extends SceneTree
## 기능 명세 점검: docs/features.md에서 "검사"가 spec인 기능마다 기대 동작을 실제 게임 코드로 확인한다.
## 끝에 문서와 대조: 문서의 spec 줄을 하나도 확인하지 않았거나, 여기서 확인한 id가 문서에 없으면 실패.
## 실패가 있으면 끝 코드 1. 저장 파일을 쓰므로 tools/run.sh spec(프로젝트를 임시 폴더에 복사)으로 돌린다.
## 줄마다 "ok   <id> <설명>" / "FAIL <id> <설명>". 기능을 바꾸면 docs/features.md와 이 파일을 같이 고친다.
var main
var fails := 0
var seen := {}  # 확인한 기능 id -> true


func ok(id: String, c: bool, what: String) -> void:
	seen[id] = true
	print(("ok   " if c else "FAIL ") + id + " " + what)
	if not c:
		fails += 1


func _clear() -> void:
	for n in [main.towers, main.orbs, main.zones, main.projectiles]:
		for c in n.get_children():
			c.free()


func _fresh(w := 5) -> void:
	_clear()
	Modes.set_on([])
	Meta.rules = 1
	Meta.map_id = "plain"
	main._apply_rules()
	Tower.dmg_mul = 1.0
	Tower.spd_mul = 1.0
	Tower.reach_mul = 1.0
	Tower.tax_step = Rules.tax_step
	main.perks = {}
	main.regen_acc = 0.0
	main.shield = 0
	main.shield_keep = 0
	main.rampart_left = 0
	main.riposte_cd = 0.0
	main.perk_mode = false
	main.coin_next = ""
	main.orb_speed_mul = 1.0
	main.tutor = false
	main.wave = w
	main.score = 0
	main.combo = 0
	main.combo_t = 0.0
	main.core_max = main.CORE_MAX_HP
	main.core_hp = main.CORE_MAX_HP
	main.bank_picks = []
	main.bank_perks = 0
	main.skip_left = 0
	main.lanes.clear()
	main._roll_lanes()


func _tower(p: Vector2, e := Elem.FIRE, lv := 1, d := Vector2.RIGHT) -> Tower:
	main.picked = {"type": "elem", "e": e, "lv": lv}
	main._place_tower(p, d)
	var t: Tower = main.towers.get_child(main.towers.get_child_count() - 1)
	t.eff = t.eff_now()
	return t


func _orb(p: Vector2, hp: float, kind := Orb.Kind.NORMAL, spd := 0.0) -> Orb:
	var o := Orb.new()
	o.main = main
	o.position = p
	o.target = main.center()
	o.from_a = (p - main.center()).angle()
	o.setup(kind, hp, spd)
	main.orbs.add_child(o)
	return o


func _initialize():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"):
		print("FAIL 실제 게임 저장 폴더를 쓰게 됨: tools/run.sh spec 으로 돌리세요")
		quit(1)
		return
	seed(1)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._hide_title()
	_cards()
	_elements()
	_patterns()
	await _attacks()
	_mods_links()
	_waves()
	_orbs_cc()
	_score_core()
	_perks()
	_rules_modes()
	_vary()
	_save_load()
	_meta_misc()
	_multiplayer()
	_tutorial()
	_vote()
	_lint()
	print("SPEC %s (실패 %d, 확인한 기능 %d개)" % ["통과" if fails == 0 else "실패", fails, seen.size()])
	quit(1 if fails > 0 else 0)


# ---------- 카드·선택지 ----------

func _cards() -> void:
	_fresh()
	var c: Vector2 = main.center()
	_tower(c + Vector2(-200, 0))
	var bad3 := 0
	var no_elem := 0
	var dup := 0
	for i in 200:
		main._make_choices()
		if main.offer.size() != 3:
			bad3 += 1
		if not main.offer.any(func(cd): return cd["type"] == "elem"):
			no_elem += 1
		var keys := {}
		for cd in main.offer:
			keys[main._card_key(cd)] = true
		if keys.size() != main.offer.size():
			dup += 1
	ok("CARD-01", bad3 == 0 and no_elem == 0, "선택지 3장, 속성 카드 최소 1장 (200번 중 어긋남 %d·%d)" % [bad3, no_elem])
	ok("CARD-03", dup == 0, "같은 카드가 두 장 나오지 않음 (겹침 %d)" % dup)

	# 넣을 곳이 없는 공격방식 카드는 나오지 않는다: 분사로 정해진 오브젝트 하나뿐이면 공격방식 카드는 분사(레벨업)만
	_clear()
	var t := _tower(c + Vector2(-200, 0))
	t.set_pattern("spray")
	var wrong := 0
	for i in 300:
		main._make_choices()
		for cd in main.offer:
			if cd["type"] == "pat" and cd["id"] != "spray":
				wrong += 1
	ok("CARD-02", wrong == 0, "넣을 곳이 없는 공격방식 카드는 선택지에 없음 (어긋남 %d)" % wrong)

	# 오브젝트가 없으면 속성 카드만
	_clear()
	var only_elem := true
	for i in 50:
		main._make_choices()
		only_elem = only_elem and main.offer.all(func(cd): return cd["type"] == "elem")
	ok("CARD-04", only_elem, "오브젝트가 없으면 속성 카드만")

	# 첫 판: 종류가 웨이브마다 열림
	main.tutor = true
	var opened := []
	for w in [0, 2, 3, 4, 5]:
		main.wave = w
		opened.append([main._card_open("pat"), main._card_open("mod"), main._card_open("trig"), main._card_open("link")])
	main.tutor = false
	ok("CARD-05", opened == [[false, false, false, false], [true, false, false, false], [true, true, false, false], [true, true, true, false], [true, true, true, true]],
		"첫 판 카드 종류가 공격방식 3·강화 4·발동 5·연계 6웨이브에 열림 %s" % str(opened))

	# 새로고침
	_fresh()
	_tower(c + Vector2(-200, 0))
	main.phase = main.Phase.CHOOSE
	main.rerolls_left = 1
	main._on_reroll()
	var after1: int = main.rerolls_left
	main._on_reroll()
	ok("CARD-06", after1 == 0 and main.rerolls_left == 0 and main.offer.size() == 3, "새로고침은 남은 횟수만큼, 다 쓰면 그대로")

	# 쉬는 시간마다 고르는 수: 처음 두 번 2장, 그 뒤 규칙 장수
	main.wave = 0
	main._new_rest()
	var p0: int = main.picks_left
	main.wave = 6
	main._new_rest()
	ok("CARD-07", p0 == 2 and main.picks_left == Rules.picks, "고르는 수: 첫 쉬는 시간 %d, 그 뒤 %d (규칙 %d)" % [p0, main.picks_left, Rules.picks])

	# 속성 Lv2 확률: 20% + 웨이브마다 2%, 최대 50%, 행운 +20%
	main.wave = 0
	var a0: float = main._lv2_chance()
	main.wave = 40
	var a40: float = main._lv2_chance()
	main.perks = {"luck": 1}
	var al: float = main._lv2_chance()
	main.perks = {}
	ok("CARD-08", is_equal_approx(a0, 0.2) and is_equal_approx(a40, 0.5) and is_equal_approx(al, 0.7), "속성 Lv2 확률 %.2f → %.2f, 행운 %.2f" % [a0, a40, al])


# ---------- 속성 ----------

func _elements() -> void:
	_fresh()
	var c: Vector2 = main.center()
	var t := _tower(c + Vector2(-200, 0), Elem.WATER, 2)
	ok("ELEM-01", t.pattern == "shot" and t.elements == {Elem.WATER: 2} and t.plv == 1, "빈 곳에 속성 카드 → 직선탄 + 그 속성 (%s)" % t.title())

	t.add(Elem.FIRE, 1)
	t.add(Elem.ICE, 1)
	var fourth := t.can_take({"type": "elem", "e": Elem.WOOD, "lv": 1})
	var same := t.can_take({"type": "elem", "e": Elem.FIRE, "lv": 1})
	ok("ELEM-02", not fourth and same, "랭크: 속성 3종까지, 같은 속성 레벨은 계속")
	ok("ELEM-03", is_equal_approx(t.tax(), 1.0 + Rules.tax_step * 2) and is_equal_approx(Rules.tax_step, 0.15), "쌓기 대가: 종류마다 공격 속도 ÷(1+0.15×(종류-1)) (%.2f)" % t.tax())

	Meta.rules = 3
	main._apply_rules()
	ok("ELEM-04", t.can_take({"type": "elem", "e": Elem.WOOD, "lv": 1}) and is_equal_approx(Rules.tax_step, 0.25), "도파민 모드: 속성 종류 제한 없음, 대가 0.25")
	Meta.rules = 1
	main._apply_rules()

	# 91개 조합 모두 반응
	var missing := []
	var ids := {}
	for i in Elem.ALL.size():
		for j in range(i + 1, Elem.ALL.size()):
			var rs := Elem.reactions_with({Elem.ALL[i]: 1, Elem.ALL[j]: 1})
			if rs.is_empty():
				missing.append("%s+%s" % [Elem.NAMES[Elem.ALL[i]], Elem.NAMES[Elem.ALL[j]]])
			for r in rs:
				ids[r["id"]] = true
	ok("ELEM-05", missing.is_empty() and ids.size() == 91 and Elem.REACTIONS.size() == 91, "두 속성 조합 91개 모두 특수 반응 (빠짐 %s, 반응 %d)" % [str(missing), ids.size()])

	t.eff = t.eff_now()
	var fresh := Elem.new_reactions({Elem.FIRE: 1}, Elem.WOOD)
	ok("ELEM-06", fresh.size() == 1 and t.reactions().size() == 3, "속성을 더하면 새 반응 알림, 3종이면 반응 3개")

	var no_rider := Elem.ALL.filter(func(e): return Elem.rider(e).is_empty())
	ok("ELEM-07", no_rider.is_empty() and Elem.ALL.size() == 14, "속성 14종 모두 부가효과 설명이 있음")


