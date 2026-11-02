import SwiftUI

// MARK: - 云

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        func blob(_ x: CGFloat, _ y: CGFloat, _ bw: CGFloat, _ bh: CGFloat) {
            p.addEllipse(in: CGRect(
                x: rect.minX + w * x,
                y: rect.minY + h * y,
                width: w * bw,
                height: h * bh
            ))
        }
        blob(0.00, 0.40, 0.42, 0.58)
        blob(0.16, 0.04, 0.48, 0.82)
        blob(0.44, 0.22, 0.44, 0.70)
        blob(0.08, 0.60, 0.84, 0.38)
        return p
    }
}

// MARK: - 海浪

struct WaveShape: Shape {
    var y: CGFloat
    var amplitude: CGFloat
    var wavelength: CGFloat
    var shift: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let half = max(20, wavelength / 2)
        let phase = shift.truncatingRemainder(dividingBy: wavelength)
        var x = rect.minX - wavelength + phase
        var sign: CGFloat = 1
        p.move(to: CGPoint(x: x, y: y))
        while x < rect.maxX + wavelength {
            let next = x + half
            p.addQuadCurve(
                to: CGPoint(x: next, y: y),
                control: CGPoint(x: (x + next) / 2, y: y - amplitude * sign)
            )
            sign = -sign
            x = next
        }
        return p
    }
}

// MARK: - 太阳光芒

struct SunRaysShape: Shape {
    var center: CGPoint
    var inner: CGFloat
    var length: CGFloat
    var radians: Double
    var count: Int = 12

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 0 ..< count {
            let a = radians + Double(i) * (2 * Double.pi / Double(count))
            let c = CGFloat(cos(a))
            let s = CGFloat(sin(a))
            var seg = Path()
            seg.move(to: CGPoint(x: center.x + c * inner, y: center.y + s * inner))
            seg.addLine(to: CGPoint(x: center.x + c * (inner + length), y: center.y + s * (inner + length)))
            p.addPath(seg)
        }
        return p
    }
}

// MARK: - 远处的小海鸥

struct BirdShape: Shape {
    var flap: Double

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let w = rect.width / 2
        let h = rect.height * 0.5
        var p = Path()
        p.move(to: CGPoint(x: cx - w, y: cy + CGFloat(flap) * h * 0.75))
        p.addQuadCurve(
            to: CGPoint(x: cx, y: cy),
            control: CGPoint(x: cx - w * 0.55, y: cy - h * 0.95)
        )
        p.addQuadCurve(
            to: CGPoint(x: cx + w, y: cy + CGFloat(flap) * h * 0.75),
            control: CGPoint(x: cx + w * 0.55, y: cy - h * 0.95)
        )
        return p
    }
}

// MARK: - 小帆船

struct SailboatView: View {
    var body: some View {
        ZStack {
            // 船身
            Piece(
                shape: PathShape(content: hullPath()),
                fillColor: Color(hex: 0x33414F)
            )
            // 桅杆
            Piece(
                shape: PathShape(content: segmentPath(from: CGPoint(x: 30, y: 44), to: CGPoint(x: 30, y: 4), width: 2.5)),
                fillColor: Palette.ink
            )
            // 主帆
            Piece(
                shape: PathShape(content: mainSailPath()),
                fillColor: Color(hex: 0xFBFCFD)
            )
            // 前帆
            Piece(
                shape: PathShape(content: frontSailPath()),
                fillColor: Color(hex: 0xDFE8EF)
            )
        }
        .frame(width: 54, height: 60)
    }

    private func hullPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 3, y: 44))
        p.addLine(to: CGPoint(x: 51, y: 44))
        p.addLine(to: CGPoint(x: 43, y: 54))
        p.addLine(to: CGPoint(x: 11, y: 54))
        p.closeSubpath()
        return p
    }

    private func mainSailPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 32, y: 6))
        p.addLine(to: CGPoint(x: 32, y: 41))
        p.addQuadCurve(to: CGPoint(x: 8, y: 41), control: CGPoint(x: 18, y: 30))
        p.closeSubpath()
        return p
    }

    private func frontSailPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 34, y: 12))
        p.addLine(to: CGPoint(x: 50, y: 41))
        p.addQuadCurve(to: CGPoint(x: 34, y: 41), control: CGPoint(x: 42, y: 30))
        p.closeSubpath()
        return p
    }
}

// MARK: - 气泡的小尾巴

struct BubbleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX * 0.42, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
