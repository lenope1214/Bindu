extends "res://tools/carry_check.gd"
## 실제 두 프로세스·로컬 중개·WebRTC로 요청/권한/준비/재접속을 검증한다.
## 인자: host|join <공유 코드 파일> <자기 캡처 폴더>. BINDU_MP_URL은 loopback만 허용.
var role := ""
var mode := "coop"
var inbox := {}
var results: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	var code_file: String = args[1]
	output = args[2]
	mode = OS.get_environment("MP_MODE")
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or not Mp.url().begins_with("http://127.0.0.1:") or OnlineConfig.SERVER_URL != "" or DisplayServer.get_name() == "headless":
		push_error("격리 native 사본과 로컬 중개가 필요합니다")
		quit(2)
		return
	create_timer(120).timeout.connect(func(): print("MPUX FAIL global timeout ", role); quit(2))
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 5
	Meta.guide_on = false
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	await settle()
	if main.tut.visible:
		await mouse_click(main.tut.btn_list.get_global_rect().get_center())
	main.touch_ui = false
	main.auto_start = false
	Meta.games = 5
	Meta.guide_on = false
	main.mp.packet.connect(func(_from: int, message: Dictionary):
		if message.get("t") == "qa":
			inbox[str(message.get("op", ""))] = message)
	if not Mp.available():
		print("MPUX FAIL native WebRTC unavailable")
		quit(1)
		return
	if role == "host":
		main.mp.room_ready.connect(func():
			var file := FileAccess.open(code_file, FileAccess.WRITE)
			file.store_string(main.mp.code)
			file.close())
		main.mp.host(mode, "로컬 호스트")
	else:
		await wait_for(func(): return FileAccess.file_exists(code_file) and FileAccess.get_file_as_string(code_file).length() == 6, "room-code")
		main.mp.join(FileAccess.get_file_as_string(code_file), "로컬 참가자")
	await wait_for(func(): return not main.mp.connected_ids().is_empty(), "real-webrtc-connected")
	trace("connected", {"id":main.mp.my_id,"peers":main.mp.connected_ids(),"extension":Mp.loaded()})
	if role == "host":
		main.lobby_system._mp_start()
	await wait_for(func(): return main.mp_mode == mode and not main.title_label.visible, "actual-game-start")
	await settle()
	await snap("initial-game")
	await place_one()
	await wait_for(func(): return main.multiplayer_system._my_towers().size() > 0, "own-tower")
	await wait_for(func(): return main.towers.get_child_count() >= 2 if mode == "coop" else true, "replicated-towers")
	if mode == "coop":
		await request_and_permissions()
		await readiness_and_recovery()
	else:
		await versus_progress()
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"role":role,"mode":mode,"failures":fails,"ui_messages":ui_errors,"results":results}, "\t"))
	file.close()
	print("MPUX %s %s failures=%d" % [mode,role,fails])
	await finish_qa_transport(code_file.get_base_dir(), "shutdown-" + mode, ["host", "join"])
	quit(1 if fails else 0)

## Dummy audio backend도 활성 WAV playback을 풀고 검사 노드를 종료한다.
func stop_qa_audio() -> void:
	if not is_instance_valid(main): return
	for player in main.sfx.players + main.sfx.lead + [main.sfx.music_player]:
		player.stream_paused = false
		player.stop()
		player.stream = null

## 실제 행동 검사가 끝난 뒤만 사용한다. 한 actor의 QA 종료가 다른 actor의 검증 중 단절이 되지 않게 한다.
func finish_qa_transport(directory: String, prefix: String, actors: Array) -> void:
	stop_qa_audio()
	if is_instance_valid(main):
		main.set_process(false)
		main.mp.set_process(false)
	FileAccess.open(directory.path_join(prefix + "-" + role), FileAccess.WRITE).store_string("network processing stopped after assertions")
	var until := Time.get_ticks_msec() + 10000
	while not actors.all(func(actor): return FileAccess.file_exists(directory.path_join(prefix + "-" + str(actor)))) and Time.get_ticks_msec() < until:
		await create_timer(0.025).timeout
	print("QA teardown barrier ", role, " all_stopped=", actors.all(func(actor): return FileAccess.file_exists(directory.path_join(prefix + "-" + str(actor)))))
	if is_instance_valid(main): main.mp.leave()
	await create_timer(0.1).timeout
	if is_instance_valid(main): main.queue_free()
	await process_frame

