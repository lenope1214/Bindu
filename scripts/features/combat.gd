class_name BinduCombat
extends BinduFeature
## 게임 시간 조각·전투 판정·격자 조회. 예약 콜백은 main의 순서를 따른다.

var star_towers: Array = []  # 별이 든 오브젝트 (둘레 피해를 별빛으로 모은다, 매 계산마다 갱신)
var targets: Array = []  # 화면 안에 들어온 구체 (공격 대상)
var prof := {}
var ach_dirty := false  # 이번 프레임에 처치가 있었다: 업적 조건을 한 번 본다
func _sim_step(delta: float) -> void:
	var session: BinduSession = self.session
	session.sim_id += 1
	var us := Time.get_ticks_usec() if session.prof_on else 0
	for layer in [session.orbs, session.projectiles, session.zones]:
		for n in layer.get_children():
			if not n.is_queued_for_deletion():
				n.step(delta)
	if session.prof_on:
		_prof_add("이동", us)

	if session.mp_extra_left > 0 and not session.mp_ghost:
		session.multiplayer_system._mp_spawn_extra(delta)
	if session.to_spawn > 0:
		session.spawn_timer -= delta
		if session.spawn_timer <= 0.0:
			# 가끔 몰려서 나온다
			session.spawn_timer = session.spawn_interval * (0.5 if randf() < 0.2 and session.wave >= 4 else 1.0)
			session.to_spawn -= 1
			# 5웨이브마다 마지막에 보스
			var boss := session.to_spawn == 0 and session.wave % 5 == 0
			session.spawning_system._spawn_orb(Orb.Kind.BOSS if boss else -1, session.boss_plan if boss and session.boss_plan.get("wave", -1) == session.wave else {})
			if boss:
				session.boss_plan = {}
				session.hud_system.big_banner("보스 등장!", Color(1, 0.35, 0.4))
				session.sfx.play("boss", 0.0)

	session.wave_time += delta
	session.run_game += delta
	session.hud_system._dps_sample(delta)
	session.abilities_system._skill_tick(delta)
	# 콤보 유지 시간은 게임 시간으로 잰다: 배속을 올려도 점수가 달라지지 않는다
	if session.combo_t > 0.0 and not session.combo_hold:
		session.combo_t = maxf(session.combo_t - delta, 0.0)
		if session.combo_t <= 0.0 and session.combo >= 5:
			session.combo_end = [session.combo, session.combo_bonus, 1.5]
	_resolve(delta)
	session.spawning_system._jam_tick()

	if session.mp_ghost:
		return  # 협동 참가자: 웨이브 끝·게임 오버는 호스트가 알려 준다
	if session.core_hp <= 0:
		session.run_flow_system._game_over()
	elif session.to_spawn == 0 and session.mp_extra_left == 0 and _alive_count(session.orbs) == 0:
		session.combo_hold = true  # 쉬는 시간·카드 고르기 동안 콤보가 끊기지 않게
		_log_wave()
		Vary.wave_done(session.wave, session.multiplayer_system._my_towers())
		session.progression_system._achieve("first")
		Ach.on_wave_clear(session.wave, session.wave_dmg, session.core_hp, session.core_max)
		session.progression_system._ach_check()
		if session.wave >= 5 and session.mp_mode == "" and not TutPlay.on:
			Meta.map_best[Meta.run_key()] = [maxi(Meta.best_of(Meta.run_key())[0], session.wave), maxi(Meta.best_of(Meta.run_key())[1], session.score)]
			if Meta.MAP_IDS.all(func(id): return id in Meta.TRIAL_MAPS or Meta.best_of(Meta.key(id))[0] >= 5):
				session.progression_system._achieve("allmaps")
		var bonus := int(session.wave * 20 * Modes.mul())
		session.score += bonus
		session.hud_system._show_toast("웨이브 %d 클리어! +%d" % [session.wave, bonus])
		session.sfx.play("clear", 0.0)
		session.spawning_system._show_mvp()
		if session.perks.has("regen"):
			session.perks_system._heal_core(session.perks_system._regen_take())
		if session.wave % 5 == 0:
			session.online_system._submit_run(false)  # 5웨이브마다 진행 중 기록 (중간에 꺼도 서버에 남게)
		session.multiplayer_system._mp_wave_cleared()
		if session.skip_left > 1 and not session.skip_stop:
			session.skip_left -= 1
			session.run_flow_system._skip_rest()
		elif session.skip_left > 0:
			session.run_flow_system._end_skip(false)
		elif session.wave % 5 == 0:
			session.perks_system._start_perk()
		else:
			session.run_flow_system._start_choose()


