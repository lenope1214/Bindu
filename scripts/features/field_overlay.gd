class_name BinduFieldOverlay
extends BinduFeature
## 진입 배지·보스 예고·전장 안내. 예약 콜백은 main의 순서를 따른다.

var info_sig: Array = []
var info_rects: Array = []  # 이번 프레임 info에 그린 배지 [이름, Rect2(UI 좌표)] (화면 배치 점검 tools/ui_check.gd)
func _draw_info() -> void:
	var session: BinduSession = self.session
	session.tip_rects.clear()
	info_rects.clear()
	var size := session.info.size
	var top := session.hud.position.y + session.hud.size.y + 6.0 if session.hud.visible else 8.0
	var lo := size.y - 64.0
	if session.card_dock.active():
		top = maxf(top, session.card_dock.bounds().position.y)
		lo = size.y - 8.0
	if session.hud.visible:
		for ch in session.hud_chips:
			session.tip_rects.append([Rect2(session.hud.position + ch[0].position, ch[0].size), ch[5]])
	var resting := session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.PLACE, BinduSession.Phase.AIM, BinduSession.Phase.MOVE, BinduSession.Phase.READY] and not session.title_label.visible and not session.get_tree().paused
	if resting and not session.lanes.is_empty():
		var xf := session.ui_root.get_global_transform().affine_inverse() * session.get_canvas_transform()
		var nw := session.wave + 1
		var counts := session.waves_system.lane_counts(nw)
		var badges: Array[Rect2] = []
		# 카드 위에 겹친 배지는 옅게 (글자를 키우면 카드가 화면 끝까지 차서 덮던 것). 카드를 내리면 다시 진하게
		var cards_r := Rect2()
		if session.phase == BinduSession.Phase.CHOOSE and session.choice_box.visible and not session.cards_hidden:
			cards_r = session.ui_root.get_global_transform().affine_inverse() * session.choice_box.get_global_rect()
		var boss_li := -1
		if nw % 5 == 0:
			boss_li = 0 if Meta.map_id == "line" or session.boss_plan.is_empty() else session.combat_system._lane_of(session.boss_plan["a"])
		var fs := 18
		# 폰: 배지가 7개까지 겹쳐 전장을 덮었다 → 수와 보스 왕관만, 섞여 나오는 종류는 점 하나(누르면 말풍선)
		var compact := session.viewport_system._phone() or (session.card_dock.active() and session.phase == BinduSession.Phase.CHOOSE)
		var blockers := session.ui_layout_system._info_blockers()
		# 오브젝트도 되도록 가리지 않는다 (배지를 비킬 때 오브젝트 위에 얹히던 것)
		for t in session.towers.get_children():
			blockers.append(Rect2(xf * t.position - Vector2(22, 26), Vector2(44, 48)))
		# 보스 길 안내(고리·"보스 · 웨이브 N" 글자·들어오는 길)도 가리지 않는다
		for br in _boss_mark_rects():
			blockers.append(xf * br)
		for arr in session.ui_layout_system._lane_arrows():
			var li: int = arr[2]
			var n: int = counts[li] if li < counts.size() else 0
			if Meta.map_id == "line":
				n = session.spawn_count(nw) - (1 if nw % 5 == 0 else 0)
			var fresh_lane := session.waves_system.lane_is_new(li)
			var warning := session.run_flow_system.lane_warning(li)
			var txt := ("새 진입 · " if fresh_lane else "") + "×%d" % n + (" · 범위 밖" if warning != "" else "")
			var tw := session.ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var nk := (0 if compact else session.wave_kinds.size()) + (1 if li == boss_li else 0)
			var w := 10.0 + tw + (6.0 + nk * 22.0 if nk > 0 else 0.0) + 8.0
			var p: Vector2 = xf * (arr[0] - arr[1] * 60.0)
			var r := Rect2(p - Vector2(w, 30.0) / 2.0, Vector2(w, 30.0))
			var gx := size.x
			var gy := lo
			r.position = r.position.clamp(Vector2(8.0, top), Vector2(gx - w - 8.0, gy - 30.0))
			var nh := 13.0 if not compact and session.wave_kinds.any(func(k): return k[2]) else 0.0  # 위에 붙는 NEW
			var avoid: Array[Rect2] = blockers.duplicate()
			for br in badges:
				avoid.append(br.grow(4.0))
			var inward: Vector2 = (xf.basis_xform(-arr[1])).normalized()
			r = session.ui_layout_system._free_badge(r.grow_side(SIDE_TOP, nh), inward, avoid, Rect2(8.0, 8.0, gx - 16.0, size.y - 16.0)).grow_side(SIDE_TOP, -nh)
			badges.append(r)
			# 카드 위에 걸친 배지는 그리지 않는다 (옅게 그려도 카드 글을 가렸고, 마우스를 올리면 말풍선이 카드를 덮었다). 카드를 내리면(V) 보인다
			if cards_r.has_area() and r.intersects(cards_r):
				continue
			info_rects.append(["배지 %s" % txt, r.grow_side(SIDE_TOP, 13.0 if not compact and session.wave_kinds.any(func(k): return k[2]) else 0.0)])
			var al := 0.85 if fresh_lane or warning != "" else (0.35 if session.card_dim.visible else 1.0)  # 카드 선택 막 아래 전장 것이라 같이 옅게
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.16, 0.04, 0.06, 0.88 * al)
			sb.border_color = Color(1, 0.8, 0.3, 0.95) if fresh_lane or warning != "" else Color(1, 0.35, 0.4, 0.9 * al)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(7)
			var home := Rect2(p - Vector2(w, 30.0) / 2.0, Vector2(w, 30.0))
			var far := r.get_center().distance_to(home.get_center())
			if far > 70.0 and far < 240.0:  # 너무 멀면 선이 화면을 가로질러 더 어지럽다 (글자 130%·길목 7곳)
				# UI를 피해 화살표에서 멀리 비켜났으면 화살표 쪽으로 옅은 선 (어느 길목 배지인지 보이게)
				var tip: Vector2 = xf * arr[0]
				# 카드 뒤의 화살표까지 잇는 선은 패널 윗변에서 멈춘다.
				if session.card_dock.panel.visible and tip.y > session.card_dock.panel.position.y:
					var from := r.get_center()
					var fraction := (session.card_dock.panel.position.y - 8 - from.y) / maxf(1, tip.y - from.y)
					tip = from.lerp(tip, clampf(fraction, 0, 1))
				var c0 := r.get_center()
				var e0 := c0 + (tip - c0).normalized() * minf(r.size.x, r.size.y) * 0.5
				session.info.draw_dashed_line(e0, tip - (tip - c0).normalized() * 14.0, Color(1, 0.4, 0.45, 0.35), 2.0, 6.0)
			session.info.draw_style_box(sb, r)
			var x := r.position.x + 10.0
			var cy := r.get_center().y
			session.info.draw_string(session.ui_font, Vector2(x, cy + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.88, 0.88, al))
			x += tw + 6.0
			if compact and not session.wave_kinds.is_empty():
				# 특수 구체가 섞이면 오른쪽 위 점 (처음 나오는 종류가 있으면 더 크게)
				var fresh := session.wave_kinds.any(func(k): return k[2])
				session.info.draw_circle(Vector2(r.end.x - 2.0, r.position.y + 2.0), 6.0 if fresh else 4.5, Color(1, 0.45, 0.45) if not fresh else Color(1, 0.85, 0.3))
			for k in ([] if compact else session.wave_kinds):
				Icons.draw(session.info, k[0], Vector2(x + 11.0, cy), 7.5, Color(k[1], k[1].a * al))
				if k[2] and al >= 1.0:
					# 처음 나오는 종류: 위에 작은 NEW
					var nr := Rect2(x - 1.0, r.position.y - 13.0, 24.0, 13.0)
					session.info.draw_rect(nr, Color(0.9, 0.25, 0.3))
					session.info.draw_string(session.ui_font, Vector2(nr.position.x + 1.0, nr.end.y - 2.0), "NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
				x += 22.0
			if li == boss_li:
				Icons.draw(session.info, "boss", Vector2(x + 11.0, cy), 7.5, Color(1, 0.6, 0.75, al))
			var lines: Array = [["이쪽에서 구체 %d개%s" % [n, " + 보스" if li == boss_li else ""], Color(1, 0.85, 0.85)]]
			if fresh_lane: lines.append(["다음 웨이브부터 새로 들어오는 방향이에요", Color(1, 0.85, 0.3)])
			if warning != "": lines.append([warning + ". 구체가 중앙에 도달할 수 있어요", Color(1, 0.85, 0.3)])
			session.tip_rects.append([r.grow(4.0), lines + session.wave_info])
		# 지난 웨이브에 놓친 구체: 그 방향 가장자리에 빨간 -N (다음 웨이브에 방향이 바뀌어도 어디서 샜는지 보이게)
		for lm in session.leak_marks:
			var d := Vector2.from_angle(lm[0])
			var ep: Vector2 = session.ui_layout_system._lane_arrows()[0][0] if Meta.map_id == "line" else session.combat_system._entry_point(lm[0])
			var p: Vector2 = xf * (ep - (Vector2(-1.0 if not Meta.line_flip else 1.0, 0) if Meta.map_id == "line" else d) * 120.0)
			var txt := "-%d" % lm[1]
			var w := Icons.chip_w(session.ui_font, txt, 16)
			var r := Rect2(p - Vector2(w, 26.0) / 2.0, Vector2(w, 26.0))
			r.position = r.position.clamp(Vector2(8.0, top), Vector2(size.x - w - 8.0, lo - 26.0))
			var avoid: Array[Rect2] = blockers.duplicate()
			for br in badges:
				avoid.append(br.grow(4.0))
			var inward: Vector2 = Vector2(1.0 if not Meta.line_flip else -1.0, 0) * -1.0 if Meta.map_id == "line" else (xf.basis_xform(-d)).normalized()
			r = session.ui_layout_system._free_badge(r, inward, avoid, Rect2(8.0, 8.0, size.x - 16.0, size.y - 16.0))
			badges.append(r)
			if cards_r.has_area() and r.intersects(cards_r):
				continue
			info_rects.append(["놓친 %s" % txt, r])
			var la := 0.35 if session.card_dim.visible else 1.0
			Icons.chip(session.info, session.ui_font, r, "orb", Color(0.85, 0.85, 0.9, la), txt, Color(1, 0.5, 0.5, la), 16, Color(0.1, 0.02, 0.03, 0.85 * la), Color(1, 0.4, 0.4, 0.6 * la))
			session.tip_rects.append([r, [["지난 웨이브에 이쪽에서 놓친 구체 %d개" % lm[1], Color(1, 0.6, 0.6)], [session.combat_system._leak_text(), Color(1, 1, 1, 0.7)]]])
	# 카드 선택 막 위로: 마우스를 올린 속성 카드로 새 반응이 생기는 오브젝트 고리 (전장의 고리는 막에 가려 옅다)
	if session.card_dim.visible and session.hover_elem >= 0:
		var xf2 := session.ui_root.get_global_transform().affine_inverse() * session.get_canvas_transform()
		var cr := session.ui_root.get_global_transform().affine_inverse() * session.choice_box.get_global_rect()
		var pz := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.7)
		var zs := xf2.get_scale().x
		var hcard := {"type": "elem", "e": session.hover_elem}
		for t in session.towers.get_children():
			if not t.can_take(hcard):
				continue
			var fresh := Elem.new_reactions(t.eff_now(), session.hover_elem)
			if fresh.is_empty():
				continue
			var tp: Vector2 = xf2 * t.position
			var rr := (Tower.RADIUS + 10.0 + pz * 4.0) * zs
			if cr.grow(rr).has_point(tp):
				continue
			if session.guide_label.visible and session.guide_label.get_rect().grow(rr).has_point(tp):
				continue  # 처음 안내 글 위에 걸치지 않게
			session.info.draw_arc(tp, rr, 0, TAU, 32, Color(fresh[0]["color"], 0.95), 3.0)
	# 선택 안내는 카드 줄 전체 폭의 독립 헤더. 개별 카드의 설명처럼 붙이지 않는다.
	if session.choice_header.visible:
		var r := session.choice_header.get_rect()
		session.tip_rects.append([r, [["이번 쉬는 시간에 카드를 %d장 더 선택할 수 있어요" % session.picks_left, Color(1, 0.9, 0.6)]]])
		if Vary.count() > 0:
			var sr := session.cards_system._draw_seal_chip(session.info, r.get_center().x, r.position.y - 6.0)
			session.tip_rects.append([sr, [["봉인 모드: 이번 판 선택지에 안 나오는 카드", Color(0.8, 0.8, 1.0)], [Vary.sealed_text(), Color(1, 1, 1, 0.9)], ["25·50웨이브에 하나씩 풀려요", Color(1, 1, 1, 0.6)]]])
	session.cards_system._draw_card_full()
	# 말풍선: 마우스를 올린 칩·배지 (터치는 누른 것)
	var m := session.info.get_local_mouse_position()
	var hit := -1
	for i in session.tip_rects.size():
		if (session.tip_pin == i and session.touch_ui) or (not session.touch_ui and session.tip_rects[i][0].has_point(m)):
			hit = i
	if hit < 0:
		return
	var tfs := 15
	var rows: Array = []
	var tw2 := 0.0
	for l in session.tip_rects[hit][1]:
		if str(l[0]) == "":
			continue
		for row in session.onboarding_system._wrap_words(l[0], 520.0, tfs).split("\n"):
			rows.append([row, l[1]])
			tw2 = maxf(tw2, session.ui_font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x)
	var lh := tfs + 6.0
	var bs := Vector2(tw2 + 20.0, rows.size() * lh + 12.0)
	var src: Rect2 = session.tip_rects[hit][0]
	var bp := Vector2(src.end.x + 8.0, src.position.y)
	if src.position.y < top:
		bp = Vector2(src.position.x, src.end.y + 6.0)  # 점수 줄 칩: 바로 아래 (옆 칩을 덮지 않게)
	elif bp.x + bs.x > size.x - 8.0:
		bp.x = src.position.x - bs.x - 8.0
	if bp.x < 8.0:
		bp = Vector2(src.position.x, src.end.y + 6.0)
	bp.x = clampf(bp.x, 8.0, maxf(8.0, size.x - bs.x - 8.0))
	bp.y = clampf(bp.y, 8.0, maxf(8.0, size.y - bs.y - 8.0))
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	tb.border_color = Color(1, 1, 1, 0.3)
	tb.set_border_width_all(1)
	tb.set_corner_radius_all(6)
	session.info.draw_style_box(tb, Rect2(bp, bs))
	for i in rows.size():
		session.info.draw_string(session.ui_font, bp + Vector2(10.0, 6.0 + tfs + i * lh), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, rows[i][1])


