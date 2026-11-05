extends SceneTree
## 플레이 튜토리얼 화면 스크린샷 (features TUT-08 shot). 단계마다 안내 칸·강조·카드가 겹치거나 잘리지 않는지 눈으로 본다.
## tools/run.sh ui tut_play_shot.gd <폴더> [글자 크기] [touch] [phone]
var main
var tp: TutPlay
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []


func _initialize():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"):
		quit(2)
		return
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	Meta.sim_phone = a.size() > 3 and a[3] == "phone"
	if Meta.sim_phone and DisplayServer.window_get_size().x > DisplayServer.window_get_size().y * 2:
		Meta.sim_safe = Rect2(86, 0, 86, 38)
	DirAccess.make_dir_recursive_absolute(out)
	TutPlay.pending = 0
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main.hud_system._apply_ui_scale()
			tp = main.tplay,
		func(): _snap("tp01_goal"); tp.skip_step(),
		func(): _snap("tp02_place"); _to("aim"),
		func(): _snap("tp03_aim"); _to("wave1"),
		func(): _snap("tp04_wave"); _to("move"),
		func(): _snap("tp05_move"); _to("turn"),
		func(): main._start_move(tp._first(Elem.FIRE)); main.aim_d = Vector2.UP; main.aim_wait = true,
		func(): _snap("tp06_turn"); main._cancel_step(); _to("stack"),
		func(): _snap("tp08_stack"); _to("pat"),
		func(): _snap("tp10_pat"); _to("tools"),
		func(): _snap("tp13_tools"); main._set_cards_hidden(true),
		func(): _snap("tp13_tools_field"); main._set_cards_hidden(false); _to("link"),
		func(): _snap("tp15_link"); _to("info"),
		func(): _snap("tp16_info"); _to("preview"),
		func(): _snap("tp17_preview"); _to("ley"),
		func(): _snap("tp18_ley"); tp.skip_step(),
		func(): _snap("tp_gate"); _to("skill"),
		func(): _snap("tp19_skill"); _to("speed"),
		func(): _snap("tp20_speed"); main._toggle_pause(),
		func(): _snap("tp20_paused"); main._toggle_pause(); _to("perk"),
		func(): _snap("tp21_wave_boss"); tp._clear_wave(),
		func(): pass,
		func(): pass,
		func(): _snap("tp21_perk"); _to("skip"),
		func(): _snap("tp22_skip"); tp.ask_quit(),
		func(): _snap("tp_ask"); tp._close_ask(); _to("end"),
		func(): _snap("tp23_end"),
	]


var goal := ""  # 이 단계에 닿을 때까지 몇 프레임마다 [건너뛰기] (웨이브는 실제로 지나간다)
var wait_n := 0


## 그 단계까지 건너뛰기로 간다 (_process가 닿을 때까지 다음 장면을 미룬다).
func _to(id: String) -> void:
	goal = id
	wait_n = 0


func _snap(n: String):
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
	print("SHOT ", n, " step=", tp.step().get("id", "") if tp else "")
	preload("res://tools/ui_check.gd").check(main, n)


var si := 0  # 다음에 부를 장면


func _process(_d) -> bool:
	if goal != "":
		wait_n += 1
		if tp.step().get("id", "") == goal and (tp._active() or goal == "end" and tp.end_box.visible) and tp.done_t < 0.0:
			goal = ""
			f = 0
		elif wait_n % 6 == 0:
			tp.done_t = -1.0
			if main.phase == main.Phase.WAVE:
				main.game_speed = 8.0
			tp.skip_step()
		if wait_n > 3000:
			print("SHOT FAIL 닿지 못함 %s 지금 %s wave=%d phase=%d picks=%d active=%s offer=%s perk=%s coin=%d skip=%d" % [goal, tp.step().get("id", ""), main.wave, main.phase, main.picks_left, tp._active(), str(main.offer), main.perk_mode, main.coin_stage, main.skip_left])
			quit(1)
		return false
	f += 1
	if f >= 20:
		f = 0
		if si < steps.size():
			si += 1
			steps[si - 1].call()
		else:
			quit()
	return false
