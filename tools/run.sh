#!/bin/bash
# 빈두 점검 도구. 프로젝트를 임시 폴더에 복사해(저장 파일이 섞이지 않게) 헤드리스 Godot으로 돌린다.
# 사용: GODOT=<godot 실행 파일> tools/run.sh <명령> [인자...]
#   bots [규칙=1] [판 수=32] [stack]     자동 플레이 봇: 도달 웨이브 중간값·평균과 죽은 웨이브 분포
#   long [규칙=1] [맵=plain] [웨이브=40]   죽지 않는 봇으로 긴 판 (웨이브가 4분 넘게 안 끝나면 STUCK)
#   cont [규칙=1] [맵=plain] [웨이브=45]   4웨이브마다 끄고 이어하기 → 저장 전후가 다르면 DIFF
#   fuzz [판 수=8] [프레임=9000]          무작위 클릭·끌기·키·터치 (스크립트 오류 찾기, GARDEN=1이면 정원 판)
#   elem                                   속성마다 직선탄 Lv2 하나가 30초간 준 피해/초
#   rx                                     특수 반응마다 두 속성 Lv1 직선탄 하나가 구체 무리에 준 반응 피해/초 (RX=id,id로 골라 보기)
#   perf                                   후반 부하(오브젝트 16개·구체 250개+) 배속별 프레임당 계산 시간·부분별 시간
#   perfwin                                perf를 창을 띄워 실행 (그리기 비용 포함, 수직 동기 끔)
#   compare [기준=1] [새 규칙=3] [판 수=32] [stack]   같은 시드로 두 규칙을 돌려 차이와 판정 (새 규칙을 내기 전에)
#   tree [규칙=1] [판 수=32]               씨앗 나무 없음·절반·전부로 같은 시드 봇 (정원 모드 → 일반 판 강화 폭)
#   garden [시드 수=3] [웨이브=40]          정원 봇: 물러남·도달 게임 시간·숙련 (garden_bot.gd)
#   gcheck                                 정원 점검: 저장·이어하기·꺼 둔 동안 보상·물러남·환생·씨앗 나무 (garden_check.gd)
#   modes [규칙=1] [판 수=32] [모드...]   모드마다 같은 시드로 모드 없는 판과 비교: 웨이브 차이·점수 손익분기 배율
#   spec                                   docs/features.md의 기대 동작 자동 점검 (tools/spec_check.gd)
#   check                                  배포 전 한 번에: spec + 그린 궤적 + 무작위 입력 + 이어하기 (실패하면 끝 코드 1)
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
	cp -r "$ROOT/scripts" "$ROOT/tools" "$ROOT/docs" "$ROOT/main.tscn" "$ROOT/project.godot" "$ROOT/icon.svg" "$d/"
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
			# 상위 25%: 잘 풀린 판의 평균 길이 (8판이면 흔들림이 커서 판정에는 쓰지 않고 참고로만)
			q = int(NR * 3 / 4) + 1; t = 0
			for (i = q; i <= NR; i++) t += a[i]
			printf "n=%d 중간값=%s 평균=%.1f 최소=%s 최대=%s 상위25%%평균=%.1f\n", NR, a[int((NR+1)/2)], s/NR, a[1], a[NR], t/(NR-q+1)
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

# 봇 판들: run_bots <규칙> <판 수> <모드> <접두어> → <접두어>_<시드>.txt
run_bots() {
	for seed in $(seq 1 "$2"); do
		MODES=${BOT_MODES:-} RULES=$1 SPEED=${SPEED:-4} T 900 "$G" --headless --fixed-fps 60 --path . -s tools/bot.gd -- "$seed" $3 2>&1 | head -c 300000 > "$4_$seed.txt" &
		if (( seed % 8 == 0 )); then wait; fi
	done
	wait
	grep -h "SCRIPT ERROR" -A2 "$4"_*.txt | head -6 || true
}

# 판마다 "웨이브 점수 배율전점수" (모드 배율 mul로 나눈 점수)
scores() {
	for f in "$@"; do
		grep -h "^RESULT wave=" "$f" | head -1 | sed 's/RESULT wave=\([0-9]*\) score=\([0-9]*\) mul=\([0-9.]*\).*/\1 \2 \3/' | awk '{ printf "%d %d %.0f\n", $1, $2, $2 / ($3 > 0 ? $3 : 1) }'
	done
}

# 중간값 평균 상위25%평균 (summary의 첫 줄에서)
med_mean() {
	summary "$@" | head -1 | sed 's/.*중간값=\([0-9]*\) 평균=\([0-9.]*\).*상위25%평균=\([0-9.]*\).*/\1 \2 \3/'
}