## 보스 길이(화면 밖 출발점부터 중앙까지)와 막지 않을 때 걸리는 시간.
func _boss_eta() -> float:
	var session: BinduSession = self.session
	var pts := session.spawning_system._orb_path(session.boss_plan["a"], session.boss_plan.get("y", 0.0))
	var L := 0.0
	for i in range(1, pts.size()):
		L += pts[i - 1].distance_to(pts[i])
	L -= BinduSession.CORE_RADIUS + 30.0  # 보스 반지름만큼 먼저 닿는다
	return L / (session.boss_plan["spd"] * Orb.KIND.boss_spd * session.orb_speed_mul * Modes.speed() * session.spawning_system.lane_k(session.boss_plan["a"]))


## 다음 보스 안내 (쉬는 시간에 미리 뽑아 둔 그대로).
func _boss_text() -> String:
	var session: BinduSession = self.session
	if session.boss_plan.is_empty():
		return "보스 등장! 중앙에 닿으면 체력 3 감소"
	var sp := PackedStringArray(["보스: 체력 %s" % session.num(ceilf(session.boss_plan["hp"] * Orb.KIND.boss_hp * Modes.boss_hp()))])
	if session.boss_plan["resist"] >= 0:
		sp.append("%s 저항" % Elem.NAMES[session.boss_plan["resist"]])
	if session.boss_plan["sturdy"]:
		sp.append("굳셈(밀기·감속·기절·냉기 절반)")
	sp.append("웨이브 마지막에 나옴")
	sp.append("%d초마다 빠른 부하 구체를 부름" % roundi(Orb.minion_every(session.boss_plan["wave"])))
	return " · ".join(sp) + "\n보스 길: 화면의 분홍 선(흐르는 화살). 막지 않으면 나온 뒤 약 %d초에 중앙 (닿으면 체력 -%d)" % [roundi(_boss_eta()), int(Orb.KIND.boss_core)]


