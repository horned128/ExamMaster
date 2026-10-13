import Foundation

enum ReviewStatus: String, Hashable {
    case stable, due, risk, new, misconception
}

enum QuestionCollectionRoute: Hashable {
    case all, year(Int), mockSet(String), subject(String), category(String), subjectCategory(String, String), subjectTopic(String, String), subjectSubtopic(String, String, String), status(ReviewStatus), incorrect, favorites

    var title: String {
        switch self {
        case .all: "すべての問題"
        case .year(let year): "\(year)年の問題"
        case .mockSet: "予想問題"
        case .subject(let subject): subject
        case .category(let category), .subjectCategory(_, let category), .subjectTopic(_, let category): category
        case .subjectSubtopic(_, _, let subtopic): subtopic
        case .status(.stable): "定着した問題"
        case .status(.due): "今の復習"
        case .status(.risk): "思い出しておきたい問題"
        case .status(.new): "これからの問題"
        case .status(.misconception): "勘違いをほどく"
        case .incorrect: "苦手問題"
        case .favorites: "ブックマーク"
        }
    }

    var studyMode: StudyMode {
        switch self {
        case .year, .mockSet: .year
        case .incorrect: .incorrect
        case .favorites: .bookmarked
        case .status(.due), .status(.risk), .status(.misconception), .status(.stable): .recommended
        case .all, .subject, .category, .subjectCategory, .subjectTopic, .subjectSubtopic, .status(.new): .subject
        }
    }
}

/// Presentation of existing due dates; never changes the scheduling model.
/// Only available questions are counted, so the home action matches the displayed count.
struct ReviewOutlook {
    let dueCount: Int
    let nextDate: Date?
    let nextCount: Int

    init(questions: [Question], data: StudyData, now: Date = .now, calendar: Calendar = .current) {
        let dates = questions.compactMap { data.mastery[$0.id]?.dueAt }
        dueCount = dates.filter { $0 <= now }.count
        let next = dates.filter { $0 > now }.min()
        nextDate = next
        nextCount = next.map { date in dates.filter { $0 > now && calendar.isDate($0, inSameDayAs: date) }.count } ?? 0
    }

    static func label(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if date <= now { return "今" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "今日中"
        case 1: return "明日"
        case 2: return "明後日"
        default: return date.formatted(.dateTime.month().day())
        }
    }
}

enum QuestionCollections {
    static func questions(for route: QuestionCollectionRoute, catalog: Catalog, data: StudyData,
                          now: Date = .now) -> [Question] {
        let questions = catalog.questions
        let mastery = data.mastery
        let indexed = Dictionary(uniqueKeysWithValues: questions.enumerated().map { ($0.element.id, $0.offset) })
        let sourceOrder: (Question, Question) -> Bool = { (indexed[$0.id] ?? 0) < (indexed[$1.id] ?? 0) }
        switch route {
        case .mockSet(let id):
            guard let set = catalog.mockSets.first(where: { $0.id == id }) else { return [] }
            let byID = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
            return set.questionIDs.compactMap { byID[$0] }
        case .year(let year):
            return questions.filter { $0.year == year }.sorted { a, b in
                let aNumber = a.questionNumber ?? inferredNumber(a.source)
                let bNumber = b.questionNumber ?? inferredNumber(b.source)
                return aNumber == bNumber ? sourceOrder(a, b) : aNumber < bNumber
            }
        case .subject(let subject):
            return newestFirst(questions.filter { $0.subject == subject }, sourceOrder: sourceOrder)
        case .category(let category):
            return newestFirst(questions.filter { $0.category == category }, sourceOrder: sourceOrder)
        case .subjectCategory(let subject, let category):
            return newestFirst(questions.filter { $0.subject == subject && $0.category == category }, sourceOrder: sourceOrder)
        case .subjectTopic(let subject, let title):
            return newestFirst(StudyTopic.grouped(subject: subject, questions: questions).first { $0.title == title }?.questions ?? [], sourceOrder: sourceOrder)
        case .subjectSubtopic(let subject, let topicTitle, let subtopicTitle):
            let topic = StudyTopic.grouped(subject: subject, questions: questions).first { $0.title == topicTitle }
            let selected = topic.flatMap { topic in
                StudySubtopic.grouped(topic: topic).first { $0.title == subtopicTitle }?.questions
            } ?? []
            return newestFirst(selected, sourceOrder: sourceOrder)
        case .all:
            return newestFirst(questions, sourceOrder: sourceOrder)
        case .incorrect:
            return questions.filter { mastery[$0.id]?.lastCorrect == false }
                .sorted { (mastery[$0.id]?.lastAnswered ?? .distantFuture) < (mastery[$1.id]?.lastAnswered ?? .distantFuture) }
        case .favorites:
            return newestFirst(questions.filter { data.bookmarks.contains($0.id) }, sourceOrder: sourceOrder)
        case .status(let status):
            let selected = questions.filter { question in
                guard let state = mastery[question.id] else { return status == .new }
                switch status {
                case .stable: return MasteryEngine.isMastered(state, now: now)
                case .due: return state.dueAt.map { $0 <= now } ?? false
                case .risk:
                    return state.lastCorrect && !MasteryEngine.isMastered(state, now: now) &&
                        MasteryEngine.retention(state, now: now) < 0.8
                case .new: return false
                case .misconception: return state.misconception
                }
            }
            return selected.sorted { a, b in
                if status == .due { return (mastery[a.id]?.dueAt ?? .distantFuture) < (mastery[b.id]?.dueAt ?? .distantFuture) }
                if status == .risk || status == .stable {
                    let lhs = mastery[a.id].map { MasteryEngine.retention($0, now: now) } ?? 0
                    let rhs = mastery[b.id].map { MasteryEngine.retention($0, now: now) } ?? 0
                    if lhs != rhs { return lhs < rhs }
                }
                return sourceOrder(a, b)
            }
        }
    }

