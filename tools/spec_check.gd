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
	main._apply_rules()
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
	await _multi_center()
	_reflex()
	_reflex_review_regressions()
	_mods_links()
	await _mods_area()
	_waves()
	_orbs_cc()
	_score_core()
	_perks()
	_rules_modes()
	_vary()
	_maps()
	_save_load()
	_meta_misc()
	_multiplayer()
	_tutorial()
	_vote()
	_ugc()
	_board_filters()
	_prism_fx()
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

	# 쉬는 시간마다 고르는 수: 처음 두 번 2장, 그 뒤 1장
	main.wave = 0
	main._new_rest()
	var p0: int = main.picks_left
	main.wave = 6
	main._new_rest()
	ok("CARD-07", p0 == 2 and main.picks_left == 1 and Rules.picks == 1, "고르는 수: 첫 쉬는 시간 %d, 그 뒤 %d (규칙 %d)" % [p0, main.picks_left, Rules.picks])

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
	var t5 := _tower(c + Vector2(-200, 150), Elem.FIRE, 4)
	t5.add(Elem.FIRE, 3)
	var cap_ok := t5.lv(Elem.FIRE) == 5 and not t5.can_take({"type": "elem", "e": Elem.FIRE, "lv": 1}) and "Lv5" in t5.refuse_text({"type": "elem", "e": Elem.FIRE, "lv": 1})
	t5.queue_free()
	ok("ELEM-02", not fourth and same and cap_ok, "랭크: 속성 3종까지, 같은 속성은 Lv5까지 (Lv%d, 더 넣기 막음 %s)" % [5, cap_ok])
	ok("ELEM-03", is_equal_approx(t.tax(), 1.0 + Rules.tax_step * 2) and is_equal_approx(Rules.tax_step, 0.15), "쌓기 대가: 종류마다 공격 속도 ÷(1+0.15×(종류-1)) (%.2f)" % t.tax())

	Meta.rules = 3
	main._apply_rules()
	ok("ELEM-04", t.can_take({"type": "elem", "e": Elem.WOOD, "lv": 1}) and is_equal_approx(Rules.tax_step, 0.25), "도파민 모드: 속성 종류 제한 없음, 대가 0.25")
	Meta.rules = 1
	main._apply_rules()

	# 105개 조합 모두 반응
	var missing := []
	var ids := {}
	for i in Elem.ALL.size():
		for j in range(i + 1, Elem.ALL.size()):
			var rs := Elem.reactions_with({Elem.ALL[i]: 1, Elem.ALL[j]: 1})
			if rs.is_empty():
				missing.append("%s+%s" % [Elem.NAMES[Elem.ALL[i]], Elem.NAMES[Elem.ALL[j]]])
			for r in rs:
				ids[r["id"]] = true
	ok("ELEM-05", missing.is_empty() and ids.size() == 105 and Elem.REACTIONS.size() == 105, "두 속성 조합 105개 모두 특수 반응 (빠짐 %s, 반응 %d)" % [str(missing), ids.size()])

	t.eff = t.eff_now()
	var fresh := Elem.new_reactions({Elem.FIRE: 1}, Elem.WOOD)
	ok("ELEM-06", fresh.size() == 1 and t.reactions().size() == 3, "속성을 더하면 새 반응 알림, 3종이면 반응 3개")

	var no_rider := Elem.ALL.filter(func(e): return Elem.rider(e).is_empty())
	ok("ELEM-07", no_rider.is_empty() and Elem.ALL.size() == 15, "속성 15종 모두 부가효과 설명이 있음")
	_elem_lv5()
	_no_fixed_zone()


## 속성 Lv5 값 (2026-11-01): 금속은 맞힌 피해 +8%/레벨, 어둠 약화는 +20% + 4%/레벨, 물 감속은 0.85 - 0.03/레벨
func _elem_lv5() -> void:
	_clear()
	var c: Vector2 = main.center()
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


## 고정 거리 장판 금지 (2026-11-01): 형태 성질 "끝"은 장판을 만들지 않고 구체에 바로 걸고,
## 계속 공격하는 형태의 끝은 사거리 끝이 아니라 공격 안의 가장 먼 구체, 모든 공격방식이 만드는 장판 종류는 허용 목록뿐.
const ZONE_OK := ["trail", "vortex", "rock", "mine", "bog", "cloud", "boom"]
const FORM_ELS := [Elem.FIRE, Elem.WATER, Elem.ICE, Elem.EARTH, Elem.POISON, Elem.TIME]
const CONT_PATS := ["spray", "stream", "laser", "sonic", "clock"]


func _form_tower(p: Vector2, d := Vector2.RIGHT) -> Tower:
	var t := _tower(p, Elem.FIRE, 3, d)
	for e in FORM_ELS:
		if e != Elem.FIRE:
			t.add(e, 3)
	t.eff = t.eff_now()
	return t


func _no_fixed_zone() -> void:
	_fresh()
	Meta.rules = 3  # 속성 종류 제한 없음 (형태 성질 6개를 한 오브젝트에)
	main._apply_rules()
	var c: Vector2 = main.center()
	var t := _form_tower(c + Vector2(-200, 0))
	# 1) 끝 효과: 구체가 없어도 있어도 장판 0개, 가까운 구체에 화상·중독·감속·째깍
	var z0: int = main.zones.get_child_count()
	t.form_end(c + Vector2(100, 0), Vector2.RIGHT, true)
	var o := _orb(c + Vector2(100, 10), 99999.0)
	main.targets = main.orbs.get_children()
	main._build_grid()
	t.form_end(c + Vector2(100, 0), Vector2.RIGHT, true)
	var no_zone: bool = main.zones.get_child_count() == z0
	var on_orb: bool = o.burn_t > 0.0 and o.poison_t > 0.0 and o.slow_timer > 0.0 and o.tick_t > 0.0
	# 째깍: 표식이 끝나면 그 구체 자리에서 터져 옆 구체도 맞는다
	var o2 := _orb(o.position + Vector2(20, 0), 99999.0)
	main.wave_active = true
	main.phase = main.Phase.WAVE
	main.to_spawn = 0
	for i in 150:  # 째깍 0.6초 (구체가 멈춘 동안에도 표식 시간은 간다)
		main._sim_step(1.0 / 60.0)
	var ticked: bool = o.tick_t <= 0.0 and o2.hp < o2.max_hp
	# 2) 계속 공격 형태: 끝은 공격 방향 안의 가장 먼 구체 자리 (사거리 끝 고정 지점 아님)
	var cont_ok := true
	var cont_bad := []
	for pat in CONT_PATS:
		_clear()
		var ct := _form_tower(c, Vector2.RIGHT)
		ct.set_pattern(pat)
		ct.aim = Vector2.RIGHT
		var near_o := _orb(c + Vector2(60, 0), 99999.0)
		var far_o := _orb(c + Vector2(110, 0), 99999.0)
		ct.fe2 = 0.0
		main.targets = main.orbs.get_children()
		main._build_grid()
		var zc: int = main.zones.get_child_count()
		ct._cont_end([near_o, far_o], ct.plv, 1.0)
		if not (far_o.tick_t > 0.0 and near_o.tick_t <= 0.0 and main.zones.get_child_count() == zc):
			cont_ok = false
			cont_bad.append(pat)
	# 3) 모든 공격방식 3초: 장판 종류는 허용 목록뿐, 계속 공격 형태는 불씨·물길(지나간 길)도 없음
	var bad := []
	for pat in Pat.PATTERN_IDS:
		_clear()
		var pt := _form_tower(c + Vector2(-60, 0), Vector2.LEFT)
		if pat != "shot":
			pt.set_pattern(pat)
		_orb(c + Vector2(-260, 0), 99999.0, Orb.Kind.NORMAL, 30.0)
		_orb(c + Vector2(-330, 30), 99999.0, Orb.Kind.NORMAL, 30.0)
		var kinds := {}
		for i in 180:
			main._sim_step(1.0 / 60.0)
			for z in main.zones.get_children():
				kinds[z.kind] = true
		for k in kinds:
			var allowed: bool = k in ZONE_OK or (k in Tower.FORM_ZONES and pat not in CONT_PATS)
			if not allowed:
				bad.append("%s:%s" % [pat, k])
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	Meta.rules = 1
	main._apply_rules()
	ok("ELEM-10", no_zone and on_orb and ticked and cont_ok and bad.is_empty(),
		"고정 거리 장판 없음: 형태 성질 끝은 구체에 바로(장판 %s, 구체 %s, 째깍 %s), 계속 공격 끝은 가장 먼 구체(틀림 %s), 장판 종류 허용 목록뿐(어긋남 %s)" % [no_zone, on_orb, ticked, str(cont_bad), str(bad)])


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
	_well()
	_fade()
	ok("PAT-04", silent.is_empty(), "공격방식 %d개 모두 앞에서 다가오는 구체에 피해 (못 맞힘: %s)" % [Pat.PATTERN_IDS.size(), str(silent)])


