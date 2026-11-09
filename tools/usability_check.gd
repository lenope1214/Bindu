extends "res://tools/carry_check.gd"
var guidance_completed := 0
var dismiss_inspector_completed := false
var preview_completed := false
var lanes_completed := false
## 사용성 회귀: 격리 사본·가상 입력으로 실제 버튼과 전장 입력 경로를 함께 확인한다.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(100).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args.size() > 2 and args[2] == "phone"
	var which := args[3] if args.size() > 3 else "all"
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
	main.progression_system._hide_title()
	main.set_process(false)
	main.auto_start = false
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	await create_timer(0.2).timeout
	ok("UI-37", not main.card_dock.pic.preview_visible and not main.card_dock.pic.attack_preview.visible, "새 정보창은 공격 예시를 접고 수치를 먼저 표시")
	if which == "focused-preview":
		await focused_preview_case()
		ok("UI-37", preview_completed, "단일 오브젝트 미리보기 검사 완료")
	if which == "lane-warning":
		await lane_warning_case()
		ok("WAVE-14", lanes_completed, "길목 경고·카드 단계 새 방향 검사 완료")
	if which == "unified-preview":
		await unified_preview_case()
		ok("UI-37", preview_completed, "최종 공격 미리보기 검사 완료")
	if which == "dismiss-inspector":
		await dismiss_inspector_case()
		ok("UI-32", dismiss_inspector_completed, "인스펙터 닫기·재활성화 입력 검사 완료")
	if which in ["all", "guidance"]:
		await guidance_case()
		ok("TUT-03", guidance_completed == 2, "마우스·첫 터치 안내 우선순위 검사 완료")
	if which in ["all", "inspector"]:
		await inspector_case()
	if which in ["all", "detail"]:
		await detail_case()
	if which in ["all", "ownership"]:
		await ownership_case()
	if which in ["all", "pause-input"]:
		await pause_input_case()
	if which in ["all", "wave-escape"]:
		await wave_escape_case()
	if which in ["all", "preview-opt-in"]:
		await preview_opt_in_case()
	if which in ["all", "direction"]:
		await direction_case()
	if which in ["all", "pause-inspector"]:
		await pause_inspector_case()
	if which in ["all", "overlap"]:
		await overlap_case()
	if which in ["all", "hud"]:
		await hud_case()
	if which in ["all", "perk"]:
		await perk_case()
	print("USABILITY case=%s failures=%d ui=%d" % [which, fails, ui_errors])
	quit(1 if fails > 0 or ui_errors > 0 else 0)

func detail_case() -> void:
	await fixture()
	target.position = Vector2(220, 300)
	main.cards_system._set_cards_hidden(true)
	await settle()
	Input.emulate_mouse_from_touch = true
	await touch(world(target.position), true)
	await touch(world(target.position), false)
	main.frame_system._process(4.0)
	await settle()
	ok("UI-16", main.card_dock.side.visible and main.detail_btn.is_visible_in_tree(), "터치 후 4초가 지나도 인스펙터·자세히 버튼 유지")
	await touch(main.detail_btn.get_global_rect().get_center(), true)
	await touch(main.detail_btn.get_global_rect().get_center(), false)
	ok("UI-16", main.field_view_system._tip_detail_on() and main.card_dock.shown_tower == target and main.card_dock.side.visible and main.field_view_system._ring_target() == target and main.card_dock.pic.detail, "헤더 자세히 터치는 대상 유지·상세 전환")
	await snap("object-detail")
	await touch(main.detail_btn.get_global_rect().get_center(), true)
	await touch(main.detail_btn.get_global_rect().get_center(), false)
	ok("UI-16", not main.field_view_system._tip_detail_on() and main.card_dock.shown_tower == target, "간단히로 복귀해도 대상 유지")