case "$CMD" in
	bots)
		R=${1:-1}; N=${2:-32}; MODE=${3:-}
		D=$(copy_project "$$")
		cd "$D"
		run_bots "$R" "$N" "$MODE" b
		echo "규칙 $R ${MODE:+($MODE)}:"
		summary b_*.txt
		leaks b_*.txt
		rm -rf "$D"
		;;
	compare)
		# 새 규칙 버전·모드를 내기 전 점검 (docs/rule-history.md의 절차). 같은 시드라 판마다 비교된다.
		A=${1:-1}; B=${2:-3}; N=${3:-32}; MODE=${4:-}
		D=$(copy_project "$$")
		cd "$D"
		run_bots "$A" "$N" "$MODE" a
		run_bots "$B" "$N" "$MODE" b
		echo "기준 규칙 $A ${MODE:+($MODE)}:"
		summary a_*.txt
		echo "새 규칙 $B ${MODE:+($MODE)}:"
		summary b_*.txt
		read -r ma ea ta <<< "$(med_mean a_*.txt)"
		read -r mb eb tb <<< "$(med_mean b_*.txt)"
		awk -v ma="$ma" -v ea="$ea" -v ta="$ta" -v mb="$mb" -v eb="$eb" -v tb="$tb" 'BEGIN {
			r = (ea > 0) ? eb / ea : 1
			rt = (ta > 0) ? tb / ta : 1
			printf "차이: 중간값 %+d · 평균 x%.2f · 상위 25%% x%.2f\n", mb - ma, r, rt
			if (mb - ma <= -2 || r < 0.85) print "판정: 어려움 — 기준보다 많이 짧다. 사람 시험판·수치 조정 없이 내지 말 것"
			else if (mb - ma >= 3 || r > 1.25) print "판정: 쉬움 — 기준보다 많이 길다. 의도한 것인지 확인"
			else print "판정: 비슷함 (봇 기준). 사람 시험판은 따로"
		}'
		rm -rf "$D"
		;;
	tree)
		# 씨앗 나무(정원)를 올린 일반 판: 없음·절반·전부를 같은 시드로 (기획 목표: 전부여도 중간값 +4 이내)
		R=${1:-1}; N=${2:-32}
		D=$(copy_project "$$")
		cd "$D"
		for lv in none half full; do
			TREE=$lv run_bots "$R" "$N" "" "t$lv"
			echo "씨앗 나무 $lv:"
			summary t${lv}_*.txt
		done
		rm -rf "$D"
		;;
	garden)
		# 정원 봇: 시드마다 정원을 [웨이브]까지 (물러남·게임 시간·숙련)
		N=${1:-3}; W=${2:-40}
		D=$(copy_project "$$")
		cd "$D"
		for seed in $(seq 1 "$N"); do
			SPEED=${SPEED:-8} T 1800 "$G" --headless --fixed-fps 60 --path . -s tools/garden_bot.gd -- "$seed" "$W" 2>&1 | grep -E "^(W|RETREAT|RESULT|MASTERY)|SCRIPT ERROR" > "g_$seed.txt" &
		done
		wait
		for seed in $(seq 1 "$N"); do echo "시드 $seed:"; grep -E "RETREAT|RESULT|SCRIPT ERROR" "g_$seed.txt" | tail -6; done
		rm -rf "$D"
		;;
	gcheck)
		# 정원 점검: 저장·이어하기·꺼 둔 동안 보상·물러남·환생·씨앗 나무·일반 판 보너스 (빈 기록으로)
		D=$(copy_project "$$")
		cd "$D"
		T 600 "$G" --headless --fixed-fps 60 --path . -s tools/garden_check.gd 2>&1 | grep -E "^(ok|FAIL|RESULT|  )|SCRIPT ERROR" || true
		rm -rf "$D"
		;;
	modes)
		# 손익분기 배율 = 모드 없는 판 점수 ÷ 모드 판의 배율 전 점수. 이 배율이면 봇 실력에서 점수가 같다 (docs/modes.md)
		R=${1:-1}; N=${2:-32}
		shift 2 || shift $# || true
		LIST=${*:-rush swarm steel glass narrow early angry stroll fort three soft ease}
		D=$(copy_project "$$")
		cd "$D"
		BOT_MODES="" run_bots "$R" "$N" "" base
		read -r mb eb tb <<< "$(med_mean base_*.txt)"
		scores base_*.txt | sort -k2 -n | awk '{s+=$2; a[NR]=$2} END {print s/NR, a[int((NR+1)/2)]}' > base_score
		echo "규칙 $R 모드 없음: 중간값 $mb · 평균 $eb · 점수 평균 $(cut -d' ' -f1 base_score | xargs printf '%.0f') · 점수 중간값 $(cut -d' ' -f2 base_score)"
		for m in $LIST; do
			BOT_MODES=$m run_bots "$R" "$N" "" "m_$m"
			read -r mm em tm <<< "$(med_mean m_"$m"_*.txt)"
			scores m_"$m"_*.txt | sort -k3 -n | awk -v m="$m" -v mb="$mb" -v eb="$eb" -v mm="$mm" -v em="$em" -v bs="$(cat base_score)" '
				{s+=$3; a[NR]=$3}
				END {
					split(bs, b, " ")
					med = a[int((NR+1)/2)]
					printf "%-12s 웨이브 중간값 %+d · 평균 x%.2f · 손익분기 배율 평균 기준 x%.2f · 중간값 기준 x%.2f\n", m, mm - mb, em / eb, b[1] / (s / NR), b[2] / med
				}'
		done
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
	rx)
		D=$(copy_project "$$")
		cd "$D"
		T 3600 "$G" --headless --fixed-fps 60 --path . -s tools/rx_dps.gd 2>&1 | grep -v "^$" | grep -vi "warning\|leaked\|alsa\|audio" || true
		rm -rf "$D"
		;;
	perf)
		D=$(copy_project "$$")
		cd "$D"
		T 900 "$G" --headless --fixed-fps 60 --path . -s tools/perf.gd 2>&1 | grep -E "PERF|SCRIPT ERROR" || true
		rm -rf "$D"
		;;
	perfwin)
		D=$(copy_project "$$")
		cd "$D"
		T 900 "$G" --fixed-fps 60 --path . -s tools/perf.gd 2>&1 | grep -E "PERF|SCRIPT ERROR" || true
		rm -rf "$D"
		;;
	spec)
		D=$(copy_project "$$")
		cd "$D"
		T 600 "$G" --headless --fixed-fps 60 --path . -s tools/spec_check.gd > spec.txt 2>&1 || true
		grep -E "^(ok|FAIL|SPEC|DOC)|SCRIPT ERROR|Parse Error" spec.txt || true
		r=0
		grep -q "^SPEC 통과" spec.txt || r=1
		cd / && rm -rf "$D"
		exit $r
		;;
	check)
		# 배포 전 점검 (docs/features.md). 화면 배치는 tools/shot.gd 스크린샷을 눈으로 따로 본다.
		bad=""
		"$0" spec > /tmp/bindu_check_spec.txt 2>&1 || bad="$bad spec"
		grep -E "^FAIL|^SPEC" /tmp/bindu_check_spec.txt || true
		D=$(copy_project "$$")
		if (cd "$D" && T 300 "$G" --headless --path . -s tools/path_test.gd > path.txt 2>&1); then echo "path 통과"; else bad="$bad path"; fi
		grep -E "^FAIL|SCRIPT ERROR" "$D/path.txt" || true
		rm -rf "$D"
		F=$("$0" fuzz 4 3000)
		echo "$F" | grep "^시드"
		echo "$F" | grep "^시드" | grep -qv "오류 0개" && bad="$bad fuzz"
		C=$("$0" cont 1 plain 13)
		echo "$C" | grep -E "RESULT|DIFF|SCRIPT ERROR" | head -5
		echo "$C" | grep -qE "DIFF|SCRIPT ERROR" && bad="$bad cont"
		echo "$C" | grep -q "RESULT" || bad="$bad cont"
		D=$(copy_project "$$")
		(cd "$D" && T 120 "$G" --headless --path . -s tools/online_check.gd > online.txt 2>&1)
		grep -q "결과: 모두 통과" "$D/online.txt" && echo "online 통과" || { grep -E "실패|SCRIPT ERROR" "$D/online.txt" | head -5; bad="$bad online"; }
		rm -rf "$D"
		D=$(copy_project "$$")
		(cd "$D" && T 120 "$G" --headless --path . -s tools/patch_keys_check.gd > pk.txt 2>&1)
		grep -q "^PATCHCHECK ok" "$D/pk.txt" && echo "patch keys 통과" || { grep -E "^FAIL|SCRIPT ERROR" "$D/pk.txt" | head -5; bad="$bad patchkeys"; }
		rm -rf "$D"
		if python3 -c "import fastapi, pytest, httpx" > /dev/null 2>&1; then
			(cd "$ROOT/server" && python3 -m pytest -q 2>&1 | tail -1) | tee /tmp/bindu_check_server.txt
			grep -qE "failed|error" /tmp/bindu_check_server.txt && bad="$bad server"
		else
			echo "server 건너뜀 (python3에 fastapi·pytest·httpx 없음: pip install -r server/requirements-dev.txt)"
		fi
		if [ -n "$bad" ]; then echo "CHECK 실패:$bad"; exit 1; fi
		echo "CHECK 통과. 화면 배치는 tools/shot.gd 스크린샷으로 따로 확인 (docs/features.md)"
		;;
	*)
		sed -n '2,13p' "$0"
		exit 1
		;;
esac
