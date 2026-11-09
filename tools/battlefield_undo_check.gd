extends "res://tools/carry_check.gd"
## 기존 편집 입력 → undo의 identity·런타임·통계·경계 회귀 검사. 임시 BinduTools native 사본 전용.
var case_id := 0
var callback_hits := 0
const RUNTIME := ["dice_miss", "dice_x", "dice_t", "side_cd", "side_n", "focus_t", "clock_ph", "cont_acc", "answer_cd", "notify_cd", "light_cd", "cd", "mirror_src", "later", "new_reactions", "wave_kills", "hist"]

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(120).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args.size() > 2 and args[2] == "phone"
	DirAccess.make_dir_recursive_absolute(output)
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 5
	Meta.guide_on = false
	Meta.sim_phone = phone
	Meta.sim_safe = Rect2(86, 0, 86, 38) if phone else Rect2()
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main.progression_system._hide_title()
	main.set_process(false)
	main.auto_start = false
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	print("UNDO ENV phone=", phone, " ui_scale=", args[1], " viewport=", root.size, " display=", DisplayServer.get_name())
	for path in ["scripts/edit_history.gd", "scripts/features/cards.gd", "scripts/features/interaction.gd", "scripts/card_dock.gd", "tools/battlefield_undo_check.gd"]:
		print("UNDO SOURCE ", path, " ", FileAccess.get_sha256("res://" + path))
	await transform_cases()
	await card_cases()
	await cancel_and_boundary_cases()
	await review_ui_case()
	await toolbar_focus_case()
	print("BATTLEFIELD UNDO failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails > 0 or ui_errors > 0 else 0)

func reset_undo_case(picks := 1) -> void:
	main.cards_system.clear_edit_history()
	main.settings_panel.hide()
	main.help_label.hide()
	main.notes_panel.hide()
	main.codex_panel.hide()
	main.vote_panel.hide()
	main.records_panel.hide()
	main.modes_panel.hide()
	main.card_dock.close_inspector()
	await fixture()
	case_id += 1
	main.run_id = "undo-check-%d" % case_id
	main.run_log = []
	main.new_achievements = []
	main.picks_left = picks
	main.countdown = -1
	main.touch_ui = phone
	main.tip_tower = null
	main.dps_focus = null
	main.card_dock.inspector_dismissed = false
	main.interaction_system.additive_selection = false
	target.position = Vector2(280, 300)
	refused.position = Vector2(950, 300)
	Meta.tally = {"pick:mod:pierce":3}
	Meta.achieved = {}
	Meta.codex = {}
	Ach.new_run()
	await settle()

func tap(at: Vector2) -> void:
	if phone:
		await touch(at, true)
		await touch(at, false)
	else:
		await mouse_click(at)

func press_key(code: int, ctrl := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.pressed = true
	VirtualInput.send(event)
	await settle()
	event.pressed = false
	VirtualInput.send(event)
	await settle()

func undo_input() -> void:
	if phone:
		await tap(main.card_dock.undo_btn.get_global_rect().get_center())
	else:
		await press_key(KEY_Z, true)

func runtime(tower: Tower) -> Dictionary:
	var result := {}
	for key in RUNTIME:
		var value: Variant = tower.get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func arm_runtime() -> Dictionary:
	target.dice_miss = 4
	target.dice_x = 2.75
	target.dice_t = 0.63
	target.side_cd = 0.41
	target.side_n = 6
	# 원래 fade_fx가 쉬는 시간의 집중을 즉시 0으로 만든다. 기존 규칙과 undo 손실을 구분한다.
	target.focus_t = 0.0
	target.clock_ph = 0.97
	target.cont_acc = 0.17
	target.answer_cd = 0.31
	target.notify_cd = 0.21
	target.light_cd = 0.81
	target.cd = {"clock":0.73}
	target.mirror_src = refused
	target.later = [[3.0, Callable(self, "delayed_effect").bind(target, refused)]]
	target.new_reactions = {"review-unread":true}
	target.wave_kills = 3
	target.hist = [[main.wave - 1, 230, 7, 14.5]]
	return runtime(target)

func delayed_effect(tower: Tower, source: Tower) -> void:
	if is_instance_valid(tower) and is_instance_valid(source) and tower.mirror_src == source:
		callback_hits += 1

func transform_cases() -> void:
	await reset_undo_case()
	main.cards_system._set_cards_hidden(true)
	var identity: int = target.get_instance_id()
	var friend_identity: int = refused.get_instance_id()
	var before := arm_runtime()
	var position_before: Vector2 = target.position
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	ok("UNDO-01", target.position.x > position_before.x, "실제 방향키 입력으로 이동")
	await press_key(KEY_Z, true)
	var original_alive := is_instance_valid(target) and is_instance_valid(refused)
	ok("UNDO-01", original_alive and target.get_instance_id() == identity and refused.get_instance_id() == friend_identity and target.get_parent() == main.towers, "이동 undo는 모든 기존 Node identity 보존")
	var actual: Tower = target if original_alive else main.towers.get_child(0)
	ok("UNDO-01", actual.position == position_before and runtime(actual) == before, "주사위 누적·배율·시간·보조공격·방향 시계·콜백·읽지 않은 조합 보존")
	if original_alive:
		actual.later[0][1].call()
	ok("UNDO-01", callback_hits == 1, "queued Callable은 원래 Tower 참조로 계속 유효")
	await snap("01-move-undo")

	await reset_undo_case()
	main.cards_system._set_cards_hidden(true)
	await press_key(KEY_A, true)
	var origins := [target.position, refused.position]
	var dirs := [target.dir, refused.dir]
	before = arm_runtime()
	await press_key(KEY_RIGHT)
	ok("UNDO-02", target.position != origins[0] and refused.position != origins[1], "Ctrl/Cmd+A 뒤 그룹 이동 입력")
	await press_key(KEY_Z, true)
	original_alive = is_instance_valid(target) and is_instance_valid(refused)
	ok("UNDO-02", original_alive and target.position == origins[0] and refused.position == origins[1] and main.interaction_system.selected.size() == 2, "그룹 이동 undo는 위치·다중 선택 복구")
	if not original_alive: return
	await press_key(KEY_BRACKETRIGHT)
	ok("UNDO-03", target.dir != dirs[0] and refused.dir != dirs[1], "그룹 회전 실제 입력")
	await press_key(KEY_Z, true)
	ok("UNDO-03", target.dir == dirs[0] and refused.dir == dirs[1] and runtime(target) == before, "그룹 회전 undo는 원래 방향·런타임 복구")
	await press_key(KEY_E)
	await press_key(KEY_UP)
	await press_key(KEY_ENTER)
	ok("UNDO-03", target.dir.dot(Vector2.UP) > 0.99 and refused.dir.dot(Vector2.UP) > 0.99, "명시 방향 편집 입력 확정")
	await press_key(KEY_Z, true)
	ok("UNDO-03", target.dir == dirs[0] and refused.dir == dirs[1] and main.phase == main.Phase.CHOOSE and runtime(target) == before, "방향 편집 undo 뒤 원래 단계와 런타임")
	await snap("02-group-direction-undo")
	var count: int = main.cards_system.edit_history.size()
	await press_key(KEY_E)
	await press_key(KEY_DOWN)
	await press_key(KEY_ESCAPE)
	ok("UNDO-04", main.cards_system.edit_history.size() == count and target.dir == dirs[0] and refused.dir == dirs[1], "방향 취소는 이력 추가·소비 없음")
	main.cards_system.begin_edit("변경 없음")
	main.cards_system.finish_edit()
	ok("UNDO-04", main.cards_system.edit_history.size() == count, "no-op 이력 없음")

func card_cases() -> void:
	await reset_undo_case()
	var old_id: int = target.get_instance_id()
	var before := arm_runtime()
	main.bank_picks = [7]
	var offer_before: Array = main.offer.duplicate(true)
	await tap(card_center())
	await tap(world(target.position))
	ok("UNDO-05", main.phase == main.Phase.READY and main.picks_left == 0 and main.bank_picks.is_empty() and target.m("pierce") == 1 and int(Meta.tally.get("pick:mod:pierce", 0)) == 4 and main.run_log.size() == 1, "마지막 카드 실제 적용·보류 선택 소비·통계 1회")
	var rng_before: int = main.wrng.state
	await undo_input()
	var alive := is_instance_valid(target)
	ok("UNDO-05", alive and target.get_instance_id() == old_id and target.m("pierce") == 0 and runtime(target) == before, "카드 undo도 기존 객체·모든 런타임 보존")
	ok("UNDO-05", main.phase == main.Phase.CHOOSE and main.picks_left == 1 and main.bank_picks == [7] and main.offer == offer_before and main.run_log.is_empty() and int(Meta.tally.get("pick:mod:pierce", 0)) == 3 and main.choice_box.visible, "선택·offer·보류·로그·통계·UI 원상 복구")
	ok("UNDO-05", main.wrng.state == rng_before, "undo는 wave RNG를 다시 뽑지 않음")
	var saved_profile := ConfigFile.new()
	var saved_run := ConfigFile.new()
	var profile_ok := saved_profile.load(main.SAVE_PATH) == OK
	var run_ok := saved_run.load(main.RUN_PATH) == OK
	ok("UNDO-05", profile_ok and run_ok and int(saved_profile.get_value("meta", "tally", {}).get("pick:mod:pierce", 0)) == 3 and saved_run.get_value("run", "picks_left", -1) == 1 and saved_run.get_value("run", "offer", []) == offer_before and saved_run.get_value("run", "log", [1]).is_empty(), "복구된 선택·통계·로그를 격리 디스크 저장에서도 확인")
	await snap("03-card-undo")
	await tap(card_center())
	await tap(world(main.towers.get_child(0).position))
	ok("UNDO-05", int(Meta.tally.get("pick:mod:pierce", 0)) == 4 and main.run_log.size() == 1 and main.picks_left == 0, "재적용해도 통계·로그 중복 없음")

	await reset_undo_case()
	before = arm_runtime()
	var originals: Array = main.towers.get_children()
	await tap(card_center(1))
	await tap(world(Vector2(470, 400)))
	ok("UNDO-06", main.towers.get_child_count() == 3 and main.phase == main.Phase.READY, "새 오브젝트 실제 설치")
	var created: Tower = main.towers.get_child(2)
	await undo_input()
	ok("UNDO-06", main.towers.get_children() == originals and (not is_instance_valid(created) or created.is_queued_for_deletion()) and is_instance_valid(target) and runtime(target) == before, "설치 undo는 새 Node만 제거하고 원본 보존")
	await snap("04-new-object-undo")

	await reset_undo_case()
	var new_reactions: Array = Elem.new_reactions(target.eff_now(), Elem.FIRE).map(func(reaction): return reaction.id)
	var previous_codex := {}
	for reaction in Elem.REACTIONS:
		if not reaction.id in new_reactions and previous_codex.size() < 4:
			previous_codex[reaction.id] = true
	Meta.codex = previous_codex.duplicate()
	Meta.achieved.erase("codex5")
	var achieved_before := Meta.achieved.duplicate(true)
	var tally_before := Meta.tally.duplicate(true)
	var ach_before := Ach.run.duplicate(true)
	before = arm_runtime()
	await tap(card_center(1))
	await tap(world(target.position))
	ok("UNDO-07", Meta.codex.size() > previous_codex.size() and Meta.achieved.has("codex5") and not main.new_achievements.is_empty(), "조합 발견·업적은 실제 카드 적용으로 발생")
	await press_key(KEY_Z, true)
	ok("UNDO-07", Meta.codex == previous_codex and Meta.achieved == achieved_before and Meta.tally == tally_before and Ach.run == ach_before and main.new_achievements.is_empty(), "도감·업적·누적·한 판 통계와 업적 목록 함께 복구")
	ok("UNDO-07", is_instance_valid(target) and runtime(target) == before and target.lv(Elem.FIRE) == 0, "조합 undo는 읽지 않은 이전 조합·원본 런타임 보존")

	await reset_undo_case()
	main.offer[0] = {"type":"pat", "id":"clock"}
	main.cards_system._show_offer()
	await settle()
	before = arm_runtime()
	var original_pattern: String = target.pattern
	await tap(card_center())
	await tap(world(target.position))
	ok("UNDO-07", target.pattern == "clock" and target.cd.is_empty(), "공격방식 적용은 실제로 기존 쿨다운을 비움")
	await undo_input()
	ok("UNDO-07", is_instance_valid(target) and target.pattern == original_pattern and runtime(target) == before, "공격방식 undo는 지워진 쿨다운과 런타임까지 복구")

func cancel_and_boundary_cases() -> void:
	await reset_undo_case()
	await tap(card_center())
	var state_before: Dictionary = target.to_save().duplicate(true)
	ok("UNDO-08", not main.cards_system.undo_edit() and main.phase == main.Phase.PLACE and target.to_save() == state_before and main.picks_left == 1, "PLACE에서 undo는 원자적으로 거절")
	await press_key(KEY_ESCAPE)
	ok("UNDO-04", main.cards_system.edit_history.is_empty(), "카드를 들었다가 취소해도 이력 없음")
	main.cards_system._set_cards_hidden(true)
	await tap(world(target.position))
	var before: Vector2 = target.position
	await press_key(KEY_RIGHT)
	await press_key(KEY_Z, true)
	ok("UNDO-08", is_instance_valid(target) and target.position == before and main.cards_hidden and main.picks_left == 1 and main.phase == main.Phase.CHOOSE, "카드 취소 뒤 이동 undo는 새 snapshot 사용")

	await reset_undo_case()
	main.cards_system._set_cards_hidden(true)
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	await press_key(KEY_E)
	state_before = target.to_save().duplicate(true)
	ok("UNDO-08", not main.cards_system.undo_edit() and main.phase == main.Phase.AIM and target.to_save() == state_before, "AIM 중 undo는 이전 이동까지 잘못 되돌리지 않음")
	await press_key(KEY_ESCAPE)

	await reset_undo_case()
	await tap(card_center())
	before = target.position
	if phone:
		await touch(world(target.position), true)
		print("TOUCH CARRY press phase=", main.phase, " picks=", main.picks_left, " pos=", target.position, " object_press=", is_instance_valid(main.interaction_system.press_t))
		await touch_drag(world(before + Vector2(64, 0)))
		await touch(world(before + Vector2(64, 0)), false)
		print("TOUCH CARRY release phase=", main.phase, " picks=", main.picks_left, " pos=", target.position, " mod=", target.m("pierce"))
	else:
		await mouse_button(world(target.position), true)
		await mouse_move(world(target.position + Vector2(64, 0)), true)
		await mouse_button(world(target.position), false)
	if phone:
		# 기존 폰 계약: 든 카드의 전장 드래그는 card drop이며 Tower 이동이 아니다.
		ok("UNDO-08", target.position == before and main.phase == main.Phase.PLACE and main.picks_left == 1, "터치 carried-card 무효 드롭은 기존 오브젝트·선택수를 바꾸지 않음")
		await press_key(KEY_ESCAPE)
		ok("UNDO-08", main.phase == main.Phase.CHOOSE and main.cards_system.edit_history.is_empty() and main.run_log.is_empty(), "무효 드롭 뒤 카드 취소는 이력·로그를 남기지 않음")
	else:
		ok("UNDO-08", target.position != before and main.phase == main.Phase.PLACE, "카드를 든 채 실제 끌기로 기존 오브젝트 이동")
		await press_key(KEY_ESCAPE)
		await press_key(KEY_Z, true)
		ok("UNDO-08", is_instance_valid(target) and target.position == before and main.phase == main.Phase.CHOOSE and main.picks_left == 1 and main.run_log.is_empty(), "카드 취소 뒤 그동안의 이동만 되돌림")

	await reset_undo_case(2)
	await tap(card_center())
	await tap(world(target.position))
	ok("UNDO-09", main.phase == main.Phase.CHOOSE and main.picks_left == 1 and main.cards_system.edit_history.is_empty() and not main.cards_system.undo_edit(), "새 무작위 카드 공개 뒤 이전 적용 undo 차단")
	# 실제 새 draft 함수가 같은 값을 다시 뽑아도 명시 경계가 이력을 비운다.
	await reset_undo_case()
	main.cards_system._set_cards_hidden(true)
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	seed(712)
	main.cards_system._make_choices()
	var once: Array = main.offer.duplicate(true)
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	seed(712)
	main.cards_system._make_choices()
	ok("UNDO-09", main.offer == once and main.cards_system.edit_history.is_empty() and not main.cards_system.undo_edit(), "동일 내용 재추첨도 새 정보 경계")

	await reset_undo_case()
	main.cards_system._set_cards_hidden(true)
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	main.cards_system._set_cards_hidden(false)
	await press_key(KEY_Q)
	ok("UNDO-09", main.rerolls_left == 0 and main.cards_system.edit_history.is_empty() and not main.cards_system.undo_edit(), "실제 새로고침 입력은 이전 이동 이력도 폐기")
	await reset_undo_case()
	main.cards_system._set_cards_hidden(true)
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	main.perks_system._start_perk()
	ok("UNDO-09", main.perk_mode and main.cards_system.edit_history.is_empty() and not main.cards_system.undo_edit(), "새 특성 공개 경계")
	await reset_undo_case()
	main.cards_system._enter_ready()
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	await press_key(KEY_SPACE)
	ok("UNDO-09", main.phase == main.Phase.WAVE and main.cards_system.edit_history.is_empty() and not main.cards_system.undo_edit(), "실제 웨이브 시작 입력은 이력 폐기")

	await reset_undo_case()
	main.cards_system._set_cards_hidden(true)
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	main.run_id = "different-run"
	state_before = target.to_save().duplicate(true)
	ok("UNDO-10", not main.cards_system.undo_edit() and target.to_save() == state_before and main.run_id == "different-run", "다른 판 snapshot 복원 차단")

	await reset_undo_case()
	await tap(card_center())
	await tap(world(target.position))
	Meta.codex["concurrent-progress"] = true
	ok("UNDO-10", not main.cards_system.undo_edit() and Meta.codex.has("concurrent-progress") and main.picks_left == 0, "편집 뒤 다른 진행 변경은 덮어쓰지 않고 fail closed")
	await reset_undo_case()
	main.cards_system._set_cards_hidden(true)
	await tap(world(target.position))
	await press_key(KEY_RIGHT)
	main.net.progress_synced.emit()
	ok("UNDO-10", main.cards_system.edit_history.is_empty() and not main.cards_system.undo_edit(), "진행 동기화 이벤트는 이전 이력 폐기")
	await snap("05-boundaries")

func review_ui_case() -> void:
	await reset_undo_case()
	main.leak_log = [{"w":main.wave, "n":0}]
	main.interaction_system.select_all()
	main.card_dock.read_wave_review()
	await settle()
	var before: Vector2 = target.position
	main.interaction_system.move_selected(Vector2(24, 0))
	main.card_dock.close_inspector()
	await settle()
	await undo_input()
	ok("UNDO-11", target.position == before and main.card_dock.reading_review and main.card_dock.inspect_return_cards and main.cards_hidden, "이동 undo는 열려 있던 지난 웨이브 정보와 카드 복귀 상태도 복구")
	await snap("06-review-ui-undo")

func toolbar_focus_case() -> void:
	await reset_undo_case()
	main.cards_system._enter_ready()
	await settle()
	var before := [target.position, refused.position]
	await tap(main.card_dock.select_all_btn.get_global_rect().get_center())
	ok("UNDO-12", main.interaction_system.selected.size() == 2, "화면의 전체 선택 버튼 실제 입력")
	await press_key(KEY_RIGHT)
	ok("UNDO-12", target.position != before[0] and refused.position != before[1], "toolbar로 선택한 뒤 방향키는 전장 그룹 이동")
	await snap("07-toolbar-focus")
	await press_key(KEY_Z, true)
	await tap(world(target.position))
	await press_key(KEY_ESCAPE)
	await press_key(KEY_SPACE)
	ok("UNDO-12", main.phase == main.Phase.WAVE, "toolbar 사용 뒤 전장을 다시 선택하면 Space로 시작")