func ownership_case() -> void:
	await fixture()
	target.position = Vector2(220, 300)
	refused.position = Vector2(1060, 300)
	main.cards_system._set_cards_hidden(true)
	main.mp_mode = "coop"
	main.mp.my_id = 1
	target.owner_id = 1
	refused.owner_id = 2
	var other_origin := refused.position
	var all := InputEventKey.new()
	all.keycode = KEY_A
	all.ctrl_pressed = true
	all.pressed = true
	VirtualInput.send(all)
	await settle()
	ok("MP-07", main.interaction_system.selected == [target], "협동 Ctrl+A는 내 오브젝트만 선택")
	main.interaction_system.selected = [target, refused]
	var mine_origin := target.position
	await mouse_button(world(target.position), true)
	await mouse_move(world(target.position) + Vector2(80, -60), true)
	ok("MP-07", main.interaction_system.dragging and main.interaction_system.drag_group == [target] and refused.position == other_origin, "섞인 선택에서도 드래그 시작 시 소유권 재확인")
	await mouse_button(world(target.position), false)
	ok("MP-07", target.position != mine_origin and refused.position == other_origin, "내 것만 이동 확정, 친구 좌표 보존")
	main.interaction_system.selected.clear()
	main.mp_mode = ""
	main.mp_bar.hide()
	main.mp_act.hide()  # 주입한 협동 fixture의 전용 버튼도 정리한다. 실제 연결 종료 UI 검사는 별도 native 도구가 맡는다.

func pause_input_case() -> void:
	await fixture()
	var original_offer: Array = main.offer.duplicate(true)
	var original_rerolls: int = main.rerolls_left
	await key(KEY_P)
	for code in [KEY_S, KEY_Q, KEY_SPACE, KEY_1]:
		await key(code)
	main.run_flow_system._on_skip()
	main.cards_system._on_reroll()
	ok("UI-10", paused and main.phase == main.Phase.CHOOSE and main.picks_left == 2 and main.rerolls_left == original_rerolls and main.offer == original_offer and main.skip_left == 0, "정지 중 게임 단축키·직접 넘기기/새로고침 호출 차단")
	await key(KEY_M)
	ok("UI-10", paused, "정지 중 소리 조작은 정지를 풀지 않음")
	await key(KEY_P)
	await key(KEY_S)
	ok("UI-10", not paused and main.phase == main.Phase.READY and main.skip_left > 0 and main.bank_picks.size() == 2, "재개 후 같은 S 키로 정상 넘기기")

func wave_escape_case() -> void:
	for armed in [false, true]:
		await fixture()
		target.position = Vector2(220, 300)
		main.cards_system._enter_ready()
		main.phase = main.Phase.WAVE
		main.wave_active = true
		main.to_spawn = 1
		main.spawn_timer = 10000.0
		main.abilities_system._skills_new_run(0)
		Meta.skill_auto = false
		_orb(Vector2(650, 500), 1e6)
		await mouse_click(world(target.position))
		ok("UI-10", main.interaction_system.selected == [target] and main.card_dock.side.visible, "Esc 우선순위 검사 전에 실제 전장 선택·정보 열기")
		if armed:
			await activate(main.skill_btns[0])
			ok("UI-10", main.skill_arm == main.skill_ids[0], "실제 기술 버튼으로 조준 대기 진입")
		var before_build: Dictionary = target.to_save().duplicate(true)
		var before_hp: float = main.orbs.get_child(0).hp
		await key(KEY_ESCAPE)
		ok("UI-10", paused and main.pause_box.is_visible_in_tree() and main.interaction_system.selected == [target] and target.to_save() == before_build and main.orbs.get_child(0).hp == before_hp, "WAVE의 첫 Esc는 선택·조준보다 먼저 즉시 정지: 조준=%s" % armed)
		await key(KEY_ESCAPE)
		ok("UI-10", not paused and main.phase == main.Phase.WAVE and main.interaction_system.selected == [target], "다음 Esc로 전투 재개·선택 유지: 조준=%s" % armed)
		if armed:
			await activate(main.skill_btns[0])
			ok("UI-10", main.skill_arm == "", "조준 취소는 같은 기술 버튼으로 명시적으로 실행")

func activate(control: Control) -> void:
	ok("UI-37", control.is_visible_in_tree(), "조작할 버튼이 실제 화면에 표시됨: " + str(control.name))
	var at := control.get_global_rect().get_center()
	if phone:
		await touch(at, true)
		await touch(at, false)
	else:
		await mouse_click(at)

func show_attack_example() -> void:
	var pic: InfoPanel = main.card_dock.pic
	if not pic.preview_visible:
		await activate(main.card_dock.preview_btn)
	ok("UI-37", pic.preview_visible and pic.attack_preview.is_visible_in_tree(), "공격 예시 버튼으로 실제 공용 전투 미리보기 펼침")

