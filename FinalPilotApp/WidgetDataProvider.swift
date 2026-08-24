import Foundation

// MARK: - App Group 配置说明
// 需要在 Xcode 中配置 App Group：group.com.jeffhan.FinalPilot
// 1. 主 App Target → Signing & Capabilities → + Capability → App Groups
// 2. Widget Extension Target → 同样添加 App Groups
// 3. 在两个 target 中勾选相同的 group.com.jeffhan.FinalPilot

enum WidgetAppGroup {
    static let suiteName = "group.com.jeffhan.FinalPilot"
    
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

// MARK: - Widget 数据模型

struct WidgetExamInfo: Codable, Identifiable {
    let id: String
    let name: String
    let examDate: Date
    let colorKey: String
    let symbol: String
    let location: String?
    
    var daysUntil: Int {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: examDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    var isUrgent: Bool {
        daysUntil <= 7 && daysUntil >= 0
    }
}

struct WidgetTaskInfo: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let minutes: Int
    let isDone: Bool
    let bucket: String
}

struct WidgetProgressInfo: Codable {
    let completedTasks: Int
    let totalTasks: Int
    let studyMinutes: Int
    let completionRate: Double
    let lastUpdated: Date
    
    var formattedStudyTime: String {
        let hours = studyMinutes / 60
        let mins = studyMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct WidgetSnapshot: Codable {
    var exams: [WidgetExamInfo]
    var tasks: [WidgetTaskInfo]
    var progress: WidgetProgressInfo
    var lastUpdated: Date
}

// MARK: - 数据提供者

final class WidgetDataProvider: @unchecked Sendable {
    static let shared = WidgetDataProvider()
    
    private let examsKey = "widget_exams"
    private let tasksKey = "widget_tasks"
    private let progressKey = "widget_progress"
    private let snapshotKey = "widget_snapshot"
    
    private var defaults: UserDefaults? {
        WidgetAppGroup.defaults
    }
    
    // MARK: - 保存数据（从主 App 调用）
    
    func saveExams(_ exams: [WidgetExamInfo]) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(exams) {
            defaults.set(data, forKey: examsKey)
        }
    }
    
    func saveTasks(_ tasks: [WidgetTaskInfo]) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: tasksKey)
        }
    }
    
    func saveProgress(_ progress: WidgetProgressInfo) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: progressKey)
        }
    }
    
    func saveSnapshot(_ snapshot: WidgetSnapshot) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }
    
    // MARK: - 读取数据（从 Widget 调用）
    
    func loadExams() -> [WidgetExamInfo] {
        guard let defaults,
              let data = defaults.data(forKey: examsKey),
              let exams = try? JSONDecoder().decode([WidgetExamInfo].self, from: data) else {
            return WidgetDataProvider.defaultExams()
        }
        return exams
    }
    
    func loadTasks() -> [WidgetTaskInfo] {
        guard let defaults,
              let data = defaults.data(forKey: tasksKey),
              let tasks = try? JSONDecoder().decode([WidgetTaskInfo].self, from: data) else {
            return []
        }
        return tasks
    }
    
    func loadProgress() -> WidgetProgressInfo {
        guard let defaults,
              let data = defaults.data(forKey: progressKey),
              let progress = try? JSONDecoder().decode(WidgetProgressInfo.self, from: data) else {
            return WidgetProgressInfo(completedTasks: 0, totalTasks: 0, studyMinutes: 0, completionRate: 0, lastUpdated: Date())
        }
        return progress
    }
    
    func loadSnapshot() -> WidgetSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
    
    // MARK: - 便捷方法
    
    var todayMustTasks: [WidgetTaskInfo] {
        loadTasks().filter { $0.bucket == "must" && !$0.isDone }
    }
    
    var nearestExam: WidgetExamInfo? {
        loadExams().filter { $0.daysUntil >= 0 }.sorted { $0.daysUntil < $1.daysUntil }.first
    }
    
    // MARK: - 默认数据（App Group 未配置时的 fallback）
    
    static func defaultExams() -> [WidgetExamInfo] {
        [
            WidgetExamInfo(
                id: "c310_multi_agent",
                name: "C310 多智能体系统",
                examDate: .finalPilotDate(month: 5, day: 13, hour: 10),
                colorKey: "orange",
                symbol: "person.3.sequence",
                location: "CTL-4-FLEX"
            ),
            WidgetExamInfo(
                id: "e320_neural_network",
                name: "E320 神经网络",
                examDate: .finalPilotDate(month: 5, day: 14, hour: 14, minute: 30),
                colorKey: "teal",
                symbol: "point.3.connected.trianglepath.dotted",
                location: "Sherrington Building"
            ),
            WidgetExamInfo(
                id: "c315_cloud",
                name: "C315 电子商务云计算",
                examDate: .finalPilotDate(month: 5, day: 26, hour: 10),
                colorKey: "blue",
                symbol: "cloud",
                location: "Yoko Ono Lennon Centre"
            )
        ]
    }
}
