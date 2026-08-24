import Foundation
import CoreData

@MainActor
final class FinalPilotStore: ObservableObject {
    @Published var courses: [Course]
    @Published var tasks: [StudyTask]
    @Published var careerEvents: [CareerEvent]
    @Published var sprintPlanDays: [SprintPlanDay]
    @Published var flashcards: [KnowledgeFlashcard]
    @Published var attempts: [QuizAttempt]

    private let sideEffectsEnabled: Bool

    // MARK: - Core Data Context
    // `context` 通过单例懒加载，保持与 DataController 的生命周期绑定
    // 这里不直接持有 `NSManagedObjectContext`，而是通过 `DataController.shared.viewContext` 间接访问。
    //        好处：1) 如果 DataController 初始化失败，这里返回 nil 而不是崩溃；2) 如果将来需要切换上下文（如支持多用户），
    //        只需修改 DataController 一处，Store 无需改动。`guard let context = context` 的防御性编程在 Core Data 操作中很必要。
    private var context: NSManagedObjectContext? {
        guard sideEffectsEnabled else { return nil }
        return DataController.shared.viewContext
    }

    init(
        courses: [Course] = SeedData.courses,
        tasks: [StudyTask] = SeedData.tasks,
        careerEvents: [CareerEvent] = SeedData.careerEvents,
        sprintPlanDays: [SprintPlanDay] = SeedData.sprintPlanDays,
        flashcards: [KnowledgeFlashcard] = SeedData.flashcards,
        attempts: [QuizAttempt] = [],
        sideEffectsEnabled: Bool = true
    ) {
        self.courses = courses
        self.tasks = tasks
        self.careerEvents = careerEvents
        self.sprintPlanDays = sprintPlanDays
        self.flashcards = flashcards
        self.attempts = attempts
        self.sideEffectsEnabled = sideEffectsEnabled
    }

    var nearestExam: Course? {
        courses
            .filter { $0.examDate != nil }
            .sorted { ($0.examDate ?? .distantFuture) < ($1.examDate ?? .distantFuture) }
            .first
    }

    var totalStudyMinutes: Int {
        tasks.filter { $0.status == .done }.reduce(0) { $0 + $1.minutes }
    }

    var completionRate: Double {
        let activeTasks = tasks.filter { $0.bucket != .skip }
        guard !activeTasks.isEmpty else { return 0 }
        let done = activeTasks.filter { $0.status == .done }.count
        return Double(done) / Double(activeTasks.count)
    }

    var highRiskKnowledgePoints: [(Course, KnowledgePoint)] {
        courses.flatMap { course in
            course.knowledgePoints
                .filter { $0.status == .weak || $0.mastery < 0.38 }
                .map { (course, $0) }
        }
        .sorted { lhs, rhs in
            let lhsScore = lhs.1.mastery - Double(lhs.1.difficulty) * 0.04
            let rhsScore = rhs.1.mastery - Double(rhs.1.difficulty) * 0.04
            return lhsScore < rhsScore
        }
    }

    var allQuestions: [QuizQuestion] {
        courses.flatMap(\.questions)
    }

    func tasks(track: TaskTrack, bucket: TaskBucket? = nil) -> [StudyTask] {
        tasks
            .filter { task in
                task.track == track && (bucket == nil || task.bucket == bucket)
            }
            .sorted { lhs, rhs in
                if lhs.bucket != rhs.bucket {
                    return bucketOrder(lhs.bucket) < bucketOrder(rhs.bucket)
                }
                return lhs.minutes > rhs.minutes
            }
    }