    private static func newestFirst(_ questions: [Question], sourceOrder: (Question, Question) -> Bool) -> [Question] {
        questions.sorted { a, b in a.year == b.year ? sourceOrder(a, b) : a.year > b.year }
    }

    private static func inferredNumber(_ source: String) -> Int {
        guard let range = source.range(of: "問[0-9]+", options: .regularExpression) else { return Int.max }
        return Int(source[range].dropFirst()) ?? Int.max
    }


}

/// Broader learning themes keep sparse source categories useful without changing question metadata.
struct StudyTopic: Identifiable {
    let title: String
    let questions: [Question]
    var id: String { title }

    static func grouped(subject: String, questions: [Question]) -> [Self] {
        let items = questions.filter { $0.subject == subject }
        let grouped = Dictionary(grouping: items, by: { theme(subject: subject, category: $0.category) })
        return grouped.keys.sorted().map { Self(title: $0, questions: grouped[$0] ?? []) }
    }

    private static func theme(subject: String, category: String) -> String {
        let rules: [(String, [String])]
        switch subject {
        case "テクノロジ": rules = [
            ("理論・アルゴリズム", ["基礎", "アルゴリズム", "データ構造"]),
            ("システム・クラウド", ["コンピュータ", "システム構成", "OS", "クラウド"]),
            ("ネットワーク", ["ネットワーク"]),
            ("セキュリティ", ["セキュリティ"]),
            ("データベース", ["データベース"]),
            ("開発・データ分析", ["開発", "AI", "データ分析"])
        ]
        case "マネジメント": rules = [
            ("プロジェクト管理", ["プロジェクト"]),
            ("サービス管理", ["サービス"]),
            ("システム監査", ["監査"])
        ]
        case "ストラテジ": rules = [
            ("会計・財務", ["会計", "財務"]),
            ("法務", ["法務"]),
            ("システム戦略・企画", ["システム戦略", "システム企画", "業務システム"]),
            ("経営戦略・企業活動", ["経営", "企業", "技術戦略"])
        ]
        case "ネットワーク": rules = [
            ("IP・アドレス設計", ["ARP", "RARP", "IPアドレス", "IPv", "サブネット", "CIDR", "VLSM", "ホスト部", "ICMP", "DHCP"]),
            ("経路制御・冗長化", ["BGP", "OSPF", "RIP", "経路", "ルーティング", "STP", "スパニング", "冗長", "MPLS", "SDN", "アグリゲーション"]),
            ("アプリケーション通信", ["DNS", "ドメイン", "HTTP", "Web", "URL", "FTP", "SMTP", "メール", "MIME", "LDAP", "認証", "VPN", "IPsec"]),
            ("無線・伝送媒体", ["無線", "IoT", "5G", "光通信", "PLC", "ケーブル", "配線", "物理接続"]),
            ("性能・運用設計", ["QoS", "RSVP", "予約", "容量", "トラフィック", "呼量", "音声", "最大流", "管理", "送信間隔", "ビット誤り"])
        ]
        case "セキュリティ": rules = [
            ("認証・暗号", ["802.1X", "RADIUS", "SAML", "TLS", "証明", "認証", "鍵", "暗号", "MAC", "IPsec", "WPA", "HSTS"]),
            ("メール・DNS対策", ["メール", "OP25B", "DNS"]),
            ("攻撃・脆弱性", ["攻撃", "注入", "脆弱", "Cookie", "妨害", "NTP", "偽装"]),
            ("検知・対応", ["マルウェア", "検知", "CSIRT", "インシデント", "フォレンジック", "観測"])
        ]
        case "コンピュータシステム": rules = [
            ("CPU・メモリ", ["CPU", "メモリ", "記憶", "割込み", "量子", "パイプライン"]),
            ("性能・待ち行列", ["待ち行列", "時間", "アムダール", "並列", "タイムアウト"]),
            ("信頼性・保守", ["信頼性", "保守", "冗長", "RAID"])
        ]
        case "システム開発技術": rules = [
            ("設計・モデリング", ["SOA", "UML", "モデリング", "アーキテクチャ", "is-a", "Web"]),
            ("テスト・品質", ["テスト", "信頼性", "安全性", "使用性", "エラー"]),
            ("開発・保守", ["開発", "XP", "保守", "リファクタリング", "リバース"])
        ]
        default: return category
        }
        for (title, words) in rules where words.contains(where: { category.localizedCaseInsensitiveContains($0) }) { return title }
        switch subject {
        case "テクノロジ": return "開発・データ分析"
        case "マネジメント": return "プロジェクト管理"
        case "ストラテジ": return "経営戦略・企業活動"
        case "ネットワーク": return "通信の基礎・プロトコル"
        case "セキュリティ": return "防御・可用性"
        case "コンピュータシステム": return "システム構成・運用"
        default: return "権利・管理"
        }
    }
}

