extends Node2D
## 게임 진행: 웨이브, 오브젝트 선택·설치, 충돌, 점수.

enum Phase { CHOOSE, PLACE, AIM, WAVE, GAMEOVER, MOVE, READY, DRAW }

const CORE_RADIUS := 14.0
const LINE_INSET := 90.0  # 회랑 맵: 문(중앙 점)이 화면 끝에서 떨어진 거리
const LINE_HALF := 180.0  # 회랑 맵: 길 폭의 반
const LINE_ORBS := 1.6  # 회랑 맵: 구체 수 배율 (방향이 하나고 길이 길어서). 봇 32판으로 평원에 맞춤 (2026-10-30)
const LINE_HP := 2.4  # 회랑 맵: 구체 체력 배율
const LINE_SPD := 1.6  # 회랑 맵: 구체 속도 배율 (길이 길어 오래 맞는 만큼)
const SPIRAL_SWIRL := 0.6  # 소용돌이 맵: 구체가 중앙 방향에서 비껴 도는 각도(라디안)
const CORE_MAX_HP := 10
const MERGE_DIST := 30.0
const SAVE_PATH := "user://best.cfg"
const RUN_PATH := "user://run.cfg"  # 이어하기: 쉬는 시간마다 저장, 게임 오버면 지움
const RUN_FORMAT := 1
const READY_HINT := "Space 또는 [웨이브 시작]: 시작   오브젝트 클릭: 방향 바꾸기   끌기: 옮기기"
## 첫 판: 카드 종류가 열리는 웨이브 (그 웨이브 앞 쉬는 시간부터 나온다). 속성은 처음부터
const TUTOR_OPEN := {"pat": 3, "mod": 4, "trig": 5, "link": 6, "cata": 6}
const PLACE_HINT := "클릭: 설치 (오브젝트 위면 속성 겹치기)   오브젝트 꾹 누르기·끌기: 옮기기\n우클릭/Esc: 다시 고르기"

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
var prism_towers: Array = []  # 발사체가 지날 때 확인할 프리즘 오브젝트 (매 계산마다 갱신)
var picks_left := 0  # 이번 쉬는 시간에 남은 설치 횟수
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
var aim_right := false  # 오브젝트를 우클릭한 채 끌어 방향을 정하는 중 (떼면 확정)
var box_start := Vector2.ZERO
var cards_hidden := false  # 선택지를 내려 필드를 보는 중
var hide_btn: Button
var card_detail_btn: Button  # 선택지 카드 [자세히] 켜기·끄기 (Meta.card_detail)
var move_orig_pos := Vector2.ZERO
var move_orig_dir := Vector2.RIGHT
var move_return := Phase.CHOOSE  # 옮기기를 끝내면 돌아갈 단계
# 그린 궤적 그리기 (Phase.DRAW)
var draw_t: Tower = null
var draw_queue: Array = []  # 그릴 갈래 번호들 (앞에서부터)
var draw_after := false  # 카드로 들어왔으면 다 그린 뒤 _after_place
var draw_pts := PackedVector2Array()  # 지금 그리는 길 (전역, 첫 점 = 오브젝트)
var draw_on := false  # 누른 채 그리는 중
var draw_len := 0.0
var draw_bends := 0
var draw_bend_pts := PackedVector2Array()
var draw_stop := ""  # 더 그릴 수 없는 까닭 (길이·꺾기를 다 씀)
var draw_skip := 0  # 방금 꺾임으로 센 뒤 다시 세지 않을 조각 수
var auto_start := false  # 끄면 설치 후 Space로 웨이브 시작
var auto_btn: Button
var start_btn: Button
var draw_ok_btn: Button  # 터치: 다 그린 길 [확정] (손을 떼자마자 넣으면 삐끗한 길을 되돌릴 수 없었다)
var draw_wait := false  # 터치: 손을 뗀 뒤 [확정]을 기다리는 중
var draw_aim := Vector2.ZERO  # 터치: 손가락 떨림을 줄인 그리기 목표점
var cancel_btn: Button  # 옮기기·설치 중 화면 취소 (우클릭·Esc가 없는 터치 화면용)
var detail_btn: Button  # 터치: 오브젝트 정보창 [자세히] (Shift 대신)
var tip_tower: Tower = null  # 터치: 정보창에 보이던 오브젝트
var tip_detail := false  # 터치로 [자세히]를 켰는지 (정보창이 사라지면 꺼짐)
var tip_frame := -10  # 오브젝트 정보창을 마지막으로 그린 프레임
var touch_tip_t := 0.0  # 터치: 누른 뒤 정보창을 보여 줄 남은 시간 (손을 뗀 자리에 정보창이 계속 남아 전장을 가리던 것)
const TOUCH_TIP_SEC := 3.0
var wave_leaks: Array = []  # 이번 웨이브에 중앙에 닿은 구체 [나온 방향 번호, 종류, 피해]
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
var refracts: Array = []  # 프리즘 굴절 [중심, 탄 방향, 색, 남은 시간]
var beams: Array = []  # 빛줄기 [시작, 끝, 색, 남은 시간]
var live_orbs: Array = []
var targets: Array = []  # 화면 안에 들어온 구체 (공격 대상)
var sim_id := 0  # 계산 조각 번호: 조각 안에서 변하지 않는 값(오브젝트 피해 배율)을 조각마다 한 번만 계산
var prof_on := false  # tools/perf.gd: 부분별 계산 시간 기록
var prof := {}
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
var guide_t := 0.0  # 남은 시간. 음수면 웨이브가 시작될 때까지
var wave_resist := -1  # 다음 웨이브 저항 속성 (-1: 없음)
var legend_btn: Button
var aim_start_ms := 0
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
	{"id": "core", "name": "단단한 중앙", "desc": "중앙 최대 체력 +3, 모두 회복"},
	{"id": "reroll", "name": "넉넉한 선택", "desc": "쉬는 시간마다 새로고침 +1"},
	{"id": "luck", "name": "행운", "desc": "속성 카드가 Lv2로 나올 확률 +20%"},
	{"id": "regen", "name": "회복", "desc": "웨이브를 마칠 때마다 중앙 체력 +1 (겹쳐 고르면 하나당 +0.5)"},
	{"id": "slow", "name": "끈적한 공간", "desc": "모든 구체 이동 속도 -8%"},
	{"id": "harmony", "name": "조화", "desc": "속성을 여러 종류 겹쳐 생기는 공격 속도 감소가 절반으로"},
	{"id": "coin", "name": "운명의 동전", "desc": "동전을 던지고 특성 3개를 새로 받아요. 앞면: 고른 특성이 두 번 적용. 뒷면: 한 번 적용 + 이번 쉬는 시간 새로고침 +2"},
]
var perks := {}  # id → 고른 횟수
var regen_acc := 0.0  # 회복 특성의 1이 안 되는 나머지 (다음 웨이브로)
var perk_mode := false
var perk_offer: Array = []
var orb_speed_mul := 1.0
var rerolls_left := 1
var bonus_rerolls := 0
# 웨이브 넘기기: 고르기를 미루고 웨이브를 연달아 진행한다. 미룬 고르기는 멈춘 쉬는 시간에 한꺼번에
const SKIP_NS := [1, 3, 5, 10]
var skip_left := 0  # 더 넘길 웨이브 수 (지금 웨이브 포함, 0이면 넘기는 중 아님)
var skip_total := 0  # 이번에 넘기기로 한 웨이브 수 (표시용)
var skip_stop := false  # 멈추기를 눌렀거나 중앙이 위험해짐: 이번 웨이브가 끝나면 멈춤
var bank_picks: Array = []  # 미룬 고르기. 값은 쌓은 쉬는 시간의 웨이브 (속성 Lv2 확률을 그때 기준으로)
var bank_rerolls := 0
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
const COMBO_KEEP := 3.0  # 이 게임 시간(배속과 상관없이) 안에 다음 처치가 나와야 콤보가 이어진다
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
var account_label: Label  # 설정: 계정 상태 한 줄
var remote_btn: Button  # 같은 계정의 다른 기기에서 하던 판이 있고, 이 기기에 하던 판이 없을 때만
var remote_run := ""  # remote_btn이 가져올 판
var moved_run := ""  # 다른 기기가 가져간 판: 이 기기에서 계속 해도 서버에는 더 올리지 않는다
var new_btn: Button
var new_armed := 0.0  # 저장된 판이 있을 때 새로 시작은 두 번 눌러야 (실수로 지우지 않게)
var map_label: Label
var flip_label: Label  # 회랑 맵: 구체가 오는 쪽 (회랑일 때만 보임)
var rules_label: Label
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
var tut_queue: Array[String] = []  # 판에서 처음 생겨서 띄울 항목 (쉬는 시간·시작 화면에서 띄움)
var tut_first := false  # 이 기기에서 처음 켰다: 시작 화면이 뜨면 기본 항목을 무조건
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
var dps_panel: PanelContainer
var dps_head: Button
var dps_scroll: ScrollContainer
var dps_list: VBoxContainer
var dps_sig := ""  # 표를 다시 만들지 정하는 요약 (오브젝트·피해가 바뀔 때만)
var dps_focus: Tower = null  # 표에서 마우스를 올린 오브젝트
var dps_hidden := OS.has_feature("mobile")  # D: 표 접기. 폰·태블릿은 접어 두고 시작
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
var mp_room_box: VBoxContainer  # 방 코드·복사 + 사람 줄(플랫폼 그림·닉네임)
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
var mp_rank := ""  # 대결: 게임 오버 글에 붙일 순위
var run_id := ""  # 판 번호: 5웨이브마다 보내는 진행 기록과 끝 기록을 서버에서 한 줄로 (이어하기에 저장)
var run_log: Array = []  # 선택지 기록 [{w, k: card|perk, o: 나온 것, p: 고른 것(새로고침이면 "")}]
var run_game := 0.0  # 웨이브 진행 게임 시간 합
var run_real := 0.0  # 실제로 플레이한 시간 (시작 화면·일시정지 빼고)
var update_btn: Button  # 시작 화면: 새 버전 받기
var updater: Updater  # Windows 게임 안 업데이트
var notice_label: Label  # 시작 화면: 패치 공지
var board_lines := {}  # 리더보드 창: period → 줄 목록
var board_bar: HBoxContainer  # 리더보드 창 위쪽 필터 버튼 (맵·규칙 버전·시즌)
var board_map := "plain"  # 리더보드 필터. 창을 열 때 지금 고른 맵·규칙 버전으로 시작
var board_rules := 1
var board_season := 0  # 0: 이번 시즌
var board_grow := false  # 리더보드: 씨앗 나무를 쓴 '성장' 기록 (끄면 '순수')
var board_easy := false  # 리더보드: 쉽게 모드를 쓴 판 (성장·순수 섞어서)
var board_seasons: Array = []  # 서버 시즌 목록 (새 시즌부터)
static var title_seen := false  # 다시 시작하면 타이틀은 건너뛴다
# 정원 모드 (Garden)
var garden_cd := -1.0  # 다음 웨이브까지 남은 시간 (정원 쉬는 시간, 자동 진행)
var garden_auto := true  # 정원: 쉬는 시간이 지나면 다음 웨이브를 저절로 (끄면 Space)
var garden_perk_t := 0.0  # 정원 특성: 이 시간이 지나면 첫 번째를 고른다
var garden_wave_dew := 0.0  # 이번 웨이브에 얻은 이슬
var garden_kills0 := 0  # 이번 웨이브 시작 때 처치 수 (숙련)
var rebirth_btn: Button
var bonsai_btn: Button
var rebirth_armed := 0.0
var garden_btn: Button  # 시작 화면
var tree_btn: Button
var tree_panel: PanelContainer
var tree_box: VBoxContainer
static var garden_note := ""  # 장면을 다시 불러온 뒤 보여 줄 글 (환생)


func _ready() -> void:
	randomize()
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
	coop_orbs = 1.0
	mp = Mp.new()
	add_child(mp)
	mp.room_ready.connect(_mp_refresh_lobby)
	mp.peers_changed.connect(_mp_refresh_lobby)
	mp.failed.connect(_mp_failed)
	mp.packet.connect(_mp_packet)
	mp.status_changed.connect(_mp_apply_switch)
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
	if Garden.on:
		_enter_garden()
	elif title_seen or DisplayServer.get_name() == "headless":
		_start_choose()
	elif _old_run_version() != "":
		_end_old_run(_old_run_version())
	else:
		title_label.visible = true
		_refresh_continue()
		hint.text = ""
		net.check()  # 시작 화면이 뜰 때마다 새 버전 확인 (처음 켤 때는 Net이 이미 묻는 중)


## 창이 포커스를 잃어도 판은 계속 진행된다 (직접 조작이 없으니 멈추지 않음).
func _notification(what: int) -> void:
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
	if camera == null or is_equal_approx(view_zoom, 1.0):
		return Rect2((Meta.FIELD - vs) / 2.0, vs)
	var s := vs / view_zoom
	return Rect2(camera.position - s / 2.0, s)


## 확대하지 않았을 때 보이는 월드 영역 (확대한 화면이 이 밖으로 나가지 않게).
func full_view() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2((Meta.FIELD - vs) / 2.0, vs)


## 전장 확대: 1~ZOOM_MAX배, at(화면 좌표)이 가리키는 월드 점이 그 자리에 남게. 화면은 전장 밖으로 나가지 않는다.
const ZOOM_MAX := 2.5
func _zoom_to(z: float, at: Vector2) -> void:
	var vs := get_viewport_rect().size
	var before := camera.position + (at - vs / 2.0) / view_zoom
	view_zoom = clampf(z, 1.0, ZOOM_MAX)
	view_pan = before - (at - vs / 2.0) / view_zoom - center()
	_clamp_pan()


func _pan_by(screen_d: Vector2) -> void:
	view_pan -= screen_d / view_zoom
	_clamp_pan()


func _clamp_pan() -> void:
	var fv := full_view()
	var hs := get_viewport_rect().size / view_zoom / 2.0
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

	choice_box = HBoxContainer.new()
	choice_box.set_anchors_preset(Control.PRESET_CENTER)
	choice_box.position = Vector2(-440, -90)
	choice_box.size = Vector2(730, 180)
	choice_box.add_theme_constant_override("separation", 20)  # 정원 상점 4장은 166×4 + 20×3 = 724 (줄 폭 730)
	choice_box.alignment = BoxContainer.ALIGNMENT_CENTER  # 카드가 2장일 때도 가운데
	root.add_child(choice_box)

	legend = Label.new()
	legend.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	legend.position = Vector2(-330, 48)
	legend.size = Vector2(320, 380)
	legend_btn = Button.new()
	legend_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	legend_btn.position = Vector2(-160, 10)
	legend_btn.size = Vector2(150, 30)
	legend_btn.focus_mode = Control.FOCUS_NONE
	legend_btn.add_theme_font_size_override("font_size", 14)
	legend_btn.pressed.connect(_toggle_legend)
	root.add_child(legend_btn)
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
	root.add_child(reroll_btn)

	apply_btn = Button.new()
	apply_btn.text = "적용"
	apply_btn.focus_mode = Control.FOCUS_NONE
	apply_btn.add_theme_font_size_override("font_size", 17)
	# 카드 글 위에 걸치므로 꽉 찬 바탕 (다른 버튼처럼 옅으면 카드 글과 섞인다)
	for st in ["normal", "hover", "pressed"]:
		var asb := StyleBoxFlat.new()
		asb.bg_color = Color(1.0, 0.82, 0.4) if st == "normal" else Color(1.0, 0.9, 0.6)
		asb.set_corner_radius_all(6)
		apply_btn.add_theme_stylebox_override(st, asb)
	for fc in ["font_color", "font_hover_color", "font_pressed_color"]:
		apply_btn.add_theme_color_override(fc, Color(0.12, 0.09, 0.02))
	apply_btn.pressed.connect(func():
		if tap_sel >= 0 and tap_sel < offer.size():
			_on_pick(offer[tap_sel]))
	apply_btn.visible = false
	root.add_child(apply_btn)

	skip_btn = Button.new()
	skip_btn.set_anchors_preset(Control.PRESET_CENTER)
	skip_btn.tooltip_text = "고르기를 미루고 웨이브를 연달아 진행합니다. 미룬 카드·새로고침·특성은 멈춘 뒤 한꺼번에 고릅니다\n중앙이 위험해지면(설정) 그 웨이브가 끝나고 멈춥니다"
	skip_btn.pressed.connect(_on_skip)
	_icon_btn(skip_btn, func(): return ["skip", Color(0.75, 0.9, 1.0)])
	_keycap(skip_btn, "S")
	skip_btn.visible = false
	root.add_child(skip_btn)
	skip_n_btn = Button.new()
	skip_n_btn.set_anchors_preset(Control.PRESET_CENTER)
	skip_n_btn.tooltip_text = "넘길 웨이브 수 바꾸기 (1·3·5·10)"
	skip_n_btn.pressed.connect(_cycle_skip_n)
	skip_n_btn.visible = false
	root.add_child(skip_n_btn)
	skip_badge = Button.new()
	skip_badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip_badge.position = Vector2(-210, -146)  # 웨이브 시작 버튼 위
	skip_badge.size = Vector2(420, 36)
	skip_badge.add_theme_color_override("font_color", Color(0.75, 0.9, 1))
	skip_badge.pressed.connect(_toggle_skip_stop)
	skip_badge.visible = false
	root.add_child(skip_badge)

	hide_btn = Button.new()
	hide_btn.focus_mode = Control.FOCUS_NONE
	hide_btn.add_theme_font_size_override("font_size", 14)
	hide_btn.pressed.connect(func(): _set_cards_hidden(not cards_hidden))
	# 펼쳐 있을 때는 눈 그림만 (내려 두면 화면 위 "선택지 보기" 글)
	_icon_btn(hide_btn, func(): return ["none" if cards_hidden else "eye", Color(1, 1, 1, 0.85)])
	_keycap(hide_btn, func(): return "" if cards_hidden else "V")
	hide_btn.visible = false
	root.add_child(hide_btn)
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
	root.add_child(card_detail_btn)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# 버튼이 늘어나도 오른쪽 여백(16)을 지키고 왼쪽으로 자란다
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.offset_left = -616.0
	bar.offset_right = -16.0
	bar.offset_top = -50.0
	bar.offset_bottom = -14.0
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	bar_box = bar
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
	_icon_btn(auto_btn, func(): return ["auto", Color(0.5, 0.9, 0.6) if (garden_auto if Garden.on else auto_start) else Color(1, 1, 1, 0.35)])
	bar.add_child(auto_btn)
	pause_btn = Button.new()
	pause_btn.tooltip_text = "일시정지 (P)"
	pause_btn.custom_minimum_size = Vector2(44, 36)
	pause_btn.pressed.connect(_toggle_pause)
	_icon_btn(pause_btn, func(): return ["pause", Color(1, 1, 1, 0.9)])
	bar.add_child(pause_btn)
	speed_btn = Button.new()
	speed_btn.custom_minimum_size = Vector2(72, 36)
	speed_btn.pressed.connect(_toggle_speed)
	_icon_btn(speed_btn, func(): return ["speed", Color(1, 0.85, 0.45) if game_speed > 1.0 else Color(1, 1, 1, 0.9)])
	bar.add_child(speed_btn)
	speed_pick = OptionButton.new()
	for sp in SPEEDS:
		speed_pick.add_item("x%d" % roundi(sp))
	speed_pick.custom_minimum_size = Vector2(64, 36)
	speed_pick.focus_mode = Control.FOCUS_NONE
	speed_pick.tooltip_text = "빠르게 할 때 배속 (Space로 1배속과 오감)"
	speed_pick.item_selected.connect(_on_speed_pick)
	bar.add_child(speed_pick)
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
	# 정원: 환생·분재 (쉬는 시간에 다음 웨이브 버튼 위)
	rebirth_btn = Button.new()
	rebirth_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	rebirth_btn.position = Vector2(-250, -152)
	rebirth_btn.size = Vector2(240, 40)
	rebirth_btn.add_theme_font_size_override("font_size", 16)
	rebirth_btn.focus_mode = Control.FOCUS_NONE
	rebirth_btn.pressed.connect(_rebirth)
	rebirth_btn.visible = false
	bonsai_btn = Button.new()
	bonsai_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bonsai_btn.position = Vector2(10, -152)
	bonsai_btn.size = Vector2(240, 40)
	bonsai_btn.add_theme_font_size_override("font_size", 16)
	bonsai_btn.focus_mode = Control.FOCUS_NONE
	bonsai_btn.tooltip_text = "선택한 오브젝트(없으면 가장 많이 때린 것)를 분재로: 씨앗 나무 분재를 열면 일반 판을 이 오브젝트로 시작"
	bonsai_btn.pressed.connect(_set_bonsai)
	bonsai_btn.visible = false
	root.add_child(start_btn)
	root.add_child(rebirth_btn)
	root.add_child(bonsai_btn)
	cancel_btn = Button.new()
	cancel_btn.text = "취소 (Esc)" if OS.has_feature("pc") else "취소"
	cancel_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cancel_btn.position = Vector2(-70, -100)  # 웨이브 시작 버튼 자리 (옮기기·설치 중엔 비어 있다)
	cancel_btn.size = Vector2(140, 40)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(_cancel_step)
	cancel_btn.visible = false
	root.add_child(cancel_btn)
	draw_ok_btn = Button.new()
	draw_ok_btn.text = "확정"
	draw_ok_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	draw_ok_btn.position = Vector2(-70.0 + 150.0, -100.0)  # 취소 오른쪽
	draw_ok_btn.size = Vector2(140, 40)
	draw_ok_btn.add_theme_font_size_override("font_size", 18)
	draw_ok_btn.focus_mode = Control.FOCUS_NONE
	draw_ok_btn.pressed.connect(func():
		if phase == Phase.DRAW and draw_wait:
			draw_wait = false
			_draw_commit())
	draw_ok_btn.visible = false
	root.add_child(draw_ok_btn)
	detail_btn = Button.new()
	detail_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	detail_btn.position = Vector2(-70.0 - 130.0, -100.0)  # 취소 왼쪽
	detail_btn.size = Vector2(120, 40)
	detail_btn.add_theme_font_size_override("font_size", 18)
	detail_btn.focus_mode = Control.FOCUS_NONE
	detail_btn.pressed.connect(func():
		tip_detail = not tip_detail
		touch_tip_t = TOUCH_TIP_SEC * 3.0)  # 자세히는 읽을 게 많아 더 오래
	detail_btn.visible = false
	root.add_child(detail_btn)
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


## 쉬는 시간 왼쪽 위: 지난 웨이브 오브젝트별 DPS 표 (줄은 _refresh_dps가 채운다).
func _build_dps(root: Control) -> void:
	dps_panel = PanelContainer.new()
	dps_panel.position = Vector2(10, 60)
	dps_panel.custom_minimum_size.x = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.85)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(6)
	dps_panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	dps_panel.add_child(box)
	dps_head = Button.new()
	dps_head.flat = true
	dps_head.focus_mode = Control.FOCUS_NONE
	dps_head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	dps_head.add_theme_font_size_override("font_size", 14)
	dps_head.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	dps_head.pressed.connect(_toggle_dps)
	box.add_child(dps_head)
	dps_scroll = ScrollContainer.new()
	dps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(dps_scroll)
	dps_list = VBoxContainer.new()
	dps_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dps_list.add_theme_constant_override("separation", 2)
	dps_scroll.add_child(dps_list)
	dps_panel.visible = false
	root.add_child(dps_panel)


func _toggle_dps() -> void:
	dps_hidden = not dps_hidden
	dps_sig = ""


## 표를 보일지, 보이면 오브젝트·피해가 바뀌었을 때만 줄을 다시 만든다 (매 프레임 만들면 마우스 올림이 끊긴다).
func _refresh_dps() -> void:
	var on := phase in [Phase.CHOOSE, Phase.READY] and not title_label.visible and wave_time > 1.0 and towers.get_child_count() > 0 \
		and not get_tree().paused and not help_label.visible and not settings_panel.visible and not records_panel.visible and not notes_panel.visible and not modes_panel.visible
	dps_panel.visible = on
	if not on:
		dps_focus = null
		return
	# 표 밑에 오브젝트가 있으면(위쪽 끝에 놓은 것) 마우스를 표에 올리지 않은 동안 옅게 해서 보이게
	var pr := get_canvas_transform().affine_inverse() * dps_panel.get_global_rect()
	var under := false
	if not pr.has_point(get_global_mouse_position()):
		for t in towers.get_children():
			if pr.grow(14.0).has_point(t.position):
				under = true
				break
	dps_panel.modulate.a = 0.4 if under else 1.0
	# 점수 줄 아래, 왼쪽 아래 안내 글 위까지
	var top := hud.position.y + hud.size.y + 8.0 if hud.visible else 8.0
	if mp_bar.visible:
		top += mp_bar.size.y + 4.0  # 멀티플레이 상태 줄 아래로
	dps_panel.position.y = top
	var bottom := _bottom_free()
	if choice_box.visible and not cards_hidden and choice_box.get_child_count() > 0 and choice_box.get_rect().position.x < 320.0:
		bottom = minf(bottom, choice_box.get_rect().position.y - 24.0)  # 카드 왼쪽 끝·고르기 꼬리표를 덮지 않게 (넘치면 굴려 본다)
	if guide_label.visible and guide_label.get_rect().position.x < 320.0:
		bottom = minf(bottom, guide_label.position.y - 4.0)  # 처음 안내 글 위까지만
	var room := maxf(48.0, bottom - top - 44.0)
	var list := towers.get_children()
	list.sort_custom(func(a, b): return a.dealt > b.dealt)
	var sig := "%s|%d|%d" % [dps_hidden, roundi(room), roundi(wave_time)]
	for t in list:
		sig += "|%d:%s:%d" % [t.get_instance_id(), t.title(), roundi(t.dealt)]
	if sig == dps_sig:
		return
	dps_sig = sig
	dps_head.text = _kh(("▶" if dps_hidden else "▼") + " 지난 웨이브 DPS (D)")
	for c in dps_list.get_children():
		c.queue_free()
	dps_scroll.visible = not dps_hidden
	if dps_hidden:
		dps_focus = null
		dps_panel.size = Vector2.ZERO
		return
	var total := 0.0
	for t in list:
		total += t.dealt
	for i in list.size():
		dps_list.add_child(_dps_row(list[i], i + 1, total))
	var rows := list.size() * 24.0
	dps_scroll.custom_minimum_size.y = minf(rows, room)
	dps_panel.size = Vector2.ZERO  # 줄이 줄면 판도 줄인다
	if dps_focus != null and not is_instance_valid(dps_focus):
		dps_focus = null


