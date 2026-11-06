// ピヨポップ リデザインのたたき台（ホーム／4択クイズ）。
// アプリのターゲットには含めていない。Xcodeの空プロジェクトか、本体の Views/ にコピーして #Preview で確認する。
// 本体へ組み込むときは PiyoMascot を TankeiView、サンプル値を StudyStore / SessionPlanner.today に置き換える。
import SwiftUI

// MARK: - Tokens

enum PiyoPop {
    static let yellow = Color(hex: 0xFFC83D)
    static let yellowDeep = Color(hex: 0xE0A100)
    static let yellowTint = Color(hex: 0xFFF1C7)
    static let beak = Color(hex: 0xFF8A3D)
    static let cream = Color(hex: 0xFFF9EB)
    static let surface = Color.white
    static let line = Color(hex: 0xF1E3C2)
    static let ink = Color(hex: 0x2D2618)
    static let ink2 = Color(hex: 0x6A5D45)
    static let correct = Color(hex: 0x0B7A45)
    static let correctTint = Color(hex: 0xDFF6E8)
    static let oops = Color(hex: 0xC24510)
    static let oopsTint = Color(hex: 0xFFE6D9)
    static let sky = Color(hex: 0x2F6FDB)
    static let skyTint = Color(hex: 0xEAF2FF)

    enum Radius { static let chip: CGFloat = 999, choice: CGFloat = 16, button: CGFloat = 18, card: CGFloat = 24 }

    /// 見出し・数字は丸ゴ。問題文と解説は可読性優先で標準の角ゴ（Dynamic Typeに追従）。
    static func rounded(_ style: Font.TextStyle, _ weight: Font.Weight = .heavy) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Components

/// 押すと影の分だけ沈む「ぷっくり」ボタン。押せるものだけに使う。
struct PuffyButtonStyle: ButtonStyle {
    var fill = PiyoPop.yellow
    var shadow = PiyoPop.yellowDeep
    var foreground = PiyoPop.ink
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = configuration.isPressed ? 0 : 5
        configuration.label
            .font(PiyoPop.rounded(.headline))
            .foregroundStyle(isEnabled ? foreground : Color(hex: 0x8A7B60))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isEnabled ? fill : Color(hex: 0xEFE6D2), in: RoundedRectangle(cornerRadius: PiyoPop.Radius.button))
            .background(isEnabled ? shadow : Color(hex: 0xDCCFB3), in: RoundedRectangle(cornerRadius: PiyoPop.Radius.button))
            .padding(.bottom, depth)
            .offset(y: 5 - depth)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// 本体の相棒（TankeiView）の代わりの仮表示。
struct PiyoMascot: View {
    var size: CGFloat = 96
    var body: some View {
        ZStack {
            Ellipse().fill(PiyoPop.yellow).overlay(Ellipse().stroke(PiyoPop.ink, lineWidth: size * 0.04))
            HStack(spacing: size * 0.22) { Circle().frame(width: size * 0.08); Circle().frame(width: size * 0.08) }
                .foregroundStyle(PiyoPop.ink).offset(y: -size * 0.06)
            Capsule().fill(PiyoPop.beak).frame(width: size * 0.2, height: size * 0.09).offset(y: size * 0.06)
        }
        .frame(width: size * 0.82, height: size * 0.78)
        .frame(width: size, height: size)
        .accessibilityLabel("ピヨ")
    }
}

struct GoalRing<Content: View>: View {
    let progress: Double
    @ViewBuilder let content: Content
    var body: some View {
        ZStack {
            Circle().stroke(PiyoPop.yellowTint, lineWidth: 10)
            Circle().trim(from: 0, to: progress)
                .stroke(PiyoPop.yellow, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: progress)
            content
        }
    }
}

// MARK: - Home

struct PiyoHomePrototype: View {
    var streak = 7
    var feathers = 240
    var done = 4
    var goal = 10
    var reviewCount = 3
    var newCount = 7
    var start: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    chip("\(streak)日", systemImage: "pawprint.fill", tint: PiyoPop.beak).accessibilityLabel("\(streak)日連続")
                    chip("\(feathers)", systemImage: "leaf.fill", tint: PiyoPop.yellowDeep).accessibilityLabel("はね \(feathers)")
                    Spacer()
                }
                HStack(spacing: 12) {
                    GoalRing(progress: Double(done) / Double(goal)) { PiyoMascot(size: 92) }
                        .frame(width: 132, height: 132)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("おかえり！\nきのう迷った\(reviewCount)問が待ってるよ")
                            .font(PiyoPop.rounded(.subheadline, .bold))
                            .padding(10).background(PiyoPop.yellowTint, in: RoundedRectangle(cornerRadius: 16))
                        Text("今日 \(done) / \(goal)問").font(PiyoPop.rounded(.subheadline, .bold)).foregroundStyle(PiyoPop.ink2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16).piyoCard()

                Button(action: start) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill").frame(width: 40, height: 40).background(.white, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("今日の\(reviewCount + newCount)問をはじめる").font(PiyoPop.rounded(.title3))
                            Text("復習 \(reviewCount) · 新しい問題 \(newCount)").font(PiyoPop.rounded(.caption, .bold))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18).frame(minHeight: 72)
                }
                .buttonStyle(PuffyButtonStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: done)
            }
            .padding(16)
        }
        .background(PiyoPop.cream)
        .foregroundStyle(PiyoPop.ink)
    }

    private func chip(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(PiyoPop.rounded(.subheadline))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 12).frame(minHeight: 36)
            .background(PiyoPop.surface, in: Capsule())
            .shadow(color: PiyoPop.line, radius: 0, y: 2)
            .symbolRenderingMode(.monochrome).tint(tint)
    }
}

