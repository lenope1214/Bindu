class_name BinduFieldView
extends BinduFeature
## 전장·효과·툴팁 그리기. 예약 콜백은 main의 순서를 따른다.

var place_label_rect := Rect2()
var place_note_rect := Rect2()
var place_note := {}  # 카드 넣는 단계에서 올린 오브젝트 설명 (_draw_place_note)
var fx_k := 1.0  # 터지는 효과 진하기 (효과 줄이기 설정이면 0.5)
var stars := PackedVector3Array()  # 배경 점 (x, y, 밝기)

var tip_orb: Node = null  # 마우스를 올린 구체 (그 구체만 체력 숫자를 보인다)
func _draw_tooltip() -> void:
	var session: BinduSession = self.session
	tip_orb = null
	if session.card_dock != null and session.cards_hidden:
		return  # 전장 넓게 보기에서는 마우스 정보창도 접는다
	# 터치는 마우스를 올려 둘 수 없으니, 눌러서 옮기기 시작한 오브젝트의 정보를 보여 준다
	var touch_move := session.phase == BinduSession.Phase.MOVE and session.touch_ui and session.interaction_system.moving != null
	# 터치로 방향 바꾸기: 손가락은 쏠 쪽에 있으니 그 오브젝트 정보를 함께 보여 준다 ([자세히]로 수치까지)
	var touch_aim := session.phase == BinduSession.Phase.AIM and session.touch_ui and session.interaction_system.moving != null
	if (session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.GAMEOVER, BinduSession.Phase.MOVE, BinduSession.Phase.AIM] and not touch_move and not touch_aim) or session.title_label.visible or session.interaction_system.dragging or session.interaction_system.boxing:
		return
	# 터치는 손을 뗀 자리에 마우스가 남는다: 누르고 3초가 지나면 정보창을 닫는다
	if session.touch_ui and not touch_move and not touch_aim and session.touch_tip_t <= 0.0:
		return
	if session.dps_panel.visible and session.dps_panel.get_global_rect().has_point(session.interaction_system._pointer_screen()):
		return  # DPS 표 위: 표 뒤에 가린 오브젝트 정보창이 뜨지 않게
	var t := session.interaction_system.moving if touch_move or touch_aim else session.interaction_system._tower_at(session.interaction_system._pointer_world())
	# 터치로 [자세히]를 누르면 손가락이 버튼으로 가서 정보창이 사라졌다: 방금 보던 오브젝트를 이어서
	if t == null and session.touch_ui and is_instance_valid(session.tip_tower) and session.detail_btn.visible \
			and session.detail_btn.get_global_rect().has_point(session.interaction_system._pointer_screen()):
		t = session.tip_tower
	if t != null:
		session.tip_tower = t
		if session.card_dock.active():
			return  # 카드 도크 사용 중엔 전장 위를 덮지 않고 오른쪽 설명 칸에 표시한다
	if t == null:
		_draw_orb_tooltip()
		return
	session.tip_frame = Engine.get_process_frames()
	var z: float = _tip_scale()
	var fs := roundi(14 * z)
	var lh := 18.0 * z
	var maxw := minf(620.0 * z, _right_limit() - 24.0)  # 이보다 긴 줄은 접는다 (속성이 많으면 화면 밖으로 나가던 것)
	var lines: Array = []  # [글자, 색]
	var head := t.title()
	var tip := "(클릭: 선택 · 한 번 더 클릭: 방향 · 끌기: 옮기기)" if session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] and not session.perk_mode else ""
	# Shift를 누르고 있으면 공격력·공격 속도·사거리 같은 수치를 자세히
	var detail := _tip_detail_on() and not touch_move
	tip = session.ui_layout_system._th(tip)
	var acts := tip != ""  # 쉬는 시간: 클릭·끌기 안내도
	var ctrl := not session.touch_ui  # 마우스에선 조작 안내를 맨 아래 그림 줄로 (_draw_tip_ctrl)
	if not session.touch_ui:
		tip = "" if not detail else "(Shift 떼기: 돌아가기)"
	if touch_move:
		tip = "(새 자리 누르기: 옮기기 · 취소: 그대로)"
	elif touch_aim:
		tip = "(쏠 쪽 누르기: 방향 확정)"
	if tip != "" and session.ui_font.get_string_size(head + "   " + tip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= maxw:
		lines.append([head + "   " + tip, Color.WHITE])
	else:
		for row in session.onboarding_system._wrap_parts(head, "·", maxw, fs).split("\n"):
			lines.append([row, Color.WHITE])
		if tip != "":
			lines.append([tip, Color(1, 1, 1, 0.6)])
	var share_line := []
	if session.wave_time > 1.0:
		var total := 0.0
		for o in session.towers.get_children():
			total += o.dealt
		var share := " · %d%%" % roundi(t.dealt / total * 100.0) if total > 0.0 and session.towers.get_child_count() > 1 else ""
		share_line = ["%s %s%s" % ["이번 웨이브" if session.phase == BinduSession.Phase.WAVE else "지난 웨이브", Tower.tip_num(t.dealt), share], Color(1, 0.9, 0.5), "rank"]
	if not detail:
		# 기본: 피해·공격 속도·치명타·피해 몫 숫자만 (효과 설명·계산 내역은 자세히에서)
		lines += t.basic_lines()
		var afs: Array = Share.aff(t)["pairs"].map(func(pr): return Elem.aff_label(pr[0], pr[1]))
		if not afs.is_empty():
			lines.append(["상성: " + " · ".join(afs), Color(0.85, 1.0, 0.75)])
		var sts: Array = Share.sites_of(t.eff_now()).map(func(x): return x[2])
		if not sts.is_empty():
			lines.append(["자리: " + " · ".join(sts), Color(0.75, 0.9, 1.0)])
		var smix := Side.mix_name(t)
		if smix != "":
			lines.append(["보조 공격: " + smix, Color(1.0, 0.85, 0.7)])
		if not share_line.is_empty():
			lines.append(share_line)
	else:
		# 자세히: 수치와 계산 내역 → 공격방식·속성·강화·반응 설명 → 버프·피해 몫. 화면을 넘으면 내역 줄부터 줄인다
		var nums: Array = t.detail_lines()
		var desc: Array = []
		desc.append(["%s Lv%d - %s" % [Pat.pname(t.pattern), t.plv, Pat.PATTERNS[t.pattern]["desc"]], Pat.pcolor(t.pattern).lightened(0.2), "p:" + t.pattern])
		var no := Pat.no_mods(t.pattern)
		if not no.is_empty():
			desc.append(["  못 넣는 강화(효과 없음): " + "·".join(no), Color(0.7, 0.7, 0.75)])
		for e in t.order:
			desc.append(["Lv%d %s" % [t.lv(e), Elem.rider(e)], Elem.COLORS[e], "e:%d" % e])
		var ex := t.extras_text()
		if t.mod_count() > 0 and Rules.mod_total < Rules.NO_CAP:
			ex = "강화 %d/%d" % [t.mod_count(), Rules.mod_total] + (" · " + ex if ex != "" else "")
		if ex != "":
			desc.append([ex, Color(1, 0.85, 0.45), "k:mod"])
		var rxs := t.reactions()
		if rxs.size() <= 5:
			for r in rxs:
				desc.append(["%s: %s" % [r["name"], r["desc"]], r["color"], "k:rx"])
		else:
			desc.append(["조합 %d개: %s" % [rxs.size(), ", ".join(rxs.map(func(r): return r["name"]))], Color(1, 0.8, 0.95), "k:rx"])
		for pr in Share.aff(t)["pairs"]:
			desc.append([Elem.aff_text(pr[0], pr[1]), BinduSession.AFF_COL["strong" if pr[2]["strong"] else "weak"], "k:rx"])
		for x in Share.sites_of(t.eff_now()):
			var nd: String = Share.site_desc(x[0], x[1])
			desc.append(["자리 %s%s" % [x[2], ": " + nd if nd != "" else ""], Color(0.75, 0.9, 1.0), "k:rx"])
		if Side.mixed(t):
			desc.append(["보조 공격 %s: %s" % [Side.mix_name(t), Side.mix_desc(t)], Color(1.0, 0.85, 0.7), "k:rx"])
		session.onboarding_system._wind_buffs()  # 쉬는 시간에 새로 놓은 오브젝트도 바로 보이게
		var tail: Array = []
		if t.wind_buff > 0.0:
			tail.append(["바람 버프: 공격 속도 +%d%%" % roundi(t.wind_buff * 100.0), Elem.COLORS[Elem.WIND], "e:%d" % Elem.WIND])
		if not share_line.is_empty():
			tail.append(share_line)
		var avail := floori((_tip_bottom() - _tip_top() - 18.0) / lh)
		var all: Array = lines + nums + desc + tail
		if _tip_rows(all, maxw, fs) > avail:
			# 1) 계산 내역(들여 쓴 흐린 줄)을 뺀다
			nums = nums.filter(func(l): return not (l[0] as String).begins_with("  "))
			desc = desc.filter(func(l): return not (l[0] as String).begins_with("  "))
			all = lines + nums + desc + tail
		if _tip_rows(all, maxw, fs) > avail:
			# 2) 반응·속성 효과를 한 줄씩으로
			var keep: Array = desc.filter(func(l): return not (l.size() > 2 and ((l[2] as String).begins_with("e:") or l[2] == "k:rx")))
			var riders: Array = t.order.map(func(e): return Elem.rider_name(e))
			keep.append(["속성 효과: " + "·".join(riders), Color(0.85, 0.85, 0.9), "k:elem"])
			if not rxs.is_empty():
				keep.append(["조합 %d개: %s" % [rxs.size(), ", ".join(rxs.map(func(r): return r["name"]))], Color(1, 0.8, 0.95), "k:rx"])
			var afs: Array = Share.aff(t)["pairs"].map(func(pr): return Elem.aff_label(pr[0], pr[1]))
			if not afs.is_empty():
				keep.append(["상성: " + " · ".join(afs), Color(0.85, 1.0, 0.75), "k:rx"])
			desc = keep
			all = lines + nums + desc + tail
		lines = all
	# 줄 앞 그림(l[2])은 왼쪽 gut 칸에. 접힌 줄은 첫 줄에만 그림
	var gut := 20.0 * z
	var rows: Array = []
	var w := 0.0
	for l in lines:
		var lw := session.ui_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if lw <= maxw:
			rows.append(l)
			w = maxf(w, lw)
			continue
		var k := 0
		for row in session.onboarding_system._wrap_words(l[0], maxw, fs).split("\n"):
			rows.append([row, l[1], l[2] if l.size() > 2 and k == 0 else ""])
			w = maxf(w, session.ui_font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			k += 1
	lines = rows
	if ctrl and not detail:
		w = maxf(w, (250.0 if acts else 90.0) * z)
	w += gut
	var h := (lines.size() + (1 if ctrl and not detail else 0)) * lh + 10.0
	var vw := session.viewport_system.view_rect()
	var size := vw.end  # 화면 오른쪽 아래 끝 (월드 좌표. 폰은 전장 밖 양옆까지)
	size.y = _tip_bottom()
	var p := t.position + Vector2(28, -h / 2)
	if touch_aim and session.interaction_system._pointer_world().x > t.position.x:
		p.x = t.position.x - 28.0 - (w + 16.0)  # 손가락(쏠 쪽) 반대편에
	p.x = clampf(p.x, vw.position.x + 8, _right_limit() - w - 16)
	var top := _tip_top()
	p.y = clampf(p.y, top if h <= size.y - top - 8.0 else vw.position.y + 8.0, size.y - h - 8)
	# 오른쪽 설명에 밀려 왼쪽으로 오면 오브젝트를 덮는다: 위나 아래로 비킨다
	if Rect2(p, Vector2(w + 16, h)).intersects(Rect2(t.position - Vector2(26, 26), Vector2(52, 52))):
		var above := t.position.y - 30.0 - h
		p.y = above if above >= top else minf(t.position.y + 30.0, size.y - h - 8)
	p = _avoid_cards(Rect2(p, Vector2(w + 16, h)), size)
	# 아래 안내 글·넘기기 표시·[선택지 보기]는 UI라 정보창 위에 그려져 글이 섞인다: 겹치는 동안 옅게
	for c in [session.hint, session.skip_badge, session.hide_btn]:
		if c.visible and c.text != "" and Rect2(p, Vector2(w + 16, h)).intersects(session.get_canvas_transform().affine_inverse() * c.get_global_rect()):
			session.tip_fade[c] = Engine.get_process_frames()
	session.fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(0.05, 0.06, 0.09, 0.92))
	session.fx_layer.draw_rect(Rect2(p, Vector2(w + 16, h)), Color(1, 1, 1, 0.2), false, 1.0)
	for i in lines.size():
		session.fx_layer.draw_string(session.ui_font, p + Vector2(8 + gut, 6 + fs + i * lh), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lines[i][1])
		if lines[i].size() > 2 and lines[i][2] != "":
			_tip_icon(lines[i][2], p + Vector2(8 + gut * 0.45, 6 + i * lh + lh * 0.5), 6.0 * z, lines[i][1])
	if ctrl and not detail:
		_draw_tip_ctrl(p + Vector2(8, 6 + lines.size() * lh), fs, lh, acts)


## 정보창 자세히: Shift를 누르고 있거나 터치 [자세히]. 기본 정보창은 숫자만, 올린 오브젝트는 공격 범위만 그리고
## 별 흡수 둘레·바람 버프 둘레(주변과 주고받는 범위)는 자세히일 때만.
func _tip_detail_on() -> bool:
	var session: BinduSession = self.session
	return Input.is_key_pressed(KEY_SHIFT) or (session.touch_ui and session.tip_detail)


## 자세히일 때 둘레를 그릴 오브젝트: 마우스 아래, 터치는 [자세히]를 누르느라 손가락이 떠나도 정보창의 오브젝트.
func _ring_target() -> Tower:
	var session: BinduSession = self.session
	if not _tip_detail_on():
		return null
	if session.card_dock.active() and session.card_dock.side.visible:
		return session.card_dock.shown_tower
	var h := session.interaction_system._tower_at(session.interaction_system._pointer_world())
	if h == null and session.touch_ui and is_instance_valid(session.tip_tower) and Engine.get_process_frames() - session.tip_frame <= 2:
		h = session.tip_tower
	return h


## 정보창 줄 앞 그림: "p:공격방식" · "e:속성" · "k:카드 종류" · 그 밖은 Glyph.ui.
func _tip_icon(id: String, c: Vector2, s: float, col: Color) -> void:
	var session: BinduSession = self.session
	match id.left(2):
		"p:": Glyph.pat(session.fx_layer, id.substr(2), c, s, col)
		"e:": Glyph.elem(session.fx_layer, int(id.substr(2)), c, s)
		"k:": Glyph.kind(session.fx_layer, id.substr(2), c, s, col)
		_: Glyph.ui(session.fx_layer, id, c, s, Color(col, 1.0))



## 정보창 글 배율: 폰은 화면이 작아 다른 글보다 14px 정보창이 유난히 작게 읽혔다
func _tip_scale() -> float:
	var session: BinduSession = self.session
	return Meta.ui_scale * (1.2 if session.viewport_system._phone() else 1.0)


## 정보창 맨 아래 조작 줄 (마우스): [왼쪽 단추] 방향 · [끌기] 옮기기 · [Shift] 자세히.
func _draw_tip_ctrl(at: Vector2, fs: int, lh: float, acts: bool) -> void:
	var session: BinduSession = self.session
	var z: float = _tip_scale()
	var f := maxi(11, fs - 2)
	var x := at.x
	var y := at.y + lh * 0.5
	var dim := Color(1, 1, 1, 0.6)
	var items := [["click", "선택"], ["drag", "옮기기"], ["Shift", "자세히"]] if acts else [["Shift", "자세히"]]
	for it in items:
		if it[0] == "Shift":
			var kw := session.ui_font.get_string_size("Shift", HORIZONTAL_ALIGNMENT_LEFT, -1, f - 1).x + 8.0
			Glyph.keycap(session.fx_layer, session.ui_font, Vector2(x + kw, y - (f + 4) * 0.5), "Shift", f - 1)
			x += kw + 4.0
		else:
			Glyph.ui(session.fx_layer, it[0], Vector2(x + 6.0 * z, y), 7.0 * z, dim)
			x += 16.0 * z
		session.fx_layer.draw_string(session.ui_font, Vector2(x, y + f * 0.36), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, f, dim)
		x += session.ui_font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, f).x + 12.0 * z


