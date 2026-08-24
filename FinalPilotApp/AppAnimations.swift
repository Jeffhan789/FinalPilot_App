import SwiftUI

// MARK: - Confetti Particle Effect
// Canvas + TimelineView 实现 60fps 粒子系统，绕过 SwiftUI 的 View 重建开销
// SwiftUI 的常规动画（`withAnimation` + `View` 变化）每次状态变化会触发整个 View 树的重计算（`body` 重新执行），
//        对于 50 个粒子来说，50 个独立 View 的状态更新会导致 50 次 `body` 重算，性能极差（掉帧、耗电）。
//        `Canvas` 是 SwiftUI 的"直接渲染"API：你拿到 `GraphicsContext` 后直接调用底层绘制命令（fill、stroke、drawImage），
//        不经过 View 树重建。配合 `TimelineView(.animation)` 以 60fps 驱动，每帧通过 `elapsed` 时间计算粒子位置，直接绘制到屏幕。
//        这是 SwiftUI 中实现高性能粒子/游戏的正确方式。
struct ConfettiView: View {
    let colors: [Color]
    let particleCount: Int
    @State private var startTime = Date()
    @State private var isActive = true

    init(colors: [Color] = [AppTheme.primary, AppTheme.orange, AppTheme.green, AppTheme.warning],
         particleCount: Int = 50) {
        self.colors = colors
        self.particleCount = particleCount
    }

