extends SceneTree
## Fixed-seed CPU-only fixture usable before/after the feature boundary change.
## Run isolated; real-clock sound guards can still vary damage. No OS input or rendering claim.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"):
		quit(2)
		return
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	seed(7)  # _ready intentionally randomizes; fix RNG after startup for both revisions.
	Meta.map_id = "plain"
	Modes.set_on([])
	Rules.apply(1)
	for layer in [scene.towers, scene.orbs, scene.projectiles, scene.zones]:
		for child in layer.get_children(): child.free()
	var place: Callable = scene._place_tower if scene.has_method("_place_tower") else scene.interaction_system._place_tower
	var step: Callable = scene._sim_step if scene.has_method("_sim_step") else scene.combat_system._sim_step
	for i in 12:
		scene.picked = {"type": "elem", "e": Elem.ALL[i], "lv": 2}
		var angle := TAU * i / 12.0
		place.call(Vector2(640, 360) + Vector2.from_angle(angle) * 170, Vector2.from_angle(angle))
	for i in 200:
		var orb := Orb.new()
		orb.main = scene
		orb.position = Vector2(80 + i % 20 * 56, 140 + i / 20 * 44)
		orb.target = Vector2(640, 360)
		orb.setup(Orb.Kind.NORMAL, 1e9, 0.0)
		scene.orbs.add_child(orb)
	scene.phase = scene.Phase.WAVE
	scene.wave_active = true
	scene.to_spawn = 0
	scene.core_hp = 1000000000
	for i in 60: step.call(1.0 / 60.0)
	var times: Array[float] = []
	for i in 240:
		var start := Time.get_ticks_usec()
		step.call(1.0 / 60.0)
		times.append((Time.get_ticks_usec() - start) / 1000.0)
	var total := 0.0
	for value in times: total += value
	times.sort()
	var damage := 0.0
	for tower in scene.towers.get_children(): damage += tower.dealt
	print("ARCHPERF mean_ms=%.3f p95_ms=%.3f damage=%.6f orbs=%d" % [total / times.size(), times[228], damage, scene.orbs.get_child_count()])
	scene.free()
	quit()