## 바람 버프 둘레: 늘 그리면 바람 오브젝트마다 큰 원이 겹쳐 어지러워서,
## 바람 오브젝트에 Shift 자세히로 올렸을 때(그 둘레), 버프 받는 오브젝트에 자세히로 올렸을 때(버프를 주는 둘레),
## 오브젝트를 옮기는 중일 때(모든 둘레)만 그린다.
func _draw_wind_rings() -> void:
	var session: BinduSession = self.session
	return  # 2026-11-04 바람 효과가 순풍(둘레 공격 속도) → 밀쳐냄으로 바뀌어 둘레가 없다
	if session.title_label.visible or session.phase == BinduSession.Phase.GAMEOVER:
		return
	var winds := session.towers.get_children().filter(func(t): return t.lv(Elem.WIND) > 0)
	if winds.is_empty():
		return
	var show: Array = []
	if _place_rings_off():
		pass
	elif session.interaction_system.moving != null or session.interaction_system.dragging or session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.MOVE]:
		show = winds
	else:
		var h := session.field_view_system._ring_target()  # 올린 오브젝트 둘레는 자세히일 때만
		if h != null:
			for w in winds:
				if w == h or w.position.distance_to(h.position) <= w.wind_range():
					show.append(w)
	var sp := fmod(Time.get_ticks_msec() / 1000.0 * 0.5, 1.0)
	var wc: Color = Elem.COLORS[Elem.WIND]
	for w in show:
		session.draw_arc(w.position, w.wind_range(), sp * TAU, sp * TAU + TAU * 0.85, 48, Color(wc, 0.35), 1.5)


