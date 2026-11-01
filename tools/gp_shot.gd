extends SceneTree
## 정원 목록 패널 스크린샷(세로 폰·PC): 정원 탭(칸 여러 개·스크롤), 영웅 탭.
## 인자: 저장 폴더 [phone]. 예) xvfb-run godot --rendering-driver opengl3 --path . --resolution 1179x2556 -s tools/gp_shot.gd -- /tmp/shots phone
var main
var f := 0
var out := "/tmp"
var tag := "pc"
var steps: Array = []


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	Meta.sim_phone = a.size() > 1 and a[1] == "phone"
	tag = "phone" if Meta.sim_phone else "pc"
	if FileAccess.file_exists(Garden.RUN_PATH):
		DirAccess.remove_absolute(Garden.RUN_PATH)
	Tutorial.load_file()
	Tutorial.done = true
	for tp in Tutorial.TOPICS:
		Tutorial.seen[tp["id"]] = true
	Tutorial.save_file()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	steps = [
		func():
			Meta.games = maxi(Meta.games, 1)
			main.touch_ui = Meta.sim_phone
			main._enter_garden(),
		func():
			Garden.auto_buy = false
			Garden.dew = 640.0
			Garden.best = 27
			for i in 6:
				Garden.slots[i] = {"e": [Elem.ICE, Elem.SOUND, Elem.WATER, Elem.EARTH, Elem.LIGHT, Elem.FIRE][i], "lv": [24, 23, 23, 23, 9, 1][i], "seed": 11 + i}
			main._grow_rebuild()
			main.wave = 14
			main._garden_rest(true),
		func(): pass,
		func(): _snap("gp_shop"),
		func(): main.gp_tab = "hero"; Garden.hero_xp = {"fire": 300.0}; Garden.hero_free = true; Garden.set_hero(Elem.FIRE); main.gp_sig = "",
		func(): pass,
		func(): _snap("gp_hero"); main.gp_tab = "shop"; main.gp_sig = "",
		func(): pass,
		func(): _drag_test(),
		func(): pass,
		func(): _snap("gp_scrolled"); Garden.dew = 9000.0; main.gp_scroll.scroll_vertical = 0; main.gp_pick_slot = 6; main.gp_sig = "",
		func(): pass,
		func(): _snap("gp_pick"),
	]


## 목록 끌기: 칸 위에서 눌러 위로 끌고 떼면 스크롤만 되고 칸은 안 키워져야 한다. 끌지 않고 떼면 키워진다.
func _drag_test():
	var sc: ScrollContainer = main.gp_scroll
	var r := sc.get_global_rect()
	var p := r.position + Vector2(r.size.x * 0.4, r.size.y * 0.6)
	var lv0 := _levels()
	_mouse(p, true)
	for k in 8:
		_motion(p - Vector2(0, 30 * (k + 1)))
	_mouse(p - Vector2(0, 240), false)
	print("DRAG scroll=", sc.scroll_vertical, " levels_same=", _levels() == lv0)
	var q := r.position + Vector2(r.size.x * 0.4, 40)
	_mouse(q, true)
	_mouse(q, false)
	print("TAP levels_changed=", _levels() != lv0)
	var sv := sc.scroll_vertical
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	w.pressed = true
	w.position = root.get_final_transform() * q
	root.push_input(w)
	print("WHEEL scroll ", sv, " -> ", sc.scroll_vertical)


func _levels() -> String:
	return str(Garden.slots.map(func(x): return x.get("lv", 0)))


func _mouse(p0: Vector2, down: bool):
	var p := root.get_final_transform() * p0  # 뷰포트 좌표 → 창 좌표 (세로 화면은 늘려 그린다)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(e)


func _motion(p0: Vector2):
	var p := root.get_final_transform() * p0
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e)


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [n, tag]))
	print("SHOT ", n)
	preload("res://tools/ui_check.gd").check(main, n)


func _process(_d) -> bool:
	f += 1
	if f < 4:
		Garden.auto_buy = false
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
