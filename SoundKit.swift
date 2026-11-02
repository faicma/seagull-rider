import Foundation
import AVFoundation

/// 音效引擎：所有声音都用数学波形实时合成，不需要任何音频素材文件。
///
/// 结构：AVAudioEngine → fxMixer → 柔化低通 → mainMixer（音效）
///                    → ambienceNode（海浪环境音）
///                    → musicNode（背景音乐）
/// 每个音效在启动时渲染成一段 PCM 缓冲，播放时从节点池里取一个空闲节点播。
final class SoundKit {

    static let shared = SoundKit()

    enum Cue {
        case whoosh    // 冲刺风声
        case bell      // 车铃
        case squawk    // 海鸥叫
        case flip      // 空翻起势
        case land      // 落地
        case wing      // 振翅
    }

    /// 静音开关（由外部 UI 控制，静音时音效、环境音、背景音乐一起安静）
    var isMuted: Bool = false {
        didSet { applyVolumes() }
    }

    // MARK: - 内部状态

    private let engine = AVAudioEngine()
    private let fxMixer = AVAudioMixerNode()
    private let softener = AVAudioUnitEQ(numberOfBands: 1)   // 音效柔化低通
    private let ambienceNode = AVAudioPlayerNode()
    private let musicNode = AVAudioPlayerNode()

    private var monoFormat: AVAudioFormat?
    private var sampleRate: Double = 44100

    private var pool: [AVAudioPlayerNode] = []
    private let poolSize = 8
    private var poolIndex = 0

    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var squawkVariants: [AVAudioPCMBuffer] = []
    private var surfBuffer: AVAudioPCMBuffer?
    private var musicBuffer: AVAudioPCMBuffer?

    private var lastPlay: [Cue: Date] = [:]
    private var ambienceOn = false
    private var musicOn = true
    private var suspended = false
    private var assembled = false
    private var engineReady = false
    private var failed = false
    private var observing = false

    private init() {}

    // MARK: - 启动

    /// 在界面出现时调用：配置音频会话并预热引擎。
    func activate() {
        configureSession()
        _ = ensureEngine()
        applyVolumes()
        if ambienceOn { startAmbience() }
        if musicOn { startMusic() }
        observeNotifications()
    }

    /// 关闭环境音与音乐并释放音频会话。
    func shutdown() {
        ambienceNode.stop()
        musicNode.stop()
        engine.stop()
        engineReady = false
    }

    /// 进入后台：把所有长音停掉（引擎保留，回来时立刻能响）。
    func suspend() {
        suspended = true
        ambienceNode.stop()
        musicNode.stop()
    }

    /// 回到前台：按各开关的状态把长音重新拉起来。
    func resume() {
        suspended = false
        _ = ensureEngine()
        applyVolumes()
        if ambienceOn { startAmbience() }
        if musicOn { startMusic() }
    }

    // MARK: - 播放

    func play(_ cue: Cue, volume: Float = 1.0, minInterval: Double = 0.06) {
        guard !isMuted else { return }
        guard ensureEngine() else { return }

        let now = Date()
        if let last = lastPlay[cue], now.timeIntervalSince(last) < minInterval { return }
        lastPlay[cue] = now

        guard let buf = buffer(for: cue) else { return }
        let node = nextNode()
        node.stop()
        node.volume = max(0, min(2, volume)) * baseVolume(cue)
        node.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        node.play()
    }

    // MARK: - 环境音（海浪 + 风）

    func setAmbience(_ on: Bool) {
        ambienceOn = on
        if on {
            _ = ensureEngine()
            startAmbience()
        } else {
            ambienceNode.stop()
        }
        applyVolumes()
    }

    private func startAmbience() {
        guard engineReady, !isMuted, ambienceOn, !suspended, let buf = surfBuffer else { return }
        guard !ambienceNode.isPlaying else { return }
        ambienceNode.stop()
        ambienceNode.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
        ambienceNode.play()
    }

    // MARK: - 背景音乐

    /// 背景音乐开关（由外部 UI 控制）。
    func setMusic(_ on: Bool) {
        musicOn = on
        if on {
            _ = ensureEngine()
            startMusic()
        } else {
            musicNode.stop()
        }
        applyVolumes()
    }

    private func startMusic() {
        guard engineReady, !isMuted, musicOn, !suspended, let buf = musicBuffer else { return }
        guard !musicNode.isPlaying else { return }
        musicNode.stop()
        musicNode.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
        musicNode.play()
    }

