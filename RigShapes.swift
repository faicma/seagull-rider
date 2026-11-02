import SwiftUI

// MARK: - 通用绘制组件

/// 把一个 Shape 用统一的填充/描边画出来
struct Piece<S: Shape>: View {
    var shape: S
    var fillColor: Color = .clear
    var strokeColor: Color = .clear
    var lineWidth: CGFloat = 1
    var eoFill: Bool = false

    var body: some View {
        ZStack {
            shape.fill(fillColor, style: FillStyle(eoFill: eoFill))
            shape.stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

/// 直接使用一条现成的 Path
struct PathShape: Shape {
    var content: Path
    func path(in rect: CGRect) -> Path { content }
}

/// 空心圆环（描边即得到轮圈/轮胎）
struct RingShape: Shape {
    var center: CGPoint
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }
}

/// 车轮辐条
struct SpokeShape: Shape {
    var center: CGPoint
    var radius: CGFloat
    var radians: Double
    var count: Int = 12

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inner: CGFloat = 7
        for i in 0 ..< count {
            let a = radians + Double(i) * (2 * Double.pi / Double(count))
            let c = CGFloat(cos(a))
            let s = CGFloat(sin(a))
            var seg = Path()
            seg.move(to: CGPoint(x: center.x + c * inner, y: center.y + s * inner))
            seg.addLine(to: CGPoint(x: center.x + c * radius, y: center.y + s * radius))
            p.addPath(seg)
        }
        return p
    }
}

/// 一根曲柄臂
struct CrankArmShape: Shape {
    var center: CGPoint
    var arm: CGFloat
    var radians: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: center)
        p.addLine(to: CGPoint(
            x: center.x + CGFloat(cos(radians)) * arm,
            y: center.y + CGFloat(sin(radians)) * arm
        ))
        return p
    }
}

/// 一块踏板
struct PedalShape: Shape {
    var at: CGPoint
    var radians: Double

    func path(in rect: CGRect) -> Path {
        barPath(center: at, width: 26, height: 10, radius: 4, degrees: radians * 180 / Double.pi)
    }
}

// MARK: - 海鸥部件

/// 翅膀：局部坐标原点 = 肩关节
struct WingShape: Shape {
    var pivot: CGPoint
    var degrees: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 10, y: -14))
        p.addCurve(
            to: CGPoint(x: -148, y: -38),
            control1: CGPoint(x: -52, y: -62),
            control2: CGPoint(x: -116, y: -66)
        )
        p.addCurve(
            to: CGPoint(x: -118, y: 14),
            control1: CGPoint(x: -166, y: -12),
            control2: CGPoint(x: -156, y: 6)
        )
        p.addCurve(
            to: CGPoint(x: 10, y: 12),
            control1: CGPoint(x: -76, y: 36),
            control2: CGPoint(x: -24, y: 30)
        )
        p.closeSubpath()
        return p.pivoting(rotateDegrees: degrees, to: pivot)
    }
}

/// 翅膀的黑色翼尖
struct WingTipShape: Shape {
    var pivot: CGPoint
    var degrees: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -80, y: -24))
        p.addCurve(
            to: CGPoint(x: -148, y: -38),
            control1: CGPoint(x: -112, y: -42),
            control2: CGPoint(x: -134, y: -44)
        )
        p.addCurve(
            to: CGPoint(x: -118, y: 12),
            control1: CGPoint(x: -160, y: -8),
            control2: CGPoint(x: -150, y: 4)
        )
        p.addCurve(
            to: CGPoint(x: -82, y: -6),
            control1: CGPoint(x: -108, y: 18),
            control2: CGPoint(x: -88, y: 8)
        )
        p.closeSubpath()
        return p.pivoting(rotateDegrees: degrees, to: pivot)
    }
}

/// 翅膀上的几道羽毛线
struct WingLineShape: Shape {
    var pivot: CGPoint
    var degrees: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -32, y: 0))
        p.addQuadCurve(to: CGPoint(x: -104, y: -20), control: CGPoint(x: -70, y: 4))
        p.move(to: CGPoint(x: -28, y: 12))
        p.addQuadCurve(to: CGPoint(x: -94, y: 2), control: CGPoint(x: -62, y: 20))
        return p.pivoting(rotateDegrees: degrees, to: pivot)
    }
}

/// 尾羽
struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 90, y: 144))
        p.addCurve(
            to: CGPoint(x: 24, y: 152),
            control1: CGPoint(x: 62, y: 138),
            control2: CGPoint(x: 38, y: 142)
        )
        p.addCurve(
            to: CGPoint(x: 36, y: 180),
            control1: CGPoint(x: 12, y: 160),
            control2: CGPoint(x: 20, y: 174)
        )
        p.addCurve(
            to: CGPoint(x: 92, y: 178),
            control1: CGPoint(x: 58, y: 188),
            control2: CGPoint(x: 78, y: 186)
        )
        p.closeSubpath()
        return p
    }
}

/// 喙
struct BeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 252, y: 58))
        p.addCurve(
            to: CGPoint(x: 312, y: 76),
            control1: CGPoint(x: 286, y: 60),
            control2: CGPoint(x: 302, y: 68)
        )
        p.addCurve(
            to: CGPoint(x: 254, y: 90),
            control1: CGPoint(x: 300, y: 86),
            control2: CGPoint(x: 276, y: 92)
        )
        p.closeSubpath()
        return p
    }
}

/// 腿：两段式 IK，膝盖自然前顶
struct LegShape: Shape {
    var hip: CGPoint
    var foot: CGPoint
    var lineWidth: CGFloat
    var bendForward: Bool = true

    func path(in rect: CGRect) -> Path {
        let l1: CGFloat = 52
        let l2: CGFloat = 56
        let dx = foot.x - hip.x
        let dy = foot.y - hip.y
        let raw = max(0.001, sqrt(dx * dx + dy * dy))
        let d = min(max(raw, abs(l1 - l2) + 6), l1 + l2 - 6)
        let ux = dx / raw
        let uy = dy / raw
        let a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
        let h = sqrt(max(0, l1 * l1 - a * a))
        var nx = uy
        var ny = -ux
        if !bendForward {
            nx = -nx
            ny = -ny
        }
        let knee = CGPoint(x: hip.x + ux * a + nx * h, y: hip.y + uy * a + ny * h)

        var p = Path()
        p.move(to: hip)
        p.addLine(to: knee)
        p.addLine(to: foot)
        return p.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

/// 飘动的围巾飘带
struct RibbonShape: Shape {
    var start: CGPoint
    var length: CGFloat
    var wave: Double
    var width: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        let steps = 16
        for i in 1 ... steps {
            let t = Double(i) / Double(steps)
            let x = start.x - length * CGFloat(t)
            let waveY = sin(t * 4.3 + wave) * (12.0 + 10.0 * t)
            let y = start.y + 24 * CGFloat(t) + CGFloat(waveY * t)
            p.addLine(to: CGPoint(x: x, y: y))
        }
        return p.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}

/// 车把
struct HandleBarShape: Shape {
    var headTop: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: headTop)
        p.addLine(to: CGPoint(x: 247, y: 157))
        p.addQuadCurve(to: CGPoint(x: 270, y: 147), control: CGPoint(x: 258, y: 145))
        return p.strokedPath(StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
    }
}
