extends SceneTree
## 기존 main/현재 소스의 실제3인 WebRTC. 게임 packet·capability·결과는 주입하지 않는다.
var main
var role := ""
var shared := ""
var output := ""
var cohort := ""
var version := ""
var verify_copy := false
var phone := false
var checks := 0
var fails := 0
var rows := []
var packets := []
const ACTORS := ["host", "peer_a", "peer_b"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role=args[0];shared=args[1];output=args[2];cohort=args[3];version=args[4]
	verify_copy=args.size()>5 and args[5]=="after"
	phone=OS.get_environment("MIXED_PROFILE")=="phone130"
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name()=="headless" or not Mp.url().begins_with("http://127.0.0.1:") or OnlineConfig.SERVER_URL!="" or OnlineConfig.MP_URL!="":
		quit(2)
		return
	create_timer(120).timeout.connect(func(): push_error("mixed native global timeout"); quit(2))
	Tutorial.loaded=true;Tutorial.done=true;Tutorial.play_done=true
	Meta.games=5;Meta.guide_on=false;Meta.skill_auto=false
	Meta.sim_phone=phone;Meta.sim_safe=Rect2(86,0,86,38) if phone else Rect2()
	main=load("res://main.tscn").instantiate()
	VirtualInput.mount(main,root)
	await process_frame
	await settle()
	Meta.ui_scale=1.3 if phone else 1.0
	main.hud_system._apply_ui_scale()
	await settle()
	if main.tut.visible:await click(main.tut.btn_list.get_global_rect().get_center())
	main.auto_start=false
	main.sfx.muted=true
	# 로컬 중개는 빈 ICE를 보내지만 제품은 빈 배열을 채택하지 않는다. QA만 host 후보로 고정한다.
	main.mp.ice=[]
	main.mp.packet.connect(observe_packet)
	ok(Mp.loaded() and Mp.available(),"native WebRTC extension available")
	ok(main.multiplayer_system.has_method("gifts")== (version=="current"),"actual version API matches actor")
	if role=="host":
		main.mp.room_ready.connect(func(): mark("room-code",main.mp.code))
		main.mp.host("coop","혼합 " + role)
	else:
		await wait_for(func():return exists("room-code","host"),"room-code")
		main.mp.join(str(read("room-code","host")),"혼합 " + role)
	await wait_for(func():return main.mp.connected_ids().size()==(2 if role=="host" else 1),"actual WebRTC peers")
	if role=="host":main.lobby_system._mp_start()
	await wait_for(func():return main.mp_mode=="coop" and main.mp_others.size()==2 and not main.title_label.visible,"actual three-player game start")
	await prepare_offer(2)
	await snapshot("initial-offer")
	rows.append({"before_pick":{"blocked":main.card_dock.input_blocked(),"tutorial":main.tut.visible,"rect":str(main.choice_box.get_child(0).get_global_rect()),"visible":main.choice_box.visible}})
	await click(main.choice_box.get_child(0).get_global_rect().get_center())
	await wait_for(func():return main.phase==main.Phase.PLACE,"actual card held")
	var index := ACTORS.find(role)
	var point := Vector2(240,420) if index==0 else Vector2(640,200) if index==1 else Vector2(1040,420)
	await click(world(point))
	if main.phase==main.Phase.AIM:await click(world(point+Vector2(110,0)))
	await wait_for(func():return main.multiplayer_system._my_towers().size()==1,"actual own placement")
	ok(main.picks_left==1,"own placement consumes exactly one pick")
	await prepare_offer(-1)
	mark("placed",state(own()))
	await all_marked("placed")
	await wait_for(func():return towers_match("placed"),"all owners replicated across actual transport")
	await create_timer(1.3).timeout
	if version=="current":
		var service: Object=main.multiplayer_system.gifts()
		ok(service.supported_all()==(cohort=="all_current"),"capability negotiation matches real versions")
		rows.append({"capability":service.debug_state(),"request_disabled":main.mp_req_btn.disabled,"request_text":main.mp_req_btn.text,"request_tooltip":main.mp_req_btn.tooltip_text,"mp_bar":main.mp_bar.text})
		ok(main.mp_req_btn.disabled==(cohort!="all_current"),"request button matches supported capability")
		if verify_copy:
			var notice: String=service.support_notice()
			if cohort=="all_current":
				ok(notice=="" and main.mp_req_btn.text=="속성 요청" and "쉬는 시간" in main.mp_req_btn.tooltip_text,"supported game restores normal request and useful hint")
			else:
				ok("업데이트" in notice and "새 판" in notice and notice in main.mp_bar.text,"unsupported or unconfirmed capability shows recovery without hover")
				ok(main.mp_req_btn.text==("요청 미지원" if cohort=="legacy_host" else "요청 확인 중"),"unsupported protocol differs from unconfirmed participant")
			ok(main.ui_root.get_global_rect().encloses(main.mp_bar.get_global_rect()),"capability text fits safe UI bounds")
			ok(main.mp_act.get_global_rect().position.y>=main.mp_bar.get_global_rect().end.y,"cooperative actions stay below status text")
	await snapshot("capability")
	var owner_role := "peer_a" if cohort=="current_host" else "host"
	if role==owner_role:
		if phone and not main.cards_hidden:
			await click(main.card_dock.focus_btn.get_global_rect().get_center())
		await click(main.mp_req_btn.get_global_rect().get_center())
		await click(world(own().position))
		await wait_for(func():return main.lobby_system.mp_pop.visible,"actual owner request menu")
		var water: Button
		for child in main.lobby_system.mp_pop.find_children("*","Button",true,false):
			if child.text==Elem.NAMES[Elem.WATER]:water=child
		ok(is_instance_valid(water),"Water request available")
		if water:await click(water.get_global_rect().get_center())
		mark("requested",state(own()))
		if main.cards_hidden:
			await click(main.card_dock.focus_btn.get_global_rect().get_center())
	await wait_for(func():return exists("requested",owner_role),"owner requested")
	var target_id := int(read("requested",owner_role).nid)
	await wait_for(func():return tower(target_id)!=null and tower(target_id).req_e==Elem.WATER,"actual remote request replicated")
	if role=="peer_b":
		var before: int=main.picks_left
		var original: Array=main.offer.duplicate(true)
		await click(main.choice_box.get_child(0).get_global_rect().get_center())
		await click(world(tower(target_id).position))
		if cohort=="all_current":
			await wait_for(func():return main.picks_left==before-1 and not main.multiplayer_system.gifts().blocks_local_choice(),"real gift commit and settlement")
			ok(main.phase==main.Phase.READY,"accepted gift uses last pick once")
		else:
			ok(main.picks_left==before and main.offer==original and main.phase==main.Phase.PLACE,"unsupported foreign placement preserves held card and pick")
			var toast: String=main.toast.text.replace("\u2060","")
			ok("지원" in toast and "업데이트" in toast,"blocked gift explains support and recovery action")
			rows.append({"blocked_toast":main.toast.text})
			await snapshot("blocked-gift")
			await key(KEY_ESCAPE)
			ok(main.phase==main.Phase.CHOOSE and main.picks_left==before,"blocked gift cancels without consumption")
		mark("attempted",true)
	await wait_for(func():return exists("attempted","peer_b"),"donor finished real attempt")
	if cohort=="all_current":
		await wait_for(func():return tower(target_id).elements.get(Elem.WATER,0)==int(read("requested",owner_role).elements[Elem.WATER])+1,"accepted gift owner and replicas converge")
	else:
		ok(elements_equal(state(tower(target_id)).elements,read("requested",owner_role).elements),"blocked gift did not mutate owner or replica")
	mark("gift-observed",true)
	await all_marked("gift-observed")
	# 남은 정상 선택을 자신에게 써서 혼합 상태의 편집·TW 전송도 확인한다.
	if main.picks_left>0:
		await click(main.choice_box.get_child(0).get_global_rect().get_center())
		await click(world(own().position))
		await wait_for(func():return main.phase==main.Phase.READY and main.picks_left==0,"same remaining Water card usable on own object")
	mark("edited",state(own()))
	await all_marked("edited")
	await wait_for(func():return towers_match("edited"),"post-edit TW convergence for every owner")
	if version=="current" and cohort!="all_current":
		var debug: Dictionary=main.multiplayer_system.gifts().debug_state()
		ok(debug.get("pending",{}).is_empty() and debug.get("host_ledger",{}).is_empty() and debug.get("terminal",{}).is_empty(),"mixed-version rejection creates no transaction or reservation")
	await snapshot("edited")
	await click(main.start_btn.get_global_rect().get_center())
	await wait_for(func():return main.phase==main.Phase.WAVE and main.wave==1,"real ready and wave start converge")
	ok(main.multiplayer_system._my_towers().size()==1 and main.towers.get_child_count()==3,"mixed-wave preserves all owner objects")
	await snapshot("wave")
	mark("verified",true)
	await all_marked("verified")
	await finish()

func prepare_offer(initial_picks: int) -> void:
	# 선택지 내용만 결정적으로 준비한다. 선택 소비·요청·결과·capability는 제품 동작이다.
	if initial_picks>=0:main.picks_left=initial_picks
	main.offer=[{"type":"elem","e":Elem.FIRE if initial_picks>=0 else Elem.WATER,"lv":1},{"type":"elem","e":Elem.EARTH,"lv":1},{"type":"mod","id":"rapid"}]
	if version=="current":ok(main.multiplayer_system.gifts().note_new_offer(),"valid fixture offer generation")
	main.cards_system._show_offer()
	main.cards_system._open_choose()
	await settle()

func own():return main.multiplayer_system._my_towers()[0]
func tower(nid: int):
	for node in main.towers.get_children():
		if node.net_id==nid:return node
	return null
func state(node) -> Dictionary:
	var elements := []
	for e in Elem.ALL:elements.append(int(node.elements.get(e,0)))
	return {"nid":node.net_id,"owner":node.owner_id,"elements":elements,"pattern":node.pattern,"req":node.req_e}
func towers_match(stage: String) -> bool:
	for actor in ACTORS:
		var expected: Dictionary=read(stage,actor)
		var node=tower(int(expected.nid))
		if node==null:return false
		var actual: Dictionary=state(node)
		for field in ["nid","owner","req"]:
			if int(actual[field])!=int(expected[field]):return false
		if str(actual.pattern)!=str(expected.pattern) or not elements_equal(actual.elements,expected.elements):return false
	return true
func elements_equal(left: Array, right: Array) -> bool:
	if left.size()!=right.size():return false
	for i in left.size():
		if int(left[i])!=int(right[i]):return false
	return true
func observe_packet(from: int, message: Dictionary) -> void:
	if message.get("t","") in ["tw","start","wave","ready"] or str(message.get("t","")).begins_with("gift_"):
		packets.append({"from":from,"message":message.duplicate(true)})
func mark(stage: String, value: Variant) -> void:
	var path := shared.path_join(stage+"-"+role+".json")
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
	DirAccess.rename_absolute(path+".tmp",path)
func exists(stage: String, actor: String) -> bool:return FileAccess.file_exists(shared.path_join(stage+"-"+actor+".json"))
func read(stage: String, actor: String) -> Variant:return JSON.parse_string(FileAccess.get_file_as_string(shared.path_join(stage+"-"+actor+".json")))
func all_marked(stage: String) -> void:await wait_for(func():return ACTORS.all(func(actor):return exists(stage,actor)),stage+" barrier")
func wait_for(test: Callable, label: String) -> void:
	var until := Time.get_ticks_msec()+20000
	while not test.call() and Time.get_ticks_msec()<until:await create_timer(0.05).timeout
	ok(test.call(),label)
	if not test.call():
		await snapshot("failed")
		FileAccess.open(output.path_join("failed-state.json"),FileAccess.WRITE).store_string(JSON.stringify({"phase":main.phase,"picks":main.picks_left,"towers":main.towers.get_children().map(state),"rows":rows,"packets":packets},"\t"))
		quit(1)
		await process_frame
func ok(condition: bool, label: String) -> void:
	checks+=1
	if not condition:fails+=1
	print("MIXED ",role," ","ok " if condition else "FAIL ",label)
func world(point: Vector2) -> Vector2:return main.get_canvas_transform()*point
func settle() -> void:
	for i in 4:await process_frame
func click(at: Vector2) -> void:
	VirtualInput.move(at)
	for pressed in [true,false]:
		if phone:
			var event := InputEventScreenTouch.new();event.position=at;event.pressed=pressed
			VirtualInput.send(event)
		else:
			var event := InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
			VirtualInput.send(event)
		await settle()
func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new();event.keycode=code;event.pressed=pressed
		VirtualInput.send(event)
		await settle()
func snapshot(label: String) -> void:
	await settle()
	RenderingServer.force_draw()
	main.get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))
func finish() -> void:
	var report := {"role":role,"version":version,"cohort":cohort,"id":main.mp.my_id,"checks":checks,"failures":fails,"native_extension":Mp.loaded(),"ice_servers":main.mp.ice,"rows":rows,"packets":packets}
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	# 모든 행동 단언 후에만 통신/음원을 함께 중지한다.
	main.set_process(false);main.mp.set_process(false)
	for player in main.sfx.players+main.sfx.lead+[main.sfx.music_player]:player.stop();player.stream=null
	mark("stopped",true)
	await all_marked("stopped")
	main.mp.leave()
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	print("MIXED FINAL ",role," checks=",checks," failures=",fails)
	quit(1 if fails else 0)