extension View {
    func piyoCard() -> some View {
        background(PiyoPop.surface, in: RoundedRectangle(cornerRadius: PiyoPop.Radius.card))
            .shadow(color: PiyoPop.line, radius: 0, y: 3)
            .shadow(color: Color(hex: 0x785A14).opacity(0.08), radius: 12, y: 10)
    }
}

// MARK: - Quiz

struct PiyoQuizPrototype: View {
    let stem = "IPv4で、サブネットマスクが 255.255.255.192 のネットワークがある。1つのサブネットでホストに割り当てられるアドレスの最大数はどれか。"
    let choices = ["30", "62", "64", "126"]
    let correctIndex = 1
    let explanation = "192 は 2進数で 11000000。ホスト部は6ビットなので 2⁶ = 64。ネットワークアドレスとブロードキャストアドレスを除いて 62 個。"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Int?
    @State private var checked = false
    @State private var shake = 0
    @State private var confetti = 0

    private var isCorrect: Bool { checked && selected == correctIndex }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(stem).font(.body.weight(.semibold)).lineSpacing(6)
                    ForEach(choices.indices, id: \.self) { index in choiceRow(index) }
                }
                .padding(16)
            }
            footer
        }
        .background(PiyoPop.cream)
        .foregroundStyle(PiyoPop.ink)
        .overlay { if !reduceMotion { FeatherBurst(trigger: confetti).allowsHitTesting(false) } }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(trigger: checked) { _, now in
            guard now else { return nil }
            return isCorrect ? .success : .warning
        }
    }

    private func choiceRow(_ index: Int) -> some View {
        let state = rowState(index)
        return Button {
            guard !checked else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.5)) { selected = index }
        } label: {
            HStack(spacing: 12) {
                Text(["ア", "イ", "ウ", "エ"][index]).font(PiyoPop.rounded(.headline))
                    .frame(width: 32, height: 32)
                    .background(state.keyFill, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(state.keyText)
                Text(choices[index]).font(PiyoPop.rounded(.body, .bold))
                Spacer()
                if let mark = state.mark { Image(systemName: mark).font(.headline) }
            }
            .padding(.horizontal, 14).frame(minHeight: 60)
            .background(state.fill, in: RoundedRectangle(cornerRadius: PiyoPop.Radius.choice))
            .overlay(RoundedRectangle(cornerRadius: PiyoPop.Radius.choice).strokeBorder(state.border, lineWidth: 2))
            .shadow(color: state.border.opacity(0.5), radius: 0, y: 4)
            .foregroundStyle(state.text)
            .scaleEffect(selected == index && !checked && !reduceMotion ? 1.02 : 1)
            .modifier(Shake(amount: checked && index == selected && !isCorrect && !reduceMotion ? CGFloat(shake) : 0))
            .opacity(checked && state.mark == nil ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected == index ? .isSelected : [])
    }

    @ViewBuilder private var footer: some View {
        if !checked {
            Button("答え合わせ") {
                checked = true
                if isCorrect { confetti += 1 } else { withAnimation(.linear(duration: 0.32)) { shake += 1 } }
            }
            .buttonStyle(PuffyButtonStyle())
            .disabled(selected == nil)
            .padding(16)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    PiyoMascot(size: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Label(isCorrect ? "せいかい！" : "おしい！", systemImage: isCorrect ? "checkmark" : "xmark")
                            .font(PiyoPop.rounded(.title2))
                        Text(isCorrect ? "はね +10" : "正解は イ 62。あとでまた出すね").font(PiyoPop.rounded(.subheadline, .bold))
                    }
                }
                .foregroundStyle(isCorrect ? Color(hex: 0x0B5E36) : Color(hex: 0x9A3409))
                Text(explanation).font(.subheadline).padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                Button(isCorrect ? "つぎへ" : "わかった、つぎへ") { selected = nil; checked = false }
                    .buttonStyle(PuffyButtonStyle(fill: isCorrect ? PiyoPop.correct : PiyoPop.oops,
                                                  shadow: isCorrect ? Color(hex: 0x075530) : Color(hex: 0x8E300A),
                                                  foreground: .white))
            }
            .padding(16)
            .background(isCorrect ? PiyoPop.correctTint : PiyoPop.oopsTint,
                        in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private struct RowState { var fill: Color; var border: Color; var text: Color; var keyFill: Color; var keyText: Color; var mark: String? }

    private func rowState(_ index: Int) -> RowState {
        if checked && index == correctIndex {
            return RowState(fill: PiyoPop.correctTint, border: PiyoPop.correct, text: Color(hex: 0x0B5E36),
                            keyFill: PiyoPop.correct, keyText: .white, mark: "checkmark")
        }
        if checked && index == selected {
            return RowState(fill: PiyoPop.oopsTint, border: PiyoPop.oops, text: Color(hex: 0x9A3409),
                            keyFill: PiyoPop.oops, keyText: .white, mark: "xmark")
        }
        if !checked && index == selected {
            return RowState(fill: PiyoPop.skyTint, border: PiyoPop.sky, text: PiyoPop.ink,
                            keyFill: PiyoPop.sky, keyText: .white, mark: nil)
        }
        return RowState(fill: PiyoPop.surface, border: PiyoPop.line, text: PiyoPop.ink,
                        keyFill: PiyoPop.yellowTint, keyText: PiyoPop.ink, mark: nil)
    }
}

/// 不正解の選択肢を左右に小さく揺らす。
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(amount * .pi * 4), y: 0))
    }
}

