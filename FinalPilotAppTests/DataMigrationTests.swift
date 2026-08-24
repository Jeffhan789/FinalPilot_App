import XCTest
import CoreData
@testable import FinalPilotApp

// MARK: - DataMigrationTests
/// 测试 SeedData 到 Core Data 的迁移逻辑。
/// 覆盖实体创建、属性映射、关系建立和迁移幂等性。
final class DataMigrationTests: XCTestCase, @unchecked Sendable {

    @MainActor private lazy var dataController = DataController(inMemory: true)
    @MainActor private lazy var context = dataController.viewContext

    // MARK: - 迁移执行

    /// 测试：执行迁移后 CourseEntity 应正确创建
    func testMigrateSeedData_CourseEntityCreated() async {
        await MainActor.run {
            // 当：执行迁移
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            // 那么：Course 实体数量应与 SeedData 一致
            let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
            let count = (try? context.count(for: fetchRequest)) ?? 0
            XCTAssertEqual(count, SeedData.courses.count)
        }
    }

    /// 测试：课程实体的属性映射应完整准确
    func testMigrateSeedData_CoursePropertiesMapped() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            // 获取第一个课程实体
            let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "c310_multi_agent")
            let results = try? context.fetch(fetchRequest)
            let entity = results?.first

            XCTAssertNotNil(entity)
            XCTAssertEqual(entity?.id, "c310_multi_agent")
            XCTAssertEqual(entity?.name, "C310 多智能体系统")
            XCTAssertEqual(entity?.difficulty, 5)
            XCTAssertEqual(entity?.colorKey, "orange")
            XCTAssertEqual(entity?.symbol, "person.3.sequence")
            XCTAssertEqual(entity?.examDurationMinutesValue, 150)
            XCTAssertEqual(entity?.examLocation, "CTL-4-FLEX, Central Teaching Labs (Building 802)")
        }
    }

    /// 测试：课程与知识点的关系应正确建立
    func testMigrateSeedData_KnowledgePointRelationship() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "c310_multi_agent")
            let courseEntity = try? context.fetch(fetchRequest).first

            XCTAssertNotNil(courseEntity)
            let knowledgePoints = courseEntity?.knowledgePointsArray ?? []
            let seedCourse = SeedData.courses.first { $0.id == "c310_multi_agent" }!
            XCTAssertEqual(knowledgePoints.count, seedCourse.knowledgePoints.count)
        }
    }

    /// 测试：知识点的属性映射应正确
    func testMigrateSeedData_KnowledgePointPropertiesMapped() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<KnowledgePointEntity> = KnowledgePointEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "c310_agent_definition")
            let entity = try? context.fetch(fetchRequest).first

            XCTAssertNotNil(entity)
            XCTAssertEqual(entity?.title, "Agent 标准定义三要素")
            XCTAssertEqual(entity?.chapter, "C1-C2")
            XCTAssertEqual(entity?.difficulty, 3)
            XCTAssertEqual(entity?.mastery ?? -1, 0.30, accuracy: 0.001)
            XCTAssertEqual(entity?.status, KnowledgeStatus.weak.rawValue)
        }
    }

    /// 测试：课程与题目的关系应正确建立
    func testMigrateSeedData_QuestionRelationship() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "c310_multi_agent")
            let courseEntity = try? context.fetch(fetchRequest).first

            XCTAssertNotNil(courseEntity)
            let questions = courseEntity?.questionsArray ?? []
            let seedCourse = SeedData.courses.first { $0.id == "c310_multi_agent" }!
            XCTAssertEqual(questions.count, seedCourse.questions.count)
        }
    }

    /// 测试：题目的属性映射应正确
    func testMigrateSeedData_QuestionPropertiesMapped() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<QuizQuestionEntity> = QuizQuestionEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "q_c310_001")
            let entity = try? context.fetch(fetchRequest).first

            XCTAssertNotNil(entity)
            XCTAssertEqual(entity?.courseID, "c310_multi_agent")
            XCTAssertEqual(entity?.knowledgePointID, "c310_agent_definition")
            XCTAssertEqual(entity?.type, "single_choice")
            XCTAssertEqual(entity?.difficulty, "easy")
            XCTAssertEqual(entity?.answer, "能够在环境中感知并自主行动")
            XCTAssertEqual(entity?.sourceTypeEnum, .lecture)
        }
    }

    /// 测试：StudyTaskEntity 应正确创建
    func testMigrateSeedData_TaskEntityCreated() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<StudyTaskEntity> = StudyTaskEntity.fetchRequest()
            let count = (try? context.count(for: fetchRequest)) ?? 0
            XCTAssertEqual(count, SeedData.tasks.count)
        }
    }

    /// 测试：任务实体的属性映射应正确
    func testMigrateSeedData_TaskPropertiesMapped() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<StudyTaskEntity> = StudyTaskEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "task_c310_day1")
            let entity = try? context.fetch(fetchRequest).first

            XCTAssertNotNil(entity)
            XCTAssertEqual(entity?.title, "C310 C1-C2 Agent 基础闭环")
            XCTAssertEqual(entity?.trackEnum, .exam)
            XCTAssertEqual(entity?.bucketEnum, .must)
            XCTAssertEqual(entity?.minutes, 70)
            XCTAssertEqual(entity?.statusEnum, .pending)
            XCTAssertEqual(entity?.linkedCourseID, "c310_multi_agent")
        }
    }

    /// 测试：CareerEventEntity 应正确创建
    func testMigrateSeedData_CareerEventEntityCreated() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<CareerEventEntity> = CareerEventEntity.fetchRequest()
            let count = (try? context.count(for: fetchRequest)) ?? 0
            XCTAssertEqual(count, SeedData.careerEvents.count)
        }
    }

    /// 测试：职业事件属性映射应正确
    func testMigrateSeedData_CareerEventPropertiesMapped() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<CareerEventEntity> = CareerEventEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "career_demo")
            let entity = try? context.fetch(fetchRequest).first

            XCTAssertNotNil(entity)
            XCTAssertEqual(entity?.company, "学呀学 v2")
            XCTAssertEqual(entity?.role, "公开测试版本")
            XCTAssertEqual(entity?.round, "发布检查")
            XCTAssertEqual(entity?.importance, 4)
            XCTAssertEqual(entity?.preparationStatus, "最低准备包已建立")
        }
    }

    /// 测试：SprintPlanDayEntity 应正确创建
    func testMigrateSeedData_SprintPlanDayEntityCreated() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<SprintPlanDayEntity> = SprintPlanDayEntity.fetchRequest()
            let count = (try? context.count(for: fetchRequest)) ?? 0
            XCTAssertEqual(count, SeedData.sprintPlanDays.count)
        }
    }

    /// 测试：冲刺计划属性映射应正确
    func testMigrateSeedData_SprintPlanDayPropertiesMapped() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<SprintPlanDayEntity> = SprintPlanDayEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "plan_0501")
            let entity = try? context.fetch(fetchRequest).first

            XCTAssertNotNil(entity)
            XCTAssertEqual(entity?.dateLabel, "5/1")
            XCTAssertEqual(entity?.weekday, "周五")
            XCTAssertEqual(entity?.phaseEnum, .foundation)
            XCTAssertEqual(entity?.marker, "启动")
            XCTAssertEqual(entity?.c310Task, "C1-C2：Agent 基础、定义、环境、rationality。")
            XCTAssertEqual(entity?.isExamDay, false)
        }
    }

    /// 测试：KnowledgeFlashcardEntity 应正确创建
    func testMigrateSeedData_FlashcardEntityCreated() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<KnowledgeFlashcardEntity> = KnowledgeFlashcardEntity.fetchRequest()
            let count = (try? context.count(for: fetchRequest)) ?? 0
            XCTAssertEqual(count, SeedData.flashcards.count)
        }
    }

    /// 测试：闪卡属性映射应正确
    func testMigrateSeedData_FlashcardPropertiesMapped() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            // 获取第一个闪卡实体
            let fetchRequest: NSFetchRequest<KnowledgeFlashcardEntity> = KnowledgeFlashcardEntity.fetchRequest()
            fetchRequest.fetchLimit = 1
            let entity = try? context.fetch(fetchRequest).first

            XCTAssertNotNil(entity)
            XCTAssertFalse(entity!.id.isEmpty)
            XCTAssertFalse(entity!.title.isEmpty)
            XCTAssertFalse(entity!.prompt.isEmpty)
            XCTAssertFalse(entity!.answer.isEmpty)
        }
    }

    /// 测试：迁移是幂等的——重复执行不应重复创建数据
    func testMigrateSeedData_IdempotentMigration() async {
        await MainActor.run {
            // 当：第一次迁移
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            // 记录各实体数量
            let courseCount1 = (try? context.count(for: CourseEntity.fetchRequest())) ?? 0
            let taskCount1 = (try? context.count(for: StudyTaskEntity.fetchRequest())) ?? 0
            let eventCount1 = (try? context.count(for: CareerEventEntity.fetchRequest())) ?? 0

            // 当：第二次迁移（应被跳过）
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            // 那么：数量应与第一次相同
            let courseCount2 = (try? context.count(for: CourseEntity.fetchRequest())) ?? 0
            let taskCount2 = (try? context.count(for: StudyTaskEntity.fetchRequest())) ?? 0
            let eventCount2 = (try? context.count(for: CareerEventEntity.fetchRequest())) ?? 0

            XCTAssertEqual(courseCount1, courseCount2)
            XCTAssertEqual(taskCount1, taskCount2)
            XCTAssertEqual(eventCount1, eventCount2)
        }
    }

    // MARK: - 往返转换测试

    /// 测试：CourseEntity 的 fromCourse/toCourse 往返转换应保持数据一致
    func testCourseEntity_RoundTripConversion() async {
        await MainActor.run {
            let seedCourse = SeedData.courses[0]
            let entity = CourseEntity.fromCourse(seedCourse, context: context)
            let converted = entity.toCourse()

            XCTAssertEqual(converted.id, seedCourse.id)
            XCTAssertEqual(converted.name, seedCourse.name)
            XCTAssertEqual(converted.examDate, seedCourse.examDate)
            XCTAssertEqual(converted.examDurationMinutes, seedCourse.examDurationMinutes)
            XCTAssertEqual(converted.examLocation, seedCourse.examLocation)
            XCTAssertEqual(converted.difficulty, seedCourse.difficulty)
            XCTAssertEqual(converted.colorKey, seedCourse.colorKey)
            XCTAssertEqual(converted.symbol, seedCourse.symbol)
            XCTAssertEqual(converted.knowledgePoints.count, seedCourse.knowledgePoints.count)
            XCTAssertEqual(converted.questions.count, seedCourse.questions.count)
        }
    }

    /// 测试：KnowledgePointEntity 的往返转换应保持数据一致
    func testKnowledgePointEntity_RoundTripConversion() async {
        await MainActor.run {
            let seedPoint = SeedData.courses[0].knowledgePoints[0]
            let entity = KnowledgePointEntity.fromKnowledgePoint(seedPoint, context: context)
            let converted = entity.toKnowledgePoint()

            XCTAssertEqual(converted.id, seedPoint.id)
            XCTAssertEqual(converted.chapter, seedPoint.chapter)
            XCTAssertEqual(converted.title, seedPoint.title)
            XCTAssertEqual(converted.difficulty, seedPoint.difficulty)
            XCTAssertEqual(converted.mastery, seedPoint.mastery, accuracy: 0.001)
            XCTAssertEqual(converted.status, seedPoint.status)
        }
    }

    /// 测试：QuizQuestionEntity 的往返转换应保持数据一致
    func testQuizQuestionEntity_RoundTripConversion() async {
        await MainActor.run {
            let seedQuestion = SeedData.courses[0].questions[0]
            let entity = QuizQuestionEntity.fromQuizQuestion(seedQuestion, context: context)
            let converted = entity.toQuizQuestion()

            XCTAssertEqual(converted.id, seedQuestion.id)
            XCTAssertEqual(converted.courseID, seedQuestion.courseID)
            XCTAssertEqual(converted.knowledgePointID, seedQuestion.knowledgePointID)
            XCTAssertEqual(converted.question, seedQuestion.question)
            XCTAssertEqual(converted.answer, seedQuestion.answer)
            XCTAssertEqual(converted.sourceType, seedQuestion.sourceType)
        }
    }

    /// 测试：StudyTaskEntity 的往返转换应保持数据一致
    func testStudyTaskEntity_RoundTripConversion() async {
        await MainActor.run {
            let seedTask = SeedData.tasks[0]
            let entity = StudyTaskEntity.fromStudyTask(seedTask, context: context)
            let converted = entity.toStudyTask()

            XCTAssertEqual(converted.id, seedTask.id)
            XCTAssertEqual(converted.track, seedTask.track)
            XCTAssertEqual(converted.bucket, seedTask.bucket)
            XCTAssertEqual(converted.title, seedTask.title)
            XCTAssertEqual(converted.minutes, seedTask.minutes)
            XCTAssertEqual(converted.status, seedTask.status)
        }
    }

    /// 测试：CareerEventEntity 的往返转换应保持数据一致
    func testCareerEventEntity_RoundTripConversion() async {
        await MainActor.run {
            let seedEvent = SeedData.careerEvents[0]
            let entity = CareerEventEntity.fromCareerEvent(seedEvent, context: context)
            let converted = entity.toCareerEvent()

            XCTAssertEqual(converted.id, seedEvent.id)
            XCTAssertEqual(converted.company, seedEvent.company)
            XCTAssertEqual(converted.role, seedEvent.role)
            XCTAssertEqual(converted.importance, seedEvent.importance)
        }
    }

    /// 测试：SprintPlanDayEntity 的往返转换应保持数据一致
    func testSprintPlanDayEntity_RoundTripConversion() async {
        await MainActor.run {
            let seedDay = SeedData.sprintPlanDays[0]
            let entity = SprintPlanDayEntity.fromSprintPlanDay(seedDay, context: context)
            let converted = entity.toSprintPlanDay()

            XCTAssertEqual(converted.id, seedDay.id)
            XCTAssertEqual(converted.dateLabel, seedDay.dateLabel)
            XCTAssertEqual(converted.phase, seedDay.phase)
            XCTAssertEqual(converted.checklist, seedDay.checklist)
        }
    }

    /// 测试：KnowledgeFlashcardEntity 的往返转换应保持数据一致
    func testKnowledgeFlashcardEntity_RoundTripConversion() async {
        await MainActor.run {
            let seedCard = SeedData.flashcards[0]
            let entity = KnowledgeFlashcardEntity.fromKnowledgeFlashcard(seedCard, context: context)
            let converted = entity.toKnowledgeFlashcard()

            XCTAssertEqual(converted.id, seedCard.id)
            XCTAssertEqual(converted.courseID, seedCard.courseID)
            XCTAssertEqual(converted.title, seedCard.title)
            XCTAssertEqual(converted.tags, seedCard.tags)
        }
    }

    /// 测试：CourseEntity 的计算属性 masteryAverage 应正确
    func testCourseEntity_MasteryAverageCalculation() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
            let entity = try? context.fetch(fetchRequest).first

            guard let courseEntity = entity else {
                XCTFail("迁移后缺少课程数据")
                return
            }

            let expectedAverage = courseEntity.knowledgePointsArray.reduce(0.0) { $0 + $1.mastery } / Double(max(courseEntity.knowledgePointsArray.count, 1))
            XCTAssertEqual(courseEntity.masteryAverage, expectedAverage, accuracy: 0.001)
        }
    }

    /// 测试：CourseEntity 的 weakPoints 应正确筛选 mastery < 0.38 的知识点
    func testCourseEntity_WeakPointsFilter() async {
        await MainActor.run {
            CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: context)

            let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
            let entity = try? context.fetch(fetchRequest).first

            guard let courseEntity = entity else {
                XCTFail("迁移后缺少课程数据")
                return
            }

            let weakPoints = courseEntity.weakPoints
            XCTAssertTrue(weakPoints.allSatisfy { $0.mastery < 0.38 || $0.status == KnowledgeStatus.weak.rawValue })
        }
    }
}
