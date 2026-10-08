import SwiftUI
import Combine

private struct TankeiMotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private struct TankeiBaseColorKey: EnvironmentKey {
    static let defaultValue = Palette.accent(TankeiPalette.defaultChickenHex)
}

extension EnvironmentValues {
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
        .task(id: "\(canAnimate && idle)-\(state.rawValue)-\(stage.rawValue)") {
            guard canAnimate && idle else { return }
            do {
                try await Task.sleep(for: .seconds(1.6))
                while !Task.isCancelled {
                    idleAction = .choose(state: state, stage: stage, excluding: idleAction)
                    actionStart = .now
                    try await Task.sleep(for: .seconds(Double.random(in: 4.2...6.8)))
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
        return TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !idle)) { timeline in
          let ambient = idle ? TankeiFrame.ambient(at: timeline.date.timeIntervalSince(motionStart), resting: state == .rest,
                                                  expressive: expressive) : TankeiFrame()
          let gesture = idle && timeline.date.timeIntervalSince(interactionStart) >= 1.5 ?
              idleAction.frame(at: timeline.date.timeIntervalSince(actionStart), expressive: expressive) : TankeiFrame()
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
                TankeiArtwork.chickWingLeft(&left)
                TankeiArtwork.chickWingRight(&right)
                TankeiArtwork.chickBody(&body)
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

/// Replay a newly earned milestone only at the result; never delay the main action.
struct TankeiGrowthReveal: View {
    let state: TankeiState
    let initialStage: TankeiStage
    let stage: TankeiStage
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var revealed = false

    private var shouldReveal: Bool {
        stage.rawValue > initialStage.rawValue && !reduceMotion && scenePhase == .active &&
            !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        TankeiView(state: state, stage: shouldReveal && !revealed ? initialStage : stage,
                    size: size, animated: true, idle: true, expressive: true)
            .task(id: stage) {
                guard shouldReveal else { revealed = true; return }
                do { try await Task.sleep(for: .milliseconds(280)) } catch { return }
                guard !Task.isCancelled else { return }
                revealed = true
            }
    }
}

/// Shown once, after the final answer. Learning controls never morph mid-session.
struct TankeiGrowthCelebration: View {
    let initialStage: TankeiStage
    let stage: TankeiStage
    let accentHex: String
    let buttonTitle: String
    let continueAction: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("成長したよ！").font(dynamicTypeSize.isAccessibilitySize ? .title2.bold() : .largeTitle.bold())
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("mascotGrowthMilestone")
                TankeiGrowthReveal(state: .celebrate, initialStage: initialStage, stage: stage,
                                   size: dynamicTypeSize.isAccessibilitySize ? 192 : 256)
                Text(stage.title).font(.title2.bold()).accessibilityIdentifier("growthStage")
            }
            .frame(maxWidth: .infinity).padding(.horizontal, 24)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 24 : 40)
        }
        .safeAreaInset(edge: .bottom) {
            Button(buttonTitle, action: continueAction)
                .font(.headline).frame(maxWidth: 600, minHeight: 44)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .tint(Palette.accent(accentHex)).foregroundStyle(Palette.onAccent(accentHex))
                .padding(20).frame(maxWidth: .infinity).background(.bar)
        }
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
struct TankeiCompanionView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    @Binding var order: AnswerHistoryOrder
    let start: (StudySession) -> Void
    let paywall: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var state: TankeiState = .ready
    @State private var replay = 0

    private var growth: TankeiGrowth { TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 8) {
                        TankeiView(state: state, stage: growth.stage, size: 224, animated: true, idle: true, expressive: true, eventID: replay)
                        Text(growth.stage.title).font(.title2.bold()).accessibilityIdentifier("mascotStage")
                        Text(growth.stage.companionMessage).font(.subheadline).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { reactionButtons }
                        VStack(alignment: .leading, spacing: 8) { reactionButtons }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("回答履歴").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        if dynamicTypeSize.isAccessibilitySize {
                            historyOrderPicker.pickerStyle(.menu)
                        } else {
                            historyOrderPicker.pickerStyle(.segmented)
                        }
                    }
                    if store.data.answers.isEmpty {
                        ContentUnavailableView("最初の1問から、ここに記録。", systemImage: "pencil.line")
                    } else {
                        ForEach(AnswerHistoryDay.grouped(store.data.answers, order: order)) { day in
                            Section {
                                ForEach(day.answers) { answer in
                                    HistoryAnswerRow(answer: answer, catalog: catalog, purchase: purchase,
                                                     start: start, paywall: paywall, showDate: false)
                                    Divider()
                                }
                            } header: {
                                Text(day.date, format: .dateTime.year().month().day().weekday())
                                    .font(.headline).foregroundStyle(Palette.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("historyDay")
                            }
                        }
                    }
                }
                .padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .navigationTitle("学習の相棒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
        .environment(\.mascotMotionEnabled, true)
    }

    private var historyOrderPicker: some View {
        Picker("回答履歴の並び順", selection: $order) {
            ForEach(AnswerHistoryOrder.allCases) { item in Text(item.title).tag(item) }
        }
        .frame(minHeight: 44).accessibilityIdentifier("historyOrder")
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
