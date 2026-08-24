import SwiftUI
import CoreData
import UserNotifications

@main
struct FinalPilotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataController: DataController
    @StateObject private var store: FinalPilotStore
    private let isRunningTests: Bool

    init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        self.isRunningTests = isRunningTests
        _dataController = StateObject(
            wrappedValue: isRunningTests ? DataController(inMemory: true) : DataController.shared
        )
        _store = StateObject(wrappedValue: FinalPilotStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(dataController)
                .environment(\.managedObjectContext, dataController.viewContext)
                .onAppear {
                    // Unit tests run inside the application process. Keep the test
                    // host deterministic and avoid permission prompts or widget IO.
                    guard !isRunningTests else { return }
                    // 首次启动：从 SeedData 迁移到 Core Data
                    CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: dataController.viewContext)
                    // 同步 Widget 数据
                    store.syncToWidget()
                    // 请求通知权限
                    NotificationManager.shared.requestAuthorization()
                    // 延迟调度通知（等待权限授予）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if NotificationManager.shared.isNotificationsEnabled {
                            StudyReminderScheduler.shared.rescheduleAllNotifications(store: store)
                        }
                    }
                }
                .onReceive(store.objectWillChange) { _ in
                    store.syncToWidget()
                }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // 应用在前台时也显示通知横幅
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // 用户点击通知后的响应
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        switch actionIdentifier {
        case "MARK_DONE":
            if let taskID = userInfo["taskID"] as? String {
                print("用户标记任务完成: \(taskID)")
            }
        case "REMIND_LATER":
            print("用户选择稍后提醒")
        case "PRACTICE_NOW":
            print("用户选择立即练习")
        case "SKIP":
            print("用户跳过此提醒")
        default:
            break
        }

        completionHandler()
    }
}