## 블랙홀 중력 우물 (2026-11-01): 사거리 안 구체가 가장 빽빽한 곳에 떨어지고, 안 구체가 남에게 받은 피해 20%를 모았다가 끝에 나눠 넣음
func _well() -> void:
	_fresh()
	var c: Vector2 = main.center()
	var vt := _tower(c + Vector2(-100, 0), Elem.DARK, 1, Vector2.LEFT)
	vt.set_pattern("vortex")
	var other := _tower(c + Vector2(-100, 200), Elem.FIRE)
	var lone := _orb(c + Vector2(-200, 0), 1e6)  # 혼자 있는 구체
	var pack := []
	for i in 5:
		pack.append(_orb(c + Vector2(-350, 150) + Vector2(i * 8, i * 6), 1e6))
	main.targets = [lone] + pack
	main._build_grid()
	var spots := vt.well_spots(1)
	var at_pack: bool = not spots.is_empty() and spots[0].distance_to(pack[0].position) < 60.0
	var z: Zone = main.spawn_zone("vortex", 1, spots[0] if not spots.is_empty() else c, vt)
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
	var c: Vector2 = main.center()
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
				main._sim_step(1.0 / 60.0)
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
	var c: Vector2 = main.center()
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
		main._sim_step(1.0 / 60.0)
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
	var z: Zone = main.spawn_zone("rock", 1, c, w)
	var rk: float = z._rapid()
	var life: float = z.max_life
	ok("MOD-09", is_equal_approx(rk, 1.0 + 2.0 * Rules.rapid_k) and is_equal_approx(life, 12.0 * w.sz())
		and not Pat.mod_ok("clock", "homing") and not Pat.mod_ok("chain", "homing")
		and is_equal_approx(Pat.mod_fix("thorn", "homing", 2.0), 1.0) and is_equal_approx(Pat.mod_fix("thorn", "homing", 5.0), Pat.MOD_FIX["thorn"]["homing"]),
		"벽 속사 2개 피해 속도 x%.2f, 크기 1개 벽 %.1f초, 시계침·연쇄 유도 막힘, 관통 연사 유도 2개 보정 x%.2f" % [rk, life, Pat.mod_fix("thorn", "homing", 2.0)])
	# MOD-10 돌풍 다중 발사: 부채꼴이 아니라 같은 방향으로 나란히
	_clear()
	var g := _tower(c + Vector2(-300, 0))
	g.set_pattern("gust")
	g.add_mod("multi")
	g.add_mod("multi")
	g.aim = Vector2.RIGHT
	var dirs := []
	for i in 60:
		main._sim_step(1.0 / 60.0)
		for p in main.projectiles.get_children():
			if p.kind == "gust" and not p in dirs:
				dirs.append(p)
	var same := dirs.size() >= 3
	for p in dirs:
		same = same and p.vel.normalized().dot(dirs[0].vel.normalized()) > 0.999
	main.wave_active = false
	main.phase = main.Phase.CHOOSE
	_clear()
	ok("MOD-10", same, "돌풍 다중 2개: 돌풍 %d개가 같은 방향으로 나란히" % dirs.size())


# 반응: 기존 방향 고정과 다른 전방위 조준·최종 감산·모드/저장 경계.
func _reflex() -> void:
	_fresh()
	var c: Vector2 = main.center()
	var card := {"type": "mod", "id": "reflex"}
	var t := _tower(c + Vector2(-100, 0), Elem.WIND)
	var other := _tower(c + Vector2(100, 0), Elem.WATER)
	var selectable: bool = main.towers.get_children().any(func(tw): return tw.can_take(card))
	t.add_mod("reflex")
	t.add_mod("reflex")
	var cap_ok := t.m("reflex") == 1 and not t.can_take(card) and other.can_take(card) and t.refuse_text(card).contains("1개")
	Meta.rules = 3
	main._apply_rules()
	cap_ok = cap_ok and not t.can_take(card)
	Meta.rules = 1
	main._apply_rules()
	var restored := Tower.new()
	restored.load_save(t.to_save())
	var save_ok := restored.m("reflex") == 1 and not restored.can_take(card)
	restored.free()
	var blocked := true
	for pat in ["path", "wisp", "vortex"]:
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
	var content: Dictionary = main._card_content(card, 1)
	var text_ok: bool = content["foot"][0][1].contains("1회") and content["rows"][0]["t"].contains("-10%")
	ok("MOD-13", patterns_ok and text_ok, "반응: 방향 공격 13종 후방 조준·카드 앞면 1회/피해 감산 안내")
	# 실제 전투 경로에서 방향 고정 분사는 후방에 0, 반응은 피해 발생.
	_fresh()
	t = _tower(c + Vector2(-100, 0), Elem.WATER)
	t.set_pattern("spray")
	victim = _orb(t.position + Vector2.LEFT * 100.0, 1000.0)
	main._resolve(0.1)
	var fixed_hp := victim.hp
	t.add_mod("reflex")
	main._resolve(0.1)
	ok("MOD-13", is_equal_approx(fixed_hp, 1000.0) and victim.hp < fixed_hp, "반응: 실제 전투 분사 후방 구체 명중 (기존 방향 고정은 0)")


# PR #11 리뷰: 기존 검사가 놓친 쿨다운·실제 사거리·처형 경계를 재현한다.
func _reflex_review_regressions() -> void:
	_fresh()
	var c: Vector2 = main.center()
	var t := _tower(c, Elem.FIRE)
	t.add(Elem.WOOD, 1)
	t.eff = t.eff_now()
	t.add_mod("reflex")
	t.cd = {"p": 1.0, "burning": 1.0}
	var de := 0.1 * t.spd_k()
	t.attack(0.1, [])
	ok("MOD-13", is_equal_approx(t.cd["burning"], 1.0 - de),
		"반응 대기: 특수 반응 쿨다운 1회만 감소 (실제 %.4f / 기대 %.4f)" % [t.cd["burning"], 1.0 - de])
	_fresh()
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
		var same := is_equal_approx(t.reflex_range(), pr.max_travel)
		ranges_ok = ranges_ok and same
		if not same:
			details.append("%s 감지%.1f/탄%.1f" % [pat, t.reflex_range(), pr.max_travel])
		pr.free()
	ok("MOD-13", ranges_ok, "반응: 바람·크기·유도 보정 뒤 실제 탄 사거리와 일치 %s" % [details])
	_fresh()
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
		var target := _orb(c + direction * (pr.max_travel - 1.0), 1000.0)
		t._update_aim([target], 0.016)
		weather_ok = weather_ok and t.reflex_target == target
		target.position = c + direction * (pr.max_travel + 1.0)
		t._update_aim([target], 0.016)
		weather_ok = weather_ok and t.reflex_target == null
		pr.free()
	ok("MOD-13", weather_ok, "반응 폭풍: 순풍/역풍의 실제 탄 사거리 안만 감지")
	_fresh()
	t = _tower(c)
	t.pattern = "wall"
	t.add_mod("reflex")
	var o := _orb(c + Vector2.LEFT * 150.0, 1000.0)
	t._update_aim([o], 0.016)
	ok("MOD-13", t.reflex_target == o, "반응 벽: 두 번째 벽이 닿는 150 거리 구체도 감지 (감지 %.1f)" % t.reflex_range())
	_fresh()
	t = _tower(c, Elem.DARK)
	t.add(Elem.METAL, 1)
	t.eff = t.eff_now()
	t.add_mod("reflex")
	o = _orb(c + Vector2.RIGHT * 80.0, 1000.0)
	o.hp = 100.0
	main.targets = [o]
	main._build_grid()
	t.in_rx = true
	t.tag = "rx:scythe"
	RxMore.tick(t, "scythe", 1, [o], 3.1, 1.0)
	ok("MOD-13", o.hp <= 0.0, "반응+처형 낫: 체력 20%% 아래 구체를 실제 처치 (남은 체력 %.3f)" % o.hp)


# ---------- 강화·연계·발동 ----------