## 중앙 체력 비율로 위험 단계를 정한다. 단계가 올라가는 순간에만 큰 글·경고음 (설정에 따라 1배속).
## 회복해서 단계가 내려가면 다시 떨어질 때 또 알린다.
func _danger_of(hp: int) -> int:
	var session: BinduSession = self.session
	if hp <= 0 or hp * 4 <= session.core_max:
		return 2
	return 1 if hp * 2 <= session.core_max else 0


func _check_danger() -> void:
	var session: BinduSession = self.session
	var lv := _danger_of(session.core_hp)
	if lv > session.danger_lv and session.core_hp > 0:
		session.hud_system.big_banner("중앙 위험! %d/%d" % [session.core_hp, session.core_max], Color(1, 0.3, 0.35) if lv == 2 else Color(1, 0.6, 0.3))
		session.sfx.play("danger", 0.0)
		if session.skip_left > 0 and not session.skip_stop and Meta.skip_danger:
			session.skip_stop = true
			session.hud_system._show_toast("중앙 위험: 이번 웨이브가 끝나면 넘기기를 멈춰요")
		if Meta.danger_slow and session.game_speed > 1.0:
			session.game_speed = 1.0
			session.run_flow_system._update_speed_btn()
			session.hud_system._show_toast("중앙 위험: 1배속으로 바꿨어요 (Space로 다시 빠르게)")
	session.danger_lv = lv


## 구체가 중앙 점에 닿았나. 회랑 맵은 끝의 문(세로선)에 닿으면.
## 구체가 중앙에서 r 안에 들어왔나 (회랑 맵은 문까지의 가로 거리).
func _near_core(o: Orb, r: float) -> bool:
	var session: BinduSession = self.session
	if Meta.map_id == "line":
		return absf(o.position.x - session.viewport_system.core().x) < r + o.radius()
	return o.position.distance_to(session.viewport_system.center()) < r + o.radius()


func _reached_core(o: Orb) -> bool:
	var session: BinduSession = self.session
	if Meta.map_id == "line":
		return absf(o.position.x - session.viewport_system.core().x) < BinduSession.CORE_RADIUS + o.radius()
	return o.position.distance_to(session.viewport_system.center()) < BinduSession.CORE_RADIUS + o.radius()


## 중앙에 닿은 구체를 기록하고, 그 구체가 들어온 화면 가장자리를 붉게 번지게 한다.
func _record_leak(o: Orb, hp_lost: int) -> void:
	var session: BinduSession = self.session
	session.wave_leaks.append([_lane_of(o.from_a), o.kind, o.core_dmg, hp_lost])
	session.leak_flash.append([Vector2(session.viewport_system.core().x, o.position.y) if Meta.map_id == "line" else _entry_point(o.from_a), 1.2])
	session.onboarding_system._guide("leak", "구체가 중앙에 닿았어요. 붉게 번쩍인 가장자리 쪽 길목이 비어 있어요. 쉬는 시간에 그쪽으로 오브젝트를 옮기거나 새로 놓으세요")


## 각도 a에서 가장 가까운 진입 방향 번호 (없으면 -1).
func _lane_of(a: float) -> int:
	var session: BinduSession = self.session
	var best := -1
	var bd := INF
	for i in session.lanes.size():
		var d := absf(angle_difference(a, session.lanes[i]))
		if d < bd:
			bd = d
			best = i
	return best


## 각도 a에서 나온 구체가 화면에 들어오는 자리 (소용돌이 맵은 나선을 따라).
func _entry_point(a: float) -> Vector2:
	var session: BinduSession = self.session
	if Meta.map_id == "spiral":
		var vr := session.viewport_system.arena()
		for q in session.spawning_system._orb_path(a):
			if vr.has_point(q):
				return q
	return session.field_view_system._edge_point(session.viewport_system.center(), Vector2.from_angle(a))


