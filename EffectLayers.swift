import SwiftUI

// MARK: - 冲刺速度线

struct SpeedLinesLayer: View {
    var w: CGFloat
    var top: CGFloat
    var bottom: CGFloat
    var distance: Double
    var burst: Double

    var body: some View {
        ZStack {
            if burst > 0.02 {
                ForEach(0 ..< 9, id: \.self) { i in
                    line(i)
                }
            }
        }
    }

    private func line(_ i: Int) -> some View {
        let t = hash01(Double(i) * 4.71)
        let t2 = hash01(Double(i) * 8.19)
        let period = Double(w + 240)
        let x = CGFloat(wrap(hash01(Double(i) * 1.9) * period - distance * 1.5, period)) - 120
        let y = top + (bottom - top) * CGFloat(0.12 + 0.84 * t2)
        let len = w * (0.10 + 0.18 * CGFloat(t))

        return Piece(
            shape: PathShape(content: segmentPath(
                from: CGPoint(x: x - len, y: y),
                to: CGPoint(x: x, y: y),
                width: 4
            )),
            fillColor: Color.white.opacity(burst * 0.5 * (0.35 + 0.65 * t))
        )
    }
}

// MARK: - 粒子

struct ParticleLayer: View {
    @ObservedObject var model: RideModel

    var body: some View {
        ZStack {
            ForEach(model.particles) { p in
                particleView(p)
            }
        }
    }

    @ViewBuilder
    private func particleView(_ p: Particle) -> some View {
        switch p.kind {
        case .spark:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: 0xFFE9A0))
                .frame(width: p.size * 0.5, height: p.size * 1.7)
                .rotationEffect(.degrees(p.spin))
                .opacity(1 - p.progress)
                .position(x: p.x, y: p.y)
        case .feather:
            Capsule()
                .fill(Color.white)
                .frame(width: p.size, height: p.size * 0.42)
                .rotationEffect(.degrees(p.spin))
                .opacity(1 - p.progress * 0.9)
                .position(x: p.x, y: p.y)
        case .bubble:
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: p.size, height: p.size)
                .opacity(1 - p.progress)
                .position(x: p.x, y: p.y)
        case .note:
            Text("♪")
                .font(.system(size: p.size, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: 0x2F6FA8))
                .opacity(1 - p.progress)
                .position(x: p.x, y: p.y)
        }
    }
}

// MARK: - 对白气泡

struct SpeechBubble: View {
    var text: String
    var progress: Double

    var body: some View {
        let pop = min(1.0, progress / 0.18)
        let scale = CGFloat(0.55 + 0.45 * pop)
        let fade = progress > 0.72 ? max(0.0, 1 - (progress - 0.72) / 0.28) : 1.0

        return VStack(alignment: .leading, spacing: -3) {
            Text(text)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(Palette.ink.opacity(0.10), lineWidth: 1.5))
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)

            BubbleTailShape()
                .fill(Color.white)
                .frame(width: 18, height: 14)
                .offset(x: 6)
        }
        .scaleEffect(scale, anchor: .bottomTrailing)
        .opacity(pop * fade)
    }
}

// MARK: - 顶部提示条

struct HintBar: View {
    var speedText: String

    var body: some View {
        VStack(spacing: 5) {
            Text("轻点屏幕加速冲刺 · 点铃铛摇铃 · 连点三次空翻")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: 0x1E4C6E))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("当前时速 " + speedText + " km/h")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: 0x2F6FA8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.white.opacity(0.74)))
        .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1))
        .shadow(color: Color(hex: 0x1E4C6E).opacity(0.12), radius: 8, y: 3)
    }
}

// MARK: - 可点击的车铃

struct BellButton: View {
    @ObservedObject var model: RideModel
    var center: CGPoint
    var elapsed: Double

    var body: some View {
        let p = 0.5 + 0.5 * sin(elapsed * 2.6)
        let ringSize = CGFloat(32 + 16 * p)

        return ZStack {
            Circle()
                .stroke(Palette.gold.opacity(0.18 + 0.38 * p), lineWidth: 2)
                .frame(width: ringSize, height: ringSize)
            Circle()
                .fill(Color.white.opacity(0.02))
                .frame(width: 64, height: 64)
        }
        .frame(width: 64, height: 64)
        .contentShape(Circle())
        .position(x: center.x, y: center.y)
        .onTapGesture { model.ringBell(anchor: center) }
    }
}

// MARK: - 声音开关

struct SoundToggle: View {
    var on: Bool
    var elapsed: Double
    var onTap: () -> Void

    var body: some View {
        let breathe = 0.5 + 0.5 * sin(elapsed * 2.2)
        let halo = on ? 1.0 : 0.35

        return ZStack {
            Circle()
                .stroke(Palette.gold.opacity(on ? 0.16 + 0.30 * breathe : 0), lineWidth: 2)
                .frame(width: 48 + CGFloat(4 * breathe), height: 48 + CGFloat(4 * breathe))

            Circle()
                .fill(Color.white.opacity(0.78))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1))
                .shadow(color: Color(hex: 0x1E4C6E).opacity(0.14), radius: 6, y: 2)

            Image(systemName: on ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(on ? Color(hex: 0x1E4C6E).opacity(halo) : Color(hex: 0x9AB0C2))
        }
        .frame(width: 56, height: 56)
        .contentShape(Circle())
        .onTapGesture { onTap() }
    }
}

// MARK: - 背景音乐开关

struct MusicToggle: View {
    var on: Bool
    var elapsed: Double
    var onTap: () -> Void

    var body: some View {
        let breathe = 0.5 + 0.5 * sin(elapsed * 2.2 + 1.4)
        let halo = on ? 1.0 : 0.35

        return ZStack {
            Circle()
                .stroke(Palette.gold.opacity(on ? 0.16 + 0.30 * breathe : 0), lineWidth: 2)
                .frame(width: 48 + CGFloat(4 * breathe), height: 48 + CGFloat(4 * breathe))

            Circle()
                .fill(Color.white.opacity(0.78))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1))
                .shadow(color: Color(hex: 0x1E4C6E).opacity(0.14), radius: 6, y: 2)

            Image(systemName: on ? "music.note.list" : "music.note")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(on ? Color(hex: 0x1E4C6E).opacity(halo) : Color(hex: 0x9AB0C2))
        }
        .frame(width: 56, height: 56)
        .contentShape(Circle())
        .onTapGesture { onTap() }
    }
}
