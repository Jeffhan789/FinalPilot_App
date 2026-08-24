# FinalPilot Core Data 迁移指南

本指南说明如何将 `FinalPilotStore` 从纯内存存储迁移到 Core Data 持久化存储。

---

## 1. Xcode 模型配置（关键第一步）

在编译项目前，必须先配置 Core Data 模型的 Code Generation：

1. 在 Xcode 中打开 `FinalPilot.xcdatamodeld`
2. 选中所有实体（Cmd+A）
3. 在右侧 **Data Model Inspector** 中，将 **Codegen** 设为 **Manual/None**
4. 这样 Xcode 不会自动生成类文件，避免与 `CoreData+Extensions.swift` 中的手动定义冲突

---

## 2. 修改 FinalPilotApp.swift

将 `FinalPilotStore` 替换为 `DataController`，注入到 SwiftUI 环境：

```swift
import SwiftUI

@main
struct FinalPilotApp: App {
    @StateObject private var dataController = DataController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataController)
                .onAppear {
                    // 首次启动时迁移 SeedData
                    CoreDataMigrationHelper.migrateSeedDataIfNeeded(
                        context: dataController.viewContext
                    )
                }
        }
    }
}
```

---

## 3. 重写 FinalPilotStore

以下是将 `FinalPilotStore` 完全迁移到 Core Data 的参考实现。核心思路：

- 所有 `@Published` 属性改为从 Core Data 查询获取
- 所有修改操作改为写入 Core Data 并保存
- 利用 `NSFetchedResultsController` 或 SwiftUI 的 `@FetchRequest` 自动刷新 UI

```swift
import CoreData
import Foundation
import SwiftUI

final class FinalPilotStore: ObservableObject {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = DataController.shared.viewContext) {
        self.context = context
    }

    // MARK: - 查询属性（从 Core Data 实时获取）

    var courses: [Course] {
        let request = CourseEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "examDate", ascending: true)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map { $0.toCourse() }
    }

    var tasks: [StudyTask] {
        let request = StudyTaskEntity.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []
        return entities.map { $0.toStudyTask() }
    }

    var careerEvents: [CareerEvent] {
        let request = CareerEventEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map { $0.toCareerEvent() }
    }

    var sprintPlanDays: [SprintPlanDay] {
        let request = SprintPlanDayEntity.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []
        return entities.map { $0.toSprintPlanDay() }
    }

    var flashcards: [KnowledgeFlashcard] {
        let request = KnowledgeFlashcardEntity.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []
        return entities.map { $0.toKnowledgeFlashcard() }
    }

    var attempts: [QuizAttempt] {
        let request = QuizAttemptEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map { $0.toQuizAttempt() }
    }

    // MARK: - 计算属性（保持不变）

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

    // MARK: - 方法重写（改为 Core Data 操作）

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

    func toggleTask(_ task: StudyTask) {
        let request = StudyTaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", task.id)
        request.fetchLimit = 1

        guard let entity = (try? context.fetch(request))?.first else { return }
        let newStatus = entity.status == TaskStatus.done.rawValue
            ? TaskStatus.pending.rawValue
            : TaskStatus.done.rawValue
        entity.status = newStatus
        save()
    }

    func deferTask(_ task: StudyTask) {
        let request = StudyTaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", task.id)
        request.fetchLimit = 1

        guard let entity = (try? context.fetch(request))?.first else { return }
        entity.status = TaskStatus.deferred.rawValue
        entity.bucket = TaskBucket.skip.rawValue
        save()
    }

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

        _ = QuizAttemptEntity.fromQuizAttempt(attempt, context: context)
        updateMastery(for: question, isCorrect: isCorrect, confidence: confidence)
        scheduleFollowUpIfNeeded(question: question, isCorrect: isCorrect, confidence: confidence)
        save()
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
        _ = CareerEventEntity.fromCareerEvent(event, context: context)
        save()
    }

    func daysUntil(_ date: Date?, from now: Date = Date()) -> Int? {
        guard let date else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    // MARK: - 新增：记录每日学习数据

    func recordDailyStudy(minutes: Int, tasksCompleted: Int, correctAnswers: Int, totalAnswers: Int) {
        let today = Date()
        let existing = context.fetchDailyRecord(for: today)

        if let record = existing {
            record.totalMinutes += Int32(minutes)
            record.completedTasks += Int32(tasksCompleted)
            record.correctAnswers += Int32(correctAnswers)
            record.totalAnswers += Int32(totalAnswers)
        } else {
            _ = DailyStudyRecordEntity.createDailyRecord(
                date: today,
                totalMinutes: minutes,
                completedTasks: tasksCompleted,
                correctAnswers: correctAnswers,
                totalAnswers: totalAnswers,
                context: context
            )
        }
        save()
    }

    // MARK: - 私有方法

    private func save() {
        if context.hasChanges {
            try? context.save()
        }
    }

    private func updateMastery(for question: QuizQuestion, isCorrect: Bool, confidence: ConfidenceLevel) {
        let request = KnowledgePointEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", question.knowledgePointID)
        request.fetchLimit = 1

        guard let point = (try? context.fetch(request))?.first else { return }
        let delta: Double
        if isCorrect {
            delta = confidence == .high ? 0.08 : 0.04
        } else {
            delta = confidence == .high ? -0.16 : -0.1
        }
        point.mastery = min(1, max(0, point.mastery + delta))
        if point.mastery >= 0.72 {
            point.status = KnowledgeStatus.mastered.rawValue
        } else if point.mastery < 0.38 {
            point.status = KnowledgeStatus.weak.rawValue
        } else {
            point.status = KnowledgeStatus.inProgress.rawValue
        }
    }

    private func scheduleFollowUpIfNeeded(question: QuizQuestion, isCorrect: Bool, confidence: ConfidenceLevel) {
        guard !isCorrect else { return }

        let request = StudyTaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", "followup_\(question.knowledgePointID)")
        request.fetchLimit = 1
        let alreadyExists = ((try? context.fetch(request))?.first) != nil
        guard !alreadyExists else { return }

        let title = confidence == .high ? "危险误区复盘" : "错题变体练习"
        let task = StudyTask(
            id: "followup_\(question.knowledgePointID)",
            track: .exam,
            bucket: .must,
            title: title,
            subtitle: "\(question.sourceType.label) · \(question.sourceTitle)",
            minutes: confidence == .high ? 20 : 15,
            reason: confidence == .high
                ? "高自信错误比普通错误更危险。回到 \(question.sourceDetail) 做一次变体。"
                : "错题需要在 24 小时内回看。来源：\(question.sourceDetail)",
            linkedCourseID: question.courseID,
            status: .pending
        )
        _ = StudyTaskEntity.fromStudyTask(task, context: context)
    }

    private func bucketOrder(_ bucket: TaskBucket) -> Int {
        switch bucket {
        case .must: 0
        case .should: 1
        case .skip: 2
        }
    }
}
```

