import SwiftUI
import UIKit

struct QuestionBodyView: View {
    let question: Question
    var largeText = false
    var body: some View {
        if question.subject == "科目B" {
            LongQuestionBodyView(question: question, largeText: largeText)
        } else if let blocks = question.bodyBlocks {
            RichContentView(blocks: blocks).font(largeText ? .title3 : .body)
        } else {
            Text(question.stem).font(largeText ? .title2.weight(.semibold) : .title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let image = question.imageName {
                QuestionFigureView(image: UIImage(named: image), altText: "問題図版", caption: nil)
            }
        }
    }
}

struct RichContentView: View {
    let blocks: [ContentBlock]
    var wrapsTables = false
    /// Two-column tables (term ⇔ point) read as a list so long Japanese text wraps; used by the textbook.
    var definitionTables = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(blocks.indices, id: \.self) { index in
                let block = blocks[index]
                switch block.type {
                case .text:
                    MarkupText(text: block.text ?? "")
                case .monospace, .formula:
                    ScrollView(.horizontal) {
                        Text(block.text ?? "").font(TextRole.code.font)
                            .textSelection(.enabled).padding(12)
                            .accessibilityIdentifier("contentCodeText")
                    }
                    .background(Palette.surface)
                    .accessibilityLabel(block.altText ?? block.text ?? "")
                    .accessibilityIdentifier(block.type == .formula ? "contentFormula" : "contentMonospace")
                    if let caption = block.caption {
                        Text(caption).textRole(.note).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .image:
                    QuestionFigureView(image: block.assetName.flatMap { ContentAsset.url(name: $0) }.flatMap { UIImage(contentsOfFile: $0.path) },
                                       altText: block.altText ?? "図版", caption: block.caption)
                case .callout:
                    CalloutView(style: block.style ?? .exam, title: block.title, text: block.text ?? "")
                case .quiz:
                    QuizBlockView(question: block.text ?? "", answer: block.answer ?? "")
                case .table:
                    if definitionTables, let headers = block.headers, headers.count == 2, let rows = block.rows {
                        ContentDefinitionTableView(headers: headers, rows: rows)
                    } else if wrapsTables, let rows = block.rows,
                       rows.contains(where: { $0.contains { $0.count > 18 } }) {
                        ContentRecordTableView(headers: block.headers ?? [], rows: rows)
                    } else {
                        ContentTableView(headers: block.headers ?? [], rows: block.rows ?? [])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Text with the InlineMarkup subset. The font comes from the caller so larger text modes still apply.
struct MarkupText: View {
    let text: String
    var role: TextRole = .body
    var setsFont = false

    var body: some View {
        let lines = InlineMarkup.parse(text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines.indices, id: \.self) { index in
                switch lines[index] {
                case .paragraph(let runs):
                    line(runs)
                case .bullet(let runs):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").accessibilityHidden(true)
                        line(runs)
                    }
                }
            }
        }
        .modifier(MarkupTextRole(role: role, setsFont: setsFont))
    }

    private func line(_ runs: [InlineMarkup.Run]) -> some View {
        Text(Self.attributed(runs))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityIdentifier("contentBodyText")
    }

    /// A table cell: inline markup only, no bullets.
    static func cell(_ text: String) -> AttributedString { attributed(InlineMarkup.runs(text)) }

    static func attributed(_ runs: [InlineMarkup.Run]) -> AttributedString {
        runs.reduce(into: AttributedString()) { result, run in
            var part = AttributedString(run.text)
            // Marked words are bold as well as red so the cue does not rely on colour alone.
            if run.bold || run.marked { part.inlinePresentationIntent = .stronglyEmphasized }
            if run.marked { part.foregroundColor = Palette.mark }
            if let link = run.link {
                part.link = link
                part.underlineStyle = .single
            }
            result += part
        }
    }
}

private struct MarkupTextRole: ViewModifier {
    let role: TextRole
    let setsFont: Bool
    func body(content: Content) -> some View {
        if setsFont { content.textRole(role) } else { content.readingLineSpacing(role) }
    }
}

/// Long sentences read vertically, with the original column names on each item.
struct ContentRecordTableView: View {
    let headers: [String]
    let rows: [[String]]
    var largeText = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rows.indices, id: \.self) { row in
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows[row].indices, id: \.self) { column in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(headers.indices.contains(column) ? headers[column] : "項目\(column + 1)")
                                .font(.caption.bold()).foregroundStyle(Palette.muted)
                            Text(MarkupText.cell(rows[row][column]))
                                .font(largeText ? .title3 : .body).lineSpacing(7)
                                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("readableCaseTable")
    }
}

private struct ContentTableView: View {
    let headers: [String]
    let rows: [[String]]
    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(headers.indices, id: \.self) { column in
                        Text(MarkupText.cell(headers[column])).font(.body.bold()).padding(12)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.track).border(Palette.border, width: 0.5)
                    }
                }
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(rows[row].indices, id: \.self) { column in
                            Text(MarkupText.cell(rows[row][column])).font(.system(.body, design: .monospaced)).padding(12)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .border(Palette.border, width: 0.5)
                                .accessibilityLabel("\(InlineMarkup.plainText(headers[column])): \(InlineMarkup.plainText(rows[row][column]))")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("contentTable")
    }
}

/// 用語 ⇔ 要点 tables: the term on its own line, the point wrapping under it.
struct ContentDefinitionTableView: View {
    let headers: [String]
    let rows: [[String]]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(MarkupText.cell(headers[0])).font(.subheadline.bold()).foregroundStyle(Palette.muted)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.track)
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text(MarkupText.cell(row.first ?? "")).font(.body.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    if row.count > 1 {
                        Text(MarkupText.cell(row[1])).textRole(.reason)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                if index < rows.count - 1 { Divider().padding(.leading, 14) }
            }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
        .accessibilityIdentifier("definitionTable")
    }
}

