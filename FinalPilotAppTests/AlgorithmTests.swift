import XCTest
@testable import FinalPilotApp

// MARK: - AlgorithmTests
/// 测试 StudyStatistics 中的纯算法逻辑。
/// 覆盖艾宾浩斯遗忘曲线、学习热力图、掌握度变化模拟、正确率趋势等统计方法。
final class AlgorithmTests: XCTestCase, @unchecked Sendable {

    // MARK: - 艾宾浩斯遗忘曲线复习建议测试

    /// 测试：无错题时返回空建议列表
    func testEbbinghausReviewSuggestions_NoWrongAttempts() async {
        await MainActor.run {
            let attempts = [
                QuizAttempt(id: "a1", questionID: "q1", knowledgePointID: "kp1", selectedAnswer: "A", isCorrect: true, confidence: .high, createdAt: Date()),
                QuizAttempt(id: "a2", questionID: "q2", knowledgePointID: "kp2", selectedAnswer: "B", isCorrect: true, confidence: .medium, createdAt: Date())
            ]

            let suggestions = StudyStatistics.ebbinghausReviewSuggestions(attempts: attempts)

            XCTAssertTrue(suggestions.isEmpty)
        }
    }

    /// 测试：单个错题在 20 分钟阶段产生建议
    func testEbbinghausReviewSuggestions_SingleStage() async {
        await MainActor.run {
            // 给定：15 分钟前的错题（处于 20 分钟阶段）
            let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
            let attempts = [
                QuizAttempt(id: "a1", questionID: "q1", knowledgePointID: "kp1", selectedAnswer: "A", isCorrect: false, confidence: .high, createdAt: fifteenMinutesAgo)
            ]

            let suggestions = StudyStatistics.ebbinghausReviewSuggestions(attempts: attempts)

            XCTAssertEqual(suggestions.count, 1)
            XCTAssertEqual(suggestions.first?.stage, 0)
            XCTAssertEqual(suggestions.first?.stageLabel, "20分钟后")
        }
    }

    /// 测试：多个错题分布在不同遗忘阶段
    func testEbbinghausReviewSuggestions_MultipleStages() async {
        await MainActor.run {
            // 给定：分别处于 20 分钟、1 小时、1 天阶段的错题
            let attempts = [
                QuizAttempt(id: "a1", questionID: "q1", knowledgePointID: "kp1", selectedAnswer: "A", isCorrect: false, confidence: .high, createdAt: Date().addingTimeInterval(-15 * 60)),
                QuizAttempt(id: "a2", questionID: "q2", knowledgePointID: "kp2", selectedAnswer: "B", isCorrect: false, confidence: .medium, createdAt: Date().addingTimeInterval(-45 * 60)),
                QuizAttempt(id: "a3", questionID: "q3", knowledgePointID: "kp3", selectedAnswer: "C", isCorrect: false, confidence: .low, createdAt: Date().addingTimeInterval(-25 * 60 * 60))
            ]

            let suggestions = StudyStatistics.ebbinghausReviewSuggestions(attempts: attempts)

            XCTAssertEqual(suggestions.count, 3)
            // 按 stage 排序
            let stages = suggestions.map { $0.stage }
            XCTAssertEqual(stages, stages.sorted())
        }
    }

    /// 测试：超过两倍间隔时间后标记为逾期
    func testEbbinghausReviewSuggestions_Overdue() async {
        await MainActor.run {
            // 3.5 天距离 2 天阶段最近，且已超过 1.5 倍容忍窗口。
            let overdueDate = Date().addingTimeInterval(-3.5 * 24 * 60 * 60)
            let attempts = [
                QuizAttempt(id: "a1", questionID: "q1", knowledgePointID: "kp1", selectedAnswer: "A", isCorrect: false, confidence: .high, createdAt: overdueDate)
            ]

            let suggestions = StudyStatistics.ebbinghausReviewSuggestions(attempts: attempts)

            XCTAssertEqual(suggestions.count, 1)
            XCTAssertEqual(suggestions.first?.stage, 4)
            XCTAssertTrue(suggestions.first?.isOverdue == true)
        }
    }