func reveal_attack_example() -> void:
	var preview: AttackPreview = main.card_dock.pic.attack_preview
	var scroll: ScrollContainer = main.card_dock.scroll
	for i in 24:
		var r := preview.get_global_rect()
		var view := scroll.get_global_rect()
		if r.intersection(view).size.y >= minf(r.size.y, view.size.y) * 0.9:
			break
		var wheel := InputEventMouseButton.new()
		wheel.position = view.get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if r.get_center().y > view.get_center().y else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		VirtualInput.send(wheel)
		wheel = wheel.duplicate()
		wheel.pressed = false
		VirtualInput.send(wheel)
		await settle()
	var actual := preview.get_global_rect()
	var visible := scroll.get_global_rect()
	ok("UI-37", actual.intersection(visible).size.y >= minf(actual.size.y, visible.size.y) * 0.9, "핵심 수치 아래 공격 예시도 실제 스크롤로 화면에 드러내 읽을 수 있음")

func preview_opt_in_case() -> void:
	await fixture()
	target.position = Vector2(220, 300)
	await activate(main.card_dock.focus_btn)
	await mouse_click(world(target.position))
	var pic: InfoPanel = main.card_dock.pic
	var preview: AttackPreview = pic.attack_preview
	var before_build: Dictionary = target.to_save().duplicate(true)
	var summary: PackedStringArray = pic.summary_lines(target)
	ok("UI-37", pic.is_visible_in_tree() and pic.tower == target and not pic.preview_visible and not preview.is_visible_in_tree() and summary.size() == 3 and "기본 공격 계산" in summary[0] and summary[1] != "", "오브젝트 선택 시 공격 수치·사거리·조준 정보를 예시보다 먼저 읽음")
	var folded_height: float = pic.custom_minimum_size.y
	await snap("preview-default-numbers")
	await show_attack_example()
	ok("UI-37", preview.position.y >= pic.tower_header_h() + 150.0 and pic.custom_minimum_size.y >= folded_height + AttackPreview.HEIGHT and preview.source == target and is_instance_valid(preview.clone), "펼친 예시는 핵심 수치 아래·실제 선택 오브젝트의 격리 전투")
	var before_elapsed: float = preview.elapsed
	await create_timer(0.12).timeout
	await settle()
	ok("UI-37", preview.elapsed > before_elapsed and target.to_save() == before_build, "예시 재생은 실제 전투 경로를 진행하고 원본 빌드는 보존")
	await snap("preview-opened-by-button")
	await activate(main.card_dock.preview_btn)
	var stopped_elapsed: float = preview.elapsed
	await create_timer(0.08).timeout
	await settle()
	ok("UI-37", not pic.preview_visible and not preview.is_visible_in_tree() and preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and is_equal_approx(preview.elapsed, stopped_elapsed) and is_equal_approx(pic.custom_minimum_size.y, folded_height), "다시 접으면 예시 시뮬레이션·렌더 정지, 수치 높이 복원")

