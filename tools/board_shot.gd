extends SceneTree
## 리더보드 창 스크린샷: 서버 없이 순위를 채워 기본·이번 주·지난 시즌·빈 기록·신고·차단 창을 찍는다.
## 인자: 저장 폴더 [글자 크기] [touch] [phone]. 예) xvfb-run godot --path <사본> --rendering-driver opengl3 --resolution 2556x1179 -s tools/board_shot.gd -- /tmp/b 1.3 touch phone
## 사본의 online_config SERVER_URL은 http://127.0.0.1:9로 (실제 서버에 닿지 않게)
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []


func _fill(n: int, week: int) -> void:
	var es := []
	for i in n:
		es.append({"rank": i + 1, "nick": "닉네임%d" % i if i != 2 else "아주긴닉네임열두글자까지", "wave": 40 - i, "score": 9000000 - i * 1000, "me": i == 3, "ended": i != 1, "pid": "p%015d" % i, "title": "wave10" if i == 0 else ""})
	main.leaderboard_system._on_board_loaded({"tag": main.leaderboard_system._board_tag(), "period": "all", "season": {"name": "시즌 2"}, "entries": es, "total": 57})
	if main.leaderboard_system.board_season == 0:
		main.leaderboard_system._on_board_loaded({"tag": main.leaderboard_system._board_tag(), "period": "week", "entries": es.slice(0, week), "total": 12, "me": {"rank": 15, "score": 120000}})


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	Meta.sim_phone = a.size() > 3 and a[3] == "phone"
	if Meta.sim_phone and DisplayServer.window_get_size().x > DisplayServer.window_get_size().y * 2:
		Meta.sim_safe = Rect2(86, 0, 86, 38)
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main.hud_system._apply_ui_scale()
			Meta.games = 5
			if main.tut.visible: main.tut.close(),
		func():
			main.leaderboard_system._toggle_board(),
		func():
			# 서버 없이: 연결 실패(빈 시즌 목록·오류)가 먼저 온 뒤에 덮어쓴다
			main.leaderboard_system._on_seasons_loaded([{"id": 3, "name": "시즌 3"}, {"id": 2, "name": "시즌 2"}, {"id": 1, "name": "시즌 1"}])
			_fill(10, 5),
		func(): _snap("board"); _press_period(1),
		func(): _snap("board_week"); _press_period(0); main.leaderboard_system._board_set("season", 2); _fill(10, 0),
		func(): _snap("board_old"); main.leaderboard_system._board_set("map", "line"); _fill(0, 0),
		func(): _snap("board_empty"); main.leaderboard_system._board_set("season", 0); _fill(10, 5),
		func(): main.leaderboard_system._board_ugc_open(),
		func(): _snap("board_ugc"),
	]


func _press_period(i: int) -> void:
	if "board_period_btns" in main and main.leaderboard_system.board_period_btns.size() > i:
		main.leaderboard_system.board_period_btns[i].pressed.emit()


func _snap(n: String):
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
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
