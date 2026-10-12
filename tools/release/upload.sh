#!/bin/bash
# Uploads an exported IPA to ASC/TestFlight processing; does not submit for App Review.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "${1:-}" = '--archive' ]; then
  task_archive="${2:?Usage: bash tools/release/upload.sh --archive /absolute/path/NetworkSpecialist.xcarchive /absolute/new/output-directory}"
  task_output="${3:?新しいアップロード結果の保存先を指定してください。}"
  case "$task_archive" in /*.xcarchive) ;; *) echo 'Archiveの絶対パスを指定してください。' >&2; exit 2;; esac
  case "$task_output" in /*) ;; *) echo '保存先の絶対パスを指定してください。' >&2; exit 2;; esac
  test -f "$task_archive/Info.plist"
  if [ -e "$task_output" ]; then echo '既存の保存先を上書きしません。' >&2; exit 2; fi
  cd "$task_root"
  "$task_root/.venv-network/bin/python" tools/release/preflight.py
  "$task_root/.venv-network/bin/python" tools/release/validate_distribution.py \
    --app "$task_archive/Products/Applications/NetworkSpecialist.app"
  mkdir -p "$task_output"
  "$task_root/.venv-network/bin/python" - "$task_archive" "$task_output" <<'PY'
import json
import plistlib
import sys
from pathlib import Path
archive, output = map(Path, sys.argv[1:])
properties = plistlib.loads((archive / 'Info.plist').read_bytes())['ApplicationProperties']
config = json.loads(Path('docs/release/production-config.json').read_text())
if properties['CFBundleIdentifier'] != config['bundleID'] or properties['Team'] != config['teamID']:
    raise SystemExit('ArchiveのBundle ID/署名Teamが本番設定と一致しません。')
options = {'method': 'app-store-connect', 'destination': 'upload', 'teamID': properties['Team'],
           'signingStyle': 'automatic', 'manageAppVersionAndBuildNumber': False,
           'stripSwiftSymbols': True, 'uploadSymbols': True}
(output / 'UploadOptions.plist').write_bytes(plistlib.dumps(options))
PY
  xcodebuild -exportArchive -archivePath "$task_archive" \
    -exportOptionsPlist "$task_output/UploadOptions.plist" -exportPath "$task_output/upload" \
    -allowProvisioningUpdates > "$task_output/upload.log" 2>&1
  echo "アップロード結果: $task_output/upload.log（App Store Connectで処理結果を確認してください）"
  echo '審査提出と公開は別の操作です。アップロード済みビルド番号を再送しないでください。'
  exit 0
fi
task_ipa="${1:?Usage: bash tools/release/upload.sh /absolute/path/NetworkSpecialist.ipa}"
case "$task_ipa" in /*.ipa) ;; *) echo 'IPAの絶対パスを指定してください。' >&2; exit 2;; esac
test -f "$task_ipa"
: "${EXAMMASTER_ASC_KEY_ID:?App Store Connect APIのKey IDを設定してください。}"
: "${EXAMMASTER_ASC_ISSUER_ID:?App Store Connect APIのIssuer IDを設定してください。}"
# AuthKey_<KEY_ID>.p8 must already be in Apple's supported private key directory.
# The private key itself is never read or printed by this script.
cd "$task_root"
"$task_root/.venv-network/bin/python" tools/release/preflight.py
"$task_root/.venv-network/bin/python" tools/release/validate_distribution.py --ipa "$task_ipa"
xcrun altool --validate-app "$task_ipa" --api-key "$EXAMMASTER_ASC_KEY_ID" --api-issuer "$EXAMMASTER_ASC_ISSUER_ID"
xcrun altool --upload-package "$task_ipa" --api-key "$EXAMMASTER_ASC_KEY_ID" --api-issuer "$EXAMMASTER_ASC_ISSUER_ID"
echo 'アップロード完了後、App Store Connectのビルド処理結果を確認してください。審査にはまだ提出していません。'
