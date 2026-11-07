class_name BinduSpawning
extends BinduFeature
## 구체·발사체·장판과 효과 생성. 예약 콜백은 main의 순서를 따른다.

func spawn_proj(t: Tower, kind: String, l: int, d := Vector2.ZERO, off := Vector2.ZERO) -> Projectile:
	var session: BinduSession = self.session
	var p := Projectile.new()
	p.setup(kind, t, l, d, off)
	session.projectiles.add_child(p)
	return p


func spawn_zone(kind: String, l: int, pos: Vector2, t: Tower) -> Zone:
	var session: BinduSession = self.session
	var z := Zone.new()
	z.setup(kind, l, t)
	z.src = t.tag if t else ""
	if t and t.fire_boost > 1.0:
		z.boost = t.fire_boost
		z.src = t.fire_key
	z.position = pos
	session.zones.add_child(z)
	return z


## 벽 공격방식: 발사 방향에 바위 벽. 오브젝트당 최대 2개(+다중 발사).
func spawn_rock(t: Tower, l: int) -> void:
	var session: BinduSession = self.session
	t.rocks = t.rocks.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion())
	if t.rocks.size() >= 2 + roundi(t.mf("multi")):
		return
	# 바위는 화면 가장자리에서 100 안쪽에만 선다: 가장자리에 서면 막힌 구체가 화면 끝에 붙어
	# 다른 오브젝트가 닿지 않는 곳에서 버티고 웨이브가 끝나지 않던 것 (폭풍 맵 66웨이브에서 4분 넘게)
	var inner := session.viewport_system.arena().grow(-100.0)
	# 빈 자리 중 앞쪽부터 (Tower.rock_slot). 가장자리에 밀려 같은 자리에 겹치는 바위는 세우지 않는다
	for k in 2 + roundi(t.mf("multi")):
		var p := (t.position + Tower.rock_slot(t.aim if t.m("reflex") > 0 else t.dir, k, l)).clamp(inner.position, inner.end)
		if not t.rocks.any(func(r): return r.position.distance_to(p) < 40.0):
			t.rocks.append(spawn_zone("rock", l, p, t))
			return


## 연쇄 번개 표시 (맨 위 층).
func bolt(pts: PackedVector2Array) -> void:
	var session: BinduSession = self.session
	if session.bolts.size() < 40:
		session.bolts.append([pts, 0.22])


## 소리 울림: 울림이 3번 쌓인 구체 주변(자기 포함)에 음파 피해. 부가효과는 붙지 않는다.
func sound_pulse(o: Orb) -> void:
	var session: BinduSession = self.session
	var tw: Tower = o.tune_src if is_instance_valid(o.tune_src) else null
	var l := maxi(o.tune_lv, 1)
	var r := 70.0 + 10.0 * (l - 1)
	var dmg := Rules.t("sound_pulse") * Tower.pw(l) * (tw.dmg_k(true) / (1.0 + Rules.size_dmg * tw.mf("size") if tw.pattern in Pat.PROJECTILE else 1.0) if tw else 1.3)
	# 소리 퍼짐 (특징 공유): 음파에 닿은 구체에 울림을 건 오브젝트 효과
	var ks := Share.k(tw, Elem.SOUND) if tw else 0.0
	if ks > 0.0:
		r *= Share.wide(tw)
	if Share.has(tw, "reso"):
		r *= 1.0 + Share.RESO_R  # 공진 (상성)
	for other in session.combat_system.near(o.position, r + 30.0):
		if other.hp > 0.0 and other.position.distance_to(o.position) < r + other.radius():
			var got: float = other.hurt(dmg, false, tw)
			if tw:
				tw.credit(got, "elem:sound")
				if ks > 0.0 and other != o:
					Share.carry(tw, other, Share.SOUND_F * ks, "share:sound", o.position, other.position.distance_to(o.position) / maxf(r, 1.0))
				if other != o and Share.has(tw, "phantasm") and tw.lv(Elem.ILLUSION) > 0 and randf() < Share.illu_ch(tw, tw.lv(Elem.ILLUSION)):
					other.confuse(Rules.illu_t * Share.dur(tw), Share.has(tw, "nightmare"))  # 환청 (상성)
	if session.pulses.size() < 40:
		session.pulses.append([o.position, r, 0.3])


