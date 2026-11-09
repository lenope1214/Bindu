extends "res://tools/carry_check.gd"
## 최신 main 결과 상세와 전장 사용성 변경의 native 호환 확인. 실제 종료·버튼 입력을 사용한다.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(90).timeout.connect(func(): quit(2))
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
	target.hist = [[main.wave - 1, 200, 3, 10.0]]
	target.run_dealt = 200
	target.dealt = 75
	target.wave_kills = 2
	main.wave_time = 10.0
	main.run_flow_system._game_over()
	await settle()
	ok("RES-MAIN", main.phase == main.Phase.GAMEOVER and not main.hud.visible and not main.bar_btn.visible and not main.pause_btn.visible, "판 종료에서는 최신 main의 위 정보·설정·정지 숨김 유지")
	ok("RES-MAIN", main.over_detail_btn.is_visible_in_tree() and main.ui_root.get_global_rect().encloses(main.over_detail_btn.get_global_rect()), "결과 상세 버튼이 실제 화면 안에 노출")
	ok("RES-MAIN", target.hist.size() == 2 and target.hist[-1] == [main.wave, 75, 2, 10.0], "실제 game over가 최신 main의 웨이브 피해·처치 기록 보존")
	await snap("gameover")
	await activate(main.over_detail_btn)
	ok("RES-MAIN", main.run_detail.visible and main.run_detail.rows.size() == 3, "실제 결과 상세 버튼이 전체와 두 오브젝트를 엶")
	await snap("result-detail")
	var detail: RunDetail = main.run_detail
	var list: Rect2 = detail._list_rect()
	# 목록은 최신 main의 pointer 경로를 검증한다. 실물 폰의 touch-to-mouse 변환 증거는 아니다.
	await mouse_click(detail.get_global_transform() * Vector2(list.get_center().x, list.position.y + RunDetail.ROW_H * 1.5))
	ok("RES-MAIN", detail.sel == 1, "pointer로 개별 오브젝트 결과 선택")
	await snap("result-object")
	await key(KEY_ESCAPE)
	ok("RES-MAIN", not detail.visible and main.phase == main.Phase.GAMEOVER and not main.title_label.visible, "Esc 한 번은 상세만 닫고 결과 화면 유지")
	await activate(main.over_detail_btn)
	await activate(detail.close_btn)
	ok("RES-MAIN", not detail.visible and main.phase == main.Phase.GAMEOVER, "실제 닫기 버튼도 결과 화면으로 복귀")
	for player in main.sfx.players + main.sfx.lead + [main.sfx.music_player]:
		player.stream_paused = false
		player.stop()
		player.stream = null
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	print("BATTLEFIELD RESULT failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails or ui_errors else 0)

func activate(button: Button) -> void:
	if phone:
		await touch(button.get_global_rect().get_center(), true)
		await touch(button.get_global_rect().get_center(), false)
	else:
		await mouse_click(button.get_global_rect().get_center())
