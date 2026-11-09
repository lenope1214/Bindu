extends "res://tools/battlefield_multiplayer_check.gd"
## 세 독립 native 참가자. 같은 유효 초기 offer만 fixture로 고정하고 거래 결과는 실제 WebRTC로 검증한다.
## 인자: host|peer_a|peer_b <공유 조정 폴더> <자기 증거 폴더> <scenario>
var shared := ""
var scenario := "race"
var service: Object
var participants := {}
var hold_types: Array[String] = []
var held_packets: Array[Dictionary] = []
var packet_trace: Array[Dictionary] = []
var actor_done := false
var fixture_before := {}
var local_request := {}
var initial_round := ""
var subject_id := 0
var dispatching_held := false
var finishing := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	shared = args[1]
	output = args[2]
	scenario = args[3] if args.size() > 3 else "race"
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or not Mp.url().begins_with("http://127.0.0.1:") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "" or DisplayServer.get_name() == "headless":
		push_error("격리 native 사본과 loopback 중개만 허용")
		quit(2)
		return
	create_timer(180).timeout.connect(func(): print("GIFT FAIL timeout ", role, " ", scenario); _finish(2))
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.sim_phone = OS.get_environment("GIFT_DEVICE") == "phone"
	Meta.sim_safe = Rect2(86, 0, 86, 38) if Meta.sim_phone else Rect2()
	Meta.games = 5
	Meta.guide_on = false
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	await settle()
	Meta.ui_scale = float(OS.get_environment("GIFT_SCALE")) if OS.has_environment("GIFT_SCALE") else 1.0
	main.hud_system._apply_ui_scale()
	if main.tut.visible:
		await mouse_click(main.tut.btn_list.get_global_rect().get_center())
	main.touch_ui = false
	main.auto_start = false
	Meta.skill_auto = false
	Meta.guide_on = false
	main.set_meta("gift_qa_receive", _receive_gate)
	main.mp.packet.connect(_qa_packet)
	if not Mp.available():
		print("GIFT DEPENDENCY native WebRTC unavailable")
		_finish(2)
		return
	var code_file := shared.path_join("code.txt")
	if role == "host":
		main.mp.room_ready.connect(func(): FileAccess.open(code_file, FileAccess.WRITE).store_string(main.mp.code))
		main.mp.host("coop", "로컬 조정자")
	else:
		await wait_for(func(): return FileAccess.file_exists(code_file) and FileAccess.get_file_as_string(code_file).length() == 6, "room-code")
		main.mp.join(FileAccess.get_file_as_string(code_file), "로컬 " + role)
	await wait_for(func(): return main.mp.connected_ids().size() == (2 if role == "host" else 1), "actual-three-peer-transport")
	trace("connected", {"id":main.mp.my_id, "peers":main.mp.connected_ids(), "native_extension":Mp.loaded()})
	if role == "host":
		main.lobby_system._mp_start()
	await wait_for(func(): return main.mp_mode == "coop" and main.mp_others.size() == 2 and not main.title_label.visible, "actual-three-player-start")
	if not main.multiplayer_system.has_method("gifts"):
		print("GIFT DEPENDENCY multiplayer.gifts API unavailable")
		_finish(2)
		return
	service = main.multiplayer_system.gifts()
	if service == null or not service.has_method("debug_state"):
		print("GIFT DEPENDENCY transaction debug_state unavailable")
		_finish(2)
		return
	initial_round = str(transaction_state().get("round_id", ""))
	ok("I-04", initial_round != "", "실제 start가 발급한 round id 존재")
	participants[role] = main.mp.my_id
	announce("hello", {"role":role, "id":main.mp.my_id})
	await _run_scenario()
	_finish(1 if fails or ui_errors else 0)

func mouse_click(point: Vector2) -> void:
	if Meta.sim_phone:
		await touch(point, true)
		await touch(point, false)
	else:
		await super.mouse_click(point)

func _qa_packet(from: int, message: Dictionary) -> void:
	if message.get("t") != "qa_gift":
		return
	var op := str(message.get("op", ""))
	inbox[op] = message
	if op == "hello":
		participants[str(message.value.role)] = from

func wait_for(test: Callable, label: String, seconds := 20.0) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not test.call() and Time.get_ticks_msec() < until:
		await create_timer(0.05).timeout
	if not test.call():
		fails += 1
		trace("wait-failed", {"label":label, "choice":choice_state() if is_instance_valid(main) else {}, "transaction":transaction_state() if service != null else {}, "held":held_packets})
		print("GIFT FAIL wait ", role, " ", label)
		_finish(1)
		await process_frame
	else:
		print("GIFT wait-ok ", role, " ", label)

func announce(op: String, value: Variant = null, to := 0) -> void:
	var message := {"t":"qa_gift", "op":op, "value":value}
	if to == 0 or to == main.mp.my_id:
		_qa_packet(main.mp.my_id, message)
	if to == 0 and main.mp.is_host():
		for id in main.mp.connected_ids():
			if not main.mp_kicked.has(id): main.mp.send(message.duplicate(true), int(id))
	else:
		main.mp.send(message, to)

## 격리 사본의 _mp_packet 앞에서만 호출된다. 실제 RTC 수신 후 제품 handler dispatch를 지연한다.
func _receive_gate(from: int, message: Dictionary) -> bool:
	if dispatching_held:
		return false
	var kind := str(message.get("t", ""))
	if not kind.begins_with("gift_"):
		return false
	packet_trace.append({"from":from, "message":message.duplicate(true), "at_ms":Time.get_ticks_msec()})
	if kind in hold_types:
		held_packets.append({"from":from, "message":message.duplicate(true)})
		trace("held-real-packet", {"from":from, "type":kind, "gift_id":message.get("gift_id", "")})
		return true
	return false

