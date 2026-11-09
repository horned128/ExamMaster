import SwiftUI
import Combine

private struct TankeiMotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private struct TankeiBaseColorKey: EnvironmentKey {
    static let defaultValue = Palette.accent(TankeiPalette.defaultChickenHex)
}

private struct TankeiChickColorKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    var mascotChickColor: Color? {
        get { self[TankeiChickColorKey.self] }
        set { self[TankeiChickColorKey.self] = newValue }
    }
    var mascotBaseColor: Color {
        get { self[TankeiBaseColorKey.self] }
        set { self[TankeiBaseColorKey.self] = newValue }
    }

    var mascotMotionEnabled: Bool {
        get { self[TankeiMotionEnabledKey.self] }
        set { self[TankeiMotionEnabledKey.self] = newValue }
    }
}

private struct TankeiVisibilityKey: PreferenceKey {
    static var defaultValue = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value && nextValue() }
}

/// Draws the supplied originals as independent native vector parts.
/// Stage changes crossfade; no unrelated SVG paths are forced into a broken morph.
struct TankeiView: View {
    var state: TankeiState = .ready
    var stage: TankeiStage = .chick
    var size: CGFloat = 88
    var animated = false
    var idle = false
    var expressive = false
    var eventID = 0
    /// Repeats the dance instead of random idle gestures (results, evolution, big combos).
    var dancing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.mascotMotionEnabled) private var motionEnabled
    @State private var playID = 0
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var present = false
    @State private var inViewport = true
    @State private var motionStart = Date()
    @State private var idleAction: TankeiIdleAction = .nod
    @State private var actionStart = Date.distantPast
    @State private var interactionStart = Date.distantPast

    private var canAnimate: Bool {
        TankeiMotionPolicy.allowsMotion(requested: animated || idle, reduceMotion: reduceMotion,
                                       lowPower: lowPower, active: scenePhase == .active,
                                       visible: present && inViewport, enabled: motionEnabled)
    }

    var body: some View {
        Group {
            if canAnimate {
                animatedDrawing.onAppear { if animated { interactionStart = .now; playID += 1 } }
            } else {
                TankeiDrawing(state: state, stage: stage, size: size, frame: TankeiFrame())
            }
        }
        .frame(width: size, height: size)
        .id(stage)
        .transition(.opacity)
        .animation(canAnimate ? .easeInOut(duration: 0.4) : nil, value: stage)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .background {
            GeometryReader { geometry in
                let viewport = geometry.bounds(of: .scrollView)
                let visible = viewport.map { $0.intersects(CGRect(origin: .zero, size: geometry.size)) } ?? true
                Color.clear.preference(key: TankeiVisibilityKey.self, value: visible)
            }
        }
        .onPreferenceChange(TankeiVisibilityKey.self) { inViewport = $0 }
        .onAppear { present = true; motionStart = .now }
        .onDisappear { present = false }
        .onChange(of: state) { _, _ in if canAnimate && animated { interactionStart = .now; playID += 1 } }
        .onChange(of: eventID) { _, _ in if canAnimate && animated { interactionStart = .now; playID += 1 } }
        .task(id: "\(canAnimate && idle)-\(state.rawValue)-\(stage.rawValue)-\(dancing)") {
            guard canAnimate && idle else { return }
            do {
                try await Task.sleep(for: .seconds(dancing ? 0.2 : 1.6))
                while !Task.isCancelled {
                    idleAction = dancing ? .dance : .choose(state: state, stage: stage, excluding: idleAction)
                    actionStart = .now
                    try await Task.sleep(for: .seconds(dancing ? 2.8 : Double.random(in: 4.2...6.8)))
                }
            } catch { /* Visibility, accessibility, or scene changes cancel the scheduler. */ }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .receive(on: RunLoop.main)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private var animatedDrawing: some View {
        let state = state
        let stage = stage
        let size = size
        let idle = idle
        let expressive = expressive
        let celebrating = state == .celebrate
        let recovering = state == .recover
        let energy = expressive ? 2.4 : 1.0
        let motionStart = motionStart
        let playID = playID
        let idleAction = idleAction
        let actionStart = actionStart
        let interactionStart = interactionStart
        let dancing = dancing
        return TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !idle)) { timeline in
          let ambient = idle ? TankeiFrame.ambient(at: timeline.date.timeIntervalSince(motionStart), resting: state == .rest,
                                                  expressive: expressive) : TankeiFrame()
          let gesture = idle && timeline.date.timeIntervalSince(interactionStart) >= 1.5 ?
              idleAction.frame(at: timeline.date.timeIntervalSince(actionStart), expressive: expressive)
                .scaled(dancing ? 1.8 : 1) : TankeiFrame()
          Color.clear.keyframeAnimator(initialValue: TankeiFrame(), trigger: playID) { _, frame in
             TankeiDrawing(state: state, stage: stage, size: size, frame: frame.adding(ambient).adding(gesture))
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                CubicKeyframe(celebrating ? 3 : 0, duration: 0.12)
                CubicKeyframe((celebrating ? -9 : -2) * energy, duration: 0.22)
                SpringKeyframe(0, duration: 0.26, spring: .bouncy)
                CubicKeyframe(celebrating ? -5 * energy : 0, duration: 0.18)
                SpringKeyframe(0, duration: 0.32, spring: .smooth)
                LinearKeyframe(0, duration: 0.30)
            }
            KeyframeTrack(\.squash) {
                CubicKeyframe(0.025 * energy, duration: 0.12)
                CubicKeyframe(-0.02 * energy, duration: 0.22)
                SpringKeyframe(0.01 * energy, duration: 0.26, spring: .smooth)
                CubicKeyframe(celebrating ? -0.02 * energy : 0, duration: 0.18)
                SpringKeyframe(0, duration: 0.32, spring: .smooth)
                LinearKeyframe(0, duration: 0.30)
            }
            KeyframeTrack(\.wing) {
                CubicKeyframe(-2 * energy, duration: 0.12)
                SpringKeyframe((recovering || state == .rest || state == .review ? 4 : (stage.isChick ? 12 : 6)) * energy,
                               duration: 0.30, spring: .smooth)
                CubicKeyframe(celebrating ? -4 * energy : 0, duration: 0.18)
                SpringKeyframe(celebrating ? 8 * energy : 0, duration: 0.24, spring: .smooth)
                SpringKeyframe(0, duration: 0.32, spring: .smooth)
                LinearKeyframe(0, duration: 0.24)
            }
            KeyframeTrack(\.nod) {
                CubicKeyframe((recovering ? 4 : 2) * energy, duration: 0.26)
                CubicKeyframe(recovering ? -2 * energy : 0, duration: 0.22)
                SpringKeyframe(0, duration: 0.42, spring: .smooth)
                LinearKeyframe(0, duration: 0.50)
            }
            KeyframeTrack(\.eyeScale) {
                LinearKeyframe(1, duration: 0.38)
                CubicKeyframe(0.12, duration: 0.06)
                CubicKeyframe(1, duration: 0.10)
                LinearKeyframe(1, duration: 0.86)
            }
            KeyframeTrack(\.tail) {
                CubicKeyframe(0, duration: 0.18)
                SpringKeyframe(8 * energy, duration: 0.28, spring: .smooth)
                SpringKeyframe(0, duration: 0.40, spring: .smooth)
                LinearKeyframe(0, duration: 0.54)
            }
            KeyframeTrack(\.sway) {
                CubicKeyframe(expressive ? -3 : 0, duration: 0.20)
                CubicKeyframe(expressive ? 3 : 0, duration: 0.26)
                SpringKeyframe(0, duration: 0.44, spring: .smooth)
                LinearKeyframe(0, duration: 0.50)
            }
            KeyframeTrack(\.burst) {
                LinearKeyframe(0, duration: 0.18)
                LinearKeyframe(expressive && (celebrating || recovering) ? 1 : 0, duration: 1.0)
                MoveKeyframe(0)
                LinearKeyframe(0, duration: 0.22)
            }
        }
        }
    }
}

