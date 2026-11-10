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
	main.ley = []  # 기맥은 _ley_build()에서만
	Modes.set_on([])
	Meta.rules = 1
	Meta.map_id = "plain"
	main.run_flow_system._apply_rules()
	Rules.tune["map_on"] = 0.0  # 맵 규칙은 _maps()에서만 켠다 (다른 검사의 피해·카드 수치가 평원 규칙에 흔들리지 않게)
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
	main.waves_system._roll_lanes()


func _tower(p: Vector2, e := Elem.FIRE, lv := 1, d := Vector2.RIGHT) -> Tower:
	main.picked = {"type": "elem", "e": e, "lv": lv}
	main.interaction_system._place_tower(p, d)
	var t: Tower = main.towers.get_child(main.towers.get_child_count() - 1)
	t.eff = t.eff_now()
	return t


func _orb(p: Vector2, hp: float, kind := Orb.Kind.NORMAL, spd := 0.0) -> Orb:
	var o := Orb.new()
	o.main = main
	o.position = p
	o.target = main.viewport_system.center()
	o.from_a = (p - main.viewport_system.center()).angle()
	o.setup(kind, hp, spd)
	main.orbs.add_child(o)
	return o


func _move_cards() -> void:
	_fresh(5)
	var c: Vector2 = main.viewport_system.center()
	var a := _tower(c + Vector2(-250, 0), Elem.FIRE, 1, Vector2.RIGHT)
	var b := _tower(c + Vector2(-250, 150), Elem.ICE, 1)
	a.add_trig("patrol")
	ok("TRIG-10", not a.can_take({"type": "trig", "id": "orbit"}) and a.can_take({"type": "trig", "id": "patrol"}), "움직임은 한 종류만")
	b.add_trig("orbit")
	var a0 := a.position
	var b0 := b.position
	a.move_begin()
	b.move_begin()
	var max_a := 0.0
	var max_b := 0.0
	for i in 120:
		a.attack(1.0 / 60.0, [])
		b.attack(1.0 / 60.0, [])
		max_a = maxf(max_a, absf(a.position.y - a0.y))
		max_b = maxf(max_b, b.position.distance_to(b0))
	ok("TRIG-10", max_a > 60.0 and max_a <= 91.0 and absf(a.position.x - a0.x) < 1.0, "순찰: 수직 좌우로 90까지 (%.0f)" % max_a)
	ok("TRIG-10", max_b > 20.0 and absf(b.position.distance_to(a0) - b0.distance_to(a0)) < 1.0 or absf(b.position.distance_to(a0) - 150.0) < 5.0, "공전: 가장 가까운 오브젝트 둘레 (%.0f)" % max_b)
	var sv := a.to_save()
	ok("TRIG-10", sv["pos"] == a0, "웨이브 중 이어하기는 제자리 저장")
	a.move_end()
	b.move_end()
	ok("TRIG-10", a.position == a0 and b.position == b0 and a.home == Vector2.INF, "웨이브 끝 제자리")
	var ch := _tower(c + Vector2(250, -150), Elem.FIRE, 1)
	ch.add_trig("chase")
	var o := _orb(ch.position + Vector2(300, 0), 1000.0)
	ch.move_begin()
	ch.reflex_target = o
	var p0 := ch.position
	for i in 120:
		ch._move_step(1.0 / 60.0)
	ok("TRIG-10", ch.position.distance_to(p0) > 100.0 and ch.position.distance_to(p0) <= 110.5, "추적: 겨눈 구체 쪽으로 110까지 (%.0f)" % ch.position.distance_to(p0))
	_clear()


func _initialize():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"):
		print("FAIL 실제 게임 저장 폴더를 쓰게 됨: tools/run.sh spec 으로 돌리세요")
		quit(1)
		return
	seed(1)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.progression_system._hide_title()
	_cards()
	_elements()
	_patterns()
	await _attacks()
	await _multi_center()
	_reflex()
	_reflex_review_regressions()
	_move_cards()
	_mods_links()
	await _mods_area()
	_waves()
	_wave_start_guard()
	_orbs_cc()
	_score_core()
	_perks()
	_rules_modes()
	_vary()
	_maps()
	_save_load()
	await _result_detail()
	_meta_misc()
	_carry_cards()
	_side()
	_side_mix()
	_multiplayer()
	_tutorial()
	_vote()
	_ugc()
	_board_filters()
	_attack_preview()
	_combination_inspector()
	_lint()
	print("SPEC %s (실패 %d, 확인한 기능 %d개)" % ["통과" if fails == 0 else "실패", fails, seen.size()])
	quit(1 if fails > 0 else 0)


# ---------- 카드·선택지 ----------

func _cards() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	_tower(c + Vector2(-200, 0))
	var bad3 := 0
	var no_elem := 0
	var dup := 0
	for i in 200:
		main.cards_system._make_choices()
		if main.offer.size() != 3:
			bad3 += 1
		if not main.offer.any(func(cd): return cd["type"] == "elem"):
			no_elem += 1
		var keys := {}
		for cd in main.offer:
			keys[main.cards_system._card_key(cd)] = true
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
		main.cards_system._make_choices()
		for cd in main.offer:
			if cd["type"] == "pat" and cd["id"] != "spray":
				wrong += 1
	ok("CARD-02", wrong == 0, "넣을 곳이 없는 공격방식 카드는 선택지에 없음 (어긋남 %d)" % wrong)

	# 오브젝트가 없으면 속성 카드만
	_clear()
	var only_elem := true
	for i in 50:
		main.cards_system._make_choices()
		only_elem = only_elem and main.offer.all(func(cd): return cd["type"] == "elem")
	ok("CARD-04", only_elem, "오브젝트가 없으면 속성 카드만")
	_fresh(30)
	_tower(main.viewport_system.center() + Vector2(120, 0))
	var valid_links := true
	for i in 1000:
		var rolled: Dictionary = main.cards_system._roll_card()
		if rolled.get("type") == "link":
			valid_links = valid_links and Pat.LINKS.has(rolled.get("id"))
	ok("LINK-02", valid_links, "오브젝트 하나에서도 삭제된 연계 카드를 뽑지 않음")


	# 첫 판: 종류가 웨이브마다 열림
	main.tutor = true
	var opened := []
	for w in [0, 2, 3, 4, 5]:
		main.wave = w
		opened.append([main.cards_system._card_open("pat"), main.cards_system._card_open("mod"), main.cards_system._card_open("trig"), main.cards_system._card_open("link")])
	main.tutor = false
	ok("CARD-05", opened == [[false, false, false, false], [true, false, false, false], [true, true, false, false], [true, true, true, false], [true, true, true, true]],
		"첫 판 카드 종류가 공격방식 3·강화 4·발동 5·연계 6웨이브에 열림 %s" % str(opened))

	# 새로고침
	_fresh()
	_tower(c + Vector2(-200, 0))
	main.phase = main.Phase.CHOOSE
	main.rerolls_left = 1
	main.cards_system._on_reroll()
	var after1: int = main.rerolls_left
	main.cards_system._on_reroll()
	ok("CARD-06", after1 == 0 and main.rerolls_left == 0 and main.offer.size() == 3, "새로고침은 남은 횟수만큼, 다 쓰면 그대로")

	# 쉬는 시간마다 고르는 수: 처음 두 번 2장, 그 뒤 1장
	main.wave = 0
	main.run_flow_system._new_rest()
	var p0: int = main.picks_left
	main.wave = 6
	main.run_flow_system._new_rest()
	ok("CARD-07", p0 == 2 and main.picks_left == 1 and Rules.picks == 1, "고르는 수: 첫 쉬는 시간 %d, 그 뒤 %d (규칙 %d)" % [p0, main.picks_left, Rules.picks])

	# 속성 Lv2 확률: 20% + 웨이브마다 2%, 최대 50%, 행운 +20%
	main.wave = 0
	var a0: float = main.perks_system._lv2_chance()
	main.wave = 40
	var a40: float = main.perks_system._lv2_chance()
	main.perks = {"luck": 1}
	var al: float = main.perks_system._lv2_chance()
	main.perks = {}
	ok("CARD-08", is_equal_approx(a0, 0.2) and is_equal_approx(a40, 0.5) and is_equal_approx(al, 0.7), "속성 Lv2 확률 %.2f → %.2f, 행운 %.2f" % [a0, a40, al])


# ---------- 속성 ----------

func _elements() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	var t := _tower(c + Vector2(-200, 0), Elem.WATER, 2)
	ok("ELEM-01", t.pattern == "shot" and t.elements == {Elem.WATER: 2} and t.plv == 1, "빈 곳에 속성 카드 → 직선탄 + 그 속성 (%s)" % t.title())

	t.add(Elem.FIRE, 1)
	t.add(Elem.ICE, 1)
	var fourth := t.can_take({"type": "elem", "e": Elem.WOOD, "lv": 1})
	var same := t.can_take({"type": "elem", "e": Elem.FIRE, "lv": 1})
	var t5 := _tower(c + Vector2(-200, 150), Elem.FIRE, 4)
	t5.add(Elem.FIRE, 3)
	var cap_ok := t5.lv(Elem.FIRE) == 5 and not t5.can_take({"type": "elem", "e": Elem.FIRE, "lv": 1}) and "Lv5" in t5.refuse_text({"type": "elem", "e": Elem.FIRE, "lv": 1})
	t5.queue_free()
	ok("ELEM-02", not fourth and same and cap_ok, "랭크: 속성 3종까지, 같은 속성은 Lv5까지 (Lv%d, 더 넣기 막음 %s)" % [5, cap_ok])
	ok("ELEM-03", is_equal_approx(t.tax(), 1.0 + Rules.tax_step * 2) and is_equal_approx(Rules.tax_step, 0.15), "쌓기 대가: 종류마다 공격 속도 ÷(1+0.15×(종류-1)) (%.2f)" % t.tax())

	Meta.rules = 3
	main.run_flow_system._apply_rules()
	ok("ELEM-04", t.can_take({"type": "elem", "e": Elem.WOOD, "lv": 1}) and is_equal_approx(Rules.tax_step, 0.25), "도파민 모드: 속성 종류 제한 없음, 대가 0.25")
	Meta.rules = 1
	main.run_flow_system._apply_rules()

	# 두 속성 짝 136개: 고정 반응이 아니라 특징 이름표 (도감·업적용)
	var missing := []
	var ids := {}
	for i in Elem.ALL.size():
		for j in range(i + 1, Elem.ALL.size()):
			var rs := Elem.reactions_with({Elem.ALL[i]: 1, Elem.ALL[j]: 1})
			if rs.is_empty():
				missing.append("%s+%s" % [Elem.NAMES[Elem.ALL[i]], Elem.NAMES[Elem.ALL[j]]])
			for r in rs:
				ids[r["id"]] = true
	var traits_ok := Elem.ALL.all(func(e): return Elem.TRAIT.has(e) and Elem.trait_name(e) != "")
	ok("ELEM-05", missing.is_empty() and ids.size() == 136 and Elem.REACTIONS.size() == 136 and traits_ok, "속성 17종 모두 특징이 있고, 두 속성 짝 136개 모두 도감 이름이 있음 (빠짐 %s, 짝 %d)" % [str(missing), ids.size()])

	t.eff = t.eff_now()
	var fresh := Elem.new_reactions({Elem.FIRE: 1}, Elem.WOOD)
	ok("ELEM-06", fresh.size() == 1 and t.reactions().size() == 3, "속성을 더해 새 짝이 생기면 알림·도감, 3종이면 짝 3개")

	var no_rider := Elem.ALL.filter(func(e): return Elem.rider(e).is_empty())
	ok("ELEM-07", no_rider.is_empty() and Elem.ALL.size() == 17, "속성 17종 모두 부가효과 설명이 있음")
	_elem_lv5()
	_no_fixed_zone()
	_share()


## 속성 Lv5 값 (2026-11-01): 금속은 맞힌 피해 +8%/레벨, 어둠 약화는 +20% + 4%/레벨, 물 감속은 0.85 - 0.03/레벨
func _elem_lv5() -> void:
	_clear()
	var c: Vector2 = main.viewport_system.center()
	var mt := _tower(c + Vector2(-200, 0), Elem.METAL, 5)
	var hc := mt.hit_calc()
	var metal_ok := is_equal_approx(hc["metal"], hc["one"] * 0.4)
	var dk := _tower(c + Vector2(-200, 100), Elem.DARK, 5)
	var o := _orb(c + Vector2(-100, 0), 1e6)
	dk.hit(o, 1.0)
	var dark_ok := is_equal_approx(o.vuln_k, 0.4)
	var wt := _tower(c + Vector2(-200, -100), Elem.WATER, 5)
	var o2 := _orb(c + Vector2(-100, 60), 1e6)
	wt.hit(o2, 1.0)
	var water_ok := absf(o2.slow_factor - 0.70) < 0.06
	var vk := o.vuln_k
	var sf := o2.slow_factor
	_clear()
	ok("ELEM-11", metal_ok and dark_ok and water_ok,
		"Lv5: 금속 맞힌 피해 +40%% (%s), 어둠 약화 +40%% (%.2f), 물 감속 0.70 (%.2f)" % [metal_ok, vk, sf])


## 고정 거리 장판 금지 (2026-11-01, 특징 공유 2026-11-03): 모든 공격방식이 만드는 장판 종류는 허용 목록뿐,
## 물길(물 흐름)은 날아가는 공격이 지나간 길에만 (계속 공격하는 형태는 없음).
const ZONE_OK := ["trail", "vortex", "rock"]
const CONT_PATS := ["spray", "stream", "laser", "sonic", "clock"]


func _no_fixed_zone() -> void:
	_fresh()
	Meta.rules = 3  # 속성 종류 제한 없음
	main.run_flow_system._apply_rules()
	var c: Vector2 = main.viewport_system.center()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.to_spawn = 0
	var bad := []
	for pat in Pat.PATTERN_IDS:
		_clear()
		var pt := _tower(c + Vector2(-60, 0), Elem.WATER, 3, Vector2.LEFT)
		for e in [Elem.FIRE, Elem.POISON, Elem.ICE, Elem.BLOOD]:
			pt.add(e, 3)
		if pat != "shot":
			pt.set_pattern(pat)
		pt.eff = pt.eff_now()
		_orb(c + Vector2(-260, 0), 99999.0, Orb.Kind.NORMAL, 30.0)
		_orb(c + Vector2(-330, 30), 99999.0, Orb.Kind.NORMAL, 30.0)
		var kinds := {}
		for i in 180:
			main.combat_system._sim_step(1.0 / 60.0)
			for z in main.zones.get_children():
				kinds[z.kind] = true
		for k in kinds:
			var allowed: bool = k in ZONE_OK or k in Zone.ORB_PATH or (k in Tower.FORM_ZONES and pat not in CONT_PATS)
			if not allowed:
				bad.append("%s:%s" % [pat, k])
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	Meta.rules = 1
	main.run_flow_system._apply_rules()
	ok("ELEM-10", bad.is_empty(), "고정 거리 장판 없음: 장판 종류는 지나간 자리·블랙홀·벽·물길·핏자국뿐, 물길은 날아가는 공격에만, 핏자국은 구체가 지나간 길에만 (어긋남 %s)" % str(bad))


## 특징 공유 (2026-11-03): 특징이 같은 오브젝트의 다른 속성 효과를 실어 나른다. 실어 나른 효과는 특징을 다시 타지 않는다.
func _share() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	var _grid := func():
		main.combat_system.targets = main.orbs.get_children()
		main.combat_system._build_grid()
	# 세기: Lv1 60% · Lv2 80% · Lv3 이상 100% x 속성별 차등(피해 특징은 낮게)
	var lt := _tower(c + Vector2(-300, -200), Elem.FIRE, 1)
	var k1 := Share.k(lt, Elem.FIRE)
	lt.add(Elem.FIRE, 4)
	lt.eff = lt.eff_now()
	var k5 := Share.k(lt, Elem.FIRE)
	var kw := Share.k(_tower(c + Vector2(-300, 200), Elem.WIND, 3), Elem.WIND) / Rules.share_mul
	var low: bool = Rules.SHARE["fire"] < 1.0 and Rules.SHARE["electric"] < 1.0 and Rules.SHARE["metal"] < 1.0
	ok("SHR-01", is_equal_approx(k1, 0.6 * Rules.SHARE["fire"] * Rules.share_mul) and is_equal_approx(k5, Rules.SHARE["fire"] * Rules.share_mul) and is_equal_approx(kw, 1.0) and low,
		"특징 세기 Lv1 60%%·Lv3+ 100%% x 속성 차등 (불 %.2f→%.2f, 바람 %.2f, 피해 특징 낮음 %s)" % [k1, k5, kw, low])
	_clear()
	# 전기 튐: 불+전기 → 튄 전류가 화상도 옮김, 옮긴 화상은 타오름을 다시 타지 않음
	var et := _tower(c + Vector2(-200, 0), Elem.ELECTRIC, 3)
	et.add(Elem.FIRE, 1)
	et.eff = et.eff_now()
	var a1 := _orb(c + Vector2(0, 0), 1e6)
	var a2 := _orb(c + Vector2(40, 0), 1e6)
	_grid.call()
	main.spawning_system.arc(a1, 1.0, et)
	var arc_ok: bool = a2.burn_t > 0.0 and a2.burn_rx
	ok("SHR-02", arc_ok, "전기 튐: 튄 전류가 같은 오브젝트의 화상도 옮김, 옮긴 효과는 1세대만 (화상 %.1f초, 표시 %s)" % [a2.burn_t, a2.burn_rx])
	# 1세대: 옮긴 화상은 다시 번지지 않음
	var a3 := _orb(c + Vector2(62, 0), 1e6)
	_grid.call()
	Share.spread(a2)
	ok("SHR-03", a3.burn_t <= 0.0, "실어 나른 효과는 특징을 다시 타지 않음 (끝없는 연쇄 없음)")
	_clear()
	# 독 전염: 독+얼음 → 중독된 구체가 죽으면 둘레에 냉기
	var pt := _tower(c + Vector2(-200, 0), Elem.POISON, 3)
	pt.add(Elem.ICE, 1)
	pt.eff = pt.eff_now()
	var p1 := _orb(c, 1e6)
	var p2 := _orb(c + Vector2(40, 0), 1e6)
	_grid.call()
	pt.hit(p1, 1.0)
	Share.contagion(p1)
	ok("SHR-04", p2.chill > 0.0 and p2.poison_t > 0.0, "독 전염: 중독된 구체가 죽으면 둘레에 독·냉기 (냉기 %.2f)" % p2.chill)
	_clear()
	# 땅 다짐: 자리(불 번짐)에 닿은 구체가 확률로 묶임, 자리가 없으면 맞은 구체가
	var gt := _tower(c + Vector2(-200, 0), Elem.EARTH, 3)
	gt.add(Elem.FIRE, 1)
	gt.eff = gt.eff_now()
	var solo := _tower(c + Vector2(-200, 150), Elem.EARTH, 3)
	var b1 := _orb(c, 1e6)
	var b2 := _orb(c + Vector2(0, 150), 1e6)
	_grid.call()
	var ech := Share.EARTH_CH
	Share.EARTH_CH = 100.0
	Share.carry(gt, b1, 0.3, "share:fire", c + Vector2(-30, 0), 0.3)
	b2.root_immune = 0.0
	Share.on_hit(solo, b2, false)
	Share.EARTH_CH = ech
	ok("SHR-05", b1.root_timer > 0.0 and b2.root_timer > 0.0, "땅 다짐: 자리에 닿은 구체·자리가 없으면 맞은 구체가 확률로 묶임 (%.2f, %.2f)" % [b1.root_timer, b2.root_timer])
	_clear()
	# 시간 되풀이: 0.8초 뒤 같은 구체에 효과 한 번 더
	var tt := _tower(c + Vector2(-200, 0), Elem.TIME, 3)
	tt.add(Elem.FIRE, 1)
	tt.eff = tt.eff_now()
	var r1 := _orb(c, 1e6)
	_grid.call()
	tt.hit(r1, 1.0)
	r1.burn_t = 0.0
	tt._share_tick(0.5)
	var early: bool = r1.burn_t > 0.0
	tt._share_tick(0.4)
	ok("SHR-06", not early and r1.burn_t > 0.0, "시간 되풀이: 0.8초 뒤 효과 한 번 더 (먼저 %s, 뒤 %.1f)" % [early, r1.burn_t])
	var gone := _orb(c + Vector2(100, 0), 1e6)
	tt.hit(gone, 1.0)
	gone.free()
	tt._share_tick(1.0)
	ok("SHR-06", tt.later.is_empty(), "되풀이 전 대상이 사라지면 오류 없이 예약을 비움")
	_clear()
	# 금속 응축: 효과 수만큼 추가 피해 (피해 출처 share:metal)
	var mt := _tower(c + Vector2(-200, 0), Elem.METAL, 3)
	mt.add(Elem.FIRE, 1)
	mt.add(Elem.POISON, 1)
	mt.eff = mt.eff_now()
	var m1 := _orb(c, 1e6)
	_grid.call()
	mt.hit(m1, 1.0)
	ok("SHR-07", mt.src.get("share:metal", 0.0) > 0.0, "금속 응축: 효과를 걸 때 효과 수만큼 추가 피해 (%.2f)" % mt.src.get("share:metal", 0.0))
	_clear()
	# 바람 넓힘·얼음 오래감
	var wt := _tower(c + Vector2(-200, 0), Elem.WIND, 3)
	wt.add(Elem.ICE, 3)
	wt.eff = wt.eff_now()
	ok("SHR-08", is_equal_approx(Share.wide(wt), 1.0 + Share.WIND_R * Share.k(wt, Elem.WIND)) and is_equal_approx(Share.dur(wt), 1.0 + Share.ICE_T * Share.k(wt, Elem.ICE)) and Share.wide(wt) > 1.0 and Elem.trait_name(Elem.ICE) == "지속 시간 연장" and "1.5배" in Elem.TRAIT[Elem.ICE], "바람 넓힘 범위 +40%%, 얼음 오래감 지속 x1.5 (특징 세기 곱, %.2f, %.2f)" % [Share.wide(wt), Share.dur(wt)])
	_clear()
	# 빛 꿰뚫음: 치명타 구체 뒤 일직선 구체에 효과
	var vt := _tower(c + Vector2(-200, 0), Elem.LIGHT, 3)
	vt.add(Elem.FIRE, 1)
	vt.eff = vt.eff_now()
	var v1 := _orb(c, 1e6)
	var v2 := _orb(c + Vector2(80, 0), 1e6)
	_grid.call()
	Share.pierce(vt, v1)
	ok("SHR-09", v2.burn_t > 0.0 and v1.burn_t <= 0.0, "빛 꿰뚫음: 치명타가 난 구체 뒤 일직선에 효과 (뒤 화상 %.1f)" % v2.burn_t)
	_clear()
	# 어둠 끌어당김: 약화된 채 죽으면 둘레를 끌고 효과
	var dt := _tower(c + Vector2(-200, 0), Elem.DARK, 3)
	dt.add(Elem.FIRE, 1)
	dt.eff = dt.eff_now()
	var d1 := _orb(c, 1e6)
	var d2 := _orb(c + Vector2(60, 0), 1e6)
	_grid.call()
	dt.hit(d1, 1.0)
	var before := d2.position
	Share.pull(d1)
	ok("SHR-10", d2.position.x < before.x and d2.burn_t > 0.0, "어둠 끌어당김: 약화된 구체가 죽으면 둘레를 끌고 효과 (끌림 %.1f)" % (before.x - d2.position.x))
	_clear()
	# 물 흐름: 날아가는 공격의 길 물길, 밟은 구체에 효과
	var ft := _tower(c + Vector2(-200, 0), Elem.WATER, 3)
	ft.add(Elem.FIRE, 1)
	ft.eff = ft.eff_now()
	var f1 := _orb(c, 1e6)
	_grid.call()
	ft.form_path(c)
	var rill: Zone = null
	for z in main.zones.get_children():
		if z.kind == "rill":
			rill = z
	if rill:
		rill.affect([f1], 0.1)
	ok("SHR-11", rill != null and f1.burn_t > 0.0, "물 흐름: 지나간 길 물길을 밟은 구체에 효과 (물길 %s, 화상 %.1f)" % [rill != null, f1.burn_t])
	_clear()
	# 특징만 있고 실어 나를 효과가 없으면 아무 일도 없음 (바람+빛)
	var nt := _tower(c + Vector2(-200, 0), Elem.LIGHT, 3)
	nt.add(Elem.WIND, 1)
	nt.eff = nt.eff_now()
	var none := not Share.has_carry(nt)
	nt.add(Elem.FIRE, 1)
	nt.eff = nt.eff_now()
	ok("SHR-12", none and Share.has_carry(nt), "바람·빛·별 효과는 오브젝트·맞힌 순간에만 걸려 실어 나르지 않음")
	_clear()
	_affinity(c)
	_real(c)
	_clear()
	_new_elems(c)


## 상성 (꼬리표, 2026-11-04)
func _affinity(c: Vector2) -> void:
	var _grid := func():
		main.combat_system.targets = main.orbs.get_children()
		main.combat_system._build_grid()
	var ns := 0
	var nw := 0
	for i in Elem.ALL.size():
		for j in range(i + 1, Elem.ALL.size()):
			var r := Elem.aff_of(Elem.ALL[i], Elem.ALL[j])
			ns += 1 if r["strong"] else 0
			nw += 1 if r["weak"] else 0
	var tags_ok := true
	for e in Elem.ALL:
		tags_ok = tags_ok and Elem.TAGS.has(e) and Elem.TAGS[e].size() in [1, 2]
	ok("AFF-01", tags_ok and ns == 26 and nw == 15 and Elem.aff_of(Elem.WATER, Elem.ELECTRIC)["strong"] and Elem.aff_of(Elem.FIRE, Elem.WATER)["weak"]
		and Elem.aff_of(Elem.FIRE, Elem.ELECTRIC)["ids"].is_empty(), "꼬리표 규칙으로 136짝 분류: 강 %d·약 %d (물+전기 강, 불+물 약, 불+전기 보통)" % [ns, nw])
	# 강: 특징 세기 x AFF_CARRY, 효과 세기 x AFF_EFF
	var st := _tower(c + Vector2(-200, 0), Elem.WATER, 3)
	st.add(Elem.ELECTRIC, 1)
	st.eff = st.eff_now()
	var base: float = Share.LV_K[1] * Rules.share_mul * Rules.share_k.get(Elem.ELECTRIC, 1.0)
	ok("AFF-02", is_equal_approx(Share.k(st, Elem.ELECTRIC), base * Share.AFF_CARRY) and is_equal_approx(Share.am(st, Elem.WATER), Share.AFF_EFF),
		"강상성: 특징 세기 x%.1f, 효과 세기 x%.1f" % [Share.AFF_CARRY, Share.AFF_EFF])
	# 감전: 튀는 거리 +40%, 튄 구체 멈칫
	var e1 := _orb(c, 1e6)
	var e2 := _orb(c + Vector2(115, 0), 1e6, Orb.Kind.NORMAL, 50.0)
	_grid.call()
	main.spawning_system.arc(e1, 10.0, st)
	ok("AFF-03", e2.hp < 1e6 and e2.stagger_t > 0.0, "감전: 전기가 115 떨어진 구체까지 튀고 멈칫 (%.0f, 멈칫 %.2f)" % [1e6 - e2.hp, e2.stagger_t])
	_clear()
	# 증기: 화상 절반, 둘레 구체도 느려짐
	var vt := _tower(c + Vector2(-200, 0), Elem.FIRE, 1)
	vt.add(Elem.WATER, 1)
	vt.eff = vt.eff_now()
	var s1 := _orb(c, 1e6)
	var s2 := _orb(c + Vector2(40, 0), 1e6)
	_grid.call()
	vt.hit(s1, 1.0)
	ok("AFF-04", is_equal_approx(Share.am(vt, Elem.FIRE), Share.AFF_WEAK) and s2.slow_timer > 0.0 and s2.slow_factor < 1.0,
		"증기: 화상 x%.1f, 대신 둘레 구체도 느려짐 (%.2f)" % [Share.am(vt, Elem.FIRE), s2.slow_factor])
	_clear()
	# 온도 충격: 냉기가 쌓인 구체를 불이 맞히면 냉기를 터뜨려 피해
	var tt := _tower(c + Vector2(-200, 0), Elem.FIRE, 1)
	tt.add(Elem.ICE, 1)
	tt.eff = tt.eff_now()
	var t1 := _orb(c, 1e6, Orb.Kind.NORMAL, 50.0)
	_grid.call()
	t1.chill = 2.0
	tt.hit(t1, 1.0)
	ok("AFF-05", tt.src.get("aff:thermo", 0.0) > 0.0 and t1.chill < 1.0, "온도 충격: 냉기를 터뜨려 피해 (%.1f, 남은 냉기 %.2f)" % [tt.src.get("aff:thermo", 0.0), t1.chill])
	_clear()
	# 일식: 치명타 확률 절반, 치명타가 나면 약화를 2배 시간
	var lt := _tower(c + Vector2(-200, 0), Elem.LIGHT, 1)
	lt.add(Elem.DARK, 1)
	lt.eff = lt.eff_now()
	var l1 := _orb(c, 1e6)
	_grid.call()
	Share.aff_hit(lt, l1, 1.0, true, 0.0)
	ok("AFF-06", is_equal_approx(Share.am(lt, Elem.LIGHT), Share.AFF_WEAK) and l1.vuln_t > Rules.dark_t * 1.5, "일식: 치명타 x%.1f, 치명타 때 약화 %.1f초" % [Share.am(lt, Elem.LIGHT), l1.vuln_t])
	_clear()
	# 접지: 전기가 튀지 않고 기절 확률 +20%
	var gt := _tower(c + Vector2(-200, 0), Elem.EARTH, 1)
	gt.add(Elem.ELECTRIC, 1)
	gt.eff = gt.eff_now()
	ok("AFF-07", Share.am(gt, Elem.ELECTRIC) == 0.0 and is_equal_approx(Share.root_ch(gt, 1), minf(Rules.earth_ch, Rules.earth_max) + Share.GROUND_CH),
		"접지: 전기 튐 없음, 기절 확률 %.2f" % Share.root_ch(gt, 1))
	_clear()
	# 시듦·녹: 중독된 구체가 느려짐 / 받는 피해 +
	var wt := _tower(c + Vector2(-200, 0), Elem.POISON, 1)
	wt.add(Elem.WOOD, 1)
	wt.eff = wt.eff_now()
	var rt := _tower(c + Vector2(-200, 150), Elem.POISON, 1)
	rt.add(Elem.METAL, 1)
	rt.eff = rt.eff_now()
	var w1 := _orb(c, 1e6)
	var w2 := _orb(c + Vector2(0, 200), 1e6)
	_grid.call()
	wt.hit(w1, 1.0)
	rt.hit(w2, 1.0)
	ok("AFF-08", w1.slow_factor <= Share.WITHER_SLOW + 0.001 and w2.vuln_t > 0.0 and w2.vuln_k >= Share.RUST - 0.001,
		"시듦: 중독된 구체 감속 %.2f · 녹: 받는 피해 +%.2f" % [w1.slow_factor, w2.vuln_k])
	_clear()
	# 잔상: 시간 되풀이 2번
	var at := _tower(c + Vector2(-200, 0), Elem.TIME, 1)
	at.add(Elem.DARK, 1)
	at.eff = at.eff_now()
	var a1 := _orb(c, 1e6)
	_grid.call()
	at.hit(a1, 1.0)
	ok("AFF-09", at.later.size() == Share.AFTER_N and Elem.aff_label(Elem.WATER, Elem.WOOD) == "성장 촉진(강)"
		and "+30%에서 +50%" in Elem.aff_text(Elem.WATER, Elem.WOOD), "잔상: 시간 되풀이 %d번" % at.later.size())
	_clear()
	# 제어 회복: 물길은 늘 감속, 묻어둠이 터지면 묶음, 응축은 멈칫, 얼음 오래감은 빙결도 길게
	var ft := _tower(c + Vector2(-200, 0), Elem.WATER, 1)
	var f1 := _orb(c, 1e6)
	var mt := _tower(c + Vector2(-200, 150), Elem.METAL, 3)
	mt.add(Elem.FIRE, 1)
	mt.eff = mt.eff_now()
	var m1 := _orb(c + Vector2(0, 200), 1e6, Orb.Kind.NORMAL, 50.0)
	var b1 := _orb(c + Vector2(0, -200), 1e6)
	_grid.call()
	ft.form_path(c)
	var rill: Zone = null
	for z in main.zones.get_children():
		if z.kind == "rill":
			rill = z
	if rill:
		rill.affect([f1], 0.1)
	var st0 := m1.stagger_t
	Share.condense(mt, m1, 2, 1.0)
	b1.root_timer = 0.1
	var fz := _orb(c + Vector2(200, 200), 1e6)
	fz.add_chill(3.0, 1.5)
	ok("AFF-10", rill != null and f1.slow_factor <= Share.RILL_SLOW + 0.001 and m1.stagger_t > st0 and b1.root_timer > 0.0 and fz.root_timer > 1.0,
		"특징 제어: 물길 감속 %.2f · 응축 멈칫 · (다짐은 SHR-05) %.2f · 빙결 %.2f초" % [f1.slow_factor if rill else 1.0, b1.root_timer, fz.root_timer])
	_clear()
	# 화면 글: 짝 이름표에 상성, 오브젝트 상성 줄
	var shock: Dictionary = Elem.reaction_of(Elem.WATER, Elem.ELECTRIC)
	ok("AFF-11", shock.get("aff", "") == "strong" and Elem.aff_label(Elem.WATER, Elem.ELECTRIC) == "감전(강)" and Elem.aff_text(Elem.FIRE, Elem.WATER).begins_with("상성 증기(약)")
		and main.src_name("aff:thermo") == "상성 온도 충격", "도감·정보창 상성 글 (%s)" % Elem.aff_label(Elem.WATER, Elem.ELECTRIC))