    var body: some View {
        // TimelineView(.animation) 的显式动画采样：以固定帧率驱动 Canvas 重绘
        // `TimelineView` 是 SwiftUI 的显式动画调度器。`.animation(minimumInterval: 1.0/60.0)` 表示
        //        以不低于 60fps 的频率调用 `content` 闭包，每次提供一个新的 `TimelineViewDefaultContext`。
        //        `context.date` 是帧的"理论显示时间"（基于 `CADisplayLink` 的 `targetTimestamp`），
        //        不是 `Date()` 的当前时间，这意味着即使主线程阻塞，动画时间仍然是连续的，不会跳帧。
        //        `paused: !isActive` 控制动画的启停：当 `isActive = false` 时，`TimelineView` 停止调度，
        //        Canvas 不再重绘，节省 CPU/GPU。这是显式动画（explicit animation）的核心特征：开发者完全控制
        //        每一帧的更新时机，不依赖 SwiftUI 的隐式状态变化检测。
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)
            Canvas { context, size in
                // 线性同余发生器（LCG）实现确定性伪随机数，保证 Canvas 可测试和可复现
                // 如果用 `Double.random(in:)`，每次 Canvas 重绘时粒子位置会随机变化（不可复现），也无法做快照测试。
                //        这里用 LCG（Linear Congruential Generator）伪随机算法：`seed = seed &* 6364136223846793005 &+ 1`。
                //        核心参数 6364136223846793005 是 glibc 的 LCG 乘数，经过统计学验证的"好"参数，周期足够长（2^64），分布均匀。
                //        每次 Canvas 绘制时以固定的 `startTime.hashValue` 为种子，生成的随机数序列完全一致，粒子轨迹是确定性的。
                var seed = startTime.hashValue
                func nextRandom() -> Double {
                    seed = seed &* 6364136223846793005 &+ 1
                    return Double(UInt64(bitPattern: Int64(seed))) / Double(UInt64.max)
                }
                func randCGFloat(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
                    min + CGFloat(nextRandom()) * (max - min)
                }

                for _ in 0..<particleCount {
                    let t = CGFloat(elapsed)
                    let startX = randCGFloat(size.width * 0.3, size.width * 0.7)
                    let startY = randCGFloat(size.height * 0.3, size.height * 0.5)
                    let vx = randCGFloat(-3, 3)
                    let vy = randCGFloat(-10, -3)
                    let w = randCGFloat(6, 12)
                    let h = randCGFloat(4, 8)
                    let colorIndex = Int(randCGFloat(0, CGFloat(colors.count)))
                    let color = colors[colorIndex % colors.count]
                    let rotSpeed = randCGFloat(-0.3, 0.3)
                    let decay = randCGFloat(0.4, 0.9)

                    // 粒子物理模拟：匀速运动 + 重力加速度 + 旋转 + 透明度衰减
                    // 这里用经典牛顿力学模拟粒子运动：
                    //        - x 方向：匀速运动 `x = startX + vx * t * 30`（30 是速度缩放系数，将随机数映射到屏幕像素）
                    //        - y 方向：竖直上抛运动 `y = startY + vy * t * 30 + 0.5 * 400 * t * t`。
                    //          其中 `vy` 为负（向上抛），`0.5 * 400 * t^2` 是重力加速度项（g ≈ 400 points/s²），
                    //          粒子先上升再下降，形成抛物线轨迹。
                    //        - 旋转：`rotation = rotSpeed * t * 5`，每个粒子以不同角速度旋转，模拟纸片飘落的视觉效果。
                    //        - 透明度衰减：`opacity = max(0, 1.0 - t / (decay * 2.5))`，`decay` 控制每个粒子的寿命，
                    //          在 `t = decay * 2.5` 秒时完全消失。`max(0, ...)` 防止负值。
                    let x = startX + vx * t * 30
                    let y = startY + vy * t * 30 + 0.5 * 400 * t * t
                    let rotation = rotSpeed * t * 5
                    let opacity = max(0, 1.0 - Double(t) / Double(decay * 2.5))

                    guard opacity > 0, y < size.height + 50, y > -50, x > -50, x < size.width + 50 else { continue }

                    let transform = CGAffineTransform.identity
                        .translatedBy(x: x, y: y)
                        .rotated(by: rotation)

                    let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)

                    context.fill(
                        Path(rect.applying(transform)),
                        with: .color(color.opacity(opacity))
                    )
                }
            }
        }
        .onAppear {
            startTime = Date()
            isActive = true
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Confetti Trigger Overlay
// Overlay + 条件渲染：通过状态控制粒子层的挂载与卸载
// `overlay` 将 `ConfettiView` 覆盖在目标 View 之上。`isPresented` 为 `true` 时创建 `ConfettiView`，
//        触发 `onAppear` 启动粒子动画；2.5 秒后通过 `DispatchQueue.main.asyncAfter` 自动将 `isPresented` 设为 `false`，
//        `ConfettiView` 被销毁。这种"创建-自动销毁"模式是典型的 ephemeral overlay 设计，避免粒子 View 长期占用内存。
//        `DispatchQueue.main.asyncAfter` 在主线程延迟执行，确保 UI 更新在主线程完成。
struct ConfettiOverlay: ViewModifier {
    @Binding var isPresented: Bool
    let colors: [Color]

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isPresented {
                        ConfettiView(colors: colors)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    isPresented = false
                                }
                            }
                    }
                }
            )
    }
}

extension View {
    func confettiOverlay(isPresented: Binding<Bool>, colors: [Color] = [AppTheme.primary, AppTheme.orange, AppTheme.green]) -> some View {
        modifier(ConfettiOverlay(isPresented: isPresented, colors: colors))
    }
}

// MARK: - Pressable Card Effect
// onLongPressGesture + pressing 回调：无延迟的按压状态检测
// SwiftUI 的 `onLongPressGesture` 通常用于检测"长按"（minimumDuration 达到后触发 `perform`），
//        但通过设置 `minimumDuration: .infinity` 可以禁用 perform 触发，仅使用 `pressing` 回调获取按压状态。
//        `pressing` 在手指按下时立即传 `true`，抬起时传 `false`，没有系统默认的 0.3 秒延迟。
//        `maximumDistance: .infinity` 允许手指在屏幕上滑动时仍然保持按压状态（不触发取消）。
//        这种技巧常用于按钮按下效果：比 `ButtonStyle` 更灵活，因为可以精确控制 scale 和 opacity 的动画参数。
struct PressableCardStyle: ViewModifier {
    @State private var isPressed = false
    var scale: CGFloat = 0.97
    var opacity: Double = 0.9

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .opacity(isPressed ? opacity : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
            .onLongPressGesture(
                minimumDuration: .infinity,
                maximumDistance: .infinity,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: {}
            )
    }
}

