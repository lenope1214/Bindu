class_name BinduUiLayout
extends BinduFeature

var key_re := RegEx.create_from_string(" ?\\((?:[KO] / )?(?:Q|V|S|D|E|F|K|O|H|M|N|P|T|Tab|Enter|Esc|F11|Space|←/→|↑/↓)(?:: [^)]*)?\\)")
var _badge_memo := {}  # _free_badge 답 (입력 hash → Rect2)
var _badge_cands: Array[Vector2] = []  # _free_badge가 볼 자리 (안쪽 칸, 옆 칸), 가까운 순
func _bottom_free() -> float:
	return session.hint.position.y - 4.0 if session.hint.text != "" else session.ui_root.size.y - 60.0


## 진입 화살표 자리 [화살 끝(월드), 들어오는 방향, lanes 번호]. 화살 그림(_draw·_draw_line_map)과 배지가 같은 자리를 쓴다.
func _lane_arrows() -> Array:
	var out: Array = []
	if Meta.map_id == "line":
		var from_right := not Meta.line_flip
		var d := Vector2(-1.0 if from_right else 1.0, 0)
		out.append([Vector2(Meta.FIELD.x - 18.0 if from_right else 18.0, Meta.FIELD.y / 2.0), d, 0])
		return out
	var c := session.center()
	var vr := session.arena()
	for i in session.lanes.size():
		var d := Vector2.from_angle(session.lanes[i])
		var edge := session._edge_point(c, d)
		if Meta.map_id == "spiral":
			var path := PackedVector2Array()
			for q in session._orb_path(session.lanes[i]):
				if not path.is_empty() or vr.has_point(q):
					path.append(q)
			if path.size() >= 2:
				edge = path[0]
				d = (path[0] - path[1]).normalized()
		out.append([edge - d * 18.0, d, i])
	return out


func _strip_key_hints() -> void:
	var nodes: Array = session.ui_root.find_children("*", "Button", true, false)
	nodes.append_array([session.dps_head, session.flip_label])
	nodes.append_array(session.get_tree().get_nodes_in_group("key_hint"))  # 창 제목 (Esc: 닫기)
	for b in nodes:
		if not is_instance_valid(b):
			continue
		var t0: String = b.text
		var t1 := _kh(t0, b == session.skip_badge)
		if t1 != t0:
			b.text = t1


## 매 프레임 쓰는 버튼 글은 쓸 때 바로 뺀다 (0.2초마다 빼도 같은 프레임에 다시 써져서 남았다)
func _kh(t: String, tap := false) -> String:
	if not session.touch_ui or not t.contains("("):
		return t
	return t.replace("(S: ", "(눌러서 ") if tap else key_re.sub(t, "", true)


## 아래 안내 글을 터치에 맞게: 클릭 → 누르기, 우클릭/Esc → 취소 버튼, 키보드·Shift 안내는 뺀다
func _th(t: String) -> String:
	if not session.touch_ui:
		return t
	return t.replace("Space 또는 [웨이브 시작]", "[웨이브 시작]").replace(" (Shift: 15도 단위)", "") \
		.replace("   오브젝트 우클릭한 채 끌기로도 바로 됨", "").replace("우클릭/Esc", "취소").replace("Esc/우클릭", "취소") \
		.replace("클릭 또는", "누르기 또는").replace("오브젝트를 클릭", "오브젝트 누르기").replace("클릭", "누르기")


## 위쪽 가운데 글(알림·처음 안내)을 가운데에 두되, 오른쪽 설명이 떠 있으면 그 왼쪽까지만 (글자를 키우면 글 끝이 설명 밑에 깔리던 것).
## 글이 정한 폭보다 길면 Label이 오른쪽으로만 늘어나 가운데에서 벗어나던 것도 함께 맞춘다.
## 전장 가운데 글(알림·큰 글)이 넘지 말아야 할 오른쪽 끝: 오른쪽 설명, 쉬는 시간 카드 정보 칸(도크 오른쪽)
func _right_panel_x() -> float:
	var x := session.ui_root.size.x
	if session.legend.visible:
		x = minf(x, session.legend.get_rect().position.x)
	if session.card_dock != null and session.card_dock.side != null and session.card_dock.side.visible and session.card_dock.side.modulate.a > 0.05:
		x = minf(x, session.card_dock.side.get_rect().position.x)
	return x


func _beside_legend(c: Control, min_w: float) -> void:
	var w := maxf(min_w, c.get_combined_minimum_size().x)
	var x := (session.ui_root.size.x - w) / 2.0
	x = minf(x, _right_panel_x() - 8.0 - w)
	c.position.x = maxf(x, 8.0)
	c.size.x = w