func direction_case() -> void:
	for select_first in [false, true]:
		await fixture()
		target.position = Vector2(220, 300)
		main.cards_system._set_cards_hidden(true)
		if select_first:
			await mouse_click(world(target.position))
		var original_dir: Vector2 = target.dir
		await mouse_move(world(target.position))
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		right.position = world(target.position)
		VirtualInput.send(right)
		await settle()
		ok("UI-05", main.phase == main.Phase.AIM and main.interaction_system.moving == target and main.interaction_system.aim_right, "우클릭 즉시 방향 편집: 선택=%s" % select_first)
		await mouse_move(world(target.position + Vector2(0, -120)))
		right.pressed = false
		right.position = world(target.position + Vector2(0, -120))
		VirtualInput.send(right)
		await settle()
		ok("UI-05", main.phase == main.Phase.CHOOSE and main.interaction_system.moving == null and not target.dir.is_equal_approx(original_dir) and target.dir.dot(Vector2.UP) > 0.99, "우클릭 끌기 확정: 선택=%s" % select_first)
	await fixture()
	target.position = Vector2(220, 300)
	main.cards_system._set_cards_hidden(true)
	await settle()
	await mouse_button(world(target.position), true)
	await mouse_move(world(target.position) + Vector2(80, -60), true)
	await mouse_button(world(target.position), false)
	ok("UI-05", main.interaction_system.selected == [target] and main.card_dock.inspected_tower == target, "마우스 드래그 후 선택·상세 유지")
	var after_drag_dir: Vector2 = target.dir
	await mouse_click(world(target.position))
	ok("UI-05", main.phase == main.Phase.CHOOSE and main.interaction_system.moving == null and main.interaction_system.selected == [target] and target.dir == after_drag_dir, "드래그 뒤 같은 오브젝트를 다시 클릭해도 방향·선택 유지")
	await key(KEY_E)
	ok("UI-05", main.phase == main.Phase.AIM and main.interaction_system.moving == target, "E로 선택한 오브젝트 방향 편집을 명시적으로 시작")
	await key(KEY_ESCAPE)
	ok("UI-05", main.phase == main.Phase.CHOOSE and target.dir == after_drag_dir and main.interaction_system.selected == [target], "E 편집 취소는 기존 방향·선택 복원")
	main.cards_system._enter_ready()
	var args := OS.get_cmdline_user_args()
	main.touch_ui = phone or (args.size() > 2 and args[2] == "touch")
	await settle()
	for expanded in [false, true]:
		main.bar_open = expanded
		await settle()
		var hint_rect: Rect2 = main.hint.get_global_rect()
		for button: Button in [main.start_btn, main.skip_btn, main.skip_n_btn]:
			ok("UI-35", not hint_rect.intersects(button.get_global_rect()) and hint_rect.end.y < button.get_global_rect().position.y, "선택 안내와 웨이브 버튼 분리: %s %s" % [expanded, button.text])
		# 상태 칸·버튼은 위에서 직접 검사. 전체 UI 감사는 기존 배지/제목 진단과 분리한다.
		RenderingServer.force_draw()
		main.get_viewport().get_texture().get_image().save_png(output.path_join("selected-ready-%s.png" % expanded))
	for folded in [false, true]:
		await fixture()
		target.position = Vector2(220, 300)
		await mouse_click(card_center(1))
		await key(KEY_ESCAPE)
		main.cards_system._set_card_detail(true)
		main.cards_system._set_cards_hidden(folded)
		await mouse_click(world(target.position))
		await mouse_click(main.card_dock.direction_btn.get_global_rect().get_center())
		await key(KEY_ESCAPE)
		ok("UI-05", main.cards_hidden == folded and main.interaction_system.selected == [target], "방향 취소는 카드 접힘·오브젝트 선택 복원: %s" % folded)
		await mouse_click(main.card_dock.direction_btn.get_global_rect().get_center())
		await mouse_click(world(Vector2(650, 240)))
		ok("UI-05", main.phase == main.Phase.CHOOSE and main.interaction_system.selected.is_empty() and not main.card_dock.side.visible and main.card_dock.preview_card().is_empty() and main.tap_sel == -1 and main.cards_hidden == folded, "방향 확정은 이전 카드 미리보기 없이 종료: %s" % folded)
		await snap("direction-finished-%s" % folded)

func pause_inspector_case() -> void:
	await fixture()
	target.position = Vector2(220, 300)
	for e in Elem.ALL:
		target.add(e, 1)
	target.eff = target.eff_now()
	main.cards_system._set_cards_hidden(true)
	await mouse_move(world(target.position))
	await key(KEY_P)
	ok("UI-07", paused and main.card_dock.side.visible and main.card_dock.side.z_index > main.pause_dim.z_index and not main.card_dock.direction_btn.visible, "일시정지 중에도 인스펙터를 메뉴 위에서 읽기 전용 표시")
	Input.emulate_mouse_from_touch = true
	var at: Vector2 = main.detail_btn.get_global_rect().get_center()
	# 마우스 호버에서 터치 열람으로 바꾼 뒤 실제 헤더 버튼을 누른다.
	main.touch_ui = true
	await settle()
	at = main.detail_btn.get_global_rect().get_center()
	var clicks := [0]
	var counted := func(): clicks[0] += 1
	main.detail_btn.pressed.connect(counted)
	await touch(at, true)
	await touch(at, false)
	ok("UI-07", paused and clicks[0] == 1 and main.field_view_system._tip_detail_on() and main.card_dock.shown_tower == target, "정지 중 터치 자세히도 대상을 유지")
	main.detail_btn.pressed.disconnect(counted)
	var before: int = main.card_dock.scroll.scroll_vertical
	for i in 10:
		var wheel := InputEventMouseButton.new()
		wheel.position = main.card_dock.scroll.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		VirtualInput.send(wheel)
		wheel = wheel.duplicate()
		wheel.pressed = false
		VirtualInput.send(wheel)
		await settle()
	ok("UI-07", main.card_dock.scroll.scroll_vertical > before and paused, "정지 중 상세 스크롤 가능")
	await snap("paused-inspector")
	await key(KEY_P)
	await mouse_move(world(Vector2(650, 240)))
	await mouse_click(world(target.position))
	var origin := target.position
	await mouse_button(world(target.position), true)
	await mouse_move(world(target.position) + Vector2(80, -60), true)
	await key(KEY_P)
	await mouse_button(world(target.position), false)
	ok("UI-07", paused and target.position == origin and main.interaction_system.press_t == null, "진행 중 드래그도 정지하면 원위치로 취소")
	await key(KEY_P)