/// 試験に出る・組込みでは・物理的には・よくある誤解
struct CalloutView: View {
    let style: ContentBlock.CalloutStyle
    var title: String? = nil
    let text: String

    private var color: Color {
        switch style {
        case .exam: Palette.beakText
        case .practice: Palette.positive
        case .physical: Palette.sky
        case .caution: Palette.mark
        }
    }
    private var tint: Color {
        switch style {
        case .exam: Palette.piyoTint
        case .practice: Palette.correctTint
        case .physical: Palette.skyTint
        case .caution: Palette.oopsTint
        }
    }
    private var symbol: String {
        switch style {
        case .exam: "pencil.line"
        case .practice: "cpu"
        case .physical: "bolt"
        case .caution: "exclamationmark.triangle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title ?? style.defaultTitle, systemImage: symbol)
                .font(.subheadline.bold()).foregroundStyle(color)
            MarkupText(text: text, role: .reason, setsFont: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12).fill(color).frame(width: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("callout-\(style.rawValue)")
    }
}

/// 確認問題: the answer stays hidden until the reader has thought about it.
struct QuizBlockView: View {
    let question: String
    let answer: String
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { open.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "questionmark.circle.fill").foregroundStyle(Palette.sky)
                        .accessibilityHidden(true)
                    Text(MarkupText.cell(question)).textRole(.body).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0))
                        .foregroundStyle(Palette.muted).accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(open ? "答えを隠す" : "答えを見る")
            .accessibilityIdentifier("textbookQuiz")
            if open {
                Divider()
                MarkupText(text: answer, role: .reason, setsFont: true)
                    .transition(.opacity)
                    .accessibilityIdentifier("textbookQuizAnswer")
            }
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
    }
}

struct QuestionFigureView: View {
    let image: UIImage?
    let altText: String
    let caption: String?
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image {
                Button { expanded = true } label: {
                    Image(uiImage: image).resizable().scaledToFit()
                        .padding(8).frame(maxWidth: .infinity, minHeight: 44)
                        .background(.white).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(altText)
                .accessibilityHint("タップして拡大。拡大画面でピンチとスクロールができます")
                .accessibilityIdentifier("questionFigure")
                Label(caption ?? "タップして拡大", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption).foregroundStyle(Palette.muted)
            } else {
                Label("図版を読み込めません", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Palette.review)
            }
        }
        .sheet(isPresented: $expanded) {
            if let image { FigureZoomView(image: image, altText: altText) }
        }
    }
}

private struct FigureZoomView: View {
    let image: UIImage
    let altText: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    var body: some View {
        NavigationStack {
            ZoomableFigure(image: image, scale: $scale).background(.white)
                .accessibilityLabel(altText)
                .accessibilityAction(named: "拡大") { scale = min(8, scale * 2) }
                .accessibilityAction(named: "縮小") { scale = max(1, scale / 2) }
                .navigationTitle("図を拡大").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("縮小", systemImage: "minus.magnifyingglass") { scale = max(1, scale / 2) }
                        Button("全体表示") { scale = 1 }
                        Button("拡大", systemImage: "plus.magnifyingglass") { scale = min(8, scale * 2) }
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
                }
        }
        // Theme only the figure and its toolbars. A preferredColorScheme in a
        // nested sheet can change the presenting exam's appearance on iOS 26.
        .environment(\.colorScheme, .light)
        .toolbarColorScheme(.light, for: .navigationBar, .bottomBar)
    }
}

private struct ZoomableFigure: UIViewRepresentable {
    let image: UIImage
    @Binding var scale: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(scale: $scale) }
    func makeUIView(context: Context) -> FigureScrollView {
        let view = FigureScrollView()
        view.imageView.image = image
        view.delegate = context.coordinator
        view.minimumZoomScale = 1
        view.maximumZoomScale = 8
        view.backgroundColor = .white
        return view
    }
    func updateUIView(_ view: FigureScrollView, context: Context) {
        context.coordinator.scale = $scale
        if abs(view.zoomScale - scale) > 0.01 { view.setZoomScale(scale, animated: false) }
    }
    class Coordinator: NSObject, UIScrollViewDelegate {
        var scale: Binding<CGFloat>
        init(scale: Binding<CGFloat>) { self.scale = scale }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? FigureScrollView)?.imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? FigureScrollView)?.centerImage()
        }
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale value: CGFloat) { scale.wrappedValue = value }
    }
}