/// 正解時に羽根を0.8秒ほど降らせる。triggerが増えるたびに1回。
struct FeatherBurst: View {
    let trigger: Int
    @State private var start: Date?

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let t = timeline.date.timeIntervalSince(start)
                guard t < 1.1 else { return }
                let colors = [PiyoPop.yellow, PiyoPop.beak, Color(hex: 0xFFE48F)]
                for i in 0..<14 {
                    let x = size.width * (Double(i) + 0.5) / 14 + sin(Double(i) * 1.7 + t * 6) * 10
                    let y = -20 + t * t * (380 + Double(i % 4) * 60)
                    let rect = CGRect(x: x, y: y, width: 10, height: 18)
                    var c = context
                    c.opacity = max(0, 1 - t / 1.1)
                    c.translateBy(x: rect.midX, y: rect.midY)
                    c.rotate(by: .degrees(t * 280 + Double(i) * 25))
                    c.fill(Path(roundedRect: CGRect(x: -5, y: -9, width: 10, height: 18), cornerRadius: 5),
                           with: .color(colors[i % colors.count]))
                }
            }
        }
        .onChange(of: trigger) { start = .now }
    }
}

#Preview("ホーム") { PiyoHomePrototype() }
#Preview("4択クイズ") { PiyoQuizPrototype() }
