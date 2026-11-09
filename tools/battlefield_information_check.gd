extends "res://tools/carry_check.gd"
## 정보 우선순위·대상 비교·DPS 선택·기술 유효 대상·적 고정 검사.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "" or DisplayServer.get_name() == "headless":
		quit(2)
		return
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
	main.auto_start = false
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	await create_timer(0.2).timeout
	await fixture()
	target.position = Vector2(280, 300)
	refused.position = Vector2(950, 300)
	main.touch_ui = phone
	main.cards_system._set_cards_hidden(true)
	await settle()
	var pic: InfoPanel = main.card_dock.pic
	pic.show_tower(target, false, 0.0, "실측 피해 몫", 310)
	ok("BF-21", pic.has_method("set_preview_visible"), "공격 예시를 별도 명시적으로 여는 API")
	if pic.has_method("set_preview_visible"):
		ok("BF-21", not pic.preview_visible and not pic.attack_preview.visible, "기본 정보는 공격 예시를 접고 수치부터")
		var compact := pic.tower_h()
		pic.set_preview_visible(true)
		ok("BF-21", pic.attack_preview.position.y >= pic.tower_header_h() + 120.0 and pic.tower_h() > compact, "수치 뒤 공격 예시·펼친 높이 반영")
		pic.set_preview_visible(false)
	var row: Control = main.hud_system._dps_row(target, 1, 50.0, 75.0, false)
	main.ui_root.add_child(row)
	row.position = Vector2(40, 150)
	row.size = Vector2(320, 42)
	await settle()
	await tap_at(row.get_global_rect().get_center())
	ok("BF-41", main.interaction_system.selected == [target] and main.card_dock.inspected_tower == target, "DPS 행 실제 클릭·터치가 전장 대상을 선택")
	ok("BF-41", row.focus_mode == Control.FOCUS_ALL, "DPS 행 키보드 포커스 가능")
	row.queue_free()
	await settle()
	ok("BF-25", main.hud_system.has_method("card_comparisons"), "후보별 적용 변화와 거절 이유 비교 API")
	if main.hud_system.has_method("card_comparisons"):
		var comparisons: Array = main.hud_system.card_comparisons({"type":"mod", "id":"pierce"})
		ok("BF-25", comparisons.size() == 2 and comparisons[0].allowed and not comparisons[1].allowed and comparisons[1].reason != "", "유효 대상과 막힌 대상의 이유 함께 제공")
		var original: Dictionary = target.mods.duplicate(true)
		main.hud_system.card_comparisons({"type":"mod", "id":"rapid"})
		ok("BF-25", target.mods == original and main.picks_left == 2, "비교는 실제 빌드·횟수 미변경")
	ok("BF-43", main.hud_system.has_method("support_summary"), "직접 피해와 지원 역할 사실 구분")
	if main.hud_system.has_method("support_summary"):
		target.add(Elem.WIND, 1)
		target.eff = target.eff_now()
		refused.position = target.position + Vector2(100, 0)
		ok("BF-43", "밀쳐내기" in main.hud_system.support_summary(target) and not "범위" in main.hud_system.support_summary(target), "현재 바람의 실제 제어 역할 표시 · 비활성 순풍을 지원으로 오인하지 않음")
	ok("BF-39", main.field_view_system.has_method("skill_aim_info"), "조준 중 실제 적용·면역 대상 요약")
	if main.field_view_system.has_method("skill_aim_info"):
		var p := Vector2(600, 300)
		var active := _orb(p, 50.0)
		var immune := _orb(p + Vector2(20, 0), 50.0)
		immune.root_immune = 2.0
		main.combat_system.grid.clear()
		main.live_orbs.assign([active, immune])
		main.combat_system._resolve(0.0, true)
		var info: Dictionary = main.field_view_system.skill_aim_info("hold", p)
		ok("BF-39", info.count == 1 and info.immune_count == 1 and active.root_timer == 0.0, "면역 제외 실제 1개·면역 1개, 조준은 적용하지 않음")
		var applied: bool = Skill.use(main, "hold", p)
		ok("BF-39", applied and active.root_timer > 0.0 and immune.root_timer == 0.0, "조준의 유효·면역 표시가 실제 붙잡기 결과와 일치")
		ok("BF-45", main.field_view_system.pin_orb_at(p), "적의 명시적 정보 고정")
		active.position += Vector2(100, 0)
		ok("BF-45", main.field_view_system.pinned_orb() == active, "적이 움직여도 같은 대상 유지")
		main.field_view_system.clear_orb_pin()
		ok("BF-45", main.field_view_system.pinned_orb() == null, "고정 정보 명시적 해제")
		main.field_view_system.pin_orb_at(active.position)
		active.hp = 0.0
		ok("BF-45", main.field_view_system.pinned_orb() == null, "죽은 적의 고정 참조 자동 해제")
	if main.hud_system.has_method("leak_review_text"):
		main.leak_log = [{"w":12,"n":2,"dmg":3,"lost":1,"dirs":{"북":2},"kinds":{Orb.Kind.FAST:2}}]
		var review: String = main.hud_system.leak_review_text()
		ok("BF-44", "북쪽 2개" in review and "빠른 2개" in review and "실제 손실 1" in review and "확정할 수 없" in review, "누수 방향·종류·실제 손실과 인과 진단 한계를 함께 표시")
		main.leak_log.clear()
		main.wave_leaks.clear()
		main.lanes.assign([0.0])
		var resistant := _orb(main.viewport_system.center() + Vector2(160, 0), 20.0)
		resistant.resist_e = Elem.WATER
		resistant.root_immune = 1.0
		var shielded := _orb(main.viewport_system.center() + Vector2(170, 0), 40.0)
		shielded.shield = 8.0
		shielded.sturdy = true
		main.combat_system._record_leak(resistant, 0)
		main.combat_system._record_leak(shielded, 1)
		main.combat_system._log_wave()
		var observed: String = main.hud_system.leak_review_text()
		ok("BF-44", "물 저항 1개" in observed and "보호막 남음 1개" in observed and "기절 일시 면역 1개" in observed and "실제 손실 1" in observed, "실제 통과 구체에서 저항·보호막·일시 면역을 기록하고 집계")
		ok("BF-44", not "길목이 비어" in " ".join(main.guide_lines.map(func(line): return str(line))), "누수만으로 빈 길목을 단정하지 않음")
	await snap("information-summary")
	print("INFORMATION failures=%d ui=%d" % [fails, ui_errors])
	quit(1 if fails else 0)

func tap_at(at: Vector2) -> void:
	if phone:
		await touch(at, true)
		await touch(at, false)
	else:
		await mouse_click(at)
