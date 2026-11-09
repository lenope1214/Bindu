extends SceneTree
## BF49 유한 실험. 제품 Zone은 수정하지 않고 실제 참조와 cell→point index 후보를 비교한다.
class WideOrb extends Orb:
	func radius() -> float:
		return 128.0

var main
var assertions := 0
var failures := 0
var expected_mutant_failures := 0
var output := ""
var rows: Array = []
var source_hashes := {}
var geom_rng := RandomNumberGenerator.new()
var last_checks := 0
var benchmark_only := false
var mutant_mode := ""
var case_serial := 0
var affect_completed := 0
var identity_labels := {}

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1
	print(("ok " if condition else "FAIL ") + description)

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "" or DisplayServer.get_name() != "headless":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else ""
	benchmark_only = args.has("bench")
	if args.has("mutant-moved"): mutant_mode = "no_moved_fallback"
	if args.has("mutant-radius"): mutant_mode = "no_radius_fallback"
	if output != "": DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func run() -> void:
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 5
	Meta.guide_on = false
	Meta.fx_low = false
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.mp.set_process(false)
	main.sfx.set_muted(true)
	main.progression_system._hide_title()
	main.auto_start = false
	await process_frame
	for path in ["scripts/zone.gd", "scripts/orb.gd", "scripts/share.gd", "scripts/tower.gd", "scripts/features/combat.gd", "tools/battlefield_zone_check.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://" + path)
	if mutant_mode != "":
		mutant_boundary_run()
	elif benchmark_only:
		benchmark_cases()
	else:
		selection_cases()
		mutant_cases()
		affect_cases()
		check(affect_completed == 4, "four affect suites completed")
	for player in main.sfx.players + main.sfx.lead + [main.sfx.music_player]:
		player.stream_paused = false
		player.stop()
		player.stream = null
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if output != "":
		FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions, "failures":failures, "expected_mutant_failures":expected_mutant_failures, "benchmark_only":benchmark_only, "mutant_mode":mutant_mode, "engine":Engine.get_version_info(), "display":DisplayServer.get_name(), "source_hashes":source_hashes, "rows":rows}, "\t"))
	print("ZONE CHECK assertions=%d mutants=%d failures=%d" % [assertions, expected_mutant_failures, failures])
	quit(1 if failures else 0)

func clear_world() -> void:
	identity_labels.clear()
	for layer in [main.towers, main.orbs, main.zones, main.projectiles]:
		for node in layer.get_children(): node.free()
	main.combat_system.grid.clear()
	main.combat_system.targets.clear()
	main.wells.clear()
	main.particles.clear()
	main.popups.clear()
	main.bolts.clear()
	main.pulses.clear()
	main.run_game = 5.0
	main.wave = 7
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.sim_id = 91
	main.wave_dmg = 0.0
	main.score = 0
	main.kills = 0
	main.combo = 0
	main.combo_t = 0.0
	main.combo_bonus = 0
	main.core_hp = main.CORE_MAX_HP
	main.perks = {}
	main.ley = []
	Meta.tally = {}
	Meta.codex = {}
	Meta.achieved = {}
	Ach.new_run()
	Modes.set_on([])
	Meta.rules = 1
	Meta.map_id = "plain"
	main.run_flow_system._apply_rules()
	Rules.tune["map_on"] = 0.0

func zone_at(points: Array, weights: Array, radius := 22.0) -> Zone:
	var zone := Zone.new()
	zone.kind = "trail"
	zone.sub = "puddle"
	zone.position = Vector2.ZERO
	zone.radius = radius
	zone.pts = PackedVector2Array(points)
	zone.pk = PackedFloat32Array(weights)
	zone.born.resize(points.size())
	zone.life = 3.0
	zone.max_life = 3.0
	zone.level = 2
	zone.dps = 28.0
	zone.src = "lob"
	zone.set_meta("check_id", "zone")
	main.zones.add_child(zone)
	return zone