# ---------- 공격방식 ----------

func _patterns() -> void:
	_fresh()
	var c: Vector2 = main.center()
	var t := _tower(c + Vector2(-200, 0))
	var m1 := t.set_pattern("spray")
	var other := t.can_pattern("laser")
	t.set_pattern("spray")
	ok("PAT-01", m1 != "" and not other and t.pattern == "spray" and t.plv == 2, "직선탄에서 한 번만 교체, 이후 같은 것만(레벨업)")

	var t2 := _tower(c + Vector2(200, 0))
	t2.set_pattern("thorn")
	var t3 := _tower(c + Vector2(0, 200))
	t3.add_mod("pierce")
	ok("PAT-02", not t2.can_take({"type": "mod", "id": "pierce"}) and not t3.can_pattern("thorn") and t3.can_pattern("spray"),
		"효과 없는 강화 표(Pat.NO_MOD): 관통 연사에 관통 못 넣음, 관통 든 직선탄은 관통 연사로 못 바꿈")

	var tab_ok := true
	for mod in Pat.NO_MOD:
		for p in Pat.NO_MOD[mod]:
			tab_ok = tab_ok and not Pat.mod_ok(p, mod) and Pat.no_mod_why(p, mod) != ""
	ok("PAT-03", tab_ok, "Pat.NO_MOD 모든 칸에 못 넣는 이유 문구")

	# 대격변
	_clear()
	var a := _tower(c + Vector2(-200, 0), Elem.FIRE, 2)
	a.add(Elem.WATER, 1)
	var lv_before := a.total_level()
	a.cataclysm_elements()
	var b := _tower(c + Vector2(200, 0))
	b.cataclysm_pattern()
	ok("CATA-01", a.total_level() >= lv_before and a.order.size() >= 1 and b.pattern != "shot" and b.pattern in Pat.PATTERN_IDS,
		"대격변: 속성은 레벨 합을 지키며 다시 뽑고, 공격방식은 직선탄이 아닌 것으로 (%s / %s)" % [a.title(), b.title()])


## 공격방식마다: 다가오는 구체에 실제로 피해를 준다.
func _attacks() -> void:
	_fresh(5)
	var c: Vector2 = main.center()
	var silent := []
	for p in Pat.PATTERN_IDS:
		_clear()
		var t := _tower(c + Vector2(-80, 0), Elem.FIRE, 1, Vector2.LEFT)
		if p != "shot":
			t.set_pattern(p)
		var o := _orb(c + Vector2(-420, 0), 99999.0, Orb.Kind.NORMAL, 45.0)
		main.wave_active = true
		main.phase = main.Phase.WAVE
		main.to_spawn = 0
		for i in 360:  # 6초
			main._sim_step(1.0 / 60.0)
			if not is_instance_valid(o) or o.hp < o.max_hp:
				break
		if not is_instance_valid(o) or o.hp >= o.max_hp:
			silent.append(p)
		await process_frame
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	ok("PAT-04", silent.is_empty(), "공격방식 %d개 모두 앞에서 다가오는 구체에 피해 (못 맞힘: %s)" % [Pat.PATTERN_IDS.size(), str(silent)])


# ---------- 강화·연계·발동 ----------

func _mods_links() -> void:
	_fresh()
	var c: Vector2 = main.center()
	var t := _tower(c + Vector2(-200, 0))
	for i in Rules.max_mod:
		t.add_mod("rapid")
	ok("MOD-01", Rules.max_mod == 5 and not t.can_take({"type": "mod", "id": "rapid"}), "랭크: 같은 강화 5개까지")
	ok("MOD-02", is_equal_approx(t.spd_k() * t.tax(), 1.5), "속사 5개 = 공격 속도 +50%% (%.2f)" % (t.spd_k() * t.tax()))

	Meta.rules = 3
	main._apply_rules()
	var u := Tower.new()
	u.mods = {"size": 3}
	ok("MOD-03", is_equal_approx(u.mf("size"), 1.75), "도파민 모드: 같은 강화는 1, 1.5, 1.75… (3개 %.2f)" % u.mf("size"))
	u.free()
	Meta.rules = 1
	main._apply_rules()

	ok("MOD-04", is_equal_approx(Pat.mod_fix("shot", "multi", 5.0), Pat.MOD_FIX["shot"]["multi"]) and is_equal_approx(Pat.mod_fix("shot", "rapid", 5.0), 1.0),
		"강화 보정표: 5개면 표의 배율, 표에 없으면 1")

	# 공명: 150 안의 다른 오브젝트 하나당 +12%
	_clear()
	var r := _tower(c + Vector2(-200, 0))
	var before := r.dmg_factor()
	r.add_link("reso")
	var near := _tower(c + Vector2(-100, 0))
	var crowd := (1.0 + Rules.crowd_bonus(2)) / (1.0 + Rules.crowd_bonus(1))
	ok("LINK-01", is_equal_approx(r.dmg_factor() / before, crowd * 1.12), "공명: 가까운 오브젝트 하나당 피해 +12%% (x%.3f)" % (r.dmg_factor() / before / crowd))
	near.add_link("prism")
	near.add_link("pincer")
	ok("LINK-02", near.prism == 1 and near.pincer == 1 and near.extras_text().contains("프리즘") and near.extras_text().contains("협공"), "프리즘·협공을 넣으면 오브젝트에 표시")

	ok("CROWD-01", is_equal_approx(Rules.crowd_bonus(5), 0.1 * log(5.0)) and roundi(Rules.crowd_bonus(10) * 100) == 23, "오브젝트 수 보너스: 5개 +%d%%, 10개 +%d%%" % [roundi(Rules.crowd_bonus(5) * 100), roundi(Rules.crowd_bonus(10) * 100)])

	for i in Tower.TRIG_MAX:
		r.add_trig("vanguard")
	ok("TRIG-01", not r.can_take({"type": "trig", "id": "vanguard"}) and r.can_take({"type": "trig", "id": "echo"}), "발동 카드는 종류마다 %d장까지" % Tower.TRIG_MAX)
	ok("TRIG-02", is_equal_approx(Tower.van_time(1), 5.0) and is_equal_approx(Tower.van_time(2), 7.5), "선봉: 5초, 한 장마다 +2.5초")
	r.wave_begin()
	ok("TRIG-03", r.van_ready and r.van_k() == 1.0, "선봉은 웨이브 시작이 아니라 첫 타격부터 (시작 직후 x1)")
	r.van_t = 1.0
	ok("TRIG-04", r.van_k() == Tower.VAN_SPD, "선봉 켜진 동안 공격 속도 x2")


# ---------- 웨이브 ----------

