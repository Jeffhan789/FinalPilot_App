import XCTest
@testable import FinalPilotApp

// MARK: - StoreLogicTests
/// 测试 FinalPilotStore 的核心业务逻辑。
/// 覆盖任务状态切换、答题提交、掌握度更新、日期计算和任务桶排序。
final class StoreLogicTests: XCTestCase, @unchecked Sendable {

    @MainActor private lazy var store = FinalPilotStore(sideEffectsEnabled: false)

    // MARK: - toggleTask 测试

    /// 测试：任务从 pending 切换为 done
    func testToggleTask_PendingToDone() async {
        await MainActor.run {
            // 给定：找到一个 pending 状态的任务
            let task = store.tasks.first { $0.status == .pending }!
            XCTAssertEqual(task.status, .pending)

            // 当：执行 toggle
            store.toggleTask(task)

            // 那么：任务状态变为 done
            let updated = store.tasks.first { $0.id == task.id }!
            XCTAssertEqual(updated.status, .done)
        }
    }

    /// 测试：任务从 done 切换回 pending
    func testToggleTask_DoneToPending() async {
        await MainActor.run {
            // 给定：先将一个任务设为 done
            let task = store.tasks.first { $0.status == .pending }!
            store.toggleTask(task)
            var updated = store.tasks.first { $0.id == task.id }!
            XCTAssertEqual(updated.status, .done)

            // 当：再次 toggle
            store.toggleTask(updated)

            // 那么：任务状态恢复为 pending
            updated = store.tasks.first { $0.id == task.id }!
            XCTAssertEqual(updated.status, .pending)
        }
    }

    /// 测试：toggle 不存在的任务时不应崩溃，且任务列表不变
    func testToggleTask_NotFound() async {
        await MainActor.run {
            // 给定：一个不存在的任务
            let fakeTask = StudyTask(
                id: "non_existent_task",
                track: .exam,
                bucket: .must,
                title: "假任务",
                subtitle: "测试用",
                minutes: 10,
                reason: "测试边界",
                linkedCourseID: nil,
                status: .pending
            )
            let originalCount = store.tasks.count

            // 当：toggle 不存在的任务
            store.toggleTask(fakeTask)

            // 那么：任务列表数量和内容均不变
            XCTAssertEqual(store.tasks.count, originalCount)
        }
    }

    /// 测试：只有一个任务时的 toggle 边界条件
    func testToggleTask_SingleTaskBoundary() async {
        await MainActor.run {
            // 给定：只有一个任务的 Store
            let singleTask = StudyTask(
                id: "single_task",
                track: .exam,
                bucket: .must,
                title: "唯一任务",
                subtitle: "边界测试",
                minutes: 30,
                reason: "测试",
                linkedCourseID: nil,
                status: .pending
            )
            let singleStore = FinalPilotStore(tasks: [singleTask], sideEffectsEnabled: false)

            // 当：toggle
            singleStore.toggleTask(singleTask)

            // 那么：状态正确切换
            XCTAssertEqual(singleStore.tasks.first!.status, .done)
            XCTAssertEqual(singleStore.tasks.count, 1)
        }
    }

    // MARK: - submitAnswer 测试

    /// 测试：正确答案 + 高自信度，掌握度应增加 0.08
    func testSubmitAnswer_CorrectHighConfidence() async {
        await MainActor.run {
            // 给定：一道已知答案的题目
            let question = store.allQuestions.first!
            let initialMastery = masteryFor(question: question)

            // 当：提交正确答案，高自信度
            let attempt = store.submitAnswer(question: question, selectedAnswer: question.answer, confidence: .high)

            // 那么：判定为正确，掌握度增加 0.08
            XCTAssertTrue(attempt.isCorrect)
            XCTAssertEqual(attempt.confidence, .high)
            let newMastery = masteryFor(question: question)
            XCTAssertEqual(newMastery, min(1.0, initialMastery + 0.08), accuracy: 0.001)
        }
    }

