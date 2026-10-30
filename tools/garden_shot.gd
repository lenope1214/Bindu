extends SceneTree
## 정원 모드 화면 스크린샷: 시작 화면(정원·씨앗 나무 버튼), 씨앗 나무 창, 정원 상점, 웨이브 중, 환생 버튼, 꺼 둔 동안 보상.
## 인자: 저장 폴더 [글자 크기]. 예) xvfb-run godot --rendering-driver opengl3 --path . -s tools/garden_shot.gd -- /tmp/shots
var main
var f := 0
var out := "/tmp"
var z := 1.0
var steps: Array = []


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	if FileAccess.file_exists(Garden.RUN_PATH):
		DirAccess.remove_absolute(Garden.RUN_PATH)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func():
			Meta.ui_scale = z
			Meta.games = maxi(Meta.games, 1)
			Garden.seeds = 23
			Garden.seeds_total = 40
			Garden.rebirths = 1
			Garden.best_ever = 43
			Garden.tree = {"root": 2, "stem": 1}
			Garden.mastery = {"fire": 6200.0, "wood": 1200.0, "ice": 300.0}
			main._apply_ui_scale()
			main._refresh_menu(),
		func(): _snap("g_title"),
		func(): main._toggle_tree(),
		func(): _snap("g_tree"),
		func():
			main._toggle_tree()
			main._enter_garden(),
		func():
			Garden.dew = 640.0
			for i in 5:
				main.picked = {"type": "elem", "e": Elem.ALL[i], "lv": 1}
				main._place_tower(main.core() + Vector2.from_angle(main.lanes[0] + i * 1.2) * 120.0, Vector2.from_angle(main.lanes[0] + i * 1.2))
			main.wave = 12
			Garden.best = 27
			main._garden_rest(true),
		func(): _snap("g_shop"),
		func():
			main._on_pick(main.offer[0]),
		func(): _snap("g_place"),
		func():
			main._cancel_step()
			main._start_wave(),
		func(): pass,
		func(): pass,
		func(): _snap("g_wave"),
		func():
			main.game_speed = 8.0,
		func(): pass,
		func(): pass,
		func(): pass,
		func(): pass,
		func(): pass,
		func(): pass,
		func(): _snap("g_after"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [n, z]))
	print("SHOT ", n, " phase=", main.phase, " wave=", main.wave, " dew=", int(Garden.dew))


func _process(_d) -> bool:
	f += 1
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
