import Foundation
import UserNotifications
import SwiftUI

/// 本地通知管理器，负责权限请求、通知调度与取消
/// 所有通知内容均为中文，适配 FinalPilot 学呀学考试冲刺场景
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isNotificationsEnabled: Bool = false

    /// 用户在设置中选择的三个提醒时段（默认 9:00、14:00、20:00）
    @AppStorage("finalPilot_reminderHours") var reminderHours: String = "9,14,20"

    /// 是否开启高优先级知识点强化提醒
    @AppStorage("finalPilot_priorityAlertsEnabled") var priorityAlertsEnabled: Bool = true

    /// 是否开启考试倒计时提醒
    @AppStorage("finalPilot_countdownAlertsEnabled") var countdownAlertsEnabled: Bool = true

    /// 是否开启每日统计推送
    @AppStorage("finalPilot_dailySummaryEnabled") var dailySummaryEnabled: Bool = true

    private let center = UNUserNotificationCenter.current()

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - 权限管理

    /// 请求通知权限（首次调用时弹出系统授权弹窗）
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.authorizationStatus = granted ? .authorized : .denied
                self?.isNotificationsEnabled = granted
                if granted {
                    self?.registerNotificationCategories()
                }
                if let error = error {
                    print("[NotificationManager] 权限请求失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 检查当前通知授权状态
    func checkAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            // UNNotificationSettings is not Sendable under Swift 6. Extract the
            // value type before hopping back to the main actor.
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                self?.isNotificationsEnabled = status == .authorized
            }
        }
    }

    /// 打开系统设置，让用户手动修改通知权限
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - 通知分类（支持操作按钮）

    private func registerNotificationCategories() {
        // 复习提醒：标记完成、稍后提醒
        let markDoneAction = UNNotificationAction(
            identifier: "MARK_DONE",
            title: "标记完成",
            options: .foreground
        )
        let remindLaterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "15分钟后再提醒",
            options: []
        )
        let studyCategory = UNNotificationCategory(
            identifier: NotificationCategory.studyReminder,
            actions: [markDoneAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )

        // 错题回顾：立即练习、跳过
        let practiceNowAction = UNNotificationAction(
            identifier: "PRACTICE_NOW",
            title: "立即练习",
            options: .foreground
        )
        let skipAction = UNNotificationAction(
            identifier: "SKIP",
            title: "跳过",
            options: []
        )
        let reviewCategory = UNNotificationCategory(
            identifier: NotificationCategory.mistakeReview,
            actions: [practiceNowAction, skipAction],
            intentIdentifiers: [],
            options: []
        )

        // 考试倒计时：查看详情
        let viewDetailAction = UNNotificationAction(
            identifier: "VIEW_DETAIL",
            title: "查看详情",
            options: .foreground
        )
        let countdownCategory = UNNotificationCategory(
            identifier: NotificationCategory.examCountdown,
            actions: [viewDetailAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([studyCategory, reviewCategory, countdownCategory])
    }

    // MARK: - 通知调度

    /// 立即发送一条本地通知（用于测试或即时反馈）
    func sendImmediateNotification(title: String, body: String, userInfo: [AnyHashable: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: "immediate_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] 即时通知发送失败: \(error.localizedDescription)")
            }
        }
    }

    /// 发送每日复习提醒（指定时间触发）
    func scheduleDailyReminder(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int = 0,
        category: String = NotificationCategory.studyReminder,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = userInfo

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] 每日提醒调度失败: \(error.localizedDescription)")
            } else {
                print("[NotificationManager] 已调度每日提醒: \(identifier) @ \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    /// 发送一次性倒计时通知（指定日期触发）
    func scheduleOneTimeReminder(
        identifier: String,
        title: String,
        body: String,
        date: Date,
        category: String = NotificationCategory.examCountdown,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = userInfo

        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] 一次性通知调度失败: \(error.localizedDescription)")
            }
        }
    }

    /// 发送错题回顾通知（间隔一段时间后触发）
    func scheduleMistakeReviewReminder(
        identifier: String,
        title: String,
        body: String,
        afterMinutes: Int,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.mistakeReview
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(afterMinutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] 错题回顾通知调度失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 通知取消

    /// 取消指定标识符的通知
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// 取消所有待发送的通知
    func cancelAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    /// 清除所有已送达通知的角标
    func clearBadge() {
        center.setBadgeCount(0)
    }

    // MARK: - 已调度通知查询

    /// 获取当前所有待发送的通知列表
    /// 回调由 UserNotifications 的系统队列执行；调用方如需更新 UI，应自行切换到主线程。
    func getPendingNotifications(completion: @escaping @Sendable ([UNNotificationRequest]) -> Void) {
        center.getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
}

// MARK: - 通知分类标识符

struct NotificationCategory {
    static let studyReminder = "STUDY_REMINDER"
    static let examCountdown = "EXAM_COUNTDOWN"
    static let mistakeReview = "MISTAKE_REVIEW"
    static let dailySummary = "DAILY_SUMMARY"
}

// MARK: - 通知用户数据键

struct NotificationUserInfoKey {
    static let courseID = "courseID"
    static let knowledgePointID = "knowledgePointID"
    static let taskID = "taskID"
    static let questionID = "questionID"
    static let examDate = "examDate"
    static let daysUntilExam = "daysUntilExam"
}
