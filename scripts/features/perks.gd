class_name BinduPerks
extends BinduFeature
## 특성·동전·중앙 방어 효과. 예약 콜백은 main의 순서를 따른다.

var perk_press: Button = null  # 누르고 있는 특성 카드 (길게 누르기)
var perk_peek: Button = null  # 길게 눌러 자세히를 띄운 특성 카드 (손을 떼도 고르지 않음)
var coin_anim := DisplayServer.get_name() != "headless"
var coin_t := 0.0
var coin_ang := 0.0  # 회전각. 가로 폭 = cos(각), 양수면 앞면이 보임
var coin_ang0 := 0.0
var coin_spin := 0.0  # 떨어지는 동안 더 돌 각도 (끝에서 모서리가 서게 맞춤)
var coin_tap_t := 0  # 마지막으로 누른 때(ms), 터치가 마우스로도 와서 두 번 눌리지 않게
func _lv2_chance() -> float:
	var session: BinduSession = self.session
	var w: int = session.bank_picks[0] if not session.bank_picks.is_empty() else session.wave  # 미룬 고르기는 쌓은 때의 웨이브로 (미뤄서 Lv2가 더 잘 나오지 않게)
	var lv2 := minf(Patch.num("cards", "lv2_base", 0.2) + Patch.num("cards", "lv2_wave", 0.02) * w, Patch.num("cards", "lv2_max", 0.5))
	return lv2 + _perk_val("luck") * session.perks.get("luck", 0)


func _start_perk() -> void:
	var session: BinduSession = self.session
	var pool := _perk_pool()
	if pool.is_empty():
		session.bank_perks = 0
		session.hud_system._show_toast("사용 가능한 특성 카드가 없어 이번 선택을 건너뜁니다")
		session.run_flow_system._start_choose(not session.rest_ready)
		return
	pool.shuffle()
	session.perk_offer = pool.slice(0, 3)
	if TutPlay.on and not session.perk_offer.any(func(pk): return pk["id"] == "coin"):
		var coin: Array = pool.filter(func(pk): return pk["id"] == "coin")
		if not coin.is_empty() and not session.perk_offer.is_empty():
			session.perk_offer[session.perk_offer.size() - 1] = coin[0]  # 연습 판: 운명의 동전도 한 번 보여 준다
	if session.coin_next == "":
		session.perk_rerolls = 0 if Modes.has("narrow") else 1  # 동전 뒤 새 3개는 같은 선택이라 다시 주지 않음
	_show_perks()
	if session.coin_next == "":
		session.hud_system.big_banner("특성 선택", Color(1, 0.85, 0.45))
	session.persistence_system._save_run()


## 지금 선택지에 나올 수 있는 특성들
func _perk_pool() -> Array:
	var session: BinduSession = self.session
	var pool: Array = BinduSession.PERKS.filter(func(pk): return session.cards_system._card_enabled({"type": "perk", "id": pk["id"]}))
	if Modes.has("narrow"):
		pool = pool.filter(func(pk): return not pk["id"] in ["reroll", "coin"])  # 외길: 새로고침이 없으니 쓸모없는 특성은 빼고 (동전 뒷면도 새로고침)
	if session.coin_next != "":
		pool = pool.filter(func(pk): return pk["id"] != "coin")  # 던진 동전의 결과를 받을 차례
	# 더 골라도 거의 효과가 없는 특성은 빼고: 이미 거의 Lv2로 나오는 행운, 조화(한 번만, 2026-11-01: 도파민에서 겹치고 속성을 많이 쌓으면 속사보다 훨씬 셌음).
	# 동전 앞면(두 번 적용)일 때도 조화는 한 번만 효과가 있어 뺀다
	pool = pool.filter(func(pk): return not (pk["id"] == "luck" and _lv2_chance() >= 0.9 or pk["id"] == "harmony" and (session.perks.has("harmony") or session.coin_next == "double")))
	# 넣어도 효과가 없는 중앙 특성은 빼고: 벽 오브젝트가 없을 때 성벽, 이미 최대인 실드·성벽
	pool = pool.filter(func(pk): return not (pk["id"] == "rampart" and (not _has_wall() or _rampart_n() >= int(_perk_val("rampart_max")))
		or pk["id"] == "shield" and _shield_wave() >= int(_perk_val("shield_max"))
		or pk["id"] == "overflow" and session.perks.has("overflow")
		or pk["id"] == "quick" and (session.skill_ids.is_empty() or session.perks.get("quick", 0) >= 3)))
	return pool