private struct TankeiDrawing: View {
    @Environment(\.mascotBaseColor) private var baseColor
    @Environment(\.mascotChickColor) private var chickColor
    let state: TankeiState
    let stage: TankeiStage
    let size: CGFloat
    let frame: TankeiFrame

    var body: some View {
        Canvas { context, canvasSize in
            if frame.burst > 0 && frame.burst < 1 { drawReaction(in: context, canvasSize: canvasSize) }
            let proportions = TankeiArtwork.proportions(stage)
            let pose = TankeiArtwork.pose(state)
            let compact = size < 48
            let bottom: CGFloat = stage.isChick ? 210 : 225
            var rig = context
            rig.scaleBy(x: canvasSize.width / 256, y: canvasSize.height / 256)
            rig.translateBy(x: 128, y: bottom + frame.lift)
            rig.rotate(by: .degrees(frame.sway))
            rig.scaleBy(x: proportions.scale * (1 + frame.squash * 0.6),
                        y: proportions.scale * (1 - frame.squash))
            rig.translateBy(x: -128, y: -bottom)
            let wing = pose.wing + frame.wing

            if stage.isChick {
                TankeiArtwork.chickFeet(&rig)
                var body = transformed(rig, degrees: pose.head + frame.nod, x: 128, y: 183)
                var left = transformed(body, degrees: wing, x: 78, y: 144, scale: proportions.wingScale)
                var right = transformed(body, degrees: -wing, x: 178, y: 144, scale: proportions.wingScale)
                TankeiArtwork.chickWingLeft(&left, baseColor: chickColor)
                TankeiArtwork.chickWingRight(&right, baseColor: chickColor)
                TankeiArtwork.chickBody(&body, baseColor: chickColor)
                var fluff = transformed(body, degrees: frame.tail * 0.5, x: 128, y: 78)
                TankeiArtwork.chickFluff(&fluff)
                var eyes = transformed(body, x: 128, y: 124, scaleY: pose.eyes * frame.eyeScale)
                eyes.translateBy(x: frame.gaze, y: pose.gaze / max(0.01, pose.eyes * frame.eyeScale))
                TankeiArtwork.chickEyes(&eyes)
                if !compact { TankeiArtwork.chickCheeks(&body) }
                TankeiArtwork.chickBeak(&body)
                TankeiArtwork.chickMouth(&body)
            } else {
                var tail = transformed(rig, degrees: frame.tail, x: 180, y: 164)
                TankeiArtwork.chickenTail(&tail, baseColor: baseColor)
                TankeiArtwork.chickenLegs(&rig, baseColor: baseColor)
                TankeiArtwork.chickenFeet(&rig)
                TankeiArtwork.chickenBody(&rig, baseColor: baseColor)
                TankeiArtwork.chickenShoulderLeft(&rig, baseColor: baseColor)
                var left = transformed(rig, degrees: wing, x: 89, y: 126, scale: proportions.wingScale)
                TankeiArtwork.chickenForearmLeft(&left, baseColor: baseColor)
                TankeiArtwork.chickenShoulderRight(&rig, baseColor: baseColor)
                var right = transformed(rig, degrees: -wing, x: 167, y: 126, scale: proportions.wingScale)
                TankeiArtwork.chickenForearmRight(&right, baseColor: baseColor)
                if !compact {
                    TankeiArtwork.chickenChest(&rig)
                    var abs = rig
                    abs.opacity *= proportions.absOpacity
                    TankeiArtwork.chickenAbs(&abs)
                }
                var head = transformed(rig, degrees: pose.head + frame.nod, x: 128, y: 122)
                TankeiArtwork.chickenHead(&head, baseColor: baseColor)
                TankeiArtwork.chickenComb(&head)
                var eyes = transformed(head, x: 128, y: 87, scaleY: pose.eyes * frame.eyeScale)
                eyes.translateBy(x: frame.gaze, y: pose.gaze / max(0.01, pose.eyes * frame.eyeScale))
                TankeiArtwork.chickenEyes(&eyes)
                if !compact { TankeiArtwork.chickenCheeks(&head) }
                TankeiArtwork.chickenBeak(&head)
                TankeiArtwork.chickenMouth(&head)
            }
        }
    }