## 실제 연상 개편 (2026-11-04): 나르는 특징(자리) · 바꾸는 특징 · 휘감기 · 밀쳐냄 · 불 번짐 · 이름 있는 자리
func _real(c: Vector2) -> void:
	var _grid := func():
		main.combat_system.targets = main.orbs.get_children()
		main.combat_system._build_grid()
	var all_e: Array = Share.SITE_E + Share.MOD_E
	var split_ok: bool = Share.SITE_E.size() == 11 and Share.MOD_E.size() == 6 and Elem.ALL.all(func(e): return all_e.count(e) == 1)
	ok("REAL-01", split_ok, "특징 17개 = 나르는 11 + 바꾸는 6 (겹침 없음)")
	var at := c + Vector2(-40, 0)
	var mk := func(e2: int) -> Tower:
		var tw := _tower(c + Vector2(-260, 0), Elem.FIRE, 1)
		tw.add(e2, 3)
		tw.eff = tw.eff_now()
		return tw
	# 자람: 자리 끝에 닿은 구체가 묶이고 효과가 셈
	var wt: Tower = mk.call(Elem.WOOD)
	var o1 := _orb(c, 1e6)
	var o0 := _orb(c + Vector2(0, 120), 1e6)
	_grid.call()
	Share.carry(wt, o0, 0.3, "share:fire", at, 0.0)
	Share.carry(wt, o1, 0.3, "share:fire", at, 1.0)
	ok("REAL-02", o1.root_timer > 0.0 and o0.root_timer <= 0.0 and o1.burn_dps > o0.burn_dps, "자람: 자리 끝은 덩굴이 묶고 효과가 셈 (화상 %.2f > %.2f)" % [o1.burn_dps, o0.burn_dps])
	_clear()
	# 실림: 자리 가운데에서 바깥으로 밀림
	var nt: Tower = mk.call(Elem.WIND)
	var o2 := _orb(c, 1e6)
	_grid.call()
	var x0 := o2.position.x
	Share.carry(nt, o2, 0.3, "share:fire", at, 0.5)
	ok("REAL-03", o2.position.x > x0, "실림: 자리에 닿은 구체를 바깥으로 밀어냄 (%.1f)" % (o2.position.x - x0))
	_clear()
	# 얼림·날 선·되풀이
	var it: Tower = mk.call(Elem.ICE)
	var mt: Tower = mk.call(Elem.METAL)
	var tt: Tower = mk.call(Elem.TIME)
	var o3 := _orb(c, 1e6)
	var o4 := _orb(c + Vector2(0, 100), 1e6, Orb.Kind.NORMAL, 50.0)
	var o5 := _orb(c + Vector2(0, -100), 1e6)
	_grid.call()
	Share.carry(it, o3, 0.3, "share:fire", at, 0.5)
	Share.carry(mt, o4, 0.3, "share:fire", at, 0.5)
	var n0 := tt.later.size()
	Share.carry(tt, o5, 0.3, "share:fire", at, 0.5)
	ok("REAL-04", o3.chill > 0.0 and mt.src.get("share:metal", 0.0) > 0.0 and o4.stagger_t > 0.0 and tt.later.size() > n0,
		"얼림 냉기 %.2f · 날 선 피해 %.1f·멈칫 · 되풀이 예약" % [o3.chill, mt.src.get("share:metal", 0.0)])
	_clear()
	# 불 번짐: 타는 구체에 닿은 구체에 옮겨 붙음 (옮은 불은 다시 안 번짐)
	var ft := _tower(c + Vector2(-260, 0), Elem.FIRE, 3)
	var f1 := _orb(c, 1e6)
	var f2 := _orb(c + Vector2(f1.radius() * 2.0 + 10.0, 0), 1e6)
	var f3 := _orb(c + Vector2(400, 0), 1e6)
	_grid.call()
	ft.hit(f1, 1.0)
	Share.spread(f1)
	ok("REAL-05", f2.burn_t > 0.0 and f2.burn_rx and f3.burn_t <= 0.0, "불 번짐: 닿은 구체에 옮겨 붙음, 먼 구체는 그대로")
	_clear()
	# 나무 휘감기: 3번 감기면 묶임, 감긴 구체에만 가시 피해
	var vt := _tower(c + Vector2(-260, 0), Elem.WOOD, 1)
	var v1 := _orb(c, 1e9)
	_grid.call()
	var h0 := v1.hp
	vt.hit(v1, 10.0)
	var first := h0 - v1.hp
	h0 = v1.hp
	vt.hit(v1, 10.0)
	var second := h0 - v1.hp
	vt.hit(v1, 10.0)
	ok("REAL-06", second > first and v1.root_timer > 0.0, "휘감기: 감긴 구체에 더 아프고(%.1f > %.1f) 3번째에 묶임" % [second, first])
	_clear()
	# 바람 밀쳐냄: 맞은 구체가 오브젝트 반대쪽으로, 순풍(둘레 공격 속도)은 없음
	var wn := _tower(c + Vector2(-260, 0), Elem.WIND, 3)
	var buddy := _tower(c + Vector2(-260, 80), Elem.FIRE, 1)
	var w1 := _orb(c, 1e6)
	_grid.call()
	var wx := w1.position.x
	wn.hit(w1, 1.0)
	main.onboarding_system._wind_buffs()
	ok("REAL-07", w1.position.x > wx and buddy.wind_buff == 0.0, "밀쳐냄: 맞은 구체가 밀림 (%.1f), 순풍 없음" % (w1.position.x - wx))
	_clear()
	# 이름 있는 자리
	var ns := Share.new_sites({Elem.WATER: 1}, Elem.WOOD)
	ok("REAL-08", Share.NAMED.size() == 10 and Share.site_name(Elem.WATER, Elem.WOOD) == "덩굴 길" and ns.has("덩굴 길")
		and Share.site_name(Elem.FIRE, Elem.METAL) == "날 선 불" and Share.sites_of({Elem.FIRE: 1, Elem.ICE: 1}).size() == 1
		and Share.site_name(Elem.ILLUSION, Elem.EARTH) == "환영 · 땅" and Share.site_desc(Elem.ILLUSION, Elem.METAL) == Elem.pair_desc(Elem.ILLUSION, Elem.METAL),
		"자리 이름: 이름 있는 칸 10개, 나머지는 꾸밈말+자리 (%s)" % ", ".join(ns))


# ---------- 공격방식 ----------

func _patterns() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
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
	var saved_pattern: String = t.pattern
	t.pattern = "wisp"
	ok("PAT-03", t.range_text() == "추적 범위 %d · 혼불 %d개" % [roundi(Projectile.wisp_leash(0.0, t.rr(t.plv))), t.wisp_cap()], "혼불 사거리 표시는 추적 범위와 혼불 수")
	t.pattern = saved_pattern



## 공격방식마다: 다가오는 구체에 실제로 피해를 준다.
func _attacks() -> void:
	_fresh(5)
	var c: Vector2 = main.viewport_system.center()
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
			main.combat_system._sim_step(1.0 / 60.0)
			if not is_instance_valid(o) or o.hp < o.max_hp:
				break
		if not is_instance_valid(o) or o.hp >= o.max_hp:
			silent.append(p)
		await process_frame
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	_well()
	_fade()
	await _far()
	ok("PAT-04", silent.is_empty(), "공격방식 %d개 모두 앞에서 다가오는 구체에 피해 (못 맞힘: %s)" % [Pat.PATTERN_IDS.size(), str(silent)])


## 방향성 공격 화면 끝까지 (2026-11-04): 직선탄·돌풍·물줄기·연쇄 번개가 예전 사거리 밖(700) 구체도 맞히고, 그 거리에선 피해가 줄어든다
func _far() -> void:
	var c: Vector2 = main.viewport_system.center()
	var reach := []
	var weak := []
	for p in Tower.FAR_PATS:
		var dealt := []
		for dist in [150.0, 700.0]:
			_fresh(5)
			_clear()
			var t := _tower(c + Vector2(400, 0), Elem.FIRE, 1, Vector2.LEFT)
			if p != "shot":
				t.set_pattern(p)
			var o := _orb(c + Vector2(400 - dist, 0), 99999.0, Orb.Kind.NORMAL, 0.1)
			main.wave_active = true
			main.phase = main.Phase.WAVE
			main.to_spawn = 0
			for i in 480:
				main.combat_system._sim_step(1.0 / 60.0)
				if not is_instance_valid(o) or o.hp < o.max_hp:
					break
			for i in 30:  # 첫 피해 뒤 조금 더 (물줄기·연속 피해 몫)
				main.combat_system._sim_step(1.0 / 60.0)
			dealt.append(o.max_hp - o.hp if is_instance_valid(o) else 0.0)
			await process_frame
		if dealt[1] <= 0.0:
			reach.append(p)
		elif dealt[1] >= dealt[0] * 0.9:
			weak.append(p)
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	var st := Tower.far_start_of("shot", 1, 1, 0.0)
	var math := Tower.far_k(st, st) == 1.0 and is_equal_approx(Tower.far_k(st + Rules.far_len * 0.5, st), 1.0 - (1.0 - Rules.far_min) * 0.5) \
		and is_equal_approx(Tower.far_k(st + 5000.0, st), Rules.far_min) and Tower.far_start_of("spray", 1, 1, 0.0) == INF
	ok("PAT-07", reach.is_empty() and weak.is_empty() and math,
		"방향성 공격 화면 끝까지 + 멀면 약해짐 (못 닿음: %s, 안 약해짐: %s, 감소식 %s)" % [str(reach), str(weak), str(math)])


## 블랙홀 중력 우물 (2026-11-01): 사거리 안 구체가 가장 빽빽한 곳에 떨어지고, 안 구체가 남에게 받은 피해 20%를 모았다가 끝에 나눠 넣음
func _well() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	var vt := _tower(c + Vector2(-100, 0), Elem.DARK, 1, Vector2.LEFT)
	vt.set_pattern("vortex")
	var other := _tower(c + Vector2(-100, 200), Elem.FIRE)
	var lone := _orb(c + Vector2(-200, 0), 1e6)  # 혼자 있는 구체
	var pack := []
	for i in 5:
		pack.append(_orb(c + Vector2(-350, 150) + Vector2(i * 8, i * 6), 1e6))
	main.combat_system.targets = [lone] + pack
	main.combat_system._build_grid()
	var spots := vt.well_spots(1)
	var at_pack: bool = not spots.is_empty() and spots[0].distance_to(pack[0].position) < 60.0
	var z: Zone = main.spawning_system.spawn_zone("vortex", 1, spots[0] if not spots.is_empty() else c, vt)
	z.well()
	var o: Orb = pack[2]
	var before := z.store
	var d0 := other.dealt
	other.hit(o, 1.0)
	var got := other.dealt - d0
	var fed := is_equal_approx(z.store - before, got * 0.2)
	var own0 := z.store
	vt.hit(o, 1.0)
	var self_no := z.store == own0  # 자기 피해는 안 모음
	z.store = 1000.0
	var hp0 := o.hp
	z._end()
	var burst := hp0 - o.hp >= 1000.0 / 5.0 * 0.99
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	ok("PAT-06", at_pack and fed and self_no and burst,
		"중력 우물: 구체 무리에 (%s), 남의 피해 20%% 모음 (%s), 자기 피해 안 모음 (%s), 끝에 나눠 넣음 (%s)" % [at_pack, fed, self_no, burst])


## 유도탄·혼불 감쇠 (2026-11-01): 유도탄은 휜 90도마다 -15%(최저 55%), 혼불은 2초 뒤 초당 -12%(최저 50%)
func _fade() -> void:
	var p := Projectile.new()
	p.kind = "shot"
	var straight := p.fade_k()
	p.turned = PI / 2.0
	var bent := p.fade_k()
	p.turned = 20.0
	var floor_k := p.fade_k()
	var w := Projectile.new()
	w.kind = "wisp"
	w.t = 1.5
	var young := w.fade_k()
	w.t = 4.0
	var old := w.fade_k()
	w.t = 30.0
	var w_floor := w.fade_k()
	p.free()
	w.free()
	ok("MOD-12", straight == 1.0 and is_equal_approx(bent, 0.85) and is_equal_approx(floor_k, 0.55) and young == 1.0 and is_equal_approx(old, 0.76) and is_equal_approx(w_floor, 0.5) and is_equal_approx(Tower.HIT.wisp, 1.15),
		"감쇠: 유도 곧게 %.2f·90도 %.2f·최저 %.2f, 혼불 1.5초 %.2f·4초 %.2f·최저 %.2f" % [straight, bent, floor_k, young, old, w_floor])


## 다중 발사가 짝수 개(다중 1·3개)여도 조준한 정면의 먼 작은 구체를 맞힌다 (2026-11-01: 가운데가 비어 빗나가던 것)
func _multi_center() -> void:
	_fresh(5)
	var c: Vector2 = main.viewport_system.center()
	var far := {"shot": 330.0, "thorn": 400.0, "shard": 320.0, "iron": 400.0, "laser": 450.0, "stream": 190.0, "lob": 260.0}
	var miss := []
	for p in far:
		for nm in [1, 3]:
			_clear()
			var tp := c + Vector2(-520, 0)
			var t := _tower(tp, Elem.FIRE, 1, Vector2.RIGHT)
			if p != "shot":
				t.set_pattern(p)
			for i in nm:
				t.add_mod("multi")
			var o := _orb(tp + Vector2(far[p], 0), 1e9, Orb.Kind.FAST, 0.0)
			o.target = o.position
			main.wave_active = true
			main.phase = main.Phase.WAVE
			main.to_spawn = 0
			for i in 300:  # 5초
				main.combat_system._sim_step(1.0 / 60.0)
				if not is_instance_valid(o) or o.hp < o.max_hp:
					break
			if is_instance_valid(o) and o.hp >= o.max_hp:
				miss.append("%s+다중%d" % [p, nm])
			await process_frame
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	ok("MOD-06", miss.is_empty() and Tower.spread_a(0.5) == 0.0 and Tower.spread_lane(0.5) > 0.0,
		"다중 발사 짝수 개도 정면 먼 구체 맞힘 (가운데 두 발 나란히, 못 맞힘: %s)" % str(miss))


# ---------- 강화가 의미 없던 조합 (2026-11-01) ----------

func _mods_area() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	# MOD-07 관통 (탄 아닌 공격): 보호막을 더 깎고 갑옷이 빼는 피해가 준다
	var a := _tower(c + Vector2(-200, 0))
	a.set_pattern("spray")
	var b := _tower(c + Vector2(-200, 120))
	b.set_pattern("spray")
	b.add_mod("pierce")
	b.add_mod("pierce")
	var oa := _orb(c + Vector2(300, 0), 1e6)
	var ob := _orb(c + Vector2(300, 120), 1e6)
	oa.shield = 1000.0
	ob.shield = 1000.0
	a.hit(oa, 10.0)
	b.hit(ob, 10.0)
	var la := 1000.0 - oa.shield
	var lb := 1000.0 - ob.shield
	var arm := _orb(c + Vector2(300, -120), 1e6)
	arm.late = "armor"
	arm.armor = 5.0
	var d0 := arm.late_direct(10.0, 1.0, 0.0)
	arm.armor_hits = 0.0
	var d2 := arm.late_direct(10.0, 1.0, 2.0)
	ok("MOD-07", lb > la * 1.4 and d2 > d0, "관통 2개 분사: 보호막 %.1f → %.1f 깎음, 갑옷 뒤 피해 %.1f → %.1f" % [la, lb, d0, d2])
	# MOD-08 튕김 (탄 아닌 공격): 맞힌 구체 옆 구체로 작은 탄이 튄다
	_clear()
	var t := _tower(c + Vector2(-200, 0))
	t.set_pattern("spray")
	t.add_mod("bounce")
	t.aim = Vector2.RIGHT
	_orb(c + Vector2(-80, 0), 1e6)
	_orb(c + Vector2(-80, 60), 1e6)
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.to_spawn = 0
	for i in 90:
		main.combat_system._sim_step(1.0 / 60.0)
	await process_frame
	ok("MOD-08", t.src.get("mod:bounce", 0.0) > 0.0 and is_equal_approx(t.bounce_iv(), Rules.t("bounce_iv")),
		"튕김 분사: 튕김 탄 피해 %.2f (%.1f초마다)" % [t.src.get("mod:bounce", 0.0), t.bounce_iv()])
	# MOD-09 벽·투척 속사는 닿은 피해 속도에, 벽 크기는 체력·시간에. 시계침·연쇄 번개 유도 막힘. 관통 연사 유도 보정은 3개째부터
	_clear()
	var w := _tower(c + Vector2(-200, 0))
	w.set_pattern("wall")
	w.add_mod("rapid")
	w.add_mod("rapid")
	w.add_mod("size")
	var z: Zone = main.spawning_system.spawn_zone("rock", 1, c, w)
	var rk: float = z._rapid()
	var life: float = z.max_life
	ok("MOD-09", is_equal_approx(rk, 1.0 + 2.0 * Rules.rapid_k) and is_equal_approx(life, 12.0 * w.sz())
		and ["wall", "wisp", "clock", "chain"].all(func(pat): return not Pat.mod_ok(pat, "homing"))
		and not "혼불은" in Pat.MODS["homing"]["desc"] and "벽·혼불·시계침·연쇄 번개에는 못 넣어요." in Pat.MODS["homing"]["desc"]
		and is_equal_approx(Pat.mod_fix("thorn", "homing", 2.0), 1.0) and is_equal_approx(Pat.mod_fix("thorn", "homing", 5.0), Pat.MOD_FIX["thorn"]["homing"]),
		"벽 속사 2개 피해 속도 x%.2f, 크기 1개 벽 %.1f초, 시계침·연쇄 유도 막힘, 관통 연사 유도 2개 보정 x%.2f" % [rk, life, Pat.mod_fix("thorn", "homing", 2.0)])
	# MOD-14 크기 피해는 공격방식 자기 공격에만: 보조 공격·실어 나른 특징 피해(dmg_k_bare)엔 안 붙고, 숨은 보정 칸도 정보 줄에 보인다
	_clear()
	var sz_t := _tower(c + Vector2(-200, 0))
	sz_t.set_pattern("shot")
	var bare0: float = sz_t.dmg_k(false)
	sz_t.add_mod("size")
	sz_t.add_mod("size")
	sz_t._dk_id = -1
	var own: float = sz_t.dmg_k(false)
	var bare: float = sz_t.dmg_k_bare()
	var line: String = sz_t.mod_effect("size")
	ok("MOD-14", line.contains("이 공격방식 피해") and own > bare0 * 1.01 and is_equal_approx(bare, bare0) and is_equal_approx(own / bare, sz_t.size_part()) and not line.contains("보정"),
		"크기 2개 직선탄: 자기 공격 x%.3f, 보조 공격·특징 x%.3f · %s" % [own / bare0, bare / bare0, line])
	# MOD-10 돌풍 다중 발사: 부채꼴이 아니라 같은 방향으로 나란히
	_clear()
	Rules.tune["auto_aim"] = 0.0  # 정한 방향으로 나란히 나가는지 (구체 없이)
	var g := _tower(c + Vector2(-300, 0))
	g.set_pattern("gust")
	g.add_mod("multi")
	g.add_mod("multi")
	g.aim = Vector2.RIGHT
	var dirs := []
	for i in 60:
		main.combat_system._sim_step(1.0 / 60.0)
		for p in main.projectiles.get_children():
			if p.kind == "gust" and not p in dirs:
				dirs.append(p)
	var same := dirs.size() >= 3
	for p in dirs:
		same = same and p.vel.normalized().dot(dirs[0].vel.normalized()) > 0.999
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	Rules.tune["auto_aim"] = Rules.DEFAULTS["auto_aim"]
	ok("MOD-10", same, "돌풍 다중 2개: 돌풍 %d개가 같은 방향으로 나란히" % dirs.size())


# 자동 조준 기본 기능 (2026-11-07, rules.auto_aim 1): 카드 없이 전방위·감산 없음·카드 풀/도감에서 빠짐·예전 저장 버림·예측 조준.
func _auto_default() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	var card := {"type": "mod", "id": "reflex"}
	var t := _tower(c, Elem.WIND)
	var pool_ok := not "reflex" in Pat.mod_ids() and not t.can_take(card) and not "mod:reflex" in Ach.cat_keys("mod")
	var back := _orb(c + Vector2.LEFT * 120.0, 1000.0)
	t._update_aim([back], 0.016)
	var aim_ok := t.auto_aim() and t.reflex_target == back and t.aim.is_equal_approx(Vector2.LEFT) and is_equal_approx(t.final_damage_mul(), 1.0)
	var far := _orb(c + Vector2.RIGHT * 900.0, 1000.0)
	t._update_aim([far], 0.016)
	aim_ok = aim_ok and t.reflex_target == far  # 직선탄은 화면 끝까지 겨눔
	var wisp := _tower(c + Vector2(0, 200))
	wisp.set_pattern("wisp")
	aim_ok = aim_ok and not wisp.auto_aim()
	var sv := t.to_save()
	sv["mods"] = {"reflex": 1, "rapid": 2}
	var restored := Tower.new()
	restored.load_save(sv)
	var save_ok := restored.m("reflex") == 0 and restored.m("rapid") == 2 and restored.mod_count() == 2
	restored.free()
	# 예측 조준: 위로 걷는 구체는 지금 자리보다 위를 겨눈다. 바로 닿는 공격(분사)과 aim_lead 0은 지금 자리
	var walker := _orb(c + Vector2.RIGHT * 300.0, 1000.0)
	walker.walk_vel = Vector2(0, -100)
	var d := t.lead_dir(walker)
	var tt := 300.0 / sqrt(440.0 * 440.0 - 100.0 * 100.0)
	var lead_ok := d.is_equal_approx((Vector2(300, -100.0 * tt)).normalized())
	t.pattern = "spray"
	lead_ok = lead_ok and t.lead_dir(walker).is_equal_approx(Vector2.RIGHT)
	t.pattern = "shot"
	Rules.tune["aim_lead"] = 0.0
	lead_ok = lead_ok and t.lead_dir(walker).is_equal_approx(Vector2.RIGHT)
	Rules.tune["aim_lead"] = Rules.DEFAULTS["aim_lead"]
	walker.walk_vel = Vector2.ZERO
	walker.position = c + Vector2.RIGHT * 300.0
	walker.target = walker.position + Vector2(0, -500)
	walker.speed = 60.0
	walker.step(0.1)
	var walk_ok := walker.walk_vel.is_equal_approx(Vector2(0, -60))
	# 지키는 곳 먼저: 중앙에 가장 가까운 구체, 중앙까지 거리가 비슷하면(aim_band) 정한 방향 쪽, 회랑은 문까지 가로 거리
	_clear()
	var cc: Vector2 = main.viewport_system.center()
	t = _tower(cc + Vector2(150, 0), Elem.WIND, 1, Vector2.UP)
	var near_core := _orb(cc + Vector2(0, 60), 1000.0)  # 중앙 60, 방향 밖
	var near_tower := _orb(cc + Vector2(150, -150), 1000.0)  # 정한 방향 바로 앞이지만 중앙 212
	t._update_aim([near_tower, near_core], 0.016)
	var pref_ok := t.reflex_target == near_core
	var front_tie := _orb(cc + Vector2(100, -60), 1000.0)  # 중앙 117(차 57 < aim_band), 방향 40도 안
	t._update_aim([near_tower, near_core, front_tie], 0.016)
	pref_ok = pref_ok and t.reflex_target == front_tie
	Rules.tune["aim_pref"] = 0.0
	t._update_aim([near_tower, near_core, front_tie], 0.016)
	pref_ok = pref_ok and t.reflex_target == near_core
	Rules.tune["aim_pref"] = Rules.DEFAULTS["aim_pref"]
	Meta.map_id = "line"
	var gate: float = main.viewport_system.core().x
	var line_a := _orb(Vector2(gate + 40, cc.y + 200), 1000.0)  # 문 가로 40 (세로로는 멀어도)
	var line_b := _orb(Vector2(gate + 300, cc.y), 1000.0)
	pref_ok = pref_ok and is_equal_approx(t.goal_dist(line_a), 40.0) and t.goal_dist(line_b) > t.goal_dist(line_a)
	Meta.map_id = "plain"
	ok("MOD-13", pref_ok, "자동 조준 지키는 곳 먼저: 중앙에 가까운 구체 우선, 비슷하면 정한 방향 쪽, aim_pref 0이면 방향 무시, 회랑은 문까지 가로 거리")
	ok("MOD-13", pool_ok and aim_ok and save_ok, "자동 조준 기본: 카드·도감 분모에서 빠짐, 강화 없이 후방·화면 끝 조준, 감산 없음, 혼불 제외, 예전 저장의 카드 버림")
	ok("MOD-13", lead_ok and walk_ok, "자동 조준 예측: 탄 속도로 만나는 곳을 앞질러 겨눔, 바로 닿는 공격·aim_lead 0은 지금 자리, 구체 걸음 속도 기록")
	_clear()


# 반응: 기존 방향 고정과 다른 전방위 조준·최종 감산·모드/저장 경계.
func _reflex() -> void:
	_auto_default()
	_fresh()
	Rules.tune["auto_aim"] = 0.0  # 아래는 예전 강화 카드 방식(rules.auto_aim 0) 검사
	var c: Vector2 = main.viewport_system.center()
	var card := {"type": "mod", "id": "reflex"}
	var t := _tower(c + Vector2(-100, 0), Elem.WIND)
	var other := _tower(c + Vector2(100, 0), Elem.WATER)
	var selectable: bool = main.towers.get_children().any(func(tw): return tw.can_take(card))
	t.add_mod("reflex")
	t.add_mod("reflex")
	var cap_ok := t.m("reflex") == 1 and not t.can_take(card) and other.can_take(card) and t.refuse_text(card).contains("1개")
	Meta.rules = 3
	main.run_flow_system._apply_rules()
	Rules.tune["auto_aim"] = 0.0
	cap_ok = cap_ok and not t.can_take(card)
	Meta.rules = 1
	main.run_flow_system._apply_rules()
	Rules.tune["auto_aim"] = 0.0
	var restored := Tower.new()
	restored.load_save(t.to_save())
	var save_ok := restored.m("reflex") == 1 and not restored.can_take(card)
	restored.free()
	var blocked := true
	for pat in ["wisp", "vortex"]:
		blocked = blocked and not t.can_pattern(pat) and not Pat.mod_ok(pat, "reflex")
	ok("MOD-13", selectable and cap_ok and save_ok and blocked, "반응: 카드 후보·오브젝트당 1개(랭크/도파민)·저장 복원·무효 조합")
	# 사거리 밖·죽은 구체 무시, 뒤·옆의 최근접 구체로 즉시 회전. 유도와 함께도 동일.
	var far := _orb(t.position + Vector2.RIGHT * (t.reflex_range() + 1.0), 1000.0)
	var dead := _orb(t.position + Vector2.RIGHT * 10.0, 0.0)
	var back := _orb(t.position + Vector2.LEFT * 100.0, 1000.0)
	var side := _orb(t.position + Vector2.DOWN * 80.0, 1000.0)
	t._update_aim([far, dead], 0.016)
	var no_target := t.reflex_target == null
	t._update_aim([far, dead, back], 0.016)
	var back_ok := t.aim.is_equal_approx(Vector2.LEFT) and t.dir == Vector2.RIGHT
	t.add_mod("homing")
	t._update_aim([back, side], 0.016)
	ok("MOD-13", no_target and back_ok and t.reflex_target == side and t.aim.is_equal_approx(Vector2.DOWN), "반응: 사거리 밖/죽은 구체 제외·후방 조준·최근접 전환·유도 공존")
	# 사거리 밖이면 탄을 아끼며 쿨다운만 진행, 들어오면 바로 발사.
	t.cd["p"] = 0.1
	t.attack(0.2, [far])
	var wait_ok: bool = main.projectiles.get_child_count() == 0 and is_zero_approx(t.cd["p"])
	t.attack(0.016, [back])
	var shot_ok: bool = main.projectiles.get_child_count() == 1 and main.projectiles.get_child(0).vel.x < 0.0
	ok("MOD-13", wait_ok and shot_ok, "반응: 사거리 밖 발사 없음·대기 중 쿨다운·진입 즉시 후방 발사")
	# 직접·반응·갑옷·보호막·화상·중독의 실제 체력/보호막 감소량.
	var damage_ok := true
	t.mods.erase("reflex")
	t.eff = {Elem.WIND: 1}
	var victim := _orb(c + Vector2(0, -200), 10000.0)
	for rx in [false, true]:
		t.in_rx = rx
		var before := victim.hp
		t.hit(victim, 100.0)
		var normal := before - victim.hp
		t.mods["reflex"] = 1
		before = victim.hp
		t.hit(victim, 100.0)
		damage_ok = damage_ok and is_equal_approx(before - victim.hp, normal * 0.9)
		t.mods.erase("reflex")
	t.in_rx = false
	t.mods["reflex"] = 1
	victim.shield = 100.0
	victim.hurt(10.0, false, t)
	damage_ok = damage_ok and is_equal_approx(victim.shield, 91.0)
	t.pattern = "spray"
	t.mods["pierce"] = 1
	t.mods.erase("reflex")
	victim.shield = 1000.0
	t.hit(victim, 10.0)
	var shield_loss := 1000.0 - victim.shield
	t.mods["reflex"] = 1
	victim.shield = 1000.0
	t.hit(victim, 10.0)
	damage_ok = damage_ok and is_equal_approx(1000.0 - victim.shield, shield_loss * 0.9)
	t.mods.erase("pierce")
	t.pattern = "shot"
	victim.shield = 0.0
	victim.burn(10.0, 2.0, t)
	victim.poison(10.0, 2.0, t)
	var hp := victim.hp
	victim.step(0.1)
	damage_ok = damage_ok and is_equal_approx(hp - victim.hp, 1.8)
	victim.late = "armor"
	victim.armor = 5.0
	t.mods.erase("reflex")
	hp = victim.hp
	t.hit(victim, 100.0)
	var armored := hp - victim.hp
	victim.armor_hits = 0.0
	t.mods["reflex"] = 1
	hp = victim.hp
	t.hit(victim, 100.0)
	damage_ok = damage_ok and is_equal_approx(hp - victim.hp, armored * 0.9)
	ok("MOD-13", damage_ok, "반응: 직접/특수 반응/보호막/화상/중독/갑옷 뒤 최종 피해 x0.9")
	# 방향을 쓰는 모든 공격방식에서 후방 조준, 범위 미리보기와 실제 수치 일치.
	var patterns_ok := true
	for pat in Pat.ALL_IDS:
		if not Pat.mod_ok(pat, "reflex"):
			continue
		t.pattern = pat
		t._update_aim([back], 0.016)
		patterns_ok = patterns_ok and t.reflex_target == back and t.aim.is_equal_approx(Vector2.LEFT)
	var content: Dictionary = main.cards_system._card_content(card, 1)
	var text_ok: bool = content["foot"][0][1].contains("1회") and content["rows"][0]["t"].contains("-10%")
	ok("MOD-13", patterns_ok and text_ok, "반응: 방향 공격 13종 후방 조준·카드 앞면 1회/피해 감산 안내")
	# 실제 전투 경로에서 방향 고정 분사는 후방에 0, 반응은 피해 발생.
	_fresh()
	Rules.tune["auto_aim"] = 0.0
	t = _tower(c + Vector2(-100, 0), Elem.WATER)
	t.set_pattern("spray")
	victim = _orb(t.position + Vector2.LEFT * 100.0, 1000.0)
	main.combat_system._resolve(0.1)
	var fixed_hp := victim.hp
	t.add_mod("reflex")
	main.combat_system._resolve(0.1)
	ok("MOD-13", is_equal_approx(fixed_hp, 1000.0) and victim.hp < fixed_hp, "반응: 실제 전투 분사 후방 구체 명중 (기존 방향 고정은 0)")


# PR #11 리뷰: 기존 검사가 놓친 쿨다운·실제 사거리·처형 경계를 재현한다.
func _reflex_review_regressions() -> void:
	_fresh()
	Rules.tune["auto_aim"] = 0.0
	var c: Vector2 = main.viewport_system.center()
	var t := _tower(c, Elem.FIRE)
	t.add(Elem.WOOD, 1)
	t.eff = t.eff_now()
	t.add_mod("reflex")
	t.cd = {"p": 1.0}
	t.attack(0.1, [])
	ok("MOD-13", t.cd["p"] < 1.0,
		"반응 대기: 구체가 없어도 기본 공격 쿨다운은 흐름 (%.4f)" % t.cd["p"])
	_fresh()
	Rules.tune["auto_aim"] = 0.0
	t = _tower(c, Elem.WIND, 3)
	t.add_mod("reflex")
	var ranges_ok := true
	var details := []
	for pat in ["lob", "gust", "thorn", "iron", "shard"]:
		t.pattern = pat
		t.mods["homing"] = 1
		t.mods["size"] = 5
		var pr := Projectile.new()
		pr.setup("blob" if pat == "lob" else pat, t, t.plv, Vector2.RIGHT)
		pr.form_init()
		var want := pr.far_from if pat in Tower.FAR_PATS else pr.max_travel  # 화면 끝까지 가는 방향성 공격은 감소 시작 거리까지 감지
		var same := is_equal_approx(t.reflex_range(), want)
		ranges_ok = ranges_ok and same
		if not same:
			details.append("%s 감지%.1f/탄%.1f" % [pat, t.reflex_range(), want])
		pr.free()
	ok("MOD-13", ranges_ok, "반응: 바람·크기·유도 보정 뒤 실제 탄 사거리와 일치 %s" % [details])
	_fresh()
	Rules.tune["auto_aim"] = 0.0
	Meta.map_id = "storm"
	Rules.tune["map_on"] = 1.0
	main.lanes.assign([0.0])
	t = _tower(c, Elem.WIND, 3)
	t.pattern = "lob"
	t.add_mod("reflex")
	var weather_ok := true
	var wind := MapRule.wind_dir(main.lanes)
	for direction in [wind, -wind]:
		var pr := Projectile.new()
		pr.setup("blob", t, t.plv, direction)
		pr.form_init()
		var target := _orb(c + direction * (pr.far_from - 1.0), 1000.0)  # 투척 장판은 화면 끝까지 날고 감지는 감소 시작 거리까지
		t._update_aim([target], 0.016)
		weather_ok = weather_ok and t.reflex_target == target
		target.position = c + direction * (pr.far_from + 1.0)
		t._update_aim([target], 0.016)
		weather_ok = weather_ok and t.reflex_target == null
		pr.free()
	ok("MOD-13", weather_ok, "반응 폭풍: 순풍/역풍의 실제 탄 사거리 안만 감지")
	_fresh()
	Rules.tune["auto_aim"] = 0.0
	t = _tower(c)
	t.pattern = "wall"
	t.add_mod("reflex")
	var o := _orb(c + Vector2.LEFT * 150.0, 1000.0)
	t._update_aim([o], 0.016)
	ok("MOD-13", t.reflex_target == o, "반응 벽: 두 번째 벽이 닿는 150 거리 구체도 감지 (감지 %.1f)" % t.reflex_range())


# ---------- 강화·연계·발동 ----------

func _mods_links() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	var t := _tower(c + Vector2(-200, 0))
	for i in Rules.max_mod:
		t.add_mod("rapid")
	ok("MOD-01", Rules.max_mod == 5 and not t.can_take({"type": "mod", "id": "rapid"}), "랭크: 같은 강화 5개까지")
	var tt := _tower(c + Vector2(-200, 120))
	for id in ["multi", "rapid", "size", "pierce", "bounce", "split"]:
		for i in 2:
			tt.add_mod(id)
	ok("MOD-11", Rules.mod_total == 12 and tt.mod_count() == 12 and not tt.can_take({"type": "mod", "id": "homing"}) and tt.refuse_text({"type": "mod", "id": "homing"}).contains("12개까지"),
		"랭크: 한 오브젝트 강화 합쳐 12개까지 (%d개 든 오브젝트에 새 종류 거절)" % tt.mod_count())
	ok("MOD-02", is_equal_approx(t.spd_k() * t.tax(), 1.5), "속사 5개 = 공격 속도 +50%% (%.2f)" % (t.spd_k() * t.tax()))

	Meta.rules = 3
	main.run_flow_system._apply_rules()
	var u := Tower.new()
	u.mods = {"size": 3}
	ok("MOD-03", is_equal_approx(u.mf("size"), 1.75) and Rules.mod_total >= Rules.NO_CAP, "도파민 모드: 같은 강화는 1, 1.5, 1.75… (3개 %.2f), 합계 상한 없음" % u.mf("size"))
	u.free()
	Meta.rules = 1
	main.run_flow_system._apply_rules()
	Rules.tune["map_on"] = 0.0

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
	near.add_link("pincer")
	ok("LINK-02", near.pincer == 1 and near.extras_text().contains("협공") and not Pat.LINKS.has("prism"), "협공을 넣으면 오브젝트에 표시, 속성을 나누는 프리즘은 없음")

	ok("CROWD-01", is_equal_approx(Rules.crowd_bonus(5), 0.1 * log(5.0)) and roundi(Rules.crowd_bonus(10) * 100) == 23, "오브젝트 수 보너스: 5개 +%d%%, 10개 +%d%%" % [roundi(Rules.crowd_bonus(5) * 100), roundi(Rules.crowd_bonus(10) * 100)])

	for i in Tower.TRIG_MAX:
		r.add_trig("vanguard")
	ok("TRIG-01", not r.can_take({"type": "trig", "id": "vanguard"}) and r.can_take({"type": "trig", "id": "echo"}), "발동 카드는 종류마다 %d장까지" % Tower.TRIG_MAX)
	ok("TRIG-02", is_equal_approx(Tower.van_mul(1), 1.4) and is_equal_approx(Tower.van_mul(2), 1.55), "선봉: x1.4, 한 장마다 +0.15")
	# 선봉: 체력 70% 이상 구체에 x1.4, 그 아래는 그대로, 공격 속도는 안 바뀜
	_clear()
	var va := _tower(c + Vector2(-200, 0), Elem.WIND)
	var sp0 := va.spd_k()
	va.add_trig("vanguard")
	var full := _orb(c + Vector2(-120, 0), 100.0)
	var hurt := _orb(c + Vector2(-120, 30), 100.0)
	hurt.hp = 60.0
	var v0 := va.dealt
	va.hit(full, 1.0)
	var v1 := va.dealt - v0
	va.hit(hurt, 1.0)
	var v2 := va.dealt - v0 - v1
	ok("TRIG-03", is_equal_approx(v1 / v2, 1.4) and va.src.has("trig:vanguard"), "선봉: 성한 구체 피해 x%.2f(체력 60%% 구체 대비), 출처 trig:vanguard" % (v1 / v2))
	ok("TRIG-04", is_equal_approx(va.spd_k(), sp0), "선봉은 공격 속도를 바꾸지 않음")

	_stars()

	# 축적: 둘레 처치(특수 2·보스 8)를 모아 다 차면 다음 공격 x5, 쏘면 비움
	_clear()
	var ch := _tower(c + Vector2(-200, 0))
	ch.add_trig("charge")
	var far := _orb(c + Vector2(-200, 300), 10.0)
	for i in 6:
		ch.add_charge(far)
	ch.add_charge(_orb(c + Vector2(-150, 0), 10.0, Orb.Kind.TANK))
	var c7 := ch.charge
	ch.add_charge(_orb(c + Vector2(-150, 20), 10.0, Orb.Kind.BOSS))
	main.combat_system.targets = main.orbs.get_children()
	main.combat_system._build_grid()
	var f: Array = ch._fire_mul(true)
	main.combat_system.targets = []
	main.combat_system._build_grid()
	ok("TRIG-06", is_equal_approx(c7, 8.0) and is_equal_approx(f[0], 5.0) and f[2] == "trig:charge" and ch.charge == 0.0 and ch.charge_need() == 15,
		"축적: 처치 1·특수 2·보스 8, 15 차면 다음 공격 x%.1f, 쏘면 비움 (8 → %.0f)" % [f[0], c7])

	# 삼연: 3번째 공격마다 x1.8
	var th := _tower(c + Vector2(-260, 80))
	th.add_trig("third")
	var ms := []
	for i in 6:
		ms.append(th._fire_mul(true)[0])
	ok("TRIG-07", ms == [1.0, 1.0, 1.8, 1.0, 1.0, 1.8], "삼연: 3번째 공격마다 x1.8 %s" % str(ms))

	# 마무리: 체력 30% 아래 구체에 x1.6, 보스는 절반(x1.3)
	_clear()
	var fi := _tower(c + Vector2(-200, 0), Elem.WIND)
	fi.add_trig("finish")
	var hi := _orb(c + Vector2(-120, 0), 100.0)
	var lo := _orb(c + Vector2(-120, 30), 100.0)
	lo.hp = 20.0
	var d0 := fi.dealt
	fi.hit(hi, 1.0)
	var d1 := fi.dealt - d0
	fi.hit(lo, 1.0)
	var d2 := fi.dealt - d0 - d1
	ok("TRIG-08", is_equal_approx(d2 / d1, 1.6) and fi.src.has("trig:finish"), "마무리: 약한 구체 피해 x%.2f, 피해 출처 trig:finish" % (d2 / d1))

	# 호응: 둘레 오브젝트의 발동이 터지면 그쪽으로 한 발, 0.6초에 한 번
	var an := _tower(c + Vector2(-200, 120), Elem.WIND)
	an.add_trig("answer")
	var n0: int = main.projectiles.get_child_count()
	fi._notify_allies(c)
	var n1: int = main.projectiles.get_child_count()
	fi._notify_allies(c)
	ok("TRIG-09", n1 == n0 + 1 and main.projectiles.get_child_count() == n1 and an.answer_cd > 0.0, "호응: 둘레 발동에 한 발 (%d발), 쿨 동안은 안 쏨" % (n1 - n0))


