import SwiftUI

struct CareerView: View {
    @EnvironmentObject private var store: FinalPilotStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "里程碑保温", subtitle: "C310/E320 考前只做最低准备，不展开大工程")
                nextMilestone
                minimumPack
                projectPitch
                careerTimeline
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("里程碑")
        .toolbar {
            Button {
                store.addSampleMilestone()
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private var nextMilestone: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "下一项里程碑", subtitle: "如与考试冲突，只保留最低准备包")

            if let event = store.careerEvents.sorted(by: { $0.date < $1.date }).first {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.company)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                            Text("\(event.role) · \(event.round)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Text(eventDateText(event.date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.primary.opacity(0.12), in: Capsule())
                    }

                    Label(event.preparationStatus, systemImage: "checklist")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                }
                .padding(16)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var minimumPack: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "里程碑检查单", subtitle: "临时事务前先确认这 5 项")
            let items = [
                ("明确完成标准与截止时间", "checkmark.seal"),
                ("拆出一个 20 分钟可执行动作", "timer"),
                ("记录依赖、风险与阻塞项", "exclamationmark.triangle"),
                ("预留复盘与资料归档时间", "archivebox"),
                ("确认不会挤占考试主线", "arrow.triangle.branch")
            ]
            ForEach(items, id: \.0) { title, icon in
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.primary.opacity(0.1), in: Circle())
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                }
                .padding(12)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var projectPitch: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "任务复盘卡", subtitle: "按这个顺序记录一次调度决策")
            VStack(alignment: .leading, spacing: 12) {
                pitchLine(number: "1", title: "背景", text: "期末考试和机动事务并行，用户需要冲刺调度。")
                pitchLine(number: "2", title: "核心", text: "Exam Track 优先，Flex Track 保温。")
                pitchLine(number: "3", title: "约束", text: "截止时间、精力上限与依赖关系共同决定优先级。")
                pitchLine(number: "4", title: "结果", text: "ConflictAgent 自动压缩、合并或延期冲突任务。")
            }
            .padding(16)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var careerTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "里程碑时间线", subtitle: "MVP 暂时手动维护，后续再接日历或邮箱")
            ForEach(store.careerEvents.sorted(by: { $0.date < $1.date })) { event in
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(event.company) · \(event.round)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(eventDateText(event.date))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Text("重要度 \(event.importance)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.orange)
                }
                .padding(12)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func pitchLine(number: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(AppTheme.primary, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func eventDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
