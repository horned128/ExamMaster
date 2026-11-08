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
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(blocks.indices, id: \.self) { index in
                let block = blocks[index]
                switch block.type {
                case .text:
                    Text(block.text ?? "").fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled).accessibilityIdentifier("contentBodyText")
                case .monospace, .formula:
                    ScrollView(.horizontal) {
                        Text(block.text ?? "").font(.system(.body, design: .monospaced))
                            .textSelection(.enabled).padding(12)
                            .accessibilityIdentifier("contentCodeText")
                    }
                    .background(Palette.surface)
                    .accessibilityLabel(block.altText ?? block.text ?? "")
                    .accessibilityIdentifier(block.type == .formula ? "contentFormula" : "contentMonospace")
                    if let caption = block.caption {
                        Text(caption).font(.caption).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .image:
                    QuestionFigureView(image: block.assetName.flatMap { ContentAsset.url(name: $0) }.flatMap { UIImage(contentsOfFile: $0.path) },
                                       altText: block.altText ?? "図版", caption: block.caption)
                case .table:
                    if wrapsTables, let rows = block.rows,
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
                            Text(rows[row][column])
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
                        Text(headers[column]).font(.body.bold()).padding(12)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.track).border(Palette.border, width: 0.5)
                    }
                }
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(rows[row].indices, id: \.self) { column in
                            Text(rows[row][column]).font(.system(.body, design: .monospaced)).padding(12)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .border(Palette.border, width: 0.5)
                                .accessibilityLabel("\(headers[column]): \(rows[row][column])")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("contentTable")
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

struct QuestionExplanationView: View {
    let question: Question
    let qualification: Qualification
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("正解: \(qualification.choiceLabel(question.correctIndex))").font(.headline)
            Text(question.explanation).fixedSize(horizontal: false, vertical: true)
            if let reasons = question.choiceExplanations {
                DisclosureGroup("選択肢ごとの理由") {
                    ForEach(reasons.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 10) {
                            Label(qualification.choiceLabel(index), systemImage: index == question.correctIndex ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(index == question.correctIndex ? Palette.positive : Palette.review)
                            Text(reasons[index]).frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(.vertical, 6)
                    }
                }
            }
            if let blocks = question.explanationBlocks { RichContentView(blocks: blocks, wrapsTables: question.subject == "科目B") }
            DisclosureGroup("出典") {
                Text(qualification.displaySource(question.source)).font(.caption).foregroundStyle(Palette.muted)
                if let source = question.sourceURL, let url = URL(string: source) {
                    Link("公式の問題PDF", destination: url).frame(minHeight: 44)
                }
            }
        }
    }
}
