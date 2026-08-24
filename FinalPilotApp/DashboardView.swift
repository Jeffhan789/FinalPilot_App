import Foundation
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: FinalPilotStore

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(now: timeline.date)
                        metricRow
                        knowledgeFlashcardsEntry
                        examTrack
                        conflictPanel
                        skipPanel
                    }
                    .padding()
                }
                .background(AppTheme.background.ignoresSafeArea())
            }
            .navigationTitle("今日冲刺")
        }
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Label(todayDateText(for: now), systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.primary.opacity(0.08), in: Capsule())

                    Text("Exam Sprint Mode")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                    Text("考试优先，机动事务保温")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.orange)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("双考试倒计时")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.secondaryText)

                HStack(spacing: 10) {
                    ForEach(primaryExamCourses) { course in
                        examCountdownCard(for: course, now: now)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var primaryExamCourses: [Course] {
        let courseIDs: Set<String> = ["c310_multi_agent", "e320_neural_network"]
        return store.courses
            .filter { courseIDs.contains($0.id) }
            .sorted { ($0.examDate ?? .distantFuture) < ($1.examDate ?? .distantFuture) }
    }

    private func examCountdownCard(for course: Course, now: Date) -> some View {
        let tint = AppTheme.courseColor(course.colorKey)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: course.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(course.name.prefixName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Spacer(minLength: 0)
            }

            Text(countdownValue(for: course, now: now))
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(examDateText(for: course))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)

            Text(examMetaText(for: course))
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.16))
        }
    }

    private var metricRow: some View {
        HStack(spacing: 10) {
            MetricTile(title: "完成率", value: "\(Int(store.completionRate * 100))%", icon: "checkmark.seal", color: AppTheme.green)
            MetricTile(title: "薄弱点", value: "\(store.highRiskKnowledgePoints.count)", icon: "exclamationmark.triangle", color: AppTheme.orange)
            MetricTile(title: "已完成", value: "\(store.totalStudyMinutes)m", icon: "timer", color: AppTheme.primary)
        }
    }

    private var knowledgeFlashcardsEntry: some View {
        NavigationLink {
            KnowledgeFlashcardsView()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "rectangle.stack.fill")
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日知识手卡")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text("C310 / E320 前两天课件笔记，按考点展开")
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
                    flashcardPill(title: "总数", value: "\(todayFlashcards.count)")
                    flashcardPill(title: "C310", value: "\(flashcardCount(for: "c310_multi_agent"))")
                    flashcardPill(title: "E320", value: "\(flashcardCount(for: "e320_neural_network"))")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var todayFlashcards: [KnowledgeFlashcard] {
        store.flashcards.sorted {
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return $0.title < $1.title
        }
    }

    private func flashcardCount(for courseID: String) -> Int {
        todayFlashcards.filter { $0.courseID == courseID }.count
    }

    private func flashcardPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var examTrack: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Exam Track", subtitle: "Must 任务优先，先处理高风险知识点")
            ForEach(store.tasks(track: .exam, bucket: .must)) { task in
                TaskCard(task: task) {
                    store.toggleTask(task)
                }
            }

            let shouldTasks = store.tasks(track: .exam, bucket: .should)
            if !shouldTasks.isEmpty {
                SectionHeader(title: "Exam Should", subtitle: "有余力再补，避免平均用力")
                ForEach(shouldTasks) { task in
                    TaskCard(task: task) {
                        store.toggleTask(task)
                    } onDefer: {
                        store.deferTask(task)
                    }
                }
            }
        }
    }

    private var conflictPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "冲突提醒", subtitle: "ConflictAgent 当前建议")
            VStack(alignment: .leading, spacing: 8) {
                Label("C310 先考，今天必须把 Agent 基础和 Q1 真题入口打通。", systemImage: "exclamationmark.shield")
                Label("E320 只晚一天，每天至少保留一个公式/算法闭环。", systemImage: "arrow.triangle.merge")
                Label("里程碑已收进计划分支，5 月 14 前只在需要时做最低准备包。", systemImage: "calendar.badge.clock")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var skipPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "今天不建议做", subtitle: "把低收益任务明确放下")
            ForEach(skipTasks) { task in
                TaskCard(task: task) {
                    store.toggleTask(task)
                }
            }
        }
    }

    private var skipTasks: [StudyTask] {
        store.tasks
            .filter { $0.bucket == .skip }
            .sorted { $0.minutes > $1.minutes }
    }

    private func todayDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: date)
    }

    private func countdownValue(for course: Course, now: Date) -> String {
        guard let days = store.daysUntil(course.examDate, from: now) else {
            return "--"
        }
        if days < 0 {
            return "已结束"
        }
        if days == 0 {
            return "今天"
        }
        return "\(days)天"
    }

    private func examDateText(for course: Course) -> String {
        guard let examDate = course.examDate else {
            return "考试时间待定"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "M月d日 HH:mm 考试"
        return formatter.string(from: examDate)
    }

    private func examMetaText(for course: Course) -> String {
        durationText(for: course) ?? ""
    }

    private func durationText(for course: Course) -> String? {
        guard let minutes = course.examDurationMinutes else {
            return nil
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 && remainingMinutes > 0 {
            return "\(hours)小时\(remainingMinutes)分钟"
        }
        if hours > 0 {
            return "\(hours)小时"
        }
        return "\(minutes)分钟"
    }
}

struct KnowledgeFlashcardsView: View {
    @EnvironmentObject private var store: FinalPilotStore
    @State private var selectedCourseID = "all"
    @State private var selectedDayFilter: FlashcardDayFilter = .all
    @State private var selectedImportanceFilter: FlashcardImportanceFilter = .all
    @State private var selectedSortMode: FlashcardSortMode = .noteOrder

    private let scopedCourseIDs: Set<String> = ["c310_multi_agent", "e320_neural_network"]

    private var courses: [Course] {
        store.courses.filter { scopedCourseIDs.contains($0.id) }
    }

    private var filteredCards: [KnowledgeFlashcard] {
        store.flashcards
            .filter { selectedCourseID == "all" || $0.courseID == selectedCourseID }
            .filter { selectedDayFilter.matches($0) }
            .filter { selectedImportanceFilter.matches($0.priority) }
            .sorted(by: isSortedBefore)
    }

    private var cardSections: [FlashcardSection] {
        let groups = Dictionary(grouping: filteredCards) { sectionKey(for: $0) }

        return groups.map { key, cards in
            FlashcardSection(
                id: key,
                title: sectionTitle(for: cards[0]),
                subtitle: sectionSubtitle(for: cards),
                tint: sectionTint(for: cards[0]),
                sortRank: sectionSortRank(for: cards[0]),
                cards: cards.sorted(by: isSortedBefore)
            )
        }
        .sorted { lhs, rhs in
            if lhs.sortRank != rhs.sortRank {
                return lhs.sortRank < rhs.sortRank
            }
            return lhs.title < rhs.title
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "知识手卡", subtitle: "只覆盖 C310 / E320 Day1-Day2，先把当天学习内容打牢")
                filterNavigationBar
                overview

                ForEach(cardSections) { section in
                    flashcardSection(section)
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("今日手卡")
    }

    private var filterNavigationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("课程", selection: $selectedCourseID) {
                        Text("全部课程").tag("all")
                        ForEach(courses) { course in
                            Text(course.name.prefixName).tag(course.id)
                        }
                    }
                } label: {
                    filterChip(title: "课程", value: selectedCourseLabel, icon: "books.vertical")
                }

                Menu {
                    Picker("天数", selection: $selectedDayFilter) {
                        ForEach(FlashcardDayFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                } label: {
                    filterChip(title: "天数", value: selectedDayFilter.label, icon: "calendar")
                }

                Menu {
                    Picker("重要度", selection: $selectedImportanceFilter) {
                        ForEach(FlashcardImportanceFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                } label: {
                    filterChip(title: "重要度", value: selectedImportanceFilter.label, icon: "flag")
                }

                Menu {
                    Picker("排序", selection: $selectedSortMode) {
                        ForEach(FlashcardSortMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                } label: {
                    filterChip(title: "排序", value: selectedSortMode.label, icon: "arrow.up.arrow.down")
                }

                Button {
                    selectedCourseID = "all"
                    selectedDayFilter = .all
                    selectedImportanceFilter = .all
                    selectedSortMode = .noteOrder
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var selectedCourseLabel: String {
        guard selectedCourseID != "all" else { return "全部" }
        return courses.first { $0.id == selectedCourseID }?.name.prefixName ?? "全部"
    }

    private func filterChip(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var overview: some View {
        HStack(spacing: 8) {
            overviewPill(title: "当前", value: "\(filteredCards.count) 张")
            overviewPill(title: "分类", value: "\(cardSections.count) 组")
            overviewPill(title: "范围", value: "前两天")
        }
    }

    private func overviewPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func flashcardSection(_ section: FlashcardSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Text("\(section.cards.count) 张")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(section.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(section.tint.opacity(0.1), in: Capsule())
            }
            .padding(.top, 4)

            ForEach(section.cards) { card in
                flashcardRow(card)
            }
        }
    }

    private func flashcardRow(_ card: KnowledgeFlashcard) -> some View {
        let tint = courseTint(for: card)

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text(readableFlashcardText(card.answer))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "target")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 1)
                    Text(readableFlashcardText(card.examHint, compact: true))
                        .font(.caption.weight(.semibold))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 6) {
                    Label("重要程度：\(importanceText(card.priority))", systemImage: "flag.fill")
                        .foregroundStyle(importanceColor(card.priority))
                    Label(card.sourceTitle, systemImage: "doc.text")
                    if let point = knowledgePoint(for: card) {
                        Label("\(point.chapter) · \(point.title)", systemImage: "brain.head.profile")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

                tagRow(card.tags, tint: tint)
            }
            .padding(.top, 10)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .center, spacing: 4) {
                    Text(card.dayLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 46, height: 34)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("重要度 \(importanceText(card.priority))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(importanceColor(card.priority))
                    Text(card.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(card.prompt)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(tint)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func tagRow(_ tags: [String], tint: Color) -> some View {
        FlowTags(tags: tags, tint: tint)
    }

    private func readableFlashcardText(_ text: String, compact: Bool = false) -> String {
        let paragraphBreak = compact ? "\n" : "\n\n"
        var formatted = text

        for marker in ["。", "？", "！"] {
            formatted = formatted.replacingOccurrences(of: marker, with: "\(marker)\(paragraphBreak)")
        }
        formatted = formatted.replacingOccurrences(of: "；", with: "；\n")
        formatted = formatted.replacingOccurrences(of: "。\(paragraphBreak)）", with: "。）")
        formatted = formatted.replacingOccurrences(
            of: #"\s+(\d+\.\s)"#,
            with: paragraphBreak + "$1",
            options: .regularExpression
        )
        formatted = formatted.replacingOccurrences(
            of: #"\s+(Q\d+[.．、]\s*)"#,
            with: paragraphBreak + "$1",
            options: .regularExpression
        )
        formatted = formatted.replacingOccurrences(
            of: #"\s+(A\d+[.．、：:]\s*)"#,
            with: paragraphBreak + "$1",
            options: .regularExpression
        )

        while formatted.contains("\n\n\n") {
            formatted = formatted.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func courseTint(for card: KnowledgeFlashcard) -> Color {
        let colorKey = courses.first { $0.id == card.courseID }?.colorKey ?? "teal"
        return AppTheme.courseColor(colorKey)
    }

    private func knowledgePoint(for card: KnowledgeFlashcard) -> KnowledgePoint? {
        courses
            .first { $0.id == card.courseID }?
            .knowledgePoints
            .first { $0.id == card.knowledgePointID }
    }

    private func sectionKey(for card: KnowledgeFlashcard) -> String {
        "\(card.courseID)_\(card.dayLabel)"
    }

    private func sectionTitle(for card: KnowledgeFlashcard) -> String {
        "\(courseShortName(for: card.courseID)) · \(dayName(for: card.dayLabel))"
    }

    private func sectionSubtitle(for cards: [KnowledgeFlashcard]) -> String {
        let mustCount = cards.filter { $0.priority >= 5 }.count
        let highCount = cards.filter { $0.priority == 4 }.count
        return "S 必考 \(mustCount) 张 · A 高频 \(highCount) 张"
    }

    private func sectionTint(for card: KnowledgeFlashcard) -> Color {
        courseTint(for: card)
    }

    private func sectionSortRank(for card: KnowledgeFlashcard) -> Int {
        courseSortRank(card.courseID) * 10 + daySortRank(card.dayLabel)
    }

    private func courseShortName(for courseID: String) -> String {
        courses.first { $0.id == courseID }?.name.prefixName ?? courseID
    }

    private func dayName(for dayLabel: String) -> String {
        if dayLabel.contains("D1") { return "Day1 第一天" }
        if dayLabel.contains("D2") { return "Day2 第二天" }
        return dayLabel
    }

    private func isSortedBefore(_ lhs: KnowledgeFlashcard, _ rhs: KnowledgeFlashcard) -> Bool {
        switch selectedSortMode {
        case .noteOrder:
            return isOrderedBefore(lhs, rhs)
        case .importance:
            return isImportanceOrderedBefore(lhs, rhs)
        }
    }

    private func isImportanceOrderedBefore(_ lhs: KnowledgeFlashcard, _ rhs: KnowledgeFlashcard) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        return isOrderedBefore(lhs, rhs)
    }

    private func isOrderedBefore(_ lhs: KnowledgeFlashcard, _ rhs: KnowledgeFlashcard) -> Bool {
        let lhsCourseRank = courseSortRank(lhs.courseID)
        let rhsCourseRank = courseSortRank(rhs.courseID)
        if lhsCourseRank != rhsCourseRank {
            return lhsCourseRank < rhsCourseRank
        }

        let lhsDayRank = daySortRank(lhs.dayLabel)
        let rhsDayRank = daySortRank(rhs.dayLabel)
        if lhsDayRank != rhsDayRank {
            return lhsDayRank < rhsDayRank
        }

        let noteCompare = compareNoteOrder(lhs.title, rhs.title)
        if noteCompare != .orderedSame {
            return noteCompare == .orderedAscending
        }

        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private func courseSortRank(_ courseID: String) -> Int {
        switch courseID {
        case "c310_multi_agent": 0
        case "e320_neural_network": 1
        default: 9
        }
    }

    private func daySortRank(_ dayLabel: String) -> Int {
        if dayLabel.contains("D1") { return 0 }
        if dayLabel.contains("D2") { return 1 }
        return 9
    }

    private func compareNoteOrder(_ lhsTitle: String, _ rhsTitle: String) -> ComparisonResult {
        let lhsOrder = noteOrderComponents(lhsTitle)
        let rhsOrder = noteOrderComponents(rhsTitle)

        for index in 0..<max(lhsOrder.count, rhsOrder.count) {
            let lhsValue = index < lhsOrder.count ? lhsOrder[index] : -1
            let rhsValue = index < rhsOrder.count ? rhsOrder[index] : -1
            if lhsValue < rhsValue { return .orderedAscending }
            if lhsValue > rhsValue { return .orderedDescending }
        }

        return .orderedSame
    }

    private func noteOrderComponents(_ title: String) -> [Int] {
        guard
            let start = title.firstIndex(of: "["),
            let end = title[start...].firstIndex(of: "]")
        else {
            return [nonNumericNoteRank(title)]
        }

        let token = String(title[title.index(after: start)..<end])
        let components = token.split(separator: ".").compactMap { Int($0) }
        return components.isEmpty ? [nonNumericNoteRank(title)] : components
    }

    private func nonNumericNoteRank(_ title: String) -> Int {
        if title.hasPrefix("[导学]") { return 0 }
        if title.hasPrefix("[模板]") { return 900 }
        if title.hasPrefix("[主动回忆]") { return 910 }
        if title.hasPrefix("[易错]") { return 920 }
        if title.hasPrefix("[自测]") { return 930 }
        if title.hasPrefix("[答案检查]") { return 940 }
        if title.hasPrefix("[术语]") { return 950 }
        if title.hasPrefix("[衔接]") { return 960 }
        if title.hasPrefix("[方法]") { return 970 }
        return 999
    }

    private func importanceText(_ priority: Int) -> String {
        switch priority {
        case 5...: "S 必考"
        case 4: "A 高频"
        case 3: "B 理解"
        default: "C 浏览"
        }
    }

    private func importanceColor(_ priority: Int) -> Color {
        switch priority {
        case 5...: AppTheme.orange
        case 4: AppTheme.primary
        case 3: AppTheme.green
        default: AppTheme.secondaryText
        }
    }
}

private enum FlashcardDayFilter: String, CaseIterable, Identifiable {
    case all
    case day1
    case day2

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "全部"
        case .day1: "Day1"
        case .day2: "Day2"
        }
    }

    func matches(_ card: KnowledgeFlashcard) -> Bool {
        switch self {
        case .all: true
        case .day1: card.dayLabel.contains("D1")
        case .day2: card.dayLabel.contains("D2")
        }
    }
}

private enum FlashcardImportanceFilter: String, CaseIterable, Identifiable {
    case all
    case must
    case high
    case understand
    case skim

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "全部"
        case .must: "S 必考"
        case .high: "A 高频"
        case .understand: "B 理解"
        case .skim: "C 浏览"
        }
    }

    func matches(_ priority: Int) -> Bool {
        switch self {
        case .all: true
        case .must: priority >= 5
        case .high: priority == 4
        case .understand: priority == 3
        case .skim: priority < 3
        }
    }
}

private enum FlashcardSortMode: String, CaseIterable, Identifiable {
    case noteOrder
    case importance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noteOrder: "笔记顺序"
        case .importance: "重要优先"
        }
    }
}

private struct FlashcardSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tint: Color
    let sortRank: Int
    let cards: [KnowledgeFlashcard]
}

private struct FlowTags: View {
    let tags: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.1), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension String {
    var prefixName: String {
        if hasPrefix("C310") { return "C310" }
        if hasPrefix("E320") { return "E320" }
        return self
    }
}
