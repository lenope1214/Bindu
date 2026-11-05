class_name TutPlay
extends Control
## 플레이 튜토리얼: 연습 판 하나를 4장 23단계로 직접 해 보며 배운다 (features TUT-07~10).
## - 연습 판: 평원·랭크·모드 없음, 정해진 길목·카드. 중앙은 1 아래로 내려가지 않고, 기록·업적·도감·이어하기에 남지 않는다.
## - 단계마다 할 일 한 줄. 해내면(state 확인) 다음으로. [건너뛰기]는 그 단계 결과를 대신 만들어 다음 단계가 막히지 않게 한다.
## - [전체 건너뛰기]는 확인 창 뒤 시작 화면으로. 끝까지 하거나 끝내면 이 기기에서 다시 자동으로 뜨지 않는다(Tutorial.done).
## main은 TutPlay.on일 때만 몇 군데에서 이 노드에 묻는다 (offer·rest_picks·allow_pick·allow_place·lanes_for·can_start).

static var on := false  # 지금 연습 판인가 (main 여러 곳이 본다)
static var pending := -1  # 다시 불러온 뒤 시작할 장 (0~3, -1: 없음)
static var then_play := false  # 끝낸 뒤 바로 첫 판 (다시 불러온 뒤 일반 판 준비 화면)
static var orig := {}  # 연습 판 동안 바꿔 둔 설정의 원래 값 (저장할 때는 이 값으로)

const CHAPTERS := ["지키기 기본", "카드 네 가지", "웨이브 읽기와 손 기술", "마무리"]
const CH_START := [0, 7, 16, 21]  # 장마다 첫 단계 번호 (0부터)
const SPOT_FIRE := Vector2(170, 0)  # 중앙에서 떨어진 자리
const SPOT_MOVE := Vector2(190, -70)
const SPOT_WOOD := Vector2(0, 170)