## 특성 고르기 화면 (perk_offer는 이미 정해져 있음).
func _show_perks() -> void:
	var session: BinduSession = self.session
	session.phase = BinduSession.Phase.CHOOSE
	session.wave_active = false
	session.perk_mode = true
	session.cards_system._clear_shots()
	for c in session.choice_box.get_children():
		c.queue_free()
	for i in session.perk_offer.size():
		var pk: Dictionary = session.perk_offer[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 170)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.11, 0.06, 0.96)
		sb.border_color = Color(1, 0.8, 0.35, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		var sbh := sb.duplicate()
		sbh.bg_color = Color(0.2, 0.17, 0.09, 0.98)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		var have: int = session.perks.get(pk["id"], 0)
		var coin: String = {"double": "동전 앞면: 두 번 적용", "reroll": "동전 뒷면: + 새로고침 %d" % int(_perk_val("coin"))}.get(session.coin_next, "")
		var rows: Array = []
		var desc := _perk_desc(pk)
		var big := _perk_big(pk["id"], desc)
		if big.is_empty():
			rows.append({"t": desc, "fs": 16})
		else:
			rows.append(big)
			b.tooltip_text = ""
		if have > 0:
			rows.append({"pips": mini(have, 8)})
		if coin != "":
			rows.append({"t": coin, "fs": 13, "c": Color(1, 0.85, 0.45)})
		session.cards_system._card_paint(b, {"kind": "perk", "name": pk["name"], "idx": i + 1}, rows, [], Color(1, 0.85, 0.45), 16, session.perk_offer.size())
		b.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
		b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("perk_desc", desc + ("\n\n" + coin if coin != "" else ""))
		b.mouse_entered.connect(func():
			session.card_dock.inspected_tower = null
			session.card_dock.hovered = b)
		# 터치는 올리기가 없어 누르면 바로 골라졌다: 길게 누르면(0.45초) 고르지 않고 오른쪽에 자세히
		b.gui_input.connect(func(ev: InputEvent):
			if session.touch_ui and (ev is InputEventScreenTouch or (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT)):
				if ev.pressed:
					perk_press = b
					# 0.45초 안에 골라 버튼이 지워질 수 있다: 버튼을 직접 잡으면 엔진이 "Lambda capture … freed" 오류를 낸다
					var bref: WeakRef = weakref(b)
					session.get_tree().create_timer(0.45).timeout.connect(func():
						var bb: Button = bref.get_ref()
						if bb != null and is_instance_valid(session) and perk_press == bb and session.perk_mode:
							perk_peek = bb
							session.card_dock.inspected_tower = null
							session.card_dock.hovered = bb)
				else:
					perk_press = null)
		b.pressed.connect(func():
			if perk_peek == b:
				perk_peek = null  # 길게 눌러 본 것: 고르지 않음
				return
			_on_perk(pk))
		session.cards_system._mark_fav(b, sb, sbh, "★ 선호" if Meta.favs.has("perk:" + str(pk["id"])) else "")
		session.choice_box.add_child(b)
	session.cards_hidden = false
	session.choice_box.visible = true
	session.cards_system._update_reroll_btn()
	match session.coin_next:
		"double": session.hint.text = session.ui_layout_system._th("동전 앞면! 고르는 특성이 두 번 적용돼요")
		"reroll": session.hint.text = session.ui_layout_system._th("동전 뒷면! 고르는 특성에 더해 이번 쉬는 시간 새로고침 +%d" % int(_perk_val("coin")))
		_: session.hint.text = session.ui_layout_system._th("특성을 하나 고르세요. 이번 판 끝까지 유지됩니다")


func _on_perk(pk: Dictionary) -> void:
	var session: BinduSession = self.session
	if not session.perk_mode or session.coin_stage > 0:
		return
	session.perk_mode = false
	var id: String = pk["id"]
	session.perks[id] = session.perks.get(id, 0) + 1
	session.run_log.append({"w": session.wave, "k": "perk", "o": session.perk_offer.map(func(x): return "perk:" + x["id"]), "p": "perk:" + id})

	Ach.on_pick("perk:" + id)
	if id == "coin":
		# 운명의 동전: 지금 던지고 특성 3개를 새로 받는다 (뒷면도 보통 특성 하나보다 조금 낫게)
		session.coin_next = "double" if randf() < 0.5 else "reroll"
		if coin_anim:
			_coin_throw()
		else:
			_coin_done()
		return
	_apply_perk(id)
	session.multiplayer_system._mp_send_perk(id)
	var note := ""
	match session.coin_next:
		"double":
			session.perks[id] += 1
			_apply_perk(id)
			session.multiplayer_system._mp_send_perk(id)
			note = " · 동전 앞면: 두 번"
		"reroll":
			session.rerolls_left += int(_perk_val("coin"))
			note = " · 동전 뒷면: 새로고침 +%d" % int(_perk_val("coin"))
	session.coin_next = ""
	session.sfx.play("reaction", 0.0)
	session.hud_system._show_toast("특성: %s (%s)%s" % [pk["name"], _perk_desc(pk), note])
	for t in session.towers.get_children():
		t.queue_redraw()
	if session.bank_perks > 0:
		session.bank_perks -= 1  # 미룬 특성을 이어서
		_start_perk()
	else:
		session.run_flow_system._start_choose(not session.rest_ready)


## 동전을 던진다: 카드를 치우고 공중에서 돌리기 시작.
func _coin_throw() -> void:
	var session: BinduSession = self.session
	for c in session.choice_box.get_children():
		c.queue_free()
	session.choice_box.visible = false
	session.reroll_btn.visible = false
	session.banner_t = 0.0  # "특성 선택" 글이 남아 결과 글이 뒤로 밀리지 않게
	session.banner_queue.clear()
	session.toast_timer = 0.0
	session.coin_stage = 1
	coin_t = 0.0
	coin_ang = 0.0
	session.coin_fx.visible = true
	session.coin_fx.mouse_filter = Control.MOUSE_FILTER_STOP
	session.hint.text = session.ui_layout_system._th("동전을 던졌어요! 눌러서 잡기 · 한 번 더 누르면 바로 결과")
	session.sfx.play("place")


## 누르기·Space: 공중이면 떨어뜨리고, 떨어지는 중이면 결과로, 결과가 떠 있으면 바로 카드로.
func _coin_tap() -> void:
	var session: BinduSession = self.session
	if session.coin_stage == 0 or Time.get_ticks_msec() - coin_tap_t < 150:
		return
	coin_tap_t = Time.get_ticks_msec()
	match session.coin_stage:
		1: _coin_drop()
		2, 3: _coin_land()
		4: _coin_done()


func _coin_drop() -> void:
	var session: BinduSession = self.session
	session.coin_stage = 2
	coin_t = 0.0
	coin_ang0 = coin_ang
	# 처음 속도(초당 22)에서 고르게 느려져 0.85초 뒤 가로 폭 0(모서리)이 되게: 끝 각도 = (n + 0.5)π
	coin_spin = ceilf((coin_ang0 + 9.35 - PI / 2.0) / PI) * PI + PI / 2.0 - coin_ang0


func _coin_land() -> void:
	var session: BinduSession = self.session
	session.coin_stage = 4
	coin_t = 0.0
	session.sfx.play("crit")
	session.sfx.play("reaction", 0.0)
	session.hud_system.big_banner("동전 앞면! 두 번 적용" if session.coin_next == "double" else "동전 뒷면! 새로고침 +%d" % int(_perk_val("coin")), Color(1, 0.85, 0.3) if session.coin_next == "double" else Color(0.7, 0.82, 1.0))


## 연출이 끝나 결과대로 특성 3개를 새로 받는다.
func _coin_done() -> void:
	var session: BinduSession = self.session
	session.coin_stage = 0
	Ach.on_coin(session.coin_next == "double")
	session.progression_system._ach_check()
	if session.coin_fx:
		session.coin_fx.visible = false
		session.coin_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not coin_anim:
		session.sfx.play("crit")
		session.hud_system.big_banner("동전 앞면!" if session.coin_next == "double" else "동전 뒷면!", Color(1, 0.85, 0.3))
	_start_perk()


func _coin_step(delta: float) -> void:
	var session: BinduSession = self.session
	coin_t += delta
	var was := cos(coin_ang) > 0.0
	match session.coin_stage:
		1:
			coin_ang += 22.0 * delta
			if coin_t >= 1.0:
				_coin_drop()
		2:
			var k := minf(coin_t / 0.85, 1.0)
			coin_ang = coin_ang0 + coin_spin * (1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				session.coin_stage = 3
				coin_t = 0.0
				session.sfx.play("place", 0.0)
		3:
			if coin_t >= 0.5:
				_coin_land()
		4:
			if coin_t >= 0.75:
				_coin_done()
				return
	if session.coin_stage in [1, 2] and (cos(coin_ang) > 0.0) != was:
		session.sfx.play("hit", 0.02)  # 면이 바뀔 때마다 띵 (느려질수록 뜸해진다)
	session.coin_fx.queue_redraw()


func _draw_coin() -> void:
	var session: BinduSession = self.session
	var sz := session.coin_fx.size
	var c := sz / 2.0 + Vector2(0, 40)  # 결과 글(banner, 가운데 -140)이 동전 위에 오게
	var air := c.y - 120.0
	var fade := minf(coin_t / 0.2, 1.0) if session.coin_stage == 1 else 1.0
	session.coin_fx.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.62 * fade))
	var y := air + sin(coin_t * 5.0) * 6.0
	var sx := cos(coin_ang)
	var rot := 0.0
	var r := 52.0
	var front := sx > 0.0
	match session.coin_stage:
		2:
			var k := minf(coin_t / 0.85, 1.0)
			y = lerpf(air, c.y, k * k)
			r = lerpf(52.0, 58.0, k)
		3:
			# 모서리로 서서 흔들림: 어느 쪽으로 쓰러질지 모르게 양쪽으로 기울었다 돌아온다
			var k := coin_t / 0.5
			y = c.y
			r = 58.0
			rot = sin(coin_t * 19.0) * 0.28 * (1.0 - k * 0.6)
			sx = 0.1 * sin(coin_t * 27.0)
			front = sx > 0.0
			session.coin_fx.draw_string(session.ui_font, Vector2(c.x - 40, c.y + 110), "…?", HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Color(1, 1, 1, 0.9))
		4:
			var k := minf(coin_t / 0.12, 1.0)
			y = c.y
			front = session.coin_next == "double"
			sx = k if front else -k
			r = 58.0 * (1.0 + 0.25 * maxf(0.0, 1.0 - coin_t / 0.25))
			var col := Color(1, 0.82, 0.35) if front else Color(0.68, 0.8, 0.95)
			var ray_a := Time.get_ticks_msec() / 1000.0 * 0.6
			var rl := 190.0 * minf(coin_t / 0.15, 1.0)
			for i in 16:
				var a := ray_a + i * TAU / 16.0
				session.coin_fx.draw_colored_polygon(PackedVector2Array([Vector2(c.x, y), Vector2(c.x, y) + Vector2.from_angle(a) * rl, Vector2(c.x, y) + Vector2.from_angle(a + 0.09) * rl]), Color(col, 0.22))
			for i in 8:
				session.coin_fx.draw_circle(Vector2(c.x, y), r * (2.6 - i * 0.2), Color(col, 0.05))
	if session.coin_stage == 1:
		session.coin_fx.draw_string(session.ui_font, Vector2(c.x - 200, c.y + 60), session.ui_layout_system._th("눌러서 잡기"), HORIZONTAL_ALIGNMENT_CENTER, 400, 28, Color(1, 1, 1, 0.95 * fade))
		session.coin_fx.draw_string(session.ui_font, Vector2(c.x - 200, c.y + 92), "운명의 동전", HORIZONTAL_ALIGNMENT_CENTER, 400, 18, Color(1, 0.85, 0.45, 0.8 * fade))
	if session.coin_stage in [1, 2]:
		# 잔상: 조금 전 위치의 흐린 동전
		_coin_disc(Vector2(c.x, y - 14.0), r, cos(coin_ang - 0.35), 0.0, cos(coin_ang - 0.35) > 0.0, 0.25)
	_coin_disc(Vector2(c.x, y), r, sx, rot, front, 1.0)


