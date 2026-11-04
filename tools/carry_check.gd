extends "res://tools/spec_check.gd"
## OS 커서·포커스를 건드리지 않는 가상 GUI 입력으로 카드 클릭·드래그·터치와 카메라 독립성을 검증한다.
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
	Meta.sim_phone = phone
	Meta.sim_safe = Rect2(86, 0, 86, 38) if phone else Rect2()
	for id in Meta.ACHIEVEMENTS:
		Meta.achieved[id] = true
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main._hide_title()
	Meta.ui_scale = float(args[1])
	Meta.skip_n = 1
	seed(17)
	main.set_process(false)
	main.auto_start = false
	main._apply_ui_scale()

	await create_timer(0.2).timeout
	await fixture()
	await mouse_click(world(main.center()))
	await fixture()
	ok("UI-34", main.get_viewport_rect().size.is_equal_approx(root.get_visible_rect().size) and VirtualInput.viewport.size == root.size, "가상 화면의 논리 크기·렌더 해상도 원본 창과 일치")
	var os_pointer := DisplayServer.mouse_get_position()
	for at in [Vector2(10, 10), Vector2(1200, 680), Vector2(400, 240)]:
		VirtualInput.move(at)
		ok("UI-34", main._pointer_screen().is_equal_approx(at) and main._pointer_world().is_equal_approx(main.get_canvas_transform().affine_inverse() * at), "가상 포인터 화면·전장 좌표 일치")
	ok("UI-34", DisplayServer.mouse_get_position() == os_pointer and root.unfocusable and root.mode == Window.MODE_MINIMIZED and not root.has_focus() and bool(ProjectSettings.get_setting("display/window/size/no_focus", false)), "OS 커서 불변 %s·unfocusable %s·minimized %s·focus %s·startup no_focus %s" % [DisplayServer.mouse_get_position() == os_pointer, root.unfocusable, root.mode == Window.MODE_MINIMIZED, root.has_focus(), ProjectSettings.get_setting("display/window/size/no_focus", false)])
	await panel_regressions()
	await fixture()
	print("GEOMETRY size=", root.size, " field=", main.get_viewport_rect(), " final=", root.get_final_transform(), " canvas=", root.canvas_transform, " screen=", root.get_screen_transform())
	await snap("browse")
	ok("SKIP-03", main.card_dock.skip_group.visible and is_equal_approx(main.skip_btn.get_global_rect().end.x, main.skip_n_btn.get_global_rect().position.x), "넘기기 실행·개수 버튼을 간격 없는 한 그룹으로 배치")
	for n in [3, 5, 10, 1]:
		await mouse_click(main.skip_n_btn.get_global_rect().get_center())
		ok("SKIP-03", Meta.skip_n == n and main.phase == main.Phase.CHOOSE and main.picks_left == 2, "그룹의 개수 버튼은 개수만 변경: %d" % n)
		if n == 10:
			await snap("skip-ten")
	main.bar_open = true
	main._set_card_detail(true)
	await snap("browse-expanded")
	var icon_center: Vector2 = main._button_icon_center(main.card_detail_btn)
	ok("UI-30", Rect2(Vector2.ZERO, main.card_detail_btn.size).grow(-8).encloses(Rect2(icon_center - Vector2(9, 9), Vector2(18, 18))), "자세히 아이콘은 버튼 내부 여백 안에 배치")
	ok("UI-30", is_equal_approx(main.bar_box.position.y - main.card_dock.footer.position.y, 12) and is_equal_approx(main.ui_root.size.y - main.bar_box.get_rect().end.y, 12), "옵션 줄 위아래 여백 각각 12")
	for entry in [[main.reroll_btn, "Q"], [main.card_detail_btn, "Z"], [main.skip_btn, "S"], [main.hide_btn, "V"]]:
		var button: Button = entry[0]
		var content_right: float = main._button_icon_center(button).x + 9
		if button.text != "":
			content_right += 8 + button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
		var shortcut_left: float = button.size.x - 3 - 8 - main.ui_font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		ok("UI-30", content_right + 4 <= shortcut_left, "아이콘·텍스트와 단축키 사이 여백: " + entry[1])
	main._set_card_detail(false)
	main.bar_open = false
	await settle()
	if not main.card_dock.has_method("carrying"):
		print("CARRY BASELINE captured")
		quit(0)
		return
	start_camera = main.get_canvas_transform()
	camera_ready = true
	ok("UI-31", main.camera.zoom.x >= 0.99, "1280×720 전장 원래 크기 이상·UI 배율로 축소하지 않음")
	await mouse_click(card_center())
	ok("UI-31", held() and main.picks_left == 2, "가상 카드 클릭: 미소비·목록/상세 접힘·이름 말풍선 없음")
	await mouse_move(world(target.position))
	await snap("held-target")
	ok("UI-25", not main.hint.visible, "대상 미리보기 위에 하단 조작 안내를 겹쳐 쓰지 않음")
	main.bar_open = true
	await snap("held-controls")
	main.bar_open = false
	await settle()
	ok("UI-31", not main.card_dock.over_ui(world(target.position)), "기존 카드 줄 뒤의 대상도 가림 없이 선택 가능")
	await mouse_click(world(target.position))
	ok("UI-31", target.m("pierce") == 1 and main.picks_left == 1, "가상 대상 클릭: 정확히 한 번 적용")
	await snap("applied")
	await fixture()
	var offers: Array = main.offer.duplicate(true)
	await mouse_click(card_center())
	await key(KEY_ESCAPE)
	ok("UI-31", main.phase == main.Phase.CHOOSE and main.offer == offers and main.picks_left == 2, "Esc: 동일 목록과 남은 선택 복원")
	await snap("cancelled")
	await drag_to(world(refused.position))
	ok("UI-31", held() and main.picks_left == 2 and refused.m("pierce") == 0, "가상 드래그 무효 대상: 미소비·계속 들기")
	await snap("refused")
	# 화면 밖의 드롭은 소비하지 않는다.
	main._drop_carried_card(Vector2(-1, main.get_viewport_rect().size.y / 2))
	ok("UI-31", main.picks_left == 2, "화면 밖 드롭은 미소비")
	await mouse_click(main.cancel_btn.get_global_rect().get_center())
	await drag_to(world(target.position))
	ok("UI-31", target.m("pierce") == 1 and main.picks_left == 1, "가상 카드 드래그: 손을 뗀 대상에 정확히 1회 적용")
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
	ok("UI-31", held() and main.picks_left == 2, "가상 터치 이벤트: 한 번 눌러 들기")
	await snap("touch-held")
	var cancel_at: Vector2 = main.cancel_btn.get_global_rect().get_center()
	await touch(cancel_at, true)
	await touch(cancel_at, false)
	ok("UI-31", main.phase == main.Phase.CHOOSE and main.picks_left == 2, "터치 취소 버튼도 한 번에 같은 목록 복원")
	await touch(card_center(), true)
	await touch_drag(world(target.position) + Vector2(0, -90))
	await touch_drag(world(target.position))
	await touch(world(target.position), false)
	ok("UI-31", target.m("pierce") == 1 and main.picks_left == 1, "가상 터치 드래그: 중복 없이 한 번 적용")
	await fixture()
	await touch(card_center(), true)
	await touch_drag(world(target.position) + Vector2(0, -90))
	await touch_drag(world(target.position))
	await touch(world(target.position) + Vector2(160, 0), true, 1)
	await touch_drag(world(target.position) + Vector2(240, 0), 1)
	ok("UI-31", main.pinch_lock and main.view_zoom > 1.0, "카드를 든 채 두 손가락으로 가상 확대 가능")
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
	ok("UI-34", not paused, "가상 P 입력으로 일시정지 복귀")
	await fixture()
	var empty_at := Vector2(450, 400)
	await mouse_click(card_center(1))
	await mouse_move(world(empty_at))
	ok("UI-31", main.card_dock.carrying() and not main.ui_root.has_node("CarriedCard"), "속성 카드 이름 말풍선 없이 설치 안내만 표시")
	await snap("element-place")
	await mouse_move(world(main.center()))
	await snap("element-near-core")
	main._zoom_to(1.5, main.get_viewport_rect().size / 2)
	await mouse_move(Vector2(main.get_viewport_rect().size.x - 4, 90))
	camera_ready = false
	await snap("element-edge-zoom")
	camera_ready = true
	main._reset_zoom()
	await key(KEY_ESCAPE)
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
	ok("UI-31", main.towers.get_child_count() == 3 and main.picks_left == 1, "속성 카드 클릭·방향 확정: 가상 새 오브젝트 설치와 1회 차감")
	await fixture()
	await touch(card_center(1), true)
	await touch_drag(world(empty_at))
	await touch(world(empty_at), false)
	var direction: Vector2 = world(empty_at + Vector2(-120, -60))
	await touch(direction, true)
	await touch(direction, false)
	ok("UI-31", main.phase == main.Phase.AIM and main.aim_ok_btn.visible, "터치 방향 선택 뒤 확정 버튼 표시")
	await touch(main.aim_ok_btn.get_global_rect().get_center(), true)
	await touch(main.aim_ok_btn.get_global_rect().get_center(), false)
	ok("UI-31", main.towers.get_child_count() == 3 and main.picks_left == 1, "터치 속성 드래그 후 방향 터치로 가상 설치")
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
	await speed_regressions()
	main.bar_open = true
	await settle()
	await mouse_click(main.fx_pick.get_global_rect().get_center())
	await snap("options")
	main.fx_pick.get_popup().hide()
	print("CARRY failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails + ui_errors > 0 else 0)

func panel_regressions() -> void:
	var same_offer: Array = main.offer.duplicate(true)
	for i in 3:
		main.bar_open = i % 2 == 1
		await settle()
		await mouse_click(main.hide_btn.get_global_rect().get_center())
		ok("UI-23", main.cards_hidden and not main.card_dock.panel.visible, "버튼으로 선택지 닫기 %d" % i)
		ok("UI-23", not main.bar_open or not main.hide_btn.get_global_rect().intersects(main.bar_box.get_global_rect()), "복원 버튼과 펼친 설정 줄 분리 %d" % i)
		await mouse_click(main.hide_btn.get_global_rect().get_center())
		ok("UI-23", not main.cards_hidden and main.card_dock.panel.visible, "복원 버튼의 press/release로 다시 열기 %d" % i)
		await key(KEY_V)
		ok("UI-23", main.cards_hidden and not main.card_dock.panel.visible, "V로 선택지 닫기 %d" % i)
		await key(KEY_V)
		ok("UI-23", not main.cards_hidden and main.card_dock.panel.visible and main.offer == same_offer and main.picks_left == 2, "V로 같은 선택지·장수 복원 %d" % i)
	main.bar_open = true
	await key(KEY_F)
	await key(KEY_V)
	ok("UI-23", main.card_dock.panel.visible and not main.card_dock.full_field, "F로 접은 패널도 V로 복원")
	await snap("toggle-restored")
	main._set_card_detail(true)
	await mouse_move(card_center())
	await mouse_move(world(main.center()))
	ok("UI-32", main.card_dock.pic.mode == "card", "카드 호버 종료 뒤 미리보기 유지")
	await key(KEY_V)
	for e in Elem.ALL:
		target.add(e, 1)
	target.eff = target.eff_now()
	await key(KEY_SHIFT)
	await mouse_move(world(target.position))
	ok("UI-32", main.card_dock.shown_tower == target, "유지된 카드 미리보기를 새 오브젝트 정보로 교체")
	await mouse_move(world(main.center()))
	ok("UI-32", main.card_dock.side.visible and main.card_dock.shown_tower == target, "오브젝트와 패널 사이 빈 공간에서도 상세 유지")
	await mouse_move(main.card_dock.side.get_global_rect().get_center())
	await snap("inspector-retained")
	ok("UI-32", main.card_dock.shown_tower == target and main.card_dock.side.mouse_filter == Control.MOUSE_FILTER_STOP, "인스펙터 안으로 이동해도 대상·입력 유지")
	var before: int = main.card_dock.scroll.scroll_vertical
	for i in 8:
		var wheel := InputEventMouseButton.new()
		wheel.position = main.card_dock.side.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		VirtualInput.send(wheel)
		wheel = wheel.duplicate()
		wheel.pressed = false
		VirtualInput.send(wheel)
		await settle()
	ok("UI-32", main.card_dock.scroll.scroll_vertical > before and main.card_dock.shown_tower == target, "유지된 오브젝트 상세를 가상 휠로 스크롤")
	await snap("inspector-scrolled")
	await mouse_click(main.card_dock.side.get_global_rect().get_center())
	ok("UI-32", main.card_dock.shown_tower == target, "패널 내부 클릭은 오브젝트 정보 유지")
	refused.position = Vector2(640, 300)
	await mouse_move(world(refused.position))
	ok("UI-32", main.card_dock.shown_tower == refused, "다른 오브젝트 호버로 상세 교체")
	var release := InputEventKey.new()
	release.keycode = KEY_SHIFT
	release.pressed = false
	VirtualInput.send(release)
	main.selected = [refused]
	main.tip_tower = refused
	await mouse_click(world(main.center()))
	ok("UI-32", main.selected.is_empty() and main.card_dock.inspected_tower == null and main.tip_tower == null and not main.card_dock.side.visible, "빈 배경 클릭으로 오브젝트 선택·상세 해제")
	await snap("inspector-dismissed")
	main.bar_open = false
	await settle()
	await mouse_move(world(refused.position))
	main.selected = [refused]
	var bar_rect: Rect2 = main.bar_box.get_global_rect()
	var empty_bar := bar_rect.position + bar_rect.size * Vector2(0.4, 0.5)
	ok("UI-32", not main.card_dock.over_ui(empty_bar), "접힌 설정 줄의 빈 영역은 배경으로 처리")
	await mouse_click(empty_bar)
	ok("UI-32", main.selected.is_empty() and not main.card_dock.side.visible, "투명한 설정 영역 뒤의 배경 클릭도 선택 해제")
	main.bar_open = true
	await settle()
	await mouse_move(world(refused.position))
	ok("UI-32", main.card_dock.shown_tower == refused, "해제 후 새 오브젝트 호버로 다시 탐색")
	await mouse_click(world(refused.position))
	ok("UI-32", main.phase == main.Phase.AIM and main.moving == refused, "설치 오브젝트 클릭의 방향 편집 유지")
	await mouse_click(world(main.center()))
	ok("UI-32", main.phase == main.Phase.CHOOSE and main.moving == null and not main.card_dock.side.visible and main.picks_left == 2, "배경으로 방향 확정 후 오브젝트 상세 해제")
	main._set_cards_hidden(true)
	await settle()
	await key(KEY_V)
	await mouse_move(card_center(1))
	ok("UI-32", main.card_dock.pic.mode == "card" and main.card_dock.inspected_tower == null and main.card_dock.pic.card.get("e", -1) == Elem.FIRE, "새 카드 호버로 오브젝트 상세 교체")
	await mouse_click(world(main.center()))
	ok("UI-32", main.card_dock.pic.mode == "card" and main.picks_left == 2, "배경 클릭은 카드 미리보기·남은 선택 보존")
	await mouse_click(card_center(1))
	ok("UI-32", held() and not main.card_dock.side.visible, "카드 선택 시 상세 숨김·카드 들기 유지")
	await key(KEY_ESCAPE)
	await key(KEY_V)
	await mouse_move(world(target.position))
	await mouse_move(world(main.center()))
	target.queue_free()
	await settle()
	ok("UI-32", not main.card_dock.side.visible and main.card_dock.inspected_tower == null, "삭제된 오브젝트 상세 참조 해제")


func speed_regressions() -> void:
	main.bar_open = true
	main.game_speed = 1.0
	main.fast_speed = 2.0
	main._update_speed_btn()
	await settle()
	ok("UI-30", is_equal_approx(main.speed_btn.get_global_rect().end.x, main.speed_pick.get_global_rect().position.x), "배속 실행·선택을 간격 없는 연결 그룹으로 배치")
	await mouse_click(main.speed_pick.get_global_rect().get_center())
	ok("UI-30", main.speed_pick.get_popup().visible, "배속 그룹의 셀렉트를 가상 클릭으로 열기")
	main.speed_pick.get_popup().index_pressed.emit(main.SPEEDS.size() - 1)
	main.speed_pick.get_popup().hide()
	await settle()
	ok("UI-30", main.fast_speed == main.SPEEDS[-1] and main.game_speed == 1.0, "배속 셀렉트 선택만으로 실행 속도를 켜지 않음")
	await mouse_click(main.speed_btn.get_global_rect().get_center())
	ok("UI-30", main.game_speed == main.fast_speed, "그룹 실행 버튼으로 선택한 배속 적용")
	await key(KEY_SPACE)
	ok("UI-30", main.game_speed == 1.0, "Space로 기본 배속 복귀")
	await snap("speed-group")


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
	return main.phase == main.Phase.PLACE and not main.choice_box.visible and not main.card_dock.panel.visible and not main.card_dock.side.visible and main.card_dock.carrying()

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
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))
	var bad: int = preload("res://tools/ui_check.gd").check(main, label)
	ui_errors += bad
	if camera_ready:
		ok("UI-31", main.get_canvas_transform().is_equal_approx(start_camera), label + ": 카메라 고정")

func mouse_move(p: Vector2, down := false) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	VirtualInput.send(e)
	await settle()

func mouse_button(p: Vector2, down: bool) -> void:
	VirtualInput.move(p)
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	VirtualInput.send(e)
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
	VirtualInput.send(e)
	await settle()

func touch(p: Vector2, down: bool, id := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.pressed = down
	e.index = id
	VirtualInput.send(e)
	await settle()

func touch_drag(p: Vector2, id := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.position = p
	e.index = id
	VirtualInput.send(e)
	await settle()
