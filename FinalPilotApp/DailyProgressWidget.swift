import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intent（iOS 17+）

struct DailyProgressIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "每日进度"
    static let description = IntentDescription("显示今日学习进度环形图")
    
    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Timeline Entry

struct DailyProgressEntry: TimelineEntry {
    let date: Date
    let progress: WidgetProgressInfo
    let targetMinutes: Int
    
    static var preview: DailyProgressEntry {
        DailyProgressEntry(
            date: Date(),
            progress: WidgetProgressInfo(
                completedTasks: 3,
                totalTasks: 5,
                studyMinutes: 120,
                completionRate: 0.6,
                lastUpdated: Date()
            ),
            targetMinutes: 180
        )
    }
}

// MARK: - Timeline Provider

struct DailyProgressProvider: AppIntentTimelineProvider {
    typealias Entry = DailyProgressEntry
    typealias Intent = DailyProgressIntent
    
    func placeholder(in context: Context) -> DailyProgressEntry {
        DailyProgressEntry.preview
    }
    
    func snapshot(for configuration: DailyProgressIntent, in context: Context) async -> DailyProgressEntry {
        buildEntry()
    }
    
    func timeline(for configuration: DailyProgressIntent, in context: Context) async -> Timeline<DailyProgressEntry> {
        let entry = buildEntry()
        
        // 每30分钟更新一次，确保进度及时刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func buildEntry() -> DailyProgressEntry {
        let provider = WidgetDataProvider.shared
        let progress = provider.loadProgress()
        
        // 默认目标学习时长 180 分钟（3小时）
        let targetMinutes = 180
        
        return DailyProgressEntry(
            date: Date(),
            progress: progress,
            targetMinutes: targetMinutes
        )
    }
}

// MARK: - Widget View

struct DailyProgressWidgetEntryView: View {
    var entry: DailyProgressProvider.Entry
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
        default:
            smallView
        }
    }
    
    // MARK: Small View
    
    private var smallView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "chart.donut")
                    .font(.caption2)
                    .foregroundColor(primaryColor)
                Text("今日进度")
                    .font(.caption2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                // 环形进度图
                ZStack {
                    Circle()
                        .stroke(
                            Color.gray.opacity(0.15),
                            lineWidth: 5
                        )
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(entry.progress.completionRate, 1.0)))
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: entry.progress.completionRate)
                    
                    VStack(spacing: 0) {
                        Text("\(Int(entry.progress.completionRate * 100))%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(progressColor)
                        Text("完成")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 56, height: 56)
                
                // 右侧信息
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                            .foregroundColor(primaryColor)
                        Text(entry.progress.formattedStudyTime)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 8))
                            .foregroundColor(greenColor)
                        Text("\(entry.progress.completedTasks)/\(entry.progress.totalTasks)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    
                    // 目标进度对比
                    let timeProgress = min(Double(entry.progress.studyMinutes) / Double(entry.targetMinutes), 1.0)
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 8))
                            .foregroundColor(orangeColor)
                        Text("\(Int(timeProgress * 100))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(orangeColor)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // MARK: Helpers
    
    private var progressColor: Color {
        let rate = entry.progress.completionRate
        if rate >= 0.8 {
            return greenColor
        } else if rate >= 0.5 {
            return primaryColor
        } else {
            return orangeColor
        }
    }
}

// MARK: - Widget Definition

struct DailyProgressWidget: Widget {
    let kind: String = "DailyProgressWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DailyProgressIntent.self,
            provider: DailyProgressProvider()
        ) { entry in
            DailyProgressWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("每日进度")
        .description("显示今日学习进度环形图、完成率和已学习时长")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#if FINALPILOT_ENABLE_PREVIEWS
#Preview(as: .systemSmall) {
    DailyProgressWidget()
} timeline: {
    DailyProgressEntry.preview
}
#endif
