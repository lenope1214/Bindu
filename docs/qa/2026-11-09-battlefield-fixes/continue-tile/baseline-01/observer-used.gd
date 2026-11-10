extends SceneTree
## Native layout measurement; normal main processing, isolated full save and virtual Enter.
var main
var output := ""
var profile := ""
var rows := []
var checks := []
var layout_failures := 0
var protocol_failures := 0

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2); return
	create_timer(180).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]; profile = args[1]
	Meta.sim_phone = args[2] == "phone"
	Meta.sim_safe = Rect2(86, 0, 86, 38) if Meta.sim_phone else Rect2()
	Meta.ui_scale = float(args[3]); Meta.pause_on_focus_loss = false
	Tutorial.loaded = true; Tutorial.done = true; Tutorial.play_done = true
	Tutorial.save_file()
	Meta.games = 5; Meta.guide_on = false; Meta.tutor_next = false
	root.unfocusable = true
	root.gui_embed_subwindows = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.sfx.muted = true
	Meta.games = 5; Meta.guide_on = false; Meta.tutor_next = false
	Meta.ui_scale = float(args[3]); Meta.pause_on_focus_loss = false
	main.hud_system._apply_ui_scale()
	root.mode = Window.MODE_WINDOWED
	await settle()
	if not check(main.title_label.visible and not main.continue_btn.visible, "fresh save has title and no continue"):
		await finish(); return
	await enter()
	if not check(main.prep and main.title_label.visible, "actual Enter opens preparation"):
		await finish(); return
	await enter()
	if not check(not main.title_label.visible and main.phase == main.Phase.CHOOSE and FileAccess.file_exists(BinduSession.RUN_PATH), "actual Enter starts and creates full saved run"):
		await finish(); return
	var genuine := ConfigFile.new()
	check(genuine.load(BinduSession.RUN_PATH) == OK, "actual product save reads")
	var original_text := genuine.encode_to_text()
	var original_offer: Array = genuine.get_value("run", "offer")
	var original_wave: int = genuine.get_value("run", "wave")
	var camera: Transform2D = main.get_canvas_transform()
	# This is a title-layout fixture, not a claim of real scene reload/navigation.
	main.title_label.visible = true
	main.menu_system._set_prep(false)
	for multiplayer_available in [false, true]:
		for wave in [12, 999, 999999]:
			for map_id in Meta.MAP_IDS:
				for rules in Rules.IDS:
					genuine.set_value("run", "wave", wave)
					genuine.set_value("run", "map", map_id)
					genuine.set_value("run", "rules", rules)
					check(genuine.save(BinduSession.RUN_PATH) == OK, "fixture save writes")
					main.mp_btn.visible = multiplayer_available
					main.persistence_system._refresh_continue()
					await settle()
					check(main.mp_btn.visible == multiplayer_available and main.continue_btn.is_visible_in_tree(), "fixture visibility stable")
					var row := measure(wave, map_id, rules, multiplayer_available)
					rows.append(row)
					if not row["fits"]:
						layout_failures += 1
					check(main.get_canvas_transform().is_equal_approx(camera), "title fixture preserves battlefield camera")
					if not multiplayer_available and wave == 12 and map_id == "plain" and rules == 1 and float(args[3]) in [1.0, 1.3]:
						capture("typical")
					if not multiplayer_available and wave == 999999 and map_id == "cross" and rules == 3 and float(args[3]) == 1.3:
						capture("long")
	# Return from wide/long summaries to the real save; don't resume artificial high waves.
	genuine.parse(original_text)
	check(genuine.save(BinduSession.RUN_PATH) == OK, "original genuine save restored")
	main.mp_btn.visible = true
	main.persistence_system._refresh_continue()
	await settle()
	var wide := measure(original_wave, "original", -1, true)
	main.mp_btn.visible = false
	main.persistence_system._refresh_continue()
	await settle()
	var narrow := measure(original_wave, "original", -1, false)
	checks.append({"name":"wide-to-narrow layout", "wide":wide, "narrow":narrow})
	if not wide["fits"]: layout_failures += 1
	if not narrow["fits"]: layout_failures += 1
	await enter()
	check(not main.title_label.visible and main.phase == main.Phase.CHOOSE and main.wave == original_wave and main.offer == original_offer, "actual Enter resumes genuine saved state")
	check(root.unfocusable and not root.has_focus(), "owned native Window never focuses")
	await finish()

func settle() -> void:
	for i in 16: await process_frame
	RenderingServer.force_draw()

func enter() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER; event.physical_keycode = KEY_ENTER; event.pressed = down
		VirtualInput.send(event)
	await settle()

func measure(wave: int, map_id: String, rules: int, multiplayer: bool) -> Dictionary:
	var button: Button = main.continue_btn
	var box: VBoxContainer = main.continue_info.get_parent()
	var title: Label = box.get_child(0)
	var info: Label = main.continue_info
	var inverse := button.get_global_transform().affine_inverse()
	var title_rect: Rect2 = inverse * title.get_global_rect()
	var info_rect: Rect2 = inverse * info.get_global_rect()
	var outer := Rect2(Vector2.ZERO, button.size)
	var content := Rect2(Vector2(16, 16), button.size - Vector2(32, 32)).grow(0.01)
	var clipped := not outer.grow(0.01).encloses(title_rect) or not outer.grow(0.01).encloses(info_rect)
	return {"profile":profile, "wave":wave, "map":map_id, "rules":rules, "multiplayer":multiplayer,
		"text":info.text, "title":title.text, "lines":info.get_line_count(),
		"title_font":title.get_theme_font_size("font_size"), "info_font":info.get_theme_font_size("font_size"),
		"button_size":vec(button.size), "button_minimum":vec(button.custom_minimum_size),
		"box_minimum":vec(box.get_combined_minimum_size()), "title_relative":rect(title_rect), "info_relative":rect(info_rect),
		"title_scale":vec(main.title_box.scale), "ui_scale":vec(main.ui_root.scale),
		"fits":content.encloses(title_rect) and content.encloses(info_rect), "clipped":clipped,
		"focus_mode":button.focus_mode, "disabled":button.disabled, "accessibility_name":button.accessibility_name,
		"main_processing":main.is_processing(), "frame":Engine.get_process_frames()}

func check(ok: bool, label: String) -> bool:
	if not ok:
		protocol_failures += 1
		print("PROTOCOL FAIL " + label)
	checks.append({"name":label, "passed":ok})
	return ok

func vec(v: Vector2) -> Array:
	return [v.x, v.y]

func rect(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func capture(label: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))

func finish() -> void:
	FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE).store_string(JSON.stringify({"profile":profile, "rows":rows, "checks":checks, "layout_failures":layout_failures, "protocol_failures":protocol_failures}, "\t"))
	main.queue_free()
	for i in 4: await process_frame
	print("CONTINUE TILE rows=%d layout=%d protocol=%d" % [rows.size(), layout_failures, protocol_failures])
	quit(2 if protocol_failures else 0)
