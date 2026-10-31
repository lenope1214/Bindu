class_name Mp
extends Node
## 멀티플레이 연결. 방 코드 중개는 Cloudflare Worker(server/mp-worker), 게임 통신은 WebRTC.
## 호스트(id 1)가 방을 만들고 참가자(id 2~)는 호스트와만 연결한다(별 모양). 참가자끼리 주고받을 것은 호스트가 대신 전한다.
## 메시지는 사전 하나 {"t": 종류, ...}. 받으면 packet(보낸 id, 사전) 신호.

signal room_ready  # 방이 생겼거나 방에 들어감 (code·my_id·mode가 정해짐)
signal peers_changed  # 들어오고 나간 사람·연결 상태
signal packet(from: int, msg: Dictionary)
signal failed(reason: String)  # 방 만들기·참가 실패 또는 연결이 끊김 (방이 끝남)

const MAX_PLAYERS := 4
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const STUN := [{"urls": ["stun:stun.cloudflare.com:3478"]}]
const WAIT_JOIN := 15.0  # 들어간 뒤 호스트와 WebRTC 연결을 기다리는 시간

var ws := WebSocketPeer.new()
var ws_open := false
var rtc: WebRTCMultiplayerPeer
var code := ""
var mode := ""  # "vs" 대결 | "coop" 협동
var my_id := 0
var host_name := ""
var ice: Array = STUN
var peers := {}  # id -> {"name", "conn", "ok"(WebRTC 연결됨)}
var my_name := ""
var started := false  # 판을 시작함 (더는 들어올 수 없음)
var join_wait := -1.0
var closing := false


## 이 기기에서 WebRTC 확장이 읽혔는지 (Android 32비트처럼 라이브러리가 없으면 false).
static func available() -> bool:
	if url() == "":
		return false
	var c := WebRTCPeerConnection.new()
	var ok := c.initialize({}) == OK
	c.close()
	return ok


## 중개 서버 주소. 시험할 때는 환경 변수 BINDU_MP_URL로 바꾼다.
## 헤드리스(봇·무작위 입력)는 환경 변수가 없으면 실제 중개 서버에 방을 만들지 않게 끈다 (Net.reachable()과 같은 이유).
static func url() -> String:
	var e := OS.get_environment("BINDU_MP_URL")
	if e != "":
		return e
	return OnlineConfig.MP_URL if DisplayServer.get_name() != "headless" else ""


## 협동: 사람마다 오브젝트 고리·상태 줄 색.
static func owner_color(id: int) -> Color:
	return [Color(0.45, 0.8, 1.0), Color(1.0, 0.6, 0.35), Color(0.6, 1.0, 0.5), Color(0.95, 0.55, 1.0)][(id - 1) % 4]


static func clean_code(t: String) -> String:
	var out := ""
	for ch in t.to_upper():
		if ch in CODE_CHARS:
			out += ch
	return out.substr(0, 6)


func is_host() -> bool:
	return my_id == 1


func active() -> bool:
	return my_id > 0


## 방 만들기. mode: "vs" | "coop".
func host(m: String, name: String) -> void:
	_reset()
	mode = m
	my_name = name
	_open("op=host&mode=%s" % m)


func join(c: String, name: String) -> void:
	_reset()
	my_name = name
	_open("op=join&code=%s" % clean_code(c))


func _open(q: String) -> void:
	var base := url().replace("https://", "wss://").replace("http://", "ws://").trim_suffix("/")
	var full := "%s/ws?%s&v=%s&name=%s" % [base, q, Net.game_version().uri_encode(), my_name.uri_encode()]
	if ws.connect_to_url(full) != OK:
		failed.emit("중개 서버에 연결하지 못했습니다")
		return
	set_process(true)


## 방을 나간다 (호스트가 나가면 방이 끝난다).
func leave() -> void:
	closing = true
	_reset()
	closing = false


func _reset() -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()
	ws = WebSocketPeer.new()
	ws_open = false
	for id in peers:
		if peers[id].get("conn"):
			peers[id]["conn"].close()
	peers.clear()
	if rtc:
		rtc.close()
		if multiplayer.multiplayer_peer == rtc:
			multiplayer.multiplayer_peer = null
	rtc = null
	code = ""
	my_id = 0
	started = false
	join_wait = -1.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_up)
	multiplayer.peer_disconnected.connect(_on_peer_down)
	if multiplayer is SceneMultiplayer:
		(multiplayer as SceneMultiplayer).server_relay = false
		(multiplayer as SceneMultiplayer).peer_packet.connect(_on_bytes)


func _process(delta: float) -> void:
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		ws_open = true
		while ws.get_available_packet_count() > 0:
			var j: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if j is Dictionary:
				_on_signal(j)
	elif st == WebSocketPeer.STATE_CLOSED and ws_open:
		ws_open = false
		# 판을 시작한 뒤에는 중개 서버가 필요 없다 (WebRTC로 이어져 있으면 계속)
		if not started and my_id > 0 and not closing:
			_fail("중개 서버 연결이 끊겼습니다")
	elif st == WebSocketPeer.STATE_CLOSED and my_id == 0 and code == "" and not closing and ws.get_close_code() != -1:
		_fail("중개 서버에 연결하지 못했습니다")
	if rtc:
		rtc.poll()
	if join_wait > 0.0:
		join_wait -= delta
		if join_wait <= 0.0 and not peers.get(1, {}).get("ok", false):
			_fail("호스트와 연결하지 못했습니다 (네트워크가 막혀 있을 수 있음)")


func _fail(reason: String) -> void:
	var was := my_id > 0 or ws_open
	_reset()
	if was or reason != "":
		failed.emit(reason)


func _send_ws(d: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(d))


