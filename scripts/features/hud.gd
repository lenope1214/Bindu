class_name BinduHud
extends BinduFeature

var panel_scroll := {}  # 폰: 창 → 안 굴림 칸 (_phone_scroll)
var hud_sig := ""
var hud_urgent := ""  # 바로 보여야 하는 값(웨이브·중앙 체력 등)이 바뀌었는지 비교용
var dps_scroll: ScrollContainer
var dps_list: VBoxContainer
var dps_sig := ""  # 표를 다시 만들지 정하는 요약 (오브젝트·피해가 바뀔 때만)
var dps_choice_open := false  # 카드 선택 중엔 요약만, D로 상세를 잠깐 펼친다
# 웨이브 중 실시간 DPS: 게임 시간 DPS_STEP초마다 오브젝트별 누적 피해(dealt)를 적어 두고 최근 DPS_WIN초 차이로 초당 피해 (이동 평균이라 덜 흔들림)
var rank_of := {}  # 오브젝트 instance id → 피해 순위 1~3 (왕관·메달)
func _build_dps(root: Control) -> void:
	session.dps_panel = FloatPanel.new("dps", session)
	session.dps_panel.position = Vector2(10, 60)
	session.dps_panel.custom_minimum_size.x = 300
	session.dps_panel.fold_pressed.connect(_toggle_dps)
	session.dps_panel.moved.connect(func(): dps_sig = "")
	session.dps_head = session.dps_panel.title
	dps_scroll = ScrollContainer.new()
	dps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	session.dps_panel.body.add_child(dps_scroll)
	dps_list = VBoxContainer.new()
	dps_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dps_list.add_theme_constant_override("separation", 2)
	dps_scroll.add_child(dps_list)
	session.dps_panel.visible = false
	root.add_child(session.dps_panel)


## 기본 자리: 점수 줄 아래 왼쪽.
func _dps_home() -> Vector2:
	var top := session.hud.position.y + session.hud.size.y + 8.0 if session.hud.visible else 8.0
	if session.mp_bar.visible:
		top += session.mp_bar.size.y + 4.0
	if session.mp_act and session.mp_act.visible:
		top += session.mp_act.size.y + 4.0
	return Vector2(10, top)


## 옮겨 둔 떠 있는 창(FloatPanel)이 비켜야 할 것 (창 부모 좌표): 점수 줄 칩·오른쪽 아래 버튼·기술 버튼·웨이브 시작 버튼·웨이브 중 콤보 자리.
func _panel_blocks(panel: Control) -> Array[Rect2]:
	var par := panel.get_parent() as Control
	var inv := par.get_global_transform().affine_inverse()
	var blocks: Array[Rect2] = []
	if session.hud.visible and not session.hud_chips.is_empty():
		var hb := Rect2()
		for c in session.hud_chips:
			hb = c[0] if hb.size == Vector2.ZERO else hb.merge(c[0])
		blocks.append(Rect2(session.hud.position + hb.position, hb.size).grow(4.0))
	var dock_btns: Array = [session.card_dock.focus_btn, session.card_dock.skip_group, session.card_dock.panel, session.card_dock.footer] if session.card_dock != null else []
	for c in [session.bar_box, session.start_btn, session.cancel_btn, session.aim_ok_btn, session.skip_badge, session.mp_bar, session.ver_label, session.legend] + session.skill_btns + dock_btns:
		if c != null and c is Control and c.is_visible_in_tree():
			blocks.append((inv * c.get_global_rect()).grow(4.0))
	if session.phase == session.Phase.WAVE:
		blocks.append((inv * session._combo_rect()).grow(4.0))  # 오른쪽 위 콤보 상자 자리 (웨이브 중엔 언제든 뜰 수 있어 비워 둔다)
	return blocks


func _toggle_dps() -> void:
	if session.card_dock != null and session.card_dock.active() and session.phase == session.Phase.CHOOSE:
		dps_choice_open = not dps_choice_open
	else:
		session.dps_hidden = not session.dps_hidden
		Meta.dps_fold = session.dps_hidden
	dps_sig = ""
	session.progression_system._save_best()