# ---------- 별 ----------

func _stars() -> void:
	_clear()
	var c: Vector2 = main.viewport_system.center()
	var st := _tower(c + Vector2(-200, 0), Elem.STAR)
	var fi := _tower(c + Vector2(-100, 0), Elem.FIRE)
	var wa := _tower(c + Vector2(-200, 100), Elem.WATER)
	main.combat_system.star_towers = [st]
	var o := _orb(c + Vector2(-60, 0), 1e6)
	var d0 := fi.dealt
	fi.hit(o, 1.0)
	var got := fi.dealt - d0
	ok("STAR-01", is_equal_approx(st.star_sum, got * 0.10 * 1.5) and st.star_e.has(Elem.FIRE) and is_equal_approx(fi.dealt - d0, got),
		"별빛: 둘레 피해의 10%% x1.5(별만) 복사 (%.3f / %.3f)" % [st.star_sum, got])
	# 레벨 성장은 Lv5까지, 자기 피해엔 별만 보너스 없음, 별 둘이 같은 피해를 받으면 나눠 받음
	var sx := _tower(c + Vector2(300, 250), Elem.STAR)
	var r5 := sx.star_rate(false)
	sx.add(Elem.STAR, 4)
	var r5b := sx.star_rate(false)
	sx.add(Elem.STAR, 6)
	var r11 := sx.star_rate(false)
	sx.free()
	var rs := st.star_rate(true)
	var st2 := _tower(c + Vector2(-150, -80), Elem.STAR)
	main.combat_system.star_towers = [st, st2]
	st.star_sum = 0.0
	d0 = fi.dealt
	fi.hit(o, 1.0)
	got = fi.dealt - d0
	ok("STAR-01", is_equal_approx(r5b, (0.10 + 0.03 * 4) * 1.5) and is_equal_approx(r11, r5b) and r5 < r5b and is_equal_approx(rs, 0.2)
		and is_equal_approx(st.star_sum, got * 0.5 * 0.15) and is_equal_approx(st2.star_sum, got * 0.5 * 0.15),
		"별빛 상한: Lv5 %.3f = Lv11 %.3f, 자기 %.2f, 별 둘이면 반씩 (%.3f / %.3f)" % [r5b, r11, rs, st.star_sum, st2.star_sum])
	st2.free()
	main.combat_system.star_towers = [st]

	# 행성: 별 + 불 = 불의 행성, 불 몫만 30%
	st.add(Elem.FIRE, 1)
	st.star_sum = 0.0
	st.star_e.clear()
	wa.hit(o, 1.0)
	var none := st.star_sum
	d0 = fi.dealt
	fi.hit(o, 1.0)
	got = fi.dealt - d0
	var none_k := none / maxf(wa.dealt, 0.0001)
	ok("STAR-02", st.planet() == Elem.FIRE and is_equal_approx(none_k, 0.05) and is_equal_approx(st.star_sum - none, got * 0.45) and is_equal_approx(st.planet_rate(st), 0.3) and not st.can_take({"type": "elem", "e": Elem.ICE, "lv": 1}),
		"행성: 물 피해는 5%%(%.3f), 불 몫 45%% (%.3f / %.3f), 자기 30%%, 3종 못 넣음" % [none_k, st.star_sum - none, got])

	# 초신성: 가운데 하나뿐이면 별빛 x3을 그 구체에
	st.star_sum = st.star_need()
	st.star_e = {Elem.FIRE: st.star_sum}
	var big := _orb(c + Vector2(-300, -200), 1e6)
	var hp0 := big.hp
	var pool := st.star_sum * 3.0 * 0.85  # 행성 초신성은 x0.85 (planet_mul)
	var pool_star := st.star_sum * 3.0
	st._supernova(big)
	ok("STAR-03", st.star_sum == 0.0 and hp0 - big.hp >= pool * 0.99 and hp0 - big.hp < pool_star * 0.99 and st.src.has("elem:star") and big.burn_t > 0.0,
		"초신성: 행성은 별빛 x3 x0.85 (%.0f 중 %.0f), 행성 효과" % [pool, hp0 - big.hp])
	# 초신성 그림은 웨이브가 끝나도(쉬는 시간·카드 선택) 0.6초 뒤 사라진다 (예전엔 attack이 안 불려 다음 웨이브까지 남음)
	var fx_on := st.nova_fx > 0.0
	st.fx["laser"] = 0.3
	var ph0 = main.phase
	main.phase = main.Phase.CHOOSE
	for i in 50:
		main.frame_system._process(0.016)
	main.phase = ph0
	ok("STAR-06", fx_on and st.nova_fx == 0.0 and st.fx["laser"] == 0.0,
		"웨이브 밖에서도 초신성·공격 그림 사라짐 (%.2f)" % st.nova_fx)
	# 초신성 예고: 별빛 85%부터 터질 자리(지금 터지면 맞을 구체)를 골라 두고, 그 아래면 없음
	var aim_o := _orb(st.position + Vector2(-200, 0), 1e6)
	main.combat_system.targets = [aim_o]
	main.combat_system._build_grid()
	st.star_sum = st.star_need() * 0.5
	st._nova_aim_tick(0.3)
	var aim_lo = st.nova_aim
	st.star_sum = st.star_need() * 0.9
	st._nova_aim_tick(0.3)
	ok("STAR-08", aim_lo == null and st.nova_aim == aim_o and Tower.NOVA_FX_T <= 0.8,
		"초신성 예고: 50%%엔 없음, 90%%엔 터질 자리 (%s)" % [st.nova_aim != null])
	ok("STAR-08", Tower.GAUGE_GAP - Tower.GAUGE_W * 0.5 - 2.0 > 7.0 + 2.5 and Tower.GAUGE_W >= 5.0,
		"별빛 게이지 고리가 속성 점(RADIUS+7)과 안 겹치고 굵음 (+%s, 두께 %s)" % [Tower.GAUGE_GAP, Tower.GAUGE_W])
	st.nova_aim = null
	aim_o.free()
	main.combat_system.targets = []
	# 보스 상한: 초신성 한 번(행성 효과·화상 포함)이 보스에게는 최대 체력의 star_boss_cap(15%)까지. 옆 일반 구체는 그대로
	st.star_sum = st.star_need()
	st.star_e = {Elem.FIRE: st.star_sum}
	var pool2 := st.star_sum * 3.0
	var boss := _orb(c + Vector2(-300, 200), pool2 / 12.0, Orb.Kind.BOSS)
	var mate := _orb(c + Vector2(-260, 200), 1e6)
	var bh0 := boss.hp
	var mh0 := mate.hp
	main.combat_system.targets = main.orbs.get_children().filter(func(o): return is_instance_valid(o) and not o.is_queued_for_deletion())
	main.combat_system._build_grid()
	st._supernova(boss)
	var bcap := boss.max_hp * Rules.t("star_boss_cap")
	var blost := bh0 - boss.hp  # 바로 깎인 몫 (행성 화상은 상한에서 미리 빼 두므로 이보다 적게 남는다)
	ok("STAR-07", is_equal_approx(Rules.t("star_boss_cap"), 0.15) and blost <= bcap * 1.01 and blost >= bcap * 0.5 and mh0 - mate.hp >= pool2 * 0.4
		and Elem.rider(Elem.STAR).contains("보스"),
		"보스 상한: 체력 %.0f 중 %.0f(상한 %.0f), 옆 구체 %.0f" % [boss.max_hp, blost, bcap, mh0 - mate.hp])
	boss.free()
	mate.free()
	main.combat_system.targets = []
	main.combat_system._build_grid()

	# 행성 제한: 같은 행성은 하나, 행성은 3개까지
	var s2 := _tower(c + Vector2(100, -150), Elem.STAR)
	var same := s2.can_take({"type": "elem", "e": Elem.FIRE, "lv": 1})
	var why := s2.refuse_text({"type": "elem", "e": Elem.FIRE, "lv": 1})
	s2.add(Elem.ICE, 1)
	var s3 := _tower(c + Vector2(150, 100), Elem.STAR)
	s3.add(Elem.WATER, 1)
	var s4 := _tower(c + Vector2(250, 0), Elem.STAR)
	var fourth := s4.can_take({"type": "elem", "e": Elem.WIND, "lv": 1})
	var plain := _tower(c + Vector2(250, 150), Elem.WIND)
	ok("STAR-04", not same and why.contains("이미") and not fourth and not plain.can_take({"type": "elem", "e": Elem.STAR, "lv": 1}),
		"같은 행성 막음(%s), 행성 3개까지" % why)
	# 별 상한: 별이 든 오브젝트(별·행성 합쳐) 3개까지. 다 차면 새로 놓기·다른 오브젝트에 별 넣기를 막고, 있는 별 레벨업은 된다
	_clear()
	var p1 := _tower(c + Vector2(-200, 0), Elem.STAR)
	_tower(c + Vector2(200, 0), Elem.STAR)
	var w1 := _tower(c + Vector2(0, 200), Elem.WIND)
	var free_before: bool = not main.cards_system.star_full() and w1.can_take({"type": "elem", "e": Elem.STAR, "lv": 1})
	p1.add(Elem.FIRE, 1)  # 행성도 같이 센다
	w1.add(Elem.STAR, 1)
	var w2 := _tower(c + Vector2(0, -200), Elem.WIND)
	var star_card := {"type": "elem", "e": Elem.STAR, "lv": 1}
	var why5: String = w2.refuse_text(star_card)
	ok("STAR-05", free_before and Tower.star_count(main) == 3 and main.cards_system.star_full() and not w2.can_take(star_card) and why5.contains("합쳐")
		and w1.can_take(star_card) and not main.cards_system._star_blocked(star_card),
		"별·행성 합쳐 3개 (%d개, %s)" % [Tower.star_count(main), why5])
	main.combat_system.star_towers = []


# ---------- 웨이브 ----------

func _waves() -> void:
	_fresh()
	ok("WAVE-01", main.wave_size(1) == 5 and main.wave_size(10) == 23 and main.wave_size(20) == 43, "웨이브 구체 수 3+2w (%d·%d·%d)" % [main.wave_size(1), main.wave_size(10), main.wave_size(20)])
	var ls := [1, 3, 6, 9, 12, 18, 24, 99].map(func(w): return main.lanes_for(w))
	ok("WAVE-02", ls == [1, 2, 3, 4, 4, 5, 6, 6], "진입 방향 수: 3·6·9웨이브에 하나씩, 18·24에 하나씩, 최대 6 %s" % str(ls))
	ok("WAVE-03", main.spawn_count(3) == roundi(main.wave_size(3) * 0.8) and main.spawn_count(4) == main.wave_size(4), "새 진입 방향이 열리는 웨이브는 구체 20% 적게")
	Meta.map_id = "cross"
	var cross: int = main.spawn_count(4)
	Meta.map_id = "plain"
	ok("WAVE-04", cross == roundi(main.wave_size(4) * 1.5), "십자로 맵 구체 1.5배")
	ok("WAVE-05", is_equal_approx(main.hp_growth(10), 1.0) and is_equal_approx(main.hp_growth(12), 1.05 * 1.05), "11웨이브부터 구체 체력 웨이브마다 x1.05")
	# 진입 부채꼴(화면)과 실제 구체 각도가 같은 폭: 웨이브 11에 ±0.26, 25웨이브부터 ±0.4, 십자로 0.06, 회랑 0
	main.lanes.assign([1.0, 3.0])
	main.wave = 10
	var sp: float = main.lane_spread(11)
	var inside := true
	var widest := 0.0
	for i in 400:
		var a: float = main.spawning_system._roll_orb(11)["a"]
		var off: float = minf(absf(angle_difference(a, 1.0)), absf(angle_difference(a, 3.0)))
		widest = maxf(widest, off)
		inside = inside and off <= sp + 0.0001
	Meta.map_id = "cross"
	var sc: float = main.lane_spread(30)
	Meta.map_id = "line"
	var sl: float = main.lane_spread(30)
	Meta.map_id = "plain"
	ok("UI-27", inside and widest > sp * 0.9 and is_equal_approx(sp, 0.26) and is_equal_approx(main.lane_spread(25), 0.4) and is_equal_approx(main.lane_spread(40), 0.4) and sc == 0.06 and sl == 0.0, "구체는 진입 부채꼴(±%.2f) 안으로만, 폭 끝까지 옴 (가장 벗어난 %.2f)" % [sp, widest])
	# 소용돌이 진입 띠: 실제 구체 이동 식으로 띠 안에 들어오는지 (두 회전 방향, 모서리 낀 길목 포함)
	Meta.map_id = "spiral"
	main.phase = main.Phase.READY
	var sv_out := 0.0
	var vc: Vector2 = main.viewport_system.center()
	for wv in [3, 6, 31]:
		main.wave = wv - 1
		var sps: float = main.lane_spread(wv)
		var sws: float = BinduSession.SPIRAL_SWIRL * MapRule.swirl_sign(wv)
		for la in [0.3, 1.0, 2.0, -2.2]:
			var band: Array = main.field_overlay_system._spiral_band(la, sps)
			var bm: PackedVector2Array = band[0]
			for k in 21:
				var aa: float = la - sps + 2.0 * sps * k / 20.0
				var p: Vector2 = vc + Vector2.from_angle(aa) * main.spawning_system._spawn_radius(aa)
				var bi := 0
				for n in 4000:
					if p.distance_to(vc) <= 80.0:
						break
					p += (vc - p).normalized().rotated(sws) * 2.5 * MapRule.spiral_speed(p.distance_to(vc))
					if n % 8 != 0 or not main.viewport_system.arena().has_point(p):
						continue
					var r := p.distance_to(vc)
					while bi + 2 < bm.size() and bm[bi + 1].distance_to(vc) > r:
						bi += 1
					var r0 := bm[bi].distance_to(vc)
					var t := clampf((r0 - r) / maxf(r0 - bm[bi + 1].distance_to(vc), 0.001), 0.0, 1.0)
					var am := (bm[bi] - vc).angle()
					am += angle_difference(am, (bm[bi + 1] - vc).angle()) * t
					var lo := lerpf(angle_difference(am, (band[1][bi] - vc).angle()), angle_difference(am, (band[1][bi + 1] - vc).angle()), t)
					var hi := lerpf(angle_difference(am, (band[2][bi] - vc).angle()), angle_difference(am, (band[2][bi + 1] - vc).angle()), t)
					var d := angle_difference(am, (p - vc).angle())
					sv_out = maxf(sv_out, maxf(lo - d, d - hi))
	Meta.map_id = "plain"
	main.wave = 10
	ok("UI-39", sv_out < 0.03, "소용돌이 구체가 진입 띠 밖으로 벗어난 가장 큰 각도 %.1f° (1.7° 미만)" % rad_to_deg(sv_out))
	ok("WAVE-06", main.resist_share(9) == 0.0 and main.resist_share(10) > 0.0 and main.sturdy_share(12) == 0.0 and main.sturdy_share(13) > 0.0, "저항 구체 10웨이브, 굳센 구체 13웨이브부터")

	var kinds := {}
	for w in [1, 3, 4, 7]:
		main.wave = w
		var s := {}
		for i in 400:
			s[main.spawning_system._roll_kind()] = true
		kinds[w] = s
	ok("WAVE-07", kinds[3].keys() == [Orb.Kind.NORMAL] and kinds[4].has(Orb.Kind.FAST) and not kinds[4].has(Orb.Kind.TANK) and kinds[7].has(Orb.Kind.TANK),
		"구체 종류: 빠른 4웨이브·단단한 7웨이브부터")

	# 보스: 5웨이브마다 마지막 구체, 쉬는 시간에 미리 정함
	main.wave = 4
	main.spawning_system._plan_boss()
	var planned: bool = main.boss_plan.get("wave", -1) == 5
	main.wave = 5
	main.to_spawn = 1
	main.spawn_timer = 0.0
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.combat_system._sim_step(1.0 / 60.0)
	var boss: Orb = null
	for o in main.orbs.get_children():
		if o.kind == Orb.Kind.BOSS:
			boss = o
	ok("WAVE-08", planned and boss != null and boss.core_dmg == 2, "5웨이브마다 마지막에 보스(중앙 2 피해), 앞 쉬는 시간에 미리 정함")
	_clear()
	main.wave_active = false
	main.phase = main.Phase.CHOOSE


## 미방어 길목은 참고 경고만. 단일 오브젝트 집중 투자도 진행할 수 있다.
func _wave_start_guard() -> void:
	_fresh(2)
	Rules.tune["auto_aim"] = 0.0  # 방향을 고정하는 경우의 경고 (자동 조준이면 사거리 안 길목은 막은 것으로 본다)
	main.mp_mode = ""
	main.lanes.assign([0.0, PI])
	main.waves_system.mark_new_angles([0.0])
	var t := _tower(main.viewport_system.center() + Vector2(120, 0), Elem.FIRE, 1, Vector2.RIGHT)
	var warns: bool = main.run_flow_system.lane_warning(0) == "" and main.run_flow_system.lane_warning(1) != ""
	var marked: bool = not main.waves_system.lane_is_new(0) and main.waves_system.lane_is_new(1)
	main.phase = main.Phase.READY
	main.mp_next_extra = 3
	main.run_flow_system._start_wave()
	var goes: bool = main.phase == main.Phase.WAVE and main.wave == 3 and main.mp_extra_left == 3
	main.mp_next_extra = 0
	main.mp_extra_left = 0
	main.wave_active = false
	_clear()
	main.mp_mode = "coop"
	main.mp_wave_go = true
	main.phase = main.Phase.READY
	main.run_flow_system._start_wave()
	var coop_go: bool = main.phase == main.Phase.WAVE and main.wave == 4
	main.mp_wave_go = false
	main.mp_mode = ""
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	ok("WAVE-14", warns and marked and goes and coop_go, "범위 밖 경고·새 방향 표시, 단일 오브젝트와 협동 모두 시작 허용")


# ---------- 구체·군중 제어 ----------

func _orbs_cc() -> void:
	_fresh()
	var o := _orb(main.viewport_system.center() + Vector2(300, 0), 10.0, Orb.Kind.NORMAL, 50.0)
	o.slow(0.05, 2.0)
	var floor_n := o.slow_factor
	var b := _orb(main.viewport_system.center() + Vector2(300, 50), 10.0, Orb.Kind.BOSS, 50.0)
	b.slow(0.05, 2.0)
	ok("CC-01", is_equal_approx(floor_n, Orb.SLOW_FLOOR) and is_equal_approx(b.slow_factor, 0.5), "감속은 최대 70%%, 보스 50%% (%.2f·%.2f)" % [floor_n, b.slow_factor])

	var durs := []
	for i in 4:
		o.root_timer = 0.0
		var hit := o.root(1.0)
		durs.append(o.root_timer if hit else -1.0)
	ok("CC-02", durs == [1.0, 0.5, 0.25, -1.0], "기절·속박·빙결: 100%%→50%%→25%% 뒤 면역 %s" % str(durs))

	var s := _orb(main.viewport_system.center() + Vector2(300, -50), 10.0, Orb.Kind.NORMAL, 50.0)
	s.sturdy = true
	s.root(1.0)
	ok("CC-03", is_equal_approx(s.root_timer, 0.5), "굳센 구체는 기절 시간 절반")

	var kb := _orb(main.viewport_system.center() + Vector2(-300, 0), 10.0, Orb.Kind.BOSS, 50.0)
	var k0 := kb.position
	kb.knock((kb.target - kb.position).normalized() * 100.0)  # 중앙 쪽
	var k_in := kb.position.distance_to(k0)
	kb.knock((kb.target - kb.position).normalized().orthogonal() * 100.0)  # 옆
	var k_side := kb.position.distance_to(k0)
	ok("CC-04", k_in < 0.01 and k_side <= Orb.BOSS_PUSH + 0.01 and k_side > 1.0, "밀쳐내기: 중앙 쪽 0, 옆은 밀림 여유까지 (보스 안쪽 %.1f · 옆 %.1f)" % [k_in, k_side])

	o.resist_e = Elem.FIRE
	ok("ORB-01", is_equal_approx(o.resist_mul({Elem.FIRE: 1}), 0.4) and is_equal_approx(o.resist_mul({Elem.FIRE: 1, Elem.WATER: 1}), 0.7) and o.resist_mul({Elem.WATER: 1}) == 1.0,
		"저항 구체: 그 속성 비중만큼 피해 최대 60% 감소")
	var sh := _orb(main.viewport_system.center() + Vector2(300, 80), 10.0)
	sh.shield = 3.0
	sh.hurt(5.0)
	ok("ORB-02", is_equal_approx(sh.hp, 8.0) and sh.shield == 0.0, "보호막이 피해를 먼저 흡수")
	_late_orbs()
	_late_curve()
	_jam_orbs()
	_skills()
	_ley_build()
	_clear()


# ---------- 점수·중앙 ----------

func _score_core() -> void:
	_fresh()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	var o := _orb(main.viewport_system.center() + Vector2(300, 0), 3.0)
	o.hp = 0.0
	main.combat_system._resolve(1.0 / 60.0)
	var first: int = main.score
	ok("SCORE-01", first == int(3.0 * 10 * 1.1) and main.combo == 1, "처치 점수 = 최대 체력x10 x 콤보 배율 (%d)" % first)
	var o2 := _orb(main.viewport_system.center() + Vector2(300, 40), 3.0)
	o2.hp = 0.0
	main.combat_system._resolve(1.0 / 60.0)
	ok("SCORE-02", main.combo == 2 and main.score - first == int(30 * 1.2), "3초 안 다음 처치는 콤보 +1, 처치마다 점수 +10%")
	main.combo = 25
	ok("SCORE-03", is_equal_approx(main.field_view_system.combo_mul(), 3.0), "콤보 20부터 x3")
	main.combo = 2
	main.combo_t = 0.01
	main.to_spawn = 5  # 웨이브가 끝나지 않게
	main.spawn_timer = 99.0
	main.combat_system._sim_step(0.1)
	var o3 := _orb(main.viewport_system.center() + Vector2(300, 80), 3.0)
	o3.hp = 0.0
	main.combat_system._resolve(1.0 / 60.0)
	ok("SCORE-04", main.combo == 1, "3초 넘게 처치가 없으면 콤보가 끊김")

	# 보스 처치: 중앙 +2, 새로고침 +1
	main.core_hp = 5
	main.bonus_rerolls = 0
	var bo := _orb(main.viewport_system.center() + Vector2(300, 0), 3.0, Orb.Kind.BOSS)
	bo.hp = 0.0
	main.combat_system._resolve(1.0 / 60.0)
	ok("BOSS-01", main.core_hp == 7 and main.bonus_rerolls == 1, "보스 처치: 중앙 체력 +2, 새로고침 +1")

	# 중앙에 닿으면 체력 -1(보스 -2), 누수 기록
	_clear()
	main.core_hp = 10
	main.wave_leaks.clear()
	_orb(main.viewport_system.center(), 5.0)
	main.combat_system._resolve(1.0 / 60.0)
	var after_n: int = main.core_hp
	_orb(main.viewport_system.center(), 5.0, Orb.Kind.BOSS)
	main.combat_system._resolve(1.0 / 60.0)
	ok("CORE-01", after_n == 9 and main.core_hp == 7 and main.wave_leaks.size() == 2, "구체가 중앙에 닿으면 -1, 보스 -2, 누수 기록")

	# 웨이브별 중앙 피해: 실드에 막힌 것도 닿은 수·피해엔 들어가고 깎인 체력엔 안 들어감, 판 기록(leaks)·이어하기 저장
	main.leak_log.clear()
	main.shield = 1
	# 웨이브 여유: 나온 체력 합·처치까지 시간·가장 가까운 처치 거리·걸린 시간
	main.wave_stat = {"hp": 0.0, "kn": 0, "life": 0.0, "close": -1.0, "peak": 4}
	main.wave_time = 12.34
	var so := _orb(main.viewport_system.center() + Vector2(120, 0), 7.0)
	so.shield = 3.0
	main.combat_system.stat_in(so)
	so.born = main.run_game - 2.0
	main.combat_system._stat_kill(so)
	so.queue_free()
	_orb(main.viewport_system.center(), 5.0, Orb.Kind.FAST)
	main.combat_system._resolve(1.0 / 60.0)
	main.combat_system._log_wave()
	var recs: Array = main.combat_system._leak_records()
	var lr: Dictionary = recs[-1] if recs.size() == 1 else {}
	var lk_ok: bool = lr.get("w") == main.wave and lr.get("n") == 3 and lr.get("dmg") == 4 and lr.get("lost") == 3 and lr.get("hp") == 7 \
		and lr.get("kinds") == {"normal": 1, "boss": 1, "fast": 1} and lr.get("kdmg", {}).get("boss") == 2 \
		and is_equal_approx(lr.get("secs", 0.0), 12.3) and lr.get("hp_in") == 10 and lr.get("close") == 120 and is_equal_approx(lr.get("life", 0.0), 2.0) \
		and lr.get("peak") == 4 and lr.get("t") == main.towers.get_child_count() and lr.has("dealt")
	main.phase = main.Phase.CHOOSE
	main.perk_mode = false
	main.persistence_system._save_run()
	main.leak_log.clear()
	main.persistence_system._continue_run()
	ok("ONLINE-05", lk_ok and JSON.stringify(main.combat_system._leak_records(), "", true) == JSON.stringify(recs, "", true), "웨이브별 중앙 피해(닿은 수·피해·깎인 체력·종류별)와 여유(걸린 시간·나온 체력·처치까지 시간·가장 가까운 처치·동시 최대·오브젝트 수·준 피해) → 판 기록 leaks, 이어하기 뒤에도 그대로")
	main.persistence_system._clear_run()
	main.shield = 0

	# 웨이브 클리어: 보너스 점수, 5웨이브마다 특성, 아니면 카드
	_clear()
	main.wave = 4
	main.to_spawn = 0
	main.score = 0
	main.perk_mode = false
	main.combat_system._sim_step(1.0 / 60.0)
	ok("WAVE-09", main.score == 4 * 20 and main.phase == main.Phase.CHOOSE and not main.perk_mode, "웨이브 클리어 +웨이브x20점, 다음 쉬는 시간은 카드 고르기")
	main.wave = 5
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.combat_system._sim_step(1.0 / 60.0)
	ok("PERK-01", main.perk_mode and main.perk_offer.size() == 3, "보스 웨이브(5의 배수)를 넘기면 특성 3개 중 고르기")
	main.perk_mode = false

	# 게임 오버
	_clear()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.core_hp = 1
	main.to_spawn = 5
	main.spawn_timer = 99.0
	_orb(main.viewport_system.center(), 5.0)
	main.combat_system._sim_step(1.0 / 60.0)
	ok("CORE-02", main.phase == main.Phase.GAMEOVER and main.over_label.visible and not FileAccess.file_exists(main.RUN_PATH), "중앙 체력 0이면 게임 오버, 이어하기 저장 지움")
	main.over_label.visible = false
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()


# ---------- 특성 ----------

func _perks() -> void:
	_fresh()
	var ids: Array = main.PERKS.map(func(p): return p["id"])
	ok("PERK-02", ids.size() == 15 and ids.has("quick") and ids.has("coin") and ids.has("shield") and ids.has("rampart") and ids.has("riposte") and ids.has("overflow"), "특성 15종 (%s)" % ",".join(ids))
	main.perks_system._apply_perk("power")
	main.perks_system._apply_perk("haste")
	main.perks_system._apply_perk("reach")
	main.perks_system._apply_perk("core")
	main.perks_system._apply_perk("slow")
	main.perks_system._apply_perk("harmony")
	main.perks_system._apply_perk("harmony")  # 동전 앞면·옛 저장처럼 두 번 와도 한 번만
	var h_ok := (is_equal_approx(Tower.tax_step, Rules.tax_step * 0.5) and is_equal_approx(Tower.tax_of(3), 1.0 + Rules.tax_step)
		and is_equal_approx(Tower.tax_of(9), (1.0 + Rules.tax_step * 8) / 1.2))
	main.perks["harmony"] = 1
	main.coin_next = ""
	h_ok = h_ok and not main.perks_system._perk_pool().any(func(pk): return pk["id"] == "harmony")
	main.perks.erase("harmony")
	ok("PERK-03", is_equal_approx(Tower.dmg_mul, 1.15) and is_equal_approx(Tower.spd_mul, 1.12) and is_equal_approx(Tower.reach_mul, 1.12)
		and main.core_max == 13 and main.core_hp == 13 and is_equal_approx(main.orb_speed_mul, 0.92) and h_ok,
		"특성 효과: 화력 +15%·속사 +12%·원거리 +12%·중앙 +3 회복·끈적 -8%·조화 대가 절반(한 번만, 공속 최대 +20%)")
	main.wave = 5
	main.rest_ready = false
	main.perks_system._start_perk()
	var heads := 0
	var tails := 0
	for i in 40:
		main.perk_mode = true
		main.coin_next = ""
		main.perks_system._on_perk(main.PERKS[9])
		if main.coin_next == "double":
			heads += 1
		elif main.coin_next == "reroll":
			tails += 1
	ok("PERK-04", heads > 0 and tails > 0 and heads + tails == 40 and not main.perk_offer.any(func(p): return p["id"] == "coin"),
		"운명의 동전: 앞면(두 번)·뒷면(새로고침) 중 하나, 다시 받는 특성에 동전 없음 (%d·%d)" % [heads, tails])
	main.perk_mode = true
	main.coin_next = "double"
	var pw := Tower.dmg_mul
	main.perks_system._on_perk(main.PERKS[0])
	var pw_n: int = main.perks.get("power", 0)
	ok("PERK-05", is_equal_approx(Tower.dmg_mul, pw + 0.3) and main.coin_next == "", "동전 앞면: 고른 특성이 두 번 적용")
	var keep_perks: Dictionary = main.perks.duplicate()
	main.perks = {"regen": 1}
	main.regen_acc = 0.0
	var r1 := [main.perks_system._regen_take(), main.perks_system._regen_take()]
	main.perks = {"regen": 2}
	var r2 := [main.perks_system._regen_take(), main.perks_system._regen_take()]
	main.perks = {"regen": 3}
	var r3 := [main.perks_system._regen_take(), main.perks_system._regen_take()]
	var big: String = main.perks_system._perk_big("regen", main.PERKS[6]["desc"]).get("big", "")
	main.perks = {}
	var big0: String = main.perks_system._perk_big("regen", main.PERKS[6]["desc"]).get("big", "")
	main.perks = keep_perks
	main.regen_acc = 0.0
	ok("PERK-07", r1 == [1, 1] and r2 == [1, 2] and r3 == [2, 2] and big0 == "+1/웨이브" and big == "+0.5/웨이브",
		"회복 겹치기: 1개 웨이브마다 +1, 2개 +1.5, 3개 +2, 카드 숫자 +1 → 이미 있으면 +0.5 (%s %s %s %s %s)" % [r1, r2, r3, big0, big])
	# 동전 연출: 공중 회전 → 누르면 떨어짐(안 누르면 1초 뒤) → 모서리 흔들림 → 결과, 그동안 카드·특성 고르기·저장 막음
	main.perks_system.coin_anim = true
	main.perk_mode = true
	main.perks_system._on_perk(main.PERKS[9])
	var st := [main.coin_stage, main.choice_box.visible]
	main.perks_system._on_perk(main.PERKS[0])  # 연출 중 특성 키는 먹지 않음
	var held: bool = main.coin_stage == 1 and main.perks.get("power", 0) == pw_n
	main.perks_system._coin_tap()
	var dropped: bool = main.coin_stage == 2
	for i in 200:
		if main.coin_stage == 0:
			break
		main.perks_system._coin_step(0.02)
	var auto_ok: bool = main.coin_stage == 0 and main.perk_mode and main.perk_offer.size() == 3 and not main.perk_offer.any(func(p): return p["id"] == "coin")
	main.perk_mode = true
	main.coin_next = ""
	main.perks_system._on_perk(main.PERKS[9])
	for i in 200:  # 안 누르고 두면 저절로 끝까지
		if main.coin_stage == 0:
			break
		main.perks_system._coin_step(0.02)
	ok("PERK-06", st[0] == 1 and not st[1] and held and dropped and auto_ok and main.coin_stage == 0 and main.coin_next in ["double", "reroll"],
		"동전 연출: 던지면 카드가 사라지고 회전, 누르면 떨어지고 결과 뒤 새 특성 3개 (누르지 않아도 끝남)")
	main.perks_system.coin_anim = false
	main.coin_next = ""
	main.perk_mode = false

	# 특성 새로고침: 특성 고를 때마다 1번, 다른 특성으로 3개, 카드 새로고침 수는 그대로
	main.rerolls_left = 2
	main.perks_system._start_perk()
	var pr0: int = main.perk_rerolls
	var before: Array = main.perk_offer.map(func(p): return p["id"])
	var shown: bool = main.reroll_btn.visible
	main.cards_system._on_reroll()
	var after: Array = main.perk_offer.map(func(p): return p["id"])
	var diff: bool = after.size() == 3 and not after.any(func(id): return id in before)
	var gone: bool = main.perk_rerolls == 0 and not main.reroll_btn.visible
	main.cards_system._on_reroll()  # 다 쓰면 그대로
	var same: bool = main.perk_offer.map(func(p): return p["id"]) == after
	main.perks_system._start_perk()  # 다음 특성 선택에는 다시 1번
	var pr1: int = main.perk_rerolls
	ok("PERK-12", pr0 == 1 and shown and diff and gone and same and pr1 == 1 and main.rerolls_left == 2 and main.perk_mode,
		"특성 새로고침: 선택마다 1번(%d·%d), 다른 특성 3개, 다 쓰면 버튼 숨김, 카드 새로고침 %d 그대로" % [pr0, pr1, main.rerolls_left])
	main.perk_mode = false


	_core_guard()


