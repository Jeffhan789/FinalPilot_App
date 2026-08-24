import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intent（iOS 17+）

struct ExamCountdownIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "考试倒计时"
    static let description = IntentDescription("显示即将到来的考试倒计时")
    
    @Parameter(title: "考试筛选", default: .all)
    var filter: ExamFilter
    
    enum ExamFilter: String, AppEnum {
        case all
        case nearest
        
        static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "考试筛选")
        
        static let caseDisplayRepresentations: [ExamFilter: DisplayRepresentation] = [
            .all: DisplayRepresentation(title: "全部考试"),
            .nearest: DisplayRepresentation(title: "最近考试")
        ]
    }
    
    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Timeline Entry

struct ExamCountdownEntry: TimelineEntry {
    let date: Date
    let exams: [WidgetExamInfo]
    let nearestExam: WidgetExamInfo?
    
    static var preview: ExamCountdownEntry {
        ExamCountdownEntry(
            date: Date(),
            exams: WidgetDataProvider.defaultExams(),
            nearestExam: WidgetDataProvider.defaultExams().first
        )
    }
}

// MARK: - Timeline Provider

struct ExamCountdownProvider: AppIntentTimelineProvider {
    typealias Entry = ExamCountdownEntry
    typealias Intent = ExamCountdownIntent
    
    func placeholder(in context: Context) -> ExamCountdownEntry {
        ExamCountdownEntry.preview
    }
    
    func snapshot(for configuration: ExamCountdownIntent, in context: Context) async -> ExamCountdownEntry {
        let provider = WidgetDataProvider.shared
        let exams = provider.loadExams().sorted { $0.daysUntil < $1.daysUntil }
        let nearest = exams.filter { $0.daysUntil >= 0 }.first
        return ExamCountdownEntry(date: Date(), exams: exams, nearestExam: nearest)
    }
    
    func timeline(for configuration: ExamCountdownIntent, in context: Context) async -> Timeline<ExamCountdownEntry> {
        let provider = WidgetDataProvider.shared
        let exams = provider.loadExams().sorted { $0.daysUntil < $1.daysUntil }
        let nearest = exams.filter { $0.daysUntil >= 0 }.first
        let entry = ExamCountdownEntry(date: Date(), exams: exams, nearestExam: nearest)
        
        // 每天更新一次（午夜），保证天数准确
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let nextMidnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
}

// MARK: - Widget View

struct ExamCountdownWidgetEntryView: View {
    var entry: ExamCountdownProvider.Entry
    @Environment(\.widgetFamily) var family
    
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
            if let exam = entry.nearestExam {
                HStack(spacing: 4) {
                    Image(systemName: exam.symbol)
                        .font(.caption2)
                        .foregroundColor(widgetColor(for: exam.colorKey))
                    Text(examNameShort(exam.name))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                }
                
                Spacer()
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(exam.daysUntil)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(widgetColor(for: exam.colorKey))
                    Text("天")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }
                
                Text("剩余")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("暂无考试")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // MARK: Medium
    
    private var mediumView: some View {
        HStack(spacing: 12) {
            // 左侧：最近考试
            if let exam = entry.nearestExam {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: exam.symbol)
                            .font(.caption2)
                            .foregroundColor(widgetColor(for: exam.colorKey))
                        Text(examNameShort(exam.name))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(exam.daysUntil)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(widgetColor(for: exam.colorKey))
                        Text("天")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 3)
                    }
                    
                    Text(formattedExamDate(exam.examDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 100)
            }
            
            Divider()
            
            // 右侧：所有考试列表
            VStack(alignment: .leading, spacing: 6) {
                Text("考试日历")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
                
                ForEach(entry.exams.filter { $0.daysUntil >= 0 }.prefix(3)) { exam in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(widgetColor(for: exam.colorKey))
                            .frame(width: 6, height: 6)
                        
                        Text(examNameShort(exam.name))
                            .font(.caption2)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(exam.daysUntil)天")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(exam.isUrgent ? widgetColor(for: "orange") : .secondary)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // MARK: Helpers
    
    private func examNameShort(_ name: String) -> String {
        // 将 "C310 多智能体系统" 转为 "C310"
        if let range = name.range(of: " ") {
            return String(name[..<range.lowerBound])
        }
        return name
    }
    
    private func formattedExamDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        return formatter.string(from: date)
    }
    
    private func widgetColor(for key: String) -> Color {
        switch key {
        case "blue": Color(red: 0.18, green: 0.42, blue: 0.78)
        case "orange": Color(red: 0.91, green: 0.55, blue: 0.25)
        case "teal": Color(red: 0.15, green: 0.43, blue: 0.46)
        case "green": Color(red: 0.18, green: 0.62, blue: 0.4)
        default: Color(red: 0.15, green: 0.43, blue: 0.46)
        }
    }
}

// MARK: - Widget Definition

struct ExamCountdownWidget: Widget {
    let kind: String = "ExamCountdownWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ExamCountdownIntent.self,
            provider: ExamCountdownProvider()
        ) { entry in
            ExamCountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("考试倒计时")
        .description("显示最近考试的剩余天数，支持全部考试列表")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#if FINALPILOT_ENABLE_PREVIEWS
#Preview(as: .systemSmall) {
    ExamCountdownWidget()
} timeline: {
    ExamCountdownEntry.preview
}

#Preview(as: .systemMedium) {
    ExamCountdownWidget()
} timeline: {
    ExamCountdownEntry.preview
}
#endif