## 영혼: 넋이 걸린 채 죽은 구체에서 혼불 (영혼 쫓아감: 혼불은 그 오브젝트 공격처럼 맞혀 효과를 모두 건다). 화면의 혼불은 30개까지.
func _soul_wisp(o: Orb) -> void:
	var session: BinduSession = self.session
	var tw: Tower = null
	var l := 1
	if o.soul_t > 0.0 and is_instance_valid(o.soul_src) and randf() < minf(Rules.t("soul_base") + Rules.t("soul_lv") * o.soul_lv, Rules.t("soul_max")):
		tw = o.soul_src
		l = o.soul_lv
	if tw == null:
		return
	var n := 0
	for p in session.projectiles.get_children():
		if p.kind == "ghost":
			n += 1
	if n >= 30:
		return
	var g := spawn_proj(tw, "ghost", l, Vector2.from_angle(randf() * TAU))
	g.position = o.position
	g.hit[o] = true
	g.dmg = 2.5 * Tower.pw(l)
	g.src = "elem:soul"


## 빛줄기 표시 (빛 꿰뚫음): 잠깐 빛나는 직선.
func beam(a: Vector2, b: Vector2, c: Color) -> void:
	var session: BinduSession = self.session
	if session.beams.size() < 40:
		session.beams.append([a, b, c, 0.2])


## 전기 부가효과: 가까운 다른 구체로 전류가 튄다 (src: 쏜 오브젝트, 피해 기록용).
func arc(from: Orb, dmg: float, src: Tower = null, cap = null) -> void:  # cap: 초신성 보스 상한 (Tower.nova_hurt)
	var session: BinduSession = self.session
	var best: Orb = null
	var bd := 90.0 * (Share.wide(src) if src else 1.0) * (1.0 + Share.SHOCK_R if Share.has(src, "shock") else 1.0) * Nature.arc_range(from)
	for o in session.combat_system.near(from.position, bd):
		if o != from and is_instance_valid(o) and o.hp > 0.0:
			var d: float = o.position.distance_to(from.position)
			if d < bd:
				bd = d
				best = o
	if best:
		var got: float = src.nova_hurt(best, dmg, cap) if src and cap is Dictionary else best.hurt(dmg, false, src)
		if src:
			src.credit(got, "elem:electric")
			Nature.electric(src, best, got)  # 자연 현상: 접지·덩굴 회로·낙뢰목
			if Share.has(src, "shock"):
				best.stagger(Share.SHOCK_STAG)  # 감전 (상성)
			# 전기 튐 (특징 공유): 전류가 튀면 오브젝트 효과도 튄다
			var ke := Share.k(src, Elem.ELECTRIC)
			if ke > 0.0:
				Share.carry(src, best, Share.ELEC_F * ke, "share:electric", from.position, 1.0)
		if session.arcs.size() < 80:
			session.arcs.append([from.position, best.position, 0.12])


