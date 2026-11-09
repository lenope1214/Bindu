class_name BinduGiftTransactions
extends BinduFeature
## 협동 선물 예약·수신·host commit·정산. Transport reset과 판 종료를 구분한다.
const VERSION := 1
const PACKETS := ["gift_hello", "gift_caps", "gift_request", "gift_apply", "gift_result", "gift_ack", "gift_settled", "gift_barrier", "gift_barrier_ready", "gift_choice", "gift_complete"]
const CONTEXT_FIELDS := ["phase", "offer", "picked", "picks_left", "bank_picks", "bank_rerolls", "bank_perks", "rerolls_left", "bonus_rerolls", "perk_rerolls", "run_log", "perk_mode", "perk_offer", "countdown", "rest_ready", "coin_stage", "coin_next"]
const REST := [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY, BinduSession.Phase.PLACE, BinduSession.Phase.AIM]

var round_id := ""
var protocol_version := 0
var protocol_armed := false
var implementation_ready := true
var pending: Dictionary = {}
var host_ledger: Dictionary = {}
var owner_ledger: Dictionary = {}
var terminal: Dictionary = {}
var caps: Dictionary = {}
var owner_revisions: Dictionary = {}
var owner_epochs: Dictionary = {}
var owner_states: Dictionary = {}
var owner_contexts: Dictionary = {}
var ack_retry_at := 0
var donor_contexts: Dictionary = {}
var retired_members: Dictionary = {}
var members: Array = []
var generation := 0
var sequence := 0
var nonce := ""
var settling_local := false
var local_fence := ""
var host_fence: Dictionary = {}
var closed := true
var host_force := false
var retry_at := 0
var retry_delay := 1000
var hello_at := 0
var context_at := 0
var context_signature := ""
var request_versions: Dictionary = {}
var received_rest := -1
var owner_retry: Dictionary = {}
var sent_states: Dictionary = {}
var authorized_wave := ""
var fence_sent := false
var fence_retry_at := 0

func start_round(message: Dictionary) -> void:
	var next_round := str(message.get("gift_round", ""))
	if not closed and round_id == next_round:
		return
	close_round()
	round_id = next_round
	protocol_version = int(message.get("gift_v", 0))
	closed = false
	protocol_armed = false
	members = (message.get("ids", []) as Array).map(func(id): return int(id))
	caps.clear()
	owner_epochs.clear()
	owner_revisions.clear()
	owner_states.clear()
	owner_contexts.clear()
	donor_contexts.clear()
	retired_members.clear()
	request_versions.clear()
	owner_retry.clear()
	sent_states.clear()
	generation = 0
	received_rest = -1
	nonce = Crypto.new().generate_random_bytes(12).hex_encode()
	sequence = 0
	for id in members:
		caps[id] = VERSION if id == session.mp.my_id and protocol_version == VERSION else 0
		owner_epochs[id] = 1
		owner_revisions[id] = 0
	hello_at = 0
	context_at = 0
	context_signature = ""

func _send(message: Dictionary, to: int) -> void:
	var packet := message.duplicate(true)
	if to == session.mp.my_id:
		receive(session.mp.my_id, packet)
		return
	# Mp.send(..., 1)는 자체적으로 to=1을 싣지 않는다. host 전용 메시지는 relay 전에 막는다.
	packet["to"] = to
	session.mp.send(packet, to)

func _base(kind: String) -> Dictionary:
	return {"t":kind, "v":VERSION, "round_id":round_id, "rest_id":session.wave}

func _same_round(message: Dictionary) -> bool:
	return not closed and protocol_version == VERSION and message.get("v") is int and message.v == VERSION and str(message.get("round_id", "")) == round_id

