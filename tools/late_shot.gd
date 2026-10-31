extends SceneTree
## 후반 구체 다섯 종 스크린샷: 처음 나오는 웨이브 안내(NEW 배지·말풍선)와 전장 위 모양(깜빡 예고·갑옷 깨짐·치유 맥동·흐림·포식).
## xvfb-run godot --rendering-driver opengl3 --path . -s tools/late_shot.gd -- <폴더> [글자 크기] [touch]
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []


func _orb(p: Vector2, id: String) -> Orb:
	var o := Orb.new()
	o.main = main
	o.position = p
	o.target = main.center()
	o.setup(Orb.Kind.NORMAL, 40.0, 0.0)
	o.late = id
	o.age = 1.0
	main.orbs.add_child(o)
	return o


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.tut_first = false
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main._apply_ui_scale()
			main._hide_title()
			main.tut.close()
			main.tutor = false,
		func():
			main.tut.close()
			main.wave = 99
			main.lanes.clear()
			main._roll_lanes()
			main._update_preview()
			main.queue_redraw(),
		func():
			# 안내 배지에 마우스를 올린 것처럼: 첫 진입 화살표 말풍선
			if not main.tip_rects.is_empty():
				Input.warp_mouse(main.tip_rects[0][0].get_center()),
		func(): _snap("late_preview_100"); main.wave = 499; main._update_preview(),
		func(): pass,
		func():
			if not main.tip_rects.is_empty():
				Input.warp_mouse(main.tip_rects[0][0].get_center()),
		func(): _snap("late_preview_500"); Input.warp_mouse(Vector2(5, 360)); main._start_wave(),
		func():
			for o in main.orbs.get_children():
				o.free()
			main.to_spawn = 0
			var c: Vector2 = main.center()
			var b := _orb(c + Vector2(-330, -150), "blink")
			b.late_t = 0.4
			var ar := _orb(c + Vector2(-150, -190), "armor")
			ar.armor = 5.0
			ar.armor_hits = 15.0
			var m := _orb(c + Vector2(80, -200), "mender")
			m.heal_fx = 0.2
			for i in 3:
				_orb(c + Vector2(80, -200) + Vector2.from_angle(i * 2.0) * 70.0, "")
			var ph := _orb(c + Vector2(300, -120), "phase")
			ph.late_t = 3.0
			ph.modulate.a = 0.45
			var ph2 := _orb(c + Vector2(330, 60), "phase")
			ph2.late_t = 2.3
			var dv := _orb(c + Vector2(-320, 150), "devour")
			dv.eaten = 7
			dv.max_hp = 200.0; dv.hp = 200.0
			main.set_process(false)
			for o in main.orbs.get_children():
				o.queue_redraw(),
		func(): pass,
		func(): _snap("late_orbs"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s.png" % [n, z, "_touch" if touch else ""]))
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
