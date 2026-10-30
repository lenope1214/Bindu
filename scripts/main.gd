extends Node2D
## 게임 진행: 웨이브, 오브젝트 선택·설치, 충돌, 점수.

enum Phase { CHOOSE, PLACE, AIM, WAVE, GAMEOVER, MOVE, READY }

const CORE_RADIUS := 14.0
const SPIRAL_SWIRL := 0.6  # 소용돌이 맵: 구체가 중앙 방향에서 비껴 도는 각도(라디안)
const CORE_MAX_HP := 10
const MERGE_DIST := 30.0
const SAVE_PATH := "user://best.cfg"
const RUN_PATH := "user://run.cfg"  # 이어하기: 쉬는 시간마다 저장, 게임 오버면 지움
const RUN_FORMAT := 1
const READY_HINT := "Space 또는 [웨이브 시작]: 시작   오브젝트 클릭: 위치·방향 변경"
## 첫 판: 카드 종류가 열리는 웨이브 (그 웨이브 앞 쉬는 시간부터 나온다). 속성은 처음부터
const TUTOR_OPEN := {"pat": 3, "mod": 4, "link": 6, "cata": 6}
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
var box_start := Vector2.ZERO
var cards_hidden := false  # 선택지를 내려 필드를 보는 중
var hide_btn: Button
var move_orig_pos := Vector2.ZERO
var move_orig_dir := Vector2.RIGHT
var move_return := Phase.CHOOSE  # 옮기기를 끝내면 돌아갈 단계
var auto_start := false  # 끄면 설치 후 Space로 웨이브 시작
var auto_btn: Button
var start_btn: Button
var cancel_btn: Button  # 옮기기·설치 중 화면 취소 (우클릭·Esc가 없는 터치 화면용)
var wave_leaks: Array = []  # 이번 웨이브에 중앙에 닿은 구체 [나온 방향 번호, 종류, 피해]
var leak_log: Array = []  # 웨이브마다 누수 요약 (봇·통계·안내용)
var leak_flash: Array = []  # 화면 가장자리 붉은 번짐 [자리, 남은 시간]
var boss_plan := {}  # 다음 보스: 쉬는 시간에 진입 각도·체력·속도·저항을 미리 정해 길과 정보를 정확히 보여 준다
var touch_ui := false  # 마지막 입력이 터치였는지 (터치는 마우스를 올려 둘 수 없다)
var offer: Array = []  # 이번 선택지 [카드, ...] 카드: {"type": "elem"|"pat"|"mod"|"link", ...}
var picked := {}  # 고른 카드
var link_a: Tower = null  # 연결선의 첫 오브젝트
var place_pos := Vector2.ZERO

var towers: Node2D
var orbs: Node2D
var projectiles: Node2D
var zones: Node2D
var arcs: Array = []  # 전류 이펙트 [시작, 끝, 남은 시간]
var bolts: Array = []  # 연쇄 번개 [점 목록, 남은 시간]
var live_orbs: Array = []
var targets: Array = []  # 화면 안에 들어온 구체 (공격 대상)
var fx_layer: Node2D  # 피해 숫자·파편 (맨 위)
var popups: Array = []  # [위치, 글자, 남은 시간, 색, 큰 글씨]
var particles: Array = []  # [위치, 속도, 남은 시간, 색, 크기]
var camera: Camera2D
var shake := 0.0
var core_flash := 0.0
var eclipse_flash := 0.0  # 일식 순간 화면 어둡게
var core_disp := float(CORE_MAX_HP)  # 중앙 체력 표시(부드럽게 변함)
var kills := 0
var best_combo := 0
var sfx: Sfx
var mute_btn: Button
var stars := PackedVector3Array()  # 배경 점 (x, y, 밝기)

var hud: Label
var hint: Label
var ver_label: Label  # 왼쪽 아래 구석: 게임 버전 · 규칙 버전
var toast: Label
var toast_timer := 0.0
var banner: Label
var banner_t := 0.0
var banner_queue: Array = []  # 앞 글자가 떠 있는 동안 들어온 글자 [글, 색]
var choice_box: HBoxContainer
var over_label: Label
var legend: Label
var preview: Label
var reroll_btn: Button
var pause_btn: Button
var speed_btn: Button
var speed_pick: OptionButton
const SPEEDS := [2.0, 3.0, 4.0, 6.0, 8.0]
var game_speed := 1.0  # 지금 배속
var fast_speed := 2.0  # Space로 켜는 배속
var paused_label: Label
var pause_box: HBoxContainer  # 일시정지 창 아래 버튼 (계속·시작 화면·끄기)
var legend_hidden := false
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
	{"id": "regen", "name": "회복", "desc": "웨이브를 마칠 때마다 중앙 체력 +1"},
	{"id": "slow", "name": "끈적한 공간", "desc": "모든 구체 이동 속도 -8%"},
	{"id": "harmony", "name": "조화", "desc": "속성을 여러 종류 겹쳐 생기는 공격 속도 감소가 절반으로"},
]
var perks := {}  # id → 고른 횟수
var perk_mode := false
var perk_offer: Array = []
var orb_speed_mul := 1.0
var rerolls_left := 1
var bonus_rerolls := 0
var combo := 0
var combo_t := 0.0
var ui_font: Font
var perk_src := ""
var hud_wrap_key := ""
var hud_wrap := false
var perk_wrapped := ""
var title_label: Control  # 메인 메뉴
var continue_btn: Button  # 저장된 판이 있을 때만 보임
var new_btn: Button
var new_armed := 0.0  # 저장된 판이 있을 때 새로 시작은 두 번 눌러야 (실수로 지우지 않게)
var map_label: Label
var rules_label: Label
var skin_label: Label
var core_label: Label
var records_panel: Label
var settings_panel: PanelContainer
var new_achievements: Array = []  # 이번 판에 새로 달성한 업적 이름
var help_label: Label
var hover_elem := -1  # 마우스를 올린 선택지의 속성
var tip_orb: Node = null  # 마우스를 올린 구체 (그 구체만 체력 숫자를 보인다)
var range_all := false  # 터치 화면 [범위 보기]: Alt를 누른 것처럼 모든 오브젝트 범위·피해 몫
var range_btn: Button
var wave_time := 0.0  # 이번 웨이브 경과 시간
# 온라인 (Net·Patch): 판 기록·통계
var net: Net
var run_log: Array = []  # 선택지 기록 [{w, k: card|perk, o: 나온 것, p: 고른 것(새로고침이면 "")}]
var run_game := 0.0  # 웨이브 진행 게임 시간 합
var run_real := 0.0  # 실제로 플레이한 시간 (시작 화면·일시정지 빼고)
var update_btn: Button  # 시작 화면: 새 버전 받기
var notice_label: Label  # 시작 화면: 패치 공지
var board_lines := {}  # 리더보드 창: period → 줄 목록
static var title_seen := false  # 다시 시작하면 타이틀은 건너뛴다


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 입력·UI는 동작
	Tower.dmg_mul = 1.0
	Tower.spd_mul = 1.0
	Tower.reach_mul = 1.0
	sfx = Sfx.new()
	add_child(sfx)
	_load_best()
	if Meta.device_id == "":
		Meta.device_id = Crypto.new().generate_random_bytes(16).hex_encode()
		_save_best()
	Patch.load_cache()
	if Meta.games == 0:
		Meta.rules = 1  # 첫 판은 기본 규칙 (규칙 고르기는 첫 판 뒤에 보인다)
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
		stars.append(Vector3(randf() * 1280.0, randf() * 720.0, randf_range(0.03, 0.12)))
	_build_ui()
	_apply_volume()
	_update_speed_btn()
	net = Net.new()
	add_child(net)
	net.booted.connect(_on_booted)
	net.run_sent.connect(_on_run_sent)
	net.board_loaded.connect(_on_board_loaded)
	_on_booted(Net.info)  # 다시 시작했을 때: 이미 받아 둔 새 버전·공지
	# 창 제목에도 한글 이름과 버전 (작업 표시줄에서 어떤 빌드인지 보이게)
	get_window().title = "빈두 v%s" % ProjectSettings.get_setting("application/config/version", "?")
	if title_seen or DisplayServer.get_name() == "headless":
		_start_choose()
	else:
		title_label.visible = true
		_refresh_continue()
		hint.text = ""


## 창이 포커스를 잃어도 판은 계속 진행된다 (직접 조작이 없으니 멈추지 않음).
func _notification(what: int) -> void:
	# Android 뒤로가기 = Esc (한 단계 되돌리기 / 일시정지)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		Input.parse_input_event(esc)
	# 창을 닫거나 (모바일) 앱이 뒤로 가면 지금 쉬는 시간 상태를 한 번 더 저장 (옮긴 위치까지)
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED) and towers and title_label:
		_save_run()


func _layer(n: String) -> Node2D:
	var node := Node2D.new()
	node.name = n
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(node)
	return node


func center() -> Vector2:
	return get_viewport_rect().size / 2.0


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

	hud = Label.new()
	hud.position = Vector2(10, 6)
	# 구체가 위쪽을 지나가도 글자가 묻히지 않게 옅은 바탕
	var hsb0 := StyleBoxFlat.new()
	hsb0.bg_color = Color(0.02, 0.03, 0.05, 0.55)
	hsb0.set_corner_radius_all(5)
	hsb0.content_margin_left = 6
	hsb0.content_margin_right = 8
	hsb0.content_margin_top = 4
	hsb0.content_margin_bottom = 4
	hud.add_theme_stylebox_override("normal", hsb0)
	root.add_child(hud)

	hint = Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(16, -66)
	hint.size = Vector2(590, 44)  # 오른쪽 아래 설정 버튼 줄(펼쳤을 때 648)과 겹치지 않게
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
	choice_box.add_theme_constant_override("separation", 20)
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
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 긴 줄이 화면 밖으로 잘리지 않게
	legend.add_theme_font_size_override("font_size", 14)
	legend.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_refresh_legend()
	root.add_child(legend)

	reroll_btn = Button.new()
	reroll_btn.text = "선택지 새로고침 (Q)"
	reroll_btn.set_anchors_preset(Control.PRESET_CENTER)
	reroll_btn.position = Vector2(-170, 105)
	reroll_btn.size = Vector2(340, 36)
	reroll_btn.pressed.connect(_on_reroll)
	reroll_btn.visible = false
	root.add_child(reroll_btn)

	hide_btn = Button.new()
	hide_btn.focus_mode = Control.FOCUS_NONE
	hide_btn.add_theme_font_size_override("font_size", 14)
	hide_btn.pressed.connect(func(): _set_cards_hidden(not cards_hidden))
	hide_btn.visible = false
	root.add_child(hide_btn)

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
	mute_btn = Button.new()
	mute_btn.custom_minimum_size = Vector2(90, 36)
	mute_btn.pressed.connect(_toggle_mute)
	bar.add_child(mute_btn)
	auto_btn = Button.new()
	auto_btn.custom_minimum_size = Vector2(132, 36)
	auto_btn.pressed.connect(_toggle_auto)
	bar.add_child(auto_btn)
	pause_btn = Button.new()
	pause_btn.text = "일시정지 (P)"
	pause_btn.custom_minimum_size = Vector2(120, 36)
	pause_btn.pressed.connect(_toggle_pause)
	bar.add_child(pause_btn)
	speed_btn = Button.new()
	speed_btn.text = "x1 (Space)"
	speed_btn.custom_minimum_size = Vector2(106, 36)
	speed_btn.pressed.connect(_toggle_speed)
	bar.add_child(speed_btn)
	speed_pick = OptionButton.new()
	for sp in SPEEDS:
		speed_pick.add_item("빠르게 x%d" % roundi(sp))
	speed_pick.custom_minimum_size = Vector2(120, 36)
	speed_pick.focus_mode = Control.FOCUS_NONE
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
	root.add_child(start_btn)
	cancel_btn = Button.new()
	cancel_btn.text = "취소 (Esc)" if OS.has_feature("pc") else "취소"
	cancel_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cancel_btn.position = Vector2(-70, -100)  # 웨이브 시작 버튼 자리 (옮기기·설치 중엔 비어 있다)
	cancel_btn.size = Vector2(140, 40)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(_cancel_step)
	cancel_btn.visible = false
	root.add_child(cancel_btn)
	for b in [pause_btn, speed_btn, reroll_btn, auto_btn, start_btn, mute_btn, cancel_btn, bar_btn]:
		b.focus_mode = Control.FOCUS_NONE
	_update_auto_btn()
	mute_btn.text = "소리: " + ("끔" if sfx.muted else "켬") + " (M)"

	paused_label = Label.new()
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
	pause_box.set_anchors_preset(Control.PRESET_CENTER)
	pause_box.position = Vector2(-350, -150)  # 글 아래 (_process에서 글 높이에 맞춤)
	pause_box.size = Vector2(700, 44)
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 12)
	var pspecs := [["계속 (P)", _toggle_pause], ["시작 화면으로 (T)", _leave.bind(false)]]
	if OS.has_feature("pc"):
		pspecs.append(["게임 끄기 (X)", _leave.bind(true)])  # 모바일은 운영체제가 앱을 닫는다
	for spec in pspecs:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(170, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		pause_box.add_child(b)
	pause_box.visible = false
	root.add_child(pause_box)

	preview = Label.new()
	preview.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	preview.position = Vector2(16, -214)
	preview.size = Vector2(620, 144)
	preview.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	# 줄이 늘면 위로 자란다 (아래 안내 문구를 덮지 않게). 줄바꿈은 _update_preview에서 띄어쓰기 단위로
	preview.grow_vertical = Control.GROW_DIRECTION_BEGIN
	preview.add_theme_font_size_override("font_size", 15)
	root.add_child(preview)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-400, -140)
	banner.size = Vector2(800, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 40)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner.add_theme_constant_override("outline_size", 6)
	banner.visible = false
	root.add_child(banner)

	over_label = Label.new()
	over_label.set_anchors_preset(Control.PRESET_CENTER)
	over_label.position = Vector2(-450, -150)
	over_label.size = Vector2(900, 300)
	# 글줄이 900보다 길어져도 가운데를 지키며 양쪽으로 자란다
	over_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	over_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	over_label.add_theme_font_size_override("font_size", 26)
	over_label.visible = false
	root.add_child(over_label)

	_build_menu(root)

	help_label = Label.new()
	help_label.set_anchors_preset(Control.PRESET_CENTER)
	help_label.position = Vector2(-440, -300)
	help_label.size = Vector2(880, 600)
	help_label.add_theme_font_size_override("font_size", 16)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.05, 0.06, 0.09, 1.0)  # 뒤 카드·설명 글자가 비쳐 보이지 않게
	hsb.set_border_width_all(1)
	hsb.border_color = Color(1, 1, 1, 0.25)
	hsb.set_content_margin_all(18)
	hsb.set_corner_radius_all(6)
	help_label.add_theme_stylebox_override("normal", hsb)
	help_label.text = _help_text()
	help_label.visible = false
	root.add_child(help_label)


