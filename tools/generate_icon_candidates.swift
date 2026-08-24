import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root.appendingPathComponent("design/icon_candidates")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

struct RGB {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    var color: NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }
}

struct IconVariant {
    let number: Int
    let key: String
    let title: String
    let subtitle: String
    let draw: (CGContext, CGFloat) -> Void
}

func cg(_ rgb: RGB) -> CGColor {
    rgb.color.cgColor
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawGradient(_ context: CGContext, _ side: CGFloat, _ colors: [RGB], _ locations: [CGFloat]? = nil) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map { $0.color.cgColor } as CFArray,
        locations: locations
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: side),
        end: CGPoint(x: side, y: 0),
        options: []
    )
}

func drawRadialGlow(_ context: CGContext, _ side: CGFloat, center: CGPoint, color: RGB, radius: CGFloat) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            color.color.cgColor,
            RGB(color.r, color.g, color.b, 0).color.cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: []
    )
}

func drawText(
    _ text: String,
    in rect: CGRect,
    size: CGFloat,
    weight: NSFont.Weight = .bold,
    fill: RGB,
    align: NSTextAlignment = .center,
    kern: CGFloat = 0,
    stroke: RGB? = nil,
    strokeWidth: CGFloat = 0,
    fontName: String? = nil
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align

    let font: NSFont
    if let fontName, let customFont = NSFont(name: fontName, size: size) {
        font = customFont
    } else {
        font = NSFont.systemFont(ofSize: size, weight: weight)
    }

    var attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: fill.color,
        .paragraphStyle: paragraph,
        .kern: kern
    ]
    if let stroke {
        attributes[.strokeColor] = stroke.color
        attributes[.strokeWidth] = -strokeWidth
    }

    let attributed = NSAttributedString(string: text, attributes: attributes)
    let bounds = attributed.boundingRect(
        with: CGSize(width: rect.width, height: rect.height),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    let drawRect = CGRect(
        x: rect.minX,
        y: rect.midY - bounds.height / 2,
        width: rect.width,
        height: bounds.height + size * 0.10
    )
    attributed.draw(in: drawRect)
}

func drawPathStroke(_ context: CGContext, _ side: CGFloat, points: [(CGFloat, CGFloat)], color: RGB, width: CGFloat) {
    guard let first = points.first else { return }
    context.setStrokeColor(cg(color))
    context.setLineWidth(side * width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: side * first.0, y: side * first.1))
    for point in points.dropFirst() {
        context.addLine(to: CGPoint(x: side * point.0, y: side * point.1))
    }
    context.strokePath()
}

func drawNode(_ context: CGContext, _ side: CGFloat, x: CGFloat, y: CGFloat, radius: CGFloat, fill: RGB, rim: RGB = RGB(1, 1, 1)) {
    let rect = CGRect(
        x: side * x - side * radius,
        y: side * y - side * radius,
        width: side * radius * 2,
        height: side * radius * 2
    )
    context.setFillColor(cg(rim))
    context.fillEllipse(in: rect.insetBy(dx: -side * 0.008, dy: -side * 0.008))
    context.setFillColor(cg(fill))
    context.fillEllipse(in: rect)
}

func drawBook(_ context: CGContext, _ side: CGFloat, y: CGFloat = 0.18, scale: CGFloat = 1) {
    let w = side * 0.25 * scale
    let h = side * 0.14 * scale
    let center = side * 0.50
    let bottom = side * y
    let gap = side * 0.015 * scale

    let left = CGMutablePath()
    left.move(to: CGPoint(x: center - gap, y: bottom))
    left.addCurve(
        to: CGPoint(x: center - w, y: bottom + h * 0.12),
        control1: CGPoint(x: center - w * 0.35, y: bottom + h * 0.12),
        control2: CGPoint(x: center - w * 0.70, y: bottom + h * 0.18)
    )
    left.addLine(to: CGPoint(x: center - w, y: bottom + h))
    left.addCurve(
        to: CGPoint(x: center - gap, y: bottom + h * 0.70),
        control1: CGPoint(x: center - w * 0.60, y: bottom + h * 1.10),
        control2: CGPoint(x: center - w * 0.25, y: bottom + h * 1.00)
    )
    left.closeSubpath()

    let right = CGMutablePath()
    right.move(to: CGPoint(x: center + gap, y: bottom))
    right.addCurve(
        to: CGPoint(x: center + w, y: bottom + h * 0.12),
        control1: CGPoint(x: center + w * 0.35, y: bottom + h * 0.12),
        control2: CGPoint(x: center + w * 0.70, y: bottom + h * 0.18)
    )
    right.addLine(to: CGPoint(x: center + w, y: bottom + h))
    right.addCurve(
        to: CGPoint(x: center + gap, y: bottom + h * 0.70),
        control1: CGPoint(x: center + w * 0.60, y: bottom + h * 1.10),
        control2: CGPoint(x: center + w * 0.25, y: bottom + h * 1.00)
    )
    right.closeSubpath()

    context.setShadow(offset: CGSize(width: 0, height: side * 0.018), blur: side * 0.028, color: cg(RGB(0, 0, 0, 0.18)))
    context.setFillColor(cg(RGB(0.98, 1, 0.96)))
    context.addPath(left)
    context.fillPath()
    context.addPath(right)
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    context.setStrokeColor(cg(RGB(0.10, 0.30, 0.32, 0.24)))
    context.setLineWidth(side * 0.008 * scale)
    context.move(to: CGPoint(x: center, y: bottom + h * 0.10))
    context.addLine(to: CGPoint(x: center, y: bottom + h * 0.88))
    context.strokePath()
}