## 카드를 넣는 단계에서 모든 바람·별 둘레를 끌지: 새로 놓을 수 없는 카드(강화·연계 등)이거나 오브젝트 위에 올려 둔 동안.
## 둘레는 새 자리를 고를 때만 쓸모 있고, 여러 개가 겹치면 올린 오브젝트 설명·범위가 묻힌다. 올린 오브젝트 자기 둘레는 draw_range가 그린다.
func _place_rings_off() -> bool:
	var session: BinduSession = self.session
	return session.phase == BinduSession.Phase.PLACE and session.interaction_system.moving == null and not session.interaction_system.dragging and (session.picked.get("type", "") != "elem" or session.interaction_system._tower_at(session.interaction_system._pointer_world()) != null)


## 별 흡수 둘레: 오브젝트를 놓거나 옮기는 중엔 모든 별의 둘레(어디 두면 별빛을 주는지),
## 별빛을 주는 오브젝트에 자세히(Shift)로 올리면 그걸 받는 별의 둘레. 별 자신에 올렸을 때·Alt·[범위 보기]는 draw_range가 그린다.
func _draw_star_rings() -> void:
	var session: BinduSession = self.session
	if session.title_label.visible or session.phase == BinduSession.Phase.GAMEOVER or Input.is_key_pressed(KEY_ALT) or session.range_all:
		return
	# star_towers는 웨이브 계산 때만 갱신되니 쉬는 시간에도 맞게 여기서 직접 고른다
	var stars := session.towers.get_children().filter(func(t): return t.lv(Elem.STAR) > 0)
	if stars.is_empty():
		return
	var show: Array = []
	if _place_rings_off():
		pass
	elif session.interaction_system.moving != null or session.interaction_system.dragging or session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.MOVE, BinduSession.Phase.AIM]:
		show = stars.filter(func(s): return s != session.interaction_system.moving)
	else:
		var h := session.field_view_system._ring_target()
		if h != null:
			for s in stars:
				if s != h and s.position.distance_to(h.position) < Rules.t("star_r"):
					show.append(s)
	for s in show:
		Tower.draw_star_ring(session, s.position, Elem.COLORS[Elem.STAR])


