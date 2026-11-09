extends "res://tools/battlefield_input_service_check.gd"
## Rendering follow-up only. Two complete engine frames, not first display latency.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(60).timeout.connect(func(): quit(2))
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
	observer = ServiceObserver.new()
	observer.harness = self
	observer.process_mode = Node.PROCESS_MODE_PAUSABLE
	VirtualInput.viewport.add_child(observer)
	orb_goal = 400
	await prepare_case(false)
	await process_frame
	event_seen = {}
	post_times = {}
	active_probe = "pause"
	var before := qa_snapshot()
	var before_rng := randi()
	var worker := Thread.new()
	var start := Time.get_ticks_usec()
	worker.start(post_buffered.bind(KEY_P))
	main.frame_system._process(1.0 / 60.0)
	var compute_end := Time.get_ticks_usec()
	worker.wait_to_finish()
	var deadline := Time.get_ticks_usec() + 2000000
	while event_seen.is_empty() and Time.get_ticks_usec() < deadline:
		await process_frame
	ok("BF-49", paused and main.pause_box.is_visible_in_tree(), "pause state and scene visibility before render follow-up")
	var stopped_id: int = main.sim_id
	var stopped_game: float = main.run_game
	RenderingServer.force_draw()
	var immediate_draw := Time.get_ticks_usec()
	main.get_viewport().get_texture().get_image().save_png(output.path_join("immediate.png"))
	main.frame_system._process(0.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var after_frames := Time.get_ticks_usec()
	main.get_viewport().get_texture().get_image().save_png(output.path_join("after-two-engine-frames.png"))
	ok("BF-49", main.sim_id == stopped_id and main.run_game == stopped_game, "render follow-up does not simulate while paused")
	var data := {"start_us": start, "compute_end_us": compute_end, "post": post_times, "event": event_seen, "pre_state": before, "pre_next_rng": before_rng, "immediate_force_draw_return_us": immediate_draw, "after_two_engine_frames_force_draw_return_us": after_frames, "stopped_sim_id": stopped_id, "stopped_game": stopped_game, "pause_label_visible": main.paused_label.is_visible_in_tree(), "pause_menu_visible": main.pause_box.is_visible_in_tree(), "failures": fails, "ui": ui_errors, "scope": "Manual fixed frame then paused layout and two real process_frame boundaries. Capture proof only; no exact first-visible-frame or physical presentation claim."}
	FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE).store_string(JSON.stringify(data, "\t"))
	print("INPUT RENDER failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails else 0)