    /// 测试：正确答案 + 低自信度，掌握度应增加 0.04
    func testSubmitAnswer_CorrectLowConfidence() async {
        await MainActor.run {
            let question = store.allQuestions.first!
            let initialMastery = masteryFor(question: question)

            let attempt = store.submitAnswer(question: question, selectedAnswer: question.answer, confidence: .low)

            XCTAssertTrue(attempt.isCorrect)
            XCTAssertEqual(attempt.confidence, .low)
            let newMastery = masteryFor(question: question)
            XCTAssertEqual(newMastery, min(1.0, initialMastery + 0.04), accuracy: 0.001)
        }
    }

    /// 测试：错误答案 + 高自信度，掌握度应减少 0.16
    func testSubmitAnswer_WrongHighConfidence() async {
        await MainActor.run {
            let question = store.allQuestions.first!
            let initialMastery = masteryFor(question: question)

            let attempt = store.submitAnswer(question: question, selectedAnswer: "明显错误的答案", confidence: .high)

            XCTAssertFalse(attempt.isCorrect)
            XCTAssertEqual(attempt.confidence, .high)
            let newMastery = masteryFor(question: question)
            XCTAssertEqual(newMastery, max(0.0, initialMastery - 0.16), accuracy: 0.001)
        }
    }

    /// 测试：错误答案 + 低自信度，掌握度应减少 0.10
    func testSubmitAnswer_WrongLowConfidence() async {
        await MainActor.run {
            let question = store.allQuestions.first!
            let initialMastery = masteryFor(question: question)

            let attempt = store.submitAnswer(question: question, selectedAnswer: "明显错误的答案", confidence: .low)

            XCTAssertFalse(attempt.isCorrect)
            XCTAssertEqual(attempt.confidence, .low)
            let newMastery = masteryFor(question: question)
            XCTAssertEqual(newMastery, max(0.0, initialMastery - 0.10), accuracy: 0.001)
        }
    }

    /// 测试：答案去除首尾空白后仍能正确匹配
    func testSubmitAnswer_AnswerTrimming() async {
        await MainActor.run {
            let question = store.allQuestions.first!

            // 给定：带前导和尾随空白的正确答案
            let paddedAnswer = "  \(question.answer)  "
            let attempt = store.submitAnswer(question: question, selectedAnswer: paddedAnswer, confidence: .medium)

            // 那么：trim 后应判定为正确
            XCTAssertTrue(attempt.isCorrect)
        }
    }

    /// 测试：提交答题后 attempts 列表应插入到首位
    func testSubmitAnswer_InsertAtFront() async {
        await MainActor.run {
            let question = store.allQuestions.first!
            let initialAttemptsCount = store.attempts.count

            _ = store.submitAnswer(question: question, selectedAnswer: question.answer, confidence: .medium)

            XCTAssertEqual(store.attempts.count, initialAttemptsCount + 1)
            XCTAssertEqual(store.attempts.first?.questionID, question.id)
        }
    }

    // MARK: - updateMastery 阈值测试（通过 submitAnswer 间接验证）

    /// 测试：掌握度超过 0.72 后状态变为 mastered
    func testUpdateMastery_ThresholdAbove0_72() async {
        await MainActor.run {
            // 给定：一个初始掌握度为 0.70 的知识点（答对+高自信度后应为 0.78）
            let question = questionForKnowledgePoint(initialMastery: 0.70)
            guard let question = question else {
                XCTFail("测试种子中缺少可用知识点")
                return
            }

            // 当：答对 + 高自信度 (+0.08)
            store.submitAnswer(question: question, selectedAnswer: question.answer, confidence: .high)

            // 那么：掌握度 >= 0.72，状态变为 mastered
            let newMastery = masteryFor(question: question)
            let newStatus = statusFor(question: question)
            XCTAssertGreaterThanOrEqual(newMastery, 0.72)
            XCTAssertEqual(newStatus, .mastered)
        }
    }

    /// 测试：掌握度低于 0.38 后状态变为 weak
    func testUpdateMastery_ThresholdBelow0_38() async {
        await MainActor.run {
            // 给定：一个初始掌握度为 0.35 的知识点（答错+高自信度后应为 0.19）
            let question = questionForKnowledgePoint(initialMastery: 0.35)
            guard let question = question else {
                XCTFail("测试种子中缺少可用知识点")
                return
            }

            // 当：答错 + 高自信度 (-0.16)
            store.submitAnswer(question: question, selectedAnswer: "错误答案", confidence: .high)

            // 那么：掌握度 < 0.38，状态变为 weak
            let newMastery = masteryFor(question: question)
            let newStatus = statusFor(question: question)
            XCTAssertLessThan(newMastery, 0.38)
            XCTAssertEqual(newStatus, .weak)
        }
    }