/// Stable second-level browse groups. Fine-grained concepts are used as hints,
/// then normalized into a small, curated set of labels under each map theme.
struct StudySubtopic: Identifiable {
    let title: String
    let questions: [Question]
    var id: String { title }

    private struct Rule {
        let title: String
        let keywords: [String]
    }

    static let unreviewedTitle = "2015年以前・詳細分類なし"

    static func grouped(topic: StudyTopic) -> [Self] {
        let rules = rulesByTopic[topic.title] ?? []
        var grouped: [String: [Question]] = [:]
        for question in topic.questions {
            let title = subtopic(for: question, rules: rules)
            grouped[title, default: []].append(question)
        }
        let orderedTitles = rules.map(\.title) + [unreviewedTitle, "その他"]
        return orderedTitles.compactMap { title in
            guard let questions = grouped[title], !questions.isEmpty else { return nil }
            return Self(title: title, questions: questions)
        }
    }

    private static func subtopic(for question: Question, rules: [Rule]) -> String {
        // Old image-only questions have no reviewed concept labels. Keep them
        // visible without presenting OCR-derived guesses as confirmed topics.
        if question.kind == .past && question.choiceExplanations?.count != question.choices.count {
            return unreviewedTitle
        }
        let labels = (question.concepts + question.tags + [question.category])
            .filter { $0 != question.subject }
        let searchable = labels.joined(separator: " ").lowercased()
        for rule in rules where rule.keywords.contains(where: { searchable.contains($0.lowercased()) }) {
            return rule.title
        }
        return "その他"
    }

