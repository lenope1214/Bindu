extends "res://tools/carry_check.gd"
## 격리 native 화면: 효과 진하기와 효과 줄이기의 구분·입력·설정 동기화.
var evidence := {}
var baseline := false
var checks := 0

func ok(id: String, condition: bool, what: String) -> void:
	checks += 1
	super.ok(id,condition,what)

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(100).timeout.connect(func(): quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args[2] == "phone"
	baseline = args[3] == "before"
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
	main.sfx.muted = true
	Meta.ui_scale = float(args[1])
	main.hud_system._apply_ui_scale()
	await create_timer(0.2).timeout
	await fixture()
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.to_spawn = 1
	main.spawn_timer = 1000.0
	main.game_speed = 8.0
	main.bar_open = true
	await settle()
	start_camera = main.get_canvas_transform()
	evidence["bar_before"] = str(main.bar_box.get_global_rect())
	var default_config := ConfigFile.new()
	Meta.save_into(default_config)
	Meta.load_into(ConfigFile.new())
	ok("UI-52", not Meta.fx_low and Meta.fx_dps == 2, "기존 기본값: 장식 켬·약한 공격30%")
	Meta.load_into(default_config)
	await capture("effects-button")
	if not baseline:
		ok("UI-52", not main.fx_pick.flat and "▾" in main.fx_pick.text and main.fx_pick.get_theme_stylebox("normal") is StyleBoxFlat, "공통 버튼 표면·메뉴 열기 표시 유지")
	await tap(main.fx_pick.get_global_rect().get_center())
	var popup: PopupMenu = main.fx_pick.get_popup()
	ok("UI-52", popup.visible, "옵션 줄에서 효과 메뉴가 실제 입력으로 열림")
	ok("UI-52", main.get_viewport_rect().encloses(Rect2(popup.position,popup.size)), "효과 메뉴 전체가 화면 안에 표시")
	evidence["popup_items"] = menu_items(popup)
	evidence["popup_rect"] = str(Rect2(popup.position, popup.size))
	evidence["safe_rect"] = str(main.ui_root.get_global_rect())
	evidence["popup_inside_safe_rect"] = main.ui_root.get_global_rect().encloses(Rect2(popup.position,popup.size))
	if not baseline:
		ok("UI-52", evidence.popup_inside_safe_rect, "메뉴가 노치·홈 막대를 제외한 UI 안전 영역 안에 표시")
	await capture("effects-menu")
	if baseline:
		ok("UI-52", popup.item_count == 4 and not Meta.fx_low, "기존 빠른 메뉴는 진하기 네 개만 제공")
		await pick_item(popup, 3)
		ok("UI-52", Meta.fx_dps == 3 and not Meta.fx_low, "기존 효과15% 선택은 성능용 효과 줄이기를 켜지 않음")
	else:
		await improved_cases(popup)
	await settings_case()
	ok("UI-52", main.get_canvas_transform() == start_camera, "설정 조작 전후 전장 카메라 불변")
	ok("UI-52", evidence.bar_before == str(main.bar_box.get_global_rect()), "효과 줄이기 상태 표시 전후 옵션 줄 크기·위치 불변")
	ok("UI-52", main.phase == main.Phase.WAVE and main.game_speed == 8.0 and main.picks_left == 2 and not paused, "전투·선택 횟수·배속 보존과 명시적 재개")
	evidence.merge({"checks":checks,"failures":fails,"ui_errors":ui_errors,"camera_unchanged":main.get_canvas_transform() == start_camera,"bar_after":str(main.bar_box.get_global_rect())})
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("FX CONTROLS failures=%d ui=%d" % [fails,ui_errors])
	quit(1 if fails else 0)

func improved_cases(popup: PopupMenu) -> void:
	ok("UI-52", popup.is_item_checkable(0) and not popup.is_item_checked(0), "효과 줄이기는 진하기와 구분되는 체크 항목")
	await pick_item(popup, 0)
	ok("UI-52", Meta.fx_low and Meta.fx_dps == 2 and not popup.visible, "효과 줄이기는 진하기를 유지하고 한 번만 적용·닫힘")
	ok("UI-52", "줄임" in main.fx_pick.text and main.menu_system.fx_low_toggle.button_pressed, "빠른 버튼·설정 스위치 즉시 동기화")
	await capture("effects-reduced-button")
	for i in [0,1,3,2]:
		await tap(main.fx_pick.get_global_rect().get_center())
		var index: int = popup.get_item_index(i + 1)
		await pick_item(popup,index)
		ok("UI-52", Meta.fx_dps == i and Meta.fx_low, "진하기 %d 선택은 효과 줄이기를 보존" % i)
	await tap(main.fx_pick.get_global_rect().get_center())
	ok("UI-52", popup.is_item_checked(0) and popup.is_item_checked(popup.get_item_index(3)), "재개방 시 두 설정의 체크 상태 일치")
	await key_pair(KEY_ESCAPE)
	ok("UI-52", not popup.visible and not paused, "Esc는 빠른 메뉴만 닫고 전투 정지를 유발하지 않음")
	# 키보드 메뉴 탐색도 실제 Viewport 입력으로 검증한다.
	await tap(main.fx_pick.get_global_rect().get_center())
	for step in popup.item_count:
		if popup.get_focused_item() == 0: break
		await key_pair(KEY_DOWN)
	ok("UI-52", popup.get_focused_item() == 0, "방향키로 효과 줄이기 항목 탐색")
	await key_pair(KEY_ENTER)
	ok("UI-52", not Meta.fx_low and Meta.fx_dps == 2 and not main.menu_system.fx_low_toggle.button_pressed, "키보드로 줄이기 해제·진하기 보존·설정 동기화")
	var cfg := ConfigFile.new()
	Meta.save_into(cfg)
	Meta.fx_low = true
	Meta.fx_dps = 0
	Meta.load_into(cfg)
	ok("UI-52", not Meta.fx_low and Meta.fx_dps == 2, "독립된 두 설정 저장·복원")

func settings_case() -> void:
	await key_pair(KEY_P)
	ok("UI-52", paused and main.pause_box.visible, "정지 화면 진입")
	var setting_button: Button
	for child in main.pause_box.get_children():
		if child is Button and child.tooltip_text.begins_with("설정"):
			setting_button = child
	ok("UI-52", is_instance_valid(setting_button), "정지 화면 설정 버튼 존재")
	if not is_instance_valid(setting_button): return
	await tap(setting_button.get_global_rect().get_center())
	ok("UI-52", main.settings_panel.visible and paused, "정지 화면 설정 실제 입력·정지 유지")
	var toggle: CheckButton = find_low(main.settings_panel)
	ok("UI-52", is_instance_valid(toggle), "설정의 효과 줄이기 스위치 존재")
	if not is_instance_valid(toggle): return
	evidence["settings_toggle_before_scroll"] = str(toggle.get_global_rect())
	var scroll: ScrollContainer = main.hud_system.panel_scroll.get(main.settings_panel)
	if is_instance_valid(scroll):
		scroll.ensure_control_visible(toggle)
		await settle()
	evidence["settings_toggle_after_scroll"] = str(toggle.get_global_rect())
	await capture("settings-effects")
	if not baseline:
		var previous: bool = Meta.fx_low
		await tap(toggle.get_global_rect().get_center())
		ok("UI-52", Meta.fx_low != previous and toggle.button_pressed == Meta.fx_low and paused, "설정 실제 클릭/터치가 효과 줄이기 전환·정지 유지")
		await key_pair(KEY_O)
		await key_pair(KEY_P)
		await tap(main.fx_pick.get_global_rect().get_center())
		var popup: PopupMenu = main.fx_pick.get_popup()
		ok("UI-52", popup.visible and popup.is_item_checked(0) == Meta.fx_low and Meta.fx_dps == 2, "설정 변경 뒤 빠른 메뉴 체크 상태 일치")
		ok("UI-52", main.ui_root.get_global_rect().encloses(Rect2(popup.position,popup.size)), "효과 줄임 상태로 재개방해도 UI 안전 영역 유지")
		await capture("effects-reduced")
		await key_pair(KEY_ESCAPE)
	else:
		await key_pair(KEY_O)
		await key_pair(KEY_P)

func find_low(node: Node) -> CheckButton:
	if node is CheckButton and node.text.begins_with("효과 줄이기"): return node
	for child in node.get_children():
		var found := find_low(child)
		if found: return found
	return null

func menu_items(popup: PopupMenu) -> Array:
	var result := []
	for i in popup.item_count: result.append({"id":popup.get_item_id(i),"text":popup.get_item_text(i),"checked":popup.is_item_checked(i)})
	return result

func pick_item(popup: PopupMenu, index: int) -> void:
	# 행 높이를 추측하지 않는다. 이동량·속도가 있는 실제 hover hit-test로 행을 찾는다.
	var at := Vector2(popup.position) + Vector2(popup.size.x / 2.0,0)
	for y in range(2,popup.size.y-1,2):
		at.y = popup.position.y + y
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.relative = Vector2(0,2)
		motion.velocity = Vector2(0,120)
		VirtualInput.send(motion)
		await process_frame
		if popup.get_focused_item() == index:
			await tap(at)
			return
	ok("UI-52",false,"메뉴 행 실제 hit-test 실패: %d" % index)
	popup.hide()

func tap(at: Vector2) -> void:
	if phone:
		await touch(at,true)
		await touch(at,false)
	else:
		await mouse_click(at)

func key_pair(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		VirtualInput.send(event)
		await settle()

func capture(label: String) -> void:
	await settle()
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))
