import SwiftUI

// MARK: - Empty State Illustration Component
struct EmptyStateIllustration: View {
    let primaryIcon: String
    var secondaryIcon: String? = nil
    var tertiaryIcon: String? = nil
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var accentColor: Color = AppTheme.primary

    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            // Icon Composition
            ZStack {
                // Background circle
                Circle()
                    .fill(accentColor.opacity(0.08))
                    .frame(width: 120, height: 120)

                // Secondary ring
                Circle()
                    .stroke(accentColor.opacity(0.12), lineWidth: 1)
                    .frame(width: 140, height: 140)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)

                // Decorative small circles
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 4, height: 4)
                        .offset(
                            x: 70 * cos(Double(index) * .pi / 2 + (isAnimating ? 0.3 : 0)),
                            y: 70 * sin(Double(index) * .pi / 2 + (isAnimating ? 0.3 : 0))
                        )
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)
                }

                // Primary icon
                Image(systemName: primaryIcon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .offset(y: isAnimating ? -3 : 3)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                // Secondary icon (top right)
                if let secondaryIcon {
                    Image(systemName: secondaryIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AppTheme.orange.opacity(0.8))
                        .symbolRenderingMode(.hierarchical)
                        .offset(x: 35, y: -30)
                        .rotationEffect(.degrees(isAnimating ? 5 : -5))
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)
                }

                // Tertiary icon (bottom left)
                if let tertiaryIcon {
                    Image(systemName: tertiaryIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.green.opacity(0.7))
                        .symbolRenderingMode(.hierarchical)
                        .offset(x: -38, y: 32)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: isAnimating)
                }
            }
            .frame(height: 160)

            // Text content
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .scaleEffect(isAnimating ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isAnimating)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
                .shadow(color: AppTheme.cardShadow(colorScheme: colorScheme), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preset Empty States for Different Scenarios
struct EmptyTasksState: View {
    var action: (() -> Void)? = nil

    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "checklist",
            secondaryIcon: "calendar.badge.clock",
            tertiaryIcon: "sparkles",
            title: "今日任务全部完成",
            message: "太棒了！你已经完成了所有任务，休息一下吧，或者添加新的学习任务",
            actionTitle: "添加任务",
            action: action,
            accentColor: AppTheme.orange
        )
    }
}

struct EmptyCoursesState: View {
    var action: (() -> Void)? = nil

    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "books.vertical",
            secondaryIcon: "graduationcap",
            tertiaryIcon: "star",
            title: "还没有添加课程",
            message: "添加你的第一门课程，开始追踪考试进度和知识掌握情况",
            actionTitle: "添加课程",
            action: action,
            accentColor: AppTheme.primary
        )
    }
}

struct EmptyPracticeState: View {
    var action: (() -> Void)? = nil

    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "pencil.and.list.clipboard",
            secondaryIcon: "target",
            tertiaryIcon: "checkmark.circle",
            title: "暂无练习题目",
            message: "选择课程知识点，开始练习真题和模拟测验，检验你的掌握程度",
            actionTitle: "开始练习",
            action: action,
            accentColor: AppTheme.green
        )
    }
}

struct EmptyPlanState: View {
    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "calendar.badge.clock",
            secondaryIcon: "arrow.clockwise",
            tertiaryIcon: "flag",
            title: "暂无冲刺计划",
            message: "制定你的考试冲刺计划，系统将自动为你排定每日学习任务和复习节奏",
            accentColor: AppTheme.primary
        )
    }
}

struct EmptyAnalyticsState: View {
    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "chart.bar.xaxis",
            secondaryIcon: "chart.line.uptrend.xyaxis",
            tertiaryIcon: "number",
            title: "数据积累中",
            message: "完成更多练习和任务后，这里将展示你的学习趋势和掌握度分析",
            accentColor: AppTheme.secondaryText
        )
    }
}

struct EmptyFlashcardsState: View {
    var action: (() -> Void)? = nil

    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "book.pages",
            secondaryIcon: "lightbulb",
            tertiaryIcon: "bookmark",
            title: "还没有知识手卡",
            message: "知识点手卡是碎片化记忆的好帮手，添加你的第一张知识手卡吧",
            actionTitle: "添加手卡",
            action: action,
            accentColor: AppTheme.green
        )
    }
}

struct EmptyCareerState: View {
    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "briefcase",
            secondaryIcon: "bell",
            tertiaryIcon: "doc.text",
            title: "暂无里程碑事件",
            message: "添加发布、课程或个人里程碑，系统会帮你追踪执行进度和提醒时间",
            accentColor: AppTheme.orange
        )
    }
}

// MARK: - Inline Empty State (Compact)
struct InlineEmptyState: View {
    let icon: String
    let title: String
    let message: String

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.secondaryText.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
                .rotationEffect(.degrees(isAnimating ? 3 : -3))
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.7))
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Empty State for Search Results
struct EmptySearchState: View {
    let query: String

    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "magnifyingglass",
            secondaryIcon: "doc.text.magnifyingglass",
            title: "未找到结果",
            message: "未找到与「\(query)」相关的内容，请尝试其他关键词",
            accentColor: AppTheme.secondaryText
        )
    }
}

// MARK: - Network Error State
struct NetworkErrorState: View {
    var retryAction: (() -> Void)? = nil

    var body: some View {
        EmptyStateIllustration(
            primaryIcon: "wifi.exclamationmark",
            secondaryIcon: "arrow.clockwise",
            title: "网络连接异常",
            message: "请检查网络连接后重试，或者稍后再试",
            actionTitle: "重试",
            action: retryAction,
            accentColor: AppTheme.error
        )
    }
}
