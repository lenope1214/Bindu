extends SceneTree
## 화면 배치 점검용 스크린샷: 시작 화면(줄이 가장 많을 때)·그 위 창들·카드·특성·일시정지·게임 오버.
## 인자: 저장 폴더 [글자 크기]. 예) xvfb-run godot --path . -s tools/shot.gd -- /tmp/shots 1.3
var main
var f := 0
var out := "/tmp"
var z := 1.0
var steps: Array = []


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func():
			Meta.ui_scale = z
			main._apply_ui_scale()
			# 가장 긴 시작 화면: 회랑(좌우 줄)·규칙 3·모드 줄·이어하기·새 버전 알림·공지까지
			Meta.games = 5
			Meta.rules = 3
			Meta.map_id = "line"
			main._refresh_menu()
			main.continue_btn.text = "이어하기 (Enter)    웨이브 29부터 · 소용돌이 · 버전 1"
			main.continue_btn.visible = true
			main.update_btn.text = "새 버전 0.9.9 받기"
			main.update_btn.visible = true
			main.notice_label.text = "공지: 시즌 2가 시작됐어요"
			main.notice_label.visible = true,
		func(): _snap("title"); main._toggle_notes(),
		func(): _snap("notes"); main._toggle_notes(); main._toggle_records(),
		func(): _snap("records"); main._toggle_records(); main._toggle_settings(),
		func(): _snap("settings"); main._toggle_settings(); main._toggle_codex(),
		func(): _snap("codex"); main._toggle_codex(); main._toggle_modes(),
		func(): _snap("modes"); main._toggle_modes(); main.help_label.visible = true,
		func(): _snap("help"); main.help_label.visible = false; main.continue_btn.visible = false; main._close_title(),
		func():
			for i in 6:
				main.picked = {"e": Elem.ALL[i], "lv": 2}
				main._place_tower(main.core() + Vector2.from_angle(i * 1.0) * 160.0, Vector2.RIGHT)
			main.wave = 27
			main.wave_time = 30.0
			main.offer = [{"type": "elem", "e": Elem.WOOD, "lv": 2}, {"type": "elem", "e": Elem.WATER, "lv": 2}, {"type": "link", "id": "prism"}]
			main._show_offer()
			main._open_choose(),
		func():
			_snap("cards")
			main.offer = [{"type": "pat", "id": Pat.PATTERN_IDS[2]}, {"type": "mod", "id": Pat.MOD_IDS[0]}, {"type": "cata", "id": "elem"}]
			main._show_offer(),
		func(): _snap("cards2"); main._set_cards_hidden(true),
		func(): _snap("cards_hidden"); main._set_cards_hidden(false); main._on_skip(),
		func(): _snap("skip_ready"); main._start_wave(),
		func(): _snap("skip_wave"); main.skip_left = 0; main._start_perk(),
		func(): _snap("perks"); main._toggle_pause(),
		func(): _snap("pause"); main._toggle_pause(); main._game_over(),
		func(): _snap("gameover"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [n, z]))
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
