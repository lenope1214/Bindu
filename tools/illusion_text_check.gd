extends "res://tools/spec_check.gd"
## 환영 16짝의 조합 카드: 속성 제목·공용 설명, 폭/높이·화면 안 배치, 선택 상세·도감까지 확인.
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
		main.rx_card.show_for(tw, [rx])
		main.rx_card.found = {rx["id"]: true}
		await settle()
		var rc = main.rx_card
		ok("UI-37", rc.visible and rc.title(rx["a"], rx["b"]) == "환영 · " + Elem.NAMES[other], "속성 제목 " + rx["id"])
		for text in [rx["desc"], rc.aff_note(rx)]:
			for line in rc.paragraph(text, 14).split("\n"):
				ok("UI-37", main.ui_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= rc.size.x - 23, "설명 폭 " + rx["id"])
		var r: Rect2 = rc.get_global_rect()
		var safe: Rect2 = main.ui_root.get_global_transform() * Rect2(Vector2.ZERO, main.ui_root.size)
		ok("UI-37", safe.grow(1).encloses(r), "조합 카드 화면 안 " + rx["id"])
		for b: Control in [main.hud, main.bar_box, main.start_btn, main.skip_btn, main.skip_n_btn]:
			ok("UI-37", not b.is_visible_in_tree() or not r.intersects(b.get_global_rect()), "조합 카드와 버튼 분리 " + rx["id"])
		RenderingServer.force_draw()
		main.get_viewport().get_texture().get_image().save_png(output.path_join(rx["id"] + ".png"))
		main.rx_card.hide_card()
		main.interaction_system._select_tower(tw)
		main.tip_detail = true
		await settle()
		ok("UI-32", main.card_dock.detail.text.contains(main.patchlog_system._kr_keep(rx["desc"])), "선택 상세의 공용 설명 " + rx["id"])
		ok("UI-37", entries.any(func(entry): return entry.get("key") == "react:" + rx["id"] and entry["name"] == rx["name"] and entry["desc"].contains(rx["desc"])), "도감의 공용 제목·설명 " + rx["id"])
	# 긴 설명 두 장도 화면에 맞춰 한 장 + 더 보기로 접을 수 있다.
	main.card_dock.close_inspector()
	main.rx_card.show_for(tw, [Elem.reaction_of(Elem.ILLUSION, Elem.FIRE), Elem.reaction_of(Elem.ILLUSION, Elem.WIND)])
	await settle()
	ok("UI-37", main.rx_card.rxs.size() + main.rx_card.extra == 2, "두 장 표시 또는 한 장+더 보기에서 조합 보존")
	var two_rect: Rect2 = main.rx_card.get_global_rect()
	var safe_rect: Rect2 = main.ui_root.get_global_transform() * Rect2(Vector2.ZERO, main.ui_root.size)
	ok("UI-37", safe_rect.grow(1).encloses(two_rect) and not two_rect.intersects(main.start_btn.get_global_rect()), "긴 두 조합도 화면 안·웨이브 버튼 위")
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(output.path_join("two_pairs.png"))
	shift.pressed = false
	VirtualInput.send(shift)
	print("ILLUSION TEXT failures=%d" % fails)
	quit(1 if fails else 0)

func settle() -> void:
	for i in 6:
		main.touch_ui = touch
		main._process(0.0)
		await process_frame
	RenderingServer.force_draw()
