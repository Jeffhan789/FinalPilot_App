import Charts
import SwiftUI

// MARK: - 统计周期选择
private enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "7日"
        case .month: "30日"
        }
    }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        }
    }
}

// MARK: - 正确率数据点
private struct AccuracyPoint: Identifiable {
    let id = UUID().uuidString
    let date: Date
    let accuracy: Double
    let total: Int
}

// MARK: - AnalyticsView
struct AnalyticsView: View {
    @EnvironmentObject private var store: FinalPilotStore
    @State private var selectedPeriod: StatisticsPeriod = .week

    // MARK: 计算属性
    private var records: [DailyStudyRecord] {
        StudyStatistics.generateDailyRecords(from: store)
    }

    private var studyTrendData: [DailyStudyRecord] {
        StudyStatistics.studyTrend(records: records, days: selectedPeriod.days)
    }

    private var masteryPoints: [MasteryHistoryPoint] {
        StudyStatistics.masteryHistoryPoints(courses: store.courses, days: selectedPeriod.days)
    }

    private var accuracyPoints: [AccuracyPoint] {
        StudyStatistics.accuracyTrend(attempts: store.attempts, days: selectedPeriod.days)
            .map { AccuracyPoint(date: $0.date, accuracy: $0.accuracy, total: $0.total) }
    }

    private var knowledgeDistribution: [(status: KnowledgeStatus, count: Int, percentage: Double)] {
        StudyStatistics.knowledgeStatusDistribution(courses: store.courses)
    }

    private var heatmapData: [(weekday: Int, weekdayLabel: String, hours: Double, intensity: Double)] {
        StudyStatistics.studyHeatmap(records: records)
    }

    private var ebbinghausSuggestions: [EbbinghausSuggestion] {
        StudyStatistics.ebbinghausReviewSuggestions(attempts: store.attempts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    metricRow
                    periodPicker
                    studyDurationChart
                    masteryTrendChart
                    accuracyTrendChart
                    knowledgeDistributionChart
                    studyHeatmap
                    ebbinghausPanel
                    dailyRecordList
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("分析")
        }
    }

    // MARK: - 顶部指标
    private var metricRow: some View {
        let totalMinutes = records.reduce(0) { $0 + $1.studyMinutes }
        let totalQuestions = records.reduce(0) { $0 + $1.totalQuestions }
        let totalCorrect = records.reduce(0) { $0 + $1.correctQuestions }
        let accuracy = totalQuestions > 0 ? Double(totalCorrect) / Double(totalQuestions) : 0
        let totalTasks = records.reduce(0) { $0 + $1.completedTasks }

        return HStack(spacing: 10) {
            MetricTile(
                title: "总学习时长",
                value: "\(totalMinutes)分钟",
                icon: "clock",
                color: AppTheme.primary
            )
            MetricTile(
                title: "总答题数",
                value: "\(totalQuestions)",
                icon: "checklist",
                color: AppTheme.orange
            )
            MetricTile(
                title: "平均正确率",
                value: "\(Int(accuracy * 100))%",
                icon: "checkmark.seal",
                color: AppTheme.green
            )
            MetricTile(
                title: "完成任务",
                value: "\(totalTasks)",
                icon: "checkmark.circle.fill",
                color: AppTheme.primary
            )
        }
    }

    // MARK: - 周期选择器
    private var periodPicker: some View {
        Picker("周期", selection: $selectedPeriod) {
            ForEach(StatisticsPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 7日/30日学习时长折线图
    private var studyDurationChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "学习时长趋势",
                subtitle: "最近\(selectedPeriod.days)日每日学习时长（分钟）"
            )

            Chart(studyTrendData) { record in
                LineMark(
                    x: .value("日期", record.date, unit: .day),
                    y: .value("分钟", record.studyMinutes)
                )
                .foregroundStyle(AppTheme.primary)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("日期", record.date, unit: .day),
                    y: .value("分钟", record.studyMinutes)
                )
                .foregroundStyle(AppTheme.primary.opacity(0.08))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("日期", record.date, unit: .day),
                    y: .value("分钟", record.studyMinutes)
                )
                .foregroundStyle(AppTheme.primary)
                .symbolSize(60)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .frame(height: 220)
            .padding(12)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - 掌握度变化曲线图
    private var masteryTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "课程掌握度变化",
                subtitle: "最近\(selectedPeriod.days)日掌握度趋势"
            )

