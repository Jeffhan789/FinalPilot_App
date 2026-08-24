import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intent（iOS 17+）

struct TodayTasksIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "今日任务"
    static let description = IntentDescription("显示今日 Must 任务列表")
    
    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Timeline Entry

struct TodayTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTaskInfo]
    let urgentTask: WidgetTaskInfo?
    let totalMinutes: Int
    let completedCount: Int
    
    static var preview: TodayTasksEntry {
        TodayTasksEntry(
            date: Date(),
            tasks: [
                WidgetTaskInfo(id: "1", title: "C310 真题闭环", subtitle: "Day1 真题矩阵", minutes: 45, isDone: false, bucket: "must"),
                WidgetTaskInfo(id: "2", title: "E320 神经网络", subtitle: "反向传播推导", minutes: 30, isDone: false, bucket: "must"),
                WidgetTaskInfo(id: "3", title: "英语阅读", subtitle: "TED 精听", minutes: 20, isDone: true, bucket: "must")
            ],
            urgentTask: WidgetTaskInfo(id: "1", title: "C310 真题闭环", subtitle: "Day1 真题矩阵", minutes: 45, isDone: false, bucket: "must"),
            totalMinutes: 95,
            completedCount: 1
        )
    }
}

// MARK: - Timeline Provider

struct TodayTasksProvider: AppIntentTimelineProvider {
    typealias Entry = TodayTasksEntry
    typealias Intent = TodayTasksIntent
    
    func placeholder(in context: Context) -> TodayTasksEntry {
        TodayTasksEntry.preview
    }
    
    func snapshot(for configuration: TodayTasksIntent, in context: Context) async -> TodayTasksEntry {
        buildEntry()
    }
    
    func timeline(for configuration: TodayTasksIntent, in context: Context) async -> Timeline<TodayTasksEntry> {
        let entry = buildEntry()
        
        // 每小时更新一次，确保任务状态及时刷新
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func buildEntry() -> TodayTasksEntry {
        let provider = WidgetDataProvider.shared
        let allTasks = provider.loadTasks()
        let mustTasks = allTasks.filter { $0.bucket == "must" }
        let pending = mustTasks.filter { !$0.isDone }
        let completed = mustTasks.filter { $0.isDone }
        let urgent = pending.sorted { $0.minutes > $1.minutes }.first
        let totalMinutes = pending.reduce(0) { $0 + $1.minutes }
        
        return TodayTasksEntry(
            date: Date(),
            tasks: mustTasks,
            urgentTask: urgent,
            totalMinutes: totalMinutes,
            completedCount: completed.count
        )
    }
}

// MARK: - Widget View

struct TodayTasksWidgetEntryView: View {
    var entry: TodayTasksProvider.Entry
    @Environment(\.widgetFamily) var family
    
    // Widget 颜色系统（与 AppTheme 一致）
    private let primaryColor = Color(red: 0.15, green: 0.43, blue: 0.46)
    private let orangeColor = Color(red: 0.91, green: 0.55, blue: 0.25)
    private let greenColor = Color(red: 0.18, green: 0.62, blue: 0.4)
    private let secondaryTextColor = Color(red: 0.42, green: 0.45, blue: 0.5)
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }
    
    // MARK: Small
    
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.caption2)
                    .foregroundColor(orangeColor)
                Text("Must 任务")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Spacer()
            
            let pendingCount = entry.tasks.filter { !$0.isDone }.count
            let totalCount = entry.tasks.count
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(pendingCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(orangeColor)
                Text("/\(totalCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
            
            Text("待完成")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if let urgent = entry.urgentTask {
                Divider()
                    .padding(.vertical, 2)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(orangeColor)
                    Text(urgent.title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                Text(urgent.subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // MARK: Medium
    
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.caption2)
                        .foregroundColor(orangeColor)
                    Text("今日 Must 任务")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                let pendingCount = entry.tasks.filter { !$0.isDone }.count
                let totalCount = entry.tasks.count
                HStack(spacing: 2) {
                    Text("\(pendingCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(orangeColor)
                    Text("/\(totalCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 任务列表
            let pendingTasks = entry.tasks.filter { !$0.isDone }.sorted { $0.minutes > $1.minutes }
            
            if pendingTasks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(greenColor)
                        Text("全部完成！")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                ForEach(pendingTasks.prefix(3)) { task in
                    HStack(spacing: 8) {
                        // 状态圆点
                        Circle()
                            .stroke(orangeColor, lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(task.title)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(task.subtitle)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text("\(task.minutes)m")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.vertical, 2)
                }
                
                Spacer(minLength: 0)
                
                if entry.totalMinutes > 0 {
                    HStack {
                        Spacer()
                        Text("预计还需 \(entry.totalMinutes) 分钟")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Definition

struct TodayTasksWidget: Widget {
    let kind: String = "TodayTasksWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TodayTasksIntent.self,
            provider: TodayTasksProvider()
        ) { entry in
            TodayTasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日 Must 任务")
        .description("显示今日 Must 任务列表和最紧急任务")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#if FINALPILOT_ENABLE_PREVIEWS
#Preview(as: .systemSmall) {
    TodayTasksWidget()
} timeline: {
    TodayTasksEntry.preview
}

#Preview(as: .systemMedium) {
    TodayTasksWidget()
} timeline: {
    TodayTasksEntry.preview
}
#endif
