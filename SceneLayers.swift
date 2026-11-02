import SwiftUI

// MARK: - 天空

struct SkyLayer: View {
    var w: CGFloat
    var h: CGFloat
    var horizon: CGFloat
    var distance: Double
    var elapsed: Double
    var wingPhase: Double

    private var sunPoint: CGPoint { CGPoint(x: w * 0.80, y: h * 0.13) }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Palette.skyTop, Palette.skyMid, Palette.skyLow],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: w, height: horizon)
                .position(x: w / 2, y: horizon / 2)

            sun
            cloudLayer
            birdLayer
        }
    }

    private var sun: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [
                        Palette.sunGlow.opacity(0.95),
                        Palette.sunGlow.opacity(0.35),
                        Palette.sunGlow.opacity(0.0)
                    ]),
                    center: .center,
                    startRadius: 8,
                    endRadius: 115
                ))
                .frame(width: 250, height: 250)
                .position(x: sunPoint.x, y: sunPoint.y)

            Piece(
                shape: SunRaysShape(
                    center: sunPoint,
                    inner: 40,
                    length: 22,
                    radians: elapsed * 0.22
                ),
                strokeColor: Color.white.opacity(0.45),
                lineWidth: 3.5
            )

            Circle()
                .fill(Palette.sunCore)
                .frame(width: 62, height: 62)
                .position(x: sunPoint.x, y: sunPoint.y)
        }
    }

    private var cloudLayer: some View {
        ZStack {
            cloud(0)
            cloud(1)
            cloud(2)
            cloud(3)
            cloud(4)
        }
    }

    private func cloud(_ i: Int) -> some View {
        let specs: [(y: CGFloat, width: CGFloat, para: Double, opacity: Double, ratio: CGFloat)] = [
            (0.09, 0.26, 0.10, 0.95, 0.42),
            (0.21, 0.34, 0.18, 0.82, 0.38),
            (0.04, 0.19, 0.27, 0.62, 0.44),
            (0.29, 0.42, 0.34, 0.52, 0.36),
            (0.15, 0.30, 0.22, 0.74, 0.40)
        ]
        let s = specs[i % specs.count]
        let cw = w * s.width
        let ch = cw * s.ratio
        let period = Double(w + cw)
        let x0 = hash01(Double(i) * 3.71) * period
        let x = CGFloat(wrap(x0 - distance * s.para, period)) - cw / 2
        let y = h * s.y + CGFloat(sin(elapsed * 0.5 + Double(i) * 1.3) * 5)

        return CloudShape()
            .fill(LinearGradient(
                colors: [Color.white.opacity(s.opacity), Color(hex: 0xE4EFF9).opacity(s.opacity * 0.85)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: cw, height: ch)
            .position(x: x, y: y)
    }

    private var birdLayer: some View {
        ZStack {
            distantBird(0)
            distantBird(1)
            distantBird(2)
        }
    }

    private func distantBird(_ i: Int) -> some View {
        let size = w * (0.030 + 0.012 * CGFloat(hash01(Double(i) * 1.7)))
        let period = Double(w + size * 2)
        let x0 = hash01(Double(i) * 9.13) * period
        let x = CGFloat(wrap(x0 - distance * 0.16 - Double(i) * 90, period)) - size
        let y = h * (0.14 + 0.16 * CGFloat(hash01(Double(i) * 4.4)))
        let flap = sin(elapsed * 5.2 + Double(i) * 2.1)

        return Piece(
            shape: BirdShape(flap: flap),
            strokeColor: Color.white.opacity(0.85),
            lineWidth: 2.6
        )
        .frame(width: size, height: size * 0.5)
        .position(x: x, y: y)
    }
}

// MARK: - 海面

struct SeaLayer: View {
    var w: CGFloat
    var horizon: CGFloat
    var deckTop: CGFloat
    var distance: Double
    var elapsed: Double

    private var seaH: CGFloat { max(10, deckTop - horizon) }
    private var sunX: CGFloat { w * 0.80 }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Palette.seaTop, Palette.seaMid, Palette.seaLow],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: w, height: seaH)
                .position(x: w / 2, y: horizon + seaH / 2)

            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(width: w, height: 2.5)
                .position(x: w / 2, y: horizon)

            wave(y: horizon + seaH * 0.06, amp: seaH * 0.020, wl: w * 0.30, speed: 0.34, opacity: 0.30, lw: 2.5)
            wave(y: horizon + seaH * 0.20, amp: seaH * 0.030, wl: w * 0.42, speed: 0.50, opacity: 0.24, lw: 3)
            wave(y: horizon + seaH * 0.44, amp: seaH * 0.042, wl: w * 0.55, speed: 0.72, opacity: 0.19, lw: 3.5)
            wave(y: horizon + seaH * 0.74, amp: seaH * 0.052, wl: w * 0.70, speed: 1.00, opacity: 0.15, lw: 4)

            glitterLayer
            sailboat
        }
    }

    private func wave(y: CGFloat, amp: CGFloat, wl: CGFloat, speed: Double, opacity: Double, lw: CGFloat) -> some View {
        Piece(
            shape: WaveShape(y: y, amplitude: amp, wavelength: wl, shift: CGFloat(-distance * speed)),
            strokeColor: Color.white.opacity(opacity),
            lineWidth: lw
        )
    }

    private var glitterLayer: some View {
        ZStack {
            glitter(0)
            glitter(1)
            glitter(2)
            glitter(3)
            glitter(4)
            glitter(5)
            glitter(6)
            glitter(7)
            glitter(8)
            glitter(9)
            glitter(10)
            glitter(11)
            glitter(12)
            glitter(13)
        }
    }

    private func glitter(_ i: Int) -> some View {
        let t1 = hash01(Double(i) * 2.31)
        let t2 = hash01(Double(i) * 7.77)
        let y = horizon + seaH * (0.10 + 0.80 * CGFloat(t2))
        let cx = sunX + CGFloat(t1 - 0.5) * w * 0.46 * (0.45 + CGFloat(t2))
        let len = w * (0.03 + 0.10 * CGFloat(hash01(Double(i) * 5.13)))
        let twinkle = 0.20 + 0.38 * (0.5 + 0.5 * sin(elapsed * 2.2 + Double(i) * 1.7))

        return Piece(
            shape: PathShape(content: segmentPath(
                from: CGPoint(x: cx - len / 2, y: y),
                to: CGPoint(x: cx + len / 2, y: y),
                width: 3
            )),
            fillColor: Color.white.opacity(twinkle)
        )
    }

    private var sailboat: some View {
        let period = Double(w + 260)
        let x = CGFloat(wrap(hash01(3.3) * period - distance * 0.045, period)) - 130
        return SailboatView()
            .position(x: x, y: horizon + seaH * 0.17 + 30)
    }
}

