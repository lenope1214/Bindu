extends Node2D
## 게임 진행: 웨이브, 오브젝트 선택·설치, 충돌, 점수.

enum Phase { CHOOSE, PLACE, AIM, WAVE, GAMEOVER, MOVE, READY }

const CORE_RADIUS := 14.0
const CORE_MAX_HP := 10
const MERGE_DIST := 30.0
const SAVE_PATH := "user://best.cfg"
const READY_HINT := "Space 또는 [웨이브 시작]: 시작   오브젝트 클릭: 위치·방향 변경"
const PAUSE_TEXT := "일시정지\nP / Esc: 계속   R: 처음부터   M: 소리   O: 설정   F11: 전체 화면"
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
var legend_hidden := false
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
var map_label: Label
var rules_label: Label
var skin_label: Label
var core_label: Label
var records_panel: Label
var settings_panel: PanelContainer
var new_achievements: Array = []  # 이번 판에 새로 달성한 업적 이름
var help_label: Label
var hover_elem := -1  # 마우스를 올린 선택지의 속성
var wave_time := 0.0  # 이번 웨이브 경과 시간
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
	# 창 제목에도 한글 이름과 버전 (작업 표시줄에서 어떤 빌드인지 보이게)
	get_window().title = "빈두 v%s" % ProjectSettings.get_setting("application/config/version", "?")
	if title_seen or DisplayServer.get_name() == "headless":
		_start_choose()
	else:
		title_label.visible = true
		hint.text = ""


## 창이 포커스를 잃어도 판은 계속 진행된다 (직접 조작이 없으니 멈추지 않음).
func _notification(what: int) -> void:
	# Android 뒤로가기 = Esc (한 단계 되돌리기 / 일시정지)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		Input.parse_input_event(esc)


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
	hint.size = Vector2(630, 44)
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
	start_btn = Button.new()
	start_btn.text = "웨이브 시작 (Space)"
	start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	start_btn.position = Vector2(-110, -100)
	start_btn.size = Vector2(220, 44)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_start_wave_from_ready)
	start_btn.visible = false
	root.add_child(start_btn)
	for b in [pause_btn, speed_btn, reroll_btn, auto_btn, start_btn, mute_btn]:
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
	paused_label.text = PAUSE_TEXT
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.03, 0.04, 0.06, 0.85)
	psb.set_corner_radius_all(8)
	paused_label.add_theme_stylebox_override("normal", psb)
	paused_label.visible = false
	root.add_child(paused_label)

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
		"P / Esc: 일시정지   M: 소리   O: 설정   Tab: 설명 보기·숨기기   H: 도움말   F11: 전체 화면",
		"R: 다시 시작 (게임 오버 뒤, 또는 일시정지 중 두 번)",
		"",
		"[규칙 · %s]" % Rules.NAMES[Rules.version],
		"중앙 체력 10. 구체가 닿으면 줄어듭니다",
		"쉬는 시간마다 3개 중 1개를 고릅니다 (처음 두 번은 2번)" if Rules.picks == 1 else "쉬는 시간마다 3개 중 1개씩 %d번 고릅니다" % Rules.picks,
		"5웨이브마다 보스. 처치하면 체력 +2, 새로고침 +1",
		"보스 웨이브를 넘기면 특성(전역 강화) 3개 중 1개 선택",
		"공격방식은 직선탄일 때 한 번만 정할 수 있고, 같은 것을 넣으면 레벨업",
		"속성을 많이 겹칠수록 피해는 늘고 공격 속도는 조금씩 느려집니다. %s" % mods,
		"감속은 최대 70%, 밀기는 조금씩만, 기절·속박·빙결은 연달아 걸리면 짧아지다 잠깐 면역",
		"화면 밖 구체는 맞지 않습니다. 시작 화면에서 규칙 버전(↑/↓)과 맵(←/→)을 바꿀 수 있어요",
	])


## 실행 중인 빌드가 최신인지 알아보도록 구석에 표시 (버전은 project.godot의 config/version).
func _ver_text() -> String:
	return "빈두 v%s · 규칙 %s" % [ProjectSettings.get_setting("application/config/version", "?"), Rules.NAMES[Meta.rules]]


