#!/bin/bash
# 빈두 점검 도구. 프로젝트를 임시 폴더에 복사해(저장 파일이 섞이지 않게) 헤드리스 Godot으로 돌린다.
# 사용: GODOT=<godot 실행 파일> tools/run.sh <명령> [인자...]
#   ui <검사.gd> <출력 폴더> [배율] [phone|touch]  커서·포커스 비점유 native 검사
#   bots [규칙=1] [판 수=32] [stack]     자동 플레이 봇: 도달 웨이브 중간값·평균과 죽은 웨이브 분포
#   long [규칙=1] [맵=plain] [웨이브=40]   죽지 않는 봇으로 긴 판 (웨이브가 4분 넘게 안 끝나면 STUCK)
#   cont [규칙=1] [맵=plain] [웨이브=45]   4웨이브마다 끄고 이어하기 → 저장 전후가 다르면 DIFF
#   fuzz [판 수=8] [프레임=9000]          무작위 클릭·끌기·키·터치 (스크립트 오류 찾기)
#   miss                                   공격방식 x 강화 x 다중 발사 수마다 정면 구체를 거리별로 맞히는지 (사거리 안 피해 0이면 MISS, KIND=fast 작은 구체)
#   elem                                   속성마다 직선탄 Lv2 하나가 30초간 준 피해/초
#   stages [규칙] [판수=6]                  5~200웨이브 11단계만 싸우고 사이는 선택지만 빠르게 (STAGES=목록)
#   rx                                     두 속성 짝마다 두 속성 Lv1 직선탄 하나가 구체 무리에 준 반응 피해/초 (RX=id,id로 골라 보기)
#   perf                                   후반 부하(오브젝트 16개·구체 250개+) 배속별 프레임당 계산 시간·부분별 시간
#   uifreq                                 UI 요소별 다시 그리기·글 바뀜 횟수와 프레임 시간 (쉬는 시간·카드 선택·구체 250개 웨이브)
#   perfwin                                perf를 창을 띄워 실행 (그리기 비용 포함, 수직 동기 끔)
#   compare [기준=1] [새 규칙=3] [판 수=32] [stack]   같은 시드로 두 규칙을 돌려 차이와 판정 (새 규칙을 내기 전에)
#   modes [규칙=1] [판 수=32] [모드...]   모드마다 같은 시드로 모드 없는 판과 비교: 웨이브 차이·점수 손익분기 배율
#   spec                                   docs/features.md의 기대 동작 자동 점검 (tools/spec_check.gd)
#   gift                                   협동 전달의 예약·정산·중복·복원 결정론 검사 (실통신은 별도 native)
#   rulekeys                               관리자 페이지 수치 표 목록(server/app/rule_keys.json)을 Rules에서 다시 만듦 (VERIFY=1이면 비교만, check에 포함)
#   patchkeys                              관리자 페이지 [패치] 하위 탭·특성·카드·모드 칸 목록(server/app/patch_sections.json)을 다시 만듦 (VERIFY=1이면 비교만, check에 포함)
#   tutplay                                플레이 튜토리얼 23단계를 직접·건너뛰기·장 고르기로 끝까지 (tools/tut_play_check.gd)
#   notes                                  CHANGELOG(게임 안 패치노트)에 패치 키·코드 이름·경로·해시·요청 인용이 없는지 (docs/changelog-rules.md)
#   preview [basic|pairs|deaths|context|long] 실제 전투·인스펙터 일치 검사
#   check                                  배포 전 한 번에: spec + 무작위 입력 + 이어하기 (실패하면 끝 코드 1)
# 환경 변수: SPEED(배속, 기본 4) SMART(기본 1: 사람처럼 중앙 가까이에서 길목을 겨눔, 0이면 예전 봇) VARY(0이면 판마다 다른 흐름 끔: 봉인·이벤트·적응 켬/끔 비교)
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
	cat > "$d/override.cfg" <<'CFG'
