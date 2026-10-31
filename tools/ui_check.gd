extends RefCounted
## 화면 배치 자동 점검: 보이는 글·버튼·창·배지끼리 겹치거나 화면 밖으로 나간 것을 찾아 줄로 찍는다.
## 스크린샷 도구(shot.gd·ui_audit.gd)가 찍을 때마다 부른다. 같은 창(Container) 안끼리는 겹칠 수 없어 보지 않는다.
## 출력: "UI OVERLAP <화면> <a> <b>" / "UI OFFSCREEN <화면> <a>" / "UI CLIP <화면> <a>" (없으면 "UI ok <화면>")


## 이름이 없는 노드는 보이는 글로 부른다
static func _name(c: Control) -> String:
	var t := ""
	if c is Button or c is Label:
		t = str(c.text)
	elif c is RichTextLabel:
		t = (c as RichTextLabel).get_parsed_text()
	t = t.replace("\n", " ").strip_edges()
	if t.length() > 24:
		t = t.substr(0, 24) + "…"
	return "%s「%s」" % [c.get_class(), t] if t != "" else "%s(%s)" % [c.get_class(), c.name]


static func _alpha(c: CanvasItem) -> float:
	var a := 1.0
	var n: Node = c
	while n is CanvasItem:
		a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a
		n = n.get_parent()
	return a


## 겹침을 볼 단위: ui_root 바로 아래 자식(창·버튼·글 하나씩). 창 안의 줄은 창과 같이 움직이므로 창 하나로 본다.
static func _units(main) -> Array:
	var out: Array = []
	for c in main.ui_root.get_children():
		_collect(c, out)
	return out


static func _collect(c: Node, out: Array) -> void:
	if not c is Control:
		return
	var ctl := c as Control
	if not ctl.is_visible_in_tree() or _alpha(ctl) < 0.25:
		return
	# 그냥 묶음(전체 화면 Control)은 속을 본다
	if ctl.get_class() == "Control" and not ctl is Container:
		var gr := ctl.get_global_rect()
		if gr.size.x * gr.size.y > 0.5 * ctl.get_viewport_rect().size.x * ctl.get_viewport_rect().size.y:
			for k in ctl.get_children():
				_collect(k, out)
			return  # 화면 전체 그림 층(info 등)은 그 자체로는 보지 않는다
	if (ctl is Label or ctl is Button) and str(ctl.text) == "" and ctl.get_child_count() == 0 and not (ctl is Button and (ctl as Button).icon != null):
		if not ctl.draw.get_connections().size() > 0:
			return  # 빈 글
	var r := ctl.get_global_rect()
	# 줄 상자(HBox·VBox)는 정해 둔 칸이 아니라 보이는 버튼들이 있는 곳만 (오른쪽 아래 버튼 줄을 접으면 [설정] 하나)
	if ctl is BoxContainer:
		var u := Rect2()
		for k in ctl.get_children():
			if k is Control and k.visible:
				u = k.get_global_rect() if not u.has_area() else u.merge(k.get_global_rect())
		if u.has_area():
			r = u
	# 바탕 없는 글은 칸이 넓어도 글이 있는 곳만 (왼쪽 정렬은 왼쪽부터, 가운데 정렬은 가운데)
	if ctl is Label and not ctl.has_theme_stylebox_override("normal") and ctl.horizontal_alignment != HORIZONTAL_ALIGNMENT_FILL:
		var f: Font = ctl.get_theme_font("font")
		var fs: int = ctl.get_theme_font_size("font_size")
		var k := ctl.get_global_transform().get_scale().x
		var tw := f.get_multiline_string_size(str(ctl.text), HORIZONTAL_ALIGNMENT_LEFT, ctl.size.x if ctl.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0, fs).x * k + 2.0
		if tw < r.size.x:
			match ctl.horizontal_alignment:
				HORIZONTAL_ALIGNMENT_CENTER: r.position.x += (r.size.x - tw) / 2.0
				HORIZONTAL_ALIGNMENT_RIGHT: r.position.x += r.size.x - tw
			r.size.x = tw
		var th := f.get_multiline_string_size(str(ctl.text), HORIZONTAL_ALIGNMENT_LEFT, ctl.size.x if ctl.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0, fs).y * k + 2.0
		if th < r.size.y:
			if ctl.vertical_alignment == VERTICAL_ALIGNMENT_CENTER: r.position.y += (r.size.y - th) / 2.0
			elif ctl.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM: r.position.y += r.size.y - th
			r.size.y = th
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	out.append([ctl, r])