static func wave_size(w: int) -> int:
	return 3 + w * 2


## 실제로 나오는 구체 수 (규칙 버전 배율, 십자로 맵 1.5배). 미리보기와 웨이브가 같은 값을 쓴다.
static func spawn_count(w: int) -> int:
	var n := roundi(wave_size(w) * Rules.orb_mul)
	if Meta.map_id == "cross":
		n = roundi(n * 1.5)
	return n


func _start_choose(new_round := true) -> void:
	phase = Phase.CHOOSE
	wave_active = false
	for p in projectiles.get_children():
		p.queue_free()
	for z in zones.get_children():
		z.queue_free()
	for t in towers.get_children():
		t.queue_redraw()
	if new_round:
		_roll_lanes()
		# 다음 웨이브 저항 속성: 12웨이브(버전 4는 8)부터 60% 확률
		wave_resist = Elem.ALL.pick_random() if wave + 1 >= Rules.resist_from and randf() < 0.6 else -1
		picks_left = 2 if wave <= 1 else Rules.picks  # 처음 두 번의 쉬는 시간은 2개씩
		rerolls_left = 1 + bonus_rerolls + perks.get("reroll", 0)
		bonus_rerolls = 0
	_update_preview()
	_make_choices()
	cards_hidden = false
	choice_box.visible = true
	_update_reroll_btn()
	hint.text = _choose_hint()


func _make_choices() -> void:
	for c in choice_box.get_children():
		c.queue_free()
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
	for i in offer.size():
		choice_box.add_child(_card_button(offer[i], i + 1))


## 같은 선택지인지 비교하는 키 (레벨은 무시).
func _card_key(card: Dictionary) -> String:
	return "%s:%s" % [card["type"], card.get("e", card.get("id", ""))]


## 선택지 한 장: 속성 / 공격방식 / 강화 / 연계 중 하나.
func _roll_card() -> Dictionary:
	var n := towers.get_child_count()
	if n > 0 and wave > 0:
		# 대격변: 각각 1%
		var c := randf()
		if c < 0.01:
			return {"type": "cata", "id": "elem"}
		if c < 0.02:
			return {"type": "cata", "id": "pat"}
	var r := randf()
	if n == 0 or wave == 0 or r < 0.42:
		var lv := 2 if randf() < minf(0.2 + 0.02 * wave, 0.5) + 0.2 * perks.get("luck", 0) else 1
		return {"type": "elem", "e": Elem.ALL.pick_random(), "lv": lv}
	if r < 0.67:
		return {"type": "pat", "id": Pat.PATTERN_IDS.slice(1).pick_random()}
	if r < 0.9:
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
			b.text = "[%d] 속성: %s%s\n부가: %s\n빈 곳: 새 오브젝트(직선탄)\n오브젝트 위: 겹치기%s" % [idx, Elem.NAMES[e], " Lv2" if card["lv"] == 2 else "", Elem.RIDER[e], " (%d종까지)" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else ""]
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
			b.text = "[%d] 강화: %s\n%s\n오브젝트 위에 놓기\n%s" % [idx, Pat.MODS[id]["name"], Pat.MODS[id]["desc"], "(종류별 %d개까지)" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "(쌓을수록 효과 절반씩)"]
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
	phase = Phase.CHOOSE
	wave_active = false
	perk_mode = true
	for p in projectiles.get_children():
		p.queue_free()
	for z in zones.get_children():
		z.queue_free()
	for c in choice_box.get_children():
		c.queue_free()
	var pool: Array = PERKS.duplicate()
	pool.shuffle()
	perk_offer = pool.slice(0, 3)
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
		b.text = _wrap_words("[%d] 특성: %s\n\n%s%s" % [i + 1, pk["name"], pk["desc"], "\n\n(보유 %d)" % have if have > 0 else ""], 220.0, 17)
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
	big_banner("특성 선택", Color(1, 0.85, 0.45))


