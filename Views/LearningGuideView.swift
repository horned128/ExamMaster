import SwiftUI
import Charts

enum LearningGuideSection: String, CaseIterable, Identifiable {
    case overview, retrieval, spacing, feedback, metrics, practice, sources
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: "このアプリでできること"
        case .retrieval: "思い出す練習"
        case .spacing: "間隔をあける理由"
        case .feedback: "間違いから学ぶ"
        case .metrics: "指標の見方"
        case .practice: "今日からの使い方"
        case .sources: "研究と、このアプリの限界"
        }
    }
}

/// One educational destination shared by the home, records, and settings.
/// Diagrams are explicitly illustrative, not personal predictions or experimental data.
struct LearningGuideView: View {
    var stage: TankeiStage = .chick
    var initialSection: LearningGuideSection = .overview
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        introduction.id(LearningGuideSection.overview)
                        article(.retrieval, number: "01", lead: "読むだけでなく、答えを取り出す。") {
                            paragraph("解説を読むと、内容がわかったように感じます。でも、見ずに答えられるかは別のこと。記憶から答えを取り出す「想起練習」は、覚えたことを後から思い出す練習になります。")
                            RecallStepsDiagram()
                            paragraph("選択肢を見る前に、答えや理由をひとつ考えてみましょう。出てこなければ、すぐに選択肢を開いて大丈夫。長く悩むこと自体が目的ではありません。")
                            application("設定の「選択肢の前に、ひと呼吸」で、今日の学習や復習にこの一段階を入れられます。選択肢の位置ではなく、理由も思い出すのがコツ。")
                            evidence("想起練習の実験と学習法のレビューで、遅れて行うテストでの記憶保持を支える効果が報告されています。［1・2］")
                        }
                        article(.spacing, number: "02", lead: "一度に何回も、よりも別の日にもう一度。") {
                            paragraph("同じ日に繰り返すと、直前に見た答えを使いやすくなります。少し間隔をあけると、記憶からあらためて取り出す機会に。これが「分散学習」です。想起練習を別の日にも繰り返す方法は、「継続的再学習」として研究されています。")
                            SpacedMemoryDiagram()
                            PracticeDaysDiagram()
                            paragraph("最適な間隔は、内容の難しさや、いつまで覚えておきたいかで変わります。「必ず翌日・3日後・1週間後」が誰にでも最適、ということではありません。忘れきるまで待つ必要もありません。")
                            application("このアプリでは、別の日の正解で復習間隔を広げ、誤答では翌日を目安に戻します。同日の反復も記録しますが、別の日の正解としては数えません。")
                            evidence("分散学習のメタ分析と、別の日に学び直す研究を参考にしています。図の曲線や日付は研究の実測値ではありません。［1・3・4］")
                        }
                        article(.feedback, number: "03", lead: "正解を知るだけでなく、違いを説明する。") {
                            paragraph("間違えた問題は、見直す場所が見つかった問題です。答え合わせでは、正しい選択肢だけでなく「なぜ自分の答えは違ったのか」を確認すると、次の練習につなげやすくなります。")
                            VStack(alignment: .leading, spacing: 20) {
                                learningStep(1, title: "正解の理由を言ってみる", detail: "解説を閉じて、自分の言葉で一文に。計算問題なら、式を選んだ理由も確認。")
                                learningStep(2, title: "間違えた選択肢との違いを見る", detail: "条件・用語・単位など、どこで判断が変わるかを比べます。")
                                learningStep(3, title: "別の日に、もう一度答える", detail: "その場でわかったことが、後からも取り出せるかを確かめます。")
                            }
                            application("「間違えた問題」や「似た問題を比べる」で、見直したい問題に戻れます。任意の「手応え」を残すと、自信があった誤答にも気づきやすくなります。")
                            evidence("選択式テストに答え合わせを加える研究では、誤った選択肢の学習を抑える効果が報告されています。自己説明や比較の活用は、内容に応じて取り入れましょう。［1・5］")
                        }
                        metrics
                        article(.practice, number: "05", lead: "短い学習を、次の一回につなげる。") {
                            VStack(alignment: .leading, spacing: 20) {
                                learningStep(1, title: "まずは今日のノルマから", detail: "少なめなら5問、しっかりなら最大12問。同じ日に答えた問題は重複なく差し引きます。正誤に関係なく、取り組んだ分を数えます。")
                                learningStep(2, title: "答える → 解説 → 復習の目安", detail: "答えを思い出し、理由を確認。表示された復習日は予定を立てるための目安です。忙しい日は中断して、続きからでも大丈夫。")
                                learningStep(3, title: "記録で、次の課題を選ぶ", detail: "科目別の定着率で偏りを見て、回答履歴で間違いを振り返ります。仕上げには模試で時間配分と科目ごとの結果も確認。")
                            }
                            paragraph("一度正解したら終わり、ではなく、別の日に説明できるかを確認する。アプリの外でも、教科書の理解・図や手順の説明・実際の問題への応用と組み合わせましょう。")
                        }
                        sources.id(LearningGuideSection.sources)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 28)
                    .frame(maxWidth: 600).frame(maxWidth: .infinity)
                }
                .background(Palette.background)
                .onAppear { proxy.scrollTo(initialSection, anchor: .top) }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(LearningGuideSection.allCases) { section in
                                Button(section.title) {
                                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(section, anchor: .top)
                                    }
                                }
                            }
                        } label: { Label("目次", systemImage: "list.bullet") }
                        .accessibilityIdentifier("learningGuideContents")
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
                }
            }
            .navigationTitle("記憶と学習")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("覚えたつもりを、\n思い出せる力に。")
                .font(dynamicTypeSize.isAccessibilitySize ? .title.bold() : .largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            paragraph("問題を解く時間を、記憶を育てる時間へ。研究に基づく学び方と、このアプリの使い方をつなげて紹介します。")
            TankeiMoment(title: "復習は、もう一度育てる時間。", detail: "思い出せなくても大丈夫。次の練習につながります。", state: .review, stage: stage)
            VStack(alignment: .leading, spacing: 20) {
                benefit("答えを思い出す練習ができる", symbol: "bubble.left", detail: "選択肢を開く前のひと呼吸で、見覚えと理解を確かめる。")
                benefit("復習する問題を選びやすくなる", symbol: "calendar", detail: "回答履歴と復習の目安で、次に見直す場所を探す手間を減らす。")
                benefit("得意・不得意を振り返れる", symbol: "chart.bar", detail: "科目別の記録と模試で、学習の偏りや次の課題を見つける。")
            }
            note("学習を支えるための設計です。このアプリ自体の学習効果や合格率の向上を、比較実験で実証したものではありません。")
        }
    }

    private var metrics: some View {
        article(.metrics, number: "04", lead: "数字は成績表ではなく、次の学習の手がかり。") {
            paragraph("定着率・学習準備度・復習日は、それぞれ違うものを見ています。値を上げることだけを目的にせず、どの問題を学ぶかの参考にしてください。")
            Surface {
                Text("定着・学習中・これから").font(.headline).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("guideMemoryHeading")
                Text("例：利用できる12問を3つに分類").font(.footnote).foregroundStyle(Palette.muted)
                MemoryBar(stable: 4, growing: 6, new: 2)
                definition("定着 · 4問", detail: "別の日に3回以上正解し、記憶が安定していると判定した問題。")
                definition("学習中 · 6問", detail: "回答済みで、まだ定着の条件を満たしていない問題。間違えた問題もここに含みます。")
                definition("これから · 2問", detail: "まだ回答していない問題。")
                Divider()
                Text("この例の定着率は、4 ÷ 12 = 33%").font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                note("3区分は重ならず、合計が利用できる問題数になります。「復習」「誤解の見直し」は別の分類で、件数が重なることがあります。")
                DisclosureGroup("定着の判定を詳しく見る") {
                    VStack(alignment: .leading, spacing: 12) {
                        paragraph("① 異なる日に3回以上正解\n② 計算上の記憶の安定期間が7日以上\n③ 推定保持率が0.75以上\n④ 誤解のフラグがない")
                            .accessibilityIdentifier("guideMasteryCriteria")
                        note("すべてを満たすと「定着」です。7日は実際に7日待ったという意味ではなく、回答から更新する内部の安定期間。同じ日の正解だけでは①を増やしません。")
                    }.padding(.top, 12)
                }
            }
            definition("定着率：利用できる問題のうち、定着した割合", detail: "無料利用中は無料問題だけ、解放後は全問題が対象です。時間が経ったり誤答したりすると下がることもあります。学びが無駄になった、という意味ではありません。")
            definition("学習準備度：問題集全体を見た総合目安", detail: "学習範囲、記憶の目安、弱い科目、最近の回答、模試を組み合わせた100点の独自スコアです。無料利用中も問題集全体を評価するので、定着率とは分母も意味も違います。")
            DisclosureGroup("準備度の内訳を詳しく見る") {
                VStack(alignment: .leading, spacing: 20) {
                    ReadinessWeightsDiagram()
                    note("最近の回答は14日以内の、問題ごとの最新回答。模試は最新の結果を使い、90日で影響がなくなるよう重みを減らします。未受験なら模試の要素は0です。")
                    note("記憶の目安は、回答日時・別の日の正解・難易度などから推定。学習範囲は正解した割合ではなく、回答した範囲です。科目平均と弱い科目も考慮します。")
                }.padding(.top, 16)
            }
            definition("復習日：もう一度出会うための目安", detail: "正誤や別の日の正解に応じて更新します。日付を過ぎても失敗ではありません。今できる範囲から、続きの一回を。")
            note("定着の区切りや準備度の配点は、このアプリ独自のルールです。研究で定められた共通基準・実測の記憶確率・合格確率ではありません。")
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            Text(LearningGuideSection.sources.title).font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("guideSourcesHeading")
            paragraph("研究が支持する学習の考え方と、アプリの独自計算は別のものです。教材・年齢・試験形式などで効果は異なり、誰にでも同じ成果を約束するものではありません。")
            reference(1, title: "学習法の総合レビュー", citation: "Dunlosky ほか（2013）", detail: "練習テストと分散学習を、幅広い条件で有用な方法として評価。", url: "https://www.psychologicalscience.org/publications/journals/pspi/learning-techniques.html")
            reference(2, title: "思い出す練習と長期の記憶", citation: "Roediger & Karpicke（2006）", detail: "文章を学ぶ実験で、読み直しと想起練習を比較。直後の出来と、後日の記憶は同じではないことを示す。", url: "https://doi.org/10.1111/j.1467-9280.2006.01693.x")
            reference(3, title: "間隔をあけた学習のメタ分析", citation: "Cepeda ほか（2006）", detail: "317実験・839件の評価をまとめ、学習間隔と保持したい期間の関係を検討。", url: "https://doi.org/10.1037/0033-2909.132.3.354")
            reference(4, title: "別の日に学び直す効果", citation: "Rawson & Dunlosky（2018）", detail: "想起練習を複数の学習日に行う、継続的再学習と長期保持を検討。", url: "https://pubmed.ncbi.nlm.nih.gov/29431462/")
            reference(5, title: "選択式テストと答え合わせ", citation: "Butler & Roediger（2008）", detail: "フィードバックが、選択式テストの利点と誤選択肢の学習に及ぼす影響を検討。", url: "https://doi.org/10.3758/MC.36.3.604")
            note("リンク先は外部の研究情報です。英語のページや、本文の閲覧に購読が必要な場合があります。説明はオフラインでも読めます。")
            Text("このアプリだけでは測れないこと").font(.headline).accessibilityAddTraits(.isHeader)
            paragraph("実際の理解の深さ、初めて見る問題への応用、当日の緊張や時間配分までは、普段の回答履歴だけでは測れません。選択肢を覚えて正解することもあります。理由を説明する練習や、時間を測った模試と組み合わせてください。")
            paragraph("復習の計算は、研究を参考にした保守的な推定です。個人ごとの最適な間隔を実証したものでも、医療的な記憶評価でもありません。")
        }
    }

    private func article<Content: View>(_ section: LearningGuideSection, number: String, lead: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            Text("\(number)  /  \(section.title)").font(.footnote.weight(.semibold)).foregroundStyle(Palette.positive)
            Text(lead).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("guide-\(section.rawValue)")
            content()
        }.id(section)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text).font(.body).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(Palette.muted).lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func definition(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
            paragraph(detail)
        }
    }

    private func benefit(_ title: String, symbol: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Palette.positive)
                .frame(width: 28).accessibilityHidden(true)
            definition(title, detail: detail)
        }
    }

    private func learningStep(_ number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.body.bold().monospacedDigit()).foregroundStyle(Palette.positive)
                .frame(minWidth: 28).accessibilityHidden(true)
            definition(title, detail: detail)
        }
    }

    private func application(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("このアプリでは").font(.footnote.weight(.semibold)).foregroundStyle(Palette.positive)
            paragraph(text)
        }
        .padding(.leading, 16)
        .overlay(alignment: .leading) { Rectangle().fill(Palette.positive).frame(width: 3).accessibilityHidden(true) }
    }

    private func evidence(_ text: String) -> some View { note(text) }

    private func reference(_ number: Int, title: String, citation: String, detail: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: url)!) {
                Text("［\(number)］\(title) ↗").font(.headline).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.accessibilityHint("外部の研究情報を開きます")
                .accessibilityIdentifier("guideResearch-\(number)")
            Text(citation).font(.footnote.weight(.medium)).foregroundStyle(Palette.muted)
            paragraph(detail)
        }
    }
}

