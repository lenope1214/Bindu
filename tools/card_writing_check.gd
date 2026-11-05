extends "res://tools/spec_check.gd"
## 전체 카드 문체 변경의 native 줄바꿈·상세 스크롤 검사. BinduTools 사본·온라인 주소 비움 필수.
var output := ""
var captures: Array = []
var touch := false
var expected_name := ""
var expected_rows: Array = []

func _initialize():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		push_error("온라인 주소를 비운 BinduTools native 사본에서 실행하세요")
		quit(1)
		return
	root.unfocusable = true
	create_timer(150).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	Meta.ui_scale = float(args[1])
	Meta.sim_phone = args.size() > 2 and args[2] == "phone"
	Meta.sim_safe = Rect2(86, 0, 86, 38) if Meta.sim_phone else Rect2()
	Meta.guide_on = false
	Tutorial.loaded = true
	Tutorial.done = true
	Meta.games = 5
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main.progression_system._hide_title()
	main.set_process(false)
	main.auto_start = false
	touch = args.size() > 2
	main.touch_ui = touch
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	ok("UI-20", is_equal_approx(Meta.ui_scale, float(args[1])) and main.ui_root.scale.is_equal_approx(Vector2.ONE * Meta.ui_scale), "requested text scale applied after saved settings")
	_fresh(12)
	for e in Elem.ALL:
		_tower(main.viewport_system.center() + Vector2.from_angle(e * 0.7) * 180.0, e)
	main.run_flow_system._start_choose()
	main.guide_lines.clear()
	main.banner_queue.clear()
	main.banner_t = 0
	main.toast_timer = 0
	main.picks_left = 2
	var cards: Array = Elem.ALL.map(func(e): return {"type": "elem", "e": e, "lv": 2})
	for kind in ["pat", "mod", "link", "trig"]:
		var defs: Dictionary = {"pat": Pat.PATTERNS, "mod": Pat.MODS, "link": Pat.LINKS, "trig": Pat.TRIGS}[kind]
		for id in defs:
			cards.append({"type": kind, "id": id})
	for start in range(0, cards.size(), 4):
		main.perk_mode = false
		main.offer = cards.slice(start, start + 4)
		Meta.card_detail = false
		main.cards_system._show_offer()
		await settle()
		for i in main.offer.size():
			var card: Dictionary = main.offer[i]
			var tag := "%s_%s" % [card["type"], str(card.get("id", card.get("e", "")))]
			var button: Button = main.choice_box.get_child(i)
			main.card_dock.inspected_tower = null
			main.card_dock.hovered = button
			VirtualInput.move(button.get_global_rect().get_center())
			expected_name = main.cards_system._card_content(card, 0)["head"]["name"]
			expected_rows = main.cards_system._card_full(card).map(func(row): return row[0])
			Meta.card_detail = false
			await snap(tag + "_summary")
			Meta.card_detail = true
			await snap(tag + "_detail")
			await bottom(tag)
	for start in range(0, main.PERKS.size(), 4):
		main.perk_offer = main.PERKS.slice(start, start + 4)
		main.perks_system._show_perks()
		await settle()
		for i in main.perk_offer.size():
			var button: Button = main.choice_box.get_child(i)
			main.card_dock.inspected_tower = null
			main.card_dock.hovered = button
			VirtualInput.move(button.get_global_rect().get_center())
			var tag: String = "perk_" + main.perk_offer[i]["id"]
			expected_name = main.perk_offer[i]["name"]
			expected_rows = [main.perks_system._perk_desc(main.perk_offer[i])]
			await snap(tag)
			await bottom(tag)
	FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE).store_string(JSON.stringify(captures, "\t"))
	print("CARD WRITING failures=%d captures=%d" % [fails, captures.size()])
	main.free()
	quit(1 if fails else 0)

func settle():
	for i in 8:
		main.touch_ui = touch
		main.frame_system._process(0.0)
		await process_frame
	RenderingServer.force_draw()

func snap(tag: String):
	await settle()
	var dock = main.card_dock
	var has_detail: bool = Meta.card_detail or main.perk_mode
	var title_ok: bool = dock.heading.text == expected_name if main.perk_mode else dock.heading.text == "카드 정보" and dock.pic.head.get("name", "") == expected_name
	ok("UI-20", not has_detail or (dock.side.visible and title_ok and expected_rows.all(func(row): return dock.detail.text.contains(main.patchlog_system._kr_keep(row)))), tag + " full text visible")
	var hbar: HScrollBar = dock.scroll.get_h_scroll_bar()
	ok("UI-20", not has_detail or hbar.max_value <= hbar.page + 1.0, tag + " no horizontal overflow")
	ok("UI-20", not has_detail or dock.detail.size.y + 1.0 >= dock.detail.get_content_height(), tag + " text height fits")
	for button in main.choice_box.get_children():
		if button.is_queued_for_deletion(): continue
		var lines: PackedStringArray = main.onboarding_system._wrap_words(main.patchlog_system._kr_keep(dock.summary_text(button)), button.size.x - 28, 14).split("\n")
		for line in lines:
			ok("UI-20", main.ui_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= button.size.x - 27, tag + " wrapped summary width")
	fails += preload("res://tools/ui_check.gd").check(main, tag)
	var image: Image = main.get_viewport().get_texture().get_image()
	image.save_png(output.path_join(tag + ".png"))
	captures.append({"file": tag + ".png", "viewport": [image.get_width(), image.get_height()], "scale": Meta.ui_scale, "touch": main.touch_ui, "phone": Meta.sim_phone, "text": dock.detail.text, "scroll_max": dock.scroll.get_v_scroll_bar().max_value, "scroll_page": dock.scroll.get_v_scroll_bar().page})

func bottom(tag: String):
	var dock = main.card_dock
	var bar: VScrollBar = dock.scroll.get_v_scroll_bar()
	if bar.max_value <= bar.page: return
	dock.scroll.scroll_vertical = int(bar.max_value)
	await snap(tag + "_bottom")
	ok("UI-20", dock.detail.get_global_rect().end.y <= dock.scroll.get_global_rect().end.y + 2, tag + " last line reachable")
	dock.scroll.scroll_vertical = 0
