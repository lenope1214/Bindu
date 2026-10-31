class_name Tutorial
extends Control
## 튜토리얼: 항목(TOPICS)마다 그림 + 설명 카드 몇 장. 기기마다 처음 켜면 기본 항목(FIRST)을 무조건 띄우고,
## 나머지 항목은 판에서 처음 생길 때(main._tut_event) 한 번 띄운다. 시작 화면 [튜토리얼]·일시정지에서 항목별로 다시 본다.
## 본 기록은 이 기기 파일(user://device.cfg)에만 남긴다: 계정 진행(Progress)·best.cfg에 넣지 않아 새 기기에선 다시 뜬다.

const PATH := "user://device.cfg"
const FIRST := ["goal", "place", "cards", "stack"]
## 처음 생기는 일(main._tut_event id, 대개 _guide id와 같음) → 항목
const ON_EVENT := {
	"stack": "stack", "react": "stack", "pat": "pat", "mod": "mod", "trig": "trig", "link": "link",
	"boss": "boss", "resist": "orbs", "sturdy": "orbs", "over": "score", "ach": "codex", "continue": "save", "mp": "mp",
}
## 항목: id, name, pages [{pic, pc, touch(없으면 pc)}]. 글은 PC·터치를 따로 (터치엔 키·클릭 말이 없게, spec TUT-02)
const TOPICS := [
	{"id": "goal", "name": "목표와 화면", "pages": [
		{"pic": "goal", "pc": "구체가 화면 끝에서 가운데 중앙으로 몰려와요. 중앙 체력은 10이고 구체가 닿을 때마다 줄어요. 0이 되면 판이 끝나요."},
		{"pic": "lanes", "pc": "가장자리의 빨간 화살표가 구체가 들어오는 길목이에요. 옆 숫자는 그쪽에서 올 구체 수예요. 길목은 3웨이브마다 하나씩 늘어요."},
		{"pic": "loop", "pc": "웨이브를 막으면 쉬는 시간이에요. 쉬는 시간에 카드를 골라 오브젝트를 놓거나 강하게 만들고 다음 웨이브를 시작해요."},
	]},
	{"id": "place", "name": "오브젝트 놓기·방향", "pages": [
		{"pic": "place", "pc": "속성 카드를 고르고 빈 곳을 클릭해 오브젝트를 놓아요. 이어서 쏠 쪽을 클릭하면(끌어서 놓아도 돼요) 방향이 정해져요. Shift를 누르면 15도씩 맞춰요.",
			"touch": "속성 카드를 누르고 [적용](또는 한 번 더 누르기), 빈 곳을 눌러 오브젝트를 놓아요. 이어서 쏠 쪽을 누르거나 끌어서 놓으면 방향이 정해져요."},
		{"pic": "turn", "pc": "쉬는 시간에 오브젝트를 클릭하면 그 자리에서 방향을 바꿔요. 우클릭한 채 끌면 한 번에 조준해요.",
			"touch": "쉬는 시간에 오브젝트를 누르면 그 자리에서 쏠 방향을 바꿔요. 쏠 쪽을 누르거나 끌어서 놓으면 돼요."},
		{"pic": "move", "pc": "오브젝트를 끌면 방향은 그대로 두고 옮겨요. 빈 곳을 끌어 여러 개를 고르면 함께 옮겨요. 우클릭·Esc는 한 단계 되돌리기, 휠은 전장 확대예요.",
			"touch": "오브젝트를 누른 채 끌면 방향은 그대로 두고 옮겨요. [취소]는 한 단계 되돌리기, 두 손가락으로 벌리면 전장이 커져요."},
	]},
	{"id": "cards", "name": "카드 선택", "pages": [
		{"pic": "cards", "pc": "쉬는 시간마다 카드 3장 중에서 골라요(1·2·3 키도 돼요). 카드를 고른 채 오브젝트 위에 올리면 바뀌는 점과 범위가 미리 보여요.",
			"touch": "쉬는 시간마다 카드 3장 중에서 골라요. 카드를 한 번 누르면 미리보기, 한 번 더 누르거나 [적용]으로 골라요."},
		{"pic": "cards_btn", "pc": "Q: 새로고침(쉬는 시간마다 1번, 보스 처치·특성으로 늘어요). V: 카드를 내리고 필드 보기. Alt를 누르고 있으면 모든 오브젝트의 범위가 보여요.",
			"touch": "[새로고침]: 선택지 바꾸기(쉬는 시간마다 1번, 보스 처치·특성으로 늘어요). [필드 보기]: 카드를 내리고 필드 보기. [범위 보기]: 모든 오브젝트의 범위."},
		{"pic": "skip", "pc": "S: 웨이브 넘기기. 카드 선택을 미루고 웨이브 1·3·5·10개를 연달아 진행한 뒤, 쌓인 카드·특성·새로고침을 한꺼번에 써요.",
			"touch": "[웨이브 n개 넘기기]: 카드 선택을 미루고 웨이브 1·3·5·10개를 연달아 진행한 뒤, 쌓인 카드·특성·새로고침을 한꺼번에 써요."},
	]},
	{"id": "stack", "name": "속성 겹치기·특수 반응", "pages": [
		{"pic": "stack", "pc": "속성 카드를 오브젝트 위에 놓으면 겹쳐져요. 같은 속성은 레벨이 오르고, 다른 속성은 그 속성의 추가 효과가 붙어요. 랭크 규칙은 오브젝트당 3종까지예요."},
		{"pic": "react", "pc": "맞는 두 속성이 한 오브젝트에 모이면 특수 반응이 생겨요. 처음 만든 반응은 도감에 기록돼요."},
		{"pic": "crowd", "pc": "종류가 늘수록 피해는 세지고 공격 속도는 조금 느려져요. 오브젝트가 많을수록 모두의 피해가 늘어서(5개 +16%) 여러 곳에 고루 놓는 게 좋아요."},
	]},
	{"id": "pat", "name": "공격방식", "pages": [
		{"pic": "pat", "pc": "공격방식 카드를 직선탄 오브젝트에 넣으면 공격 모양이 바뀌어요. 분사·연쇄 번개·돌풍 등 여러 가지가 있어요."},
		{"pic": "pat_lv", "pc": "한 번 정하면 그 오브젝트의 공격방식은 고정이에요. 같은 공격방식을 또 넣으면 레벨이 올라요. 그린 궤적은 직접 길을 그려서 넣어요."},
	]},
	{"id": "mod", "name": "강화", "pages": [
		{"pic": "mod", "pc": "강화 카드는 오브젝트 위에 놓아 공격을 바꿔요. 다중·분열·유도·튕김·크기·속사·관통·주사위가 있어요."},
		{"pic": "mod_cap", "pc": "랭크는 같은 강화를 5개까지 넣어요(도파민 모드는 제한 없이 쌓이지만 효과가 점점 줄어요). 공격방식에 효과가 없는 강화(예: 벽에 유도)는 막혀요."},
	]},
	{"id": "trig", "name": "발동", "pages": [
		{"pic": "trig", "pc": "발동 카드는 조건이 맞을 때 공격을 더해요. 여진: 구체를 잡으면 그 자리에서 작은 탄이 사방으로. 선봉: 웨이브에서 처음 맞힌 순간부터 5초 동안 공격 속도 2배."},
	]},
	{"id": "link", "name": "연계", "pages": [
		{"pic": "link", "pc": "연계 카드는 주변 오브젝트와 함께 싸워요. 공명: 가까운 오브젝트 하나당 피해 +12%. 프리즘: 지나가는 탄에 속성·피해 +20%. 협공: 다른 오브젝트가 맞힌 구체를 3초 안에 맞히면 폭발."},
	]},
	{"id": "boss", "name": "보스·특성·운명의 동전", "pages": [
		{"pic": "boss", "pc": "5웨이브마다 마지막에 보스가 와요. 분홍 선이 실제로 지나갈 길이고, 중앙에 닿으면 3 피해예요. 잡으면 중앙 체력 +2, 새로고침 +1."},
		{"pic": "perk", "pc": "보스 웨이브를 넘기면 특성 3개 중 하나를 골라요. 특성은 모든 오브젝트에 붙는 강화예요."},
		{"pic": "coin", "pc": "운명의 동전: 던지면 특성 3개를 새로 받아요. 앞면이면 고른 특성이 두 번 적용되고, 뒷면이면 한 번 적용에 이번 쉬는 시간 새로고침이 2번 늘어요."},
	]},
	{"id": "orbs", "name": "특수 구체", "pages": [
		{"pic": "orb_kinds", "pc": "빠른 구체(4웨이브), 단단한 구체(7), 보호막 구체(8, 피해를 먼저 흡수), 분열 구체(12, 잡으면 쪼개짐)가 차례로 나와요."},
		{"pic": "orb_resist", "pc": "저항 구체(점선 고리)는 그 웨이브 저항 속성 피해를 덜 받고, 굳센 구체(회색 쐐기)는 밀기·감속·기절이 절반만 들어요. 다음 웨이브 예고에서 미리 보여요."},
	]},
	{"id": "score", "name": "점수·콤보·규칙·모드", "pages": [
		{"pic": "combo", "pc": "구체를 잡으면 점수가 올라요. 3초 안에 다음 구체를 잡으면 콤보가 이어져 처치 점수가 10%씩 늘고, 콤보 20부터는 3배예요."},
		{"pic": "rules", "pc": "첫 판을 끝내면 시작 화면에서 규칙을 고를 수 있어요. 랭크는 기본 규칙, 도파민 모드는 속성 종류 제한이 없고 강화가 크게 쌓여요."},
		{"pic": "modes", "pc": "모드로 어렵게 하면 점수 배율이 오르고, 쉽게 하면 내려가요. 쉽게 모드를 쓴 판은 기록이 따로 남아요."},
	]},
	{"id": "codex", "name": "도감·업적", "pages": [
		{"pic": "codex", "pc": "도감(시작 화면)에 고른 카드·만난 반응·특성이 모여요. ☆로 선호 표시하면 판 중에 그 카드가 나올 때 반짝여요."},
		{"pic": "ach", "pc": "업적은 5등급으로 나뉘어요. 달성하면 오브젝트·중앙 모양과 칭호가 열려요. [기록·업적]이나 도감의 업적 탭에서 봐요."},
	]},
	{"id": "mp", "name": "멀티플레이", "pages": [
		{"pic": "vs", "pc": "시작 화면 [멀티플레이]에서 방을 만들면 6자리 코드가 나와요. 코드로 최대 4명이 들어와요. 대결은 모두 같은 웨이브를 받고, 중앙이 안 맞은 채 웨이브를 막으면 상대에게 구체를 보내요."},
		{"pic": "coop", "pc": "협동은 한 전장을 함께 지켜요. 인원만큼 구체가 늘고, 오브젝트는 놓은 사람만 바꿀 수 있어요(고리 색으로 구분). 멀티 판은 이어하기·리더보드가 없어요."},
	]},
	{"id": "save", "name": "저장·이어하기", "pages": [
		{"pic": "save", "pc": "쉬는 시간마다 자동으로 저장돼요. 게임을 꺼도 시작 화면 [이어하기]로 그 쉬는 시간부터 이어서 해요. 웨이브 중에 끄면 그 웨이브 앞부터예요."},
		{"pic": "sync", "pc": "같은 계정이면 다른 기기에서 하던 판과 도감·업적을 가져와요. 게임 버전이 바뀌면 지난 판은 이어 하지 않고 그 점수로 끝나요."},
	]},
]