## 단계: id, ch(장), rest(그 쉬는 시간의 wave 값, 웨이브 중 단계는 그 웨이브 번호), when(rest|wave|perk|end), card(이 단계에서 고를 카드)
## pc·touch: 할 일 글 (터치 글엔 키·클릭 말이 없다, spec TUT-08)
const STEPS := [
	{"id": "goal", "ch": 0, "rest": 0, "when": "rest", "name": "목표",
		"pc": "구체가 빨간 부채꼴 쪽에서 가운데 중앙으로 와요. 중앙에 닿지 않게 막는 게 목표예요",
		"touch": "구체가 빨간 부채꼴 쪽에서 가운데 중앙으로 와요. 중앙에 닿지 않게 막는 게 목표예요"},
	{"id": "place", "ch": 0, "rest": 0, "when": "rest", "name": "카드 들어 놓기", "card": {"type": "elem", "e": Elem.FIRE, "lv": 1},
		"pc": "아래 불 카드를 끌어 빛나는 자리에 놓으세요 (카드를 누른 뒤 자리를 눌러도 돼요)",
		"touch": "아래 불 카드를 끌어 빛나는 자리에 놓으세요 (카드를 누른 뒤 자리를 눌러도 돼요)"},
	{"id": "aim", "ch": 0, "rest": 0, "when": "rest", "name": "쏠 방향 정하기",
		"pc": "빨간 부채꼴 쪽을 클릭해 쏠 방향을 정하세요 (끌었다 놓아도 돼요)",
		"touch": "누른 채 부채꼴 쪽으로 끌어 범위를 보고, 손을 뗀 뒤 [확정]을 누르세요"},
	{"id": "wave1", "ch": 0, "rest": 0, "when": "rest", "name": "웨이브 시작",
		"pc": "[웨이브 시작](Space)을 누르고 구체를 막아 보세요",
		"touch": "[웨이브 시작]을 누르고 구체를 막아 보세요"},
	{"id": "move", "ch": 0, "rest": 1, "when": "rest", "name": "옮기기",
		"pc": "오브젝트를 끌어 빛나는 자리로 옮기세요. 방향은 그대로예요",
		"touch": "오브젝트를 꾹 누른 채 끌어 빛나는 자리로 옮기세요. 방향은 그대로예요"},
	{"id": "turn", "ch": 0, "rest": 1, "when": "rest", "name": "방향 바꾸기",
		"pc": "오브젝트를 클릭하고 새 방향을 클릭하세요. 우클릭한 채 끌어도 바로 돼요",
		"touch": "오브젝트를 짧게 누르고, 새 방향으로 끌었다 뗀 뒤 [확정]을 누르세요"},
	{"id": "zoom", "ch": 0, "rest": 1, "when": "rest", "name": "전장 확대",
		"pc": "마우스 휠로 전장을 키웠다 줄여 보세요. 휠을 누른 채 끌면 화면이 움직여요",
		"touch": "두 손가락을 벌려 전장을 키웠다 모아 보세요. 두 손가락으로 끌면 화면이 움직여요"},
	{"id": "stack", "ch": 1, "rest": 1, "when": "rest", "name": "속성 겹치기", "card": {"type": "elem", "e": Elem.WATER, "lv": 1},
		"pc": "물 카드를 불 오브젝트 위에 놓으세요. 속성이 겹치고, 새 조합이면 도감에 오를 반응이 생겨요",
		"touch": "물 카드를 불 오브젝트 위에 놓으세요. 속성이 겹치고, 새 조합이면 반응이 생겨요"},
	{"id": "second", "ch": 1, "rest": 1, "when": "rest", "name": "두 번째 오브젝트", "card": {"type": "elem", "e": Elem.WOOD, "lv": 1},
		"pc": "나무 카드를 아래쪽 빛나는 자리에 놓고 아래 길목 쪽으로 방향을 정하세요. 다음 웨이브부터 아래에서도 와요",
		"touch": "나무 카드를 아래쪽 빛나는 자리에 놓고 아래 길목 쪽으로 방향을 정하세요. 다음 웨이브부터 아래에서도 와요"},
	{"id": "pat", "ch": 1, "rest": 2, "when": "rest", "name": "공격방식 바꾸기", "card": {"type": "pat", "id": "spray"},
		"pc": "분사 카드를 나무 오브젝트에 넣으세요. 공격방식은 직선탄일 때 한 번만 바꿀 수 있어요",
		"touch": "분사 카드를 나무 오브젝트에 넣으세요. 공격방식은 직선탄일 때 한 번만 바꿀 수 있어요"},
	{"id": "mod", "ch": 1, "rest": 2, "when": "rest", "name": "강화", "card": {"type": "mod", "id": "multi"},
		"pc": "다중 발사 카드를 들고 불 오브젝트 위에 올려 바뀌는 점을 본 뒤 넣으세요",
		"touch": "다중 발사 카드를 한 번 눌러 미리보기를 본 뒤, 불 오브젝트에 넣으세요"},
	{"id": "detail", "ch": 1, "rest": 3, "when": "rest", "name": "카드 자세히",
		"pc": "카드 줄의 [자세히](Z)를 눌러 긴 설명을 켜 보세요. 다시 누르면 꺼져요",
		"touch": "카드 줄의 [자세히]를 눌러 긴 설명을 켜 보세요. 다시 누르면 꺼져요"},
	{"id": "tools", "ch": 1, "rest": 3, "when": "rest", "name": "새로고침·필드 보기·범위 보기",
		"pc": "Q로 선택지를 바꾸고, V로 카드를 내려 필드를 보고, Alt를 누르고 있어 모든 범위를 보세요",
		"touch": "[새로고침]으로 선택지를 바꾸고, [필드 보기]로 카드를 내리고, [범위 보기]를 눌러 보세요"},
	{"id": "trig", "ch": 1, "rest": 3, "when": "rest", "name": "발동", "card": {"type": "trig", "id": "vanguard"},
		"pc": "앞줄 강타 카드를 아무 오브젝트에 넣으세요. 체력이 많이 남은 구체를 더 세게 때려요",
		"touch": "앞줄 강타 카드를 아무 오브젝트에 넣으세요. 체력이 많이 남은 구체를 더 세게 때려요"},
	{"id": "link", "ch": 1, "rest": 3, "when": "rest", "name": "연계", "card": {"type": "link", "id": "reso"},
		"pc": "공명 카드를 넣고, 두 오브젝트를 가까이(빛나는 원 안) 두세요. 가까운 오브젝트 하나당 피해가 늘어요",
		"touch": "공명 카드를 넣고, 두 오브젝트를 가까이(빛나는 원 안) 두세요. 가까운 오브젝트 하나당 피해가 늘어요"},
	{"id": "info", "ch": 1, "rest": 3, "when": "rest", "name": "오브젝트 정보창",
		"pc": "오브젝트에 마우스를 올려 정보창을 보고, Shift를 눌러 자세히 보세요",
		"touch": "오브젝트를 짧게 눌러 정보창을 보고, [자세히]를 눌러 보세요"},
	{"id": "preview", "ch": 2, "rest": 4, "when": "rest", "name": "다음 웨이브 예고",
		"pc": "다음 웨이브 끝에 보스가 와요. 분홍 선이 보스가 지나갈 길이에요. 오브젝트 하나를 그 길 쪽으로 돌려 보세요",
		"touch": "다음 웨이브 끝에 보스가 와요. 분홍 선이 보스가 지나갈 길이에요. 오브젝트 하나를 그 길 쪽으로 돌려 보세요"},
	{"id": "ley", "ch": 2, "rest": 4, "when": "rest", "name": "기맥",
		"pc": "청록 고리(기맥) 위로 오브젝트 하나를 옮기세요. 그 위에선 피해가 늘어요",
		"touch": "청록 고리(기맥) 위로 오브젝트 하나를 옮기세요. 그 위에선 피해가 늘어요"},
	{"id": "skill", "ch": 2, "rest": 5, "when": "wave", "name": "중앙 기술",
		"pc": "아래 기술 버튼(1·2)을 눌러 쓸 곳을 클릭하세요. 집중은 오브젝트, 붙잡기는 구체 무리 위에",
		"touch": "아래 기술 버튼을 누르고 쓸 곳을 누르세요. 집중은 오브젝트, 붙잡기는 구체 무리 위에"},
	{"id": "speed", "ch": 2, "rest": 5, "when": "wave", "name": "배속·일시정지",
		"pc": "Space로 빠르게 했다 돌리고, P로 일시정지를 열었다 닫아 보세요",
		"touch": "오른쪽 아래 배속 버튼을 눌러 보고, 일시정지 버튼으로 멈췄다 계속해 보세요"},
	{"id": "perk", "ch": 2, "rest": 5, "when": "perk", "name": "보스와 특성",
		"pc": "보스를 막으면 특성을 하나 골라요. 운명의 동전을 고르면 던져서 결과를 받아요",
		"touch": "보스를 막으면 특성을 하나 골라요. 운명의 동전을 고르면 던져서 결과를 받아요"},
	{"id": "skip", "ch": 3, "rest": 5, "when": "rest", "name": "웨이브 넘기기",
		"pc": "[넘기기](S)를 누르면 카드 선택을 미뤄 두고 웨이브를 진행해요. 끝나면 쌓인 카드를 한꺼번에 골라요",
		"touch": "[넘기기]를 누르면 카드 선택을 미뤄 두고 웨이브를 진행해요. 끝나면 쌓인 카드를 한꺼번에 골라요"},
	{"id": "end", "ch": 3, "rest": 6, "when": "end", "name": "시작 화면 둘러보기", "pc": "", "touch": ""},
]
const END_ITEMS := [
	["규칙·모드", "일반 판 준비 화면에서 규칙(랭크·도파민 모드)과 어렵게·쉽게 모드를 골라요"],
	["맵", "준비 화면 맵 카드 다섯 장: 길 모양과 맵 규칙이 달라요"],
	["도감·업적", "고른 카드·만난 조합·특성이 모이고, 업적을 달성하면 모양과 칭호가 열려요"],
	["순위", "판이 끝나면 기록이 올라가요. 시즌·맵·규칙별로 봐요"],
	["멀티플레이", "6자리 코드로 최대 4명이 대결하거나 한 전장을 함께 지켜요"],
	["이어하기", "쉬는 시간마다 저장돼서 꺼도 그 쉬는 시간부터 이어 해요"],
]

var m: Node  # main
var idx := 0
var start_ch := 0
var base := {}  # 단계 시작 때 상태 (옮기기·방향·확대 비교용)
var flags := {}  # 단계 안 작은 할 일 (새로고침·필드 보기·범위 보기, 배속·일시정지)
var done_t := -1.0  # 해낸 뒤 ✓를 보여 주는 남은 시간
var ff := -1  # 장 고르기: 이 단계까지 건너뛰기로 빨리 감기
var force_start := false
var auto_perk := false
var quit_ask := false
var t := 0.0
var was_paused := false

var panel: PanelContainer
var head: Label
var body: Label
var btn_skip: Button
var btn_all: Button
var btn_ok: Button
var dots: Control
var ask: PanelContainer
var end_box: PanelContainer
var end_list: VBoxContainer
var marks: Control  # 강조 고리·손 그림 (전장 위, 창 아래)


# ---------- 시작·끝 ----------