## 정보창 줄들을 maxw로 접었을 때 줄 수.
func _tip_rows(lines: Array, maxw: float, fs: int) -> int:
	var session: BinduSession = self.session
	var n := 0
	for l in lines:
		n += 1 if session.ui_font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= maxw else session.onboarding_system._wrap_words(l[0], maxw, fs).count("\n") + 1
	return n


## 정보창을 놓을 수 있는 위쪽 끝: 점수 줄 아래 (점수 줄이 정보창 첫 줄을 덮던 것).
func _tip_top() -> float:
	var session: BinduSession = self.session
	if not session.hud.visible:
		return 8.0
	return (session.get_canvas_transform().affine_inverse() * session.hud.get_global_rect()).end.y + 6.0


## 정보창을 놓을 수 있는 아래쪽 끝: 화면 끝, 터치 [자세히]·[간단히] 버튼이 떠 있으면 그 위 (정보창이 버튼을 덮던 것).
func _tip_bottom() -> float:
	var session: BinduSession = self.session
	var b := session.viewport_system.view_rect().end.y
	if session.touch_ui and session.detail_btn != null and session.detail_btn.visible:
		b = minf(b, (session.get_canvas_transform().affine_inverse() * session.detail_btn.get_global_rect()).position.y - 6.0)
	return b