static var done := false  # 이 기기에서 처음 튜토리얼을 띄웠나
static var seen := {}  # 이 기기에서 본 항목 id -> true
static var loaded := false

signal closed

var touch := false
var phone := false
var on_help: Callable  # [조작·규칙 전체 보기] (도움말 글)
var mode := ""  # "list" | "pages"
var queue: Array = []  # 이어서 볼 항목 id
var qi := 0
var page := 0
var first_run := false
var from_list := false
var t := 0.0
var swipe_x := -1.0

var panel: PanelContainer
var head: Label
var count: Label
var pic: Control
var body: Label
var pages_box: VBoxContainer
var list_box: VBoxContainer
var grid: GridContainer
var btn_prev: Button
var btn_next: Button
var btn_close: Button
var btn_list: Button


static func load_file() -> void:
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		done = false
		seen = {}
		return
	done = cfg.get_value("tutorial", "done", false)
	var s = cfg.get_value("tutorial", "seen", {})
	seen = s if s is Dictionary else {}


static func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 나중에 이 파일에 다른 기기 전용 값이 생겨도 지우지 않게
	cfg.set_value("tutorial", "done", done)
	cfg.set_value("tutorial", "seen", seen)
	cfg.save(PATH)


## 이 기기에서 아직 튜토리얼을 띄운 적이 없다.
static func need_first() -> bool:
	if not loaded:
		load_file()
	return not done