## 웨이브 중 표본 적기 (게임 시간 기준이라 배속과 상관없이 같은 값).
func _dps_sample(delta: float) -> void:
	session.dps_t -= delta
	if session.dps_t > 0.0:
		return
	session.dps_t += session.DPS_STEP
	session.dps_n += 1
	var keep := int(session.DPS_WIN / session.DPS_STEP) + 1
	for t in session.towers.get_children():
		var h: Array = session.dps_hist.get(t.get_instance_id(), [])
		h.append(t.dealt)
		if h.size() > keep:
			h.pop_front()
		session.dps_hist[t.get_instance_id()] = h


## 피해 1~3위 (왕관·메달, Tower._draw_rank). 이번 웨이브 누적 피해, 쉬는 시간엔 지난 웨이브 피해(t.dealt가 그 값).
## 웨이브 첫 RANK_HOLD초는 피해가 0부터 다시 쌓이므로 지난 순위를 그대로 둔다. 오브젝트 2개면 1위만, 1개면 없음.
func _rank_update() -> void:
	if not Meta.rank_on:
		if not rank_of.is_empty():
			rank_of.clear()
			for t in session.towers.get_children():
				t.queue_redraw()
		return
	if session.phase == session.Phase.WAVE and session.wave_time < session.RANK_HOLD:
		return
	var list := session.towers.get_children().filter(func(t): return t.dealt > 0.0)
	list.sort_custom(func(a, b): return a.dealt > b.dealt)
	var n := 0 if list.size() < 2 else (1 if list.size() < 3 else 3)
	var old_king = null
	for t in session.towers.get_children():
		if rank_of.get(t.get_instance_id(), 0) == 1:
			old_king = t
	rank_of.clear()
	for i in mini(n, list.size()):
		rank_of[list[i].get_instance_id()] = i + 1
	if n > 0 and old_king != null and old_king != list[0]:
		# 1위가 바뀌면 왕관이 옛 1위 자리에서 새 1위로 날아간다
		list[0].crown_from = old_king.position - list[0].position
		list[0].crown_t = Tower.CROWN_FLY
	for t in session.towers.get_children():
		t.queue_redraw()


## 표의 초당 피해: 웨이브 중이면 최근 DPS_WIN초 이동 평균, 쉬는 시간이면 지난 웨이브 평균.
func _dps_of(t: Tower) -> float:
	if session.phase != session.Phase.WAVE:
		return t.dealt / maxf(session.wave_time, 0.001)
	var h: Array = session.dps_hist.get(t.get_instance_id(), [])
	if h.size() < 2:
		return t.dealt / maxf(session.wave_time, 0.001)
	# 마지막 표본 뒤 흐른 시간까지 넣으면 0.5초마다 톱니처럼 튀므로 표본끼리만 잰다
	return (h[-1] - h[0]) / ((h.size() - 1) * session.DPS_STEP)


