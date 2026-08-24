import Foundation

// MARK: - StudyStatistics
/// 提供学习统计计算方法的工具结构体。
/// 所有方法均为纯函数，基于输入数据返回统计结果，不依赖任何外部状态。
struct StudyStatistics {

    // MARK: - 7日/30日学习趋势
    /// 计算指定天数内的每日学习趋势。
    /// 返回按日期排序的聚合记录，包含学习时长、完成任务数、答题数等。
    static func studyTrend(records: [DailyStudyRecord], days: Int) -> [DailyStudyRecord] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else {
            return []
        }

        let grouped = Dictionary(grouping: records) { $0.dateKey }

        var trend: [DailyStudyRecord] = []
        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                let key = formatDateKey(date)
                let dayRecords = grouped[key] ?? []
                let totalMinutes = dayRecords.reduce(0) { $0 + $1.studyMinutes }
                let totalTasks = dayRecords.reduce(0) { $0 + $1.completedTasks }
                let totalQuestions = dayRecords.reduce(0) { $0 + $1.totalQuestions }
                let totalCorrect = dayRecords.reduce(0) { $0 + $1.correctQuestions }

                let record = DailyStudyRecord(
                    id: "trend_\(key)",
                    date: date,
                    courseID: nil,
                    courseName: nil,
                    studyMinutes: totalMinutes,
                    completedTasks: totalTasks,
                    totalQuestions: totalQuestions,
                    correctQuestions: totalCorrect,
                    weakPointChanges: []
                )
                trend.append(record)
            }
        }
        return trend
    }

    // MARK: - 课程掌握度变化曲线
    /// 生成课程掌握度历史数据点，用于绘制变化曲线。
    /// 当前基于当前掌握度回溯模拟历史数据；接入 Core Data 后可替换为真实历史记录。
    static func masteryHistoryPoints(courses: [Course], days: Int) -> [MasteryHistoryPoint] {
        var points: [MasteryHistoryPoint] = []
        for course in courses {
            let current = course.masteryAverage
            for i in 0..<days {
                let dayIndex = days - 1 - i
                let factor = 1.0 - Double(i) * 0.015
                let historicalMastery = max(0, min(1, current * factor))
                points.append(MasteryHistoryPoint(
                    dayIndex: dayIndex,
                    courseName: course.name.courseShortName,
                    colorKey: course.colorKey,
                    mastery: historicalMastery
                ))
            }
        }
        return points
    }

    // MARK: - 答题正确率趋势
    /// 计算指定天数内的每日答题正确率。
    /// 返回按日期排序的元组数组：(日期, 正确率, 答题总数)
    static func accuracyTrend(attempts: [QuizAttempt], days: Int) -> [(date: Date, accuracy: Double, total: Int)] {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let grouped = Dictionary(grouping: attempts) { attempt in
            formatDateKey(attempt.createdAt)
        }

        var result: [(Date, Double, Int)] = []
        for dayOffset in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                let key = formatDateKey(date)
                let dayAttempts = grouped[key] ?? []
                let total = dayAttempts.count
                let correct = dayAttempts.filter(\.isCorrect).count
                let accuracy = total > 0 ? Double(correct) / Double(total) : 0
                result.append((date, accuracy, total))
            }
        }
        return result
    }

    // MARK: - 艾宾浩斯遗忘曲线复习建议
    /// 基于艾宾浩斯遗忘曲线生成错题复习建议。
    /// 遗忘曲线节点：20分钟、1小时、9小时、1天、2天、6天、31天。
    static func ebbinghausReviewSuggestions(attempts: [QuizAttempt]) -> [EbbinghausSuggestion] {
        let intervals: [TimeInterval] = [20 * 60, 60 * 60, 9 * 60 * 60, 86400, 172800, 518400, 2678400]
        let intervalLabels = ["20分钟后", "1小时后", "9小时后", "1天后", "2天后", "6天后", "31天后"]
        let overdueTolerance: Double = 1.5

        let wrongAttempts = attempts.filter { !$0.isCorrect }
        var suggestions: [EbbinghausSuggestion] = []

        for attempt in wrongAttempts {
            let elapsed = max(0, Date().timeIntervalSince(attempt.createdAt))
            guard let stage = intervals.indices.min(by: {
                abs(elapsed - intervals[$0]) < abs(elapsed - intervals[$1])
            }) else { continue }
            let interval = intervals[stage]
            suggestions.append(EbbinghausSuggestion(
                questionID: attempt.questionID,
                knowledgePointID: attempt.knowledgePointID,
                stage: stage,
                stageLabel: intervalLabels[stage],
                elapsedHours: elapsed / 3600,
                isOverdue: elapsed > interval * overdueTolerance
            ))
        }
        return suggestions.sorted { $0.stage < $1.stage }
    }

    // MARK: - 学习热力图
    /// 按星期几分组统计学习时长，返回热力图数据。
    /// 每个条目包含：星期索引、星期标签、学习小时数、强度值(0-1)。
    static func studyHeatmap(records: [DailyStudyRecord]) -> [(weekday: Int, weekdayLabel: String, hours: Double, intensity: Double)] {
        let grouped = Dictionary(grouping: records) { $0.weekdayIndex }
        let maxMinutes = max(records.map { $0.studyMinutes }.max() ?? 1, 1)

        let weekdays = [
            (1, "周日"), (2, "周一"), (3, "周二"), (4, "周三"),
            (5, "周四"), (6, "周五"), (7, "周六")
        ]

        return weekdays.map { index, label in
            let dayRecords = grouped[index] ?? []
            let totalMinutes = dayRecords.reduce(0) { $0 + $1.studyMinutes }
            let hours = Double(totalMinutes) / 60.0
            let intensity = Double(totalMinutes) / Double(maxMinutes)
            return (index, label, hours, intensity)
        }
    }

    // MARK: - 知识点状态分布
    /// 统计所有课程中知识点的状态分布。
    /// 返回每种状态的：(状态枚举, 数量, 占比)
    static func knowledgeStatusDistribution(courses: [Course]) -> [(status: KnowledgeStatus, count: Int, percentage: Double)] {
        let allPoints = courses.flatMap(\.knowledgePoints)
        let total = allPoints.count
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: allPoints) { $0.status }
        return [KnowledgeStatus.notStarted, .inProgress, .mastered, .weak].map { status in
            let count = grouped[status]?.count ?? 0
            let percentage = Double(count) / Double(total)
            return (status, count, percentage)
        }
    }

    // MARK: - 从 Store 生成每日记录
    /// 从 FinalPilotStore 的现有数据生成 DailyStudyRecord 数组。
    /// 用于在尚未接入 Core Data 时，从 attempts 和 tasks 反推每日学习数据。
    @MainActor
    static func generateDailyRecords(from store: FinalPilotStore) -> [DailyStudyRecord] {
        var records: [DailyStudyRecord] = []
        let calendar = Calendar.current

        let groupedAttempts = Dictionary(grouping: store.attempts) {
            formatDateKey($0.createdAt)
        }

        let doneTasks = store.tasks.filter { $0.status == .done }
        let totalTaskMinutes = doneTasks.reduce(0) { $0 + $1.minutes }
        let totalTaskCount = doneTasks.count

        if groupedAttempts.isEmpty {
            // 无答题记录时，生成今日汇总记录
            let record = DailyStudyRecord(
                id: "record_today",
                date: calendar.startOfDay(for: Date()),
                courseID: nil,
                courseName: "综合学习",
                studyMinutes: totalTaskMinutes,
                completedTasks: totalTaskCount,
                totalQuestions: 0,
                correctQuestions: 0,
                weakPointChanges: []
            )
            records.append(record)
        } else {
            for (dateKey, dayAttempts) in groupedAttempts {
                let correct = dayAttempts.filter(\.isCorrect).count
                let total = dayAttempts.count

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let date = formatter.date(from: dateKey) ?? calendar.startOfDay(for: Date())

                let proportion = !store.attempts.isEmpty ? Double(total) / Double(store.attempts.count) : 0
                let estimatedMinutes = Int(Double(totalTaskMinutes) * proportion)
                let estimatedTasks = max(Int(Double(totalTaskCount) * proportion), total > 0 ? 1 : 0)

                let record = DailyStudyRecord(
                    id: "record_\(dateKey)",
                    date: date,
                    courseID: nil,
                    courseName: "综合学习",
                    studyMinutes: estimatedMinutes,
                    completedTasks: estimatedTasks,
                    totalQuestions: total,
                    correctQuestions: correct,
                    weakPointChanges: []
                )
                records.append(record)
            }
        }

        return records.sorted { $0.date < $1.date }
    }

    // MARK: - 辅助方法
    private static func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - 辅助结构体

struct MasteryHistoryPoint: Identifiable {
    let id = UUID().uuidString
    let dayIndex: Int
    let courseName: String
    let colorKey: String
    let mastery: Double
}

struct EbbinghausSuggestion: Identifiable {
    let id = UUID().uuidString
    var questionID: String
    var knowledgePointID: String
    var stage: Int
    var stageLabel: String
    var elapsedHours: Double
    var isOverdue: Bool
}

// MARK: - String 扩展
private extension String {
    var courseShortName: String {
        if hasPrefix("C310") { return "C310" }
        if hasPrefix("E320") { return "E320" }
        return self
    }
}