## 중앙 특성: 실드·성벽·반격 파동·넘친 회복
func _core_guard() -> void:
	_fresh()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.perks = {"shield": 5}
	var cap: int = main.perks_system._shield_wave()
	main.perks = {"shield": 1}
	main.shield = main.perks_system._shield_wave()
	_orb(main.viewport_system.center(), 5.0)
	main.combat_system._resolve(1.0 / 60.0)
	var hp1: int = main.core_hp
	var sh1: int = main.shield
	_orb(main.viewport_system.center(), 5.0)
	main.combat_system._resolve(1.0 / 60.0)
	ok("PERK-08", cap == 3 and hp1 == main.CORE_MAX_HP and sh1 == 0 and main.core_hp == main.CORE_MAX_HP - 1,
		"실드: 웨이브마다 1칸(겹치면 +1, 최대 3), 맞으면 체력 대신 실드가 깎임 (최대 %d, 막은 뒤 체력 %d, 다음 %d)" % [cap, hp1, main.core_hp])

	_fresh()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	var no_wall: bool = not main.perks_system._has_wall()
	var t := _tower(main.viewport_system.center() + Vector2(0, 200))
	t.set_pattern("wall")
	main.perks = {"rampart": 1}
	main.rampart_left = main.perks_system._rampart_n()
	var n0: int = main.rampart_left
	var o := _orb(main.viewport_system.center() + Vector2(main.RAMPART_R, 0), 5.0)
	main.combat_system._resolve(1.0 / 60.0)
	var pushed: bool = o.position.distance_to(main.viewport_system.center()) > main.RAMPART_R + 100.0 and o.walled
	o.position = main.viewport_system.center() + Vector2(main.RAMPART_R, 0)
	main.combat_system._resolve(1.0 / 60.0)  # 한 번 밀린 구체는 다시 막지 않음
	ok("PERK-09", no_wall and n0 == 2 and pushed and main.rampart_left == 1 and main.core_hp == main.CORE_MAX_HP,
		"성벽: 벽 오브젝트가 있어야 나옴, 조각 = 벽 레벨 합 + 1, 다가온 구체를 한 번 밀어내고 한 조각 부서짐 (조각 %d → %d)" % [n0, main.rampart_left])

	_fresh()
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.perks = {"riposte": 1}
	_orb(main.viewport_system.center(), 5.0)
	var far := _orb(main.viewport_system.center() + Vector2(100, 0), 1000000.0)
	main.combat_system._resolve(1.0 / 60.0)
	ok("PERK-10", far.hp < 1000000.0 and far.position.distance_to(main.viewport_system.center()) > 100.0 and main.core_hp == main.CORE_MAX_HP - 1,
		"반격 파동: 중앙이 맞으면 가까운 구체에 피해·밀어내기")

	_fresh()
	main.perks = {"overflow": 1}
	main.perks_system._heal_core(1)
	var k1: int = main.shield_keep
	main.perks_system._heal_core(5)
	var k2: int = main.shield_keep
	main.core_hp = main.CORE_MAX_HP - 1
	main.shield_keep = 0
	main.perks_system._heal_core(2)
	var part: Array = [main.core_hp, main.shield_keep]
	main.perks = {"overflow": 1, "shield": 3}
	main.shield_keep = 0
	main.perks_system._heal_core(3)
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
	main.menu_system._refresh_menu()
	var tap_txt: bool = main.menu_system.rules_label.text.contains("눌러서 바꾸기") and not main.menu_system.rules_label.text.contains("↑/↓")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	main.menu_system.rules_label.gui_input.emit(up)
	var r1: int = Meta.rules
	main.menu_system.rules_label.gui_input.emit(up)
	ok("RULE-04", main.menu_system.rules_label.get_meta("row").visible and tap_txt and r1 == 3 and Meta.rules == 1 and main.menu_system.rules_label.mouse_filter == Control.MOUSE_FILTER_STOP, "규칙 줄 글을 누르면 랭크 ↔ 도파민 모드, 터치 화면 안내 '눌러서 바꾸기'")
	main.touch_ui = false
	Meta.games = g0
	main.menu_system._refresh_menu()
	Rules.apply(5)
	var v5 := Rules.version
	Rules.apply(1)
	ok("RULE-02", v5 == 1, "모르는(폐기한) 규칙 버전은 1로")
	Rules._apply_patch({"max_mod": 7, "picks": "x", "nope": 3, "wind_buff": -1})
	var patched := Rules.max_mod == 7 and Rules.picks == 1 and Rules.t("wind_buff") == 0.0
	Rules.apply(1)
	ok("PATCH-01", patched and Rules.max_mod == 5, "온라인 패치 rules: 아는 키만 적용, 형식이 틀린 값·모르는 키 무시, 새 판에 원래대로")
	# 게임 코드 수치 (Rules.CODE): 레이저 피해를 패치로 올리면 실제 맞힌 피해가 오르고, 패치를 빼면 원래대로
	var lz := Tower.new()
	lz.main = main
	main.towers.add_child(lz)
	lz.add(Elem.LIGHT, 1)
	lz.pattern = "laser"
	var hz0: float = lz.hit_calc()["one"]
	Rules._apply_patch({"Tower.HIT.laser": 6.8, "Orb.KIND.boss_hp": "x", "Tower.HIT.nope": 1})
	var hz1: float = lz.hit_calc()["one"]
	Rules.apply(1)
	var hz2: float = lz.hit_calc()["one"]
	lz.free()
	ok("PATCH-03", is_equal_approx(hz1, hz0 * 2.0) and is_equal_approx(hz2, hz0) and is_equal_approx(Orb.KIND.boss_hp, 10.0),
		"게임 코드 수치 패치: Tower.HIT.laser 3.4 → 6.8이면 한 번 피해 %.2f → %.2f, 빼면 %.2f" % [hz0, hz1, hz2])

	Modes.set_on(["rush", "stroll", "bogus", "rush", "fort"])
	ok("MODE-01", Modes.on == ["rush", "fort"], "모드: 모르는 것·중복·반대 쌍 뒤쪽은 버림 %s" % str(Modes.on))
	ok("MODE-02", Modes.easy() and Meta.run_key().ends_with(Meta.EASY_TAG), "쉽게 모드가 하나라도 있으면 기록 따로")
	Modes.set_on(["rush", "swarm", "steel", "glass", "narrow", "early", "angry"])
	ok("MODE-03", is_equal_approx(Modes.mul(), Modes.MUL_MAX) and not Modes.easy(), "점수 배율은 곱, %.1f배에서 멈춤" % Modes.MUL_MAX)
	Modes.set_on(["three", "ease"])
	main.run_flow_system._apply_rules()
	ok("MODE-04", Rules.picks == 2 and Modes.rerolls(1) == 3, "두 장: 고르기 2장, 여유: 새로고침 +2")
	Modes.set_on([])
	main.run_flow_system._apply_rules()
	main.menu_system._toggle_mode("stroll")
	var shown: bool = main.menu_system.easy_notice.visible
	main.menu_system.easy_notice_skip.button_pressed = true
	main.menu_system._close_easy_notice()
	main.menu_system._toggle_mode("stroll")
	main.menu_system._toggle_mode("stroll")
	ok("MODE-05", shown and not main.menu_system.easy_notice.visible and main.menu_system._easy_notice_off(), "쉽게 모드를 켜면 안내, 다시 보지 않기면 안 뜸")
	Modes.set_on([])
	main.run_flow_system._apply_rules()


# ---------- 판마다 다른 흐름 ----------

func _vary() -> void:
	_fresh(5)
	var off_after_rules := not Vary.on
	Modes.set_on([])
	Vary.new_run(true)
	var no_mode_no_seal: bool = Vary.on and Vary.count() == 0 and not Vary.seal_on
	Modes.set_on(["seal"])
	Vary.new_run(true)
	var mode_ok: bool = Vary.seal_on and Modes.mul() > 1.0 and not Modes.easy()
	ok("VARY-06", no_mode_no_seal and mode_ok, "봉인은 모드: 안 켜면 봉인 없음(흐름은 켜짐), 켜면 봉인·어렵게 점수 배율")
	var counts_ok: bool = Vary.sealed["elem"].size() == 3 and Vary.sealed["pat"].size() == 4 and Vary.sealed["link"].size() == 1
	var c: Vector2 = main.viewport_system.center()
	_tower(c + Vector2(-200, 0))
	_tower(c + Vector2(200, 0))
	_tower(c + Vector2(0, -200))
	var leak := 0
	for i in 400:
		main.cards_system._make_choices()
		for cd in main.offer:
			if cd["type"] == "elem" and Vary.is_sealed("elem", cd["e"]) or cd["type"] in ["pat", "link"] and Vary.is_sealed(cd["type"], cd["id"]):
				leak += 1
	var n0 := Vary.count()
	Vary.rest(25)
	var sv := Vary.save()
	var sealed_e: Array = Vary.sealed["elem"].duplicate()
	Vary.load_from(JSON.parse_string(JSON.stringify(sv)))
	var keep: bool = Vary.seal_on and Vary.sealed["elem"] == sealed_e
	Modes.set_on([])
	ok("VARY-01", off_after_rules and counts_ok and keep and leak == 0 and Vary.count() == n0 - 1, "봉인: 속성 3·공격방식 4·연계 1, 선택지에 안 나옴(새어 나옴 %d), 25웨이브에 하나 풀림" % leak)

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
	var shell: bool = main.spawning_system._roll_orb(15)["sturdy"]
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
	ok("VARY-04", Vary.on and got == want,  # 내용 비교 (JSON을 거치면 사전 키 순서가 바뀌어 str 비교는 판마다 흔들렸다)
		"이어하기: 봉인·예고 이벤트·적응 저항이 저장 후 그대로")
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
	ok("VARY-05", tut_off and patch_off and Vary.tower_mul({Elem.SOUL: 1}, "wisp") == 1.0, "첫 판·멀티플레이는 끔, 패치 vary_on 0이면 끔")


# ---------- 맵 규칙 ----------

func _map_on(id: String) -> void:
	_fresh(5)
	Meta.map_id = id
	Rules.tune["map_on"] = 1.0
	main.lanes.clear()
	main.waves_system._roll_lanes()


func _maps() -> void:
	var c: Vector2 = main.viewport_system.center()
	# 친화 카드: 회랑 얼음·물·독이 더 자주, 피해 +15%(속성 레벨 몫·공격방식)
	_map_on("line")
	_tower(c + Vector2(-200, 0))
	_tower(c + Vector2(200, 0))
	# Sampling must not depend on RNG consumed by earlier UI/sound timing.
	seed(7)
	var cnt := {}
	for i in 1500:
		main.cards_system._make_choices()
		for cd in main.offer:
			if cd["type"] == "elem":
				cnt[cd["e"]] = cnt.get(cd["e"], 0) + 1
	var aff := 0.0
	var other := 0.0
	for e in Elem.ALL:
		if e in MapRule.aff("elem"):
			aff += cnt.get(e, 0) / 3.0
		else:
			other += cnt.get(e, 0) / float(Elem.ALL.size() - 4)  # 친화 3개·별 빼고 (속성 수가 늘어도 맞게)
	var k := 1.0 + Rules.t("map_aff_dmg")
	var mul_ok := is_equal_approx(MapRule.tower_mul({Elem.ICE: 2}, "lob"), k * k) and is_equal_approx(MapRule.tower_mul({Elem.ICE: 1, Elem.FIRE: 1}, "shot"), 1.0 + Rules.t("map_aff_dmg") / 2.0) and MapRule.tower_mul({Elem.FIRE: 1}, "wisp") == 1.0
	ok("MAPX-01", aff > other * 1.25 and mul_ok and MapRule.card_aff({"type": "mod", "id": "size"}) and MapRule.aff_text() != "", "친화 카드: 더 자주(장당 %.0f vs %.0f), 피해 +15%%(속성 레벨 몫·공격방식)" % [aff, other])
	Vary.new_run(true)
	var sealed_aff: bool = Vary.sealed["elem"].any(func(e): return e in MapRule.aff("elem")) or Vary.sealed["pat"].any(func(p): return p in MapRule.aff("pat"))
	ok("MAPX-07", not sealed_aff, "친화 카드는 봉인되지 않음")
	Vary.new_run(false)

	# 평원: 무리 보너스 x2, 공명 거리 +30%
	_map_on("plain")
	ok("MAPX-02", MapRule.crowd_k() == Rules.t("map_crowd") and is_equal_approx(MapRule.reso_k(), 1.0 + Rules.t("map_reso")), "평원: 무리 보너스 x%s, 공명 거리 x%.1f" % [MapRule.crowd_k(), MapRule.reso_k()])

	# 소용돌이: 1~5웨이브 한 방향, 6~10 반대. 중앙 1.4배·바깥 0.8배
	_map_on("spiral")
	main.wave = 6
	main.spawning_system._spawn_orb(Orb.Kind.NORMAL)
	var o: Orb = main.orbs.get_child(main.orbs.get_child_count() - 1)
	var flip_ok: bool = MapRule.swirl_sign(5) == 1.0 and MapRule.swirl_sign(6) == -1.0 and MapRule.swirl_sign(11) == 1.0 and o.swirl < 0.0
	var spd_ok := is_equal_approx(MapRule.spiral_speed(60.0), Rules.t("map_spiral_in")) and is_equal_approx(MapRule.spiral_speed(900.0), Rules.t("map_spiral_out"))
	ok("MAPX-03", flip_ok and spd_ok, "소용돌이: 보스 웨이브 뒤 회전 반전, 중앙 가까울수록 빠름")

	# 진입 시간 맞추기: 평원·소용돌이에서 좌우·상하·모서리 구체가 곧바로 전장에 들어오고 중앙까지 걸리는 시간이 같다
	var lane_ok := true
	var lane_txt := ""
	for mid in ["plain", "spiral"]:
		_map_on(mid)
		main.wave = 1
		var ins: Array = []
		var arr: Array = []
		var base: Dictionary = main.spawning_system._roll_orb(1)
		for a in [0.0, PI / 2.0, atan2(360.0, 640.0), PI, PI * 1.5]:
			var plan: Dictionary = base.duplicate()
			plan["a"] = a
			main.spawning_system._spawn_orb(Orb.Kind.NORMAL, plan)
			var lo: Orb = main.orbs.get_child(main.orbs.get_child_count() - 1)
			var t_in := -1.0
			var t := 0.0
			while lo.position.distance_to(main.viewport_system.center()) > 20.0 and t < 120.0:
				lo.step(0.02)
				t += 0.02
				if t_in < 0.0 and main.viewport_system.arena().grow(lo.radius()).has_point(lo.position):
					t_in = t
			ins.append(t_in)
			arr.append(t)
		var lo_t: float = arr.min()
		var hi_t: float = arr.max()
		lane_ok = lane_ok and ins.max() < 1.5 and hi_t / lo_t < 1.04
		lane_txt += " %s 들어옴 %.1f초 이내, 도착 %.1f~%.1f초" % [mid, ins.max(), lo_t, hi_t]
	ok("WAVE-13", lane_ok, "진입 시간 맞추기:" + lane_txt)

	# 십자로: 길 위에서 길 따라 겨누면 피해 +25%, 길 밖·가로로 겨누면 그대로
	_map_on("cross")
	var u := Vector2.from_angle(main.lanes[0])
	var on_t := _tower(c + u * 200.0, Elem.FIRE, 1, u)
	var cross_t := _tower(c + u * 330.0, Elem.FIRE, 1, u.orthogonal())
	var off_t := _tower(c + u.rotated(PI / 4) * 200.0, Elem.FIRE, 1, u)
	var ratio: float = on_t.dmg_factor() / cross_t.dmg_factor()
	ok("MAPX-04", on_t.on_lane() and not cross_t.on_lane() and not off_t.on_lane() and is_equal_approx(ratio, 1.0 + Rules.t("map_cross_dmg")), "십자로: 길목에서 길 따라 겨눈 오브젝트 피해 x%.2f" % ratio)

	# 폭풍: 진입 방향으로 정해지는 바람, 순풍 탄 +30% / 역풍 -15%
	_map_on("storm")
	var w := MapRule.wind_dir(main.lanes)
	var same := MapRule.wind_dir(main.lanes.duplicate()) == w
	var wt := _tower(c + Vector2(-150, 60), Elem.FIRE, 1, w)
	var pr := Projectile.new()
	pr.setup("shot", wt, 1, w)
	var fast := is_equal_approx(pr.vel.length(), 440.0 * (1.0 + Rules.t("map_wind_with")))
	pr.free()
	ok("MAPX-05", w != Vector2.ZERO and same and fast and is_equal_approx(MapRule.wind_k(-w, w), 1.0 - Rules.t("map_wind_against")), "폭풍: 바람 방향(진입 방향으로 정해짐), 순풍 탄 빠름·역풍 느림")

	# 회랑: 지나간 자리 장판 x2, 감속·밀치기 +30%
	_map_on("line")
	var lt := _tower(c + Vector2(-150, 0), Elem.POISON)
	var z: Zone = main.spawning_system.spawn_zone("trail", 1, lt.position, lt)
	z.trail("puddle")
	var life_ok := is_equal_approx(z.max_life, Tower.LOB_LIFE * Rules.t("map_line_trail"))
	var so := _orb(c + Vector2(300, 0), 50.0)
	so.slow(0.8, 1.0)
	var slow_ok := is_equal_approx(so.slow_factor, 1.0 - 0.2 * (1.0 + Rules.t("map_line_cc")))
	ok("MAPX-06", life_ok and slow_ok, "회랑: 지나간 자리 장판 x%s, 감속 +30%%" % Rules.t("map_line_trail"))

	# 끄기: 패치 map_on 0
	Rules.tune["map_on"] = 0.0
	ok("MAPX-08", not MapRule.on() and MapRule.crowd_k() == 1.0 and MapRule.tower_mul({Elem.ICE: 1}, "lob") == 1.0, "패치 map_on 0이면 맵 규칙·친화 끔")
	_fresh(5)
	var map0: String = Meta.map_id
	var mo: float = Rules.tune["map_on"]
	Rules.tune["map_on"] = 1.0
	var n_ok: bool = main.menu_system.map_cards.size() == Meta.MAP_IDS.size()
	main.menu_system.map_cards[2].pressed.emit()
	var picked: bool = Meta.map_id == Meta.MAP_IDS[2]
	var sub_t: String = (main.menu_system.map_label.get_meta("sub") as Label).text.replace("\u2060", "")  # _kr_keep 줄바꿈 방지 문자
	var aff_shown: bool = sub_t.contains("친화") and sub_t.contains(Elem.NAMES[MapRule.aff("elem")[0]])
	Meta.map_id = map0
	Rules.tune["map_on"] = mo
	main.menu_system._refresh_menu()
	ok("MAPX-09", n_ok and picked and aff_shown, "준비 화면 맵 카드: 맵마다 한 장, 누르면 그 맵, 아래 설명에 친화 카드")


# ---------- 결과 상세 ----------

func _result_detail() -> void:
	# 처치는 마지막으로 맞힌 오브젝트 몫: 실제 전투 경로에서 쓰러뜨린 구체가 그 오브젝트 처치로
	_fresh(3)
	var c: Vector2 = main.viewport_system.center()
	var a := _tower(c + Vector2(-100, 0), Elem.FIRE, 2, Vector2.RIGHT)
	var b := _tower(c + Vector2(100, 120), Elem.WATER, 1, Vector2.DOWN)
	a.set_pattern("spray")
	var vo := _orb(a.position + Vector2.RIGHT * 100.0, 0.1)
	for i in 30:
		main.combat_system._resolve(1.0 / 60.0)
	var killed: bool = a.wave_kills >= 1 and b.wave_kills == 0
	# 웨이브가 끝나면 [웨이브, 피해, 처치, 초]로 남기고 이번 웨이브 처치는 비운다 (같은 웨이브는 한 번만)
	a.dealt = 400.0
	a.wave_kills = 3
	b.dealt = 100.0
	main.wave = 3
	main.wave_time = 20.0
	main.combat_system._log_wave()
	main.combat_system._log_wave()
	var logged: bool = a.hist == [[3, 400, 3, 20.0]] and a.wave_kills == 0 and b.hist.size() == 1
	var saved: Dictionary = a.to_save()
	var a2 := _tower(c + Vector2(-100, -150), Elem.FIRE)
	a2.load_save(JSON.parse_string(JSON.stringify(saved)))
	var kept: bool = a2.hist.size() == 1 and int(a2.hist[0][1]) == 400 and int(a2.hist[0][2]) == 3
	a2.free()
	ok("RES-01", killed and logged and kept, "처치는 마지막으로 맞힌 오브젝트 몫, 웨이브마다 피해·처치·시간 기록, 이어하기에 저장")
	# 결과 화면: 위 정보 줄·설정 버튼 줄은 숨기고 [결과 상세]로 오브젝트별 표·웨이브 그래프
	a.run_dealt = 0.0
	b.run_dealt = 0.0
	a.dealt = 0.0
	b.dealt = 0.0
	a.hist = [[1, 100, 1, 10.0], [2, 300, 2, 10.0]]
	b.hist = [[2, 900, 4, 10.0]]
	a.run_dealt = 400.0
	b.run_dealt = 900.0
	main.score = 100
	main.core_hp = 0
	main.wave = 2
	main.phase = main.Phase.CHOOSE
	main.run_flow_system._game_over()
	main.over_card.queue_redraw()
	await process_frame
	await process_frame
	var hidden: bool = not main.hud.visible and not main.bar_btn.visible and not main.pause_btn.visible and not main.mute_btn.visible
	var btn: bool = main.over_detail_btn.visible
	main.over_detail_btn.pressed.emit()
	var rd: RunDetail = main.run_detail
	var rows: Array = rd.rows
	var table: bool = rd.visible and rows.size() == 3 and rows[0]["name"] == "전체" and rows[1]["dealt"] == 900.0 and rows[2]["kills"] == 3 \
		and is_equal_approx(RunDetail.avg_dps(rows[2]["hist"]), 20.0) and rows[0]["hist"].size() == 2 and int(rows[0]["hist"][1][1]) == 1200 and int(rows[0]["hist"][1][2]) == 6
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	main.over_ms = Time.get_ticks_msec() - 2000
	main.interaction_system._unhandled_input(ev)
	var esc: bool = not rd.visible and main.phase == main.Phase.GAMEOVER
	ok("RES-02", hidden and btn and table and esc, "결과 화면: 위 정보 줄·설정 숨김, [결과 상세] 오브젝트별 피해 몫·처치·평균 DPS·웨이브 그래프, Esc로 닫기")
	_detail_reset()


func _detail_reset() -> void:
	main.run_detail.close()
	main.run_flow_system.over_data = {}
	main.over_card.visible = false
	main.over_label.visible = false
	main.over_detail_btn.visible = false
	main.phase = main.Phase.CHOOSE
	main.persistence_system._clear_run()
	_clear()


# ---------- 이어하기 ----------

func _save_load() -> void:
	_fresh(7)
	var c: Vector2 = main.viewport_system.center()
	var a := _tower(c + Vector2(-200, 30), Elem.FIRE, 2, Vector2.UP)
	a.add(Elem.WOOD, 1)
	a.set_pattern("spray")
	a.add_mod("size")
	a.add_trig("echo")
	var b := _tower(c + Vector2(180, -40), Elem.ICE)
	b.add_link("pincer")
	main.score = 1234
	main.core_hp = 6
	main.rerolls_left = 2
	main.perks = {"power": 1}
	main.phase = main.Phase.CHOOSE
	main.perk_mode = false
	main.offer = [{"type": "elem", "e": Elem.SOUL, "lv": 1}, {"type": "mod", "id": "rapid"}, {"type": "trig", "id": "vanguard"}]
	main.persistence_system._save_run()
	var want: Array = main.towers.get_children().map(func(t): return JSON.stringify(t.to_save()))
	_clear()
	main.score = 0
	main.wave = 0
	main.core_hp = 10
	main.persistence_system._continue_run()
	var got: Array = main.towers.get_children().map(func(t): return JSON.stringify(t.to_save()))
	ok("SAVE-01", FileAccess.file_exists(main.RUN_PATH) and got == want and main.wave == 7 and main.score == 1234 and main.core_hp == 6 and main.rerolls_left == 2 and main.perks == {"power": 1},
		"쉬는 시간 저장 → 이어하기: 오브젝트·웨이브·점수·중앙·새로고침·특성 그대로")
	ok("SAVE-02", main.offer.size() == 3 and main.offer[2].get("id") == "vanguard", "이어하기는 저장한 선택지 그대로")

	var cfg := ConfigFile.new()
	cfg.load(main.RUN_PATH)
	cfg.set_value("run", "version", "0.0.1")
	cfg.save(main.RUN_PATH)
	var old_minor: bool = main.persistence_system._old_run_version() == "0.0.1"
	var vp := Net.game_version().split(".")
	cfg.set_value("run", "version", "%s.%s.999" % [vp[0], vp[1] if vp.size() > 1 else "0"])
	cfg.save(main.RUN_PATH)
	ok("SAVE-03", old_minor and main.persistence_system._old_run_version() == "" and not Net.same_minor("0.6.0", "0.7.0") and Net.same_minor("0.6.0", "0.6.3"),
		"마이너 버전(x.Y)이 바뀐 저장은 지난 판으로 알아봄 (이어 하지 않고 끝냄), 패치만 바뀐 판은 이어 함")
	cfg.set_value("run", "map", "nowhere")
	cfg.save(main.RUN_PATH)
	ok("SAVE-04", main.persistence_system._run_info().is_empty(), "모르는 맵 등 깨진 저장은 이어하기 버튼을 띄우지 않음")
	cfg.set_value("run", "map", "plain")
	cfg.set_value("run", "rules", 5)
	cfg.save(main.RUN_PATH)
	ok("SAVE-05", main.persistence_system._run_info().get("rules", 0) == 1, "폐기한 규칙(2·4·5)으로 저장된 판은 랭크로 이어 함")
	main.persistence_system._clear_run()
	_clear()


# ---------- 카드 들기와 독립 카메라 ----------
func _carry_cards() -> void:
	_fresh(12)
	main.auto_start = false
	main.shake = 0.0
	Meta.card_detail = false
	main.cards_hidden = false
	var target := _tower(Vector2(420, 520), Elem.WATER)
	var bad := _tower(Vector2(860, 520), Elem.WATER)
	bad.set_pattern("thorn")
	var card := {"type": "mod", "id": "pierce"}
	main.offer = [card, {"type":"elem", "e":Elem.FIRE, "lv":1}, {"type":"elem", "e":Elem.WOOD, "lv":1}]
	main.picks_left = 2
	main.cards_system._show_offer()
	main.cards_system._open_choose()
	main.frame_system._process(0.0)
	var offers: Array = main.offer.duplicate(true)
	var xform: Transform2D = main.get_canvas_transform()
	var scale0 := Meta.ui_scale
	Meta.ui_scale = 1.3
	main.hud_system._apply_ui_scale()
	main.frame_system._process(0.0)
	var scale_independent: bool = xform.is_equal_approx(main.get_canvas_transform())
	main.viewport_system._zoom_to(1.4, main.get_viewport_rect().size / 2)
	var zoomed: Transform2D = main.get_canvas_transform()
	main.touch_ui = true
	main.cards_system._on_card_tap(card, 0)
	main.frame_system._process(0.0)
	var held: bool = main.phase == main.Phase.PLACE and main.card_dock.carrying() and not main.card_dock.panel.visible and not main.card_dock.side.visible and not main.choice_box.visible
	var independent: bool = zoomed.is_equal_approx(main.get_canvas_transform()) and is_equal_approx(main.view_zoom, 1.4)
	var before: int = main.picks_left
	main.interaction_system._drop_carried_card(Vector2(-100, -100))
	main.interaction_system._drop_carried_card(main.get_canvas_transform() * bad.position)
	var refused: bool = main.picks_left == before and bad.m("pierce") == 0 and main.phase == main.Phase.PLACE
	main.interaction_system._drop_carried_card(main.cancel_btn.get_global_rect().get_center())
	refused = refused and main.picks_left == before
	main.interaction_system._cancel_step()
	main.frame_system._process(0.0)
	var cancel: bool = main.offer == offers and main.picks_left == before and main.phase == main.Phase.CHOOSE and main.choice_box.visible and main.tap_sel == 0 and zoomed.is_equal_approx(main.get_canvas_transform())
	main.cards_system._on_card_tap(offers[1], 1)
	main.frame_system._process(0.0)
	var chip: bool = main.card_dock.carrying() and not main.ui_root.has_node("CarriedCard")
	main.interaction_system._cancel_step()
	main.cards_system._on_card_tap(card, 0)
	main.interaction_system._drop_carried_card(main.get_canvas_transform() * target.position)
	var applied: bool = target.m("pierce") == 1 and main.picks_left == before - 1
	# 들고 있는 동안 앱을 닫아도 마지막 선택 목록과 남은 장수로 복원한다.
	main.offer = offers.duplicate(true)
	main.cards_system._show_offer()
	main.cards_system._open_choose()
	main.cards_system._on_card_tap(card, 0)
	_clear()
	main.persistence_system._continue_run()
	var resume: bool = main.phase == main.Phase.CHOOSE and main.offer == offers and main.picks_left == before - 1
	main.viewport_system._reset_zoom()
	Meta.ui_scale = scale0
	main.hud_system._apply_ui_scale()
	main.touch_ui = false
	ok("UI-31", held and chip and independent and scale_independent and refused and cancel and applied and resume,
		"카드 들기: 카드 이름 말풍선 없음 %s·목록 접힘 %s·카메라 독립 %s·글자 배율 독립 %s·무효 드롭 보존 %s·취소 복원 %s·1회 적용 %s·이어하기 %s" % [chip, held, independent, scale_independent, refused, cancel, applied, resume])


# ---------- 보조 공격 ----------

func _side() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	var _grid := func():
		main.combat_system.targets = main.orbs.get_children()
		main.combat_system._build_grid()
	var base: float = Rules.t("side_iv")
	var t := _tower(c + Vector2(-300, 0), Elem.FIRE, 1)
	var one := Side.iv(t)
	t.add(Elem.WATER, 1)
	t.eff = t.eff_now()
	var two := Side.iv(t)
	ok("SIDE-01", base > 0.0 and is_equal_approx(one, base) and is_equal_approx(two, base / 2.0),
		"보조 공격 간격 = %s초 ÷ 속성 종류 수 (1종 %.2f초, 2종 %.2f초)" % [base, one, two])
	_clear()
	# 조준(오른쪽) 밖, 위쪽 150에 있는 구체를 친다. 효과(화상)가 실린다.
	var ft := _tower(c + Vector2(-300, 0), Elem.FIRE, 3, Vector2.RIGHT)
	var far := _orb(ft.position + Vector2(0, -250), 1e6)
	var near := _orb(ft.position + Vector2(0, -150), 1e6)
	_grid.call()
	ft.side_cd = 0.0
	ft.side_n = 0
	main.side_big_t = 0.0
	Side.tick(ft, 0.01)
	var hit_near: bool = near.hp < 1e6 and far.hp >= 1e6 and near.burn_t > 0.0
	var credited: bool = float(ft.src.get("share:side", 0.0)) > 0.0
	var reset: bool = is_equal_approx(ft.side_cd, Side.iv(ft))
	ok("SIDE-02", hit_near and credited and reset and main.src_name("share:side") == "보조 공격" and main.src_name("share:side_big") == "큰 보조 공격",
		"보조 공격: 조준과 상관없이 둘레 가장 가까운 구체 하나, 효과 실림·피해 출처 보조 공격 (맞힘 %s·출처 %s·간격 %s)" % [hit_near, credited, reset])
	_clear()
	# 큰 보조 공격: side_big_n번째는 여러 구체를 맞힌다
	var bt := _tower(c + Vector2(-300, 0), Elem.FIRE, 3, Vector2.RIGHT)
	var group: Array = []
	for i in 4:
		group.append(_orb(bt.position + Vector2(-40 + i * 30, -150), 1e6))
	_grid.call()
	bt.side_cd = 0.0
	bt.side_n = int(Rules.t("side_big_n")) - 1
	main.side_big_t = 0.0
	Side.tick(bt, 0.01)
	var all_hit := true
	for o in group:
		all_hit = all_hit and o.hp < 1e6
	var big_src: bool = float(bt.src.get("share:side_big", 0.0)) > 0.0
	var locked: bool = main.side_big_t > 0.0 and bt.side_n == 0
	ok("SIDE-03", all_hit and big_src and locked,
		"큰 보조 공격: %d번째 보조 공격은 여러 구체를 함께 맞힘 (전부 맞음 %s·출처 %s·차례 초기화 %s)" % [int(Rules.t("side_big_n")), all_hit, big_src, locked])
	# 화면에 큰 보조 공격이 이미 있으면 다른 오브젝트는 보통 보조 공격, 차례는 남김
	var ot := _tower(c + Vector2(-300, 60), Elem.WATER, 3, Vector2.RIGHT)
	var hp0: Array = group.map(func(o): return o.hp)
	ot.side_cd = 0.0
	ot.side_n = int(Rules.t("side_big_n")) - 1
	Side.tick(ot, 0.01)
	var n_hit := 0
	for i in group.size():
		if group[i].hp < hp0[i]:
			n_hit += 1
	var waits: bool = n_hit == 1 and ot.side_n == int(Rules.t("side_big_n")) - 1 and float(ot.src.get("share:side_big", 0.0)) == 0.0
	ok("SIDE-04", waits, "큰 보조 공격은 화면에 하나씩: 다른 오브젝트는 보통 보조 공격, 차례는 다음으로 미룸 (맞은 수 %d)" % n_hit)
	main.side_big_t = 0.0
	_clear()


# ---------- 섞인 보조 공격 ----------

