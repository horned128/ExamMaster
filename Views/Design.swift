import SwiftUI

enum Palette {
    private static let theme: QualificationTheme? = {
        guard let url = Bundle.main.url(forResource: "qualification", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(Qualification.self, from: data))?.theme
    }()
    // ピヨポップ: 地の色・文字・境界はシリーズ共通。資格ごとの差は accentHex と状態色（theme）で出す。
    static let ink = adaptive(light: 0x2D2618, dark: 0xF7F1E3)
    static let muted = adaptive(light: 0x6A5D45, dark: 0xCBBFA8)
    static let background = adaptive(light: 0xFFF9EB, dark: 0x1E1A14)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x2A251D)
    static let border = adaptive(light: 0xF1E3C2, dark: 0x463C2C)
    static let track = adaptive(light: 0xF6EEDC, dark: 0x3A3226)
    static let positive = adaptive(light: hex(theme?.positiveLight, fallback: 0x326D4F), dark: hex(theme?.positiveDark, fallback: 0xA0D7B5))
    static let review = adaptive(light: hex(theme?.reviewLight, fallback: 0x87592D), dark: hex(theme?.reviewDark, fallback: 0xE5BC8F))
    static let growing = adaptive(light: hex(theme?.growingLight, fallback: 0x738D80), dark: hex(theme?.growingDark, fallback: 0x7D9C8B))

    /// Brand yellow is the one primary action colour across every qualification app.
    static let piyo = adaptive(light: 0xFFC83D, dark: 0xFFC83D)
    static let piyoDeep = adaptive(light: 0xE0A100, dark: 0xA97A00)
    static let piyoTint = adaptive(light: 0xFFF1C7, dark: 0x3A3018)
    static let onPiyo = adaptive(light: 0x2D2618, dark: 0x2D2618)
    static let beak = adaptive(light: 0xFF8A3D, dark: 0xFF8A3D)
    static let beakText = adaptive(light: 0xA0560F, dark: 0xFFB27A)
    /// Answer states differ in lightness as well as hue, and always ship with a ✓ / × mark.
    static let correct = adaptive(light: 0x0B7A45, dark: 0x6FD3A0)
    static let correctTint = adaptive(light: 0xDFF6E8, dark: 0x17382A)
    static let correctText = adaptive(light: 0x0B5E36, dark: 0x9BE6BE)
    static let oops = adaptive(light: 0xC24510, dark: 0xFF9D6E)
    static let oopsTint = adaptive(light: 0xFFE6D9, dark: 0x3E2418)
    static let oopsText = adaptive(light: 0x9A3409, dark: 0xFFB894)
    static let sky = adaptive(light: 0x2F6FDB, dark: 0x8DB7FF)
    static let skyTint = adaptive(light: 0xEAF2FF, dark: 0x1C2A44)

    private static func hex(_ value: String?, fallback: Int) -> Int {
        value.flatMap { Int($0.dropFirst(), radix: 16) } ?? fallback
    }

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

extension Palette {
    /// `==mark==` in content: a confusable word the learner should notice.
    static let mark = adaptive(light: 0xC62828, dark: 0xFF8A80)
}

/// Reading text follows Dynamic Type; at the default size body is 17pt, choice reasons 15pt and notes 13pt.
/// Long text uses the system face (SF + Hiragino), headings and numbers the rounded face, code a monospaced face.
enum TextRole {
    case body, reason, note, heading, number, code

    var textStyle: Font.TextStyle {
        switch self {
        case .body, .code: .body
        case .reason: .subheadline
        case .note: .footnote
        case .heading: .headline
        case .number: .title3
        }
    }
    var font: Font {
        switch self {
        case .body, .reason, .note: .system(textStyle)
        case .heading: .system(textStyle, design: .rounded).weight(.bold)
        case .number: .system(textStyle, design: .rounded).weight(.bold).monospacedDigit()
        case .code: .system(textStyle, design: .monospaced)
        }
    }
    /// Prose lines sit about 1.6 times the font size apart; headings, numbers and code stay compact.
    var lineHeightMultiple: CGFloat {
        switch self { case .body, .reason, .note: 1.6; default: 0 }
    }
}

enum Reading {
    /// Lines longer than this tire the eye on iPad.
    static let maxWidth: CGFloat = 640
}

private struct TextRoleModifier: ViewModifier {
    let role: TextRole
    var setsFont = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if setsFont { content.font(role.font).lineSpacing(lineSpacing) } else { content.lineSpacing(lineSpacing) }
    }

    private var lineSpacing: CGFloat {
        guard role.lineHeightMultiple > 0 else { return 0 }
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let font = UIFont.preferredFont(forTextStyle: role.uiTextStyle, compatibleWith: traits)
        return max(0, font.pointSize * role.lineHeightMultiple - font.lineHeight)
    }
}

private extension TextRole {
    var uiTextStyle: UIFont.TextStyle {
        switch textStyle {
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .headline: .headline
        case .title3: .title3
        default: .body
        }
    }
}

