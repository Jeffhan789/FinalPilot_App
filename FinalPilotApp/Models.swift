import Foundation

enum TaskTrack: String, CaseIterable, Identifiable {
    case exam
    case career

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exam: "Exam Track"
        case .career: "Flex Track"
        }
    }

    var subtitle: String {
        switch self {
        case .exam: "考试优先，先保住 C310 / E320"
        case .career: "里程碑保温，只保留高收益短任务"
        }
    }

    var icon: String {
        switch self {
        case .exam: "graduationcap"
        case .career: "briefcase"
        }
    }
}

enum TaskBucket: String, CaseIterable, Identifiable {
    case must
    case should
    case skip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .must: "Must"
        case .should: "Should"
        case .skip: "Skip"
        }
    }

    var caption: String {
        switch self {
        case .must: "今天必须完成"
        case .should: "有余力再做"
        case .skip: "今天建议放下"
        }
    }
}

enum TaskStatus: String {
    case pending
    case done
    case deferred
}

enum KnowledgeStatus: String {
    case notStarted
    case inProgress
    case mastered
    case weak

    var label: String {
        switch self {
        case .notStarted: "未开始"
        case .inProgress: "复习中"
        case .mastered: "已掌握"
        case .weak: "薄弱"
        }
    }
}

enum ConfidenceLevel: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: "不确定"
        case .medium: "一般"
        case .high: "很确定"
        }
    }

    var score: Double {
        switch self {
        case .low: 0.25
        case .medium: 0.55
        case .high: 0.9
        }
    }
}

enum QuestionSourceType: String, CaseIterable, Identifiable {
    case lecture
    case tutorial
    case pastPaper
    case finalExam
    case sprintNote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lecture: "课件"
        case .tutorial: "辅导课"
        case .pastPaper: "真题"
        case .finalExam: "期末题型"
        case .sprintNote: "冲刺笔记"
        }
    }

    var icon: String {
        switch self {
        case .lecture: "text.book.closed"
        case .tutorial: "person.wave.2"
        case .pastPaper: "doc.text.magnifyingglass"
        case .finalExam: "target"
        case .sprintNote: "bolt"
        }
    }
}

struct KnowledgePoint: Identifiable, Hashable {
    let id: String
    let chapter: String
    var title: String
    var difficulty: Int
    var mastery: Double
    var status: KnowledgeStatus
}

struct KnowledgeFlashcard: Identifiable, Hashable {
    let id: String
    let courseID: String
    let knowledgePointID: String
    let dayLabel: String
    let title: String
    let prompt: String
    let answer: String
    let examHint: String
    let sourceTitle: String
    let tags: [String]
    let priority: Int
}

struct QuizQuestion: Identifiable, Hashable {
    let id: String
    let courseID: String
    let knowledgePointID: String
    let type: String
    let difficulty: String
    let question: String
    let options: [String]
    let answer: String
    let explanation: String
    let sourceType: QuestionSourceType
    let sourceTitle: String
    let sourceDetail: String
    let examValue: Int
    let examPrompt: String
}

struct Course: Identifiable, Hashable {
    let id: String
    var name: String
    var examDate: Date?
    var examDurationMinutes: Int? = nil
    var examLocation: String? = nil
    var difficulty: Int
    var colorKey: String
    var symbol: String
    var knowledgePoints: [KnowledgePoint]
    var questions: [QuizQuestion]

    var masteryAverage: Double {
        guard !knowledgePoints.isEmpty else { return 0 }
        let total = knowledgePoints.reduce(0) { $0 + $1.mastery }
        return total / Double(knowledgePoints.count)
    }

    var weakPoints: [KnowledgePoint] {
        knowledgePoints.filter { $0.status == .weak || $0.mastery < 0.38 }
    }
}

struct StudyTask: Identifiable, Hashable {
    let id: String
    var track: TaskTrack
    var bucket: TaskBucket
    var title: String
    var subtitle: String
    var minutes: Int
    var reason: String
    var linkedCourseID: String?
    var status: TaskStatus
}

struct CareerEvent: Identifiable, Hashable {
    let id: String
    var company: String
    var role: String
    var round: String
    var date: Date
    var importance: Int
    var preparationStatus: String
}

enum SprintPlanPhase: String, CaseIterable, Identifiable {
    case foundation
    case highFrequency
    case pastPaper
    case examSwitch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: "搭骨架"
        case .highFrequency: "补高频"
        case .pastPaper: "真题闭环"
        case .examSwitch: "考试切换"
        }
    }

    var subtitle: String {
        switch self {
        case .foundation: "5/1-5/4"
        case .highFrequency: "5/5-5/8"
        case .pastPaper: "5/9-5/12"
        case .examSwitch: "5/13-5/14"
        }
    }
}

struct SprintPlanDay: Identifiable, Hashable {
    let id: String
    var dateLabel: String
    var weekday: String
    var phase: SprintPlanPhase
    var marker: String?
    var c310Task: String
    var e320Task: String
    var output: String
    var checklist: [String]

    var isExamDay: Bool {
        marker?.contains("考试") == true
    }
}

struct QuizAttempt: Identifiable, Hashable {
    let id: String
    let questionID: String
    let knowledgePointID: String
    let selectedAnswer: String
    let isCorrect: Bool
    let confidence: ConfidenceLevel
    let createdAt: Date
}

extension Date {
    static func finalPilotDate(month: Int, day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Europe/London")
        components.year = 2026
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }
}
