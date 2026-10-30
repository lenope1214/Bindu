extends SceneTree
# 조합별 효율: 소용돌이 맵에서 오브젝트 하나(봇처럼 중앙 가까이에서 길목 바깥쪽을 겨눔) 앞으로
# 나선을 따라 들어오는 구체 무리(초당 3개)에 SECS초 동안 준 피해/초(all), 그중 반응 피해(rx),
# 구체가 중앙까지 걸린 시간 배율(delay, 오브젝트 없을 때 = 1.00).
# 구체는 죽지 않아 처치로 터지는 효과(영혼 넋·저주 등)는 빠진다.
# 사용: godot --headless --fixed-fps 60 --path . -s tools/combo_eff.gd
# 환경 변수:
#   SET=ep (속성×공격방식) | pm (공격방식×강화) | rx (특수 반응 = 두 속성) | lv (공격방식 레벨 성장)
#   RULES=1|3  STAGE=early|mid|late (속성 Lv1/3/6, 공격방식 Lv1/2/4, 강화 0/2/5개)
#   PART=i/n (i번째 조각만, 여러 프로세스로 나눠 돌리기)  SECS(기본 20)
#   PARTNER=<공격방식> PPOS=0~3 (금속 파트너를 PPOS 자리에 같은 단계로 두고 파트너가 준 피해/초 pd를 같이 찍는다.
#     끌기·늦추기 같은 군중 제어가 남을 얼마나 돕는지: 같은 단계 직선탄을 넣었을 때의 pd와 비교)
var main
const STAGES := {"early": [1, 1, 0], "mid": [3, 2, 2], "late": [6, 4, 5]}
var secs := 20.0
var base_travel := 0.0
var partner := ""
var stage_lv: Array = [1, 1, 0]


func _initialize():
	Meta.map_id = "spiral"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	Meta.rules = int(OS.get_environment("RULES")) if OS.get_environment("RULES") != "" else 1
	Meta.map_id = "spiral"
	main._apply_rules()
	secs = float(OS.get_environment("SECS")) if OS.get_environment("SECS") != "" else 20.0
	var stage := OS.get_environment("STAGE") if OS.get_environment("STAGE") != "" else "mid"
	var st: Array = STAGES[stage]
	stage_lv = st
	partner = OS.get_environment("PARTNER")
	var set := OS.get_environment("SET") if OS.get_environment("SET") != "" else "ep"
	var jobs := []
	match set:
		"ep":
			for p in Pat.PATTERN_IDS:
				for e in Elem.ALL:
					jobs.append({"els": [e], "lv": st[0], "pat": p, "plv": st[1], "mods": {}})
		"pm":
			# 강화 효과: 불 Lv(단계) 하나로, 강화 없음과 강화 하나 종류를 (단계 개수만큼, 최소 2) 쌓은 것
			var n: int = maxi(st[2], 2)
			for p in Pat.PATTERN_IDS:
				jobs.append({"els": [Elem.FIRE], "lv": st[0], "pat": p, "plv": st[1], "mods": {}})
				for mid in Pat.MOD_IDS:
					jobs.append({"els": [Elem.FIRE], "lv": st[0], "pat": p, "plv": st[1], "mods": {mid: n}})
		"rx":
			for r in Elem.REACTIONS:
				jobs.append({"els": [r["a"], r["b"]], "lv": st[0], "pat": "shot", "plv": 1, "mods": {}, "rx": r["id"]})
		"lv":
			for p in Pat.PATTERN_IDS:
				for l in [1, 2, 3, 4, 6]:
					jobs.append({"els": [Elem.FIRE], "lv": 1, "pat": p, "plv": l, "mods": {}})
	var part := OS.get_environment("PART")
	if part != "":
		var a := part.split("/")
		var i := int(a[0]); var n := int(a[1])
		var mine := []
		for k in jobs.size():
			if k % n == i: mine.append(jobs[k])
		jobs = mine
	base_travel = (await _run({"els": [], "lv": 1, "pat": "shot", "plv": 1, "mods": {}}))["travel"]
	for j in jobs:
		var r = await _run(j)
		var en := ",".join(j["els"].map(func(e): return Elem.NAMES[e]))
		var md := ",".join(j["mods"].keys().map(func(k): return "%s%d" % [k, j["mods"][k]]))
		print("COMBO set=%s rules=%d stage=%s pat=%s plv=%d els=%s lv=%d mods=%s rx=%s all=%.2f rxd=%.2f delay=%.2f pd=%.2f" % [
			set, Meta.rules, stage, j["pat"], j["plv"], en, j["lv"], md if md != "" else "-", j.get("rx", "-"),
			r["all"], r["rx"], r["travel"] / maxf(base_travel, 0.01), r["pd"]])
	quit()