## 화면 가운데 크게 잠깐 뜨는 글자. 앞 글자가 아직 또렷하면 뒤에 세워 차례로 보여 준다
## (업적 직후 "웨이브 10"이 바로 덮어써 업적을 못 보던 것).
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


func _update_hud() -> void:
	var text := "웨이브 %d   점수 %s   중앙 %d/%d   최고 %s (웨이브 %d)" % [
		wave, num(score), maxi(core_hp, 0), core_max, num(best_score), best_wave]
	var extra := ""
	if Meta.rules != 1:
		extra += "   [%s]" % Rules.NAMES[Meta.rules]
	if not selected.is_empty():
		extra += "   선택 %d개" % selected.size()
	var nt := towers.get_child_count()
	if nt > 1:
		extra += "   무리 +%d%% (오브젝트 %d개)" % [roundi(Rules.crowd * (nt - 1) * 100), nt]
	# 길어지면 오른쪽 위 설명 버튼과 겹치므로 둘째 줄로. 글자 모양 계산은 비싸서
	# 길이나 덧붙인 내용이 바뀔 때만 다시 잰다 (점수 숫자만 바뀌면 폭은 거의 그대로)
	if extra != "":
		var key := "%d|%s" % [text.length(), extra]
		if key != hud_wrap_key:
			hud_wrap_key = key
			hud_wrap = ui_font.get_string_size(text + extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > 1080.0
		if hud_wrap:
			extra = "\n" + extra.strip_edges()
	text += extra
	if phase == Phase.WAVE:
		text += "\n남은 구체 %d" % (to_spawn + _alive_count(orbs))
	var pt := _perk_text()
	if pt != perk_src:
		perk_src = pt
		perk_wrapped = _wrap_words(pt, 1080.0, 18)  # 특성이 많아도 오른쪽 위 버튼까지 뻗지 않게
	if pt != "":
		text += "\n" + perk_wrapped
	if hud.text != text:
		hud.text = text
		hud.reset_size()  # 글자가 짧아져도 바탕이 넓게 남지 않게


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
	Tower.tax_step = Rules.tax_step
	if legend:
		_refresh_legend()
	if ver_label:
		ver_label.text = _ver_text()
	if help_label:
		help_label.text = _help_text()


## 도움말: 상한·장수는 고른 규칙 버전에 따라 다르다.
func _help_text() -> String:
	var elems := "속성 %d종까지, 레벨은 제한 없음" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "종류 제한 없음"
	var mods := "강화는 종류마다 %d개까지" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "강화는 제한 없이 쌓이지만 쌓을수록 효과가 절반씩"
	return "\n".join([
		"[조작]",
		"1 / 2 / 3 또는 클릭: 선택지 고르기     Q: 선택지 새로고침     V: 선택지 내리고 필드 보기",
		"속성 카드: 빈 곳에 설치(직선탄) → 클릭(또는 끌어서 놓기)으로 방향, Shift: 15도",
		"속성 카드를 오브젝트 위에: 속성 겹치기 (%s)" % elems,
		"공격방식·강화·연계 카드: 오브젝트 위에 놓기 (연결선은 두 개 차례로)",
		"오브젝트 끌기: 방향은 그대로 두고 옮기기 (카드를 고른 뒤에는 꾹 눌러서)",
		"빈 곳 끌기 / Shift·Ctrl+클릭 / Ctrl+A(모두): 여러 개 선택 → 그중 하나를 끌면 함께 이동",
		"쉬는 시간에 오브젝트 클릭: 위치·방향 다시 정하기",
		"Alt 누르고 있기: 모든 오브젝트의 공격 범위·피해 몫 보기     우클릭 / Esc: 한 단계 되돌리기, 선택 해제",
		"Space: 웨이브 시작(자동 시작 끔일 때) / 웨이브 중 빠르게 켜기·끄기 (배율은 오른쪽 아래에서 x2~x8)",
		"P / Esc: 일시정지(시작 화면으로·끄기)   M: 소리   O: 설정   Tab: 설명 보기·숨기기   H: 도움말   F11: 전체 화면",
		"R: 다시 시작 (게임 오버 뒤, 또는 일시정지 중 두 번)",
		"쉬는 시간마다 자동 저장: 게임을 꺼도 시작 화면의 이어하기(Enter)로 그 쉬는 시간부터 (새로 시작은 N 두 번)",
		"첫 판은 카드가 단계별로 열려요(공격방식 3·강화 4·연계 6웨이브). 처음 생기는 일엔 위쪽에 한 줄 안내 (설정에서 끄기·다시 보기)",
		"",
		"[규칙 · %s]" % Rules.NAMES[Rules.version],
		"중앙 체력 10. 구체가 닿으면 줄어듭니다",
		"쉬는 시간마다 3개 중 1개를 고릅니다 (처음 두 번은 2번)" if Rules.picks == 1 else "쉬는 시간마다 3개 중 1개씩 %d번 고릅니다" % Rules.picks,
		"5웨이브마다 보스. 처치하면 체력 +2, 새로고침 +1",
		"보스 웨이브를 넘기면 특성(전역 강화) 3개 중 1개 선택",
		"공격방식은 직선탄일 때 한 번만 정할 수 있고, 같은 것을 넣으면 레벨업",
		"속성을 많이 겹칠수록 피해는 늘고 공격 속도는 조금씩 느려집니다. %s" % mods,
	] + ([
		"강화 칸: 속성마다 칸이 있고(독·불·나무 1, 전기·빛·금속·어둠 2, 물·바람·얼음·땅 3) 2종을 섞으면 x1.5, 3종은 x2",
		"   연결선으로 받은 속성은 칸 절반. 강화는 무게만큼 칸을 씁니다 (유도·크기·속사 1, 관통·튕김·분열 2, 다중 발사 3)",
	] if Rules.mod_slots else []) + [
		"감속은 최대 70%, 밀기는 조금씩만, 기절·속박·빙결은 연달아 걸리면 짧아지다 잠깐 면역",
		"화면 밖 구체는 맞지 않습니다. 시작 화면에서 규칙 버전(↑/↓)과 맵(←/→)을 바꿀 수 있어요",
	])


## 실행 중인 빌드가 최신인지 알아보도록 구석에 표시 (버전은 project.godot의 config/version).
func _ver_text() -> String:
	return "빈두 v%s · 규칙 %s" % [ProjectSettings.get_setting("application/config/version", "?"), Rules.NAMES[Meta.rules]]


## 웨이브 구체 수: 3 + 2w. 첫 웨이브는 70%에서 시작해 10웨이브에 100%가 된다 (초반에 판이 끝나지 않게).
static func wave_size(w: int) -> int:
	return roundi((3 + w * 2) * lerpf(0.7, 1.0, clampf((w - 1) / 9.0, 0.0, 1.0)))


## 실제로 나오는 구체 수 (규칙 버전 배율, 십자로 맵 1.5배). 미리보기와 웨이브가 같은 값을 쓴다.
static func spawn_count(w: int) -> int:
	var n := roundi(wave_size(w) * Rules.orb_mul)
	# 새 진입 방향이 열리는 웨이브는 구체를 조금 덜 (새 길목을 막을 시간)
	if Meta.map_id != "cross" and lanes_for(w) > lanes_for(w - 1):
		n = roundi(n * 0.8)
	if Meta.map_id == "cross":
		n = roundi(n * 1.5)
	return n


## 웨이브 w의 진입 방향 수: 3웨이브마다 하나씩 늘어 4곳, 이후 6웨이브마다 하나씩 최대 6곳.
## 새 구체 종류(빠른 4·단단한 7·보호막 8·분열 12)와 겹치지 않게 3·6·9웨이브(이후 18·24)에 열린다.
static func lanes_for(w: int) -> int:
	return mini(mini(1 + w / 3, 4 + maxi(0, (w - 12) / 6)), 6)


func _start_choose(new_round := true) -> void:
	if new_round and wave == 0:
		# 새 판. 헤드리스(봇·점검)는 늘 모두 열린 채로
		tutor = Meta.tutor_next and DisplayServer.get_name() != "headless"
		tutor_given = {}
	if new_round and tutor and wave + 1 >= TUTOR_OPEN.values().max() and Meta.tutor_next:
		Meta.tutor_next = false  # 모두 열렸다: 다음 판부터는 처음부터 모두
		_save_best()
	if new_round:
		_roll_lanes()
		# 다음 웨이브 저항 속성: 12웨이브(버전 4는 8)부터 60% 확률
		wave_resist = Elem.ALL.pick_random() if wave + 1 >= Rules.resist_from and randf() < 0.6 else -1
		_plan_boss()
		picks_left = 2 if wave <= 1 else Rules.picks  # 처음 두 번의 쉬는 시간은 2개씩
		rerolls_left = 1 + bonus_rerolls + perks.get("reroll", 0) * int(_perk_val("reroll"))
		bonus_rerolls = 0
	phase = Phase.CHOOSE  # 웨이브를 막 끝낸 때도 카드 안내가 쉬는 시간 안내로 뜨게 (_open_choose가 다시 정함)
	_make_choices()
	_open_choose()
	_save_run()
	if new_round:
		_rest_guides()


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
	hint.text = _choose_hint()


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
		# 넣을 곳이 없는 공격방식·강화 카드는 내지 않는다
		if card["type"] in ["pat", "mod"] and not towers.get_children().any(func(t): return t.can_take(card)):
			continue
		# 같은 속성은 레벨만 다르게 두 장 나오지 않게: 높은 레벨 한 장만 남긴다
		var same := offer.filter(func(cd): return _card_key(cd) == _card_key(card))
		if same.is_empty():
			offer.append(card)
		elif card.get("lv", 1) > same[0].get("lv", 1):
			offer[offer.find(same[0])] = card
	# 속성 카드(새 오브젝트를 놓을 수 있는 카드)는 최소 1장
	if not offer.any(func(cd): return cd["type"] == "elem"):
		offer[randi() % offer.size()] = {"type": "elem", "e": Elem.ALL.pick_random(), "lv": 1}
	if tutor:
		_tutor_offer()
	_show_offer()
	_card_guides()


## 첫 판: 이번 웨이브에 새로 열린 카드 종류를 처음 한 번은 선택지에 꼭 넣는다 (속성 카드 하나는 남김).
func _tutor_offer() -> void:
	for k in ["pat", "mod", "link"]:
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
		"link": ids = ["link"] if towers.get_child_count() >= 2 else ["prism", "reso"]
	ids.shuffle()
	for id in ids:
		var cd := {"type": k, "id": id}
		if k == "link" or towers.get_children().any(func(t): return t.can_take(cd)):
			return cd
	return {}


## 첫 판에는 아직 안 열린 카드 종류.
func _card_open(k: String) -> bool:
	return not tutor or wave + 1 >= TUTOR_OPEN[k]


## 선택지 카드 버튼을 offer대로 다시 만든다.
func _show_offer() -> void:
	for c in choice_box.get_children():
		c.queue_free()
	for i in offer.size():
		choice_box.add_child(_card_button(offer[i], i + 1))


## 같은 선택지인지 비교하는 키 (레벨은 무시).
func _card_key(card: Dictionary) -> String:
	return "%s:%s" % [card["type"], card.get("e", card.get("id", ""))]


## 선택지 한 장: 속성 / 공격방식 / 강화 / 연계 중 하나.
func _roll_card() -> Dictionary:
	var n := towers.get_child_count()
	var cata := Patch.num("cards", "cata", 0.01)
	if n > 0 and wave > 0 and _card_open("cata"):
		# 대격변: 각각 1%
		var c := randf()
		if c < cata:
			return {"type": "cata", "id": "elem"}
		if c < cata * 2.0:
			return {"type": "cata", "id": "pat"}
	# 종류 비율 (온라인 패치 cards로 바뀔 수 있음): 속성 42%, 공격방식 25%, 강화 23%, 연계 10%
	var we := Patch.num("cards", "elem", 0.42)
	var wp := Patch.num("cards", "pat", 0.25) if _card_open("pat") else 0.0
	var wm := Patch.num("cards", "mod", 0.23) if _card_open("mod") else 0.0
	var r := randf() * (we + wp + wm + (Patch.num("cards", "link", 0.10) if _card_open("link") else 0.0))
	if n == 0 or wave == 0 or r < we:
		var lv2 := minf(Patch.num("cards", "lv2_base", 0.2) + Patch.num("cards", "lv2_wave", 0.02) * wave, Patch.num("cards", "lv2_max", 0.5))
		var lv := 2 if randf() < lv2 + _perk_val("luck") * perks.get("luck", 0) else 1
		return {"type": "elem", "e": Elem.ALL.pick_random(), "lv": lv}
	if r < we + wp:
		return {"type": "pat", "id": Pat.PATTERN_IDS.slice(1).pick_random()}
	if r < we + wp + wm:
		return {"type": "mod", "id": Pat.MOD_IDS.pick_random()}
	var ids: Array = Pat.LINK_IDS.duplicate() if n >= 2 else ["prism", "reso"]
	return {"type": "link", "id": ids.pick_random()}


func _card_color(card: Dictionary) -> Color:
	match card["type"]:
		"elem": return Elem.COLORS[card["e"]]
		"pat": return Pat.pcolor(card["id"]).lightened(0.15)
		"mod": return Color(1, 0.82, 0.4)
		"cata": return Color(1, 0.45, 0.9)
	return Color(0.55, 0.9, 1.0)


func _card_button(card: Dictionary, idx: int) -> Button:
	var col := _card_color(card)
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 170)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.15, 0.96)
	sb.border_color = Color(col, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(0.16, 0.17, 0.22, 0.98)
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
	match card["type"]:
		"cata":
			if card["id"] == "elem":
				b.text = "[%d] ★ 대격변: 속성 ★\n설치된 모든 오브젝트의 속성을\n하나씩 무작위로 다시 뽑는다\n같은 속성이 나오면 레벨 +1\n(희귀 1%%, 고르면 바로 발동)" % idx
			else:
				b.text = "[%d] ★ 대격변: 공격방식 ★\n모든 오브젝트의 공격방식을\n직선탄을 뺀 무작위로 바꾼다\n고정·직선탄도 바뀜, 레벨 유지\n(희귀 1%%, 고르면 바로 발동)" % idx
		"elem":
			var e: int = card["e"]
			b.text = "[%d] 속성: %s%s%s\n부가: %s\n빈 곳: 새 오브젝트(직선탄)\n오브젝트 위: 겹치기%s" % [idx, Elem.NAMES[e], " Lv2" if card["lv"] == 2 else "", " · 강화 칸 %d" % Rules.ELEM_SLOTS[e] if Rules.mod_slots else "", Elem.RIDER[e], " (%d종까지)" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else ""]
			var combos := _combos_for(e)
			if not combos.is_empty():
				b.text += "\n" + "\n".join(combos.slice(0, 2))
		"pat":
			var id: String = card["id"]
			b.text = "[%d] 공격방식: %s\n%s\n직선탄 오브젝트에 넣으면 이 형태로 고정\n같은 공격방식에 넣으면 레벨업" % [idx, Pat.pname(id), Pat.PATTERNS[id]["desc"]]
			var fits := PackedStringArray()
			for t in towers.get_children():
				if t.pattern == id:
					fits.append("%s Lv%d → Lv%d 가능" % [Pat.pname(id), t.plv, t.plv + 1])
			if fits.is_empty() and not towers.get_children().any(func(t): return t.pattern == Pat.DEFAULT):
				fits.append("넣을 수 있는 오브젝트 없음")
			if not fits.is_empty():
				b.text += "\n" + fits[0]
		"mod":
			var id: String = card["id"]
			b.text = "[%d] 강화: %s\n%s\n오브젝트 위에 놓기\n%s" % [idx, Pat.MODS[id]["name"], Pat.MODS[id]["desc"], ("(강화 칸 %d칸 씀 · 종류별 %d개까지)" % [Rules.MOD_WEIGHT[id], Rules.max_mod] if Rules.mod_slots else "(종류별 %d개까지)" % Rules.max_mod) if Rules.max_mod < Rules.NO_CAP else "(쌓을수록 효과 절반씩)"]
		"link":
			var id: String = card["id"]
			b.text = "[%d] 연계: %s\n%s\n%s" % [idx, Pat.LINKS[id]["name"], Pat.LINKS[id]["desc"], "오브젝트 두 개를 차례로 클릭" if id == "link" else "오브젝트 위에 놓기"]
	b.text = _wrap_words(b.text, 220.0, 15)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE  # 다른 버튼처럼: Space·Enter가 카드를 고르지 않게
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.pressed.connect(_on_pick.bind(card))
	if card["type"] == "elem":
		b.mouse_entered.connect(func(): hover_elem = card["e"])
		b.mouse_exited.connect(func(): hover_elem = -1)
	return b


## 고르기 안내. 이번 쉬는 시간에 더 고를 수가 있으면 첫 줄에 붙인다 (V 줄 끝에 붙어 내리기 횟수처럼 읽히던 것).
func _choose_hint() -> String:
	var left := " (%d개 남음)" % picks_left if picks_left > 1 else ""
	return "선택지를 고르세요%s. 설치된 오브젝트를 클릭하면 위치·방향 변경\nV: 선택지 내리기" % left


# ---------- 처음 안내 ----------

## 처음 생기는 일에 한 줄 안내. 안내마다 한 번만(Meta.guide_seen), 설정에서 끌 수 있다.
## 쉬는 시간 안내는 웨이브가 시작될 때까지, 웨이브 중 안내는 8초 보인다(쉬는 시간 안내가 붙으면 함께 남음). 많아야 3개.
func _guide(id: String, text: String) -> void:
	if not Meta.guide_on or Meta.guide_seen.has(id) or title_label.visible:
		return
	var first := Meta.guide_seen.is_empty()
	Meta.guide_seen[id] = true
	_save_best()
	guide_lines.append(text)
	if first:
		guide_lines.append("이런 안내는 처음 한 번만 나와요. 설정(O)에서 끌 수 있어요")
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
		_guide("stack", "속성 카드를 오브젝트 위에 놓으면 겹쳐져요. 같은 속성은 레벨업, 다른 속성은 부가효과가 더해지고, 맞는 두 속성이 만나면 특수 반응이 생겨요")
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
		_guide("link", "새 카드 · 연계: 연결선은 두 오브젝트를 이어 속성을 나눠 쓰게 하고, 프리즘·공명은 오브젝트 위에 놓아 주변을 도와요")


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
func _start_perk() -> void:
	var pool: Array = PERKS.duplicate()
	pool.shuffle()
	perk_offer = pool.slice(0, 3)
	_show_perks()
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
		b.text = _wrap_words("[%d] 특성: %s\n\n%s%s" % [i + 1, pk["name"], _perk_desc(pk), "\n\n(보유 %d)" % have if have > 0 else ""], 220.0, 17)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
		b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_perk.bind(pk))
		choice_box.add_child(b)
	cards_hidden = false
	choice_box.visible = true
	reroll_btn.visible = false
	hint.text = "특성을 하나 고르세요. 이번 판 끝까지 유지됩니다"


