class_name BinduSession
extends Node2D
## Shared scene/run contract. Feature-private state lives in its owner controller.

enum Phase { CHOOSE, PLACE, AIM, WAVE, GAMEOVER, MOVE, READY }

var abilities_system: BinduAbilities
var cards_system: BinduCards
var combat_system: BinduCombat
var field_overlay_system: BinduFieldOverlay
var field_view_system: BinduFieldView
var frame_system: BinduFrame
var hud_system: BinduHud
var interaction_system: BinduInteraction
var leaderboard_system: BinduLeaderboard
var lobby_system: BinduLobby
var menu_system: BinduMenu
var multiplayer_system: BinduMultiplayer
var onboarding_system: BinduOnboarding
var online_system: BinduOnline
var patchlog_system: BinduPatchlog
var perks_system: BinduPerks
var persistence_system: BinduPersistence
var progression_system: BinduProgression
var run_flow_system: BinduRunFlow
var spawning_system: BinduSpawning
var ui_layout_system: BinduUiLayout
var ui_shell_system: BinduUiShell
var viewport_system: BinduViewport
var waves_system: BinduWaves

func _init() -> void:
	abilities_system = BinduAbilities.new(self)
	cards_system = BinduCards.new(self)
	combat_system = BinduCombat.new(self)
	field_overlay_system = BinduFieldOverlay.new(self)
	field_view_system = BinduFieldView.new(self)
	frame_system = BinduFrame.new(self)
	hud_system = BinduHud.new(self)
	interaction_system = BinduInteraction.new(self)
	leaderboard_system = BinduLeaderboard.new(self)
	lobby_system = BinduLobby.new(self)
	menu_system = BinduMenu.new(self)
	multiplayer_system = BinduMultiplayer.new(self)
	onboarding_system = BinduOnboarding.new(self)
	online_system = BinduOnline.new(self)
	patchlog_system = BinduPatchlog.new(self)
	perks_system = BinduPerks.new(self)
	persistence_system = BinduPersistence.new(self)
	progression_system = BinduProgression.new(self)
	run_flow_system = BinduRunFlow.new(self)
	spawning_system = BinduSpawning.new(self)
	ui_layout_system = BinduUiLayout.new(self)
	ui_shell_system = BinduUiShell.new(self)
	viewport_system = BinduViewport.new(self)
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
var wave_stat := {}  # 이번 웨이브 여유 (판 기록 leaks): hp 나온 구체 체력+실드 합, kn 처치 수, life 처치까지 걸린 시간 합, close 가장 가까이서 처치한 거리(-1 없음), peak 동시에 살아 있던 구체 최대 수
var leak_flash: Array = []  # 화면 가장자리 붉은 번짐 [자리, 남은 시간]
var boss_plan := {}  # 다음 보스: 쉬는 시간에 진입 각도·체력·속도·저항을 미리 정해 길과 정보를 정확히 보여 준다
var touch_ui := OS.has_feature("mobile")  # 마지막 입력이 터치였는지 (터치는 마우스를 올려 둘 수 없다). 폰·태블릿은 첫 터치 전 첫 화면부터 터치용 글
var help_touch := false  # 도움말 글을 터치용으로 썼는지
var legend_rx_rows := 999  # 설명에 적을 반응 줄 수 상한 (화면에 맞춰 _process가 줄임)
var legend_rows := 0  # 지금 설명에 적힌 반응 줄 수
## 터치 화면에선 버튼 글의 키 안내 "(Q)"·"(Space: 바로)"를 뺀다. "(S: 멈추기)"처럼 누르면 하는 일은 "(눌러서 멈추기)"로
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
var sim_id := 0  # 계산 조각 번호: 조각 안에서 변하지 않는 값(오브젝트 피해 배율)을 조각마다 한 번만 계산
var prof_on := false  # tools/perf.gd: 부분별 계산 시간 기록
var fx_layer: Node2D  # 피해 숫자·파편 (맨 위)
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
var hud: Control  # 왼쪽 위 점수 줄: 아이콘 칩 (_update_hud가 hud_chips를 채우고 _draw_hud가 그린다)
var hud_chips: Array = []  # [자리 Rect2, 아이콘, 아이콘 색, 글, 글 색, 말풍선 줄]
var info: Control  # 화면 위 아이콘 층: 진입 화살표 배지·고르기 배지·말풍선 (_draw_info)
var tip_rects: Array = []  # 이번 프레임 말풍선 자리 [Rect2(UI 좌표), 줄들 [[글, 색]]]
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
var help_label: Label
var help_scroll: ScrollContainer
var hover_elem := -1  # 마우스를 올린 선택지의 속성
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
var mp_btn: Button  # 시작 화면의 [멀티플레이]
var mp_bar: Label  # 게임 중 위쪽 가운데: 다른 플레이어 상태
var mp_mode := ""  # "" 혼자 | "vs" 대결 | "coop" 협동 (판을 시작하면 정해짐)
var mp_seed := 0  # 대결: 모두 같은 웨이브를 받는 씨앗 (0이면 혼자 하는 판처럼 전역 난수)
var wrng := RandomNumberGenerator.new()
var w_off := false  # 보낸 구체처럼 씨앗 밖에서 뽑는 구체 (같은 웨이브 순서를 흐트리지 않게)
var mp_others := {}  # id -> {name, w, hp, mx, sc, alive, gone}
var mp_next_extra := 0  # 대결: 다음 웨이브에 더 오는 구체 (상대가 보냄)
var mp_extra_left := 0  # 대결: 이번 웨이브에 아직 안 나온 보낸 구체
var mp_ghost := false  # 협동 참가자: 판 계산은 호스트가 하고 이 기기는 받은 대로 그린다
var mp_wave_go := false
var mp_ready := {}  # 협동 호스트: 웨이브 시작을 누른 사람
var mp_i_ready := false
var mp_tw_n := 0
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
var mp_req_mode := false  # [속성 요청]을 누르고 내 오브젝트를 고르는 중
var mp_wave_extra := 0  # 대결: 이번 웨이브에 섞인 받은 구체 수
var mp_recv_n := 0  # 대결: 다음 웨이브에 받기로 한 구체 (상한 계산)
var mp_cursors := {}  # id -> {"p": 그리는 자리, "to": 받은 자리, "t": 받은 시각 ms}
const MP_CUR_HZ := 12.0
const MP_CUR_HIDE_MS := 4000  # 이만큼 안 움직이면 흐려지다 사라짐  # 대결: 게임 오버 글에 붙일 순위
var run_id := ""  # 판 번호: 5웨이브마다 보내는 진행 기록과 끝 기록을 서버에서 한 줄로 (이어하기에 저장)
var run_log: Array = []  # 선택지 기록 [{w, k: card|perk, o: 나온 것, p: 고른 것(새로고침이면 "")}]
var run_game := 0.0  # 웨이브 진행 게임 시간 합
var run_real := 0.0  # 실제로 플레이한 시간 (시작 화면·일시정지 빼고)
var update_btn: Button  # 시작 화면: 업데이트
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
	service_signals.connect_to(fx_layer.draw, field_view_system._draw_fx)
	multiplayer_system.mp_cur_layer = _layer("Cursors")
	multiplayer_system.mp_cur_layer.z_index = 6
	service_signals.connect_to(multiplayer_system.mp_cur_layer.draw, multiplayer_system._draw_mp_cursors)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)  # 가로 고정 (예전 빌드는 자유 회전으로 설정돼 있었다)
	camera = Camera2D.new()
	camera.position = viewport_system.center()
	add_child(camera)
	for i in 140:
		field_view_system.stars.append(Vector3(randf() * Meta.FIELD.x, randf() * Meta.FIELD.y, randf_range(0.03, 0.12)))
	ui_shell_system._build_ui()
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
	service_signals.connect_to(mp.room_ready, lobby_system._mp_refresh_lobby)
	service_signals.connect_to(mp.peers_changed, lobby_system._mp_refresh_lobby)
	service_signals.connect_to(mp.failed, lobby_system._mp_failed)
	service_signals.connect_to(mp.packet, multiplayer_system._mp_packet)
	service_signals.connect_to(mp.status_changed, lobby_system._mp_apply_switch)
	service_signals.connect_to(mp.ping_changed, lobby_system._mp_refresh_pings)
	service_signals.connect_to(mp.peer_up, multiplayer_system._mp_peer_up)
	mp.check_status()
	lobby_system._mp_refresh_lobby(false)
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
	service_signals.connect_to(online_system.updater.progress, online_system._on_update_progress)
	service_signals.connect_to(online_system.updater.failed, online_system._on_update_failed)
	online_system.updater.cleanup()
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
		lobby_system._mp_back_lobby()
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
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.5
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