static func check(main, tag: String, extra: Array = []) -> int:
	var vp: Rect2 = main.get_viewport().get_visible_rect()
	var pad: Rect2 = main._safe_pad() if main.has_method("_safe_pad") else Rect2()
	vp = Rect2(vp.position + pad.position, vp.size - pad.position - pad.size)  # 노치·홈 막대 밖은 화면 밖
	var units := _units(main)
	var items: Array = []  # [이름, 화면 rect, node or null]
	for u in units:
		if u[0] == main.hud:
			# 점수 줄은 칩마다 (줄마다 폭이 달라 상자 하나로 보면 둘째 줄 옆 빈자리도 겹침으로 셌다)
			for ch in main.hud_chips:
				items.append(["점수 칩「%s」" % ch[3], Rect2(main.hud.get_global_transform() * (ch[0] as Rect2).position, (ch[0] as Rect2).size * main.hud.get_global_transform().get_scale()), main.hud])
			continue
		items.append([_name(u[0]), u[1], u[0]])
	# 그림으로 그린 것(진입 배지·점수 칩): ui_root 좌표 → 화면 좌표
	var xf: Transform2D = main.ui_root.get_global_transform()
	if extra.is_empty() and main.get("info_rects") != null:
		extra = main.info_rects
	for e in extra:
		items.append([e[0], xf * (e[1] as Rect2), null])
	# 화면 전체 어둠(일시정지·튜토리얼): 그 밑에 깔린 것은 일부러 가린 것이라 보지 않는다
	var dims: Array = []
	for it in items:
		if it[2] is ColorRect and (it[1] as Rect2).get_area() > 0.5 * vp.get_area():
			dims.append(it[2])
	if not dims.is_empty():
		var keep: Array = []
		for it in items:
			if it[2] in dims:
				continue
			var under := false
			for d in dims:
				if it[2] == null or _z(it[2]) < _z(d) or (_z(it[2]) == _z(d) and d.is_greater_than(it[2])):
					under = true
			if not under:
				keep.append(it)
		items = keep
	var bad := 0
	# 창(PanelContainer)이 화면 가운데에 떠 있으면 그 밑은 가려져도 된다 (창끼리만 본다)
	var modal: Array = []
	for it in items:
		var n = it[2]
		if n != null and n is PanelContainer and n.z_index >= 20:
			modal.append(it)
	for i in items.size():
		var a = items[i]
		var ra: Rect2 = a[1].grow(-1.0)
		if not vp.encloses(a[1].grow(-2.0)):
			print("UI OFFSCREEN %s %s %s" % [tag, a[0], _rs(a[1])])
			bad += 1
		for j in range(i + 1, items.size()):
			var b = items[j]
			if not ra.intersects(b[1].grow(-1.0)):
				continue
			if a[2] != null and a[2] == b[2]:
				continue
			if a[2] != null and b[2] != null and (a[2].is_ancestor_of(b[2]) or b[2].is_ancestor_of(a[2])):
				continue
			var hidden := false
			for m in modal:
				if m != a and m != b and (m[1] as Rect2).encloses(a[1]) and (m[1] as Rect2).encloses(b[1]):
					hidden = true
			if hidden:
				continue
			print("UI OVERLAP %s %s %s × %s %s" % [tag, a[0], _rs(a[1]), b[0], _rs(b[1])])
			bad += 1
	# 글이 칸보다 긴 버튼·글 (clip_text·말줄임으로 잘린 것)
	for u in units:
		for c in [u[0]] + u[0].find_children("*", "", true, false):
			if not (c is Control and c.is_visible_in_tree()):
				continue
			if (c is Button and (c.clip_text or c.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING)) or (c is Label and (c.clip_text or c.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) and c.autowrap_mode == TextServer.AUTOWRAP_OFF):
				var f: Font = c.get_theme_font("font")
				var fs: int = c.get_theme_font_size("font_size")
				var w := f.get_string_size(str(c.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if str(c.text) != "" and w > c.size.x - 4.0:
					print("UI CLIP %s %s 글 %d > 칸 %d" % [tag, _name(c), w, c.size.x])
					bad += 1
	if bad == 0:
		print("UI ok ", tag)
	return bad


static func _rs(r: Rect2) -> String:
	return "[%d,%d %dx%d]" % [r.position.x, r.position.y, r.size.x, r.size.y]


static func _z(c: CanvasItem) -> int:
	var z := 0
	var n: Node = c
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z
