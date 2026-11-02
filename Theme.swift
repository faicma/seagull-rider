import SwiftUI

// MARK: - 配色

enum Palette {
    // 天空
    static let skyTop = Color(hex: 0x2E86C8)
    static let skyMid = Color(hex: 0x79C3EC)
    static let skyLow = Color(hex: 0xD3EBF9)
    // 太阳
    static let sunCore = Color(hex: 0xFFF8DC)
    static let sunGlow = Color(hex: 0xFFE9A0)
    // 海
    static let seaTop = Color(hex: 0x1E6DA6)
    static let seaMid = Color(hex: 0x3E9ACB)
    static let seaLow = Color(hex: 0x78C6E6)
    // 木栈道
    static let woodTop = Color(hex: 0xD9AB72)
    static let woodLow = Color(hex: 0xA87848)
    static let woodDark = Color(hex: 0x7B5730)
    static let woodLight = Color(hex: 0xEFD3A8)
    // 海鸥
    static let white = Color(hex: 0xFDFEFF)
    static let shade = Color(hex: 0xE2EAF1)
    static let feather = Color(hex: 0xC3D0DC)
    static let featherTip = Color(hex: 0x39434F)
    static let beak = Color(hex: 0xF5A623)
    static let beakDark = Color(hex: 0xD9860F)
    static let ink = Color(hex: 0x2A3038)
    // 其他
    static let scarf = Color(hex: 0xE4572E)
    static let scarfDark = Color(hex: 0xBE3F1C)
    static let bike = Color(hex: 0x2F3742)
    static let rim = Color(hex: 0xD8DFE6)
    static let gold = Color(hex: 0xF2C14E)
    static let metal = Color(hex: 0xB9C6D2)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - 小工具

/// 确定性伪随机（0..1），避免每帧抖动
func hash01(_ n: Double) -> Double {
    let x = sin(n * 12.9898 + 4.1414) * 43758.5453
    return x - x.rounded(.down)
}

/// 把 v 收进 0..<period
func wrap(_ v: Double, _ period: Double) -> Double {
    let r = v.truncatingRemainder(dividingBy: period)
    return r < 0 ? r + period : r
}

/// 角度（度）转弧度
func rad(_ degrees: Double) -> CGFloat { CGFloat(degrees * Double.pi / 180.0) }

extension Path {
    /// 先绕路径原点旋转，再平移 —— 用于「以某个关节为轴」的部件
    func pivoting(rotateDegrees: Double, to origin: CGPoint) -> Path {
        applying(CGAffineTransform(rotationAngle: rad(rotateDegrees)))
            .applying(CGAffineTransform(translationX: origin.x, y: origin.y))
    }
}

/// 一个可旋转的椭圆（以 center 为圆心）
func ellipsePath(center: CGPoint, rx: CGFloat, ry: CGFloat, degrees: Double = 0) -> Path {
    Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        .pivoting(rotateDegrees: degrees, to: center)
}

/// 一个可旋转的圆角矩形（以 center 为圆心）
func barPath(center: CGPoint, width: CGFloat, height: CGFloat, radius: CGFloat, degrees: Double = 0) -> Path {
    Path(roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), cornerRadius: radius)
        .pivoting(rotateDegrees: degrees, to: center)
}

/// 一条圆头线段
func segmentPath(from a: CGPoint, to b: CGPoint, width: CGFloat) -> Path {
    var p = Path()
    p.move(to: a)
    p.addLine(to: b)
    return p.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
}
