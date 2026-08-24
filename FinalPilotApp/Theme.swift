import SwiftUI

// MARK: - Dynamic Color Helpers
// MARK: [原理] UIColor dynamicProvider：iOS 13+ 的自动暗色切换机制
// [原理] `UIColor { traitCollection in ... }` 是 iOS 13 引入的 Dynamic Color API。它不会立即返回一个固定的颜色值，
//        而是返回一个"颜色提供者"（闭包）。当系统检测到界面风格变化（用户切换 light/dark 模式、或 App 进入/退出深色模式）时，
//        UIKit 会重新调用这个闭包，传入新的 `traitCollection`，获取对应的颜色。这是系统级的自动切换机制，
//        不需要任何 `onChange` 或 `NotificationCenter` 监听。
//        底层实现：UIColor 内部持有一个 ` UITraitCollection` 到 `CGColor` 的映射表，渲染时根据当前 trait 自动查表。
// [设计复盘] "SwiftUI 怎么支持深色模式？"
//        答：三种方案。1) `UIColor dynamicProvider`（本例）：最可靠，系统级自动切换，支持 Widget 和 App Clip；
//        2) `@Environment(\.colorScheme)` + `if colorScheme == .dark` 条件渲染：灵活但代码冗余，每个 View 都要写判断；
//        3) SwiftUI 的 `Color(uiColor:)` 直接包装 Dynamic UIColor。本方案选择方案 1 的原因是：
//        `Color` 在 SwiftUI 中是不可变的值类型，但 `UIColor` 的 dynamicProvider 是引用语义，系统可以在不重建 View 的情况下切换颜色，
//        性能更优。而且 `Color(light:dark:)` 扩展封装后，调用方完全无感知，代码最简洁。
extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return dark
            default:
                return light
            }
        })
    }
}

