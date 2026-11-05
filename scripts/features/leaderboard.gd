class_name BinduLeaderboard
extends BinduFeature

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
var board_seasons: Array = []  # 서버 시즌 목록 (새 시즌부터)
var board_raw := {}  # 리더보드 창: period → 받은 응답 (차단을 바꾸면 다시 그리기)
var board_people := {}  # 리더보드 창에 보이는 다른 사람 {pid: 닉네임} (신고·차단 창 목록)
var board_ugc_btn: Button  # 리더보드 창 오른쪽 아래 [신고·차단] (App Store 1.2, 지우지 말 것)
func _toggle_board() -> void:
	session.records_panel.visible = not session.records_panel.visible
	session.board_ugc_panel.visible = false
	if not session.records_panel.visible:
		session.board_box.visible = false
		return
	board_map = Meta.map_id
	board_rules = Meta.rules if Meta.rules in Rules.IDS else Rules.IDS[0]
	board_easy = Modes.easy()  # 쉽게 모드를 켰으면 쉽게 모드 기록
	board_season = 0
	board_period = "all"
	session.records_panel.text = ""
	session.board_box.visible = true
	_board_fit()
	session.net.seasons()
	_load_board()


func _board_tag() -> String:
	return "%s|%d|%d|%s" % [board_map, board_rules, board_season, board_easy]


func _load_board() -> void:
	board_raw = {}
	board_people = {}
	session.board_ugc_panel.visible = false
	if board_season != 0:
		board_period = "all"
	_draw_board()
	session.net.leaderboard(board_map, board_rules, "all", board_season, _board_tag(), board_easy)
	if board_season == 0:
		session.net.leaderboard(board_map, board_rules, "week", 0, _board_tag(), board_easy)


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
	if session.records_panel.visible and session.board_box.visible:
		_draw_board()


func _season_name(id: int) -> String:
	for x in board_seasons:
		if int(x.get("id", 0)) == id:
			return str(x.get("name", ""))
	return "시즌 %d" % id


func _on_board_loaded(d: Dictionary) -> void:
	if not session.records_panel.visible or not session.board_box.visible or d.get("tag", "") != _board_tag():
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
	var ph := session._phone()
	session.board_box = VBoxContainer.new()
	session.board_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	session.board_box.offset_left = 18.0
	session.board_box.offset_top = 14.0
	session.board_box.offset_right = -18.0
	session.board_box.offset_bottom = -14.0
	session.board_box.mouse_filter = Control.MOUSE_FILTER_STOP  # 창 안 빈 곳을 눌러도 닫히지 않게 (닫기는 ✕·바깥·Esc)
	session.board_box.add_theme_constant_override("separation", 10)
	session.board_box.visible = false
	session.records_panel.add_child(session.board_box)
	# 맨 위: 제목 + 닫기
	var head := HBoxContainer.new()
	session.board_box.add_child(head)
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
	session.board_box.add_child(body)
	# 왼쪽: 필터
	var left := VBoxContainer.new()
	board_left = left  # 폭은 _board_fit이 화면 폭에 맞춰 정한다
	left.add_theme_constant_override("separation", 12)
	if ph:
		body.add_child(session.hud_system._vscroll(left))  # 폰: 창을 줄이지 않고 필터·순위를 굴려 본다 (줄이면 글자가 7pt 남짓)
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
		right.add_child(session.hud_system._vscroll(board_rows))
	else:
		right.add_child(board_rows)
	# 맨 아래: 안내 + [신고·차단] (App Store 1.2)
	var foot := HBoxContainer.new()
	session.board_box.add_child(foot)
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
	b.custom_minimum_size = Vector2(64, 44 if session._phone() else 32)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(on_press)
	return b


