extends SceneTree
## 방향 바꾸기 스크린샷: 오브젝트 하나 선택(아래 상태 칸 "한 번 더 …: 방향") → 한 번 더 누름(방향 편집).
## 인자: 저장 폴더 [글자 크기] [touch] [phone]. 예) tools/run.sh ui aim_shot.gd /tmp/aim 1.3 touch
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []
var t


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	Meta.sim_phone = (a.size() > 3 and a[3] == "phone") or (a.size() > 2 and a[2] == "phone")
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main.hud_system._apply_ui_scale()
			main.onboarding_system.tut_first = false
			Meta.games = 5
			Meta.guide_on = false
			Tutorial.loaded = true
			for tp in Tutorial.TOPICS:
				Tutorial.seen[tp["id"]] = true
			main.progression_system._close_title(),
		func():
			main.tut.visible = false
			var c: Vector2 = main.viewport_system.core()
			main.picked = {"e": Elem.FIRE, "lv": 2}
			main.interaction_system._place_tower(c + Vector2(140, -60), Vector2.RIGHT)
			main.picked = {"e": Elem.WATER, "lv": 2}
			main.interaction_system._place_tower(c + Vector2(-150, 80), Vector2.LEFT)
			t = main.towers.get_child(0)
			main.cards_system._enter_ready(),
		func():
			main.touch_ui = touch
			main.interaction_system._select_tower(t),
		func(): main.touch_ui = touch,
		func():
			_snap("aim_selected")
			main.touch_ui = touch
			main.interaction_system.pointer_position = t.get_global_transform_with_canvas().origin
			main.interaction_system.press_t = t
			main.interaction_system.dragging = false
			main.interaction_system._release_press(),
		func(): main.touch_ui = touch,
		func(): _snap("aim_again"),
	]


func _snap(n: String):
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
	print("SHOT ", n, " phase=", main.phase, " moving=", main.interaction_system.moving == t)


func _process(_d) -> bool:
	f += 1
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