func _side_mix() -> void:
	_fresh()
	var c: Vector2 = main.viewport_system.center()
	var _grid := func():
		main.combat_system.targets = main.orbs.get_children()
		main.live_orbs = main.orbs.get_children()
		main.combat_system._build_grid()
	var mk := func(els: Array, pos := Vector2(-300, 0)) -> Tower:
		var t: Tower = _tower(c + pos, els[0][0], els[0][1], Vector2.RIGHT)
		for i in range(1, els.size()):
			t.add(els[i][0], els[i][1])
		t.eff = t.eff_now()
		t.side_cd = 0.0
		t.side_n = 0
		return t
	var fire := func(t: Tower) -> void:
		main.side_big_t = 0.0
		t.side_cd = 0.0
		Side.tick(t, 0.01)
	var hurt_n := func(arr: Array) -> int:
		return arr.filter(func(o): return is_instance_valid(o) and o.hp < 1e6).size()
	# SIDE-05 모양 고르기
	var a: Tower = mk.call([[Elem.FIRE, 3], [Elem.WOOD, 1]])
	var b: Tower = mk.call([[Elem.FIRE, 1], [Elem.WATER, 1]], Vector2(-300, 100))
	var n0: Tower = mk.call([[Elem.WOOD, 2], [Elem.EARTH, 2]], Vector2(-300, 200))
	var one: Tower = mk.call([[Elem.FIRE, 3]], Vector2(-300, -100))
	ok("SIDE-05", Side.shape_e(a) == Elem.FIRE and Side.mix_name(a) == "불덩이" and Side.shape_e(b) == Elem.FIRE and Side.shape_e(n0) == -1 and Side.mix_name(n0) == "휩쓸기" and Side.mix_name(one) == "" and not Side.mixed(one) and Side.mix_desc(a) != "",
		"섞인 보조 공격 모양: 불3+나무1 %s, 불1+물1(먼저 넣은 불) %s, 나무+땅 %s, 불 하나 '%s'" % [Side.mix_name(a), Side.mix_name(b), Side.mix_name(n0), Side.mix_name(one)])
	_clear()
	# SIDE-06 여러 대상
	var et: Tower = mk.call([[Elem.ELECTRIC, 2], [Elem.METAL, 1]])
	var chain: Array = []
	for i in 4:
		chain.append(_orb(et.position + Vector2(0, -120 - i * 100), 1e6))
	_grid.call()
	fire.call(et)
	var elec_ok: bool = hurt_n.call(chain) == 3 and chain[3].hp >= 1e6
	_clear()
	var st: Tower = mk.call([[Elem.SOUND, 2], [Elem.WOOD, 1]])
	var ring: Array = []
	for i in 4:
		ring.append(_orb(st.position + Vector2.from_angle(i * 1.3) * (120 + i * 30), 1e6))
	_grid.call()
	fire.call(st)
	var sound_ok: bool = hurt_n.call(ring) == 3
	_clear()
	var bt: Tower = mk.call([[Elem.BLOOD, 2], [Elem.WOOD, 1]])
	var bl: Array = []
	for i in 3:
		bl.append(_orb(bt.position + Vector2(100 + i * 60, -100), 1e6))
	_grid.call()
	fire.call(bt)
	var hp1: float = bl[1].hp
	bl[0].hurt(100.0)
	var blood_ok: bool = bl[0].link_t > 0.0 and absf((hp1 - bl[1].hp) - 30.0) < 0.5
	_clear()
	var so: Tower = mk.call([[Elem.SOUL, 2], [Elem.WOOD, 1]])
	for i in 3:
		_orb(so.position + Vector2(150, -80 + i * 80), 1e6)
	_grid.call()
	fire.call(so)
	var ghosts := 0
	for p in main.projectiles.get_children():
		if p.kind == "ghost" and p.src == "share:side":
			ghosts += 1
	_clear()
	var it: Tower = mk.call([[Elem.ILLUSION, 2], [Elem.WOOD, 1]])
	var it2: Tower = _tower(it.position + Vector2(150, 100), Elem.FIRE, 1)
	var near_me := _orb(it.position + Vector2(-100, -50), 1e6)
	var near_it2 := _orb(it2.position + Vector2(250, 100), 1e6)  # 내 둘레 300 밖, 옆 오브젝트 둘레 안
	_grid.call()
	fire.call(it)
	var illu_ok: bool = near_me.hp < 1e6 and near_it2.hp < 1e6
	_clear()
	ok("SIDE-06", elec_ok and sound_ok and blood_ok and ghosts == 3 and illu_ok,
		"여러 대상: 번개 3마리 %s · 메아리 3마리 %s · 핏줄 30%% 나눔 %s · 혼불 %d개 · 분신 옆 오브젝트 자리 %s" % [elec_ok, sound_ok, blood_ok, ghosts, illu_ok])
	# SIDE-07 장판 던지기: 묻힌 구체가 지나간 길에만
	var wt: Tower = mk.call([[Elem.WATER, 2], [Elem.FIRE, 1]])
	var lead := _orb(wt.position + Vector2(150, 0), 1e6, Orb.Kind.NORMAL, 60.0)
	var back := _orb(wt.position + Vector2(-900, 0), 1e6)
	_grid.call()
	fire.call(wt)
	var smeared: bool = lead.smear_t > 0.0 and lead.smear_e == Elem.WATER
	for i in 60:
		lead.step(1.0 / 60.0)
	var sz: Zone = null
	for z in main.zones.get_children():
		if z.kind == "smear":
			sz = z
	var self_ok := true
	var near_tower := true
	if sz:
		lead.slow_timer = 0.0
		sz.affect([lead], 0.1)
		self_ok = lead.slow_timer == 0.0
		for q in sz.pts:
			near_tower = near_tower and q.distance_to(wt.position) > 100.0
		back.position = sz.pts[sz.pts.size() - 1]
		sz.affect([back], 0.1)
	var step_ok: bool = sz != null and back.hp < 1e6 and back.slow_timer > 0.0 and back.burn_t > 0.0
	_clear()
	var pt: Tower = mk.call([[Elem.POISON, 2], [Elem.WOOD, 1]])
	var dier := _orb(pt.position + Vector2(150, 0), 1e6)
	var nb := _orb(pt.position + Vector2(190, 0), 1e6)
	_grid.call()
	fire.call(pt)
	nb.poison_t = 0.0
	dier.hp = 0.0
	main.combat_system._death_effects(dier)
	var burst_ok: bool = nb.poison_t > 0.0
	_clear()
	ok("SIDE-07", smeared and step_ok and self_ok and near_tower and burst_ok and Zone.ORB_PATH.has("smear"),
		"장판 던지기: 묻힘 %s, 지나간 길 장판을 밟은 구체 피해·감속·화상 %s, 묻은 구체는 안 밟음 %s, 오브젝트 곁 장판 없음 %s, 독병 죽으면 둘레 중독 %s" % [smeared, step_ok, self_ok, near_tower, burst_ok])
	# SIDE-08 맵 전체
	var dt: Tower = mk.call([[Elem.DARK, 2], [Elem.WOOD, 1]])
	var close := _orb(dt.position + Vector2(150, 0), 1e6)
	var big := _orb(dt.position + Vector2(700, 100), 5e6)
	var pulled := _orb(big.position + Vector2(60, 0), 1e6)
	_grid.call()
	var px: float = pulled.position.x
	fire.call(dt)
	var dark_ok: bool = big.hp < 5e6 and close.hp >= 1e6 and pulled.position.x < px
	_clear()
	var sr: Tower = mk.call([[Elem.STAR, 2], [Elem.WOOD, 1]])
	var lone := _orb(sr.position + Vector2(150, 0), 1e6)
	var pack: Array = []
	for i in 4:
		pack.append(_orb(sr.position + Vector2(600 + i * 15, 150), 1e6))
	_grid.call()
	fire.call(sr)
	var star_ok: bool = hurt_n.call(pack) == 4 and lone.hp >= 1e6
	_clear()
	var lt: Tower = mk.call([[Elem.LIGHT, 2], [Elem.WOOD, 1]])
	var first := _orb(lt.position + Vector2(150, 0), 1e6)
	var far1 := _orb(lt.position + Vector2(700, 0), 1e6)
	var off := _orb(lt.position + Vector2(400, 120), 1e6)
	_grid.call()
	fire.call(lt)
	var light_ok: bool = first.hp < 1e6 and far1.hp < 1e6 and off.hp >= 1e6
	_clear()
	ok("SIDE-08", dark_ok and star_ok and light_ok, "맵 전체: 그림자 낙하 체력 많은 먼 구체·끌어당김 %s · 유성 몰린 곳 %s · 빛줄기 화면 끝까지 %s" % [dark_ok, star_ok, light_ok])
	# SIDE-09 휩쓸기·시간
	var wd: Tower = mk.call([[Elem.WOOD, 2], [Elem.EARTH, 2]])
	var s1 := _orb(wd.position + Vector2(150, 0), 1e6)
	var s2 := _orb(wd.position + Vector2(200, 30), 1e6)
	var s3 := _orb(wd.position + Vector2(150, 200), 1e6)
	_grid.call()
	fire.call(wd)
	var sweep_ok: bool = s1.hp < 1e6 and s2.hp < 1e6 and s3.hp >= 1e6
	_clear()
	var tt: Tower = mk.call([[Elem.SOUND, 2], [Elem.TIME, 1]])
	var to := _orb(tt.position + Vector2(150, 0), 1e6)
	_grid.call()
	fire.call(tt)
	var h1: float = to.hp
	tt.later = tt.later.map(func(x): return [0.0, x[1]])
	tt._share_tick(0.01)
	var again: bool = to.hp < h1
	_clear()
	ok("SIDE-09", sweep_ok and again, "휩쓸기 둘레 80 %s · 시간 0.8초 뒤 한 번 더 %s" % [sweep_ok, again])
	# SIDE-10 특별 칸
	var ld: Tower = mk.call([[Elem.DARK, 2], [Elem.LIGHT, 1]])
	var faraway := _orb(ld.position + Vector2(900, -150), 1e6)
	var nearby := _orb(ld.position + Vector2(150, 0), 1e7)  # 그림자 낙하는 이 구체로 (체력 가장 많음), 먼 구체는 작은 일식만
	_grid.call()
	for i in Side.MINI_ECLIPSE_N:
		fire.call(ld)
	var eclipse_ok: bool = Side.has_sp(ld, "eclipse") and nearby.hp < 1e7 and faraway.hp < 1e6 and ld.side_mix_n == 0
	_clear()
	var we: Tower = mk.call([[Elem.WATER, 2], [Elem.ELECTRIC, 1]])
	var ew: Tower = mk.call([[Elem.ELECTRIC, 2], [Elem.WATER, 1]], Vector2(-300, 150))
	var shock_ok: bool = Side.has_sp(we, "shock") and not Side.has_sp(ew, "shock")
	_clear()
	var fw: Tower = mk.call([[Elem.FIRE, 2], [Elem.WIND, 1]])
	var wh: Array = []
	for i in 3:
		wh.append(_orb(fw.position + Vector2(150 + i * 100, 0), 1e6))
	_grid.call()
	fire.call(fw)
	var wheel_ok: bool = wh.all(func(o): return o.smear_t > 0.0)
	_clear()
	var pd: Tower = mk.call([[Elem.POISON, 2], [Elem.DARK, 1]])
	var cd := _orb(pd.position + Vector2(150, 0), 1e6)
	var cn := _orb(pd.position + Vector2(210, 0), 1e6)
	_grid.call()
	fire.call(pd)
	var cx: float = cn.position.x
	cd.hp = 0.0
	Side.on_death(cd)
	var curse_ok: bool = Side.has_sp(pd, "curse") and cn.position.x < cx
	_clear()
	var sd: Tower = mk.call([[Elem.SOUL, 2], [Elem.DARK, 1]])
	_orb(sd.position + Vector2(150, 0), 1e6)
	var heavy := _orb(sd.position + Vector2(900, 0), 9e6)
	_grid.call()
	fire.call(sd)
	var doom_ok := false
	for p in main.projectiles.get_children():
		if p.kind == "ghost" and p.position.distance_to(heavy.position) < 100.0:
			doom_ok = true
	_clear()
	var sl: Tower = mk.call([[Elem.STAR, 2], [Elem.LIGHT, 1]])
	var pk1: Array = []
	var pk2: Array = []
	_orb(sl.position + Vector2(150, 0), 1e6)
	for i in 3:
		pk1.append(_orb(sl.position + Vector2(500 + i * 15, -150), 1e6))
		pk2.append(_orb(sl.position + Vector2(500 + i * 15, 200), 1e6))
	_grid.call()
	fire.call(sl)
	var shower_ok: bool = hurt_n.call(pk1) > 0 and hurt_n.call(pk2) > 0
	_clear()
	ok("SIDE-10", eclipse_ok and shock_ok and wheel_ok and curse_ok and doom_ok and shower_ok,
		"특별 칸: 일식 %s · 감전 물폭탄(물 모양만) %s · 불바퀴 3마리 %s · 저주병 %s · 저승길 %s · 유성우 %s" % [eclipse_ok, shock_ok, wheel_ok, curse_ok, doom_ok, shower_ok])
	# SIDE-11 큰 판
	var bs: Tower = mk.call([[Elem.SOUND, 2], [Elem.WOOD, 1]])
	var many: Array = []
	for i in 8:
		many.append(_orb(bs.position + Vector2.from_angle(i * 0.7) * (100 + i * 20), 1e6))
	_grid.call()
	bs.side_n = int(Rules.t("side_big_n")) - 1
	fire.call(bs)
	var big_ok: bool = hurt_n.call(many) == 8 and main.side_big_t > 0.0 and bs.side_n == 0
	_clear()
	var bw: Tower = mk.call([[Elem.WATER, 2], [Elem.WOOD, 1]])
	var bw_o: Array = []
	for i in 4:
		bw_o.append(_orb(bw.position + Vector2(120 + i * 40, 0), 1e6))
	_grid.call()
	bw.side_n = int(Rules.t("side_big_n")) - 1
	fire.call(bw)
	var throw_big: int = bw_o.filter(func(o): return o.smear_t > 0.0).size()
	main.side_big_t = 0.0
	_clear()
	ok("SIDE-11", big_ok and throw_big == Side.BIG_THROW_N, "섞인 큰 보조 공격: 메아리 큰 판 8마리 모두 %s · 물폭탄 %d마리에 묻힘" % [big_ok, throw_big])
	_clear()
	# SIDE-12 처음 맞힌 구체 최소 피해 (보통 보조 공격)
	var fl: Tower = mk.call([[Elem.FIRE, 2], [Elem.WOOD, 1]])
	var fo: Orb = _orb(fl.position + Vector2(120, 0), 1e6)
	_grid.call()
	fl.side_n = 0
	var want: float = Tower.pw(fl.plv) * Rules.t("side_dmg") * Rules.t("side_mix_floor") * fl.dmg_k_bare() * fo.resist_mul(Side._els(fl))
	fire.call(fl)
	var took: float = 1e6 - fo.hp
	ok("SIDE-12", Rules.t("side_mix_floor") > 0.0 and took >= want * 0.99, "섞인 보조 공격 처음 맞힌 구체: %.1f 받음 (최소 %.1f)" % [took, want])


# ---------- 기록·도감·화면 글 ----------

