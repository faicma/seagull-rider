import SwiftUI

// MARK: - 画布坐标（设计尺寸 340 x 300，车轮触地点在 y = 300）

enum Rig {
    static let width: CGFloat = 340
    static let height: CGFloat = 300

    static let rearHub = CGPoint(x: 75, y: 250)
    static let frontHub = CGPoint(x: 262, y: 250)
    static let wheelR: CGFloat = 50

    static let bb = CGPoint(x: 155, y: 250)        // 五通（曲柄中心）
    static let arm: CGFloat = 22                   // 曲柄长度
    static let seatTop = CGPoint(x: 140, y: 182)
    static let headTop = CGPoint(x: 238, y: 170)
    static let saddle = CGPoint(x: 140, y: 175)
    static let bell = CGPoint(x: 258, y: 150)
    static let grip = CGPoint(x: 268, y: 148)

    static let hip = CGPoint(x: 152, y: 180)
    static let shoulderFar = CGPoint(x: 150, y: 110)
    static let shoulderNear = CGPoint(x: 165, y: 124)
    static let bodyCenter = CGPoint(x: 138, y: 140)
    static let headCenter = CGPoint(x: 238, y: 72)
    static let headR: CGFloat = 27

    /// 设计坐标 -> 相对画布中心的偏移（用于在场景中定位部件）
    static func unit(_ p: CGPoint) -> UnitPoint {
        UnitPoint(x: Double(p.x / width), y: Double(p.y / height))
    }
}

struct SeagullRider: View {
    @ObservedObject var model: RideModel

    // MARK: 运动学

    private var wheelRadians: Double { model.distance / Double(Rig.wheelR) }
    private var crankRadians: Double { wheelRadians * 0.38 }

    // 注意：SwiftUI 里正角度是顺时针，翅膀指向左上，所以正角度 = 抬起
    private var flapAmp: Double { 16 + 16 * model.wingOpen }
    private var flapBase: Double { 6 + 20 * model.wingOpen }
    private var farWingDeg: Double { flapBase + sin(model.wingPhase + 0.7) * flapAmp * 0.88 }
    private var nearWingDeg: Double { flapBase + sin(model.wingPhase) * flapAmp }

    private var bobY: CGFloat { CGFloat(sin(model.bobPhase)) * CGFloat(2.4 + 1.6 * max(0, model.speed - 1)) }

    private var bellDeg: Double { sin(model.bellShake * 30) * model.bellShake * 15 }

    private func pedalPoint(_ k: Int) -> CGPoint {
        let a = crankRadians + Double(k) * Double.pi
        return CGPoint(
            x: Rig.bb.x + CGFloat(cos(a)) * Rig.arm,
            y: Rig.bb.y + CGFloat(sin(a)) * Rig.arm
        )
    }

    private var nearFoot: CGPoint { pedalPoint(0) }
    private var farFoot: CGPoint { pedalPoint(1) }

    // MARK: 视图

    var body: some View {
        ZStack {
            wheel(Rig.rearHub)
            wheel(Rig.frontHub)

            chainAndCogs

            // 远侧曲柄与腿（在车架之后）
            crank(1)
            Piece(shape: LegShape(hip: Rig.hip, foot: farFoot, lineWidth: 7), fillColor: Palette.beakDark.opacity(0.85))

            bikeFrame

            gull

            // 近侧腿与曲柄（最靠前）
            Piece(shape: LegShape(hip: Rig.hip, foot: nearFoot, lineWidth: 8), fillColor: Palette.beak)
            footDot(nearFoot)
            crank(0)
        }
    }

    // MARK: 车轮

    private func wheel(_ hub: CGPoint) -> some View {
        ZStack {
            Piece(shape: RingShape(center: hub, radius: 45.5), strokeColor: Palette.bike, lineWidth: 9)
            Piece(
                shape: SpokeShape(center: hub, radius: 38, radians: wheelRadians),
                strokeColor: Palette.metal,
                lineWidth: 1.6
            )
            Piece(shape: RingShape(center: hub, radius: 39), strokeColor: Palette.rim, lineWidth: 3.5)
            Piece(shape: RingShape(center: hub, radius: 4.5), strokeColor: Palette.bike, lineWidth: 9)
        }
    }

    private var chainAndCogs: some View {
        ZStack {
            Piece(shape: RingShape(center: Rig.bb, radius: 16), strokeColor: Palette.metal, lineWidth: 3)
            Piece(shape: RingShape(center: Rig.rearHub, radius: 9), strokeColor: Palette.metal, lineWidth: 3)
        }
    }

    // MARK: 曲柄与踏板

    private func crank(_ k: Int) -> some View {
        ZStack {
            Piece(
                shape: CrankArmShape(center: Rig.bb, arm: Rig.arm, radians: crankRadians + Double(k) * Double.pi),
                strokeColor: Palette.bike,
                lineWidth: 8
            )
            Piece(
                shape: PedalShape(at: pedalPoint(k), radians: crankRadians + Double(k) * Double.pi),
                fillColor: Palette.bike
            )
        }
    }

    private func footDot(_ p: CGPoint) -> some View {
        Piece(
            shape: PathShape(content: ellipsePath(center: p, rx: 6.5, ry: 5)),
            fillColor: Palette.beak
        )
    }

    // MARK: 车架