    /// 测试：建议按 stage 升序排列
    func testEbbinghausReviewSuggestions_SortedByStage() async {
        await MainActor.run {
            let attempts = [
                QuizAttempt(id: "a1", questionID: "q1", knowledgePointID: "kp1", selectedAnswer: "A", isCorrect: false, confidence: .high, createdAt: Date().addingTimeInterval(-25 * 60 * 60)), // 1 天后 stage 3
                QuizAttempt(id: "a2", questionID: "q2", knowledgePointID: "kp2", selectedAnswer: "B", isCorrect: false, confidence: .medium, createdAt: Date().addingTimeInterval(-15 * 60)) // 20 分钟后 stage 0
            ]

            let suggestions = StudyStatistics.ebbinghausReviewSuggestions(attempts: attempts)

            XCTAssertEqual(suggestions.count, 2)
            XCTAssertEqual(suggestions[0].stage, 0)
            XCTAssertEqual(suggestions[1].stage, 3)
        }
    }

    // MARK: - 学习热力图测试

    /// 测试：空记录时返回 7 天数据，但强度均为 0
    func testStudyHeatmap_EmptyRecords() async {
        await MainActor.run {
            let records: [DailyStudyRecord] = []

            let heatmap = StudyStatistics.studyHeatmap(records: records)

            XCTAssertEqual(heatmap.count, 7)
            XCTAssertTrue(heatmap.allSatisfy { $0.hours == 0 && $0.intensity == 0 })
        }
    }

    /// 测试：正常分布的学习记录应生成正确热力图
    func testStudyHeatmap_NormalDistribution() async {
        await MainActor.run {
            // 给定：周一学习 120 分钟，周二学习 60 分钟，其余为 0
            let monday = calendarDate(weekday: 2) // 周一
            let tuesday = calendarDate(weekday: 3) // 周二
            let records = [
                DailyStudyRecord(id: "r1", date: monday, studyMinutes: 120, completedTasks: 2, totalQuestions: 10, correctQuestions: 8, weakPointChanges: []),
                DailyStudyRecord(id: "r2", date: tuesday, studyMinutes: 60, completedTasks: 1, totalQuestions: 5, correctQuestions: 3, weakPointChanges: [])
            ]

            let heatmap = StudyStatistics.studyHeatmap(records: records)

            XCTAssertEqual(heatmap.count, 7)
            let mondayData = heatmap.first { $0.weekdayLabel == "周一" }!
            let tuesdayData = heatmap.first { $0.weekdayLabel == "周二" }!
            XCTAssertEqual(mondayData.hours, 2.0, accuracy: 0.001) // 120 分钟 = 2 小时
            XCTAssertEqual(tuesdayData.hours, 1.0, accuracy: 0.001) // 60 分钟 = 1 小时
        }
    }

    /// 测试：强度值应正确计算（当前日 / 最大日）
    func testStudyHeatmap_IntensityCalculation() async {
        await MainActor.run {
            let monday = calendarDate(weekday: 2)
            let tuesday = calendarDate(weekday: 3)
            let records = [
                DailyStudyRecord(id: "r1", date: monday, studyMinutes: 120, completedTasks: 2, totalQuestions: 10, correctQuestions: 8, weakPointChanges: []),
                DailyStudyRecord(id: "r2", date: tuesday, studyMinutes: 60, completedTasks: 1, totalQuestions: 5, correctQuestions: 3, weakPointChanges: [])
            ]

            let heatmap = StudyStatistics.studyHeatmap(records: records)

            let mondayData = heatmap.first { $0.weekdayLabel == "周一" }!
            let tuesdayData = heatmap.first { $0.weekdayLabel == "周二" }!
            XCTAssertEqual(mondayData.intensity, 1.0, accuracy: 0.001) // 最大值，强度为 1
            XCTAssertEqual(tuesdayData.intensity, 0.5, accuracy: 0.001) // 60/120 = 0.5
        }
    }

    /// 测试：所有天都有记录时返回完整热力图
    func testStudyHeatmap_AllDays() async {
        await MainActor.run {
            let records = (1...7).map { weekday in
                DailyStudyRecord(
                    id: "r\(weekday)",
                    date: calendarDate(weekday: weekday),
                    studyMinutes: weekday * 10,
                    completedTasks: 1,
                    totalQuestions: 5,
                    correctQuestions: 3,
                    weakPointChanges: []
                )
            }

            let heatmap = StudyStatistics.studyHeatmap(records: records)

            XCTAssertEqual(heatmap.count, 7)
            XCTAssertEqual(heatmap[0].weekdayLabel, "周日")
            XCTAssertEqual(heatmap[6].weekdayLabel, "周六")
        }
    }

    // MARK: - 掌握度变化曲线测试