## 동전 한 개. sx: 가로 폭(-1~1, 0이면 모서리). 앞면은 금색에 가운데 점(빈두), 뒷면은 은색에 새로고침 화살표.
func _coin_disc(p: Vector2, r: float, sx: float, rot: float, front: bool, a: float) -> void:
	var session: BinduSession = self.session
	var w := maxf(absf(sx), 0.07)
	var face := Color(1, 0.8, 0.35, a) if front else Color(0.68, 0.8, 0.95, a)
	var dark := Color(0.62, 0.42, 0.12, a) if front else Color(0.3, 0.4, 0.58, a)
	var th := 3.0 + 6.0 * (1.0 - absf(sx))  # 옆으로 누울수록 두께가 보인다
	session.coin_fx.draw_set_transform(p, rot, Vector2(w, 1.0))
	session.coin_fx.draw_circle(Vector2(th / w, 0), r, dark)
	session.coin_fx.draw_circle(Vector2.ZERO, r, face)
	session.coin_fx.draw_arc(Vector2.ZERO, r - 2.0, 0, TAU, 40, dark, 4.0 / w)
	if absf(sx) > 0.3:
		session.coin_fx.draw_arc(Vector2.ZERO, r * 0.62, 0, TAU, 40, dark, 3.0 / w)
		if front:
			session.coin_fx.draw_circle(Vector2.ZERO, r * 0.16, dark)
		else:
			session.coin_fx.draw_arc(Vector2.ZERO, r * 0.32, 0.7, TAU - 0.5, 24, dark, 4.0 / w)
			var tip := Vector2.from_angle(0.7) * r * 0.32
			session.coin_fx.draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -2), tip + Vector2(7, -6), tip + Vector2(2, 9)]), dark)
	session.coin_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _apply_perk(id: String) -> void:
	var session: BinduSession = self.session
	match id:
		"power": Tower.dmg_mul += _perk_val("power")
		"haste": Tower.spd_mul += _perk_val("haste")
		"reach": Tower.reach_mul += _perk_val("reach")
		"core":
			session.core_max += int(_perk_val("core"))
			session.core_hp = session.core_max
		"slow": session.orb_speed_mul *= 1.0 - _perk_val("slow")
		"harmony": Tower.tax_step = minf(Tower.tax_step, Rules.tax_step * _perk_val("harmony"))  # 한 번만 (동전 앞면·옛 저장에서 두 번 와도 같게)