// MARK: - AppTheme
enum AppTheme {
    // MARK: Base Colors
    // MARK: [原理] 为什么用 `Color(light:dark:)` 而不是 `@Environment(\.colorScheme)` 读取
    // [原理] 两种方案都能实现暗色模式适配，但设计哲学不同：
    //        - `@Environment(\.colorScheme)` 是"运行时状态读取"：当用户切换模式时，SwiftUI 检测到环境变化，触发依赖它的 View 重建（`body` 重新执行）。
    //          这意味着每次切换模式，所有使用 `colorScheme` 的 View 都会重建。对于大型界面，这可能造成卡顿。
    //        - `UIColor dynamicProvider` 是"系统级自动切换"：颜色值由 UIKit 在渲染层自动切换，不需要重建 View。
    //          SwiftUI 的 `Color` 只是包装了 `UIColor`，真正渲染时 Core Animation 会根据当前 trait 自动选择正确的颜色。
    //        选择方案 2（本例）的另一个原因：App 的 `Color` 常量可以全局定义，不依赖任何 View 的生命周期或环境。
    //        如果每个 View 都用 `@Environment` 读取 `colorScheme` 再判断，代码会充斥大量条件分支，难以维护。
    // [设计复盘] "如果读者问你的 Theme 设计，重点讲什么？"
    //        答：重点讲三个设计决策。1) 暗色模式用 `UIColor dynamicProvider` 而不是 `@Environment(\.colorScheme)`，
    //        因为前者在渲染层自动切换，不需要重建 View，性能更优；2) 颜色分层：Base Colors（原始色值）→ Semantic Colors（用途语义，如 error/warning）
    //        → Surface Colors（界面层级，如 card/elevatedCard），层级清晰便于扩展；3) 动态适配函数（`adaptiveBackground` 等）
    //        作为兜底方案，用于某些需要条件判断的场景（如阴影强度需要同时知道 colorScheme）。
    static let primary = Color(light: UIColor(red: 0.15, green: 0.43, blue: 0.46, alpha: 1.0),
                               dark: UIColor(red: 0.40, green: 0.72, blue: 0.75, alpha: 1.0))
    static let orange = Color(light: UIColor(red: 0.91, green: 0.55, blue: 0.25, alpha: 1.0),
                              dark: UIColor(red: 1.00, green: 0.70, blue: 0.35, alpha: 1.0))
    static let green = Color(light: UIColor(red: 0.18, green: 0.62, blue: 0.40, alpha: 1.0),
                             dark: UIColor(red: 0.35, green: 0.78, blue: 0.55, alpha: 1.0))
    static let ink = Color(light: UIColor(red: 0.12, green: 0.16, blue: 0.20, alpha: 1.0),
                           dark: UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0))
    static let secondaryText = Color(light: UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1.0),
                                     dark: UIColor(red: 0.60, green: 0.63, blue: 0.68, alpha: 1.0))
    static let background = Color(light: UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0),
                                  dark: UIColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1.0))
    static let card = Color(light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
                            dark: UIColor(red: 0.15, green: 0.17, blue: 0.20, alpha: 1.0))

    // MARK: Semantic Colors
    static let error = Color(light: UIColor(red: 0.85, green: 0.25, blue: 0.20, alpha: 1.0),
                             dark: UIColor(red: 1.00, green: 0.40, blue: 0.35, alpha: 1.0))
    static let warning = Color(light: UIColor(red: 0.90, green: 0.70, blue: 0.15, alpha: 1.0),
                               dark: UIColor(red: 1.00, green: 0.85, blue: 0.35, alpha: 1.0))
    static let success = Color(light: UIColor(red: 0.20, green: 0.70, blue: 0.35, alpha: 1.0),
                               dark: UIColor(red: 0.40, green: 0.85, blue: 0.55, alpha: 1.0))

    // MARK: Surface Colors
    static let elevatedCard = Color(light: UIColor(red: 0.99, green: 0.99, blue: 1.00, alpha: 1.0),
                                    dark: UIColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1.0))
    static let groupedBackground = Color(light: UIColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1.0),
                                         dark: UIColor(red: 0.10, green: 0.12, blue: 0.14, alpha: 1.0))
    static let separator = Color(light: UIColor(red: 0.88, green: 0.89, blue: 0.90, alpha: 1.0),
                                 dark: UIColor(red: 0.25, green: 0.27, blue: 0.30, alpha: 1.0))

    // MARK: Gradients
    // MARK: [原理] LinearGradient 的线性插值：为什么用 `.topLeading` 到 `.bottomTrailing`
    // [原理] `LinearGradient` 在底层是 Core Graphics 的 `CGGradient`，它的颜色过渡不是简单的两个颜色混合，
    //        而是沿着起止点连线方向做一维线性插值。具体来说，对于渐变线上任意一点 p，其颜色 = `startColor + (endColor - startColor) * t`，
    //        其中 `t` 是 p 到起点的距离 / 起点到终点的总距离。`t ∈ [0, 1]`，`t=0` 时纯 startColor，`t=1` 时纯 endColor。
    //        选择 `.topLeading` → `.bottomTrailing`（对角线）而不是 `.top` → `.bottom`（垂直），是因为对角线渐变更有"动感和层次感"，
    //        符合现代 UI 设计趋势（如 Apple 的 iOS 设置界面背景）。技术上，`startPoint` 和 `endPoint` 是单位坐标系（0-1），
    //        `.topLeading = (0, 0)`，`.bottomTrailing = (1, 1)`，`.top = (0.5, 0)` 等。
    // [设计复盘] "SwiftUI 的渐变是怎么实现的？性能怎么样？"
    //        答：`LinearGradient` 是 Core Graphics 的 `CGGradient` 上层封装。渲染时 GPU 对渐变区域进行线性插值着色，
    //        性能极好（单次绘制开销与普通纯色填充几乎相同）。但要注意：如果渐变颜色变化频繁（如动画中每帧改变 `colors`），
    //        会触发 GPU 重新生成纹理，开销较大。优化方案：用 `Color` 的 `opacity` 变化模拟渐变亮度变化，而不是改变 `colors` 数组。
    //        本 App 的渐变颜色固定，只随暗色模式切换（通过 Dynamic UIColor），所以无性能问题。
    //        另外，如果需要更复杂的渐变（如径向、角度、mesh），SwiftUI 16+ 提供了 `MeshGradient` 和 `AngularGradient`，
    //        低版本可以用 `Canvas` 或 `Core Image` 的 `CIFilter` 实现。
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.8), primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var warmGradient: LinearGradient {
        LinearGradient(
            colors: [orange.opacity(0.7), orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [green.opacity(0.7), green],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [card, card.opacity(0.95)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.15), orange.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var darkOverlayGradient: LinearGradient {
        LinearGradient(
            colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Dynamic Helpers
    // MARK: [原理] 动态适配函数与 `Color(light:dark:)` 的互补关系
    // [原理] 本例同时提供了两种暗色适配方案：`Color(light:dark:)` 静态常量 和 `adaptiveBackground(forScheme:)` 动态函数。
    //        两者的区别：静态常量在初始化时绑定 Dynamic UIColor，系统会自动切换，但颜色值是固定的（如 primary 在 light 下永远是 #0x246e76）；
    //        动态函数接受 `ColorScheme` 参数，可以在运行时根据条件选择不同色值（如阴影深浅需要根据当前 scheme 动态调整）。
    //        为什么需要两者？因为有些场景无法通过 Dynamic UIColor 表达，如 `shadow(color:radius:x:y:)` 的阴影颜色需要同时知道 `colorScheme`
    //        来决定不透明度（light 下 0.06，dark 下 0.3）。如果硬编码固定 opacity，在某一模式下会太弱或太强。
    // [设计复盘] "你的 Theme 为什么同时有静态常量和动态函数？不会重复吗？"
    //        答：不是重复，是互补。静态常量（`primary`、`background` 等）用于 90% 的场景——文字、背景、按钮颜色，
    //        它们使用 `UIColor dynamicProvider`，系统会自动切换，不需要任何额外代码。动态函数（`adaptiveBackground`、`adaptiveCard` 等）
    //        用于需要运行时判断 colorScheme 的复杂场景，如阴影深浅、border 颜色、或者与外部数据源（服务器返回的图片/颜色）混合时。
    //        设计原则是"默认用最简方案，复杂场景用动态函数兜底"。
    static func adaptiveBackground(forScheme scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.08, green: 0.10, blue: 0.12) : Color(red: 0.96, green: 0.97, blue: 0.98)
    }

    static func adaptiveCard(forScheme scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.15, green: 0.17, blue: 0.20) : Color.white
    }

    static func adaptiveInk(forScheme scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.92, green: 0.94, blue: 0.96) : Color(red: 0.12, green: 0.16, blue: 0.20)
    }

    // MARK: Existing Helpers (Enhanced for Dark Mode)
    // MARK: [原理] 业务语义颜色函数：为什么用函数封装而不是静态常量
    // [原理] `courseColor(_:)`, `phaseColor(_:)` 等函数封装了"业务语义到颜色"的映射关系。
    //        这些颜色不是纯视觉 Token（如 primary/background），而是"业务概念"（如 sprintPhase = .foundation 对应 primary 色）。
    //        用函数而非静态常量的原因：1) 参数是枚举或字符串，运行时才能确定；2) 映射关系可能随业务变化，集中在一处便于维护；
    //        3) 可以统一处理 fallback（如 unknown key 返回 primary）。
    //        这些函数也使用了 `Color(light:dark:)` 初始化器，说明业务颜色同样需要适配暗色模式。
    // [设计复盘] "Theme 中的业务颜色和基础颜色有什么区别？"
    //        答：基础颜色（primary/orange/green 等）是"视觉原子"，不携带业务含义；业务颜色（courseColor/phaseColor 等）是"语义映射"，
    //        将业务状态/枚举映射到具体的视觉颜色。分层的好处是：当品牌色改变时，只需改基础颜色，业务颜色自动跟随；
    //        当业务逻辑变化时（如新增 sprint phase），只需在语义映射函数中增加 case，不影响基础色板。
    //        这也是设计系统中"Token 分层"的实践：Raw Color → Semantic Color → Component Color。
    static func courseColor(_ key: String) -> Color {
        switch key {
        case "blue": Color(light: UIColor(red: 0.18, green: 0.42, blue: 0.78, alpha: 1.0),
                           dark: UIColor(red: 0.40, green: 0.62, blue: 1.00, alpha: 1.0))
        case "orange": orange
        default: primary
        }
    }

    static func bucketColor(_ bucket: TaskBucket) -> Color {
        switch bucket {
        case .must: orange
        case .should: primary
        case .skip: secondaryText
        }
    }

    static func phaseColor(_ phase: SprintPlanPhase) -> Color {
        switch phase {
        case .foundation: primary
        case .highFrequency: orange
        case .pastPaper: Color(light: UIColor(red: 0.18, green: 0.42, blue: 0.78, alpha: 1.0),
                               dark: UIColor(red: 0.40, green: 0.62, blue: 1.00, alpha: 1.0))
        case .examSwitch: green
        }
    }

    static func questionSourceColor(_ source: QuestionSourceType) -> Color {
        switch source {
        case .lecture: primary
        case .tutorial: green
        case .pastPaper: Color(light: UIColor(red: 0.18, green: 0.42, blue: 0.78, alpha: 1.0),
                               dark: UIColor(red: 0.40, green: 0.62, blue: 1.00, alpha: 1.0))
        case .finalExam: orange
        case .sprintNote: Color(light: UIColor(red: 0.48, green: 0.36, blue: 0.72, alpha: 1.0),
                                 dark: UIColor(red: 0.68, green: 0.56, blue: 0.92, alpha: 1.0))
        }
    }

    // MARK: Shadows
    // MARK: [原理] Shadow 为什么要用动态函数而不是 Dynamic UIColor：opacity 的上下文依赖
    // [原理] `shadow(color:radius:x:y:)` 的 `color` 参数接受 SwiftUI `Color`，理论上也可以包装 Dynamic UIColor。
    //        但阴影的不透明度（opacity）必须与当前 colorScheme 强相关：light 模式下阴影很淡（0.06），dark 模式下反而要加深（0.3）。
    //        这是因为暗色模式的界面本身已经很深，如果阴影保持同样不透明度，几乎不可见，导致层级感丢失。
    //        这个逻辑无法用 Dynamic UIColor 表达，因为 Dynamic UIColor 只映射"颜色值"，而这里的 opacity 需要根据 scheme 动态计算。
    //        这就是 Theme 同时提供静态常量（Color(light:dark:)）和动态函数（adaptive*）的原因。
    // [设计复盘] "暗色模式下阴影怎么处理？有什么坑？"
    //        答：坑在于"暗色模式的阴影要更深而不是更浅"。直觉上 dark 模式应该降低阴影强度，但实际 UI 体验是：
    //        dark 背景已经很深，如果阴影保持 light 模式的 0.06 opacity，几乎看不见，卡片会贴在背景上，没有悬浮感。
    //        正确做法：dark 模式阴影 opacity 提升到 0.3 甚至 0.4，同时略微增加 radius。
    //        本例的 `cardShadow` / `elevatedShadow` 就是典型实现：light (0.06, radius 8) vs dark (0.3, radius 8 或更高)。
    static func cardShadow(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.06)
    }

    static func elevatedShadow(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.10)
    }

    // MARK: Typography Helpers
    // MARK: [原理] Typography Helpers 的设计理念：颜色与语义绑定，而非硬编码
    // [原理] `sectionTitle(colorScheme:)` 和 `bodyText(colorScheme:)` 看似只是颜色的简单封装，
    //        但体现了"语义化颜色"的设计思想：调用方不直接写 `.foregroundColor(AppTheme.ink)`，
    //        而是写 `.foregroundColor(AppTheme.sectionTitle(colorScheme: colorScheme))`。
    //        好处是：当"章节标题"的颜色规范变化时（如从 ink 改为 primary），只需修改这一处，
    //        所有使用 `sectionTitle` 的地方自动更新。这比分散在各 View 中的硬编码颜色更容易维护。
    //        这些函数也展示了 Dynamic Helpers 的另一种用法：它们内部可能调用 `adaptiveInk` 或自定义逻辑，
    //        封装了"何时用 ink、何时用其他色"的判断。
    // [设计复盘] "你的 Theme 怎么保证全局颜色一致性？"
    //        答：通过三层防护。1) Token 化：所有颜色通过 Theme 常量/函数获取，禁止 View 中硬编码 Color(red:green:blue:)；
    //        2) 语义化：用 `sectionTitle`、`bodyText`、`courseColor` 等语义函数，而非直接使用 `primary`、`ink` 等基础色；
    //        3) 强制适配：所有颜色都必须通过 `Color(light:dark:)` 或 `adaptive*` 函数提供 dark 版本，不允许"只适配 light 模式"。
    //        这三层确保：品牌色更新 → 改基础常量；业务逻辑更新 → 改语义函数；新增 View → 只能从 Theme 取色，不能自创。
    static func sectionTitle(colorScheme: ColorScheme) -> Color {
        adaptiveInk(forScheme: colorScheme)
    }

    static func bodyText(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.75, green: 0.77, blue: 0.80) : secondaryText
    }
}

