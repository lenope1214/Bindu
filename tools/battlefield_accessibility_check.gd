extends "res://tools/carry_check.gd"
## Native accessibility-tree observation handshake. Only isolated BinduTools.
var observations := []
var labels := {}

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2); return
	create_timer(600).timeout.connect(func(): quit(2))
	output = OS.get_cmdline_user_args()[0]
	Tutorial.loaded = true; Tutorial.done = true; Tutorial.play_done = true
	Tutorial.save_file()  # boot reloads this file even when loaded was already true.
	Meta.games = 5; Meta.guide_on = false; Meta.sim_phone = false
	Meta.ui_scale = 1.0
	main = load("res://main.tscn").instantiate()
	# AX observes the real product Window hierarchy, not the GUI-input SubViewport.
	Meta.pause_on_focus_loss = false
	root.unfocusable = true
	root.gui_embed_subwindows = true
	root.add_child(main)
	main.set_process(false)
	await process_frame
	main.set_process(false)
	main.sfx.muted = true
	Meta.games = 5; Meta.guide_on = false
	main.onboarding_system.tut_first = false
	main.tut.close()
	# Observe a visible QA window while keeping it unfocusable.
	await process_frame
	root.mode = Window.MODE_WINDOWED
	await expose("title")
	main.progression_system._hide_title()
	seed(1701)
	await fixture()
	main.bar_open = true
	await expose("choose")
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "action":
		await finish()
		return
	seed(1701)
	await fixture()
	main.interaction_system._select_tower(target)
	await expose("inspector")
	main.card_dock.close_inspector()
	main.cards_system._enter_ready()
	await expose("ready")
	main.phase = main.Phase.WAVE; main.wave_active = true
	main.to_spawn = 1; main.spawn_timer = 100000.0
	await expose("wave")
	main.run_flow_system._toggle_pause()
	await expose("pause")
	main.run_flow_system._toggle_pause()
	main.menu_system._toggle_settings()
	await expose("settings")
	main.menu_system._toggle_settings()
	seed(700)
	main.perks_system._start_perk()
	await expose("perk")
	await finish()

func finish() -> void:
	FileAccess.open(output.path_join("observations.json"), FileAccess.WRITE).store_string(JSON.stringify(observations, "\t"))
	main.queue_free()
	for i in 4: await process_frame
	print("ACCESSIBILITY OBSERVATION states=%d failures=%d" % [observations.size(), fails])
	quit(1 if fails else 0)

func expose(label: String) -> void:
	root.title = "Bindu QA " + label  # Native-window state marker, not complete subtree proof.
	await settle()
	for i in 3: await process_frame
	RenderingServer.force_draw()
	var controls := []
	collect(main, controls)
	ok("BF-50", not main.tut.visible and not paused if label != "pause" else paused, "intended QA state without tutorial overlay: " + label)
	if label == "choose" or label == "perk":
		ok("BF-50", main.choice_box.visible and main.choice_box.get_child_count() > 0, "actual offer surface is visible: " + label)
	var before := {"phase": main.phase, "picks": main.picks_left, "camera": str(main.get_canvas_transform()), "tower_positions": main.towers.get_children().map(func(t): return str(t.position)), "held": held()}
	FileAccess.open(output.path_join(label + "-ready.json"), FileAccess.WRITE).store_string(JSON.stringify({"label": label, "pid": OS.get_process_id(), "supported": AccessibilityServer.is_supported(), "root_visible": root.visible, "root_mode": root.mode, "unfocusable": root.unfocusable, "has_focus": root.has_focus(), "controls": controls, "before": before}, "\t"))
	var deadline := Time.get_ticks_usec() + 60000000
	while not FileAccess.file_exists(output.path_join(label + "-done.json")) and Time.get_ticks_usec() < deadline:
		await create_timer(0.05).timeout
	ok("BF-50", FileAccess.file_exists(output.path_join(label + "-done.json")), "AX host observed " + label)
	for i in 2: await process_frame
	var after := {"phase": main.phase, "picks": main.picks_left, "camera": str(main.get_canvas_transform()), "tower_positions": main.towers.get_children().map(func(t): return str(t.position)), "held": held()}
	observations.append({"label": label, "controls": controls, "before": before, "after": after})
	FileAccess.open(output.path_join(label + "-result.json"), FileAccess.WRITE).store_string(JSON.stringify(observations[-1], "\t"))
	main.get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))

func collect(node: Node, result: Array) -> void:
	if node is BaseButton and node.is_visible_in_tree():
		var text := str(node.get("text")) if "text" in node else ""
		result.append({"path": str(node.get_path()), "class": node.get_class(), "text": text, "name": node.accessibility_name, "description": node.accessibility_description, "tooltip": node.tooltip_text, "disabled": node.disabled, "focus_mode": node.focus_mode, "rect": str(node.get_global_rect()), "custom_draw": node.get_signal_connection_list("draw").size() > 0})
	for child in node.get_children(): collect(child, result)
