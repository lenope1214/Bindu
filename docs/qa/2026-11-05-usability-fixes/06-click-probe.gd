extends "res://tools/carry_check.gd"
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "" or DisplayServer.get_name() == "headless":
		quit(2)
		return
	Tutorial.loaded = true
	Tutorial.done = true
	Meta.games = 5
	Meta.guide_on = false
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main._hide_title()
	main.set_process(false)
	main.auto_start = false
	await create_timer(0.2).timeout
	for touch_mode in [false, true]:
		for run in 3:
			await fixture()
			var at: Vector2 = main.card_dock.focus_btn.get_global_rect().get_center()
			target.position = main.get_canvas_transform().affine_inverse() * at
			var count := [0]
			var pressed := func(): count[0] += 1
			main.card_dock.focus_btn.pressed.connect(pressed)
			var rect: Rect2 = main.ui_root.get_global_transform().affine_inverse() * main.card_dock.focus_btn.get_global_rect()
			main.tip_rects.clear()
			main.tip_rects.append([rect, [["overlap", Color.WHITE]]])
			main.tip_pin = -1
			Input.emulate_mouse_from_touch = true
			if touch_mode:
				var event := InputEventScreenTouch.new()
				event.position = at
				event.pressed = true
				VirtualInput.send(event)
				event = event.duplicate()
				event.pressed = false
				VirtualInput.send(event)
			else:
				var event := InputEventMouseButton.new()
				event.position = at
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = true
				VirtualInput.send(event)
				event = event.duplicate()
				event.pressed = false
				VirtualInput.send(event)
			print("CLICK button touch=", touch_mode, " run=",run," callbacks=",count[0]," pin=",main.tip_pin," selected=",main.selected.size()," press=",main.press_t != null)
			main.card_dock.focus_btn.pressed.disconnect(pressed)
			await settle()
	for emulate in [true, false]:
		for run in 3:
			await fixture()
			target.position = Vector2(220, 300)
			var at := world(target.position)
			var ui_at: Vector2 = main.ui_root.get_global_transform().affine_inverse() * at
			main.tip_rects.clear()
			main.tip_rects.append([Rect2(ui_at - Vector2(30, 18), Vector2(60, 36)), [["overlap", Color.WHITE]]])
			main.tip_pin = -1
			Input.emulate_mouse_from_touch = emulate
			var event := InputEventScreenTouch.new()
			event.position = at
			event.pressed = true
			VirtualInput.send(event)
			event = event.duplicate()
			event.pressed = false
			VirtualInput.send(event)
			print("CLICK badge emulate=",emulate," run=",run," pin=",main.tip_pin," selected=",main.selected.size()," press=",main.press_t != null)
			await settle()
	print("CLICK complete")
	quit(0)
