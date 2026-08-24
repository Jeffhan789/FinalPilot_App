import SwiftUI

struct CoursesView: View {
    @EnvironmentObject private var store: FinalPilotStore

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "课程状态", subtitle: "先看薄弱点，再决定今天是否追加练习")

                        ForEach(store.courses) { course in
                            NavigationLink {
                                CourseDetailView(courseID: course.id)
                            } label: {
                                CourseCard(course: course, daysUntilExam: store.daysUntil(course.examDate, from: timeline.date))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .background(AppTheme.background.ignoresSafeArea())
            }
            .navigationTitle("课程")
        }
    }
}

struct CourseDetailView: View {
    @EnvironmentObject private var store: FinalPilotStore
    let courseID: String

    private var course: Course? {
        store.courses.first { $0.id == courseID }
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { timeline in
            ScrollView {
                if let course {
                    VStack(alignment: .leading, spacing: 16) {
                        CourseCard(course: course, daysUntilExam: store.daysUntil(course.examDate, from: timeline.date))

                        SectionHeader(title: "知识点", subtitle: "掌握度低于 38% 会被标记为薄弱")
                        ForEach(course.knowledgePoints) { point in
                            knowledgePointRow(point, color: AppTheme.courseColor(course.colorKey))
                        }

                        SectionHeader(title: "推荐动作", subtitle: "把错题和里程碑知识串联处理")
                        VStack(alignment: .leading, spacing: 8) {
                            Label("薄弱知识点先做 15 分钟主动回忆，再看解释。", systemImage: "brain.head.profile")
                            Label("与里程碑实践相关的概念，额外整理 3 句简明说明。", systemImage: "checklist")
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                        .padding(14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                } else {
                    EmptyStateView(title: "没有找到课程", message: "课程数据会优先使用本地种子和内置快照。", icon: "books.vertical")
                        .padding()
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
        .navigationTitle(course?.name ?? "课程")
    }

    private func knowledgePointRow(_ point: KnowledgePoint, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(point.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("\(point.chapter) · 难度 \(point.difficulty)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text(point.status.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(point.status == .weak ? AppTheme.orange : color)
            }

            ProgressView(value: point.mastery)
                .tint(point.status == .weak ? AppTheme.orange : color)
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
