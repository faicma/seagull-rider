import SwiftUI
import Combine
import UIKit

// MARK: - 粒子

struct Particle: Identifiable {
    enum Kind { case spark, feather, bubble, note }

    let id = UUID()
    var kind: Kind
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: Double
    var maxLife: Double
    var size: CGFloat
    var spin: Double

    var progress: Double { maxLife > 0 ? 1 - life / maxLife : 1 }
}

// MARK: - 骑行状态机

final class RideModel: ObservableObject {

    // 世界推进
    @Published private(set) var distance: Double = 0      // 累计行进距离（点）
    @Published private(set) var elapsed: Double = 0       // 累计运行时间（秒）
    @Published private(set) var speed: Double = 1         // 速度倍率，1 为巡航
    @Published private(set) var wingPhase: Double = 0     // 振翅相位
    @Published private(set) var bobPhase: Double = 0      // 车身起伏相位
    @Published private(set) var wingOpen: Double = 0      // 0..1 翅膀张开（冲刺时）
    @Published private(set) var burst: Double = 0         // 0..1 冲刺强度

    // 互动
    @Published private(set) var bellShake: Double = 0     // 0..1 铃铛抖动
    @Published private(set) var flip: Double = 0          // 空翻角度
    @Published private(set) var hop: Double = 0           // 向上腾空位移
    @Published private(set) var trickActive = false
    @Published private(set) var speech: String = ""
    @Published private(set) var speechLife: Double = 0
    @Published private(set) var particles: [Particle] = []
    @Published private(set) var bestTrick = false         // 是否完成过空翻

    // 声音开关
    @Published var soundOn: Bool = true {
        didSet {
            SoundKit.shared.isMuted = !soundOn
            SoundKit.shared.setAmbience(soundOn)
            SoundKit.shared.setMusic(musicOn && soundOn)
        }
    }

    // 背景音乐开关（总静音时跟着安静，但各自独立记住状态）
    @Published var musicOn: Bool = true {
        didSet {
            SoundKit.shared.setMusic(musicOn && soundOn)
        }
    }

    private var targetSpeed: Double = 1
    private var boostLeft: Double = 0
    private var trickT: Double = -1
    private var speechTotal: Double = 2.0
    private var tapTimes: [Date] = []
    private var flapAcc: Double = 0                       // 振翅音的相位累加
    private var timer: Timer?
    private var lastTick = Date()

    // MARK: 生命周期

    func start() {
        guard timer == nil else { return }
        SoundKit.shared.activate()
        SoundKit.shared.setAmbience(soundOn)
        SoundKit.shared.setMusic(musicOn && soundOn)
        lastTick = Date()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.step()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        SoundKit.shared.suspend()
    }

    /// 开关声音
    func toggleSound() {
        soundOn.toggle()
        if soundOn { SoundKit.shared.play(.bell, volume: 0.7) }
        haptic(0.3)
    }

    /// 开关背景音乐
    func toggleMusic() {
        musicOn.toggle()
        if musicOn && soundOn { SoundKit.shared.play(.bell, volume: 0.4) }
        haptic(0.3)
    }

    /// 进入后台：停掉环境音和背景音乐
    func pauseAudio() {
        SoundKit.shared.suspend()
    }

    /// 回到前台：恢复环境音和背景音乐（音量由各开关决定）
    func resumeAudio() {
        SoundKit.shared.activate()
        SoundKit.shared.resume()
    }

    // MARK: 每帧推进

    private func step() {
        let now = Date()
        var dt = now.timeIntervalSince(lastTick)
        lastTick = now
        if dt <= 0 { return }
        if dt > 0.12 { dt = 0.12 }
        update(dt)
    }

    private func update(_ dt: Double) {
        // 速度平滑趋近目标
        speed += (targetSpeed - speed) * min(1, dt * 4.5)
        if boostLeft > 0 {
            boostLeft -= dt
            if boostLeft <= 0 { targetSpeed = 1 }
        }
        burst = max(0, burst - dt * 1.25)

        // 世界推进
        elapsed += dt
        distance += dt * 190 * speed
        wingPhase += dt * (6.2 + 6.8 * max(0, speed - 1))
        bobPhase += dt * (8.0 + 4.0 * max(0, speed - 1))

        // 翅膀张开程度跟随速度
        let wantOpen = min(1, max(0, (speed - 1.05) / 0.95))
        wingOpen += (wantOpen - wingOpen) * min(1, dt * 5)

        // 铃铛抖动衰减
        bellShake = max(0, bellShake - dt * 3.4)

        // 空翻
        if trickT >= 0 {
            trickT += dt
            let p = min(1, trickT / 1.15)
            let e = p * p * (3 - 2 * p)
            flip = 360 * e
            hop = 4 * 170 * p * (1 - p)
            if p >= 1 {
                trickT = -1
                flip = 0
                hop = 0
                trickActive = false
                SoundKit.shared.play(.land, volume: 0.72, minInterval: 0.3)
            }
        } else {
            flip = 0
            hop = 9 * wingOpen
        }

        // 高速时的振翅声（很轻，只在冲刺/高速时出现）
        if speed > 1.5 {
            flapAcc += dt * (6.2 + 6.8 * max(0, speed - 1))
            if flapAcc >= 2 * Double.pi {
                flapAcc -= 2 * Double.pi
                SoundKit.shared.play(.wing, volume: 0.45, minInterval: 0.22)
            }
        } else {
            flapAcc = 0
        }

        // 气泡
        if speechLife > 0 {
            speechLife -= dt
            if speechLife <= 0 {
                speechLife = 0
                speech = ""
            }
        }

        stepParticles(dt)
    }

