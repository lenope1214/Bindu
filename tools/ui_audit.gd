extends SceneTree
## 게임 중 화면 배치 점검: 진입 배지가 점수 줄·DPS 표·오른쪽 위 버튼·웨이브 시작 버튼·아래 안내에 닿는 방향으로 길목을 두고,
## 큰 숫자·긴 이름·오브젝트 많이·특성 많이로 꽉 채워 찍는다. 찍을 때마다 tools/ui_check.gd로 겹침·화면 밖을 줄로 찍는다.
## xvfb-run godot --path . --rendering-driver opengl3 --resolution 2556x1179 -s tools/ui_audit.gd -- <폴더> [글자 크기] [touch] [phone]
const UiCheck = preload("res://tools/ui_check.gd")
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []
var bad := 0


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	Meta.sim_phone = a.size() > 3 and a[3] == "phone"
	if Meta.sim_phone and DisplayServer.window_get_size().x > DisplayServer.window_get_size().y * 2:
		Meta.sim_safe = Rect2(86, 0, 86, 38)  # 노치 있는 폰 가로: 양옆 노치·둥근 모서리, 아래 홈 막대
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	steps = [
		func():
			Meta.guide_on = false
			main.onboarding_system.tut_first = false
			if main.tut and main.tut.panel.visible:
				main.tut.close()
			Meta.ui_scale = z
			main.touch_ui = touch
			main.hud_system._apply_ui_scale()
			Meta.games = 1  # 아래 안내(READY_HINT)가 보이는 첫 판들
			Meta.map_id = "plain"
			Meta.rules = 1
			main.persistence_system._clear_run(); main.progression_system._hide_title(); main.lanes.clear(); main.run_flow_system._start_choose(),
		func():
			# 오브젝트 많이 + 지난 웨이브 피해 (DPS 표가 뜨게)
			for i in 14:
				main.picked = {"e": Elem.ALL[i % Elem.ALL.size()], "lv": 3}
				main.interaction_system._place_tower(main.core() + Vector2.from_angle(i * 0.45) * (120.0 + (i % 3) * 70.0), Vector2.RIGHT)
			for t in main.towers.get_children():
				t.dealt = 100000.0 + randf() * 900000.0
			main.wave = 39  # 다음이 보스 웨이브(40), 섞여 나오는 종류 전부
			main.wave_time = 40.0
			main.score = 98765432109
			main.best_score = 123456789012
			main.best_wave = 88
			for pk in main.PERKS.slice(0, 8):
				main.perks[pk["id"]] = 3
			# 길목: 왼쪽 위(점수 줄·DPS 표), 위, 오른쪽 위(버튼), 아래(웨이브 시작·안내), 오른쪽 아래(속도 줄), 왼쪽 아래(버전)
			main.lanes.assign([-2.5, -1.57, -0.45, 1.57, 0.55, 2.55, PI])
			main.waves_system._update_preview()
			main.picks_left = 0
			main.cards_system._enter_ready()
			main.legend_hidden = false
			main.menu_system._refresh_legend(),
		func(): _snap("ready"),
		func():
			main.legend_hidden = true
			main.menu_system._refresh_legend(),
		func(): _snap("ready_nolegend"); main.leak_marks = [[-2.5, 12], [-0.45, 3], [1.57, 140]],
		func(): _snap("ready_leak"); main.start_btn.visible = false; main.run_flow_system._start_choose(true),  # 실제로는 웨이브가 끝나야 고르기라 [웨이브 시작]은 없다
		func():
			main.legend_hidden = false
			main.menu_system._refresh_legend(),
		func(): _snap("choose"),
		func(): main.legend_hidden = true; main.menu_system._refresh_legend(),
		func(): _snap("choose_nolegend"); main.leak_marks = []; main.run_flow_system._start_wave(),
		func(): main.score = 98765432109; main.hud_system._update_hud(true),
		func(): _snap("wave"); main.hud_system._show_toast("업적: 아주 긴 업적 이름이 여기에 들어갑니다 · 칭호 해금"); main.hud_system.big_banner("웨이브 40 · 보스", Color.WHITE),
		func(): _snap("wave_toast"),
	]


func _snap(n: String):
	main.info.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
	print("SHOT ", n)
	bad += UiCheck.check(main, n)


func _process(_d) -> bool:
	f += 1
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			print("UI BAD ", bad)
			quit()
	return false