## 구체 하나의 진입 각도·체력(종류 보정 전)·속도·저항·굳셈을 뽑는다.
## 웨이브 w 구체가 진입 방향 각도에서 벗어나는 폭(라디안, ±). 화면의 진입 부채꼴(_draw_lane_fan)과 같은 값.
func _roll_orb(w: int) -> Dictionary:
	var session: BinduSession = self.session
	var spread := session.lane_spread(w)
	var li: int = session.lane_bag.pop_back() if not session.lane_bag.is_empty() and session.phase == BinduSession.Phase.WAVE and not session.w_off else session.multiplayer_system.wi() % session.lanes.size()
	var a: float = session.lanes[li] + session.multiplayer_system.wrange(-spread, spread)
	var hp := (1.0 + floorf(w * 0.7) + session.multiplayer_system.wi() % 2) * session.hp_growth(w) * Rules.orb_hp
	match Meta.map_id:
		"cross":
			hp = ceilf(hp * BinduSession.CROSS_HP)
		"storm":
			hp = maxf(1.0, roundf(hp * 0.6))
		"line":
			hp *= BinduSession.LINE_HP
	hp *= Vary.hp_k()
	hp *= session.coop_hp_k(w) * session.vs_k("vs_hp")
	var spd := (session.orb_base_speed(w) + session.multiplayer_system.wf() * 8.0) * (BinduSession.LINE_SPD if Meta.map_id == "line" else 1.0) * Vary.spd_k() * session.vs_k("vs_spd")
	# 저항·굳셈: 쉬는 시간에 미리 알려 준 대로
	var res := session.wave_resist if session.wave_resist >= 0 and session.multiplayer_system.wf() < session.resist_share(w) else -1
	var y := session.multiplayer_system.wrange(-BinduSession.LINE_HALF + 20.0, BinduSession.LINE_HALF - 20.0) if Meta.map_id == "line" else 0.0
	return {"a": a, "y": y, "hp": roundf(hp), "spd": spd, "resist": res, "sturdy": session.multiplayer_system.wf() < session.sturdy_share(w) or Vary.all_sturdy()}


## 다음 웨이브가 보스 웨이브면 보스를 미리 뽑아 둔다 (화면에 길·체력을 정확히 알려 주려고).
func _plan_boss() -> void:
	var session: BinduSession = self.session
	session.boss_plan = {}
	if (session.wave + 1) % 5 == 0 and not session.lanes.is_empty():
		session.boss_plan = _roll_orb(session.wave + 1)
		session.boss_plan["wave"] = session.wave + 1


## 구체가 나오는 거리. 예전(lane_even 0)은 모든 방향 화면 대각선 반 + 30.
## 지금은 각도 a 방향 전장 가장자리 + lane_margin: 상하(360)는 좌우(640)보다 가깝다 → lane_k로 속도를 맞춘다.
func _spawn_radius(a := 0.0) -> float:
	var session: BinduSession = self.session
	if Rules.t("lane_even") <= 0.0:
		return Meta.FIELD.length() / 2.0 + 30.0
	return session.field_view_system._edge_point(session.viewport_system.center(), Vector2.from_angle(a)).distance_to(session.viewport_system.center()) + Rules.t("lane_margin")


## 진입 시간 맞추기 (2026-11-01): 각도 a에서 나온 구체 속도 배율. 나온 곳에서 중앙까지 걸리는 시간이
## 좌우(가장 먼 가로 방향)와 같아지게 거리 비율로 곱한다 (상하 약 0.58, 좌우 1, 모서리 약 1.14). 전체에 lane_speed(소용돌이는 lane_speed_spiral)를 곱함.
## 소용돌이는 중앙 가까울수록 빨라지므로 거리 대신 걸리는 시간 몫(_lane_time)으로 비율을 낸다.
func lane_k(a: float) -> float:
	if Rules.t("lane_even") <= 0.0 or Meta.map_id == "line":
		return 1.0
	var ref := Meta.FIELD.x / 2.0 + Rules.t("lane_margin")
	return _lane_time(_spawn_radius(a)) / _lane_time(ref) * Rules.t("lane_speed_spiral" if Meta.map_id == "spiral" else "lane_speed")


## 거리 d에서 중앙까지 속도 1로 걸리는 시간 (소용돌이: 나선이라 안쪽으로는 cos(비낌)만큼, 거리별 속도 배율 반영).
func _lane_time(d: float) -> float:
	if Meta.map_id != "spiral":
		return d
	var t := 60.0
	var n := 48
	var step := maxf(d - 60.0, 0.0) / n
	for i in n:
		t += step / (cos(BinduSession.SPIRAL_SWIRL) * MapRule.spiral_speed(60.0 + step * (i + 0.5)))
	return t


