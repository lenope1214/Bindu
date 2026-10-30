#!/usr/bin/env bash
# Bindu Google Play용 AAB 빌드 (macOS: Finder에서 더블클릭 또는 터미널 실행)
#
# 결과: 프로젝트 폴더에 Bindu.aab (업로드 키로 서명됨)
# 빌드가 끝나면 export_presets.cfg의 version/code를 1 올려 둔다 (Play는 같은 번호를 다시 받지 않음).
# 업로드 키: keystore/bindu-upload.jks, 비밀번호: keystore/password.txt — 잃어버리면 Play Console에서 키 재설정 요청 필요. 꼭 백업.
set -euo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/keystore/bindu-upload.jks"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="upload"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat keystore/password.txt)"

CODE="$(grep -m1 '^version/code=' export_presets.cfg | cut -d= -f2)"
echo "versionCode $CODE 빌드 중..."

mkdir -p build/android
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
# 게임 안 패치노트를 CHANGELOG.md에서 다시 만든다 (빌드에는 .md가 들어가지 않음)
"$GODOT_BIN" --headless --path . --script tools/gen_patch_notes.gd || true
INSTALL=()
[[ -d android/build ]] || INSTALL=(--install-android-build-template)
"$GODOT_BIN" --headless --path . "${INSTALL[@]}" --export-release "Android" build/android/Bindu.aab

[[ -f build/android/Bindu.aab ]] || { echo "빌드 실패: 위 로그를 확인해 주세요." >&2; exit 1; }
mv -f build/android/Bindu.aab Bindu.aab
rm -rf build
sed -i '' "s/^version\/code=$CODE$/version\/code=$((CODE + 1))/" export_presets.cfg
echo "완료: $PWD/Bindu.aab (versionCode $CODE, $(du -h Bindu.aab | cut -f1))"