---

## 4. 各 View 的修改要点

所有 View 目前通过 `@EnvironmentObject private var store: FinalPilotStore` 访问数据。由于重写后的 `FinalPilotStore` 保持相同的接口（`courses`、`tasks`、`toggleTask` 等），**大部分 View 无需修改**即可继续工作。

### 需要微调的部分：

#### A. ContentView / TabView（无需修改）

`ContentView` 本身不直接访问 `store`，所有子 View 通过 `EnvironmentObject` 获取。

#### B. 使用 `@FetchRequest` 的优化（可选）

对于需要自动响应 Core Data 变化的页面，可以将 SwiftUI 的 `@FetchRequest` 与 `FinalPilotStore` 结合使用：

```swift
struct DashboardView: View {
    @EnvironmentObject private var store: FinalPilotStore

    // 可选：直接绑定 Core Data FetchRequest 以获得自动刷新
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "examDate", ascending: true)],
        animation: .default
    ) private var courseEntities: FetchedResults<CourseEntity>

    private var courses: [Course] {
        courseEntities.map { $0.toCourse() }
    }
}
```

#### C. 新增每日学习记录调用点

在 `submitAnswer` 或 `toggleTask` 完成后，可以调用新增的 `recordDailyStudy` 方法：

```swift
// 在 submitAnswer 中自动记录
func submitAnswer(...) -> QuizAttempt {
    // ... 原有逻辑
    recordDailyStudy(
        minutes: 10,
        tasksCompleted: 0,
        correctAnswers: isCorrect ? 1 : 0,
        totalAnswers: 1
    )
    return attempt
}
```

---

## 5. 需要重写的方法清单

| 方法 | 原实现 | 新实现 | 说明 |
|------|--------|--------|------|
| `courses` | 纯数组 | Core Data Fetch | 实时查询 |
| `tasks` | 纯数组 | Core Data Fetch | 实时查询 |
| `careerEvents` | 纯数组 | Core Data Fetch | 实时查询 |
| `sprintPlanDays` | 纯数组 | Core Data Fetch | 实时查询 |
| `flashcards` | 纯数组 | Core Data Fetch | 实时查询 |
| `attempts` | 纯数组 | Core Data Fetch | 实时查询 |
| `toggleTask(_:)` | 数组索引修改 | 查询+修改实体 | 需先 Fetch 再 Save |
| `deferTask(_:)` | 数组索引修改 | 查询+修改实体 | 需先 Fetch 再 Save |
| `submitAnswer(...)` | 插入数组+更新数组 | 创建实体+保存 | 使用 `QuizAttemptEntity` |
| `addSampleMilestone()` | `append` 数组 | 创建实体+保存 | 使用 `CareerEventEntity` |
| `updateMastery(...)` | 数组索引修改 | 查询+修改实体 | 需先 Fetch 知识点 |
| `scheduleFollowUpIfNeeded(...)` | `contains`+`insert` | 查询+创建实体 | 使用 `StudyTaskEntity` |
| `recordDailyStudy(...)` | 无 | 新增方法 | 使用 `DailyStudyRecordEntity` |

---

## 6. 编译检查清单

完成修改后，请按以下顺序验证：

1. [ ] 在 Xcode 中打开 `FinalPilot.xcdatamodeld`，确认所有 9 个实体已正确加载
2. [ ] 选中所有实体，确认 Codegen = **Manual/None**
3. [ ] 编译项目，确认 `CoreData+Extensions.swift` 无重复定义错误
4. [ ] 首次运行 App，确认 `CoreDataMigrationHelper` 成功将 `SeedData` 导入持久化存储
5. [ ] 杀死后台重启 App，确认数据仍然保留（非内存存储）
6. [ ] 完成一个任务，杀死后台，确认任务状态已持久化

---

## 7. 后续可扩展方向

基于已搭建的 Core Data 基础设施，可以无缝扩展以下功能：

- **Widget 共享**：使用 `App Group` 让 Widget Extension 读取同一 `NSPersistentContainer`
- **iCloud 同步**：在 `DataController` 中为 `NSPersistentStoreDescription` 启用 `cloudKitContainerOptions`
- **数据导出**：将 `DailyStudyRecordEntity` 导出为 CSV 或 JSON
- **历史趋势分析**：在 `AnalyticsView` 中查询 `DailyStudyRecordEntity` 绘制长期学习曲线