## main._ready에서 pending이 있으면 부른다: 설정을 연습 판용으로 바꾸고 첫 쉬는 시간을 연다.
static func enter_meta() -> void:
	orig = _meta_now()
	Meta.map_id = "plain"
	Meta.rules = 1
	Meta.skill_set = 0
	Meta.skip_n = 1
	Meta.line_flip = false
	Modes.set_on([])
	on = true
	Ach.mp = "tut"  # 누적 수·도감 수집이 오르지 않게 (멀티 판과 같은 길, "mp_" 키만 받는데 연습 판엔 그런 일이 없다)


## 저장할 때는 원래 값으로 (연습 판 도중 꺼도 사용자의 맵·규칙·모드가 바뀌지 않게). 저장 앞뒤로 한 번씩 부른다.
static func swap() -> void:
	if not on or orig.is_empty():
		return
	var cur := _meta_now()
	_meta_put(orig)
	orig = cur


static func _meta_now() -> Dictionary:
	return {"map_id": Meta.map_id, "rules": Meta.rules, "modes": Array(Meta.modes), "skill_set": Meta.skill_set, "skip_n": Meta.skip_n, "line_flip": Meta.line_flip}


static func _meta_put(d: Dictionary) -> void:
	Meta.map_id = d["map_id"]
	Meta.rules = d["rules"]
	Meta.modes = d["modes"]
	Meta.skill_set = d["skill_set"]
	Meta.skip_n = d["skip_n"]
	Meta.line_flip = d["line_flip"]


static func leave_meta() -> void:
	if not orig.is_empty():
		_meta_put(orig)
		Modes.set_on(Meta.modes if Meta.games > 0 else [])
	orig = {}
	on = false
	Ach.mp = ""


func setup(main: Node, chapter: int) -> void:
	m = main
	start_ch = clampi(chapter, 0, CHAPTERS.size() - 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks = Control.new()
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks)
	add_child(marks)
	_build_panel()
	_build_ask()
	_build_end()
	idx = 0
	ff = CH_START[start_ch]
	_enter_step()


