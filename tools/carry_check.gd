extends "res://tools/spec_check.gd"
## 실제 GUI 입력으로 카드 클릭·드래그·터치와 카메라 독립성을 검증한다.
## 저장 분리 BinduTools 사본·온라인 주소 비움·native 창에서만 실행.
var output := ""
var start_camera := Transform2D()
var camera_ready := false
var card := {"type":"mod", "id":"pierce"}
var target: Tower
var refused: Tower
var phone := false
var ui_errors := 0

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		push_error("BinduTools 격리 사본·서버 주소 비움·native 창이 필요합니다")
		quit(1)
		return
	create_timer(100).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args.size() > 2 and args[2] == "phone"
	DirAccess.make_dir_recursive_absolute(output)
	Tutorial.loaded = true
	Tutorial.done = true
	Meta.games = 5
	Meta.guide_on = false
	Meta.ui_scale = float(args[1])
	Meta.sim_phone = phone
	Meta.sim_safe = Rect2(86, 0, 86, 38) if phone else Rect2()
	for id in Meta.ACHIEVEMENTS:
		Meta.achieved[id] = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._hide_title()
	seed(17)
	main.set_process(false)
	main.auto_start = false
	main._apply_ui_scale()
	await fixture()
	print("GEOMETRY size=", root.size, " field=", main.get_viewport_rect(), " final=", root.get_final_transform(), " canvas=", root.canvas_transform, " screen=", root.get_screen_transform())
	await snap("browse")
	if not main.card_dock.has_method("carrying"):
		print("CARRY BASELINE captured")
		quit(0)
		return
	start_camera = main.get_canvas_transform()
	camera_ready = true
	ok("UI-31", main.camera.zoom.x >= 0.99, "1280×720 전장 원래 크기 이상·UI 배율로 축소하지 않음")
	await mouse_click(card_center())
	ok("UI-31", held() and main.picks_left == 2, "실제 카드 클릭: 미소비·목록/상세 접힘·작은 카드 표시")
	await mouse_move(world(target.position))
	await snap("held-target")
	main.bar_open = true
	await snap("held-controls")
	main.bar_open = false
	await settle()
	ok("UI-31", not main.card_dock.over_ui(world(target.position)), "기존 카드 줄 뒤의 대상도 가림 없이 선택 가능")
	await mouse_click(world(target.position))
	ok("UI-31", target.m("pierce") == 1 and main.picks_left == 1, "실제 대상 클릭: 정확히 한 번 적용")
	await snap("applied")
	await fixture()
	var offers: Array = main.offer.duplicate(true)
	await mouse_click(card_center())
	await key(KEY_ESCAPE)
	ok("UI-31", main.phase == main.Phase.CHOOSE and main.offer == offers and main.picks_left == 2, "Esc: 동일 목록과 남은 선택 복원")
	await snap("cancelled")
	await drag_to(world(refused.position))
	ok("UI-31", held() and main.picks_left == 2 and refused.m("pierce") == 0, "실제 드래그 무효 대상: 미소비·계속 들기")
	await snap("refused")
	# 화면 밖의 드롭은 소비하지 않는다.
	main._drop_carried_card(Vector2(-1, main.get_viewport_rect().size.y / 2))
	ok("UI-31", main.picks_left == 2, "화면 밖 드롭은 미소비")
	await mouse_click(main.cancel_btn.get_global_rect().get_center())
	await drag_to(world(target.position))
	ok("UI-31", target.m("pierce") == 1 and main.picks_left == 1, "실제 카드 드래그: 손을 뗀 대상에 정확히 1회 적용")
	await snap("drag-applied")
	await fixture()
	await mouse_button(card_center(), true)
	await mouse_move(world(target.position) + Vector2(0, -90), true)
	await mouse_move(world(target.position), true)
	ok("UI-31", main.card_dock.card_dragging, "Esc 전에 드래그 상태 진입")
	await key(KEY_ESCAPE)
	await mouse_button(world(target.position), false)
	ok("UI-31", main.phase == main.Phase.CHOOSE and target.m("pierce") == 0 and main.picks_left == 2, "드래그 중 Esc 후 손 떼기: 오적용 없음")
	await fixture()
	await mouse_button(card_center(), true)
	await mouse_move(world(target.position) + Vector2(0, -90), true)
	await mouse_move(world(target.position), true)
	main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await mouse_button(world(target.position), false)
	ok("UI-31", main.picks_left == 2 and target.m("pierce") == 0, "앱 전환 후 손 떼기: 오적용 없음")
	await fixture()
	# ScreenTouch/ScreenDrag와 Godot의 마우스 에뮬레이션을 함께 통과시킨다.
	Input.emulate_mouse_from_touch = true
	await touch(card_center(), true)
	await touch(card_center(), false)
	ok("UI-31", held() and main.picks_left == 2, "실제 터치 이벤트: 한 번 눌러 들기")
	await snap("touch-held")
	var cancel_at: Vector2 = main.cancel_btn.get_global_rect().get_center()
	await touch(cancel_at, true)
	await touch(cancel_at, false)
	ok("UI-31", main.phase == main.Phase.CHOOSE and main.picks_left == 2, "터치 취소 버튼도 한 번에 같은 목록 복원")
	await touch(card_center(), true)
	await touch_drag(world(target.position) + Vector2(0, -90))
	await touch_drag(world(target.position))
	await touch(world(target.position), false)
	ok("UI-31", target.m("pierce") == 1 and main.picks_left == 1, "실제 터치 드래그: 중복 없이 한 번 적용")
	await fixture()
	await touch(card_center(), true)
	await touch_drag(world(target.position) + Vector2(0, -90))
	await touch_drag(world(target.position))
	await touch(world(target.position) + Vector2(160, 0), true, 1)
	await touch_drag(world(target.position) + Vector2(240, 0), 1)
	ok("UI-31", main.pinch_lock and main.view_zoom > 1.0, "카드를 든 채 두 손가락으로 실제 확대 가능")
	await touch(world(target.position), false)
	await touch(world(target.position) + Vector2(160, 0), false, 1)
	ok("UI-31", main.picks_left == 2 and target.m("pierce") == 0, "두 번째 손가락 확대 중 손 떼기: 카드 적용 없음")
	await fixture()
	Input.emulate_mouse_from_touch = false
	await touch(card_center(), true)
	await touch_drag(world(target.position) + Vector2(0, -90))
	await touch_drag(world(target.position))
	await touch(world(target.position), false)
	ok("UI-31", target.m("pierce") == 1 and main.picks_left == 1, "마우스 에뮬레이션 없는 터치 드래그도 1회 적용")
	Input.emulate_mouse_from_touch = true
	await fixture()
	await mouse_button(card_center(), true)
	await mouse_move(world(target.position) + Vector2(0, -90), true)
	await key(KEY_P)
	await mouse_button(world(target.position), false)
	ok("UI-31", paused and main.picks_left == 2 and target.m("pierce") == 0, "드래그 중 일시정지·손 떼기: 오적용 없음")
	await key(KEY_P)
	await fixture()
	var empty_at := Vector2(450, 400)
	await drag_to(world(empty_at), 1)
	ok("UI-31", main.phase == main.Phase.AIM and main.towers.get_child_count() == 2 and main.picks_left == 2, "속성 카드 드롭: 방향 확정 전에는 새 오브젝트·횟수 소비 없음")
	await snap("element-aim")
	await key(KEY_ESCAPE)
	ok("UI-31", main.phase == main.Phase.PLACE and main.picks_left == 2, "방향 취소: 같은 카드를 들고 위치 재선택")
	await key(KEY_ESCAPE)
	ok("UI-31", main.phase == main.Phase.CHOOSE and main.tap_sel == 1, "위치 취소: 같은 속성 카드 선택 표시 복원")
	await mouse_click(card_center(1))
	await mouse_click(world(empty_at))
	await mouse_click(world(empty_at + Vector2(-120, -60)))
	ok("UI-31", main.towers.get_child_count() == 3 and main.picks_left == 1, "속성 카드 클릭·방향 확정: 실제 새 오브젝트 설치와 1회 차감")
	await fixture()
	await touch(card_center(1), true)
	await touch_drag(world(empty_at))
	await touch(world(empty_at), false)
	var direction: Vector2 = world(empty_at + Vector2(-120, -60))
	await touch(direction, true)
	await touch(direction, false)
	ok("UI-31", main.towers.get_child_count() == 3 and main.picks_left == 1, "터치 속성 드래그 후 방향 터치로 실제 설치")
	await fixture()
	main._zoom_to(1.5, main.get_viewport_rect().size / 2)
	var zoomed: Transform2D = main.get_canvas_transform()
	await mouse_click(card_center())
	ok("UI-31", main.get_canvas_transform().is_equal_approx(zoomed), "카드 들어도 사용자 확대 유지")
	await key(KEY_ESCAPE)
	ok("UI-31", main.get_canvas_transform().is_equal_approx(zoomed), "취소해도 사용자 확대 유지")
	main._set_card_detail(true)
	await settle()
	ok("UI-31", main.get_canvas_transform().is_equal_approx(zoomed), "상세를 열어도 사용자 확대 유지")
	main._reset_zoom()
	await settle()
	await snap("detail")
	main._set_card_detail(false)
	main._toggle_focus_view()
	await settle()
	main._toggle_focus_view()
	await settle()
	ok("UI-31", main.reroll_btn.visible and main.rerolls_left == 1 and main.get_canvas_transform().is_equal_approx(start_camera), "카드 접기·복원 후 새로고침과 카메라 유지")
	main.lanes.clear()  # 이 검사는 배치 유효성 정책이 아닌 전투 전환의 카메라를 확인한다.
	main._enter_ready()
	await snap("ready")
	ok("UI-31", main.start_btn.visible and main.skip_btn.visible and main.skip_n_btn.visible, "배치 완료 후 시작·넘기기 조작 보존")
	main._start_wave_from_ready()
	main.banner_t = 0
	main.banner_queue.clear()
	await snap("wave")
	print("CARRY failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails + ui_errors > 0 else 0)

func fixture() -> void:
	paused = false
	main._drop_press()
	main.moving = null
	main.selected.clear()
	main.card_dock.full_field = false
	if main.card_dock.has_method("clear_gesture"):
		main.card_dock.clear_gesture()
	main._reset_zoom()
	_fresh(12)
	target = _tower(Vector2(220, 620), Elem.WATER)
	refused = _tower(Vector2(1060, 620), Elem.WATER)
	refused.set_pattern("thorn")
	main.offer = [card.duplicate(), {"type":"elem", "e":Elem.FIRE, "lv":1}, {"type":"elem", "e":Elem.WOOD, "lv":1}]
	main.picks_left = 2
	main.rerolls_left = 1
	main._show_offer()
	main._open_choose()
	Meta.card_detail = false
	main.banner_t = 0
	main.banner_queue.clear()
	main.toast_timer = 0
	await settle()

func held() -> bool:
	return main.phase == main.Phase.PLACE and not main.choice_box.visible and not main.card_dock.panel.visible and not main.card_dock.side.visible and main.card_dock.held_chip.visible

func card_center(index := 0) -> Vector2:
	return main.choice_box.get_child(index).get_global_rect().get_center()

func world(p: Vector2) -> Vector2:
	return main.get_canvas_transform() * p

func settle() -> void:
	for i in 4:
		main._process(0.0)
		await process_frame

func snap(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	var bad: int = preload("res://tools/ui_check.gd").check(main, label)
	ui_errors += bad
	if camera_ready:
		ok("UI-31", main.get_canvas_transform().is_equal_approx(start_camera), label + ": 카메라 고정")

func mouse_move(p: Vector2, down := false) -> void:
	root.warp_mouse(p)
	var e := InputEventMouseMotion.new()
	e.position = root.get_final_transform() * p
	e.global_position = root.get_final_transform() * p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)
	await settle()

func mouse_button(p: Vector2, down: bool) -> void:
	root.warp_mouse(p)
	var e := InputEventMouseButton.new()
	e.position = root.get_final_transform() * p
	e.global_position = root.get_final_transform() * p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	Input.parse_input_event(e)
	await settle()

func mouse_click(p: Vector2) -> void:
	await mouse_move(p)
	await mouse_button(p, true)
	await mouse_button(p, false)

func drag_to(p: Vector2, index := 0) -> void:
	await mouse_button(card_center(index), true)
	await mouse_move(p + Vector2(0, -90), true)
	await mouse_move(p, true)
	await mouse_button(p, false)

func key(k: int) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await settle()

func touch(p: Vector2, down: bool, id := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = root.get_final_transform() * p
	e.pressed = down
	e.index = id
	Input.parse_input_event(e)
	await settle()

func touch_drag(p: Vector2, id := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.position = root.get_final_transform() * p
	e.index = id
	Input.parse_input_event(e)
	await settle()