func _waves() -> void:
	_fresh()
	ok("WAVE-01", main.wave_size(1) == 4 and main.wave_size(10) == 23 and main.wave_size(20) == 43, "웨이브 구체 수 3+2w, 1웨이브 70%%에서 10웨이브 100%% (%d·%d·%d)" % [main.wave_size(1), main.wave_size(10), main.wave_size(20)])
	var ls := [1, 3, 6, 9, 12, 18, 24, 99].map(func(w): return main.lanes_for(w))
	ok("WAVE-02", ls == [1, 2, 3, 4, 4, 5, 6, 6], "진입 방향 수: 3·6·9웨이브에 하나씩, 18·24에 하나씩, 최대 6 %s" % str(ls))
	ok("WAVE-03", main.spawn_count(3) == roundi(main.wave_size(3) * 0.8) and main.spawn_count(4) == main.wave_size(4), "새 진입 방향이 열리는 웨이브는 구체 20% 적게")
	Meta.map_id = "cross"
	var cross: int = main.spawn_count(4)
	Meta.map_id = "plain"
	ok("WAVE-04", cross == roundi(main.wave_size(4) * 1.5), "십자로 맵 구체 1.5배")
	ok("WAVE-05", is_equal_approx(main.hp_growth(10), 1.0) and is_equal_approx(main.hp_growth(12), 1.05 * 1.05), "11웨이브부터 구체 체력 웨이브마다 x1.05")
	ok("WAVE-06", main.resist_share(9) == 0.0 and main.resist_share(10) > 0.0 and main.sturdy_share(12) == 0.0 and main.sturdy_share(13) > 0.0, "저항 구체 10웨이브, 굳센 구체 13웨이브부터")

	var kinds := {}
	for w in [1, 3, 4, 7]:
		main.wave = w
		var s := {}
		for i in 400:
			s[main._roll_kind()] = true
		kinds[w] = s
	ok("WAVE-07", kinds[3].keys() == [Orb.Kind.NORMAL] and kinds[4].has(Orb.Kind.FAST) and not kinds[4].has(Orb.Kind.TANK) and kinds[7].has(Orb.Kind.TANK),
		"구체 종류: 빠른 4웨이브·단단한 7웨이브부터")

	# 보스: 5웨이브마다 마지막 구체, 쉬는 시간에 미리 정함
	main.wave = 4
	main._plan_boss()
	var planned: bool = main.boss_plan.get("wave", -1) == 5
	main.wave = 5
	main.to_spawn = 1
	main.spawn_timer = 0.0
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main._sim_step(1.0 / 60.0)
	var boss: Orb = null
	for o in main.orbs.get_children():
		if o.kind == Orb.Kind.BOSS:
			boss = o
	ok("WAVE-08", planned and boss != null and boss.core_dmg == 3, "5웨이브마다 마지막에 보스(중앙 3 피해), 앞 쉬는 시간에 미리 정함")
	_clear()
	main.wave_active = false
	main.phase = main.Phase.CHOOSE


# ---------- 구체·군중 제어 ----------

func _orbs_cc() -> void:
	_fresh()
	var o := _orb(main.center() + Vector2(300, 0), 10.0, Orb.Kind.NORMAL, 50.0)
	o.slow(0.05, 2.0)
	var floor_n := o.slow_factor
	var b := _orb(main.center() + Vector2(300, 50), 10.0, Orb.Kind.BOSS, 50.0)
	b.slow(0.05, 2.0)
	ok("CC-01", is_equal_approx(floor_n, Orb.SLOW_FLOOR) and is_equal_approx(b.slow_factor, 0.5), "감속은 최대 70%%, 보스 50%% (%.2f·%.2f)" % [floor_n, b.slow_factor])

	var durs := []
	for i in 4:
		o.root_timer = 0.0
		var hit := o.root(1.0)
		durs.append(o.root_timer if hit else -1.0)
	ok("CC-02", durs == [1.0, 0.5, 0.25, -1.0], "기절·속박·빙결: 100%%→50%%→25%% 뒤 면역 %s" % str(durs))

	var s := _orb(main.center() + Vector2(300, -50), 10.0, Orb.Kind.NORMAL, 50.0)
	s.sturdy = true
	s.root(1.0)
	ok("CC-03", is_equal_approx(s.root_timer, 0.5), "굳센 구체는 기절 시간 절반")

	o.resist_e = Elem.FIRE
	ok("ORB-01", is_equal_approx(o.resist_mul({Elem.FIRE: 1}), 0.4) and is_equal_approx(o.resist_mul({Elem.FIRE: 1, Elem.WATER: 1}), 0.7) and o.resist_mul({Elem.WATER: 1}) == 1.0,
		"저항 구체: 그 속성 비중만큼 피해 최대 60% 감소")
	var sh := _orb(main.center() + Vector2(300, 80), 10.0)
	sh.shield = 3.0
	sh.hurt(5.0)
	ok("ORB-02", is_equal_approx(sh.hp, 8.0) and sh.shield == 0.0, "보호막이 피해를 먼저 흡수")
	_clear()


# ---------- 점수·중앙 ----------

func _score_core() -> void:
	_fresh()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	var o := _orb(main.center() + Vector2(300, 0), 3.0)
	o.hp = 0.0
	main._resolve(1.0 / 60.0)
	var first: int = main.score
	ok("SCORE-01", first == int(3.0 * 10 * 1.1) and main.combo == 1, "처치 점수 = 최대 체력x10 x 콤보 배율 (%d)" % first)
	var o2 := _orb(main.center() + Vector2(300, 40), 3.0)
	o2.hp = 0.0
	main._resolve(1.0 / 60.0)
	ok("SCORE-02", main.combo == 2 and main.score - first == int(30 * 1.2), "3초 안 다음 처치는 콤보 +1, 처치마다 점수 +10%")
	main.combo = 25
	ok("SCORE-03", is_equal_approx(main.combo_mul(), 3.0), "콤보 20부터 x3")
	main.combo = 2
	main.combo_t = 0.01
	main.to_spawn = 5  # 웨이브가 끝나지 않게
	main.spawn_timer = 99.0
	main._sim_step(0.1)
	var o3 := _orb(main.center() + Vector2(300, 80), 3.0)
	o3.hp = 0.0
	main._resolve(1.0 / 60.0)
	ok("SCORE-04", main.combo == 1, "3초 넘게 처치가 없으면 콤보가 끊김")

	# 보스 처치: 중앙 +2, 새로고침 +1
	main.core_hp = 5
	main.bonus_rerolls = 0
	var bo := _orb(main.center() + Vector2(300, 0), 3.0, Orb.Kind.BOSS)
	bo.hp = 0.0
	main._resolve(1.0 / 60.0)
	ok("BOSS-01", main.core_hp == 7 and main.bonus_rerolls == 1, "보스 처치: 중앙 체력 +2, 새로고침 +1")

	# 중앙에 닿으면 체력 -1(보스 -3), 누수 기록
	_clear()
	main.core_hp = 10
	main.wave_leaks.clear()
	_orb(main.center(), 5.0)
	main._resolve(1.0 / 60.0)
	var after_n: int = main.core_hp
	_orb(main.center(), 5.0, Orb.Kind.BOSS)
	main._resolve(1.0 / 60.0)
	ok("CORE-01", after_n == 9 and main.core_hp == 6 and main.wave_leaks.size() == 2, "구체가 중앙에 닿으면 -1, 보스 -3, 누수 기록")

	# 웨이브 클리어: 보너스 점수, 5웨이브마다 특성, 아니면 카드
	_clear()
	main.wave = 4
	main.to_spawn = 0
	main.score = 0
	main.perk_mode = false
	main._sim_step(1.0 / 60.0)
	ok("WAVE-09", main.score == 4 * 20 and main.phase == main.Phase.CHOOSE and not main.perk_mode, "웨이브 클리어 +웨이브x20점, 다음 쉬는 시간은 카드 고르기")
	main.wave = 5
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main._sim_step(1.0 / 60.0)
	ok("PERK-01", main.perk_mode and main.perk_offer.size() == 3, "보스 웨이브(5의 배수)를 넘기면 특성 3개 중 고르기")
	main.perk_mode = false

	# 게임 오버
	_clear()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.core_hp = 1
	main.to_spawn = 5
	main.spawn_timer = 99.0
	_orb(main.center(), 5.0)
	main._sim_step(1.0 / 60.0)
	ok("CORE-02", main.phase == main.Phase.GAMEOVER and main.over_label.visible and not FileAccess.file_exists(main.RUN_PATH), "중앙 체력 0이면 게임 오버, 이어하기 저장 지움")
	main.over_label.visible = false
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()


# ---------- 특성 ----------

