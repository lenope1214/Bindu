extends SceneTree
## 긴 글·큰 숫자 점검: 글자를 키운 폰·태블릿에서 글이 길어지면 겹치거나 밀리거나 잘리는 곳을 찾는다.
## 시작 화면(긴 이어하기·공지·새 버전·다른 기기 판), 준비 화면(모드 여럿), 카드 4장(높은 레벨·긴 설명), 긴 알림·안내·아래 안내,
## 특성, 결과 화면(큰 점수·업적 8개·모드·피해 출처), 일시정지. 찍을 때마다 tools/ui_check.gd로 겹침·화면 밖·잘림을 줄로 찍는다.
## tools/run.sh ui text_stress_shot.gd <폴더> [글자 크기] [touch] [phone]
const UiCheck = preload("res://tools/ui_check.gd")
const LONG := "아주 긴 이름이 들어가도 칸 밖으로 나가지 않는지 보는 글이에요 · 두 번째 조각도 길게"
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
		Meta.sim_safe = Rect2(86, 0, 86, 38)  # 노치 있는 폰 가로
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	Tutorial.done = true
	Tutorial.play_done = true
	steps = [
		func():
			if main.tut and main.tut.visible:
				main.tut.close()
			Meta.guide_on = false
			Meta.ui_scale = z
			main.touch_ui = touch
			main.hud_system._apply_ui_scale()
			Meta.games = 5
			Meta.rules = 3
			Meta.map_id = "line"
			main.menu_system._refresh_menu()
			main.continue_info.text = "웨이브 129부터 · 소용돌이 · 도파민 모드 · 모드 4개 · 점수 x2.50"
			main.continue_btn.visible = true
			main.update_btn.text = "새 버전 10.12.99 받기 · 바뀐 것: 새 속성 둘, 새 맵, 화면 정리"
			main.update_btn.visible = true
			main.notice_label.text = "공지: 시즌 2가 시작됐어요. 지난 시즌 기록은 리더보드의 [지난 시즌]에서 볼 수 있고, 이번 주 투표는 일요일 밤에 닫혀요"
			main.notice_label.visible = true,
		func(): _snap("title_long"); main.remote_btn.text = "다른 기기에서 하던 판 이어하기   웨이브 129부터 · 소용돌이 · 도파민 모드"; main.remote_btn.visible = true,
		func(): _snap("title_remote_long"); main.remote_btn.visible = false; Modes.on.assign(Modes.ORDER.slice(0, 5)); Meta.modes = Modes.on.duplicate(); main.menu_system._refresh_menu(); main.menu_system._set_prep(true),
		func(): _snap("prep_modes"); main.menu_system._set_prep(false); Modes.on.clear(); Meta.modes = []; main.menu_system._refresh_menu(); Meta.map_id = "plain"; Meta.rules = 1; main.persistence_system._clear_run(); main.progression_system._hide_title(); main.lanes.clear(); main.run_flow_system._start_choose(),
		func():
			for i in 10:
				main.picked = {"e": Elem.ALL[i % Elem.ALL.size()], "lv": 4}
				main.interaction_system._place_tower(main.viewport_system.core() + Vector2.from_angle(i * 0.63) * (150.0 + (i % 2) * 90.0), Vector2.RIGHT)
			main.wave = 127
			main.wave_time = 30.0
			main.score = 98765432109
			main.kills = 1234567
			main.best_combo = 9999
			main.abilities_system._skills_new_run(1)
			main.hud_system.build_cache = [["elem:wood", 0.34], ["share:electric", 0.18], ["pat:spray", 0.12]]
			main.offer = [{"type": "elem", "e": Elem.ALL[-1], "lv": 3}, {"type": "pat", "id": Pat.PATTERN_IDS[-1]}, {"type": "mod", "id": Pat.MOD_IDS[-1]}, {"type": "link", "id": "pincer"}]
			main.cards_system._show_offer()
			main.cards_system._open_choose()
			main.hud_system._update_hud(true),
		func(): main.cards_system._show_offer(); main.cards_system._open_choose(),
		func(): _snap("cards4"); main.hud_system._show_toast("업적: " + LONG); main.hint.text = main.patchlog_system._kr_keep(LONG + " · 빈 곳을 눌러 해제"); main.hint.visible = true,
		func(): _snap("cards4_toast"); main.cards_system._set_cards_hidden(true),
		func(): _snap("field_toast"); main.cards_system._set_cards_hidden(false); main.guide_label.text = main.patchlog_system._kr_keep(LONG); main.guide_label.visible = true; Meta.guide_on = true,
		func(): _snap("cards4_guide"); main.guide_label.visible = false; Meta.guide_on = false; main.perks_system._start_perk(),
		func(): _snap("perks_long"); main.run_flow_system._toggle_pause(),
		func(): _snap("pause_long"); main.run_flow_system._toggle_pause(),
		func():
			Modes.on.assign(Modes.ORDER.slice(0, 4))
			main.new_achievements = ["철벽", "사냥꾼 III", "불굴의 의지", "몰살", "백 웨이브 생존자", "한 판 백만 처치", "도파민 중독", "만능 조합가"]
			main.run_flow_system._game_over(),
		func(): _snap("gameover_long"); Modes.on.clear(),
	]


func _snap(n: String):
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
	print("SHOT ", n)
	bad += UiCheck.check(main, n)


func _process(_d) -> bool:
	f += 1
	if f % 20 == 5:
		var i := f / 20
		if i < steps.size():
			steps[i].call()
		else:
			print("UI BAD ", bad)
			quit()
	return false