func overlap_tip(rect: Rect2) -> void:
	main.tip_rects.clear()
	main.tip_rects.append([main.ui_root.get_global_transform().affine_inverse() * rect, [["겹침 정보", Color.WHITE]]])
	main.tip_pin = -1

func overlap_case() -> void:
	for touch_mode in [false, true]:
		for run in 3:
			await fixture()
			var button: Button = main.card_dock.focus_btn
			var at := button.get_global_rect().get_center()
			target.position = main.get_canvas_transform().affine_inverse() * at
			var count := [0]
			var pressed := func(): count[0] += 1
			button.pressed.connect(pressed)
			overlap_tip(button.get_global_rect())
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
			ok("UI-28", count[0] == 1 and main.tip_pin == -1 and main.interaction_system.selected.is_empty() and main.interaction_system.press_t == null, "버튼·배지·오브젝트 겹침은 버튼 한 번만: touch=%s 회차=%d" % [touch_mode, run])
			button.pressed.disconnect(pressed)
			await settle()
	for emulate in [true, false]:
		for run in 3:
			await fixture()
			target.position = Vector2(220, 300)
			var at := world(target.position)
			overlap_tip(Rect2(at - Vector2(30, 18), Vector2(60, 36)))
			Input.emulate_mouse_from_touch = emulate
			var event := InputEventScreenTouch.new()
			event.position = at
			event.pressed = true
			VirtualInput.send(event)
			event = event.duplicate()
			event.pressed = false
			VirtualInput.send(event)
			ok("UI-28", main.tip_pin == 0 and main.interaction_system.selected.is_empty() and main.interaction_system.press_t == null and not main.interaction_system.info_mouse_capture and main.interaction_system.info_touch_capture == -1, "배지·오브젝트 겹침은 배지만: emulate=%s 회차=%d" % [emulate, run])
			await settle()
	Input.emulate_mouse_from_touch = true
	await fixture()
	main.cards_system._set_cards_hidden(true)
	target.position = Vector2(220, 300)
	await settle()
	var origin := target.position
	await mouse_button(world(target.position), true)
	await mouse_move(main.card_dock.focus_btn.get_global_rect().get_center(), true)
	await mouse_button(main.card_dock.focus_btn.get_global_rect().get_center(), false)
	ok("UI-28", target.position == origin and main.phase == main.Phase.CHOOSE and main.interaction_system.press_t == null, "전장 드래그를 버튼 위에서 놓으면 이동 취소")
	await fixture()
	await mouse_click(card_center())
	var cancel_at: Vector2 = main.cancel_btn.get_global_rect().get_center()
	target.position = main.get_canvas_transform().affine_inverse() * cancel_at
	await mouse_click(cancel_at)
	ok("UI-28", main.phase == main.Phase.CHOOSE and main.picks_left == 2 and target.m("pierce") == 0 and main.interaction_system.selected.is_empty(), "카드 취소 버튼과 뒤 대상이 겹쳐도 취소만 실행")

	main.help_label.visible = true
	await settle()
	var outside: Vector2 = main.ui_root.get_global_transform() * Vector2(4, 100)
	overlap_tip(Rect2(outside - Vector2(8, 8), Vector2(16, 16)))
	await mouse_click(outside)
	ok("UI-28", not main.help_label.visible and main.interaction_system.selected.is_empty(), "모달 밖 클릭은 창만 닫고 뒤 정보·전장을 누르지 않음")

func hud_case() -> void:
	for touch_mode in [false, true]:
		await fixture()
		main.cards_system._set_cards_hidden(true)
		await settle()
		var at: Vector2 = main.hud.get_global_rect().position + Vector2(20, main.hud.get_global_rect().size.y / 2.0)
		target.position = main.get_canvas_transform().affine_inverse() * at
		main.tip_pin = -1
		if touch_mode:
			Input.emulate_mouse_from_touch = true
			await touch(at, true)
			await touch(at, false)
		else:
			await mouse_click(at)
		ok("UI-36", main.interaction_system.selected == [target] and main.tip_pin == -1 and main.phase == main.Phase.CHOOSE, "점수 줄 밑 오브젝트는 단독 선택하고 칩은 함께 누르지 않음: %s" % touch_mode)