    /// 测试：生成的历史点数数量应等于 days 参数
    func testMasteryHistoryPoints_Count() async {
        await MainActor.run {
            let courses = SeedData.courses
            let days = 7

            let points = StudyStatistics.masteryHistoryPoints(courses: courses, days: days)

            // 每门课程生成 days 个点
            XCTAssertEqual(points.count, courses.count * days)
        }
    }

    /// 测试：历史掌握度值应在 [0, 1] 范围内
    func testMasteryHistoryPoints_Range() async {
        await MainActor.run {
            let courses = SeedData.courses
            let points = StudyStatistics.masteryHistoryPoints(courses: courses, days: 30)

            XCTAssertTrue(points.allSatisfy { $0.mastery >= 0 && $0.mastery <= 1 })
        }
    }

    /// 测试：dayIndex 应从 0 到 days-1 递增
    func testMasteryHistoryPoints_DayIndexOrder() async {
        await MainActor.run {
            let course = SeedData.courses[0]
            let days = 7

            let points = StudyStatistics.masteryHistoryPoints(courses: [course], days: days)
                .filter { $0.colorKey == course.colorKey }

            XCTAssertEqual(points.count, days)
            let dayIndices = points.map { $0.dayIndex }.sorted()
            XCTAssertEqual(dayIndices, Array(0..<days))
        }
    }

    /// 测试：历史掌握度应随 dayIndex 递减（回溯模拟）
    func testMasteryHistoryPoints_DecreasingTrend() async {
        await MainActor.run {
            let course = SeedData.courses[0]
            let days = 7

            let points = StudyStatistics.masteryHistoryPoints(courses: [course], days: days)
                .sorted { $0.dayIndex < $1.dayIndex }

            // 越久远（dayIndex 越小）的掌握度应越低或相等
            for i in 1..<points.count {
                XCTAssertLessThanOrEqual(points[i-1].mastery, points[i].mastery)
            }
        }
    }

    // MARK: - 答题正确率趋势测试

    /// 测试：无答题记录时返回 0 正确率
    func testAccuracyTrend_NoAttempts() async {
        await MainActor.run {
            let attempts: [QuizAttempt] = []
            let days = 7

            let trend = StudyStatistics.accuracyTrend(attempts: attempts, days: days)

            XCTAssertEqual(trend.count, days)
            XCTAssertTrue(trend.allSatisfy { $0.accuracy == 0 && $0.total == 0 })
        }
    }

    /// 测试：有答题记录时正确率计算准确
    func testAccuracyTrend_WithAttempts() async {
        await MainActor.run {
            let today = Calendar.current.startOfDay(for: Date())
            let attempts = [
                QuizAttempt(id: "a1", questionID: "q1", knowledgePointID: "kp1", selectedAnswer: "A", isCorrect: true, confidence: .high, createdAt: today),
                QuizAttempt(id: "a2", questionID: "q2", knowledgePointID: "kp2", selectedAnswer: "B", isCorrect: true, confidence: .medium, createdAt: today),
                QuizAttempt(id: "a3", questionID: "q3", knowledgePointID: "kp3", selectedAnswer: "C", isCorrect: false, confidence: .low, createdAt: today)
            ]
            let days = 7

            let trend = StudyStatistics.accuracyTrend(attempts: attempts, days: days)

            XCTAssertEqual(trend.count, days)
            let todayTrend = trend.first { Calendar.current.isDate($0.date, inSameDayAs: today) }!
            XCTAssertEqual(todayTrend.accuracy, 2.0 / 3.0, accuracy: 0.001)
            XCTAssertEqual(todayTrend.total, 3)
        }
    }

    // MARK: - 学习趋势测试

    /// 测试：正常学习记录聚合
    func testStudyTrend_Normal() async {
        await MainActor.run {
            let today = Calendar.current.startOfDay(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let records = [
                DailyStudyRecord(id: "r1", date: today, studyMinutes: 60, completedTasks: 2, totalQuestions: 10, correctQuestions: 7, weakPointChanges: []),
                DailyStudyRecord(id: "r2", date: today, studyMinutes: 30, completedTasks: 1, totalQuestions: 5, correctQuestions: 4, weakPointChanges: []),
                DailyStudyRecord(id: "r3", date: yesterday, studyMinutes: 90, completedTasks: 3, totalQuestions: 8, correctQuestions: 6, weakPointChanges: [])
            ]

            let trend = StudyStatistics.studyTrend(records: records, days: 7)

            //  today's total = 60 + 30 = 90 minutes, 3 tasks, 15 questions, 11 correct
            let todayTrend = trend.first { Calendar.current.isDate($0.date, inSameDayAs: today) }!
            XCTAssertEqual(todayTrend.studyMinutes, 90)
            XCTAssertEqual(todayTrend.completedTasks, 3)
            XCTAssertEqual(todayTrend.totalQuestions, 15)
            XCTAssertEqual(todayTrend.correctQuestions, 11)

            //  yesterday's total = 90 minutes, 3 tasks, 8 questions, 6 correct
            let yesterdayTrend = trend.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }!
            XCTAssertEqual(yesterdayTrend.studyMinutes, 90)
        }
    }

