import Foundation
import UserNotifications

/// 复习提醒调度器，根据考试日期、知识点优先级、用户偏好自动计算提醒策略
/// 考试日期：C310 = 5/13、E320 = 5/14、C315 = 5/26
// 调度器采用单例模式，集中管理所有通知的 CRUD 操作
// UserNotifications 框架是系统级服务，UNUserNotificationCenter 是单例（`UNUserNotificationCenter.current()`）。
//        本调度器作为 App 层的通知管理门面（Facade），封装了：权限检查、内容生成、时机计算、通知调度四大职责。
//        所有通知操作都经过这里，避免分散在各业务逻辑中，便于统一管理通知 ID 命名规范、防止重复调度、控制频率配额。
@MainActor
final class StudyReminderScheduler: ObservableObject {
    static let shared = StudyReminderScheduler()

    private let manager = NotificationManager.shared
    private let calendar = Calendar.current

    /// 三科考试日期（固定，与 SeedData 中课程保持一致）
    private let examDates: [(courseID: String, courseName: String, date: Date)] = [
        ("c310", "C310", Date.finalPilotDate(month: 5, day: 13, hour: 9)),
        ("e320", "E320", Date.finalPilotDate(month: 5, day: 14, hour: 9)),
        ("c315", "C315", Date.finalPilotDate(month: 5, day: 26, hour: 9))
    ]

    /// 默认提醒时段（9:00、14:00、20:00）
    // 三时段设计基于人体认知节律：早晨记忆编码、下午巩固、晚上检索
    // 认知科学研究表明，一天中的记忆效率并非均匀分布。早晨（9:00 左右）大脑经过休息，
    //        适合"编码新信息"（学习新知识点）；下午（14:00 左右）适合"巩固和练习"（做题、复习错题）；
    //        晚上（20:00 左右）适合"检索练习"（回顾一天所学，睡前回忆效果最佳）。
    //        这三个时段避开用户的通勤高峰（8:00-9:00）和午休时间（12:00-13:00），确保通知到达时用户有时间响应。
    //        另外，固定时段有利于建立"学习仪式感"——当用户每天在相同时间收到学习提醒，会形成条件反射，提高执行率。
    private var defaultReminderHours: [Int] { reminderHoursFromStorage }