private final class FigureScrollView: UIScrollView {
    let imageView = UIImageView()
    private var previousSize = CGSize.zero
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        bouncesZoom = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != previousSize, bounds.width > 0, let image = imageView.image {
            previousSize = bounds.size
            setZoomScale(1, animated: false)
            let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
            imageView.frame = CGRect(origin: .zero, size: CGSize(width: image.size.width * fit, height: image.size.height * fit))
            contentSize = imageView.frame.size
        }
        centerImage()
    }
    func centerImage() {
        let horizontal = max(0, (bounds.width - contentSize.width) / 2)
        let vertical = max(0, (bounds.height - contentSize.height) / 2)
        let next = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        if contentInset != next { contentInset = next }
    }
}

/// The explanation below the choices: why the answer is right, then one closed line per supplement.
struct QuestionExplanationView: View {
    let question: Question
    let qualification: Qualification
    /// Off where each choice already shows its own reason (the question screen).
    var listsChoiceReasons = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            QuestionWhyView(question: question, qualification: qualification)
            if listsChoiceReasons, let reasons = question.choiceExplanations {
                ChoiceReasonList(question: question, qualification: qualification, reasons: reasons)
            }
            QuestionSupplementsView(question: question, qualification: qualification)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 「なぜ正解か」: the explanation text, its figures and tables, then the solving steps.
struct QuestionWhyView: View {
    let question: Question
    let qualification: Qualification

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("なぜ「\(qualification.choiceLabel(question.correctIndex))」が正解か")
                .textRole(.heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("whyCorrectHeading")
            if !question.explanation.isEmpty { MarkupText(text: question.explanation) }
            if let blocks = question.explanationBlocks { RichContentView(blocks: blocks, wrapsTables: question.subject == "科目B") }
            if let steps = question.steps, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("解き方").textRole(.heading).foregroundStyle(Palette.muted)
                    ForEach(steps.indices, id: \.self) { step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(step + 1)").textRole(.number).font(.subheadline.weight(.heavy))
                                .foregroundStyle(Palette.piyoDeep)
                                .accessibilityHidden(true)
                            MarkupText(text: steps[step], role: .reason, setsFont: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .accessibilityIdentifier("solutionSteps")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard(radius: 20)
    }
}

/// Reasons for every choice, for screens that list the choices without them.
struct ChoiceReasonList: View {
    let question: Question
    let qualification: Qualification
    let reasons: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(reasons.indices, id: \.self) { index in
                let correct = index == question.correctIndex
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(qualification.choiceLabel(index)) \(correct ? "○" : "×")")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(correct ? Palette.correctText : Palette.oopsText)
                    MarkupText(text: reasons[index], role: .reason, setsFont: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("choiceReasons")
    }
}

/// 関連知識・用語メモ・参考資料 as closed one-line rows, then the official PDF when there is one.
struct QuestionSupplementsView: View {
    let question: Question
    let qualification: Qualification

    private var glossaryTerms: [GlossaryTerm] {
        guard let ids = question.glossaryTermIDs, !ids.isEmpty else { return [] }
        return Glossary.main?.terms(ids: ids) ?? []
    }

    var body: some View {
        let terms = glossaryTerms
        VStack(alignment: .leading, spacing: 0) {
            if let related = question.related {
                SupplementRow(title: "関連知識", symbol: "lightbulb") {
                    RichContentView(blocks: related)
                }
                .accessibilityIdentifier("relatedKnowledge")
            }
            if !terms.isEmpty {
                SupplementRow(title: "用語メモ", symbol: "character.book.closed") {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(terms) { term in GlossaryTermRow(term: term) }
                    }
                }
                .accessibilityIdentifier("glossaryMemo")
            }
            if let references = question.references { QuestionReferencesView(references: references) }
            if let source = question.sourceURL, let url = URL(string: source) {
                Link(destination: url) {
                    Label("公式の問題PDF", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .textRole(.reason)
            }
        }
    }
}

/// A closed one-line disclosure used for each supplement under the explanation.
struct SupplementRow<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $expanded) {
                content.padding(.top, 8).padding(.bottom, 12)
            } label: {
                Label(title, systemImage: symbol).textRole(.heading)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .tint(Palette.ink)
            Divider()
        }
    }
}

struct GlossaryTermRow: View {
    let term: GlossaryTerm
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term.term).font(.body.bold())
            if let english = term.english, !english.isEmpty {
                Text(english).textRole(.note).foregroundStyle(Palette.muted)
            }
            MarkupText(text: term.description, role: .reason, setsFont: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 参考資料: web sources open in the browser; textbook links are handled by the app.
struct QuestionReferencesView: View {
    let references: [QuestionReference]
    var body: some View {
        SupplementRow(title: "参考資料", symbol: "books.vertical") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(references, id: \.self) { reference in
                    if let text = reference.url, let url = URL(string: text) {
                        Link(destination: url) {
                            Label(reference.title, systemImage: url.scheme == "https" ? "arrow.up.right.square" : "book")
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    } else {
                        Text(reference.title).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            }
            .textRole(.reason)
        }
        .accessibilityIdentifier("questionReferences")
    }
}