func _on_perk(pk: Dictionary) -> void:
	if not perk_mode:
		return
	perk_mode = false
	var id: String = pk["id"]
	perks[id] = perks.get(id, 0) + 1
	run_log.append({"w": wave, "k": "perk", "o": perk_offer.map(func(x): return "perk:" + x["id"]), "p": "perk:" + id})
	match id:
		"power": Tower.dmg_mul += _perk_val("power")
		"haste": Tower.spd_mul += _perk_val("haste")
		"reach": Tower.reach_mul += _perk_val("reach")
		"core":
			core_max += int(_perk_val("core"))
			core_hp = core_max
		"slow": orb_speed_mul *= 1.0 - _perk_val("slow")
		"harmony": Tower.tax_step *= _perk_val("harmony")
	sfx.play("reaction", 0.0)
	_show_toast("특성: %s (%s)" % [pk["name"], _perk_desc(pk)])
	for t in towers.get_children():
		t.queue_redraw()
	_start_choose()


## 특성 수치 (온라인 패치 perks로 바뀔 수 있음). 설명 글도 같이 바꿔야 하면 perk_desc.
const PERK_VALS := {"power": 0.15, "haste": 0.12, "reach": 0.12, "core": 3, "reroll": 1, "luck": 0.2, "regen": 1, "slow": 0.08, "harmony": 0.5}


func _perk_val(id: String) -> float:
	return Patch.num("perks", id, PERK_VALS[id])


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
	if rerolls_left <= 0:
		_show_toast("이번 쉬는 시간의 새로고침을 다 썼어요")  # Q를 눌러도 아무 일이 없던 것
		return
	rerolls_left -= 1
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
	if perk_mode:
		reroll_btn.visible = false
	else:
		_update_reroll_btn()


func _update_reroll_btn() -> void:
	reroll_btn.visible = rerolls_left > 0 and not cards_hidden
	reroll_btn.text = "선택지 새로고침 (Q) · %d회 남음" % rerolls_left


## 진입 방향은 웨이브마다 조금씩 늘고, 가끔 하나가 옮겨 간다.
func _roll_lanes() -> void:
	var n := lanes_for(wave + 1)
	if Meta.map_id == "cross":
		# 십자로: 처음부터 네 방향 고정
		if lanes.size() != 4:
			var r0 := randf() * TAU
			lanes = [r0, r0 + PI / 2, r0 + PI, r0 + PI * 1.5]
		return
	if Meta.map_id == "storm":
		# 폭풍: 매번 전부 새로
		lanes.clear()
	if not lanes.is_empty() and randf() < 0.25:
		lanes.remove_at(randi() % lanes.size())
	while lanes.size() < n:
		lanes.append(_free_lane())


## 다른 방향과 0.8 이상 떨어진 새 방향. 자리가 모자라면 가장 넓은 틈의 가운데에 둔다
## (6곳이 될 때 기존 방향이 고르게 퍼져 있으면 빈자리가 없어 게임이 멈추던 것).
func _free_lane() -> float:
	for i in 40:
		var a := randf() * TAU
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
func _combos_for(e: int) -> PackedStringArray:
	var out := PackedStringArray()
	# 속성 이름을 늘어놓지 않고 짧게: 생길 반응 이름과 레벨업 가능한 곳 수만 (대상은 판에 표시)
	var names := PackedStringArray()
	var ups := 0
	for t in towers.get_children():
		for r in Elem.new_reactions(t.elements, e):
			if not names.has(r["name"]):
				names.append(r["name"])
		if t.elements.has(e):
			ups += 1
	if not names.is_empty():
		out.append("반응: " + ", ".join(names.slice(0, 3)) + (" 외" if names.size() > 3 else ""))
	if ups > 0:
		out.append("%s 레벨업 가능 %d곳" % [Elem.NAMES[e], ups])
	return out


func _els_name(t: Tower) -> String:
	var parts := PackedStringArray()
	for e in t.order:
		parts.append(Elem.NAMES[e])
	return "·".join(parts)


## 다음 웨이브 안내.
func _update_preview() -> void:
	var nw := wave + 1
	var lines := PackedStringArray()
	var lk := _leak_text()
	if lk != "":
		lines.append(lk)
	lines.append("다음 웨이브 %d: 구체 %d개, 진입 방향 %d곳" % [nw, spawn_count(nw), lanes.size()])
	var mix := PackedStringArray()
	if nw >= 4:
		mix.append("빠른 구체(뾰족)")
	if nw >= 7:
		mix.append("단단한 구체(네모)")
	if nw >= 8:
		mix.append("보호막")
	if nw >= 12:
		mix.append("분열")
	if not mix.is_empty():
		lines.append("섞여 나옴: " + ", ".join(mix))
	var sp := PackedStringArray()
	if wave_resist >= 0:
		sp.append("%s 저항 %d%%" % [Elem.NAMES[wave_resist], roundi(resist_share(nw) * 100)])
	if sturdy_share(nw) > 0.0:
		sp.append("굳셈 %d%%" % roundi(sturdy_share(nw) * 100))
	if nw > 10:
		sp.append("체력 x%.1f" % hp_growth(nw))
	if not sp.is_empty():
		lines.append("특수: " + " · ".join(sp))
	var firsts := {4: "빠른 구체", 7: "단단한 구체", 8: "보호막 두른 구체(먼저 보호막을 깎아야 함)", 12: "분열 구체(터지면 둘로 나뉨)", 11: "이제부터 구체 체력이 웨이브마다 %d%%씩 곱으로 늘어남" % roundi((Rules.hp_growth - 1.0) * 100)}
	for f in [[Rules.resist_from, "저항 구체(같은 색 점선 고리: 그 속성 비중만큼 피해 최대 60% 감소)"], [Rules.sturdy_from, "굳센 구체(회색 쐐기: 밀기·감속·기절·냉기 절반)"]]:
		firsts[f[0]] = (firsts[f[0]] + ", " if firsts.has(f[0]) else "") + f[1]
	if firsts.has(nw):
		lines.append("처음 등장: " + firsts[nw])
	if nw % 5 == 0:
		lines.append(_boss_text())
	else:
		var bw := ceili(nw / 5.0) * 5
		lines.append("다음 보스: 웨이브 %d (%d웨이브 뒤)" % [bw, bw - wave])
	if wave == 0:
		lines.append("빨간 화살표 방향에서 구체가 와요. 길목을 가로지르게 설치하세요.")
	# 자동 줄바꿈은 한글 낱말 중간에서도 끊으므로 띄어쓰기에서 직접 바꾼다
	preview.text = _wrap_words("\n".join(lines), 610.0, 15)
	preview.add_theme_color_override("font_color", Color(1, 0.75, 0.75) if nw % 5 == 0 else Color(1, 1, 1, 0.85))


## 보스 길이(화면 밖 출발점부터 중앙까지)와 막지 않을 때 걸리는 시간.
func _boss_eta() -> float:
	var pts := _orb_path(boss_plan["a"])
	var L := 0.0
	for i in range(1, pts.size()):
		L += pts[i - 1].distance_to(pts[i])
	L -= CORE_RADIUS + 30.0  # 보스 반지름만큼 먼저 닿는다
	return L / (boss_plan["spd"] * 0.45 * orb_speed_mul)


## 다음 보스 안내 (쉬는 시간에 미리 뽑아 둔 그대로).
func _boss_text() -> String:
	if boss_plan.is_empty():
		return "보스 등장! 중앙에 닿으면 체력 3 감소"
	var sp := PackedStringArray(["보스: 체력 %s" % num(ceilf(boss_plan["hp"] * 12.0))])
	if boss_plan["resist"] >= 0:
		sp.append("%s 저항" % Elem.NAMES[boss_plan["resist"]])
	if boss_plan["sturdy"]:
		sp.append("굳셈")
	sp.append("웨이브 마지막에 나옴")
	sp.append("%d초마다 빠른 부하" % roundi(Orb.minion_every(boss_plan["wave"])))
	return " · ".join(sp) + "\n보스 길: 화면의 굵은 분홍 선. 막지 않으면 나온 뒤 약 %d초에 중앙 (닿으면 체력 -3)" % roundi(_boss_eta())


## 보스가 올 길: 쉬는 시간과, 보스 웨이브에서 보스가 나오기 전까지.
func _draw_boss_path(now: float) -> void:
	if boss_plan.is_empty() or title_label.visible or phase == Phase.GAMEOVER:
		return
	if phase == Phase.WAVE and boss_plan["wave"] != wave:
		return
	var col := Color(1, 0.35, 0.6)
	var vr := get_viewport_rect()
	var all := _orb_path(boss_plan["a"])
	# 화면 안에 들어온 뒤부터 그린다 (직선은 화면 가장자리에서 자름)
	var pts := PackedVector2Array()
	if all.size() == 2:
		pts.append(_edge_point(center(), Vector2.from_angle(boss_plan["a"])))
		pts.append(all[1])
	else:
		for p in all:
			if not pts.is_empty() or vr.has_point(p):
				pts.append(p)
	if pts.size() < 2:
		return
	var pulse := 0.75 + 0.25 * sin(now * 3.0)
	draw_polyline(pts, Color(col, 0.16 * pulse), 14.0)
	draw_polyline(pts, Color(col, 0.8 * pulse), 3.0)
	# 보스가 오는 쪽으로 흐르는 화살 (길이 비율로 놓는다)
	var lens: Array[float] = [0.0]
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i - 1].distance_to(pts[i]))
	var total: float = lens[-1]
	for k in 7:
		var dpos := fmod(now * 0.12 + k / 7.0, 1.0) * (total - CORE_RADIUS - 20.0)
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
	if side.dot(m - center()) < 0.0:
		side = -side
	var lp := m + side * 30.0 + Vector2(-w / 2.0 if absf(side.x) < 0.5 else (0.0 if side.x > 0.0 else -w), 6.0)
	lp = lp.clamp(Vector2(8, 70), vr.size - Vector2(w + 8, 70))
	draw_string_outline(ui_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(ui_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.75, 0.85))