func wait_for(test: Callable, label: String, seconds := 20.0) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not test.call() and Time.get_ticks_msec() < until:
		await create_timer(0.05).timeout
	if not test.call():
		print("MPUX FAIL ", role, " ", label)
		quit(1)
		await process_frame
	else:
		print("MPUX wait-ok ", role, " ", label)

func trace(label: String, data: Dictionary) -> void:
	results.append({"event":label,"data":data})
	print("MPUX OBS ", role, " ", label, " ", JSON.stringify(data))

func wire(op: String, value: Variant = null) -> void:
	main.mp.send({"t":"qa","op":op,"value":value})

func first_element() -> int:
	for i in main.offer.size():
		if main.offer[i].get("type") == "elem":
			return i
	return -1

func place_one() -> void:
	if main.phase != main.Phase.CHOOSE:
		return
	await settle()
	var index := first_element()
	ok("BF-46", index >= 0, role + " 실제 선택지의 속성 카드 존재")
	if index < 0:
		return
	trace("card-pick-at", {"phase":main.phase,"paused":paused,"blocked":main.card_dock.input_blocked(),"rect":str(main.choice_box.get_child(index).get_global_rect())})
	await mouse_click(card_center(index))
	await wait_for(func(): return main.phase == main.Phase.PLACE, "card-held")
	var count: int = main.multiplayer_system._my_towers().size()
	var offset := Vector2(-210, -40 - count * 100) if role == "host" else Vector2(210, -40 - count * 100)
	var point: Vector2 = main.viewport_system.core() + offset
	await mouse_click(world(point))
	if main.phase == main.Phase.AIM:
		await mouse_click(world(point + Vector2(100 if role == "join" else -100, 0)))
	await wait_for(func(): return main.phase in [main.Phase.CHOOSE,main.Phase.READY], "actual-placement")
	trace("placed", {"mine":main.multiplayer_system._my_towers().size(),"picks":main.picks_left,"phase":main.phase})