## 8방위 이름 (화면 위가 북).
func _log_wave() -> void:
	var session: BinduSession = self.session
	if session.wave <= 0 or (not session.leak_log.is_empty() and session.leak_log[-1]["w"] == session.wave):
		return
	var by_lane := {}
	var kinds := {}
	var kdmg := {}
	var dmg := 0
	var lost := 0
	for l in session.wave_leaks:
		by_lane[l[0]] = by_lane.get(l[0], 0) + 1
		kinds[l[1]] = kinds.get(l[1], 0) + 1
		kdmg[l[1]] = kdmg.get(l[1], 0) + l[2]
		dmg += l[2]
		lost += l[3] if l.size() > 3 else l[2]
	var dirs := {}
	session.leak_marks.clear()
	for i in by_lane:
		dirs[session.compass(session.lanes[i]) if i >= 0 and i < session.lanes.size() else "?"] = by_lane[i]
		if i >= 0 and i < session.lanes.size():
			session.leak_marks.append([session.lanes[i], by_lane[i]])
	session.leak_log.append({"w": session.wave, "n": session.wave_leaks.size(), "dmg": dmg, "lost": lost, "dirs": dirs, "kinds": kinds, "kdmg": kdmg, "towers": session.towers.get_child_count(), "lanes": session.lanes.size(), "core": session.core_hp})
	if session.leak_log.size() > 200:
		session.leak_log.pop_front()


## 지난 웨이브 누수 안내 한 줄 ("지난 웨이브 누수: 북동쪽 3개(빠른 2) · 남쪽 1개"), 없으면 빈 문자열.
func _leak_text() -> String:
	var session: BinduSession = self.session
	if session.leak_log.is_empty() or session.leak_log[-1]["w"] != session.wave or session.leak_log[-1]["n"] == 0:
		return ""
	var e: Dictionary = session.leak_log[-1]
	var parts := PackedStringArray()
	for d in e["dirs"]:
		parts.append("%s쪽 %d개" % [d, e["dirs"][d]])
	var names := {Orb.Kind.NORMAL: "일반", Orb.Kind.FAST: "빠른", Orb.Kind.TANK: "단단한", Orb.Kind.BOSS: "보스"}
	var ks := PackedStringArray()
	for k in e["kinds"]:
		ks.append("%s %d" % [names.get(k, "?"), e["kinds"][k]])
	return "지난 웨이브에 놓친 구체: %s (%s, 중앙 체력 -%d)" % [" · ".join(parts), ", ".join(ks), e["dmg"]]


func _leak_records() -> Array:
	var session: BinduSession = self.session
	var out: Array = []
	for e in session.leak_log:
		var kinds := {}
		var kdmg := {}
		for k in e.get("kinds", {}):
			kinds[BinduSession.LEAK_KIND_KEYS.get(int(k), "other")] = int(e["kinds"][k])
		for k in e.get("kdmg", {}):
			kdmg[BinduSession.LEAK_KIND_KEYS.get(int(k), "other")] = int(e["kdmg"][k])
		out.append({"w": int(e["w"]), "n": int(e["n"]), "dmg": int(e["dmg"]), "lost": int(e.get("lost", e["dmg"])), "hp": int(e.get("core", 0)), "kinds": kinds, "kdmg": kdmg})
	return out


func _alive_count(n: Node) -> int:
	var c := 0
	for x in n.get_children():
		if not x.is_queued_for_deletion():
			c += 1
	return c