extension View {
    func textRole(_ role: TextRole) -> some View { modifier(TextRoleModifier(role: role)) }
    /// The role's line spacing only, for text whose font the caller chooses (larger text modes).
    func readingLineSpacing(_ role: TextRole = .body) -> some View { modifier(TextRoleModifier(role: role, setsFont: false)) }
    /// Centres content and caps its width for comfortable reading on iPad.
    func readingWidth() -> some View {
        frame(maxWidth: Reading.maxWidth, alignment: .leading).frame(maxWidth: .infinity)
    }
}

struct Surface<Content: View>: View {
    var inset: CGFloat = 20
    var spacing: CGFloat = 16
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(inset)
            .popCard(radius: 24)
    }
}

extension View {
    /// Information cards: a flat bottom edge instead of an outline. Pressable controls use PuffyButtonStyle instead.
    func popCard(radius: CGFloat = 20, fill: Color = Palette.surface) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius).fill(fill)
                .shadow(color: Palette.border, radius: 0, y: 3)
        }
    }
}

/// The main call to action: sinks by its own shadow when pressed.
struct PuffyButtonStyle: ButtonStyle {
    enum Kind { case primary, correct, oops, plain }
    var kind: Kind = .primary
    var minHeight: CGFloat = 56
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = configuration.isPressed ? 0 : 5
        let colors = palette
        // Constant total height: the edge shows below the face, and the face drops onto it when pressed.
        return configuration.label
            .font(.headline)
            .foregroundStyle(colors.text)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(colors.fill, in: RoundedRectangle(cornerRadius: 18))
            .padding(.bottom, depth)
            .background(colors.edge, in: RoundedRectangle(cornerRadius: 18))
            .padding(.top, 5 - depth)
            .contentShape(Rectangle())
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var palette: (fill: Color, edge: Color, text: Color) {
        guard isEnabled else { return (Palette.track, Palette.border, Palette.muted) }
        switch kind {
        case .primary: return (Palette.piyo, Palette.piyoDeep, Palette.onPiyo)
        case .correct: return (Palette.correct, Palette.correctText, Palette.correctTint)
        case .oops: return (Palette.oops, Palette.oopsText, Palette.oopsTint)
        case .plain: return (Palette.surface, Palette.border, Palette.ink)
        }
    }
}

/// Press feedback without moving the control or its neighbours.
struct StudyButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
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

/// A shared, exhaustive partition; review flags are deliberately not extra segments.
struct MemoryBreakdown: View {
    let summary: RetentionSummary
    let identifier: String
    var compact = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MemoryBar(stable: summary.stable, growing: summary.growing, new: summary.new)
                .accessibilityHidden(true)
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
                AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                legend("定着", count: summary.stable, symbol: "checkmark.circle", color: Palette.positive)
                legend("学習中", count: summary.growing, symbol: "circle.lefthalf.filled", color: Palette.muted)
                legend("これから", count: summary.new, symbol: "circle.dashed", color: Palette.muted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("問題の学習状態")
        .accessibilityValue("定着 \(summary.stable)問、学習中 \(summary.growing)問、これから \(summary.new)問")
        .accessibilityIdentifier(identifier)
    }

    private func legend(_ title: String, count: Int, symbol: String, color: Color) -> some View {
        Group {
            if compact && !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 4) {
                    Text(title).foregroundStyle(color)
                    Text("\(count)問").fontWeight(.semibold).monospacedDigit()
                }
                .font(.caption).fixedSize(horizontal: true, vertical: false)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Label { Text(title) } icon: { Image(systemName: symbol).accessibilityHidden(true) }
                        .font(.caption).foregroundStyle(color)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(count)問").font(.subheadline.weight(.semibold).monospacedDigit())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SubjectProgress: View {
    let subject: String
    let score: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) :
                AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
            layout {
                Text(subject).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(score)%").font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
            }
            ProgressView(value: Double(score), total: 100).tint(Palette.positive).accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subject)
        .accessibilityValue("定着率 \(score)パーセント")
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

/// Shared grid density; large text keeps the same navigation in one readable column.
/// Few cards, so lay them out eagerly: off-screen cards stay reachable by VoiceOver and UI tests
/// (a LazyVGrid drops them once a header above pushes the grid below a short landscape viewport).
struct StudyGrid<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder let content: Content
    var body: some View {
        ColumnsLayout(columns: typeSize.isAccessibilitySize ? 1 : 2, spacing: 12) { content }
    }
}

/// Equal-width columns; each row is as tall as its tallest card and cards are top-aligned.
private struct ColumnsLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let rows = rowHeights(width: width, subviews: subviews)
        return CGSize(width: width, height: rows.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let column = columnWidth(bounds.width)
        var y = bounds.minY
        for (row, height) in rowHeights(width: bounds.width, subviews: subviews).enumerated() {
            for index in row * columns..<min((row + 1) * columns, subviews.count) {
                let x = bounds.minX + CGFloat(index - row * columns) * (column + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: column, height: height))
            }
            y += height + spacing
        }
    }

    private func columnWidth(_ width: CGFloat) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func rowHeights(width: CGFloat, subviews: Subviews) -> [CGFloat] {
        let proposal = ProposedViewSize(width: columnWidth(width), height: nil)
        return stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)].map { $0.sizeThatFits(proposal).height }.max() ?? 0
        }
    }
}

