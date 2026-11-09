extends SceneTree
## 동결된 중간 구현에 대한 서비스 수준 반례. 실제 WebRTC나 3인 UI 검사가 아니다.
class CaptureGift:
	extends BinduGiftTransactions
	var sent: Array = []
	func _send(message: Dictionary, to: int) -> void:
		sent.append({"to":to, "message":message.duplicate(true)})

class CaptureTransport:
	extends Mp
	var sent: Array = []
	func send(message: Dictionary, _to := 0, _reliable := true) -> void:
		sent.append(message.duplicate(true))

var game: BinduSession
var gift: CaptureGift
var card := {"type":"elem", "e":Elem.FIRE, "lv":1}

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 10
	Meta.guide_on = false
	Meta.pause_on_focus_loss = false
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.progression_system._hide_title()
	var mode := OS.get_cmdline_user_args()[0]
	setup(2)
	match mode:
		"terminal-rejoin": terminal_rejoin()
		"settled-retry": settled_retry()
		"old-ack": old_ack()
		"owner-before-commit": owner_before_commit()
		"ordinary-choice": ordinary_choice()
		"loser-result": loser_result()
		"disconnect-retire": disconnect_retire()
		"context-only": context_only()
		"settled-replay": settled_replay()
		"caps-fence": caps_fence()
		"fence-pending": fence_pending()
		"fence-auto": fence_auto()
		"moving-context": moving_context()
		"legacy-tw": legacy_tw()
		_: quit(2)

func setup(id: int) -> void:
	game.mp_mode = "coop"
	game.mp.my_id = id
	game.mp.started = true
	game.mp.in_game = {1:true, 2:true, 3:true}
	game.wave = 5
	game.phase = BinduSession.Phase.PLACE
	game.picks_left = 2
	game.picked = card.duplicate(true)
	game.offer = [card.duplicate(true)]
	game.bank_picks = []
	game.run_log = []
	game.lobby_system.mp_req_got_w = -999
	gift = CaptureGift.new(game)
	game.multiplayer_system._gift_transactions = gift
	gift.closed = false
	gift.round_id = "review-round"
	gift.protocol_version = 1
	gift.members = [1, 2, 3]
	gift.caps = {1:1, 2:1, 3:1}
	gift.owner_epochs = {1:1, 2:1, 3:1}
	gift.owner_revisions = {1:0, 2:0, 3:0}
	gift.generation = 10

func request() -> Dictionary:
	var result := {"v":1, "round_id":gift.round_id, "rest_id":5, "gift_id":"review:A", "choice_id":"10:0:1", "donor_id":2,
		"owner_id":3, "nid":300001, "request_id":1, "e":Elem.FIRE, "lv":1, "context":gift._context()}
	result["fp"] = gift._fingerprint(result)
	return result

func receipt(req: Dictionary) -> Dictionary:
	var result := gift._thin(req)
	result.merge({"status":"accepted", "reason":"", "applied_revision":1})
	return result

func entry(req: Dictionary, settled := false) -> Dictionary:
	return {"request":req.duplicate(true), "result":receipt(req), "status":"accepted", "settled":settled}

func snapshot(entries: Dictionary, context: Dictionary) -> Dictionary:
	return {"round_id":gift.round_id, "epochs":gift.owner_epochs.duplicate(), "revisions":gift.owner_revisions.duplicate(),
		"caps":gift.caps.duplicate(), "receipts":{}, "entries":entries, "context":{"rest_id":5, "context":context}, "fence":{}}

