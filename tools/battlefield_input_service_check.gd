extends "res://tools/battlefield_load_check.gd"
## Isolated experiment: thread-buffered synthetic events, not UIKit/OS latency.
const TAG := 0xB1D0
var observer: ServiceObserver
var post_mutex := Mutex.new()
var post_times := {}
var active_probe := ""
var event_seen := {}
var rows := []
var no_input := []

class ServiceObserver extends Node:
	var harness
	func _input(event: InputEvent) -> void:
		if event.device != TAG or not event is InputEventKey or not event.pressed:
			return
		harness.event_seen["dispatch_us"] = Time.get_ticks_usec()
		harness.event_seen["dispatch_sim_id"] = harness.main.sim_id
		if harness.active_probe == "reentrant":
			var before: int = harness.main.sim_id
			harness.main.frame_system._process(1.0 / 60.0)
			harness.event_seen["reentrant_extra_steps"] = harness.main.sim_id - before
		elif harness.active_probe == "free":
			harness.main.free()
			harness.event_seen["freed_us"] = Time.get_ticks_usec()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PAUSED and harness != null and harness.active_probe == "pause":
			harness.event_seen["paused_us"] = Time.get_ticks_usec()

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(240).timeout.connect(func(): quit(2))
	output = OS.get_cmdline_user_args()[0]
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 10
	Meta.guide_on = false
	Meta.sim_phone = false
	Meta.skill_auto = false
	Meta.skill_aim_slow = false
	Meta.ui_scale = 1.3
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await make_session()
	orb_goal = 400
	observer = ServiceObserver.new()
	observer.harness = self
	observer.process_mode = Node.PROCESS_MODE_PAUSABLE
	VirtualInput.viewport.add_child(observer)
	await create_timer(0.2).timeout
	for reduced in [false, true]:
		await measure_no_input(reduced)
	for trial in 3:
		await measure_probe("pause", KEY_P, trial)
	for pair in [["settings", KEY_O], ["speed", KEY_SPACE], ["reentrant", KEY_F10], ["free", KEY_F9]]:
		await measure_probe(pair[0], pair[1], 0)
	var result := {"engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(), "fixed_delta": 1.0 / 60.0, "render_drive": "force_draw return, not physical presentation", "queue_source": "Thread parses fresh tagged Key press/release into Input buffer after5ms; no OS/UI event injection", "no_input": no_input, "probes": rows, "failures": fails, "ui": ui_errors}
	FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("INPUT SERVICE conditions=%d probes=%d failures=%d ui=%d" % [no_input.size(), rows.size(), fails, ui_errors])
	quit(1 if fails else 0)

func make_session() -> void:
	if is_instance_valid(main):
		main.free()
	await process_frame
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	Input.use_accumulated_input = true
	main.set_process(false)
	main.sfx.muted = true
	await process_frame
	main.progression_system._hide_title()
	main.auto_start = false
	main.hud_system._apply_ui_scale()
	main.pause_box.visibility_changed.connect(func():
		if active_probe == "pause" and is_instance_valid(main) and main.pause_box.visible:
			event_seen["menu_us"] = Time.get_ticks_usec())
	main.settings_panel.visibility_changed.connect(func():
		if active_probe == "settings" and is_instance_valid(main) and main.settings_panel.visible:
			event_seen["settings_us"] = Time.get_ticks_usec())

func prepare_case(reduced: bool) -> void:
	await make_session()
	await load_fixture()
	main.sim_id = 0
	main.game_speed = 8.0
	Meta.fx_low = reduced
	for i in 30:
		await process_frame
		main.frame_system._process(1.0 / 60.0)
		fill_orbs()
		RenderingServer.force_draw()

func measure_no_input(reduced: bool) -> void:
	await prepare_case(reduced)
	var begin_id: int = main.sim_id
	var begin_game: float = main.run_game
	var samples := []
	var counts := []
	var traces := []
	for i in 30:
		await process_frame
		var start := Time.get_ticks_usec()
		main.frame_system._process(1.0 / 60.0)
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		fill_orbs()
		RenderingServer.force_draw()
		counts.append([main.live_orbs.size(), main.projectiles.get_child_count(), main.zones.get_child_count()])
		if i % 10 == 9:
			traces.append(qa_snapshot())
	var row := {"fx_low": reduced, "main_cpu_ms": stats(samples), "raw_main_cpu_ms": samples, "population": counts, "traces": traces, "next_rng": randi(), "steps": main.sim_id - begin_id, "game_seconds": main.run_game - begin_game}
	ok("BF-49", row.steps == 240 and is_equal_approx(row.game_seconds, 4.0), "no-input requested8speed game time and step count")
	no_input.append(row)
	print("NO INPUT reduced=", reduced, " cpu=", row.main_cpu_ms.mean)

func post_buffered(code: int) -> void:
	OS.delay_msec(5)
	post_mutex.lock()
	post_times["before_parse_us"] = Time.get_ticks_usec()
	post_mutex.unlock()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.device = TAG
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	post_mutex.lock()
	post_times["after_parse_us"] = Time.get_ticks_usec()
	post_mutex.unlock()

func measure_probe(label: String, code: int, trial: int) -> void:
	await prepare_case(false)
	await process_frame
	event_seen = {}
	post_times = {}
	active_probe = label
	var begin_id: int = main.sim_id
	var begin_game: float = main.run_game
	var camera: Transform2D = main.get_canvas_transform()
	var picks: int = main.picks_left
	var before := qa_snapshot()
	var before_rng := randi()
	var worker := Thread.new()
	var start := Time.get_ticks_usec()
	worker.start(post_buffered.bind(code))
	main.frame_system._process(1.0 / 60.0)
	var compute_end := Time.get_ticks_usec()
	var at_return := {"session_valid": is_instance_valid(main), "paused": paused}
	if is_instance_valid(main):
		at_return.merge({"steps": main.sim_id - begin_id, "game_seconds": main.run_game - begin_game, "settings_visible": main.settings_panel.visible, "menu_visible": main.pause_box.visible, "speed": main.game_speed})
	worker.wait_to_finish()
	var deadline := Time.get_ticks_usec() + 2000000
	while event_seen.is_empty() and Time.get_ticks_usec() < deadline:
		await process_frame
	ok("BF-49", not event_seen.is_empty(), "buffered request dispatch: " + label)
	post_mutex.lock()
	var posted := post_times.duplicate()
	post_mutex.unlock()
	var row := {"label": label, "trial": trial, "start_us": start, "compute_end_us": compute_end, "post": posted, "event": event_seen.duplicate(), "at_compute_return": at_return, "pre_state": before, "pre_next_rng": before_rng}
	row["posted_during_compute"] = posted.before_parse_us >= start and posted.after_parse_us < compute_end
	if event_seen.has("dispatch_us"):
		row["queue_to_dispatch_ms"] = (event_seen.dispatch_us - posted.before_parse_us) / 1000.0
	if is_instance_valid(main):
		row["camera_preserved"] = main.get_canvas_transform().is_equal_approx(camera)
		row["picks_preserved"] = main.picks_left == picks
		ok("BF-49", row.camera_preserved and row.picks_preserved, "camera and picks preserved: " + label)
		if label == "pause":
			ok("BF-49", paused and main.pause_box.visible, "paused and menu visible")
			row["raw_pause_label_rect"] = str(main.paused_label.get_global_rect())
			row["raw_pause_box_rect"] = str(main.pause_box.get_global_rect())
			row["raw_menu_inside_viewport"] = main.get_viewport_rect().encloses(main.pause_box.get_global_rect())
			row["raw_pause_label_inside_viewport"] = main.get_viewport_rect().encloses(main.paused_label.get_global_rect())
			row["raw_label_menu_overlap"] = main.paused_label.get_global_rect().intersects(main.pause_box.get_global_rect())
			RenderingServer.force_draw()
			row["raw_force_draw_return_us"] = Time.get_ticks_usec()
			main.get_viewport().get_texture().get_image().save_png(output.path_join("raw-pause-%d.png" % trial))
			# Explicitly layout the paused UI, then measure a forced draw. This is NOT first-frame OS latency.
			main.frame_system._process(0.0)
			RenderingServer.force_draw()
			row["after_explicit_paused_layout_draw_us"] = Time.get_ticks_usec()
			main.get_viewport().get_texture().get_image().save_png(output.path_join("pause-%d.png" % trial))
			main.run_flow_system._toggle_pause()
			var resume_id: int = main.sim_id
			var resume_game: float = main.run_game
			main.frame_system._process(1.0 / 60.0)
			row["resume_steps"] = main.sim_id - resume_id
			row["resume_game_seconds"] = main.run_game - resume_game
			ok("BF-49", row.resume_steps == 8 and is_equal_approx(row.resume_game_seconds, 8.0 / 60.0), "resume has one requested batch, no catch-up debt")
		elif label == "settings":
			ok("BF-49", main.settings_panel.visible, "settings is visible")
			main.menu_system._toggle_settings()
		elif label == "speed":
			ok("BF-49", main.game_speed != 8.0, "speed key accepted")
	else:
		ok("BF-49", label == "free", "only teardown probe may free session")
		await process_frame
		await process_frame
	rows.append(row)
	active_probe = ""
	Input.flush_buffered_events()
	print("PROBE ", label, " ", trial, " return=", JSON.stringify(at_return), " queued=", row.get("queue_to_dispatch_ms", -1.0))

func qa_snapshot() -> Dictionary:
	var extra := []
	for t: Tower in main.towers.get_children():
		var timers := []
		for item in t.later:
			timers.append(qa_normalize(item[0]))
		extra.append([timers, qa_normalize(t.mirror_cd), qa_normalize(t.mirror_t), qa_normalize(t.mirror_f), t.mirror_src.get_index() if is_instance_valid(t.mirror_src) else -1])
	return {"layers": qa_state(main), "tower_extra": extra, "sim_id": main.sim_id, "run_game": qa_normalize(main.run_game), "wave_time": qa_normalize(main.wave_time)}

func qa_state(w: BinduSession) -> Array:
	var result := []
	for layer in [w.towers, w.orbs, w.projectiles, w.zones]:
		var values := []
		for n in layer.get_children():
			if n.is_queued_for_deletion(): continue
			var keys: Array
			if n is Tower: keys = ["position", "dealt", "rx_dealt", "src", "charge", "third_n", "star_sum", "side_n", "side_cd"]
			elif n is Orb: keys = ["position", "hp", "burn_t", "poison_t", "slow_timer", "slow_factor", "root_timer", "frozen_t", "vuln_t", "vine", "chill", "echo_t", "echo_amt", "bleed_t", "confuse_t"]
			elif n is Projectile: keys = ["kind", "position", "vel", "dmg", "radius", "t", "travel", "pierce_left", "bounces"]
			else: keys = ["kind", "position", "life", "radius", "hp", "store", "pts"]
			var row := []
			for key in keys: row.append(qa_normalize(n.get(key)))
			values.append(row)
		result.append(values)
	return result

func qa_normalize(value):
	if value is float: return snappedf(value, 0.00001)
	if value is Vector2: return [snappedf(value.x, 0.00001), snappedf(value.y, 0.00001)]
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = qa_normalize(value[key])
		return result
	if value is Array or value is PackedVector2Array:
		var result := []
		for item in value: result.append(qa_normalize(item))
		return result
	return value
