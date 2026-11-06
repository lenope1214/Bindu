extends "res://tools/spec_check.gd"
## 환영 16짝의 통합 인스펙터·도감 공용 제목과 설명을 확인.
var output := ""
var touch := false

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(100).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	Meta.sim_phone = args.size() > 2 and args[2] == "phone"
	Meta.sim_safe = Rect2(86, 0, 86, 38) if Meta.sim_phone else Rect2()
	touch = args.size() > 2
	Meta.games = 5
	Meta.guide_on = false
	Tutorial.loaded = true
	Tutorial.done = true
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main.progression_system._hide_title()
	main.set_process(false)
	main.auto_start = false
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	main.guide_lines.clear()
	main.banner_queue.clear()
	main.banner_t = 0
	main.toast_timer = 0
	_fresh(0)
	var tw := _tower(Vector2(280, 300), Elem.ILLUSION, 3)
	main.cards_system._enter_ready()
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	VirtualInput.send(shift)
	var entries: Array = main.codex_panel.entries("react")
	for other in Elem.ALL:
		if other == Elem.ILLUSION:
			continue
		var rx: Dictionary = Elem.reaction_of(Elem.ILLUSION, other)
		main.card_dock.close_inspector()
		tw.elements = {Elem.ILLUSION: 3, other: 3}
		tw.order = [Elem.ILLUSION, other]
		tw.eff = tw.eff_now()
		main.interaction_system._select_tower(tw)
		main.tip_detail = true
		await settle()
		ok("UI-32", main.card_dock.detail.text.contains(main.patchlog_system._kr_keep(rx["desc"])), "선택 상세의 공용 설명 " + rx["id"])
		ok("UI-37", entries.any(func(entry): return entry.get("key") == "react:" + rx["id"] and entry["name"] == rx["name"] and entry["desc"].contains(rx["desc"])), "도감의 공용 제목·설명 " + rx["id"])
	shift.pressed = false
	VirtualInput.send(shift)
	print("ILLUSION TEXT failures=%d" % fails)
	quit(1 if fails else 0)

func settle() -> void:
	for i in 6:
		main.touch_ui = touch
		main.frame_system._process(0.0)
		await process_frame
	RenderingServer.force_draw()
