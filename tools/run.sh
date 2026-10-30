#!/bin/bash
# 빈두 점검 도구. 프로젝트를 임시 폴더에 복사해(저장 파일이 섞이지 않게) 헤드리스 Godot으로 돌린다.
# 사용: GODOT=<godot 실행 파일> tools/run.sh <명령> [인자...]
#   bots [규칙=1] [판 수=32] [stack]     자동 플레이 봇: 도달 웨이브 중간값·평균과 죽은 웨이브 분포
#   long [규칙=1] [맵=plain] [웨이브=40]   죽지 않는 봇으로 긴 판 (웨이브가 4분 넘게 안 끝나면 STUCK)
#   cont [규칙=1] [맵=plain] [웨이브=45]   4웨이브마다 끄고 이어하기 → 저장 전후가 다르면 DIFF
#   fuzz [판 수=8] [프레임=9000]          무작위 클릭·끌기·키·터치 (스크립트 오류 찾기)
#   elem                                   속성마다 직선탄 Lv2 하나가 30초간 준 피해/초
# 환경 변수: SPEED(배속, 기본 4) SMART(기본 1: 사람처럼 중앙 가까이에서 길목을 겨눔, 0이면 예전 봇)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SMART=${SMART:-1}
G=${GODOT:-godot}
CMD=${1:-bots}
shift || true

# macOS에는 timeout이 없을 수 있다 (있으면 쓰고, 없으면 그냥 실행)
T() {
	if command -v timeout > /dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi
}

copy_project() {
	local d
	d=$(mktemp -d)
	cp -r "$ROOT/scripts" "$ROOT/tools" "$ROOT/main.tscn" "$ROOT/project.godot" "$ROOT/icon.svg" "$d/"
	# config/name이 다르면 user:// 폴더가 달라 실제 게임의 기록·이어하기를 건드리지 않는다
	sed -i.bak "s/^config\/name=.*/config\/name=\"BinduTools$1\"/" "$d/project.godot"
	(cd "$d" && T 300 "$G" --headless --import > /dev/null 2>&1 || true)
	echo "$d"
}

summary() {
	# RESULT wave=N 줄들 → 중간값·평균·최소·최대, 죽은 웨이브 분포
	grep -ho "RESULT wave=[0-9]*" "$@" | sed 's/RESULT wave=//' | sort -n | awk '
		{a[NR]=$1; s+=$1; h[$1]++}
		END {
			if (NR == 0) { print "결과 없음"; exit }
			printf "n=%d 중간값=%s 평균=%.1f 최소=%s 최대=%s\n", NR, a[int((NR+1)/2)], s/NR, a[1], a[NR]
			printf "죽은 웨이브:"
			for (w = a[1]; w <= a[NR]; w++) if (h[w] > 0) printf " %d웨이브x%d", w, h[w]
			printf "\n"
		}'
}

leaks() {
	# 판마다 처음 누수가 난 웨이브, 웨이브별 누수 합계, 죽은 웨이브에서 새어 든 구체 종류(0 일반 1 빠른 2 단단한 3 보스)
	for f in "$@"; do
		d=$(grep -o "RESULT wave=[0-9]*" "$f" | head -1 | sed 's/RESULT wave=//')
		grep "^LEAKS" "$f" | sed "s/^/$d /"
	done | awk '
		{ dw=$1; split($3, a, "="); w=a[2]; split($4, b, "="); n=b[2]; tot[w]+=n; if (w==dw) { died[w]++; match($0, /kinds=[^ ]*/); dk[w]=dk[w] " " substr($0, RSTART+6, RLENGTH-6) } }
		END {
			printf "웨이브별 누수 합계:"; for (w=1; w<=60; w++) if (tot[w]>0) printf " %d:%d", w, tot[w]; printf "\n"
			for (w=1; w<=60; w++) if (died[w]>0) printf "  %d웨이브에서 죽은 판 %d개, 새어 든 종류:%s\n", w, died[w], dk[w]
		}'
}

case "$CMD" in
	bots)
		R=${1:-1}; N=${2:-32}; MODE=${3:-}
		D=$(copy_project "$$")
		cd "$D"
		for seed in $(seq 1 "$N"); do
			RULES=$R SPEED=${SPEED:-4} T 900 "$G" --headless --fixed-fps 60 --path . -s tools/bot.gd -- "$seed" $MODE 2>&1 | head -c 300000 > "b_$seed.txt" &
			if (( seed % 8 == 0 )); then wait; fi
		done
		wait
		grep -h "SCRIPT ERROR" -A2 b_*.txt | head -6 || true
		echo "규칙 $R ${MODE:+($MODE)}:"
		summary b_*.txt
		leaks b_*.txt
		rm -rf "$D"
		;;
	long|cont)
		R=${1:-1}; M=${2:-plain}; W=${3:-40}
		[ "$CMD" = cont ] && W=${3:-45}
		D=$(copy_project "$$")
		cd "$D"
		S=tools/bot.gd
		[ "$CMD" = cont ] && S=tools/bot_continue.gd
		CONT=$([ "$CMD" = cont ] && echo 1 || echo "") RULES=$R MAP=$M GOD=$W SPEED=${SPEED:-8} \
			T 3600 "$G" --headless --fixed-fps 60 --path . -s "$S" -- 1 2>&1 | grep -E "SCRIPT ERROR|STUCK|RESULT|DIFF|CONT w=" | head -80 || true
		rm -rf "$D"
		;;
	fuzz)
		N=${1:-8}; F=${2:-9000}
		D=$(copy_project "$$")
		cd "$D"
		for seed in $(seq 1 "$N"); do
			T 900 "$G" --headless --fixed-fps 60 --path . -s tools/fuzz.gd -- "$seed" "$F" > "f_$seed.txt" 2>&1 &
			if (( seed % 8 == 0 )); then wait; fi
		done
		wait
		for seed in $(seq 1 "$N"); do
			echo "시드 $seed: 오류 $(grep -c 'SCRIPT ERROR' "f_$seed.txt" || true)개 · $(grep FUZZR "f_$seed.txt" | head -1)"
		done
		grep -h "SCRIPT ERROR" -A3 f_*.txt | head -20 || true
		rm -rf "$D"
		;;
	elem)
		D=$(copy_project "$$")
		cd "$D"
		T 1800 "$G" --headless --fixed-fps 60 --path . -s tools/elem_dps.gd 2>&1 | grep -v "^$" | grep -vi "warning\|leaked\|alsa\|audio" || true
		rm -rf "$D"
		;;
	*)
		sed -n '2,10p' "$0"
		exit 1
		;;
esac