func _on_signal(j: Dictionary) -> void:
	match str(j.get("t", "")):
		"room":
			code = str(j.get("code", ""))
			my_id = int(j.get("id", 0))
			mode = str(j.get("mode", mode))
			var ic: Variant = j.get("ice")
			if ic is Array and not ic.is_empty():
				ice = ic
			rtc = WebRTCMultiplayerPeer.new()
			if my_id == 1:
				rtc.create_server()
			else:
				rtc.create_client(my_id)
			multiplayer.multiplayer_peer = rtc
			for p in j.get("peers", []):
				if p is Dictionary and int(p.get("id", 0)) != my_id:
					peers[int(p["id"])] = {"name": str(p.get("name", "")), "conn": null, "ok": false}
			peers[my_id] = {"name": my_name, "conn": null, "ok": true}
			if my_id != 1:
				_make_conn(1)  # 호스트가 offer를 보낸다
				join_wait = WAIT_JOIN
			room_ready.emit()
			peers_changed.emit()
		"join":
			var id := int(j.get("id", 0))
			if id > 1:
				peers[id] = {"name": str(j.get("name", "")), "conn": null, "ok": false}
				if is_host():
					var c := _make_conn(id)
					c.create_offer()
				peers_changed.emit()
		"leave":
			var id := int(j.get("id", 0))
			if peers.has(id) and not peers[id]["ok"]:
				_drop(id)
		"sig":
			_on_rtc_signal(int(j.get("from", 0)), j.get("d", {}))
		"closed":
			if not started:
				_fail("호스트가 방을 닫았습니다")
		"err":
			var why := {"nocode": "없는 방 코드입니다", "full": "방이 가득 찼습니다 (최대 %d명)" % MAX_PLAYERS,
				"version": "호스트와 게임 버전이 다릅니다 (호스트 %s)" % str(j.get("host_v", "?")), "started": "이미 시작한 방입니다"}
			_fail(why.get(str(j.get("code", "")), "방에 들어가지 못했습니다"))


func _make_conn(id: int) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	c.initialize({"iceServers": ice})
	c.session_description_created.connect(func(type: String, sdp: String):
		c.set_local_description(type, sdp)
		_send_ws({"t": "sig", "to": id, "d": {"k": "sdp", "type": type, "sdp": sdp}}))
	c.ice_candidate_created.connect(func(mid: String, idx: int, cand: String):
		_send_ws({"t": "sig", "to": id, "d": {"k": "ice", "mid": mid, "idx": idx, "cand": cand}}))
	rtc.add_peer(c, id)
	if peers.has(id):
		peers[id]["conn"] = c
	else:
		peers[id] = {"name": "", "conn": c, "ok": false}
	return c


func _on_rtc_signal(from: int, d: Variant) -> void:
	if not d is Dictionary or not peers.has(from) or peers[from]["conn"] == null:
		return
	var c: WebRTCPeerConnection = peers[from]["conn"]
	match str(d.get("k", "")):
		"sdp":
			c.set_remote_description(str(d.get("type", "")), str(d.get("sdp", "")))
		"ice":
			c.add_ice_candidate(str(d.get("mid", "")), int(d.get("idx", 0)), str(d.get("cand", "")))


func _on_peer_up(id: int) -> void:
	if peers.has(id):
		peers[id]["ok"] = true
	if id == 1:
		join_wait = -1.0
	peers_changed.emit()


func _on_peer_down(id: int) -> void:
	if id == 1 and not is_host():
		_fail("호스트와 연결이 끊겼습니다")
		return
	_drop(id)
	packet.emit(id, {"t": "gone"})


func _drop(id: int) -> void:
	if not peers.has(id):
		return
	if rtc and rtc.has_peer(id):
		rtc.remove_peer(id)
	peers.erase(id)
	peers_changed.emit()


## 판 시작: 중개 서버에 방을 잠그게 하고 연결을 끊는다(남은 통신은 WebRTC).
func lock() -> void:
	started = true
	_send_ws({"t": "lock"})


func names() -> Array:
	var ids := peers.keys()
	ids.sort()
	return ids.map(func(id): return [id, peers[id]["name"], peers[id]["ok"]])


func connected_ids() -> Array:
	var out: Array = []
	for id in peers:
		if id != my_id and peers[id]["ok"]:
			out.append(id)
	return out


## to: 0이면 모두에게 (참가자가 보내면 호스트가 다른 참가자에게도 전한다).
func send(msg: Dictionary, to := 0, reliable := true) -> void:
	if rtc == null or my_id == 0:
		return
	msg["f"] = my_id
	var b := var_to_bytes(msg)
	var m := MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	var ch := 0  # SceneMultiplayer 기본 채널 (전송 방식은 m이 고름)
	var sm := multiplayer as SceneMultiplayer
	if is_host():
		for id in connected_ids():
			if to == 0 or to == id:
				sm.send_bytes(b, id, m, ch)
	elif peers.get(1, {}).get("ok", false):
		if to != 0 and to != 1:
			msg["to"] = to
			b = var_to_bytes(msg)
		sm.send_bytes(b, 1, m, ch)


func _on_bytes(id: int, b: PackedByteArray) -> void:
	var v: Variant = bytes_to_var(b)
	if not v is Dictionary:
		return
	var msg: Dictionary = v
	if is_host() and id != 1:
		msg["f"] = id  # 보낸 사람은 연결로 정한다 (참가자가 다른 id를 사칭하지 못하게)
		var to := int(msg.get("to", 0))
		var bb := var_to_bytes(msg)
		var sm := multiplayer as SceneMultiplayer
		for other in connected_ids():
			if other != id and (to == 0 or to == other):
				sm.send_bytes(bb, other, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)
		if to != 0 and to != 1:
			return
	packet.emit(int(msg.get("f", id)), msg)