    /// Brief local accents, not an overlay or an endless confetti emitter.
    private func drawReaction(in context: GraphicsContext, canvasSize: CGSize) {
        let progress = Double(frame.burst)
        let spread = 1 - pow(1 - progress, 3)
        let opacity = sin(progress * .pi)
        let colors: [Color] = [Palette.accent("#F2B544"), Palette.accent("#F06D5E"), Palette.positive]
        let count = state == .celebrate ? 12 : 4
        for index in 0..<count {
            let angle = Double(index) * 2 * .pi / Double(count) - .pi / 2
            let radius = canvasSize.width * (0.24 + 0.22 * spread)
            let center = CGPoint(x: canvasSize.width / 2 + cos(angle) * radius,
                                 y: canvasSize.height * 0.48 + sin(angle) * radius * 0.8 + progress * progress * 10)
            var particle = context
            particle.opacity *= opacity
            particle.translateBy(x: center.x, y: center.y)
            particle.rotate(by: .degrees(Double(index * 31) + progress * 140))
            let bounds = CGRect(x: -2, y: -4, width: state == .celebrate ? 4 : 5, height: state == .celebrate ? 8 : 5)
            particle.fill(Path(roundedRect: bounds, cornerRadius: 2), with: .color(colors[index % colors.count]))
        }
    }

