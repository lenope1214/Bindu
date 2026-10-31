class_name Codex
extends PanelContainer
## 도감: 카드로 나오는 속성·공격방식·강화·연계와 특수 반응·특성을 모아 본다 (시작 화면, K).
## 한 번이라도 고른 카드는 "수집" (Ach.picks, 계정 진행 저장으로 기기끼리 합침). 마지막 탭은 업적 (Ach.LIST).
## 목록은 Elem·Pat·특성 정의에서 바로 만들어서 새 속성·카드가 생기면 저절로 들어간다.
## ★로 선호 표시(Meta.favs) → 판 중 선택지에 나오면 카드가 반짝인다 (Sparkle).

const CATS := [
	["elem", "속성"], ["pat", "공격방식"], ["mod", "강화"], ["link", "연계"], ["react", "특수 반응"], ["perk", "특성"], ["ach", "업적"],
]
## 업적 보유율 {id: 0~1} (서버 /v1/ach_rates, main이 넣는다. 비면 안 보임)
static var rates := {}
const FAV_COLOR := Color(1, 0.86, 0.35)

var perks: Array = []  # main.PERKS
var on_change: Callable  # 선호·칭호를 바꾸면 저장
var cat := "elem"
var list: VBoxContainer
var count_label: Label
var tabs: Array[Button] = []


## 선택지 카드의 도감 키. 속성은 번호 대신 이름으로 (속성이 늘어 번호가 밀려도 선호가 그대로).
static func card_key(card: Dictionary) -> String:
	if card["type"] == "elem":
		return "elem:" + str(Elem.NAMES[card["e"]])
	return "%s:%s" % [card["type"], card.get("id", "")]


## 분류마다 항목: {key, name, desc, color, sub}. sub는 이름 옆 작은 글 (반응 발견 여부 등).
func entries(c: String) -> Array:
	var out := []
	match c:
		"elem":
			for e in Elem.ALL:
				var ps := Elem.partners(e)
				out.append({"key": card_key({"type": "elem", "e": e}), "name": Elem.NAMES[e], "color": Elem.COLORS[e],
					"desc": "같은 색 공격방식 카드: %s (속성과 따로 나오는 카드, 직선탄 오브젝트에 넣음)\n추가 효과: %s\n형태 성질(시험): %s%s" % [Elem.FORM.get(e, "-"), Elem.RIDER.get(e, "-"), Elem.TRAIT.get(e, "-"), "\n반응: " + ", ".join(ps) if not ps.is_empty() else ""]})
		"pat":
			for id in Pat.ALL_IDS:
				if id != Pat.DEFAULT:  # 직선탄은 카드로 나오지 않는다
					var no := Pat.no_mods(id)
					out.append({"key": "pat:" + id, "name": Pat.pname(id), "desc": Pat.PATTERNS[id]["desc"] + ("\n못 넣는 강화: " + "·".join(no) if not no.is_empty() else ""), "color": Pat.pcolor(id).lightened(0.15)})
		"mod":
			for id in Pat.MOD_IDS:
				out.append({"key": "mod:" + id, "name": Pat.MODS[id]["name"], "desc": Pat.MODS[id]["desc"], "color": Color(1, 0.82, 0.4)})
		"link":
			for id in Pat.LINK_IDS:
				out.append({"key": "link:" + id, "name": Pat.LINKS[id]["name"], "desc": Pat.LINKS[id]["desc"], "color": Color(0.55, 0.9, 1.0)})
		"react":
			# 만나 본 반응을 먼저 (91개라 아직 못 만난 것 사이에서 찾기 어렵던 것), 그 안은 원래 순서
			var seen: Array = Elem.REACTIONS.filter(func(r): return Meta.codex.has(r["id"]))
			for r in seen + Elem.REACTIONS.filter(func(r): return not Meta.codex.has(r["id"])):
				out.append({"key": "react:" + str(r["id"]), "name": r["name"], "color": r.get("color", Color.WHITE),
					"sub": "%s + %s%s" % [Elem.NAMES[r["a"]], Elem.NAMES[r["b"]], "" if Meta.codex.has(r["id"]) else "   · 아직 못 만남"],
					"desc": "%s\n선호하면 이 반응을 만들 수 있는 속성 카드가 반짝여요" % r["desc"]})
		"perk":
			for pk in perks:
				out.append({"key": "perk:" + str(pk["id"]), "name": pk["name"], "desc": pk["desc"], "color": FAV_COLOR})
		"ach":
			for g in Ach.GROUPS:
				out.append({"head": g})
				for a in Ach.LIST:
					if a["group"] == g:
						out.append(_ach_entry(a))
	if c in ["elem", "pat", "mod", "link", "perk"]:
		for x in out:
			var n := Ach.picks(stat_key(x["key"]))
			x["sub"] = ("✓ 수집 · %d번 고름" % n) if n > 0 else "· 아직 안 골라 봄"
			x["got"] = n > 0
			if n == 0:
				x["color"] = Color(x["color"], 0.5)
	return out


