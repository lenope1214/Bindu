extends SceneTree
## 판마다 다른 흐름 스크린샷: 점수 줄 흐름 칩 말풍선(이벤트·예고·봉인·적응)과 진입 배지 말풍선.
## 인자: 저장 폴더 [글자 크기] [touch]. 예) xvfb-run godot --path . -s tools/vary_shot.gd -- /tmp/shots 1.3
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
			main._apply_ui_scale()
			main._close_title(),
		func():
			main._close_title()
			main.touch_ui = touch
			if main.tut:
				main.tut.close()
			main.help_label.visible = false
			for i in 5:
				main.picked = {"type": "elem", "e": Elem.ALL[i * 2], "lv": 2}
				main._place_tower(main.core() + Vector2.from_angle(i * 1.3 + 0.4) * 170.0, Vector2.RIGHT)
			Vary.new_run(true)
			Vary.event = {"id": "eclipse", "el": {Elem.LIGHT: 0.6, Elem.DARK: 1.4}, "pt": {}}
			Vary.next_event = {"id": "form", "el": {}, "pt": {"wisp": 0.6, "wall": 1.4, "spray": 1.4}}
			Vary.adapt_el = {Elem.SOUL: 0.12}
			Vary.adapt_pt = {"wisp": 0.08}
			main.wave = 39
			main._roll_lanes()
			main.phase = main.Phase.READY
			main._update_preview()
			main.hud_sig = "",
		func():
			var ch: Array = main.hud_chips.filter(func(c): return c[1] == "tag")
			var r: Rect2 = ch[-1][0]
			root.get_viewport().warp_mouse(main.hud.get_global_transform_with_canvas() * r.get_center()),
		func(): pass,
		func(): _snap("vary_chip"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s.png" % [n, z, "_touch" if touch else ""]))
	print("SHOT ", n)
	preload("res://tools/ui_check.gd").check(main, n)  # 겹침·화면 밖 (UI OVERLAP 줄)


func _process(_d) -> bool:
	f += 1
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