func _mods_links() -> void:
	_fresh()
	var c: Vector2 = main.center()
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
	main._apply_rules()
	var u := Tower.new()
	u.mods = {"size": 3}
	ok("MOD-03", is_equal_approx(u.mf("size"), 1.75) and Rules.mod_total >= Rules.NO_CAP, "도파민 모드: 같은 강화는 1, 1.5, 1.75… (3개 %.2f), 합계 상한 없음" % u.mf("size"))
	u.free()
	Meta.rules = 1
	main._apply_rules()
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
	near.add_link("prism")
	near.add_link("pincer")
	ok("LINK-02", near.prism == 1 and near.pincer == 1 and near.extras_text().contains("프리즘") and near.extras_text().contains("협공"), "프리즘·협공을 넣으면 오브젝트에 표시")

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
	main.targets = main.orbs.get_children()
	main._build_grid()
	var f: Array = ch._fire_mul(true)
	main.targets = []
	main._build_grid()
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
	var c: Vector2 = main.center()
	var st := _tower(c + Vector2(-200, 0), Elem.STAR)
	var fi := _tower(c + Vector2(-100, 0), Elem.FIRE)
	var wa := _tower(c + Vector2(-200, 100), Elem.WATER)
	main.star_towers = [st]
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
	main.star_towers = [st, st2]
	st.star_sum = 0.0
	d0 = fi.dealt
	fi.hit(o, 1.0)
	got = fi.dealt - d0
	ok("STAR-01", is_equal_approx(r5b, (0.10 + 0.03 * 4) * 1.5) and is_equal_approx(r11, r5b) and r5 < r5b and is_equal_approx(rs, 0.2)
		and is_equal_approx(st.star_sum, got * 0.5 * 0.15) and is_equal_approx(st2.star_sum, got * 0.5 * 0.15),
		"별빛 상한: Lv5 %.3f = Lv11 %.3f, 자기 %.2f, 별 둘이면 반씩 (%.3f / %.3f)" % [r5b, r11, rs, st.star_sum, st2.star_sum])
	st2.free()
	main.star_towers = [st]

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
		main._process(0.016)
	main.phase = ph0
	ok("STAR-06", fx_on and st.nova_fx == 0.0 and st.fx["laser"] == 0.0,
		"웨이브 밖에서도 초신성·공격 그림 사라짐 (%.2f)" % st.nova_fx)
	# 초신성 예고: 별빛 85%부터 터질 자리(지금 터지면 맞을 구체)를 골라 두고, 그 아래면 없음
	var aim_o := _orb(st.position + Vector2(-200, 0), 1e6)
	main.targets = [aim_o]
	main._build_grid()
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
	main.targets = []
	# 보스 상한: 초신성 한 번(행성 효과·화상 포함)이 보스에게는 최대 체력의 star_boss_cap(15%)까지. 옆 일반 구체는 그대로
	st.star_sum = st.star_need()
	st.star_e = {Elem.FIRE: st.star_sum}
	var pool2 := st.star_sum * 3.0
	var boss := _orb(c + Vector2(-300, 200), pool2 / 12.0, Orb.Kind.BOSS)
	var mate := _orb(c + Vector2(-260, 200), 1e6)
	var bh0 := boss.hp
	var mh0 := mate.hp
	main.targets = main.orbs.get_children().filter(func(o): return is_instance_valid(o) and not o.is_queued_for_deletion())
	main._build_grid()
	st._supernova(boss)
	var bcap := boss.max_hp * Rules.t("star_boss_cap")
	var blost := bh0 - boss.hp  # 바로 깎인 몫 (행성 화상은 상한에서 미리 빼 두므로 이보다 적게 남는다)
	ok("STAR-07", is_equal_approx(Rules.t("star_boss_cap"), 0.15) and blost <= bcap * 1.01 and blost >= bcap * 0.5 and mh0 - mate.hp >= pool2 * 0.4
		and Elem.rider(Elem.STAR).contains("보스"),
		"보스 상한: 체력 %.0f 중 %.0f(상한 %.0f), 옆 구체 %.0f" % [boss.max_hp, blost, bcap, mh0 - mate.hp])
	boss.free()
	mate.free()
	main.targets = []
	main._build_grid()

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
	var free_before: bool = not main.star_full() and w1.can_take({"type": "elem", "e": Elem.STAR, "lv": 1})
	p1.add(Elem.FIRE, 1)  # 행성도 같이 센다
	w1.add(Elem.STAR, 1)
	var w2 := _tower(c + Vector2(0, -200), Elem.WIND)
	var star_card := {"type": "elem", "e": Elem.STAR, "lv": 1}
	var why5: String = w2.refuse_text(star_card)
	ok("STAR-05", free_before and Tower.star_count(main) == 3 and main.star_full() and not w2.can_take(star_card) and why5.contains("합쳐")
		and w1.can_take(star_card) and not main._star_blocked(star_card),
		"별·행성 합쳐 3개 (%d개, %s)" % [Tower.star_count(main), why5])
	main.star_towers = []


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
	# 진입 부채꼴(화면)과 실제 구체 각도가 같은 폭: 웨이브 11에 ±0.26, 25웨이브부터 ±0.4, 십자로 0.06, 회랑 0
	main.lanes.assign([1.0, 3.0])
	main.wave = 10
	var sp: float = main.lane_spread(11)
	var inside := true
	var widest := 0.0
	for i in 400:
		var a: float = main._roll_orb(11)["a"]
		var off: float = minf(absf(angle_difference(a, 1.0)), absf(angle_difference(a, 3.0)))
		widest = maxf(widest, off)
		inside = inside and off <= sp + 0.0001
	Meta.map_id = "cross"
	var sc: float = main.lane_spread(30)
	Meta.map_id = "line"
	var sl: float = main.lane_spread(30)
	Meta.map_id = "plain"
	ok("UI-27", inside and widest > sp * 0.9 and is_equal_approx(sp, 0.26) and is_equal_approx(main.lane_spread(25), 0.4) and is_equal_approx(main.lane_spread(40), 0.4) and sc == 0.06 and sl == 0.0, "구체는 진입 부채꼴(±%.2f) 안으로만, 폭 끝까지 옴 (가장 벗어난 %.2f)" % [sp, widest])
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

	var kb := _orb(main.center() + Vector2(-300, 0), 10.0, Orb.Kind.BOSS, 50.0)
	var k0 := kb.position
	kb.knock((kb.target - kb.position).normalized() * 100.0)  # 중앙 쪽
	var k_in := kb.position.distance_to(k0)
	kb.knock((kb.target - kb.position).normalized().orthogonal() * 100.0)  # 옆
	var k_side := kb.position.distance_to(k0)
	ok("CC-04", k_in < 0.01 and k_side <= Orb.BOSS_PUSH + 0.01 and k_side > 1.0, "밀쳐내기: 중앙 쪽 0, 옆은 밀림 여유까지 (보스 안쪽 %.1f · 옆 %.1f)" % [k_in, k_side])

	o.resist_e = Elem.FIRE
	ok("ORB-01", is_equal_approx(o.resist_mul({Elem.FIRE: 1}), 0.4) and is_equal_approx(o.resist_mul({Elem.FIRE: 1, Elem.WATER: 1}), 0.7) and o.resist_mul({Elem.WATER: 1}) == 1.0,
		"저항 구체: 그 속성 비중만큼 피해 최대 60% 감소")
	var sh := _orb(main.center() + Vector2(300, 80), 10.0)
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

	# 웨이브별 중앙 피해: 실드에 막힌 것도 닿은 수·피해엔 들어가고 깎인 체력엔 안 들어감, 판 기록(leaks)·이어하기 저장
	main.leak_log.clear()
	main.shield = 1
	_orb(main.center(), 5.0, Orb.Kind.FAST)
	main._resolve(1.0 / 60.0)
	main._log_wave()
	var recs: Array = main._leak_records()
	var lr: Dictionary = recs[-1] if recs.size() == 1 else {}
	var lk_ok: bool = lr.get("w") == main.wave and lr.get("n") == 3 and lr.get("dmg") == 5 and lr.get("lost") == 4 and lr.get("hp") == 6 \
		and lr.get("kinds") == {"normal": 1, "boss": 1, "fast": 1} and lr.get("kdmg", {}).get("boss") == 3
	main.phase = main.Phase.CHOOSE
	main.perk_mode = false
	main._save_run()
	main.leak_log.clear()
	main._continue_run()
	ok("ONLINE-05", lk_ok and JSON.stringify(main._leak_records(), "", true) == JSON.stringify(recs, "", true), "웨이브별 중앙 피해 기록(닿은 수·피해·깎인 체력·종류별) → 판 기록 leaks, 이어하기 뒤에도 그대로")
	main._clear_run()
	main.shield = 0

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
	ok("PERK-02", ids.size() == 15 and ids.has("quick") and ids.has("coin") and ids.has("shield") and ids.has("rampart") and ids.has("riposte") and ids.has("overflow"), "특성 15종 (%s)" % ",".join(ids))
	main._apply_perk("power")
	main._apply_perk("haste")
	main._apply_perk("reach")
	main._apply_perk("core")
	main._apply_perk("slow")
	main._apply_perk("harmony")
	main._apply_perk("harmony")  # 동전 앞면·옛 저장처럼 두 번 와도 한 번만
	var h_ok := (is_equal_approx(Tower.tax_step, Rules.tax_step * 0.5) and is_equal_approx(Tower.tax_of(3), 1.0 + Rules.tax_step)
		and is_equal_approx(Tower.tax_of(9), (1.0 + Rules.tax_step * 8) / 1.2))
	main.perks["harmony"] = 1
	main.coin_next = ""
	h_ok = h_ok and not main._perk_pool().any(func(pk): return pk["id"] == "harmony")
	main.perks.erase("harmony")
	ok("PERK-03", is_equal_approx(Tower.dmg_mul, 1.15) and is_equal_approx(Tower.spd_mul, 1.12) and is_equal_approx(Tower.reach_mul, 1.12)
		and main.core_max == 13 and main.core_hp == 13 and is_equal_approx(main.orb_speed_mul, 0.92) and h_ok,
		"특성 효과: 화력 +15%·속사 +12%·원거리 +12%·중앙 +3 회복·끈적 -8%·조화 대가 절반(한 번만, 공속 최대 +20%)")
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
	ok("RULE-04", main.rules_label.get_meta("row").visible and tap_txt and r1 == 3 and Meta.rules == 1 and main.rules_label.mouse_filter == Control.MOUSE_FILTER_STOP, "규칙 줄 글을 누르면 랭크 ↔ 도파민 모드, 터치 화면 안내 '눌러서 바꾸기'")
	main.touch_ui = false
	Meta.games = g0
	main._refresh_menu()
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
	ok("PATCH-03", is_equal_approx(hz1, hz0 * 2.0) and is_equal_approx(hz2, hz0) and is_equal_approx(Orb.KIND.boss_hp, 12.0),
		"게임 코드 수치 패치: Tower.HIT.laser 3.4 → 6.8이면 한 번 피해 %.2f → %.2f, 빼면 %.2f" % [hz0, hz1, hz2])

	Modes.set_on(["rush", "stroll", "bogus", "rush", "fort"])
	ok("MODE-01", Modes.on == ["rush", "fort"], "모드: 모르는 것·중복·반대 쌍 뒤쪽은 버림 %s" % str(Modes.on))
	ok("MODE-02", Modes.easy() and Meta.run_key().ends_with(Meta.EASY_TAG), "쉽게 모드가 하나라도 있으면 기록 따로")
	Modes.set_on(["rush", "swarm", "steel", "glass", "narrow", "early", "angry"])
	ok("MODE-03", is_equal_approx(Modes.mul(), Modes.MUL_MAX) and not Modes.easy(), "점수 배율은 곱, %.1f배에서 멈춤" % Modes.MUL_MAX)
	Modes.set_on(["three", "ease"])
	main._apply_rules()
	ok("MODE-04", Rules.picks == 2 and Modes.rerolls(1) == 3, "두 장: 고르기 2장, 여유: 새로고침 +2")
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
	Modes.set_on([])
	Vary.new_run(true)
	var no_mode_no_seal: bool = Vary.on and Vary.count() == 0 and not Vary.seal_on
	Modes.set_on(["seal"])
	Vary.new_run(true)
	var mode_ok: bool = Vary.seal_on and Modes.mul() > 1.0 and not Modes.easy()
	ok("VARY-06", no_mode_no_seal and mode_ok, "봉인은 모드: 안 켜면 봉인 없음(흐름은 켜짐), 켜면 봉인·어렵게 점수 배율")
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
	var sv := Vary.save()
	var sealed_e: Array = Vary.sealed["elem"].duplicate()
	Vary.load_from(JSON.parse_string(JSON.stringify(sv)))
	var keep: bool = Vary.seal_on and Vary.sealed["elem"] == sealed_e
	Modes.set_on([])
	ok("VARY-01", off_after_rules and counts_ok and keep and leak == 0 and Vary.count() == n0 - 1, "봉인: 속성 3·공격방식 4·연계 1, 선택지·대격변에 안 나옴(새어 나옴 %d), 25웨이브에 하나 풀림" % leak)

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
	ok("VARY-05", tut_off and patch_off and Vary.tower_mul({Elem.SOUL: 1}, "wisp") == 1.0, "첫 판·멀티플레이·정원은 끔, 패치 vary_on 0이면 끔")


