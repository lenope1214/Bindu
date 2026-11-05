class_name BinduPersistence
extends BinduFeature
## 판 스냅샷 검증·저장·복원. 예약 콜백은 main의 순서를 따른다.

func _save_run() -> void:
	var session: BinduSession = self.session
	if session.mp_mode != "" or TutPlay.on:
		return  # 멀티플레이 판·연습 판은 이어하기가 없다
	if session.title_label.visible or not session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] or session.interaction_system.press_t or session.interaction_system.dragging or session.coin_stage > 0:
		return
	var ts := session.towers.get_children()
	var list: Array = []
	for t in ts:
		list.append(t.to_save())
	var vals := {
		"format": BinduSession.RUN_FORMAT, "version": ProjectSettings.get_setting("application/config/version", ""),
		"map": Meta.map_id, "line_flip": Meta.line_flip, "rules": Meta.rules, "modes": Array(Modes.on), "wave": session.wave, "score": session.score, "kills": session.kills, "best_combo": session.best_combo,
		"combo": session.combo, "combo_t": session.combo_t, "combo_bonus": session.combo_bonus,
		"core_hp": session.core_hp, "core_max": session.core_max, "perks": session.perks.keys().map(func(k): return [k, session.perks[k]]), "regen_acc": session.regen_acc, "shield_keep": session.shield_keep, "orb_speed_mul": session.orb_speed_mul,
		"dmg_mul": Tower.dmg_mul, "spd_mul": Tower.spd_mul, "reach_mul": Tower.reach_mul, "tax_step": Tower.tax_step,
		"rerolls_left": session.rerolls_left, "bonus_rerolls": session.bonus_rerolls, "picks_left": session.picks_left,
		"vary": Vary.save(), "skip_left": session.skip_left, "skip_total": session.skip_total, "skip_stop": session.skip_stop, "bank_picks": session.bank_picks, "bank_rerolls": session.bank_rerolls, "bank_perks": session.bank_perks, "perk_rerolls": session.perk_rerolls, "coin_next": session.coin_next, "rest_ready": session.rest_ready,
		"new_angles": session.waves_system.new_angles, "lanes": Array(session.lanes), "wave_resist": session.wave_resist, "boss": session.boss_plan, "achievements": session.new_achievements, "ach_run": Ach.run,
		"state": "perk" if session.perk_mode else ("ready" if session.phase == BinduSession.Phase.READY else "choose"),
		"offer": session.offer, "perk_offer": session.perk_offer.map(func(pk): return pk["id"]), "towers": list,
		"log": session.run_log, "leaks": session.leak_log, "game_secs": session.run_game, "real_secs": session.run_real, "run_id": session.run_id,
		"tutor": session.tutor, "tutor_given": session.tutor_given.keys(), "grow": session.legacy_grow, "skill_set": session.skill_set, "skill_used": session.skill_used, "ley": session.ley.map(func(p): return [p.x, p.y]),
	}
	var cfg := ConfigFile.new()
	for k in vals:
		cfg.set_value("run", k, vals[k])
	cfg.save(BinduSession.RUN_PATH)
	if session.run_id != session.moved_run:
		# 같은 계정의 다른 기기에서 이어 할 수 있게 서버에도 (쉬는 시간마다, 끄면 마지막 것)
		session.net.put_run(session.run_id, cfg.encode_to_text(), {"game": Net.game_version(), "platform": Net.platform(), "map": Meta.map_id,
			"rules": Meta.rules, "wave": session.wave, "score": session.score})


## drop: 서버의 같은 판도 지운다 (다른 기기가 가져가서 지우는 것이면 false).
func _clear_run(drop := true) -> void:
	var session: BinduSession = self.session
	if FileAccess.file_exists(BinduSession.RUN_PATH):
		var key := session.online_system._local_run_key()
		DirAccess.remove_absolute(BinduSession.RUN_PATH)
		if drop and key != "" and key != session.moved_run:
			session.net.drop_run(key)