    // MARK: toggleTask - 任务状态切换与副作用编排
    // 状态机模式：任务状态在 pending ↔ done 之间切换，通过 `wasDone` 记录原状态实现幂等回退
    // 这里使用内存数组 `tasks` 作为单一事实来源（Single Source of Truth），UI 通过 `@Published` 自动响应。
    //        `firstIndex(where:)` 在 O(n) 时间内定位任务，对于百级数据量完全可接受。如果任务量增长到千级以上，
    //        应考虑将 `tasks` 改为 `Dictionary<String, StudyTask>` 实现 O(1) 查找。
    func toggleTask(_ task: StudyTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let wasDone = tasks[index].status == .done
        tasks[index].status = wasDone ? .pending : .done
        
        // 状态切换后立刻持久化，但只写 changed 属性，不是全对象覆盖
        // Core Data 的 `save()` 只保存被标记为 `hasChanges` 的属性。`NSManagedObject` 内部维护一个"变更集"，
        //        只有被修改的字段会被写入 SQL UPDATE 语句。所以即使每次都调用 `save()`，性能开销也只在实际变更时产生。
        //        这里 `persistTask` 先 fetch 对应 Entity，更新字段后再 save，确保写入最小化。
        persistTask(tasks[index])
        
        // 即时鼓励通知与业务逻辑分离，通过调度器解耦
        // 完成 Must 任务后发送通知是"副作用"（side effect），不应直接内嵌在状态切换逻辑中。
        //        这里通过 `StudyReminderScheduler` 单例委托，保持了 Store 的单一职责：只管理数据和状态，不直接操作通知系统。
        //        如果将来需要把通知改为弹窗或积分系统，只需修改调度器，Store 无需改动。
        // 通知反馈
        if sideEffectsEnabled && !wasDone {
            StudyReminderScheduler.shared.sendTaskCompletionEncouragement(task: task)
        }
        
        // Widget 同步与数据持久化必须同时发生，但先后顺序有讲究
        // Widget 的 Timeline 刷新依赖的是 App Group 共享的 UserDefaults（或 Core Data 共享存储），
        //        所以必须先完成 Core Data 保存，再刷新 Widget。如果先刷新 Widget 再保存 Core Data，Widget 可能读到旧数据。
        //        实际调用 `WidgetCenter.shared.reloadAllTimelines()` 是异步操作，App 不需要等待它完成。
        // Widget 同步
        if sideEffectsEnabled {
            syncToWidget()
        }
    }