[display]
window/size/no_focus=true
window/size/mode=1
CFG
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
	ui)
		SCRIPT=${1:?tools 아래 검사 파일 이름 필요}; shift
		if [[ "$SCRIPT" == */* || ! -f "$ROOT/tools/$SCRIPT" ]]; then echo "검사 파일을 찾을 수 없음: $SCRIPT"; exit 1; fi
		D=$(copy_project "$$")
		python3 - "$D/scripts/online_config.gd" <<'PYCONFIG'
import re, sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^\"]*"', r'const \1 := ""', p.read_text()))
PYCONFIG
		if [[ "$SCRIPT" != "fuzz.gd" && $# -gt 0 ]]; then
			if [[ "$1" != /* ]]; then echo "출력 폴더는 절대 경로를 사용하세요"; rm -rf "$D"; exit 1; fi
			mkdir -p -- "$1"
		fi
		trap 'rm -rf "$D"' EXIT
		T 300 "$G" --audio-driver Dummy --path "$D" --resolution "${RESOLUTION:-1280x720}" -s "tools/$SCRIPT" -- "$@"
		;;
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
	stages)
		# 웨이브 단계별 점검 (2026-11-03): 사이 웨이브는 전투 없이 선택지만 고르고 5·10·15·20·30·40·50·75·100·150·200웨이브만 싸운다.
		# STAGES=5,20,50처럼 목록을 바꿀 수 있다. 판마다 STAGE 줄, 끝에 웨이브별 막은 판 비율·새어 든 구체 비율·특징 피해 몫
		R=${1:-1}; N=${2:-6}; MODE=${3:-}
		D=$(copy_project "$$")
		cd "$D"
		J=${JOBS:-$( (nproc || sysctl -n hw.ncpu) 2> /dev/null || echo 4)}
		for seed in $(seq 1 "$N"); do
			STAGES=${STAGES:-1} MINS=${MINS:-600} MODES=${BOT_MODES:-} RULES=$R SPEED=${SPEED:-4} T 3600 "$G" --headless --fixed-fps 60 --path . -s tools/bot.gd -- "$seed" $MODE 2>&1 | grep -E "^STAGE|^RESULT|SCRIPT ERROR" > "s_$seed.txt" &
			if (( seed % J == 0 )); then wait; fi
		done
		wait
		grep -h "SCRIPT ERROR" s_*.txt | head -3 || true
		echo "규칙 $R ${MODE:+($MODE)} 판 $N개:"
		cat s_*.txt | awk '/^STAGE/ {
			for (i = 2; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] }
			w = v["w"]; c[w]++; if (v["leaked"] == 0) ok[w]++; lk[w] += v["leaked"] / (v["n"] > 0 ? v["n"] : 1); sh[w] += v["share"]; tw[w] += v["towers"]
		} END {
			for (w in c) printf "%6d %4d %7.0f%% %9.1f%% %7.1f%% %6.1f\n", w, c[w], 100 * ok[w] / c[w], 100 * lk[w] / c[w], 100 * sh[w] / c[w], tw[w] / c[w]
		}' | sort -n | { echo "웨이브   판   막음   새어든몫   특징몫  오브젝트"; cat; }
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
			T 3600 "$G" --headless --fixed-fps 60 --path . -s "$S" -- 1 2>&1 | grep -E "SCRIPT ERROR|Parse Error|^ERROR:|STUCK|RESULT|DIFF|CONT w=" | head -80 || true
		rm -rf "$D"
		;;
	fuzz)
		N=${1:-8}; F=${2:-9000}
		D=$(copy_project "$$")
		cd "$D"
		for seed in $(seq 1 "$N"); do
			(T 900 "$G" --headless --fixed-fps 60 --path . -s tools/fuzz.gd -- "$seed" "$F" > "f_$seed.txt" 2>&1 && echo "FUZZ EXIT ok" >> "f_$seed.txt") &
			if (( seed % 8 == 0 )); then wait; fi
		done
		wait
		bad_fuzz=0
		for seed in $(seq 1 "$N"); do
			errors=$(grep -cE 'SCRIPT ERROR|Parse Error|^ERROR:' "f_$seed.txt" || true)
			echo "시드 $seed: 오류 ${errors}개 · $(grep FUZZR "f_$seed.txt" | head -1)"
			if [ "$errors" -gt 0 ] || ! grep -q "^FUZZ DONE frames=$F$" "f_$seed.txt" || ! grep -q "^FUZZ EXIT ok$" "f_$seed.txt"; then bad_fuzz=1; fi
		done
		grep -hE 'SCRIPT ERROR|Parse Error|^ERROR:' -A3 f_*.txt | head -20 || true
		rm -rf "$D"
		exit "$bad_fuzz"
		;;
	miss)
		D=$(copy_project "$$")
		cd "$D"
		T 3000 "$G" --headless --fixed-fps 60 --path . -s tools/miss_audit.gd 2>&1 | grep -E "^(ok|MISS|AUDIT)|SCRIPT ERROR" || true
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
	uifreq)
		D=$(copy_project "$$")
		cd "$D"
		T 900 "$G" --headless --fixed-fps 60 --path . -s tools/ui_freq.gd 2>&1 | grep -E "UIFREQ|SCRIPT ERROR" || true
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
		r=0
		T 1200 "$G" --headless --fixed-fps 60 --path . -s tools/spec_check.gd > spec.txt 2>&1 || r=1
		grep -E "^(ok|FAIL|SPEC|DOC)|SCRIPT ERROR|Parse Error|^ERROR:" spec.txt || true
		grep -q "^SPEC 통과" spec.txt || r=1
		grep -qE 'SCRIPT ERROR|Parse Error|^ERROR:' spec.txt && r=1
		cd / && rm -rf "$D"
		exit $r
		;;
	gift)
		if [[ ! -f "$ROOT/tools/battlefield_gift_state_check.gd" ]]; then
			echo "FAIL gift state 검사 도구 없음"
			exit 1
		fi
		D=$(copy_project "$$")
		trap 'rm -rf "$D"' EXIT
		python3 - "$D/scripts/online_config.gd" <<'PYGIFT'
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^\"]*"', r'const \1 := ""', path.read_text()))
PYGIFT
		r=0
		T 300 "$G" --headless --fixed-fps 60 --path "$D" -s tools/battlefield_gift_state_check.gd > "$D/gift.txt" 2>&1 || r=1
		grep -E "^(ok|FAIL|GIFT STATE)|SCRIPT ERROR|Parse Error|^ERROR:" "$D/gift.txt" || true
		grep -qE '^GIFT STATE .*failures=0$' "$D/gift.txt" || r=1
		grep -qE 'SCRIPT ERROR|Parse Error|^ERROR:' "$D/gift.txt" && r=1
		exit $r
		;;
	tutplay)
		# 플레이 튜토리얼: 23단계 직접 해내기(PC·터치)·건너뛰기만·장 고르기, 끝나면 기록·설정 그대로
		D=$(copy_project "$$")
		cd "$D"
		r=0
		T 600 "$G" --headless --fixed-fps 60 --path . -s tools/tut_play_check.gd > tp.txt 2>&1 || r=1
		grep -E "^(ok|FAIL|TUTPLAY|STUCK)|SCRIPT ERROR|Parse Error|^ERROR:" tp.txt || true
		grep -q "^TUTPLAY 통과" tp.txt || r=1
		grep -qE 'SCRIPT ERROR|Parse Error|^ERROR:' tp.txt && r=1
		cd / && rm -rf "$D"
		exit $r
		;;
	notes)
		python3 "$ROOT/tools/notes_check.py"
		;;
	patchkeys)
		# Godot 없이 돈다 (게임 코드를 글로 읽음)
		if [ "${VERIFY:-0}" = "1" ]; then python3 "$ROOT/tools/patch_keys.py" --check; else python3 "$ROOT/tools/patch_keys.py"; fi
		;;
	rulekeys)
		# 관리자 페이지 수치 표(server/app/rule_keys.json)를 지금 Rules에서 다시 만든다. VERIFY=1이면 쓰지 않고 같은지만
		D=$(copy_project "$$")
		(cd "$D" && T 120 "$G" --headless --path . -s tools/rule_keys.gd > rk.txt 2>&1) || true
		if ! grep -q "^RULEKEYS ok" "$D/rk.txt"; then grep -E "ERROR|Error" "$D/rk.txt" | head -5; rm -rf "$D"; exit 1; fi
		r=0
		if [ "${VERIFY:-0}" = "1" ]; then
			if cmp -s "$D/rule_keys.json" "$ROOT/server/app/rule_keys.json"; then echo "rule keys 통과"; else echo "FAIL rule keys: server/app/rule_keys.json이 오래됨 (tools/run.sh rulekeys)"; r=1; fi
		else
			cp "$D/rule_keys.json" "$ROOT/server/app/rule_keys.json"
			grep "^RULEKEYS" "$D/rk.txt"
		fi
		rm -rf "$D"
		exit $r
		;;
	architecture)
		D=$(copy_project "$$")
		trap 'rm -rf "$D"' EXIT
		"$G" --headless --path "$D" -s tools/architecture_check.gd
		;;
	preview)
		SUITE=${1:-basic}
		case "$SUITE" in basic|pairs|deaths|context|long) ;; *) echo "알 수 없는 preview 검사: $SUITE"; exit 1 ;; esac
		D=$(copy_project "$$")
		trap 'rm -rf "$D"' EXIT
		preview_status=0
		T 300 "$G" --headless --path "$D" -s tools/preview_parity_check.gd -- "$D" 1.0 pc "$SUITE" > "$D/preview.txt" 2>&1 || preview_status=$?
		grep -E "^PARITY|^FAIL|SCRIPT ERROR|Parse Error|^ERROR:" "$D/preview.txt" || true
		if [ "$preview_status" -ne 0 ] || grep -qE "^FAIL|SCRIPT ERROR|Parse Error|^ERROR:" "$D/preview.txt"; then exit 1; fi
		grep -q "^PARITY suite=$SUITE .* failures=0$" "$D/preview.txt"
		;;
	check)
		# 배포 전 점검 (docs/features.md). 화면 배치는 tools/shot.gd 스크린샷을 눈으로 따로 본다.
		CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bindu-check.XXXXXX")
		bad=""
		"$0" architecture > "$CHECK_DIR/architecture.txt" 2>&1 || bad="$bad architecture"
		grep -E "^ARCHITECTURE|^FAIL|SCRIPT ERROR|Parse Error" "$CHECK_DIR/architecture.txt" || true
		if python3 "$ROOT/tools/notes_check.py" > "$CHECK_DIR/notes.txt" 2>&1; then echo "notes 통과"; else grep -E "^FAIL|^NOTES" "$CHECK_DIR/notes.txt" | head -10; bad="$bad notes"; fi
		"$0" spec > "$CHECK_DIR/spec.txt" 2>&1 || bad="$bad spec"
		grep -E "^FAIL|^SPEC|SCRIPT ERROR|Parse Error|^ERROR:" "$CHECK_DIR/spec.txt" || true
		"$0" gift > "$CHECK_DIR/gift.txt" 2>&1 || bad="$bad gift"
		grep -E "^FAIL|^GIFT STATE|SCRIPT ERROR|Parse Error|^ERROR:" "$CHECK_DIR/gift.txt" || true
		for suite in basic deaths; do
			"$0" preview "$suite" > "$CHECK_DIR/preview-$suite.txt" 2>&1 || bad="$bad preview-$suite"
			grep -E "^PARITY suite=|^FAIL|SCRIPT ERROR|Parse Error|^ERROR:" "$CHECK_DIR/preview-$suite.txt" || true
		done
		"$0" tutplay > "$CHECK_DIR/tutplay.txt" 2>&1 || bad="$bad tutplay"
		grep -E "^FAIL|^TUTPLAY|SCRIPT ERROR|Parse Error|^ERROR:" "$CHECK_DIR/tutplay.txt" || true
		F=$("$0" fuzz 4 3000) || bad="$bad fuzz"
		printf '%s\n' "$F" > "$CHECK_DIR/fuzz.txt"
		echo "$F" | grep "^시드"
		echo "$F" | grep "^시드" | grep -qv "오류 0개" && bad="$bad fuzz"
		C=$("$0" cont 1 plain 13)
		echo "$C" | grep -E "RESULT|DIFF|SCRIPT ERROR|CONT w=" | head -10
		echo "$C" | grep -qE "DIFF|SCRIPT ERROR|Parse Error|^ERROR:|STUCK" && bad="$bad cont"
		echo "$C" | grep -q "^RESULT wave=13 " || bad="$bad cont"
		for w in 4 8 12; do echo "$C" | grep -q "^CONT w=$w OK$" || bad="$bad cont@$w"; done
		D=$(copy_project "$$")
		(cd "$D" && T 120 "$G" --headless --path . -s tools/online_check.gd > online.txt 2>&1)
		grep -q "결과: 모두 통과" "$D/online.txt" && echo "online 통과" || { grep -E "실패|SCRIPT ERROR" "$D/online.txt" | head -5; bad="$bad online"; }
		rm -rf "$D"
		D=$(copy_project "$$")
		(cd "$D" && T 120 "$G" --headless --path . -s tools/patch_keys_check.gd > pk.txt 2>&1)
		grep -q "^PATCHCHECK ok" "$D/pk.txt" && echo "patch keys 통과" || { grep -E "^FAIL|SCRIPT ERROR" "$D/pk.txt" | head -5; bad="$bad patchkeys"; }
		rm -rf "$D"
		VERIFY=1 "$0" rulekeys || bad="$bad rulekeys"
		VERIFY=1 "$0" patchkeys || bad="$bad patchkeys"
		if python3 -c "import fastapi, pytest, httpx" > /dev/null 2>&1; then
			(cd "$ROOT/server" && python3 -m pytest -q > "$CHECK_DIR/server.txt" 2>&1) || bad="$bad server"
			tail -1 "$CHECK_DIR/server.txt"
		else
			echo "server 건너뜀 (python3에 fastapi·pytest·httpx 없음: pip install -r server/requirements-dev.txt)"
		fi
		if [ -n "$bad" ]; then echo "CHECK 실패:$bad · 로그: $CHECK_DIR"; exit 1; fi
		echo "CHECK 통과. 화면 배치는 tools/shot.gd 스크린샷으로 따로 확인 (docs/features.md)"
		rm -rf "$CHECK_DIR"
		;;
	*)
		sed -n '2,13p' "$0"
		exit 1
		;;
esac