## 각도 a에서 나온 구체가 막히지 않을 때 지나가는 길 (소용돌이 맵은 나선, 구체 이동과 같은 식).
## y: 회랑 맵에서 구체가 나오는 높이.
func _orb_path(a: float, y := 0.0) -> PackedVector2Array:
	var session: BinduSession = self.session
	if Meta.map_id == "line":
		return PackedVector2Array([session.viewport_system._line_start(y), session.viewport_system._line_end(y)])
	var c := session.viewport_system.center()
	var p := c + Vector2.from_angle(a) * _spawn_radius(a)
	if Meta.map_id != "spiral":
		return PackedVector2Array([p, c])
	var sw := BinduSession.SPIRAL_SWIRL * MapRule.swirl_sign(session.wave if session.phase == BinduSession.Phase.WAVE else session.wave + 1)
	var pts := PackedVector2Array([p])
	for k in 600:
		var to := c - p
		if to.length() <= 60.0:
			break
		p += to.normalized().rotated(sw) * 4.0
		if k % 3 == 2:
			pts.append(p)
	pts.append(p)
	pts.append(c)
	return pts


func _spawn_orb(kind := -1, plan := {}) -> void:
	var session: BinduSession = self.session
	var o := Orb.new()
	var p: Dictionary = plan if not plan.is_empty() else _roll_orb(session.wave)
	o.born = session.run_game
	o.position = session.viewport_system.center() + Vector2.from_angle(p["a"]) * _spawn_radius(p["a"])
	o.from_a = p["a"]
	o.target = session.viewport_system.center()
	o.lane_k = lane_k(p["a"])
	if Meta.map_id == "line":
		o.position = session.viewport_system._line_start(p.get("y", 0.0))
		o.target = session.viewport_system._line_end(p.get("y", 0.0))
	if kind < 0:
		kind = _roll_kind()
	o.main = session
	if Meta.map_id == "spiral":
		o.swirl = BinduSession.SPIRAL_SWIRL * MapRule.swirl_sign(session.wave)  # 회오리: 보스 웨이브가 끝나면 방향이 바뀐다
	o.setup(kind, p["hp"], p["spd"])
	o.resist_e = p["resist"]
	o.sturdy = p["sturdy"]
	# A4·A5: 보호막(8웨이브~), 분열(12웨이브~, 10웨이브는 보스·저항이 처음 겹침)
	if kind == Orb.Kind.NORMAL or kind == Orb.Kind.TANK:
		if session.wave >= 8 and session.multiplayer_system.wf() < minf(0.1 + 0.01 * session.wave, 0.3):
			o.shield = (2.0 + session.wave * 0.3) * session.hp_growth(session.wave) * Rules.orb_hp
		if session.wave >= 12 and session.multiplayer_system.wf() < 0.15:
			o.splits = true
	if Vary.all_split() and kind != Orb.Kind.BOSS:
		o.splits = true  # 이벤트 증식
	if kind != Orb.Kind.BOSS:
		_late_trait(o, p)
		if o.late == "":
			_jam_trait(o)
	session.orbs.add_child(o)
	session.combat_system.stat_in(o)


