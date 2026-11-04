extends "res://tools/spec_check.gd"
## 플레이 튜토리얼 흐름 점검 (features TUT-07·09·10). tools/run.sh tutplay 로 돈다 (저장 분리 사본).
## 세 번 돈다: 모든 단계를 직접 해내기(PC·터치 글), 모든 단계를 [건너뛰기]로만, 3장부터 장 고르기.
## 실제 판처럼 웨이브를 돌리고, 끝나면 기록·업적·도감·이어하기·설정이 그대로인지 본다.

var tp: TutPlay
var cur_touch := false


func _initialize():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"):
		print("FAIL 실제 게임 저장 폴더를 쓰게 됨: tools/run.sh tutplay 로 돌리세요")
		quit(1)
		return
	seed(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.cfg"))
	await _run("play", 0, false)
	await _run("play", 0, true)
	await _run("skip", 0, false)
	await _run("skip", 2, true)
	print("TUTPLAY %s (실패 %d)" % ["통과" if fails == 0 else "실패", fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## 조건이 맞을 때까지 프레임을 넘긴다 (웨이브는 8배속).
func _until(f: Callable, limit := 4000) -> bool:
	for i in limit:
		if f.call():
			return true
		await process_frame
	return f.call()


func _run(how: String, ch: int, touch: bool) -> void:
	var tag := "%s ch%d %s" % [how, ch + 1, "touch" if touch else "pc"]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.SAVE_PATH))  # 아래 값 그대로 불러오게
	Meta.map_id = "cross"
	Meta.rules = 3
	Meta.modes = ["three"]
	Meta.skill_set = 2
	Meta.games = 1  # 규칙·모드는 첫 판 뒤에 열린다: 바꿔 둔 값을 되돌리는지 보려면 한 판 해 본 사람으로
	var games0 := Meta.games
	var tally0 := JSON.stringify(Meta.tally)
	var ach0 := Meta.achieved.size()
	Tutorial.done = false
	Tutorial.play_done = false
	TutPlay.pending = ch
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	main.touch_ui = touch
	cur_touch = touch
	tp = main.tplay
	var started: bool = TutPlay.on and tp != null and Meta.map_id == "plain" and Meta.rules == 1 and Modes.on.is_empty()
	ok("TUT-07", started, "%s: 연습 판 시작 (평원·랭크·모드 없음)" % tag)
	if not started:
		main.queue_free()
		await _frames(2)
		return
	await _until(func(): return tp.ff < 0, 400)
	ok("TUT-09", tp.idx == TutPlay.CH_START[ch], "%s: %d장 첫 단계에서 시작 (단계 %d)" % [tag, ch + 1, tp.idx + 1])
	main.game_speed = 8.0
	var stuck := ""
	var guard := 0
	var last := -1
	var same := 0
	while tp.idx < TutPlay.STEPS.size() - 1 and guard < 30000:
		guard += 1
		if tp.idx != last:
			last = tp.idx
			same = 0
		same += 1
		if same > 6000:
			stuck = TutPlay.STEPS[tp.idx]["id"]
			print("STUCK %s wave=%d phase=%d picks=%d offer=%s block=%s active=%s perk=%s skip=%d hp=%d" % [stuck, main.wave, main.phase, main.picks_left, str(main.offer), main._wave_start_block_reason(), tp._active(), main.perk_mode, main.skip_left, main.core_hp])
			break
		if main.phase == main.Phase.WAVE:
			main.game_speed = 8.0
		if tp.done_t >= 0.0:
			await process_frame
			continue
		if how == "skip":
			if not tp.btn_skip.disabled:
				tp.btn_skip.pressed.emit()
			await _frames(2)
			continue
		await _act()
		await process_frame
	ok("TUT-07", stuck == "" and tp.idx == TutPlay.STEPS.size() - 1 and tp.end_box.visible, "%s: 23단계 끝까지 (멈춘 단계 %s, 지금 %d)" % [tag, stuck if stuck != "" else "없음", tp.idx + 1])
	ok("TUT-07", main.core_hp >= 1 and main.phase != main.Phase.GAMEOVER and main.wave >= 5, "%s: 지지 않고 %d웨이브까지 (중앙 %d)" % [tag, main.wave, main.core_hp])
	ok("TUT-10", not FileAccess.file_exists("user://run.cfg") and Meta.games == games0 and JSON.stringify(Meta.tally) == tally0 and Meta.achieved.size() == ach0,
		"%s: 이어하기 저장·판 수·누적 수·업적이 그대로" % tag)
	main._save_best()
	var cfg := ConfigFile.new()
	cfg.load(Meta.SAVE_PATH)
	var saved_ok := Meta.map_id == "plain" and str(cfg.get_value("meta", "map", "plain")) == "cross"
	tp.finish(true)
	ok("TUT-10", not TutPlay.on and Meta.map_id == "cross" and Meta.rules == 3 and Meta.modes == ["three"] and Meta.skill_set == 2 and saved_ok,
		"%s: 끝나면 맵·규칙·모드·기술 묶음 되돌림, 도중 저장도 원래 값" % tag)
	ok("TUT-09", Tutorial.done and Tutorial.play_done, "%s: 끝내면 이 기기에서 다시 자동으로 뜨지 않음" % tag)
	main.queue_free()
	await _frames(3)


## 지금 단계를 사람이 하듯 해낸다 (입력 처리가 부르는 함수 그대로).
func _act() -> void:
	var s := tp.step()
	if not tp._active():
		await _gate()
		return
	var fire := tp._first(Elem.FIRE)
	var wood := tp._first(Elem.WOOD)
	match s["id"]:
		"goal":
			tp.btn_ok.pressed.emit()
		"place", "second":
			_pick(s["card"])
			main._place_card_at(tp._spot(TutPlay.SPOT_FIRE if s["id"] == "place" else TutPlay.SPOT_WOOD), true)
			if s["id"] == "second":
				_aim(Vector2.DOWN)
		"aim":
			_aim(Vector2.RIGHT)
		"wave1":
			if main.phase == main.Phase.READY:
				main._start_wave_from_ready()
		"move":
			fire.position = tp._spot(TutPlay.SPOT_MOVE)
		"turn":
			main._start_move(fire)
			_aim(fire.dir.rotated(-0.6))
		"preview":
			main._start_move(fire)
			_aim((main.core() + Vector2.from_angle(main.boss_plan.get("a", 0.0)) * 240.0 - fire.position).normalized().rotated(0.1))
		"zoom":
			main._zoom_to(1.6, main.get_viewport_rect().size / 2.0)
			await process_frame
			main._reset_zoom()
		"stack", "trig", "link":
			_pick(s["card"])
			main._place_card_at(fire.position, true)
			if s["id"] == "link":
				fire.position = wood.position + Vector2(100, -50)
				fire.set_attack_direction(tp._lane_dir(fire.position, 0.0))
		"pat", "mod":
			_pick(s["card"])
			main._place_card_at((wood if s["id"] == "pat" else fire).position, true)
		"detail":
			main._set_card_detail(not Meta.card_detail)
			await process_frame
			main._set_card_detail(not Meta.card_detail)
		"tools":
			main._on_reroll()
			main._set_cards_hidden(true)
			await process_frame
			main._set_cards_hidden(false)
			main.range_all = true
			await process_frame
			main.range_all = false
		"info":
			main.tip_detail = true
			main.touch_ui = true
			main.tip_frame = Engine.get_process_frames()
			await process_frame
			main.tip_frame = Engine.get_process_frames()
			await process_frame
			main.tip_detail = false
			main.touch_ui = cur_touch
		"ley":
			if not main.ley.is_empty():
				fire.position = main.ley[0]
		"skill":
			for id in main.skill_ids:
				var p: Variant = Skill.auto_target(main, id)
				if p != null:
					main._use_skill(id, p)
		"speed":
			main._toggle_speed()
			await process_frame
			main._toggle_speed()
			main._toggle_pause()
			await process_frame
			main._toggle_pause()
			main.game_speed = 8.0
		"perk":
			if main.coin_stage > 0:
				main._coin_tap()
			elif main.perk_mode:
				var coin: Array = main.perk_offer.filter(func(pk): return pk["id"] == "coin")
				main._on_perk(coin[0] if not coin.is_empty() and main.perks.is_empty() else main.perk_offer[0])
		"skip":
			if main.skip_left == 0 and main.phase in [main.Phase.CHOOSE, main.Phase.READY]:
				main._on_skip()


func _pick(card: Dictionary) -> void:
	if main.phase == main.Phase.CHOOSE:
		main._on_pick(card)


## 방향 확정: 터치 조준처럼 붙잡아 둔 방향으로 (PC 클릭도 같은 _confirm_aim).
func _aim(d: Vector2) -> void:
	if main.phase != main.Phase.AIM:
		return
	main.aim_d = d.normalized()
	main.aim_wait = true
	var was: bool = main.touch_ui
	main.touch_ui = true
	main._confirm_aim()
	main.touch_ui = was


## 이 쉬는 시간에 할 일이 끝난 뒤: 남은 카드를 놓고 웨이브를 시작한다.
func _gate() -> void:
	if main.perk_mode and not main.perk_offer.is_empty() and main.coin_stage == 0:
		main._on_perk(main.perk_offer[0])
	elif main.coin_stage > 0:
		main._coin_tap()
	elif main.phase == main.Phase.CHOOSE and main.picks_left > 0 and not main.offer.is_empty():
		var cd: Dictionary = main.offer[0]
		main._on_pick(cd)
		if cd["type"] == "elem":
			main._place_card_at(tp._free_spot(), true)
			_aim(Vector2.LEFT)
		else:
			main._place_card_at(main.towers.get_child(0).position, true)
	elif main.phase == main.Phase.READY:
		tp._cover_lanes()
		if main._wave_start_block_reason() != "":
			print("BLOCK %s (단계 %s)" % [main._wave_start_block_reason(), tp.step()["id"]])
			tp.force_start = true
		main._start_wave_from_ready()