static func topic(id: String) -> Dictionary:
	for tp in TOPICS:
		if tp["id"] == id:
			return tp
	return {}


static func page_text(pg: Dictionary, for_touch: bool) -> String:
	return pg.get("touch", pg["pc"]) if for_touch else pg["pc"]


func setup(sb: StyleBox, help: Callable) -> void:
	on_help = help
	process_mode = Node.PROCESS_MODE_ALWAYS  # 판 중에 띄우면 판은 멈춰 있다
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 카드·필드를 누르지 않게
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.gui_input.connect(_on_panel_input)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var hb := HBoxContainer.new()
	v.add_child(hb)
	head = Label.new()
	head.add_theme_font_size_override("font_size", 22)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.clip_text = true
	hb.add_child(head)
	count = Label.new()
	count.add_theme_font_size_override("font_size", 15)
	count.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hb.add_child(count)

	pages_box = VBoxContainer.new()
	pages_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages_box.add_theme_constant_override("separation", 10)
	v.add_child(pages_box)
	pic = Control.new()
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.custom_minimum_size = Vector2(0, 110)
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(_draw_pic)
	pages_box.add_child(pic)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.custom_minimum_size = Vector2(0, 80)
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pages_box.add_child(body)

	list_box = VBoxContainer.new()
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(list_box)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(sc)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	btn_prev = _btn(row, "◀ 이전", _prev)
	btn_next = _btn(row, "다음 ▶", _next)
	btn_list = _btn(row, "목록", open_list)
	btn_close = _btn(row, "닫기", close)


func _btn(row: Container, text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 44)
	b.pressed.connect(f)
	row.add_child(b)
	return b


## 다시 보기 목록 (시작 화면 [튜토리얼]·일시정지).
func open_list() -> void:
	mode = "list"
	first_run = false
	visible = true
	for c in grid.get_children():
		c.free()  # 바로 지운다 (목록 버튼이 아닌 곳에서만 불림)
	grid.columns = 3 if size.x >= 760.0 else 2
	for i in TOPICS.size():
		var tp: Dictionary = TOPICS[i]
		var id: String = tp["id"]
		var b := Button.new()
		b.text = "%d. %s%s" % [i + 1, tp["name"], "  ✓" if seen.has(id) else ""]
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 52 if phone else 44)
		b.pressed.connect(func():
			from_list = true
			_show_topics([id]))
		grid.add_child(b)
	var hb := Button.new()
	hb.text = "조작·규칙 전체 보기"
	hb.focus_mode = Control.FOCUS_NONE
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.custom_minimum_size = Vector2(0, 52 if phone else 44)
	hb.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	hb.pressed.connect(func():
		close()
		if on_help.is_valid():
			on_help.call())
	grid.add_child(hb)
	_refresh()


## 항목들을 이어서 본다. first: 기기에서 처음 켰을 때 (닫으면 done, [건너뛰기]).
func open_topics(ids: Array, first := false) -> void:
	first_run = first
	from_list = false
	_show_topics(ids)


func _show_topics(ids: Array) -> void:
	mode = "pages"
	visible = true
	queue = ids.filter(func(id): return not topic(id).is_empty())
	qi = 0
	page = 0
	t = 0.0
	if queue.is_empty():
		close()
		return
	_mark(queue[0])
	_refresh()


func _mark(id: String) -> void:
	if not seen.has(id):
		seen[id] = true
		save_file()


func cur_topic() -> Dictionary:
	return topic(queue[qi]) if mode == "pages" and qi < queue.size() else {}


func _next() -> void:
	var tp := cur_topic()
	if tp.is_empty():
		return
	t = 0.0
	if page + 1 < tp["pages"].size():
		page += 1
	elif qi + 1 < queue.size():
		qi += 1
		page = 0
		_mark(queue[qi])
	elif from_list:
		open_list()
		return
	else:
		close()
		return
	_refresh()


func _prev() -> void:
	t = 0.0
	if page > 0:
		page -= 1
	elif qi > 0:
		qi -= 1
		page = topic(queue[qi])["pages"].size() - 1
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	if first_run:
		done = true
		for id in FIRST:  # 건너뛰어도 본 것으로 (판에서 다시 띄우지 않게)
			seen[id] = true
		save_file()
	first_run = false
	mode = ""
	closed.emit()


## 마지막 장인가 (다음 버튼 글: 닫기·시작하기·목록으로).
func _last() -> bool:
	var tp := cur_topic()
	return not tp.is_empty() and page + 1 >= tp["pages"].size() and qi + 1 >= queue.size()