func _on_pick(card: Dictionary) -> void:
	if card["type"] == "cata":
		_cataclysm(card["id"])
		return
	picked = card
	link_a = null
	hover_elem = -1
	choice_box.visible = false
	reroll_btn.visible = false
	phase = Phase.PLACE
	hint.text = _place_hint()


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
	run_log.append({"w": wave, "k": "card", "o": offer.map(_stat_key), "p": _stat_key(card) if not card.is_empty() else ""})


func _place_hint() -> String:
	match picked.get("type", "elem"):
		"elem":
			return PLACE_HINT
		"link":
			if picked["id"] == "link":
				return ("연결할 두 번째 오브젝트 클릭 (%d 이내)" % int(Rules.link_range) if link_a else "연결할 첫 오브젝트 클릭") + "   꾹 누르기·끌기: 옮기기\n우클릭/Esc: 다시 고르기"
	return "넣을 오브젝트를 클릭   꾹 누르기·끌기: 옮기기\n우클릭/Esc: 다시 고르기"


## card: 이번에 넣은 카드 (대격변은 picked를 거치지 않아 따로 넘긴다).
func _after_place(card: Dictionary = {}) -> void:
	_log_offer(picked if card.is_empty() else card)
	_check_progress()
	picks_left -= 1
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
	hint.text = READY_HINT
	_save_run()


func _start_wave_from_ready() -> void:
	if phase == Phase.READY:
		_start_wave()


func _toggle_mute() -> void:
	sfx.muted = not sfx.muted
	mute_btn.text = "소리: " + ("끔" if sfx.muted else "켬") + " (M)"
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


func _toggle_bar() -> void:
	bar_open = not bar_open
	_save_best()


func _update_auto_btn() -> void:
	auto_btn.text = "자동 시작: " + ("켬" if auto_start else "끔")


func _start_wave() -> void:
	countdown = -1.0
	_drop_press()
	boxing = false
	selected.clear()
	start_btn.visible = false
	wave += 1
	phase = Phase.WAVE
	wave_active = true
	choice_box.visible = false
	reroll_btn.visible = false
	to_spawn = spawn_count(wave)
	wave_leaks.clear()
	if guide_t < 0.0:
		guide_lines.clear()
		guide_t = 0.0
	for w in [10, 15, 20]:
		if wave >= w:
			_achieve("wave%d" % w)
	spawn_interval = maxf(0.35, 1.2 - wave * 0.06)
	spawn_timer = 0.5
	wave_time = 0.0
	for t in towers.get_children():
		t.cd.clear()
		t.fx.clear()
		t.run_dealt += t.dealt
		t.dealt = 0.0
		t.rx_dealt = 0.0
		t.queue_redraw()  # 레벨 숫자는 쉬는 시간에만
	hint.text = ""
	big_banner("웨이브 %d" % wave, Color.WHITE)
	sfx.play("wave", 0.0)


func _game_over() -> void:
	_log_wave()
	phase = Phase.GAMEOVER
	over_ms = Time.get_ticks_msec()
	wave_active = false
	game_speed = 1.0
	_update_speed_btn()
	banner_queue.clear()  # 남은 가운데 글자가 게임 오버 글 위에 뜨지 않게 (새 업적은 아래 글에 나옴)
	banner_t = minf(banner_t, 0.4)
	# 기록은 지금 맵·규칙 버전의 저장값과 비교한다 (다른 키에서 남은 값이 섞이지 않게)
	var prev := Meta.best_of(Meta.key())
	var record := "  최고 기록!" if score > prev[1] or wave > prev[0] else ""
	best_score = maxi(score, prev[1])
	best_wave = maxi(wave, prev[0])
	Meta.total_kills += kills
	Meta.games += 1
	if tutor:
		Meta.tutor_next = false
	_save_best()
	_clear_run()
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
	over_label.text = "게임 오버 (%s · %s)\n웨이브 %d · 점수 %s%s\n처치 %s · 최고 콤보 %d · 오브젝트 %d개%s%s\nR 또는 클릭: 다시 시작   Esc: 메뉴" % [Meta.MAPS[Meta.map_id]["name"], Rules.NAMES[Meta.rules], wave, num(score), record if record != "" else "   (최고 웨이브 %d)" % best_wave, num(kills), best_combo, towers.get_child_count(), mvp, ach]
	over_label.visible = true
	_submit_run()
	sfx.play("over", 0.0)
	reroll_btn.visible = false
	choice_box.visible = false
	hint.text = ""


# ---------- 입력 ----------

## 터치인지 마우스인지 기억한다 (터치에서 흉내 낸 마우스 움직임은 장치 번호가 EMULATION).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_ui = true
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		touch_ui = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_O:
			_toggle_settings()
			return
		if event.keycode == KEY_ESCAPE and (settings_panel.visible or records_panel.visible or help_label.visible):
			settings_panel.visible = false
			records_panel.visible = false
			help_label.visible = false
			return
		if title_label.visible:
			match event.keycode:
				KEY_H:
					help_label.visible = not help_label.visible
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
				get_tree().reload_current_scene()
			return
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif event.keycode == KEY_R and get_tree().paused:
			if restart_armed > 0.0:
				get_tree().paused = false
				get_tree().reload_current_scene()
			else:
				restart_armed = 2.0
				paused_label.text = _pause_text() + "\nR을 한 번 더 누르면 처음부터"
		elif event.keycode == KEY_T and get_tree().paused:
			_leave(false)
		elif event.keycode == KEY_X and get_tree().paused and OS.has_feature("pc"):
			_leave(true)
		elif event.keycode == KEY_H:
			help_label.visible = not help_label.visible
		elif event.keycode == KEY_TAB:
			_toggle_legend()
		elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3] and phase == Phase.CHOOSE and help_label.visible == false:
			var i: int = event.keycode - (KEY_KP_1 if event.keycode >= KEY_KP_1 else KEY_1)
			if perk_mode:
				if i < perk_offer.size():
					_on_perk(perk_offer[i])
			elif i < offer.size():
				_on_pick(offer[i])
		elif event.keycode == KEY_Q and phase == Phase.CHOOSE and not perk_mode:
			_on_reroll()
		elif event.keycode == KEY_V and phase == Phase.CHOOSE:
			_set_cards_hidden(not cards_hidden)
		elif event.keycode == KEY_A and (event.ctrl_pressed or event.meta_pressed) and phase in [Phase.CHOOSE, Phase.READY] and not perk_mode:
			# 모두 선택: 한꺼번에 옮길 때
			selected = towers.get_children()
			_restore_hint()
		elif event.keycode == KEY_R and phase == Phase.GAMEOVER:
			if Time.get_ticks_msec() - over_ms > 800:
				get_tree().reload_current_scene()
		elif event.keycode == KEY_M:
			_toggle_mute()
		elif event.keycode == KEY_SPACE and phase == Phase.READY:
			_start_wave()
		elif event.keycode == KEY_SPACE and phase == Phase.WAVE:
			_toggle_speed()
		elif event.keycode == KEY_SPACE and phase == Phase.CHOOSE:
			_show_toast(("특성을" if perk_mode else "선택지를") + " 먼저 고르세요 (1·2·3 또는 클릭)")
		elif event.keycode == KEY_ESCAPE and (phase in [Phase.PLACE, Phase.AIM, Phase.MOVE] or press_t or boxing or (not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY])):
			_cancel_step()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			_toggle_pause()
	if get_tree().paused:
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
	if event.button_index == MOUSE_BUTTON_RIGHT and (press_t or boxing or (not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY])):
		_cancel_step()
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
			get_tree().reload_current_scene()
		return
	var mpos := get_global_mouse_position()
	if perk_mode:
		return
	if phase in [Phase.CHOOSE, Phase.READY] and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tower_at(mpos)
		if t:
			# 짧게 클릭: 옮기기(클릭으로 위치·방향), Shift/Ctrl+클릭: 선택에 더하기·빼기, 끌기: 바로 이동
			_begin_press(t, mpos)
		else:
			# 빈 곳을 끌면 선택 상자
			boxing = true
			box_start = mpos
		return
	if phase == Phase.MOVE:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mpos = mpos.clamp(field_rect().position, field_rect().end)
			if mpos.distance_to(center()) < 50.0:
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
			hint.text = "클릭 또는 끌어서 놓기: 방향 확정 (Shift: 15도 단위) (색칠된 곳이 공격 범위)\n우클릭/Esc: 옮기기 취소"
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
		if mpos.distance_to(center()) < 50.0:
			_show_toast("중앙 점에 너무 가까워요")
			return
		if picked["type"] != "elem":
			_apply_card(target)
			return
		else:
			place_pos = mpos
			phase = Phase.AIM
			aim_start_ms = Time.get_ticks_msec()
			hint.text = "클릭 또는 끌어서 놓기: 발사 방향 확정 (Shift: 15도 단위) (색칠된 곳이 공격 범위)\n우클릭/Esc: 위치 다시 고르기"
	elif phase == Phase.AIM:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_aim()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_step()
	elif phase == Phase.PLACE and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_step()


## 고른 카드를 오브젝트에 넣는다 (PLACE에서 오브젝트를 짧게 클릭).
func _place_on(target: Tower) -> void:
	if picked["type"] != "elem":
		_apply_card(target)
		return
	if not target.can_take(picked):
		_show_toast(target.refuse_text(picked))
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
		hint.text = "끌어서 옮기는 중%s: 놓으면 그 자리에 둠 (방향은 그대로)\n우클릭/Esc: 취소" % (" (%d개)" % drag_group.size() if drag_group.size() > 1 else "")
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
	if o.position.distance_to(center()) < 50.0:
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
			if r.grow(Tower.RADIUS * 0.5).has_point(t.position) and not t in selected:
				selected.append(t)
	_restore_hint()