func orb_at(at: Vector2, index: int, kind := Orb.Kind.NORMAL, wide := false) -> Orb:
	var orb: Orb = WideOrb.new() if wide else Orb.new()
	orb.main = main
	orb.position = at
	orb.target = Vector2(640, 360)
	orb.from_a = 0.0
	orb.setup(kind, 10000.0, 8.0)
	orb.net_id = index + 1
	orb.set_meta("check_id", "orb:%d" % index)
	main.orbs.add_child(orb)
	identity_labels[orb.get_instance_id()] = orb.get_meta("check_id")
	return orb

func make_grid() -> void:
	main.combat_system.targets = main.orbs.get_children().filter(func(orb): return not orb.is_queued_for_deletion())
	main.combat_system._build_grid()

## 후보 1개. key 삽입·구체·point index 순서가 참조와 같다.
func candidate(zone: Zone, mutant := "", count_checks := false) -> Array:
	var out: Array = []
	zone.orb_k.clear()
	last_checks = 0
	if zone.pts.is_empty(): return out
	var g: float = main.GRID
	var pad := zone.radius + 32.0
	var cells := {}
	for i in zone.pts.size():
		var p := zone.pts[i]
		for x in range(floori((p.x - pad) / g), floori((p.x + pad) / g) + 1):
			for y in range(floori((p.y - pad) / g), floori((p.y + pad) / g) + 1):
				var key := Vector2i(x, y)
				if not cells.has(key): cells[key] = []
				cells[key].append(i)
	for key in cells:
		var cell = main.combat_system.grid.get(key)
		if not cell: continue
		for orb in cell:
			if not is_instance_valid(orb) or orb.is_queued_for_deletion(): continue
			var body: float = orb.radius()
			var rr: float = zone.radius + body
			rr *= rr
			var moved: bool = Vector2i(floori(orb.position.x / g), floori(orb.position.y / g)) != key
			var fallback: bool = (moved and mutant != "no_moved_fallback") or (body > 32.0 and mutant != "no_radius_fallback")
			var indices: Array = range(zone.pts.size()) if fallback else cells[key]
			var best := -1.0
			for i in indices:
				if zone.pk[i] > best:
					if count_checks: last_checks += 1
					if orb.position.distance_squared_to(zone.pts[i]) < rr:
						best = zone.pk[i]
						if best >= 1.0: break
			if best >= 0.0:
				out.append(orb)
				zone.orb_k[orb] = best
	return out

## 거리 검사 수 계측만을 위한 참조의 문자 그대로 루프. 결과도 실제 Zone 메서드와 별도 대조한다.
func reference_counted(zone: Zone) -> Array:
	var out: Array = []
	zone.orb_k.clear()
	last_checks = 0
	if zone.pts.is_empty(): return out
	var g: float = main.GRID
	var pad := zone.radius + 32.0
	var cells := {}
	for p in zone.pts:
		for x in range(floori((p.x - pad) / g), floori((p.x + pad) / g) + 1):
			for y in range(floori((p.y - pad) / g), floori((p.y + pad) / g) + 1): cells[Vector2i(x, y)] = true
	for key in cells:
		var cell = main.combat_system.grid.get(key)
		if not cell: continue
		for orb in cell:
			if not is_instance_valid(orb) or orb.is_queued_for_deletion(): continue
			var rr: float = zone.radius + orb.radius()
			rr *= rr
			var best := -1.0
			for i in zone.pts.size():
				if zone.pk[i] > best:
					last_checks += 1
					if orb.position.distance_squared_to(zone.pts[i]) < rr:
						best = zone.pk[i]
						if best >= 1.0: break
			if best >= 0.0:
				out.append(orb)
				zone.orb_k[orb] = best
	return out

func selected(zone: Zone, list: Array) -> Array:
	return list.map(func(orb): return [orb.get_meta("check_id"), zone.orb_k[orb]])