func _refresh() -> void:
	var lst := mode == "list"
	pages_box.visible = not lst
	list_box.visible = lst
	btn_prev.visible = not lst
	btn_next.visible = not lst
	btn_list.visible = not lst and not first_run and not (from_list and _last())
	btn_close.visible = lst or not _last()  # 마지막 장은 [다음] 자리가 닫기·시작하기
	var h := 60.0 if phone else 44.0
	for b: Button in [btn_prev, btn_next, btn_list, btn_close]:
		b.custom_minimum_size = Vector2(150 if not phone else 170, h)
	if lst:
		head.text = "튜토리얼"
		count.text = "항목을 골라 다시 보기"
		btn_close.text = "닫기"
		return
	var tp := cur_topic()
	var pg: Dictionary = tp["pages"][page]
	head.text = "튜토리얼 · " + str(tp["name"])
	var n: int = tp["pages"].size()
	count.text = ("%d / %d" % [page + 1, n]) + (("   항목 %d / %d" % [qi + 1, queue.size()]) if queue.size() > 1 else "")
	# 한 줄로 화면 끝까지 늘어져 읽기 힘들던 것: 문장마다 줄을 바꾸고(공명·프리즘·협공처럼 항목이 여럿이면 한 줄씩), 글 폭은 _process에서 줄인다
	body.text = PatchNotes.kr_keep(page_text(pg, touch).replace(". ", ".\n"))
	btn_prev.disabled = page == 0 and qi == 0
	btn_next.text = ("목록으로" if from_list else "시작하기" if first_run else "닫기") if _last() else "다음 ▶"
	btn_close.text = "건너뛰기" if first_run else "닫기"
	if not touch:
		btn_next.text += "" if _last() else " (→)"
	pic.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	# 창 크기: PC는 900x560 안, 폰은 화면을 거의 채운다 (글자 크기를 키우면 부모(ui_root)가 작아져 함께 줄어든다)
	var avail := size
	var w := avail.x - 32.0 if phone else minf(900.0, avail.x - 48.0)
	var hh := avail.y - 24.0 if phone else minf(560.0, avail.y - 48.0)
	panel.size = Vector2(w, hh)
	panel.position = ((avail - panel.size) / 2.0).floor()
	body.add_theme_font_size_override("font_size", 20 if phone else 18)
	body.custom_minimum_size.x = minf(w - 48.0, 760.0)  # 읽기 좋은 폭 (넓은 폰 화면에서 한 줄이 1500px까지 늘어났다)
	if mode == "pages":
		pic.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()  # 열려 있는 동안 다른 단축키는 막는다
		if not event.pressed or event.echo:
			return
		match event.keycode:
			KEY_ESCAPE:
				if mode == "pages" and from_list:
					open_list()
				else:
					close()
			KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if mode == "pages":
					_next()
			KEY_LEFT:
				if mode == "pages":
					_prev()
			KEY_H:
				if mode == "list":
					close()


## 폰: 창을 좌우로 밀어 넘기기.
func _on_panel_input(event: InputEvent) -> void:
	if mode != "pages" or not event is InputEventScreenTouch:
		return
	if event.pressed:
		swipe_x = event.position.x
	elif swipe_x >= 0.0:
		var dx: float = event.position.x - swipe_x
		swipe_x = -1.0
		if dx < -80.0:
			_next()
		elif dx > 80.0 and not btn_prev.disabled:
			_prev()


# ---------- 그림 ----------
# 그림은 실제 게임 모양을 흉내 낸 작은 장면 (560x240 기준 좌표를 창 크기에 맞춰 늘림). t로 움직인다.

var _o := Vector2.ZERO
var _s := 1.0
const CORE_COL := Color(0.95, 0.88, 0.55)
const ORB_COL := Color(0.92, 0.42, 0.52)
const LANE_COL := Color(1, 0.3, 0.3)
const DIM := Color(1, 1, 1, 0.35)