            Chart {
                ForEach(store.courses) { course in
                    let points = masteryPoints.filter { $0.colorKey == course.colorKey }
                        .sorted { $0.dayIndex < $1.dayIndex }
                    ForEach(points) { point in
                        LineMark(
                            x: .value("天数", point.dayIndex),
                            y: .value("掌握度", point.mastery)
                        )
                        .foregroundStyle(AppTheme.courseColor(course.colorKey))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                // 参考线：掌握度 0.72（已掌握阈值）
                RuleMark(y: .value("掌握阈值", 0.72))
                    .foregroundStyle(AppTheme.green.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                // 参考线：薄弱阈值 0.38
                RuleMark(y: .value("薄弱阈值", 0.38))
                    .foregroundStyle(AppTheme.orange.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        Text("\(Int((value.as(Double.self) ?? 0) * 100))%")
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel("\(value.as(Int.self) ?? 0)")
                    AxisGridLine()
                }
            }
            .frame(height: 220)
            .padding(12)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // 图例
            HStack(spacing: 16) {
                ForEach(store.courses) { course in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.courseColor(course.colorKey))
                            .frame(width: 8, height: 8)
                        Text(course.name.courseShortName)
                            .font(.caption)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - 答题正确率趋势图
    private var accuracyTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "答题正确率趋势",
                subtitle: "最近\(selectedPeriod.days)日每日正确率与答题量"
            )

            if accuracyPoints.allSatisfy({ $0.total == 0 }) {
                EmptyStateView(
                    title: "暂无答题数据",
                    message: "在练习页面完成题目后，这里会显示正确率趋势。",
                    icon: "chart.line.uptrend.xyaxis"
                )
                .padding(12)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Chart(accuracyPoints) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("正确率", point.accuracy)
                    )
                    .foregroundStyle(point.accuracy >= 0.7 ? AppTheme.green : (point.accuracy >= 0.4 ? AppTheme.primary : AppTheme.orange))
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            Text("\(Int((value.as(Double.self) ?? 0) * 100))%")
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
                .padding(12)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    // MARK: - 知识点状态分布饼图
    private var knowledgeDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "知识点状态分布",
                subtitle: "所有课程知识点的掌握状态占比"
            )

            HStack(spacing: 20) {
                // 自定义饼图
                if knowledgeDistribution.isEmpty {
                    EmptyStateView(
                        title: "暂无数据",
                        message: "同步课程数据后显示知识点分布。",
                        icon: "chart.pie"
                    )
                } else {
                    GeometryReader { geometry in
                        let size = min(geometry.size.width, geometry.size.height)
                        ZStack {
                            ForEach(0..<knowledgeDistribution.count, id: \.self) { index in
                                let startAngle = knowledgeDistribution.prefix(index).reduce(0) { $0 + $1.percentage } * 360 - 90
                                let endAngle = startAngle + knowledgeDistribution[index].percentage * 360
                                PieSliceShape(startAngle: startAngle, endAngle: endAngle)
                                    .fill(statusColor(knowledgeDistribution[index].status))
                            }
                            // 中心白色圆，形成环形图效果
                            Circle()
                                .fill(AppTheme.card)
                                .frame(width: size * 0.45, height: size * 0.45)
                            VStack(spacing: 2) {
                                let total = knowledgeDistribution.reduce(0) { $0 + $1.count }
                                Text("\(total)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.ink)
                                Text("知识点")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                    .frame(width: 140, height: 140)
                    .padding(.leading, 8)

                    // 图例
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(knowledgeDistribution, id: \.status) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(statusColor(item.status))
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.status.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text("\(item.count)个 (\(Int(item.percentage * 100))%)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - 学习热力图
    private var studyHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "学习热力图",
                subtitle: "按星期几分总学习时长"
            )

            HStack(spacing: 8) {
                ForEach(heatmapData, id: \.weekday) { item in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.background)
                                .frame(height: 80)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(heatmapColor(intensity: item.intensity))
                                .frame(height: max(80 * CGFloat(item.intensity), 8))
                        }
                        .frame(maxWidth: .infinity)

                        Text(item.weekdayLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)

                        Text(String(format: "%.1fh", item.hours))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.ink)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // 热力图图例
            HStack(spacing: 6) {
                Text("低")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatmapColor(intensity: Double(level) / 4.0))
                        .frame(width: 24, height: 12)
                }
                Text("高")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 艾宾浩斯复习建议面板
    private var ebbinghausPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "艾宾浩斯复习建议",
                subtitle: "基于遗忘曲线的错题复习提醒"
            )

            if ebbinghausSuggestions.isEmpty {
                EmptyStateView(
                    title: "暂无复习建议",
                    message: "答错题目后，系统会根据艾宾浩斯遗忘曲线（20分钟→1小时→9小时→1天→2天→6天→31天）提醒你复习。",
                    icon: "brain.head.profile"
                )
                .padding(12)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("当前有 \(ebbinghausSuggestions.count) 个错题需要按遗忘曲线复习")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    ForEach(ebbinghausSuggestions.prefix(5)) { suggestion in
                        ebbinghausRow(suggestion)
                    }
                }
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func ebbinghausRow(_ suggestion: EbbinghausSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.isOverdue ? "exclamationmark.triangle.fill" : "clock.arrow.circlepath")
                .foregroundStyle(suggestion.isOverdue ? AppTheme.orange : AppTheme.primary)
                .frame(width: 30, height: 30)
                .background(
                    (suggestion.isOverdue ? AppTheme.orange : AppTheme.primary)
                        .opacity(0.12),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("错题复习：第\(suggestion.stage + 1)阶段 (\(suggestion.stageLabel))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("已过去 \(Int(suggestion.elapsedHours)) 小时")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            if suggestion.isOverdue {
                Text("已逾期")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.orange, in: Capsule())
            } else {
                Text("待复习")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.12), in: Capsule())
            }
        }
        .padding(12)
    }

    // MARK: - 每日学习记录列表
    private var dailyRecordList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "每日学习记录",
                subtitle: "最近学习详情"
            )