## 글자를 놓을 수 있는 오른쪽 끝: 오른쪽 설명이 떠 있으면 그 앞까지 (설명이 글자를 가린다).
func _right_limit() -> float:
	var session: BinduSession = self.session
	var r := session.viewport_system.view_rect().end.x - 8.0
	if session.legend.visible:
		r = minf(r, (session.get_canvas_transform().affine_inverse() * session.legend.get_global_rect()).position.x - 8.0)
	return r


## 선택지 카드가 떠 있으면 툴팁이 카드 뒤에 가려지지 않게 위나 아래로 비킨다.
func _avoid_cards(r: Rect2, size: Vector2) -> Vector2:
	var session: BinduSession = self.session
	if not session.choice_box.visible or session.choice_box.get_child_count() == 0 or session.cards_hidden:
		return r.position
	var inv := session.get_canvas_transform().affine_inverse()
	var cr: Rect2 = inv * session.choice_box.get_global_rect()
	for b in [session.reroll_btn, session.hide_btn, session.skip_btn, session.skip_n_btn]:
		if b.visible:
			cr = cr.merge(inv * b.get_global_rect())
	cr = cr.grow(6.0)
	if not cr.intersects(r):
		return r.position
	var up := cr.position.y - r.size.y
	var down := cr.end.y
	if up >= session.viewport_system.view_rect().position.y + 8.0 and (r.get_center().y < cr.get_center().y or down + r.size.y > size.y - 8.0):
		return Vector2(r.position.x, up)
	if down + r.size.y <= size.y - 8.0:
		return Vector2(r.position.x, down)
	return r.position


