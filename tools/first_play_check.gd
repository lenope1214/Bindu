extends "res://tools/spec_check.gd"
## 실제 첫 진입 native 검사. 개인 저장과 분리한 BinduTools 사본에서만 실행한다.
## godot --path <사본> -s tools/first_play_check.gd -- <캡처 폴더> <글자 배율> [touch]
var output := "/tmp/bindu-first-qa"
func _initialize():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless":
		push_error("BinduTools 저장 분리 사본에서 창을 띄워 실행하세요")
		quit(1)
		return
	if OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		push_error("검사 사본의 서버·멀티 주소를 비운 뒤 실행하세요")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	for path in [Tutorial.PATH, Meta.SAVE_PATH, "user://run.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Tutorial.loaded = false
	Meta.games = 0
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	Meta.ui_scale = float(args[1])
	main.touch_ui = args.size() > 2
	Meta.sim_phone = main.touch_ui
	if Meta.sim_phone:
		Meta.sim_safe = Rect2(86, 0, 86, 38)
	main.hud_system._apply_ui_scale()
	for i in 5:
		await process_frame
	ok("TUT-01", main.tut.visible and main.tut.mode == "welcome" and Tutorial.seen.is_empty(), "native fresh device shows one-goal welcome")
	await snap("welcome")
	main.tut.btn_close.pressed.emit()
	ok("TUT-01", main.tut.mode == "pages" and Tutorial.seen.has("goal") and not Tutorial.seen.has("place"), "optional detail marks only opened topic")
	main.tut.close()
	main.tut.open_welcome()
	main.tut.btn_next.pressed.emit()
	ok("TUT-01", TutPlay.pending == 0 and Tutorial.done, "play starts the play tutorial practice run")
	TutPlay.pending = -1  # 여기서는 첫 일반 판 흐름(TUT-06)을 이어서 본다
	main.menu_system._set_prep(true)
	main.progression_system._close_title()
	main.auto_start = false
	main.set_process(false)
	await snap("choose")
	ok("TUT-06", main.picks_left == 2 and main.onboarding_system._first_action_text().contains("하나"), "first choice keeps two picks")
	var card: Dictionary = main.offer[0]
	main._on_card_tap(card, 0)
	ok("TUT-06", main.phase == main.Phase.PLACE and main.picks_left == 2 and not main.choice_box.visible, "first tap holds card without consuming a pick")
	if main.touch_ui:
		await snap("preview")
	await snap("place")
	main.phase = main.Phase.AIM
	await snap("aim")
	main._cancel_step()
	ok("TUT-06", main.phase == main.Phase.PLACE and main.onboarding_system._first_action_text().contains("빈 곳"), "aim cancel returns to placement")
	main._back_to_choose()
	main._set_cards_hidden(true)
	ok("TUT-06", main.onboarding_system._first_action_text().contains("다시 열어"), "field view retains next action")
	main._set_cards_hidden(false)
	main._on_pick(card)
	main._place_tower(main.center() + Vector2(-180, 120), Vector2.RIGHT)
	main._after_place(card)
	await snap("one_left")
	ok("TUT-06", main.picks_left == 1 and main.phase == main.Phase.CHOOSE and main.onboarding_system._first_action_text().contains("한 장 더"), "first completed placement still needs one card")
	main._save_run()
	main._continue_run()
	ok("TUT-06", main.picks_left == 1 and main.phase == main.Phase.CHOOSE and main.onboarding_system._first_action_text().contains("한 장 더"), "saved initial rest resumes correct action")
	card = main.offer[0]
	main._on_pick(card)
	main._place_tower(main.center() + Vector2(180, 120), Vector2.LEFT)
	main._after_place(card)
	await snap("ready")
	ok("TUT-06", main.picks_left == 0 and main.phase == main.Phase.READY and main.onboarding_system._first_action_text().contains("웨이브"), "two real placements enable start action")
	main.lanes.clear()  # 방어 배치 정책은 spec에서 검사하고, 여기서는 첫 행동 안내 종료를 확인한다.
	main._start_wave_from_ready()
	ok("TUT-06", main.wave == 1 and main.onboarding_system._first_action_text() == "", "action guide ends only after wave starts")
	main.onboarding_system._guide("skill", "긴 설명")
	main.onboarding_system._tut_tick()
	ok("TUT-03", not main.tut.visible and not paused and main.onboarding_system.tut_queue.is_empty(), "event does not pause or open another modal")
	Meta.guide_on = false
	main._process(0.0)
	ok("TUT-03", not main.guide_label.visible and not main.guide_more.visible, "turning guidance off hides current hint immediately")
	Meta.guide_on = true
	Tutorial.load_file()
	ok("TUT-01", not Tutorial.need_first() and not Tutorial.seen.has("place"), "returning device keeps intro done and unread detail separate")
	main.free()
	print("NATIVE FIRST failures=", fails)
	quit(1 if fails else 0)
func snap(tag: String):
	for i in 6:
		main._process(0.0)
		await process_frame
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(output.path_join(tag + ".png"))
	var bad: int = preload("res://tools/ui_check.gd").check(main, tag)
	fails += bad
	print("NATIVE SHOT ", tag, " action=", main.onboarding_system._first_action_text(), " ui=", bad)