func _perks() -> void:
	_fresh()
	var ids: Array = main.PERKS.map(func(p): return p["id"])
	ok("PERK-02", ids.size() == 14 and ids.has("coin") and ids.has("shield") and ids.has("rampart") and ids.has("riposte") and ids.has("overflow"), "특성 14종 (%s)" % ",".join(ids))
	main._apply_perk("power")
	main._apply_perk("haste")
	main._apply_perk("reach")
	main._apply_perk("core")
	main._apply_perk("slow")
	main._apply_perk("harmony")
	ok("PERK-03", is_equal_approx(Tower.dmg_mul, 1.15) and is_equal_approx(Tower.spd_mul, 1.12) and is_equal_approx(Tower.reach_mul, 1.12)
		and main.core_max == 13 and main.core_hp == 13 and is_equal_approx(main.orb_speed_mul, 0.92) and is_equal_approx(Tower.tax_step, Rules.tax_step * 0.5),
		"특성 효과: 화력 +15%·속사 +12%·원거리 +12%·중앙 +3 회복·끈적 -8%·조화 대가 절반")
	main.wave = 5
	main.rest_ready = false
	main._start_perk()
	var heads := 0
	var tails := 0
	for i in 40:
		main.perk_mode = true
		main.coin_next = ""
		main._on_perk(main.PERKS[9])
		if main.coin_next == "double":
			heads += 1
		elif main.coin_next == "reroll":
			tails += 1
	ok("PERK-04", heads > 0 and tails > 0 and heads + tails == 40 and not main.perk_offer.any(func(p): return p["id"] == "coin"),
		"운명의 동전: 앞면(두 번)·뒷면(새로고침) 중 하나, 다시 받는 특성에 동전 없음 (%d·%d)" % [heads, tails])
	main.perk_mode = true
	main.coin_next = "double"
	var pw := Tower.dmg_mul
	main._on_perk(main.PERKS[0])
	var pw_n: int = main.perks.get("power", 0)
	ok("PERK-05", is_equal_approx(Tower.dmg_mul, pw + 0.3) and main.coin_next == "", "동전 앞면: 고른 특성이 두 번 적용")
	var keep_perks: Dictionary = main.perks.duplicate()
	main.perks = {"regen": 1}
	main.regen_acc = 0.0
	var r1 := [main._regen_take(), main._regen_take()]
	main.perks = {"regen": 2}
	var r2 := [main._regen_take(), main._regen_take()]
	main.perks = {"regen": 3}
	var r3 := [main._regen_take(), main._regen_take()]
	var big: String = main._perk_big("regen", main.PERKS[6]["desc"]).get("big", "")
	main.perks = {}
	var big0: String = main._perk_big("regen", main.PERKS[6]["desc"]).get("big", "")
	main.perks = keep_perks
	main.regen_acc = 0.0
	ok("PERK-07", r1 == [1, 1] and r2 == [1, 2] and r3 == [2, 2] and big0 == "+1/웨이브" and big == "+0.5/웨이브",
		"회복 겹치기: 1개 웨이브마다 +1, 2개 +1.5, 3개 +2, 카드 숫자 +1 → 이미 있으면 +0.5 (%s %s %s %s %s)" % [r1, r2, r3, big0, big])
	# 동전 연출: 공중 회전 → 누르면 떨어짐(안 누르면 1초 뒤) → 모서리 흔들림 → 결과, 그동안 카드·특성 고르기·저장 막음
	main.coin_anim = true
	main.perk_mode = true
	main._on_perk(main.PERKS[9])
	var st := [main.coin_stage, main.choice_box.visible]
	main._on_perk(main.PERKS[0])  # 연출 중 특성 키는 먹지 않음
	var held: bool = main.coin_stage == 1 and main.perks.get("power", 0) == pw_n
	main._coin_tap()
	var dropped: bool = main.coin_stage == 2
	for i in 200:
		if main.coin_stage == 0:
			break
		main._coin_step(0.02)
	var auto_ok: bool = main.coin_stage == 0 and main.perk_mode and main.perk_offer.size() == 3 and not main.perk_offer.any(func(p): return p["id"] == "coin")
	main.perk_mode = true
	main.coin_next = ""
	main._on_perk(main.PERKS[9])
	for i in 200:  # 안 누르고 두면 저절로 끝까지
		if main.coin_stage == 0:
			break
		main._coin_step(0.02)
	ok("PERK-06", st[0] == 1 and not st[1] and held and dropped and auto_ok and main.coin_stage == 0 and main.coin_next in ["double", "reroll"],
		"동전 연출: 던지면 카드가 사라지고 회전, 누르면 떨어지고 결과 뒤 새 특성 3개 (누르지 않아도 끝남)")
	main.coin_anim = false
	main.coin_next = ""
	main.perk_mode = false


	_core_guard()


## 중앙 특성: 실드·성벽·반격 파동·넘친 회복
func _core_guard() -> void:
	_fresh()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.perks = {"shield": 5}
	var cap: int = main._shield_wave()
	main.perks = {"shield": 1}
	main.shield = main._shield_wave()
	_orb(main.center(), 5.0)
	main._resolve(1.0 / 60.0)
	var hp1: int = main.core_hp
	var sh1: int = main.shield
	_orb(main.center(), 5.0)
	main._resolve(1.0 / 60.0)
	ok("PERK-08", cap == 3 and hp1 == main.CORE_MAX_HP and sh1 == 0 and main.core_hp == main.CORE_MAX_HP - 1,
		"실드: 웨이브마다 1칸(겹치면 +1, 최대 3), 맞으면 체력 대신 실드가 깎임 (최대 %d, 막은 뒤 체력 %d, 다음 %d)" % [cap, hp1, main.core_hp])

	_fresh()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	var no_wall: bool = not main._has_wall()
	var t := _tower(main.center() + Vector2(0, 200))
	t.set_pattern("wall")
	main.perks = {"rampart": 1}
	main.rampart_left = main._rampart_n()
	var n0: int = main.rampart_left
	var o := _orb(main.center() + Vector2(main.RAMPART_R, 0), 5.0)
	main._resolve(1.0 / 60.0)
	var pushed: bool = o.position.distance_to(main.center()) > main.RAMPART_R + 100.0 and o.walled
	o.position = main.center() + Vector2(main.RAMPART_R, 0)
	main._resolve(1.0 / 60.0)  # 한 번 밀린 구체는 다시 막지 않음
	ok("PERK-09", no_wall and n0 == 2 and pushed and main.rampart_left == 1 and main.core_hp == main.CORE_MAX_HP,
		"성벽: 벽 오브젝트가 있어야 나옴, 조각 = 벽 레벨 합 + 1, 다가온 구체를 한 번 밀어내고 한 조각 부서짐 (조각 %d → %d)" % [n0, main.rampart_left])

	_fresh()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.perks = {"riposte": 1}
	_orb(main.center(), 5.0)
	var far := _orb(main.center() + Vector2(100, 0), 1000000.0)
	main._resolve(1.0 / 60.0)
	ok("PERK-10", far.hp < 1000000.0 and far.position.distance_to(main.center()) > 100.0 and main.core_hp == main.CORE_MAX_HP - 1,
		"반격 파동: 중앙이 맞으면 가까운 구체에 피해·밀어내기")

	_fresh()
	main.perks = {"overflow": 1}
	main._heal_core(1)
	var k1: int = main.shield_keep
	main._heal_core(5)
	var k2: int = main.shield_keep
	main.core_hp = main.CORE_MAX_HP - 1
	main.shield_keep = 0
	main._heal_core(2)
	var part: Array = [main.core_hp, main.shield_keep]
	main.perks = {"overflow": 1, "shield": 3}
	main.shield_keep = 0
	main._heal_core(3)
	ok("PERK-11", k1 == 1 and k2 == 2 and part == [main.CORE_MAX_HP, 1] and main.shield_keep == 1,
		"넘친 회복: 체력이 가득할 때 회복은 실드로(최대 2, 모든 실드 합 4) (%d %d %s %d)" % [k1, k2, part, main.shield_keep])
	main.perks = {}
	main.shield_keep = 0


# ---------- 규칙·모드 ----------

func _rules_modes() -> void:
	ok("RULE-01", Rules.IDS == [1, 3] and Rules.NAMES[1] == "랭크" and Rules.NAMES[3] == "도파민 모드", "고를 수 있는 규칙: 랭크(1)·도파민 모드(3)")
	# 폰: 규칙 줄 글을 눌러도 바뀐다 (화살표 버튼이 손가락보다 작아서), 터치 화면엔 "눌러서 바꾸기"
	var g0: int = Meta.games
	Meta.games = 1
	Meta.rules = 1
	main.touch_ui = true
	main._refresh_menu()
	var tap_txt: bool = main.rules_label.text.contains("눌러서 바꾸기") and not main.rules_label.text.contains("↑/↓")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	main.rules_label.gui_input.emit(up)
	var r1: int = Meta.rules
	main.rules_label.gui_input.emit(up)
	ok("RULE-04", main.rules_label.get_parent().visible and tap_txt and r1 == 3 and Meta.rules == 1 and main.rules_label.mouse_filter == Control.MOUSE_FILTER_STOP, "규칙 줄 글을 누르면 랭크 ↔ 도파민 모드, 터치 화면 안내 '눌러서 바꾸기'")
	main.touch_ui = false
	Meta.games = g0
	main._refresh_menu()
	Rules.apply(5)
	var v5 := Rules.version
	Rules.apply(1)
	ok("RULE-02", v5 == 1, "모르는(폐기한) 규칙 버전은 1로")
	Rules._apply_patch({"max_mod": 7, "picks": "x", "nope": 3, "wind_buff": -1})
	var patched := Rules.max_mod == 7 and Rules.picks == 2 and Rules.t("wind_buff") == 0.0
	Rules.apply(1)
	ok("PATCH-01", patched and Rules.max_mod == 5, "온라인 패치 rules: 아는 키만 적용, 형식이 틀린 값·모르는 키 무시, 새 판에 원래대로")

	Modes.set_on(["rush", "stroll", "bogus", "rush", "fort"])
	ok("MODE-01", Modes.on == ["rush", "fort"], "모드: 모르는 것·중복·반대 쌍 뒤쪽은 버림 %s" % str(Modes.on))
	ok("MODE-02", Modes.easy() and Meta.run_key().ends_with(Meta.EASY_TAG), "쉽게 모드가 하나라도 있으면 기록 따로")
	Modes.set_on(["rush", "swarm", "steel", "glass", "narrow", "early", "angry"])
	ok("MODE-03", is_equal_approx(Modes.mul(), Modes.MUL_MAX) and not Modes.easy(), "점수 배율은 곱, %.1f배에서 멈춤" % Modes.MUL_MAX)
	Modes.set_on(["three", "ease"])
	main._apply_rules()
	ok("MODE-04", Rules.picks == 3 and Modes.rerolls(1) == 3, "세 장: 고르기 3장, 여유: 새로고침 +2")
	Modes.set_on([])
	main._apply_rules()
	main._toggle_mode("stroll")
	var shown: bool = main.easy_notice.visible
	main.easy_notice_skip.button_pressed = true
	main._close_easy_notice()
	main._toggle_mode("stroll")
	main._toggle_mode("stroll")
	ok("MODE-05", shown and not main.easy_notice.visible and main._easy_notice_off(), "쉽게 모드를 켜면 안내, 다시 보지 않기면 안 뜸")
	Modes.set_on([])
	main._apply_rules()