func terminal_rejoin() -> void:
	var req := request()
	var original: Dictionary = req.context.duplicate(true)
	game.phase = BinduSession.Phase.CHOOSE
	game.picks_left = 1
	game.offer = [{"type":"mod", "id":"rapid"}]
	gift.generation = 11
	var after := gift._context()
	var done := receipt(req)
	done["after_context"] = after.duplicate(true)
	done["after_state"] = gift.current_state()
	done["awaiting_settled"] = true
	gift.terminal[gift._key(req)] = done
	gift.restore_rejoin(snapshot({gift._key(req):entry(req)}, original))
	var actual := gift._context()
	print("PROBE terminal-rejoin expected_picks=1 actual_picks=", game.picks_left, " expected_generation=11 actual_generation=", gift.generation, " sent_settled=", gift.sent.size())
	print("CONTEXT ", JSON.stringify({"expected":after, "actual":actual}))
	quit(1 if actual != after else 0)

func settled_retry() -> void:
	setup(1)
	game.phase = BinduSession.Phase.READY
	var req := request()
	gift.host_ledger[gift._key(req)] = entry(req)
	gift.context_at = Time.get_ticks_msec() + 1000000
	gift.hello_at = Time.get_ticks_msec() + 1000000
	for i in 100:
		gift.tick(1.0)
	var acknowledgements := gift.sent.filter(func(packet): return packet.message.get("t") == "gift_ack").size()
	var can_start := gift.prepare_wave(false)
	print("PROBE settled-retry callbacks=100 ack_retries=", acknowledgements, " can_start=", can_start, " ledger_settled=", gift.host_ledger[gift._key(req)].settled)
	quit(1 if acknowledgements == 0 and not can_start else 0)

func old_ack() -> void:
	var req := request()
	var done := receipt(req)
	done["after_context"] = gift._context()
	gift.terminal[gift._key(req)] = done
	game.wave = 6
	game.phase = BinduSession.Phase.WAVE
	gift.wave_started()
	var ack := receipt(req)
	ack["t"] = "gift_ack"
	print("PROBE old-ack after_context_retained=", gift.terminal[gift._key(req)].has("after_context"))
	gift.receive(1, ack)
	print("PROBE old-ack returned")
	quit(0)

func make_tower(owner: int) -> Tower:
	game.picked = card.duplicate(true)
	game.interaction_system._place_tower(Vector2(640, 360), Vector2.RIGHT)
	var tower: Tower = game.towers.get_child(game.towers.get_child_count() - 1)
	tower.owner_id = owner
	tower.net_id = owner * 100000 + 1
	tower.req_e = Elem.FIRE
	tower.set_meta("gift_request_id", 1)
	return tower

func owner_before_commit() -> void:
	setup(1)
	var tower := make_tower(3)
	var original := tower.mp_state()
	var before := int(tower.elements.get(Elem.FIRE, 0))
	var req := request()
	gift.host_ledger[gift._key(req)] = {"request":req.duplicate(true), "result":{}, "status":"pending", "settled":false}
	tower.add(Elem.FIRE, 1)
	tower.req_e = -1
	var newer := tower.mp_state()
	newer["rqid"] = 2
	tower.mp_apply(original)
	var accepted_tw := gift.ingest_state(3, {"gift_round":gift.round_id, "owner_epoch":1, "owner_revision":2, "list":[newer]})
	var re := gift.rejoin_state(3)
	var host_missing_receipt: bool = re.receipts.is_empty()
	game.mp.my_id = 3
	var owner := CaptureGift.new(game)
	game.multiplayer_system._gift_transactions = owner
	owner.closed = false
	owner.round_id = gift.round_id
	owner.protocol_version = 1
	owner.members = [1, 2, 3]
	owner.restore_rejoin(re)
	req["owner_epoch"] = 1
	req["t"] = "gift_apply"
	owner.receive(1, req)
	var result: Dictionary = owner.sent[-1].message if not owner.sent.is_empty() else {}
	var after := int(tower.elements.get(Elem.FIRE, 0))
	print("PROBE owner-before-commit accepted_tw=", accepted_tw, " host_receipt_empty=", host_missing_receipt, " level_before=", before, " level_after=", after, " retry_status=", result.get("status", "missing"))
	quit(1 if accepted_tw and host_missing_receipt and after > before and result.get("status") == "rejected" else 0)