## 마우스를 올린 구체의 체력·상태.
func _draw_orb_tooltip() -> void:
	var session: BinduSession = self.session
	var m := session.interaction_system._pointer_world()
	# 작은 구체도 잡기 쉽게 최소 14 안, 여럿이면 가장 가까운 것
	var o: Orb = null
	var bd := INF
	for x in session.live_orbs:
		if not is_instance_valid(x) or x.hp <= 0.0:
			continue
		var d: float = x.position.distance_to(m)
		if d <= maxf(x.radius() + 4.0, 14.0) and d < bd:
			o = x
			bd = d
	tip_orb = o
	if o:
		var kinds := ["구체", "빠른 구체", "단단한 구체", "보스"]
		var parts := PackedStringArray([kinds[o.kind], "체력 %d/%d" % [ceili(o.hp), roundi(o.max_hp)]])
		if o.shield > 0.0: parts.append("보호막 %d" % ceili(o.shield))
		if o.splits: parts.append("분열")
		if o.jam != "": parts.append(BinduSession.JAM_NAMES[o.jam])
		if o.amp.has("brand"): parts.append("낙인(받는 피해 +%d%%)" % roundi(Rules.t("skill_brand_amp") * 100))
		if o.burn_t > 0.0: parts.append("화상")
		if o.poison_t > 0.0: parts.append("중독")
		if o.root_immune > 0.0: parts.append("기절 면역")
		if o.vuln_t > 0.0: parts.append("받는 피해↑ +30%")
		if o.slow_timer > 0.0: parts.append("감속")
		if o.frozen_t > 0.0: parts.append("얼림")
		if o.tune_t > 0.0: parts.append("3타 음파 %d/3" % int(o.ring))
		if o.echo_t > 0.0: parts.append("피해 되풀이 %d%%" % roundi(o.echo_frac * 100))
		if o.soul_t > 0.0: parts.append("혼불 소환")
		if o.silence_t > 0.0: parts.append("침묵")
		if o.resist_e >= 0: parts.append("%s 저항" % Elem.NAMES[o.resist_e])
		if o.sturdy: parts.append("굳셈(밀기·감속·기절·냉기 절반)")
		if o.vine > 0.0: parts.append("덩굴 %d/3" % int(o.vine))
		if not o.amp.is_empty():
			# 받는 피해 증가 (낙인 등, 곱해서 하나로)
			var k := 1.0
			for v in o.amp.values():
				k *= 1.0 + v[0]
			if k > 1.005:
				parts.append("받는 피해↑ +%d%%" % roundi((k - 1.0) * 100.0))
		var fs := roundi(14 * _tip_scale())
		# 상태가 많으면(보스·후반) 한 줄이 화면·오른쪽 설명 밖으로 나간다: 들어가는 만큼씩 줄을 나눈다
		var maxw := minf(_right_limit() - 32.0, 620.0 * _tip_scale())
		var rows: Array[String] = [""]
		for part in parts:
			var cand: String = part if rows[-1] == "" else rows[-1] + " · " + part
			if rows[-1] != "" and session.ui_font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
				rows.append(part)
			else:
				rows[-1] = cand
		var w := 0.0
		for r in rows:
			w = maxf(w, session.ui_font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var lh := fs + 6.0
		var bh := lh * rows.size() + 4.0
		var p: Vector2 = o.position + Vector2(-w / 2 - 8, -o.radius() - 16 - bh)
		p.x = clampf(p.x, session.viewport_system.view_rect().position.x + 8.0, maxf(session.viewport_system.view_rect().position.x + 8.0, _right_limit() - w - 16))
		p.y = maxf(p.y, _tip_top())
		session.fx_layer.draw_rect(Rect2(p, Vector2(w + 16, bh)), Color(0.05, 0.06, 0.09, 0.9))
		for i in rows.size():
			session.fx_layer.draw_string(session.ui_font, p + Vector2(8, fs + 3 + lh * i), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## 중앙 점 스킨: 눈은 가장 가까운 구체를 본다, 태양은 빛살이 돈다.
func _draw_core_skin(c: Vector2, col: Color, now: float) -> void:
	var session: BinduSession = self.session
	match Meta.core_skin:
		"eye":
			var look := Vector2.ZERO
			var best := INF
			for o in session.orbs.get_children():
				var d2: float = (o.position - c).length_squared()
				if d2 < best:
					best = d2
					look = (o.position - c).normalized()
			session.draw_circle(c, BinduSession.CORE_RADIUS * 0.62, Color(0.1, 0.12, 0.18))
			session.draw_circle(c + look * BinduSession.CORE_RADIUS * 0.3, BinduSession.CORE_RADIUS * 0.3, Color(0.55, 0.85, 1.0))
			session.draw_circle(c + look * BinduSession.CORE_RADIUS * 0.36, BinduSession.CORE_RADIUS * 0.12, Color(0.02, 0.02, 0.05))
		"sun":
			for i in 10:
				var a := now * 0.6 + i * TAU / 10.0
				var d := Vector2.from_angle(a)
				session.draw_colored_polygon(PackedVector2Array([
					c + d * (BinduSession.CORE_RADIUS + 14.0),
					c + d.rotated(0.18) * (BinduSession.CORE_RADIUS - 1.0),
					c + d.rotated(-0.18) * (BinduSession.CORE_RADIUS - 1.0),
				]), Color(1.0, 0.85, 0.35, 0.85))
			session.draw_circle(c, BinduSession.CORE_RADIUS * 0.7, Color(1.0, 0.9, 0.5).lerp(col, 0.4))
		"crown":
			# 왕관 (보스 사냥꾼): 위로 솟은 다섯 뾰족
			var w := BinduSession.CORE_RADIUS * 0.8
			var pts := PackedVector2Array([c + Vector2(-w, w * 0.45), c + Vector2(w, w * 0.45)])
			for i in 5:
				var x := w - i * w * 0.5
				pts.append(c + Vector2(x, -w * (0.75 if i % 2 == 0 else 0.25)))
				if i < 4:
					pts.append(c + Vector2(x - w * 0.25, w * 0.05))
			session.draw_colored_polygon(pts, Color(1.0, 0.82, 0.3).lerp(col, 0.25))
			for i in 3:
				session.draw_circle(c + Vector2(-w + i * w, -w * 0.75), 2.5, Color(1, 0.4, 0.45))
		"galaxy":
			# 은하 (신화 업적 '빈두'): 도는 나선 팔 두 개
			session.draw_circle(c, BinduSession.CORE_RADIUS * 0.35, Color(1, 0.95, 0.85))
			for arm in 2:
				for i in 14:
					var t := i / 14.0
					var a := now * 0.8 + arm * PI + t * 3.2
					var d := BinduSession.CORE_RADIUS * (0.3 + 0.75 * t)
					session.draw_circle(c + Vector2.from_angle(a) * d, 2.6 * (1.0 - t * 0.6), Color.from_hsv(fmod(0.6 + t * 0.4 + now * 0.05, 1.0), 0.55, 1.0, 0.9 - t * 0.5))

## 일식 발동 때 화면 전체 연출(어둡게·큰 고리)을 이 오브젝트가 맡을지. 2.5초에 한 번만 맡기고 나머지는 오브젝트 둘레만 작게.
## 연출만 고르고 피해·발동 시각은 바꾸지 않는다
func eclipse_screen() -> bool:
	var session: BinduSession = self.session
	if session.eclipse_cd > 0.0:
		return false
	session.eclipse_flash = 0.6
	session.eclipse_cd = 2.5
	return true


## 효과 줄이기(설정): 장판은 절반 진하기, 25개를 넘게 겹치면 그만큼 더 옅게 (최소 20%). 터지는 효과는 절반.
func _soften_fx() -> void:
	var session: BinduSession = self.session
	fx_k = 0.5 if Meta.fx_low else 1.0
	var soft := session.zones.get_children().filter(func(z): return z.kind in Zone.SOFT)
	var a := 1.0
	if Meta.fx_low:
		a = maxf(0.2, 0.5 * minf(1.0, 25.0 / maxf(soft.size(), 1.0)))
	# 피해 몫이 작은 오브젝트의 탄·장판은 옅게 (가장 센 오브젝트 대비 비율만큼, 아래 버튼 줄에서 세기 조절).
	# 웨이브 첫머리(피해가 아직 적을 때)는 지난 값을 유지하고, 바뀔 때는 천천히 따라간다
	var str_k: float = BinduSession.FX_DPS[Meta.fx_dps]
	var top := 0.0
	for t in session.towers.get_children():
		top = maxf(top, t.dealt)
	for t in session.towers.get_children():
		var want := 1.0
		if str_k > 0.0 and session.towers.get_child_count() > 1:
			if top < 30.0:
				want = t.fx_a
			else:
				want = maxf(0.15, 1.0 - str_k * (1.0 - t.dealt / top))
		t.fx_a = lerpf(t.fx_a, want, 0.1)
	for z in session.zones.get_children():
		var za: float = a if z.kind in Zone.SOFT else 1.0
		if is_instance_valid(z.owner_tower):
			za *= z.owner_tower.fx_a
		if not is_equal_approx(z.modulate.a, za):
			z.modulate.a = za
	for p in session.projectiles.get_children():
		var pa: float = p.owner_tower.fx_a if is_instance_valid(p.owner_tower) else 1.0
		if absf(p.modulate.a - pa) > 0.02:
			p.modulate.a = pa


## 전장 밖(폰의 양옆·태블릿의 위아래)은 어둡게 덮고 경계선을 긋는다. 그쪽 구체는 아직 맞지 않고 오브젝트도 놓을 수 없다.
func _draw_margins(vw: Rect2) -> void:
	var session: BinduSession = self.session
	var ar := session.viewport_system.arena()
	if vw.size.x <= ar.size.x + 1.0 and vw.size.y <= ar.size.y + 1.0:
		return
	var col := Color(0, 0, 0, 0.45)
	if vw.position.x < ar.position.x:
		session.fx_layer.draw_rect(Rect2(vw.position.x, vw.position.y, ar.position.x - vw.position.x, vw.size.y), col)
		session.fx_layer.draw_rect(Rect2(ar.end.x, vw.position.y, vw.end.x - ar.end.x, vw.size.y), col)
	if vw.position.y < ar.position.y:
		session.fx_layer.draw_rect(Rect2(ar.position.x, vw.position.y, ar.size.x, ar.position.y - vw.position.y), col)
		session.fx_layer.draw_rect(Rect2(ar.position.x, ar.end.y, ar.size.x, vw.end.y - ar.end.y), col)
	session.fx_layer.draw_rect(ar, Color(1, 1, 1, 0.08), false, 1.0)


func _draw_fx(preview := false) -> void:
	var session: BinduSession = self.session
	if not preview:
		var vw := session.viewport_system.view_rect()
		var o := vw.position
		var vs := vw.size
		_draw_margins(vw)
		_draw_place_note(session.fx_layer)
		session.abilities_system._draw_skill_fx()
		for i in 6:
			var w := 14.0 * (6 - i)
			var col := Color(0, 0, 0, 0.05)
			session.fx_layer.draw_rect(Rect2(o.x, o.y, vs.x, w), col)
			session.fx_layer.draw_rect(Rect2(o.x, o.y + vs.y - w, vs.x, w), col)
			session.fx_layer.draw_rect(Rect2(o.x, o.y, w, vs.y), col)
			session.fx_layer.draw_rect(Rect2(o.x + vs.x - w, o.y, w, vs.y), col)
		if session.phase == BinduSession.Phase.GAMEOVER or session.title_label.visible:
			session.fx_layer.draw_rect(vw, Color(0, 0, 0, 0.6))
		_draw_eclipse(vw)
		# 중앙 위험: 화면 테두리가 붉게 맥박친다 (25% 이하는 더 진하고 빠르게). 배속과 상관없이 계속 보인다
		if session.danger_lv > 0 and session.phase != BinduSession.Phase.GAMEOVER and not session.title_label.visible:
			var t := Time.get_ticks_msec() / 1000.0
			var beat := 0.5 + 0.5 * sin(t * (3.0 if session.danger_lv == 1 else 7.0))
			var a := (0.05 + 0.05 * beat) if session.danger_lv == 1 else (0.09 + 0.09 * beat)
			var dc := Color(1, 0.6, 0.25) if session.danger_lv == 1 else Color(1, 0.15, 0.2)
			for i in 6:
				var w := 10.0 * (6 - i)
				var col := Color(dc, a)
				session.fx_layer.draw_rect(Rect2(o.x, o.y, vs.x, w), col)
				session.fx_layer.draw_rect(Rect2(o.x, o.y + vs.y - w, vs.x, w), col)
				session.fx_layer.draw_rect(Rect2(o.x, o.y, w, vs.y), col)
				session.fx_layer.draw_rect(Rect2(o.x + vs.x - w, o.y, w, vs.y), col)
	if preview:
		_draw_eclipse(session.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, session.get_viewport_rect().size))
	for a in session.arcs:
		session.fx_layer.draw_line(a[0], a[1], Color(Elem.COLORS[Elem.ELECTRIC], fx_k), 2.0)
	var sc: Color = Elem.COLORS[Elem.SOUND]
	for q in session.pulses:
		var k: float = 1.0 - q[2] / 0.3
		session.fx_layer.draw_arc(q[0], q[1] * (0.4 + 0.6 * k), 0, TAU, 32, Color(sc, (1.0 - k) * fx_k), 3.0)
		session.fx_layer.draw_arc(q[0], q[1] * (0.2 + 0.5 * k), 0, TAU, 24, Color(sc, 0.6 * (1.0 - k) * fx_k), 2.0)
	for q in session.beams:
		var bk: float = q[3] / 0.2 * fx_k
		session.fx_layer.draw_line(q[0], q[1], Color(q[2], 0.35 * bk), 9.0)
		session.fx_layer.draw_line(q[0], q[1], Color(q[2], 0.9 * bk), 3.0)
	var ec: Color = Elem.COLORS[Elem.ELECTRIC]
	for b in session.bolts:
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
		var al := clampf(b[1] / 0.22, 0.0, 1.0) * fx_k
		session.fx_layer.draw_polyline(pts, Color(ec, 0.35 * al), 9.0)
		session.fx_layer.draw_polyline(pts, Color(ec, al), 3.5)
		session.fx_layer.draw_polyline(pts, Color(1, 1, 1, al), 1.2)
		for q in src.slice(1):
			session.fx_layer.draw_circle(q, 6.0, Color(ec, 0.5 * al))
	for p in session.particles:
		session.fx_layer.draw_circle(p[0], p[4] * clampf(p[2] / 0.4, 0.2, 1.0), Color(p[3], p[3].a * fx_k))
	for p in session.popups:
		var size := 22 if p[4] else 14
		var a := clampf(p[2] / 0.3, 0.0, 1.0)
		# 숫자는 기본 글꼴, 한글이 든 글자(콤보·최다 피해)는 한글 글꼴
		var f: Font = ThemeDB.fallback_font if p[1].is_valid_int() else session.ui_font
		session.fx_layer.draw_string(f, p[0] + Vector2(1, 1), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * a))
		session.fx_layer.draw_string(f, p[0], p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(p[3], a))
	if preview:
		return
	# 보스 체력 줄·콤보 상자는 화면에 붙은 글이라 화면 좌표로 그린다 (확대해도 크기·자리 그대로)
	session.fx_layer.draw_set_transform_matrix(session.get_canvas_transform().affine_inverse())
	_draw_boss_bar()
	_draw_combo()
	session.fx_layer.draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_tooltip()



