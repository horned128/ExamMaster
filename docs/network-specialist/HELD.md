# 公式正答と仕様の相違・調査履歴


## 現在の扱い（2026-10-11）

利用者の最新指定に従い、下記3問を**当時のIPA公式正答で採点し、回答後に仕様上の注意を説明する方針で収録**した。2015年問9＝エ、2018年問17＝ウ、2024年問22＝ア。現在は375問、該当年度も各25問・40分の公式原問順の固定模試を登録済み。

原問の技術的一意性が解決した、公式訂正が得られたという意味ではない。レビュー台帳は、この採点方針と注意点を隠さない解説に対する制作内編集レビューを記録する。現行教材と確認根拠は[今回の編集方針](review-notes/historical-answer-policy.md)を参照。

## 以下は収録前の保留・再確認の履歴

旧草稿の保存先は`archive/held-drafts/`。以下の「未収録」「固定模試未登録」「保留解除に一意性解決が必要」などの記載は当時の方針・結果であり、現在の次工程を指示するものではない。

## 2015年秋期 午前Ⅱ 問9

- 公式問題PDF5頁はIPv4からIPv6への仕様変更を問う。公式正答PDF1頁は**エ**。エには「IPレベルのセキュリティ機能（IPsec）である認証と改ざん検出機能のサポートが必須となり」とある。
- 2026-10-09，原本/正答を直接校合し，RFC4294 §8.1/8.2のIPsec/ESP/AH実装MUSTと，RFC6434（2011年12月，4294を廃止）§11/11.1の全IPv6ノードのIPsecアーキテクチャ対応SHOULDへの変更を直接確認。RFC8504（2019年1月）§13/13.1もSHOULDの推奨を維持している。
- 変更は2015年の出題より前であり，「出題時点は必須，現在だけ推奨へ変わった」という説明にはできない。原問には「旧RFC4294の要件として」の限定がないため，その限定を追加して正解根拠を作らない。実装サポートの要件と，全通信の暗号化を強制することも違う。
- 他の3肢（TOSだけで資源予約，64ビットアドレス，ヘッダチェックサム追加）はIPv6仕様と異なるが，それを消去してもエの必須記述との整合は説明できない。公式正答は変更しない。
- IPAの2015年度ページ（最終更新2016-01-08）も直接確認したが，当該NW問9の訂正は見つからなかった。最新版公式問題/正答を再取得し，問題`197b3654299e4aee98f9d8fb11fc0e4c8efef8077294d236cb96c600384c2ff3`，正答`b780523726b42ad542146c05f8fd19a3e1809c3c0098911190d9691c035a1a6e`の収集済みSHA-256と一致。検索で見つからなかったことを訂正不存在の証明としない。
- `archive/held-drafts/2015-q09.json`に未承認草稿を隔離。**同梱件数に加えず，2015年の公式固定模試も登録しない**。その他24問の制作を止めない。一次根拠/訂正等で正答根拠を適切に説明できるまで保留。

確認資料:

- https://www.rfc-editor.org/rfc/rfc4294.txt
- https://www.rfc-editor.org/rfc/rfc6434.txt
- https://www.rfc-editor.org/rfc/rfc8504.txt
- https://www.ipa.go.jp/shiken/mondai-kaiotu/2015h27.html

## 2018年秋期 午前Ⅱ 問17

- 公式問題PDF9頁「認証にクライアント証明書を用いるプロトコルはどれか。」。四肢はEAP-FAST / EAP-MD5 / EAP-TLS / EAP-TTLS，公式正答PDF1頁は**ウ（EAP-TLS）**。
- 2026-10-09に25問の原本校合後，第二段階の仕様レビューでRFC5281 §7がTTLSのphase1で任意のクライアント証明書認証を許すことを確認。§7.6（本文PDF相当17頁）も「Authentication of the client via client certificate during phase 1, with no additional authentication or information exchange required.」をphase2へ入らない例として明記している。
- EAP-TLSの証明書による相互認証はRFC5216/RFC9190から確認済みだが，それだけではエを技術的に誤りと断定できない。TTLSではクライアント証明書が必須でないことと，証明書を使えないことは違う。
- 原文に「必須」「基本」「代表的」の限定はない。その限定を推測で追加して原問の意味や誤答理由を作らない。公式正答は変更しない。
- IPAの2018年度ページも再確認。掲載更新履歴は2026年5月20日のSG春期午後の誤植訂正で，当該NW問17の訂正は見つからなかった。訂正の不在を証明したとはしない。
- 最新の公式問題/正答も再取得し，収集済みSHA-256（問題`2448a3cb987b6ea8792b4950c292cfed305fa605b0f331ca08b01391fdf9f029`，正答`ace80ab5d960f618a11720459b3779df6dbca3bf0f9b518d6881ea2f95a716fe`）と一致した。Pythonの初回取得はローカルCAの証明書検証で失敗し，検証を無効化せずシステムcurlで取得して比較した。
- 調査草稿は`archive/held-drafts/2018-q17.json`へ隔離。**未承認・アプリに未収録**。他24問を止めず制作し，2018年度は部分年度のまま固定模試を登録しない。教育品質/一意性の追加根拠が得られるまで保留する。