# ---------- 맵 규칙 ----------

func _map_on(id: String) -> void:
	_fresh(5)
	Meta.map_id = id
	Rules.tune["map_on"] = 1.0
	main.lanes.clear()
	main._roll_lanes()


func _maps() -> void:
	var c: Vector2 = main.center()
	# 친화 카드: 회랑 얼음·물·독이 더 자주, 피해 +15%(속성 레벨 몫·공격방식)
	_map_on("line")
	_tower(c + Vector2(-200, 0))
	_tower(c + Vector2(200, 0))
	var cnt := {}
	for i in 1500:
		main._make_choices()
		for cd in main.offer:
			if cd["type"] == "elem":
				cnt[cd["e"]] = cnt.get(cd["e"], 0) + 1
	var aff := 0.0
	var other := 0.0
	for e in Elem.ALL:
		if e in MapRule.aff("elem"):
			aff += cnt.get(e, 0) / 3.0
		else:
			other += cnt.get(e, 0) / 11.0
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
	main._spawn_orb(Orb.Kind.NORMAL)
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
		var base: Dictionary = main._roll_orb(1)
		for a in [0.0, PI / 2.0, atan2(360.0, 640.0), PI, PI * 1.5]:
			var plan: Dictionary = base.duplicate()
			plan["a"] = a
			main._spawn_orb(Orb.Kind.NORMAL, plan)
			var lo: Orb = main.orbs.get_child(main.orbs.get_child_count() - 1)
			var t_in := -1.0
			var t := 0.0
			while lo.position.distance_to(main.center()) > 20.0 and t < 120.0:
				lo.step(0.02)
				t += 0.02
				if t_in < 0.0 and main.arena().grow(lo.radius()).has_point(lo.position):
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
	var z: Zone = main.spawn_zone("trail", 1, lt.position, lt)
	z.trail("puddle")
	var life_ok := is_equal_approx(z.max_life, Tower.LOB_LIFE * Rules.t("map_line_trail"))
	var so := _orb(c + Vector2(300, 0), 50.0)
	so.slow(0.8, 1.0)
	var slow_ok := is_equal_approx(so.slow_factor, 1.0 - 0.2 * (1.0 + Rules.t("map_line_cc")))
	ok("MAPX-06", life_ok and slow_ok, "회랑: 지나간 자리 장판 x%s, 감속 +30%%" % Rules.t("map_line_trail"))

	# 끄기: 정원·패치 map_on 0
	Garden.on = true
	var g_off := not MapRule.on()
	Garden.on = false
	Rules.tune["map_on"] = 0.0
	ok("MAPX-08", g_off and not MapRule.on() and MapRule.crowd_k() == 1.0 and MapRule.tower_mul({Elem.ICE: 1}, "lob") == 1.0, "정원·패치 map_on 0이면 맵 규칙·친화 끔")
	_fresh(5)
	var map0: String = Meta.map_id
	var mo: float = Rules.tune["map_on"]
	Rules.tune["map_on"] = 1.0
	var n_ok: bool = main.map_cards.size() == Meta.MAP_IDS.size()
	main.map_cards[2].pressed.emit()
	var picked: bool = Meta.map_id == Meta.MAP_IDS[2]
	var sub_t: String = (main.map_label.get_meta("sub") as Label).text.replace("\u2060", "")  # _kr_keep 줄바꿈 방지 문자
	var aff_shown: bool = sub_t.contains("친화") and sub_t.contains(Elem.NAMES[MapRule.aff("elem")[0]])
	Meta.map_id = map0
	Rules.tune["map_on"] = mo
	main._refresh_menu()
	ok("MAPX-09", n_ok and picked and aff_shown, "준비 화면 맵 카드: 맵마다 한 장, 누르면 그 맵, 아래 설명에 친화 카드")


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
	var old_minor: bool = main._old_run_version() == "0.0.1"
	var vp := Net.game_version().split(".")
	cfg.set_value("run", "version", "%s.%s.999" % [vp[0], vp[1] if vp.size() > 1 else "0"])
	cfg.save(main.RUN_PATH)
	ok("SAVE-03", old_minor and main._old_run_version() == "" and not Net.same_minor("0.6.0", "0.7.0") and Net.same_minor("0.6.0", "0.6.3"),
		"마이너 버전(x.Y)이 바뀐 저장은 지난 판으로 알아봄 (이어 하지 않고 끝냄), 패치만 바뀐 판은 이어 함")
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

	# 그린 궤적: 손을 떼면 [적용]을 기다리고, 누르면 넣는다 (터치·마우스 같음). 마우스는 Enter로도, 취소하면 원래 길
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
	# 마우스: 이미 그린 길을 다시 그리다 떼도 바로 안 들어감 → 취소하면 원래 길, Enter면 넣음
	var old0: PackedVector2Array = pt.paths[0].duplicate()
	main._start_draw(pt, [0], false)
	main.draw_on = true
	main.draw_pts = PackedVector2Array([pt.position, pt.position + Vector2(0, 60), pt.position + Vector2(0, 120)])
	main.draw_len = 120.0
	main._draw_release()
	var m_wait: bool = main.draw_wait and main.phase == main.Phase.DRAW and pt.paths[0] == old0
	main._cancel_step()
	var m_cancel: bool = main.phase != main.Phase.DRAW and pt.paths[0] == old0
	main._start_draw(pt, [0], false)
	main.draw_on = true
	main.draw_pts = PackedVector2Array([pt.position, pt.position + Vector2(0, 60), pt.position + Vector2(0, 120)])
	main.draw_len = 120.0
	main._draw_release()
	var ke := InputEventKey.new(); ke.keycode = KEY_ENTER; ke.pressed = true
	main._unhandled_input(ke)
	var m_enter: bool = main.phase != main.Phase.DRAW and pt.paths[0] != old0
	ok("PATH-02", waiting and done and m_wait and m_cancel and m_enter, "그린 궤적: 손을 떼면 길을 남겨 두고 [적용]을 누르면 넣음, [취소]면 원래 길 (터치 %s/%s, 마우스 대기 %s·취소 %s·Enter %s)" % [waiting, done, m_wait, m_cancel, m_enter])

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

	# 기본 설명은 효과 문장이고, 자세히와 반응·레벨업 정보는 남는다. 첫 판에 한정하지 않는다.
	var was_d := Meta.card_detail
	Meta.card_detail = false
	var full: Array = main._card_full({"type": "elem", "e": Elem.WATER, "lv": 1})
	var basic_ok := true
	var wave_before: int = main.wave
	for w in [0, 12, 50]:
		main.wave = w
		for e in Elem.ALL:
			var basic: Dictionary = main._card_content({"type": "elem", "e": e, "lv": 1}, 0)
			var text: String = basic["rows"][0].get("t", "")
			basic_ok = basic_ok and text.length() >= 10 and not basic["rows"][0].has("pair") and not text.contains("적중 ·") and not text.contains("형태 ·")
	main.wave = wave_before
	var ice: String = main._card_content({"type": "elem", "e": Elem.ICE, "lv": 1}, 0)["rows"][0]["t"]
	var earth: String = main._card_content({"type": "elem", "e": Elem.EARTH, "lv": 1}, 0)["rows"][0]["t"]
	var star: String = main._card_content({"type": "elem", "e": Elem.STAR, "lv": 1}, 0)["rows"][0]["t"]
	var conditions: bool = ice.contains("쌓아") and earth.contains("확률") and star.contains("복사") and star.contains("다 차면")
	var s0: Dictionary = main._card_content({"type": "elem", "e": Elem.WATER, "lv": 1}, 0)
	var combo_ok: bool = s0["rows"].any(func(r): return r.has("els"))
	var multi: Dictionary = main._card_content({"type": "mod", "id": "multi"}, 0)
	var finish: Dictionary = main._card_content({"type": "trig", "id": "finish"}, 0)
	var reso: Dictionary = main._card_content({"type": "link", "id": "reso"}, 0)
	var cata: Dictionary = main._card_content({"type": "cata", "id": "pat"}, 0)
	conditions = conditions and multi["rows"][0]["t"].contains("피해는 줄어") and multi["rows"][0]["t"].contains("벽·블랙홀·투척 장판") and finish["rows"][0]["t"].contains("보스") and reso["rows"][0]["t"].contains("거리") and cata["rows"].size() == 3
	var detail: Dictionary = main._card_content({"type": "mod", "id": "multi"}, 1)
	var full_ok: bool = full.any(func(l): return str(l[0]).begins_with("반응 ")) and full.any(func(l): return str(l[0]).begins_with("형태 성질")) and detail["rows"][0]["t"].contains("(")
	main._set_card_detail(true)
	var on_ok: bool = Meta.card_detail and main.card_detail_btn.button_pressed
	Meta.card_detail = false
	var plain_card: Button = main._card_button({"type":"elem", "e":Elem.WATER, "lv":1}, 1)
	var no_floating_tip := plain_card.tooltip_text == ""
	var dock_brief: bool = main.card_dock.summary_text(plain_card).contains(Elem.BRIEF[Elem.WATER])
	plain_card.free()
	main._set_card_detail(was_d)
	ok("UI-20", basic_ok and conditions and combo_ok and full_ok and on_ok and no_floating_tip and dock_brief, "카드 기본 효과: 15속성·0/12/50웨이브 %s, 조건 %s, 반응 그림 %s, 자세히 보존 %s" % [basic_ok, conditions, combo_ok, full_ok])

	# 카드 선택 막: 선택지가 펼쳐져 있으면 검은 막(카드·카드 줄 버튼은 그 위), 필드 보기·카드를 고르면 곧바로 걷힘
	_fresh(3)
	var dt := _tower(main.center() + Vector2(-200, 0))
	main._start_choose()
	main._process(0.016)
	var dim_on: bool = not main.card_dim.visible and main.card_dock.panel.visible and main.card_dock.side.visible
	main.picks_left = 2
	main._process(0.016)
	var head_two: bool = main.choice_header.visible and main.choice_remaining.text == "2장 더 선택 가능" and main.choice_header.z_index > main.card_dim.z_index
	main.picks_left = 1
	main._process(0.016)
	var head_one: bool = main.choice_remaining.text == "1장 더 선택 가능"
	for card_node in main.choice_box.get_children():
		if card_node.is_queued_for_deletion():
			main.choice_box.remove_child(card_node)
	main.touch_ui = true
	main.tap_sel = 1
	main._process(0.016)
	var apply_row: bool = main.apply_btn.get_meta("choice_icon", {}) == main.choice_box.get_child(1).get_meta("card")[0] and main.apply_btn.visible and main.apply_btn.text.replace("\u2060", "").ends_with(" 적용") and is_equal_approx(main.apply_btn.offset_top, main.reroll_btn.offset_top)
	main.tap_sel = -1
	main.touch_ui = false
	main.perk_mode = true
	main._process(0.016)
	var head_perk: bool = not main.choice_header.visible
	main.perk_mode = false
	main._set_cards_hidden(true)
	main._process(0.016)
	var dim_hide: bool = not main.card_dim.visible
	var head_hide: bool = not main.choice_header.visible
	main._set_cards_hidden(false)
	main._on_pick({"type": "mod", "id": "pierce"})
	main._process(0.016)
	var dim_off: bool = not main.card_dim.visible and main.phase == main.Phase.PLACE
	ok("UI-23", dim_on and dim_hide and dim_off, "일반 판 카드 선택 시 전장 어둠 없음 %s, 필드 보기 %s·카드 고른 뒤 %s 유지" % [dim_on, dim_hide, dim_off])
	ok("UI-30", head_two and head_one and apply_row and head_perk and head_hide and not main.choice_header.visible,
		"카드 줄 선택 안내: 갱신 %s·%s, 적용 줄 %s, 숨김 %s·%s·%s" % [head_two, head_one, apply_row, head_perk, head_hide, not main.choice_header.visible])



	main.shake = 0.0
	main._process(0.0)
	main._process(0.0)
	var transform: Transform2D = main.get_canvas_transform()
	var stable := true
	for stage in [main.Phase.AIM, main.Phase.READY, main.Phase.WAVE, main.Phase.CHOOSE]:
		main.phase = stage
		main._process(0.0)
		stable = stable and main.get_canvas_transform().is_equal_approx(transform)
	var board: Rect2 = main.card_dock.screen_board()
	ok("UI-28", stable and main.arena().size == Meta.FIELD and board.grow(1).encloses(main.get_canvas_transform() * main.arena())
		and not board.intersects(main.card_dock.panel.get_global_rect()), "전장 전체가 도크 위에 표시되고 단계 전환에서 카메라 고정·논리 전장 유지")
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
	main.phase = main.Phase.PLACE


	# 카드 넣을 대상: 넣을 수 있는 오브젝트만 밝게, 못 넣는 오브젝트(NO_MOD 등)는 흐리게·선택 불가
	var bad_t := _tower(main.center() + Vector2(200, 0))
	bad_t.set_pattern("thorn")
	main.picked = {"type": "mod", "id": "pierce"}
	main.phase = main.Phase.PLACE
	main._update_place_dim()
	var marks: bool = main._place_ok(dt) and not main._place_ok(bad_t) and bad_t.modulate == main.PLACE_OFF and dt.modulate == Color.WHITE \
		and main._place_refuse(bad_t) != ""
	main.phase = main.Phase.CHOOSE
	main._update_place_dim()
	var back: bool = bad_t.modulate == Color.WHITE
	ok("UI-24", marks and back, "강화 카드 놓기: 넣을 수 있는 것만 밝게, 관통 연사는 흐리게·이유 문구, 단계가 바뀌면 원래대로")

	# 넣을 오브젝트에 올린 설명: 전·후 숫자만 합친 한 줄, 강화 카드를 넣는 동안 모든 별·바람 둘레는 끔
	var mg: String = Tower.arrow_merge("혼불 3개 (하나 피해 73%) · 공격방식 보정 x1.06", "혼불 4개 (하나 피해 72%) · 공격방식 보정 x1.06")
	var mg2: String = Tower.arrow_merge("없음", "탄 2개")
	main.picked = {"type": "mod", "id": "multi"}
	main.phase = main.Phase.PLACE
	var rings_off: bool = main._place_rings_off()
	main.phase = main.Phase.CHOOSE
	var rings_back: bool = not main._place_rings_off()
	var pv_ok: bool = not (dt.preview({"type": "mod", "id": "multi"})[0] as PackedStringArray)[0].contains("겹쳐서")
	ok("UI-25", mg == "혼불 3→4개 (하나 피해 73→72%) · 공격방식 보정 x1.06" and mg2 == "없음 → 탄 2개" and rings_off and rings_back and pv_ok, "넣기 설명 한 줄 합치기 '%s', 둘레 끔 %s/%s" % [mg, rings_off, rings_back])

	# 오브젝트 정보창: 기본은 피해·공격 속도·치명타 숫자만, 자세히에만 주변 둘레
	_fresh(3)
	var tp := _tower(main.center() + Vector2(0, -150), Elem.SOUL, 3)
	tp.add(Elem.STAR, 1)
	tp.add(Elem.LIGHT, 2)
	tp.eff = tp.eff_now()
	var bl: Array = tp.basic_lines()
	var bl_ok: bool = bl.size() == 3 and (bl[0][0] as String).begins_with("피해 ") and (bl[1][0] as String).begins_with("초당 ") and (bl[2][0] as String).begins_with("치명타 ")
	var plain := _tower(main.center() + Vector2(0, 150))
	plain.eff = plain.eff_now()
	var no_crit: bool = plain.basic_lines().size() == 2
	var dl_more: bool = tp.detail_lines().size() > bl.size()
	var basic_ring: bool = main._ring_target() == null and not main._tip_detail_on()
	ok("UI-26", bl_ok and no_crit and dl_more and basic_ring, "정보창 기본 %d줄 %s, 빛 없으면 치명타 줄 없음 %s, 자세히가 더 많음 %s, 기본엔 둘레 없음 %s" % [bl.size(), bl_ok, no_crit, dl_more, basic_ring])

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
	# 카드를 다 고른 뒤(웨이브 시작 대기)에도 넘기기: 버튼이 보이고, 누르면 넘기기 시작
	_tower(main.center() + Vector2(-200, 0))
	main._enter_ready()
	main.countdown = -1.0
	main._update_skip_ui()
	var ready_btn: bool = main.skip_btn.visible
	main._on_skip()
	ok("SKIP-03", ready_btn and main.skip_left == 3 and main.bank_picks.is_empty() and main.phase == main.Phase.READY, "웨이브 시작 대기에서도 넘기기 (버튼 %s, 남은 %d)" % [ready_btn, main.skip_left])
	main.skip_left = 0
	main.countdown = -1.0
	_clear()

	# 피해 출처
	var tw := Tower.new()
	tw.credit(5.0, "rx:steam")
	tw.credit(2.0, "rx:steam")
	ok("DPS-01", is_equal_approx(tw.dealt, 7.0) and is_equal_approx(tw.src.get("rx:steam", 0.0), 7.0), "피해 출처: 출처별로 나눠 쌓음")
	tw.free()

	# 웨이브 중 실시간 DPS: 최근 5초 이동 평균 (앞쪽 큰 피해는 창 밖으로 빠짐), 접기 상태 저장
	_tower(main.center() + Vector2(-200, 0))
	var lt: Tower = main.towers.get_child(main.towers.get_child_count() - 1)
	var ph0 = main.phase
	main.phase = main.Phase.WAVE
	main.dps_hist.clear()
	main.dps_t = 0.0
	lt.dealt = 1000.0  # 웨이브 초반 큰 피해
	main.wave_time = 0.0
	for i in 40:  # 20초 동안 초당 10
		main._dps_sample(main.DPS_STEP)
		lt.dealt += 10.0 * main.DPS_STEP
		main.wave_time += main.DPS_STEP
	var live: float = main._dps_of(lt)
	main.phase = main.Phase.CHOOSE
	var after: float = main._dps_of(lt)
	main.phase = ph0
	var f0: bool = main.dps_hidden
	main._toggle_dps()
	var saved: bool = Meta.dps_fold == main.dps_hidden and main.dps_hidden != f0
	main._toggle_dps()
	ok("DPS-02", absf(live - 10.0) < 0.01 and after > 50.0 and saved, "실시간 DPS: 웨이브 중 최근 5초 이동 평균 (%.1f, 쉬는 시간엔 웨이브 평균 %.1f), 표 접기 저장" % [live, after])
	_clear()

	# 피해 1~3위 왕관·메달: 쉬는 시간 지난 웨이브 피해 순, 2개면 1위만, 1위가 바뀌면 왕관이 날아감, 설정으로 끔
	var rk: Array = []
	for i in 4:
		_tower(main.center() + Vector2(-240 + 160 * i, 120))
		rk.append(main.towers.get_child(main.towers.get_child_count() - 1))
	var ph1 = main.phase
	main.phase = main.Phase.CHOOSE
	for i in 4:
		rk[i].dealt = [300.0, 900.0, 100.0, 500.0][i]
	main.rank_of.clear()
	main._rank_update()
	var r_ok: bool = main.rank_of.get(rk[1].get_instance_id(), 0) == 1 and main.rank_of.get(rk[3].get_instance_id(), 0) == 2 \
		and main.rank_of.get(rk[0].get_instance_id(), 0) == 3 and not main.rank_of.has(rk[2].get_instance_id())
	rk[2].dealt = 2000.0
	main._rank_update()
	var fly: bool = main.rank_of.get(rk[2].get_instance_id(), 0) == 1 and rk[2].crown_t > 0.0
	main.phase = main.Phase.WAVE
	main.wave_time = 1.0
	rk[1].dealt = 5000.0
	main._rank_update()
	var hold: bool = main.rank_of.get(rk[2].get_instance_id(), 0) == 1  # 웨이브 첫 3초는 그대로
	main.phase = main.Phase.CHOOSE
	for i in 2:
		rk[i].dealt = 0.0
	main._rank_update()
	var two: bool = main.rank_of.size() == 1  # 피해 있는 오브젝트 2개 → 1위만
	var on0: bool = Meta.rank_on
	Meta.rank_on = false
	main._rank_update()
	var off: bool = main.rank_of.is_empty()
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

	# 멀티 난이도: 대결·협동만 구체 체력 x0.7(대결)·중앙 체력 13, 혼자 판은 그대로
	_fresh(3)
	var cores := []
	for st in [[false, 1], [true, 1], [false, 2]]:
		main.vs_on = st[0]
		main.coop_n = st[1]
		main.start_modes()
		cores.append(main.core_max)
	main.vs_on = true
	var vk: float = main.vs_k("vs_hp")
	main.vs_on = false
	main.coop_n = 1
	main.start_modes()
	ok("MP-20", cores == [10, 13, 13] and is_equal_approx(vk, 0.7) and main.vs_k("vs_hp") == 1.0 and main.core_max == 10,
		"멀티 난이도: 중앙 체력 혼자/대결/협동 %s, 대결 구체 체력 x%.2f" % [str(cores), vk])

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
	main._achieve("wave100")
	main._mp_ach_coop(5, {1: 0.5, 2: 0.5})
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
	main._mp_packet(1, {"t": "wait", "s": 45.0, "ids": [2]})
	var waited: bool = is_equal_approx(main.mp_wait_left, 45.0)
	main.mp_afk_n = 0
	main._start_choose()
	main._mp_auto_rest()
	var first := [main.phase == main.Phase.READY, main.mp_i_ready, main.towers.get_child_count() >= 1, main.mp_afk_n == 1, main.mp_afk]
	main.mp_i_ready = false
	main._start_choose()
	main._mp_auto_rest()
	var afk: bool = main.mp_afk
	main._mp_presence()
	var back: bool = not main.mp_afk and main.mp_afk_n == 0
	_fresh(3)
	main.mp_mode = "vs"
	main.mp.my_id = 1
	main.mp_afk_n = 0
	main._start_choose()
	main._mp_auto_rest()
	var vs_go: bool = main.phase == main.Phase.WAVE and main.mp_afk_n == 1
	ok("MP-15", waited and first == [true, true, true, true, false] and afk and back and vs_go and Rules.tune["mp_wait"] == 45.0 and Rules.tune["vs_idle"] == 90.0,
		"잠수: 기다림 %s, 첫 대신 고르기 %s, 2번째 자리 비움 %s, 돌아옴 %s, 대결 웨이브 시작 %s" % [waited, str(first), afk, back, vs_go])
	main.mp_i_ready = false
	main.mp_afk_n = 0

	# MP-16: 속성 요청 — 요청한 속성 카드만 친구 오브젝트에, 받으면 주인 기기가 넣고 요청이 지워짐
	_fresh(3)
	main.mp_mode = "coop"
	main.mp.my_id = 1
	var mine := _tower(main.center() + Vector2(-200, 0), Elem.FIRE)
	var other := _tower(main.center() + Vector2(200, 0), Elem.WOOD)
	other.owner_id = 2
	other.req_e = Elem.WATER
	main.picked = {"type": "elem", "e": Elem.WATER, "lv": 1}
	var can_req: bool = main._place_ok(other)
	main.picked = {"type": "elem", "e": Elem.FIRE, "lv": 1}
	var cant_other: bool = not main._place_ok(other)
	var st: Dictionary = other.mp_state()
	var copy := Tower.new()
	copy.main = main
	copy.mp_apply(st)
	var synced: bool = copy.req_e == Elem.WATER
	copy.free()
	mine.req_e = Elem.WATER
	main._mp_recv_gift(2, {"nid": mine.net_id, "e": Elem.WATER, "lv": 1})
	var given: bool = mine.lv(Elem.WATER) == 1 and mine.req_e == -1 and main.mp_req_got_w == main.wave
	main._mp_recv_gift(2, {"nid": mine.net_id, "e": Elem.ICE, "lv": 1})
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
	var k4: float = main._mp_send_k()
	main.mp_others[4]["alive"] = false
	var k3: float = main._mp_send_k()
	var tgt: int = main._mp_vs_target([3])
	main.phase = main.Phase.CHOOSE
	main.mp_recv_n = 0
	main.mp_next_extra = 0
	main._mp_packet(2, {"t": "atk", "n": 5})
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
	main._save_best()
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
	main.tut_queue.clear()
	Meta.guide_on = true
	main.mp_mode = ""
	main.wave = 4
	Meta.guide_seen.erase("boss")
	Meta.guide_seen.erase("mod")
	main.guide_lines.clear()
	main._tut_event("pat")
	main._guide("boss", "보스 안내")
	main._guide("mod", "일반 안내")
	var single: bool = main.guide_lines.size() == 1 and main.guide_lines[0].contains("보스") and not Meta.guide_seen.has("mod")
	var quiet: bool = main.tut_queue.is_empty() and Tutorial.seen.is_empty() and not paused
	Meta.guide_on = false
	main._process(0.0)
	var hidden_off: bool = not main.guide_label.visible and not main.guide_more.visible and not main.guide_lines.is_empty()
	Meta.guide_on = true
	main.tut_paused = true
	paused = true
	main._open_tut(["pat"])
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
	var preview: bool = main._first_action_text() == "선택한 카드를 적용하세요."
	main.tap_sel = -1
	main.phase = main.Phase.PLACE
	var place: bool = main._first_action_text().contains("빈 곳")
	main.phase = main.Phase.AIM
	var aim: bool = main._first_action_text().contains("방향")
	main._cancel_step()
	var cancel: bool = main.phase == main.Phase.PLACE and main._first_action_text().contains("빈 곳")
	main.phase = main.Phase.READY
	var ready: bool = main._first_action_text() == "웨이브를 시작하세요."
	main.wave = 1
	var finished: bool = main._first_action_text() == ""
	main.wave = 0
	Meta.games = 1
	main.tutor = false
	var veteran: bool = main._first_action_text() == ""
	main.tutor = true
	var reset: bool = main._first_action_text().contains("웨이브")
	Meta.guide_on = false
	var off: bool = main._first_action_text() == ""
	Meta.guide_on = true
	Meta.games = games0
	main.tutor = false
	main.touch_ui = false
	ok("TUT-06", preview and place and aim and cancel and ready and finished and veteran and reset and off, "첫 행동: 터치 확정·설치·방향·취소·시작을 실제 상태에 따라 안내")
	# TUT-04: 시작 화면·일시정지의 [튜토리얼] 버튼, 목록 15개 + 전체 보기, ✓, 항목 → 카드 → 목록으로, 전체 보기 → 도움말
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
	# 이름이 같은 카드(강화 속사·특성 속사)는 이번 판 탭에서 갈래로 구분
	main.run_log = [{"w": 0, "k": "card", "p": "mod:rapid"}, {"w": 1, "k": "perk", "p": "perk:haste"}]
	v.open(main._vote_run_keys())
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
	main._toggle_board()
	main._on_seasons_loaded([{"id": 3, "name": "시즌 3"}, {"id": 2, "name": "시즌 2"}])
	var ch: Dictionary = main.board_chips
	var counts: bool = ch["map"].get_child_count() == Meta.MAP_IDS.size() and ch["rules"].get_child_count() == Rules.IDS.size() \
		and ch["kind"].get_child_count() == 3 and ch["season"].get_child_count() == 2
	# 소용돌이 칩 한 번 → 바로 그 맵, 쉽게 모드 칩 → 쉽게 기록
	ch["map"].get_child(Meta.MAP_IDS.find("spiral")).pressed.emit()
	ch["kind"].get_child(2).pressed.emit()
	var picked: bool = main.board_map == "spiral" and main.board_easy and not main.board_grow
	# 이번 주 탭 → 지난 시즌 칩을 누르면 시즌 전체만 (이번 주 탭 숨김)
	main.board_period_btns[1].pressed.emit()
	var week: bool = main.board_period == "week"
	ch["season"].get_child(1).pressed.emit()
	var old: bool = main.board_season == 2 and main.board_period == "all" and not main.board_period_btns[1].visible
	# 표: 받은 순위가 줄마다, 내 줄은 '나'
	main._on_board_loaded({"tag": main._board_tag(), "period": "all", "entries": [{"rank": 1, "nick": "가나", "wave": 9, "score": 100}, {"rank": 2, "nick": "다라", "wave": 8, "score": 90, "me": true}]})
	var rows: bool = main.board_rows.get_child_count() == 2 and main._board_text().contains("가나") and main._board_text().contains("나")
	var ugc: bool = main.board_ugc_btn.visible and main.board_ugc_btn.is_visible_in_tree()
	main._toggle_board()
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
	main.board_raw = {}
	main.board_people = {}
	var tag: String = main._board_tag()
	main._on_board_loaded({"tag": tag, "period": "all", "season": {"name": "s"}, "entries": [
		{"rank": 1, "nick": "나쁜이름", "wave": 9, "score": 100, "pid": "aaaaaaaaaaaaaaaa"},
		{"rank": 2, "nick": "착한이름", "wave": 8, "score": 90, "pid": "bbbbbbbbbbbbbbbb"},
		{"rank": 3, "nick": "나", "wave": 7, "score": 80, "pid": "cccccccccccccccc", "me": true}]})
	var txt: String = main._board_text()
	var hide_ok: bool = txt.contains("(차단한 플레이어)") and not txt.contains("나쁜이름") and txt.contains("착한이름")
	var people_ok: bool = main.board_people.size() == 2 and main.board_ugc_btn.visible
	main._board_ugc_open()
	var btns: Array = main.board_ugc_panel.find_children("*", "Button", true, false)
	var reps: Array = btns.filter(func(b): return b.text == "신고")
	var unblock: Array = btns.filter(func(b): return b.text == "차단 풀기")
	var panel_ok: bool = main.board_ugc_panel.visible and reps.size() == 2 and unblock.size() == 1 and reps.all(func(b): return b.disabled == not Net.report_ok())
	# 차단 풀기 → 이름이 다시 보임
	unblock[0].pressed.emit()
	var unblock_ok: bool = not Meta.blocked.has("aaaaaaaaaaaaaaaa") and main._board_text().contains("나쁜이름")
	main.board_ugc_panel.visible = false
	main.records_panel.visible = false
	main.board_box.visible = false
	Meta.blocked = keep
	main._save_best()
	# 설정의 [내 온라인 데이터 지우기] (서버 주소가 있는 빌드)
	var del_ok: bool = OnlineConfig.SERVER_URL == "" or main.settings_panel.find_children("*", "Button", true, false).any(func(b): return b.text == "내 온라인 데이터 지우기")
	ok("ONLINE-06", filt and hide_ok and people_ok and panel_ok and unblock_ok and del_ok,
		"닉네임 거르기, 리더보드 차단한 사람 이름 가림·[신고·차단] 창(신고는 서버 report 있을 때만)·차단 풀기, 설정 데이터 지우기 버튼")