    /// 测试：掌握度在 0.38 到 0.72 之间时状态为 inProgress
    func testUpdateMastery_BetweenThresholds() async {
        await MainActor.run {
            // 给定：一个初始掌握度为 0.50 的知识点
            let question = questionForKnowledgePoint(initialMastery: 0.50)
            guard let question = question else {
                XCTFail("测试种子中缺少可用知识点")
                return
            }

            // 当：答对 + 低自信度 (+0.04 -> 0.54)
            store.submitAnswer(question: question, selectedAnswer: question.answer, confidence: .low)

            // 那么：状态应为 inProgress
            let newStatus = statusFor(question: question)
            XCTAssertEqual(newStatus, .inProgress)
        }
    }

    /// 测试：边界值——掌握度刚好达到 0.72 时状态变为 mastered
    func testUpdateMastery_BoundaryAt0_72() async {
        await MainActor.run {
            // 给定：初始掌握度 0.64，答对+高自信度 (+0.08) = 0.72
            let question = questionForKnowledgePoint(initialMastery: 0.64)
            guard let question = question else {
                XCTFail("测试种子中缺少可用知识点")
                return
            }

            store.submitAnswer(question: question, selectedAnswer: question.answer, confidence: .high)

            let newMastery = masteryFor(question: question)
            let newStatus = statusFor(question: question)
            XCTAssertEqual(newMastery, 0.72, accuracy: 0.001)
            XCTAssertEqual(newStatus, .mastered)
        }
    }

    /// 测试：边界值——掌握度刚好低于 0.38 时状态变为 weak
    func testUpdateMastery_BoundaryAt0_38() async {
        await MainActor.run {
            // 给定：初始掌握度 0.48，答错+高自信度 (-0.16) = 0.32
            let question = questionForKnowledgePoint(initialMastery: 0.48)
            guard let question = question else {
                XCTFail("测试种子中缺少可用知识点")
                return
            }

            store.submitAnswer(question: question, selectedAnswer: "错误答案", confidence: .high)

            let newMastery = masteryFor(question: question)
            let newStatus = statusFor(question: question)
            XCTAssertEqual(newMastery, 0.32, accuracy: 0.001)
            XCTAssertLessThan(newMastery, 0.38)
            XCTAssertEqual(newStatus, .weak)
        }
    }

    /// 测试：掌握度不会溢出超过 1.0
    func testUpdateMastery_UpperBound() async {
        await MainActor.run {
            // 给定：初始掌握度 0.98 的知识点
            let question = questionForKnowledgePoint(initialMastery: 0.98)
            guard let question = question else {
                XCTFail("测试种子中缺少可用知识点")
                return
            }

            // 当：答对 + 高自信度 (+0.08)
            store.submitAnswer(question: question, selectedAnswer: question.answer, confidence: .high)

            // 那么：掌握度上限为 1.0
            let newMastery = masteryFor(question: question)
            XCTAssertEqual(newMastery, 1.0, accuracy: 0.001)
            XCTAssertEqual(statusFor(question: question), .mastered)
        }
    }

    /// 测试：掌握度不会下溢低于 0.0
    func testUpdateMastery_LowerBound() async {
        await MainActor.run {
            // 给定：初始掌握度 0.05 的知识点
            let question = questionForKnowledgePoint(initialMastery: 0.05)
            guard let question = question else {
                XCTFail("测试种子中缺少可用知识点")
                return
            }

            // 当：答错 + 高自信度 (-0.16)
            store.submitAnswer(question: question, selectedAnswer: "错误答案", confidence: .high)

            // 那么：掌握度下限为 0.0
            let newMastery = masteryFor(question: question)
            XCTAssertEqual(newMastery, 0.0, accuracy: 0.001)
            XCTAssertEqual(statusFor(question: question), .weak)
        }
    }