func release_held(kind: String) -> void:
	hold_types.erase(kind)
	var remaining: Array[Dictionary] = []
	for packet: Dictionary in held_packets:
		if packet.message.get("t") == kind:
			dispatching_held = true
			main.multiplayer_system._mp_packet(int(packet.from), packet.message.duplicate(true))
			dispatching_held = false
		else:
			remaining.append(packet)
	held_packets = remaining

func transaction_state() -> Dictionary:
	service = main.multiplayer_system.gifts()
	var state: Dictionary = service.call("debug_state")
	return state.duplicate(true)

func choice_state() -> Dictionary:
	return {"offer":main.offer.duplicate(true), "picks":main.picks_left, "bank":main.bank_picks.duplicate(), "rerolls":main.rerolls_left, "phase":main.phase}

func _run_scenario() -> void:
	await wait_for(func(): return participants.size() == 3, "three-role-identities")
	await wait_for(func(): return transaction_state().get("implementation_ready", false) and service.call("supported_all"), "protocol-v1-supported-by-all")
	if scenario in ["race", "race_reverse", "ack_loss", "complete_loss", "donor_rejoin", "donor_rejoin_before_commit", "old_round", "force_fence", "retire_donor"]:
		await prepare_fixture("host")
		if role == "host":
			await direct_race()
		else:
			await act_race_donor()
	elif scenario in ["owner_rejoin", "owner_rejoin_before_commit"]:
		await prepare_fixture("peer_a")
		await owner_recovery_case()
	elif scenario in ["host_donor", "retire_owner"]:
		await prepare_fixture("peer_a")
		await host_donor_case()
	elif scenario == "donor_edit_rejoin":
		await prepare_fixture("host")
		await donor_edit_rejoin_case()
	else:
		print("GIFT FAIL unknown scenario: ", scenario)
		fails += 1

func subject() -> Tower:
	for tower: Tower in main.towers.get_children():
		if tower.net_id == subject_id and not tower.is_queued_for_deletion():
			return tower
	return null

## 3인에게 같은 유효 Lv1 카드와 미룬 선택을 준비한다. 거래 상태·결과는 주입하지 않는다.
func prepare_fixture(owner_role: String) -> void:
	main.auto_start = false
	main.bank_picks = [] if role == owner_role else [0]
	main.picks_left = 2
	main.rerolls_left = 1
	main.offer = [{"type":"elem", "e":Elem.FIRE if role == owner_role else Elem.WATER, "lv":1}, {"type":"elem", "e":Elem.EARTH, "lv":1}, {"type":"mod", "id":"rapid"}]
	ok("I-04", service.call("note_new_offer"), "예약 없는 초기 fixture offer generation 등록")
	main.cards_system._show_offer()
	main.cards_system._open_choose()
	main.banner_t = 0.0
	main.banner_queue.clear()
	await settle()
	trace("fixture-only", {"owner_role":owner_role, "choice":choice_state(), "round":initial_round})
	if role == owner_role:
		await mouse_click(card_center(0))
		var point: Vector2 = main.viewport_system.core() + Vector2(0, -145)
		await mouse_click(world(point))
		if main.phase == main.Phase.AIM:
			await mouse_click(world(point + Vector2(110, 0)))
		await wait_for(func(): return main.multiplayer_system._my_towers().size() == 1, "owner-actual-placement")
		var own: Tower = main.multiplayer_system._my_towers()[0]
		subject_id = own.net_id
		await mouse_click(main.mp_req_btn.get_global_rect().get_center())
		await mouse_click(world(own.position))
		await wait_for(func(): return main.lobby_system.mp_pop.visible, "owner-request-popup")
		var request_button: Button
		for button: Button in main.lobby_system.mp_pop.find_children("*", "Button", true, false):
			if button.text == Elem.NAMES[Elem.WATER]: request_button = button
		ok("I-04", request_button != null, "실제 요청 팝업에 물 속성 존재")
		if request_button == null: return
		await mouse_click(request_button.get_global_rect().get_center())
		ok("I-04", own.req_e == Elem.WATER and int(own.get_meta("gift_request_id", 0)) > 0, "실제 버튼 요청에 request id 부여")
		announce("subject", {"nid":subject_id, "owner":main.mp.my_id})
	else:
		await wait_for(func(): return inbox.has("subject"), "subject-announced")
		subject_id = int(inbox.subject.value.nid)
		await wait_for(func(): return subject() != null and subject().req_e == Elem.WATER and service.call("offer_status", subject(), main.offer[0]).get("ok", false), "same-live-request-observed")
	fixture_before = choice_state()
	announce("prepared-" + role, {"choice":fixture_before, "nid":subject_id})