            if records.isEmpty {
                EmptyStateView(
                    title: "暂无学习记录",
                    message: "开始学习和答题后，这里会显示每日记录。",
                    icon: "doc.text"
                )
                .padding(12)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(records.suffix(7).reversed()) { record in
                        dailyRecordRow(record)
                    }
                }
                .padding(12)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func dailyRecordRow(_ record: DailyStudyRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                    Text(record.dateKey)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }

                Spacer()

                if record.accuracy > 0 {
                    Text("正确率 \(Int(record.accuracy * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.green.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 16) {
                Label("\(record.studyMinutes)分钟", systemImage: "clock")
                Label("\(record.completedTasks)任务", systemImage: "checkmark.circle")
                Label("\(record.totalQuestions)题", systemImage: "questionmark.circle")
                if record.totalQuestions > 0 {
                    Label("\(record.correctQuestions)对", systemImage: "checkmark.circle.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)

            if !record.weakPointChanges.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.orange)
                    Text("薄弱知识点变化: \(record.weakPointChanges.count) 项")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.orange)
                }
            }
        }
        .padding(12)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - 辅助方法
    private func statusColor(_ status: KnowledgeStatus) -> Color {
        switch status {
        case .notStarted: AppTheme.secondaryText.opacity(0.6)
        case .inProgress: AppTheme.primary
        case .mastered: AppTheme.green
        case .weak: AppTheme.orange
        }
    }

    private func heatmapColor(intensity: Double) -> Color {
        switch intensity {
        case 0..<0.2: AppTheme.primary.opacity(0.12)
        case 0.2..<0.4: AppTheme.primary.opacity(0.32)
        case 0.4..<0.6: AppTheme.primary.opacity(0.52)
        case 0.6..<0.8: AppTheme.primary.opacity(0.72)
        default: AppTheme.primary
        }
    }
}

// MARK: - PieSliceShape
/// 自定义饼图扇形 Shape
private struct PieSliceShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - String 扩展
private extension String {
    var courseShortName: String {
        if hasPrefix("C310") { return "C310" }
        if hasPrefix("E320") { return "E320" }
        return self
    }
}

// MARK: - 预览
#Preview {
    AnalyticsView()
        .environmentObject(FinalPilotStore())
}
