extends SceneTree
## 그린 궤적 화면 스크린샷: 카드·그리는 중(꺾기·길이 다 씀)·떼고 [적용] 기다림·쉬는 시간 길·웨이브 중 탄·레벨업 미리보기.
## 인자: 저장 폴더 [글자 크기] [touch]. 예) xvfb-run godot --path . -s tools/path_shot.gd -- /tmp/shots 1.3
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []
var t: Tower
var tp: Vector2


func _drag(a: Vector2, b: Vector2) -> void:
	var n := ceili(a.distance_to(b) / 4.0)
	for i in n + 1:
		main._draw_extend(a.lerp(b, float(i) / n))


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func():
			Meta.ui_scale = z
			main._apply_ui_scale()
			main._close_title(),
		func():
			main._close_title()
			main.touch_ui = touch
			for i in 4:
				main.picked = {"type": "elem", "e": Elem.ALL[i], "lv": 1}
				main._place_tower(main.core() + Vector2.from_angle(i * 1.6 + 0.4) * 170.0, Vector2.RIGHT)
			tp = main.core() + Vector2(-380, -60)
			main.picked = {"type": "elem", "e": Elem.FIRE, "lv": 2}
			main._place_tower(tp, Vector2.RIGHT)
			t = main.towers.get_child(main.towers.get_child_count() - 1)
			main.wave = 12
			main.offer = [{"type": "pat", "id": "path"}, {"type": "mod", "id": "pierce"}, {"type": "elem", "e": Elem.WOOD, "lv": 1}]
			main._show_offer()
			main._open_choose(),
		func():
			_snap("path_card")
			main._on_pick(main.offer[0])
			main._place_on(t),
		func():
			_snap("path_draw_start")
			main.draw_pts.append(t.position)
			_drag(tp, tp + Vector2(160, 0))
			_drag(tp + Vector2(160, 0), tp + Vector2(160, 140))
			_drag(tp + Vector2(160, 140), tp + Vector2(240, 140)),
		func():
			_snap("path_drawing")
			_drag(tp + Vector2(240, 140), tp + Vector2(240, 400)),
		func():
			_snap("path_draw_full")
			main._draw_release(),  # 손을 뗌: [적용]/[취소]를 기다림
		func():
			_snap("path_wait")
			main.draw_ok_btn.pressed.emit(),
		func():
			_snap("path_rest")
			root.get_viewport().warp_mouse(root.get_viewport().get_canvas_transform() * t.position),
		func():
			_snap("path_hover")
			if main.lanes.is_empty():
				main._roll_lanes()
			main._start_wave(),
		func(): pass,
		func(): pass,
		func(): pass,
		func(): pass,
		func(): _snap("path_wave"),
		func():
			main.wave_active = false
			main.phase = main.Phase.CHOOSE
			t.plv = 3
			main.picked = {"type": "pat", "id": "path"}
			main.picks_left = 3
			main._apply_card(t),
		func(): _snap("path_branch"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s.png" % [n, z, "_touch" if touch else ""]))
	print("SHOT ", n)
	preload("res://tools/ui_check.gd").check(main, n)  # 겹침·화면 밖 (UI OVERLAP 줄)


func _process(_d) -> bool:
	f += 1
	if main.tut.visible:
		main.tut.close()  # 처음 켠 기기면 그때그때 뜨는 튜토리얼이 화면을 가린다
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
