extends "res://tools/carry_check.gd"
## 입력 사용성 회귀. 격리 native 사본에서 GUI 입력을 통해 최종 상태를 검사한다.

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(120).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args.size() > 2 and args[2] == "phone"
	DirAccess.make_dir_recursive_absolute(output)
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 5
	Meta.guide_on = false
	Meta.sim_phone = phone
	Meta.sim_safe = Rect2(86, 0, 86, 38) if phone else Rect2()
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main.progression_system._hide_title()
	main.set_process(false)
	main.auto_start = false
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	await create_timer(0.2).timeout
	await modal_cases()
	await object_cases()
	await placement_case()
	await keyboard_and_group_case()
	print("BATTLEFIELD INPUT failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails else 0)

func reset_input_case() -> void:
	paused = false
	main.help_label.hide()
	main.settings_panel.hide()
	main.notes_panel.hide()
	main.codex_panel.hide()
	main.records_panel.hide()
	main.vote_panel.hide()
	main.modes_panel.hide()
	main.skill_arm = ""
	main.card_dock.inspector_dismissed = false
	await fixture()
	target.position = Vector2(280, 300)
	refused.position = Vector2(950, 300)
	main.touch_ui = phone
	await settle()

func input_key(code: int, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	e.pressed = true
	VirtualInput.send(e)
	await settle()
	e.pressed = false
	VirtualInput.send(e)
	await settle()

func input_tap(at: Vector2) -> void:
	if phone:
		await touch(at, true)
		await touch(at, false)
	else:
		await mouse_click(at)

func modal_cases() -> void:
	await reset_input_case()
	await input_key(KEY_O)
	var original_offer: Array = main.offer.duplicate(true)
	for code in [KEY_1, KEY_Q, KEY_S, KEY_SPACE]:
		await input_key(code)
	ok("BF-01", main.settings_panel.visible and main.phase == main.Phase.CHOOSE and main.offer == original_offer and main.rerolls_left == 1 and main.picks_left == 2 and main.skip_left == 0, "설정이 게임 단축키를 소유: 카드·새로고침·넘기기·시작 불변")
	await input_key(KEY_ESCAPE)
	await input_key(KEY_H)
	for code in [KEY_Q, KEY_S, KEY_1]:
		await input_key(code)
	ok("BF-01", main.help_label.visible and main.phase == main.Phase.CHOOSE and main.rerolls_left == 1 and main.skip_left == 0, "도움말 뒤 소비 없음")
	await input_key(KEY_ESCAPE)
	await input_key(KEY_Z, true)
	ok("BF-05", not Meta.card_detail, "Ctrl+Z가 plain Z 자세히를 실행하지 않음")
	for code in [KEY_1, KEY_Q, KEY_O, KEY_S]:
		await input_key(code, true)
	ok("BF-01", main.phase == main.Phase.CHOOSE and main.rerolls_left == 1 and not main.settings_panel.visible and main.skip_left == 0, "수정키 조합이 plain 게임 명령을 실행하지 않음")
	await snap("01-modal-input")

func object_cases() -> void:
	await reset_input_case()
	main.cards_system._set_cards_hidden(true)
	target.position = Vector2(280, 300)
	refused.position = Vector2(315, 300)
	await input_tap(world(Vector2(304, 300)))
	ok("BF-04", main.interaction_system.selected == [refused], "노드 순서 대신 가까운 대상 선택 (거리 24 대 11)")
	main.towers.move_child(refused, 0)
	await input_tap(world(Vector2(297.5, 300)))
	ok("BF-04", main.interaction_system.selected == [target], "동률은 위치 기준으로 결정되어 생성 순서와 무관")
	await input_tap(world(refused.position))
	await input_tap(world(refused.position))
	ok("BF-12", main.phase == main.Phase.CHOOSE and main.interaction_system.selected == [refused], "반복 선택은 방향 편집에 들어가지 않음")
	main.card_dock.close_inspector(true)
	await input_tap(world(target.position))
	ok("BF-03", not main.card_dock.inspector_dismissed and main.card_dock.side.visible, "명시적 재선택은 닫은 정보 복구")
	await snap("02-nearest-selection")
	await reset_input_case()
	main.cards_system._set_cards_hidden(true)
	if phone:
		await touch(world(target.position), true)
	else:
		await mouse_button(world(target.position), true)
	await create_timer(0.45).timeout
	await settle()
	ok("BF-13", not main.interaction_system.dragging and target.position == Vector2(280, 300), "정지한 길게 누르기는 이동 아님")
	if phone:
		await touch(world(target.position), false)
	else:
		await mouse_button(world(target.position), false)
	if not phone:
		var d: Vector2 = target.dir
		var e := InputEventMouseButton.new()
		e.position = world(target.position)
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		VirtualInput.send(e)
		await settle()
		ok("BF-14", target.dir == d and main.view_zoom > 1.0, "일반 휠은 선택 위에서도 확대")
	await reset_input_case()
	main.cards_system._enter_ready()
	main.run_flow_system._start_wave()
	await settle()
	await input_tap(world(target.position))
	main.card_dock.close_inspector(true)
	await input_tap(world(refused.position))
	ok("BF-03", not main.card_dock.inspector_dismissed and main.card_dock.side.visible, "전투 중 닫기 뒤 명시적 재선택으로 정보 복구")
	await input_key(KEY_ESCAPE)
	ok("BF-06", paused, "정보가 열려 있어도 전투 Esc 즉시 정지")
	await snap("03-wave-immediate-pause")

func placement_case() -> void:
	await reset_input_case()
	var original_count: int = main.towers.get_child_count()
	await input_tap(card_center(1))
	await input_tap(world(Vector2(470, 400)))
	ok("BF-09", main.towers.get_child_count() == original_count + 1 and main.picks_left == 1 and main.phase == main.Phase.CHOOSE, "기본 자동 조준 새 설치는 방향 확정 없이 1회 완료")
	await snap("04-auto-aim-placement")

func keyboard_and_group_case() -> void:
	await reset_input_case()
	main.cards_system._set_cards_hidden(true)
	var has_group: bool = main.interaction_system.has_method("set_additive_selection") and main.interaction_system.has_method("rotate_selected") and main.interaction_system.has_method("move_selected")
	ok("BF-16", has_group, "터치 그룹 편집 API 존재")
	if has_group:
		main.interaction_system.set_additive_selection(true)
		await input_tap(world(target.position))
		await input_tap(world(refused.position))
		ok("BF-16", main.interaction_system.selected.size() == 2, "터치 선택 모드로 떨어진 대상 추가")
		await input_tap(world(target.position))
		ok("BF-16", main.interaction_system.selected == [refused], "터치 선택 모드로 제외")
		await input_tap(world(target.position))
		var old_first: Vector2 = target.dir
		var old_second: Vector2 = refused.dir
		main.interaction_system.rotate_selected(PI / 4)
		ok("BF-17", not target.dir.is_equal_approx(old_first) and not refused.dir.is_equal_approx(old_second), "그룹 방향 함께 회전")
		await input_key(KEY_E)
		await input_key(KEY_UP)
		await input_key(KEY_ENTER)
		ok("BF-17", target.dir.dot(Vector2.UP) > 0.99 and refused.dir.dot(Vector2.UP) > 0.99 and main.phase == main.Phase.CHOOSE, "그룹 명시적 방향 편집·확정")
		main.interaction_system.select_all()
		var group_dirs := [target.dir, refused.dir]
		await input_key(KEY_E)
		await input_key(KEY_DOWN)
		await input_key(KEY_ESCAPE)
		ok("BF-17", target.dir == group_dirs[0] and refused.dir == group_dirs[1] and main.interaction_system.selected.size() == 2, "그룹 방향 취소는 원래 방향·선택 복원")
		main.interaction_system.set_additive_selection(false)
		main.interaction_system.clear_selection()
	await input_key(KEY_TAB)
	ok("BF-19", main.interaction_system.selected.size() == 1, "Tab 대상 순환")
	if not main.interaction_system.selected.is_empty():
		var selected_tower: Tower = main.interaction_system.selected[0]
		var before: Vector2 = selected_tower.position
		await input_key(KEY_RIGHT)
		ok("BF-19", selected_tower.position.x > before.x, "키보드로 선택 이동")
	await snap("05-keyboard-group")
	await reset_input_case()
	await input_key(KEY_2)
	await input_key(KEY_ENTER)
	ok("BF-19", main.towers.get_child_count() == 3 and main.picks_left == 1, "키보드만으로 카드 선택·새 설치 완료")
	await reset_input_case()
	await input_key(KEY_1)
	await input_key(KEY_TAB)
	await input_key(KEY_ENTER)
	ok("BF-19", target.m("pierce") == 1 and main.picks_left == 1, "키보드만으로 적용 대상 순환·강화 적용 완료")
	await reset_input_case()
	main.cards_system._set_cards_hidden(true)
	if phone:
		await touch(world(target.position), true)
		await touch_drag(world(main.viewport_system.core()))
	else:
		await mouse_button(world(target.position), true)
		await mouse_move(world(main.viewport_system.core()), true)
	var has_preview: bool = main.interaction_system.has_method("drag_preview")
	ok("BF-15", has_preview and main.interaction_system.dragging, "드래그 유효성 API 존재")
	if has_preview:
		var preview: Dictionary = main.interaction_system.drag_preview()
		ok("BF-15", not preview.get("valid", true) and preview.get("reason", "") != "", "손을 떼기 전 중앙 배치 불가 이유 제공")
	await snap("06-invalid-drag-preview")
	if phone:
		await touch(world(main.viewport_system.core()), false)
	else:
		await mouse_button(world(main.viewport_system.core()), false)
	ok("BF-15", target.position == Vector2(280, 300), "무효 드래그는 안전하게 원복")