func _meta_misc() -> void:
	var pointer_before: Vector2 = main.interaction_system._pointer_screen()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(123, 234)
	main.interaction_system._input(motion)
	var cached: bool = main.interaction_system._pointer_screen() == motion.position
	var transformed: bool = (main.get_canvas_transform() * main.interaction_system._pointer_world()).is_equal_approx(motion.position)
	main.interaction_system.pointer_position = pointer_before
	ok("UI-34", cached and transformed, "입력 이벤트의 포인터 좌표 보존·현재 카메라 변환으로 전장 좌표 계산")
	var tools_safe := true
	for file in DirAccess.get_files_at("res://tools"):
		if not file.ends_with(".gd"): continue
		var source := FileAccess.get_file_as_string("res://tools/" + file)
		tools_safe = tools_safe and not source.contains("warp_" + "mouse(") and not source.contains("window_move_to_" + "foreground(")
		if file != "virtual_input.gd":
			tools_safe = tools_safe and not source.contains("Input." + "parse_input_event(")
	ok("UI-34", tools_safe, "자동화 도구의 OS 커서·포커스 제어 금지, 입력 주입은 공용 Viewport 경로만 사용")
	Meta.codex.erase("spec_x")
	ok("META-01", Meta.discover("spec_x") and not Meta.discover("spec_x"), "반응 도감: 처음 발견할 때만 새로 추가")
	Meta.codex.erase("spec_x")
	Meta.achieved.erase("first")
	ok("META-02", Meta.achieve("first") and not Meta.achieve("first"), "업적: 한 번만 달성")
	var skins_ok := Meta.TOWER_SKIN_IDS.all(func(s): return Meta.TOWER_SKINS[s]["need"] == "" or Meta.ACHIEVEMENTS.has(Meta.TOWER_SKINS[s]["need"]))
	ok("META-03", skins_ok and Meta.unlocked(""), "모양 해금 조건은 모두 있는 업적")
	ok("META-04", Meta.key("plain", 1) != Meta.key("plain", 3) and Meta.key("plain", 1, true) == "plain", "최고 기록은 맵·규칙마다 따로, 예전 규칙 기록은 옛 키로")

	ok("UI-01", main.run_flow_system._ver_text().contains(str(ProjectSettings.get_setting("application/config/version"))), "구석 버전 표시 = project.godot 버전 (%s)" % main.run_flow_system._ver_text())
	main.touch_ui = true
	var t: String = main.ui_layout_system._kh("새로고침 (Q)")
	var h: String = main.run_flow_system._help_text()
	main.touch_ui = false
	ok("UI-02", not t.contains("(Q)") and h.contains("[조작 · 터치]"), "터치 화면은 키 안내를 빼고 터치용 도움말")

	# 일반 판은 마우스·터치 모두 한 번 눌러 든다. 대상 확정 전에는 선택 횟수를 쓰지 않는다.
	_fresh(3)
	main.phase = main.Phase.CHOOSE
	main.offer = [{"type": "elem", "e": Elem.WATER, "lv": 1}, {"type": "elem", "e": Elem.FIRE, "lv": 1}]
	main.picks_left = 2
	main.cards_system._show_offer()
	main.touch_ui = true
	main.cards_system._on_card_tap(main.offer[0], 0)
	var tap1: bool = main.phase == main.Phase.PLACE and main.picked == main.offer[0] and main.picks_left == 2
	main.interaction_system._cancel_step()
	var tap2: bool = main.phase == main.Phase.CHOOSE and main.offer.size() == 2
	main.cards_system._on_card_tap(main.offer[1], 1)
	var tap3: bool = main.phase == main.Phase.PLACE and main.picked.get("e", -1) == Elem.FIRE
	main.interaction_system._cancel_step()
	main.touch_ui = false
	main.cards_system._on_card_tap(main.offer[0], 0)
	var mouse1: bool = main.phase == main.Phase.PLACE and main.picks_left == 2
	ok("UI-14", tap1 and tap2 and tap3 and mouse1, "카드 한 번 눌러 들기: PC·터치 동일, 취소하면 같은 목록, 적용 전 횟수 보존")
	main.interaction_system._back_to_choose()

	# 그린 궤적은 없어짐: 공격방식 목록·카드에 없고, 예전 저장의 궤적 오브젝트는 직선탄으로 레벨 그대로
	_fresh(3)
	var old_path := Tower.new()
	old_path.load_save({"elements": {Elem.FIRE: 2}, "order": [Elem.FIRE], "pattern": "path", "plv": 4, "mods": {"pierce": 1}, "paths": [[Vector2.ZERO, Vector2(100, 0)]]})
	var migrated := old_path.pattern == Pat.DEFAULT and old_path.plv == 4 and old_path.m("pierce") == 1 and not old_path.to_save().has("paths")
	old_path.free()
	var no_card := true
	for i in 3000:
		var cd: Dictionary = main.cards_system._roll_card()
		no_card = no_card and not (cd["type"] == "pat" and cd["id"] == "path")
	ok("PATH-03", migrated and no_card and not Pat.ALL_IDS.has("path") and not Pat.PATTERNS.has("path"), "그린 궤적 없음: 카드 안 나옴·예전 저장은 직선탄 Lv 유지 (저장 %s, 카드 %s)" % [migrated, no_card])

	# 전장 확대: 두 손가락 벌리기로 확대, 그동안 누르기는 게임에 안 넘어감, 다 떼면 풀림. [확대 풀기]로 1배
	_fresh(3)
	main.phase = main.Phase.CHOOSE
	var t0 := InputEventScreenTouch.new(); t0.index = 0; t0.pressed = true; t0.position = Vector2(600, 360)
	var t1 := InputEventScreenTouch.new(); t1.index = 1; t1.pressed = true; t1.position = Vector2(700, 360)
	main.interaction_system._zoom_input(t0)
	var lock1: bool = main.interaction_system._zoom_input(t1)
	var dr := InputEventScreenDrag.new(); dr.index = 1; dr.position = Vector2(800, 360)
	main.interaction_system._zoom_input(dr)
	var zin: bool = main.view_zoom > 1.5 and main.viewport_system.view_rect().size.x < main.get_viewport_rect().size.x
	t1.pressed = false; t0.pressed = false
	main.interaction_system._zoom_input(t1)
	var last: bool = main.interaction_system._zoom_input(t0)
	var unlocked: bool = not main.interaction_system.pinch_lock and last
	main.viewport_system._reset_zoom()
	ok("UI-18", lock1 and zin and unlocked and is_equal_approx(main.view_zoom, 1.0) and main.viewport_system.arena().size == Meta.FIELD, "두 손가락 벌리기 = 전장 확대(x%.1f), 확대 중 누르기는 게임에 안 넘어감, [확대 풀기] = 1배, 전장 크기 그대로" % main.view_zoom)

	main.viewport_system._zoom_to(0.1, Vector2(100, 100))
	main.frame_system._process(0.0)
	var zoom_min: bool = is_equal_approx(main.view_zoom, 0.5) and main.view_pan.is_zero_approx() and main.zoom_btn.visible
	main.viewport_system._zoom_to(9.0, Vector2(100, 100))
	var zoom_max: bool = is_equal_approx(main.view_zoom, 2.5)
	main.viewport_system._reset_zoom()
	ok("UI-18", zoom_min and zoom_max and is_equal_approx(main.view_zoom, 1.0), "0.5~2.5배 제한·축소 중앙 정렬·복귀 버튼")

	# 글 대신 그림: 카드는 버튼 글 없이 그림 머리(속성 카드는 속성 그림·Lv 배지), 짝 속성 줄·숫자 특성은 그림 + 숫자,
	# 시작 화면·일시정지는 그림 버튼(이름은 말풍선), 오른쪽 설명 앞줄마다 그림
	_fresh(3)
	_tower(main.viewport_system.center() + Vector2(-200, 0))
	var ec: Button = main.cards_system._card_button({"type": "elem", "e": Elem.WATER, "lv": 2}, 1)
	var em: Array = ec.get_meta("card")
	var has_els: bool = em[1].any(func(l): return l[0].has("els"))
	var pc: Button = main.cards_system._card_button({"type": "trig", "id": "echo"}, 2)
	var big: Dictionary = main.perks_system._perk_big("haste", main.perks_system._perk_desc(main.PERKS[1]))
	var glyph_btns: bool = main.title_box.find_children("*", "Button", true, false).filter(func(b): return b.text == "" and b.tooltip_text in ["도감 (K)", "설정 (O)"]).size() == 2
	var pause_ok: bool = main.pause_box.get_child_count() >= 6 and main.pause_box.get_children().all(func(b): return b.text == "")
	ok("UI-19", ec.text == "" and em[0].get("e", -1) == Elem.WATER and em[0].get("lv", "") == "Lv2" and has_els and pc.text == "" and big.get("big", "") == "+12%" and big.get("i", "") == "rate" \
		and glyph_btns and pause_ok and main.menu_system.legend_heads.size() == main.LEGEND_ICONS.size() and not main.run_flow_system._pause_text().contains("Esc:"),
		"글 대신 그림: 카드 그림 머리·짝 속성 그림, 특성 그림+숫자, 시작 화면·일시정지 그림 버튼, 설명 앞줄 그림")
	ec.free()
	pc.free()

	# 시작 화면: 첫 화면은 큰 타일(일반 판·멀티, 정원 없음) + 그림 버튼 줄(PC는 종료), [일반 판] → 준비 화면(맵·규칙·모드·시작), 모양은 설정 창
	var home0: bool = main.menu_system.home_box.visible and not main.menu_system.prep_box.visible
	var tiles_ok: bool = not "garden_btn" in main and main.menu_system.home_box.is_ancestor_of(main.mp_btn) and not main.menu_system.home_box.is_ancestor_of(main.menu_system.map_label)
	main.menu_system._set_prep(true)
	var prep1: bool = main.menu_system.prep_box.visible and not main.menu_system.home_box.visible and main.menu_system.prep_box.is_ancestor_of(main.menu_system.map_label) and main.menu_system.prep_box.is_ancestor_of(main.new_btn) and main.menu_system.prep_box.is_ancestor_of(main.modes_btn)
	main.menu_system._set_prep(false)
	var skins_set: bool = main.settings_panel.is_ancestor_of(main.menu_system.skin_label) and main.settings_panel.is_ancestor_of(main.menu_system.core_label)
	var quit_btn: bool = main.menu_system.home_box.find_children("*", "Button", true, false).any(func(b): return b.tooltip_text == "게임 종료") == OS.has_feature("pc")
	ok("UI-21", home0 and tiles_ok and prep1 and main.menu_system.home_box.visible and skins_set and quit_btn, "첫 화면 %s·타일 %s, 준비 화면 %s, 모양은 설정 %s, 종료(PC만) %s" % [home0, tiles_ok, prep1, skins_set, quit_btn])

	# 기본 설명은 효과 문장이고, 자세히와 반응·레벨업 정보는 남는다. 첫 판에 한정하지 않는다.
	var was_d := Meta.card_detail
	Meta.card_detail = false
	var full: Array = main.cards_system._card_full({"type": "elem", "e": Elem.WATER, "lv": 1})
	var basic_ok := true
	var wave_before: int = main.wave
	for w in [0, 12, 50]:
		main.wave = w
		for e in Elem.ALL:
			var basic: Dictionary = main.cards_system._card_content({"type": "elem", "e": e, "lv": 1}, 0)
			var text: String = basic["rows"][0].get("t", "")
			basic_ok = basic_ok and text.length() >= 10 and not basic["rows"][0].has("pair") and not text.contains("효과 ·") and not text.contains("특징 ·")
	main.wave = wave_before
	var ice: String = main.cards_system._card_content({"type": "elem", "e": Elem.ICE, "lv": 1}, 0)["rows"][0]["t"]
	var earth: String = main.cards_system._card_content({"type": "elem", "e": Elem.EARTH, "lv": 1}, 0)["rows"][0]["t"]
	var star: String = main.cards_system._card_content({"type": "elem", "e": Elem.STAR, "lv": 1}, 0)["rows"][0]["t"]
	var conditions: bool = ice.contains("쌓아") and earth.contains("확률") and star.contains("복사") and star.contains("다 차면")
	var s0: Dictionary = main.cards_system._card_content({"type": "elem", "e": Elem.WATER, "lv": 1}, 0)
	var combo_ok: bool = s0["rows"].any(func(r): return r.has("els"))
	var multi: Dictionary = main.cards_system._card_content({"type": "mod", "id": "multi"}, 0)
	var finish: Dictionary = main.cards_system._card_content({"type": "trig", "id": "finish"}, 0)
	var reso: Dictionary = main.cards_system._card_content({"type": "link", "id": "reso"}, 0)
	conditions = conditions and multi["rows"][0]["t"].contains("피해는 줄어") and multi["rows"][0]["t"].contains("벽·블랙홀·투척 장판") and finish["rows"][0]["t"].contains("보스") and reso["rows"][0]["t"].contains("거리")
	var detail: Dictionary = main.cards_system._card_content({"type": "mod", "id": "multi"}, 1)
	var full_ok: bool = full.any(func(l): return str(l[0]).begins_with("조합 ")) and full.any(func(l): return str(l[0]).begins_with("특징")) and detail["rows"][0]["t"].contains("(")
	main.cards_system._set_card_detail(true)
	var on_ok: bool = Meta.card_detail and main.card_detail_btn.button_pressed
	Meta.card_detail = false
	var plain_card: Button = main.cards_system._card_button({"type":"elem", "e":Elem.WATER, "lv":1}, 1)
	var no_floating_tip := plain_card.tooltip_text == ""
	var dock_brief: bool = main.card_dock.summary_text(plain_card).contains(Elem.BRIEF[Elem.WATER])
	plain_card.free()
	main.cards_system._set_card_detail(was_d)
	# 공유 원문뿐 아니라 카드별 별도 설명·도감으로 가는 전체 문장도 검사한다. 수치 라벨은 허용한다.
	var copy_texts: Array[String] = []
	for e in Elem.ALL:
		copy_texts.append_array([Elem.BRIEF[e], Elem.rider(e), Elem.TRAIT[e]])
	for defs in [Pat.PATTERNS, Pat.MODS, Pat.LINKS, Pat.TRIGS]:
		for id in defs:
			copy_texts.append(Rules.fmt(defs[id]["desc"]))
	for kind in Pat.BRIEF:
		for id in Pat.BRIEF[kind]:
			copy_texts.append(Pat.brief(kind, id, ""))
	for pk in main.PERKS:
		copy_texts.append(pk["desc"])
	for rule in Elem.AFF_RULES:
		copy_texts.append(rule[5])
	copy_texts.append(Elem.SAME_AFF[3])
	for kind in ["pat", "mod", "link", "trig"]:
		var defs: Dictionary = {"pat": Pat.PATTERNS, "mod": Pat.MODS, "link": Pat.LINKS, "trig": Pat.TRIGS}[kind]
		for id in defs:
			var card := {"type": kind, "id": id}
			for lvl in [0, 1]:
				for row in main.cards_system._card_content(card, lvl)["rows"]:
					copy_texts.append(row.get("t", ""))
			for row in main.cards_system._card_full(card):
				copy_texts.append(row[0])
	var old_ending := RegEx.create_from_string("(한다|된다|쏜다|뿜는다|세운다|튄다|민다|갈라진다|막는다|남는다|훑는다|건다|줄어듦|세짐|느려짐|쫓음|받음|못 넣음|넣을 수 없음)([. ,)\\n]|$)")
	var copy_ok := copy_texts.all(func(text): return old_ending.search(text) == null)
	ok("UI-20", copy_ok, "카드·특성·도감 공유 원문과 요약·상세: 해요체, 수치 라벨 허용 (%d줄)" % copy_texts.size())
	var unit_text := "12개까지 1.5초 40%를"
	var kept_units := PatchNotes.kr_keep(unit_text)
	ok("UI-20", kept_units.contains("2\u2060개") and kept_units.contains("5\u2060초") and kept_units.contains("0\u2060%\u2060를") and kept_units.replace("\u2060", "") == unit_text and PatchNotes.kr_keep(kept_units) == kept_units and PatchNotes.kr_keep("[bgcolor=#4a2422][font_size=12] 고침 [/font_size][/bgcolor]") == "[bgcolor=#4a2422][font_size=12] 고\u2060침 [/font_size][/bgcolor]", "숫자·단위 줄바꿈 방지: 원문 보존·중복 적용 안전·BBCode 태그(색·크기 숫자)는 그대로")
	ok("UI-20", basic_ok and conditions and combo_ok and full_ok and on_ok and no_floating_tip and dock_brief, "카드 기본 효과: 15속성·0/12/50웨이브 %s, 조건 %s, 반응 그림 %s, 자세히 보존 %s" % [basic_ok, conditions, combo_ok, full_ok])

	# 카드 선택 막: 선택지가 펼쳐져 있으면 검은 막(카드·카드 줄 버튼은 그 위), 필드 보기·카드를 고르면 곧바로 걷힘
	_fresh(3)
	var dt := _tower(main.viewport_system.center() + Vector2(-200, 0))
	main.run_flow_system._start_choose()
	main.frame_system._process(0.016)
	var dim_on: bool = not main.card_dim.visible and main.card_dock.panel.visible
	main.picks_left = 2
	main.frame_system._process(0.016)
	var head_two: bool = main.choice_header.visible and main.choice_remaining.text == "2장 더 선택 가능" and main.choice_header.z_index > main.card_dim.z_index
	var bottom_controls: bool = is_equal_approx(main.bar_box.position.y - main.card_dock.footer.position.y, 12) and is_equal_approx(main.ui_root.size.y - main.bar_box.get_rect().end.y, 12)
	var detail_icon: Vector2 = main.cards_system._button_icon_center(main.card_detail_btn)
	var icon_fits: bool = Rect2(Vector2.ZERO, main.card_detail_btn.size).grow(-8).encloses(Rect2(detail_icon - Vector2(9, 9), Vector2(18, 18)))

	main.picks_left = 1
	main.frame_system._process(0.016)
	var head_one: bool = main.choice_remaining.text == "1장 더 선택 가능"
	for card_node in main.choice_box.get_children():
		if card_node.is_queued_for_deletion():
			main.choice_box.remove_child(card_node)
	main.touch_ui = true
	main.tap_sel = 1
	main.frame_system._process(0.016)
	var no_apply: bool = not main.apply_btn.visible
	main.tap_sel = -1
	main.touch_ui = false
	main.perk_mode = true
	main.frame_system._process(0.016)
	var head_perk: bool = not main.choice_header.visible
	main.perk_mode = false
	main.cards_system._set_cards_hidden(true)
	main.frame_system._process(0.016)
	var dim_hide: bool = not main.card_dim.visible
	var head_hide: bool = not main.choice_header.visible
	var fold_offer: Array = main.offer.duplicate(true)
	var fold_left: int = main.picks_left
	var fold_ok := true
	main.cards_system._set_cards_hidden(false)
	main.frame_system._process(0.0)
	fold_ok = main.hide_btn == main.card_dock.focus_btn and main.card_dock.focus_btn.visible and main.card_dock.focus_btn.text == "카드 접기"
	for i in 3:
		main.card_dock.focus_btn.pressed.emit()
		main.frame_system._process(0.0)
		fold_ok = fold_ok and main.cards_hidden and not main.card_dock.panel.visible and not main.card_dock.side.visible and main.card_dock.focus_btn.text == "카드 보기"
		main.card_dock.focus_btn.pressed.emit()
		main.frame_system._process(0.0)
		fold_ok = fold_ok and main.card_dock.panel.visible and main.offer == fold_offer and main.picks_left == fold_left
	main.cards_system._set_cards_hidden(true)
	main.frame_system._process(0.0)
	fold_ok = fold_ok and main.card_dock.focus_btn.text == "카드 보기"
	main.card_dock.focus_btn.pressed.emit()
	main.frame_system._process(0.0)
	fold_ok = fold_ok and not main.cards_hidden and main.card_dock.panel.visible
	var toggles := true
	var same_offer: Array = main.offer.duplicate(true)
	for i in 4:
		main.cards_system._set_cards_hidden(false)
		main.frame_system._process(0.0)
		toggles = toggles and main.card_dock.panel.visible and not main.cards_hidden
		main.cards_system._set_cards_hidden(true)
		main.frame_system._process(0.0)
		toggles = toggles and not main.card_dock.panel.visible and main.hide_btn.visible and main.offer == same_offer
	main.cards_system._set_cards_hidden(false)
	main.cards_system._on_pick({"type": "mod", "id": "pierce"})
	main.frame_system._process(0.016)
	var dim_off: bool = not main.card_dim.visible and main.phase == main.Phase.PLACE
	ok("UI-23", fold_ok and toggles and dim_on and dim_hide and dim_off, "일반 판 카드 선택 시 전장 어둠 없음 %s, 필드 보기 %s·카드 고른 뒤 %s 유지" % [dim_on, dim_hide, dim_off])
	var controls: bool = main.speed_btn.get_parent() == main.speed_group and main.speed_pick.get_parent() == main.speed_group and main.speed_group.get_theme_constant("separation") == 0 and main.card_detail_btn.theme == main.bar_box.theme and main.speed_pick.get_theme_stylebox("normal").bg_color == main.reroll_btn.get_theme_stylebox("normal").bg_color and main.fx_pick.get_popup().get_theme_stylebox("panel") is StyleBoxFlat
	ok("UI-30", controls and bottom_controls and icon_fits and head_two and head_one and no_apply and head_perk and head_hide and not main.choice_header.visible,
		"카드 줄 선택 안내: 갱신 %s·%s, 중간 적용 버튼 없음 %s, 숨김 %s·%s·%s" % [head_two, head_one, no_apply, head_perk, head_hide, not main.choice_header.visible])



	main.shake = 0.0
	main.frame_system._process(0.0)
	main.frame_system._process(0.0)
	var transform: Transform2D = main.get_canvas_transform()
	var stable := true
	for stage in [main.Phase.AIM, main.Phase.READY, main.Phase.CHOOSE]:
		main.phase = stage
		main.frame_system._process(0.0)
		stable = stable and main.get_canvas_transform().is_equal_approx(transform)
	var board: Rect2 = main.card_dock.screen_board()
	ok("UI-28", stable and main.viewport_system.arena().size == Meta.FIELD and board.grow(1).encloses(main.get_canvas_transform() * main.viewport_system.arena())
		and board.size.is_equal_approx(main.get_viewport_rect().size), "패널과 독립된 전체 화면 전장: 단계 전환에서 카메라 고정·논리 전장 유지")
	var saved_tips: Array = main.tip_rects.duplicate()
	var saved_pin: int = main.tip_pin
	var info_point: Vector2 = main.get_canvas_transform() * main.viewport_system.center()
	var info_at: Vector2 = main.ui_root.get_global_transform().affine_inverse() * info_point
	main.tip_rects.clear()
	main.tip_rects.append([Rect2(info_at - Vector2(10, 10), Vector2(20, 20)), [["정보", Color.WHITE]]])
	var info_touch := InputEventScreenTouch.new()
	info_touch.position = info_point
	info_touch.pressed = true
	var captured_info: bool = main.interaction_system._info_input(info_touch) and main.interaction_system.info_touch_capture == 0 and main.card_dock.over_ui(info_point)
	info_touch.pressed = false
	var released_info: bool = main.interaction_system._info_input(info_touch) and main.interaction_system.info_touch_capture == -1
	main.tip_rects = saved_tips
	main.tip_pin = saved_pin
	ok("UI-28", captured_info and released_info, "그려진 정보 요소도 터치 누름·뗌을 소비해 전장으로 통과하지 않음")
	var preview := {"type": "elem", "e": Elem.WATER, "lv": 1}
	var target_good: bool = main.card_dock.target_ok(dt, preview)
	dt.add(Elem.ICE, 1)
	dt.add(Elem.ELECTRIC, 1)
	var target_capped: bool = not main.card_dock.target_ok(dt, preview)
	main.mp_mode = "coop"
	var old_my_id: int = main.mp.my_id
	main.mp.my_id = 1
	dt.owner_id = 2
	dt.req_e = -1
	var ownership: bool = not main.card_dock.target_ok(dt, {"type":"mod", "id":"rapid"})
	dt.req_e = Elem.FIRE
	var requested: bool = main.card_dock.target_ok(dt, {"type":"elem", "e":Elem.FIRE, "lv":1})
	main.mp_mode = ""
	main.mp.my_id = old_my_id
	dt.owner_id = 0
	ok("UI-29", target_good and target_capped and ownership and requested, "카드 미리보기 적용 상한·협동 소유권·요청 속성 구분")
	# UI-32: 설명창은 내용 높이만큼, 보고 있는 오브젝트를 가리지 않는 위쪽 구석에
	var dock = main.card_dock
	var ui_size: Vector2 = main.ui_root.size
	var to_world := func(u: Vector2) -> Vector2:
		return main.get_canvas_transform().affine_inverse() * (main.ui_root.get_global_transform() * u)
	var keep_pos: Vector2 = dt.position
	var side_ok := true
	for u in [Vector2(ui_size.x - 120.0, 160.0), Vector2(120.0, 200.0)]:
		dt.position = to_world.call(u)
		dock.shown_tower = dt
		dock.heading.text = "직선탄"
		dock.detail.text = "피해 1\n\n초당 1번"
		dock._place_side(ui_size, false)
		var at: Vector2 = main.ui_root.get_global_transform().affine_inverse() * (main.get_canvas_transform() * dt.global_position)
		side_ok = side_ok and not dock.side.get_rect().has_point(at) and dock.side.size.y < ui_size.y * 0.6
	dt.position = keep_pos
	dock.shown_tower = null
	var tab_hidden: bool = not "legend_btn" in main
	var old_phase = main.phase
	main.phase = main.Phase.READY
	dock.hovered = null
	dock.inspected_tower = dt
	dock._update_side()
	var retained_tower: bool = dock.shown_tower == dt and dock.side.visible and dock.scroll.mouse_filter == Control.MOUSE_FILTER_STOP
	var close_visible: bool = dock.close_btn.visible
	main.tap_sel = 1
	main.hover_elem = Elem.FIRE
	dock.close_btn.pressed.emit()
	var closed: bool = not dock.side.visible and dock.inspected_tower == null and main.tap_sel == -1 and main.hover_elem == -1
	main.interaction_system.selected = [dt]
	dock._update_side()
	var stays_closed: bool = dock.inspector_dismissed and not dock.side.visible
	main.cards_system._set_card_detail(not Meta.card_detail)
	dock._update_side()
	ok("UI-32", stays_closed and not dock.inspector_dismissed and Meta.card_detail and dock.side.visible, "X 닫힘은 선택에도 유지하고 자세히 한 번으로 재활성화")
	main.interaction_system.selected.clear()
	dock.inspected_tower = dt
	dock._update_side()
	var old_pointer: Vector2 = main.interaction_system.pointer_position
	main.interaction_system.pointer_position = main.get_canvas_transform() * main.viewport_system.center()
	main.interaction_system.selected = [dt]
	main.tip_tower = dt
	var background_click := InputEventMouseButton.new()
	background_click.button_index = MOUSE_BUTTON_LEFT
	background_click.pressed = true
	background_click.position = main.interaction_system.pointer_position
	main.interaction_system._unhandled_input(background_click)
	main.interaction_system._finish_box()
	dock._update_side()
	var dismissed_tower: bool = main.interaction_system.selected.is_empty() and dock.inspected_tower == null and main.tip_tower == null and not dock.side.visible
	main.interaction_system.pointer_position = old_pointer
	main.phase = old_phase
	ok("UI-32", side_ok and retained_tower and close_visible and closed and dismissed_tower and tab_hidden, "설명창 내용 높이·보는 오브젝트 반대쪽 구석, 일반 판 Tab 버튼 없음")
	# 선택 대상은 카드 호버에 밀리지 않고, 다른 오브젝트 호버가 끝나면 돌아온다.
	var hover_other := _tower(main.viewport_system.center() + Vector2(-200, 0))
	var select_at: Vector2 = dt.position
	dt.position = Vector2(220, 300)
	hover_other.position = Vector2(420, 300)
	var saved_hidden: bool = main.cards_hidden
	main.phase = main.Phase.CHOOSE
	main.cards_hidden = false
	main.interaction_system._select_tower(dt)
	main.interaction_system.pointer_position = main.get_canvas_transform() * Vector2(650, 240)
	main.choice_box.get_child(0).mouse_entered.emit()
	dock._update_side()
	var selected_priority: bool = dock.shown_tower == dt and dock.preview_card().is_empty()
	main.interaction_system.pointer_position = main.get_canvas_transform() * hover_other.position
	dock._update_side()
	var temporary_hover: bool = dock.shown_tower == hover_other and dock.inspected_tower == dt and main.interaction_system.selected == [dt]
	main.interaction_system.pointer_position = main.get_canvas_transform() * Vector2(650, 240)
	dock._update_side()
	var restored_selection: bool = dock.shown_tower == dt and dock.inspected_tower == dt
	main.interaction_system.selected.append(hover_other)
	main.interaction_system.pointer_position = main.get_canvas_transform() * hover_other.position
	dock._update_side()
	main.interaction_system.pointer_position = main.get_canvas_transform() * Vector2(650, 240)
	dock._update_side()
	var group_anchor: bool = dock.shown_tower == dt and main.interaction_system.selected.size() == 2
	dock.close_inspector()
	main.choice_box.get_child(0).mouse_entered.emit()
	dock._update_side()
	var card_after_clear: bool = not dock.preview_card().is_empty() and dock.shown_tower == null
	dock.hovered = null
	dock.dismissed_tower = null
	hover_other.free()
	dt.position = select_at
	main.interaction_system.pointer_position = old_pointer
	main.phase = old_phase
	main.cards_hidden = saved_hidden
	ok("UI-32", selected_priority and temporary_hover and restored_selection and group_anchor and card_after_clear,
		"선택 상세 우선 %s · 호버 임시 %s · 복귀 %s · 그룹 기준 유지 %s · 선택 해제 후 카드 %s" % [selected_priority, temporary_hover, restored_selection, group_anchor, card_after_clear])
	# UI-38: 떠 있는 창 공용 틀 — 정보창도 DPS 표와 같은 FloatPanel(머리 줄 압정·접기, 정보창만 닫기). 옮겨 둔 자리에 고정, 압정 끄면 자동 자리, 터치는 여섯 자리에 붙음, 접으면 머리 줄만
	var fpp0: Dictionary = Meta.panel_pos.duplicate()
	var fold0: Dictionary = Meta.panel_fold.duplicate()
	var fs: FloatPanel = dock.side
	var same_frame: bool = fs is FloatPanel and main.dps_panel is FloatPanel and fs.close_btn != null and main.dps_panel.close_btn == null \
		and fs.pin_btn.get_parent() == fs.head and main.dps_panel.pin_btn.get_parent() == main.dps_panel.head
	var ph_37 = main.phase
	main.phase = main.Phase.READY
	Meta.panel_pos.erase("info")
	dock.inspected_tower = dt
	dock._update_side()
	dock._place_side(ui_size, false)
	var auto_at: Vector2 = fs.position
	Meta.panel_pos["info"] = Vector2(0.5, 0.5)
	dock._place_side(ui_size, false)
	var mid_x: float = (ui_size.x - fs.size.x) / 2.0
	var pin_ok: bool = fs.pinned() and absf(fs.position.x - mid_x) < 2.0
	fs.toggle_pin()
	dock._place_side(ui_size, false)
	var unpin_ok: bool = not fs.pinned() and fs.position.is_equal_approx(auto_at)
	var was_touch_37: bool = main.touch_ui
	main.touch_ui = true
	var sl37: Array[Vector2] = fs.slots()
	var snap_ok: bool = sl37.size() == 6 and fs.snap(Vector2(20.0, ui_size.y)) == sl37[3] and fs.snap(Vector2(ui_size.x, 0.0)) == sl37[2]
	main.touch_ui = was_touch_37
	var h_open: float = fs.size.y
	fs.fold_pressed.emit()
	dock._place_side(ui_size, false)
	var h_fold: float = fs.size.y
	var fold37: bool = fs.folded and not fs.body.visible and h_fold < h_open and Meta.panel_fold.get("info", false)
	fs.fold_pressed.emit()
	var unfold_ok: bool = not fs.folded and fs.body.visible
	Meta.panel_pos = fpp0
	Meta.panel_fold = fold0
	dock.close_inspector()
	main.phase = ph_37
	ok("UI-38", same_frame and pin_ok and unpin_ok and snap_ok and fold37 and unfold_ok, "떠 있는 창 공용 틀 %s · 옮긴 자리 고정 %s · 압정 끄면 자동 %s · 터치 여섯 자리 %s · 접기 %s(%d→%d)/%s" % [same_frame, pin_ok, unpin_ok, snap_ok, fold37, h_open, h_fold, unfold_ok])
	var status_guide_visible: bool = main.guide_label.visible
	main.guide_label.hide()
	main.phase = main.Phase.READY
	main.interaction_system.press_t = dt
	main.interaction_system.dragging = false
	main.interaction_system.pointer_position = main.get_canvas_transform() * dt.position
	main.interaction_system._release_press()
	dock._update_side()
	dock.tick()
	var selection_status: bool = main.hint.visible and main.patchlog_system._kr_keep("오브젝트 1개 선택") in main.hint.text
	var click_selects: bool = main.interaction_system.selected == [dt] and main.interaction_system.moving == null and main.phase == main.Phase.READY and dock.direction_btn.visible
	# 선택 없이 끌어 놓아도 상세를 열어 다음 클릭 한 번으로 방향을 바꾼다.
	main.interaction_system.selected.clear()
	dock.inspected_tower = null
	var drag_origin: Vector2 = dt.position
	main.interaction_system.press_t = dt
	main.interaction_system.dragging = true
	main.interaction_system.drag_group = [dt]
	main.interaction_system.drag_origs = [drag_origin]
	main.interaction_system._release_press()
	var drop_selects: bool = main.interaction_system.selected == [dt] and dock.inspected_tower == dt
	main.interaction_system.press_t = dt
	main.interaction_system._release_press()
	drop_selects = drop_selects and main.phase == main.Phase.AIM and main.interaction_system.moving == dt
	main.interaction_system._cancel_step()
	ok("UI-05", drop_selects, "끌어 놓기 후 선택·상세 유지, 다음 클릭은 방향 편집")
	var status_gap: bool = main.hint.get_rect().end.y <= main.start_btn.position.y - 7.9
	ok("UI-35", status_gap, "상태 안내는 실제 높이로 웨이브 버튼 위 8px 간격")
	main.phase = main.Phase.WAVE
	dock._update_side()
	main.interaction_system._edit_selected_direction()
	var wave_readonly: bool = not dock.direction_btn.visible and main.phase == main.Phase.WAVE and main.interaction_system.moving == null
	main.phase = main.Phase.READY
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = main.get_canvas_transform() * dt.position
	var right_ok := true
	for picked_group in [[], [dt]]:
		main.interaction_system.selected.assign(picked_group)
		main.interaction_system.pointer_position = right.position
		main.interaction_system._unhandled_input(right)
		right_ok = right_ok and main.phase == main.Phase.AIM and main.interaction_system.moving == dt and main.interaction_system.aim_right
		main.interaction_system.aim_right = false
		main.interaction_system._cancel_step()
	main.interaction_system._select_tower(dt)
	main.interaction_system.pointer_position = main.get_canvas_transform() * main.viewport_system.center()
	right.position = main.interaction_system.pointer_position
	main.interaction_system._unhandled_input(right)
	right_ok = right_ok and main.interaction_system.selected.is_empty() and main.phase == main.Phase.READY
	main.interaction_system._select_tower(dt)
	main.interaction_system.pointer_position = main.get_canvas_transform() * dt.position
	ok("UI-05", right_ok, "선택 유무와 무관하게 오브젝트 우클릭은 조준 우선, 빈 곳은 선택 해제")
	var original_dir: Vector2 = dt.dir
	# 이미 선택해 상세가 열린 오브젝트를 한 번 더 누르면 바로 방향 바꾸기, 취소하면 그대로
	main.interaction_system.press_t = dt
	main.interaction_system.dragging = false
	main.interaction_system._release_press()
	var tap_again: bool = main.phase == main.Phase.AIM and main.interaction_system.moving == dt
	main.interaction_system._cancel_step()
	tap_again = tap_again and main.phase == main.Phase.READY and dt.dir == original_dir and main.interaction_system.selected == [dt]
	# 선택한 오브젝트 위에서 휠: 15도씩 돌리기, 선택 안 한 오브젝트 위·전투 중이면 확대
	var was_touch_w: bool = main.touch_ui
	main.touch_ui = false
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = main.get_canvas_transform() * dt.position
	var a0: float = dt.dir.angle()
	var wheel_turns: bool = main.interaction_system._wheel_turn(wheel) and absf(angle_difference(a0, dt.dir.angle()) + deg_to_rad(-15.0)) < 0.01
	main.phase = main.Phase.WAVE
	var wheel_wave_zooms: bool = not main.interaction_system._wheel_turn(wheel)
	main.phase = main.Phase.READY
	main.interaction_system.selected = []
	var wheel_unselected_zooms: bool = not main.interaction_system._wheel_turn(wheel)
	main.interaction_system.selected = [dt]
	main.touch_ui = was_touch_w
	dt.set_attack_direction(original_dir)
	tap_again = tap_again and wheel_turns and wheel_wave_zooms and wheel_unselected_zooms
	dock.direction_btn.pressed.emit()
	dock.tick()
	var edit_status: bool = main.hint.visible and main.patchlog_system._kr_keep("방향 편집 중") in main.hint.text
	var edits_selected: bool = main.phase == main.Phase.AIM and main.interaction_system.moving == dt
	main.interaction_system._cancel_step()
	var cancel_restores: bool = main.phase == main.Phase.READY and main.interaction_system.selected == [dt] and dt.dir == original_dir and dock.inspected_tower == dt
	main.phase = main.Phase.CHOOSE
	main.cards_hidden = true
	main.picked = main.offer[0]
	main.interaction_system._start_move(dt)
	main.interaction_system.moving = null
	main.interaction_system._end_move()
	var finished_clean: bool = main.cards_hidden and main.interaction_system.selected.is_empty() and dock.inspected_tower == null and dock.hovered == null and main.tap_sel == -1
	main.cards_hidden = false
	dock.close_inspector()
	main.interaction_system.selected = [dt]
	main.cards_system._on_pick({"type": "mod", "id": "multi"})
	var carry_status: bool = main.interaction_system.selected.is_empty() and main.hint.visible and main.patchlog_system._kr_keep("카드 놓는 중") in main.hint.text and main.patchlog_system._kr_keep("Esc 취소") in main.hint.text
	var was_touch: bool = main.touch_ui
	main.touch_ui = true
	var touch_status: bool = "버튼으로 취소" in dock.operation_text() and not "Esc" in dock.operation_text()
	main.touch_ui = was_touch
	main.phase = main.Phase.CHOOSE
	var deleted = _tower(main.viewport_system.center() + Vector2(200, 0))
	main.interaction_system.selected = [deleted]
	deleted.free()
	var deleted_selection: bool = dock.operation_text() == "" and main.interaction_system.selected.is_empty()
	main.interaction_system._select_tower(dt)
	dock.tick()
	var state_before_guide: bool = main.hint.visible
	main.guide_label.show()
	dock.tick()
	var guide_priority: bool = not main.hint.visible
	dock.close_inspector()
	main.phase = old_phase
	main.guide_label.visible = status_guide_visible
	ok("UI-35", selection_status and edit_status and carry_status and touch_status and deleted_selection and state_before_guide and guide_priority, "선택·편집·카드 상태 %s/%s/%s · 터치 %s · 삭제 %s" % [selection_status, edit_status, carry_status, touch_status, deleted_selection])
	ok("UI-05", click_selects and wave_readonly and edits_selected and cancel_restores and finished_clean and tap_again, "클릭은 선택, 한 번 더 누르기·[방향 변경]으로 방향 편집·취소 복원, 휠 15도 %s, 전투 중 읽기 전용" % tap_again)
	# UI-36: 점수 줄 칩 밑에 깔린 오브젝트는 점수 줄이 막지 않는다
	var hud_ok := true
	if main.hud.is_visible_in_tree() and main.hud.size.x > 40.0:
		var hp: Vector2 = main.hud.get_global_rect().position + Vector2(20.0, main.hud.size.y / 2.0)
		var keep_hp: Vector2 = dt.position
		dt.position = Vector2(-9999, -9999)
		var blocked_empty: bool = dock.over_ui(hp) or main.interaction_system._tower_at(main.get_canvas_transform().affine_inverse() * hp) != null
		dt.position = main.get_canvas_transform().affine_inverse() * hp
		var free_tower: bool = not dock.over_ui(hp)
		dt.position = keep_hp
		hud_ok = blocked_empty and free_tower
	ok("UI-36", hud_ok, "점수 줄 밑 오브젝트는 누를 수 있고, 빈 칩 자리는 막힘")
	# UI-33: 설명창 그림 (오브젝트 정보: 미리보기·숫자 타일, 자세히: 곱셈 사슬·배율 막대 / 카드: 미리보기·타일)
	var pic: InfoPanel = dock.pic
	pic.show_tower(dt, false, 0.3, "이번 웨이브 몫", 300.0)
	var h_basic: float = pic.custom_minimum_size.y
	pic.show_tower(dt, true, 0.3, "이번 웨이브 몫", 300.0)
	var h_more: float = pic.custom_minimum_size.y
	var df: Dictionary = dt.dmg_factors()
	var hc2: Dictionary = dt.hit_calc()
	var chain_end: String = df["chain"][-1][0]
	var chain_ok: bool = chain_end == "= " + Tower.tip_num(hc2["one"] + hc2["metal"])
	pic.show_card({"type": "elem", "e": Elem.FIRE, "lv": 2}, {"kind": "elem", "name": "불", "e": Elem.FIRE, "lv": "Lv2"}, 3, 1, [Elem.WOOD], 300.0)
	var card_ok: bool = pic.mode == "card" and pic.custom_minimum_size.y > 150.0
	pic.clear()
	ok("UI-33", h_basic > 200.0 and h_more > h_basic and chain_ok and card_ok, "설명창 그림: 기본 %d · 자세히 %d · 사슬 끝 %s" % [h_basic, h_more, chain_end])
	main.phase = main.Phase.READY
	main.touch_ui = true
	main.countdown = -1.0
	main.card_dock.inspected_tower = dt
	main.tip_frame = -10
	main.frame_system._process(4.0)
	var touch_detail_btn: bool = main.detail_btn.is_visible_in_tree() and main.detail_btn.get_parent() == dock.inspector_header
	main.detail_btn.pressed.emit()
	main.frame_system._process(0.0)
	var touch_detail_kept: bool = main.field_view_system._tip_detail_on() and dock.shown_tower == dt and main.field_view_system._ring_target() == dt and dock.pic.detail
	main.touch_ui = false
	main.tip_detail = false
	dock.close_inspector()
	ok("UI-16", touch_detail_btn and touch_detail_kept, "터치 인스펙터는 시간 경과 후에도 유지, 헤더 자세히로 상세 수치 전환")
	main.phase = main.Phase.READY
	main.card_dock.inspected_tower = dt
	main.interaction_system.selected = [dt]
	main.run_flow_system._toggle_pause()
	main.frame_system._process(0.0)
	var paused_reading: bool = dock.side.visible and dock.side.z_index > main.pause_dim.z_index and not dock.direction_btn.visible and main.field_view_system._ring_target() == null
	main.interaction_system._edit_selected_direction()
	var paused_no_edit: bool = main.phase == main.Phase.READY and main.interaction_system.moving == null
	main.run_flow_system._toggle_pause()
	ok("UI-07", paused_reading and paused_no_edit, "정지 중 인스펙터는 막 위에서 열람 가능, 방향 편집은 금지")
	main.phase = main.Phase.PLACE


	# 카드 넣을 대상: 넣을 수 있는 오브젝트만 밝게, 못 넣는 오브젝트(NO_MOD 등)는 흐리게·선택 불가
	var bad_t := _tower(main.viewport_system.center() + Vector2(200, 0))
	bad_t.set_pattern("thorn")
	main.picked = {"type": "mod", "id": "pierce"}
	main.phase = main.Phase.PLACE
	main.interaction_system._update_place_dim()
	var marks: bool = main.interaction_system._place_ok(dt) and not main.interaction_system._place_ok(bad_t) and bad_t.modulate == main.PLACE_OFF and dt.modulate == Color.WHITE \
		and main.interaction_system._place_refuse(bad_t) != ""
	main.phase = main.Phase.CHOOSE
	main.interaction_system._update_place_dim()
	var back: bool = bad_t.modulate == Color.WHITE
	ok("UI-24", marks and back, "강화 카드 놓기: 넣을 수 있는 것만 밝게, 관통 연사는 흐리게·이유 문구, 단계가 바뀌면 원래대로")

	# 넣을 오브젝트에 올린 설명: 전·후 숫자만 합친 한 줄, 강화 카드를 넣는 동안 모든 별·바람 둘레는 끔
	var mg: String = Tower.arrow_merge("혼불 3개 (하나 피해 73%) · 공격방식 보정 x1.06", "혼불 4개 (하나 피해 72%) · 공격방식 보정 x1.06")
	var mg2: String = Tower.arrow_merge("없음", "탄 2개")
	main.picked = {"type": "mod", "id": "multi"}
	main.phase = main.Phase.PLACE
	var rings_off: bool = main.field_overlay_system._place_rings_off()
	main.phase = main.Phase.CHOOSE
	var rings_back: bool = not main.field_overlay_system._place_rings_off()
	var pv_ok: bool = not (dt.preview({"type": "mod", "id": "multi"})[0] as PackedStringArray)[0].contains("겹쳐서")
	main.card_dock.camera_fit()
	var preview_target := _tower(main.interaction_system._pointer_world())
	main.picked = {"type": "mod", "id": "multi"}
	main.phase = main.Phase.PLACE
	var guide_was_visible: bool = main.guide_label.visible
	main.guide_label.hide()
	main.card_dock.tick()
	var preview_status: bool = main.hint.visible and main.patchlog_system._kr_keep("카드 놓는 중") in main.hint.text
	preview_target.free()
	main.card_dock.tick()
	ok("UI-25", preview_status and main.hint.visible, "대상 미리보기 중 상태 유지 %s/%s · 문구 %s · 입력 차단 %s" % [preview_status, main.hint.visible, main.hint.text, main.card_dock.input_blocked()])
	main.guide_label.visible = guide_was_visible
	main.phase = main.Phase.CHOOSE
	ok("UI-25", mg == "혼불 3→4개 (하나 피해 73→72%) · 공격방식 보정 x1.06" and mg2 == "없음 → 탄 2개" and rings_off and rings_back and pv_ok, "넣기 설명 한 줄 합치기 '%s', 둘레 끔 %s/%s" % [mg, rings_off, rings_back])

	# 오브젝트 정보창: 기본은 피해·공격 속도·치명타 숫자만, 자세히에만 주변 둘레
	_fresh(3)
	var tp := _tower(main.viewport_system.center() + Vector2(0, -150), Elem.SOUL, 3)
	tp.add(Elem.STAR, 1)
	tp.add(Elem.LIGHT, 2)
	tp.eff = tp.eff_now()
	var bl: Array = tp.basic_lines()
	var bl_ok: bool = bl.size() == 3 and (bl[0][0] as String).begins_with("피해 ") and (bl[1][0] as String).begins_with("초당 ") and (bl[2][0] as String).begins_with("치명타 ")
	var plain := _tower(main.viewport_system.center() + Vector2(0, 150))
	plain.eff = plain.eff_now()
	var no_crit: bool = plain.basic_lines().size() == 2
	var dl_more: bool = tp.detail_lines().size() > bl.size()
	var basic_ring: bool = main.field_view_system._ring_target() == null and not main.field_view_system._tip_detail_on()
	ok("UI-26", bl_ok and no_crit and dl_more and basic_ring, "정보창 기본 %d줄 %s, 빛 없으면 치명타 줄 없음 %s, 자세히가 더 많음 %s, 기본엔 둘레 없음 %s" % [bl.size(), bl_ok, no_crit, dl_more, basic_ring])

	# 웨이브 넘기기: 오브젝트가 있어야, 첫 판은 카드가 다 열린 뒤
	_fresh(3)
	var none: bool = main.run_flow_system._can_skip()
	_tower(main.viewport_system.center() + Vector2(-200, 0))
	var some: bool = main.run_flow_system._can_skip()
	main.tutor = true
	var tut: bool = main.run_flow_system._can_skip()
	main.tutor = false
	ok("SKIP-01", not none and some and not tut, "웨이브 넘기기: 오브젝트가 있을 때만, 첫 판은 카드가 다 열린 뒤")
	main.phase = main.Phase.CHOOSE
	main.picks_left = 2
	Meta.skip_n = 3
	main.run_flow_system._update_skip_ui()
	var skip_forecast: bool = "카드 선택 2회 보류" in main.skip_btn.tooltip_text
	main.get_tree().paused = true
	var paused_offer: Array = main.offer.duplicate(true)
	var paused_rerolls: int = main.rerolls_left
	for code in [KEY_S, KEY_Q, KEY_SPACE, KEY_1]:
		var paused_key := InputEventKey.new()
		paused_key.keycode = code
		paused_key.pressed = true
		main.interaction_system._unhandled_input(paused_key)
	main.run_flow_system._on_skip()
	main.cards_system._on_reroll()
	var paused_unchanged: bool = main.phase == main.Phase.CHOOSE and main.picks_left == 2 and main.rerolls_left == paused_rerolls and main.offer == paused_offer and main.skip_left == 0
	main.get_tree().paused = false
	ok("UI-10", paused_unchanged, "일시정지 중 선택·새로고침·넘기기·시작 입력은 상태를 바꾸지 않음")
	# 음량: 설정 창에 전체·배경음·효과음 슬라이더, 배경음·효과음은 따로 효과음 플레이어·배경음 크기에 반영, 0이면 안 남
	var vs: Dictionary = main.menu_system.volume_sliders
	var vol_save := [Meta.volume, Meta.music_volume, Meta.sfx_volume]
	var vol_rows: bool = vs.has("전체 음량") and vs.has("배경음") and vs.has("효과음") and vs.values().all(func(sl): return main.settings_panel.is_ancestor_of(sl))
	var vol_ok := false
	if vol_rows:
		vs["배경음"].value = 0.5
		vs["효과음"].value = 0.0
		var sfx: Sfx = main.sfx
		var music_half: bool = is_equal_approx(Meta.music_volume, 0.5) and absf(sfx.music_player.volume_db - (Sfx.MUSIC_DB + linear_to_db(0.5))) < 0.1 and not sfx.music_player.stream_paused
		var fx_off: bool = Meta.sfx_volume == 0.0 and sfx.sfx_vol == 0.0 and sfx.players[0].volume_db < -50.0
		vs["효과음"].value = 1.0
		vs["배경음"].value = 0.0
		var music_off: bool = sfx.music_player.stream_paused and is_equal_approx(sfx.players[0].volume_db, 0.0)
		vs["전체 음량"].value = 0.5
		var master_ok: bool = absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.1
		vol_ok = music_half and fx_off and music_off and master_ok
	for i in 3:
		var key: String = ["전체 음량", "배경음", "효과음"][i]
		if vs.has(key):
			vs[key].value = vol_save[i]
	ok("UI-40", vol_rows and vol_ok, "음량 따로: 전체·배경음·효과음 슬라이더 %s, 반영 %s" % [vol_rows, vol_ok])
	# 폰 글자 크기: 폰만 작은 글을 키우고 PC는 그대로, 폰은 카드 줄도 키 큰 판
	var was_phone := Meta.sim_phone
	Meta.sim_phone = false
	CardDock.fit_phone()
	var fs_pc: bool = Meta.fs(13) == 13 and Meta.fs(18) == 18 and Meta.fs(72) == 72 and is_equal_approx(CardDock.CARD_HEIGHT, 94.0) and Meta.fs_bb("[font_size=12]a") == "[font_size=12]a"
	Meta.sim_phone = true
	CardDock.fit_phone()
	var fs_phone: bool = Meta.fs(11) == 18 and Meta.fs(18) == 23 and Meta.fs(24) == 30 and Meta.fs(72) == 72 and CardDock.CARD_HEIGHT > 94.0 and CardDock.CONTROL_HEIGHT > 36.0 and Meta.fs_bb("[font_size=12]a") == "[font_size=18]a"
	Meta.sim_phone = was_phone
	CardDock.fit_phone()
	ok("UI-41", fs_pc and fs_phone, "폰 글자 크기: PC 그대로 %s, 폰 키움 %s" % [fs_pc, fs_phone])
	# 소리 버튼: 누르면 작은 창(켜기·끄기 + 음량 세 줄), 창에서 끄면 소리 꺼짐, 창 음량은 설정 창과 같은 값, 바깥·버튼 다시 누르면 닫힘
	var mm = main.menu_system
	var was_muted: bool = main.sfx.muted
	var mv_save: float = Meta.music_volume
	main.mute_btn.pressed.emit()
	var pop_open: bool = mm.sound_pop.visible and was_muted == main.sfx.muted
	var pop_sl: Array = mm.sound_panel.find_children("Vol_*", "HSlider", true, false)
	var pop_rows: bool = pop_sl.size() == 3 and mm.sound_toggle != null and mm.sound_toggle.button_pressed == not main.sfx.muted
	mm.sound_toggle.button_pressed = main.sfx.muted  # 반대로 = 끄기(켜져 있었으면)
	var pop_mute: bool = main.sfx.muted != was_muted
	mm.sound_toggle.button_pressed = not mm.sound_toggle.button_pressed
	var pop_back: bool = main.sfx.muted == was_muted
	var pop_music: HSlider = pop_sl.filter(func(x): return x.name == "Vol_배경음")[0] if pop_sl.size() == 3 else null
	var pop_sync := false
	if pop_music:
		pop_music.value = 0.25
		pop_sync = is_equal_approx(Meta.music_volume, 0.25) and is_equal_approx(vs["배경음"].value, 0.25)
		pop_music.value = mv_save
	var pr: Rect2 = mm.sound_panel.get_global_rect()
	var br: Rect2 = main.mute_btn.get_global_rect()
	var vr: Rect2 = main.get_viewport_rect()
	var pop_place: bool = pr.end.y <= br.position.y + 1.0 and vr.encloses(pr)
	main.mute_btn.pressed.emit()
	var pop_closed: bool = not mm.sound_pop.visible
	ok("UI-42", pop_open and pop_rows and pop_mute and pop_back and pop_sync and pop_closed and pop_place, "소리 버튼 작은 창: 열림 %s, 켜기·음량 세 줄 %s, 끄기 %s·다시 켜기 %s, 설정과 같은 값 %s, 버튼 위·화면 안 %s, 닫힘 %s" % [pop_open, pop_rows, pop_mute, pop_back, pop_sync, pop_place, pop_closed])
	main.run_flow_system._on_skip()
	ok("SKIP-02", skip_forecast and main.skip_left == 3 and main.bank_picks.size() == 2, "넘기기: 이번 고르기를 쌓아 두고 n웨이브 진행 (남은 %d, 쌓인 고르기 %d)" % [main.skip_left, main.bank_picks.size()])
	main.skip_left = 0
	main.bank_picks = []
	# 카드를 다 고른 뒤(웨이브 시작 대기)에도 넘기기: 버튼이 보이고, 누르면 넘기기 시작
	_tower(main.viewport_system.center() + Vector2(-200, 0))
	main.cards_system._enter_ready()
	main.countdown = -1.0
	main.run_flow_system._update_skip_ui()
	main.card_dock.tick()
	var ready_btn: bool = main.skip_btn.visible and main.card_dock.skip_group.visible and is_equal_approx(main.skip_btn.get_rect().end.x, main.skip_n_btn.position.x) and main.skip_btn.text == "넘기기" and main.skip_n_btn.text == "3웨이브 ▸"
	main.run_flow_system._on_skip()
	ok("SKIP-03", ready_btn and main.skip_left == 3 and main.bank_picks.is_empty() and main.phase == main.Phase.READY, "웨이브 시작 대기에서도 넘기기 (버튼 %s, 남은 %d)" % [ready_btn, main.skip_left])
	main.skip_left = 0
	main.countdown = -1.0
	_clear()

	# 피해 출처
	var tw := Tower.new()
	tw.credit(5.0, "share:electric")
	tw.credit(2.0, "share:electric")
	ok("DPS-01", is_equal_approx(tw.dealt, 7.0) and is_equal_approx(tw.src.get("share:electric", 0.0), 7.0), "피해 출처: 출처별로 나눠 쌓음")
	tw.free()

	# 웨이브 중 실시간 DPS: 최근 5초 이동 평균 (앞쪽 큰 피해는 창 밖으로 빠짐), 접기 상태 저장
	_tower(main.viewport_system.center() + Vector2(-200, 0))
	var lt: Tower = main.towers.get_child(main.towers.get_child_count() - 1)
	var ph0 = main.phase
	main.phase = main.Phase.WAVE
	main.dps_hist.clear()
	main.dps_t = 0.0
	lt.dealt = 1000.0  # 웨이브 초반 큰 피해
	main.wave_time = 0.0
	for i in 40:  # 20초 동안 초당 10
		main.hud_system._dps_sample(main.DPS_STEP)
		lt.dealt += 10.0 * main.DPS_STEP
		main.wave_time += main.DPS_STEP
	var live: float = main.hud_system._dps_of(lt)
	main.phase = main.Phase.CHOOSE
	var after: float = main.hud_system._dps_of(lt)
	main.phase = ph0
	var f0: bool = main.dps_hidden
	main.hud_system._toggle_dps()
	var saved: bool = Meta.dps_fold == main.dps_hidden and main.dps_hidden != f0
	main.hud_system._toggle_dps()
	ok("DPS-02", absf(live - 10.0) < 0.01 and after > 50.0 and saved, "실시간 DPS: 웨이브 중 최근 5초 이동 평균 (%.1f, 쉬는 시간엔 웨이브 평균 %.1f), 표 접기 저장" % [live, after])
	var stale_row: Control = main.hud_system._dps_row(lt, 1, 10.0, 10.0)
	main.hud_system.dps_list.add_child(stale_row)
	lt.free()
	stale_row.mouse_entered.emit()
	stale_row.mouse_exited.emit()
	ok("DPS-02", main.dps_focus == null, "오브젝트가 삭제된 옛 DPS 줄에 올려도 해제된 참조를 읽지 않음")
	stale_row.queue_free()
	# 표 옮기기: 제목 줄 짧게 누르면 접기·펴기, 끌거나 꾹 누르면 집어 들고, 놓은 자리는 비율로 저장, 점수 줄과 겹치면 비킴
	var h0: bool = main.dps_hidden
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	var fp: FloatPanel = main.dps_panel
	fp.head_input(dn)
	fp.head_input(up)
	var tap_ok: bool = main.dps_hidden != h0 and fp.drag == 0
	main.hud_system._toggle_dps()
	var pp0: Dictionary = Meta.panel_pos.duplicate()
	fp.head_input(dn)
	fp.press = fp._local_pointer() + Vector2(50, 0)  # 누른 뒤 50 끈 것처럼
	var mv := InputEventMouseMotion.new()
	fp.head_input(mv)
	var picked: bool = fp.drag == 2
	fp.head_input(up)
	var dpr: Vector2 = Meta.panel_pos.get("dps", Vector2(-1, -1))
	var dropped: bool = fp.drag == 0 and main.dps_hidden == h0 and fp.pinned() and dpr.x >= 0.0 and dpr.x <= 1.0 and dpr.y >= 0.0 and dpr.y <= 1.0
	fp.toggle_pin()
	var unpinned: bool = not fp.pinned()
	Meta.panel_pos = pp0
	main.hud_system._update_hud(true)
	var dodge := true
	if main.hud.visible and not main.hud_chips.is_empty():
		var c0: Rect2 = main.hud_chips[0][0]
		var p: Vector2 = fp.place(main.hud.position + c0.position)
		dodge = p.y >= main.hud.position.y + c0.end.y
	# 표 밑에 오브젝트가 깔린 자리를 누르면 오브젝트가 먼저 (점수 줄과 같은 규칙), 빈 자리는 표가 받음
	var pv0: bool = main.dps_panel.visible
	main.dps_panel.visible = true
	main.dps_panel.position = Vector2(10, 100)
	main.dps_panel.size = Vector2(300, 160)
	var sp: Vector2 = main.dps_panel.get_global_rect().get_center()
	var wpos: Vector2 = main.get_canvas_transform().affine_inverse() * sp
	var n0: int = main.towers.get_child_count()
	main.picked = {"e": Elem.FIRE, "lv": 1}
	main.interaction_system._place_tower(wpos, Vector2.RIGHT)
	main.picked = {}
	var ut: Node = main.towers.get_child(main.towers.get_child_count() - 1) if main.towers.get_child_count() > n0 else null
	var under_ok := false
	if ut != null:
		ut.position = wpos
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = sp
		main.interaction_system._input(ev)
		var passes: bool = main.dps_panel.passing and main.dps_panel.head.mouse_filter == Control.MOUSE_FILTER_IGNORE and not main.card_dock.over_ui(sp)
		ut.position = Vector2(-9999, -9999)
		main.interaction_system._input(ev)
		var blocks: bool = not main.dps_panel.passing and main.dps_panel.head.mouse_filter == Control.MOUSE_FILTER_STOP and main.card_dock.over_ui(sp)
		under_ok = passes and blocks
		ut.free()
	main.dps_panel.visible = pv0
	ok("DPS-03", under_ok, "DPS 표 밑 오브젝트는 누를 수 있고, 빈 표 자리는 표가 받음")
	ok("DPS-03", tap_ok and picked and dropped and unpinned and dodge, "DPS 표 옮기기: 짧게 누르기=접기 %s, 끌기=집기 %s, 놓기=자리 저장·압정 %s, 압정 끄기 %s, 점수 줄 비킴 %s" % [tap_ok, picked, dropped, unpinned, dodge])
	_clear()

	# 피해 1~3위 왕관·메달: 쉬는 시간 지난 웨이브 피해 순, 2개면 1위만, 1위가 바뀌면 왕관이 날아감, 설정으로 끔
	var rk: Array = []
	for i in 4:
		_tower(main.viewport_system.center() + Vector2(-240 + 160 * i, 120))
		rk.append(main.towers.get_child(main.towers.get_child_count() - 1))
	var ph1 = main.phase
	main.phase = main.Phase.CHOOSE
	for i in 4:
		rk[i].dealt = [300.0, 900.0, 100.0, 500.0][i]
	main.hud_system.rank_of.clear()
	main.hud_system._rank_update()
	var r_ok: bool = main.hud_system.rank_of.get(rk[1].get_instance_id(), 0) == 1 and main.hud_system.rank_of.get(rk[3].get_instance_id(), 0) == 2 \
		and main.hud_system.rank_of.get(rk[0].get_instance_id(), 0) == 3 and not main.hud_system.rank_of.has(rk[2].get_instance_id())
	rk[2].dealt = 2000.0
	main.hud_system._rank_update()
	var fly: bool = main.hud_system.rank_of.get(rk[2].get_instance_id(), 0) == 1 and rk[2].crown_t > 0.0
	main.phase = main.Phase.WAVE
	main.wave_time = 1.0
	rk[1].dealt = 5000.0
	main.hud_system._rank_update()
	var hold: bool = main.hud_system.rank_of.get(rk[2].get_instance_id(), 0) == 1  # 웨이브 첫 3초는 그대로
	main.phase = main.Phase.CHOOSE
	for i in 2:
		rk[i].dealt = 0.0
	main.hud_system._rank_update()
	var two: bool = main.hud_system.rank_of.size() == 1  # 피해 있는 오브젝트 2개 → 1위만
	var on0: bool = Meta.rank_on
	Meta.rank_on = false
	main.hud_system._rank_update()
	var off: bool = main.hud_system.rank_of.is_empty()
	Meta.rank_on = on0
	main.phase = ph1
	ok("RANK-01", r_ok and fly and hold and two and off, "피해 1~3위 왕관·메달 (순위 %s, 날아감 %s, 웨이브 초반 유지 %s, 2개면 1위만 %s, 끄기 %s)" % [r_ok, fly, hold, two, off])
	_clear()


