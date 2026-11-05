extends SceneTree
## 오브젝트 정보창 스크린샷: 별 여럿·바람 곁의 행성(별+영혼, 혼불)에 올렸을 때 기본 / Shift 자세히.
## 인자: 저장 폴더 [글자 크기] [touch] [phone]. 예) xvfb-run godot --path . -s tools/tip_shot.gd -- /tmp/shots 1.3 touch phone
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []
var planet


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
			for tp in Tutorial.TOPICS:
				Tutorial.seen[tp["id"]] = true
			main.progression_system._close_title(),
		func():
			if not main.legend_hidden:
				main._toggle_legend()
			var c: Vector2 = main.core()
			# 별 넷이 중앙 둘레에, 바람 하나, 행성(별2·영혼8 혼불) 하나
			for i in 4:
				main.picked = {"e": Elem.STAR, "lv": 2}
				main._place_tower(c + Vector2.from_angle(i * TAU / 4 + 0.5) * 130.0, Vector2.RIGHT)
				main.towers.get_child(i).add(Elem.FIRE + i, 3)
			main.picked = {"e": Elem.WIND, "lv": 3}
			main._place_tower(c + Vector2(-60, 200), Vector2.UP)
			main.picked = {"e": Elem.SOUL, "lv": 8}
			main._place_tower(c + Vector2(90, -150), Vector2.RIGHT)
			planet = main.towers.get_child(main.towers.get_child_count() - 1)
			planet.add(Elem.STAR, 2)
			planet.add(Elem.LIGHT, 2)
			planet.set_pattern("wisp")
			planet.add_mod("dice")
			main.wave = 32
			main.wave_time = 30.0
			for t in main.towers.get_children():
				t.dealt = 900.0 + 400.0 * t.get_index()
			main._skills_new_run(1)
			main._open_choose()
			main._set_cards_hidden(true),
		func(): _hover(),
		func(): _touch(),
		func(): _touch(),  # 마우스를 옮기면(warp) touch_ui가 꺼진다: 다음 프레임에 다시
		func(): _snap("tip_basic"); _detail(true),
		func(): _touch(),
		func(): _touch(),
		func(): _snap("tip_detail"); _detail(false),
	]


func _hover() -> void:
	VirtualInput.move(planet.get_global_transform_with_canvas().origin)


func _touch() -> void:
	VirtualInput.move(planet.get_global_transform_with_canvas().origin)
	main.touch_ui = touch
	if touch:
		main.touch_tip_t = 3.0


func _detail(on: bool) -> void:
	if touch:
		main.tip_detail = on
		return
	var ev := InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = on
	VirtualInput.send(ev)


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