func ordinary_choice() -> void:
	setup(1)
	var tower := make_tower(2)
	var original := tower.mp_state()
	game.phase = BinduSession.Phase.CHOOSE
	game.picks_left = 1
	game.picked = {}
	var old_context := gift._context()
	var req := request()
	gift.host_ledger[gift._key(req)] = entry(req, true)
	gift.donor_contexts[2] = {"rest_id":5, "context":old_context.duplicate(true)}
	var before := int(tower.elements.get(Elem.FIRE, 0))
	tower.add(Elem.FIRE, 1)
	# 실제 일반 카드 완료와 실제 current_state를 사용한다. TW 필드를 임의로 만들지 않는다.
	game.mp.my_id = 2
	var sender := CaptureGift.new(game)
	sender.closed = false
	sender.round_id = gift.round_id
	sender.protocol_version = 1
	sender.members = [1, 2, 3]
	sender.caps = {1:1, 2:1, 3:1}
	sender.owner_epochs = {1:1, 2:1, 3:1}
	game.multiplayer_system._gift_transactions = sender
	game.cards_system._after_place(card)
	var newer := sender.current_state()
	game.mp.my_id = 1
	game.multiplayer_system._gift_transactions = gift
	tower.mp_apply(original)
	var accepted_tw := gift.ingest_state(2, newer)
	var re := gift.rejoin_state(2)
	game.mp.my_id = 2
	var donor := CaptureGift.new(game)
	game.multiplayer_system._gift_transactions = donor
	donor.closed = false
	donor.round_id = gift.round_id
	donor.protocol_version = 1
	donor.members = [1, 2, 3]
	donor.restore_rejoin(re)
	var after := int(tower.elements.get(Elem.FIRE, 0))
	print("PROBE ordinary-choice accepted_tw=", accepted_tw, " applied_level_before=", before, " applied_level_after=", after, " restored_picks=", game.picks_left, " restored_offer=", JSON.stringify(game.offer))
	quit(1 if not accepted_tw or after <= before or game.picks_left != 0 else 0)

func loser_result() -> void:
	setup(3)
	var tower := make_tower(3)
	var original := tower.mp_state()
	var before := int(tower.elements.get(Elem.FIRE, 0))
	var req_a := request()
	var req_b := req_a.duplicate(true)
	req_b.merge({"donor_id":1, "gift_id":"review:B", "choice_id":"B"}, true)
	req_b["fp"] = gift._fingerprint(req_b)
	var apply_a := req_a.duplicate(true)
	apply_a.merge({"t":"gift_apply", "owner_epoch":1}, true)
	var apply_b := req_b.duplicate(true)
	apply_b.merge({"t":"gift_apply", "owner_epoch":1}, true)
	gift.receive(1, apply_a)
	gift.receive(1, apply_b)
	var owner_results := gift.sent.filter(func(packet): return packet.message.get("t") == "gift_result")
	var loser: Dictionary = {}
	for packet in owner_results:
		if packet.message.get("gift_id") == "review:B": loser = packet.message.duplicate(true)
	if loser.is_empty():
		print("PROBE loser-result queued_without_publish=true owner_messages=", owner_results.size())
		quit(0)
		return
	var round_name := gift.round_id
	game.mp.my_id = 1
	tower.mp_apply(original)
	tower.set_meta("gift_request_id", 1)
	var host := CaptureGift.new(game)
	game.multiplayer_system._gift_transactions = host
	host.closed = false
	host.round_id = round_name
	host.protocol_version = 1
	host.members = [1, 2, 3]
	host.caps = {1:1, 2:1, 3:1}
	host.owner_epochs = {1:1, 2:1, 3:1}
	host.owner_revisions = {1:0, 2:0, 3:0}
	host.host_ledger[host._key(req_a)] = {"request":req_a.duplicate(true), "result":{}, "status":"pending", "settled":false}
	host.host_ledger[host._key(req_b)] = {"request":req_b.duplicate(true), "result":{}, "status":"pending", "settled":false}
	# 정상 생성된 winner result만 전달하지 않는다. loser result는 원문 그대로 host handler로 보낸다.
	host.receive(3, loser)
	var leaked := int(tower.elements.get(Elem.FIRE, 0))
	var re := host.rejoin_state(3)
	var missing_winner: bool = host.host_ledger[host._key(req_a)].result.is_empty()
	game.mp.my_id = 3
	var rejoined := CaptureGift.new(game)
	game.multiplayer_system._gift_transactions = rejoined
	rejoined.closed = false
	rejoined.round_id = round_name
	rejoined.protocol_version = 1
	rejoined.members = [1, 2, 3]
	rejoined.restore_rejoin(re)
	rejoined.receive(1, apply_a)
	var last: Dictionary = rejoined.sent[-1].message if not rejoined.sent.is_empty() else {}
	print("PROBE loser-result winner_receipt_missing=", missing_winner, " loser_status=", loser.get("status"), " level_before=", before, " host_level_after_loser=", leaked, " winner_retry_status=", last.get("status", "missing"))
	quit(1 if missing_winner and leaked > before and last.get("status") == "rejected" else 0)