struct FeatureCard: View {
    let title: String
    let symbol: String
    var detail: String? = nil
    var color: Color = Palette.positive
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.title3.weight(.medium))
                .foregroundStyle(color).frame(width: 38, height: 38)
                .background(color.opacity(0.10), in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                if let detail { Text(detail).font(.caption).foregroundStyle(Palette.muted) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .popCard(radius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(detail ?? "")
    }
}

/// Counts reflect the actual bank, including partial years and locked content.
struct CollectionProgressCard: View {
    let title: String
    let questions: [Question]
    let data: StudyData
    let freeIDs: Set<String>
    let unlocked: Bool
    var compact = true
    var countLabel: String? = nil
    var now: Date = .now

    private var answered: Int { questions.filter { data.mastery[$0.id] != nil }.count }
    private var review: Int {
        questions.filter { question in
            guard let state = data.mastery[question.id] else { return false }
            return !state.lastCorrect || state.misconception || (state.dueAt.map { $0 <= now } ?? false)
        }.count
    }
    private var freeCount: Int { questions.filter { freeIDs.contains($0.id) }.count }
    private var status: String {
        if review > 0 { return "要復習 \(review)問" }
        if answered == 0 { return "未着手" }
        return answered == questions.count ? "ひと通り学習済み" : "学習中"
    }
    private var access: String {
        if unlocked { return "利用可能" }
        if freeCount == questions.count { return "無料" }
        return freeCount == 0 ? "有料" : "無料 \(freeCount)問 / 有料 \(questions.count - freeCount)問"
    }
    var body: some View {
        Surface(inset: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(title).font(compact ? .headline : .title3.bold())
                        .foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.muted).accessibilityHidden(true)
                }
                Text("\(countLabel ?? "\(questions.count)問") · \(access)").font(.caption).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: Double(answered), total: Double(max(1, questions.count)))
                    .tint(Palette.positive).accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline) {
                    Text(status).foregroundStyle(review > 0 ? Palette.review : Palette.muted)
                    Spacer(minLength: 4)
                    Text("回答 \(answered)/\(questions.count)").foregroundStyle(Palette.muted).monospacedDigit()
                }.font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: compact ? 104 : 0, alignment: .top)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)、\(countLabel ?? "\(questions.count)問")、\(access)、\(status)、回答済み \(answered)問")
    }
}

/// Fills one segment per answer. Up to 20 questions show segments; correct is yellow, a miss is orange,
/// and timed sessions pass `results: nil` so the bar never reveals correctness before grading.
struct SessionProgressBar: View {
    let total: Int
    let results: [Bool]?
    let answered: Int

    var body: some View {
        if total <= 20 {
            HStack(spacing: 4) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Capsule().fill(color(index)).frame(height: 10)
                        .overlay {
                            if index == answered && answered < total { Capsule().strokeBorder(Palette.piyo, lineWidth: 2) }
                        }
                }
            }
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    Capsule().fill(Palette.piyo)
                        .frame(width: proxy.size.width * CGFloat(min(answered, total)) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 10)
        }
    }

    private func color(_ index: Int) -> Color {
        guard index < answered else { return index == answered ? Palette.piyoTint : Palette.track }
        guard let results, index < results.count else { return Palette.piyo }
        return results[index] ? Palette.piyo : Palette.beak
    }
}

/// Feathers drift down for about a second each time `trigger` changes. Callers skip it under Reduce Motion.
struct FeatherBurst: View {
    let trigger: Int
    var count = 14
    @State private var start: Date?

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed < 1.1 else { return }
                let colors = [Palette.piyo, Palette.beak, Palette.piyoTint]
                for index in 0..<count {
                    let x = size.width * (Double(index) + 0.5) / Double(count) + sin(Double(index) * 1.7 + elapsed * 6) * 10
                    let y = -20 + elapsed * elapsed * (420 + Double(index % 4) * 70)
                    var feather = context
                    feather.opacity = max(0, 1 - elapsed / 1.1)
                    feather.translateBy(x: x, y: y)
                    feather.rotate(by: .degrees(elapsed * 280 + Double(index) * 25))
                    feather.fill(Path(roundedRect: CGRect(x: -5, y: -9, width: 10, height: 18), cornerRadius: 5),
                                 with: .color(colors[index % colors.count]))
                }
            }
        }
        .onChange(of: trigger) { start = .now }
        .accessibilityHidden(true)
    }
}

/// 画面の補足は1行までにし、それ以上の説明は (i) から開く。
struct InfoTip: View {
    let label: String
    let lines: [String]
    @State private var shown = false
    var body: some View {
        Button { shown = true } label: {
            Image(systemName: "info.circle").foregroundStyle(Palette.muted)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .popover(isPresented: $shown) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines, id: \.self) { Text($0).textRole(.reason).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(20).frame(idealWidth: 320, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
}
