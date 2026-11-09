extends "res://tools/carry_check.gd"
## 공통 카드 읽기·정지·편집 UI의 사용자 입력 검증.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args.size() > 2 and args[2] == "phone"
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
	await fixture()
	main.touch_ui = phone
	main.run_id = "core-usability-check"
	ok("BF-02", main.card_dock.has_method("read_card"), "소비 없는 카드 읽기 경로")
	var read_button: Button = main.choice_box.get_child(0).get_node_or_null("ReadCard")
	ok("BF-02", read_button != null, "카드마다 명시적 정보 버튼")
	if read_button != null:
		await click_or_touch(read_button.get_global_rect().get_center())
		ok("BF-02", main.phase == main.Phase.CHOOSE and main.picks_left == 2 and main.card_dock.side.visible, "정보 버튼은 횟수·선택 상태를 소비하지 않음")
		await snap("read-card")
		await key(KEY_P)
		main.card_dock.use_btn.pressed.emit()
		await click_or_touch(main.card_dock.use_btn.get_global_rect().get_center())
		ok("BF-01", paused and main.phase == main.Phase.CHOOSE and main.picks_left == 2, "정지 중 정보창의 카드 들기도 직접·가상 입력 모두 차단")
		await key(KEY_P)
		await click_or_touch(main.card_dock.close_btn.get_global_rect().get_center())
		ok("BF-02", main.choice_box.visible and main.picks_left == 2, "읽기 닫으면 같은 카드 복원")
	main.bar_open = false
	await settle()
	ok("BF-34", main.pause_btn.is_visible_in_tree() and main.pause_btn.get_parent() != main.bar_box, "접힌 설정과 독립적인 즉시 정지")
	await click_or_touch(main.pause_btn.get_global_rect().get_center())
	ok("BF-34", paused, "한 번의 입력으로 정지")
	await click_or_touch(main.pause_btn.get_global_rect().get_center())
	ok("BF-34", not paused, "같은 버튼으로 재개")
	await fixture()
	main.picks_left = 1
	var before: int = target.m("pierce")
	await click_or_touch(card_center())
	await click_or_touch(world(target.position))
	if main.cards_system.has_method("undo_edit"):
		var changed: bool = main.cards_system.call("undo_edit")
		ok("BF-05", changed and main.phase == main.Phase.CHOOSE and main.picks_left == 1 and main.towers.get_children().all(func(t): return t.m("pierce") == before), "마지막 카드 적용을 상태·선택수와 함께 복원")
	else:
		ok("BF-05", false, "최근 변경 복구 경로")
	await snap("undo-card")
	main.leak_log = [{"w":12,"n":2,"dmg":3,"lost":1,"dirs":{"북":2},"kinds":{Orb.Kind.FAST:2}}]
	await settle()
	await click_or_touch(main.card_dock.review_btn.get_global_rect().get_center())
	ok("BF-44", main.card_dock.reading_review and main.card_dock.side.visible and main.patchlog_system._kr_keep("실제 손실 1") in main.card_dock.detail.text and main.patchlog_system._kr_keep("북쪽 2개") in main.card_dock.detail.text, "지난 웨이브 버튼으로 방향·종류·실제 체력 손실 열람")
	ok("BF-44", main.picks_left == 1, "기록 열람은 카드 소비 없음")
	await snap("wave-review")
	await click_or_touch(main.card_dock.close_btn.get_global_rect().get_center())
	ok("BF-44", not main.card_dock.reading_review and main.choice_box.visible, "기록을 닫으면 원래 카드 선택 복원")
	var stale_card: Dictionary = main.offer[0].duplicate(true)
	main.card_dock.read_card(stale_card)
	main.run_flow_system._on_skip()
	main.interaction_system._select_tower(main.towers.get_child(0))
	await settle()
	main.card_dock.use_btn.pressed.emit()
	main.cards_system._on_pick(stale_card)
	ok("BF-01", main.phase == main.Phase.READY and main.picks_left == 0 and not main.card_dock.use_btn.visible and main.card_dock.reading_card.is_empty(), "연속 진행으로 보류한 카드의 오래된 읽기·직접 callback을 재사용할 수 없음")
	await fixture()
	main.mp_mode = "coop"
	target.owner_id = main.mp.my_id
	refused.owner_id = main.mp.my_id
	main.settings_panel.show()
	ok("BF-01", not main.cards_system._on_pick(main.offer[0]) and main.phase == main.Phase.CHOOSE, "사용자 카드 선택은 설정 뒤에서 차단")
	main.mp_auto_now = true
	var automatically_picked: bool = main.lobby_system._mp_auto_pick()
	ok("BF-46", automatically_picked and main.picks_left == 1 and target.m("pierce") == 1, "멀티 제한시간 자동 선택은 읽기 창과 독립적으로 유효 카드 하나 적용")
	main.picks_left = 0
	var automatic_before: int = target.m("pierce")
	ok("BF-46", not main.lobby_system._mp_auto_pick() and target.m("pierce") == automatic_before, "자동 선택 거절 뒤 오래된 picked로 추가 적용하지 않음")
	main.mp_auto_now = false
	main.mp_mode = ""
	main.settings_panel.hide()
	print("BATTLEFIELD CORE failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails > 0 or ui_errors > 0 else 0)

func click_or_touch(at: Vector2) -> void:
	if phone:
		await touch(at, true)
		await touch(at, false)
	else:
		await mouse_click(at)