// MARK: - Hover Scale Effect
// onHover：跨平台的鼠标悬停检测，底层依赖 NSEvent/UITouch 的映射
// `onHover` 是 SwiftUI 的跨平台悬停事件 API。在 macOS 上，它直接监听 `NSEvent.mouseMoved` 和 `NSEvent.mouseExited`，
//        通过 `NSTrackingArea` 实现；在 iOS/iPadOS 13.4+ 上，它监听 `UIHoverGestureRecognizer`（指针设备，如妙控鼠标/触控板）。
//        当指针进入/离开 View 的 bounds 时，闭包被调用，`isHovered` 状态切换，触发 `scaleEffect` 动画。
//        注意：`onHover` 在纯触摸设备（无指针）上永远不会触发，所以这种效果属于"渐进增强"，不影响核心体验。
struct HoverScaleEffect: ViewModifier {
    @State private var isHovered = false
    var scale: CGFloat = 1.02

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hover in
                isHovered = hover
            }
    }
}

extension View {
    func pressableCard(scale: CGFloat = 0.97, opacity: Double = 0.9) -> some View {
        modifier(PressableCardStyle(scale: scale, opacity: opacity))
    }

    func hoverScale(scale: CGFloat = 1.02) -> some View {
        modifier(HoverScaleEffect(scale: scale))
    }
}

// MARK: - Animated Number
// Animatable protocol：SwiftUI 动画的底层插值机制
// `Animatable` 协议只有一个要求：`animatableData`（`associatedtype AnimatableData: VectorArithmetic`）。
//        当 `withAnimation` 改变了一个 `Animatable` View 的属性时，SwiftUI 不是在动画开始瞬间跳转到目标值，
//        而是：1) 读取 `animatableData` 的当前值；2) 计算目标值与当前值的差值；3) 在动画时长内，每帧通过 easing 函数
//        计算中间值，写回 `animatableData`；4) 触发 `body` 重绘。所以 `AnimatedNumber` 的 `body` 每帧显示的是插值过程中的数字，
//        形成数字滚动的效果。`monospacedDigit()` 确保数字等宽，防止宽度变化导致布局抖动。
struct AnimatedNumber: View, @preconcurrency Animatable {
    var value: Double
    var formatter: (Double) -> String = { String(format: "%.0f", $0) }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(formatter(value))
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(AppTheme.ink)
            .monospacedDigit()
    }
}

// MARK: - Counting Animation Modifier
// 动画组合：将 Animatable View 封装为 ViewModifier，实现可复用的数字滚动
// `CountingAnimationModifier` 是 `AnimatedNumber` 的包装层，负责管理动画的生命周期（onAppear 时启动）。
//        它将"动画什么"（AnimatedNumber 的插值逻辑）和"何时动画"（modifier 的 onAppear 触发）分离，
//        符合单一职责原则。`withAnimation(.easeOut(duration:))` 创建隐式动画，SwiftUI 自动检测
//        `displayedValue` 的变化，通过 `AnimatedNumber.animatableData` 的 setter 注入插值。
//        `easeOut` 让数字快速滚动到接近目标值，然后缓慢逼近，符合"倒计时/计数"的认知习惯。
struct CountingAnimationModifier: ViewModifier {
    @State private var displayedValue: Double = 0
    let targetValue: Double
    let duration: Double

    func body(content: Content) -> some View {
        AnimatedNumber(value: displayedValue)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    displayedValue = targetValue
                }
            }
    }
}

extension View {
    func countingAnimation(from: Double = 0, to target: Double, duration: Double = 1.0) -> some View {
        modifier(CountingAnimationModifier(targetValue: target, duration: duration))
    }
}

