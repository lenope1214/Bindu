extends "res://tools/battlefield_targeting_check.gd"
## Existing target/RNG matrix against a range-invariant candidate; product Tower stays unchanged.

func candidate(tower: Tower, orbs: Array) -> Orb:
	if orbs.is_empty():
		return null
	if orbs.size() == 1:
		var only = orbs[0]
		if not is_instance_valid(only) or only.hp <= 0.0:
			return null
		var toward: Vector2 = only.position - tower.position
		if toward.length() > tower.reflex_range(toward):
			return null
		var goal := tower.goal_dist(only)
		return only if not (goal > goal + Rules.t("aim_band")) else null
	var closest: Orb = null
	var closest_g := INF
	var preferred: Orb = null
	var preferred_g := INF
	var aim_pref := Rules.t("aim_pref")
	var range_ready := false
	var fixed_range := 0.0
	var directional_range := false
	var goal_ready := false
	var goal_center := Vector2.ZERO
	var line_goal := false
	for orb in orbs:
		if not is_instance_valid(orb) or orb.hp <= 0.0:
			continue
		var v: Vector2 = orb.position - tower.position
		if not range_ready:
			var far_guard: bool = Rules.t("auto_aim") > 0.0 and tower.pattern in Tower.FAR_PATS
			directional_range = not far_guard and tower.main != null and MapRule.is_map("storm") and (tower.pattern in ["shot", "gust", "lob"] or (tower.pattern in Pat.PROJECTILE and tower.mf("homing") > 0.0))
			if not directional_range:
				fixed_range = tower.reflex_range(v)
			range_ready = true
		if v.length() > (tower.reflex_range(v) if directional_range else fixed_range):
			continue
		if not goal_ready:
			line_goal = tower.main != null and Meta.map_id == "line"
			goal_center = tower.position if tower.main == null else (tower.main.viewport_system.core() if line_goal else tower.main.viewport_system.center())
			goal_ready = true
		var distance: float = absf(orb.position.x - goal_center.x) if line_goal else orb.position.distance_to(goal_center)
		if closest == null or distance < closest_g:
			closest = orb
			closest_g = distance
		if aim_pref > 0.0 and absf(tower.dir.angle_to(v)) <= aim_pref and (preferred == null or distance < preferred_g):
			preferred = orb
			preferred_g = distance
	var limit := closest_g + Rules.t("aim_band")
	if preferred != null and not (preferred_g > limit):
		return preferred
	return closest if closest != null and not (closest_g > limit) else null

func compare(tower: Tower, candidates: Array, label: String) -> void:
	note_case(tower)
	comparisons += 1
	seed(12345)
	var expected_rng := randi()
	seed(12345)
	var reference := tower._guard_pick(candidates)
	var reference_rng := randi()
	seed(12345)
	var proposed := candidate(tower, candidates)
	var candidate_rng := randi()
	if proposed != reference or reference_rng != expected_rng or candidate_rng != expected_rng:
		mismatch_count += 1
		if mismatches.size() < 30:
			mismatches.append({"case":label, "expected":reference.get_instance_id() if reference != null else 0, "actual":proposed.get_instance_id() if proposed != null else 0, "rng_preserved":reference_rng == expected_rng and candidate_rng == expected_rng})

func run_benchmark(tower: Tower) -> void:
	Rules.tune["map_on"] = 1.0
	Rules.tune["aim_pref"] = 0.6
	Rules.tune["aim_band"] = 40.0
	tower.position = main.viewport_system.center() + Vector2(180, 60)
	tower.set_attack_direction(Vector2.LEFT)
	var all_candidates: Array = []
	for i in 300:
		all_candidates.append(_orb(Vector2(90 + (i % 25) * 44, 105 + floori(i / 25.0) * 43), 100.0))
	for map_id in ["plain", "line", "storm"]:
		Meta.map_id = map_id
		for pattern in ["shot", "spray", "wall", "iron"]:
			configure_pattern(tower, pattern)
			for count in [0, 1, 300]:
				var candidates := all_candidates.slice(0, count)
				Rules.tune["auto_aim"] = 1.0
				if map_id == "storm" and pattern == "shot": Rules.tune["auto_aim"] = 0.0
				for _warmup in 20:
					tower._guard_pick(candidates)
					candidate(tower, candidates)
				var before_ms: Array = []
				var after_ms: Array = []
				for batch in 7:
					for which in ([0, 1] if batch % 2 == 0 else [1, 0]):
						var before := Time.get_ticks_usec()
						for _repeat in 40:
							if which == 0: tower._guard_pick(candidates)
							else: candidate(tower, candidates)
						var elapsed := (Time.get_ticks_usec() - before) / 1000.0 / 40.0
						(before_ms if which == 0 else after_ms).append(elapsed)
				var a := before_ms.duplicate()
				var b := after_ms.duplicate()
				a.sort()
				b.sort()
				benchmark.append({"pattern":"%s/%s/%d" % [map_id, pattern, count], "orbs":count, "calls_per_batch":40, "batches":7, "reference_ms_per_call":before_ms, "actual_ms_per_call":after_ms, "reference_median_ms":a[3], "actual_median_ms":b[3], "scope":"current product vs candidate in test tool; headless CPU, not native frame/FPS"})