# ---------- 판마다 다른 흐름 ----------

func _vary() -> void:
	_fresh(5)
	var off_after_rules := not Vary.on
	Vary.new_run(true)
	var counts_ok: bool = Vary.sealed["elem"].size() == 3 and Vary.sealed["pat"].size() == 4 and Vary.sealed["link"].size() == 1
	var c: Vector2 = main.center()
	_tower(c + Vector2(-200, 0))
	_tower(c + Vector2(200, 0))
	_tower(c + Vector2(0, -200))
	var leak := 0
	for i in 400:
		main._make_choices()
		for cd in main.offer:
			if cd["type"] == "elem" and Vary.is_sealed("elem", cd["e"]) or cd["type"] in ["pat", "link"] and Vary.is_sealed(cd["type"], cd["id"]):
				leak += 1
	var t: Tower = main.towers.get_child(0)
	for i in 30:
		t.cataclysm_pattern()
		if Vary.is_sealed("pat", t.pattern):
			leak += 1
	var n0 := Vary.count()
	Vary.rest(25)
	ok("VARY-01", off_after_rules and counts_ok and leak == 0 and Vary.count() == n0 - 1, "봉인: 속성 3·공격방식 4·연계 1, 선택지·대격변에 안 나옴(새어 나옴 %d), 25웨이브에 하나 풀림" % leak)

	Vary.new_run(true)
	Vary.rest(8)
	var none_yet: bool = Vary.next_event.is_empty() and Vary.event.is_empty()
	Vary.rest(9)
	var planned: bool = not Vary.next_event.is_empty()
	var pid: String = Vary.next_event.get("id", "")
	Vary.rest(10)
	var active: bool = Vary.ev_id() == pid and Vary.next_event.is_empty()
	Vary.event = {"id": "eclipse", "el": {Elem.LIGHT: 0.6, Elem.DARK: 1.4}, "pt": {}}
	var ecl: bool = is_equal_approx(Vary.tower_mul({Elem.LIGHT: 2}, "shot"), 0.6) and is_equal_approx(Vary.tower_mul({Elem.LIGHT: 1, Elem.DARK: 1}, "shot"), 1.0)
	Vary.event = {"id": "gold", "el": {}, "pt": {}}
	var gold: bool = Vary.score_k() == 2.0 and Vary.spd_k() > 1.0
	Vary.event = {"id": "shell", "el": {}, "pt": {}}
	var shell: bool = main._roll_orb(15)["sturdy"]
	Vary.event = {}
	ok("VARY-02", none_yet and planned and active and ecl and gold and shell, "이벤트: 9웨이브 뒤 예고, 10웨이브 뒤 시작해 10웨이브, 일식 빛 x0.6, 황금 점수 x2, 굳은 껍질 모두 굳셈")

	Vary.new_run(true)
	var soul := Tower.new()
	soul.elements = {Elem.SOUL: 3}
	soul.pattern = "wisp"
	soul.dealt = 900.0
	var fire := Tower.new()
	fire.elements = {Elem.FIRE: 1}
	fire.pattern = "shot"
	fire.dealt = 100.0
	for w in range(20, 29):
		Vary.wave_done(w, [soul, fire])
	var before_ok: bool = Vary.adapt_el.is_empty()
	for w in range(29, 60):
		Vary.wave_done(w, [soul, fire])
	var top_mul := Vary.tower_mul({Elem.SOUL: 3}, "wisp")
	var other_mul := Vary.tower_mul({Elem.FIRE: 1}, "shot")
	ok("VARY-03", before_ok and is_equal_approx(top_mul, 0.8) and is_equal_approx(other_mul, 1.0) and Vary.adapt_text() != "", "적응 구체: 30웨이브부터 1위 속성·공격방식에 저항, 합쳐 최대 20%%(%.2f), 나머지는 그대로" % top_mul)
	soul.free()
	fire.free()

	Vary.new_run(true)
	Vary.rest(9)
	Vary.adapt_el = {Elem.SOUL: 0.1}
	Vary.adapt_pt = {"wisp": 0.06}
	var saved := Vary.save()
	var want := [Vary.sealed.duplicate(true), Vary.next_event.duplicate(true), Vary.adapt_el.duplicate(), Vary.adapt_pt.duplicate()]
	Vary.load_from(JSON.parse_string(JSON.stringify(saved)))
	var got := [Vary.sealed, Vary.next_event, Vary.adapt_el, Vary.adapt_pt]
	ok("VARY-04", Vary.on and str(got) == str(want), "이어하기: 봉인·예고 이벤트·적응 저항이 저장 후 그대로")
	main.tutor = true
	Vary.new_run(main.mp_mode == "" and not main.tutor)
	var tut_off := not Vary.on
	main.tutor = false
	Patch.data = {"rules": {"all": {"vary_on": 0}}}
	Rules.apply(1)
	Vary.new_run(true)
	var patch_off := not Vary.on
	Patch.data = {}
	Rules.apply(1)
	Vary.new_run(false)
	ok("VARY-05", tut_off and patch_off and Vary.tower_mul({Elem.SOUL: 1}, "wisp") == 1.0, "첫 판·멀티플레이·정원은 끔, 패치 vary_on 0이면 끔")


# ---------- 이어하기 ----------

func _save_load() -> void:
	_fresh(7)
	var c: Vector2 = main.center()
	var a := _tower(c + Vector2(-200, 30), Elem.FIRE, 2, Vector2.UP)
	a.add(Elem.WOOD, 1)
	a.set_pattern("spray")
	a.add_mod("size")
	a.add_trig("echo")
	var b := _tower(c + Vector2(180, -40), Elem.ICE)
	b.add_link("prism")
	main.score = 1234
	main.core_hp = 6
	main.rerolls_left = 2
	main.perks = {"power": 1}
	main.phase = main.Phase.CHOOSE
	main.perk_mode = false
	main.offer = [{"type": "elem", "e": Elem.SOUL, "lv": 1}, {"type": "mod", "id": "rapid"}, {"type": "trig", "id": "vanguard"}]
	main._save_run()
	var want: Array = main.towers.get_children().map(func(t): return JSON.stringify(t.to_save()))
	_clear()
	main.score = 0
	main.wave = 0
	main.core_hp = 10
	main._continue_run()
	var got: Array = main.towers.get_children().map(func(t): return JSON.stringify(t.to_save()))
	ok("SAVE-01", FileAccess.file_exists(main.RUN_PATH) and got == want and main.wave == 7 and main.score == 1234 and main.core_hp == 6 and main.rerolls_left == 2 and main.perks == {"power": 1},
		"쉬는 시간 저장 → 이어하기: 오브젝트·웨이브·점수·중앙·새로고침·특성 그대로")
	ok("SAVE-02", main.offer.size() == 3 and main.offer[2].get("id") == "vanguard", "이어하기는 저장한 선택지 그대로")

	var cfg := ConfigFile.new()
	cfg.load(main.RUN_PATH)
	cfg.set_value("run", "version", "0.0.1")
	cfg.save(main.RUN_PATH)
	ok("SAVE-03", main._old_run_version() == "0.0.1", "게임 버전이 바뀐 저장은 지난 판으로 알아봄 (이어 하지 않고 끝냄)")
	cfg.set_value("run", "map", "nowhere")
	cfg.save(main.RUN_PATH)
	ok("SAVE-04", main._run_info().is_empty(), "모르는 맵 등 깨진 저장은 이어하기 버튼을 띄우지 않음")
	cfg.set_value("run", "map", "plain")
	cfg.set_value("run", "rules", 5)
	cfg.save(main.RUN_PATH)
	ok("SAVE-05", main._run_info().get("rules", 0) == 1, "폐기한 규칙(2·4·5)으로 저장된 판은 랭크로 이어 함")
	main._clear_run()
	_clear()