## 후반 구체 (100·175·250·350·500웨이브~, Rules late_*). 종류마다 처음 late_share, 10웨이브마다 +late_share_step, 최대 late_share_max.
## 치유는 웨이브당 late_heal_max, 포식은 웨이브 무리를 late_devour_n+1로 나눈 자리마다 하나(조금 빨라 앞 구체를 따라잡음).
func _late_trait(o: Orb, p: Dictionary) -> void:
	var session: BinduSession = self.session
	if session.mp_ghost:
		return
	var id := ""
	var dn := int(Rules.t("late_devour_n"))
	var tot := session.spawn_count(session.wave)
	if session.wave >= session.late_from("devour") and session.late_n.get("devour", 0) < dn and range(1, dn + 1).any(func(k): return session.to_spawn == int(tot * k / (dn + 1.0))):
		id = "devour"  # 무리 한가운데쯤 나와 앞 구체를 따라잡아 삼킨다
	else:
		var x := session.multiplayer_system.wf()
		for k in ["blink", "armor", "mender", "phase"]:
			var sh := session.late_share(k, session.wave)
			if sh <= 0.0:
				continue
			if x < sh:
				if k != "mender" or session.late_n.get("mender", 0) < int(Rules.t("late_heal_max")):
					id = k
				break
			x -= sh
	if id == "":
		return
	session.late_n[id] = session.late_n.get(id, 0) + 1
	o.late = id
	var hk := 1.0
	var sk := 1.0
	match id:
		"blink":
			sk = 0.85
			o.late_t = Rules.t("late_blink_iv")
		"armor":
			hk = 1.2; sk = 0.9
			o.armor = p["hp"] * Rules.t("late_armor")
		"mender":
			hk = 0.7; sk = 0.8
			o.late_t = Rules.t("late_heal_iv")
		"phase":
			hk = 1.3
			o.late_t = session.multiplayer_system.wf() * Rules.t("late_phase_on")  # 다 같이 깜빡이지 않게
		"devour":
			hk = 3.0; sk = 1.3
			o.splits = false
			o.shield = 0.0
	o.max_hp = ceilf(o.max_hp * hk)
	o.hp = o.max_hp
	o.speed *= sk


# ---------- 방해 구체 (Orb.jam, 2026-10-31 "디펜스 한계 개선 B") ----------
## 오브젝트를 잠깐 멈추거나 느리게만 한다(오브젝트 체력은 없음). 예고는 쉬는 시간 웨이브 안내, 침묵이면 효과가 멈춘다.
func jams_on() -> bool:
	var session: BinduSession = self.session
	return Rules.t("jam_on") > 0.0 and session.mp_mode == "" and OS.get_environment("JAM") != "0"  # 봇 비교용: JAM=0이면 끔


func _jam_trait(o: Orb) -> void:
	var session: BinduSession = self.session
	if not jams_on() or session.mp_ghost:
		return
	var x := session.multiplayer_system.wf()
	for k in BinduSession.JAM_IDS:
		var sh := session.jam_share(k, session.wave)
		if sh <= 0.0:
			continue
		if x < sh:
			o.jam = k
			break
		x -= sh
	if o.jam == "":
		return
	session.jam_any = true
	if o.jam == "seeker":
		o.speed *= Rules.t("jam_seek_spd")
		var best: Tower = null
		var bd := INF
		for t in session.towers.get_children():
			var d: float = t.position.distance_to(o.position)
			if d < bd:
				bd = d
				best = t
		if best:
			o.jam_tower = best
			o.jam_home = o.target
			o.target = best.position
			o.swirl = 0.0  # 곧장 온다
			o.lane_k = 1.0


## 계산 조각마다: 그림자는 둘레 오브젝트를 멈추고, 표적은 닿으면 멈추고 사라진다.
func _jam_tick() -> void:
	var session: BinduSession = self.session
	if not session.jam_any:
		return
	for o in session.live_orbs:
		if o.jam == "" or o.hp <= 0.0 or o.is_queued_for_deletion():
			continue
		if o.silence_t > 0.0:
			continue
		match o.jam:
			"shade":
				var r := Rules.t("jam_shade_r") + Tower.RADIUS
				for t in session.towers.get_children():
					if t.position.distance_to(o.position) < r:
						t.jam(Rules.t("jam_shade_t"))
			"seeker":
				var t: Object = o.jam_tower
				if not is_instance_valid(t):
					o.jam = ""
					o.target = o.jam_home
					continue
				if t.position.distance_to(o.position) < Tower.RADIUS + o.radius() + 4.0:
					t.jam(Rules.t("jam_seek_t"))
					burst(o.position, Color(1.0, 0.35, 0.3), 12, 160.0)
					o.queue_free()


## 흡수 구체가 죽으면 둘레 오브젝트가 빼앗긴 공격 속도를 돌려받는다.
func _jam_death(o: Orb) -> void:
	var session: BinduSession = self.session
	if o.jam != "leech":
		return
	for t in session.towers.get_children():
		if t.position.distance_to(o.position) < Rules.t("jam_leech_free"):
			t.leech_n = 0
			t.leech_t = 0.0