func perk_case() -> void:
	await fixture()
	main.perk_offer.assign(main.PERKS.filter(func(pk): return pk["id"] != "coin").slice(0, 3))
	main.perks_system._show_perks()
	main.banner_t = 0
	main.banner_queue.clear()
	await settle()
	Input.emulate_mouse_from_touch = true
	var at: Vector2 = main.choice_box.get_child(0).get_global_rect().get_center()
	var before: Dictionary = main.perks.duplicate(true)
	await touch(at, true)
	await create_timer(0.55).timeout
	await settle()
	ok("UI-16", main.card_dock.side.visible and main.perks_system.perk_peek != null and main.perks == before, "특성 길게 누르기는 적용 없이 상세 열람")
	await snap("perk-long-press")
	await touch(at, false)
	ok("UI-16", main.perk_mode and main.perks == before, "길게 누른 손을 떼어도 특성을 적용하지 않음")
	await touch(at, true)
	await touch(at, false)
	ok("UI-16", main.perks != before, "이후 짧은 터치는 특성 한 번 적용")

func inspector_case() -> void:
	for stage in [main.Phase.CHOOSE, main.Phase.READY, main.Phase.WAVE]:
		await fixture()
		target.position = Vector2(220, 300)
		refused.position = Vector2(420, 300)
		main.phase = stage
		if stage == main.Phase.WAVE:
			_orb(Vector2(650, 500), 1e6)  # 빈 전투가 즉시 끝나 단계 검증이 무의미해지지 않게
		await mouse_click(world(target.position))
		ok("UI-32", main.phase == stage and main.interaction_system.selected == [target] and main.card_dock.shown_tower == target, "선택한 상세 유지: %s" % stage)
		if stage == main.Phase.CHOOSE:
			main.cards_system._set_card_detail(true)
			await settle()  # 상세 전환이 카드 노드를 다시 만들므로 새 버튼의 실제 레이아웃을 기다린다.
			await mouse_move(card_center(1))
			ok("UI-32", main.card_dock.pic.mode == "card" and main.card_dock.preview_card() == main.offer[1] and main.interaction_system.selected == [target] and main.picks_left == 2, "실제 카드 호버는 선택을 지우지 않고 카드 비교를 우선 표시·미소비")
			await mouse_move(main.card_dock.side.get_global_rect().get_center())
			ok("UI-32", main.card_dock.pic.mode == "card" and main.card_dock.preview_card() == main.offer[1] and main.interaction_system.selected == [target], "카드에서 상세 패널로 옮겨도 같은 카드 비교 유지")
			await mouse_move(world(Vector2(650, 240)))
			ok("UI-32", main.card_dock.shown_tower == target and main.card_dock.preview_card().is_empty() and main.interaction_system.selected == [target], "카드·상세 호버를 벗어나면 선택 오브젝트 정보 복귀")
		for run in 3:
			await mouse_move(world(refused.position))
			ok("UI-32", main.card_dock.shown_tower == refused and main.card_dock.inspected_tower == target and main.interaction_system.selected == [target], "다른 오브젝트 호버는 임시 표시: %s/%s" % [stage, run])
			await mouse_move(world(Vector2(650, 240)))
			ok("UI-32", main.card_dock.shown_tower == target, "호버 이탈 후 선택 상세 복귀: %s/%s" % [stage, run])
		await key(KEY_P)
		await mouse_move(world(refused.position))
		ok("UI-32", paused and main.card_dock.shown_tower == refused, "정지 중에도 임시 호버 표시")
		await mouse_move(world(Vector2(650, 240)))
		ok("UI-32", main.card_dock.shown_tower == target, "정지 중 호버 이탈도 선택 상세 복귀")
		await key(KEY_P)
		RenderingServer.force_draw()
		main.get_viewport().get_texture().get_image().save_png(output.path_join("inspector-selected-%s.png" % stage))
		await key(KEY_ESCAPE)
		if stage == main.Phase.WAVE:
			ok("UI-32", paused and main.pause_box.is_visible_in_tree() and main.interaction_system.selected == [target] and main.card_dock.inspected_tower == target, "WAVE 첫 Esc는 선택 해제보다 일시정지 우선")
			await key(KEY_ESCAPE)
			ok("UI-32", not paused and main.phase == main.Phase.WAVE and main.card_dock.inspected_tower == target, "WAVE Esc 재개 후 선택한 정보 복원")
			await activate(main.card_dock.close_btn)
			ok("UI-32", main.interaction_system.selected.is_empty() and main.card_dock.inspected_tower == null and not main.card_dock.side.visible, "WAVE 선택 해제는 정보창 닫기 버튼으로 실행")
		else:
			ok("UI-32", not paused and main.interaction_system.selected.is_empty() and main.card_dock.inspected_tower == null, "쉬는 시간 Esc는 선택·인스펙터 해제")

