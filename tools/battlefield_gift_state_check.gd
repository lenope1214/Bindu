extends SceneTree
## 결정론 단위 게이트. 실제 feature/세션/owner 적용/카드 소비 사용, 전송 큐만 메모리 대역.
## 실제 WebRTC 경합/재접속은 battlefield_gift_check.gd의 별도 3-process native 검증.
class QueuedTransactions extends BinduGiftTransactions:
	var outbox: Array[Dictionary] = []
	func _send(message: Dictionary, to: int) -> void:
		outbox.append({"from":session.mp.my_id, "to":to, "message":message.duplicate(true)})

class RecordingMp extends Mp:
	var sent: Array[Dictionary] = []
	func send(message: Dictionary, _to := 0, _reliable := true) -> void:
		sent.append(message.duplicate(true))

var games: Array = []
var services: Array = []
var assertions := 0
var failures := 0
var captured: Array[Dictionary] = []
var round_number := 0
const IDS := [1, 2, 3]

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1
	print(("ok " if condition else "FAIL ") + description)

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	call_deferred("run")

func run() -> void:
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 5
	Meta.guide_on = false
	for id in IDS:
		var game = load("res://main.tscn").instantiate()
		root.add_child(game)
		game.sfx.set_muted(true)
		game.set_process(false)
		game.mp.set_process(false)
		game.progression_system._hide_title()
		game.mp.my_id = id
		game.mp.mode = "coop"
		game.mp_mode = "coop"
		game.mp.started = true
		game.mp.in_game = {1:true, 2:true, 3:true}
		game.auto_start = false
		var service := QueuedTransactions.new(game)
		game.multiplayer_system._gift_transactions = service
		games.append(game)
		services.append(service)
	await process_frame
	reset_case()
	check(services.all(func(service): return service.implementation_ready), "제품 구현 준비 상태 활성")
	await race_case()
	await retry_and_context_case()
	await edit_mode_restore_case()
	await completion_retry_case()
	await owner_atomic_case()
	await owner_rejoin_case()
	await rejoin_and_boundary_case()
	await fence_case()
	await wave_rejoin_case()
	await retire_and_validation_case()
	await legacy_transport_case()
	for game in games:
		for player in game.sfx.players + game.sfx.lead + [game.sfx.music_player]:
			player.stream_paused = false
			player.stop()
			player.stream = null
	await create_timer(0.1).timeout
	for game in games:
		game.mp.my_id = 0
		game.mp_mode = ""
		game.queue_free()
	await process_frame
	services.clear()
	games.clear()
	print("GIFT STATE assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures else 0)

func reset_case() -> void:
	round_number += 1
	captured.clear()
	for i in games.size():
		var game = games[i]
		var service = services[i]
		service.close_round()
		service.outbox.clear()
		game.mp_kicked.clear()
		game.mp.in_game = {1:true, 2:true, 3:true}
		game.mp_others = {}
		game.mp_ready = {}
		game.mp_i_ready = false
		game.wave = 3
		game.phase = game.Phase.CHOOSE
		game.perk_mode = false
		game.coin_stage = 0
		game.countdown = -1.0
		game.bank_picks = [1]
		game.bank_perks = 0
		game.bank_rerolls = 0
		game.run_log = []
		game.picks_left = 2
		game.rerolls_left = 1
		game.bonus_rerolls = 0
		game.perk_rerolls = 0
		game.picked = {}
		game.interaction_system.press_t = null
		game.interaction_system.moving = null
		game.interaction_system.selected.clear()
		game.card_dock.close_inspector()
		game.card_dock.clear_gesture()
		game.lobby_system.mp_req_got_w = -1
		game.offer = [{"type":"elem", "e":Elem.WATER, "lv":1}, {"type":"elem", "e":Elem.FIRE, "lv":1}]
		for node in game.towers.get_children(): node.free()
		service.start_round({"gift_round":"state-%d" % round_number, "gift_v":1, "ids":IDS})
		service.receive(1, {"t":"gift_caps", "v":1, "round_id":service.round_id, "caps":{1:1, 2:1, 3:1}, "epochs":{1:1, 2:1, 3:1}})
		game.cards_system._show_offer()
		game.cards_hidden = false
		game.choice_box.show()
	var tower := Tower.new()
	tower.main = games[0]
	tower.owner_id = 1
	tower.net_id = 100001
	tower.position = Vector2(280, 300)
	tower.add(Elem.FIRE, 1)
	tower.req_e = Elem.WATER
	games[0].towers.add_child(tower)
	services[0].next_request(tower)
	sync_states()

func sync_states() -> void:
	for i in games.size():
		var state: Dictionary = services[i].current_state()
		for j in games.size():
			if i != j: services[j].ingest_state(i + 1, state)

func target(index: int) -> Tower:
	for tower in games[index].towers.get_children():
		if tower.net_id == 100001: return tower
	return null

func reserve(index: int) -> Dictionary:
	var game = games[index]
	game.mp_auto_now = true # UI 상태와 별개로 실제 중앙 _on_pick 검증을 거친다.
	check(game.cards_system._on_pick(game.offer[0]), "donor%d 실제 카드 선택" % (index + 1))
	game.mp_auto_now = false
	check(services[index].begin_gift(target(index)), "donor%d 선택 예약" % (index + 1))
	return services[index].pending.request.duplicate(true)

func deliver(packet: Dictionary) -> void:
	captured.append(packet.duplicate(true))
	if int(packet.to) == 0:
		for i in games.size():
			if i + 1 != int(packet.from): services[i].receive(int(packet.from), packet.message.duplicate(true))
	elif int(packet.to) in IDS:
		services[int(packet.to) - 1].receive(int(packet.from), packet.message.duplicate(true))

func pump(hold: Array = []) -> void:
	for _step in 100:
		var moved := false
		for service in services:
			for packet in service.outbox.duplicate():
				if str(packet.message.t) in hold: continue
				service.outbox.erase(packet)
				deliver(packet)
				moved = true
		if not moved: return
	check(false, "패킷 큐가 유한 시간에 수렴")

func first_packet(kind: String) -> Dictionary:
	for packet in captured:
		if packet.message.t == kind: return packet.duplicate(true)
	return {}

func race_case() -> void:
	var request_a := reserve(1)
	var context_a: Dictionary = services[1]._context().duplicate(true)
	var request_b := reserve(2)
	var context_b: Dictionary = services[2]._context().duplicate(true)
	check(games[1].picks_left == 2 and games[2].picks_left == 2, "send는 양쪽 선택 미소비")
	games[1].interaction_system._cancel_step()
	games[1].interaction_system._place_tower(Vector2(900, 300), Vector2.RIGHT)
	games[1].lobby_system._mp_auto_rest()
	check(services[1]._context() == context_a and games[1].towers.get_child_count() == 1, "pending cancel/직접설치/AFK가 선택·전장을 보존")
	pump(["gift_ack"])
	check(target(0).lv(Elem.WATER) == 1, "owner 적용 정확히 1회")
	check(games[1].picks_left == 2 and games[2].picks_left == 2, "host commit 후 ACK 전 미소비")
	check(services[0].host_ledger.size() == 2 and services[0].host_ledger.values().filter(func(entry): return entry.status == "accepted").size() == 1, "동일 요청 경합 accepted1/rejected1")
	var host_context: Dictionary = services[0]._context()
	games[0].multiplayer_system._mp_try_go(true)
	check(services[0]._context() == host_context and not services[0].before_wave(), "미정산 force wave는 host 카드도 불변")
	pump()
	services[0].ack_retry_at = 0
	services[0].tick(0.0)
	pump()
	check(games[1].picks_left == 1 and games[1].bank_picks.is_empty(), "승자 선택·bank 정확히 1회 소비")
	check(services[2]._context() == context_b, "거절은 원 offer/카드/선택/bank/새로고침 유지")
	check(services[0].host_ledger.values().all(func(entry): return entry.settled), "양쪽 host 정산 완료")
	check(not services[1].awaiting_settlement() and not services[2].awaiting_settlement(), "완료 확인 뒤 잠금 해제")
	var after: Dictionary = services[1]._context()
	services[0].receive(2, request_a)
	services[0].receive(3, request_b)
	pump()
	check(services[1]._context() == after and target(0).lv(Elem.WATER) == 1, "동일 request/ACK replay는 새 offer·소비·적용 불변")
	var bad := request_a.duplicate(true)
	bad.lv = 2
	bad.fp = services[0]._fingerprint(bad)
	services[0].receive(2, bad)
	pump()
	check(target(0).lv(Elem.WATER) == 1, "동일 token payload 변조 거절")
	check(context_a.picks_left == 2, "예약 문맥 원본 불변")

func retry_and_context_case() -> void:
	reset_case()
	reserve(1)
	pump(["gift_settled"])
	check(services[1].pending.is_empty() and services[1].awaiting_settlement(), "settled 유실은 다음 선택 잠금 유지")
	var context: Dictionary = services[1]._context()
	games[1].lobby_system._mp_auto_rest()
	games[1].interaction_system._back_to_choose()
	check(services[1]._context() == context, "정산 확인 유실 중 AFK/취소가 새 offer 보존")
	services[0].ack_retry_at = 0
	services[0].tick(0.0)
	pump()
	check(not services[1].awaiting_settlement() and services[0].host_ledger.values()[0].settled, "host ACK 재전송이 settled 유실 복구")
	var stale_settled := first_packet("gift_settled")
	games[1].phase = games[1].Phase.READY
	games[1].picks_left = 0
	var own := Tower.new()
	own.main = games[1]
	own.owner_id = 2
	own.net_id = 200001
	own.position = Vector2(900, 300)
	own.add(Elem.WATER, 1)
	games[1].towers.add_child(own)
	var newer: Dictionary = services[1].current_state()
	services[0].accept_tw(2, newer)
	var saved: Dictionary = services[0].donor_contexts[2].duplicate(true)
	deliver(stale_settled)
	check(games[0].towers.get_children().any(func(tower): return tower.net_id == 200001) and services[0].donor_contexts[2].context.picks_left == 0, "정상 후속카드의 TW와 소비 문맥이 원자 동시 반영")
	check(services[0].donor_contexts[2] == saved and saved.context.picks_left == 0, "중복 settled는 최신 선택 문맥을 역행시키지 않음")
	var tamper := newer.duplicate(true)
	tamper.choice_context.picks_left = 9
	check(not services[0].ingest_state(2, tamper), "동일 revision에 다른 choice context 거절")
	var ack := first_packet("gift_ack")
	for game in games: game.wave += 1
	for service in services: service.wave_started()
	var before: Dictionary = services[1]._context()
	deliver(ack)
	pump()
	check(services[1]._context() == before, "지난 rest ACK는 삭제한 after_context 접근 없이 무해")

func edit_mode_restore_case() -> void:
	reset_case()
	reserve(1)
	pump()
	games[1].picks_left = 0
	games[1].cards_system._enter_ready()
	var own := Tower.new()
	own.main = games[1]
	own.owner_id = 2
	own.net_id = 200001
	own.position = Vector2(900, 300)
	own.add(Elem.FIRE, 1)
	games[1].towers.add_child(own)
	games[1].interaction_system._start_move(own)
	var state: Dictionary = services[1].current_state()
	check(state.choice_context.phase == games[1].Phase.READY, "방향편집 AIM은 소비카드 PLACE 대신 원래 READY로 직렬화")
	services[0].ingest_state(2, state)
	games[1].interaction_system.moving = null
	services[1]._restore_context(services[0].donor_contexts[2].context)
	check(games[1].phase == games[1].Phase.READY and games[1].picks_left == 0, "재접속 방향편집 취소가 소비 끝난 카드의 무료 PLACE를 만들지 않음")

func completion_retry_case() -> void:
	reset_case()
	reserve(1)
	pump(["gift_complete"])
	check(services[0].host_ledger.values()[0].settled and services[1].awaiting_settlement(), "complete 유실의 host/local 정산 상태 구분")
	# 실제 유실: 큐에서 삭제한 뒤 donor의 timer 재전송만으로 복구해야 한다.
	for service in services:
		for packet in service.outbox.duplicate():
			if packet.message.t == "gift_complete": service.outbox.erase(packet)
	for result in services[1].terminal.values(): result["settlement_retry_at"] = 0
	services[1].tick(0.0)
	pump()
	check(not services[1].awaiting_settlement() and games[1].picks_left == 1, "same-token settled 재전송이 complete 유실·재접속을 추가 소비 없이 복구")

func owner_atomic_case() -> void:
	reset_case()
	# participant 소유 요청으로 owner result 유실을 만든다.
	for game in games:
		for tower in game.towers.get_children(): tower.free()
	var tower := Tower.new()
	tower.main = games[1]
	tower.owner_id = 2
	tower.net_id = 200001
	tower.position = Vector2(280, 300)
	tower.add(Elem.FIRE, 1)
	tower.req_e = Elem.WATER
	games[1].towers.add_child(tower)
	services[1].next_request(tower)
	sync_states()
	var game = games[2]
	game.mp_auto_now = true
	check(game.cards_system._on_pick(game.offer[0]), "remote owner용 donor 카드 선택")
	game.mp_auto_now = false
	var remote: Tower = game.towers.get_child(0)
	check(services[2].begin_gift(remote), "remote owner 예약")
	pump(["gift_result"])
	# A 미확정 중 B rejected result가 A snapshot을 먼저 공개하는 경로도 막는다.
	games[0].mp_auto_now = true
	check(games[0].cards_system._on_pick(games[0].offer[0]), "동시 두 번째 donor 실제 선택")
	games[0].mp_auto_now = false
	check(services[0].begin_gift(games[0].towers.get_child(0)), "동시 두 번째 donor 예약")
	pump(["gift_result"])
	check(services[1].owner_ledger.size() == 1, "첫 accepted 미확정 중 다른 rejected snapshot도 보류")
	check(tower.lv(Elem.WATER) == 1 and not services[1].can_publish_state(), "owner 미확정 적용은 일반TW publish 금지")
	games[1].multiplayer_system.mp_tw_sig = ""
	games[1].multiplayer_system._mp_send_towers()
	check(services[1].blocks_local_choice(), "owner commit 확인 전 편집 차단")
	check(games[0].towers.get_child(0).lv(Elem.WATER) == 0, "result 유실 중 host TW는 미적용 상태 유지")
	pump()
	services[0].ack_retry_at = 0
	services[0].tick(0.0)
	pump()
	check(games[0].picks_left == 2, "후속 rejected donor는 선택 미소비")
	check(services[1].can_publish_state() and games[2].picks_left == 1 and games[0].towers.get_child(0).lv(Elem.WATER) == 1, "원자 host commit 뒤 owner 잠금 해제·donor1소비")

func owner_rejoin_case() -> void:
	reset_case()
	# owner2 + donor3. transport만 단절시키고 host의 미적용 snapshot으로 owner를 복구한다.
	for game in games:
		for tower in game.towers.get_children(): tower.free()
	var tower := Tower.new()
	tower.main = games[1]
	tower.owner_id = 2
	tower.net_id = 200001
	tower.position = Vector2(280, 300)
	tower.add(Elem.FIRE, 1)
	tower.req_e = Elem.WATER
	games[1].towers.add_child(tower)
	services[1].next_request(tower)
	sync_states()
	games[2].mp_auto_now = true
	check(games[2].cards_system._on_pick(games[2].offer[0]), "owner복구 donor 실제 선택")
	games[2].mp_auto_now = false
	check(services[2].begin_gift(games[2].towers.get_child(0)), "owner복구 예약")
	pump(["gift_result"])
	var old_result: Dictionary = services[1].outbox.filter(func(packet): return packet.message.t == "gift_result")[0].duplicate(true)
	var original: Dictionary = services[0].host_ledger.values()[0].request.duplicate(true)
	games[0].mp.in_game.erase(2)
	check(not services[0]._retired(2), "일시 RTC 단절의 in_game 제거는 영구 퇴장 아님")
	services[0].peer_rejoined(2)
	var saved: Dictionary = services[0].owner_states[2][0].duplicate(true)
	tower.mp_apply(saved)
	tower.set_meta("gift_request_id", int(saved.rqid))
	services[1].outbox.clear()
	services[1].restore_rejoin(services[0].rejoin_state(2))
	check(services[1].owner_ledger.is_empty() and games[1].lobby_system.mp_req_got_w == -1, "owner 미확정 receipt·수신횟수를 host 확정 상태로 교체")
	deliver(old_result)
	check(games[0].towers.get_child(0).lv(Elem.WATER) == 0 and services[0].host_ledger.values()[0].result.is_empty(), "old epoch owner result는 host snapshot/receipt에 영향 없음")
	services[0].receive(3, original)
	pump()
	check(tower.lv(Elem.WATER) == 1 and games[0].towers.get_child(0).lv(Elem.WATER) == 1 and games[2].picks_left == 1, "원래 token을 새 owner epoch에서 재검증·1회 적용·1회 소비")

func rejoin_and_boundary_case() -> void:
	reset_case()
	reserve(1)
	pump(["gift_settled"])
	var after: Dictionary = services[1]._context()
	var state: Dictionary = services[0].rejoin_state(2)
	services[1].restore_rejoin(state)
	check(services[1]._context() == after, "terminal 복원 뒤 host 원본 예약 context로 다시 덮지 않음")
	pump()
	check(not services[1].awaiting_settlement(), "재접속 terminal settlement 재전송 수렴")
	var stale := first_packet("gift_request")
	var next_round := "replacement-round"
	for service in services: service.start_round({"gift_round":next_round, "gift_v":1, "ids":IDS})
	var counts := games.map(func(game): return game.picks_left)
	deliver(stale)
	pump()
	check(services[0].host_ledger.is_empty() and games.map(func(game): return game.picks_left) == counts, "old round request는 새 판에 효과 없음")
	reset_case()
	services[1].caps[3] = 0
	var status: Dictionary = services[1].offer_status(target(1), games[1].offer[0])
	check(not status.ok, "구버전/미협상 peer 포함시 foreign gift fail closed")
	check(services[1].offer_status(null, {}).ok == false, "잘못된 target fail closed")
	var before_level := target(0).lv(Elem.WATER)
	games[0].lobby_system._mp_recv_gift(2, {"nid":100001, "e":Elem.WATER, "lv":1})
	check(target(0).lv(Elem.WATER) == before_level, "legacy gift 직접수신도 적용하지 않음")

func fence_case() -> void:
	reset_case()
	for game in games: game.cards_system._enter_ready()
	check(not services[0].prepare_wave(false), "host는 모든 participant fence 전에 wave 대기")
	pump(["gift_barrier_ready"])
	check(services[1].blocks_local_choice() and services[2].blocks_local_choice(), "participant fence는 선택/편집 동결")
	var wrong: Dictionary = services[1]._base("gift_barrier_ready")
	wrong.merge({"fence_id":"wrong", "owner_epoch":1})
	services[0].receive(2, wrong)
	check(services[0].host_fence.waiting.size() == 2, "불일치 fence ready 무시")
	# deferred 실제 wave 실행 대신 packet 승인 경계까지만 결정론 검사.
	services[0].host_fence.notified = true
	pump()
	check(services[0].prepare_wave(false), "같은 round/rest/epoch 전원 ready 뒤 host 승인")
	var packet := {"gift_round":services[0].round_id, "gift_fence":services[0].local_fence}
	check(services[1].accept_wave(packet) and services[2].accept_wave(packet), "정상 host wave가 local fence 소비")
	games[1].mp_wave_go = true
	check(services[1].before_wave(), "승인된 participant wave가 before_wave guard 통과")
	games[1].mp_wave_go = false
	services[0].wave_started()
	services[0].peer_rejoined(2)
	check(not services[0].prepare_wave(true), "협상 완료 뒤 rejoin caps0이어도 fence 생략 금지")
	check(services[0].caps[2] == 0 and int(services[0].owner_epochs[2]) == 2, "재접속 epoch 갱신·capability 재협상")

func wave_rejoin_case() -> void:
	reset_case()
	var game = games[1]
	game.mp_ghost = true
	game.phase = game.Phase.WAVE
	var packet := {"w":4, "ph":"wave", "sc":10, "k":2, "hp":game.core_hp, "mx":game.core_max,
		"tw":{1:services[0].current_state().list}, "gift_state":services[0].rejoin_state(2),
		"next":{"w":4, "lanes":[0.0], "res":-1, "boss":{}}}
	game.multiplayer_system._mp_resync(packet)
	check(game.wave == 4 and game.phase == game.Phase.WAVE and game.to_spawn == 0, "실제 _mp_resync의 WAVE snapshot이 승인되어 같은 host wave로 복귀")
	check(game.interaction_system.moving == null and game.interaction_system.press_t == null and game.towers.get_child_count() == 1, "snapshot 복원은 old gesture 참조 없이 오브젝트 유지")
	var bad: Dictionary = services[0].rejoin_state(2)
	bad.round_id = "old-round"
	check(not services[1].accept_rejoin_wave(bad), "다른 round rejoin snapshot은 wave 승인 불가")
	game.mp_ghost = false

func retire_and_validation_case() -> void:
	reset_case()
	for game in games:
		for node in game.towers.get_children(): node.free()
	var tower := Tower.new()
	tower.main = games[1]
	tower.owner_id = 2
	tower.net_id = 200001
	tower.position = Vector2(280, 300)
	tower.add(Elem.FIRE, 1)
	tower.req_e = Elem.WATER
	games[1].towers.add_child(tower)
	services[1].next_request(tower)
	sync_states()
	games[2].mp_auto_now = true
	check(games[2].cards_system._on_pick(games[2].offer[0]), "퇴장owner 대상 donor 실제 선택")
	games[2].mp_auto_now = false
	check(services[2].begin_gift(games[2].towers.get_child(0)), "퇴장owner 대상 예약")
	pump(["gift_apply"])
	services[0].mark_retired(2)
	# 실제 kick의 GAMEOVER는 recipient namespace를 닫는다. 늦은 원래 apply도 복귀시키지 않는다.
	services[1].close_round()
	pump()
	check(games[2].picks_left == 2 and games[0].towers.get_child(0).lv(Elem.WATER) == 0, "owner 명시퇴장은 미확정 적용 없이 donor 카드 보존")
	reset_case()
	reserve(1)
	pump(["gift_ack"])
	services[0].mark_retired(2)
	check(services[0].host_ledger.values()[0].settled and target(0).lv(Elem.WATER) == 1, "donor 명시퇴장은 host commit 유지하고 barrier 정리")
	check(services[0].supported_all(), "영구 퇴장자는 나머지 참가자의 capability 협상을 막지 않음")
	reset_case()
	var request := reserve(1)
	var before: Dictionary = services[0].debug_state()
	services[0].receive(3, request)
	check(services[0].host_ledger.is_empty(), "다른 실제 sender가 보낸 donor token 거절")
	var malformed := request.duplicate(true)
	malformed.donor_id = {"bad":2}
	for kind in ["gift_request", "gift_result", "gift_ack", "gift_settled", "gift_complete"]:
		malformed.t = kind
		services[0].receive(2, malformed)
	check(services[0].host_ledger.is_empty() and before.owner_revisions == services[0].owner_revisions, "잘못된 receipt 필드 타입이 예외·상태변경 없이 거절됨")
	services[0].receive(2, request)
	pump()
	var snapshot: Dictionary = services[1].current_state()
	var stale := snapshot.duplicate(true)
	stale.owner_revision -= 1
	check(not services[0].ingest_state(2, stale), "과거 revision TW는 새 상태를 덮지 않음")
	var forged := snapshot.duplicate(true)
	forged.owner_epoch += 1
	check(not services[0].ingest_state(2, forged), "불일치 epoch TW 거절")

func legacy_transport_case() -> void:
	reset_case()
	for service in services: service.start_round({"gift_round":"", "gift_v":0, "ids":IDS})
	var game = games[1]
	var original_mp: Mp = game.mp
	var recorder := RecordingMp.new()
	recorder.my_id = 2
	game.mp = recorder
	var tower := Tower.new()
	tower.main = game
	tower.owner_id = 2
	tower.net_id = 200001
	tower.position = Vector2(900, 300)
	tower.add(Elem.FIRE, 1)
	game.towers.add_child(tower)
	game.multiplayer_system.mp_tw_sig = ""
	game.multiplayer_system._mp_send_towers()
	check(recorder.sent.size() == 1 and not recorder.sent[0].has("gift_round"), "구host 판에서는 실제 TW 송신이 legacy plain envelope 유지")
	if not recorder.sent.is_empty(): games[2].multiplayer_system._mp_packet(2, recorder.sent[0])
	check(games[2].towers.get_children().any(func(t): return t.net_id == 200001), "구host relay를 받은 newclient도 다른 newclient Tower 동기화")
	check(not services[1].supported_all(), "legacy transport에서도 gift는 fail closed 유지")
	game.mp = original_mp
	recorder.free()