const BOSS_FS := 16


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


static func lane_spread(w: int) -> float:
	if Meta.map_id == "cross":
		return 0.06  # 십자로: 네 길 위로만 온다
	if Meta.map_id == "line":
		return 0.0  # 회랑: 방향은 하나, 대신 높이가 길 폭 안에서 갈린다
	return minf(0.15 + 0.01 * w, 0.4)


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


static func compass(a: float) -> String:
	return ["동", "남동", "남", "남서", "서", "북서", "북", "북동"][posmod(roundi(a / (PI / 4.0)), 8)]


## 웨이브가 끝나면(클리어·게임 오버) 누수를 한 줄로 요약해 둔다.
const LEAK_KIND_KEYS := {Orb.Kind.NORMAL: "normal", Orb.Kind.FAST: "fast", Orb.Kind.TANK: "tank", Orb.Kind.BOSS: "boss"}


## 서버로 보낼 웨이브별 중앙 피해 기록: 웨이브마다 닿은 구체 수·구체가 준 피해·실제로 깎인 체력(실드 뺀 값)·웨이브 끝 체력·종류별 수와 피해.
## 닿지 않은 웨이브도 n 0으로 들어간다 (웨이브별 비율을 낼 수 있게).
const GRID := 64.0
static func _mp_my_name() -> String:
	return Meta.nickname.strip_edges().left(12)