func _on_perk(pk: Dictionary) -> void:
	if not perk_mode:
		return
	perk_mode = false
	var id: String = pk["id"]
	perks[id] = perks.get(id, 0) + 1
	match id:
		"power": Tower.dmg_mul += 0.15
		"haste": Tower.spd_mul += 0.12
		"reach": Tower.reach_mul += 0.12
		"core":
			core_max += 3
			core_hp = core_max
		"slow": orb_speed_mul *= 0.92
		"harmony": Tower.tax_step *= 0.5
	sfx.play("reaction", 0.0)
	_show_toast("특성: %s (%s)" % [pk["name"], pk["desc"]])
	for t in towers.get_children():
		t.queue_redraw()
	_start_choose()


func _perk_text() -> String:
	var parts := PackedStringArray()
	for pk in PERKS:
		var n: int = perks.get(pk["id"], 0)
		if n > 0:
			parts.append(pk["name"] + (" x%d" % n if n > 1 else ""))
	return "특성: " + ", ".join(parts) if not parts.is_empty() else ""


func _on_reroll() -> void:
	if rerolls_left <= 0 or phase != Phase.CHOOSE:
		return
	rerolls_left -= 1
	_make_choices()
	_update_reroll_btn()


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
	# 진입 방향: 3웨이브마다 하나씩 늘어 4곳, 이후 6웨이브마다 하나씩 최대 6곳
	var n := mini(1 + (wave + 1) / 3, 4 + maxi(0, (wave - 11) / 6))
	n = mini(n, 6)
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
		var a := randf() * TAU
		var ok := true
		for b in lanes:
			if absf(angle_difference(a, b)) < 0.8:
				ok = false
		if ok:
			lanes.append(a)


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
	lines.append("다음 웨이브 %d: 구체 %d개, 진입 방향 %d곳" % [nw, spawn_count(nw), lanes.size()])
	var mix := PackedStringArray()
	if nw >= 4:
		mix.append("빠른 구체(뾰족)")
	if nw >= 6:
		mix.append("단단한 구체(네모)")
	if nw >= 8:
		mix.append("보호막")
	if nw >= 10:
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
	var firsts := {4: "빠른 구체", 6: "단단한 구체", 8: "보호막 두른 구체(먼저 보호막을 깎아야 함)", 10: "분열 구체(터지면 둘로 나뉨)", 11: "이제부터 구체 체력이 웨이브마다 %d%%씩 곱으로 늘어남" % roundi((Rules.hp_growth - 1.0) * 100)}
	for f in [[Rules.resist_from, "저항 구체(같은 색 점선 고리: 그 속성 비중만큼 피해 최대 60% 감소)"], [Rules.sturdy_from, "굳센 구체(회색 쐐기: 밀기·감속·기절·냉기 절반)"]]:
		firsts[f[0]] = (firsts[f[0]] + ", " if firsts.has(f[0]) else "") + f[1]
	if firsts.has(nw):
		lines.append("처음 등장: " + firsts[nw])
	if nw % 5 == 0:
		lines.append("보스 등장! 중앙에 닿으면 체력 3 감소")
	if wave == 0:
		lines.append("빨간 화살표 방향에서 구체가 와요. 길목을 가로지르게 설치하세요.")
	# 자동 줄바꿈은 한글 낱말 중간에서도 끊으므로 띄어쓰기에서 직접 바꾼다
	preview.text = _wrap_words("\n".join(lines), 610.0, 15)
	preview.add_theme_color_override("font_color", Color(1, 0.75, 0.75) if nw % 5 == 0 else Color(1, 1, 1, 0.85))


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
	_after_place()


func _place_hint() -> String:
	match picked.get("type", "elem"):
		"elem":
			return PLACE_HINT
		"link":
			if picked["id"] == "link":
				return ("연결할 두 번째 오브젝트 클릭 (%d 이내)" % int(Rules.link_range) if link_a else "연결할 첫 오브젝트 클릭") + "   꾹 누르기·끌기: 옮기기\n우클릭/Esc: 다시 고르기"
	return "넣을 오브젝트를 클릭   꾹 누르기·끌기: 옮기기\n우클릭/Esc: 다시 고르기"


func _after_place() -> void:
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
	hint.text = ""
	big_banner("웨이브 %d" % wave, Color.WHITE)
	sfx.play("wave", 0.0)


func _game_over() -> void:
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
	_save_best()
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
	sfx.play("over", 0.0)
	reroll_btn.visible = false
	choice_box.visible = false
	hint.text = ""