    /// 从 AppStorage 读取用户自定义时段
    private var reminderHoursFromStorage: [Int] {
        let hoursString = UserDefaults.standard.string(forKey: "finalPilot_reminderHours") ?? "9,14,20"
        return hoursString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (0...23).contains($0) }
    }

    private init() {}

    // MARK: - 主调度入口

    // 全量重新调度策略：先取消再创建，保证状态一致性
    // 本调度器采用"全量重建"策略：每次数据变更时，先取消所有 pending 通知，再重新计算并创建新通知。
    //        这样做的好处：1) 通知状态与 Store 数据严格一致，不存在旧通知引用已删除数据的问题；
    //        2) ID 命名规范统一（`daily_reminder_\(hour)`、`countdown_\(courseID)_\(days)`），相同 ID 的通知自动覆盖；
    //        3) 逻辑简单，不需要维护增量更新的 diff 算法。代价：每次调度有 O(n) 的计算量，但通知总量很小（<20条），可忽略。
    func rescheduleAllNotifications(store: FinalPilotStore) {
        guard manager.isNotificationsEnabled else { return }

        // 1. 先取消所有旧通知
        manager.cancelAllPendingNotifications()

        // 2. 调度每日复习提醒（基于高优先级知识点）
        scheduleDailyStudyReminders(store: store)

        // 3. 调度考试倒计时提醒（1/3/7天）
        scheduleExamCountdownReminders()

        // 4. 调度每日统计推送（20:30）
        scheduleDailySummary(store: store)

        // 5. 调度错题回顾提醒（基于最近错题）
        scheduleMistakeReviewReminders(store: store)

        print("[StudyReminderScheduler] 所有通知已重新调度完成")
    }

    // MARK: - 每日复习提醒

    // 内容差异化策略：三时段推送不同侧重点，匹配用户认知状态与执行意图
    // 早晨（<12:00）用户刚进入学习状态，前额叶皮层活跃度最高，适合推送"倒计时+任务数"形成紧迫感，
    //        利用"损失框架"（Loss Framing，"还剩X天"）比"收益框架"更能驱动执行——这是前景理论（Prospect Theory）的应用；
    //        下午（<17:00）经过半天认知消耗，大脑进入疲劳期，注意力残留约上午的60%，此时推送"薄弱知识点"帮助精准查漏补缺，
    //        避免让用户在高负荷时做复杂决策；晚上（≥17:00）用户即将结束一天，海马体进入记忆巩固窗口期，
    //        推送"错题回顾"利用睡前记忆重放（Memory Replay）效应，睡眠中大脑会自发巩固当天纠错内容。
    //        三个时段的内容不是随机分配，而是对应"计划→执行→巩固"的完整学习闭环。
    private func scheduleDailyStudyReminders(store: FinalPilotStore) {
        guard manager.isNotificationsEnabled else { return }

        let hours = defaultReminderHours
        guard !hours.isEmpty else { return }

        // 找到高优先级知识点（priority >= 5）或薄弱知识点
        let highPriorityCards = store.flashcards.filter { $0.priority >= 5 }
        let weakPoints = store.highRiskKnowledgePoints

        for (index, hour) in hours.enumerated() {
            let identifier = "daily_reminder_\(hour)"
            let content: (title: String, body: String)

            // 早晨提醒：侧重考试倒计时和今日任务
            if hour < 12 {
                let nearestExam = store.nearestExam
                let daysLeft = store.daysUntil(nearestExam?.examDate)
                let examName = nearestExam?.name ?? "考试"
                let mustCount = store.tasks(track: .exam, bucket: .must).filter { $0.status != .done }.count

                content.title = "🎓 学呀学 · 今日冲刺"
                if let days = daysLeft, days >= 0 {
                    content.body = "距离 \(examName) 还有 \(days) 天，今日有 \(mustCount) 个 Must 任务等你完成。开始复习吧！"
                } else {
                    content.body = "今日有 \(mustCount) 个 Must 任务等你完成，先保住 C310 / E320 优先级！"
                }
            }
            // 下午提醒：侧重复习薄弱知识点
            else if hour < 17 {
                if let firstCard = highPriorityCards.first {
                    content.title = "🔥 高优先级知识点复习"
                    content.body = "【\(firstCard.title)】\(firstCard.prompt.prefix(60))… 抽10分钟回顾一下吧！"
                } else if let firstWeak = weakPoints.first {
                    content.title = "⚠️ 薄弱知识点提醒"
                    content.body = "【\(firstWeak.1.title)】掌握度仅 \(Int(firstWeak.1.mastery * 100))%，建议优先复习！"
                } else {
                    content.title = "📚 下午复习时间"
                    content.body = "完成一套真题或复习辅导课笔记，保持手感！"
                }
            }
            // 晚上提醒：错题回顾和总结
            else {
                let todayAttempts = store.attempts.filter {
                    calendar.isDate($0.createdAt, inSameDayAs: Date())
                }
                let wrongCount = todayAttempts.filter { !$0.isCorrect }.count
                if wrongCount > 0 {
                    content.title = "🌙 晚间错题回顾"
                    content.body = "今天错了 \(wrongCount) 道题，睡前花15分钟复盘，效果翻倍！"
                } else {
                    content.title = "🌙 今日复习总结"
                    content.body = "今天表现不错！再花10分钟过一遍高频考点，巩固记忆。"
                }
            }

            manager.scheduleDailyReminder(
                identifier: identifier,
                title: content.title,
                body: content.body,
                hour: hour,
                minute: 0,
                category: NotificationCategory.studyReminder,
                userInfo: ["slotIndex": index]
            )
        }
    }

    // MARK: - 考试倒计时提醒

    // 1/3/7 天倒计时策略：基于记忆唤醒曲线和备考心理学
    // 考试倒计时的通知不是简单的"还有 X 天"，而是经过心理学设计的"压力梯度"：
    //        - 7 天前：第一次提醒，让用户从"日常模式"切换到"备考模式"，开始高强度复习；
    //        - 3 天前：第二次提醒，此时用户进入"冲刺模式"，提醒内容侧重查漏补缺和错题回顾；
    //        - 1 天前：最后一次提醒，侧重考试物品准备和心理调整（"带好准考证、深呼吸"）。
    //        这个节奏参考了耶基斯-多德森定律（Yerkes-Dodson Law）：适度压力提升表现，但过早或过强的压力会导致焦虑下降。
    //        选择 8:00 发送是因为：倒计时通知需要用户在一天开始时看到，才能影响当天的复习计划。
    private func scheduleExamCountdownReminders() {
        guard manager.countdownAlertsEnabled else { return }

        let now = Date()
        let countdownDays = [1, 3, 7]

        for exam in examDates {
            guard exam.date > now else { continue }

            for daysBefore in countdownDays {
                guard let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: exam.date) else { continue }
                guard reminderDate > now else { continue }

                let identifier = "countdown_\(exam.courseID)_\(daysBefore)"
                let content = NotificationContent.examCountdown(
                    courseName: exam.courseName,
                    daysLeft: daysBefore,
                    examDate: exam.date
                )

                // 倒计时提醒在当天 8:00 发送
                var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
                components.hour = 8
                components.minute = 0
                guard let triggerDate = calendar.date(from: components) else { continue }

                manager.scheduleOneTimeReminder(
                    identifier: identifier,
                    title: content.title,
                    body: content.body,
                    date: triggerDate,
                    category: NotificationCategory.examCountdown,
                    userInfo: [
                        NotificationUserInfoKey.courseID: exam.courseID,
                        NotificationUserInfoKey.examDate: exam.date.timeIntervalSince1970,
                        NotificationUserInfoKey.daysUntilExam: daysBefore
                    ]
                )
            }

            // 考试当天提醒（考前 1 小时）
            let examDayIdentifier = "exam_day_\(exam.courseID)"
            guard let examDayReminder = calendar.date(byAdding: .hour, value: -1, to: exam.date) else { return }

            manager.scheduleOneTimeReminder(
                identifier: examDayIdentifier,
                title: "🚨 \(exam.courseName) 考试即将开始",
                body: "考试将在 1 小时后开始！带好准考证、身份证和文具，深呼吸，加油！",
                date: examDayReminder,
                category: NotificationCategory.examCountdown,
                userInfo: [
                    NotificationUserInfoKey.courseID: exam.courseID,
                    NotificationUserInfoKey.examDate: exam.date.timeIntervalSince1970
                ]
            )
        }
    }

    // MARK: - 每日统计推送

    // 20:30 统计推送：利用"完成感"与"进度可视化"强化内在学习动机
    // 选择 20:30 而非 23:00 或 18:00，是基于"学习活动边界"的假设：此时用户大概率已完成当天主要学习任务，
    //        处于心理账户的"收尾"阶段。此时推送统计摘要（学习时长、完成率、任务数），能触发"完成感"（Sense of Completion），
    //        这是自我决定理论（Self-Determination Theory）中"胜任感"（Competence）的来源之一。
    //        进度可视化利用了"目标梯度效应"（Goal Gradient Effect）——越接近 100% 完成率，用户越有动力完成剩余任务；
    //        即使完成率低，数据本身也是一种"温和的反馈"，促使用户在第二天调整策略。
    //        特别注意：统计推送必须基于真实数据，如果用户今日学习 0 分钟，显示"0 分钟"会造成负面强化，
    //        因此实际生产环境中建议增加"低活跃度过滤"（如学习时长 < 10 分钟时不发统计推送，改发鼓励回归通知）。
    private func scheduleDailySummary(store: FinalPilotStore) {
        guard manager.dailySummaryEnabled else { return }

        let totalMinutes = store.totalStudyMinutes
        let completedTasks = store.tasks.filter { $0.status == .done }.count
        let totalTasks = store.tasks.filter { $0.bucket != .skip }.count
        let completionRate = Int(store.completionRate * 100)

        let content = NotificationContent.dailySummary(
            studyMinutes: totalMinutes,
            completedTasks: completedTasks,
            totalTasks: totalTasks,
            completionRate: completionRate
        )

        manager.scheduleDailyReminder(
            identifier: "daily_summary",
            title: content.title,
            body: content.body,
            hour: 20,
            minute: 30,
            category: NotificationCategory.dailySummary,
            userInfo: [
                "studyMinutes": totalMinutes,
                "completedTasks": completedTasks,
                "completionRate": completionRate
            ]
        )
    }

    // MARK: - 错题回顾提醒

    // 艾宾浩斯间隔重复：错后 60 分钟首次提醒，错开 30 分钟避免通知轰炸
    // 艾宾浩斯遗忘曲线指出：学习后 1 小时内遗忘速度最快（从 100% 降到约 44%）。
    //        所以在答错后 60 分钟（1 小时）进行第一次回顾，是在"遗忘最快"的时间窗口介入，效率最高。
    //        但如果有多个错题，不能同时发多条通知（用户会被轰炸），所以用 `index * 30` 错开发送：
    //        第 1 题 60 分钟后、第 2 题 90 分钟后、第 3 题 120 分钟后……保证用户一次只收到一条回顾提醒，有足够精力处理。
    //        只取最近 5 条错题（`prefix(5)`），是因为：1) 错题太多时分批处理更高效；2) 太旧的错题可能已经通过其他方式复习过了。
    func scheduleMistakeReviewReminders(store: FinalPilotStore) {
        let wrongAttempts = store.attempts.filter { !$0.isCorrect }.prefix(5)

        for (index, attempt) in wrongAttempts.enumerated() {
            // 错开发送时间，避免通知轰炸
            let delayMinutes = 60 + (index * 30)
            guard let question = store.allQuestions.first(where: { $0.id == attempt.questionID }) else { continue }

            let identifier = "mistake_review_\(attempt.id)"
            let content = NotificationContent.mistakeReview(
                questionSource: question.sourceType.label,
                sourceTitle: question.sourceTitle
            )

            manager.scheduleMistakeReviewReminder(
                identifier: identifier,
                title: content.title,
                body: content.body,
                afterMinutes: delayMinutes,
                userInfo: [
                    NotificationUserInfoKey.questionID: attempt.questionID,
                    NotificationUserInfoKey.knowledgePointID: attempt.knowledgePointID
                ]
            )
        }
    }

    // MARK: - 即时通知（用户操作触发）

    // 即时正反馈：行为发生后秒级响应，强化操作性条件反射回路
    // 即时通知与定时通知的本质区别：定时通知是"外部时钟驱动"（系统决定何时推），
    //        即时通知是"事件响应驱动"（用户操作后立即反馈）。根据斯金纳的操作性条件反射理论，
    //        行为与奖励的间隔越短，神经关联越强。用户刚完成一个 Must 任务就收到鼓励，
    //        大脑会将"完成任务"与"愉悦感"直接关联，提高未来重复该行为的概率（正强化）。
    //        连胜通知（Streak）则利用了"损失厌恶"（Loss Aversion）心理：用户为了保住"连续答对 X 题"的记录，
    //        会更倾向于继续答题，这是游戏化设计（Gamification）中"粘性机制"的核心。
    //        但需严格控制频率：连续答对每题都发会耗尽通知配额并引起反感，因此设置 ≥3 题的门槛。
    func sendTaskCompletionEncouragement(task: StudyTask) {
        guard manager.isNotificationsEnabled else { return }
        let content = NotificationContent.taskCompleted(taskTitle: task.title)
        manager.sendImmediateNotification(
            title: content.title,
            body: content.body,
            userInfo: [NotificationUserInfoKey.taskID: task.id]
        )
    }

    /// 用户连续答对 3 题后，发送即时鼓励
    func sendStreakEncouragement(correctCount: Int) {
        guard manager.isNotificationsEnabled, correctCount >= 3 else { return }
        let content = NotificationContent.streakEncouragement(correctCount: correctCount)
        manager.sendImmediateNotification(
            title: content.title,
            body: content.body
        )
    }

    // MARK: - 用户偏好更新

    // 用户偏好持久化通过 UserDefaults 实现，但这里用逗号分隔字符串而不是数组
    // `UserDefaults` 原生支持 `String` 和 `Array` 存储，但本例选择将 `[Int]` 编码为逗号分隔的字符串（如 "9,14,20"）。
    //        原因：1) 字符串是人类可读的，便于调试时在 Xcode 的 UserDefaults 编辑器中查看；2) 跨版本兼容性好，
    //        如果未来增加其他配置（如 `9:30,14:00`），字符串格式更灵活；3) 用 `AppStorage` 或 `UserDefaults` 的数组 API 也可以，
    //        但字符串方案更简洁。注意：排序后存储（`sorted()`），保证读取时顺序一致，避免通知顺序随机变化。
    func updateReminderHours(_ hours: [Int], store: FinalPilotStore) {
        let sortedHours = hours.filter { (0...23).contains($0) }.sorted()
        let hoursString = sortedHours.map { String($0) }.joined(separator: ",")
        UserDefaults.standard.set(hoursString, forKey: "finalPilot_reminderHours")
        rescheduleAllNotifications(store: store)
    }
}
