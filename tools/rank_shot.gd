extends SceneTree
## 피해 1~3위 왕관·메달 스크린샷. 인자: 저장 폴더 [글자 크기] [touch] [phone]
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
	Meta.sim_phone = a.size() > 3 and a[3] == "phone"
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main.hud_system._apply_ui_scale()
			main.onboarding_system.tut_first = false
			Tutorial.loaded = true
			Tutorial.done = true
			for tp in Tutorial.TOPICS:
				Tutorial.seen[tp["id"]] = true
			if main.tut.visible:
				main.tut.close()
			get_paused_fix()
			main.progression_system._close_title(),
		func():
			if not main.legend_hidden:
				main.cards_system._toggle_legend()
			var c: Vector2 = main.core()
			var es := [Elem.FIRE, Elem.ICE, Elem.LIGHT, Elem.WIND, Elem.SOUL, Elem.EARTH, Elem.WATER]
			var dl := [2400.0, 1500.0, 3100.0, 400.0, 900.0, 1250.0, 600.0]
			for i in es.size():
				main.picked = {"e": es[i], "lv": 3}
				main.interaction_system._place_tower(c + Vector2.from_angle(i * TAU / es.size() + 0.3) * 170.0, Vector2.RIGHT)
				var t = main.towers.get_child(i)
				t.add(es[(i + 2) % es.size()], 2)
			for i in es.size():
				main.towers.get_child(i).dealt = dl[i]
			main.wave = 24
			main.wave_time = 30.0
			main.hud_system._rank_update()
			main.cards_system._set_cards_hidden(true),
		func(): VirtualInput.move(Vector2(5, 5)),
		func(): _snap("rank"),
	]


func get_paused_fix():
	paused = false
	main.tut_paused = false


func _snap(n: String):
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
	var img: Image = main.get_viewport().get_texture().get_image()
	var c: Vector2 = main.core()
	var sc: Transform2D = main.get_viewport().get_final_transform() * main.get_canvas_transform()
	var cc := sc * c
	var hw := 260.0 * sc.get_scale().x
	var crop := img.get_region(Rect2i(int(cc.x - hw), int(cc.y - hw * 0.8), int(hw * 2), int(hw * 1.6)))
	crop.resize(int(hw * 2 * 1.8), int(hw * 1.6 * 1.8), Image.INTERPOLATE_LANCZOS)
	crop.save_png(out.path_join("%s_zoom_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
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
