class_name Vote
extends PanelContainer
## 다음 패치 투표 (시작 화면 [투표] V, 판 끝난 화면 [다음 패치 투표]).
## 도감 목록(속성·공격방식·강화·연계·발동·반응·특성) 줄마다 ▲ 강하게 / ▼ 약하게 / ✎ 개선.
## 회차마다 계정당 표 MAX장(서버가 정함), 한 항목엔 방향 하나. 개선엔 한 줄 의견(선택).
## 서버: GET/PUT /v1/vote (server/app/votes.py). 키는 통계 키(Codex.stat_key: elem:fire 등).

const DIRS := ["up", "down", "fix"]
const DIR_TEXT := {"up": "▲", "down": "▼", "fix": "✎"}
const DIR_NAME := {"up": "강하게", "down": "약하게", "fix": "개선"}
const DIR_COLOR := {"up": Color(1.0, 0.55, 0.4), "down": Color(0.5, 0.75, 1.0), "fix": Color(1.0, 0.86, 0.35)}
const CATS := [["run", "이번 판"], ["elem", "속성"], ["pat", "공격방식"], ["mod", "강화"], ["link", "연계"], ["trig", "발동"], ["react", "특수 반응"], ["perk", "특성"]]
const NOTE_MAX := 60
const KEY_RE := "^(elem|pat|mod|link|trig|react|perk):[a-z0-9_]{1,40}$"

var net: Net
var cx: Codex  # 목록은 도감 것을 그대로 (새 카드가 생기면 저절로 들어감)
var cat := "elem"
var run_keys: Array = []  # 판 끝난 화면에서 열면: 이번 판에 고른 것 (맨 앞 탭)
var max_votes := 5
var round_id := 0
var round_name := ""
var can_vote := false
var loaded := false
var dirty := false
var sending := false
var picks := {}  # 통계 키 -> {dir, note}
var names := {}  # 통계 키 -> 이름 (지난 회차 결과 글)
var last := {}  # 지난 회차 결과 (서버)

var list: VBoxContainer
var title_label: Label
var left_label: Label
var status: Label
var last_label: Label
var send_btn: Button
var tabs: Array[Button] = []
var tab_row: HBoxContainer


func setup(perk_list: Array, sb: StyleBox, net_node: Net) -> void:
	net = net_node
	cx = Codex.new()
	cx.perks = perk_list
	for c in CATS:
		if c[0] != "run":
			for x in cx.entries(c[0]):
				names[Codex.stat_key(x["key"])] = x["name"]
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
	title_label = Label.new()
	title_label.add_to_group("key_hint")  # 터치 화면에서 main이 키 안내를 뺀다
	title_label.add_theme_font_size_override("font_size", 22)
	head.add_child(title_label)
	left_label = Label.new()
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left_label.add_theme_font_size_override("font_size", 16)
	left_label.add_theme_color_override("font_color", Codex.FAV_COLOR)
	head.add_child(left_label)
	var tip := Label.new()
	tip.text = "다음 패치에서 강해졌으면 ▲, 약해졌으면 ▼, 바뀌었으면 하는 점이 있으면 ✎ (한 줄 의견). 다시 누르면 취소"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	v.add_child(tip)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	v.add_child(tab_row)
	var g := ButtonGroup.new()
	for spec in CATS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = g
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("cat", spec[0])
		b.tooltip_text = spec[1]
		b.pressed.connect(func():
			cat = spec[0]
			_draw_list()
			(list.get_parent() as ScrollContainer).scroll_vertical = 0)
		var kind: String = {"react": "rx", "run": "ach"}.get(spec[0], spec[0])
		b.draw.connect(func():
			var tw := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			var cx0 := (b.size.x - tw) / 2.0 - (12.0 if b.text != "" else 0.0)
			if spec[0] == "run":
				Glyph.ui(b, "flag", Vector2(cx0, b.size.y / 2.0), 8.0, Color(0.95, 0.85, 0.6))
			else:
				Glyph.kind(b, kind, Vector2(cx0, b.size.y / 2.0), 8.0, Color(0.95, 0.85, 0.6)))
		tab_row.add_child(b)
		tabs.append(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	sc.add_child(list)
	last_label = Label.new()
	last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_label.add_theme_font_size_override("font_size", 13)
	last_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	last_label.visible = false
	v.add_child(last_label)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	v.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	send_btn = Button.new()
	send_btn.text = "보내기"
	send_btn.focus_mode = Control.FOCUS_NONE
	send_btn.custom_minimum_size = Vector2(0, 40)
	send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_btn.pressed.connect(send)
	row.add_child(send_btn)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 40)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(hide_panel)
	row.add_child(close)
	_draw_head()


func _exit_tree() -> void:
	if is_instance_valid(cx):
		cx.free()