func received(kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for packet: Dictionary in packet_trace:
		if packet.message.get("t") == kind:
			found.append(packet)
	return found

func unique_held_requests() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var ids := {}
	for packet: Dictionary in held_packets:
		if packet.message.get("t") != "gift_request": continue
		var key := str(packet.from) + ":" + str(packet.message.get("gift_id", ""))
		if not ids.has(key):
			ids[key] = true
			found.append(packet)
	return found

func choices_equal(left: Dictionary, right: Dictionary) -> bool:
	for field: String in ["offer", "picks", "bank", "rerolls"]:
		if left.get(field) != right.get(field): return false
	return true

func pending_on() -> bool:
	return not transaction_state().get("pending", {}).is_empty()

func check_pending_controls() -> void:
	var before := choice_state()
	await key(KEY_Q)
	await key(KEY_S)
	await key(KEY_2)
	await key(KEY_ESCAPE)
	var cancel := InputEventMouseButton.new()
	cancel.position = world(subject().position)
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	VirtualInput.send(cancel)
	await settle()
	main.cards_system._on_reroll()
	main.run_flow_system._on_skip()
	main.lobby_system._mp_auto_rest()
	main.touch_ui = Meta.sim_phone
	await settle()
	ok("I-04", pending_on() and choices_equal(before, choice_state()), "ACK 전 키·reroll·skip·AFK가 예약 offer/picks/bank를 바꾸지 않음")
	ok("I-04", main.cancel_btn.disabled and main.start_btn.disabled and main.skip_btn.disabled and main.reroll_btn.disabled and main.card_dock.select_btn.disabled and main.card_dock.select_all_btn.disabled, "예약 중 취소·진행·다시 뽑기·편집 버튼은 비활성으로 표시")
	ok("I-04", "확인" in main.cancel_btn.text, "예약 중 취소 버튼은 가능 행동 대신 결과 확인 상태 표시")
	await snap("pending-reservation")
	var note: Dictionary = main.field_view_system.place_note
	var lines: PackedStringArray = note.get("lines", PackedStringArray())
	ok("I-04", not note.get("refuse", true) and not lines.is_empty() and "확인" in lines[0], "전달 대기는 거절 X 대신 중립 확인 안내로 표시")
	announce("pending-checked-" + role)

func direct_race() -> void:
	await wait_for(func(): return inbox.has("prepared-peer_a") and inbox.has("prepared-peer_b"), "all-actors-prepared")
	hold_types.append("gift_request")
	announce("begin-race")
	await wait_for(func(): return unique_held_requests().size() == 2, "two-actual-inflight-gifts")
	var requests := unique_held_requests()
	ok("I-04", requests[0].from != requests[1].from and requests[0].message.request_id == requests[1].message.request_id and requests[0].message.e == requests[1].message.e, "서로 다른 두 실제 donor가 같은 요청·속성을 전송")
	for packet: Dictionary in requests:
		for actor: String in ["peer_a", "peer_b"]:
			if int(participants[actor]) == int(packet.from):
				announce("original-" + actor, packet.message, int(packet.from))
	var level: int = subject().lv(Elem.WATER)
	if scenario == "donor_rejoin_before_commit":
		announce("rejoin-before-commit")
		await wait_for(func(): return inbox.has("rejoined-peer_a"), "uncommitted-donor-restored", 40.0)
	var first_actor := "peer_b" if scenario == "race_reverse" else "peer_a"
	held_packets.sort_custom(func(left, right): return int(left.from) == int(participants[first_actor]) and int(right.from) != int(participants[first_actor]))
	release_held("gift_request")
	await wait_for(func(): return transaction_state().host_ledger.size() == 2 and transaction_state().host_ledger.values().all(func(entry): return not entry.result.is_empty()), "both-terminal-owner-decisions")
	var before := choice_state()
	main.multiplayer_system._mp_try_go(true)
	ok("I-04", not service.call("before_wave") and main.phase != main.Phase.WAVE and choices_equal(before, choice_state()), "미정산 ACK가 있으면 강제 wave·host 자동 선택도 보류")
	announce("check-pending")
	await wait_for(func(): return inbox.has("pending-checked-peer_a") and inbox.has("pending-checked-peer_b"), "both-pending-controls-checked")
	if scenario == "ack_loss":
		announce("drop-first-acks")
		await wait_for(func(): return inbox.has("retry-ack-peer_a") and inbox.has("retry-ack-peer_b"), "same-token-retry-after-lost-ack")
	elif scenario == "donor_rejoin":
		announce("rejoin-peer_a")
		await wait_for(func(): return inbox.has("rejoined-peer_a"), "pending-donor-restored", 40.0)
	elif scenario == "retire_donor":
		await kick_actor("peer_a")
		await wait_for(func(): return transaction_state().host_ledger.values().any(func(entry): return int(entry.request.donor_id) == int(participants.peer_a) and entry.settled), "retired-donor-terminal-settled")
		announce("retired-observed")
	announce("release-acks")
	if scenario == "retire_donor":
		await wait_for(func(): return inbox.has("resolved-peer_b"), "surviving-donor-resolved")
		ok("I-04", subject().lv(Elem.WATER) == level + 1 and transaction_state().host_ledger.size() == 2, "퇴장 donor의 이미 확정된 선물도 중복 없이 한 번만 유지")
		await snap("retired-donor-owner")
		announce("finish")
		await create_timer(0.35).timeout
		return
	await wait_for(func(): return inbox.has("resolved-peer_a") and inbox.has("resolved-peer_b"), "both-donors-resolved")
	var accepted := int(inbox["resolved-peer_a"].value.accepted) + int(inbox["resolved-peer_b"].value.accepted)
	ok("I-04", accepted == 1 and subject().lv(Elem.WATER) == level + 1 and subject().req_e == -1, "owner 속성 +1과 정확히 한 accept·한 reject")
	ok("I-04", inbox["resolved-" + first_actor].value.accepted, "실제 dispatch 선착순 donor만 수락")
	if scenario == "complete_loss":
		for actor in ["peer_a", "peer_b"]:
			var repeated: Array[Dictionary] = received("gift_settled").filter(func(packet): return int(packet.from) == int(participants[actor]))
			ok("I-04", repeated.size() >= 2 and repeated.all(func(packet): return str(packet.message.gift_id) == str(repeated[0].message.gift_id)), "완료 유실 뒤 동일 token settled를 실제 RTC로 재전송")
	var ledger: Dictionary = transaction_state().host_ledger
	ok("I-04", ledger.values().filter(func(entry): return entry.get("status") == "accepted").size() == 1 and ledger.values().filter(func(entry): return entry.get("status") == "rejected").size() == 1, "host ledger도 한 accepted·한 rejected로 확정")
	ok("I-04", main.picks_left == fixture_before.picks and main.bank_picks == fixture_before.bank, "수신 owner 선택·bank는 소비하지 않음")
	await wait_for(func(): return transaction_state().host_ledger.values().all(func(entry): return entry.settled), "all-settled-at-host")
	announce("replay-requests")
	await wait_for(func(): return inbox.has("replayed-peer_a") and inbox.has("replayed-peer_b"), "duplicate-request-idempotency")
	for actor: String in ["peer_a", "peer_b"]:
		main.mp.send(inbox["resolved-" + actor].value.ack.duplicate(true), int(participants[actor]))
	announce("replayed-acks")
	await wait_for(func(): return inbox.has("duplicates-checked-peer_a") and inbox.has("duplicates-checked-peer_b"), "duplicate-ack-idempotency")
	await wait_for(func(): return service.call("before_wave"), "settled-barrier-handshake-released")
	ok("I-04", subject().lv(Elem.WATER) == level + 1, "중복 패킷 뒤 추가 적용 없음·모든 정산 뒤 barrier 해제")
	trace("race-final", {"level":subject().lv(Elem.WATER), "host":transaction_state()})
	await snap("owner-final")
	if scenario == "force_fence":
		announce("force-fence")
		main.multiplayer_system._mp_try_go(true)
		await wait_for(func(): return main.phase == main.Phase.WAVE and main.wave == 1, "host-force-after-all-settled-starts-real-wave")
		await wait_for(func(): return inbox.has("wave-observed-peer_a") and inbox.has("wave-observed-peer_b"), "fenced-wave-all-three-actors")
		ok("I-04", not pending_on() and subject().lv(Elem.WATER) == level + 1, "강제 선택·wave 전환 뒤 선물 적용 보존·미정산 없음")
		await snap("fenced-wave")
	if scenario == "old_round":
		announce("restart-round")
		await restart_and_replay()
	announce("finish")
	await create_timer(0.35).timeout

func act_race_donor() -> void:
	hold_types.append("gift_ack")
	if scenario == "complete_loss": hold_types.append("gift_complete")
	await mouse_click(card_center(0))
	ok("I-04", main.phase == main.Phase.PLACE and main.picks_left == fixture_before.picks, "실제 카드 들기는 선택 미소비")
	await wait_for(func(): return inbox.has("begin-race"), "shared-race-trigger")
	await mouse_click(world(subject().position))
	await wait_for(pending_on, "actual-transaction-pending")
	local_request = transaction_state().pending.request.duplicate(true)
	ok("I-04", choices_equal(fixture_before, choice_state()), "전송 직후에도 원래 offer/picks/bank 유지")
	if scenario == "donor_rejoin_before_commit" and role == "peer_a":
		await wait_for(func(): return inbox.has("rejoin-before-commit"), "uncommitted-reconnect-trigger")
		await reconnect_pending_donor()
	await wait_for(func(): return inbox.has("check-pending"), "pending-guard-trigger")
	await check_pending_controls()
	if scenario == "ack_loss":
		await wait_for(func(): return inbox.has("drop-first-acks") and held_packets.any(func(packet): return packet.message.get("t") == "gift_ack"), "first-ack-received-for-drop")
		held_packets.assign(held_packets.filter(func(packet): return packet.message.get("t") != "gift_ack"))
		trace("lost-ack", {"request":local_request})
		await wait_for(func(): return held_packets.any(func(packet): return packet.message.get("t") == "gift_ack"), "retry-returned-real-ack")
		announce("retry-ack-" + role)
	elif scenario == "donor_rejoin" and role == "peer_a":
		await wait_for(func(): return inbox.has("rejoin-peer_a"), "reconnect-trigger")
		await reconnect_pending_donor()
	elif scenario == "retire_donor" and role == "peer_a":
		await wait_for(func(): return main.phase == main.Phase.GAMEOVER, "actual-donor-kick-gameover")
		ok("I-04", not pending_on() and transaction_state().closed and choices_equal(fixture_before, choice_state()), "내보낸 donor는 소비 없이 판 예약 종료")
		await snap("retired-donor")
		return
	await wait_for(func(): return inbox.has("release-acks"), "settlement-trigger")
	release_held("gift_ack")
	await wait_for(func(): return not pending_on(), "ack-settled-locally")
	if scenario == "complete_loss":
		await wait_for(func(): return held_packets.any(func(packet): return packet.message.get("t") == "gift_complete"), "first-real-complete-received-for-drop")
		held_packets.assign(held_packets.filter(func(packet): return packet.message.get("t") != "gift_complete"))
		var reserved_after := choice_state()
		main.cards_system._on_reroll()
		main.run_flow_system._on_skip()
		main.lobby_system._mp_auto_rest()
		ok("I-04", service.call("awaiting_settlement") and choices_equal(reserved_after, choice_state()), "complete 유실 중 다음 선택은 잠겨 현재 offer 미소비")
		trace("lost-complete", {"gift_id":local_request.gift_id, "choice":reserved_after})
		await wait_for(func(): return held_packets.any(func(packet): return packet.message.get("t") == "gift_complete"), "same-token-settled-retry-returns-real-complete")
		release_held("gift_complete")
	await wait_for(func(): return not service.call("blocks_local_choice"), "host-confirmed-settlement-unlocks-choice")
	var after := choice_state()
	var accepted: bool = after.picks == int(fixture_before.picks) - 1
	if accepted:
		ok("I-04", after.picks == 1 and after.bank.size() == fixture_before.bank.size() - 1, "승자 선택·미룬 선택은 정확히 한 번 소비")
		ok("I-04", int(transaction_state().generation) > int(local_request.context.generation), "승자 정산 뒤 실제 새 offer generation 생성")
	else:
		ok("I-04", choices_equal(fixture_before, after) and main.picked == fixture_before.offer[0], "거절 donor는 동일 카드·offer·picks·bank 복원")
	var ack: Dictionary = received("gift_ack")[-1].message.duplicate(true)
	ok("I-04", ack.get("status") == ("accepted" if accepted else "rejected") and ack.get("gift_id") == local_request.gift_id and ack.get("fp") == local_request.fp, "실제 ACK 결과·token·payload가 소비 결과와 일치")
	if not accepted:
		ok("I-04", str(ack.get("reason", "")) != "" and main.toast.text != "", "거절 이유를 결과 패킷·실제 화면에 표시")
	trace("donor-result", {"accepted":accepted, "before":fixture_before, "after":after, "toast":main.toast.text, "transaction":transaction_state()})
	await snap("donor-result")
	announce("resolved-" + role, {"accepted":accepted, "ack":ack})
	if scenario == "retire_donor":
		await wait_for(func(): return inbox.has("finish"), "retire-survivor-finished")
		return
	await wait_for(func(): return inbox.has("replay-requests") and inbox.has("original-" + role), "duplicate-request-trigger")
	var ack_count := received("gift_ack").size()
	main.mp.send(inbox["original-" + role].value.duplicate(true), 1)
	await wait_for(func(): return received("gift_ack").size() > ack_count, "duplicate-request-returns-cached-ack")
	ok("I-04", choices_equal(after, choice_state()), "같은 token 재전송 뒤 선택 추가 소비 없음")
	announce("replayed-" + role)
	await wait_for(func(): return inbox.has("replayed-acks"), "duplicate-ack-trigger")
	await create_timer(0.2).timeout
	ok("I-04", choices_equal(after, choice_state()), "늦은 중복 ACK도 현재 선택을 바꾸지 않음")
	if not accepted and scenario in ["race", "race_reverse"]:
		var count: int = main.multiplayer_system._my_towers().size()
		var target: Vector2 = main.viewport_system.core() + Vector2(190, -145)
		await mouse_click(world(target))
		if main.phase == main.Phase.AIM: await mouse_click(world(target + Vector2(100, 0)))
		ok("I-04", main.multiplayer_system._my_towers().size() == count + 1 and main.picks_left == int(fixture_before.picks) - 1, "거절 donor는 보존한 같은 카드를 실제 빈 땅에 정상 사용")
		await snap("rejected-valid-alternative")
	announce("duplicates-checked-" + role)
	if scenario == "force_fence":
		await wait_for(func(): return inbox.has("force-fence"), "force-fence-trigger")
		await wait_for(func(): return main.phase == main.Phase.WAVE and main.wave == 1, "participant-received-authorized-wave")
		ok("I-04", not pending_on(), "실제 fence 이후 wave는 미정산 거래 없이 시작")
		await snap("fenced-wave")
		announce("wave-observed-" + role)
	if scenario == "old_round":
		await wait_for(func(): return inbox.has("restart-round"), "new-round-trigger")
		await restart_and_replay()
	await wait_for(func(): return inbox.has("finish"), "all-actors-finished")

func reconnect_pending_donor() -> void:
	var token := str(local_request.gift_id)
	main.mp._fail("로컬 gift ACK 전 연결 중단")
	await wait_for(func(): return main.mp.my_id > 1 and not main.mp.connected_ids().is_empty() and main.mp_rejoin_until == 0, "actual-pending-donor-rejoin", 35.0)
	var state := transaction_state()
	var same_pending: bool = pending_on() and str(state.pending.request.gift_id) == token
	var same_terminal: bool = state.terminal.values().any(func(result): return str(result.get("gift_id", "")) == token and str(result.get("round_id", "")) == initial_round)
	ok("I-04", (same_pending or same_terminal) and str(state.round_id) == initial_round, "donor 재접속은 동일 예약 token 또는 host 확정 결과로 복원")
	if scenario == "donor_rejoin_before_commit":
		ok("I-04", same_pending and choices_equal(fixture_before, choice_state()), "host 미확정 재접속은 예약 유지·선택 미소비")
	trace("donor-rejoined", {"choice":choice_state(), "transaction":transaction_state()})
	announce("rejoined-peer_a")

## donor가 자기 오브젝트를 설치한 뒤 마지막 선택을 선물로 소비한다. 편집은 소비한 카드를 되살리지 않는다.
func donor_edit_rejoin_case() -> void:
	if role == "host":
		await wait_for(func(): return inbox.has("edit-donor-ready"), "donor-own-tower-and-last-card-prepared")
		announce("edit-gift")
		await wait_for(func(): return transaction_state().host_ledger.values().any(func(entry): return entry.status == "accepted" and entry.settled), "last-card-gift-committed")
		await wait_for(func(): return inbox.has("edit-rejoined"), "ready-direction-edit-donor-recovered", 40.0)
		ok("I-04", subject().lv(Elem.WATER) == 1 and main.picks_left == fixture_before.picks, "편집 재접속 뒤 받은 선물은 1회·owner 선택 보존")
		await snap("edit-rejoin-owner")
		announce("finish")
		await create_timer(0.35).timeout
	elif role == "peer_a":
		await mouse_click(card_center(0))
		var point: Vector2 = main.viewport_system.core() + Vector2(190, -145)
		await mouse_click(world(point))
		if main.phase == main.Phase.AIM: await mouse_click(world(point + Vector2(100, 0)))
		await wait_for(func(): return main.multiplayer_system._my_towers().size() == 1 and main.picks_left == 1, "actual-donor-preparatory-placement")
		var own_id: int = main.multiplayer_system._my_towers()[0].net_id
		# 예약/결과 주입 없음. 이 조건만 마지막 유효 offer를 결정적으로 준비한다.
		main.offer = [{"type":"elem", "e":Elem.WATER, "lv":1}, {"type":"elem", "e":Elem.EARTH, "lv":1}, {"type":"mod", "id":"rapid"}]
		ok("I-04", service.call("note_new_offer"), "마지막 선택 fixture의 새 generation 등록")
		main.cards_system._show_offer()
		main.cards_system._open_choose()
		await settle()
		trace("fixture-edit-last-offer", {"choice":choice_state(), "own_nid":own_id})
		announce("edit-donor-ready")
		await wait_for(func(): return inbox.has("edit-gift"), "last-card-gift-trigger")
		await mouse_click(card_center(0))
		await mouse_click(world(subject().position))
		await wait_for(func(): return main.picks_left == 0 and main.phase == main.Phase.READY and not service.call("blocks_local_choice"), "actual-last-card-gift-ready")
		var own: Tower = main.multiplayer_system._my_towers()[0]
		await mouse_click(world(own.position))
		await key(KEY_E)
		ok("I-04", main.phase == main.Phase.AIM and main.interaction_system.moving != null and main.picks_left == 0, "실제 선택+E로 READY의 방향 편집 진입·선택0")
		await snap("zero-picks-direction-edit")
		main.mp._fail("로컬 선택0 방향 편집 중 재접속")
		await wait_for(func(): return main.mp.my_id > 1 and not main.mp.connected_ids().is_empty() and main.mp_rejoin_until == 0, "actual-editing-donor-reconnected", 35.0)
		await wait_for(func(): return main.phase == main.Phase.READY and main.picks_left == 0 and not service.call("blocks_local_choice"), "zero-choice-ready-context-restored")
		ok("I-04", main.interaction_system.moving == null and main.interaction_system.press_t == null and main.multiplayer_system._my_towers().size() == 1 and main.multiplayer_system._my_towers()[0].net_id == own_id, "재접속은 옛 편집 gesture를 정리하고 같은 오브젝트 복원")
		await mouse_click(world(main.viewport_system.core() + Vector2(280, -145)))
		ok("I-04", main.phase == main.Phase.READY and main.picks_left == 0 and main.multiplayer_system._my_towers().size() == 1, "빈 땅 클릭도 소비한 카드 부활·추가 설치 없음")
		trace("zero-choice-edit-rejoined", {"choice":choice_state(), "transaction":transaction_state(), "own_nid":own_id})
		await snap("zero-picks-edit-recovered")
		announce("edit-rejoined")
		await wait_for(func(): return inbox.has("finish"), "edit-rejoin-complete")
	else:
		await wait_for(func(): return inbox.has("finish"), "edit-rejoin-observer-finished", 50.0)
		ok("I-04", choices_equal(fixture_before, choice_state()), "편집 재접속은 관찰 참가자 선택을 바꾸지 않음")

## Popup 선택/확인 버튼을 실제 누른다. 서비스 내부 retire 플래그는 주입하지 않는다.
func kick_actor(actor: String) -> void:
	await mouse_click(main.mp_kick_btn.get_global_rect().get_center())
	await wait_for(func(): return main.lobby_system.mp_pop.visible, "kick-picker-visible")
	var person: Button
	for button: Button in main.lobby_system.mp_pop.find_children("*", "Button", true, false):
		if button.text == main.multiplayer_system._mp_name(int(participants[actor])): person = button
	ok("I-04", person != null, "내보내기 목록에 실제 참가자 표시")
	if person == null: return
	await mouse_click(person.get_global_rect().get_center())
	var confirm: Button
	for button: Button in main.lobby_system.mp_pop.find_children("*", "Button", true, false):
		if button.text == "내보내기": confirm = button
	ok("I-04", confirm != null, "실제 내보내기 확인 버튼 존재")
	if confirm == null: return
	await mouse_click(confirm.get_global_rect().get_center())
	await wait_for(func(): return main.mp_kicked.has(int(participants[actor])), "actual-host-kick-marked")

## host 자신도 donor일 때 owner는 별도 native 참가자다.
func host_donor_case() -> void:
	if role == "host":
		await wait_for(func(): return inbox.has("prepared-peer_a") and inbox.has("prepared-peer_b"), "host-donor-prepared")
		announce("host-gift")
		await mouse_click(card_center(0))
		await mouse_click(world(subject().position))
		await wait_for(pending_on, "host-own-donor-pending")
		local_request = transaction_state().pending.request.duplicate(true)
		ok("I-04", choices_equal(fixture_before, choice_state()), "host donor도 전송은 선택 예약이며 미소비")
		if scenario == "retire_owner":
			await wait_for(func(): return inbox.has("owner-apply-held"), "real-apply-delayed-before-owner-retirement")
			await kick_actor("peer_a")
		else:
			announce("owner-allow-apply")
		await wait_for(func(): return not pending_on(), "host-own-donor-terminal")
		var entry: Dictionary = transaction_state().host_ledger.values()[0]
		if scenario == "retire_owner":
			ok("I-04", entry.status == "rejected" and choices_equal(fixture_before, choice_state()) and subject().lv(Elem.WATER) == 0, "owner 퇴장은 host donor 원래 선택 보존·적용 0")
			ok("I-04", str(entry.result.reason) != "" and main.toast.text != "", "owner 퇴장 거절 이유를 화면에 표시")
		else:
			ok("I-04", entry.status == "accepted" and main.picks_left == int(fixture_before.picks) - 1 and main.bank_picks.size() == fixture_before.bank.size() - 1 and subject().lv(Elem.WATER) == 1, "host donor→remote owner 실제 전달도 적용·소비 한 번")
			var after := choice_state()
			var count := received("gift_result").size()
			announce("host-donor-replay-result")
			await wait_for(func(): return received("gift_result").size() > count, "remote-owner-replays-same-real-result")
			ok("I-04", choices_equal(after, choice_state()), "remote owner의 중복 결과가 만든 host 로컬 ACK 추가 소비 없음")
		await wait_for(func(): return transaction_state().host_ledger.values().all(func(row): return row.settled), "host-donor-settled")
		trace("host-donor-final", {"transaction":transaction_state(), "before":fixture_before, "after":choice_state(), "tower":subject().mp_state()})
		await snap("host-donor-final")
		announce("finish")
		await create_timer(0.35).timeout
	elif role == "peer_a":
		hold_types.append("gift_apply")
		await wait_for(func(): return held_packets.any(func(packet): return packet.message.get("t") == "gift_apply"), "host-request-arrives-as-real-owner-apply")
		announce("owner-apply-held")
		if scenario == "retire_owner":
			await wait_for(func(): return main.phase == main.Phase.GAMEOVER, "actual-owner-kick-gameover")
			ok("I-04", transaction_state().closed and subject().lv(Elem.WATER) == 0, "퇴장 owner는 미적용 요청을 수신해도 적용하지 않음")
			release_held("gift_apply")
			ok("I-04", subject().lv(Elem.WATER) == 0, "판 종료 뒤 지연된 apply도 무효")
			await snap("retired-owner")
			return
		else:
			await wait_for(func(): return inbox.has("owner-allow-apply"), "host-donor-apply-release")
			release_held("gift_apply")
			await wait_for(func(): return subject().lv(Elem.WATER) == 1, "remote-owner-accepted-host-gift")
			ok("I-04", main.picks_left == fixture_before.picks and main.bank_picks == fixture_before.bank, "remote 수신 owner는 선택 미소비")
			await snap("host-gift-recipient")
			await wait_for(func(): return inbox.has("host-donor-replay-result"), "duplicate-result-trigger")
			var original: Dictionary = received("gift_apply")[0].message
			var duplicate := original.duplicate(true)
			duplicate["t"] = "gift_result"
			var saved: Dictionary = transaction_state().owner_ledger.values()[0]
			duplicate.merge(saved, true)
			var owner_state: Dictionary = service.call("current_state")
			duplicate.merge({"owner_revision":owner_state.owner_revision, "owner_epoch":owner_state.owner_epoch, "owner_towers":owner_state.list, "to":1}, true)
			main.mp.send(duplicate, 1)
		await wait_for(func(): return inbox.has("finish"), "host-donor-owner-finished")
	else:
		await wait_for(func(): return inbox.has("finish"), "host-donor-observer-finished")
		ok("I-04", choices_equal(fixture_before, choice_state()), "관찰 참가자 선택은 거래·퇴장의 영향을 받지 않음")

func owner_recovery_case() -> void:
	if role == "host":
		await wait_for(func(): return inbox.has("prepared-peer_a") and inbox.has("prepared-peer_b"), "owner-recovery-prepared")
		if scenario == "owner_rejoin_before_commit": hold_types.append("gift_result")
		announce("single-gift")
		if scenario == "owner_rejoin_before_commit":
			await wait_for(func(): return held_packets.any(func(packet): return packet.message.get("t") == "gift_result" and packet.message.get("status") == "accepted"), "owner-applied-result-held-before-host-commit")
		else:
			await wait_for(func(): return transaction_state().host_ledger.values().any(func(entry): return entry.get("status") == "accepted"), "host-commit-before-owner-cut")
		announce("disconnect-owner")
		await wait_for(func(): return inbox.has("owner-rejoined"), "real-owner-restored", 40.0)
		if scenario == "owner_rejoin_before_commit": release_held("gift_result")
		await wait_for(func(): return transaction_state().host_ledger.values().any(func(entry): return entry.get("status") == "accepted") and subject().lv(Elem.WATER) == 1, "recovered-owner-commit")
		announce("owner-result-release")
		await wait_for(func(): return inbox.has("single-resolved"), "single-donor-settled")
		await wait_for(func(): return transaction_state().host_ledger.values().all(func(entry): return entry.settled), "recovery-host-settled")
		ok("I-04", subject().lv(Elem.WATER) == 1, "owner 재접속 전후 host의 최종 속성 증가 정확히 한 번")
		trace("owner-recovery-final", {"transaction":transaction_state(), "tower":subject().mp_state()})
		await snap("owner-recovery-coordinator")
		announce("finish")
		await create_timer(0.35).timeout
	elif role == "peer_a":
		await wait_for(func(): return inbox.has("disconnect-owner"), "owner-cut-trigger")
		ok("I-04", subject().lv(Elem.WATER) == 1, "단절 전에 실제 owner가 속성 적용")
		trace("owner-before-cut", {"tower":subject().mp_state(), "transaction":transaction_state()})
		main.mp._fail("로컬 gift owner 적용 후 연결 중단")
		await wait_for(func(): return main.mp.my_id > 1 and not main.mp.connected_ids().is_empty() and main.mp_rejoin_until == 0, "actual-owner-rejoin", 35.0)
		ok("I-04", str(transaction_state().round_id) == initial_round, "owner 재접속도 같은 판 유지")
		announce("owner-rejoined")
		await wait_for(func(): return inbox.has("owner-result-release") and subject() != null and subject().lv(Elem.WATER) == 1, "owner-final-one-application")
		await snap("owner-recovered")
		await wait_for(func(): return inbox.has("finish"), "owner-recovery-finished")
	else:
		hold_types.append("gift_ack")
		await mouse_click(card_center(0))
		await wait_for(func(): return inbox.has("single-gift"), "single-donor-trigger")
		await mouse_click(world(subject().position))
		await wait_for(pending_on, "single-donor-pending")
		local_request = transaction_state().pending.request.duplicate(true)
		await wait_for(func(): return inbox.has("owner-result-release"), "owner-rejoin-settlement-trigger", 50.0)
		release_held("gift_ack")
		await wait_for(func(): return not pending_on(), "single-donor-accepted-after-recovery")
		ok("I-04", main.picks_left == int(fixture_before.picks) - 1 and main.bank_picks.size() == fixture_before.bank.size() - 1, "owner 재접속 뒤 donor도 정확히 한 선택만 소비")
		var after := choice_state()
		var duplicate := local_request.duplicate(true)
		duplicate["t"] = "gift_request"
		duplicate["v"] = 1
		duplicate["to"] = 1
		main.mp.send(duplicate, 1)
		await create_timer(0.3).timeout
		ok("I-04", choices_equal(after, choice_state()), "owner 재접속 후 동일 token retry도 추가 소비 없음")
		announce("single-resolved")
		await wait_for(func(): return inbox.has("finish"), "single-donor-finished")

## 실제 판 종료→방 연결 보존→새 start를 실행한다. VirtualInput 호스트의 scene mount만 수동으로 다시 한다.
func restart_and_replay() -> void:
	var stale_request: Dictionary = inbox["original-" + role].value.duplicate(true) if role != "host" else {}
	var stale_ack: Dictionary = inbox["resolved-peer_a"].value.ack.duplicate(true) if role == "host" else {}
	if role == "host":
		await key(KEY_P)
		await key(KEY_E)
		await key(KEY_E)
	await wait_for(func(): return main.phase == main.Phase.GAMEOVER, "actual-round-ended")
	main.run_flow_system._mp_keep_room()
	stop_qa_audio()
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	await settle()
	main.set_meta("gift_qa_receive", _receive_gate)
	if not main.mp.packet.is_connected(_qa_packet): main.mp.packet.connect(_qa_packet)
	service = main.multiplayer_system.gifts()
	main.auto_start = false
	announce("in-lobby-" + role)
	if role == "host":
		await wait_for(func(): return inbox.has("in-lobby-peer_a") and inbox.has("in-lobby-peer_b") and main.mp.playing_ids().is_empty(), "actual-previous-round-left")
		main.lobby_system._mp_start()
	await wait_for(func(): return main.mp_mode == "coop" and str(transaction_state().round_id) != initial_round and str(transaction_state().round_id) != "", "actual-new-round-id")
	await settle()
	var before := choice_state()
	var tower_count: int = main.towers.get_child_count()
	announce("new-round-" + role)
	if role == "host":
		await wait_for(func(): return inbox.has("new-round-peer_a") and inbox.has("new-round-peer_b"), "new-round-all-participants")
		main.mp.send(stale_ack, int(participants["peer_a"]))
		announce("send-old-requests")
	else:
		await wait_for(func(): return inbox.has("send-old-requests"), "old-round-replay-trigger")
		main.mp.send(stale_request, 1)
	await create_timer(0.4).timeout
	ok("I-04", choices_equal(before, choice_state()) and main.towers.get_child_count() == tower_count and not pending_on(), "옛 판 request·늦은 ACK가 새 판 선택·오브젝트를 바꾸지 않음")
	trace("new-round-after-stale-packets", {"round":transaction_state().round_id, "choice":choice_state(), "transaction":transaction_state()})
	announce("stale-checked-" + role)
	if role == "host":
		await wait_for(func(): return inbox.has("stale-checked-peer_a") and inbox.has("stale-checked-peer_b"), "old-round-guards-all-checked")

func _finish(code: int) -> void:
	if finishing: return
	finishing = true
	if not output.is_empty():
		FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"role":role, "scenario":scenario, "failures":fails, "ui_messages":ui_errors, "results":results}, "\t"))
		FileAccess.open(output.path_join("packets.bin"), FileAccess.WRITE).store_buffer(var_to_bytes(packet_trace))
		if service != null and service.has_method("debug_state"):
			FileAccess.open(output.path_join("transaction-state.json"), FileAccess.WRITE).store_string(JSON.stringify(transaction_state(), "\t"))
	print("GIFT ", scenario, " ", role, " failures=", fails, " ui=", ui_errors, " exit=", code)
	await finish_qa_transport(shared, "shutdown", ["host", "peer_a", "peer_b"])
	quit(code)
