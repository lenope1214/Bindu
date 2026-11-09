extends "res://tools/spec_check.gd"
## _guard_pick의 교체 전 구현을 독립 참조로 보존한 대상·동률·난수 differential.
## 저장 분리 BinduTools 사본 + 빈 서버 URL에서만 실행한다.
var output := ""
var comparisons := 0
var mismatches: Array = []
var mismatch_count := 0
var pool: Array = []
var benchmark: Array = []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 10
	Meta.guide_on = false
	Meta.skill_auto = false
	Meta.pause_on_focus_loss = false
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.progression_system._hide_title()
	_fresh(39)
	main.countdown = -1.0
	main.phase = main.Phase.READY
	var t := _tower(main.viewport_system.center() + Vector2(180, 60), Elem.FIRE, 3)
	t.add(Elem.WIND, 2)
	t.add(Elem.WATER, 2)
	for id in ["size", "homing", "multi"]:
		for n in 3:
			t.add_mod(id)
	t.eff = t.eff_now()
	make_pool()
	var invalid := Orb.new()
	pool.append(invalid)
	invalid.free()  # 해제된 참조는 기존 구현처럼 건너뛴다.
	pool.append(null)
	var queued := _orb(Vector2(1400, 900), 100.0)
	queued.queue_free()  # 기존 구현은 유효한 queued 구체를 별도 제외하지 않는다.
	pool.append(queued)
	var cases: Array = []
	for map_id in MapRule.AFF:
		Meta.map_id = map_id
		Rules.tune["map_on"] = 1.0
		main.lanes.assign([-2.5, -0.4, 1.1])
		for auto_aim in [0.0, 1.0]:
			Rules.tune["auto_aim"] = auto_aim
			for pattern in Pat.PATTERN_IDS:
				t.set_pattern(pattern)
				for angle in [0.0, PI / 2.0, -2.2]:
					t.set_attack_direction(Vector2.from_angle(angle))
					place_boundaries(t)
					for pref in [-1.0, 0.0, 0.12, 0.6, PI]:
						Rules.tune["aim_pref"] = pref
						for band in [-100.0, -0.0001, 0.0, 0.0001, 40.0, 1000.0]:
							Rules.tune["aim_band"] = band
							compare(t, pool, "%s/%s/auto%s/dir%s/pref%s/band%s" % [map_id, pattern, auto_aim, angle, pref, band])
		cases.append(map_id)
	# main이 없는 재사용 경로는 중앙 대신 오브젝트와의 거리를 쓴다.
	t.main = null
	for pref in [-1.0, 0.0, 0.6, PI]:
		Rules.tune["aim_pref"] = pref
		for band in [-1.0, 0.0, 40.0]:
			Rules.tune["aim_band"] = band
			compare(t, pool, "without-main/pref%s/band%s" % [pref, band])
	t.main = main
	manual_boundaries(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9009
	for i in 1000:
		Meta.map_id = MapRule.AFF.keys()[i % MapRule.AFF.size()]
		Rules.tune["auto_aim"] = float(i % 2)
		Rules.tune["aim_pref"] = rng.randf_range(-0.2, PI)
		Rules.tune["aim_band"] = rng.randf_range(-20.0, 300.0)
		t.set_pattern(Pat.PATTERN_IDS[i % Pat.PATTERN_IDS.size()])
		t.set_attack_direction(Vector2.from_angle(rng.randf_range(-PI, PI)))
		for j in 44:
			pool[j].position = main.viewport_system.center() + Vector2(rng.randf_range(-650, 650), rng.randf_range(-400, 400))
			pool[j].hp = 0.0 if (i + j) % 13 == 0 else 100.0
		compare(t, pool, "seeded-%d" % i)
	if args.size() < 2 or args[1] != "check":
		run_benchmark(t)
	var report := {"comparisons":comparisons, "mismatch_count":mismatch_count, "mismatches":mismatches, "maps":cases, "patterns":Pat.PATTERN_IDS, "finite_position_cases":true, "rng_contract":"reference and actual leave global RNG untouched", "benchmark":benchmark, "engine":Engine.get_version_info(), "display_server":DisplayServer.get_name(), "tower_sha256":FileAccess.get_sha256("res://scripts/tower.gd"), "tool_sha256":FileAccess.get_sha256("res://tools/battlefield_targeting_check.gd")}
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("TARGETING comparisons=%d mismatches=%d" % [comparisons, mismatch_count])
	for row in benchmark:
		print("BENCH ", JSON.stringify(row))
	quit(1 if not mismatches.is_empty() else 0)

func make_pool() -> void:
	var center: Vector2 = main.viewport_system.center()
	for i in 44:
		var at := center + Vector2((i % 11 - 5) * 95.0, (floori(i / 11.0) - 1.5) * 140.0)
		pool.append(_orb(at, 0.0 if i % 11 == 0 else 100.0))
	for at in [Vector2(80, 0), Vector2(0, 80), Vector2(-80, 0), Vector2(0, -80)]:
		pool.append(_orb(center + at, 100.0))
	for i in 3:
		pool.append(_orb(center, 100.0))

func place_boundaries(t: Tower) -> void:
	var reach := t.reflex_range(t.dir)
	var epsilon := maxf(0.0001, reach * 0.00001)
	for i in 3:
		pool[48 + i].position = t.position + t.dir * (reach + [-epsilon, 0.0, epsilon][i])

func compare(t: Tower, candidates: Array, label: String) -> void:
	comparisons += 1
	seed(12345)
	var expected_rng := randi()
	seed(12345)
	var reference := guard_reference(t, candidates)
	var reference_rng := randi()
	seed(12345)
	var actual := t._guard_pick(candidates)
	var actual_rng := randi()
	if actual != reference or reference_rng != expected_rng or actual_rng != expected_rng:
		mismatch_count += 1
		if mismatches.size() < 30:
			mismatches.append({"case":label, "expected":reference.get_instance_id() if reference != null else 0, "actual":actual.get_instance_id() if actual != null else 0, "rng_preserved":actual_rng == expected_rng and reference_rng == expected_rng})

func manual_boundaries(t: Tower) -> void:
	Meta.map_id = "plain"
	Rules.tune["auto_aim"] = 1.0
	Rules.tune["aim_pref"] = 0.1
	Rules.tune["aim_band"] = 40.0
	t.set_pattern("shot")
	t.position = main.viewport_system.center() + Vector2(200, 0)
	t.set_attack_direction(Vector2.RIGHT)
	var near := _orb(main.viewport_system.center() + Vector2(-10, 0), 100.0)
	var preferred := _orb(main.viewport_system.center() + Vector2(250, 0), 100.0)
	# 정확히 band 경계인 방향 후보와 경계 밖을 각각 비교한다.
	for d in [0.0, 0.0001, -0.0001]:
		Rules.tune["aim_band"] = 240.0 + d
		compare(t, [near, preferred], "exact-band-%s" % d)
		compare(t, [preferred, near], "exact-band-reversed-%s" % d)
	Rules.tune["aim_band"] = 1000.0
	var tie := _orb(preferred.position, 100.0)
	compare(t, [preferred, tie], "preferred-tie-first")
	compare(t, [tie, preferred], "preferred-tie-reversed")
	var cone_edge := _orb(t.position + Vector2.from_angle(0.6) * 100.0, 100.0)
	var edge_angle := absf(t.dir.angle_to(cone_edge.position - t.position))
	for offset in [-0.0000001, 0.0, 0.0000001]:
		Rules.tune["aim_pref"] = edge_angle + offset
		compare(t, [near, cone_edge], "exact-cone-%s" % offset)
	compare(t, [], "empty")
	compare(t, [null], "null-only")
	for hp in [0.0, -1.0]:
		near.hp = hp
		compare(t, [near], "dead-only-%s" % hp)

func run_benchmark(t: Tower) -> void:
	Meta.map_id = "storm"
	Rules.tune["map_on"] = 1.0
	Rules.tune["auto_aim"] = 1.0
	Rules.tune["aim_pref"] = 0.6
	Rules.tune["aim_band"] = 40.0
	t.position = main.viewport_system.center() + Vector2(180, 60)
	t.set_attack_direction(Vector2.LEFT)
	var candidates: Array = []
	for i in 300:
		candidates.append(_orb(Vector2(90 + (i % 25) * 44, 105 + floori(i / 25.0) * 43), 100.0))
	for pattern in ["shot", "spray", "wall"]:
		t.set_pattern(pattern)
		for i in 60:
			guard_reference(t, candidates)
			t._guard_pick(candidates)
		var baseline: Array = []
		var optimized: Array = []
		for batch in 8:
			for which in ([0, 1] if batch % 2 == 0 else [1, 0]):
				var start := Time.get_ticks_usec()
				for i in 200:
					if which == 0:
						guard_reference(t, candidates)
					else:
						t._guard_pick(candidates)
				var elapsed := (Time.get_ticks_usec() - start) / 1000.0 / 200.0
				(baseline if which == 0 else optimized).append(elapsed)
		var a := baseline.duplicate()
		var b := optimized.duplicate()
		a.sort()
		b.sort()
		benchmark.append({"pattern":pattern, "orbs":300, "calls_per_batch":200, "batches":8, "reference_ms_per_call":baseline, "actual_ms_per_call":optimized, "reference_median_ms":(a[3] + a[4]) / 2.0, "actual_median_ms":(b[3] + b[4]) / 2.0, "scope":"headless function CPU; not native frame or GPU performance"})

## 교체 전 _guard_pick의 후보 배열·2pass를 독립 참조로 유지한다.
func guard_reference(t: Tower, orbs: Array) -> Orb:
	var cand := []
	var top := INF
	for o in orbs:
		if not is_instance_valid(o) or o.hp <= 0.0:
			continue
		var v: Vector2 = o.position - t.position
		if v.length() > t.reflex_range(v):
			continue
		var g := t.goal_dist(o)
		cand.append([o, g, Rules.t("aim_pref") > 0.0 and absf(t.dir.angle_to(v)) <= Rules.t("aim_pref")])
		top = minf(top, g)
	var pick: Orb = null
	var pick_g := INF
	var pick_in := false
	for c in cand:
		if c[1] > top + Rules.t("aim_band"):
			continue
		if pick == null or (c[2] and not pick_in) or (c[2] == pick_in and c[1] < pick_g):
			pick = c[0]
			pick_g = c[1]
			pick_in = c[2]
	return pick