# ---------- 입력 ----------

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
					_close_title()
				KEY_LEFT:
					_cycle_map(-1)
				KEY_RIGHT:
					_cycle_map(1)
				KEY_UP:
					_cycle_rules(-1)
				KEY_DOWN:
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
				paused_label.text = PAUSE_TEXT + "\nR을 한 번 더 누르면 처음부터"
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
	for spec in [["시작 (Enter)", _close_title], ["기록·업적", _toggle_records], ["설정 (O)", _toggle_settings], ["도움말 (H)", func(): help_label.visible = not help_label.visible]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(150, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
	row.get_child(0).add_theme_font_size_override("font_size", 20)

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
	for spec in [["화면 흔들림", "shake_on"], ["피해 숫자", "numbers_on"]]:
		var cb := CheckButton.new()
		cb.text = spec[0]
		cb.button_pressed = Meta.shake_on if spec[1] == "shake_on" else Meta.numbers_on
		cb.focus_mode = Control.FOCUS_NONE
		var key: String = spec[1]
		cb.toggled.connect(func(on):
			if key == "shake_on":
				Meta.shake_on = on
			else:
				Meta.numbers_on = on
			_save_best())
		sv.add_child(cb)
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
	rules_label.text = "규칙: %s  (↑/↓)\n%s" % [Rules.NAMES[Meta.rules], _wrap_parts(Rules.DESCS[Meta.rules], " · ", 470.0, 18)]
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
		"[특수 반응] 두 속성이 함께 있으면 추가 공격",
	])
	# 반응이 많아 한 줄에 두 개씩
	var rs: Array = Elem.REACTIONS
	for i in range(0, rs.size(), 2):
		var row := PackedStringArray()
		for r in rs.slice(i, i + 2):
			row.append("%s+%s %s" % [Elem.NAMES[r["a"]], Elem.NAMES[r["b"]], r["name"]])
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
	if links / 2 >= 3:
		_achieve("links3")
	if Meta.codex.size() >= 5:
		_achieve("codex5")
	if Meta.codex.size() >= Elem.REACTIONS.size():
		_achieve("codex9")


func _close_title() -> void:
	title_label.visible = false
	help_label.visible = false
	records_panel.visible = false
	settings_panel.visible = false
	lanes.clear()
	title_seen = true
	_start_choose()


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
	hint.text = "클릭: 새 위치   우클릭/Esc: 옮기기 취소"


func _toggle_pause() -> void:
	if phase == Phase.GAMEOVER or title_label.visible:
		return
	get_tree().paused = not get_tree().paused
	paused_label.visible = get_tree().paused
	paused_label.text = PAUSE_TEXT
	restart_armed = 0.0
	pause_btn.text = "계속 (P)" if get_tree().paused else "일시정지 (P)"


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
	t.rocks.append(spawn_zone("rock", l, t.position + t.dir * dist * Tower.reach(l), t))


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


func _spawn_orb(kind := -1) -> void:
	var o := Orb.new()
	var size := get_viewport_rect().size
	var r := size.length() / 2.0 + 30.0
	var spread := minf(0.15 + 0.01 * wave, 0.4)
	if Meta.map_id == "cross":
		spread = 0.06  # 십자로: 네 길 위로만 온다
	var a: float = lanes.pick_random() + randf_range(-spread, spread)
	o.position = center() + Vector2(cos(a), sin(a)) * r
	o.target = center()
	if kind < 0:
		kind = _roll_kind()
	o.main = self
	var hp := (1.0 + floorf(wave * 0.7) + randi() % 2) * hp_growth(wave)
	var spd := 36.0 + wave * 3.0 + randf() * 8.0
	match Meta.map_id:
		"spiral":
			o.swirl = 0.6
		"cross":
			hp = ceilf(hp * 1.6)
		"storm":
			hp = maxf(1.0, roundf(hp * 0.6))
	o.setup(kind, roundf(hp), spd)
	# 저항·굳셈: 쉬는 시간에 미리 알려 준 대로
	if wave_resist >= 0 and randf() < resist_share(wave):
		o.resist_e = wave_resist
	if randf() < sturdy_share(wave):
		o.sturdy = true
	# A4·A5: 보호막(8웨이브~), 분열(10웨이브~)
	if kind == Orb.Kind.NORMAL or kind == Orb.Kind.TANK:
		if wave >= 8 and randf() < minf(0.1 + 0.01 * wave, 0.3):
			o.shield = (2.0 + wave * 0.3) * hp_growth(wave)
		if wave >= 10 and randf() < 0.15:
			o.splits = true
	orbs.add_child(o)