## 프리즘 연출(번쩍·굴절 육각형)은 프리즘마다 PRISM_FX_GAP초에 한 번, 피해 +는 탄마다.
## 파편 연출이 난수를 써서 다른 검사의 난수 순서를 흔들지 않게 맨 끝(_lint 앞)에서 돈다.
func _prism_fx() -> void:
	_fresh()
	var c: Vector2 = main.center()
	var r := _tower(c + Vector2(-200, 0))
	var near := _tower(c + Vector2(-100, 0))
	near.add_link("prism")
	main.prism_towers = [near]
	main.refracts = []
	var pdm: Array = []
	for i in 3:
		if i == 2:
			near._process(Tower.PRISM_FX_GAP + 0.01)
		var pp := Projectile.new()
		pp.setup("shot", r, 1, Vector2.RIGHT)
		pp.position = near.position
		var d0: float = pp.dmg
		pp._check_prisms()
		pdm.append(pp.dmg / d0)
		pp.free()
	var fx_ok: bool = main.refracts.size() == 2 and pdm.all(func(x): return is_equal_approx(x, 1.0 + Rules.prism_dmg))
	ok("LINK-02", fx_ok, "프리즘 연출은 %.1f초에 한 번 (탄 3발 중 굴절 %d번), 피해 +%d%%는 탄마다" % [Tower.PRISM_FX_GAP, main.refracts.size(), roundi(Rules.prism_dmg * 100)])
	main.prism_towers = []
	main.refracts = []


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
	var c: Vector2 = main.center()
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
	main._resolve(0.0)  # 격자
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
	main._resolve(0.0)
	dv.step(0.01)
	var dev_ok := prey.is_queued_for_deletion() and is_equal_approx(dv.max_hp, 40.0) and dv.core_dmg == 2 and dv.eaten == 1
	# 안내: 처음 나오는 웨이브에 NEW
	main.wave = 99
	main._update_preview()
	var fresh: bool = main.wave_kinds.any(func(k): return k[0] == "blink" and k[2])
	main.wave = 5
	ok("ORB-03", froms == [100, 175, 250, 350, 500] and share_ok and held and jumped and armor_ok and heal_ok and phase_ok and dev_ok and fresh,
		"후반 구체: 등장 %s 비율 %s 깜빡 %s/%s 갑옷 %s(%.1f·%.1f·%.1f) 치유 %s(%.1f·%.1f) 흐림 %s 포식 %s 안내 %s" % [str(froms), share_ok, held, jumped, armor_ok, d1, d2, d3, heal_ok, n1.hp, n2.hp, phase_ok, dev_ok, fresh])