func _context() -> Dictionary:
	var state := {"generation":generation}
	for key in CONTEXT_FIELDS:
		var value: Variant = session.get(key)
		state[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	# 방향 편집 AIM은 새 카드 설치 AIM과 다르다. 재접속은 편집 전 카드 단계로 돌아간다.
	if session.interaction_system.moving != null:
		state["phase"] = session.interaction_system.move_return
	return state

func _restore_context(state: Dictionary) -> void:
	for key in CONTEXT_FIELDS:
		if key == "phase": continue
		if state.has(key):
			var value: Variant = state[key]
			session.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
	generation = int(state.get("generation", generation))
	session.card_dock.clear_gesture()
	session.card_dock.close_inspector()
	session.phase = int(state.get("phase", BinduSession.Phase.CHOOSE))
	if session.phase in [BinduSession.Phase.AIM, BinduSession.Phase.MOVE]:
		session.phase = BinduSession.Phase.PLACE
	if session.perk_mode:
		session.phase = BinduSession.Phase.CHOOSE
		session.perks_system._show_perks()
	elif session.phase == BinduSession.Phase.CHOOSE:
		session.cards_system._show_offer()
		session.cards_system._set_cards_hidden(false)
	elif session.phase == BinduSession.Phase.READY:
		session.cards_system._enter_ready()
	else:
		session.phase = BinduSession.Phase.PLACE
		session.choice_box.hide()
		session.reroll_btn.hide()
	session.card_dock.tick()

func _fingerprint(request: Dictionary) -> String:
	var values: Array = []
	for key in ["v", "round_id", "rest_id", "gift_id", "choice_id", "donor_id", "owner_id", "nid", "request_id", "e", "lv"]:
		values.append(request.get(key))
	return var_to_bytes(values).hex_encode().sha256_text()

func _key(request: Dictionary) -> String:
	return "%d:%s" % [int(request.get("donor_id", 0)), str(request.get("gift_id", ""))]

func next_request(tower: Tower) -> void:
	var id := tower.net_id
	var revision := maxi(int(request_versions.get(id, 0)), int(tower.get_meta("gift_request_id", 0))) + 1
	request_versions[id] = revision
	tower.set_meta("gift_request_id", revision)
	session.multiplayer_system.mp_tw_sig = ""

func decorate_towers(list: Array) -> Array:
	var result := list.duplicate(true)
	for item in result:
		for tower in session.multiplayer_system._my_towers():
			if tower.net_id == int(item.get("nid", 0)):
				item["rqid"] = int(tower.get_meta("gift_request_id", 0))
				break
	return result

func current_state() -> Dictionary:
	var list: Array = session.multiplayer_system._my_towers().map(func(tower): return tower.mp_state())
	list = decorate_towers(list)
	var id: int = session.mp.my_id
	var context := _context()
	var signature := var_to_str([list, context])
	if str(sent_states.get(id, "")) != signature:
		owner_revisions[id] = int(owner_revisions.get(id, 0)) + 1
		sent_states[id] = signature
	owner_states[id] = list.duplicate(true)
	owner_contexts[id] = context.duplicate(true)
	var state := {"gift_round":round_id, "owner_revision":int(owner_revisions.get(id, 0)), "owner_epoch":int(owner_epochs.get(id, 1)), "list":list, "choice_context":context}
	if session.mp.is_host(): _remember_context(id, state)
	return state

func awaiting_settlement() -> bool:
	return terminal.values().any(func(result): return result.get("awaiting_settled", false))

func _uncommitted_owner_key() -> String:
	for key in owner_retry:
		if owner_ledger.has(key) and owner_ledger[key].get("status") == "accepted": return str(key)
	return ""

func can_publish_state() -> bool:
	# 미확정 owner 적용은 host receipt와 함께만 공개한다.
	return owner_retry.is_empty()

func _remember_context(id: int, state: Dictionary) -> void:
	if not state.get("choice_context") is Dictionary: return
	if not host_ledger.values().any(func(entry): return int(entry.request.donor_id) == id and int(entry.request.rest_id) == session.wave): return
	var previous: Dictionary = donor_contexts.get(id, {})
	if int(state.get("owner_revision", -1)) < int(previous.get("revision", -1)): return
	donor_contexts[id] = {"rest_id":session.wave, "revision":state.owner_revision, "context":state.choice_context.duplicate(true)}

func blocks_local_choice() -> bool:
	return session.mp_mode == "coop" and not settling_local and (not pending.is_empty() or awaiting_settlement() or not owner_retry.is_empty() or local_fence != "")

func pending_notice() -> String:
	if not pending.is_empty():
		return "속성 전달 확인 중 · 결과가 올 때까지 카드를 보관해요"
	if awaiting_settlement() or not owner_retry.is_empty():
		return "전달 결과를 저장 중이에요 · 잠시 후 이어서 고를 수 있어요"
	if local_fence != "":
		return "친구들의 전달 결과와 다음 웨이브 준비를 확인 중이에요"
	if session.mp_mode == "coop" and session.mp.is_host() and host_ledger.values().any(func(entry): return not entry.get("settled", false)):
		return "친구의 속성 전달 결과를 확인 중이에요"
	return ""

func note_new_offer() -> bool:
	if blocks_local_choice():
		return false
	generation += 1
	return true

func before_wave() -> bool:
	if session.mp_mode != "coop":
		return true
	if not pending.is_empty() or awaiting_settlement() or not owner_retry.is_empty():
		return false
	if session.mp.is_host():
		for entry in host_ledger.values():
			if not entry.get("settled", false):
				return false
	if not session.mp_wave_go:
		return local_fence == ""
	if session.mp.is_host():
		return host_fence.is_empty() or (host_fence.waiting.is_empty() and int(host_fence.rest_id) == session.wave)
	return local_fence == "" and (not protocol_armed or authorized_wave != "")

func close_round() -> void:
	closed = true
	pending.clear()
	host_ledger.clear()
	owner_ledger.clear()
	terminal.clear()
	local_fence = ""
	host_fence.clear()
	authorized_wave = ""

func offer_status(tower: Tower, card: Dictionary) -> Dictionary:
	if not is_instance_valid(tower):
		return {"ok":false, "reason":"오브젝트를 선택하세요"}
	if blocks_local_choice():
		return {"ok":false, "reason":pending_notice()}
	if session.multiplayer_system._mine(tower):
		return {"ok":tower.can_take(card), "reason":tower.refuse_text(card) if not tower.can_take(card) else ""}
	if session.mp_mode != "coop":
		return {"ok":false, "reason":"소유자만 편집할 수 있어요"}
	if not implementation_ready or not supported_all():
		return {"ok":false, "reason":"친구의 전달 지원을 확인 중이에요. 오래 걸리면 모두 업데이트한 뒤 새 판을 시작하세요"}
	if card.get("type", "") != "elem" or tower.req_e < 0 or int(card.get("e", -1)) != tower.req_e:
		return {"ok":false, "reason":"친구가 요청한 속성 카드만 전달할 수 있어요"}
	if int(tower.get_meta("gift_request_id", 0)) <= 0:
		return {"ok":false, "reason":"이전 요청은 사용할 수 없어요. 친구가 다시 요청해야 해요"}
	if not tower.can_take(card):
		return {"ok":false, "reason":tower.refuse_text(card)}
	return {"ok":true, "reason":""}

func supported_all() -> bool:
	if closed or protocol_version != VERSION or members.is_empty():
		return false
	for id in members:
		if _retired(int(id)): continue
		if int(caps.get(int(id), 0)) != VERSION:
			return false
	protocol_armed = true
	return true

func begin_gift(tower: Tower) -> bool:
	var status := offer_status(tower, session.picked)
	if not status.ok or session.phase != BinduSession.Phase.PLACE or session.picks_left <= 0:
		session.hud_system._show_toast(str(status.reason))
		return false
	sequence += 1
	var request := _base("gift_request")
	request.merge({"gift_id":nonce + ":" + str(sequence), "choice_id":"%d:%d:%d" % [generation, session.offer.find(session.picked), sequence],
		"donor_id":session.mp.my_id, "owner_id":tower.owner_id, "nid":tower.net_id,
		"request_id":int(tower.get_meta("gift_request_id", 0)), "e":int(session.picked.e), "lv":int(session.picked.lv),
		"context":_context(), "donor_state":current_state()})
	request["fp"] = _fingerprint(request)
	pending = {"request":request.duplicate(true), "context":request.context.duplicate(true)}
	retry_delay = 1000
	retry_at = Time.get_ticks_msec() + retry_delay
	session.card_dock.clear_gesture()
	session.hud_system._show_toast(pending_notice())
	_send(request, 1)
	return true

func receive(from: int, message: Dictionary) -> bool:
	var kind := str(message.get("t", ""))
	if not kind in PACKETS:
		return false
	if not _same_round(message):
		return true
	match kind:
		"gift_hello": _hello(from, message)
		"gift_caps": _caps(from, message)
		"gift_request": _request(from, message)
		"gift_apply": _apply(from, message)
		"gift_result": _result(from, message)
		"gift_ack": _ack(from, message)
		"gift_settled": _settled(from, message)
		"gift_complete": _complete(from, message)
		"gift_choice": _choice(from, message)
		"gift_barrier", "gift_barrier_ready": _barrier(from, message)
	return true

func tick(_delta: float) -> void:
	if closed or session.mp_mode != "coop" or protocol_version != VERSION:
		return
	var now := Time.get_ticks_msec()
	if now >= hello_at and not supported_all():
		hello_at = now + 1000
		var hello := _base("gift_hello")
		hello["owner_epoch"] = int(owner_epochs.get(session.mp.my_id, 1))
		_send(hello, 1)
	if not pending.is_empty() and now >= retry_at:
		retry_at = now + retry_delay
		retry_delay = mini(5000, retry_delay * 2)
		_send(pending.request, 1)
	for result in terminal.values():
		if result.get("awaiting_settled", false) and now >= int(result.get("settlement_retry_at", 0)):
			result["settlement_retry_at"] = now + 1000
			_send_settled(result)
	for key in owner_retry.keys():
		if now >= int(owner_retry[key]):
			owner_retry[key] = now + 1500
			_send_result(str(key))
	if now >= context_at and not settling_local and pending.is_empty() and can_publish_state() and session.phase in REST:
		context_at = now + 250
		var context := _context()
		var state := current_state()
		var signature := var_to_str([context, state])
		if signature != context_signature:
			context_signature = signature
			var update := _base("gift_choice")
			update.merge({"context":context, "donor_state":state})
			_send(update, 1)
	if session.mp.is_host():
		if now >= ack_retry_at:
			ack_retry_at = now + 1000
			for entry in host_ledger.values():
				if entry.settled: continue
				if not entry.result.is_empty(): _send_ack(entry)
				else: _send_apply(entry.request)
		_retire()
	_try_fence_ready()

func _hello(from: int, message: Dictionary) -> void:
	if not session.mp.is_host() or not from in members or _retired(from) or int(message.get("owner_epoch", -1)) != int(owner_epochs.get(from, 1)):
		return
	caps[from] = VERSION
	supported_all()
	var packet := _base("gift_caps")
	packet.merge({"caps":caps.duplicate(), "epochs":owner_epochs.duplicate(), "retired":retired_members.duplicate(), "armed":protocol_armed})
	_send(packet, 0)

func _caps(from: int, message: Dictionary) -> void:
	if from != 1 or not message.get("caps") is Dictionary or not message.get("epochs") is Dictionary:
		return
	caps = message.caps.duplicate()
	owner_epochs = message.epochs.duplicate()
	if message.get("retired") is Dictionary: retired_members.merge(message.retired)
	protocol_armed = protocol_armed or message.get("armed", false) == true
	supported_all()

func _valid_request(request: Dictionary) -> bool:
	for key in ["rest_id", "donor_id", "owner_id", "nid", "request_id", "e", "lv"]:
		if not request.get(key) is int:
			return false
	for key in ["gift_id", "choice_id", "fp"]:
		if not request.get(key) is String or str(request[key]).is_empty() or str(request[key]).length() > 160:
			return false
	return int(request.donor_id) in members and int(request.owner_id) in members and request.donor_id != request.owner_id \
		and int(request.nid) / 100000 == int(request.owner_id) and request.request_id > 0 and request.e in Elem.ALL \
		and request.lv > 0 and request.lv <= 2 and request.fp == _fingerprint(request)

func _thin(request: Dictionary) -> Dictionary:
	var result := {}
	for key in ["v", "round_id", "rest_id", "gift_id", "choice_id", "donor_id", "owner_id", "nid", "request_id", "e", "lv", "fp"]:
		result[key] = request.get(key)
	return result

func _request(from: int, request: Dictionary) -> void:
	if not session.mp.is_host() or not _valid_request(request) or from != request.donor_id:
		return
	var key := _key(request)
	if host_ledger.has(key):
		var entry: Dictionary = host_ledger[key]
		if entry.request.fp != request.fp:
			return
		if not entry.result.is_empty():
			_send_ack(entry)
		else:
			_send_apply(entry.request)
		return
	if not request.get("context") is Dictionary or not request.context.get("offer") is Array or int(request.context.get("picks_left", 0)) <= 0:
		return
	host_ledger[key] = {"request":request.duplicate(true), "result":{}, "status":"pending", "settled":false}
	if request.get("donor_state") is Dictionary:
		ingest_state(from, request.donor_state)
	if request.rest_id != session.wave or not session.phase in REST or not supported_all():
		_reject_host(key, "이 쉬는 시간의 요청을 더는 사용할 수 없어요")
		return
	_send_apply(request)

func _send_apply(request: Dictionary) -> void:
	var packet := request.duplicate(true)
	packet["t"] = "gift_apply"
	packet["owner_epoch"] = int(owner_epochs.get(request.owner_id, 1))
	_send(packet, int(request.owner_id))

func _apply(from: int, request: Dictionary) -> void:
	if from != 1 or not _valid_request(request) or int(request.owner_id) != session.mp.my_id or int(request.get("owner_epoch", -1)) != int(owner_epochs.get(session.mp.my_id, 1)):
		return
	var key := _key(request)
	if owner_ledger.has(key):
		if owner_ledger[key].fp == request.fp:
			_send_result(key)
		return
	# 한 owner의 미확정 적용을 다른 결과 snapshot에 섞지 않는다. 같은 token retry가 다시 온다.
	if _uncommitted_owner_key() != "": return
	var reason := ""
	var tower: Tower = null
	for candidate in session.multiplayer_system._my_towers():
		if candidate.net_id == request.nid:
			tower = candidate
			break
	var card := {"type":"elem", "e":request.e, "lv":request.lv}
	if request.rest_id != session.wave or not session.phase in REST:
		reason = "이번 쉬는 시간이 끝나 들어가지 않았어요"
	elif session.phase == BinduSession.Phase.AIM or session.interaction_system.press_t != null or session.interaction_system.moving != null:
		reason = "친구가 오브젝트를 편집 중이에요. 잠시 후 다시 요청하세요"
	elif tower == null:
		reason = "받을 오브젝트가 없어 들어가지 않았어요"
	elif received_rest == session.wave or session.lobby_system.mp_req_got_w == session.wave:
		reason = "친구가 이번 쉬는 시간의 속성을 이미 받았어요"
	elif tower.req_e != request.e or int(tower.get_meta("gift_request_id", 0)) != request.request_id:
		reason = "친구의 요청이 바뀌었거나 이미 채워졌어요. 카드는 그대로예요"
	elif not tower.can_take(card):
		reason = tower.refuse_text(card)
	var receipt := _thin(request)
	receipt.merge({"status":"rejected" if reason != "" else "accepted", "reason":reason})
	if reason == "":
		tower.add(request.e, request.lv)
		tower.req_e = -1
		next_request(tower)
		received_rest = session.wave
		session.lobby_system.mp_req_got_w = session.wave
		current_state()
	receipt["applied_revision"] = int(owner_revisions.get(session.mp.my_id, 0))
	owner_ledger[key] = receipt
	owner_retry[key] = Time.get_ticks_msec() + 1500
	_send_result(key)

func _send_result(key: String) -> void:
	if not owner_ledger.has(key): return
	var uncommitted := _uncommitted_owner_key()
	if uncommitted != "" and uncommitted != key: return
	var result: Dictionary = owner_ledger[key].duplicate(true)
	var state := current_state()
	result.merge({"t":"gift_result", "owner_revision":state.owner_revision, "owner_epoch":state.owner_epoch, "owner_towers":state.list, "choice_context":state.choice_context})
	_send(result, 1)

func _result(from: int, result: Dictionary) -> void:
	if not session.mp.is_host() or not _valid_request(result): return
	var key := _key(result)
	if not host_ledger.has(key): return
	var entry: Dictionary = host_ledger[key]
	for field in _thin(entry.request):
		if result.get(field) != entry.request.get(field): return
	if from != int(entry.request.owner_id) or int(result.get("owner_epoch", -1)) != int(owner_epochs.get(from, 1)) or not str(result.get("status", "")) in ["accepted", "rejected"]:
		return
	if not entry.result.is_empty():
		_send_ack(entry)
		return
	if not result.get("owner_towers") is Array:
		return
	var state := {"gift_round":round_id, "owner_epoch":result.owner_epoch, "owner_revision":result.owner_revision, "list":result.owner_towers, "choice_context":result.get("choice_context", {})}
	if not ingest_state(from, state):
		# 지난 snapshot으로 덮지 않는다. 같은 receipt를 최신 state revision으로 다시 포장한다.
		_send_apply(entry.request)
		return
	var receipt := _thin(result)
	receipt.merge({"status":str(result.status), "reason":str(result.get("reason", "")), "applied_revision":int(result.get("applied_revision", 0))})
	entry.result = receipt
	entry.status = receipt.status
	_send_ack(entry)

func _reject_host(key: String, reason: String) -> void:
	var entry: Dictionary = host_ledger[key]
	var result := _thin(entry.request)
	result.merge({"status":"rejected", "reason":reason})
	entry.result = result
	entry.status = "rejected"
	_send_ack(entry)

func _send_ack(entry: Dictionary) -> void:
	var ack: Dictionary = entry.result.duplicate(true)
	ack["t"] = "gift_ack"
	_send(ack, int(ack.donor_id))
	if int(ack.owner_id) != int(ack.donor_id):
		_send(ack, int(ack.owner_id))

func _ack(from: int, ack: Dictionary) -> void:
	if from != 1 or not _valid_request(ack) or not str(ack.get("status", "")) in ["accepted", "rejected"]: return
	var key := _key(ack)
	if int(ack.get("owner_id", 0)) == session.mp.my_id and owner_ledger.has(key):
		var receipt: Dictionary = owner_ledger[key]
		var matches := true
		for field in _thin(receipt):
			if ack.get(field) != receipt.get(field): matches = false
		if matches and owner_retry.has(key):
			owner_retry.erase(key)
			if ack.status == "accepted": session.progression_system._check_progress()
	if int(ack.get("donor_id", 0)) != session.mp.my_id: return
	if terminal.has(key):
		if terminal[key].fp == ack.get("fp"): _send_settled(terminal[key])
		return
	if pending.is_empty() or _uncommitted_owner_key() != "": return
	var request: Dictionary = pending.request
	for field in _thin(request):
		if ack.get(field) != request.get(field): return
	if session.wave != int(request.rest_id) or session.phase == BinduSession.Phase.GAMEOVER or _context() != pending.context: return
	var context: Dictionary = pending.context.duplicate(true)
	var result := ack.duplicate(true)
	# 먼저 terminal을 등록해 자기 host의 재진입/중복 ACK도 소비하지 못하게 한다.
	result["awaiting_settled"] = true
	terminal[key] = result
	if ack.status == "accepted":
		settling_local = true
		session.cards_system._after_place(context.picked)
		settling_local = false
	pending = {}
	if ack.status == "rejected": _restore_context(context)
	result["after_context"] = _context()
	result["after_state"] = current_state()
	if ack.status == "rejected":
		session.hud_system._show_toast(str(ack.get("reason", "친구의 요청이 바뀌었어요")) + " · 카드는 보관 중이에요")
	else:
		session.hud_system._show_toast("속성을 전달했어요 · 카드 선택 1회를 사용했어요")
	_send_settled(result)
	_try_fence_ready()

func _send_settled(result: Dictionary) -> void:
	var packet := _thin(result)
	packet["t"] = "gift_settled"
	# 지난 rest의 ACK는 확인만 반복한다. 지운 문맥을 읽거나 현재 선택을 덮지 않는다.
	if result.get("awaiting_settled", false) and int(result.rest_id) == session.wave:
		if not can_publish_state(): return
		packet["donor_state"] = current_state()
	_send(packet, 1)

func _send_complete(entry: Dictionary) -> void:
	var packet := _thin(entry.request)
	packet["t"] = "gift_complete"
	_send(packet, int(packet.donor_id))

func _complete(from: int, message: Dictionary) -> void:
	if from != 1 or not _valid_request(message): return
	var key := _key(message)
	if not terminal.has(key): return
	var result: Dictionary = terminal[key]
	for field in _thin(result):
		if message.get(field) != result.get(field): return
	result["awaiting_settled"] = false
	result.erase("after_context")
	result.erase("after_state")
	_try_fence_ready()

func _settled(from: int, message: Dictionary) -> void:
	if not session.mp.is_host() or not _valid_request(message) or from != int(message.get("donor_id", 0)): return
	var key := _key(message)
	if not host_ledger.has(key): return
	var entry: Dictionary = host_ledger[key]
	if entry.result.is_empty(): return
	for field in _thin(entry.request):
		if message.get(field) != entry.request.get(field): return
	# 중복/old-rest 정산은 최신 offer·tower snapshot을 다시 쓰지 않는다.
	if entry.settled:
		_send_complete(entry)
		return
	if int(message.get("rest_id", -1)) != session.wave or not message.get("donor_state") is Dictionary: return
	if not ingest_state(from, message.donor_state):
		_send_ack(entry)
		return
	entry.settled = true
	entry.request = _thin(entry.request)
	_send_complete(entry)
	_try_fence_ready()

func ingest_state(owner: int, state: Dictionary) -> bool:
	if not state.get("owner_revision") is int or not state.get("owner_epoch") is int: return false
	if str(state.get("gift_round", "")) != round_id or not state.get("list") is Array or not state.get("choice_context") is Dictionary or int(state.get("owner_epoch", -1)) != int(owner_epochs.get(owner, 1)):
		return false
	if _retired(owner): return false
	var revision := int(state.get("owner_revision", -1))
	var previous := int(owner_revisions.get(owner, 0))
	if revision < previous: return false
	for item in state.list:
		if not item is Dictionary or not item.get("nid") is int or int(item.get("nid", 0)) / 100000 != owner: return false
	if revision == previous and owner_states.has(owner) and (owner_states[owner] != state.list or owner_contexts.get(owner, {}) != state.choice_context):
		return false
	owner_revisions[owner] = revision
	owner_states[owner] = state.list.duplicate(true)
	owner_contexts[owner] = state.choice_context.duplicate(true)
	if session.mp.is_host(): _remember_context(owner, state)
	if owner != session.mp.my_id:
		session.multiplayer_system._mp_recv_towers(owner, state.list)
		apply_metadata(owner, state.list)
	return true

func accept_tw(owner: int, message: Dictionary) -> bool:
	if protocol_version != VERSION or int(caps.get(owner, 0)) != VERSION:
		# 구버전과 게임은 계속하되 전달은 supported_all에서 비활성화한다.
		return not message.has("gift_round")
	return ingest_state(owner, message)

func apply_metadata(owner: int, list: Array) -> void:
	for item in list:
		for tower in session.towers.get_children():
			if tower.owner_id == owner and tower.net_id == int(item.get("nid", 0)):
				tower.set_meta("gift_request_id", int(item.get("rqid", 0)))
				break

func _choice(from: int, message: Dictionary) -> void:
	if not session.mp.is_host() or not from in members or not message.get("context") is Dictionary or int(message.get("rest_id", -1)) != session.wave:
		return
	if host_ledger.values().any(func(entry): return int(entry.request.donor_id) == from and not entry.settled):
		return
	if not host_ledger.values().any(func(entry): return int(entry.request.donor_id) == from and int(entry.request.rest_id) == session.wave):
		return
	if not message.get("donor_state") is Dictionary or not ingest_state(from, message.donor_state): return
	# context와 towers는 ingest_state의 같은 revision에서만 함께 갱신한다.

func prepare_wave(force: bool) -> bool:
	if not session.mp.is_host() or not pending.is_empty() or awaiting_settlement() or not owner_retry.is_empty(): return false
	if host_ledger.values().any(func(entry): return not entry.settled): return false
	if host_fence.is_empty():
		if not supported_all() and not protocol_armed: return true
		sequence += 1
		local_fence = nonce + ":wave:" + str(sequence)
		host_force = force
		var need: Array = members.filter(func(id): return id != session.mp.my_id and not _retired(id))
		host_fence = {"id":local_fence, "rest_id":session.wave, "waiting":need, "notified":false}
		_send_fence()
	return host_fence.waiting.is_empty()

func _send_fence() -> void:
	if host_fence.is_empty(): return
	fence_retry_at = Time.get_ticks_msec() + 1000
	for id in host_fence.waiting:
		var packet := _base("gift_barrier")
		packet.merge({"fence_id":host_fence.id, "owner_epoch":int(owner_epochs.get(id, 1)), "force":host_force})
		_send(packet, int(id))

func _barrier(from: int, message: Dictionary) -> void:
	if int(message.get("rest_id", -1)) != session.wave: return
	if message.t == "gift_barrier":
		if from != 1 or session.mp.is_host() or int(message.get("owner_epoch", -1)) != int(owner_epochs.get(session.mp.my_id, 1)): return
		var fence := str(message.get("fence_id", ""))
		if fence == "": return
		if local_fence != fence:
			local_fence = fence
			fence_sent = false
		host_force = message.get("force", false) == true
		if not pending.is_empty(): _send(pending.request, 1)
		_try_fence_ready()
	else:
		if not session.mp.is_host() or host_fence.is_empty() or not from in host_fence.waiting or str(message.get("fence_id", "")) != host_fence.id or int(message.get("owner_epoch", -1)) != int(owner_epochs.get(from, 1)): return
		host_fence.waiting.erase(from)
		_try_fence_ready()

func mark_retired(id: int) -> void:
	if not id in members: return
	retired_members[id] = true
	caps[id] = 0
	if session.mp.is_host():
		_hello(session.mp.my_id, {"owner_epoch":int(owner_epochs.get(session.mp.my_id, 1))})
		_retire()

func _retired(id: int) -> bool:
	return session.mp_kicked.has(id) or retired_members.has(id)

func _retire() -> void:
	# RTC _drop도 in_game을 지운다. 연결이 살아 있는데 lobby로 돌아간 경우만 명시 퇴장이다.
	for id in session.mp.connected_ids():
		if session.mp.started and not session.mp.in_game.has(id): retired_members[id] = true
	for key in host_ledger.keys():
		var entry: Dictionary = host_ledger[key]
		if entry.settled: continue
		if entry.result.is_empty() and _retired(int(entry.request.owner_id)):
			_reject_host(str(key), "받는 플레이어가 판에서 나가 카드를 보관했어요")
		if _retired(int(entry.request.donor_id)) and not entry.result.is_empty():
			entry.settled = true
			entry.request = _thin(entry.request)
	if not host_fence.is_empty():
		host_fence.waiting = host_fence.waiting.filter(func(id): return not _retired(int(id)))
		if Time.get_ticks_msec() >= fence_retry_at and not host_fence.waiting.is_empty(): _send_fence()

func _try_fence_ready() -> void:
	if local_fence == "" or not pending.is_empty() or awaiting_settlement() or not owner_retry.is_empty(): return
	if session.mp.is_host():
		if host_fence.is_empty() or not host_fence.waiting.is_empty() or host_fence.notified or host_ledger.values().any(func(entry): return not entry.settled): return
		host_fence.notified = true
		session.multiplayer_system.call_deferred("_mp_try_go", host_force)
		return
	if fence_sent: return
	if host_force and session.phase in REST and session.phase != BinduSession.Phase.READY:
		# 예약이 끝난 뒤 자기 카드만 자동 적용한다. 새 선물 예약은 만들지 않는다.
		settling_local = true
		session.lobby_system._mp_auto_rest()
		settling_local = false
	if session.phase != BinduSession.Phase.READY: return
	fence_sent = true
	var packet := _base("gift_barrier_ready")
	packet.merge({"fence_id":local_fence, "owner_epoch":int(owner_epochs.get(session.mp.my_id, 1))})
	_send(packet, 1)

func accept_wave(message: Dictionary) -> bool:
	if not pending.is_empty() or awaiting_settlement() or not owner_retry.is_empty(): return false
	if protocol_version == VERSION and str(message.get("gift_round", "")) != round_id: return false
	if protocol_armed and (local_fence == "" or str(message.get("gift_fence", "")) != local_fence): return false
	authorized_wave = str(message.get("gift_fence", "legacy"))
	local_fence = ""
	return true

func accept_rejoin_wave(state: Dictionary) -> bool:
	# 이 경로는 host의 re snapshot(ph=wave)에서만 호출된다. 새 wave 명령의 fence와 구분한다.
	if protocol_version != VERSION: return true
	if closed or str(state.get("round_id", "")) != round_id: return false
	for entry in state.get("entries", {}).values():
		if not entry.get("settled", false): return false
		var key := _key(entry.request)
		if terminal.has(key) and terminal[key].get("awaiting_settled", false):
			_complete(1, _thin(entry.request))
	if not pending.is_empty() or awaiting_settlement() or not owner_retry.is_empty(): return false
	local_fence = ""
	authorized_wave = "rejoin:" + round_id
	return true

func wave_started() -> void:
	local_fence = ""
	host_fence.clear()
	authorized_wave = ""
	fence_sent = false
	for key in terminal:
		if int(terminal[key].get("rest_id", -1)) < session.wave:
			terminal[key].erase("after_context")
			terminal[key].erase("after_state")
	for id in donor_contexts.keys():
		if int(donor_contexts[id].get("rest_id", -1)) < session.wave: donor_contexts.erase(id)

func peer_rejoined(id: int) -> void:
	owner_epochs[id] = int(owner_epochs.get(id, 1)) + 1
	caps[id] = 0
	if session.mp.is_host(): _hello(session.mp.my_id, {"owner_epoch":int(owner_epochs.get(session.mp.my_id, 1))})
	if not host_fence.is_empty() and not id in host_fence.waiting:
		host_fence.waiting.append(id)
		host_fence.notified = false

func rejoin_state(id: int) -> Dictionary:
	var receipts := {}
	for key in host_ledger:
		var entry: Dictionary = host_ledger[key]
		if not entry.result.is_empty(): receipts[key] = entry.result.duplicate(true)
	return {"round_id":round_id, "armed":protocol_armed, "caps":caps.duplicate(), "epochs":owner_epochs.duplicate(), "revisions":owner_revisions.duplicate(),
		"receipts":receipts, "entries":host_ledger.duplicate(true), "context":donor_contexts.get(id, {}).duplicate(true), "retired":retired_members.duplicate(), "fence":host_fence.duplicate(true)}

func restore_rejoin(state: Dictionary) -> void:
	if str(state.get("round_id", "")) != round_id: return
	protocol_armed = protocol_armed or state.get("armed", false) == true
	owner_epochs = (state.get("epochs", {}) as Dictionary).duplicate()
	owner_revisions = (state.get("revisions", {}) as Dictionary).duplicate()
	caps = (state.get("caps", {}) as Dictionary).duplicate()
	retired_members = (state.get("retired", {}) as Dictionary).duplicate()
	owner_ledger.clear()
	owner_retry.clear()
	owner_states.clear()
	owner_contexts.clear()
	sent_states.clear()
	request_versions.clear()
	received_rest = -1
	for key in state.get("receipts", {}):
		var receipt: Dictionary = state.receipts[key]
		if int(receipt.get("owner_id", 0)) == session.mp.my_id:
			owner_ledger[key] = receipt.duplicate(true)
			if receipt.get("status") == "accepted": received_rest = maxi(received_rest, int(receipt.rest_id))
	session.lobby_system.mp_req_got_w = received_rest
	for tower in session.multiplayer_system._my_towers():
		request_versions[tower.net_id] = int(tower.get_meta("gift_request_id", 0))
	var to_settle: Dictionary = {}
	var restored_terminal := false
	for key in state.get("entries", {}):
		var entry: Dictionary = state.entries[key]
		if int(entry.request.donor_id) != session.mp.my_id or entry.settled: continue
		if terminal.has(key):
			restored_terminal = true
			if terminal[key].has("after_context"): _restore_context(terminal[key].after_context)
			_send_settled(terminal[key])
			continue
		pending = {"request":entry.request.duplicate(true), "context":entry.request.context.duplicate(true)}
		if not entry.result.is_empty(): to_settle = entry.result.duplicate(true)
		break
	if not pending.is_empty():
		_restore_context(pending.context)
		if not to_settle.is_empty():
			to_settle["t"] = "gift_ack"
			_ack(1, to_settle)
		else:
			retry_at = 0
	elif not restored_terminal and state.get("context") is Dictionary and int(state.context.get("rest_id", -1)) == session.wave:
		_restore_context(state.context.context)
	var fence: Dictionary = state.get("fence", {})
	if not fence.is_empty() and int(fence.get("rest_id", -1)) == session.wave:
		local_fence = str(fence.get("id", ""))
		fence_sent = false
	hello_at = 0
	context_signature = ""

func debug_state() -> Dictionary:
	return {"round_id":round_id, "protocol_version":protocol_version, "protocol_armed":protocol_armed, "implementation_ready":implementation_ready,
		"pending":pending.duplicate(true), "host_ledger":host_ledger.duplicate(true), "owner_ledger":owner_ledger.duplicate(true),
		"terminal":terminal.duplicate(true), "caps":caps.duplicate(true), "owner_revisions":owner_revisions.duplicate(true),
		"owner_epochs":owner_epochs.duplicate(true), "generation":generation, "local_fence":local_fence, "host_fence":host_fence.duplicate(true), "received_rest":received_rest, "awaiting_settled":awaiting_settlement(), "closed":closed}