## 피해 숫자 팝업.
func popup(pos: Vector2, amount: float, col: Color, big: bool, text := "", life := 0.7) -> void:
	if popups.size() > 120:
		return
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
	o.target = center()
	o.setup(Orb.Kind.FAST, maxf(1.0, roundf(wave * 0.5 * hp_growth(wave))), 36.0 + wave * 3.0)
	o.resist_e = boss.resist_e
	orbs.add_child(o)


## 분열 구체가 터지면 작은 구체 2개.
func _spawn_child(parent: Orb) -> void:
	var o := Orb.new()
	o.main = self
	o.position = parent.position + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	o.target = center()
	o.setup(Orb.Kind.NORMAL, maxf(1.0, ceilf(parent.max_hp * 0.4)), parent.speed * 1.1 / orb_speed_mul)
	o.resist_e = parent.resist_e
	o.sturdy = parent.sturdy
	orbs.add_child(o)


## 웨이브가 오를수록 빠른 구체(4웨이브~), 단단한 구체(6웨이브~)가 섞인다.
func _roll_kind() -> int:
	var x := randf()
	if wave >= 6 and x < minf(0.08 + 0.02 * wave, 0.3):
		return Orb.Kind.TANK
	if wave >= 4 and x > 1.0 - minf(0.1 + 0.03 * wave, 0.35):
		return Orb.Kind.FAST
	return Orb.Kind.NORMAL


# ---------- 루프 ----------

