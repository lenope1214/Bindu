class_name BinduSession
extends Node2D
## Shared scene/run contract. Feature-private state lives in its owner controller.

enum Phase { CHOOSE, PLACE, AIM, WAVE, GAMEOVER, MOVE, READY }

var abilities_system: BinduAbilities
var cards_system: BinduCards
var hud_system: BinduHud
var interaction_system: BinduInteraction
var leaderboard_system: BinduLeaderboard
var menu_system: BinduMenu
var onboarding_system: BinduOnboarding
var online_system: BinduOnline
var patchlog_system: BinduPatchlog
var perks_system: BinduPerks
var persistence_system: BinduPersistence
var progression_system: BinduProgression
var run_flow_system: BinduRunFlow
var ui_layout_system: BinduUiLayout
var waves_system: BinduWaves

func _init() -> void:
	abilities_system = BinduAbilities.new(self)
	cards_system = BinduCards.new(self)
	hud_system = BinduHud.new(self)
	interaction_system = BinduInteraction.new(self)
	leaderboard_system = BinduLeaderboard.new(self)
	menu_system = BinduMenu.new(self)
	onboarding_system = BinduOnboarding.new(self)
	online_system = BinduOnline.new(self)
	patchlog_system = BinduPatchlog.new(self)
	perks_system = BinduPerks.new(self)
	persistence_system = BinduPersistence.new(self)
	progression_system = BinduProgression.new(self)
	run_flow_system = BinduRunFlow.new(self)
	ui_layout_system = BinduUiLayout.new(self)
	waves_system = BinduWaves.new(self)


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
var cards_hidden := false  # 선택지를 내려 필드를 보는 중
var hide_btn: Button
var card_detail_btn: Button  # 선택지 카드 [자세히] 켜기·끄기 (Meta.card_detail)
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
var zoom_btn: Button
var shake := 0.0
var core_flash := 0.0
var danger_lv := 0  # 중앙 위험 단계: 0 보통, 1 체력 50% 이하, 2 25% 이하
var wave_dmg := 0  # 이번 웨이브에 중앙이 잃은 체력
var eclipse_flash := 0.0  # 일식 순간 화면 어둡게
var side_big_t := 0.0  # 큰 보조 공격이 화면을 차지하는 남은 시간 (Side.BIG_LOCK, 하나씩만)
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
var info_rects: Array = []  # 이번 프레임 info에 그린 배지 [이름, Rect2(UI 좌표)] (화면 배치 점검 tools/ui_check.gd)
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
var legend_hidden := OS.has_feature("mobile")  # 폰·태블릿은 필드가 좁아 접어 두고 시작 (버튼으로 열면 저장)
var bar_open := false  # 오른쪽 아래 설정 버튼(소리·자동 시작·일시정지·배속)을 펼쳤는지. 접으면 펼치기 버튼만 남는다
var bar_btn: Button
var tutor := false  # 이번 판이 첫 판 안내 판인지: 카드 종류를 웨이브마다 하나씩 연다 (TUTOR_OPEN)
var tutor_given := {}  # 첫 판에 새로 연 카드 종류를 선택지에 한 번 넣었는지 (종류 -> true)
var guide_label: Label  # 처음 생기는 일 한 줄 안내 (위쪽 가운데)
const RX_CARD := preload("res://scripts/rx_card.gd")
var rx_card: RxCard  # RxCard: 속성을 합쳐 새 조합이 생기면 오브젝트 옆에 뜨는 그림 카드
var guide_lines: Array[String] = []
var guide_more: Button
var guide_t := 0.0  # 남은 시간. 음수면 웨이브가 시작될 때까지
var wave_resist := -1  # 다음 웨이브 저항 속성 (-1: 없음)
const AIM_TOUCH_MIN := 30.0  # 터치 조준: 오브젝트에서 이만큼 떨어진 손가락만 방향으로 친다 (손가락이 오브젝트를 가려도 바깥으로 끌면 된다)
const AIM_TOUCH_HINT := "쏠 쪽으로 누른 채 끌어 범위 보기, 떼면 그 방향 유지\n[확정] 또는 오브젝트 다시 누르기: 방향 확정"
# 터치 조준: 누른 채 끌면 손가락을 따라 범위가 보이고, 떼면 그 방향을 붙잡아 둔 채 [확정]을 기다린다
# (예전엔 누르는 순간 확정돼 어느 쪽으로 정해질지 미리 볼 수 없었다)
var aim_d := Vector2.ZERO  # 붙잡아 둔 방향 (터치)
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
var coin_stage := 0
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
var hud_cool := 0.0  # 점수 줄을 다시 쓰기까지 남은 시간 (점수·남은 구체만 바뀔 때)
var title_label: Control  # 메인 메뉴
var title_box: VBoxContainer
var continue_btn: Button  # 저장된 판이 있을 때만 보임
var continue_info: Label  # 이어하기 카드의 설명 줄 (웨이브·맵·규칙)
const CONT_COL := Color(1.0, 0.78, 0.38)  # 이어하기 카드 색 (호박)
var remote_btn: Button  # 같은 계정의 다른 기기에서 하던 판이 있고, 이 기기에 하던 판이 없을 때만
var moved_run := ""  # 다른 기기가 가져간 판: 이 기기에서 계속 해도 서버에는 더 올리지 않는다
var new_btn: Button
var new_armed := 0.0  # 저장된 판이 있을 때 새로 시작은 두 번 눌러야 (실수로 지우지 않게)
var flip_label: Label  # 회랑 맵: 구체가 오는 쪽 (회랑일 때만 보임)
var records_panel: Label
var notes_panel: PanelContainer  # 패치노트 (시작 화면·설정)
var notes_btn: Button
var settings_panel: PanelContainer
var modes_panel: PanelContainer  # 모드 고르기 (시작 화면, 첫 판 뒤)
var codex_panel: Codex  # 도감·선호 표시 (시작 화면, K)
var vote_panel: Vote  # 다음 패치 투표 (시작 화면 V, 판 끝난 화면 버튼)
var vote_btn: Button  # 시작 화면 [투표]: 투표 API가 있는 서버일 때만
var vote_over_btn: Button  # 판 끝난 화면 [다음 패치 투표]
var tut: Tutorial  # 튜토리얼 카드·다시 보기 목록 (시작 화면 [튜토리얼]·일시정지)
var tplay: TutPlay = null  # 플레이 튜토리얼 연습 판의 안내 칸 (TutPlay.on일 때만)
var tut_paused := false  # 튜토리얼을 띄우느라 판을 멈췄다 (닫으면 다시 진행)
var modes_btn: Button
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
var dps_focus: Tower = null  # 표에서 마우스를 올린 오브젝트
var dps_hidden := OS.has_feature("mobile")  # D: 표 접기 (Meta.dps_fold로 저장)
const DPS_STEP := 0.5
const DPS_WIN := 5.0
var dps_hist := {}  # 오브젝트 instance id → 최근 dealt 표본들 (오래된 것부터)
var dps_t := 0.0  # 다음 표본까지 남은 게임 시간
var dps_n := 0  # 이번 웨이브에 적은 표본 수 (표를 1초마다 고치는 데 씀)
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
var notice_label: Label  # 시작 화면: 패치 공지
var board_box: VBoxContainer  # 리더보드 창 (records_panel 안): 왼쪽 필터 칩·오른쪽 순위 표
var legacy_grow := false  # 정원(씨앗 나무)이 있던 버전에서 씨앗 나무를 켜고 시작해 이어 하는 판: 예전처럼 'grow'를 붙여 일반 리더보드에 섞이지 않게
var board_ugc_panel: PanelContainer  # 리더보드 위에 뜨는 신고·차단 목록
static var title_seen := false  # 다시 시작하면 타이틀은 건너뛴다
## 멀티 판이 끝나도 방은 남는다: 판 끝 화면을 지나 다시 불러올 때 Mp 노드를 루트에 잠시 옮겨 두고(연결 유지)
## 새 화면이 받아 대기방(멀티플레이 창)을 연다. 방이 없어졌으면 그 까닭을 창에 보여 준다.
static var mp_keep: Mp = null
static var mp_back := false
static var mp_back_msg := ""
var prep_back: Button  # 준비 화면 왼쪽 위 [뒤로]
var prep := false