// MARK: - Shake Effect (Error Feedback)
// GeometryEffect：直接操作底层 CGAffineTransform，绕过 SwiftUI 的布局系统
// `GeometryEffect` 是 SwiftUI 中最底层的动画协议，它允许直接修改 View 的仿射变换矩阵（`CGAffineTransform`）。
//        与 `Animatable` 不同：`Animatable` 修改的是 View 的"数据"（通过 `body` 重绘），`GeometryEffect` 修改的是 View 的"变换矩阵"（通过 Core Animation 层）。
//        所以 `GeometryEffect` 更高效（不触发 `body` 重计算），适合高频动画（如连续震动）。
//        `ShakeEffect` 的实现：每帧计算 `x = sin(animatableData * 2π * shakes) * amount`，
//        通过 `sin` 函数产生周期性左右震动。`animatableData` 从 0 到 1，控制 3 个完整周期的震动（`shakes = 3`）。
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    var multiplier: CGFloat {
        2 * .pi * shakes
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = sin(animatableData * multiplier) * amount
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

extension View {
    func shake(amount: CGFloat = 8, shakes: CGFloat = 3, trigger: Bool) -> some View {
        self.modifier(ShakeEffect(amount: amount, shakes: shakes, animatableData: trigger ? 1 : 0))
    }
}

// MARK: - Slide In Animation
// 方向性位移动画：从屏幕边缘滑入，建立空间认知
// 根据 `edge` 参数（.leading/.trailing/.top/.bottom）计算初始偏移量（±30 points），
//        配合 `opacity` 从 0 到 1 的渐变，形成"从屏幕外滑入并淡入"的效果。`delay` 参数支持延迟启动，
//        常用于页面首次加载时让元素按序出现。30 points 的偏移量是 UI 设计经验值：足够让用户感知运动方向，
//        又不会因距离太长而显得拖沓。`.easeOut` 让动画快速启动、缓慢结束，符合"进入视野"的物理直觉。
struct SlideInModifier: ViewModifier {
    let edge: Edge
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .offset(
                x: edge == .leading ? (isVisible ? 0 : -30) : (edge == .trailing ? (isVisible ? 0 : 30) : 0),
                y: edge == .top ? (isVisible ? 0 : -30) : (edge == .bottom ? (isVisible ? 0 : 30) : 0)
            )
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

extension View {
    func slideIn(from edge: Edge, delay: Double = 0) -> some View {
        modifier(SlideInModifier(edge: edge, delay: delay))
    }
}

// MARK: - Pulse Animation (Attention)
// 呼吸动画：scale + opacity 的组合，制造"脉动"视觉效果
// 同时改变 `scaleEffect`（1.0 → 1.08）和 `opacity`（1.0 → 0.8），形成放大-变淡-恢复-变浓的循环。
//        人眼对同时变化的大小和透明度非常敏感，这种组合比单一属性变化更醒目。`repeatForever(autoreverses: true)`
//        让动画来回播放，`easeInOut` 使过渡平滑。周期 1.2 秒是经验值：太快会显得焦虑，太慢会被忽略。
//        底层：SwiftUI 将 `scaleEffect` 和 `opacity` 的动画合并为一个 `CAAnimationGroup`，同步执行。
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.08 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulseAnimation() -> some View {
        modifier(PulseModifier())
    }
}

// MARK: - Bounce Animation
// 周期性位移动画：模拟物理弹性的视觉反馈
// `offset(y:)` 修改 View 的垂直位置，底层通过 `CGAffineTransform(translationX: 0, y: offset)` 实现。
//        `repeatForever(autoreverses: true)` 创建往返动画：0 → -6 → 0 → -6... 形成上下弹跳效果。
//        `.easeInOut` easing 函数让运动有加速和减速，模拟真实物理中"上升减速、下降加速"的规律。
//        这种微动画（micro-animation）用于吸引用户注意力，提示"这里有新内容"或"需要操作"。
struct BounceModifier: ViewModifier {
    @State private var isBouncing = false

    func body(content: Content) -> some View {
        content
            .offset(y: isBouncing ? -6 : 0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isBouncing)
            .onAppear {
                isBouncing = true
            }
    }
}

extension View {
    func bounceAnimation() -> some View {
        modifier(BounceModifier())
    }
}

// MARK: - Fade In Stagger (for Lists)
// Stagger（交错）动画：通过 delay 实现视觉层次感
// 列表中所有元素同时动画会显得单调且拥挤。Stagger 动画让每个元素按索引延迟启动，
//        形成"波浪式"入场效果。公式：`delay = index * 0.06`，第 0 个元素立即开始，第 1 个延迟 0.06 秒，以此类推。
//        底层实现：SwiftUI 的动画系统为每个 View 维护独立的动画状态机，`delay` 只是将动画启动时间向后平移，
//        不占用额外线程。当 `List` 或 `LazyVStack` 的 cell 进入屏幕时触发 `onAppear`，每个 cell 独立计算自己的延迟。
struct FadeInStaggerModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.06), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