# ---------- 기록·도감·화면 글 ----------

func _meta_misc() -> void:
	Meta.codex.erase("spec_x")
	ok("META-01", Meta.discover("spec_x") and not Meta.discover("spec_x"), "반응 도감: 처음 발견할 때만 새로 추가")
	Meta.codex.erase("spec_x")
	Meta.achieved.erase("first")
	ok("META-02", Meta.achieve("first") and not Meta.achieve("first"), "업적: 한 번만 달성")
	var skins_ok := Meta.TOWER_SKIN_IDS.all(func(s): return Meta.TOWER_SKINS[s]["need"] == "" or Meta.ACHIEVEMENTS.has(Meta.TOWER_SKINS[s]["need"]))
	ok("META-03", skins_ok and Meta.unlocked(""), "모양 해금 조건은 모두 있는 업적")
	ok("META-04", Meta.key("plain", 1) != Meta.key("plain", 3) and Meta.key("plain", 1, true) == "plain", "최고 기록은 맵·규칙마다 따로, 예전 규칙 기록은 옛 키로")

	ok("UI-01", main._ver_text().contains(str(ProjectSettings.get_setting("application/config/version"))), "구석 버전 표시 = project.godot 버전 (%s)" % main._ver_text())
	main.touch_ui = true
	var t: String = main._kh("새로고침 (Q)")
	var h: String = main._help_text()
	main.touch_ui = false
	ok("UI-02", not t.contains("(Q)") and h.contains("[조작 · 터치]"), "터치 화면은 키 안내를 빼고 터치용 도움말")

	# 폰 카드: 한 번 누르면 미리보기, 같은 카드를 한 번 더 누르면 고름 (마우스는 바로)
	_fresh(3)
	main.phase = main.Phase.CHOOSE
	main.offer = [{"type": "elem", "e": Elem.WATER, "lv": 1}, {"type": "elem", "e": Elem.FIRE, "lv": 1}]
	main._show_offer()
	main.touch_ui = true
	main._on_card_tap(main.offer[0], 0)
	var tap1: bool = main.phase == main.Phase.CHOOSE and main.tap_sel == 0 and main.hover_elem == Elem.WATER
	main._on_card_tap(main.offer[1], 1)
	var tap2: bool = main.phase == main.Phase.CHOOSE and main.tap_sel == 1
	main._on_card_tap(main.offer[1], 1)
	var tap3: bool = main.phase == main.Phase.PLACE and main.picked.get("e", -1) == Elem.FIRE
	main.touch_ui = false
	main.phase = main.Phase.CHOOSE
	main._show_offer()
	main._on_card_tap(main.offer[0], 0)
	var mouse1: bool = main.phase == main.Phase.PLACE
	ok("UI-14", tap1 and tap2 and tap3 and mouse1, "터치 카드: 한 번 누르면 미리보기·다른 카드 누르면 바꿈·한 번 더 누르면 고름, 마우스는 바로 고름")
	main.phase = main.Phase.CHOOSE

	# 그린 궤적 터치: 손을 떼면 [확정]을 기다리고, 누르면 넣는다 (마우스는 떼자마자)
	_fresh(3)
	var pt := _tower(main.center() + Vector2(-200, 0))
	main.touch_ui = true
	main._start_draw(pt, [0], false)
	main.draw_on = true
	main.draw_pts = PackedVector2Array([pt.position, pt.position + Vector2(60, 0), pt.position + Vector2(120, 0)])
	main.draw_len = 120.0
	var before: int = pt.paths.size()
	main._draw_release()
	var waiting: bool = main.draw_wait and main.phase == main.Phase.DRAW and pt.paths.size() == before
	main.draw_ok_btn.pressed.emit()
	var done: bool = not main.draw_wait and pt.paths.size() > before and main.phase != main.Phase.DRAW
	main.touch_ui = false
	ok("PATH-02", waiting and done, "그린 궤적 터치: 손을 떼면 길을 남겨 두고 [확정]을 누르면 넣음")

	# 전장 확대: 두 손가락 벌리기로 확대, 그동안 누르기는 게임에 안 넘어감, 다 떼면 풀림. [확대 풀기]로 1배
	_fresh(3)
	main.phase = main.Phase.CHOOSE
	var t0 := InputEventScreenTouch.new(); t0.index = 0; t0.pressed = true; t0.position = Vector2(600, 360)
	var t1 := InputEventScreenTouch.new(); t1.index = 1; t1.pressed = true; t1.position = Vector2(700, 360)
	main._zoom_input(t0)
	var lock1: bool = main._zoom_input(t1)
	var dr := InputEventScreenDrag.new(); dr.index = 1; dr.position = Vector2(800, 360)
	main._zoom_input(dr)
	var zin: bool = main.view_zoom > 1.5 and main.view_rect().size.x < main.get_viewport_rect().size.x
	t1.pressed = false; t0.pressed = false
	main._zoom_input(t1)
	var last: bool = main._zoom_input(t0)
	var unlocked: bool = not main.pinch_lock and last
	main._reset_zoom()
	ok("UI-18", lock1 and zin and unlocked and is_equal_approx(main.view_zoom, 1.0) and main.arena().size == Meta.FIELD, "두 손가락 벌리기 = 전장 확대(x%.1f), 확대 중 누르기는 게임에 안 넘어감, [확대 풀기] = 1배, 전장 크기 그대로" % main.view_zoom)

	# 글 대신 그림: 카드는 버튼 글 없이 그림 머리(속성 카드는 속성 그림·Lv 배지), 짝 속성 줄·숫자 특성은 그림 + 숫자,
	# 시작 화면·일시정지는 그림 버튼(이름은 말풍선), 오른쪽 설명 앞줄마다 그림
	_fresh(3)
	_tower(main.center() + Vector2(-200, 0))
	var ec: Button = main._card_button({"type": "elem", "e": Elem.WATER, "lv": 2}, 1)
	var em: Array = ec.get_meta("card")
	var has_els: bool = em[1].any(func(l): return l[0].has("els"))
	var pc: Button = main._card_button({"type": "trig", "id": "echo"}, 2)
	var big: Dictionary = main._perk_big("haste", main._perk_desc(main.PERKS[1]))
	var glyph_btns: bool = main.title_box.find_children("*", "Button", true, false).filter(func(b): return b.text == "" and b.tooltip_text in ["도감 (K)", "설정 (O)"]).size() == 2
	var pause_ok: bool = main.pause_box.get_child_count() >= 6 and main.pause_box.get_children().all(func(b): return b.text == "")
	ok("UI-19", ec.text == "" and em[0].get("e", -1) == Elem.WATER and em[0].get("lv", "") == "Lv2" and has_els and pc.text == "" and big.get("big", "") == "+12%" and big.get("i", "") == "rate" \
		and glyph_btns and pause_ok and main.legend_heads.size() == main.LEGEND_ICONS.size() and not main._pause_text().contains("Esc:"),
		"글 대신 그림: 카드 그림 머리·짝 속성 그림, 특성 그림+숫자, 시작 화면·일시정지 그림 버튼, 설명 앞줄 그림")
	ec.free()
	pc.free()

	# 시작 화면: 첫 화면은 큰 타일(일반 판·정원·멀티) + 그림 버튼 줄(PC는 종료), [일반 판] → 준비 화면(맵·규칙·모드·시작), 모양은 설정 창
	var home0: bool = main.home_box.visible and not main.prep_box.visible
	var tiles_ok: bool = main.home_box.is_ancestor_of(main.garden_btn) and main.home_box.is_ancestor_of(main.mp_btn) and not main.home_box.is_ancestor_of(main.map_label)
	main._set_prep(true)
	var prep1: bool = main.prep_box.visible and not main.home_box.visible and main.prep_box.is_ancestor_of(main.map_label) and main.prep_box.is_ancestor_of(main.new_btn) and main.prep_box.is_ancestor_of(main.modes_btn)
	main._set_prep(false)
	var skins_set: bool = main.settings_panel.is_ancestor_of(main.skin_label) and main.settings_panel.is_ancestor_of(main.core_label)
	var quit_btn: bool = main.home_box.find_children("*", "Button", true, false).any(func(b): return b.tooltip_text == "게임 종료") == OS.has_feature("pc")
	ok("UI-21", home0 and tiles_ok and prep1 and main.home_box.visible and skins_set and quit_btn, "첫 화면 %s·타일 %s, 준비 화면 %s, 모양은 설정 %s, 종료(PC만) %s" % [home0, tiles_ok, prep1, skins_set, quit_btn])

	# 카드 설명 세 단계: 기본 간소화(속성은 효과 이름만, 괄호 덧붙임 뺌) → [자세히] 전체 → 자세히 + 올리기 창(반응 설명까지)
	var was_d := Meta.card_detail
	Meta.card_detail = false
	var s0: Dictionary = main._card_content({"type": "elem", "e": Elem.WATER, "lv": 1}, 0)
	var m0: Dictionary = main._card_content({"type": "mod", "id": "multi"}, 0)
	var m1: Dictionary = main._card_content({"type": "mod", "id": "multi"}, 1)
	var full: Array = main._card_full({"type": "elem", "e": Elem.WATER, "lv": 1})
	var simple_ok: bool = s0["rows"][0].has("pair") and not str(m0["rows"][0]["t"]).contains("(") and str(m1["rows"][0]["t"]).contains("(")
	var full_ok: bool = full.any(func(l): return str(l[0]).begins_with("반응 ")) and full.size() > s0["rows"].size()
	main._set_card_detail(true)
	var on_ok: bool = Meta.card_detail and main.card_detail_btn.button_pressed
	main._set_card_detail(was_d)
	ok("UI-20", simple_ok and full_ok and on_ok, "카드 설명: 기본 간소화 · [자세히] 전체 · 자세히 + 올리기(터치는 한 번 누르기) 창에 반응 설명까지")

	# 웨이브 넘기기: 오브젝트가 있어야, 첫 판은 카드가 다 열린 뒤
	_fresh(3)
	var none: bool = main._can_skip()
	_tower(main.center() + Vector2(-200, 0))
	var some: bool = main._can_skip()
	main.tutor = true
	var tut: bool = main._can_skip()
	main.tutor = false
	ok("SKIP-01", not none and some and not tut, "웨이브 넘기기: 오브젝트가 있을 때만, 첫 판은 카드가 다 열린 뒤")
	main.phase = main.Phase.CHOOSE
	main.picks_left = 2
	Meta.skip_n = 3
	main._on_skip()
	ok("SKIP-02", main.skip_left == 3 and main.bank_picks.size() == 2, "넘기기: 이번 고르기를 쌓아 두고 n웨이브 진행 (남은 %d, 쌓인 고르기 %d)" % [main.skip_left, main.bank_picks.size()])
	main.skip_left = 0
	main.bank_picks = []
	_clear()

	# 피해 출처
	var tw := Tower.new()
	tw.credit(5.0, "rx:steam")
	tw.credit(2.0, "rx:steam")
	ok("DPS-01", is_equal_approx(tw.dealt, 7.0) and is_equal_approx(tw.src.get("rx:steam", 0.0), 7.0), "피해 출처: 출처별로 나눠 쌓음")
	tw.free()


