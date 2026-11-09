extends "res://tools/carry_check.gd"
## 요청한 예시의 실제 GUI 노출과 레이아웃 대기 중 닫기·대상 변경을 검증한다.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL!="" or OnlineConfig.MP_URL!="" or DisplayServer.get_name()=="headless":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	output=args[0];phone=args[2]=="phone"
	Tutorial.loaded=true;Tutorial.done=true;Tutorial.play_done=true
	Meta.games=5;Meta.guide_on=false;Meta.sim_phone=phone
	Meta.sim_safe=Rect2(86,0,86,38) if phone else Rect2()
	main=load("res://main.tscn").instantiate()
	VirtualInput.mount(main,root)
	await process_frame
	main.progression_system._hide_title();main.set_process(false);main.auto_start=false
	Meta.ui_scale=float(args[1]);main.hud_system._apply_ui_scale()
	await fixture()
	target.position=Vector2(300,320);refused.position=Vector2(950,320)
	for element in Elem.ALL:
		target.elements[element]=3
		if not element in target.order:target.order.append(element)
	target.eff=target.eff_now()
	main.phase=main.Phase.WAVE;main.wave_active=true
	main.to_spawn=1;main.spawn_timer=1000.0  # 빈 전투가 즉시 끝나 카드 줄로 바뀌지 않게 한다.
	main.abilities_system._skills_new_run(0)
	main.touch_ui=phone;main.cards_system._set_cards_hidden(true)
	var dock: CardDock=main.card_dock
	var pic: InfoPanel=dock.pic
	main.interaction_system._select_tower(target)
	main.tip_detail=true;pic.set_preview_visible(false)
	for i in 6:await settle()
	var presses := []
	dock.preview_btn.pressed.connect(func():presses.append(pic.preview_visible))
	var count: int=main.picks_left
	var camera: Transform2D=main.get_canvas_transform()
	await press_preview()
	print("PREVIEW observed callback=",presses," expanded=",pic.preview_visible," scroll=",dock.scroll.scroll_vertical," clip=",dock.scroll.get_global_rect()," example=",pic.attack_preview.get_global_rect())
	ok("I-11",pic.preview_visible and dock.scroll.scroll_vertical>0,"요청한 예시로 스크롤 이동")
	ok("I-11",dock.scroll.get_global_rect().grow(.1).encloses(pic.attack_preview.get_global_rect()),"예시 전체가 clip 안에 보임")
	ok("I-11",is_equal_approx(pic.attack_preview.size.x/pic.attack_preview.size.y,16.0/9.0),"원본16:9 비율 보존")
	await snap("preview-revealed")
	await press_preview()
	ok("I-11",not pic.preview_visible and dock.scroll.scroll_vertical==0,"접으면 핵심 수치로 복귀")
	await snap("primary-returned")
	# 실제 사용자 입력 뒤 비동기 callback이 아직 기다리는 같은 프레임의 상태 변경.
	dock.preview_btn.pressed.emit()
	dock.preview_btn.pressed.emit()
	await settle()
	ok("I-11",not pic.preview_visible and dock.scroll.scroll_vertical==0,"빠른 펼침/접기 뒤 오래된 reveal 없음")
	dock.preview_btn.pressed.emit()
	main.interaction_system._select_tower(refused)
	await settle()
	ok("I-11",pic.tower==refused and dock.scroll.scroll_vertical==0,"대상 변경 뒤 이전 callback이 새 정보를 스크롤하지 않음")
	pic.set_preview_visible(false)
	dock.preview_btn.pressed.emit()
	dock.close_inspector(true)
	await settle()
	ok("I-11",not dock.side.visible and dock.scroll.scroll_vertical==0,"닫은 뒤 이전 callback이 정보창을 복원하지 않음")
	main.interaction_system._select_tower(target)
	pic.set_preview_visible(false)
	await settle()
	dock.preview_btn.pressed.emit()
	dock.close_inspector(true)
	main.interaction_system._select_tower(target)
	await settle()
	ok("I-11",dock.side.visible and dock.scroll.scroll_vertical==0,"닫고 같은 대상을 바로 다시 열어도 이전 reveal은 취소됨")
	ok("I-11",main.picks_left==count and main.towers.get_child_count()==2 and main.get_canvas_transform().is_equal_approx(camera),"읽기 입력은 카드·오브젝트·전장 카메라 보존")
	for phase in [main.Phase.READY,main.Phase.CHOOSE]:
		main.phase=phase;main.wave_active=false;main.countdown=-1.0
		main.picks_left=2 if phase==main.Phase.CHOOSE else 0
		main.cards_hidden=true
		main.interaction_system._select_tower(target)
		pic.set_preview_visible(false)
		for i in 6:await settle()
		await press_preview()
		ok("I-11",pic.preview_visible and dock.scroll.get_global_rect().grow(.1).encloses(pic.attack_preview.get_global_rect()),"준비/선택의 전체 정보에서도 요청한 예시 노출: %d" % phase)
		await snap("preview-phase-%d" % phase)
		await press_preview()
		ok("I-11",not pic.preview_visible and dock.scroll.scroll_vertical==0,"준비/선택에서도 접으면 수치 복귀: %d" % phase)
	main.interaction_system._select_tower(target)
	pic.set_preview_visible(false)
	await settle()
	dock.preview_btn.pressed.emit()
	main.queue_free()
	for i in 4:await process_frame
	print("BATTLEFIELD PREVIEW failures=%d ui=%d" % [fails,ui_errors])
	quit(1 if fails else 0)

func press_preview() -> void:
	var at: Vector2=main.card_dock.preview_btn.get_global_rect().get_center()
	if phone:
		await touch(at,true);await touch(at,false)
	else:
		await mouse_move(at)
		print("PREVIEW GUI at=",at," button=",main.card_dock.preview_btn.get_global_rect()," hovered=",VirtualInput.viewport.gui_get_hovered_control()," filter=",main.card_dock.preview_btn.mouse_filter," passing=",main.card_dock.side.passing," blocked=",main.card_dock.input_blocked()," paused=",paused)
		await mouse_button(at,true)
		await mouse_button(at,false)
	await settle()