func drawNeuralNodes(_ context: CGContext, _ side: CGFloat, accent: RGB) {
    let nodes: [(CGFloat, CGFloat)] = [
        (0.20, 0.70), (0.38, 0.78), (0.61, 0.72), (0.78, 0.82),
        (0.25, 0.33), (0.48, 0.24), (0.72, 0.33)
    ]
    let edges = [(0, 1), (1, 2), (2, 3), (0, 4), (4, 5), (5, 6), (2, 6), (1, 5)]
    context.setStrokeColor(cg(RGB(1, 1, 1, 0.18)))
    context.setLineWidth(side * 0.010)
    for edge in edges {
        let a = nodes[edge.0]
        let b = nodes[edge.1]
        context.move(to: CGPoint(x: side * a.0, y: side * a.1))
        context.addLine(to: CGPoint(x: side * b.0, y: side * b.1))
    }
    context.strokePath()
    for node in nodes {
        drawNode(context, side, x: node.0, y: node.1, radius: 0.020, fill: accent, rim: RGB(1, 1, 1, 0.90))
    }
}

func renderIcon(size: Int, variant: IconVariant) -> NSBitmapImageRep {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: representation) else {
        fatalError("Could not create bitmap context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    variant.draw(graphicsContext.cgContext, CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return representation
}

func writePNG(_ representation: NSBitmapImageRep, to url: URL) throws {
    guard let data = representation.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    try data.write(to: url)
}

func makeFileName(_ variant: IconVariant) -> String {
    "candidate_\(String(format: "%02d", variant.number))_\(variant.key).png"
}

let variants: [IconVariant] = [
    IconVariant(number: 1, key: "hanzi_xue_seal", title: "01 学 字印", subtitle: "简体 学 + XYX") { context, side in
        drawGradient(context, side, [RGB(0.02, 0.11, 0.13), RGB(0.04, 0.43, 0.43), RGB(0.88, 0.42, 0.18)])
        drawRadialGlow(context, side, center: CGPoint(x: side * 0.74, y: side * 0.70), color: RGB(1.0, 0.72, 0.28, 0.42), radius: side * 0.50)
        let seal = CGRect(x: side * 0.18, y: side * 0.18, width: side * 0.64, height: side * 0.64)
        context.setShadow(offset: CGSize(width: 0, height: side * 0.040), blur: side * 0.060, color: cg(RGB(0, 0, 0, 0.28)))
        context.setFillColor(cg(RGB(0.98, 0.56, 0.22)))
        context.addPath(roundedRect(seal, side * 0.15))
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setStrokeColor(cg(RGB(1, 1, 1, 0.55)))
        context.setLineWidth(side * 0.018)
        context.addPath(roundedRect(seal.insetBy(dx: side * 0.030, dy: side * 0.030), side * 0.11))
        context.strokePath()
        drawText("学", in: CGRect(x: side * 0.14, y: side * 0.28, width: side * 0.72, height: side * 0.42), size: side * 0.38, weight: .black, fill: RGB(1, 1, 0.95), stroke: RGB(0.24, 0.08, 0.03, 0.30), strokeWidth: side * 0.010)
        drawText("XYX", in: CGRect(x: side * 0.25, y: side * 0.19, width: side * 0.50, height: side * 0.10), size: side * 0.070, weight: .black, fill: RGB(0.15, 0.10, 0.08, 0.72), kern: side * 0.006)
    },
    IconVariant(number: 2, key: "traditional_xue_orbit", title: "02 學 星轨", subtitle: "繁体 學 + 路径") { context, side in
        drawGradient(context, side, [RGB(0.06, 0.10, 0.24), RGB(0.10, 0.32, 0.48), RGB(0.02, 0.15, 0.18)])
        drawRadialGlow(context, side, center: CGPoint(x: side * 0.30, y: side * 0.78), color: RGB(0.36, 0.82, 0.82, 0.35), radius: side * 0.46)
        drawPathStroke(context, side, points: [(0.17, 0.34), (0.36, 0.62), (0.63, 0.46), (0.84, 0.72)], color: RGB(0.97, 0.63, 0.24), width: 0.040)
        for point in [(0.17, 0.34), (0.36, 0.62), (0.63, 0.46), (0.84, 0.72)] {
            drawNode(context, side, x: point.0, y: point.1, radius: 0.030, fill: RGB(0.97, 0.63, 0.24))
        }
        drawText("學", in: CGRect(x: side * 0.12, y: side * 0.26, width: side * 0.76, height: side * 0.52), size: side * 0.44, weight: .black, fill: RGB(0.96, 1.00, 0.98), stroke: RGB(0.02, 0.09, 0.13, 0.70), strokeWidth: side * 0.014)
        drawText("XYX", in: CGRect(x: side * 0.25, y: side * 0.18, width: side * 0.50, height: side * 0.10), size: side * 0.078, weight: .heavy, fill: RGB(0.73, 0.98, 0.95), kern: side * 0.010)
    },
    IconVariant(number: 3, key: "xyx_fusion", title: "03 X学X", subtitle: "字母融合") { context, side in
        drawGradient(context, side, [RGB(0.02, 0.12, 0.16), RGB(0.08, 0.40, 0.36), RGB(0.95, 0.61, 0.20)])
        let panel = CGRect(x: side * 0.10, y: side * 0.20, width: side * 0.80, height: side * 0.58)
        context.setFillColor(cg(RGB(0.01, 0.07, 0.10, 0.55)))
        context.addPath(roundedRect(panel, side * 0.12))
        context.fillPath()
        drawText("X", in: CGRect(x: side * 0.10, y: side * 0.31, width: side * 0.28, height: side * 0.34), size: side * 0.28, weight: .black, fill: RGB(0.84, 1.00, 0.95), stroke: RGB(0, 0, 0, 0.35), strokeWidth: side * 0.010)
        drawText("学", in: CGRect(x: side * 0.31, y: side * 0.24, width: side * 0.38, height: side * 0.46), size: side * 0.33, weight: .black, fill: RGB(1.00, 0.68, 0.24), stroke: RGB(0, 0, 0, 0.35), strokeWidth: side * 0.010)
        drawText("X", in: CGRect(x: side * 0.62, y: side * 0.31, width: side * 0.28, height: side * 0.34), size: side * 0.28, weight: .black, fill: RGB(0.84, 1.00, 0.95), stroke: RGB(0, 0, 0, 0.35), strokeWidth: side * 0.010)
        drawText("FinalPilot", in: CGRect(x: side * 0.24, y: side * 0.20, width: side * 0.52, height: side * 0.08), size: side * 0.052, weight: .semibold, fill: RGB(0.84, 1.0, 0.95, 0.86), kern: side * 0.002)
    },
    IconVariant(number: 4, key: "xyx_cloud_learning", title: "04 云学习", subtitle: "云计算 + XYX") { context, side in
        drawGradient(context, side, [RGB(0.02, 0.08, 0.16), RGB(0.05, 0.25, 0.44), RGB(0.36, 0.62, 0.70)])
        drawNeuralNodes(context, side, accent: RGB(0.96, 0.68, 0.22))
        let cloud = CGMutablePath()
        cloud.move(to: CGPoint(x: side * 0.24, y: side * 0.37))
        cloud.addCurve(to: CGPoint(x: side * 0.36, y: side * 0.52), control1: CGPoint(x: side * 0.22, y: side * 0.45), control2: CGPoint(x: side * 0.28, y: side * 0.52))
        cloud.addCurve(to: CGPoint(x: side * 0.54, y: side * 0.57), control1: CGPoint(x: side * 0.40, y: side * 0.69), control2: CGPoint(x: side * 0.53, y: side * 0.66))
        cloud.addCurve(to: CGPoint(x: side * 0.77, y: side * 0.38), control1: CGPoint(x: side * 0.69, y: side * 0.61), control2: CGPoint(x: side * 0.83, y: side * 0.52))
        cloud.addLine(to: CGPoint(x: side * 0.24, y: side * 0.37))
        cloud.closeSubpath()
        context.setFillColor(cg(RGB(0.94, 1.00, 0.97, 0.94)))
        context.addPath(cloud)
        context.fillPath()
        drawText("學", in: CGRect(x: side * 0.29, y: side * 0.40, width: side * 0.42, height: side * 0.32), size: side * 0.25, weight: .black, fill: RGB(0.03, 0.21, 0.30))
        drawText("XYX", in: CGRect(x: side * 0.23, y: side * 0.24, width: side * 0.54, height: side * 0.12), size: side * 0.080, weight: .heavy, fill: RGB(0.98, 0.65, 0.20), kern: side * 0.012)
    },
    IconVariant(number: 5, key: "minimal_xue", title: "05 极简学", subtitle: "设计复盘开源项目感") { context, side in
        drawGradient(context, side, [RGB(0.94, 0.96, 0.90), RGB(0.78, 0.92, 0.88), RGB(0.11, 0.36, 0.38)])
        let circle = CGRect(x: side * 0.15, y: side * 0.15, width: side * 0.70, height: side * 0.70)
        context.setFillColor(cg(RGB(0.03, 0.16, 0.18)))
        context.fillEllipse(in: circle)
        context.setStrokeColor(cg(RGB(0.97, 0.61, 0.22)))
        context.setLineWidth(side * 0.026)
        context.strokeEllipse(in: circle.insetBy(dx: side * 0.025, dy: side * 0.025))
        drawText("学", in: CGRect(x: side * 0.18, y: side * 0.31, width: side * 0.64, height: side * 0.39), size: side * 0.36, weight: .black, fill: RGB(0.98, 1, 0.96))
        drawText("XYX", in: CGRect(x: side * 0.28, y: side * 0.22, width: side * 0.44, height: side * 0.09), size: side * 0.060, weight: .black, fill: RGB(0.97, 0.61, 0.22), kern: side * 0.010)
    },
    IconVariant(number: 6, key: "book_xue_badge", title: "06 书页徽章", subtitle: "复习计划感") { context, side in
        drawGradient(context, side, [RGB(0.04, 0.13, 0.16), RGB(0.07, 0.42, 0.42), RGB(0.12, 0.22, 0.42)])
        drawRadialGlow(context, side, center: CGPoint(x: side * 0.75, y: side * 0.78), color: RGB(0.96, 0.62, 0.22, 0.35), radius: side * 0.42)
        context.setStrokeColor(cg(RGB(1, 1, 1, 0.12)))
        context.setLineWidth(side * 0.008)
        for y in stride(from: side * 0.20, through: side * 0.82, by: side * 0.14) {
            context.move(to: CGPoint(x: side * 0.16, y: y))
            context.addLine(to: CGPoint(x: side * 0.84, y: y + side * 0.05))
        }
        context.strokePath()
        drawBook(context, side, y: 0.18, scale: 1.18)
        drawText("学", in: CGRect(x: side * 0.19, y: side * 0.43, width: side * 0.62, height: side * 0.34), size: side * 0.31, weight: .black, fill: RGB(0.98, 1, 0.96), stroke: RGB(0, 0, 0, 0.45), strokeWidth: side * 0.010)
        drawText("XYX", in: CGRect(x: side * 0.25, y: side * 0.36, width: side * 0.50, height: side * 0.10), size: side * 0.070, weight: .black, fill: RGB(0.98, 0.65, 0.22), kern: side * 0.012)
    },
    IconVariant(number: 7, key: "traditional_neural", title: "07 神经學", subtitle: "神经网络课程感") { context, side in
        drawGradient(context, side, [RGB(0.06, 0.08, 0.18), RGB(0.18, 0.18, 0.42), RGB(0.03, 0.38, 0.36)])
        drawNeuralNodes(context, side, accent: RGB(0.78, 0.94, 0.92))
        drawText("學", in: CGRect(x: side * 0.10, y: side * 0.28, width: side * 0.80, height: side * 0.50), size: side * 0.41, weight: .black, fill: RGB(0.99, 0.98, 0.88), stroke: RGB(0.03, 0.07, 0.11, 0.65), strokeWidth: side * 0.014)
        drawPathStroke(context, side, points: [(0.27, 0.27), (0.42, 0.35), (0.58, 0.29), (0.75, 0.38)], color: RGB(0.96, 0.63, 0.22), width: 0.026)
        drawText("XYX", in: CGRect(x: side * 0.27, y: side * 0.18, width: side * 0.46, height: side * 0.10), size: side * 0.070, weight: .heavy, fill: RGB(0.96, 0.63, 0.22), kern: side * 0.010)
    },
    IconVariant(number: 8, key: "exam_sprint_y", title: "08 冲刺Y", subtitle: "Y = 调度分流") { context, side in
        drawGradient(context, side, [RGB(0.03, 0.12, 0.16), RGB(0.08, 0.32, 0.35), RGB(0.78, 0.24, 0.18)])
        drawPathStroke(context, side, points: [(0.18, 0.22), (0.38, 0.44), (0.50, 0.68), (0.65, 0.44), (0.84, 0.78)], color: RGB(0.98, 0.68, 0.25), width: 0.048)
        for point in [(0.18, 0.22), (0.50, 0.68), (0.84, 0.78)] {
            drawNode(context, side, x: point.0, y: point.1, radius: 0.032, fill: RGB(0.98, 0.68, 0.25))
        }
        drawText("X", in: CGRect(x: side * 0.12, y: side * 0.40, width: side * 0.26, height: side * 0.28), size: side * 0.22, weight: .black, fill: RGB(0.94, 1, 0.96))
        drawText("Y", in: CGRect(x: side * 0.35, y: side * 0.35, width: side * 0.30, height: side * 0.36), size: side * 0.28, weight: .black, fill: RGB(0.98, 0.68, 0.25))
        drawText("X", in: CGRect(x: side * 0.62, y: side * 0.40, width: side * 0.26, height: side * 0.28), size: side * 0.22, weight: .black, fill: RGB(0.94, 1, 0.96))
        drawText("學", in: CGRect(x: side * 0.34, y: side * 0.20, width: side * 0.32, height: side * 0.16), size: side * 0.13, weight: .black, fill: RGB(0.94, 1, 0.96, 0.90))
    }
]

for variant in variants {
    let icon = renderIcon(size: 1024, variant: variant)
    try writePNG(icon, to: outputDirectory.appendingPathComponent(makeFileName(variant)))
}

let thumbSize = 256
let labelHeight = 64
let padding = 34
let columns = 4
let rows = Int(ceil(Double(variants.count) / Double(columns)))
let sheetWidth = columns * thumbSize + (columns + 1) * padding
let sheetHeight = rows * (thumbSize + labelHeight) + (rows + 1) * padding

guard let sheet = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: sheetWidth,
    pixelsHigh: sheetHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
), let sheetContext = NSGraphicsContext(bitmapImageRep: sheet) else {
    fatalError("Could not create preview sheet")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = sheetContext
let context = sheetContext.cgContext
context.setFillColor(cg(RGB(0.92, 0.95, 0.94)))
context.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))

