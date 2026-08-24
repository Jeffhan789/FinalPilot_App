import Foundation

/// 通知内容模板工厂，所有文案均为中文，适配 FinalPilot 考试冲刺场景
enum NotificationContent {

    // MARK: - 复习提醒

    /// 普通每日复习提醒
    static func dailyReminder(timeSlot: ReminderTimeSlot, todayTasks: Int, nextExamName: String? = nil, daysUntilExam: Int? = nil) -> (title: String, body: String) {
        switch timeSlot {
        case .morning:
            let examInfo: String
            if let name = nextExamName, let days = daysUntilExam, days >= 0 {
                examInfo = "距离 \(name) 还有 \(days) 天。"
            } else {
                examInfo = ""
            }
            return (
                title: "🎓 学呀学 · 今日冲刺",
                body: "\(examInfo)今日有 \(todayTasks) 个 Must 任务，优先保住 C310 / E320！"
            )
        case .afternoon:
            return (
                title: "📚 下午复习时间",
                body: "完成一套真题或复习辅导课笔记，保持手感。现在正是高效时段！"
            )
        case .evening:
            return (
                title: "🌙 晚间错题回顾",
                body: "睡前花 15 分钟复盘今日错题，利用睡眠记忆巩固效果翻倍。"
            )
        }
    }

    /// 高优先级知识点强化提醒（priority >= 5）
    static func highPriorityReminder(knowledgeTitle: String, prompt: String, courseName: String) -> (title: String, body: String) {
        return (
            title: "🔥 【高优先级】\(courseName) 知识点",
            body: "【\(knowledgeTitle)】\(prompt.prefix(80))… 抽 10 分钟强化记忆，考试高频出现！"
        )
    }

    /// 薄弱知识点提醒
    static func weakPointReminder(knowledgeTitle: String, mastery: Double, courseName: String) -> (title: String, body: String) {
        return (
            title: "⚠️ \(courseName) 薄弱点提醒",
            body: "【\(knowledgeTitle)】掌握度仅 \(Int(mastery * 100))%，建议优先复习。别让它成为考试失分点！"
        )
    }

    // MARK: - 考试倒计时

    /// 考试倒计时提醒（1/3/7 天）
    static func examCountdown(courseName: String, daysLeft: Int, examDate: Date) -> (title: String, body: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        let dateString = formatter.string(from: examDate)

        let urgency: String
        switch daysLeft {
        case 1: urgency = "⚠️ 明天就是考试日！"
        case 3: urgency = "🔥 还有 3 天，进入最后冲刺！"
        case 7: urgency = "📅 还有 1 周，规划好每日复习节奏。"
        default: urgency = "⏰ 考试倒计时提醒"
        }

        return (
            title: "\(urgency) \(courseName)",
            body: "\(courseName) 考试日期：\(dateString)（\(daysLeft) 天后）。建议今天完成真题模拟，调整生物钟。加油！"
        )
    }

    /// 考试当天提醒
    static func examDayReminder(courseName: String, examTime: Date) -> (title: String, body: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "H:mm"
        let timeString = formatter.string(from: examTime)

        return (
            title: "🚨 \(courseName) 考试今天开始",
            body: "考试将于 \(timeString) 开始。带好准考证、身份证和文具，深呼吸，相信自己！"
        )
    }

    // MARK: - 错题回顾

    /// 错题回顾提醒
    static func mistakeReview(questionSource: String, sourceTitle: String) -> (title: String, body: String) {
        return (
            title: "📝 错题回顾提醒",
            body: "【\(questionSource) · \(sourceTitle)】这道题之前做错了，现在再来做一次吧？间隔复习效果更好！"
        )
    }

    /// 高频错题集中复习
    static func frequentMistakesReview(wrongCount: Int, topTopic: String) -> (title: String, body: String) {
        return (
            title: "🎯 高频错题集中突破",
            body: "你最近错了 \(wrongCount) 道题，\(topTopic) 是重灾区。集中 30 分钟专项突破，效果显著！"
        )
    }

    // MARK: - 每日统计推送

    /// 每日学习统计摘要
    static func dailySummary(studyMinutes: Int, completedTasks: Int, totalTasks: Int, completionRate: Int) -> (title: String, body: String) {
        let hours = studyMinutes / 60
        let minutes = studyMinutes % 60
        let timeString = hours > 0 ? "\(hours) 小时 \(minutes) 分钟" : "\(minutes) 分钟"

        let encouragement: String
        if completionRate >= 80 {
            encouragement = "太棒了！保持这个节奏，考试稳了！💪"
        } else if completionRate >= 50 {
            encouragement = "进度不错，明天再努力一把！📈"
        } else {
            encouragement = "今天有点松懈哦，明天补回来！⏰"
        }

        return (
            title: "📊 今日学习报告",
            body: "今日学习 \(timeString)，完成 \(completedTasks)/\(totalTasks) 个任务（\(completionRate)%）。\(encouragement)"
        )
    }

    // MARK: - 即时反馈

    /// 任务完成鼓励
    static func taskCompleted(taskTitle: String) -> (title: String, body: String) {
        return (
            title: "✅ 任务完成！",
            body: "已完成「\(taskTitle)」，又向目标迈进了一步。休息一下，继续下一个任务吧！"
        )
    }

    /// 连续答对鼓励
    static func streakEncouragement(correctCount: Int) -> (title: String, body: String) {
        return (
            title: "🔥 \(correctCount) 连对！",
            body: "连续答对 \(correctCount) 道题，状态很好！继续保持，考试高分不是梦！"
        )
    }

    /// 新知识掌握庆祝
    static func knowledgeMastered(knowledgeTitle: String, courseName: String) -> (title: String, body: String) {
        return (
            title: "🎉 知识点掌握！",
            body: "【\(courseName) · \(knowledgeTitle)】已升级为「已掌握」。知识地图又亮了一块！"
        )
    }
}

// MARK: - 提醒时段枚举

enum ReminderTimeSlot: String, CaseIterable, Identifiable, Codable {
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: "早间提醒"
        case .afternoon: "午后提醒"
        case .evening: "晚间提醒"
        }
    }

    var icon: String {
        switch self {
        case .morning: "sun.max.fill"
        case .afternoon: "clock.fill"
        case .evening: "moon.fill"
        }
    }

    var defaultHour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 14
        case .evening: 20
        }
    }

    var description: String {
        switch self {
        case .morning: "9:00 开始今日冲刺，查看 Must 任务"
        case .afternoon: "14:00 下午高效时段，复习薄弱点"
        case .evening: "20:00 晚间复盘，回顾错题和总结"
        }
    }
}

// MARK: - 通知偏好设置结构

struct NotificationPreference: Identifiable, Codable {
    let id: String
    var isEnabled: Bool
    var timeSlot: ReminderTimeSlot
    var customHour: Int
    var customMinute: Int

    static let `default` = [
        NotificationPreference(id: "morning", isEnabled: true, timeSlot: .morning, customHour: 9, customMinute: 0),
        NotificationPreference(id: "afternoon", isEnabled: true, timeSlot: .afternoon, customHour: 14, customMinute: 0),
        NotificationPreference(id: "evening", isEnabled: true, timeSlot: .evening, customHour: 20, customMinute: 0)
    ]
}