func _resolve(delta: float, preview := false) -> void:
	var session: BinduSession = self.session
	var us := Time.get_ticks_usec() if session.prof_on else 0
	var rect := session.viewport_system.arena().grow(40.0)
	session.live_orbs = session.orbs.get_children().filter(func(o): return not o.is_queued_for_deletion())
	# 공격은 전장에 들어오기 시작한 구체에만 닿는다 (가장자리가 전장 안으로 들어온 구체. 폰처럼 화면이 넓어도 전장 밖 구체는 안 맞는다)
	var screen := session.viewport_system.arena()
	targets = session.live_orbs.filter(func(o): return screen.grow(o.radius()).has_point(o.position))

	_build_grid()
	star_towers = session.towers.get_children().filter(func(t): return t.elements.has(Elem.STAR))
	session.onboarding_system._wind_buffs()
	if session.prof_on:
		us = _prof_add("목록·격자", us)
	# 오브젝트 공격
	for t in session.towers.get_children():
		if not t.is_queued_for_deletion():
			t.attack(delta, targets)
	if session.prof_on:
		us = _prof_add("오브젝트 공격", us)

	# 바닥 효과
	for z in session.zones.get_children():
		if not z.is_queued_for_deletion():
			z.affect(z.trail_orbs(session) if z.kind == "trail" else near(z.position, z.radius if z.kind != "mine" else 80.0), delta)
	if session.prof_on:
		us = _prof_add("장판", us)

	# 발사체
	for p in session.projectiles.get_children():
		if p.is_queued_for_deletion():
			continue
		if not rect.has_point(p.position):
			p.queue_free()
			continue
		if p.finished():
			p.end_form()
			p.queue_free()
			continue
		if p.lob:
			continue
		# 이번 프레임에 지나온 선분으로 판정해 고배속에서도 뚫고 지나가지 않게
		var prev: Vector2 = p.position - p.vel * delta
		for o in near(p.position, p.radius + p.vel.length() * delta):
			if o.hp > 0.0 and Geometry2D.get_closest_point_to_segment(o.position, prev, p.position).distance_to(o.position) < o.radius() + p.radius:
				if p.on_hit(o, delta):
					if p.kind == "shard":
						session.field_view_system._shatter(p)
					p.queue_free()
					break
	if session.prof_on:
		us = _prof_add("발사체 판정", us)

	# 구체 처치 / 중앙 도달 (협동 참가자는 호스트가 보낸 대로)
	for o in (session.live_orbs if not session.mp_ghost else []):
		if o.hp <= 0.0 and preview:
			_death_effects(o)
			o.queue_free()
			continue
		if preview:
			continue
		if o.hp <= 0.0:
			session.spawning_system._jam_death(o)
			session.sfx.play("kill", 0.15)
			session.combo_hold = false
			if session.combo_t <= 0.0:
				session.combo = 0
				session.combo_bonus = 0
			session.combo += 1
			session.combo_t = BinduSession.COMBO_KEEP
			session.best_combo = maxi(session.best_combo, session.combo)
			Ach.on_kill(o, session.run_game, session.combo)
			ach_dirty = true
			if session.combo >= 30:
				session.progression_system._achieve("combo30")
			# 모드가 늘린 체력·수는 빼고 매긴 뒤 모드 배율을 곱한다
			var base: float = o.max_hp * Modes.kill_k(o.kind == Orb.Kind.BOSS, o.minion) * 10 * Modes.mul() * Vary.score_k()
			var gain := int(base * session.field_view_system.combo_mul())
			session.score += gain
			session.combo_bonus += gain - int(base)
			if session.combo == 20:
				session.combo_max_flash = 0.8
				session.spawning_system.popup(o.position + Vector2(0, -20), session.combo, Color(1, 0.85, 0.2), true, "콤보 20! 점수 x3", 1.2)
			elif session.combo >= 3 and session.combo % 5 == 0:
				session.spawning_system.popup(o.position + Vector2(0, -20), session.combo, Color(1, 0.7, 0.3), true, "콤보 %d! 점수 x%.1f" % [session.combo, session.field_view_system.combo_mul()])
			if o.splits:
				for i in 2:
					session.spawning_system._spawn_child(o)
			if o.kind == Orb.Kind.BOSS:
				session.perks_system._heal_core(2)
				session.bonus_rerolls += 1
				session.progression_system._achieve("boss")
				session.hud_system._show_toast("보스 처치! 중앙 체력 +2" + ("" if Modes.has("narrow") else ", 새로고침 +1"))
			session.spawning_system.burst(o.position, o.death_color(), 10 if o.kind != Orb.Kind.BOSS else 40, 180.0)
			session.kills += 1
			for t in session.towers.get_children():
				if t.tg("charge") > 0 and t.position.distance_to(o.position) < Rules.t("charge_r"):
					t.add_charge(o)
			if o.kind == Orb.Kind.BOSS:
				session.shake = 0.4
			_death_effects(o)
			o.queue_free()
			continue
		if session.rampart_left > 0 and not o.walled and not o.ghost and _near_core(o, BinduSession.RAMPART_R):
			# 성벽: 구체 하나당 한 번 밀어내고 한 조각 부서진다
			o.walled = true
			session.rampart_left -= 1
			o.position += (o.position - o.target).normalized() * session.perks_system._perk_val("rampart_push") * (0.5 if o.kind == Orb.Kind.BOSS else 1.0)
			session.spawning_system.burst(o.position, Color(0.75, 0.6, 0.45), 12, 160.0)
			session.sfx.play("hit", 0.0)
		if _reached_core(o):
			var hit_p: Vector2 = o.position if Meta.map_id == "line" else session.viewport_system.center()
			var dmg: int = o.core_dmg - session.perks_system._shield_absorb(o.core_dmg)
			if session.perks.has("riposte"):
				session.perks_system._riposte(hit_p)
			if dmg <= 0:
				session.sfx.play("shield", 0.0)
				session.spawning_system.burst(hit_p, Color(0.55, 0.85, 1.0), 14, 200.0)
				session.spawning_system.popup(hit_p + Vector2(0, -BinduSession.CORE_RADIUS - 24.0), 0, Color(0.55, 0.85, 1.0), true, "실드", 0.9)
				_record_leak(o, 0)
				o.queue_free()
				continue
			session.core_hp -= dmg
			if TutPlay.on:
				session.core_hp = maxi(session.core_hp, 1)  # 연습 판은 지지 않는다
			session.sfx.play("core", 0.0)
			session.shake = 0.25 + 0.1 * dmg
			session.core_flash = 0.4
			session.spawning_system.burst(hit_p, Color(1, 0.3, 0.35), 18, 220.0)
			session.hud_system._show_toast("중앙 피격! %d/%d" % [maxi(session.core_hp, 0), session.core_max])
			session.wave_dmg += dmg
			Ach.on_core_hit(dmg)
			session.spawning_system.popup(hit_p + Vector2(0, -BinduSession.CORE_RADIUS - 24.0), dmg, Color(1, 0.3, 0.35), true, "-%d" % dmg, 1.2)
			_check_danger()
			_record_leak(o, dmg)
			o.queue_free()
			continue

	if ach_dirty:
		ach_dirty = false
		session.progression_system._ach_check()
	for a in session.arcs:
		a[2] -= delta
	session.arcs = session.arcs.filter(func(a): return a[2] > 0.0)
	if session.prof_on:
		_prof_add("처치·나머지", us)