func request_and_permissions() -> void:
	if role == "join":
		var card: Dictionary = main.offer[first_element()]
		wire("available-element", card)
		await wait_for(func(): return main.towers.get_children().any(func(t): return t.owner_id == 1 and t.req_e == card["e"]), "remote-request-visible")
		var remote: Tower
		for t: Tower in main.towers.get_children():
			if t.owner_id == 1:
				remote = t
		var origin := remote.position
		await mouse_button(world(origin), true)
		await mouse_move(world(origin + Vector2(70, 20)), true)
		await mouse_button(world(origin + Vector2(70, 20)), false)
		ok("BF-46", remote.position.is_equal_approx(origin), "실제 상대 오브젝트 드래그 거절")
		trace("peer-permission", {"owner":remote.owner_id,"selected":main.interaction_system.selected.size(),"inspector":main.card_dock.side.visible,"toast":main.toast.text})
		var info_text: String = main.card_dock.brief.text if main.card_dock.brief.visible else main.card_dock.detail.text
		info_text = info_text.replace(String.chr(0x2060), "")
		ok("BF-46", "로컬 호스트" in info_text and "소유자만" in info_text, "친구 정보에 소유자·편집 권한 지속 표시")
		await snap("peer-permission")
		var index: int = main.offer.find(card)
		await mouse_click(card_center(index))
		await wait_for(func(): return main.multiplayer_system.gifts().offer_status(remote, main.picked).get("ok", false), "live-request-protocol-ready")
		var picks_before: int = main.picks_left
		var offer_before: Array = main.offer.duplicate(true)
		var point := world(remote.position)
		VirtualInput.move(point)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = point
			click.global_position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			VirtualInput.send(click)
		ok("BF-46", not main.multiplayer_system.gifts().pending.is_empty() and main.picks_left == picks_before and main.offer == offer_before, "실제 전달 클릭 직후 ACK 전 선택·offer 미소비 예약")
		await wait_for(func(): return main.multiplayer_system.gifts().pending.is_empty() and not main.multiplayer_system.gifts().awaiting_settlement(), "actual-gift-ack-and-host-complete")
		ok("BF-46", main.picks_left == picks_before - 1, "호스트 확정 뒤 예약한 선택 정확히 1회 소비")
		ok("BF-46", main.picks_left == 0, "요청 전달은 보낸 사람의 선택 1회만 소비")
		trace("gift-sent", {"picks":main.picks_left,"toast":main.toast.text})
		wire("gift-sent")
	else:
		await wait_for(func(): return inbox.has("available-element"), "other-offer-announced")
		var card: Dictionary = inbox["available-element"]["value"]
		var own: Tower = main.multiplayer_system._my_towers()[0]
		var before := own.lv(card["e"])
		await mouse_click(main.mp_req_btn.get_global_rect().get_center())
		await mouse_click(world(own.position))
		await wait_for(func(): return main.lobby_system.mp_pop.visible, "request-popup")
		var chosen: Button
		for button in main.lobby_system.mp_pop.find_children("*", "Button", true, false):
			if button.text == Elem.NAMES[card["e"]]:
				chosen = button
		ok("BF-46", chosen != null, "실제 요청 팝업에서 친구 카드 속성 선택")
		if chosen == null:
			return
		await mouse_click(chosen.get_global_rect().get_center())
		ok("BF-46", own.req_e == card["e"], "요청은 내 대상에 설정")
		trace("request-set", {"owner":own.owner_id,"element":own.req_e,"toast":main.toast.text})
		await snap("request-set")
		await wait_for(func(): return own.lv(card["e"]) == before + int(card["lv"]), "real-gift-received")
		ok("BF-46", own.req_e == -1 and main.picks_left == 1, "실제 수신은 요청 해제·수신자 선택 보존")
		trace("gift-received", {"element":card["e"],"level":own.lv(card["e"]),"picks":main.picks_left,"toast":main.toast.text})
		await snap("gift-received")
		await place_one()