func _clear():
	for c in main.towers.get_children(): c.free()
	for c in main.orbs.get_children(): c.free()
	for c in main.zones.get_children(): c.free()
	for c in main.projectiles.get_children(): c.free()


## 봇 eff_lane과 같은 식: 각도 a에서 나온 구체가 중앙 170 거리를 지날 때의 각도
func _eff_lane(a: float) -> float:
	var c = main.center()
	var p = c + Vector2(cos(a), sin(a)) * 650
	while p.distance_to(c) > 170:
		p += (c - p).normalized().rotated(main.SPIRAL_SWIRL) * 4.0
	return (p - c).angle()


func _run(j: Dictionary) -> Dictionary:
	seed(7)
	var spawn_rng := RandomNumberGenerator.new()  # 구체 흐름은 오브젝트가 쓰는 무작위와 따로 (모든 조합이 같은 흐름을 받게)
	spawn_rng.seed = 7
	_clear()
	main.wave = 20
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.wave_time = 10.0
	main.to_spawn = 0
	main.core_hp = 99999
	var a0 := -PI / 2.0
	var c = main.center()
	var ld := Vector2.from_angle(_eff_lane(a0))
	var t = null
	if not j["els"].is_empty():
		main.picked = {"e": j["els"][0], "lv": j["lv"]}
		main._place_tower(c + ld * 100.0, ld)
		t = main.towers.get_child(0)
		for k in range(1, j["els"].size()):
			t.add(j["els"][k], j["lv"])
		if j["pat"] != "shot":
			t.set_pattern(j["pat"])
		while t.plv < j["plv"]:
			t.set_pattern(j["pat"])
		for mid in j["mods"]:
			for k in j["mods"][mid]:
				t.add_mod(mid)
		t.dealt = 0.0
		t.rx_dealt = 0.0
	var pt = null
	if partner != "":
		main.picked = {"e": Elem.METAL, "lv": stage_lv[0]}  # 금속: 무작위가 없고 화상처럼 다른 오브젝트 상태를 덮어쓰지 않음
		# PPOS: 0 옆(왼) 1 옆(오른) 2 나선 다음 자리(중앙 둘레 0.8라디안 뒤) 3 길목 바깥쪽(중앙에서 160)
		var pp: Vector2 = [c + ld * 100.0 + ld.orthogonal() * 50.0, c + ld * 100.0 - ld.orthogonal() * 50.0,
			c + ld.rotated(0.8) * 100.0, c + ld * 160.0][int(OS.get_environment("PPOS"))]
		main._place_tower(pp, (pp - c).normalized())
		pt = main.towers.get_child(main.towers.get_child_count() - 1)
		if partner != "shot":
			pt.set_pattern(partner)
		while pt.plv < stage_lv[1]:
			pt.set_pattern(partner)
		pt.dealt = 0.0
	var spawn_t := 0.0
	var travel := 0.0
	var crossed := 0
	var frames := int(60 * secs)
	for f in frames:
		main.phase = main.Phase.WAVE
		main.wave_active = true
		main.core_hp = 99999
		spawn_t -= 1.0 / 60
		if spawn_t <= 0 and f < frames - 60 * 8:
			spawn_t = 1.0 / 3.0
			var o = Orb.new(); o.main = main
			var a := a0 + spawn_rng.randf_range(-0.12, 0.12)
			o.position = c + Vector2.from_angle(a) * main._spawn_radius()
			o.from_a = a
			o.target = c
			o.swirl = main.SPIRAL_SWIRL
			o.setup(Orb.Kind.NORMAL, 1000000, 90)
			o.set_meta("born", f)
			main.orbs.add_child(o)
		await process_frame
		for o in main.orbs.get_children():
			if o.is_queued_for_deletion(): continue
			if o.position.distance_to(c) < 45.0:
				crossed += 1
				travel += (f - int(o.get_meta("born"))) / 60.0
				o.queue_free()
	# 시간 안에 못 들어온 구체는 지금까지 걸린 시간으로 (막아 둔 만큼 지연에 들어감)
	for o in main.orbs.get_children():
		if not o.is_queued_for_deletion():
			crossed += 1
			travel += (frames - int(o.get_meta("born"))) / 60.0
	var span := secs
	return {"all": (t.dealt if t else 0.0) / span, "rx": (t.rx_dealt if t else 0.0) / span, "travel": travel / maxf(crossed, 1), "pd": (pt.dealt if pt else 0.0) / span}
