extends SceneTree
## 최근 판 기록(시험) 스크린샷: 기록 창. 인자: 저장 폴더 [글자 크기] [touch] [phone]
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
			Meta.recent = []
			Meta.add_recent(12, 18420, "불 직선탄 34%")
			Meta.add_recent(23, 71930, "전기 연쇄 번개 41%")
			Meta.map_id = "spiral"
			Meta.add_recent(31, 152400, "얼음 분사 28%")
			Meta.map_id = "plain",
		func(): main.menu_system._toggle_records(),
		func(): _snap("recent_records"),
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