## 표를 보일지, 보이면 오브젝트·피해가 바뀌었을 때만 줄을 다시 만든다 (매 프레임 만들면 마우스 올림이 끊긴다).
func _refresh_dps() -> void:
	var on := session.phase in [session.Phase.CHOOSE, session.Phase.READY, session.Phase.WAVE] and not session.title_label.visible and session.wave_time > 1.0 and session.towers.get_child_count() > 0 \
		and not session.get_tree().paused and not session.help_label.visible and not session.settings_panel.visible and not session.records_panel.visible and not session.notes_panel.visible and not session.modes_panel.visible
	session.dps_panel.visible = on
	if not on:
		session.dps_focus = null
		session.dps_panel.stop_drag()
		return
	session.dps_panel.set_touch(session.touch_ui)
	# 표 밑에 오브젝트가 있으면 마우스를 올리지 않은 동안 옅게, 누르는 자리 밑 오브젝트는 먼저 (점수 줄과 같은 규칙, UI-36)
	session.dps_panel.cover(true)
	# 기본: 점수 줄 아래, 왼쪽 아래 안내 글 위까지. 옮겨 뒀으면 그 자리(줄 수는 화면 아래까지)
	var home := _dps_home()
	var top := home.y
	var par := session.dps_panel.get_parent() as Control
	var moved := session.dps_panel.pinned() or session.dps_panel.drag == 2
	session.dps_panel.follow(home, session.get_process_delta_time())
	var bottom := session.ui_layout_system._bottom_free()
	if moved:
		bottom = par.size.y - 8.0  # 표 높이는 점수 줄 아래~화면 아래만큼까지, 넘치면 dps_panel.place가 위로 올린다
	if not moved and session.choice_box.visible and not session.cards_hidden and session.choice_box.get_child_count() > 0 and session.choice_box.get_rect().position.x < 320.0:
		bottom = minf(bottom, session.choice_box.get_rect().position.y - maxf(24.0, session._choice_headroom() + 4.0))  # 카드·선택 안내를 덮지 않게 (넘치면 굴려 본다)
	if not moved and session.apply_btn.visible and session.apply_btn.get_rect().position.x < session.dps_panel.get_rect().end.x:
		bottom = minf(bottom, session.apply_btn.get_rect().position.y - 28.0)  # 폰 [적용] 버튼(누른 카드 위)을 덮지 않게
	if not moved and session.guide_label.visible and session.guide_label.get_rect().position.x < 320.0:
		bottom = minf(bottom, session.guide_label.position.y - 4.0)  # 처음 안내 글 위까지만
	var room := maxf(0.0 if session.apply_btn.visible else 48.0, bottom - top - session.dps_panel.head.size.y - 18.0)
	var live := session.phase == session.Phase.WAVE
	var list := session.towers.get_children()
	var dv := {}
	for t in list:
		dv[t] = _dps_of(t)
	list.sort_custom(func(a, b): return dv[a] > dv[b])
	# 웨이브 중엔 1초(표본 2개)마다만 고친다: 숫자가 매 프레임 바뀌면 읽을 수 없고 줄 순서도 덜 뒤바뀐다
	var folded := session.dps_hidden or (session.card_dock != null and session.card_dock.active() and session.phase == session.Phase.CHOOSE and not dps_choice_open)
	var sig := "%s|%s|%d|%d" % [folded, live, roundi(room), session.dps_n / 2 if live else roundi(session.wave_time)]
	for t in list:
		sig += "|%d:%s" % [t.get_instance_id(), t.title()]
		if not live:
			sig += ":%d" % roundi(t.dealt)
	if sig == dps_sig:
		return
	dps_sig = sig
	session.dps_head.text = session.ui_layout_system._kh("실시간 DPS (D)" if live else "지난 웨이브 DPS (D)")
	for c in dps_list.get_children():
		c.queue_free()
	session.dps_panel.set_folded(folded)
	if folded:
		session.dps_focus = null
		session.dps_panel.size = Vector2.ZERO
		return
	var total := 0.0
	for t in list:
		total += dv[t]
	for i in list.size():
		var row := _dps_row(list[i], i + 1, dv[list[i]], total, live)
		dps_list.add_child(row)
	var rows := list.size() * 24.0
	dps_scroll.custom_minimum_size.y = minf(rows, room)
	session.dps_panel.set_pass(session.dps_panel.passing, true)  # 새 줄도 통과 상태를 따르게
	session.dps_panel.size = Vector2.ZERO  # 줄이 줄면 판도 줄인다
	if session.dps_focus != null and not is_instance_valid(session.dps_focus):
		session.dps_focus = null