for (index, variant) in variants.enumerated() {
    let column = index % columns
    let row = rows - 1 - index / columns
    let x = padding + column * (thumbSize + padding)
    let y = padding + row * (thumbSize + labelHeight + padding)
    let icon = renderIcon(size: thumbSize, variant: variant)
    if let cgImage = icon.cgImage {
        context.setShadow(offset: CGSize(width: 0, height: 9), blur: 16, color: cg(RGB(0, 0, 0, 0.18)))
        context.draw(cgImage, in: CGRect(x: x, y: y + labelHeight, width: thumbSize, height: thumbSize))
        context.setShadow(offset: .zero, blur: 0, color: nil)
    }
    drawText(variant.title, in: CGRect(x: x, y: y + 28, width: thumbSize, height: 28), size: 22, weight: .bold, fill: RGB(0.04, 0.12, 0.14))
    drawText(variant.subtitle, in: CGRect(x: x, y: y, width: thumbSize, height: 26), size: 16, weight: .medium, fill: RGB(0.22, 0.34, 0.35))
}

NSGraphicsContext.restoreGraphicsState()
try writePNG(sheet, to: outputDirectory.appendingPathComponent("FinalPilot_XYX_icon_candidates.png"))

let indexMarkdown = """
# FinalPilot XYX 图标候选稿

生成日期：2026-05-01

这些候选稿只是设计预览，暂时不覆盖正式 `AppIcon.appiconset`。

| 编号 | 方向 | 文件 |
| --- | --- | --- |
\(variants.map { "| \($0.number) | \($0.title) - \($0.subtitle) | `\(makeFileName($0))` |" }.joined(separator: "\n"))

预览总图：`FinalPilot_XYX_icon_candidates.png`
"""

try indexMarkdown.write(
    to: outputDirectory.appendingPathComponent("README.md"),
    atomically: true,
    encoding: .utf8
)

print("Generated \(variants.count) icon candidates in \(outputDirectory.path)")