func disconnect_retire() -> void:
	setup(1)
	game.mp_others = {2:{"name":"donor", "gone":false}, 3:{"name":"owner", "gone":false}}
	var initial := gift._retired(2)
	game.mp._drop(2)
	var disconnected := gift._retired(2)
	game.multiplayer_system._mp_peer_up(2)
	var rejoined := gift._retired(2)
	print("PROBE disconnect-retire initially=", initial, " after_transport_drop=", disconnected, " after_peer_up=", rejoined, " in_game=", game.mp.in_game.has(2), " gone=", game.mp_others[2].gone)
	quit(1 if not initial and rejoined else 0)

func context_only() -> void:
	setup(2)
	make_tower(2)
	game.phase = BinduSession.Phase.CHOOSE
	game.picked = {}
	game.rerolls_left = 2
	var before := gift.current_state()
	game.cards_system._on_reroll()
	var after := gift.current_state()
	var context_present: bool = after.get("choice_context") is Dictionary
	print("PROBE context-only same_towers=", before.list == after.list, " revision_before=", before.owner_revision, " revision_after=", after.owner_revision, " context_present=", context_present, " rerolls=", game.rerolls_left)
	quit(1 if before.list != after.list or after.owner_revision <= before.owner_revision or not context_present or game.rerolls_left != 1 else 0)

func settled_replay() -> void:
	setup(1)
	var req := request()
	gift.host_ledger[gift._key(req)] = entry(req, true)
	var old := gift._context()
	game.picks_left = 0
	game.phase = BinduSession.Phase.READY
	gift.generation = 15
	var latest := gift._context()
	gift.donor_contexts[2] = {"rest_id":5, "revision":3, "context":latest.duplicate(true)}
	var packet := gift._thin(req)
	packet.merge({"t":"gift_settled", "context":old, "donor_state":{"gift_round":gift.round_id, "owner_epoch":1, "owner_revision":1, "list":[], "choice_context":old}}, true)
	gift.receive(2, packet)
	var kept: bool = gift.donor_contexts[2].context == latest
	var complete_count := gift.sent.filter(func(message): return message.message.get("t") == "gift_complete").size()
	print("PROBE settled-replay latest_context_kept=", kept, " complete_messages=", complete_count, " generation=", gift.donor_contexts[2].context.generation)
	quit(1 if not kept or complete_count != 1 else 0)

func caps_fence() -> void:
	setup(1)
	game.phase = BinduSession.Phase.READY
	var hello := {"t":"gift_hello", "v":1, "round_id":gift.round_id, "rest_id":5, "owner_epoch":1}
	gift.receive(2, hello)
	gift.peer_rejoined(3)
	var can_start := gift.prepare_wave(false)
	var armed: bool = gift.get("protocol_armed") == true
	var waiting: Array = gift.host_fence.get("waiting", [])
	print("PROBE caps-fence armed=", armed, " caps3=", gift.caps.get(3), " can_start=", can_start, " waiting=", JSON.stringify(waiting))
	quit(1 if not armed or can_start or not 3 in waiting else 0)

