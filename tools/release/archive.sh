#!/bin/bash
# Signed NW archive -> exported IPA. Runs local gates before doing distribution work.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="${1:?Usage: bash tools/release/archive.sh /absolute/new/output-directory}"
case "$task_output" in /*) ;; *) echo '保存先は絶対パスを指定してください。' >&2; exit 2;; esac
if [ -e "$task_output" ]; then echo '既存の保存先を上書きしません。新しい保存先を指定してください。' >&2; exit 2; fi
task_python="$task_root/.venv-network/bin/python"
if [ ! -x "$task_python" ]; then echo '.venv-networkの制作ツール依存を先に準備してください。' >&2; exit 2; fi
mkdir -p "$task_output"
cd "$task_root"
"$task_python" tools/release/preflight.py --report "$task_output/preflight.json"
xcodebuild -project ExamMaster.xcodeproj -scheme NetworkSpecialist -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$task_output/NetworkSpecialist.xcarchive" \
  -derivedDataPath "$task_output/DerivedData" -allowProvisioningUpdates archive CODE_SIGN_STYLE=Automatic \
  > "$task_output/archive.log" 2>&1
"$task_python" tools/release/validate_distribution.py \
  --app "$task_output/NetworkSpecialist.xcarchive/Products/Applications/NetworkSpecialist.app" \
  --report "$task_output/archive-privacy-check.json"
"$task_python" - "$task_output" <<'PY'
import plistlib
import sys
from pathlib import Path
output = Path(sys.argv[1])
archive = plistlib.loads((output / 'NetworkSpecialist.xcarchive/Info.plist').read_bytes())
team = archive['ApplicationProperties']['Team']
options = {'method': 'app-store-connect', 'destination': 'export', 'teamID': team,
           'signingStyle': 'automatic', 'manageAppVersionAndBuildNumber': False,
           'stripSwiftSymbols': True, 'uploadSymbols': True}
(output / 'ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
xcodebuild -exportArchive -archivePath "$task_output/NetworkSpecialist.xcarchive" \
  -exportPath "$task_output/ipa" -exportOptionsPlist "$task_output/ExportOptions.plist" \
  -allowProvisioningUpdates > "$task_output/export.log" 2>&1
"$task_python" tools/release/validate_distribution.py --ipa "$task_output/ipa/NetworkSpecialist.ipa" \
  --report "$task_output/ipa-privacy-check.json"
echo "IPAを作成しました: $task_output/ipa"
echo 'アップロードと審査提出は申請手順の別コマンドから行います。'