    private func transformed(_ context: GraphicsContext, degrees: Double = 0, x: CGFloat, y: CGFloat,
                             scale: CGFloat = 1, scaleY: CGFloat? = nil) -> GraphicsContext {
        var result = context
        result.translateBy(x: x, y: y)
        result.rotate(by: .degrees(degrees))
        result.scaleBy(x: scale, y: scaleY ?? scale)
        result.translateBy(x: -x, y: -y)
        return result
    }
}

/// A one-colour cut-out of the mascot, used for unreached gauge stops and the evolution flicker.
struct TankeiSilhouette: View {
    let stage: TankeiStage
    let size: CGFloat
    var color: Color = .white

    var body: some View {
        color.frame(width: size, height: size)
            .mask(TankeiView(stage: stage, size: size))
            .accessibilityHidden(true)
    }
}

/// Home: the four stages as stops on one track. The fill shows how far the earned stage is toward
/// the next one, from saved highs only, so it never moves back. No numbers are shown.
struct TankeiEvolutionGaugeView: View {
    let gauge: TankeiEvolutionGauge
    var width: CGFloat = 136
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    private let stop: CGFloat = 24

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track).frame(height: 8).padding(.horizontal, stop / 2)
                Capsule().fill(Palette.piyo).frame(width: fillWidth, height: 8).padding(.leading, stop / 2)
                HStack(spacing: 0) {
                    ForEach(TankeiStage.allCases) { stage in
                        if stage != .chick { Spacer(minLength: 0) }
                        stageStop(stage)
                    }
                }
            }
            .frame(width: width)
            if gauge.almostNext {
                Text("もうすぐ進化！")
                    .font(.caption.weight(.heavy)).foregroundStyle(Palette.beakText)
                    .scaleEffect(pulse ? 1.08 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = !reduceMotion }
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("相棒の進化")
        .accessibilityValue(gauge.stage.title + (gauge.almostNext ? "、もうすぐ進化" : ""))
        .accessibilityIdentifier("evolutionGauge")
    }

    private var fillWidth: CGFloat {
        let segments = TankeiStage.allCases.count - 1
        let filled = (0..<segments).reduce(0.0) { $0 + gauge.fill(segment: $1) }
        return (width - stop) * CGFloat(filled / Double(segments))
    }

    private func stageStop(_ stage: TankeiStage) -> some View {
        let reached = stage.rawValue <= gauge.stage.rawValue
        return ZStack {
            Circle().fill(reached ? Palette.piyoTint : Palette.surface)
            Circle().strokeBorder(reached ? Palette.piyo : Palette.track, lineWidth: 2)
            if reached { TankeiView(stage: stage, size: stop - 6) }
            else { TankeiSilhouette(stage: stage, size: stop - 6, color: Palette.muted.opacity(0.45)) }
        }
        .frame(width: stop, height: stop)
    }
}

