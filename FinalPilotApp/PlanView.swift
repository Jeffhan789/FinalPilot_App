import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: FinalPilotStore
    @State private var selectedPhase: SprintPlanPhase? = nil

    private var filteredDays: [SprintPlanDay] {
        guard let selectedPhase else { return store.sprintPlanDays }
        return store.sprintPlanDays.filter { $0.phase == selectedPhase }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    phasePicker
                    StudySyncPanel()
                    careerBranch
                    dailyBaseline
                    dayTimeline
                    executionRules
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("两周计划")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(AppTheme.orange)
                    .frame(width: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text("C310 + E320 冲刺航线")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("5/1-5/14：课件 -> 1 页笔记 -> 1-2 道题 -> 错题重做 -> 睡前主动回忆")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                MetricTile(title: "C310", value: "5/13 10:00", icon: "person.3.sequence", color: AppTheme.orange)
                MetricTile(title: "E320", value: "5/14 14:30", icon: "point.3.connected.trianglepath.dotted", color: AppTheme.primary)
                MetricTile(title: "C315", value: "5/26 10:00", icon: "cloud", color: AppTheme.courseColor("blue"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var phasePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "阶段筛选", subtitle: "按 A4 规划表的四个阶段查看")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    phaseButton(title: "全部", subtitle: "5/1-5/14", phase: nil)
                    ForEach(SprintPlanPhase.allCases) { phase in
                        phaseButton(title: phase.title, subtitle: phase.subtitle, phase: phase)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phaseButton(title: String, subtitle: String, phase: SprintPlanPhase?) -> some View {
        let isSelected = selectedPhase == phase
        let color = phase.map(AppTheme.phaseColor) ?? AppTheme.ink
        return Button {
            selectedPhase = phase
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                Text(subtitle)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? color : color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var dailyBaseline: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "每日保底", subtitle: "有临时事务时切 B 档，不补偿性熬夜")
            VStack(alignment: .leading, spacing: 8) {
                Label("C310：1 个核心概念 + 1 道相关题", systemImage: "1.circle")
                Label("E320：1 个公式 / 算法 + 1 道相关计算题", systemImage: "2.circle")
                Label("睡前 20 分钟：5 个英文术语 + 错题重做日期", systemImage: "moon.stars")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var careerBranch: some View {
        NavigationLink {
            CareerView()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.orange, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("里程碑保温分支")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(careerBranchSubtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.top, 4)
                }

                HStack(spacing: 8) {
                    branchPill(title: "模式", value: "隐藏")
                    branchPill(title: "任务", value: "\(store.tasks(track: .career, bucket: .should).count) 项")
                    branchPill(title: "原则", value: "不抢主线")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var careerBranchSubtitle: String {
        guard let event = store.careerEvents.sorted(by: { $0.date < $1.date }).first else {
            return "里程碑不放在底部主导航；需要时进入这里看最低准备包。"
        }
        return "下一项：\(event.company) · \(event.round)，只保留最低执行包。"
    }

    private func branchPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var dayTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "每日进度", subtitle: "来自 A4 两周复习进度规划表")
            ForEach(filteredDays) { day in
                SprintPlanDayCard(day: day)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var executionRules: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "执行标准", subtitle: "判断今天是否真的完成")
            VStack(alignment: .leading, spacing: 10) {
                Label("C310：能用英文术语写出结构化答案。", systemImage: "text.book.closed")
                Label("E320：能在纸上完整算出公式步骤。", systemImage: "function")
                Label("笔记只是中间产物，限时输出才是复习成果。", systemImage: "stopwatch")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SprintPlanDayCard: View {
    let day: SprintPlanDay
    private let checklistColumns = [GridItem(.adaptive(minimum: 86), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Text(day.dateLabel)
                        .font(.headline.weight(.bold))
                    Text(day.weekday)
                        .font(.caption)
                    if let marker = day.marker {
                        Text(marker)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(day.isExamDay ? AppTheme.orange.opacity(0.18) : AppTheme.primary.opacity(0.12), in: Capsule())
                    }
                }
                .foregroundStyle(AppTheme.ink)
                .frame(width: 64)

                VStack(alignment: .leading, spacing: 9) {
                    phaseLabel
                    planLine(title: "C310", text: day.c310Task, color: AppTheme.orange)
                    planLine(title: "E320", text: day.e320Task, color: AppTheme.primary)
                    planLine(title: "输出", text: day.output, color: AppTheme.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            LazyVGrid(columns: checklistColumns, alignment: .leading, spacing: 8) {
                ForEach(day.checklist, id: \.self) { item in
                    Label(item, systemImage: "square")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.background, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.phaseColor(day.phase).opacity(day.isExamDay ? 0.5 : 0.16))
        }
    }

    private var phaseLabel: some View {
        Text("\(day.phase.title) · \(day.phase.subtitle)")
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.phaseColor(day.phase))
    }

    private func planLine(title: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38)
                .padding(.vertical, 4)
                .background(color, in: RoundedRectangle(cornerRadius: 6))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