// MARK: - View Modifiers for Theme
// MARK: [原理] ViewModifier 封装复用样式，比直接写 `.background()` 更利于维护和测试
// [原理] SwiftUI 的 `ViewModifier` 是"样式封装"的最佳实践。如果不封装，每个 View 都要写：
//        `.background(AppTheme.adaptiveBackground(forScheme: colorScheme))`，代码重复且容易不一致。
//        `ViewModifier` 将样式逻辑封装为独立单元，调用方只需 `.themedBackground()` 即可，语义明确。
//        另一个好处是方便单元测试：可以单独测试 `ThemedBackground` 是否应用了正确的背景色，而不需要创建整个 View 树。
//        这里 `ThemedBackground` 用 `@Environment(\.colorScheme)` 读取当前模式，是因为 Modifier 也是 View 的参与者，
//        可以访问环境值。与 Theme 静态常量的 `UIColor dynamicProvider` 不冲突——后者在渲染层切换，前者在构建时读取。
// [设计复盘] "SwiftUI 中 ViewModifier 和自定义 View 有什么区别？"
//        答：`ViewModifier` 是"样式装饰器"，只修改现有 View 的外观（如背景、阴影、动画），不引入新的语义；
//        自定义 View（`struct MyView: View`）是"组件封装"，引入新的 UI 语义（如 `CourseCard`、`TaskRow`）。
//        选择原则：如果只是样式的组合（背景+圆角+阴影），用 `ViewModifier`；如果需要新的业务语义和数据绑定，用自定义 View。
//        本例中 `.themedCard()` 封装了"卡片样式"（背景 + 圆角 + 阴影），适合作为 Modifier；而"考试倒计时卡片"则应该是自定义 View，
//        因为它包含倒计时逻辑、点击事件等业务语义。不要滥用 ViewModifier 封装业务逻辑，否则会导致 Modifier 臃肿难维护。
struct ThemedBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppTheme.adaptiveBackground(forScheme: colorScheme))
    }
}