/// Shown once, after the final answer, when a new stage was earned. The screen glows, the
/// silhouettes flicker faster and faster, a flash, and the new stage dances in.
/// Reduce Motion or Low Power Mode: the new stage as a still picture and a haptic.
struct TankeiGrowthCelebration: View {
    let initialStage: TankeiStage
    let stage: TankeiStage
    let accentHex: String
    let buttonTitle: String
    let continueAction: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.before
    @State private var showNew = false
    @State private var flash = 0.0
    @State private var burst = 0
    @State private var haptic = 0

    private enum Phase { case before, morphing, revealed }
    private var still: Bool { reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled }

    var body: some View {
        let size: CGFloat = dynamicTypeSize.isAccessibilitySize ? 192 : 256
        let revealed = phase == .revealed
        ZStack {
            EvolutionGlow(active: phase != .before, still: still).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text("進化した！")
                        .font(.system(dynamicTypeSize.isAccessibilitySize ? .title2 : .largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(Palette.onPiyo)
                        .scaleEffect(revealed || still ? 1 : 0.4).opacity(revealed ? 1 : 0)
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("mascotGrowthMilestone")
                    ZStack {
                        switch phase {
                        case .before:
                            TankeiView(state: .ready, stage: initialStage, size: size, animated: true, idle: true, expressive: true)
                        case .morphing:
                            TankeiSilhouette(stage: showNew ? stage : initialStage, size: size)
                                .scaleEffect(showNew ? 1.1 : 0.94)
                                .shadow(color: .white, radius: 28)
                        case .revealed:
                            TankeiView(state: .celebrate, stage: stage, size: size, animated: true, idle: true,
                                       expressive: true, dancing: true)
                        }
                    }
                    .frame(width: size, height: size)
                    Text(stage.title)
                        .font(.system(.title, design: .rounded).weight(.heavy)).foregroundStyle(Palette.onPiyo)
                        .opacity(revealed ? 1 : 0)
                        .accessibilityIdentifier("growthStage")
                }
                .frame(maxWidth: .infinity).padding(.horizontal, 24)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 24 : 48)
            }
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
            if !still { FeatherBurst(trigger: burst, count: TankeiCombo.blazing.featherCount).ignoresSafeArea().allowsHitTesting(false) }
        }
        .safeAreaInset(edge: .bottom) {
            Button(buttonTitle, action: continueAction)
                .buttonStyle(PuffyButtonStyle())
                .frame(maxWidth: 600)
                .padding(20).frame(maxWidth: .infinity)
                .opacity(revealed ? 1 : 0).disabled(!revealed)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: haptic)
        .task { await play() }
    }

    private func play() async {
        guard phase == .before else { return }
        SoundEffects.shared.play(.evolve)
        guard !still else { phase = .revealed; haptic += 1; return }
        // The flicker speeds up until the sound's chord lands at about 1.45 s.
        do {
            try await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeInOut(duration: 0.3)) { phase = .morphing }
            for gap in [260, 220, 180, 150, 120, 100, 80, 70, 60, 60] {
                try await Task.sleep(for: .milliseconds(gap))
                withAnimation(.easeInOut(duration: Double(gap) / 1_250)) { showNew.toggle() }
            }
        } catch { phase = .revealed; return }
        flash = 1
        withAnimation(.spring(duration: 0.5, bounce: 0.5)) { phase = .revealed }
        withAnimation(.easeOut(duration: 0.9)) { flash = 0 }
        burst += 1
        haptic += 1
    }
}

/// Bright full-screen glow with slowly turning rays. Still under Reduce Motion or Low Power Mode.
private struct EvolutionGlow: View {
    let active: Bool
    let still: Bool