## 표 한 줄: 순위 · 색 · 이름 · 초당 피해 · 몫. 뒤에 몫만큼 막대.
func _dps_row(t: Tower, rank: int, dps: float, total: float, live := false) -> Control:
	var share := dps / total if total > 0.0 else 0.0
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 22)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 6)
	var col := t.color()
	var target: WeakRef = weakref(t)
	row.draw.connect(func():
		var tower: Tower = target.get_ref()
		var hot := tower != null and session.dps_focus == tower
		row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(1, 1, 1, 0.14 if hot else 0.04))
		row.draw_rect(Rect2(Vector2.ZERO, Vector2(row.size.x * share, row.size.y)), Color(col, 0.28))
		if hot:
			row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(1, 0.9, 0.5, 0.9), false, 1.0))
	row.mouse_entered.connect(func():
		session.dps_focus = target.get_ref()
		for r in dps_list.get_children():
			r.queue_redraw())
	row.mouse_exited.connect(func():
		if session.dps_focus == target.get_ref():
			session.dps_focus = null
		row.queue_redraw())
	var cells := [["%d" % rank, 18, HORIZONTAL_ALIGNMENT_RIGHT, Tower.RANK_COLORS[rank - 1] if rank <= 3 and rank_of.get(t.get_instance_id(), 0) == rank else Color(1, 1, 1, 0.55)],
		["", 0],
		["%.1f" % dps, 52, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.9, 0.5)],
		["%d%%" % roundi(share * 100.0), 36, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 1, 1, 0.7)]]
	for c in cells:
		if c[0] == "":
			row.add_child(_dps_name(t, col))
			continue
		var l := Label.new()
		l.text = c[0]
		l.horizontal_alignment = c[2]
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", c[3])
		if c[1] > 0:
			l.custom_minimum_size.x = c[1]
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size.x = 150
		row.add_child(l)
	if live:
		row.tooltip_text = "%s\n최근 %d초 초당 %.1f · 전체의 %d%%\n이번 웨이브 피해 %d (평균 초당 %.1f)" % [t.title(), roundi(session.DPS_WIN), dps, roundi(share * 100.0), roundi(t.dealt), t.dealt / session.wave_time]
	else:
		row.tooltip_text = "%s\n지난 웨이브 피해 %d · 초당 %.1f · 전체의 %d%%" % [t.title(), roundi(t.dealt), dps, roundi(share * 100.0)]
	var b := t.breakdown()
	if t.dealt > 0.0 and not b.is_empty():
		row.tooltip_text += "\n\n%s피해 출처 (초당 · 이 오브젝트의 몫)" % ("이번 웨이브 " if live else "")
		for key in _src_top(b, 5):
			row.tooltip_text += "\n  %s  %.1f · %d%%" % [session.src_name(key), b[key] / session.wave_time, roundi(b[key] / t.dealt * 100.0)]
		if b.has("pat:" + t.pattern) and b.size() > 1:
			row.tooltip_text += "\n(직접 타격 안의 배율 몫은 추정)"
	return row


