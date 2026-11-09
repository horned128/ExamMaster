import SwiftUI

/// 全体図: zones of layer rows, each row a wrap of term chips, then the journeys.
struct LayerMapView: View {
    let map: LayerMap

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let intro = map.intro {
                    RichContentView(blocks: intro).textRole(.reason).foregroundStyle(Palette.muted)
                }
                ForEach(map.zones) { zone in
                    Text(zone.name).font(.headline).fontDesign(.rounded)
                        .foregroundStyle(Palette.accent(zone.colorHex))
                        .padding(.top, 6)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(zone.rows, id: \.self) { rowID in
                        if let row = map.row(rowID) { LayerRowCard(row: row, chips: map.chips(in: row.id)) }
                    }
                }
                let cross = map.rows.filter { $0.crossCutting == true }
                if !cross.isEmpty {
                    Text("どの階層にもまたがる分野").font(.headline).fontDesign(.rounded)
                        .foregroundStyle(Palette.muted).padding(.top, 6)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(cross) { row in LayerRowCard(row: row, chips: map.chips(in: row.id)) }
                }
                if !map.journeys.isEmpty {
                    Text("旅：階層をまたいで追う").font(.headline).fontDesign(.rounded).padding(.top, 6)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(map.journeys) { journey in
                        NavigationLink(value: TextbookRoute.journey(journey.id)) {
                            FeatureCard(title: journey.title, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                                        detail: "\(journey.steps.count)ステップ", color: Palette.sky)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("journey-\(journey.id)")
                    }
                }
            }
            .padding(20)
            .readingWidth()
        }
        .background(Palette.background)
        .navigationTitle(map.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LayerRowCard: View {
    let row: LayerMap.Row
    let chips: [LayerMap.Chip]

    var body: some View {
        let color = Palette.accent(row.colorHex)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name).font(.subheadline.bold()).foregroundStyle(Palette.ink)
                    Text(row.example).textRole(.note).foregroundStyle(Palette.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("layerRow-\(row.id)")
            FlowLayout(spacing: 8, lineSpacing: 0) {
                ForEach(chips) { chip in
                    NavigationLink(value: TextbookRoute.chip(chip.id)) {
                        LayerChipLabel(chip: chip, color: color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chip-\(chip.id)")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard(radius: 18)
    }
}

/// Chips with exam questions are solid; the rest are dashed, as on the web page.
struct LayerChipLabel: View {
    let chip: LayerMap.Chip
    let color: Color
    var body: some View {
        let practised = !(chip.questionIDs ?? []).isEmpty
        Text(chip.term)
            .font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(color.opacity(practised ? 0.18 : 0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: practised ? [] : [3, 2])))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityHint(practised ? "関連問題あり" : "")
    }
}

struct LayerChipView: View {
    let map: LayerMap
    let chip: LayerMap.Chip
    let context: TextbookContext

    var body: some View {
        let row = map.row(chip.row)
        let journeys = map.journeys.filter { $0.steps.contains { $0.chipIDs?.contains(chip.id) == true } }
        let ids = (chip.questionIDs ?? []) + context.backlinks.ids(chapter: LayerMap.chapterID, section: chip.id)
        let questions = context.questions(ids: ids.reduce(into: []) { if !$0.contains($1) { $0.append($1) } })
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if let row {
                        Text(row.name).font(.caption.bold()).foregroundStyle(Palette.accent(row.colorHex))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Palette.accent(row.colorHex).opacity(0.12), in: Capsule())
                    }
                    Text(chip.term).font(.title2.bold()).fontDesign(.rounded)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                MarkupText(text: chip.description, role: .body, setsFont: true)
                if let exam = chip.exam { CalloutView(style: .exam, text: exam) }
                if let link = chip.textbook, let url = URL(string: link) {
                    Link(destination: url) {
                        Label("教科書で詳しく読む", systemImage: "book").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("chipTextbookLink")
                }
                if !journeys.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(journeys) { journey in
                            NavigationLink(value: TextbookRoute.journey(journey.id)) {
                                Label(journey.title, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                        }
                    }
                }
                if !questions.isEmpty && context.canSolve {
                    RelatedQuestionList(questions: questions, context: context)
                }
            }
            .padding(20)
            .readingWidth()
        }
        .background(Palette.background)
        .navigationTitle(chip.term)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A journey as a timeline: each step names the layer it happens in, then 物理的には with the timing charts.
struct LayerJourneyView: View {
    let map: LayerMap
    let journey: LayerMap.Journey

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(journey.title).font(.title2.bold()).fontDesign(.rounded)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                MarkupText(text: journey.intro, role: .body, setsFont: true)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(journey.steps.indices, id: \.self) { index in
                        JourneyStepRow(map: map, step: journey.steps[index],
                                       previousRow: index > 0 ? journey.steps[index - 1].row : nil,
                                       isLast: index == journey.steps.count - 1)
                    }
                }
                if let physical = journey.physical, !physical.isEmpty {
                    SupplementRow(title: "物理的には", symbol: "bolt") {
                        RichContentView(blocks: physical, definitionTables: true).textRole(.body)
                    }
                    .accessibilityIdentifier("journeyPhysical")
                }
            }
            .padding(20)
            .readingWidth()
        }
        .background(Palette.background)
        .navigationTitle("全体図")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct JourneyStepRow: View {
    let map: LayerMap
    let step: LayerMap.Step
    let previousRow: String?
    let isLast: Bool

    var body: some View {
        let row = map.row(step.row)
        let color = row.map { Palette.accent($0.colorHex) } ?? Palette.muted
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle().fill(color).frame(width: 14, height: 14).padding(.top, 4)
                if !isLast { Rectangle().fill(Palette.border).frame(width: 2).frame(maxHeight: .infinity) }
            }
            .frame(width: 14)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                if let row, row.id != previousRow {
                    Text(row.name).font(.caption.bold()).foregroundStyle(color)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(color.opacity(0.12), in: Capsule())
                }
                Text(step.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                MarkupText(text: step.text, role: .reason, setsFont: true)
                let chips = (step.chipIDs ?? []).compactMap(map.chip)
                if !chips.isEmpty {
                    FlowLayout(spacing: 6, lineSpacing: 0) {
                        ForEach(chips) { chip in
                            NavigationLink(value: TextbookRoute.chip(chip.id)) {
                                LayerChipLabel(chip: chip, color: map.row(chip.row).map { Palette.accent($0.colorHex) } ?? color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
}

/// Lays children out left to right and wraps to the next line when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    /// Between lines; chips already pad themselves to a 44pt tap target.
    var lineSpacing: CGFloat? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(width: bounds.width, subviews: subviews)
        for (index, frame) in layout.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(ProposedViewSize(width: width.isFinite ? width : nil, height: nil))
            size.width = min(size.width, width)
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + (lineSpacing ?? spacing)
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (frames, CGSize(width: maxX, height: y + lineHeight))
    }
}