# ---------- 멀티플레이 (연결 없이 확인할 수 있는 것) ----------

func _multiplayer() -> void:
	# 대결: 같은 씨앗이면 같은 웨이브. 씨앗 0이면 전역 난수 (혼자 하는 판 순서 그대로)
	var rolls := []
	for k in 2:
		_fresh(6)
		main.mp_seed = 4242
		randomize()  # 전역 난수가 달라도 같아야 한다
		main.lanes.clear()
		main._new_rest()
		var plan := [Array(main.lanes), main.wave_resist]
		main.phase = main.Phase.WAVE
		main.wave += 1
		main.lane_bag.clear()
		for i in main.lane_counts(main.wave).size():
			for j in main.lane_counts(main.wave)[i]:
				main.lane_bag.append(i)
		main._wshuffle(main.lane_bag)
		for i in 5:
			plan.append(main._roll_orb(main.wave))
		rolls.append(var_to_str(plan))
	main.mp_seed = 0
	seed(7)
	var a := randf()
	seed(7)
	var b: float = main.wf()
	ok("MP-03", rolls[0] == rolls[1] and is_equal_approx(a, b), "대결: 같은 씨앗이면 같은 방향·저항·구체, 씨앗 0이면 전역 난수")

	# 대결: 보낸 구체는 다음 웨이브에 더 나오고, 다 나와야 웨이브가 끝난다
	_fresh(3)
	main.mp_mode = "vs"
	main.mp_next_extra = 3
	main.phase = main.Phase.READY
	main._start_wave()
	var extra: int = main.mp_extra_left
	main.to_spawn = 0
	for i in 600:
		main._sim_step(1.0 / 30.0)
	ok("MP-04", extra == 3 and main.mp_next_extra == 0 and main.mp_extra_left == 0, "보낸 구체 %d개가 이번 웨이브에 나옴 (남은 %d)" % [extra, main.mp_extra_left])
	main.mp_mode = ""
	main.mp_extra_left = 0

	# 협동: 구체 수, 오브젝트 주인, 주고받는 상태
	_fresh(5)
	var solo: int = main.spawn_count(5)
	main.coop_orbs = 1.6
	var duo: int = main.spawn_count(5)
	main.coop_orbs = 1.0
	main.mp_mode = "coop"
	main.mp.my_id = 1
	var mine := _tower(main.center() + Vector2(-200, 0), Elem.FIRE, 2)
	var other := _tower(main.center() + Vector2(200, 0), Elem.WATER)
	other.owner_id = 2
	main.phase = main.Phase.CHOOSE
	main._begin_press(other, other.position)
	var blocked: bool = main.press_t == null
	ok("MP-06", duo == roundi(solo * 1.6) or abs(duo - solo * 1.6) <= 1.0, "협동: 2명이면 구체 x1.6 (%d → %d)" % [solo, duo])
	mine.dealt = 55.0
	var st: Dictionary = other.mp_state()
	st["nid"] = 200001
	var copy := Tower.new()
	copy.main = main
	copy.mp_apply(st)
	mine.mp_apply(mine.mp_state())
	ok("MP-07", mine.owner_id == 1 and mine.net_id == 100001 and blocked and main._my_towers() == [mine] and copy.elements == other.elements and copy.pattern == other.pattern and is_equal_approx(mine.dealt, 55.0) and mine.lv(Elem.FIRE) == 2,
		"협동: 내 오브젝트만 바꿈, 상태를 주고받아도 속성·공격방식 같고 피해 기록은 이 기기 것 (%s)" % str([mine.owner_id, mine.net_id, blocked, main._my_towers().size(), copy.elements, other.elements, mine.dealt, mine.lv(Elem.FIRE)]))
	copy.free()
	main.press_t = null

	# 멀티 판: 이어하기 저장·웨이브 넘기기 없음
	var had := FileAccess.file_exists(main.RUN_PATH)
	if had:
		DirAccess.remove_absolute(main.RUN_PATH)
	main.phase = main.Phase.CHOOSE
	main._save_run()
	ok("MP-08", not FileAccess.file_exists(main.RUN_PATH) and not main._can_skip(), "멀티 판은 이어하기 저장·웨이브 넘기기 없음")
	main.mp_mode = ""
	main.mp.my_id = 0
	main.mp_tw_n = 0
	_clear()


# ---------- 문서 대조 ----------

# ---------- 튜토리얼 ----------

