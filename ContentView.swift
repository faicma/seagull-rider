import SwiftUI

struct ContentView: View {
    @StateObject private var model = RideModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            scene(geo.size)
        }
        .ignoresSafeArea()
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.resumeAudio()
            } else {
                model.pauseAudio()
            }
        }
    }

    private var speedText: String {
        String((model.speed * 12.8 * 10).rounded() / 10)
    }

    private func scene(_ size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let horizon = h * 0.555
        let deckTop = h * 0.80

        let rigScale = min(h / 660, w / 400)
        let rigW = Rig.width * rigScale
        let rigH = Rig.height * rigScale
        let contactY = deckTop + 16
        let riderX = w * 0.44
        let riderCenterY = contactY - (Rig.height / 2) * rigScale

        let bellScreen = CGPoint(
            x: riderX + (Rig.bell.x - Rig.width / 2) * rigScale,
            y: riderCenterY + (Rig.bell.y - Rig.height / 2) * rigScale
        )
        let headScreen = CGPoint(
            x: riderX + (Rig.headCenter.x - Rig.width / 2) * rigScale,
            y: riderCenterY + (Rig.headCenter.y - Rig.height / 2) * rigScale
        )
        let burstAnchor = CGPoint(x: riderX + 20 * rigScale, y: riderCenterY - 40 * rigScale)
        let shadowScale = CGFloat(max(0.55, 1 - model.hop / 420))

        return ZStack {
            SkyLayer(
                w: w,
                h: h,
                horizon: horizon,
                distance: model.distance,
                elapsed: model.elapsed,
                wingPhase: model.wingPhase
            )

            SeaLayer(
                w: w,
                horizon: horizon,
                deckTop: deckTop,
                distance: model.distance,
                elapsed: model.elapsed
            )

            DeckLayer(
                w: w,
                h: h,
                deckTop: deckTop,
                distance: model.distance
            )

            // 地面投影
            Ellipse()
                .fill(Color.black.opacity(0.20))
                .frame(width: 235 * rigScale, height: 22 * rigScale)
                .scaleEffect(shadowScale)
                .blur(radius: 5)
                .position(x: riderX, y: contactY + 4)

            // 海鸥与单车
            SeagullRider(model: model)
                .frame(width: Rig.width, height: Rig.height)
                .scaleEffect(rigScale)
                .rotationEffect(.degrees(model.flip))
                .offset(y: CGFloat(-model.hop))
                .frame(width: rigW, height: rigH)
                .position(x: riderX, y: riderCenterY)

            SpeedLinesLayer(
                w: w,
                top: h * 0.26,
                bottom: deckTop + 40,
                distance: model.distance,
                burst: model.burst
            )

            ParticleLayer(model: model)

            if model.speechLife > 0 {
                SpeechBubble(text: model.speech, progress: model.speechProgress)
                    .position(
                        x: headScreen.x - 92 * rigScale,
                        y: headScreen.y - 58 * rigScale
                    )
            }

            HintBar(speedText: speedText)
                .position(x: w / 2, y: 72)

            SoundToggle(
                on: model.soundOn,
                elapsed: model.elapsed,
                onTap: { model.toggleSound() }
            )
            .position(x: max(46, w - 46), y: 72)

            MusicToggle(
                on: model.musicOn,
                elapsed: model.elapsed,
                onTap: { model.toggleMusic() }
            )
            .position(x: max(46, w - 112), y: 72)

            BellButton(model: model, center: bellScreen, elapsed: model.elapsed)
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        .onTapGesture { model.tapScene(anchor: burstAnchor) }
    }
}