## 도감 키 → 통계 키 (속성만 이름 대신 영문 키: elem:불 → elem:fire).
static func stat_key(key: String) -> String:
	if key.begins_with("elem:"):
		for e in Elem.ALL:
			if str(Elem.NAMES[e]) == key.substr(5):
				return "elem:" + Patch.ELEM_KEYS[Elem.ALL.find(e)]
	return key


static func _ach_entry(a: Dictionary) -> Dictionary:
	var id: String = a["id"]
	var done := Meta.achieved.has(id)
	var hide := Ach.hidden(a)
	var t: Dictionary = Ach.TIERS[a["tier"]]
	var rw := PackedStringArray()
	for sk in Meta.TOWER_SKIN_IDS:
		if Meta.TOWER_SKINS[sk]["need"] == id:
			rw.append("오브젝트 모양 '%s'" % Meta.TOWER_SKINS[sk]["name"])
	for sk in Meta.CORE_SKIN_IDS:
		if Meta.CORE_SKINS[sk]["need"] == id:
			rw.append("중앙 모양 '%s'" % Meta.CORE_SKINS[sk]["name"])
	if Ach.can_title(id):
		rw.append("칭호")
	var g := Ach.goal(a)
	var cur := g if done else (Ach.value(a["stat"]) if a["stat"] != "" else 0)
	return {"key": "ach:" + id, "id": id, "name": a["name"], "tier": t["name"], "tier_color": t["color"], "done": done,
		"desc": "???" if hide else a["desc"], "cur": mini(cur, g), "goal": g, "bar": a["stat"] != "" and not hide,
		"reward": ", ".join(rw), "rate": rates.get(id, -1.0), "color": t["color"] if done else Color(1, 1, 1, 0.85)}