func readiness_and_recovery() -> void:
	await wait_for(func(): return main.phase == main.Phase.READY, "ready-state")
	if role == "host":
		await mouse_click(main.start_btn.get_global_rect().get_center())
		await create_timer(0.6).timeout
		ok("BF-46", main.phase == main.Phase.READY, "한 명 준비만으로 협동 웨이브 미시작")
		trace("waiting-for-participant", {"start":main.start_btn.text,"status":main.mp_bar.text,"ready":main.mp_ready})
		await snap("waiting-for-participant")
		var before_cancel: bool = main.mp_ready.get(1, false)
		await mouse_click(main.start_btn.get_global_rect().get_center())
		var after_cancel: bool = main.mp_ready.get(1, false)
		ok("BF-46", before_cancel and not after_cancel, "호스트가 같은 버튼으로 준비 취소")
		trace("ready-second-click", {"before":before_cancel,"after":after_cancel,"start":main.start_btn.text,"status":main.mp_bar.text})
		await snap("ready-second-click")
		wire("ready-canceled")
		await wait_for(func(): return inbox.has("cancel-observed"), "participant-observed-cancel")
		if not after_cancel:
			await mouse_click(main.start_btn.get_global_rect().get_center())
		wire("host-ready")
	else:
		await wait_for(func(): return inbox.has("ready-canceled"), "host-canceled")
		await wait_for(func(): return main.mp_wait_left <= 0.0 and main.mp_wait_show <= 0.0, "remote-wait-canceled")
		await mouse_click(main.start_btn.get_global_rect().get_center())
		var first_ready: bool = main.mp_i_ready
		await mouse_click(main.start_btn.get_global_rect().get_center())
		ok("BF-46", first_ready and not main.mp_i_ready, "참가자도 같은 버튼으로 준비 취소")
		await create_timer(0.15).timeout
		await wait_for(func(): return main.mp_wait_left <= 0.0 and main.mp_wait_show <= 0.0, "participant-wait-canceled")
		trace("participant-ready-canceled", {"ready":main.mp_i_ready,"wait_left":main.mp_wait_left,"wait_show":main.mp_wait_show,"phase":main.phase})
		wire("cancel-observed")
		await wait_for(func(): return inbox.has("host-ready"), "host-ready")
		trace("before-ready", {"start":main.start_btn.text,"status":main.mp_bar.text})
		await mouse_click(main.start_btn.get_global_rect().get_center())
	await wait_for(func(): return main.phase == main.Phase.WAVE and main.wave == 1, "synchronized-wave")
	var geometry_before := {"save":str(main.card_dock.save_btn.get_global_rect()), "version":str(main.ver_label.get_global_rect())}
	await settle()
	trace("wave", {"wave":main.wave,"phase":main.phase,"status":main.mp_bar.text,"towers":main.towers.get_child_count()})
	trace("wave-layout", {"before_process":geometry_before, "after_process":{"save":str(main.card_dock.save_btn.get_global_rect()), "version":str(main.ver_label.get_global_rect())}})
	ok("BF-46", not main.card_dock.save_btn.get_global_rect().intersects(main.ver_label.get_global_rect()), "멀티 전투 저장 상태 버튼·버전 글 겹침 없음")
	await snap("wave")
	if role == "join":
		var expected_wave: int = main.wave
		var mine_before: Array = main.multiplayer_system._my_towers().map(func(tower): return {"nid":tower.net_id, "elements":tower.elements.duplicate(true)})
		main.mp._fail("로컬 연결 중단 시험")
		trace("reconnecting", {"until":main.mp_rejoin_until,"status":main.mp_bar.text,"toast":main.toast.text})
		await snap("reconnecting")
		await wait_for(func(): return main.mp.my_id > 1 and not main.mp.connected_ids().is_empty() and main.mp_rejoin_until == 0, "real-reconnected", 30.0)
		await wait_for(func(): return main.phase == main.Phase.WAVE and main.wave == expected_wave, "actual-rejoined-same-wave", 5.0)
		var mine_after: Array = main.multiplayer_system._my_towers().map(func(tower): return {"nid":tower.net_id, "elements":tower.elements.duplicate(true)})
		ok("BF-46", mine_after == mine_before, "전투 중 재접속은 같은 웨이브와 내 오브젝트 속성을 복원")
		trace("recovered", {"wave":main.wave,"phase":main.phase,"status":main.mp_bar.text,"mine":main.multiplayer_system._my_towers().size()})
		await snap("recovered")
		wire("recovered")
		await create_timer(0.5).timeout
	else:
		await wait_for(func(): return inbox.has("recovered"), "participant-recovery-confirmed", 35.0)
		trace("participant-returned", {"others":main.mp_others,"toast":main.toast.text})
		await snap("participant-returned")

func versus_progress() -> void:
	await place_one()
	await wait_for(func(): return main.phase == main.Phase.READY, "vs-ready")
	await mouse_click(main.start_btn.get_global_rect().get_center())
	await wait_for(func(): return main.phase == main.Phase.WAVE, "vs-wave")
	trace("vs-wave", {"wave":main.wave,"lanes":main.lanes,"status":main.mp_bar.text})
	await snap("vs-wave")
	if role == "join":
		wire("vs-wave")
		await create_timer(0.4).timeout
		main.mp._fail("로컬 대결 연결 중단 시험")
		await wait_for(func(): return main.phase == main.Phase.GAMEOVER, "vs-disconnect-loss")
		trace("vs-disconnect", {"rank":main.mp_rank,"status":main.mp_bar.text})
		await snap("vs-disconnect")
	else:
		await wait_for(func(): return inbox.has("vs-wave"), "vs-peer-wave")
		await wait_for(func(): return main.mp_others.values().any(func(other): return other.get("gone", false) or not other.get("alive", true)), "vs-peer-disconnected")
		trace("vs-peer-disconnected", {"others":main.mp_others,"toast":main.toast.text})
		await snap("vs-peer-disconnected")
