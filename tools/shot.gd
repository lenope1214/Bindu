extends SceneTree
## 화면 배치 점검용 스크린샷: 시작 화면(줄이 가장 많을 때)·그 위 창들·카드·특성·일시정지·게임 오버.
## 인자: 저장 폴더 [글자 크기] [touch]. 예) xvfb-run godot --path . -s tools/shot.gd -- /tmp/shots 1.3 touch
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
		func():
			_snap("codex_perk")
			# 업적 탭: 진행 막대·등급·칭호 버튼·숨긴 신화가 보이게 몇 개 채운다
			Meta.total_kills = 6342
			Meta.tally["max:wave"] = 27
			Meta.tally["max:burst"] = 22
			Meta.tally["boss_kills"] = 11
			for id in ["first", "wave10", "wave15", "boss", "rxk500", "calm10"]:
				Meta.achieved[id] = true
			Meta.title = "calm10"
			for i in 9:
				Meta.tally["pick:elem:" + Patch.ELEM_KEYS[i]] = 2 + i * 3
			for id in Pat.PATTERN_IDS.slice(1, 6):
				Meta.tally["pick:pat:" + id] = 3
			main.codex_panel.tabs[6].pressed.emit(),
		func(): _snap("codex_ach"); (main.codex_panel.list.get_parent() as ScrollContainer).scroll_vertical = 100000,
		func(): _snap("codex_ach_end"); main.codex_panel.tabs[0].pressed.emit(),
		func(): _snap("codex_elem"); main._toggle_codex(); main._toggle_modes(),
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
			main.offer = [{"type": "elem", "e": Elem.WOOD, "lv": 2}, {"type": "elem", "e": Elem.WATER, "lv": 2}, {"type": "link", "id": "prism"}]
			main._show_offer()
			main._open_choose(),
		func():
			_snap("cards")
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
		func(): _snap("tip"); main.touch_ui = touch; main._set_cards_hidden(false); main._on_skip(),  # 마우스를 옮기면 touch_ui가 꺼진다
		func(): _snap("skip_ready"); main._start_wave(),
		func(): _snap("skip_wave"); _orb_tip(),
		func(): _snap("orb_tip"); main.touch_ui = touch; main.skip_left = 0; main._start_perk(),
		func(): _snap("perks"); main._toggle_pause(),
		func(): _snap("pause"); main._toggle_settings(),
		func(): _snap("pause_settings"); main._toggle_settings(); main._toggle_pause(); main._game_over(),
		func(): _snap("gameover"),
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
