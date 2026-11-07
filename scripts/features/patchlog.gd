class_name BinduPatchlog
extends BinduFeature
## 패치노트 상태와 표시. 예약 콜백은 main의 순서를 따른다.

var notes_text: RichTextLabel
var notes_status: Label
var notes: PatchNotes
var notes_back := false  # 설정 창에서 열었으면 닫을 때 설정 창으로 돌아간다
var notes_open := {}  # 패치노트에서 펼친 버전 (지금·새 버전은 처음부터 펼침)
func _build_notes(root: Control) -> void:
	var session: BinduSession = self.session
	session.notes_panel = PanelContainer.new()
	session.notes_panel.z_index = 22  # 일시정지 어둠(z 20) 위에
	session.notes_panel.set_anchors_preset(Control.PRESET_CENTER)
	session.notes_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	session.notes_panel.offset_left = -430.0
	session.notes_panel.offset_right = 430.0
	session.notes_panel.offset_top = -300.0
	session.notes_panel.offset_bottom = 270.0
	if session.viewport_system._phone():
		# 폰: 화면 높이(글자 130%면 약 520)에 맞는 창이라 줄어들지 않는다 (줄어들면 키운 글자가 도로 작아졌다)
		var nw := clampf(session.viewport_system._phone_ui_w() / 2.0, 430.0, 480.0)
		session.notes_panel.offset_left = -nw
		session.notes_panel.offset_right = nw
		session.notes_panel.offset_top = -245.0
		session.notes_panel.offset_bottom = 245.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_content_margin_all(18)
	sb.set_corner_radius_all(6)
	session.notes_panel.add_theme_stylebox_override("panel", sb)
	session.notes_panel.visible = false
	root.add_child(session.notes_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	session.notes_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "패치노트"
	t.add_theme_font_size_override("font_size", Meta.fs(22))
	head.add_child(t)
	notes_status = Label.new()
	notes_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notes_status.add_theme_font_size_override("font_size", Meta.fs(13))
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
	notes_text.add_theme_font_size_override("normal_font_size", Meta.fs(15))
	notes_text.add_theme_font_size_override("bold_font_size", Meta.fs(15))
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
	var session: BinduSession = self.session
	if session.notes_panel.visible:
		_close_notes()
		return
	session.notes_panel.visible = true
	notes_back = session.settings_panel.visible
	session.settings_panel.visible = false
	session.records_panel.visible = false
	session.help_label.visible = false
	if Meta.notes_seen != Net.game_version():
		Meta.notes_seen = Net.game_version()
		session.progression_system._save_best()
		_refresh_notes_btn()
	_draw_notes()
	(notes_text.get_parent() as ScrollContainer).scroll_vertical = 0
	notes.fetch()


func _close_notes() -> void:
	var session: BinduSession = self.session
	session.notes_panel.visible = false
	if notes_back:
		session.settings_panel.visible = true
	notes_back = false


func _kr_keep(t: String) -> String:
	return PatchNotes.kr_keep(t)

func _draw_notes() -> void:
	var session: BinduSession = self.session
	if session.notes_panel == null or not session.notes_panel.visible:
		return
	var cur := Net.game_version()
	var cur_t := PatchNotes.vtuple(cur)
	var out := PackedStringArray()
	# 서버가 알려 준 새 버전 (스토어·다운로드 주소가 있는 것)
	var latest: Variant = Net.info.get("latest")
	if latest is Dictionary and str(latest.get("version", "")) != "":
		var ln := str(latest.get("notes", ""))
		out.append("[color=#ffd873]새 버전 v%s가 나왔어요. 시작 화면의 [업데이트]를 눌러 주세요.%s[/color]\n" % [session._bb(str(latest["version"])), ("\n" + session._bb(ln)) if ln != "" else ""])
	# 색 안내: 줄 앞 꼬리표가 무슨 뜻인지
	var legend := PackedStringArray()
	for k in BinduSession.NOTE_KINDS:
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
			out.append("[b]%s[/b]" % session._bb(n["title"]))
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
			for k in BinduSession.NOTE_KINDS:
				if cnt.has(k):
					sums.append("[color=%s]%s %d[/color]" % [BinduSession.NOTE_KINDS[k][1], BinduSession.NOTE_KINDS[k][0], cnt[k]])
			out.append("[url=v%s][bgcolor=#1b2230][b][font_size=19] %s v%s [/font_size][/b]  [color=#e8ecf2]%s[/color][/bgcolor][/url]%s" % [v, "▾" if open else "▸", v, session._bb(n["title"]), tag])
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
	notes_text.text = Meta.fs_bb(_kr_keep("\n".join(out)))
	match PatchNotes.source:
		"online":
			notes_status.text = "최신 (인터넷)"
		"cache":
			notes_status.text = "불러오는 중…" if PatchNotes.fetching else "지난번에 받은 노트"
		_:
			notes_status.text = "불러오는 중…" if PatchNotes.fetching else "이 빌드에 든 노트"


## 패치노트 줄 종류: [꼬리표, 글자색, 바탕색]. 위에서부터 먼저 맞는 것
func _note_kind(t: String) -> String:
	var head := t.split(":")[0]
	if BinduSession._re_fix.search(head):
		return "fix"
	if BinduSession._re_new.search(head):
		return "new"
	if BinduSession._re_tune.search(head):
		return "tune"
	if BinduSession._re_ui.search(head):
		return "ui"
	return "etc"


func _note_chip(k: String) -> String:
	var d: Array = BinduSession.NOTE_KINDS[k]
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
	var session: BinduSession = self.session
	t = BinduSession._re_arrow.sub(session._bb(t), "[color=#7d8694]$1[/color] → [b][color=#ffe08a]$2[/color][/b]", true)
	return BinduSession._re_quote.sub(t, "[color=#ffd873]\"$1\"[/color]", true)


## 윗줄: "제목: 설명"이면 제목은 굵고 밝게, 설명은 보통. (사용자 선택 …)·(제보 …)는 작고 흐리게
func _note_head(s: String) -> String:
	var session: BinduSession = self.session
	var asides := PackedStringArray()
	for m in BinduSession._re_aside.search_all(s):
		asides.append(m.get_string().strip_edges())
	s = BinduSession._re_aside.sub(s, "", true)
	var cut := session._colon_at(s)
	var aside := ""
	if not asides.is_empty():
		aside = " [font_size=12][color=#6f7a88]%s[/color][/font_size]" % session._bb(" ".join(asides))
	if cut < 0:
		return "[color=#e8ecf2]%s[/color]%s" % [_note_marks(s), aside]
	# 설명은 다음 줄로 (제목만 훑어 읽기 쉽게)
	return "[b][color=#ffffff]%s[/color][/b]%s\n[color=#c3c9d2]%s[/color]" % [_note_marks(s.substr(0, cut)), aside, _note_marks(s.substr(cut + 1).strip_edges())]


## 들여 쓴 줄: 조금 흐리게, "측정"·봇 줄은 더 흐리게
func _note_sub(s: String) -> String:
	var session: BinduSession = self.session
	var dim := s.begins_with("측정") or s.begins_with("봇") or s.begins_with("자동 플레이")
	var cut := session._colon_at(s)
	var c := "#8a93a0" if dim else "#b4bbc5"
	if cut >= 0 and cut < 40:
		return "[color=%s][b]%s[/b]:%s[/color]" % [c, _note_marks(s.substr(0, cut)), _note_marks(s.substr(cut + 1))]
	return "[color=%s]%s[/color]" % [c, _note_marks(s)]


## 괄호 밖 첫 ": " 자리 (없으면 -1)
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
func _refresh_notes_btn() -> void:
	var session: BinduSession = self.session
	if session.notes_btn == null:
		return
	var cur := Net.game_version()
	var fresh := Meta.notes_seen != cur and PatchNotes.has_version(cur)
	session.notes_btn.text = "패치노트 · v%s%s" % [cur, " 새로 바뀐 것" if fresh else ""]
	session.notes_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.45) if fresh else Color(1, 1, 1, 0.8))
