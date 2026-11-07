extends SceneTree
## 섞인 보조 공격 스크린샷: 번개 3마리·물폭탄(묻힌 구체가 지나간 길)·그림자 낙하·유성·핏줄·휩쓸기, 정보창 이름 줄.
## tools/run.sh ui side_shot.gd <폴더> [글자 크기] [touch]
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


func _scene(els: Array, orbs: Array, hp := 40.0, move := false) -> void:
	_clear()
	var c: Vector2 = main.viewport_system.center()
	var t := _tower(c + Vector2(-260, 40), els)
	for p in orbs:
		_orb(c + p, hp)
	_grid()
	var near: Orb = Side.nearest(t, Rules.t("side_r"))
	if near == null:
		near = main.orbs.get_child(0)
	Side.mix_hit(t, near, false, true)  # 시간 '한 번 더'는 빼고 한 번만
	if move:
		# 묻힌 구체를 앞으로 걸려 지나간 길에 장판이 남는 모습
		for i in 14:
			near.position += Vector2(12, -6)
			Side.smear_pt(near)
	main.fx_layer.queue_redraw()
	for n in [main.towers, main.zones]:
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
	var pack := [Vector2(-40, -150), Vector2(40, -170), Vector2(110, -130), Vector2(180, -60), Vector2(60, 60), Vector2(260, 120), Vector2(380, -200), Vector2(420, 40)]
	var shots := [
		["side_elec", [[Elem.ELECTRIC, 2], [Elem.METAL, 1]], pack, false],
		["side_water", [[Elem.WATER, 2], [Elem.ICE, 1]], pack, true],
		["side_dark", [[Elem.DARK, 2], [Elem.POISON, 1]], pack + [Vector2(500, 250)], false],
		["side_star", [[Elem.STAR, 2], [Elem.LIGHT, 1]], pack, false],
		["side_blood", [[Elem.BLOOD, 2], [Elem.WOOD, 1]], pack, false],
		["side_sweep", [[Elem.WOOD, 2], [Elem.EARTH, 1]], pack, false],
	]
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
	for s in shots:
		var ss: Array = s
		steps.append(func(): _scene(ss[1], ss[2], 9e5 if ss[0] == "side_dark" else 8.0, ss[3]))
		steps.append(func(): pass)
		steps.append(func(): _snap(ss[0]))


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
