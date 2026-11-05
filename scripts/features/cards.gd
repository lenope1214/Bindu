class_name BinduCards
extends BinduFeature
## 카드 선택·표현·적용. 예약 콜백은 main의 순서를 따른다.

func _open_choose() -> void:
	var session: BinduSession = self.session
	session.phase = BinduSession.Phase.CHOOSE
	session.wave_active = false
	_clear_shots()
	for t in session.towers.get_children():
		t.queue_redraw()
	session.waves_system._update_preview()
	session.cards_hidden = false
	session.choice_box.visible = true
	_update_reroll_btn()
	session.hint.text = session.ui_layout_system._th(_choose_hint())


## 쉬는 시간이 되면 남은 탄·장판을 지운다.
func _clear_shots() -> void:
	var session: BinduSession = self.session
	for p in session.projectiles.get_children():
		p.queue_free()
	for z in session.zones.get_children():
		z.queue_free()


func _make_choices() -> void:
	var session: BinduSession = self.session
	session.offer.clear()
	var guard := 0
	while session.offer.size() < 3 and guard < 50:
		guard += 1
		var card := _roll_card()
		if card.is_empty():
			break
		if not _card_enabled(card):
			continue
		# 넣을 곳이 없는 공격방식·강화 카드는 내지 않는다
		if card["type"] in ["pat", "mod", "trig"] and not session.multiplayer_system._my_towers().any(func(t): return t.can_take(card)):
			continue
		if _star_blocked(card):  # 별·행성이 다 찼고 레벨업할 별도 없으면 별 카드는 내지 않는다
			continue
		# 같은 속성은 레벨만 다르게 두 장 나오지 않게: 높은 레벨 한 장만 남긴다
		var same := session.offer.filter(func(cd): return _card_key(cd) == _card_key(card))
		if same.is_empty():
			session.offer.append(card)
		elif card.get("lv", 1) > same[0].get("lv", 1):
			session.offer[session.offer.find(same[0])] = card
	# 속성 카드(새 오브젝트를 놓을 수 있는 카드)는 최소 1장
	if not session.offer.any(func(cd): return cd["type"] == "elem"):
		var pool: Array = Vary.open("elem", Elem.ALL).filter(func(e): return _card_enabled({"type": "elem", "e": e}) and not _star_blocked({"type": "elem", "e": e}))
		if not pool.is_empty():
			var fallback := {"type": "elem", "e": MapRule.pick("elem", pool), "lv": 1}
			if session.offer.is_empty():
				session.offer.append(fallback)
			else:
				session.offer[randi() % session.offer.size()] = fallback
	if session.tutor:
		_tutor_offer()
	if TutPlay.on and session.tplay != null:
		session.offer = session.tplay.offer(session.offer)  # 연습 판: 이번 단계 카드 + 흐린 카드 두 장
	_show_offer()
	session.onboarding_system._card_guides()


