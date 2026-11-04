extends SceneTree
## 새 속성 피·환영(2026-11-04) 화면 점검: 카드 선택지·카드 자세히·출혈·현혹 표시와 핏자국이 깔린 전장·정보창·도감 속성 탭.
## 인자: 저장 폴더 [글자 크기] [touch] [phone]. 예) xvfb-run godot --path . --rendering-driver opengl3 -s tools/newelem_shot.gd -- /tmp/shots 1.0
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
	root.add_child(main)
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main._apply_ui_scale()
			Meta.games = 5
			if main.tut and main.tut.visible:
				main.tut.close(),
		func():
			main.continue_btn.visible = false
			main._close_title(),
		func():
			if main.tut and main.tut.visible:
				main.tut.visible = false,
		func():
			var c: Vector2 = main.core()
			main.picked = {"type": "elem", "e": Elem.BLOOD, "lv": 2}
			main._place_tower(c + Vector2(-170, -60), Vector2.LEFT)
			main.picked = {"type": "elem", "e": Elem.ILLUSION, "lv": 2}
			main._place_tower(c + Vector2(-150, 90), Vector2.LEFT)
			main.picked = {"type": "elem", "e": Elem.FIRE, "lv": 1}
			main._place_tower(c + Vector2(170, 0), Vector2.RIGHT)
			main.towers.get_child(0).add(Elem.FIRE, 1)
			main.towers.get_child(1).add(Elem.SOUND, 1)
			for t in main.towers.get_children():
				t.eff = t.eff_now()
			main.wave = 12
			main.offer = [{"type": "elem", "e": Elem.BLOOD, "lv": 2}, {"type": "elem", "e": Elem.ILLUSION, "lv": 1}, {"type": "elem", "e": Elem.POISON, "lv": 1}]
			main._show_offer()
			main._open_choose(),
		func():
			_snap("ne_cards")
			main._set_card_detail(true)
			main._tap_hover(),
		func():
			_snap("ne_cards_detail")
			main._set_card_detail(false)
			# 전장: 출혈·현혹 걸린 구체와 핏자국
			main._set_cards_hidden(true)
			var c: Vector2 = main.core()
			var bt: Tower = main.towers.get_child(0)
			var it: Tower = main.towers.get_child(1)
			for i in 6:
				var o := Orb.new()
				o.main = main
				o.position = c + Vector2(-420 + i * 34, -60 + (i % 2) * 18)
				o.target = c
				o.setup(Orb.Kind.NORMAL, 999.0, 40.0)
				o.age = 1.0
				main.orbs.add_child(o)
				bt.hit(o, 0.0)
				o.bleed_pos = o.position
				o.position += Vector2(60, 0)
				o.gore_acc = 99.0
				o._blood_step(0.016)
				o.queue_redraw()
			for i in 3:
				var o := Orb.new()
				o.main = main
				o.position = c + Vector2(-380 + i * 50, 120)
				o.target = c
				o.setup(Orb.Kind.NORMAL, 999.0, 40.0)
				o.age = 1.0
				main.orbs.add_child(o)
				o.confuse(5.0)
				o.queue_redraw()
			it.hit(main.orbs.get_child(6), 0.0),
		func():
			_snap("ne_field")
			Input.warp_mouse(main.towers.get_child(0).get_global_transform_with_canvas().origin),
		func(): pass,
		func():
			_snap("ne_tip")
			main._set_cards_hidden(false)
			main._toggle_codex()
			main.codex_panel.tabs[0].pressed.emit(),
		func():
			_snap("ne_codex")
			(main.codex_panel.list.get_parent() as ScrollContainer).scroll_vertical = 100000,
		func(): _snap("ne_codex_end"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
	print("SHOT ", n)
	preload("res://tools/ui_check.gd").check(main, n)


func _process(_d) -> bool:
	f += 1
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
