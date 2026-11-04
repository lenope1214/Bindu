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