struct ThemedCardBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppTheme.adaptiveCard(forScheme: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ThemedShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .shadow(color: AppTheme.cardShadow(colorScheme: colorScheme), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }

    func themedCard() -> some View {
        modifier(ThemedCardBackground())
    }

    func themedShadow() -> some View {
        modifier(ThemedShadow())
    }
}

// MARK: - Color Scheme Preview Helper
// MARK: [原理] `ColorSchemePreview` 的 `.preferredColorScheme` 与系统级动态切换的本质区别
// [原理] `preferredColorScheme(_:)` 是一个 SwiftUI 环境覆盖修饰符，它会将该子树强制指定为某一种颜色方案（light/dark），
//        但**不会**影响系统全局设置。底层实现上，SwiftUI 会创建一个覆盖当前 `UITraitCollection` 的局部环境，
//        让该子树内的 View 认为系统处于指定的模式。这与 `UIApplication.shared.overrideUserInterfaceStyle`（全局强制）
//        或系统设置（用户层面）完全不同。注意：`.preferredColorScheme(.dark)` 只影响 View 树内部，
//        外部的状态栏、系统弹窗等不会受影响。
//        为什么这里用 VStack 叠加 light/dark 两个预览？因为 SwiftUI Preview 默认只展示一种模式，
//        通过叠加可以在 Xcode Canvas 中同时看到两种模式效果，极大提升 UI 调试效率。
// [设计复盘] "怎么在 SwiftUI Preview 中同时看到 light 和 dark 模式？"
//        答：标准方案有三种。1) 用 `.preferredColorScheme` 叠加两个 View（本例），在一个 Preview 中并排/上下展示两种模式；
//        2) 使用 `ForEach([ColorScheme.light, .dark], id: \.self) { scheme in ... }` 结合 `.preferredColorScheme(scheme)`
//        让 Xcode 自动生成两个 preview 标签页；3) 在 Preview 的右上角切换器手动切换。方案 1 最直观，适合快速对比。
//        但要注意：`.preferredColorScheme` 是向下传播的环境值，如果子 View 内部也使用了该修饰符，
//        会产生冲突（子 View 的会覆盖父 View 的），设计 Theme 时要避免深层嵌套的强制颜色方案。
struct ColorSchemePreview<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .preferredColorScheme(.light)
                .frame(height: 200)
                .clipped()

            Divider()

            content
                .preferredColorScheme(.dark)
                .frame(height: 200)
                .clipped()
        }
    }
}
