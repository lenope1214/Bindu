extends SceneTree
## 보스 서약(시험) 스크린샷: 서약 창·점수 줄 칩. 인자: 저장 폴더 [글자 크기] [touch] [phone]
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
			paused = false
			main.tut_paused = false
			main.progression_system._close_title(),
		func():
			var c: Vector2 = main.viewport_system.core()
			var es := [Elem.FIRE, Elem.WATER, Elem.ICE, Elem.WIND, Elem.WOOD]
			for i in es.size():
				main.picked = {"type": "elem", "e": es[i], "lv": 2}
				main.interaction_system._place_tower(c + Vector2.from_angle(i * TAU / es.size()) * 170.0, Vector2.RIGHT)
			main.towers.get_child(0).set_pattern("laser")
			main.towers.get_child(1).set_pattern("spray")
			main.towers.get_child(2).set_pattern("sonic")
			main.wave = 10
			Oath.offered_w = -1
			Oath.open(main),
		func(): _snap("oath_pick"),
		func():
			Oath.close(main)
			Oath.take(main, "rigid")
			Oath.take(main, "sprint")
			main.cards_system._make_choices(),
		func(): _snap("oath_chips"),
	]


func _snap(n: String):
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
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