func compare_selection(zone: Zone, name: String) -> void:
	var actual := selected(zone, zone.trail_orbs(main))
	var counted := selected(zone, reference_counted(zone))
	var before_checks := last_checks
	var proposed := selected(zone, candidate(zone, "", true))
	check(actual == counted and actual == proposed, name + ": 순서/id/orb_k exact")
	rows.append({"case":name, "points":zone.pts.size(), "orbs":main.orbs.get_child_count(), "selected":actual, "reference_distance_checks":before_checks, "candidate_distance_checks":last_checks})

func selection_cases() -> void:
	clear_world()
	orb_at(Vector2.ZERO, 0)
	make_grid()
	compare_selection(zone_at([], []), "empty")
	clear_world()
	var zone := zone_at([Vector2.ZERO], [1.0], 22.0)
	for i in 6: orb_at(Vector2(43.0 + (i - 2) * 0.00001, 0), i)
	orb_at(Vector2(-64, -64), 6, Orb.Kind.BOSS)
	make_grid()
	compare_selection(zone, "strict radius boundary")
	clear_world()
	zone = zone_at([Vector2(-64, -64), Vector2.ZERO, Vector2(64, 64)], [0.0, 0.5, 1.0])
	for i in 9: orb_at(Vector2((i % 3 - 1) * 64.0, (i / 3 - 1) * 64.0), i, Orb.Kind.FAST if i % 2 else Orb.Kind.NORMAL)
	make_grid()
	main.orbs.get_child(0).hp = 0.0
	main.orbs.get_child(1).queue_free()
	compare_selection(zone, "negative cells queued and hp0")
	clear_world()
	zone = zone_at([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [1.25, 1.5, 0.5])
	orb_at(Vector2.ZERO, 0)
	make_grid()
	compare_selection(zone, "first pk>=1 wins without sorting")
	check(zone.orb_k[main.orbs.get_child(0)] == 1.25, "early break weight exact")
	zone.pk = PackedFloat32Array([0.5, NAN, 0.25])
	compare_selection(zone, "NaN weight keeps original greater-than semantics")
	zone.add_pt(Vector2(256, 0), 0.75)
	orb_at(Vector2(256, 0), 1)
	make_grid()
	compare_selection(zone, "add_pt current index")
	zone._drop_pts(2)
	compare_selection(zone, "drop_pts current index")
	for n in 32:
		clear_world()
		geom_rng.seed = 9100 + n
		var points: Array = []
		var weights: Array = []
		var count: int = [1, 4, 24, 80][n % 4]
		for i in count:
			points.append(Vector2(geom_rng.randf_range(-200, 1300), geom_rng.randf_range(-200, 900)))
			weights.append([0.0, 0.25, 0.5, 1.0, 1.5][geom_rng.randi() % 5])
		zone = zone_at(points, weights, [4.0, 22.0, 55.0, 90.0][n % 4])
		for i in 32: orb_at(Vector2(geom_rng.randf_range(-200, 1300), geom_rng.randf_range(-200, 900)), i, i % 3)
		make_grid()
		for i in range(0, 32, 5): main.orbs.get_child(i).position += Vector2(130, -65)
		compare_selection(zone, "seed-%d" % (9100 + n))

func mutant_cases() -> void:
	clear_world()
	var zone := zone_at([Vector2.ZERO, Vector2(256, 0)], [0.5, 0.75], 4.0)
	var orb := orb_at(Vector2(1, 1), 0)
	make_grid()
	orb.position = Vector2(256, 0)
	var actual := selected(zone, zone.trail_orbs(main))
	check(actual == selected(zone, candidate(zone)), "stale-grid fallback exact")
	var bad := selected(zone, candidate(zone, "no_moved_fallback"))
	check(actual != bad, "MUTANT RED: stale-grid fallback removal detected")
	if actual != bad: expected_mutant_failures += 1
	clear_world()
	zone = zone_at([Vector2.ZERO, Vector2(128, 0)], [-2.0, 0.5], 20.0)
	orb_at(Vector2.ZERO, 0, Orb.Kind.NORMAL, true)
	make_grid()
	actual = selected(zone, zone.trail_orbs(main))
	check(actual == selected(zone, candidate(zone)), "radius>32 fallback exact")
	bad = selected(zone, candidate(zone, "no_radius_fallback"))
	check(actual != bad, "MUTANT RED: radius fallback removal detected")
	if actual != bad: expected_mutant_failures += 1

func mutant_boundary_run() -> void:
	clear_world()
	var zone: Zone
	if mutant_mode == "no_moved_fallback":
		zone = zone_at([Vector2.ZERO, Vector2(256, 0)], [0.5, 0.75], 4.0)
		var orb := orb_at(Vector2(1, 1), 0)
		make_grid()
		orb.position = Vector2(256, 0)
	else:
		zone = zone_at([Vector2.ZERO, Vector2(128, 0)], [-2.0, 0.5], 20.0)
		orb_at(Vector2.ZERO, 0, Orb.Kind.NORMAL, true)
		make_grid()
	var actual := selected(zone, zone.trail_orbs(main))
	var broken := selected(zone, candidate(zone, mutant_mode))
	rows.append({"mutant":mutant_mode, "reference":actual, "mutant_result":broken})
	check(actual == broken, "intentional mutant must satisfy ordinary equality (expected RED): " + mutant_mode)

func make_affect_fixture(elements: Array, serial: int) -> Zone:
	seed(12000 + serial)
	clear_world()
	case_serial = serial
	var tower := Tower.new()
	tower.main = main
	tower.net_id = 800001
	tower.position = Vector2(320, 300)
	tower.set_meta("check_id", "tower")
	main.towers.add_child(tower)
	identity_labels[tower.get_instance_id()] = "tower"
	tower.set_pattern("lob")
	tower.plv = 3
	for element in elements: tower.add(element, 2)
	tower.mods = {"rapid":3, "reflex":1}
	tower.trigs = {"finish":1, "vanguard":1}
	tower.eff = tower.eff_now()
	var points: Array = []
	var weights: Array = []
	for i in 18:
		points.append(Vector2(210 + i * 30, 260 + (i % 3) * 24))
		weights.append(0.4 if i % 4 == 0 else 1.0)
	var zone := zone_at(points, weights, 46.0)
	zone.owner_tower = tower
	zone.boost = 1.25
	for i in 16:
		var orb := orb_at(Vector2(220 + i * 30, 265 + (i % 3) * 21), i, i % 3)
		orb.hp = 15.0 if i % 7 == 0 else orb.max_hp
		orb.chill = 1.5 if i % 4 == 0 else 0.0
	make_grid()
	main.orbs.get_child(2).position += Vector2(130, 0)
	return zone

func normalize(value: Variant) -> Variant:
	if value is int and identity_labels.has(value): return identity_labels[value]
	if value is Node:
		if not is_instance_valid(value): return "freed-node"
		if value == main: return "main"
		if value.has_meta("check_id"): return value.get_meta("check_id")
		return value.get_class() + ":" + str(value.get_index())
	if value is Callable: return {"callable":value.get_method()}
	if value is Dictionary:
		var entries: Array = []
		for key in value: entries.append([normalize(key), normalize(value[key])])
		return entries
	if value is Array:
		return value.map(normalize)
	if value is Object: return value.get_class() if is_instance_valid(value) else "freed-object"
	return value

func script_state(node: Object) -> Dictionary:
	var result := {}
	if node is Node2D: result["position"] = node.position
	if node is Node: result["queued"] = node.is_queued_for_deletion()
	for property in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and not str(property.name).begins_with("_"):
			result[property.name] = normalize(node.get(property.name))
	return result

func affect_trace(use_candidate: bool, elements: Array, serial: int) -> Dictionary:
	var zone := make_affect_fixture(elements, serial)
	seed(22000 + serial)
	var calls := candidate(zone) if use_candidate else zone.trail_orbs(main)
	var order := selected(zone, calls)
	zone.affect(calls, 1.0 / 120.0)
	# 같은 sim_id의 두 번째 호출은 trail_hit가 중복을 막고 다음 sim에서는 다시 맞힌다.
	var trace: Array = [world_state()]
	zone.affect(candidate(zone) if use_candidate else zone.trail_orbs(main), 1.0 / 120.0)
	trace.append(world_state())
	main.sim_id += 1
	zone.affect(candidate(zone) if use_candidate else zone.trail_orbs(main), 1.0 / 120.0)
	trace.append(world_state())
	for _step in 3:
		for tower in main.towers.get_children(): tower._share_tick(0.9)
		trace.append(world_state())
	var rng_after: Array = []
	for _i in 8: rng_after.append(randi())
	return {"order":order, "trace":trace, "rng_after":rng_after}

func world_state() -> Dictionary:
	var out := {}
	for name in ["towers", "orbs", "zones", "projectiles"]:
		out[name] = main.get(name).get_children().map(script_state)
	for name in ["score", "kills", "wave_dmg", "combo", "combo_t", "combo_bonus", "particles", "popups", "bolts", "pulses"]:
		out[name] = normalize(main.get(name))
	return out

func affect_cases() -> void:
	var suites: Array = [[Elem.FIRE, Elem.ICE, Elem.EARTH], [Elem.WATER, Elem.WIND, Elem.METAL], [Elem.LIGHT, Elem.TIME, Elem.POISON], [Elem.BLOOD, Elem.WOOD, Elem.ILLUSION]]
	for i in suites.size():
		var reference := affect_trace(false, suites[i], i)
		var proposed := affect_trace(true, suites[i], i)
		check(reference.order == proposed.order, "affect suite%d ordered targets/weights" % i)
		check(reference.trace == proposed.trace, "affect suite%d full script states + deferred traces" % i)
		check(reference.rng_after == proposed.rng_after, "affect suite%d subsequent global RNG exact" % i)
		affect_completed += 1
		if output != "":
			FileAccess.open(output.path_join("affect-%d-reference.bin" % i), FileAccess.WRITE).store_buffer(var_to_bytes(reference))
			FileAccess.open(output.path_join("affect-%d-candidate.bin" % i), FileAccess.WRITE).store_buffer(var_to_bytes(proposed))

func benchmark_cases() -> void:
	for distribution in ["short", "long", "bent", "clustered", "moved-fallback"]:
		clear_world()
		var points: Array = []
		var weights: Array = []
		var point_count := 4 if distribution == "short" else 80
		for i in point_count:
			points.append(Vector2(100 + i * 18, 300) if distribution != "clustered" else Vector2(500 + i % 4, 300 + i % 3))
			if distribution == "bent": points[i].y += (i % 9) * 24
			weights.append(0.5 if i % 4 == 0 else 1.0)
		var zone := zone_at(points, weights)
		for i in 300: orb_at(Vector2(80 + i % 30 * 48, 200 + i / 30 * 22), i)
		make_grid()
		if distribution == "moved-fallback":
			for i in range(0, 300, 2): main.orbs.get_child(i).position += Vector2(130, 0)
		compare_selection(zone, "bench correctness " + distribution)
		var reference_us: Array = []
		var candidate_us: Array = []
		for batch in 7:
			# 실행 선후를 교대한다. 준비·결과 검사는 시간에서 제외하며 분포마다 각각 280회 호출한다.
			for which in ([0, 1] if batch % 2 == 0 else [1, 0]):
				var before := Time.get_ticks_usec()
				for _repeat in 40:
					if which == 0: zone.trail_orbs(main)
					else: candidate(zone)
				var elapsed := (Time.get_ticks_usec() - before) / 40.0
				if which == 0: reference_us.append(elapsed)
				else: candidate_us.append(elapsed)
		reference_us.sort()
		candidate_us.sort()
		var row := {"distribution":distribution, "points":point_count, "orbs":300, "calls_per_implementation":280, "reference_us_median":reference_us[3], "candidate_us_median":candidate_us[3], "ratio_candidate_over_reference":candidate_us[3] / reference_us[3], "reference_batch_us":reference_us, "candidate_batch_us":candidate_us}
		rows.append(row)
		print("ZONE BENCH ", JSON.stringify(row))
