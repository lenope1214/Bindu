#!/usr/bin/env bash
# Direct-distribution macOS app + signed updater. No Sparkle dependency.
# MACOS_SIGN_IDENTITY='Developer ID Application: ...' MACOS_NOTARY_PROFILE=... ./build_macos.command
# Default '-' identity produces an ad-hoc signed local QA build, not a notarized public release.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
OUT="$ROOT/build/macos"
mkdir -p "$OUT"
SDK="$(xcrun --show-sdk-path)"
ARCHIVE_INCLUDE="${LIBARCHIVE_INCLUDE:-}"
if [[ ! -f "$SDK/usr/include/archive.h" ]]; then
  if [[ -z "$ARCHIVE_INCLUDE" ]] && command -v brew >/dev/null; then
    ARCHIVE_INCLUDE="$(brew --prefix libarchive 2>/dev/null || true)/include"
  fi
  if [[ ! -f "$ARCHIVE_INCLUDE/archive.h" ]]; then
    echo '빌드용 libarchive 헤더가 필요합니다: brew install libarchive 또는 LIBARCHIVE_INCLUDE 지정' >&2
    exit 1
  fi
fi
INCLUDE=()
[[ -n "$ARCHIVE_INCLUDE" ]] && INCLUDE=(-I "$ARCHIVE_INCLUDE")
HELPER_TMP="$OUT/.BinduUpdater.$$"
trap 'rm -f "$HELPER_TMP"' EXIT
xcrun clang "${INCLUDE[@]}" -fobjc-arc -O2 -Werror -Wno-deprecated-declarations \
  -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  -framework Foundation -larchive "$ROOT/native/macos/updater.m" -o "$HELPER_TMP"
SIGN_ID="${MACOS_SIGN_IDENTITY:--}"
codesign --force --options runtime --sign "$SIGN_ID" "$HELPER_TMP"
mv -f "$HELPER_TMP" "$OUT/BinduUpdater"
trap - EXIT
[[ "${1:-}" == '--helper-only' ]] && exit 0
G="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
[[ -x "$G" ]] || { echo 'GODOT에 Godot 실행 파일을 지정하세요' >&2; exit 1; }
RAW="$("$G" --version | tail -n1)"
TPL="$(echo "$RAW" | awk -F. '{v=$1"."$2; if ($3 ~ /^[0-9]+$/) {v=v"."$3;s=$4} else {s=$3}; print v"."s}')"
TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/$TPL"
if [[ ! -f "$TPL_DIR/macos.zip" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fL --retry 2 -o "$TMP/templates.tpz" "https://github.com/godotengine/godot/releases/download/${TPL%.*}-${TPL##*.}/Godot_v${TPL%.*}-${TPL##*.}_export_templates.tpz"
  mkdir -p "$TPL_DIR"
  unzip -q "$TMP/templates.tpz" 'templates/macos.zip' -d "$TMP"
  cp "$TMP/templates/macos.zip" "$TPL_DIR/macos.zip"
fi
"$G" --headless --path "$ROOT" --import
"$G" --headless --path "$ROOT" -s tools/gen_patch_notes.gd
"$G" --headless --path "$ROOT" --export-release macOS "$OUT/Bindu.app"
APP="$OUT/Bindu.app"
mkdir -p "$APP/Contents/Helpers"
cp "$OUT/BinduUpdater" "$APP/Contents/Helpers/BinduUpdater"
chmod 755 "$APP/Contents/Helpers/BinduUpdater"
# Sign nested Mach-O files and frameworks first, then seal the whole app after embedding the helper.
while IFS= read -r -d '' item; do
  if /usr/bin/file -b "$item" | /usr/bin/grep -q 'Mach-O'; then
    codesign --force --options runtime --sign "$SIGN_ID" "$item"
  fi
done < <(find "$APP/Contents" -type f -print0)
while IFS= read -r -d '' item; do
  codesign --force --options runtime --sign "$SIGN_ID" "$item"
done < <(find "$APP/Contents" -depth -type d -name '*.framework' -print0)
codesign --force --options runtime --entitlements "$ROOT/native/macos/entitlements.plist" --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP"
ZIP="$OUT/Bindu-macos.zip"
rm -f "$ZIP"
ditto -c -k --norsrc --keepParent "$APP" "$ZIP"
if [[ -n "${MACOS_NOTARY_PROFILE:-}" ]]; then
  [[ "$SIGN_ID" != '-' ]] || { echo '공증에는 Developer ID 서명이 필요합니다' >&2; exit 1; }
  xcrun notarytool submit "$ZIP" --keychain-profile "$MACOS_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
  ditto -c -k --norsrc --keepParent "$APP" "$ZIP"
fi
shasum -a 256 "$ZIP"
echo "앱: $APP"
echo "배포 ZIP: $ZIP"