    private func applyVolumes() {
        ambienceNode.volume = (isMuted || !ambienceOn) ? 0 : 0.30
        musicNode.volume = (isMuted || !musicOn) ? 0 : 0.22
        fxMixer.outputVolume = isMuted ? 0 : 0.9
    }

    // MARK: - 引擎装配

    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback 让 iPad 的静音拨杆不会吞掉音效；.mixWithOthers 不打断别的 App
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // 会话配置失败时保持静默降级，不阻断界面
        }
        #endif
    }

    @discardableResult
    private func ensureEngine() -> Bool {
        if engineReady { return true }
        if failed { return false }

        if !assembled {
            // 采样率要等会话激活后再取，否则可能是 0
            let sr = engine.outputNode.outputFormat(forBus: 0).sampleRate
            sampleRate = sr > 0 ? sr : 44100

            guard let fmt = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            ) else {
                failed = true
                return false
            }
            monoFormat = fmt

            buildBuffers()

            // 音效链路上加一个温和的低通，把最刺耳的高频压掉
            let lp = softener.bands[0]
            lp.filterType = .lowPass
            lp.frequency = 6200
            lp.bandwidth = 0.8
            lp.bypass = false

            engine.attach(fxMixer)
            engine.attach(softener)
            engine.connect(fxMixer, to: softener, format: nil)
            engine.connect(softener, to: engine.mainMixerNode, format: nil)

            for _ in 0 ..< poolSize {
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: fxMixer, format: fmt)
                node.volume = 1
                pool.append(node)
            }

            engine.attach(ambienceNode)
            engine.connect(ambienceNode, to: engine.mainMixerNode, format: fmt)
            ambienceNode.volume = 0

            engine.attach(musicNode)
            engine.connect(musicNode, to: engine.mainMixerNode, format: fmt)
            musicNode.volume = 0

            engine.prepare()
            assembled = true
        }

        guard assembled else { return false }
        if engine.isRunning {
            engineReady = true
            return true
        }

        do {
            try engine.start()
            engineReady = true
            applyVolumes()
            startAmbience()
            startMusic()
            return true
        } catch {
            // 这次没起来不要判死刑，下次互动时再试
            return false
        }
    }

    private func nextNode() -> AVAudioPlayerNode {
        for _ in 0 ..< pool.count {
            let node = pool[poolIndex % pool.count]
            poolIndex = (poolIndex + 1) % pool.count
            if !node.isPlaying { return node }
        }
        let node = pool[poolIndex % pool.count]
        poolIndex = (poolIndex + 1) % pool.count
        return node
    }

    private func buffer(for cue: Cue) -> AVAudioPCMBuffer? {
        if cue == .squawk && !squawkVariants.isEmpty {
            return squawkVariants[Int.random(in: 0 ..< squawkVariants.count)]
        }
        return buffers[cue]
    }

    /// 各音效的基础音量：整体调低一档，让声音更陪衬、不抢戏
    private func baseVolume(_ cue: Cue) -> Float {
        switch cue {
        case .whoosh: return 0.55
        case .bell:   return 0.60
        case .squawk: return 0.45
        case .flip:   return 0.58
        case .land:   return 0.50
        case .wing:   return 0.22
        }
    }

    private func observeNotifications() {
        guard !observing else { return }
        observing = true

        _ = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.engineReady && !self.engine.isRunning {
                do { try self.engine.start() } catch { self.engineReady = false }
            }
            if self.engine.isRunning {
                self.startAmbience()
                self.startMusic()
            }
        }

        #if os(iOS)
        _ = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .ended {
                self.configureSession()
                if self.engineReady && !self.engine.isRunning {
                    do { try self.engine.start() } catch { self.engineReady = false }
                }
                self.startAmbience()
                self.startMusic()
            }
        }
        #endif
    }

    // MARK: - 缓冲渲染

    private func buildBuffers() {
        guard monoFormat != nil else { return }
        let syn = Synth(sr: sampleRate)

        buffers[.whoosh] = makeBuffer(syn.whoosh())
        buffers[.bell] = makeBuffer(syn.bell())
        buffers[.flip] = makeBuffer(syn.flip())
        buffers[.land] = makeBuffer(syn.land())
        buffers[.wing] = makeBuffer(syn.wing())

        squawkVariants = [0.93, 1.0, 1.08, 1.15].compactMap { makeBuffer(syn.squawk(scale: $0)) }
        surfBuffer = makeBuffer(syn.surf())
        musicBuffer = makeBuffer(syn.music())
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let fmt = monoFormat, !samples.isEmpty else { return nil }
        let frames = AVAudioFrameCount(samples.count)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        guard let channel = buf.floatChannelData else { return nil }
        let dst = channel[0]
        for i in 0 ..< samples.count {
            dst[i] = samples[i]
        }
        return buf
    }
}

