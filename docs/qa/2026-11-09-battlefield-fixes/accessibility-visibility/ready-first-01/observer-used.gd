extends "res://tools/ax_visibility_base.gd"
## Discriminate activation order and fixture jumps from a supported action journey.
var journey := ""
var key_trace := []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2); return
	create_timer(120).timeout.connect(func(): quit(2))
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
	if journey == "native-journey":
		await expose("pick_one")
		ok("BF-50", main.phase == main.Phase.PLACE and main.picks_left == 2, "first actual native element-card press holds card")
		await place_by_keyboard()
		ok("BF-50", main.phase == main.Phase.CHOOSE and main.picks_left == 1, "first virtual GUI placement consumes exactly one pick")
		await expose("pick_two")
		ok("BF-50", main.phase == main.Phase.PLACE and main.picks_left == 1, "second actual native element-card press holds card")
		await place_by_keyboard()
		ok("BF-50", main.phase == main.Phase.READY and main.picks_left == 0, "supported two-pick flow reaches READY without phase assignment")
	else:
		if journey == "choose-ready":
			await expose("visible")
		# Explicit boundary probe, not a supported-action proof.
		main.picks_left = 0
		main.cards_system._enter_ready()
	await expose("ready")
	var method := "native_AXPress" if main.phase == main.Phase.WAVE else "virtual_space_fallback"
	if main.phase == main.Phase.READY:
		await input_key(KEY_SPACE)
	ok("BF-50", main.phase == main.Phase.WAVE and main.wave_active, "actual start action enters WAVE")
	FileAccess.open(output.path_join("start-method.json"), FileAccess.WRITE).store_string(JSON.stringify({"method":method, "state":state(), "keys":key_trace}, "\t"))
	await expose("wave")
	await finish()

func card_action_name() -> String:
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
