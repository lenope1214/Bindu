extends SceneTree
## 영웅 속성(시험) 스크린샷: 고르기 창·영웅 오브젝트·능력 창. 인자: 저장 폴더 [글자 크기] [touch] [phone]
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
		func(): Hero.open_pick(main),
		func(): _snap("hero_pick"),
		func():
			Hero.close(main)
			var h := Hero.spawn(main, Elem.ELECTRIC)
			for i in 3:
				Hero.gain(h, "card", 10.0)
			main.picked = {"type": "elem", "e": Elem.FIRE, "lv": 2}
			main.interaction_system._place_tower(main.viewport_system.core() + Vector2(160, 80), Vector2.RIGHT)
			Hero.open_ability(main),
		func(): _snap("hero_ability"),
		func():
			Hero.close(main)
			main.cards_system._set_cards_hidden(true),
		func(): _snap("hero_field"),
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