func guidance_case() -> void:
	for touch_mode in [false, true]:
		await fixture()
		main.cards_system._enter_ready()
		await mouse_move(world(Vector2(650, 440)))
		Meta.guide_on = true
		main.guide_lines.assign(["방해 구체가 와요. 오브젝트를 나눠 배치하세요."])
		main.guide_t = -1
		main.onboarding_system.guide_topic = "jam"
		await settle()
		ok("TUT-03", main.guide_more.visible and main.guide_label.position.y < 140.0, "처음 안내는 HUD 바로 아래에 표시")
		var at: Vector2 = main.guide_more.get_global_rect().get_center()
		target.position = main.get_canvas_transform().affine_inverse() * at
		await settle()
		if touch_mode:
			Input.emulate_mouse_from_touch = true
			await touch(at, true)
			await touch(at, false)
		else:
			await mouse_click(at)
		ok("TUT-03", main.interaction_system.selected == [target] and not paused and not main.tut.visible and not main.guide_more.visible, "더 알아보기 아래 오브젝트는 첫 입력으로 선택: 터치=%s" % touch_mode)
		RenderingServer.force_draw()
		main.get_viewport().get_texture().get_image().save_png(output.path_join("guide-object-priority-%s.png" % touch_mode))
		guidance_completed += 1
	Meta.guide_on = false
	main.guide_lines.clear()

func dismiss_inspector_case() -> void:
	await fixture()
	main.cards_system._set_card_detail(true)
	main.interaction_system._select_tower(target)
	await settle()
	if phone:
		var at: Vector2 = main.card_dock.close_btn.get_global_rect().get_center()
		await touch(at, true)
		await touch(at, false)
	else:
		await mouse_click(main.card_dock.close_btn.get_global_rect().get_center())
	VirtualInput.move(world(refused.position))
	await settle()
	ok("UI-32", main.card_dock.inspector_dismissed and not main.card_dock.side.visible, "X 후 다른 오브젝트 호버에도 닫힘 유지")
	await mouse_click(main.card_detail_btn.get_global_rect().get_center())
	await settle()
	ok("UI-32", not main.card_dock.inspector_dismissed and Meta.card_detail, "자세히 버튼 한 번으로 다시 활성화")
	main.interaction_system._select_tower(target)
	await settle()
	await mouse_click(main.card_dock.close_btn.get_global_rect().get_center())
	var event := InputEventKey.new()
	event.keycode = KEY_Z
	event.pressed = true
	VirtualInput.send(event)
	await settle()
	ok("UI-32", not main.card_dock.inspector_dismissed and Meta.card_detail, "Z 한 번으로 다시 활성화")
	dismiss_inspector_completed = true

