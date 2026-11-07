extends SceneTree
## 자연 현상 스크린샷(브랜치 elements-nature): 덩굴 회로·증기·문턱 게이지·상태 점.
## tools/run.sh ui nature_shot.gd <폴더> [글자 크기] [touch]
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []


func _orb(p: Vector2, hp := 40.0) -> Orb:
	var o := Orb.new()
	o.main = main
	o.position = p
	o.target = main.viewport_system.center()
	o.setup(Orb.Kind.NORMAL, hp, 0.0)
	o.age = 1.0
	main.orbs.add_child(o)
	return o


func _tower(p: Vector2, els: Array) -> Tower:
	var t := Tower.new()
	for e in els:
		t.add(e[0], e[1])
	t.dir = Vector2.RIGHT
	t.position = p
	t.main = main
	main.towers.add_child(t)
	t.eff = t.eff_now()
	return t


func _clear() -> void:
	for n in [main.towers, main.orbs, main.zones, main.projectiles]:
		for c in n.get_children():
			c.free()
	main.beams.clear()
	main.bolts.clear()
	main.pulses.clear()
	main.arcs.clear()


func _grid() -> void:
	main.combat_system.targets = main.orbs.get_children()
	main.live_orbs = main.orbs.get_children()
	main.combat_system._build_grid()


func _scene(kind: String) -> void:
	_clear()
	Nature.reset()
	var c: Vector2 = main.viewport_system.center()
	var wt := _tower(c + Vector2(-300, -60), [[Elem.WATER, 2], [Elem.WOOD, 1]])
	var et := _tower(c + Vector2(-300, 80), [[Elem.ELECTRIC, 2]])
	var ft := _tower(c + Vector2(-300, 200), [[Elem.FIRE, 2]])
	var orbs: Array = []
	for i in 7:
		orbs.append(_orb(c + Vector2(-60 + i * 70, -40 + (i % 2) * 50), 40.0))
	_grid()
	for o in orbs:
		Nature.touch(wt, o, Elem.WATER, 1.0)
		o.vine = 2.0
		o.gauge[Elem.ELECTRIC] = randf_range(30.0, 85.0)
		o.gauge[Elem.WOOD] = randf_range(20.0, 60.0)
		o.gauge_src[Elem.ELECTRIC] = et
	match kind:
		"circuit":
			Nature.electric(et, orbs[0], 6.0)
		"steam":
			for o in orbs:
				o.nat_cd = 0.0
			Nature.touch(ft, orbs[3], Elem.FIRE, 1.0)
		"burst":
			orbs[2].gauge[Elem.ELECTRIC] = 99.0
			Nature.fill(et, orbs[2], Elem.ELECTRIC, 2, 1.0)
			Nature.tick(0.2)
	main.fx_layer.queue_redraw()
	for n in [main.towers, main.zones, main.orbs]:
		for x in n.get_children():
			x.queue_redraw()


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	main.onboarding_system.tut_first = false
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main.hud_system._apply_ui_scale()
			main.progression_system._hide_title()
			main.tut.close()
			main.tutor = false
			main.wave = 12,
		func():
			main.tut.close()
			main.set_process(false),
	]
	for k in ["circuit", "steam", "burst"]:
		var kk: String = k
		steps.append(func(): _scene(kk))
		steps.append(func(): pass)
		steps.append(func(): _snap("nature_" + kk))


func _snap(n: String):
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s.png" % [n, z, "_touch" if touch else ""]))
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