## 특성 수치 (온라인 패치 perks로 바뀔 수 있음). 설명 글도 같이 바꿔야 하면 perk_desc. coin: 동전 뒷면 새로고침 수
func _shield_wave() -> int:
	var session: BinduSession = self.session
	return mini(session.perks.get("shield", 0) * int(_perk_val("shield")), int(_perk_val("shield_max")))


## 넘친 회복으로 남길 수 있는 실드 (모든 실드 합이 shield_all을 넘지 않게).
func _keep_cap() -> int:
	var session: BinduSession = self.session
	if not session.perks.has("overflow"):
		return 0
	return maxi(0, mini(int(_perk_val("overflow")), int(_perk_val("shield_all")) - _shield_wave()))


## 중앙 체력 회복. 넘친 회복 특성이 있으면 가득 차서 넘친 만큼 실드로.
func _heal_core(n: int) -> void:
	var session: BinduSession = self.session
	var room := maxi(session.core_max - session.core_hp, 0)
	session.core_hp += mini(n, room)
	var over := mini(n - room, _keep_cap() - session.shield_keep)
	if over > 0:
		session.shield_keep += over
		session.spawning_system.popup(session.viewport_system.core() + Vector2(0, -BinduSession.CORE_RADIUS - 24.0), over, Color(0.55, 0.85, 1.0), true, "실드 +%d" % over, 1.0)


