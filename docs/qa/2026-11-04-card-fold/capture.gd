extends "res://tools/spec_check.gd"
var output := ""
var ui_bad := 0
var phone := false
func _initialize() -> void:
	if DisplayServer.get_name() == "headless" or not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args.size() > 2
	DirAccess.make_dir_recursive_absolute(output)
	Tutorial.loaded = true
	Tutorial.done = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._hide_title()
	main.set_process(false)
	paused = false
	main.tut.hide()
	Meta.ui_scale = float(args[1])
	Meta.sim_phone = phone
	Meta.sim_safe = Rect2(86, 0, 86, 38) if phone else Rect2()
	main._apply_ui_scale()
	_fresh(12)
	main.auto_start = false
	main.offer = [{"type":"mod", "id":"pierce"}, {"type":"elem", "e":Elem.FIRE, "lv":1}, {"type":"elem", "e":Elem.WATER, "lv":1}]
	main.picks_left = 2
	main._show_offer()
	main._open_choose()
	main._set_card_detail(true)
	await settle()
	main.card_dock.hovered = main.choice_box.get_child(0)
	await settle()
	var original: Array = main.offer.duplicate(true)
	var camera: Transform2D = main.get_canvas_transform()
	ok("UI-23", main.card_dock.focus_btn.visible and main.card_dock.focus_btn.text == "카드 접기", "PC·폰에서 접기 버튼 노출")
	await snap("expanded")
	DisplayServer.window_move_to_foreground()
	await create_timer(0.2).timeout
	await click(world(main.center()))
	for i in 3:
		await click(main.card_dock.focus_btn.get_global_rect().get_center())
		ok("UI-23", main.card_dock.full_field and not main.card_dock.panel.visible and not main.card_dock.side.visible and main.card_dock.focus_btn.text == "카드 보기", "버튼으로 카드·상세 접기 %d" % i)
		if i == 0:
			await snap("collapsed")
		await click(main.card_dock.focus_btn.get_global_rect().get_center())
		ok("UI-23", not main.card_dock.full_field and main.card_dock.panel.visible and main.offer == original and main.picks_left == 2 and camera.is_equal_approx(main.get_canvas_transform()), "같은 선택지·장수·카메라로 펼치기 %d" % i)
	main._set_cards_hidden(true)
	await settle()
	ok("UI-23", main.card_dock.focus_btn.text == "카드 보기", "V 숨김 상태에서 보기 표시")
	await click(main.card_dock.focus_btn.get_global_rect().get_center())
	ok("UI-23", main.card_dock.panel.visible and not main.cards_hidden and not main.card_dock.full_field, "V로 숨긴 뒤 접기/보기 버튼으로 복원")
	await snap("restored")
	print("FOLD failures=%d ui=%d" % [fails, ui_bad])
	quit(1 if fails + ui_bad else 0)
func world(p: Vector2) -> Vector2:
	return main.get_canvas_transform() * p
func settle() -> void:
	for i in 4:
		main._process(0.0)
		await process_frame
func click(p: Vector2) -> void:
	root.warp_mouse(p)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * p
	Input.parse_input_event(motion)
	await settle()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_final_transform() * p
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await settle()
func snap(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	ui_bad += preload("res://tools/ui_check.gd").check(main, name)
