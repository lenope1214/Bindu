extends "res://tools/carry_check.gd"
## 2026-11-09 사용성 진단용 관찰 도구. 제품 코드는 변경하지 않는다.
## tools/run.sh ui battlefield_usability_audit.gd <출력 절대경로> <배율> [phone]
## 상태 준비만 fixture로 한다. 진단 대상 행동은 VirtualInput의 GUI 경로를 사용한다.
var observations: Array = []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		push_error("저장·네트워크 격리 native 사본이 필요합니다")
		quit(2)
		return
	create_timer(120).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args.size() > 2 and args[2] == "phone"
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
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	await create_timer(0.2).timeout
	await placement_and_cancel()
	await edit_ambiguity()
	await nearby_target()
	await modal_shortcuts()
	await automatic_progress()
	await wave_actions()
	await skip_actions()
	await reading_actions()
	var f := FileAccess.open(output.path_join("observations.json"), FileAccess.WRITE)
	var revision := OS.get_environment("BINDU_AUDIT_REVISION")
	f.store_string(JSON.stringify({"source_revision":revision if revision != "" else "unrecorded", "phone_simulation":phone, "ui_scale":Meta.ui_scale, "physical_size":str(root.size), "logical_size":str(main.get_viewport_rect().size), "observations":observations, "ui_checker_messages":ui_errors}, "\t"))
	f.close()
	print("AUDIT observations=%d ui_messages=%d" % [observations.size(), ui_errors])
	quit(0 if observations.size() == (26 if phone else 25) else 1)

func reset_case() -> void:
	paused = false
	main.help_label.hide()
	main.settings_panel.hide()
	main.records_panel.hide()
	main.notes_panel.hide()
	main.codex_panel.hide()
	main.vote_panel.hide()
	main.auto_start = false
	main.countdown = -1.0
	main.touch_ui = phone
	main.tip_tower = null
	main.card_dock.close_inspector()
	main.card_dock.inspector_dismissed = false
	main.card_dock.side.set_folded(false)
	seed(9009)
	await fixture()
	main.cards_system._set_card_detail(false)
	target.position = Vector2(280, 300)
	refused.position = Vector2(950, 300)
	main.touch_ui = phone
	await settle()

func record(id: String, data: Dictionary) -> void:
	observations.append({"id":id, "data":data})
	print("OBS ", id, " ", JSON.stringify(data))

