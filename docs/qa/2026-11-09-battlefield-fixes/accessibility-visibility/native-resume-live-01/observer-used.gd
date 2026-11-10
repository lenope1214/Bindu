extends "res://tools/ax_visibility_base.gd"
## Discriminate activation order and fixture jumps from a supported action journey.
var journey := ""
var key_trace := []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2); return
	create_timer(180).timeout.connect(func(): quit(2))
	output = OS.get_cmdline_user_args()[0]
	journey = OS.get_cmdline_user_args()[1]
	Tutorial.loaded = true; Tutorial.done = true; Tutorial.play_done = true
	Tutorial.save_file()
	Meta.games = 5; Meta.guide_on = false; Meta.sim_phone = false
	Meta.ui_scale = 1.0; Meta.pause_on_focus_loss = false
	main = load("res://main.tscn").instantiate()
	root.unfocusable = true
	root.gui_embed_subwindows = true
	root.add_child(main)
	if is_resume():
		current_scene = main  # Match normal scene ownership so the real reload action runs.
	main.set_process(false)
	await process_frame
	main.set_process(false)
	main.sfx.muted = true
	main.auto_start = false
	Meta.games = 5; Meta.guide_on = false
	main.onboarding_system.tut_first = false
	main.tut.close()
	main.progression_system._hide_title()
	await process_frame
	root.mode = Window.MODE_WINDOWED
	seed(1701)
	await fixture()
	main.bar_open = true
	main.set_process(journey == "native-resume-live")
	if journey.begins_with("native-"):
		await expose("pick_one")
		ok("BF-50", main.phase == main.Phase.PLACE and main.picks_left == 2, "first actual native element-card press holds card")
		await place_by_keyboard()
		ok("BF-50", main.phase == main.Phase.CHOOSE and main.picks_left == 1, "first virtual GUI placement consumes exactly one pick")
		await expose("pick_two")
		ok("BF-50", main.phase == main.Phase.PLACE and main.picks_left == 1, "second actual native element-card press holds card")
		await place_by_keyboard()
		ok("BF-50", main.phase == main.Phase.READY and main.picks_left == 0, "supported two-pick flow reaches READY without phase assignment")
		if is_resume():
			var saved := state()
			await expose("saved_ready")
			await input_key(KEY_P)
			ok("BF-50", paused and main.pause_box.visible, "actual pause opens leave action")
			await expose("pause")
			await expose("leave")
			ok("BF-50", current_scene == main and main.title_label.visible and not paused, "native start-screen action reloads current scene to title")
			ok("BF-50", main.continue_btn.is_visible_in_tree(), "saved game exposes native continue action")
			await expose("continue")
			ok("BF-50", main.phase == main.Phase.READY and not main.title_label.visible and main.picks_left == 0, "actual native continue restores READY")
			if main.title_label.visible:
				await finish()
				return
			var restored := state()
			ok("BF-50", restored.wave == saved.wave and restored.tower_positions == saved.tower_positions and restored.tower_elements == saved.tower_elements, "native reload and continue preserve wave and tower state")
			if journey == "native-resume-live":
				await finish()
				return
		if journey == "native-close":
			await expose("ready_open")
			await input_key(KEY_ESCAPE)
			ok("BF-50", main.phase == main.Phase.READY and not main.card_dock.side.visible, "actual Esc closes inspector in READY")
			await expose("ready_closed")
			await input_key(KEY_TAB)
			ok("BF-50", main.phase == main.Phase.READY and main.card_dock.side.visible, "actual Tab reopens inspector in READY")
	else:
		if journey == "choose-ready":
			await expose("visible")
		if journey == "ready-with-key":
			await input_key(KEY_F17)
		# Explicit boundary probe, not a supported-action proof.
		main.picks_left = 0
		main.cards_system._enter_ready()
		if journey == "ready-with-inspector":
			await input_key(KEY_TAB)
	await expose("ready")
	var method := "native_AXPress" if main.phase == main.Phase.WAVE else "virtual_space_fallback"
	if main.phase == main.Phase.READY:
		await input_key(KEY_SPACE)
	ok("BF-50", main.phase == main.Phase.WAVE and main.wave_active, "actual start action enters WAVE")
	FileAccess.open(output.path_join("start-method.json"), FileAccess.WRITE).store_string(JSON.stringify({"method":method, "state":state(), "keys":key_trace}, "\t"))
	await expose("wave")
	await finish()

func is_resume() -> bool:
	return journey in ["native-resume", "native-resume-live"]

func settle() -> void:
	if journey == "native-resume-live":
		for i in 4: await process_frame
	else:
		await super.settle()

func state() -> Dictionary:
	if is_resume() and is_instance_valid(current_scene) and (not is_instance_valid(main) or main != current_scene):
		main = current_scene
		main.set_process(journey == "native-resume-live")
		main.sfx.muted = true
		Meta.guide_on = false
	var result := super.state()
	var focused: Control = main.get_viewport().gui_get_focus_owner()
	result["gui_focus"] = str(focused.get_path()) if focused != null else ""
	result["inspector_visible"] = main.card_dock.side.is_visible_in_tree()
	result["selected"] = main.interaction_system.selected.map(func(t): return str(t.position))
	result["picked"] = main.picked.duplicate(true)
	result["title_visible"] = main.title_label.visible
	result["session_id"] = str(main.get_instance_id())
	result["current_scene_is_main"] = current_scene == main
	result["game_process_enabled"] = main.is_processing()
	result["manual_settle"] = journey != "native-resume-live"
	result["run_real"] = main.run_real
	result["process_frame"] = Engine.get_process_frames()
	result["tower_elements"] = main.towers.get_children().map(func(t): return t.elements.duplicate())
	result["window_model"] = {"size":str(root.size), "position":str(root.position),
		"content_scale_size":str(root.content_scale_size), "content_scale_factor":root.content_scale_factor,
		"final_transform":str(root.get_final_transform()), "screen_transform":str(root.get_screen_transform()),
		"ui_root_rect":str(main.ui_root.get_global_rect()), "ui_root_clip":main.ui_root.clip_contents}
	var ancestors := []
	var node: Node = main.start_btn
	while node != null:
		var row := {"path":str(node.get_path()), "class":node.get_class()}
		if node is CanvasItem:
			row["visible"] = node.visible
			row["visible_in_tree"] = node.is_visible_in_tree()
			row["transform"] = str(node.get_transform())
		if node is Control:
			row["rect"] = str(node.get_global_rect())
			row["clip"] = node.clip_contents
			row["focus_override"] = node.get_focus_mode_with_override()
		ancestors.append(row)
		node = node.get_parent()
	result["start_ancestors"] = ancestors
	return result

func card_action_name() -> String:
	if is_resume():
		if paused:
			return "시작 화면"
		if main.title_label.visible:
			return main.continue_btn.accessibility_name
	for i in main.offer.size():
		if main.offer[i].get("type") == "elem":
			return main.choice_box.get_child(i).accessibility_name
	return ""

func place_by_keyboard() -> void:
	await input_key(KEY_ENTER)
	if main.phase == main.Phase.AIM:
		await input_key(KEY_ENTER)

func input_key(code: int) -> void:
	var before := state()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		VirtualInput.send(event)
	await settle()
	key_trace.append({"code":OS.get_keycode_string(code), "before":before, "after":state()})