var service_signals := BinduSignalScope.new()

func _exit_tree() -> void:
	service_signals.close()

func boot() -> void:
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
	progression_system._load_best()
	Tutorial.load_file()
	onboarding_system.tut_first = Tutorial.need_first() and DisplayServer.get_name() != "headless"
	if Meta.device_id == "":
		Meta.device_id = Crypto.new().generate_random_bytes(16).hex_encode()
		progression_system._save_best()
	Patch.load_cache()
	if Meta.games == 0:
		Meta.rules = 1  # 첫 판은 기본 규칙 (규칙 고르기는 첫 판 뒤에 보인다)
	Modes.set_on(Meta.modes if Meta.games > 0 else [])  # 모드도 첫 판 뒤에 열린다
	if TutPlay.pending >= 0:
		TutPlay.enter_meta()  # 플레이 튜토리얼: 평원·랭크·모드 없음 (저장할 때는 원래 값으로)
	run_flow_system._apply_rules()
	zones = _layer("Zones")
	towers = _layer("Towers")
	orbs = _layer("Orbs")
	projectiles = _layer("Projectiles")
	# 이 셋은 main이 _sim_step에서 직접 움직인다(배속 계산용)
	for l in [zones, orbs, projectiles]:
		l.process_mode = Node.PROCESS_MODE_DISABLED
	fx_layer = _layer("Fx")
	fx_layer.z_index = 5
	service_signals.connect_to(fx_layer.draw, _draw_fx)
	mp_cur_layer = _layer("Cursors")
	mp_cur_layer.z_index = 6
	service_signals.connect_to(mp_cur_layer.draw, _draw_mp_cursors)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)  # 가로 고정 (예전 빌드는 자유 회전으로 설정돼 있었다)
	camera = Camera2D.new()
	camera.position = center()
	add_child(camera)
	for i in 140:
		stars.append(Vector3(randf() * Meta.FIELD.x, randf() * Meta.FIELD.y, randf_range(0.03, 0.12)))
	_build_ui()
	hud_system._apply_ui_scale()
	progression_system._ach_catch_up()
	menu_system._apply_volume()
	run_flow_system._update_speed_btn()
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
	service_signals.connect_to(mp.room_ready, _mp_refresh_lobby)
	service_signals.connect_to(mp.peers_changed, _mp_refresh_lobby)
	service_signals.connect_to(mp.failed, _mp_failed)
	service_signals.connect_to(mp.packet, _mp_packet)
	service_signals.connect_to(mp.status_changed, _mp_apply_switch)
	service_signals.connect_to(mp.ping_changed, _mp_refresh_pings)
	service_signals.connect_to(mp.peer_up, _mp_peer_up)
	mp.check_status()
	_mp_refresh_lobby(false)
	service_signals.connect_to(net.booted, online_system._on_booted)
	service_signals.connect_to(net.run_sent, online_system._on_run_sent)
	service_signals.connect_to(net.board_loaded, leaderboard_system._on_board_loaded)
	service_signals.connect_to(net.seasons_loaded, leaderboard_system._on_seasons_loaded)
	service_signals.connect_to(net.progress_synced, online_system._on_progress_synced)
	service_signals.connect_to(net.device_changed, progression_system._save_best)
	service_signals.connect_to(net.runs_listed, online_system._on_runs_listed)
	service_signals.connect_to(net.run_claimed, online_system._on_run_claimed)
	service_signals.connect_to(net.run_moved, online_system._on_run_moved)
	service_signals.connect_to(net.rates_loaded, func(): if codex_panel.visible: codex_panel._draw_list())
	online_system.updater = Updater.new()
	add_child(online_system.updater)
	online_system.updater.cleanup()
	service_signals.connect_to(online_system.updater.progress, online_system._on_update_progress)
	service_signals.connect_to(online_system.updater.failed, online_system._on_update_failed)
	patchlog_system.notes = PatchNotes.new()
	add_child(patchlog_system.notes)
	service_signals.connect_to(patchlog_system.notes.loaded, patchlog_system._draw_notes)
	if Meta.notes_seen == "" and Meta.games == 0:
		Meta.notes_seen = Net.game_version()  # 처음 하는 사람에게는 '새 소식' 표시를 하지 않는다
	patchlog_system._refresh_notes_btn()
	online_system._on_booted(Net.info)  # 다시 시작했을 때: 이미 받아 둔 새 버전·공지
	# 창 제목에도 한글 이름과 버전 (작업 표시줄에서 어떤 빌드인지 보이게)
	get_window().title = "빈두 v%s" % ProjectSettings.get_setting("application/config/version", "?")
	if TutPlay.on and TutPlay.pending >= 0:
		onboarding_system._start_tut_play(TutPlay.pending)
	elif mp_back:
		_mp_back_lobby()
	elif title_seen or DisplayServer.get_name() == "headless":
		run_flow_system._start_choose()
	elif persistence_system._old_run_version() != "":
		persistence_system._end_old_run(persistence_system._old_run_version())
	else:
		title_label.visible = true
		persistence_system._refresh_continue()
		hint.text = ""
		net.check()  # 시작 화면이 뜰 때마다 새 버전 확인 (처음 켤 때는 Net이 이미 묻는 중)
		if TutPlay.then_play:
			TutPlay.then_play = false
			menu_system._set_prep(true)  # 튜토리얼 끝 [첫 판 시작]: 일반 판 준비 화면


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
		interaction_system.touches.clear()
		interaction_system.pinch_lock = false
		interaction_system.mid_drag = false
		interaction_system.info_mouse_capture = false
		interaction_system.info_touch_capture = -1
	# 창을 닫거나 (모바일) 앱이 뒤로 가면 지금 쉬는 시간 상태를 한 번 더 저장 (옮긴 위치까지)
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED) and towers and title_label:
		persistence_system._save_run()


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
	get_viewport().size_changed.connect(hud_system._apply_ui_scale)

	hud = Control.new()
	hud.position = Vector2(10, 6)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 칩 말풍선은 _draw_info가 마우스 자리로 띄운다 (필드 누르기를 막지 않게)
	hud.draw.connect(hud_system._draw_hud)
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
	ver_label.text = run_flow_system._ver_text()
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
	guide_more.pressed.connect(onboarding_system._open_guide_details)
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
	legend.draw.connect(menu_system._draw_legend_icons)
	menu_system._refresh_legend()
	root.add_child(legend)

	reroll_btn = Button.new()
	reroll_btn.text = "1"
	cards_system._icon_btn(reroll_btn, func(): return ["reroll", Color(0.6, 0.85, 1.0)])
	cards_system._keycap(reroll_btn, "Q")
	reroll_btn.set_anchors_preset(Control.PRESET_CENTER)
	reroll_btn.position = Vector2(-170, 105)
	reroll_btn.size = Vector2(340, 36)
	reroll_btn.pressed.connect(cards_system._on_reroll)
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
			cards_system._on_pick(offer[tap_sel]))
	apply_btn.visible = false
	apply_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(apply_btn)

	skip_btn = Button.new()
	skip_btn.set_anchors_preset(Control.PRESET_CENTER)
	skip_btn.tooltip_text = "카드 선택을 미루고 웨이브를 연달아 진행합니다. 미룬 카드·새로고침·특성은 멈춘 뒤 한꺼번에 고릅니다\n중앙이 위험해지면(설정) 그 웨이브가 끝나고 멈춥니다"
	skip_btn.pressed.connect(run_flow_system._on_skip)
	cards_system._icon_btn(skip_btn, func(): return ["skip", Color(0.75, 0.9, 1.0)])
	cards_system._keycap(skip_btn, "S")
	skip_btn.visible = false
	skip_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(skip_btn)
	skip_n_btn = Button.new()
	skip_n_btn.set_anchors_preset(Control.PRESET_CENTER)
	skip_n_btn.tooltip_text = "넘길 웨이브 수 바꾸기 (1·3·5·10)"
	skip_n_btn.pressed.connect(run_flow_system._cycle_skip_n)
	skip_n_btn.visible = false
	skip_n_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(skip_n_btn)
	skip_badge = Button.new()
	skip_badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip_badge.position = Vector2(-210, -146)  # 웨이브 시작 버튼 위
	skip_badge.size = Vector2(420, 36)
	skip_badge.add_theme_color_override("font_color", Color(0.75, 0.9, 1))
	skip_badge.pressed.connect(run_flow_system._toggle_skip_stop)
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
	card_detail_btn.toggled.connect(cards_system._set_card_detail)
	cards_system._icon_btn(card_detail_btn, func(): return ["help", Color(1, 0.88, 0.5) if Meta.card_detail else Color(1, 1, 1, 0.7)])
	cards_system._keycap(card_detail_btn, "Z")
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
		progression_system._save_best())
	bar.add_child(fx_pick)
	mute_btn = Button.new()
	mute_btn.custom_minimum_size = Vector2(44, 36)
	mute_btn.pressed.connect(cards_system._toggle_mute)
	mute_btn.pressed.connect(cards_system._icon_toast.bind(mute_btn))
	cards_system._icon_btn(mute_btn, func(): return ["mute" if sfx.muted else "sound", Color(1, 1, 1, 0.9)])
	bar.add_child(mute_btn)
	auto_btn = Button.new()
	auto_btn.custom_minimum_size = Vector2(44, 36)
	auto_btn.pressed.connect(cards_system._toggle_auto)
	auto_btn.pressed.connect(cards_system._icon_toast.bind(auto_btn))
	cards_system._icon_btn(auto_btn, func(): return ["auto", Color(0.5, 0.9, 0.6) if auto_start else Color(1, 1, 1, 0.35)])
	bar.add_child(auto_btn)
	pause_btn = Button.new()
	pause_btn.tooltip_text = "일시정지 (P)"
	pause_btn.custom_minimum_size = Vector2(44, 36)
	pause_btn.pressed.connect(run_flow_system._toggle_pause)
	cards_system._icon_btn(pause_btn, func(): return ["pause", Color(1, 1, 1, 0.9)])
	bar.add_child(pause_btn)
	speed_group = HBoxContainer.new()
	speed_group.name = "SpeedControls"
	speed_group.add_theme_constant_override("separation", 0)
	bar.add_child(speed_group)
	speed_btn = Button.new()
	speed_btn.custom_minimum_size = Vector2(72, 36)
	speed_btn.pressed.connect(run_flow_system._toggle_speed)
	cards_system._icon_btn(speed_btn, func(): return ["speed", Color(1, 0.85, 0.45) if game_speed > 1.0 else Color(1, 1, 1, 0.9)])
	speed_group.add_child(speed_btn)
	speed_pick = OptionButton.new()
	for sp in SPEEDS:
		speed_pick.add_item("x%d" % roundi(sp))
	speed_pick.custom_minimum_size = Vector2(64, 36)
	speed_pick.focus_mode = Control.FOCUS_NONE
	speed_pick.tooltip_text = "빠르게 할 때 배속 (Space로 1배속과 오감)"
	speed_pick.item_selected.connect(run_flow_system._on_speed_pick)
	speed_group.add_child(speed_pick)
	# 맨 오른쪽: 접으면 이것만 남고, 펼치면 왼쪽으로 버튼이 늘어선다
	bar_btn = Button.new()
	bar_btn.custom_minimum_size = Vector2(96, 36)
	bar_btn.pressed.connect(cards_system._toggle_bar)
	bar.add_child(bar_btn)
	start_btn = Button.new()
	start_btn.text = "웨이브 시작 (Space)"
	start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	start_btn.position = Vector2(-110, -100)
	start_btn.size = Vector2(220, 44)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(cards_system._start_wave_from_ready)
	start_btn.visible = false
	root.add_child(start_btn)
	abilities_system._make_skill_btns(root)
	cancel_btn = Button.new()
	cancel_btn.text = "취소 (Esc)" if OS.has_feature("pc") else "취소"
	cancel_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cancel_btn.position = Vector2(-70, -100)  # 웨이브 시작 버튼 자리 (옮기기·설치 중엔 비어 있다)
	cancel_btn.size = Vector2(140, 40)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(interaction_system._cancel_step)
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
			interaction_system._confirm_aim())
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
	cards_system._update_auto_btn()
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
	paused_label.text = run_flow_system._pause_text()
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
	var pspecs := [["계속", run_flow_system._toggle_pause, "play", "P"], ["튜토리얼", onboarding_system._open_tut_list, "help", ""], ["처음부터", run_flow_system._pause_restart, "restart", "R"], ["판 끝내기", run_flow_system._end_run, "flag", "E"], ["시작 화면", run_flow_system._leave.bind(false), "home", "T"]]
	if OS.has_feature("pc"):
		pspecs.append(["끄기", run_flow_system._leave.bind(true), "power", "X"])  # 모바일은 운영체제가 앱을 닫는다
	pspecs += [["소리 (M)", cards_system._toggle_mute, "sound", "M", true], ["설정 (O)", menu_system._toggle_settings, "gear", "O", true]]
	if OS.has_feature("pc"):
		pspecs.append(["전체 화면 (F11)", menu_system._toggle_fullscreen, "full", "F11", true])
	for spec in pspecs:
		var b := Button.new()
		var small: bool = spec.size() > 4
		b.custom_minimum_size = Vector2(56 if small else 92, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		if small:
			b.tooltip_text = spec[0]
			cards_system._icon_btn(b, func(): return [("mute" if sfx.muted else "sound") if spec[2] == "sound" else spec[2], Color(1, 1, 1, 0.85)])
			b.pressed.connect(cards_system._icon_toast.bind(b))
		else:
			cards_system._menu_glyph(b, spec[2], spec[0])
		cards_system._keycap(b, spec[3])
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
	coin_fx.draw.connect(perks_system._draw_coin)
	coin_fx.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed:
			perks_system._coin_tap()
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
	vote_over_btn.pressed.connect(func(): menu_system._toggle_vote(true))
	vote_over_btn.visible = false
	cards_system._icon_btn(vote_over_btn, func(): return ["vote", Color(1, 0.86, 0.35)])
	root.add_child(vote_over_btn)
	# 게임 오버 그림 카드: 웨이브·점수 큰 칩, 처치·콤보·오브젝트 작은 칩, 새 업적 배지 (나머지 글은 아래 over_label)
	over_card = Control.new()
	over_card.set_anchors_preset(Control.PRESET_CENTER)
	over_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_card.draw.connect(run_flow_system._draw_over_card)
	over_card.add_to_group("keycap")  # 터치·마우스가 바뀌면 나가는 법 줄을 다시
	over_card.visible = false
	root.add_child(over_card)
	root.move_child(over_card, over_label.get_index())  # 바탕이 남은 글(over_label)을 덮지 않게 글 밑에

	dps_hidden = Meta.dps_fold
	hud_system._build_dps(root)
	menu_system._build_menu(root)

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
	help_label.text = patchlog_system._kr_keep(run_flow_system._help_text())
	help_label.visible = false
	help_scroll.add_child(help_label)
	root.add_child(help_scroll)


## 쉬는 시간 왼쪽 위: 지난 웨이브 오브젝트별 DPS 표 (줄은 _refresh_dps가 채운다). 틀은 공용 FloatPanel.
const RANK_STEP := 1.0
const RANK_HOLD := 3.0
const BUILD_COLOR := Color(0.55, 0.95, 0.95)
const BUILD_MIN := 0.08  # 이 몫 아래면 주력으로 치지 않음
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
				return "보조 공격"
			if p[1] == "side_big":
				return "큰 보조 공격"
			var j := Patch.ELEM_KEYS.find(p[1])
			return ("특징 " + Elem.trait_name(Elem.ALL[j])) if j >= 0 else p[1]
		"etc":
			return {"crowd": "무리(오브젝트 수)", "perk": "특성", "ley": "기맥"}.get(p[1], p[1])
	return p[1]


## 화면 가운데 크게 잠깐 뜨는 글자. 앞 글자가 아직 또렷하면 뒤에 세워 차례로 보여 준다
## (업적 직후 "웨이브 10"이 바로 덮어써 업적을 못 보던 것).
## 글자·버튼 크기: UI를 s배로 그리고, 배치는 화면을 s로 나눈 크기 안에서 한다 (앵커가 그대로 맞는다).
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


const PERK_VALS := {"power": 0.15, "haste": 0.12, "reach": 0.12, "core": 3, "reroll": 1, "luck": 0.2, "regen": 1, "regen_more": 0.5, "slow": 0.08, "harmony": 0.5, "harmony_cap": 0.2, "coin": 2,
	"shield": 1, "shield_max": 3, "shield_all": 4, "rampart": 1, "rampart_max": 4, "rampart_push": 140, "riposte": 0.6, "riposte_more": 0.5, "riposte_r": 160, "overflow": 2}
static var RAMPART_R := 56.0  # 성벽이 서는 중앙에서의 거리
const FX_RIPOSTE := 0.35


## 실드 특성이 웨이브 시작마다 채우는 실드.
const PERK_GLYPH := {"power": "dmg", "haste": "rate", "reach": "range", "slow": "fast", "regen": "core", "reroll": "reroll"}


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
		var counts := waves_system.lane_counts(nw)
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
		var blockers := ui_layout_system._info_blockers()
		# 오브젝트도 되도록 가리지 않는다 (배지를 비킬 때 오브젝트 위에 얹히던 것)
		for t in towers.get_children():
			blockers.append(Rect2(xf * t.position - Vector2(22, 26), Vector2(44, 48)))
		# 보스 길 안내(고리·"보스 · 웨이브 N" 글자·들어오는 길)도 가리지 않는다
		for br in _boss_mark_rects():
			blockers.append(xf * br)
		for arr in ui_layout_system._lane_arrows():
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
			r = ui_layout_system._free_badge(r.grow_side(SIDE_TOP, nh), inward, avoid, Rect2(8.0, 8.0, gx - 16.0, size.y - 16.0)).grow_side(SIDE_TOP, -nh)
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
			var ep: Vector2 = ui_layout_system._lane_arrows()[0][0] if Meta.map_id == "line" else _entry_point(lm[0])
			var p: Vector2 = xf * (ep - (Vector2(-1.0 if not Meta.line_flip else 1.0, 0) if Meta.map_id == "line" else d) * 120.0)
			var txt := "-%d" % lm[1]
			var w := Icons.chip_w(ui_font, txt, 16)
			var r := Rect2(p - Vector2(w, 26.0) / 2.0, Vector2(w, 26.0))
			r.position = r.position.clamp(Vector2(8.0, top), Vector2(size.x - w - 8.0, lo - 26.0))
			var avoid: Array[Rect2] = blockers.duplicate()
			for br in badges:
				avoid.append(br.grow(4.0))
			var inward: Vector2 = Vector2(1.0 if not Meta.line_flip else -1.0, 0) * -1.0 if Meta.map_id == "line" else (xf.basis_xform(-d)).normalized()
			r = ui_layout_system._free_badge(r, inward, avoid, Rect2(8.0, 8.0, size.x - 16.0, size.y - 16.0))
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
			var sr := cards_system._draw_seal_chip(info, r.get_center().x, r.position.y - 6.0)
			tip_rects.append([sr, [["봉인 모드: 이번 판 선택지에 안 나오는 카드", Color(0.8, 0.8, 1.0)], [Vary.sealed_text(), Color(1, 1, 1, 0.9)], ["25·50웨이브에 하나씩 풀려요", Color(1, 1, 1, 0.6)]]])
	cards_system._draw_card_full()
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
		for row in onboarding_system._wrap_words(l[0], 520.0, tfs).split("\n"):
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
	elif interaction_system.moving != null or interaction_system.dragging or phase in [Phase.PLACE, Phase.MOVE]:
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
	return phase == Phase.PLACE and interaction_system.moving == null and not interaction_system.dragging and (picked.get("type", "") != "elem" or interaction_system._tower_at(interaction_system._pointer_world()) != null)


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
	elif interaction_system.moving != null or interaction_system.dragging or phase in [Phase.PLACE, Phase.MOVE, Phase.AIM]:
		show = stars.filter(func(s): return s != interaction_system.moving)
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
const PREP_W := 640.0


## 준비 화면 칸: 화면 폭이 맵 카드 + 오른쪽 묶음(520)을 나란히 둘 만큼이면 두 칸
const LEGEND_ICONS := ["pat", "elem", "mod", "link", "trig", "tower", "rx"]
static func _new_run_id() -> String:
	return "%d-%06d" % [Time.get_unix_time_from_system(), randi() % 1000000]


## 판 기록(점수·특성·선택지·지금 구성)을 서버로. 설정에서 끄면 보내지 않는다.
## done=false: 5웨이브마다 보내는 진행 중 기록. 서버는 같은 판 번호(run)면 한 줄을 고친다.
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


static func _bb(t: String) -> String:
	return t.replace("[", "[lb]")


## 시작 화면 [패치노트] 버튼: 이 버전 노트를 아직 안 봤으면 강조.
const EASY_NOTICE_KEY := "easy_board"  # user://device.cfg [notice]: 다시 보지 않기 (기기마다)


## 쉽게 모드 안내 상자: 모드 창 맨 위에 뜬다 (판 시작은 막지 않음).
var ley: Array = []  # 기맥 자리 (전장 좌표)


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
		hud_system._rank_update()
	key_t -= delta
	_mp_lobby_tick()
	_mp_tick(delta)
	if coin_stage > 0 and not get_tree().paused:
		perks_system._coin_step(delta)
	touch_tip_t -= delta
	# 터치 자세히는 유지 중인 인스펙터를 기준으로 표시한다.
	var tip_on := touch_ui and not title_label.visible and (is_instance_valid(card_dock.inspected_tower) if card_dock.active() else Engine.get_process_frames() - tip_frame <= 2)
	if touch_ui or phase == Phase.PLACE:
		fx_layer.queue_redraw()  # PLACE: 올린 오브젝트 설명(place_note)이 마우스를 따라가게. 정보창이 떠 있는지(tip_frame)를 매 프레임 알도록 (쉬는 시간엔 다시 그리지 않는 프레임이 있다)
	if not tip_on:
		tip_detail = false
	detail_btn.visible = tip_on
	aim_ok_btn.visible = interaction_system._ok_btn_on() and not get_tree().paused
	detail_btn.text = "간단히" if tip_detail else "자세히"
	_place_apply_btn()
	for c in [hint, skip_badge, hide_btn]:
		c.self_modulate.a = 0.12 if Engine.get_process_frames() - tip_fade.get(c, -10) <= 2 else 1.0
	if touch_ui and key_t <= 0.0:
		key_t = 0.2
		ui_layout_system._strip_key_hints()
	var us := Time.get_ticks_usec() if prof_on else 0
	if new_armed > 0.0:
		new_armed -= delta
		if new_armed <= 0.0:
			new_btn.text = "새로 시작"
	toast_timer -= delta
	toast.visible = toast_timer > 0.0
	onboarding_system._tut_tick()
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
		hint.text = patchlog_system._kr_keep(hint.text)  # 줄이 접힐 때 한글 낱말 중간("방향 바/꾸기")에서 끊기지 않게
		_hint_kept = hint.text
	toast.position.y = maxf(100.0, hud.position.y + hud.size.y + 36.0)  # 점수 줄이 길어져도 보스 체력 막대 아래
	if tplay != null:
		toast.position.y = maxf(toast.position.y, tplay.panel_bottom() + 8.0)  # 연습 판 안내 칸 아래
	# 안내·큰 글자도 점수 줄이 길어지거나 글자를 키우면(설정) 그 아래로 밀어 겹치지 않게
	guide_label.position.y = maxf(140.0, toast.position.y + 40.0)
	ui_layout_system._beside_legend(guide_label, 0.0)
	onboarding_system._update_action_guide()
	# 왼쪽 위 DPS 표를 펼쳐 두면 알림이 표 위에 겹치던 것 (글자 115% 이상·표가 길 때): 표와 오른쪽 설명 사이에 두고,
	# 글이 그 폭보다 길면 두 줄로 접는다 (예전엔 표 아래로 내려 카드 줄 밑에 깔렸다: 봉인·이벤트 알림)
	if toast.visible:
		var left := 8.0
		var right := ui_layout_system._right_panel_x() - 8.0
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
	if ban_w / 2.0 + minf(ban_full, 800.0) / 2.0 > ui_layout_system._right_panel_x() - 8.0:
		ban_w = minf(ban_w, ui_layout_system._right_panel_x() - 8.0)  # 긴 큰 글이 오른쪽 설명 위로 넘치던 것 (폰 "웨이브 3개 넘기기")
	banner.size.x = minf(800.0, ban_w - 16.0)
	banner.position.x = (ban_w - banner.size.x) / 2.0
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if ui_font.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x > banner.size.x else TextServer.AUTOWRAP_OFF
	if choice_box.visible and not cards_hidden and choice_box.get_child_count() > 0:
		# 카드가 떠 있으면 "웨이브 N" 큰 글이 카드 윗변에 걸치지 않게 그 위로
		banner.position.y = maxf(minf(banner.position.y, choice_box.get_rect().position.y - banner.size.y - 4.0), hud.position.y + hud.size.y + 12.0)
	banner_t -= delta
	if banner_t <= 0.0 and not banner_queue.is_empty():
		var nb: Array = banner_queue.pop_front()
		hud_system.big_banner(nb[0], nb[1])
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
			menu_system._refresh_legend()
	# 시작 화면 위에 설정·기록·도움말·패치노트 창을 열면 뒤 메뉴는 숨긴다 (흐리게만 하면 창 아래로 삐져나온 버튼 줄이 겹쳐 보이고 눌리던 것)
	if help_label.visible and not help_scroll.visible:
		help_scroll.scroll_vertical = 0  # 열 때마다 맨 위부터
		if help_touch != touch_ui:  # 터치면 조작 안내를 버튼·누르기로
			help_touch = touch_ui
			help_label.text = patchlog_system._kr_keep(run_flow_system._help_text())
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
	hud_system._update_hud()
	# 일시정지 위에 설정·도움말 등을 열면 일시정지 글·버튼은 잠깐 숨기고, 어둠은 남겨 창이 그 위에 뜬다 (창 z 22 > 어둠 20)
	var over := settings_panel.visible or help_label.visible or records_panel.visible or notes_panel.visible or codex_panel.visible or vote_panel.visible
	var dim := get_tree().paused and not title_label.visible and phase != Phase.GAMEOVER
	var show_pause := dim and not over and not tut_paused  # 튜토리얼이 멈춘 것은 일시정지 창 없이
	paused_label.visible = show_pause
	pause_box.visible = show_pause
	pause_dim.visible = dim
	# 카드 선택 중: 카드 밖은 검은 막 (닫히면 곧바로 걷는다). 카드를 내리면(필드 보기) 막도 걷는다
	card_dim.visible = interaction_system._card_dim_on()
	interaction_system._update_place_dim()
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
	hud_system._fit_panels()
	hud_system._refresh_dps()
	_soften_fx()
	queue_redraw()
	info.queue_redraw()
	if phase == Phase.MOVE and interaction_system.moving and not get_tree().paused:
		interaction_system.moving.position = interaction_system._pointer_world().clamp(field_rect().position, field_rect().end)
	interaction_system._update_press()
	if interaction_system.boxing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		interaction_system._finish_box()  # 창 밖에서 손을 떼 놓기 이벤트를 못 받은 경우
	card_detail_btn.visible = phase == Phase.CHOOSE and not title_label.visible and coin_stage == 0 and not cards_hidden and not perk_mode
	run_flow_system._update_skip_ui()
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
	var lim := ui_layout_system._bottom_free() - 6.0
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
	cards_system._start_btn_layout()
	abilities_system._skill_ui()
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
		if interaction_system.press_t or interaction_system.boxing or reading:
			countdown = maxf(countdown, 1.0)
		else:
			countdown -= delta
		start_btn.text = ui_layout_system._kh("%.1f초 뒤 시작 (Space: 바로)" % maxf(countdown, 0.0))
		if countdown <= 0.0:
			run_flow_system._start_wave()
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
				hud_system.big_banner("보스 등장!", Color(1, 0.35, 0.4))
				sfx.play("boss", 0.0)

	wave_time += delta
	run_game += delta
	hud_system._dps_sample(delta)
	abilities_system._skill_tick(delta)
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
		run_flow_system._game_over()
	elif to_spawn == 0 and mp_extra_left == 0 and _alive_count(orbs) == 0:
		combo_hold = true  # 쉬는 시간·카드 고르기 동안 콤보가 끊기지 않게
		_log_wave()
		Vary.wave_done(wave, _my_towers())
		progression_system._achieve("first")
		Ach.on_wave_clear(wave, wave_dmg, core_hp, core_max)
		progression_system._ach_check()
		if wave >= 5 and mp_mode == "" and not TutPlay.on:
			Meta.map_best[Meta.run_key()] = [maxi(Meta.best_of(Meta.run_key())[0], wave), maxi(Meta.best_of(Meta.run_key())[1], score)]
			if Meta.MAP_IDS.all(func(id): return id in Meta.TRIAL_MAPS or Meta.best_of(Meta.key(id))[0] >= 5):
				progression_system._achieve("allmaps")
		var bonus := int(wave * 20 * Modes.mul())
		score += bonus
		hud_system._show_toast("웨이브 %d 클리어! +%d" % [wave, bonus])
		sfx.play("clear", 0.0)
		_show_mvp()
		if perks.has("regen"):
			perks_system._heal_core(perks_system._regen_take())
		if wave % 5 == 0:
			online_system._submit_run(false)  # 5웨이브마다 진행 중 기록 (중간에 꺼도 서버에 남게)
		_mp_wave_cleared()
		if skip_left > 1 and not skip_stop:
			skip_left -= 1
			run_flow_system._skip_rest()
		elif skip_left > 0:
			run_flow_system._end_skip(false)
		elif wave % 5 == 0:
			perks_system._start_perk()
		else:
			run_flow_system._start_choose()


## 중앙 체력 비율로 위험 단계를 정한다. 단계가 올라가는 순간에만 큰 글·경고음 (설정에 따라 1배속).
## 회복해서 단계가 내려가면 다시 떨어질 때 또 알린다.
func _danger_of(hp: int) -> int:
	if hp <= 0 or hp * 4 <= core_max:
		return 2
	return 1 if hp * 2 <= core_max else 0


func _check_danger() -> void:
	var lv := _danger_of(core_hp)
	if lv > danger_lv and core_hp > 0:
		hud_system.big_banner("중앙 위험! %d/%d" % [core_hp, core_max], Color(1, 0.3, 0.35) if lv == 2 else Color(1, 0.6, 0.3))
		sfx.play("danger", 0.0)
		if skip_left > 0 and not skip_stop and Meta.skip_danger:
			skip_stop = true
			hud_system._show_toast("중앙 위험: 이번 웨이브가 끝나면 넘기기를 멈춰요")
		if Meta.danger_slow and game_speed > 1.0:
			game_speed = 1.0
			run_flow_system._update_speed_btn()
			hud_system._show_toast("중앙 위험: 1배속으로 바꿨어요 (Space로 다시 빠르게)")
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
	onboarding_system._guide("leak", "구체가 중앙에 닿았어요. 붉게 번쩍인 가장자리 쪽 길목이 비어 있어요. 쉬는 시간에 그쪽으로 오브젝트를 옮기거나 새로 놓으세요")


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
	onboarding_system._wind_buffs()
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
				progression_system._achieve("combo30")
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
				perks_system._heal_core(2)
				bonus_rerolls += 1
				progression_system._achieve("boss")
				hud_system._show_toast("보스 처치! 중앙 체력 +2" + ("" if Modes.has("narrow") else ", 새로고침 +1"))
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
			o.position += (o.position - o.target).normalized() * perks_system._perk_val("rampart_push") * (0.5 if o.kind == Orb.Kind.BOSS else 1.0)
			burst(o.position, Color(0.75, 0.6, 0.45), 12, 160.0)
			sfx.play("hit", 0.0)
		if _reached_core(o):
			var hit_p: Vector2 = o.position if Meta.map_id == "line" else center()
			var dmg: int = o.core_dmg - perks_system._shield_absorb(o.core_dmg)
			if perks.has("riposte"):
				perks_system._riposte(hit_p)
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
			hud_system._show_toast("중앙 피격! %d/%d" % [maxi(core_hp, 0), core_max])
			wave_dmg += dmg
			Ach.on_core_hit(dmg)
			popup(hit_p + Vector2(0, -CORE_RADIUS - 24.0), dmg, Color(1, 0.3, 0.35), true, "-%d" % dmg, 1.2)
			_check_danger()
			_record_leak(o, dmg)
			o.queue_free()
			continue

	if ach_dirty:
		ach_dirty = false
		progression_system._ach_check()
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
	var touch_move := phase == Phase.MOVE and touch_ui and interaction_system.moving != null
	# 터치로 방향 바꾸기: 손가락은 쏠 쪽에 있으니 그 오브젝트 정보를 함께 보여 준다 ([자세히]로 수치까지)
	var touch_aim := phase == Phase.AIM and touch_ui and interaction_system.moving != null
	if (phase in [Phase.PLACE, Phase.GAMEOVER, Phase.MOVE, Phase.AIM] and not touch_move and not touch_aim) or title_label.visible or interaction_system.dragging or interaction_system.boxing:
		return
	# 터치는 손을 뗀 자리에 마우스가 남는다: 누르고 3초가 지나면 정보창을 닫는다
	if touch_ui and not touch_move and not touch_aim and touch_tip_t <= 0.0:
		return
	if dps_panel.visible and dps_panel.get_global_rect().has_point(interaction_system._pointer_screen()):
		return  # DPS 표 위: 표 뒤에 가린 오브젝트 정보창이 뜨지 않게
	var t := interaction_system.moving if touch_move or touch_aim else interaction_system._tower_at(interaction_system._pointer_world())
	# 터치로 [자세히]를 누르면 손가락이 버튼으로 가서 정보창이 사라졌다: 방금 보던 오브젝트를 이어서
	if t == null and touch_ui and is_instance_valid(tip_tower) and detail_btn.visible \
			and detail_btn.get_global_rect().has_point(interaction_system._pointer_screen()):
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
	tip = ui_layout_system._th(tip)
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
		for row in onboarding_system._wrap_parts(head, "·", maxw, fs).split("\n"):
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
			var nd: String = Share.site_desc(x[0], x[1])
			desc.append(["자리 %s%s" % [x[2], ": " + nd if nd != "" else ""], Color(0.75, 0.9, 1.0), "k:rx"])
		onboarding_system._wind_buffs()  # 쉬는 시간에 새로 놓은 오브젝트도 바로 보이게
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
		for row in onboarding_system._wrap_words(l[0], maxw, fs).split("\n"):
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
	if touch_aim and interaction_system._pointer_world().x > t.position.x:
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
	var h := interaction_system._tower_at(interaction_system._pointer_world())
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
	var ui_blocks := ui_layout_system._info_blockers()
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
		n += 1 if ui_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= maxw else onboarding_system._wrap_words(l[0], maxw, fs).count("\n") + 1
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
	var m := interaction_system._pointer_world()
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
	abilities_system._draw_skill_fx()
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

	menu_system._draw_map_rule(c, now)
	_draw_boss_path(now)
	_draw_wind_rings()
	_draw_star_rings()
	# 누수: 구체가 들어온 화면 가장자리가 붉게 번진다 (어느 길목이 뚫렸는지)
	for lf in leak_flash:
		var f: float = lf[1] / 1.2
		for k in 4:
			draw_circle(lf[0], 40.0 + k * 34.0, Color(1, 0.15, 0.2, 0.16 * f * (1.0 - k * 0.22)))

	var mpos := interaction_system._pointer_world()
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
		var col := cards_system._card_color(picked)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		var is_elem: bool = picked["type"] == "elem"
		# 넣을 수 있는 오브젝트: 숨 쉬는 빛 + 고리 + 도는 점선 고리 (속성 카드는 새 반응이 생기면 그 반응 색).
		# 넣을 수 없는 오브젝트는 _update_place_dim이 흐리게 하고 누를 수 없다 (작은 ✕)
		var spin := Time.get_ticks_msec() / 1000.0 * 1.6
		var target := interaction_system._tower_at(mpos)
		place_note = {}
		var pv: Array = target.preview(picked) if target and interaction_system._place_ok(target) else []
		var refuse: bool = target != null and (pv.is_empty() or (pv[0] as PackedStringArray)[0] == "넣을 수 없음")
		for t in towers.get_children():
			if not interaction_system._place_ok(t):
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
		var sp: Dictionary = interaction_system.moving.spec() if interaction_system.moving else {"els": {picked["e"]: picked["lv"]}, "pat": Pat.DEFAULT, "plv": 1, "mods": {}}
		var col: Color = Elem.COLORS[sp["els"].keys()[0]]
		if not interaction_system.moving:
			draw_circle(place_pos, Tower.RADIUS, Color(col, 0.6))
		var d := _aim_dir(place_pos)
		if d != Vector2.ZERO:
			Tower.draw_range(self, place_pos, d, sp)
			if interaction_system.moving and not get_tree().paused:
				interaction_system.moving.set_attack_direction(d)
			draw_line(place_pos, place_pos + d * (Tower.RADIUS + 14.0), Color.WHITE, 3.0)
	# 마우스를 올린 오브젝트의 공격 범위
	if phase == Phase.MOVE and interaction_system.moving:
		Tower.draw_range(self, mpos, interaction_system.moving.dir, interaction_system.moving.spec())
	# 연결선: 옮길 자리에서 이어지는지 미리 보여 준다
	var movers: Array = [interaction_system.moving] if phase == Phase.MOVE and interaction_system.moving else (interaction_system.drag_group if interaction_system.dragging else [])
	for mover in movers:
		if not is_instance_valid(mover):
			continue
		if interaction_system._bad_spot(mover, movers) != "":
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
	elif interaction_system.dragging:
		# 끄는 동안: 옮기는 오브젝트들의 범위 (방향은 그대로)
		for t in interaction_system.drag_group:
			if is_instance_valid(t):
				Tower.draw_range(self, t.position, t.dir, t.spec())
	elif phase in [Phase.CHOOSE, Phase.WAVE, Phase.READY]:
		var hov := interaction_system._tower_at(mpos) if not card_dock.over_ui(interaction_system._pointer_screen()) else null
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
	for t in interaction_system.selected:
		if is_instance_valid(t):
			for i in 8:
				var a0 := TAU * i / 8 + Time.get_ticks_msec() / 800.0
				draw_arc(t.position, Tower.RADIUS + 12.0, a0, a0 + 0.45, 6, Color(0.5, 0.9, 1.0, 0.95), 2.5)
	if interaction_system.boxing:
		var r := Rect2(interaction_system.box_start, mpos - interaction_system.box_start).abs()
		draw_rect(r, Color(0.5, 0.9, 1.0, 0.08))
		draw_rect(r, Color(0.5, 0.9, 1.0, 0.8), false, 1.5)


func _draw_place_label(at: Vector2, text: String, color: Color) -> void:
	var visible := view_rect().grow(-8)
	var width := ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	at.x = clampf(at.x, visible.position.x, maxf(visible.position.x, visible.end.x - width))
	at.y = clampf(at.y, visible.position.y + 14, visible.end.y)
	var avoid: Array[Rect2] = []
	var to_world := get_canvas_transform().affine_inverse() * ui_root.get_global_transform()
	for rect in ui_layout_system._info_blockers():
		avoid.append(to_world * rect)
	avoid.append(Rect2(interaction_system._pointer_world() - Vector2(24, 24), Vector2(48, 48)))
	place_label_rect = ui_layout_system._free_badge(Rect2(at - Vector2(0, 14), Vector2(width, 18)), Vector2.UP, avoid, visible)
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
	for rect in ui_layout_system._info_blockers():
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
	abilities_system._draw_ley()
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
	var d := interaction_system._pointer_world() - from
	if touch_ui and phase == Phase.AIM and (not interaction_system.aim_hold or d.length() < AIM_TOUCH_MIN):
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
		hud_system._show_toast("이번 쉬는 시간에는 이미 요청한 속성을 받았어요")
		return
	mp_req_mode = not mp_req_mode
	mp_req_btn.text = "요청 취소" if mp_req_mode else "속성 요청"
	hint.text = "속성을 요청할 내 오브젝트를 누르세요" if mp_req_mode else ui_layout_system._th(cards_system._choose_hint() if phase == Phase.CHOOSE else "")


func _mp_req_open(t: Tower) -> void:
	mp_req_mode = false
	mp_req_btn.text = "속성 요청"
	interaction_system._restore_hint()
	var items: Array = []
	for e in Elem.ALL:
		if t.can_take({"type": "elem", "e": e, "lv": 1}):
			var ee: int = e
			items.append([Elem.NAMES[e], Elem.COLORS[e], func(): _mp_req_set(t, ee)])
	if t.req_e >= 0:
		items.append(["요청 지우기", Color(0.75, 0.75, 0.75), func(): _mp_req_set(t, -1)])
	if items.is_empty():
		hud_system._show_toast("이 오브젝트에는 더 넣을 수 있는 속성이 없어요")
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
		hud_system._show_toast("요청: %s 속성 (친구 화면에 표시돼요)" % Elem.NAMES[e])


## 친구 오브젝트가 지금 든 속성 카드를 요청했나.
func _req_ok(t: Tower) -> bool:
	return mp_mode == "coop" and is_instance_valid(t) and t.owner_id != mp.my_id and t.req_e >= 0 \
		and str(picked.get("type", "")) == "elem" and int(picked.get("e", -1)) == t.req_e


## 요청한 속성을 친구 오브젝트에 넣어 준다: 주인 기기가 넣고 상태를 다시 보낸다.
func _mp_give(t: Tower) -> void:
	mp.send({"t": "gift", "nid": t.net_id, "e": picked["e"], "lv": picked["lv"]}, t.owner_id)
	hud_system._show_toast("%s에게 %s 속성을 넣어 줬어요" % [_mp_name(t.owner_id), Elem.NAMES[picked["e"]]])
	sfx.play("place")
	burst(t.position, cards_system._card_color(picked), 16, 160.0)
	t.req_e = -1
	t.queue_redraw()
	cards_system._after_place()


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
			hud_system._show_toast("%s가 보낸 %s 속성은 요청이 이미 채워져 들어가지 않았어요" % [_mp_name(from), Elem.NAMES.get(e, "?")])
			return
		var m: String = t.add(e, lv)
		t.req_e = -1
		mp_req_got_w = wave
		t.place_pop = 1.0
		t.queue_redraw()
		hud_system._show_toast("%s가 %s 속성을 넣어 줬어요 · %s" % [_mp_name(from), Elem.NAMES[e], m])
		sfx.play("place")
		if m.begins_with("조합"):
			sfx.play("reaction", 0.0)
		burst(t.position, Elem.COLORS[e], 20, 200.0)
		progression_system._check_progress()
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
	hud_system._show_toast("%s을(를) 내보냈어요" % _mp_name(id))
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
		hud_system._show_toast("돌아왔어요: 다시 직접 골라요")


## 잠수: 남은 고르기를 대신하고 준비한다 (속성은 반응이 생기는 내 오브젝트에, 없으면 오브젝트가 적은 진입 방향에 새로,
## 다른 카드는 넣을 수 있는 내 오브젝트에, 특성은 동전 말고 첫 번째).
func _mp_auto_rest() -> void:
	if phase == Phase.GAMEOVER or phase == Phase.WAVE or mp_mode == "":
		return
	mp_auto_now = true
	mp_req_mode = false
	mp_pop.visible = false
	for i in 40:
		if phase in [Phase.PLACE, Phase.AIM, Phase.MOVE] or interaction_system.press_t or interaction_system.moving:
			interaction_system._cancel_step()
			continue
		if perk_mode:
			if coin_stage > 0:
				break
			var opts: Array = perk_offer.filter(func(pk): return pk["id"] != "coin")
			perks_system._on_perk(opts[0] if not opts.is_empty() else perk_offer[0])
			continue
		if phase != Phase.CHOOSE or picks_left <= 0 or offer.is_empty():
			break
		if not _mp_auto_pick():
			break
	if phase == Phase.CHOOSE and not perk_mode:
		picks_left = 0
		cards_system._enter_ready()
	mp_afk_n += 1
	if mp_mode == "coop":
		if mp_afk_n >= int(Rules.tune["mp_afk_after"]) and not mp_afk:
			mp_afk = true
			mp.send({"t": "afk", "on": true})
			hud_system._show_toast("자리 비움: 다음부터 카드를 대신 골라요 (화면을 누르면 돌아와요)")
		else:
			hud_system._show_toast("시간이 지나 카드를 대신 골랐어요")
		if phase == Phase.READY:
			_mp_coop_ready()
	elif mp_mode == "vs":
		if mp_afk_n >= int(Rules.tune["vs_idle_out"]):
			mp_auto_now = false
			mp_rank = "%d번 연속 움직임이 없어 탈락했어요" % mp_afk_n
			core_hp = 0
			run_flow_system._game_over()
			return
		hud_system._show_toast("오래 움직임이 없어 웨이브를 시작했어요 (%d번 연속이면 탈락)" % int(Rules.tune["vs_idle_out"]))
		if phase == Phase.READY:
			run_flow_system._start_wave()
	mp_auto_now = false


## 카드 하나를 대신 고른다. 고를 게 없으면 false.
func _mp_auto_pick() -> bool:
	var mine: Array = _my_towers()
	for o in offer:
		if o["type"] == "elem":
			for t in mine:
				if t.can_take(o) and not Elem.new_reactions(t.eff_now(), o["e"]).is_empty():
					cards_system._on_pick(o)
					interaction_system._place_on(t)
					return true
		else:
			for t in mine:
				if t.can_take(o):
					cards_system._on_pick(o)
					cards_system._apply_card(t)
					return true
	for o in offer:
		if o["type"] == "elem" and not (o["e"] == Elem.STAR and cards_system.star_full()):
			var spot := _mp_auto_spot()
			if spot.is_empty():
				return false
			cards_system._on_pick(o)
			interaction_system._place_tower(spot[0], spot[1])
			cards_system._after_place()
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
		onboarding_system._open_tut(["mp"])  # 멀티 창 위에 바로
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
			hud_system._show_toast("연결이 끊겼어요. 다시 접속하는 중…")
		if not room_gone and Time.get_ticks_msec() < mp_rejoin_until:
			mp_rejoin_wait = 2.0
			return
		mp_rejoin_until = 0
		mp_rank = "호스트가 나가 판이 끝났어요" if room_gone else reason
		core_hp = 0
		run_flow_system._game_over()
	elif mp_mode == "vs" and not mp.is_host() and phase != Phase.GAMEOVER:
		# 대결 참가자: 호스트와 끊기면 이 판은 끝 (끊긴 사람은 패배)
		mp_rank = "연결이 끊겨 판이 끝났어요 (끊기면 패배)"
		core_hp = 0
		run_flow_system._game_over()
	else:
		hud_system._show_toast(reason)
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
			hud_system._show_toast("차단한 플레이어가 들어와서 내보냈어요")
			mp.call_deferred("_drop", did)
			continue
		var nm: String = _mp_name(id) if not me else (n[1] if n[1] != "" else "닉네임 없음")
		var st := "" if me or n[2] else ("연결 안 됨" if n[4] else "연결 중")
		if st == "" and not me and mp.in_game.has(id):
			st = "판 진행 중"
		var row := _mp_member_row(id, n[3], id == 1, nm + (" (나)" if me else ""), st)
		if not me:
			row.add_child(leaderboard_system._ugc_buttons(mp.pids.get(id, ""), str(n[1]), "mp", func(): _mp_refresh_lobby()))
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
	persistence_system._refresh_continue()
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
	run_flow_system._apply_rules()
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
		cards_system._update_auto_btn()
	mp_panel.visible = false
	var tn := Meta.tutor_next
	Meta.tutor_next = false  # 멀티플레이는 첫 판 안내(카드 종류를 하나씩 엶) 없이
	progression_system._hide_title()
	lanes.clear()
	run_flow_system._start_choose()
	Meta.tutor_next = tn
	hud_system.big_banner("%s 시작! %d명" % ["대결" if mp_mode == "vs" else "협동", mp_others.size() + 1], Color(0.6, 0.9, 1.0))


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
					hud_system._show_toast("%s 연결이 끊겨 탈락했어요" % _mp_name(from))
				else:
					hud_system._show_toast("%s 연결이 끊겼어요%s" % [_mp_name(from), " (같은 방 코드로 다시 들어올 수 있어요)" if mp_mode == "coop" else ""])
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
				hud_system._show_toast("%s 탈락 (웨이브 %d)" % [_mp_name(from), mp_others[from]["w"]])
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
				waves_system._update_preview()
			hud_system._show_toast("%s가 구체 %d개를 보냈어요 (다음 웨이브에 더 옴)" % [_mp_name(from), n])
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
				perks_system._apply_perk(id)
				hud_system._show_toast("%s 특성: %s (팀 전체)" % [_mp_name(from), _perk_name(id)])
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
				run_flow_system._game_over()
		"gift":
			_mp_recv_gift(from, msg)
		"wave":
			if mp_ghost and from == 1:
				_mp_wait_end()
				wave = int(msg.get("w", wave + 1)) - 1
				mp_wave_go = true
				_end_ghost_rest()
				run_flow_system._start_wave()
				mp_wave_go = false
				mp_i_ready = false
		"next":
			if mp_ghost and from == 1:
				mp_next = msg
				if int(msg.get("w", -1)) == wave:
					_mp_ghost_rest()
					waves_system._update_preview()
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
				run_flow_system._game_over()


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
	hud_system._show_toast("%s 다시 들어왔어요" % _mp_name(id))


## 협동 참가자: 호스트가 보낸 판 상태로 맞춘다 (끊겼다 다시 붙음, 또는 게임을 껐다 켜고 같은 코드로 들어옴).
## 쉬는 시간이면 카드 고르기 없이 웨이브 기다림으로 (다시 들어와 카드를 더 받지 않게).
func _mp_resync(msg: Dictionary) -> void:
	var fresh := mp_mode == ""
	mp_rejoin_until = 0
	mp_rejoin_wait = 0.0
	for t in towers.get_children():
		towers.remove_child(t)
		t.queue_free()
	interaction_system.selected.clear()
	for o in orbs.get_children():
		o.queue_free()
	mp_ghosts.clear()
	if fresh:
		_mp_begin(msg)
		for id in msg.get("perks", {}):
			for i in int(msg["perks"][id]):
				if PERKS.any(func(pk): return pk["id"] == id):
					perks[id] = perks.get(id, 0) + 1
					perks_system._apply_perk(id)
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
		run_flow_system._start_wave()
		mp_wave_go = false
	else:
		wave = int(msg.get("w", 0))
		_mp_ghost_rest()
		cards_system._enter_ready()
		waves_system._update_preview()
	mp_i_ready = false
	hud_system._refresh_dps()
	hud_system._show_toast("다시 들어왔어요 (웨이브 %d)" % maxi(wave, 1))


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
		var m := interaction_system._pointer_world()
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
		progression_system._ach_check()
		return
	var to := _mp_vs_target([])
	if to <= 0:
		progression_system._ach_check()
		return
	var n := maxi(1, roundi((1 + wave / 4) * _mp_send_k()))
	mp.send({"t": "atk", "n": n}, to)
	Ach.add("mp_sent", n)
	progression_system._ach_check()
	hud_system._show_toast("완벽 방어! %s에게 구체 %d개를 보냈어요" % [_mp_name(to), n])


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
	progression_system._ach_check()


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
	progression_system._ach_check()


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
		hud_system.big_banner("승리! 끝까지 버텨 기록을 늘려 보세요", Color(1, 0.85, 0.3))
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
	run_flow_system._start_wave()
	mp_wave_go = false


## 참가자: 호스트가 웨이브를 시작했는데 아직 고르는 중이면 그대로 닫는다.
func _end_ghost_rest() -> void:
	if phase in [Phase.PLACE, Phase.AIM, Phase.MOVE]:
		interaction_system._cancel_step()
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
	hud_system._show_toast("웨이브 %d 클리어!" % wave)
	sfx.play("clear", 0.0)
	_show_mvp()
	var sh: Variant = msg.get("sh", {})
	_mp_ach_coop(wave, sh if sh is Dictionary else {})
	if bool(msg.get("perk", false)):
		perks_system._start_perk()
	else:
		run_flow_system._start_choose()


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
		hud_system._show_toast("중앙 피격! %d/%d" % [maxi(hp, 0), core_max])
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
			if x in interaction_system.selected:
				interaction_system.selected.erase(x)
			x.queue_free()


# ---------- 별 상한·특성 ----------

## 별이 든 오브젝트(별·행성 합쳐)가 star_max개라 별을 새로 놓을 수 없다.