確認資料:

- https://www.rfc-editor.org/rfc/rfc5281.txt
- https://www.rfc-editor.org/rfc/rfc5216.txt
- https://www.rfc-editor.org/rfc/rfc9190.txt
- https://www.ipa.go.jp/shiken/mondai-kaiotu/2018h30.html

## 2024年春期 午前Ⅱ 問22

- 公式問題PDF11頁，公式正答は**ア**。原本・正答は取得済み。
- アの速度（3.0/4.0/5.0は8/16/32GT/s），後方互換性，128b/130bはPCI-SIG公開資料4頁で確認。
- ウの原文は「いずれも，規格上の最大レーン数は32レーンである。」。
- IntelのPCIe 3.0解説はリンクについて「one to 32 lanes」と記す。PCI-SIGの世代比較資料は幅x1/x2/x4/x8/x16を挙げるが，これだけではBase仕様の最大値が16である証明にならない。
- 2026-10-09にPCI-SIG公式5.0 FAQを取得。本文は「A PCIe Link consists of 1, 2, 4, 8, 12, 16, or 32 Lanes」と記し，5.0の32レーンリンクの帯域も明記している。原本PDF11頁の3.0/4.0/5.0という条件とウの文言を再確認した。一般教材だけでなく，規格団体の公開説明との整合が未解決。
- 同日，第三者公開ミラーの「PCI Express Base Specification Revision 4.0 Version 1.0（2017-09-27）」743頁，§7.5.3.6のMaximum Link Widthを確認。x1/x2/x4/x8/x12/x16/x32を定義し，他のエンコードはReservedと記す。少なくとも4.0を「最大16」と説明する根拠にはならない。ただしミラーの真正性・配布権限を独立確認できていないため，公式配布原本を確認済みとは称さず，教材にもPDFを同梱しない。
- IPAの2024年度ページと同ページの最新問題/正答PDFを再取得。両PDFのSHA-256は収集済み原本と一致し，問22の正答はアのまま。ページの更新履歴にNW午前Ⅱ問22の訂正は見つからなかった。訂正が全く存在しないことや，独自解釈でウを誤りと扱えることを証明したわけではない。
- 一般的なカード/コネクタのx16上限と，Base仕様でのリンク幅を混同し，「全世代の規格上最大は16」と断言して誤肢理由を作らない。
- 追加確認（2026-10-09）：PCI-SIG公式「What is the PCI Express (PCIe) architecture?」も1/2/4/8/12/16/32レーン構成を明記。3.0 FAQはBase（chip-to-chip）とCEM仕様を区別しており，x16帯域の比較表を規格全体の最大幅の根拠にできない。4.0 FAQは速度と互換性を説明するが，最大16という記述は見つからなかった。IPA年度ページの更新履歴と訂正の追加検索でも当該訂正を見つけられず，保留解除に足る根拠は得られなかった。検索結果の不在は訂正不存在の証明ではない。
- Base仕様・IPAの訂正情報・原設問の意図を追加確認し，公式正答と技術的な選択肢の一意性が整合するまで**アプリに未収録・レビュー未承認**。公式正答を変更せず，ウを根拠なく誤りと説明しない。2024年25問の固定模試も未登録。

確認した資料:

- https://pcisig.com/sites/default/files/files/PCIe_Specification_Webinar_Rev%206_FINAL_0.pdf
- https://www.intel.com/content/www/us/en/io/pci-express/pci-express-architecture-general.html
- https://pcisig.com/what-bit-rates-does-pcie-50-specification-support-and-how-does-it-compare-prior-pcie-generations
- https://pcisig.com/what-pci-express-pcie-architecture
- https://pcisig.com/faq?field_category_value%5B%5D=pci_express_3.0
- https://pcisig.com/faq?field_category_value%5B%5D=pci_express_4.0
- https://www.ipa.go.jp/shiken/mondai-kaiotu/2024r06.html
- 第三者ミラー（参考のみ）: https://www.pedestrian.com.cn/_downloads/d2f2495e73c44b8c3a8dfd4c399f50f0/PCIE_V4.0.pdf

## 最新指定より前の2026-10-11の公開方針と再確認

利用者は保留3問の確認を終え、375問そろえてから申請する方針を選択。未承認のまま追加したり、完成版ゲートを部分収録へ緩めたりしない。RFC6434 §11/11.1のSHOULD、RFC5281 §7.1/7.6の任意クライアント証明書認証、PCI-SIGのarchitecture説明にある32レーン構成を一次資料で再確認した。保留の理由は引き続き解消していない。この再確認をIPAからの訂正取得や専門家の承認とはしない。問題本文・正答・レビュー固定ハッシュは変更していない。
