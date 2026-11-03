#!/usr/bin/env bash
# Bindu UI 개선 PR 실행 (빌드 없이). Finder에서 더블클릭하거나 터미널에서 ./run_mac_ui_overhaul.command
# 항상 GitHub codex/ui-overhaul 최신으로 실행: 전용 사본(BINDU_UI_DIR, 기본
# ~/Library/Caches/Bindu-ui-overhaul)을 origin/codex/ui-overhaul에 맞춘 뒤 실행한다. 이 폴더의 파일·브랜치·변경은 건드리지 않음.
# 이 폴더 그대로 실행하려면(로컬 수정 시험): LOCAL=1 ./run_mac_ui_overhaul.command
# 인터넷이 안 되면 마지막으로 받아 둔 PR 브랜치로 실행.
# 게임을 닫으면 터미널 창도 닫힘(실패 시에는 오류를 보도록 유지). 창을 남기려면 KEEP_OPEN=1
# Godot 위치가 다르면: GODOT=/경로/Godot ./run_mac_ui_overhaul.command
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

BRANCH="codex/ui-overhaul"
REPO_URL="${BINDU_REPO:-https://github.com/lenope1214/Bindu.git}"
MAIN_DIR="${BINDU_UI_DIR:-$HOME/Library/Caches/Bindu-ui-overhaul}"
if [[ "${LOCAL:-}" != "1" ]]; then
  if [[ ! -d "$MAIN_DIR/.git" ]]; then
    echo "PR 브랜치 최신본 받는 중 (처음 한 번): $MAIN_DIR"
    mkdir -p "$(dirname "$MAIN_DIR")"
    if ! git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$MAIN_DIR"; then
      echo "PR 브랜치를 받지 못해 이 폴더 그대로 실행합니다." >&2
      MAIN_DIR=""
    fi
  elif git -C "$MAIN_DIR" fetch --depth 1 origin "$BRANCH"; then
    # 전용 사본이라 강제로 맞춰도 됨 (.godot 임포트 캐시는 gitignore라 유지)
    git -C "$MAIN_DIR" checkout -q -B "$BRANCH" FETCH_HEAD
    git -C "$MAIN_DIR" reset -q --hard FETCH_HEAD
    git -C "$MAIN_DIR" clean -qfd
  else
    echo "PR 브랜치를 새로 받지 못해 마지막으로 받은 버전으로 실행합니다." >&2
  fi
  if [[ -n "$MAIN_DIR" ]]; then
    echo "실행: $BRANCH $(git -C "$MAIN_DIR" log -1 --format='%h %s' | cut -c1-70)"
    cd "$MAIN_DIR"
  fi
fi

GODOT_BIN="${GODOT:-}"
if [[ -z "$GODOT_BIN" ]]; then
  for c in godot godot4 Godot; do
    if command -v "$c" >/dev/null 2>&1; then GODOT_BIN="$(command -v "$c")"; break; fi
  done
fi
if [[ -z "$GODOT_BIN" ]]; then
  for c in "/Applications/Godot.app/Contents/MacOS/Godot" \
           "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
           /Applications/Godot*.app/Contents/MacOS/Godot; do
    if [[ -x "$c" ]]; then GODOT_BIN="$c"; break; fi
  done
fi
if [[ -z "$GODOT_BIN" ]]; then
  echo "Godot을 찾지 못했어요. GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./run_mac_ui_overhaul.command 처럼 지정해 주세요." >&2
  exit 1
fi

# 리소스 임포트·스크립트 목록 갱신 (새 스크립트가 추가돼도 바로 실행되도록 매번)
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --path .
close_terminal