# ---------- 멀티플레이 (연결 없이 확인할 수 있는 것) ----------

func _multiplayer() -> void:
	# 대결: 같은 씨앗이면 같은 웨이브. 씨앗 0이면 전역 난수 (혼자 하는 판 순서 그대로)
	var rolls := []
	for k in 2:
		_fresh(6)
		main.mp_seed = 4242
		randomize()  # 전역 난수가 달라도 같아야 한다
		main.lanes.clear()
		main.run_flow_system._new_rest()
		var plan := [Array(main.lanes), main.wave_resist]
		main.phase = main.Phase.WAVE
		main.wave += 1
		main.lane_bag.clear()
		for i in main.waves_system.lane_counts(main.wave).size():
			for j in main.waves_system.lane_counts(main.wave)[i]:
				main.lane_bag.append(i)
		main.multiplayer_system._wshuffle(main.lane_bag)
		for i in 5:
			plan.append(main.spawning_system._roll_orb(main.wave))
		rolls.append(var_to_str(plan))
	main.mp_seed = 0
	seed(7)
	var a := randf()
	seed(7)
	var b: float = main.multiplayer_system.wf()
	ok("MP-03", rolls[0] == rolls[1] and is_equal_approx(a, b), "대결: 같은 씨앗이면 같은 방향·저항·구체, 씨앗 0이면 전역 난수")

	# 멀티 난이도: 대결·협동만 구체 체력 x0.7(대결)·중앙 체력 13, 혼자 판은 그대로
	_fresh(3)
	var cores := []
	for st in [[false, 1], [true, 1], [false, 2]]:
		main.vs_on = st[0]
		main.coop_n = st[1]
		main.hud_system.start_modes()
		cores.append(main.core_max)
	main.vs_on = true
	var vk: float = main.vs_k("vs_hp")
	main.vs_on = false
	main.coop_n = 1
	main.hud_system.start_modes()
	ok("MP-20", cores == [10, 13, 13] and is_equal_approx(vk, 0.7) and main.vs_k("vs_hp") == 1.0 and main.core_max == 10,
		"멀티 난이도: 중앙 체력 혼자/대결/협동 %s, 대결 구체 체력 x%.2f" % [str(cores), vk])

	# 대결: 보낸 구체는 다음 웨이브에 더 나오고, 다 나와야 웨이브가 끝난다
	_fresh(3)
	main.mp_mode = "vs"
	main.mp_next_extra = 3
	main.phase = main.Phase.READY
	main.run_flow_system._start_wave()
	var extra: int = main.mp_extra_left
	main.to_spawn = 0
	for i in 600:
		main.combat_system._sim_step(1.0 / 30.0)
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
	var mine := _tower(main.viewport_system.center() + Vector2(-200, 0), Elem.FIRE, 2)
	var other := _tower(main.viewport_system.center() + Vector2(200, 0), Elem.WATER)
	other.owner_id = 2
	main.phase = main.Phase.CHOOSE
	main.interaction_system._begin_press(other, other.position)
	var blocked: bool = main.interaction_system.press_t == null
	var select_all := InputEventKey.new()
	select_all.keycode = KEY_A
	select_all.ctrl_pressed = true
	select_all.pressed = true
	main.interaction_system._unhandled_input(select_all)
	var owned_selection: bool = main.interaction_system.selected == [mine]
	main.interaction_system.selected.clear()
	main.coop_n = 2
	var hk1: float = main.coop_hp_k(1)
	var hk3: float = main.coop_hp_k(3)
	main.coop_n = 1
	var hk_solo: float = main.coop_hp_k(3)
	ok("MP-06", (duo == roundi(solo * 1.6) or abs(duo - solo * 1.6) <= 1.0) and is_equal_approx(hk1, 1.5) and is_equal_approx(hk3, 1.5 * 1.18 * 1.18) and hk_solo == 1.0,
		"협동: 2명이면 구체 x1.6 (%d → %d), 체력 웨이브1 x%.2f·웨이브3 x%.2f, 혼자 x%.1f" % [solo, duo, hk1, hk3, hk_solo])
	mine.dealt = 55.0
	var st: Dictionary = other.mp_state()
	st["nid"] = 200001
	var copy := Tower.new()
	copy.main = main
	copy.mp_apply(st)
	mine.mp_apply(mine.mp_state())
	ok("MP-07", mine.owner_id == 1 and mine.net_id == 100001 and blocked and owned_selection and main.multiplayer_system._my_towers() == [mine] and copy.elements == other.elements and copy.pattern == other.pattern and is_equal_approx(mine.dealt, 55.0) and mine.lv(Elem.FIRE) == 2,
		"협동: 내 오브젝트만 바꿈, 상태를 주고받아도 속성·공격방식 같고 피해 기록은 이 기기 것 (%s)" % str([mine.owner_id, mine.net_id, blocked, main.multiplayer_system._my_towers().size(), copy.elements, other.elements, mine.dealt, mine.lv(Elem.FIRE)]))
	copy.free()
	main.interaction_system.press_t = null

	# 멀티 판: 이어하기 저장·웨이브 넘기기 없음
	var had := FileAccess.file_exists(main.RUN_PATH)
	if had:
		DirAccess.remove_absolute(main.RUN_PATH)
	main.phase = main.Phase.CHOOSE
	main.persistence_system._save_run()
	ok("MP-08", not FileAccess.file_exists(main.RUN_PATH) and not main.run_flow_system._can_skip(), "멀티 판은 이어하기 저장·웨이브 넘기기 없음")
	main.mp_mode = ""
	main.mp.my_id = 0
	main.mp_tw_n = 0
	_clear()
	_mp_more()


## 멀티 업적·잠수·속성 요청·대결 보낸 구체 (2026-10-31).
func _mp_more() -> void:
	# MP-14: 멀티 판은 기존 업적·누적 키가 안 오르고 멀티 업적만
	_fresh(5)
	main.mp_mode = "coop"
	main.mp.my_id = 1
	main.coop_n = 2
	Ach.mp = "coop"
	var kb := int(Meta.tally.get("boss_kills", 0))
	var mw := int(Meta.tally.get("max:wave", 0))
	var w100 := Meta.achieved.has("wave100")
	Ach.add("boss_kills")
	Ach.raise("max:wave", 100)
	main.progression_system._achieve("wave100")
	main.multiplayer_system._mp_ach_coop(5, {1: 0.5, 2: 0.5})
	var blocked: bool = int(Meta.tally.get("boss_kills", 0)) == kb and int(Meta.tally.get("max:wave", 0)) == mw and Meta.achieved.has("wave100") == w100
	var got: bool = Meta.achieved.has("mp_coop5") and int(Meta.tally.get("max:mp_coop", 0)) >= 5
	Ach.mp = ""
	var bindu_goal := Ach.goal(Ach.by_id("bindu"))
	ok("MP-14", blocked and got and bindu_goal == Ach.LIST.filter(func(a): return a["group"] != Ach.MP_GROUP).size() - 1 and Ach.GROUPS.has(Ach.MP_GROUP),
		"멀티 판: 기존 키·업적 막힘 %s, 협동 웨이브 5 업적 %s, 빈두 목표 %d(멀티 빼고)" % [blocked, got, bindu_goal])

	# MP-15: 잠수 — 기다림 알림, 대신 고르기, 2번 연속 자리 비움, 누르면 돌아옴. 대결은 대신 고르고 웨이브 시작
	_fresh(3)
	main.mp_mode = "coop"
	main.mp.my_id = 2
	main.multiplayer_system._mp_packet(1, {"t": "wait", "s": 45.0, "ids": [2]})
	var waited: bool = is_equal_approx(main.mp_wait_left, 45.0)
	main.mp_afk_n = 0
	main.run_flow_system._start_choose()
	main.lobby_system._mp_auto_rest()
	var first := [main.phase == main.Phase.READY, main.mp_i_ready, main.towers.get_child_count() >= 1, main.mp_afk_n == 1, main.mp_afk]
	main.mp_i_ready = false
	main.run_flow_system._start_choose()
	main.lobby_system._mp_auto_rest()
	var afk: bool = main.mp_afk
	main.lobby_system._mp_presence()
	var back: bool = not main.mp_afk and main.mp_afk_n == 0
	_fresh(3)
	main.mp_mode = "vs"
	main.mp.my_id = 1
	main.mp_afk_n = 0
	main.run_flow_system._start_choose()
	main.lobby_system._mp_auto_rest()
	var vs_go: bool = main.phase == main.Phase.WAVE and main.mp_afk_n == 1
	ok("MP-15", waited and first == [true, true, true, true, false] and afk and back and vs_go and Rules.tune["mp_wait"] == 45.0 and Rules.tune["vs_idle"] == 90.0,
		"잠수: 기다림 %s, 첫 대신 고르기 %s, 2번째 자리 비움 %s, 돌아옴 %s, 대결 웨이브 시작 %s" % [waited, str(first), afk, back, vs_go])
	main.mp_i_ready = false
	main.mp_afk_n = 0

	# MP-16: 속성 요청 — 요청한 속성 카드만 친구 오브젝트에, 받으면 주인 기기가 넣고 요청이 지워짐
	_fresh(3)
	main.mp_mode = "coop"
	main.mp.my_id = 1
	var mine := _tower(main.viewport_system.center() + Vector2(-200, 0), Elem.FIRE)
	var other := _tower(main.viewport_system.center() + Vector2(200, 0), Elem.WOOD)
	other.owner_id = 2
	other.req_e = Elem.WATER
	main.picked = {"type": "elem", "e": Elem.WATER, "lv": 1}
	var can_req: bool = main.interaction_system._place_ok(other)
	main.picked = {"type": "elem", "e": Elem.FIRE, "lv": 1}
	var cant_other: bool = not main.interaction_system._place_ok(other)
	var st: Dictionary = other.mp_state()
	var copy := Tower.new()
	copy.main = main
	copy.mp_apply(st)
	var synced: bool = copy.req_e == Elem.WATER
	copy.free()
	mine.req_e = Elem.WATER
	main.lobby_system._mp_recv_gift(2, {"nid": mine.net_id, "e": Elem.WATER, "lv": 1})
	var given: bool = mine.lv(Elem.WATER) == 1 and mine.req_e == -1 and main.lobby_system.mp_req_got_w == main.wave
	main.lobby_system._mp_recv_gift(2, {"nid": mine.net_id, "e": Elem.ICE, "lv": 1})
	var no_req: bool = mine.lv(Elem.ICE) == 0
	ok("MP-16", can_req and cant_other and synced and given and no_req,
		"속성 요청: 요청 속성 넣기 %s, 다른 속성 막힘 %s, 상태 주고받기 %s, 받음 %s, 요청 없으면 안 들어감 %s" % [can_req, cant_other, synced, given, no_req])
	main.picked = {}

	# MP-17: 대결 보낸 구체 — 살아 있는 인원 4명 x0.5·3명 x0.7, 한 웨이브 받는 상한 (1+웨이브/4)x1.5
	_fresh(3)
	main.mp_mode = "vs"
	main.mp.my_id = 1
	main.mp_others = {}
	for id in [2, 3, 4]:
		main.mp_others[id] = {"name": "", "w": 3, "hp": 10, "mx": 10, "sc": id * 10, "alive": true, "gone": false}
	var k4: float = main.multiplayer_system._mp_send_k()
	main.mp_others[4]["alive"] = false
	var k3: float = main.multiplayer_system._mp_send_k()
	var tgt: int = main.multiplayer_system._mp_vs_target([3])
	main.phase = main.Phase.CHOOSE
	main.mp_recv_n = 0
	main.mp_next_extra = 0
	main.multiplayer_system._mp_packet(2, {"t": "atk", "n": 5})
	var capped: bool = main.mp_recv_n == 3 and main.mp_next_extra == 3
	ok("MP-17", is_equal_approx(k4, 0.5) and is_equal_approx(k3, 0.7) and tgt == 2 and capped,
		"대결: 4명 x%.1f, 3명 x%.1f, 받는 사람 %d, 5개 중 받은 %d (상한 3)" % [k4, k3, tgt, main.mp_next_extra])
	main.mp_others = {}
	main.mp_next_extra = 0
	main.mp_recv_n = 0
	main.mp_mode = ""
	main.mp.my_id = 0
	main.mp_tw_n = 0
	main.coop_n = 1
	_clear()


# ---------- 문서 대조 ----------

# ---------- 튜토리얼 ----------

func _tutorial() -> void:
	# TUT-01: 첫 소개 완료와 상세 항목 열람을 기기 파일에서 분리한다.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PATH))
	Tutorial.load_file()
	var first := Tutorial.need_first()
	main.tut.open_welcome()
	var showed: bool = main.tut.visible and main.tut.mode == "welcome" and main.tut.queue.is_empty() and main.tut.btn_next.text == "플레이하며 배우기"
	main.tut.close()
	Tutorial.done = false
	Tutorial.seen = {}
	Tutorial.load_file()
	var after := not Tutorial.need_first() and Tutorial.seen.is_empty()
	main.tut.open_welcome()
	main.tut._close_or_details()
	var optional: bool = main.tut.mode == "pages" and Tutorial.seen.has("goal") and not Tutorial.seen.has("place")
	main.tut.close()
	main.progression_system._save_best()
	var best := ConfigFile.new()
	best.load(Meta.SAVE_PATH)
	var prog := JSON.stringify(Progress.build())
	ok("TUT-01", Tutorial.PATH == "user://device.cfg" and first and showed and after and optional and not best.has_section("tutorial") and not prog.contains("tutorial"),
		"첫 목표 한 문장 %s, 소개 완료와 설명 열람 분리 %s, 선택형 설명 %s, 기기 파일만 사용" % [showed, after, optional])
	# TUT-02: 수동 상세 항목 15개, id·그림·터치 문구·안내 연결 목록 정합성
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
	ok("TUT-02", Tutorial.TOPICS.size() == 15 and ids.size() == 15 and bad.is_empty(), "항목 %d개, 문제 %s" % [ids.size(), str(bad)])
	# 자동 이벤트는 더 이상 모달을 예약하거나 읽음으로 기록하지 않는다.
	Tutorial.seen = {}
	main.onboarding_system.tut_queue.clear()
	Meta.guide_on = true
	main.mp_mode = ""
	main.wave = 4
	Meta.guide_seen.erase("boss")
	Meta.guide_seen.erase("mod")
	main.guide_lines.clear()
	main.onboarding_system._tut_event("pat")
	main.onboarding_system._guide("boss", "보스 안내")
	main.onboarding_system._guide("mod", "일반 안내")
	var keep_pointer: Vector2 = main.interaction_system.pointer_position
	main.guide_label.show()
	main.guide_more.show()
	var probe := _tower(main.viewport_system.center() + Vector2(140, -100))
	main.onboarding_system.suppress_guide_for_object(main.get_canvas_transform() * probe.position)
	ok("TUT-03", not main.guide_label.visible and not main.guide_more.visible and not paused, "오브젝트 위 안내·더 알아보기는 숨겨 선택 입력 우선")
	probe.free()
	main.interaction_system.pointer_position = keep_pointer
	var single: bool = main.guide_lines.size() == 1 and main.guide_lines[0].contains("보스") and not Meta.guide_seen.has("mod")
	var quiet: bool = main.onboarding_system.tut_queue.is_empty() and Tutorial.seen.is_empty() and not paused
	Meta.guide_on = false
	main.frame_system._process(0.0)
	var hidden_off: bool = not main.guide_label.visible and not main.guide_more.visible and not main.guide_lines.is_empty()
	Meta.guide_on = true
	main.tut_paused = true
	paused = true
	main.onboarding_system._open_tut(["pat"])
	var marked := Tutorial.seen.has("pat")
	main.tut._next()
	main.tut._next()
	var resumed: bool = not main.tut.visible and not paused and not main.tut_paused
	paused = false
	ok("TUT-03", single and quiet and marked and resumed and hidden_off, "단일 안내·경고 우선 %s, 자동 모달 없음 %s, 직접 열람만 기록 %s·닫으면 복귀 %s" % [single, quiet, marked, resumed])
	var games0 := Meta.games
	Meta.games = 0
	main.wave = 0
	main.phase = main.Phase.CHOOSE
	main.perk_mode = false
	main.cards_hidden = false
	main.touch_ui = true
	main.tap_sel = 0
	var preview: bool = main.onboarding_system._first_action_text().contains("고르세요")
	main.tap_sel = -1
	main.picked = {"type":"elem", "e":Elem.WATER, "lv":1}
	main.phase = main.Phase.PLACE
	var place: bool = main.onboarding_system._first_action_text().contains("빈 곳")
	main.phase = main.Phase.AIM
	var aim: bool = main.onboarding_system._first_action_text().contains("방향")
	main.interaction_system._cancel_step()
	var cancel: bool = main.phase == main.Phase.PLACE and main.onboarding_system._first_action_text().contains("빈 곳")
	main.phase = main.Phase.READY
	var ready: bool = main.onboarding_system._first_action_text() == "웨이브를 시작하세요."
	main.wave = 1
	var finished: bool = main.onboarding_system._first_action_text() == ""
	main.wave = 0
	Meta.games = 1
	main.tutor = false
	var veteran: bool = main.onboarding_system._first_action_text() == ""
	main.tutor = true
	var reset: bool = main.onboarding_system._first_action_text().contains("웨이브")
	Meta.guide_on = false
	var off: bool = main.onboarding_system._first_action_text() == ""
	Meta.guide_on = true
	Meta.games = games0
	main.tutor = false
	main.touch_ui = false
	# AIM-01: 터치 조준은 누르는 순간 확정하지 않고, 뗀 뒤 붙잡아 둔 방향으로 [확정]
	main.touch_ui = true
	main.interaction_system.moving = null
	main.phase = main.Phase.AIM
	main.place_pos = main.viewport_system.core() + Vector2(200, 0)
	main.interaction_system._aim_begin()
	var no_btn: bool = not main.interaction_system._ok_btn_on()
	main.aim_d = Vector2.UP
	main.aim_wait = true
	var held_dir: bool = main.field_view_system._aim_dir(main.place_pos) == Vector2.UP and main.interaction_system._ok_btn_on() and main.aim_ok_btn.text == "확정"
	main.interaction_system.aim_hold = true
	var held_near: bool = main.interaction_system._pointer_world().distance_to(main.place_pos) >= main.AIM_TOUCH_MIN or main.field_view_system._aim_dir(main.place_pos) == Vector2.UP
	main.interaction_system.aim_hold = false
	main.phase = main.Phase.PLACE
	main.touch_ui = false
	ok("AIM-01", no_btn and held_dir and held_near, "터치 조준: 새로 놓기는 방향 전 [확정] 없음, 뗀 뒤 붙잡은 방향·[확정], 오브젝트 가까이 누르면 방향 유지")
	ok("TUT-06", preview and place and aim and cancel and ready and finished and veteran and reset and off, "첫 행동: 터치 확정·설치·방향·취소·시작을 실제 상태에 따라 안내")
	# TUT-04: 시작 화면·일시정지의 [튜토리얼] 버튼, 목록 15개 + 전체 보기, ✓, 항목 → 카드 → 목록으로, 전체 보기 → 도움말
	var title_btn := false
	for b in main.title_box.find_children("*", "Button", true, false):
		if (b as Button).pressed.is_connected(main.onboarding_system._open_tut_list):
			title_btn = true
	var pause_btn := false
	for b in main.pause_box.get_children():
		if (b as Button).pressed.is_connected(main.onboarding_system._open_tut_list):
			pause_btn = true
	Tutorial.seen = {"goal": true}
	main.onboarding_system._open_tut_list()
	var g: GridContainer = main.tut.grid
	var listed: bool = main.tut.mode == "list" and g.get_child_count() == 16 and (g.get_child(0) as Button).text.ends_with("✓") and not (g.get_child(1) as Button).text.ends_with("✓")
	(g.get_child(4) as Button).pressed.emit()
	var opened: bool = main.tut.mode == "pages" and main.tut.cur_topic()["id"] == Tutorial.TOPICS[4]["id"]
	for i in 5:
		main.tut._next()
	var back: bool = main.tut.visible and main.tut.mode == "list"
	(main.tut.grid.get_child(15) as Button).pressed.emit()
	var helped: bool = not main.tut.visible and main.help_label.visible
	main.help_label.visible = false
	ok("TUT-04", title_btn and pause_btn and listed and opened and back and helped, "시작 화면 %s, 일시정지 %s, 목록 %s, 항목 열기 %s, 목록으로 %s, 전체 보기 %s" % [title_btn, pause_btn, listed, opened, back, helped])
	_tut_play()


## 플레이 튜토리얼 (흐름 전체는 tools/run.sh tutplay)
func _tut_play() -> void:
	# TUT-07: 4장 23단계, 장 첫 단계, 카드 단계의 카드가 실제 카드, 쉬는 시간 고르는 수, 정해진 길목
	var ids := {}
	var bad := []
	for i in TutPlay.STEPS.size():
		var st: Dictionary = TutPlay.STEPS[i]
		ids[st["id"]] = true
		if st.has("card"):
			var cd: Dictionary = st["card"]
			var known: bool = cd["type"] == "elem" and cd["e"] in Elem.ALL or cd["type"] == "pat" and cd["id"] in Pat.PATTERN_IDS \
				or cd["type"] == "mod" and cd["id"] in Pat.MOD_IDS or cd["type"] == "trig" and cd["id"] in Pat.TRIG_IDS or cd["type"] == "link" and cd["id"] in Pat.LINK_IDS
			if not known:
				bad.append(st["id"] + ":카드")
	for c in TutPlay.CHAPTERS.size():
		if TutPlay.STEPS[TutPlay.CH_START[c]]["ch"] != c or TutPlay.CH_START[c] > 0 and TutPlay.STEPS[TutPlay.CH_START[c] - 1]["ch"] == c:
			bad.append("장 %d 시작" % (c + 1))
	var tp := TutPlay.new()
	tp.m = main
	var picks: bool = tp.rest_picks(0) == 1 and tp.rest_picks(1) == 2 and tp.rest_picks(2) == 2 and tp.rest_picks(3) == 2 and tp.rest_picks(4) == -1
	var lanes: bool = TutPlay.lanes_for(1) == [0.0] and TutPlay.lanes_for(3).size() == 2 and TutPlay.lanes_for(6).size() == 3
	_fresh(1)
	_tower(main.viewport_system.core() + Vector2(170, 0))
	tp.idx = 7  # 속성 겹치기
	var water := {"type": "elem", "e": Elem.WATER, "lv": 1}
	var offer: Array = tp.offer([{"type": "elem", "e": Elem.ICE, "lv": 1}, {"type": "elem", "e": Elem.EARTH, "lv": 1}, water])
	var fixed: bool = offer.size() == 3 and offer[1] == water and tp.want_card() == water
	var refuse: bool = not tp.allow_pick(offer[0]) and tp.allow_pick(water)
	main.picked = water
	var place_ok: bool = not tp.allow_place(null) and tp.allow_place(main.towers.get_child(0))
	main.picked = {}
	_clear()
	tp.free()
	ok("TUT-07", TutPlay.STEPS.size() == 23 and ids.size() == 23 and TutPlay.CHAPTERS.size() == 4 and bad.is_empty() and picks and lanes and fixed and refuse and place_ok and not ids.has("path") and not ids.has("garden"),
		"단계 %d·장 %d, 문제 %s, 고르는 수 %s, 길목 %s, 정해진 카드·흐린 카드 %s·%s, 놓을 곳 %s" % [ids.size(), TutPlay.CHAPTERS.size(), str(bad), picks, lanes, fixed, refuse, place_ok])
	# TUT-08: 단계마다 이름·글, 터치 글엔 키·클릭 말 없음, 안내 칸 버튼
	var words := []
	for st in TutPlay.STEPS:
		if st["id"] == "end":
			continue
		var tt: String = st.get("touch", st["pc"])
		if st["name"] == "" or st["pc"] == "":
			words.append(st["id"] + ":빈 글")
		for w in ["클릭", "Shift", "Esc", "Alt", "휠", "Space", "Tab", "(Z)", "(S)", "Q로", "V로", "P로", "1·2"]:
			if tt.contains(w):
				words.append(st["id"] + ":" + w)
	var tp2 := TutPlay.new()
	tp2.m = main
	tp2._build_panel()
	var btns: bool = tp2.btn_skip != null and tp2.btn_all != null and tp2.btn_ok != null
	tp2.free()
	ok("TUT-08", words.is_empty() and btns, "터치 글 문제 %s, 건너뛰기·전체 건너뛰기 버튼 %s" % [str(words), btns])
	# TUT-09: 목록 맨 위 처음부터 + 장 4개, 첫 소개 [건너뛰기]
	main.onboarding_system._open_tut_list()
	var row: int = main.tut.play_row.get_child_count()
	var asked := [-1]
	var cb := func(ch): asked[0] = ch
	main.tut.play_requested.disconnect(main.onboarding_system._play_tutorial)
	main.tut.play_requested.connect(cb)
	(main.tut.play_row.get_child(3) as Button).pressed.emit()
	var chosen: bool = asked[0] == 2 and not main.tut.visible
	main.tut.open_welcome()
	var skip_btn: bool = main.tut.btn_list.visible and main.tut.btn_list.text == "건너뛰기"
	main.tut._list_or_skip()
	var closed: bool = not main.tut.visible
	main.tut.play_requested.disconnect(cb)
	main.tut.play_requested.connect(main.onboarding_system._play_tutorial)
	var starts: bool = TutPlay.CH_START == [0, 7, 16, 21]
	ok("TUT-09", row == 5 and chosen and skip_btn and closed and starts, "목록 맨 위 %d개, 3장 버튼 → 장 %d, 첫 소개 [건너뛰기] %s·닫힘 %s" % [row, asked[0], skip_btn, closed])
	# TUT-10: 연습 판 설정 바꾸기·되돌리기, 저장은 원래 값, 이어하기·업적 없음
	var keep := [Meta.map_id, Meta.rules, Array(Meta.modes), Meta.skill_set, Meta.skip_n]
	Meta.map_id = "cross"
	Meta.rules = 3
	Meta.skill_set = 2
	TutPlay.enter_meta()
	var inside: bool = TutPlay.on and Meta.map_id == "plain" and Meta.rules == 1 and Meta.skill_set == 0 and Modes.on.is_empty() and Ach.mp == "tut"
	TutPlay.swap()
	var swapped: bool = Meta.map_id == "cross" and Meta.rules == 3
	TutPlay.swap()
	var back_in: bool = Meta.map_id == "plain"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.RUN_PATH))
	main.phase = main.Phase.CHOOSE
	main.persistence_system._save_run()
	var no_run: bool = not FileAccess.file_exists(main.RUN_PATH)
	var ach0 := Meta.achieved.size()
	main.progression_system._achieve("first")
	var no_ach: bool = Meta.achieved.size() == ach0
	TutPlay.leave_meta()
	var out: bool = not TutPlay.on and Meta.map_id == "cross" and Meta.rules == 3 and Meta.skill_set == 2 and Ach.mp == ""
	Meta.map_id = keep[0]
	Meta.rules = keep[1]
	Meta.modes = keep[2]
	Meta.skill_set = keep[3]
	Meta.skip_n = keep[4]
	ok("TUT-10", inside and swapped and back_in and no_run and no_ach and out, "연습 판 설정 %s, 저장은 원래 값 %s·%s, 이어하기 없음 %s, 업적 없음 %s, 되돌림 %s" % [inside, swapped, back_in, no_run, no_ach, out])


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
	var rk: Array = main.menu_system._vote_run_keys()
	v.open(rk)
	var run_tab: bool = v.cat == "run" and v._entries("run").size() == 2
	# 이름이 같은 카드(강화 속사·특성 속사)는 이번 판 탭에서 갈래로 구분
	main.run_log = [{"w": 0, "k": "card", "p": "mod:rapid"}, {"w": 1, "k": "perk", "p": "perk:haste"}]
	v.open(main.menu_system._vote_run_keys())
	var rx: Array = v._entries("run")
	var same_name: bool = rx.size() == 2 and rx[0]["name"] == rx[1]["name"] and rx[0]["sub"] != rx[1]["sub"] and rx[0]["sub"] != ""
	# 서버에 못 닿으면 '불러오는 중'에 멈추지 않고 안내 + [다시 시도] (기록 보내기를 끈 경우는 설정 안내)
	v.load_votes(true)
	var retry: bool = not v.loading and not v.can_vote and v.retry_btn.visible == Meta.online_on and not v.status.text.contains("불러오는")
	run_tab = run_tab and same_name and retry
	v.visible = false
	v.dirty = false
	main.run_log = []
	# 투표 API가 없는 서버면 버튼이 없다 (헤드리스는 서버에 닿지 않음)
	var hidden: bool = not Net.vote_ok() and (main.vote_btn == null or not main.vote_btn.visible)
	ok("ONLINE-04", bad.is_empty() and has_all and r1 and r2 and r3 and full and note_ok and pl_ok and no_vote and run_tab and hidden,
		"다음 패치 투표: 항목 %d개 키 모양(틀림 %s), 표 5장·방향 하나·다시 누르면 취소·개선 의견 60자, 자격 없으면 못 넣음, 판 끝 화면은 이번 판 탭, 서버에 투표 없으면 버튼 숨김" % [keys.size(), str(bad)])


## 리더보드 필터: 맵·규칙·기록·시즌 칩을 모두 펼쳐 한 번 눌러 고르고, 순위 표는 시즌 전체/이번 주 탭
func _board_filters() -> void:
	var keep_map: String = Meta.map_id
	main.leaderboard_system._toggle_board()
	main.leaderboard_system._on_seasons_loaded([{"id": 3, "name": "시즌 3"}, {"id": 2, "name": "시즌 2"}])
	var ch: Dictionary = main.leaderboard_system.board_chips
	var counts: bool = ch["map"].get_child_count() == Meta.MAP_IDS.size() and ch["rules"].get_child_count() == Rules.IDS.size() \
		and ch["kind"].get_child_count() == 2 and ch["season"].get_child_count() == 2
	# 소용돌이 칩 한 번 → 바로 그 맵, 쉽게 모드 칩 → 쉽게 기록
	ch["map"].get_child(Meta.MAP_IDS.find("spiral")).pressed.emit()
	ch["kind"].get_child(1).pressed.emit()
	var picked: bool = main.leaderboard_system.board_map == "spiral" and main.leaderboard_system.board_easy

	# 이번 주 탭 → 지난 시즌 칩을 누르면 시즌 전체만 (이번 주 탭 숨김)
	main.leaderboard_system.board_period_btns[1].pressed.emit()
	var week: bool = main.leaderboard_system.board_period == "week"
	ch["season"].get_child(1).pressed.emit()
	var old: bool = main.leaderboard_system.board_season == 2 and main.leaderboard_system.board_period == "all" and not main.leaderboard_system.board_period_btns[1].visible
	# 표: 받은 순위가 줄마다, 내 줄은 '나'
	main.leaderboard_system._on_board_loaded({"tag": main.leaderboard_system._board_tag(), "period": "all", "entries": [{"rank": 1, "nick": "가나", "wave": 9, "score": 100}, {"rank": 2, "nick": "다라", "wave": 8, "score": 90, "me": true}]})
	var rows: bool = main.leaderboard_system.board_rows.get_child_count() == 2 and main.leaderboard_system._board_text().contains("가나") and main.leaderboard_system._board_text().contains("나")
	var ugc: bool = main.leaderboard_system.board_ugc_btn.visible and main.leaderboard_system.board_ugc_btn.is_visible_in_tree()
	main.leaderboard_system._toggle_board()
	var closed: bool = not main.records_panel.visible
	Meta.map_id = keep_map
	ok("ONLINE-07", counts and picked and week and old and rows and ugc and closed,
		"리더보드 필터 칩(맵 %d·규칙·기록 3·시즌), 한 번 눌러 고름 %s, 이번 주 탭 %s, 지난 시즌이면 전체만 %s, 표 %s, [신고·차단] %s, 닫기 %s" % [Meta.MAP_IDS.size(), picked, week, old, rows, ugc, closed])