## 표 이름 칸: 글 대신 공격방식 그림 + 속성 그림(레벨 2 이상은 작은 숫자). 이름은 줄 말풍선에.
func _dps_name(t: Tower, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(150, 22)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = true
	var target: WeakRef = weakref(t)
	c.draw.connect(func():
		var tower: Tower = target.get_ref()
		if tower == null:
			return  # 표가 다시 만들어지기 전에 오브젝트가 없어짐 (협동 재접속 등)
		var y := c.size.y / 2.0
		Glyph.pat(c, tower.pattern, Vector2(10, y), 8.0, col.lightened(0.5))
		var x := 22.0
		if tower.plv > 1:
			c.draw_string(session.ui_font, Vector2(x, y + 4.0), str(tower.plv), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
			x += 9.0
		x += 8.0
		for e in tower.order:
			Glyph.elem(c, e, Vector2(x + 7.0, y), 7.0)
			x += 16.0
			if tower.lv(e) > 1:
				c.draw_string(session.ui_font, Vector2(x, y + 4.0), str(tower.lv(e)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
				x += 4.0 + 6.0 * str(tower.lv(e)).length()
			x += 3.0)
	return c


## 판 전체 피해 출처 (모든 오브젝트 합).
func _run_src() -> Dictionary:
	var out := {}
	for t in session.towers.get_children():
		var a: Dictionary = t.all_src()
		for key in a:
			out[key] = out.get(key, 0.0) + a[key]
	return out


# ---------- 빌드 읽기 (2026-10-31 "디펜스 한계 개선 E") ----------
## 이번 판 주력: 판 누적 피해 출처 상위 [키, 몫]. 직접 타격(hit)·무리 보너스 같은 공통 몫은 뺀다.
## 쉬는 시간이 열릴 때만 다시 센다(build_cache) — 점수 줄·카드가 매 프레임 읽는다.
var build_cache: Array = []


func build_top(n: int) -> Array:
	var d := _run_src()
	var tot := 0.0
	for k in d:
		tot += d[k]
	if tot <= 0.0:
		return []
	var keys := d.keys().filter(func(k): return k != "hit" and not str(k).begins_with("etc:"))
	keys.sort_custom(func(a, b): return d[a] > d[b])
	return keys.slice(0, n).map(func(k): return [k, d[k] / tot])


func _refresh_build() -> void:
	build_cache = build_top(5) if session.wave >= 3 else []


## 카드가 주력(상위 2, 몫 8% 이상) 출처를 키우면 그 이름, 아니면 "". 반응 출처는 그 반응의 두 속성 카드.
func core_fit(card: Dictionary) -> String:
	for it in build_cache.slice(0, 2):
		if it[1] < session.BUILD_MIN:
			continue
		var k: String = it[0]
		match card["type"]:
			"elem":
				if k == Tower.elem_key(card["e"]):
					return session.src_name(k)
				if k == "share:" + Patch.ELEM_KEYS[Elem.ALL.find(card["e"])]:
					return session.src_name(k)
			"pat", "mod", "link", "trig":
				if k == "%s:%s" % [card["type"], card.get("id", "")]:
					return session.src_name(k)
	return ""


## 피해가 큰 출처 키 n개.
func _src_top(d: Dictionary, n: int) -> Array:
	var keys := d.keys()
	keys.sort_custom(func(a, b): return d[a] > d[b])
	return keys.slice(0, n)


## 피해 출처 키 → 보이는 이름 (elem:fire → 불, share:electric → 특징 튐).
## 상성 색: 강 초록, 약 주황 (Elem.aff_of)
func _apply_ui_scale() -> void:
	var s: float = Meta.ui_scale
	session.legend_rx_rows = 999  # 글자 크기가 바뀌면 설명 반응 줄 수를 다시 맞춘다
	session.ui_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# 폰: 노치·둥근 모서리·홈 막대 자리(안전 영역 밖)는 비운다 (화면비를 넓힌 뒤 가장자리 UI가 노치 밑에 깔릴 수 있다)
	var pad := _safe_pad()
	session.ui_root.position = Vector2(pad.position.x, pad.position.y)
	session.ui_root.scale = Vector2(s, s)
	session.ui_root.size = (session.get_viewport_rect().size - Vector2(pad.position.x + pad.size.x, pad.position.y + pad.size.y)) / s
	# 일시정지 어둠·카드 선택 막은 안전 영역 밖까지 덮는다
	for d in [session.pause_dim, session.card_dim]:
		if d:
			d.offset_left = -pad.position.x / s
			d.offset_top = -pad.position.y / s
			d.offset_right = pad.size.x / s
			d.offset_bottom = pad.size.y / s


## 안전 영역 밖 여백 (화면 좌표, position = 왼쪽·위, size = 오른쪽·아래). 폰·태블릿만.
func _safe_pad() -> Rect2:
	if Meta.sim_safe.has_area() or Meta.sim_safe.position != Vector2.ZERO:
		return Meta.sim_safe
	if not OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return Rect2()
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Rect2()
	var k := session.get_viewport_rect().size / win  # 화면 픽셀 → 뷰포트 좌표
	var l := clampf(safe.position.x, 0.0, win.x * 0.15) * k.x
	var t := clampf(safe.position.y, 0.0, win.y * 0.15) * k.y
	var r := clampf(win.x - safe.end.x, 0.0, win.x * 0.15) * k.x
	var b := clampf(win.y - safe.end.y, 0.0, win.y * 0.15) * k.y
	return Rect2(l, t, r, b)


## 화면보다 커지는 창(줄이 많거나 글자를 키웠을 때)은 줄여서 맞춘다. 가운데 창이라 위아래 여백이 같고, 아래는 버튼 줄을 비운다.
## 세로로만 굴리는 칸에 넣는다 (가로는 내용 폭 그대로)
func _vscroll(inner: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = inner.size_flags_horizontal
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	return sc


## 폰: 창 안 내용을 굴림 칸으로 옮긴다. _fit_panels가 창을 줄이는 대신 굴림 칸 높이를 화면에 맞춘다
func _phone_scroll(p: PanelContainer) -> void:
	if not session._phone():
		return
	var inner: Control = p.get_child(0)
	p.remove_child(inner)
	var sc := _vscroll(inner)
	p.add_child(sc)
	panel_scroll[p] = sc


func _fit_panels() -> void:
	if session.title_box.visible:
		session.menu_system._prep_layout()
		if session.modes_btn.get_child_count() > 0:
			# 모드 줄 작은 설명이 두 줄로 접히면 버튼도 키운다 (버튼은 안 글 높이를 따라 크지 않는다)
			var mh := (session.modes_btn.get_child(0) as Control).get_combined_minimum_size().y + 8.0
			session.modes_btn.custom_minimum_size.y = maxf(64.0 if session._phone() else 56.0, mh)
	for c: Control in [session.title_box, session.help_scroll, session.records_panel, session.settings_panel, session.notes_panel, session.modes_panel, session.codex_panel, session.vote_panel]:
		if not c.is_visible_in_tree():
			continue
		if panel_scroll.has(c):
			# 폰: 줄이지 않고 화면 높이까지만 키운 뒤 안을 굴린다 (줄이면 글자 6~7pt·토글이 손가락보다 작았다)
			var sc: ScrollContainer = panel_scroll[c]
			var want := minf(sc.get_child(0).get_combined_minimum_size().y, session.ui_root.size.y - 24.0 - 40.0)
			if absf(sc.custom_minimum_size.y - want) > 0.5:
				sc.custom_minimum_size.y = want
				var ph := want + 40.0
				c.offset_top = -ph / 2.0
				c.offset_bottom = ph / 2.0
			c.scale = Vector2.ONE
			continue
		if c == session.records_panel and session.board_box.visible and session._phone():
			c.scale = Vector2.ONE  # 리더보드는 _board_fit이 화면에 맞추고 안을 굴린다
			continue
		if c == session.records_panel and not session.board_box.visible:
			# 맵별 기록: 창 높이를 글 높이에 맞춘다 (예전엔 610 고정이라 아래 절반이 빈칸)
			var rh := clampf(session.records_panel.get_line_count() * session.records_panel.get_line_height() + 40.0, 160.0, 610.0)
			if absf(session.records_panel.offset_bottom - session.records_panel.offset_top - rh) > 0.5:
				session.records_panel.offset_top = -rh / 2.0 - 20.0
				session.records_panel.offset_bottom = rh / 2.0 - 20.0
		var h: float = c.get_combined_minimum_size().y if c == session.title_box else c.size.y
		# 글자 크기와 상관없이: 줄이 많으면 시작 화면 아래 버튼 줄·도움말·기록 창이 화면 밖으로 잘리던 것 (아래 구석 버전·소리 버튼 자리를 비운다)
		var k := minf(1.0, (session.ui_root.size.y - (110.0 if c == session.title_box else 100.0)) / maxf(1.0, h))
		if c == session.title_box:
			k = minf(k, (session.ui_root.size.x - 24.0) / maxf(1.0, c.get_combined_minimum_size().x))
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2(k, k)


## 새 판을 시작할 때 모드가 바꾸는 시작 값 (중앙 체력). 봇이 모드를 바꾼 뒤에도 부른다.
func start_modes() -> void:
	session.core_max = maxi(1, roundi(Modes.core_max(session.CORE_MAX_HP) * (float(Rules.tune["mp_core"]) if session.vs_on or session.coop_n > 1 else 1.0)))
	session.core_hp = session.core_max
	session.core_disp = float(session.core_hp)
	session.danger_lv = 0
	session.wave_dmg = 0


func big_banner(t: String, col: Color) -> void:
	if session.banner_t > 0.5:
		if session.banner_queue.size() < 3:
			session.banner_queue.append([t, col])
		return
	session.banner.text = t
	session.banner.add_theme_color_override("font_color", col)
	session.banner_t = 1.6


func _show_toast(t: String) -> void:
	session.toast.text = session.patchlog_system._kr_keep(t)  # 좁은 자리에서 두 줄로 접힐 때 한글 낱말 중간에서 끊기지 않게
	session.toast_timer = 2.0


## 점수·남은 구체만 바뀐 때는 0.1초에 한 번만 다시 쓴다. 글자 모양 계산이 비싸 고배속에서 프레임마다 쓰면
## 그것만으로 프레임당 몇 ms (8배속 부하 측정). 웨이브·중앙 체력 등이 바뀌면 바로.
func _update_hud(force := false) -> void:
	var urgent := "%d|%d|%d|%d|%d|%d|%d|%d|%d" % [session.wave, session.wave_dmg, session.core_hp, session.core_max, session.phase, session.towers.get_child_count(), session.selected.size(), session.perks.size(), 0]
	if not force and urgent == hud_urgent and session.hud_cool > 0.0:
		return
	hud_urgent = urgent
	session.hud_cool = 0.1
	var W := Color(1, 1, 1, 0.92)
	var D := Color(1, 1, 1, 0.6)
	var items: Array = []  # [아이콘, 아이콘 색, 글, 글 색, 말풍선 줄, 새 줄에서 시작?]
	items.append(["wave", Color(0.5, 0.78, 1.0), str(session.wave), W, [["웨이브", W]], false])
	items.append(["score", Color(1, 0.82, 0.35), session.num(session.score), W, [["점수", W]], false])
	var ct := "%d/%d" % [maxi(session.core_hp, 0), session.core_max] + ("  -%d" % session.wave_dmg if session.wave_dmg > 0 else "")
	var ctip := [["중앙 체력", W]]
	if session.wave_dmg > 0:
		ctip.append(["이번 웨이브 -%d" % session.wave_dmg, Color(1, 0.55, 0.55)])
	items.append(["core", Color(1, 0.55, 0.6) if session.core_hp * 3 <= session.core_max else W, ct, Color(1, 0.6, 0.6) if session.wave_dmg > 0 else W, ctip, false])
	items.append(["best", Color(1, 0.82, 0.35, 0.7), "%s · %d" % [session.num(session.best_score), session.best_wave], D, [["최고 기록: 점수 %s · 웨이브 %d" % [session.num(session.best_score), session.best_wave], W]], false])
	if Meta.rules != 1:
		items.append(["tag", D, Rules.NAMES[Meta.rules], D, [["규칙", W]], false])
	if not Modes.on.is_empty():
		items.append(["tag", Color(1, 0.7, 0.4), "x%.2f" % Modes.mul(), Color(1, 0.8, 0.55), [["모드 점수 배율 x%.2f" % Modes.mul(), W]], false])
	if Vary.on or Vary.count() > 0:
		# 판마다 다른 흐름: 지금 이벤트(없으면 봉인 수), 말풍선에 이벤트·예고·봉인·적응
		var vc := Color(0.7, 0.85, 1.0)
		var vt := ["이번 판 흐름 (시험)", W]
		var vl: Array = [vt]
		if not Vary.event.is_empty():
			vl.append(["이벤트 %s: %s" % [Vary.ename(Vary.event), Vary.edesc(Vary.event)], W])
		if not Vary.next_event.is_empty():
			vl.append(["다음 이벤트 %s: %s" % [Vary.ename(Vary.next_event), Vary.edesc(Vary.next_event)], D])
		if Vary.count() > 0:
			vl.append(["봉인: " + Vary.sealed_text(), D])
		var ad := Vary.adapt_text()
		if ad != "":
			vl.append(["적응 구체: " + ad, Color(1, 0.75, 0.6)])
		var txt := Vary.ename(Vary.event) if not Vary.event.is_empty() else ("봉인 %d" % Vary.count() if Vary.count() > 0 else "판 흐름")
		if ad != "":
			txt += " · 적응"
		items.append(["tag", vc, txt, vc, vl, false])
	if MapRule.on():
		# 맵 규칙·친화 카드 (시험): 칩은 규칙 이름, 말풍선에 규칙과 친화
		var mc := session.MAP_AFF_COLOR
		var rt := MapRule.rule_text()
		items.append(["tag", mc, str(Meta.MAPS[Meta.map_id]["name"]) + " 규칙", mc, [["맵 규칙 (시험)", W], [rt, W], ["친화 카드 (자주 나옴, 속성·공격방식 피해 +%d%%): %s" % [roundi(Rules.t("map_aff_dmg") * 100), MapRule.aff_text()], D]], false])
	if not build_cache.is_empty() and build_cache[0][1] >= session.BUILD_MIN:
		# 이번 판 주력: 피해 출처 1위와 몫, 말풍선에 상위 5
		var bl: Array = [["이번 판 주력 (판 누적 피해 출처)", W]]
		for it in build_cache:
			bl.append(["%s %d%%" % [session.src_name(it[0]), roundi(it[1] * 100)], D])
		bl.append(["주력을 키우는 카드에는 ◎ 표시", session.BUILD_COLOR])
		items.append(["build", session.BUILD_COLOR, "주력 %s %d%%" % [session.src_name(build_cache[0][0]), roundi(build_cache[0][1] * 100)], Color(0.8, 1, 1), bl, false])
	var nt := session.towers.get_child_count()
	if nt > 1:
		var cb := roundi(Rules.crowd_bonus(nt) * MapRule.crowd_k() * 100)
		items.append(["crowd", Color(0.6, 0.9, 0.65), "%d개 +%d%%" % [nt, cb], Color(0.7, 0.95, 0.75), [["오브젝트 수 보너스: %d개, 피해 +%d%%" % [nt, cb], W]], false])
	if session.phase == session.Phase.WAVE:
		items.append(["orb", Color(0.85, 0.85, 0.9), str(session.to_spawn + session._alive_count(session.orbs)), W, [["남은 구체", W]], false])
	# 다음 보스까지 남은 웨이브 (보스 웨이브 중이면 "지금")
	var bl := (ceili(session.wave / 5.0) * 5 - session.wave) if session.phase == session.Phase.WAVE else (ceili((session.wave + 1) / 5.0) * 5 - session.wave)
	if session.wave > 0 or session.phase != session.Phase.WAVE:
		var bt := "다음 웨이브 보스" if bl == 1 and session.phase != session.Phase.WAVE else ("이번 웨이브 보스" if bl == 0 else "보스까지 %d웨이브" % bl)
		items.append(["boss", Color(1, 0.6, 0.75), "보스!" if bl == 0 else "보스까지 %d" % bl, Color(1, 0.75, 0.85), [[bt, W]], false])
	if not session.selected.is_empty():
		items.append(["sel", Color(0.6, 1, 0.7), str(session.selected.size()), W, [["선택한 오브젝트", W]], false])
	var first := true
	for pk in session.PERKS:
		var n: int = session.perks.get(pk["id"], 0)
		if n > 0:
			items.append(["perk", Color(0.75, 0.7, 1.0), pk["name"] + (" x%d" % n if n > 1 else ""), D, [["특성 " + pk["name"] + (" x%d" % n if n > 1 else ""), W], [pk["desc"], D]], first])
			first = false
	# 오른쪽 위 버튼(설명 보기, 터치면 범위 보기) 앞까지. 글자를 키우면(설정) 화면이 좁아진 만큼 줄어든다
	var hud_w := session.ui_root.size.x - (410.0 if session.zoom_btn.visible else 300.0 if session.range_btn.visible else 190.0)  # [확대 풀기]까지 피함
	# 둘째 줄부터는 오른쪽 설명(위에서 48부터) 왼쪽까지 (특성이 많으면 둘째 줄이 설명 글 위로 지나갔다)
	var hud_w2 := minf(hud_w, session.legend.position.x - 8.0) if session.legend.visible else hud_w
	var sig := "%s|%s" % [hud_w, hud_w2]
	for it in items:
		sig += "|" + it[2] + str(it[1])
	if sig == hud_sig:
		return
	hud_sig = sig
	var fs := 17
	var x := 0.0
	var y := 0.0
	var right := 0.0
	session.hud_chips.clear()
	# 핵심 상태는 항상 먼저, 나머지는 별도 줄로 시각적으로 묶는다.
	var primary := items.slice(0, mini(3, items.size()))
	var secondary := items.slice(mini(3, items.size()))
	for it in primary + secondary:
		var w := Icons.chip_w(session.ui_font, it[2], fs)
		var core_count := mini(3, items.size())
		var core_done := session.hud_chips.size() >= core_count
		if x > 0.0 and (it[5] or (core_done and y == 0.0) or x + w > (hud_w if y == 0.0 else hud_w2)):
			x = 0.0
			y += 34.0
		session.hud_chips.append([Rect2(x, y, w, 30.0), it[0], it[1], it[2], it[3], it[4]])
		x += w + 6.0
		right = maxf(right, x)
	session.hud.size = Vector2(right, y + 30.0)
	session.hud.queue_redraw()


func _draw_hud() -> void:
	for c in session.hud_chips:
		Icons.chip(session.hud, session.ui_font, c[0], c[1], c[2], c[3], c[4], 17)


# ---------- 단계 ----------

## 큰 숫자를 천 단위 쉼표로 (3864489 → 3,864,489).