    // MARK: - daysUntil 测试

    /// 测试：同一天的日期差应为 0
    func testDaysUntil_SameDay() async {
        await MainActor.run {
            let now = Date.finalPilotDate(month: 5, day: 10, hour: 10)
            let target = Date.finalPilotDate(month: 5, day: 10, hour: 18)

            let days = store.daysUntil(target, from: now)

            XCTAssertEqual(days, 0)
        }
    }

    /// 测试：未来日期应返回正数
    func testDaysUntil_Future() async {
        await MainActor.run {
            let now = Date.finalPilotDate(month: 5, day: 10, hour: 10)
            let target = Date.finalPilotDate(month: 5, day: 13, hour: 10)

            let days = store.daysUntil(target, from: now)

            XCTAssertEqual(days, 3)
        }
    }

    /// 测试：过去日期应返回负数
    func testDaysUntil_Past() async {
        await MainActor.run {
            let now = Date.finalPilotDate(month: 5, day: 13, hour: 10)
            let target = Date.finalPilotDate(month: 5, day: 10, hour: 10)

            let days = store.daysUntil(target, from: now)

            XCTAssertEqual(days, -3)
        }
    }

    /// 测试：nil 日期应返回 nil
    func testDaysUntil_Nil() async {
        await MainActor.run {
            let days = store.daysUntil(nil)
            XCTAssertNil(days)
        }
    }

    /// 测试：跨月份的日期计算
    func testDaysUntil_CrossMonth() async {
        await MainActor.run {
            let now = Date.finalPilotDate(month: 5, day: 30, hour: 10)
            let target = Date.finalPilotDate(month: 6, day: 3, hour: 10)

            let days = store.daysUntil(target, from: now)

            XCTAssertEqual(days, 4)
        }
    }

    // MARK: - bucketOrder 测试（通过 tasks(track:) 间接验证）

    /// 测试：must 桶的任务排在 should 桶之前
    func testBucketOrder_MustBeforeShould() async {
        await MainActor.run {
            // 给定：创建 must 和 should 的混合任务
            let mustTask = StudyTask(
                id: "t_must", track: .exam, bucket: .must,
                title: "Must", subtitle: "", minutes: 10, reason: "", linkedCourseID: nil, status: .pending
            )
            let shouldTask = StudyTask(
                id: "t_should", track: .exam, bucket: .should,
                title: "Should", subtitle: "", minutes: 10, reason: "", linkedCourseID: nil, status: .pending
            )
            let mixedStore = FinalPilotStore(tasks: [shouldTask, mustTask], sideEffectsEnabled: false)

            // 当：获取 exam track 的任务列表
            let sorted = mixedStore.tasks(track: .exam)

            // 那么：must 排在 should 前面
            let mustIndex = sorted.firstIndex { $0.id == "t_must" }!
            let shouldIndex = sorted.firstIndex { $0.id == "t_should" }!
            XCTAssertLessThan(mustIndex, shouldIndex)
        }
    }

    /// 测试：skip 桶的任务排在最后
    func testBucketOrder_SkipLast() async {
        await MainActor.run {
            let mustTask = StudyTask(
                id: "t_must", track: .exam, bucket: .must,
                title: "Must", subtitle: "", minutes: 10, reason: "", linkedCourseID: nil, status: .pending
            )
            let skipTask = StudyTask(
                id: "t_skip", track: .exam, bucket: .skip,
                title: "Skip", subtitle: "", minutes: 10, reason: "", linkedCourseID: nil, status: .deferred
            )
            let mixedStore = FinalPilotStore(tasks: [skipTask, mustTask], sideEffectsEnabled: false)

            let sorted = mixedStore.tasks(track: .exam)

            let mustIndex = sorted.firstIndex { $0.id == "t_must" }!
            let skipIndex = sorted.firstIndex { $0.id == "t_skip" }!
            XCTAssertLessThan(mustIndex, skipIndex)
        }
    }