## 보스가 올 길: 쉬는 시간과, 보스 웨이브에서 보스가 나오기 전까지.
## 진입 부채꼴: 구체가 실제로 올 수 있는 범위(진입 각도 a ± sp)를 옅게 칠하고 테두리, 화면 가장자리엔 입구 막대,
## 흐르는 점은 폭 전체에. 소용돌이는 나선 길을 ±sp 돌린 띠. 웨이브 중엔 더 옅게.
func _draw_lane_fan(a: float, sp: float, now: float) -> void:
	var session: BinduSession = self.session
	if sp <= 0.0:
		return
	var c := session.viewport_system.center()
	var rest := session.phase != BinduSession.Phase.WAVE
	var col := Color(1, 0.3, 0.35)
	var fill := Color(col, 0.16 if rest else 0.05)
	var rim := Color(col, 0.5 if rest else 0.18)
	var bar := Color(col, 0.9 if rest else 0.3)
	const N := 16
	if Meta.map_id == "spiral":
		var vr := session.viewport_system.arena().grow(2.0)
		var mid := PackedVector2Array()
		for q in session.spawning_system._orb_path(a):
			if not mid.is_empty() or vr.has_point(q):
				mid.append(q)
		if mid.size() < 2:
			return
		var lo := PackedVector2Array()
		var hi := PackedVector2Array()
		for q in mid:
			lo.append(c + (q - c).rotated(-sp))
			hi.append(c + (q - c).rotated(sp))
		var fade := func(q: Vector2) -> Color: return Color(fill, fill.a * clampf((q.distance_to(c) - 40.0) / 360.0, 0.0, 1.0))
		for i in range(1, mid.size()):
			if vr.has_point(lo[i]) or vr.has_point(hi[i]):
				session.draw_polygon(PackedVector2Array([lo[i - 1], lo[i], hi[i], hi[i - 1]]),
					PackedColorArray([fade.call(lo[i - 1]), fade.call(lo[i]), fade.call(hi[i]), fade.call(hi[i - 1])]))
		for side in [lo, hi]:
			var cut := PackedVector2Array()
			for q in side:
				if not cut.is_empty() or vr.has_point(q):
					cut.append(q)
			if cut.size() >= 2:
				session.draw_polyline(cut, rim, 2.0)
		if rest:
			for k in 5:
				var f := fmod(now * 0.25 + k / 5.0, 1.0)
				var q: Vector2 = mid[mini(int(f * (mid.size() - 1)), mid.size() - 1)]
				for j in 3:
					var r := (j - 1) * sp
					session.draw_circle(c + (q - c).rotated(r), 2.5, Color(col, 0.5 * (1.0 - f)))
		return
	var edge := PackedVector2Array()
	for k in N + 1:
		edge.append(session.field_view_system._edge_point(c, Vector2.from_angle(a - sp + 2.0 * sp * k / N)))
	# 가장자리에서 진하고 중앙으로 갈수록 투명하게 (길목이 6곳이면 화면 전체가 붉어지고, 중앙에 테두리가 몰려 어지러웠다)
	var poly := PackedVector2Array([c])
	poly.append_array(edge)
	var cols := PackedColorArray([Color(fill, 0.0)])
	for k in N + 1:
		cols.append(fill)
	session.draw_polygon(poly, cols)
	var clear := Color(rim, 0.0)
	session.draw_polyline_colors(PackedVector2Array([c, edge[0]]), PackedColorArray([clear, rim]), 2.0)
	session.draw_polyline_colors(PackedVector2Array([c, edge[N]]), PackedColorArray([clear, rim]), 2.0)
	session.draw_polyline(edge, bar, 5.0 if rest else 3.0)
	if rest:
		# 중앙 쪽으로 흐르는 점을 폭 전체에 (가운데 한 줄만 흐르면 그 선으로만 오는 줄 안다)
		for j in 5:
			var e := session.field_view_system._edge_point(c, Vector2.from_angle(a - sp + 2.0 * sp * (j + 0.5) / 5.0))
			for k in 3:
				var f := fmod(now * 0.25 + k / 3.0 + j * 0.13, 1.0)
				session.draw_circle(e.lerp(c, f * 0.85), 2.5, Color(col, 0.55 * (1.0 - f)))