extension View {
    func fadeInStagger(index: Int) -> some View {
        modifier(FadeInStaggerModifier(index: index))
    }
}

// MARK: - Matched Geometry Namespace
// matchedGeometryEffect 需要跨视图共享同一个 Namespace，必须用全局静态变量
// `matchedGeometryEffect` 是 SwiftUI 的共享元素转场动画 API。它的工作原理：两个 View 通过同一个 `id` 和 `namespace`
//        建立关联，当其中一个出现、另一个消失时，SwiftUI 会自动在两者之间做平滑的位置/大小插值动画。
//        `Namespace` 是引用类型（class），只有同一个实例才能匹配。如果每个 View 自己创建 `Namespace()`，
//        那它们永远不会匹配（不同实例）。所以必须用全局静态变量 `AppNamespace.namespace`，让所有需要转场动画的 View 共享。
//        这里用 `Namespace().wrappedValue` 是因为 `Namespace` 是 `@Namespace` 属性包装器的底层类型，获取其 `wrappedValue`
//        才能得到 `Namespace.ID`（实际是个 `String`，但框架隐藏了具体类型）。
enum AppNamespace {
    static let namespace = Namespace().wrappedValue
}

// MARK: - Rotation Effect for Loading
// rotationEffect + repeatForever：基于三角函数的连续旋转动画
// `rotationEffect(.degrees(角度))` 对 View 应用 2D 旋转变换，底层是 `CGAffineTransform(rotationAngle:)`。
//        `.linear(duration: 1).repeatForever(autoreverses: false)` 创建无限循环的线性动画，1 秒转 360 度，即 60 RPM。
//        `autoreverses: false` 确保旋转方向始终一致（顺时针），不会来回摆动。SwiftUI 动画引擎使用 `CADisplayLink`
//        以屏幕刷新率（通常 60/120Hz）驱动，每帧计算当前旋转角度，直接修改 layer 的 `transform` 属性，不触发 View 重建。
struct RotationModifier: ViewModifier {
    @State private var isRotating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
    }
}

extension View {
    func continuousRotation() -> some View {
        modifier(RotationModifier())
    }
}

// MARK: - Card Flip Animation
// rotation3DEffect：基于透视投影的 3D 旋转变换
// `rotation3DEffect` 是 SwiftUI 对 Core Animation `CATransform3D` 的封装。它创建了一个 3D 透视变换矩阵，
//        绕指定轴（axis）旋转指定角度。默认的 `axis: (0, 1, 0)` 表示绕 Y 轴旋转，形成卡片左右翻转效果。
//        底层通过 `CATransform3DMakeRotation(angle, x, y, z)` 实现，配合 `m34` 透视参数产生近大远小的 3D 视觉效果。
//        `.easeInOut(duration: 0.6)` 让翻转有加速和减速过程，更自然。
struct FlipModifier: ViewModifier {
    @State private var isFlipped = false
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: axis
            )
            .animation(.easeInOut(duration: 0.6), value: isFlipped)
            .onTapGesture {
                isFlipped.toggle()
            }
    }
}

extension View {
    func flipOnTap(axis: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 1, 0)) -> some View {
        modifier(FlipModifier(axis: axis))
    }
}