## 판 끝난 화면에서 열 때: 이번 판에 고른 카드·특성(통계 키)을 맨 앞 탭으로.
func open(from_run: Array = []) -> void:
	run_keys = []
	for k in from_run:
		if k is String and k.match("*:*") and not run_keys.has(k) and _key_ok(k):
			run_keys.append(k)
	cat = "run" if not run_keys.is_empty() else ("elem" if cat == "run" else cat)
	visible = true
	_draw_list()
	(list.get_parent() as ScrollContainer).scroll_vertical = 0
	load_votes()


func toggle(from_run: Array = []) -> void:
	if visible:
		hide_panel()
	else:
		open(from_run)


## 닫을 때 바꾼 표가 있으면 보낸다.
func hide_panel() -> void:
	visible = false
	if dirty and can_vote:
		send()


static func _key_ok(k: String) -> bool:
	return RegEx.create_from_string(KEY_RE).search(k) != null


# ---------- 표 고르기 (서버 없이도 돌아가는 부분, tools/spec_check.gd가 확인) ----------

func used() -> int:
	return picks.size()


## 한 항목에 방향을 넣는다. 같은 방향을 다시 누르면 취소, 다른 방향이면 바꿈. 표가 모자라면 까닭을 돌려준다.
func choose(key: String, dir: String) -> String:
	if not _key_ok(key) or not DIRS.has(dir):
		return "bad"
	if picks.has(key):
		if picks[key]["dir"] == dir:
			picks.erase(key)
		else:
			picks[key] = {"dir": dir, "note": picks[key]["note"] if dir == "fix" else ""}
		dirty = true
		return ""
	if picks.size() >= max_votes:
		return "full"
	picks[key] = {"dir": dir, "note": ""}
	dirty = true
	return ""


func set_note(key: String, note: String) -> void:
	if picks.has(key) and picks[key]["dir"] == "fix":
		picks[key]["note"] = note.strip_edges().left(NOTE_MAX)
		dirty = true


## PUT /v1/vote 본문.
func payload() -> Dictionary:
	var vs := []
	for k in picks:
		vs.append({"key": k, "dir": picks[k]["dir"], "note": picks[k]["note"]})
	return {"round": round_id, "votes": vs}


## 서버 응답(GET /v1/vote)을 받아 넣는다.
func take(d: Dictionary) -> void:
	var r: Variant = d.get("round")
	round_id = int(r.get("id", 0)) if r is Dictionary else 0
	round_name = str(r.get("name", "")) if r is Dictionary else ""
	max_votes = int(d.get("max", 5))
	var why := str(d.get("reason", ""))
	can_vote = round_id > 0 and d.get("eligible", false) == true
	picks.clear()
	for m in d.get("mine", []):
		if m is Dictionary and _key_ok(str(m.get("key", ""))):
			picks[str(m["key"])] = {"dir": str(m.get("dir", "up")), "note": str(m.get("note", ""))}
	last = d.get("last") if d.get("last") is Dictionary else {}
	dirty = false
	loaded = true
	if round_id == 0:
		_say("지금 열린 투표가 없어요")
	elif why == "play":
		_say("%d웨이브 이상 간 판을 한 번 보내면 투표할 수 있어요" % int(d.get("min_wave", 5)))
	elif why == "banned":
		_say("이 기기는 투표할 수 없어요")
	elif why == "auth":
		_say("서버에 로그인하지 못했어요. 잠시 뒤 다시 열어 주세요")
	else:
		_say("")


# ---------- 서버 ----------

func load_votes() -> void:
	loaded = false
	can_vote = false
	_say("불러오는 중…")
	_draw_head()
	if net == null:
		return
	var d: Dictionary = await net.vote_get()
	if not is_inside_tree():
		return
	if d.is_empty():
		_say("서버에 연결하지 못했어요" if Meta.online_on else "설정에서 '기록 보내기'를 켜면 투표할 수 있어요")
	else:
		take(d)
	_draw_list()


func send() -> void:
	if sending or not can_vote or net == null:
		return
	sending = true
	_say("보내는 중…")
	var code: int = await net.vote_put(payload())
	sending = false
	if not is_inside_tree():
		return
	match code:
		200:
			dirty = false
			_say("보냈어요. 이번 회차 동안은 언제든 바꿀 수 있어요")
		409:
			_say("회차가 바뀌었어요. 다시 불러올게요")
			load_votes()
		403:
			_say("투표할 수 없는 계정이에요")
		_:
			_say("보내지 못했어요 (%s). 닫을 때 다시 보내요" % ("연결 실패" if code == 0 else str(code)))
	_draw_head()


# ---------- 화면 ----------

func _say(t: String) -> void:
	if status:
		status.text = t
		status.visible = t != ""


