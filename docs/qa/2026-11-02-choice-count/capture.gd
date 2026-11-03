extends "res://tools/spec_check.gd"
## 실제 저장과 온라인 기능을 분리한 사본에서 실행. README.md의 실행 예를 따른다.

var output: String
var touch := false

func _initialize():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"):
		push_error("저장 분리 사본의 config/name을 BinduTools로 시작하게 바꾼 뒤 실행하세요")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	output = args[0]
	Meta.ui_scale = float(args[1])
	touch = args.size() > 2 and args[2] == "touch"
	Meta.sim_phone = args.size() > 3 and args[3] == "phone"
	if Meta.sim_phone:
		Meta.sim_safe = Rect2(86, 0, 86, 38)
	seed(1)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	if main.tut and main.tut.panel.visible:
		main.tut.close()
	main._hide_title()
	Meta.ui_scale = float(args[1])
	Meta.guide_on = false
	Meta.card_detail = false
	Meta.games = 1
	main.touch_ui = touch
	main._apply_ui_scale()
	_fresh(1)
	_tower(main.center() + Vector2(-220, 120), Elem.WOOD)
	_tower(main.center() + Vector2(240, -120), Elem.WATER)
	main._start_choose()
	Vary.sealed = {"elem": [], "pat": [], "link": []}
	main.guide_lines.clear()
	main.picks_left = 2
	main.offer = [{"type": "elem", "e": Elem.EARTH, "lv": 2}, {"type": "elem", "e": Elem.ICE, "lv": 1}, {"type": "elem", "e": Elem.STAR, "lv": 1}]
	main._show_offer()
	await snap("two")
	main.guide_lines.append("속성 카드 안내")
	main.guide_label.text = main._kr_keep("속성 카드를 오브젝트 위에 놓으면 겹쳐져요. 같은 속성은 레벨업, 다른 속성은 추가 효과가\n더해지고, 맞는 두 속성이 만나면 특수 반응이 생겨요")
	await snap("guide_two")
	main.guide_lines.clear()
	main.picks_left = 1
	await snap("one")
	main.picks_left = 12
	await snap("bank")
	main.picks_left = 2
	if touch:
		for i in 3:
			main._on_card_tap(main.offer[i], i)
			await snap("preview_%d" % i)
		main._set_card_detail(true)
		await snap("detail")
		main._set_card_detail(false)
		main.tap_sel = -1
		main._tap_hover()
	Vary.sealed = {"elem": [Elem.FIRE, Elem.WOOD, Elem.WATER], "pat": ["spray", "thorn", "chain", "gust"], "link": ["prism"]}
	await snap("seal")
	main.free()
	quit(1 if fails else 0)

func snap(tag: String):
	for i in 6:
		main._process(0.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(output.path_join(tag + ".png"))
	preload("res://tools/ui_check.gd").check(main, tag)
	var head = main.get("choice_header")
	if head != null and head.visible:
		var inv = main.ui_root.get_global_transform().affine_inverse()
		var first = inv * main.choice_box.get_child(0).get_global_rect()
		var last = inv * main.choice_box.get_child(2).get_global_rect()
		var r = head.get_rect()
		var gap = first.position.y - r.end.y
		var valid = is_equal_approx(first.position.x, r.position.x) and is_equal_approx(last.end.x, r.end.x) and gap >= 18.0
		if main.apply_btn.visible:
			valid = valid and not r.intersects(main.apply_btn.get_rect())
		if main.guide_label.visible:
			valid = valid and not r.intersects(main.guide_label.get_rect())
		print("CHOICE ", tag, " header=", r, " card_gap=", gap, " ok=", valid)
		if not valid:
			fails += 1
	print("SHOT ", tag)
	print("PROFILE viewport=", root.get_viewport().get_visible_rect().size, " scale=", Meta.ui_scale, " touch=", main.touch_ui)