## 저장된 판 요약 {wave, map, rules, cfg} (없거나 형식이 다르면 빈 사전).
func _run_info(path := "") -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path if path != "" else BinduSession.RUN_PATH) != OK or Meta.val(cfg, "run", "format", 0) != BinduSession.RUN_FORMAT:
		return {}
	var map: String = Meta.val(cfg, "run", "map", "")
	var r: int = Meta.val(cfg, "run", "rules", 0)
	if not map in Meta.MAP_IDS or not r in Rules.OLD_IDS:
		return {}
	if not r in Rules.IDS:
		r = 1  # 고를 수 없게 된 버전(2·4)과 폐기한 5로 저장된 판은 버전 1로 이어 한다
	return {"wave": maxi(0, Meta.val(cfg, "run", "wave", 0)), "map": map, "rules": r, "cfg": cfg}


## 시작 화면의 이어하기 버튼: 저장된 판이 있으면 그 판의 웨이브·맵·규칙을 보여 준다.
func _refresh_continue() -> void:
	var session: BinduSession = self.session
	var info := _run_info()
	session.continue_btn.visible = not info.is_empty()
	if session.continue_btn.visible:
		session.remote_btn.visible = false
	session.new_armed = 0.0
	session.new_btn.text = "새로 시작" if session.continue_btn.visible else "시작"
	if session.continue_btn.visible:
		session.onboarding_system._tut_event("continue")
		session.continue_info.text = "웨이브 %d부터 · %s · %s" % [info["wave"] + 1, Meta.MAPS[info["map"]]["name"], Rules.NAMES[info["rules"]]]
		var n := 2 if session.mp_btn.visible else 1  # 이어하기 폭 = 타일 줄 폭 (일반 판·멀티)
		session.continue_btn.custom_minimum_size.x = n * session.menu_system._tile_w() + 16 * (n - 1)
	session.get_tree().call_group("keycap", "queue_redraw")  # [일반 판] 타일의 Enter 표시는 이어하기가 있으면 뺀다


## 저장된 선택지 카드가 지금 판에서도 쓸 수 있는 형식인지.
func _valid_card(cd: Variant) -> bool:
	if not cd is Dictionary:
		return false
	match cd.get("type"):
		"elem": return cd.get("e") in Elem.ALL and cd.get("lv") is int
		"pat": return cd.get("id") in Pat.ALL_IDS
		"mod": return Pat.MODS.has(cd.get("id"))
		"link": return Pat.LINKS.has(cd.get("id"))
		"trig": return Pat.TRIGS.has(cd.get("id"))
		"cata": return false  # 예전 저장된 대격변 선택지 복원 방지
	return false


