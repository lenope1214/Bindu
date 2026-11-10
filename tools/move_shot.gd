extends SceneTree
## 움직임 카드(시험) 스크린샷: 카드 줄·웨이브 중 움직이는 오브젝트. 인자: 저장 폴더 [글자 크기] [touch] [phone]
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
			var es := [Elem.FIRE, Elem.WATER, Elem.ELECTRIC]
			var mv := ["patrol", "orbit", "chase"]
			for i in es.size():
				main.picked = {"type": "elem", "e": es[i], "lv": 2}
				main.interaction_system._place_tower(c + Vector2.from_angle(i * TAU / es.size() + 0.4) * 170.0, Vector2.RIGHT)
				main.towers.get_child(i).add_trig(mv[i])
			main.wave = 6
			main.offer = [{"type": "trig", "id": "patrol"}, {"type": "trig", "id": "orbit"}, {"type": "trig", "id": "chase"}]
			main.cards_system._show_offer(),
		func(): _snap("move_cards"),
		func():
			main.cards_system._set_cards_hidden(true)
			main.run_flow_system._start_wave(),
		func(): pass,
		func(): pass,
		func(): pass,
		func(): pass,
		func(): pass,
		func(): _snap("move_wave"),
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
