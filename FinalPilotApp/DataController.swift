import CoreData
import SwiftUI

// MARK: - DataController

// NSPersistentContainer 单例模式
// Core Data 的 NSPersistentContainer 是重量级对象（初始化需加载模型文件、创建 SQLite 连接、配置线程队列）。
//        如果每次用都创建新实例，会导致：1) 内存重复分配；2) 数据库连接数暴涨；3) 多上下文写入冲突。
//        单例模式确保整个 App 生命周期内只有一个容器实例，所有 NSManagedObjectContext 都指向同一持久化栈。
@MainActor
final class DataController: ObservableObject {
    // 单例的 `static let shared` 是线程安全的延迟初始化
    // Swift 的 `static let` 由运行时自动保证线程安全（内部使用 dispatch_once 语义），无需手动加锁。
    //        相比 `static var shared: DataController!` 的强制解包方案，`let` 不可变性更安全，避免运行时被篡改。
    static let shared = DataController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // 依赖注入的 `inMemory` 参数实现同一套代码支持两种运行模式
    // `inMemory: true` 时将持久化存储 URL 设为 `/dev/null`，SQLite 的写入实际上被黑洞丢弃，
    //        重启后数据消失。这是 SwiftUI 预览和单元测试的常用技巧——不需要清理数据库文件，也不会污染真实数据。
    //        `NSPersistentStoreDescription` 决定存储后端（SQLite、Binary、In-Memory），本例只修改 URL 即可切换。
    init(inMemory: Bool = false) {
        // ValueTransformer 的注册必须在 NSPersistentContainer 初始化之前完成
        // Core Data 的 Transformable 属性在加载模型时就需要知道如何转换非标准类型（如 [String]）。
        //        ValueTransformer 是 Objective-C 运行时机制，基于 `NSValueTransformerName` 全局注册表。
        //        如果容器已经加载了模型，再注册 Transformer 会导致已加载的属性无法识别转换器，读取时返回 nil 或崩溃。
        //        注册调用 `setValueTransformer(_:forName:)` 本质是向全局字典插入 key-value，不是线程安全的，
        //        但 Swift 的 `static let` 单例初始化自带屏障，保证了注册和容器创建的顺序性。
        ValueTransformer.setValueTransformer(
            StringArrayTransformer(),
            forName: NSValueTransformerName("StringArrayTransformer")
        )

        container = NSPersistentContainer(name: "FinalPilot")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                // Core Data 加载失败调用 fatalError 是合理的兜底策略
                // 持久化存储加载失败意味着整个 App 的数据层无法工作，继续运行会导致后续所有操作崩溃或数据丢失。
                //        `fatalError` 在 Release 环境下会直接终止进程，给用户明确的错误信号，避免在不可恢复状态下运行。
                //        更优雅的方案是：在加载回调中通过 Notification 通知 UI 层显示错误页，引导用户尝试修复或重装。
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        // automaticallyMergesChangesFromParent 解决父子上下文数据同步问题
        // Core Data 的上下文是**工作副本**（working copy），`viewContext`（主线程）和后台上下文可以共享同一个持久化协调器（NSPersistentStoreCoordinator）。
        //        当后台上下文保存后，持久化存储中的数据已更新，但 `viewContext` 内存中的对象还是旧版本。
        //        `automaticallyMergesChangesFromParent = true` 让 `viewContext` 自动监听父级（persistentStoreCoordinator）的保存通知，
        //        自动合并变更，无需手动调用 `mergeChanges(fromContextDidSave:)`。
        container.viewContext.automaticallyMergesChangesFromParent = true

        // mergeByPropertyObjectTrump 的合并策略选择
        // Core Data 上下文合并时可能遇到冲突：内存中的对象和数据库中的对象同一属性值不同。
        //        `mergeByPropertyObjectTrump` 的策略是：以内存对象（object）的属性值为准，覆盖数据库中的值（"Trump" 即"胜出"）。
        //        对应策略：`mergeByPropertyStoreTrump` 以数据库为准。选择 objectTrump 是因为：用户当前界面的编辑状态是最新的，
        //        不应被后台同步或其他线程的写入覆盖。但如果后台任务执行了批量更新（如服务器同步），则应该用 storeTrump。
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        registerAutoSave()
    }

    // 后台上下文必须独立创建，不能复用 viewContext
    // `viewContext` 被设计为主线程专用，它的并发类型是 `NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType`，
    //        所有操作必须在主线程执行。如果直接在后台线程调用 `viewContext.save()` 会触发 `EXC_BAD_ACCESS` 或数据损坏。
    //        `newBackgroundContext()` 创建的是 `privateQueueConcurrencyType` 上下文，Core Data 会自动管理一个私有队列，
    //        所有操作在这个私有队列中异步执行，通过 `perform(_:)` 或 `performAndWait(_:)` 提交任务。
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }

    /// 保存 viewContext 中未提交的更改。
    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Auto Save

    // 自动保存利用 UIApplication 生命周期通知，在 App 进入后台前触发保存
    // iOS 的 App 生命周期：用户按 Home 键或切换 App 时，系统先发送 `willResignActiveNotification`，
    //        然后发送 `didEnterBackgroundNotification`。在这两个节点保存，可以确保用户离开 App 时的最新状态被持久化。
    //        如果不自动保存，用户可能丢失最近的操作（比如刚完成的学习任务状态）。
    //        这里同时监听两个通知是为了保险：`willResignActive` 是 App 失去焦点但可能还在前台（如接电话），
    //        `didEnterBackground` 是 App 正式进入后台。理论上只监听一个就够了，但双重保障可以避免极端情况遗漏。
    private func registerAutoSave() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.save()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.save()
            }
        }
    }

    // MARK: - Preview

    static let preview: DataController = {
        let controller = DataController(inMemory: true)
        CoreDataMigrationHelper.migrateSeedDataIfNeeded(context: controller.viewContext)
        return controller
    }()
}

// MARK: - StringArrayTransformer

/// 将 [String] 数组与 Data 进行双向转换的 Value Transformer。
/// 用于 Core Data 的 Transformable 属性，支持 JSON 编码/解码。
@objc(StringArrayTransformer)
final class StringArrayTransformer: ValueTransformer {
    override class func allowsReverseTransformation() -> Bool { true }
    override class func transformedValueClass() -> AnyClass { NSData.self }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let array = value as? [String] else { return nil }
        return try? JSONEncoder().encode(array)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
}