func _board_chip_on(b: Button, on: bool) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14 if not session._phone() else 18)
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
	var ph := session._phone()
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
		cols = [str(int(e.get("rank", 0))), nick, tag, str(int(e.get("wave", 0))), session.num(int(e.get("score", 0)))]
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
	var ph := session._phone()
	var w := minf(session.ui_root.size.x - 40.0, 1400.0 if ph else 1140.0)  # 폰은 가로로 넓게 써서 닉네임 칸을 넓힌다
	var h := 560.0 if not ph else minf(590.0, session.ui_root.size.y - 24.0)  # 폰: 화면 높이에 맞추고 안은 굴려 본다
	board_narrow = w < 1100.0  # 글자를 키운 PC·폰: 필터 칸과 표 열을 좁힌다
	board_left.custom_minimum_size.x = 300.0 if board_narrow else 380.0
	session.records_panel.offset_left = -w / 2.0
	session.records_panel.offset_right = w / 2.0
	session.records_panel.offset_top = -h / 2.0
	session.records_panel.offset_bottom = h / 2.0


## 맵별 최고 기록 창은 원래 크기로
func _records_fit() -> void:
	session.records_panel.offset_left = -430.0
	session.records_panel.offset_right = 430.0
	session.records_panel.offset_top = -325.0
	session.records_panel.offset_bottom = 285.0


## 지금 보이는 순위 표 글 (점검용)
func _board_text() -> String:
	var out := PackedStringArray()
	for l: Label in board_rows.find_children("*", "Label", true, false):
		out.append(l.text)
	return " ".join(out)


# ---------- 닉네임 신고·차단 (App Store 1.2) ----------

## 리더보드 [신고·차단]: 지금 창에 보이는 다른 사람 목록. 다시 누르면 닫는다.
func _board_ugc_open() -> void:
	if session.board_ugc_panel.visible:
		session.board_ugc_panel.visible = false
		return
	for ch in session.board_ugc_panel.get_children():
		session.board_ugc_panel.remove_child(ch)
		ch.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	session.board_ugc_panel.add_child(v)
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
			session.board_ugc_panel.visible = false
			_board_ugc_open()))
		list.add_child(row)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): session.board_ugc_panel.visible = false)
	v.add_child(close)
	session.board_ugc_panel.visible = true


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
	rb.custom_minimum_size = Vector2(72, 40 if session._phone() else 32)
	rb.add_theme_font_size_override("font_size", 15)
	rb.disabled = pid == "" or not Net.report_ok()
	rb.tooltip_text = "부적절한 닉네임 신고" if not rb.disabled else "지금은 신고할 수 없어요 (온라인 연결 필요)"
	rb.pressed.connect(func():
		rb.disabled = true
		rb.text = "보내는 중"
		var code := await session.net.report(pid, nick, where)
		if not is_instance_valid(rb):
			return
		if code == 200:
			rb.text = "신고함"
			session.hud_system._show_toast("신고했어요. 운영자가 24시간 안에 확인해요")
		else:
			rb.text = "신고"
			rb.disabled = false
			session.hud_system._show_toast("신고를 보내지 못했어요. 잠시 뒤 다시 눌러 주세요"))
	box.add_child(rb)
	var bb := Button.new()
	var on := Meta.blocked.has(pid)
	bb.text = "차단 풀기" if on else "차단"
	bb.focus_mode = Control.FOCUS_NONE
	bb.custom_minimum_size = Vector2(90, 40 if session._phone() else 32)
	bb.add_theme_font_size_override("font_size", 15)
	bb.disabled = pid == ""
	bb.tooltip_text = "이 기기에서 이 사람 이름을 가리고 멀티 방에서 막아요"
	bb.pressed.connect(func():
		if Meta.blocked.has(pid):
			Meta.blocked.erase(pid)
			session.hud_system._show_toast("차단을 풀었어요")
		else:
			Meta.blocked[pid] = nick.left(16)
			session.hud_system._show_toast("차단했어요. 이 기기에서 이름이 가려져요")
		session.progression_system._save_best()
		after.call())
	box.add_child(bb)
	return box


# ---------- 패치노트 ----------

## 버전별 패치노트 창: 길어서 굴려 보는 창. 바깥을 누르거나 Esc·N으로 닫는다.