## 표 한 줄: 순위 · 색 · 이름 · 초당 피해 · 몫. 뒤에 몫만큼 막대.
func _dps_row(t: Tower, rank: int, total: float) -> Control:
	var share := t.dealt / total if total > 0.0 else 0.0
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 22)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 6)
	var col := t.color()
	row.draw.connect(func():
		var hot := dps_focus == t
		row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(1, 1, 1, 0.14 if hot else 0.04))
		row.draw_rect(Rect2(Vector2.ZERO, Vector2(row.size.x * share, row.size.y)), Color(col, 0.28))
		if hot:
			row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(1, 0.9, 0.5, 0.9), false, 1.0))
	row.mouse_entered.connect(func():
		dps_focus = t
		for r in dps_list.get_children():
			r.queue_redraw())
	row.mouse_exited.connect(func():
		if dps_focus == t:
			dps_focus = null
		row.queue_redraw())
	var cells := [["%d" % rank, 18, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 1, 1, 0.55)],
		["", 0],
		["%.1f" % (t.dealt / wave_time), 52, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.9, 0.5)],
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
	row.tooltip_text = "%s\n지난 웨이브 피해 %d · 초당 %.1f · 전체의 %d%%" % [t.title(), roundi(t.dealt), t.dealt / wave_time, roundi(share * 100.0)]
	var b := t.breakdown()
	if t.dealt > 0.0 and not b.is_empty():
		row.tooltip_text += "\n\n피해 출처 (초당 · 이 오브젝트의 몫)"
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
	c.draw.connect(func():
		var y := c.size.y / 2.0
		Glyph.pat(c, t.pattern, Vector2(10, y), 8.0, col.lightened(0.5))
		var x := 22.0
		if t.plv > 1:
			c.draw_string(ui_font, Vector2(x, y + 4.0), str(t.plv), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
			x += 9.0
		x += 8.0
		for e in t.order:
			Glyph.elem(c, e, Vector2(x + 7.0, y), 7.0)
			x += 16.0
			if t.lv(e) > 1:
				c.draw_string(ui_font, Vector2(x, y + 4.0), str(t.lv(e)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
				x += 4.0 + 6.0 * str(t.lv(e)).length()
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


## 피해가 큰 출처 키 n개.
func _src_top(d: Dictionary, n: int) -> Array:
	var keys := d.keys()
	keys.sort_custom(func(a, b): return d[a] > d[b])
	return keys.slice(0, n)


## 피해 출처 키 → 보이는 이름 (elem:fire → 불, rx:lava → 용암).
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
		"trait":
			var j := Patch.ELEM_KEYS.find(p[1])
			return "형태 성질 " + (Elem.NAMES[Elem.ALL[j]] if j >= 0 else p[1])
		"etc":
			return {"crowd": "무리(오브젝트 수)", "perk": "특성"}.get(p[1], p[1])
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
	if pause_dim:
		# 일시정지 어둠은 안전 영역 밖까지 덮는다
		pause_dim.offset_left = -pad.position.x / s
		pause_dim.offset_top = -pad.position.y / s
		pause_dim.offset_right = pad.size.x / s
		pause_dim.offset_bottom = pad.size.y / s


## 안전 영역 밖 여백 (화면 좌표, position = 왼쪽·위, size = 오른쪽·아래). 폰·태블릿만.
func _safe_pad() -> Rect2:
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
func _fit_panels() -> void:
	for c: Control in [title_box, help_scroll, records_panel, settings_panel, notes_panel, modes_panel, codex_panel, vote_panel]:
		if not c.is_visible_in_tree():
			continue
		var h: float = c.get_combined_minimum_size().y if c == title_box else c.size.y
		# 글자 크기와 상관없이: 줄이 많으면 시작 화면 아래 버튼 줄·도움말·기록 창이 화면 밖으로 잘리던 것 (아래 구석 버전·소리 버튼 자리를 비운다)
		var k := minf(1.0, (ui_root.size.y - (110.0 if c == title_box else 100.0)) / maxf(1.0, h))
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2(k, k)


## 새 판을 시작할 때 모드가 바꾸는 시작 값 (중앙 체력). 봇이 모드를 바꾼 뒤에도 부른다.
func start_modes() -> void:
	core_max = Modes.core_max(CORE_MAX_HP)
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
	toast.text = t
	toast_timer = 2.0


## 점수·남은 구체만 바뀐 때는 0.1초에 한 번만 다시 쓴다. 글자 모양 계산이 비싸 고배속에서 프레임마다 쓰면
## 그것만으로 프레임당 몇 ms (8배속 부하 측정). 웨이브·중앙 체력 등이 바뀌면 바로.
func _update_hud(force := false) -> void:
	var urgent := "%d|%d|%d|%d|%d|%d|%d|%d|%d" % [wave, wave_dmg, core_hp, core_max, phase, towers.get_child_count(), selected.size(), perks.size(), int(Garden.dew) if Garden.on else 0]
	if not force and urgent == hud_urgent and hud_cool > 0.0:
		return
	hud_urgent = urgent
	hud_cool = 0.1
	var W := Color(1, 1, 1, 0.92)
	var D := Color(1, 1, 1, 0.6)
	var items: Array = []  # [아이콘, 아이콘 색, 글, 글 색, 말풍선 줄, 새 줄에서 시작?]
	items.append(["wave", Color(0.5, 0.78, 1.0), str(wave), W, [["웨이브", W]], false])
	if Garden.on:
		items.append(["score", Color(0.55, 1, 0.75), Garden.short(Garden.dew), Color(0.75, 1, 0.85), [["이슬 (상점에서 씀)", W], ["최근 초당 %.1f · 꺼 두면 그 절반" % Garden.rate, D]], false])
	else:
		items.append(["score", Color(1, 0.82, 0.35), num(score), W, [["점수", W]], false])
	var ct := "%d/%d" % [maxi(core_hp, 0), core_max] + ("  -%d" % wave_dmg if wave_dmg > 0 else "")
	var ctip := [["중앙 체력", W]]
	if wave_dmg > 0:
		ctip.append(["이번 웨이브 -%d" % wave_dmg, Color(1, 0.55, 0.55)])
	items.append(["core", Color(1, 0.55, 0.6) if core_hp * 3 <= core_max else W, ct, Color(1, 0.6, 0.6) if wave_dmg > 0 else W, ctip, false])
	if Garden.on:
		var sd := Garden.seeds_for(Garden.best)
		items.append(["best", Color(0.75, 1, 0.55, 0.8), "%d%s" % [Garden.best, "  씨앗 +%d" % sd if Garden.can_rebirth() else ""], D, [["이번 정원 최고 웨이브 %d" % Garden.best, W], ["환생: 최고 %d웨이브부터 (씨앗 = 최고 - %d)" % [Garden.REBIRTH_FROM, Garden.SEED_BASE], D]], false])
	else:
		items.append(["best", Color(1, 0.82, 0.35, 0.7), "%s · %d" % [num(best_score), best_wave], D, [["최고 기록: 점수 %s · 웨이브 %d" % [num(best_score), best_wave], W]], false])
	if Meta.rules != 1:
		items.append(["tag", D, Rules.NAMES[Meta.rules], D, [["규칙", W]], false])
	if not Modes.on.is_empty():
		items.append(["tag", Color(1, 0.7, 0.4), "x%.2f" % Modes.mul(), Color(1, 0.8, 0.55), [["모드 점수 배율 x%.2f" % Modes.mul(), W]], false])
	if Vary.on:
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
		var txt := Vary.ename(Vary.event) if not Vary.event.is_empty() else "봉인 %d" % Vary.count()
		if ad != "":
			txt += " · 적응"
		items.append(["tag", vc, txt, vc, vl, false])
	var nt := towers.get_child_count()
	if nt > 1:
		var cb := roundi(Rules.crowd_bonus(nt) * 100)
		items.append(["crowd", Color(0.6, 0.9, 0.65), "%d  +%d%%" % [nt, cb], Color(0.7, 0.95, 0.75), [["오브젝트 수 보너스: %d개, 피해 +%d%%" % [nt, cb], W]], false])
	if phase == Phase.WAVE:
		items.append(["orb", Color(0.85, 0.85, 0.9), str(to_spawn + _alive_count(orbs)), W, [["남은 구체", W]], false])
	# 다음 보스까지 남은 웨이브 (보스 웨이브 중이면 "지금")
	var bl := (ceili(wave / 5.0) * 5 - wave) if phase == Phase.WAVE else (ceili((wave + 1) / 5.0) * 5 - wave)
	if wave > 0 or phase != Phase.WAVE:
		var bt := "다음 웨이브 보스" if bl == 1 and phase != Phase.WAVE else ("이번 웨이브 보스" if bl == 0 else "보스까지 %d웨이브" % bl)
		items.append(["boss", Color(1, 0.6, 0.75), "!" if bl == 0 else str(bl), Color(1, 0.75, 0.85), [[bt, W]], false])
	if not selected.is_empty():
		items.append(["sel", Color(0.6, 1, 0.7), str(selected.size()), W, [["선택한 오브젝트", W]], false])
	var first := true
	for pk in PERKS:
		var n: int = perks.get(pk["id"], 0)
		if n > 0:
			items.append(["perk", Color(0.75, 0.7, 1.0), pk["name"] + (" x%d" % n if n > 1 else ""), D, [["특성 " + pk["name"] + (" x%d" % n if n > 1 else ""), W], [pk["desc"], D]], first])
			first = false
	# 오른쪽 위 버튼(설명 보기, 터치면 범위 보기) 앞까지. 글자를 키우면(설정) 화면이 좁아진 만큼 줄어든다
	var hud_w := ui_root.size.x - (300.0 if range_btn.visible else 190.0)
	var sig := str(hud_w)
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
	for it in items:
		var w := Icons.chip_w(ui_font, it[2], fs)
		if x > 0.0 and (it[5] or x + w > hud_w):
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
static func hp_growth(w: int) -> float:
	return 1.0 if w <= 10 else pow(Rules.hp_growth, w - 10)


## 저항 구체(12웨이브~, 버전 4는 8~): 웨이브마다 저항 속성 하나를 정하고 미리 알려 준다.
static func resist_share(w: int) -> float:
	var s := Rules.resist_from
	return 0.0 if w < s else minf(0.3 + 0.01 * (w - s), 0.6)


## 굳센 구체(15웨이브~, 버전 4는 11~): 밀기·감속·기절·냉기 절반.
static func sturdy_share(w: int) -> float:
	var s := Rules.sturdy_from
	return 0.0 if w < s else minf(0.15 + 0.01 * (w - s), 0.4)


## 고른 규칙 버전을 적용한다 (시작 화면에서 바꿀 때, 새 판마다).
func _apply_rules() -> void:
	Patch.commit()  # 받아 둔 온라인 패치는 새 판을 시작할 때 적용
	Rules.apply(Meta.rules)
	Modes.apply_rules()
	Vary.new_run(false)  # 판마다 다른 흐름: 일반 새 판에서만 켠다 (_on_rest_start), 이어하기는 저장에서
	Tower.tax_step = Rules.tax_step
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
	var mods := "강화는 종류마다 %d개까지" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "강화는 제한 없이 쌓이지만 쌓을수록 효과가 절반씩"
	var keys := [
		"[조작]",
		"1 / 2 / 3 또는 클릭: 선택지 고르기     Q: 선택지 새로고침     V: 선택지 내리고 필드 보기",
		"S: 웨이브 넘기기 — 고르기를 미루고 웨이브 n개(1·3·5·10)를 연달아 진행, 멈추면 쌓인 특성·카드·새로고침을 한꺼번에 (넘기는 중 S: 멈추기)",
		"속성 카드: 빈 곳에 설치(직선탄) → 클릭(또는 끌어서 놓기)으로 방향, Shift: 15도",
		"속성 카드를 오브젝트 위에: 속성 겹치기 (%s)" % elems,
		"공격방식·강화·연계 카드: 오브젝트 위에 놓기 (효과가 없는 강화는 못 넣음: 관통 연사·돌풍·철구에 관통·튕김, 벽에 유도, 벽·투척 장판에 분열)",
		"오브젝트 끌기: 방향은 그대로 두고 옮기기 (카드를 고른 뒤에는 꾹 눌러서)",
		"빈 곳 끌기 / Shift·Ctrl+클릭 / Ctrl+A(모두): 여러 개 선택 → 그중 하나를 끌면 함께 이동",
		"쉬는 시간에 오브젝트 클릭: 그 자리에서 방향 바꾸기 (우클릭한 채 끌면 한 번에)",
		"Alt 누르고 있기: 모든 오브젝트의 공격 범위·피해 비율 보기     우클릭 / Esc: 한 단계 되돌리기, 선택 해제",
		"쉬는 시간 왼쪽 위 DPS 표: 지난 웨이브에 오브젝트마다 낸 DPS와 비율. 줄에 마우스를 올리면 그 오브젝트를 짚어 줌   D: 표 접기·펴기",
		"Space: 웨이브 시작(자동 시작 끔일 때) / 웨이브 중 빠르게 켜기·끄기 (배율은 오른쪽 아래에서 x2~x8)",
		"P / Esc: 일시정지(시작 화면으로·끄기)   M: 소리   O: 설정   Tab: 설명 보기·숨기기   H: 도움말   K: 도감(시작 화면)   F11: 전체 화면",
		"R: 처음부터 (일시정지 중 두 번) · 게임 오버 뒤 클릭·R·Esc: 시작 화면",
		"E: 판 끝내기 (일시정지 중 두 번) — 지금 점수로 게임 오버, 기록·온라인 순위에 올라감",
		"쉬는 시간마다 자동 저장: 게임을 꺼도 시작 화면의 이어하기(Enter)로 그 쉬는 시간부터 (새로 시작은 N 두 번)",
		"첫 판은 카드가 단계별로 열려요 (공격방식 3·강화 4·연계 6웨이브)",
		"처음 생기는 일엔 위쪽에 한 줄 안내 (설정에서 끄기·처음부터 다시 보기)",
		"튜토리얼: 시작 화면 [튜토리얼]·일시정지에서 항목별로 다시 보기",
		"도감(시작 화면)에서 ☆로 선호 표시: 그 카드·반응이 선택지에 나오면 반짝여요",
	]
	# 폰·태블릿: 키보드·마우스 안내 대신 버튼·누르기로
	var touch := [
		"[조작 · 터치]",
		"카드 누르기: 선택지 고르기   [새로고침]: 선택지 바꾸기   [필드 보기]: 카드를 내리고 필드 보기",
		"[웨이브 n개 넘기기]: 고르기를 미루고 웨이브 n개(1·3·5·10)를 연달아 진행, 멈추면 쌓인 특성·카드·새로고침을 한꺼번에 (넘기는 중 아래 표시를 누르면 멈춤)",
		"속성 카드: 빈 곳을 눌러 설치(직선탄) → 쏠 쪽을 누르거나 끌어서 놓아 방향",
		"속성 카드를 오브젝트 위에: 속성 겹치기 (%s)" % elems,
		"공격방식·강화·연계 카드: 오브젝트를 눌러 넣기 (효과가 없는 강화는 못 넣음: 관통 연사·돌풍·철구에 관통·튕김, 벽에 유도, 벽·투척 장판에 분열)",
		"쉬는 시간에 오브젝트 누르기: 그 자리에서 쏠 방향 바꾸기   누른 채 끌기: 옮기기 (방향은 그대로)",
		"[취소]: 한 단계 되돌리기   [범위 보기]: 모든 오브젝트의 공격 범위·피해 비율",
		"쉬는 시간 왼쪽 위 DPS 표: 지난 웨이브에 오브젝트마다 낸 DPS와 비율. 제목을 누르면 접기·펴기",
		"오른쪽 아래 [◀ 설정]: 소리·자동 시작·일시정지(시작 화면으로·판 끝내기·처음부터)·배속(x2~x8)",
		"쉬는 시간마다 자동 저장: 게임을 꺼도 시작 화면의 [이어하기]로 그 쉬는 시간부터",
		"첫 판은 카드가 단계별로 열려요 (공격방식 3·강화 4·연계 6웨이브)",
		"처음 생기는 일엔 위쪽에 한 줄 안내 (설정에서 끄기·처음부터 다시 보기)",
		"튜토리얼: 시작 화면 [튜토리얼]·일시정지에서 항목별로 다시 보기",
		"도감(시작 화면)에서 ☆로 선호 표시: 그 카드·반응이 선택지에 나오면 반짝여요",
	]
	return "\n".join((touch if touch_ui else keys) + [
		"",
		"[규칙 · %s]" % Rules.NAMES[Rules.version],
		"중앙 체력 10. 구체가 닿으면 줄어듭니다",
		"쉬는 시간마다 3개 중 1개를 고릅니다 (처음 두 번은 2번)" if Rules.picks == 1 else "쉬는 시간마다 3개 중 1개씩 %d번 고릅니다" % Rules.picks,
		"5웨이브마다 보스. 처치하면 체력 +2, 새로고침 +1",
		"콤보: 게임 시간 3초 안에 다음 구체를 잡으면 이어져요 (어느 오브젝트가 잡든, 배속과 상관없이). 쉬는 시간엔 멈춰서 다음 웨이브로 이어져요. 콤보마다 처치 점수 +10%, 콤보 20부터 x3. 오른쪽 위 상자에 배율과 남은 시간",
		"보스 웨이브를 넘기면 특성(모든 오브젝트에 붙는 강화) 3개 중 1개 선택",
		"공격방식은 직선탄일 때 한 번만 정할 수 있고, 같은 것을 넣으면 레벨업",
		"속성을 많이 겹칠수록 피해는 늘고 공격 속도는 조금씩 느려집니다. 오브젝트가 많을수록 모든 오브젝트의 피해가 늘어요(오브젝트 수 보너스, 5개 +16%% · 10개 +23%%, 늘수록 덜 오름). %s" % mods,
		"감속은 최대 70%, 밀기는 조금씩만. 기절·속박·빙결은 연달아 걸릴수록 짧아지다가 잠깐 면역",
		"화면 밖 구체는 맞지 않습니다. 시작 화면에서 규칙(랭크·도파민 모드)%s과 맵%s을 바꿀 수 있어요" % (["", ""] if touch_ui else ["(↑/↓)", "(←/→)"]),
		"모드(첫 판 뒤): 어렵게 하면 점수 배율이 오르고, 쉽게 하면 내려가요 (쉽게 모드 판은 기록 따로)",
	])


## 실행 중인 빌드가 최신인지 알아보도록 구석에 표시 (버전은 project.godot의 config/version).
func _ver_text() -> String:
	return "빈두 v%s · 규칙 %s" % [ProjectSettings.get_setting("application/config/version", "?"), Rules.NAMES[Meta.rules]]


## 웨이브 구체 수: 3 + 2w. 첫 웨이브는 70%에서 시작해 10웨이브에 100%가 된다 (초반에 판이 끝나지 않게).
static func wave_size(w: int) -> int:
	return roundi((3 + w * 2) * lerpf(0.7, 1.0, clampf((w - 1) / 9.0, 0.0, 1.0)))


## 실제로 나오는 구체 수 (규칙 버전 배율, 십자로 맵 1.5배). 미리보기와 웨이브가 같은 값을 쓴다.
static var coop_orbs := 1.0  # 협동: 인원만큼 구체가 늘어난다 (2명 x1.6, 3명 x2.2, 4명 x2.8)


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
	if Garden.on:
		_garden_rest(new_round)
		return
	if new_round and wave == 0:
		# 새 판. 헤드리스(봇·점검)는 늘 모두 열린 채로
		tutor = Meta.tutor_next and DisplayServer.get_name() != "headless"
		tutor_given = {}
		start_modes()
		Vary.new_run(mp_mode == "" and not tutor)
		if Vary.on and Vary.count() > 0:
			_show_toast("이번 판 봉인 (시험): " + Vary.sealed_text())
		run_id = _new_run_id()
		Ach.new_run()
		_apply_tree()
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
	if mp_seed != 0:
		wrng.seed = hash([mp_seed, wave])  # 대결: 모두 같은 웨이브 (방향·저항·보스·구체)
	if mp_ghost:
		_mp_ghost_rest()  # 협동 참가자: 다음 웨이브는 호스트가 정한 것
	else:
		if wave > 0:
			for msg in Vary.rest(wave):
				_show_toast(msg)
		_roll_lanes()
		# 다음 웨이브 저항 속성: 12웨이브(버전 4는 8)부터 60% 확률
		wave_resist = _wpick(Elem.ALL) if wave + 1 >= Rules.resist_from and wf() < 0.6 else -1
		_plan_boss()
	_mp_rest_begin()
	picks_left = maxi(2, Rules.picks) if wave <= 1 else Rules.picks  # 처음 두 번의 쉬는 시간은 2개씩 (모드 '세 장'이면 3개)
	if wave == 0 and Garden.boosted and Garden.lv("leaf") >= 3:
		picks_left += 1  # 씨앗 나무 잎 3: 첫 쉬는 시간 고르기 +1
	rerolls_left = Modes.rerolls(1 + bonus_rerolls + perks.get("reroll", 0) * int(_perk_val("reroll")))
	bonus_rerolls = 0


# ---------- 웨이브 넘기기 ----------

## 넘기기를 쓸 수 있나: 오브젝트가 있고, 첫 판이면 카드 종류가 다 열린 뒤.
func _can_skip() -> bool:
	if mp_mode != "":
		return false  # 멀티플레이는 웨이브 넘기기 없음 (협동은 함께, 대결은 같은 웨이브 순서)
	if Garden.on:
		return false
	return towers.get_child_count() > 0 and not (tutor and wave + 1 < TUTOR_OPEN.values().max()) and skip_left == 0


## 선택지(또는 특성) 화면에서 넘기기: 이번 쉬는 시간의 고르기를 쌓아 두고 웨이브를 시작한다.
func _on_skip() -> void:
	if phase != Phase.CHOOSE or not _can_skip() or title_label.visible:
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
	_show_toast("웨이브 %d개 넘기기: 고르기는 멈춘 뒤 한꺼번에 (%s)" % [skip_total, "아래 표시를 누르면 멈춤" if touch_ui else "S: 멈추기"])


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
	var show_btn := phase == Phase.CHOOSE and not cards_hidden and not title_label.visible and _can_skip() and not get_tree().paused and coin_stage == 0
	skip_btn.visible = show_btn
	skip_n_btn.visible = show_btn
	# 글자를 키우면(폰 기본) 카드 아래 버튼 줄이 왼쪽 아래 안내 글까지 내려와 겹친다. 카드를 고르라는 글이라 겹칠 때만 숨긴다
	hint.visible = not (show_btn and hint.get_global_rect().intersects(skip_btn.get_global_rect()))
	if show_btn:
		var n := int(Meta.skip_n)
		skip_btn.tooltip_text = "웨이브 %d개 넘기기 (S)\n고르기를 미루고 웨이브를 연달아 진행합니다. 미룬 카드·새로고침·특성은 멈춘 뒤 한꺼번에 고릅니다\n중앙이 위험해지면(설정) 그 웨이브가 끝나고 멈춥니다" % n
		skip_n_btn.text = "×%d ▸" % n
	skip_badge.visible = skip_left > 0 and phase in [Phase.WAVE, Phase.READY] and not title_label.visible
	if skip_badge.visible:
		var done := skip_total - skip_left + 1
		var cards := bank_picks.size()
		var extra := " · 특성 %d" % bank_perks if bank_perks > 0 else ""
		if skip_stop:
			skip_badge.text = _kh("이번 웨이브 뒤 멈춤 · 쌓인 카드 %d%s (S: 계속)" % [cards, extra], true)
		elif phase == Phase.READY:
			skip_badge.text = _kh("넘기는 중 %d/%d · 쌓인 카드 %d%s (S: 지금 멈추고 고르기)" % [done, skip_total, cards, extra], true)
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
	var want := 4 if wave == 0 and Garden.boosted and Garden.lv("leaf") >= 2 else 3  # 씨앗 나무 잎 2: 첫 쉬는 시간 카드 4장
	while offer.size() < want and guard < 50:
		guard += 1
		var card := _roll_card()
		# 넣을 곳이 없는 공격방식·강화 카드는 내지 않는다
		if card["type"] in ["pat", "mod", "trig"] and not _my_towers().any(func(t): return t.can_take(card)):
			continue
		# 같은 속성은 레벨만 다르게 두 장 나오지 않게: 높은 레벨 한 장만 남긴다
		var same := offer.filter(func(cd): return _card_key(cd) == _card_key(card))
		if same.is_empty():
			offer.append(card)
		elif card.get("lv", 1) > same[0].get("lv", 1):
			offer[offer.find(same[0])] = card
	# 속성 카드(새 오브젝트를 놓을 수 있는 카드)는 최소 1장
	if not offer.any(func(cd): return cd["type"] == "elem"):
		offer[randi() % offer.size()] = {"type": "elem", "e": Vary.open("elem", Elem.ALL).pick_random(), "lv": 1}
	if tutor:
		_tutor_offer()
	_show_offer()
	_card_guides()


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
		"link": ids = ["pincer"] if towers.get_child_count() >= 2 else ["prism", "reso"]
		"trig": ids = Pat.TRIG_IDS.duplicate()
	ids.shuffle()
	for id in ids:
		var cd := {"type": k, "id": id}
		if k == "link" or towers.get_children().any(func(t): return t.can_take(cd)):
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
	tap_sel = -1
	for c in choice_box.get_children():
		c.queue_free()
	for i in offer.size():
		choice_box.add_child(_card_button(offer[i], i + 1))


## 같은 선택지인지 비교하는 키 (레벨은 무시).
func _card_key(card: Dictionary) -> String:
	return "%s:%s" % [card["type"], card.get("e", card.get("id", ""))]


## 선택지 한 장: 속성 / 공격방식 / 강화 / 연계 중 하나.
func _roll_card() -> Dictionary:
	var n := _my_towers().size()
	if n > 0 and wave > 0 and _card_open("pat") and _path_takers():
		# 그린 궤적: 카드당 0.7%, 이 판에 궤적이 있으면 1.2% (여러 번 나와야 쓸모 있는 공격)
		var has := _my_towers().any(func(t): return t.pattern == "path")
		if randf() < (Patch.num("cards", "path_again", Pat.PATH_CHANCE_AGAIN) if has else Patch.num("cards", "path", Pat.PATH_CHANCE)):
			return {"type": "pat", "id": "path"}
	var cata := Patch.num("cards", "cata", 0.01)
	if n > 0 and wave > 0 and _card_open("cata") and mp_mode != "coop":  # 협동: 친구 오브젝트까지 뒤섞여서 빼기
		# 대격변: 각각 1%
		var c := randf()
		if c < cata:
			return {"type": "cata", "id": "elem"}
		if c < cata * 2.0:
			return {"type": "cata", "id": "pat"}
	# 종류 비율 (온라인 패치 cards로 바뀔 수 있음): 속성 42%, 공격방식 25%, 강화 23%, 연계 10%, 발동 8% (합으로 나눔)
	var we := Patch.num("cards", "elem", 0.42)
	var wp := Patch.num("cards", "pat", 0.25) if _card_open("pat") else 0.0
	var wm := Patch.num("cards", "mod", 0.23) if _card_open("mod") else 0.0
	var wt := Patch.num("cards", "trig", 0.08) if _card_open("trig") else 0.0
	var r := randf() * (we + wp + wm + wt + (Patch.num("cards", "link", 0.10) if _card_open("link") else 0.0))
	if n == 0 or (wave == 0 and not Garden.on) or r < we:  # 정원은 웨이브 0으로 물러나도 다른 카드가 나오게
		var lv := 2 if randf() < _lv2_chance() else 1
		return {"type": "elem", "e": Vary.open("elem", Elem.ALL).pick_random(), "lv": lv}
	if r < we + wp:
		return {"type": "pat", "id": Vary.open("pat", Pat.PATTERN_IDS.slice(1)).pick_random()}
	if r < we + wp + wm:
		return {"type": "mod", "id": Pat.MOD_IDS.pick_random()}
	if r < we + wp + wm + wt:
		return {"type": "trig", "id": Pat.TRIG_IDS.pick_random()}
	var ids: Array = Pat.LINK_IDS.duplicate() if n >= 2 else ["prism", "reso"]
	ids = ids.filter(func(id): return not Vary.is_sealed("link", id))
	if ids.is_empty():
		return {"type": "elem", "e": Vary.open("elem", Elem.ALL).pick_random(), "lv": 1}
	return {"type": "link", "id": ids.pick_random()}


## 그린 궤적 카드를 넣을 오브젝트가 있는지 (궤적 레벨업, 또는 4개 미만일 때 직선탄).
func _path_takers() -> bool:
	return _my_towers().any(func(t): return t.can_pattern("path"))


func _card_color(card: Dictionary) -> Color:
	match card["type"]:
		"elem": return Elem.COLORS[card["e"]]
		"pat": return Pat.pcolor(card["id"]).lightened(0.15)
		"mod": return Color(1, 0.82, 0.4)
		"cata": return Color(1, 0.45, 0.9)
		"trig": return Pat.TRIG_COLOR
	return Color(0.55, 0.9, 1.0)


func _card_button(card: Dictionary, idx: int) -> Button:
	var col := _card_color(card)
	var b := Button.new()
	b.custom_minimum_size = Vector2(230 if offer.size() <= 3 else 166, 170)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.15, 0.96)
	sb.border_color = Color(col, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(0.16, 0.17, 0.22, 0.98)
	if card["type"] == "pat" and card["id"] == "path":
		sb.bg_color = Color(0.2, 0.16, 0.05, 0.97)
		sb.set_border_width_all(4)
		sb.border_color = col
		sbh.bg_color = Color(0.3, 0.24, 0.08, 0.98)
		sbh.set_border_width_all(4)
		sbh.border_color = col.lightened(0.3)
	if card["type"] == "cata":
		sb.bg_color = Color(0.2, 0.06, 0.2, 0.97)
		sb.set_border_width_all(4)
		sb.border_color = col
		sbh.bg_color = Color(0.3, 0.1, 0.3, 0.98)
		sbh.set_border_width_all(4)
		sbh.border_color = col.lightened(0.3)
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
	if cc["tip"] != "" and not Meta.card_detail:
		b.tooltip_text = cc["tip"]
	b.set_meta("full", _card_full(card))
	if Garden.on:
		var pr := _garden_price_text(card)
		rows.append({"t": pr[0], "fs": 13, "c": Color(0.6, 1, 0.75) if pr[1] else Color(1, 0.6, 0.55)})
		if not pr[1]:
			col = col.darkened(0.45)
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


func _draw_card_foot(b: Button, foot: Array, col: Color) -> void:
	var fs := 12
	var c := Color(col, 0.75)
	var w := 0.0
	while true:  # 좁은 카드(정원 상점 4장)에서 넘치면 글자를 줄인다
		w = 0.0
		for f in foot:
			w += 18.0 + ui_font.get_string_size(f[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		if w - 12.0 <= b.size.x - 10.0 or fs <= 9:
			break
		fs -= 1
	var x := (b.size.x - w + 12.0) / 2.0
	var y := b.size.y - 15.0
	b.draw_line(Vector2(14.0, y - 11.0), Vector2(b.size.x - 14.0, y - 11.0), Color(col, 0.2), 1.0)
	for f in foot:
		Icons.draw(b, f[0], Vector2(x + 7.0, y), 6.0, c)
		b.draw_string(ui_font, Vector2(x + 18.0, y + fs * 0.36), f[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		x += 18.0 + ui_font.get_string_size(f[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0


## 카드 앞면 내용 {head, rows, foot, tip}. lvl 0 = 간소화(효과 이름·괄호 뺀 한 줄), 1 = 자세히(전체 설명).
func _card_content(card: Dictionary, lvl: int) -> Dictionary:
	var head := {"kind": card["type"], "name": ""}
	var rows: Array = []
	var foot: Array = []
	var tip := ""
	var dim := Color(1, 1, 1, 0.55)
	match card["type"]:
		"cata":
			head["name"] = "대격변: " + ("속성" if card["id"] == "elem" else "공격방식")
			if card["id"] == "elem":
				rows = [{"t": "설치된 모든 오브젝트의 속성을 하나씩 무작위로 다시 뽑는다"}, {"t": "같은 속성이 나오면 레벨 +1"}]
			else:
				rows = [{"t": "모든 오브젝트의 공격방식을 직선탄을 뺀 무작위로 바꾼다"}, {"t": "고정·직선탄도 바뀜, 레벨 유지"}]
			rows.append({"t": "희귀 1% · 고르면 바로 발동", "fs": 12, "c": dim})
		"elem":
			var e: int = card["e"]
			head["name"] = Elem.NAMES[e]
			head["e"] = e
			if card["lv"] == 2:
				head["lv"] = "Lv2"
			rows = [{"i": "rider", "t": Elem.rider(e), "al": 0}, {"i": "trait", "t": Elem.TRAIT[e], "al": 0}]
			foot = [["place_new", "새 오브젝트"], ["place_on", "겹치기" + (" %d종" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "")]]
			var cf := _combo_parts(e)
			if not cf["els"].is_empty():
				rows.append({"els": cf["els"]})
				tip = "생길 반응: " + ", ".join(cf["names"])
			if cf["ups"] > 0:
				rows.append({"chip": "Lv↑ %d곳" % cf["ups"], "i": "place_on"})
		"pat":
			var id: String = card["id"]
			head["pat"] = id
			if id == "path":
				head["name"] = "그린 궤적"
				head["badge"] = "시험"
				rows = [{"t": "탄이 직접 그린 길을 따라간다"}, {"t": "길이 400→500→600, 그 뒤 갈래 +1"}, {"t": "꺾기 %d번 · 오브젝트 %d개까지" % [Pat.PATH_BENDS, Pat.PATH_MAX]}, {"t": "희귀 · 유도 못 넣음", "fs": 12, "c": dim}]
			else:
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
			rows = [{"t": Pat.mdesc(id)}]
			foot = [["place_on", "위에 놓기 · " + ("종류별 %d개" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "쌓을수록 절반")]]
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


## 간소화: 속성은 효과 이름 두 개(가시 · 자람)만, 나머지는 괄호를 뺀 짧은 설명. 짝 속성·레벨업 칩은 그대로.
func _card_simple(card: Dictionary, rows: Array) -> Array:
	var out: Array = []
	if card["type"] == "elem":
		var e: int = card["e"]
		out.append({"pair": [["rider", Elem.rider(e).get_slice(":", 0)], ["trait", (Elem.TRAIT[e] as String).get_slice(":", 0)]]})
		for r in rows:
			if r.has("els") or r.has("chip"):
				out.append(r)
		return out
	var first := true
	for r in rows:
		if not r.has("t"):
			out.append(r)
		elif r.has("fs"):
			if r.get("c", Color.WHITE) != Color(1, 1, 1, 0.55):
				out.append(r)  # "넣을 수 있는 오브젝트 없음" 같은 경고는 남긴다
		elif first:
			out.append({"t": _short(r["t"])})
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
			out.append(["추가 효과 · " + Elem.rider(e), Elem.COLORS[e].lightened(0.3)])
			out.append(["형태 성질 · " + Elem.TRAIT[e], W])
			var seen := {}
			for t in towers.get_children():
				if not t.can_take({"type": "elem", "e": e}):
					continue
				for r in Elem.new_reactions(t.elements, e):
					if seen.has(r["id"]):
						continue
					seen[r["id"]] = true
					var o: int = r["b"] if r["a"] == e else r["a"]
					out.append(["반응 %s (+%s) · %s" % [r["name"], Elem.NAMES[o], r["desc"]], r["color"]])
			var ups: int = _combo_parts(e)["ups"]
			if ups > 0:
				out.append(["%s 레벨업 가능 %d곳" % [Elem.NAMES[e], ups], D])
			out.append(["새 오브젝트로 놓거나 오브젝트 위에 겹치기" + (" (%d종까지)" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else " (종류마다 공격 속도 -%d%%)" % roundi(Rules.tax_step * 100)), D])
		"pat":
			var id: String = card["id"]
			if id == "path":
				out.append(["탄이 직접 그린 길을 따라간다. 길이 400→500→600, 그 뒤 갈래 +1", W])
				out.append(["꺾기 %d번 · 오브젝트 %d개까지 · 희귀 · 유도 못 넣음" % [Pat.PATH_BENDS, Pat.PATH_MAX], D])
			else:
				out.append([Pat.PATTERNS[id]["desc"], W])
				var no := Pat.no_mods(id)
				if not no.is_empty():
					out.append(["못 넣는 강화(효과 없음): " + "·".join(no), D])
			for t in towers.get_children():
				if t.pattern == id:
					out.append(["%s Lv%d → Lv%d 가능" % [Pat.pname(id), t.plv, t.plv + 1], D])
			out.append(["직선탄 오브젝트에 넣으면 그 공격방식으로 고정, 같은 공격방식에 넣으면 레벨업", D])
		"mod":
			out.append([Pat.mdesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기 · " + ("종류별 %d개까지" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "쌓을수록 효과 절반씩"), D])
		"link":
			out.append([Pat.ldesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기", D])
		"trig":
			out.append([Pat.tdesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기 · 종류별 5개까지", D])
		"cata":
			if card["id"] == "elem":
				out.append(["설치된 모든 오브젝트의 속성을 하나씩 무작위로 다시 뽑는다. 같은 속성이 나오면 레벨 +1", W])
			else:
				out.append(["모든 오브젝트의 공격방식을 직선탄을 뺀 무작위로 바꾼다. 고정·직선탄도 바뀌고 레벨은 유지", W])
			out.append(["희귀 1% · 고르면 바로 발동", D])
	return out


## [자세히]를 켠 채 카드에 올리면(터치는 한 번 눌러 미리보기) 카드 위에 모든 내용 창.
func _draw_card_full() -> void:
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
	var w := 420.0
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
	if y < top_lim:
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
	var cw := 230.0 if count <= 3 else 166.0  # 정원 상점·씨앗 나무 열매 특성은 4장
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
	b.custom_minimum_size = Vector2(cw, clampf(h + pad, 170.0, CARD_MAX_H))
	b.clip_contents = true
	b.set_meta("card", [head, lay, h, not foot.is_empty()])
	b.add_to_group("keycap")
	b.draw.connect(_draw_card.bind(b, col))
	if not foot.is_empty():
		b.draw.connect(_draw_card_foot.bind(b, foot, col))


func _draw_card(b: Button, col: Color) -> void:
	var m: Array = b.get_meta("card")
	var head: Dictionary = m[0]
	var hc := col.lightened(0.3) if b.is_hovered() else col
	Glyph.kind(b, head["kind"], Vector2(17, 17), 8.0, hc)
	if not touch_ui:
		Glyph.keycap(b, ui_font, Vector2(b.size.x - 7.0, 7.0), str(head["idx"]))
	# 이름 줄: [그림] 이름 [Lv 배지]
	var nfs := 19
	var nm: String = head["name"]
	while nfs > 13 and ui_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > 150.0:
		nfs -= 1
	var nw := ui_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var lv: String = head.get("lv", head.get("badge", ""))
	var lw := (ui_font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0) if lv != "" else 0.0
	var gw := 24.0 if head.has("e") or head.has("pat") else 0.0
	var x := (b.size.x - gw - nw - (lw + 6.0 if lv != "" else 0.0)) / 2.0
	var y := 40.0
	if head.has("e"):
		Glyph.elem(b, head["e"], Vector2(x + 9.0, y - 6.0), 9.0)
	elif head.has("pat"):
		Glyph.pat(b, head["pat"], Vector2(x + 9.0, y - 6.0), 9.0, hc)
	b.draw_string(ui_font, Vector2(x + gw, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, hc)
	if lv != "":
		Icons.chip(b, ui_font, Rect2(x + gw + nw + 6.0, y - 16.0, lw, 20.0), "", col, lv, Color.WHITE, 12, Color(col, 0.25), Color(col, 0.6))
	# 줄들: 머리와 놓는 곳 줄 사이 가운데
	var foot_h := 24.0 if m[3] else 8.0
	y = 52.0 + maxf(0.0, (b.size.y - 52.0 - foot_h - float(m[2])) / 2.0)
	var tc := Color(1, 1, 1, 0.88)
	for l in m[1]:
		var r: Dictionary = l[0]
		var f: int = l[2]
		if r.has("els"):
			var els: Array = r["els"]
			var n := mini(els.size(), 6)
			var x0 := (b.size.x - (n * 23.0 + 22.0 + (26.0 if els.size() > 6 else 0.0))) / 2.0
			Glyph.kind(b, "rx", Vector2(x0 + 9.0, y + 11.0), 7.0, col)
			for i in n:
				var c := Vector2(x0 + 34.0 + i * 23.0, y + 11.0)
				b.draw_circle(c, 9.5, Color(Elem.COLORS[els[i]], 0.2))
				Glyph.elem(b, els[i], c, 6.5)
			if els.size() > 6:
				b.draw_string(ui_font, Vector2(x0 + 28.0 + n * 23.0, y + 16.0), "+%d" % (els.size() - 6), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
		elif r.has("chip"):
			var tw := Icons.chip_w(ui_font, r["chip"], 12)
			Icons.chip(b, ui_font, Rect2((b.size.x - tw) / 2.0, y + 3.0, tw, 22.0), r.get("i", ""), col, r["chip"], Color(1, 1, 1, 0.85), 12, Color(col, 0.12), Color(col, 0.35))
		elif r.has("pair"):
			# [그림 이름] [그림 이름] 가운데 한 줄 (간소화한 속성 카드)
			var parts: Array = r["pair"]
			var pfs := 16
			var pw := 0.0
			while true:  # 좁은 카드(정원 상점 4장)에서 넘치면 글자를 줄인다
				pw = 0.0
				for it in parts:
					pw += 20.0 + ui_font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x + 16.0
				if pw - 16.0 <= b.size.x - 12.0 or pfs <= 11:
					break
				pfs -= 1
			if pw - 16.0 > b.size.x - 12.0:
				# 그래도 넘치면(긴 효과 이름) 칸마다 같은 폭으로 자르고 …
				var lim := (b.size.x - 12.0) / parts.size() - 36.0
				parts = parts.map(func(it):
					var t: String = it[1]
					while t.length() > 2 and ui_font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x > lim:
						t = t.substr(0, t.length() - 1)
					return [it[0], t + "…" if t != it[1] else t])
				pw = 0.0
				for it in parts:
					pw += 20.0 + ui_font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x + 16.0
			var px := (b.size.x - pw + 16.0) / 2.0
			for it in parts:
				Glyph.ui(b, it[0], Vector2(px + 7.0, y + 13.0), 7.0, Color(col, 0.9))
				b.draw_string(ui_font, Vector2(px + 20.0, y + 19.0), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, tc)
				px += 20.0 + ui_font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x + 16.0
		elif r.has("pips"):
			var n: int = r["pips"]
			for i in n:
				Glyph.kind(b, "perk", Vector2(b.size.x / 2.0 + (i - (n - 1) / 2.0) * 16.0, y + 10.0), 6.0, Color(col, 0.85))
		elif r.has("big"):
			var tw := ui_font.get_string_size(r["big"], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			var x0 := (b.size.x - tw - 34.0) / 2.0
			Glyph.ui(b, r["i"], Vector2(x0 + 12.0, y + 22.0), 12.0, Color.WHITE)
			b.draw_string(ui_font, Vector2(x0 + 34.0, y + 31.0), r["big"], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		else:
			var c: Color = r.get("c", tc)
			if r.has("i"):
				Glyph.ui(b, r["i"], Vector2(19.0, y + f * 0.7), 6.5, Color(col, 0.9))
				b.draw_multiline_string(ui_font, Vector2(32.0, y + f), l[1], HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 44.0, f, -1, c)
			else:
				b.draw_multiline_string(ui_font, Vector2(12.0, y + f), l[1], HORIZONTAL_ALIGNMENT_CENTER, b.size.x - 24.0, f, -1, c)
		y += float(l[3])


## 도감에서 선호한 카드면 꼬리표 글: 카드 자체, 또는 속성 카드가 선호한 반응을 지금 오브젝트에 만들 수 있을 때. 아니면 "".
func _fav_tag(card: Dictionary) -> String:
	if Meta.favs.has(Codex.card_key(card)):
		return "★ 선호"
	if card["type"] == "elem":
		for t in towers.get_children():
			if not t.can_take(card):
				continue
			for r in Elem.new_reactions(t.elements, card["e"]):
				if Meta.favs.has("react:" + str(r["id"])):
					return "★ 선호 반응: " + str(r["name"])
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
	if Garden.on:
		return "상점: 카드를 사서 놓아요 (빈 곳: 새 오브젝트 · 오브젝트 위: 겹치기·넣기). 끌기: 옮기기"
	if Meta.games >= 3:
		return ""
	# 선택지 내리기(V)는 카드 아래 버튼에 적혀 있다
	if touch_ui:
		return "카드를 한 번 누르면 미리보기, 한 번 더 누르거나 [적용]으로 고르기. 설치된 오브젝트 누르기: 방향 바꾸기 · 끌기: 옮기기"
	return "선택지를 고르세요. 설치된 오브젝트 클릭: 방향 바꾸기 · 끌기: 옮기기"


# ---------- 튜토리얼 ----------

## 판에서 처음 생긴 일(_guide id 등) → 그 튜토리얼 항목을 이 기기에서 아직 안 봤으면 띄울 줄에 넣는다.
## 안내 끄기(설정)를 따르고, 멀티 판(멈출 수 없음)·정원(지켜보는 판)에서는 띄우지 않는다.
func _tut_event(id: String) -> void:
	var tp: String = Tutorial.ON_EVENT.get(id, "")
	if tp == "" or not Meta.guide_on or mp_mode != "" or Garden.on or Tutorial.seen.has(tp) or tut_queue.has(tp):
		return
	tut_queue.append(tp)


## 띄울 때가 되면 띄운다: 처음 켠 기기는 시작 화면에서 기본 항목, 판에서 생긴 항목은 쉬는 시간(카드 고르기)이나 시작 화면에서.
func _tut_tick() -> void:
	if tut.visible or DisplayServer.get_name() == "headless":
		return
	var panels := settings_panel.visible or records_panel.visible or help_label.visible or notes_panel.visible or modes_panel.visible or codex_panel.visible or vote_panel.visible or mp_panel.visible or tree_panel.visible
	if panels:
		return
	if tut_first:
		if title_label.visible:
			tut_first = false
			_open_tut(Tutorial.FIRST, true)
		return
	if tut_queue.is_empty():
		return
	var ok := title_label.visible or (phase == Phase.CHOOSE and not get_tree().paused and coin_stage == 0 and skip_left == 0 and mp_mode == "")
	if not ok:
		return
	var ids: Array = tut_queue.filter(func(x): return not Tutorial.seen.has(x))
	tut_queue.clear()
	if ids.is_empty():
		return
	if not title_label.visible:
		get_tree().paused = true  # 고르는 동안은 시간이 안 가지만 자동 시작·배속 등이 돌지 않게
		tut_paused = true
	_open_tut(ids)


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


# ---------- 처음 안내 ----------

## 처음 생기는 일에 한 줄 안내. 안내마다 한 번만(Meta.guide_seen), 설정에서 끌 수 있다.
## 쉬는 시간 안내는 웨이브가 시작될 때까지, 웨이브 중 안내는 8초 보인다(쉬는 시간 안내가 붙으면 함께 남음). 많아야 3개.
func _guide(id: String, text: String) -> void:
	_tut_event(id)
	if not Meta.guide_on or Meta.guide_seen.has(id) or title_label.visible:
		return
	var first := Meta.guide_seen.is_empty()
	Meta.guide_seen[id] = true
	_save_best()
	guide_lines.append(text)
	if first:
		guide_lines.append(_kh("이런 안내는 처음 한 번만 나와요. 설정(O)에서 끌 수 있어요"))
	while guide_lines.size() > 3:
		guide_lines.pop_front()
	guide_t = 8.0 if phase == Phase.WAVE else -1.0
	var out := PackedStringArray()
	for g in guide_lines:
		out.append(_wrap_words(g, 570.0, 16))
	guide_label.text = "\n".join(out)
	guide_label.reset_size()


## 쉬는 시간이 열릴 때: 길목·겹치기·보스·저항·굳센 구체 안내.
func _rest_guides() -> void:
	if wave == 0:
		_guide("start", "빨간 화살표가 구체가 들어오는 길목이에요. 속성 카드를 고른 뒤 길목 쪽 빈 곳을 눌러 놓고, 한 번 더 눌러 쏠 방향을 정하세요")
	elif towers.get_child_count() > 0:
		_guide("stack", "속성 카드를 오브젝트 위에 놓으면 겹쳐져요. 같은 속성은 레벨업, 다른 속성은 추가 효과가 더해지고, 맞는 두 속성이 만나면 특수 반응이 생겨요")
	if not boss_plan.is_empty() and boss_plan["wave"] == wave + 1:
		_guide("boss", "다음 웨이브 끝에 보스가 와요. 분홍 선이 실제로 지나갈 길이에요. 중앙에 닿으면 3 피해, 웨이브를 넘기면 특성을 하나 골라요")
	if wave_resist >= 0:
		_guide("resist", "저항 구체(점선 고리)가 섞여 와요. 다음 웨이브는 %s 속성 피해를 덜 받으니 다른 속성 오브젝트도 길목에 두세요" % Elem.NAMES[wave_resist])
	if wave + 1 >= Rules.sturdy_from:
		_guide("sturdy", "굳센 구체(회색 쐐기)가 섞여 와요. 밀기·감속·기절·냉기가 절반만 들으니 피해로 잡아야 해요")


## 선택지에 처음 나온 카드 종류 안내.
func _card_guides() -> void:
	var types := offer.map(func(cd): return cd["type"])
	if "pat" in types:
		_guide("pat", "새 카드 · 공격방식: 직선탄 오브젝트에 넣으면 공격 모양이 바뀌고 그 뒤로 고정돼요. 같은 공격방식을 넣으면 레벨업")
	if "mod" in types:
		var cap := "같은 강화는 %d개까지 쌓여요" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "쌓을수록 효과가 절반씩 줄어요"
		_guide("mod", "새 카드 · 강화: 오브젝트 위에 놓아 공격을 바꿔요(빠르게·크게·관통 등). " + cap)
	if "link" in types:
		_guide("link", "새 카드 · 연계: 오브젝트 위에 놓아 주변과 함께 싸워요. 협공은 여러 오브젝트가 같이 맞힌 구체를 터뜨려요")
	if "trig" in types:
		_guide("trig", "새 카드 · 발동: 오브젝트 위에 놓으면 조건이 맞을 때 공격이 더 나가요. 여진은 잡은 자리에서 탄이 터지고, 선봉은 웨이브 첫 타격부터 빨라져요")


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
	var winds := ts.filter(func(w): return w.lv(Elem.WIND) > 0 and not w.is_queued_for_deletion())
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
	var pool: Array = PERKS.duplicate()
	if Modes.has("narrow"):
		pool = pool.filter(func(pk): return not pk["id"] in ["reroll", "coin"])  # 외길: 새로고침이 없으니 쓸모없는 특성은 빼고 (동전 뒷면도 새로고침)
	if coin_next != "":
		pool = pool.filter(func(pk): return pk["id"] != "coin")  # 던진 동전의 결과를 받을 차례
	# 더 골라도 거의 효과가 없는 특성은 빼고: 이미 거의 Lv2로 나오는 행운, 두 번 고른 조화(공속 감소 10% → 2.5%)
	pool = pool.filter(func(pk): return not (pk["id"] == "luck" and _lv2_chance() >= 0.9 or pk["id"] == "harmony" and perks.get("harmony", 0) >= 2))
	pool.shuffle()
	perk_offer = pool.slice(0, 4 if Garden.boosted and Garden.lv("fruit") >= 1 else 3)  # 씨앗 나무 열매 1: 특성 선택지 4개
	_show_perks()
	if coin_next == "":
		big_banner("특성 선택", Color(1, 0.85, 0.45))
	_save_run()


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
			b.tooltip_text = desc
		if have > 0:
			rows.append({"pips": mini(have, 8)})
		if coin != "":
			rows.append({"t": coin, "fs": 13, "c": Color(1, 0.85, 0.45)})
		_card_paint(b, {"kind": "perk", "name": pk["name"], "idx": i + 1}, rows, [], Color(1, 0.85, 0.45), 16, perk_offer.size())
		b.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
		b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_perk.bind(pk))
		_mark_fav(b, sb, sbh, "★ 선호" if Meta.favs.has("perk:" + str(pk["id"])) else "")
		choice_box.add_child(b)
	cards_hidden = false
	choice_box.visible = true
	reroll_btn.visible = false
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
	if not Garden.on:
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
		"harmony": Tower.tax_step *= _perk_val("harmony")


## 특성 수치 (온라인 패치 perks로 바뀔 수 있음). 설명 글도 같이 바꿔야 하면 perk_desc. coin: 동전 뒷면 새로고침 수
const PERK_VALS := {"power": 0.15, "haste": 0.12, "reach": 0.12, "core": 3, "reroll": 1, "luck": 0.2, "regen": 1, "regen_more": 0.5, "slow": 0.08, "harmony": 0.5, "coin": 2}


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
	if phase != Phase.CHOOSE:
		return
	if Garden.on:
		if perk_mode or not _garden_pay(Garden.REROLL_COST):
			return
		_garden_fill()
		_show_offer()
		_save_run()
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


## 새로고침 버튼: 남은 횟수를 같이 보여 준다.
## 선택지 내리기·올리기 (V): 카드에 가려진 필드를 본다. 마우스를 올린 오브젝트 범위·정보는 그대로 보인다.
func _set_cards_hidden(h: bool) -> void:
	if phase != Phase.CHOOSE:
		return
	cards_hidden = h
	choice_box.visible = not h
	hover_elem = -1
	_tap_hover()  # 다시 올리면 터치로 고르던 카드 미리보기도 다시
	if perk_mode:
		reroll_btn.visible = false
	else:
		_update_reroll_btn()


func _update_reroll_btn() -> void:
	if Garden.on:
		reroll_btn.visible = not cards_hidden and not perk_mode
		reroll_btn.text = "%d이슬" % Garden.REROLL_COST
		reroll_btn.tooltip_text = "상점 카드 새로 뽑기 (Q): %d이슬" % Garden.REROLL_COST
		return
	reroll_btn.visible = rerolls_left > 0 and not cards_hidden  # 모드 '외길'은 늘 0
	reroll_btn.text = str(rerolls_left)
	reroll_btn.tooltip_text = "선택지 새로고침 (Q): 이번 쉬는 시간에 %d번 남음" % rerolls_left


## 진입 방향은 웨이브마다 조금씩 늘고, 가끔 하나가 옮겨 간다.
func _roll_lanes() -> void:
	var n := lanes_for(wave + 1)
	if Meta.map_id == "line":
		# 회랑: 한쪽 끝 하나 (각도는 중앙 점에서 구체가 오는 쪽)
		lanes = [PI if Meta.line_flip else 0.0]
		return
	if Garden.on:
		# 정원: 방향이 옮겨 가지 않는다 (꺼 두고 맡겨도 되게). 늘어날 때마다 육각형 자리를 하나씩 채운다
		var r0: float = lanes[0] if not lanes.is_empty() else randf() * TAU
		lanes.clear()
		for i in n:
			lanes.append(r0 + Garden.LANE_ORDER[i])
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
		for l in _boss_text().split("\n"):
			info_l.append([l, Color(1, 0.75, 0.85)])
	else:
		var bw := ceili(nw / 5.0) * 5
		info_l.append(["다음 보스: 웨이브 %d (%d웨이브 뒤)" % [bw, bw - wave], Color(1, 0.75, 0.85)])
	if Vary.on:
		var vc := Color(0.75, 0.85, 1.0)
		if not Vary.event.is_empty():
			info_l.append(["이벤트 %s: %s" % [Vary.ename(Vary.event), Vary.edesc(Vary.event)], vc])
		if not Vary.next_event.is_empty():
			info_l.append(["웨이브 %d 뒤 이벤트 %s: %s" % [nw, Vary.ename(Vary.next_event), Vary.edesc(Vary.next_event)], vc])
		if Vary.count() > 0:
			info_l.append(["봉인 (시험): " + Vary.sealed_text(), vc])
		var ad := Vary.adapt_text()
		if ad != "":
			info_l.append(["적응 구체 (많이 쓴 것에 저항): " + ad, vc])
	wave_info = info_l
	wave_kinds = kinds
	if wave == 0:
		_guide("lanes", "빨간 화살표 쪽에서 구체가 와요. 옆 숫자는 그쪽에서 오는 구체 수(%s 자세히). 길목을 가로지르게 설치하세요" % ("누르면" if touch_ui else "올리면"))


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
	if is_inside_tree() and get_tree().current_scene != null:
		get_tree().reload_current_scene()


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
func _beside_legend(c: Control, min_w: float) -> void:
	var w := maxf(min_w, c.get_combined_minimum_size().x)
	var x := (ui_root.size.x - w) / 2.0
	if legend.visible:
		x = minf(x, legend.get_rect().position.x - 8.0 - w)
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


## 화면 위 아이콘 층: 진입 화살표 옆 구체 수 배지, 놓친 구체, 남은 고르기, 칩·배지에 올리면 뜨는 말풍선.
func _draw_info() -> void:
	tip_rects.clear()
	var size := info.size
	var top := hud.position.y + hud.size.y + 6.0 if hud.visible else 8.0
	var lo := size.y - 64.0
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
		var compact := _phone()
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
			r.position = r.position.clamp(Vector2(8.0, top), Vector2(size.x - w - 8.0, lo - 30.0))
			r = _off_legend(r)
			badges.append(r)
			# 카드 위에 걸친 배지는 그리지 않는다 (옅게 그려도 카드 글을 가렸고, 마우스를 올리면 말풍선이 카드를 덮었다). 카드를 내리면(V) 보인다
			if cards_r.has_area() and r.intersects(cards_r):
				continue
			var al := 1.0
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.16, 0.04, 0.06, 0.88 * al)
			sb.border_color = Color(1, 0.35, 0.4, 0.9 * al)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(7)
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
			r = _off_legend(r)
			for br in badges:
				if r.intersects(br.grow(4.0)):
					r.position = Vector2(br.position.x, br.end.y + 6.0)  # 같은 방향 배지 바로 아래
			if cards_r.has_area() and r.intersects(cards_r):
				continue
			var la := 1.0
			Icons.chip(info, ui_font, r, "orb", Color(0.85, 0.85, 0.9, la), txt, Color(1, 0.5, 0.5, la), 16, Color(0.1, 0.02, 0.03, 0.85 * la), Color(1, 0.4, 0.4, 0.6 * la))
			tip_rects.append([r, [["지난 웨이브에 이쪽에서 놓친 구체 %d개" % lm[1], Color(1, 0.6, 0.6)], [_leak_text(), Color(1, 1, 1, 0.7)]]])
	# 남은 고르기: 카드 줄 왼쪽 위 모서리에 걸친 꼬리표
	if phase == Phase.CHOOSE and not perk_mode and choice_box.visible and not cards_hidden and choice_box.get_child_count() > 0 and not get_tree().paused and not Garden.on:
		var cb := ui_root.get_global_transform().affine_inverse() * choice_box.get_global_rect()
		var first: Control = choice_box.get_child(0)
		var fx := (ui_root.get_global_transform().affine_inverse() * first.get_global_rect()).position.x
		var txt := "고르기 %d" % picks_left
		var w := Icons.chip_w(ui_font, txt, 15, false)
		var r := Rect2(fx + 10.0, cb.position.y - 21.0, w, 24.0)
		Icons.chip(info, ui_font, r, "", Color.WHITE, txt, Color(1, 0.88, 0.5), 15, Color(0.12, 0.1, 0.04, 0.97), Color(1, 0.82, 0.4, 0.8))
		tip_rects.append([r, [["이번 쉬는 시간에 %d장 더 고를 수 있어요" % picks_left, Color(1, 0.9, 0.6)]]])
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
	return L / (boss_plan["spd"] * 0.45 * orb_speed_mul * Modes.speed())


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
## 바람 오브젝트에 마우스를 올렸을 때(그 둘레), 버프 받는 오브젝트에 올렸을 때(버프를 주는 둘레),
## 오브젝트를 옮기는 중일 때(모든 둘레)만 그린다.
func _draw_wind_rings() -> void:
	if title_label.visible or phase == Phase.GAMEOVER:
		return
	var winds := towers.get_children().filter(func(t): return t.lv(Elem.WIND) > 0)
	if winds.is_empty():
		return
	var show: Array = []
	if moving != null or dragging or phase in [Phase.PLACE, Phase.MOVE]:
		show = winds
	else:
		var h := _tower_at(get_global_mouse_position())
		if h != null:
			for w in winds:
				if w == h or w.position.distance_to(h.position) <= w.wind_range():
					show.append(w)
	var sp := fmod(Time.get_ticks_msec() / 1000.0 * 0.5, 1.0)
	var wc: Color = Elem.COLORS[Elem.WIND]
	for w in show:
		draw_arc(w.position, w.wind_range(), sp * TAU, sp * TAU + TAU * 0.85, 48, Color(wc, 0.35), 1.5)


## 보스가 올 길: 쉬는 시간과, 보스 웨이브에서 보스가 나오기 전까지.
func _draw_boss_path(now: float) -> void:
	if boss_plan.is_empty() or title_label.visible or phase == Phase.GAMEOVER:
		return
	if phase == Phase.WAVE and boss_plan["wave"] != wave:
		return
	var col := Color(1, 0.35, 0.6)
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
		return
	var pulse := 0.75 + 0.25 * sin(now * 3.0)
	draw_polyline(pts, Color(col, 0.6 * pulse), 2.5)
	# 보스가 오는 쪽으로 흐르는 화살 (길이 비율로 놓는다)
	var lens: Array[float] = [0.0]
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i - 1].distance_to(pts[i]))
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
	# 들어오는 자리: 큰 고리 + 글자. 가장자리의 버튼·점수 줄에 가리지 않게 길을 따라 안쪽(110)에
	var at := minf(110.0, total * 0.4)
	var j2 := 1
	while j2 < pts.size() - 1 and lens[j2] < at:
		j2 += 1
	var d2 := (pts[j2] - pts[j2 - 1]).normalized()
	var m := pts[j2 - 1] + d2 * (at - lens[j2 - 1])
	draw_arc(m, 20.0 + 3.0 * sin(now * 5.0), 0, TAU, 32, Color(col, 0.95), 3.0)
	draw_circle(m, 9.0, Color(col, 0.9))
	var label := "보스 · 웨이브 %d" % boss_plan["wave"]
	var fs := 16
	var w := ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# 길 옆에 쓴다 (길 위에 쓰면 화살과 겹침): 중앙에서 먼 쪽 옆
	var side := d2.orthogonal()
	if side.dot(m - core()) < 0.0:
		side = -side
	var lp := m + side * 30.0 + Vector2(-w / 2.0 if absf(side.x) < 0.5 else (0.0 if side.x > 0.0 else -w), 6.0)
	lp = lp.clamp(Vector2(8, 70), vr.size - Vector2(w + 8, 70))
	draw_string_outline(ui_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(ui_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.75, 0.85))


## 폰 [적용] 버튼: 미리보기 중인 카드 오른쪽 위 모서리에 걸친다 (왼쪽 위는 고르기 꼬리표, 카드 아래는 새로고침 줄)
func _place_apply_btn() -> void:
	var cs := choice_box.get_children() if choice_box else []
	var on := touch_ui and phase == Phase.CHOOSE and not perk_mode and choice_box.visible and not cards_hidden \
		and tap_sel >= 0 and tap_sel < cs.size() and not cs[tap_sel].is_queued_for_deletion() and not get_tree().paused
	apply_btn.visible = on
	if not on:
		return
	var r: Rect2 = ui_root.get_global_transform().affine_inverse() * cs[tap_sel].get_global_rect()
	var w := minf(120.0, r.size.x * 0.5)
	apply_btn.size = Vector2(w, 34.0)
	apply_btn.position = Vector2(r.end.x - w - 10.0, maxf(r.position.y - 36.0, 0.0))  # 카드 위: 글 첫 줄을 덮지 않게


## 카드 누르기. 마우스는 바로 고르고(올리면 미리보기), 터치는 한 번 누르면 미리보기(다른 카드는 옅게, 아래에 [적용]),
## 같은 카드를 한 번 더 누르거나 [적용]을 누르면 고른다.
func _on_card_tap(card: Dictionary, i: int) -> void:
	if not touch_ui or tap_sel == i:
		_on_pick(card)
		return
	tap_sel = i
	_tap_hover()


## 터치로 고른(미리보기 중인) 카드의 속성 미리보기와 카드 진하기.
func _tap_hover() -> void:
	if tap_sel >= 0 and tap_sel < offer.size() and not cards_hidden:
		hover_elem = offer[tap_sel]["e"] if offer[tap_sel]["type"] == "elem" else -1
	var cs := choice_box.get_children()
	for k in cs.size():
		cs[k].modulate.a = 0.55 if tap_sel >= 0 and k != tap_sel else 1.0


func _on_pick(card: Dictionary) -> void:
	tap_sel = -1
	_tap_hover()
	if card["type"] == "cata":
		_cataclysm(card["id"])
		return
	picked = card
	hover_elem = -1
	choice_box.visible = false
	reroll_btn.visible = false
	phase = Phase.PLACE
	hint.text = _th(_place_hint())


## 대격변: 고르는 즉시 모든 오브젝트에 발동.
func _cataclysm(id: String) -> void:
	hover_elem = -1
	choice_box.visible = false
	reroll_btn.visible = false
	var ts := towers.get_children()
	for t in ts:
		if id == "elem":
			t.cataclysm_elements()
		else:
			t.cataclysm_pattern()
		t.eff = t.eff_now()
		burst(t.position, Color(1, 0.45, 0.9), 16, 220.0)
	shake = maxf(shake, 2.0)
	sfx.play("boss")
	big_banner("대격변! " + ("속성이 뒤섞였다" if id == "elem" else "공격방식이 뒤섞였다"), Color(1, 0.45, 0.9))
	_after_place({"type": "cata", "id": id})


## 통계용 카드 이름: elem:fire, pat:spray, mod:rapid, link:prism, cata:elem
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
	return "넣을 오브젝트를 클릭   꾹 누르기·끌기: 옮기기\n우클릭/Esc: 다시 고르기"


## card: 이번에 넣은 카드 (대격변은 picked를 거치지 않아 따로 넘긴다).
func _after_place(card: Dictionary = {}) -> void:
	if Garden.on:
		_garden_bought()
		return
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
	if phase == Phase.READY or (Garden.on and phase == Phase.CHOOSE and not perk_mode):
		_start_wave()


## 버튼 위에 아이콘을 그린다. 글이 있으면 왼쪽, 없으면 가운데. icon은 [아이콘, 색]을 돌려준다.
func _icon_btn(b: Button, icon: Callable) -> void:
	b.draw.connect(func():
		var ic: Array = icon.call()
		var x := b.size.x / 2.0
		if b.text != "":
			# 가운데 맞춘 글 바로 왼쪽
			var tw := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			x = (b.size.x - tw) / 2.0 - 13.0
		Glyph.ui(b, ic[0], Vector2(x, b.size.y / 2.0), 8.5, ic[1]))


## 버튼 오른쪽 위 모서리에 작은 단축키 상자 (터치 화면에선 안 그림). key는 글 또는 글을 돌려주는 Callable.
func _keycap(b: Button, key: Variant) -> void:
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
	sfx.muted = not sfx.muted
	mute_btn.tooltip_text = "소리: " + ("끔" if sfx.muted else "켬") + " (M)"
	mute_btn.queue_redraw()
	_save_best()


func _toggle_auto() -> void:
	if Garden.on:
		garden_auto = not garden_auto
		garden_cd = Garden.NEXT_DELAY if garden_auto else -1.0
		_update_auto_btn()
		_save_best()
		_show_toast("정원 자동 진행: " + ("켬" if garden_auto else "끔 (Space로 다음 웨이브)"))
		return
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


func _toggle_bar() -> void:
	bar_open = not bar_open
	_save_best()


func _update_auto_btn() -> void:
	if Garden.on:
		auto_btn.tooltip_text = "정원 자동 진행: " + ("켬" if garden_auto else "끔") + " (쉬는 시간 %d초 뒤 다음 웨이브)" % int(Garden.NEXT_DELAY)
		auto_btn.queue_redraw()
		return
	auto_btn.tooltip_text = "자동 시작: " + ("켬" if auto_start else "끔") + " (웨이브가 끝나고 고르기를 마치면 바로 다음 웨이브)"
	auto_btn.queue_redraw()


func _start_wave() -> void:
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
	mp_next_extra = 0
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
	if guide_t < 0.0:
		guide_lines.clear()
		guide_t = 0.0
	for w in [10, 15, 20]:
		if wave >= w and not Garden.on:
			_achieve("wave%d" % w)
	Ach.on_wave_start(wave, towers.get_children(), Meta.map_id)
	_ach_check()
	garden_wave_dew = 0.0
	garden_kills0 = kills
	garden_cd = -1.0
	spawn_interval = maxf(0.35, 1.2 - wave * 0.06)
	spawn_timer = 0.5
	wave_time = 0.0
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
	# 나가는 법
	var dim := Color(1, 1, 1, 0.5)
	if touch_ui:
		c.draw_string(ui_font, Vector2(x0, y + 14.0), "눌러서 시작 화면으로", HORIZONTAL_ALIGNMENT_CENTER, W, 13, dim)
	else:
		Glyph.ui(c, "click", Vector2(-46.0, y + 9.0), 7.0, dim)
		c.draw_string(ui_font, Vector2(-34.0, y + 14.0), "· R · Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, dim)
		Glyph.ui(c, "home", Vector2(38.0, y + 9.0), 7.0, dim)
	if absf(over_label.offset_top - (y + 34.0)) > 0.5:
		over_label.offset_top = y + 34.0  # 남은 글은 카드 바로 아래 (둘 다 화면 가운데 기준)
		over_label.offset_bottom = y + 184.0


# ---------- 입력 ----------

## 두 손가락 벌리기·모으기 = 확대, 두 손가락 끌기 = 이동. PC는 휠 = 확대(커서 쪽), 휠 누른 채 끌기 = 이동.
## 처리했으면 true (그 입력은 게임·UI로 넘기지 않는다).
func _zoom_input(event: InputEvent) -> bool:
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
			_zoom_to(view_zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), event.position)
			return true
	if event is InputEventMouseMotion and mid_drag:
		_pan_by(event.relative)
		return true
	return false


## 휠을 굴릴 창(도감·패치노트·도움말·DPS 표 등)이 마우스 아래 있으면 확대하지 않는다.
func _over_scroll_ui(p: Vector2) -> bool:
	var h := get_viewport().gui_get_hovered_control() if get_viewport().has_method("gui_get_hovered_control") else null
	if h != null and h != ui_root and h != info:
		return true
	return settings_panel.visible or notes_panel.visible or help_label.visible or records_panel.visible or codex_panel.visible or vote_panel.visible or get_tree().paused


## 두 번째 손가락이 닿으면: 첫 손가락으로 시작한 누르기·끌기·그리기·상자 선택을 없던 일로.
func _abort_touch_action() -> void:
	if phase == Phase.DRAW and draw_on:
		draw_on = false
		draw_pts = PackedVector2Array()
		draw_len = 0.0
	if press_t:
		_drop_press()
		_restore_hint()
	boxing = false
	if dragging and moving:
		_cancel_step()


## 터치인지 마우스인지 기억한다 (터치에서 흉내 낸 마우스 움직임은 장치 번호가 EMULATION).
func _input(event: InputEvent) -> void:
	if _zoom_input(event):
		get_viewport().set_input_as_handled()
		return
	var was_touch := touch_ui
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_tip_t = TOUCH_TIP_SEC
	if event is InputEventScreenTouch:
		touch_ui = true
		if event.pressed:
			# 칩·배지를 누르면 말풍선 (다시 누르거나 다른 곳을 누르면 닫힘)
			var p: Vector2 = ui_root.get_global_transform().affine_inverse() * event.position
			var was := tip_pin
			tip_pin = -1
			for i in tip_rects.size():
				if tip_rects[i][0].has_point(p):
					tip_pin = -1 if was == i else i
					get_viewport().set_input_as_handled()
					break
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		touch_ui = false
	if touch_ui != was_touch:
		get_tree().call_group("keycap", "queue_redraw")  # 모서리 단축키 상자는 터치에서 숨긴다
	if touch_ui != was_touch and legend:
		_refresh_legend()  # 설명의 키 안내(도감 K)를 터치·마우스에 맞게


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
		if event.keycode == KEY_ESCAPE and (settings_panel.visible or records_panel.visible or help_label.visible or modes_panel.visible or codex_panel.visible or vote_panel.visible or tree_panel.visible):
			tree_panel.visible = false
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
				KEY_G:
					if garden_btn.visible:
						_enter_garden()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					if continue_btn.visible:
						_continue_run()
					else:
						_close_title()
				KEY_N:
					_close_title()
				KEY_LEFT:
					_cycle_map(-1)
				KEY_RIGHT:
					_cycle_map(1)
				KEY_F:
					_toggle_flip()
				KEY_UP:
					if Meta.games > 0:
						_cycle_rules(-1)
				KEY_DOWN:
					if Meta.games > 0:
						_cycle_rules(1)
				KEY_F11:
					_toggle_fullscreen()
				KEY_M:
					_toggle_mute()  # 시작 화면에도 소리 버튼이 보인다
			return
		if event.keycode == KEY_ESCAPE and phase == Phase.GAMEOVER:
			if Time.get_ticks_msec() - over_ms > 800:
				title_seen = false
				_reload()
			return
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif event.keycode == KEY_R and get_tree().paused:
			_pause_restart()
		elif event.keycode == KEY_E and get_tree().paused:
			_end_run()
		elif event.keycode == KEY_T and get_tree().paused:
			_leave(false)
		elif event.keycode == KEY_X and get_tree().paused and OS.has_feature("pc"):
			_leave(true)
		elif event.keycode == KEY_H:
			help_label.visible = not help_label.visible
		elif event.keycode == KEY_TAB:
			_toggle_legend()
		elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4] and phase == Phase.CHOOSE and help_label.visible == false:
			var i: int = event.keycode - (KEY_KP_1 if event.keycode >= KEY_KP_1 else KEY_1)
			if perk_mode:
				if i < perk_offer.size():
					_on_perk(perk_offer[i])
			elif i < offer.size():
				_on_pick(offer[i])
		elif event.keycode == KEY_Q and phase == Phase.CHOOSE and not perk_mode:
			_on_reroll()
		elif event.keycode == KEY_S and not event.ctrl_pressed and not event.meta_pressed and not title_label.visible:
			if skip_left > 0:
				_toggle_skip_stop()
			elif phase == Phase.CHOOSE:
				_on_skip()
		elif event.keycode == KEY_V and phase == Phase.CHOOSE:
			_set_cards_hidden(not cards_hidden)
		elif event.keycode == KEY_Z and phase == Phase.CHOOSE and not perk_mode:
			_set_card_detail(not Meta.card_detail)
		elif event.keycode == KEY_D and phase in [Phase.CHOOSE, Phase.READY]:
			_toggle_dps()
		elif event.keycode == KEY_A and (event.ctrl_pressed or event.meta_pressed) and phase in [Phase.CHOOSE, Phase.READY] and not perk_mode:
			# 모두 선택: 한꺼번에 옮길 때
			selected = towers.get_children()
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
		elif event.keycode == KEY_SPACE and phase == Phase.CHOOSE and Garden.on and not perk_mode:
			_start_wave()
		elif event.keycode == KEY_SPACE and phase == Phase.CHOOSE:
			_show_toast(("특성을" if perk_mode else "선택지를") + " 먼저 고르세요 (1·2·3 또는 클릭)")
		elif event.keycode == KEY_ESCAPE and (phase in [Phase.PLACE, Phase.AIM, Phase.MOVE, Phase.DRAW] or press_t or boxing or (not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY])):
			_cancel_step()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			_toggle_pause()
	if get_tree().paused:
		return
	if phase == Phase.DRAW:
		_draw_input(event)
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and aim_right:
		aim_right = false
		if phase == Phase.AIM:
			if get_global_mouse_position().distance_to(place_pos) > 30.0:
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
		# 누른 채 끌어서 놓으면 그 방향으로 바로 확정
		if phase == Phase.AIM and get_global_mouse_position().distance_to(place_pos) > 40.0 and Time.get_ticks_msec() - aim_start_ms > 150:
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
		var rt := _tower_at(get_global_mouse_position())
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
	var mpos := get_global_mouse_position()
	if perk_mode:
		return
	if phase in [Phase.CHOOSE, Phase.READY] and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tower_at(mpos)
		if t:
			# 짧게 클릭: 그 자리에서 방향 바꾸기, Shift/Ctrl+클릭: 선택에 더하기·빼기, 끌기: 바로 이동
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
			hint.text = _th("클릭 또는 끌어서 놓기: 방향 확정 (Shift: 15도 단위) (색칠된 곳이 공격 범위)\n우클릭/Esc: 옮기기 취소")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_step()
		return
	if phase == Phase.PLACE and event.button_index == MOUSE_BUTTON_LEFT:
		var target := _tower_at(mpos)
		if target:
			# 클릭은 손을 뗄 때 처리한다. 꾹 누르거나 끌면 카드를 유지한 채 옮긴다.
			_begin_press(target, mpos)
			return
		mpos = mpos.clamp(field_rect().position, field_rect().end)
		if mpos.distance_to(core()) < 50.0:
			_show_toast("중앙 점에 너무 가까워요")
			return
		if picked["type"] != "elem":
			_apply_card(target)
			return
		elif Garden.on and not _garden_can_new():
			return
		else:
			place_pos = mpos
			phase = Phase.AIM
			aim_start_ms = Time.get_ticks_msec()
			hint.text = _th("클릭 또는 끌어서 놓기: 발사 방향 확정 (Shift: 15도 단위) (색칠된 곳이 공격 범위)\n우클릭/Esc: 위치 다시 고르기")
	elif phase == Phase.AIM:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 오브젝트 바로 위를 누르면 손을 뗄 때 정한다 (그 자리에서 바깥으로 끌어 조준)
			if mpos.distance_to(place_pos) >= MERGE_DIST:
				_confirm_aim()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not aim_right:
			_cancel_step()
	elif phase == Phase.PLACE and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_step()


## 고른 카드를 오브젝트에 넣는다 (PLACE에서 오브젝트를 짧게 클릭).
func _place_on(target: Tower) -> void:
	if not _mine(target):
		_show_toast("친구가 놓은 오브젝트에는 넣을 수 없어요")
		return
	if picked["type"] != "elem":
		_apply_card(target)
		return
	if not target.can_take(picked):
		_show_toast(target.refuse_text(picked))
		return
	if not _garden_pay(Garden.cost_elem_on(target, picked["e"], towers.get_child_count())):
		return
	var msg: String = target.add(picked["e"], picked["lv"])
	_show_toast(msg)
	sfx.play("place")
	if msg.begins_with("반응"):
		sfx.play("reaction", 0.0)
		big_banner(msg + "!", Color(1, 0.8, 0.4))
		burst(target.position, Color(1, 0.85, 0.4), 30, 260.0)
	_after_place()


func _begin_press(t: Tower, mpos: Vector2) -> void:
	if not _mine(t):
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
	if not phase in [Phase.PLACE, Phase.CHOOSE, Phase.READY] or not is_instance_valid(press_t):
		_drop_press()
		return
	var mpos := get_global_mouse_position()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_press()
		return
	if not dragging and (mpos.distance_to(press_pos) > 12.0 or Time.get_ticks_msec() - press_ms >= 350):
		dragging = true
		drag_group = selected.duplicate() if press_t in selected else [press_t]
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
		else:
			selected.clear()
			_start_move(t)
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
	var r := Rect2(box_start, get_global_mouse_position() - box_start).abs()
	var add := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if not add:
		selected.clear()
	if r.size.length() > 8.0:
		for t in towers.get_children():
			if r.grow(Tower.RADIUS * 0.5).has_point(t.position) and not t in selected and _mine(t):
				selected.append(t)
	_restore_hint()


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


## 방향 확정 (클릭, 또는 끌었다 놓기).
func _confirm_aim() -> void:
	var d := _aim_dir(place_pos)
	if d == Vector2.ZERO:
		return
	if moving:
		moving.position = place_pos
		moving.dir = d
		moving.place_pop = 1.0
		sfx.play("place")
		moving.queue_redraw()
		moving = null
		_end_move()
		return
	if Garden.on and not _garden_pay(Garden.cost_new(towers.get_child_count())):
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
	map_label = _menu_row(box, func(): _cycle_map(-1), func(): _cycle_map(1))
	flip_label = _menu_row(box, _toggle_flip, _toggle_flip)
	rules_label = _menu_row(box, func(): _cycle_rules(-1), func(): _cycle_rules(1))
	modes_btn = Button.new()
	modes_btn.custom_minimum_size = Vector2(580, 56 if _phone() else 40)
	modes_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modes_btn.focus_mode = Control.FOCUS_NONE
	modes_btn.add_theme_font_size_override("font_size", 17)
	modes_btn.pressed.connect(_toggle_modes)
	box.add_child(modes_btn)
	# 오브젝트·중앙 모양은 한 줄에 나란히 (세로 자리 아끼기)
	var skins := HBoxContainer.new()
	skins.alignment = BoxContainer.ALIGNMENT_CENTER
	skins.add_theme_constant_override("separation", 24)
	box.add_child(skins)
	skin_label = _menu_row(skins, func(): _cycle_skin("tower", -1), func(): _cycle_skin("tower", 1), 180.0)
	core_label = _menu_row(skins, func(): _cycle_skin("core", -1), func(): _cycle_skin("core", 1), 180.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	# 시작 말고는 그림 + 짧은 이름 (단축키는 모서리 작은 키, 긴 이름은 말풍선)
	var specs := [["시작", _close_title, "", ""], ["기록", _toggle_records, "records", "", "기록·업적"], ["도감", _toggle_codex, "book", "K", "도감 (K)"], ["설정", _toggle_settings, "gear", "O", "설정 (O)"], ["튜토리얼", _open_tut_list, "help", "H", "튜토리얼 (H)"]]
	if OnlineConfig.SERVER_URL != "":
		specs.insert(2, ["순위", _toggle_board, "rank", "", "리더보드"])
		specs.insert(4, ["투표", _toggle_vote, "vote", "V", "다음 패치 투표 (V)"])
	for spec in specs:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
		if spec[2] == "":
			b.text = spec[0]
			b.custom_minimum_size = Vector2(170, 60 if _phone() else 54)
			continue
		b.custom_minimum_size = Vector2(78, 64 if _phone() else 54)
		b.tooltip_text = spec[4]
		if spec[2] == "vote":
			vote_btn = b
			b.visible = Net.vote_ok()
		_menu_glyph(b, spec[2], spec[0])
		_keycap(b, spec[3])
	row.get_child(0).add_theme_font_size_override("font_size", 20)
	new_btn = row.get_child(0)
	_icon_btn(new_btn, func(): return ["play", Color(1, 0.9, 0.6)])
	_keycap(new_btn, func(): return "N" if continue_btn.visible else "Enter")
	# 정원 모드와 씨앗 나무 (Garden)
	var grow := HBoxContainer.new()
	grow.alignment = BoxContainer.ALIGNMENT_CENTER
	grow.add_theme_constant_override("separation", 10)
	box.add_child(grow)
	garden_btn = Button.new()
	garden_btn.custom_minimum_size = Vector2(380, 44)
	garden_btn.focus_mode = Control.FOCUS_NONE
	garden_btn.clip_text = true
	garden_btn.add_theme_font_size_override("font_size", 16)
	garden_btn.add_theme_color_override("font_color", Color(0.6, 1, 0.7))
	garden_btn.tooltip_text = "켜 두거나 꺼 두어도 자라는 끝없는 판. 최고 25웨이브부터 환생해 씨앗을 얻는다"
	garden_btn.pressed.connect(_enter_garden)
	grow.add_child(garden_btn)
	tree_btn = Button.new()
	tree_btn.custom_minimum_size = Vector2(240, 44)
	tree_btn.focus_mode = Control.FOCUS_NONE
	tree_btn.clip_text = true
	tree_btn.add_theme_font_size_override("font_size", 16)
	tree_btn.add_theme_color_override("font_color", Color(0.85, 1, 0.6))
	tree_btn.tooltip_text = "씨앗으로 가지를 올리면 일반 판을 더 강하게 시작 (켜면 '성장' 기록)"
	tree_btn.pressed.connect(_toggle_tree)
	grow.add_child(tree_btn)
	# 이어하기: 저장된 판이 있을 때만 (쉬는 시간마다 자동 저장)
	continue_btn = Button.new()
	continue_btn.custom_minimum_size = Vector2(630, 60 if _phone() else 48)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.focus_mode = Control.FOCUS_NONE
	continue_btn.add_theme_font_size_override("font_size", 19)
	continue_btn.pressed.connect(_continue_run)
	continue_btn.visible = false
	box.add_child(continue_btn)
	box.move_child(continue_btn, row.get_index())
	remote_btn = Button.new()
	remote_btn.custom_minimum_size = Vector2(630, 56 if _phone() else 44)
	remote_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	remote_btn.focus_mode = Control.FOCUS_NONE
	remote_btn.add_theme_font_size_override("font_size", 17)
	remote_btn.pressed.connect(_claim_remote_run)
	remote_btn.visible = false
	box.add_child(remote_btn)
	box.move_child(remote_btn, row.get_index())
	# 멀티플레이: 중개 서버 주소가 있고 WebRTC 확장이 읽힌 기기에서만
	mp_btn = Button.new()
	mp_btn.text = "멀티플레이 (대결·협동)"
	_icon_btn(mp_btn, func(): return ["multi", Color(1, 1, 1, 0.85)])
	mp_btn.custom_minimum_size = Vector2(630, 42)
	mp_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mp_btn.focus_mode = Control.FOCUS_NONE
	mp_btn.add_theme_font_size_override("font_size", 18)
	mp_btn.pressed.connect(_toggle_mp_lobby)
	# Windows는 exe 안 dll을 풀어 읽어서 실패할 수 있다: 버튼은 두고 방을 만들 때 까닭을 보여 준다
	mp_btn.visible = _mp_btn_shown()
	box.add_child(mp_btn)
	box.move_child(mp_btn, row.get_index() + 1)
	_build_mp_lobby(root)
	# 온라인: 새 버전 알림, 패치 공지 (서버에서 받았을 때만 보임)
	update_btn = Button.new()
	update_btn.custom_minimum_size = Vector2(630, 56 if _phone() else 40)
	update_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	update_btn.focus_mode = Control.FOCUS_NONE
	update_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	update_btn.visible = false
	box.add_child(update_btn)
	notes_btn = Button.new()
	notes_btn.custom_minimum_size = Vector2(320, 52 if _phone() else 36)
	_icon_btn(notes_btn, func(): return ["notes", Color(1, 1, 1, 0.8)])
	notes_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	notes_btn.focus_mode = Control.FOCUS_NONE
	notes_btn.pressed.connect(_toggle_notes)
	box.add_child(notes_btn)
	box.move_child(notes_btn, update_btn.get_index())
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.custom_minimum_size = Vector2(630, 0)
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	notice_label.visible = false
	box.add_child(notice_label)

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
	board_bar = HBoxContainer.new()
	board_bar.add_theme_constant_override("separation", 10)
	board_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_bar.visible = false
	records_panel.add_child(board_bar)
	for f in [_board_next_map, _board_next_rules, _board_next_season, _board_next_grow]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 36)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 15)  # 4칸이라 '규칙: 버전 3 · 자유 쌓기'가 잘리던 것
		b.pressed.connect(f)
		board_bar.add_child(b)
	_build_notes(root)
	_build_modes(root, rsb)
	_build_tree(root, rsb)
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
	var cbox: Container = sv
	if _phone():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 4)
		sv.add_child(grid)
		cbox = grid
	for spec in [["화면 흔들림", "shake_on"], ["피해 숫자", "numbers_on"], ["속성 기호 표시 (색 위에 속성 그림)", "symbols_on"], ["모든 구체에 체력 숫자 (끄면 고리만)", "orb_hp_on"], ["중앙이 위험하면 1배속으로 (체력 50%·25%)", "danger_slow"], ["웨이브 넘기기 중 중앙이 위험하면 멈춤 (체력 50%)", "skip_danger"], ["효과 줄이기 (장판·터지는 효과를 옅게, 많을수록 더)", "fx_low"]]:
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
			"fx_low": cb.button_pressed = Meta.fx_low
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			match key:
				"shake_on": Meta.shake_on = on
				"numbers_on": Meta.numbers_on = on
				"orb_hp_on": Meta.orb_hp_on = on
				"danger_slow": Meta.danger_slow = on
				"skip_danger": Meta.skip_danger = on
				"fx_low": Meta.fx_low = on
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
		Tutorial.seen = {}  # 튜토리얼 항목도 처음 생길 때 다시 (기기에서 처음 켤 때 보는 기본 항목은 그대로 지남)
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
		ne.text_changed.connect(func(t):
			Meta.nickname = t.strip_edges()
			_save_best())
		ne.text_submitted.connect(func(_t): ne.release_focus())
		nrow.add_child(ne)
		sv.add_child(nrow)
		account_label = Label.new()
		account_label.add_theme_font_size_override("font_size", 14)
		account_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		account_label.text = Account.label()
		sv.add_child(account_label)
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
	_refresh_menu()


## ◀ 글자 ▶ 한 줄.
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


func _refresh_menu() -> void:
	var m: Dictionary = Meta.MAPS[Meta.map_id]
	var keep := Garden.boosted
	if title_label.visible and not Garden.on:
		Garden.boosted = Garden.want_boost()  # 다음 판의 기록 키 (성장/순수)
	var best := Meta.best_of(Meta.run_key())
	var grow_tag := " · 성장" if Garden.boosted else ""
	Garden.boosted = keep
	garden_btn.get_parent().visible = Meta.games > 0 or Garden.seeds_total > 0  # 첫 판 뒤에
	_refresh_garden_menu()
	# 폰: 맵 설명 줄은 뺀다 (도움말·도감에 있고, 줄이 많으면 시작 화면 전체가 줄어 버튼이 작아진다)
	map_label.text = _kh("맵: %s  (←/→)\n%s최고 기록%s  웨이브 %d · 점수 %s" % [Meta.map_name(), "" if _phone() else m["desc"] + "\n", (" (쉽게 모드)" if Modes.easy() else "") + grow_tag, best[0], num(best[1])])
	flip_label.get_parent().visible = Meta.map_id == "line"
	flip_label.text = _kh("구체가 오는 쪽: %s  (F)" % ("왼쪽 → 문은 오른쪽 끝" if Meta.line_flip else "오른쪽 → 문은 왼쪽 끝"))
	var ra := [Rules.NAMES[Meta.rules], " (시험)" if Meta.rules in Rules.TRIAL_IDS else "", "(눌러서 바꾸기)" if touch_ui else "(↑/↓)", _wrap_parts(Patch.text("rules_desc", str(Meta.rules), Rules.DESCS[Meta.rules]), " · ", 550.0, 18)]
	# 폰: 규칙 설명 줄도 뺀다 (이름만, 자세한 건 도움말·모드 창)
	rules_label.text = _kh("규칙: %s%s  %s" % ra.slice(0, 3) if _phone() else "규칙: %s%s  %s\n%s" % ra)
	rules_label.get_parent().visible = Meta.games > 0  # 규칙 버전 고르기는 첫 판을 끝낸 뒤에 (그 전엔 버전 1)
	modes_btn.visible = Meta.games > 0  # 모드도
	modes_btn.text = "모드 (시험): %s   ▶" % ("없음" if Modes.on.is_empty() else "%s · 점수 x%.2f" % [Modes.names(), Modes.mul()])
	if modes_panel.visible:
		_refresh_modes()
	var ts: Dictionary = Meta.TOWER_SKINS[Meta.tower_skin]
	skin_label.text = "오브젝트 모양: " + ts["name"]
	var cs: Dictionary = Meta.CORE_SKINS[Meta.core_skin]
	core_label.text = "중앙 모양: " + cs["name"]
	best_wave = best[0]
	best_score = best[1]


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
	var cap_m := "종류별 %d개" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "쌓을수록 절반"
	legend_heads = PackedStringArray([
		"공격방식 · 직선탄에 1번, 같은 것 Lv↑",
		"속성 · 추가 효과, " + cap_e,
		"강화 · 공격 변형, " + cap_m,
		"연계 · 주변 오브젝트와 함께",
		"발동 · 조건이 맞으면 추가 공격",
		"새 오브젝트 = 직선탄 + 속성 1",
		"특수 반응 · 두 속성이 만나면 (%d/%d)" % [Meta.codex.size(), Elem.REACTIONS.size()],
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
		lines.append("외 %d개%s (모두 도감%s)" % [rs.size() - shown, " · 못 만난 반응 %d개" % left if left > 0 else "", k])
	elif rs.size() < Elem.REACTIONS.size():
		lines.append("못 만난 반응 %d개 (도감%s)" % [Elem.REACTIONS.size() - rs.size(), k])
	legend.text = _kr_keep("\n".join(lines))
	legend.size.y = 380.0  # Label은 글이 줄어도 저절로 작아지지 않는다 (글이 길면 다시 늘어남)


## 규칙 버전 바꾸기: 기록은 버전마다 따로.
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
	board_bar.visible = false
	if not records_panel.visible:
		return
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
	lines.append("[반응 도감] %d / %d   (모든 반응·조합은 도감%s 특수 반응 탭)" % [Meta.codex.size(), Elem.REACTIONS.size(), "" if touch_ui else "(K)"])
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
			if e is Dictionary and not e.get("mine", true) and str(e.get("game", "")) == Net.game_version() and str(e.get("map", "")) in Meta.MAP_IDS:
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
	if not Net.enabled() or mp_mode != "":
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
		list.append({"els": els, "pat": t.pattern, "plv": t.plv, "mods": t.mods, "prism": t.prism, "reso": t.reso,
			"pincer": t.pincer, "trigs": t.trigs, "share": (t.run_dealt + t.dealt) / total if total > 0.0 else 0.0})
	# 피해 출처 몫 (속성·공격방식·강화·반응·연계별, 오브젝트를 합쳐서). 직접 타격 안의 배율 몫은 추정
	var src := {}
	var rs := _run_src()
	for key in rs:
		if total > 0.0 and rs[key] / total >= 0.0005:
			src[key] = snappedf(rs[key] / total, 0.0001)
	net.submit({
		"device": Meta.device_id, "nick": Meta.nickname, "title": Meta.title, "platform": Net.platform(), "game": old_run_ver if old_run_ver != "" else Net.game_version(),
		"patch": Patch.id, "map": Meta.map_id, "rules": Meta.rules, "modes": Array(Modes.on) + (["grow"] if Garden.boosted else []), "wave": wave, "score": score, "kills": kills,
		"best_combo": best_combo, "game_secs": run_game, "real_secs": run_real, "perks": perks.duplicate(),
		"towers": list, "src": src, "log": run_log, "vary": Vary.record(), "run": run_id, "ended": done,
	})


## 서버가 기록을 받으면 게임 오버 글 아래에 온라인 순위.
func _on_run_sent(res: Dictionary) -> void:
	if phase != Phase.GAMEOVER or not res.get("accepted", false):
		return
	var rk: Variant = res.get("rank")
	if int(res.get("season", 0)) == 0:
		over_label.text += _kr_keep("\n(지난 버전으로 한 판이라 이번 시즌 리더보드에는 들어가지 않아요)")
	elif rk is Dictionary:
		var season: Variant = Net.info.get("season")
		var sname := str(season.get("name", "")) if season is Dictionary else ""
		over_label.text += "\n온라인 순위%s: %s%d위 (최고 점수 %s)" % [" (쉽게 모드)" if Modes.easy() else "", sname + " " if sname != "" else "", int(rk["rank"]), num(int(rk["score"]))]


## 시작 화면 리더보드: 위쪽 버튼으로 맵·규칙 버전·시즌을 골라 본다.
## 처음엔 지금 고른 맵·규칙 버전의 이번 시즌 전체·이번 주 순위. 지난 시즌은 전체만.
func _toggle_board() -> void:
	records_panel.visible = not records_panel.visible
	if not records_panel.visible:
		board_bar.visible = false
		return
	board_map = Meta.map_id
	board_rules = Meta.rules if Meta.rules in Rules.IDS else Rules.IDS[0]
	board_grow = Garden.want_boost()  # 다음 판과 같은 쪽 (씨앗 나무를 켰으면 성장)
	board_easy = Modes.easy()  # 쉽게 모드를 켰으면 쉽게 모드 기록
	board_season = 0
	net.seasons()
	_load_board()


func _board_tag() -> String:
	return "%s|%d|%d|%s|%s" % [board_map, board_rules, board_season, board_grow, board_easy]


func _load_board() -> void:
	board_lines = {}
	_draw_board()
	net.leaderboard(board_map, board_rules, "all", board_season, _board_tag(), board_grow, board_easy)
	if board_season == 0:
		net.leaderboard(board_map, board_rules, "week", 0, _board_tag(), board_grow, board_easy)


## 순수(씨앗 나무 없이) → 성장(씨앗 나무·숙련을 쓴 판) → 쉽게 모드(쉽게 모드를 쓴 판) 기록.
func _board_next_grow() -> void:
	if board_easy:
		board_easy = false
		board_grow = false
	elif board_grow:
		board_easy = true
	else:
		board_grow = true
	_load_board()


func _board_next_map() -> void:
	board_map = Meta.MAP_IDS[(Meta.MAP_IDS.find(board_map) + 1) % Meta.MAP_IDS.size()]
	_load_board()


func _board_next_rules() -> void:
	board_rules = Rules.IDS[(Rules.IDS.find(board_rules) + 1) % Rules.IDS.size()]
	_load_board()


## 이번 시즌 → 지난 시즌들(최근부터) → 다시 이번 시즌. 목록의 첫 항목이 이번 시즌이다.
func _board_next_season() -> void:
	var ids := board_seasons.map(func(x): return int(x.get("id", 0)))
	if ids.size() <= 1:
		return
	var i := 0 if board_season == 0 else ids.find(board_season)
	board_season = 0 if i < 0 or i + 1 >= ids.size() else ids[i + 1]
	_load_board()


func _on_seasons_loaded(list: Array) -> void:
	board_seasons = list.filter(func(x): return x is Dictionary)
	if records_panel.visible and board_bar.visible:
		_draw_board()


func _season_name(id: int) -> String:
	for x in board_seasons:
		if int(x.get("id", 0)) == id:
			return str(x.get("name", ""))
	return "시즌 %d" % id


func _on_board_loaded(d: Dictionary) -> void:
	if not records_panel.visible or not board_bar.visible or d.get("tag", "") != _board_tag():
		return
	var lines := PackedStringArray()
	if d.has("error"):
		lines.append("  " + str(d["error"]))
	else:
		board_lines["season"] = str(d.get("season", {}).get("name", ""))
		var shown_me := false
		for e in d.get("entries", []):
			shown_me = shown_me or e.get("me", false)
			var tt := str(e.get("title", ""))
			var nick := str(e["nick"]) + (" 「%s」" % Meta.ACHIEVEMENTS[tt]["name"] if Meta.ACHIEVEMENTS.has(tt) else "")
			lines.append("  %d. %s   웨이브 %d · 점수 %s%s" % [int(e["rank"]), nick, int(e["wave"]), num(int(e["score"])), ("   ◀ 나" if e.get("me", false) else "") + ("   ▶ 진행 중" if not e.get("ended", true) else "")])
		if lines.is_empty():
			lines.append("  아직 기록이 없어요")
		var me: Variant = d.get("me")
		if me is Dictionary and not shown_me:
			lines.append("  …  내 순위 %d위 / %d명 · 점수 %s" % [int(me["rank"]), int(d.get("total", 0)), num(int(me["score"]))])
	board_lines[d.get("period", "all")] = lines
	_draw_board()


func _board_kind_name() -> String:
	return "쉽게 모드" if board_easy else ("성장 (씨앗 나무)" if board_grow else "순수")


func _draw_board() -> void:
	var cur := "" if board_seasons.is_empty() else str(board_seasons[0].get("name", ""))
	var sname := ("이번 시즌" + (" (%s)" % cur if cur != "" else "")) if board_season == 0 else _season_name(board_season)
	var texts := ["맵: %s" % Meta.map_name(board_map), "규칙: %s" % Rules.NAMES[board_rules], "시즌: %s" % sname, "기록: %s" % _board_kind_name()]
	for i in 4:
		var b: Button = board_bar.get_child(i)
		b.text = texts[i] + ("  ▶" if i != 2 or board_seasons.size() > 1 else "")
		b.disabled = i == 2 and board_seasons.size() <= 1
	board_bar.visible = true
	var lines := PackedStringArray(["[리더보드]   위 버튼을 누르면 맵·규칙·시즌·순수/성장/쉽게 모드가 바뀝니다   (빈 곳 %s)" % ("누르면 닫기" if touch_ui else "클릭: 닫기"), "", "", ""])
	var specs := [["all", "이번 시즌 전체"], ["week", "이번 주"]] if board_season == 0 else [["all", sname + " 전체"]]
	for spec in specs:
		lines.append(spec[1])
		lines.append_array(board_lines.get(spec[0], PackedStringArray(["  불러오는 중…"])))
		lines.append("")
	if not Meta.online_on:
		lines.append("설정에서 '기록 보내기'를 켜면 내 기록도 올라갑니다")
	elif Meta.nickname == "":
		lines.append("설정에서 닉네임을 정할 수 있어요")
	records_panel.text = _kr_keep("\n".join(lines))
	var lh := records_panel.get_line_height()
	board_bar.position = Vector2(18, 18 + lh + (lh * 2.0 - 36.0) / 2.0 + 2.0)


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
	l.text = _kr_keep("쉽게 모드를 켰어요\n쉽게 모드를 하나라도 켠 판은 일반(순수·성장) 리더보드에 오르지 않고 \"쉽게 모드\" 리더보드에만 올라가요. 어렵게 모드와 함께 켜도 같아요. 최고 기록도 따로 세요.")
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
			if Meta.discover(r["id"]):
				_show_toast("반응 도감에 추가: " + r["name"])
				_save_best()
				_refresh_legend()
				_guide("react", "특수 반응 · %s(%s+%s): %s. 발견한 반응은 오른쪽 설명에 채워져요" % [r["name"], Elem.NAMES[r["a"]], Elem.NAMES[r["b"]], r["desc"]])
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
	if mp_mode != "":
		return  # 멀티플레이 판은 이어하기가 없다
	if title_label.visible or not phase in [Phase.CHOOSE, Phase.READY] or press_t or dragging or coin_stage > 0:
		return
	if Garden.on:
		run_log.clear()  # 정원은 끝이 없어 선택 기록을 쌓지 않는다
	var ts := towers.get_children()
	var list: Array = []
	for t in ts:
		list.append(t.to_save())
	var vals := {
		"format": RUN_FORMAT, "version": ProjectSettings.get_setting("application/config/version", ""),
		"map": Meta.map_id, "line_flip": Meta.line_flip, "rules": Meta.rules, "modes": Array(Modes.on), "wave": wave, "score": score, "kills": kills, "best_combo": best_combo,
		"combo": combo, "combo_t": combo_t, "combo_bonus": combo_bonus,
		"core_hp": core_hp, "core_max": core_max, "perks": perks.keys().map(func(k): return [k, perks[k]]), "regen_acc": regen_acc, "orb_speed_mul": orb_speed_mul,
		"dmg_mul": Tower.dmg_mul, "spd_mul": Tower.spd_mul, "reach_mul": Tower.reach_mul, "tax_step": Tower.tax_step,
		"rerolls_left": rerolls_left, "bonus_rerolls": bonus_rerolls, "picks_left": picks_left,
		"vary": Vary.save(), "skip_left": skip_left, "skip_total": skip_total, "skip_stop": skip_stop, "bank_picks": bank_picks, "bank_rerolls": bank_rerolls, "bank_perks": bank_perks, "coin_next": coin_next, "rest_ready": rest_ready,
		"lanes": Array(lanes), "wave_resist": wave_resist, "boss": boss_plan, "achievements": new_achievements, "ach_run": Ach.run,
		"state": "perk" if perk_mode else ("ready" if phase == Phase.READY else "choose"),
		"offer": offer, "perk_offer": perk_offer.map(func(pk): return pk["id"]), "towers": list,
		"log": run_log, "game_secs": run_game, "real_secs": run_real, "run_id": run_id,
		"tutor": tutor, "tutor_given": tutor_given.keys(), "grow": Garden.boosted,
	}
	if Garden.on:
		vals["garden"] = Garden.run_state()
	var cfg := ConfigFile.new()
	for k in vals:
		cfg.set_value("run", k, vals[k])
	cfg.save(_run_path())
	if Garden.on:
		Garden.has_run = true
		Garden.run_wave = wave
		Garden.run_dew = Garden.dew
	elif run_id != moved_run:
		# 같은 계정의 다른 기기에서 이어 할 수 있게 서버에도 (쉬는 시간마다, 끄면 마지막 것)
		net.put_run(run_id, cfg.encode_to_text(), {"game": Net.game_version(), "platform": Net.platform(), "map": Meta.map_id,
			"rules": Meta.rules, "wave": wave, "score": score})


## drop: 서버의 같은 판도 지운다 (다른 기기가 가져가서 지우는 것이면 false).
func _clear_run(drop := true) -> void:
	if Garden.on:
		if FileAccess.file_exists(Garden.RUN_PATH):
			DirAccess.remove_absolute(Garden.RUN_PATH)
		Garden.has_run = false
		return
	if FileAccess.file_exists(RUN_PATH):
		var key := _local_run_key()
		DirAccess.remove_absolute(RUN_PATH)
		if drop and key != "" and key != moved_run:
			net.drop_run(key)


## 저장된 판 요약 {wave, map, rules, cfg} (없거나 형식이 다르면 빈 사전).
func _run_info(path := "") -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path if path != "" else _run_path()) != OK or Meta.val(cfg, "run", "format", 0) != RUN_FORMAT:
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
		continue_btn.text = "이어하기 (Enter)   웨이브 %d부터 · %s · %s" % [info["wave"] + 1, Meta.MAPS[info["map"]]["name"], Rules.NAMES[info["rules"]]]


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
		"cata": return cd.get("id") in ["elem", "pat"]
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
	Garden.boosted = g.call("grow", false) == true and not Garden.on
	if Garden.on:
		Garden.load_run(g.call("garden", {}))
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
	match g.call("state", "choose"):
		"perk":
			perk_offer = []
			for id in g.call("perk_offer", []):
				for pk in PERKS:
					if pk["id"] == id:
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


## 저장된 판이 지난 게임 버전에서 저장됐으면 그 버전 (같은 버전이거나 저장이 없으면 "").
func _old_run_version() -> String:
	var info := _run_info()
	if info.is_empty():
		return ""
	var v := str(Meta.val(info["cfg"], "run", "version", ""))
	if v == Net.game_version():
		return ""
	return v if v != "" else "?"


## 게임 버전이 바뀌면 지난 버전의 판은 이어 하지 않는다: 그 판을 불러와 지금 점수로 끝낸다
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
			if not _garden_pay(Garden.cost_pat(target, picked["id"])):
				return
			var was: String = target.pattern
			msg = target.set_pattern(picked["id"])
			if picked["id"] == "path":
				# 처음 넣거나 길이가 늘면 길을 다시 그리고, 갈래가 늘면 새 갈래를 그린다
				var q: Array = []
				if was != "path" or Pat.path_len(target.plv) > Pat.path_len(target.plv - 1):
					q = [0]
				else:
					var nb := target.add_branch()
					if nb >= 0:
						q = [nb]
				if not q.is_empty():
					_show_toast(msg)
					sfx.play("place")
					burst(target.position, _card_color(picked), 16, 160.0)
					_start_draw(target, q, true)
					return
		"mod":
			if not target.can_take(picked):
				_show_toast(target.refuse_text(picked))
				return
			if not _garden_pay(Garden.cost_mod(target, picked["id"])):
				return
			msg = target.add_mod(picked["id"])
		"link":
			if not _garden_pay(Garden.cost_link(_garden_links())):
				return
			msg = target.add_link(picked["id"])
		"trig":
			if not target.can_take(picked):
				_show_toast(target.refuse_text(picked))
				return
			if not _garden_pay(Garden.cost_trig(target, picked["id"])):
				return
			msg = target.add_trig(picked["id"])
	_show_toast(msg)
	sfx.play("place")
	burst(target.position, _card_color(picked), 16, 160.0)
	_after_place()


## 우클릭·Esc: 방향 고르기 → 위치 고르기 → 오브젝트 고르기 순으로 한 단계 되돌린다.
func _cancel_step() -> void:
	if phase == Phase.DRAW:
		_draw_next()  # 이 갈래는 그대로 두고 다음으로
		return
	if press_t:
		_drop_press()
		_restore_hint()
		return
	if boxing:
		boxing = false
		return
	if not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY]:
		selected.clear()
		_restore_hint()
		return
	if moving:
		moving.position = move_orig_pos
		moving.dir = move_orig_dir
		moving.queue_redraw()
		moving = null
		_end_move()
		return
	if phase == Phase.AIM:
		phase = Phase.PLACE
		hint.text = _th(PLACE_HINT)
	elif phase == Phase.PLACE:
		_back_to_choose()


## 선택지를 그대로 둔 채 오브젝트 고르기로 돌아간다.
func _back_to_choose() -> void:
	phase = Phase.CHOOSE
	choice_box.visible = not cards_hidden
	_update_reroll_btn()
	hint.text = _th(_choose_hint())
	_save_run()


## 방향 바꾸기를 끝내고 원래 단계로.
func _end_move() -> void:
	aim_right = false
	if move_return == Phase.READY:
		_enter_ready()
	else:
		_back_to_choose()


## 쉬는 시간에 설치된 오브젝트를 클릭(또는 우클릭한 채 끌기)하면 그 자리에서 방향을 다시 정한다.
## 옮기기는 끌기·꾹 누르기로 따로 한다 (예전엔 클릭 → 새 자리 → 방향, 방향만 바꿀 때도 제자리를 다시 눌러야 했다).
func _start_move(t: Tower) -> void:
	if t.pattern == "path":
		_start_draw(t, range(t.paths.size()), false)  # 그린 궤적은 방향 대신 길을 다시 그린다
		return
	move_return = phase
	start_btn.visible = false
	moving = t
	move_orig_pos = t.position
	move_orig_dir = t.dir
	place_pos = t.position
	phase = Phase.AIM
	aim_start_ms = Time.get_ticks_msec()
	choice_box.visible = false
	reroll_btn.visible = false
	if touch_ui:
		hint.text = _th("쏠 쪽을 누르거나 끌어서 놓기: 방향 확정   취소: 그대로 두기")
	else:
		hint.text = _th("클릭 또는 끌어서 놓기: 방향 확정 (Shift: 15도 단위)   오브젝트 우클릭한 채 끌기로도 바로 됨\n우클릭/Esc: 그대로 두기")


## 그린 궤적 길 그리기. q: 그릴 갈래 번호들, after: 카드로 들어왔으면 다 그린 뒤 고르기를 마친다.
func _start_draw(t: Tower, q: Array, after: bool) -> void:
	if not after:
		move_return = phase
	draw_t = t
	draw_queue = q.duplicate()
	draw_after = after
	phase = Phase.DRAW
	selected.clear()
	choice_box.visible = false
	reroll_btn.visible = false
	start_btn.visible = false
	_draw_begin_branch()


func _draw_begin_branch() -> void:
	draw_on = false
	draw_wait = false
	draw_pts = PackedVector2Array()
	draw_len = 0.0
	draw_bends = 0
	draw_bend_pts = PackedVector2Array()
	draw_stop = ""
	draw_skip = 0
	var n := Pat.path_branches(draw_t.plv)
	var head := "그린 궤적%s: " % (" %d/%d" % [draw_queue[0] + 1, n] if n > 1 else "")
	# 화면 아래 취소 버튼과 겹치지 않게 짧게 (남은 길이·꺾기 수는 그리는 끝에 따로 보인다)
	hint.text = _th(head + "누른 채 끌어 길 그리기\n" + ("취소: 그대로 두기" if touch_ui else "우클릭/Esc: 그대로 두기"))


func _draw_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_draw_begin_branch()
			draw_on = true
			draw_pts.append(draw_t.position)
			draw_aim = get_global_mouse_position()
		elif draw_on:
			_draw_release()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_step()


## 누른 채 끄는 동안: 마우스 쪽으로 DRAW_STEP마다 점을 잇는다 (길이·꺾기 수를 넘으면 멈춤).
const DRAW_STEP := 16.0
const DRAW_MIN := 48.0  # 이보다 짧으면 그리지 않은 것으로


func _update_draw() -> void:
	if phase != Phase.DRAW or not draw_on:
		return
	if not is_instance_valid(draw_t):
		_draw_done()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_draw_release()  # 창 밖에서 손을 떼 놓기 이벤트를 못 받은 경우
		return
	var m := get_global_mouse_position()
	# 터치: 손가락 떨림이 꺾기로 세어져 꺾기를 일찍 다 쓰던 것 → 목표점을 부드럽게 따라간다
	draw_aim = draw_aim.lerp(m, 0.45) if touch_ui else m
	_draw_extend(draw_aim.clamp(field_rect().position, field_rect().end))


## 손을 뗐을 때: 마우스는 바로 넣고, 터치는 길을 남겨 둔 채 [확정]을 기다린다 (다시 누른 채 끌면 새로 그림).
func _draw_release() -> void:
	draw_on = false
	if touch_ui and draw_len >= DRAW_MIN:
		_draw_extend(get_global_mouse_position().clamp(field_rect().position, field_rect().end))  # 떨림 줄이기로 덜 따라간 끝까지
		draw_wait = true
		hint.text = "[확정]으로 넣기 · 다시 누른 채 끌면 새로 그리기\n취소: 그대로 두기"
		return
	_draw_commit()


func _draw_extend(p: Vector2) -> void:
	var L := Pat.path_len(draw_t.plv)
	while draw_stop == "" and draw_pts[draw_pts.size() - 1].distance_to(p) >= DRAW_STEP:
		var last := draw_pts[draw_pts.size() - 1]
		var room := L - draw_len
		if room < 1.0:
			draw_stop = "길이를 다 썼어요"
			break
		var nxt := last + (p - last).normalized() * minf(DRAW_STEP, room)
		var n := draw_pts.size()
		# 세 조각 전 방향과 45도 넘게 다르면 꺾임 하나 (완만한 곡선은 세지 않음)
		if n >= 4 and draw_skip <= 0:
			var ref := draw_pts[n - 3] - draw_pts[n - 4]
			if absf(ref.angle_to(nxt - last)) > Pat.PATH_BEND_ANGLE:
				if draw_bends >= Pat.PATH_BENDS:
					draw_stop = "꺾기를 다 썼어요"
					break
				draw_bends += 1
				draw_bend_pts.append(last)
				draw_skip = 3
		draw_skip -= 1
		draw_len += last.distance_to(nxt)
		draw_pts.append(nxt)


## 다 그린 길을 오브젝트에 넣는다 (짧으면 다시 그리게 한다).
func _draw_commit() -> void:
	if draw_len < DRAW_MIN:
		draw_pts = PackedVector2Array()
		_show_toast("조금 더 길게 그려 주세요")
		return
	var t := draw_t
	var br: int = draw_queue[0]
	var loc := PackedVector2Array()
	for q in draw_pts:
		loc.append(q - t.position)
	while t.paths.size() <= br:
		t.paths.append(t.straight_path(t.dir))
	t.paths[br] = loc
	if br == 0:
		t.dir = (loc[1] - loc[0]).normalized()
		t.aim = t.dir
	t.place_pop = 1.0
	t.queue_redraw()
	sfx.play("place")
	_draw_next()


func _draw_next() -> void:
	draw_on = false
	if not draw_queue.is_empty():
		draw_queue.pop_front()
	if draw_queue.is_empty() or not is_instance_valid(draw_t):
		_draw_done()
	else:
		_draw_begin_branch()


func _draw_done() -> void:
	draw_t = null
	draw_pts = PackedVector2Array()
	if draw_after:
		draw_after = false
		_after_place()
	elif move_return == Phase.READY:
		_enter_ready()
	else:
		_back_to_choose()


## 그리는 중인 길과 남은 길이·꺾기 (터치면 손가락에 가리지 않게 위쪽에 글).
func _draw_path_edit() -> void:
	var t := draw_t
	var c := t.color()
	var br: int = draw_queue[0] if not draw_queue.is_empty() else 0
	var L := Pat.path_len(t.plv)
	draw_arc(t.position, L, 0, TAU, 96, Color(c, 0.12), 1.0)  # 곧게 그리면 닿는 곳
	for i in t.paths.size():
		var g := PackedVector2Array()
		for q in t.paths[i]:
			g.append(t.position + q)
		if g.size() >= 2:
			draw_polyline(g, Color(c, 0.2 if i == br else 0.4), 2.0)
	if draw_pts.size() >= 2:
		draw_polyline(draw_pts, Color(c.lightened(0.3), 0.95), 3.0)
	for q in draw_bend_pts:
		draw_arc(q, 6.0, 0, TAU, 16, Color(1, 0.8, 0.4, 0.9), 2.0)
	var tip := draw_pts[draw_pts.size() - 1] if not draw_pts.is_empty() else get_global_mouse_position()
	var txt := "남은 길이 %d · 꺾기 %d/%d" % [roundi(maxf(L - draw_len, 0.0)), draw_bends, Pat.PATH_BENDS]
	if draw_stop != "":
		txt += " · " + draw_stop
	var fs := roundi(15 * Meta.ui_scale)  # 폰은 글자 크기 설정만큼 (작아서 읽기 힘들었다)
	var tw := ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := tip + (Vector2(-70, -70) * Meta.ui_scale if touch_ui else Vector2(14, -14))
	at = at.clamp(view_rect().position + Vector2(4, 20), view_rect().end - Vector2(tw + 8, 8))
	draw_string(ui_font, at + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
	draw_string(ui_font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.6, 0.5) if draw_stop != "" else Color(1, 0.95, 0.75))


func _toggle_pause() -> void:
	if phase == Phase.GAMEOVER or title_label.visible:
		return
	get_tree().paused = not get_tree().paused
	paused_label.visible = get_tree().paused
	pause_box.visible = get_tree().paused
	paused_label.text = _pause_text()
	restart_armed = 0.0
	end_armed = 0.0
	pause_btn.text = _kh("계속 (P)" if get_tree().paused else "일시정지 (P)")


## 일시정지에서 처음부터: 두 번 눌러야 (R 또는 버튼).
func _pause_restart() -> void:
	if restart_armed > 0.0:
		get_tree().paused = false
		_reload()
	else:
		restart_armed = 2.0
		paused_label.text = _pause_text() + "\n처음부터를 한 번 더 누르면 새 판"


## 일시정지 글: 지금 나가면 어디서부터 이어지는지도 알려 준다. 키는 아래 그림 버튼 모서리에.
func _pause_text() -> String:
	if Garden.on:
		return "일시정지 (정원)\n정원은 쉬는 시간마다 저장되고, 꺼 둔 동안에도 이슬이 쌓여요 (최대 %d시간치)" % int(Garden.OFFLINE_MAX / 3600.0)
	var keys := "일시정지"
	if phase == Phase.WAVE:
		return keys + "\n지금 나가면 웨이브 %d 앞 쉬는 시간부터 이어집니다" % wave
	return keys + "\n지금 나가도 이 쉬는 시간부터 이어서 할 수 있어요"


## 일시정지에서 판 끝내기: 두 번 누르면 지금 점수로 게임 오버 (기록 저장·온라인 전송은 보통 게임 오버와 같다).
## 실수로 누르지 않게 처음 누르면 안내만 한다.
func _end_run() -> void:
	if Garden.on:
		return  # 정원은 끝나지 않는다 (환생은 쉬는 시간 버튼)
	if end_armed <= 0.0:
		end_armed = 3.0
		paused_label.text = _pause_text() + "\n판 끝내기를 한 번 더 누르면 지금 점수 %s로 끝냅니다 (기록·순위에 올라가요)" % num(score)
		return
	end_armed = 0.0
	get_tree().paused = false
	paused_label.visible = false
	pause_box.visible = false
	pause_btn.text = _kh("일시정지 (P)")
	ended = true
	_game_over()


## 일시정지에서 시작 화면으로 가거나 게임을 끈다. 쉬는 시간이면 지금 상태를 저장하고,
## 웨이브 중이면 그 웨이브 앞 쉬는 시간의 저장이 남는다 (시작 화면의 이어하기).
func _leave(quit_game: bool) -> void:
	_save_run()
	if Garden.on:
		_exit_garden()
	get_tree().paused = false
	if quit_game:
		get_tree().quit()
		return
	title_seen = false
	_reload()


func _toggle_speed() -> void:
	# Space·버튼: 1배속 ↔ 고른 배속
	game_speed = fast_speed if game_speed == 1.0 else 1.0
	_update_speed_btn()


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
		game_speed = fast_speed
	_update_speed_btn()
	_save_best()


func _tower_at(p: Vector2, except: Tower = null) -> Tower:
	for t in towers.get_children():
		if t != except and t.position.distance_to(p) < MERGE_DIST:
			return t
	return null


## 어둠 그림자 표식이 붙은 구체가 죽으면 남은 시간째 가장 가까운 산 구체(150 안)로 옮긴다.
func _pass_shade(o: Orb) -> void:
	var best: Orb = null
	var bd := 150.0
	for x in near(o.position, bd):
		if x != o and x.hp > 0.0 and x.position.distance_to(o.position) < bd:
			bd = x.position.distance_to(o.position)
			best = x
	if best:
		best.shade(o.shade_t)
		beam(o.position, best.position, Elem.COLORS[Elem.DARK])
	o.shade_t = 0.0


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

func spawn_proj(t: Tower, kind: String, l: int, d := Vector2.ZERO) -> Projectile:
	var p := Projectile.new()
	p.setup(kind, t, l, d)
	projectiles.add_child(p)
	if kind == "mushroom":
		t.mines.append(p)
	return p


func spawn_zone(kind: String, l: int, pos: Vector2, t: Tower) -> Zone:
	var z := Zone.new()
	z.setup(kind, l, t)
	z.src = t.tag if t else ""
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
		var p := (t.position + Tower.rock_slot(t.dir, k, l)).clamp(inner.position, inner.end)
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
	var dmg := Rules.t("sound_pulse") * Tower.pw(l) * (tw.dmg_k(true) if tw else 1.3) * (Rules.t("loud_mul") if o.loud_t > 0.0 else 1.0)
	var tox: Tower = o.toxring_src if o.toxring_t > 0.0 and is_instance_valid(o.toxring_src) else null
	for other in near(o.position, r + 30.0):
		if other.hp > 0.0 and other.position.distance_to(o.position) < r + other.radius():
			var got: float = other.hurt(dmg)
			if tw:
				tw.credit(got, "elem:sound")
			if tox:
				other.poison(1.2 * o.toxring_lv * Rules.rx_mul, 3.0, tox, true, "rx:toxecho")
	if pulses.size() < 40:
		pulses.append([o.position, r, 0.3])


## 프리즘 굴절 표시: 탄이 프리즘을 지나면 육각형이 퍼진다.
func refract(pos: Vector2, d: Vector2, col: Color) -> void:
	if refracts.size() < 40:
		refracts.append([pos, d, col, 0.35])


## 영혼: 넋이 걸린 채 죽은 구체에서 혼불 (망자의 강 안이면 반드시). 화면의 혼불은 30개까지.
func _soul_wisp(o: Orb) -> void:
	var tw: Tower = null
	var l := 1
	if o.styx_t > 0.0 and is_instance_valid(o.styx_src):
		tw = o.styx_src
		l = o.styx_lv
	elif o.soul_t > 0.0 and is_instance_valid(o.soul_src) and randf() < minf(Rules.t("soul_base") + Rules.t("soul_lv") * o.soul_lv, Rules.t("soul_max")):
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
	g.ghost = "styx" if o.styx_t > 0.0 else ""
	g.src = "rx:styx" if o.styx_t > 0.0 else "elem:soul"


## 영혼 형태 성질(넋불): 공격 끝 자리에서 혼불. 화면의 혼불은 30개까지 (_soul_wisp와 같이 셈).
func form_ghost(tw: Tower, pos: Vector2, dmg: float) -> void:
	var n := 0
	for p in projectiles.get_children():
		if p.kind == "ghost":
			n += 1
	if n >= 30:
		return
	var g := spawn_proj(tw, "ghost", tw.plv, Vector2.from_angle(randf() * TAU))
	g.position = pos
	g.dmg = dmg


## 빛 형태 성질(빛줄기) 표시: 잠깐 빛나는 직선.
func beam(a: Vector2, b: Vector2, c: Color) -> void:
	if beams.size() < 40:
		beams.append([a, b, c, 0.2])


## 전기 부가효과: 가까운 다른 구체로 전류가 튄다 (src: 쏜 오브젝트, 피해 기록용).
func arc(from: Orb, dmg: float, src: Tower = null) -> void:
	var best: Orb = null
	var bd := 90.0
	for o in near(from.position, bd):
		if o != from and is_instance_valid(o) and o.hp > 0.0:
			var d: float = o.position.distance_to(from.position)
			if d < bd:
				bd = d
				best = o
	if best:
		var got: float = best.hurt(dmg)
		if src:
			src.credit(got, "elem:electric")
		if arcs.size() < 80:
			arcs.append([from.position, best.position, 0.12])


## 구체 하나의 진입 각도·체력(종류 보정 전)·속도·저항·굳셈을 뽑는다.
func _roll_orb(w: int) -> Dictionary:
	var spread := minf(0.15 + 0.01 * w, 0.4)
	if Meta.map_id == "cross":
		spread = 0.06  # 십자로: 네 길 위로만 온다
	elif Meta.map_id == "line":
		spread = 0.0  # 회랑: 방향은 하나, 대신 높이가 길 폭 안에서 갈린다
	var li: int = lane_bag.pop_back() if not lane_bag.is_empty() and phase == Phase.WAVE and not w_off else wi() % lanes.size()
	var a: float = lanes[li] + wrange(-spread, spread)
	var hp := (1.0 + floorf(w * 0.7) + wi() % 2) * hp_growth(w) * Rules.orb_hp
	match Meta.map_id:
		"cross":
			hp = ceilf(hp * 1.6)
		"storm":
			hp = maxf(1.0, roundf(hp * 0.6))
		"line":
			hp *= LINE_HP
	if Garden.on:
		hp *= Garden.hp_k(w)
	hp *= Vary.hp_k()
	var spd := (30.0 + w * 3.0 + wf() * 8.0) * (LINE_SPD if Meta.map_id == "line" else 1.0) * Vary.spd_k()
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


## 구체가 나오는 거리 (화면 대각선 반 + 30, 화면 밖).
func _spawn_radius() -> float:
	return Meta.FIELD.length() / 2.0 + 30.0


## 각도 a에서 나온 구체가 막히지 않을 때 지나가는 길 (소용돌이 맵은 나선, 구체 이동과 같은 식).
## y: 회랑 맵에서 구체가 나오는 높이.
func _orb_path(a: float, y := 0.0) -> PackedVector2Array:
	if Meta.map_id == "line":
		return PackedVector2Array([_line_start(y), _line_end(y)])
	var c := center()
	var p := c + Vector2.from_angle(a) * _spawn_radius()
	if Meta.map_id != "spiral":
		return PackedVector2Array([p, c])
	var pts := PackedVector2Array([p])
	for k in 600:
		var to := c - p
		if to.length() <= 60.0:
			break
		p += to.normalized().rotated(SPIRAL_SWIRL) * 4.0
		if k % 3 == 2:
			pts.append(p)
	pts.append(p)
	pts.append(c)
	return pts


func _spawn_orb(kind := -1, plan := {}) -> void:
	var o := Orb.new()
	var p: Dictionary = plan if not plan.is_empty() else _roll_orb(wave)
	o.born = run_game
	o.position = center() + Vector2.from_angle(p["a"]) * _spawn_radius()
	o.from_a = p["a"]
	o.target = center()
	if Meta.map_id == "line":
		o.position = _line_start(p.get("y", 0.0))
		o.target = _line_end(p.get("y", 0.0))
	if kind < 0:
		kind = _roll_kind()
	o.main = self
	if Meta.map_id == "spiral":
		o.swirl = SPIRAL_SWIRL
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
	orbs.add_child(o)


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
	o.setup(Orb.Kind.FAST, maxf(1.0, roundf(wave * 0.5 * hp_growth(wave) * Rules.orb_hp)), 36.0 + wave * 3.0)
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
	key_t -= delta
	_mp_tick(delta)
	if coin_stage > 0 and not get_tree().paused:
		_coin_step(delta)
	touch_tip_t -= delta
	# 터치 [자세히]: 오브젝트 정보창이 떠 있는 동안만 (취소 버튼 왼쪽)
	var tip_on := touch_ui and Engine.get_process_frames() - tip_frame <= 2 and not title_label.visible
	if touch_ui:
		fx_layer.queue_redraw()  # 정보창이 떠 있는지(tip_frame)를 매 프레임 알도록 (쉬는 시간엔 다시 그리지 않는 프레임이 있다)
	if not tip_on:
		tip_detail = false
	detail_btn.visible = tip_on
	draw_ok_btn.visible = phase == Phase.DRAW and draw_wait and not get_tree().paused
	detail_btn.text = "간단히" if tip_detail else "자세히"
	_place_apply_btn()
	for c in [hint, skip_badge]:
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
	guide_label.visible = not guide_lines.is_empty() and not title_label.visible and phase != Phase.GAMEOVER and not get_tree().paused and not help_label.visible and not settings_panel.visible and not records_panel.visible and not notes_panel.visible and not modes_panel.visible and not codex_panel.visible and not vote_panel.visible
	# 글자를 키운(설정) 좁은 화면에서 펼친 버튼 줄이 왼쪽 아래 안내 글에 닿으면 안내 글을 버튼 줄 앞까지로 줄인다.
	# 줄이 늘면 위로 자라고, 다음 웨이브 미리보기는 그 위에 붙는다
	var hw := 590.0
	if pause_btn.visible:
		hw = clampf(bar_box.get_rect().position.x - hint.position.x - 12.0, 240.0, 590.0)
	if not is_equal_approx(hint.size.x, hw):
		hint.size.x = hw
	toast.position.y = maxf(100.0, hud.position.y + hud.size.y + 36.0)  # 점수 줄이 길어져도 보스 체력 막대 아래
	# 안내·큰 글자도 점수 줄이 길어지거나 글자를 키우면(설정) 그 아래로 밀어 겹치지 않게
	guide_label.position.y = maxf(140.0, toast.position.y + 40.0)
	_beside_legend(toast, 600.0)
	_beside_legend(guide_label, 0.0)
	# 왼쪽 위 DPS 표를 펼쳐 두면 알림이 표 위에 겹치던 것 (글자 115% 이상·표가 길 때): 표 오른쪽에 자리가 있으면 그쪽, 없으면 표 아래로
	if toast.visible and dps_panel.visible:
		var dr := dps_panel.get_rect()
		if toast.get_rect().intersects(dr):
			var right := legend.get_rect().position.x - 8.0 if legend.visible else ui_root.size.x - 8.0
			if right - dr.end.x - 8.0 >= toast.size.x:
				toast.position.x = dr.end.x + 8.0 + (right - dr.end.x - 8.0 - toast.size.x) / 2.0
			else:
				toast.position.y = dr.end.y + 8.0
	banner.position.y = maxf(ui_root.size.y / 2.0 - 140.0, hud.position.y + hud.size.y + 12.0)
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
	legend_btn.visible = legend.visible
	range_btn.visible = touch_ui and not title_label.visible and phase != Phase.GAMEOVER
	zoom_btn.visible = view_zoom > 1.01 and not title_label.visible
	zoom_btn.text = "확대 풀기 x%.1f" % view_zoom
	range_btn.text = "범위 끄기" if range_all else "범위 보기"
	legend_btn.text = _kh(("설명 보기" if legend_hidden else "설명 숨기기") + " (Tab)")
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
	title_box.visible = not (tut.visible or settings_panel.visible or records_panel.visible or help_label.visible or notes_panel.visible or modes_panel.visible or codex_panel.visible or vote_panel.visible or mp_panel.visible or tree_panel.visible)
	# 투표 버튼: 투표 API가 있는 서버(boot의 vote)에 닿았을 때만. 판 끝난 화면 버튼은 남은 글 바로 아래
	if vote_btn:
		vote_btn.visible = Net.vote_ok()
	vote_over_btn.visible = over_label.visible and phase == Phase.GAMEOVER and mp_mode == "" and Net.vote_ok() and not vote_panel.visible
	if vote_over_btn.visible:
		var lh := over_label.get_line_count() * over_label.get_line_height() if over_label.text != "" else 0
		vote_over_btn.position = Vector2(over_label.position.x + (over_label.size.x - vote_over_btn.size.x) / 2.0, over_label.position.y + lh + 10.0)
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
	if pause_box.visible:
		# 글자를 키우면(설정) 가운데 기준 자리가 점수 줄에 닿는다: 점수 줄 아래로
		paused_label.position.y = maxf(ui_root.size.y / 2.0 - 248.0, hud.get_rect().end.y + 8.0 if hud.visible else 8.0)
		pause_box.position.y = paused_label.position.y + paused_label.size.y + 10.0
		pause_box.size.x = 0.0  # 버튼 수(튜토리얼·끄기)만큼 넓어져도 가운데
		pause_box.position.x = floorf((ui_root.size.x - pause_box.get_combined_minimum_size().x) / 2.0)
	_fit_panels()
	_refresh_dps()
	_soften_fx()
	queue_redraw()
	info.queue_redraw()
	if phase == Phase.MOVE and moving:
		moving.position = get_global_mouse_position().clamp(field_rect().position, field_rect().end)
	_update_press()
	_update_draw()
	if boxing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_box()  # 창 밖에서 손을 떼 놓기 이벤트를 못 받은 경우
	hide_btn.visible = phase == Phase.CHOOSE and not title_label.visible and coin_stage == 0
	card_detail_btn.visible = hide_btn.visible and not cards_hidden and not perk_mode
	_update_skip_ui()
	cancel_btn.visible = phase in [Phase.PLACE, Phase.AIM, Phase.MOVE, Phase.DRAW] and not title_label.visible and not get_tree().paused
	hide_btn.text = _kh("▲ 선택지 보기 (V)") if cards_hidden else ""
	hide_btn.tooltip_text = "선택지를 다시 올린다" if cards_hidden else "필드 보기 (V): 선택지를 내리고 카드에 가려진 필드를 본다"
	if speed_btn.visible:
		speed_btn.queue_redraw()
	# 펼쳐 있으면 카드 바로 아래 새로고침 버튼 옆, 내려 두면 화면 위쪽 가운데
	hide_btn.set_anchors_preset(Control.PRESET_CENTER_TOP if cards_hidden else Control.PRESET_CENTER)
	# 카드 줄은 오른쪽 설명을 피해 왼쪽으로 비켜 있다. 설명을 숨기면 가운데로, 버튼도 카드 가운데에 맞춘다
	var cx := 0.0 if legend_hidden else -75.0
	# 카드 4장(정원 상점·열매 특성)이 오른쪽 설명 밑으로 들어가면(글자 크게) 쉬는 시간 동안 설명을 접고 가운데로
	if legend.visible and phase == Phase.CHOOSE and choice_box.get_child_count() > 3 and ui_root.size.x / 2.0 + cx + 365.0 > legend.position.x - 8.0:
		legend.visible = false
		cx = 0.0
	# 글자를 키우면(설정) 카드 줄 오른쪽이 설명 밑으로 들어가던 것: 설명 왼쪽까지 들어가게 왼쪽으로 옮기고, 모자라면 줄인다
	var room := (legend.get_rect().position.x - 8.0) if legend.visible else ui_root.size.x - 8.0
	var kw := minf((room - 8.0) / 730.0, 1.0)
	# 새로고침·내리기 버튼은 카드 바로 아래 한 줄에 (카드가 길어지면 버튼이 카드 글을 덮던 것).
	# 카드+버튼 줄이 왼쪽 아래 안내 글에 닿으면 카드 줄을 위로 올리고, 그래도 모자라면(글자 크게) 0.7배까지 줄인다
	var mid := ui_root.size.y / 2.0
	var ch := choice_box.get_combined_minimum_size().y
	var lim := _bottom_free() - 6.0
	var floor_y := (hud.position.y + hud.size.y + 8.0) if hud.visible else 8.0
	if dps_panel.visible and ui_root.size.x / 2.0 + cx - 365.0 < 320.0:
		floor_y += 44.0 + 48.0 + 6.0  # 왼쪽 위 DPS 표(머리 + 2줄, 나머지는 굴려 봄)를 덮지 않게
	if guide_label.visible:
		floor_y = maxf(floor_y, guide_label.position.y + guide_label.size.y + 26.0)  # 처음 안내 글이 카드 글 뒤로 겹치던 것 (고르기 꼬리표 자리 포함)
	var need := ch + 8.0 + 40.0 + (84.0 if Garden.on else 0.0)
	var k := clampf(minf((lim - floor_y) / need, kw), 0.7, 1.0)
	cx = minf(cx, room - 365.0 * k - ui_root.size.x / 2.0)
	choice_box.offset_left = cx - 365.0
	choice_box.offset_right = cx + 365.0
	var ctop := maxf(minf(mid - 90.0, lim - need * k), floor_y)
	choice_box.pivot_offset = Vector2(choice_box.size.x / 2.0, 0.0)
	choice_box.scale = Vector2(k, k)
	choice_box.offset_top = ctop - mid
	choice_box.offset_bottom = choice_box.offset_top + ch
	var by := choice_box.offset_top + ch * k + 8.0
	# 카드 밑 한 줄 그림 버튼: [새로고침 N] [필드 보기] [넘기기] [×N]. 없는 버튼 자리는 당겨 가운데 맞춘다
	var row: Array = []
	for bt in [reroll_btn, card_detail_btn, hide_btn, skip_btn, skip_n_btn]:
		if bt.visible and not (bt == hide_btn and cards_hidden):
			row.append(bt)
	var bw := {reroll_btn: 130.0 if Garden.on else 96.0, card_detail_btn: 104.0, hide_btn: 76.0, skip_btn: 76.0, skip_n_btn: 76.0}
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
	if cards_hidden:
		var hy := maxf(96.0, hud.position.y + hud.size.y + 8.0)  # 내려 둘 때는 점수 줄 아래
		hide_btn.offset_left = -130.0
		hide_btn.offset_right = 130.0
		hide_btn.offset_top = hy
		hide_btn.offset_bottom = hy + 32.0
	_garden_layout(cx, by)
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
	if Garden.on:
		_garden_ui(delta, reading)
	if reading:
		return
	_update_fx(delta)
	if phase != Phase.WAVE:
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
	# 콤보 유지 시간은 게임 시간으로 잰다: 배속을 올려도 점수가 달라지지 않는다
	if combo_t > 0.0 and not combo_hold:
		combo_t = maxf(combo_t - delta, 0.0)
		if combo_t <= 0.0 and combo >= 5:
			combo_end = [combo, combo_bonus, 1.5]
	_resolve(delta)

	if mp_ghost:
		return  # 협동 참가자: 웨이브 끝·게임 오버는 호스트가 알려 준다
	if core_hp <= 0 and Garden.on:
		_garden_retreat()
	elif core_hp <= 0:
		_game_over()
	elif to_spawn == 0 and _alive_count(orbs) == 0 and Garden.on:
		_garden_wave_done()
	elif to_spawn == 0 and mp_extra_left == 0 and _alive_count(orbs) == 0:
		combo_hold = true  # 쉬는 시간·카드 고르기 동안 콤보가 끊기지 않게
		_log_wave()
		Vary.wave_done(wave, _my_towers())
		_achieve("first")
		Ach.on_wave_clear(wave, wave_dmg, core_hp, core_max)
		_ach_check()
		if wave >= 5:
			Meta.map_best[Meta.run_key()] = [maxi(Meta.best_of(Meta.run_key())[0], wave), maxi(Meta.best_of(Meta.run_key())[1], score)]
			if Meta.MAP_IDS.all(func(id): return id in Meta.TRIAL_MAPS or Meta.best_of(Meta.key(id))[0] >= 5):
				_achieve("allmaps")
		var bonus := int(wave * 20 * Modes.mul())
		score += bonus
		_show_toast("웨이브 %d 클리어! +%d" % [wave, bonus])
		sfx.play("clear", 0.0)
		_show_mvp()
		if perks.has("regen"):
			core_hp = mini(core_hp + _regen_take(), core_max)
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
func _reached_core(o: Orb) -> bool:
	if Meta.map_id == "line":
		return absf(o.position.x - core().x) < CORE_RADIUS + o.radius()
	return o.position.distance_to(center()) < CORE_RADIUS + o.radius()


## 중앙에 닿은 구체를 기록하고, 그 구체가 들어온 화면 가장자리를 붉게 번지게 한다.
func _record_leak(o: Orb) -> void:
	wave_leaks.append([_lane_of(o.from_a), o.kind, o.core_dmg])
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
	var dmg := 0
	for l in wave_leaks:
		by_lane[l[0]] = by_lane.get(l[0], 0) + 1
		kinds[l[1]] = kinds.get(l[1], 0) + 1
		dmg += l[2]
	var dirs := {}
	leak_marks.clear()
	for i in by_lane:
		dirs[compass(lanes[i]) if i >= 0 and i < lanes.size() else "?"] = by_lane[i]
		if i >= 0 and i < lanes.size():
			leak_marks.append([lanes[i], by_lane[i]])
	leak_log.append({"w": wave, "n": wave_leaks.size(), "dmg": dmg, "dirs": dirs, "kinds": kinds, "towers": towers.get_child_count(), "lanes": lanes.size(), "core": core_hp})
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
	prism_towers = towers.get_children().filter(func(t): return t.prism > 0)
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
			_land(p)
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
			if o.shade_t > 0.0:
				_pass_shade(o)
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
			if Garden.on:
				var gd := Garden.kill_dew(wave, o.kind == Orb.Kind.BOSS)
				Garden.dew += gd
				garden_wave_dew += gd
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
				core_hp = mini(core_hp + 2, core_max)
				bonus_rerolls += 1
				if not Garden.on:
					_achieve("boss")
				_show_toast("보스 처치! 중앙 체력 +2" + ("" if Modes.has("narrow") else ", 새로고침 +1"))
			burst(o.position, o.death_color(), 10 if o.kind != Orb.Kind.BOSS else 40, 180.0)
			kills += 1
			if o.kind == Orb.Kind.BOSS:
				shake = 0.4
			if o.poison_t > 0.0:
				for other in targets:
					if other != o and other.position.distance_to(o.position) < 80.0:
						other.poison(o.poison_dps, 3.0, o.poison_src, o.poison_rx, o.poison_key)
			if o.curse_lv > 0:
				_curse_burst(o)
			if o.swamp_t > 0.0:
				_swamp_burst(o)
			if o.lava_t > 0.0:
				lava_burst(o)
			# 독늪: 표식이 남았거나 늪 안에서 죽으면 그 자리에 늪 (늪이 번진다)
			var bs: Object = o.bog_src if o.bog_t > 0.0 else o.swamp_src if o.swamp_t > 0.0 else null
			if is_instance_valid(bs):
				bs.spawn_bog(o.position, o.bog_lv if o.bog_t > 0.0 else o.swamp_lv)
			if o.soul_t > 0.0 or o.styx_t > 0.0:
				_soul_wisp(o)
			if not o.dfx.is_empty():
				RxMore.on_death(o)
			o.queue_free()
			continue
		if _reached_core(o):
			core_hp -= o.core_dmg
			sfx.play("core", 0.0)
			shake = 0.25 + 0.1 * o.core_dmg
			core_flash = 0.4
			burst(o.position if Meta.map_id == "line" else center(), Color(1, 0.3, 0.35), 18, 220.0)
			_show_toast("중앙 피격! %d/%d" % [maxi(core_hp, 0), core_max])
			wave_dmg += o.core_dmg
			Ach.on_core_hit(o.core_dmg)
			popup((o.position if Meta.map_id == "line" else center()) + Vector2(0, -CORE_RADIUS - 24.0), o.core_dmg, Color(1, 0.3, 0.35), true, "-%d" % o.core_dmg, 1.2)
			_check_danger()
			_record_leak(o)
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


## 저주: 표식 구체가 죽으면 주변에 그 구체 최대 체력의 10% 피해(보스는 1/4), 표식은 가까운 구체로 옮겨 간다.
## 2026-10-30 25% → 10%: 오브젝트 힘과 상관없이 후반 구체 체력만큼 커져 몰아 쌓은 판에서 피해의 2/3가 됐다.
const CURSE_BURST := 0.10


func _curse_burst(o: Orb) -> void:
	var tw: Tower = o.curse_owner if is_instance_valid(o.curse_owner) else null
	var dmg := CURSE_BURST * o.max_hp * (1.0 + 0.2 * (o.curse_lv - 1)) * (0.25 if o.kind == Orb.Kind.BOSS else 1.0)
	var next: Orb = null
	var bd := 220.0
	for other in near(o.position, bd):
		if other == o or other.hp <= 0.0:
			continue
		var d: float = other.position.distance_to(o.position)
		if d < 100.0 + other.radius():
			var got: float = other.hurt(dmg)
			other.last_rx = true
			if tw:
				tw.credit(got, "rx:curse")
				tw.rx_dealt += got
		if other.curse_lv == 0 and d < bd:
			bd = d
			next = other
	burst(o.position, Color(0.75, 0.3, 0.9), 18, 200.0)
	if next and tw:
		next.curse_lv = o.curse_lv
		next.curse_owner = tw
		if arcs.size() < 80:
			arcs.append([o.position, next.position, 0.25])
	o.curse_lv = 0


## 용암: 묻은 구체가 그 자리에서 터져 주변에 피해·화상 (오브젝트 반응 피해).
func lava_burst(o: Orb) -> void:
	o.lava_t = 0.0
	var tw = o.lava_src
	if not is_instance_valid(tw):
		return
	var l: int = o.lava_lv
	tw.in_rx = true
	tw.tag = "rx:lava"
	for other in near(o.position, Tower.LAVA_R):
		if other.hp > 0.0 and other.position.distance_to(o.position) < Tower.LAVA_R + other.radius():
			tw.hit(other, Tower.LAVA_DMG * Tower.pw(l))
			other.burn(1.0 * l, 2.0, tw, true, "rx:lava")
	tw.in_rx = false
	tw.tag = ""
	burst(o.position, Color(0.95, 0.3, 0.05), 12, 170.0)


## 독늪 안에서 죽으면 독이 터져 주변 구체를 중독시킨다.
func _swamp_burst(o: Orb) -> void:
	for other in near(o.position, 90.0):
		if other != o and other.hp > 0.0 and other.position.distance_to(o.position) < 90.0 + other.radius():
			other.poison(1.5 * o.swamp_lv, 4.0, o.poison_src, true, "rx:swamp")
	burst(o.position, Color(0.6, 0.85, 0.2), 12, 160.0)


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
	for q in refracts:
		q[3] -= delta
	refracts = refracts.filter(func(q): return q[3] > 0.0)
	for q in beams:
		q[3] -= delta
	beams = beams.filter(func(q): return q[3] > 0.0)
	shake = maxf(shake - delta, 0.0)
	combo_end[2] = maxf(combo_end[2] - delta, 0.0)
	combo_max_flash = maxf(combo_max_flash - delta, 0.0)
	core_flash = maxf(core_flash - delta, 0.0)
	eclipse_flash = maxf(eclipse_flash - delta, 0.0)
	eclipse_cd = maxf(eclipse_cd - delta, 0.0)
	if view_zoom > 1.0 and (title_label.visible or phase == Phase.GAMEOVER):
		_reset_zoom()  # 시작 화면·게임 오버는 1배로
	camera.position = center() + view_pan
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * shake * (1.0 if Meta.shake_on else 0.0)
	fx_layer.queue_redraw()


## 마우스를 올린 오브젝트의 정보.
func _draw_tooltip() -> void:
	tip_orb = null
	# 터치는 마우스를 올려 둘 수 없으니, 눌러서 옮기기 시작한 오브젝트의 정보를 보여 준다
	var touch_move := phase == Phase.MOVE and touch_ui and moving != null
	# 터치로 방향 바꾸기: 손가락은 쏠 쪽에 있으니 그 오브젝트 정보를 함께 보여 준다 ([자세히]로 수치까지)
	var touch_aim := phase == Phase.AIM and touch_ui and moving != null
	if (phase in [Phase.PLACE, Phase.GAMEOVER, Phase.MOVE, Phase.AIM, Phase.DRAW] and not touch_move and not touch_aim) or title_label.visible or dragging or boxing:
		return
	# 터치는 손을 뗀 자리에 마우스가 남는다: 누르고 3초가 지나면 정보창을 닫는다
	if touch_ui and not touch_move and not touch_aim and touch_tip_t <= 0.0:
		return
	if dps_panel.visible and dps_panel.get_global_rect().has_point(dps_panel.get_global_mouse_position()):
		return  # DPS 표 위: 표 뒤에 가린 오브젝트 정보창이 뜨지 않게
	var t := moving if touch_move or touch_aim else _tower_at(get_global_mouse_position())
	# 터치로 [자세히]를 누르면 손가락이 버튼으로 가서 정보창이 사라졌다: 방금 보던 오브젝트를 이어서
	if t == null and touch_ui and is_instance_valid(tip_tower) and detail_btn.visible \
			and detail_btn.get_global_rect().has_point(get_viewport().get_mouse_position()):
		t = tip_tower
	if t != null:
		tip_tower = t
	if t == null:
		_draw_orb_tooltip()
		return
	tip_frame = Engine.get_process_frames()
	var z: float = Meta.ui_scale
	var fs := roundi(14 * z)
	var lh := 18.0 * z
	var maxw := minf(620.0 * z, _right_limit() - 24.0)  # 이보다 긴 줄은 접는다 (속성이 많으면 화면 밖으로 나가던 것)
	var lines: Array = []  # [글자, 색]
	var head := t.title()
	var tip := ("(클릭: 길 다시 그리기 · 끌기: 옮기기)" if t.pattern == "path" else "(클릭: 방향 · 끌기: 옮기기)") if phase in [Phase.CHOOSE, Phase.READY] and not perk_mode else ""
	# Shift를 누르고 있으면 공격력·공격 속도·사거리 같은 수치를 자세히
	var detail := (Input.is_key_pressed(KEY_SHIFT) or (touch_ui and tip_detail)) and not touch_move
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
	var nhead := lines.size()
	lines.append(["%s Lv%d - %s" % [Pat.pname(t.pattern), t.plv, Pat.PATTERNS[t.pattern]["desc"]], Pat.pcolor(t.pattern).lightened(0.2), "p:" + t.pattern])
	var no := Pat.no_mods(t.pattern)
	if not no.is_empty():
		lines.append(["  못 넣는 강화(효과 없음): " + "·".join(no), Color(0.7, 0.7, 0.75)])
	for e in t.order:
		lines.append(["Lv%d %s" % [t.lv(e), Elem.rider(e)], Elem.COLORS[e], "e:%d" % e])
	var ex := t.extras_text()
	if ex != "":
		lines.append([ex, Color(1, 0.85, 0.45), "k:mod"])
	lines.append(["×%.2f" % t.dmg_factor(), Color(1, 1, 1, 0.8), "dmg"])
	var rxs := t.reactions()
	if rxs.size() <= 5:
		for r in rxs:
			lines.append(["%s: %s" % [r["name"], r["desc"]], r["color"], "k:rx"])
	else:
		# 반응이 많으면 이름만 (설명까지 쓰면 화면 높이를 넘음)
		lines.append(["반응 %d개: %s" % [rxs.size(), ", ".join(rxs.map(func(r): return r["name"]))], Color(1, 0.8, 0.95), "k:rx"])
	if wave_time > 1.0:
		var total := 0.0
		for o in towers.get_children():
			total += o.dealt
		var share := " · 전체의 %d%%" % roundi(t.dealt / total * 100.0) if total > 0.0 and towers.get_child_count() > 1 else ""
		lines.append(["%s 피해 %d (초당 %.1f%s)" % ["이번 웨이브" if phase == Phase.WAVE else "지난 웨이브", roundi(t.dealt), t.dealt / wave_time, share], Color(1, 0.9, 0.5), "rank"])
	_wind_buffs()  # 쉬는 시간에 새로 놓은 오브젝트도 바로 보이게
	if t.wind_buff > 0.0:
		lines.append(["바람 버프: 공격 속도 +%d%%" % roundi(t.wind_buff * 100.0), Elem.COLORS[Elem.WIND], "e:%d" % Elem.WIND])
	lines.append([t.spd_line().trim_prefix("공격 속도 "), Color(0.6, 0.9, 1.0), "rate"])
	var sp := t.spd_parts_text()
	if sp != "":
		lines.append(["  " + sp + " (모두 곱함)", Color(1, 1, 1, 0.65)])
	if detail:
		lines = lines.slice(0, nhead) + t.detail_lines()
	elif _tip_rows(lines, maxw, fs) * lh + 10.0 > view_rect().end.y - _tip_top() - 8.0:
		# 속성·반응이 아주 많으면 화면 높이를 넘어 위가 잘렸다: 반응 이름은 두 줄까지, 그래도 넘치면 속성 효과를 한 줄로
		var avail := floori((view_rect().end.y - _tip_top() - 18.0) / lh)
		for i in lines.size():
			if (lines[i][0] as String).begins_with("반응 %d개: " % rxs.size()):
				var names: Array = rxs.map(func(r): return r["name"])
				var k := names.size()
				var txt: String = lines[i][0]
				while k > 1 and _wrap_words(txt, maxw, fs).count("\n") >= 2:
					k -= 1
					txt = "반응 %d개: %s 외 %d개" % [rxs.size(), ", ".join(names.slice(0, k)), names.size() - k]
				lines[i] = [txt, lines[i][1]]
		if _tip_rows(lines, maxw, fs) > avail and t.order.size() > 1:
			var first := lines.find_custom(func(l): return l.size() > 2 and l[2] == "e:%d" % t.order[0])
			if first >= 0:
				var riders: Array = t.order.map(func(e): return (Elem.RIDER[e] as String).get_slice(":", 0))
				lines = lines.slice(0, first) + [["속성 효과: " + "·".join(riders), Color(0.85, 0.85, 0.9), "k:elem"]] + lines.slice(first + t.order.size())
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
	var p := t.position + Vector2(28, -h / 2)
	if touch_aim and get_global_mouse_position().x > t.position.x:
		p.x = t.position.x - 28.0 - (w + 16.0)  # 손가락(쏠 쪽) 반대편에
	p.x = clampf(p.x, vw.position.x + 8, _right_limit() - w - 16)
	var top := _tip_top()
	p.y = clampf(p.y, top if h <= size.y - top - 8.0 else vw.position.y + 8.0, size.y - h - 8)
	# 오른쪽 설명에 밀려 왼쪽으로 오면 오브젝트를 덮는다: 위나 아래로 비킨다
	if Rect2(p, Vector2(w + 16, h)).intersects(Rect2(t.position - Vector2(26, 26), Vector2(52, 52))):
		var above := t.position.y - 30.0 - h
		p.y = above if above >= top else minf(t.position.y + 30.0, size.y - h - 8)
	p = _avoid_cards(Rect2(p, Vector2(w + 16, h)), size)
	# 아래 안내 글·넘기기 표시는 UI라 정보창 위에 그려져 글이 섞인다: 겹치는 동안 옅게
	for c in [hint, skip_badge]:
		if c.visible and c.text != "" and Rect2(p, Vector2(w + 16, h)).intersects(get_canvas_transform().affine_inverse() * c.get_global_rect()):
			tip_fade[c] = Engine.get_process_frames()
	fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(0.05, 0.06, 0.09, 0.92))
	fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(1, 1, 1, 0.2), false, 1.0)
	for i in lines.size():
		fx_layer.draw_string(ui_font, p + Vector2(8 + gut, 6 + fs + i * lh), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lines[i][1])
		if lines[i].size() > 2 and lines[i][2] != "":
			_tip_icon(lines[i][2], p + Vector2(8 + gut * 0.45, 6 + i * lh + lh * 0.5), 6.0 * z, lines[i][1])
	if ctrl and not detail:
		_draw_tip_ctrl(p + Vector2(8, 6 + lines.size() * lh), fs, lh, t.pattern == "path", acts)


## 정보창 줄 앞 그림: "p:공격방식" · "e:속성" · "k:카드 종류" · 그 밖은 Glyph.ui.
func _tip_icon(id: String, c: Vector2, s: float, col: Color) -> void:
	match id.left(2):
		"p:": Glyph.pat(fx_layer, id.substr(2), c, s, col)
		"e:": Glyph.elem(fx_layer, int(id.substr(2)), c, s)
		"k:": Glyph.kind(fx_layer, id.substr(2), c, s, col)
		_: Glyph.ui(fx_layer, id, c, s, Color(col, 1.0))


## 정보창 맨 아래 조작 줄 (마우스): [왼쪽 단추] 방향 · [끌기] 옮기기 · [Shift] 자세히.
func _draw_tip_ctrl(at: Vector2, fs: int, lh: float, path: bool, acts: bool) -> void:
	var z: float = Meta.ui_scale
	var f := maxi(11, fs - 2)
	var x := at.x
	var y := at.y + lh * 0.5
	var dim := Color(1, 1, 1, 0.6)
	var items := [["click", "다시 그리기" if path else "방향"], ["drag", "옮기기"], ["Shift", "자세히"]] if acts else [["Shift", "자세히"]]
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
	var m := get_global_mouse_position()
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
		if o.burn_t > 0.0: parts.append("화상")
		if o.poison_t > 0.0: parts.append("중독")
		if o.root_immune > 0.0: parts.append("기절 면역")
		if o.vuln_t > 0.0: parts.append("약화(받는 피해 +30%)")
		if o.slow_timer > 0.0: parts.append("감속")
		if o.frozen_t > 0.0: parts.append("빙결")
		if o.prison_t > 0.0: parts.append("감옥(받는 피해 +50%)")
		if o.swamp_t > 0.0: parts.append("독늪(중독 2배)")
		if o.curse_lv > 0: parts.append("저주")
		if o.tune_t > 0.0: parts.append("울림 %d/3" % int(o.ring))
		if o.echo_t > 0.0: parts.append("메아리 %d%%" % roundi(o.echo_frac * 100))
		if o.soul_t > 0.0 or o.styx_t > 0.0: parts.append("넋")
		if o.silence_t > 0.0: parts.append("침묵")
		if o.resist_e >= 0: parts.append("%s 저항" % Elem.NAMES[o.resist_e])
		if o.sturdy: parts.append("굳셈(밀기·감속·기절·냉기 절반)")
		if o.lava_t > 0.0: parts.append("용암(%.1f초 뒤 폭발)" % o.lava_t)
		if o.seed_n > 0: parts.append("씨앗 %d" % o.seed_n)
		if not o.amp.is_empty():
			# 반응이 건 받는 피해 증가 (녹·씨앗·검은 물 등, 곱해서 하나로)
			var k := 1.0
			for v in o.amp.values():
				k *= 1.0 + v[0]
			if k > 1.005:
				parts.append("반응 약화(받는 피해 +%d%%)" % roundi((k - 1.0) * 100.0))
		var fs := roundi(14 * Meta.ui_scale)
		# 상태가 많으면(보스·후반) 한 줄이 화면·오른쪽 설명 밖으로 나간다: 들어가는 만큼씩 줄을 나눈다
		var maxw := minf(_right_limit() - 32.0, 620.0 * Meta.ui_scale)
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
	for q in refracts:
		var k: float = 1.0 - q[3] / 0.35
		var al := (1.0 - k) * fx_k
		var hx := PackedVector2Array()
		for i in 7:
			hx.append(q[0] + Vector2.from_angle(TAU * i / 6.0 + k) * (Tower.RADIUS + 6.0 + 22.0 * k))
		fx_layer.draw_colored_polygon(hx.slice(0, 6), Color(q[2], 0.18 * al))
		fx_layer.draw_polyline(hx, Color(q[2].lerp(Color.WHITE, 0.6), al), 3.5)
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


## 오른쪽 위(설명 버튼 아래) 콤보 상자: 콤보·점수 배율·남은 유지 시간·더 얻은 점수.
## 콤보는 웨이브 중에만 쌓이고(쉬는 시간엔 멈춰 다음 웨이브로 이어짐), 웨이브 중엔 설명 글이 꺼져 있어 이 자리가 빈다.
func _draw_combo() -> void:
	if title_label.visible or phase == Phase.GAMEOVER:
		return
	var live := combo_t > 0.0 and combo >= 2 and phase == Phase.WAVE  # 쉬는 시간엔 그 자리에 설명 글이 뜬다
	if not live and combo_end[2] <= 0.0:
		return
	var w := 180.0
	var r := legend_btn.get_global_rect()
	var p := Vector2(ui_root.position.x + ui_root.size.x * ui_root.scale.x - 10.0 - w, r.end.y + 8.0)
	if legend.visible:
		p.y = legend.get_global_rect().end.y + 8.0
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


## 투척형 발사체가 착지했을 때.
func _land(p: Projectile) -> void:
	var tw: Tower = p.owner_tower if is_instance_valid(p.owner_tower) else null
	if tw:
		tw.tag = p.src  # 장판이 발사체의 출처를 이어받는다
	match p.kind:
		"mushroom":
			var z := spawn_zone("mine", p.level, p.position, tw)
			if tw:
				tw.mines.erase(p)
				tw.mines.append(z)
	if tw:
		tw.tag = ""


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
		draw_colored_polygon(PackedVector2Array([
			tip - d * 22.0,
			tip + d.orthogonal() * 12.0,
			tip - d.orthogonal() * 12.0,
		]), col)
		if phase != Phase.WAVE and Meta.map_id == "spiral":
			# 나선 경로 미리보기 (구체 이동과 같은 식)
			if path.size() >= 2:
				draw_polyline(path, Color(col, 0.3), 1.5)
		elif phase != Phase.WAVE:
			# 중앙 쪽으로 흘러가는 점 (점선은 진입 방향이 늘면 화면을 가로질러 어지러워 뺐다)
			var L := (tip - c).length()
			for k in 5:
				var f := fmod(now * 0.25 + k / 5.0, 1.0)
				draw_circle(tip - d * f * (L - 40.0), 2.5, Color(col, 0.5 * (1.0 - f)))

	_draw_boss_path(now)
	_draw_wind_rings()
	# 누수: 구체가 들어온 화면 가장자리가 붉게 번진다 (어느 길목이 뚫렸는지)
	for lf in leak_flash:
		var f: float = lf[1] / 1.2
		for k in 4:
			draw_circle(lf[0], 40.0 + k * 34.0, Color(1, 0.15, 0.2, 0.16 * f * (1.0 - k * 0.22)))

	var mpos := get_global_mouse_position()
	if phase == Phase.CHOOSE and hover_elem >= 0:
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
		# 새 반응이 생기는 오브젝트 강조
		if is_elem:
			for t in towers.get_children():
				if not t.can_take(picked):
					continue
				var fresh := Elem.new_reactions(t.eff_now(), picked["e"])
				if not fresh.is_empty():
					draw_arc(t.position, Tower.RADIUS + 10.0 + pulse * 4.0, 0, TAU, 32, Color(fresh[0]["color"], 0.9), 3.0)
		if picked["type"] in ["pat", "mod", "elem", "trig"]:
			for t in towers.get_children():
				if t.can_take(picked):
					if picked["type"] != "elem":
						draw_arc(t.position, Tower.RADIUS + 10.0 + pulse * 4.0, 0, TAU, 32, Color(col, 0.9), 3.0)
				else:
					draw_line(t.position + Vector2(-8, -8), t.position + Vector2(8, 8), Color(1, 0.3, 0.3, 0.7), 3.0)
					draw_line(t.position + Vector2(8, -8), t.position + Vector2(-8, 8), Color(1, 0.3, 0.3, 0.7), 3.0)
		var target := _tower_at(mpos)
		if target:
			var pv: Array = target.preview(picked)
			var lines: PackedStringArray = pv[0]
			Tower.draw_range(self, target.position, target.dir, pv[1], picked["e"] if is_elem else -2)
			draw_arc(target.position, Tower.RADIUS + 8.0, 0, TAU, 32, Color.WHITE, 2.0)
			var tcol := col
			if is_elem:
				for r in Elem.new_reactions(target.eff_now(), picked["e"]):
					lines.append("반응: %s (%s)" % [r["name"], r["desc"]])
					tcol = r["color"]
			var y := target.position.y - Tower.RADIUS - 24.0 - 20.0 * (lines.size() - 1)
			for i in lines.size():
				var txt := lines[i]
				var c2: Color = tcol if i == 0 or txt.begins_with("반응") else Color(1, 1, 1, 0.85)
				var w := ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				var tp := Vector2(clampf(target.position.x - w / 2, 8, _right_limit() - w), maxf(y + i * 20.0, 16.0 + i * 20.0))
				draw_string(ui_font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
				draw_string(ui_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c2)
		elif is_elem:
			var at := mpos.clamp(field_rect().position, field_rect().end)  # 실제로 놓일 자리
			draw_circle(at, Tower.RADIUS, Color(col, 0.4))
			var near := at.distance_to(c) < 50.0
			var lbl := "중앙과 너무 가까움" if near else "새로 설치 (직선탄)"
			draw_string(ui_font, at + Vector2(-40, Tower.RADIUS + 20), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.5, 0.5) if near else Color(1, 1, 1, 0.7))
		else:
			draw_arc(mpos, 10.0, 0, TAU, 20, Color(col, 0.8), 2.0)
			draw_string(ui_font, mpos + Vector2(-50, 28), "오브젝트 위에 놓기", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
	elif phase == Phase.AIM:
		var sp: Dictionary = moving.spec() if moving else {"els": {picked["e"]: picked["lv"]}, "pat": Pat.DEFAULT, "plv": 1, "mods": {}}
		var col: Color = Elem.COLORS[sp["els"].keys()[0]]
		if not moving:
			draw_circle(place_pos, Tower.RADIUS, Color(col, 0.6))
		var d := _aim_dir(place_pos)
		if d != Vector2.ZERO:
			Tower.draw_range(self, place_pos, d, sp)
			if moving:
				moving.dir = d
				moving.queue_redraw()
			draw_line(place_pos, place_pos + d * (Tower.RADIUS + 14.0), Color.WHITE, 3.0)
	elif phase == Phase.DRAW and is_instance_valid(draw_t):
		_draw_path_edit()
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
		var hov := _tower_at(mpos)
		if hov:
			Tower.draw_range(self, hov.position, hov.dir, hov.spec())
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


## 회랑 맵: 길(띠)·끝의 문·구체가 오는 쪽 화살표.
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
func _aim_dir(from: Vector2) -> Vector2:
	var d := get_global_mouse_position() - from
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
		Garden.load_into(cfg)
		garden_auto = Meta.val(cfg, "option", "garden_auto", true)
		if not Garden.on and not Garden.prev.is_empty():
			Garden.restore_prev()  # 정원에서 게임을 끈 저장: 시작 화면 맵·규칙을 돌려 놓는다
		var b := Meta.best_of(Meta.run_key())
		best_wave = b[0]
		best_score = b[1]
		auto_start = Meta.val(cfg, "option", "auto_start", false)
		legend_hidden = Meta.val(cfg, "option", "legend_hidden", legend_hidden)
		bar_open = Meta.val(cfg, "option", "bar_open", false)
		sfx.muted = Meta.val(cfg, "option", "muted", false)
		fast_speed = Meta.val(cfg, "option", "fast_speed", 2.0)
		if not fast_speed in SPEEDS:
			fast_speed = 2.0


func _save_best() -> void:
	var cfg := ConfigFile.new()
	var b := Meta.best_of(Meta.run_key())
	if best_wave > b[0] or best_score > b[1]:
		Meta.map_best[Meta.run_key()] = [maxi(best_wave, b[0]), maxi(best_score, b[1])]
	if Garden.on:
		# 정원은 평원·버전 1로 돈다: 시작 화면에서 고른 맵·규칙은 그대로 저장
		var cur := [Meta.map_id, Meta.rules, Meta.line_flip]
		Meta.map_id = Garden.prev.get("map", Meta.map_id)
		Meta.rules = Garden.prev.get("rules", Meta.rules)
		Meta.line_flip = Garden.prev.get("line_flip", Meta.line_flip)
		Meta.save_into(cfg)
		Meta.map_id = cur[0]
		Meta.rules = cur[1]
		Meta.line_flip = cur[2]
	else:
		Meta.save_into(cfg)
	Garden.save_into(cfg)
	cfg.set_value("option", "garden_auto", garden_auto)
	cfg.set_value("option", "auto_start", auto_start)
	cfg.set_value("option", "legend_hidden", legend_hidden)
	cfg.set_value("option", "bar_open", bar_open)
	cfg.set_value("option", "muted", sfx.muted)
	cfg.set_value("option", "fast_speed", fast_speed)
	cfg.save(SAVE_PATH)


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
	mp_start_btn.custom_minimum_size = Vector2(200, 46)
	mp_start_btn.focus_mode = Control.FOCUS_NONE
	mp_start_btn.pressed.connect(_mp_start)
	row.add_child(mp_start_btn)
	var lb := Button.new()
	lb.text = "닫기"
	lb.custom_minimum_size = Vector2(200, 46)
	lb.focus_mode = Control.FOCUS_NONE
	lb.pressed.connect(_toggle_mp_lobby)
	row.add_child(lb)
	mp_bar = Label.new()  # 점수 줄 바로 아래 (_mp_tick이 자리를 맞춘다)
	mp_bar.add_theme_font_size_override("font_size", 15)
	mp_bar.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	mp_bar.add_theme_constant_override("outline_size", 4)
	mp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_bar.visible = false
	root.add_child(mp_bar)
	_mp_refresh_lobby()


## 시작 화면 [멀티플레이]: 창을 열고 닫는다. 닫으면 만든 방·들어간 방에서 나온다.
func _toggle_mp_lobby() -> void:
	mp_panel.visible = not mp_panel.visible
	if mp_panel.visible:
		mp.check_status()
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
	mp_status.text = "방을 만드는 중…"
	mp.host(m, _mp_my_name())


func _mp_join() -> void:
	var c := Mp.clean_code(mp_code_edit.text)
	if c.length() != 6:
		mp_status.text = "방 코드 6자리를 넣으세요"
		return
	if _mp_blocked():
		return
	mp_status.text = "방에 들어가는 중…"
	mp.join(c, _mp_my_name())


func _mp_failed(reason: String) -> void:
	if mp_mode == "":
		mp_status.text = reason
		_mp_refresh_lobby(false)
		return
	# 판 중에 끊김
	if mp_mode == "coop" and mp_ghost and phase != Phase.GAMEOVER:
		mp_rank = reason
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
	mp_host_box.visible = not in_room
	mp_join_box.visible = not in_room
	mp_room_box.visible = in_room
	for ch in mp_room_box.get_children():
		mp_room_box.remove_child(ch)
		ch.queue_free()
	mp_start_btn.visible = in_room and mp.is_host()
	var ready := mp.connected_ids().size()
	mp_start_btn.disabled = ready < 1
	if not in_room:
		if not keep_status and mp_status.text == "":
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
	for n in mp.names():
		var st := "" if n[0] == mp.my_id or n[2] else ("  (연결 안 됨)" if n[4] else "  (연결 중…)")
		var nm: String = _mp_name(n[0]) if n[0] != mp.my_id else (n[1] if n[1] != "" else "닉네임 없음")
		mp_room_box.add_child(_mp_member_row(n[3], n[0] == 1, nm + (" (나)" if n[0] == mp.my_id else "") + st))
	if mp.is_host():
		mp_status.text = "친구에게 방 코드를 알려 주세요. 연결되면 [시작] (최대 %d명)" % Mp.MAX_PLAYERS
	else:
		mp_status.text = "호스트가 시작하기를 기다리는 중"


## 로비 사람 한 줄: [플랫폼 그림] ★(호스트) 닉네임 (상태)
func _mp_member_row(pf: String, host: bool, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(26, 26)
	ic.tooltip_text = {"windows": "Windows", "mac": "Mac", "ios": "iPhone·iPad", "android": "Android", "linux": "Linux"}.get(pf, "")
	ic.draw.connect(func(): Glyph.ui(ic, "pf_" + (pf if pf != "" else "unknown"), ic.size * 0.5, 10.0, Color(1, 1, 1, 0.85)))
	row.add_child(ic)
	var l := Label.new()
	l.text = ("★ " if host else "") + text
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	return row


## 호스트 [시작]: 씨앗·맵·규칙을 정해 모두에게 보내고 함께 시작한다.
func _mp_start() -> void:
	if not mp.is_host() or mp.connected_ids().is_empty():
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


func _mp_begin(msg: Dictionary) -> void:
	mp.started = true
	mp_mode = str(msg.get("mode", "vs"))
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
			mp_others[int(id)] = {"name": str(names.get(id, "")), "w": 0, "hp": CORE_MAX_HP, "mx": CORE_MAX_HP, "sc": 0, "alive": true, "gone": false}
	mp_seed = int(msg.get("seed", 1)) if mp_mode == "vs" else 0
	mp_ghost = mp_mode == "coop" and not mp.is_host()
	if mp_mode == "coop":
		coop_orbs = 1.0 + 0.6 * mp_others.size()
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
	if mp_mode == "":
		return
	match t:
		"gone":
			if mp_others.has(from):
				mp_others[from]["gone"] = true
				_show_toast("%s 연결이 끊겼어요" % _mp_name(from))
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
			if phase == Phase.WAVE:
				mp_pending += n
			else:
				mp_next_extra += n
				_update_preview()
			_show_toast("%s가 구체 %d개를 보냈어요 (다음 웨이브에 더 옴)" % [_mp_name(from), n])
			sfx.play("danger", 0.0)
		"tw":
			_mp_recv_towers(from, msg.get("list", []))
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
		"wave":
			if mp_ghost and from == 1:
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
	mp_tick_t += delta
	mp_snap_t += delta
	if mp_mode == "vs" and mp_tick_t >= 0.5:
		mp_tick_t = 0.0
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
					parts.append("%s W%d ♥%d/%d %s점" % [nm, o["w"], o["hp"], o["mx"], num(o["sc"])])
			mp_bar.text = "대결 · " + "   |   ".join(parts)
		else:
			for id in mp_others:
				parts.append("%s%s" % [_mp_name(id), " (끊김)" if mp_others[id]["gone"] else ""])
			mp_bar.text = "협동 · 나(%s) + %s" % ["호스트" if mp.is_host() else "참가", ", ".join(parts)]
			mp_bar.add_theme_color_override("font_color", Mp.owner_color(mp.my_id))


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
		mp.send({"t": "clear", "w": wave, "perk": wave % 5 == 0, "sc": score, "hp": core_hp, "mx": core_max, "k": kills})
		return
	if mp_mode != "vs" or wave_dmg > 0:
		return
	var alive: Array = mp_others.keys().filter(func(id): return mp_others[id]["alive"] and not mp_others[id]["gone"])
	if alive.is_empty():
		return
	# 앞서 있는(점수가 높은) 상대에게
	alive.sort_custom(func(a, b): return mp_others[a]["sc"] > mp_others[b]["sc"])
	var n := 1 + wave / 4
	mp.send({"t": "atk", "n": n}, alive[0])
	_show_toast("완벽 방어! %s에게 구체 %d개를 보냈어요" % [_mp_name(alive[0]), n])


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
		if mp.is_host():
			mp.send({"t": "over", "w": wave, "sc": score, "k": kills})
		if mp_rank == "":
			mp_rank = "협동 %d명 · 함께 웨이브 %d까지" % [mp_others.size() + 1, wave]


## 대결: 다른 사람이 모두 탈락하면 승리 (판은 계속할 수 있다).
func _mp_check_win() -> void:
	if phase == Phase.GAMEOVER or mp_others.is_empty():
		return
	if mp_others.values().all(func(o): return not o["alive"] or o["gone"]):
		big_banner("승리! 끝까지 버텨 기록을 늘려 보세요", Color(1, 0.85, 0.3))
		sfx.play("clear", 0.0)


# --- 협동 ---

## 웨이브 시작을 누름: 모두 누르면 호스트가 시작한다.
func _mp_coop_ready() -> void:
	if phase != Phase.READY:
		return
	if mp.is_host():
		mp_ready[1] = true
		_mp_try_go()
	elif not mp_i_ready:
		mp_i_ready = true
		mp.send({"t": "ready"}, 1)
		start_btn.text = "친구를 기다리는 중…"


func _mp_try_go() -> void:
	if not mp_ready.get(1, false) or phase != Phase.READY:
		return
	var need: Array = mp.connected_ids()
	var have := need.filter(func(id): return mp_ready.get(id, false)).size()
	if have < need.size():
		start_btn.text = "친구를 기다리는 중 (%d/%d)" % [have + 1, need.size() + 1]
		return
	mp_ready.clear()
	mp.send({"t": "wave", "w": wave + 1})
	mp_wave_go = true
	_start_wave()
	mp_wave_go = false


## 참가자: 호스트가 웨이브를 시작했는데 아직 고르는 중이면 그대로 닫는다.
func _end_ghost_rest() -> void:
	if phase in [Phase.PLACE, Phase.AIM, Phase.MOVE, Phase.DRAW]:
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
	if bool(msg.get("perk", false)):
		_start_perk()
	else:
		_start_choose()


## 호스트: 전장 구체 상태를 보낸다 [번호, x, y, 체력, 최대, 종류, 보호막, 저항+1, 굳셈].
func _mp_send_snap() -> void:
	var o_list := PackedFloat32Array()
	for o in orbs.get_children():
		if o.is_queued_for_deletion():
			continue
		if o.net_id == 0:
			mp_orb_n += 1
			o.net_id = mp_orb_n
		o_list.append_array([o.net_id, o.position.x, o.position.y, o.hp, o.max_hp, o.kind, o.shield, o.resist_e + 1, 1.0 if o.sturdy else 0.0])
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
		o.sturdy = arr[i + 8] > 0.5
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


# ---------- 정원 모드 (Garden) ----------

func _run_path() -> String:
	return Garden.RUN_PATH if Garden.on else RUN_PATH


## 시작 화면 [정원]: 저장된 정원이 있으면 이어 하고(꺼 둔 동안의 이슬), 없으면 새 정원.
func _enter_garden() -> void:
	if not Garden.on:
		Garden.prev = {"map": Meta.map_id, "rules": Meta.rules, "line_flip": Meta.line_flip}
	Garden.on = true
	Garden.boosted = false
	Meta.map_id = "plain"
	Meta.rules = 1
	Modes.set_on([])
	_apply_rules()
	_hide_title()
	tree_panel.visible = false
	_update_auto_btn()
	if not _run_info().is_empty():
		_continue_run()
		var off: Array = Garden.offline_gain()
		if off[0] >= 1.0:
			Garden.dew += off[0]
			var h := int(off[1]) / 3600
			var mi := (int(off[1]) % 3600) / 60
			big_banner("꺼 둔 %s 동안 이슬 +%s" % ["%d시간 %d분" % [h, mi] if h > 0 else "%d분" % mi, Garden.short(off[0])], Color(0.6, 1, 0.75))
			_save_run()
	else:
		Garden.reset_run()
		wave = 0
		lanes.clear()
		_start_choose()
		_guide("garden", "정원: 처치하면 이슬, 이슬로 상점 카드를 사요. 웨이브는 저절로 이어지고, 중앙이 무너지면 %d웨이브 물러나요. 최고 %d웨이브부터 환생해 씨앗을 얻어요" % [Garden.RETREAT, Garden.REBIRTH_FROM])
	if garden_note != "":
		big_banner(garden_note, Color(0.75, 1, 0.55))
		garden_note = ""


## 정원에서 시작 화면으로: 맵·규칙을 정원에 들어오기 전으로.
func _exit_garden() -> void:
	Garden.on = false
	Garden.restore_prev()
	Modes.set_on(Meta.modes if Meta.games > 0 else [])
	_save_best()


## 정원 쉬는 시간: 상점(카드 4장, 사는 만큼 고르기) + 몇 초 뒤 다음 웨이브.
func _garden_rest(new_round: bool) -> void:
	if new_round:
		if wave == 0 and towers.get_child_count() == 0:  # 웨이브 0으로 물러난 것은 같은 정원
			tutor = false
			run_id = _new_run_id()
		_new_rest()
		rerolls_left = 0
		_garden_fill()
		garden_cd = Garden.NEXT_DELAY if garden_auto else -1.0
	picks_left = 9999
	phase = Phase.CHOOSE
	_show_offer()
	_open_choose()
	_save_run()


## 상점 카드: 속성 2장(하나는 이미 쓰는 속성에서) + 공격방식·강화·연계 2장.
func _garden_fill() -> void:
	offer.clear()
	var used: Array = []
	for t in towers.get_children():
		for e in t.order:
			if not e in used:
				used.append(e)
	var es: Array = Elem.ALL.duplicate()
	es.shuffle()
	if not used.is_empty():
		var u: int = used.pick_random()
		es.erase(u)
		es.push_front(u)
	for i in Garden.SHOP_ELEMS:
		offer.append({"type": "elem", "e": es[i], "lv": 1})
	var guard := 0
	while offer.size() < Garden.SHOP_ELEMS + Garden.SHOP_OTHERS and guard < 60 and towers.get_child_count() > 0:
		guard += 1
		var cd := _roll_card()
		if cd["type"] in ["elem", "cata"]:
			continue
		if cd["type"] in ["pat", "mod", "trig"] and not towers.get_children().any(func(t): return t.can_take(cd)):
			continue
		if offer.any(func(o): return _card_key(o) == _card_key(cd)):
			continue
		offer.append(cd)


## 상점 카드 가격 줄 [글, 지금 살 수 있는지]: 넣을 곳에 따라 다르면 가장 싼 값.
func _garden_price_text(card: Dictionary) -> Array:
	var ts := towers.get_children()
	var n := ts.size()
	match card["type"]:
		"elem":
			var c := Garden.cost_new(n)
			var t_new := "새로 %s" % Garden.short(c) if n < Garden.MAX_TOWERS else "새로 놓기: %d개 다 참" % Garden.MAX_TOWERS
			var low := -1
			for t in ts:
				if t.can_take(card):
					var x := Garden.cost_elem_on(t, card["e"], n)
					low = x if low < 0 else mini(low, x)
			var ok := (n < Garden.MAX_TOWERS and Garden.dew >= c) or (low >= 0 and Garden.dew >= low)
			return ["이슬 %s%s" % [t_new, " · 겹치기 %s~" % Garden.short(low) if low >= 0 else ""], ok]
		"pat", "mod", "trig":
			var low := -1
			for t in ts:
				if t.can_take(card):
					var x := Garden.cost_pat(t, card["id"]) if card["type"] == "pat" else Garden.cost_mod(t, card["id"]) if card["type"] == "mod" else Garden.cost_trig(t, card["id"])
					low = x if low < 0 else mini(low, x)
			return ["이슬 %s~" % Garden.short(low), low >= 0 and Garden.dew >= low]
		"link":
			var c := Garden.cost_link(_garden_links())
			return ["이슬 %s" % Garden.short(c), Garden.dew >= c]
	return ["", true]


## 정원이면 이슬을 낸다 (모자라면 알리고 false). 정원이 아니면 늘 true.
func _garden_pay(cost: int) -> bool:
	if not Garden.on:
		return true
	if Garden.dew < cost:
		_show_toast("이슬이 모자라요: %s 필요 (지금 %s)" % [Garden.short(cost), Garden.short(Garden.dew)])
		return false
	Garden.dew -= cost
	popup(get_global_mouse_position() + Vector2(14, -18), 0.0, Color(0.6, 1, 0.75), false, "-%s 이슬" % Garden.short(cost), 1.0)
	return true


## 정원에 새 오브젝트를 놓을 수 있나 (개수·이슬).
func _garden_can_new() -> bool:
	var n := towers.get_child_count()
	if n >= Garden.MAX_TOWERS:
		_show_toast("정원 오브젝트는 %d개까지예요. 있는 오브젝트에 겹쳐 보세요" % Garden.MAX_TOWERS)
		return false
	if Garden.dew < Garden.cost_new(n):
		_show_toast("이슬이 모자라요: 새 오브젝트 %s 필요 (지금 %s)" % [Garden.short(Garden.cost_new(n)), Garden.short(Garden.dew)])
		return false
	return true


func _garden_links() -> int:
	var n := 0
	for t in towers.get_children():
		n += t.prism + t.reso + t.pincer
	return n


## 상점에서 하나 샀다: 그 카드를 빼고(다 사면 새로 채움) 상점으로.
func _garden_bought() -> void:
	_check_progress()
	var i := offer.find(picked)
	if i >= 0:
		offer.remove_at(i)
	if offer.is_empty():
		_garden_fill()
	garden_cd = Garden.NEXT_DELAY if garden_auto else -1.0
	_garden_rest(false)


## 정원 웨이브를 막았다: 숙련·최고 기록·초당 이슬, 10웨이브마다 특성.
func _garden_wave_done() -> void:
	combo_hold = true
	_log_wave()
	var total := 0.0
	for t in towers.get_children():
		total += t.dealt
	var kw := float(kills - garden_kills0)
	if total > 0.0 and kw > 0.0:
		for t in towers.get_children():
			if t.dealt > 0.0 and not t.elements.is_empty():
				for e in t.elements:
					Garden.add_mastery(e, kw * t.dealt / total / t.elements.size())
	Garden.best = maxi(Garden.best, wave)
	# 웨이브를 막으면 중앙 체력이 다 찬다: 놓친 구체가 쌓여 켜 둔 채 결국 물러나지 않게, 한 웨이브에 다 뚫릴 때만 물러남
	if core_hp < core_max:
		core_hp = core_max
		danger_lv = 0
	Garden.best_ever = maxi(Garden.best_ever, wave)
	var r := garden_wave_dew / maxf(1.0, wave_time + Garden.NEXT_DELAY)
	Garden.rate = r if Garden.rate <= 0.0 else lerpf(Garden.rate, r, 0.3)
	_show_toast("웨이브 %d · 이슬 +%s" % [wave, Garden.short(garden_wave_dew)])
	sfx.play("clear", 0.0)
	_show_mvp()
	if perks.has("regen"):
		core_hp = mini(core_hp + perks["regen"] * int(_perk_val("regen")), core_max)
	if wave == Garden.REBIRTH_FROM and Garden.rebirths == 0:
		_guide("rebirth", "환생할 수 있어요: 정원을 처음부터 하는 대신 씨앗(최고 웨이브 - %d)을 받아 씨앗 나무로 일반 판을 강하게 해요" % Garden.SEED_BASE)
	_save_best()
	if wave % Garden.PERK_EVERY == 0:
		garden_perk_t = Garden.PERK_WAIT
		_start_perk()
	else:
		_start_choose()


## 특성 하나를 얻는다 (고르기·씨앗 나무 열매 2).
func _grant_perk(id: String) -> void:
	perks[id] = perks.get(id, 0) + 1
	_apply_perk(id)


## 중앙 점이 무너졌다: 게임 오버 대신 몇 웨이브 물러나 다시.
func _garden_retreat() -> void:
	var w0 := wave
	var key := str(w0)
	Garden.walls[key] = int(Garden.walls.get(key, 0)) + 1
	_log_wave()
	for o in orbs.get_children():
		o.queue_free()
	to_spawn = 0
	wave_active = false
	_clear_shots()
	wave = maxi(0, wave - Garden.RETREAT)
	core_hp = core_max
	core_disp = float(core_hp)
	danger_lv = 0
	combo = 0
	combo_t = 0.0
	shake = maxf(shake, 1.5)
	sfx.play("over", 0.0)
	banner_queue.clear()  # 앞서 쌓인 '중앙 위험' 글이 물러난 뒤 카드 위에 뜨던 것
	banner_t = 0.0
	big_banner("중앙이 무너졌다 · 웨이브 %d부터 다시" % (wave + 1), Color(1, 0.5, 0.5))
	if Garden.walls[key] >= 3:
		var tip := " 환생하면 씨앗 +%d" % Garden.seeds_for(Garden.best) if Garden.can_rebirth() else ""
		_show_toast("웨이브 %d에서 %d번 물러났어요: 구성을 바꿔 보세요.%s" % [w0, Garden.walls[key], tip])
	_start_choose()


## 환생: 정원을 처음부터, 씨앗 +(최고 웨이브 - 20). 두 번 눌러야.
func _rebirth() -> void:
	if not Garden.on or not Garden.can_rebirth() or phase != Phase.CHOOSE:
		return
	if rebirth_armed <= 0.0:
		rebirth_armed = 3.0
		return
	var got := Garden.seeds_for(Garden.best)
	Garden.seeds += got
	Garden.seeds_total += got
	Garden.rebirths += 1
	_clear_run()
	Garden.reset_run()
	_save_best()
	garden_note = "환생! 씨앗 +%d (모두 %d) · 이슬 획득 +%d%%" % [got, Garden.seeds, roundi(minf(1.0, Garden.REBIRTH_DEW * Garden.rebirths) * 100)]
	get_tree().reload_current_scene()


## 분재로 지정: 선택한 오브젝트, 없으면 이번(지난) 웨이브에 가장 많이 때린 것.
func _set_bonsai() -> void:
	var t: Tower = selected[0] if selected.size() == 1 else null
	if t == null:
		for x in towers.get_children():
			if t == null or x.run_dealt + x.dealt > t.run_dealt + t.dealt:
				t = x
	if t == null:
		return
	Garden.bonsai = Garden.bonsai_of(t)
	_save_best()
	burst(t.position, Color(0.75, 1, 0.55), 20, 180.0)
	_show_toast("분재: " + Garden.bonsai_text())


## 정원 버튼·카운트다운 (매 프레임, 쉬는 시간).
func _garden_ui(delta: float, reading: bool) -> void:
	var rest := Garden.on and phase == Phase.CHOOSE and not title_label.visible and not get_tree().paused
	rebirth_armed = maxf(rebirth_armed - delta, 0.0)
	rebirth_btn.visible = rest and not perk_mode and Garden.can_rebirth()
	if rebirth_btn.visible:
		rebirth_btn.text = "한 번 더: 정원 처음부터" if rebirth_armed > 0.0 else "환생: 씨앗 +%d" % Garden.seeds_for(Garden.best)
	bonsai_btn.visible = rest and not perk_mode and Garden.lv("bonsai") > 0 and towers.get_child_count() > 0
	if bonsai_btn.visible:
		bonsai_btn.text = "분재로 지정 (%s)" % ("선택한 것" if selected.size() == 1 else "최다 피해")
	if not rest:
		if Garden.on and phase != Phase.READY:
			start_btn.visible = false  # 놓는 중·웨이브 중엔 카운트다운 버튼을 숨긴다 (놓는 동안 멈춰 있음)
		return
	if perk_mode:
		start_btn.visible = false
		garden_perk_t -= delta
		if garden_perk_t <= 0.0 and not perk_offer.is_empty() and garden_auto:
			_on_perk(perk_offer[0])
		return
	start_btn.visible = true
	if garden_cd < 0.0:
		start_btn.text = "다음 웨이브 (Space)"
		return
	var hc := get_viewport().gui_get_hovered_control()
	var hovering := hc != null and (choice_box.is_ancestor_of(hc) or hc == reroll_btn or hc == rebirth_btn or hc == bonsai_btn)
	if press_t or boxing or reading or hovering:
		garden_cd = maxf(garden_cd, 1.5)
	else:
		garden_cd -= delta
	start_btn.text = "%.1f초 뒤 다음 웨이브 (Space)" % maxf(garden_cd, 0.0)
	if garden_cd <= 0.0:
		_start_wave()


## 정원 쉬는 시간: 다음 웨이브·환생·분재 버튼을 카드 줄 아래에 (화면 맨 아래 진입 표시와 겹치던 것).
func _garden_layout(cx: float, by: float) -> void:
	if not Garden.on:
		if start_btn.anchor_top != 1.0:
			start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			start_btn.position = Vector2(-110, -100)
			start_btn.size = Vector2(220, 44)
		return
	var rows := [[start_btn, cx - 305.0, cx - 5.0, by + 42.0], [rebirth_btn, cx + 5.0, cx + 305.0, by + 42.0], [bonsai_btn, cx - 150.0, cx + 150.0, by + 84.0]]
	if not rebirth_btn.visible:
		rows[0][2] = cx + 305.0
	for r in rows:
		var b: Button = r[0]
		b.set_anchors_preset(Control.PRESET_CENTER)
		b.offset_left = r[1]
		b.offset_right = r[2]
		b.offset_top = r[3]
		b.offset_bottom = r[3] + 36.0


# ---------- 씨앗 나무 (일반 판) ----------

## 새 일반 판: 씨앗 나무·숙련을 켰으면 시작 보너스 (기록은 '성장' ~grow로 따로).
func _apply_tree() -> void:
	Garden.boosted = Garden.want_boost()
	if not Garden.boosted:
		return
	core_max += Garden.lv("root")
	core_hp = core_max
	core_disp = float(core_hp)
	Tower.dmg_mul += 0.03 * Garden.lv("stem")
	if Garden.lv("leaf") >= 1:
		bonus_rerolls += 1
	if Garden.lv("fruit") >= 2:
		var pool: Array = PERKS.filter(func(pk): return not (pk["id"] == "reroll" and Modes.has("narrow")))
		var pk: Dictionary = pool.pick_random()
		_grant_perk(pk["id"])
		_show_toast("씨앗 나무 열매: 특성 '%s'로 시작" % pk["name"])
	call_deferred("_place_bonsai")


## 분재 오브젝트를 첫 진입 방향을 겨눠 중앙 가까이에 놓는다.
func _place_bonsai() -> void:
	var b := Garden.bonsai
	if Garden.lv("bonsai") <= 0 or b.is_empty() or wave != 0 or Garden.on:
		return
	var a: float = lanes[0] if not lanes.is_empty() else 0.0
	var d := Vector2.from_angle(a)
	var t := Tower.new()
	t.main = self
	t.add(b["e"], 2)
	if b["pat"] != Pat.DEFAULT:
		t.set_pattern(b["pat"])
		for i in int(b["plv"]) - 1:
			t.set_pattern(b["pat"])
	for i in mini(Garden.lv("bonsai") - 1, b["mods"].size()):
		t.add_mod(b["mods"][i])
	t.dir = d
	t.position = core() + d * 110.0
	towers.add_child(t)
	t.eff = t.eff_now()
	burst(t.position, Color(0.75, 1, 0.55), 24, 200.0)
	_show_toast("분재로 시작: " + Garden.bonsai_text())
	_update_preview()


func _build_tree(root: Control, sb: StyleBox) -> void:
	tree_panel = PanelContainer.new()
	tree_panel.set_anchors_preset(Control.PRESET_CENTER)
	tree_panel.position = Vector2(-330, 0)
	tree_panel.size = Vector2(660, 0)
	tree_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	tree_panel.add_theme_stylebox_override("panel", sb.duplicate())
	tree_panel.visible = false
	root.add_child(tree_panel)
	tree_box = VBoxContainer.new()
	tree_box.add_theme_constant_override("separation", 8)
	tree_panel.add_child(tree_box)


func _toggle_tree() -> void:
	tree_panel.visible = not tree_panel.visible
	if tree_panel.visible:
		_refresh_tree()


## 씨앗 나무 창: 가지마다 단계·다음 비용 버튼, 일반 판 적용 켜기·끄기, 분재, 속성 숙련.
func _refresh_tree() -> void:
	for c in tree_box.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "씨앗 나무 (Esc: 닫기)   씨앗 %d · 환생 %d번 · 정원 최고 웨이브 %d" % [Garden.seeds, Garden.rebirths, Garden.best_ever]
	head.add_theme_font_size_override("font_size", 19)
	tree_box.add_child(head)
	var desc := Label.new()
	desc.text = "정원에서 환생하면 씨앗(최고 웨이브 - %d)을 받아요. 가지를 올리면 일반 판을 더 강하게 시작해요.\n씨앗 나무를 쓴 판의 기록은 '성장'으로 따로 세고, 끄면 '순수' 기록이에요." % Garden.SEED_BASE
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tree_box.add_child(desc)
	for id in Garden.TREE_IDS:
		var d: Dictionary = Garden.TREE[id]
		var l := Garden.lv(id)
		var c := Garden.next_cost(id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(620, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 15)
		var lvs: Array = d["lv"]
		var now: String = lvs[0] if lvs.size() == 1 else ("—" if l == 0 else lvs[l - 1])
		if lvs.size() == 1 and l > 0:
			now = "%s x%d" % [lvs[0], l]
		var nxt: String = "다 올림" if c < 0 else "다음: %s · 씨앗 %d" % [lvs[0] if lvs.size() == 1 else lvs[l], c]
		b.text = "%s (%s) %d/%d   지금: %s   %s" % [d["name"], d["what"], l, Garden.max_lv(id), now, nxt]
		b.disabled = c < 0 or Garden.seeds < c
		b.pressed.connect(func():
			if Garden.buy(id):
				sfx.play("reaction", 0.0)
				_save_best()
				_refresh_tree()
				_refresh_menu())
		tree_box.add_child(b)
	var on := CheckButton.new()
	on.text = "일반 판에 씨앗 나무·숙련 쓰기 (끄면 '순수' 기록)"
	on.button_pressed = Garden.tree_on
	on.focus_mode = Control.FOCUS_NONE
	on.toggled.connect(func(v):
		Garden.tree_on = v
		_save_best()
		_refresh_menu())
	tree_box.add_child(on)
	var bl := Label.new()
	bl.text = "분재: " + Garden.bonsai_text() + ("" if Garden.lv("bonsai") > 0 else "  (분재 가지를 올리면 써요)")
	bl.add_theme_font_size_override("font_size", 14)
	tree_box.add_child(bl)
	var ms := PackedStringArray()
	for e in Elem.ALL:
		var key: String = Patch.ELEM_KEYS[Elem.ALL.find(e)]
		var n := float(Garden.mastery.get(key, 0.0))
		if n >= 1.0:
			var nx := Garden.mastery_next(e)
			ms.append("%s +%d%% (%s%s)" % [Elem.NAMES[e], roundi(Garden.mastery_bonus(e) * 100), Garden.short(n), "/" + Garden.short(nx) if nx > 0 else ""])
	var ml := Label.new()
	ml.text = "속성 숙련 (정원 처치 수 → 일반 판 그 속성 피해, 최대 +%d%%):\n%s" % [roundi(Garden.MASTERY_PER * Garden.MASTERY_STEPS.size() * 100), "아직 없음" if ms.is_empty() else " · ".join(ms)]
	ml.add_theme_font_size_override("font_size", 14)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size.x = 620
	tree_box.add_child(ml)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_toggle_tree)
	tree_box.add_child(close)


## 시작 화면: 저장된 정원 요약.
func _refresh_garden_menu() -> void:
	var info := _run_info(Garden.RUN_PATH)
	Garden.has_run = not info.is_empty()
	if Garden.has_run:
		Garden.run_wave = info["wave"]
		var gd: Variant = Meta.val(info["cfg"], "run", "garden", {})
		Garden.run_dew = float(gd.get("dew", 0.0)) if gd is Dictionary else 0.0
	garden_btn.text = Garden.menu_text()
	tree_btn.text = Garden.tree_btn_text()
