#!/usr/bin/env bash
# Bindu 바로 실행 (빌드 없이). Finder에서 더블클릭하거나 터미널에서 ./run_mac.command
# 게임을 닫으면 터미널 창도 닫힘(실패 시에는 오류를 보도록 유지). 창을 남기려면 KEEP_OPEN=1
# Godot 위치가 다르면: GODOT=/경로/Godot ./run_mac.command
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
  echo "Godot을 찾지 못했어요. GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./run_mac.command 처럼 지정해 주세요." >&2
  exit 1
fi

# 리소스 임포트·스크립트 목록 갱신 (새 스크립트가 추가돼도 바로 실행되도록 매번)
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --path .
close_terminal