## 오른쪽 설명이 떠 있으면 배지를 그 왼쪽으로 비킨다 (설명 글 위에 겹치던 것).
## 아래에 자리가 있으면 설명 아래로, 없으면 왼쪽으로.
func _off_legend(r: Rect2) -> Rect2:
	var lr := session.legend.get_rect()
	if session.legend.visible and r.intersects(lr):
		if lr.end.y + 20.0 + r.size.y < session.info.size.y - 64.0:
			r.position.y = lr.end.y + 20.0
		else:
			r.position.x = lr.position.x - r.size.x - 8.0
	return r


## 배지가 피해야 할 화면 UI 자리 (UI 좌표): 점수 줄·DPS 표·오른쪽 위 버튼·웨이브 시작·아래 안내·버튼 줄·알림 등.
## 예전엔 오른쪽 설명(legend)만 피해서 왼쪽 위 길목 배지가 DPS 표 위에, 아래 길목 배지가 [웨이브 시작] 위에 겹쳤다.
func _info_blockers() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var inv := session.ui_root.get_global_transform().affine_inverse()
	for c: Control in [session.hud, session.dps_panel, session.legend, session.range_btn, session.zoom_btn, session.start_btn, session.skip_badge, session.bar_box, session.toast, session.banner, session.guide_label, session.guide_more,  session.mp_bar, session.ver_label, session.hint, session.apply_btn, session.reroll_btn, session.card_detail_btn, session.hide_btn, session.skip_btn, session.skip_n_btn, session.cancel_btn, session.detail_btn, session.aim_ok_btn, session.card_dock.focus_btn, session.card_dock.panel, session.card_dock.side, session.card_dock.footer]:
		if c == null or not c.is_visible_in_tree():
			continue
		if (c is Label and str(c.text) == "") or (c == session.hud and session.hud_chips.is_empty()):
			continue
		var r := inv * c.get_global_rect()
		if c == session.hint and not session.hint.has_theme_stylebox_override("normal"):
			# 안내 글은 칸이 넓어도 글이 있는 곳만
			var tw := minf(r.size.x, session.ui_font.get_multiline_string_size(session.hint.text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 15).x)
			r.size.x = tw + 4.0
		if r.has_area():
			out.append(r.grow(4.0))
	if session.choice_header.visible:
		out.append(inv * session.choice_header.get_global_rect())
	return out


## 배지를 화살표에서 안쪽(전장 가운데 쪽)으로, 모자라면 옆으로 밀어 UI·다른 배지와 겹치지 않는 자리를 찾는다.
## 자리가 없으면 처음 자리 그대로.
func _free_badge(r: Rect2, inward: Vector2, avoid: Array[Rect2], lo_r: Rect2) -> Rect2:
	# 겹친 넓이 (0이면 빈자리)
	var cover := func(q: Rect2) -> float:
		var a := 0.0
		for b in avoid:
			if q.intersects(b):
				a += q.intersection(b).get_area()
		return a
	if is_zero_approx(cover.call(r)):
		return r
	# 같은 자리·같은 UI면 지난 답 그대로 (자리 찾기가 매 프레임 수백 칸을 보지 않게)
	var key := hash([r, inward, avoid, lo_r])
	if _badge_memo.has(key):
		return _badge_memo[key]
	if _badge_memo.size() > 64:
		_badge_memo.clear()
	var found := _free_badge_search(r, inward, lo_r, cover)
	_badge_memo[key] = found
	return found


func _free_badge_search(r: Rect2, inward: Vector2, lo_r: Rect2, cover: Callable) -> Rect2:
	# 화살표에서 가까운 자리부터: 안쪽(가운데 쪽)으로 0~34칸 × 옆으로 -6~6칸, 가까운 순. 바깥쪽(화면 끝)으로는 가지 않는다.
	# 빈자리가 없으면(글자 130%로 UI가 화면을 많이 차지할 때) 가장 덜 겹치는 자리
	if _badge_cands.is_empty():
		for step in range(0, 35):
			for sd in range(-6, 7):
				if step != 0 or sd != 0:
					_badge_cands.append(Vector2(step * 16.0, sd * 20.0))
		_badge_cands.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
	var side := Vector2(-inward.y, inward.x)
	var best := r
	var best_a: float = cover.call(r)
	for c: Vector2 in _badge_cands:
		var q := r
		q.position += inward * c.x + side * c.y
		q.position = q.position.clamp(lo_r.position, lo_r.end - q.size)
		var a: float = cover.call(q)
		if is_zero_approx(a):
			return q
		if a < best_a - 1.0:
			best_a = a
			best = q
	return best


## 화면 위 아이콘 층: 진입 화살표 옆 구체 수 배지, 놓친 구체, 남은 고르기, 칩·배지에 올리면 뜨는 말풍선.