// MARK: - 波形合成

/// 只负责把声音算成一组 Float 样本，不碰任何播放逻辑。
private struct Synth {

    let sr: Double

    // MARK: 基础工具

    /// 线性同余伪随机（可复现的噪声源）
    private struct Noise {
        private var state: UInt64
        init(seed: UInt64) {
            state = seed &* 6364136223846793005 &+ 1442695040888963407
        }
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let v = (state >> 40) & 0xFFFFFF
            return Double(v) / Double(0x7FFFFF) - 1.0
        }
    }

    /// 一阶低通（截止频率随时间可变）
    private struct LowPass {
        private var y: Double = 0
        private var a: Double = 0.1
        mutating func process(_ x: Double, cutoff: Double, sr: Double) -> Double {
            let c = max(20, min(cutoff, sr * 0.45))
            a = 1 - exp(-2 * Double.pi * c / sr)
            y += a * (x - y)
            return y
        }
    }

    /// 峰值归一化
    private func normalized(_ x: [Float], peak: Float = 0.92) -> [Float] {
        var m: Float = 0
        for v in x { m = max(m, abs(v)) }
        guard m > 0.0001 else { return x }
        let g = peak / m
        var out = x
        for i in 0 ..< out.count { out[i] *= g }
        return out
    }

    /// 关键点平滑插值（用于音高曲线）
    private func interp(_ keys: [(Double, Double)], _ t: Double) -> Double {
        if keys.isEmpty { return 0 }
        if t <= keys[0].0 { return keys[0].1 }
        for j in 1 ..< keys.count {
            if t <= keys[j].0 {
                let a = keys[j - 1]
                let b = keys[j]
                let u = (t - a.0) / max(0.0001, b.0 - a.0)
                let s = u * u * (3 - 2 * u)
                return a.1 + (b.1 - a.1) * s
            }
        }
        return keys[keys.count - 1].1
    }

    // MARK: 车铃 —— 两声「叮铃」，音色调温：基频更低、高泛音更少、敲击声更闷

    func bell() -> [Float] {
        let dur = 1.05
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)

        let f0 = 880.0
        // (频率比, 振幅, 衰减速度) —— 高次泛音的振幅整体压低
        let partials: [(Double, Double, Double)] = [
            (1.00, 1.00, 2.6),
            (2.03, 0.30, 4.0),
            (2.79, 0.26, 5.2),
            (4.18, 0.10, 7.4),
            (5.46, 0.05, 9.8)
        ]

        for (k, strike) in [0.0, 0.116].enumerated() {
            for p in partials {
                let f = f0 * p.0
                if f > sr * 0.45 { continue }
                var phase = 0.0
                let start = Int(strike * sr)
                var i = start
                while i < n {
                    let t = Double(i - start) / sr
                    out[i] += Float(exp(-t * p.2) * p.1 * sin(phase))
                    phase += 2 * Double.pi * f / sr
                    i += 1
                }
            }
            // 敲击瞬间的高频颗粒：更轻、更闷
            var noise = Noise(seed: UInt64(1000 + k * 37))
            var lp = LowPass()
            let start = Int(strike * sr)
            let end = min(n, start + Int(0.009 * sr))
            var i = start
            while i < end {
                let t = Double(i - start) / sr
                let raw = noise.next()
                let bright = lp.process(raw, cutoff: 2200, sr: sr)
                out[i] += Float(bright * exp(-t * 430) * 0.22)
                i += 1
            }
        }
        return normalized(out, peak: 0.80)
    }

    // MARK: 冲刺风声 —— 噪声扫频（收窄频带，去掉嘶吼感）

    func whoosh() -> [Float] {
        let dur = 0.62
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var noise = Noise(seed: 77)
        var lp = LowPass()
        var phase = 0.0

        for i in 0 ..< n {
            let t = Double(i) / sr
            let u = t / dur
            let env = min(1.0, u / 0.15) * pow(max(0, 1 - u), 1.7)

            let raw = noise.next()
            let sweep = sin(Double.pi * min(1, u * 1.18))
            let cutoff = 220 + 1900 * pow(max(0, sweep), 1.4)
            let body = lp.process(raw, cutoff: cutoff, sr: sr)

            let f = 170 + 520 * u
            phase += 2 * Double.pi * f / sr

            out[i] = Float((body + sin(phase) * 0.14) * env)
        }
        return normalized(out, peak: 0.80)
    }

    // MARK: 海鸥叫 —— 带颤音的锯齿波 + 沙哑噪声（整体降调、削泛音，不再尖利）

    func squawk(scale: Double) -> [Float] {
        let dur = 0.46
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var noise = Noise(seed: 4242)
        var lp1 = LowPass()
        var lp2 = LowPass()
        var phase = 0.0

        // 「嘎——哟」的音高走向（比原来低约三成）
        let keys: [(Double, Double)] = [
            (0.00, 1220),
            (0.08, 1050),
            (0.20, 1320),
            (0.36, 800),
            (0.46, 590)
        ]

        for i in 0 ..< n {
            let t = Double(i) / sr
            let base = interp(keys, t) * scale
            let vibrato = 1 + 0.028 * sin(2 * Double.pi * 20 * t)
            phase += 2 * Double.pi * base * vibrato / sr

            var tone = 0.0
            var k = 1.0
            while k <= 6 {
                tone += sin(phase * k) / k
                k += 1
            }
            tone *= 0.48

            let raw = noise.next()
            let band = lp1.process(raw, cutoff: 1600, sr: sr) - lp2.process(raw, cutoff: 550, sr: sr)

            let env = min(1.0, t / 0.030) * pow(max(0, 1 - t / dur), 0.85)
            out[i] = Float((tone * 0.85 + band * 0.30) * env)
        }
        return normalized(out, peak: 0.76)
    }

    // MARK: 空翻 —— 上行琶音 + 气流（琶音更柔，气流更闷）

    func flip() -> [Float] {
        let dur = 0.78
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)

        let notes: [(Double, Double)] = [
            (0.000, 523.3),
            (0.075, 622.3),
            (0.150, 784.0),
            (0.235, 1046.5),
            (0.330, 1318.5)
        ]

        for note in notes {
            var phase = 0.0
            let start = Int(note.0 * sr)
            var i = start
            while i < n {
                let t = Double(i - start) / sr
                let env = exp(-t * 4.6)
                out[i] += Float((sin(phase) + 0.20 * sin(2 * phase)) * env * 0.6)
                phase += 2 * Double.pi * note.1 / sr
                i += 1
            }
        }

        var noise = Noise(seed: 909)
        var lp = LowPass()
        var liftPhase = 0.0
        for i in 0 ..< n {
            let t = Double(i) / sr
            let u = t / dur
            let env = pow(max(0, sin(Double.pi * u)), 1.2) * 0.4
            let raw = noise.next()
            let body = lp.process(raw, cutoff: 420 + 2100 * u, sr: sr)
            liftPhase += 2 * Double.pi * (260 + 700 * u) / sr
            out[i] += Float((body * 0.6 + sin(liftPhase) * 0.18) * env)
        }
        return normalized(out, peak: 0.80)
    }

    // MARK: 落地 —— 低频下坠 + 闷响（本身不刺耳，仅收一点颗粒）

    func land() -> [Float] {
        let dur = 0.42
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var noise = Noise(seed: 31)
        var lp = LowPass()
        var phase = 0.0

        for i in 0 ..< n {
            let t = Double(i) / sr
            let f = 150 * exp(-t * 9) + 52
            phase += 2 * Double.pi * f / sr
            let raw = noise.next()
            let thud = lp.process(raw, cutoff: 340, sr: sr)
            out[i] = Float(sin(phase) * exp(-t * 9.5) * 0.95 + thud * exp(-t * 20) * 0.55)
        }
        return normalized(out, peak: 0.85)
    }

    // MARK: 振翅 —— 一声很轻的气流

    func wing() -> [Float] {
        let dur = 0.19
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var noise = Noise(seed: 555)
        var lp1 = LowPass()
        var lp2 = LowPass()

        for i in 0 ..< n {
            let t = Double(i) / sr
            let u = t / dur
            let env = pow(max(0, sin(Double.pi * u)), 1.5)
            let raw = noise.next()
            let band = lp1.process(raw, cutoff: 1350, sr: sr) - lp2.process(raw, cutoff: 420, sr: sr)
            out[i] = Float(band * env)
        }
        return normalized(out, peak: 0.60)
    }

    // MARK: 海浪环境音 —— 4 秒无缝循环

    func surf() -> [Float] {
        let dur = 4.0
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var noise = Noise(seed: 2024)
        var lp1 = LowPass()
        var lp2 = LowPass()
        var hp = LowPass()

        // 两个 LFO 的周期都能整除 4 秒，保证循环点连续
        for i in 0 ..< n {
            let t = Double(i) / sr
            let swell = 0.42 + 0.58 * (0.5 + 0.5 * sin(2 * Double.pi * 0.25 * t - 1.2))
            let wind = 0.42 + 0.58 * (0.5 + 0.5 * sin(2 * Double.pi * 0.25 * t + 2.1))

            let raw = noise.next()
            let stage1 = lp1.process(raw, cutoff: 900, sr: sr)
            let body = lp2.process(stage1, cutoff: 420, sr: sr)
            let hiss = raw - hp.process(raw, cutoff: 1300, sr: sr)

            out[i] = Float(body * swell + hiss * wind * 0.10)
        }

        // 首尾交叉淡化，抹掉循环接缝
        let fade = Int(0.4 * sr)
        if n > fade * 2 {
            for i in 0 ..< fade {
                let u = Double(i) / Double(fade)
                let tail = Double(out[n - fade + i])
                let head = Double(out[i])
                out[n - fade + i] = Float(tail * (1 - u) + head * u)
            }
        }
        return normalized(out, peak: 0.55)
    }

    // MARK: 背景音乐 —— 8 秒无缝循环的轻柔小曲
    //
    // 进行：C → Am → F → G（每和弦 2 秒），低音 + 微失谐垫音 + 柔和拨弦点缀。
    // 结尾与开头做 0.8 秒交叉淡化，循环点听不出接缝。

    func music() -> [Float] {
        let dur = 8.0
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)

        // (低音根音, 垫音和声, 拨弦[(起始, 音高)])
        let chords: [(bass: Double, pad: [Double], pluck: [(Double, Double)])] = [
            (bass:  65.41, pad: [130.81, 164.81, 196.00, 261.63],
             pluck: [(0.05, 261.63), (0.55, 329.63), (1.05, 392.00), (1.55, 329.63)]),
            (bass:  55.00, pad: [110.00, 130.81, 164.81, 220.00],
             pluck: [(2.05, 220.00), (2.55, 261.63), (3.05, 329.63), (3.55, 261.63)]),
            (bass:  87.31, pad: [ 87.31, 130.81, 174.61, 220.00],
             pluck: [(4.05, 174.61), (4.55, 220.00), (5.05, 261.63), (5.55, 220.00)]),
            (bass:  98.00, pad: [ 98.00, 123.47, 146.83, 196.00],
             pluck: [(6.05, 196.00), (6.55, 246.94), (7.05, 293.66), (7.55, 246.94)])
        ]
        let chordDur = 2.0

        for (ci, chord) in chords.enumerated() {
            let base = Double(ci) * chordDur
            let start = Int(base * sr)
            let end = min(n, Int((base + chordDur) * sr))

            // 低音：整段持续，两端缓入缓出
            var bassPhase = 0.0
            var i = start
            while i < end {
                let t = Double(i - start) / sr
                let env = min(1, t / 0.25) * min(1, (chordDur - t) / 0.25)
                bassPhase += 2 * Double.pi * chord.bass / sr
                out[i] += Float(sin(bassPhase) * 0.16 * env)
                i += 1
            }

            // 垫音：每个和声用两个微失谐的正弦叠出温暖的合唱感
            for f in chord.pad {
                var p1 = 0.0
                var p2 = 0.0
                let detune = f * 0.0013
                var i = start
                while i < end {
                    let t = Double(i - start) / sr
                    let env = min(1, t / 0.6) * min(1, (chordDur - t) / 0.7)
                    p1 += 2 * Double.pi * f / sr
                    p2 += 2 * Double.pi * (f + detune) / sr
                    out[i] += Float((sin(p1) + sin(p2)) * 0.045 * env)
                    i += 1
                }
            }

            // 拨弦：柔和高音点缀，允许一点尾巴延到下一和弦，听感更连贯
            for (offset, f) in chord.pluck {
                var phase = 0.0
                let pStart = Int((base + offset) * sr)
                var i = pStart
                while i < n {
                    let t = Double(i - pStart) / sr
                    if t > 1.6 { break }
                    let env = min(1, t / 0.012) * exp(-t * 3.2)
                    phase += 2 * Double.pi * f / sr
                    out[i] += Float((sin(phase) + 0.24 * sin(2 * phase) + 0.10 * sin(3 * phase)) * 0.10 * env)
                    i += 1
                }
            }
        }

        // 首尾交叉淡化，保证无缝循环
        let fade = Int(0.8 * sr)
        if n > fade * 2 {
            for i in 0 ..< fade {
                let u = Double(i) / Double(fade)
                let s = u * u * (3 - 2 * u)
                let tail = Double(out[n - fade + i])
                let head = Double(out[i])
                out[n - fade + i] = Float(tail * (1 - s) + head * s)
            }
        }
        return normalized(out, peak: 0.50)
    }
}