## 방해 구체 (JAM-01~04)
func _jam_orbs() -> void:
	_fresh(25)
	var c: Vector2 = main.center()
	var froms := [main.jam_from("shade"), main.jam_from("leech"), main.jam_from("seeker")]
	var share_ok: bool = main.jam_share("shade", 19) == 0.0 and is_equal_approx(main.jam_share("shade", 20), 0.05) and is_equal_approx(main.jam_share("shade", 40), 0.07) and is_equal_approx(main.jam_share("shade", 300), 0.12)
	main.mp_mode = "vs"
	var mp_off: bool = not main.jams_on()
	main.mp_mode = ""
	var fresh := false
	main.wave = 19
	main._update_preview()
	fresh = main.wave_kinds.any(func(k): return k[0] == "shade" and k[2])
	main.wave = 25
	ok("JAM-01", froms == [20, 30, 40] and share_ok and mp_off and main.jams_on() and fresh, "등장 %s 비율 %s 멀티 끔 %s 안내 NEW %s" % [str(froms), share_ok, mp_off, fresh])
	# 그림자: 80 안 오브젝트 1.5초 멈춤, 풀린 뒤 4초 면역, 침묵이면 못 함
	var t := _tower(c + Vector2(-200, 0), Elem.FIRE)
	var far := _tower(c + Vector2(200, 0), Elem.FIRE)
	var sh := _orb(c + Vector2(-200, 60), 50.0)
	sh.jam = "shade"
	main.jam_any = true
	main._resolve(0.0)
	main._jam_tick()
	var stopped := is_equal_approx(t.jam_t, 1.5) and far.jam_t == 0.0
	t.jam_t = 0.0
	main._jam_tick()
	var imm := t.jam_t == 0.0 and t.jam_imm > 0.0
	t.jam_imm = 0.0
	sh.silence_t = 2.0
	main._jam_tick()
	var quiet := t.jam_t == 0.0
	# 멈춘 동안 공격하지 않는다 (직선탄이 안 나감)
	t.jam_t = 1.0
	t.dir = Vector2.DOWN
	var np: int = main.projectiles.get_child_count()
	t.attack(0.5, main.targets)
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
	main._jam_death(lc)
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
		o.setup(Orb.Kind.NORMAL, 5.0, 40.0)
		main._jam_trait(o)
		if o.jam == "seeker":
			sk = o
			break
		o.free()
	var aimed: bool = sk != null and sk.jam_tower == t and sk.target == t.position
	var hit_ok := false
	if sk:
		main.orbs.add_child(sk)
		sk.position = t.position + Vector2(10, 0)
		main._resolve(0.0)
		main._jam_tick()
		hit_ok = is_equal_approx(t.jam_t, 3.0) and sk.is_queued_for_deletion()
	main.wave = 25
	ok("JAM-04", aimed and hit_ok, "표적: 가까운 오브젝트 쫓음 %s 닿으면 멈춤·사라짐 %s" % [aimed, hit_ok])
	main.jam_any = false
	_clear()