    /// 测试：无记录的天应返回 0 值记录
    func testStudyTrend_EmptyDaysFilled() async {
        await MainActor.run {
            let records: [DailyStudyRecord] = []
            let days = 7

            let trend = StudyStatistics.studyTrend(records: records, days: days)

            XCTAssertEqual(trend.count, days)
            XCTAssertTrue(trend.allSatisfy { $0.studyMinutes == 0 && $0.completedTasks == 0 })
        }
    }

    // MARK: - 知识点状态分布测试

    /// 测试：状态分布总和应为 1（100%）
    func testKnowledgeStatusDistribution_TotalPercentage() async {
        await MainActor.run {
            let courses = SeedData.courses
            let distribution = StudyStatistics.knowledgeStatusDistribution(courses: courses)

            let totalPercentage = distribution.reduce(0.0) { $0 + $1.percentage }
            XCTAssertEqual(totalPercentage, 1.0, accuracy: 0.001)
        }
    }

    /// 测试：分布计数总和应等于知识点总数
    func testKnowledgeStatusDistribution_TotalCount() async {
        await MainActor.run {
            let courses = SeedData.courses
            let distribution = StudyStatistics.knowledgeStatusDistribution(courses: courses)

            let totalCount = distribution.reduce(0) { $0 + $1.count }
            let expectedCount = courses.flatMap(\.knowledgePoints).count
            XCTAssertEqual(totalCount, expectedCount)
        }
    }

    /// 测试：空课程返回空分布
    func testKnowledgeStatusDistribution_EmptyCourses() async {
        await MainActor.run {
            let distribution = StudyStatistics.knowledgeStatusDistribution(courses: [])
            XCTAssertTrue(distribution.isEmpty)
        }
    }

    // MARK: - 从 Store 生成每日记录测试

    /// 测试：无答题记录时从 Store 生成单条今日记录
    func testGenerateDailyRecords_NoAttempts() async {
        await MainActor.run {
            let store = FinalPilotStore(attempts: [])
            let records = StudyStatistics.generateDailyRecords(from: store)

            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records.first?.courseName, "综合学习")
        }
    }

    /// 测试：有答题记录时按日期分组
    func testGenerateDailyRecords_WithAttempts() async {
        await MainActor.run {
            let today = Calendar.current.startOfDay(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let attempts = [
                QuizAttempt(id: "a1", questionID: "q1", knowledgePointID: "kp1", selectedAnswer: "A", isCorrect: true, confidence: .high, createdAt: today),
                QuizAttempt(id: "a2", questionID: "q2", knowledgePointID: "kp2", selectedAnswer: "B", isCorrect: false, confidence: .low, createdAt: today),
                QuizAttempt(id: "a3", questionID: "q3", knowledgePointID: "kp3", selectedAnswer: "C", isCorrect: true, confidence: .medium, createdAt: yesterday)
            ]
            let store = FinalPilotStore(attempts: attempts)
            let records = StudyStatistics.generateDailyRecords(from: store)

            // 应有 2 条记录（今天和昨天）
            XCTAssertEqual(records.count, 2)
        }
    }

    // MARK: - 辅助方法

    /// 构造一个指定星期几的日期（用于热力图测试）
    /// weekday: 1=周日, 2=周一, ..., 7=周六
    private func calendarDate(weekday: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = 2026
        components.month = 5
        // 2026-05-01 是周五 (weekday=6)
        // 需要找到目标 weekday 的日期
        let baseDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let baseWeekday = Calendar.current.component(.weekday, from: baseDate)
        let offset = (weekday - baseWeekday + 7) % 7
        return Calendar.current.date(byAdding: .day, value: offset, to: baseDate)!
    }
}