## 일식 화면 연출도 미리보기 전장 안에서 같은 진하기·시간으로 표시한다.
func _draw_eclipse(vw: Rect2) -> void:
	var session: BinduSession = self.session
	if session.eclipse_flash > 0.0:
		# 단번에 어두워지지 않게 0.1초 동안 천천히 어두워졌다가 풀린다
		var ef := session.eclipse_flash / 0.6
		var env := minf((1.0 - ef) / 0.15, 1.0) * ef
		session.fx_layer.draw_rect(vw, Color(0.1, 0.0, 0.15, 0.22 * env))

## 보스가 있으면 화면 위 가운데에 체력 막대 (여럿이면 합계). 화면 흔들림을 따라가지 않게 카메라 흔들림만큼 되돌린다.
func _draw_boss_bar() -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.WAVE:
		return
	var hp := 0.0
	var mx := 0.0
	var n := 0
	for o in session.orbs.get_children():
		if o.kind == Orb.Kind.BOSS and o.hp > 0.0:
			hp += o.hp
			mx += o.max_hp
			n += 1
	if n == 0:
		return
	var w := 300.0
	# 위쪽 점수 줄(바탕 상자) 바로 아래. 특성 줄이 늘면 같이 내려간다
	var p := Vector2(session.get_viewport_rect().size.x / 2.0 - w / 2.0, session.ui_root.position.y + (session.hud.position.y + session.hud.size.y) * session.ui_root.scale.y + 20.0)
	session.fx_layer.draw_rect(Rect2(p, Vector2(w, 10)), Color(0, 0, 0, 0.6))
	session.fx_layer.draw_rect(Rect2(p, Vector2(w * clampf(hp / mx, 0.0, 1.0), 10)), Color(1, 0.3, 0.4))
	session.fx_layer.draw_rect(Rect2(p, Vector2(w, 10)), Color(1, 1, 1, 0.3), false, 1.0)
	var txt := "보스%s  %d / %d" % [" x%d" % n if n > 1 else "", ceili(hp), ceili(mx)]
	session.fx_layer.draw_string(session.ui_font, p + Vector2(1, -3), txt, HORIZONTAL_ALIGNMENT_CENTER, w, Meta.fs(14), Color(0, 0, 0, 0.8))
	session.fx_layer.draw_string(session.ui_font, p + Vector2(0, -4), txt, HORIZONTAL_ALIGNMENT_CENTER, w, Meta.fs(14), Color(1, 0.85, 0.88))


## 콤보 점수 배율: 콤보마다 +10%, 콤보 20부터 x3.
func combo_mul() -> float:
	var session: BinduSession = self.session
	return 1.0 + 0.1 * mini(session.combo, 20)


## 콤보 상자 자리 (화면 좌표, 높이는 끊김·진행 중 큰 쪽). DPS 표를 옮겨 둘 때도 이 자리를 피한다.
func _combo_rect() -> Rect2:
	var session: BinduSession = self.session
	var w := 180.0
	var p := Vector2(session.ui_root.position.x + session.ui_root.size.x * session.ui_root.scale.x - 10.0 - w, session.ui_root.position.y + 40.0 * session.ui_root.scale.y + 8.0)
	if session.legend.visible:
		p.y = session.legend.get_global_rect().end.y + 8.0
	return Rect2(p, Vector2(w, 64))


