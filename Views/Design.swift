import SwiftUI

enum Palette {
    static let ink = Color.primary
    static let muted = adaptive(light: 0x636B65, dark: 0xB5BEB7)
    static let background = adaptive(light: 0xF5F4F0, dark: 0x181C1A)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x242A26)
    static let border = adaptive(light: 0xE2E5DF, dark: 0x465048)
    static let track = adaptive(light: 0xE6E9E3, dark: 0x3C453E)
    static let positive = adaptive(light: 0x326D4F, dark: 0xA0D7B5)
    static let review = adaptive(light: 0x87592D, dark: 0xE5BC8F)
    static let growing = adaptive(light: 0x738D80, dark: 0x7D9C8B)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Double((value >> 16) & 255) / 255,
                           green: Double((value >> 8) & 255) / 255,
                           blue: Double(value & 255) / 255, alpha: 1)
        })
    }

    static func accent(_ hex: String) -> Color {
        let value = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x2F6E70
        return Color(red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255,
                      blue: Double(value & 255) / 255)
    }

    /// Readable brand colour for text and controls, separate from the solid button fill.
    static func linkAccent(_ hex: String) -> Color {
        let value = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x2F6E70
        return Color(uiColor: UIColor { traits in
            let blend = traits.userInterfaceStyle == .dark ? 0.6 : 0.0
            let channels = [Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255)]
                .map { ($0 + (255 - $0) * blend) / 255 }
            return UIColor(red: channels[0], green: channels[1], blue: channels[2], alpha: 1)
        })
    }

    static func onAccent(_ hex: String) -> Color {
        let value = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x2F6E70
        let channels = [Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255)]
            .map { $0 / 255 }.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        let luminance = channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        return luminance > 0.179 ? .black : .white
    }
}

struct Surface<Content: View>: View {
    var inset: CGFloat = 20
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(inset)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.border, lineWidth: 0.5))
    }
}

struct Metric: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        Surface {
            Image(systemName: symbol).foregroundStyle(.tint).font(.title3)
                .accessibilityHidden(true)
            Text(value).font(.title2.bold()).contentTransition(.numericText())
            Text(title).font(.footnote).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Press feedback without moving the control or its neighbours.
struct StudyButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct StudyBadge: View {
    let title: String
    let symbol: String
    var color: Color = Palette.muted

    var body: some View {
        Label {
            Text(title).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).accessibilityHidden(true)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct MemoryBar: View {
    let stable: Int
    let growing: Int
    let new: Int

    var body: some View {
        GeometryReader { geometry in
            let total = CGFloat(max(1, stable + growing + new))
            HStack(spacing: 0) {
                Rectangle().fill(Palette.positive).frame(width: geometry.size.width * CGFloat(stable) / total)
                Rectangle().fill(Palette.growing)
                    .overlay {
                        Canvas { context, size in
                            var stripes = Path()
                            for x in stride(from: -size.height, to: size.width, by: 8) {
                                stripes.move(to: CGPoint(x: x, y: size.height))
                                stripes.addLine(to: CGPoint(x: x + size.height, y: 0))
                            }
                            context.stroke(stripes, with: .color(Palette.surface.opacity(0.65)), lineWidth: 2)
                        }
                    }
                    .frame(width: geometry.size.width * CGFloat(growing) / total).clipped()
                Rectangle().fill(Palette.track).frame(width: geometry.size.width * CGFloat(new) / total)
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("記憶の状態")
        .accessibilityValue("定着 \(stable)問、学習中 \(growing)問、これから \(new)問")
    }
}

struct SubjectProgress: View {
    let subject: String
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(subject).font(.subheadline)
                Spacer(minLength: 8)
                Text("\(score)%").font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
            }
            ProgressView(value: Double(score), total: 100).tint(Palette.positive)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subject)
        .accessibilityValue("定着の目安 \(score)パーセント")
    }
}

struct ReadinessRing: View {
    let value: Int
    @ScaledMetric(relativeTo: .title) private var diameter: CGFloat = 96

