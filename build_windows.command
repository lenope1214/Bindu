#!/usr/bin/env bash
# Bindu Windows(.exe) 빌드 스크립트 (macOS: Finder에서 더블클릭 또는 터미널 실행)
#
# 사용법:  ./build_windows.command            → 프로젝트 폴더에 Bindu.exe, Bindu.zip (릴리스)
#          ./build_windows.command --debug    → 디버그 빌드
#          GODOT=/경로/Godot ./build_windows.command   → Godot 실행 파일 직접 지정
#
# 처음 실행 시 Godot 버전에 맞는 export 템플릿이 없으면 내려받아 설치한다(약 1GB).
set -euo pipefail

# 끝나면 이 터미널 창을 닫는다 (Terminal.app에서 실행했을 때만, KEEP_OPEN=1 이면 유지)
close_terminal() {
  [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" && "${KEEP_OPEN:-}" != "1" ]] || return 0
  local my_tty
  my_tty="$(tty 2>/dev/null)" || return 0
  nohup osascript \
    -e 'delay 0.5' \
    -e 'tell application "Terminal"' \
    -e 'repeat with w in windows' \
    -e "if (tty of tabs of w) contains \"$my_tty\" then" \
    -e 'close w' \
    -e 'exit repeat' \
    -e 'end if' \
    -e 'end repeat' \
    -e 'end tell' >/dev/null 2>&1 &
}

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"
PRESET="Windows Desktop"
OUT="build/windows/Bindu.exe"
MODE="--export-release"
[[ "${1:-}" == "--debug" ]] && MODE="--export-debug"

# 1) Godot 실행 파일 찾기
find_godot() {
  if [[ -n "${GODOT:-}" ]]; then echo "$GODOT"; return; fi
  for c in godot godot4 Godot; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return; fi
  done
  for c in "/Applications/Godot.app/Contents/MacOS/Godot" \
           "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
           /Applications/Godot*.app/Contents/MacOS/Godot; do
    if [[ -x "$c" ]]; then echo "$c"; return; fi
  done
}
GODOT_BIN="$(find_godot || true)"
if [[ -z "$GODOT_BIN" ]]; then
  echo "Godot을 찾지 못했어요. GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./build_windows.command 처럼 지정해 주세요." >&2
  exit 1
fi

# 2) 버전 확인 (예: 4.7.2.stable.official.abc123 → 템플릿 폴더 4.7.2.stable, 태그 4.7.2-stable)
RAW_VER="$("$GODOT_BIN" --version | tail -n1)"
TPL_VER="$(echo "$RAW_VER" | awk -F. '{ v=$1"."$2; if ($3 ~ /^[0-9]+$/) { v=v"."$3; s=$4 } else { s=$3 }; print v"."s }')"
TAG="${TPL_VER%.*}-${TPL_VER##*.}"
echo "Godot: $GODOT_BIN ($RAW_VER)"

# 3) export 템플릿 확인/설치
if [[ "$(uname)" == "Darwin" ]]; then
  TPL_ROOT="$HOME/Library/Application Support/Godot/export_templates"
else
  TPL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"
fi
TPL_DIR="$TPL_ROOT/$TPL_VER"
if [[ ! -f "$TPL_DIR/windows_release_x86_64.exe" ]]; then
  echo "export 템플릿($TPL_VER)이 없어 내려받습니다..."
  URL="https://github.com/godotengine/godot/releases/download/${TAG}/Godot_v${TAG}_export_templates.tpz"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fL --progress-bar -o "$TMP/templates.tpz" "$URL" || {
    echo "템플릿 다운로드 실패: $URL" >&2
    echo "Godot 에디터 > 편집기 > 내보내기 템플릿 관리에서 설치해도 됩니다." >&2
    exit 1
  }
  unzip -q "$TMP/templates.tpz" -d "$TMP"
  mkdir -p "$TPL_DIR"
  cp -R "$TMP/templates/." "$TPL_DIR/"
  echo "템플릿 설치 완료: $TPL_DIR"
fi

# 4) 빌드
mkdir -p "$(dirname "$OUT")"
# 리소스 임포트·스크립트 목록 갱신 (새 스크립트가 추가돼도 바로 실행되도록 매번)
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path "$PROJECT_DIR" $MODE "$PRESET" "$OUT"

if [[ ! -f "$OUT" ]]; then
  echo "빌드 실패: $OUT 이 만들어지지 않았어요. 위 로그를 확인해 주세요." >&2
  exit 1
fi

# 5) 결과물을 프로젝트 폴더로 옮기기 (디버그 빌드의 콘솔용 exe 포함)
BUILT=()
for f in "$(dirname "$OUT")"/*.exe; do
  mv -f "$f" "$PROJECT_DIR/$(basename "$f")"
  BUILT+=("$(basename "$f")")
done
rm -rf build

# 6) 배포용 zip (exe와 같은 폴더에 Bindu.zip)
rm -f Bindu.zip
zip -q Bindu.zip "${BUILT[@]}"
echo "완료: $PROJECT_DIR/Bindu.exe ($(du -h Bindu.exe | cut -f1))"
echo "      $PROJECT_DIR/Bindu.zip ($(du -h Bindu.zip | cut -f1))"
close_terminal