func press_key(code: int, ctrl := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.ctrl_pressed = ctrl
	e.pressed = true
	VirtualInput.send(e)
	await settle()
	e.pressed = false
	VirtualInput.send(e)
	await settle()

func tap_at(p: Vector2) -> void:
	if phone:
		await touch(p, true)
		await touch(p, false)
	else:
		await mouse_click(p)

func placement_and_cancel() -> void:
	await reset_case()
	await tap_at(card_center(1))
	await tap_at(world(Vector2(470, 380)))
	record("new-placement-needs-direction", {"auto_aim":target.auto_aim(), "phase":main.phase, "aim_phase":main.Phase.AIM, "towers":main.towers.get_child_count(), "picks_left":main.picks_left})
	await snap("01-new-placement-direction")
	await tap_at(main.cancel_btn.get_global_rect().get_center())
	record("cancel-once", {"phase":main.phase, "place_phase":main.Phase.PLACE, "still_carrying":main.card_dock.carrying(), "picks_left":main.picks_left})
	await snap("02-cancel-once-still-carrying")
	await tap_at(main.cancel_btn.get_global_rect().get_center())
	record("cancel-twice", {"phase":main.phase, "choose_phase":main.Phase.CHOOSE, "picks_left":main.picks_left})
	await reset_case()
	await tap_at(card_center())
	await tap_at(world(target.position))
	var before := target.m("pierce")
	await press_key(KEY_Z, true)
	record("undo-after-card", {"applied":before, "after_ctrl_z":target.m("pierce"), "picks_left":main.picks_left, "card_detail_opened":Meta.card_detail})
	await snap("03-applied-ctrl-z")

func edit_ambiguity() -> void:
	await reset_case()
	main.cards_system._set_cards_hidden(true)
	await tap_at(world(target.position))
	record("first-object-tap", {"phase":main.phase, "selected":main.interaction_system.selected.size()})
	await tap_at(world(target.position))
	record("second-object-tap", {"phase":main.phase, "aim_phase":main.Phase.AIM, "moving":main.interaction_system.moving == target})
	await snap("04-second-tap-direction")
	await reset_case()
	main.cards_system._set_cards_hidden(true)
	await tap_at(world(target.position))
	if phone:
		await touch(world(target.position), true)
	else:
		await mouse_button(world(target.position), true)
	await create_timer(0.4).timeout
	await settle()
	record("long-press-object", {"dragging":main.interaction_system.dragging, "selected":main.interaction_system.selected.size(), "hold_ms":400})
	await snap("05-long-press-starts-moving")
	if phone:
		await touch(world(target.position), false)
	else:
		await mouse_button(world(target.position), false)
	if not phone:
		await reset_case()
		main.cards_system._set_cards_hidden(true)
		await mouse_click(world(target.position))
		var d: Vector2 = target.dir
		var e := InputEventMouseButton.new()
		e.position = world(target.position)
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		VirtualInput.send(e)
		await settle()
		record("wheel-on-selected", {"direction_changed":not target.dir.is_equal_approx(d), "zoom":main.view_zoom})
		await snap("06-wheel-changes-direction")

func nearby_target() -> void:
	await reset_case()
	target.position = Vector2(280, 300)
	refused.position = Vector2(315, 300)
	main.cards_system._set_cards_hidden(true)
	var at := Vector2(304, 300)
	await tap_at(world(at))
	record("nearby-target", {"distance_to_first":at.distance_to(target.position), "distance_to_second":at.distance_to(refused.position), "first_selected":main.interaction_system.selected == [target], "second_selected":main.interaction_system.selected == [refused]})
	await snap("07-nearer-object-not-selected")

func modal_shortcuts() -> void:
	await reset_case()
	await press_key(KEY_O)
	await press_key(KEY_1)
	record("settings-number-key", {"settings_visible":main.settings_panel.visible, "phase":main.phase, "picked_type":main.picked.get("type", ""), "picks_left":main.picks_left})
	await snap("08-settings-hidden-card-pick")
	await reset_case()
	await press_key(KEY_H)
	var rerolls: int = main.rerolls_left
	await press_key(KEY_Q)
	record("help-reroll-key", {"help_visible":main.help_label.visible, "rerolls_before":rerolls, "rerolls_after":main.rerolls_left})
	await snap("09-help-hidden-reroll")
	await reset_case()
	main.picks_left = 0
	main.cards_system._enter_ready()
	await press_key(KEY_O)
	await press_key(KEY_SPACE)
	record("settings-space-start", {"settings_visible":main.settings_panel.visible, "phase":main.phase, "wave_phase":main.Phase.WAVE})
	await snap("10-settings-hidden-start")
	await reset_case()
	await press_key(KEY_H)
	await press_key(KEY_S)
	record("help-skip-key", {"help_visible":main.help_label.visible, "skip_left":main.skip_left, "bank_picks":main.bank_picks.size(), "phase":main.phase})
	await snap("11-help-hidden-skip")

func automatic_progress() -> void:
	await reset_case()
	main.picks_left = 0
	main.cards_system._enter_ready()
	main.auto_start = true
	main.countdown = 2.0
	await settle()
	await tap_at(world(target.position))
	var info_before: bool = main.card_dock.side.visible
	main.frame_system._process(1.0)
	main.frame_system._process(1.1)
	record("auto-start-while-inspecting", {"inspector_was_visible":info_before, "phase":main.phase, "wave_phase":main.Phase.WAVE, "selected":main.interaction_system.selected.size()})
	await snap("12-inspection-auto-start")

func wave_actions() -> void:
	await reset_case()
	main.cards_system._enter_ready()
	main.run_flow_system._start_wave()
	main.run_id = "isolated-usability-audit"
	main.abilities_system._skills_new_run(0)
	await settle()
	var before: float = main.wave_time
	main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	main.frame_system._process(0.05)
	record("focus-out-wave", {"tree_paused":paused, "wave_time_before":before, "wave_time_after":main.wave_time})
	await snap("13-focus-out-keeps-running")
	await press_key(KEY_2)
	before = main.wave_time
	main.frame_system._process(0.05)
	record("skill-aim-time", {"armed":main.skill_arm, "time_before":before, "time_after":main.wave_time})
	await snap("14-skill-aim-running")
	await tap_at(world(target.position))
	record("hold-empty-area", {"armed":main.skill_arm, "cooldown":main.abilities_system.skill_left("hold"), "toast":main.toast.text})
	await press_key(KEY_ESCAPE)
	await tap_at(world(target.position))
	await press_key(KEY_ESCAPE)
	record("wave-first-escape", {"paused":paused, "inspector_visible":main.card_dock.side.visible})
	await press_key(KEY_ESCAPE)
	record("wave-second-escape", {"paused":paused})
	await snap("15-escape-pause")
	await reset_case()
	main.cards_system._enter_ready()
	main.run_flow_system._start_wave()
	await settle()
	await tap_at(world(target.position))
	var before_close: bool = main.card_dock.side.visible
	if before_close:
		await tap_at(main.card_dock.close_btn.get_global_rect().get_center())
	await tap_at(world(refused.position))
	await press_key(KEY_Z)
	record("wave-explicit-close-reopen", {"visible_before_close":before_close, "inspector_dismissed":main.card_dock.inspector_dismissed, "visible_after_other_object_and_z":main.card_dock.side.visible})
	await snap("19-wave-inspector-cannot-reopen")
	await reset_case()
	main.cards_system._enter_ready()
	main.run_flow_system._start_wave()
	var normal: float = main.game_speed
	await press_key(KEY_SPACE)
	record("space-during-wave", {"speed_before":normal, "speed_after":main.game_speed, "paused":paused})
	await snap("16-space-is-speed")

func skip_actions() -> void:
	await reset_case()
	var values := [int(Meta.skip_n)]
	for i in 4:
		await tap_at(main.skip_n_btn.get_global_rect().get_center())
		values.append(int(Meta.skip_n))
	record("skip-cycle", {"values":values, "tooltip":main.skip_btn.tooltip_text})
	await snap("17-skip-cycle")
	await tap_at(main.skip_btn.get_global_rect().get_center())
	record("skip-before-wave", {"phase":main.phase, "banked_picks":main.bank_picks.size(), "skip_left":main.skip_left})
	await snap("18-skip-bank")

func reading_actions() -> void:
	await reset_case()
	if phone:
		await tap_at(main.card_detail_btn.get_global_rect().get_center())
		await touch(card_center(), true)
		await create_timer(0.45).timeout
		await settle()
		record("phone-card-detail-hold", {"detail_on":Meta.card_detail, "preview_card":main.card_dock.preview_card(), "side_visible":main.card_dock.side.visible, "phase_before_release":main.phase})
		await snap("20-phone-detail-hold")
		await touch(card_center(), false)
		record("phone-card-detail-release", {"phase":main.phase, "still_carrying":main.card_dock.carrying(), "side_visible":main.card_dock.side.visible})
		await snap("21-phone-detail-release")
	await reset_case()
	target.add(Elem.FIRE, 2)
	target.add(Elem.WOOD, 1)
	target.eff = target.eff_now()
	await tap_at(world(target.position))
	record("inspector-with-cards", {"visible":main.card_dock.side.visible, "panel_height":main.card_dock.side.size.y, "preview_height":AttackPreview.HEIGHT, "scroll_height":main.card_dock.scroll.size.y, "picture_min_height":main.card_dock.pic.custom_minimum_size.y})
	await snap("22-inspector-with-cards")
	await reset_case()
	main.cards_system._set_cards_hidden(true)
	target.dealt = 1000.0
	refused.dealt = 500.0
	main.wave_time = 20.0
	main.dps_hidden = false
	main.hud_system.dps_choice_open = true
	main.hud_system.dps_sig = ""
	main.hud_system._refresh_dps()
	await settle()
	var row: Control = main.hud_system.dps_list.get_child(0)
	await tap_at(row.get_global_rect().get_center())
	record("dps-row-tap", {"selected":main.interaction_system.selected.size(), "inspected_target":main.card_dock.inspected_tower == target, "dps_focus":main.dps_focus == target})
	await snap("23-dps-row-tap")