func _tutorial() -> void:
	# TUT-01: 기기 파일에만 저장, 처음이면 need_first, 닫으면(건너뛰기 포함) 기본 항목까지 본 것으로
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PATH))
	Tutorial.load_file()
	var first := Tutorial.need_first()
	main._open_tut(Tutorial.FIRST, true)
	var showed: bool = main.tut.visible and main.tut.btn_close.text == "건너뛰기"
	main.tut.close()
	Tutorial.done = false
	Tutorial.seen = {}
	Tutorial.load_file()
	var after := not Tutorial.need_first() and Tutorial.FIRST.all(func(id): return Tutorial.seen.has(id))
	main._save_best()
	var best := ConfigFile.new()
	best.load(Meta.SAVE_PATH)
	var prog := JSON.stringify(Progress.build())
	ok("TUT-01", Tutorial.PATH == "user://device.cfg" and first and showed and after and not best.has_section("tutorial") and not prog.contains("tutorial"),
		"첫 진입 %s, 건너뛰기 %s, 닫은 뒤 다시 안 뜸 %s, best.cfg·계정 진행엔 없음" % [first, showed, after])
	# TUT-02: 항목 14개, id 겹침 없음, 장마다 그림 함수, 터치 글엔 키·클릭 말 없음, 모든 항목이 첫 진입이나 처음 나올 때로 뜸
	var ids := {}
	var bad := []
	for tp in Tutorial.TOPICS:
		ids[tp["id"]] = true
		if tp["pages"].is_empty():
			bad.append(tp["id"] + ":빈 항목")
		for pg in tp["pages"]:
			if not main.tut.has_method("_pic_" + pg["pic"]):
				bad.append(tp["id"] + ":그림 " + pg["pic"])
			var tt := Tutorial.page_text(pg, true)
			for w in ["클릭", "Shift", "Esc", "Alt", "휠", "Q:", "V:", "S:", "(Q)"]:
				if tt.contains(w):
					bad.append(tp["id"] + ":터치 글 " + w)
		if not (tp["id"] in Tutorial.FIRST or Tutorial.ON_EVENT.values().has(tp["id"])):
			bad.append(tp["id"] + ":뜨는 때 없음")
	for v in Tutorial.ON_EVENT.values():
		if not ids.has(v):
			bad.append("모르는 항목 " + v)
	ok("TUT-02", Tutorial.TOPICS.size() == 14 and ids.size() == 14 and bad.is_empty(), "항목 %d개, 문제 %s" % [ids.size(), str(bad)])
	# TUT-03: 처음 생긴 일이면 한 번만 줄에 넣고, 안내 끄기·멀티·이미 본 항목은 넣지 않음. 띄우면 본 것으로, 판을 멈췄으면 닫을 때 다시 진행
	Tutorial.seen = {}
	main.tut_queue.clear()
	Meta.guide_on = true
	main.mp_mode = ""
	main._tut_event("pat")
	main._tut_event("pat")
	main._tut_event("nothing")
	var once: bool = main.tut_queue == ["pat"]
	main._guide("boss", "보스 안내")
	var via_guide: bool = main.tut_queue.has("boss")
	Meta.guide_on = false
	main._tut_event("mod")
	Meta.guide_on = true
	main.mp_mode = "vs"
	main._tut_event("mod")
	main.mp_mode = ""
	Tutorial.seen["link"] = true
	main._tut_event("link")
	var skipped: bool = not main.tut_queue.has("mod") and not main.tut_queue.has("link")
	main.tut_queue.clear()
	main.tut_paused = true
	paused = true
	main._open_tut(["pat"])
	var marked := Tutorial.seen.has("pat")
	main.tut._next()
	main.tut._next()
	var resumed: bool = not main.tut.visible and not paused and not main.tut_paused
	paused = false
	ok("TUT-03", once and via_guide and skipped and marked and resumed, "한 번만 %s, _guide에서 %s, 끄기·멀티·본 것 빼기 %s, 본 것 표시 %s, 닫으면 판 진행 %s" % [once, via_guide, skipped, marked, resumed])
	# TUT-04: 시작 화면·일시정지의 [튜토리얼] 버튼, 목록 14개 + 전체 보기, ✓, 항목 → 카드 → 목록으로, 전체 보기 → 도움말
	var title_btn := false
	for b in main.title_box.find_children("*", "Button", true, false):
		if (b as Button).pressed.is_connected(main._open_tut_list):
			title_btn = true
	var pause_btn := false
	for b in main.pause_box.get_children():
		if (b as Button).pressed.is_connected(main._open_tut_list):
			pause_btn = true
	Tutorial.seen = {"goal": true}
	main._open_tut_list()
	var g: GridContainer = main.tut.grid
	var listed: bool = main.tut.mode == "list" and g.get_child_count() == 15 and (g.get_child(0) as Button).text.ends_with("✓") and not (g.get_child(1) as Button).text.ends_with("✓")
	(g.get_child(4) as Button).pressed.emit()
	var opened: bool = main.tut.mode == "pages" and main.tut.cur_topic()["id"] == Tutorial.TOPICS[4]["id"]
	for i in 5:
		main.tut._next()
	var back: bool = main.tut.visible and main.tut.mode == "list"
	(main.tut.grid.get_child(14) as Button).pressed.emit()
	var helped: bool = not main.tut.visible and main.help_label.visible
	main.help_label.visible = false
	ok("TUT-04", title_btn and pause_btn and listed and opened and back and helped, "시작 화면 %s, 일시정지 %s, 목록 %s, 항목 열기 %s, 목록으로 %s, 전체 보기 %s" % [title_btn, pause_btn, listed, opened, back, helped])


# ---------- 다음 패치 투표 ----------

func _vote() -> void:
	var v: Vote = main.vote_panel
	# 목록: 모든 탭 항목이 서버 키 모양(elem:fire 등)이고 겹치지 않음
	var keys := {}
	var bad := []
	for c in Vote.CATS:
		if c[0] == "run":
			continue
		for x in v._entries(c[0]):
			if not Vote._key_ok(x["key"]) or keys.has(x["key"]):
				bad.append(x["key"])
			keys[x["key"]] = true
	var has_all: bool = keys.has("elem:fire") and keys.has("pat:spray") and keys.has("mod:homing") and keys.has("perk:power") \
		and keys.keys().any(func(k): return k.begins_with("react:")) and keys.keys().any(func(k): return k.begins_with("trig:"))
	# 표 고르기: 회차마다 표 5장, 한 항목엔 방향 하나, 같은 방향 다시 누르면 취소, 개선엔 60자 의견
	v.take({"round": {"id": 3, "name": "시험"}, "max": 5, "eligible": true, "reason": "", "mine": [{"key": "elem:fire", "dir": "up", "note": ""}], "last": null})
	var r1: bool = v.can_vote and v.used() == 1 and v.picks["elem:fire"]["dir"] == "up"
	v.choose("elem:fire", "down")
	var r2: bool = v.used() == 1 and v.picks["elem:fire"]["dir"] == "down"
	v.choose("elem:fire", "down")
	var r3: bool = v.used() == 0
	for k in ["elem:ice", "pat:spray", "mod:homing", "perk:power", "trig:echo"]:
		v.choose(k, "fix" if k == "mod:homing" else "up")
	var full: bool = v.choose("elem:wood", "up") == "full" and v.used() == 5
	v.set_note("mod:homing", "  " + "가".repeat(80))
	v.set_note("elem:ice", "무시")
	var note_ok: bool = v.picks["mod:homing"]["note"].length() == Vote.NOTE_MAX and v.picks["elem:ice"]["note"] == ""
	var pl := v.payload()
	var pl_ok: bool = pl["round"] == 3 and pl["votes"].size() == 5
	# 자격이 없으면 못 넣음, 판 끝난 화면은 이번 판에 고른 것을 앞 탭으로
	v.take({"round": {"id": 3, "name": "시험"}, "max": 5, "eligible": false, "reason": "play", "mine": [], "min_wave": 5})
	var no_vote: bool = not v.can_vote and v.status.text.contains("5웨이브")
	main.run_log = [{"w": 0, "k": "card", "p": "elem:fire"}, {"w": 2, "k": "card", "p": ""}, {"w": 4, "k": "card", "p": "elem:fire"}, {"w": 5, "k": "perk", "p": "perk:power"}]
	var rk: Array = main._vote_run_keys()
	v.open(rk)
	var run_tab: bool = v.cat == "run" and v._entries("run").size() == 2
	v.visible = false
	v.dirty = false
	main.run_log = []
	# 투표 API가 없는 서버면 버튼이 없다 (헤드리스는 서버에 닿지 않음)
	var hidden: bool = not Net.vote_ok() and (main.vote_btn == null or not main.vote_btn.visible)
	ok("ONLINE-04", bad.is_empty() and has_all and r1 and r2 and r3 and full and note_ok and pl_ok and no_vote and run_tab and hidden,
		"다음 패치 투표: 항목 %d개 키 모양(틀림 %s), 표 5장·방향 하나·다시 누르면 취소·개선 의견 60자, 자격 없으면 못 넣음, 판 끝 화면은 이번 판 탭, 서버에 투표 없으면 버튼 숨김" % [keys.size(), str(bad)])


func _lint() -> void:
	var f := FileAccess.open("res://docs/features.md", FileAccess.READ)
	if f == null:
		ok("DOC", false, "docs/features.md를 못 읽음")
		return
	var re := RegEx.create_from_string("^\\| ([A-Z]+-\\d{2}) \\|.*\\| ([^|]+) \\|\\s*$")
	var doc := {}
	var dup := []
	for line in f.get_as_text().split("\n"):
		var mt := re.search(line)
		if mt:
			var id := mt.get_string(1)
			if doc.has(id):
				dup.append(id)
			doc[id] = mt.get_string(2)
	var unchecked := []
	for id in doc:
		if doc[id].contains("spec") and not seen.has(id):
			unchecked.append(id)
	var undocumented := []
	for id in seen:
		if not doc.has(id) or not doc[id].contains("spec"):
			undocumented.append(id)
	print(("ok   " if dup.is_empty() else "FAIL ") + "DOC id 겹침 없음 %s" % str(dup))
	print(("ok   " if unchecked.is_empty() else "FAIL ") + "DOC 문서의 spec 기능을 모두 확인 (빠짐 %s)" % str(unchecked))
	print(("ok   " if undocumented.is_empty() else "FAIL ") + "DOC 확인한 기능이 모두 문서에 spec으로 있음 (없음 %s)" % str(undocumented))
	fails += dup.size() + unchecked.size() + undocumented.size()
	print("DOC 기능 %d개 중 spec %d개" % [doc.size(), doc.values().filter(func(v): return v.contains("spec")).size()])