func P(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _ec(e: int) -> Color:
	return Elem.COLORS[e]


func _draw_pic() -> void:
	var r := Rect2(Vector2.ZERO, pic.size)
	pic.draw_rect(r, Color(0.05, 0.06, 0.1, 0.9))
	_s = minf(r.size.x / 560.0, r.size.y / 240.0)
	_o = (r.size - Vector2(560, 240) * _s) / 2.0
	var tp := cur_topic()
	if tp.is_empty():
		return
	var id: String = tp["pages"][page]["pic"]
	var f := Callable(self, "_pic_" + id)
	if f.is_valid():
		f.call()


func _font() -> Font:
	return get_theme_default_font()


func _txt(p: Vector2, s: String, fs := 16, col := Color(1, 1, 1, 0.85)) -> void:
	var f := _font()
	var sz := int(fs * _s)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	pic.draw_string(f, p - Vector2(w / 2.0, -sz * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _core(p: Vector2, hp := "10") -> void:
	pic.draw_circle(p, 16 * _s, CORE_COL)
	pic.draw_arc(p, 22 * _s, 0, TAU, 32, Color(CORE_COL, 0.5), 2 * _s)
	if hp != "":
		_txt(p + Vector2(0, 36 * _s), "중앙 " + hp, 13, CORE_COL)


func _orb(p: Vector2, rad := 8.0, col := ORB_COL) -> void:
	pic.draw_circle(p, rad * _s, col)
	pic.draw_arc(p, rad * _s, 0, TAU, 20, col.lightened(0.4), 1.5 * _s)


func _tower(p: Vector2, cols: Array, dir := Vector2.RIGHT, ring := Color.TRANSPARENT) -> void:
	var c: Color = cols[0]
	pic.draw_line(p, p + dir.normalized() * 24 * _s, c.lightened(0.3), 4 * _s)
	pic.draw_circle(p, 13 * _s, c.darkened(0.45))
	for i in cols.size():
		pic.draw_arc(p, (13 - i * 4) * _s, 0, TAU, 24, cols[i], 3 * _s)
	if ring.a > 0.0:
		pic.draw_arc(p, 19 * _s, 0, TAU, 28, ring, 2.5 * _s)


func _arrow(a: Vector2, b: Vector2, col := Color(1, 1, 1, 0.7), w := 3.0) -> void:
	pic.draw_line(a, b, col, w * _s)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	pic.draw_colored_polygon(PackedVector2Array([b + d * 6 * _s, b - d * 8 * _s + n * 7 * _s, b - d * 8 * _s - n * 7 * _s]), col)


func _dash(a: Vector2, b: Vector2, col := DIM, w := 2.0) -> void:
	pic.draw_dashed_line(a, b, col, w * _s, 8 * _s)


func _lane(p: Vector2, dir: Vector2, n: String) -> void:
	_arrow(p - dir * 18 * _s, p + dir * 14 * _s, LANE_COL, 5)
	_txt(p - dir * 18 * _s + Vector2(dir.y, -dir.x).abs() * 22 * _s, n, 15, LANE_COL)


func _card(c: Vector2, title: String, sub: String, col: Color, hi := false) -> void:
	var r := Rect2(c - Vector2(62, 72) * _s, Vector2(124, 144) * _s)
	pic.draw_rect(r, Color(0.12, 0.13, 0.2))
	pic.draw_rect(r, col if not hi else Color(1, 0.9, 0.5), false, (4.0 if hi else 2.0) * _s)
	_txt(c + Vector2(0, -38) * _s, title, 15, col)
	_txt(c + Vector2(0, 20) * _s, sub, 13)


func _button(c: Vector2, label: String, w := 120.0, hi := false) -> void:
	var r := Rect2(c - Vector2(w / 2.0, 16) * _s, Vector2(w, 32) * _s)
	pic.draw_rect(r, Color(0.2, 0.22, 0.32) if not hi else Color(0.3, 0.32, 0.5))
	pic.draw_rect(r, Color(1, 1, 1, 0.4), false, 1.5 * _s)
	_txt(c, label, 13)


## 커서(PC) 또는 손가락(터치).
func _pointer(p: Vector2, press := false) -> void:
	if touch:
		pic.draw_circle(p, (14 if press else 11) * _s, Color(1, 1, 1, 0.35 if press else 0.22))
		pic.draw_arc(p, 11 * _s, 0, TAU, 20, Color(1, 1, 1, 0.8), 2 * _s)
		return
	var pts := PackedVector2Array([p, p + Vector2(0, 20) * _s, p + Vector2(5, 15) * _s, p + Vector2(12, 14) * _s])
	pic.draw_colored_polygon(pts, Color.WHITE)
	pic.draw_polyline(pts + PackedVector2Array([p]), Color.BLACK, 1.5 * _s)
	if press:
		pic.draw_arc(p, 10 * _s, 0, TAU, 20, Color(1, 1, 1, 0.6), 2 * _s)


## 0~1을 n초마다 되풀이.
func _ph(n: float) -> float:
	return fmod(t, n) / n


func _shots(from: Vector2, dir: Vector2, col: Color, n := 3, length := 220.0) -> void:
	for i in n:
		var k := fmod(t * 1.4 + float(i) / n, 1.0)
		pic.draw_circle(from + dir.normalized() * (20 + k * length) * _s, 4 * _s, col)


func _pic_goal() -> void:
	var c := P(280, 110)
	_core(c)
	for i in 6:
		var a := i * TAU / 6 + 0.3
		var k := fmod(t * 0.22 + i * 0.37, 1.0)
		var from := c + Vector2(cos(a) * 250, sin(a) * 105) * _s
		_orb(from.lerp(c, k * 0.85))
	_txt(P(80, 30), "구체 →", 14, ORB_COL)


func _pic_lanes() -> void:
	pic.draw_rect(Rect2(P(40, 10), Vector2(480, 220) * _s), DIM, false, 1.5 * _s)
	var c := P(280, 120)
	_core(c, "")
	_lane(P(52, 120), Vector2.RIGHT, "6")
	_lane(P(280, 22), Vector2.DOWN, "4")
	for i in 3:
		_orb(P(60, 120).lerp(c, fmod(t * 0.25 + i * 0.33, 1.0)))
		_orb(P(280, 30).lerp(c, fmod(t * 0.25 + i * 0.33 + 0.15, 1.0)))
	_txt(P(470, 205), "길목", 14, LANE_COL)


func _pic_loop() -> void:
	var names := ["웨이브", "쉬는 시간", "카드 선택"]
	var cur := int(t / 1.2) % 3
	for i in 3:
		var c := P(100 + i * 180, 120)
		var r := Rect2(c - Vector2(70, 30) * _s, Vector2(140, 60) * _s)
		pic.draw_rect(r, Color(0.18, 0.2, 0.3) if i != cur else Color(0.35, 0.3, 0.15))
		pic.draw_rect(r, Color(1, 0.9, 0.5) if i == cur else DIM, false, 2 * _s)
		_txt(c, names[i], 16)
		if i < 2:
			_arrow(c + Vector2(74, 0) * _s, c + Vector2(104, 0) * _s)
	_dash(P(460, 160), P(460, 200))
	_dash(P(460, 200), P(100, 200))
	_arrow(P(100, 200), P(100, 158), DIM, 2)


func _pic_place() -> void:
	var k := _ph(5.0)
	var card := P(80, 120)
	_card(card, "불", "Lv1 · 직선탄", _ec(Elem.FIRE), k < 0.25)
	var spot := P(300, 140)
	var aim := P(480, 70)
	if k < 0.25:
		_pointer(card.lerp(spot, k / 0.25), k > 0.2)
		pic.draw_arc(spot, 20 * _s, 0, TAU, 24, Color(1, 1, 1, 0.3), 2 * _s)
	else:
		var d := Vector2.RIGHT.lerp((aim - spot).normalized(), clampf((k - 0.25) / 0.25, 0, 1))
		_tower(spot, [_ec(Elem.FIRE)], d)
		if k < 0.5:
			_dash(spot, spot + d * 160 * _s, Color(1, 1, 1, 0.5))
			_pointer(spot.lerp(aim, (k - 0.25) / 0.25), true)
		else:
			_shots(spot, aim - spot, _ec(Elem.FIRE), 3, 200)


func _pic_turn() -> void:
	var p := P(280, 130)
	var a := -0.6 + sin(t * 1.2) * 1.1
	var d := Vector2.from_angle(a)
	pic.draw_arc(p, 46 * _s, -1.7, 0.5, 24, Color(1, 1, 1, 0.4), 3 * _s)
	_tower(p, [_ec(Elem.WATER)], d)
	_shots(p, d, _ec(Elem.WATER), 3, 200)
	_pointer(p + d * 90 * _s, true)
	_txt(P(280, 222), "누르기: 쏠 방향" if touch else "클릭: 그 자리에서 방향 · 우클릭 끌기: 조준", 14)


func _pic_move() -> void:
	var k := clampf(_ph(3.0) * 1.3, 0, 1)
	var a := P(150, 120)
	var b := P(410, 120)
	var d := Vector2(0.4, -1)
	_tower(a, [Color(1, 1, 1, 0.2)], d)
	_dash(a, b)
	var p := a.lerp(b, k)
	_tower(p, [_ec(Elem.WIND)], d)
	_pointer(p + Vector2(6, 6) * _s, true)
	_txt(P(280, 210), "끌기: 옮기기 (방향은 그대로)" if not touch else "누른 채 끌기: 옮기기 (방향은 그대로)", 14)


func _pic_cards() -> void:
	var hi := int(t / 1.5) % 3
	_card(P(130, 115), "불", "Lv2", _ec(Elem.FIRE), hi == 0)
	_card(P(280, 115), "공격방식", Pat.pname("spray"), Pat.pcolor("spray"), hi == 1)
	_card(P(430, 115), "강화", Pat.MODS[Pat.MOD_IDS[0]]["name"], Color(1, 0.82, 0.4), hi == 2)
	_pointer(P(150 + hi * 150, 150), true)


func _pic_cards_btn() -> void:
	_card(P(130, 90), "물", "Lv1", _ec(Elem.WATER))
	_card(P(280, 90), "번개", "Lv1", _ec(Elem.ELECTRIC))
	_card(P(430, 90), "연계", Pat.LINKS["reso"]["name"], Color(0.55, 0.9, 1.0))
	var hi := int(t / 1.5) % 2
	_button(P(205, 205), "새로고침" + ("" if touch else " (Q)"), 130, hi == 0)
	_button(P(355, 205), "필드 보기" + ("" if touch else " (V)"), 130, hi == 1)


func _pic_skip() -> void:
	var labels := ["1", "3", "5", "10"]
	for i in 4:
		_button(P(130 + i * 100, 60), "웨이브 %s개" % labels[i], 90, i == int(t / 1.2) % 4)
	for i in 3:
		var r := Rect2(P(200 + i * 14, 120 + i * 8), Vector2(110, 70) * _s)
		pic.draw_rect(r, Color(0.12, 0.13, 0.2))
		pic.draw_rect(r, Color(1, 0.82, 0.4), false, 2 * _s)
	_txt(P(400, 160), "쌓인 선택 +3", 16, Color(1, 0.85, 0.4))


func _pic_stack() -> void:
	var p := P(300, 130)
	var k := _ph(3.0)
	var cols := [_ec(Elem.FIRE)] if k < 0.5 else [_ec(Elem.FIRE), _ec(Elem.WATER)]
	_tower(p, cols)
	if k < 0.5:
		_card(P(110, 120).lerp(p, k * 2.0), "물", "Lv1", _ec(Elem.WATER))
	else:
		_txt(p + Vector2(0, 46) * _s, "불 + 물", 16)


func _pic_react() -> void:
	var r: Dictionary = Elem.REACTIONS[1]
	var k := _ph(2.5)
	var a := P(180, 110).lerp(P(280, 110), minf(k * 2, 1))
	var b := P(380, 110).lerp(P(280, 110), minf(k * 2, 1))
	if k < 0.5:
		pic.draw_circle(a, 22 * _s, _ec(r["a"]))
		pic.draw_circle(b, 22 * _s, _ec(r["b"]))
	else:
		var rad := (20 + (k - 0.5) * 120) * _s
		pic.draw_circle(P(280, 110), rad, Color(r.get("color", Color.WHITE), 1.2 - k))
		pic.draw_arc(P(280, 110), rad, 0, TAU, 40, r.get("color", Color.WHITE), 3 * _s)
	_txt(P(280, 200), "%s + %s → %s" % [Elem.NAMES[r["a"]], Elem.NAMES[r["b"]], r["name"]], 17, Color(1, 0.9, 0.6))


func _pic_crowd() -> void:
	var es := [Elem.FIRE, Elem.WATER, Elem.WOOD, Elem.ELECTRIC, Elem.ICE]
	for i in 5:
		var p := P(280, 110) + Vector2.from_angle(i * TAU / 5 - 1.2) * 80 * _s
		_tower(p, [_ec(es[i])], (p - P(280, 110)))
	_core(P(280, 110), "")
	_txt(P(280, 222), "오브젝트 5개: 모두 피해 +16%", 16, Color(1, 0.9, 0.6))


func _pic_pat() -> void:
	var p := P(140, 120)
	var col := Pat.pcolor("spray")
	_tower(p, [_ec(Elem.FIRE)], Vector2.RIGHT, col)
	for j in 5:
		var d := Vector2.from_angle((j - 2) * 0.22)
		for i in 3:
			var k := fmod(t * 1.2 + i / 3.0, 1.0)
			pic.draw_circle(p + d * (24 + k * 260) * _s, (3 + k * 4) * _s, Color(col, 1.0 - k * 0.7))
	_txt(P(420, 215), Pat.pname("spray"), 16, col)


func _pic_pat_lv() -> void:
	_tower(P(110, 120), [_ec(Elem.ELECTRIC)], Vector2.RIGHT, Pat.pcolor("chain"))
	_txt(P(110, 170), "%s Lv1 → Lv2" % Pat.pname("chain"), 15, Pat.pcolor("chain"))
	var pts := PackedVector2Array([P(300, 190), P(340, 60), P(420, 150), P(500, 50)])
	var k := _ph(3.0)
	pic.draw_polyline(pts, Color(0.6, 1, 0.7, 0.8), 4 * _s)
	_pointer(pts[2].lerp(pts[3], k), true)
	_txt(P(400, 215), "그린 궤적", 15, Color(0.6, 1, 0.7))


func _pic_mod() -> void:
	var p := P(120, 120)
	_tower(p, [_ec(Elem.ICE)], Vector2.RIGHT, Color(1, 0.82, 0.4))
	for j in 3:
		for i in 3:
			var k := fmod(t * 1.3 + i / 3.0, 1.0)
			pic.draw_circle(p + Vector2(26 + k * 330, (j - 1) * 26 * (0.4 + k)) * _s, 6 * _s, _ec(Elem.ICE))
	_txt(P(400, 215), "다중 + 크기", 16, Color(1, 0.82, 0.4))


func _pic_mod_cap() -> void:
	_tower(P(140, 110), [_ec(Elem.EARTH)], Vector2.RIGHT, Color(1, 0.82, 0.4))
	for i in 5:
		pic.draw_circle(P(100 + i * 20, 160), 6 * _s, Color(1, 0.82, 0.4))
	_txt(P(140, 190), "같은 강화 5/5", 14)
	var c := P(400, 110)
	_card(c, "강화", "유도", Color(1, 0.82, 0.4, 0.5))
	pic.draw_line(c + Vector2(-40, -40) * _s, c + Vector2(40, 40) * _s, LANE_COL, 5 * _s)
	pic.draw_line(c + Vector2(40, -40) * _s, c + Vector2(-40, 40) * _s, LANE_COL, 5 * _s)
	_txt(P(400, 215), "벽에는 못 넣음", 14, LANE_COL)


func _pic_trig() -> void:
	var p := P(110, 120)
	var o := P(330, 120)
	var k := _ph(2.0)
	_tower(p, [_ec(Elem.LIGHT)], Vector2.RIGHT, Pat.TRIG_COLOR)
	if k < 0.45:
		_orb(o, 10)
		pic.draw_circle(p.lerp(o, k / 0.45), 5 * _s, _ec(Elem.LIGHT))
	else:
		var kk := (k - 0.45) / 0.55
		for i in 4:
			pic.draw_circle(o + Vector2.from_angle(i * TAU / 4 + 0.4) * kk * 110 * _s, 4 * _s, Pat.TRIG_COLOR)
		pic.draw_arc(o, (10 + kk * 30) * _s, 0, TAU, 24, Color(Pat.TRIG_COLOR, 1 - kk), 2 * _s)
	_txt(P(330, 215), "여진: 잡은 자리에서 사방으로", 15, Pat.TRIG_COLOR)


func _pic_link() -> void:
	var a := P(180, 110)
	var b := P(380, 110)
	var col := Color(0.55, 0.9, 1.0)
	pic.draw_line(a, b, Color(col, 0.4 + 0.3 * sin(t * 4)), 6 * _s)
	_tower(a, [_ec(Elem.SOUND)], Vector2.UP, col)
	_tower(b, [_ec(Elem.DARK)], Vector2.UP, col)
	_txt(P(280, 80), "공명 +12%", 16, col)
	_txt(P(280, 200), "가까운 오브젝트와 함께", 14)


func _pic_boss() -> void:
	var c := P(470, 120)
	_core(c)
	var pts := PackedVector2Array()
	for i in 21:
		var x := float(i) / 20.0
		pts.append(P(40 + x * 400, 120 + sin(x * 6.0) * 60 * (1 - x)))
	for i in 20:
		if i % 2 == 0:
			pic.draw_line(pts[i], pts[i + 1], Color(1, 0.45, 0.8), 3 * _s)
	var k := _ph(5.0)
	var idx := mini(int(k * 20), 19)
	_orb(pts[idx].lerp(pts[idx + 1], k * 20 - idx), 18, Color(0.85, 0.3, 0.7))
	_txt(P(250, 222), "보스: 중앙 3 피해 · 잡으면 체력 +2", 15, Color(1, 0.6, 0.85))


func _pic_perk() -> void:
	var gold := Color(1, 0.86, 0.35)
	var hi := int(t / 1.5) % 3
	_card(P(130, 115), "특성", "화력 +15%", gold, hi == 0)
	_card(P(280, 115), "특성", "속사 +12%", gold, hi == 1)
	_card(P(430, 115), "특성", "운명의 동전", gold, hi == 2)


func _pic_coin() -> void:
	var c := P(280, 105)
	var w := cos(t * 5.0)
	var col := Color(1, 0.85, 0.35) if w > 0 else Color(0.8, 0.65, 0.3)
	var pts := PackedVector2Array()
	for i in 32:
		var a := i * TAU / 32
		pts.append(c + Vector2(cos(a) * 50 * absf(w) + 1, sin(a) * 50) * _s)
	pic.draw_colored_polygon(pts, col)
	pic.draw_polyline(pts + PackedVector2Array([pts[0]]), col.darkened(0.4), 3 * _s)
	_txt(P(150, 205), "앞면: 특성 두 번", 15, Color(1, 0.85, 0.35))
	_txt(P(410, 205), "뒷면: 새로고침 +2", 15, Color(0.85, 0.75, 0.5))


func _pic_orb_kinds() -> void:
	var names := ["빠른", "단단한", "보호막", "분열"]
	for i in 4:
		var p := P(90 + i * 125, 105) + Vector2(sin(t * 2 + i) * 6, 0) * _s
		match i:
			0:
				_orb(p, 7, Color(1, 0.7, 0.4))
				for j in 3:
					pic.draw_line(p + Vector2(10 + j * 6, -4 + j * 4) * _s, p + Vector2(26 + j * 6, -4 + j * 4) * _s, Color(1, 1, 1, 0.4), 2 * _s)
			1:
				_orb(p, 15, Color(0.7, 0.35, 0.4))
			2:
				_orb(p, 10)
				pic.draw_arc(p, 16 * _s, 0, TAU, 28, Color(0.5, 0.8, 1.0), 3 * _s)
			3:
				_orb(p + Vector2(-6, 0) * _s, 8, Color(0.6, 0.9, 0.5))
				_orb(p + Vector2(6, 0) * _s, 8, Color(0.6, 0.9, 0.5))
		_txt(P(90 + i * 125, 170), names[i], 15)
		_txt(P(90 + i * 125, 195), ["4웨이브", "7웨이브", "8웨이브", "12웨이브"][i], 12, DIM)


func _pic_orb_resist() -> void:
	var a := P(170, 105)
	_orb(a, 12)
	pic.draw_arc(a, 20 * _s, t, t + TAU, 28, _ec(Elem.FIRE), 2.5 * _s)
	for i in 8:
		pic.draw_arc(a, 26 * _s, i * TAU / 8 + t, i * TAU / 8 + t + 0.4, 6, _ec(Elem.FIRE), 2.5 * _s)
	_txt(P(170, 170), "저항 구체 (불 피해 덜 받음)", 14)
	var b := P(400, 105)
	_orb(b, 12, Color(0.6, 0.6, 0.65))
	pic.draw_colored_polygon(PackedVector2Array([b + Vector2(-8, -18) * _s, b + Vector2(8, -18) * _s, b + Vector2(0, -6) * _s]), Color(0.75, 0.75, 0.8))
	_txt(P(400, 170), "굳센 구체 (밀기·감속 절반)", 14)


func _pic_combo() -> void:
	var n := 1 + int(t * 3) % 24
	for i in 6:
		var k := fmod(t * 0.8 + i / 6.0, 1.0)
		if k < 0.7:
			_orb(P(80 + i * 70, 170 - k * 40), 8)
		else:
			pic.draw_arc(P(80 + i * 70, 142), (k - 0.7) * 60 * _s, 0, TAU, 16, Color(1, 0.9, 0.5, 1 - k), 2 * _s)
	var mul := "x3" if n >= 20 else "+%d%%" % (n * 10)
	_txt(P(280, 70), "콤보 %d   %s" % [n, mul], 26, Color(1, 0.85, 0.35))


func _pic_rules() -> void:
	for i in 2:
		var c := P(160 + i * 240, 115)
		var r := Rect2(c - Vector2(100, 70) * _s, Vector2(200, 140) * _s)
		pic.draw_rect(r, Color(0.15, 0.17, 0.26))
		pic.draw_rect(r, [Color(0.6, 0.85, 1.0), Color(1, 0.5, 0.8)][i], false, 2 * _s)
		_txt(c + Vector2(0, -36) * _s, ["랭크", "도파민 모드"][i], 18, [Color(0.6, 0.85, 1.0), Color(1, 0.5, 0.8)][i])
		_txt(c + Vector2(0, 6) * _s, ["속성 3종까지", "속성 종류 제한 없음"][i], 13)
		_txt(c + Vector2(0, 32) * _s, ["기본 규칙", "강화가 크게 쌓임"][i], 13)


func _pic_modes() -> void:
	var rows := [["어렵게", 1.4, Color(1, 0.5, 0.4)], ["모드 없음", 1.0, Color(1, 1, 1, 0.7)], ["쉽게", 0.7, Color(0.5, 0.9, 0.6)]]
	for i in 3:
		var y := 60 + i * 55
		_txt(P(110, y), rows[i][0], 16, rows[i][2])
		var w: float = rows[i][1] * 200.0 * (0.9 + 0.1 * sin(t * 2))
		pic.draw_rect(Rect2(P(190, y - 12), Vector2(w, 24) * _s), rows[i][2])
		_txt(P(470, y), "점수 x%.1f" % rows[i][1], 15)


func _pic_codex() -> void:
	for i in 12:
		var p := P(110 + (i % 6) * 68, 70 + int(i / 6) * 80)
		var e: int = Elem.ALL[i % Elem.ALL.size()]
		pic.draw_rect(Rect2(p - Vector2(26, 26) * _s, Vector2(52, 52) * _s), Color(_ec(e), 0.35 if i % 4 == 3 else 0.85))
		if i in [1, 6]:
			var g := 0.6 + 0.4 * sin(t * 5 + i)
			_txt(p + Vector2(18, -22) * _s, "★", 18, Color(1, 0.86, 0.35, g))
	_txt(P(280, 215), "☆ 선호 표시: 선택지에서 반짝임", 15, Color(1, 0.86, 0.35))


func _pic_ach() -> void:
	var tiers: Array = Ach.TIERS.values()
	var n := mini(tiers.size(), 5)
	for i in n:
		var td: Dictionary = tiers[i]
		var p := P(80 + i * 100, 100)
		var on := i <= int(t / 0.8) % (n + 1)
		pic.draw_circle(p, 26 * _s, Color(td["color"], 0.9 if on else 0.2))
		_txt(p + Vector2(0, 46) * _s, str(td["name"]), 14, td["color"])
	_txt(P(280, 210), "모양 해금 · 칭호", 15, Color(1, 0.86, 0.35))


func _pic_vs() -> void:
	for i in 2:
		var r := Rect2(P(30 + i * 270, 20), Vector2(230, 170) * _s)
		pic.draw_rect(r, DIM, false, 1.5 * _s)
		_core(r.get_center(), "")
		_txt(r.position + Vector2(115, 186) * _s, ["나", "상대"][i], 15)
	var k := _ph(2.0)
	_arrow(P(250, 100), P(310, 100), Color(1, 0.6, 0.4), 4)
	_orb(P(260, 80).lerp(P(330, 80), k), 7)
	_txt(P(280, 40), "보낸 구체", 13, Color(1, 0.6, 0.4))


func _pic_coop() -> void:
	pic.draw_rect(Rect2(P(60, 10), Vector2(440, 200) * _s), DIM, false, 1.5 * _s)
	var c := P(280, 110)
	_core(c, "")
	var mine := Color(0.4, 0.8, 1.0)
	var theirs := Color(1, 0.6, 0.3)
	for i in 4:
		var p := c + Vector2.from_angle(i * TAU / 4 + 0.6) * 90 * _s
		_tower(p, [_ec(Elem.ALL[i])], p - c, mine if i % 2 == 0 else theirs)
	for i in 3:
		_orb(P(70, 30 + i * 70).lerp(c, fmod(t * 0.3 + i * 0.3, 1.0)))
	_txt(P(170, 225), "내 오브젝트", 13, mine)
	_txt(P(390, 225), "친구 오브젝트", 13, theirs)


func _pic_save() -> void:
	_button(P(280, 80), "이어하기   웨이브 8부터", 300, int(t / 0.8) % 2 == 0)
	_button(P(280, 140), "새로 시작", 300)
	_txt(P(280, 205), "쉬는 시간마다 자동 저장", 15, Color(0.6, 0.85, 1.0))


func _pic_sync() -> void:
	var pc := Rect2(P(60, 50), Vector2(180, 110) * _s)
	var ph := Rect2(P(390, 40), Vector2(70, 130) * _s)
	for r in [pc, ph]:
		pic.draw_rect(r, Color(0.15, 0.17, 0.26))
		pic.draw_rect(r, Color(1, 1, 1, 0.6), false, 2 * _s)
	var k := _ph(2.0)
	_arrow(P(260, 105), P(370, 105), Color(0.6, 0.85, 1.0), 4)
	pic.draw_circle(P(260, 105).lerp(P(370, 105), k), 6 * _s, Color(1, 0.86, 0.35))
	_txt(P(280, 205), "판·도감·업적", 15, Color(1, 0.86, 0.35))