    private var bikeFrame: some View {
        ZStack {
            // 后三角
            bar(from: Rig.bb, to: Rig.rearHub, width: 8, color: Palette.bike)
            bar(from: Rig.bb, to: Rig.seatTop, width: 8, color: Palette.bike)
            bar(from: Rig.seatTop, to: Rig.rearHub, width: 8, color: Palette.bike)
            // 上管 / 下管 / 前叉
            bar(from: Rig.seatTop, to: Rig.headTop, width: 8, color: Palette.bike)
            bar(from: Rig.bb, to: Rig.headTop, width: 8, color: Palette.bike)
            bar(from: Rig.headTop, to: Rig.frontHub, width: 7, color: Palette.bike)

            // 车把
            Piece(shape: HandleBarShape(headTop: Rig.headTop), fillColor: Palette.bike)
            Piece(shape: PathShape(content: segmentPath(from: Rig.grip, to: CGPoint(x: 274, y: 145), width: 11)), fillColor: Palette.ink)

            // 车座
            Piece(
                shape: PathShape(content: barPath(center: Rig.saddle, width: 48, height: 12, radius: 6, degrees: -6)),
                fillColor: Color(hex: 0x6E4630)
            )

            bellAssembly
        }
    }

    private func bar(from a: CGPoint, to b: CGPoint, width: CGFloat, color: Color) -> some View {
        Piece(shape: PathShape(content: segmentPath(from: a, to: b, width: width)), fillColor: color)
    }

    private var bellAssembly: some View {
        ZStack {
            Piece(shape: RingShape(center: Rig.bell, radius: 3), strokeColor: Palette.gold, lineWidth: 6)
            Piece(
                shape: PathShape(content: ellipsePath(center: CGPoint(x: Rig.bell.x, y: Rig.bell.y - 2), rx: 9, ry: 8.5)),
                fillColor: Palette.gold
            )
            Piece(
                shape: PathShape(content: ellipsePath(center: CGPoint(x: Rig.bell.x - 3, y: Rig.bell.y - 5), rx: 2.6, ry: 2)),
                fillColor: Color.white.opacity(0.75)
            )
            Piece(
                shape: PathShape(content: segmentPath(
                    from: CGPoint(x: Rig.bell.x + 9, y: Rig.bell.y + 1),
                    to: CGPoint(x: Rig.bell.x + 16, y: Rig.bell.y + 4),
                    width: 3.5
                )),
                fillColor: Palette.beakDark
            )
        }
        .rotationEffect(.degrees(bellDeg), anchor: Rig.unit(Rig.bell))
    }

    // MARK: 海鸥

    private var gull: some View {
        ZStack {
            // 尾羽
            Piece(shape: TailShape(), fillColor: Palette.white)

            // 远侧翅膀
            wing(far: true)

            // 身体
            PathShape(content: ellipsePath(center: Rig.bodyCenter, rx: 72, ry: 40, degrees: -14))
                .fill(LinearGradient(
                    colors: [Palette.white, Palette.shade],
                    startPoint: UnitPoint(x: 0.58, y: 0.30),
                    endPoint: UnitPoint(x: 0.34, y: 0.70)
                ))

            // 脖子
            Piece(
                shape: PathShape(content: ellipsePath(center: CGPoint(x: 211, y: 106), rx: 33, ry: 18, degrees: -57)),
                fillColor: Palette.white
            )

            // 头
            Piece(shape: RingShape(center: Rig.headCenter, radius: Rig.headR / 2), strokeColor: Palette.white, lineWidth: Rig.headR)

            // 头顶淡灰
            Piece(
                shape: PathShape(content: ellipsePath(center: CGPoint(x: 232, y: 62), rx: 20, ry: 10, degrees: -18)),
                fillColor: Palette.shade.opacity(0.9)
            )

            // 喙
            Piece(shape: BeakShape(), fillColor: Palette.beak)
            Piece(
                shape: PathShape(content: segmentPath(
                    from: CGPoint(x: 264, y: 76),
                    to: CGPoint(x: 306, y: 79),
                    width: 2
                )),
                fillColor: Palette.beakDark.opacity(0.75)
            )

            // 眼睛
            Piece(shape: RingShape(center: CGPoint(x: 248, y: 63), radius: 3), strokeColor: Palette.ink, lineWidth: 6)
            Piece(shape: RingShape(center: CGPoint(x: 246.3, y: 61.3), radius: 1.2), strokeColor: .white, lineWidth: 2.4)

            // 围巾
            scarf

            // 近侧翅膀
            wing(far: false)
        }
        .offset(y: bobY)
    }

    private func wing(far: Bool) -> some View {
        let pivot = far ? Rig.shoulderFar : Rig.shoulderNear
        let deg = far ? farWingDeg : nearWingDeg
        let base = far ? Palette.feather.opacity(0.95) : Palette.feather
        return ZStack {
            Piece(shape: WingShape(pivot: pivot, degrees: deg), fillColor: base)
            Piece(shape: WingTipShape(pivot: pivot, degrees: deg), fillColor: Palette.featherTip)
            Piece(shape: WingLineShape(pivot: pivot, degrees: deg), strokeColor: .white.opacity(0.55), lineWidth: 2)
        }
    }

    private var scarf: some View {
        ZStack {
            Piece(
                shape: PathShape(content: segmentPath(
                    from: CGPoint(x: 200, y: 80),
                    to: CGPoint(x: 238, y: 104),
                    width: 13
                )),
                fillColor: Palette.scarf
            )
            Piece(shape: RibbonShape(start: CGPoint(x: 208, y: 92), length: 108, wave: model.wingPhase * 1.6, width: 12), fillColor: Palette.scarf)
            Piece(shape: RibbonShape(start: CGPoint(x: 206, y: 100), length: 92, wave: model.wingPhase * 1.6 + 1.1, width: 9), fillColor: Palette.scarfDark)
        }
    }
}
