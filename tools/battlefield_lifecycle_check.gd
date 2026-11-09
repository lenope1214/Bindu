extends "res://tools/carry_check.gd"
## 합성 모바일 알림·늦은 release·실제 저장 복원 경계. 물리 OS 검증을 대신하지 않는다.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "" or DisplayServer.get_name() == "headless":
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
	for stage in ["choose", "place", "aim", "ready", "wave", "skill", "continuous"]:
		for notification in [MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT, MainLoop.NOTIFICATION_APPLICATION_PAUSED]:
			await lifecycle_case(stage, notification)
	print("BATTLEFIELD LIFECYCLE failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails + ui_errors > 0 else 0)

func lifecycle_case(stage: String, notification: int) -> void:
	Meta.pause_on_focus_loss = false  # fixture의 격리된 no_focus 창은 실제 포커스 정책과 분리
	await fixture()
	main.run_id = "lifecycle-" + stage
	main.touch_ui = true
	target.position = Vector2(300, 320)
	refused.position = Vector2(950, 320)
	var original_auto: float = Rules.t("auto_aim")
	main.persistence_system._save_run()
	var old_offer: Array = main.offer.duplicate(true)
	var probe := world(Vector2(600, 400))
	match stage:
		"choose":
			probe = card_center()
		"aim":
			main.cards_system._on_pick(main.offer[1])
			Rules.tune["auto_aim"] = 0.0
			main.interaction_system._place_card_at(Vector2(600, 400))
		"ready":
			main.cards_system._enter_ready()
			probe = world(target.position)
		"wave", "skill":
			main.cards_system._enter_ready()
			main.lanes.clear()
			main.run_flow_system._start_wave()
			main.to_spawn = 1
			main.spawn_timer = 1000.0
			if stage == "skill":
				main.skill_arm = "hold"
		"continuous":
			main.run_flow_system._on_skip()
	await settle()
	# 실제 input 경로에서 down 뒤 release가 사라지는 상황을 만든다.
	if stage == "place":
		await touch(card_center(1), true)
		await touch_drag(probe)
	else:
		await touch(probe, true)
	var picks: int = main.picks_left
	var count: int = main.towers.get_child_count()
	var modifications: int = target.m("pierce")
	var wave: int = main.wave
	Meta.pause_on_focus_loss = true
	main._notification(notification)
	await settle()
	ok("BF-47", paused and main.interaction_system.touches.is_empty() and not main.interaction_system.pinch_lock and main.card_dock.pending_card.is_empty() and main.interaction_system.press_t == null, stage + ": 백그라운드 알림이 정지·입력 상태 정리")
	await touch(probe, false)
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	main.frame_system._process(10.0)
	ok("BF-47", paused and main.picks_left == picks and main.towers.get_child_count() == count and target.m("pierce") == modifications and main.wave == wave, stage + ": 늦은 release·복귀는 소비·설치·자동 재개 없음")
	await snap(stage + "-" + str(notification))
	main.run_flow_system._toggle_pause()
	ok("BF-47", not paused, stage + ": 명시적 재개 가능")
	# 앱을 재시작해 이어하기를 누른 것과 같은 실제 저장 경로를 읽는다.
	main.persistence_system._continue_run()
	ok("BF-47", main.phase in [main.Phase.CHOOSE, main.Phase.READY] and main.interaction_system.touches.is_empty() and main.picks_left >= 0 and main.towers.get_child_count() == 2, stage + ": 재시작 복원은 쉬는 시간·무입력 상태")
	if stage in ["choose", "place", "aim"]:
		ok("BF-47", main.offer == old_offer, stage + ": 원래 저장한 offer 보존")
	Rules.tune["auto_aim"] = original_auto
	Meta.pause_on_focus_loss = false