## 성벽 조각 수: 벽 공격방식 오브젝트의 레벨 합 + 고른 횟수.
func _rampart_n() -> int:
	var session: BinduSession = self.session
	var n: int = session.perks.get("rampart", 0)
	if n == 0:
		return 0
	for t in session.multiplayer_system._my_towers():
		if t.pattern == "wall":
			n += t.plv
	return mini(n * int(_perk_val("rampart")), int(_perk_val("rampart_max")))


func _has_wall() -> bool:
	var session: BinduSession = self.session
	return session.multiplayer_system._my_towers().any(func(t): return t.pattern == "wall")


## 실드가 먼저 막는다 (이번 웨이브 실드 → 남는 실드). 막은 양을 돌려준다.
func _shield_absorb(dmg: int) -> int:
	var session: BinduSession = self.session
	var a := mini(session.shield, dmg)
	session.shield -= a
	var b := mini(session.shield_keep, dmg - a)
	session.shield_keep -= b
	return a + b


## 반격 파동: 중앙 근처 구체를 밀어내고 피해 (보통 구체 체력의 riposte배, 겹치면 하나당 +riposte_more).
func _riposte(p: Vector2) -> void:
	var session: BinduSession = self.session
	if session.riposte_cd > 0.0:
		return
	session.riposte_cd = 0.25
	var r := _perk_val("riposte_r")
	var base: float = (1.0 + floorf(session.wave * 0.7)) * session.hp_growth(session.wave) * Rules.orb_hp * Vary.hp_k()
	var dmg: float = base * _perk_val("riposte") * (1.0 + _perk_val("riposte_more") * (session.perks.get("riposte", 1) - 1))
	for o in session.combat_system.near(p, r):
		if o.hp <= 0.0 or o.ghost:
			continue
		var d: float = o.position.distance_to(p)
		if d < r + o.radius():
			o.hurt(dmg)
			o.knock((o.position - p).normalized() * 60.0 if d > 0.1 else Vector2.ZERO)
	if session.core_fx.size() < 20:
		session.core_fx.append([p, r, BinduSession.FX_RIPOSTE])


