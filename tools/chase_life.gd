extends SceneTree
# 유도·혼불 탄이 얼마나 오래 사는지: 강화 조합마다 탄 하나가 산 시간(초)·간 거리 최댓값.
# 사용: godot --headless --fixed-fps 60 --path . -s tools/chase_life.gd   (RULES=1|3, SECS 기본 20, OSPD 구체 속도 기본 90)
var main


func _initialize():
	Meta.map_id = "spiral"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	Meta.rules = int(OS.get_environment("RULES")) if OS.get_environment("RULES") != "" else 1
	Meta.map_id = "spiral"
	main._apply_rules()
	var secs := float(OS.get_environment("SECS")) if OS.get_environment("SECS") != "" else 20.0
	var ospd := float(OS.get_environment("OSPD")) if OS.get_environment("OSPD") != "" else 90.0
	var combos := [{}, {"homing": 3}, {"bounce": 3}, {"pierce": 3}, {"split": 3}, {"multi": 3},
		{"homing": 3, "bounce": 3}, {"homing": 3, "pierce": 3}, {"homing": 3, "bounce": 3, "pierce": 3},
		{"homing": 3, "bounce": 3, "pierce": 3, "split": 3, "multi": 3}, {"homing": 3, "bounce": 3, "size": 3, "rapid": 3}]
	var pats := OS.get_environment("PATS").split(",") if OS.get_environment("PATS") != "" else PackedStringArray(["shot", "wisp", "thorn", "iron", "shard"])
	for pat in pats:
		for md in combos:
			var r = await _run(pat, md, secs, ospd)
			print("LIFE rules=%d ospd=%d pat=%s mods=%s n=%d max_t=%.1f avg_t=%.2f max_travel=%.0f over10s=%d" % [Meta.rules, ospd, pat, str(md), r[0], r[1], r[2], r[3], r[4]])
	quit()


func _run(pat: String, md: Dictionary, secs: float, ospd: float) -> Array:
	seed(7)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for c in main.towers.get_children(): c.free()
	for c in main.orbs.get_children(): c.free()
	for c in main.zones.get_children(): c.free()
	for c in main.projectiles.get_children(): c.free()
	main.wave = 20; main.phase = main.Phase.WAVE; main.wave_active = true; main.wave_time = 10.0; main.to_spawn = 0
	var c = main.center()
	var ld := Vector2.UP
	main.picked = {"e": Elem.SOUL, "lv": 3}
	main._place_tower(c + ld * 100.0, ld)
	var t = main.towers.get_child(0)
	if pat != "shot":
		t.set_pattern(pat)
	for k in md:
		for i in md[k]:
			t.add_mod(k)
	var born := {}
	var lives := []
	var maxtr := 0.0
	var spawn_t := 0.0
	var frames := int(60 * secs)
	for f in frames:
		main.phase = main.Phase.WAVE; main.wave_active = true; main.core_hp = 99999
		spawn_t -= 1.0 / 60
		if spawn_t <= 0:
			spawn_t = 0.5
			var o = Orb.new(); o.main = main
			var a := rng.randf_range(0, TAU)
			o.position = c + Vector2.from_angle(a) * main._spawn_radius()
			o.from_a = a; o.target = c; o.swirl = main.SPIRAL_SWIRL
			o.setup(Orb.Kind.NORMAL, 1000000, ospd)
			main.orbs.add_child(o)
		await process_frame
		var alive := {}
		for p in main.projectiles.get_children():
			if p.is_queued_for_deletion() or p.kind == "frag": continue
			var id = p.get_instance_id()
			alive[id] = true
			if not born.has(id): born[id] = f
			maxtr = maxf(maxtr, p.travel)
		for id in born.keys():
			if not alive.has(id):
				lives.append((f - born[id]) / 60.0)
				born.erase(id)
		for o in main.orbs.get_children():
			if not o.is_queued_for_deletion() and o.position.distance_to(c) < 45.0:
				o.queue_free()
	for id in born: lives.append((frames - born[id]) / 60.0)
	var mx := 0.0; var sum := 0.0; var over := 0
	for l in lives:
		mx = maxf(mx, l); sum += l
		if l > 10.0: over += 1
	return [lives.size(), mx, sum / maxf(lives.size(), 1), maxtr, over]