## 오른쪽 위(설명 버튼 아래) 콤보 상자: 콤보·점수 배율·남은 유지 시간·더 얻은 점수.
## 콤보는 웨이브 중에만 쌓이고(쉬는 시간엔 멈춰 다음 웨이브로 이어짐), 웨이브 중엔 설명 글이 꺼져 있어 이 자리가 빈다.
func _draw_combo() -> void:
	var session: BinduSession = self.session
	if session.title_label.visible or session.phase == BinduSession.Phase.GAMEOVER:
		return
	var live := session.combo_t > 0.0 and session.combo >= 2 and session.phase == BinduSession.Phase.WAVE  # 쉬는 시간엔 그 자리에 설명 글이 뜬다
	if not live and session.combo_end[2] <= 0.0:
		return
	var w := 180.0
	var p := _combo_rect().position
	if not live:
		var a: float = clampf(session.combo_end[2] / 0.5, 0.0, 1.0)
		# 끊김: 콤보 그림 + 숫자(빨강, 줄 그음) + 얻은 점수
		session.fx_layer.draw_rect(Rect2(p, Vector2(w, 40)), Color(0, 0, 0, 0.55 * a))
		var rc := Color(1, 0.6, 0.5, a)
		Glyph.ui(session.fx_layer, "combo", p + Vector2(20, 20), 10.0, rc)
		var ns := str(session.combo_end[0])
		var nw := session.ui_font.get_string_size(ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		session.fx_layer.draw_string(session.ui_font, p + Vector2(36, 28), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, rc)
		session.fx_layer.draw_line(p + Vector2(34, 21), p + Vector2(38 + nw, 21), rc, 2.0)
		Icons.draw(session.fx_layer, "score", p + Vector2(w - 78, 20), 7.0, Color(1, 0.9, 0.6, a))
		session.fx_layer.draw_string(session.ui_font, p + Vector2(w - 68, 25), "+" + session.num(session.combo_end[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.6, a))
		return
	var maxed := session.combo >= 20
	var now := Time.get_ticks_msec() / 1000.0
	var col := Color(1, 0.85, 0.2) if maxed else Color(1, 1, 1).lerp(Color(1, 0.6, 0.25), session.combo / 20.0)
	# 글 대신: [콤보 그림] 숫자 · 배율, 줄어드는 유지 막대, [별] 콤보로 얻은 점수
	session.fx_layer.draw_rect(Rect2(p, Vector2(w, 62)), Color(0, 0, 0, 0.6))
	if maxed:
		# x3: 금색 테두리가 맥박치고, 닿은 순간엔 크게 반짝인다
		var glow := 0.45 + 0.25 * sin(now * 6.0) + session.combo_max_flash
		session.fx_layer.draw_rect(Rect2(p, Vector2(w, 62)), Color(1, 0.85, 0.2, clampf(glow, 0.0, 1.0)), false, 2.0 + 3.0 * session.combo_max_flash)
	Glyph.ui(session.fx_layer, "combo", p + Vector2(20, 20), 11.0, col)
	session.fx_layer.draw_string(session.ui_font, p + Vector2(38, 30), str(session.combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
	var mt := "×3 최대" if maxed else "×%.1f" % combo_mul()
	session.fx_layer.draw_string(session.ui_font, p + Vector2(0, 27), mt, HORIZONTAL_ALIGNMENT_RIGHT, w - 10.0, 16, col)
	# 남은 유지 시간: 다 줄어들기 전에 다음 구체를 잡아야 이어진다
	var k := session.combo_t / BinduSession.COMBO_KEEP
	session.fx_layer.draw_rect(Rect2(p + Vector2(10, 38), Vector2(w - 20, 5)), Color(1, 1, 1, 0.15))
	session.fx_layer.draw_rect(Rect2(p + Vector2(10, 38), Vector2((w - 20) * k, 5)), Color(1, 0.35, 0.3) if k < 0.35 else col)
	Icons.draw(session.fx_layer, "score", p + Vector2(17, 52), 6.0, Color(1, 0.9, 0.6))
	session.fx_layer.draw_string(session.ui_font, p + Vector2(28, 57), "+" + session.num(session.combo_bonus), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.6))


## 얼음 탄이 깨지며 파편 3개.
func _shatter(p: Projectile) -> void:
	var session: BinduSession = self.session
	if not is_instance_valid(p.owner_tower):
		return
	for a in [-0.6, 0.0, 0.6]:
		var f := session.spawning_system.spawn_proj(p.owner_tower, "frag", p.level, p.vel.normalized().rotated(a))
		f.position = p.position + p.vel.normalized() * 14.0
		f.hit = p.hit.duplicate()
		f.src = p.src


# ---------- 그리기 ----------

func _draw() -> void:
	var session: BinduSession = self.session
	place_label_rect = Rect2()
	var size := Meta.FIELD
	var vw := session.viewport_system.view_rect()
	var mp: Dictionary = Meta.MAPS[Meta.map_id]
	session.draw_rect(vw, mp["bg"])
	var c := session.viewport_system.core()
	var now := Time.get_ticks_msec() / 1000.0
	# 전장 바깥(폰의 양옆·태블릿의 위아래)은 같은 별을 이어 붙여 채운다
	var tiles: Array[Vector2] = [Vector2.ZERO]
	if vw.position.x < 0.0:
		tiles.append_array([Vector2(-size.x, 0), Vector2(size.x, 0)])
	if vw.position.y < 0.0:
		tiles.append_array([Vector2(0, -size.y), Vector2(0, size.y)])
	for st in stars:
		var col := Color(1, 1, 1, st.z * (0.7 + 0.3 * sin(now * 1.3 + st.x)))
		for tl in tiles:
			var sp := Vector2(st.x, st.y) + tl
			if tl == Vector2.ZERO or vw.has_point(sp):
				session.draw_circle(sp, 1.2, col)
	if Meta.map_id == "line":
		_draw_line_map(size, mp, now)
	else:
		var rc: Color = mp["ring"]
		for i in range(1, 5):
			session.draw_arc(c, i * 110.0, 0, TAU, 64, Color(rc, rc.a * 0.5), 1.0)  # 오브젝트·효과가 많아지면 거슬려 옅게
	# 중앙 점: 체력이 줄수록 붉어지고, 맞으면 번쩍인다
	session.core_disp = lerpf(session.core_disp, float(maxi(session.core_hp, 0)), 0.1)
	var frac := session.core_disp / session.core_max
	var core_col := Color(1, 1, 1).lerp(Color(1, 0.25, 0.3), 1.0 - frac)
	var beat := 0.5 + 0.5 * sin(now * (2.0 + 4.0 * (1.0 - frac)))
	for i in 4:
		session.draw_circle(c, BinduSession.CORE_RADIUS + 6.0 + i * 7.0 + beat * 4.0, Color(core_col, 0.05 + 0.25 * session.core_flash))
	session.draw_circle(c, BinduSession.CORE_RADIUS, core_col.lerp(Color.WHITE, session.core_flash * 2.0))
	_draw_core_skin(c, core_col, now)
	_draw_core_guard(c, now)
	# 체력이 줄면 금이 간다
	var cracks := session.core_max - maxi(session.core_hp, 0)
	for i in mini(cracks, 8):
		var a := i * 2.39
		var p1 := c + Vector2(cos(a), sin(a)) * BinduSession.CORE_RADIUS * 0.2
		var p2 := c + Vector2(cos(a + 0.3), sin(a + 0.3)) * BinduSession.CORE_RADIUS * 0.95
		session.draw_line(p1, p2, Color(0.3, 0.05, 0.08, 0.8), 1.5)
	session.draw_arc(c, BinduSession.CORE_RADIUS + 5.0, -PI / 2, -PI / 2 + TAU * frac, 32, Color(1, 1, 1, 0.6), 2.0)
	if session.title_label.visible:
		# 시작 화면: 중앙 점(체력 고리 포함)이 메뉴 글자 뒤로 비치지 않게 배경을 어둡게
		session.draw_rect(vw, Color(0, 0, 0, 0.6))

	# 구체 진입 방향 표시
	var vr := session.viewport_system.arena()
	for a in ([] if Meta.map_id == "line" else session.lanes):
		var d := Vector2(cos(a), sin(a))
		var edge := _edge_point(c, d)
		var path := PackedVector2Array()
		if Meta.map_id == "spiral":
			# 나선: 화면 밖에서 돌며 들어오므로, 실제로 화면에 들어오는 자리에 화살표를 둔다
			for q in session.spawning_system._orb_path(a):
				if not path.is_empty() or vr.has_point(q):
					path.append(q)
			if path.size() >= 2:
				edge = path[0]
				d = (path[0] - path[1]).normalized()
		var tip := edge - d * 18.0 - d * 6.0 * sin(now * 4.0)
		var col := Color(1, 0.3, 0.35, 0.9 if session.phase != BinduSession.Phase.WAVE else 0.35)
		session.field_overlay_system._draw_lane_fan(a, session.lane_spread(session.wave if session.phase == BinduSession.Phase.WAVE else session.wave + 1), now)
		session.draw_colored_polygon(PackedVector2Array([
			tip - d * 22.0,
			tip + d.orthogonal() * 12.0,
			tip - d.orthogonal() * 12.0,
		]), col)
		# 길 한 줄(나선 미리보기·흐르는 점)은 부채꼴(_draw_lane_fan)이 대신한다: 한 줄로 그리면 초보가 그 선만 막았다

	session.menu_system._draw_map_rule(c, now)
	session.field_overlay_system._draw_boss_path(now)
	session.field_overlay_system._draw_wind_rings()
	session.field_overlay_system._draw_star_rings()
	# 누수: 구체가 들어온 화면 가장자리가 붉게 번진다 (어느 길목이 뚫렸는지)
	for lf in session.leak_flash:
		var f: float = lf[1] / 1.2
		for k in 4:
			session.draw_circle(lf[0], 40.0 + k * 34.0, Color(1, 0.15, 0.2, 0.16 * f * (1.0 - k * 0.22)))

	var mpos := session.interaction_system._pointer_world()
	if session.card_dock.active():
		var preview := session.card_dock.preview_card()
		if not preview.is_empty():
			for t: Tower in session.towers.get_children():
				if not session.card_dock.target_ok(t, preview):
					continue
				var fresh: Array = Elem.new_reactions(t.eff_now(), preview["e"]) if preview["type"] == "elem" else []
				var col: Color = fresh[0]["color"] if not fresh.is_empty() else Color(0.65, 0.85, 1.0, 0.7)
				var radius := Tower.RADIUS + (15.0 + 3.0 * sin(now * 6.7) if not fresh.is_empty() else 7.0)
				session.draw_arc(t.position, radius, 0, TAU, 40, col, 3.0 if not fresh.is_empty() else 1.5)
	elif session.phase == BinduSession.Phase.CHOOSE and session.hover_elem >= 0:
		var pulse2 := 0.5 + 0.5 * sin(now * 6.7)
		var hcard := {"type": "elem", "e": session.hover_elem}
		for t in session.towers.get_children():
			if not t.can_take(hcard):  # 속성 종류 상한에 걸려 못 넣는 오브젝트는 강조하지 않음
				continue
			var fresh := Elem.new_reactions(t.eff_now(), session.hover_elem)
			if not fresh.is_empty():
				session.draw_arc(t.position, Tower.RADIUS + 10.0 + pulse2 * 4.0, 0, TAU, 32, Color(fresh[0]["color"], 0.9), 3.0)
	if session.phase == BinduSession.Phase.PLACE and not session.picked.is_empty():
		var col := session.cards_system._card_color(session.picked)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		var is_elem: bool = session.picked["type"] == "elem"
		# 넣을 수 있는 오브젝트: 숨 쉬는 빛 + 고리 + 도는 점선 고리 (속성 카드는 새 반응이 생기면 그 반응 색).
		# 넣을 수 없는 오브젝트는 _update_place_dim이 흐리게 하고 누를 수 없다 (작은 ✕)
		var spin := Time.get_ticks_msec() / 1000.0 * 1.6
		var target := session.interaction_system._tower_at(mpos)
		place_note = {}
		var pv: Array = target.preview(session.picked) if target and session.interaction_system._place_ok(target) else []
		var refuse: bool = target != null and (pv.is_empty() or (pv[0] as PackedStringArray)[0] == "넣을 수 없음")
		for t in session.towers.get_children():
			if not session.interaction_system._place_ok(t):
				if t != target:
					session.draw_line(t.position + Vector2(-7, -7), t.position + Vector2(7, 7), Color(1, 0.35, 0.35, 0.55), 2.5)
					session.draw_line(t.position + Vector2(7, -7), t.position + Vector2(-7, 7), Color(1, 0.35, 0.35, 0.55), 2.5)
				continue
			if t == target:
				continue  # 올린 오브젝트는 아래에서 따로 (흰 고리 또는 넣을 수 없음 표시)
			var hc := col
			var strong := not is_elem
			if is_elem:
				var fresh := Elem.new_reactions(t.eff_now(), session.picked["e"])
				if not fresh.is_empty():
					hc = fresh[0]["color"]
					strong = true
			if not strong or target != null:
				# 속성 카드는 빈 곳에 새로 놓을 수도 있어 겹치기만 옅게 표시.
				# 오브젝트 하나에 올려 둔 동안엔 나머지는 얇은 고리만 (빛·도는 고리가 겹쳐 올린 것이 묻히지 않게)
				session.draw_arc(t.position, Tower.RADIUS + 9.0, 0, TAU, 32, Color(hc, 0.55 if strong else 0.35), 1.5)
				continue
			session.draw_circle(t.position, Tower.RADIUS + 14.0 + pulse * 4.0, Color(hc, 0.07 + 0.07 * pulse))
			session.draw_arc(t.position, Tower.RADIUS + 10.0 + pulse * 4.0, 0, TAU, 32, Color(hc, 0.95), 3.0)
			for k in 4:
				var a0 := spin + k * TAU / 4.0
				session.draw_arc(t.position, Tower.RADIUS + 20.0, a0, a0 + 0.8, 8, Color(hc, 0.6), 2.0)
		if target and refuse:
			# 넣을 수 없는 오브젝트 위: 범위·설명 없이 빨간 고리 + 큰 ✕ + "넣을 수 없음" 하나만 (이유는 누르면 알림으로)
			place_note = {"t": target, "lines": PackedStringArray(["넣을 수 없음"]), "col": Color(1, 0.3, 0.32), "fs": 18, "refuse": true}
		elif target:
			var lines: PackedStringArray = pv[0]
			Tower.draw_range(session, target.position, target.dir, pv[1], session.picked["e"] if is_elem else -2)
			session.draw_arc(target.position, Tower.RADIUS + 8.0, 0, TAU, 32, Color.WHITE, 2.0)
			var tcol := col
			if is_elem:
				for r in Elem.new_reactions(target.eff_now(), session.picked["e"]):
					var rd: String = r["desc"]
					lines.append("조합: %s" % r["name"] + (" (%s)" % rd if rd.length() <= 26 else ""))
					tcol = r["color"]
					if r.get("aff", "") != "":
						lines.append(Elem.aff_label(r["a"], r["b"]).replace("(강)", " ▲강").replace("(약)", " ∿약"))
						tcol = BinduSession.AFF_COL[r["aff"]]
				var ns := Share.new_sites(target.eff_now(), session.picked["e"])
				if not ns.is_empty():
					lines.append("새 자리: " + " · ".join(ns))
			place_note = {"t": target, "lines": lines, "col": tcol, "fs": 16, "refuse": false}
		elif is_elem:
			var at := mpos.clamp(session.combat_system.field_rect().position, session.combat_system.field_rect().end)  # 실제로 놓일 자리
			session.draw_circle(at, Tower.RADIUS, Color(col, 0.4))
			var near := at.distance_to(c) < 50.0
			var lbl := "중앙과 너무 가까움" if near else "새로 설치 (직선탄)"
			_draw_place_label(at + Vector2(-40, Tower.RADIUS + 20), lbl, Color(1, 0.5, 0.5) if near else Color(1, 1, 1, 0.7))
		else:
			session.draw_arc(mpos, 10.0, 0, TAU, 20, Color(col, 0.8), 2.0)
			_draw_place_label(mpos + Vector2(-50, 28), "오브젝트 위에 놓기", Color(1, 1, 1, 0.7))
	elif session.phase == BinduSession.Phase.AIM:
		var sp: Dictionary = session.interaction_system.moving.spec() if session.interaction_system.moving else {"els": {session.picked["e"]: session.picked["lv"]}, "pat": Pat.DEFAULT, "plv": 1, "mods": {}}
		var col: Color = Elem.COLORS[sp["els"].keys()[0]]
		if not session.interaction_system.moving:
			session.draw_circle(session.place_pos, Tower.RADIUS, Color(col, 0.6))
		var d := _aim_dir(session.place_pos)
		if d != Vector2.ZERO:
			Tower.draw_range(session, session.place_pos, d, sp)
			if session.interaction_system.moving and not session.get_tree().paused:
				session.interaction_system.moving.set_attack_direction(d)
			session.draw_line(session.place_pos, session.place_pos + d * (Tower.RADIUS + 14.0), Color.WHITE, 3.0)
	# 마우스를 올린 오브젝트의 공격 범위
	if session.phase == BinduSession.Phase.MOVE and session.interaction_system.moving:
		Tower.draw_range(session, mpos, session.interaction_system.moving.dir, session.interaction_system.moving.spec())
	# 연결선: 옮길 자리에서 이어지는지 미리 보여 준다
	var movers: Array = [session.interaction_system.moving] if session.phase == BinduSession.Phase.MOVE and session.interaction_system.moving else (session.interaction_system.drag_group if session.interaction_system.dragging else [])
	for mover in movers:
		if not is_instance_valid(mover):
			continue
		if session.interaction_system._bad_spot(mover, movers) != "":
			# 여기 놓으면 되돌아간다는 표시 (중앙에 너무 가깝거나 다른 오브젝트와 겹침)
			session.draw_arc(mover.position, Tower.RADIUS + 10.0, 0, TAU, 32, Color(1, 0.25, 0.25, 0.75 + 0.25 * sin(Time.get_ticks_msec() / 90.0)), 4.0)
	if (Input.is_key_pressed(KEY_ALT) or session.range_all) and not session.title_label.visible:
		# Alt를 누르고 있는 동안: 모든 오브젝트의 공격 범위와 이번(지난) 웨이브 피해 몫 (약한 오브젝트 찾기)
		var total := 0.0
		for t in session.towers.get_children():
			Tower.draw_range(session, t.position, t.dir, t.spec())
			if t.reso > 0:
				session.draw_arc(t.position, Rules.t("reso_r") * MapRule.reso_k(), 0, TAU, 48, Color(1.0, 0.78, 0.3, 0.8), 2.0)
			total += t.dealt
		if total > 0.0:
			for t in session.towers.get_children():
				var txt := "%d%%" % roundi(t.dealt / total * 100.0)
				var tp: Vector2 = t.position + Vector2(-40, Tower.RADIUS + 20)
				session.draw_string(session.ui_font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, Meta.fs(14), Color(0, 0, 0, 0.8))
				session.draw_string(session.ui_font, tp, txt, HORIZONTAL_ALIGNMENT_CENTER, 80, Meta.fs(14), Color(1, 0.9, 0.5))
	elif session.interaction_system.dragging:
		# 끄는 동안: 옮기는 오브젝트들의 범위 (방향은 그대로)
		for t in session.interaction_system.drag_group:
			if is_instance_valid(t):
				Tower.draw_range(session, t.position, t.dir, t.spec())
	elif session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.WAVE, BinduSession.Phase.READY]:
		var hov := session.interaction_system._tower_at(mpos) if not session.card_dock.over_ui(session.interaction_system._pointer_screen()) else null
		if hov == null:
			hov = _ring_target()
		if hov:
			Tower.draw_range(session, hov.position, hov.dir, hov.spec(), -1, _tip_detail_on())
	if session.dps_panel.visible and is_instance_valid(session.dps_focus):
		# DPS 표에서 고른 오브젝트: 범위와 깜빡이는 고리, 위에서 가리키는 화살표
		var fp := session.dps_focus.position
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		Tower.draw_range(session, fp, session.dps_focus.dir, session.dps_focus.spec())
		session.draw_arc(fp, Tower.RADIUS + 8.0 + pulse * 6.0, 0, TAU, 40, Color(1, 0.9, 0.5, 0.95), 3.0)
		var ay := fp.y - Tower.RADIUS - 22.0 - pulse * 6.0
		session.draw_colored_polygon(PackedVector2Array([Vector2(fp.x, ay + 12), Vector2(fp.x - 9, ay), Vector2(fp.x + 9, ay)]), Color(1, 0.9, 0.5))
	# 여러 개 선택: 하늘색 점선 고리, 선택 상자
	for t in session.interaction_system.selected:
		if is_instance_valid(t):
			for i in 8:
				var a0 := TAU * i / 8 + Time.get_ticks_msec() / 800.0
				session.draw_arc(t.position, Tower.RADIUS + 12.0, a0, a0 + 0.45, 6, Color(0.5, 0.9, 1.0, 0.95), 2.5)
	if session.interaction_system.boxing:
		var r := Rect2(session.interaction_system.box_start, mpos - session.interaction_system.box_start).abs()
		session.draw_rect(r, Color(0.5, 0.9, 1.0, 0.08))
		session.draw_rect(r, Color(0.5, 0.9, 1.0, 0.8), false, 1.5)


func _draw_place_label(at: Vector2, text: String, color: Color) -> void:
	var session: BinduSession = self.session
	var visible := session.viewport_system.view_rect().grow(-8)
	var width := session.ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Meta.fs(14)).x
	at.x = clampf(at.x, visible.position.x, maxf(visible.position.x, visible.end.x - width))
	at.y = clampf(at.y, visible.position.y + 14, visible.end.y)
	var avoid: Array[Rect2] = []
	var to_world := session.get_canvas_transform().affine_inverse() * session.ui_root.get_global_transform()
	for rect in session.ui_layout_system._info_blockers():
		avoid.append(to_world * rect)
	avoid.append(Rect2(session.interaction_system._pointer_world() - Vector2(24, 24), Vector2(48, 48)))
	place_label_rect = session.ui_layout_system._free_badge(Rect2(at - Vector2(0, 14), Vector2(width, 18)), Vector2.UP, avoid, visible)
	session.draw_string(session.ui_font, place_label_rect.position + Vector2(0, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Meta.fs(14), color)


## 카드를 넣을 오브젝트에 올렸을 때의 설명 글 (main._draw가 place_note에 담고, 오브젝트 위에 보이게 fx_layer가 그린다).
## 어두운 상자에 담아 다른 오브젝트·중앙을 가장 덜 가리는 자리(위·아래·옆, 조금씩 떨어진 곳까지)에 띄운다.
## 넣을 수 없으면 빨간 고리 + 큰 ✕ + "넣을 수 없음" 한 줄만.
func _draw_place_note(ci: CanvasItem) -> void:
	var session: BinduSession = self.session
	place_note_rect = Rect2()
	if place_note.is_empty() or session.phase != BinduSession.Phase.PLACE or not is_instance_valid(place_note["t"]):
		return
	var target: Tower = place_note["t"]
	var lines: PackedStringArray = place_note["lines"]
	var col: Color = place_note["col"]
	var fs: int = place_note["fs"]
	var o := target.position
	if place_note["refuse"]:
		ci.draw_arc(o, Tower.RADIUS + 8.0, 0, TAU, 32, col, 3.0)
		var xr := Tower.RADIUS * 0.8
		ci.draw_line(o + Vector2(-xr, -xr), o + Vector2(xr, xr), Color(0, 0, 0, 0.6), 7.0)
		ci.draw_line(o + Vector2(xr, -xr), o + Vector2(-xr, xr), Color(0, 0, 0, 0.6), 7.0)
		ci.draw_line(o + Vector2(-xr, -xr), o + Vector2(xr, xr), col, 4.0)
		ci.draw_line(o + Vector2(xr, -xr), o + Vector2(-xr, xr), col, 4.0)
	var lh := fs + 5.0
	var w := 0.0
	for txt in lines:
		w = maxf(w, session.ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var sz := Vector2(w + 16.0, lh * lines.size() + 8.0)
	var vr := session.viewport_system.view_rect()
	var lo := vr.position + Vector2(8.0, 44.0)
	var hi := Vector2(_right_limit() - sz.x, vr.end.y - 76.0 - sz.y).max(lo)
	var gap := Tower.RADIUS + 12.0
	var cands: Array = []
	for k in 5:
		var dy := gap + k * 34.0
		for fx in [0.5, 0.15, 0.85]:
			cands.append(Vector2(o.x - sz.x * fx, o.y - dy - sz.y))  # 위
			cands.append(Vector2(o.x - sz.x * fx, o.y + dy))  # 아래
		var dx := gap + k * 40.0
		cands.append(Vector2(o.x + dx, o.y - sz.y / 2.0))  # 오른쪽
		cands.append(Vector2(o.x - dx - sz.x, o.y - sz.y / 2.0))  # 왼쪽
	var blocks: Array = [[session.viewport_system.center(), BinduSession.CORE_RADIUS + 16.0]]
	for t in session.towers.get_children():
		blocks.append([t.position, Tower.RADIUS + 4.0])
	var ui_blocks: Array[Rect2] = []
	var to_world := session.get_canvas_transform().affine_inverse() * session.ui_root.get_global_transform()
	for rect in session.ui_layout_system._info_blockers():
		ui_blocks.append(to_world * rect)
	var best := Rect2()
	var best_s := INF
	for p: Vector2 in cands:
		var q := p.clamp(lo, hi)
		var r := Rect2(q, sz)
		var sc := q.distance_to(o) / 60.0 + q.distance_to(p) / 30.0
		for bl in blocks:
			var bp: Vector2 = bl[0]
			if bp.clamp(r.position, r.end).distance_to(bp) < bl[1]:
				sc += 10.0
		for rect in ui_blocks:
			if r.intersects(rect):
				sc += 1000.0 + r.intersection(rect).get_area()
		if sc < best_s:
			best_s = sc
			best = r
	place_note_rect = best
	var near := o.clamp(best.position, best.end)
	if near.distance_to(o) > gap + 20.0:
		# 떨어진 자리면 오브젝트까지 가는 가는 선
		ci.draw_line(o + (near - o).normalized() * (Tower.RADIUS + 9.0), near, Color(col, 0.5), 1.5)
	ci.draw_rect(best, Color(0.03, 0.03, 0.06, 0.85))
	ci.draw_rect(best, Color(col, 0.6), false, 1.5)
	for i in lines.size():
		var txt := lines[i]
		var c2: Color = col if i == 0 or txt.begins_with("조합") else Color(1, 1, 1, 0.9)
		ci.draw_string(session.ui_font, best.position + Vector2(8.0, 2.0 + fs + i * lh), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c2)


## 회랑 맵: 길(띠)·끝의 문·구체가 오는 쪽 화살표.
## 중앙 특성 표시: 실드(파란 고리, 칸마다 한 줄), 성벽(진입 방향마다 바위 벽, 남은 조각만큼 두껍게), 반격 파동.
func _draw_core_guard(c: Vector2, now: float) -> void:
	var session: BinduSession = self.session
	var sh := session.shield + session.shield_keep
	for i in sh:
		var col := Color(0.55, 0.85, 1.0, 0.75) if i < session.shield else Color(0.75, 0.95, 1.0, 0.75)
		session.draw_arc(c, BinduSession.CORE_RADIUS + 5.0 + i * 4.0, 0, TAU, 40, Color(col, col.a * (0.75 + 0.25 * sin(now * 3.0 + i))), 2.0)
	if session.rampart_left > 0 and session.phase == BinduSession.Phase.WAVE:
		var wcol := Color(0.75, 0.6, 0.45, 0.9)
		var half := 22.0
		if Meta.map_id == "line":
			var dx := -BinduSession.RAMPART_R if Meta.line_flip else BinduSession.RAMPART_R
			for k in session.rampart_left:
				var x := c.x + dx + signf(dx) * k * 5.0
				session.draw_line(Vector2(x, c.y - 260.0), Vector2(x, c.y + 260.0), wcol, 4.0)
		else:
			for a in session.lanes:
				var dir := Vector2.from_angle(a)
				var side := dir.orthogonal() * half
				for k in session.rampart_left:
					var m := c + dir * (BinduSession.RAMPART_R + k * 5.0)
					session.draw_line(m - side, m + side, wcol, 4.0)
	session.abilities_system._draw_ley()
	for q in session.core_fx:
		var k: float = 1.0 - q[2] / BinduSession.FX_RIPOSTE
		session.draw_arc(q[0], q[1] * (0.3 + 0.7 * k), 0, TAU, 48, Color(1.0, 0.85, 0.5, 1.0 - k), 4.0)


func _draw_line_map(size: Vector2, mp: Dictionary, now: float) -> void:
	var session: BinduSession = self.session
	var cy := size.y / 2.0
	var gx := session.viewport_system.core().x
	var from_right := not Meta.line_flip
	var vw := session.viewport_system.view_rect()  # 길 바닥은 화면 끝까지 (전장 밖 양옆에서 끊기지 않게)
	session.draw_rect(Rect2(vw.position.x, cy - BinduSession.LINE_HALF, vw.size.x, BinduSession.LINE_HALF * 2.0), Color(1, 1, 1, 0.025))
	for e in [-1.0, 1.0]:
		session.draw_line(Vector2(vw.position.x, cy + e * BinduSession.LINE_HALF), Vector2(vw.end.x, cy + e * BinduSession.LINE_HALF), Color(mp["ring"], 0.25), 2.0)
	# 길 바닥의 흐르는 줄무늬 (구체가 가는 방향)
	var dirx := -1.0 if from_right else 1.0
	for k in 12:
		var x := fposmod(k * size.x / 12.0 + dirx * now * 30.0, size.x)
		session.draw_line(Vector2(x, cy - BinduSession.LINE_HALF + 6.0), Vector2(x, cy + BinduSession.LINE_HALF - 6.0), mp["ring"], 1.0)
	# 문: 닿으면 중앙 체력이 깎이는 세로선
	var gcol := Color(1, 0.4, 0.45, 0.5 + 0.2 * sin(now * 3.0) + 0.3 * session.core_flash)
	session.draw_line(Vector2(gx, cy - BinduSession.LINE_HALF), Vector2(gx, cy + BinduSession.LINE_HALF), gcol, 3.0)
	for e in [-1.0, 1.0]:
		session.draw_rect(Rect2(gx - 6.0, cy + e * BinduSession.LINE_HALF - 6.0, 12.0, 12.0), gcol)
	# 구체가 오는 쪽: 화면 끝의 화살표 3개
	var col := Color(1, 0.3, 0.35, 0.9 if session.phase != BinduSession.Phase.WAVE else 0.35)
	var ex := size.x - 18.0 if from_right else 18.0
	var d := Vector2(dirx, 0)
	for yy in [-BinduSession.LINE_HALF * 0.6, 0.0, BinduSession.LINE_HALF * 0.6]:
		var tip := Vector2(ex, cy + yy) + d * (6.0 * sin(now * 4.0))
		session.draw_colored_polygon(PackedVector2Array([tip + d * 22.0, tip + Vector2(0, 12), tip - Vector2(0, 12)]), col)


## 방향 고르기. Shift를 누르면 15도 단위로 맞춘다.
## 터치: 손가락을 오브젝트에서 조금 떼어 대고 있는 동안만 손가락 쪽, 아니면 붙잡아 둔 방향(aim_d).
func _aim_dir(from: Vector2) -> Vector2:
	var session: BinduSession = self.session
	var d := session.interaction_system._pointer_world() - from
	if session.touch_ui and session.phase == BinduSession.Phase.AIM and (not session.interaction_system.aim_hold or d.length() < BinduSession.AIM_TOUCH_MIN):
		return session.aim_d
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
