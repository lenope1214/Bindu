extends "res://tools/carry_check.gd"
## Real Window and native AX handshake; no virtual input or OS activation.
var observations := []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2); return
	create_timer(150).timeout.connect(func(): quit(2))
	output = OS.get_cmdline_user_args()[0]
	Tutorial.loaded = true; Tutorial.done = true; Tutorial.play_done = true
	Tutorial.save_file()
	Meta.games = 5; Meta.guide_on = false; Meta.sim_phone = false
	Meta.ui_scale = 1.0; Meta.pause_on_focus_loss = false
	main = load("res://main.tscn").instantiate()
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
	main.progression_system._hide_title()
	await process_frame
	root.mode = Window.MODE_WINDOWED
	seed(1701)
	await fixture()
	main.bar_open = true
	await expose("visible")
	main.cards_system._set_cards_hidden(true)
	await expose("hidden")
	seed(1701)
	await fixture()
	await expose("shown")
	seed(1701)
	await fixture()
	await expose("visible_again")
	main.cards_system._set_cards_hidden(true)
	await expose("hidden_again")
	seed(1701)
	await fixture()
	main.cards_system._enter_ready()
	await expose("ready")
	main.phase = main.Phase.WAVE; main.wave_active = true
	main.start_btn.visible = false
	main.to_spawn = 1; main.spawn_timer = 100000.0
	await expose("wave")
	FileAccess.open(output.path_join("observations.json"), FileAccess.WRITE).store_string(JSON.stringify(observations, "\t"))
	main.queue_free()
	for i in 4: await process_frame
	print("AX VISIBILITY states=%d failures=%d" % [observations.size(), fails])
	quit(1 if fails else 0)

func state() -> Dictionary:
	return {"phase":main.phase, "picks":main.picks_left, "cards_hidden":main.cards_hidden,
		"choice_visible":main.choice_box.is_visible_in_tree(), "held":held(),
		"reroll_visible":main.reroll_btn.is_visible_in_tree(), "start_visible":main.start_btn.is_visible_in_tree(),
		"camera":str(main.get_canvas_transform()),
		"tower_positions":main.towers.get_children().map(func(t): return str(t.position)),
		"offer":main.offer.duplicate(true), "focus":root.has_focus()}

func expose(label: String) -> void:
	root.title = "Bindu QA " + label
	await settle()
	for i in 3: await process_frame
	RenderingServer.force_draw()
	var controls := []
	collect(main, controls)
	var card_name := str(main.choice_box.get_child(0).accessibility_name) if main.choice_box.get_child_count() > 0 else ""
	var before := state()
	FileAccess.open(output.path_join(label + "-ready.json"), FileAccess.WRITE).store_string(JSON.stringify({"label":label, "pid":OS.get_process_id(), "supported":AccessibilityServer.is_supported(), "card_name":card_name, "controls":controls, "before":before}, "\t"))
	var deadline := Time.get_ticks_usec() + 30000000
	while not FileAccess.file_exists(output.path_join(label + "-done.json")) and Time.get_ticks_usec() < deadline:
		await create_timer(0.05).timeout
	ok("BF-50", FileAccess.file_exists(output.path_join(label + "-done.json")), "native AX observed " + label)
	for i in 3: await process_frame
	var after := state()
	observations.append({"label":label, "before":before, "after":after, "controls":controls})
	FileAccess.open(output.path_join(label + "-result.json"), FileAccess.WRITE).store_string(JSON.stringify(observations[-1], "\t"))
	main.get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))

func collect(node: Node, result: Array) -> void:
	if node is BaseButton:
		result.append({"path":str(node.get_path()), "class":node.get_class(), "text":str(node.get("text")) if "text" in node else "",
			"name":node.accessibility_name, "visible":node.visible, "visible_in_tree":node.is_visible_in_tree(),
			"disabled":node.disabled, "focus_mode":node.focus_mode, "rect":str(node.get_global_rect())})
	for child in node.get_children(): collect(child, result)