// MARK: - 木栈道

struct DeckLayer: View {
    var w: CGFloat
    var h: CGFloat
    var deckTop: CGFloat
    var distance: Double

    private var plank: CGFloat { max(38, w * 0.11) }
    private var deckH: CGFloat { max(4, h - deckTop) }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Palette.woodTop, Palette.woodLow],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: w, height: deckH)
                .position(x: w / 2, y: deckTop + deckH / 2)

            Rectangle()
                .fill(Palette.woodLight)
                .frame(width: w, height: 4)
                .position(x: w / 2, y: deckTop + 2)

            Rectangle()
                .fill(Palette.woodDark.opacity(0.22))
                .frame(width: w, height: 3)
                .position(x: w / 2, y: deckTop + 12)

            grooveLayer
            knotLayer
        }
    }

    private var grooveLayer: some View {
        ZStack {
            groove(0)
            groove(1)
            groove(2)
            groove(3)
            groove(4)
            groove(5)
            groove(6)
            groove(7)
            groove(8)
            groove(9)
            groove(10)
            groove(11)
        }
    }

    private func groove(_ i: Int) -> some View {
        let spacing = plank
        let shift = CGFloat(distance.truncatingRemainder(dividingBy: Double(spacing)))
        let x = CGFloat(i) * spacing - shift
        return ZStack {
            Rectangle()
                .fill(Palette.woodDark.opacity(0.55))
                .frame(width: 3, height: deckH)
                .position(x: x, y: deckTop + deckH / 2)
            Rectangle()
                .fill(Palette.woodLight.opacity(0.45))
                .frame(width: 1.6, height: deckH)
                .position(x: x + 3, y: deckTop + deckH / 2)
        }
    }

    private var knotLayer: some View {
        ZStack {
            knot(0)
            knot(1)
            knot(2)
            knot(3)
            knot(4)
            knot(5)
        }
    }

    private func knot(_ i: Int) -> some View {
        let spacing = plank * 2.6
        let shift = CGFloat(distance.truncatingRemainder(dividingBy: Double(spacing)))
        let x = CGFloat(i) * spacing - shift + spacing * 0.4
        let y = deckTop + deckH * (0.28 + 0.52 * CGFloat(hash01(Double(i) * 6.1)))
        let rx = 5 + 5 * CGFloat(hash01(Double(i) * 8.3))
        return Piece(
            shape: PathShape(content: ellipsePath(center: CGPoint(x: x, y: y), rx: rx, ry: rx * 0.55, degrees: -8)),
            fillColor: Palette.woodDark.opacity(0.28)
        )
    }
}