    func deferTask(_ task: StudyTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].status = .deferred
        tasks[index].bucket = .skip
        persistTask(tasks[index])
        if sideEffectsEnabled {
            syncToWidget()
        }
    }

    // MARK: submitAnswer - 答题提交与掌握度反馈闭环
    // 答题流程的完整闭环：归一化比对 → 创建 Attempt → 更新掌握度 → 错题跟进 → 持久化 → 激励通知
    // 字符串比对前先用 `trimmingCharacters(in: .whitespacesAndNewlines)` 去除首尾空白，
    //        这是因为用户输入或题库数据可能包含不可见字符（如换行、空格），直接 `==` 会导致假阴性（false negative）。
    //        但要注意：这不能解决全角半角问题（如 "A" vs "Ａ"），如果需要更严格的比对，应使用 `precomposedStringWithCanonicalMapping` 做 Unicode 正规化。
    @discardableResult
    func submitAnswer(question: QuizQuestion, selectedAnswer: String, confidence: ConfidenceLevel) -> QuizAttempt {
        let normalizedSelected = selectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAnswer = question.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = normalizedSelected == normalizedAnswer

        let attempt = QuizAttempt(
            id: UUID().uuidString,
            questionID: question.id,
            knowledgePointID: question.knowledgePointID,
            selectedAnswer: selectedAnswer,
            isCorrect: isCorrect,
            confidence: confidence,
            createdAt: Date()
        )
        attempts.insert(attempt, at: 0)
        
        // Confidence Trap 检测：高自信答错比低自信答错危害更大
        // 认知科学中的"邓宁-克鲁格效应"（Dunning-Kruger Effect）指出：能力不足者往往会高估自己的能力。
        //        本 App 将答题行为分为四个象限：高自信正确、低自信正确、低自信错误、高自信错误。
        //        其中"高自信错误"（Confidence Trap）是最危险的——用户以为自己掌握了但实际没有，考试中会直接丢分。
        //        所以 delta 的惩罚力度设计为：高自信错误 -0.16，低自信错误 -0.1，差距 60%。
        //        奖励侧设计为：高自信正确 +0.08，低自信正确 +0.04，鼓励用户建立准确的自信判断。
        updateMastery(for: question, isCorrect: isCorrect, confidence: confidence)
        
        // 错题自动创建后续任务，利用"间隔效应"（Spacing Effect）
        // 艾宾浩斯遗忘曲线表明：学习后 20 分钟遗忘 42%，1 小时后遗忘 56%，1 天后遗忘 74%。
        //        但如果在遗忘临界点前复习，记忆强度会跃升。本 App 在答错后立即创建一个"24 小时后回顾"的 Must 任务，
        //        在最佳复习窗口期触发回顾，形成"测试-反馈-再学习"的闭环。
        scheduleFollowUpIfNeeded(question: question, isCorrect: isCorrect, confidence: confidence)
        
        // Core Data 持久化
        persistQuizAttempt(attempt)
        
        // 连续答对鼓励
        let hasThreeCorrectAnswers = attempts.count >= 3 && attempts.prefix(3).allSatisfy { $0.isCorrect }
        if sideEffectsEnabled && hasThreeCorrectAnswers {
            StudyReminderScheduler.shared.sendStreakEncouragement(correctCount: 3)
        }

        if sideEffectsEnabled {
            syncToWidget()
        }
        return attempt
    }

    func addSampleMilestone() {
        let event = CareerEvent(
            id: UUID().uuidString,
            company: "新增里程碑",
            role: "自定义事务",
            round: "待执行",
            date: .finalPilotDate(month: 5, day: 10, hour: 15),
            importance: 3,
            preparationStatus: "等待拆解"
        )
        careerEvents.append(event)
        if sideEffectsEnabled {
            syncToWidget()
        }
    }

    // MARK: daysUntil - 跨时区考试倒计时计算
    // 日期计算的核心是"日期语义"与"物理时间"的分离。`Date` 是物理时间（UTC 时间戳），
    //        而人类理解的"还有几天考试"是语义时间（取决于时区和日历规则）。
    //        本方法的关键设计：1) 显式指定考试所在时区（Europe/London），避免用户跨时区旅行导致倒计时错乱；
    //        2) 使用 `startOfDay(for:)` 将两个时间点都归一化为当天的 00:00:00，消除时分秒差异；
    //        3) 用 `dateComponents([.day], from:to:)` 计算天数差，而不是自己除 86400，因为夏令时切换当天不是 86400 秒。
    func daysUntil(_ date: Date?, from now: Date = Date()) -> Int? {
        guard let date else { return nil }
        
        // Calendar 的时区处理：为什么显式设置 Europe/London
        // `Date` 在 Swift 中是 UTC 时间戳，不带时区信息。`Calendar` 负责将时间戳映射到人类理解的"年月日时分秒"。
        //        如果不显式设置 `timeZone`，`Calendar.current` 会使用设备当前时区。但本 App 的用户可能在考试期间旅行，
        //        如果在伦敦考试期间到了纽约，设备的本地时区变了，倒计时就会算错（因为日期分界点变了）。
        //        显式设置为考试所在时区（Europe/London）确保无论用户在哪里，倒计时都基于伦敦时间计算。
        //        `startOfDay(for:)` 是关键 API：它将任意时间点归一化为当天的 00:00:00，消除时分秒差异，只比较日期差。
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    // MARK: - Widget Sync
    
    // MARK: syncToWidget - App Group 共享数据与 Widget 刷新
    // Widget Extension 是独立进程，与主 App 不共享内存，必须通过 App Group 的共享容器交换数据。
    //        本方法将三类数据序列化为轻量结构写入 `UserDefaults(suiteName:)`：1) 考试倒计时（WidgetExamInfo）；
    //        2) 待办任务列表（WidgetTaskInfo）；3) 学习进度统计（WidgetProgressInfo）。
    //        选择 UserDefaults 而非 Core Data 共享容器的原因是：Widget 数据量小、结构简单、更新频繁，
    //        UserDefaults 的键值读写性能更优，且避免了 Core Data 并发上下文的复杂性。
    // MARK: - Core Data Persistence
    
    // MARK: persistTask - Core Data 任务持久化（Upsert 模式）
    // Upsert（Update or Insert）模式：先 Fetch 已有记录，存在则更新，不存在则新建。
    //        这种模式避免了重复插入导致的主键冲突，同时保证数据一致性。`NSFetchRequest` 通过 `predicate` 限定查询范围，
    //        这里用 `id == %@` 精确匹配，利用 SQLite 的索引实现 O(log n) 查找。`Int32` 是 Core Data 对 Swift `Int` 的映射类型，
    //        因为 Objective-C 的 `NSInteger` 在 32 位/64 位平台宽度不同，Core Data 选择 `Int32` 保证跨平台一致性。
    private func persistTask(_ task: StudyTask) {
        guard let context = context else { return }
        let fetchRequest: NSFetchRequest<StudyTaskEntity> = StudyTaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", task.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            let entity = results.first ?? StudyTaskEntity(context: context)
            entity.id = task.id
            entity.track = task.track.rawValue
            entity.bucket = task.bucket.rawValue
            entity.title = task.title
            entity.subtitle = task.subtitle
            entity.minutes = Int32(task.minutes)
            entity.reason = task.reason
            entity.linkedCourseID = task.linkedCourseID
            entity.status = task.status.rawValue
            try context.save()
        } catch {
            print("Persist task error: \(error)")
        }
    }
    
    // MARK: persistQuizAttempt - 答题记录持久化（纯 Insert 模式）
    // 与 `persistTask` 的 Upsert 不同，QuizAttempt 是追加-only 的审计日志，每次答题都生成新记录，永不更新旧记录。
    //        这种设计符合事件溯源（Event Sourcing）思想：系统状态不是存储在某个字段中，而是由一系列不可变事件推导得出。
    //        好处：1) 完整保留学习轨迹，可用于后续分析（如"本周在哪些知识点上犯了高自信错误"）；
    //        2) 防止数据篡改，历史记录不可变；3) 便于实现"撤销"功能（只需忽略某条记录重新计算）。
    private func persistQuizAttempt(_ attempt: QuizAttempt) {
        guard let context = context else { return }
        let entity = QuizAttemptEntity(context: context)
        entity.id = attempt.id
        entity.questionID = attempt.questionID
        entity.knowledgePointID = attempt.knowledgePointID
        entity.selectedAnswer = attempt.selectedAnswer
        entity.isCorrect = attempt.isCorrect
        entity.confidence = attempt.confidence.rawValue
        entity.createdAt = attempt.createdAt
        
        do {
            try context.save()
        } catch {
            print("Persist attempt error: \(error)")
        }
    }

    // MARK: updateMastery - 掌握度 Delta 算法（四象限反馈模型）
    // 信号检测理论（Signal Detection Theory）将决策分为四种：Hit（高自信正确）、Miss（低自信错误）、
    //        False Alarm（高自信错误）、Correct Rejection（低自信正确）。本算法将 False Alarm 的惩罚（-0.16）设为 Miss（-0.10）的 1.6 倍，
    //        因为 False Alarm 代表"认知偏差"——用户不仅错了，还不知道自己错了，这种偏差会导致后续复习中主动忽略该知识点。
    //        0.08 和 0.04 的奖励差两倍，是鼓励用户培养自信判断能力，而非盲目猜测。
    //        阈值 0.72（mastered）和 0.38（weak）是经验值，参考了 SuperMemo 的 SM-2 算法中 "easy threshold" 和 "forgetting threshold"。
    private func updateMastery(for question: QuizQuestion, isCorrect: Bool, confidence: ConfidenceLevel) {
        guard
            let courseIndex = courses.firstIndex(where: { $0.id == question.courseID }),
            let pointIndex = courses[courseIndex].knowledgePoints.firstIndex(where: { $0.id == question.knowledgePointID })
        else { return }

        var point = courses[courseIndex].knowledgePoints[pointIndex]
        
        // 掌握度 delta 的量化心理学基础：信号检测理论（Signal Detection Theory）
        // 信号检测理论将决策分为四种：Hit（高自信正确）、Miss（低自信错误）、False Alarm（高自信错误）、Correct Rejection（低自信正确）。
        //        本算法将 False Alarm 的惩罚（-0.16）设为 Miss（-0.10）的 1.6 倍，因为 False Alarm 代表"认知偏差"——
        //        用户不仅错了，还不知道自己错了，这种偏差会导致后续复习中主动忽略该知识点。
        //        0.08 和 0.04 的奖励差两倍，是鼓励用户培养自信判断能力，而非盲目猜测。
        //        阈值 0.72（mastered）和 0.38（weak）是经验值，参考了 SuperMemo 的 SM-2 算法中 "easy threshold" 和 "forgetting threshold" 的设定。
        let delta: Double
        if isCorrect {
            delta = confidence == .high ? 0.08 : 0.04
        } else {
            delta = confidence == .high ? -0.16 : -0.1
        }
        point.mastery = min(1, max(0, point.mastery + delta))
        if point.mastery >= 0.72 {
            point.status = .mastered
        } else if point.mastery < 0.38 {
            point.status = .weak
        } else {
            point.status = .inProgress
        }
        courses[courseIndex].knowledgePoints[pointIndex] = point
        
        // 持久化知识点掌握度
        persistKnowledgePoint(point, courseID: question.courseID)
    }
    
    // MARK: persistKnowledgePoint - 知识点掌握度持久化（精准更新）
    // 精准更新模式：只 Fetch 目标记录，更新 `mastery` 和 `status` 两个字段，不触碰其他属性。
    //        Core Data 的脏检查机制会自动追踪变更属性，`save()` 时只生成包含变更字段的 UPDATE SQL，而非整行覆盖。
    //        这比"读出整行 → 修改 → 写回整行"更高效，尤其在并发场景下减少了写冲突的概率。
    private func persistKnowledgePoint(_ point: KnowledgePoint, courseID: String) {
        guard let context = context else { return }
        let fetchRequest: NSFetchRequest<KnowledgePointEntity> = KnowledgePointEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", point.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                entity.mastery = point.mastery
                entity.status = point.status.rawValue
                try context.save()
            }
        } catch {
            print("Persist knowledge point error: \(error)")
        }
    }

    // MARK: scheduleFollowUpIfNeeded - 错题跟进任务的智能调度（间隔效应）
    // 艾宾浩斯遗忘曲线表明：学习后 20 分钟遗忘 42%，1 小时后遗忘 56%，1 天后遗忘 74%。
    //        但如果在遗忘临界点前复习，记忆强度会跃升。本方法在答错后立即创建一个"24 小时后回顾"的 Must 任务，
    //        在最佳复习窗口期触发回顾，形成"测试-反馈-再学习"的闭环。`alreadyExists` 检查防止同一知识点重复创建跟进任务。
    private func scheduleFollowUpIfNeeded(question: QuizQuestion, isCorrect: Bool, confidence: ConfidenceLevel) {
        guard !isCorrect else { return }
        let alreadyExists = tasks.contains { $0.id == "followup_\(question.knowledgePointID)" }
        guard !alreadyExists else { return }

        let title = confidence == .high ? "危险误区复盘" : "错题变体练习"
        let task = StudyTask(
            id: "followup_\(question.knowledgePointID)",
            track: .exam,
            bucket: .must,
            title: title,
            subtitle: "\(question.sourceType.label) · \(question.sourceTitle)",
            minutes: confidence == .high ? 20 : 15,
            reason: confidence == .high ? "高自信错误比普通错误更危险。回到 \(question.sourceDetail) 做一次变体。" : "错题需要在 24 小时内回看。来源：\(question.sourceDetail)",
            linkedCourseID: question.courseID,
            status: .pending
        )
        tasks.insert(task, at: 0)
        persistTask(task)
        
        // 错题回顾通知
        if sideEffectsEnabled {
            StudyReminderScheduler.shared.scheduleMistakeReviewReminders(store: self)
        }
    }

    private func bucketOrder(_ bucket: TaskBucket) -> Int {
        switch bucket {
        case .must: 0
        case .should: 1
        case .skip: 2
        }
    }
}
