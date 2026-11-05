extends Node2D
## 게임 진행: 웨이브, 오브젝트 선택·설치, 충돌, 점수.

enum Phase { CHOOSE, PLACE, AIM, WAVE, GAMEOVER, MOVE, READY }

const CORE_RADIUS := 14.0
const LINE_INSET := 90.0  # 회랑 맵: 문(중앙 점)이 화면 끝에서 떨어진 거리
const LINE_HALF := 180.0  # 회랑 맵: 길 폭의 반
static var LINE_ORBS := 1.6  # 회랑 맵: 구체 수 배율 (방향이 하나고 길이 길어서). 봇 32판으로 평원에 맞춤 (2026-10-30)
static var CROSS_HP := 5.6  # 십자로 맵: 구체 체력 배율 (1.6 → 5.6, 2026-10-31 맵 난이도 맞추기: 봇 중간값 44 → 17). 서버 validate.py MAP_HP와 같이
static var LINE_HP := 4.8  # 회랑 맵: 구체 체력 배율 (2.4 → 4.8, 2026-10-31 맵 난이도 맞추기: 봇 중간값 35 → 16, 다른 맵 16~17)
static var LINE_SPD := 1.6  # 회랑 맵: 구체 속도 배율 (길이 길어 오래 맞는 만큼)
static var SPIRAL_SWIRL := 0.6  # 소용돌이 맵: 구체가 중앙 방향에서 비껴 도는 각도(라디안)
const MAP_AFF_COLOR := Color(0.55, 0.95, 0.85)  # 맵 친화 카드 표시 (MapRule)
static var CORE_MAX_HP := 10  # 중앙 체력 (모드·멀티 배율 전)
const MERGE_DIST := 30.0
const SAVE_PATH := "user://best.cfg"
const RUN_PATH := "user://run.cfg"  # 이어하기: 쉬는 시간마다 저장, 게임 오버면 지움
const OLD_GARDEN_RUN := "user://garden.cfg"  # 예전 정원 모드 저장 판 (정원을 없애서 읽지 않고 지운다)
const RUN_FORMAT := 1
const READY_HINT := "Space 또는 [웨이브 시작]: 시작   오브젝트 클릭: 선택 · 한 번 더 클릭: 방향 바꾸기   끌기: 옮기기"
## 첫 판: 카드 종류가 열리는 웨이브 (그 웨이브 앞 쉬는 시간부터 나온다). 속성은 처음부터
const TUTOR_OPEN := {"pat": 3, "mod": 4, "trig": 5, "link": 6}
const PLACE_HINT := "클릭: 설치 (오브젝트 위면 속성 겹치기)   오브젝트 꾹 누르기·끌기: 옮기기\n우클릭/Esc: 카드 다시 선택"

var phase := Phase.CHOOSE
var wave := 0
var score := 0
var best_score := 0
var best_wave := 0
var core_hp := CORE_MAX_HP
var core_max := CORE_MAX_HP
var wave_active := false

var to_spawn := 0
var spawn_timer := 0.0
var spawn_interval := 1.0

var lanes: Array[float] = []  # 다음 웨이브 구체가 들어올 방향(라디안)
var wells: Array = []  # 지금 떠 있는 중력 우물 (블랙홀): 안 구체가 받은 피해를 모은다
var star_towers: Array = []  # 별이 든 오브젝트 (둘레 피해를 별빛으로 모은다, 매 계산마다 갱신)
var picks_left := 0  # 이번 쉬는 시간에 남은 설치 횟수
const CARD_DIM_A := 0.65  # 카드 선택 중 전장 위 검은 막 (카드·카드 줄 버튼은 그 위)
const PLACE_OFF := Color(0.45, 0.45, 0.5, 0.4)  # 카드를 놓는 중 넣을 수 없는 오브젝트
var card_dim: ColorRect
var card_dock: CardDock
var moving: Tower = null  # 위치를 옮기는 중인 오브젝트
# 오브젝트를 꾹 누르거나 끌면 바로 옮긴다(카드를 고른 뒤에도). 선택된 오브젝트를 끌면 함께 움직인다.
var press_t: Tower = null
var press_pos := Vector2.ZERO
var press_ms := 0
var dragging := false
var drag_group: Array = []  # 함께 끄는 오브젝트들
var drag_origs: Array = []  # 끌기 전 위치
var selected: Array = []  # 여러 개 선택 (빈 곳을 끌어 상자로, Shift/Ctrl+클릭으로 더하고 빼기)
var boxing := false  # 선택 상자를 끄는 중
var wheel_acc := 0.0  # 오브젝트 휠 돌리기: 트랙패드의 잘게 오는 휠을 한 칸이 될 때까지 모은다
var aim_right := false  # 오브젝트를 우클릭한 채 끌어 방향을 정하는 중 (떼면 확정)
var box_start := Vector2.ZERO
var cards_hidden := false  # 선택지를 내려 필드를 보는 중
var hide_btn: Button
var card_detail_btn: Button  # 선택지 카드 [자세히] 켜기·끄기 (Meta.card_detail)
var move_orig_pos := Vector2.ZERO
var move_orig_dir := Vector2.RIGHT
var move_cards_hidden := false
var move_return := Phase.CHOOSE  # 옮기기를 끝내면 돌아갈 단계
var auto_start := false  # 끄면 설치 후 Space로 웨이브 시작
var auto_btn: Button
var start_btn: Button
var aim_ok_btn: Button  # 터치 조준 [확정] (취소 오른쪽)
var cancel_btn: Button  # 옮기기·설치 중 화면 취소 (우클릭·Esc가 없는 터치 화면용)
var detail_btn: Button  # 터치: 오브젝트 정보창 [자세히] (Shift 대신)
var tip_tower: Tower = null  # 터치: 정보창에 보이던 오브젝트
var tip_detail := false  # 터치로 [자세히]를 켰는지 (정보창이 사라지면 꺼짐)
var tip_frame := -10  # 오브젝트 정보창을 마지막으로 그린 프레임
var touch_tip_t := 0.0  # 터치: 누른 뒤 정보창을 보여 줄 남은 시간 (손을 뗀 자리에 정보창이 계속 남아 전장을 가리던 것)
const TOUCH_TIP_SEC := 3.0
var wave_leaks: Array = []  # 이번 웨이브에 중앙에 닿은 구체 [나온 방향 번호, 종류, 피해, 실제로 깎인 체력(실드에 막히면 0)]
var leak_log: Array = []  # 웨이브마다 누수 요약 (봇·통계·안내용)
var leak_flash: Array = []  # 화면 가장자리 붉은 번짐 [자리, 남은 시간]
var boss_plan := {}  # 다음 보스: 쉬는 시간에 진입 각도·체력·속도·저항을 미리 정해 길과 정보를 정확히 보여 준다
var touch_ui := OS.has_feature("mobile")  # 마지막 입력이 터치였는지 (터치는 마우스를 올려 둘 수 없다). 폰·태블릿은 첫 터치 전 첫 화면부터 터치용 글
var help_touch := false  # 도움말 글을 터치용으로 썼는지
var legend_rx_rows := 999  # 설명에 적을 반응 줄 수 상한 (화면에 맞춰 _process가 줄임)
var legend_rows := 0  # 지금 설명에 적힌 반응 줄 수
## 터치 화면에선 버튼 글의 키 안내 "(Q)"·"(Space: 바로)"를 뺀다. "(S: 멈추기)"처럼 누르면 하는 일은 "(눌러서 멈추기)"로
var key_re := RegEx.create_from_string(" ?\\((?:[KO] / )?(?:Q|V|S|D|E|F|K|O|H|M|N|P|T|Tab|Enter|Esc|F11|Space|←/→|↑/↓)(?:: [^)]*)?\\)")
var key_t := 0.0
var offer: Array = []  # 이번 선택지 [카드, ...] 카드: {"type": "elem"|"pat"|"mod"|"link"|"trig", ...}
var picked := {}  # 고른 카드
var place_pos := Vector2.ZERO

var towers: Node2D
var orbs: Node2D
var projectiles: Node2D
var zones: Node2D
var arcs: Array = []  # 전류 이펙트 [시작, 끝, 남은 시간]
var bolts: Array = []  # 연쇄 번개 [점 목록, 남은 시간]
var pulses: Array = []  # 소리 울림 음파 [중심, 반지름, 남은 시간]
var beams: Array = []  # 빛줄기 [시작, 끝, 색, 남은 시간]
var live_orbs: Array = []
var targets: Array = []  # 화면 안에 들어온 구체 (공격 대상)
var sim_id := 0  # 계산 조각 번호: 조각 안에서 변하지 않는 값(오브젝트 피해 배율)을 조각마다 한 번만 계산
var prof_on := false  # tools/perf.gd: 부분별 계산 시간 기록
var prof := {}
var place_label_rect := Rect2()
var place_note_rect := Rect2()
var place_note := {}  # 카드 넣는 단계에서 올린 오브젝트 설명 (_draw_place_note)
var fx_layer: Node2D  # 피해 숫자·파편 (맨 위)
var fx_k := 1.0  # 터지는 효과 진하기 (효과 줄이기 설정이면 0.5)
const FX_DPS := [0.0, 0.4, 0.7, 0.9]  # Meta.fx_dps별로 피해 몫이 작은 오브젝트 효과를 옅게 하는 세기
var fx_pick: OptionButton  # 아래 버튼 줄: 그 세기 고르기
var popups: Array = []  # [위치, 글자, 남은 시간, 색, 큰 글씨]
var particles: Array = []  # [위치, 속도, 남은 시간, 색, 크기]
var camera: Camera2D
var view_zoom := 1.0  # 전장 확대 배율 (두 손가락 벌리기·마우스 휠)
var view_pan := Vector2.ZERO  # 확대한 화면 가운데가 전장 가운데에서 벗어난 만큼
var touches := {}  # 터치 번호 → 화면 자리 (두 손가락 확대·이동)
var pinch_d := 0.0  # 두 손가락 사이 거리 (확대 시작할 때)
var pinch_z := 1.0
var pinch_lock := false  # 두 손가락을 댄 뒤 모든 손가락을 뗄 때까지 누르기·끌기를 막는다 (확대하다 설치되지 않게)
var mid_drag := false  # PC: 휠 누른 채 끌어 화면 이동
var zoom_btn: Button
var shake := 0.0
var core_flash := 0.0
var danger_lv := 0  # 중앙 위험 단계: 0 보통, 1 체력 50% 이하, 2 25% 이하
var wave_dmg := 0  # 이번 웨이브에 중앙이 잃은 체력
var eclipse_flash := 0.0  # 일식 순간 화면 어둡게
var side_big_t := 0.0  # 큰 곁공격이 화면을 차지하는 남은 시간 (Side.BIG_LOCK, 하나씩만)
var eclipse_cd := 0.0  # 화면 전체 일식 연출 쉬는 시간(실제 시간). 오브젝트 여럿의 일식이 번갈아 화면을 깜빡이지 않게
var core_disp := float(CORE_MAX_HP)  # 중앙 체력 표시(부드럽게 변함)
var kills := 0
var best_combo := 0
var sfx: Sfx
var mute_btn: Button
var stars := PackedVector3Array()  # 배경 점 (x, y, 밝기)

var hud: Control  # 왼쪽 위 점수 줄: 아이콘 칩 (_update_hud가 hud_chips를 채우고 _draw_hud가 그린다)
var hud_chips: Array = []  # [자리 Rect2, 아이콘, 아이콘 색, 글, 글 색, 말풍선 줄]
var info: Control  # 화면 위 아이콘 층: 진입 화살표 배지·고르기 배지·말풍선 (_draw_info)
var tip_rects: Array = []  # 이번 프레임 말풍선 자리 [Rect2(UI 좌표), 줄들 [[글, 색]]]
var _hint_kept := ""  # 낱말 붙임(_kr_keep)을 넣은 아래 안내 글
var _badge_memo := {}  # _free_badge 답 (입력 hash → Rect2)
var _badge_cands: Array[Vector2] = []  # _free_badge가 볼 자리 (안쪽 칸, 옆 칸), 가까운 순
var info_rects: Array = []  # 이번 프레임 info에 그린 배지 [이름, Rect2(UI 좌표)] (화면 배치 점검 tools/ui_check.gd)
var info_mouse_capture := false
var info_touch_capture := -1
var tip_pin := -1  # 터치로 누른 말풍선 (tip_rects 번호)
var wave_info: Array = []  # 다음 웨이브 자세한 안내 [[글, 색]] (배지에 올리면 보임)
var wave_kinds: Array = []  # 다음 웨이브에 섞여 나오는 구체 [아이콘, 색, 처음 등장?]
var lane_bag: Array[int] = []  # 이번 웨이브 구체의 진입 방향(lanes 번호): 배지에 띄운 수대로 고르게 나눠 섞어 둔다
var leak_marks: Array = []  # 지난 웨이브에 놓친 구체 [각도, 수] (쉬는 시간 동안 그 방향에 -N)
var hint: Label
var ver_label: Label  # 왼쪽 아래 구석: 게임 버전 · 규칙 버전
var toast: Label
var toast_timer := 0.0
var tip_fade := {}  # 정보창과 겹친 UI 글 → 마지막으로 겹친 프레임
var banner: Label
var banner_t := 0.0
var banner_queue: Array = []  # 앞 글자가 떠 있는 동안 들어온 글자 [글, 색]
var choice_box: HBoxContainer
var choice_header: PanelContainer  # 카드 한 장의 설명과 구분되는 카드 줄 전체의 선택 안내
var choice_remaining: Label
const CHOICE_HEADER_H := 36.0
const CHOICE_HEADER_GAP := 18.0
const CARD_MAX_H := 250.0  # 선택지 카드 최대 높이 (넘으면 글자를 줄인다)
var over_label: Label
var over_card: Control  # 게임 오버 그림 카드 (over_data를 그림)
var over_data := {}
var legend: Label
var bar_box: HBoxContainer  # 오른쪽 아래 버튼 줄
var reroll_btn: Button
var apply_btn: Button  # 폰: 한 번 누른 카드 아래의 [적용]
var tap_sel := -1  # 폰: 한 번 눌러 미리보기 중인 카드 번호 (0부터). 같은 카드를 한 번 더 누르거나 [적용]을 누르면 고른다
var skip_btn: Button  # 웨이브 넘기기 (S)
var skip_n_btn: Button  # 넘길 웨이브 수 바꾸기
var skip_badge: Button  # 넘기는 중 표시, 누르면 멈추기
var pause_btn: Button
var speed_btn: Button
var speed_group: HBoxContainer
var speed_pick: OptionButton
const SPEEDS := [2.0, 3.0, 4.0, 6.0, 8.0]
var game_speed := 1.0  # 지금 배속
var fast_speed := 2.0  # Space로 켜는 배속
var paused_label: Label
var pause_box: HBoxContainer  # 일시정지 창 아래 버튼 (계속·시작 화면·끄기)
var pause_dim: ColorRect
var perk_press: Button = null  # 누르고 있는 특성 카드 (길게 누르기)
var perk_peek: Button = null  # 길게 눌러 자세히를 띄운 특성 카드 (손을 떼도 고르지 않음)
var panel_scroll := {}  # 폰: 창 → 안 굴림 칸 (_phone_scroll)
var legend_hidden := OS.has_feature("mobile")  # 폰·태블릿은 필드가 좁아 접어 두고 시작 (버튼으로 열면 저장)
var bar_open := false  # 오른쪽 아래 설정 버튼(소리·자동 시작·일시정지·배속)을 펼쳤는지. 접으면 펼치기 버튼만 남는다
var bar_btn: Button
var tutor := false  # 이번 판이 첫 판 안내 판인지: 카드 종류를 웨이브마다 하나씩 연다 (TUTOR_OPEN)
var tutor_given := {}  # 첫 판에 새로 연 카드 종류를 선택지에 한 번 넣었는지 (종류 -> true)
var guide_label: Label  # 처음 생기는 일 한 줄 안내 (위쪽 가운데)
const RX_CARD := preload("res://scripts/rx_card.gd")
var rx_card: RxCard  # RxCard: 속성을 합쳐 새 조합이 생기면 오브젝트 옆에 뜨는 그림 카드
var guide_lines: Array[String] = []
var guide_topic := ""
var guide_priority := 0
var guide_more: Button
var guide_t := 0.0  # 남은 시간. 음수면 웨이브가 시작될 때까지
var wave_resist := -1  # 다음 웨이브 저항 속성 (-1: 없음)
var aim_start_ms := 0
const AIM_TOUCH_MIN := 30.0  # 터치 조준: 오브젝트에서 이만큼 떨어진 손가락만 방향으로 친다 (손가락이 오브젝트를 가려도 바깥으로 끌면 된다)
const AIM_TOUCH_HINT := "쏠 쪽으로 누른 채 끌어 범위 보기, 떼면 그 방향 유지\n[확정] 또는 오브젝트 다시 누르기: 방향 확정"
# 터치 조준: 누른 채 끌면 손가락을 따라 범위가 보이고, 떼면 그 방향을 붙잡아 둔 채 [확정]을 기다린다
# (예전엔 누르는 순간 확정돼 어느 쪽으로 정해질지 미리 볼 수 없었다)
var aim_d := Vector2.ZERO  # 붙잡아 둔 방향 (터치)
var aim_hold := false  # 손가락을 대고 있는 중 (터치)
var aim_wait := false  # 방향을 붙잡아 두고 [확정]을 기다리는 중 (터치)
var restart_armed := 0.0  # 일시정지 중 R 두 번이면 처음부터
var end_armed := 0.0  # 일시정지 중 판 끝내기 두 번이면 지금 점수로 게임 오버
var ended := false  # 스스로 끝낸 판 (게임 오버 글 제목만 다름)
var old_run_ver := ""  # 지난 게임 버전에서 저장된 판을 끝낼 때 그 버전 (기록은 그 버전으로 보냄)
var over_ms := 0  # 게임 오버 시각: 직후 클릭이 결과를 못 보고 넘기지 않게
var countdown := -1.0  # 자동 시작까지 남은 시간
# 특성: 5웨이브마다 고르는 전역 강화
const PERKS := [
	{"id": "power", "name": "화력", "desc": "모든 피해 +15%"},
	{"id": "haste", "name": "속사", "desc": "모든 공격 속도 +12%"},
	{"id": "reach", "name": "원거리", "desc": "모든 사거리 +12%"},
	{"id": "core", "name": "단단한 중앙", "desc": "중앙 최대 체력 +3, 체력을 모두 회복해요."},
	{"id": "reroll", "name": "넉넉한 선택", "desc": "쉬는 시간마다 새로고침 +1"},
	{"id": "luck", "name": "행운", "desc": "속성 카드가 Lv2로 나올 확률 +20%"},
	{"id": "regen", "name": "회복", "desc": "웨이브를 마칠 때마다 중앙 체력 +1 (겹쳐 고르면 하나당 +0.5)"},
	{"id": "slow", "name": "끈적한 공간", "desc": "모든 구체 이동 속도 -8%"},
	{"id": "harmony", "name": "조화", "desc": "속성을 여러 종류 겹쳐 생기는 공격 속도 감소가 절반이 돼요. (한 번만, 공격 속도 최대 +20%)"},
	{"id": "coin", "name": "운명의 동전", "desc": "동전을 던지고 특성 3개를 새로 받아요. 앞면: 고른 특성이 두 번 적용돼요. 뒷면: 한 번 적용돼요. 이번 쉬는 시간 새로고침 +2"},
	{"id": "shield", "name": "실드", "desc": "웨이브를 시작할 때마다 중앙 실드 1칸 (겹치면 +1, 최대 3). 맞으면 체력 대신 실드가 깎이고, 다음 웨이브로 넘어가지 않아요."},
	{"id": "rampart", "name": "성벽", "desc": "웨이브마다 중앙 앞에 바위 벽: 다가온 구체를 한 번 밀어내고 한 조각씩 부서져요. 조각 수 = 벽 오브젝트 레벨 합 + 1 (겹치면 +1, 최대 4)"},
	{"id": "riposte", "name": "반격 파동", "desc": "중앙이 맞을 때마다(실드 포함) 파동이 퍼져 가까운 구체를 밀어내고 피해를 줘요. (겹치면 피해 +50%)"},
	{"id": "quick", "name": "빠른 손", "desc": "중앙 기술을 다시 쓰기까지 -20% (겹치면 곱)"},
	{"id": "overflow", "name": "넘친 회복", "desc": "체력이 가득할 때 받은 회복은 실드로 쌓여요. (회복 특성·보스 처치, 최대 2, 웨이브가 지나도 남아요.)"},
]
var perks := {}  # id → 고른 횟수
# 중앙 기술 (Skill): 이번 판 기술 두 개, 다시 쓰기까지 남은 게임 시간, 누를 자리를 기다리는 기술, 효과 그림 [자리, 반지름, 남은 시간, 색]
var skill_ids: Array = []
var skill_set := 0
var skill_cd := {}
var skill_arm := ""
var skill_fx: Array = []
var skill_btns: Array = []
var skill_used := 0  # 이번 판에 쓴 수 (판 기록)
var regen_acc := 0.0  # 회복 특성의 1이 안 되는 나머지 (다음 웨이브로)
var shield := 0  # 실드 특성: 이번 웨이브 실드 (웨이브 시작마다 다시 참)
var shield_keep := 0  # 넘친 회복 특성: 남는 실드 (이어하기에 저장)
var rampart_left := 0  # 성벽 특성: 이번 웨이브에 남은 벽 조각
var riposte_cd := 0.0
var core_fx: Array = []  # 중앙 반격 파동 [중심, 반지름, 남은 시간]
var perk_mode := false
var perk_offer: Array = []
var orb_speed_mul := 1.0
var rerolls_left := 1
var bonus_rerolls := 0
# 웨이브 넘기기: 카드 선택을 미루고 웨이브를 연달아 진행한다. 미룬 고르기는 멈춘 쉬는 시간에 한꺼번에
const SKIP_NS := [1, 3, 5, 10]
var skip_left := 0  # 더 넘길 웨이브 수 (지금 웨이브 포함, 0이면 넘기는 중 아님)
var skip_total := 0  # 이번에 넘기기로 한 웨이브 수 (표시용)
var skip_stop := false  # 멈추기를 눌렀거나 중앙이 위험해짐: 이번 웨이브가 끝나면 멈춤
var bank_picks: Array = []  # 미룬 고르기. 값은 쌓은 쉬는 시간의 웨이브 (속성 Lv2 확률을 그때 기준으로)
var bank_rerolls := 0
var perk_rerolls := 0  # 특성 선택 새로고침: 특성 고를 때마다 1번 (카드 새로고침과 따로)
var bank_perks := 0  # 미룬 특성 고르기
var coin_next := ""  # 운명의 동전을 던진 뒤 다음 특성: "double"(앞면) | "reroll"(뒷면) | ""
## 동전 연출: 0 없음, 1 공중에서 회전(누르면 떨어짐, 1초 뒤 자동), 2 떨어지며 느려짐, 3 모서리로 서서 흔들림, 4 쓰러져 결과.
## 결과(coin_next)는 던질 때 정해지고 연출은 보여 주기만 한다. 실제 시간으로 흐름(배속 무관). 자동 점검(headless)은 건너뜀
var coin_anim := DisplayServer.get_name() != "headless"
var coin_stage := 0
var coin_t := 0.0
var coin_ang := 0.0  # 회전각. 가로 폭 = cos(각), 양수면 앞면이 보임
var coin_ang0 := 0.0
var coin_spin := 0.0  # 떨어지는 동안 더 돌 각도 (끝에서 모서리가 서게 맞춤)
var coin_tap_t := 0  # 마지막으로 누른 때(ms), 터치가 마우스로도 와서 두 번 눌리지 않게
var coin_fx: Control
var rest_ready := false  # 이번 쉬는 시간의 다음 웨이브(방향·저항·보스)를 이미 뽑아 둠 (넘기다 쉬는 시간에 멈춘 때)
var combo := 0
var combo_t := 0.0
static var COMBO_KEEP := 3.0  # 이 게임 시간(배속과 상관없이) 안에 다음 처치가 나와야 콤보가 이어진다
var combo_hold := false  # 웨이브가 끝나면 남은 유지 시간을 멈춰 두고, 다음 웨이브 첫 처치에서 푼다
var combo_bonus := 0  # 이번 콤보로 더 얻은 점수 (배율 없이 받았을 점수와의 차이)
var combo_end := [0, 0, 0.0]  # 끊긴 콤보 [콤보, 보너스, 남은 표시 시간]
var combo_max_flash := 0.0  # 콤보 20(점수 x3)에 닿은 순간 반짝임
var ui_font: Font
var ui_root: Control  # UI 전체 (글자·버튼 크기 설정만큼 키운다)
var hud_sig := ""
var hud_cool := 0.0  # 점수 줄을 다시 쓰기까지 남은 시간 (점수·남은 구체만 바뀔 때)
var hud_urgent := ""  # 바로 보여야 하는 값(웨이브·중앙 체력 등)이 바뀌었는지 비교용
var title_label: Control  # 메인 메뉴
var title_box: VBoxContainer
var continue_btn: Button  # 저장된 판이 있을 때만 보임
var continue_info: Label  # 이어하기 카드의 설명 줄 (웨이브·맵·규칙)
const CONT_COL := Color(1.0, 0.78, 0.38)  # 이어하기 카드 색 (호박)
var account_label: Label  # 설정: 계정 상태 한 줄
var remote_btn: Button  # 같은 계정의 다른 기기에서 하던 판이 있고, 이 기기에 하던 판이 없을 때만
var remote_run := ""  # remote_btn이 가져올 판
var moved_run := ""  # 다른 기기가 가져간 판: 이 기기에서 계속 해도 서버에는 더 올리지 않는다
var new_btn: Button
var new_armed := 0.0  # 저장된 판이 있을 때 새로 시작은 두 번 눌러야 (실수로 지우지 않게)
var map_label: Label  # 준비 화면 맵 카드 아래 설명 (고른 맵 이름·규칙, 작은 설명은 meta "sub")
var map_cards: Array[Button] = []  # 준비 화면 맵 카드 (Meta.MAP_IDS 순서, _draw_map_card)
var flip_label: Label  # 회랑 맵: 구체가 오는 쪽 (회랑일 때만 보임)
var rules_label: Label
var skill_label: Label  # 준비 화면 중앙 기술 묶음
var skin_label: Label
var core_label: Label
var records_panel: Label
var notes_panel: PanelContainer  # 패치노트 (시작 화면·설정)
var notes_text: RichTextLabel
var notes_status: Label
var notes_btn: Button
var notes: PatchNotes
var notes_back := false  # 설정 창에서 열었으면 닫을 때 설정 창으로 돌아간다
var notes_open := {}  # 패치노트에서 펼친 버전 (지금·새 버전은 처음부터 펼침)
var settings_panel: PanelContainer
var modes_panel: PanelContainer  # 모드 고르기 (시작 화면, 첫 판 뒤)
var easy_notice: PanelContainer  # 쉽게 모드를 처음 켤 때: 쉽게 모드 리더보드로 간다는 안내 (다시 보지 않기)
var easy_notice_skip: CheckBox
var codex_panel: Codex  # 도감·선호 표시 (시작 화면, K)
var vote_panel: Vote  # 다음 패치 투표 (시작 화면 V, 판 끝난 화면 버튼)
var vote_btn: Button  # 시작 화면 [투표]: 투표 API가 있는 서버일 때만
var vote_over_btn: Button  # 판 끝난 화면 [다음 패치 투표]
var tut: Tutorial  # 튜토리얼 카드·다시 보기 목록 (시작 화면 [튜토리얼]·일시정지)
var tplay: TutPlay = null  # 플레이 튜토리얼 연습 판의 안내 칸 (TutPlay.on일 때만)
var tut_queue: Array[String] = []  # 판에서 처음 생겨서 띄울 항목 (쉬는 시간·시작 화면에서 띄움)
var tut_first := false  # 이 기기에서 첫 소개가 아직 완료되지 않음
var tut_paused := false  # 튜토리얼을 띄우느라 판을 멈췄다 (닫으면 다시 진행)
var modes_btn: Button
var modes_head: Label
var modes_btns := {}  # 모드 id -> 켜고 끄는 버튼
var new_achievements: Array = []  # 이번 판에 새로 달성한 업적 이름
var ach_dirty := false  # 이번 프레임에 처치가 있었다: 업적 조건을 한 번 본다
var help_label: Label
var help_scroll: ScrollContainer
var hover_elem := -1  # 마우스를 올린 선택지의 속성
var tip_orb: Node = null  # 마우스를 올린 구체 (그 구체만 체력 숫자를 보인다)
var range_all := false  # 터치 화면 [범위 보기]: Alt를 누른 것처럼 모든 오브젝트 범위·피해 몫
var range_btn: Button
var wave_time := 0.0  # 이번 웨이브 경과 시간
# 쉬는 시간 오브젝트별 DPS 표: 줄에 마우스를 올리면 그 오브젝트를 필드에서 짚어 준다
var dps_panel: FloatPanel  # 공용 떠 있는 창 틀 (옮기기·압정·접기는 FloatPanel)
var dps_head: Label  # 표 제목 (dps_panel.title)
var dps_scroll: ScrollContainer
var dps_list: VBoxContainer
var dps_sig := ""  # 표를 다시 만들지 정하는 요약 (오브젝트·피해가 바뀔 때만)
var dps_focus: Tower = null  # 표에서 마우스를 올린 오브젝트
var dps_hidden := OS.has_feature("mobile")  # D: 표 접기 (Meta.dps_fold로 저장)
var dps_choice_open := false  # 카드 선택 중엔 요약만, D로 상세를 잠깐 펼친다
# 웨이브 중 실시간 DPS: 게임 시간 DPS_STEP초마다 오브젝트별 누적 피해(dealt)를 적어 두고 최근 DPS_WIN초 차이로 초당 피해 (이동 평균이라 덜 흔들림)
const DPS_STEP := 0.5
const DPS_WIN := 5.0
var dps_hist := {}  # 오브젝트 instance id → 최근 dealt 표본들 (오래된 것부터)
var dps_t := 0.0  # 다음 표본까지 남은 게임 시간
var dps_n := 0  # 이번 웨이브에 적은 표본 수 (표를 1초마다 고치는 데 씀)
var rank_of := {}  # 오브젝트 instance id → 피해 순위 1~3 (왕관·메달)
var rank_t := 0.0  # 다음 순위 매김까지 남은 시간
# 온라인 (Net·Patch): 판 기록·통계
var net: Net
# 멀티플레이 (아래 "멀티플레이" 절)
var mp: Mp
var mp_panel: PanelContainer  # 시작 화면: 방 만들기·참가·대기실
var mp_status: Label
var mp_code_edit: LineEdit
var mp_start_btn: Button
var mp_host_box: HBoxContainer
var mp_join_box: HBoxContainer
var mp_room_box: VBoxContainer  # 방 코드·복사 + 사람 줄(플랫폼 그림·닉네임·핑)
var mp_desc: Label  # 모드 설명 (방에 들어가면 숨김)
var mp_load_view: Control  # 방 만들기·들어가기·호스트와 연결 중 화면 (그림·단계·남은 시간, _mp_draw_load)
var mp_load_msg := ""
var mp_load_host := false  # 방을 만드는 중 (단계가 둘)
var mp_close_btn: Button
var mp_ping_labels := {}  # id -> 사람 줄 끝 핑 Label (핑이 바뀌면 줄을 다시 안 만들고 글만)
var mp_btn: Button  # 시작 화면의 [멀티플레이]
var mp_bar: Label  # 게임 중 위쪽 가운데: 다른 플레이어 상태
var mp_mode := ""  # "" 혼자 | "vs" 대결 | "coop" 협동 (판을 시작하면 정해짐)
var mp_seed := 0  # 대결: 모두 같은 웨이브를 받는 씨앗 (0이면 혼자 하는 판처럼 전역 난수)
var wrng := RandomNumberGenerator.new()
var w_off := false  # 보낸 구체처럼 씨앗 밖에서 뽑는 구체 (같은 웨이브 순서를 흐트리지 않게)
var mp_others := {}  # id -> {name, w, hp, mx, sc, alive, gone}
var mp_next_extra := 0  # 대결: 다음 웨이브에 더 오는 구체 (상대가 보냄)
var mp_extra_left := 0  # 대결: 이번 웨이브에 아직 안 나온 보낸 구체
var mp_pending := 0  # 대결: 웨이브 중에 받은 것 (다음 쉬는 시간에 예고에 더함)
var mp_st_sig := ""
var mp_tick_t := 0.0
var mp_ghost := false  # 협동 참가자: 판 계산은 호스트가 하고 이 기기는 받은 대로 그린다
var mp_wave_go := false
var mp_ready := {}  # 협동 호스트: 웨이브 시작을 누른 사람
var mp_i_ready := false
var mp_next := {}  # 협동 참가자: 호스트가 정한 다음 웨이브 {w, lanes, res, boss}
var mp_ghosts := {}  # 협동 참가자: net_id -> Orb
var mp_orb_n := 0
var mp_tw_n := 0
var mp_tw_sig := ""
var mp_snap_t := 0.0
var mp_start := {}  # 판을 시작한 "start" 메시지 (협동 호스트가 다시 들어온 사람에게 다시 보냄)
var mp_code_last := ""  # 이번 판 방 코드 (끊기면 Mp가 code를 비우므로 따로)
var mp_view := 0  # 협동 [보기] 필터: 0이면 모두, 사람 id면 그 사람 오브젝트만 진하게 (나머지·그 공격은 흐리게)
var mp_view_btn: Button
var mp_fail_msg := ""  # 판 중에 방에서 떨어진 까닭 (판 끝 뒤 대기방 창에 보여 줌)
var mp_rejoin_until := 0  # 협동 참가자 재접속: 이 시각(ms)까지 다시 붙어 본다 (0이면 안 하는 중)
var mp_rejoin_wait := 0.0  # 다음 재시도까지
const MP_REJOIN_S := 30
var mp_rank := ""
## 협동: 다른 사람 마우스(터치) 위치. 초당 12번 보내고 받는 쪽은 부드럽게 따라가며 그린다 (대결은 전장이 따로라 안 함).
# 잠수 처리 (2026-10-31): 협동은 누군가 [웨이브 시작]을 누르면 남은 사람에게 기다림 시간, 지나면 대신 골라 준비.
# 2번 연속이면 자리 비움(다음부터 바로 대신 고름). 대결은 쉬는 시간이 길면 웨이브가 저절로 시작, 3번 연속이면 탈락.
var mp_wait_left := -1.0  # 이 기기 자동 고르기까지 (음수면 안 셈)
var mp_wait_ids: Array = []  # 호스트가 알려 준 아직 고르는 사람
var mp_wait_show := -1.0  # 상태 줄에 보여 줄 남은 시간
var mp_host_wait := -1.0  # 협동 호스트: 이 시간이 지나면 안 누른 사람을 두고 시작
var mp_afk := false  # 이 기기 자리 비움
var mp_afk_n := 0  # 연속으로 대신 고른 횟수
var mp_auto_now := false
var mp_idle_t := 0.0  # 대결: 쉬는 시간이 이어진 시간
var mp_kicked := {}  # 협동 호스트: 내보낸 id (다시 못 들어옴)
var mp_act: HBoxContainer  # 상태 줄 아래 버튼: [속성 요청] [내보내기]
var mp_req_btn: Button
var mp_kick_btn: Button
var mp_pop: PanelContainer  # 속성 고르기·내보낼 사람 고르기 작은 창
var mp_req_mode := false  # [속성 요청]을 누르고 내 오브젝트를 고르는 중
var mp_req_got_w := -1  # 이 웨이브 쉬는 시간에 요청한 속성을 이미 받음
# 대결 보낸 구체·멀티 업적
var mp_wave_extra := 0  # 대결: 이번 웨이브에 섞인 받은 구체 수
var mp_recv_n := 0  # 대결: 다음 웨이브에 받기로 한 구체 (상한 계산)
var mp_won := false
var mp_win_counted := false
var mp_was_last := false  # 대결: 한때 웨이브 꼴찌
var mp_cursors := {}  # id -> {"p": 그리는 자리, "to": 받은 자리, "t": 받은 시각 ms}
var mp_cur_layer: Node2D
var mp_cur_t := 0.0
var mp_cur_last := Vector2.INF
const MP_CUR_HZ := 12.0
const MP_CUR_HIDE_MS := 4000  # 이만큼 안 움직이면 흐려지다 사라짐  # 대결: 게임 오버 글에 붙일 순위
var run_id := ""  # 판 번호: 5웨이브마다 보내는 진행 기록과 끝 기록을 서버에서 한 줄로 (이어하기에 저장)
var run_log: Array = []  # 선택지 기록 [{w, k: card|perk, o: 나온 것, p: 고른 것(새로고침이면 "")}]
var run_game := 0.0  # 웨이브 진행 게임 시간 합
var run_real := 0.0  # 실제로 플레이한 시간 (시작 화면·일시정지 빼고)
var update_btn: Button  # 시작 화면: 새 버전 받기
var updater: Updater  # Windows 게임 안 업데이트
var notice_label: Label  # 시작 화면: 패치 공지
var board_box: VBoxContainer  # 리더보드 창 (records_panel 안): 왼쪽 필터 칩·오른쪽 순위 표
var board_chips := {}  # 필터 줄: map·rules·kind·season → HFlowContainer
var board_period := "all"  # 순위 표 탭: all(시즌 전체)·week(이번 주)
var board_period_btns: Array = []
var board_period_note: Label  # 탭 줄 오른쪽 'N명'
var board_rows: VBoxContainer  # 순위 줄
var board_hint: Label  # 맨 아래 안내 (기록 보내기·닉네임)
var board_left: VBoxContainer  # 리더보드 왼쪽 필터 칸
var board_narrow := false  # 리더보드 창이 좁을 때 (글자 키움·폰)
var board_map := "plain"  # 리더보드 필터. 창을 열 때 지금 고른 맵·규칙 버전으로 시작
var board_rules := 1
var board_season := 0  # 0: 이번 시즌
var board_easy := false  # 리더보드: 쉽게 모드를 쓴 판
var legacy_grow := false  # 정원(씨앗 나무)이 있던 버전에서 씨앗 나무를 켜고 시작해 이어 하는 판: 예전처럼 'grow'를 붙여 일반 리더보드에 섞이지 않게
var board_seasons: Array = []  # 서버 시즌 목록 (새 시즌부터)
var board_raw := {}  # 리더보드 창: period → 받은 응답 (차단을 바꾸면 다시 그리기)
var board_people := {}  # 리더보드 창에 보이는 다른 사람 {pid: 닉네임} (신고·차단 창 목록)
var board_ugc_btn: Button  # 리더보드 창 오른쪽 아래 [신고·차단] (App Store 1.2, 지우지 말 것)
var board_ugc_panel: PanelContainer  # 리더보드 위에 뜨는 신고·차단 목록
static var title_seen := false  # 다시 시작하면 타이틀은 건너뛴다
## 멀티 판이 끝나도 방은 남는다: 판 끝 화면을 지나 다시 불러올 때 Mp 노드를 루트에 잠시 옮겨 두고(연결 유지)
## 새 화면이 받아 대기방(멀티플레이 창)을 연다. 방이 없어졌으면 그 까닭을 창에 보여 준다.
static var mp_keep: Mp = null
static var mp_back := false
static var mp_back_msg := ""
var home_box: VBoxContainer  # 시작 화면 첫 화면: 이어하기·큰 타일(일반 판·멀티)·그림 버튼 줄
var prep_cols: GridContainer  # 준비 화면: [맵 카드 | 규칙·기술·모드·시작] 두 칸 또는 위아래 (_prep_layout)
var prep_right: VBoxContainer
var prep_box: VBoxContainer  # [일반 판]을 누르면: 맵·규칙·모드 + 시작 (Esc 뒤로)
var prep_title: Label
var prep_back: Button  # 준비 화면 왼쪽 위 [뒤로]
var modes_label: Label  # 준비 화면 모드 줄 가운데 글
var normal_info: Label  # 일반 판 타일의 맵·최고 기록 줄
var prep := false


func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.07))  # 전장 밖이 기본 회색으로 보이던 것
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 입력·UI는 동작
	Tower.dmg_mul = 1.0
	Tower.spd_mul = 1.0
	Tower.reach_mul = 1.0
	sfx = Sfx.new()
	add_child(sfx)
	Ach.perk_ids = PERKS.map(func(pk): return pk["id"])
	Ach.new_run()
	_load_best()
	Tutorial.load_file()
	tut_first = Tutorial.need_first() and DisplayServer.get_name() != "headless"
	if Meta.device_id == "":
		Meta.device_id = Crypto.new().generate_random_bytes(16).hex_encode()
		_save_best()
	Patch.load_cache()
	if Meta.games == 0:
		Meta.rules = 1  # 첫 판은 기본 규칙 (규칙 고르기는 첫 판 뒤에 보인다)
	Modes.set_on(Meta.modes if Meta.games > 0 else [])  # 모드도 첫 판 뒤에 열린다
	if TutPlay.pending >= 0:
		TutPlay.enter_meta()  # 플레이 튜토리얼: 평원·랭크·모드 없음 (저장할 때는 원래 값으로)
	_apply_rules()
	zones = _layer("Zones")
	towers = _layer("Towers")
	orbs = _layer("Orbs")
	projectiles = _layer("Projectiles")
	# 이 셋은 main이 _sim_step에서 직접 움직인다(배속 계산용)
	for l in [zones, orbs, projectiles]:
		l.process_mode = Node.PROCESS_MODE_DISABLED
	fx_layer = _layer("Fx")
	fx_layer.z_index = 5
	fx_layer.draw.connect(_draw_fx)
	mp_cur_layer = _layer("Cursors")
	mp_cur_layer.z_index = 6
	mp_cur_layer.draw.connect(_draw_mp_cursors)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)  # 가로 고정 (예전 빌드는 자유 회전으로 설정돼 있었다)
	camera = Camera2D.new()
	camera.position = center()
	add_child(camera)
	for i in 140:
		stars.append(Vector3(randf() * Meta.FIELD.x, randf() * Meta.FIELD.y, randf_range(0.03, 0.12)))
	_build_ui()
	_apply_ui_scale()
	_ach_catch_up()
	_apply_volume()
	_update_speed_btn()
	net = Net.new()
	add_child(net)
	vote_panel.net = net  # 투표 창은 _build_ui에서 net보다 먼저 만들어져 null을 받았다 ("서버에 연결하지 못했어요")
	coop_orbs = 1.0
	coop_n = 1
	vs_on = false
	Ach.mp = ""
	if mp_keep != null and is_instance_valid(mp_keep):
		mp = mp_keep  # 판이 끝나도 방 유지: 지난 화면의 연결을 그대로 받는다
		mp.reparent(self)
	else:
		mp = Mp.new()
		add_child(mp)
	mp_keep = null
	mp.room_ready.connect(_mp_refresh_lobby)
	mp.peers_changed.connect(_mp_refresh_lobby)
	mp.failed.connect(_mp_failed)
	mp.packet.connect(_mp_packet)
	mp.status_changed.connect(_mp_apply_switch)
	mp.ping_changed.connect(_mp_refresh_pings)
	mp.peer_up.connect(_mp_peer_up)
	mp.check_status()
	_mp_refresh_lobby(false)
	net.booted.connect(_on_booted)
	net.run_sent.connect(_on_run_sent)
	net.board_loaded.connect(_on_board_loaded)
	net.seasons_loaded.connect(_on_seasons_loaded)
	net.progress_synced.connect(_on_progress_synced)
	net.device_changed.connect(_save_best)
	net.runs_listed.connect(_on_runs_listed)
	net.run_claimed.connect(_on_run_claimed)
	net.run_moved.connect(_on_run_moved)
	net.rates_loaded.connect(func(): if codex_panel.visible: codex_panel._draw_list())
	updater = Updater.new()
	add_child(updater)
	updater.cleanup()
	updater.progress.connect(_on_update_progress)
	updater.failed.connect(_on_update_failed)
	notes = PatchNotes.new()
	add_child(notes)
	notes.loaded.connect(_draw_notes)
	if Meta.notes_seen == "" and Meta.games == 0:
		Meta.notes_seen = Net.game_version()  # 처음 하는 사람에게는 '새 소식' 표시를 하지 않는다
	_refresh_notes_btn()
	_on_booted(Net.info)  # 다시 시작했을 때: 이미 받아 둔 새 버전·공지
	# 창 제목에도 한글 이름과 버전 (작업 표시줄에서 어떤 빌드인지 보이게)
	get_window().title = "빈두 v%s" % ProjectSettings.get_setting("application/config/version", "?")
	if TutPlay.on and TutPlay.pending >= 0:
		_start_tut_play(TutPlay.pending)
	elif mp_back:
		_mp_back_lobby()
	elif title_seen or DisplayServer.get_name() == "headless":
		_start_choose()
	elif _old_run_version() != "":
		_end_old_run(_old_run_version())
	else:
		title_label.visible = true
		_refresh_continue()
		hint.text = ""
		net.check()  # 시작 화면이 뜰 때마다 새 버전 확인 (처음 켤 때는 Net이 이미 묻는 중)
		if TutPlay.then_play:
			TutPlay.then_play = false
			_set_prep(true)  # 튜토리얼 끝 [첫 판 시작]: 일반 판 준비 화면


## 창이 포커스를 잃어도 판은 계속 진행된다 (직접 조작이 없으니 멈추지 않음).
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and card_dock != null:
		card_dock.clear_gesture()
	# Android 뒤로가기 = Esc (한 단계 되돌리기 / 일시정지)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		Input.parse_input_event(esc)
	# 앱이 뒤로 가면 뗀 손가락 이벤트를 못 받을 수 있다: 두 손가락 확대 상태를 비운다
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		touches.clear()
		pinch_lock = false
		mid_drag = false
		info_mouse_capture = false
		info_touch_capture = -1
	# 창을 닫거나 (모바일) 앱이 뒤로 가면 지금 쉬는 시간 상태를 한 번 더 저장 (옮긴 위치까지)
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED) and towers and title_label:
		_save_run()


func _layer(n: String) -> Node2D:
	var node := Node2D.new()
	node.name = n
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(node)
	return node


## 폰·태블릿 화면 구성 (작은 화면에 손가락 크기 버튼). 점검 도구는 Meta.sim_phone으로 흉내 낸다.
func _phone() -> bool:
	return OS.has_feature("mobile") or Meta.sim_phone


func center() -> Vector2:
	return Meta.FIELD / 2.0


## 전장: 구체가 나오고 공격이 닿고 오브젝트를 놓는 곳. 화면비와 상관없이 늘 Meta.FIELD 크기 (기기마다 난이도·순위가 같게).
func arena() -> Rect2:
	return Rect2(Vector2.ZERO, Meta.FIELD)


## 지금 화면에 보이는 월드 영역. 화면이 16:9보다 길면(폰) 전장 양옆까지, 4:3이면(태블릿) 위아래까지 보인다.
func view_rect() -> Rect2:
	var vs := get_viewport_rect().size
	if card_dock != null and card_dock.active():
		return card_dock.world_view()
	if camera == null or is_equal_approx(view_zoom, 1.0):
		return Rect2((Meta.FIELD - vs) / 2.0, vs)
	var s := vs / view_zoom
	return Rect2(camera.position - s / 2.0, s)


## 확대하지 않았을 때 보이는 월드 영역 (확대한 화면이 이 밖으로 나가지 않게).
func full_view() -> Rect2:
	if card_dock != null and card_dock.active():
		return arena()
	var vs := get_viewport_rect().size
	return Rect2((Meta.FIELD - vs) / 2.0, vs)


## 전장 확대: ZOOM_MIN~ZOOM_MAX배, at(화면 좌표)이 가리키는 월드 점이 그 자리에 남게. 축소하면 전장을 중앙에 두고, 확대하면 전장 밖으로 이동하지 않는다.
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.5
func _zoom_to(z: float, at: Vector2) -> void:
	if card_dock != null and card_dock.active():
		var origin := card_dock.screen_board().get_center()
		var before := center() + view_pan + (at - origin) / (card_dock.fit * view_zoom)
		view_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
		view_pan = before - (at - origin) / (card_dock.fit * view_zoom) - center()
		_clamp_pan()
		return
	var vs := get_viewport_rect().size
	var before := camera.position + (at - vs / 2.0) / view_zoom
	view_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	view_pan = before - (at - vs / 2.0) / view_zoom - center()
	_clamp_pan()


func _pan_by(screen_d: Vector2) -> void:
	view_pan -= screen_d / (view_zoom * (card_dock.fit if card_dock != null and card_dock.active() else 1.0))
	_clamp_pan()


func _clamp_pan() -> void:
	if card_dock != null and card_dock.active():
		card_dock.camera_fit()
		return
	var fv := full_view()
	var hs := (get_viewport_rect().size / view_zoom / 2.0).min(fv.size / 2.0)
	var c := center() + view_pan
	c.x = clampf(c.x, fv.position.x + hs.x, fv.end.x - hs.x)
	c.y = clampf(c.y, fv.position.y + hs.y, fv.end.y - hs.y)
	view_pan = c - center()
	if camera:
		camera.zoom = Vector2(view_zoom, view_zoom)
		camera.position = center() + view_pan


func _reset_zoom() -> void:
	view_zoom = 1.0
	view_pan = Vector2.ZERO
	_clamp_pan()


## 지키는 중앙 점. 회랑 맵은 화면 가운데가 아니라 구체가 오는 반대쪽 끝(문 가운데).
func core() -> Vector2:
	var c := center()
	if Meta.map_id == "line":
		c.x = Meta.FIELD.x - LINE_INSET if Meta.line_flip else LINE_INSET
	return c


## 회랑 맵: 높이 y(길 가운데 기준)에서 구체가 나오는 자리와 닿는 문 자리.
func _line_start(y: float) -> Vector2:
	return Vector2(-30.0 if Meta.line_flip else Meta.FIELD.x + 30.0, center().y + y)


func _line_end(y: float) -> Vector2:
	return Vector2(core().x, center().y + y)


# ---------- UI ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Malgun Gothic", "sans-serif"])
	theme.default_font = font
	ui_font = font
	theme.default_font_size = 18
	root.theme = theme
	layer.add_child(root)
	ui_root = root
	card_dock = CardDock.new(self)
	get_viewport().size_changed.connect(_apply_ui_scale)

	hud = Control.new()
	hud.position = Vector2(10, 6)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 칩 말풍선은 _draw_info가 마우스 자리로 띄운다 (필드 누르기를 막지 않게)
	hud.draw.connect(_draw_hud)
	root.add_child(hud)

	hint = Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(16, -66)
	hint.size = Vector2(590, 44)  # 오른쪽 아래 설정 버튼 줄(펼쳤을 때 648)과 겹치지 않게
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN  # 줄이 늘면 위로 (아래는 버전 표시)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	root.add_child(hint)

	ver_label = Label.new()
	ver_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver_label.position = Vector2(16, -22)
	ver_label.size = Vector2(400, 18)
	ver_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ver_label.add_theme_font_size_override("font_size", 12)
	ver_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	ver_label.text = _ver_text()
	root.add_child(ver_label)

	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-300, 100)  # 점수 줄·보스 체력 막대 아래
	toast.size = Vector2(600, 30)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 22)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 5)
	root.add_child(toast)

	guide_label = Label.new()
	guide_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# 토스트 아래, 선택지 카드 위. 오른쪽 설명(x 950~)과 겹치지 않게 폭 600
	guide_label.position = Vector2(-300, 140)
	guide_label.size = Vector2(600, 0)
	guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_label.add_theme_font_size_override("font_size", 16)
	guide_label.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.08, 0.07, 0.04, 0.9)
	gsb.border_color = Color(1, 0.82, 0.4, 0.7)
	gsb.set_border_width_all(1)
	gsb.set_corner_radius_all(6)
	gsb.set_content_margin_all(10)
	guide_label.add_theme_stylebox_override("normal", gsb)
	guide_label.visible = false
	root.add_child(guide_label)
	rx_card = RX_CARD.new(self)
	root.add_child(rx_card)
	guide_more = Button.new()
	guide_more.text = "더 알아보기"
	guide_more.focus_mode = Control.FOCUS_NONE
	guide_more.z_index = 2
	guide_more.custom_minimum_size = Vector2(130, 32)
	# 안내 말풍선과 같은 노란 테두리 버튼: 예전엔 테두리 없는 글처럼 보여 누를 수 있는지 몰랐다
	for st in ["normal", "hover", "pressed"]:
		var mb := StyleBoxFlat.new()
		mb.bg_color = Color(0.08, 0.07, 0.04, 0.9) if st == "normal" else Color(0.18, 0.15, 0.07, 0.95)
		mb.border_color = Color(1, 0.82, 0.4, 0.7)
		mb.set_border_width_all(1)
		mb.set_corner_radius_all(6)
		mb.set_content_margin_all(6)
		guide_more.add_theme_stylebox_override(st, mb)
	guide_more.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	guide_more.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	guide_more.text = "더 알아보기 ›"
	guide_more.visible = false
	guide_more.pressed.connect(_open_guide_details)
	root.add_child(guide_more)

	# 카드 선택 중 전장·점수 줄·설명을 어둡게 (카드·카드 줄 버튼·알림·안내는 z 2로 그 위). 마우스는 통과
	card_dim = ColorRect.new()
	card_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_dim.color = Color(0, 0, 0, CARD_DIM_A)
	card_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_dim.z_index = 1
	card_dim.visible = false
	root.add_child(card_dim)
	toast.z_index = 2
	guide_label.z_index = 2

	choice_box = HBoxContainer.new()
	choice_box.z_index = 2
	choice_box.set_anchors_preset(Control.PRESET_CENTER)
	choice_box.position = Vector2(-440, -90)
	choice_box.size = Vector2(730, 180)
	choice_box.add_theme_constant_override("separation", 20)
	choice_box.alignment = BoxContainer.ALIGNMENT_CENTER  # 카드가 2장일 때도 가운데
	root.add_child(choice_box)
	choice_header = PanelContainer.new()
	choice_header.z_index = 2
	choice_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_header.visible = false
	var chs := CardDock.surface()
	chs.content_margin_left = 14
	chs.content_margin_right = 14
	chs.content_margin_top = 6
	chs.content_margin_bottom = 6
	choice_header.add_theme_stylebox_override("panel", chs)
	var chr := HBoxContainer.new()
	chr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chr.add_theme_constant_override("separation", 20)
	choice_header.add_child(chr)
	var cht := Label.new()
	cht.text = "카드 선택"
	cht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cht.add_theme_font_size_override("font_size", 16)
	cht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chr.add_child(cht)
	choice_remaining = Label.new()
	choice_remaining.add_theme_font_size_override("font_size", 16)
	choice_remaining.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	choice_remaining.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chr.add_child(choice_remaining)
	root.add_child(choice_header)

	legend = Label.new()
	legend.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	legend.position = Vector2(-330, 48)
	legend.size = Vector2(320, 380)
	# 터치 화면용 Alt: 누를 때마다 모든 오브젝트 범위·피해 몫 보기 켜기·끄기 (터치를 한 번 쓰면 나타남)
	range_btn = Button.new()
	range_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	range_btn.position = Vector2(-280, 10)
	range_btn.size = Vector2(112, 30)
	range_btn.focus_mode = Control.FOCUS_NONE
	range_btn.add_theme_font_size_override("font_size", 14)
	range_btn.pressed.connect(func(): range_all = not range_all)
	range_btn.visible = false
	root.add_child(range_btn)
	# 확대했을 때만: 1배로 돌아가기
	zoom_btn = Button.new()
	zoom_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	zoom_btn.position = Vector2(-400, 10)
	zoom_btn.size = Vector2(112, 30)
	zoom_btn.focus_mode = Control.FOCUS_NONE
	zoom_btn.add_theme_font_size_override("font_size", 14)
	zoom_btn.pressed.connect(_reset_zoom)
	zoom_btn.visible = false
	root.add_child(zoom_btn)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 긴 줄이 화면 밖으로 잘리지 않게
	legend.add_theme_font_size_override("font_size", 14)
	# 옅은 바탕: 지나가는 구체 위에서도, 글자를 키워(설정) 카드와 겹칠 때도 읽히게
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.02, 0.03, 0.05, 0.85)
	lsb.set_corner_radius_all(5)
	lsb.set_content_margin_all(8)
	legend.add_theme_stylebox_override("normal", lsb)
	legend.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	lsb.content_margin_left = 32.0
	legend.draw.connect(_draw_legend_icons)
	_refresh_legend()
	root.add_child(legend)

	reroll_btn = Button.new()
	reroll_btn.text = "1"
	_icon_btn(reroll_btn, func(): return ["reroll", Color(0.6, 0.85, 1.0)])
	_keycap(reroll_btn, "Q")
	reroll_btn.set_anchors_preset(Control.PRESET_CENTER)
	reroll_btn.position = Vector2(-170, 105)
	reroll_btn.size = Vector2(340, 36)
	reroll_btn.pressed.connect(_on_reroll)
	reroll_btn.visible = false
	reroll_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(reroll_btn)

	apply_btn = Button.new()
	apply_btn.text = "적용"
	apply_btn.set_anchors_preset(Control.PRESET_CENTER)
	apply_btn.focus_mode = Control.FOCUS_NONE
	apply_btn.draw.connect(_draw_apply_icon)
	apply_btn.add_theme_font_size_override("font_size", 17)
	# 선택 조작 줄의 기본 동작을 금색으로 강조
	for st in ["normal", "hover", "pressed"]:
		var asb := StyleBoxFlat.new()
		asb.bg_color = Color(1.0, 0.82, 0.4) if st == "normal" else Color(1.0, 0.9, 0.6)
		asb.set_corner_radius_all(6)
		asb.content_margin_left = 38
		asb.content_margin_right = 12
		apply_btn.add_theme_stylebox_override(st, asb)
	for fc in ["font_color", "font_hover_color", "font_pressed_color"]:
		apply_btn.add_theme_color_override(fc, Color(0.12, 0.09, 0.02))
	apply_btn.pressed.connect(func():
		if tap_sel >= 0 and tap_sel < offer.size():
			_on_pick(offer[tap_sel]))
	apply_btn.visible = false
	apply_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(apply_btn)

	skip_btn = Button.new()
	skip_btn.set_anchors_preset(Control.PRESET_CENTER)
	skip_btn.tooltip_text = "카드 선택을 미루고 웨이브를 연달아 진행합니다. 미룬 카드·새로고침·특성은 멈춘 뒤 한꺼번에 고릅니다\n중앙이 위험해지면(설정) 그 웨이브가 끝나고 멈춥니다"
	skip_btn.pressed.connect(_on_skip)
	_icon_btn(skip_btn, func(): return ["skip", Color(0.75, 0.9, 1.0)])
	_keycap(skip_btn, "S")
	skip_btn.visible = false
	skip_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(skip_btn)
	skip_n_btn = Button.new()
	skip_n_btn.set_anchors_preset(Control.PRESET_CENTER)
	skip_n_btn.tooltip_text = "넘길 웨이브 수 바꾸기 (1·3·5·10)"
	skip_n_btn.pressed.connect(_cycle_skip_n)
	skip_n_btn.visible = false
	skip_n_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(skip_n_btn)
	skip_badge = Button.new()
	skip_badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip_badge.position = Vector2(-210, -146)  # 웨이브 시작 버튼 위
	skip_badge.size = Vector2(420, 36)
	skip_badge.add_theme_color_override("font_color", Color(0.75, 0.9, 1))
	skip_badge.pressed.connect(_toggle_skip_stop)
	skip_badge.visible = false
	root.add_child(skip_badge)

	hide_btn = card_dock.focus_btn  # V·F·화면 버튼이 같은 컨트롤을 사용한다.
	card_detail_btn = Button.new()
	card_detail_btn.set_anchors_preset(Control.PRESET_CENTER)
	card_detail_btn.focus_mode = Control.FOCUS_NONE
	card_detail_btn.add_theme_font_size_override("font_size", 14)
	card_detail_btn.text = "자세히"
	card_detail_btn.toggle_mode = true
	card_detail_btn.button_pressed = Meta.card_detail
	card_detail_btn.tooltip_text = "카드 설명 자세히 (Z): 켜면 설명 전체, 카드에 올리면(터치는 한 번 누르면) 위에 모든 내용"
	card_detail_btn.toggled.connect(_set_card_detail)
	_icon_btn(card_detail_btn, func(): return ["help", Color(1, 0.88, 0.5) if Meta.card_detail else Color(1, 1, 1, 0.7)])
	_keycap(card_detail_btn, "Z")
	card_detail_btn.visible = false
	card_detail_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(card_detail_btn)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# 버튼이 늘어나도 오른쪽 여백(16)을 지키고 왼쪽으로 자란다
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.offset_left = -616.0
	bar.offset_right = -12.0
	bar.offset_top = -48.0
	bar.offset_bottom = -12.0
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	bar_box = bar
	bar.theme = card_dock.controls_theme
	# 글 대신 아이콘 (이름·단축키는 올리면 말풍선)
	fx_pick = OptionButton.new()
	for i in FX_DPS.size():
		fx_pick.add_item("효과 %d%%" % roundi(maxf(0.15, 1.0 - FX_DPS[i]) * 100))
	fx_pick.select(Meta.fx_dps)
	fx_pick.custom_minimum_size = Vector2(104, 36)
	fx_pick.focus_mode = Control.FOCUS_NONE
	fx_pick.tooltip_text = "피해를 적게 주는 오브젝트의 탄·장판 진하기\n(가장 센 오브젝트와 비교해 약할수록 이 값까지 옅어짐. 센 오브젝트는 그대로)"
	fx_pick.item_selected.connect(func(i):
		Meta.fx_dps = i
		_save_best())
	bar.add_child(fx_pick)
	mute_btn = Button.new()
	mute_btn.custom_minimum_size = Vector2(44, 36)
	mute_btn.pressed.connect(_toggle_mute)
	mute_btn.pressed.connect(_icon_toast.bind(mute_btn))
	_icon_btn(mute_btn, func(): return ["mute" if sfx.muted else "sound", Color(1, 1, 1, 0.9)])
	bar.add_child(mute_btn)
	auto_btn = Button.new()
	auto_btn.custom_minimum_size = Vector2(44, 36)
	auto_btn.pressed.connect(_toggle_auto)
	auto_btn.pressed.connect(_icon_toast.bind(auto_btn))
	_icon_btn(auto_btn, func(): return ["auto", Color(0.5, 0.9, 0.6) if auto_start else Color(1, 1, 1, 0.35)])
	bar.add_child(auto_btn)
	pause_btn = Button.new()
	pause_btn.tooltip_text = "일시정지 (P)"
	pause_btn.custom_minimum_size = Vector2(44, 36)
	pause_btn.pressed.connect(_toggle_pause)
	_icon_btn(pause_btn, func(): return ["pause", Color(1, 1, 1, 0.9)])
	bar.add_child(pause_btn)
	speed_group = HBoxContainer.new()
	speed_group.name = "SpeedControls"
	speed_group.add_theme_constant_override("separation", 0)
	bar.add_child(speed_group)
	speed_btn = Button.new()
	speed_btn.custom_minimum_size = Vector2(72, 36)
	speed_btn.pressed.connect(_toggle_speed)
	_icon_btn(speed_btn, func(): return ["speed", Color(1, 0.85, 0.45) if game_speed > 1.0 else Color(1, 1, 1, 0.9)])
	speed_group.add_child(speed_btn)
	speed_pick = OptionButton.new()
	for sp in SPEEDS:
		speed_pick.add_item("x%d" % roundi(sp))
	speed_pick.custom_minimum_size = Vector2(64, 36)
	speed_pick.focus_mode = Control.FOCUS_NONE
	speed_pick.tooltip_text = "빠르게 할 때 배속 (Space로 1배속과 오감)"
	speed_pick.item_selected.connect(_on_speed_pick)
	speed_group.add_child(speed_pick)
	# 맨 오른쪽: 접으면 이것만 남고, 펼치면 왼쪽으로 버튼이 늘어선다
	bar_btn = Button.new()
	bar_btn.custom_minimum_size = Vector2(96, 36)
	bar_btn.pressed.connect(_toggle_bar)
	bar.add_child(bar_btn)
	start_btn = Button.new()
	start_btn.text = "웨이브 시작 (Space)"
	start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	start_btn.position = Vector2(-110, -100)
	start_btn.size = Vector2(220, 44)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_start_wave_from_ready)
	start_btn.visible = false
	root.add_child(start_btn)
	_make_skill_btns(root)
	cancel_btn = Button.new()
	cancel_btn.text = "취소 (Esc)" if OS.has_feature("pc") else "취소"
	cancel_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cancel_btn.position = Vector2(-70, -100)  # 웨이브 시작 버튼 자리 (옮기기·설치 중엔 비어 있다)
	cancel_btn.size = Vector2(140, 40)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(_cancel_step)
	cancel_btn.visible = false
	root.add_child(cancel_btn)
	aim_ok_btn = Button.new()
	aim_ok_btn.text = "확정"
	aim_ok_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	aim_ok_btn.position = Vector2(-70.0 + 150.0, -100.0)  # 취소 오른쪽
	aim_ok_btn.size = Vector2(140, 40)
	aim_ok_btn.add_theme_font_size_override("font_size", 18)
	aim_ok_btn.focus_mode = Control.FOCUS_NONE
	aim_ok_btn.pressed.connect(func():
		if phase == Phase.AIM and aim_wait:
			_confirm_aim())
	aim_ok_btn.visible = false
	root.add_child(aim_ok_btn)
	for button: Button in [reroll_btn, skip_btn, skip_n_btn, hide_btn, card_detail_btn, start_btn, cancel_btn, aim_ok_btn]:
		button.theme = card_dock.controls_theme
	for pair in [[skip_btn, skip_n_btn], [speed_btn, speed_pick]]:
		for button: Button in pair:
			for state_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
				var segment: StyleBoxFlat = button.get_theme_stylebox(state_name).duplicate()
				if button == pair[0]:
					segment.corner_radius_top_right = 0
					segment.corner_radius_bottom_right = 0
					segment.border_width_right = 0
				else:
					segment.corner_radius_top_left = 0
					segment.corner_radius_bottom_left = 0
				button.add_theme_stylebox_override(state_name, segment)
	detail_btn = Button.new()
	detail_btn.theme = card_dock.controls_theme
	detail_btn.custom_minimum_size = Vector2(64, 36)
	detail_btn.focus_mode = Control.FOCUS_NONE
	detail_btn.pressed.connect(func():
		tip_detail = not tip_detail
		touch_tip_t = TOUCH_TIP_SEC * 3.0)  # 자세히는 읽을 게 많아 더 오래
	detail_btn.visible = false
	card_dock.inspector_header.add_child(detail_btn)
	card_dock.inspector_header.move_child(detail_btn, 1)
	for b in [pause_btn, speed_btn, reroll_btn, skip_btn, skip_n_btn, skip_badge, auto_btn, start_btn, mute_btn, cancel_btn, bar_btn]:
		b.focus_mode = Control.FOCUS_NONE
	_update_auto_btn()
	mute_btn.tooltip_text = "소리: " + ("끔" if sfx.muted else "켬") + " (M)"

	# 일시정지 중엔 뒤 화면(카드·설명·큰 글)을 어둡게 덮고 그 위에 글·버튼 (카드가 일시정지 버튼 위에 그려져 겹치던 것)
	pause_dim = ColorRect.new()
	pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dim.color = Color(0.02, 0.02, 0.04, 0.82)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤 카드가 눌리지 않게
	pause_dim.z_index = 20
	pause_dim.visible = false
	root.add_child(pause_dim)
	paused_label = Label.new()
	paused_label.z_index = 21
	paused_label.set_anchors_preset(Control.PRESET_CENTER)
	# 화면 위쪽에 두어 멈춘 채로 가운데 필드의 오브젝트·구체 정보를 볼 수 있게
	paused_label.position = Vector2(-350, -248)  # 점수 줄·보스 막대 아래
	paused_label.size = Vector2(700, 80)  # 글줄이 늘면 아래로 자란다
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paused_label.add_theme_font_size_override("font_size", 20)
	paused_label.add_theme_color_override("font_outline_color", Color.BLACK)
	paused_label.add_theme_constant_override("outline_size", 5)
	paused_label.text = _pause_text()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.03, 0.04, 0.06, 0.85)
	psb.set_corner_radius_all(8)
	paused_label.add_theme_stylebox_override("normal", psb)
	paused_label.visible = false
	root.add_child(paused_label)
	pause_box = HBoxContainer.new()
	pause_box.z_index = 21
	pause_box.set_anchors_preset(Control.PRESET_CENTER)
	pause_box.position = Vector2(-385, -150)  # 글 아래 (_process에서 글 높이에 맞춤)
	pause_box.size = Vector2(770, 60)
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 12)
	# 글 대신 그림 버튼 (키 안내 글 두 줄을 없애고 키는 모서리에). 작은 버튼 셋은 그림만 (이름은 말풍선)
	var pspecs := [["계속", _toggle_pause, "play", "P"], ["튜토리얼", _open_tut_list, "help", ""], ["처음부터", _pause_restart, "restart", "R"], ["판 끝내기", _end_run, "flag", "E"], ["시작 화면", _leave.bind(false), "home", "T"]]
	if OS.has_feature("pc"):
		pspecs.append(["끄기", _leave.bind(true), "power", "X"])  # 모바일은 운영체제가 앱을 닫는다
	pspecs += [["소리 (M)", _toggle_mute, "sound", "M", true], ["설정 (O)", _toggle_settings, "gear", "O", true]]
	if OS.has_feature("pc"):
		pspecs.append(["전체 화면 (F11)", _toggle_fullscreen, "full", "F11", true])
	for spec in pspecs:
		var b := Button.new()
		var small: bool = spec.size() > 4
		b.custom_minimum_size = Vector2(56 if small else 92, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		if small:
			b.tooltip_text = spec[0]
			_icon_btn(b, func(): return [("mute" if sfx.muted else "sound") if spec[2] == "sound" else spec[2], Color(1, 1, 1, 0.85)])
			b.pressed.connect(_icon_toast.bind(b))
		else:
			_menu_glyph(b, spec[2], spec[0])
		_keycap(b, spec[3])
		pause_box.add_child(b)
	pause_box.visible = false
	root.add_child(pause_box)

	info = Control.new()
	info.set_anchors_preset(Control.PRESET_FULL_RECT)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.z_index = 5  # 카드 위에 말풍선이 뜬다
	info.draw.connect(_draw_info)
	root.add_child(info)

	coin_fx = Control.new()
	coin_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	coin_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_fx.z_index = 15  # 카드 줄 버튼(넘기기·필드 보기) 위, 일시정지(20) 아래
	coin_fx.visible = false
	coin_fx.draw.connect(_draw_coin)
	coin_fx.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed:
			_coin_tap()
			coin_fx.accept_event())
	root.add_child(coin_fx)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-400, -140)
	banner.size = Vector2(800, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 40)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner.add_theme_constant_override("outline_size", 6)
	banner.visible = false
	banner.z_index = 16  # 동전 연출(15) 위에 결과 글
	root.add_child(banner)

	over_label = Label.new()
	over_label.set_anchors_preset(Control.PRESET_CENTER)
	over_label.position = Vector2(-450, 70)  # 그림 카드(over_card) 아래
	over_label.size = Vector2(900, 150)
	# 줄이 늘어도 가운데를 지키며 위아래로 자란다
	over_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	over_label.grow_vertical = Control.GROW_DIRECTION_END
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 최다 피해 오브젝트 이름 등이 길면 화면 밖으로 나가던 것: 900 안에서 접는다
	over_label.add_theme_font_size_override("font_size", 18)
	over_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	over_label.visible = false
	root.add_child(over_label)
	# 글이 바뀌어 다시 그려지면(온라인 순위가 나중에 붙는 등) 그림 카드 바탕 높이·나가는 법 줄도 다시
	over_label.draw.connect(func(): if over_card: over_card.queue_redraw())
	# 판 끝난 화면: 다음 패치 투표 (투표 API가 있는 서버일 때만, 자리는 over_label 바로 아래로 매 프레임 맞춤)
	vote_over_btn = Button.new()
	vote_over_btn.set_anchors_preset(Control.PRESET_CENTER)
	vote_over_btn.text = "다음 패치 투표"
	vote_over_btn.focus_mode = Control.FOCUS_NONE
	vote_over_btn.size = Vector2(220, 44)
	vote_over_btn.position = Vector2(-110, 200)
	vote_over_btn.add_theme_font_size_override("font_size", 17)
	vote_over_btn.add_theme_color_override("font_color", Color(1, 0.86, 0.35))
	vote_over_btn.tooltip_text = "이번 판에 쓴 카드 중 다음 패치에서 강해졌으면·약해졌으면·바뀌었으면 하는 것에 투표"
	vote_over_btn.pressed.connect(func(): _toggle_vote(true))
	vote_over_btn.visible = false
	_icon_btn(vote_over_btn, func(): return ["vote", Color(1, 0.86, 0.35)])
	root.add_child(vote_over_btn)
	# 게임 오버 그림 카드: 웨이브·점수 큰 칩, 처치·콤보·오브젝트 작은 칩, 새 업적 배지 (나머지 글은 아래 over_label)
	over_card = Control.new()
	over_card.set_anchors_preset(Control.PRESET_CENTER)
	over_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_card.draw.connect(_draw_over_card)
	over_card.add_to_group("keycap")  # 터치·마우스가 바뀌면 나가는 법 줄을 다시
	over_card.visible = false
	root.add_child(over_card)
	root.move_child(over_card, over_label.get_index())  # 바탕이 남은 글(over_label)을 덮지 않게 글 밑에

	dps_hidden = Meta.dps_fold
	_build_dps(root)
	_build_menu(root)

	# 도움말은 굴려 보는 창 안에 (줄이 많아 화면 높이에 맞춰 줄이면 글자를 읽을 수 없게 작아지던 것).
	# 열고 닫는 것은 그대로 help_label.visible, 창(help_scroll)은 _process에서 따라간다
	help_scroll = ScrollContainer.new()
	help_scroll.z_index = 22  # 일시정지 어둠(z 20) 위에
	help_scroll.set_anchors_preset(Control.PRESET_CENTER)
	help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	help_scroll.visible = false
	help_label = Label.new()
	# 긴 줄은 창 안에서 줄바꿈 (오른쪽 끝이 화면 밖으로 잘리던 것)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_label.add_theme_font_size_override("font_size", 15)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.05, 0.06, 0.09, 1.0)  # 뒤 카드·설명 글자가 비쳐 보이지 않게
	hsb.set_border_width_all(1)
	hsb.border_color = Color(1, 1, 1, 0.25)
	hsb.set_content_margin_all(18)
	hsb.set_corner_radius_all(6)
	help_scroll.add_theme_stylebox_override("panel", hsb)
	help_label.text = _kr_keep(_help_text())
	help_label.visible = false
	help_scroll.add_child(help_label)
	root.add_child(help_scroll)


## 쉬는 시간 왼쪽 위: 지난 웨이브 오브젝트별 DPS 표 (줄은 _refresh_dps가 채운다). 틀은 공용 FloatPanel.
func _build_dps(root: Control) -> void:
	dps_panel = FloatPanel.new("dps", self)
	dps_panel.position = Vector2(10, 60)
	dps_panel.custom_minimum_size.x = 300
	dps_panel.fold_pressed.connect(_toggle_dps)
	dps_panel.moved.connect(func(): dps_sig = "")
	dps_head = dps_panel.title
	dps_scroll = ScrollContainer.new()
	dps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dps_panel.body.add_child(dps_scroll)
	dps_list = VBoxContainer.new()
	dps_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dps_list.add_theme_constant_override("separation", 2)
	dps_scroll.add_child(dps_list)
	dps_panel.visible = false
	root.add_child(dps_panel)


## 기본 자리: 점수 줄 아래 왼쪽.
func _dps_home() -> Vector2:
	var top := hud.position.y + hud.size.y + 8.0 if hud.visible else 8.0
	if mp_bar.visible:
		top += mp_bar.size.y + 4.0
	if mp_act and mp_act.visible:
		top += mp_act.size.y + 4.0
	return Vector2(10, top)


## 옮겨 둔 떠 있는 창(FloatPanel)이 비켜야 할 것 (창 부모 좌표): 점수 줄 칩·오른쪽 아래 버튼·기술 버튼·웨이브 시작 버튼·웨이브 중 콤보 자리.
func _panel_blocks(panel: Control) -> Array[Rect2]:
	var par := panel.get_parent() as Control
	var inv := par.get_global_transform().affine_inverse()
	var blocks: Array[Rect2] = []
	if hud.visible and not hud_chips.is_empty():
		var hb := Rect2()
		for c in hud_chips:
			hb = c[0] if hb.size == Vector2.ZERO else hb.merge(c[0])
		blocks.append(Rect2(hud.position + hb.position, hb.size).grow(4.0))
	var dock_btns: Array = [card_dock.focus_btn, card_dock.skip_group, card_dock.panel, card_dock.footer] if card_dock != null else []
	for c in [bar_box, start_btn, cancel_btn, aim_ok_btn, skip_badge, mp_bar, ver_label, legend] + skill_btns + dock_btns:
		if c != null and c is Control and c.is_visible_in_tree():
			blocks.append((inv * c.get_global_rect()).grow(4.0))
	if phase == Phase.WAVE:
		blocks.append((inv * _combo_rect()).grow(4.0))  # 오른쪽 위 콤보 상자 자리 (웨이브 중엔 언제든 뜰 수 있어 비워 둔다)
	return blocks


func _toggle_dps() -> void:
	if card_dock != null and card_dock.active() and phase == Phase.CHOOSE:
		dps_choice_open = not dps_choice_open
	else:
		dps_hidden = not dps_hidden
		Meta.dps_fold = dps_hidden
	dps_sig = ""
	_save_best()


## 웨이브 중 표본 적기 (게임 시간 기준이라 배속과 상관없이 같은 값).
func _dps_sample(delta: float) -> void:
	dps_t -= delta
	if dps_t > 0.0:
		return
	dps_t += DPS_STEP
	dps_n += 1
	var keep := int(DPS_WIN / DPS_STEP) + 1
	for t in towers.get_children():
		var h: Array = dps_hist.get(t.get_instance_id(), [])
		h.append(t.dealt)
		if h.size() > keep:
			h.pop_front()
		dps_hist[t.get_instance_id()] = h


## 피해 1~3위 (왕관·메달, Tower._draw_rank). 이번 웨이브 누적 피해, 쉬는 시간엔 지난 웨이브 피해(t.dealt가 그 값).
## 웨이브 첫 RANK_HOLD초는 피해가 0부터 다시 쌓이므로 지난 순위를 그대로 둔다. 오브젝트 2개면 1위만, 1개면 없음.
const RANK_STEP := 1.0
const RANK_HOLD := 3.0
func _rank_update() -> void:
	if not Meta.rank_on:
		if not rank_of.is_empty():
			rank_of.clear()
			for t in towers.get_children():
				t.queue_redraw()
		return
	if phase == Phase.WAVE and wave_time < RANK_HOLD:
		return
	var list := towers.get_children().filter(func(t): return t.dealt > 0.0)
	list.sort_custom(func(a, b): return a.dealt > b.dealt)
	var n := 0 if list.size() < 2 else (1 if list.size() < 3 else 3)
	var old_king = null
	for t in towers.get_children():
		if rank_of.get(t.get_instance_id(), 0) == 1:
			old_king = t
	rank_of.clear()
	for i in mini(n, list.size()):
		rank_of[list[i].get_instance_id()] = i + 1
	if n > 0 and old_king != null and old_king != list[0]:
		# 1위가 바뀌면 왕관이 옛 1위 자리에서 새 1위로 날아간다
		list[0].crown_from = old_king.position - list[0].position
		list[0].crown_t = Tower.CROWN_FLY
	for t in towers.get_children():
		t.queue_redraw()


## 표의 초당 피해: 웨이브 중이면 최근 DPS_WIN초 이동 평균, 쉬는 시간이면 지난 웨이브 평균.
func _dps_of(t: Tower) -> float:
	if phase != Phase.WAVE:
		return t.dealt / maxf(wave_time, 0.001)
	var h: Array = dps_hist.get(t.get_instance_id(), [])
	if h.size() < 2:
		return t.dealt / maxf(wave_time, 0.001)
	# 마지막 표본 뒤 흐른 시간까지 넣으면 0.5초마다 톱니처럼 튀므로 표본끼리만 잰다
	return (h[-1] - h[0]) / ((h.size() - 1) * DPS_STEP)


## 표를 보일지, 보이면 오브젝트·피해가 바뀌었을 때만 줄을 다시 만든다 (매 프레임 만들면 마우스 올림이 끊긴다).
func _refresh_dps() -> void:
	var on := phase in [Phase.CHOOSE, Phase.READY, Phase.WAVE] and not title_label.visible and wave_time > 1.0 and towers.get_child_count() > 0 \
		and not get_tree().paused and not help_label.visible and not settings_panel.visible and not records_panel.visible and not notes_panel.visible and not modes_panel.visible
	dps_panel.visible = on
	if not on:
		dps_focus = null
		dps_panel.stop_drag()
		return
	dps_panel.set_touch(touch_ui)
	# 표 밑에 오브젝트가 있으면 마우스를 올리지 않은 동안 옅게, 누르는 자리 밑 오브젝트는 먼저 (점수 줄과 같은 규칙, UI-36)
	dps_panel.cover(true)
	# 기본: 점수 줄 아래, 왼쪽 아래 안내 글 위까지. 옮겨 뒀으면 그 자리(줄 수는 화면 아래까지)
	var home := _dps_home()
	var top := home.y
	var par := dps_panel.get_parent() as Control
	var moved := dps_panel.pinned() or dps_panel.drag == 2
	dps_panel.follow(home, get_process_delta_time())
	var bottom := _bottom_free()
	if moved:
		bottom = par.size.y - 8.0  # 표 높이는 점수 줄 아래~화면 아래만큼까지, 넘치면 dps_panel.place가 위로 올린다
	if not moved and choice_box.visible and not cards_hidden and choice_box.get_child_count() > 0 and choice_box.get_rect().position.x < 320.0:
		bottom = minf(bottom, choice_box.get_rect().position.y - maxf(24.0, _choice_headroom() + 4.0))  # 카드·선택 안내를 덮지 않게 (넘치면 굴려 본다)
	if not moved and apply_btn.visible and apply_btn.get_rect().position.x < dps_panel.get_rect().end.x:
		bottom = minf(bottom, apply_btn.get_rect().position.y - 28.0)  # 폰 [적용] 버튼(누른 카드 위)을 덮지 않게
	if not moved and guide_label.visible and guide_label.get_rect().position.x < 320.0:
		bottom = minf(bottom, guide_label.position.y - 4.0)  # 처음 안내 글 위까지만
	var room := maxf(0.0 if apply_btn.visible else 48.0, bottom - top - dps_panel.head.size.y - 18.0)
	var live := phase == Phase.WAVE
	var list := towers.get_children()
	var dv := {}
	for t in list:
		dv[t] = _dps_of(t)
	list.sort_custom(func(a, b): return dv[a] > dv[b])
	# 웨이브 중엔 1초(표본 2개)마다만 고친다: 숫자가 매 프레임 바뀌면 읽을 수 없고 줄 순서도 덜 뒤바뀐다
	var folded := dps_hidden or (card_dock != null and card_dock.active() and phase == Phase.CHOOSE and not dps_choice_open)
	var sig := "%s|%s|%d|%d" % [folded, live, roundi(room), dps_n / 2 if live else roundi(wave_time)]
	for t in list:
		sig += "|%d:%s" % [t.get_instance_id(), t.title()]
		if not live:
			sig += ":%d" % roundi(t.dealt)
	if sig == dps_sig:
		return
	dps_sig = sig
	dps_head.text = _kh("실시간 DPS (D)" if live else "지난 웨이브 DPS (D)")
	for c in dps_list.get_children():
		c.queue_free()
	dps_panel.set_folded(folded)
	if folded:
		dps_focus = null
		dps_panel.size = Vector2.ZERO
		return
	var total := 0.0
	for t in list:
		total += dv[t]
	for i in list.size():
		var row := _dps_row(list[i], i + 1, dv[list[i]], total, live)
		dps_list.add_child(row)
	var rows := list.size() * 24.0
	dps_scroll.custom_minimum_size.y = minf(rows, room)
	dps_panel.set_pass(dps_panel.passing, true)  # 새 줄도 통과 상태를 따르게
	dps_panel.size = Vector2.ZERO  # 줄이 줄면 판도 줄인다
	if dps_focus != null and not is_instance_valid(dps_focus):
		dps_focus = null


## 표 한 줄: 순위 · 색 · 이름 · 초당 피해 · 몫. 뒤에 몫만큼 막대.
func _dps_row(t: Tower, rank: int, dps: float, total: float, live := false) -> Control:
	var share := dps / total if total > 0.0 else 0.0
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 22)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 6)
	var col := t.color()
	var target: WeakRef = weakref(t)
	row.draw.connect(func():
		var tower: Tower = target.get_ref()
		var hot := tower != null and dps_focus == tower
		row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(1, 1, 1, 0.14 if hot else 0.04))
		row.draw_rect(Rect2(Vector2.ZERO, Vector2(row.size.x * share, row.size.y)), Color(col, 0.28))
		if hot:
			row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(1, 0.9, 0.5, 0.9), false, 1.0))
	row.mouse_entered.connect(func():
		dps_focus = target.get_ref()
		for r in dps_list.get_children():
			r.queue_redraw())
	row.mouse_exited.connect(func():
		if dps_focus == target.get_ref():
			dps_focus = null
		row.queue_redraw())
	var cells := [["%d" % rank, 18, HORIZONTAL_ALIGNMENT_RIGHT, Tower.RANK_COLORS[rank - 1] if rank <= 3 and rank_of.get(t.get_instance_id(), 0) == rank else Color(1, 1, 1, 0.55)],
		["", 0],
		["%.1f" % dps, 52, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.9, 0.5)],
		["%d%%" % roundi(share * 100.0), 36, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 1, 1, 0.7)]]
	for c in cells:
		if c[0] == "":
			row.add_child(_dps_name(t, col))
			continue
		var l := Label.new()
		l.text = c[0]
		l.horizontal_alignment = c[2]
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", c[3])
		if c[1] > 0:
			l.custom_minimum_size.x = c[1]
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size.x = 150
		row.add_child(l)
	if live:
		row.tooltip_text = "%s\n최근 %d초 초당 %.1f · 전체의 %d%%\n이번 웨이브 피해 %d (평균 초당 %.1f)" % [t.title(), roundi(DPS_WIN), dps, roundi(share * 100.0), roundi(t.dealt), t.dealt / wave_time]
	else:
		row.tooltip_text = "%s\n지난 웨이브 피해 %d · 초당 %.1f · 전체의 %d%%" % [t.title(), roundi(t.dealt), dps, roundi(share * 100.0)]
	var b := t.breakdown()
	if t.dealt > 0.0 and not b.is_empty():
		row.tooltip_text += "\n\n%s피해 출처 (초당 · 이 오브젝트의 몫)" % ("이번 웨이브 " if live else "")
		for key in _src_top(b, 5):
			row.tooltip_text += "\n  %s  %.1f · %d%%" % [src_name(key), b[key] / wave_time, roundi(b[key] / t.dealt * 100.0)]
		if b.has("pat:" + t.pattern) and b.size() > 1:
			row.tooltip_text += "\n(직접 타격 안의 배율 몫은 추정)"
	return row


## 표 이름 칸: 글 대신 공격방식 그림 + 속성 그림(레벨 2 이상은 작은 숫자). 이름은 줄 말풍선에.
func _dps_name(t: Tower, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(150, 22)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = true
	var target: WeakRef = weakref(t)
	c.draw.connect(func():
		var tower: Tower = target.get_ref()
		if tower == null:
			return  # 표가 다시 만들어지기 전에 오브젝트가 없어짐 (협동 재접속 등)
		var y := c.size.y / 2.0
		Glyph.pat(c, tower.pattern, Vector2(10, y), 8.0, col.lightened(0.5))
		var x := 22.0
		if tower.plv > 1:
			c.draw_string(ui_font, Vector2(x, y + 4.0), str(tower.plv), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
			x += 9.0
		x += 8.0
		for e in tower.order:
			Glyph.elem(c, e, Vector2(x + 7.0, y), 7.0)
			x += 16.0
			if tower.lv(e) > 1:
				c.draw_string(ui_font, Vector2(x, y + 4.0), str(tower.lv(e)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
				x += 4.0 + 6.0 * str(tower.lv(e)).length()
			x += 3.0)
	return c


## 판 전체 피해 출처 (모든 오브젝트 합).
func _run_src() -> Dictionary:
	var out := {}
	for t in towers.get_children():
		var a: Dictionary = t.all_src()
		for key in a:
			out[key] = out.get(key, 0.0) + a[key]
	return out


# ---------- 빌드 읽기 (2026-10-31 "디펜스 한계 개선 E") ----------
## 이번 판 주력: 판 누적 피해 출처 상위 [키, 몫]. 직접 타격(hit)·무리 보너스 같은 공통 몫은 뺀다.
## 쉬는 시간이 열릴 때만 다시 센다(build_cache) — 점수 줄·카드가 매 프레임 읽는다.
const BUILD_COLOR := Color(0.55, 0.95, 0.95)
const BUILD_MIN := 0.08  # 이 몫 아래면 주력으로 치지 않음
var build_cache: Array = []


func build_top(n: int) -> Array:
	var d := _run_src()
	var tot := 0.0
	for k in d:
		tot += d[k]
	if tot <= 0.0:
		return []
	var keys := d.keys().filter(func(k): return k != "hit" and not str(k).begins_with("etc:"))
	keys.sort_custom(func(a, b): return d[a] > d[b])
	return keys.slice(0, n).map(func(k): return [k, d[k] / tot])


func _refresh_build() -> void:
	build_cache = build_top(5) if wave >= 3 else []


## 카드가 주력(상위 2, 몫 8% 이상) 출처를 키우면 그 이름, 아니면 "". 반응 출처는 그 반응의 두 속성 카드.
func core_fit(card: Dictionary) -> String:
	for it in build_cache.slice(0, 2):
		if it[1] < BUILD_MIN:
			continue
		var k: String = it[0]
		match card["type"]:
			"elem":
				if k == Tower.elem_key(card["e"]):
					return src_name(k)
				if k == "share:" + Patch.ELEM_KEYS[Elem.ALL.find(card["e"])]:
					return src_name(k)
			"pat", "mod", "link", "trig":
				if k == "%s:%s" % [card["type"], card.get("id", "")]:
					return src_name(k)
	return ""


## 피해가 큰 출처 키 n개.
func _src_top(d: Dictionary, n: int) -> Array:
	var keys := d.keys()
	keys.sort_custom(func(a, b): return d[a] > d[b])
	return keys.slice(0, n)


## 피해 출처 키 → 보이는 이름 (elem:fire → 불, share:electric → 특징 튐).
## 상성 색: 강 초록, 약 주황 (Elem.aff_of)
const AFF_COL := {"strong": Color(0.5, 1.0, 0.55), "weak": Color(1.0, 0.68, 0.3)}


static func src_name(key: String) -> String:
	var p := key.split(":")
	if p.size() != 2:
		return key
	match p[0]:
		"elem":
			var i := Patch.ELEM_KEYS.find(p[1])
			return Elem.NAMES[Elem.ALL[i]] if i >= 0 else p[1]
		"pat":
			return Pat.pname(p[1]) if Pat.PATTERNS.has(p[1]) else p[1]
		"mod":
			return Pat.MODS[p[1]]["name"] if Pat.MODS.has(p[1]) else p[1]
		"link":
			return Pat.LINKS[p[1]]["name"] if Pat.LINKS.has(p[1]) else p[1]
		"trig":
			return Pat.TRIGS[p[1]]["name"] if Pat.TRIGS.has(p[1]) else p[1]
		"rx":
			for r in Elem.REACTIONS:
				if r["id"] == p[1]:
					return r["name"]
		"aff":
			for r in Elem.AFF_RULES:
				if r[2] == p[1]:
					return "상성 " + r[3]
		"trait", "share":
			if p[1] == "side":
				return "곁공격"
			if p[1] == "side_big":
				return "큰 곁공격"
			var j := Patch.ELEM_KEYS.find(p[1])
			return ("특징 " + Elem.trait_name(Elem.ALL[j])) if j >= 0 else p[1]
		"etc":
			return {"crowd": "무리(오브젝트 수)", "perk": "특성", "ley": "기맥"}.get(p[1], p[1])
	return p[1]


## 화면 가운데 크게 잠깐 뜨는 글자. 앞 글자가 아직 또렷하면 뒤에 세워 차례로 보여 준다
## (업적 직후 "웨이브 10"이 바로 덮어써 업적을 못 보던 것).
## 글자·버튼 크기: UI를 s배로 그리고, 배치는 화면을 s로 나눈 크기 안에서 한다 (앵커가 그대로 맞는다).
func _apply_ui_scale() -> void:
	var s: float = Meta.ui_scale
	legend_rx_rows = 999  # 글자 크기가 바뀌면 설명 반응 줄 수를 다시 맞춘다
	ui_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# 폰: 노치·둥근 모서리·홈 막대 자리(안전 영역 밖)는 비운다 (화면비를 넓힌 뒤 가장자리 UI가 노치 밑에 깔릴 수 있다)
	var pad := _safe_pad()
	ui_root.position = Vector2(pad.position.x, pad.position.y)
	ui_root.scale = Vector2(s, s)
	ui_root.size = (get_viewport_rect().size - Vector2(pad.position.x + pad.size.x, pad.position.y + pad.size.y)) / s
	# 일시정지 어둠·카드 선택 막은 안전 영역 밖까지 덮는다
	for d in [pause_dim, card_dim]:
		if d:
			d.offset_left = -pad.position.x / s
			d.offset_top = -pad.position.y / s
			d.offset_right = pad.size.x / s
			d.offset_bottom = pad.size.y / s


## 안전 영역 밖 여백 (화면 좌표, position = 왼쪽·위, size = 오른쪽·아래). 폰·태블릿만.
func _safe_pad() -> Rect2:
	if Meta.sim_safe.has_area() or Meta.sim_safe.position != Vector2.ZERO:
		return Meta.sim_safe
	if not OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return Rect2()
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Rect2()
	var k := get_viewport_rect().size / win  # 화면 픽셀 → 뷰포트 좌표
	var l := clampf(safe.position.x, 0.0, win.x * 0.15) * k.x
	var t := clampf(safe.position.y, 0.0, win.y * 0.15) * k.y
	var r := clampf(win.x - safe.end.x, 0.0, win.x * 0.15) * k.x
	var b := clampf(win.y - safe.end.y, 0.0, win.y * 0.15) * k.y
	return Rect2(l, t, r, b)


## 화면보다 커지는 창(줄이 많거나 글자를 키웠을 때)은 줄여서 맞춘다. 가운데 창이라 위아래 여백이 같고, 아래는 버튼 줄을 비운다.
## 세로로만 굴리는 칸에 넣는다 (가로는 내용 폭 그대로)
func _vscroll(inner: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = inner.size_flags_horizontal
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	return sc


## 폰: 창 안 내용을 굴림 칸으로 옮긴다. _fit_panels가 창을 줄이는 대신 굴림 칸 높이를 화면에 맞춘다
func _phone_scroll(p: PanelContainer) -> void:
	if not _phone():
		return
	var inner: Control = p.get_child(0)
	p.remove_child(inner)
	var sc := _vscroll(inner)
	p.add_child(sc)
	panel_scroll[p] = sc


func _fit_panels() -> void:
	if title_box.visible:
		_prep_layout()
		if modes_btn.get_child_count() > 0:
			# 모드 줄 작은 설명이 두 줄로 접히면 버튼도 키운다 (버튼은 안 글 높이를 따라 크지 않는다)
			var mh := (modes_btn.get_child(0) as Control).get_combined_minimum_size().y + 8.0
			modes_btn.custom_minimum_size.y = maxf(64.0 if _phone() else 56.0, mh)
	for c: Control in [title_box, help_scroll, records_panel, settings_panel, notes_panel, modes_panel, codex_panel, vote_panel]:
		if not c.is_visible_in_tree():
			continue
		if panel_scroll.has(c):
			# 폰: 줄이지 않고 화면 높이까지만 키운 뒤 안을 굴린다 (줄이면 글자 6~7pt·토글이 손가락보다 작았다)
			var sc: ScrollContainer = panel_scroll[c]
			var want := minf(sc.get_child(0).get_combined_minimum_size().y, ui_root.size.y - 24.0 - 40.0)
			if absf(sc.custom_minimum_size.y - want) > 0.5:
				sc.custom_minimum_size.y = want
				var ph := want + 40.0
				c.offset_top = -ph / 2.0
				c.offset_bottom = ph / 2.0
			c.scale = Vector2.ONE
			continue
		if c == records_panel and board_box.visible and _phone():
			c.scale = Vector2.ONE  # 리더보드는 _board_fit이 화면에 맞추고 안을 굴린다
			continue
		if c == records_panel and not board_box.visible:
			# 맵별 기록: 창 높이를 글 높이에 맞춘다 (예전엔 610 고정이라 아래 절반이 빈칸)
			var rh := clampf(records_panel.get_line_count() * records_panel.get_line_height() + 40.0, 160.0, 610.0)
			if absf(records_panel.offset_bottom - records_panel.offset_top - rh) > 0.5:
				records_panel.offset_top = -rh / 2.0 - 20.0
				records_panel.offset_bottom = rh / 2.0 - 20.0
		var h: float = c.get_combined_minimum_size().y if c == title_box else c.size.y
		# 글자 크기와 상관없이: 줄이 많으면 시작 화면 아래 버튼 줄·도움말·기록 창이 화면 밖으로 잘리던 것 (아래 구석 버전·소리 버튼 자리를 비운다)
		var k := minf(1.0, (ui_root.size.y - (110.0 if c == title_box else 100.0)) / maxf(1.0, h))
		if c == title_box:
			k = minf(k, (ui_root.size.x - 24.0) / maxf(1.0, c.get_combined_minimum_size().x))
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2(k, k)


## 새 판을 시작할 때 모드가 바꾸는 시작 값 (중앙 체력). 봇이 모드를 바꾼 뒤에도 부른다.
func start_modes() -> void:
	core_max = maxi(1, roundi(Modes.core_max(CORE_MAX_HP) * (float(Rules.tune["mp_core"]) if vs_on or coop_n > 1 else 1.0)))
	core_hp = core_max
	core_disp = float(core_hp)
	danger_lv = 0
	wave_dmg = 0


func big_banner(t: String, col: Color) -> void:
	if banner_t > 0.5:
		if banner_queue.size() < 3:
			banner_queue.append([t, col])
		return
	banner.text = t
	banner.add_theme_color_override("font_color", col)
	banner_t = 1.6


func _show_toast(t: String) -> void:
	toast.text = _kr_keep(t)  # 좁은 자리에서 두 줄로 접힐 때 한글 낱말 중간에서 끊기지 않게
	toast_timer = 2.0


## 점수·남은 구체만 바뀐 때는 0.1초에 한 번만 다시 쓴다. 글자 모양 계산이 비싸 고배속에서 프레임마다 쓰면
## 그것만으로 프레임당 몇 ms (8배속 부하 측정). 웨이브·중앙 체력 등이 바뀌면 바로.
func _update_hud(force := false) -> void:
	var urgent := "%d|%d|%d|%d|%d|%d|%d|%d|%d" % [wave, wave_dmg, core_hp, core_max, phase, towers.get_child_count(), selected.size(), perks.size(), 0]
	if not force and urgent == hud_urgent and hud_cool > 0.0:
		return
	hud_urgent = urgent
	hud_cool = 0.1
	var W := Color(1, 1, 1, 0.92)
	var D := Color(1, 1, 1, 0.6)
	var items: Array = []  # [아이콘, 아이콘 색, 글, 글 색, 말풍선 줄, 새 줄에서 시작?]
	items.append(["wave", Color(0.5, 0.78, 1.0), str(wave), W, [["웨이브", W]], false])
	items.append(["score", Color(1, 0.82, 0.35), num(score), W, [["점수", W]], false])
	var ct := "%d/%d" % [maxi(core_hp, 0), core_max] + ("  -%d" % wave_dmg if wave_dmg > 0 else "")
	var ctip := [["중앙 체력", W]]
	if wave_dmg > 0:
		ctip.append(["이번 웨이브 -%d" % wave_dmg, Color(1, 0.55, 0.55)])
	items.append(["core", Color(1, 0.55, 0.6) if core_hp * 3 <= core_max else W, ct, Color(1, 0.6, 0.6) if wave_dmg > 0 else W, ctip, false])
	items.append(["best", Color(1, 0.82, 0.35, 0.7), "%s · %d" % [num(best_score), best_wave], D, [["최고 기록: 점수 %s · 웨이브 %d" % [num(best_score), best_wave], W]], false])
	if Meta.rules != 1:
		items.append(["tag", D, Rules.NAMES[Meta.rules], D, [["규칙", W]], false])
	if not Modes.on.is_empty():
		items.append(["tag", Color(1, 0.7, 0.4), "x%.2f" % Modes.mul(), Color(1, 0.8, 0.55), [["모드 점수 배율 x%.2f" % Modes.mul(), W]], false])
	if Vary.on or Vary.count() > 0:
		# 판마다 다른 흐름: 지금 이벤트(없으면 봉인 수), 말풍선에 이벤트·예고·봉인·적응
		var vc := Color(0.7, 0.85, 1.0)
		var vt := ["이번 판 흐름 (시험)", W]
		var vl: Array = [vt]
		if not Vary.event.is_empty():
			vl.append(["이벤트 %s: %s" % [Vary.ename(Vary.event), Vary.edesc(Vary.event)], W])
		if not Vary.next_event.is_empty():
			vl.append(["다음 이벤트 %s: %s" % [Vary.ename(Vary.next_event), Vary.edesc(Vary.next_event)], D])
		if Vary.count() > 0:
			vl.append(["봉인: " + Vary.sealed_text(), D])
		var ad := Vary.adapt_text()
		if ad != "":
			vl.append(["적응 구체: " + ad, Color(1, 0.75, 0.6)])
		var txt := Vary.ename(Vary.event) if not Vary.event.is_empty() else ("봉인 %d" % Vary.count() if Vary.count() > 0 else "판 흐름")
		if ad != "":
			txt += " · 적응"
		items.append(["tag", vc, txt, vc, vl, false])
	if MapRule.on():
		# 맵 규칙·친화 카드 (시험): 칩은 규칙 이름, 말풍선에 규칙과 친화
		var mc := MAP_AFF_COLOR
		var rt := MapRule.rule_text()
		items.append(["tag", mc, str(Meta.MAPS[Meta.map_id]["name"]) + " 규칙", mc, [["맵 규칙 (시험)", W], [rt, W], ["친화 카드 (자주 나옴, 속성·공격방식 피해 +%d%%): %s" % [roundi(Rules.t("map_aff_dmg") * 100), MapRule.aff_text()], D]], false])
	if not build_cache.is_empty() and build_cache[0][1] >= BUILD_MIN:
		# 이번 판 주력: 피해 출처 1위와 몫, 말풍선에 상위 5
		var bl: Array = [["이번 판 주력 (판 누적 피해 출처)", W]]
		for it in build_cache:
			bl.append(["%s %d%%" % [src_name(it[0]), roundi(it[1] * 100)], D])
		bl.append(["주력을 키우는 카드에는 ◎ 표시", BUILD_COLOR])
		items.append(["build", BUILD_COLOR, "주력 %s %d%%" % [src_name(build_cache[0][0]), roundi(build_cache[0][1] * 100)], Color(0.8, 1, 1), bl, false])
	var nt := towers.get_child_count()
	if nt > 1:
		var cb := roundi(Rules.crowd_bonus(nt) * MapRule.crowd_k() * 100)
		items.append(["crowd", Color(0.6, 0.9, 0.65), "%d개 +%d%%" % [nt, cb], Color(0.7, 0.95, 0.75), [["오브젝트 수 보너스: %d개, 피해 +%d%%" % [nt, cb], W]], false])
	if phase == Phase.WAVE:
		items.append(["orb", Color(0.85, 0.85, 0.9), str(to_spawn + _alive_count(orbs)), W, [["남은 구체", W]], false])
	# 다음 보스까지 남은 웨이브 (보스 웨이브 중이면 "지금")
	var bl := (ceili(wave / 5.0) * 5 - wave) if phase == Phase.WAVE else (ceili((wave + 1) / 5.0) * 5 - wave)
	if wave > 0 or phase != Phase.WAVE:
		var bt := "다음 웨이브 보스" if bl == 1 and phase != Phase.WAVE else ("이번 웨이브 보스" if bl == 0 else "보스까지 %d웨이브" % bl)
		items.append(["boss", Color(1, 0.6, 0.75), "보스!" if bl == 0 else "보스까지 %d" % bl, Color(1, 0.75, 0.85), [[bt, W]], false])
	if not selected.is_empty():
		items.append(["sel", Color(0.6, 1, 0.7), str(selected.size()), W, [["선택한 오브젝트", W]], false])
	var first := true
	for pk in PERKS:
		var n: int = perks.get(pk["id"], 0)
		if n > 0:
			items.append(["perk", Color(0.75, 0.7, 1.0), pk["name"] + (" x%d" % n if n > 1 else ""), D, [["특성 " + pk["name"] + (" x%d" % n if n > 1 else ""), W], [pk["desc"], D]], first])
			first = false
	# 오른쪽 위 버튼(설명 보기, 터치면 범위 보기) 앞까지. 글자를 키우면(설정) 화면이 좁아진 만큼 줄어든다
	var hud_w := ui_root.size.x - (410.0 if zoom_btn.visible else 300.0 if range_btn.visible else 190.0)  # [확대 풀기]까지 피함
	# 둘째 줄부터는 오른쪽 설명(위에서 48부터) 왼쪽까지 (특성이 많으면 둘째 줄이 설명 글 위로 지나갔다)
	var hud_w2 := minf(hud_w, legend.position.x - 8.0) if legend.visible else hud_w
	var sig := "%s|%s" % [hud_w, hud_w2]
	for it in items:
		sig += "|" + it[2] + str(it[1])
	if sig == hud_sig:
		return
	hud_sig = sig
	var fs := 17
	var x := 0.0
	var y := 0.0
	var right := 0.0
	hud_chips.clear()
	# 핵심 상태는 항상 먼저, 나머지는 별도 줄로 시각적으로 묶는다.
	var primary := items.slice(0, mini(3, items.size()))
	var secondary := items.slice(mini(3, items.size()))
	for it in primary + secondary:
		var w := Icons.chip_w(ui_font, it[2], fs)
		var core_count := mini(3, items.size())
		var core_done := hud_chips.size() >= core_count
		if x > 0.0 and (it[5] or (core_done and y == 0.0) or x + w > (hud_w if y == 0.0 else hud_w2)):
			x = 0.0
			y += 34.0
		hud_chips.append([Rect2(x, y, w, 30.0), it[0], it[1], it[2], it[3], it[4]])
		x += w + 6.0
		right = maxf(right, x)
	hud.size = Vector2(right, y + 30.0)
	hud.queue_redraw()


func _draw_hud() -> void:
	for c in hud_chips:
		Icons.chip(hud, ui_font, c[0], c[1], c[2], c[3], c[4], 17)


# ---------- 단계 ----------

## 큰 숫자를 천 단위 쉼표로 (3864489 → 3,864,489).
static func num(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "," + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if n < 0 else "") + t + out


## 11웨이브부터 구체 체력이 웨이브마다 곱으로 늘어난다 (오브젝트 성장 속도에 맞춤, Rules.hp_growth).
## 후반 (2026-10-31 사용자 "600웨이브쯤이 한계로"): hp_late_from웨이브 뒤로는 x hp_growth_late, 구체 수 상한(orb_n_cap_w)을 넘는 몫은 체력으로 옮긴다.
static func hp_growth(w: int) -> float:
	if w <= 10:
		return 1.0
	var lf := int(Rules.t("hp_late_from"))
	return pow(Rules.hp_growth, mini(w, lf) - 10) * pow(Rules.t("hp_growth_late"), maxi(0, w - lf)) * count_k(w)


## 구체 수 상한으로 줄어든 만큼 구체 하나 체력 배율 (웨이브 전체 체력은 그대로).
static func count_k(w: int) -> float:
	var cw := int(Rules.t("orb_n_cap_w"))
	return 1.0 if w <= cw else float(3 + w * 2) / float(3 + cw * 2)


## 구체 기본 속도 30+3w, orb_spd_cap_w웨이브 값에서 멈춘다.
static func orb_base_speed(w: int) -> float:
	return 30.0 + mini(w, int(Rules.t("orb_spd_cap_w"))) * 3.0


## 저항·굳센 구체 비율: 나오는 웨이브의 처음 비율, 웨이브마다 +, 최대. 온라인 패치 rules "Main.SPECIAL.<이름>"
static var SPECIAL := {
	"resist": 0.3, "resist_step": 0.01, "resist_max": 0.6,  # 저항 구체: 처음 비율, 웨이브마다 +, 최대
	"sturdy": 0.15, "sturdy_step": 0.01, "sturdy_max": 0.4,  # 굳센 구체: 처음 비율, 웨이브마다 +, 최대
}


## 저항 구체(12웨이브~, 버전 4는 8~): 웨이브마다 저항 속성 하나를 정하고 미리 알려 준다.
static func resist_share(w: int) -> float:
	var s := Rules.resist_from
	return 0.0 if w < s else minf(SPECIAL.resist + SPECIAL.resist_step * (w - s), SPECIAL.resist_max)


## 굳센 구체(15웨이브~, 버전 4는 11~): 밀기·감속·기절·냉기 절반.
static func sturdy_share(w: int) -> float:
	var s := Rules.sturdy_from
	return 0.0 if w < s else minf(SPECIAL.sturdy + SPECIAL.sturdy_step * (w - s), SPECIAL.sturdy_max)


## 고른 규칙 버전을 적용한다 (시작 화면에서 바꿀 때, 새 판마다).
func _apply_rules() -> void:
	Patch.commit()  # 받아 둔 온라인 패치는 새 판을 시작할 때 적용
	Rules.apply(Meta.rules)
	Modes.apply_rules()
	Vary.new_run(false)  # 판마다 다른 흐름: 일반 새 판에서만 켠다 (_on_rest_start), 이어하기는 저장에서
	Tower.tax_step = Rules.tax_step
	Tower.harmony_cap = _perk_val("harmony_cap")
	if legend:
		_refresh_legend()
	if ver_label:
		ver_label.text = _ver_text()
	if help_label:
		help_label.text = _kr_keep(_help_text())
		help_touch = touch_ui


## 도움말: 상한·장수는 고른 규칙 버전에 따라 다르다.
func _help_text() -> String:
	var elems := "속성 %d종까지, 레벨은 제한 없음" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "종류 제한 없음"
	var mods := "강화는 종류마다 %d개, 한 오브젝트에 합쳐 %d개까지" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "강화는 제한 없이 쌓이지만 쌓을수록 효과가 절반씩"
	var keys := [
		"[조작]",
		"1 / 2 / 3 또는 클릭: 카드 선택     Q: 선택지 새로고침     V: 선택지 내리고 필드 보기",
		"S: 웨이브 넘기기 — 카드 선택을 미루고 웨이브 n개(1·3·5·10)를 연달아 진행, 멈추면 쌓인 특성·카드·새로고침을 한꺼번에 (넘기는 중 S: 멈추기)",
		"속성 카드: 빈 곳에 설치(직선탄) → 클릭(또는 끌어서 놓기)으로 방향, Shift: 15도",
		"속성 카드를 오브젝트 위에: 속성 겹치기 (%s)" % elems,
		"공격방식·강화·연계 카드: 오브젝트 위에 놓기 (효과가 없는 강화는 못 넣음: 관통 연사·돌풍·철구에 관통·튕김, 벽에 유도, 벽·투척 장판에 분열)",
		"오브젝트 끌기: 방향은 그대로 두고 옮기기 (카드를 고른 뒤에는 꾹 눌러서)",
		"빈 곳 끌기 / Shift·Ctrl+클릭 / Ctrl+A(모두): 여러 개 선택 → 그중 하나를 끌면 함께 이동",
		"오브젝트 클릭: 선택 · 쉬는 시간에 선택한 오브젝트를 한 번 더 클릭하거나 상세의 [방향 변경]: 방향 바꾸기 · 선택한 오브젝트 위에서 휠: 15도씩 돌리기(Shift: 5도) · 우클릭한 채 끌기: 바로 조준",
		"Alt 누르고 있기: 모든 오브젝트의 공격 범위·피해 비율 보기     우클릭 / Esc: 한 단계 되돌리기, 선택 해제",
		"왼쪽 위 DPS 표: 웨이브 중엔 최근 5초 실시간 DPS, 쉬는 시간엔 지난 웨이브 DPS와 비율. 줄에 마우스를 올리면 그 오브젝트를 짚어 줌   D: 표 접기·펴기 (저장됨)",
		"Space: 웨이브 시작(자동 시작 끔일 때) / 웨이브 중 빠르게 켜기·끄기 (배율은 오른쪽 아래에서 x2~x8)",
		"F / V: 카드 패널 보기·접기   P / Esc: 일시정지(시작 화면으로·끄기)   M: 소리   O: 설정   H: 도움말   K: 도감(시작 화면)   F11: 전체 화면",
		"R: 처음부터 (일시정지 중 두 번) · 게임 오버 뒤 클릭·R·Esc: 시작 화면 (멀티 판은 대기방)",
		"E: 판 끝내기 (일시정지 중 두 번) — 지금 점수로 게임 오버, 기록·온라인 순위에 올라감",
		"쉬는 시간마다 자동 저장: 게임을 꺼도 시작 화면의 이어하기(Enter)로 그 쉬는 시간부터 (새로 시작은 N 두 번)",
		"첫 판은 카드가 단계별로 열려요 (공격방식 3·강화 4·연계 6웨이브)",
		"처음 생기는 일엔 위쪽에 한 줄 안내 (설정에서 끄기·처음부터 다시 보기)",
		"튜토리얼: 시작 화면 [튜토리얼]·일시정지에서 항목별로 다시 보기",
		"도감(시작 화면)에서 ☆로 선호 표시: 그 카드·조합이 선택지에 나오면 반짝여요",
	]
	# 폰·태블릿: 키보드·마우스 안내 대신 버튼·누르기로
	var touch := [
		"[조작 · 터치]",
		"카드 누르기: 카드 선택   [새로고침]: 선택지 바꾸기   [필드 보기]: 카드를 내리고 필드 보기",
		"화면 아래 [전장 넓게] / [패널 보기]: 카드·설명 패널 접기·복구",
		"[웨이브 n개 넘기기]: 카드 선택을 미루고 웨이브 n개(1·3·5·10)를 연달아 진행, 멈추면 쌓인 특성·카드·새로고침을 한꺼번에 (넘기는 중 아래 표시를 누르면 멈춤)",
		"속성 카드: 빈 곳을 눌러 설치(직선탄) → 쏠 쪽을 누르거나 끌어서 놓아 방향",
		"속성 카드를 오브젝트 위에: 속성 겹치기 (%s)" % elems,
		"공격방식·강화·연계 카드: 오브젝트를 눌러 넣기 (효과가 없는 강화는 못 넣음: 관통 연사·돌풍·철구에 관통·튕김, 벽에 유도, 벽·투척 장판에 분열)",
		"오브젝트 누르기: 선택 · 쉬는 시간에 선택한 오브젝트를 한 번 더 누르기: 쏠 방향 바꾸기   누른 채 끌기: 옮기기 (방향은 그대로)",
		"[취소]: 한 단계 되돌리기   [범위 보기]: 모든 오브젝트의 공격 범위·피해 비율",
		"왼쪽 위 DPS 표: 웨이브 중엔 최근 5초 실시간 DPS, 쉬는 시간엔 지난 웨이브 DPS와 비율. 제목을 누르면 접기·펴기 (저장됨)",
		"오른쪽 아래 [◀ 설정]: 소리·자동 시작·일시정지(시작 화면으로·판 끝내기·처음부터)·배속(x2~x8)",
		"쉬는 시간마다 자동 저장: 게임을 꺼도 시작 화면의 [이어하기]로 그 쉬는 시간부터",
		"첫 판은 카드가 단계별로 열려요 (공격방식 3·강화 4·연계 6웨이브)",
		"처음 생기는 일엔 위쪽에 한 줄 안내 (설정에서 끄기·처음부터 다시 보기)",
		"튜토리얼: 시작 화면 [튜토리얼]·일시정지에서 항목별로 다시 보기",
		"도감(시작 화면)에서 ☆로 선호 표시: 그 카드·조합이 선택지에 나오면 반짝여요",
	]
	return "\n".join((touch if touch_ui else keys) + [
		"",
		"[규칙 · %s]" % Rules.NAMES[Rules.version],
		"중앙 체력 10. 구체가 닿으면 줄어듭니다",
		"쉬는 시간마다 3개 중 1개를 고릅니다 (처음 두 번은 %d번)" % Rules.open_picks if Rules.picks == 1 else "쉬는 시간마다 3개 중 1개씩 %d번 고릅니다" % Rules.picks,
		"5웨이브마다 보스. 처치하면 체력 +2, 새로고침 +1",
		"콤보: 게임 시간 3초 안에 다음 구체를 잡으면 이어져요 (어느 오브젝트가 잡든, 배속과 상관없이). 쉬는 시간엔 멈춰서 다음 웨이브로 이어져요. 콤보마다 처치 점수 +10%, 콤보 20부터 x3. 오른쪽 위 상자에 배율과 남은 시간",
		"보스 웨이브를 넘기면 특성(모든 오브젝트에 붙는 강화) 3개 중 1개 선택",
		"공격방식은 직선탄일 때 한 번만 정할 수 있고, 같은 것을 넣으면 레벨업",
		"속성을 많이 겹칠수록 피해는 늘고 공격 속도는 조금씩 느려집니다. 오브젝트가 많을수록 모든 오브젝트의 피해가 늘어요(오브젝트 수 보너스, 5개 +16%% · 10개 +23%%, 늘수록 덜 오름). %s" % mods,
		"감속은 최대 70%, 밀기는 조금씩만. 기절·속박·얼림은 연달아 걸릴수록 짧아지다가 잠깐 면역",
		"화면 밖 구체는 맞지 않습니다. 시작 화면에서 규칙(랭크·도파민 모드)%s과 맵%s을 바꿀 수 있어요" % (["", ""] if touch_ui else ["(↑/↓)", "(←/→)"]),
		"모드(첫 판 뒤): 어렵게 하면 점수 배율이 오르고, 쉽게 하면 내려가요 (쉽게 모드 판은 기록 따로)",
	])


## 실행 중인 빌드가 최신인지 알아보도록 구석에 표시 (버전은 project.godot의 config/version).
func _ver_text() -> String:
	return "빈두 v%s · 규칙 %s" % [ProjectSettings.get_setting("application/config/version", "?"), Rules.NAMES[Meta.rules]]


## 웨이브 구체 수: 기존 공식 3 + 2w. 150웨이브 이후에는 기존처럼 수를 고정하고 초과 몫은 체력으로 반영한다.
static func wave_size(w: int) -> int:
	return 3 + mini(w, int(Rules.t("orb_n_cap_w"))) * 2


## 실제로 나오는 구체 수 (규칙 버전 배율, 십자로 맵 1.5배). 미리보기와 웨이브가 같은 값을 쓴다.
static var coop_orbs := 1.0  # 협동: 인원만큼 구체가 늘어난다 (Rules coop_orb_per: 2명 x1.6, 3명 x2.2, 4명 x2.8)
static var coop_n := 1  # 협동 인원 (혼자·대결은 1)
static var vs_on := false  # 대결 판 (구체 체력·속도에 Rules vs_hp·vs_spd)


## 대결 판에서만 쓰는 구체 배율 (혼자·협동은 1).
static func vs_k(key: String) -> float:
	return float(Rules.tune[key]) if vs_on else 1.0


## 협동 구체 체력 배율: 인원만큼 + 웨이브마다 크게 올라 판이 짧게 끝난다 (Rules coop_hp_per·coop_ramp).
static func coop_hp_k(w: int) -> float:
	if coop_n <= 1:
		return 1.0
	return (1.0 + float(Rules.tune["coop_hp_per"]) * (coop_n - 1)) * pow(float(Rules.tune["coop_ramp"]), maxi(0, w - 1))


static func spawn_count(w: int) -> int:
	var n := roundi(wave_size(w) * Rules.orb_mul * coop_orbs)
	# 새 진입 방향이 열리는 웨이브는 구체를 조금 덜 (새 길목을 막을 시간)
	if not Meta.map_id in ["cross", "line"] and lanes_for(w) > lanes_for(w - 1):
		n = roundi(n * 0.8)
	if Meta.map_id == "cross":
		n = roundi(n * 1.5)
	elif Meta.map_id == "line":
		n = roundi(n * LINE_ORBS)
	return n


## 웨이브 w의 진입 방향 수: 3웨이브마다 하나씩 늘어 4곳, 이후 6웨이브마다 하나씩 최대 6곳.
## 새 구체 종류(빠른 4·단단한 7·보호막 8·분열 12)와 겹치지 않게 3·6·9웨이브(이후 18·24)에 열린다.
static func lanes_for(w: int) -> int:
	return mini(mini(1 + w / 3, 4 + maxi(0, (w - 12) / 6)), 6)


func _start_choose(new_round := true) -> void:
	if new_round and wave == 0:
		# 새 판. 헤드리스(봇·점검)는 늘 모두 열린 채로
		tutor = Meta.tutor_next and DisplayServer.get_name() != "headless" and not TutPlay.on
		tutor_given = {}
		start_modes()
		Vary.new_run(mp_mode == "" and not tutor and not TutPlay.on)
		if Vary.count() > 0:
			_show_toast("봉인: " + Vary.sealed_text())
			toast_timer = 5.0  # 카드 줄 위 봉인 칩에도 계속 보임 (_draw_seal_chip)
		run_id = _new_run_id()
		Ach.new_run()
		legacy_grow = false
		_skills_new_run(Meta.skill_set)
		_ley_new_run()
	if new_round and tutor and wave + 1 >= TUTOR_OPEN.values().max() and Meta.tutor_next:
		Meta.tutor_next = false  # 모두 열렸다: 다음 판부터는 처음부터 모두
		_save_best()
	if new_round:
		_new_rest()
		_take_bank()
	phase = Phase.CHOOSE  # 웨이브를 막 끝낸 때도 카드 안내가 쉬는 시간 안내로 뜨게 (_open_choose가 다시 정함)
	_make_choices()
	_open_choose()
	_save_run()
	if new_round:
		_rest_guides()


## 새 쉬는 시간: 다음 웨이브(방향·저항·보스)를 뽑고 고르기·새로고침 수를 정한다.
func _new_rest() -> void:
	_refresh_build()
	if mp_seed != 0:
		wrng.seed = hash([mp_seed, wave])  # 대결: 모두 같은 웨이브 (방향·저항·보스·구체)
	if mp_ghost:
		_mp_ghost_rest()  # 협동 참가자: 다음 웨이브는 호스트가 정한 것
	else:
		if wave > 0:
			for msg in Vary.rest(wave):
				_show_toast(msg)
			if MapRule.is_map("spiral") and wave % 5 == 0:
				_show_toast("회오리: 다음 웨이브부터 회전 방향이 반대로 바뀌어요")
		_roll_lanes()
		# 다음 웨이브 저항 속성: 12웨이브(버전 4는 8)부터 60% 확률
		wave_resist = _wpick(Elem.ALL) if wave + 1 >= Rules.resist_from and wf() < 0.6 else -1
		_plan_boss()
	_mp_rest_begin()
	picks_left = maxi(Rules.open_picks, Rules.picks) if wave <= 1 else Rules.picks  # 처음 두 번의 쉬는 시간은 2개씩, 그 뒤 1개 (모드 '두 장'이면 계속 2개)
	if TutPlay.on and tplay != null and tplay.rest_picks(wave) >= 0:
		picks_left = tplay.rest_picks(wave)  # 플레이 튜토리얼: 그 쉬는 시간의 카드 단계 수
	rerolls_left = Modes.rerolls(1 + bonus_rerolls + perks.get("reroll", 0) * int(_perk_val("reroll")))
	bonus_rerolls = 0


# ---------- 웨이브 넘기기 ----------

## 넘기기를 쓸 수 있나: 오브젝트가 있고, 첫 판이면 카드 종류가 다 열린 뒤.
func _can_skip() -> bool:
	if mp_mode != "":
		return false  # 멀티플레이는 웨이브 넘기기 없음 (협동은 함께, 대결은 같은 웨이브 순서)
	return towers.get_child_count() > 0 and not (tutor and wave + 1 < TUTOR_OPEN.values().max()) and skip_left == 0


## 선택지(또는 특성) 화면에서 넘기기: 이번 쉬는 시간의 고르기를 쌓아 두고 웨이브를 시작한다.
func _on_skip() -> void:
	if phase not in [Phase.CHOOSE, Phase.READY] or not _can_skip() or title_label.visible or get_tree().paused:
		return
	if TutPlay.on and tplay != null and not tplay.allow_skip():
		_show_toast("웨이브 넘기기는 튜토리얼 마지막 장에서 해 봐요")
		return
	if perk_mode:
		perk_mode = false
		bank_perks += 1
		if not rest_ready:
			_new_rest()  # 특성 뒤에 올 카드 고르기도 같이 쌓는다
			_take_bank()
	skip_total = int(Meta.skip_n)
	skip_left = skip_total
	skip_stop = false
	_bank_rest()
	_show_toast("웨이브 %d개 넘기기: 카드 선택은 멈춘 뒤 한꺼번에 (%s)" % [skip_total, "아래 표시를 누르면 멈춤" if touch_ui else "S: 멈추기"])


## 이번 쉬는 시간의 남은 고르기·새로고침을 쌓고 바로 다음 웨이브로 (1초 뒤 시작).
## picks_left에는 이미 쌓인 고르기(bank_picks)도 들어 있다.
func _bank_rest() -> void:
	for i in picks_left - bank_picks.size():
		bank_picks.append(wave)
	picks_left = 0
	bank_rerolls += rerolls_left
	rerolls_left = 0
	offer.clear()
	for c in choice_box.get_children():
		c.queue_free()
	rest_ready = false
	cards_hidden = false
	_enter_ready()
	countdown = 1.0


## 넘기는 중에 웨이브가 끝났다: 고르지 않고 다음 쉬는 시간을 쌓는다.
func _skip_rest() -> void:
	if wave % 5 == 0:
		bank_perks += 1
	wave_active = false
	_clear_shots()  # 쉬는 시간처럼 남은 탄·장판을 지운다
	_new_rest()
	_take_bank()
	_update_preview()
	_bank_rest()


## 쌓아 둔 고르기·새로고침을 이번 쉬는 시간에 더한다.
func _take_bank() -> void:
	picks_left += bank_picks.size()
	rerolls_left += bank_rerolls
	bank_rerolls = 0


## 넘기기를 끝내고 쌓인 것을 연다: 특성부터 하나씩, 그다음 카드.
## now_rest: 이번 쉬는 시간의 다음 웨이브를 이미 뽑아 둔 채(넘기기 대기 중) 멈췄나.
func _end_skip(now_rest: bool) -> void:
	if not now_rest and not skip_stop:
		Ach.on_skip_done(skip_total)  # 멈추지 않고 끝까지 넘김
	skip_left = 0
	skip_stop = false
	countdown = -1.0
	start_btn.visible = false
	if now_rest:
		rest_ready = true
		picks_left = 0
		_take_bank()
	if not now_rest and wave % 5 == 0:
		_start_perk()  # 이번 쉬는 시간의 특성 (미룬 특성은 그 뒤에 이어서)
	elif bank_perks > 0:
		bank_perks -= 1
		_start_perk()
	else:
		_start_choose(not now_rest)


## 넘기는 중 멈추기: 웨이브 중이면 그 웨이브 뒤에, 다음 웨이브를 기다리는 중이면 바로.
func _toggle_skip_stop() -> void:
	if skip_left <= 0:
		return
	if phase == Phase.READY:
		_end_skip(true)
		return
	skip_stop = not skip_stop
	_show_toast("이번 웨이브가 끝나면 넘기기를 멈춰요" if skip_stop else "넘기기를 계속해요")


func _cycle_skip_n() -> void:
	var i := SKIP_NS.find(int(Meta.skip_n))
	Meta.skip_n = SKIP_NS[(i + 1) % SKIP_NS.size()]
	_save_best()


## 넘기기 버튼·넘기는 중 표시 (매 프레임).
func _update_skip_ui() -> void:
	# 카드를 다 고른 뒤(웨이브 시작 대기)에도 [웨이브 시작] 옆에서 넘기기를 쓸 수 있다
	var ready_skip := phase == Phase.READY and skip_left == 0
	var show_btn := (phase == Phase.CHOOSE and not cards_hidden or ready_skip) and not title_label.visible and _can_skip() and not get_tree().paused and coin_stage == 0
	skip_btn.visible = show_btn
	skip_n_btn.visible = show_btn
	# 글자를 키우면(폰 기본) 카드 아래 버튼 줄이 왼쪽 아래 안내 글까지 내려와 겹친다. 카드를 고르라는 글이라 겹칠 때만 숨긴다
	hint.visible = not (show_btn and hint.get_global_rect().intersects(skip_btn.get_global_rect()))
	if show_btn:
		var n := int(Meta.skip_n)
		var deferred := "특성 선택 1회 보류" if perk_mode else "카드 선택 %d회 보류 · 새로고침 %d회 보류" % [picks_left, rerolls_left]
		skip_btn.tooltip_text = "%d웨이브 넘기기 (S)\n%s\n미룬 카드·새로고침·특성은 멈춘 뒤 한꺼번에 고릅니다. 중앙이 위험해지면(설정) 그 웨이브가 끝나고 멈춥니다" % [n, deferred]
		skip_btn.text = "넘기기"
		skip_n_btn.text = "%d웨이브 ▸" % n
	skip_badge.visible = skip_left > 0 and phase in [Phase.WAVE, Phase.READY] and not title_label.visible
	if skip_badge.visible:
		var done := skip_total - skip_left + 1
		var cards := bank_picks.size()
		var extra := " · 특성 %d" % bank_perks if bank_perks > 0 else ""
		if skip_stop:
			skip_badge.text = _kh("이번 웨이브 뒤 멈춤 · 쌓인 카드 %d%s (S: 계속)" % [cards, extra], true)
		elif phase == Phase.READY:
			skip_badge.text = _kh("넘기는 중 %d/%d · 쌓인 카드 %d%s (S: 지금 멈추고 선택)" % [done, skip_total, cards, extra], true)
		else:
			skip_badge.text = _kh("넘기는 중 %d/%d · 쌓인 카드 %d%s (S: 멈추기)" % [done, skip_total, cards, extra], true)


## 선택지 화면을 연다 (offer는 이미 정해져 있음).
func _open_choose() -> void:
	phase = Phase.CHOOSE
	wave_active = false
	_clear_shots()
	for t in towers.get_children():
		t.queue_redraw()
	_update_preview()
	cards_hidden = false
	choice_box.visible = true
	_update_reroll_btn()
	hint.text = _th(_choose_hint())


## 쉬는 시간이 되면 남은 탄·장판을 지운다.
func _clear_shots() -> void:
	for p in projectiles.get_children():
		p.queue_free()
	for z in zones.get_children():
		z.queue_free()


func _make_choices() -> void:
	offer.clear()
	var guard := 0
	while offer.size() < 3 and guard < 50:
		guard += 1
		var card := _roll_card()
		if card.is_empty():
			break
		if not _card_enabled(card):
			continue
		# 넣을 곳이 없는 공격방식·강화 카드는 내지 않는다
		if card["type"] in ["pat", "mod", "trig"] and not _my_towers().any(func(t): return t.can_take(card)):
			continue
		if _star_blocked(card):  # 별·행성이 다 찼고 레벨업할 별도 없으면 별 카드는 내지 않는다
			continue
		# 같은 속성은 레벨만 다르게 두 장 나오지 않게: 높은 레벨 한 장만 남긴다
		var same := offer.filter(func(cd): return _card_key(cd) == _card_key(card))
		if same.is_empty():
			offer.append(card)
		elif card.get("lv", 1) > same[0].get("lv", 1):
			offer[offer.find(same[0])] = card
	# 속성 카드(새 오브젝트를 놓을 수 있는 카드)는 최소 1장
	if not offer.any(func(cd): return cd["type"] == "elem"):
		var pool: Array = Vary.open("elem", Elem.ALL).filter(func(e): return _card_enabled({"type": "elem", "e": e}) and not _star_blocked({"type": "elem", "e": e}))
		if not pool.is_empty():
			var fallback := {"type": "elem", "e": MapRule.pick("elem", pool), "lv": 1}
			if offer.is_empty():
				offer.append(fallback)
			else:
				offer[randi() % offer.size()] = fallback
	if tutor:
		_tutor_offer()
	if TutPlay.on and tplay != null:
		offer = tplay.offer(offer)  # 연습 판: 이번 단계 카드 + 흐린 카드 두 장
	_show_offer()
	_card_guides()


## 카드 줄 위 봉인 칩 (봉인 모드): 봉인된 속성(그림 + 이름)·공격방식(그림 + 이름)·연계 이름. cx 가운데, bottom 칩 아래 끝.
func _draw_seal_chip(ci: CanvasItem, cx: float, bottom: float) -> Rect2:
	var fs := 14
	var items: Array = []  # [그리기 종류, id, 글, 색]
	for e in Vary.sealed["elem"]:
		items.append(["e", e, Elem.NAMES[e], Elem.COLORS[e]])
	for p in Vary.sealed["pat"]:
		items.append(["p", p, Pat.pname(p), Pat.pcolor(p).lightened(0.15)])
	for l in Vary.sealed["link"]:
		items.append(["l", l, Pat.LINKS[l]["name"], Color(0.55, 0.9, 1.0)])
	var head := "봉인"
	var hw := ui_font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var widths: Array = []
	var w := 12.0 + hw + 10.0
	for it in items:
		var iw: float = (0.0 if it[0] == "l" else 18.0) + ui_font.get_string_size(it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(iw)
		w += iw + 10.0
	w += 2.0
	var r := Rect2(cx - w / 2.0, bottom - 26.0, w, 26.0)
	r.position.x = clampf(r.position.x, 8.0, maxf(8.0, info.size.x - w - 8.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.12, 0.97)
	sb.border_color = Color(0.7, 0.7, 1.0, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	ci.draw_style_box(sb, r)
	var cy := r.position.y + 13.0
	var x := r.position.x + 12.0
	ci.draw_string(ui_font, Vector2(x, cy + fs * 0.36), head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.8, 0.8, 1.0))
	x += hw + 10.0
	for i in items.size():
		var it: Array = items[i]
		var col: Color = it[3]
		if it[0] == "e":
			Glyph.elem(ci, it[1], Vector2(x + 7.0, cy), 7.0)
		elif it[0] == "p":
			Glyph.pat(ci, it[1], Vector2(x + 7.0, cy), 7.0, col)
		var tx := x + (0.0 if it[0] == "l" else 18.0)
		ci.draw_string(ui_font, Vector2(tx, cy + fs * 0.36), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		# 봉인: 이름 위에 가로줄
		var tw: float = ui_font.get_string_size(it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_line(Vector2(tx - 1.0, cy), Vector2(tx + tw + 1.0, cy), Color(col, 0.7), 1.5)
		x += widths[i] + 10.0
	return r


## 첫 판: 이번 웨이브에 새로 열린 카드 종류를 처음 한 번은 선택지에 꼭 넣는다 (속성 카드 하나는 남김).
func _tutor_offer() -> void:
	for k in ["pat", "mod", "trig", "link"]:
		if wave + 1 < TUTOR_OPEN[k] or tutor_given.has(k):
			continue
		if not offer.any(func(cd): return cd["type"] == k):
			var cd := _tutor_card(k)
			if cd.is_empty():
				continue
			var elems := offer.filter(func(c): return c["type"] == "elem").size()
			for i in range(offer.size() - 1, -1, -1):
				if offer[i]["type"] != "elem" or elems > 1:
					offer[i] = cd
					break
		tutor_given[k] = true


## 넣을 곳이 있는 그 종류 카드 한 장 (없으면 빈 사전).
func _tutor_card(k: String) -> Dictionary:
	var ids: Array = []
	match k:
		"pat": ids = Pat.PATTERN_IDS.slice(1)
		"mod": ids = Pat.MOD_IDS.duplicate()
		"link": ids = ["pincer"] if towers.get_child_count() >= 2 else ["reso"]
		"trig": ids = Pat.TRIG_IDS.duplicate()
	ids.shuffle()
	for id in ids:
		var cd := {"type": k, "id": id}
		if _card_enabled(cd) and (k == "link" or towers.get_children().any(func(t): return t.can_take(cd))):
			return cd
	return {}


## 첫 판에는 아직 안 열린 카드 종류.
func _card_open(k: String) -> bool:
	return not tutor or wave + 1 >= TUTOR_OPEN[k]


## 카드 [자세히] 켜기·끄기: 지금 선택지를 같은 카드로 다시 그린다 (새로 뽑지 않음).
func _set_card_detail(on: bool) -> void:
	Meta.card_detail = on
	card_detail_btn.set_pressed_no_signal(on)
	_save_best()
	if phase == Phase.CHOOSE and not perk_mode and not offer.is_empty():
		var sel := tap_sel
		_show_offer()
		tap_sel = sel
		_tap_hover.call_deferred()


## 선택지 카드 버튼을 offer대로 다시 만든다.
func _show_offer() -> void:
	var last_preview := card_dock.preview_card() if card_dock != null else {}
	var retained: Button = null
	tap_sel = -1
	for c in choice_box.get_children():
		c.queue_free()
	for i in offer.size():
		var button := _card_button(offer[i], i + 1)
		choice_box.add_child(button)
		if offer[i] == last_preview:
			retained = button
	if card_dock != null:
		card_dock.hovered = retained


## 같은 선택지인지 비교하는 키 (레벨은 무시).
func _card_key(card: Dictionary) -> String:
	return "%s:%s" % [card["type"], card.get("e", card.get("id", ""))]


## 온라인 패치의 카드 사용 여부. 미지정 카드는 기존처럼 사용한다.
func _card_enabled(card: Dictionary) -> bool:
	var kind := str(card.get("type", ""))
	var id := str(card.get("id", ""))
	if kind == "elem":
		var e := int(card.get("e", -1))
		if e < 0 or e >= Patch.ELEM_KEYS.size():
			return false
		id = Patch.ELEM_KEYS[e]
	return Patch.num("card_enabled", "%s.%s" % [kind, id], 1.0) >= 0.5


## 선택지 한 장: 속성 / 공격방식 / 강화 / 연계 중 하나.
func _roll_card() -> Dictionary:
	var ts := _my_towers()
	var n := ts.size()
	var elems: Array = Vary.open("elem", Elem.ALL).filter(func(e): return _card_enabled({"type": "elem", "e": e}))
	if elems.is_empty():
		return {}
	var patterns: Array = Vary.open("pat", Pat.PATTERN_IDS.slice(1)).filter(func(id):
		var cd := {"type": "pat", "id": id}
		return _card_enabled(cd) and ts.any(func(t): return t.can_take(cd)))
	var mods: Array = Pat.MOD_IDS.filter(func(id):
		var cd := {"type": "mod", "id": id}
		return _card_enabled(cd) and ts.any(func(t): return t.can_take(cd)))
	var trigs: Array = Pat.TRIG_IDS.filter(func(id):
		var cd := {"type": "trig", "id": id}
		return _card_enabled(cd) and ts.any(func(t): return t.can_take(cd)))
	var links: Array = (Pat.LINK_IDS if n >= 2 else ["reso"]).filter(func(id):
		return _card_enabled({"type": "link", "id": id}) and not Vary.is_sealed("link", id))
	# 비활성 카드와 현재 넣을 수 없는 카드는 확률 풀에서 빼고 남은 종류끼리 비율을 다시 맞춘다.
	var we := Patch.num("cards", "elem", 0.42)
	var wp := Patch.num("cards", "pat", 0.25) if _card_open("pat") and not patterns.is_empty() else 0.0
	var wm := Patch.num("cards", "mod", 0.23) if _card_open("mod") and not mods.is_empty() else 0.0
	var wt := Patch.num("cards", "trig", 0.12) if _card_open("trig") and not trigs.is_empty() else 0.0
	var wl := Patch.num("cards", "link", 0.10) if _card_open("link") and not links.is_empty() else 0.0
	var total := we + wp + wm + wt + wl
	if n == 0 or wave == 0 or total <= 0.0:
		return {"type": "elem", "e": MapRule.pick("elem", elems), "lv": 2 if randf() < _lv2_chance() else 1}
	var r := randf() * total
	if r < we:
		return {"type": "elem", "e": MapRule.pick("elem", elems), "lv": 2 if randf() < _lv2_chance() else 1}
	r -= we
	if r < wp:
		return {"type": "pat", "id": MapRule.pick("pat", patterns)}
	r -= wp
	if r < wm:
		return {"type": "mod", "id": MapRule.pick("mod", mods)}
	r -= wm
	if r < wt:
		return {"type": "trig", "id": trigs.pick_random()}
	return {"type": "link", "id": MapRule.pick("link", links)}


func _card_color(card: Dictionary) -> Color:
	match card["type"]:
		"elem": return Elem.COLORS[card["e"]]
		"pat": return Pat.pcolor(card["id"]).lightened(0.15)
		"mod": return Color(1, 0.82, 0.4)
		"trig": return Pat.TRIG_COLOR
	return Color(0.55, 0.9, 1.0)


func _card_button(card: Dictionary, idx: int) -> Button:
	var col := _card_color(card)
	var b := Button.new()
	b.custom_minimum_size = Vector2(230 if offer.size() <= 3 else 166, 170)
	var sb := CardDock.surface()
	sb.border_color = Color(col, 0.6)
	var sbh := sb.duplicate()
	sbh.bg_color = Color("223149")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	# 카드는 글 대신 그림 머리(종류 그림·이름·Lv 배지·번호 키)와 줄(앞에 그림)로 그린다 (_card_paint).
	# 설명은 세 단계: 기본은 간소화, [자세히]를 켜면 조금 더, 자세히 + 올리기(터치는 한 번 누르기)면 카드 위 창에 전부 (_draw_card_full)
	var cc := _card_content(card, 1 if Meta.card_detail else 0)
	var head: Dictionary = cc["head"]
	head["idx"] = idx
	var rows: Array = cc["rows"]
	var foot: Array = cc["foot"]
	b.set_meta("full", _card_full(card))
	b.set_meta("summary", _card_content(card, 0)["rows"])
	card_dock.watch(b, card)
	var fit := core_fit(card)
	if fit != "":
		rows.append({"t": "◎ 주력 %s 강화" % fit, "fs": 12, "c": BUILD_COLOR})
	if MapRule.card_aff(card):
		var dmg_up: bool = card["type"] in ["elem", "pat"]
		rows.append({"t": "◆ %s 친화%s" % [Meta.MAPS[Meta.map_id]["name"], " · 피해 +%d%%" % roundi(Rules.t("map_aff_dmg") * 100) if dmg_up else ""], "fs": 12, "c": MAP_AFF_COLOR})

	_card_paint(b, head, rows, foot, col, 14, offer.size())
	b.focus_mode = Control.FOCUS_NONE  # 다른 버튼처럼: Space·Enter가 카드를 고르지 않게
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.pressed.connect(_on_card_tap.bind(card, idx - 1))
	_mark_fav(b, sb, sbh, _fav_tag(card))
	if card["type"] == "elem":
		# 터치는 누르는 순간 마우스가 들어와 미리보기가 보이기도 전에 골라졌다: 터치는 한 번 누르기(_on_card_tap)로 미리보기
		b.mouse_entered.connect(func():
			if not touch_ui: hover_elem = card["e"])
		b.mouse_exited.connect(func():
			if not touch_ui: hover_elem = -1)
	return b


## 카드 앞면 내용 {head, rows, foot, tip}. lvl 0 = 기본 주효과, 1 = 자세히(전체 설명).
func _card_content(card: Dictionary, lvl: int) -> Dictionary:
	var head := {"kind": card["type"], "name": ""}
	var rows: Array = []
	var foot: Array = []
	var tip := ""
	var dim := Color(1, 1, 1, 0.55)
	match card["type"]:
		"elem":
			var e: int = card["e"]
			head["name"] = Elem.NAMES[e]
			head["e"] = e
			if card["lv"] == 2:
				head["lv"] = "Lv2"
			rows = [{"i": "rider", "t": "효과 · " + Elem.rider(e), "al": 0}, {"i": "trait", "t": "특징 · " + Elem.TRAIT[e], "al": 0}]
			foot = [["place_new", "새 오브젝트"], ["place_on", "겹치기" + (" %d종" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "")]]
			var cf := _combo_parts(e)
			if not cf["els"].is_empty():
				rows.append({"els": cf["els"]})
				tip = "생길 조합: " + ", ".join(cf["names"])
			if cf["ups"] > 0:
				rows.append({"chip": "Lv↑ %d곳" % cf["ups"], "i": "place_on"})
		"pat":
			var id: String = card["id"]
			head["pat"] = id
			head["name"] = Pat.pname(id)
			rows = [{"t": Pat.PATTERNS[id]["desc"]}]
			foot = [["place_on", "직선탄에: 고정 · 같은 것에: Lv+"]]
			var fit := ""
			for t in towers.get_children():
				if t.pattern == id:
					fit = "Lv%d → Lv%d" % [t.plv, t.plv + 1]
					break
			if fit != "":
				rows.append({"chip": fit, "i": "place_on"})
			elif not towers.get_children().any(func(t): return t.pattern == Pat.DEFAULT):
				rows.append({"t": "넣을 수 있는 오브젝트 없음", "fs": 12, "c": Color(1, 0.6, 0.55)})
		"mod":
			var id: String = card["id"]
			head["name"] = Pat.MODS[id]["name"]
			rows = [{"t": "사거리 안 가까운 구체를 전방위로 조준해요. 최종 피해 -10% · 오브젝트당 1회" if id == "reflex" else Pat.mdesc(id)}]
			foot = [["place_on", "오브젝트당 1회" if id == "reflex" else "위에 놓기 · " + ("종류별 %d · 합 %d" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "쌓을수록 절반")]]
		"link":
			var id: String = card["id"]
			head["name"] = Pat.LINKS[id]["name"]
			rows = [{"t": Pat.ldesc(id)}]
			foot = [["place_on", "오브젝트 위에 놓기"]]
		"trig":
			var id: String = card["id"]
			head["name"] = Pat.TRIGS[id]["name"]
			rows = [{"t": Pat.tdesc(id)}]
			foot = [["place_on", "위에 놓기 · 종류별 5개"]]
	if lvl == 0:
		rows = _card_simple(card, rows)
		for f in foot:
			f[1] = _short(f[1]).get_slice(" · ", 0)
	return {"head": head, "rows": rows, "foot": foot, "tip": tip}


## 기본 카드에는 효과를 설명하는 문장을 남긴다. 모든 웨이브에서 같은 내용이며 자세히는 보존한다.
func _card_simple(card: Dictionary, rows: Array) -> Array:
	var out: Array = []
	if card["type"] == "elem":
		out.append({"t": Elem.BRIEF[card["e"]]})
		for r in rows:
			if r.has("els") or r.has("chip"):
				out.append(r)
		return out
	if card["type"] == "cata":
		return rows  # 다시 뽑는 대상·레벨 유지·즉시 발동 조건을 생략하지 않는다.
	var first := true
	for r in rows:
		if not r.has("t"):
			out.append(r)
		elif r.has("fs"):
			if r.get("c", Color.WHITE) != Color(1, 1, 1, 0.55):
				out.append(r)  # 넣을 수 없는 대상 경고는 남긴다.
		elif first:
			out.append({"t": Pat.brief(card["type"], card["id"], r["t"])})
			first = false
	return out


## 괄호 속 덧붙임을 뺀 짧은 글.
func _short(t: String) -> String:
	return short_re.sub(t, "", true).strip_edges()


## 자세히 + 올리기 창의 줄 [[글, 색]]: 앞면에 줄인 것까지 전부.
func _card_full(card: Dictionary) -> Array:
	var W := Color(1, 1, 1, 0.9)
	var D := Color(1, 1, 1, 0.6)
	var out: Array = []
	match card["type"]:
		"elem":
			var e: int = card["e"]
			out.append(["효과 (맞힌 구체에) · " + Elem.rider(e), Elem.COLORS[e].lightened(0.3)])
			out.append(["특징 (이 오브젝트의 효과를 다른 구체로) · " + Elem.TRAIT[e], W])
			var seen := {}
			for t in towers.get_children():
				if not t.can_take({"type": "elem", "e": e}):
					continue
				for r in Elem.new_reactions(t.elements, e):
					if seen.has(r["id"]):
						continue
					seen[r["id"]] = true
					var o: int = r["b"] if r["a"] == e else r["a"]
					out.append(["조합 %s (+%s) · %s" % [r["name"], Elem.NAMES[o], r["desc"]], r["color"]])
					if r.get("aff_txt", "") != "":
						out.append([r["aff_txt"], AFF_COL[r["aff"]]])
			var ups: int = _combo_parts(e)["ups"]
			if ups > 0:
				out.append(["%s 레벨업 가능 %d곳" % [Elem.NAMES[e], ups], D])
			out.append(["새 오브젝트로 놓거나 오브젝트 위에 겹치기" + (" (%d종까지)" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else " (종류마다 공격 속도 -%d%%)" % roundi(Rules.tax_step * 100)), D])
		"pat":
			var id: String = card["id"]
			out.append([Pat.PATTERNS[id]["desc"], W])
			var no := Pat.no_mods(id)
			if not no.is_empty():
				out.append(["못 넣는 강화(효과 없음): " + "·".join(no), D])
			for t in towers.get_children():
				if t.pattern == id:
					out.append(["%s Lv%d → Lv%d 가능" % [Pat.pname(id), t.plv, t.plv + 1], D])
			out.append(["직선탄 오브젝트에 넣으면 그 공격방식으로 고정돼요. 같은 공격방식에 넣으면 레벨업해요.", D])
		"mod":
			if card["id"] == "reflex":
				out.append(["전방위로 자동 조준해요. 최종 피해 -10%", W])
				out.append(["사거리 안 최근접 구체 · 오브젝트당 1회", D])
				out.append(["혼불·블랙홀에는 넣을 수 없어요.", D])
				return out
			out.append([Pat.mdesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기 · " + ("종류별 %d개, 합쳐 %d개까지" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "쌓을수록 효과 절반씩"), D])
		"link":
			out.append([Pat.ldesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기", D])
		"trig":
			out.append([Pat.tdesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기 · 종류별 5개까지", D])
	return out


## [자세히]를 켠 채 카드에 올리면(터치는 한 번 눌러 미리보기) 카드 위에 모든 내용 창.
func _draw_card_full() -> void:
	if card_dock != null and card_dock.active():
		return
	if not Meta.card_detail or phase != Phase.CHOOSE or perk_mode or cards_hidden or not choice_box.visible or get_tree().paused:
		return
	var cs := choice_box.get_children()
	var hit: Button = null
	for i in cs.size():
		var b := cs[i] as Button
		if b == null or b.is_queued_for_deletion() or not b.has_meta("full"):
			continue
		if (touch_ui and i == tap_sel) or (not touch_ui and b.is_hovered()):
			hit = b
	if hit == null or (hit.get_meta("full") as Array).is_empty():
		return
	var inv := ui_root.get_global_transform().affine_inverse()
	var cr: Rect2 = inv * hit.get_global_rect()
	var row: Rect2 = inv * choice_box.get_global_rect()
	var top_lim := (hud.position.y + hud.size.y + 6.0) if hud.visible else 8.0
	var bot_lim := info.size.y - 8.0
	var side_room := info.size.x - row.end.x - 20.0
	var beside_guide := guide_label.visible and side_room >= 260.0
	var w := minf(420.0, side_room) if beside_guide else 420.0
	var fs := 14
	var rows: Array = []
	var lh := 0.0
	var h := 0.0
	# 화면 높이에 안 들어가면 글자를 한 단계씩 줄인다 (최소 12)
	while true:
		rows.clear()
		for l in hit.get_meta("full"):
			for t in _wrap_words(_kr_keep(l[0]), w - 20.0, fs).split("\n"):
				rows.append([t, l[1]])
		lh = fs + 6.0
		h = rows.size() * lh + 14.0
		if h <= bot_lim - top_lim or fs <= 12:
			break
		fs -= 1
	var x := clampf(cr.get_center().x - w / 2.0, 8.0, info.size.x - w - 8.0)
	var y := row.position.y - h - (44.0 if touch_ui else 30.0)  # 카드 줄 위 (고르기 꼬리표·[적용] 위)
	if beside_guide:
		x = row.end.x + 12.0
		y = clampf(row.position.y, top_lim, bot_lim - h)
	elif y < top_lim:
		y = clampf(row.end.y + 50.0, top_lim, bot_lim - h)  # 위에 자리가 없으면 아래 버튼 줄 밑, 화면 안으로
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	sb.border_color = Color(1, 0.85, 0.5, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	info.draw_style_box(sb, Rect2(x, y, w, h))
	# 어느 카드의 내용인지: 카드 쪽으로 작은 꼭지
	var tipx := clampf(cr.get_center().x, x + 12.0, x + w - 12.0)
	if y < row.position.y:
		info.draw_colored_polygon(PackedVector2Array([Vector2(tipx - 7, y + h), Vector2(tipx + 7, y + h), Vector2(tipx, y + h + 7)]), sb.bg_color)
	for i in rows.size():
		info.draw_string(ui_font, Vector2(x + 10.0, y + 7.0 + fs + i * lh), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, rows[i][1])


## 그림 카드: 머리(종류 그림·이름·Lv 배지, 번호는 오른쪽 위 작은 키)와 줄들을 직접 그린다 (버튼 글은 비움).
## head: kind·name·idx, 있으면 e(속성 그림)·pat(공격방식 그림)·lv·badge. rows: 줄마다 하나
##   {t: 글, i: 앞 그림(Glyph.ui id), fs, c, al(0 왼쪽 · 기본 가운데)} · {els: [짝 속성]} · {chip: 글, i} · {big: 글, i} · {pips: 보유 수}
## 높이는 내용에 맞춰 170~CARD_MAX_H, 넘치면 글자를 줄인다(최소 12).
func _card_paint(b: Button, head: Dictionary, rows: Array, foot: Array, col: Color, base_fs := 14, count := 3) -> void:
	b.text = ""
	var cw := 230.0 if count <= 3 else 166.0  # 4장일 때는 좁게
	var fs := base_fs
	var lay: Array = []
	var h := 0.0
	var pad := 54.0 + (24.0 if not foot.is_empty() else 8.0)
	while true:
		lay.clear()
		h = 0.0
		for r: Dictionary in rows:
			var f: int = mini(r.get("fs", fs), fs)
			var lh := 0.0
			var t := ""
			if r.has("els"):
				lh = 24.0
			elif r.has("chip"):
				lh = 28.0
			elif r.has("big"):
				lh = 44.0
			elif r.has("pips"):
				lh = 20.0
			elif r.has("pair"):
				lh = 28.0
			else:
				var w := cw - 24.0 - (20.0 if r.has("i") else 0.0)
				t = _wrap_words(_kr_keep(r["t"]), w, f)
				lh = ui_font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w, f).y + 4.0
			lay.append([r, t, f, lh])
			h += lh
		if h + pad <= CARD_MAX_H or fs <= 12:
			break
		fs -= 1
	b.custom_minimum_size = card_dock.card_size()
	b.clip_contents = true
	b.set_meta("card", [head, lay, h, not foot.is_empty()])
	b.set_meta("card_foot", foot)
	b.add_to_group("keycap")
	b.draw.connect(_draw_card.bind(b, col))


func _draw_card(b: Button, col: Color) -> void:
	card_dock.draw_card(b, col)


func _fav_tag(card: Dictionary) -> String:
	if Meta.favs.has(Codex.card_key(card)):
		return "★ 선호"
	if card["type"] == "elem":
		for t in towers.get_children():
			if not t.can_take(card):
				continue
			for r in Elem.new_reactions(t.elements, card["e"]):
				if Meta.favs.has("react:" + str(r["id"])):
					return "★ 선호 조합: " + str(r["name"])
	return ""


## 선호 카드 강조: 금색 테두리와 반짝임(Codex.Sparkle)을 얹는다.
func _mark_fav(b: Button, sb: StyleBoxFlat, sbh: StyleBoxFlat, tag: String) -> void:
	if tag == "":
		return
	for s: StyleBoxFlat in [sb, sbh]:
		s.border_color = Codex.FAV_COLOR
		s.set_border_width_all(maxi(s.border_width_left, 3))
	b.add_child(Codex.Sparkle.new(tag))


## 남은 고르기 수는 카드 위 배지(_draw_info)에 있어서, 조작 안내만 처음 세 판에 띄운다.
func _choose_hint() -> String:
	if Meta.games >= 3:
		return ""
	return "카드를 눌러 든 뒤 대상에 놓으세요. 카드에서 바로 끌어 놓을 수도 있어요."


# ---------- 튜토리얼 ----------

## 자동 튜토리얼 모달은 예약하지 않는다. 기존 이벤트 호출부는 짧은 안내와 함께 유지한다.
func _tut_event(_id: String) -> void:
	# 판 중 설명은 _guide가 담당한다. 상세 설명은 직접 열 때만 seen으로 기록한다.
	pass


func _tut_tick() -> void:
	if tut.visible or DisplayServer.get_name() == "headless":
		return
	var panels := settings_panel.visible or records_panel.visible or help_label.visible or notes_panel.visible or modes_panel.visible or codex_panel.visible or vote_panel.visible or mp_panel.visible
	if panels:
		return
	if tut_first and title_label.visible:
		tut_first = false
		tut.touch = touch_ui
		tut.phone = _phone()
		tut.open_welcome()
	tut_queue.clear()


func _first_action_text() -> String:
	if TutPlay.on or Tutorial.play_done or (Meta.games > 0 and not tutor) or wave != 0 or mp_mode != "" or not Meta.guide_on:
		return ""
	match phase:
		Phase.CHOOSE:
			if perk_mode:
				return ""
			if cards_hidden:
				return "선택지를 다시 열어 카드를 고르세요."
			return "카드를 한 장 더 고르세요." if towers.get_child_count() > 0 else "카드를 하나 고르세요."
		Phase.PLACE:
			return "넣을 오브젝트를 고르세요." if picked.get("type", "elem") != "elem" else "빨간 길목 쪽 빈 곳에 놓으세요."
		Phase.AIM:
			return "구체가 오는 쪽으로 방향을 정하세요."
		Phase.READY:
			return "웨이브를 시작하세요."
		Phase.MOVE:
			return "옮길 곳에 놓으세요. 취소하면 돌아가요."
	return ""


func _open_guide_details() -> void:
	if guide_topic == "":
		return
	if not get_tree().paused and not title_label.visible:
		get_tree().paused = true
		tut_paused = true
	_open_tut([guide_topic])


func _update_action_guide() -> void:
	var action := _first_action_text()
	if action != "" and not title_label.visible and not (settings_panel.visible or records_panel.visible or help_label.visible or notes_panel.visible or modes_panel.visible or codex_panel.visible or vote_panel.visible or mp_panel.visible or tut.visible):
		guide_label.text = _kr_keep(action)
		guide_label.reset_size()
		guide_topic = "cards" if phase == Phase.CHOOSE else "goal" if phase == Phase.READY else "place"
		guide_label.visible = not get_tree().paused and not tut.visible
		# 같은 조작을 화면 위 안내와 아래 긴 조작문으로 중복 설명하지 않는다.
		hint.text = ""
	guide_more.visible = guide_label.visible and guide_topic != ""
	guide_more.position = Vector2(guide_label.position.x, guide_label.get_rect().end.y + 6.0)


func _open_tut(ids: Array, first := false) -> void:
	tut.touch = touch_ui
	tut.phone = _phone()
	tut.open_topics(ids, first)


## 다시 보기 목록 (시작 화면 [튜토리얼]·H, 일시정지 [튜토리얼]).
func _open_tut_list() -> void:
	help_label.visible = false
	tut.touch = touch_ui
	tut.phone = _phone()
	tut.open_list()


func _on_tut_closed() -> void:
	if tut_paused:
		tut_paused = false
		get_tree().paused = false


## [플레이하며 배우기]·목록의 [플레이 튜토리얼]: 화면을 다시 불러 연습 판으로 (ch: 장 0~3).
## 진행 중인 판은 쉬는 시간 저장이 그대로 남아 시작 화면 [이어하기]로 돌아갈 수 있다.
func _play_tutorial(ch := 0) -> void:
	if mp_mode != "":
		return
	_save_run()
	get_tree().paused = false
	if TutPlay.on:
		TutPlay.leave_meta()
	TutPlay.pending = ch
	_reload()


## 다시 불러온 뒤 (_ready): 시작 화면을 닫고 연습 판의 첫 쉬는 시간을 연다.
func _start_tut_play(ch: int) -> void:
	TutPlay.pending = -1
	_hide_title()
	title_seen = false  # 연습 판을 마치면 시작 화면으로
	tplay = TutPlay.new()
	tplay.z_index = 19  # 카드·전장 위, 일시정지 어둠(20)·창 아래 (끝내기 확인은 그 위)
	ui_root.add_child(tplay)
	lanes.clear()
	wave = 0
	Ach.mp = "tut"  # _ready가 멀티 표시를 지운 뒤라 다시 (누적 수·도감 수집이 오르지 않게)
	tplay.setup(self, ch)
	_start_choose()


# ---------- 처음 안내 ----------

## 처음 생기는 일에 한 줄 안내. 안내마다 한 번만(Meta.guide_seen), 설정에서 끌 수 있다.
## 쉬는 시간은 웨이브 시작까지, 웨이브 중은 8초. 한 번에 하나만, 위험 경고를 일반 안내보다 우선한다.
func _guide(id: String, text: String) -> void:
	if TutPlay.on:
		return  # 연습 판은 위 안내 칸이 대신한다
	if not Meta.guide_on or Meta.guide_seen.has(id) or title_label.visible or _first_action_text() != "":
		return
	var priority := 3 if id == "boss" else 2 if id in ["resist", "sturdy", "jam", "leak"] else 1
	if not guide_lines.is_empty() and priority < guide_priority:
		return  # 판단에 필요한 경고를 일반 설명이 덮지 않는다. 보여 주지 않은 항목은 seen으로 기록하지 않는다.
	var short := {
		"stack": "같은 속성은 레벨업, 다른 속성은 효과를 더해요.",
		"boss": "다음 웨이브에 보스가 와요. 분홍 경로를 확인하세요.",
		"resist": "저항 속성 외의 공격도 준비하세요.",
		"sturdy": "굳센 구체는 이동 방해에 강해요.",
		"ley": "청록 고리 위 오브젝트는 피해가 늘어요.",
		"jam": "방해 구체가 와요. 오브젝트를 나눠 배치하세요.",
		"pat": "새 공격방식: 직선탄 오브젝트에 넣어 공격을 바꿔요.",
		"mod": "새 강화: 오브젝트에 넣어 공격을 강화해요.",
		"trig": "새 발동: 조건이 맞으면 추가 효과가 나와요.",
		"link": "새 연계: 주변 오브젝트와 함께 싸워요.",
		"skill": "웨이브 중 기술 버튼으로 전투를 도울 수 있어요.",
		"leak": "구체가 중앙에 닿았어요. 빈 길목을 보강하세요.",
		"lanes": "빨간 부채꼴이 구체가 들어오는 길목이에요.",
		"react": "조합: 한 속성의 효과가 다른 속성의 특징을 따라 퍼져요.",
	}
	var line: String = short.get(id, text.get_slice(". ", 0))
	Meta.guide_seen[id] = true
	_save_best()
	guide_lines.assign([line])
	guide_priority = priority
	guide_topic = Tutorial.ON_EVENT.get(id, "goal" if id == "lanes" else "")
	guide_t = 8.0 if phase == Phase.WAVE else -1.0
	guide_label.text = _kr_keep(_wrap_words(line, minf(570.0, ui_root.size.x - 40.0), 16))
	guide_label.reset_size()


## 쉬는 시간이 열릴 때: 길목·겹치기·보스·저항·굳센 구체 안내.
func _rest_guides() -> void:
	if wave == 0:
		_guide("start", "빨간 부채꼴이 구체가 들어오는 길목이에요. 그 넓이 어디로든 와요. 속성 카드를 고른 뒤 길목 쪽 빈 곳을 눌러 놓고, 한 번 더 눌러 쏠 방향을 정하세요")
	elif towers.get_child_count() > 0:
		_guide("stack", "속성 카드를 오브젝트 위에 놓으면 겹쳐져요. 같은 속성은 레벨업, 다른 속성은 추가 효과가 더해지고, 속성마다 특징이 다른 속성 효과까지 실어 날라요")
	if not boss_plan.is_empty() and boss_plan["wave"] == wave + 1:
		_guide("boss", "다음 웨이브 끝에 보스가 와요. 분홍 선이 실제로 지나갈 길이에요. 중앙에 닿으면 3 피해, 웨이브를 넘기면 특성을 하나 골라요")
	if wave_resist >= 0:
		_guide("resist", "저항 구체(점선 고리)가 섞여 와요. 다음 웨이브는 %s 속성 피해를 덜 받으니 다른 속성 오브젝트도 길목에 두세요" % Elem.NAMES[wave_resist])
	if not ley.is_empty():
		_guide("ley", "청록 고리는 기맥이에요. 그 위에 놓은 오브젝트는 피해 +%d%% (자리마다 가장 가까운 하나)" % roundi(Rules.t("ley_dmg") * 100))
	if jams_on() and wave + 1 >= jam_from("shade"):
		_guide("jam", "방해 구체가 섞여 와요. 그림자·표적은 오브젝트를 잠깐 멈추고, 흡수는 공격 속도를 빼앗아요. 오브젝트를 여러 곳에 나눠 두면 덜 막혀요")
	if wave + 1 >= Rules.sturdy_from:
		_guide("sturdy", "굳센 구체(회색 쐐기)가 섞여 와요. 밀기·감속·기절·냉기가 절반만 들으니 피해로 잡아야 해요")


## 선택지에 처음 나온 카드 종류 안내.
func _card_guides() -> void:
	var types := offer.map(func(cd): return cd["type"])
	if "pat" in types:
		_guide("pat", "새 카드 · 공격방식: 직선탄 오브젝트에 넣으면 공격 모양이 바뀌고 그 뒤로 고정돼요. 같은 공격방식을 넣으면 레벨업")
	if "mod" in types:
		var cap := "같은 강화는 %d개, 한 오브젝트에 합쳐 %d개까지 넣어요" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "쌓을수록 효과가 절반씩 줄어요"
		_guide("mod", "새 카드 · 강화: 오브젝트 위에 놓아 공격을 바꿔요(빠르게·크게·관통 등). " + cap)
	if "link" in types:
		_guide("link", "새 카드 · 연계: 오브젝트 위에 놓아 주변과 함께 싸워요. 협공은 여러 오브젝트가 같이 맞힌 구체를 터뜨려요")
	if "trig" in types:
		_guide("trig", "새 카드 · 발동: 오브젝트 위에 놓으면 조건이 맞을 때 공격이 더 나가요. 처치 폭발은 잡은 자리에서 탄이 터지고, 앞줄 강타는 체력이 많이 남은 구체를 더 세게 때려요")


## 띄어쓰기 단위로 줄을 나눈다. Godot 자동 줄바꿈은 한글을 음절마다 끊어 "형\n태"처럼 단어가 잘린다.
func _wrap_words(text: String, width: float, fs: int) -> String:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for w in para.split(" ", false):
			var cand: String = w if line == "" else line + " " + w
			if line != "" and ui_font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
				out.append(line)
				line = w
			else:
				line = cand
		out.append(line)
	return "\n".join(out)


## "a · b · c"처럼 구분자로 나뉜 글을 항목 단위로 줄바꿈 (항목 중간에서 끊지 않음).
func _wrap_parts(text: String, sep: String, width: float, fs: int) -> String:
	var out := PackedStringArray()
	var line := ""
	for part in text.split(sep):
		var cand: String = part if line == "" else line + sep + part
		if line != "" and ui_font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			out.append(line)
			line = part
		else:
			line = cand
	out.append(line)
	return "\n".join(out)


## 5웨이브마다: 특성 3개 중 1개.
## 바람 속성 오브젝트 둘레의 다른 오브젝트 공격 속도를 정한다 (가장 큰 바람 하나만).
func _wind_buffs() -> void:
	var ts := towers.get_children()
	var winds := []  # 2026-11-04: 바람 효과가 밀쳐냄으로 바뀌어 순풍은 없다 (패치로 되살릴 때를 위해 계산은 남김)
	for t in ts:
		var b := 0.0
		for w in winds:
			if w != t and w.position.distance_to(t.position) < w.wind_range():
				b = maxf(b, Rules.t("wind_buff") * w.lv(Elem.WIND))
		t.wind_buff = b


## 속성 카드가 Lv2로 나올 확률 (행운 특성 포함).
func _lv2_chance() -> float:
	var w: int = bank_picks[0] if not bank_picks.is_empty() else wave  # 미룬 고르기는 쌓은 때의 웨이브로 (미뤄서 Lv2가 더 잘 나오지 않게)
	var lv2 := minf(Patch.num("cards", "lv2_base", 0.2) + Patch.num("cards", "lv2_wave", 0.02) * w, Patch.num("cards", "lv2_max", 0.5))
	return lv2 + _perk_val("luck") * perks.get("luck", 0)


func _start_perk() -> void:
	var pool := _perk_pool()
	if pool.is_empty():
		bank_perks = 0
		_show_toast("사용 가능한 특성 카드가 없어 이번 선택을 건너뜁니다")
		_start_choose(not rest_ready)
		return
	pool.shuffle()
	perk_offer = pool.slice(0, 3)
	if TutPlay.on and not perk_offer.any(func(pk): return pk["id"] == "coin"):
		var coin: Array = pool.filter(func(pk): return pk["id"] == "coin")
		if not coin.is_empty() and not perk_offer.is_empty():
			perk_offer[perk_offer.size() - 1] = coin[0]  # 연습 판: 운명의 동전도 한 번 보여 준다
	if coin_next == "":
		perk_rerolls = 0 if Modes.has("narrow") else 1  # 동전 뒤 새 3개는 같은 선택이라 다시 주지 않음
	_show_perks()
	if coin_next == "":
		big_banner("특성 선택", Color(1, 0.85, 0.45))
	_save_run()


## 지금 선택지에 나올 수 있는 특성들
func _perk_pool() -> Array:
	var pool: Array = PERKS.filter(func(pk): return _card_enabled({"type": "perk", "id": pk["id"]}))
	if Modes.has("narrow"):
		pool = pool.filter(func(pk): return not pk["id"] in ["reroll", "coin"])  # 외길: 새로고침이 없으니 쓸모없는 특성은 빼고 (동전 뒷면도 새로고침)
	if coin_next != "":
		pool = pool.filter(func(pk): return pk["id"] != "coin")  # 던진 동전의 결과를 받을 차례
	# 더 골라도 거의 효과가 없는 특성은 빼고: 이미 거의 Lv2로 나오는 행운, 조화(한 번만, 2026-11-01: 도파민에서 겹치고 속성을 많이 쌓으면 속사보다 훨씬 셌음).
	# 동전 앞면(두 번 적용)일 때도 조화는 한 번만 효과가 있어 뺀다
	pool = pool.filter(func(pk): return not (pk["id"] == "luck" and _lv2_chance() >= 0.9 or pk["id"] == "harmony" and (perks.has("harmony") or coin_next == "double")))
	# 넣어도 효과가 없는 중앙 특성은 빼고: 벽 오브젝트가 없을 때 성벽, 이미 최대인 실드·성벽
	pool = pool.filter(func(pk): return not (pk["id"] == "rampart" and (not _has_wall() or _rampart_n() >= int(_perk_val("rampart_max")))
		or pk["id"] == "shield" and _shield_wave() >= int(_perk_val("shield_max"))
		or pk["id"] == "overflow" and perks.has("overflow")
		or pk["id"] == "quick" and (skill_ids.is_empty() or perks.get("quick", 0) >= 3)))
	return pool


## 특성 고르기 화면 (perk_offer는 이미 정해져 있음).
func _show_perks() -> void:
	phase = Phase.CHOOSE
	wave_active = false
	perk_mode = true
	_clear_shots()
	for c in choice_box.get_children():
		c.queue_free()
	for i in perk_offer.size():
		var pk: Dictionary = perk_offer[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 170)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.11, 0.06, 0.96)
		sb.border_color = Color(1, 0.8, 0.35, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		var sbh := sb.duplicate()
		sbh.bg_color = Color(0.2, 0.17, 0.09, 0.98)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		var have: int = perks.get(pk["id"], 0)
		var coin: String = {"double": "동전 앞면: 두 번 적용", "reroll": "동전 뒷면: + 새로고침 %d" % int(_perk_val("coin"))}.get(coin_next, "")
		var rows: Array = []
		var desc := _perk_desc(pk)
		var big := _perk_big(pk["id"], desc)
		if big.is_empty():
			rows.append({"t": desc, "fs": 16})
		else:
			rows.append(big)
			b.tooltip_text = ""
		if have > 0:
			rows.append({"pips": mini(have, 8)})
		if coin != "":
			rows.append({"t": coin, "fs": 13, "c": Color(1, 0.85, 0.45)})
		_card_paint(b, {"kind": "perk", "name": pk["name"], "idx": i + 1}, rows, [], Color(1, 0.85, 0.45), 16, perk_offer.size())
		b.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
		b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("perk_desc", desc + ("\n\n" + coin if coin != "" else ""))
		b.mouse_entered.connect(func():
			card_dock.inspected_tower = null
			card_dock.hovered = b)
		# 터치는 올리기가 없어 누르면 바로 골라졌다: 길게 누르면(0.45초) 고르지 않고 오른쪽에 자세히
		b.gui_input.connect(func(ev: InputEvent):
			if touch_ui and (ev is InputEventScreenTouch or (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT)):
				if ev.pressed:
					perk_press = b
					get_tree().create_timer(0.45).timeout.connect(func():
						if perk_press == b and is_instance_valid(b) and perk_mode:
							perk_peek = b
							card_dock.inspected_tower = null
							card_dock.hovered = b)
				else:
					perk_press = null)
		b.pressed.connect(func():
			if perk_peek == b:
				perk_peek = null  # 길게 눌러 본 것: 고르지 않음
				return
			_on_perk(pk))
		_mark_fav(b, sb, sbh, "★ 선호" if Meta.favs.has("perk:" + str(pk["id"])) else "")
		choice_box.add_child(b)
	cards_hidden = false
	choice_box.visible = true
	_update_reroll_btn()
	match coin_next:
		"double": hint.text = _th("동전 앞면! 고르는 특성이 두 번 적용돼요")
		"reroll": hint.text = _th("동전 뒷면! 고르는 특성에 더해 이번 쉬는 시간 새로고침 +%d" % int(_perk_val("coin")))
		_: hint.text = _th("특성을 하나 고르세요. 이번 판 끝까지 유지됩니다")


func _on_perk(pk: Dictionary) -> void:
	if not perk_mode or coin_stage > 0:
		return
	perk_mode = false
	var id: String = pk["id"]
	perks[id] = perks.get(id, 0) + 1
	run_log.append({"w": wave, "k": "perk", "o": perk_offer.map(func(x): return "perk:" + x["id"]), "p": "perk:" + id})

	Ach.on_pick("perk:" + id)
	if id == "coin":
		# 운명의 동전: 지금 던지고 특성 3개를 새로 받는다 (뒷면도 보통 특성 하나보다 조금 낫게)
		coin_next = "double" if randf() < 0.5 else "reroll"
		if coin_anim:
			_coin_throw()
		else:
			_coin_done()
		return
	_apply_perk(id)
	_mp_send_perk(id)
	var note := ""
	match coin_next:
		"double":
			perks[id] += 1
			_apply_perk(id)
			_mp_send_perk(id)
			note = " · 동전 앞면: 두 번"
		"reroll":
			rerolls_left += int(_perk_val("coin"))
			note = " · 동전 뒷면: 새로고침 +%d" % int(_perk_val("coin"))
	coin_next = ""
	sfx.play("reaction", 0.0)
	_show_toast("특성: %s (%s)%s" % [pk["name"], _perk_desc(pk), note])
	for t in towers.get_children():
		t.queue_redraw()
	if bank_perks > 0:
		bank_perks -= 1  # 미룬 특성을 이어서
		_start_perk()
	else:
		_start_choose(not rest_ready)


## 동전을 던진다: 카드를 치우고 공중에서 돌리기 시작.
func _coin_throw() -> void:
	for c in choice_box.get_children():
		c.queue_free()
	choice_box.visible = false
	reroll_btn.visible = false
	banner_t = 0.0  # "특성 선택" 글이 남아 결과 글이 뒤로 밀리지 않게
	banner_queue.clear()
	toast_timer = 0.0
	coin_stage = 1
	coin_t = 0.0
	coin_ang = 0.0
	coin_fx.visible = true
	coin_fx.mouse_filter = Control.MOUSE_FILTER_STOP
	hint.text = _th("동전을 던졌어요! 눌러서 잡기 · 한 번 더 누르면 바로 결과")
	sfx.play("place")


## 누르기·Space: 공중이면 떨어뜨리고, 떨어지는 중이면 결과로, 결과가 떠 있으면 바로 카드로.
func _coin_tap() -> void:
	if coin_stage == 0 or Time.get_ticks_msec() - coin_tap_t < 150:
		return
	coin_tap_t = Time.get_ticks_msec()
	match coin_stage:
		1: _coin_drop()
		2, 3: _coin_land()
		4: _coin_done()


func _coin_drop() -> void:
	coin_stage = 2
	coin_t = 0.0
	coin_ang0 = coin_ang
	# 처음 속도(초당 22)에서 고르게 느려져 0.85초 뒤 가로 폭 0(모서리)이 되게: 끝 각도 = (n + 0.5)π
	coin_spin = ceilf((coin_ang0 + 9.35 - PI / 2.0) / PI) * PI + PI / 2.0 - coin_ang0


func _coin_land() -> void:
	coin_stage = 4
	coin_t = 0.0
	sfx.play("crit")
	sfx.play("reaction", 0.0)
	big_banner("동전 앞면! 두 번 적용" if coin_next == "double" else "동전 뒷면! 새로고침 +%d" % int(_perk_val("coin")), Color(1, 0.85, 0.3) if coin_next == "double" else Color(0.7, 0.82, 1.0))


## 연출이 끝나 결과대로 특성 3개를 새로 받는다.
func _coin_done() -> void:
	coin_stage = 0
	Ach.on_coin(coin_next == "double")
	_ach_check()
	if coin_fx:
		coin_fx.visible = false
		coin_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not coin_anim:
		sfx.play("crit")
		big_banner("동전 앞면!" if coin_next == "double" else "동전 뒷면!", Color(1, 0.85, 0.3))
	_start_perk()


func _coin_step(delta: float) -> void:
	coin_t += delta
	var was := cos(coin_ang) > 0.0
	match coin_stage:
		1:
			coin_ang += 22.0 * delta
			if coin_t >= 1.0:
				_coin_drop()
		2:
			var k := minf(coin_t / 0.85, 1.0)
			coin_ang = coin_ang0 + coin_spin * (1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				coin_stage = 3
				coin_t = 0.0
				sfx.play("place", 0.0)
		3:
			if coin_t >= 0.5:
				_coin_land()
		4:
			if coin_t >= 0.75:
				_coin_done()
				return
	if coin_stage in [1, 2] and (cos(coin_ang) > 0.0) != was:
		sfx.play("hit", 0.02)  # 면이 바뀔 때마다 띵 (느려질수록 뜸해진다)
	coin_fx.queue_redraw()


func _draw_coin() -> void:
	var sz := coin_fx.size
	var c := sz / 2.0 + Vector2(0, 40)  # 결과 글(banner, 가운데 -140)이 동전 위에 오게
	var air := c.y - 120.0
	var fade := minf(coin_t / 0.2, 1.0) if coin_stage == 1 else 1.0
	coin_fx.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.62 * fade))
	var y := air + sin(coin_t * 5.0) * 6.0
	var sx := cos(coin_ang)
	var rot := 0.0
	var r := 52.0
	var front := sx > 0.0
	match coin_stage:
		2:
			var k := minf(coin_t / 0.85, 1.0)
			y = lerpf(air, c.y, k * k)
			r = lerpf(52.0, 58.0, k)
		3:
			# 모서리로 서서 흔들림: 어느 쪽으로 쓰러질지 모르게 양쪽으로 기울었다 돌아온다
			var k := coin_t / 0.5
			y = c.y
			r = 58.0
			rot = sin(coin_t * 19.0) * 0.28 * (1.0 - k * 0.6)
			sx = 0.1 * sin(coin_t * 27.0)
			front = sx > 0.0
			coin_fx.draw_string(ui_font, Vector2(c.x - 40, c.y + 110), "…?", HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Color(1, 1, 1, 0.9))
		4:
			var k := minf(coin_t / 0.12, 1.0)
			y = c.y
			front = coin_next == "double"
			sx = k if front else -k
			r = 58.0 * (1.0 + 0.25 * maxf(0.0, 1.0 - coin_t / 0.25))
			var col := Color(1, 0.82, 0.35) if front else Color(0.68, 0.8, 0.95)
			var ray_a := Time.get_ticks_msec() / 1000.0 * 0.6
			var rl := 190.0 * minf(coin_t / 0.15, 1.0)
			for i in 16:
				var a := ray_a + i * TAU / 16.0
				coin_fx.draw_colored_polygon(PackedVector2Array([Vector2(c.x, y), Vector2(c.x, y) + Vector2.from_angle(a) * rl, Vector2(c.x, y) + Vector2.from_angle(a + 0.09) * rl]), Color(col, 0.22))
			for i in 8:
				coin_fx.draw_circle(Vector2(c.x, y), r * (2.6 - i * 0.2), Color(col, 0.05))
	if coin_stage == 1:
		coin_fx.draw_string(ui_font, Vector2(c.x - 200, c.y + 60), _th("눌러서 잡기"), HORIZONTAL_ALIGNMENT_CENTER, 400, 28, Color(1, 1, 1, 0.95 * fade))
		coin_fx.draw_string(ui_font, Vector2(c.x - 200, c.y + 92), "운명의 동전", HORIZONTAL_ALIGNMENT_CENTER, 400, 18, Color(1, 0.85, 0.45, 0.8 * fade))
	if coin_stage in [1, 2]:
		# 잔상: 조금 전 위치의 흐린 동전
		_coin_disc(Vector2(c.x, y - 14.0), r, cos(coin_ang - 0.35), 0.0, cos(coin_ang - 0.35) > 0.0, 0.25)
	_coin_disc(Vector2(c.x, y), r, sx, rot, front, 1.0)


## 동전 한 개. sx: 가로 폭(-1~1, 0이면 모서리). 앞면은 금색에 가운데 점(빈두), 뒷면은 은색에 새로고침 화살표.
func _coin_disc(p: Vector2, r: float, sx: float, rot: float, front: bool, a: float) -> void:
	var w := maxf(absf(sx), 0.07)
	var face := Color(1, 0.8, 0.35, a) if front else Color(0.68, 0.8, 0.95, a)
	var dark := Color(0.62, 0.42, 0.12, a) if front else Color(0.3, 0.4, 0.58, a)
	var th := 3.0 + 6.0 * (1.0 - absf(sx))  # 옆으로 누울수록 두께가 보인다
	coin_fx.draw_set_transform(p, rot, Vector2(w, 1.0))
	coin_fx.draw_circle(Vector2(th / w, 0), r, dark)
	coin_fx.draw_circle(Vector2.ZERO, r, face)
	coin_fx.draw_arc(Vector2.ZERO, r - 2.0, 0, TAU, 40, dark, 4.0 / w)
	if absf(sx) > 0.3:
		coin_fx.draw_arc(Vector2.ZERO, r * 0.62, 0, TAU, 40, dark, 3.0 / w)
		if front:
			coin_fx.draw_circle(Vector2.ZERO, r * 0.16, dark)
		else:
			coin_fx.draw_arc(Vector2.ZERO, r * 0.32, 0.7, TAU - 0.5, 24, dark, 4.0 / w)
			var tip := Vector2.from_angle(0.7) * r * 0.32
			coin_fx.draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -2), tip + Vector2(7, -6), tip + Vector2(2, 9)]), dark)
	coin_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _apply_perk(id: String) -> void:
	match id:
		"power": Tower.dmg_mul += _perk_val("power")
		"haste": Tower.spd_mul += _perk_val("haste")
		"reach": Tower.reach_mul += _perk_val("reach")
		"core":
			core_max += int(_perk_val("core"))
			core_hp = core_max
		"slow": orb_speed_mul *= 1.0 - _perk_val("slow")
		"harmony": Tower.tax_step = minf(Tower.tax_step, Rules.tax_step * _perk_val("harmony"))  # 한 번만 (동전 앞면·옛 저장에서 두 번 와도 같게)


## 특성 수치 (온라인 패치 perks로 바뀔 수 있음). 설명 글도 같이 바꿔야 하면 perk_desc. coin: 동전 뒷면 새로고침 수
const PERK_VALS := {"power": 0.15, "haste": 0.12, "reach": 0.12, "core": 3, "reroll": 1, "luck": 0.2, "regen": 1, "regen_more": 0.5, "slow": 0.08, "harmony": 0.5, "harmony_cap": 0.2, "coin": 2,
	"shield": 1, "shield_max": 3, "shield_all": 4, "rampart": 1, "rampart_max": 4, "rampart_push": 140, "riposte": 0.6, "riposte_more": 0.5, "riposte_r": 160, "overflow": 2}
static var RAMPART_R := 56.0  # 성벽이 서는 중앙에서의 거리
const FX_RIPOSTE := 0.35


## 실드 특성이 웨이브 시작마다 채우는 실드.
func _shield_wave() -> int:
	return mini(perks.get("shield", 0) * int(_perk_val("shield")), int(_perk_val("shield_max")))


## 넘친 회복으로 남길 수 있는 실드 (모든 실드 합이 shield_all을 넘지 않게).
func _keep_cap() -> int:
	if not perks.has("overflow"):
		return 0
	return maxi(0, mini(int(_perk_val("overflow")), int(_perk_val("shield_all")) - _shield_wave()))


## 중앙 체력 회복. 넘친 회복 특성이 있으면 가득 차서 넘친 만큼 실드로.
func _heal_core(n: int) -> void:
	var room := maxi(core_max - core_hp, 0)
	core_hp += mini(n, room)
	var over := mini(n - room, _keep_cap() - shield_keep)
	if over > 0:
		shield_keep += over
		popup(core() + Vector2(0, -CORE_RADIUS - 24.0), over, Color(0.55, 0.85, 1.0), true, "실드 +%d" % over, 1.0)


## 성벽 조각 수: 벽 공격방식 오브젝트의 레벨 합 + 고른 횟수.
func _rampart_n() -> int:
	var n: int = perks.get("rampart", 0)
	if n == 0:
		return 0
	for t in _my_towers():
		if t.pattern == "wall":
			n += t.plv
	return mini(n * int(_perk_val("rampart")), int(_perk_val("rampart_max")))


func _has_wall() -> bool:
	return _my_towers().any(func(t): return t.pattern == "wall")


## 실드가 먼저 막는다 (이번 웨이브 실드 → 남는 실드). 막은 양을 돌려준다.
func _shield_absorb(dmg: int) -> int:
	var a := mini(shield, dmg)
	shield -= a
	var b := mini(shield_keep, dmg - a)
	shield_keep -= b
	return a + b


## 반격 파동: 중앙 근처 구체를 밀어내고 피해 (보통 구체 체력의 riposte배, 겹치면 하나당 +riposte_more).
func _riposte(p: Vector2) -> void:
	if riposte_cd > 0.0:
		return
	riposte_cd = 0.25
	var r := _perk_val("riposte_r")
	var base: float = (1.0 + floorf(wave * 0.7)) * hp_growth(wave) * Rules.orb_hp * Vary.hp_k()
	var dmg: float = base * _perk_val("riposte") * (1.0 + _perk_val("riposte_more") * (perks.get("riposte", 1) - 1))
	for o in near(p, r):
		if o.hp <= 0.0 or o.ghost:
			continue
		var d: float = o.position.distance_to(p)
		if d < r + o.radius():
			o.hurt(dmg)
			o.knock((o.position - p).normalized() * 60.0 if d > 0.1 else Vector2.ZERO)
	if core_fx.size() < 20:
		core_fx.append([p, r, FX_RIPOSTE])


## 회복 특성이 이번 웨이브에 채우는 체력. 처음 고른 것은 regen(1), 겹친 것은 하나당 regen_more(0.5)이고, 1이 안 되는 나머지는 다음 웨이브로 넘긴다.
func _regen_take() -> int:
	regen_acc += _perk_val("regen") + _perk_val("regen_more") * (perks.get("regen", 0) - 1)
	var h := int(regen_acc)
	regen_acc -= h
	return h


func _perk_val(id: String) -> float:
	return Patch.num("perks", id, PERK_VALS[id])


## 숫자 하나로 끝나는 특성은 그림 + 숫자로 (설명 글은 말풍선). 패치로 설명이 바뀌어 숫자를 못 찾으면 글 그대로.
const PERK_GLYPH := {"power": "dmg", "haste": "rate", "reach": "range", "slow": "fast", "regen": "core", "reroll": "reroll"}


func _perk_big(id: String, desc: String) -> Dictionary:
	if not PERK_GLYPH.has(id):
		return {}
	if id == "regen" and perks.get("regen", 0) > 0:  # 이미 있으면 겹친 회복 값
		return {"big": "+%s/웨이브" % String.num(_perk_val("regen_more")), "i": PERK_GLYPH[id]}
	var re := RegEx.create_from_string("[+-]\\d+(\\.\\d+)?%?")
	var mm := re.search(desc)
	if mm == null:
		return {}
	return {"big": mm.get_string() + ("/웨이브" if id == "regen" else ""), "i": PERK_GLYPH[id]}


func _perk_desc(pk: Dictionary) -> String:
	return Patch.text("perk_desc", pk["id"], pk["desc"])


func _perk_text() -> String:
	var parts := PackedStringArray()
	for pk in PERKS:
		var n: int = perks.get(pk["id"], 0)
		if n > 0:
			parts.append(pk["name"] + (" x%d" % n if n > 1 else ""))
	return "특성: " + ", ".join(parts) if not parts.is_empty() else ""


func _on_reroll() -> void:
	if phase != Phase.CHOOSE or get_tree().paused or coin_stage > 0:
		return
	if perk_mode:
		_perk_reroll()
		return
	if rerolls_left <= 0:
		_show_toast("이번 쉬는 시간의 새로고침을 다 썼어요")  # Q를 눌러도 아무 일이 없던 것
		return
	rerolls_left -= 1
	Ach.on_reroll()
	_log_offer({})
	_make_choices()
	_update_reroll_btn()
	_save_run()


## 특성 새로고침: 지금 나온 특성 말고 다른 것으로 3개를 다시 뽑는다 (모자라면 지금 것으로 채움).
func _perk_reroll() -> void:
	if perk_rerolls <= 0 or not _perk_can_reroll():
		_show_toast("이번 특성 선택의 새로고침을 다 썼어요")
		return
	perk_rerolls -= 1
	var now: Array = perk_offer.map(func(pk): return pk["id"])
	var pool := _perk_pool()
	var fresh: Array = pool.filter(func(pk): return not pk["id"] in now)
	var old: Array = pool.filter(func(pk): return pk["id"] in now)
	fresh.shuffle()
	old.shuffle()
	perk_offer = (fresh + old).slice(0, 3)
	_show_perks()
	_save_run()


## 다시 뽑으면 다른 특성이 하나라도 나올 수 있는지
func _perk_can_reroll() -> bool:
	var now: Array = perk_offer.map(func(pk): return pk["id"])
	return _perk_pool().any(func(pk): return not pk["id"] in now)


## 새로고침 버튼: 남은 횟수를 같이 보여 준다.
## 선택지 내리기·올리기 (V): 카드에 가려진 필드를 본다. 마우스를 올린 오브젝트 범위·정보는 그대로 보인다.
func _toggle_cards_hidden() -> void:
	if card_dock.input_blocked():
		return
	_set_cards_hidden(not cards_hidden)


func _set_cards_hidden(h: bool) -> void:
	if phase != Phase.CHOOSE:
		return
	cards_hidden = h
	choice_box.visible = not h
	hover_elem = -1
	_tap_hover()  # 다시 올리면 터치로 고르던 카드 미리보기도 다시
	_update_reroll_btn()


func _update_reroll_btn() -> void:
	if perk_mode:
		reroll_btn.visible = perk_rerolls > 0 and not cards_hidden and coin_stage == 0 and _perk_can_reroll()
		reroll_btn.text = str(perk_rerolls)
		reroll_btn.tooltip_text = "특성 새로고침 (Q): 이번 특성 선택에 %d번 남음" % perk_rerolls
		return
	reroll_btn.visible = rerolls_left > 0 and not cards_hidden  # 모드 '외길'은 늘 0
	reroll_btn.text = str(rerolls_left)
	reroll_btn.tooltip_text = "선택지 새로고침 (Q): 이번 쉬는 시간에 %d번 남음" % rerolls_left


## 진입 방향은 웨이브마다 조금씩 늘고, 가끔 하나가 옮겨 간다.
func _roll_lanes() -> void:
	if TutPlay.on:
		lanes.assign(TutPlay.lanes_for(wave + 1))  # 연습 판: 정해진 길목
		return
	var n := lanes_for(wave + 1)
	if Meta.map_id == "line":
		# 회랑: 한쪽 끝 하나 (각도는 중앙 점에서 구체가 오는 쪽)
		lanes = [PI if Meta.line_flip else 0.0]
		return
	if Meta.map_id == "cross":
		# 십자로: 처음부터 네 방향 고정
		if lanes.size() != 4:
			var r0 := wf() * TAU
			lanes = [r0, r0 + PI / 2, r0 + PI, r0 + PI * 1.5]
		return
	if Meta.map_id == "storm":
		# 폭풍: 매번 전부 새로
		lanes.clear()
	if not lanes.is_empty() and wf() < 0.25:
		lanes.remove_at(wi() % lanes.size())
	while lanes.size() < n:
		lanes.append(_free_lane())


## 다른 방향과 0.8 이상 떨어진 새 방향. 자리가 모자라면 가장 넓은 틈의 가운데에 둔다
## (6곳이 될 때 기존 방향이 고르게 퍼져 있으면 빈자리가 없어 게임이 멈추던 것).
func _free_lane() -> float:
	for i in 40:
		var a := wf() * TAU
		if lanes.all(func(b): return absf(angle_difference(a, b)) >= 0.8):
			return a
	var ls: Array = lanes.map(func(b): return fposmod(b, TAU))
	ls.sort()
	var best := 0
	var gap := 0.0
	for i in ls.size():
		var g := fposmod(ls[(i + 1) % ls.size()] - ls[i], TAU)
		if g <= 0.0:
			g = TAU  # 방향이 하나뿐일 때
		if g > gap:
			gap = g
			best = i
	return fposmod(ls[best] + gap / 2.0, TAU)


## 설치된 오브젝트에 겹쳤을 때 생기는 특수 반응 안내 문구들.
## 속성 카드: 넣으면 생길 반응의 짝 속성·반응 이름, 레벨업 가능한 곳 수.
func _combo_parts(e: int) -> Dictionary:
	var els: Array = []
	var names := PackedStringArray()
	var ups := 0
	var card := {"type": "elem", "e": e}
	for t in towers.get_children():
		if not t.can_take(card):  # 속성 종류 상한으로 못 넣는 오브젝트는 셈에서 뺀다
			continue
		for r in Elem.new_reactions(t.elements, e):
			var o: int = r["b"] if r["a"] == e else r["a"]
			if not els.has(o):
				els.append(o)
			if not names.has(r["name"]):
				names.append(r["name"])
		if t.elements.has(e):
			ups += 1
	return {"els": els, "names": names, "ups": ups}


func _els_name(t: Tower) -> String:
	var parts := PackedStringArray()
	for e in t.order:
		parts.append(Elem.NAMES[e])
	return "·".join(parts)


## 다음 웨이브 안내: 진입 화살표 배지(구체 수·섞여 나오는 종류)와, 배지에 올리면 뜨는 자세한 글.
func _update_preview() -> void:
	var nw := wave + 1
	var info_l: Array = []
	var kinds: Array = []
	var W := Color(1, 1, 1, 0.9)
	var lk := _leak_text()
	if lk != "":
		info_l.append([lk, Color(1, 0.6, 0.6)])
	info_l.append(["다음 웨이브 %d: 구체 %d개, 진입 방향 %d곳" % [nw, spawn_count(nw), lanes.size()], W])
	if mp_next_extra > 0:
		info_l.append(["상대가 보낸 구체 +%d개 (이번 웨이브 구체와 같은 세기, 아무 방향)" % mp_next_extra, Color(1, 0.55, 0.45)])
	var firsts := {4: "빠른 구체", 7: "단단한 구체", 8: "보호막 두른 구체(먼저 보호막을 깎아야 함)", 12: "분열 구체(터지면 둘로 나뉨)", 11: "이제부터 구체 체력이 웨이브마다 %d%%씩 곱으로 늘어남" % roundi((Rules.hp_growth - 1.0) * 100)}
	for f in [[Rules.resist_from, "저항 구체(같은 색 점선 고리: 그 속성 피해를 덜 받음. 오브젝트에서 그 속성이 차지하는 만큼, 최대 60%)"], [Rules.sturdy_from, "굳센 구체(회색 쐐기: 밀기·감속·기절·냉기 절반)"]]:
		firsts[f[0]] = (firsts[f[0]] + ", " if firsts.has(f[0]) else "") + f[1]
	var body := Color(0.85, 0.85, 0.9)
	var mix := PackedStringArray()
	for m in [[4, "fast", "빠른 구체(뾰족)"], [7, "tank", "단단한 구체(네모)"], [8, "shield", "보호막"], [12, "split", "분열"]]:
		if nw >= m[0]:
			mix.append(m[2])
			kinds.append([m[1], body, nw == m[0]])
	for id in LATE_IDS:
		var lf := late_from(id)
		if nw >= lf:
			mix.append(LATE_NAMES[id] + (" %d%%" % roundi(late_share(id, nw) * 100) if id != "devour" else " %d" % int(Rules.t("late_devour_n"))))
			kinds.append([id, body, nw == lf])
			if nw == lf:
				firsts[lf] = (firsts[lf] + ", " if firsts.has(lf) else "") + LATE_DESC[id]
	for id in JAM_IDS:
		var jf := jam_from(id)
		if nw >= jf and jams_on():
			mix.append(JAM_NAMES[id] + " %d%%" % roundi(jam_share(id, nw) * 100))
			kinds.append([id, body, nw == jf])
			if nw == jf:
				firsts[jf] = (firsts[jf] + ", " if firsts.has(jf) else "") + JAM_DESC[id]
	if not mix.is_empty():
		info_l.append(["섞여 나옴: " + ", ".join(mix), W])
	var sp := PackedStringArray()
	if wave_resist >= 0:
		sp.append("%s 저항 구체 %d%%" % [Elem.NAMES[wave_resist], roundi(resist_share(nw) * 100)])
		kinds.append(["resist", Elem.COLORS[wave_resist], nw == Rules.resist_from])
	if sturdy_share(nw) > 0.0:
		sp.append("굳센 구체 %d%%" % roundi(sturdy_share(nw) * 100))
		kinds.append(["sturdy", Color(0.75, 0.75, 0.8), nw == Rules.sturdy_from])
	if nw > 10:
		sp.append("구체 체력 x%.1f" % hp_growth(nw))
	if not sp.is_empty():
		info_l.append(["특수 구체: " + " · ".join(sp), W])
	if firsts.has(nw):
		info_l.append(["처음 등장: " + firsts[nw], Color(1, 0.75, 0.75)])
	if nw % 5 == 0:
		info_l.insert(0, ["⚠ 보스 웨이브 · 놓치면 중앙 체력 -3", Color(1, 0.35, 0.4)])
		for l in _boss_text().split("\n"):
			info_l.append([l, Color(1, 0.75, 0.85)])
	else:
		var bw := ceili(nw / 5.0) * 5
		info_l.append(["다음 보스: 웨이브 %d (%d웨이브 뒤)" % [bw, bw - wave], Color(1, 0.75, 0.85)])
	if MapRule.is_map("spiral") and wave > 0 and wave % 5 == 0:
		info_l.append(["회오리: 이번 웨이브부터 회전 방향이 바뀜", MAP_AFF_COLOR])
	if MapRule.is_map("storm"):
		info_l.append(["뇌우: 바람 방향은 화면의 흰 화살표 (순풍 탄 +%d%%, 역풍 -%d%%)" % [roundi(Rules.t("map_wind_with") * 100), roundi(Rules.t("map_wind_against") * 100)], MAP_AFF_COLOR])
	if Vary.on or Vary.count() > 0:
		var vc := Color(0.75, 0.85, 1.0)
		if not Vary.event.is_empty():
			info_l.append(["이벤트 %s: %s" % [Vary.ename(Vary.event), Vary.edesc(Vary.event)], vc])
		if not Vary.next_event.is_empty():
			info_l.append(["웨이브 %d 뒤 이벤트 %s: %s" % [nw, Vary.ename(Vary.next_event), Vary.edesc(Vary.next_event)], vc])
		if Vary.count() > 0:
			info_l.append(["봉인: " + Vary.sealed_text(), vc])
		var ad := Vary.adapt_text()
		if ad != "":
			info_l.append(["적응 구체 (많이 쓴 것에 저항): " + ad, vc])
	wave_info = info_l
	wave_kinds = kinds
	if wave == 0:
		_guide("lanes", "구체는 빨간 부채꼴 넓이 어디로든 와요. 옆 숫자는 그쪽에서 오는 구체 수(%s 자세히). 부채꼴을 가로지르게, 좁은 중앙 쪽에 설치하면 다 막혀요" % ("누르면" if touch_ui else "올리면"))


## 다음 웨이브 구체를 진입 방향별로 고르게 나눈 수 (보스 제외). 화살표 배지와 실제 웨이브(lane_bag)가 같은 값을 쓴다.
func lane_counts(w: int) -> Array[int]:
	var out: Array[int] = []
	var nl := lanes.size()
	if nl == 0:
		return out
	var n := spawn_count(w) - (1 if w % 5 == 0 else 0)
	for i in nl:
		out.append(n / nl + (1 if i < n % nl else 0))
	return out


## 장면 다시 읽기. 한 프레임에 입력이 여럿 오면 두 번째는 current_scene이 이미 비어 오류가 난다.
func _reload() -> void:
	_mp_keep_room()
	if is_inside_tree() and get_tree().current_scene != null:
		get_tree().reload_current_scene()


## 멀티 판 끝 → 다시 불러오기 전에: 방 연결(Mp)을 루트에 옮겨 두고, 새 화면이 대기방을 열게 표시한다.
func _mp_keep_room() -> void:
	if mp != null and mp_mode != "" and phase == Phase.GAMEOVER and is_inside_tree():
		# 멀티 판 끝 → 대기방으로 (방은 나가기 전까지 남는다)
		mp_back = true
		mp_back_msg = ""
		if mp.active():
			mp_keep = mp
			mp.reparent(get_tree().root)
		else:
			mp_back_msg = mp_fail_msg if mp_fail_msg != "" else "방이 없어져 대기방으로 돌아가지 못했어요"


## 왼쪽 아래 안내 글 위쪽 끝 (안내 글이 없으면 아래 버튼 줄 위).
func _bottom_free() -> float:
	return hint.position.y - 4.0 if hint.text != "" else ui_root.size.y - 60.0


## 진입 화살표 자리 [화살 끝(월드), 들어오는 방향, lanes 번호]. 화살 그림(_draw·_draw_line_map)과 배지가 같은 자리를 쓴다.
func _lane_arrows() -> Array:
	var out: Array = []
	if Meta.map_id == "line":
		var from_right := not Meta.line_flip
		var d := Vector2(-1.0 if from_right else 1.0, 0)
		out.append([Vector2(Meta.FIELD.x - 18.0 if from_right else 18.0, Meta.FIELD.y / 2.0), d, 0])
		return out
	var c := center()
	var vr := arena()
	for i in lanes.size():
		var d := Vector2.from_angle(lanes[i])
		var edge := _edge_point(c, d)
		if Meta.map_id == "spiral":
			var path := PackedVector2Array()
			for q in _orb_path(lanes[i]):
				if not path.is_empty() or vr.has_point(q):
					path.append(q)
			if path.size() >= 2:
				edge = path[0]
				d = (path[0] - path[1]).normalized()
		out.append([edge - d * 18.0, d, i])
	return out


func _strip_key_hints() -> void:
	var nodes: Array = ui_root.find_children("*", "Button", true, false)
	nodes.append_array([dps_head, flip_label])
	nodes.append_array(get_tree().get_nodes_in_group("key_hint"))  # 창 제목 (Esc: 닫기)
	for b in nodes:
		if not is_instance_valid(b):
			continue
		var t0: String = b.text
		var t1 := _kh(t0, b == skip_badge)
		if t1 != t0:
			b.text = t1


## 매 프레임 쓰는 버튼 글은 쓸 때 바로 뺀다 (0.2초마다 빼도 같은 프레임에 다시 써져서 남았다)
func _kh(t: String, tap := false) -> String:
	if not touch_ui or not t.contains("("):
		return t
	return t.replace("(S: ", "(눌러서 ") if tap else key_re.sub(t, "", true)


## 아래 안내 글을 터치에 맞게: 클릭 → 누르기, 우클릭/Esc → 취소 버튼, 키보드·Shift 안내는 뺀다
func _th(t: String) -> String:
	if not touch_ui:
		return t
	return t.replace("Space 또는 [웨이브 시작]", "[웨이브 시작]").replace(" (Shift: 15도 단위)", "") \
		.replace("   오브젝트 우클릭한 채 끌기로도 바로 됨", "").replace("우클릭/Esc", "취소").replace("Esc/우클릭", "취소") \
		.replace("클릭 또는", "누르기 또는").replace("오브젝트를 클릭", "오브젝트 누르기").replace("클릭", "누르기")


## 위쪽 가운데 글(알림·처음 안내)을 가운데에 두되, 오른쪽 설명이 떠 있으면 그 왼쪽까지만 (글자를 키우면 글 끝이 설명 밑에 깔리던 것).
## 글이 정한 폭보다 길면 Label이 오른쪽으로만 늘어나 가운데에서 벗어나던 것도 함께 맞춘다.
## 전장 가운데 글(알림·큰 글)이 넘지 말아야 할 오른쪽 끝: 오른쪽 설명, 쉬는 시간 카드 정보 칸(도크 오른쪽)
func _right_panel_x() -> float:
	var x := ui_root.size.x
	if legend.visible:
		x = minf(x, legend.get_rect().position.x)
	if card_dock != null and card_dock.side != null and card_dock.side.visible and card_dock.side.modulate.a > 0.05:
		x = minf(x, card_dock.side.get_rect().position.x)
	return x


func _beside_legend(c: Control, min_w: float) -> void:
	var w := maxf(min_w, c.get_combined_minimum_size().x)
	var x := (ui_root.size.x - w) / 2.0
	x = minf(x, _right_panel_x() - 8.0 - w)
	c.position.x = maxf(x, 8.0)
	c.size.x = w


## 오른쪽 설명이 떠 있으면 배지를 그 왼쪽으로 비킨다 (설명 글 위에 겹치던 것).
## 아래에 자리가 있으면 설명 아래로, 없으면 왼쪽으로.
func _off_legend(r: Rect2) -> Rect2:
	var lr := legend.get_rect()
	if legend.visible and r.intersects(lr):
		if lr.end.y + 20.0 + r.size.y < info.size.y - 64.0:
			r.position.y = lr.end.y + 20.0
		else:
			r.position.x = lr.position.x - r.size.x - 8.0
	return r


## 배지가 피해야 할 화면 UI 자리 (UI 좌표): 점수 줄·DPS 표·오른쪽 위 버튼·웨이브 시작·아래 안내·버튼 줄·알림 등.
## 예전엔 오른쪽 설명(legend)만 피해서 왼쪽 위 길목 배지가 DPS 표 위에, 아래 길목 배지가 [웨이브 시작] 위에 겹쳤다.
func _info_blockers() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var inv := ui_root.get_global_transform().affine_inverse()
	for c: Control in [hud, dps_panel, legend, range_btn, zoom_btn, start_btn, skip_badge, bar_box, toast, banner, guide_label, guide_more,  mp_bar, ver_label, hint, apply_btn, reroll_btn, card_detail_btn, hide_btn, skip_btn, skip_n_btn, cancel_btn, detail_btn, aim_ok_btn, card_dock.focus_btn, card_dock.panel, card_dock.side, card_dock.footer]:
		if c == null or not c.is_visible_in_tree():
			continue
		if (c is Label and str(c.text) == "") or (c == hud and hud_chips.is_empty()):
			continue
		var r := inv * c.get_global_rect()
		if c == hint and not hint.has_theme_stylebox_override("normal"):
			# 안내 글은 칸이 넓어도 글이 있는 곳만
			var tw := minf(r.size.x, ui_font.get_multiline_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 15).x)
			r.size.x = tw + 4.0
		if r.has_area():
			out.append(r.grow(4.0))
	if choice_header.visible:
		out.append(inv * choice_header.get_global_rect())
	return out


## 배지를 화살표에서 안쪽(전장 가운데 쪽)으로, 모자라면 옆으로 밀어 UI·다른 배지와 겹치지 않는 자리를 찾는다.
## 자리가 없으면 처음 자리 그대로.
func _free_badge(r: Rect2, inward: Vector2, avoid: Array[Rect2], lo_r: Rect2) -> Rect2:
	# 겹친 넓이 (0이면 빈자리)
	var cover := func(q: Rect2) -> float:
		var a := 0.0
		for b in avoid:
			if q.intersects(b):
				a += q.intersection(b).get_area()
		return a
	if is_zero_approx(cover.call(r)):
		return r
	# 같은 자리·같은 UI면 지난 답 그대로 (자리 찾기가 매 프레임 수백 칸을 보지 않게)
	var key := hash([r, inward, avoid, lo_r])
	if _badge_memo.has(key):
		return _badge_memo[key]
	if _badge_memo.size() > 64:
		_badge_memo.clear()
	var found := _free_badge_search(r, inward, lo_r, cover)
	_badge_memo[key] = found
	return found


func _free_badge_search(r: Rect2, inward: Vector2, lo_r: Rect2, cover: Callable) -> Rect2:
	# 화살표에서 가까운 자리부터: 안쪽(가운데 쪽)으로 0~34칸 × 옆으로 -6~6칸, 가까운 순. 바깥쪽(화면 끝)으로는 가지 않는다.
	# 빈자리가 없으면(글자 130%로 UI가 화면을 많이 차지할 때) 가장 덜 겹치는 자리
	if _badge_cands.is_empty():
		for step in range(0, 35):
			for sd in range(-6, 7):
				if step != 0 or sd != 0:
					_badge_cands.append(Vector2(step * 16.0, sd * 20.0))
		_badge_cands.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
	var side := Vector2(-inward.y, inward.x)
	var best := r
	var best_a: float = cover.call(r)
	for c: Vector2 in _badge_cands:
		var q := r
		q.position += inward * c.x + side * c.y
		q.position = q.position.clamp(lo_r.position, lo_r.end - q.size)
		var a: float = cover.call(q)
		if is_zero_approx(a):
			return q
		if a < best_a - 1.0:
			best_a = a
			best = q
	return best


## 화면 위 아이콘 층: 진입 화살표 옆 구체 수 배지, 놓친 구체, 남은 고르기, 칩·배지에 올리면 뜨는 말풍선.
func _draw_info() -> void:
	tip_rects.clear()
	info_rects.clear()
	var size := info.size
	var top := hud.position.y + hud.size.y + 6.0 if hud.visible else 8.0
	var lo := size.y - 64.0
	if card_dock.active():
		top = maxf(top, card_dock.bounds().position.y)
		lo = size.y - 8.0
	if hud.visible:
		for ch in hud_chips:
			tip_rects.append([Rect2(hud.position + ch[0].position, ch[0].size), ch[5]])
	var resting := phase in [Phase.CHOOSE, Phase.PLACE, Phase.AIM, Phase.MOVE, Phase.READY] and not title_label.visible and not get_tree().paused
	if resting and not lanes.is_empty():
		var xf := ui_root.get_global_transform().affine_inverse() * get_canvas_transform()
		var nw := wave + 1
		var counts := lane_counts(nw)
		var badges: Array[Rect2] = []
		# 카드 위에 겹친 배지는 옅게 (글자를 키우면 카드가 화면 끝까지 차서 덮던 것). 카드를 내리면 다시 진하게
		var cards_r := Rect2()
		if phase == Phase.CHOOSE and choice_box.visible and not cards_hidden:
			cards_r = ui_root.get_global_transform().affine_inverse() * choice_box.get_global_rect()
		var boss_li := -1
		if nw % 5 == 0:
			boss_li = 0 if Meta.map_id == "line" or boss_plan.is_empty() else _lane_of(boss_plan["a"])
		var fs := 18
		# 폰: 배지가 7개까지 겹쳐 전장을 덮었다 → 수와 보스 왕관만, 섞여 나오는 종류는 점 하나(누르면 말풍선)
		var compact := _phone() or (card_dock.active() and phase == Phase.CHOOSE)
		var blockers := _info_blockers()
		# 오브젝트도 되도록 가리지 않는다 (배지를 비킬 때 오브젝트 위에 얹히던 것)
		for t in towers.get_children():
			blockers.append(Rect2(xf * t.position - Vector2(22, 26), Vector2(44, 48)))
		# 보스 길 안내(고리·"보스 · 웨이브 N" 글자·들어오는 길)도 가리지 않는다
		for br in _boss_mark_rects():
			blockers.append(xf * br)
		for arr in _lane_arrows():
			var li: int = arr[2]
			var n: int = counts[li] if li < counts.size() else 0
			if Meta.map_id == "line":
				n = spawn_count(nw) - (1 if nw % 5 == 0 else 0)
			var txt := "×%d" % n
			var tw := ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var nk := (0 if compact else wave_kinds.size()) + (1 if li == boss_li else 0)
			var w := 10.0 + tw + (6.0 + nk * 22.0 if nk > 0 else 0.0) + 8.0
			var p: Vector2 = xf * (arr[0] - arr[1] * 60.0)
			var r := Rect2(p - Vector2(w, 30.0) / 2.0, Vector2(w, 30.0))
			var gx := size.x
			var gy := lo
			r.position = r.position.clamp(Vector2(8.0, top), Vector2(gx - w - 8.0, gy - 30.0))
			var nh := 13.0 if not compact and wave_kinds.any(func(k): return k[2]) else 0.0  # 위에 붙는 NEW
			var avoid: Array[Rect2] = blockers.duplicate()
			for br in badges:
				avoid.append(br.grow(4.0))
			var inward: Vector2 = (xf.basis_xform(-arr[1])).normalized()
			r = _free_badge(r.grow_side(SIDE_TOP, nh), inward, avoid, Rect2(8.0, 8.0, gx - 16.0, size.y - 16.0)).grow_side(SIDE_TOP, -nh)
			badges.append(r)
			# 카드 위에 걸친 배지는 그리지 않는다 (옅게 그려도 카드 글을 가렸고, 마우스를 올리면 말풍선이 카드를 덮었다). 카드를 내리면(V) 보인다
			if cards_r.has_area() and r.intersects(cards_r):
				continue
			info_rects.append(["배지 %s" % txt, r.grow_side(SIDE_TOP, 13.0 if not compact and wave_kinds.any(func(k): return k[2]) else 0.0)])
			var al := 0.35 if card_dim.visible else 1.0  # 카드 선택 막 아래 전장 것이라 같이 옅게
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.16, 0.04, 0.06, 0.88 * al)
			sb.border_color = Color(1, 0.35, 0.4, 0.9 * al)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(7)
			var home := Rect2(p - Vector2(w, 30.0) / 2.0, Vector2(w, 30.0))
			var far := r.get_center().distance_to(home.get_center())
			if far > 70.0 and far < 240.0:  # 너무 멀면 선이 화면을 가로질러 더 어지럽다 (글자 130%·길목 7곳)
				# UI를 피해 화살표에서 멀리 비켜났으면 화살표 쪽으로 옅은 선 (어느 길목 배지인지 보이게)
				var tip: Vector2 = xf * arr[0]
				# 카드 뒤의 화살표까지 잇는 선은 패널 윗변에서 멈춘다.
				if card_dock.panel.visible and tip.y > card_dock.panel.position.y:
					var from := r.get_center()
					var fraction := (card_dock.panel.position.y - 8 - from.y) / maxf(1, tip.y - from.y)
					tip = from.lerp(tip, clampf(fraction, 0, 1))
				var c0 := r.get_center()
				var e0 := c0 + (tip - c0).normalized() * minf(r.size.x, r.size.y) * 0.5
				info.draw_dashed_line(e0, tip - (tip - c0).normalized() * 14.0, Color(1, 0.4, 0.45, 0.35), 2.0, 6.0)
			info.draw_style_box(sb, r)
			var x := r.position.x + 10.0
			var cy := r.get_center().y
			info.draw_string(ui_font, Vector2(x, cy + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.88, 0.88, al))
			x += tw + 6.0
			if compact and not wave_kinds.is_empty():
				# 특수 구체가 섞이면 오른쪽 위 점 (처음 나오는 종류가 있으면 더 크게)
				var fresh := wave_kinds.any(func(k): return k[2])
				info.draw_circle(Vector2(r.end.x - 2.0, r.position.y + 2.0), 6.0 if fresh else 4.5, Color(1, 0.45, 0.45) if not fresh else Color(1, 0.85, 0.3))
			for k in ([] if compact else wave_kinds):
				Icons.draw(info, k[0], Vector2(x + 11.0, cy), 7.5, Color(k[1], k[1].a * al))
				if k[2] and al >= 1.0:
					# 처음 나오는 종류: 위에 작은 NEW
					var nr := Rect2(x - 1.0, r.position.y - 13.0, 24.0, 13.0)
					info.draw_rect(nr, Color(0.9, 0.25, 0.3))
					info.draw_string(ui_font, Vector2(nr.position.x + 1.0, nr.end.y - 2.0), "NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
				x += 22.0
			if li == boss_li:
				Icons.draw(info, "boss", Vector2(x + 11.0, cy), 7.5, Color(1, 0.6, 0.75, al))
			var lines: Array = [["이쪽에서 구체 %d개%s" % [n, " + 보스" if li == boss_li else ""], Color(1, 0.85, 0.85)]]
			tip_rects.append([r.grow(4.0), lines + wave_info])
		# 지난 웨이브에 놓친 구체: 그 방향 가장자리에 빨간 -N (다음 웨이브에 방향이 바뀌어도 어디서 샜는지 보이게)
		for lm in leak_marks:
			var d := Vector2.from_angle(lm[0])
			var ep: Vector2 = _lane_arrows()[0][0] if Meta.map_id == "line" else _entry_point(lm[0])
			var p: Vector2 = xf * (ep - (Vector2(-1.0 if not Meta.line_flip else 1.0, 0) if Meta.map_id == "line" else d) * 120.0)
			var txt := "-%d" % lm[1]
			var w := Icons.chip_w(ui_font, txt, 16)
			var r := Rect2(p - Vector2(w, 26.0) / 2.0, Vector2(w, 26.0))
			r.position = r.position.clamp(Vector2(8.0, top), Vector2(size.x - w - 8.0, lo - 26.0))
			var avoid: Array[Rect2] = blockers.duplicate()
			for br in badges:
				avoid.append(br.grow(4.0))
			var inward: Vector2 = Vector2(1.0 if not Meta.line_flip else -1.0, 0) * -1.0 if Meta.map_id == "line" else (xf.basis_xform(-d)).normalized()
			r = _free_badge(r, inward, avoid, Rect2(8.0, 8.0, size.x - 16.0, size.y - 16.0))
			badges.append(r)
			if cards_r.has_area() and r.intersects(cards_r):
				continue
			info_rects.append(["놓친 %s" % txt, r])
			var la := 0.35 if card_dim.visible else 1.0
			Icons.chip(info, ui_font, r, "orb", Color(0.85, 0.85, 0.9, la), txt, Color(1, 0.5, 0.5, la), 16, Color(0.1, 0.02, 0.03, 0.85 * la), Color(1, 0.4, 0.4, 0.6 * la))
			tip_rects.append([r, [["지난 웨이브에 이쪽에서 놓친 구체 %d개" % lm[1], Color(1, 0.6, 0.6)], [_leak_text(), Color(1, 1, 1, 0.7)]]])
	# 카드 선택 막 위로: 마우스를 올린 속성 카드로 새 반응이 생기는 오브젝트 고리 (전장의 고리는 막에 가려 옅다)
	if card_dim.visible and hover_elem >= 0:
		var xf2 := ui_root.get_global_transform().affine_inverse() * get_canvas_transform()
		var cr := ui_root.get_global_transform().affine_inverse() * choice_box.get_global_rect()
		var pz := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.7)
		var zs := xf2.get_scale().x
		var hcard := {"type": "elem", "e": hover_elem}
		for t in towers.get_children():
			if not t.can_take(hcard):
				continue
			var fresh := Elem.new_reactions(t.eff_now(), hover_elem)
			if fresh.is_empty():
				continue
			var tp: Vector2 = xf2 * t.position
			var rr := (Tower.RADIUS + 10.0 + pz * 4.0) * zs
			if cr.grow(rr).has_point(tp):
				continue
			if guide_label.visible and guide_label.get_rect().grow(rr).has_point(tp):
				continue  # 처음 안내 글 위에 걸치지 않게
			info.draw_arc(tp, rr, 0, TAU, 32, Color(fresh[0]["color"], 0.95), 3.0)
	# 선택 안내는 카드 줄 전체 폭의 독립 헤더. 개별 카드의 설명처럼 붙이지 않는다.
	if choice_header.visible:
		var r := choice_header.get_rect()
		tip_rects.append([r, [["이번 쉬는 시간에 카드를 %d장 더 선택할 수 있어요" % picks_left, Color(1, 0.9, 0.6)]]])
		if Vary.count() > 0:
			var sr := _draw_seal_chip(info, r.get_center().x, r.position.y - 6.0)
			tip_rects.append([sr, [["봉인 모드: 이번 판 선택지에 안 나오는 카드", Color(0.8, 0.8, 1.0)], [Vary.sealed_text(), Color(1, 1, 1, 0.9)], ["25·50웨이브에 하나씩 풀려요", Color(1, 1, 1, 0.6)]]])
	_draw_card_full()
	# 말풍선: 마우스를 올린 칩·배지 (터치는 누른 것)
	var m := info.get_local_mouse_position()
	var hit := -1
	for i in tip_rects.size():
		if (tip_pin == i and touch_ui) or (not touch_ui and tip_rects[i][0].has_point(m)):
			hit = i
	if hit < 0:
		return
	var tfs := 15
	var rows: Array = []
	var tw2 := 0.0
	for l in tip_rects[hit][1]:
		if str(l[0]) == "":
			continue
		for row in _wrap_words(l[0], 520.0, tfs).split("\n"):
			rows.append([row, l[1]])
			tw2 = maxf(tw2, ui_font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x)
	var lh := tfs + 6.0
	var bs := Vector2(tw2 + 20.0, rows.size() * lh + 12.0)
	var src: Rect2 = tip_rects[hit][0]
	var bp := Vector2(src.end.x + 8.0, src.position.y)
	if src.position.y < top:
		bp = Vector2(src.position.x, src.end.y + 6.0)  # 점수 줄 칩: 바로 아래 (옆 칩을 덮지 않게)
	elif bp.x + bs.x > size.x - 8.0:
		bp.x = src.position.x - bs.x - 8.0
	if bp.x < 8.0:
		bp = Vector2(src.position.x, src.end.y + 6.0)
	bp.x = clampf(bp.x, 8.0, maxf(8.0, size.x - bs.x - 8.0))
	bp.y = clampf(bp.y, 8.0, maxf(8.0, size.y - bs.y - 8.0))
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	tb.border_color = Color(1, 1, 1, 0.3)
	tb.set_border_width_all(1)
	tb.set_corner_radius_all(6)
	info.draw_style_box(tb, Rect2(bp, bs))
	for i in rows.size():
		info.draw_string(ui_font, bp + Vector2(10.0, 6.0 + tfs + i * lh), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, rows[i][1])


## 보스 길이(화면 밖 출발점부터 중앙까지)와 막지 않을 때 걸리는 시간.
func _boss_eta() -> float:
	var pts := _orb_path(boss_plan["a"], boss_plan.get("y", 0.0))
	var L := 0.0
	for i in range(1, pts.size()):
		L += pts[i - 1].distance_to(pts[i])
	L -= CORE_RADIUS + 30.0  # 보스 반지름만큼 먼저 닿는다
	return L / (boss_plan["spd"] * 0.45 * orb_speed_mul * Modes.speed() * lane_k(boss_plan["a"]))


## 다음 보스 안내 (쉬는 시간에 미리 뽑아 둔 그대로).
func _boss_text() -> String:
	if boss_plan.is_empty():
		return "보스 등장! 중앙에 닿으면 체력 3 감소"
	var sp := PackedStringArray(["보스: 체력 %s" % num(ceilf(boss_plan["hp"] * 12.0 * Modes.boss_hp()))])
	if boss_plan["resist"] >= 0:
		sp.append("%s 저항" % Elem.NAMES[boss_plan["resist"]])
	if boss_plan["sturdy"]:
		sp.append("굳셈(밀기·감속·기절·냉기 절반)")
	sp.append("웨이브 마지막에 나옴")
	sp.append("%d초마다 빠른 부하 구체를 부름" % roundi(Orb.minion_every(boss_plan["wave"])))
	return " · ".join(sp) + "\n보스 길: 화면의 분홍 선(흐르는 화살). 막지 않으면 나온 뒤 약 %d초에 중앙 (닿으면 체력 -3)" % roundi(_boss_eta())


## 바람 버프 둘레: 늘 그리면 바람 오브젝트마다 큰 원이 겹쳐 어지러워서,
## 바람 오브젝트에 Shift 자세히로 올렸을 때(그 둘레), 버프 받는 오브젝트에 자세히로 올렸을 때(버프를 주는 둘레),
## 오브젝트를 옮기는 중일 때(모든 둘레)만 그린다.
func _draw_wind_rings() -> void:
	return  # 2026-11-04 바람 효과가 순풍(둘레 공격 속도) → 밀쳐냄으로 바뀌어 둘레가 없다
	if title_label.visible or phase == Phase.GAMEOVER:
		return
	var winds := towers.get_children().filter(func(t): return t.lv(Elem.WIND) > 0)
	if winds.is_empty():
		return
	var show: Array = []
	if _place_rings_off():
		pass
	elif moving != null or dragging or phase in [Phase.PLACE, Phase.MOVE]:
		show = winds
	else:
		var h := _ring_target()  # 올린 오브젝트 둘레는 자세히일 때만
		if h != null:
			for w in winds:
				if w == h or w.position.distance_to(h.position) <= w.wind_range():
					show.append(w)
	var sp := fmod(Time.get_ticks_msec() / 1000.0 * 0.5, 1.0)
	var wc: Color = Elem.COLORS[Elem.WIND]
	for w in show:
		draw_arc(w.position, w.wind_range(), sp * TAU, sp * TAU + TAU * 0.85, 48, Color(wc, 0.35), 1.5)


## 카드를 넣는 단계에서 모든 바람·별 둘레를 끌지: 새로 놓을 수 없는 카드(강화·연계 등)이거나 오브젝트 위에 올려 둔 동안.
## 둘레는 새 자리를 고를 때만 쓸모 있고, 여러 개가 겹치면 올린 오브젝트 설명·범위가 묻힌다. 올린 오브젝트 자기 둘레는 draw_range가 그린다.
func _place_rings_off() -> bool:
	return phase == Phase.PLACE and moving == null and not dragging and (picked.get("type", "") != "elem" or _tower_at(_pointer_world()) != null)


## 별 흡수 둘레: 오브젝트를 놓거나 옮기는 중엔 모든 별의 둘레(어디 두면 별빛을 주는지),
## 별빛을 주는 오브젝트에 자세히(Shift)로 올리면 그걸 받는 별의 둘레. 별 자신에 올렸을 때·Alt·[범위 보기]는 draw_range가 그린다.
func _draw_star_rings() -> void:
	if title_label.visible or phase == Phase.GAMEOVER or Input.is_key_pressed(KEY_ALT) or range_all:
		return
	# star_towers는 웨이브 계산 때만 갱신되니 쉬는 시간에도 맞게 여기서 직접 고른다
	var stars := towers.get_children().filter(func(t): return t.lv(Elem.STAR) > 0)
	if stars.is_empty():
		return
	var show: Array = []
	if _place_rings_off():
		pass
	elif moving != null or dragging or phase in [Phase.PLACE, Phase.MOVE, Phase.AIM]:
		show = stars.filter(func(s): return s != moving)
	else:
		var h := _ring_target()
		if h != null:
			for s in stars:
				if s != h and s.position.distance_to(h.position) < Rules.t("star_r"):
					show.append(s)
	for s in show:
		Tower.draw_star_ring(self, s.position, Elem.COLORS[Elem.STAR])


## 보스가 올 길: 쉬는 시간과, 보스 웨이브에서 보스가 나오기 전까지.
## 진입 부채꼴: 구체가 실제로 올 수 있는 범위(진입 각도 a ± sp)를 옅게 칠하고 테두리, 화면 가장자리엔 입구 막대,
## 흐르는 점은 폭 전체에. 소용돌이는 나선 길을 ±sp 돌린 띠. 웨이브 중엔 더 옅게.
func _draw_lane_fan(a: float, sp: float, now: float) -> void:
	if sp <= 0.0:
		return
	var c := center()
	var rest := phase != Phase.WAVE
	var col := Color(1, 0.3, 0.35)
	var fill := Color(col, 0.16 if rest else 0.05)
	var rim := Color(col, 0.5 if rest else 0.18)
	var bar := Color(col, 0.9 if rest else 0.3)
	const N := 16
	if Meta.map_id == "spiral":
		var vr := arena().grow(2.0)
		var mid := PackedVector2Array()
		for q in _orb_path(a):
			if not mid.is_empty() or vr.has_point(q):
				mid.append(q)
		if mid.size() < 2:
			return
		var lo := PackedVector2Array()
		var hi := PackedVector2Array()
		for q in mid:
			lo.append(c + (q - c).rotated(-sp))
			hi.append(c + (q - c).rotated(sp))
		var fade := func(q: Vector2) -> Color: return Color(fill, fill.a * clampf((q.distance_to(c) - 40.0) / 360.0, 0.0, 1.0))
		for i in range(1, mid.size()):
			if vr.has_point(lo[i]) or vr.has_point(hi[i]):
				draw_polygon(PackedVector2Array([lo[i - 1], lo[i], hi[i], hi[i - 1]]),
					PackedColorArray([fade.call(lo[i - 1]), fade.call(lo[i]), fade.call(hi[i]), fade.call(hi[i - 1])]))
		for side in [lo, hi]:
			var cut := PackedVector2Array()
			for q in side:
				if not cut.is_empty() or vr.has_point(q):
					cut.append(q)
			if cut.size() >= 2:
				draw_polyline(cut, rim, 2.0)
		if rest:
			for k in 5:
				var f := fmod(now * 0.25 + k / 5.0, 1.0)
				var q: Vector2 = mid[mini(int(f * (mid.size() - 1)), mid.size() - 1)]
				for j in 3:
					var r := (j - 1) * sp
					draw_circle(c + (q - c).rotated(r), 2.5, Color(col, 0.5 * (1.0 - f)))
		return
	var edge := PackedVector2Array()
	for k in N + 1:
		edge.append(_edge_point(c, Vector2.from_angle(a - sp + 2.0 * sp * k / N)))
	# 가장자리에서 진하고 중앙으로 갈수록 투명하게 (길목이 6곳이면 화면 전체가 붉어지고, 중앙에 테두리가 몰려 어지러웠다)
	var poly := PackedVector2Array([c])
	poly.append_array(edge)
	var cols := PackedColorArray([Color(fill, 0.0)])
	for k in N + 1:
		cols.append(fill)
	draw_polygon(poly, cols)
	var clear := Color(rim, 0.0)
	draw_polyline_colors(PackedVector2Array([c, edge[0]]), PackedColorArray([clear, rim]), 2.0)
	draw_polyline_colors(PackedVector2Array([c, edge[N]]), PackedColorArray([clear, rim]), 2.0)
	draw_polyline(edge, bar, 5.0 if rest else 3.0)
	if rest:
		# 중앙 쪽으로 흐르는 점을 폭 전체에 (가운데 한 줄만 흐르면 그 선으로만 오는 줄 안다)
		for j in 5:
			var e := _edge_point(c, Vector2.from_angle(a - sp + 2.0 * sp * (j + 0.5) / 5.0))
			for k in 3:
				var f := fmod(now * 0.25 + k / 3.0 + j * 0.13, 1.0)
				draw_circle(e.lerp(c, f * 0.85), 2.5, Color(col, 0.55 * (1.0 - f)))


## 보스 길 표시 자리 (그림과 진입 배지 비키기가 같은 값을 쓴다). 그릴 게 없으면 빈 사전.
## pts: 화면 안 길, lens: 누적 길이, m: 들어오는 자리 고리, lp·lw: 글자 자리·폭.
func _boss_mark() -> Dictionary:
	if boss_plan.is_empty() or title_label.visible or phase == Phase.GAMEOVER:
		return {}
	if phase == Phase.WAVE and boss_plan["wave"] != wave:
		return {}
	var vr := arena()
	var all := _orb_path(boss_plan["a"], boss_plan.get("y", 0.0))
	# 화면 안에 들어온 뒤부터 그린다 (직선은 화면 가장자리에서 자름)
	var pts := PackedVector2Array()
	if Meta.map_id == "line":
		pts.append(Vector2(clampf(all[0].x, 0.0, vr.size.x), all[0].y))
		pts.append(all[1])
	elif all.size() == 2:
		pts.append(_edge_point(center(), Vector2.from_angle(boss_plan["a"])))
		pts.append(all[1])
	else:
		for p in all:
			if not pts.is_empty() or vr.has_point(p):
				pts.append(p)
	if pts.size() < 2:
		return {}
	var lens: Array[float] = [0.0]
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i - 1].distance_to(pts[i]))
	var total: float = lens[-1]
	# 들어오는 자리: 큰 고리 + 글자. 가장자리의 버튼·점수 줄에 가리지 않게 길을 따라 안쪽(110)에
	var at := minf(110.0, total * 0.4)
	var j2 := 1
	while j2 < pts.size() - 1 and lens[j2] < at:
		j2 += 1
	var d2 := (pts[j2] - pts[j2 - 1]).normalized()
	var m := pts[j2 - 1] + d2 * (at - lens[j2 - 1])
	var label := "보스 · 웨이브 %d" % boss_plan["wave"]
	var w := ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, BOSS_FS).x
	# 길 옆에 쓴다 (길 위에 쓰면 화살과 겹침): 중앙에서 먼 쪽 옆
	var side := d2.orthogonal()
	if side.dot(m - core()) < 0.0:
		side = -side
	var lp := m + side * 30.0 + Vector2(-w / 2.0 if absf(side.x) < 0.5 else (0.0 if side.x > 0.0 else -w), 6.0)
	lp = lp.clamp(Vector2(8, 70), vr.size - Vector2(w + 8, 70))
	return {"pts": pts, "lens": lens, "m": m, "lp": lp, "lw": w, "label": label}


## 진입 배지가 피할 보스 표시 자리(월드 좌표): 고리·글자·화면 안 길.
func _boss_mark_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var bm := _boss_mark()
	if bm.is_empty():
		return out
	var m: Vector2 = bm["m"]
	out.append(Rect2(m - Vector2(26, 26), Vector2(52, 52)))
	out.append(Rect2(bm["lp"] - Vector2(4, BOSS_FS + 2), Vector2(bm["lw"] + 8, BOSS_FS + 10)))
	# 길 전체 (중앙 점 둘레는 빼고): 소용돌이는 꺾인 길을 마디마다
	var pts: PackedVector2Array = bm["pts"]
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var L := a.distance_to(pts[i])
		var d := (pts[i] - a) / maxf(L, 0.01)
		var s := 0.0
		while s < L:
			var q := a + d * s
			if q.distance_to(core()) > CORE_RADIUS + 30.0:
				out.append(Rect2(q - Vector2(8, 8), Vector2(16, 16)))
			s += 20.0
	return out


const BOSS_FS := 16


func _draw_boss_path(now: float) -> void:
	var bm := _boss_mark()
	if bm.is_empty():
		return
	var col := Color(1, 0.35, 0.6)
	var pts: PackedVector2Array = bm["pts"]
	var lens: Array[float] = bm["lens"]
	var pulse := 0.75 + 0.25 * sin(now * 3.0)
	draw_polyline(pts, Color(col, 0.6 * pulse), 2.5)
	# 보스가 오는 쪽으로 흐르는 화살 (길이 비율로 놓는다)
	var total: float = lens[-1]
	for k in 3:
		var dpos := fmod(now * 0.12 + k / 3.0, 1.0) * (total - CORE_RADIUS - 20.0)
		var j := 1
		while j < pts.size() - 1 and lens[j] < dpos:
			j += 1
		var seg := pts[j] - pts[j - 1]
		if seg.length() < 0.01:
			continue
		var d := seg.normalized()
		var q := pts[j - 1] + d * (dpos - lens[j - 1])
		draw_colored_polygon(PackedVector2Array([q + d * 9.0, q - d * 5.0 + d.orthogonal() * 7.0, q - d * 5.0 - d.orthogonal() * 7.0]), Color(col, 0.85))
	var m: Vector2 = bm["m"]
	draw_arc(m, 20.0 + 3.0 * sin(now * 5.0), 0, TAU, 32, Color(col, 0.95), 3.0)
	draw_circle(m, 9.0, Color(col, 0.9))
	var lp: Vector2 = bm["lp"]
	draw_string_outline(ui_font, lp, bm["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, BOSS_FS, 4, Color(0, 0, 0, 0.9))
	draw_string(ui_font, lp, bm["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, BOSS_FS, Color(1, 0.75, 0.85))


## 카드 선택 안내·봉인 칩에 필요한 카드 위 공간 (UI 좌표).
func _choice_headroom() -> float:
	if card_dock != null and card_dock.active():
		return 0.0
	if phase != Phase.CHOOSE or perk_mode or cards_hidden:
		return 0.0
	return CHOICE_HEADER_H + CHOICE_HEADER_GAP + (32.0 if Vary.count() > 0 else 0.0)


func _update_choice_header() -> void:
	choice_header.visible = phase == Phase.CHOOSE and not perk_mode and choice_box.visible and not cards_hidden \
		and choice_box.get_child_count() > 0 and not title_label.visible and not get_tree().paused
	if not choice_header.visible:
		return
	var inv := ui_root.get_global_transform().affine_inverse()
	var first := inv * (choice_box.get_child(0) as Control).get_global_rect()
	var last := inv * (choice_box.get_child(choice_box.get_child_count() - 1) as Control).get_global_rect()
	choice_remaining.text = "%d장 더 선택 가능" % picks_left
	choice_header.size = Vector2(last.end.x - first.position.x, CHOICE_HEADER_H)
	choice_header.position = Vector2(first.position.x, first.position.y - CHOICE_HEADER_H - CHOICE_HEADER_GAP)


## 터치 미리보기의 적용 동작. 위치는 카드 아래 조작 줄에서 함께 정한다.
func _place_apply_btn() -> void:
	var cs := choice_box.get_children() if choice_box else []
	var on := touch_ui and phase == Phase.CHOOSE and not perk_mode and choice_box.visible and not cards_hidden \
		and tap_sel >= 0 and tap_sel < cs.size() and not cs[tap_sel].is_queued_for_deletion() and not get_tree().paused
	apply_btn.visible = on
	if not on:
		return
	var head: Dictionary = cs[tap_sel].get_meta("card")[0]
	apply_btn.text = "%s 적용" % head["name"]
	apply_btn.set_meta("choice_icon", head.duplicate())
	apply_btn.queue_redraw()


## 카드와 같은 벡터 그림을 금색 버튼의 글자 왼쪽에 그린다.
func _draw_apply_icon() -> void:
	var head: Dictionary = apply_btn.get_meta("choice_icon", {})
	if head.is_empty():
		return
	var tw := ui_font.get_string_size(apply_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var c := Vector2((apply_btn.size.x - tw - 26.0) / 2.0 + 9.0, apply_btn.size.y / 2.0)
	var ink := Color(0.12, 0.09, 0.02)
	if head.has("e"):
		Glyph.elem(apply_btn, head["e"], c, 9.0, ink)
	elif head.has("pat"):
		Glyph.pat(apply_btn, head["pat"], c, 9.0, ink)
	else:
		Glyph.kind(apply_btn, head["kind"], c, 9.0, ink)



## PC·터치 모두 한 번 눌러 든다.
func _on_card_tap(card: Dictionary, _i: int) -> void:
	if phase != Phase.CHOOSE or card_dock.suppress_tap or card_dock.input_blocked():
		return
	_on_pick(card)


func _release_card_tap_guard() -> void:
	card_dock.suppress_tap = false
	card_dock.touch_capture = false


## 터치로 고른(미리보기 중인) 카드의 속성 미리보기와 카드 진하기.
func _tap_hover() -> void:
	if tap_sel >= 0 and tap_sel < offer.size() and not cards_hidden:
		hover_elem = offer[tap_sel]["e"] if offer[tap_sel]["type"] == "elem" else -1
	var cs := choice_box.get_children()
	for k in cs.size():
		cs[k].modulate.a = 0.55 if tap_sel >= 0 and k != tap_sel else 1.0


func _on_pick(card: Dictionary) -> void:
	if TutPlay.on and tplay != null and not tplay.allow_pick(card):
		return
	_save_run()  # 카드를 들고 앱을 닫아도 적용 전 목록과 남은 선택을 복원한다.
	tap_sel = -1
	_tap_hover()
	picked = card
	selected.clear()
	hover_elem = -1
	choice_box.visible = false
	reroll_btn.visible = false
	phase = Phase.PLACE
	card_dock.inspected_tower = null
	hint.text = _th(_place_hint())
	if card_dock.active():
		card_dock.tick()


## 통계용 카드 이름: elem:fire, pat:spray, mod:rapid, link:reso
func _stat_key(card: Dictionary) -> String:
	if card.get("type", "") == "elem":
		return "elem:" + Patch.ELEM_KEYS[Elem.ALL.find(card["e"])]
	return "%s:%s" % [card.get("type", ""), card.get("id", "")]


## 이번 선택지와 고른 카드(빈 사전: 새로고침으로 넘김)를 판 기록에 남긴다.
func _log_offer(card: Dictionary) -> void:
	var e := {"w": wave, "k": "card", "o": offer.map(_stat_key), "p": _stat_key(card) if not card.is_empty() else ""}
	if not bank_picks.is_empty():
		e["bw"] = bank_picks[0]  # 넘기기로 미뤘던 고르기: 쌓은 쉬는 시간의 웨이브
	run_log.append(e)


func _place_hint() -> String:
	match picked.get("type", "elem"):
		"elem":
			return PLACE_HINT
	return "넣을 오브젝트를 클릭   꾹 누르기·끌기: 옮기기\n우클릭/Esc: 카드 다시 선택"


## card: 이번에 넣은 카드.
func _after_place(card: Dictionary = {}) -> void:
	_log_offer(picked if card.is_empty() else card)
	Ach.on_pick(_stat_key(picked if card.is_empty() else card))
	_check_progress()
	picks_left -= 1
	if not bank_picks.is_empty():
		bank_picks.pop_front()  # 미룬 고르기부터 쓴다
	if picks_left > 0:
		_start_choose(false)
	else:
		_enter_ready()
		if auto_start:
			countdown = 2.0


## 자동 시작이 꺼져 있을 때: 설치를 마치고 Space를 기다린다. 이때도 오브젝트를 옮길 수 있다.
func _enter_ready() -> void:
	phase = Phase.READY
	choice_box.visible = false
	reroll_btn.visible = false
	start_btn.visible = true
	start_btn.text = "웨이브 시작 (Space)"
	hint.text = _th(READY_HINT if Meta.games < 3 else "")
	_save_run()


func _start_wave_from_ready() -> void:
	if phase == Phase.READY:
		_start_wave()


## 버튼 위에 아이콘을 그린다. 글이 있으면 왼쪽, 없으면 가운데. icon은 [아이콘, 색]을 돌려준다.
func _icon_btn(b: Button, icon: Callable) -> void:
	# 벡터 아이콘을 덧그려도 native 버튼이 글 옆의 아이콘 공간을 확보하게 한다.
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	b.icon = ImageTexture.create_from_image(image)
	b.add_theme_constant_override("h_separation", 8)
	b.draw.connect(func():
		var ic: Array = icon.call()
		Glyph.ui(b, ic[0], _button_icon_center(b), 8.5, ic[1]))


func _button_icon_center(b: Button) -> Vector2:
	var style := b.get_theme_stylebox("normal")
	var left := style.get_content_margin(SIDE_LEFT)
	var width := b.size.x - left - style.get_content_margin(SIDE_RIGHT)
	var text_width := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
	var content_width := 18.0 + (text_width + b.get_theme_constant("h_separation") if b.text != "" else 0.0)
	return Vector2(left + (width - content_width) / 2.0 + 9, b.size.y / 2.0)


## 버튼 오른쪽 위 모서리에 작은 단축키 상자 (터치 화면에선 안 그림). key는 글 또는 글을 돌려주는 Callable.
func _keycap(b: Button, key: Variant) -> void:
	b.theme_type_variation = "ShortcutButton"
	b.add_to_group("keycap")
	b.draw.connect(func():
		var k: String = key.call() if key is Callable else key
		if not touch_ui and k != "":
			Glyph.keycap(b, ui_font, Vector2(b.size.x - 3.0, 3.0), k, 9))


## 메뉴 그림 버튼: 위에 그림, 아래 짧은 이름 (버튼 글은 비움).
func _menu_glyph(b: Button, icon: String, label: String) -> void:
	b.text = ""
	b.draw.connect(func():
		var hov := b.is_hovered()
		var c := Color(1, 1, 1, 1.0 if hov else 0.9)
		var fs := 13
		Glyph.ui(b, icon, Vector2(b.size.x / 2.0, b.size.y * 0.4), 10.0, c)
		b.draw_string(ui_font, Vector2(0, b.size.y - 7.0), label, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, fs, Color(c, 0.75)))


## 터치는 말풍선(tooltip)을 볼 수 없어 글 없는 아이콘 버튼이 무엇을 바꿨는지 몰랐다: 누르면 이름·상태를 잠깐 띄운다.
func _icon_toast(b: Button) -> void:
	if touch_ui and b.tooltip_text != "":
		_show_toast(_kh(b.tooltip_text.get_slice("\n", 0)))


func _toggle_mute() -> void:
	sfx.set_muted(not sfx.muted)
	mute_btn.tooltip_text = "소리: " + ("끔" if sfx.muted else "켬") + " (M)"
	mute_btn.queue_redraw()
	_save_best()


func _toggle_auto() -> void:
	auto_start = not auto_start
	_update_auto_btn()
	_save_best()
	if auto_start and phase == Phase.READY:
		countdown = 2.0
	elif not auto_start:
		countdown = -1.0
		if phase == Phase.READY:
			start_btn.text = "웨이브 시작 (Space)"


func _toggle_legend() -> void:
	legend_hidden = not legend_hidden
	_save_best()


## 카드 도크·설명 칸을 접어 전장을 넓게 보거나 다시 연다 (F·모바일 버튼).
func _toggle_focus_view() -> void:
	_toggle_cards_hidden()


func _toggle_bar() -> void:
	bar_open = not bar_open
	_save_best()


func _update_auto_btn() -> void:
	auto_btn.tooltip_text = "자동 시작: " + ("켬" if auto_start else "끔") + " (웨이브가 끝나고 카드 선택을 마치면 바로 다음 웨이브)"
	auto_btn.queue_redraw()


func _start_wave() -> void:
	# 멀티는 준비 동기화·잠수 자동 진행을 우선한다. 한 기기의 배치로 시작을 거부하면
	# 호스트의 wave 통지와 실제 단계가 달라지거나 대결이 무기한 멈출 수 있다.
	var forced := TutPlay.on and tplay != null and tplay.force_start
	if TutPlay.on and tplay != null and not tplay.can_start():
		countdown = -1.0
		return
	if mp_mode == "" and not forced:
		var blocked := _wave_start_block_reason()
		if blocked != "":
			countdown = -1.0
			_show_toast(blocked)
			return
	if mp_mode == "coop" and not mp_wave_go:
		countdown = -1.0
		_mp_coop_ready()
		return
	countdown = -1.0
	_drop_press()
	boxing = false
	selected.clear()
	start_btn.visible = false
	wave += 1
	rest_ready = false
	phase = Phase.WAVE
	wave_active = true
	choice_box.visible = false
	reroll_btn.visible = false
	to_spawn = spawn_count(wave)
	mp_extra_left = mp_next_extra
	mp_wave_extra = mp_next_extra
	mp_next_extra = 0
	mp_recv_n = 0
	mp_idle_t = 0.0
	# 진입 방향은 배지에 띄운 수대로 고르게 나눠 섞는다 (구체마다 무작위로 고르면 화살표의 수와 달라짐)
	lane_bag.clear()
	var lc := lane_counts(wave)
	for i in lc.size():
		for k in lc[i]:
			lane_bag.append(i)
	_wshuffle(lane_bag)
	if mp_ghost:
		to_spawn = 0  # 협동 참가자: 구체는 호스트가 보낸 대로
		lane_bag.clear()
	wave_leaks.clear()
	leak_marks.clear()
	wave_dmg = 0
	jam_any = false
	skill_cd = {}  # 중앙 기술은 웨이브마다 다시 찬다
	skill_arm = ""
	if not skill_ids.is_empty():
		_guide("skill", "아래 기술 버튼%s을 누르고 쓸 곳을 누르면 웨이브 중에 도울 수 있어요. 웨이브마다 다시 차요" % ("" if touch_ui else "(1·2 키)"))
	shield = _shield_wave()
	rampart_left = _rampart_n()
	if guide_t < 0.0:
		guide_lines.clear()
		guide_t = 0.0
	for w in [10, 15, 20]:
		if wave >= w:
			_achieve("wave%d" % w)
	Ach.on_wave_start(wave, towers.get_children(), Meta.map_id)
	_ach_check()
	spawn_interval = maxf(0.35, 1.2 - wave * 0.06)
	spawn_timer = 0.5
	wave_time = 0.0
	late_n = {}
	dps_hist.clear()
	dps_t = 0.0
	dps_n = 0
	rank_t = RANK_HOLD + 0.05  # 피해가 다시 쌓인 뒤에 매긴다
	for t in towers.get_children():
		t.cd.clear()
		t.fx.clear()
		t.run_dealt += t.dealt
		t.close_src()
		t.wave_begin()
		t.dealt = 0.0
		t.rx_dealt = 0.0
		t.queue_redraw()  # 레벨 숫자는 쉬는 시간에만
	hint.text = ""
	big_banner("웨이브 %d" % wave, Color.WHITE)
	sfx.play("wave", 0.0)


## 모든 다음 웨이브 진입 방향에 적어도 하나의 오브젝트 공격이 닿는지 확인한다.
## 시작 버튼·Space·자동 시작·넘기기·멀티 호스트가 모두 _start_wave를 지나므로 여기서 막는다.
func _wave_start_block_reason() -> String:
	if lanes.is_empty():
		return ""
	var w := wave + 1
	var spread := lane_spread(w)
	var missed: Array[String] = []
	for i in lanes.size():
		if not _wave_lane_covered(lanes[i], w, spread):
			missed.append(compass(lanes[i]))
	if missed.is_empty():
		return ""
	return "웨이브를 시작할 수 없어요: %s쪽 공격이 닿지 않아요. 오브젝트의 위치나 방향을 맞춰 주세요" % "·".join(missed)


## 진입 길을 따라 여러 지점을 살펴 공격 사거리·방향 안에 들어오는 오브젝트를 찾는다.
func _wave_lane_covered(a: float, w: int, spread: float) -> bool:
	var path := _orb_path(a)
	if path.size() < 2:
		return true
	var samples: Array[Vector2] = []
	if Meta.map_id == "line":
		for y in [-LINE_HALF + 20.0, 0.0, LINE_HALF - 20.0]:
			var line_path := _orb_path(a, y)
			for k in range(1, 9):
				samples.append(line_path[0].lerp(line_path[1], float(k) / 9.0))
	else:
		for seg in range(path.size() - 1):
			var length := path[seg].distance_to(path[seg + 1])
			var n := maxi(1, ceili(length / 45.0))
			for k in n:
				samples.append(path[seg].lerp(path[seg + 1], float(k) / n))
	for t: Tower in towers.get_children():
		var reach := _wave_attack_reach(t)
		if reach <= 0.0:
			continue
		for p in samples:
			var v := p - t.position
			var dist := v.length()
			if dist < 8.0 or dist > reach:
				continue
			# 자동 조준·중력 우물은 공격 방향을 고정하지 않는다. 나머지는 공격 폭과
			# 구체의 진입 부채꼴을 함께 고려해 중앙선을 겨눈 공격도 유효하게 판정한다.
			if t.m("reflex") > 0 or t.pattern == "vortex":
				return true
			var half := 0.12
			match t.pattern:
				"spray": half = 0.35
				"chain": half = 0.5
				"sonic": half = 0.5
				"clock": half = 0.7
			var width := atan(18.0 / dist)
			if absf(t.dir.angle_to(v)) <= maxf(half, width) + spread:
				return true
	return false


## 기본 공격방식별 유효 사거리. 수치는 실제 공격·사거리 표시와 같은 기준이다.
func _wave_attack_reach(t: Tower) -> float:
	if t.pattern in Tower.FAR_PATS and t.m("reflex") == 0:
		return Tower.FAR  # 직선탄·돌풍·물줄기·연쇄 번개는 화면 끝까지 (멀면 약해질 뿐)
	return t.well_range() if t.pattern == "vortex" else t.reflex_range()


func _game_over() -> void:
	_mp_over()
	_tut_event("over")
	_log_wave()
	phase = Phase.GAMEOVER
	over_ms = Time.get_ticks_msec()
	toast_timer = 0.0  # 넘기기 알림 등이 게임 오버 글 위에 남지 않게
	wave_active = false
	game_speed = 1.0
	_update_speed_btn()
	banner_queue.clear()  # 남은 가운데 글자가 게임 오버 글 위에 뜨지 않게 (새 업적은 아래 글에 나옴)
	banner_t = minf(banner_t, 0.4)
	# 기록은 지금 맵·규칙 버전의 저장값과 비교한다 (다른 키에서 남은 값이 섞이지 않게)
	var prev := Meta.best_of(Meta.run_key())
	var record := "  최고 기록!" if (score > prev[1] or wave > prev[0]) and mp_mode == "" else ""
	if mp_mode == "":  # 멀티플레이 판은 혼자 하는 판 최고 기록에 넣지 않는다
		best_score = maxi(score, prev[1])
		best_wave = maxi(wave, prev[0])
	if mp_mode == "":  # 멀티 판은 누적 처치·판 수(업적)에 넣지 않는다
		Meta.total_kills += kills
		Meta.games += 1
	Ach.live_kills = 0
	_ach_check()
	if tutor:
		Meta.tutor_next = false
	_save_best()
	_clear_run()
	net.sync()
	var ach := "\n새 업적: " + ", ".join(new_achievements) if not new_achievements.is_empty() else ""
	# 판 전체에서 가장 많이 때린 오브젝트
	var mvp := ""
	var top: Tower = null
	var total := 0.0
	for t in towers.get_children():
		total += t.run_dealt + t.dealt
		if top == null or t.run_dealt + t.dealt > top.run_dealt + top.dealt:
			top = t
	if top and total > 0.0 and towers.get_child_count() > 1:
		mvp = "\n최다 피해: %s (%d%%)" % [top.title(), roundi((top.run_dealt + top.dealt) / total * 100.0)]
	var rs := _run_src()
	if total > 0.0 and not rs.is_empty():
		var tops := PackedStringArray()
		for key in _src_top(rs, 3):
			tops.append("%s %d%%" % [src_name(key), roundi(rs[key] / total * 100.0)])
		mvp += "\n피해 출처: " + ", ".join(tops)
	var md := "" if Modes.on.is_empty() else "\n모드: %s · 점수 x%.2f%s" % [Modes.names(), Modes.mul(), "\n쉽게 모드: 최고 기록 따로, 쉽게 모드 리더보드에 올라감" if Modes.easy() else ""]
	if mp_mode != "":
		record = ""
		md = "\n" + mp_rank if mp_rank != "" else ""
	var head: String = ("협동 끝" if mp_mode == "coop" else "탈락") if mp_mode != "" else "판 끝냄" if ended else "게임 오버"
	over_data = {"head": head, "sub": "%s · %s" % [Meta.map_name(Meta.map_id), Rules.NAMES[Meta.rules]], "wave": wave, "score": score, "record": record != "", "best_wave": best_wave if mp_mode == "" else -1,
		"kills": kills, "combo": best_combo, "towers": towers.get_child_count(), "ach": new_achievements.duplicate()}
	# 아래 글은 그림으로 못 줄인 것만 (모드·순위·최다 피해·피해 출처, 온라인 순위는 나중에 붙음)
	over_label.text = _kr_keep((md + mvp).strip_edges())
	over_card.visible = true
	over_card.queue_redraw()
	over_label.visible = true
	_submit_run()
	sfx.play("over", 0.0)
	reroll_btn.visible = false
	choice_box.visible = false
	hint.text = ""


## 게임 오버 그림 카드 (over_card 가운데가 화면 가운데 위쪽).
func _draw_over_card() -> void:
	if not over_label.visible or over_data.is_empty():
		return
	var d := over_data
	var c := over_card
	var W := 620.0
	var x0 := -W / 2.0
	var y := -210.0
	# 업적 배지 줄 나누기를 먼저 해서 바탕 높이를 안다
	var ach_rows: Array = []
	var ach_w: Array = []
	for a in d["ach"]:
		var aw := ui_font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 36.0
		if ach_rows.is_empty() or ach_w[-1] + aw > W:
			ach_rows.append([])
			ach_w.append(0.0)
		ach_rows[-1].append([a, aw])
		ach_w[-1] += aw + 6.0
	var bh := 84.0 + 96.0 + 50.0 + ach_rows.size() * 30.0 + 34.0
	# 아래 남은 글(over_label: 모드·최다 피해·피해 출처)까지 바탕에 넣는다: 예전엔 바탕 밖 전장 위에 떠 읽기 어려웠다
	var lab_h := 0.0
	if over_label.text != "" and over_label.get_line_count() > 0:
		lab_h = over_label.get_line_count() * over_label.get_line_height() + 10.0
	bh += lab_h
	# 점수 줄 아래에서 시작 (폰 글자 1.3이면 화면 높이가 줄어 제목이 점수 줄 둘째 줄을 덮었다), 아래 버튼 줄 위까지
	var top_free := _dps_home().y - c.position.y
	var bottom_free := (c.get_parent() as Control).size.y - 56.0 - c.position.y
	if y - 6.0 < top_free:
		y = maxf(minf(top_free, bottom_free - bh), y - 6.0) + 6.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	bg.set_corner_radius_all(12)
	c.draw_style_box(bg, Rect2(x0 - 10.0, y - 6.0, W + 20.0, bh))
	c.draw_string(ui_font, Vector2(x0, y + 34.0), d["head"], HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color.WHITE)
	var sw := ui_font.get_string_size(d["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0
	Icons.chip(c, ui_font, Rect2(-sw / 2.0, y + 46.0, sw, 24.0), "", Color.WHITE, d["sub"], Color(1, 1, 1, 0.65), 14, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12))
	# 큰 칩 둘: 웨이브 · 점수
	y += 84.0
	for i in 2:
		var r := Rect2(-196.0 + i * 204.0, y, 188.0, 62.0)
		var gold := i == 1
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.15, 0.08, 0.95) if gold else Color(0.1, 0.12, 0.17, 0.95)
		sb.border_color = Color(1, 0.85, 0.4, 0.6) if gold else Color(0.5, 0.7, 1, 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		c.draw_style_box(sb, r)
		Icons.draw(c, "score" if gold else "wave", r.position + Vector2(30, 31), 13.0, Color(1, 0.85, 0.4) if gold else Color(0.6, 0.8, 1))
		var txt := num(d["score"]) if gold else str(d["wave"])
		var fs := 32
		while fs > 18 and ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 120.0:
			fs -= 2
		c.draw_string(ui_font, r.position + Vector2(54, 31 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if d["record"]:
		Icons.chip(c, ui_font, Rect2(132.0, y - 9.0, 64.0, 20.0), "", Color.WHITE, "최고!", Color(0.12, 0.09, 0.0), 12, Color(1, 0.85, 0.4), Color(1, 0.85, 0.4))
	elif d["best_wave"] >= 0:
		Icons.draw(c, "best", Vector2(-110.0, y + 76.0), 6.0, Color(1, 1, 1, 0.5))
		c.draw_string(ui_font, Vector2(-100.0, y + 80.0), "최고 %d" % d["best_wave"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
	# 작은 칩: 처치 · 최고 콤보 · 오브젝트
	y += 110.0
	var smalls := [["kill", num(d["kills"]), "처치"], ["combo", str(d["combo"]), "최고 콤보"], ["tower", str(d["towers"]), "오브젝트"]]
	for i in smalls.size():
		var cx := -130.0 + i * 130.0
		Glyph.ui(c, smalls[i][0], Vector2(cx - 22.0, y), 9.0, Color(0.85, 0.9, 1))
		c.draw_string(ui_font, Vector2(cx - 8.0, y + 7.0), smalls[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
		c.draw_string(ui_font, Vector2(cx - 50.0, y + 24.0), smalls[i][2], HORIZONTAL_ALIGNMENT_CENTER, 100.0, 11, Color(1, 1, 1, 0.45))
	# 새 업적 배지 (줄이 넘치면 다음 줄)
	y += 42.0
	for ri in ach_rows.size():
		var x: float = -(ach_w[ri] - 6.0) / 2.0
		for it in ach_rows[ri]:
			var r := Rect2(x, y + ri * 30.0, it[1], 24.0)
			Icons.chip(c, ui_font, r, "", Color.WHITE, "", Color.WHITE, 13, Color(0.15, 0.12, 0.2, 0.95), Color(0.8, 0.6, 1, 0.5))
			Glyph.kind(c, "ach", r.position + Vector2(14, 12), 7.0, Color(1, 0.8, 0.4))
			c.draw_string(ui_font, r.position + Vector2(26, 17), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			x += it[1] + 6.0
	y += ach_rows.size() * 30.0
	# 남은 글(over_label)은 배지 바로 아래, 나가는 법은 그 아래 바탕 끝 줄
	if absf(over_label.offset_top - (y + 4.0)) > 0.5:
		over_label.offset_top = y + 4.0  # (둘 다 화면 가운데 기준)
		over_label.offset_bottom = y + 154.0
	var dim := Color(1, 1, 1, 0.5)
	var to_lobby := mp_mode != "" and mp.active()  # 멀티 판: 방이 남아 있으면 대기방으로
	var hy := y + lab_h + 14.0
	if touch_ui:
		c.draw_string(ui_font, Vector2(x0, hy), "눌러서 대기방으로" if to_lobby else "눌러서 시작 화면으로", HORIZONTAL_ALIGNMENT_CENTER, W, 13, dim)
	else:
		# 그림(마우스·집)만으로는 무엇을 누르면 어디로 가는지 알기 어려웠다: 글로
		c.draw_string(ui_font, Vector2(x0, hy), "클릭 · R · Esc: " + ("대기방으로" if to_lobby else "시작 화면으로"), HORIZONTAL_ALIGNMENT_CENTER, W, 13, dim)


# ---------- 입력 ----------

## 두 손가락 벌리기·모으기 = 확대, 두 손가락 끌기 = 이동. PC는 휠 = 확대(커서 쪽), 휠 누른 채 끌기 = 이동.
## 처리했으면 true (그 입력은 게임·UI로 넘기지 않는다).
func _zoom_input(event: InputEvent) -> bool:
	if card_dock != null and card_dock.active():
		if event is InputEventMouseButton and card_dock.over_ui(event.position):
			if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
				mid_drag = false
			return false
		if event is InputEventScreenTouch and event.pressed and card_dock.over_ui(event.position):
			return false
	if title_label == null or title_label.visible or phase == Phase.GAMEOVER:
		touches.clear()
		pinch_lock = false
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		if touches.size() >= 2:
			if not pinch_lock:
				pinch_lock = true
				_abort_touch_action()  # 첫 손가락이 시작한 놓기·끌기·그리기를 거둔다
			var ps: Array = touches.values()
			pinch_d = maxf((ps[0] as Vector2).distance_to(ps[1]), 1.0)
			pinch_z = view_zoom
		elif touches.is_empty():
			var was := pinch_lock
			pinch_lock = false
			return was  # 마지막 손가락을 뗀 것도 누르기로 치지 않는다
		return pinch_lock
	if event is InputEventScreenDrag:
		if not touches.has(event.index):
			return pinch_lock
		var prev: Vector2 = touches[event.index]
		touches[event.index] = event.position
		if touches.size() >= 2 and pinch_lock:
			var ps: Array = touches.values()
			var d := maxf((ps[0] as Vector2).distance_to(ps[1]), 1.0)
			var mid: Vector2 = ((ps[0] as Vector2) + (ps[1] as Vector2)) / 2.0
			_zoom_to(pinch_z * d / pinch_d, mid)
			_pan_by((event.position - prev) / 2.0)  # 두 손가락의 가운데가 움직인 만큼
			return true
		return pinch_lock
	if pinch_lock and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return true  # 손가락에서 흉내 낸 마우스
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = event.pressed and view_zoom > 1.0
			return mid_drag or not event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not _over_scroll_ui(event.position):
			if _wheel_turn(event):
				return true
			_zoom_to(view_zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), event.position)
			return true
	if event is InputEventMouseMotion and mid_drag:
		_pan_by(event.relative)
		return true
	return false


## PC 쉬는 시간: 선택한 내 오브젝트 위에서 휠 = 그 자리에서 15도씩 돌리기 (Shift: 5도). 위로 굴리면 시계 반대.
## 그 밖의 곳에서는 휠이 그대로 확대. 트랙패드처럼 잘게 오는 휠은 모아서 한 칸씩 돈다.
func _wheel_turn(event: InputEventMouseButton) -> bool:
	if touch_ui or perk_mode or get_tree().paused or not phase in [Phase.CHOOSE, Phase.READY] or press_t or boxing:
		return false
	if settings_panel.visible or notes_panel.visible or codex_panel.visible or vote_panel.visible or records_panel.visible or help_label.visible:
		return false
	var t := _tower_at(get_canvas_transform().affine_inverse() * event.position)
	if t == null or not _mine(t) or not t in selected:
		return false
	wheel_acc += event.factor if event.factor > 0.0 else 1.0
	if wheel_acc < 1.0:
		return true
	wheel_acc = 0.0
	var step := deg_to_rad(5.0 if Input.is_key_pressed(KEY_SHIFT) else 15.0)
	t.set_attack_direction(t.dir.rotated(-step if event.button_index == MOUSE_BUTTON_WHEEL_UP else step))
	if tplay != null:
		tplay.flags["aimed"] = true
	t.queue_redraw()
	sfx.play("place")
	_save_run()
	return true


## 휠을 굴릴 창(도감·패치노트·도움말·DPS 표 등)이 마우스 아래 있으면 확대하지 않는다.
func _over_scroll_ui(p: Vector2) -> bool:
	var h := get_viewport().gui_get_hovered_control() if get_viewport().has_method("gui_get_hovered_control") else null
	if h != null and h != ui_root and h != info:
		return true
	return settings_panel.visible or notes_panel.visible or help_label.visible or records_panel.visible or codex_panel.visible or vote_panel.visible or get_tree().paused


## 두 번째 손가락이 닿으면: 첫 손가락으로 시작한 누르기·끌기·그리기·상자 선택을 없던 일로.
func _abort_touch_action() -> void:
	if press_t:
		_drop_press()
		_restore_hint()
	boxing = false
	aim_hold = false
	if dragging and moving:
		_cancel_step()


## OS 포인터를 조회하지 않고 입력 이벤트의 화면 좌표를 현재 카메라로 변환한다.
var pointer_position := Vector2.ZERO


func _pointer_screen() -> Vector2:
	return pointer_position


func _pointer_world() -> Vector2:
	return get_canvas_transform().affine_inverse() * pointer_position


## 터치에서 흉내 낸 마우스는 장치 번호 EMULATION으로 구분한다.
func _input(event: InputEvent) -> void:
	var was_touch := touch_ui
	if event is InputEventMouse:
		pointer_position = event.position
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer_position = event.position
		touch_ui = true
		touch_tip_t = TOUCH_TIP_SEC
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		touch_ui = false
	if touch_ui != was_touch:
		get_tree().call_group("keycap", "queue_redraw")
		if legend:
			_refresh_legend()
	if dps_panel != null and ((event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed):
		dps_panel.press_check(event.position)
		if card_dock != null:
			card_dock.side.press_check(event.position)
	if mp_mode != "" and ((event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.pressed):
		_mp_presence()
	if _info_input(event) or (card_dock != null and card_dock.handle_input(event)) or _zoom_input(event):
		get_viewport().set_input_as_handled()


func _info_tip_at(screen: Vector2) -> int:
	if hud.is_visible_in_tree() and hud.get_global_rect().has_point(screen) and card_dock._tower_under(screen):
		return -1
	var at := ui_root.get_global_transform().affine_inverse() * screen
	for i in range(tip_rects.size() - 1, -1, -1):
		if tip_rects[i][0].has_point(at):
			return i
	return -1


## 원래 터치와 흉내 낸 마우스의 누름/뗌을 각각 소비해 뒤 전장으로 넘기지 않는다.
func _info_input(event: InputEvent) -> bool:
	if card_dock == null or card_dock.input_blocked():
		info_mouse_capture = false
		info_touch_capture = -1
		return false
	if event is InputEventMouseMotion and info_mouse_capture:
		return true
	if event is InputEventScreenDrag and event.index == info_touch_capture:
		return true
	var mouse: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch
	if mouse and not event.pressed and info_mouse_capture:
		info_mouse_capture = false
		return true
	if touch and not event.pressed and event.index == info_touch_capture:
		info_touch_capture = -1
		return true
	if not (mouse or touch) or not event.pressed:
		return false
	var at: Vector2 = (event as InputEventScreenTouch).position if touch else (event as InputEventMouseButton).position
	var was := tip_pin
	if touch:
		tip_pin = -1
	if card_dock.over_ui(at, false):
		return false
	var hit := _info_tip_at(at)
	if hit < 0:
		return false
	_abort_touch_action()
	if touch:
		info_touch_capture = event.index
		tip_pin = -1 if was == hit else hit
	else:
		info_mouse_capture = true
	return true


func _unhandled_input(event: InputEvent) -> void:
	# 글 입력 칸(닉네임)에 쓰는 중엔 단축키를 막는다. 한글 조합 중 키는 입력 칸이 받지 않고 넘겨서
	# ㅐ(O)·ㅔ(P)·ㅡ(M) 같은 글자가 설정 닫기·일시정지·소리 끄기로 먹혔다. Esc는 그대로 창을 닫는다.
	if event is InputEventKey and get_viewport().gui_get_focus_owner() is LineEdit and event.keycode != KEY_ESCAPE:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if coin_stage > 0 and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3]:
			_coin_tap()
			return
		if event.keycode == KEY_O:
			_toggle_settings()
			return
		if event.keycode == KEY_N and (title_label.visible or settings_panel.visible or notes_panel.visible):
			_toggle_notes()
			return
		if event.keycode == KEY_ESCAPE and notes_panel.visible:
			_close_notes()
			return
		if event.keycode == KEY_ESCAPE and (settings_panel.visible or records_panel.visible or help_label.visible or modes_panel.visible or codex_panel.visible or vote_panel.visible):
			settings_panel.visible = false
			codex_panel.visible = false
			if vote_panel.visible:
				vote_panel.hide_panel()
			modes_panel.visible = false
			records_panel.visible = false
			help_label.visible = false
			return
		if title_label.visible:
			match event.keycode:
				KEY_H:
					if help_label.visible:
						help_label.visible = false
					else:
						_open_tut_list()
				KEY_K:
					_toggle_codex()
				KEY_V:
					if vote_btn and vote_btn.visible:
						_toggle_vote()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					if prep:
						_close_title()
					elif continue_btn.visible:
						_continue_run()
					else:
						_set_prep(true)
				KEY_ESCAPE:
					if prep:
						_set_prep(false)
				KEY_LEFT:
					if prep:
						_cycle_map(-1)
				KEY_RIGHT:
					if prep:
						_cycle_map(1)
				KEY_F:
					if prep:
						_toggle_flip()
				KEY_UP:
					if prep and Meta.games > 0:
						_cycle_rules(-1)
				KEY_DOWN:
					if prep and Meta.games > 0:
						_cycle_rules(1)
				KEY_F11:
					_toggle_fullscreen()
				KEY_M:
					_toggle_mute()  # 시작 화면에도 소리 버튼이 보인다
			return
		if get_tree().paused and event.keycode not in [KEY_ESCAPE, KEY_P, KEY_R, KEY_E, KEY_T, KEY_X, KEY_H, KEY_M, KEY_D, KEY_F11]:
			return
		if event.keycode == KEY_ESCAPE and phase == Phase.GAMEOVER:
			if Time.get_ticks_msec() - over_ms > 800:
				title_seen = false
				_reload()
			return
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif event.keycode == KEY_F:
			_toggle_focus_view()
		elif event.keycode == KEY_R and get_tree().paused:
			_pause_restart()
		elif event.keycode == KEY_E and get_tree().paused:
			_end_run()
		elif event.keycode == KEY_T and get_tree().paused:
			_leave(false)
		elif event.keycode == KEY_X and get_tree().paused and OS.has_feature("pc"):
			_leave(true)
		elif event.keycode in [KEY_1, KEY_2, KEY_KP_1, KEY_KP_2] and phase == Phase.WAVE and not skill_ids.is_empty():
			_arm_skill(event.keycode - (KEY_KP_1 if event.keycode >= KEY_KP_1 else KEY_1))
		elif event.keycode == KEY_ESCAPE and skill_arm != "":
			skill_arm = ""
		elif event.keycode == KEY_H:
			help_label.visible = not help_label.visible
		elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4] and phase == Phase.CHOOSE and help_label.visible == false and not get_tree().paused:
			var i: int = event.keycode - (KEY_KP_1 if event.keycode >= KEY_KP_1 else KEY_1)
			if perk_mode:
				if i < perk_offer.size():
					_on_perk(perk_offer[i])
			elif i < offer.size():
				_on_pick(offer[i])
		elif event.keycode == KEY_Q and phase == Phase.CHOOSE:
			_on_reroll()
		elif event.keycode == KEY_S and not event.ctrl_pressed and not event.meta_pressed and not title_label.visible:
			if skip_left > 0:
				_toggle_skip_stop()
			elif phase in [Phase.CHOOSE, Phase.READY]:
				_on_skip()
		elif event.keycode == KEY_V and phase == Phase.CHOOSE:
			_toggle_cards_hidden()
		elif event.keycode == KEY_Z and phase == Phase.CHOOSE and not perk_mode:
			_set_card_detail(not Meta.card_detail)
		elif event.keycode == KEY_D and phase in [Phase.CHOOSE, Phase.READY, Phase.WAVE]:
			_toggle_dps()
		elif event.keycode == KEY_A and (event.ctrl_pressed or event.meta_pressed) and phase in [Phase.CHOOSE, Phase.READY] and not perk_mode:
			# 모두 선택: 한꺼번에 옮길 때
			selected = _my_towers()
			_restore_hint()
		elif event.keycode == KEY_R and phase == Phase.GAMEOVER:
			if Time.get_ticks_msec() - over_ms > 800:
				title_seen = false
				_reload()
		elif event.keycode == KEY_M:
			_toggle_mute()
		elif event.keycode == KEY_SPACE and phase == Phase.READY:
			_start_wave()
		elif event.keycode == KEY_SPACE and phase == Phase.WAVE:
			_toggle_speed()
		elif event.keycode == KEY_SPACE and phase == Phase.CHOOSE:
			_show_toast(("특성을" if perk_mode else "선택지를") + " 먼저 고르세요 (1·2·3 또는 클릭)")
		elif event.keycode == KEY_ESCAPE and not get_tree().paused and (phase in [Phase.PLACE, Phase.AIM, Phase.MOVE] or press_t or boxing or (not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY])):
			_cancel_step()
		elif event.keycode == KEY_ESCAPE and not get_tree().paused and card_dock.side.visible:
			card_dock.close_inspector()
			_restore_hint()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			_toggle_pause()
	if get_tree().paused:
		return
	if event is InputEventMouseButton and not card_dock.input_blocked() and card_dock.over_ui(event.position):
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drop_press()
			boxing = false
			aim_hold = false
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and aim_right:
		aim_right = false
		if phase == Phase.AIM:
			if _pointer_world().distance_to(place_pos) > 30.0:
				_confirm_aim()
			else:
				_cancel_step()  # 거의 안 끌고 뗀 우클릭: 그대로 둔다
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if press_t:
			_release_press()
			return
		if boxing:
			_finish_box()
			return
		if phase == Phase.AIM and touch_ui and aim_hold:
			_aim_release()
			return
		# 누른 채 끌어서 놓으면 그 방향으로 바로 확정
		if phase == Phase.AIM and _pointer_world().distance_to(place_pos) > 40.0 and Time.get_ticks_msec() - aim_start_ms > 150:
			_confirm_aim()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	# 휠은 클릭이 아니다: 도감·패치노트는 끝까지 굴린 뒤의 휠이 여기로 넘어와 창이 닫혔다
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and (press_t or boxing or (not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY])):
		_cancel_step()
		return
	# 오브젝트를 우클릭한 채 끌기: 그 자리에서 방향만 바꾸고, 떼면 확정
	if event.button_index == MOUSE_BUTTON_RIGHT and phase in [Phase.CHOOSE, Phase.READY] and not perk_mode and not title_label.visible \
			and not (settings_panel.visible or notes_panel.visible or codex_panel.visible or vote_panel.visible or records_panel.visible or help_label.visible):
		var rt := _tower_at(_pointer_world())
		if rt and _mine(rt):
			_start_move(rt)
			aim_right = phase == Phase.AIM
			return
	if notes_panel.visible:
		_close_notes()
		return
	if codex_panel.visible:
		codex_panel.visible = false
		return
	if vote_panel.visible:
		vote_panel.hide_panel()
		return
	if records_panel.visible:
		records_panel.visible = false
		return
	if help_label.visible:
		help_label.visible = false
		return
	if title_label.visible or settings_panel.visible:
		return
	if phase == Phase.GAMEOVER and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() - over_ms > 800:
			title_seen = false
			_reload()
		return
	if card_dock != null and card_dock.over_ui(event.position):
		return
	var mpos := _pointer_world()
	if event.button_index == MOUSE_BUTTON_LEFT and phase in [Phase.CHOOSE, Phase.READY, Phase.WAVE] and _tower_at(mpos) == null:
		card_dock.inspected_tower = null
		tip_tower = null
		if not (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)):
			selected.clear()
	if perk_mode:
		return
	if phase == Phase.WAVE and skill_arm != "":
		if event.button_index == MOUSE_BUTTON_LEFT:
			_use_skill(skill_arm, mpos)
		else:
			skill_arm = ""
		return
	if phase == Phase.WAVE and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tower_at(mpos)
		if t:
			_select_tower(t)
		return
	if phase in [Phase.CHOOSE, Phase.READY] and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tower_at(mpos)
		if t:
			# 짧게 클릭: 선택, Shift/Ctrl+클릭: 선택에 더하기·빼기, 끌기: 바로 이동
			_begin_press(t, mpos)
		else:
			# 빈 곳을 끌면 선택 상자
			boxing = true
			box_start = mpos
		return
	if phase == Phase.MOVE:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mpos = mpos.clamp(field_rect().position, field_rect().end)
			if mpos.distance_to(core()) < 50.0:
				_show_toast("중앙 점에 너무 가까워요")
				return
			var other := _tower_at(mpos, moving)
			if other:
				_show_toast("다른 오브젝트와 겹칠 수 없어요")
				return
			place_pos = mpos
			moving.position = mpos
			phase = Phase.AIM
			aim_start_ms = Time.get_ticks_msec()
			_aim_begin()
			hint.text = _th("클릭 또는 끌어서 놓기: 방향 확정 (Shift: 15도 단위) (색칠된 곳이 공격 범위)\n우클릭/Esc: 옮기기 취소")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_step()
		return
	if phase == Phase.PLACE and event.button_index == MOUSE_BUTTON_LEFT:
		_place_card_at(mpos)
	elif phase == Phase.AIM:
		if event.button_index == MOUSE_BUTTON_LEFT and touch_ui:
			aim_hold = true  # 터치: 누르는 동안 손가락을 따라 범위를 보여 주고, 떼면 [확정]을 기다린다
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# 오브젝트 바로 위를 누르면 손을 뗄 때 정한다 (그 자리에서 바깥으로 끌어 조준)
			if mpos.distance_to(place_pos) >= MERGE_DIST:
				_confirm_aim()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not aim_right:
			_cancel_step()
	elif phase == Phase.PLACE and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_step()


## 드롭은 손을 뗀 화면 좌표로 판정한다. 패널·창 밖·무효 대상에서는 카드를 소비하지 않는다.
func _drop_carried_card(screen: Vector2) -> void:
	if phase != Phase.PLACE or picked.is_empty() or not get_viewport_rect().has_point(screen) or card_dock.input_blocked() or card_dock.over_ui(screen):
		return
	var world := get_canvas_transform().affine_inverse() * screen
	_place_card_at(world, true)


func _place_card_at(mpos: Vector2, direct := false) -> void:
	var target := _tower_at(mpos)
	if TutPlay.on and tplay != null and not tplay.allow_place(target):
		return
	if target and not _place_ok(target):
		# 넣을 수 없는 오브젝트는 흐리게 그리고 누르거나 끌 수 없다 (이유만 알림)
		_show_toast(_place_refuse(target))
		return
	if target:
		# 클릭은 손을 뗄 때 처리한다. 꾹 누르거나 끌면 카드를 유지한 채 옮긴다.
		if direct:
			_place_on(target)
		else:
			_begin_press(target, mpos)
		return
	if not field_rect().has_point(mpos):
		_show_toast("전장 안에 놓으세요")
		return
	if mpos.distance_to(core()) < 50.0:
		_show_toast("중앙 점에 너무 가까워요")
		return
	if picked["type"] != "elem":
		_apply_card(target)
		return
	elif picked["e"] == Elem.STAR and star_full():
		_show_toast(Tower.star_full_text())
		return
	else:
		place_pos = mpos
		phase = Phase.AIM
		aim_start_ms = Time.get_ticks_msec()
		_aim_begin()
		aim_hold = touch_ui and not direct  # 놓은 손가락 그대로 끌어 방향을 볼 수 있다
		if touch_ui:
			hint.text = _th(AIM_TOUCH_HINT + "   취소: 위치 다시 정하기")
		else:
			hint.text = _th("클릭 또는 끌어서 놓기: 발사 방향 확정 (Shift: 15도 단위) (색칠된 곳이 공격 범위)\n우클릭/Esc: 위치 다시 정하기")

## 카드 선택 막을 깔지: 선택지 카드가 펼쳐져 있을 때만 (일시정지 어둠이 있으면 그것만).
func _card_dim_on() -> bool:
	if card_dock != null and card_dock.active():
		return false
	return phase == Phase.CHOOSE and choice_box.visible and not cards_hidden and choice_box.get_child_count() > 0 \
		and not title_label.visible and not get_tree().paused


## 지금 고른 카드를 이 오브젝트에 넣을 수 있는지 (속성 종류·강화 종류별 상한·Pat.NO_MOD·별 상한·친구 오브젝트).
func _place_ok(t: Tower) -> bool:
	if picked.is_empty() or not is_instance_valid(t):
		return false
	return (_mine(t) or _req_ok(t)) and t.can_take(picked)


## 넣을 수 없는 이유 (_place_ok가 false일 때).
func _place_refuse(t: Tower) -> String:
	if not _mine(t) and not _req_ok(t):
		return "친구가 놓은 오브젝트에는 넣을 수 없어요" + (" (요청한 속성 %s만)" % Elem.NAMES[t.req_e] if t.req_e >= 0 else "")
	return t.refuse_text(picked)


## 카드를 놓는 중(PLACE): 넣을 수 없는 오브젝트는 흐리게. 다른 단계에서는 원래대로.
func _update_place_dim() -> void:
	var on := phase == Phase.PLACE and not picked.is_empty()
	for t in towers.get_children():
		var c := Color.WHITE
		if on and not _place_ok(t):
			c = PLACE_OFF
		if t.modulate != c:
			t.modulate = c


## 고른 카드를 오브젝트에 넣는다 (PLACE에서 오브젝트를 짧게 클릭).
func _place_on(target: Tower) -> void:
	if not _mine(target):
		if _req_ok(target) and target.can_take(picked):
			_mp_give(target)  # 협동: 친구가 요청한 속성
		else:
			_show_toast(_place_refuse(target))
		return
	if picked["type"] != "elem":
		_apply_card(target)
		return
	if not target.can_take(picked):
		_show_toast(target.refuse_text(picked))
		return
	var fresh := Elem.new_reactions(target.eff_now(), picked["e"])
	var msg: String = target.add(picked["e"], picked["lv"])
	sfx.play("place")
	if msg.begins_with("조합"):
		# 긴 배너·토스트 글 대신 오브젝트 옆 그림 카드 (2026-11-05)
		sfx.play("reaction", 0.0)
		rx_card.show_for(target, fresh)
		burst(target.position, Color(1, 0.85, 0.4), 30, 260.0)
	else:
		_show_toast(msg)
	_after_place()


func _begin_press(t: Tower, mpos: Vector2) -> void:
	if mp_req_mode and phase in [Phase.CHOOSE, Phase.READY]:
		if _mine(t):
			_mp_req_open(t)
		else:
			_show_toast("내 오브젝트를 누르세요")
		return
	if not _mine(t):
		if phase == Phase.PLACE and _req_ok(t):
			_place_on(t)  # 요청한 속성을 넣어 주기 (옮기지는 못함)
			return
		if phase in [Phase.CHOOSE, Phase.READY]:
			_select_tower(t)
		else:
			_show_toast("친구가 놓은 오브젝트는 바꿀 수 없어요")
		return
	press_t = t
	press_pos = mpos
	press_ms = Time.get_ticks_msec()
	dragging = false


## 누른 오브젝트: 꾹 누르거나(0.35초) 끌면 옮기기 시작한다. 선택된 것을 끌면 선택 전부가 함께.
func _update_press() -> void:
	if not press_t:
		return
	if card_dock.input_blocked() or not phase in [Phase.PLACE, Phase.CHOOSE, Phase.READY] or not is_instance_valid(press_t) or not _mine(press_t):
		_drop_press()
		return
	var mpos := _pointer_world()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_press()
		return
	if not dragging and (mpos.distance_to(press_pos) > 12.0 or Time.get_ticks_msec() - press_ms >= 350):
		dragging = true
		drag_group = selected.filter(func(t): return is_instance_valid(t) and _mine(t)) if press_t in selected else [press_t]
		drag_origs = drag_group.map(func(t): return t.position)
		for t in drag_group:
			t.place_pop = 1.0
		hint.text = _th("끌어서 옮기는 중%s: 놓으면 그 자리에 둠 (방향은 그대로)\n우클릭/Esc: 취소" % (" (%d개)" % drag_group.size() if drag_group.size() > 1 else ""))
	if dragging:
		# 창 밖으로 끌어도 무리 전체가 화면 안에 남도록 이동량을 자른다
		var delta := mpos - press_pos
		var f := field_rect()
		for i in drag_group.size():
			if is_instance_valid(drag_group[i]):
				var q: Vector2 = drag_origs[i] + delta
				delta += q.clamp(f.position, f.end) - q
		for i in drag_group.size():
			if is_instance_valid(drag_group[i]):
				drag_group[i].position = drag_origs[i] + delta
				drag_group[i].queue_redraw()


## 누른 오브젝트에서 손을 뗐을 때: 끌었으면 그 자리에 두고, 짧은 클릭이면 원래 클릭 동작.
func _release_press() -> void:
	if card_dock.input_blocked() or card_dock.over_ui(_pointer_screen()):
		_drop_press()
		_restore_hint()
		return
	var t := press_t
	press_t = null
	if not is_instance_valid(t) or not phase in [Phase.PLACE, Phase.CHOOSE, Phase.READY]:
		_drop_press()
		return
	if not dragging:
		if phase == Phase.PLACE:
			_place_on(t)
		elif Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
			if t in selected:
				selected.erase(t)
			else:
				selected.append(t)
			_restore_hint()
		elif phase in [Phase.CHOOSE, Phase.READY] and selected == [t] and card_dock.inspected_tower == t:
			_edit_selected_direction()  # 이미 선택해 상세가 열린 오브젝트를 한 번 더 누르면 바로 방향 바꾸기
		else:
			_select_tower(t)
		return
	dragging = false
	# 놓을 수 없는 자리가 하나라도 있으면 모두 원래 자리로
	var bad := ""
	for o in drag_group:
		if is_instance_valid(o) and bad == "":
			bad = _bad_spot(o, drag_group)
	if bad != "":
		_show_toast(bad)
		_revert_drag()
	elif drag_group[0].position.distance_to(drag_origs[0]) > 4.0:
		sfx.play("place")
	for o in drag_group:
		if is_instance_valid(o):
			o.place_pop = 1.0
			o.queue_redraw()
	if bad == "" and phase in [Phase.CHOOSE, Phase.READY]:
		if drag_group.size() == 1:
			_select_tower(t)
		else:
			selected = drag_group.duplicate()
	drag_group.clear()
	_restore_hint()
	_save_run()


## 옮기는 자리에 놓을 수 없으면 그 이유 (movers: 함께 움직이는 것들끼리는 겹쳐도 됨).
func _bad_spot(o: Tower, movers: Array) -> String:
	if o.position.distance_to(core()) < 50.0:
		return "중앙 점에 너무 가까워요"
	for other in towers.get_children():
		if not other in movers and other.position.distance_to(o.position) < MERGE_DIST:
			return "다른 오브젝트와 겹칠 수 없어요"
	return ""


func _revert_drag() -> void:
	for i in drag_group.size():
		if is_instance_valid(drag_group[i]):
			drag_group[i].position = drag_origs[i]
			drag_group[i].queue_redraw()


func _drop_press() -> void:
	if dragging:
		_revert_drag()
	press_t = null
	dragging = false
	drag_group.clear()


## 선택 상자를 놓았을 때: 상자 안 오브젝트 선택 (Shift/Ctrl: 기존 선택에 더함). 짧은 클릭이면 선택 해제.
func _finish_box() -> void:
	boxing = false
	if card_dock.input_blocked() or card_dock.over_ui(_pointer_screen()):
		_restore_hint()
		return
	var r := Rect2(box_start, _pointer_world() - box_start).abs()
	var add := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if not add:
		selected.clear()
	if r.size.length() > 8.0:
		for t in towers.get_children():
			if r.grow(Tower.RADIUS * 0.5).has_point(t.position) and not t in selected and _mine(t):
				selected.append(t)
	_restore_hint()


func _select_tower(t: Tower) -> void:
	selected = [t] if _mine(t) else []
	card_dock.dismissed_tower = null
	card_dock.hovered = null
	card_dock.inspected_tower = t
	tip_tower = t
	_restore_hint()


func _edit_selected_direction() -> void:
	if phase in [Phase.CHOOSE, Phase.READY] and not card_dock.input_blocked() and selected.size() == 1 and is_instance_valid(selected[0]) and _mine(selected[0]):
		_start_move(selected[0])


## 단계에 맞는 안내 문구로 되돌린다 (선택 중이면 선택 안내).
func _restore_hint() -> void:
	selected = selected.filter(func(t): return is_instance_valid(t))
	match phase:
		Phase.PLACE:
			hint.text = _th(_place_hint())
		Phase.CHOOSE:
			hint.text = _th(_choose_hint())
		Phase.READY:
			hint.text = _th(READY_HINT if Meta.games < 3 else "")
	if not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY, Phase.PLACE]:
		hint.text = ("선택 %d개: 선택한 오브젝트 하나를 끌면 함께 이동\n빈 곳 누르기: 선택 해제" if touch_ui else "선택 %d개: 선택한 오브젝트 하나를 끌면 함께 이동\nShift/Ctrl+클릭: 더하기·빼기   Ctrl+A: 모두   Esc/우클릭: 선택 해제") % selected.size()


## 조준 단계에 들어갈 때: 터치는 지금 방향(옮기는 오브젝트)을 붙잡아 두고 시작한다.
func _aim_begin() -> void:
	aim_hold = false
	aim_d = moving.dir.normalized() if moving else Vector2.ZERO
	aim_wait = aim_d != Vector2.ZERO


## 아래 [확정] 버튼: 터치 조준에서 방향을 붙잡아 뒀을 때.
func _ok_btn_on() -> bool:
	return phase == Phase.AIM and touch_ui and aim_wait


## 터치 조준에서 손가락을 뗄 때: 끌었던 방향을 붙잡아 두고 [확정]을 기다린다.
## 오브젝트를 짧게 다시 누르면(끌지 않고 떼면) 붙잡아 둔 방향으로 확정.
func _aim_release() -> void:
	aim_hold = false
	var d := _pointer_world() - place_pos
	if d.length() >= AIM_TOUCH_MIN:
		aim_d = d.normalized()
		aim_wait = true
	elif aim_wait and d.length() < MERGE_DIST:
		_confirm_aim()


## 방향 확정 (클릭, 또는 끌었다 놓기, 터치 [확정]).
func _confirm_aim() -> void:
	var d := _aim_dir(place_pos)
	if d == Vector2.ZERO:
		return
	if moving:
		if tplay != null:
			tplay.flags["aimed"] = true  # 튜토리얼 '보스 길 쪽으로 돌리기': 이미 그쪽이라 거의 안 돌아도 한 번 정하면 된다
		moving.position = place_pos
		moving.set_attack_direction(d)
		moving.place_pop = 1.0
		sfx.play("place")
		moving.queue_redraw()
		moving = null
		_end_move()
		return
	_place_tower(place_pos, d)

	sfx.play("place")
	_after_place()


## 메인 메뉴: 맵·스킨 선택, 시작, 기록·업적, 설정, 도움말.
func _build_menu(root: Control) -> void:
	title_label = Control.new()
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.visible = false
	root.add_child(title_label)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-330, -300)
	box.size = Vector2(660, 600)
	# 줄이 늘면(회랑 설명·규칙·모드·이어하기·새 버전 알림) 위아래로 같이 자라고, 화면보다 크면 _fit_panels가 줄인다
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	title_label.add_child(box)
	title_box = box
	var logo := Label.new()
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 72)
	logo.text = "빈두"
	box.add_child(logo)
	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 19)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	desc.text = "밖에서 몰려오는 구체를 막아 중앙 점을 지키세요\n공격방식·속성·강화·연계를 조합해 오브젝트를 키우세요"
	desc.visible = not _phone()  # 폰: 줄을 줄여야 시작 화면을 덜 줄여서 버튼이 손가락 크기로 남는다
	box.add_child(desc)
	# [일반 판]을 누르면 나오는 준비 화면 (맵·오는 쪽·규칙·모드 + 시작)
	prep_title = Label.new()
	prep_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prep_title.add_theme_font_size_override("font_size", 38)
	prep_title.text = "일반 판"
	prep_title.visible = false
	box.add_child(prep_title)
	prep_box = VBoxContainer.new()
	prep_box.add_theme_constant_override("separation", 10)
	prep_box.visible = false
	box.add_child(prep_box)
	home_box = VBoxContainer.new()
	home_box.add_theme_constant_override("separation", 10)
	box.add_child(home_box)
	map_label = _build_map_cards(prep_box)
	flip_label = _prep_row(prep_box, "오는 쪽", _toggle_flip, _toggle_flip)
	rules_label = _prep_row(prep_box, "규칙", func(): _cycle_rules(-1), func(): _cycle_rules(1))
	skill_label = _prep_row(prep_box, "중앙 기술", func(): _cycle_skill(-1), func(): _cycle_skill(1))
	# 모드: 여러 개를 켜고 끄는 창이라 화살표 대신 줄 전체가 [모드] 창을 연다
	modes_btn = Button.new()
	modes_btn.custom_minimum_size = Vector2(PREP_W, 64 if _phone() else 56)
	modes_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modes_btn.focus_mode = Control.FOCUS_NONE
	modes_btn.pressed.connect(_toggle_modes)
	for st in ["normal", "hover", "pressed"]:
		modes_btn.add_theme_stylebox_override(st, _prep_sb(st != "normal"))
	var mh := HBoxContainer.new()
	mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mh.add_theme_constant_override("separation", 12)
	modes_btn.add_child(mh)
	mh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	mh.offset_left = 14.0
	mh.offset_right = -10.0
	var mn := _prep_name("모드 (시험)")
	mh.add_child(mn)
	var mv := VBoxContainer.new()
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(mv)
	modes_label = _prep_main()
	mv.add_child(modes_label)
	var msub := _prep_sub()
	mv.add_child(msub)
	modes_label.set_meta("sub", msub)
	var marrow := Label.new()
	marrow.text = "바꾸기 ▶"
	marrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marrow.custom_minimum_size = Vector2(90, 0)
	marrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	mh.add_child(marrow)
	prep_box.add_child(modes_btn)
	new_btn = Button.new()
	new_btn.custom_minimum_size = Vector2(PREP_W, 72 if _phone() else 64)
	new_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_btn.focus_mode = Control.FOCUS_NONE
	new_btn.add_theme_font_size_override("font_size", 24)
	for st in ["normal", "hover", "pressed"]:
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(0.15, 0.22, 0.13) if st == "normal" else Color(0.2, 0.3, 0.17)
		gsb.set_border_width_all(2)
		gsb.border_color = Color(0.56, 0.82, 0.44)
		gsb.set_corner_radius_all(10)
		new_btn.add_theme_stylebox_override(st, gsb)
	new_btn.pressed.connect(_close_title)
	prep_box.add_child(new_btn)
	_icon_btn(new_btn, func(): return ["play", Color(1, 0.9, 0.6)])
	_keycap(new_btn, "Enter")
	# 맵 카드와 규칙·기술·모드·시작 묶음: 화면이 넓으면 두 칸(_prep_layout), 좁으면 위아래.
	# 한 줄로 쌓으면 화면 높이를 넘어 준비 화면 전체가 줄었다 (PC 0.87배·폰 0.69배, 설명 글 9~11px)
	prep_cols = GridContainer.new()
	prep_cols.add_theme_constant_override("h_separation", 12)
	prep_cols.add_theme_constant_override("v_separation", 10)
	prep_right = VBoxContainer.new()
	prep_right.add_theme_constant_override("separation", 10)
	prep_right.alignment = BoxContainer.ALIGNMENT_CENTER
	var kids := prep_box.get_children()
	for k: Control in kids:
		prep_box.remove_child(k)
	prep_cols.add_child(kids[0])
	for k: Control in kids.slice(1):
		prep_right.add_child(k)
	prep_cols.add_child(prep_right)
	prep_box.add_child(prep_cols)
	_prep_layout()
	prep_back = Button.new()
	prep_back.text = "◀ 뒤로 (Esc)"
	prep_back.add_to_group("key_hint")
	prep_back.custom_minimum_size = Vector2(150, 56 if _phone() else 42)
	prep_back.position = Vector2(20, 20)
	prep_back.focus_mode = Control.FOCUS_NONE
	prep_back.add_theme_font_size_override("font_size", 18)
	prep_back.pressed.connect(func(): _set_prep(false))
	prep_back.visible = false
	title_label.add_child(prep_back)
	# 첫 화면: 큰 타일 (일반 판 · 멀티플레이)
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 16)
	home_box.add_child(tiles)
	var normal_tile := Button.new()
	normal_tile.pressed.connect(func(): _set_prep(true))
	normal_info = _tile(normal_tile, "일반 판", Color(0.55, 0.78, 1.0), func(): return "" if continue_btn.visible else "Enter")
	tiles.add_child(normal_tile)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	home_box.add_child(row)
	# 그림 + 짧은 이름 (단축키는 모서리 작은 키, 긴 이름은 말풍선)
	var specs := [["기록", _toggle_records, "records", "", "기록·업적"], ["도감", _toggle_codex, "book", "K", "도감 (K)"], ["설정", _toggle_settings, "gear", "O", "설정 (O)"], ["튜토리얼", _open_tut_list, "help", "H", "튜토리얼 (H)"]]
	if OnlineConfig.SERVER_URL != "":
		specs.insert(2, ["순위", _toggle_board, "rank", "", "리더보드"])
		specs.insert(4, ["투표", _toggle_vote, "vote", "V", "다음 패치 투표 (V)"])
	# 게임 끄기: PC만 (iOS·Android는 앱이 스스로 끄지 않는다)
	if OS.has_feature("pc"):
		specs.append(["종료", func(): get_tree().quit(), "power", "", "게임 종료"])
	for spec in specs:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
		b.custom_minimum_size = Vector2(78, 64 if _phone() else 54)
		b.tooltip_text = spec[4]
		if spec[2] == "vote":
			vote_btn = b
			b.visible = Net.vote_ok()
		_menu_glyph(b, spec[2], spec[0])
		_keycap(b, spec[3])
	# 이어하기: 저장된 판이 있을 때만 (쉬는 시간마다 자동 저장)
	# 아래 타일과 같은 카드 모양(호박색 테두리·이름·설명 줄), 폭은 타일 줄과 같게 (_refresh_continue)
	continue_btn = Button.new()
	continue_info = _tile(continue_btn, "이어하기", CONT_COL, "Enter")
	continue_btn.custom_minimum_size.y = 104 if _phone() else 92
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed"]:
		var csb: StyleBoxFlat = continue_btn.get_theme_stylebox(st).duplicate()
		csb.bg_color = Color(0.13, 0.11, 0.07) if st == "normal" else Color(0.18, 0.15, 0.09)
		csb.border_color = Color(CONT_COL, 0.8 if st == "normal" else 1.0)
		continue_btn.add_theme_stylebox_override(st, csb)
	continue_info.add_theme_font_size_override("font_size", 17)
	continue_info.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 0.85))
	continue_btn.pressed.connect(_continue_run)
	continue_btn.visible = false
	home_box.add_child(continue_btn)
	home_box.move_child(continue_btn, 0)
	remote_btn = Button.new()
	remote_btn.custom_minimum_size = Vector2(630, 56 if _phone() else 44)
	remote_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	remote_btn.focus_mode = Control.FOCUS_NONE
	remote_btn.add_theme_font_size_override("font_size", 17)
	remote_btn.pressed.connect(_claim_remote_run)
	remote_btn.visible = false
	home_box.add_child(remote_btn)
	home_box.move_child(remote_btn, 1)
	# 멀티플레이: 중개 서버 주소가 있고 WebRTC 확장이 읽힌 기기에서만
	mp_btn = Button.new()
	_tile(mp_btn, "멀티플레이", Color(0.8, 0.62, 1.0), "").text = "친구와 대결 · 협동\n방 만들기 · 코드로 참가"
	mp_btn.pressed.connect(_toggle_mp_lobby)
	# Windows는 exe 안 dll을 풀어 읽어서 실패할 수 있다: 버튼은 두고 방을 만들 때 까닭을 보여 준다
	mp_btn.visible = _mp_btn_shown()
	tiles.add_child(mp_btn)
	_build_mp_lobby(root)
	# 온라인: 새 버전 알림, 패치 공지 (서버에서 받았을 때만 보임)
	update_btn = Button.new()
	update_btn.custom_minimum_size = Vector2(630, 56 if _phone() else 40)
	update_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	update_btn.focus_mode = Control.FOCUS_NONE
	update_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	update_btn.visible = false
	home_box.add_child(update_btn)
	notes_btn = Button.new()
	notes_btn.custom_minimum_size = Vector2(320, 52 if _phone() else 36)
	_icon_btn(notes_btn, func(): return ["notes", Color(1, 1, 1, 0.8)])
	notes_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	notes_btn.focus_mode = Control.FOCUS_NONE
	notes_btn.pressed.connect(_toggle_notes)
	home_box.add_child(notes_btn)
	home_box.move_child(notes_btn, update_btn.get_index())
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.custom_minimum_size = Vector2(630, 0)
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	notice_label.visible = false
	home_box.add_child(notice_label)

	records_panel = Label.new()
	records_panel.z_index = 22  # 일시정지 어둠(z 20) 위에
	records_panel.set_anchors_preset(Control.PRESET_CENTER)
	# 내용이 늘면 위아래로 같이 자라게 (아래로만 자라면 오른쪽 아래 소리 버튼을 덮음)
	records_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	records_panel.offset_left = -430.0
	records_panel.offset_right = 430.0
	records_panel.offset_top = -325.0
	records_panel.offset_bottom = 285.0
	records_panel.add_theme_font_size_override("font_size", 15)
	records_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	rsb.set_border_width_all(1)
	rsb.border_color = Color(1, 1, 1, 0.25)
	rsb.set_content_margin_all(18)
	rsb.set_corner_radius_all(6)
	records_panel.add_theme_stylebox_override("normal", rsb)
	records_panel.visible = false
	root.add_child(records_panel)
	_build_board()
	board_ugc_panel = PanelContainer.new()
	var usb: StyleBoxFlat = rsb.duplicate()
	usb.bg_color = Color(0.08, 0.09, 0.13, 1.0)
	usb.border_color = Color(1, 1, 1, 0.45)
	board_ugc_panel.add_theme_stylebox_override("panel", usb)
	board_ugc_panel.set_anchors_preset(Control.PRESET_CENTER)
	board_ugc_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	board_ugc_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	board_ugc_panel.visible = false
	records_panel.add_child(board_ugc_panel)
	_build_notes(root)
	_build_modes(root, rsb)
	codex_panel = Codex.new()
	codex_panel.z_index = 22  # 일시정지 어둠(z 20) 위에
	codex_panel.setup(PERKS, rsb.duplicate(), _save_best)
	root.add_child(codex_panel)
	vote_panel = Vote.new()
	vote_panel.z_index = 22
	vote_panel.setup(PERKS, rsb.duplicate(), net)
	root.add_child(vote_panel)
	tut = Tutorial.new()
	tut.z_index = 23  # 일시정지 어둠(20)·다른 창(22) 위에
	tut.setup(rsb.duplicate(), func(): help_label.visible = true)
	tut.closed.connect(_on_tut_closed)
	tut.play_requested.connect(_play_tutorial)
	root.add_child(tut)

	settings_panel = PanelContainer.new()
	settings_panel.z_index = 22  # 일시정지 어둠(z 20) 위에
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	# 폰: 켜기·끄기 줄을 두 칸으로 나누고 줄을 손가락 크기로 (한 칸이면 창이 화면보다 길어져 줄어들고 줄이 3mm 남짓이었다)
	var sw := 920.0 if _phone() else 480.0
	settings_panel.position = Vector2(-sw / 2.0, 0)
	settings_panel.size = Vector2(sw, 0)
	settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH  # 내용 높이에 맞춰 위아래로 자라 가운데에 (온라인 줄이 생기면 아래가 잘리던 것)
	settings_panel.add_theme_stylebox_override("panel", rsb.duplicate())
	settings_panel.visible = false
	root.add_child(settings_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	settings_panel.add_child(sv)
	var st := Label.new()
	st.text = "설정 (O / Esc: 닫기)"
	st.add_to_group("key_hint")
	st.add_theme_font_size_override("font_size", 22)
	sv.add_child(st)
	var vrow := HBoxContainer.new()
	var vl := Label.new()
	vl.text = "음량 %d%%" % roundi(Meta.volume * 100.0)
	vl.custom_minimum_size = Vector2(120, 0)
	vrow.add_child(vl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Meta.volume
	slider.custom_minimum_size = Vector2(240, 30)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v):
		Meta.volume = v
		vl.text = "음량 %d%%" % roundi(v * 100.0)
		_apply_volume()
		_save_best())
	vrow.add_child(slider)
	sv.add_child(vrow)
	var zrow := HBoxContainer.new()
	zrow.add_theme_constant_override("separation", 6)
	var zl := Label.new()
	zl.text = "글자·버튼 크기"
	zl.custom_minimum_size = Vector2(120, 0)
	zrow.add_child(zl)
	var zg := ButtonGroup.new()
	for v in Meta.UI_SCALES:
		var zb := Button.new()
		zb.text = "%d%%" % roundi(v * 100.0)
		zb.toggle_mode = true
		zb.button_group = zg
		zb.button_pressed = is_equal_approx(v, Meta.ui_scale)
		zb.custom_minimum_size = Vector2(72, 30)
		zb.focus_mode = Control.FOCUS_NONE
		zb.pressed.connect(func():
			Meta.ui_scale = v
			_apply_ui_scale()
			_save_best())
		zrow.add_child(zb)
	sv.add_child(zrow)
	# 오브젝트·중앙 모양 (예전엔 시작 화면에 있었다)
	skin_label = _menu_row(sv, func(): _cycle_skin("tower", -1), func(): _cycle_skin("tower", 1), sw - 160.0)
	core_label = _menu_row(sv, func(): _cycle_skin("core", -1), func(): _cycle_skin("core", 1), sw - 160.0)
	var cbox: Container = sv
	if _phone():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 4)
		sv.add_child(grid)
		cbox = grid
	for spec in [["화면 흔들림", "shake_on"], ["피해 숫자", "numbers_on"], ["속성 기호 표시 (색 위에 속성 그림)", "symbols_on"], ["모든 구체에 체력 숫자 (끄면 고리만)", "orb_hp_on"], ["중앙이 위험하면 1배속으로 (체력 50%·25%)", "danger_slow"], ["웨이브 넘기기 중 중앙이 위험하면 멈춤 (체력 50%)", "skip_danger"], ["중앙 기술 자동 사용 (구체가 몰린 곳에)", "skill_auto"], ["효과 줄이기 (장판·터지는 효과를 옅게, 많을수록 더)", "fx_low"], ["피해 1~3위 왕관·메달", "rank_on"]]:
		var cb := CheckButton.new()
		cb.text = spec[0]
		var key: String = spec[1]
		match key:
			"shake_on": cb.button_pressed = Meta.shake_on
			"numbers_on": cb.button_pressed = Meta.numbers_on
			"symbols_on": cb.button_pressed = Meta.symbols_on
			"orb_hp_on": cb.button_pressed = Meta.orb_hp_on
			"danger_slow": cb.button_pressed = Meta.danger_slow
			"skip_danger": cb.button_pressed = Meta.skip_danger
			"skill_auto": cb.button_pressed = Meta.skill_auto
			"fx_low": cb.button_pressed = Meta.fx_low
			"rank_on": cb.button_pressed = Meta.rank_on
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			match key:
				"shake_on": Meta.shake_on = on
				"numbers_on": Meta.numbers_on = on
				"orb_hp_on": Meta.orb_hp_on = on
				"danger_slow": Meta.danger_slow = on
				"skip_danger": Meta.skip_danger = on
				"skill_auto": Meta.skill_auto = on
				"fx_low": Meta.fx_low = on
				"rank_on":
					Meta.rank_on = on
					_rank_update()
				"symbols_on":
					Meta.symbols_on = on
					for t in towers.get_children():
						t.queue_redraw()
			_save_best())
		cbox.add_child(cb)
	var gc := CheckButton.new()
	gc.text = "처음 안내 보기 (처음 생기는 일에 한 줄 설명)"
	gc.button_pressed = Meta.guide_on
	gc.focus_mode = Control.FOCUS_NONE
	gc.toggled.connect(func(on):
		Meta.guide_on = on
		if not on:
			guide_lines.clear()
		_save_best())
	cbox.add_child(gc)
	var gr := Button.new()
	gr.text = "안내 처음부터 다시 보기"
	gr.tooltip_text = "본 안내를 지우고, 다음 새 판은 첫 판처럼 카드 종류를 웨이브마다 하나씩 엽니다"
	gr.focus_mode = Control.FOCUS_NONE
	gr.pressed.connect(func():
		Meta.guide_seen = {}
		Tutorial.seen = {}  # 직접 열어 본 항목 기록만 초기화. 첫 소개 완료(done)는 보존
		Tutorial.save_file()
		Meta.guide_on = true
		Meta.tutor_next = true
		gc.set_pressed_no_signal(true)
		_save_best()
		_show_toast("다음 새 판부터 안내를 처음부터 보여 줘요"))
	sv.add_child(gr)
	if OnlineConfig.SERVER_URL != "":
		var oc := CheckButton.new()
		oc.text = "기록 보내기 (리더보드·사용 통계, 익명)"
		oc.button_pressed = Meta.online_on
		oc.focus_mode = Control.FOCUS_NONE
		oc.toggled.connect(func(on):
			Meta.online_on = on
			_save_best())
		cbox.add_child(oc)
		var nrow := HBoxContainer.new()
		var nl := Label.new()
		nl.text = "닉네임"
		nl.custom_minimum_size = Vector2(120, 0)
		nrow.add_child(nl)
		var ne := LineEdit.new()
		ne.max_length = 12
		ne.placeholder_text = "비우면 익명"
		ne.text = Meta.nickname
		ne.custom_minimum_size = Vector2(240, 0)
		var nbad := Label.new()  # 욕설·운영자 사칭 등 (NickFilter): 저장하지 않고 익명으로
		nbad.text = "쓸 수 없는 낱말이 있어요"
		nbad.add_theme_font_size_override("font_size", 14)
		nbad.add_theme_color_override("font_color", Color(1, 0.5, 0.45))
		nbad.visible = NickFilter.bad(Meta.nickname)
		ne.text_changed.connect(func(t):
			var bad := NickFilter.bad(t)
			nbad.visible = bad
			Meta.nickname = "" if bad else t.strip_edges()
			_save_best())
		ne.text_submitted.connect(func(_t): ne.release_focus())
		nrow.add_child(ne)
		nrow.add_child(nbad)
		sv.add_child(nrow)
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 8)
		account_label = Label.new()
		account_label.add_theme_font_size_override("font_size", 14)
		account_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		account_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		account_label.text = Account.label()
		arow.add_child(account_label)
		# 내 온라인 데이터 지우기 (App Store 5.1.1(v)): 두 번 눌러야 지운다. 서버 계정·진행·리더보드 이름과 기록을 지우고 기록 보내기를 끈다.
		var del := Button.new()
		del.text = "내 온라인 데이터 지우기"
		del.tooltip_text = "서버에 저장된 진행·리더보드 이름과 기록을 지웁니다. 이 기기의 기록·업적은 남아요"
		del.focus_mode = Control.FOCUS_NONE
		del.pressed.connect(_on_delete_data.bind(del, ne))
		arow.add_child(del)
		sv.add_child(arow)
	var nb := Button.new()
	nb.text = "패치노트 (N)"
	nb.focus_mode = Control.FOCUS_NONE
	nb.pressed.connect(_toggle_notes)
	sv.add_child(nb)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	var fs := Button.new()
	fs.text = "전체 화면 전환 (F11)"
	fs.focus_mode = Control.FOCUS_NONE
	fs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs.pressed.connect(_toggle_fullscreen)
	fs.visible = not OS.has_feature("mobile")  # 폰·태블릿은 늘 전체 화면 (누르면 창 모드로 바뀌어 위아래 막대가 생길 수 있다)
	brow.add_child(fs)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(_toggle_settings)
	brow.add_child(close)
	sv.add_child(brow)
	if _phone():
		for c: Control in settings_panel.find_children("*", "", true, false):
			if c is BaseButton or c is LineEdit or c is HSlider:
				c.custom_minimum_size.y = maxf(c.custom_minimum_size.y, 52.0)
			if c is CheckButton:
				c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phone_scroll(settings_panel)
	_refresh_menu()


## 설정의 [내 온라인 데이터 지우기]: 첫 누름은 확인 글로 바꾸고 4초 안에 한 번 더 누르면 지운다.
func _on_delete_data(b: Button, nick_edit: LineEdit) -> void:
	if not b.has_meta("armed"):
		b.set_meta("armed", true)
		b.text = "한 번 더 누르면 지워요"
		b.add_theme_color_override("font_color", Color(1, 0.55, 0.5))
		get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(b) and b.has_meta("armed") and not b.disabled:
				b.remove_meta("armed")
				b.text = "내 온라인 데이터 지우기"
				b.remove_theme_color_override("font_color"))
		return
	b.remove_meta("armed")
	b.disabled = true
	b.text = "지우는 중…"
	var code := await net.delete_account()
	if not is_instance_valid(b):
		return
	b.disabled = false
	b.text = "내 온라인 데이터 지우기"
	b.remove_theme_color_override("font_color")
	if code == 200:
		Meta.online_on = false  # 바로 새 계정이 생기지 않게: 다시 켜면 새 익명 계정으로 시작
		Meta.nickname = ""
		nick_edit.text = ""
		for c in settings_panel.find_children("*", "CheckButton", true, false):
			if (c as CheckButton).text.begins_with("기록 보내기"):
				(c as CheckButton).set_pressed_no_signal(false)
		_save_best()
		if account_label:
			account_label.text = Account.label()
		_show_toast("서버에 저장된 내 데이터를 지웠어요. '기록 보내기'를 다시 켜면 새 익명 계정으로 시작해요")
	else:
		_show_toast("지우지 못했어요. 인터넷 연결을 확인하고 다시 눌러 주세요" if code == 0 else "지우지 못했어요 (서버 %d)" % code)


## ◀ 글자 ▶ 한 줄.
## 시작 화면 큰 타일: 버튼 위에 이름(색)과 설명 줄. 설명 Label을 돌려준다.
func _tile(b: Button, title: String, col: Color, key: Variant) -> Label:
	b.text = ""
	b.custom_minimum_size = Vector2(_tile_w(), 170 if _phone() else 150)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.09, 0.12) if st == "normal" else Color(0.1, 0.13, 0.17)
		sb.set_border_width_all(2)
		sb.border_color = Color(col, 0.55 if st == "normal" else 0.95)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st, sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	var n := Label.new()
	n.text = title
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_font_size_override("font_size", 26)
	n.add_theme_color_override("font_color", col)
	v.add_child(n)
	var info := Label.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(info)
	_keycap(b, key)
	return info


func _tile_w() -> float:
	return 230.0 if _phone() else 210.0


## 시작 화면: 첫 화면(큰 타일) ↔ 일반 판 준비 화면.
func _set_prep(on: bool) -> void:
	prep = on
	prep_title.visible = on
	prep_box.visible = on
	prep_back.visible = on
	home_box.visible = not on
	title_box.get_child(0).visible = not on  # 로고·소개 줄은 첫 화면에만
	title_box.get_child(1).visible = not on and not _phone()
	new_armed = 0.0
	new_btn.text = "새로 시작" if continue_btn.visible else "시작"
	sfx.play("place")
	_refresh_menu()


const PREP_W := 640.0


## 준비 화면 칸: 화면 폭이 맵 카드 + 오른쪽 묶음(520)을 나란히 둘 만큼이면 두 칸
func _prep_layout() -> void:
	if prep_cols == null:
		return
	# 오른쪽 칸 폭: 남는 폭에 맞춰 420~520 (폰 가로 글자 130%는 UI 폭 약 1120)
	# 조금 모자라면 _fit_panels가 폭에 맞춰 살짝 줄인다 (한 칸으로 두면 높이 탓에 0.57배까지 줄었다)
	var rw := clampf(ui_root.size.x - PREP_W - 12.0 - 24.0, 420.0, 520.0)
	var two := ui_root.size.x >= 960.0
	var w := floorf(rw) if two else PREP_W
	if prep_cols.columns == (2 if two else 1) and prep_cols.get_meta("laid", -1.0) == w:
		return
	prep_cols.set_meta("laid", w)
	prep_cols.columns = 2 if two else 1
	for k: Control in prep_right.get_children():
		k.custom_minimum_size.x = w
		k.size_flags_horizontal = Control.SIZE_FILL if two else Control.SIZE_SHRINK_CENTER  # 긴 글로 넓어진 줄에 다른 줄도 폭을 맞춘다
	for l: Control in prep_right.find_children("*", "Label", true, false):
		if l.has_meta("sub_w"):
			l.custom_minimum_size.x = w - 220.0


func _prep_sb(hov := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16) if hov else Color(0.07, 0.085, 0.115)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _prep_name(t: String) -> Label:
	var n := Label.new()
	n.text = t
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.custom_minimum_size = Vector2(96, 0)
	n.add_theme_font_size_override("font_size", 15)
	n.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	return n


func _prep_main() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 19)
	return l


func _prep_sub() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(PREP_W - 220.0, 0)
	l.set_meta("sub_w", true)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	return l


## 준비 화면 한 줄: [이름표 | ◀ | 가운데 글(+작은 설명) | ▶]. 가운데 글을 눌러도 다음으로.
## 가운데 Label을 돌려주고, 작은 설명 Label은 meta "sub", 줄 전체는 meta "row".
func _prep_row(box: BoxContainer, title: String, prev: Callable, next: Callable) -> Label:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(PREP_W, 64 if _phone() else 56)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_stylebox_override("panel", _prep_sb())
	box.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	h.add_child(_prep_name(title))
	var bs := Vector2(56, 52) if OS.has_feature("mobile") else Vector2(40, 40)
	var a := Button.new()
	a.text = "◀"
	a.flat = true
	a.focus_mode = Control.FOCUS_NONE
	a.custom_minimum_size = bs
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	a.pressed.connect(prev)
	h.add_child(a)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var l := _prep_main()
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			next.call()
			l.accept_event())
	v.add_child(l)
	var sub := _prep_sub()
	v.add_child(sub)
	var b := Button.new()
	b.text = "▶"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = bs
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(next)
	h.add_child(b)
	l.set_meta("sub", sub)
	l.set_meta("row", row)
	return l


## 준비 화면 맵 고르기: 맵 카드 다섯 장(이름·길 모양·규칙·친화 속성 그림·최고 웨이브) + 아래 고른 맵 설명.
## 2026-11-01 사용자 요청 "맵 친화 속성도 게임 시작 전에 알 수 있게, 텍스트 대신 카드 형식으로". ←/→도 그대로.
func _build_map_cards(box: BoxContainer) -> Label:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(PREP_W, 0)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var psb := _prep_sb()
	psb.content_margin_left = 8
	psb.content_margin_top = 8
	psb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", psb)
	box.add_child(row)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	map_cards.clear()
	var cw := floorf((PREP_W - 16.0 - 8.0 * (Meta.MAP_IDS.size() - 1)) / Meta.MAP_IDS.size())
	for id in Meta.MAP_IDS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(cw, 150 if _phone() else 138)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("map", id)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())  # 바탕·테두리는 _draw_map_card가 (고른 맵 강조)
		b.pressed.connect(func():
			if Meta.map_id != id:
				Meta.map_id = id
				sfx.play("place")
				_refresh_menu()
				_save_best()
				queue_redraw())
		b.draw.connect(_draw_map_card.bind(b))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		h.add_child(b)
		map_cards.append(b)
	var l := _prep_main()
	v.add_child(l)
	var sub := _prep_sub()
	sub.custom_minimum_size = Vector2(PREP_W - 40.0, 0)
	v.add_child(sub)
	l.set_meta("sub", sub)
	l.set_meta("row", row)
	return l


## 맵 카드 한 장: 고른 맵은 밝은 테두리. 위 이름, 가운데 길 모양, 규칙 이름, 친화 속성 그림, 최고 웨이브.
func _draw_map_card(b: Button) -> void:
	var id: String = b.get_meta("map")
	var m: Dictionary = Meta.MAPS[id]
	var sel := Meta.map_id == id
	var hov := b.is_hovered()
	var r := Rect2(Vector2.ZERO, b.size)
	var acc := Color(0.75, 0.85, 1.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = (m["bg"] as Color).lightened(0.12 if sel else (0.07 if hov else 0.03))
	sb.border_color = Color(1, 0.85, 0.45) if sel else Color(1, 1, 1, 0.25 if hov else 0.1)
	sb.set_border_width_all(3 if sel else 1)
	sb.set_corner_radius_all(8)
	b.draw_style_box(sb, r)
	var cx := b.size.x / 2.0
	var nc := Color(1, 0.92, 0.7) if sel else Color(1, 1, 1, 0.85)
	b.draw_string(ui_font, Vector2(0, 22), m["name"], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 16, nc)
	if id in Meta.TRIAL_MAPS:
		b.draw_string(ui_font, Vector2(0, 35), "시험", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 10, Color(1, 1, 1, 0.45))
	_draw_map_path(b, id, Vector2(cx, 62.0), 20.0, Color(acc, 0.75 if sel else 0.5))
	var rt := MapRule.rule_text(id).get_slice(":", 0)
	b.draw_string(ui_font, Vector2(0, 100), rt, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 13, Color(MAP_AFF_COLOR, 0.95 if sel else 0.7))
	# 친화 속성 그림 (자주 나오고 피해 +)
	var es: Array = MapRule.aff("elem", id)
	var gap := 26.0
	var x0 := cx - gap * (es.size() - 1) / 2.0
	for i in es.size():
		Glyph.elem(b, es[i], Vector2(x0 + gap * i, 118.0), 9.0)
	var best := Meta.best_of(Meta.run_key(id))
	if best[0] > 0:
		b.draw_string(ui_font, Vector2(0, b.size.y - 6.0), "최고 %d" % best[0], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 11, Color(1, 1, 1, 0.5))


## 맵 카드 가운데 길 모양 그림 (구체가 들어오는 모양). c 가운데, s 반지름.
func _draw_map_path(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c, 3.0, Color(1, 0.9, 0.6))
	match id:
		"plain":
			for k in 3:
				var d := Vector2.from_angle(-PI / 2.0 + k * TAU / 3.0)
				ci.draw_line(c + d * s * 1.5, c + d * s * 0.45, col, 2.0)
		"spiral":
			var pts := PackedVector2Array()
			for i in 40:
				var t := i / 39.0
				pts.append(c + Vector2.from_angle(t * TAU * 1.4) * s * (1.5 - t * 1.1))
			ci.draw_polyline(pts, col, 2.0)
		"cross":
			for k in 4:
				var d := Vector2.from_angle(k * PI / 2.0)
				ci.draw_line(c + d * s * 1.5, c + d * s * 0.45, col, 3.0)
		"storm":
			for k in 6:
				var a := k * TAU / 6.0 + 0.3
				var d := Vector2.from_angle(a)
				ci.draw_line(c + d * s * 1.5, c + d * s * 1.0, Color(col, 0.4 + 0.1 * (k % 3)), 2.0)
			ci.draw_arc(c, s * 0.75, 0.6, 2.4, 10, Color(col, 0.6), 1.5)
			ci.draw_arc(c, s * 0.75, 3.7, 5.5, 10, Color(col, 0.6), 1.5)
		"line":
			ci.draw_line(c + Vector2(-s * 2.2, 0), c + Vector2(s * 2.2, 0), col, 3.0)
			ci.draw_line(c + Vector2(-s * 2.2, -6), c + Vector2(-s * 2.2, 6), Color(1, 0.9, 0.6, 0.8), 2.0)


## 준비 화면 줄 글: 가운데 글과 작은 설명 (설명이 비면 숨김).
func _prep_set(l: Label, main_t: String, sub_t: String) -> void:
	l.text = main_t
	var sub: Label = l.get_meta("sub")
	sub.text = _kr_keep(sub_t)
	sub.visible = sub_t != ""


func _menu_row(box: BoxContainer, prev: Callable, next: Callable, w := 560.0) -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	# 폰에선 화면이 작아 화살표 버튼이 손가락보다 작다: 버튼을 키우고 가운데 글을 눌러도 다음으로 (2026-10-31)
	var bs := Vector2(64, 56) if OS.has_feature("mobile") else Vector2(44, 40)
	var a := Button.new()
	a.text = "◀"
	a.focus_mode = Control.FOCUS_NONE
	a.custom_minimum_size = bs
	a.pressed.connect(prev)
	row.add_child(a)
	var l := Label.new()
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			next.call()
			l.accept_event())
	row.add_child(l)
	var b := Button.new()
	b.text = "▶"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = bs
	b.pressed.connect(next)
	row.add_child(b)
	return l


## 맵 규칙 그림: 십자로 길목 띠(쉬는 시간), 폭풍 바람 줄기와 화살표.
func _draw_map_rule(c: Vector2, now: float) -> void:
	if title_label.visible:
		return
	if MapRule.is_map("cross") and phase != Phase.WAVE:
		for a in lanes:
			var u := Vector2.from_angle(a)
			var e := _edge_point(c, u)
			var n := u.orthogonal() * MapRule.LANE_W
			draw_colored_polygon(PackedVector2Array([c + u * 60.0 + n, e + n, e - n, c + u * 60.0 - n]), Color(MAP_AFF_COLOR, 0.05))
			draw_line(c + u * 60.0 + n, e + n, Color(MAP_AFF_COLOR, 0.18), 1.0)
			draw_line(c + u * 60.0 - n, e - n, Color(MAP_AFF_COLOR, 0.18), 1.0)
	var w := MapRule.wind_dir(lanes)
	if w != Vector2.ZERO:
		# 바람 줄기: 화면을 가로질러 흐르는 짧은 선 (웨이브 중에는 옅게)
		var vr := arena()
		var al := 0.16 if phase != Phase.WAVE else 0.07
		for i in 24:
			var h := Vector2(fmod(i * 0.6180339, 1.0), fmod(i * 0.4142135 + 0.13, 1.0))
			var p := vr.position + Vector2(h.x * vr.size.x, h.y * vr.size.y)
			var off := fmod(now * 90.0 + i * 37.0, 260.0)
			p += w * off
			p = Vector2(vr.position.x + fposmod(p.x - vr.position.x, vr.size.x), vr.position.y + fposmod(p.y - vr.position.y, vr.size.y))
			draw_line(p, p + w * 34.0, Color(1, 1, 1, al * (1.0 - off / 260.0)), 2.0)
		# 화살표: 중앙 위
		var at := c + Vector2(0, -150.0)
		var col := Color(1, 1, 1, 0.55 if phase != Phase.WAVE else 0.25)
		draw_line(at - w * 40.0, at + w * 30.0, col, 4.0)
		draw_colored_polygon(PackedVector2Array([at + w * 46.0, at + w * 22.0 + w.orthogonal() * 12.0, at + w * 22.0 - w.orthogonal() * 12.0]), col)


## 시작 화면 맵 줄: 맵 규칙·친화 카드 (시험)
func _refresh_menu() -> void:
	var m: Dictionary = Meta.MAPS[Meta.map_id]
	var best := Meta.best_of(Meta.run_key())
	# 폰: 맵 설명 줄은 뺀다 (도움말·도감에 있고, 줄이 많으면 시작 화면 전체가 줄어 버튼이 작아진다)
	# 맵 카드 아래: 고른 맵 이름·규칙, 작은 설명에 맵 설명·친화 카드·최고 기록 (폰은 맵 설명 줄만 뺌)
	var mr := MapRule.rule_text() + " (시험)" if MapRule.on() else ""
	_prep_set(map_label, _kh("%s%s" % [Meta.map_name(), "" if touch_ui else "  (←/→)"]), "%s%s최고 기록%s · 웨이브 %d · 점수 %s" % ["" if _phone() else m["desc"].replace("\n", " ") + "\n", "%s\n친화 카드 (자주 나옴·피해 +%d%%): %s\n" % [mr, roundi(Rules.t("map_aff_dmg") * 100), MapRule.aff_text()] if MapRule.on() else "", " (쉽게 모드)" if Modes.easy() else "", best[0], num(best[1])])
	for mc in map_cards:
		mc.queue_redraw()
	flip_label.get_meta("row").visible = Meta.map_id == "line"
	_prep_set(flip_label, _kh("%s  (F)" % ("왼쪽 → 문은 오른쪽 끝" if Meta.line_flip else "오른쪽 → 문은 왼쪽 끝")), "")
	var ra := [Rules.NAMES[Meta.rules], " (시험)" if Meta.rules in Rules.TRIAL_IDS else "", "(눌러서 바꾸기)" if touch_ui else "(↑/↓)", _wrap_parts(Patch.text("rules_desc", str(Meta.rules), Rules.DESCS[Meta.rules]), " · ", 550.0, 18)]
	# 폰: 규칙 설명 줄도 뺀다 (이름만, 자세한 건 도움말·모드 창)
	_prep_set(rules_label, _kh("%s%s  %s" % ra.slice(0, 3)), "" if _phone() else ra[3].replace("\n", " · "))
	rules_label.get_meta("row").visible = Meta.games > 0  # 규칙 버전 고르기는 첫 판을 끝낸 뒤에 (그 전엔 버전 1)
	modes_btn.visible = Meta.games > 0  # 모드도
	var sk := Skill.set_ids(Meta.skill_set)
	_prep_set(skill_label, Skill.combo_name(Meta.skill_set) + ("  (눌러서 바꾸기)" if touch_ui else ""),
		"" if _phone() else "웨이브 중 %s · %s" % ["%s: %s" % [Skill.NAMES[sk[0]], Skill.desc(sk[0])], "%s: %s" % [Skill.NAMES[sk[1]], Skill.desc(sk[1])]])
	skill_label.get_meta("row").visible = Rules.t("skill_on") > 0.0
	_prep_set(modes_label, "없음" if Modes.on.is_empty() else Modes.names(), "판을 어렵게·쉽게 바꾸는 규칙 · 점수 배율이 붙어요" if Modes.on.is_empty() else "점수 x%.2f" % Modes.mul())
	if modes_panel.visible:
		_refresh_modes()
	var ts: Dictionary = Meta.TOWER_SKINS[Meta.tower_skin]
	skin_label.text = "오브젝트 모양: " + ts["name"]
	var cs: Dictionary = Meta.CORE_SKINS[Meta.core_skin]
	core_label.text = "중앙 모양: " + cs["name"]
	best_wave = best[0]
	best_score = best[1]
	normal_info.text = "맵·규칙·모드를 골라 한 판\n%s · %s\n최고 웨이브 %d" % [Meta.map_name(), Rules.NAMES[Meta.rules], best[0]]


## 회랑 맵: 구체가 오는 쪽(좌우)을 바꾼다. 기록은 나누지 않는다 (좌우만 바뀐 같은 판).
func _toggle_flip() -> void:
	if Meta.map_id != "line":
		return
	Meta.line_flip = not Meta.line_flip
	sfx.play("place")
	_refresh_menu()
	_save_best()
	queue_redraw()


func _cycle_map(d: int) -> void:
	var i := Meta.MAP_IDS.find(Meta.map_id)
	Meta.map_id = Meta.MAP_IDS[(i + d + Meta.MAP_IDS.size()) % Meta.MAP_IDS.size()]
	sfx.play("place")
	_refresh_menu()
	_save_best()
	queue_redraw()


## 오른쪽 설명: 상한은 규칙 버전에 따라 다르다.
const LEGEND_ICONS := ["pat", "elem", "mod", "link", "trig", "tower", "rx"]
var legend_heads := PackedStringArray()
var short_re := RegEx.create_from_string("\\s*\\([^)]*\\)")  # 카드 간소화: 괄호 덧붙임 빼기  # 그림이 붙는 앞줄들 (_draw_legend_icons)


## 오른쪽 설명 줄 앞 그림. 글자를 키우면 줄이 접히므로 앞줄들이 몇 줄로 접히는지 세어 자리를 맞춘다.
func _draw_legend_icons() -> void:
	var lh := legend.get_line_height() + legend.get_theme_constant("line_spacing")
	var fs := legend.get_theme_font_size("font_size")
	var w := legend.size.x - 32.0 - 8.0
	var row := 0
	for i in mini(LEGEND_ICONS.size(), legend_heads.size()):
		var c := Vector2(16.0, 8.0 + lh * row + legend.get_line_height() / 2.0)
		row += _wrap_words(_kr_keep(legend_heads[i]), w, fs).count("\n") + 1
		var id: String = LEGEND_ICONS[i]
		if id == "tower":
			Glyph.ui(legend, id, c, 6.5, Color(1, 1, 1, 0.7))
		else:
			Glyph.kind(legend, id, c, 7.0, Color(0.95, 0.85, 0.6))


func _refresh_legend() -> void:
	# 줄 앞 그림(카드 종류)은 legend.draw에서 (LEGEND_ICONS 순서). 그림이 있어 머리 글·긴 설명을 뺐다
	var cap_e := "%d종까지" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "종류마다 공속 -%d%%" % roundi(Rules.tax_step * 100)
	var cap_m := "종류별 %d · 합 %d" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "쌓을수록 절반"
	legend_heads = PackedStringArray([
		"공격방식 · 직선탄에 1번, 같은 것 Lv↑",
		"속성 · 추가 효과, " + cap_e,
		"강화 · 공격 변형, " + cap_m,
		"연계 · 주변 오브젝트와 함께",
		"발동 · 조건이 맞으면 추가 공격",
		"새 오브젝트 = 직선탄 + 속성 1",
		"조합 · 두 속성이 만나면 (%d/%d)" % [Meta.codex.size(), Elem.REACTIONS.size()],
	])
	var lines := legend_heads.duplicate()
	# 반응이 91개라 만들어 본 반응만 한 줄에 세 개씩 (나머지는 개수만, 도감과 같은 기록).
	# 줄 수는 legend_rx_rows까지: 많이 찾으면 설명이 화면 아래 설정 버튼까지 덮던 것 (_process에서 맞춤)
	var rs: Array = Elem.REACTIONS.filter(func(r): return Meta.codex.has(r["id"]))
	var shown := 0
	legend_rows = 0
	for i in range(0, rs.size(), 3):
		if legend_rows >= legend_rx_rows:
			break
		var row := PackedStringArray()
		for r in rs.slice(i, i + 3):
			row.append("%s+%s %s" % [Elem.NAMES[r["a"]], Elem.NAMES[r["b"]], r["name"]])
		lines.append("   ".join(row))
		shown += row.size()
		legend_rows += 1
	var k := "" if touch_ui else " K"
	if shown < rs.size():
		var left := Elem.REACTIONS.size() - rs.size()
		lines.append("외 %d개%s (모두 도감%s)" % [rs.size() - shown, " · 못 만난 조합 %d개" % left if left > 0 else "", k])
	elif rs.size() < Elem.REACTIONS.size():
		lines.append("못 만난 조합 %d개 (도감%s)" % [Elem.REACTIONS.size() - rs.size(), k])
	legend.text = _kr_keep("\n".join(lines))
	legend.size.y = 380.0  # Label은 글이 줄어도 저절로 작아지지 않는다 (글이 길면 다시 늘어남)


## 규칙 버전 바꾸기: 기록은 버전마다 따로.
func _cycle_skill(d: int) -> void:
	Meta.skill_set = posmod(Meta.skill_set + d, Skill.SETS.size())
	sfx.play("place")
	_refresh_menu()
	_save_best()


func _cycle_rules(d: int) -> void:
	var i := Rules.IDS.find(Meta.rules)
	Meta.rules = Rules.IDS[(i + d + Rules.IDS.size()) % Rules.IDS.size()]
	_apply_rules()
	sfx.play("place")
	_refresh_menu()
	_save_best()
	_update_hud(true)


## 잠긴 스킨은 건너뛰고, 잠긴 것이 있으면 해금 조건을 알려 준다.
func _cycle_skin(kind: String, d: int) -> void:
	var ids: Array = Meta.TOWER_SKIN_IDS if kind == "tower" else Meta.CORE_SKIN_IDS
	var defs: Dictionary = Meta.TOWER_SKINS if kind == "tower" else Meta.CORE_SKINS
	var cur: String = Meta.tower_skin if kind == "tower" else Meta.core_skin
	var i := ids.find(cur)
	var locked := PackedStringArray()
	for k in ids.size():
		i = (i + d + ids.size()) % ids.size()
		var need: String = defs[ids[i]]["need"]
		if Meta.unlocked(need):
			break
		locked.append("%s: %s" % [defs[ids[i]]["name"], Meta.ACHIEVEMENTS[need]["name"]])
	if kind == "tower":
		Meta.tower_skin = ids[i]
	else:
		Meta.core_skin = ids[i]
	if not locked.is_empty():
		_show_toast("잠김 - " + ", ".join(locked) + " 업적으로 해금")
	sfx.play("place")
	_refresh_menu()
	_save_best()
	for t in towers.get_children():
		t.queue_redraw()


func _toggle_codex() -> void:
	if not codex_panel.visible:
		settings_panel.visible = false
		records_panel.visible = false
		help_label.visible = false
		notes_panel.visible = false
		modes_panel.visible = false
	if vote_panel.visible:
		vote_panel.hide_panel()
	codex_panel.fit(ui_root.size, _phone())
	codex_panel.toggle()
	if codex_panel.visible:
		net.ach_rates()


## 다음 패치 투표 창. 판 끝난 화면에서 열면 이번 판에 고른 카드·특성이 맨 앞 탭.
func _toggle_vote(from_run := false) -> void:
	if not vote_panel.visible:
		settings_panel.visible = false
		records_panel.visible = false
		help_label.visible = false
		notes_panel.visible = false
		modes_panel.visible = false
		codex_panel.visible = false
	vote_panel.toggle(_vote_run_keys() if from_run else [])


## 이번 판에 고른 것 (통계 키, 고른 차례대로, 겹치지 않게).
func _vote_run_keys() -> Array:
	var out := []
	for e in run_log:
		var p := str(e.get("p", ""))
		if p != "" and not out.has(p):
			out.append(p)
	return out


func _toggle_records() -> void:
	records_panel.visible = not records_panel.visible
	board_box.visible = false
	board_ugc_panel.visible = false
	if not records_panel.visible:
		return
	_records_fit()
	var lines := PackedStringArray(["[맵별 최고 기록 · %s]   (아무 곳이나 %s)" % [Rules.NAMES[Meta.rules], "누르면 닫기" if touch_ui else "클릭: 닫기"]])
	for id in Meta.MAP_IDS:
		var b := Meta.best_of(Meta.key(id))
		var e := Meta.best_of(Meta.key(id) + Meta.EASY_TAG)  # 쉽게 모드를 쓴 판은 따로
		lines.append("  %s: 웨이브 %d · 점수 %s%s" % [Meta.map_name(id), b[0], num(b[1]), "   (쉽게 모드: 웨이브 %d · 점수 %s)" % [e[0], num(e[1])] if e[0] > 0 else ""])
	# 규칙 버전끼리 비교하기 쉽게: 지금 맵의 버전별 최고 웨이브
	var vers := PackedStringArray()
	for r in Rules.IDS:
		vers.append("%s: %d" % [Rules.NAMES[r], Meta.best_of(Meta.key(Meta.map_id, r))[0]])
	lines.append("  %s 규칙별 최고 웨이브  %s" % [Meta.map_name(Meta.map_id), " · ".join(vers)])
	# 2026-10-30 이전 규칙(버전 1~5)의 기록은 따로 보관해 보여 준다
	var olds := PackedStringArray()
	for r in Rules.OLD_IDS:
		var w: int = Meta.best_of(Meta.key(Meta.map_id, r, true))[0]
		if w > 0:
			olds.append("버전 %d: %d" % [r, w])
	if not olds.is_empty():
		lines.append("  이전 규칙 최고 웨이브  %s" % " · ".join(olds))
	lines.append("  총 처치 %s · 플레이 %d판" % [num(Meta.total_kills), Meta.games])
	lines.append("")
	# 업적은 도감 업적 탭에 진행 막대와 함께 (55개라 여기에 다 쓰면 창이 넘친다). 등급마다 수만
	var tiers := PackedStringArray()
	for tid in Ach.TIER_IDS:
		var of_t := Ach.LIST.filter(func(a): return a["tier"] == tid)
		tiers.append("%s %d/%d" % [Ach.TIERS[tid]["name"], of_t.filter(func(a): return Meta.achieved.has(a["id"])).size(), of_t.size()])
	lines.append("[업적] %d / %d   %s   (도감%s 업적 탭)" % [Meta.achieved.size(), Ach.LIST.size(), " · ".join(tiers), "" if touch_ui else "(K)"])
	if Meta.title != "":
		lines.append("  칭호: " + Meta.ACHIEVEMENTS[Meta.title]["name"])
	lines.append("")
	lines.append("[조합 도감] %d / %d   (모든 조합은 도감%s 조합 탭)" % [Meta.codex.size(), Elem.REACTIONS.size(), "" if touch_ui else "(K)"])
	# 찾은 반응만 이어 쓴다. 모르는 칸마다 ???를 쓰면 반응이 91개라 창이 화면 높이만큼 길어져 글자가 읽을 수 없게 작아졌다
	var found := PackedStringArray()
	for r in Elem.REACTIONS:
		if Meta.codex.has(r["id"]):
			found.append("%s(%s+%s)" % [r["name"], Elem.NAMES[r["a"]], Elem.NAMES[r["b"]]])
	if not found.is_empty():
		# 많이 찾아도 4줄까지 (다 찾으면 16줄이 넘어 창 전체가 읽을 수 없게 작아졌다). 나머지는 도감에서
		var k := found.size()
		var wl := _wrap_words(", ".join(found), 600.0, 15).split("\n")
		while wl.size() > 4 and k > 1:
			k -= 1
			wl = _wrap_words(", ".join(found.slice(0, k)) + " 외 %d개" % (found.size() - k), 600.0, 15).split("\n")
		for l in wl:
			lines.append("  " + l)
	records_panel.text = _kr_keep("\n".join(lines))


# ---------- 온라인 ----------

## 서버 응답(켤 때, 시작 화면으로 돌아올 때): 시작 화면이면 받은 패치를 바로 적용하고, 새 버전·공지를 띄운다.
func _on_booted(info: Dictionary) -> void:
	if info.is_empty() or update_btn == null:
		return
	if title_label.visible:
		_apply_rules()
		_refresh_menu()
	var latest: Variant = info.get("latest")
	# 폰·태블릿은 스토어 주소만 연다 (App Store 2.5.2·3.1: 앱 밖에서 빌드를 받게 하지 않음)
	if latest is Dictionary and OS.has_feature("mobile") and not (str(latest.get("url", "")).begins_with("https://apps.apple.com/") or str(latest.get("url", "")).begins_with("https://play.google.com/")):
		latest = null
	if latest is Dictionary and str(latest.get("url", "")) != "" and not updater.busy:
		var notes := str(latest.get("notes", ""))
		var url := str(latest["url"])
		var auto := Updater.available(latest)
		update_btn.text = "새 버전 v%s %s%s" % [latest.get("version", "?"), "업데이트" if auto else "받기", " · " + notes if notes != "" else ""]
		update_btn.disabled = false
		_set_update_action(func(): _start_update(latest) if auto else OS.shell_open(url))
		update_btn.visible = true
	elif not updater.busy:
		update_btn.visible = false  # 다시 물어보니 새 버전이 없음 (서버에서 내림)
	var msg := Patch.text("", "message", "")
	notice_label.text = _kr_keep(msg)
	notice_label.visible = msg != ""
	if Net.acct_ok():
		net.sync()  # 진행을 계정 것과 합친다 (다른 기기에서 한 것)
		if title_label.visible:
			net.list_runs()


## 다른 기기 진행과 합쳐졌다: 저장하고 시작 화면 글(최고 기록·해금)을 다시 쓴다.
func _on_progress_synced() -> void:
	var b := Meta.best_of(Meta.run_key())
	best_wave = maxi(best_wave, b[0])
	best_score = maxi(best_score, b[1])
	_ach_catch_up()
	_save_best()
	if title_label.visible:
		Modes.set_on(Meta.modes if Meta.games > 0 else [])
		_apply_rules()
		_refresh_menu()


## 계정의 진행 중 판 목록: 이 기기 판을 다른 기기가 가져갔으면 지우고, 이 기기에 판이 없으면 다른 기기 판을 이어 하게.
func _on_runs_listed(list: Array) -> void:
	var local := _local_run_key()
	remote_run = ""
	for e in list:
		if not e is Dictionary:
			continue
		if str(e.get("run", "")) == local and local != "" and not e.get("mine", true):
			_on_run_moved(local)
			local = ""
	if local == "" and not FileAccess.file_exists(RUN_PATH):
		for e in list:
			if e is Dictionary and not e.get("mine", true) and Net.same_minor(str(e.get("game", "")), Net.game_version()) and str(e.get("map", "")) in Meta.MAP_IDS:
				remote_run = str(e["run"])
				remote_btn.text = "다른 기기에서 하던 판 이어하기   웨이브 %d부터 · %s" % [int(e.get("wave", 0)) + 1, Meta.MAPS[str(e["map"])]["name"]]
				break
	remote_btn.visible = remote_run != "" and title_label.visible
	remote_btn.disabled = false


func _claim_remote_run() -> void:
	if remote_run == "":
		return
	remote_btn.disabled = true
	remote_btn.text = "가져오는 중..."
	net.claim_run(remote_run)


func _on_run_claimed(d: Dictionary) -> void:
	remote_btn.visible = false
	var cfg := ConfigFile.new()
	if d.is_empty() or cfg.parse(str(d.get("data", ""))) != OK or Meta.val(cfg, "run", "format", 0) != RUN_FORMAT:
		_show_toast("다른 기기의 판을 가져오지 못했어요")
		return
	cfg.save(RUN_PATH)
	moved_run = ""
	_refresh_continue()
	if title_label.visible and continue_btn.visible:
		_continue_run()


## 다른 기기가 이 판을 가져갔다: 시작 화면이면 이어하기를 지우고, 하는 중이면 계속 하되 서버에는 더 올리지 않는다.
func _on_run_moved(key: String) -> void:
	if title_label.visible and _local_run_key() == key:
		_clear_run(false)
		_refresh_continue()
		_show_toast("하던 판은 다른 기기에서 이어 하고 있어요")
	elif run_id == key and moved_run != key:
		moved_run = key
		_show_toast("이 판을 다른 기기에서 이어 하고 있어요. 여기서 계속 해도 다른 기기로는 넘어가지 않아요")


func _local_run_key() -> String:
	var cfg := ConfigFile.new()
	return str(Meta.val(cfg, "run", "run_id", "")) if cfg.load(RUN_PATH) == OK else ""


func _set_update_action(f: Callable) -> void:
	for c in update_btn.pressed.get_connections():
		update_btn.pressed.disconnect(c["callable"])
	update_btn.pressed.connect(f)


## [업데이트]: 받는 동안 버튼이 진행률을 보여 주고, 다 되면 새 버전으로 다시 켜진다.
func _start_update(latest: Dictionary) -> void:
	update_btn.disabled = true
	update_btn.text = "업데이트 받는 중..."
	updater.start(latest)


func _on_update_progress(ratio: float) -> void:
	update_btn.text = "업데이트 받는 중 %d%%" % int(ratio * 100) if ratio >= 0.0 else "업데이트 받는 중..."


## 실패하면 원래 버전 그대로: 버튼을 눌러 지금처럼 zip을 직접 받는다.
func _on_update_failed(reason: String) -> void:
	var latest: Variant = Net.info.get("latest")
	var url := str(latest.get("url", "")) if latest is Dictionary else ""
	update_btn.disabled = false
	update_btn.text = "업데이트 실패: %s · 눌러서 직접 받기" % reason
	_set_update_action(func(): OS.shell_open(url))


static func _new_run_id() -> String:
	return "%d-%06d" % [Time.get_unix_time_from_system(), randi() % 1000000]


## 판 기록(점수·특성·선택지·지금 구성)을 서버로. 설정에서 끄면 보내지 않는다.
## done=false: 5웨이브마다 보내는 진행 중 기록. 서버는 같은 판 번호(run)면 한 줄을 고친다.
func _submit_run(done := true) -> void:
	if not Net.enabled() or mp_mode != "" or TutPlay.on:
		return
	var ts := towers.get_children()
	var total := 0.0
	for t in ts:
		total += t.run_dealt + t.dealt
	var list: Array = []
	for t in ts:
		var els := {}
		for e in t.elements:
			els[Patch.ELEM_KEYS[Elem.ALL.find(e)]] = t.elements[e]
		list.append({"els": els, "pat": t.pattern, "plv": t.plv, "mods": t.mods, "reso": t.reso,
			"pincer": t.pincer, "trigs": t.trigs, "share": (t.run_dealt + t.dealt) / total if total > 0.0 else 0.0})
	# 피해 출처 몫 (속성·공격방식·강화·반응·연계별, 오브젝트를 합쳐서). 직접 타격 안의 배율 몫은 추정
	var src := {}
	var rs := _run_src()
	for key in rs:
		if total > 0.0 and rs[key] / total >= 0.0005:
			src[key] = snappedf(rs[key] / total, 0.0001)
	net.submit({
		"device": Meta.device_id, "nick": Meta.nickname, "title": Meta.title, "platform": Net.platform(), "game": old_run_ver if old_run_ver != "" else Net.game_version(),
		"patch": Patch.id, "map": Meta.map_id, "rules": Meta.rules, "modes": Array(Modes.on) + (["grow"] if legacy_grow else []), "wave": wave, "score": score, "kills": kills,
		"best_combo": best_combo, "game_secs": run_game, "real_secs": run_real, "perks": perks.duplicate(),
		"towers": list, "src": src, "log": run_log, "leaks": _leak_records(), "vary": Vary.record(), "run": run_id, "ended": done,
	})


## 서버가 기록을 받으면 게임 오버 글 아래에 온라인 순위.
func _on_run_sent(res: Dictionary) -> void:
	if phase != Phase.GAMEOVER or not res.get("accepted", false):
		return
	var rk: Variant = res.get("rank")
	if int(res.get("season", 0)) == 0:
		over_label.text += _kr_keep("\n(지난 버전으로 한 판이라 이번 시즌 리더보드에는 들어가지 않아요)")
		over_card.queue_redraw()
	elif rk is Dictionary:
		var season: Variant = Net.info.get("season")
		var sname := str(season.get("name", "")) if season is Dictionary else ""
		over_label.text += "\n온라인 순위%s: %s%d위 (최고 점수 %s)" % [" (쉽게 모드)" if Modes.easy() else "", sname + " " if sname != "" else "", int(rk["rank"]), num(int(rk["score"]))]
		over_card.queue_redraw()


## 시작 화면 리더보드 (2026-11-01 개편): 왼쪽 필터(맵·규칙·기록·시즌 칩을 모두 펼쳐 한 번에 고름), 오른쪽 순위 표(전체/이번 주 탭).
## 처음엔 지금 고른 맵·규칙·기록 종류의 이번 시즌 전체. 지난 시즌은 전체만.
func _toggle_board() -> void:
	records_panel.visible = not records_panel.visible
	board_ugc_panel.visible = false
	if not records_panel.visible:
		board_box.visible = false
		return
	board_map = Meta.map_id
	board_rules = Meta.rules if Meta.rules in Rules.IDS else Rules.IDS[0]
	board_easy = Modes.easy()  # 쉽게 모드를 켰으면 쉽게 모드 기록
	board_season = 0
	board_period = "all"
	records_panel.text = ""
	board_box.visible = true
	_board_fit()
	net.seasons()
	_load_board()


func _board_tag() -> String:
	return "%s|%d|%d|%s" % [board_map, board_rules, board_season, board_easy]


func _load_board() -> void:
	board_raw = {}
	board_people = {}
	board_ugc_panel.visible = false
	if board_season != 0:
		board_period = "all"
	_draw_board()
	net.leaderboard(board_map, board_rules, "all", board_season, _board_tag(), board_easy)
	if board_season == 0:
		net.leaderboard(board_map, board_rules, "week", 0, _board_tag(), board_easy)


## 칩 하나를 눌렀을 때. what: map·rules·kind(pure·easy)·season(0 = 이번 시즌)
func _board_set(what: String, v: Variant) -> void:
	match what:
		"map": board_map = str(v)
		"rules": board_rules = int(v)
		"kind":
			board_easy = v == "easy"
		"season": board_season = int(v)
	_load_board()


func _board_kind() -> String:
	return "easy" if board_easy else "pure"


func _board_value(what: String) -> Variant:
	return {"map": board_map, "rules": board_rules, "kind": _board_kind(), "season": board_season}[what]


func _on_seasons_loaded(list: Array) -> void:
	board_seasons = list.filter(func(x): return x is Dictionary)
	if records_panel.visible and board_box.visible:
		_draw_board()


func _season_name(id: int) -> String:
	for x in board_seasons:
		if int(x.get("id", 0)) == id:
			return str(x.get("name", ""))
	return "시즌 %d" % id


func _on_board_loaded(d: Dictionary) -> void:
	if not records_panel.visible or not board_box.visible or d.get("tag", "") != _board_tag():
		return
	board_raw[d.get("period", "all")] = d
	for p in board_raw:
		for e in board_raw[p].get("entries", []):
			var pid := str(e.get("pid", ""))
			if pid != "" and not e.get("me", false):
				board_people[pid] = str(e.get("nick", ""))
	_draw_board()


## 리더보드 창 만들기 (records_panel 안). 칩·표는 _draw_board가 채운다.
func _build_board() -> void:
	var ph := _phone()
	board_box = VBoxContainer.new()
	board_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_box.offset_left = 18.0
	board_box.offset_top = 14.0
	board_box.offset_right = -18.0
	board_box.offset_bottom = -14.0
	board_box.mouse_filter = Control.MOUSE_FILTER_STOP  # 창 안 빈 곳을 눌러도 닫히지 않게 (닫기는 ✕·바깥·Esc)
	board_box.add_theme_constant_override("separation", 10)
	board_box.visible = false
	records_panel.add_child(board_box)
	# 맨 위: 제목 + 닫기
	var head := HBoxContainer.new()
	board_box.add_child(head)
	var t := Label.new()
	t.text = "리더보드"
	t.add_theme_font_size_override("font_size", 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "✕"
	close.tooltip_text = "닫기 (Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(56, 44) if ph else Vector2(40, 32)
	close.pressed.connect(_toggle_board)
	head.add_child(close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_box.add_child(body)
	# 왼쪽: 필터
	var left := VBoxContainer.new()
	board_left = left  # 폭은 _board_fit이 화면 폭에 맞춰 정한다
	left.add_theme_constant_override("separation", 12)
	if ph:
		body.add_child(_vscroll(left))  # 폰: 창을 줄이지 않고 필터·순위를 굴려 본다 (줄이면 글자가 7pt 남짓)
	else:
		body.add_child(left)
	board_chips = {}
	for g in [["map", "맵"], ["rules", "규칙"], ["kind", "기록"], ["season", "시즌"]]:
		var gl := Label.new()
		gl.text = g[1]
		gl.add_theme_font_size_override("font_size", 14)
		gl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		left.add_child(gl)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		left.add_child(flow)
		board_chips[g[0]] = flow
	var sep := VSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.4)
	body.add_child(sep)
	# 오른쪽: 기간 탭 + 순위 표
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	right.add_child(tabs)
	board_period_btns = []
	for p in [["all", "시즌 전체"], ["week", "이번 주"]]:
		var b := _board_chip(p[1], func():
			board_period = p[0]
			_draw_board())
		b.set_meta("period", p[0])
		b.custom_minimum_size.x = 130.0
		tabs.add_child(b)
		board_period_btns.append(b)
	board_period_note = Label.new()
	board_period_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_period_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board_period_note.add_theme_font_size_override("font_size", 14)
	board_period_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	tabs.add_child(board_period_note)
	right.add_child(_board_row(null))  # 열 이름
	board_rows = VBoxContainer.new()
	board_rows.add_theme_constant_override("separation", 2)
	board_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if ph:
		board_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(_vscroll(board_rows))
	else:
		right.add_child(board_rows)
	# 맨 아래: 안내 + [신고·차단] (App Store 1.2)
	var foot := HBoxContainer.new()
	board_box.add_child(foot)
	board_hint = Label.new()
	board_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_hint.add_theme_font_size_override("font_size", 14)
	board_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	foot.add_child(board_hint)
	board_ugc_btn = Button.new()
	board_ugc_btn.text = "신고·차단"
	board_ugc_btn.tooltip_text = "부적절한 닉네임을 신고하거나, 이 기기에서 그 사람 이름을 가립니다"
	board_ugc_btn.focus_mode = Control.FOCUS_NONE
	board_ugc_btn.add_theme_font_size_override("font_size", 15)
	board_ugc_btn.custom_minimum_size = Vector2(140, 44 if ph else 32)
	board_ugc_btn.pressed.connect(_board_ugc_open)
	foot.add_child(board_ugc_btn)


## 필터 칩 하나 (고른 칩은 금색 테두리·밝은 바탕)
func _board_chip(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 44 if _phone() else 32)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(on_press)
	return b


func _board_chip_on(b: Button, on: bool) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14 if not _phone() else 18)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.set_border_width_all(1)
		if on:
			sb.bg_color = Color(0.95, 0.78, 0.4, 0.22)
			sb.border_color = Color(0.95, 0.8, 0.45, 0.95)
		else:
			sb.bg_color = Color(1, 1, 1, 0.09 if st == "hover" else 0.04)
			sb.border_color = Color(1, 1, 1, 0.18)
		b.add_theme_stylebox_override(st, sb)
	var c := Color(1.0, 0.88, 0.6) if on else Color(1, 1, 1, 0.8)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, c)


## 필터 칩 다시 채우기 (시즌 목록이 늦게 오면 시즌 칩이 늘어난다)
func _board_fill_chips() -> void:
	var opts := {
		"map": Meta.MAP_IDS.map(func(id): return [id, Meta.map_name(id), Meta.MAPS[id]["desc"]]),
		"rules": Rules.IDS.map(func(r): return [r, Rules.NAMES[r], ""]),
		"kind": [["pure", "일반", "쉽게 모드 없이 한 판"], ["easy", "쉽게 모드", "쉽게 모드를 하나라도 쓴 판"]],
		"season": [[0, "이번 시즌", ""]],
	}
	var cur := "" if board_seasons.is_empty() else str(board_seasons[0].get("name", ""))
	if cur != "":
		opts["season"][0][1] = "이번 시즌 · " + cur
	for x in board_seasons.slice(1, 6):  # 지난 시즌은 최근 5개까지
		opts["season"].append([int(x.get("id", 0)), str(x.get("name", "")), ""])
	for what in board_chips:
		var flow: HFlowContainer = board_chips[what]
		var want: Array = opts[what]
		if flow.get_child_count() != want.size() or (what == "season" and flow.get_child(0).text != want[0][1]):
			for ch in flow.get_children():
				flow.remove_child(ch)
				ch.queue_free()
			for o in want:
				var b := _board_chip(o[1], _board_set.bind(what, o[0]))
				b.tooltip_text = o[2]
				b.set_meta("v", o[0])
				flow.add_child(b)
		for b: Button in flow.get_children():
			_board_chip_on(b, b.get_meta("v") == _board_value(what))


## 표 한 줄. e가 null이면 열 이름 줄, Dictionary면 순위 한 줄.
func _board_row(e: Variant) -> PanelContainer:
	var ph := _phone()
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.bg_color = Color(0, 0, 0, 0)
	var me: bool = e is Dictionary and e.get("me", false)
	if me:
		sb.bg_color = Color(0.95, 0.78, 0.4, 0.16)
		sb.border_color = Color(0.95, 0.8, 0.45, 0.6)
		sb.set_border_width_all(1)
	elif e is Dictionary and int(e.get("rank", 0)) % 2 == 1:
		sb.bg_color = Color(1, 1, 1, 0.035)
	row.add_theme_stylebox_override("panel", sb)
	row.custom_minimum_size.y = 26.0 if e == null else (32.0 if ph else 28.0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var dim := Color(1, 1, 1, 0.5)
	var fs := 14 if e == null else 16
	var cols: Array
	if e == null:
		cols = ["순위", "닉네임", "", "웨이브", "점수"]
	else:
		var tt := str(e.get("title", ""))
		var nick := str(e.get("nick", ""))
		if Meta.blocked.has(str(e.get("pid", ""))):
			nick = "(차단한 플레이어)"
		elif Meta.ACHIEVEMENTS.has(tt):
			nick += "  「%s」" % Meta.ACHIEVEMENTS[tt]["name"]
		var tag := "나" if me else ("진행 중" if not e.get("ended", true) else "")
		cols = [str(int(e.get("rank", 0))), nick, tag, str(int(e.get("wave", 0))), num(int(e.get("score", 0)))]
	var widths := [44.0, 0.0, 56.0, 60.0, 120.0] if board_narrow else [52.0, 0.0, 64.0, 70.0, 140.0]
	for i in cols.size():
		var l := Label.new()
		l.text = cols[i]
		l.add_theme_font_size_override("font_size", fs if i != 2 else 13)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = widths[i]
		if i == 1:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if i >= 2:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i >= 3 else HORIZONTAL_ALIGNMENT_CENTER
		if e == null:
			l.add_theme_color_override("font_color", dim)
		elif i == 0:
			var rk := int(e.get("rank", 0))
			l.add_theme_color_override("font_color", [Color(1.0, 0.84, 0.35), Color(0.82, 0.87, 0.95), Color(0.9, 0.62, 0.4)][rk - 1] if rk >= 1 and rk <= 3 else Color(1, 1, 1, 0.7))
		elif i == 2:
			l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5) if me else Color(0.55, 0.85, 1.0))
		elif i == 4:
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		h.add_child(l)
	return row


func _board_msg(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	l.custom_minimum_size.y = 40.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_rows.add_child(l)


func _draw_board() -> void:
	_board_fill_chips()
	if board_season != 0:
		board_period = "all"
	for b: Button in board_period_btns:
		b.visible = board_season == 0 or b.get_meta("period") == "all"
		_board_chip_on(b, b.get_meta("period") == board_period)
	board_period_btns[0].text = "시즌 전체" if board_season == 0 else _season_name(board_season) + " 전체"
	for ch in board_rows.get_children():
		board_rows.remove_child(ch)
		ch.queue_free()
	var d: Variant = board_raw.get(board_period)
	board_period_note.text = ""
	if d == null:
		_board_msg("불러오는 중…")
	elif d.has("error"):
		_board_msg(str(d["error"]))
	else:
		var es: Array = d.get("entries", [])
		var shown_me := false
		for e in es:
			shown_me = shown_me or e.get("me", false)
			board_rows.add_child(_board_row(e))
		if es.is_empty():
			_board_msg("아직 기록이 없어요")
		if int(d.get("total", 0)) > 0:
			board_period_note.text = "%d명" % int(d["total"])
		var me: Variant = d.get("me")
		if me is Dictionary and not shown_me:
			var r := _board_row({"rank": int(me["rank"]), "nick": "내 순위 (%d명 중)" % int(d.get("total", 0)), "wave": int(me.get("wave", 0)), "score": int(me["score"]), "me": true})
			if int(me.get("wave", 0)) == 0:
				(r.get_child(0).get_child(3) as Label).text = ""
			board_rows.add_child(r)
	if not Meta.online_on:
		board_hint.text = "설정에서 '기록 보내기'를 켜면 내 기록도 올라갑니다"
	elif Meta.nickname == "":
		board_hint.text = "설정에서 닉네임을 정할 수 있어요"
	else:
		board_hint.text = ""
	board_ugc_btn.visible = true


## 리더보드 창 크기: 화면 폭에 맞춰 넓게(최대 1140, 폰 1400), 높이는 순위 10줄이 들어가게. 화면보다 크면 _fit_panels가 줄인다.
func _board_fit() -> void:
	var ph := _phone()
	var w := minf(ui_root.size.x - 40.0, 1400.0 if ph else 1140.0)  # 폰은 가로로 넓게 써서 닉네임 칸을 넓힌다
	var h := 560.0 if not ph else minf(590.0, ui_root.size.y - 24.0)  # 폰: 화면 높이에 맞추고 안은 굴려 본다
	board_narrow = w < 1100.0  # 글자를 키운 PC·폰: 필터 칸과 표 열을 좁힌다
	board_left.custom_minimum_size.x = 300.0 if board_narrow else 380.0
	records_panel.offset_left = -w / 2.0
	records_panel.offset_right = w / 2.0
	records_panel.offset_top = -h / 2.0
	records_panel.offset_bottom = h / 2.0


## 맵별 최고 기록 창은 원래 크기로
func _records_fit() -> void:
	records_panel.offset_left = -430.0
	records_panel.offset_right = 430.0
	records_panel.offset_top = -325.0
	records_panel.offset_bottom = 285.0


## 지금 보이는 순위 표 글 (점검용)
func _board_text() -> String:
	var out := PackedStringArray()
	for l: Label in board_rows.find_children("*", "Label", true, false):
		out.append(l.text)
	return " ".join(out)


# ---------- 닉네임 신고·차단 (App Store 1.2) ----------

## 리더보드 [신고·차단]: 지금 창에 보이는 다른 사람 목록. 다시 누르면 닫는다.
func _board_ugc_open() -> void:
	if board_ugc_panel.visible:
		board_ugc_panel.visible = false
		return
	for ch in board_ugc_panel.get_children():
		board_ugc_panel.remove_child(ch)
		ch.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	board_ugc_panel.add_child(v)
	var t := Label.new()
	t.text = "신고·차단"
	t.add_theme_font_size_override("font_size", 20)
	v.add_child(t)
	var hint := Label.new()
	hint.text = "신고하면 운영자가 24시간 안에 확인해 이름을 지우거나 차단해요.\n차단하면 이 기기에서 그 사람 이름이 가려지고 멀티 방에서도 막혀요."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	v.add_child(hint)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(560, mini(board_people.size(), 7) * 44 + 4 if not board_people.is_empty() else 36)
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	if board_people.is_empty():
		var e := Label.new()
		e.text = "  목록에 다른 사람이 없어요"
		list.add_child(e)
	for pid in board_people:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = "(차단한 플레이어) " + str(Meta.blocked[pid]) if Meta.blocked.has(pid) else str(board_people[pid])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 17)
		row.add_child(l)
		row.add_child(_ugc_buttons(pid, str(board_people[pid]), "board", func():
			_draw_board_again()
			board_ugc_panel.visible = false
			_board_ugc_open()))
		list.add_child(row)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): board_ugc_panel.visible = false)
	v.add_child(close)
	board_ugc_panel.visible = true


## 차단을 바꾼 뒤 리더보드 줄을 다시 쓴다 (받은 응답은 그대로, 이름만 가림).
func _draw_board_again() -> void:
	for d in board_raw.values():
		_on_board_loaded(d)


## 한 사람 줄의 [신고] [차단] 버튼. pid가 없으면(예전 서버·예전 게임) 신고는 못 하고 차단만 이름으로 못 함 → 둘 다 꺼 둠.
## after: 차단을 바꾼 뒤 부름 (목록 다시 그리기).
func _ugc_buttons(pid: String, nick: String, where: String, after: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var rb := Button.new()
	rb.text = "신고"
	rb.focus_mode = Control.FOCUS_NONE
	rb.custom_minimum_size = Vector2(72, 40 if _phone() else 32)
	rb.add_theme_font_size_override("font_size", 15)
	rb.disabled = pid == "" or not Net.report_ok()
	rb.tooltip_text = "부적절한 닉네임 신고" if not rb.disabled else "지금은 신고할 수 없어요 (온라인 연결 필요)"
	rb.pressed.connect(func():
		rb.disabled = true
		rb.text = "보내는 중"
		var code := await net.report(pid, nick, where)
		if not is_instance_valid(rb):
			return
		if code == 200:
			rb.text = "신고함"
			_show_toast("신고했어요. 운영자가 24시간 안에 확인해요")
		else:
			rb.text = "신고"
			rb.disabled = false
			_show_toast("신고를 보내지 못했어요. 잠시 뒤 다시 눌러 주세요"))
	box.add_child(rb)
	var bb := Button.new()
	var on := Meta.blocked.has(pid)
	bb.text = "차단 풀기" if on else "차단"
	bb.focus_mode = Control.FOCUS_NONE
	bb.custom_minimum_size = Vector2(90, 40 if _phone() else 32)
	bb.add_theme_font_size_override("font_size", 15)
	bb.disabled = pid == ""
	bb.tooltip_text = "이 기기에서 이 사람 이름을 가리고 멀티 방에서 막아요"
	bb.pressed.connect(func():
		if Meta.blocked.has(pid):
			Meta.blocked.erase(pid)
			_show_toast("차단을 풀었어요")
		else:
			Meta.blocked[pid] = nick.left(16)
			_show_toast("차단했어요. 이 기기에서 이름이 가려져요")
		_save_best()
		after.call())
	box.add_child(bb)
	return box


# ---------- 패치노트 ----------

## 버전별 패치노트 창: 길어서 굴려 보는 창. 바깥을 누르거나 Esc·N으로 닫는다.
func _build_notes(root: Control) -> void:
	notes_panel = PanelContainer.new()
	notes_panel.z_index = 22  # 일시정지 어둠(z 20) 위에
	notes_panel.set_anchors_preset(Control.PRESET_CENTER)
	notes_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	notes_panel.offset_left = -430.0
	notes_panel.offset_right = 430.0
	notes_panel.offset_top = -300.0
	notes_panel.offset_bottom = 270.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_content_margin_all(18)
	sb.set_corner_radius_all(6)
	notes_panel.add_theme_stylebox_override("panel", sb)
	notes_panel.visible = false
	root.add_child(notes_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	notes_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "패치노트"
	t.add_theme_font_size_override("font_size", 22)
	head.add_child(t)
	notes_status = Label.new()
	notes_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notes_status.add_theme_font_size_override("font_size", 13)
	notes_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	head.add_child(notes_status)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	notes_text = RichTextLabel.new()
	notes_text.bbcode_enabled = true
	notes_text.fit_content = true
	notes_text.scroll_active = false
	notes_text.mouse_filter = Control.MOUSE_FILTER_PASS  # 터치로 끌면 위의 ScrollContainer가 굴린다
	notes_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_text.add_theme_font_size_override("normal_font_size", 15)
	notes_text.add_theme_font_size_override("bold_font_size", 15)
	notes_text.add_theme_constant_override("line_separation", 3)
	notes_text.add_theme_constant_override("paragraph_separation", 8)
	notes_text.meta_underlined = false
	notes_text.meta_clicked.connect(_on_notes_meta)
	sc.add_child(notes_text)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(_close_notes)
	v.add_child(close)


func _toggle_notes() -> void:
	if notes_panel.visible:
		_close_notes()
		return
	notes_panel.visible = true
	notes_back = settings_panel.visible
	settings_panel.visible = false
	records_panel.visible = false
	help_label.visible = false
	if Meta.notes_seen != Net.game_version():
		Meta.notes_seen = Net.game_version()
		_save_best()
		_refresh_notes_btn()
	_draw_notes()
	(notes_text.get_parent() as ScrollContainer).scroll_vertical = 0
	notes.fetch()


func _close_notes() -> void:
	notes_panel.visible = false
	if notes_back:
		settings_panel.visible = true
	notes_back = false


func _kr_keep(t: String) -> String:
	return PatchNotes.kr_keep(t)

func _draw_notes() -> void:
	if notes_panel == null or not notes_panel.visible:
		return
	var cur := Net.game_version()
	var cur_t := PatchNotes.vtuple(cur)
	var out := PackedStringArray()
	# 서버가 알려 준 새 버전 (스토어·다운로드 주소가 있는 것)
	var latest: Variant = Net.info.get("latest")
	if latest is Dictionary and str(latest.get("version", "")) != "":
		var ln := str(latest.get("notes", ""))
		out.append("[color=#ffd873]새 버전 v%s가 나왔어요. 시작 화면의 [받기]로 받을 수 있어요.%s[/color]\n" % [_bb(str(latest["version"])), ("\n" + _bb(ln)) if ln != "" else ""])
	# 색 안내: 줄 앞 꼬리표가 무슨 뜻인지
	var legend := PackedStringArray()
	for k in NOTE_KINDS:
		legend.append(_note_chip(k))
	out.append("[font_size=13][color=#8a93a0]%s[/color][/font_size]" % "  ".join(legend))
	var list := PatchNotes.notes()
	var older := false
	var first := true  # 지금 버전이 목록에 없으면 맨 위 버전을 펼친다
	for i in range(list.size() - 1, -1, -1):
		var n: Dictionary = list[i]
		var v: String = n["v"]
		var items := _note_items(n["lines"])
		if v == "":
			if not older:
				older = true
				out.append("[color=#8899aa][b]v0.4 이전 기록[/b][/color]")
			out.append("[b]%s[/b]" % _bb(n["title"]))
		else:
			var tag := ""
			var newer := PatchNotes.vtuple(v) > cur_t
			if v == cur:
				tag = "  [bgcolor=#2e5a34][color=#bff0bf] 지금 버전 [/color][/bgcolor]"
			elif newer:
				tag = "  [bgcolor=#5a4a1c][color=#ffe08a] 새 버전 [/color][/bgcolor]"
			if not notes_open.has(v):
				notes_open[v] = v == cur or newer or (first and not PatchNotes.has_version(cur))
			var open: bool = notes_open[v]
			# 종류별 수: 접어 두어도 무엇이 얼마나 바뀌었는지 보이게
			var cnt := {}
			for it in items:
				cnt[it[2]] = cnt.get(it[2], 0) + 1
			var sums := PackedStringArray()
			for k in NOTE_KINDS:
				if cnt.has(k):
					sums.append("[color=%s]%s %d[/color]" % [NOTE_KINDS[k][1], NOTE_KINDS[k][0], cnt[k]])
			out.append("[url=v%s][bgcolor=#1b2230][b][font_size=19] %s v%s [/font_size][/b]  [color=#e8ecf2]%s[/color][/bgcolor][/url]%s" % [v, "▾" if open else "▸", v, _bb(n["title"]), tag])
			out.append("[font_size=13]   %s%s[/font_size]" % ["  ·  ".join(sums), "" if open else "   [color=#6f7a88](눌러서 펼치기)[/color]"])
			first = false
			if not open:
				out.append("")
				continue
		# 한 버전의 줄은 목록 하나에 (목록을 줄마다 열고 닫으면 빈 줄이 껴서 듬성듬성). 줄 사이는 paragraph_separation
		var rows := PackedStringArray()
		for it in items:
			var subs: Array = it[1]
			var row := "%s %s" % [_note_chip(it[2]), it[0]]
			if not subs.is_empty():
				var ss := PackedStringArray()
				for sub: String in subs:
					ss.append(_note_sub(sub))
				row += "\n[ul bullet=◦][font_size=14]%s[/font_size][/ul]" % "\n".join(ss)
			rows.append(row)
		if not rows.is_empty():
			out.append("[ul bullet= ]%s[/ul]" % "\n".join(rows))
		out.append("")
	notes_text.text = _kr_keep("\n".join(out))
	match PatchNotes.source:
		"online":
			notes_status.text = "최신 (인터넷)"
		"cache":
			notes_status.text = "불러오는 중…" if PatchNotes.fetching else "지난번에 받은 노트"
		_:
			notes_status.text = "불러오는 중…" if PatchNotes.fetching else "이 빌드에 든 노트"


## 패치노트 줄 종류: [꼬리표, 글자색, 바탕색]. 위에서부터 먼저 맞는 것
const NOTE_KINDS := {
	"fix": ["고침", "#ff9a8a", "#4a2422"],
	"new": ["새로움", "#8fe39a", "#1f4026"],
	"tune": ["조정", "#ffc46b", "#4a3a1a"],
	"ui": ["화면", "#8cc8ff", "#1d3550"],
	"etc": ["바뀜", "#c0c6d0", "#2a3038"],
}
static var _re_fix := RegEx.create_from_string("버그|고침|고친|고쳤|안 되던|안 잡히던|오류")
static var _re_new := RegEx.create_from_string("새 |새로운|추가|정식|생김|생겨|\\d+개 → \\d+개|기록|수집|보상|업적|멀티플레이")
static var _re_tune := RegEx.create_from_string("조정|→|하향|상향|너프|버프|배율|보정|덜 오르|줄임|늘림|개편|바꿈|x\\d")
static var _re_ui := RegEx.create_from_string("화면|폰|터치|버튼|창|글자|그림|말풍선|카드 설명|표시")
static var _re_arrow := RegEx.create_from_string("([^\\s\\[\\]()]*\\d[^\\s\\[\\]()]*) → ([^\\s\\[\\](),]*\\d[^\\s\\[\\](),]*)")
static var _re_quote := RegEx.create_from_string("\"([^\"\\[\\]]+)\"")
static var _re_aside := RegEx.create_from_string(" ?\\((사용자|제보|측정)[^()]*(\\([^()]*\\)[^()]*)*\\)")


func _note_kind(t: String) -> String:
	var head := t.split(":")[0]
	if _re_fix.search(head):
		return "fix"
	if _re_new.search(head):
		return "new"
	if _re_tune.search(head):
		return "tune"
	if _re_ui.search(head):
		return "ui"
	return "etc"


func _note_chip(k: String) -> String:
	var d: Array = NOTE_KINDS[k]
	return "[bgcolor=%s][color=%s][font_size=12] %s [/font_size][/color][/bgcolor]" % [d[2], d[1], d[0]]


## 노트 줄 → [[머리 글, [들여 쓴 줄...], 종류]]
func _note_items(lines: Array) -> Array:
	var items: Array = []
	for l: String in lines:
		var s := l.strip_edges()
		if s.begins_with("- "):
			s = s.substr(2)
		if l.begins_with(" ") and not items.is_empty():
			items[-1][1].append(s)
		else:
			items.append([_note_head(s), [], _note_kind(s)])
	return items


## 숫자 바뀜(A → B)은 옛 값 흐리게·새 값 밝게, "이름"은 금색
func _note_marks(t: String) -> String:
	t = _re_arrow.sub(_bb(t), "[color=#7d8694]$1[/color] → [b][color=#ffe08a]$2[/color][/b]", true)
	return _re_quote.sub(t, "[color=#ffd873]\"$1\"[/color]", true)


## 윗줄: "제목: 설명"이면 제목은 굵고 밝게, 설명은 보통. (사용자 선택 …)·(제보 …)는 작고 흐리게
func _note_head(s: String) -> String:
	var asides := PackedStringArray()
	for m in _re_aside.search_all(s):
		asides.append(m.get_string().strip_edges())
	s = _re_aside.sub(s, "", true)
	var cut := _colon_at(s)
	var aside := ""
	if not asides.is_empty():
		aside = " [font_size=12][color=#6f7a88]%s[/color][/font_size]" % _bb(" ".join(asides))
	if cut < 0:
		return "[color=#e8ecf2]%s[/color]%s" % [_note_marks(s), aside]
	# 설명은 다음 줄로 (제목만 훑어 읽기 쉽게)
	return "[b][color=#ffffff]%s[/color][/b]%s\n[color=#c3c9d2]%s[/color]" % [_note_marks(s.substr(0, cut)), aside, _note_marks(s.substr(cut + 1).strip_edges())]


## 들여 쓴 줄: 조금 흐리게, "측정"·봇 줄은 더 흐리게
func _note_sub(s: String) -> String:
	var dim := s.begins_with("측정") or s.begins_with("봇") or s.begins_with("자동 플레이")
	var cut := _colon_at(s)
	var c := "#8a93a0" if dim else "#b4bbc5"
	if cut >= 0 and cut < 40:
		return "[color=%s][b]%s[/b]:%s[/color]" % [c, _note_marks(s.substr(0, cut)), _note_marks(s.substr(cut + 1))]
	return "[color=%s]%s[/color]" % [c, _note_marks(s)]


## 괄호 밖 첫 ": " 자리 (없으면 -1)
static func _colon_at(s: String) -> int:
	var depth := 0
	for i in s.length():
		var ch := s[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
		elif ch == ":" and depth == 0 and i + 1 < s.length() and s[i + 1] == " ":
			return i
	return -1


func _on_notes_meta(meta: Variant) -> void:
	var m := str(meta)
	if m.begins_with("v"):
		var v := m.substr(1)
		notes_open[v] = not notes_open.get(v, false)
		var sc := notes_text.get_parent() as ScrollContainer
		var y := sc.scroll_vertical
		_draw_notes()
		sc.set_deferred("scroll_vertical", y)


## RichTextLabel에 그대로 보이게 [ 를 바꾼다 (노트의 "[받기]" 같은 글자가 태그로 읽히지 않게).
static func _bb(t: String) -> String:
	return t.replace("[", "[lb]")


## 시작 화면 [패치노트] 버튼: 이 버전 노트를 아직 안 봤으면 강조.
func _refresh_notes_btn() -> void:
	if notes_btn == null:
		return
	var cur := Net.game_version()
	var fresh := Meta.notes_seen != cur and PatchNotes.has_version(cur)
	notes_btn.text = "패치노트 · v%s%s" % [cur, " 새로 바뀐 것" if fresh else ""]
	notes_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.45) if fresh else Color(1, 1, 1, 0.8))


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	if account_label:
		account_label.text = Account.label()


# ---------- 모드 ----------

## 모드 창: 어렵게·쉽게 두 묶음. 누르면 켜고 끄며, 반대 모드는 저절로 꺼진다. 효과는 버튼에 바로 적는다 (터치는 마우스 올리기가 없음).
func _build_modes(root: Control, sb: StyleBox) -> void:
	modes_panel = PanelContainer.new()
	modes_panel.set_anchors_preset(Control.PRESET_CENTER)
	modes_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	modes_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	modes_panel.add_theme_stylebox_override("panel", sb.duplicate())
	modes_panel.visible = false
	root.add_child(modes_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	modes_panel.add_child(v)
	var t := Label.new()
	t.text = "모드 (시험)   (Esc: 닫기)"
	t.add_to_group("key_hint")
	t.add_theme_font_size_override("font_size", 22)
	v.add_child(t)
	modes_head = Label.new()
	modes_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modes_head.custom_minimum_size = Vector2(620, 0)
	modes_head.add_theme_font_size_override("font_size", 16)
	v.add_child(modes_head)
	_build_easy_notice(v)
	for hard in [true, false]:
		var l := Label.new()
		l.text = "어렵게 (점수 올라감)" if hard else "쉽게 (점수 내려감 · 쉽게 모드 리더보드 · 최고 기록 따로)"
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", Color(1, 0.65, 0.5) if hard else Color(0.6, 0.85, 1.0))
		v.add_child(l)
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 6)
		v.add_child(g)
		for id in Modes.ORDER:
			if Modes.LIST[id]["hard"] != hard:
				continue
			var b := Button.new()
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(306, 54)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 15)
			b.add_theme_color_override("font_pressed_color", Color(1, 0.88, 0.45))
			b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.88, 0.45))
			b.pressed.connect(func(): _toggle_mode(id))
			g.add_child(b)
			modes_btns[id] = b
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for spec in [["모두 끄기", _modes_off], ["닫기", _toggle_modes]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(spec[1])
		row.add_child(b)
	_phone_scroll(modes_panel)


func _toggle_modes() -> void:
	modes_panel.visible = not modes_panel.visible
	if modes_panel.visible:
		_refresh_modes()


func _modes_off() -> void:
	Modes.on.clear()
	_modes_changed()


func _toggle_mode(id: String) -> void:
	var was_easy := Modes.easy()
	Modes.toggle(id)
	_modes_changed()
	if Modes.easy() and not was_easy and not _easy_notice_off():
		easy_notice_skip.button_pressed = false
		easy_notice.visible = true


const EASY_NOTICE_KEY := "easy_board"  # user://device.cfg [notice]: 다시 보지 않기 (기기마다)


## 쉽게 모드 안내 상자: 모드 창 맨 위에 뜬다 (판 시작은 막지 않음).
func _build_easy_notice(v: VBoxContainer) -> void:
	easy_notice = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.16, 0.26, 0.97)
	sb.border_color = Color(0.6, 0.85, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	easy_notice.add_theme_stylebox_override("panel", sb)
	easy_notice.visible = false
	v.add_child(easy_notice)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	easy_notice.add_child(box)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	l.add_theme_font_size_override("font_size", 17)
	l.text = _kr_keep("쉽게 모드를 켰어요\n쉽게 모드를 하나라도 켠 판은 일반 리더보드에 오르지 않고 \"쉽게 모드\" 리더보드에만 올라가요. 어렵게 모드와 함께 켜도 같아요. 최고 기록도 따로 세요.")
	box.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	easy_notice_skip = CheckBox.new()
	easy_notice_skip.text = "다시 보지 않기"
	easy_notice_skip.add_theme_font_size_override("font_size", 16)
	easy_notice_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(easy_notice_skip)
	var ok_btn := Button.new()
	ok_btn.text = "확인"
	ok_btn.custom_minimum_size = Vector2(120, 44)
	ok_btn.pressed.connect(_close_easy_notice)
	row.add_child(ok_btn)


func _close_easy_notice() -> void:
	if easy_notice_skip.button_pressed:
		var cfg := ConfigFile.new()
		cfg.load(Tutorial.PATH)
		cfg.set_value("notice", EASY_NOTICE_KEY, true)
		cfg.save(Tutorial.PATH)
	easy_notice.visible = false


func _easy_notice_off() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(Tutorial.PATH) == OK and cfg.get_value("notice", EASY_NOTICE_KEY, false) == true


## 고른 모드를 저장하고 규칙·기록 표시를 다시 맞춘다 (시작 화면에서만 바뀐다).
func _modes_changed() -> void:
	Meta.modes = Array(Modes.on)
	if not Modes.easy():
		easy_notice.visible = false
	_apply_rules()
	sfx.play("place")
	_refresh_menu()
	_save_best()
	_refresh_modes()


func _refresh_modes() -> void:
	for id in modes_btns:
		var b: Button = modes_btns[id]
		var d: Dictionary = Modes.LIST[id]
		b.set_pressed_no_signal(Modes.has(id))
		b.text = "%s %s  %s\n   %s" % ["●" if Modes.has(id) else "○", d["name"], Modes.pct(Modes.score_of(id)), d["desc"]]
	var head := "점수 x%.2f (%s)" % [Modes.mul(), Modes.pct(Modes.mul())] if not Modes.on.is_empty() else "고른 모드 없음"
	if Modes.easy():
		head += " · 쉽게 모드: 쉽게 모드 리더보드, 최고 기록 따로"
	else:
		head += " · 여러 개를 고르면 배율을 곱해요 (x%.1f~x%.1f)" % [Modes.MUL_MIN, Modes.MUL_MAX]
	modes_head.text = _kr_keep(head)


func _toggle_fullscreen() -> void:
	if OS.has_feature("mobile"):
		return
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Meta.volume, 0.001)))


## 업적 달성 처리: 배너와 소리, 해금 안내.
func _achieve(id: String) -> void:
	if TutPlay.on:
		return  # 연습 판은 업적이 없다
	if mp_mode != "" and not Ach.is_mp(id):
		return  # 멀티 판은 멀티 업적만
	if not Meta.achieve(id):
		return
	_tut_event("ach")
	var a: Dictionary = Meta.ACHIEVEMENTS[id]
	new_achievements.append(a["name"])
	big_banner("업적: " + a["name"], Color(1, 0.85, 0.4))
	sfx.play("reaction", 0.0)
	for sk in Meta.TOWER_SKIN_IDS:
		if Meta.TOWER_SKINS[sk]["need"] == id:
			_show_toast("오브젝트 모양 '%s' 해금 (메뉴에서 선택)" % Meta.TOWER_SKINS[sk]["name"])
	for sk in Meta.CORE_SKIN_IDS:
		if Meta.CORE_SKINS[sk]["need"] == id:
			_show_toast("중앙 모양 '%s' 해금 (메뉴에서 선택)" % Meta.CORE_SKINS[sk]["name"])
	_save_best()


## 조건을 넘긴 업적을 준다 (Ach.LIST).
func _ach_check() -> void:
	for id in Ach.newly_met():
		_achieve(id)


## 이전 기록·다른 기기 진행으로 이미 넘긴 업적은 배너 없이 한꺼번에 (불러올 때·진행 맞춘 뒤).
func _ach_catch_up() -> void:
	var got := Ach.newly_met()
	if got.is_empty():
		return
	for id in got:
		Meta.achieve(id)
	if is_inside_tree() and hint:
		_show_toast("업적 %d개 달성: %s" % [got.size(), ", ".join(got.map(func(id): return Meta.ACHIEVEMENTS[id]["name"]))])


## 설치 후 확인하는 업적·도감.
func _check_progress() -> void:
	var pincers := 0
	for t in towers.get_children():
		pincers += 1 if t.pincer > 0 else 0
		if t.order.size() >= 5:
			_achieve("stack5")
		var rs: Array = t.reactions()
		Ach.on_reactions(rs.map(func(r): return r["id"]))
		for r in rs:
			if mp_mode == "" and not TutPlay.on and Meta.discover(r["id"]):
				if rx_card.active():
					rx_card.found[r["id"]] = true  # 카드 머리에 "도감 +" 표시
				else:
					_show_toast("조합 도감에 추가: " + r["name"])
				_save_best()
				_refresh_legend()
				_guide("react", "")
	if pincers >= 3:
		_achieve("links3")
	_ach_check()


func _close_title() -> void:
	if continue_btn.visible and new_armed <= 0.0:
		new_armed = 2.5
		new_btn.text = "정말 새로 시작?"
		return
	_clear_run()
	_hide_title()
	lanes.clear()
	_start_choose()


func _hide_title() -> void:
	title_label.visible = false
	help_label.visible = false
	records_panel.visible = false
	settings_panel.visible = false
	notes_panel.visible = false
	codex_panel.visible = false
	if vote_panel.visible:
		vote_panel.hide_panel()
	remote_btn.visible = false
	title_seen = true


# ---------- 이어하기 ----------

## 쉬는 시간마다 판을 저장한다. 웨이브 중에 끄면 그 웨이브 앞 쉬는 시간부터 이어진다.
func _save_run() -> void:
	if mp_mode != "" or TutPlay.on:
		return  # 멀티플레이 판·연습 판은 이어하기가 없다
	if title_label.visible or not phase in [Phase.CHOOSE, Phase.READY] or press_t or dragging or coin_stage > 0:
		return
	var ts := towers.get_children()
	var list: Array = []
	for t in ts:
		list.append(t.to_save())
	var vals := {
		"format": RUN_FORMAT, "version": ProjectSettings.get_setting("application/config/version", ""),
		"map": Meta.map_id, "line_flip": Meta.line_flip, "rules": Meta.rules, "modes": Array(Modes.on), "wave": wave, "score": score, "kills": kills, "best_combo": best_combo,
		"combo": combo, "combo_t": combo_t, "combo_bonus": combo_bonus,
		"core_hp": core_hp, "core_max": core_max, "perks": perks.keys().map(func(k): return [k, perks[k]]), "regen_acc": regen_acc, "shield_keep": shield_keep, "orb_speed_mul": orb_speed_mul,
		"dmg_mul": Tower.dmg_mul, "spd_mul": Tower.spd_mul, "reach_mul": Tower.reach_mul, "tax_step": Tower.tax_step,
		"rerolls_left": rerolls_left, "bonus_rerolls": bonus_rerolls, "picks_left": picks_left,
		"vary": Vary.save(), "skip_left": skip_left, "skip_total": skip_total, "skip_stop": skip_stop, "bank_picks": bank_picks, "bank_rerolls": bank_rerolls, "bank_perks": bank_perks, "perk_rerolls": perk_rerolls, "coin_next": coin_next, "rest_ready": rest_ready,
		"lanes": Array(lanes), "wave_resist": wave_resist, "boss": boss_plan, "achievements": new_achievements, "ach_run": Ach.run,
		"state": "perk" if perk_mode else ("ready" if phase == Phase.READY else "choose"),
		"offer": offer, "perk_offer": perk_offer.map(func(pk): return pk["id"]), "towers": list,
		"log": run_log, "leaks": leak_log, "game_secs": run_game, "real_secs": run_real, "run_id": run_id,
		"tutor": tutor, "tutor_given": tutor_given.keys(), "grow": legacy_grow, "skill_set": skill_set, "skill_used": skill_used, "ley": ley.map(func(p): return [p.x, p.y]),
	}
	var cfg := ConfigFile.new()
	for k in vals:
		cfg.set_value("run", k, vals[k])
	cfg.save(RUN_PATH)
	if run_id != moved_run:
		# 같은 계정의 다른 기기에서 이어 할 수 있게 서버에도 (쉬는 시간마다, 끄면 마지막 것)
		net.put_run(run_id, cfg.encode_to_text(), {"game": Net.game_version(), "platform": Net.platform(), "map": Meta.map_id,
			"rules": Meta.rules, "wave": wave, "score": score})


## drop: 서버의 같은 판도 지운다 (다른 기기가 가져가서 지우는 것이면 false).
func _clear_run(drop := true) -> void:
	if FileAccess.file_exists(RUN_PATH):
		var key := _local_run_key()
		DirAccess.remove_absolute(RUN_PATH)
		if drop and key != "" and key != moved_run:
			net.drop_run(key)


## 저장된 판 요약 {wave, map, rules, cfg} (없거나 형식이 다르면 빈 사전).
func _run_info(path := "") -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path if path != "" else RUN_PATH) != OK or Meta.val(cfg, "run", "format", 0) != RUN_FORMAT:
		return {}
	var map: String = Meta.val(cfg, "run", "map", "")
	var r: int = Meta.val(cfg, "run", "rules", 0)
	if not map in Meta.MAP_IDS or not r in Rules.OLD_IDS:
		return {}
	if not r in Rules.IDS:
		r = 1  # 고를 수 없게 된 버전(2·4)과 폐기한 5로 저장된 판은 버전 1로 이어 한다
	return {"wave": maxi(0, Meta.val(cfg, "run", "wave", 0)), "map": map, "rules": r, "cfg": cfg}


## 시작 화면의 이어하기 버튼: 저장된 판이 있으면 그 판의 웨이브·맵·규칙을 보여 준다.
func _refresh_continue() -> void:
	var info := _run_info()
	continue_btn.visible = not info.is_empty()
	if continue_btn.visible:
		remote_btn.visible = false
	new_armed = 0.0
	new_btn.text = "새로 시작" if continue_btn.visible else "시작"
	if continue_btn.visible:
		_tut_event("continue")
		continue_info.text = "웨이브 %d부터 · %s · %s" % [info["wave"] + 1, Meta.MAPS[info["map"]]["name"], Rules.NAMES[info["rules"]]]
		var n := 2 if mp_btn.visible else 1  # 이어하기 폭 = 타일 줄 폭 (일반 판·멀티)
		continue_btn.custom_minimum_size.x = n * _tile_w() + 16 * (n - 1)
	get_tree().call_group("keycap", "queue_redraw")  # [일반 판] 타일의 Enter 표시는 이어하기가 있으면 뺀다


## 저장된 선택지 카드가 지금 판에서도 쓸 수 있는 형식인지.
func _valid_card(cd: Variant) -> bool:
	if not cd is Dictionary:
		return false
	match cd.get("type"):
		"elem": return cd.get("e") in Elem.ALL and cd.get("lv") is int
		"pat": return cd.get("id") in Pat.ALL_IDS
		"mod": return Pat.MODS.has(cd.get("id"))
		"link": return Pat.LINKS.has(cd.get("id"))
		"trig": return Pat.TRIGS.has(cd.get("id"))
		"cata": return false  # 예전 저장된 대격변 선택지 복원 방지
	return false


## 시작 화면 [이어하기]: 저장된 쉬는 시간으로 돌아간다.
func _continue_run() -> void:
	var info := _run_info()
	if info.is_empty():
		_clear_run()
		_refresh_continue()
		return
	var cfg: ConfigFile = info["cfg"]
	var g := func(k: String, d: Variant) -> Variant: return Meta.val(cfg, "run", k, d)
	Meta.map_id = info["map"]
	Meta.line_flip = g.call("line_flip", Meta.line_flip)
	Meta.rules = info["rules"]
	Modes.set_on(g.call("modes", []))  # 그 판을 시작할 때 고른 모드 (시작 화면에서 지금 고른 것과 달라도)
	legacy_grow = g.call("grow", false) == true
	_apply_rules()

	_refresh_menu()
	_save_best()
	_hide_title()
	wave = info["wave"]
	score = maxi(0, g.call("score", 0))
	kills = maxi(0, g.call("kills", 0))
	best_combo = maxi(0, g.call("best_combo", 0))
	combo = clampi(g.call("combo", 0), 0, best_combo)
	combo_t = clampf(g.call("combo_t", 0.0), 0.0, COMBO_KEEP) if combo > 0 else 0.0
	combo_bonus = maxi(0, g.call("combo_bonus", 0))
	combo_hold = combo_t > 0.0
	core_max = maxi(1, g.call("core_max", CORE_MAX_HP))
	core_hp = clampi(g.call("core_hp", core_max), 1, core_max)
	danger_lv = _danger_of(core_hp)
	core_disp = float(core_hp)
	# 특성은 고른 순서대로 [id, 횟수] 목록 (사전으로 저장하면 이름순으로 바뀌어 점수 줄 순서가 달라짐)
	perks = {}
	var pk_saved: Variant = cfg.get_value("run", "perks", [])
	var pairs: Array = []
	if pk_saved is Array:
		pairs = pk_saved
	elif pk_saved is Dictionary:  # v0.4.21~24 저장
		pairs = pk_saved.keys().map(func(k): return [k, pk_saved[k]])
	for pr in pairs:
		if pr is Array and pr.size() == 2 and PERKS.any(func(pk): return pk["id"] == pr[0]) and pr[1] is int and pr[1] > 0:
			perks[pr[0]] = pr[1]
	regen_acc = clampf(float(g.call("regen_acc", 0.0)), 0.0, 0.999)
	shield_keep = clampi(int(g.call("shield_keep", 0)), 0, 4)
	orb_speed_mul = clampf(g.call("orb_speed_mul", 1.0), 0.05, 1.0)
	Tower.dmg_mul = maxf(1.0, g.call("dmg_mul", 1.0))
	Tower.spd_mul = maxf(1.0, g.call("spd_mul", 1.0))
	Tower.reach_mul = maxf(1.0, g.call("reach_mul", 1.0))
	Tower.tax_step = clampf(g.call("tax_step", Rules.tax_step), 0.0, Rules.tax_step)
	rerolls_left = maxi(0, g.call("rerolls_left", 1))
	bonus_rerolls = maxi(0, g.call("bonus_rerolls", 0))
	picks_left = maxi(0, g.call("picks_left", 1))  # 특성 고르기 중에는 0
	skip_left = maxi(0, int(g.call("skip_left", 0)))
	skip_total = maxi(skip_left, int(g.call("skip_total", 0)))
	skip_stop = g.call("skip_stop", false) == true
	bank_picks = (g.call("bank_picks", []) as Array).filter(func(x): return x is int).map(func(x): return clampi(x, 0, wave))
	bank_rerolls = maxi(0, int(g.call("bank_rerolls", 0)))
	perk_rerolls = clampi(int(g.call("perk_rerolls", 1)), 0, 1)
	bank_perks = maxi(0, int(g.call("bank_perks", 0)))
	coin_next = str(g.call("coin_next", ""))
	if not coin_next in ["double", "reroll"]:
		coin_next = ""
	rest_ready = g.call("rest_ready", false) == true
	lanes.assign((g.call("lanes", []) as Array).filter(func(a): return a is float))
	if lanes.is_empty():
		_roll_lanes()
	wave_resist = g.call("wave_resist", -1)
	if not wave_resist in Elem.ALL:
		wave_resist = -1
	Vary.load_from(g.call("vary", {}))
	_skills_new_run(int(g.call("skill_set", 0)))
	ley = []
	if leys_on():
		for q in g.call("ley", []):
			if q is Array and q.size() == 2 and (q[0] is float or q[0] is int) and (q[1] is float or q[1] is int):
				ley.append(Vector2(q[0], q[1]).clamp(field_rect().position, field_rect().end))
	skill_used = maxi(0, int(g.call("skill_used", 0)))
	# 미리 뽑아 둔 보스 (없거나 형식이 다르면 새로 뽑음)
	var bp: Variant = g.call("boss", {})
	boss_plan = {}
	if bp is Dictionary and bp.get("wave") is int and bp["wave"] == wave + 1 and bp.get("a") is float and bp.get("hp") is float and bp.get("spd") is float and bp.get("resist") is int and bp.get("sturdy") is bool:
		boss_plan = {"wave": bp["wave"], "a": bp["a"], "hp": maxf(1.0, bp["hp"]), "spd": maxf(1.0, bp["spd"]), "resist": bp["resist"] if bp["resist"] in Elem.ALL else -1, "sturdy": bp["sturdy"], "y": clampf(float(bp.get("y", 0.0)), -LINE_HALF, LINE_HALF)}
	else:
		_plan_boss()
	new_achievements = (g.call("achievements", []) as Array).filter(func(a): return a is String)
	Ach.load_run(cfg.get_value("run", "ach_run", {}))
	run_log = (g.call("log", []) as Array).filter(func(e): return e is Dictionary)
	leak_log = (g.call("leaks", []) as Array).filter(func(e): return e is Dictionary and e.has("w") and e.has("n") and e.has("dmg") and e.has("kinds"))
	run_game = maxf(0.0, g.call("game_secs", 0.0))
	run_real = maxf(0.0, g.call("real_secs", 0.0))
	run_id = str(g.call("run_id", ""))
	if run_id == "":
		run_id = _new_run_id()  # 판 번호가 없던 예전 저장
	tutor = g.call("tutor", false)
	tutor_given = {}
	for k in g.call("tutor_given", []):
		if k in TUTOR_OPEN:
			tutor_given[k] = true
	# 오브젝트: 연결선은 저장 순서 번호로 다시 잇는다 (못 읽은 것은 null로 자리만 지킴)
	var raw: Array = g.call("towers", [])
	var made: Array = []
	for d in raw:
		var t: Tower = null
		if d is Dictionary:
			t = Tower.new()
			t.main = self
			t.load_save(d)
			var fr := field_rect()
			t.position = t.position.clamp(fr.position, fr.end)  # 손으로 고친 저장에서 화면 밖 위치
			if t.order.is_empty():
				t.free()
				t = null
			else:
				towers.add_child(t)
		made.append(t)
	# 예전 저장의 연결선("links")은 없어진 카드라 읽지 않는다
	for t in towers.get_children():
		t.eff = t.eff_now()
	_refresh_build()
	match g.call("state", "choose"):
		"perk":
			perk_offer = []
			for id in g.call("perk_offer", []):
				for pk in PERKS:
					if pk["id"] == id and _card_enabled({"type": "perk", "id": id}):
						perk_offer.append(pk)
			if perk_offer.is_empty():
				_start_perk()
			else:
				_show_perks()
		"ready":
			_clear_shots()
			_update_preview()
			_enter_ready()
			if skip_left > 0:
				countdown = 1.0  # 넘기는 중에 껐다: 이어서 넘긴다
		_:
			picks_left = maxi(1, picks_left)
			offer = (g.call("offer", []) as Array).filter(_valid_card)
			if offer.is_empty():
				_make_choices()
			else:
				_show_offer()
			_open_choose()
	if old_run_ver == "":
		_show_toast("웨이브 %d 앞 쉬는 시간부터 이어서 합니다" % (wave + 1))


## 저장된 판이 지난 마이너 버전(x.Y)에서 저장됐으면 그 버전 (마이너가 같거나 저장이 없으면 "").
## 패치(x.y.Z)만 바뀐 판은 그대로 이어 한다.
func _old_run_version() -> String:
	var info := _run_info()
	if info.is_empty():
		return ""
	var v := str(Meta.val(info["cfg"], "run", "version", ""))
	if Net.same_minor(v, Net.game_version()):
		return ""
	return v if v != "" else "?"


## 마이너 버전이 바뀌면 지난 버전의 판은 이어 하지 않는다: 그 판을 불러와 지금 점수로 끝낸다
## (판 끝내기와 같이 기록 저장·온라인 전송, 저장은 지움). 결과를 보여 주고 클릭하면 시작 화면.
func _end_old_run(v: String) -> void:
	old_run_ver = v
	_continue_run()
	perk_mode = false
	ended = true
	_game_over()
	over_label.text = _kr_keep("v%s에서 하던 판은 새 버전(v%s)에서 이어 할 수 없어 지금 점수로 끝냈어요\n" % [v, Net.game_version()]) + over_label.text


## 공격방식·강화·연계 카드를 오브젝트에 넣는다.
func _apply_card(target: Tower) -> void:
	if target == null:
		_show_toast("오브젝트 위에 놓으세요")
		return
	if not _mine(target):
		_show_toast("친구가 놓은 오브젝트에는 넣을 수 없어요")
		return
	var msg := ""
	match picked["type"]:
		"pat":
			if not target.can_take(picked):
				_show_toast(target.refuse_text(picked))
				return
			msg = target.set_pattern(picked["id"])
		"mod":
			if not target.can_take(picked):
				_show_toast(target.refuse_text(picked))
				return
			msg = target.add_mod(picked["id"])
		"link":
			msg = target.add_link(picked["id"])
		"trig":
			if not target.can_take(picked):
				_show_toast(target.refuse_text(picked))
				return
			msg = target.add_trig(picked["id"])
	_show_toast(msg)
	sfx.play("place")
	burst(target.position, _card_color(picked), 16, 160.0)
	_after_place()


## 우클릭·Esc: 방향 고르기 → 위치 고르기 → 오브젝트 고르기 순으로 한 단계 되돌린다.
func _cancel_step() -> void:
	if press_t:
		_drop_press()
		_restore_hint()
		return
	if boxing:
		boxing = false
		return
	if not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY]:
		card_dock.close_inspector()
		_restore_hint()
		return
	if moving:
		var t := moving
		moving.position = move_orig_pos
		moving.set_attack_direction(move_orig_dir)
		moving.queue_redraw()
		moving = null
		_end_move()
		_select_tower(t)
		return
	if phase == Phase.AIM:
		phase = Phase.PLACE
		hint.text = _th(PLACE_HINT)
	elif phase == Phase.PLACE:
		_back_to_choose()


## 선택지를 그대로 둔 채 오브젝트 고르기로 돌아간다.
func _back_to_choose() -> void:
	card_dock.clear_gesture()
	cards_hidden = false
	tap_sel = offer.find(picked)
	for button: Button in choice_box.get_children():
		if button.get_meta("offer_card", {}) == picked:
			card_dock.hovered = button
	phase = Phase.CHOOSE
	_tap_hover()
	choice_box.visible = not cards_hidden
	_update_reroll_btn()
	hint.text = _th(_choose_hint())
	_save_run()


## 방향 바꾸기를 끝내고 원래 단계로.
func _end_move() -> void:
	card_dock.clear_gesture()
	card_dock.close_inspector()
	aim_right = false
	if move_return == Phase.READY:
		_enter_ready()
	else:
		phase = Phase.CHOOSE
		_set_cards_hidden(move_cards_hidden)
		_restore_hint()
		_save_run()


## 선택한 오브젝트의 [방향 변경]·한 번 더 누르기 또는 우클릭 끌기로 제자리 방향을 편집한다.
func _start_move(t: Tower) -> void:
	move_cards_hidden = cards_hidden
	move_return = phase
	start_btn.visible = false
	moving = t
	move_orig_pos = t.position
	move_orig_dir = t.dir
	place_pos = t.position
	phase = Phase.AIM
	aim_start_ms = Time.get_ticks_msec()
	_aim_begin()
	choice_box.visible = false
	reroll_btn.visible = false
	if touch_ui:
		hint.text = _th(AIM_TOUCH_HINT + "   취소: 그대로 두기")
	else:
		hint.text = _th("클릭 또는 끌어서 놓기: 방향 확정 (Shift: 15도 단위)   오브젝트 우클릭한 채 끌기로도 바로 됨\n우클릭/Esc: 그대로 두기")


func _toggle_pause() -> void:
	if phase == Phase.GAMEOVER or title_label.visible:
		return
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		_abort_touch_action()
	paused_label.visible = get_tree().paused
	pause_box.visible = get_tree().paused
	paused_label.text = _pause_text()
	restart_armed = 0.0
	end_armed = 0.0
	pause_btn.tooltip_text = "계속 (P)" if get_tree().paused else "일시정지 (P)"  # 그림 버튼이라 글은 말풍선에만


## 일시정지에서 처음부터: 두 번 눌러야 (R 또는 버튼).
func _pause_restart() -> void:
	if restart_armed > 0.0:
		get_tree().paused = false
		if TutPlay.on and tplay != null:
			var ch := tplay.start_ch
			TutPlay.leave_meta()
			TutPlay.pending = ch  # 연습 판: 그 장 처음부터
		_reload()
	else:
		restart_armed = 2.0
		paused_label.text = _pause_text() + "\n처음부터를 한 번 더 누르면 새 판"


## 일시정지 글: 지금 나가면 어디서부터 이어지는지도 알려 준다. 키는 아래 그림 버튼 모서리에.
func _pause_text() -> String:
	var keys := "일시정지"
	if TutPlay.on:
		return keys + "\n연습 판이에요. 기록·업적은 남지 않아요"
	if phase == Phase.WAVE:
		return keys + "\n지금 나가면 웨이브 %d 앞 쉬는 시간부터 이어집니다" % wave
	return keys + "\n지금 나가도 이 쉬는 시간부터 이어서 할 수 있어요"


## 일시정지에서 판 끝내기: 두 번 누르면 지금 점수로 게임 오버 (기록 저장·온라인 전송은 보통 게임 오버와 같다).
## 실수로 누르지 않게 처음 누르면 안내만 한다.
func _end_run() -> void:
	if TutPlay.on and tplay != null:
		_toggle_pause()
		tplay.ask_quit()  # 연습 판: 튜토리얼 끝내기 확인
		return
	if end_armed <= 0.0:
		end_armed = 3.0
		paused_label.text = _pause_text() + "\n판 끝내기를 한 번 더 누르면 지금 점수 %s로 끝냅니다 (기록·순위에 올라가요)" % num(score)
		return
	end_armed = 0.0
	get_tree().paused = false
	paused_label.visible = false
	pause_box.visible = false
	pause_btn.tooltip_text = "일시정지 (P)"
	ended = true
	_game_over()


## 일시정지에서 시작 화면으로 가거나 게임을 끈다. 쉬는 시간이면 지금 상태를 저장하고,
## 웨이브 중이면 그 웨이브 앞 쉬는 시간의 저장이 남는다 (시작 화면의 이어하기).
func _leave(quit_game: bool) -> void:
	if TutPlay.on and tplay != null and not quit_game:
		tplay.finish(false)  # 연습 판에서 시작 화면으로 = 튜토리얼 끝내기
		return
	_save_run()
	if quit_game:
		TutPlay.leave_meta()
	get_tree().paused = false
	if quit_game:
		get_tree().quit()
		return
	title_seen = false
	_reload()


# ---------- 기맥 (2026-10-31 "디펜스 한계 개선 F") ----------
## 판마다 전장에 기맥 자리 ley_n개가 생긴다(판 번호로 정해 이어하기도 같음). 자리마다 ley_r 안 가장 가까운 오브젝트 하나가 피해 +ley_dmg.
var ley: Array = []  # 기맥 자리 (전장 좌표)


func leys_on() -> bool:
	return Rules.t("ley_on") > 0.0 and mp_mode == "" and OS.get_environment("LEY") != "0"  # 봇 비교용: LEY=0이면 끔


## 새 판: 중앙에서 150~360, 가장자리에서 90 넘게, 서로 220 넘게 떨어진 자리. 회랑은 문에서 150 넘게.
func _ley_new_run() -> void:
	ley = []
	if not leys_on():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(run_id + "ley")
	var fr := field_rect().grow(-90.0)
	var c := core()
	var n := int(Rules.t("ley_n"))
	for tries in 400:
		if ley.size() >= n:
			break
		var p := Vector2(rng.randf_range(fr.position.x, fr.end.x), rng.randf_range(fr.position.y, fr.end.y))
		if Meta.map_id == "line":
			p.y = c.y + rng.randf_range(-LINE_HALF + 50.0, LINE_HALF - 50.0)  # 회랑: 길 안에만
		var d := absf(p.x - c.x) if Meta.map_id == "line" else p.distance_to(c)
		if d < 150.0 or (Meta.map_id != "line" and d > 360.0):
			continue
		if ley.any(func(q): return q.distance_to(p) < 220.0):
			continue
		ley.append(p)


## 이 오브젝트가 기맥 위인가: 어느 자리에서 ley_r 안이고, 그 자리에 가장 가까운 오브젝트.
## 한 시뮬 단계 안에서는 맞을 때마다 다시 세지 않는다(ley_memo: sim_id → 결과).
var ley_memo := {}
var ley_memo_id := -1


func on_ley(t: Node) -> bool:
	if ley.is_empty():
		return false
	if phase == Phase.WAVE:
		if ley_memo_id != sim_id:
			ley_memo_id = sim_id
			ley_memo = {}
		var id := t.get_instance_id()
		if not ley_memo.has(id):
			ley_memo[id] = _on_ley(t)
		return ley_memo[id]
	return _on_ley(t)


func _on_ley(t: Node) -> bool:
	var r := Rules.t("ley_r")
	for p in ley:
		if t.position.distance_to(p) >= r:
			continue
		var mine := true
		for o in towers.get_children():
			if o != t and o.position.distance_to(p) < t.position.distance_to(p):
				mine = false
				break
		if mine:
			return true
	return false


func _draw_ley() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var r := Rules.t("ley_r")
	for p in ley:
		var used := false
		for t in towers.get_children():
			if t.position.distance_to(p) < r:
				used = true
				break
		var a := 0.5 + 0.2 * sin(now * 2.0 + p.x * 0.01)
		draw_circle(p, r, Color(BUILD_COLOR, 0.08 if not used else 0.16))
		for k in 6:
			var a0 := TAU * k / 6.0 + now * 0.4
			draw_arc(p, r, a0, a0 + 0.6, 6, Color(BUILD_COLOR, a if not used else 0.9), 2.0)
		draw_circle(p, 3.0, Color(BUILD_COLOR, a))


# ---------- 중앙 기술 (Skill) ----------

var auto_skills := false  # 봇·점검: 설정과 상관없이 자동 사용


## 이번 판에 중앙 기술을 쓰는가 (멀티플레이·온라인 패치 skill_on 0이면 없음).
func skills_on() -> bool:
	return Rules.t("skill_on") > 0.0 and mp_mode == "" and OS.get_environment("SKILL") != "0"  # 봇 비교용: SKILL=0이면 끔


func _skills_new_run(set_i: int) -> void:
	skill_set = clampi(set_i, 0, Skill.SETS.size() - 1)
	skill_ids = Skill.set_ids(skill_set).duplicate() if skills_on() else []
	skill_cd = {}
	skill_arm = ""
	skill_used = 0


func skill_left(id: String) -> float:
	return skill_cd.get(id, 0.0)


func _skill_tick(delta: float) -> void:
	if skill_ids.is_empty() or mp_ghost:
		return
	for id in skill_cd.keys():
		skill_cd[id] = maxf(skill_cd[id] - delta, 0.0)
	if Meta.skill_auto or auto_skills:
		for id in skill_ids:
			if skill_left(id) <= 0.0 and id != skill_arm:
				var p: Variant = Skill.auto_target(self, id)
				if p != null:
					_use_skill(id, p)


## 기술 버튼(1·2 키): 쓸 곳을 누르기를 기다린다. 다시 누르면 취소.
func _arm_skill(i: int) -> void:
	if phase != Phase.WAVE or i < 0 or i >= skill_ids.size():
		return
	var id: String = skill_ids[i]
	if skill_left(id) > 0.0:
		_show_toast("%s: %d초 뒤에 다시 쓸 수 있어요" % [Skill.NAMES[id], ceili(skill_left(id))])
		return
	skill_arm = "" if skill_arm == id else id
	if skill_arm != "":
		# 이름(집중·붙잡기·낙인)만으로는 무엇을 하는지 몰라 설명을 같이 (2026-11-03)
		_show_toast(("%s (%s): 쓸 곳을 누르세요" if touch_ui else "%s (%s): 쓸 곳을 클릭 (우클릭·Esc 취소)") % [Skill.NAMES[id], Skill.short(id)])


## p에 기술을 쓴다. 적용할 대상이 없으면 쓰지 않는다 (누른 기술이면 이유를 알림).
func _use_skill(id: String, p: Vector2) -> bool:
	if phase != Phase.WAVE or skill_left(id) > 0.0 or not id in skill_ids:
		return false
	if not Skill.use(self, id, p):
		if skill_arm == id:
			if id == "hold" and not Skill.hold_targets(self, p).is_empty():
				_show_toast("붙잡기: 구체가 기절·속박 면역 중이에요")
			else:
				_show_toast("집중: 오브젝트 위를 누르세요" if id == "focus" else "%s: 둘레에 구체가 없어요" % Skill.NAMES[id])
		return false
	skill_cd[id] = Skill.cd_full(id, perks.get("quick", 0))
	skill_used += 1
	if skill_arm == id:
		skill_arm = ""
	sfx.play("place")
	return true


## 기술 버튼: 웨이브 중에만, 다시 쓰기까지 남은 초를 글로.
func _skill_ui() -> void:
	var show := phase == Phase.WAVE and not skill_ids.is_empty() and not title_label.visible
	for i in skill_btns.size():
		var b: Button = skill_btns[i]
		b.visible = show and i < skill_ids.size()
		if not b.visible:
			continue
		var id: String = skill_ids[i]
		var left := skill_left(id)
		var txt: String = Skill.NAMES[id] if left <= 0.0 else "%s %d초" % [Skill.NAMES[id], ceili(left)]
		if b.text != txt:
			b.text = txt
		var col: Color = Skill.COLORS[id]
		b.modulate = Color(1, 1, 1, 1) if left <= 0.0 else Color(1, 1, 1, 0.55)
		b.add_theme_color_override("font_color", col if left <= 0.0 else Color(1, 1, 1, 0.8))
		b.tooltip_text = "%s (%d): %s · 다시 쓰기 %d초" % [Skill.NAMES[id], i + 1, Skill.desc(id), roundi(Skill.cd_full(id, perks.get("quick", 0)))]
		var armed := skill_arm == id
		if b.get_meta("armed", false) != armed:
			b.set_meta("armed", armed)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col, 0.35) if armed else Color(0.06, 0.07, 0.1, 0.85)
			sb.border_color = col
			sb.set_border_width_all(3 if armed else 2)
			sb.set_corner_radius_all(10)
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, sb)


func _make_skill_btns(root: Control) -> void:
	for i in 2:
		var b := Button.new()
		b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		b.position = Vector2(-176 + i * 186, -104)
		b.size = Vector2(166, 50)
		b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		b.visible = false
		b.pressed.connect(_arm_skill.bind(i))
		root.add_child(b)
		_keycap(b, str(i + 1))
		skill_btns.append(b)


## 기술 효과·고른 기술의 범위 (fx_layer, 전장 좌표).
func _draw_skill_fx() -> void:
	for q in skill_fx:
		var k: float = 1.0 - q[2] / 0.5
		fx_layer.draw_arc(q[0], q[1] * (0.6 + 0.4 * k), 0, TAU, 48, Color(q[3], 0.9 * (1.0 - k)), 4.0)
	if skill_arm != "" and phase == Phase.WAVE:
		var mp := _pointer_world()
		var col: Color = Skill.COLORS[skill_arm]
		if skill_arm == "focus":
			var t := Skill.focus_tower(self, mp)
			if t:
				fx_layer.draw_arc(t.position, Tower.RADIUS + 12.0, 0, TAU, 28, col, 3.0)
			fx_layer.draw_arc(mp, Skill.PICK_R, 0, TAU, 32, Color(col, 0.35), 1.5)
		else:
			var r := Skill.radius(skill_arm)
			fx_layer.draw_circle(mp, r, Color(col, 0.12))
			fx_layer.draw_arc(mp, r, 0, TAU, 48, Color(col, 0.8), 2.0)


func _toggle_speed() -> void:
	# Space·버튼: 1배속 ↔ 고른 배속
	game_speed = _fast_now() if game_speed == 1.0 else 1.0
	_update_speed_btn()


## 빠르게 켤 때 배속
func _fast_now() -> float:
	return fast_speed


func _update_speed_btn() -> void:
	speed_btn.text = "x%d" % roundi(game_speed)
	speed_btn.tooltip_text = "배속 x%d (Space)" % roundi(game_speed)
	speed_btn.queue_redraw()
	for i in SPEEDS.size():
		if SPEEDS[i] == fast_speed:
			speed_pick.select(i)


func _on_speed_pick(i: int) -> void:
	fast_speed = SPEEDS[i]
	if game_speed > 1.0:
		game_speed = _fast_now()
	_update_speed_btn()
	_save_best()


func _tower_at(p: Vector2, except: Tower = null) -> Tower:
	for t in towers.get_children():
		if t != except and t.position.distance_to(p) < MERGE_DIST:
			return t
	return null


func _place_tower(p: Vector2, d: Vector2) -> void:
	var t := Tower.new()
	t.add(picked["e"], picked["lv"])
	t.dir = d
	t.position = p
	t.main = self
	if mp_mode == "coop":
		mp_tw_n += 1
		t.owner_id = mp.my_id
		t.net_id = mp.my_id * 100000 + mp_tw_n
	towers.add_child(t)


# ---------- 생성 ----------

func spawn_proj(t: Tower, kind: String, l: int, d := Vector2.ZERO, off := Vector2.ZERO) -> Projectile:
	var p := Projectile.new()
	p.setup(kind, t, l, d, off)
	projectiles.add_child(p)
	return p


func spawn_zone(kind: String, l: int, pos: Vector2, t: Tower) -> Zone:
	var z := Zone.new()
	z.setup(kind, l, t)
	z.src = t.tag if t else ""
	if t and t.fire_boost > 1.0:
		z.boost = t.fire_boost
		z.src = t.fire_key
	z.position = pos
	zones.add_child(z)
	return z


## 벽 공격방식: 발사 방향에 바위 벽. 오브젝트당 최대 2개(+다중 발사).
func spawn_rock(t: Tower, l: int) -> void:
	t.rocks = t.rocks.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion())
	if t.rocks.size() >= 2 + roundi(t.mf("multi")):
		return
	# 바위는 화면 가장자리에서 100 안쪽에만 선다: 가장자리에 서면 막힌 구체가 화면 끝에 붙어
	# 다른 오브젝트가 닿지 않는 곳에서 버티고 웨이브가 끝나지 않던 것 (폭풍 맵 66웨이브에서 4분 넘게)
	var inner := arena().grow(-100.0)
	# 빈 자리 중 앞쪽부터 (Tower.rock_slot). 가장자리에 밀려 같은 자리에 겹치는 바위는 세우지 않는다
	for k in 2 + roundi(t.mf("multi")):
		var p := (t.position + Tower.rock_slot(t.aim if t.m("reflex") > 0 else t.dir, k, l)).clamp(inner.position, inner.end)
		if not t.rocks.any(func(r): return r.position.distance_to(p) < 40.0):
			t.rocks.append(spawn_zone("rock", l, p, t))
			return


## 연쇄 번개 표시 (맨 위 층).
func bolt(pts: PackedVector2Array) -> void:
	if bolts.size() < 40:
		bolts.append([pts, 0.22])


## 소리 울림: 울림이 3번 쌓인 구체 주변(자기 포함)에 음파 피해. 부가효과는 붙지 않는다.
func sound_pulse(o: Orb) -> void:
	var tw: Tower = o.tune_src if is_instance_valid(o.tune_src) else null
	var l := maxi(o.tune_lv, 1)
	var r := 70.0 + 10.0 * (l - 1)
	var dmg := Rules.t("sound_pulse") * Tower.pw(l) * (tw.dmg_k(true) / (1.0 + Rules.size_dmg * tw.mf("size") if tw.pattern in Pat.PROJECTILE else 1.0) if tw else 1.3)
	# 소리 퍼짐 (특징 공유): 음파에 닿은 구체에 울림을 건 오브젝트 효과
	var ks := Share.k(tw, Elem.SOUND) if tw else 0.0
	if ks > 0.0:
		r *= Share.wide(tw)
	if Share.has(tw, "reso"):
		r *= 1.0 + Share.RESO_R  # 공진 (상성)
	for other in near(o.position, r + 30.0):
		if other.hp > 0.0 and other.position.distance_to(o.position) < r + other.radius():
			var got: float = other.hurt(dmg, false, tw)
			if tw:
				tw.credit(got, "elem:sound")
				if ks > 0.0 and other != o:
					Share.carry(tw, other, Share.SOUND_F * ks, "share:sound", o.position, other.position.distance_to(o.position) / maxf(r, 1.0))
				if other != o and Share.has(tw, "phantasm") and tw.lv(Elem.ILLUSION) > 0 and randf() < Share.illu_ch(tw, tw.lv(Elem.ILLUSION)):
					other.confuse(Rules.illu_t * Share.dur(tw), Share.has(tw, "nightmare"))  # 환청 (상성)
	if pulses.size() < 40:
		pulses.append([o.position, r, 0.3])


## 영혼: 넋이 걸린 채 죽은 구체에서 혼불 (영혼 쫓아감: 혼불은 그 오브젝트 공격처럼 맞혀 효과를 모두 건다). 화면의 혼불은 30개까지.
func _soul_wisp(o: Orb) -> void:
	var tw: Tower = null
	var l := 1
	if o.soul_t > 0.0 and is_instance_valid(o.soul_src) and randf() < minf(Rules.t("soul_base") + Rules.t("soul_lv") * o.soul_lv, Rules.t("soul_max")):
		tw = o.soul_src
		l = o.soul_lv
	if tw == null:
		return
	var n := 0
	for p in projectiles.get_children():
		if p.kind == "ghost":
			n += 1
	if n >= 30:
		return
	var g := spawn_proj(tw, "ghost", l, Vector2.from_angle(randf() * TAU))
	g.position = o.position
	g.hit[o] = true
	g.dmg = 2.5 * Tower.pw(l)
	g.src = "elem:soul"


## 빛줄기 표시 (빛 꿰뚫음): 잠깐 빛나는 직선.
func beam(a: Vector2, b: Vector2, c: Color) -> void:
	if beams.size() < 40:
		beams.append([a, b, c, 0.2])


## 전기 부가효과: 가까운 다른 구체로 전류가 튄다 (src: 쏜 오브젝트, 피해 기록용).
func arc(from: Orb, dmg: float, src: Tower = null, cap = null) -> void:  # cap: 초신성 보스 상한 (Tower.nova_hurt)
	var best: Orb = null
	var bd := 90.0 * (Share.wide(src) if src else 1.0) * (1.0 + Share.SHOCK_R if Share.has(src, "shock") else 1.0)
	for o in near(from.position, bd):
		if o != from and is_instance_valid(o) and o.hp > 0.0:
			var d: float = o.position.distance_to(from.position)
			if d < bd:
				bd = d
				best = o
	if best:
		var got: float = src.nova_hurt(best, dmg, cap) if src and cap is Dictionary else best.hurt(dmg, false, src)
		if src:
			src.credit(got, "elem:electric")
			if Share.has(src, "shock"):
				best.stagger(Share.SHOCK_STAG)  # 감전 (상성)
			# 전기 튐 (특징 공유): 전류가 튀면 오브젝트 효과도 튄다
			var ke := Share.k(src, Elem.ELECTRIC)
			if ke > 0.0:
				Share.carry(src, best, Share.ELEC_F * ke, "share:electric", from.position, 1.0)
		if arcs.size() < 80:
			arcs.append([from.position, best.position, 0.12])


## 구체 하나의 진입 각도·체력(종류 보정 전)·속도·저항·굳셈을 뽑는다.
## 웨이브 w 구체가 진입 방향 각도에서 벗어나는 폭(라디안, ±). 화면의 진입 부채꼴(_draw_lane_fan)과 같은 값.
static func lane_spread(w: int) -> float:
	if Meta.map_id == "cross":
		return 0.06  # 십자로: 네 길 위로만 온다
	if Meta.map_id == "line":
		return 0.0  # 회랑: 방향은 하나, 대신 높이가 길 폭 안에서 갈린다
	return minf(0.15 + 0.01 * w, 0.4)


func _roll_orb(w: int) -> Dictionary:
	var spread := lane_spread(w)
	var li: int = lane_bag.pop_back() if not lane_bag.is_empty() and phase == Phase.WAVE and not w_off else wi() % lanes.size()
	var a: float = lanes[li] + wrange(-spread, spread)
	var hp := (1.0 + floorf(w * 0.7) + wi() % 2) * hp_growth(w) * Rules.orb_hp
	match Meta.map_id:
		"cross":
			hp = ceilf(hp * CROSS_HP)
		"storm":
			hp = maxf(1.0, roundf(hp * 0.6))
		"line":
			hp *= LINE_HP
	hp *= Vary.hp_k()
	hp *= coop_hp_k(w) * vs_k("vs_hp")
	var spd := (orb_base_speed(w) + wf() * 8.0) * (LINE_SPD if Meta.map_id == "line" else 1.0) * Vary.spd_k() * vs_k("vs_spd")
	# 저항·굳셈: 쉬는 시간에 미리 알려 준 대로
	var res := wave_resist if wave_resist >= 0 and wf() < resist_share(w) else -1
	var y := wrange(-LINE_HALF + 20.0, LINE_HALF - 20.0) if Meta.map_id == "line" else 0.0
	return {"a": a, "y": y, "hp": roundf(hp), "spd": spd, "resist": res, "sturdy": wf() < sturdy_share(w) or Vary.all_sturdy()}


## 다음 웨이브가 보스 웨이브면 보스를 미리 뽑아 둔다 (화면에 길·체력을 정확히 알려 주려고).
func _plan_boss() -> void:
	boss_plan = {}
	if (wave + 1) % 5 == 0 and not lanes.is_empty():
		boss_plan = _roll_orb(wave + 1)
		boss_plan["wave"] = wave + 1


## 구체가 나오는 거리. 예전(lane_even 0)은 모든 방향 화면 대각선 반 + 30.
## 지금은 각도 a 방향 전장 가장자리 + lane_margin: 상하(360)는 좌우(640)보다 가깝다 → lane_k로 속도를 맞춘다.
func _spawn_radius(a := 0.0) -> float:
	if Rules.t("lane_even") <= 0.0:
		return Meta.FIELD.length() / 2.0 + 30.0
	return _edge_point(center(), Vector2.from_angle(a)).distance_to(center()) + Rules.t("lane_margin")


## 진입 시간 맞추기 (2026-11-01): 각도 a에서 나온 구체 속도 배율. 나온 곳에서 중앙까지 걸리는 시간이
## 좌우(가장 먼 가로 방향)와 같아지게 거리 비율로 곱한다 (상하 약 0.58, 좌우 1, 모서리 약 1.14). 전체에 lane_speed(소용돌이는 lane_speed_spiral)를 곱함.
## 소용돌이는 중앙 가까울수록 빨라지므로 거리 대신 걸리는 시간 몫(_lane_time)으로 비율을 낸다.
func lane_k(a: float) -> float:
	if Rules.t("lane_even") <= 0.0 or Meta.map_id == "line":
		return 1.0
	var ref := Meta.FIELD.x / 2.0 + Rules.t("lane_margin")
	return _lane_time(_spawn_radius(a)) / _lane_time(ref) * Rules.t("lane_speed_spiral" if Meta.map_id == "spiral" else "lane_speed")


## 거리 d에서 중앙까지 속도 1로 걸리는 시간 (소용돌이: 나선이라 안쪽으로는 cos(비낌)만큼, 거리별 속도 배율 반영).
func _lane_time(d: float) -> float:
	if Meta.map_id != "spiral":
		return d
	var t := 60.0
	var n := 48
	var step := maxf(d - 60.0, 0.0) / n
	for i in n:
		t += step / (cos(SPIRAL_SWIRL) * MapRule.spiral_speed(60.0 + step * (i + 0.5)))
	return t


## 각도 a에서 나온 구체가 막히지 않을 때 지나가는 길 (소용돌이 맵은 나선, 구체 이동과 같은 식).
## y: 회랑 맵에서 구체가 나오는 높이.
func _orb_path(a: float, y := 0.0) -> PackedVector2Array:
	if Meta.map_id == "line":
		return PackedVector2Array([_line_start(y), _line_end(y)])
	var c := center()
	var p := c + Vector2.from_angle(a) * _spawn_radius(a)
	if Meta.map_id != "spiral":
		return PackedVector2Array([p, c])
	var sw := SPIRAL_SWIRL * MapRule.swirl_sign(wave if phase == Phase.WAVE else wave + 1)
	var pts := PackedVector2Array([p])
	for k in 600:
		var to := c - p
		if to.length() <= 60.0:
			break
		p += to.normalized().rotated(sw) * 4.0
		if k % 3 == 2:
			pts.append(p)
	pts.append(p)
	pts.append(c)
	return pts


func _spawn_orb(kind := -1, plan := {}) -> void:
	var o := Orb.new()
	var p: Dictionary = plan if not plan.is_empty() else _roll_orb(wave)
	o.born = run_game
	o.position = center() + Vector2.from_angle(p["a"]) * _spawn_radius(p["a"])
	o.from_a = p["a"]
	o.target = center()
	o.lane_k = lane_k(p["a"])
	if Meta.map_id == "line":
		o.position = _line_start(p.get("y", 0.0))
		o.target = _line_end(p.get("y", 0.0))
	if kind < 0:
		kind = _roll_kind()
	o.main = self
	if Meta.map_id == "spiral":
		o.swirl = SPIRAL_SWIRL * MapRule.swirl_sign(wave)  # 회오리: 보스 웨이브가 끝나면 방향이 바뀐다
	o.setup(kind, p["hp"], p["spd"])
	o.resist_e = p["resist"]
	o.sturdy = p["sturdy"]
	# A4·A5: 보호막(8웨이브~), 분열(12웨이브~, 10웨이브는 보스·저항이 처음 겹침)
	if kind == Orb.Kind.NORMAL or kind == Orb.Kind.TANK:
		if wave >= 8 and wf() < minf(0.1 + 0.01 * wave, 0.3):
			o.shield = (2.0 + wave * 0.3) * hp_growth(wave) * Rules.orb_hp
		if wave >= 12 and wf() < 0.15:
			o.splits = true
	if Vary.all_split() and kind != Orb.Kind.BOSS:
		o.splits = true  # 이벤트 증식
	if kind != Orb.Kind.BOSS:
		_late_trait(o, p)
		if o.late == "":
			_jam_trait(o)
	orbs.add_child(o)


## 후반 구체 (100·175·250·350·500웨이브~, Rules late_*). 종류마다 처음 late_share, 10웨이브마다 +late_share_step, 최대 late_share_max.
## 치유는 웨이브당 late_heal_max, 포식은 웨이브 무리를 late_devour_n+1로 나눈 자리마다 하나(조금 빨라 앞 구체를 따라잡음).
const LATE_IDS := ["blink", "armor", "mender", "phase", "devour"]
const LATE_FROM := {"blink": "late_blink_from", "armor": "late_armor_from", "mender": "late_heal_from", "phase": "late_phase_from", "devour": "late_devour_from"}
const LATE_NAMES := {"blink": "깜빡 구체", "armor": "갑옷 구체", "mender": "치유 구체", "phase": "흐림 구체", "devour": "포식 구체"}
const LATE_DESC := {"blink": "깜빡 구체(보라 점선 고리: 몇 초마다 앞으로 순간이동, 깜빡이면 곧 뜀. 기절·속박 중엔 못 뜀)", "armor": "갑옷 구체(두꺼운 테두리: 맞을 때마다 피해가 조금씩 깎임, 큰 한 방·화상·중독·반응엔 약함. 맞을수록 깨짐)", "mender": "치유 구체(초록 십자: 주변 구체 체력을 채움. 화상·중독 걸린 구체는 절반, 침묵이면 멈춤)", "phase": "흐림 구체(파란 고리: 흐려진 동안 탄·광선 피해 30%만. 화상·중독·장판·반응은 그대로)", "devour": "포식 구체(붉은 입: 무리 사이에서 조금 빠르게 와 닿은 구체를 삼켜 커지고 중앙 피해가 늘어남)"}
var late_n := {}  # 이번 웨이브에 나온 후반 구체 수 (치유·포식 상한)


static func late_from(id: String) -> int:
	return int(Rules.t(LATE_FROM[id]))


static func late_share(id: String, w: int) -> float:
	var f := late_from(id)
	if w < f or id == "devour":
		return 0.0
	return minf(Rules.t("late_share") + Rules.t("late_share_step") * floorf((w - f) / 10.0), Rules.t("late_share_max"))


func _late_trait(o: Orb, p: Dictionary) -> void:
	if mp_ghost:
		return
	var id := ""
	var dn := int(Rules.t("late_devour_n"))
	var tot := spawn_count(wave)
	if wave >= late_from("devour") and late_n.get("devour", 0) < dn and range(1, dn + 1).any(func(k): return to_spawn == int(tot * k / (dn + 1.0))):
		id = "devour"  # 무리 한가운데쯤 나와 앞 구체를 따라잡아 삼킨다
	else:
		var x := wf()
		for k in ["blink", "armor", "mender", "phase"]:
			var sh := late_share(k, wave)
			if sh <= 0.0:
				continue
			if x < sh:
				if k != "mender" or late_n.get("mender", 0) < int(Rules.t("late_heal_max")):
					id = k
				break
			x -= sh
	if id == "":
		return
	late_n[id] = late_n.get(id, 0) + 1
	o.late = id
	var hk := 1.0
	var sk := 1.0
	match id:
		"blink":
			sk = 0.85
			o.late_t = Rules.t("late_blink_iv")
		"armor":
			hk = 1.2; sk = 0.9
			o.armor = p["hp"] * Rules.t("late_armor")
		"mender":
			hk = 0.7; sk = 0.8
			o.late_t = Rules.t("late_heal_iv")
		"phase":
			hk = 1.3
			o.late_t = wf() * Rules.t("late_phase_on")  # 다 같이 깜빡이지 않게
		"devour":
			hk = 3.0; sk = 1.3
			o.splits = false
			o.shield = 0.0
	o.max_hp = ceilf(o.max_hp * hk)
	o.hp = o.max_hp
	o.speed *= sk


# ---------- 방해 구체 (Orb.jam, 2026-10-31 "디펜스 한계 개선 B") ----------
## 오브젝트를 잠깐 멈추거나 느리게만 한다(오브젝트 체력은 없음). 예고는 쉬는 시간 웨이브 안내, 침묵이면 효과가 멈춘다.
const JAM_IDS := ["shade", "leech", "seeker"]
const JAM_NAMES := {"shade": "그림자 구체", "leech": "흡수 구체", "seeker": "표적 구체"}
const JAM_DESC := {"shade": "그림자 구체(보라 둘레: 지나가며 둘레 오브젝트 공격을 잠깐 멈춤. 침묵이면 못 함)", "leech": "흡수 구체(초록 송곳니: 맞힌 오브젝트 공격 속도를 빼앗고, 잡으면 둘레가 풀림)", "seeker": "표적 구체(붉은 화살촉: 가장 가까운 오브젝트로 와서 닿으면 그 오브젝트를 멈추고 사라짐, 중앙 피해 없음)"}
var jam_any := false  # 이번 웨이브에 방해 구체가 나왔나 (없으면 매 조각 검사를 건너뜀)


static func jam_from(id: String) -> int:
	return int(Rules.t("jam_%s_from" % id))


static func jam_share(id: String, w: int) -> float:
	var f := jam_from(id)
	if w < f:
		return 0.0
	return minf(Rules.t("jam_share") + Rules.t("jam_share_step") * floorf((w - f) / 10.0), Rules.t("jam_share_max"))


func jams_on() -> bool:
	return Rules.t("jam_on") > 0.0 and mp_mode == "" and OS.get_environment("JAM") != "0"  # 봇 비교용: JAM=0이면 끔


func _jam_trait(o: Orb) -> void:
	if not jams_on() or mp_ghost:
		return
	var x := wf()
	for k in JAM_IDS:
		var sh := jam_share(k, wave)
		if sh <= 0.0:
			continue
		if x < sh:
			o.jam = k
			break
		x -= sh
	if o.jam == "":
		return
	jam_any = true
	if o.jam == "seeker":
		o.speed *= Rules.t("jam_seek_spd")
		var best: Tower = null
		var bd := INF
		for t in towers.get_children():
			var d: float = t.position.distance_to(o.position)
			if d < bd:
				bd = d
				best = t
		if best:
			o.jam_tower = best
			o.jam_home = o.target
			o.target = best.position
			o.swirl = 0.0  # 곧장 온다
			o.lane_k = 1.0


## 계산 조각마다: 그림자는 둘레 오브젝트를 멈추고, 표적은 닿으면 멈추고 사라진다.
func _jam_tick() -> void:
	if not jam_any:
		return
	for o in live_orbs:
		if o.jam == "" or o.hp <= 0.0 or o.is_queued_for_deletion():
			continue
		if o.silence_t > 0.0:
			continue
		match o.jam:
			"shade":
				var r := Rules.t("jam_shade_r") + Tower.RADIUS
				for t in towers.get_children():
					if t.position.distance_to(o.position) < r:
						t.jam(Rules.t("jam_shade_t"))
			"seeker":
				var t: Object = o.jam_tower
				if not is_instance_valid(t):
					o.jam = ""
					o.target = o.jam_home
					continue
				if t.position.distance_to(o.position) < Tower.RADIUS + o.radius() + 4.0:
					t.jam(Rules.t("jam_seek_t"))
					burst(o.position, Color(1.0, 0.35, 0.3), 12, 160.0)
					o.queue_free()


## 흡수 구체가 죽으면 둘레 오브젝트가 빼앗긴 공격 속도를 돌려받는다.
func _jam_death(o: Orb) -> void:
	if o.jam != "leech":
		return
	for t in towers.get_children():
		if t.position.distance_to(o.position) < Rules.t("jam_leech_free"):
			t.leech_n = 0
			t.leech_t = 0.0


## 피해 숫자 팝업.
func popup(pos: Vector2, amount: float, col: Color, big: bool, text := "", life := 0.7) -> void:
	if popups.size() > 120:
		if text == "":
			return
		popups.pop_front()  # 글자(최다 피해·콤보)는 피해 숫자가 꽉 차도 가장 오래된 것을 밀어내고 띄운다
	if text == "" and not Meta.numbers_on:
		return
	var txt := text if text != "" else str(maxi(roundi(amount), 1))
	popups.append([pos + Vector2(randf_range(-8, 8), -10), txt, life, col, big])


## 웨이브를 마치면 가장 많이 때린 오브젝트 위에 몫을 잠깐 띄운다 (무엇이 일하는지 알려 줌).
func _show_mvp() -> void:
	var best: Tower = null
	var total := 0.0
	for t in towers.get_children():
		total += t.dealt
		if best == null or t.dealt > best.dealt:
			best = t
	if best == null or total <= 0.0 or towers.get_child_count() < 2:
		return
	var txt := "최다 피해 %d%%" % roundi(best.dealt / total * 100.0)
	popup(best.position + Vector2(-ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x / 2.0, -30), 0.0, Color(1, 0.9, 0.5), true, txt, 2.0)


## 구체가 터질 때 파편.
func burst(pos: Vector2, col: Color, n: int, spd: float) -> void:
	if particles.size() > 600:
		n = mini(n, 3)
	for i in n:
		var a := randf() * TAU
		particles.append([pos, Vector2(cos(a), sin(a)) * spd * randf_range(0.4, 1.0), randf_range(0.3, 0.6), col, randf_range(2.0, 4.5)])


## 보스가 부르는 빠른 부하.
func spawn_minion(boss: Orb) -> void:
	var o := Orb.new()
	o.main = self
	o.position = boss.position
	o.from_a = boss.from_a
	o.target = boss.target
	o.setup(Orb.Kind.FAST, maxf(1.0, roundf(wave * 0.5 * hp_growth(wave) * Rules.orb_hp)), orb_base_speed(wave) + 6.0)
	o.resist_e = boss.resist_e
	o.minion = true
	orbs.add_child(o)


## 분열 구체가 터지면 작은 구체 2개.
func _spawn_child(parent: Orb) -> void:
	var o := Orb.new()
	o.main = self
	o.position = parent.position + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	o.from_a = parent.from_a
	o.target = parent.target
	o.swirl = parent.swirl
	o.lane_k = parent.lane_k
	o.setup(Orb.Kind.NORMAL, maxf(1.0, ceilf(parent.max_hp * 0.4)), parent.speed * 1.1 / (orb_speed_mul * Modes.speed()))
	o.resist_e = parent.resist_e
	o.sturdy = parent.sturdy
	orbs.add_child(o)


## 웨이브가 오를수록 빠른 구체(4웨이브~), 단단한 구체(6웨이브~)가 섞인다.
func _roll_kind() -> int:
	var x := wf()
	# 단단한 구체는 7웨이브부터 (6웨이브는 세 번째 진입 방향이 열림)
	if wave >= 7 and x < minf(0.08 + 0.02 * wave, 0.3):
		return Orb.Kind.TANK
	if wave >= 4 and x > 1.0 - minf(0.1 + 0.03 * wave, 0.35):
		return Orb.Kind.FAST
	return Orb.Kind.NORMAL


# ---------- 루프 ----------

func _process(delta: float) -> void:
	_place_rx_card()
	rank_t -= delta
	if rank_t <= 0.0:
		rank_t = RANK_STEP
		_rank_update()
	key_t -= delta
	_mp_lobby_tick()
	_mp_tick(delta)
	if coin_stage > 0 and not get_tree().paused:
		_coin_step(delta)
	touch_tip_t -= delta
	# 터치 자세히는 유지 중인 인스펙터를 기준으로 표시한다.
	var tip_on := touch_ui and not title_label.visible and (is_instance_valid(card_dock.inspected_tower) if card_dock.active() else Engine.get_process_frames() - tip_frame <= 2)
	if touch_ui or phase == Phase.PLACE:
		fx_layer.queue_redraw()  # PLACE: 올린 오브젝트 설명(place_note)이 마우스를 따라가게. 정보창이 떠 있는지(tip_frame)를 매 프레임 알도록 (쉬는 시간엔 다시 그리지 않는 프레임이 있다)
	if not tip_on:
		tip_detail = false
	detail_btn.visible = tip_on
	aim_ok_btn.visible = _ok_btn_on() and not get_tree().paused
	detail_btn.text = "간단히" if tip_detail else "자세히"
	_place_apply_btn()
	for c in [hint, skip_badge, hide_btn]:
		c.self_modulate.a = 0.12 if Engine.get_process_frames() - tip_fade.get(c, -10) <= 2 else 1.0
	if touch_ui and key_t <= 0.0:
		key_t = 0.2
		_strip_key_hints()
	var us := Time.get_ticks_usec() if prof_on else 0
	if new_armed > 0.0:
		new_armed -= delta
		if new_armed <= 0.0:
			new_btn.text = "새로 시작"
	toast_timer -= delta
	toast.visible = toast_timer > 0.0
	_tut_tick()
	if guide_t > 0.0 and not get_tree().paused:
		guide_t -= delta
		if guide_t <= 0.0:
			guide_lines.clear()
			guide_t = 0.0
	guide_label.visible = Meta.guide_on and not guide_lines.is_empty() and not title_label.visible and phase != Phase.GAMEOVER and not get_tree().paused and not help_label.visible and not settings_panel.visible and not records_panel.visible and not notes_panel.visible and not modes_panel.visible and not codex_panel.visible and not vote_panel.visible and skill_arm == ""  # 기술 조준 중엔 위 가운데 조준 안내만 (글이 겹겹이 쌓였다)
	if not guide_label.visible:
		guide_more.visible = false  # 안내가 꺼졌는데 [더 알아보기]만 남던 것
	# 글자를 키운(설정) 좁은 화면에서 펼친 버튼 줄이 왼쪽 아래 안내 글에 닿으면 안내 글을 버튼 줄 앞까지로 줄인다.
	# 줄이 늘면 위로 자라고, 다음 웨이브 미리보기는 그 위에 붙는다
	var hw := 590.0
	if pause_btn.visible:
		hw = clampf(bar_box.get_rect().position.x - hint.position.x - 12.0, 240.0, 590.0)
	# 아래 가운데 버튼([웨이브 시작]·[취소]·[자세히]·[적용])에도 닿지 않게 (글이 길면 버튼 밑으로 지나갔다)
	var hb := hint.get_rect().end.y
	for b: Control in [start_btn, cancel_btn, detail_btn, aim_ok_btn, skip_badge]:
		if b != null and b.visible:
			var br := b.get_rect()
			if br.end.y > hb - 70.0 and br.position.x > hint.position.x + 120.0:
				hw = minf(hw, maxf(240.0, br.position.x - hint.position.x - 12.0))
	if not is_equal_approx(hint.size.x, hw):
		hint.size.x = hw
	if hint.text != _hint_kept:
		hint.text = _kr_keep(hint.text)  # 줄이 접힐 때 한글 낱말 중간("방향 바/꾸기")에서 끊기지 않게
		_hint_kept = hint.text
	toast.position.y = maxf(100.0, hud.position.y + hud.size.y + 36.0)  # 점수 줄이 길어져도 보스 체력 막대 아래
	if tplay != null:
		toast.position.y = maxf(toast.position.y, tplay.panel_bottom() + 8.0)  # 연습 판 안내 칸 아래
	# 안내·큰 글자도 점수 줄이 길어지거나 글자를 키우면(설정) 그 아래로 밀어 겹치지 않게
	guide_label.position.y = maxf(140.0, toast.position.y + 40.0)
	_beside_legend(guide_label, 0.0)
	_update_action_guide()
	# 왼쪽 위 DPS 표를 펼쳐 두면 알림이 표 위에 겹치던 것 (글자 115% 이상·표가 길 때): 표와 오른쪽 설명 사이에 두고,
	# 글이 그 폭보다 길면 두 줄로 접는다 (예전엔 표 아래로 내려 카드 줄 밑에 깔렸다: 봉인·이벤트 알림)
	if toast.visible:
		var left := 8.0
		var right := _right_panel_x() - 8.0
		if dps_panel.visible and dps_panel.get_rect().end.y > toast.position.y:
			left = dps_panel.get_rect().end.x + 8.0
		var avail := maxf(240.0, right - left)
		var tw := ui_font.get_string_size(toast.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 12.0
		var wrap := tw > avail
		toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		toast.add_theme_font_size_override("font_size", 18 if wrap else 22)  # 접을 때는 조금 작게 (세 줄로 전장 가운데를 덮지 않게)
		var w := minf(maxf(tw, 600.0), avail)
		if not is_equal_approx(toast.size.x, w):
			toast.size = Vector2(w, 0.0)
		toast.position.x = clampf((ui_root.size.x - w) / 2.0, left, maxf(left, right - w))
	banner.position.y = maxf(ui_root.size.y / 2.0 - 140.0, hud.position.y + hud.size.y + 12.0)
	if toast.visible and toast.text != "":
		banner.position.y = maxf(banner.position.y, toast.get_rect().end.y + 4.0)  # 점수 줄이 세 줄일 때 알림과 겹치던 것
	if guide_more.visible:
		banner.position.y = maxf(banner.position.y, guide_more.get_rect().end.y + 4.0)  # [더 알아보기]가 "특성 선택" 큰 글 위에 걸치던 것
	var ban_w := ui_root.size.x
	var ban_full := ui_font.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	if ban_w / 2.0 + minf(ban_full, 800.0) / 2.0 > _right_panel_x() - 8.0:
		ban_w = minf(ban_w, _right_panel_x() - 8.0)  # 긴 큰 글이 오른쪽 설명 위로 넘치던 것 (폰 "웨이브 3개 넘기기")
	banner.size.x = minf(800.0, ban_w - 16.0)
	banner.position.x = (ban_w - banner.size.x) / 2.0
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if ui_font.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x > banner.size.x else TextServer.AUTOWRAP_OFF
	if choice_box.visible and not cards_hidden and choice_box.get_child_count() > 0:
		# 카드가 떠 있으면 "웨이브 N" 큰 글이 카드 윗변에 걸치지 않게 그 위로
		banner.position.y = maxf(minf(banner.position.y, choice_box.get_rect().position.y - banner.size.y - 4.0), hud.position.y + hud.size.y + 12.0)
	banner_t -= delta
	if banner_t <= 0.0 and not banner_queue.is_empty():
		var nb: Array = banner_queue.pop_front()
		big_banner(nb[0], nb[1])
	banner.visible = banner_t > 0.0
	banner.modulate.a = clampf(banner_t / 0.4, 0.0, 1.0)
	legend.visible = phase in [Phase.CHOOSE, Phase.PLACE, Phase.AIM, Phase.MOVE, Phase.READY] and not title_label.visible
	range_btn.visible = touch_ui and not title_label.visible and phase != Phase.GAMEOVER
	zoom_btn.visible = not is_equal_approx(view_zoom, 1.0) and not title_label.visible
	zoom_btn.text = "확대 풀기 x%.1f" % view_zoom
	range_btn.text = "범위 끄기" if range_all else "범위 보기"
	legend.visible = legend.visible and not legend_hidden
	if legend.visible:
		# 설명 아래끝이 오른쪽 아래 설정 버튼(없으면 화면 끝)에 닿으면 반응 줄을 줄인다
		var lim := minf(bar_btn.get_global_rect().position.y if bar_btn.visible else 1e9, get_viewport_rect().size.y) - 8.0
		var over_px := legend.get_global_rect().end.y - lim
		if over_px > 0.0 and legend_rows > 0:
			var lh := legend.get_line_height() * ui_root.scale.y
			legend_rx_rows = maxi(legend_rows - maxi(1, floori(over_px / (lh * 2.0))), 0)  # 반응 한 줄이 접혀 두 줄일 수 있어 덜 줄이고 다음 프레임에 더
			_refresh_legend()
	# 시작 화면 위에 설정·기록·도움말·패치노트 창을 열면 뒤 메뉴는 숨긴다 (흐리게만 하면 창 아래로 삐져나온 버튼 줄이 겹쳐 보이고 눌리던 것)
	if help_label.visible and not help_scroll.visible:
		help_scroll.scroll_vertical = 0  # 열 때마다 맨 위부터
		if help_touch != touch_ui:  # 터치면 조작 안내를 버튼·누르기로
			help_touch = touch_ui
			help_label.text = _kr_keep(_help_text())
	help_scroll.visible = help_label.visible
	if help_scroll.visible:
		var hw2 := minf(1040.0, ui_root.size.x - 40.0)  # 글자를 키우면 화면 폭보다 넓어지던 것
		help_scroll.offset_left = -hw2 / 2.0
		help_scroll.offset_right = hw2 / 2.0
		help_label.custom_minimum_size.x = hw2 - 36.0 - 12.0  # 안쪽 여백 + 굴림 막대
		var hh := minf(help_label.get_combined_minimum_size().y + 36.0, ui_root.size.y - 100.0)
		help_scroll.offset_top = -hh / 2.0
		help_scroll.offset_bottom = hh / 2.0
	title_box.visible = not (tut.visible or settings_panel.visible or records_panel.visible or help_label.visible or notes_panel.visible or modes_panel.visible or codex_panel.visible or vote_panel.visible or mp_panel.visible)
	prep_back.visible = prep and title_box.visible  # 준비 화면에서 모드 창 등을 열면 [뒤로]도 숨김
	# 투표 버튼: 투표 API가 있는 서버(boot의 vote)에 닿았을 때만. 판 끝난 화면 버튼은 남은 글 바로 아래
	if vote_btn:
		vote_btn.visible = Net.vote_ok()
	vote_over_btn.visible = over_label.visible and phase == Phase.GAMEOVER and mp_mode == "" and Net.vote_ok() and not vote_panel.visible
	if vote_over_btn.visible:
		var lh := over_label.get_line_count() * over_label.get_line_height() if over_label.text != "" else 0
		vote_over_btn.position = Vector2(over_label.position.x + (over_label.size.x - vote_over_btn.size.x) / 2.0, over_label.position.y + lh + 34.0)  # 바탕 끝 나가는 법 줄 아래
	hud.visible = not title_label.visible  # 시작 화면엔 메뉴에 최고 기록이 따로 있다
	# 시작 화면에서 일시정지·배속 버튼을 누르면 메뉴 위에 일시정지 창이 뜨던 문제
	# 게임 중엔 펼쳤을 때만 보인다 (단축키 M·P·Space는 접어도 된다). 시작 화면엔 소리·자동 시작만
	var in_game := not title_label.visible
	bar_btn.visible = in_game
	# 펼쳤을 땐 좁은 ▶만 (버튼 줄이 왼쪽 아래 안내 문구까지 뻗지 않게)
	bar_btn.text = "▶" if bar_open else "◀ 설정"
	bar_btn.custom_minimum_size.x = 40.0 if bar_open else 96.0
	bar_btn.tooltip_text = "설정 버튼 접기" if bar_open else "소리·자동 시작·일시정지·배속 버튼 펼치기"
	mute_btn.visible = not in_game or bar_open
	auto_btn.visible = not in_game or bar_open
	pause_btn.visible = in_game and bar_open
	speed_group.visible = in_game and bar_open
	speed_btn.visible = in_game and bar_open
	speed_pick.visible = in_game and bar_open
	fx_pick.visible = in_game and bar_open
	hud_cool -= delta
	_update_hud()
	# 일시정지 위에 설정·도움말 등을 열면 일시정지 글·버튼은 잠깐 숨기고, 어둠은 남겨 창이 그 위에 뜬다 (창 z 22 > 어둠 20)
	var over := settings_panel.visible or help_label.visible or records_panel.visible or notes_panel.visible or codex_panel.visible or vote_panel.visible
	var dim := get_tree().paused and not title_label.visible and phase != Phase.GAMEOVER
	var show_pause := dim and not over and not tut_paused  # 튜토리얼이 멈춘 것은 일시정지 창 없이
	paused_label.visible = show_pause
	pause_box.visible = show_pause
	pause_dim.visible = dim
	# 카드 선택 중: 카드 밖은 검은 막 (닫히면 곧바로 걷는다). 카드를 내리면(필드 보기) 막도 걷는다
	card_dim.visible = _card_dim_on()
	_update_place_dim()
	# 일시정지 창 버튼이 어둠 밑 카드 글 위에 겹쳐 읽기 힘들던 것 (폰·글자 130%): 멈춘 동안 카드 줄은 더 옅게
	choice_box.modulate.a = 0.25 if dim else 1.0
	if pause_box.visible:
		# 글자를 키우면(설정) 가운데 기준 자리가 점수 줄에 닿는다: 점수 줄 아래로
		paused_label.position.y = maxf(ui_root.size.y / 2.0 - 248.0, hud.get_rect().end.y + 8.0 if hud.visible else 8.0)
		pause_box.position.y = paused_label.position.y + paused_label.size.y + 10.0
		pause_box.size.x = 0.0  # 버튼 수(튜토리얼·끄기)만큼 넓어져도 가운데
		pause_box.position.x = floorf((ui_root.size.x - pause_box.get_combined_minimum_size().x) / 2.0)
	if vote_panel.visible:
		# 넓은 화면(폰 가로·와이드)에서는 투표 창을 넓혀 카드 설명이 덜 잘리게 (860 고정이라 설명 끝이 … 로 많이 잘렸다)
		var vh := clampf((ui_root.size.x - 48.0) / 2.0, 430.0, 580.0)
		vote_panel.offset_left = -vh
		vote_panel.offset_right = vh
	_fit_panels()
	_refresh_dps()
	_soften_fx()
	queue_redraw()
	info.queue_redraw()
	if phase == Phase.MOVE and moving and not get_tree().paused:
		moving.position = _pointer_world().clamp(field_rect().position, field_rect().end)
	_update_press()
	if boxing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_box()  # 창 밖에서 손을 떼 놓기 이벤트를 못 받은 경우
	card_detail_btn.visible = phase == Phase.CHOOSE and not title_label.visible and coin_stage == 0 and not cards_hidden and not perk_mode
	_update_skip_ui()
	cancel_btn.visible = phase in [Phase.PLACE, Phase.AIM, Phase.MOVE] and not title_label.visible and not get_tree().paused
	if speed_btn.visible:
		speed_btn.queue_redraw()
	# 카드 줄은 오른쪽 설명을 피해 왼쪽으로 비켜 있다. 설명을 숨기면 가운데로, 버튼도 카드 가운데에 맞춘다
	var cx := 0.0 if legend_hidden else -75.0
	# 카드 4장이 오른쪽 설명 밑으로 들어가면(글자 크게) 쉬는 시간 동안 설명을 접고 가운데로
	if legend.visible and phase == Phase.CHOOSE and choice_box.get_child_count() > 3 and ui_root.size.x / 2.0 + cx + 365.0 > legend.position.x - 8.0:
		legend.visible = false
		cx = 0.0
	# 글자를 키우면(설정) 카드 줄 오른쪽이 설명 밑으로 들어가던 것: 설명 왼쪽까지 들어가게 왼쪽으로 옮기고, 모자라면 줄인다
	var room := (legend.get_rect().position.x - 8.0) if legend.visible else ui_root.size.x - 8.0
	var half := maxf(365.0, choice_box.get_combined_minimum_size().x / 2.0)  # 카드 4장은 730보다 넓다
	var kw := minf((room - 8.0) / (half * 2.0), 1.0)
	# 새로고침·내리기 버튼은 카드 바로 아래 한 줄에 (카드가 길어지면 버튼이 카드 글을 덮던 것).
	# 카드+버튼 줄이 왼쪽 아래 안내 글에 닿으면 카드 줄을 위로 올리고, 그래도 모자라면(글자 크게) 0.7배까지 줄인다
	var mid := ui_root.size.y / 2.0
	var ch := choice_box.get_combined_minimum_size().y
	var lim := _bottom_free() - 6.0
	var floor_y := (hud.position.y + hud.size.y + 8.0) if hud.visible else 8.0
	if dps_panel.visible and ui_root.size.x / 2.0 + cx - 365.0 < 320.0:
		floor_y += 44.0 + 48.0 + 6.0  # 왼쪽 위 DPS 표(머리 + 2줄, 나머지는 굴려 봄)를 덮지 않게
	if guide_label.visible:
		floor_y = maxf(floor_y, (guide_more.get_rect().end.y if guide_more.visible else guide_label.get_rect().end.y) + 26.0)  # 처음 안내 글이 카드 글 뒤로 겹치던 것 (고르기 꼬리표 자리 포함)
	var need := ch + 8.0 + 40.0
	var k := clampf(minf((lim - floor_y) / need, kw), minf(0.7, kw), 1.0)
	cx = minf(cx, room - half * k - ui_root.size.x / 2.0)
	cx = maxf(cx, 8.0 + half * k - ui_root.size.x / 2.0)
	choice_box.offset_left = cx - half
	choice_box.offset_right = cx + half
	var ctop := maxf(minf(mid - 90.0, lim - need * k), floor_y)
	choice_box.pivot_offset = Vector2(choice_box.size.x / 2.0, 0.0)
	choice_box.scale = Vector2(k, k)
	choice_box.offset_top = ctop - mid
	choice_box.offset_bottom = choice_box.offset_top + ch
	_update_choice_header()
	var by := choice_box.offset_top + ch * k + 8.0
	# 카드 밑 한 줄 그림 버튼: [새로고침 N] [필드 보기] [넘기기] [×N]. 없는 버튼 자리는 당겨 가운데 맞춘다
	var row: Array = []
	for bt in [reroll_btn, card_detail_btn, skip_btn, skip_n_btn, apply_btn]:
		if bt.visible:
			row.append(bt)
	var bw := {reroll_btn: 96.0, card_detail_btn: 104.0, hide_btn: 76.0, skip_btn: 76.0, skip_n_btn: 76.0}
	if apply_btn.visible:
		bw = {reroll_btn: 76.0, card_detail_btn: 88.0, hide_btn: 60.0, skip_btn: 60.0, skip_n_btn: 60.0}
		bw[apply_btn] = maxf(120.0, ui_font.get_string_size(apply_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 50.0)
	var rw := -10.0
	for bt in row:
		rw += bw[bt] + 10.0
	var bx := cx - rw / 2.0
	for bt in row:
		bt.offset_left = bx
		bt.offset_right = bx + bw[bt]
		bt.offset_top = by
		bt.offset_bottom = by + 40.0
		bx += bw[bt] + 10.0
	if phase == Phase.READY and skip_btn.visible:
		# 웨이브 시작 대기: [웨이브 시작] 바로 오른쪽에 [넘기기] [×N]
		var pw: Vector2 = skip_btn.get_parent().size
		var sx := start_btn.position.x + start_btn.size.x + 10.0 - pw.x / 2.0
		var sy := start_btn.position.y + (start_btn.size.y - 40.0) / 2.0 - pw.y / 2.0
		for bt in [skip_btn, skip_n_btn]:
			bt.offset_left = sx
			bt.offset_right = sx + 76.0
			bt.offset_top = sy
			bt.offset_bottom = sy + 40.0
			sx += 86.0
	_start_btn_layout()
	_skill_ui()
	card_dock.tick()
	restart_armed = maxf(restart_armed - delta, 0.0)
	end_armed = maxf(end_armed - delta, 0.0)
	if not get_tree().paused and not title_label.visible and phase != Phase.GAMEOVER:
		run_real += delta
	if get_tree().paused:
		fx_layer.queue_redraw()  # 멈춘 동안에도 오브젝트·구체 정보창은 마우스를 따라간다
		return
	# 도움말·설정 창을 보는 동안은 게임이 멈춘다 (읽는 사이 구체가 중앙에 닿거나 웨이브가 시작되지 않게)
	var reading := (help_label.visible or settings_panel.visible or records_panel.visible or notes_panel.visible) and not title_label.visible
	if countdown >= 0.0 and phase == Phase.READY:
		# 오브젝트를 끌거나 상자로 고르는 동안은 자동 시작을 멈춘다 (시작하면 끌던 것이 되돌아감)
		if press_t or boxing or reading:
			countdown = maxf(countdown, 1.0)
		else:
			countdown -= delta
		start_btn.text = _kh("%.1f초 뒤 시작 (Space: 바로)" % maxf(countdown, 0.0))
		if countdown <= 0.0:
			_start_wave()
	if reading:

		return
	_update_fx(delta)
	if phase != Phase.WAVE:
		for t in towers.get_children():
			t.fade_fx(delta)
		return
	if prof_on:
		_prof_add("UI·효과", us)
	# 배속: 한 프레임을 1배속 크기의 조각으로 나눠 여러 번 계산한다.
	# 공격 주기·충돌이 배속과 상관없이 1배속과 같게 나온다.
	var steps := ceili(game_speed)
	# 프레임이 한 번 크게 끊겨도(창 끌기·버벅임) 한 조각이 1/20초를 넘지 않게: 구체가 지뢰·벽을 건너뛰지 않는다
	var dt := minf(delta, 0.05) * game_speed / steps
	for i in steps:
		_sim_step(dt)
		if phase != Phase.WAVE:
			break


## 게임 시간 dt만큼 진행 (구체·발사체·장판 이동 → 판정 → 웨이브 종료 확인).
func _sim_step(delta: float) -> void:
	sim_id += 1
	var us := Time.get_ticks_usec() if prof_on else 0
	for layer in [orbs, projectiles, zones]:
		for n in layer.get_children():
			if not n.is_queued_for_deletion():
				n.step(delta)
	if prof_on:
		_prof_add("이동", us)

	if mp_extra_left > 0 and not mp_ghost:
		_mp_spawn_extra(delta)
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			# 가끔 몰려서 나온다
			spawn_timer = spawn_interval * (0.5 if randf() < 0.2 and wave >= 4 else 1.0)
			to_spawn -= 1
			# 5웨이브마다 마지막에 보스
			var boss := to_spawn == 0 and wave % 5 == 0
			_spawn_orb(Orb.Kind.BOSS if boss else -1, boss_plan if boss and boss_plan.get("wave", -1) == wave else {})
			if boss:
				boss_plan = {}
				big_banner("보스 등장!", Color(1, 0.35, 0.4))
				sfx.play("boss", 0.0)

	wave_time += delta
	run_game += delta
	_dps_sample(delta)
	_skill_tick(delta)
	# 콤보 유지 시간은 게임 시간으로 잰다: 배속을 올려도 점수가 달라지지 않는다
	if combo_t > 0.0 and not combo_hold:
		combo_t = maxf(combo_t - delta, 0.0)
		if combo_t <= 0.0 and combo >= 5:
			combo_end = [combo, combo_bonus, 1.5]
	_resolve(delta)
	_jam_tick()

	if mp_ghost:
		return  # 협동 참가자: 웨이브 끝·게임 오버는 호스트가 알려 준다
	if core_hp <= 0:
		_game_over()
	elif to_spawn == 0 and mp_extra_left == 0 and _alive_count(orbs) == 0:
		combo_hold = true  # 쉬는 시간·카드 고르기 동안 콤보가 끊기지 않게
		_log_wave()
		Vary.wave_done(wave, _my_towers())
		_achieve("first")
		Ach.on_wave_clear(wave, wave_dmg, core_hp, core_max)
		_ach_check()
		if wave >= 5 and mp_mode == "" and not TutPlay.on:
			Meta.map_best[Meta.run_key()] = [maxi(Meta.best_of(Meta.run_key())[0], wave), maxi(Meta.best_of(Meta.run_key())[1], score)]
			if Meta.MAP_IDS.all(func(id): return id in Meta.TRIAL_MAPS or Meta.best_of(Meta.key(id))[0] >= 5):
				_achieve("allmaps")
		var bonus := int(wave * 20 * Modes.mul())
		score += bonus
		_show_toast("웨이브 %d 클리어! +%d" % [wave, bonus])
		sfx.play("clear", 0.0)
		_show_mvp()
		if perks.has("regen"):
			_heal_core(_regen_take())
		if wave % 5 == 0:
			_submit_run(false)  # 5웨이브마다 진행 중 기록 (중간에 꺼도 서버에 남게)
		_mp_wave_cleared()
		if skip_left > 1 and not skip_stop:
			skip_left -= 1
			_skip_rest()
		elif skip_left > 0:
			_end_skip(false)
		elif wave % 5 == 0:
			_start_perk()
		else:
			_start_choose()


## 중앙 체력 비율로 위험 단계를 정한다. 단계가 올라가는 순간에만 큰 글·경고음 (설정에 따라 1배속).
## 회복해서 단계가 내려가면 다시 떨어질 때 또 알린다.
func _danger_of(hp: int) -> int:
	if hp <= 0 or hp * 4 <= core_max:
		return 2
	return 1 if hp * 2 <= core_max else 0


func _check_danger() -> void:
	var lv := _danger_of(core_hp)
	if lv > danger_lv and core_hp > 0:
		big_banner("중앙 위험! %d/%d" % [core_hp, core_max], Color(1, 0.3, 0.35) if lv == 2 else Color(1, 0.6, 0.3))
		sfx.play("danger", 0.0)
		if skip_left > 0 and not skip_stop and Meta.skip_danger:
			skip_stop = true
			_show_toast("중앙 위험: 이번 웨이브가 끝나면 넘기기를 멈춰요")
		if Meta.danger_slow and game_speed > 1.0:
			game_speed = 1.0
			_update_speed_btn()
			_show_toast("중앙 위험: 1배속으로 바꿨어요 (Space로 다시 빠르게)")
	danger_lv = lv


## 구체가 중앙 점에 닿았나. 회랑 맵은 끝의 문(세로선)에 닿으면.
## 구체가 중앙에서 r 안에 들어왔나 (회랑 맵은 문까지의 가로 거리).
func _near_core(o: Orb, r: float) -> bool:
	if Meta.map_id == "line":
		return absf(o.position.x - core().x) < r + o.radius()
	return o.position.distance_to(center()) < r + o.radius()


func _reached_core(o: Orb) -> bool:
	if Meta.map_id == "line":
		return absf(o.position.x - core().x) < CORE_RADIUS + o.radius()
	return o.position.distance_to(center()) < CORE_RADIUS + o.radius()


## 중앙에 닿은 구체를 기록하고, 그 구체가 들어온 화면 가장자리를 붉게 번지게 한다.
func _record_leak(o: Orb, hp_lost: int) -> void:
	wave_leaks.append([_lane_of(o.from_a), o.kind, o.core_dmg, hp_lost])
	leak_flash.append([Vector2(core().x, o.position.y) if Meta.map_id == "line" else _entry_point(o.from_a), 1.2])
	_guide("leak", "구체가 중앙에 닿았어요. 붉게 번쩍인 가장자리 쪽 길목이 비어 있어요. 쉬는 시간에 그쪽으로 오브젝트를 옮기거나 새로 놓으세요")


## 각도 a에서 가장 가까운 진입 방향 번호 (없으면 -1).
func _lane_of(a: float) -> int:
	var best := -1
	var bd := INF
	for i in lanes.size():
		var d := absf(angle_difference(a, lanes[i]))
		if d < bd:
			bd = d
			best = i
	return best


## 각도 a에서 나온 구체가 화면에 들어오는 자리 (소용돌이 맵은 나선을 따라).
func _entry_point(a: float) -> Vector2:
	if Meta.map_id == "spiral":
		var vr := arena()
		for q in _orb_path(a):
			if vr.has_point(q):
				return q
	return _edge_point(center(), Vector2.from_angle(a))


## 8방위 이름 (화면 위가 북).
static func compass(a: float) -> String:
	return ["동", "남동", "남", "남서", "서", "북서", "북", "북동"][posmod(roundi(a / (PI / 4.0)), 8)]


## 웨이브가 끝나면(클리어·게임 오버) 누수를 한 줄로 요약해 둔다.
func _log_wave() -> void:
	if wave <= 0 or (not leak_log.is_empty() and leak_log[-1]["w"] == wave):
		return
	var by_lane := {}
	var kinds := {}
	var kdmg := {}
	var dmg := 0
	var lost := 0
	for l in wave_leaks:
		by_lane[l[0]] = by_lane.get(l[0], 0) + 1
		kinds[l[1]] = kinds.get(l[1], 0) + 1
		kdmg[l[1]] = kdmg.get(l[1], 0) + l[2]
		dmg += l[2]
		lost += l[3] if l.size() > 3 else l[2]
	var dirs := {}
	leak_marks.clear()
	for i in by_lane:
		dirs[compass(lanes[i]) if i >= 0 and i < lanes.size() else "?"] = by_lane[i]
		if i >= 0 and i < lanes.size():
			leak_marks.append([lanes[i], by_lane[i]])
	leak_log.append({"w": wave, "n": wave_leaks.size(), "dmg": dmg, "lost": lost, "dirs": dirs, "kinds": kinds, "kdmg": kdmg, "towers": towers.get_child_count(), "lanes": lanes.size(), "core": core_hp})
	if leak_log.size() > 200:
		leak_log.pop_front()


## 지난 웨이브 누수 안내 한 줄 ("지난 웨이브 누수: 북동쪽 3개(빠른 2) · 남쪽 1개"), 없으면 빈 문자열.
func _leak_text() -> String:
	if leak_log.is_empty() or leak_log[-1]["w"] != wave or leak_log[-1]["n"] == 0:
		return ""
	var e: Dictionary = leak_log[-1]
	var parts := PackedStringArray()
	for d in e["dirs"]:
		parts.append("%s쪽 %d개" % [d, e["dirs"][d]])
	var names := {Orb.Kind.NORMAL: "일반", Orb.Kind.FAST: "빠른", Orb.Kind.TANK: "단단한", Orb.Kind.BOSS: "보스"}
	var ks := PackedStringArray()
	for k in e["kinds"]:
		ks.append("%s %d" % [names.get(k, "?"), e["kinds"][k]])
	return "지난 웨이브에 놓친 구체: %s (%s, 중앙 체력 -%d)" % [" · ".join(parts), ", ".join(ks), e["dmg"]]


const LEAK_KIND_KEYS := {Orb.Kind.NORMAL: "normal", Orb.Kind.FAST: "fast", Orb.Kind.TANK: "tank", Orb.Kind.BOSS: "boss"}


## 서버로 보낼 웨이브별 중앙 피해 기록: 웨이브마다 닿은 구체 수·구체가 준 피해·실제로 깎인 체력(실드 뺀 값)·웨이브 끝 체력·종류별 수와 피해.
## 닿지 않은 웨이브도 n 0으로 들어간다 (웨이브별 비율을 낼 수 있게).
func _leak_records() -> Array:
	var out: Array = []
	for e in leak_log:
		var kinds := {}
		var kdmg := {}
		for k in e.get("kinds", {}):
			kinds[LEAK_KIND_KEYS.get(int(k), "other")] = int(e["kinds"][k])
		for k in e.get("kdmg", {}):
			kdmg[LEAK_KIND_KEYS.get(int(k), "other")] = int(e["kdmg"][k])
		out.append({"w": int(e["w"]), "n": int(e["n"]), "dmg": int(e["dmg"]), "lost": int(e.get("lost", e["dmg"])), "hp": int(e.get("core", 0)), "kinds": kinds, "kdmg": kdmg})
	return out


func _alive_count(n: Node) -> int:
	var c := 0
	for x in n.get_children():
		if not x.is_queued_for_deletion():
			c += 1
	return c


func _resolve(delta: float) -> void:
	var us := Time.get_ticks_usec() if prof_on else 0
	var rect := arena().grow(40.0)
	live_orbs = orbs.get_children().filter(func(o): return not o.is_queued_for_deletion())
	# 공격은 전장에 들어오기 시작한 구체에만 닿는다 (가장자리가 전장 안으로 들어온 구체. 폰처럼 화면이 넓어도 전장 밖 구체는 안 맞는다)
	var screen := arena()
	targets = live_orbs.filter(func(o): return screen.grow(o.radius()).has_point(o.position))

	_build_grid()
	star_towers = towers.get_children().filter(func(t): return t.elements.has(Elem.STAR))
	_wind_buffs()
	if prof_on:
		us = _prof_add("목록·격자", us)
	# 오브젝트 공격
	for t in towers.get_children():
		if not t.is_queued_for_deletion():
			t.attack(delta, targets)
	if prof_on:
		us = _prof_add("오브젝트 공격", us)

	# 바닥 효과
	for z in zones.get_children():
		if not z.is_queued_for_deletion():
			z.affect(z.trail_orbs(self) if z.kind == "trail" else near(z.position, z.radius if z.kind != "mine" else 80.0), delta)
	if prof_on:
		us = _prof_add("장판", us)

	# 발사체
	for p in projectiles.get_children():
		if p.is_queued_for_deletion():
			continue
		if not rect.has_point(p.position):
			p.queue_free()
			continue
		if p.finished():
			p.end_form()
			p.queue_free()
			continue
		if p.lob:
			continue
		# 이번 프레임에 지나온 선분으로 판정해 고배속에서도 뚫고 지나가지 않게
		var prev: Vector2 = p.position - p.vel * delta
		for o in near(p.position, p.radius + p.vel.length() * delta):
			if o.hp > 0.0 and Geometry2D.get_closest_point_to_segment(o.position, prev, p.position).distance_to(o.position) < o.radius() + p.radius:
				if p.on_hit(o, delta):
					if p.kind == "shard":
						_shatter(p)
					p.queue_free()
					break
	if prof_on:
		us = _prof_add("발사체 판정", us)

	# 구체 처치 / 중앙 도달 (협동 참가자는 호스트가 보낸 대로)
	for o in (live_orbs if not mp_ghost else []):
		if o.hp <= 0.0:
			_jam_death(o)
			sfx.play("kill", 0.15)
			combo_hold = false
			if combo_t <= 0.0:
				combo = 0
				combo_bonus = 0
			combo += 1
			combo_t = COMBO_KEEP
			best_combo = maxi(best_combo, combo)
			Ach.on_kill(o, run_game, combo)
			ach_dirty = true
			if combo >= 30:
				_achieve("combo30")
			# 모드가 늘린 체력·수는 빼고 매긴 뒤 모드 배율을 곱한다
			var base: float = o.max_hp * Modes.kill_k(o.kind == Orb.Kind.BOSS, o.minion) * 10 * Modes.mul() * Vary.score_k()
			var gain := int(base * combo_mul())
			score += gain
			combo_bonus += gain - int(base)
			if combo == 20:
				combo_max_flash = 0.8
				popup(o.position + Vector2(0, -20), combo, Color(1, 0.85, 0.2), true, "콤보 20! 점수 x3", 1.2)
			elif combo >= 3 and combo % 5 == 0:
				popup(o.position + Vector2(0, -20), combo, Color(1, 0.7, 0.3), true, "콤보 %d! 점수 x%.1f" % [combo, combo_mul()])
			if o.splits:
				for i in 2:
					_spawn_child(o)
			if o.kind == Orb.Kind.BOSS:
				_heal_core(2)
				bonus_rerolls += 1
				_achieve("boss")
				_show_toast("보스 처치! 중앙 체력 +2" + ("" if Modes.has("narrow") else ", 새로고침 +1"))
			burst(o.position, o.death_color(), 10 if o.kind != Orb.Kind.BOSS else 40, 180.0)
			kills += 1
			for t in towers.get_children():
				if t.tg("charge") > 0 and t.position.distance_to(o.position) < Rules.t("charge_r"):
					t.add_charge(o)
			if o.kind == Orb.Kind.BOSS:
				shake = 0.4
			if o.poison_t > 0.0:
				for other in targets:
					if other != o and other.position.distance_to(o.position) < 80.0:
						other.poison(o.poison_dps, 3.0, o.poison_src, o.poison_rx, o.poison_key)
				Share.contagion(o)  # 독 전염: 효과도 번짐
			if o.vuln_t > 0.0:
				Share.pull(o)  # 어둠 끌어당김
			if o.soul_t > 0.0:
				_soul_wisp(o)
			o.queue_free()
			continue
		if rampart_left > 0 and not o.walled and not o.ghost and _near_core(o, RAMPART_R):
			# 성벽: 구체 하나당 한 번 밀어내고 한 조각 부서진다
			o.walled = true
			rampart_left -= 1
			o.position += (o.position - o.target).normalized() * _perk_val("rampart_push") * (0.5 if o.kind == Orb.Kind.BOSS else 1.0)
			burst(o.position, Color(0.75, 0.6, 0.45), 12, 160.0)
			sfx.play("hit", 0.0)
		if _reached_core(o):
			var hit_p: Vector2 = o.position if Meta.map_id == "line" else center()
			var dmg: int = o.core_dmg - _shield_absorb(o.core_dmg)
			if perks.has("riposte"):
				_riposte(hit_p)
			if dmg <= 0:
				sfx.play("shield", 0.0)
				burst(hit_p, Color(0.55, 0.85, 1.0), 14, 200.0)
				popup(hit_p + Vector2(0, -CORE_RADIUS - 24.0), 0, Color(0.55, 0.85, 1.0), true, "실드", 0.9)
				_record_leak(o, 0)
				o.queue_free()
				continue
			core_hp -= dmg
			if TutPlay.on:
				core_hp = maxi(core_hp, 1)  # 연습 판은 지지 않는다
			sfx.play("core", 0.0)
			shake = 0.25 + 0.1 * dmg
			core_flash = 0.4
			burst(hit_p, Color(1, 0.3, 0.35), 18, 220.0)
			_show_toast("중앙 피격! %d/%d" % [maxi(core_hp, 0), core_max])
			wave_dmg += dmg
			Ach.on_core_hit(dmg)
			popup(hit_p + Vector2(0, -CORE_RADIUS - 24.0), dmg, Color(1, 0.3, 0.35), true, "-%d" % dmg, 1.2)
			_check_danger()
			_record_leak(o, dmg)
			o.queue_free()
			continue

	if ach_dirty:
		ach_dirty = false
		_ach_check()
	for a in arcs:
		a[2] -= delta
	arcs = arcs.filter(func(a): return a[2] > 0.0)
	if prof_on:
		_prof_add("처치·나머지", us)


## 부분별 계산 시간(µs)을 더하고 지금 시각을 돌려준다.
func _prof_add(part: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	prof[part] = prof.get(part, 0) + now - since
	return now


## 구체 위치 격자: 발사체·장판이 가까운 구체만 확인하도록.
const GRID := 64.0
var grid := {}


func _build_grid() -> void:
	grid.clear()
	for i in targets.size():
		var o: Orb = targets[i]
		o.ti = i
		var k := Vector2i(floori(o.position.x / GRID), floori(o.position.y / GRID))
		if grid.has(k):
			grid[k].append(o)
		else:
			grid[k] = [o]


## 오브젝트를 놓을 수 있는 전장 안쪽 영역 (가장자리에서 몸 반지름만큼 안).
func field_rect() -> Rect2:
	return arena().grow(-(Tower.RADIUS + 6.0))


## p에서 r(+가장 큰 구체 반지름) 안에 있을 수 있는 구체들.
func near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var rr := r + 32.0
	for x in range(floori((p.x - rr) / GRID), floori((p.x + rr) / GRID) + 1):
		for y in range(floori((p.y - rr) / GRID), floori((p.y + rr) / GRID) + 1):
			var cell = grid.get(Vector2i(x, y))
			if cell:
				for o in cell:
					if is_instance_valid(o) and not o.is_queued_for_deletion():
						out.append(o)
	return out


## 오브젝트 공격용: p에서 r 안에 있을 수 있는 구체를 targets 순서 그대로.
## 전체를 돌던 때와 맞히는 순서(그래서 치명타 등 난수 순서)가 같다.
## 공격 중에 바람에 밀린 만큼(한 조각에 밀림 여유 최대 40)도 빠지지 않게 여유를 둔다.
## 구체가 적거나 범위가 넓어 칸 수가 구체의 1/3을 넘으면 그냥 전체를 준다 (칸 조회가 구체 확인보다 비싸다).
func near_t(p: Vector2, r: float) -> Array:
	var rr := r + 32.0 + 40.0
	var x0 := floori((p.x - rr) / GRID)
	var x1 := floori((p.x + rr) / GRID)
	var y0 := floori((p.y - rr) / GRID)
	var y1 := floori((p.y + rr) / GRID)
	if (x1 - x0 + 1) * (y1 - y0 + 1) * 3 >= targets.size():
		return targets
	var idx := PackedInt32Array()
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var cell = grid.get(Vector2i(x, y))
			if cell:
				for o in cell:
					idx.append(o.ti)
	idx.sort()
	var out: Array = []
	out.resize(idx.size())
	for i in idx.size():
		out[i] = targets[idx[i]]
	return out


func _update_fx(delta: float) -> void:
	danger_lv = mini(danger_lv, _danger_of(core_hp))
	for lf in leak_flash:
		lf[1] -= delta
	leak_flash = leak_flash.filter(func(lf): return lf[1] > 0.0)
	for p in popups:
		p[0] += Vector2(0, -40.0 * delta)
		p[2] -= delta
	popups = popups.filter(func(p): return p[2] > 0.0)
	for p in particles:
		p[0] += p[1] * delta
		p[1] *= 0.92
		p[2] -= delta
	particles = particles.filter(func(p): return p[2] > 0.0)
	for b in bolts:
		b[1] -= delta
	bolts = bolts.filter(func(b): return b[1] > 0.0)
	for q in pulses:
		q[2] -= delta
	pulses = pulses.filter(func(q): return q[2] > 0.0)
	for q in beams:
		q[3] -= delta
	beams = beams.filter(func(q): return q[3] > 0.0)
	shake = maxf(shake - delta, 0.0)
	combo_end[2] = maxf(combo_end[2] - delta, 0.0)
	combo_max_flash = maxf(combo_max_flash - delta, 0.0)
	core_flash = maxf(core_flash - delta, 0.0)
	riposte_cd = maxf(riposte_cd - delta, 0.0)
	for q in core_fx:
		q[2] -= delta
	core_fx = core_fx.filter(func(q): return q[2] > 0.0)
	for q in skill_fx:
		q[2] -= delta
	skill_fx = skill_fx.filter(func(q): return q[2] > 0.0)
	eclipse_flash = maxf(eclipse_flash - delta, 0.0)
	eclipse_cd = maxf(eclipse_cd - delta, 0.0)
	if not is_equal_approx(view_zoom, 1.0) and (title_label.visible or phase == Phase.GAMEOVER):
		_reset_zoom()  # 시작 화면·게임 오버는 1배로
	if not card_dock.active():  # 도크 전용 화면 영역의 카메라는 도크 레이아웃에서 정한다

		camera.position = center() + view_pan
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * shake * (1.0 if Meta.shake_on else 0.0)
	fx_layer.queue_redraw()


## 마우스를 올린 오브젝트의 정보.
func _draw_tooltip() -> void:
	tip_orb = null
	if card_dock != null and cards_hidden:
		return  # 전장 넓게 보기에서는 마우스 정보창도 접는다
	# 터치는 마우스를 올려 둘 수 없으니, 눌러서 옮기기 시작한 오브젝트의 정보를 보여 준다
	var touch_move := phase == Phase.MOVE and touch_ui and moving != null
	# 터치로 방향 바꾸기: 손가락은 쏠 쪽에 있으니 그 오브젝트 정보를 함께 보여 준다 ([자세히]로 수치까지)
	var touch_aim := phase == Phase.AIM and touch_ui and moving != null
	if (phase in [Phase.PLACE, Phase.GAMEOVER, Phase.MOVE, Phase.AIM] and not touch_move and not touch_aim) or title_label.visible or dragging or boxing:
		return
	# 터치는 손을 뗀 자리에 마우스가 남는다: 누르고 3초가 지나면 정보창을 닫는다
	if touch_ui and not touch_move and not touch_aim and touch_tip_t <= 0.0:
		return
	if dps_panel.visible and dps_panel.get_global_rect().has_point(_pointer_screen()):
		return  # DPS 표 위: 표 뒤에 가린 오브젝트 정보창이 뜨지 않게
	var t := moving if touch_move or touch_aim else _tower_at(_pointer_world())
	# 터치로 [자세히]를 누르면 손가락이 버튼으로 가서 정보창이 사라졌다: 방금 보던 오브젝트를 이어서
	if t == null and touch_ui and is_instance_valid(tip_tower) and detail_btn.visible \
			and detail_btn.get_global_rect().has_point(_pointer_screen()):
		t = tip_tower
	if t != null:
		tip_tower = t
		if card_dock.active():
			return  # 카드 도크 사용 중엔 전장 위를 덮지 않고 오른쪽 설명 칸에 표시한다
	if t == null:
		_draw_orb_tooltip()
		return
	tip_frame = Engine.get_process_frames()
	var z: float = _tip_scale()
	var fs := roundi(14 * z)
	var lh := 18.0 * z
	var maxw := minf(620.0 * z, _right_limit() - 24.0)  # 이보다 긴 줄은 접는다 (속성이 많으면 화면 밖으로 나가던 것)
	var lines: Array = []  # [글자, 색]
	var head := t.title()
	var tip := "(클릭: 선택 · 한 번 더 클릭: 방향 · 끌기: 옮기기)" if phase in [Phase.CHOOSE, Phase.READY] and not perk_mode else ""
	# Shift를 누르고 있으면 공격력·공격 속도·사거리 같은 수치를 자세히
	var detail := _tip_detail_on() and not touch_move
	tip = _th(tip)
	var acts := tip != ""  # 쉬는 시간: 클릭·끌기 안내도
	var ctrl := not touch_ui  # 마우스에선 조작 안내를 맨 아래 그림 줄로 (_draw_tip_ctrl)
	if not touch_ui:
		tip = "" if not detail else "(Shift 떼기: 돌아가기)"
	if touch_move:
		tip = "(새 자리 누르기: 옮기기 · 취소: 그대로)"
	elif touch_aim:
		tip = "(쏠 쪽 누르기: 방향 확정)"
	if tip != "" and ui_font.get_string_size(head + "   " + tip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= maxw:
		lines.append([head + "   " + tip, Color.WHITE])
	else:
		for row in _wrap_parts(head, "·", maxw, fs).split("\n"):
			lines.append([row, Color.WHITE])
		if tip != "":
			lines.append([tip, Color(1, 1, 1, 0.6)])
	var share_line := []
	if wave_time > 1.0:
		var total := 0.0
		for o in towers.get_children():
			total += o.dealt
		var share := " · %d%%" % roundi(t.dealt / total * 100.0) if total > 0.0 and towers.get_child_count() > 1 else ""
		share_line = ["%s %s%s" % ["이번 웨이브" if phase == Phase.WAVE else "지난 웨이브", Tower.tip_num(t.dealt), share], Color(1, 0.9, 0.5), "rank"]
	if not detail:
		# 기본: 피해·공격 속도·치명타·피해 몫 숫자만 (효과 설명·계산 내역은 자세히에서)
		lines += t.basic_lines()
		var afs: Array = Share.aff(t)["pairs"].map(func(pr): return Elem.aff_label(pr[0], pr[1]))
		if not afs.is_empty():
			lines.append(["상성: " + " · ".join(afs), Color(0.85, 1.0, 0.75)])
		var sts: Array = Share.sites_of(t.eff_now()).map(func(x): return x[2])
		if not sts.is_empty():
			lines.append(["자리: " + " · ".join(sts), Color(0.75, 0.9, 1.0)])
		if not share_line.is_empty():
			lines.append(share_line)
	else:
		# 자세히: 수치와 계산 내역 → 공격방식·속성·강화·반응 설명 → 버프·피해 몫. 화면을 넘으면 내역 줄부터 줄인다
		var nums: Array = t.detail_lines()
		var desc: Array = []
		desc.append(["%s Lv%d - %s" % [Pat.pname(t.pattern), t.plv, Pat.PATTERNS[t.pattern]["desc"]], Pat.pcolor(t.pattern).lightened(0.2), "p:" + t.pattern])
		var no := Pat.no_mods(t.pattern)
		if not no.is_empty():
			desc.append(["  못 넣는 강화(효과 없음): " + "·".join(no), Color(0.7, 0.7, 0.75)])
		for e in t.order:
			desc.append(["Lv%d %s" % [t.lv(e), Elem.rider(e)], Elem.COLORS[e], "e:%d" % e])
		var ex := t.extras_text()
		if t.mod_count() > 0 and Rules.mod_total < Rules.NO_CAP:
			ex = "강화 %d/%d" % [t.mod_count(), Rules.mod_total] + (" · " + ex if ex != "" else "")
		if ex != "":
			desc.append([ex, Color(1, 0.85, 0.45), "k:mod"])
		var rxs := t.reactions()
		if rxs.size() <= 5:
			for r in rxs:
				desc.append(["%s: %s" % [r["name"], r["desc"]], r["color"], "k:rx"])
		else:
			desc.append(["조합 %d개: %s" % [rxs.size(), ", ".join(rxs.map(func(r): return r["name"]))], Color(1, 0.8, 0.95), "k:rx"])
		for pr in Share.aff(t)["pairs"]:
			desc.append([Elem.aff_text(pr[0], pr[1]), AFF_COL["strong" if pr[2]["strong"] else "weak"], "k:rx"])
		for x in Share.sites_of(t.eff_now()):
			var nd: Array = Share.NAMED.get([x[0], x[1]], [])
			desc.append(["자리 %s%s" % [x[2], ": " + nd[1] if not nd.is_empty() else ""], Color(0.75, 0.9, 1.0), "k:rx"])
		_wind_buffs()  # 쉬는 시간에 새로 놓은 오브젝트도 바로 보이게
		var tail: Array = []
		if t.wind_buff > 0.0:
			tail.append(["바람 버프: 공격 속도 +%d%%" % roundi(t.wind_buff * 100.0), Elem.COLORS[Elem.WIND], "e:%d" % Elem.WIND])
		if not share_line.is_empty():
			tail.append(share_line)
		var avail := floori((_tip_bottom() - _tip_top() - 18.0) / lh)
		var all: Array = lines + nums + desc + tail
		if _tip_rows(all, maxw, fs) > avail:
			# 1) 계산 내역(들여 쓴 흐린 줄)을 뺀다
			nums = nums.filter(func(l): return not (l[0] as String).begins_with("  "))
			desc = desc.filter(func(l): return not (l[0] as String).begins_with("  "))
			all = lines + nums + desc + tail
		if _tip_rows(all, maxw, fs) > avail:
			# 2) 반응·속성 효과를 한 줄씩으로
			var keep: Array = desc.filter(func(l): return not (l.size() > 2 and ((l[2] as String).begins_with("e:") or l[2] == "k:rx")))
			var riders: Array = t.order.map(func(e): return Elem.rider_name(e))
			keep.append(["속성 효과: " + "·".join(riders), Color(0.85, 0.85, 0.9), "k:elem"])
			if not rxs.is_empty():
				keep.append(["조합 %d개: %s" % [rxs.size(), ", ".join(rxs.map(func(r): return r["name"]))], Color(1, 0.8, 0.95), "k:rx"])
			var afs: Array = Share.aff(t)["pairs"].map(func(pr): return Elem.aff_label(pr[0], pr[1]))
			if not afs.is_empty():
				keep.append(["상성: " + " · ".join(afs), Color(0.85, 1.0, 0.75), "k:rx"])
			desc = keep
			all = lines + nums + desc + tail
		lines = all
	# 줄 앞 그림(l[2])은 왼쪽 gut 칸에. 접힌 줄은 첫 줄에만 그림
	var gut := 20.0 * z
	var rows: Array = []
	var w := 0.0
	for l in lines:
		var lw := ui_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if lw <= maxw:
			rows.append(l)
			w = maxf(w, lw)
			continue
		var k := 0
		for row in _wrap_words(l[0], maxw, fs).split("\n"):
			rows.append([row, l[1], l[2] if l.size() > 2 and k == 0 else ""])
			w = maxf(w, ui_font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			k += 1
	lines = rows
	if ctrl and not detail:
		w = maxf(w, (250.0 if acts else 90.0) * z)
	w += gut
	var h := (lines.size() + (1 if ctrl and not detail else 0)) * lh + 10.0
	var vw := view_rect()
	var size := vw.end  # 화면 오른쪽 아래 끝 (월드 좌표. 폰은 전장 밖 양옆까지)
	size.y = _tip_bottom()
	var p := t.position + Vector2(28, -h / 2)
	if touch_aim and _pointer_world().x > t.position.x:
		p.x = t.position.x - 28.0 - (w + 16.0)  # 손가락(쏠 쪽) 반대편에
	p.x = clampf(p.x, vw.position.x + 8, _right_limit() - w - 16)
	var top := _tip_top()
	p.y = clampf(p.y, top if h <= size.y - top - 8.0 else vw.position.y + 8.0, size.y - h - 8)
	# 오른쪽 설명에 밀려 왼쪽으로 오면 오브젝트를 덮는다: 위나 아래로 비킨다
	if Rect2(p, Vector2(w + 16, h)).intersects(Rect2(t.position - Vector2(26, 26), Vector2(52, 52))):
		var above := t.position.y - 30.0 - h
		p.y = above if above >= top else minf(t.position.y + 30.0, size.y - h - 8)
	p = _avoid_cards(Rect2(p, Vector2(w + 16, h)), size)
	# 아래 안내 글·넘기기 표시·[선택지 보기]는 UI라 정보창 위에 그려져 글이 섞인다: 겹치는 동안 옅게
	for c in [hint, skip_badge, hide_btn]:
		if c.visible and c.text != "" and Rect2(p, Vector2(w + 16, h)).intersects(get_canvas_transform().affine_inverse() * c.get_global_rect()):
			tip_fade[c] = Engine.get_process_frames()
	fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(0.05, 0.06, 0.09, 0.92))
	fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(1, 1, 1, 0.2), false, 1.0)
	for i in lines.size():
		fx_layer.draw_string(ui_font, p + Vector2(8 + gut, 6 + fs + i * lh), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lines[i][1])
		if lines[i].size() > 2 and lines[i][2] != "":
			_tip_icon(lines[i][2], p + Vector2(8 + gut * 0.45, 6 + i * lh + lh * 0.5), 6.0 * z, lines[i][1])
	if ctrl and not detail:
		_draw_tip_ctrl(p + Vector2(8, 6 + lines.size() * lh), fs, lh, acts)


## 정보창 자세히: Shift를 누르고 있거나 터치 [자세히]. 기본 정보창은 숫자만, 올린 오브젝트는 공격 범위만 그리고
## 별 흡수 둘레·바람 버프 둘레(주변과 주고받는 범위)는 자세히일 때만.
func _tip_detail_on() -> bool:
	return Input.is_key_pressed(KEY_SHIFT) or (touch_ui and tip_detail)


## 자세히일 때 둘레를 그릴 오브젝트: 마우스 아래, 터치는 [자세히]를 누르느라 손가락이 떠나도 정보창의 오브젝트.
func _ring_target() -> Tower:
	if not _tip_detail_on():
		return null
	if card_dock.active() and card_dock.side.visible:
		return card_dock.shown_tower
	var h := _tower_at(_pointer_world())
	if h == null and touch_ui and is_instance_valid(tip_tower) and Engine.get_process_frames() - tip_frame <= 2:
		h = tip_tower
	return h


## 정보창 줄 앞 그림: "p:공격방식" · "e:속성" · "k:카드 종류" · 그 밖은 Glyph.ui.
func _tip_icon(id: String, c: Vector2, s: float, col: Color) -> void:
	match id.left(2):
		"p:": Glyph.pat(fx_layer, id.substr(2), c, s, col)
		"e:": Glyph.elem(fx_layer, int(id.substr(2)), c, s)
		"k:": Glyph.kind(fx_layer, id.substr(2), c, s, col)
		_: Glyph.ui(fx_layer, id, c, s, Color(col, 1.0))


## 조합 카드 자리: 그 오브젝트 오른쪽·왼쪽·위·아래 중 UI(카드 줄·설명·점수 줄)·다른 오브젝트·중앙을 가장 덜 가리는 곳 (ui_root 좌표).
## 카드를 넣는 단계(PLACE)에는 놓을 곳을 가리지 않게 감추고, 시작 화면·게임 오버면 닫는다.
func _place_rx_card() -> void:
	if rx_card == null or not rx_card.visible:
		return
	if title_label.visible or phase == Phase.GAMEOVER:
		rx_card.hide_card()
		return
	rx_card.self_modulate.a = 0.0 if phase in [Phase.PLACE, Phase.AIM] else 1.0
	if not is_instance_valid(rx_card.tower):
		return
	var to_ui := ui_root.get_global_transform().affine_inverse() * get_canvas_transform()
	var o := to_ui * rx_card.tower.position
	var sz := rx_card.size
	var zs := to_ui.get_scale().x
	var gap := Tower.RADIUS * zs + 16.0
	var lo := Vector2(8.0, 44.0)
	var hi := (ui_root.size - sz - Vector2(8.0, 60.0)).max(lo)
	var cands: Array = []
	for kk in 4:
		var d := gap + kk * 36.0
		for ay in [0.35, 0.85, 0.0]:  # 옆자리는 오브젝트 높이에 맞춘 세 가지 (위 점수 줄·아래 카드 줄 중 빈 쪽으로)
			cands.append(Vector2(o.x + d, o.y - sz.y * ay))
			cands.append(Vector2(o.x - d - sz.x, o.y - sz.y * ay))
		cands.append(Vector2(o.x - sz.x * 0.5, o.y - d - sz.y))
		cands.append(Vector2(o.x - sz.x * 0.5, o.y + d))
	var blocks: Array = [[to_ui * center(), CORE_RADIUS * zs + 12.0]]
	for t in towers.get_children():
		blocks.append([to_ui * t.position, Tower.RADIUS * zs + 4.0])
	var ui_blocks := _info_blockers()
	if choice_box and choice_box.is_visible_in_tree():
		ui_blocks.append(ui_root.get_global_transform().affine_inverse() * choice_box.get_global_rect())
	var best := Rect2(cands[0] as Vector2, sz)
	var best_s := INF
	for p: Vector2 in cands:
		var q := p.clamp(lo, hi)
		var r := Rect2(q, sz)
		var sc := q.distance_to(p) / 20.0 + p.distance_to(o) / 80.0
		for bl in blocks:
			var bp: Vector2 = bl[0]
			if bp.clamp(r.position, r.end).distance_to(bp) < bl[1]:
				sc += 12.0
		for rect in ui_blocks:
			if r.intersects(rect):
				sc += 1000.0 + r.intersection(rect).get_area()
		if sc < best_s:
			best_s = sc
			best = r
	if best_s >= 1000.0 and rx_card.shrink_to_one():
		_place_rx_card()  # 두 장이 UI에 걸리면 한 장 + "+N"으로 다시 자리를 잡는다
		return
	rx_card.position = best.position


## 정보창 글 배율: 폰은 화면이 작아 다른 글보다 14px 정보창이 유난히 작게 읽혔다
func _tip_scale() -> float:
	return Meta.ui_scale * (1.2 if _phone() else 1.0)


## 정보창 맨 아래 조작 줄 (마우스): [왼쪽 단추] 방향 · [끌기] 옮기기 · [Shift] 자세히.
func _draw_tip_ctrl(at: Vector2, fs: int, lh: float, acts: bool) -> void:
	var z: float = _tip_scale()
	var f := maxi(11, fs - 2)
	var x := at.x
	var y := at.y + lh * 0.5
	var dim := Color(1, 1, 1, 0.6)
	var items := [["click", "선택"], ["drag", "옮기기"], ["Shift", "자세히"]] if acts else [["Shift", "자세히"]]
	for it in items:
		if it[0] == "Shift":
			var kw := ui_font.get_string_size("Shift", HORIZONTAL_ALIGNMENT_LEFT, -1, f - 1).x + 8.0
			Glyph.keycap(fx_layer, ui_font, Vector2(x + kw, y - (f + 4) * 0.5), "Shift", f - 1)
			x += kw + 4.0
		else:
			Glyph.ui(fx_layer, it[0], Vector2(x + 6.0 * z, y), 7.0 * z, dim)
			x += 16.0 * z
		fx_layer.draw_string(ui_font, Vector2(x, y + f * 0.36), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, f, dim)
		x += ui_font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, f).x + 12.0 * z


## 정보창 줄들을 maxw로 접었을 때 줄 수.
func _tip_rows(lines: Array, maxw: float, fs: int) -> int:
	var n := 0
	for l in lines:
		n += 1 if ui_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= maxw else _wrap_words(l[0], maxw, fs).count("\n") + 1
	return n


## 정보창을 놓을 수 있는 위쪽 끝: 점수 줄 아래 (점수 줄이 정보창 첫 줄을 덮던 것).
func _tip_top() -> float:
	if not hud.visible:
		return 8.0
	return (get_canvas_transform().affine_inverse() * hud.get_global_rect()).end.y + 6.0


## 정보창을 놓을 수 있는 아래쪽 끝: 화면 끝, 터치 [자세히]·[간단히] 버튼이 떠 있으면 그 위 (정보창이 버튼을 덮던 것).
func _tip_bottom() -> float:
	var b := view_rect().end.y
	if touch_ui and detail_btn != null and detail_btn.visible:
		b = minf(b, (get_canvas_transform().affine_inverse() * detail_btn.get_global_rect()).position.y - 6.0)
	return b


## 글자를 놓을 수 있는 오른쪽 끝: 오른쪽 설명이 떠 있으면 그 앞까지 (설명이 글자를 가린다).
func _right_limit() -> float:
	var r := view_rect().end.x - 8.0
	if legend.visible:
		r = minf(r, (get_canvas_transform().affine_inverse() * legend.get_global_rect()).position.x - 8.0)
	return r


## 선택지 카드가 떠 있으면 툴팁이 카드 뒤에 가려지지 않게 위나 아래로 비킨다.
func _avoid_cards(r: Rect2, size: Vector2) -> Vector2:
	if not choice_box.visible or choice_box.get_child_count() == 0 or cards_hidden:
		return r.position
	var inv := get_canvas_transform().affine_inverse()
	var cr: Rect2 = inv * choice_box.get_global_rect()
	for b in [reroll_btn, hide_btn, skip_btn, skip_n_btn]:
		if b.visible:
			cr = cr.merge(inv * b.get_global_rect())
	cr = cr.grow(6.0)
	if not cr.intersects(r):
		return r.position
	var up := cr.position.y - r.size.y
	var down := cr.end.y
	if up >= view_rect().position.y + 8.0 and (r.get_center().y < cr.get_center().y or down + r.size.y > size.y - 8.0):
		return Vector2(r.position.x, up)
	if down + r.size.y <= size.y - 8.0:
		return Vector2(r.position.x, down)
	return r.position


## 마우스를 올린 구체의 체력·상태.
func _draw_orb_tooltip() -> void:
	var m := _pointer_world()
	# 작은 구체도 잡기 쉽게 최소 14 안, 여럿이면 가장 가까운 것
	var o: Orb = null
	var bd := INF
	for x in live_orbs:
		if not is_instance_valid(x) or x.hp <= 0.0:
			continue
		var d: float = x.position.distance_to(m)
		if d <= maxf(x.radius() + 4.0, 14.0) and d < bd:
			o = x
			bd = d
	tip_orb = o
	if o:
		var kinds := ["구체", "빠른 구체", "단단한 구체", "보스"]
		var parts := PackedStringArray([kinds[o.kind], "체력 %d/%d" % [ceili(o.hp), roundi(o.max_hp)]])
		if o.shield > 0.0: parts.append("보호막 %d" % ceili(o.shield))
		if o.splits: parts.append("분열")
		if o.jam != "": parts.append(JAM_NAMES[o.jam])
		if o.amp.has("brand"): parts.append("낙인(받는 피해 +%d%%)" % roundi(Rules.t("skill_brand_amp") * 100))
		if o.burn_t > 0.0: parts.append("화상")
		if o.poison_t > 0.0: parts.append("중독")
		if o.root_immune > 0.0: parts.append("기절 면역")
		if o.vuln_t > 0.0: parts.append("받는 피해↑ +30%")
		if o.slow_timer > 0.0: parts.append("감속")
		if o.frozen_t > 0.0: parts.append("얼림")
		if o.tune_t > 0.0: parts.append("3타 음파 %d/3" % int(o.ring))
		if o.echo_t > 0.0: parts.append("피해 되풀이 %d%%" % roundi(o.echo_frac * 100))
		if o.soul_t > 0.0: parts.append("혼불 소환")
		if o.silence_t > 0.0: parts.append("침묵")
		if o.resist_e >= 0: parts.append("%s 저항" % Elem.NAMES[o.resist_e])
		if o.sturdy: parts.append("굳셈(밀기·감속·기절·냉기 절반)")
		if o.vine > 0.0: parts.append("덩굴 %d/3" % int(o.vine))
		if not o.amp.is_empty():
			# 받는 피해 증가 (낙인 등, 곱해서 하나로)
			var k := 1.0
			for v in o.amp.values():
				k *= 1.0 + v[0]
			if k > 1.005:
				parts.append("받는 피해↑ +%d%%" % roundi((k - 1.0) * 100.0))
		var fs := roundi(14 * _tip_scale())
		# 상태가 많으면(보스·후반) 한 줄이 화면·오른쪽 설명 밖으로 나간다: 들어가는 만큼씩 줄을 나눈다
		var maxw := minf(_right_limit() - 32.0, 620.0 * _tip_scale())
		var rows: Array[String] = [""]
		for part in parts:
			var cand: String = part if rows[-1] == "" else rows[-1] + " · " + part
			if rows[-1] != "" and ui_font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
				rows.append(part)
			else:
				rows[-1] = cand
		var w := 0.0
		for r in rows:
			w = maxf(w, ui_font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var lh := fs + 6.0
		var bh := lh * rows.size() + 4.0
		var p: Vector2 = o.position + Vector2(-w / 2 - 8, -o.radius() - 16 - bh)
		p.x = clampf(p.x, view_rect().position.x + 8.0, maxf(view_rect().position.x + 8.0, _right_limit() - w - 16))
		p.y = maxf(p.y, _tip_top())
		fx_layer.draw_rect(Rect2(p, Vector2(w + 16, bh)), Color(0.05, 0.06, 0.09, 0.9))
		for i in rows.size():
			fx_layer.draw_string(ui_font, p + Vector2(8, fs + 3 + lh * i), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## 중앙 점 스킨: 눈은 가장 가까운 구체를 본다, 태양은 빛살이 돈다.
func _draw_core_skin(c: Vector2, col: Color, now: float) -> void:
	match Meta.core_skin:
		"eye":
			var look := Vector2.ZERO
			var best := INF
			for o in orbs.get_children():
				var d2: float = (o.position - c).length_squared()
				if d2 < best:
					best = d2
					look = (o.position - c).normalized()
			draw_circle(c, CORE_RADIUS * 0.62, Color(0.1, 0.12, 0.18))
			draw_circle(c + look * CORE_RADIUS * 0.3, CORE_RADIUS * 0.3, Color(0.55, 0.85, 1.0))
			draw_circle(c + look * CORE_RADIUS * 0.36, CORE_RADIUS * 0.12, Color(0.02, 0.02, 0.05))
		"sun":
			for i in 10:
				var a := now * 0.6 + i * TAU / 10.0
				var d := Vector2.from_angle(a)
				draw_colored_polygon(PackedVector2Array([
					c + d * (CORE_RADIUS + 14.0),
					c + d.rotated(0.18) * (CORE_RADIUS - 1.0),
					c + d.rotated(-0.18) * (CORE_RADIUS - 1.0),
				]), Color(1.0, 0.85, 0.35, 0.85))
			draw_circle(c, CORE_RADIUS * 0.7, Color(1.0, 0.9, 0.5).lerp(col, 0.4))
		"crown":
			# 왕관 (보스 사냥꾼): 위로 솟은 다섯 뾰족
			var w := CORE_RADIUS * 0.8
			var pts := PackedVector2Array([c + Vector2(-w, w * 0.45), c + Vector2(w, w * 0.45)])
			for i in 5:
				var x := w - i * w * 0.5
				pts.append(c + Vector2(x, -w * (0.75 if i % 2 == 0 else 0.25)))
				if i < 4:
					pts.append(c + Vector2(x - w * 0.25, w * 0.05))
			draw_colored_polygon(pts, Color(1.0, 0.82, 0.3).lerp(col, 0.25))
			for i in 3:
				draw_circle(c + Vector2(-w + i * w, -w * 0.75), 2.5, Color(1, 0.4, 0.45))
		"galaxy":
			# 은하 (신화 업적 '빈두'): 도는 나선 팔 두 개
			draw_circle(c, CORE_RADIUS * 0.35, Color(1, 0.95, 0.85))
			for arm in 2:
				for i in 14:
					var t := i / 14.0
					var a := now * 0.8 + arm * PI + t * 3.2
					var d := CORE_RADIUS * (0.3 + 0.75 * t)
					draw_circle(c + Vector2.from_angle(a) * d, 2.6 * (1.0 - t * 0.6), Color.from_hsv(fmod(0.6 + t * 0.4 + now * 0.05, 1.0), 0.55, 1.0, 0.9 - t * 0.5))

## 일식 발동 때 화면 전체 연출(어둡게·큰 고리)을 이 오브젝트가 맡을지. 2.5초에 한 번만 맡기고 나머지는 오브젝트 둘레만 작게.
## 연출만 고르고 피해·발동 시각은 바꾸지 않는다
func eclipse_screen() -> bool:
	if eclipse_cd > 0.0:
		return false
	eclipse_flash = 0.6
	eclipse_cd = 2.5
	return true


## 효과 줄이기(설정): 장판은 절반 진하기, 25개를 넘게 겹치면 그만큼 더 옅게 (최소 20%). 터지는 효과는 절반.
func _soften_fx() -> void:
	fx_k = 0.5 if Meta.fx_low else 1.0
	var soft := zones.get_children().filter(func(z): return z.kind in Zone.SOFT)
	var a := 1.0
	if Meta.fx_low:
		a = maxf(0.2, 0.5 * minf(1.0, 25.0 / maxf(soft.size(), 1.0)))
	# 피해 몫이 작은 오브젝트의 탄·장판은 옅게 (가장 센 오브젝트 대비 비율만큼, 아래 버튼 줄에서 세기 조절).
	# 웨이브 첫머리(피해가 아직 적을 때)는 지난 값을 유지하고, 바뀔 때는 천천히 따라간다
	var str_k: float = FX_DPS[Meta.fx_dps]
	var top := 0.0
	for t in towers.get_children():
		top = maxf(top, t.dealt)
	for t in towers.get_children():
		var want := 1.0
		if str_k > 0.0 and towers.get_child_count() > 1:
			if top < 30.0:
				want = t.fx_a
			else:
				want = maxf(0.15, 1.0 - str_k * (1.0 - t.dealt / top))
		t.fx_a = lerpf(t.fx_a, want, 0.1)
	for z in zones.get_children():
		var za: float = a if z.kind in Zone.SOFT else 1.0
		if is_instance_valid(z.owner_tower):
			za *= z.owner_tower.fx_a
		if not is_equal_approx(z.modulate.a, za):
			z.modulate.a = za
	for p in projectiles.get_children():
		var pa: float = p.owner_tower.fx_a if is_instance_valid(p.owner_tower) else 1.0
		if absf(p.modulate.a - pa) > 0.02:
			p.modulate.a = pa


## 전장 밖(폰의 양옆·태블릿의 위아래)은 어둡게 덮고 경계선을 긋는다. 그쪽 구체는 아직 맞지 않고 오브젝트도 놓을 수 없다.
func _draw_margins(vw: Rect2) -> void:
	var ar := arena()
	if vw.size.x <= ar.size.x + 1.0 and vw.size.y <= ar.size.y + 1.0:
		return
	var col := Color(0, 0, 0, 0.45)
	if vw.position.x < ar.position.x:
		fx_layer.draw_rect(Rect2(vw.position.x, vw.position.y, ar.position.x - vw.position.x, vw.size.y), col)
		fx_layer.draw_rect(Rect2(ar.end.x, vw.position.y, vw.end.x - ar.end.x, vw.size.y), col)
	if vw.position.y < ar.position.y:
		fx_layer.draw_rect(Rect2(ar.position.x, vw.position.y, ar.size.x, ar.position.y - vw.position.y), col)
		fx_layer.draw_rect(Rect2(ar.position.x, ar.end.y, ar.size.x, vw.end.y - ar.end.y), col)
	fx_layer.draw_rect(ar, Color(1, 1, 1, 0.08), false, 1.0)


func _draw_fx() -> void:
	var vw := view_rect()
	var o := vw.position
	var vs := vw.size
	_draw_margins(vw)
	_draw_place_note(fx_layer)
	_draw_skill_fx()
	for i in 6:
		var w := 14.0 * (6 - i)
		var col := Color(0, 0, 0, 0.05)
		fx_layer.draw_rect(Rect2(o.x, o.y, vs.x, w), col)
		fx_layer.draw_rect(Rect2(o.x, o.y + vs.y - w, vs.x, w), col)
		fx_layer.draw_rect(Rect2(o.x, o.y, w, vs.y), col)
		fx_layer.draw_rect(Rect2(o.x + vs.x - w, o.y, w, vs.y), col)
	if phase == Phase.GAMEOVER or title_label.visible:
		fx_layer.draw_rect(vw, Color(0, 0, 0, 0.6))
	if eclipse_flash > 0.0:
		# 단번에 어두워지지 않게 0.1초 동안 천천히 어두워졌다가 풀린다
		var ef := eclipse_flash / 0.6
		var env := minf((1.0 - ef) / 0.15, 1.0) * ef
		fx_layer.draw_rect(vw, Color(0.1, 0.0, 0.15, 0.22 * env))
	# 중앙 위험: 화면 테두리가 붉게 맥박친다 (25% 이하는 더 진하고 빠르게). 배속과 상관없이 계속 보인다
	if danger_lv > 0 and phase != Phase.GAMEOVER and not title_label.visible:
		var t := Time.get_ticks_msec() / 1000.0
		var beat := 0.5 + 0.5 * sin(t * (3.0 if danger_lv == 1 else 7.0))
		var a := (0.05 + 0.05 * beat) if danger_lv == 1 else (0.09 + 0.09 * beat)
		var dc := Color(1, 0.6, 0.25) if danger_lv == 1 else Color(1, 0.15, 0.2)
		for i in 6:
			var w := 10.0 * (6 - i)
			var col := Color(dc, a)
			fx_layer.draw_rect(Rect2(o.x, o.y, vs.x, w), col)
			fx_layer.draw_rect(Rect2(o.x, o.y + vs.y - w, vs.x, w), col)
			fx_layer.draw_rect(Rect2(o.x, o.y, w, vs.y), col)
			fx_layer.draw_rect(Rect2(o.x + vs.x - w, o.y, w, vs.y), col)
	for a in arcs:
		fx_layer.draw_line(a[0], a[1], Color(Elem.COLORS[Elem.ELECTRIC], fx_k), 2.0)
	var sc: Color = Elem.COLORS[Elem.SOUND]
	for q in pulses:
		var k: float = 1.0 - q[2] / 0.3
		fx_layer.draw_arc(q[0], q[1] * (0.4 + 0.6 * k), 0, TAU, 32, Color(sc, (1.0 - k) * fx_k), 3.0)
		fx_layer.draw_arc(q[0], q[1] * (0.2 + 0.5 * k), 0, TAU, 24, Color(sc, 0.6 * (1.0 - k) * fx_k), 2.0)
	for q in beams:
		var bk: float = q[3] / 0.2 * fx_k
		fx_layer.draw_line(q[0], q[1], Color(q[2], 0.35 * bk), 9.0)
		fx_layer.draw_line(q[0], q[1], Color(q[2], 0.9 * bk), 3.0)
	var ec: Color = Elem.COLORS[Elem.ELECTRIC]
	for b in bolts:
		var src: PackedVector2Array = b[0]
		var pts := PackedVector2Array()
		for i in src.size() - 1:
			var a := src[i]
			var e := src[i + 1]
			for s in 6:
				var p := a.lerp(e, s / 6.0)
				if s > 0:
					p += (e - a).orthogonal().normalized() * randf_range(-7, 7)
				pts.append(p)
		pts.append(src[-1])
		var al := clampf(b[1] / 0.22, 0.0, 1.0) * fx_k
		fx_layer.draw_polyline(pts, Color(ec, 0.35 * al), 9.0)
		fx_layer.draw_polyline(pts, Color(ec, al), 3.5)
		fx_layer.draw_polyline(pts, Color(1, 1, 1, al), 1.2)
		for q in src.slice(1):
			fx_layer.draw_circle(q, 6.0, Color(ec, 0.5 * al))
	for p in particles:
		fx_layer.draw_circle(p[0], p[4] * clampf(p[2] / 0.4, 0.2, 1.0), Color(p[3], p[3].a * fx_k))
	for p in popups:
		var size := 22 if p[4] else 14
		var a := clampf(p[2] / 0.3, 0.0, 1.0)
		# 숫자는 기본 글꼴, 한글이 든 글자(콤보·최다 피해)는 한글 글꼴
		var f: Font = ThemeDB.fallback_font if p[1].is_valid_int() else ui_font
		fx_layer.draw_string(f, p[0] + Vector2(1, 1), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * a))
		fx_layer.draw_string(f, p[0], p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(p[3], a))
	# 보스 체력 줄·콤보 상자는 화면에 붙은 글이라 화면 좌표로 그린다 (확대해도 크기·자리 그대로)
	fx_layer.draw_set_transform_matrix(get_canvas_transform().affine_inverse())
	_draw_boss_bar()
	_draw_combo()
	fx_layer.draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_tooltip()


## 보스가 있으면 화면 위 가운데에 체력 막대 (여럿이면 합계). 화면 흔들림을 따라가지 않게 카메라 흔들림만큼 되돌린다.
func _draw_boss_bar() -> void:
	if phase != Phase.WAVE:
		return
	var hp := 0.0
	var mx := 0.0
	var n := 0
	for o in orbs.get_children():
		if o.kind == Orb.Kind.BOSS and o.hp > 0.0:
			hp += o.hp
			mx += o.max_hp
			n += 1
	if n == 0:
		return
	var w := 300.0
	# 위쪽 점수 줄(바탕 상자) 바로 아래. 특성 줄이 늘면 같이 내려간다
	var p := Vector2(get_viewport_rect().size.x / 2.0 - w / 2.0, ui_root.position.y + (hud.position.y + hud.size.y) * ui_root.scale.y + 20.0)
	fx_layer.draw_rect(Rect2(p, Vector2(w, 10)), Color(0, 0, 0, 0.6))
	fx_layer.draw_rect(Rect2(p, Vector2(w * clampf(hp / mx, 0.0, 1.0), 10)), Color(1, 0.3, 0.4))
	fx_layer.draw_rect(Rect2(p, Vector2(w, 10)), Color(1, 1, 1, 0.3), false, 1.0)
	var txt := "보스%s  %d / %d" % [" x%d" % n if n > 1 else "", ceili(hp), ceili(mx)]
	fx_layer.draw_string(ui_font, p + Vector2(1, -3), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0, 0, 0, 0.8))
	fx_layer.draw_string(ui_font, p + Vector2(0, -4), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(1, 0.85, 0.88))


## 콤보 점수 배율: 콤보마다 +10%, 콤보 20부터 x3.
func combo_mul() -> float:
	return 1.0 + 0.1 * mini(combo, 20)


## 콤보 상자 자리 (화면 좌표, 높이는 끊김·진행 중 큰 쪽). DPS 표를 옮겨 둘 때도 이 자리를 피한다.
func _combo_rect() -> Rect2:
	var w := 180.0
	var p := Vector2(ui_root.position.x + ui_root.size.x * ui_root.scale.x - 10.0 - w, ui_root.position.y + 40.0 * ui_root.scale.y + 8.0)
	if legend.visible:
		p.y = legend.get_global_rect().end.y + 8.0
	return Rect2(p, Vector2(w, 64))


## 오른쪽 위(설명 버튼 아래) 콤보 상자: 콤보·점수 배율·남은 유지 시간·더 얻은 점수.
## 콤보는 웨이브 중에만 쌓이고(쉬는 시간엔 멈춰 다음 웨이브로 이어짐), 웨이브 중엔 설명 글이 꺼져 있어 이 자리가 빈다.
func _draw_combo() -> void:
	if title_label.visible or phase == Phase.GAMEOVER:
		return
	var live := combo_t > 0.0 and combo >= 2 and phase == Phase.WAVE  # 쉬는 시간엔 그 자리에 설명 글이 뜬다
	if not live and combo_end[2] <= 0.0:
		return
	var w := 180.0
	var p := _combo_rect().position
	if not live:
		var a: float = clampf(combo_end[2] / 0.5, 0.0, 1.0)
		# 끊김: 콤보 그림 + 숫자(빨강, 줄 그음) + 얻은 점수
		fx_layer.draw_rect(Rect2(p, Vector2(w, 40)), Color(0, 0, 0, 0.55 * a))
		var rc := Color(1, 0.6, 0.5, a)
		Glyph.ui(fx_layer, "combo", p + Vector2(20, 20), 10.0, rc)
		var ns := str(combo_end[0])
		var nw := ui_font.get_string_size(ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		fx_layer.draw_string(ui_font, p + Vector2(36, 28), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, rc)
		fx_layer.draw_line(p + Vector2(34, 21), p + Vector2(38 + nw, 21), rc, 2.0)
		Icons.draw(fx_layer, "score", p + Vector2(w - 78, 20), 7.0, Color(1, 0.9, 0.6, a))
		fx_layer.draw_string(ui_font, p + Vector2(w - 68, 25), "+" + num(combo_end[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.6, a))
		return
	var maxed := combo >= 20
	var now := Time.get_ticks_msec() / 1000.0
	var col := Color(1, 0.85, 0.2) if maxed else Color(1, 1, 1).lerp(Color(1, 0.6, 0.25), combo / 20.0)
	# 글 대신: [콤보 그림] 숫자 · 배율, 줄어드는 유지 막대, [별] 콤보로 얻은 점수
	fx_layer.draw_rect(Rect2(p, Vector2(w, 62)), Color(0, 0, 0, 0.6))
	if maxed:
		# x3: 금색 테두리가 맥박치고, 닿은 순간엔 크게 반짝인다
		var glow := 0.45 + 0.25 * sin(now * 6.0) + combo_max_flash
		fx_layer.draw_rect(Rect2(p, Vector2(w, 62)), Color(1, 0.85, 0.2, clampf(glow, 0.0, 1.0)), false, 2.0 + 3.0 * combo_max_flash)
	Glyph.ui(fx_layer, "combo", p + Vector2(20, 20), 11.0, col)
	fx_layer.draw_string(ui_font, p + Vector2(38, 30), str(combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
	var mt := "×3 최대" if maxed else "×%.1f" % combo_mul()
	fx_layer.draw_string(ui_font, p + Vector2(0, 27), mt, HORIZONTAL_ALIGNMENT_RIGHT, w - 10.0, 16, col)
	# 남은 유지 시간: 다 줄어들기 전에 다음 구체를 잡아야 이어진다
	var k := combo_t / COMBO_KEEP
	fx_layer.draw_rect(Rect2(p + Vector2(10, 38), Vector2(w - 20, 5)), Color(1, 1, 1, 0.15))
	fx_layer.draw_rect(Rect2(p + Vector2(10, 38), Vector2((w - 20) * k, 5)), Color(1, 0.35, 0.3) if k < 0.35 else col)
	Icons.draw(fx_layer, "score", p + Vector2(17, 52), 6.0, Color(1, 0.9, 0.6))
	fx_layer.draw_string(ui_font, p + Vector2(28, 57), "+" + num(combo_bonus), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.6))


## 얼음 탄이 깨지며 파편 3개.
func _shatter(p: Projectile) -> void:
	if not is_instance_valid(p.owner_tower):
		return
	for a in [-0.6, 0.0, 0.6]:
		var f := spawn_proj(p.owner_tower, "frag", p.level, p.vel.normalized().rotated(a))
		f.position = p.position + p.vel.normalized() * 14.0
		f.hit = p.hit.duplicate()
		f.src = p.src


# ---------- 그리기 ----------

func _draw() -> void:
	place_label_rect = Rect2()
	var size := Meta.FIELD
	var vw := view_rect()
	var mp: Dictionary = Meta.MAPS[Meta.map_id]
	draw_rect(vw, mp["bg"])
	var c := core()
	var now := Time.get_ticks_msec() / 1000.0
	# 전장 바깥(폰의 양옆·태블릿의 위아래)은 같은 별을 이어 붙여 채운다
	var tiles: Array[Vector2] = [Vector2.ZERO]
	if vw.position.x < 0.0:
		tiles.append_array([Vector2(-size.x, 0), Vector2(size.x, 0)])
	if vw.position.y < 0.0:
		tiles.append_array([Vector2(0, -size.y), Vector2(0, size.y)])
	for st in stars:
		var col := Color(1, 1, 1, st.z * (0.7 + 0.3 * sin(now * 1.3 + st.x)))
		for tl in tiles:
			var sp := Vector2(st.x, st.y) + tl
			if tl == Vector2.ZERO or vw.has_point(sp):
				draw_circle(sp, 1.2, col)
	if Meta.map_id == "line":
		_draw_line_map(size, mp, now)
	else:
		var rc: Color = mp["ring"]
		for i in range(1, 5):
			draw_arc(c, i * 110.0, 0, TAU, 64, Color(rc, rc.a * 0.5), 1.0)  # 오브젝트·효과가 많아지면 거슬려 옅게
	# 중앙 점: 체력이 줄수록 붉어지고, 맞으면 번쩍인다
	core_disp = lerpf(core_disp, float(maxi(core_hp, 0)), 0.1)
	var frac := core_disp / core_max
	var core_col := Color(1, 1, 1).lerp(Color(1, 0.25, 0.3), 1.0 - frac)
	var beat := 0.5 + 0.5 * sin(now * (2.0 + 4.0 * (1.0 - frac)))
	for i in 4:
		draw_circle(c, CORE_RADIUS + 6.0 + i * 7.0 + beat * 4.0, Color(core_col, 0.05 + 0.25 * core_flash))
	draw_circle(c, CORE_RADIUS, core_col.lerp(Color.WHITE, core_flash * 2.0))
	_draw_core_skin(c, core_col, now)
	_draw_core_guard(c, now)
	# 체력이 줄면 금이 간다
	var cracks := core_max - maxi(core_hp, 0)
	for i in mini(cracks, 8):
		var a := i * 2.39
		var p1 := c + Vector2(cos(a), sin(a)) * CORE_RADIUS * 0.2
		var p2 := c + Vector2(cos(a + 0.3), sin(a + 0.3)) * CORE_RADIUS * 0.95
		draw_line(p1, p2, Color(0.3, 0.05, 0.08, 0.8), 1.5)
	draw_arc(c, CORE_RADIUS + 5.0, -PI / 2, -PI / 2 + TAU * frac, 32, Color(1, 1, 1, 0.6), 2.0)
	if title_label.visible:
		# 시작 화면: 중앙 점(체력 고리 포함)이 메뉴 글자 뒤로 비치지 않게 배경을 어둡게
		draw_rect(vw, Color(0, 0, 0, 0.6))

	# 구체 진입 방향 표시
	var vr := arena()
	for a in ([] if Meta.map_id == "line" else lanes):
		var d := Vector2(cos(a), sin(a))
		var edge := _edge_point(c, d)
		var path := PackedVector2Array()
		if Meta.map_id == "spiral":
			# 나선: 화면 밖에서 돌며 들어오므로, 실제로 화면에 들어오는 자리에 화살표를 둔다
			for q in _orb_path(a):
				if not path.is_empty() or vr.has_point(q):
					path.append(q)
			if path.size() >= 2:
				edge = path[0]
				d = (path[0] - path[1]).normalized()
		var tip := edge - d * 18.0 - d * 6.0 * sin(now * 4.0)
		var col := Color(1, 0.3, 0.35, 0.9 if phase != Phase.WAVE else 0.35)
		_draw_lane_fan(a, lane_spread(wave if phase == Phase.WAVE else wave + 1), now)
		draw_colored_polygon(PackedVector2Array([
			tip - d * 22.0,
			tip + d.orthogonal() * 12.0,
			tip - d.orthogonal() * 12.0,
		]), col)
		# 길 한 줄(나선 미리보기·흐르는 점)은 부채꼴(_draw_lane_fan)이 대신한다: 한 줄로 그리면 초보가 그 선만 막았다

	_draw_map_rule(c, now)
	_draw_boss_path(now)
	_draw_wind_rings()
	_draw_star_rings()
	# 누수: 구체가 들어온 화면 가장자리가 붉게 번진다 (어느 길목이 뚫렸는지)
	for lf in leak_flash:
		var f: float = lf[1] / 1.2
		for k in 4:
			draw_circle(lf[0], 40.0 + k * 34.0, Color(1, 0.15, 0.2, 0.16 * f * (1.0 - k * 0.22)))

	var mpos := _pointer_world()
	if card_dock.active():
		var preview := card_dock.preview_card()
		if not preview.is_empty():
			for t: Tower in towers.get_children():
				if not card_dock.target_ok(t, preview):
					continue
				var fresh: Array = Elem.new_reactions(t.eff_now(), preview["e"]) if preview["type"] == "elem" else []
				var col: Color = fresh[0]["color"] if not fresh.is_empty() else Color(0.65, 0.85, 1.0, 0.7)
				var radius := Tower.RADIUS + (15.0 + 3.0 * sin(now * 6.7) if not fresh.is_empty() else 7.0)
				draw_arc(t.position, radius, 0, TAU, 40, col, 3.0 if not fresh.is_empty() else 1.5)
	elif phase == Phase.CHOOSE and hover_elem >= 0:
		var pulse2 := 0.5 + 0.5 * sin(now * 6.7)
		var hcard := {"type": "elem", "e": hover_elem}
		for t in towers.get_children():
			if not t.can_take(hcard):  # 속성 종류 상한에 걸려 못 넣는 오브젝트는 강조하지 않음
				continue
			var fresh := Elem.new_reactions(t.eff_now(), hover_elem)
			if not fresh.is_empty():
				draw_arc(t.position, Tower.RADIUS + 10.0 + pulse2 * 4.0, 0, TAU, 32, Color(fresh[0]["color"], 0.9), 3.0)
	if phase == Phase.PLACE and not picked.is_empty():
		var col := _card_color(picked)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		var is_elem: bool = picked["type"] == "elem"
		# 넣을 수 있는 오브젝트: 숨 쉬는 빛 + 고리 + 도는 점선 고리 (속성 카드는 새 반응이 생기면 그 반응 색).
		# 넣을 수 없는 오브젝트는 _update_place_dim이 흐리게 하고 누를 수 없다 (작은 ✕)
		var spin := Time.get_ticks_msec() / 1000.0 * 1.6
		var target := _tower_at(mpos)
		place_note = {}
		var pv: Array = target.preview(picked) if target and _place_ok(target) else []
		var refuse: bool = target != null and (pv.is_empty() or (pv[0] as PackedStringArray)[0] == "넣을 수 없음")
		for t in towers.get_children():
			if not _place_ok(t):
				if t != target:
					draw_line(t.position + Vector2(-7, -7), t.position + Vector2(7, 7), Color(1, 0.35, 0.35, 0.55), 2.5)
					draw_line(t.position + Vector2(7, -7), t.position + Vector2(-7, 7), Color(1, 0.35, 0.35, 0.55), 2.5)
				continue
			if t == target:
				continue  # 올린 오브젝트는 아래에서 따로 (흰 고리 또는 넣을 수 없음 표시)
			var hc := col
			var strong := not is_elem
			if is_elem:
				var fresh := Elem.new_reactions(t.eff_now(), picked["e"])
				if not fresh.is_empty():
					hc = fresh[0]["color"]
					strong = true
			if not strong or target != null:
				# 속성 카드는 빈 곳에 새로 놓을 수도 있어 겹치기만 옅게 표시.
				# 오브젝트 하나에 올려 둔 동안엔 나머지는 얇은 고리만 (빛·도는 고리가 겹쳐 올린 것이 묻히지 않게)
				draw_arc(t.position, Tower.RADIUS + 9.0, 0, TAU, 32, Color(hc, 0.55 if strong else 0.35), 1.5)
				continue
			draw_circle(t.position, Tower.RADIUS + 14.0 + pulse * 4.0, Color(hc, 0.07 + 0.07 * pulse))
			draw_arc(t.position, Tower.RADIUS + 10.0 + pulse * 4.0, 0, TAU, 32, Color(hc, 0.95), 3.0)
			for k in 4:
				var a0 := spin + k * TAU / 4.0
				draw_arc(t.position, Tower.RADIUS + 20.0, a0, a0 + 0.8, 8, Color(hc, 0.6), 2.0)
		if target and refuse:
			# 넣을 수 없는 오브젝트 위: 범위·설명 없이 빨간 고리 + 큰 ✕ + "넣을 수 없음" 하나만 (이유는 누르면 알림으로)
			place_note = {"t": target, "lines": PackedStringArray(["넣을 수 없음"]), "col": Color(1, 0.3, 0.32), "fs": 18, "refuse": true}
		elif target:
			var lines: PackedStringArray = pv[0]
			Tower.draw_range(self, target.position, target.dir, pv[1], picked["e"] if is_elem else -2)
			draw_arc(target.position, Tower.RADIUS + 8.0, 0, TAU, 32, Color.WHITE, 2.0)
			var tcol := col
			if is_elem:
				for r in Elem.new_reactions(target.eff_now(), picked["e"]):
					var rd: String = r["desc"]
					lines.append("조합: %s" % r["name"] + (" (%s)" % rd if rd.length() <= 26 else ""))
					tcol = r["color"]
					if r.get("aff", "") != "":
						lines.append(Elem.aff_label(r["a"], r["b"]).replace("(강)", " ▲강").replace("(약)", " ∿약"))
						tcol = AFF_COL[r["aff"]]
				var ns := Share.new_sites(target.eff_now(), picked["e"])
				if not ns.is_empty():
					lines.append("새 자리: " + " · ".join(ns))
			place_note = {"t": target, "lines": lines, "col": tcol, "fs": 16, "refuse": false}
		elif is_elem:
			var at := mpos.clamp(field_rect().position, field_rect().end)  # 실제로 놓일 자리
			draw_circle(at, Tower.RADIUS, Color(col, 0.4))
			var near := at.distance_to(c) < 50.0
			var lbl := "중앙과 너무 가까움" if near else "새로 설치 (직선탄)"
			_draw_place_label(at + Vector2(-40, Tower.RADIUS + 20), lbl, Color(1, 0.5, 0.5) if near else Color(1, 1, 1, 0.7))
		else:
			draw_arc(mpos, 10.0, 0, TAU, 20, Color(col, 0.8), 2.0)
			_draw_place_label(mpos + Vector2(-50, 28), "오브젝트 위에 놓기", Color(1, 1, 1, 0.7))
	elif phase == Phase.AIM:
		var sp: Dictionary = moving.spec() if moving else {"els": {picked["e"]: picked["lv"]}, "pat": Pat.DEFAULT, "plv": 1, "mods": {}}
		var col: Color = Elem.COLORS[sp["els"].keys()[0]]
		if not moving:
			draw_circle(place_pos, Tower.RADIUS, Color(col, 0.6))
		var d := _aim_dir(place_pos)
		if d != Vector2.ZERO:
			Tower.draw_range(self, place_pos, d, sp)
			if moving and not get_tree().paused:
				moving.set_attack_direction(d)
			draw_line(place_pos, place_pos + d * (Tower.RADIUS + 14.0), Color.WHITE, 3.0)
	# 마우스를 올린 오브젝트의 공격 범위
	if phase == Phase.MOVE and moving:
		Tower.draw_range(self, mpos, moving.dir, moving.spec())
	# 연결선: 옮길 자리에서 이어지는지 미리 보여 준다
	var movers: Array = [moving] if phase == Phase.MOVE and moving else (drag_group if dragging else [])
	for mover in movers:
		if not is_instance_valid(mover):
			continue
		if _bad_spot(mover, movers) != "":
			# 여기 놓으면 되돌아간다는 표시 (중앙에 너무 가깝거나 다른 오브젝트와 겹침)
			draw_arc(mover.position, Tower.RADIUS + 10.0, 0, TAU, 32, Color(1, 0.25, 0.25, 0.75 + 0.25 * sin(Time.get_ticks_msec() / 90.0)), 4.0)
	if (Input.is_key_pressed(KEY_ALT) or range_all) and not title_label.visible:
		# Alt를 누르고 있는 동안: 모든 오브젝트의 공격 범위와 이번(지난) 웨이브 피해 몫 (약한 오브젝트 찾기)
		var total := 0.0
		for t in towers.get_children():
			Tower.draw_range(self, t.position, t.dir, t.spec())
			if t.reso > 0:
				draw_arc(t.position, Rules.t("reso_r") * MapRule.reso_k(), 0, TAU, 48, Color(1.0, 0.78, 0.3, 0.8), 2.0)
			total += t.dealt
		if total > 0.0:
			for t in towers.get_children():
				var txt := "%d%%" % roundi(t.dealt / total * 100.0)
				var tp: Vector2 = t.position + Vector2(-40, Tower.RADIUS + 20)
				draw_string(ui_font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(0, 0, 0, 0.8))
				draw_string(ui_font, tp, txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(1, 0.9, 0.5))
	elif dragging:
		# 끄는 동안: 옮기는 오브젝트들의 범위 (방향은 그대로)
		for t in drag_group:
			if is_instance_valid(t):
				Tower.draw_range(self, t.position, t.dir, t.spec())
	elif phase in [Phase.CHOOSE, Phase.WAVE, Phase.READY]:
		var hov := _tower_at(mpos) if not card_dock.over_ui(_pointer_screen()) else null
		if hov == null:
			hov = _ring_target()
		if hov:
			Tower.draw_range(self, hov.position, hov.dir, hov.spec(), -1, _tip_detail_on())
	if dps_panel.visible and is_instance_valid(dps_focus):
		# DPS 표에서 고른 오브젝트: 범위와 깜빡이는 고리, 위에서 가리키는 화살표
		var fp := dps_focus.position
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		Tower.draw_range(self, fp, dps_focus.dir, dps_focus.spec())
		draw_arc(fp, Tower.RADIUS + 8.0 + pulse * 6.0, 0, TAU, 40, Color(1, 0.9, 0.5, 0.95), 3.0)
		var ay := fp.y - Tower.RADIUS - 22.0 - pulse * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(fp.x, ay + 12), Vector2(fp.x - 9, ay), Vector2(fp.x + 9, ay)]), Color(1, 0.9, 0.5))
	# 여러 개 선택: 하늘색 점선 고리, 선택 상자
	for t in selected:
		if is_instance_valid(t):
			for i in 8:
				var a0 := TAU * i / 8 + Time.get_ticks_msec() / 800.0
				draw_arc(t.position, Tower.RADIUS + 12.0, a0, a0 + 0.45, 6, Color(0.5, 0.9, 1.0, 0.95), 2.5)
	if boxing:
		var r := Rect2(box_start, mpos - box_start).abs()
		draw_rect(r, Color(0.5, 0.9, 1.0, 0.08))
		draw_rect(r, Color(0.5, 0.9, 1.0, 0.8), false, 1.5)


func _draw_place_label(at: Vector2, text: String, color: Color) -> void:
	var visible := view_rect().grow(-8)
	var width := ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	at.x = clampf(at.x, visible.position.x, maxf(visible.position.x, visible.end.x - width))
	at.y = clampf(at.y, visible.position.y + 14, visible.end.y)
	var avoid: Array[Rect2] = []
	var to_world := get_canvas_transform().affine_inverse() * ui_root.get_global_transform()
	for rect in _info_blockers():
		avoid.append(to_world * rect)
	avoid.append(Rect2(_pointer_world() - Vector2(24, 24), Vector2(48, 48)))
	place_label_rect = _free_badge(Rect2(at - Vector2(0, 14), Vector2(width, 18)), Vector2.UP, avoid, visible)
	draw_string(ui_font, place_label_rect.position + Vector2(0, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


## 카드를 넣을 오브젝트에 올렸을 때의 설명 글 (main._draw가 place_note에 담고, 오브젝트 위에 보이게 fx_layer가 그린다).
## 어두운 상자에 담아 다른 오브젝트·중앙을 가장 덜 가리는 자리(위·아래·옆, 조금씩 떨어진 곳까지)에 띄운다.
## 넣을 수 없으면 빨간 고리 + 큰 ✕ + "넣을 수 없음" 한 줄만.
func _draw_place_note(ci: CanvasItem) -> void:
	place_note_rect = Rect2()
	if place_note.is_empty() or phase != Phase.PLACE or not is_instance_valid(place_note["t"]):
		return
	var target: Tower = place_note["t"]
	var lines: PackedStringArray = place_note["lines"]
	var col: Color = place_note["col"]
	var fs: int = place_note["fs"]
	var o := target.position
	if place_note["refuse"]:
		ci.draw_arc(o, Tower.RADIUS + 8.0, 0, TAU, 32, col, 3.0)
		var xr := Tower.RADIUS * 0.8
		ci.draw_line(o + Vector2(-xr, -xr), o + Vector2(xr, xr), Color(0, 0, 0, 0.6), 7.0)
		ci.draw_line(o + Vector2(xr, -xr), o + Vector2(-xr, xr), Color(0, 0, 0, 0.6), 7.0)
		ci.draw_line(o + Vector2(-xr, -xr), o + Vector2(xr, xr), col, 4.0)
		ci.draw_line(o + Vector2(xr, -xr), o + Vector2(-xr, xr), col, 4.0)
	var lh := fs + 5.0
	var w := 0.0
	for txt in lines:
		w = maxf(w, ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var sz := Vector2(w + 16.0, lh * lines.size() + 8.0)
	var vr := view_rect()
	var lo := vr.position + Vector2(8.0, 44.0)
	var hi := Vector2(_right_limit() - sz.x, vr.end.y - 76.0 - sz.y).max(lo)
	var gap := Tower.RADIUS + 12.0
	var cands: Array = []
	for k in 5:
		var dy := gap + k * 34.0
		for fx in [0.5, 0.15, 0.85]:
			cands.append(Vector2(o.x - sz.x * fx, o.y - dy - sz.y))  # 위
			cands.append(Vector2(o.x - sz.x * fx, o.y + dy))  # 아래
		var dx := gap + k * 40.0
		cands.append(Vector2(o.x + dx, o.y - sz.y / 2.0))  # 오른쪽
		cands.append(Vector2(o.x - dx - sz.x, o.y - sz.y / 2.0))  # 왼쪽
	var blocks: Array = [[center(), CORE_RADIUS + 16.0]]
	for t in towers.get_children():
		blocks.append([t.position, Tower.RADIUS + 4.0])
	var ui_blocks: Array[Rect2] = []
	var to_world := get_canvas_transform().affine_inverse() * ui_root.get_global_transform()
	for rect in _info_blockers():
		ui_blocks.append(to_world * rect)
	var best := Rect2()
	var best_s := INF
	for p: Vector2 in cands:
		var q := p.clamp(lo, hi)
		var r := Rect2(q, sz)
		var sc := q.distance_to(o) / 60.0 + q.distance_to(p) / 30.0
		for bl in blocks:
			var bp: Vector2 = bl[0]
			if bp.clamp(r.position, r.end).distance_to(bp) < bl[1]:
				sc += 10.0
		for rect in ui_blocks:
			if r.intersects(rect):
				sc += 1000.0 + r.intersection(rect).get_area()
		if sc < best_s:
			best_s = sc
			best = r
	place_note_rect = best
	var near := o.clamp(best.position, best.end)
	if near.distance_to(o) > gap + 20.0:
		# 떨어진 자리면 오브젝트까지 가는 가는 선
		ci.draw_line(o + (near - o).normalized() * (Tower.RADIUS + 9.0), near, Color(col, 0.5), 1.5)
	ci.draw_rect(best, Color(0.03, 0.03, 0.06, 0.85))
	ci.draw_rect(best, Color(col, 0.6), false, 1.5)
	for i in lines.size():
		var txt := lines[i]
		var c2: Color = col if i == 0 or txt.begins_with("조합") else Color(1, 1, 1, 0.9)
		ci.draw_string(ui_font, best.position + Vector2(8.0, 2.0 + fs + i * lh), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c2)


## 회랑 맵: 길(띠)·끝의 문·구체가 오는 쪽 화살표.
## 중앙 특성 표시: 실드(파란 고리, 칸마다 한 줄), 성벽(진입 방향마다 바위 벽, 남은 조각만큼 두껍게), 반격 파동.
func _draw_core_guard(c: Vector2, now: float) -> void:
	var sh := shield + shield_keep
	for i in sh:
		var col := Color(0.55, 0.85, 1.0, 0.75) if i < shield else Color(0.75, 0.95, 1.0, 0.75)
		draw_arc(c, CORE_RADIUS + 5.0 + i * 4.0, 0, TAU, 40, Color(col, col.a * (0.75 + 0.25 * sin(now * 3.0 + i))), 2.0)
	if rampart_left > 0 and phase == Phase.WAVE:
		var wcol := Color(0.75, 0.6, 0.45, 0.9)
		var half := 22.0
		if Meta.map_id == "line":
			var dx := -RAMPART_R if Meta.line_flip else RAMPART_R
			for k in rampart_left:
				var x := c.x + dx + signf(dx) * k * 5.0
				draw_line(Vector2(x, c.y - 260.0), Vector2(x, c.y + 260.0), wcol, 4.0)
		else:
			for a in lanes:
				var dir := Vector2.from_angle(a)
				var side := dir.orthogonal() * half
				for k in rampart_left:
					var m := c + dir * (RAMPART_R + k * 5.0)
					draw_line(m - side, m + side, wcol, 4.0)
	_draw_ley()
	for q in core_fx:
		var k: float = 1.0 - q[2] / FX_RIPOSTE
		draw_arc(q[0], q[1] * (0.3 + 0.7 * k), 0, TAU, 48, Color(1.0, 0.85, 0.5, 1.0 - k), 4.0)


func _draw_line_map(size: Vector2, mp: Dictionary, now: float) -> void:
	var cy := size.y / 2.0
	var gx := core().x
	var from_right := not Meta.line_flip
	var vw := view_rect()  # 길 바닥은 화면 끝까지 (전장 밖 양옆에서 끊기지 않게)
	draw_rect(Rect2(vw.position.x, cy - LINE_HALF, vw.size.x, LINE_HALF * 2.0), Color(1, 1, 1, 0.025))
	for e in [-1.0, 1.0]:
		draw_line(Vector2(vw.position.x, cy + e * LINE_HALF), Vector2(vw.end.x, cy + e * LINE_HALF), Color(mp["ring"], 0.25), 2.0)
	# 길 바닥의 흐르는 줄무늬 (구체가 가는 방향)
	var dirx := -1.0 if from_right else 1.0
	for k in 12:
		var x := fposmod(k * size.x / 12.0 + dirx * now * 30.0, size.x)
		draw_line(Vector2(x, cy - LINE_HALF + 6.0), Vector2(x, cy + LINE_HALF - 6.0), mp["ring"], 1.0)
	# 문: 닿으면 중앙 체력이 깎이는 세로선
	var gcol := Color(1, 0.4, 0.45, 0.5 + 0.2 * sin(now * 3.0) + 0.3 * core_flash)
	draw_line(Vector2(gx, cy - LINE_HALF), Vector2(gx, cy + LINE_HALF), gcol, 3.0)
	for e in [-1.0, 1.0]:
		draw_rect(Rect2(gx - 6.0, cy + e * LINE_HALF - 6.0, 12.0, 12.0), gcol)
	# 구체가 오는 쪽: 화면 끝의 화살표 3개
	var col := Color(1, 0.3, 0.35, 0.9 if phase != Phase.WAVE else 0.35)
	var ex := size.x - 18.0 if from_right else 18.0
	var d := Vector2(dirx, 0)
	for yy in [-LINE_HALF * 0.6, 0.0, LINE_HALF * 0.6]:
		var tip := Vector2(ex, cy + yy) + d * (6.0 * sin(now * 4.0))
		draw_colored_polygon(PackedVector2Array([tip + d * 22.0, tip + Vector2(0, 12), tip - Vector2(0, 12)]), col)


## 방향 고르기. Shift를 누르면 15도 단위로 맞춘다.
## 터치: 손가락을 오브젝트에서 조금 떼어 대고 있는 동안만 손가락 쪽, 아니면 붙잡아 둔 방향(aim_d).
func _aim_dir(from: Vector2) -> Vector2:
	var d := _pointer_world() - from
	if touch_ui and phase == Phase.AIM and (not aim_hold or d.length() < AIM_TOUCH_MIN):
		return aim_d
	if d.length() < 5.0:
		return Vector2.ZERO
	if Input.is_key_pressed(KEY_SHIFT):
		var step := PI / 12.0
		return Vector2.from_angle(roundf(d.angle() / step) * step)
	return d.normalized()


## 중앙에서 d 방향으로 뻗은 선이 화면 가장자리와 만나는 점.
func _edge_point(c: Vector2, d: Vector2) -> Vector2:
	var tx := INF if is_zero_approx(d.x) else absf(c.x / d.x)
	var ty := INF if is_zero_approx(d.y) else absf(c.y / d.y)
	return c + d * minf(tx, ty)


# ---------- 기록 ----------

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		Meta.load_into(cfg)
		# 예전 버전의 정원 기록([garden] 칸)은 읽지 않고, 다음 저장 때 빠진다
		if FileAccess.file_exists(OLD_GARDEN_RUN):
			DirAccess.remove_absolute(OLD_GARDEN_RUN)  # 정원 저장 판은 더 쓰지 않는다

		var b := Meta.best_of(Meta.run_key())
		best_wave = b[0]
		best_score = b[1]
		auto_start = Meta.val(cfg, "option", "auto_start", false)
		legend_hidden = Meta.val(cfg, "option", "legend_hidden", legend_hidden)
		bar_open = Meta.val(cfg, "option", "bar_open", false)
		sfx.set_muted(Meta.val(cfg, "option", "muted", false))
		fast_speed = Meta.val(cfg, "option", "fast_speed", 2.0)
		if not fast_speed in SPEEDS:
			fast_speed = 2.0


func _save_best() -> void:
	TutPlay.swap()  # 연습 판: 원래 맵·규칙·모드로 저장
	var cfg := ConfigFile.new()
	var b := Meta.best_of(Meta.run_key())
	if best_wave > b[0] or best_score > b[1]:
		Meta.map_best[Meta.run_key()] = [maxi(best_wave, b[0]), maxi(best_score, b[1])]
	Meta.save_into(cfg)
	cfg.set_value("option", "auto_start", auto_start)
	cfg.set_value("option", "legend_hidden", legend_hidden)
	cfg.set_value("option", "bar_open", bar_open)
	cfg.set_value("option", "muted", sfx.muted)
	cfg.set_value("option", "fast_speed", fast_speed)
	cfg.save(SAVE_PATH)
	TutPlay.swap()


# ---------- 멀티플레이 ----------
# 대결(vs): 모두 같은 씨앗으로 같은 웨이브를 받아 각자 판을 하고, 상태·보낸 구체·탈락만 주고받는다.
# 협동(coop): 호스트가 한 전장을 계산하고 참가자는 받은 구체를 그린다. 오브젝트는 놓은 사람이 바꾸고 서로 보낸다.

## 대결 씨앗이 있으면 모두 같은 난수, 없으면 전역 난수(혼자 하는 판·봇 측정과 같은 순서).
func wf() -> float:
	return wrng.randf() if mp_seed != 0 and not w_off else randf()


func wi() -> int:
	return wrng.randi() if mp_seed != 0 and not w_off else randi()


func wrange(a: float, b: float) -> float:
	return wrng.randf_range(a, b) if mp_seed != 0 and not w_off else randf_range(a, b)


func _wpick(arr: Array) -> Variant:
	return arr[wi() % arr.size()] if mp_seed != 0 and not w_off else arr.pick_random()


func _wshuffle(arr: Array) -> void:
	if mp_seed == 0:
		arr.shuffle()
		return
	for i in range(arr.size() - 1, 0, -1):
		var j := wi() % (i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## 이 기기 사람이 바꿀 수 있는 오브젝트인지 (협동에서 친구 것은 아님).
func _mine(t: Tower) -> bool:
	return t == null or mp_mode != "coop" or t.owner_id == mp.my_id


func _my_towers() -> Array:
	if mp_mode != "coop":
		return towers.get_children()
	return towers.get_children().filter(func(t): return t.owner_id == mp.my_id)


func _mp_name(id: int) -> String:
	if id == mp.my_id:
		return "나"
	if Meta.blocked.has(mp.pids.get(id, "")):
		return "차단한 플레이어"
	var n: String = mp_others.get(id, {}).get("name", "")
	if n == "":
		n = mp.peers.get(id, {}).get("name", "")
	return n if n != "" else "플레이어 %d" % id


## 멀티플레이에서 남에게 보이는 이름 = 설정의 닉네임 (비우면 상대 화면엔 "플레이어 N"). 플랫폼은 그림으로 따로.
static func _mp_my_name() -> String:
	return Meta.nickname.strip_edges().left(12)


func _build_mp_lobby(root: Control) -> void:
	mp_panel = PanelContainer.new()
	mp_panel.z_index = 22
	mp_panel.set_anchors_preset(Control.PRESET_CENTER)
	mp_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mp_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	mp_panel.offset_left = -330.0
	mp_panel.offset_right = 330.0
	mp_panel.offset_top = -160.0  # 내용만큼 위아래로 자란다
	mp_panel.offset_bottom = 160.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_content_margin_all(18)
	mp_panel.add_theme_stylebox_override("panel", sb)
	mp_panel.visible = false
	root.add_child(mp_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	mp_panel.add_child(box)
	var head := Label.new()
	head.text = "멀티플레이"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	var desc := Label.new()
	mp_desc = desc
	desc.text = "대결: 같은 웨이브를 각자 막고, 실수 없이 막으면 상대에게 구체를 보냄\n협동: 한 전장을 함께 막음 (호스트 기기가 계산, 인원만큼 구체가 많아짐)\n맵·규칙은 호스트가 시작 화면에서 고른 것으로, 모드는 끈 채로 합니다"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	box.add_child(desc)
	mp_host_box = HBoxContainer.new()
	mp_host_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mp_host_box.add_theme_constant_override("separation", 10)
	box.add_child(mp_host_box)
	for spec in [["대결 방 만들기", "vs"], ["협동 방 만들기", "coop"]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(250, 46)
		b.focus_mode = Control.FOCUS_NONE
		var m: String = spec[1]
		b.pressed.connect(func(): _mp_host(m))
		mp_host_box.add_child(b)
	mp_join_box = HBoxContainer.new()
	mp_join_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mp_join_box.add_theme_constant_override("separation", 10)
	box.add_child(mp_join_box)
	mp_code_edit = LineEdit.new()
	mp_code_edit.placeholder_text = "방 코드 6자리"
	mp_code_edit.custom_minimum_size = Vector2(220, 46)
	mp_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_code_edit.add_theme_font_size_override("font_size", 22)
	# 글자 수 제한(max_length) 대신 넣을 때마다 코드 글자만 남긴다: "방 코드 3EL3MP" 같은 글을 붙여 넣어도 코드만
	mp_code_edit.text_changed.connect(func(t):
		var c := Mp.clean_code(t)
		if c != t:
			mp_code_edit.text = c
			mp_code_edit.caret_column = c.length())
	mp_code_edit.text_submitted.connect(func(_t): _mp_join())
	mp_join_box.add_child(mp_code_edit)
	var pb := Button.new()
	pb.text = "붙여넣기"
	pb.custom_minimum_size = Vector2(130, 46)
	pb.focus_mode = Control.FOCUS_NONE
	pb.pressed.connect(func():
		mp_code_edit.text = Mp.clean_code(DisplayServer.clipboard_get())
		mp_code_edit.caret_column = mp_code_edit.text.length()
		if mp_code_edit.text.length() != 6:
			mp_status.text = "복사한 글에 방 코드 6자리가 없어요")
	mp_join_box.add_child(pb)
	var jb := Button.new()
	jb.text = "참가"
	jb.custom_minimum_size = Vector2(200, 46)
	jb.focus_mode = Control.FOCUS_NONE
	jb.pressed.connect(_mp_join)
	mp_join_box.add_child(jb)
	mp_room_box = VBoxContainer.new()
	mp_room_box.add_theme_constant_override("separation", 6)
	mp_room_box.visible = false
	box.add_child(mp_room_box)
	mp_load_view = Control.new()
	mp_load_view.custom_minimum_size = Vector2(560, 200)
	mp_load_view.visible = false
	mp_load_view.add_to_group("mp_spin")  # 매 프레임 다시 그림
	mp_load_view.draw.connect(_mp_draw_load)
	box.add_child(mp_load_view)
	mp_status = Label.new()
	mp_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mp_status.custom_minimum_size = Vector2(600, 30)
	mp_status.add_theme_font_size_override("font_size", 18)
	box.add_child(mp_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	mp_start_btn = Button.new()
	mp_start_btn.text = "시작"
	mp_start_btn.custom_minimum_size = Vector2(220, 46)
	mp_start_btn.focus_mode = Control.FOCUS_NONE
	mp_start_btn.pressed.connect(_mp_start)
	row.add_child(mp_start_btn)
	mp_close_btn = Button.new()
	mp_close_btn.text = "닫기"
	mp_close_btn.custom_minimum_size = Vector2(200, 46)
	mp_close_btn.focus_mode = Control.FOCUS_NONE
	mp_close_btn.pressed.connect(_toggle_mp_lobby)
	row.add_child(mp_close_btn)
	mp_bar = Label.new()  # 점수 줄 바로 아래 (_mp_tick이 자리를 맞춘다)
	mp_bar.add_theme_font_size_override("font_size", 15)
	mp_bar.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	mp_bar.add_theme_constant_override("outline_size", 4)
	mp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_bar.visible = false
	root.add_child(mp_bar)
	# 협동 버튼 줄 (상태 줄 아래): [속성 요청] 모두, [내보내기] 호스트만
	mp_act = HBoxContainer.new()
	mp_act.add_theme_constant_override("separation", 8)
	mp_act.visible = false
	root.add_child(mp_act)
	mp_view_btn = Button.new()
	mp_view_btn.text = "보기: 모두"
	mp_view_btn.tooltip_text = "누구 오브젝트인지 골라 보기: 모두 → 나 → 친구마다 (고른 사람 것만 진하게, 나머지는 흐리게)"
	mp_view_btn.focus_mode = Control.FOCUS_NONE
	mp_view_btn.add_theme_font_size_override("font_size", 14)
	mp_view_btn.pressed.connect(_mp_view_next)
	mp_act.add_child(mp_view_btn)
	mp_req_btn = Button.new()
	mp_req_btn.text = "속성 요청"
	mp_req_btn.tooltip_text = "내 오브젝트 하나에 원하는 속성을 요청해요. 친구가 그 속성 카드를 고르면 넣어 줄 수 있어요 (쉬는 시간마다 1장)"
	mp_req_btn.focus_mode = Control.FOCUS_NONE
	mp_req_btn.add_theme_font_size_override("font_size", 14)
	mp_req_btn.pressed.connect(_mp_req_toggle)
	mp_act.add_child(mp_req_btn)
	mp_kick_btn = Button.new()
	mp_kick_btn.text = "내보내기"
	mp_kick_btn.tooltip_text = "호스트: 판에서 사람을 내보내요 (그 사람 오브젝트는 남고, 다시 들어올 수 없어요)"
	mp_kick_btn.focus_mode = Control.FOCUS_NONE
	mp_kick_btn.add_theme_font_size_override("font_size", 14)
	mp_kick_btn.pressed.connect(_mp_kick_open)
	mp_act.add_child(mp_kick_btn)
	mp_pop = PanelContainer.new()
	mp_pop.z_index = 23
	mp_pop.set_anchors_preset(Control.PRESET_CENTER)
	mp_pop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mp_pop.grow_vertical = Control.GROW_DIRECTION_BOTH
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	psb.set_border_width_all(1)
	psb.border_color = Color(1, 1, 1, 0.25)
	psb.set_content_margin_all(16)
	mp_pop.add_theme_stylebox_override("panel", psb)
	mp_pop.visible = false
	root.add_child(mp_pop)
	_mp_refresh_lobby()


## 협동 작은 창: 제목 + 버튼들 ([글, 색, 누르면 할 일]) + [닫기].
func _mp_pop_show(title: String, items: Array) -> void:
	for ch in mp_pop.get_children():
		mp_pop.remove_child(ch)
		ch.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	mp_pop.add_child(box)
	var head := Label.new()
	head.text = title
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(420, 0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 17)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 4 if items.size() > 4 else maxi(1, items.size())
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.custom_minimum_size = Vector2(100, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", it[1])
		var f: Callable = it[2]
		b.pressed.connect(func():
			mp_pop.visible = false
			f.call())
		grid.add_child(b)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(120, 38)
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): mp_pop.visible = false)
	box.add_child(close)
	mp_pop.visible = true
	_mp_pop_center.call_deferred()


func _mp_pop_center() -> void:
	var sz := mp_pop.get_combined_minimum_size()
	mp_pop.offset_left = -floorf(sz.x / 2.0)
	mp_pop.offset_right = ceilf(sz.x / 2.0)
	mp_pop.offset_top = -floorf(sz.y / 2.0)
	mp_pop.offset_bottom = ceilf(sz.y / 2.0)


## [속성 요청]: 다음에 누른 내 오브젝트에 요청할 속성을 고른다.
func _mp_req_toggle() -> void:
	if mp_mode != "coop":
		return
	if mp_req_got_w == wave:
		_show_toast("이번 쉬는 시간에는 이미 요청한 속성을 받았어요")
		return
	mp_req_mode = not mp_req_mode
	mp_req_btn.text = "요청 취소" if mp_req_mode else "속성 요청"
	hint.text = "속성을 요청할 내 오브젝트를 누르세요" if mp_req_mode else _th(_choose_hint() if phase == Phase.CHOOSE else "")


func _mp_req_open(t: Tower) -> void:
	mp_req_mode = false
	mp_req_btn.text = "속성 요청"
	_restore_hint()
	var items: Array = []
	for e in Elem.ALL:
		if t.can_take({"type": "elem", "e": e, "lv": 1}):
			var ee: int = e
			items.append([Elem.NAMES[e], Elem.COLORS[e], func(): _mp_req_set(t, ee)])
	if t.req_e >= 0:
		items.append(["요청 지우기", Color(0.75, 0.75, 0.75), func(): _mp_req_set(t, -1)])
	if items.is_empty():
		_show_toast("이 오브젝트에는 더 넣을 수 있는 속성이 없어요")
		return
	_mp_pop_show("%s에 받고 싶은 속성 (친구가 그 속성 카드를 고르면 넣어 줄 수 있어요. 한 번에 하나)" % t.title(), items)


## 요청은 사람마다 하나: 다른 내 오브젝트의 요청은 지운다. 상태는 오브젝트 상태(tw)로 친구에게 간다.
func _mp_req_set(t: Tower, e: int) -> void:
	if not is_instance_valid(t):
		return
	for x in _my_towers():
		if x != t and x.req_e >= 0:
			x.req_e = -1
			x.queue_redraw()
	t.req_e = e
	t.queue_redraw()
	if e >= 0:
		_show_toast("요청: %s 속성 (친구 화면에 표시돼요)" % Elem.NAMES[e])


## 친구 오브젝트가 지금 든 속성 카드를 요청했나.
func _req_ok(t: Tower) -> bool:
	return mp_mode == "coop" and is_instance_valid(t) and t.owner_id != mp.my_id and t.req_e >= 0 \
		and str(picked.get("type", "")) == "elem" and int(picked.get("e", -1)) == t.req_e


## 요청한 속성을 친구 오브젝트에 넣어 준다: 주인 기기가 넣고 상태를 다시 보낸다.
func _mp_give(t: Tower) -> void:
	mp.send({"t": "gift", "nid": t.net_id, "e": picked["e"], "lv": picked["lv"]}, t.owner_id)
	_show_toast("%s에게 %s 속성을 넣어 줬어요" % [_mp_name(t.owner_id), Elem.NAMES[picked["e"]]])
	sfx.play("place")
	burst(t.position, _card_color(picked), 16, 160.0)
	t.req_e = -1
	t.queue_redraw()
	_after_place()


func _mp_recv_gift(from: int, msg: Dictionary) -> void:
	if mp_mode != "coop":
		return
	var nid := int(msg.get("nid", 0))
	var e := int(msg.get("e", -1))
	var lv := maxi(1, int(msg.get("lv", 1)))
	for t in _my_towers():
		if t.net_id != nid:
			continue
		if t.req_e != e or not t.can_take({"type": "elem", "e": e, "lv": lv}):
			_show_toast("%s가 보낸 %s 속성은 요청이 이미 채워져 들어가지 않았어요" % [_mp_name(from), Elem.NAMES.get(e, "?")])
			return
		var m: String = t.add(e, lv)
		t.req_e = -1
		mp_req_got_w = wave
		t.place_pop = 1.0
		t.queue_redraw()
		_show_toast("%s가 %s 속성을 넣어 줬어요 · %s" % [_mp_name(from), Elem.NAMES[e], m])
		sfx.play("place")
		if m.begins_with("조합"):
			sfx.play("reaction", 0.0)
		burst(t.position, Elem.COLORS[e], 20, 200.0)
		_check_progress()
		return


## 호스트 [내보내기]: 내보낼 사람 고르기 (두 번 눌러야).
func _mp_kick_open() -> void:
	if mp_mode != "coop" or not mp.is_host():
		return
	var items: Array = []
	for id in mp_others:
		if mp_kicked.has(id):
			continue
		var kid: int = id
		items.append([_mp_name(id), Mp.owner_color(id), func(): _mp_kick_confirm(kid)])
	if items.is_empty():
		return
	_mp_pop_show("내보낼 사람 (그 사람 오브젝트는 남고 다시 들어올 수 없어요)", items)


func _mp_kick_confirm(id: int) -> void:
	_mp_pop_show("%s을(를) 정말 내보낼까요?" % _mp_name(id), [["내보내기", Color(1, 0.5, 0.5), func(): _mp_kick(id)]])


func _mp_kick(id: int) -> void:
	if not mp.is_host() or not mp_others.has(id):
		return
	mp_kicked[id] = true
	mp.send({"t": "kick"}, id)
	mp_others[id]["gone"] = true
	mp_ready.erase(id)
	mp_cursors.erase(id)
	_show_toast("%s을(를) 내보냈어요" % _mp_name(id))
	get_tree().create_timer(0.5).timeout.connect(func(): mp._drop(id))  # 메시지가 간 뒤에 끊는다
	_mp_try_go()


## 협동 [보기]: 모두 → 나 → 친구마다 차례로.
func _mp_view_next() -> void:
	var ids: Array = [0, mp.my_id]
	for id in mp_others:
		if not mp_others[id].get("gone", false):
			ids.append(id)
	mp_view = ids[(ids.find(mp_view) + 1) % ids.size()]
	for t in towers.get_children():
		t.queue_redraw()


## 고른 사람 것이 아닌 오브젝트·그 탄·장판을 흐리게 (부드럽게 바뀜).
func _mp_view_fade(delta: float) -> void:
	var k := minf(1.0, delta * 10.0)
	for t in towers.get_children():
		var a := 1.0 if mp_view == 0 or t.owner_id == mp_view else 0.25
		t.self_modulate.a = lerpf(t.self_modulate.a, a, k)  # modulate는 카드 놓기 흐림(_update_place_dim)이 쓴다
	for layer in [projectiles, zones]:
		for n in layer.get_children():
			var ot = n.get("owner_tower")
			var a := 1.0 if mp_view == 0 or not is_instance_valid(ot) or ot.owner_id == mp_view else 0.25
			n.modulate.a = lerpf(n.modulate.a, a, k)


func _mp_wait_end() -> void:
	mp_wait_left = -1.0
	mp_wait_ids.clear()
	mp_wait_show = -1.0
	mp_host_wait = -1.0


## 매 프레임 (멀티 판): 잠수 처리 시간 재기.
func _mp_afk_tick(delta: float) -> void:
	if phase == Phase.GAMEOVER or title_label.visible:
		return
	if mp_wait_show > 0.0:
		mp_wait_show -= delta
	var rest := phase != Phase.WAVE
	if mp_mode == "coop":
		if mp.is_host() and mp_host_wait > 0.0:
			mp_host_wait -= delta
			if mp_host_wait <= 0.0:
				mp_host_wait = -1.0
				_mp_try_go(true)
		var done: bool = mp_ready.get(mp.my_id, false) if mp.is_host() else mp_i_ready
		if mp_afk and rest and not done and mp_wait_left < 0.0:
			mp_wait_left = 2.0  # 자리 비움: 곧바로 대신 고른다
		if mp_wait_left > 0.0:
			mp_wait_left -= delta
			if mp_wait_left <= 0.0:
				mp_wait_left = -1.0
				if rest and not done:
					_mp_auto_rest()
	elif mp_mode == "vs" and rest:
		mp_idle_t += delta
		if mp_idle_t >= float(Rules.tune["vs_idle"]):
			mp_idle_t = 0.0
			_mp_auto_rest()


## 사람이 화면을 누르거나 키를 누름: 잠수 아님.
func _mp_presence() -> void:
	mp_idle_t = 0.0
	mp_afk_n = 0
	if mp_afk:
		mp_afk = false
		mp_wait_left = -1.0
		if mp_mode == "coop":
			mp.send({"t": "afk", "on": false})
		_show_toast("돌아왔어요: 다시 직접 골라요")


## 잠수: 남은 고르기를 대신하고 준비한다 (속성은 반응이 생기는 내 오브젝트에, 없으면 오브젝트가 적은 진입 방향에 새로,
## 다른 카드는 넣을 수 있는 내 오브젝트에, 특성은 동전 말고 첫 번째).
func _mp_auto_rest() -> void:
	if phase == Phase.GAMEOVER or phase == Phase.WAVE or mp_mode == "":
		return
	mp_auto_now = true
	mp_req_mode = false
	mp_pop.visible = false
	for i in 40:
		if phase in [Phase.PLACE, Phase.AIM, Phase.MOVE] or press_t or moving:
			_cancel_step()
			continue
		if perk_mode:
			if coin_stage > 0:
				break
			var opts: Array = perk_offer.filter(func(pk): return pk["id"] != "coin")
			_on_perk(opts[0] if not opts.is_empty() else perk_offer[0])
			continue
		if phase != Phase.CHOOSE or picks_left <= 0 or offer.is_empty():
			break
		if not _mp_auto_pick():
			break
	if phase == Phase.CHOOSE and not perk_mode:
		picks_left = 0
		_enter_ready()
	mp_afk_n += 1
	if mp_mode == "coop":
		if mp_afk_n >= int(Rules.tune["mp_afk_after"]) and not mp_afk:
			mp_afk = true
			mp.send({"t": "afk", "on": true})
			_show_toast("자리 비움: 다음부터 카드를 대신 골라요 (화면을 누르면 돌아와요)")
		else:
			_show_toast("시간이 지나 카드를 대신 골랐어요")
		if phase == Phase.READY:
			_mp_coop_ready()
	elif mp_mode == "vs":
		if mp_afk_n >= int(Rules.tune["vs_idle_out"]):
			mp_auto_now = false
			mp_rank = "%d번 연속 움직임이 없어 탈락했어요" % mp_afk_n
			core_hp = 0
			_game_over()
			return
		_show_toast("오래 움직임이 없어 웨이브를 시작했어요 (%d번 연속이면 탈락)" % int(Rules.tune["vs_idle_out"]))
		if phase == Phase.READY:
			_start_wave()
	mp_auto_now = false


## 카드 하나를 대신 고른다. 고를 게 없으면 false.
func _mp_auto_pick() -> bool:
	var mine: Array = _my_towers()
	for o in offer:
		if o["type"] == "elem":
			for t in mine:
				if t.can_take(o) and not Elem.new_reactions(t.eff_now(), o["e"]).is_empty():
					_on_pick(o)
					_place_on(t)
					return true
		else:
			for t in mine:
				if t.can_take(o):
					_on_pick(o)
					_apply_card(t)
					return true
	for o in offer:
		if o["type"] == "elem" and not (o["e"] == Elem.STAR and star_full()):
			var spot := _mp_auto_spot()
			if spot.is_empty():
				return false
			_on_pick(o)
			_place_tower(spot[0], spot[1])
			_after_place()
			return true
	return false


## 대신 놓을 자리: 오브젝트가 가장 적은 진입 방향, 중앙 가까이 비어 있는 곳 [자리, 방향].
func _mp_auto_spot() -> Array:
	var ls: Array = Array(lanes) if not lanes.is_empty() else [0.0]
	var c := core()
	var best_a: float = ls[0]
	var fewest := 999
	for a in ls:
		var d := Vector2.from_angle(a)
		var cnt := towers.get_children().filter(func(t): return (t.position - c).normalized().dot(d) > 0.9).size()
		if cnt < fewest:
			fewest = cnt
			best_a = a
	var dir := Vector2.from_angle(best_a)
	var f := field_rect()
	for k in 16:
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := c + dir * (90.0 + 28.0 * (k / 2)) + dir.orthogonal() * 24.0 * side
		if f.has_point(p) and towers.get_children().all(func(t): return t.position.distance_to(p) >= MERGE_DIST + 4.0):
			return [p, dir]
	return []


## 시작 화면 [멀티플레이]: 창을 열고 닫는다. 닫으면 만든 방·들어간 방에서 나온다.
func _toggle_mp_lobby() -> void:
	mp_panel.visible = not mp_panel.visible
	if mp_panel.visible:
		mp.check_status()
		var rj := Mp.saved_rejoin()
		if not rj.is_empty() and not mp.active() and mp_mode == "":
			# 껐다 켠 협동 참가자: 코드를 채워 두고 [참가]로 원래 자리에
			mp_code_edit.text = str(rj.get("code", ""))
			mp_status.text = "하던 협동 판이 있어요. [참가]를 누르면 다시 들어가요"
	if mp_panel.visible and Meta.guide_on and not Tutorial.seen.has("mp") and DisplayServer.get_name() != "headless":
		_open_tut(["mp"])  # 멀티 창 위에 바로
	if not mp_panel.visible and mp_mode == "":
		mp.leave()
	_mp_refresh_lobby()


func _mp_btn_shown() -> bool:
	if Mp.sw_hide:
		return false
	return Mp.available() or (Mp.url() != "" and OS.has_feature("windows"))


## 서버 스위치가 바뀜: 숨김이면 버튼·창을 닫고, 막힘이면 창의 안내를 바꾼다 (이미 시작한 판은 그대로).
func _mp_apply_switch() -> void:
	if mp_btn:
		mp_btn.visible = _mp_btn_shown()
	if mp_panel and mp_panel.visible and not Mp.sw_on and mp_mode == "":
		if not mp.active():
			if Mp.sw_hide:
				_toggle_mp_lobby()
			else:
				mp_status.text = _mp_off_text()


func _mp_off_text() -> String:
	return "멀티플레이를 잠시 쉬고 있어요" + (": " + Mp.sw_msg if Mp.sw_msg != "" else "")


## 서버 스위치가 꺼졌거나 연결 부품(WebRTC 확장)을 못 읽은 기기: 방을 열어도 안 되니 미리 막는다.
func _mp_blocked() -> bool:
	if not Mp.sw_on:
		mp_status.text = _mp_off_text()
		return true
	if Mp.loaded():
		return false
	mp_status.text = "이 기기에서 멀티플레이 연결 부품을 읽지 못했어요. 게임을 완전히 껐다 켜 보세요 (계속되면 오류가 자동으로 보고됩니다)"
	return true


func _mp_host(m: String) -> void:
	if _mp_blocked():
		return
	mp_status.text = ""
	mp_load_msg = "방을 만드는 중"
	mp_load_host = true
	mp.host(m, _mp_my_name())
	_mp_refresh_lobby()


func _mp_join() -> void:
	var c := Mp.clean_code(mp_code_edit.text)
	if c.length() != 6:
		mp_status.text = "방 코드 6자리를 넣으세요"
		return
	if _mp_blocked():
		return
	mp_status.text = ""
	mp_load_msg = "방에 들어가는 중"
	mp_load_host = false
	mp.join(c, _mp_my_name())
	_mp_refresh_lobby()


func _mp_failed(reason: String) -> void:
	if mp_mode != "":
		mp_fail_msg = reason
	if mp_mode == "":
		mp_status.text = reason
		_mp_refresh_lobby(false)
		return
	# 판 중에 끊김
	if mp_mode == "coop" and mp_ghost and phase != Phase.GAMEOVER:
		# 협동 참가자: 같은 방에 다시 붙어 본다. 방이 없어졌으면(호스트가 나감) 바로 끝
		var room_gone: bool = mp.last_err in ["nocode", "started"]
		if mp_rejoin_until == 0 and not room_gone:
			mp_rejoin_until = Time.get_ticks_msec() + MP_REJOIN_S * 1000
			_show_toast("연결이 끊겼어요. 다시 접속하는 중…")
		if not room_gone and Time.get_ticks_msec() < mp_rejoin_until:
			mp_rejoin_wait = 2.0
			return
		mp_rejoin_until = 0
		mp_rank = "호스트가 나가 판이 끝났어요" if room_gone else reason
		core_hp = 0
		_game_over()
	elif mp_mode == "vs" and not mp.is_host() and phase != Phase.GAMEOVER:
		# 대결 참가자: 호스트와 끊기면 이 판은 끝 (끊긴 사람은 패배)
		mp_rank = "연결이 끊겨 판이 끝났어요 (끊기면 패배)"
		core_hp = 0
		_game_over()
	else:
		_show_toast(reason)
		for id in mp_others:
			mp_others[id]["gone"] = true


func _mp_refresh_lobby(keep_status := true) -> void:
	if mp_panel == null or mp == null:
		return
	var in_room := mp.active()
	var busy := mp.busy()
	var wait_host := mp.waiting_host()
	mp_host_box.visible = not in_room and not busy
	mp_join_box.visible = not in_room and not busy
	mp_room_box.visible = in_room
	mp_load_view.visible = busy or wait_host
	mp_close_btn.text = "나가기" if in_room or busy else "닫기"
	mp_desc.visible = not in_room and not busy
	_mp_lobby_tick()
	for ch in mp_room_box.get_children():
		mp_room_box.remove_child(ch)
		ch.queue_free()
	mp_ping_labels.clear()
	mp_start_btn.visible = in_room and mp.is_host()
	var ready := mp.connected_ids().size()
	var playing := mp.playing_ids().size() if in_room else 0  # 지난 판이 아직 안 끝난 사람
	mp_start_btn.disabled = ready < 1 or playing > 0
	mp_start_btn.text = "시작 (%d/%d명)" % [ready + 1, Mp.MAX_PLAYERS] if in_room else "시작"
	if not in_room:
		if busy:
			mp_status.text = ""
		elif not keep_status and mp_status.text == "":
			mp_status.text = "방을 만들거나 친구에게 받은 방 코드로 들어가세요"
		return
	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", 12)
	mp_room_box.add_child(code_row)
	var cl := Label.new()
	cl.text = "%s 방 코드  %s" % ["대결" if mp.mode == "vs" else "협동", mp.code]
	cl.add_theme_font_size_override("font_size", 22)
	code_row.add_child(cl)
	var cb := Button.new()
	cb.text = "복사"
	cb.custom_minimum_size = Vector2(90, 38)
	cb.focus_mode = Control.FOCUS_NONE
	cb.pressed.connect(func():
		DisplayServer.clipboard_set(mp.code)
		cb.text = "복사됨")
	code_row.add_child(cb)
	var cnt := Label.new()
	cnt.text = "%d/%d명" % [mp.names().size(), Mp.MAX_PLAYERS]
	cnt.add_theme_font_size_override("font_size", 16)
	cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	code_row.add_child(cnt)
	if wait_host:
		# 참가자: 호스트와 이어지기 전엔 사람 줄 대신 도는 고리만 (이어지면 peers_changed로 다시 그림)
		mp_status.text = ""
		return
	# 사람 줄은 왼쪽 정렬 (그림·★·이름이 세로로 맞게), 목록 덩어리는 창 가운데
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.custom_minimum_size = Vector2(380, 0)
	list.add_theme_constant_override("separation", 6)
	mp_room_box.add_child(list)
	for n in mp.names():
		var id: int = n[0]
		var me := id == mp.my_id
		# 호스트: 내가 차단한 사람은 시작 전에 방에서 내보낸다
		if mp.is_host() and not me and not mp.started and Meta.blocked.has(mp.pids.get(id, "")):
			var did := id
			_show_toast("차단한 플레이어가 들어와서 내보냈어요")
			mp.call_deferred("_drop", did)
			continue
		var nm: String = _mp_name(id) if not me else (n[1] if n[1] != "" else "닉네임 없음")
		var st := "" if me or n[2] else ("연결 안 됨" if n[4] else "연결 중")
		if st == "" and not me and mp.in_game.has(id):
			st = "판 진행 중"
		var row := _mp_member_row(id, n[3], id == 1, nm + (" (나)" if me else ""), st)
		if not me:
			row.add_child(_ugc_buttons(mp.pids.get(id, ""), str(n[1]), "mp", func(): _mp_refresh_lobby()))
		list.add_child(row)
	for i in Mp.MAX_PLAYERS - mp.names().size():
		var empty := _mp_member_row(0, "", false, "빈 자리", "")
		empty.modulate = Color(1, 1, 1, 0.3)
		list.add_child(empty)
	_mp_refresh_pings()
	if mp.relay_lost and mp.is_host():
		mp_status.text = "중개 서버 연결이 끊겨 새로 들어올 수는 없어요. 지금 있는 사람끼리는 계속할 수 있어요" if playing == 0 else "지난 판이 아직 끝나지 않은 사람이 있어요 (중개 서버 연결이 끊겨 새로 들어올 수는 없어요)"
	elif playing > 0:
		mp_status.text = "지난 판이 아직 끝나지 않은 사람이 있어요. 모두 돌아오면 %s" % ("[시작]" if mp.is_host() else "호스트가 시작해요")
	elif mp.is_host():
		mp_status.text = "친구에게 방 코드를 알려 주세요. 연결되면 [시작]" if ready < 1 else "모두 연결되면 [시작]"
	else:
		mp_status.text = "호스트가 시작하기를 기다리는 중"


## 로비 사람 한 줄: [플랫폼 그림] ★(호스트) 닉네임 [연결 중 고리·상태 | 핑]
func _mp_member_row(id: int, pf: String, host: bool, text: String, state: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(26, 26)
	ic.tooltip_text = {"windows": "Windows", "mac": "Mac", "ios": "iPhone·iPad", "android": "Android", "linux": "Linux"}.get(pf, "")
	if id > 0:  # 빈 자리는 그림 없이
		ic.draw.connect(func(): Glyph.ui(ic, "pf_" + (pf if pf != "" else "unknown"), ic.size * 0.5, 10.0, Color(1, 1, 1, 0.85)))
	row.add_child(ic)
	var l := Label.new()
	l.text = ("★ " if host else "    ") + text  # ★ 자리를 비워 이름 시작을 맞춤
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	if state == "연결 중":
		row.add_child(_mp_spinner(8.0))
	if state != "":
		var sl := Label.new()
		sl.text = state
		sl.add_theme_font_size_override("font_size", 16)
		sl.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if state == "연결 안 됨" else Color(1, 1, 1, 0.55))
		row.add_child(sl)
	elif id != mp.my_id and id > 0:
		var pl := Label.new()
		pl.add_theme_font_size_override("font_size", 16)
		pl.tooltip_text = "왕복 지연 (호스트와의 연결 기준)"
		row.add_child(pl)
		mp_ping_labels[id] = pl
	return row


## 핑 글과 색: 80ms 아래 초록, 150ms 아래 노랑, 그 위 빨강. 아직 못 쟀으면 "…ms".
func _mp_ping_text(id: int) -> Array:
	if not mp.ping.has(id):
		return ["…ms", Color(1, 1, 1, 0.4)]
	var ms: int = mp.ping[id]
	return ["%dms" % ms, Color(0.5, 1, 0.55) if ms < 80 else (Color(1, 0.85, 0.35) if ms < 150 else Color(1, 0.45, 0.4))]


func _mp_refresh_pings() -> void:
	for id in mp_ping_labels:
		var l: Label = mp_ping_labels[id]
		if is_instance_valid(l):
			var t := _mp_ping_text(id)
			l.text = t[0]
			l.add_theme_color_override("font_color", t[1])


## 도는 고리 (기다리는 동안). 다시 그리기는 _mp_lobby_tick이 group "mp_spin"으로.
func _mp_spinner(r: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(r * 2.0 + 6.0, r * 2.0 + 6.0)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add_to_group("mp_spin")
	c.draw.connect(func():
		var a := Time.get_ticks_msec() * 0.006
		var w := maxf(2.0, r * 0.22)
		c.draw_arc(c.size * 0.5, r, 0.0, TAU, 32, Color(1, 1, 1, 0.12), w, true)
		c.draw_arc(c.size * 0.5, r, a, a + PI * 1.3, 24, Color(0.6, 0.9, 1.0), w, true))
	return c


## 매 프레임 (창이 열려 있을 때): 고리·접속 화면을 다시 그린다.
func _mp_lobby_tick() -> void:
	if mp_panel == null or not mp_panel.visible:
		return
	get_tree().call_group("mp_spin", "queue_redraw")


## 접속 화면: 내 기기 ─ 오가는 점 ─ 상대(중개 서버·호스트), 지금 하는 일, 단계, (호스트 기다림) 남은 시간 막대.
## 단계: 방 만들기 = 중개 서버 → 방 만들기, 참가 = 중개 서버 → 방 찾기 → 호스트와 직접 연결.
func _mp_draw_load() -> void:
	var c := mp_load_view
	var w := c.size.x
	var font := c.get_theme_default_font()
	var now := Time.get_ticks_msec() / 1000.0
	var wait_host := mp.waiting_host()
	var ws_open := mp.ws.get_ready_state() == WebSocketPeer.STATE_OPEN
	var steps: Array = ["중개 서버", "방 만들기"] if mp_load_host else ["중개 서버", "방 찾기", "호스트와 직접 연결"]
	var cur := 2 if wait_host else (1 if ws_open else 0)
	var accent := Color(0.6, 0.9, 1.0)
	# 그림: 두 기기와 그 사이를 오가는 점
	var y := 44.0
	var a := Vector2(w * 0.24, y)
	var b := Vector2(w * 0.76, y)
	for p in [a, b]:
		c.draw_circle(p, 30.0, Color(1, 1, 1, 0.06))
		c.draw_arc(p, 30.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 1.5, true)
	Glyph.ui(c, "pf_" + str(Mp.PF[Mp.pf_code()]), a, 13.0, Color(1, 1, 1, 0.9))
	if wait_host:
		var hp: String = mp.peers.get(1, {}).get("pf", "")
		Glyph.ui(c, "pf_" + (hp if hp != "" else "unknown"), b, 13.0, Color(1, 1, 1, 0.9))
		Icons.draw(c, "score", b + Vector2(22, -22), 7.0, Color(1, 0.85, 0.4))
	else:
		# 중개 서버: 서버 칸 셋 (불빛은 차례로 깜빡)
		for i in 3:
			var r := Rect2(b + Vector2(-13, -13 + i * 9), Vector2(26, 7))
			c.draw_rect(r, Color(1, 1, 1, 0.85), false, 1.5)
			var on := int(now * 4.0) % 3 == i
			c.draw_circle(r.position + Vector2(20, 3.5), 1.6, accent if on else Color(1, 1, 1, 0.5))
	c.draw_arc(b, 36.0, now * 3.0, now * 3.0 + PI * 1.2, 24, accent, 3.0, true)  # 기다리는 쪽에 도는 고리
	var x0 := a.x + 40.0
	var x1 := b.x - 40.0
	for i in 9:
		c.draw_circle(Vector2(lerpf(x0, x1, i / 8.0), y), 1.5, Color(1, 1, 1, 0.18))
	for i in 3:
		var t := fposmod(now * 0.6 + i / 3.0, 1.0)
		var back := i == 1  # 하나는 되돌아오는 답
		var px := lerpf(x0, x1, 1.0 - t if back else t)
		c.draw_circle(Vector2(px, y), 4.0, Color(accent, sin(t * PI)))
	c.draw_string(font, Vector2(0, y + 52), "나", HORIZONTAL_ALIGNMENT_CENTER, w * 0.48, 14, Color(1, 1, 1, 0.55))
	var right := ("호스트 " + _mp_name(1)) if wait_host else "중개 서버"
	c.draw_string(font, Vector2(w * 0.52, y + 52), right, HORIZONTAL_ALIGNMENT_CENTER, w * 0.48, 14, Color(1, 1, 1, 0.55))
	# 지금 하는 일
	var dots := ".".repeat(1 + int(now * 2.5) % 3)
	var title: String = ["중개 서버에 접속하는 중", mp_load_msg if not ws_open or mp_load_host else "방을 찾는 중", "호스트와 직접 연결하는 중"][cur]
	if cur == 1 and mp_load_host:
		title = "방을 만드는 중"
	c.draw_string(font, Vector2(0, 132), title + dots, HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color.WHITE)
	# 단계: 끝난 것 초록 ✓, 지금 것 파랑, 남은 것 흐리게
	var fs := 15
	var parts: Array = []
	var total := 0.0
	for i in steps.size():
		var tx: String = ("✓ " if i < cur else "%d " % (i + 1)) + steps[i]
		var tw := font.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		parts.append([tx, tw, Color(0.5, 1, 0.55) if i < cur else (accent if i == cur else Color(1, 1, 1, 0.35))])
		total += tw + (34.0 if i < steps.size() - 1 else 0.0)
	var sx := (w - total) * 0.5
	for i in parts.size():
		c.draw_string(font, Vector2(sx, 162), parts[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, parts[i][2])
		sx += parts[i][1]
		if i < parts.size() - 1:
			c.draw_line(Vector2(sx + 9, 157), Vector2(sx + 25, 157), Color(1, 1, 1, 0.25), 1.5)
			sx += 34.0
	# 호스트 기다림: 남은 시간 막대 (Mp.WAIT_JOIN초가 지나면 실패로 돌아감)
	if wait_host:
		var el := clampf((Time.get_ticks_msec() - mp.joined_ms) / 1000.0, 0.0, Mp.WAIT_JOIN)
		var bar := Rect2(w * 0.2, 180, w * 0.6, 5)
		c.draw_rect(bar, Color(1, 1, 1, 0.1))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * el / Mp.WAIT_JOIN, bar.size.y)), accent if el < 10.0 else Color(1, 0.75, 0.35))
		c.draw_string(font, Vector2(bar.end.x + 10, 187), "%d / %d초" % [int(el), int(Mp.WAIT_JOIN)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
		if el >= 8.0:
			c.draw_string(font, Vector2(0, 210), "오래 걸리면 두 기기의 인터넷·방화벽을 확인해 보세요", HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(1, 1, 1, 0.5))


## 호스트 [시작]: 씨앗·맵·규칙을 정해 모두에게 보내고 함께 시작한다.
func _mp_start() -> void:
	if not mp.is_host() or mp.connected_ids().is_empty() or not mp.playing_ids().is_empty():
		return
	var ids: Array = [1] + mp.connected_ids()
	var names := {}
	for id in ids:
		names[id] = mp.peers.get(id, {}).get("name", "")
	var msg := {"t": "start", "seed": randi() % 2000000000 + 1, "map": Meta.map_id, "flip": Meta.line_flip, "rules": Meta.rules,
		"mode": mp.mode, "ids": ids, "names": names}
	mp.lock()
	mp.send(msg)
	_mp_begin(msg)


## 멀티 판이 끝나고 돌아옴: 시작 화면 위에 대기방(멀티플레이 창)을 연다. 방이 남아 있으면 다시 들어올 수 있게 풀고 알린다.
func _mp_back_lobby() -> void:
	mp_back = false
	title_label.visible = true
	_refresh_continue()
	hint.text = ""
	mp_panel.visible = true
	if mp.active():
		mp.back_to_lobby()
		mp_status.text = ""
		_mp_refresh_lobby()
	else:
		_mp_refresh_lobby()
		mp_status.text = mp_back_msg
	mp_back_msg = ""


func _mp_begin(msg: Dictionary) -> void:
	mp.started = true
	mp.in_game.clear()
	for id in msg.get("ids", []):
		mp.in_game[int(id)] = true
	mp_start = msg.duplicate(true)
	mp_cursors.clear()
	mp_code_last = mp.code
	mp_mode = str(msg.get("mode", "vs"))
	mp.save_rejoin(mp_mode == "coop" and not mp.is_host())  # 협동 참가자만 다시 들어올 수 있다
	var m := str(msg.get("map", "plain"))
	Meta.map_id = m if m in Meta.MAP_IDS else "plain"
	Meta.line_flip = msg.get("flip", false) == true
	var r := int(msg.get("rules", 1))
	Meta.rules = r if r in Rules.IDS else 1
	Modes.set_on([])
	_apply_rules()
	mp_others.clear()
	var names: Dictionary = msg.get("names", {})
	for id in msg.get("ids", []):
		if int(id) != mp.my_id:
			var c0 := roundi(CORE_MAX_HP * float(Rules.tune["mp_core"]))
			mp_others[int(id)] = {"name": str(names.get(id, "")), "w": 0, "hp": c0, "mx": c0, "sc": 0, "alive": true, "gone": false}
	mp_seed = int(msg.get("seed", 1)) if mp_mode == "vs" else 0
	Ach.mp = mp_mode
	for id in mp_others:
		var nk: String = str(Mp.split_name(str(mp_others[id]["name"]))[0]).strip_edges()
		if nk != "":
			Ach.raise("mpn:" + nk.left(16), 1)
	mp_ghost = mp_mode == "coop" and not mp.is_host()
	vs_on = mp_mode == "vs"
	if mp_mode == "coop":
		coop_n = 1 + mp_others.size()
		coop_orbs = 1.0 + float(Rules.tune["coop_orb_per"]) * (coop_n - 1)
		auto_start = false
		_update_auto_btn()
	mp_panel.visible = false
	var tn := Meta.tutor_next
	Meta.tutor_next = false  # 멀티플레이는 첫 판 안내(카드 종류를 하나씩 엶) 없이
	_hide_title()
	lanes.clear()
	_start_choose()
	Meta.tutor_next = tn
	big_banner("%s 시작! %d명" % ["대결" if mp_mode == "vs" else "협동", mp_others.size() + 1], Color(0.6, 0.9, 1.0))


func _mp_packet(from: int, msg: Dictionary) -> void:
	var t := str(msg.get("t", ""))
	if t == "start":
		if from == 1 and mp_mode == "" and mp.active():
			_mp_begin(msg)
		return
	if t == "re":
		if from == 1 and not mp.is_host() and mp.active():
			_mp_resync(msg)
		return
	if t == "kick" and from == 1 and mp_mode == "":
		# 내보내진 뒤 같은 코드로 다시 들어오려 함
		mp.save_rejoin(false)
		mp.leave()
		if mp_status:
			mp_status.text = "호스트가 판에서 내보냈어요"
		_mp_refresh_lobby()
		return
	if mp_mode == "":
		return
	match t:
		"gone":
			mp_cursors.erase(from)
			if mp_others.has(from):
				mp_others[from]["gone"] = true
				if mp_mode == "vs" and mp_others[from]["alive"]:
					mp_others[from]["alive"] = false  # 대결은 끊기면 패배 (다시 못 들어옴)
					_show_toast("%s 연결이 끊겨 탈락했어요" % _mp_name(from))
				else:
					_show_toast("%s 연결이 끊겼어요%s" % [_mp_name(from), " (같은 방 코드로 다시 들어올 수 있어요)" if mp_mode == "coop" else ""])
			mp_ready.erase(from)
			if mp_mode == "coop" and mp.is_host():
				_mp_try_go()
			elif mp_mode == "vs":
				_mp_check_win()
		"st":
			if mp_others.has(from):
				var o: Dictionary = mp_others[from]
				o["w"] = int(msg.get("w", 0))
				o["hp"] = int(msg.get("hp", 0))
				o["mx"] = int(msg.get("mx", CORE_MAX_HP))
				o["sc"] = int(msg.get("sc", 0))
		"dead":
			if mp_others.has(from):
				mp_others[from]["alive"] = false
				mp_others[from]["w"] = int(msg.get("w", 0))
				mp_others[from]["sc"] = int(msg.get("sc", 0))
				_show_toast("%s 탈락 (웨이브 %d)" % [_mp_name(from), mp_others[from]["w"]])
				_mp_check_win()
		"atk":
			var n := int(msg.get("n", 0))
			if n <= 0 or phase == Phase.GAMEOVER:
				return
			# 한 웨이브에 받는 상한: 넘치는 만큼은 (보낸 사람 말고) 점수가 가장 높은 다른 사람에게 넘긴다 (한 번만)
			var cap := ceili((1 + (wave + 1) / 4) * float(Rules.tune["vs_recv_cap"]))
			var over := maxi(0, mp_recv_n + n - cap)
			if over > 0:
				n -= over
				if not msg.get("fw", false):
					var nxt := _mp_vs_target([from])
					if nxt > 0:
						mp.send({"t": "atk", "n": over, "fw": true}, nxt)
				if n <= 0:
					return
			mp_recv_n += n
			if phase == Phase.WAVE:
				mp_pending += n
			else:
				mp_next_extra += n
				_update_preview()
			_show_toast("%s가 구체 %d개를 보냈어요 (다음 웨이브에 더 옴)" % [_mp_name(from), n])
			sfx.play("danger", 0.0)
		"tw":
			_mp_recv_towers(from, msg.get("list", []))
		"cur":
			if mp_mode == "coop" and from != mp.my_id:
				var to := Vector2(float(msg.get("x", 0)), float(msg.get("y", 0)))
				var c: Dictionary = mp_cursors.get(from, {"p": to})
				c["to"] = to
				c["t"] = Time.get_ticks_msec()
				mp_cursors[from] = c
		"perk":
			var id := str(msg.get("id", ""))
			if PERKS.any(func(pk): return pk["id"] == id):
				perks[id] = perks.get(id, 0) + 1
				_apply_perk(id)
				_show_toast("%s 특성: %s (팀 전체)" % [_mp_name(from), _perk_name(id)])
		"ready":
			if mp.is_host():
				mp_ready[from] = true
				_mp_try_go()
		"wait":
			# 협동: 누군가 웨이브 시작을 눌렀다. 아직 고르는 사람은 정해진 시간 안에 고르고, 지나면 대신 고른다
			mp_wait_ids = (msg.get("ids", []) as Array).map(func(x): return int(x))
			mp_wait_show = float(msg.get("s", 0))
			if mp.my_id in mp_wait_ids and not mp_i_ready and mp_wait_left < 0.0:
				mp_wait_left = 2.0 if mp_afk else float(msg.get("s", Rules.tune["mp_wait"]))
		"afk":
			if mp_others.has(from):
				mp_others[from]["afk"] = msg.get("on", false) == true
		"kick":
			if from == 1 and mp_mode == "coop" and phase != Phase.GAMEOVER:
				mp.save_rejoin(false)
				mp_rank = "호스트가 판에서 내보냈어요"
				mp_fail_msg = mp_rank
				core_hp = 0
				_game_over()
		"gift":
			_mp_recv_gift(from, msg)
		"wave":
			if mp_ghost and from == 1:
				_mp_wait_end()
				wave = int(msg.get("w", wave + 1)) - 1
				mp_wave_go = true
				_end_ghost_rest()
				_start_wave()
				mp_wave_go = false
				mp_i_ready = false
		"next":
			if mp_ghost and from == 1:
				mp_next = msg
				if int(msg.get("w", -1)) == wave:
					_mp_ghost_rest()
					_update_preview()
		"snap":
			if mp_ghost and from == 1:
				_mp_apply_snap(msg)
		"clear":
			if mp_ghost and from == 1 and phase == Phase.WAVE:
				_mp_ghost_clear(msg)
		"over":
			if mp_ghost and from == 1 and phase != Phase.GAMEOVER:
				score = int(msg.get("sc", score))
				kills = int(msg.get("k", kills))
				wave = int(msg.get("w", wave))
				core_hp = 0
				_game_over()


## 협동 호스트: 끊겼던 참가자가 같은 자리로 다시 이어짐 → 지금 판 상태를 통째로 보낸다.
func _mp_peer_up(id: int) -> void:
	if mp_mode != "coop" or not mp.is_host() or not mp_others.has(id) or phase == Phase.GAMEOVER:
		return
	if mp_kicked.has(id):
		mp.send({"t": "kick"}, id)  # 내보낸 사람은 다시 들어올 수 없다
		return
	mp_others[id]["gone"] = false
	var st := mp_start.duplicate(true)
	st["t"] = "re"
	var ids: Array = [1] + mp_others.keys()
	var names := {1: mp.my_name}
	for k in mp_others:
		names[k] = mp_others[k]["name"]
	st["ids"] = ids
	st["names"] = names
	var tw := {}
	for t in towers.get_children():
		if t.is_queued_for_deletion():
			continue
		if not tw.has(t.owner_id):
			tw[t.owner_id] = []
		tw[t.owner_id].append(t.mp_state())
	st.merge({"w": wave, "ph": "wave" if phase == Phase.WAVE else "rest", "sc": score, "k": kills, "hp": core_hp, "mx": core_max,
		"perks": perks.duplicate(), "tw": tw, "next": {"t": "next", "w": wave, "lanes": Array(lanes), "res": wave_resist, "boss": boss_plan}}, true)
	mp.send(st, id)
	_show_toast("%s 다시 들어왔어요" % _mp_name(id))


## 협동 참가자: 호스트가 보낸 판 상태로 맞춘다 (끊겼다 다시 붙음, 또는 게임을 껐다 켜고 같은 코드로 들어옴).
## 쉬는 시간이면 카드 고르기 없이 웨이브 기다림으로 (다시 들어와 카드를 더 받지 않게).
func _mp_resync(msg: Dictionary) -> void:
	var fresh := mp_mode == ""
	mp_rejoin_until = 0
	mp_rejoin_wait = 0.0
	for t in towers.get_children():
		towers.remove_child(t)
		t.queue_free()
	selected.clear()
	for o in orbs.get_children():
		o.queue_free()
	mp_ghosts.clear()
	if fresh:
		_mp_begin(msg)
		for id in msg.get("perks", {}):
			for i in int(msg["perks"][id]):
				if PERKS.any(func(pk): return pk["id"] == id):
					perks[id] = perks.get(id, 0) + 1
					_apply_perk(id)
	else:
		mp.started = true
		mp_code_last = mp.code
		mp.save_rejoin(true)
		for id in mp_others:
			mp_others[id]["gone"] = false
	score = int(msg.get("sc", 0))
	kills = int(msg.get("k", 0))
	core_max = int(msg.get("mx", core_max))
	core_hp = int(msg.get("hp", core_hp))
	var tw: Dictionary = msg.get("tw", {})
	mp_tw_n = 0
	for owner in tw:
		for d in tw[owner]:
			if not d is Dictionary:
				continue
			var t := Tower.new()
			t.main = self
			t.owner_id = int(owner)
			t.net_id = int(d.get("nid", 0))
			t.mp_apply(d)
			if t.order.is_empty():
				t.free()
				continue
			towers.add_child(t)
			if t.owner_id == mp.my_id:
				mp_tw_n = maxi(mp_tw_n, t.net_id % 100000)
	mp_tw_sig = ""
	_end_ghost_rest()
	mp_next = msg.get("next", {})
	if str(msg.get("ph", "rest")) == "wave":
		wave = int(msg.get("w", 1)) - 1
		mp_next["w"] = wave  # 호스트가 지금 웨이브 진입 방향을 보냈다 (평소 next는 쉬는 시간에 지난 웨이브 번호로)
		_mp_ghost_rest()
		mp_wave_go = true
		_start_wave()
		mp_wave_go = false
	else:
		wave = int(msg.get("w", 0))
		_mp_ghost_rest()
		_enter_ready()
		_update_preview()
	mp_i_ready = false
	_refresh_dps()
	_show_toast("다시 들어왔어요 (웨이브 %d)" % maxi(wave, 1))


func _perk_name(id: String) -> String:
	for pk in PERKS:
		if pk["id"] == id:
			return pk["name"]
	return id


func _mp_send_perk(id: String) -> void:
	if mp_mode == "coop":
		mp.send({"t": "perk", "id": id})


## 매 프레임: 상태·오브젝트·전장 보내기, 위쪽 상태 줄.
func _mp_tick(delta: float) -> void:
	if mp_mode == "":
		return
	if mp_mode == "coop":
		_mp_cursor_tick(delta)
	if mp_rejoin_wait > 0.0:
		mp_rejoin_wait -= delta
		if mp_rejoin_wait <= 0.0:
			mp.join(mp_code_last, _mp_my_name())
	_mp_afk_tick(delta)
	mp_tick_t += delta
	mp_snap_t += delta
	if mp_mode == "vs" and mp_tick_t >= 0.5:
		mp_tick_t = 0.0
		var ws: Array = mp_others.values().filter(func(o): return o["alive"] and not o["gone"]).map(func(o): return int(o["w"]))
		if not ws.is_empty() and wave < ws.min() and phase != Phase.GAMEOVER:
			mp_was_last = true  # 역전 업적: 한때 웨이브 꼴찌
		var sig := "%d/%d/%d/%d" % [wave, core_hp, core_max, score]
		if sig != mp_st_sig and phase != Phase.GAMEOVER:
			mp_st_sig = sig
			mp.send({"t": "st", "w": wave, "hp": core_hp, "mx": core_max, "sc": score})
	if mp_mode == "coop":
		if mp_tick_t >= 0.25 and phase != Phase.GAMEOVER:
			mp_tick_t = 0.0
			_mp_send_towers()
		if mp.is_host() and phase == Phase.WAVE and mp_snap_t >= 1.0 / 12.0:
			mp_snap_t = 0.0
			_mp_send_snap()
	mp_bar.visible = not title_label.visible
	mp_bar.position = Vector2(hud.position.x + 2.0, hud.position.y + hud.size.y + 4.0)
	var mine_n := _my_towers().size() if mp_mode == "coop" else 0
	mp_req_btn.visible = mp_mode == "coop" and phase in [Phase.CHOOSE, Phase.READY] and not perk_mode and mine_n > 0
	mp_kick_btn.visible = mp_mode == "coop" and mp.is_host() and phase != Phase.GAMEOVER \
		and mp_others.keys().any(func(id): return not mp_kicked.has(id))
	mp_view_btn.visible = mp_mode == "coop" and phase != Phase.GAMEOVER
	if phase == Phase.GAMEOVER:
		mp_view = 0  # 끝 화면에선 모두 보이게
	if mp_view > 0 and mp_view != mp.my_id and (not mp_others.has(mp_view) or mp_others[mp_view].get("gone", false)):
		mp_view = 0  # 고른 사람이 나감
	mp_view_btn.text = "보기: " + ("모두" if mp_view == 0 else _mp_name(mp_view))
	if mp_view > 0:
		mp_view_btn.add_theme_color_override("font_color", Mp.owner_color(mp_view))
	else:
		mp_view_btn.remove_theme_color_override("font_color")
	if mp_mode == "coop":
		_mp_view_fade(delta)
	mp_act.visible = mp_bar.visible and (mp_req_btn.visible or mp_kick_btn.visible or mp_view_btn.visible)
	mp_act.position = mp_bar.position + Vector2(0, mp_bar.size.y + 2.0)
	if not mp_req_btn.visible and mp_req_mode:
		mp_req_mode = false
		mp_req_btn.text = "속성 요청"
	if mp_bar.visible:
		var parts := PackedStringArray()
		if mp_mode == "vs":
			for id in mp_others:
				var o: Dictionary = mp_others[id]
				var nm := _mp_name(id)
				if o["gone"] and o["alive"]:
					parts.append("%s 연결 끊김" % nm)
				elif not o["alive"]:
					parts.append("%s 탈락 W%d" % [nm, o["w"]])
				else:
					parts.append("%s W%d ♥%d/%d %s점%s" % [nm, o["w"], o["hp"], o["mx"], num(o["sc"]), _mp_bar_ping(id)])
			mp_bar.text = "대결 · " + "   |   ".join(parts)
		else:
			for id in mp_others:
				var tag := " (끊김)" if mp_others[id]["gone"] else _mp_bar_ping(id)
				if mp_others[id].get("afk", false) and not mp_others[id]["gone"]:
					tag = " (자리 비움)"
				elif id in mp_wait_ids and mp_wait_show > 0.0 and not mp_others[id]["gone"]:
					tag = " (고르는 중 %d초)" % ceili(mp_wait_show)
				parts.append("%s%s" % [_mp_name(id), tag])
			var me := "호스트" if mp.is_host() else "참가"
			if mp_afk:
				me += ", 자리 비움"
			elif mp_wait_left > 0.0:
				me += ", %d초 뒤 대신 고름" % ceili(mp_wait_left)
			mp_bar.text = "협동 · 나(%s) + %s" % [me, ", ".join(parts)]
			if mp_rejoin_until > 0:
				mp_bar.text = "협동 · 다시 접속하는 중… %d초" % maxi(0, (mp_rejoin_until - Time.get_ticks_msec()) / 1000)
			mp_bar.add_theme_color_override("font_color", Mp.owner_color(mp.my_id))


## 협동: 내 마우스 위치를 보내고(움직였을 때만, 초당 MP_CUR_HZ번) 받은 위치를 따라간다.
func _mp_cursor_tick(delta: float) -> void:
	mp_cur_t += delta
	if mp_cur_t >= 1.0 / MP_CUR_HZ:
		mp_cur_t = 0.0
		var m := _pointer_world()
		if m.distance_to(mp_cur_last) > 1.0 and not title_label.visible:
			mp_cur_last = m
			mp.send({"t": "cur", "x": roundf(m.x), "y": roundf(m.y)}, 0, false)
	var k := 1.0 - exp(-14.0 * delta)
	for id in mp_cursors:
		var c: Dictionary = mp_cursors[id]
		c["p"] = (c["p"] as Vector2).lerp(c["to"], k)
	if not mp_cursors.is_empty():
		mp_cur_layer.queue_redraw()


## 다른 사람 커서: 주인 색 화살표 + 닉네임. 화면 확대와 상관없이 같은 크기.
func _draw_mp_cursors() -> void:
	if mp_mode != "coop":
		return
	var now := Time.get_ticks_msec()
	var z := 1.0 / maxf(0.01, camera.zoom.x) if camera else 1.0
	for id in mp_cursors:
		var c: Dictionary = mp_cursors[id]
		var age: int = now - int(c["t"])
		if age > MP_CUR_HIDE_MS:
			continue
		var a := clampf((MP_CUR_HIDE_MS - age) / 1000.0, 0.0, 1.0)
		var col := Color(Mp.owner_color(id), a)
		var p: Vector2 = c["p"]
		var tri := PackedVector2Array([p, p + Vector2(0, 22) * z, p + Vector2(6, 17) * z, p + Vector2(14, 16) * z])
		mp_cur_layer.draw_colored_polygon(tri, col)
		tri.append(p)
		mp_cur_layer.draw_polyline(tri, Color(0, 0, 0, 0.7 * a), 1.5 * z, true)
		var nm := _mp_name(id)
		var fs := 13
		mp_cur_layer.draw_set_transform(p + Vector2(16, 28) * z, 0.0, Vector2(z, z))
		mp_cur_layer.draw_string_outline(ui_font, Vector2.ZERO, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75 * a))
		mp_cur_layer.draw_string(ui_font, Vector2.ZERO, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		mp_cur_layer.draw_set_transform(Vector2.ZERO)


func _mp_bar_ping(id: int) -> String:
	return " · %dms" % mp.ping[id] if mp.ping.has(id) else ""


## 쉬는 시간 시작 (_new_rest 안): 대결은 받아 둔 구체를 예고에, 협동 호스트는 다음 웨이브를 참가자에게.
func _mp_rest_begin() -> void:
	if mp_mode == "vs":
		mp_next_extra += mp_pending
		mp_pending = 0
	elif mp_mode == "coop" and mp.is_host():
		mp.send({"t": "next", "w": wave, "lanes": Array(lanes), "res": wave_resist, "boss": boss_plan})


## 대결: 상대가 보낸 구체를 웨이브 동안 섞어 내보낸다 (같은 웨이브 순서를 흐트리지 않게 씨앗 밖에서 뽑음).
func _mp_spawn_extra(delta: float) -> void:
	if randf() > delta * 1.2:
		return
	mp_extra_left -= 1
	w_off = true
	_spawn_orb()
	w_off = false


## 대결: 웨이브를 막았을 때. 중앙이 한 번도 안 맞았으면 상대에게 구체를 보낸다.
## 협동 호스트: 참가자에게 웨이브 끝을 알린다.
func _mp_wave_cleared() -> void:
	if mp_mode == "coop" and mp.is_host():
		var sh := _mp_shares()
		mp.send({"t": "clear", "w": wave, "perk": wave % 5 == 0, "sc": score, "hp": core_hp, "mx": core_max, "k": kills, "sh": sh})
		_mp_ach_coop(wave, sh)
		return
	if mp_mode != "vs":
		return
	if wave_dmg == 0 and mp_wave_extra > 0:
		Ach.raise("max:mp_counter", 1)
	_mp_ach_win()
	if wave_dmg > 0:
		_ach_check()
		return
	var to := _mp_vs_target([])
	if to <= 0:
		_ach_check()
		return
	var n := maxi(1, roundi((1 + wave / 4) * _mp_send_k()))
	mp.send({"t": "atk", "n": n}, to)
	Ach.add("mp_sent", n)
	_ach_check()
	_show_toast("완벽 방어! %s에게 구체 %d개를 보냈어요" % [_mp_name(to), n])


## 대결: 보내는 구체 배율. 살아 있는 사람이 많을수록 줄인다 (1위가 여럿에게 한꺼번에 받지 않게).
func _mp_send_k() -> float:
	var n := 1 + mp_others.values().filter(func(o): return o["alive"] and not o["gone"]).size()
	if n <= 2:
		return 1.0
	return float(Rules.tune["vs_send3"]) if n == 3 else float(Rules.tune["vs_send4"])


## 대결: 구체를 받을 사람 = 살아 있는 상대 중 점수가 가장 높은 사람 (skip은 빼고). 없으면 0.
func _mp_vs_target(skip: Array) -> int:
	var alive: Array = mp_others.keys().filter(func(id): return mp_others[id]["alive"] and not mp_others[id]["gone"] and not id in skip)
	if alive.is_empty():
		return 0
	alive.sort_custom(func(a, b): return mp_others[a]["sc"] > mp_others[b]["sc"])
	return alive[0]


## 협동 호스트: 사람마다 판 전체 피해 비중 {id: 0~1}.
func _mp_shares() -> Dictionary:
	var by := {}
	var total := 0.0
	for t in towers.get_children():
		var d: float = t.run_dealt + t.dealt
		by[t.owner_id] = by.get(t.owner_id, 0.0) + d
		total += d
	var out := {}
	for id in [1] + mp_others.keys():
		out[id] = snappedf(by.get(id, 0.0) / total, 0.001) if total > 0.0 else 0.0
	return out


## 협동 업적: 웨이브 w를 막음 (sh: 사람마다 피해 비중).
func _mp_ach_coop(w: int, sh: Dictionary) -> void:
	Ach.raise("max:mp_coop", w)
	if coop_n >= 4:
		Ach.raise("max:mp_coop4", w)
	if w >= 12 and sh.size() >= 2:
		if sh.values().all(func(v): return float(v) >= 0.2):
			Ach.raise("max:mp_even", 1)
		var mine := 0.0
		for k in sh:
			if int(k) == mp.my_id:
				mine = float(sh[k])
		if mine >= 0.6:
			Ach.raise("max:mp_carry", 1)
	_ach_check()


## 대결 승리 업적: 상대가 모두 빠졌고 내 웨이브가 5 이상일 때 한 번.
func _mp_ach_win() -> void:
	if not mp_won or mp_win_counted or wave < 5 or mp_mode != "vs":
		return
	mp_win_counted = true
	Ach.add("mp_wins")
	if mp_others.size() + 1 >= 4:
		Ach.add("mp_wins4")
	if mp_was_last:
		Ach.raise("max:mp_comeback", 1)
	_ach_check()


## 대결·협동: 이 기기가 끝났을 때.
func _mp_over() -> void:
	if mp_mode == "vs":
		mp.send({"t": "dead", "w": wave, "sc": score})
		var rows: Array = [[mp.my_id, wave, score]]
		for id in mp_others:
			var o: Dictionary = mp_others[id]
			rows.append([id, o["w"], o["sc"], o["alive"] and not o["gone"]])
		rows.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[2] > b[2]))
		var place := 1 + mp_others.values().filter(func(o): return o["alive"] and not o["gone"]).size()
		var ls := PackedStringArray()
		for r in rows:
			ls.append("%s W%d%s" % [_mp_name(r[0]), r[1], " (진행 중)" if r.size() > 3 and r[3] else ""])
		mp_rank = "대결 %d위 / %d명 · %s" % [place, mp_others.size() + 1, " · ".join(ls)]
	elif mp_mode == "coop":
		mp.save_rejoin(false)
		if mp.is_host():
			mp.send({"t": "over", "w": wave, "sc": score, "k": kills})
		if mp_rank == "":
			mp_rank = "협동 %d명 · 함께 웨이브 %d까지" % [mp_others.size() + 1, wave]


## 대결: 다른 사람이 모두 탈락하면 승리 (판은 계속할 수 있다).
func _mp_check_win() -> void:
	if phase == Phase.GAMEOVER or mp_others.is_empty():
		return
	if mp_others.values().all(func(o): return not o["alive"] or o["gone"]):
		if mp_won:
			return
		mp_won = true
		big_banner("승리! 끝까지 버텨 기록을 늘려 보세요", Color(1, 0.85, 0.3))
		sfx.play("clear", 0.0)
		_mp_ach_win()


# --- 협동 ---

## 웨이브 시작을 누름: 모두 누르면 호스트가 시작한다.
func _mp_coop_ready() -> void:
	if phase != Phase.READY:
		return
	mp_wait_left = -1.0
	if not mp_auto_now:
		mp_afk_n = 0  # 스스로 눌렀다
	if mp.is_host():
		mp_ready[1] = true
		_mp_try_go()
	elif not mp_i_ready:
		mp_i_ready = true
		mp.send({"t": "ready"}, 1)
		start_btn.text = "친구를 기다리는 중…"


## force: 기다림이 다 지나 안 누른 사람(응답 없는 기기)을 두고 시작.
func _mp_try_go(force := false) -> void:
	var need: Array = mp.connected_ids()
	var have := need.filter(func(id): return mp_ready.get(id, false)).size()
	var host_ok: bool = mp_ready.get(1, false) and phase == Phase.READY
	if force and not host_ok and phase != Phase.GAMEOVER and phase != Phase.WAVE:
		mp_host_wait = 999.0  # 대신 고르는 동안 기다림 알림을 다시 보내지 않게
		_mp_auto_rest()  # 호스트 자신이 잠수: 대신 고르고 준비
		mp_host_wait = -1.0
		if phase == Phase.READY:
			mp_ready[1] = true
			_mp_try_go(true)
		return
	if not force and (not host_ok or have < need.size()):
		if (host_ok or have > 0) and mp_host_wait < 0.0:
			# 누군가 눌렀다: 남은 사람에게 기다림 시간을 알린다
			var w: float = Rules.tune["mp_wait"]
			mp_host_wait = w + float(Rules.tune["mp_wait_force"])
			var left: Array = ([] if host_ok else [1]) + need.filter(func(id): return not mp_ready.get(id, false))
			mp.send({"t": "wait", "s": w, "ids": left})
			_mp_packet(1, {"t": "wait", "s": w, "ids": left})  # 호스트 자신에게도
		if host_ok:
			start_btn.text = "친구를 기다리는 중 (%d/%d)" % [have + 1, need.size() + 1]
		return
	if phase != Phase.READY:
		return
	mp_ready.clear()
	_mp_wait_end()
	mp.send({"t": "wave", "w": wave + 1})
	mp_wave_go = true
	_start_wave()
	mp_wave_go = false


## 참가자: 호스트가 웨이브를 시작했는데 아직 고르는 중이면 그대로 닫는다.
func _end_ghost_rest() -> void:
	if phase in [Phase.PLACE, Phase.AIM, Phase.MOVE]:
		_cancel_step()
	perk_mode = false
	choice_box.visible = false


## 참가자의 쉬는 시간: 다음 웨이브는 호스트가 보낸 것으로.
func _mp_ghost_rest() -> void:
	if int(mp_next.get("w", -1)) != wave:
		return
	lanes.assign((mp_next.get("lanes", []) as Array).filter(func(a): return a is float))
	wave_resist = int(mp_next.get("res", -1))
	var bp: Variant = mp_next.get("boss", {})
	boss_plan = bp if bp is Dictionary else {}


## 참가자: 호스트 웨이브가 끝남 → 이 기기도 쉬는 시간.
func _mp_ghost_clear(msg: Dictionary) -> void:
	wave = int(msg.get("w", wave))
	score = int(msg.get("sc", score))
	kills = int(msg.get("k", kills))
	core_max = int(msg.get("mx", core_max))
	core_hp = int(msg.get("hp", core_hp))
	for o in orbs.get_children():
		o.queue_free()
	mp_ghosts.clear()
	combo_hold = true
	_show_toast("웨이브 %d 클리어!" % wave)
	sfx.play("clear", 0.0)
	_show_mvp()
	var sh: Variant = msg.get("sh", {})
	_mp_ach_coop(wave, sh if sh is Dictionary else {})
	if bool(msg.get("perk", false)):
		_start_perk()
	else:
		_start_choose()


## 호스트: 전장 구체 상태를 보낸다 [번호, x, y, 체력, 최대, 종류, 보호막, 저항+1, 굳셈 + 2x(후반 구체 번호+1)].
func _mp_send_snap() -> void:
	var o_list := PackedFloat32Array()
	for o in orbs.get_children():
		if o.is_queued_for_deletion():
			continue
		if o.net_id == 0:
			mp_orb_n += 1
			o.net_id = mp_orb_n
		o_list.append_array([o.net_id, o.position.x, o.position.y, o.hp, o.max_hp, o.kind, o.shield, o.resist_e + 1, (1.0 if o.sturdy else 0.0) + 2.0 * (LATE_IDS.find(o.late) + 1)])
	mp.send({"t": "snap", "w": wave, "hp": core_hp, "mx": core_max, "sc": score, "k": kills, "cb": combo, "o": o_list}, 0, false)


func _mp_apply_snap(msg: Dictionary) -> void:
	if phase != Phase.WAVE or int(msg.get("w", -1)) != wave:
		return
	var hp := int(msg.get("hp", core_hp))
	if hp < core_hp:
		sfx.play("core", 0.0)
		shake = 0.25
		core_flash = 0.4
		_show_toast("중앙 피격! %d/%d" % [maxi(hp, 0), core_max])
	core_hp = hp
	core_max = int(msg.get("mx", core_max))
	score = int(msg.get("sc", score))
	kills = int(msg.get("k", kills))
	combo = int(msg.get("cb", combo))
	best_combo = maxi(best_combo, combo)
	_check_danger()
	var arr: PackedFloat32Array = msg.get("o", PackedFloat32Array())
	var seen := {}
	var i := 0
	while i + 8 < arr.size():
		var id := int(arr[i])
		seen[id] = true
		var o: Orb = mp_ghosts.get(id)
		var pos := Vector2(arr[i + 1], arr[i + 2])
		if o == null or not is_instance_valid(o):
			o = Orb.new()
			o.main = self
			o.ghost = true
			o.net_id = id
			o.setup(int(arr[i + 5]), arr[i + 4], 30.0)
			o.position = pos
			o.target = center()
			o.from_a = (pos - center()).angle()
			orbs.add_child(o)
			mp_ghosts[id] = o
		o.net_pos = pos
		o.hp = arr[i + 3]
		o.max_hp = arr[i + 4]
		o.shield = arr[i + 6]
		o.resist_e = int(arr[i + 7]) - 1
		var sl := roundi(arr[i + 8])
		o.sturdy = sl % 2 == 1
		o.late = LATE_IDS[sl / 2 - 1] if sl >= 2 and sl / 2 - 1 < LATE_IDS.size() else ""
		i += 9
	for id in mp_ghosts.keys():
		if not seen.has(id):
			var o: Orb = mp_ghosts[id]
			if is_instance_valid(o):
				if o.position.distance_to(center()) > 40.0:
					burst(o.position, o.death_color(), 10 if o.kind != Orb.Kind.BOSS else 40, 180.0)
					sfx.play("kill", 0.15)
				o.queue_free()
			mp_ghosts.erase(id)


## 내 오브젝트가 바뀌었으면 다른 기기로 보낸다.
func _mp_send_towers() -> void:
	var list: Array = []
	for t in _my_towers():
		list.append(t.mp_state())
	var sig := var_to_str(list)
	if sig == mp_tw_sig:
		return
	mp_tw_sig = sig
	mp.send({"t": "tw", "list": list})


func _mp_recv_towers(owner: int, list: Variant) -> void:
	if not list is Array or owner == mp.my_id:
		return
	var keep := {}
	for d in list:
		if not d is Dictionary:
			continue
		var nid := int(d.get("nid", 0))
		if nid / 100000 != owner:
			continue  # 남의 번호로 보낸 것
		keep[nid] = true
		var t: Tower = null
		for x in towers.get_children():
			if x.net_id == nid:
				t = x
				break
		if t == null:
			t = Tower.new()
			t.main = self
			t.owner_id = owner
			t.net_id = nid
			t.mp_apply(d)
			if t.order.is_empty():
				t.free()
				continue
			towers.add_child(t)
			t.place_pop = 1.0
		else:
			t.mp_apply(d)
	for x in towers.get_children():
		if x.owner_id == owner and not keep.has(x.net_id):
			if x in selected:
				selected.erase(x)
			x.queue_free()


# ---------- 별 상한·특성 ----------

## 별이 든 오브젝트(별·행성 합쳐)가 star_max개라 별을 새로 놓을 수 없다.
func star_full() -> bool:
	return Tower.star_count(self) >= int(Rules.t("star_max"))


## 이 카드가 별 카드인데 새로 놓을 수도, 넣을(레벨업할) 오브젝트도 없다.
func _star_blocked(card: Dictionary) -> bool:
	return card.get("type") == "elem" and card.get("e") == Elem.STAR and star_full() and not _my_towers().any(func(t): return t.can_take(card))


## 특성 하나를 얻는다.
func _grant_perk(id: String) -> void:
	perks[id] = perks.get(id, 0) + 1
	_apply_perk(id)


## 쉬는 시간 [시작] 버튼 자리 (일반 판 도크가 옮겨 두면 원래 자리로).
func _start_btn_layout() -> void:
	if start_btn.anchor_top != 1.0:
		start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		start_btn.position = Vector2(-110, -100)
		start_btn.size = Vector2(220, 44)
