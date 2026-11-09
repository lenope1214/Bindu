extends "res://tools/carry_check.gd"
## 격리 native 사본에서 진행·기술·저장 사용성 검증.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(100).timeout.connect(func(): quit(2))
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
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	await create_timer(0.2).timeout
	await fixture()
	main.run_id = "flow-check"
	main.touch_ui = phone
	main.run_flow_system._update_skip_ui()
	ok("BF-30", main.run_flow_system.has_method("set_skip_n") and main.run_flow_system.has_method("open_skip_picker"), "진행 수를 직접 선택하는 API")
	ok("BF-31", "연속 진행" in main.skip_btn.text and "전투" in main.skip_btn.tooltip_text, "실제 전투·카드 보류가 실행 전에 설명됨")
	ok("BF-26", main.persistence_system.has_method("save_status_text"), "실제 로컬 저장 상태·복원 경계 표시")
	main.abilities_system._skills_new_run(0)
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.to_spawn = 1
	main.spawn_timer = 1000.0
	main.skill_cd["hold"] = 8.0
	main.game_speed = 4.0
	main.abilities_system._skill_ui()
	ok("BF-37", "속도" in main.skill_btns[0].text and "멈춤" in main.skill_btns[1].text, "기술 버튼에 효과가 보임")
	ok("BF-38", "실제" in main.skill_btns[1].tooltip_text and "웨이브" in main.skill_btns[1].tooltip_text, "실제 초·웨이브 재충전 표시")
	ok("BF-36", main.abilities_system.has_method("skill_speed_factor"), "조준 속도 정책 API")
	ok("BF-40", main.abilities_system.has_method("toggle_skill_auto") and main.abilities_system.has_method("skill_mode_text"), "수동·자동 모드 제어 API")
	await snap("skills")
	await persistence_case()
	if main.run_flow_system.has_method("set_skip_n"):
		await skip_case()
	if main.abilities_system.has_method("skill_speed_factor"):
		await skill_case()
		await settings_case()
	if main.run_flow_system.has_method("speed_shortcut_ready"):
		await speed_case()
	print("BATTLEFIELD FLOW failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails else 0)

func persistence_case() -> void:
	await fixture()
	main.run_id = "flow-saved-continue"
	main.score = 1234
	main.picks_left = 2
	target.dealt = 75.0
	main.wave_time = 15.0
	var initial_offer: Array = main.offer.duplicate(true)
	var initial_pos: Vector2 = target.position
	main.persistence_system._save_run()
	var saved: String = FileAccess.get_file_as_string(main.RUN_PATH)
	ok("BF-26", saved.begins_with("[run]"), "실제 격리 user 경로에 쉬는 시간 저장")
	main.score = 9000
	target.position += Vector2(80, -40)
	main.offer.clear()
	main.persistence_system._continue_run()
	ok("BF-26", main.run_id == "flow-saved-continue" and main.score == 1234 and main.picks_left == 2 and main.offer == initial_offer and main.towers.get_child(0).position.is_equal_approx(initial_pos), "실제 이어하기가 판 ID·점수·카드·위치를 복구")
	ok("BF-26", main.phase == main.Phase.CHOOSE and main.towers.get_child_count() == 2 and is_equal_approx(main.towers.get_child(0).dealt, 75.0) and is_equal_approx(main.wave_time, 15.0), "이어하기는 중복 오브젝트 없이 쉬는 시간·지난 피해 기록 복원")
	ok("BF-26", FileAccess.get_file_as_string(main.RUN_PATH) == saved, "이어하기 조회 중 저장한 선택지를 덮어쓰지 않음")
	await snap("restored")

func skip_case() -> void:
	await fixture()
	var picks: int = main.picks_left
	var offers: Array = main.offer.duplicate(true)
	for n in [10, 1, 5, 3]:
		main.run_flow_system.set_skip_n(n)
		ok("BF-30", Meta.skip_n == n and main.phase == main.Phase.CHOOSE and main.picks_left == picks and main.offer == offers, "선택 수 직접 지정은 전투·카드를 소비하지 않음: %d" % n)
	main.run_flow_system.open_skip_picker()
	await settle()
	ok("BF-30", main.run_flow_system.skip_picker.visible and main.run_flow_system.skip_picker.item_count == 4, "1·3·5·10 직접 선택 메뉴 열림")
	await snap("skip-picker")
	main.run_flow_system.skip_picker.hide()
	main.run_flow_system._on_skip()
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.to_spawn = 1
	main.spawn_timer = 1000.0
	main.run_flow_system._update_skip_ui()
	ok("BF-32", "웨이브 뒤" in main.skip_badge.text, "연속 전투 중 멈춤은 현재 웨이브 뒤임을 명시")
	ok("BF-33", "카드" in main.skip_badge.text and "새로고침" in main.skip_badge.tooltip_text, "누적 보류 내역 노출")
	main.run_flow_system._toggle_skip_stop()
	ok("BF-32", main.skip_stop and "멈" in main.toast.text, "현재 웨이브 뒤 멈춤을 예약")
	await snap("continuous")

func skill_case() -> void:
	await fixture()
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.to_spawn = 1
	main.spawn_timer = 1000.0
	main.mp_mode = ""
	main.skill_arm = "hold"
	ok("BF-36", main.abilities_system.skill_speed_factor() < 1.0, "수동 조준 속도 배율이 1보다 작음")
	main.mp_mode = "coop"
	ok("BF-36", is_equal_approx(main.abilities_system.skill_speed_factor(), 1.0), "멀티 판에는 조준 감속을 적용하지 않음")
	main.mp_mode = ""
	main.skill_arm = ""
	ok("BF-36", is_equal_approx(main.abilities_system.skill_speed_factor(), 1.0), "조준하지 않을 때 원래 속도")
	var before: bool = Meta.skill_auto
	main.abilities_system.toggle_skill_auto()
	ok("BF-40", Meta.skill_auto != before and "자동" in main.abilities_system.skill_mode_text(), "기술 자동 사용 전환·표시")
	main.abilities_system.toggle_skill_auto()
	await snap("skill-mode")

func settings_case() -> void:
	# VirtualInput은 창 포커스 정책을 꺼서 비점유 실행한다. 새 저장의 기본값은 별도 로드해 검사한다.
	var current := ConfigFile.new()
	Meta.save_into(current)
	Meta.load_into(ConfigFile.new())
	ok("BF-07", Meta.pause_on_focus_loss, "새 설정은 싱글 포커스 상실 정지가 기본 켬")
	ok("BF-36", Meta.skill_aim_slow, "수동 조준 감속 기본 켬")
	Meta.load_into(current)
	var original_pause: bool = Meta.pause_on_focus_loss
	var original_slow: bool = Meta.skill_aim_slow
	Meta.pause_on_focus_loss = false
	Meta.skill_aim_slow = false
	var cfg := ConfigFile.new()
	Meta.save_into(cfg)
	Meta.pause_on_focus_loss = true
	Meta.skill_aim_slow = true
	Meta.load_into(cfg)
	ok("BF-07", not Meta.pause_on_focus_loss and not Meta.skill_aim_slow, "설정 저장·복원에서 사용자가 끈 상태 유지")
	Meta.pause_on_focus_loss = original_pause
	Meta.skill_aim_slow = original_slow
	await fixture()
	main.persistence_system._save_run()
	ok("BF-26", main.persistence_system.last_local_save_wave == main.wave and "저장됨" in main.persistence_system.save_status_text(), "성공한 로컬 저장 사실 표시")
	main.mp_mode = "coop"
	ok("BF-26", "이어하기 없음" in main.persistence_system.save_status_text() and "이어하기" in main.run_flow_system._pause_text(), "멀티는 이어하기가 없다는 안내")
	main.mp_mode = ""
	main.menu_system._toggle_settings()
	await snap("settings")
	main.menu_system._toggle_settings()

func speed_case() -> void:
	await fixture()
	main.picks_left = 0
	main.cards_system._enter_ready()
	main.game_speed = 1.0
	main.fast_speed = 4.0
	main.run_flow_system._start_wave()
	main.run_flow_system._toggle_speed(true)
	ok("BF-35", is_equal_approx(main.game_speed, 1.0), "시작 직후 Space 반복은 가속하지 않음")
	main.run_flow_system._toggle_speed(false)
	ok("BF-35", is_equal_approx(main.game_speed, 4.0), "명시적 배속 버튼은 즉시 반응")
	main.game_speed = 1.0
	await create_timer(0.5).timeout
	main.run_flow_system._toggle_speed(true)
	ok("BF-35", is_equal_approx(main.game_speed, 4.0), "중복 방지 시간 뒤 단축키 정상 가속")
	await snap("speed")
