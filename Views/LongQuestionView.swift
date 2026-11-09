import SwiftUI

/// Subject B keeps the original reading order while making prose, code and the
/// question visually distinct. The same renderer is used in the reading sheet.
struct LongQuestionBodyView: View {
    let question: Question
    var largeText = false

    private var blocks: [ContentBlock] {
        question.bodyBlocks ?? [ContentBlock(type: .text, text: question.stem)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(blocks.indices, id: \.self) { index in
                let block = blocks[index]
                VStack(alignment: .leading, spacing: 10) {
                    Label(sectionTitle(block, index: index), systemImage: symbol(block))
                        .font(.subheadline.bold()).foregroundStyle(Palette.positive)
                        .accessibilityAddTraits(.isHeader)
                    if block.type == .monospace {
                        code(block)
                    } else if block.type == .table, let rows = block.rows,
                              rows.contains(where: { $0.contains { $0.count > 40 } }) {
                        // Long case-study cells read as records, so a policy or
                        // incident description never becomes a very wide column.
                        ContentRecordTableView(headers: block.headers ?? [], rows: rows, largeText: largeText)
                    } else {
                        RichContentView(blocks: [block])
                            .font(largeText ? .title3 : .body).lineSpacing(7)
                    }
                }
                .id("reading-block-\(index)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("longQuestionBody")
    }

    private func sectionTitle(_ block: ContentBlock, index: Int) -> String {
        switch block.type {
        case .monospace: return "コード"
        case .table: return "表・条件"
        case .image: return "図・資料"
        case .formula: return "式"
        case .callout: return block.title ?? block.style?.defaultTitle ?? "補足"
        case .quiz: return "確認問題"
        case .text: return index == blocks.count - 1 && index > 0 ? "設問" : "問題文"
        }
    }

    private func symbol(_ block: ContentBlock) -> String {
        switch block.type {
        case .monospace: return "chevron.left.forwardslash.chevron.right"
        case .table: return "tablecells"
        case .image: return "doc.richtext"
        case .formula: return "function"
        case .callout: return "lightbulb"
        case .quiz: return "questionmark.circle"
        case .text: return "text.alignleft"
        }
    }

    private func code(_ block: ContentBlock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StudyCodeView(source: block.text ?? "", largeText: largeText)
            if let caption = block.caption {
                Text(caption).font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
}

/// Persistent controls prevent a long trip back through the passage after the
/// learner has reached the choices. The sheet never changes answer state.
struct LongQuestionQuickActions: View {
    let question: Question
    var largeText = false
    let jumpToChoices: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showReading = false

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Button { showReading = true } label: {
                Label("本文を別表示", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.accessibilityIdentifier("openReadingPane")
            Button(action: jumpToChoices) {
                Label("選択肢へ", systemImage: "arrow.down.to.line")
                    .frame(minHeight: 44)
            }.accessibilityIdentifier("jumpToChoices")
        }
        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
        .padding(.horizontal, 20).frame(maxWidth: 680).frame(maxWidth: .infinity)
        .background(.bar)
        .sheet(isPresented: $showReading) {
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LongQuestionBodyView(question: question, largeText: largeText)
                            .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("readingPassage")
                    .background(Palette.background)
                    .navigationTitle("問題文を読む").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("回答へ戻る") { showReading = false }
                                .accessibilityIdentifier("closeReadingPane")
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Menu {
                                Button("本文の先頭") { proxy.scrollTo("reading-block-0", anchor: .top) }
                                if let blocks = question.bodyBlocks {
                                    ForEach(blocks.indices.filter { blocks[$0].type == .monospace || blocks[$0].type == .table || blocks[$0].type == .image }, id: \.self) { index in
                                        Button("\(index + 1) · \(blocks[index].type == .monospace ? "コード" : "図・表")") {
                                            proxy.scrollTo("reading-block-\(index)", anchor: .top)
                                        }
                                    }
                                    Button("本文の末尾") { proxy.scrollTo("reading-block-\(blocks.count - 1)", anchor: .top) }
                                }
                            } label: {
                                Label("本文内を移動", systemImage: "list.bullet")
                            }.accessibilityIdentifier("readingContents")
                        }
                    }
                }
            }
            .presentationDragIndicator(.visible)
        }
    }
}