    /// 测试：同 bucket 内按 minutes 降序排列
    func testBucketOrder_SameBucketByMinutesDesc() async {
        await MainActor.run {
            let shortTask = StudyTask(
                id: "t_short", track: .exam, bucket: .must,
                title: "Short", subtitle: "", minutes: 10, reason: "", linkedCourseID: nil, status: .pending
            )
            let longTask = StudyTask(
                id: "t_long", track: .exam, bucket: .must,
                title: "Long", subtitle: "", minutes: 60, reason: "", linkedCourseID: nil, status: .pending
            )
            let mixedStore = FinalPilotStore(tasks: [shortTask, longTask], sideEffectsEnabled: false)

            let sorted = mixedStore.tasks(track: .exam)

            let shortIndex = sorted.firstIndex { $0.id == "t_short" }!
            let longIndex = sorted.firstIndex { $0.id == "t_long" }!
            XCTAssertLessThan(longIndex, shortIndex)
        }
    }

    /// 测试：tasks(track:bucket:) 按指定 bucket 过滤
    func testTasks_FilterByBucket() async {
        await MainActor.run {
            let mustTasks = store.tasks(track: .exam, bucket: .must)
            XCTAssertTrue(mustTasks.allSatisfy { $0.bucket == .must })
        }
    }

    // MARK: - 辅助方法

    /// 获取与题目关联的知识点的当前掌握度
    @MainActor
    private func masteryFor(question: QuizQuestion) -> Double {
        guard let course = store.courses.first(where: { $0.id == question.courseID }),
              let point = course.knowledgePoints.first(where: { $0.id == question.knowledgePointID }) else {
            return 0
        }
        return point.mastery
    }

    /// 获取与题目关联的知识点的当前状态
    @MainActor
    private func statusFor(question: QuizQuestion) -> KnowledgeStatus {
        guard let course = store.courses.first(where: { $0.id == question.courseID }),
              let point = course.knowledgePoints.first(where: { $0.id == question.knowledgePointID }) else {
            return .notStarted
        }
        return point.status
    }

    /// 在 Store 中查找或构造一个具有指定初始掌握度的测试题目
    /// 由于 SeedData 是只读的，此方法通过替换整个 Course 来构造测试数据
    @MainActor
    private func questionForKnowledgePoint(initialMastery: Double) -> QuizQuestion? {
        // 尝试在 SeedData 中找到第一个有问题的课程
        guard let seedCourse = SeedData.courses.first(where: { !$0.questions.isEmpty && !$0.knowledgePoints.isEmpty }),
              let question = seedCourse.questions.first,
              let pointIndex = seedCourse.knowledgePoints.firstIndex(where: {
                  $0.id == question.knowledgePointID
              }) else {
            return nil
        }

        // 创建修改后的知识点（设置目标掌握度）
        let targetPoint = seedCourse.knowledgePoints[pointIndex]
        let modifiedPoint = KnowledgePoint(
            id: targetPoint.id,
            chapter: targetPoint.chapter,
            title: targetPoint.title,
            difficulty: targetPoint.difficulty,
            mastery: initialMastery,
            status: initialMastery >= 0.72 ? .mastered : (initialMastery < 0.38 ? .weak : .inProgress)
        )

        // 创建修改后的课程
        var modifiedPoints = seedCourse.knowledgePoints
        modifiedPoints[pointIndex] = modifiedPoint
        let modifiedCourse = Course(
            id: seedCourse.id,
            name: seedCourse.name,
            examDate: seedCourse.examDate,
            examDurationMinutes: seedCourse.examDurationMinutes,
            examLocation: seedCourse.examLocation,
            difficulty: seedCourse.difficulty,
            colorKey: seedCourse.colorKey,
            symbol: seedCourse.symbol,
            knowledgePoints: modifiedPoints,
            questions: seedCourse.questions
        )

        // 重建 Store，用修改后的课程替换原始课程
        var modifiedCourses = SeedData.courses
        if let index = modifiedCourses.firstIndex(where: { $0.id == seedCourse.id }) {
            modifiedCourses[index] = modifiedCourse
        }
        store = FinalPilotStore(
            courses: modifiedCourses,
            tasks: SeedData.tasks,
            attempts: [],
            sideEffectsEnabled: false
        )

        // 返回与该知识点关联的题目
        return question
    }
}