    private func stepParticles(_ dt: Double) {
        guard !particles.isEmpty else { return }
        var next: [Particle] = []
        next.reserveCapacity(particles.count)
        for var p in particles {
            p.life -= dt
            if p.life <= 0 { continue }
            switch p.kind {
            case .spark:
                p.vy += 190 * dt
            case .feather:
                p.vy += 42 * dt
                p.vx *= 0.995
                p.vx += 26 * dt
            case .bubble:
                p.vy -= 70 * dt
            case .note:
                p.vy -= 26 * dt
            }
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.spin += dt * 240
            next.append(p)
        }
        particles = next
    }

    // MARK: 互动：轻点冲刺

    func tapScene(anchor: CGPoint) {
        targetSpeed = 2.4
        boostLeft = 1.25
        burst = 1
        say(pick(["嘎——！", "冲呀！", "风好大！", "再快一点！", "顺着海风走～"]))
        spawnSparks(anchor, count: 12)
        spawnFeathers(anchor, count: 3)
        haptic(0.55)

        // 风声 + 海鸥叫
        SoundKit.shared.play(.whoosh, volume: 0.85, minInterval: 0.12)
        SoundKit.shared.play(.squawk, volume: 0.62, minInterval: 0.16)

        let now = Date()
        tapTimes.append(now)
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < 1.1 }
        if tapTimes.count >= 3 && !trickActive {
            tapTimes.removeAll()
            startTrick(anchor)
        }
    }

    // MARK: 互动：摇铃

    func ringBell(anchor: CGPoint) {
        bellShake = 1
        say(pick(["叮铃铃～", "让一让咯！", "叮叮！"]))
        spawnNotes(anchor, count: 5)
        targetSpeed = max(targetSpeed, 2.0)
        boostLeft = max(boostLeft, 0.85)
        burst = max(burst, 0.7)
        haptic(0.4)

        SoundKit.shared.play(.bell, volume: 0.95, minInterval: 0.16)
    }

    // MARK: 互动：空翻

    private func startTrick(_ anchor: CGPoint) {
        guard !trickActive else { return }
        trickActive = true
        bestTrick = true
        trickT = 0
        speak("看我的空翻！", 1.6)
        spawnSparks(anchor, count: 20)
        spawnFeathers(anchor, count: 5)
        haptic(1.0)

        SoundKit.shared.play(.flip, volume: 0.9, minInterval: 0.3)
        SoundKit.shared.play(.squawk, volume: 0.7, minInterval: 0.3)
    }

    // MARK: 台词

    private func pick(_ options: [String]) -> String {
        options[Int(abs(distance) * 7 + Double(options.count)) % options.count]
    }

    private func say(_ text: String) { speak(text, 1.5) }

    private func speak(_ text: String, _ duration: Double) {
        speech = text
        speechTotal = duration
        speechLife = duration
    }

    var speechProgress: Double { speechTotal > 0 ? 1 - speechLife / speechTotal : 1 }

    // MARK: 粒子工厂

    private func spawnSparks(_ a: CGPoint, count: Int) {
        for _ in 0..<count {
            let ang = Double.random(in: 0 ..< (2 * Double.pi))
            let sp = Double.random(in: 70 ... 240)
            append(Particle(
                kind: .spark,
                x: a.x + CGFloat.random(in: -26 ... 26),
                y: a.y + CGFloat.random(in: -24 ... 16),
                vx: CGFloat(cos(ang) * sp),
                vy: CGFloat(sin(ang) * sp) - 30,
                life: Double.random(in: 0.35 ... 0.8),
                maxLife: 0.8,
                size: CGFloat.random(in: 5 ... 11),
                spin: 0
            ))
        }
    }

    private func spawnFeathers(_ a: CGPoint, count: Int) {
        for _ in 0..<count {
            append(Particle(
                kind: .feather,
                x: a.x + CGFloat.random(in: -10 ... 40),
                y: a.y + CGFloat.random(in: -10 ... 30),
                vx: CGFloat.random(in: 40 ... 110),
                vy: CGFloat.random(in: -80 ... -20),
                life: Double.random(in: 0.9 ... 1.6),
                maxLife: 1.6,
                size: CGFloat.random(in: 10 ... 18),
                spin: Double.random(in: 0 ... 360)
            ))
        }
    }

    private func spawnNotes(_ a: CGPoint, count: Int) {
        for _ in 0..<count {
            append(Particle(
                kind: .note,
                x: a.x + CGFloat.random(in: -16 ... 16),
                y: a.y + CGFloat.random(in: -12 ... 10),
                vx: CGFloat.random(in: 26 ... 66),
                vy: CGFloat.random(in: -120 ... -60),
                life: Double.random(in: 0.8 ... 1.4),
                maxLife: 1.4,
                size: CGFloat.random(in: 14 ... 24),
                spin: Double.random(in: -20 ... 20)
            ))
        }
    }

    private func append(_ p: Particle) {
        particles.append(p)
        if particles.count > 96 {
            particles.removeFirst(particles.count - 96)
        }
    }

    // MARK: 触感

    func haptic(_ intensity: Double) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        if intensity > 0.8 { style = .heavy }
        else if intensity > 0.45 { style = .medium }
        else { style = .light }
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred(intensity: CGFloat(max(0.25, min(1, intensity))))
    }
}