## 부분별 계산 시간(µs)을 더하고 지금 시각을 돌려준다.
func _prof_add(part: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	prof[part] = prof.get(part, 0) + now - since
	return now


## 구체 위치 격자: 발사체·장판이 가까운 구체만 확인하도록.
var grid := {}


func _build_grid() -> void:
	grid.clear()
	for i in targets.size():
		var o: Orb = targets[i]
		o.ti = i
		var k := Vector2i(floori(o.position.x / BinduSession.GRID), floori(o.position.y / BinduSession.GRID))
		if grid.has(k):
			grid[k].append(o)
		else:
			grid[k] = [o]


## 오브젝트를 놓을 수 있는 전장 안쪽 영역 (가장자리에서 몸 반지름만큼 안).
func field_rect() -> Rect2:
	var session: BinduSession = self.session
	return session.viewport_system.arena().grow(-(Tower.RADIUS + 6.0))


## p에서 r(+가장 큰 구체 반지름) 안에 있을 수 있는 구체들.
func near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var rr := r + 32.0
	for x in range(floori((p.x - rr) / BinduSession.GRID), floori((p.x + rr) / BinduSession.GRID) + 1):
		for y in range(floori((p.y - rr) / BinduSession.GRID), floori((p.y + rr) / BinduSession.GRID) + 1):
			var cell = grid.get(Vector2i(x, y))
			if cell:
				for o in cell:
					if is_instance_valid(o) and not o.is_queued_for_deletion():
						out.append(o)
	return out


## 오브젝트 공격용: p에서 r 안에 있을 수 있는 구체를 targets 순서 그대로.
## 전체를 돌던 때와 맞히는 순서(그래서 치명타 등 난수 순서)가 같다.
## 공격 중에 바람에 밀린 만큼(한 조각에 밀림 여유 최대 40)도 빠지지 않게 여유를 둔다.
## 구체가 적거나 범위가 넓어 칸 수가 구체의 1/3을 넘으면 그냥 전체를 준다 (칸 조회가 구체 확인보다 비싸다).
func near_t(p: Vector2, r: float) -> Array:
	var rr := r + 32.0 + 40.0
	var x0 := floori((p.x - rr) / BinduSession.GRID)
	var x1 := floori((p.x + rr) / BinduSession.GRID)
	var y0 := floori((p.y - rr) / BinduSession.GRID)
	var y1 := floori((p.y + rr) / BinduSession.GRID)
	if (x1 - x0 + 1) * (y1 - y0 + 1) * 3 >= targets.size():
		return targets
	var idx := PackedInt32Array()
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var cell = grid.get(Vector2i(x, y))
			if cell:
				for o in cell:
					idx.append(o.ti)
	idx.sort()
	var out: Array = []
	out.resize(idx.size())
	for i in idx.size():
		out[i] = targets[idx[i]]
	return out


func _update_fx(delta: float) -> void:
	var session: BinduSession = self.session
	session.danger_lv = mini(session.danger_lv, _danger_of(session.core_hp))
	for lf in session.leak_flash:
		lf[1] -= delta
	session.leak_flash = session.leak_flash.filter(func(lf): return lf[1] > 0.0)
	for p in session.popups:
		p[0] += Vector2(0, -40.0 * delta)
		p[2] -= delta
	session.popups = session.popups.filter(func(p): return p[2] > 0.0)
	for p in session.particles:
		p[0] += p[1] * delta
		p[1] *= 0.92
		p[2] -= delta
	session.particles = session.particles.filter(func(p): return p[2] > 0.0)
	for b in session.bolts:
		b[1] -= delta
	session.bolts = session.bolts.filter(func(b): return b[1] > 0.0)
	for q in session.pulses:
		q[2] -= delta
	session.pulses = session.pulses.filter(func(q): return q[2] > 0.0)
	for q in session.beams:
		q[3] -= delta
	session.beams = session.beams.filter(func(q): return q[3] > 0.0)
	session.shake = maxf(session.shake - delta, 0.0)
	session.combo_end[2] = maxf(session.combo_end[2] - delta, 0.0)
	session.combo_max_flash = maxf(session.combo_max_flash - delta, 0.0)
	session.core_flash = maxf(session.core_flash - delta, 0.0)
	session.riposte_cd = maxf(session.riposte_cd - delta, 0.0)
	for q in session.core_fx:
		q[2] -= delta
	session.core_fx = session.core_fx.filter(func(q): return q[2] > 0.0)
	for q in session.skill_fx:
		q[2] -= delta
	session.skill_fx = session.skill_fx.filter(func(q): return q[2] > 0.0)
	session.eclipse_flash = maxf(session.eclipse_flash - delta, 0.0)
	session.eclipse_cd = maxf(session.eclipse_cd - delta, 0.0)
	if not is_equal_approx(session.view_zoom, 1.0) and (session.title_label.visible or session.phase == BinduSession.Phase.GAMEOVER):
		session.viewport_system._reset_zoom()  # 시작 화면·게임 오버는 1배로
	if not session.card_dock.active():  # 도크 전용 화면 영역의 카메라는 도크 레이아웃에서 정한다

		session.camera.position = session.viewport_system.center() + session.view_pan
	session.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * session.shake * (1.0 if Meta.shake_on else 0.0)
	session.fx_layer.queue_redraw()


## 처치 시 전투 효과만. 보상·업적과 분리해 미리보기에서도 같은 효과를 쓴다.
func _death_effects(o: Orb) -> void:
	var session: BinduSession = self.session
	if o.poison_t > 0.0:
		for other in targets:
			if other != o and other.position.distance_to(o.position) < 80.0:
				other.poison(o.poison_dps, 3.0, o.poison_src, o.poison_rx, o.poison_key)
		Share.contagion(o)  # 독 전염: 효과도 번짐
	if o.vuln_t > 0.0:
		Share.pull(o)  # 어둠 끌어당김
	if o.soul_t > 0.0:
		session.spawning_system._soul_wisp(o)