    private static let rulesByTopic: [String: [Rule]] = [
        "理論・アルゴリズム": [
            Rule(title: "論理・数値表現", keywords: ["論理", "カルノー", "2進", "16進", "数値表現", "数値誤差", "浮動小数", "補数", "回路", "ブール"]),
            Rule(title: "アルゴリズム・データ構造", keywords: ["アルゴリズム", "探索", "ソート", "スタック", "キュー", "リスト", "木構造", "二分木", "2分木", "配列", "ハッシュ", "AVL", "グラフ", "再帰", "線形リスト"]),
            Rule(title: "確率・情報理論", keywords: ["確率", "統計", "標本", "情報量", "符号化", "エントロピー", "データ圧縮", "誤り検出", "モンテカルロ", "情報理論"])
        ],
        "システム・クラウド": [
            Rule(title: "CPU・ハードウェア", keywords: ["CPU", "プロセッサ", "命令", "パイプライン", "半導体", "GPU", "割込み", "DMA", "FPGA", "ハードウェア", "PWM"]),
            Rule(title: "メモリ・記憶装置", keywords: ["メモリ", "記憶", "キャッシュ", "RAID", "SSD", "ディスク", "主記憶", "補助記憶", "DRAM", "仮想記憶"]),
            Rule(title: "OS・システム構成", keywords: ["OS", "オペレーティングシステム", "プロセス", "ジョブ", "スケジューリング", "システム構成", "仮想化", "コンテナ", "クライアントサーバ", "クラウド", "サーバ統合", "分散処理"]),
            Rule(title: "性能・信頼性", keywords: ["性能", "稼働率", "信頼性", "待ち行列", "冗長", "MTBF", "MTTR", "アムダール", "可用性", "ボトルネック", "処理能力"])
        ],
        "ネットワーク": [
            Rule(title: "プロトコル・アドレス", keywords: ["IPアドレス", "IPv", "TCP", "UDP", "DNS", "DHCP", "HTTP", "LAN", "ARP", "OSI", "SMTP", "FTP", "ICMP", "NAT", "NAPT", "VLAN", "サブネット", "CIDR", "プロトコル", "Ethernet", "イーサネット"]),
            Rule(title: "経路制御・ネットワーク機器", keywords: ["ルータ", "ルーティング", "BGP", "OSPF", "RIP", "スイッチ", "STP", "経路制御", "経路選択", "冗長化", "ゲートウェイ", "MPLS", "SDN", "ネットワーク機器"]),
            Rule(title: "無線・伝送", keywords: ["無線", "Wi-Fi", "光通信", "ケーブル", "伝送", "変調", "CSMA", "無線LAN", "ビット誤り"]),
            Rule(title: "通信性能・運用", keywords: ["QoS", "帯域", "通信速度", "遅延", "トラフィック", "回線", "容量", "運用", "負荷", "通信性能", "呼量"])
        ],
        "セキュリティ": [
            Rule(title: "認証・アクセス制御", keywords: ["認証", "アクセス制御", "パスワード", "SSO", "SAML", "多要素", "権限", "ID管理", "生体", "RADIUS", "802.1X"]),
            Rule(title: "暗号・署名・証明書", keywords: ["暗号", "鍵", "署名", "証明書", "PKI", "ハッシュ", "TLS", "電子署名", "共通鍵", "公開鍵", "ディジタル署名"]),
            Rule(title: "攻撃・脆弱性", keywords: ["攻撃", "脆弱", "XSS", "SQLインジェクション", "CSRF", "マルウェア", "ランサム", "DoS", "改ざん", "盗聴", "偽装", "ボット", "バックドア"]),
            Rule(title: "管理・運用・インシデント", keywords: ["管理", "リスク", "ISMS", "CSIRT", "インシデント", "監査", "運用", "ファイアウォール", "WAF", "セキュリティ対策", "情報セキュリティ"])
        ],
        "データベース": [
            Rule(title: "データモデル・設計", keywords: ["E-R", "ERモデル", "正規化", "テーブル設計", "外部キー", "概念データ", "関係モデル", "データモデル", "スキーマ", "データベース設計"]),
            Rule(title: "SQL・データ操作", keywords: ["SQL", "問合せ", "クエリ", "ビュー", "結合", "集計", "データ操作", "select", "トリガ", "索引"]),
            Rule(title: "トランザクション・DBMS", keywords: ["トランザクション", "ACID", "排他", "ロック", "チェックポイント", "DBMS", "デッドロック", "コミット", "ロールバック"]),
            Rule(title: "分散データ・分析", keywords: ["分散", "NoSQL", "データウェアハウス", "ビッグデータ", "データ分析", "データマイニング", "レプリケーション"])
        ],
        "開発・データ分析": [
            Rule(title: "要件・設計・モデリング", keywords: ["要件", "要求", "設計", "UML", "モデリング", "アーキテクチャ", "SOA", "オブジェクト指向", "デザインパターン", "クラス図", "シーケンス図"]),
            Rule(title: "開発手法・実装", keywords: ["開発手法", "アジャイル", "XP", "スクラム", "DevOps", "CI/CD", "プログラミング", "実装", "コーディング", "ソフトウェア開発"]),
            Rule(title: "テスト・品質・保守", keywords: ["テスト", "品質", "保守", "レビュー", "リファクタリング", "障害", "品質保証", "バグ", "信頼性"]),
            Rule(title: "AI・データ分析", keywords: ["AI", "人工知能", "機械学習", "学習", "データ分析", "データマイニング", "回帰分析", "ニューラル", "クラスタリング", "ビッグデータ"]),
            Rule(title: "組込み・UI・マルチメディア", keywords: ["組込み", "センサ", "制御", "マルチメディア", "画像", "音声", "ヒューマンインタフェース", "ユーザインタフェース", "グラフィックス", "RFID"])
        ],
        "プロジェクト管理": [
            Rule(title: "計画・スコープ・WBS", keywords: ["WBS", "スコープ", "計画", "PMBOK", "要件", "成果物", "ステークホルダー", "プロジェクトマネジメント"]),
            Rule(title: "進捗・スケジュール・EVM", keywords: ["EVM", "CPI", "SPI", "PV", "EV", "AC", "予算", "見積", "進捗", "クリティカルパス", "工程", "工数", "スケジュール", "コスト", "クラッシング"]),
            Rule(title: "リスク・品質・チーム", keywords: ["リスク", "品質", "要員", "調達", "契約", "変更", "コンフリクト", "人的資源", "体制", "コミュニケーション", "チーム"])
        ],
        "サービス管理": [
            Rule(title: "インシデント・問題・変更", keywords: ["インシデント", "問題管理", "変更管理", "構成管理", "リリース管理", "サービスデスク"]),
            Rule(title: "SLA・容量・サービス水準", keywords: ["SLA", "サービスレベル", "容量", "能力管理", "課金", "サービス水準"]),
            Rule(title: "可用性・継続・運用", keywords: ["可用性", "継続", "RTO", "RPO", "バックアップ", "災害", "運用", "ITIL", "サービスマネジメント", "復旧"])
        ],
        "システム監査": [
            Rule(title: "監査計画・実施・証拠", keywords: ["監査計画", "監査手続", "監査証拠", "サンプリング", "ウォークスルー", "監査調書", "監査報告", "監査の実施"]),
            Rule(title: "統制・独立性・フォロー", keywords: ["統制", "独立", "フォローアップ", "監査人", "ガバナンス", "情報セキュリティ監査", "監査基準", "監査の独立性"])
        ],
        "経営戦略・企業活動": [
            Rule(title: "経営・競争戦略", keywords: ["SWOT", "PPM", "コアコンピタンス", "競争", "経営戦略", "M&A", "バランススコアカード", "バリューチェーン"]),
            Rule(title: "マーケティング・顧客", keywords: ["マーケティング", "CRM", "顧客", "4P", "4C", "市場", "ブランド", "セグメンテーション"]),
            Rule(title: "生産・物流・品質", keywords: ["SCM", "生産", "在庫", "品質", "物流", "MRP", "EOQ", "QC", "TQM", "調達"]),
            Rule(title: "企業活動・組織", keywords: ["企業活動", "組織", "人事", "労働", "リーダー", "コンピテンシー", "ファシリテーション", "コーポレート"])
        ],
        "会計・財務": [
            Rule(title: "会計・財務諸表", keywords: ["財務諸表", "財務会計", "会計", "利益", "原価", "損益", "貸借対照表", "キャッシュフロー"]),
            Rule(title: "投資評価・経営指標", keywords: ["NPV", "IRR", "投資", "回収", "ROE", "ROA", "ROI", "損益分岐点", "投資評価", "費用対効果"])
        ],
        "法務": [
            Rule(title: "知的財産", keywords: ["著作", "特許", "商標", "知的財産", "不正競争", "ライセンス"]),
            Rule(title: "契約・調達・取引", keywords: ["契約", "委託", "請負", "派遣", "取適法", "下請", "調達", "電子署名法"]),
            Rule(title: "個人情報・労務・法令", keywords: ["個人情報", "労働", "法律", "法", "プライバシー", "独禁", "マイナンバー", "コンプライアンス"])
        ],
        "システム戦略・企画": [
            Rule(title: "業務分析・改善", keywords: ["BPR", "業務分析", "ECRS", "BABOK", "業務プロセス", "業務改善", "要求定義"]),
            Rule(title: "システム企画・調達", keywords: ["システム企画", "システム化", "要件", "RFP", "調達", "提案依頼", "ベンダ"]),
            Rule(title: "IT戦略・投資・全体構想", keywords: ["IT戦略", "IT投資", "EA", "ERP", "CRM", "SCM", "CIO", "アーキテクチャ", "投資評価"])
        ]
    ]
}

enum QuizLevel {
    static func questions(level: Int, catalog: Catalog, unlocked: Bool) -> [Question] {
        SessionPlanner.available(catalog, unlocked: unlocked).filter { $0.difficulty == level }
    }
    static func title(_ level: Int) -> String {
        switch level { case 1: "入門"; case 2: "基本"; case 3: "応用"; case 4: "発展"; default: "挑戦" }
    }
}