func _draw_head() -> void:
	title_label.text = "다음 패치 투표%s   (V / Esc: 닫기)" % (" · " + round_name if round_name != "" else "")
	left_label.text = "남은 표 %d / %d" % [maxi(0, max_votes - used()), max_votes] if loaded and round_id > 0 else ""
	send_btn.disabled = not can_vote or sending
	send_btn.text = "보내기" + (" *" if dirty else "")
	var parts := PackedStringArray()
	for d in DIRS:
		var xs := PackedStringArray()
		for it in last.get(d, []):
			if it is Dictionary:
				xs.append("%s %d" % [names.get(str(it.get("key", "")), str(it.get("key", ""))), int(it.get("n", 0))])
		if not xs.is_empty():
			parts.append("%s %s: %s" % [DIR_TEXT[d], DIR_NAME[d], ", ".join(xs)])
	last_label.visible = not parts.is_empty()
	last_label.text = "지난 회차(%s, %d명) 결과 — %s" % [str(last.get("name", "")), int(last.get("voters", 0)), "  ·  ".join(parts)] if not parts.is_empty() else ""


func _entries(c: String) -> Array:
	if c == "run":
		var out := []
		for k in run_keys:
			out.append({"key": k, "name": names.get(k, k), "color": Color(1, 1, 1, 0.9), "desc": ""})
		return out
	var xs := []
	for x in cx.entries(c):
		if x.has("key"):
			xs.append({"key": Codex.stat_key(x["key"]), "name": x["name"], "color": Color(x["color"], 1.0), "desc": x.get("desc", ""),
				"sub": x.get("sub", "") if c == "react" else ""})
	return xs


func _draw_list() -> void:
	_draw_head()
	for b in tabs:
		var c: String = b.get_meta("cat")
		b.visible = c != "run" or not run_keys.is_empty()
		b.button_pressed = c == cat
		var n := 0
		for k in picks:
			if (c == "run" and run_keys.has(k)) or (c != "run" and k.begins_with(("react" if c == "react" else c) + ":")):
				n += 1
		b.text = str(n) if n > 0 else ""
		b.queue_redraw()
	for ch in list.get_children():
		ch.queue_free()
	for x in _entries(cat):
		list.add_child(_row(x))


func _row(x: Dictionary) -> Control:
	var key: String = x["key"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	box.add_child(h)
	var n := Label.new()
	n.text = x["name"] + ("   " + x["sub"] if x.get("sub", "") != "" else "")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.custom_minimum_size.x = 60
	n.add_theme_font_size_override("font_size", 17)
	n.add_theme_color_override("font_color", x["color"])
	if x.get("desc", "") != "":
		n.tooltip_text = PatchNotes.kr_keep(x["desc"])
		n.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(n)
	# 이름 옆 빈자리엔 설명 첫 줄을 흐리게 (전체는 말풍선)
	var first := str(x.get("desc", "")).get_slice("\n", 0)
	if first != "":
		n.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		n.clip_text = false  # 이름은 다 보이게 (줄이는 건 설명 쪽)
		var dl := Label.new()
		dl.text = PatchNotes.kr_keep(first)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dl.clip_text = true
		dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		dl.add_theme_font_size_override("font_size", 13)
		dl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		dl.tooltip_text = n.tooltip_text
		dl.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(dl)
	var note := LineEdit.new()
	note.max_length = NOTE_MAX
	note.placeholder_text = "어떻게 바뀌면 좋을지 한 줄로 (선택, %d자)" % NOTE_MAX
	note.add_theme_font_size_override("font_size", 14)
	note.text = picks[key]["note"] if picks.has(key) else ""
	note.visible = picks.has(key) and picks[key]["dir"] == "fix"
	note.editable = can_vote
	note.text_changed.connect(func(t): set_note(key, t); _draw_head())
	for d in DIRS:
		var b := Button.new()
		b.text = DIR_TEXT[d]
		b.tooltip_text = DIR_NAME[d]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.disabled = not can_vote
		var on: bool = picks.has(key) and picks[key]["dir"] == d
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(DIR_COLOR[d], 0.35) if on else Color(1, 1, 1, 0.06)
		sb.border_color = DIR_COLOR[d] if on else Color(1, 1, 1, 0.2)
		sb.set_border_width_all(2 if on else 1)
		sb.set_corner_radius_all(6)
		for s in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		b.add_theme_color_override("font_color", DIR_COLOR[d] if on else Color(1, 1, 1, 0.7))
		b.add_theme_color_override("font_hover_color", DIR_COLOR[d].lightened(0.2))
		b.pressed.connect(func():
			var err := choose(key, d)
			if err == "full":
				_say("표 %d장을 다 썼어요. 다른 표를 취소하고 넣어 주세요" % max_votes)
			elif err == "":
				_say("")
			_draw_list()
			if picks.has(key) and picks[key]["dir"] == "fix":
				_focus_note.call_deferred(key))
		h.add_child(b)
	box.add_child(note)
	box.set_meta("key", key)
	box.set_meta("note", note)
	return box


func _focus_note(key: String) -> void:
	for ch in list.get_children():
		if ch.has_meta("key") and ch.get_meta("key") == key and not ch.is_queued_for_deletion():
			var le: LineEdit = ch.get_meta("note")
			if le.visible and DisplayServer.get_name() != "headless":
				le.grab_focus()