private struct RecallStepsDiagram: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let steps = ["読む", "隠す", "思い出す", "答え合わせ"]

    var body: some View {
        Surface {
            Text("一問の中に、思い出す時間を。").font(.headline)
            if dynamicTypeSize.isAccessibilitySize {
                verticalSteps
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        ForEach(steps.indices, id: \.self) { index in
                            Text(steps[index]).font(.body.weight(.semibold)).fixedSize()
                            if index < steps.count - 1 { Image(systemName: "arrow.right").font(.caption) }
                        }
                    }
                    verticalSteps
                }
            }
            Text("見てわかる → 見ずに取り出せる、を確かめる。").font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("想起練習の流れ")
        .accessibilityValue("読む、隠す、思い出す、答え合わせ。見ずに取り出せるかを確かめます。")
        .accessibilityIdentifier("guideRecallFlow")
    }

    private var verticalSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(steps.indices, id: \.self) { index in
                Text("\(index + 1). \(steps[index])").font(.body.weight(.semibold))
            }
        }
    }
}

private struct SpacedMemoryDiagram: View {
    @State private var compare = true

    var body: some View {
        Surface {
            Text("復習で、思い出すきっかけを増やす").font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("guideMemoryDiagramTitle")
            Text("思い出しやすさ · 模式図").font(.footnote).foregroundStyle(Palette.muted)
            Chart {
                ForEach(0...60, id: \.self) { index in
                    let time = Double(index) / 6
                    LineMark(x: .value("時間", time), y: .value("イメージ", exp(-time / 2)), series: .value("学び方", "復習なし"))
                        .foregroundStyle(Palette.muted).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                if compare {
                    ForEach(0...60, id: \.self) { index in
                        let time = Double(index) / 6
                        let latest = time >= 6 ? 6.0 : time >= 3 ? 3.0 : 0.0
                        let stability = time >= 6 ? 8.0 : time >= 3 ? 4.0 : 2.0
                        LineMark(x: .value("時間", time), y: .value("イメージ", exp(-(time - latest) / stability)), series: .value("学び方", "復習あり"))
                            .foregroundStyle(Palette.positive).lineStyle(StrokeStyle(lineWidth: 3))
                    }
                    ForEach([3.0, 6.0], id: \.self) { time in
                        RuleMark(x: .value("復習", time)).foregroundStyle(Palette.positive.opacity(0.3))
                        PointMark(x: .value("復習", time), y: .value("イメージ", 1.0))
                            .foregroundStyle(Palette.positive).symbol(.circle)
                    }
                }
            }
            .chartXScale(domain: 0...10).chartYScale(domain: 0...1.05)
            .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
            .frame(height: 180).accessibilityHidden(true)
            HStack {
                Text("学習したとき")
                Spacer()
                Text("時間の経過 →")
            }.font(.footnote).foregroundStyle(Palette.muted)
            VStack(alignment: .leading, spacing: 8) {
                Label("破線：復習しない場合", systemImage: "line.diagonal").foregroundStyle(Palette.muted)
                if compare { Label("実線と丸：間隔をあけて復習", systemImage: "circle.fill").foregroundStyle(Palette.positive) }
            }.font(.footnote)
            Toggle("復習した場合と比べる", isOn: $compare).font(.body)
                .accessibilityIdentifier("guideMemoryCompare")
            Text("時間とともに取り出しにくくなり、復習であらためて取り出す。間隔をあけた練習を重ねるイメージです。")
                .font(.body).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            Text("個人の記憶の予測・実験結果ではありません。目盛りや復習点は説明のための仮の配置です。")
                .font(.footnote).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PracticeDaysDiagram: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("4回の練習を、どう分ける？").font(.headline)
            schedule("同じ日にまとめる", days: [4, 0, 0, 0])
            schedule("別の日にも取り出す", days: [1, 1, 1, 1])
            Text("同じ4回でも、別の日に答える機会を作る。日付・回数は説明用の例で、おすすめ日程ではありません。")
                .font(.footnote).foregroundStyle(Palette.muted).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func schedule(_ title: String, days: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.body.weight(.medium))
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
                AnyLayout(HStackLayout(alignment: .top, spacing: 8))
            layout {
                ForEach(days.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(index == 0 ? "今日" : "別の日\(index)").font(.footnote)
                        HStack(spacing: 4) {
                            ForEach(0..<max(1, days[index]), id: \.self) { _ in
                                Circle().fill(days[index] > 0 ? Palette.positive : Palette.track).frame(width: 12, height: 12)
                            }
                        }.frame(height: 16)
                        Text("\(days[index])回").font(.footnote.monospacedDigit()).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(title)
        .accessibilityValue(days[0] == 4 ? "今日に4回。別の日の練習なし。" : "今日と、異なる3日にそれぞれ1回。合計4回。")
    }
}

private struct ReadinessWeightsDiagram: View {
    private let weights: [(title: String, weight: Int)] = [
        ("学習した範囲", 20), ("科目ごとの記憶の目安の平均", 34),
        ("もっとも弱い科目の記憶の目安", 14), ("最近の回答の正答率", 12), ("模試の正答率と新しさ", 20)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("100点をつくる5つの要素").font(.headline)
                .accessibilityIdentifier("guideReadinessWeights")
            Text("棒の長さは配点。あなたの現在の点数ではありません。")
                .font(.footnote).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            ForEach(weights.indices, id: \.self) { index in
                let item = weights[index]
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(item.title) · \(item.weight)点分").font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: Double(item.weight), total: 100).tint(Palette.positive).accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore).accessibilityLabel(item.title)
                .accessibilityValue("100点のうち\(item.weight)点分")
            }
        }
    }
}