## 단계에 맞는 안내 문구로 되돌린다 (선택 중이면 선택 안내).
func _restore_hint() -> void:
	selected = selected.filter(func(t): return is_instance_valid(t))
	match phase:
		Phase.PLACE:
			hint.text = _place_hint()
		Phase.CHOOSE:
			hint.text = _choose_hint()
		Phase.READY:
			hint.text = READY_HINT
	if not selected.is_empty() and phase in [Phase.CHOOSE, Phase.READY, Phase.PLACE]:
		hint.text = "선택 %d개: 선택한 오브젝트 하나를 끌면 함께 이동\nShift/Ctrl+클릭: 더하기·빼기   Ctrl+A: 모두   Esc/우클릭: 선택 해제" % selected.size()


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
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	title_label.add_child(box)
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
	box.add_child(desc)
	map_label = _menu_row(box, func(): _cycle_map(-1), func(): _cycle_map(1))
	rules_label = _menu_row(box, func(): _cycle_rules(-1), func(): _cycle_rules(1))
	skin_label = _menu_row(box, func(): _cycle_skin("tower", -1), func(): _cycle_skin("tower", 1))
	core_label = _menu_row(box, func(): _cycle_skin("core", -1), func(): _cycle_skin("core", 1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var specs := [["시작 (Enter)", _close_title], ["기록·업적", _toggle_records], ["설정 (O)", _toggle_settings], ["도움말 (H)", func(): help_label.visible = not help_label.visible]]
	if OnlineConfig.SERVER_URL != "":
		specs.insert(2, ["리더보드", _toggle_board])
	for spec in specs:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(150 if specs.size() <= 4 else 120, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
	row.get_child(0).add_theme_font_size_override("font_size", 20)
	new_btn = row.get_child(0)
	# 이어하기: 저장된 판이 있을 때만 (쉬는 시간마다 자동 저장)
	continue_btn = Button.new()
	continue_btn.custom_minimum_size = Vector2(630, 48)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.focus_mode = Control.FOCUS_NONE
	continue_btn.add_theme_font_size_override("font_size", 19)
	continue_btn.pressed.connect(_continue_run)
	continue_btn.visible = false
	box.add_child(continue_btn)
	box.move_child(continue_btn, row.get_index())
	# 온라인: 새 버전 알림, 패치 공지 (서버에서 받았을 때만 보임)
	update_btn = Button.new()
	update_btn.custom_minimum_size = Vector2(630, 40)
	update_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	update_btn.focus_mode = Control.FOCUS_NONE
	update_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	update_btn.visible = false
	box.add_child(update_btn)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.custom_minimum_size = Vector2(630, 0)
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	notice_label.visible = false
	box.add_child(notice_label)

	records_panel = Label.new()
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

	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.position = Vector2(-220, -150)
	settings_panel.size = Vector2(440, 0)  # 내용 높이에 맞춤
	settings_panel.add_theme_stylebox_override("panel", rsb.duplicate())
	settings_panel.visible = false
	root.add_child(settings_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	settings_panel.add_child(sv)
	var st := Label.new()
	st.text = "설정 (O / Esc: 닫기)"
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
	for spec in [["화면 흔들림", "shake_on"], ["피해 숫자", "numbers_on"], ["속성 기호 표시 (색 위에 첫 글자)", "symbols_on"], ["모든 구체에 체력 숫자 (끄면 고리만)", "orb_hp_on"]]:
		var cb := CheckButton.new()
		cb.text = spec[0]
		var key: String = spec[1]
		match key:
			"shake_on": cb.button_pressed = Meta.shake_on
			"numbers_on": cb.button_pressed = Meta.numbers_on
			"symbols_on": cb.button_pressed = Meta.symbols_on
			"orb_hp_on": cb.button_pressed = Meta.orb_hp_on
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			match key:
				"shake_on": Meta.shake_on = on
				"numbers_on": Meta.numbers_on = on
				"orb_hp_on": Meta.orb_hp_on = on
				"symbols_on":
					Meta.symbols_on = on
					for t in towers.get_children():
						t.queue_redraw()
			_save_best())
		sv.add_child(cb)
	var gc := CheckButton.new()
	gc.text = "처음 안내 보기 (처음 생기는 일에 한 줄 설명)"
	gc.button_pressed = Meta.guide_on
	gc.focus_mode = Control.FOCUS_NONE
	gc.toggled.connect(func(on):
		Meta.guide_on = on
		if not on:
			guide_lines.clear()
		_save_best())
	sv.add_child(gc)
	var gr := Button.new()
	gr.text = "안내 처음부터 다시 보기"
	gr.tooltip_text = "본 안내를 지우고, 다음 새 판은 첫 판처럼 카드 종류를 웨이브마다 하나씩 엽니다"
	gr.focus_mode = Control.FOCUS_NONE
	gr.pressed.connect(func():
		Meta.guide_seen = {}
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
		sv.add_child(oc)
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
	var fs := Button.new()
	fs.text = "전체 화면 전환 (F11)"
	fs.focus_mode = Control.FOCUS_NONE
	fs.pressed.connect(_toggle_fullscreen)
	sv.add_child(fs)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_toggle_settings)
	sv.add_child(close)
	_refresh_menu()


## ◀ 글자 ▶ 한 줄.
func _menu_row(box: VBoxContainer, prev: Callable, next: Callable) -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var a := Button.new()
	a.text = "◀"
	a.focus_mode = Control.FOCUS_NONE
	a.custom_minimum_size = Vector2(44, 40)
	a.pressed.connect(prev)
	row.add_child(a)
	var l := Label.new()
	l.custom_minimum_size = Vector2(480, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var b := Button.new()
	b.text = "▶"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(44, 40)
	b.pressed.connect(next)
	row.add_child(b)
	return l


func _refresh_menu() -> void:
	var m: Dictionary = Meta.MAPS[Meta.map_id]
	var best := Meta.best_of(Meta.key())
	map_label.text = "맵: %s  (←/→)\n%s\n최고 기록  웨이브 %d · 점수 %s" % [m["name"], m["desc"], best[0], num(best[1])]
	rules_label.text = "규칙: %s  (↑/↓)\n%s" % [Rules.NAMES[Meta.rules], _wrap_parts(Patch.text("rules_desc", str(Meta.rules), Rules.DESCS[Meta.rules]), " · ", 470.0, 18)]
	rules_label.get_parent().visible = Meta.games > 0  # 규칙 버전 고르기는 첫 판을 끝낸 뒤에 (그 전엔 버전 1)
	var ts: Dictionary = Meta.TOWER_SKINS[Meta.tower_skin]
	skin_label.text = "오브젝트 모양: " + ts["name"]
	var cs: Dictionary = Meta.CORE_SKINS[Meta.core_skin]
	core_label.text = "중앙 모양: " + cs["name"]
	best_wave = best[0]
	best_score = best[1]


func _cycle_map(d: int) -> void:
	var i := Meta.MAP_IDS.find(Meta.map_id)
	Meta.map_id = Meta.MAP_IDS[(i + d + Meta.MAP_IDS.size()) % Meta.MAP_IDS.size()]
	sfx.play("place")
	_refresh_menu()
	_save_best()
	queue_redraw()


## 오른쪽 설명: 상한은 규칙 버전에 따라 다르다.
func _refresh_legend() -> void:
	var cap_e := "한 오브젝트에 %d종까지(레벨은 무제한)" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "종류 제한 없음, 종류마다 공격 속도 -%d%%" % roundi(Rules.tax_step * 100)
	var cap_m := "종류별 %d개까지" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "제한 없음, 쌓을수록 효과 절반씩"
	if Rules.mod_slots:
		cap_m = "강화 칸 안에서 (속성이 칸을 줌, 섞을수록 x1.5·x2)"
	var lines := PackedStringArray([
		"[오브젝트] 공격방식 + 속성 + 강화 + 연계",
		"· 새 오브젝트는 직선탄 + 속성 1개",
		"· 공격방식: 직선탄에만 넣을 수 있고 이후 고정,",
		"   같은 공격방식을 넣으면 레벨업",
		"· 속성: 모든 공격에 부가효과,",
		"   " + cap_e,
		"· 강화: 공격방식을 변형,",
		"   " + cap_m,
		"· 연계: 연결선·프리즘·공명",
		"",
		"[특수 반응] 두 속성이 함께 있으면 추가 공격 (발견 %d/%d)" % [Meta.codex.size(), Elem.REACTIONS.size()],
	])
	# 반응이 많아 한 줄에 두 개씩. 아직 만들어 보지 않은 반응은 ? + ? (도감과 같은 기록)
	var rs: Array = Elem.REACTIONS
	for i in range(0, rs.size(), 2):
		var row := PackedStringArray()
		for r in rs.slice(i, i + 2):
			row.append("%s+%s %s" % [Elem.NAMES[r["a"]], Elem.NAMES[r["b"]], r["name"]] if Meta.codex.has(r["id"]) else "? + ?")
		lines.append("   ".join(row))
	legend.text = "\n".join(lines)


## 규칙 버전 바꾸기: 기록은 버전마다 따로.
func _cycle_rules(d: int) -> void:
	var i := Rules.IDS.find(Meta.rules)
	Meta.rules = Rules.IDS[(i + d + Rules.IDS.size()) % Rules.IDS.size()]
	_apply_rules()
	sfx.play("place")
	_refresh_menu()
	_save_best()
	_update_hud()


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


func _toggle_records() -> void:
	records_panel.visible = not records_panel.visible
	if not records_panel.visible:
		return
	var lines := PackedStringArray(["[맵별 최고 기록 · %s]   (아무 곳이나 클릭: 닫기)" % Rules.NAMES[Meta.rules]])
	for id in Meta.MAP_IDS:
		var b := Meta.best_of(Meta.key(id))
		lines.append("  %s: 웨이브 %d · 점수 %s" % [Meta.MAPS[id]["name"], b[0], num(b[1])])
	# 규칙 버전끼리 비교하기 쉽게: 지금 맵의 버전별 최고 웨이브
	var vers := PackedStringArray()
	for r in Rules.IDS:
		vers.append("버전 %d: %d" % [r, Meta.best_of(Meta.key(Meta.map_id, r))[0]])
	lines.append("  %s 버전별 최고 웨이브  %s" % [Meta.MAPS[Meta.map_id]["name"], " · ".join(vers)])
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
	lines.append("[업적] %d / %d" % [Meta.achieved.size(), Meta.ACH_IDS.size()])
	for id in Meta.ACH_IDS:
		var a: Dictionary = Meta.ACHIEVEMENTS[id]
		var unlock := ""
		for sk in Meta.TOWER_SKIN_IDS:
			if Meta.TOWER_SKINS[sk]["need"] == id:
				unlock = " → 오브젝트 모양 '%s'" % Meta.TOWER_SKINS[sk]["name"]
		for sk in Meta.CORE_SKIN_IDS:
			if Meta.CORE_SKINS[sk]["need"] == id:
				unlock = " → 중앙 모양 '%s'" % Meta.CORE_SKINS[sk]["name"]
		lines.append("  %s %s - %s%s" % ["✓" if Meta.achieved.has(id) else "·", a["name"], a["desc"], unlock])
	lines.append("")
	lines.append("[반응 도감] %d / %d" % [Meta.codex.size(), Elem.REACTIONS.size()])
	var row := PackedStringArray()
	for r in Elem.REACTIONS:
		if Meta.codex.has(r["id"]):
			row.append("%s(%s+%s)" % [r["name"], Elem.NAMES[r["a"]], Elem.NAMES[r["b"]]])
		else:
			row.append("???")
	# 반응이 17개라 다섯 개씩 끊어 화면 밖으로 넘치지 않게
	for i in range(0, row.size(), 5):
		lines.append("  " + ", ".join(row.slice(i, i + 5)))
	records_panel.text = "\n".join(lines)


# ---------- 온라인 ----------

## 서버 응답(켤 때 한 번): 시작 화면이면 받은 패치를 바로 적용하고, 새 버전·공지를 띄운다.
func _on_booted(info: Dictionary) -> void:
	if info.is_empty() or update_btn == null:
		return
	if title_label.visible:
		_apply_rules()
		_refresh_menu()
	var latest: Variant = info.get("latest")
	if latest is Dictionary and str(latest.get("url", "")) != "":
		var notes := str(latest.get("notes", ""))
		update_btn.text = "새 버전 v%s 받기%s" % [latest.get("version", "?"), " · " + notes if notes != "" else ""]
		for c in update_btn.pressed.get_connections():
			update_btn.pressed.disconnect(c["callable"])
		var url := str(latest["url"])
		update_btn.pressed.connect(func(): OS.shell_open(url))
		update_btn.visible = true
	var msg := Patch.text("", "message", "")
	notice_label.text = msg
	notice_label.visible = msg != ""


## 게임 오버: 판 기록(점수·특성·선택지·마지막 구성)을 서버로. 설정에서 끄면 보내지 않는다.
func _submit_run() -> void:
	if not Net.enabled():
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
			"links": t.links.size(), "share": (t.run_dealt + t.dealt) / total if total > 0.0 else 0.0})
	net.submit({
		"device": Meta.device_id, "nick": Meta.nickname, "platform": Net.platform(), "game": Net.game_version(),
		"patch": Patch.id, "map": Meta.map_id, "rules": Meta.rules, "wave": wave, "score": score, "kills": kills,
		"best_combo": best_combo, "game_secs": run_game, "real_secs": run_real, "perks": perks.duplicate(),
		"towers": list, "log": run_log,
	})


## 서버가 기록을 받으면 게임 오버 글 아래에 온라인 순위.
func _on_run_sent(res: Dictionary) -> void:
	if phase != Phase.GAMEOVER or not res.get("accepted", false):
		return
	var rk: Variant = res.get("rank")
	if int(res.get("season", 0)) == 0:
		over_label.text += "\n(지난 버전으로 한 판이라 이번 시즌 리더보드에는 들어가지 않아요)"
	elif rk is Dictionary:
		var season: Variant = Net.info.get("season")
		var sname := str(season.get("name", "")) if season is Dictionary else ""
		over_label.text += "\n온라인 순위: %s%d위 (최고 점수 %s)" % [sname + " " if sname != "" else "", int(rk["rank"]), num(int(rk["score"]))]


## 시작 화면 리더보드: 지금 고른 맵·규칙 버전의 이번 시즌 전체·이번 주 순위.
func _toggle_board() -> void:
	records_panel.visible = not records_panel.visible
	if not records_panel.visible:
		return
	board_lines = {}
	_draw_board()
	net.leaderboard(Meta.map_id, Meta.rules, "all")
	net.leaderboard(Meta.map_id, Meta.rules, "week")


func _on_board_loaded(d: Dictionary) -> void:
	if not records_panel.visible or not records_panel.text.begins_with("[리더보드"):
		return
	var lines := PackedStringArray()
	if d.has("error"):
		lines.append("  " + str(d["error"]))
	else:
		board_lines["season"] = str(d.get("season", {}).get("name", ""))
		var shown_me := false
		for e in d.get("entries", []):
			shown_me = shown_me or e.get("me", false)
			lines.append("  %d. %s   웨이브 %d · 점수 %s%s" % [int(e["rank"]), e["nick"], int(e["wave"]), num(int(e["score"])), "   ◀ 나" if e.get("me", false) else ""])
		if lines.is_empty():
			lines.append("  아직 기록이 없어요")
		var me: Variant = d.get("me")
		if me is Dictionary and not shown_me:
			lines.append("  …  내 순위 %d위 / %d명 · 점수 %s" % [int(me["rank"]), int(d.get("total", 0)), num(int(me["score"]))])
	board_lines[d.get("period", "all")] = lines
	_draw_board()


func _draw_board() -> void:
	var head := "[리더보드 · %s · %s%s]   (아무 곳이나 클릭: 닫기)" % [Meta.MAPS[Meta.map_id]["name"], Rules.NAMES[Meta.rules],
		" · " + board_lines["season"] if board_lines.get("season", "") != "" else ""]
	var lines := PackedStringArray([head, ""])
	for spec in [["all", "이번 시즌 전체"], ["week", "이번 주"]]:
		lines.append(spec[1])
		lines.append_array(board_lines.get(spec[0], PackedStringArray(["  불러오는 중…"])))
		lines.append("")
	if not Meta.online_on:
		lines.append("설정에서 '기록 보내기'를 켜면 내 기록도 올라갑니다")
	elif Meta.nickname == "":
		lines.append("설정에서 닉네임을 정할 수 있어요")
	records_panel.text = "\n".join(lines)


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible


func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Meta.volume, 0.001)))


## 업적 달성 처리: 배너와 소리, 해금 안내.
func _achieve(id: String) -> void:
	if not Meta.achieve(id):
		return
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


## 설치 후 확인하는 업적·도감.
func _check_progress() -> void:
	var links := 0
	for t in towers.get_children():
		links += t.links.size()
		if t.order.size() >= 5:
			_achieve("stack5")
		for r in t.reactions():
			if Meta.discover(r["id"]):
				_show_toast("반응 도감에 추가: " + r["name"])
				_save_best()
				_refresh_legend()
				_guide("react", "특수 반응 · %s(%s+%s): %s. 발견한 반응은 오른쪽 설명에 채워져요" % [r["name"], Elem.NAMES[r["a"]], Elem.NAMES[r["b"]], r["desc"]])
	if links / 2 >= 3:
		_achieve("links3")
	if Meta.codex.size() >= 5:
		_achieve("codex5")
	if Meta.codex.size() >= Elem.REACTIONS.size():
		_achieve("codex9")


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
	title_seen = true


# ---------- 이어하기 ----------

## 쉬는 시간마다 판을 저장한다. 웨이브 중에 끄면 그 웨이브 앞 쉬는 시간부터 이어진다.
func _save_run() -> void:
	if title_label.visible or not phase in [Phase.CHOOSE, Phase.READY] or press_t or dragging:
		return
	var ts := towers.get_children()
	var list: Array = []
	for t in ts:
		var d: Dictionary = t.to_save()
		var li: Array = []
		for o in t.links:
			if is_instance_valid(o) and ts.has(o):
				li.append(ts.find(o))
		d["links"] = li
		list.append(d)
	var vals := {
		"format": RUN_FORMAT, "version": ProjectSettings.get_setting("application/config/version", ""),
		"map": Meta.map_id, "rules": Meta.rules, "wave": wave, "score": score, "kills": kills, "best_combo": best_combo,
		"core_hp": core_hp, "core_max": core_max, "perks": perks.keys().map(func(k): return [k, perks[k]]), "orb_speed_mul": orb_speed_mul,
		"dmg_mul": Tower.dmg_mul, "spd_mul": Tower.spd_mul, "reach_mul": Tower.reach_mul, "tax_step": Tower.tax_step,
		"rerolls_left": rerolls_left, "bonus_rerolls": bonus_rerolls, "picks_left": picks_left,
		"lanes": Array(lanes), "wave_resist": wave_resist, "boss": boss_plan, "achievements": new_achievements,
		"state": "perk" if perk_mode else ("ready" if phase == Phase.READY else "choose"),
		"offer": offer, "perk_offer": perk_offer.map(func(pk): return pk["id"]), "towers": list,
		"log": run_log, "game_secs": run_game, "real_secs": run_real,
		"tutor": tutor, "tutor_given": tutor_given.keys(),
	}
	var cfg := ConfigFile.new()
	for k in vals:
		cfg.set_value("run", k, vals[k])
	cfg.save(RUN_PATH)


