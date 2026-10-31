extends SceneTree
## 화면 배치 점검용 스크린샷: 시작 화면(줄이 가장 많을 때)·그 위 창들·카드·특성·일시정지·게임 오버.
## 인자: 저장 폴더 [글자 크기] [touch] [phone]. 예) xvfb-run godot --path . -s tools/shot.gd -- /tmp/shots 1.3 touch phone
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false  # 폰처럼 터치 화면 (범위 보기 버튼 등)
var steps: Array = []


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	Meta.sim_phone = a.size() > 3 and a[3] == "phone"  # 폰 화면 구성 (main._phone)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
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
		func():
			_snap("records"); main._toggle_records(); main._toggle_board(),
		func():
			# 서버 없이 순위 10줄을 채워 본다 (연결 실패가 먼저 온 뒤에 덮어쓴다)
			var es := []
			for i in 10:
				es.append({"rank": i + 1, "nick": "닉네임%d" % i, "wave": 40 - i, "score": 9000000 - i * 1000, "me": i == 3, "ended": i != 1})
			main._on_board_loaded({"tag": main._board_tag(), "period": "all", "entries": es})
			main._on_board_loaded({"tag": main._board_tag(), "period": "week", "entries": es.slice(0, 5)}),
		func(): _snap("board"); main._toggle_board(); main._toggle_settings(),
		func(): _snap("settings"); main._toggle_settings(); main._toggle_codex(),
		func(): _snap("codex"); main.codex_panel.tabs[1].pressed.emit(),
		func(): _snap("codex_pat"); main.codex_panel.tabs[4].pressed.emit(),
		func(): _snap("codex_rx"); main.codex_panel.tabs[5].pressed.emit(),
		func(): _snap("codex_perk"); main._toggle_codex(); main._toggle_modes(),
		func(): _snap("modes"); main._toggle_modes(); main.help_label.visible = true,
		func():
			_snap("help"); main.help_label.visible = false; main.continue_btn.visible = false
			main.remote_btn.text = "다른 기기에서 하던 판 이어하기   웨이브 29부터 · 소용돌이"
			main.remote_btn.visible = true,
		func(): _snap("title_remote"); main.remote_btn.visible = false; main._close_title(),
		func():
			for i in 6:
				main.picked = {"e": Elem.ALL[i], "lv": 2}
				main._place_tower(main.core() + Vector2.from_angle(i * 1.0) * 160.0, Vector2.RIGHT)
			main.wave = 27
			main.wave_time = 30.0
			main.offer = [{"type": "elem", "e": Elem.WOOD, "lv": 2}, {"type": "trig", "id": "echo"}, {"type": "link", "id": "prism"}]
			main._show_offer()
			main._open_choose(),
		func():
			_snap("cards")
			# 폰: 한 번 누른 카드 (미리보기·다른 카드 옅게·[적용])
			main.touch_ui = true
			main._on_card_tap(main.offer[0], 0),
		func():
			_snap("cards_tap")
			main.touch_ui = touch
			# 전장 확대 2배 (오른쪽 위 [확대 풀기], 배지·카드·정보는 그대로 화면에)
			main._set_cards_hidden(true)
			main._zoom_to(2.0, main.get_viewport_rect().size * Vector2(0.3, 0.5)),
		func():
			_snap("zoom")
			main._reset_zoom()
			main._set_cards_hidden(false)
			main.offer = [{"type": "pat", "id": Pat.PATTERN_IDS[2]}, {"type": "mod", "id": Pat.MOD_IDS[0]}, {"type": "cata", "id": "elem"}]
			main._show_offer(),
		func():
			_snap("cards2")
			# 첫 판처럼 처음 안내가 떠 있을 때 (안내 글과 카드 줄이 겹치지 않는지)
			main.guide_lines.clear()
			Meta.guide_seen.erase("start")
			main._guide("start", "빨간 화살표가 구체가 들어오는 길목이에요. 속성 카드를 고른 뒤 길목 쪽 빈 곳을 눌러 놓고, 한 번 더 눌러 쏠 방향을 정하세요"),
		func(): _snap("cards_guide"); main.guide_lines.clear(); main._set_cards_hidden(true),
		func():
			_snap("cards_hidden")
			# 오브젝트 정보창 (마우스를 올렸을 때, 화면 오른쪽 아래 쪽 오브젝트라 창이 화면 끝에 닿는지)
			var t: Node2D = main.towers.get_child(1)
			Input.warp_mouse(t.get_global_transform_with_canvas().origin),
		func():
			_snap("tip")
			# 터치로 방향 바꾸기: 오브젝트 정보창이 손가락 반대편에, 아래에 [자세히]
			main.touch_ui = true
			var t: Node2D = main.towers.get_child(1)
			main._start_move(t)
			Input.warp_mouse(t.get_global_transform_with_canvas().origin + Vector2(160, 0)),
		func(): main.touch_ui = true,  # 마우스를 옮기면(warp) touch_ui가 꺼진다
		func(): main.tip_detail = true,
		func():
			_snap("aim_touch_detail")
			main.tip_detail = false
			main._cancel_step()
			main.touch_ui = touch; main._set_cards_hidden(false); main._on_skip(),  # 마우스를 옮기면 touch_ui가 꺼진다
		func(): _snap("skip_ready"); main._start_wave(),
		func(): _snap("skip_wave"); _orb_tip(),
		func(): _snap("orb_tip"); main.touch_ui = touch; main.skip_left = 0; Input.warp_mouse(Vector2(5, 360)); main._start_perk(),
		func():
			_snap("perks")
			# 운명의 동전 연출: 장면마다 멈춰 두고 찍는다 (공중 → 떨어지는 중 → 모서리 → 결과 → 새 특성)
			main.coin_anim = true
			main._on_perk(main.PERKS[9])
			main.coin_next = "double"
			main._process(0.0)  # 숨길 버튼·글을 한 번 정리하고
			main.set_process(false)  # 장면을 멈춰 둔다 (일시정지는 일시정지 창이 떠서 안 씀)
			main.coin_t = 0.5; main.coin_ang = 0.6; main.coin_fx.queue_redraw(),
		func():
			_snap("coin_air"); main._coin_drop()
			main.coin_t = 0.45; main.coin_ang = main.coin_ang0 + main.coin_spin * 0.72; main.coin_fx.queue_redraw(),
		func(): _snap("coin_fall"); main.coin_stage = 3; main.coin_t = 0.1; main.coin_fx.queue_redraw(),
		func(): _snap("coin_edge"); main.set_process(true); main._coin_land(),
		func(): _snap("coin_land"),
		func(): pass,
		func(): _snap("coin_perks"); main._toggle_pause(),
		func(): _snap("pause"); main._toggle_settings(),
		func(): _snap("pause_settings"); main._toggle_settings(); main._toggle_pause(); main._game_over(),
		func(): _snap("gameover"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
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


## 상태가 많은 구체에 마우스를 올린다 (구체 정보창이 한 줄로 화면 밖까지 나가지 않는지)
func _orb_tip() -> void:
	if main.orbs.get_child_count() == 0:
		main._spawn_orb(2)  # 단단한 구체
	var o = main.orbs.get_child(0)
	o.position = main.get_canvas_transform().affine_inverse() * Vector2(760, 440)  # 막 나온 구체는 화면 끝이라 가운데로
	o.shield = 30.0; o.splits = true; o.burn_t = 2.0; o.poison_t = 2.0; o.vuln_t = 2.0; o.slow_timer = 2.0
	o.prison_t = 2.0; o.swamp_t = 2.0; o.curse_lv = 1; o.silence_t = 2.0; o.resist_e = 0; o.sturdy = true
	o.lava_t = 1.5; o.seed_n = 2; o.amp = {"rust": [0.16, 4.0], "seed": [0.3, 3.0]}
	o.root_timer = 30.0  # 제자리에
	Input.warp_mouse(o.get_global_transform_with_canvas().origin)
