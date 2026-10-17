# App Store用画像

日本語・iPhoneのみ。公式仕様確認日：2026-10-15。
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

出力はDynamic Island中型1206×2622と大型1320×2868の2種類。Apple側で選択したスロットと処理後の画像順を別途記録する。素材はXCTestから取得した実画面を全体・等比で使用。UIへの文字重ね、色加工、トリミングはなし。

再生成（Playwrightと日本語フォントが必要）：
```
SCREENSHOT_BROWSER_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' SCREENSHOT_PLAYWRIGHT_MODULE=/Users/hino/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs node .agents/skills/app-store-screenshot-designer/scripts/render.mjs docs/fundamental-information/app-store-assets/index.html docs/fundamental-information/app-store-assets/png/1320x2868 1320 2868
```
1206×2622は末尾の出力先・幅・高さを変更。既存Chromiumが見つからない場合は `SCREENSHOT_BROWSER_EXECUTABLE` で指定する。