## 보스 길 표시 자리 (그림과 진입 배지 비키기가 같은 값을 쓴다). 그릴 게 없으면 빈 사전.
## pts: 화면 안 길, lens: 누적 길이, m: 들어오는 자리 고리, lp·lw: 글자 자리·폭.
func _boss_mark() -> Dictionary:
	var session: BinduSession = self.session
	if session.boss_plan.is_empty() or session.title_label.visible or session.phase == BinduSession.Phase.GAMEOVER:
		return {}
	if session.phase == BinduSession.Phase.WAVE and session.boss_plan["wave"] != session.wave:
		return {}
	var vr := session.viewport_system.arena()
	var all := session.spawning_system._orb_path(session.boss_plan["a"], session.boss_plan.get("y", 0.0))
	# 화면 안에 들어온 뒤부터 그린다 (직선은 화면 가장자리에서 자름)
	var pts := PackedVector2Array()
	if Meta.map_id == "line":
		pts.append(Vector2(clampf(all[0].x, 0.0, vr.size.x), all[0].y))
		pts.append(all[1])
	elif all.size() == 2:
		pts.append(session.field_view_system._edge_point(session.viewport_system.center(), Vector2.from_angle(session.boss_plan["a"])))
		pts.append(all[1])
	else:
		for p in all:
			if not pts.is_empty() or vr.has_point(p):
				pts.append(p)
	if pts.size() < 2:
		return {}
	var lens: Array[float] = [0.0]
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i - 1].distance_to(pts[i]))
	var total: float = lens[-1]
	# 들어오는 자리: 큰 고리 + 글자. 가장자리의 버튼·점수 줄에 가리지 않게 길을 따라 안쪽(110)에
	var at := minf(110.0, total * 0.4)
	var j2 := 1
	while j2 < pts.size() - 1 and lens[j2] < at:
		j2 += 1
	var d2 := (pts[j2] - pts[j2 - 1]).normalized()
	var m := pts[j2 - 1] + d2 * (at - lens[j2 - 1])
	var label := "보스 · 웨이브 %d" % session.boss_plan["wave"]
	var w := session.ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, BinduSession.BOSS_FS).x
	# 길 옆에 쓴다 (길 위에 쓰면 화살과 겹침): 중앙에서 먼 쪽 옆
	var side := d2.orthogonal()
	if side.dot(m - session.viewport_system.core()) < 0.0:
		side = -side
	var lp := m + side * 30.0 + Vector2(-w / 2.0 if absf(side.x) < 0.5 else (0.0 if side.x > 0.0 else -w), 6.0)
	lp = lp.clamp(Vector2(8, 70), vr.size - Vector2(w + 8, 70))
	return {"pts": pts, "lens": lens, "m": m, "lp": lp, "lw": w, "label": label}