    var body: some View {
        ZStack {
            Circle().stroke(Palette.track, lineWidth: 7)
            Circle().trim(from: 0, to: CGFloat(value) / 100)
                .stroke(Palette.positive, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(value)").font(.title.bold().monospacedDigit())
                Text("/ 100").font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .frame(width: min(diameter, 240), height: min(diameter, 240))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("学習準備度")
        .accessibilityValue("100中\(value)。合格確率ではありません")
    }
}

/// An educational illustration, deliberately not plotted as a personal prediction.
struct MemoryRhythm: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Canvas { context, size in
                let left: CGFloat = 12
                let width = size.width - 24
                let top: CGFloat = 12
                let bottom = size.height - 12
                let first = left + width * 0.34
                let second = left + width * 0.69
                var fading = Path()
                fading.move(to: CGPoint(x: left, y: top))
                fading.addCurve(to: CGPoint(x: left + width, y: bottom),
                                control1: CGPoint(x: left + width * 0.15, y: bottom * 0.88),
                                control2: CGPoint(x: left + width * 0.50, y: bottom))
                context.stroke(fading, with: .color(Palette.muted.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                var renewed = Path()
                renewed.move(to: CGPoint(x: left, y: top))
                renewed.addQuadCurve(to: CGPoint(x: first, y: bottom * 0.70),
                                     control: CGPoint(x: left + width * 0.09, y: bottom * 0.65))
                renewed.addLine(to: CGPoint(x: first, y: top))
                renewed.addQuadCurve(to: CGPoint(x: second, y: bottom * 0.43),
                                     control: CGPoint(x: first + width * 0.13, y: bottom * 0.40))
                renewed.addLine(to: CGPoint(x: second, y: top))
                renewed.addQuadCurve(to: CGPoint(x: left + width, y: bottom * 0.25),
                                     control: CGPoint(x: second + width * 0.13, y: bottom * 0.25))
                context.stroke(renewed, with: .color(Palette.positive),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                for x in [left, first, second] {
                    let dot = Path(ellipseIn: CGRect(x: x - 5, y: top - 5, width: 10, height: 10))
                    context.fill(dot, with: .color(Palette.positive))
                }
            }
            .frame(height: 104)
            .accessibilityHidden(true)
            let columns = dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                Array(repeating: GridItem(.flexible()), count: 3)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                rhythmStep("思い出す", symbol: "bubble.left")
                rhythmStep("ひと休み", symbol: "moon")
                rhythmStep("もう一度", symbol: "arrow.clockwise")
            }
            Text("間隔をあけて、記憶を育てる。")
                .font(.subheadline).foregroundStyle(Palette.muted)
            Text("学び方のイメージ").font(.caption2).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private func rhythmStep(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold)).foregroundStyle(Palette.positive)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct LearningGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("忘れる前に、\nもう一度出会う。")
                        .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    Surface { MemoryRhythm() }
                    guideItem("思い出すことが練習に", symbol: "bubble.left",
                              detail: "選択肢を開く前に、答えをひとつ考える。難しいときはすぐ開いても大丈夫。")
                    guideItem("次の復習は、回答に合わせて", symbol: "calendar",
                              detail: "別の日に思い出せるほど、復習の間隔が少しずつ広がります。間違えた問題の目安は翌日です。")
                    Surface {
                        Text("数値は、学習の目安").font(.headline)
                        Text("定着度と復習日は回答履歴からの推定です。実測の記憶確率や、合格を保証する数値ではありません。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        DisclosureGroup("指標の見方") {
                            Text("学習準備度は、学習した範囲・記憶の目安・科目の偏り・最近の回答・模試から算出します。「定着」は、別の日に3回以上正解し、記憶が安定している問題です。")
                                .font(.subheadline).foregroundStyle(Palette.muted).padding(.top, 8)
                        }
                    }
                    Surface {
                        Text("学び方の参考にした研究").font(.headline)
                        Link("分散学習・想起練習のレビュー ↗", destination: URL(string: "https://www.psychologicalscience.org/publications/journals/pspi/learning-techniques.html")!)
                        Link("別の日に学び直す研究 ↗", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/29431462/")!)
                        Text("研究を参考にした独自の計算です。個人ごとの最適な間隔を実証したものではありません。")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                .padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .navigationTitle("記憶と復習")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
            }
        }
    }

    private func guideItem(_ title: String, symbol: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(Palette.muted)
        }
    }
}