func fence_packet() -> Dictionary:
	return {"t":"gift_barrier", "v":1, "round_id":gift.round_id, "rest_id":5, "owner_epoch":1, "fence_id":"review:F", "force":true}

func fence_pending() -> void:
	setup(2)
	var req := request()
	gift.pending = {"request":req.duplicate(true), "context":req.context.duplicate(true)}
	gift.receive(1, fence_packet())
	var ready := gift.sent.filter(func(packet): return packet.message.get("t") == "gift_barrier_ready").size()
	print("PROBE fence-pending picks=", game.picks_left, " phase=", game.phase, " log_count=", game.run_log.size(), " barrier_ready=", ready)
	quit(1 if game.picks_left != 2 or game.phase != BinduSession.Phase.PLACE or not game.run_log.is_empty() or ready != 0 else 0)

func fence_auto() -> void:
	setup(2)
	make_tower(2)
	game.phase = BinduSession.Phase.CHOOSE
	game.picked = {}
	seed(42)
	gift.receive(1, fence_packet())
	var ready := gift.sent.filter(func(packet): return packet.message.get("t") == "gift_barrier_ready").size()
	var new_gifts := gift.sent.filter(func(packet): return packet.message.get("t") == "gift_request").size()
	print("PROBE fence-auto picks=", game.picks_left, " phase=", game.phase, " applied_log_count=", game.run_log.size(), " barrier_ready=", ready, " new_gift_requests=", new_gifts)
	quit(1 if game.picks_left != 0 or game.phase != BinduSession.Phase.READY or game.run_log.size() != 2 or ready != 1 or new_gifts != 0 else 0)

func moving_context() -> void:
	setup(2)
	var tower := make_tower(2)
	game.picks_left = 1
	game.cards_system._after_place(card)
	game.interaction_system._start_move(tower)
	var captured := gift._context()
	game.interaction_system.moving = null  # rejoin에서 원래 편집 Node·gesture는 버려진다.
	gift._restore_context(captured)
	var edit_restored_ready: bool = game.phase == BinduSession.Phase.READY and game.picks_left == 0 and not game.card_dock.carrying()
	game.phase = BinduSession.Phase.AIM
	game.picks_left = 1
	game.picked = card.duplicate(true)
	var new_card := gift._context()
	gift._restore_context(new_card)
	var new_card_restored_place: bool = game.phase == BinduSession.Phase.PLACE and game.picks_left == 1 and game.card_dock.carrying()
	print("PROBE moving-context edit_captured_phase=", captured.phase, " edit_restored_ready=", edit_restored_ready, " new_card_restored_place=", new_card_restored_place)
	quit(1 if not edit_restored_ready or not new_card_restored_place else 0)

func legacy_tw() -> void:
	setup(2)
	var tower := make_tower(2)
	var transport := CaptureTransport.new()
	var original_transport := game.mp
	game.mp = transport
	transport.my_id = 2
	transport.started = true
	transport.in_game = {1:true, 2:true, 3:true}
	gift.protocol_version = 0
	game.multiplayer_system.mp_tw_sig = ""
	game.multiplayer_system._mp_send_towers()
	var packet: Dictionary = transport.sent[0] if not transport.sent.is_empty() else {}
	var plain: bool = packet.get("t") == "tw" and packet.has("list") and not packet.has("gift_round")
	var source_position := tower.position
	transport.my_id = 3
	tower.position = Vector2(100, 100)
	game.multiplayer_system._mp_packet(2, packet)
	var received: bool = tower.position.is_equal_approx(source_position)
	game.mp = original_transport
	transport.free()
	print("PROBE legacy-tw plain_publish=", plain, " new_client_receive=", received)
	quit(1 if not plain or not received else 0)
