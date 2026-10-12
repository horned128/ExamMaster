#!/bin/bash
# Captures real NW screens with XCTest; no screenshot compositing or uploads.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_device="${1:?Usage: bash tools/release/screenshots.sh <large-iPhone-Simulator-UDID> /absolute/new/output-directory}"
task_output="${2:?撮影結果の保存先を指定してください。}"
case "$task_output" in /*) ;; *) echo '保存先は絶対パスを指定してください。' >&2; exit 2;; esac
if [ -e "$task_output" ]; then echo '新しい保存先を指定してください。' >&2; exit 2; fi
mkdir -p "$task_output"
cd "$task_root"
xcodebuild -project ExamMaster.xcodeproj -scheme NetworkSpecialist \
  -destination "platform=iOS Simulator,id=$task_device" -parallel-testing-enabled NO \
  -derivedDataPath "$task_output/DerivedData" -resultBundlePath "$task_output/ui.xcresult" \
  -only-testing:NetworkSpecialistUITests/NetworkStudyUITests/testHomeExamDateIsVisibleAndPersists \
  -only-testing:NetworkSpecialistUITests/NetworkStudyUITests/testRedesignedYearGridAndSubjectHierarchy \
  -only-testing:NetworkSpecialistUITests/NetworkStudyUITests/test2026PredictionLocksAndStartsOriginalFixedMock \
  test CODE_SIGNING_ALLOWED=NO > "$task_output/ui.log" 2>&1
xcrun xcresulttool export attachments --path "$task_output/ui.xcresult" --output-path "$task_output/images"
echo "撮影完了: $task_output/images（公式サイズ・最終教材・正式表示名・画像の目視確認後に申請へ使用）"
