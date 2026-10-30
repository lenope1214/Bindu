#!/usr/bin/env bash
# Bindu App Store용 IPA 빌드 (macOS: Finder에서 더블클릭 또는 터미널 실행)
#
# 결과: 프로젝트 폴더에 Bindu.ipa (App Store Connect 업로드용, Transporter 앱으로 올림)
# 빌드가 끝나면 export_presets.cfg의 iOS application/version(빌드 번호)을 1 올려 둔다.
# 사전 준비: Xcode > Settings > Accounts에 Apple ID(팀 4472Q8S8CD) 로그인. 서명은 Xcode 자동 서명.
set -euo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
VER="$(sed -n '/^name="iOS"/,$p' export_presets.cfg | grep -m1 '^application/version=' | cut -d'"' -f2)"
echo "iOS 빌드 번호 $VER 빌드 중..."

rm -rf build/ios && mkdir -p build/ios
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path . --export-release "iOS" build/ios/Bindu.xcodeproj

xcodebuild -project build/ios/Bindu.xcodeproj -scheme Bindu -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/ios/Bindu.xcarchive \
  -allowProvisioningUpdates CODE_SIGN_IDENTITY="Apple Development" archive

cat > build/ios/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>4472Q8S8CD</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath build/ios/Bindu.xcarchive \
  -exportOptionsPlist build/ios/ExportOptions.plist -exportPath build/ios/out -allowProvisioningUpdates

[[ -f build/ios/out/Bindu.ipa ]] || { echo "빌드 실패: 위 로그를 확인해 주세요." >&2; exit 1; }
mv -f build/ios/out/Bindu.ipa Bindu.ipa
rm -rf build/ios
sed -i '' "/^name=\"iOS\"/,\$ s/^application\/version=\"$VER\"$/application\/version=\"$((VER + 1))\"/" export_presets.cfg
echo "완료: $PWD/Bindu.ipa (빌드 번호 $VER, $(du -h Bindu.ipa | cut -f1))"