## 중앙 기술 (SKILL-01~05)
func _skills() -> void:
	_fresh(12)
	var c: Vector2 = main.center()
	main._skills_new_run(1)
	var set_ok: bool = main.skill_ids == ["focus", "brand"] and Skill.SETS.size() == 3
	main.mp_mode = "coop"
	main._skills_new_run(0)
	var mp_off: bool = main.skill_ids.is_empty()
	main.mp_mode = ""
	main._skills_new_run(0)
	ok("SKILL-01", set_ok and mp_off and main.skill_ids == ["focus", "hold"], "묶음 3개 중 고른 둘 %s, 멀티는 없음 %s" % [set_ok, mp_off])
	main.phase = main.Phase.WAVE
	var t := _tower(c + Vector2(-150, 0), Elem.FIRE)
	var k0 := t.spd_k()
	var used: bool = main._use_skill("focus", t.position + Vector2(20, 10))
	var fast := is_equal_approx(t.spd_k(), k0 * 2.0) and is_equal_approx(t.focus_t, 6.0)
	var cd_ok: bool = is_equal_approx(main.skill_left("focus"), 25.0) and not main._use_skill("focus", t.position)
	var miss: bool = not main._use_skill("hold", c + Vector2(400, 300)) and main.skill_left("hold") == 0.0
	main._skill_tick(10.0)
	var ticked: bool = is_equal_approx(main.skill_left("focus"), 15.0)
	ok("SKILL-02", used and fast and cd_ok and miss and ticked, "집중: 공속 x2 6초 %s, 다시 쓰기 25초 %s, 빈 곳엔 안 씀 %s, 게임 시간으로 줄어듦 %s" % [fast, cd_ok, miss, ticked])
	var a := _orb(c + Vector2(200, 0), 50.0)
	var b := _orb(c + Vector2(260, 40), 50.0)
	var boss := _orb(c + Vector2(180, -60), 50.0, Orb.Kind.BOSS)
	var out := _orb(c + Vector2(200, 200), 50.0)
	main._resolve(0.0)
	var held: bool = main._use_skill("hold", c + Vector2(210, 0))
	var hold_ok: bool = held and is_equal_approx(a.root_timer, 2.0) and is_equal_approx(b.root_timer, 2.0) and is_equal_approx(boss.root_timer, 1.0) and out.root_timer == 0.0 and is_equal_approx(main.skill_left("hold"), 30.0)
	ok("SKILL-03", hold_ok, "붙잡기: 120 안 2초(보스 1초), 밖은 그대로, 다시 쓰기 30초")
	main._skills_new_run(2)
	main.phase = main.Phase.WAVE
	main._use_skill("brand", c + Vector2(210, 0))
	var hp0 := a.hp
	a.hurt(10.0)
	var brand_ok: bool = a.amp.has("brand") and is_equal_approx(hp0 - a.hp, 13.0) and not out.amp.has("brand")
	ok("SKILL-04", brand_ok, "낙인: 150 안 구체 받는 피해 +30%% (%.1f)" % [hp0 - a.hp])
	# 빠른 손 -20%(겹치면 곱), 자동 사용은 몰린 곳에
	main.perks = {"quick": 2}
	var q_ok := is_equal_approx(Skill.cd_full("brand", 2), 20.0 * 0.64)
	main.skill_cd = {}
	main.auto_skills = true
	for o in [a, b, boss, out]:
		o.amp.clear()
		o.root_timer = 0.0
		o.root_immune = 0.0
		o.root_dr = 0
	main._resolve(0.0)
	main._skill_tick(0.01)
	var auto_ok: bool = main.skill_left("hold") > 0.0 and main.skill_left("brand") > 0.0 and a.amp.has("brand") and is_equal_approx(main.skill_left("brand"), 12.8)
	main.auto_skills = false
	main.perks = {}
	main.phase = main.Phase.CHOOSE
	main._skills_new_run(0)
	ok("SKILL-05", q_ok and auto_ok, "빠른 손 2번 x0.64 %s, 자동 사용 %s" % [q_ok, auto_ok])
	_clear()
	_hold_immunity()


