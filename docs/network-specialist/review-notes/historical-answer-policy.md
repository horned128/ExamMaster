# 当時の公式正答による採点・3問の収録

2026-10-11、利用者の「未完成の問題3問とも、当時の答えで問題を作って回答後の説明でその旨を説明しておけばいい」という指定に従って収録。原問とIPA公式正答を保持し、回答後の解説冒頭に「当時の公式正答で採点します」と表示する。通常演習の答え合わせと、模試終了後の問題別解説の両方で表示される。

| 問題 | 公式正答・本アプリの採点 | 回答後に伝える注意点 |
|---|---|---|
| 2015年秋期 午前Ⅱ 問9 | エ | IPsec対応のSHOULDへの変更は2011年で、出題年より前。「当時は必須、現在だけ推奨」と説明しない。実装サポートと全通信の暗号化も区別する。 |
| 2018年秋期 午前Ⅱ 問17 | ウ（EAP-TLS） | EAP-TTLSも任意のクライアント証明書認証を利用できる。「証明書を使えない」という誤答理由を作らない。 |
| 2024年春期 午前Ⅱ 問22 | ア | 3.0/4.0/5.0の8/16/32GT/sは確認済み。PCI-SIGも32レーン構成を説明しているため、ウの理由として規格全体を最大16レーンと断定しない。 |

3問の技術的一意性が解決した、IPAが訂正した、独立専門家が承認したという扱いにはしない。従前の調査経緯は[HELD.md](../HELD.md)、旧未承認草稿は`../archive/held-drafts/`に保存。今回の第二段階の承認は、上記の採点方針と、仕様上の注意を隠さない解説に対する制作内AI編集レビューである。

## 確認した原本と仕様

第一段階では、保存済み公式問題PDFの画像5/9/11頁と全四肢を再校合。正答PDFからエ／ウ／アを照合した。原本のSHA-256は`sources.json`の記録と教材検証で一致する。

第二段階では、本文解説・全肢理由・解き方を別観点で確認。原問にない「旧要件に限る」「必須」「代表的」などの限定を問題文に追加せず、技術的に否定できない肢を否定した解説にしない。注意は回答後の本文に常時表示し、折りたたみを開く操作には依存しない。

- [IPA 2015年問題・正答](https://www.ipa.go.jp/shiken/mondai-kaiotu/2015h27.html)、[2018年](https://www.ipa.go.jp/shiken/mondai-kaiotu/2018h30.html)、[2024年](https://www.ipa.go.jp/shiken/mondai-kaiotu/2024r06.html)。
- [RFC4294 §8](https://www.rfc-editor.org/rfc/rfc4294.html#section-8)、[RFC6434 §11/11.1](https://www.rfc-editor.org/rfc/rfc6434.html#section-11)、[RFC8504 §13/13.1](https://www.rfc-editor.org/rfc/rfc8504.html#section-13)。
- [RFC5281 §7.1](https://www.rfc-editor.org/rfc/rfc5281.html#section-7.1)、[§7.6](https://www.rfc-editor.org/rfc/rfc5281.html#section-7.6)、[RFC5216](https://www.rfc-editor.org/rfc/rfc5216.html)、[RFC9190](https://www.rfc-editor.org/rfc/rfc9190.html)。
- [PCI-SIG 5.0転送レートとリンク幅](https://pcisig.com/what-bit-rates-does-pcie-50-specification-support-and-how-does-it-compare-prior-pcie-generations)、[architecture](https://pcisig.com/what-pci-express-pcie-architecture)、[世代比較資料4頁](https://pcisig.com/sites/default/files/files/PCIe_Specification_Webinar_Rev%206_FINAL_0.pdf)。

## 教材への反映

編集元の2015/2018/2024へ各1問を追加し、原問順の各25問・40分固定模試を登録。15原稿すべてのisDraftをfalseにした。同梱375問＝過去問300＋予想75、無料75＝2023〜2025の全問、有料300＝他の過去問225＋予想75。

追加前の372問・12固定模試、既存レビュー、373件の固定ハッシュ（アプリから外した2010問23を含む）は一致を確認。追加3問だけ新しいレビュー固定ハッシュを作成し、生成器・公式正答照合・図版SHA-256・固定模試の25問構成のチェックを通した。完成版ゲートを緩和する変更はない。

教材の完成と、App Storeの公開設定・実機検証の完了は別。最新の確認結果は[STATUS.md](../STATUS.md)と[公開準備](../../release/README.md)を参照。