    var body: some View {
        TimelineView(.animation(paused: still || !active)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let radius = hypot(size.width, size.height)
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .radialGradient(Gradient(colors: [.white, Palette.piyo, Palette.beak]),
                                                   center: center, startRadius: 0, endRadius: radius * 0.75))
                guard active else { return }
                let turn = still ? 0 : timeline.date.timeIntervalSinceReferenceDate * 0.35
                let rays = 14
                var light = context
                light.opacity = 0.3
                for index in 0..<rays {
                    let angle = Double(index) / Double(rays) * 2 * .pi + turn
                    let half = .pi / Double(rays) * 0.45
                    var ray = Path()
                    ray.move(to: center)
                    ray.addLine(to: CGPoint(x: center.x + cos(angle - half) * radius, y: center.y + sin(angle - half) * radius))
                    ray.addLine(to: CGPoint(x: center.x + cos(angle + half) * radius, y: center.y + sin(angle + half) * radius))
                    ray.closeSubpath()
                    light.fill(ray, with: .color(.white))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A small, native companion moment; the words, not the illustration, carry meaning.
struct TankeiMoment: View {
    let title: String
    let detail: String
    var state: TankeiState = .ready
    var stage: TankeiStage = .chick
    var size: CGFloat = 80
    var idle = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            TankeiView(state: state, stage: stage, size: dynamicTypeSize.isAccessibilitySize ? 64 : size,
                       animated: true, idle: idle)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A real app destination, not the Debug gallery. Reactions never alter study records.
/// The companion lives alongside progress and history in the learning record.
struct TankeiRecordCompanion: View {
    let growth: TankeiGrowth
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var state: TankeiState = .ready
    @State private var replay = 0

    var body: some View {
        Surface(inset: 16) {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
                AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            layout {
                TankeiView(state: state, stage: growth.stage, size: 104, animated: true, idle: true, expressive: true, eventID: replay)
                VStack(alignment: .leading, spacing: 6) {
                    Text("相棒の成長").font(.headline)
                    Text(growth.stage.title).font(.title3.bold()).accessibilityIdentifier("mascotStage")
                    Text(growth.stage.companionMessage).font(.caption).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { reactionButtons }
                VStack(alignment: .leading, spacing: 8) { reactionButtons }
            }
        }
    }

    private var reactionButtons: some View {
        ForEach([TankeiState.encourage, .celebrate, .rest]) { item in
            Button(item == .encourage ? "応援して" : item == .celebrate ? "力こぶ！" : "ひと休み") {
                state = item
                replay += 1
            }
            .buttonStyle(.bordered).frame(minHeight: 44)
            .accessibilityAddTraits(state == item ? .isSelected : [])
        }
    }
}

#if DEBUG
#Preview("原案の相棒・成長と動き") { TankeiGallery() }

/// Development only: preview all parts/poses without changing any study data.
struct TankeiGallery: View {
    @State private var replay = 0
    @State private var progress = min(100, max(0, UserDefaults.standard.double(forKey: "TankeiGalleryProgress")))
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("いっしょに、ひと区切り。").font(.title2.bold())
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TankeiView(state: .celebrate, stage: .at(progress / 100), size: 176, animated: true, idle: true, expressive: true, eventID: replay)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(TankeiStage.at(progress / 100).title).font(.title3.bold())
                                Text("表示検証スコア \(Int(progress))").font(.subheadline.monospacedDigit())
                            }
                        }
                        Slider(value: $progress, in: 0...100, step: 1) { Text("成長をプレビュー") }
                            .accessibilityIdentifier("mascotGrowthSlider")
                        HStack {
                            ForEach([0, 25, 60, 85], id: \.self) { value in
                                Button("\(value)") { progress = Double(value) }
                                    .buttonStyle(.bordered).frame(minHeight: 44)
                            }
                        }
                    }
                    Text("原案のひよことチキン").font(.headline)
                    HStack(spacing: 16) {
                        TankeiView(stage: .chick, size: 128)
                        TankeiView(stage: .chicken, size: 128)
                    }
                    Text("部位ごとの動き").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 20) {
                        ForEach(TankeiState.allCases) { state in
                            VStack(spacing: 8) {
                                TankeiView(state: state, stage: .at(progress / 100), size: 128, animated: true, expressive: true, eventID: replay)
                                Text(state.title).font(.subheadline)
                            }
                        }
                    }
                    Text("小さくても、同じシルエット").font(.headline)
                    HStack(alignment: .bottom, spacing: 24) {
                        ForEach([24, 32, 48, 64], id: \.self) { size in
                            VStack(spacing: 8) {
                                TankeiView(stage: .at(progress / 100), size: CGFloat(size))
                                Text("\(size)pt").font(.caption)
                            }
                        }
                    }
                    Button("動きをもう一度") { replay += 1 }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                }
                .padding(24)
            }
            .background(Palette.background)
            .navigationTitle("相棒の成長")
        }
    }
}
#endif