## 진입 배지가 피할 보스 표시 자리(월드 좌표): 고리·글자·화면 안 길.
func _boss_mark_rects() -> Array[Rect2]:
	var session: BinduSession = self.session
	var out: Array[Rect2] = []
	var bm := _boss_mark()
	if bm.is_empty():
		return out
	var m: Vector2 = bm["m"]
	out.append(Rect2(m - Vector2(26, 26), Vector2(52, 52)))
	out.append(Rect2(bm["lp"] - Vector2(4, BinduSession.BOSS_FS + 2), Vector2(bm["lw"] + 8, BinduSession.BOSS_FS + 10)))
	# 길 전체 (중앙 점 둘레는 빼고): 소용돌이는 꺾인 길을 마디마다
	var pts: PackedVector2Array = bm["pts"]
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var L := a.distance_to(pts[i])
		var d := (pts[i] - a) / maxf(L, 0.01)
		var s := 0.0
		while s < L:
			var q := a + d * s
			if q.distance_to(session.viewport_system.core()) > BinduSession.CORE_RADIUS + 30.0:
				out.append(Rect2(q - Vector2(8, 8), Vector2(16, 16)))
			s += 20.0
	return out


func _draw_boss_path(now: float) -> void:
	var session: BinduSession = self.session
	var bm := _boss_mark()
	if bm.is_empty():
		return
	var col := Color(1, 0.35, 0.6)
	var pts: PackedVector2Array = bm["pts"]
	var lens: Array[float] = bm["lens"]
	var pulse := 0.75 + 0.25 * sin(now * 3.0)
	session.draw_polyline(pts, Color(col, 0.6 * pulse), 2.5)
	# 보스가 오는 쪽으로 흐르는 화살 (길이 비율로 놓는다)
	var total: float = lens[-1]
	for k in 3:
		var dpos := fmod(now * 0.12 + k / 3.0, 1.0) * (total - BinduSession.CORE_RADIUS - 20.0)
		var j := 1
		while j < pts.size() - 1 and lens[j] < dpos:
			j += 1
		var seg := pts[j] - pts[j - 1]
		if seg.length() < 0.01:
			continue
		var d := seg.normalized()
		var q := pts[j - 1] + d * (dpos - lens[j - 1])
		session.draw_colored_polygon(PackedVector2Array([q + d * 9.0, q - d * 5.0 + d.orthogonal() * 7.0, q - d * 5.0 - d.orthogonal() * 7.0]), Color(col, 0.85))
	var m: Vector2 = bm["m"]
	session.draw_arc(m, 20.0 + 3.0 * sin(now * 5.0), 0, TAU, 32, Color(col, 0.95), 3.0)
	session.draw_circle(m, 9.0, Color(col, 0.9))
	var lp: Vector2 = bm["lp"]
	session.draw_string_outline(session.ui_font, lp, bm["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, BinduSession.BOSS_FS, 4, Color(0, 0, 0, 0.9))
	session.draw_string(session.ui_font, lp, bm["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, BinduSession.BOSS_FS, Color(1, 0.75, 0.85))


## 카드 선택 안내·봉인 칩에 필요한 카드 위 공간 (UI 좌표).
func _choice_headroom() -> float:
	var session: BinduSession = self.session
	if session.card_dock != null and session.card_dock.active():
		return 0.0
	if session.phase != BinduSession.Phase.CHOOSE or session.perk_mode or session.cards_hidden:
		return 0.0
	return BinduSession.CHOICE_HEADER_H + BinduSession.CHOICE_HEADER_GAP + (32.0 if Vary.count() > 0 else 0.0)


func _update_choice_header() -> void:
	var session: BinduSession = self.session
	session.choice_header.visible = session.phase == session.Phase.CHOOSE and not session.perk_mode and session.choice_box.visible and not session.cards_hidden \
		and session.choice_box.get_child_count() > 0 and not session.title_label.visible and not session.get_tree().paused
	if not session.choice_header.visible:
		return
	var inv := session.ui_root.get_global_transform().affine_inverse()
	var first := inv * (session.choice_box.get_child(0) as Control).get_global_rect()
	var last := inv * (session.choice_box.get_child(session.choice_box.get_child_count() - 1) as Control).get_global_rect()
	session.choice_remaining.text = "%d장 더 선택 가능" % session.picks_left
	if session.card_dock.active():
		return  # 자리는 카드 도크가 정한다 (여기서도 정하면 둘이 매 프레임 번갈아 바꿨다)
	session.choice_header.size = Vector2(last.end.x - first.position.x, session.CHOICE_HEADER_H)
	session.choice_header.position = Vector2(first.position.x, first.position.y - session.CHOICE_HEADER_H - session.CHOICE_HEADER_GAP)


## 터치 미리보기의 적용 동작. 위치는 카드 아래 조작 줄에서 함께 정한다.
func _place_apply_btn() -> void:
	var session: BinduSession = self.session
	var cs := session.choice_box.get_children() if session.choice_box else []
	var on := session.touch_ui and session.phase == BinduSession.Phase.CHOOSE and not session.perk_mode and session.choice_box.visible and not session.cards_hidden \
		and session.tap_sel >= 0 and session.tap_sel < cs.size() and not cs[session.tap_sel].is_queued_for_deletion() and not session.get_tree().paused
	session.apply_btn.visible = on
	if not on:
		return
	var head: Dictionary = cs[session.tap_sel].get_meta("card")[0]
	session.apply_btn.text = "%s 적용" % head["name"]
	session.apply_btn.set_meta("choice_icon", head.duplicate())
	session.apply_btn.queue_redraw()


## 카드와 같은 벡터 그림을 금색 버튼의 글자 왼쪽에 그린다.
func _draw_apply_icon() -> void:
	var session: BinduSession = self.session
	var head: Dictionary = session.apply_btn.get_meta("choice_icon", {})
	if head.is_empty():
		return
	var tw := session.ui_font.get_string_size(session.apply_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var c := Vector2((session.apply_btn.size.x - tw - 26.0) / 2.0 + 9.0, session.apply_btn.size.y / 2.0)
	var ink := Color(0.12, 0.09, 0.02)
	if head.has("e"):
		Glyph.elem(session.apply_btn, head["e"], c, 9.0, ink)
	elif head.has("pat"):
		Glyph.pat(session.apply_btn, head["pat"], c, 9.0, ink)
	else:
		Glyph.kind(session.apply_btn, head["kind"], c, 9.0, ink)


func _info_sig() -> Array:
	var session: BinduSession = self.session
	if session.card_dim.visible and session.hover_elem >= 0:
		return [Engine.get_process_frames()]  # 새 반응 고리가 숨쉬듯 움직인다: 매 프레임
	var tw: Array = []
	for t in session.towers.get_children():
		tw.append([t.position, t.dir, t.pattern, t.plv, t.elements.duplicate(), t.mods.duplicate()])
	# 전장 좌표(카메라·흔들림)는 쉬는 시간 배지만 따라간다: 웨이브 중엔 빼서 맞을 때 흔들려도 다시 그리지 않게
	var resting := session.phase in [session.Phase.CHOOSE, session.Phase.PLACE, session.Phase.AIM, session.Phase.MOVE, session.Phase.READY]
	return [session.waves_system.new_angles.duplicate(), session.info.size, session.get_canvas_transform() if resting or session.card_dim.visible else Transform2D(), session.ui_root.get_global_transform(), session.info.get_local_mouse_position(), session.tip_pin, session.touch_ui,
		session.phase, session.wave, session.title_label.visible, session.get_tree().paused, session.lanes, Meta.map_id, Meta.line_flip, session.perk_mode, session.cards_hidden, session.picks_left,
		Vary.count(), session.hud_system.hud_sig, session.hud.visible, session.hud.position, session.ui_layout_system._info_blockers(), session.choice_box.visible, session.choice_box.get_global_rect(),
		session.card_dim.visible, session.choice_header.visible, session.choice_header.get_rect(), tw, session.leak_marks, session.wave_kinds, session.wave_info, session.boss_plan,
		session.tap_sel, Meta.card_detail, session.card_dock.panel.visible, session.card_dock.panel.position, session.choice_box.get_child_count(), session.guide_label.visible]