## 피해 숫자 팝업.
func popup(pos: Vector2, amount: float, col: Color, big: bool, text := "", life := 0.7) -> void:
	var session: BinduSession = self.session
	if session.popups.size() > 120:
		if text == "":
			return
		session.popups.pop_front()  # 글자(최다 피해·콤보)는 피해 숫자가 꽉 차도 가장 오래된 것을 밀어내고 띄운다
	if text == "" and not Meta.numbers_on:
		return
	var txt := text if text != "" else str(maxi(roundi(amount), 1))
	session.popups.append([pos + Vector2(randf_range(-8, 8), -10), txt, life, col, big])


## 웨이브를 마치면 가장 많이 때린 오브젝트 위에 몫을 잠깐 띄운다 (무엇이 일하는지 알려 줌).
func _show_mvp() -> void:
	var session: BinduSession = self.session
	var best: Tower = null
	var total := 0.0
	for t in session.towers.get_children():
		total += t.dealt
		if best == null or t.dealt > best.dealt:
			best = t
	if best == null or total <= 0.0 or session.towers.get_child_count() < 2:
		return
	var txt := "최다 피해 %d%%" % roundi(best.dealt / total * 100.0)
	popup(best.position + Vector2(-session.ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x / 2.0, -30), 0.0, Color(1, 0.9, 0.5), true, txt, 2.0)


## 구체가 터질 때 파편.
func burst(pos: Vector2, col: Color, n: int, spd: float) -> void:
	var session: BinduSession = self.session
	if session.particles.size() > 600:
		n = mini(n, 3)
	for i in n:
		var a := randf() * TAU
		session.particles.append([pos, Vector2(cos(a), sin(a)) * spd * randf_range(0.4, 1.0), randf_range(0.3, 0.6), col, randf_range(2.0, 4.5)])


## 보스가 부르는 빠른 부하.
func spawn_minion(boss: Orb) -> void:
	var session: BinduSession = self.session
	var o := Orb.new()
	o.main = session
	o.position = boss.position
	o.from_a = boss.from_a
	o.target = boss.target
	o.setup(Orb.Kind.FAST, maxf(1.0, roundf(session.wave * 0.5 * session.hp_growth(session.wave) * Rules.orb_hp)), session.orb_base_speed(session.wave) + 6.0)
	o.resist_e = boss.resist_e
	o.minion = true
	session.orbs.add_child(o)
	session.combat_system.stat_in(o)


## 분열 구체가 터지면 작은 구체 2개.
func _spawn_child(parent: Orb) -> void:
	var session: BinduSession = self.session
	var o := Orb.new()
	o.main = session
	o.position = parent.position + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	o.from_a = parent.from_a
	o.target = parent.target
	o.swirl = parent.swirl
	o.lane_k = parent.lane_k
	o.setup(Orb.Kind.NORMAL, maxf(1.0, ceilf(parent.max_hp * 0.4)), parent.speed * 1.1 / (session.orb_speed_mul * Modes.speed()))
	o.resist_e = parent.resist_e
	o.sturdy = parent.sturdy
	session.orbs.add_child(o)
	session.combat_system.stat_in(o)


## 웨이브가 오를수록 빠른 구체(4웨이브~), 단단한 구체(6웨이브~)가 섞인다.
func _roll_kind() -> int:
	var session: BinduSession = self.session
	var x := session.multiplayer_system.wf()
	# 단단한 구체는 7웨이브부터 (6웨이브는 세 번째 진입 방향이 열림)
	if session.wave >= 7 and x < minf(0.08 + 0.02 * session.wave, 0.3):
		return Orb.Kind.TANK
	if session.wave >= 4 and x > 1.0 - minf(0.1 + 0.03 * session.wave, 0.35):
		return Orb.Kind.FAST
	return Orb.Kind.NORMAL