## 시작 화면 [이어하기]: 저장된 쉬는 시간으로 돌아간다.
func _continue_run() -> void:
	var session: BinduSession = self.session
	var info := _run_info()
	if info.is_empty():
		_clear_run()
		_refresh_continue()
		return
	var cfg: ConfigFile = info["cfg"]
	var g := func(k: String, d: Variant) -> Variant: return Meta.val(cfg, "run", k, d)
	Meta.map_id = info["map"]
	Meta.line_flip = g.call("line_flip", Meta.line_flip)
	Meta.rules = info["rules"]
	Modes.set_on(g.call("modes", []))  # 그 판을 시작할 때 고른 모드 (시작 화면에서 지금 고른 것과 달라도)
	session.legacy_grow = g.call("grow", false) == true
	session.run_flow_system._apply_rules()

	session.menu_system._refresh_menu()
	session.progression_system._save_best()
	session.progression_system._hide_title()
	session.wave = info["wave"]
	session.score = maxi(0, g.call("score", 0))
	session.kills = maxi(0, g.call("kills", 0))
	session.best_combo = maxi(0, g.call("best_combo", 0))
	session.combo = clampi(g.call("combo", 0), 0, session.best_combo)
	session.combo_t = clampf(g.call("combo_t", 0.0), 0.0, BinduSession.COMBO_KEEP) if session.combo > 0 else 0.0
	session.combo_bonus = maxi(0, g.call("combo_bonus", 0))
	session.combo_hold = session.combo_t > 0.0
	session.core_max = maxi(1, g.call("core_max", BinduSession.CORE_MAX_HP))
	session.core_hp = clampi(g.call("core_hp", session.core_max), 1, session.core_max)
	session.danger_lv = session.combat_system._danger_of(session.core_hp)
	session.core_disp = float(session.core_hp)
	# 특성은 고른 순서대로 [id, 횟수] 목록 (사전으로 저장하면 이름순으로 바뀌어 점수 줄 순서가 달라짐)
	session.perks = {}
	var pk_saved: Variant = cfg.get_value("run", "perks", [])
	var pairs: Array = []
	if pk_saved is Array:
		pairs = pk_saved
	elif pk_saved is Dictionary:  # v0.4.21~24 저장
		pairs = pk_saved.keys().map(func(k): return [k, pk_saved[k]])
	for pr in pairs:
		if pr is Array and pr.size() == 2 and BinduSession.PERKS.any(func(pk): return pk["id"] == pr[0]) and pr[1] is int and pr[1] > 0:
			session.perks[pr[0]] = pr[1]
	session.regen_acc = clampf(float(g.call("regen_acc", 0.0)), 0.0, 0.999)
	session.shield_keep = clampi(int(g.call("shield_keep", 0)), 0, 4)
	session.orb_speed_mul = clampf(g.call("orb_speed_mul", 1.0), 0.05, 1.0)
	Tower.dmg_mul = maxf(1.0, g.call("dmg_mul", 1.0))
	Tower.spd_mul = maxf(1.0, g.call("spd_mul", 1.0))
	Tower.reach_mul = maxf(1.0, g.call("reach_mul", 1.0))
	Tower.tax_step = clampf(g.call("tax_step", Rules.tax_step), 0.0, Rules.tax_step)
	session.rerolls_left = maxi(0, g.call("rerolls_left", 1))
	session.bonus_rerolls = maxi(0, g.call("bonus_rerolls", 0))
	session.picks_left = maxi(0, g.call("picks_left", 1))  # 특성 고르기 중에는 0
	session.skip_left = maxi(0, int(g.call("skip_left", 0)))
	session.skip_total = maxi(session.skip_left, int(g.call("skip_total", 0)))
	session.skip_stop = g.call("skip_stop", false) == true
	session.bank_picks = (g.call("bank_picks", []) as Array).filter(func(x): return x is int).map(func(x): return clampi(x, 0, session.wave))
	session.bank_rerolls = maxi(0, int(g.call("bank_rerolls", 0)))
	session.perk_rerolls = clampi(int(g.call("perk_rerolls", 1)), 0, 1)
	session.bank_perks = maxi(0, int(g.call("bank_perks", 0)))
	session.coin_next = str(g.call("coin_next", ""))
	if not session.coin_next in ["double", "reroll"]:
		session.coin_next = ""
	session.rest_ready = g.call("rest_ready", false) == true
	session.lanes.assign((g.call("lanes", []) as Array).filter(func(a): return a is float))
	if session.lanes.is_empty():
		session.waves_system._roll_lanes()
	session.waves_system.new_angles = (g.call("new_angles", []) as Array).filter(func(a): return a is float or a is int)
	session.wave_resist = g.call("wave_resist", -1)
	if not session.wave_resist in Elem.ALL:
		session.wave_resist = -1
	Vary.load_from(g.call("vary", {}))
	session.abilities_system._skills_new_run(int(g.call("skill_set", 0)))
	session.ley = []
	if session.abilities_system.leys_on():
		for q in g.call("ley", []):
			if q is Array and q.size() == 2 and (q[0] is float or q[0] is int) and (q[1] is float or q[1] is int):
				session.ley.append(Vector2(q[0], q[1]).clamp(session.combat_system.field_rect().position, session.combat_system.field_rect().end))
	session.skill_used = maxi(0, int(g.call("skill_used", 0)))
	# 미리 뽑아 둔 보스 (없거나 형식이 다르면 새로 뽑음)
	var bp: Variant = g.call("boss", {})
	session.boss_plan = {}
	if bp is Dictionary and bp.get("wave") is int and bp["wave"] == session.wave + 1 and bp.get("a") is float and bp.get("hp") is float and bp.get("spd") is float and bp.get("resist") is int and bp.get("sturdy") is bool:
		session.boss_plan = {"wave": bp["wave"], "a": bp["a"], "hp": maxf(1.0, bp["hp"]), "spd": maxf(1.0, bp["spd"]), "resist": bp["resist"] if bp["resist"] in Elem.ALL else -1, "sturdy": bp["sturdy"], "y": clampf(float(bp.get("y", 0.0)), -BinduSession.LINE_HALF, BinduSession.LINE_HALF)}
	else:
		session.spawning_system._plan_boss()
	session.new_achievements = (g.call("achievements", []) as Array).filter(func(a): return a is String)
	Ach.load_run(cfg.get_value("run", "ach_run", {}))
	session.run_log = (g.call("log", []) as Array).filter(func(e): return e is Dictionary)
	session.leak_log = (g.call("leaks", []) as Array).filter(func(e): return e is Dictionary and e.has("w") and e.has("n") and e.has("dmg") and e.has("kinds"))
	session.run_game = maxf(0.0, g.call("game_secs", 0.0))
	session.run_real = maxf(0.0, g.call("real_secs", 0.0))
	session.run_id = str(g.call("run_id", ""))
	if session.run_id == "":
		session.run_id = session._new_run_id()  # 판 번호가 없던 예전 저장
	session.tutor = g.call("tutor", false)
	session.tutor_given = {}
	for k in g.call("tutor_given", []):
		if k in BinduSession.TUTOR_OPEN:
			session.tutor_given[k] = true
	# 오브젝트: 연결선은 저장 순서 번호로 다시 잇는다 (못 읽은 것은 null로 자리만 지킴)
	var raw: Array = g.call("towers", [])
	var made: Array = []
	for d in raw:
		var t: Tower = null
		if d is Dictionary:
			t = Tower.new()
			t.main = session
			t.load_save(d)
			var fr := session.combat_system.field_rect()
			t.position = t.position.clamp(fr.position, fr.end)  # 손으로 고친 저장에서 화면 밖 위치
			if t.order.is_empty():
				t.free()
				t = null
			else:
				session.towers.add_child(t)
		made.append(t)
	# 예전 저장의 연결선("links")은 없어진 카드라 읽지 않는다
	for t in session.towers.get_children():
		t.eff = t.eff_now()
	session.hud_system._refresh_build()
	match g.call("state", "choose"):
		"perk":
			session.perk_offer = []
			for id in g.call("perk_offer", []):
				for pk in BinduSession.PERKS:
					if pk["id"] == id and session.cards_system._card_enabled({"type": "perk", "id": id}):
						session.perk_offer.append(pk)
			if session.perk_offer.is_empty():
				session.perks_system._start_perk()
			else:
				session.perks_system._show_perks()
		"ready":
			session.cards_system._clear_shots()
			session.waves_system._update_preview()
			session.cards_system._enter_ready()
			if session.skip_left > 0:
				session.countdown = 1.0  # 넘기는 중에 껐다: 이어서 넘긴다
		_:
			session.picks_left = maxi(1, session.picks_left)
			session.offer = (g.call("offer", []) as Array).filter(_valid_card)
			if session.offer.is_empty():
				session.cards_system._make_choices()
			else:
				session.cards_system._show_offer()
			session.cards_system._open_choose()
	if session.old_run_ver == "":
		session.hud_system._show_toast("웨이브 %d 앞 쉬는 시간부터 이어서 합니다" % (session.wave + 1))


## 저장된 판이 지난 마이너 버전(x.Y)에서 저장됐으면 그 버전 (마이너가 같거나 저장이 없으면 "").
## 패치(x.y.Z)만 바뀐 판은 그대로 이어 한다.
func _old_run_version() -> String:
	var info := _run_info()
	if info.is_empty():
		return ""
	var v := str(Meta.val(info["cfg"], "run", "version", ""))
	if Net.same_minor(v, Net.game_version()):
		return ""
	return v if v != "" else "?"


## 마이너 버전이 바뀌면 지난 버전의 판은 이어 하지 않는다: 그 판을 불러와 지금 점수로 끝낸다
## (판 끝내기와 같이 기록 저장·온라인 전송, 저장은 지움). 결과를 보여 주고 클릭하면 시작 화면.
func _end_old_run(v: String) -> void:
	var session: BinduSession = self.session
	session.old_run_ver = v
	_continue_run()
	session.perk_mode = false
	session.ended = true
	session.run_flow_system._game_over()
	session.over_label.text = session.patchlog_system._kr_keep("v%s에서 하던 판은 새 버전(v%s)에서 이어 할 수 없어 지금 점수로 끝냈어요\n" % [v, Net.game_version()]) + session.over_label.text
