extends "res://tools/carry_check.gd"
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
	main._hide_title()
	main.set_process(false)
	main.auto_start = false
	Meta.ui_scale = float(args[1])
	main._apply_ui_scale()
	await create_timer(0.2).timeout
	if which in ["all", "detail"]:
		await detail_case()
	if which in ["all", "ownership"]:
		await ownership_case()
	if which in ["all", "pause-input"]:
		await pause_input_case()
	if which in ["all", "direction"]:
		await direction_case()
	print("USABILITY case=%s failures=%d ui=%d" % [which, fails, ui_errors])
	quit(1 if fails > 0 or ui_errors > 0 else 0)

func detail_case() -> void:
	await fixture()
	target.position = Vector2(220, 300)
	main._set_cards_hidden(true)
	await settle()
	Input.emulate_mouse_from_touch = true
	await touch(world(target.position), true)
	await touch(world(target.position), false)
	main._process(4.0)
	await settle()
	ok("UI-16", main.card_dock.side.visible and main.detail_btn.is_visible_in_tree(), "터치 후 4초가 지나도 인스펙터·자세히 버튼 유지")
	await touch(main.detail_btn.get_global_rect().get_center(), true)
	await touch(main.detail_btn.get_global_rect().get_center(), false)
	ok("UI-16", main._tip_detail_on() and main.card_dock.shown_tower == target and main.card_dock.side.visible and main._ring_target() == target and main.card_dock.pic.detail, "헤더 자세히 터치는 대상 유지·상세 전환")
	await snap("object-detail")
	await touch(main.detail_btn.get_global_rect().get_center(), true)
	await touch(main.detail_btn.get_global_rect().get_center(), false)
	ok("UI-16", not main._tip_detail_on() and main.card_dock.shown_tower == target, "간단히로 복귀해도 대상 유지")

func ownership_case() -> void:
	await fixture()
	target.position = Vector2(220, 300)
	refused.position = Vector2(1060, 300)
	main._set_cards_hidden(true)
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
	ok("MP-07", main.selected == [target], "협동 Ctrl+A는 내 오브젝트만 선택")
	main.selected = [target, refused]
	var mine_origin := target.position
	await mouse_button(world(target.position), true)
	await mouse_move(world(target.position) + Vector2(80, -60), true)
	ok("MP-07", main.dragging and main.drag_group == [target] and refused.position == other_origin, "섞인 선택에서도 드래그 시작 시 소유권 재확인")
	await mouse_button(world(target.position), false)
	ok("MP-07", target.position != mine_origin and refused.position == other_origin, "내 것만 이동 확정, 친구 좌표 보존")
	main.selected.clear()
	main.mp_mode = ""

func pause_input_case() -> void:
	await fixture()
	var original_offer: Array = main.offer.duplicate(true)
	var original_rerolls: int = main.rerolls_left
	await key(KEY_P)
	for code in [KEY_S, KEY_Q, KEY_SPACE, KEY_1]:
		await key(code)
	main._on_skip()
	main._on_reroll()
	ok("UI-10", paused and main.phase == main.Phase.CHOOSE and main.picks_left == 2 and main.rerolls_left == original_rerolls and main.offer == original_offer and main.skip_left == 0, "정지 중 게임 단축키·직접 넘기기/새로고침 호출 차단")
	await key(KEY_M)
	ok("UI-10", paused, "정지 중 소리 조작은 정지를 풀지 않음")
	await key(KEY_P)
	await key(KEY_S)
	ok("UI-10", not paused and main.phase == main.Phase.READY and main.skip_left > 0 and main.bank_picks.size() == 2, "재개 후 같은 S 키로 정상 넘기기")

func direction_case() -> void:
	for folded in [false, true]:
		await fixture()
		target.position = Vector2(220, 300)
		await mouse_click(card_center(1))
		await key(KEY_ESCAPE)
		main._set_card_detail(true)
		main._set_cards_hidden(folded)
		await mouse_click(world(target.position))
		await mouse_click(main.card_dock.direction_btn.get_global_rect().get_center())
		await key(KEY_ESCAPE)
		ok("UI-05", main.cards_hidden == folded and main.selected == [target], "방향 취소는 카드 접힘·오브젝트 선택 복원: %s" % folded)
		await mouse_click(main.card_dock.direction_btn.get_global_rect().get_center())
		await mouse_click(world(Vector2(650, 240)))
		ok("UI-05", main.phase == main.Phase.CHOOSE and main.selected.is_empty() and not main.card_dock.side.visible and main.card_dock.preview_card().is_empty() and main.tap_sel == -1 and main.cards_hidden == folded, "방향 확정은 이전 카드 미리보기 없이 종료: %s" % folded)
		await snap("direction-finished-%s" % folded)
