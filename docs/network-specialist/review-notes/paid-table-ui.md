# 150問版の有料模試・表枠回帰

2026-10-09。125問版の成功画像でCPIの長い見出しと各値のセル枠幅が一致しないことを発見。共通`QuestionContentView`の表セルへ`.frame(maxWidth: .infinity, alignment: .leading)`を追加し，既存Grid列幅へ枠を揃えた。原問，表の内容・AX見出しラベル・横スクロール・回答操作・配色は変更しない。

修正後に150問版（無料74/有料76，固定5年度）を順次テストし，結果JSONと終了コードで確認した。

| 結果 | 内訳 |
|---|---|
| `network-150-paid-dark.xcresult`：17成功，失敗0 | NW単体13，有料2019/2021/2022 UI2，最大文字構造化UI2 |
| `network-150-paid-compact.xcresult`：17成功，失敗0 | 同一範囲，375pt SE Simulator・ライト |
| `demo-150-table-regression.xcresult`：55成功，失敗0 | デモ単体54＋共通単問/保存再開UI1（全UI23件再実行ではない） |

一時領域の根は`/private/var/folders/__/d9pz1vws43n9zs95zsqwyf540000gp/T/opencode/`。ログ/summary JSONも同名で保持。

## 保存した証拠

- ダーク有料UI：`network-150-paid-dark-study-evidence/`，画像21点。
- ダーク構造化UI：`network-150-paid-dark-evidence/`，画像14点＋検査版/コントラスト添付。
- ライト有料UI：`network-150-compact-study-evidence/`，画像21点。
- ライト構造化UI：`network-150-compact-rich-evidence/`，画像14点＋検査版/コントラスト添付。
- 各`manifest.json`には元xcresult・テストID・Success・添付名・画像SHA-256を記録。デモ対象UIは保持添付なし（`demo-150-table-evidence/manifest.json`）。今回デモ実画像を確認済みとはしない。

両配色のCPI表左右端（018/019）の見出し/3行/構成比率20/20/60，2019OSPFイのx30/y30表，最大文字2024問12/2025問15の列枠と右端を実画像で目視。2019CPU/OSPFと2021最大流の拡大も確認した。表が途中で切れる左端画像は横スクロール前の状態で，右端到達は別添付とUIで確認。ダークの図拡大は局所ライト，閉鎖後は元配色という検査も成功。

有料UIは未購入拒否→開発用500円購入→図/表→保存→取引消去/再起動による再開拒否→再購入→一括採点を検査。2019は図表2問だけ回答し23問未回答，2021は5問回答/20問未回答を採点。未回答に学習Answerを作らないことは単体でも確認。

VoiceOverの実読み上げ，実機ピンチ，全教材/全肢/全画面の最大文字・横向き，Sandbox/TestFlight，本番課金価格/広告停止は別工程。この成功を全範囲の完了としない。
