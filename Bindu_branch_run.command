#!/usr/bin/env bash
# 빈두 브랜치 골라 실행 (Mac). Finder에서 더블클릭.
# GitHub의 브랜치 목록을 창에 보여 주고, 고른 브랜치 최신본을 전용 사본
# (~/Library/Caches/Bindu-branches/<브랜치>)에 받아 빌드 없이 실행한다. 다른 폴더는 건드리지 않음.
# Godot 위치가 다르면: GODOT=/경로/Godot ./Bindu_branch_run.command
# 끝나도 터미널 창을 남기려면 KEEP_OPEN=1
set -uo pipefail

REPO_URL="${BINDU_REPO:-https://github.com/lenope1214/Bindu.git}"
CACHE="${BINDU_BRANCH_DIR:-$HOME/Library/Caches/Bindu-branches}"

fail() {
  osascript -e "display alert \"빈두 실행기\" message \"$1\" as critical" >/dev/null 2>&1
  echo "$1" >&2
  exit 1
}

close_terminal() {
  [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" && "${KEEP_OPEN:-}" != "1" ]] || return 0
  local my_tty
  my_tty="$(tty 2>/dev/null)" || return 0
  nohup osascript -e 'delay 0.5' -e 'tell application "Terminal"' -e 'repeat with w in windows' \
    -e "if (tty of tabs of w) contains \"$my_tty\" then" -e 'close w' -e 'exit repeat' -e 'end if' \
    -e 'end repeat' -e 'end tell' >/dev/null 2>&1 &
}

command -v git >/dev/null 2>&1 || fail "git이 없어요. 터미널에서 xcode-select --install 로 설치해 주세요."

echo "브랜치 목록 받는 중..."
BRANCHES="$(git ls-remote --heads "$REPO_URL" 2>/dev/null | sed 's#.*refs/heads/##' | sort)"
[[ -n "$BRANCHES" ]] || fail "브랜치 목록을 받지 못했어요. 인터넷 연결을 확인해 주세요."
# main을 맨 위로, 마지막으로 고른 브랜치를 기본 선택으로
LIST="$( (echo "$BRANCHES" | grep -x main; echo "$BRANCHES" | grep -vx main) )"
LAST="$(cat "$CACHE/.last" 2>/dev/null || echo main)"
echo "$LIST" | grep -qx "$LAST" || LAST=main
ITEMS="$(echo "$LIST" | sed 's/"/\\"/g; s/.*/"&"/' | paste -sd, -)"
PICK="$(osascript -e "choose from list {$ITEMS} with title \"빈두 실행기\" with prompt \"실행할 브랜치를 고르세요\" default items {\"$LAST\"} OK button name \"실행\" cancel button name \"취소\"" 2>/dev/null)"
[[ -n "$PICK" && "$PICK" != "false" ]] || { close_terminal; exit 0; }
BRANCH="$PICK"

DIR="$CACHE/$(echo "$BRANCH" | tr '/' '_')"
mkdir -p "$CACHE"
echo "$BRANCH" > "$CACHE/.last"
if [[ ! -d "$DIR/.git" ]]; then
  echo "$BRANCH 받는 중 (처음 한 번): $DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$DIR" || fail "$BRANCH 를 받지 못했어요."
elif git -C "$DIR" fetch --depth 1 origin "$BRANCH"; then
  # 전용 사본이라 강제로 맞춰도 됨 (.godot 임포트 캐시는 gitignore라 유지)
  git -C "$DIR" checkout -qf -B "$BRANCH" FETCH_HEAD
  git -C "$DIR" reset -q --hard FETCH_HEAD
  git -C "$DIR" clean -qfd
else
  echo "새로 받지 못해 마지막으로 받은 $BRANCH 로 실행합니다." >&2
fi
echo "실행: $BRANCH $(git -C "$DIR" log -1 --format='%h %s' | cut -c1-70)"

GODOT_BIN="${GODOT:-}"
if [[ -z "$GODOT_BIN" ]]; then
  for c in godot godot4 Godot; do
    if command -v "$c" >/dev/null 2>&1; then GODOT_BIN="$(command -v "$c")"; break; fi
  done
fi
if [[ -z "$GODOT_BIN" ]]; then
  for c in "/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Applications/Godot.app/Contents/MacOS/Godot" /Applications/Godot*.app/Contents/MacOS/Godot; do
    if [[ -x "$c" ]]; then GODOT_BIN="$c"; break; fi
  done
fi
[[ -n "$GODOT_BIN" ]] || fail "Godot을 찾지 못했어요. GODOT=/Applications/Godot.app/Contents/MacOS/Godot 로 지정해 실행해 주세요."

cd "$DIR"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --path .
close_terminal
