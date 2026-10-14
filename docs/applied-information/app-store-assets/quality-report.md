# Quality verification

Verified: 2026-10-14

## Export checks

- Six upload-ready PNGs exist at `png/1320x2868/01.png` through `06.png`; every image is exactly 1320 × 2868 px, RGB, and has no alpha channel.
- The contact sheet is 1124 × 1674 px and places the six screenshots in order.
- All headline text fits the 1128 px copy column. At 25% scale, the 70 px headline is 17.5 px. Full set preview was inspected.
- Main-ink/background contrast is 11.55:1 or higher; accent/background contrast is 4.69:1 or higher.
- Pixel comparison confirms that each app-screen region is the corresponding source image, uniformly resized with Lanczos. No crop, overlay, recoloring, retouch, or text over the app UI was detected.
- The first three source captures are authentic iPhone 17 Pro Max simulator UI-test attachments. The subcategory screen is scrolled so all five choices are visible above the tab bar. The question, explanation, and unlock sources are existing simulator captures. They are preserved in `assets/source/`.
- The selected screens contain no account name, email, or user-entered personal information.

## Claim checks

- The research panel describes retrieval practice and spaced review, which are implemented in the guide and practice flow. The app itself explicitly disclaims experimental proof of its own learning effect or any pass-rate increase. The listing copy uses “参考にした” and does not promise a result.
- The graph screen shows six selectable technology themes with question and learned counts; each link opens the corresponding topic. The following actual screen shows a second subcategory level.
- The question screen uses selectable text. The explanation screen includes the answer rationale and individual choice explanations.
- The purchase screen shows 160 free questions, a ¥300 one-time unlock, no ads after purchase, and the 1,760-question total (1,520 official past questions plus 240 forecast questions).
- The paper framing is supported by the app's cited learning-technique review and primary studies: [Dunlosky et al. (2013)](https://doi.org/10.1177/1529100612453266), [Roediger & Karpicke (2006)](https://pubmed.ncbi.nlm.nih.gov/16507066/), and [Cepeda et al. (2006)](https://pubmed.ncbi.nlm.nih.gov/16719566/).

## Functional verification

- Two targeted iPhone 17 Pro Max simulator UI tests passed with zero failures: the research-based learning guide and the topic-map → subcategory → question-list navigation. These tests produced the new guide and graph source captures.
- The AP bank validator reported `releaseReady: true`, all 32 AP Python tests passed, and the screenshot export check above passed.
- SubmitDock's required local release checks passed earlier against this six-image manifest; the large-display PNG size and format are unchanged.
- App Store Connect's Japanese large Dynamic Island iPhone slot shows the six screenshots in 01–06 order (6/10). The final subcategory screenshot is selected; the version has not been submitted for review.

## Apple specification and design critique

Apple's official screenshot specification accepts 1320 × 2868 portrait PNGs for the large iPhone Dynamic Island display class and allows up to 10 screenshots per size. The six exported files meet those dimensions and format. Final App Store Connect acceptance still depends on the selected device-size slot and app support configuration. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/) (checked 2026-10-14).

UI/UX Pro Max was used to establish an educational hierarchy and a palette distinct from the lavender app UI. Impeccable was not installed locally, so a manual critique checked hierarchy, copy length, contrast, image fidelity, and claim alignment; the limitation is recorded in `design-direction.md`.