func setup(perk_list: Array, sb: StyleBox, changed: Callable) -> void:
	perks = perk_list
	on_change = changed
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = -430.0
	offset_right = 430.0
	offset_top = -300.0
	offset_bottom = 270.0
	add_theme_stylebox_override("panel", sb)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "도감   (K / Esc: 닫기)"
	t.add_to_group("key_hint")  # 터치 화면에서 main이 키 안내를 뺀다
	t.add_theme_font_size_override("font_size", 22)
	head.add_child(t)
	count_label = Label.new()
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", FAV_COLOR)
	head.add_child(count_label)
	var tip := Label.new()
	tip.text = "☆를 눌러 선호 표시: 판 중에 그 카드가 선택지에 나오면 반짝이며 알려 줘요"
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	v.add_child(tip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var g := ButtonGroup.new()
	for spec in CATS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = g
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("cat", spec[0])
		b.pressed.connect(func():
			cat = spec[0]
			_draw_list()
			(list.get_parent() as ScrollContainer).scroll_vertical = 0)
		row.add_child(b)
		tabs.append(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(func(): visible = false)
	v.add_child(close)


func toggle() -> void:
	visible = not visible
	if visible:
		_draw_list()
		(list.get_parent() as ScrollContainer).scroll_vertical = 0


## 분류 탭 글(선호 수)과 지금 분류의 목록을 다시 만든다.
func _draw_list() -> void:
	_draw_tabs()
	for b in tabs:
		b.button_pressed = b.get_meta("cat") == cat
	for ch in list.get_children():
		ch.queue_free()
	for x in entries(cat):
		list.add_child(_row(x))


func _row(x: Dictionary) -> Control:
	if x.has("head"):
		var hl := Label.new()
		hl.text = x["head"]
		hl.add_theme_font_size_override("font_size", 16)
		hl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		return hl
	if x.has("goal"):
		return _ach_row(x)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var star := Button.new()
	star.custom_minimum_size = Vector2(44, 44)
	star.focus_mode = Control.FOCUS_NONE
	star.add_theme_font_size_override("font_size", 22)
	var key: String = x["key"]
	var paint := func():
		var on := Meta.favs.has(key)
		star.text = "★" if on else "☆"
		star.add_theme_color_override("font_color", FAV_COLOR if on else Color(1, 1, 1, 0.45))
		star.add_theme_color_override("font_hover_color", FAV_COLOR.lightened(0.3) if on else Color(1, 1, 1, 0.8))
	paint.call()
	star.pressed.connect(func():
		if Meta.favs.has(key):
			Meta.favs.erase(key)
		else:
			Meta.favs[key] = true
		paint.call()
		if on_change.is_valid():
			on_change.call()
		_draw_tabs())
	h.add_child(star)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var n := Label.new()
	n.text = x["name"] + ("   " + x["sub"] if x.has("sub") else "")
	n.add_theme_font_size_override("font_size", 17)
	n.add_theme_color_override("font_color", x["color"])
	v.add_child(n)
	var d := Label.new()
	d.text = PatchNotes.kr_keep(x["desc"])
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(700, 0)
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	v.add_child(d)
	return h


func _ach_row(x: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var done: bool = x["done"]
	var mark := Label.new()
	mark.text = "✓" if done else "·"
	mark.custom_minimum_size = Vector2(44, 0)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 22)
	mark.add_theme_color_override("font_color", x["tier_color"] if done else Color(1, 1, 1, 0.4))
	h.add_child(mark)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var tier := Label.new()
	tier.text = "[%s]" % x["tier"]
	tier.add_theme_font_size_override("font_size", 14)
	tier.add_theme_color_override("font_color", x["tier_color"])
	top.add_child(tier)
	var n := Label.new()
	n.text = x["name"]
	n.add_theme_font_size_override("font_size", 17)
	n.add_theme_color_override("font_color", x["color"])
	top.add_child(n)
	var extra := Label.new()
	var bits := PackedStringArray()
	if x["reward"] != "":
		bits.append("보상: " + x["reward"])
	if x["rate"] >= 0.0:
		bits.append("보유 %s%%" % ("%.1f" % (x["rate"] * 100.0) if x["rate"] < 0.1 else str(roundi(x["rate"] * 100.0))))
	extra.text = "   ".join(bits)
	extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extra.add_theme_font_size_override("font_size", 13)
	extra.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	top.add_child(extra)
	if done and Ach.can_title(x["id"]):
		var tb := Button.new()
		var on: bool = Meta.title == x["id"]
		tb.text = "칭호 해제" if on else "칭호로"
		tb.focus_mode = Control.FOCUS_NONE
		tb.add_theme_font_size_override("font_size", 13)
		tb.pressed.connect(func():
			Meta.title = "" if Meta.title == x["id"] else x["id"]
			if on_change.is_valid():
				on_change.call()
			_draw_list())
		top.add_child(tb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var d := Label.new()
	d.text = x["desc"]
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	row.add_child(d)
	if x["bar"] and x["goal"] > 1:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(160, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = x["goal"]
		bar.value = x["cur"]
		row.add_child(bar)
	var c := Label.new()
	c.text = ("%s / %s" % [_num(x["cur"]), _num(x["goal"])]) if x["bar"] and x["goal"] > 1 else ("달성" if done else "")
	c.custom_minimum_size = Vector2(130, 0)
	c.add_theme_font_size_override("font_size", 14)
	c.add_theme_color_override("font_color", x["tier_color"] if done else Color(1, 1, 1, 0.7))
	row.add_child(c)
	return h


static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## 별을 누를 때는 목록은 두고 탭 숫자만 고친다 (목록을 다시 만들면 굴린 자리가 맨 위로 감).
func _draw_tabs() -> void:
	var total := 0
	for b in tabs:
		var c: String = b.get_meta("cat")
		var es := entries(c)
		var n := es.filter(func(x): return Meta.favs.has(x.get("key", ""))).size()
		total += n
		var nm: String = CATS.filter(func(s): return s[0] == c)[0][1]
		var got: int
		var all: int
		if c == "ach":
			got = Meta.achieved.size()
			all = Ach.LIST.size()
		elif c == "react":
			got = es.filter(func(x): return Meta.codex.has(str(x["key"]).substr(6))).size()
			all = es.size()
		else:
			got = es.filter(func(x): return x.get("got", false)).size()
			all = es.size()
		b.text = "%s %d/%d" % [nm, got, all] + (" ★%d" % n if n > 0 else "")
	var tl := ""
	if Meta.title != "":
		tl = "칭호: " + Meta.ACHIEVEMENTS[Meta.title]["name"]
	var parts := PackedStringArray()
	if tl != "":
		parts.append(tl)
	if total > 0:
		parts.append("선호 %d개" % total)
	count_label.text = "   ".join(parts)


## 선호 카드 반짝임: 카드 위에 얹어 테두리 빛·도는 별·"★ 선호" 꼬리표를 그린다 (누르기는 아래 카드가 받음).
class Sparkle extends Control:
	var t := randf() * 10.0
	var tag := "★ 선호"

	func _init(text := "★ 선호") -> void:
		tag = text
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pulse := 0.5 + 0.5 * sin(t * 3.2)
		for i in 3:
			draw_rect(r.grow(1.0 + i * 2.5), Color(Codex.FAV_COLOR, (0.55 - i * 0.16) * (0.45 + 0.55 * pulse)), false, 2.0)
		# 테두리를 따라 도는 별 여섯 개, 저마다 깜빡임
		var per := 2.0 * (size.x + size.y)
		for k in 6:
			var tw := 0.5 + 0.5 * sin(t * 5.0 + k * 1.9)
			_star(_perim(fmod(t * 55.0 + per * k / 6.0, per)), 3.0 + 4.5 * tw, Color(1, 1, 0.85, 0.35 + 0.65 * tw))
		var f := get_theme_default_font()
		var fs := 13
		var w := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box := Rect2(size.x - w - 16.0, -10.0, w + 10.0, 20.0)
		draw_rect(box, Color(0.22, 0.16, 0.02, 0.96))
		draw_rect(box, Color(Codex.FAV_COLOR, 0.6 + 0.4 * pulse), false, 1.5)
		draw_string(f, Vector2(box.position.x + 5.0, 5.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Codex.FAV_COLOR)

	## 테두리 둘레 s 지점 (왼쪽 위에서 시계 방향).
	func _perim(s: float) -> Vector2:
		if s < size.x:
			return Vector2(s, 0)
		s -= size.x
		if s < size.y:
			return Vector2(size.x, s)
		s -= size.y
		if s < size.x:
			return Vector2(size.x - s, size.y)
		return Vector2(0, size.y - (s - size.x))

	func _star(p: Vector2, rad: float, c: Color) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			pts.append(p + Vector2.from_angle(i * PI / 4.0) * (rad if i % 2 == 0 else rad * 0.3))
		draw_colored_polygon(pts, c)