## 닉네임 거르기·신고·차단·데이터 지우기 (App Store 1.2·5.1.1(v))
func _ugc() -> void:
	var filt: bool = NickFilter.bad("시 발") and NickFilter.bad("FuCk_you") and NickFilter.bad("개1새끼") and NickFilter.bad("운영자") \
		and not NickFilter.bad("별빛") and not NickFilter.bad("Tester") and not NickFilter.bad("grape") and not NickFilter.bad("")
	var keep: Dictionary = Meta.blocked.duplicate()
	Meta.blocked = {"aaaaaaaaaaaaaaaa": "나쁜이름"}
	main.records_panel.visible = true
	main.board_box.visible = true
	main.leaderboard_system.board_raw = {}
	main.leaderboard_system.board_people = {}
	var tag: String = main.leaderboard_system._board_tag()
	main.leaderboard_system._on_board_loaded({"tag": tag, "period": "all", "season": {"name": "s"}, "entries": [
		{"rank": 1, "nick": "나쁜이름", "wave": 9, "score": 100, "pid": "aaaaaaaaaaaaaaaa"},
		{"rank": 2, "nick": "착한이름", "wave": 8, "score": 90, "pid": "bbbbbbbbbbbbbbbb"},
		{"rank": 3, "nick": "나", "wave": 7, "score": 80, "pid": "cccccccccccccccc", "me": true}]})
	var txt: String = main.leaderboard_system._board_text()
	var hide_ok: bool = txt.contains("(차단한 플레이어)") and not txt.contains("나쁜이름") and txt.contains("착한이름")
	var people_ok: bool = main.leaderboard_system.board_people.size() == 2 and main.leaderboard_system.board_ugc_btn.visible
	main.leaderboard_system._board_ugc_open()
	var btns: Array = main.board_ugc_panel.find_children("*", "Button", true, false)
	var reps: Array = btns.filter(func(b): return b.text == "신고")
	var unblock: Array = btns.filter(func(b): return b.text == "차단 풀기")
	var panel_ok: bool = main.board_ugc_panel.visible and reps.size() == 2 and unblock.size() == 1 and reps.all(func(b): return b.disabled == not Net.report_ok())
	# 차단 풀기 → 이름이 다시 보임
	unblock[0].pressed.emit()
	var unblock_ok: bool = not Meta.blocked.has("aaaaaaaaaaaaaaaa") and main.leaderboard_system._board_text().contains("나쁜이름")
	main.board_ugc_panel.visible = false
	main.records_panel.visible = false
	main.board_box.visible = false
	Meta.blocked = keep
	main.progression_system._save_best()
	# 설정의 [내 온라인 데이터 지우기] (서버 주소가 있는 빌드)
	var del_ok: bool = OnlineConfig.SERVER_URL == "" or main.settings_panel.find_children("*", "Button", true, false).any(func(b): return b.text == "내 온라인 데이터 지우기")
	ok("ONLINE-06", filt and hide_ok and people_ok and panel_ok and unblock_ok and del_ok,
		"닉네임 거르기, 리더보드 차단한 사람 이름 가림·[신고·차단] 창(신고는 서버 report 있을 때만)·차단 풀기, 설정 데이터 지우기 버튼")


## UI-37: 실제 공격·렌더링·누적 상태를 통합 인스펙터에서 격리해 표시한다.
func _attack_preview() -> void:
	_fresh()
	var t := _tower(Vector2(250, 300), Elem.WATER, 2)
	t.add(Elem.POISON, 2)
	var preview: AttackPreview = main.card_dock.pic.attack_preview
	preview.configure(t)
	var hp: int = main.core_hp
	var score: int = main.score
	var dealt := t.dealt
	var count: int = main.orbs.get_child_count()
	for frame in 120: preview.advance(1.0 / 30.0)
	var hit: bool = preview.clone.dealt > 0.0
	var effects := false
	for orb in preview.world.orbs.get_children():
		effects = effects or orb.poison_t > 0.0 or orb.slow_timer > 0.0
	ok("UI-37", hit and effects and preview.world.wave_active, "실제 공격·명중 경로로 미리보기 표적에 감속·중독 적용")
	ok("UI-37", hp == main.core_hp and score == main.score and dealt == t.dealt and count == main.orbs.get_child_count(), "미리보기 피해·구체·점수는 실제 판과 격리")
	t.trigs = {"charge": 2, "third": 2}
	t.charge = 3.0
	t.third_n = 2
	t.dir = Vector2.UP
	var ally := _tower(t.position + Vector2(30, 0), Elem.FIRE)
	preview.configure(t)
	ok("UI-37", preview.clone.charge == 3.0 and preview.clone.third_n == 2 and preview.clone.dir == t.dir and preview.copies.has(ally.get_instance_id()), "현재 축적·삼연·방향·주변 배치를 미리보기에 복사")
	for frame in 60: preview.advance(1.0 / 60.0)
	var quiet: bool = true
	for peer in preview.world.towers.get_children():
		if peer != preview.clone: quiet = quiet and not peer.visible and peer.dealt == 0.0
	ok("UI-37", quiet and preview.clone.side_n == 0 and preview.clone.dealt > 0.0, "활성 오브젝트만 공격·표시하고 보조 공격은 제외")
	preview.signature = ""
	preview.configure(t)
	preview.clone.charge = 0.0
	var slot := 0
	for orb in preview.world.orbs.get_children():
		orb.position = preview.clone.position + preview.clone.dir * (60.0 + 8.0 * slot)
		orb.hp = 0.0
		slot += 1
	preview.advance(1.0 / 60.0)
	var charged: bool = preview.clone.charge == 5.0
	var same: int = preview.clone.get_instance_id()
	preview.elapsed = 8.1
	preview.advance(0.5)
	ok("UI-37", charged and preview.clone.get_instance_id() == same and preview.clone.charge == 5.0 and preview.cycle == 2, "처치로 축적 증가, 8초 뒤에도 상태 유지하며 표적만 보충")
	preview.source = null
	_clear()


func _combination_inspector() -> void:
	_fresh()
	var t := _tower(main.viewport_system.center() + Vector2(-200, -120), Elem.FIRE)
	main.phase = main.Phase.PLACE
	main.picked = {"type": "elem", "e": Elem.ELECTRIC, "lv": 1}
	main.card_dock.close_inspector(true)
	main.interaction_system._place_on(t)
	main.card_dock._update_side()
	ok("UI-37", not main.card_dock.side.visible and not t.new_reactions.is_empty() and not "rx_card" in main, "새 조합은 NEW로 남기고 X 닫힘은 유지")
	main.cards_system._set_card_detail(true)
	main.interaction_system._select_tower(t)
	main.card_dock._update_side()
	ok("UI-37", main.card_dock.side.visible and "NEW" in main.card_dock.detail.text and main.card_dock.pic.attack_preview.source == t, "인스펙터에서 현재 공격과 NEW 조합 설명 통합")
	main.card_dock.pic._process(6.1)
	main.card_dock._update_side()
	ok("UI-37", t.new_reactions.is_empty() and not "NEW" in main.card_dock.detail.text, "인스펙터 열람 후 NEW 해제")
	_clear()


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


## 후반 구체 다섯 종 (ORB-03)
func _late_orbs() -> void:
	var froms: Array = [main.late_from("blink"), main.late_from("armor"), main.late_from("mender"), main.late_from("phase"), main.late_from("devour")]
	var share_ok: bool = main.late_share("blink", 99) == 0.0 and is_equal_approx(main.late_share("blink", 100), 0.08) and is_equal_approx(main.late_share("blink", 400), 0.2)
	# 깜빡: 3.5초 뒤 90px 앞으로, 기절 중엔 안 뜀
	var c: Vector2 = main.viewport_system.center()
	var b := _orb(c + Vector2(500, 0), 10.0, Orb.Kind.NORMAL, 0.0)
	b.late = "blink"
	b.late_t = 3.5
	b.root_timer = 10.0
	for i in 240: b.step(1.0 / 60.0)
	var held := b.position.distance_to(c + Vector2(500, 0)) < 1.0
	b.root_timer = 0.0
	for i in 211: b.step(1.0 / 60.0)
	var jumped := is_equal_approx(roundf(b.position.x), c.x + 410.0)
	# 갑옷: 직접 피해에서 갑옷만큼, 최소 30%, 맞을수록 깨짐
	var a := _orb(c + Vector2(300, 200), 1000.0)
	a.late = "armor"
	a.armor = 10.0
	var d1 := a.late_direct(12.0)  # 12 - 10 = 2 → 최소 3.6
	var d2 := a.late_direct(100.0)  # 100 - 9.8
	for i in 100: a.late_direct(100.0)
	var d3 := a.late_direct(100.0)  # 깨짐은 절반까지: 100 - 5
	var armor_ok := is_equal_approx(d1, 3.6) and is_equal_approx(d2, 90.2) and is_equal_approx(d3, 95.0)
	# 치유: 주변 구체 6%, 화상이면 절반
	var m := _orb(c + Vector2(-300, 200), 10.0)
	m.late = "mender"
	m.late_t = 0.01
	var n1 := _orb(c + Vector2(-260, 200), 100.0)
	var n2 := _orb(c + Vector2(-300, 240), 100.0)
	n1.hp = 50.0
	n2.hp = 50.0
	n2.burn(0.0001, 10.0)
	main.combat_system._resolve(0.0)  # 격자
	m.step(0.02)
	var heal_ok := is_equal_approx(n1.hp, 56.0) and absf(n2.hp - 53.0) < 0.01
	# 흐림: 흐린 동안 직접 피해 30%
	var ph := _orb(c + Vector2(-300, -200), 10.0)
	ph.late = "phase"
	ph.late_t = 0.0
	var solid := ph.late_direct(10.0)
	ph.late_t = 3.0
	var ghost := ph.late_direct(10.0)
	var phase_ok := is_equal_approx(solid, 10.0) and is_equal_approx(ghost, 3.0)
	# 포식: 닿은 구체를 삼켜 남은 체력 50%, 중앙 피해 +1
	var dv := _orb(c + Vector2(0, -250), 30.0)
	dv.late = "devour"
	var prey := _orb(c + Vector2(5, -250), 20.0)
	main.combat_system._resolve(0.0)
	dv.step(0.01)
	var dev_ok := prey.is_queued_for_deletion() and is_equal_approx(dv.max_hp, 40.0) and dv.core_dmg == 2 and dv.eaten == 1
	# 안내: 처음 나오는 웨이브에 NEW
	main.wave = 99
	main.waves_system._update_preview()
	var fresh: bool = main.wave_kinds.any(func(k): return k[0] == "blink" and k[2])
	main.wave = 5
	ok("ORB-03", froms == [100, 175, 250, 350, 500] and share_ok and held and jumped and armor_ok and heal_ok and phase_ok and dev_ok and fresh,
		"후반 구체: 등장 %s 비율 %s 깜빡 %s/%s 갑옷 %s(%.1f·%.1f·%.1f) 치유 %s(%.1f·%.1f) 흐림 %s 포식 %s 안내 %s" % [str(froms), share_ok, held, jumped, armor_ok, d1, d2, d3, heal_ok, n1.hp, n2.hp, phase_ok, dev_ok, fresh])


## 방해 구체 (JAM-01~04)
func _jam_orbs() -> void:
	_fresh(25)
	var c: Vector2 = main.viewport_system.center()
	var froms := [main.jam_from("shade"), main.jam_from("leech"), main.jam_from("seeker")]
	var share_ok: bool = main.jam_share("shade", 19) == 0.0 and is_equal_approx(main.jam_share("shade", 20), 0.05) and is_equal_approx(main.jam_share("shade", 40), 0.07) and is_equal_approx(main.jam_share("shade", 300), 0.12)
	main.mp_mode = "vs"
	var mp_off: bool = not main.spawning_system.jams_on()
	main.mp_mode = ""
	var fresh := false
	main.wave = 19
	main.waves_system._update_preview()
	fresh = main.wave_kinds.any(func(k): return k[0] == "shade" and k[2])
	main.wave = 25
	ok("JAM-01", froms == [20, 30, 40] and share_ok and mp_off and main.spawning_system.jams_on() and fresh, "등장 %s 비율 %s 멀티 끔 %s 안내 NEW %s" % [str(froms), share_ok, mp_off, fresh])
	# 그림자: 80 안 오브젝트 1.5초 멈춤, 풀린 뒤 4초 면역, 침묵이면 못 함
	var t := _tower(c + Vector2(-200, 0), Elem.FIRE)
	var far := _tower(c + Vector2(200, 0), Elem.FIRE)
	var sh := _orb(c + Vector2(-200, 60), 50.0)
	sh.jam = "shade"
	main.jam_any = true
	main.combat_system._resolve(0.0)
	main.spawning_system._jam_tick()
	var stopped := is_equal_approx(t.jam_t, 1.5) and far.jam_t == 0.0
	t.jam_t = 0.0
	main.spawning_system._jam_tick()
	var imm := t.jam_t == 0.0 and t.jam_imm > 0.0
	t.jam_imm = 0.0
	sh.silence_t = 2.0
	main.spawning_system._jam_tick()
	var quiet := t.jam_t == 0.0
	# 멈춘 동안 공격하지 않는다 (직선탄이 안 나감)
	t.jam_t = 1.0
	t.dir = Vector2.DOWN
	var np: int = main.projectiles.get_child_count()
	t.attack(0.5, main.combat_system.targets)
	var no_shot: bool = main.projectiles.get_child_count() == np and is_equal_approx(t.jam_t, 0.5)
	ok("JAM-02", stopped and imm and quiet and no_shot, "그림자: 멈춤 %s 면역 %s 침묵 %s 멈춘 동안 공격 없음 %s" % [stopped, imm, quiet, no_shot])
	# 흡수: 맞힐 때마다 공격 속도 -5%(0.5초에 한 겹, 최대 5), 잡으면 300 안 오브젝트 풀림
	sh.free()
	t.jam_t = 0.0
	var lc := _orb(c + Vector2(-200, 40), 1000.0)
	lc.jam = "leech"
	var k0 := t.spd_k()
	t.hit(lc, 1.0)
	t.hit(lc, 1.0)
	var one := t.leech_n == 1 and is_equal_approx(t.spd_k(), k0 * 0.95)
	for i in 10:
		t.leech_t = 0.0
		t.hit(lc, 1.0)
	var cap := t.leech_n == 5
	main.spawning_system._jam_death(lc)
	var freed := t.leech_n == 0
	ok("JAM-03", one and cap and freed, "흡수: 한 겹 %s 최대 5 %s 잡으면 풀림 %s" % [one, cap, freed])
	# 표적: 가장 가까운 오브젝트를 쫓고, 닿으면 그 오브젝트 3초 멈춤·사라짐
	lc.free()
	t.jam_imm = 0.0
	t.jam_t = 0.0
	main.wave = 45
	var sk: Orb = null
	for i in 400:
		var o := Orb.new()
		o.main = main
		o.position = c + Vector2(-500, 0)
		o.target = c
		o.setup(Orb.Kind.NORMAL, 5000.0, 40.0)  # 오브젝트 공격에 바로 죽지 않게
		main.spawning_system._jam_trait(o)
		if o.jam == "seeker":
			sk = o
			break
		o.free()
	var aimed: bool = sk != null and sk.jam_tower == t and sk.target == t.position
	var hit_ok := false
	if sk:
		main.orbs.add_child(sk)
		sk.position = t.position + Vector2(10, 0)
		main.combat_system._resolve(0.0)
		main.spawning_system._jam_tick()
		hit_ok = is_equal_approx(t.jam_t, 3.0) and sk.is_queued_for_deletion()
	main.wave = 25
	ok("JAM-04", aimed and hit_ok, "표적: 가까운 오브젝트 쫓음 %s 닿으면 멈춤·사라짐 %s" % [aimed, hit_ok])
	main.jam_any = false
	_clear()


## 중앙 기술 (SKILL-01~05)
func _skills() -> void:
	_fresh(12)
	var c: Vector2 = main.viewport_system.center()
	main.abilities_system._skills_new_run(1)
	var set_ok: bool = main.skill_ids == ["focus", "brand"] and Skill.SETS.size() == 3
	main.mp_mode = "coop"
	main.abilities_system._skills_new_run(0)
	var mp_off: bool = main.skill_ids.is_empty()
	main.mp_mode = ""
	main.abilities_system._skills_new_run(0)
	ok("SKILL-01", set_ok and mp_off and main.skill_ids == ["focus", "hold"], "묶음 3개 중 고른 둘 %s, 멀티는 없음 %s" % [set_ok, mp_off])
	main.phase = main.Phase.WAVE
	var t := _tower(c + Vector2(-150, 0), Elem.FIRE)
	var k0 := t.spd_k()
	var used: bool = main.abilities_system._use_skill("focus", t.position + Vector2(20, 10))
	var fast := is_equal_approx(t.spd_k(), k0 * 2.0) and is_equal_approx(t.focus_t, 6.0)
	var cd_ok: bool = is_equal_approx(main.abilities_system.skill_left("focus"), 25.0) and not main.abilities_system._use_skill("focus", t.position)
	var miss: bool = not main.abilities_system._use_skill("hold", c + Vector2(400, 300)) and main.abilities_system.skill_left("hold") == 0.0
	main.abilities_system._skill_tick(10.0)
	var ticked: bool = is_equal_approx(main.abilities_system.skill_left("focus"), 15.0)
	ok("SKILL-02", used and fast and cd_ok and miss and ticked, "집중: 공속 x2 6초 %s, 다시 쓰기 25초 %s, 빈 곳엔 안 씀 %s, 게임 시간으로 줄어듦 %s" % [fast, cd_ok, miss, ticked])
	var a := _orb(c + Vector2(200, 0), 50.0)
	var b := _orb(c + Vector2(260, 40), 50.0)
	var boss := _orb(c + Vector2(180, -60), 50.0, Orb.Kind.BOSS)
	var out := _orb(c + Vector2(200, 200), 50.0)
	main.combat_system._resolve(0.0)
	var held: bool = main.abilities_system._use_skill("hold", c + Vector2(210, 0))
	var hold_ok: bool = held and is_equal_approx(a.root_timer, 2.0) and is_equal_approx(b.root_timer, 2.0) and is_equal_approx(boss.root_timer, 1.0) and out.root_timer == 0.0 and is_equal_approx(main.abilities_system.skill_left("hold"), 30.0)
	ok("SKILL-03", hold_ok, "붙잡기: 120 안 2초(보스 1초), 밖은 그대로, 다시 쓰기 30초")
	main.abilities_system._skills_new_run(2)
	main.phase = main.Phase.WAVE
	main.abilities_system._use_skill("brand", c + Vector2(210, 0))
	var hp0 := a.hp
	a.hurt(10.0)
	var brand_ok: bool = a.amp.has("brand") and is_equal_approx(hp0 - a.hp, 13.0) and not out.amp.has("brand")
	ok("SKILL-04", brand_ok, "낙인: 150 안 구체 받는 피해 +30%% (%.1f)" % [hp0 - a.hp])
	# 빠른 손 -20%(겹치면 곱), 자동 사용은 몰린 곳에
	main.perks = {"quick": 2}
	var q_ok := is_equal_approx(Skill.cd_full("brand", 2), 20.0 * 0.64)
	main.skill_cd = {}
	main.abilities_system.auto_skills = true
	for o in [a, b, boss, out]:
		o.amp.clear()
		o.root_timer = 0.0
		o.root_immune = 0.0
		o.root_dr = 0
	main.combat_system._resolve(0.0)
	main.abilities_system._skill_tick(0.01)
	var auto_ok: bool = main.abilities_system.skill_left("hold") > 0.0 and main.abilities_system.skill_left("brand") > 0.0 and a.amp.has("brand") and is_equal_approx(main.abilities_system.skill_left("brand"), 12.8)
	main.abilities_system.auto_skills = false
	main.perks = {}
	main.phase = main.Phase.CHOOSE
	main.abilities_system._skills_new_run(0)
	ok("SKILL-05", q_ok and auto_ok, "빠른 손 2번 x0.64 %s, 자동 사용 %s" % [q_ok, auto_ok])
	_clear()
	_hold_immunity()


## 붙잡기 실패는 사용 횟수·쿨다운·성공 효과를 쓰지 않고, 수동 조준은 유지한다.
func _hold_immunity() -> void:
	for natural in [false, true]:
		for kind in [Orb.Kind.NORMAL, Orb.Kind.BOSS]:
			_fresh(12)
			main.abilities_system._skills_new_run(0)
			main.phase = main.Phase.WAVE
			var o := _orb(main.viewport_system.center() + Vector2(210, 0), 100.0, kind, 60.0)
			if natural:
				for i in 3:
					o.root(2.0)
				for i in 121:
					o.step(1.0 / 60.0)
			else:
				o.root_immune = 2.0
			main.combat_system._resolve(0.0)
			main.abilities_system._arm_skill(1)
			var fx_n: int = main.skill_fx.size()
			var immune := o.root_immune > 0.0 and o.root_timer == 0.0
			var used: bool = main.abilities_system._use_skill("hold", o.position)
			var no_cost: bool = not used and main.abilities_system.skill_left("hold") == 0.0 and main.skill_used == 0
			var feedback: bool = main.skill_arm == "hold" and main.toast.text.contains(main.patchlog_system._kr_keep("면역"))
			ok("SKILL-03", immune and no_cost and feedback and o.root_timer == 0.0 and main.skill_fx.size() == fx_n,
				"붙잡기 전부 면역: 자연 %s·종류 %d, 사용 %s·쿨다운 %.1f·안내 %s" % [natural, kind, used, main.abilities_system.skill_left("hold"), feedback])

	# near는 격자 후보를 돌려주므로 죽은 구체·실제 범위 밖 면역 구체는 면역 안내 대상이 아니다.
	_fresh(12)
	main.abilities_system._skills_new_run(0)
	main.phase = main.Phase.WAVE
	var p: Vector2 = main.viewport_system.center() + Vector2(210, 0)
	var dead := _orb(p, 50.0)
	dead.root_immune = 2.0
	var outside := _orb(p + Vector2(150, 0), 50.0)
	outside.root_immune = 2.0
	main.combat_system._resolve(0.0)
	dead.hp = 0.0
	main.abilities_system._arm_skill(1)
	var missed: bool = not main.abilities_system._use_skill("hold", p)
	ok("SKILL-03", missed and main.abilities_system.skill_left("hold") == 0.0 and main.toast.text.contains(main.patchlog_system._kr_keep("없어요")) and not main.toast.text.contains(main.patchlog_system._kr_keep("면역")),
		"붙잡기 빈 범위: 죽은 구체·범위 밖 면역 구체는 제외하고 구체 없음 안내")

	# 성공한 첫 구체 때문에 뒤 구체의 root 호출을 건너뛰면 안 된다. 순서를 바꿔 둘 다 확인한다.
	for immune_first in [false, true]:
		_fresh(12)
		main.abilities_system._skills_new_run(0)
		main.phase = main.Phase.WAVE
		var c: Vector2 = main.viewport_system.center() + Vector2(210, 0)
		var group: Array = []
		for i in 3:
			group.append(_orb(c + Vector2(0, i * 20), 50.0))
		var immune: Orb = group[0 if immune_first else 2]
		immune.root_immune = 2.0
		main.combat_system._resolve(0.0)
		main.abilities_system._arm_skill(1)
		var used: bool = main.abilities_system._use_skill("hold", c)
		var stopped: bool = group.all(func(o): return o == immune or is_equal_approx(o.root_timer, 2.0))
		ok("SKILL-03", used and stopped and immune.root_timer == 0.0 and is_equal_approx(main.abilities_system.skill_left("hold"), 30.0) and main.skill_used == 1 and main.skill_arm == "",
			"붙잡기 혼합 범위: 면역 먼저 %s, 비면역 구체 모두 정지·쿨다운 한 번" % immune_first)

	# 자동 사용은 면역 실패를 조용히 넘기고, 면역이 끝나면 같은 기술을 다시 시도한다.
	_fresh(12)
	main.abilities_system._skills_new_run(0)
	main.phase = main.Phase.WAVE
	var boss := _orb(main.viewport_system.center() + Vector2(210, 0), 100.0, Orb.Kind.BOSS)
	boss.root_immune = 2.0
	main.combat_system._resolve(0.0)
	main.toast.text = "자동 사용 전"
	main.abilities_system.auto_skills = true
	main.abilities_system._skill_tick(0.01)
	var quiet: bool = main.abilities_system.skill_left("hold") == 0.0 and main.skill_used == 0 and main.toast.text == "자동 사용 전"
	boss.step(2.1)
	main.combat_system._resolve(0.0)
	main.abilities_system._skill_tick(0.01)
	ok("SKILL-03", quiet and is_equal_approx(boss.root_timer, 1.0) and is_equal_approx(main.abilities_system.skill_left("hold"), 30.0) and main.skill_used == 1,
		"붙잡기 자동 사용: 면역 중 비용·안내 없음, 면역이 풀리면 다시 사용")
	main.abilities_system.auto_skills = false
	main.phase = main.Phase.CHOOSE
	main.abilities_system._skills_new_run(0)
	_clear()


## 기맥·빌드 읽기 (LEY-01..03, BUILD-01..02)
func _ley_build() -> void:
	_fresh(12)
	var c: Vector2 = main.viewport_system.center()
	main.run_id = "spec-ley"
	main.abilities_system._ley_new_run()
	var a: Array = main.ley.duplicate()
	main.abilities_system._ley_new_run()
	var same: bool = a == main.ley
	var fr: Rect2 = main.combat_system.field_rect().grow(-90.0)
	var cons := a.size() == 3
	for i in a.size():
		var d: float = a[i].distance_to(main.viewport_system.core())
		cons = cons and fr.has_point(a[i]) and d >= 150.0 and d <= 360.0
		for j in i:
			cons = cons and a[i].distance_to(a[j]) >= 220.0
	main.run_id = "spec-ley-2"
	main.abilities_system._ley_new_run()
	var differs: bool = main.ley != a
	ok("LEY-01", same and cons and differs, "판 번호로 정해지는 3곳 %s, 가장자리 90·중앙 150~360·서로 220 %s, 판마다 다름 %s" % [same, cons, differs])
	main.ley = [c + Vector2(200, 0)]
	var t1 := _tower(c + Vector2(210, 0), Elem.FIRE)
	var t2 := _tower(c + Vector2(225, 0), Elem.FIRE)
	var t3 := _tower(c + Vector2(-200, 0), Elem.FIRE)
	main.phase = main.Phase.CHOOSE
	var one: bool = main.abilities_system.on_ley(t1) and not main.abilities_system.on_ley(t2) and not main.abilities_system.on_ley(t3)
	var f_on := t1.dmg_factor()
	main.ley = []
	var k := f_on / t1.dmg_factor()
	ok("LEY-02", one and is_equal_approx(k, 1.15), "자리마다 가장 가까운 하나만 %s, 피해 x%.2f" % [one, k])
	main.ley = []
	main.run_id = "spec-ley"
	main.abilities_system._ley_new_run()
	var save_ok := true
	var saved: Array = main.ley.map(func(q): return [q.x, q.y])
	var back: Array = saved.map(func(q): return Vector2(q[0], q[1]))
	save_ok = back == main.ley
	Rules.tune["ley_on"] = 0.0
	main.abilities_system._ley_new_run()
	var off: bool = main.ley.is_empty()
	Rules.tune.erase("ley_on")
	ok("LEY-03", save_ok and off, "이어하기 저장 [x,y] %s, ley_on 0이면 없음 %s" % [save_ok, off])
	main.ley = []
	# 빌드 읽기
	t1.run_src = {"hit": 900.0, "elem:fire": 500.0, "share:wood": 300.0, "etc:crowd": 200.0}
	t3.run_src = {"pat:spray": 150.0, "mod:split": 50.0}
	t2.run_src = {}
	for t in [t1, t2, t3]:
		t.src = {}
	main.wave = 12
	main.hud_system._refresh_build()
	var top: Array = main.hud_system.build_cache
	var top_ok: bool = top.size() >= 3 and top[0][0] == "elem:fire" and top[1][0] == "share:wood" and not top.any(func(it): return it[0] == "hit" or str(it[0]).begins_with("etc:"))
	ok("BUILD-01", top_ok, "주력 순서(직접 타격·공통 몫 뺌) %s" % [top.map(func(it): return it[0])])
	var f_fire: String = main.hud_system.core_fit({"type": "elem", "e": Elem.FIRE, "lv": 1})
	var rx_ok: bool = main.hud_system.core_fit({"type": "elem", "e": Elem.WOOD, "lv": 1}) != ""  # 특징 자람(share:wood)이 주력
	var no_pat: bool = main.hud_system.core_fit({"type": "pat", "id": "spray"}) == ""
	main.wave = 2
	main.hud_system._refresh_build()
	var early: bool = main.hud_system.build_cache.is_empty()
	ok("BUILD-02", f_fire != "" and rx_ok and no_pat and early, "주력 카드 ◎: 속성 %s, 특징의 속성 %s, 3위 아래는 없음 %s, 3웨이브 전엔 안 셈 %s" % [f_fire != "", rx_ok, no_pat, early])
	_clear()


## 후반 곡선 (WAVE-12)
func _late_curve() -> void:
	var g150: float = main.hp_growth(150)
	var g151: float = main.hp_growth(151)
	var hp_ok := is_equal_approx(g150, pow(1.05, 140)) and is_equal_approx(g151, pow(1.05, 140) * 1.03 * 305.0 / 303.0)
	var n_ok: bool = main.wave_size(150) == 303 and main.wave_size(400) == 303 and main.wave_size(100) == 203
	var s_ok: bool = main.orb_base_speed(20) == 90.0 and main.orb_base_speed(34) == 132.0 and main.orb_base_speed(600) == 132.0
	ok("WAVE-12", hp_ok and n_ok and s_ok, "후반 곡선: 체력 150까지 x1.05·뒤 x1.03(+수 상한 몫) %s, 구체 수 303 상한 %s, 속도 34웨이브 값 132 상한 %s" % [hp_ok, n_ok, s_ok])


## 새 속성 피·환영 (2026-11-04)
func _new_elems(c: Vector2) -> void:
	var _grid := func():
		main.combat_system.targets = main.orbs.get_children()
		main.combat_system._build_grid()
	# 피 출혈: 움직인 만큼 피해, 멈추면 피해 없음
	var bt := _tower(c + Vector2(-300, -200), Elem.BLOOD, 2)
	var mv := _orb(c + Vector2(-300, 0), 1e6, Orb.Kind.NORMAL, 60.0)
	var st := _orb(c + Vector2(0, -250), 1e6)
	_grid.call()
	bt.hit(mv, 0.0)
	bt.hit(st, 0.0)
	var hm := mv.hp
	var hs := st.hp
	for i in 30:
		mv.step(1.0 / 60.0)
		st.step(1.0 / 60.0)
	var want := Rules.blood_dmg * 2 * 30.0 / 100.0 * bt.final_damage_mul()
	var lost := hm - mv.hp
	ok("ELEM-14", mv.bleed_t > 0.0 and absf(lost - want) < want * 0.15 and hs == st.hp and bt.src.has("elem:blood"),
		"피 출혈: 30px 움직이면 %.2f (기대 %.2f), 멈춘 구체 피해 %.2f" % [lost, want, hs - st.hp])
	_clear()
	# 피 핏자국: 맞은 구체가 지나간 길에 핏자국, 뒤따라 밟은 구체에 효과, 남긴 구체는 안 밟음
	var gt := _tower(c + Vector2(-300, -200), Elem.BLOOD, 3)
	gt.add(Elem.FIRE, 1)
	gt.eff = gt.eff_now()
	var lead := _orb(c + Vector2(-300, 0), 1e6, Orb.Kind.NORMAL, 60.0)
	var back := _orb(c + Vector2(-400, 0), 1e6)
	_grid.call()
	gt.hit(lead, 0.0)
	for i in 60:
		lead.step(1.0 / 60.0)
	var gore: Zone = null
	for z in main.zones.get_children():
		if z.kind == "gore":
			gore = z
	var self_ok := true
	if gore:
		lead.burn_t = 0.0
		gore.affect([lead], 0.1)
		self_ok = lead.burn_t == 0.0
		back.position = gore.pts[gore.pts.size() - 1]
		gore.affect([back], 0.1)
	ok("ELEM-14", lead.gore_src == gt and gore != null and back.burn_t > 0.0 and self_ok and back.bleed_t > 0.0,
		"피 핏자국: 구체가 지나간 길에 핏자국(%s), 밟은 뒤 구체 화상 %.1f·출혈 %.1f, 남긴 구체는 안 밟음 %s" % [gore != null, back.burn_t, back.bleed_t, self_ok])
	_clear()
	# 환영 현혹: 왔던 길을 되돌아 걸음, 같은 구체는 쿨, 보스 절반
	var co := _orb(c + Vector2(-300, 0), 1e6, Orb.Kind.NORMAL, 60.0)
	var d0 := co.position.distance_to(co.target)
	var got := co.confuse(Rules.illu_t)
	for i in 20:
		co.step(1.0 / 60.0)
	var d1 := co.position.distance_to(co.target)
	var again := co.confuse(Rules.illu_t)
	var boss := _orb(c + Vector2(300, 0), 1e6, Orb.Kind.BOSS, 60.0)
	boss.confuse(Rules.illu_t)
	var it := _tower(c + Vector2(-300, -200), Elem.ILLUSION, 9)
	ok("ELEM-15", got and d1 > d0 and not again and is_equal_approx(boss.confuse_t, Rules.illu_t * 0.5) and is_equal_approx(Share.illu_ch(it, 9), Rules.illu_max),
		"환영 현혹: 되돌아 걸음 (거리 %.0f → %.0f), 다시 걸기 막힘, 보스 %.2f초, 확률 최대 %d%%" % [d0, d1, boss.confuse_t, roundi(Rules.illu_max * 100)])
	_clear()
	# 환영 효과 전달: 옆 오브젝트의 다음 공격에 이 오브젝트 효과, 한 번 쓰면 사라짐
	var mt := _tower(c + Vector2(-300, -200), Elem.ILLUSION, 3)
	mt.add(Elem.FIRE, 1)
	mt.eff = mt.eff_now()
	var nb := _tower(c + Vector2(-200, -200), Elem.WOOD, 1)
	var far := _tower(c + Vector2(300, 200), Elem.WOOD, 1)
	var m1 := _orb(c, 1e6)
	var m2 := _orb(c + Vector2(0, 100), 1e6)
	_grid.call()
	mt.hit(m1, 0.0)
	var lit := nb.mirror_src == mt and far.mirror_src == null
	nb.hit(m2, 0.0)
	ok("ELEM-15", lit and m2.burn_t > 0.0 and nb.mirror_src == null and Elem.trait_name(Elem.ILLUSION) == "효과 전달" and "2초 안" in Elem.TRAIT[Elem.ILLUSION],
		"환영 효과 전달: 둘레 220 안 가장 가까운 오브젝트에 비침(%s), 그 오브젝트 다음 공격에 화상 %.1f, 쓰면 사라짐" % [lit, m2.burn_t])
	_clear()
	# 상성
	var ab := Elem.aff_of(Elem.BLOOD, Elem.POISON)
	var ai := Elem.aff_of(Elem.BLOOD, Elem.ICE)
	var at := _tower(c + Vector2(-300, -200), Elem.BLOOD, 1)
	at.add(Elem.ICE, 1)
	at.eff = at.eff_now()
	var nm := _orb(c, 1e6, Orb.Kind.NORMAL, 60.0)
	nm.vuln(2.0, 0.2)
	var h0 := nm.hurt_mul()
	nm.confuse(Rules.illu_t, true)
	var h1 := nm.hurt_mul()
	ok("ELEM-16", ab["strong"] and ai["weak"] and Elem.aff_of(Elem.BLOOD, Elem.DARK)["ids"].has("hunger") and Elem.aff_of(Elem.BLOOD, Elem.WOOD)["ids"].has("stanch")
		and Elem.aff_of(Elem.ILLUSION, Elem.SOUND)["ids"].has("phantasm") and Elem.aff_of(Elem.ILLUSION, Elem.SOUL)["ids"].has("nightmare") and Elem.aff_of(Elem.ILLUSION, Elem.STAR)["ids"].has("mirage")
		and is_equal_approx(Share.am(at, Elem.BLOOD), Share.AFF_WEAK) and is_equal_approx(h1 - 1.0, (h0 - 1.0) * Share.NIGHTMARE),
		"피·환영 상성: 패혈·굶주림·응고·지혈·환청·악몽·신기루, 응고 출혈 x%.1f, 악몽 받는 피해↑ %.2f → %.2f" % [Share.am(at, Elem.BLOOD), h0, h1])
	_clear()
