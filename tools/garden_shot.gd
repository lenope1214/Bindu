extends SceneTree
## 정원(키우기형) 화면 스크린샷: 시작 화면, 씨앗 나무 창, 정원 칸 목록(오른쪽), 영웅 탭(고르기·레벨), 자동 정원사, 세로 화면, 심을 속성 고르기, 단계 중, 그 뒤, 리더보드(성장/순수 버튼).
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
	Tutorial.load_file()  # 튜토리얼 창이 화면을 가리지 않게 (본 것으로 저장)
	Tutorial.done = true
	for tp in Tutorial.TOPICS:
		Tutorial.seen[tp["id"]] = true
	Tutorial.save_file()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Garden.auto_buy = false  # 자동 정원사는 기본 켬: 점검·촬영·봇은 직접 산다
	current_scene = main
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
			Garden.auto_buy = false
			Garden.dew = 640.0
			Garden.best = 27
			for i in 6:
				Garden.slots[i] = {"e": [Elem.FIRE, Elem.WATER, Elem.ELECTRIC, Elem.WOOD, Elem.LIGHT, Elem.ICE][i], "lv": [34, 22, 18, 9, 4, 1][i], "seed": 11 + i}
			main._grow_rebuild()
			main.wave = 12
			main._garden_rest(true),
		func(): _snap("g_shop"); main.gp_tab = "hero"; Garden.hero_free = true; Garden.hero_e = -1,
		func(): pass,
		func(): _snap("g_hero_pick"); Garden.hero_xp = {"fire": 900.0}; Garden.set_hero(Elem.FIRE); main.gp_sig = "",
		func(): pass,
		func(): _snap("g_hero"); main.gp_tab = "shop"; Garden.auto_buy = true,
		func(): pass,
		func(): pass,
		func(): _snap("g_auto"); Garden.auto_buy = false; root.get_window().size = Vector2i(720, 1440),
		func(): pass,
		func(): pass,
		func(): _snap("g_portrait"); root.get_window().size = Vector2i(1280, 720),
		func(): pass,
		func():
			main.gp_pick_slot = 6
			main.gp_sig = "",
		func(): pass,
		func(): _snap("g_place"); main.gp_pick_slot = -1; main.gp_sig = "",
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
		func():
			main._leave(false),
		func(): pass,
		func():
			main = current_scene
			main._toggle_board(),
		func(): pass,
		func(): _snap("g_board"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [n, z]))
	print("SHOT ", n, " phase=", main.phase, " wave=", main.wave, " dew=", int(Garden.dew))
	preload("res://tools/ui_check.gd").check(main, n)  # 겹침·화면 밖 (UI OVERLAP 줄)


func _process(_d) -> bool:
	f += 1
	if f < 4:
		Garden.auto_buy = false  # 저장된 설정을 읽은 뒤에
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
