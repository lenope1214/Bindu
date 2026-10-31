extends SceneTree
## 정원 모드 화면 스크린샷: 시작 화면(정원·씨앗 나무 버튼), 씨앗 나무 창, 정원 상점(오른쪽 목록), 영웅 탭(고르기·레벨), 자동 정원사, 세로 화면, 놓기, 웨이브 중, 물러난 뒤, 특성 4장(열매), 리더보드(성장/순수 버튼).
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
			Garden.dew = 640.0
			for i in 5:
				main.picked = {"type": "elem", "e": Elem.ALL[i], "lv": 1}
				main._place_tower(main.core() + Vector2.from_angle(main.lanes[0] + i * 1.2) * 120.0, Vector2.from_angle(main.lanes[0] + i * 1.2))
			main.wave = 12
			Garden.best = 27
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
		func():
			# 씨앗 나무 열매 1: 특성 4장
			Garden.tree["fruit"] = 1
			Garden.boosted = true
			main.garden_perk_t = 30.0
			main._start_perk(),
		func(): pass,
		func(): _snap("g_perk4"),
		func():
			main._on_perk(main.perk_offer[0])
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


func _process(_d) -> bool:
	f += 1
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
