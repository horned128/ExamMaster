# Quality verification

Verified: 2026-10-14

## Output checks

- Six upload-ready files exist in `png/1320x2868/`, named `01.png` through `06.png`.
- Every PNG is exactly 1320 × 2868 pixels, RGB, with no alpha channel.
- The contact sheet is 1124 × 1674 pixels and shows the six screenshots in order.
- Each source image in `assets/source/` has the same SHA-256 as the original simulator capture.
- The displayed UI region is 1120 × 2435 pixels. Automated image comparison confirms it is exactly the source PNG resized uniformly with Lanczos; it has no crop, overlay, recoloring, or retouching.
- All six headline strings fit within the 1128-pixel text column. At 25% preview scale the headline type is 17.5 px. Each panel and the contact sheet were visually inspected at full and overview sizes.
- Contrast between the main ink and panel backgrounds ranges from 11.5:1 to 12.1:1. The smallest accent copy is 4.69:1 or higher after the color revision.
- Claim checks: 1,520 historical questions (2016 spring–2025 autumn), 2026 forecast questions, 160 free questions, 1,760 total questions, and the ¥300 one-time unlock match the current app/release data.
- No account name, email, user-entered information, or other personal data appears in the selected screens.
- The AP question-bank validator passed (`releaseReady: true`), all 32 AP Python tests passed, all 31 mascot source assets passed verification, and SubmitDock passed its required local release checks against the updated six-image manifest.

## Apple specification check

Apple's official screenshot specification lists 1320 × 2868 portrait for the large iPhone Dynamic Island display class, accepts PNG, limits each device-size set to 10 screenshots, and says consistent UI may be scaled down for smaller sizes. These six files meet that image-size/format/count check. Final App Store Connect validation still depends on the target device-size slot and the app's current support configuration.

Source: [Apple App Store Connect — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/) (checked 2026-10-14).

## Design review

UI/UX Pro Max was invoked to derive an educational-app hierarchy and visual direction. The final system uses a distinct cream/blue-green surround so the AP listing does not repeat the lavender interface or another qualification's base colors. Impeccable was not installed locally; its headline, spacing, contrast, fidelity, and claim-alignment review was performed manually and recorded in `design-direction.md`.

The supplied Playwright renderer could not launch Chrome in this host (Chrome exited with `SIGABRT`). PNG export was completed with the included local Pillow renderer, which reads the panel copy and image paths from `index.html` and layout/color tokens from `styles.css`. `render.py` can reproduce the six PNGs and contact sheet on macOS with Pillow and Hiragino Sans.
