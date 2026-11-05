extends "res://tools/carry_check.gd"
var guidance_completed := 0
var dismiss_inspector_completed := false
var preview_completed := false
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
	await mouse_click(world(target.position))
	ok("UI-05", main.phase == main.Phase.AIM and main.interaction_system.moving == target, "드래그 다음 클릭 한 번으로 방향 편집")
	await key(KEY_ESCAPE)
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
			await mouse_move(card_center(1))
			ok("UI-32", main.card_dock.shown_tower == target and main.card_dock.preview_card().is_empty(), "선택한 오브젝트는 카드 호버보다 우선")
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
		ok("UI-32", main.interaction_system.selected.is_empty() and main.card_dock.inspected_tower == null, "Esc로 선택·인스펙터 해제")

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
	main.interaction_system._select_tower(target)
	target.add(Elem.POISON, 2)
	target.add(Elem.WATER, 2)
	await settle()
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