## 카드 줄 위 봉인 칩 (봉인 모드): 봉인된 속성(그림 + 이름)·공격방식(그림 + 이름)·연계 이름. cx 가운데, bottom 칩 아래 끝.
func _draw_seal_chip(ci: CanvasItem, cx: float, bottom: float) -> Rect2:
	var session: BinduSession = self.session
	var fs := 14
	var items: Array = []  # [그리기 종류, id, 글, 색]
	for e in Vary.sealed["elem"]:
		items.append(["e", e, Elem.NAMES[e], Elem.COLORS[e]])
	for p in Vary.sealed["pat"]:
		items.append(["p", p, Pat.pname(p), Pat.pcolor(p).lightened(0.15)])
	for l in Vary.sealed["link"]:
		items.append(["l", l, Pat.LINKS[l]["name"], Color(0.55, 0.9, 1.0)])
	var head := "봉인"
	var hw := session.ui_font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var widths: Array = []
	var w := 12.0 + hw + 10.0
	for it in items:
		var iw: float = (0.0 if it[0] == "l" else 18.0) + session.ui_font.get_string_size(it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(iw)
		w += iw + 10.0
	w += 2.0
	var r := Rect2(cx - w / 2.0, bottom - 26.0, w, 26.0)
	r.position.x = clampf(r.position.x, 8.0, maxf(8.0, session.info.size.x - w - 8.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.12, 0.97)
	sb.border_color = Color(0.7, 0.7, 1.0, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	ci.draw_style_box(sb, r)
	var cy := r.position.y + 13.0
	var x := r.position.x + 12.0
	ci.draw_string(session.ui_font, Vector2(x, cy + fs * 0.36), head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.8, 0.8, 1.0))
	x += hw + 10.0
	for i in items.size():
		var it: Array = items[i]
		var col: Color = it[3]
		if it[0] == "e":
			Glyph.elem(ci, it[1], Vector2(x + 7.0, cy), 7.0)
		elif it[0] == "p":
			Glyph.pat(ci, it[1], Vector2(x + 7.0, cy), 7.0, col)
		var tx := x + (0.0 if it[0] == "l" else 18.0)
		ci.draw_string(session.ui_font, Vector2(tx, cy + fs * 0.36), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		# 봉인: 이름 위에 가로줄
		var tw: float = session.ui_font.get_string_size(it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_line(Vector2(tx - 1.0, cy), Vector2(tx + tw + 1.0, cy), Color(col, 0.7), 1.5)
		x += widths[i] + 10.0
	return r


## 첫 판: 이번 웨이브에 새로 열린 카드 종류를 처음 한 번은 선택지에 꼭 넣는다 (속성 카드 하나는 남김).
func _tutor_offer() -> void:
	var session: BinduSession = self.session
	for k in ["pat", "mod", "trig", "link"]:
		if session.wave + 1 < BinduSession.TUTOR_OPEN[k] or session.tutor_given.has(k):
			continue
		if not session.offer.any(func(cd): return cd["type"] == k):
			var cd := _tutor_card(k)
			if cd.is_empty():
				continue
			var elems := session.offer.filter(func(c): return c["type"] == "elem").size()
			for i in range(session.offer.size() - 1, -1, -1):
				if session.offer[i]["type"] != "elem" or elems > 1:
					session.offer[i] = cd
					break
		session.tutor_given[k] = true


## 넣을 곳이 있는 그 종류 카드 한 장 (없으면 빈 사전).
func _tutor_card(k: String) -> Dictionary:
	var session: BinduSession = self.session
	var ids: Array = []
	match k:
		"pat": ids = Pat.PATTERN_IDS.slice(1)
		"mod": ids = Pat.MOD_IDS.duplicate()
		"link": ids = ["pincer"] if session.towers.get_child_count() >= 2 else ["reso"]
		"trig": ids = Pat.TRIG_IDS.duplicate()
	ids.shuffle()
	for id in ids:
		var cd := {"type": k, "id": id}
		if _card_enabled(cd) and (k == "link" or session.towers.get_children().any(func(t): return t.can_take(cd))):
			return cd
	return {}


## 첫 판에는 아직 안 열린 카드 종류.
func _card_open(k: String) -> bool:
	var session: BinduSession = self.session
	return not session.tutor or session.wave + 1 >= BinduSession.TUTOR_OPEN[k]


## 카드 [자세히] 켜기·끄기: 지금 선택지를 같은 카드로 다시 그린다 (새로 뽑지 않음).
func _set_card_detail(on: bool) -> void:
	var session: BinduSession = self.session
	Meta.card_detail = on
	session.card_detail_btn.set_pressed_no_signal(on)
	session.progression_system._save_best()
	if session.phase == BinduSession.Phase.CHOOSE and not session.perk_mode and not session.offer.is_empty():
		var sel := session.tap_sel
		_show_offer()
		session.tap_sel = sel
		_tap_hover.call_deferred()


## 선택지 카드 버튼을 offer대로 다시 만든다.
func _show_offer() -> void:
	var session: BinduSession = self.session
	var last_preview := session.card_dock.preview_card() if session.card_dock != null else {}
	var retained: Button = null
	session.tap_sel = -1
	for c in session.choice_box.get_children():
		c.queue_free()
	for i in session.offer.size():
		var button := _card_button(session.offer[i], i + 1)
		session.choice_box.add_child(button)
		if session.offer[i] == last_preview:
			retained = button
	if session.card_dock != null:
		session.card_dock.hovered = retained


## 같은 선택지인지 비교하는 키 (레벨은 무시).
func _card_key(card: Dictionary) -> String:
	return "%s:%s" % [card["type"], card.get("e", card.get("id", ""))]


## 온라인 패치의 카드 사용 여부. 미지정 카드는 기존처럼 사용한다.
func _card_enabled(card: Dictionary) -> bool:
	var kind := str(card.get("type", ""))
	var id := str(card.get("id", ""))
	if kind == "elem":
		var e := int(card.get("e", -1))
		if e < 0 or e >= Patch.ELEM_KEYS.size():
			return false
		id = Patch.ELEM_KEYS[e]
	return Patch.num("card_enabled", "%s.%s" % [kind, id], 1.0) >= 0.5


## 선택지 한 장: 속성 / 공격방식 / 강화 / 연계 중 하나.
func _roll_card() -> Dictionary:
	var session: BinduSession = self.session
	var ts := session.multiplayer_system._my_towers()
	var n := ts.size()
	var elems: Array = Vary.open("elem", Elem.ALL).filter(func(e): return _card_enabled({"type": "elem", "e": e}))
	if elems.is_empty():
		return {}
	var patterns: Array = Vary.open("pat", Pat.PATTERN_IDS.slice(1)).filter(func(id):
		var cd := {"type": "pat", "id": id}
		return _card_enabled(cd) and ts.any(func(t): return t.can_take(cd)))
	var mods: Array = Pat.MOD_IDS.filter(func(id):
		var cd := {"type": "mod", "id": id}
		return _card_enabled(cd) and ts.any(func(t): return t.can_take(cd)))
	var trigs: Array = Pat.TRIG_IDS.filter(func(id):
		var cd := {"type": "trig", "id": id}
		return _card_enabled(cd) and ts.any(func(t): return t.can_take(cd)))
	var links: Array = (Pat.LINK_IDS if n >= 2 else ["reso"]).filter(func(id):
		return _card_enabled({"type": "link", "id": id}) and not Vary.is_sealed("link", id))
	# 비활성 카드와 현재 넣을 수 없는 카드는 확률 풀에서 빼고 남은 종류끼리 비율을 다시 맞춘다.
	var we := Patch.num("cards", "elem", 0.42)
	var wp := Patch.num("cards", "pat", 0.25) if _card_open("pat") and not patterns.is_empty() else 0.0
	var wm := Patch.num("cards", "mod", 0.23) if _card_open("mod") and not mods.is_empty() else 0.0
	var wt := Patch.num("cards", "trig", 0.12) if _card_open("trig") and not trigs.is_empty() else 0.0
	var wl := Patch.num("cards", "link", 0.10) if _card_open("link") and not links.is_empty() else 0.0
	var total := we + wp + wm + wt + wl
	if n == 0 or session.wave == 0 or total <= 0.0:
		return {"type": "elem", "e": MapRule.pick("elem", elems), "lv": 2 if randf() < session.perks_system._lv2_chance() else 1}
	var r := randf() * total
	if r < we:
		return {"type": "elem", "e": MapRule.pick("elem", elems), "lv": 2 if randf() < session.perks_system._lv2_chance() else 1}
	r -= we
	if r < wp:
		return {"type": "pat", "id": MapRule.pick("pat", patterns)}
	r -= wp
	if r < wm:
		return {"type": "mod", "id": MapRule.pick("mod", mods)}
	r -= wm
	if r < wt:
		return {"type": "trig", "id": trigs.pick_random()}
	return {"type": "link", "id": MapRule.pick("link", links)}


func _card_color(card: Dictionary) -> Color:
	match card["type"]:
		"elem": return Elem.COLORS[card["e"]]
		"pat": return Pat.pcolor(card["id"]).lightened(0.15)
		"mod": return Color(1, 0.82, 0.4)
		"trig": return Pat.TRIG_COLOR
	return Color(0.55, 0.9, 1.0)


func _card_button(card: Dictionary, idx: int) -> Button:
	var session: BinduSession = self.session
	var col := _card_color(card)
	var b := Button.new()
	b.custom_minimum_size = Vector2(230 if session.offer.size() <= 3 else 166, 170)
	var sb := CardDock.surface()
	sb.border_color = Color(col, 0.6)
	var sbh := sb.duplicate()
	sbh.bg_color = Color("223149")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	# 카드는 글 대신 그림 머리(종류 그림·이름·Lv 배지·번호 키)와 줄(앞에 그림)로 그린다 (_card_paint).
	# 설명은 세 단계: 기본은 간소화, [자세히]를 켜면 조금 더, 자세히 + 올리기(터치는 한 번 누르기)면 카드 위 창에 전부 (_draw_card_full)
	var cc := _card_content(card, 1 if Meta.card_detail else 0)
	var head: Dictionary = cc["head"]
	head["idx"] = idx
	var rows: Array = cc["rows"]
	var foot: Array = cc["foot"]
	b.set_meta("full", _card_full(card))
	b.set_meta("summary", _card_content(card, 0)["rows"])
	session.card_dock.watch(b, card)
	var fit := session.hud_system.core_fit(card)
	if fit != "":
		rows.append({"t": "◎ 주력 %s 강화" % fit, "fs": 12, "c": BinduSession.BUILD_COLOR})
	if MapRule.card_aff(card):
		var dmg_up: bool = card["type"] in ["elem", "pat"]
		rows.append({"t": "◆ %s 친화%s" % [Meta.MAPS[Meta.map_id]["name"], " · 피해 +%d%%" % roundi(Rules.t("map_aff_dmg") * 100) if dmg_up else ""], "fs": 12, "c": BinduSession.MAP_AFF_COLOR})

	_card_paint(b, head, rows, foot, col, 14, session.offer.size())
	b.focus_mode = Control.FOCUS_NONE  # 다른 버튼처럼: Space·Enter가 카드를 고르지 않게
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.pressed.connect(_on_card_tap.bind(card, idx - 1))
	_mark_fav(b, sb, sbh, _fav_tag(card))
	if card["type"] == "elem":
		# 터치는 누르는 순간 마우스가 들어와 미리보기가 보이기도 전에 골라졌다: 터치는 한 번 누르기(_on_card_tap)로 미리보기
		b.mouse_entered.connect(func():
			if not session.touch_ui: session.hover_elem = card["e"])
		b.mouse_exited.connect(func():
			if not session.touch_ui: session.hover_elem = -1)
	return b


## 카드 앞면 내용 {head, rows, foot, tip}. lvl 0 = 기본 주효과, 1 = 자세히(전체 설명).
func _card_content(card: Dictionary, lvl: int) -> Dictionary:
	var session: BinduSession = self.session
	var head := {"kind": card["type"], "name": ""}
	var rows: Array = []
	var foot: Array = []
	var tip := ""
	var dim := Color(1, 1, 1, 0.55)
	match card["type"]:
		"elem":
			var e: int = card["e"]
			head["name"] = Elem.NAMES[e]
			head["e"] = e
			if card["lv"] == 2:
				head["lv"] = "Lv2"
			rows = [{"i": "rider", "t": "효과 · " + Elem.rider(e), "al": 0}, {"i": "trait", "t": "특징 · " + Elem.TRAIT[e], "al": 0}]
			foot = [["place_new", "새 오브젝트"], ["place_on", "겹치기" + (" %d종" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "")]]
			var cf := session.waves_system._combo_parts(e)
			if not cf["els"].is_empty():
				rows.append({"els": cf["els"]})
				tip = "생길 조합: " + ", ".join(cf["names"])
			if cf["ups"] > 0:
				rows.append({"chip": "Lv↑ %d곳" % cf["ups"], "i": "place_on"})
		"pat":
			var id: String = card["id"]
			head["pat"] = id
			head["name"] = Pat.pname(id)
			rows = [{"t": Pat.PATTERNS[id]["desc"]}]
			foot = [["place_on", "직선탄에: 고정 · 같은 것에: Lv+"]]
			var fit := ""
			for t in session.towers.get_children():
				if t.pattern == id:
					fit = "Lv%d → Lv%d" % [t.plv, t.plv + 1]
					break
			if fit != "":
				rows.append({"chip": fit, "i": "place_on"})
			elif not session.towers.get_children().any(func(t): return t.pattern == Pat.DEFAULT):
				rows.append({"t": "넣을 수 있는 오브젝트 없음", "fs": 12, "c": Color(1, 0.6, 0.55)})
		"mod":
			var id: String = card["id"]
			head["name"] = Pat.MODS[id]["name"]
			rows = [{"t": "사거리 안 가까운 구체를 전방위로 조준해요. 최종 피해 -10% · 오브젝트당 1회" if id == "reflex" else Pat.mdesc(id)}]
			foot = [["place_on", "오브젝트당 1회" if id == "reflex" else "위에 놓기 · " + ("종류별 %d · 합 %d" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "쌓을수록 절반")]]
		"link":
			var id: String = card["id"]
			head["name"] = Pat.LINKS[id]["name"]
			rows = [{"t": Pat.ldesc(id)}]
			foot = [["place_on", "오브젝트 위에 놓기"]]
		"trig":
			var id: String = card["id"]
			head["name"] = Pat.TRIGS[id]["name"]
			rows = [{"t": Pat.tdesc(id)}]
			foot = [["place_on", "위에 놓기 · 종류별 5개"]]
	if lvl == 0:
		rows = _card_simple(card, rows)
		for f in foot:
			f[1] = _short(f[1]).get_slice(" · ", 0)
	return {"head": head, "rows": rows, "foot": foot, "tip": tip}


## 기본 카드에는 효과를 설명하는 문장을 남긴다. 모든 웨이브에서 같은 내용이며 자세히는 보존한다.
func _card_simple(card: Dictionary, rows: Array) -> Array:
	var out: Array = []
	if card["type"] == "elem":
		out.append({"t": Elem.BRIEF[card["e"]]})
		for r in rows:
			if r.has("els") or r.has("chip"):
				out.append(r)
		return out
	if card["type"] == "cata":
		return rows  # 다시 뽑는 대상·레벨 유지·즉시 발동 조건을 생략하지 않는다.
	var first := true
	for r in rows:
		if not r.has("t"):
			out.append(r)
		elif r.has("fs"):
			if r.get("c", Color.WHITE) != Color(1, 1, 1, 0.55):
				out.append(r)  # 넣을 수 없는 대상 경고는 남긴다.
		elif first:
			out.append({"t": Pat.brief(card["type"], card["id"], r["t"])})
			first = false
	return out


## 괄호 속 덧붙임을 뺀 짧은 글.
func _short(t: String) -> String:
	return short_re.sub(t, "", true).strip_edges()


## 자세히 + 올리기 창의 줄 [[글, 색]]: 앞면에 줄인 것까지 전부.
func _card_full(card: Dictionary) -> Array:
	var session: BinduSession = self.session
	var W := Color(1, 1, 1, 0.9)
	var D := Color(1, 1, 1, 0.6)
	var out: Array = []
	match card["type"]:
		"elem":
			var e: int = card["e"]
			out.append(["효과 (맞힌 구체에) · " + Elem.rider(e), Elem.COLORS[e].lightened(0.3)])
			out.append(["특징 (이 오브젝트의 효과를 다른 구체로) · " + Elem.TRAIT[e], W])
			var seen := {}
			for t in session.towers.get_children():
				if not t.can_take({"type": "elem", "e": e}):
					continue
				for r in Elem.new_reactions(t.elements, e):
					if seen.has(r["id"]):
						continue
					seen[r["id"]] = true
					var o: int = r["b"] if r["a"] == e else r["a"]
					out.append(["조합 %s (+%s) · %s" % [r["name"], Elem.NAMES[o], r["desc"]], r["color"]])
					if r.get("aff_txt", "") != "":
						out.append([r["aff_txt"], BinduSession.AFF_COL[r["aff"]]])
			var ups: int = session.waves_system._combo_parts(e)["ups"]
			if ups > 0:
				out.append(["%s 레벨업 가능 %d곳" % [Elem.NAMES[e], ups], D])
			out.append(["새 오브젝트로 놓거나 오브젝트 위에 겹치기" + (" (%d종까지)" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else " (종류마다 공격 속도 -%d%%)" % roundi(Rules.tax_step * 100)), D])
		"pat":
			var id: String = card["id"]
			out.append([Pat.PATTERNS[id]["desc"], W])
			var no := Pat.no_mods(id)
			if not no.is_empty():
				out.append(["못 넣는 강화(효과 없음): " + "·".join(no), D])
			for t in session.towers.get_children():
				if t.pattern == id:
					out.append(["%s Lv%d → Lv%d 가능" % [Pat.pname(id), t.plv, t.plv + 1], D])
			out.append(["직선탄 오브젝트에 넣으면 그 공격방식으로 고정돼요. 같은 공격방식에 넣으면 레벨업해요.", D])
		"mod":
			if card["id"] == "reflex":
				out.append(["전방위로 자동 조준해요. 최종 피해 -10%", W])
				out.append(["사거리 안 최근접 구체 · 오브젝트당 1회", D])
				out.append(["혼불·블랙홀에는 넣을 수 없어요.", D])
				return out
			out.append([Pat.mdesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기 · " + ("종류별 %d개, 합쳐 %d개까지" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "쌓을수록 효과 절반씩"), D])
		"link":
			out.append([Pat.ldesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기", D])
		"trig":
			out.append([Pat.tdesc(card["id"]), W])
			out.append(["오브젝트 위에 놓기 · 종류별 5개까지", D])
	return out


## [자세히]를 켠 채 카드에 올리면(터치는 한 번 눌러 미리보기) 카드 위에 모든 내용 창.
func _draw_card_full() -> void:
	var session: BinduSession = self.session
	if session.card_dock != null and session.card_dock.active():
		return
	if not Meta.card_detail or session.phase != BinduSession.Phase.CHOOSE or session.perk_mode or session.cards_hidden or not session.choice_box.visible or session.get_tree().paused:
		return
	var cs := session.choice_box.get_children()
	var hit: Button = null
	for i in cs.size():
		var b := cs[i] as Button
		if b == null or b.is_queued_for_deletion() or not b.has_meta("full"):
			continue
		if (session.touch_ui and i == session.tap_sel) or (not session.touch_ui and b.is_hovered()):
			hit = b
	if hit == null or (hit.get_meta("full") as Array).is_empty():
		return
	var inv := session.ui_root.get_global_transform().affine_inverse()
	var cr: Rect2 = inv * hit.get_global_rect()
	var row: Rect2 = inv * session.choice_box.get_global_rect()
	var top_lim := (session.hud.position.y + session.hud.size.y + 6.0) if session.hud.visible else 8.0
	var bot_lim := session.info.size.y - 8.0
	var side_room := session.info.size.x - row.end.x - 20.0
	var beside_guide := session.guide_label.visible and side_room >= 260.0
	var w := minf(420.0, side_room) if beside_guide else 420.0
	var fs := 14
	var rows: Array = []
	var lh := 0.0
	var h := 0.0
	# 화면 높이에 안 들어가면 글자를 한 단계씩 줄인다 (최소 12)
	while true:
		rows.clear()
		for l in hit.get_meta("full"):
			for t in session.onboarding_system._wrap_words(session.patchlog_system._kr_keep(l[0]), w - 20.0, fs).split("\n"):
				rows.append([t, l[1]])
		lh = fs + 6.0
		h = rows.size() * lh + 14.0
		if h <= bot_lim - top_lim or fs <= 12:
			break
		fs -= 1
	var x := clampf(cr.get_center().x - w / 2.0, 8.0, session.info.size.x - w - 8.0)
	var y := row.position.y - h - (44.0 if session.touch_ui else 30.0)  # 카드 줄 위 (고르기 꼬리표·[적용] 위)
	if beside_guide:
		x = row.end.x + 12.0
		y = clampf(row.position.y, top_lim, bot_lim - h)
	elif y < top_lim:
		y = clampf(row.end.y + 50.0, top_lim, bot_lim - h)  # 위에 자리가 없으면 아래 버튼 줄 밑, 화면 안으로
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	sb.border_color = Color(1, 0.85, 0.5, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	session.info.draw_style_box(sb, Rect2(x, y, w, h))
	# 어느 카드의 내용인지: 카드 쪽으로 작은 꼭지
	var tipx := clampf(cr.get_center().x, x + 12.0, x + w - 12.0)
	if y < row.position.y:
		session.info.draw_colored_polygon(PackedVector2Array([Vector2(tipx - 7, y + h), Vector2(tipx + 7, y + h), Vector2(tipx, y + h + 7)]), sb.bg_color)
	for i in rows.size():
		session.info.draw_string(session.ui_font, Vector2(x + 10.0, y + 7.0 + fs + i * lh), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, rows[i][1])


## 그림 카드: 머리(종류 그림·이름·Lv 배지, 번호는 오른쪽 위 작은 키)와 줄들을 직접 그린다 (버튼 글은 비움).
## head: kind·name·idx, 있으면 e(속성 그림)·pat(공격방식 그림)·lv·badge. rows: 줄마다 하나
##   {t: 글, i: 앞 그림(Glyph.ui id), fs, c, al(0 왼쪽 · 기본 가운데)} · {els: [짝 속성]} · {chip: 글, i} · {big: 글, i} · {pips: 보유 수}
## 높이는 내용에 맞춰 170~CARD_MAX_H, 넘치면 글자를 줄인다(최소 12).
func _card_paint(b: Button, head: Dictionary, rows: Array, foot: Array, col: Color, base_fs := 14, count := 3) -> void:
	var session: BinduSession = self.session
	b.text = ""
	var cw := 230.0 if count <= 3 else 166.0  # 4장일 때는 좁게
	var fs := base_fs
	var lay: Array = []
	var h := 0.0
	var pad := 54.0 + (24.0 if not foot.is_empty() else 8.0)
	while true:
		lay.clear()
		h = 0.0
		for r: Dictionary in rows:
			var f: int = mini(r.get("fs", fs), fs)
			var lh := 0.0
			var t := ""
			if r.has("els"):
				lh = 24.0
			elif r.has("chip"):
				lh = 28.0
			elif r.has("big"):
				lh = 44.0
			elif r.has("pips"):
				lh = 20.0
			elif r.has("pair"):
				lh = 28.0
			else:
				var w := cw - 24.0 - (20.0 if r.has("i") else 0.0)
				t = session.onboarding_system._wrap_words(session.patchlog_system._kr_keep(r["t"]), w, f)
				lh = session.ui_font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w, f).y + 4.0
			lay.append([r, t, f, lh])
			h += lh
		if h + pad <= BinduSession.CARD_MAX_H or fs <= 12:
			break
		fs -= 1
	b.custom_minimum_size = session.card_dock.card_size()
	b.clip_contents = true
	b.set_meta("card", [head, lay, h, not foot.is_empty()])
	b.set_meta("card_foot", foot)
	b.add_to_group("keycap")
	b.draw.connect(_draw_card.bind(b, col))


func _draw_card(b: Button, col: Color) -> void:
	var session: BinduSession = self.session
	session.card_dock.draw_card(b, col)


func _fav_tag(card: Dictionary) -> String:
	var session: BinduSession = self.session
	if Meta.favs.has(Codex.card_key(card)):
		return "★ 선호"
	if card["type"] == "elem":
		for t in session.towers.get_children():
			if not t.can_take(card):
				continue
			for r in Elem.new_reactions(t.elements, card["e"]):
				if Meta.favs.has("react:" + str(r["id"])):
					return "★ 선호 조합: " + str(r["name"])
	return ""


## 선호 카드 강조: 금색 테두리와 반짝임(Codex.Sparkle)을 얹는다.
func _mark_fav(b: Button, sb: StyleBoxFlat, sbh: StyleBoxFlat, tag: String) -> void:
	if tag == "":
		return
	for s: StyleBoxFlat in [sb, sbh]:
		s.border_color = Codex.FAV_COLOR
		s.set_border_width_all(maxi(s.border_width_left, 3))
	b.add_child(Codex.Sparkle.new(tag))


## 남은 고르기 수는 카드 위 배지(_draw_info)에 있어서, 조작 안내만 처음 세 판에 띄운다.
func _choose_hint() -> String:
	if Meta.games >= 3:
		return ""
	return "카드를 눌러 든 뒤 대상에 놓으세요. 카드에서 바로 끌어 놓을 수도 있어요."


# ---------- 튜토리얼 ----------

## 자동 튜토리얼 모달은 예약하지 않는다. 기존 이벤트 호출부는 짧은 안내와 함께 유지한다.
func _on_reroll() -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.CHOOSE or session.get_tree().paused or session.coin_stage > 0:
		return
	if session.perk_mode:
		_perk_reroll()
		return
	if session.rerolls_left <= 0:
		session.hud_system._show_toast("이번 쉬는 시간의 새로고침을 다 썼어요")  # Q를 눌러도 아무 일이 없던 것
		return
	session.rerolls_left -= 1
	Ach.on_reroll()
	_log_offer({})
	_make_choices()
	_update_reroll_btn()
	session.persistence_system._save_run()


## 특성 새로고침: 지금 나온 특성 말고 다른 것으로 3개를 다시 뽑는다 (모자라면 지금 것으로 채움).
func _perk_reroll() -> void:
	var session: BinduSession = self.session
	if session.perk_rerolls <= 0 or not _perk_can_reroll():
		session.hud_system._show_toast("이번 특성 선택의 새로고침을 다 썼어요")
		return
	session.perk_rerolls -= 1
	var now: Array = session.perk_offer.map(func(pk): return pk["id"])
	var pool := session.perks_system._perk_pool()
	var fresh: Array = pool.filter(func(pk): return not pk["id"] in now)
	var old: Array = pool.filter(func(pk): return pk["id"] in now)
	fresh.shuffle()
	old.shuffle()
	session.perk_offer = (fresh + old).slice(0, 3)
	session.perks_system._show_perks()
	session.persistence_system._save_run()


## 다시 뽑으면 다른 특성이 하나라도 나올 수 있는지
func _perk_can_reroll() -> bool:
	var session: BinduSession = self.session
	var now: Array = session.perk_offer.map(func(pk): return pk["id"])
	return session.perks_system._perk_pool().any(func(pk): return not pk["id"] in now)


## 새로고침 버튼: 남은 횟수를 같이 보여 준다.
## 선택지 내리기·올리기 (V): 카드에 가려진 필드를 본다. 마우스를 올린 오브젝트 범위·정보는 그대로 보인다.
func _toggle_cards_hidden() -> void:
	var session: BinduSession = self.session
	if session.card_dock.input_blocked():
		return
	_set_cards_hidden(not session.cards_hidden)


func _set_cards_hidden(h: bool) -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.CHOOSE:
		return
	session.cards_hidden = h
	session.choice_box.visible = not h
	session.hover_elem = -1
	_tap_hover()  # 다시 올리면 터치로 고르던 카드 미리보기도 다시
	_update_reroll_btn()


func _update_reroll_btn() -> void:
	var session: BinduSession = self.session
	if session.perk_mode:
		session.reroll_btn.visible = session.perk_rerolls > 0 and not session.cards_hidden and session.coin_stage == 0 and _perk_can_reroll()
		session.reroll_btn.text = str(session.perk_rerolls)
		session.reroll_btn.tooltip_text = "특성 새로고침 (Q): 이번 특성 선택에 %d번 남음" % session.perk_rerolls
		return
	session.reroll_btn.visible = session.rerolls_left > 0 and not session.cards_hidden  # 모드 '외길'은 늘 0
	session.reroll_btn.text = str(session.rerolls_left)
	session.reroll_btn.tooltip_text = "선택지 새로고침 (Q): 이번 쉬는 시간에 %d번 남음" % session.rerolls_left


## 진입 방향은 웨이브마다 조금씩 늘고, 가끔 하나가 옮겨 간다.
func _on_card_tap(card: Dictionary, _i: int) -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.CHOOSE or session.card_dock.suppress_tap or session.card_dock.input_blocked():
		return
	_on_pick(card)


func _release_card_tap_guard() -> void:
	var session: BinduSession = self.session
	session.card_dock.suppress_tap = false
	session.card_dock.touch_capture = false


## 터치로 고른(미리보기 중인) 카드의 속성 미리보기와 카드 진하기.
func _tap_hover() -> void:
	var session: BinduSession = self.session
	if session.tap_sel >= 0 and session.tap_sel < session.offer.size() and not session.cards_hidden:
		session.hover_elem = session.offer[session.tap_sel]["e"] if session.offer[session.tap_sel]["type"] == "elem" else -1
	var cs := session.choice_box.get_children()
	for k in cs.size():
		cs[k].modulate.a = 0.55 if session.tap_sel >= 0 and k != session.tap_sel else 1.0


func _on_pick(card: Dictionary) -> void:
	var session: BinduSession = self.session
	if TutPlay.on and session.tplay != null and not session.tplay.allow_pick(card):
		return
	session.persistence_system._save_run()  # 카드를 들고 앱을 닫아도 적용 전 목록과 남은 선택을 복원한다.
	session.tap_sel = -1
	_tap_hover()
	session.picked = card
	session.interaction_system.selected.clear()
	session.hover_elem = -1
	session.choice_box.visible = false
	session.reroll_btn.visible = false
	session.phase = BinduSession.Phase.PLACE
	session.card_dock.inspected_tower = null
	session.hint.text = session.ui_layout_system._th(_place_hint())
	if session.card_dock.active():
		session.card_dock.tick()


## 통계용 카드 이름: elem:fire, pat:spray, mod:rapid, link:reso
func _stat_key(card: Dictionary) -> String:
	if card.get("type", "") == "elem":
		return "elem:" + Patch.ELEM_KEYS[Elem.ALL.find(card["e"])]
	return "%s:%s" % [card.get("type", ""), card.get("id", "")]


## 이번 선택지와 고른 카드(빈 사전: 새로고침으로 넘김)를 판 기록에 남긴다.
func _log_offer(card: Dictionary) -> void:
	var session: BinduSession = self.session
	var e := {"w": session.wave, "k": "card", "o": session.offer.map(_stat_key), "p": _stat_key(card) if not card.is_empty() else ""}
	if not session.bank_picks.is_empty():
		e["bw"] = session.bank_picks[0]  # 넘기기로 미뤘던 고르기: 쌓은 쉬는 시간의 웨이브
	session.run_log.append(e)


func _place_hint() -> String:
	var session: BinduSession = self.session
	match session.picked.get("type", "elem"):
		"elem":
			return BinduSession.PLACE_HINT
	return "넣을 오브젝트를 클릭   꾹 누르기·끌기: 옮기기\n우클릭/Esc: 카드 다시 선택"


## card: 이번에 넣은 카드.
func _after_place(card: Dictionary = {}) -> void:
	var session: BinduSession = self.session
	_log_offer(session.picked if card.is_empty() else card)
	Ach.on_pick(_stat_key(session.picked if card.is_empty() else card))
	session.progression_system._check_progress()
	session.picks_left -= 1
	if not session.bank_picks.is_empty():
		session.bank_picks.pop_front()  # 미룬 고르기부터 쓴다
	if session.picks_left > 0:
		session.run_flow_system._start_choose(false)
	else:
		_enter_ready()
		if session.auto_start:
			session.countdown = 2.0


## 자동 시작이 꺼져 있을 때: 설치를 마치고 Space를 기다린다. 이때도 오브젝트를 옮길 수 있다.
func _enter_ready() -> void:
	var session: BinduSession = self.session
	session.phase = BinduSession.Phase.READY
	session.choice_box.visible = false
	session.reroll_btn.visible = false
	session.start_btn.visible = true
	session.start_btn.text = "웨이브 시작 (Space)"
	session.hint.text = session.ui_layout_system._th(BinduSession.READY_HINT if Meta.games < 3 else "")
	session.persistence_system._save_run()


func _start_wave_from_ready() -> void:
	var session: BinduSession = self.session
	if session.phase == BinduSession.Phase.READY:
		session.run_flow_system._start_wave()


## 버튼 위에 아이콘을 그린다. 글이 있으면 왼쪽, 없으면 가운데. icon은 [아이콘, 색]을 돌려준다.
func _icon_btn(b: Button, icon: Callable) -> void:
	# 벡터 아이콘을 덧그려도 native 버튼이 글 옆의 아이콘 공간을 확보하게 한다.
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	b.icon = ImageTexture.create_from_image(image)
	b.add_theme_constant_override("h_separation", 8)
	b.draw.connect(func():
		var ic: Array = icon.call()
		Glyph.ui(b, ic[0], _button_icon_center(b), 8.5, ic[1]))


func _button_icon_center(b: Button) -> Vector2:
	var style := b.get_theme_stylebox("normal")
	var left := style.get_content_margin(SIDE_LEFT)
	var width := b.size.x - left - style.get_content_margin(SIDE_RIGHT)
	var text_width := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
	var content_width := 18.0 + (text_width + b.get_theme_constant("h_separation") if b.text != "" else 0.0)
	return Vector2(left + (width - content_width) / 2.0 + 9, b.size.y / 2.0)


## 버튼 오른쪽 위 모서리에 작은 단축키 상자 (터치 화면에선 안 그림). key는 글 또는 글을 돌려주는 Callable.
func _keycap(b: Button, key: Variant) -> void:
	var session: BinduSession = self.session
	b.theme_type_variation = "ShortcutButton"
	b.add_to_group("keycap")
	b.draw.connect(func():
		var k: String = key.call() if key is Callable else key
		if not session.touch_ui and k != "":
			Glyph.keycap(b, session.ui_font, Vector2(b.size.x - 3.0, 3.0), k, 9))


## 메뉴 그림 버튼: 위에 그림, 아래 짧은 이름 (버튼 글은 비움).
func _menu_glyph(b: Button, icon: String, label: String) -> void:
	var session: BinduSession = self.session
	b.text = ""
	b.draw.connect(func():
		var hov := b.is_hovered()
		var c := Color(1, 1, 1, 1.0 if hov else 0.9)
		var fs := 13
		Glyph.ui(b, icon, Vector2(b.size.x / 2.0, b.size.y * 0.4), 10.0, c)
		b.draw_string(session.ui_font, Vector2(0, b.size.y - 7.0), label, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, fs, Color(c, 0.75)))


## 터치는 말풍선(tooltip)을 볼 수 없어 글 없는 아이콘 버튼이 무엇을 바꿨는지 몰랐다: 누르면 이름·상태를 잠깐 띄운다.
func _icon_toast(b: Button) -> void:
	var session: BinduSession = self.session
	if session.touch_ui and b.tooltip_text != "":
		session.hud_system._show_toast(session.ui_layout_system._kh(b.tooltip_text.get_slice("\n", 0)))


func _toggle_mute() -> void:
	var session: BinduSession = self.session
	session.sfx.set_muted(not session.sfx.muted)
	session.mute_btn.tooltip_text = "소리: " + ("끔" if session.sfx.muted else "켬") + " (M)"
	session.mute_btn.queue_redraw()
	session.progression_system._save_best()


func _toggle_auto() -> void:
	var session: BinduSession = self.session
	session.auto_start = not session.auto_start
	_update_auto_btn()
	session.progression_system._save_best()
	if session.auto_start and session.phase == BinduSession.Phase.READY:
		session.countdown = 2.0
	elif not session.auto_start:
		session.countdown = -1.0
		if session.phase == BinduSession.Phase.READY:
			session.start_btn.text = "웨이브 시작 (Space)"


func _toggle_legend() -> void:
	var session: BinduSession = self.session
	session.legend_hidden = not session.legend_hidden
	session.progression_system._save_best()


## 카드 도크·설명 칸을 접어 전장을 넓게 보거나 다시 연다 (F·모바일 버튼).
func _toggle_focus_view() -> void:
	_toggle_cards_hidden()


func _toggle_bar() -> void:
	var session: BinduSession = self.session
	session.bar_open = not session.bar_open
	session.progression_system._save_best()


func _update_auto_btn() -> void:
	var session: BinduSession = self.session
	session.auto_btn.tooltip_text = "자동 시작: " + ("켬" if session.auto_start else "끔") + " (웨이브가 끝나고 카드 선택을 마치면 바로 다음 웨이브)"
	session.auto_btn.queue_redraw()


var short_re := RegEx.create_from_string("\\s*\\([^)]*\\)")  # 카드 간소화: 괄호 덧붙임 빼기  # 그림이 붙는 앞줄들 (_draw_legend_icons)


## 오른쪽 설명 줄 앞 그림. 글자를 키우면 줄이 접히므로 앞줄들이 몇 줄로 접히는지 세어 자리를 맞춘다.
func _apply_card(target: Tower) -> void:
	var session: BinduSession = self.session
	if target == null:
		session.hud_system._show_toast("오브젝트 위에 놓으세요")
		return
	if not session.multiplayer_system._mine(target):
		session.hud_system._show_toast("친구가 놓은 오브젝트에는 넣을 수 없어요")
		return
	var msg := ""
	match session.picked["type"]:
		"pat":
			if not target.can_take(session.picked):
				session.hud_system._show_toast(target.refuse_text(session.picked))
				return
			msg = target.set_pattern(session.picked["id"])
		"mod":
			if not target.can_take(session.picked):
				session.hud_system._show_toast(target.refuse_text(session.picked))
				return
			msg = target.add_mod(session.picked["id"])
		"link":
			msg = target.add_link(session.picked["id"])
		"trig":
			if not target.can_take(session.picked):
				session.hud_system._show_toast(target.refuse_text(session.picked))
				return
			msg = target.add_trig(session.picked["id"])
	session.hud_system._show_toast(msg)
	session.sfx.play("place")
	session.spawning_system.burst(target.position, _card_color(session.picked), 16, 160.0)
	_after_place()


## 우클릭·Esc: 방향 고르기 → 위치 고르기 → 오브젝트 고르기 순으로 한 단계 되돌린다.
func star_full() -> bool:
	return Tower.star_count(session) >= int(Rules.t("star_max"))


## 이 카드가 별 카드인데 새로 놓을 수도, 넣을(레벨업할) 오브젝트도 없다.
func _star_blocked(card: Dictionary) -> bool:
	var session: BinduSession = self.session
	return card.get("type") == "elem" and card.get("e") == Elem.STAR and star_full() and not session.multiplayer_system._my_towers().any(func(t): return t.can_take(card))


## 특성 하나를 얻는다.
func _grant_perk(id: String) -> void:
	var session: BinduSession = self.session
	session.perks[id] = session.perks.get(id, 0) + 1
	session.perks_system._apply_perk(id)


## 쉬는 시간 [시작] 버튼 자리 (일반 판 도크가 옮겨 두면 원래 자리로).
func _start_btn_layout() -> void:
	var session: BinduSession = self.session
	if session.start_btn.anchor_top != 1.0:
		session.start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		session.start_btn.position = Vector2(-110, -100)
		session.start_btn.size = Vector2(220, 44)
