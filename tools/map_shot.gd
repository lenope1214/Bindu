extends SceneTree
## 맵 규칙·친화 카드 스크린샷: 준비 화면 맵 줄(맵마다), 친화 카드 선택지, 점수 줄 맵 칩 말풍선, 십자로 길목 띠, 폭풍 바람.
## 인자: 저장 폴더 [글자 크기] [touch]. 예) xvfb-run godot --path . -s tools/map_shot.gd -- /tmp/shots 1.3
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main._apply_ui_scale()
			Meta.games = 5
			if main.tut:
				main.tut.close(),
	]
	for m in ["plain", "spiral", "cross", "storm", "line"]:
		steps.append(func():
			if main.tut:
				main.tut.close()
			Meta.map_id = m
			main._set_prep(true)
			main._refresh_menu())
		steps.append(func(): _snap("prep_" + m))
	steps.append_array([
		func():
			main._set_prep(false)
			Meta.map_id = "line"
			main._close_title(),
		func():
			main._close_title()
			if main.tut:
				main.tut.close()
			main.help_label.visible = false
			for i in 3:
				main.picked = {"type": "elem", "e": Elem.ALL[i * 3], "lv": 1}
				main._place_tower(main.core() + Vector2.from_angle(i * 2.0 + 0.4) * 170.0, Vector2.RIGHT)
			main.wave = 6
			main.offer = [{"type": "elem", "e": Elem.ICE, "lv": 1}, {"type": "pat", "id": "lob"}, {"type": "mod", "id": "size"}]
			main.phase = main.Phase.CHOOSE
			main._show_offer()
			main.choice_box.get_parent().visible = true,
		func(): pass,
		func(): _snap("map_cards"),
		func():
			main.choice_box.get_parent().visible = false
			Meta.map_id = "cross"
			main.lanes.clear()
			main._roll_lanes()
			main.phase = main.Phase.READY
			main._update_preview()
			main.hud_sig = "",
		func():
			var ch: Array = main.hud_chips.filter(func(c): return c[1] == "tag")
			var r: Rect2 = ch[-1][0]
			root.get_viewport().warp_mouse(main.hud.get_global_transform_with_canvas() * r.get_center()),
		func(): pass,
		func(): _snap("map_cross"),
		func():
			Meta.map_id = "storm"
			main.lanes.clear()
			main._roll_lanes()
			main._update_preview()
			main.hud_sig = "",
		func(): pass,
		func(): _snap("map_storm"),
	])


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s.png" % [n, z, "_touch" if touch else ""]))
	print("SHOT ", n)


func _process(_d) -> bool:
	f += 1
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