func unified_preview_case() -> void:
	await fixture()
	target.position = Vector2(220, 300)
	target.add(Elem.POISON, 2)
	target.add(Elem.WATER, 2)
	main.cards_system._set_cards_hidden(true)
	await mouse_click(world(target.position))
	await settle()
	await show_attack_example()
	var preview: AttackPreview = main.card_dock.pic.attack_preview
	var tested := 0
	for pat in Pat.ALL_IDS:
		target.pattern = pat
		preview.configure(target)
		for frame in 90: preview.advance(1.0 / 30.0)
		tested += 1
		ok("UI-37", is_instance_valid(preview.clone), "실제 공격 미리보기: " + pat)
	target.pattern = "shot"
	for reaction in Elem.REACTIONS:
		target.elements = {reaction["a"]: 2, reaction["b"]: 2}
		target.order.assign([reaction["a"], reaction["b"]])
		target.eff = target.eff_now()
		preview.configure(target)
		for frame in 150: preview.advance(1.0 / 30.0)
		ok("UI-37", is_instance_valid(preview.clone), "실제 조합 미리보기: " + str(reaction["id"]))
	target.elements = {Elem.WATER: 3, Elem.POISON: 2}
	target.order.assign([Elem.WATER, Elem.POISON])
	target.eff = target.eff_now()
	preview.configure(target)
	for frame in 24: preview.advance(1.0 / 30.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(output.path_join("unified-preview.png"))
	preview_completed = tested == Pat.ALL_IDS.size()

func lane_warning_case() -> void:
	await fixture()
	target.position = main.viewport_system.center() + Vector2(120, 0)
	target.dir = Vector2.RIGHT
	refused.position = target.position
	refused.dir = Vector2.RIGHT
	main.lanes.assign([0.0, PI])
	main.waves_system.mark_new_angles([0.0])
	await settle()
	await process_frame
	RenderingServer.force_draw()
	var badges: Array = main.field_overlay_system.info_rects
	ok("WAVE-14", main.phase == main.Phase.CHOOSE and badges.any(func(b): return "새 진입" in b[0] and "범위 밖" in b[0]), "카드 선택 중 새 진입·범위 밖을 해당 길목 배지로 표시")
	main.get_viewport().get_texture().get_image().save_png(output.path_join("lane-warning.png"))
	main.lanes.assign([0.0, TAU / 6, TAU / 3, PI, TAU * 2 / 3, TAU * 5 / 6])
	main.waves_system.mark_new_angles([0.0])
	await settle()
	RenderingServer.force_draw()
	var rects: Array = main.field_overlay_system.info_rects.filter(func(b): return str(b[0]).begins_with("배지"))
	var clear := rects.size() == 6
	var safe := Rect2(Vector2.ZERO, main.ui_root.size)
	var cards: Rect2 = main.ui_root.get_global_transform().affine_inverse() * main.choice_box.get_global_rect()
	for i in rects.size():
		clear = clear and safe.encloses(rects[i][1]) and not cards.intersects(rects[i][1])
		for j in range(i + 1, rects.size()): clear = clear and not rects[i][1].intersects(rects[j][1])
	ok("WAVE-14", clear, "여섯 길목 경고도 카드·다른 배지·화면 밖을 피함")
	main.get_viewport().get_texture().get_image().save_png(output.path_join("lane-warning-six.png"))
	main.cards_system._enter_ready()
	await settle()
	var start_at: Vector2 = main.start_btn.get_global_rect().get_center()
	if phone:
		await touch(start_at, true)
		await touch(start_at, false)
	else:
		await mouse_click(start_at)
	ok("WAVE-14", main.phase == main.Phase.WAVE, "범위 밖 길목이 있어도 시작 버튼으로 진행")
	lanes_completed = true

func focused_preview_case() -> void:
	await fixture()
	main.cards_system._enter_ready()
	refused.position = target.position + Vector2(35, 10)
	for e in [Elem.POISON, Elem.FIRE, Elem.ELECTRIC, Elem.TIME]: target.add(e, 2)
	target.pattern = "spray"
	await mouse_click(world(target.position))
	await settle()
	await show_attack_example()
	var pic: InfoPanel = main.card_dock.pic
	var preview: AttackPreview = pic.attack_preview
	preview.set_process(false)
	for frame in 240: preview.advance(1.0 / 60.0)
	var hidden := true
	for peer in preview.world.towers.get_children():
		if peer != preview.clone: hidden = hidden and not peer.visible and peer.dealt == 0.0
	ok("UI-37", hidden and preview.clone.side_n == 0, "주변 오브젝트·공격·보조 공격은 숨김")
	ok("UI-37", pic.tower_header_h() >= 90.0 and preview.position.y >= pic.tower_header_h() + 150.0, "다섯 속성 줄바꿈과 핵심 수치를 펼친 공격 예시보다 먼저 표시")
	var lowest := 5
	for frame in 720:
		preview.advance(1.0 / 60.0)
		if frame % 60 == 0:
			var live: int = preview.world.orbs.get_children().filter(func(o): return not o.is_queued_for_deletion()).size()
			lowest = mini(lowest, live)
	ok("UI-37", lowest > 0 and preview.clone.dealt > 0.0 and preview.cycle > 1, "적 명중과 표적 보충이 계속 이어짐")
	var pos := target.position
	target.position = Vector2(Meta.FIELD.x - 25, 300)
	target.dir = Vector2.RIGHT
	preview.configure(target)
	for frame in 120: preview.advance(1.0 / 60.0)
	ok("UI-37", preview.clone.dealt > 0.0, "전장 바깥을 향한 오브젝트도 예시 표적 명중을 보여 줌")
	target.position = pos
	preview.configure(target)
	for frame in 60: preview.advance(1.0 / 60.0)
	await reveal_attack_example()
	await process_frame
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(output.path_join("focused-preview.png"))
	preview_completed = true