## 붙잡기 실패는 사용 횟수·쿨다운·성공 효과를 쓰지 않고, 수동 조준은 유지한다.
func _hold_immunity() -> void:
	for natural in [false, true]:
		for kind in [Orb.Kind.NORMAL, Orb.Kind.BOSS]:
			_fresh(12)
			main._skills_new_run(0)
			main.phase = main.Phase.WAVE
			var o := _orb(main.center() + Vector2(210, 0), 100.0, kind, 60.0)
			if natural:
				for i in 3:
					o.root(2.0)
				for i in 121:
					o.step(1.0 / 60.0)
			else:
				o.root_immune = 2.0
			main._resolve(0.0)
			main._arm_skill(1)
			var fx_n: int = main.skill_fx.size()
			var immune := o.root_immune > 0.0 and o.root_timer == 0.0
			var used: bool = main._use_skill("hold", o.position)
			var no_cost: bool = not used and main.skill_left("hold") == 0.0 and main.skill_used == 0
			var feedback: bool = main.skill_arm == "hold" and main.toast.text.contains(main._kr_keep("면역"))
			ok("SKILL-03", immune and no_cost and feedback and o.root_timer == 0.0 and main.skill_fx.size() == fx_n,
				"붙잡기 전부 면역: 자연 %s·종류 %d, 사용 %s·쿨다운 %.1f·안내 %s" % [natural, kind, used, main.skill_left("hold"), feedback])

	# near는 격자 후보를 돌려주므로 죽은 구체·실제 범위 밖 면역 구체는 면역 안내 대상이 아니다.
	_fresh(12)
	main._skills_new_run(0)
	main.phase = main.Phase.WAVE
	var p: Vector2 = main.center() + Vector2(210, 0)
	var dead := _orb(p, 50.0)
	dead.root_immune = 2.0
	var outside := _orb(p + Vector2(150, 0), 50.0)
	outside.root_immune = 2.0
	main._resolve(0.0)
	dead.hp = 0.0
	main._arm_skill(1)
	var missed: bool = not main._use_skill("hold", p)
	ok("SKILL-03", missed and main.skill_left("hold") == 0.0 and main.toast.text.contains(main._kr_keep("없어요")) and not main.toast.text.contains(main._kr_keep("면역")),
		"붙잡기 빈 범위: 죽은 구체·범위 밖 면역 구체는 제외하고 구체 없음 안내")

	# 성공한 첫 구체 때문에 뒤 구체의 root 호출을 건너뛰면 안 된다. 순서를 바꿔 둘 다 확인한다.
	for immune_first in [false, true]:
		_fresh(12)
		main._skills_new_run(0)
		main.phase = main.Phase.WAVE
		var c: Vector2 = main.center() + Vector2(210, 0)
		var group: Array = []
		for i in 3:
			group.append(_orb(c + Vector2(0, i * 20), 50.0))
		var immune: Orb = group[0 if immune_first else 2]
		immune.root_immune = 2.0
		main._resolve(0.0)
		main._arm_skill(1)
		var used: bool = main._use_skill("hold", c)
		var stopped: bool = group.all(func(o): return o == immune or is_equal_approx(o.root_timer, 2.0))
		ok("SKILL-03", used and stopped and immune.root_timer == 0.0 and is_equal_approx(main.skill_left("hold"), 30.0) and main.skill_used == 1 and main.skill_arm == "",
			"붙잡기 혼합 범위: 면역 먼저 %s, 비면역 구체 모두 정지·쿨다운 한 번" % immune_first)

	# 자동 사용은 면역 실패를 조용히 넘기고, 면역이 끝나면 같은 기술을 다시 시도한다.
	_fresh(12)
	main._skills_new_run(0)
	main.phase = main.Phase.WAVE
	var boss := _orb(main.center() + Vector2(210, 0), 100.0, Orb.Kind.BOSS)
	boss.root_immune = 2.0
	main._resolve(0.0)
	main.toast.text = "자동 사용 전"
	main.auto_skills = true
	main._skill_tick(0.01)
	var quiet: bool = main.skill_left("hold") == 0.0 and main.skill_used == 0 and main.toast.text == "자동 사용 전"
	boss.step(2.1)
	main._resolve(0.0)
	main._skill_tick(0.01)
	ok("SKILL-03", quiet and is_equal_approx(boss.root_timer, 1.0) and is_equal_approx(main.skill_left("hold"), 30.0) and main.skill_used == 1,
		"붙잡기 자동 사용: 면역 중 비용·안내 없음, 면역이 풀리면 다시 사용")
	main.auto_skills = false
	main.phase = main.Phase.CHOOSE
	main._skills_new_run(0)
	_clear()


## 기맥·빌드 읽기 (LEY-01..03, BUILD-01..02)
func _ley_build() -> void:
	_fresh(12)
	var c: Vector2 = main.center()
	main.run_id = "spec-ley"
	main._ley_new_run()
	var a: Array = main.ley.duplicate()
	main._ley_new_run()
	var same: bool = a == main.ley
	var fr: Rect2 = main.field_rect().grow(-90.0)
	var cons := a.size() == 3
	for i in a.size():
		var d: float = a[i].distance_to(main.core())
		cons = cons and fr.has_point(a[i]) and d >= 150.0 and d <= 360.0
		for j in i:
			cons = cons and a[i].distance_to(a[j]) >= 220.0
	main.run_id = "spec-ley-2"
	main._ley_new_run()
	var differs: bool = main.ley != a
	ok("LEY-01", same and cons and differs, "판 번호로 정해지는 3곳 %s, 가장자리 90·중앙 150~360·서로 220 %s, 판마다 다름 %s" % [same, cons, differs])
	main.ley = [c + Vector2(200, 0)]
	var t1 := _tower(c + Vector2(210, 0), Elem.FIRE)
	var t2 := _tower(c + Vector2(225, 0), Elem.FIRE)
	var t3 := _tower(c + Vector2(-200, 0), Elem.FIRE)
	main.phase = main.Phase.CHOOSE
	var one: bool = main.on_ley(t1) and not main.on_ley(t2) and not main.on_ley(t3)
	var f_on := t1.dmg_factor()
	main.ley = []
	var k := f_on / t1.dmg_factor()
	ok("LEY-02", one and is_equal_approx(k, 1.15), "자리마다 가장 가까운 하나만 %s, 피해 x%.2f" % [one, k])
	main.ley = []
	main.run_id = "spec-ley"
	main._ley_new_run()
	var save_ok := true
	var saved: Array = main.ley.map(func(q): return [q.x, q.y])
	var back: Array = saved.map(func(q): return Vector2(q[0], q[1]))
	save_ok = back == main.ley
	Rules.tune["ley_on"] = 0.0
	main._ley_new_run()
	var off: bool = main.ley.is_empty()
	Rules.tune.erase("ley_on")
	ok("LEY-03", save_ok and off, "이어하기 저장 [x,y] %s, ley_on 0이면 없음 %s" % [save_ok, off])
	main.ley = []
	# 빌드 읽기
	t1.run_src = {"hit": 900.0, "elem:fire": 500.0, "rx:lava": 300.0, "etc:crowd": 200.0}
	t3.run_src = {"pat:spray": 150.0, "mod:split": 50.0}
	t2.run_src = {}
	for t in [t1, t2, t3]:
		t.src = {}
	main.wave = 12
	main._refresh_build()
	var top: Array = main.build_cache
	var top_ok: bool = top.size() >= 3 and top[0][0] == "elem:fire" and top[1][0] == "rx:lava" and not top.any(func(it): return it[0] == "hit" or str(it[0]).begins_with("etc:"))
	ok("BUILD-01", top_ok, "주력 순서(직접 타격·공통 몫 뺌) %s" % [top.map(func(it): return it[0])])
	var f_fire: String = main.core_fit({"type": "elem", "e": Elem.FIRE, "lv": 1})
	var rx_ok := true
	for r in Elem.REACTIONS:
		if str(r["id"]) == "lava":
			var other: int = r["b"] if r["a"] == Elem.FIRE else r["a"]
			rx_ok = main.core_fit({"type": "elem", "e": other, "lv": 1}) != ""
	var no_pat: bool = main.core_fit({"type": "pat", "id": "spray"}) == ""
	main.wave = 2
	main._refresh_build()
	var early: bool = main.build_cache.is_empty()
	ok("BUILD-02", f_fire != "" and rx_ok and no_pat and early, "주력 카드 ◎: 속성 %s, 반응의 다른 속성 %s, 3위 아래는 없음 %s, 3웨이브 전엔 안 셈 %s" % [f_fire != "", rx_ok, no_pat, early])
	_clear()


## 후반 곡선 (WAVE-12)
func _late_curve() -> void:
	var g150: float = main.hp_growth(150)
	var g151: float = main.hp_growth(151)
	var hp_ok := is_equal_approx(g150, pow(1.05, 140)) and is_equal_approx(g151, pow(1.05, 140) * 1.03 * 305.0 / 303.0)
	var n_ok: bool = main.wave_size(150) == 303 and main.wave_size(400) == 303 and main.wave_size(100) == 203
	var s_ok: bool = main.orb_base_speed(100) == 330.0 and main.orb_base_speed(450) == 1380.0 and main.orb_base_speed(600) == 1380.0
	ok("WAVE-12", hp_ok and n_ok and s_ok, "후반 곡선: 체력 150까지 x1.05·뒤 x1.03(+수 상한 몫) %s, 구체 수 303 상한 %s, 속도 450웨이브 값 1380 상한 %s" % [hp_ok, n_ok, s_ok])