func _process(delta: float) -> void:
	toast_timer -= delta
	toast.visible = toast_timer > 0.0
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
	legend_btn.text = ("설명 보기" if legend_hidden else "설명 숨기기") + " (Tab)"
	legend.visible = legend.visible and not legend_hidden
	# 시작 화면 위에 설정·기록·도움말 창을 열면 뒤 메뉴 글자가 창 옆으로 삐져나와 보이지 않게 흐리게
	title_label.modulate.a = 0.12 if settings_panel.visible or records_panel.visible or help_label.visible else 1.0
	hud.visible = not title_label.visible  # 시작 화면엔 메뉴에 최고 기록이 따로 있다
	# 시작 화면에서 일시정지·배속 버튼을 누르면 메뉴 위에 일시정지 창이 뜨던 문제
	pause_btn.visible = not title_label.visible
	speed_btn.visible = not title_label.visible
	speed_pick.visible = not title_label.visible
	_update_hud()
	queue_redraw()
	if phase == Phase.MOVE and moving:
		moving.position = get_global_mouse_position().clamp(field_rect().position, field_rect().end)
	_update_press()
	if boxing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_box()  # 창 밖에서 손을 떼 놓기 이벤트를 못 받은 경우
	hide_btn.visible = phase == Phase.CHOOSE and not title_label.visible
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
			_spawn_orb(Orb.Kind.BOSS if to_spawn == 0 and wave % 5 == 0 else -1)
			if to_spawn == 0 and wave % 5 == 0:
				big_banner("보스 등장!", Color(1, 0.35, 0.4))
				sfx.play("boss", 0.0)

	wave_time += delta
	_resolve(delta)

	if core_hp <= 0:
		_game_over()
	elif to_spawn == 0 and _alive_count(orbs) == 0:
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
			core_hp = mini(core_hp + perks["regen"], core_max)
		if wave % 5 == 0:
			_start_perk()
		else:
			_start_choose()


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
	if phase in [Phase.PLACE, Phase.GAMEOVER, Phase.MOVE, Phase.AIM] or title_label.visible or dragging or boxing:
		return
	var t := _tower_at(get_global_mouse_position())
	if t == null:
		_draw_orb_tooltip()
		return
	var lines: Array = []  # [글자, 색]
	lines.append([t.title() + ("   (클릭: 옮기기 · 끌기: 바로 이동)" if phase in [Phase.CHOOSE, Phase.READY] and not perk_mode else ""), Color.WHITE])
	lines.append(["공격방식: %s Lv%d - %s" % [Pat.pname(t.pattern), t.plv, Pat.PATTERNS[t.pattern]["desc"]], Pat.pcolor(t.pattern).lightened(0.2)])
	for e in t.order:
		lines.append(["%s Lv%d: %s" % [Elem.NAMES[e], t.lv(e), Elem.RIDER[e]], Elem.COLORS[e]])
	var ex := t.extras_text()
	if ex != "":
		lines.append(["강화·연계: " + ex, Color(1, 0.85, 0.45)])
	lines.append(["피해 배율 x%.2f" % t.dmg_factor(), Color(1, 1, 1, 0.8)])
	for r in t.reactions():
		lines.append(["반응 %s: %s" % [r["name"], r["desc"]], r["color"]])
	if wave_time > 1.0:
		var total := 0.0
		for o in towers.get_children():
			total += o.dealt
		var share := " · 전체의 %d%%" % roundi(t.dealt / total * 100.0) if total > 0.0 and towers.get_child_count() > 1 else ""
		lines.append(["%s 피해 %d (초당 %.1f%s)" % ["이번 웨이브" if phase == Phase.WAVE else "지난 웨이브", roundi(t.dealt), t.dealt / wave_time, share], Color(1, 0.9, 0.5)])
	if t.order.size() > 1:
		lines.append(["쌓기 대가: 공격 속도 -%d%%" % roundi((1.0 - 1.0 / t.tax()) * 100.0), Color(1, 0.6, 0.6)])
	var fs := 14
	var w := 0.0
	for l in lines:
		w = maxf(w, ui_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var h := lines.size() * 18.0 + 10.0
	var size := get_viewport_rect().size
	var p := t.position + Vector2(28, -h / 2)
	p.x = clampf(p.x, 8, _right_limit() - w - 16)
	p.y = clampf(p.y, 8, size.y - h - 8)
	p = _avoid_cards(Rect2(p, Vector2(w + 16, h)), size)
	fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(0.05, 0.06, 0.09, 0.92))
	fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(1, 1, 1, 0.2), false, 1.0)
	for i in lines.size():
		fx_layer.draw_string(ui_font, p + Vector2(8, 20 + i * 18), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lines[i][1])


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
		p.y = maxf(p.y, 8)
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
	for a in lanes:
		var d := Vector2(cos(a), sin(a))
		var tip := _edge_point(c, d) - d * 18.0 - d * 6.0 * sin(now * 4.0)
		var col := Color(1, 0.3, 0.35, 0.9 if phase != Phase.WAVE else 0.35)
		draw_colored_polygon(PackedVector2Array([
			tip - d * 22.0,
			tip + d.orthogonal() * 12.0,
			tip - d.orthogonal() * 12.0,
		]), col)
		if phase != Phase.WAVE and Meta.map_id == "spiral":
			# 나선 경로 미리보기
			var p := tip
			var pts := PackedVector2Array([p])
			for k in 80:
				var to := c - p
				if to.length() < 30.0:
					break
				p += to.normalized().rotated(0.75 if to.length() > 60.0 else 0.0) * 14.0
				pts.append(p)
			draw_polyline(pts, Color(col, 0.3), 1.5)
		elif phase != Phase.WAVE:
			draw_dashed_line(c + d * 40.0, tip, Color(col, 0.25), 1.5, 8.0)
			# 중앙 쪽으로 흘러가는 점
			var L := (tip - c).length()
			for k in 5:
				var f := fmod(now * 0.25 + k / 5.0, 1.0)
				draw_circle(tip - d * f * (L - 40.0), 2.5, Color(col, 0.5 * (1.0 - f)))


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
	if Input.is_key_pressed(KEY_ALT) and not title_label.visible:
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
	cfg.set_value("option", "muted", sfx.muted)
	cfg.set_value("option", "fast_speed", fast_speed)
	cfg.save(SAVE_PATH)