func _clear_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(RUN_PATH)


## 저장된 판 요약 {wave, map, rules, cfg} (없거나 형식이 다르면 빈 사전).
func _run_info() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(RUN_PATH) != OK or Meta.val(cfg, "run", "format", 0) != RUN_FORMAT:
		return {}
	var map: String = Meta.val(cfg, "run", "map", "")
	var r: int = Meta.val(cfg, "run", "rules", 0)
	if not map in Meta.MAP_IDS or not r in Rules.ALL_IDS:
		return {}
	if not r in Rules.IDS:
		r = 1  # 고를 수 없게 된 버전(2·4·5)으로 저장된 판은 버전 1로 이어 한다
	return {"wave": maxi(0, Meta.val(cfg, "run", "wave", 0)), "map": map, "rules": r, "cfg": cfg}


## 시작 화면의 이어하기 버튼: 저장된 판이 있으면 그 판의 웨이브·맵·규칙을 보여 준다.
func _refresh_continue() -> void:
	var info := _run_info()
	continue_btn.visible = not info.is_empty()
	new_armed = 0.0
	new_btn.text = "새로 시작 (N)" if continue_btn.visible else "시작 (Enter)"
	if continue_btn.visible:
		continue_btn.text = "이어하기 (Enter)   웨이브 %d부터 · %s · 버전 %d" % [info["wave"] + 1, Meta.MAPS[info["map"]]["name"], info["rules"]]


## 저장된 선택지 카드가 지금 판에서도 쓸 수 있는 형식인지.
func _valid_card(cd: Variant) -> bool:
	if not cd is Dictionary:
		return false
	match cd.get("type"):
		"elem": return cd.get("e") in Elem.ALL and cd.get("lv") is int
		"pat": return cd.get("id") in Pat.PATTERN_IDS
		"mod": return Pat.MODS.has(cd.get("id"))
		"link": return Pat.LINKS.has(cd.get("id"))
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
	Meta.rules = info["rules"]
	_apply_rules()
	_refresh_menu()
	_save_best()
	_hide_title()
	wave = info["wave"]
	score = maxi(0, g.call("score", 0))
	kills = maxi(0, g.call("kills", 0))
	best_combo = maxi(0, g.call("best_combo", 0))
	core_max = maxi(1, g.call("core_max", CORE_MAX_HP))
	core_hp = clampi(g.call("core_hp", core_max), 1, core_max)
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
	orb_speed_mul = clampf(g.call("orb_speed_mul", 1.0), 0.05, 1.0)
	Tower.dmg_mul = maxf(1.0, g.call("dmg_mul", 1.0))
	Tower.spd_mul = maxf(1.0, g.call("spd_mul", 1.0))
	Tower.reach_mul = maxf(1.0, g.call("reach_mul", 1.0))
	Tower.tax_step = clampf(g.call("tax_step", Rules.tax_step), 0.0, Rules.tax_step)
	rerolls_left = maxi(0, g.call("rerolls_left", 1))
	bonus_rerolls = maxi(0, g.call("bonus_rerolls", 0))
	picks_left = maxi(0, g.call("picks_left", 1))  # 특성 고르기 중에는 0
	lanes.assign((g.call("lanes", []) as Array).filter(func(a): return a is float))
	if lanes.is_empty():
		_roll_lanes()
	wave_resist = g.call("wave_resist", -1)
	if not wave_resist in Elem.ALL:
		wave_resist = -1
	# 미리 뽑아 둔 보스 (없거나 형식이 다르면 새로 뽑음)
	var bp: Variant = g.call("boss", {})
	boss_plan = {}
	if bp is Dictionary and bp.get("wave") is int and bp["wave"] == wave + 1 and bp.get("a") is float and bp.get("hp") is float and bp.get("spd") is float and bp.get("resist") is int and bp.get("sturdy") is bool:
		boss_plan = {"wave": bp["wave"], "a": bp["a"], "hp": maxf(1.0, bp["hp"]), "spd": maxf(1.0, bp["spd"]), "resist": bp["resist"] if bp["resist"] in Elem.ALL else -1, "sturdy": bp["sturdy"]}
	else:
		_plan_boss()
	new_achievements = (g.call("achievements", []) as Array).filter(func(a): return a is String)
	run_log = (g.call("log", []) as Array).filter(func(e): return e is Dictionary)
	run_game = maxf(0.0, g.call("game_secs", 0.0))
	run_real = maxf(0.0, g.call("real_secs", 0.0))
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
	for i in made.size():
		var li: Variant = raw[i].get("links", []) if made[i] else []
		if li is Array:
			for j in li:
				if j is int and j >= 0 and j < made.size() and j != i and made[j] and not made[i].links.has(made[j]):
					made[i].links.append(made[j])
					if not made[j].links.has(made[i]):
						made[j].links.append(made[i])
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
		_:
			picks_left = maxi(1, picks_left)
			offer = (g.call("offer", []) as Array).filter(_valid_card)
			if offer.is_empty():
				_make_choices()
			else:
				_show_offer()
			_open_choose()
	_show_toast("웨이브 %d 앞 쉬는 시간부터 이어서 합니다" % (wave + 1))


## 공격방식·강화·연계 카드를 오브젝트에 넣는다.
func _apply_card(target: Tower) -> void:
	if target == null:
		_show_toast("오브젝트 위에 놓으세요")
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
			if picked["id"] == "link":
				if link_a == null:
					link_a = target
					sfx.play("place")
					hint.text = _place_hint()
					return
				if target == link_a:
					return
				if target.position.distance_to(link_a.position) > Rules.link_range:
					_show_toast("너무 멀어요 (%d 이내)" % int(Rules.link_range))
					return
				if link_a.links.has(target):
					_show_toast("이미 연결되어 있어요")
					return
				var before := Elem.reactions_with(link_a.eff_now()).size() + Elem.reactions_with(target.eff_now()).size()
				msg = link_a.add_link("link", target)
				link_a.eff = link_a.eff_now()
				target.eff = target.eff_now()
				if link_a.reactions().size() + target.reactions().size() > before:
					msg += " (속성 공유로 반응 발동)"
				link_a = null
			else:
				msg = target.add_link(picked["id"])
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
		hint.text = PLACE_HINT
	elif phase == Phase.PLACE:
		if link_a:
			link_a = null
			hint.text = _place_hint()
		else:
			_back_to_choose()


## 선택지를 그대로 둔 채 오브젝트 고르기로 돌아간다.
func _back_to_choose() -> void:
	phase = Phase.CHOOSE
	choice_box.visible = not cards_hidden
	_update_reroll_btn()
	hint.text = _choose_hint()
	_save_run()


## 쉬는 시간에 설치된 오브젝트를 클릭하면 위치·방향을 다시 정한다.
func _end_move() -> void:
	if move_return == Phase.READY:
		_enter_ready()
	else:
		_back_to_choose()


func _start_move(t: Tower) -> void:
	move_return = phase
	start_btn.visible = false
	moving = t
	move_orig_pos = t.position
	move_orig_dir = t.dir
	phase = Phase.MOVE
	choice_box.visible = false
	reroll_btn.visible = false
	hint.text = "새 자리를 누르면 옮깁니다   취소: 그대로 두기" if touch_ui else "클릭: 새 위치   우클릭/Esc: 옮기기 취소"


func _toggle_pause() -> void:
	if phase == Phase.GAMEOVER or title_label.visible:
		return
	get_tree().paused = not get_tree().paused
	paused_label.visible = get_tree().paused
	pause_box.visible = get_tree().paused
	paused_label.text = _pause_text()
	restart_armed = 0.0
	pause_btn.text = "계속 (P)" if get_tree().paused else "일시정지 (P)"


## 일시정지 글: 지금 나가면 어디서부터 이어지는지도 알려 준다.
func _pause_text() -> String:
	var keys := "일시정지\nP / Esc: 계속   T: 시작 화면%s   R: 처음부터\nM: 소리   O: 설정   F11: 전체 화면" % ("   X: 끄기" if OS.has_feature("pc") else "")
	if phase == Phase.WAVE:
		return keys + "\n지금 나가면 웨이브 %d 앞 쉬는 시간부터 이어집니다" % wave
	return keys + "\n지금 나가도 이 쉬는 시간부터 이어서 할 수 있어요"


## 일시정지에서 시작 화면으로 가거나 게임을 끈다. 쉬는 시간이면 지금 상태를 저장하고,
## 웨이브 중이면 그 웨이브 앞 쉬는 시간의 저장이 남는다 (시작 화면의 이어하기).
func _leave(quit_game: bool) -> void:
	_save_run()
	get_tree().paused = false
	if quit_game:
		get_tree().quit()
		return
	title_seen = false
	get_tree().reload_current_scene()


func _toggle_speed() -> void:
	# Space·버튼: 1배속 ↔ 고른 배속
	game_speed = fast_speed if game_speed == 1.0 else 1.0
	_update_speed_btn()


func _update_speed_btn() -> void:
	speed_btn.text = "x%d (Space)" % roundi(game_speed)
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


func _place_tower(p: Vector2, d: Vector2) -> void:
	var t := Tower.new()
	t.add(picked["e"], picked["lv"])
	t.dir = d
	t.position = p
	t.main = self
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
	z.position = pos
	zones.add_child(z)
	return z


## 벽 공격방식: 발사 방향에 바위 벽. 오브젝트당 최대 2개(+다중 발사).
func spawn_rock(t: Tower, l: int) -> void:
	t.rocks = t.rocks.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion())
	if t.rocks.size() >= 2 + roundi(t.mf("multi")):
		return
	var dist := 90.0 + 60.0 * t.rocks.size()
	# 바위는 화면 가장자리에서 100 안쪽에만 선다: 가장자리에 서면 막힌 구체가 화면 끝에 붙어
	# 다른 오브젝트가 닿지 않는 곳에서 버티고 웨이브가 끝나지 않던 것 (폭풍 맵 66웨이브에서 4분 넘게)
	var inner := get_viewport_rect().grow(-100.0)
	var p := (t.position + t.dir * dist * Tower.reach(l)).clamp(inner.position, inner.end)
	if t.rocks.any(func(r): return r.position.distance_to(p) < 40.0):
		return  # 가장자리에 밀려 같은 자리에 겹치는 바위는 세우지 않는다
	t.rocks.append(spawn_zone("rock", l, p, t))


## 연쇄 번개 표시 (맨 위 층).
func bolt(pts: PackedVector2Array) -> void:
	if bolts.size() < 40:
		bolts.append([pts, 0.22])


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
		best.hurt(dmg)
		if src:
			src.dealt += dmg
		if arcs.size() < 80:
			arcs.append([from.position, best.position, 0.12])


## 구체 하나의 진입 각도·체력(종류 보정 전)·속도·저항·굳셈을 뽑는다.
func _roll_orb(w: int) -> Dictionary:
	var spread := minf(0.15 + 0.01 * w, 0.4)
	if Meta.map_id == "cross":
		spread = 0.06  # 십자로: 네 길 위로만 온다
	var a: float = lanes.pick_random() + randf_range(-spread, spread)
	var hp := (1.0 + floorf(w * 0.7) + randi() % 2) * hp_growth(w) * Rules.orb_hp
	match Meta.map_id:
		"cross":
			hp = ceilf(hp * 1.6)
		"storm":
			hp = maxf(1.0, roundf(hp * 0.6))
	var spd := 30.0 + w * 3.0 + randf() * 8.0
	# 저항·굳셈: 쉬는 시간에 미리 알려 준 대로
	var res := wave_resist if wave_resist >= 0 and randf() < resist_share(w) else -1
	return {"a": a, "hp": roundf(hp), "spd": spd, "resist": res, "sturdy": randf() < sturdy_share(w)}


## 다음 웨이브가 보스 웨이브면 보스를 미리 뽑아 둔다 (화면에 길·체력을 정확히 알려 주려고).
func _plan_boss() -> void:
	boss_plan = {}
	if (wave + 1) % 5 == 0 and not lanes.is_empty():
		boss_plan = _roll_orb(wave + 1)
		boss_plan["wave"] = wave + 1


## 구체가 나오는 거리 (화면 대각선 반 + 30, 화면 밖).
func _spawn_radius() -> float:
	return get_viewport_rect().size.length() / 2.0 + 30.0


## 각도 a에서 나온 구체가 막히지 않을 때 지나가는 길 (소용돌이 맵은 나선, 구체 이동과 같은 식).
func _orb_path(a: float) -> PackedVector2Array:
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
	o.position = center() + Vector2.from_angle(p["a"]) * _spawn_radius()
	o.from_a = p["a"]
	o.target = center()
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
		if wave >= 8 and randf() < minf(0.1 + 0.01 * wave, 0.3):
			o.shield = (2.0 + wave * 0.3) * hp_growth(wave) * Rules.orb_hp
		if wave >= 12 and randf() < 0.15:
			o.splits = true
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
	o.target = center()
	o.setup(Orb.Kind.FAST, maxf(1.0, roundf(wave * 0.5 * hp_growth(wave) * Rules.orb_hp)), 36.0 + wave * 3.0)
	o.resist_e = boss.resist_e
	orbs.add_child(o)


## 분열 구체가 터지면 작은 구체 2개.
func _spawn_child(parent: Orb) -> void:
	var o := Orb.new()
	o.main = self
	o.position = parent.position + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	o.from_a = parent.from_a
	o.target = center()
	o.setup(Orb.Kind.NORMAL, maxf(1.0, ceilf(parent.max_hp * 0.4)), parent.speed * 1.1 / orb_speed_mul)
	o.resist_e = parent.resist_e
	o.sturdy = parent.sturdy
	orbs.add_child(o)


## 웨이브가 오를수록 빠른 구체(4웨이브~), 단단한 구체(6웨이브~)가 섞인다.
func _roll_kind() -> int:
	var x := randf()
	# 단단한 구체는 7웨이브부터 (6웨이브는 세 번째 진입 방향이 열림)
	if wave >= 7 and x < minf(0.08 + 0.02 * wave, 0.3):
		return Orb.Kind.TANK
	if wave >= 4 and x > 1.0 - minf(0.1 + 0.03 * wave, 0.35):
		return Orb.Kind.FAST
	return Orb.Kind.NORMAL


# ---------- 루프 ----------

