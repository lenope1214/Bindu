extends SceneTree
## 초신성 그림 스크린샷: 별빛 게이지(별·행성), 85% 넘어 터질 자리 예고, 다 참, 터지는 순간·퍼지는 중.
## xvfb-run godot --rendering-driver opengl3 --path . -s tools/nova_shot.gd -- <폴더> [글자 크기] [touch]
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []
var st: Tower
var pl: Tower
var aim: Orb


func _orb(p: Vector2) -> Orb:
	var o := Orb.new()
	o.main = main
	o.position = p
	o.target = main.center()
	o.setup(Orb.Kind.NORMAL, 40.0, 0.0)
	o.age = 1.0
	main.orbs.add_child(o)
	return o


func _tower(p: Vector2, els: Array) -> Tower:
	var t := Tower.new()
	for e in els:
		t.add(e, 1)
	t.dir = Vector2.LEFT
	t.position = p
	t.main = main
	main.towers.add_child(t)
	return t


func _state(gauge: float, pgauge: float, nova_e := -1.0) -> void:
	st.star_sum = st.star_need() * gauge
	pl.star_sum = pl.star_need() * pgauge
	st.nova_aim = aim if gauge >= Tower.NOVA_WARN else null
	pl.nova_aim = null
	st.nova_fx = 0.0
	if nova_e >= 0.0:
		st.star_sum = 0.0
		st.nova_aim = null
		st.nova_fx = Tower.NOVA_FX_T * (1.0 - nova_e)
		st.nova_pos = aim.position
		st.nova_from = st.position
	st.t += 0.37
	pl.t += 0.37
	st.queue_redraw()
	pl.queue_redraw()


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
			main.wave = 12
			var c: Vector2 = main.center()
			st = _tower(c + Vector2(-150, 40), [Elem.STAR])
			pl = _tower(c + Vector2(110, 60), [Elem.STAR, Elem.FIRE])
			_tower(c + Vector2(-40, 110), [Elem.FIRE])
			aim = _orb(c + Vector2(-330, -170))
			for i in 6:
				_orb(aim.position + Vector2.from_angle(i * 1.1) * (45.0 + 12.0 * i))
			for i in 4:
				_orb(c + Vector2(320, -120) + Vector2.from_angle(i * 1.6) * 50.0)
			main.set_process(false)
			_state(0.4, 0.6),
		func(): pass,
		func(): _snap("nova_gauge"); _state(0.92, 1.0),
		func(): pass,
		func(): _snap("nova_warn"); _state(1.0, 1.0),
		func(): pass,
		func(): _snap("nova_full"); _state(0.0, 0.3, 0.12),
		func(): pass,
		func(): _snap("nova_burst"); _state(0.0, 0.3, 0.5),
		func(): pass,
		func(): _snap("nova_wave"),
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
