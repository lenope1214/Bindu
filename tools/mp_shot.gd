extends SceneTree
## 멀티플레이 화면 스크린샷 (연결 없이 상태만 채워서): 시작 화면 버튼, 방 화면, 대결 상태 줄, 협동 고리 색.
## xvfb-run godot --path . -s tools/mp_shot.gd -- <저장 폴더> [글자 크기] [touch] [vs|coop]
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var mode := "vs"
var steps: Array = []


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	if a.size() > 3: mode = a[3]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func():
			Meta.guide_on = false  # 튜토리얼(처음 켤 때·멀티플레이 처음)이 화면을 가리지 않게
			main.tut_first = false
			if main.tut and main.tut.panel.visible:
				main.tut.close()
			Meta.ui_scale = z
			main.touch_ui = touch
			main._apply_ui_scale()
			Meta.games = 5
			main._refresh_menu()
			main.mp_btn.visible = true,
		func(): _snap("mp_title"); main._toggle_mp_lobby(),
		func():
			_snap("mp_lobby")
			main.mp.my_id = 2  # 참가자: 방에 들어왔지만 호스트와 아직 안 이어짐 → 도는 고리
			main.mp.code = "K7QX2M"
			main.mp.mode = mode
			main.mp.joined_ms = Time.get_ticks_msec() - 6000
			main.mp.peers = {1: {"name": "빈두장인", "pf": "windows", "conn": null, "ok": false}, 2: {"name": "민수", "pf": "ios", "conn": null, "ok": true}}
			main._mp_refresh_lobby(),
		func():
			_snap("mp_wait_host")
			main.mp.my_id = 1
			main.mp.code = "K7QX2M"
			main.mp.mode = mode
			main.mp.peers = {1: {"name": "빈두장인", "pf": "windows", "conn": null, "ok": true}, 2: {"name": "민수", "pf": "ios", "conn": null, "ok": true}, 3: {"name": "", "pf": "android", "conn": null, "ok": false}, 4: {"name": "맥유저", "pf": "mac", "conn": null, "ok": false}}
			main.mp.diag_sent = {4: true}
			main.mp.ping = {2: 38, 3: 212}
			main._mp_refresh_lobby(),
		func():
			_snap("mp_room_" + mode)
			main._mp_begin({"mode": mode, "seed": 77, "map": "plain", "rules": 1, "ids": [1, 2, 3], "names": {1: "빈두장인", 2: "민수", 3: ""}})
			if mode == "vs":
				main.mp_others[2].merge({"w": 7, "hp": 6, "mx": 10, "sc": 4210}, true)
				main.mp_others[3].merge({"w": 5, "alive": false, "sc": 1980}, true)
				main.mp_next_extra = 3
				main._update_preview()
			else:
				main.mp_others[3]["gone"] = true
			for i in 4:
				main.picked = {"e": Elem.ALL[i], "lv": 1}
				main._place_tower(main.center() + Vector2.from_angle(i * 1.6) * 140.0, Vector2.from_angle(i * 1.6))
				if mode == "coop":
					main.towers.get_child(i).owner_id = 1 + i % 3,
		func(): _snap("mp_rest_" + mode); main.phase = main.Phase.READY; main._enter_ready(); main.mp_wave_go = true; main._start_wave(); main.mp_wave_go = false,
		func(): _snap("mp_wave_" + mode); main._game_over(),
		func(): _snap("mp_over_" + mode),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s.png" % [n, z, "_touch" if touch else ""]))
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