func _process(delta: float) -> void:
	if new_armed > 0.0:
		new_armed -= delta
		if new_armed <= 0.0:
			new_btn.text = "새로 시작 (N)"
	toast_timer -= delta
	toast.visible = toast_timer > 0.0
	if guide_t > 0.0 and not get_tree().paused:
		guide_t -= delta
		if guide_t <= 0.0:
			guide_lines.clear()
			guide_t = 0.0
	guide_label.visible = not guide_lines.is_empty() and not title_label.visible and phase != Phase.GAMEOVER and not get_tree().paused and not help_label.visible and not settings_panel.visible and not records_panel.visible
	toast.position.y = maxf(100.0, hud.position.y + hud.size.y + 36.0)  # 점수 줄이 길어져도 보스 체력 막대 아래
	banner_t -= delta
	if banner_t <= 0.0 and not banner_queue.is_empty():
		var nb: Array = banner_queue.pop_front()
		big_banner(nb[0], nb[1])
	banner.visible = banner_t > 0.0
	banner.modulate.a = clampf(banner_t / 0.4, 0.0, 1.0)
	legend.visible = phase in [Phase.CHOOSE, Phase.PLACE, Phase.AIM, Phase.MOVE, Phase.READY] and not title_label.visible
	preview.visible = legend.visible
	legend_btn.visible = legend.visible
	range_btn.visible = touch_ui and not title_label.visible and phase != Phase.GAMEOVER
	range_btn.text = "범위 끄기" if range_all else "범위 보기"
	legend_btn.text = ("설명 보기" if legend_hidden else "설명 숨기기") + " (Tab)"
	legend.visible = legend.visible and not legend_hidden
	# 시작 화면 위에 설정·기록·도움말 창을 열면 뒤 메뉴 글자가 창 옆으로 삐져나와 보이지 않게 흐리게
	title_label.modulate.a = 0.12 if settings_panel.visible or records_panel.visible or help_label.visible else 1.0
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
	_update_hud()
	if pause_box.visible:
		pause_box.position.y = paused_label.position.y + paused_label.size.y + 10.0
	queue_redraw()
	if phase == Phase.MOVE and moving:
		moving.position = get_global_mouse_position().clamp(field_rect().position, field_rect().end)
	_update_press()
	if boxing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_box()  # 창 밖에서 손을 떼 놓기 이벤트를 못 받은 경우
	hide_btn.visible = phase == Phase.CHOOSE and not title_label.visible
	cancel_btn.visible = phase in [Phase.PLACE, Phase.AIM, Phase.MOVE] and not title_label.visible and not get_tree().paused
	hide_btn.text = ("▲ 선택지 다시 보기" if cards_hidden else "▼ 선택지 내리고 필드 보기") + " (V)"
	# 펼쳐 있으면 새로고침 버튼 아래, 내려 두면 화면 위쪽 가운데
	hide_btn.set_anchors_preset(Control.PRESET_CENTER_TOP if cards_hidden else Control.PRESET_CENTER)
	var hy := maxf(96.0, hud.position.y + hud.size.y + 8.0) if cards_hidden else 148.0  # 내려 둘 때는 점수 줄 아래
	# 카드 줄은 오른쪽 설명을 피해 왼쪽으로 비켜 있다. 설명을 숨기면 가운데로, 버튼도 카드 가운데에 맞춘다
	var cx := 0.0 if legend_hidden else -75.0
	choice_box.offset_left = cx - 365.0
	choice_box.offset_right = cx + 365.0
	reroll_btn.offset_left = cx - 170.0
	reroll_btn.offset_right = cx + 170.0
	var hx := 0.0 if cards_hidden else cx
	hide_btn.offset_left = hx - 130.0
	hide_btn.offset_right = hx + 130.0
	hide_btn.offset_top = hy
	hide_btn.offset_bottom = hy + 32.0
	restart_armed = maxf(restart_armed - delta, 0.0)
	if not get_tree().paused and not title_label.visible and phase != Phase.GAMEOVER:
		run_real += delta
	if get_tree().paused:
		fx_layer.queue_redraw()  # 멈춘 동안에도 오브젝트·구체 정보창은 마우스를 따라간다
		return
	# 도움말·설정 창을 보는 동안은 게임이 멈춘다 (읽는 사이 구체가 중앙에 닿거나 웨이브가 시작되지 않게)
	var reading := (help_label.visible or settings_panel.visible or records_panel.visible) and not title_label.visible
	if countdown >= 0.0 and phase == Phase.READY:
		# 오브젝트를 끌거나 상자로 고르는 동안은 자동 시작을 멈춘다 (시작하면 끌던 것이 되돌아감)
		if press_t or boxing or reading:
			countdown = maxf(countdown, 1.0)
		else:
			countdown -= delta
		start_btn.text = "%.1f초 뒤 시작 (Space: 바로)" % maxf(countdown, 0.0)
		if countdown <= 0.0:
			_start_wave()
	if reading:
		return
	_update_fx(delta)
	if phase != Phase.WAVE:
		return
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
	for layer in [orbs, projectiles, zones]:
		for n in layer.get_children():
			if not n.is_queued_for_deletion():
				n.step(delta)

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
	_resolve(delta)

	if core_hp <= 0:
		_game_over()
	elif to_spawn == 0 and _alive_count(orbs) == 0:
		_log_wave()
		_achieve("first")
		if wave >= 5:
			Meta.map_best[Meta.key()] = [maxi(Meta.best_of(Meta.key())[0], wave), maxi(Meta.best_of(Meta.key())[1], score)]
			if Meta.MAP_IDS.all(func(id): return Meta.best_of(Meta.key(id))[0] >= 5):
				_achieve("allmaps")
		var bonus := wave * 20
		score += bonus
		_show_toast("웨이브 %d 클리어! +%d" % [wave, bonus])
		sfx.play("clear", 0.0)
		_show_mvp()
		if perks.has("regen"):
			core_hp = mini(core_hp + perks["regen"] * int(_perk_val("regen")), core_max)
		if wave % 5 == 0:
			_start_perk()
		else:
			_start_choose()


## 중앙에 닿은 구체를 기록하고, 그 구체가 들어온 화면 가장자리를 붉게 번지게 한다.
func _record_leak(o: Orb) -> void:
	wave_leaks.append([_lane_of(o.from_a), o.kind, o.core_dmg])
	leak_flash.append([_entry_point(o.from_a), 1.2])
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
		var vr := get_viewport_rect()
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
	for i in by_lane:
		dirs[compass(lanes[i]) if i >= 0 and i < lanes.size() else "?"] = by_lane[i]
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
	return "지난 웨이브 누수: %s (%s, 중앙 -%d)" % [" · ".join(parts), ", ".join(ks), e["dmg"]]


func _alive_count(n: Node) -> int:
	var c := 0
	for x in n.get_children():
		if not x.is_queued_for_deletion():
			c += 1
	return c


func _resolve(delta: float) -> void:
	var rect := get_viewport_rect().grow(40.0)
	live_orbs = orbs.get_children().filter(func(o): return not o.is_queued_for_deletion())
	# 공격은 화면에 보이기 시작한 구체에만 닿는다 (가장자리가 화면 안으로 들어온 구체)
	var screen := get_viewport_rect()
	targets = live_orbs.filter(func(o): return screen.grow(o.radius()).has_point(o.position))

	_build_grid()
	prism_towers = towers.get_children().filter(func(t): return t.prism > 0)
	# 오브젝트 공격
	for t in towers.get_children():
		if not t.is_queued_for_deletion():
			t.attack(delta, targets)

	# 바닥 효과
	for z in zones.get_children():
		if not z.is_queued_for_deletion():
			z.affect(near(z.position, z.radius if z.kind != "mine" else 80.0), delta)

	# 발사체
	for p in projectiles.get_children():
		if p.is_queued_for_deletion():
			continue
		if not rect.has_point(p.position):
			p.queue_free()
			continue
		if p.finished():
			_land(p)
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

	# 구체 처치 / 중앙 도달
	for o in live_orbs:
		if o.hp <= 0.0:
			sfx.play("kill", 0.15)
			combo = combo + 1 if combo_t > 0.0 else 1
			combo_t = 1.5
			best_combo = maxi(best_combo, combo)
			if combo >= 30:
				_achieve("combo30")
			var gain := int(o.max_hp * 10 * (1.0 + 0.1 * mini(combo, 20)))
			score += gain
			if combo >= 3 and combo % 5 == 0:
				popup(o.position + Vector2(0, -20), combo, Color(1, 0.7, 0.3), true, "콤보 %d!" % combo)
			if o.splits:
				for i in 2:
					_spawn_child(o)
			if o.kind == Orb.Kind.BOSS:
				core_hp = mini(core_hp + 2, core_max)
				bonus_rerolls += 1
				_achieve("boss")
				_show_toast("보스 처치! 중앙 체력 +2, 새로고침 +1")
			burst(o.position, o.death_color(), 10 if o.kind != Orb.Kind.BOSS else 40, 180.0)
			kills += 1
			if o.kind == Orb.Kind.BOSS:
				shake = 0.4
			if o.poison_t > 0.0:
				for other in targets:
					if other != o and other.position.distance_to(o.position) < 80.0:
						other.poison(o.poison_dps, 3.0, o.poison_src, o.poison_rx)
			if o.curse_lv > 0:
				_curse_burst(o)
			if o.swamp_t > 0.0:
				_swamp_burst(o)
			o.queue_free()
			continue
		if o.position.distance_to(center()) < CORE_RADIUS + o.radius():
			core_hp -= o.core_dmg
			sfx.play("core", 0.0)
			shake = 0.25 + 0.1 * o.core_dmg
			core_flash = 0.4
			burst(center(), Color(1, 0.3, 0.35), 18, 220.0)
			_show_toast("중앙 피격! %d/%d" % [maxi(core_hp, 0), core_max])
			_record_leak(o)
			o.queue_free()
			continue

	for a in arcs:
		a[2] -= delta
	arcs = arcs.filter(func(a): return a[2] > 0.0)


## 저주: 표식 구체가 죽으면 주변에 그 구체 최대 체력 비례 피해, 표식은 가까운 구체로 옮겨 간다.
func _curse_burst(o: Orb) -> void:
	var tw: Tower = o.curse_owner if is_instance_valid(o.curse_owner) else null
	var dmg := 0.25 * o.max_hp * (1.0 + 0.2 * (o.curse_lv - 1))
	var next: Orb = null
	var bd := 220.0
	for other in near(o.position, bd):
		if other == o or other.hp <= 0.0:
			continue
		var d: float = other.position.distance_to(o.position)
		if d < 100.0 + other.radius():
			other.hurt(dmg)
			if tw:
				tw.dealt += dmg
				tw.rx_dealt += dmg
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


## 독늪 안에서 죽으면 독이 터져 주변 구체를 중독시킨다.
func _swamp_burst(o: Orb) -> void:
	for other in near(o.position, 90.0):
		if other != o and other.hp > 0.0 and other.position.distance_to(o.position) < 90.0 + other.radius():
			other.poison(1.5 * o.swamp_lv, 4.0, o.poison_src, true)
	burst(o.position, Color(0.6, 0.85, 0.2), 12, 160.0)


## 구체 위치 격자: 발사체·장판이 가까운 구체만 확인하도록.
const GRID := 64.0
var grid := {}


func _build_grid() -> void:
	grid.clear()
	for o in targets:
		var k := Vector2i(floori(o.position.x / GRID), floori(o.position.y / GRID))
		if grid.has(k):
			grid[k].append(o)
		else:
			grid[k] = [o]


## 오브젝트를 놓을 수 있는 화면 안쪽 영역 (가장자리에서 몸 반지름만큼 안).
func field_rect() -> Rect2:
	return get_viewport_rect().grow(-(Tower.RADIUS + 6.0))


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


func _update_fx(delta: float) -> void:
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
	shake = maxf(shake - delta, 0.0)
	combo_t = maxf(combo_t - delta, 0.0)
	core_flash = maxf(core_flash - delta, 0.0)
	eclipse_flash = maxf(eclipse_flash - delta, 0.0)
	camera.position = center()
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * shake * (1.0 if Meta.shake_on else 0.0)
	fx_layer.queue_redraw()


## 마우스를 올린 오브젝트의 정보.
func _draw_tooltip() -> void:
	tip_orb = null
	# 터치는 마우스를 올려 둘 수 없으니, 눌러서 옮기기 시작한 오브젝트의 정보를 보여 준다
	var touch_move := phase == Phase.MOVE and touch_ui and moving != null
	if (phase in [Phase.PLACE, Phase.GAMEOVER, Phase.MOVE, Phase.AIM] and not touch_move) or title_label.visible or dragging or boxing:
		return
	var t := moving if touch_move else _tower_at(get_global_mouse_position())
	if t == null:
		_draw_orb_tooltip()
		return
	var fs := 14
	var maxw := minf(620.0, _right_limit() - 24.0)  # 이보다 긴 줄은 접는다 (속성이 많으면 화면 밖으로 나가던 것)
	var lines: Array = []  # [글자, 색]
	var head := t.title()
	var tip := "(클릭: 옮기기 · 끌기: 바로 이동)" if phase in [Phase.CHOOSE, Phase.READY] and not perk_mode else ""
	if touch_move:
		tip = "(새 자리 누르기: 옮기기 · 취소: 그대로)"
	if tip != "" and ui_font.get_string_size(head + "   " + tip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= maxw:
		lines.append([head + "   " + tip, Color.WHITE])
	else:
		for row in _wrap_parts(head, "·", maxw, fs).split("\n"):
			lines.append([row, Color.WHITE])
		if tip != "":
			lines.append([tip, Color(1, 1, 1, 0.6)])
	lines.append(["공격방식: %s Lv%d - %s" % [Pat.pname(t.pattern), t.plv, Pat.PATTERNS[t.pattern]["desc"]], Pat.pcolor(t.pattern).lightened(0.2)])
	for e in t.order:
		lines.append(["%s Lv%d: %s" % [Elem.NAMES[e], t.lv(e), Elem.RIDER[e]], Elem.COLORS[e]])
	var ex := t.extras_text()
	if ex != "":
		lines.append(["강화·연계: " + ex, Color(1, 0.85, 0.45)])
	if Rules.mod_slots:
		lines.append([t.slots_text(), Color(1, 0.55, 0.45) if t.slots_used() > t.slots() else Color(1, 0.85, 0.45)])
	lines.append(["피해 배율 x%.2f" % t.dmg_factor(), Color(1, 1, 1, 0.8)])
	var rxs := t.reactions()
	if rxs.size() <= 5:
		for r in rxs:
			lines.append(["반응 %s: %s" % [r["name"], r["desc"]], r["color"]])
	else:
		# 반응이 많으면 이름만 (설명까지 쓰면 화면 높이를 넘음)
		lines.append(["반응 %d개: %s" % [rxs.size(), ", ".join(rxs.map(func(r): return r["name"]))], Color(1, 0.8, 0.95)])
	if wave_time > 1.0:
		var total := 0.0
		for o in towers.get_children():
			total += o.dealt
		var share := " · 전체의 %d%%" % roundi(t.dealt / total * 100.0) if total > 0.0 and towers.get_child_count() > 1 else ""
		lines.append(["%s 피해 %d (초당 %.1f%s)" % ["이번 웨이브" if phase == Phase.WAVE else "지난 웨이브", roundi(t.dealt), t.dealt / wave_time, share], Color(1, 0.9, 0.5)])
	if t.order.size() > 1:
		lines.append(["쌓기 대가: 공격 속도 -%d%%" % roundi((1.0 - 1.0 / t.tax()) * 100.0), Color(1, 0.6, 0.6)])
	var rows: Array = []
	var w := 0.0
	for l in lines:
		var lw := ui_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if lw <= maxw:
			rows.append(l)
			w = maxf(w, lw)
			continue
		for row in _wrap_words(l[0], maxw, fs).split("\n"):
			rows.append([row, l[1]])
			w = maxf(w, ui_font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	lines = rows
	var h := lines.size() * 18.0 + 10.0
	var size := get_viewport_rect().size
	var p := t.position + Vector2(28, -h / 2)
	p.x = clampf(p.x, 8, _right_limit() - w - 16)
	var top := _tip_top()
	p.y = clampf(p.y, top if h <= size.y - top - 8.0 else 8.0, size.y - h - 8)
	# 오른쪽 설명에 밀려 왼쪽으로 오면 오브젝트를 덮는다: 위나 아래로 비킨다
	if Rect2(p, Vector2(w + 16, h)).intersects(Rect2(t.position - Vector2(26, 26), Vector2(52, 52))):
		var above := t.position.y - 30.0 - h
		p.y = above if above >= top else minf(t.position.y + 30.0, size.y - h - 8)
	p = _avoid_cards(Rect2(p, Vector2(w + 16, h)), size)
	fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(0.05, 0.06, 0.09, 0.92))
	fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(1, 1, 1, 0.2), false, 1.0)
	for i in lines.size():
		fx_layer.draw_string(ui_font, p + Vector2(8, 20 + i * 18), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lines[i][1])