## 회복 특성이 이번 웨이브에 채우는 체력. 처음 고른 것은 regen(1), 겹친 것은 하나당 regen_more(0.5)이고, 1이 안 되는 나머지는 다음 웨이브로 넘긴다.
func _regen_take() -> int:
	var session: BinduSession = self.session
	session.regen_acc += _perk_val("regen") + _perk_val("regen_more") * (session.perks.get("regen", 0) - 1)
	var h := int(session.regen_acc)
	session.regen_acc -= h
	return h


func _perk_val(id: String) -> float:
	return Patch.num("perks", id, BinduSession.PERK_VALS[id])


## 숫자 하나로 끝나는 특성은 그림 + 숫자로 (설명 글은 말풍선). 패치로 설명이 바뀌어 숫자를 못 찾으면 글 그대로.
func _perk_big(id: String, desc: String) -> Dictionary:
	var session: BinduSession = self.session
	if not BinduSession.PERK_GLYPH.has(id):
		return {}
	if id == "regen" and session.perks.get("regen", 0) > 0:  # 이미 있으면 겹친 회복 값
		return {"big": "+%s/웨이브" % String.num(_perk_val("regen_more")), "i": BinduSession.PERK_GLYPH[id]}
	var re := RegEx.create_from_string("[+-]\\d+(\\.\\d+)?%?")
	var mm := re.search(desc)
	if mm == null:
		return {}
	return {"big": mm.get_string() + ("/웨이브" if id == "regen" else ""), "i": BinduSession.PERK_GLYPH[id]}


func _perk_desc(pk: Dictionary) -> String:
	return Patch.text("perk_desc", pk["id"], pk["desc"])


func _perk_text() -> String:
	var session: BinduSession = self.session
	var parts := PackedStringArray()
	for pk in BinduSession.PERKS:
		var n: int = session.perks.get(pk["id"], 0)
		if n > 0:
			parts.append(pk["name"] + (" x%d" % n if n > 1 else ""))
	return "특성: " + ", ".join(parts) if not parts.is_empty() else ""