func _sb(a := 0.94) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, a)
	sb.border_color = Color(0.33, 0.76, 0.8, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	return sb


func _button(text: String, f: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(f)
	parent.add_child(b)
	return b


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "TutPlayPanel"
	panel.add_theme_stylebox_override("panel", _sb())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	head = Label.new()
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", Color(0.62, 0.68, 0.8))
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.clip_text = true
	top.add_child(head)
	btn_skip = _button("건너뛰기 ▸", skip_step, top)
	btn_all = _button("전체 건너뛰기 ✕", ask_quit, top)
	body = Label.new()
	body.add_theme_font_size_override("font_size", 17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	var bottom := HBoxContainer.new()
	v.add_child(bottom)
	dots = Control.new()
	dots.custom_minimum_size = Vector2(0, 12)
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.draw.connect(_draw_dots)
	bottom.add_child(dots)
	btn_ok = _button("알겠어요", _ok, bottom)


func _build_ask() -> void:
	ask = PanelContainer.new()
	ask.name = "TutPlayAsk"
	ask.add_theme_stylebox_override("panel", _sb(0.98))
	ask.mouse_filter = Control.MOUSE_FILTER_STOP
	ask.visible = false
	ask.z_index = 5  # 일시정지 어둠(20) 위
	add_child(ask)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	ask.add_child(v)
	var h := Label.new()
	h.text = "튜토리얼을 끝낼까요?"
	h.add_theme_font_size_override("font_size", 20)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var s := Label.new()
	s.text = PatchNotes.kr_keep("시작 화면 [튜토리얼]에서 언제든 처음부터나 원하는 장부터 다시 할 수 있어요")
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 360
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	s.add_theme_font_size_override("font_size", 15)
	v.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var b1 := _button("계속하기", func(): _close_ask(), row)
	var b2 := _button("끝내기", func(): finish(false), row)
	for b in [b1, b2]:
		b.custom_minimum_size = Vector2(150, 48)


func _build_end() -> void:
	end_box = PanelContainer.new()
	end_box.name = "TutPlayEnd"
	end_box.add_theme_stylebox_override("panel", _sb(0.98))
	end_box.mouse_filter = Control.MOUSE_FILTER_STOP
	end_box.visible = false
	end_box.z_index = 5
	add_child(end_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	end_box.add_child(v)
	var h := Label.new()
	h.text = "튜토리얼 끝"
	h.add_theme_font_size_override("font_size", 24)
	v.add_child(h)
	var s := Label.new()
	s.text = "판 밖에서 쓰는 것들은 시작 화면에 있어요"
	s.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	s.add_theme_font_size_override("font_size", 15)
	v.add_child(s)
	end_list = VBoxContainer.new()
	end_list.add_theme_constant_override("separation", 6)
	v.add_child(end_list)
	for it in END_ITEMS:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		var a := Label.new()
		a.text = it[0]
		a.custom_minimum_size.x = 110
		a.add_theme_color_override("font_color", Color(0.45, 0.85, 0.9))
		a.add_theme_font_size_override("font_size", 16)
		r.add_child(a)
		var b := Label.new()
		b.text = PatchNotes.kr_keep(it[1])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		r.add_child(b)
		end_list.add_child(r)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var b1 := _button("첫 판 시작", func(): finish(true, true), row)
	var b2 := _button("시작 화면으로", func(): finish(true), row)
	for b in [b1, b2]:
		b.custom_minimum_size = Vector2(170, 52)


## 끝내기: completed면 끝까지 한 것. play면 다시 불러온 뒤 바로 일반 판 준비 화면.
func finish(completed: bool, play := false) -> void:
	Tutorial.done = true
	Tutorial.play_done = Tutorial.play_done or completed or idx > 0
	Tutorial.save_file()
	leave_meta()
	then_play = play
	pending = -1
	get_tree().paused = false
	m.title_seen = false
	m._reload()


func ask_quit() -> void:
	quit_ask = true
	ask.visible = true
	was_paused = get_tree().paused
	get_tree().paused = true


func _close_ask() -> void:
	quit_ask = false
	ask.visible = false
	get_tree().paused = was_paused


# ---------- 단계 ----------

func step() -> Dictionary:
	return STEPS[idx] if idx < STEPS.size() else {}


func _touch() -> bool:
	return m.touch_ui


func step_text(s: Dictionary, for_touch: bool) -> String:
	return s.get("touch", s["pc"]) if for_touch else s["pc"]


func _enter_step() -> void:
	base = {"zoom": m.view_zoom, "pan": m.view_pan, "detail": Meta.card_detail, "rerolls": m.rerolls_left, "tw": {}}
	for tw in m.towers.get_children():
		base["tw"][tw.get_instance_id()] = [tw.position, tw.dir]
	flags = {}
	t = 0.0
	match step().get("id", ""):
		"speed":
			if not m.bar_open:
				m._toggle_bar()  # 배속·일시정지 버튼이 접혀 있으면 펼쳐 둔다
		"skip":
			Meta.skip_n = 1
		"end":
			end_box.visible = true


func _advance() -> void:
	idx += 1
	done_t = -1.0
	if idx < STEPS.size():
		_enter_step()


func _ok() -> void:
	if step().get("id", "") == "goal":
		_advance()


## 지금 단계를 해낼 수 있는 때인가 (그 쉬는 시간·웨이브·특성 화면).
func _active() -> bool:
	var s := step()
	if s.is_empty():
		return false
	var rest_ph: bool = m.phase in [m.Phase.CHOOSE, m.Phase.READY, m.Phase.PLACE, m.Phase.AIM, m.Phase.MOVE] and not m.perk_mode and m.coin_stage == 0
	match s["when"]:
		"rest", "end":
			return rest_ph and m.wave == s["rest"] and m.skip_left == 0 or s["id"] == "wave1" and m.wave == 0 and m.phase == m.Phase.WAVE
		"wave":
			return m.phase == m.Phase.WAVE and m.wave == s["rest"]
		"perk":
			return m.perk_mode or m.coin_stage > 0 or m.phase == m.Phase.WAVE and m.wave == s["rest"]
	return false


## 이미 지나간 단계인가 (웨이브를 넘겼거나 단계가 놓인 때가 지났다).
func _passed() -> bool:
	var s := step()
	match s["when"]:
		"rest":
			return m.wave > s["rest"] and s["id"] != "skip" or s["id"] == "skip" and m.wave > s["rest"] + 1
		"wave":
			return m.wave > s["rest"] or m.wave == s["rest"] and m.phase != m.Phase.WAVE
		"perk":
			return m.wave > s["rest"] and not m.perk_mode and m.coin_stage == 0 and not m.perks.is_empty()
	return false


## 단계를 해냈나: 상태로 본다 (순서를 앞질러 해도 그 단계에 오면 바로 ✓).
func is_done() -> bool:
	var s := step()
	match s["id"]:
		"goal":
			return m.towers.get_child_count() > 0 or m.phase != m.Phase.CHOOSE
		"place":
			return m.towers.get_child_count() > 0 or m.phase == m.Phase.AIM and m.moving == null
		"aim":
			return m.towers.get_child_count() > 0
		"wave1":
			return m.wave >= 1 and m.phase != m.Phase.WAVE
		"move":
			return not m.dragging and m.press_t == null and _moved() > 40.0
		"turn":
			return m.phase != m.Phase.AIM and m.moving == null and _turned() > 0.35
		"preview":
			return m.phase != m.Phase.AIM and m.moving == null and (_turned() > 0.35 or (_turned() > 0.02 or flags.has("aimed")) and _aims_boss())
		"zoom":
			return absf(m.view_zoom - base["zoom"]) > 0.2 or (m.view_pan - base["pan"]).length() > 40.0
		"stack":
			return _with(Elem.FIRE).any(func(tw): return tw.elements.has(Elem.WATER))
		"second":
			return not _with(Elem.WOOD).is_empty()
		"pat":
			return _with(Elem.WOOD).any(func(tw): return tw.pattern == "spray")
		"mod":
			return _with(Elem.FIRE).any(func(tw): return tw.mods.has("multi"))
		"detail":
			return Meta.card_detail != base["detail"]
		"tools":
			if m.rerolls_left < base["rerolls"]:
				flags["reroll"] = true
			if m.cards_hidden:
				flags["hide"] = true
			if Input.is_key_pressed(KEY_ALT) or m.range_all:
				flags["range"] = true
			return flags.size() >= 3
		"trig":
			return m.towers.get_children().any(func(tw): return tw.trigs.has("vanguard"))
		"link":
			return _reso_pair()
		"info":
			if m._ring_target() != null:
				flags["info"] = true
			return flags.has("info")
		"ley":
			return m.ley.is_empty() or m.towers.get_children().any(func(tw): return m.on_ley(tw))
		"skill":
			return m.skill_ids.is_empty() or m.skill_used >= mini(2, m.skill_ids.size())
		"speed":
			if m.game_speed > 1.0:
				flags["speed"] = true
			if get_tree().paused and not quit_ask:
				flags["pause"] = true
			return flags.has("speed") and flags.has("pause") and not get_tree().paused
		"perk":
			return not m.perks.is_empty() and not m.perk_mode and m.coin_stage == 0
		"skip":
			if m.skip_left > 0:
				flags["skip"] = true
			return flags.has("skip") and m.skip_left == 0 and m.phase != m.Phase.WAVE
	return false


func _with(e: int) -> Array:
	return m.towers.get_children().filter(func(tw): return tw.elements.has(e))


func _moved() -> float:
	var best := 0.0
	for tw in m.towers.get_children():
		var b: Array = base["tw"].get(tw.get_instance_id(), [])
		if not b.is_empty():
			best = maxf(best, tw.position.distance_to(b[0]))
	return best


func _turned() -> float:
	var best := 0.0
	for tw in m.towers.get_children():
		var b: Array = base["tw"].get(tw.get_instance_id(), [])
		if not b.is_empty():
			best = maxf(best, absf(tw.dir.angle_to(b[1])))
	return best


## 오브젝트 하나가 보스 길(중앙에서 240 떨어진 곳) 쪽을 겨누나.
func _aims_boss() -> bool:
	if m.boss_plan.is_empty():
		return true
	var q: Vector2 = m.core() + Vector2.from_angle(m.boss_plan["a"]) * 240.0
	return m.towers.get_children().any(func(tw): return absf(tw.dir.angle_to(q - tw.position)) < 0.4)


func _reso_pair() -> bool:
	var r: float = Rules.t("reso_r") * MapRule.reso_k()
	for tw in m.towers.get_children():
		if tw.reso > 0:
			for o in m.towers.get_children():
				if o != tw and o.position.distance_to(tw.position) <= r:
					return true
	return false


# ---------- main이 묻는 것 ----------

## 이번 쉬는 시간의 고르는 수: 카드 단계가 있는 쉬는 시간은 그 수만큼, 나머지는 보통대로(-1).
func rest_picks(w: int) -> int:
	var n := 0
	for s in STEPS:
		if s["rest"] == w and s.has("card"):
			n += 1
	return n if n > 0 else -1


## 이번에 쓸 카드 (지금 단계부터 이 쉬는 시간 안에서 아직 안 한 첫 카드 단계).
func want_card() -> Dictionary:
	for i in range(idx, STEPS.size()):
		var s: Dictionary = STEPS[i]
		if s["rest"] < m.wave:
			continue  # 지난 쉬는 시간의 단계 (웨이브 시작을 막기 전에 남은 것)
		if s["rest"] > m.wave or s["when"] != "rest":
			break
		if s.has("card") and not _card_done(s["id"]):
			return s["card"]
	return {}


func _card_done(id: String) -> bool:
	var keep := idx
	for i in STEPS.size():
		if STEPS[i]["id"] == id:
			idx = i
	var d := is_done()
	idx = keep
	return d


## 선택지: 정해진 카드 한 장 + 보통 선택지에서 두 장(골라지지 않는 흐린 카드). 카드 단계가 없으면 그대로.
func offer(base_offer: Array) -> Array:
	var want := want_card()
	if want.is_empty():
		return base_offer
	var out: Array = []
	for cd in base_offer:
		if out.size() >= 2:
			break
		if cd["type"] != want["type"] or cd.get("e", -1) != want.get("e", -2) and cd.get("id", "") != want.get("id", "_"):
			out.append(cd)
	out.insert(mini(1, out.size()), want)
	return out


## 고를 수 있는 카드인가 (정해진 카드만, 할 일이 카드가 아닌 단계에서는 막는다).
func allow_pick(card: Dictionary) -> bool:
	var want := want_card()
	if want.is_empty():
		return true
	var s := step()
	if not s.has("card") and s["id"] not in ["goal", "wave1"] and _active():
		m._show_toast("먼저 위 안내를 해 보세요 (건너뛰기도 돼요)")
		return false
	if card != want:
		m._show_toast("이번엔 %s 카드를 고르세요" % _card_name(want))
		return false
	return true


func _card_name(cd: Dictionary) -> String:
	if cd["type"] == "elem":
		return Elem.NAMES[cd["e"]]
	var table: Dictionary = {"pat": Pat.PATTERNS, "mod": Pat.MODS, "trig": Pat.TRIGS, "link": Pat.LINKS}.get(cd["type"], {})
	return table.get(cd.get("id", ""), {}).get("name", "")


## 카드를 놓을 곳이 맞나 (target: 그 자리 오브젝트, 없으면 빈 곳).
func allow_place(target: Node) -> bool:
	var want := want_card()
	if want.is_empty() or m.picked != want:
		return true
	var need := ""
	if want["type"] == "elem" and want["e"] == Elem.WATER or want["type"] == "mod":
		need = "fire"
	elif want["type"] == "pat":
		need = "wood"
	if want["type"] == "elem" and want["e"] != Elem.WATER:
		if target != null:
			m._show_toast("이번엔 빈 곳에 놓으세요")
			return false
		return true
	if need == "fire" and (target == null or not target.elements.has(Elem.FIRE)):
		m._show_toast("불 오브젝트 위에 놓으세요")
		return false
	if need == "wood" and (target == null or not target.elements.has(Elem.WOOD)):
		m._show_toast("나무 오브젝트에 넣으세요")
		return false
	return true


## 연습 판 길목: 1웨이브는 오른쪽 하나, 2웨이브부터 아래도, 6웨이브부터 왼쪽도.
static func lanes_for(w: int) -> Array:
	if w <= 1:
		return [0.0]
	if w <= 5:
		return [0.0, PI / 2.0]
	return [0.0, PI / 2.0, PI]


## 웨이브를 시작해도 되나: 이 쉬는 시간에 할 단계가 남았으면 막는다.
func can_start() -> bool:
	if force_start:
		force_start = false
		return true
	var s := step()
	if s.is_empty() or s["when"] != "rest" or s["id"] == "wave1" or m.wave != s["rest"]:
		return true
	m._show_toast("먼저 위 안내를 해 보세요 (건너뛰기도 돼요)")
	return false


func allow_skip() -> bool:
	return step().get("id", "") == "skip"


# ---------- 건너뛰기 ----------

func skip_step() -> void:
	if quit_ask or end_box.visible:
		return
	if not _active():
		_skip_gate()
		return
	_do_skip(false)
	_advance()


## 그 단계 결과를 대신 만든다. instant: 장 고르기 빨리 감기 (웨이브를 실제로 하지 않는다).
func _do_skip(instant: bool) -> void:
	var s := step()
	_settle()
	match s["id"]:
		"place":
			_pick(s["card"])
			m._place_card_at(_spot(SPOT_FIRE), true)
		"aim":
			if m.phase == m.Phase.AIM:
				m.picked = STEPS[1]["card"]
				m._place_tower(m.place_pos, _lane_dir(m.place_pos, 0.0))
				m.sfx.play("place")
				m._after_place()
			elif m.towers.get_child_count() == 0:
				_put(STEPS[1]["card"], _spot(SPOT_FIRE), 0.0)
		"wave1":
			_instant_wave() if instant or m.phase != m.Phase.WAVE else _clear_wave()
		"move":
			var f := _first(Elem.FIRE)
			if f:
				f.position = _spot(SPOT_MOVE)
				f.queue_redraw()
		"turn":
			var f := _first(Elem.FIRE)
			if f:
				f.set_attack_direction(f.dir.rotated(-0.5))
				f.queue_redraw()
		"preview":
			var f := _first(Elem.FIRE)
			if f and not m.boss_plan.is_empty():
				f.set_attack_direction(_lane_dir(f.position, m.boss_plan["a"]))
			elif f:
				f.set_attack_direction(f.dir.rotated(0.5))
			if f:
				f.queue_redraw()
		"stack":
			var f := _first(Elem.FIRE)
			if f:
				_pick(s["card"])
				f.add(Elem.WATER, 1)
				m._after_place()
		"second":
			_put(s["card"], _spot(SPOT_WOOD), PI / 2.0)
		"pat", "mod", "trig", "link":
			var tw: Node = _first(Elem.WOOD if s["id"] == "pat" else Elem.FIRE)
			if tw == null and m.towers.get_child_count() > 0:
				tw = m.towers.get_child(0)
			if tw and not _card_done(s["id"]):
				_pick(s["card"])
				m._apply_card(tw)
			if s["id"] == "link":
				_pair_up()
		"ley":
			if not m.ley.is_empty():
				var f := _first(Elem.FIRE)
				if f:
					f.position = m.ley[0]
					f.queue_redraw()
		"skill":
			for id in m.skill_ids:
				var p: Variant = Skill.auto_target(m, id)
				if p != null:
					m._use_skill(id, p)
		"perk":
			if m.perk_mode and m.coin_stage == 0 and not m.perk_offer.is_empty():
				m._on_perk(m.perk_offer.filter(func(pk): return pk["id"] != "coin")[0])
			elif m.coin_stage > 0:
				m._coin_done()
				auto_perk = true
			elif m.phase == m.Phase.WAVE and not instant:
				auto_perk = true
				_clear_wave()
			elif instant:
				m.wave = 5
				m._clear_shots()
				m._start_perk()
				if m.perk_mode and not m.perk_offer.is_empty():
					m._on_perk(m.perk_offer.filter(func(pk): return pk["id"] != "coin")[0])
		"skip":
			if m.skip_left == 0:
				flags["skip"] = true
				if instant:
					_instant_wave()


## 카드를 들거나 방향을 정하던 중이면 쉬는 시간 처음으로 되돌린다.
func _settle() -> void:
	if m.press_t:
		m._drop_press()
	if m.moving:
		m._cancel_step()
	if m.phase == m.Phase.PLACE:
		m._back_to_choose()


func _pick(card: Dictionary) -> void:
	if m.phase == m.Phase.CHOOSE:
		m._on_pick(card)
	m.picked = card


## 속성 카드로 새 오브젝트를 놓고 방향까지.
func _put(card: Dictionary, p: Vector2, lane: float) -> void:
	_pick(card)
	m._place_tower(p, _lane_dir(p, lane))
	m.sfx.play("place")
	m._after_place()


func _first(e: int) -> Node:
	var a := _with(e)
	return a[0] if not a.is_empty() else null


func _spot(off: Vector2) -> Vector2:
	return m.core() + off


## p에서 그 길목 구체가 지나가는 곳(중앙에서 260)을 겨누는 방향.
func _lane_dir(p: Vector2, a: float) -> Vector2:
	var q: Vector2 = m.core() + Vector2.from_angle(a) * 260.0
	var d := q - p
	return d.normalized() if d.length() > 1.0 else Vector2.from_angle(a)


## 공명: 두 오브젝트를 가까이 (멀리 쏘는 불을 나무 옆으로 옮겨 오른쪽 길목을 계속 겨눈다).
func _pair_up() -> void:
	if _reso_pair():
		return
	var f := _first(Elem.FIRE)
	var w := _first(Elem.WOOD)
	if f == null or w == null:
		return
	var p: Vector2 = w.position + Vector2(100, -50)
	if p.distance_to(m.core()) < 60.0 or m._tower_at(p, f) != null:
		p = w.position + Vector2(-100, -50)
	f.position = p
	f.set_attack_direction(_lane_dir(p, 0.0))
	f.queue_redraw()


## 웨이브를 실제로 하지 않고 막은 것으로 친다 (장 고르기 빨리 감기·웨이브 단계 건너뛰기).
func _instant_wave() -> void:
	_settle()
	m.picks_left = 0
	m.wave += 1
	m.wave_active = false
	m._clear_shots()
	for o in m.orbs.get_children():
		o.queue_free()
	m.to_spawn = 0
	m.start_btn.visible = false
	m._start_choose(true)


## 웨이브 중 건너뛰기: 남은 구체를 치우면 다음 계산에서 웨이브가 끝난다.
func _clear_wave() -> void:
	m.to_spawn = 0
	m.mp_extra_left = 0
	for o in m.orbs.get_children():
		o.queue_free()


## 이 쉬는 시간에 할 단계가 끝났고 다음 단계는 다음 웨이브 뒤: [건너뛰기] = 웨이브 시작 (길목을 못 겨누면 맞춰 주고).
func _skip_gate() -> void:
	var s := step()
	if s.is_empty():
		return
	if m.phase == m.Phase.WAVE:
		if s["when"] != "wave":
			_clear_wave()
		return
	# 남은 고르기는 넣을 수 있는 카드를 골라 대신 (속성은 빈 곳에, 나머지는 받아 주는 오브젝트에)
	if m.phase == m.Phase.PLACE:
		m._back_to_choose()  # 들고 있던 카드는 내려놓고 넣을 수 있는 카드부터
	var guard := 0
	while m.phase == m.Phase.CHOOSE and m.picks_left > 0 and not m.perk_mode and guard < 8:
		guard += 1
		var put := false
		for cd in m.offer.duplicate():
			if _auto_card(cd):
				put = true
				break
		if not put:
			break
	if m.perk_mode and not m.perk_offer.is_empty():
		m._on_perk(m.perk_offer[0])
		return
	if m.phase == m.Phase.READY:
		_cover_lanes()
		force_start = true
		m._start_wave()


## 카드 하나를 사람 대신 넣는다. 받아 줄 곳이 없으면 false (그 카드는 두고 다음 카드).
func _auto_card(cd: Dictionary) -> bool:
	if cd["type"] == "elem":
		_put(cd, _free_spot(), m.lanes[0] if not m.lanes.is_empty() else 0.0)
		return true
	var keep: Dictionary = m.picked
	m.picked = cd
	for tw in m.towers.get_children():
		if m._place_ok(tw):
			m.picked = keep
			_pick(cd)
			m._apply_card(tw)
			return true
	m.picked = keep
	return false


func _free_spot() -> Vector2:
	for k in 12:
		var p: Vector2 = m.core() + Vector2.from_angle(k * TAU / 12.0 + 0.3) * 200.0
		if m._tower_at(p) == null:
			return p
	return m.core() + Vector2(-200, -120)


## 웨이브를 시작할 수 없는 길목이 있으면 가장 가까운 오브젝트를 그쪽으로 돌린다.
func _cover_lanes() -> void:
	if m._wave_start_block_reason() == "":
		return
	var w: int = m.wave + 1
	var spread: float = m.lane_spread(w)
	for a in m.lanes:
		if m._wave_lane_covered(a, w, spread):
			continue
		var bestd := INF
		var best: Node = null
		for tw in m.towers.get_children():
			var d: float = tw.position.distance_to(m.core() + Vector2.from_angle(a) * 200.0)
			if d < bestd:
				bestd = d
				best = tw
		if best:
			best.set_attack_direction(_lane_dir(best.position, a))
			best.queue_redraw()


# ---------- 매 프레임 ----------

func _process(delta: float) -> void:
	if m == null or not on:
		return
	t += delta
	if ff >= 0:
		_fast_forward()
		return
	if idx >= STEPS.size():
		return
	var s := step()
	if s["id"] != "end":
		if done_t >= 0.0:
			done_t -= delta
			if done_t < 0.0:
				_advance()
		elif _active() and is_done():
			done_t = 0.6
			m.sfx.play("clear", 0.0)
		elif _passed():
			_advance()
	if auto_perk and m.perk_mode and m.coin_stage == 0 and not m.perk_offer.is_empty():
		auto_perk = false
		m._on_perk(m.perk_offer.filter(func(pk): return pk["id"] != "coin")[0])
	_layout()
	_refresh()
	_dim_cards()
	marks.queue_redraw()
	dots.queue_redraw()


## 장 고르기: 앞 단계를 한 프레임에 하나씩 건너뛰기로 채운다.
func _fast_forward() -> void:
	visible = true
	panel.visible = true
	head.text = "튜토리얼 · %s 준비 중" % CHAPTERS[start_ch]
	body.text = ""
	if idx >= ff:
		ff = -1
		_enter_step()
		return
	var s := step()
	if s["when"] in ["rest", "end"] and m.wave < s["rest"] and m.phase != m.Phase.WAVE:
		_instant_wave()  # 그 단계가 놓인 쉬는 시간까지 웨이브를 건너뛴다
		return
	_do_skip(true)
	_advance()


## 이번 단계에 쓸 카드가 아닌 선택지는 흐리게 (고르면 안내만 뜬다).
func _dim_cards() -> void:
	var want := want_card()
	for b in m.choice_box.get_children():
		if not b.has_meta("offer_card") or m.perk_mode:
			continue
		var lock: bool = not want.is_empty() and b.get_meta("offer_card") != want
		if lock:
			b.modulate.a = 0.35
		elif is_equal_approx(b.modulate.a, 0.35):
			b.modulate.a = 1.0


func _layout() -> void:
	# 왼쪽 위 점수 줄 오른쪽, 오른쪽 위 버튼·설명 왼쪽 틈에. 모자라면 점수 줄 아래 가운데
	var hud: Control = m.hud
	var left: float = hud.position.x + hud.size.x + 10.0
	var right: float = minf(m._right_panel_x(), size.x - (300.0 if m.range_btn.visible or m.zoom_btn.visible else 0.0)) - 10.0
	var w := minf(620.0, right - left)
	var top := 8.0
	if w < 420.0:
		w = minf(620.0, size.x - 32.0)
		left = (size.x - w) / 2.0
		top = hud.position.y + hud.size.y + 6.0
		# 점수 줄 아래 왼쪽 DPS 표는 가리지 않게 그 오른쪽으로 (자리가 모자라면 표 아래로)
		var dp: Control = m.dps_panel
		if dp and dp.is_visible_in_tree() and dp.position.y < top + 200.0:
			var dl := dp.position.x + dp.size.x + 10.0
			var edge := size.x - 16.0
			if m.phase == m.Phase.WAVE:
				edge -= 200.0 / maxf(m.ui_root.scale.x, 0.5)  # 오른쪽 위 콤보 칸
			var room := edge - dl
			if room >= 420.0:
				w = minf(w, room)
				left = maxf(left, dl)
				left = minf(left, edge - w)
			else:
				top = dp.position.y + dp.size.y + 6.0
	else:
		left += (right - left - w) / 2.0
	panel.size = Vector2(w, 0)
	panel.reset_size()
	panel.size.x = w
	panel.position = Vector2(left, top).floor()
	body.custom_minimum_size.x = w - 28.0
	ask.reset_size()
	ask.position = ((size - ask.size) / 2.0).floor()
	if end_box.visible:
		var ew := minf(640.0, size.x - 32.0)
		end_box.size = Vector2(ew, 0)
		end_box.reset_size()
		end_box.size.x = ew
		end_box.position = ((size - end_box.size) / 2.0).floor()


## 안내 칸 아래 끝 (main이 알림 글을 그 아래로 내린다).
func panel_bottom() -> float:
	return panel.get_rect().end.y if panel.visible else 0.0


func _refresh() -> void:
	var s := step()
	var tc := _touch()
	panel.visible = not end_box.visible and not (get_tree().paused and not quit_ask and s.get("id", "") != "speed") and not m.title_label.visible
	ask.visible = quit_ask
	btn_skip.text = "건너뛰기" if tc else "건너뛰기 ▸ (Tab)"
	btn_all.text = "전체 ✕" if tc else "전체 건너뛰기 ✕"
	var hgt := 52.0 if m._phone() else 32.0
	for b in [btn_skip, btn_all, btn_ok]:
		b.custom_minimum_size = Vector2(64.0 if m._phone() else 0.0, hgt)
	btn_ok.visible = s.get("id", "") == "goal"
	if s.is_empty() or s["id"] == "end":
		return
	head.text = "단계 %d/%d · %s · %s" % [idx + 1, STEPS.size(), CHAPTERS[s["ch"]], s["name"]]
	var txt := ""
	if done_t >= 0.0:
		txt = "✓ 잘했어요"
	elif _active():
		txt = step_text(s, tc)
		if s["id"] == "tools":
			txt += "\n%s 새로고침   %s 필드 보기   %s 범위 보기" % ["✓" if flags.has("reroll") else "○", "✓" if flags.has("hide") else "○", "✓" if flags.has("range") else "○"]
		elif s["id"] == "speed":
			txt += "\n%s 배속   %s 일시정지" % ["✓" if flags.has("speed") else "○", "✓" if flags.has("pause") else "○"]
	elif m.phase == m.Phase.WAVE:
		txt = "구체를 막는 중이에요. 다음 할 일은 웨이브가 끝나면 나와요"
	elif m.perk_mode or m.coin_stage > 0:
		txt = "특성을 하나 고르세요"
	elif m.phase == m.Phase.CHOOSE and m.picks_left > 0:
		txt = "카드를 골라 놓거나 넣으세요"
	else:
		txt = "[웨이브 시작]을 눌러 다음 웨이브를 막으세요" if tc else "[웨이브 시작](Space)을 눌러 다음 웨이브를 막으세요"
		var why: String = m._wave_start_block_reason() if m.phase == m.Phase.READY else ""
		if why != "":
			txt += "\n" + why.replace("웨이브를 시작할 수 없어요: ", "")
	body.text = PatchNotes.kr_keep(txt)
	btn_skip.disabled = m.phase == m.Phase.WAVE and not _active() and s["when"] == "wave" or done_t >= 0.0


func _input(event: InputEvent) -> void:
	if not on or m == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if quit_ask:
			if event.keycode == KEY_ESCAPE:
				_close_ask()
				get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				finish(false)
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB and not m.title_label.visible:
			skip_step()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and step().get("id", "") == "goal":
			_ok()
			get_viewport().set_input_as_handled()


# ---------- 그리기 ----------

## 할 일 대상: 전장 자리(월드) 또는 UI.
func _world_to_ui(p: Vector2) -> Vector2:
	var screen: Vector2 = m.get_canvas_transform() * p
	return get_global_transform_with_canvas().affine_inverse() * screen


func _ui_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var inv := get_global_transform().affine_inverse()
	return Rect2(inv * r.position, r.size / get_global_transform().get_scale())


func _ring(p: Vector2, r: float, col := Color(0.33, 0.86, 0.92)) -> void:
	var k := 0.5 + 0.5 * sin(t * 5.0)
	marks.draw_arc(p, r + 4.0 * k, 0, TAU, 48, Color(col, 0.55 + 0.4 * k), 3.0, true)


func _box(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		return
	var r := _ui_rect(c).grow(4.0)
	var k := 0.5 + 0.5 * sin(t * 5.0)
	marks.draw_rect(r, Color(0.33, 0.86, 0.92, 0.55 + 0.4 * k), false, 3.0)


## 손(터치)·마우스 그림이 a에서 b로 움직인다 (b가 없으면 a에서 누르기).
func _hand(a: Vector2, b = null) -> void:
	var ph := fmod(t, 1.6) / 1.6
	var p: Vector2 = a if b == null else a.lerp(b, clampf(ph * 1.3, 0.0, 1.0))
	var col := Color(1, 1, 1, 0.9)
	if _touch():
		marks.draw_circle(p + Vector2(6, 10), 11.0, Color(0.95, 0.82, 0.72, 0.85))
		if ph < 0.15 or b == null and ph < 0.5:
			marks.draw_arc(p + Vector2(6, 10), 16.0, 0, TAU, 24, Color(1, 1, 1, 0.6), 2.0)
	else:
		var pts := PackedVector2Array([p, p + Vector2(0, 20), p + Vector2(5, 15), p + Vector2(10, 24), p + Vector2(13, 22), p + Vector2(8, 13), p + Vector2(15, 13)])
		marks.draw_colored_polygon(pts, col)
		marks.draw_polyline(pts + PackedVector2Array([p]), Color(0, 0, 0, 0.6), 1.0)


func _draw_marks() -> void:
	if m == null or ff >= 0 or end_box.visible or get_tree().paused or done_t >= 0.0 or m.title_label.visible:
		return
	var s := step()
	if s.is_empty():
		return
	if not _active():
		if m.phase == m.Phase.READY:
			_box(m.start_btn)
		return
	var z: float = m.view_zoom
	match s["id"]:
		"goal":
			_ring(_world_to_ui(m.core()), 30.0 * z, Color(1, 0.88, 0.5))
		"place":
			var sp := _world_to_ui(_spot(SPOT_FIRE))
			_ring(sp, 26.0 * z)
			var btn := _card_btn(s["card"])
			if btn and m.phase == m.Phase.CHOOSE:
				_box(btn)
				_hand(_ui_rect(btn).get_center(), sp)
			else:
				_hand(sp)
		"aim":
			if m.phase == m.Phase.AIM:
				var a := _world_to_ui(m.place_pos)
				var b := _world_to_ui(m.place_pos + Vector2.from_angle(m.lanes[0] if not m.lanes.is_empty() else 0.0) * 120.0)
				_ring(b, 18.0)
				_hand(a, b)
				if m._ok_btn_on():
					_box(m.aim_ok_btn)
		"wave1":
			if m.phase == m.Phase.READY:
				_box(m.start_btn)
		"move":
			var f := _first(Elem.FIRE)
			if f:
				var a := _world_to_ui(f.position)
				var b := _world_to_ui(_spot(SPOT_MOVE))
				_ring(b, 26.0 * z)
				_hand(a, b)
		"turn", "preview":
			var f := _first(Elem.FIRE)
			if f:
				var a := _world_to_ui(f.position)
				_ring(a, 24.0 * z)
				var tgt: Vector2 = f.position + f.dir.rotated(0.8) * 110.0
				if s["id"] == "preview" and not m.boss_plan.is_empty():
					tgt = m.core() + Vector2.from_angle(m.boss_plan["a"]) * 240.0
				_hand(a, _world_to_ui(tgt))
				if m._ok_btn_on():
					_box(m.aim_ok_btn)
		"zoom":
			var c := _world_to_ui(m.core())
			if _touch():
				var d := 30.0 + 30.0 * fmod(t, 1.4) / 1.4
				_hand(c + Vector2(-d, d * 0.4))
				_hand(c + Vector2(d, -d * 0.4))
			else:
				_ring(c, 60.0, Color(1, 1, 1, 0.5))
		"stack", "pat", "mod":
			var tw := _first(Elem.WOOD if s["id"] == "pat" else Elem.FIRE)
			var btn := _card_btn(s["card"])
			if tw:
				var a := _world_to_ui(tw.position)
				_ring(a, 26.0 * z)
				if btn and m.phase == m.Phase.CHOOSE:
					_box(btn)
					_hand(_ui_rect(btn).get_center(), a)
		"second":
			var sp := _world_to_ui(_spot(SPOT_WOOD))
			_ring(sp, 26.0 * z)
			var btn := _card_btn(s["card"])
			if btn and m.phase == m.Phase.CHOOSE:
				_box(btn)
				_hand(_ui_rect(btn).get_center(), sp)
		"detail":
			_box(m.card_detail_btn)
		"tools":
			if not flags.has("reroll"):
				_box(m.reroll_btn)
			if not flags.has("hide"):
				_box(m.hide_btn)
			if not flags.has("range") and _touch():
				_box(m.range_btn)
		"trig", "link":
			var btn := _card_btn(s["card"])
			if btn and m.phase == m.Phase.CHOOSE:
				_box(btn)
			if s["id"] == "link":
				for tw in m.towers.get_children():
					if tw.reso > 0:
						_ring(_world_to_ui(tw.position), Rules.t("reso_r") * MapRule.reso_k() * z, Color(0.7, 0.6, 1.0))
		"info":
			var tw := _first(Elem.FIRE)
			if tw:
				_ring(_world_to_ui(tw.position), 24.0 * z)
			if _touch():
				_box(m.detail_btn)
		"ley":
			for p in m.ley:
				_ring(_world_to_ui(p), 44.0 * z, Color(0.3, 0.95, 0.85))
		"skill":
			for b in m.skill_btns:
				_box(b)
		"speed":
			if not flags.has("speed"):
				_box(m.speed_btn)
			if not flags.has("pause"):
				_box(m.pause_btn)
		"skip":
			_box(m.skip_btn)


func _card_btn(card: Dictionary) -> Control:
	for b in m.choice_box.get_children():
		if b.get_meta("offer_card", {}) == card:
			return b
	return null


func _draw_dots() -> void:
	var n := STEPS.size()
	var gap := minf(14.0, (dots.size.x - 8.0) / n)
	for i in n:
		var col := Color(0.33, 0.76, 0.8) if i < idx else Color(0.89, 0.71, 0.29) if i == idx else Color(0.25, 0.28, 0.38)
		dots.draw_circle(Vector2(5.0 + i * gap, 6.0), 3.0, col)