## 정보창을 놓을 수 있는 위쪽 끝: 점수 줄 아래 (점수 줄이 정보창 첫 줄을 덮던 것).
func _tip_top() -> float:
	if not hud.visible:
		return 8.0
	return (get_canvas_transform().affine_inverse() * hud.get_global_rect()).end.y + 6.0


## 글자를 놓을 수 있는 오른쪽 끝: 오른쪽 설명이 떠 있으면 그 앞까지 (설명이 글자를 가린다).
func _right_limit() -> float:
	var r := get_viewport_rect().size.x - 8.0
	if legend.visible:
		r = minf(r, (get_canvas_transform().affine_inverse() * legend.get_global_rect()).position.x - 8.0)
	return r


## 선택지 카드가 떠 있으면 툴팁이 카드 뒤에 가려지지 않게 위나 아래로 비킨다.
func _avoid_cards(r: Rect2, size: Vector2) -> Vector2:
	if not choice_box.visible or choice_box.get_child_count() == 0 or cards_hidden:
		return r.position
	var inv := get_canvas_transform().affine_inverse()
	var cr: Rect2 = inv * choice_box.get_global_rect()
	for b in [reroll_btn, hide_btn]:
		if b.visible:
			cr = cr.merge(inv * b.get_global_rect())
	cr = cr.grow(6.0)
	if not cr.intersects(r):
		return r.position
	var up := cr.position.y - r.size.y
	var down := cr.end.y
	if up >= 8.0 and (r.get_center().y < cr.get_center().y or down + r.size.y > size.y - 8.0):
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
		if o.vuln_t > 0.0: parts.append("약화")
		if o.slow_timer > 0.0: parts.append("감속")
		if o.frozen_t > 0.0: parts.append("빙결")
		if o.prison_t > 0.0: parts.append("감옥(받는 피해 +50%)")
		if o.swamp_t > 0.0: parts.append("독늪(중독 2배)")
		if o.curse_lv > 0: parts.append("저주")
		if o.resist_e >= 0: parts.append("%s 저항" % Elem.NAMES[o.resist_e])
		if o.sturdy: parts.append("굳셈")
		var txt := " · ".join(parts)
		var w := ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var p: Vector2 = o.position + Vector2(-w / 2 - 8, -o.radius() - 40)
		p.x = clampf(p.x, 8, get_viewport_rect().size.x - w - 24)
		p.y = maxf(p.y, _tip_top())
		fx_layer.draw_rect(Rect2(p, Vector2(w + 16, 24)), Color(0.05, 0.06, 0.09, 0.9))
		fx_layer.draw_string(ui_font, p + Vector2(8, 17), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


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

func _draw_fx() -> void:
	var vs := get_viewport_rect().size
	for i in 6:
		var w := 14.0 * (6 - i)
		var col := Color(0, 0, 0, 0.05)
		fx_layer.draw_rect(Rect2(0, 0, vs.x, w), col)
		fx_layer.draw_rect(Rect2(0, vs.y - w, vs.x, w), col)
		fx_layer.draw_rect(Rect2(0, 0, w, vs.y), col)
		fx_layer.draw_rect(Rect2(vs.x - w, 0, w, vs.y), col)
	if phase == Phase.GAMEOVER or title_label.visible:
		fx_layer.draw_rect(get_viewport_rect(), Color(0, 0, 0, 0.6))
	if eclipse_flash > 0.0:
		fx_layer.draw_rect(get_viewport_rect(), Color(0.1, 0.0, 0.15, 0.5 * eclipse_flash / 0.6))
	for a in arcs:
		fx_layer.draw_line(a[0], a[1], Elem.COLORS[Elem.ELECTRIC], 2.0)
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
		var al := clampf(b[1] / 0.22, 0.0, 1.0)
		fx_layer.draw_polyline(pts, Color(ec, 0.35 * al), 9.0)
		fx_layer.draw_polyline(pts, Color(ec, al), 3.5)
		fx_layer.draw_polyline(pts, Color(1, 1, 1, al), 1.2)
		for q in src.slice(1):
			fx_layer.draw_circle(q, 6.0, Color(ec, 0.5 * al))
	for p in particles:
		fx_layer.draw_circle(p[0], p[4] * clampf(p[2] / 0.4, 0.2, 1.0), p[3])
	for p in popups:
		var size := 22 if p[4] else 14
		var a := clampf(p[2] / 0.3, 0.0, 1.0)
		# 숫자는 기본 글꼴, 한글이 든 글자(콤보·최다 피해)는 한글 글꼴
		var f: Font = ThemeDB.fallback_font if p[1].is_valid_int() else ui_font
		fx_layer.draw_string(f, p[0] + Vector2(1, 1), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * a))
		fx_layer.draw_string(f, p[0], p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(p[3], a))
	_draw_boss_bar()
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
	var p := Vector2(center().x - w / 2.0, hud.position.y + hud.size.y + 20.0) + camera.offset
	fx_layer.draw_rect(Rect2(p, Vector2(w, 10)), Color(0, 0, 0, 0.6))
	fx_layer.draw_rect(Rect2(p, Vector2(w * clampf(hp / mx, 0.0, 1.0), 10)), Color(1, 0.3, 0.4))
	fx_layer.draw_rect(Rect2(p, Vector2(w, 10)), Color(1, 1, 1, 0.3), false, 1.0)
	var txt := "보스%s  %d / %d" % [" x%d" % n if n > 1 else "", ceili(hp), ceili(mx)]
	fx_layer.draw_string(ui_font, p + Vector2(1, -3), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0, 0, 0, 0.8))
	fx_layer.draw_string(ui_font, p + Vector2(0, -4), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(1, 0.85, 0.88))


## 투척형 발사체가 착지했을 때.
func _land(p: Projectile) -> void:
	var tw: Tower = p.owner_tower if is_instance_valid(p.owner_tower) else null
	match p.kind:
		"log":
			spawn_zone("burn", p.level, p.position, tw)
		"dark":
			spawn_zone("vortex", p.level, p.position, tw)
		"blob":
			spawn_zone("puddle", p.level, p.position, tw)
		"mushroom":
			var z := spawn_zone("mine", p.level, p.position, tw)
			if tw:
				tw.mines.erase(p)
				tw.mines.append(z)


## 얼음 탄이 깨지며 파편 3개.
func _shatter(p: Projectile) -> void:
	if not is_instance_valid(p.owner_tower):
		return
	for a in [-0.6, 0.0, 0.6]:
		var f := spawn_proj(p.owner_tower, "frag", p.level, p.vel.normalized().rotated(a))
		f.position = p.position + p.vel.normalized() * 14.0
		f.hit = p.hit.duplicate()


# ---------- 그리기 ----------

func _draw() -> void:
	var size := get_viewport_rect().size
	var mp: Dictionary = Meta.MAPS[Meta.map_id]
	draw_rect(Rect2(Vector2.ZERO, size), mp["bg"])
	var c := center()
	var now := Time.get_ticks_msec() / 1000.0
	for st in stars:
		draw_circle(Vector2(st.x, st.y), 1.2, Color(1, 1, 1, st.z * (0.7 + 0.3 * sin(now * 1.3 + st.x))))
	for i in range(1, 5):
		draw_arc(c, i * 110.0, 0, TAU, 64, mp["ring"], 1.0)
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
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))

	# 구체 진입 방향 표시
	var vr := get_viewport_rect()
	for a in lanes:
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
			draw_dashed_line(c + d * 40.0, tip, Color(col, 0.25), 1.5, 8.0)
			# 중앙 쪽으로 흘러가는 점
			var L := (tip - c).length()
			for k in 5:
				var f := fmod(now * 0.25 + k / 5.0, 1.0)
				draw_circle(tip - d * f * (L - 40.0), 2.5, Color(col, 0.5 * (1.0 - f)))

	_draw_boss_path(now)
	# 누수: 구체가 들어온 화면 가장자리가 붉게 번진다 (어느 길목이 뚫렸는지)
	for lf in leak_flash:
		var f: float = lf[1] / 1.2
		for k in 4:
			draw_circle(lf[0], 40.0 + k * 34.0, Color(1, 0.15, 0.2, 0.16 * f * (1.0 - k * 0.22)))

	# 연결선
	for t in towers.get_children():
		for o in t.links:
			if is_instance_valid(o) and t.get_instance_id() < o.get_instance_id():
				if not t.link_on(o):
					# 거리를 넘으면 끊김: 흐린 점선
					draw_dashed_line(t.position, o.position, Color(1, 0.4, 0.4, 0.5), 2.0, 10.0)
					continue
				var lc: Color = t.color().lerp(o.color(), 0.5)
				var flick := 0.7 + 0.3 * sin(now * 12.0 + t.position.x)
				draw_line(t.position, o.position, Color(lc, 0.25 * flick), 12.0)
				draw_line(t.position, o.position, Color(lc, 0.9 * flick), 3.0)
				draw_line(t.position, o.position, Color(1, 1, 1, 0.6 * flick), 1.0)
	var mpos := get_global_mouse_position()
	if phase == Phase.CHOOSE and hover_elem >= 0:
		var pulse2 := 0.5 + 0.5 * sin(now * 6.7)
		for t in towers.get_children():
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
				var fresh := Elem.new_reactions(t.eff_now(), picked["e"])
				if not fresh.is_empty():
					draw_arc(t.position, Tower.RADIUS + 10.0 + pulse * 4.0, 0, TAU, 32, Color(fresh[0]["color"], 0.9), 3.0)
		if picked["type"] in ["pat", "mod", "elem"]:
			for t in towers.get_children():
				if t.can_take(picked):
					if picked["type"] != "elem":
						draw_arc(t.position, Tower.RADIUS + 10.0 + pulse * 4.0, 0, TAU, 32, Color(col, 0.9), 3.0)
				else:
					draw_line(t.position + Vector2(-8, -8), t.position + Vector2(8, 8), Color(1, 0.3, 0.3, 0.7), 3.0)
					draw_line(t.position + Vector2(8, -8), t.position + Vector2(-8, 8), Color(1, 0.3, 0.3, 0.7), 3.0)
		if link_a:
			draw_arc(link_a.position, Rules.link_range, 0, TAU, 64, Color(col, 0.35), 1.5)
			var to := press_t.position if dragging and press_t != link_a else mpos
			if link_a.position.distance_to(to) <= Rules.link_range:
				draw_line(link_a.position, to, Color(col, 0.7), 3.0)
			else:
				draw_dashed_line(link_a.position, to, Color(1, 0.4, 0.4, 0.8), 3.0, 10.0)
				draw_string(ui_font, to + Vector2(-30, Tower.RADIUS + 36), "너무 멂", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.5, 0.5))
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
		for o in mover.links:
			if is_instance_valid(o) and not o in movers:
				var ok: bool = mover.position.distance_to(o.position) <= Rules.link_range
				draw_arc(o.position, Rules.link_range, 0, TAU, 64, Color(1, 1, 1, 0.15) if ok else Color(1, 0.4, 0.4, 0.35), 1.5)
				if ok:
					draw_line(mover.position, o.position, Color(0.6, 1, 1, 0.6), 2.0)
				else:
					draw_dashed_line(mover.position, o.position, Color(1, 0.4, 0.4, 0.7), 2.0, 10.0)
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
		var b := Meta.best_of(Meta.key())
		best_wave = b[0]
		best_score = b[1]
		auto_start = Meta.val(cfg, "option", "auto_start", false)
		legend_hidden = Meta.val(cfg, "option", "legend_hidden", false)
		bar_open = Meta.val(cfg, "option", "bar_open", false)
		sfx.muted = Meta.val(cfg, "option", "muted", false)
		fast_speed = Meta.val(cfg, "option", "fast_speed", 2.0)
		if not fast_speed in SPEEDS:
			fast_speed = 2.0


func _save_best() -> void:
	var cfg := ConfigFile.new()
	var b := Meta.best_of(Meta.key())
	if best_wave > b[0] or best_score > b[1]:
		Meta.map_best[Meta.key()] = [maxi(best_wave, b[0]), maxi(best_score, b[1])]
	Meta.save_into(cfg)
	cfg.set_value("option", "auto_start", auto_start)
	cfg.set_value("option", "legend_hidden", legend_hidden)
	cfg.set_value("option", "bar_open", bar_open)
	cfg.set_value("option", "muted", sfx.muted)
	cfg.set_value("option", "fast_speed", fast_speed)
	cfg.save(SAVE_PATH)
