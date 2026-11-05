extends "res://tools/spec_check.gd"
## 같은 fixture로 main/새 레이아웃을 비교한다. BinduTools 격리 사본, 서버 주소 비움, native 창 필수.
var output := ""
var revised := false
var camera_start := Transform2D()
var old_covered := 0

func _initialize():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless":
		push_error("저장 분리 BinduTools 사본의 native 창에서 실행하세요")
		quit(1)
		return
	if OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		push_error("검사 사본의 온라인·멀티 주소를 비우세요")
		quit(1)
		return
	create_timer(60).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	for path in [Tutorial.PATH, Meta.SAVE_PATH, "user://run.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Tutorial.loaded = true
	Tutorial.done = true
	Meta.games = 5
	Meta.guide_on = false
	Meta.ui_scale = float(args[1])
	Meta.card_detail = false
	Meta.sim_phone = args.size() > 2 and args[2] == "phone"
	Meta.sim_safe = Rect2(86, 0, 86, 38) if Meta.sim_phone else Rect2()
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main._hide_title()
	main.touch_ui = args.size() > 2
	main.auto_start = false
	main.set_process(false)
	Meta.ui_scale = float(args[1])
	main._apply_ui_scale()
	main.legend_hidden = false
	revised = main.get("card_dock") != null
	for id in Meta.ACHIEVEMENTS:
		Meta.achieved[id] = true
	seed(17)
	_fresh(12)
	# 가운데를 가리는 기존 카드에 걸리는 오브젝트와 전장 가장자리 오브젝트를 함께 배치한다.
	for p in [Vector2(32, 32), Vector2(1248, 32), Vector2(32, 688), Vector2(1248, 688), Vector2(340, 340), Vector2(600, 440), Vector2(880, 340), Vector2(420, 180), Vector2(870, 560)]:
		_tower(p, Elem.FIRE)
	main.offer = [{"type":"elem", "e":Elem.WATER, "lv":1}, {"type":"mod", "id":"multi"}, {"type":"pat", "id":"laser"}]
	main.picks_left = 1
	main._show_offer()
	main._open_choose()
	main.banner_t = 0
	main.banner_queue.clear()
	main.toast_timer = 0
	main.guide_lines.clear()
	await settle()
	VirtualInput.move(main.choice_box.get_child(0).get_global_rect().get_center())
	await settle()
	main.touch_ui = args.size() > 2
	main.choice_box.get_child(0).mouse_entered.emit()
	if main.touch_ui:
		main._on_card_tap(main.offer[0], 0)
	await snap("hover")
	var hit: Button = main.choice_box.get_child(0)
	var cr := hit.get_global_rect()
	for t in main.towers.get_children():
		if main.choice_box.get_global_rect().has_point(main.get_canvas_transform() * t.position): old_covered += 1
	print("CARD COVERED ", old_covered)
	if revised:
		# 카메라 독립 팔레트는 전장을 덮을 수 있다. 대상 클릭은 팔레트를 접은 뒤 아래에서 검사한다.
		var board: Rect2 = main.card_dock.screen_board()
		var world: Rect2 = main.get_canvas_transform() * main.arena()
		ok("UI-28", board.grow(1).encloses(world), "whole logical arena fits board including edge objects")
		ok("UI-28", main.arena().size == Meta.FIELD, "logical arena unchanged")
		camera_start = main.get_canvas_transform()
		var pt: Vector2 = main.towers.get_child(5).position
		var screen: Vector2 = main.get_canvas_transform() * pt
		ok("UI-28", (main.get_canvas_transform().affine_inverse() * screen).distance_to(pt) < 0.01, "screen placement maps back to same world point")
		var card: Dictionary = main.card_dock.preview_card()
		ok("UI-29", not card.is_empty() and main.card_dock.target_ok(main.towers.get_child(5), card), "preview resolves applicable target")
		ok("UI-29", hit.tooltip_text == "", "card does not open floating tooltip over world")
	main._set_card_detail(true)
	await snap("detail")
	if revised:
		ok("UI-29", not main.card_dock.preview_card().is_empty(), "detail toggle retains card preview")
	main._set_card_detail(false)
	main._set_cards_hidden(true)
	await snap("hidden")
	check_camera("hide cards")
	main._set_cards_hidden(false)
	await settle()
	main._on_pick(main.offer[0])
	await snap("place")
	check_camera("place")
	main._cancel_step()
	await settle()
	ok("UI-28", main.phase == main.Phase.CHOOSE, "cancel returns to choice")
	main._save_run()
	_clear()
	main._continue_run()
	main.toast_timer = 0
	await settle()
	check_camera("continue")
	main._enter_ready()
	await snap("ready")
	check_camera("ready")
	main._start_wave_from_ready()
	main.banner_t = 0
	main.banner_queue.clear()
	await snap("wave")
	check_camera("wave")
	if revised:
		var p: Vector2 = main.card_dock.screen_board().get_center()
		main._zoom_to(1.6, p)
		await snap("zoom")
		ok("UI-28", main.view_zoom > 1.5, "zoom remains available inside board")
		main.phase = main.Phase.CHOOSE
		main._show_offer()
		main._open_choose()
		await settle()
		var z: float = main.view_zoom
		var wheel := InputEventMouseButton.new()
		wheel.position = main.card_dock.panel.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		VirtualInput.move(wheel.position)
		VirtualInput.send(wheel)
		await settle()
		ok("UI-28", main.view_zoom == z, "visible dock wheel cannot zoom world")
		main._reset_zoom()
	main.wave = 5
	main._start_perk()
	main.banner_t = 0
	main.banner_queue.clear()
	main.toast_timer = 0
	await settle()
	main.choice_box.get_child(0).mouse_entered.emit()
	await snap("perk")
	check_camera("perk")
	main.bar_open = true
	await snap("settings_expanded")
	if revised:
		main._toggle_pause()
		await snap("pause")
		check_camera("pause")
		main._toggle_pause()
		_fresh(12)
		var target: Tower = _tower(Vector2(600, 440), Elem.FIRE)
		main._on_pick({"type":"mod", "id":"rapid"})
		await settle()
		var target_screen: Vector2 = main.get_canvas_transform() * target.position
		VirtualInput.move(target_screen)
		await process_frame
		ok("UI-28", main._tower_at(main._pointer_world()) == target, "virtual pointer resolves transformed target")
		var count: int = target.mod_count()
		await click_at(target_screen)
		ok("UI-28", target.mod_count() == count + 1, "virtual input applies card to transformed target")
		main._on_pick({"type":"mod", "id":"rapid"})
		await settle()
		var area: Vector2 = main.card_dock.side.get_global_rect().get_center()
		await click_at(area)
		ok("UI-28", main.phase == main.Phase.PLACE and not main.boxing and target.mod_count() == count + 1, "inspector input does not place or start selection")
		var card: Dictionary = {"type":"elem", "e":Elem.WATER, "lv":1}
		main.phase = main.Phase.CHOOSE
		main.offer = [card]
		main._show_offer()
		main._open_choose()
		await settle()
		main.touch_ui = true
		main._on_card_tap(card, 0)
		await settle()
		ok("UI-29", not main.apply_btn.visible and main.phase == main.Phase.PLACE and main.picked == card, "touch selection carries card without obsolete apply step")
		main._cancel_step()
		main.title_label.visible = true
		await settle()
		ok("UI-28", not main.card_dock.panel.visible and main.camera.zoom.is_equal_approx(Vector2.ONE), "return to title restores camera")
	# 전체 결과는 기존 프로젝트 도구와 마찬가지로 종료 코드로 반환한다.
	print("DOCK failures=", fails, " revised=", revised)
	main.free()
	quit(1 if fails else 0)

func check_camera(label: String):
	if revised:
		ok("UI-28", main.get_canvas_transform().is_equal_approx(camera_start), "camera stays fixed: " + label)

func settle():
	for i in 8:
		main._process(0.0)
		await process_frame
	RenderingServer.force_draw()

func snap(tag: String):
	await settle()
	main.get_viewport().get_texture().get_image().save_png(output.path_join(tag + ".png"))
	fails += preload("res://tools/ui_check.gd").check(main, tag)
	print("DOCK SHOT ", tag)

func click_at(p: Vector2):
	VirtualInput.move(p)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = p
		event.global_position = p
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		VirtualInput.send(event)
		await process_frame
		main._process(0.0)
	await settle()
