class_name Mp
extends Node
## 멀티플레이 연결. 방 코드 중개는 Cloudflare Worker(server/mp-worker), 게임 통신은 WebRTC.
## 호스트(id 1)가 방을 만들고 참가자(id 2~)는 호스트와만 연결한다(별 모양). 참가자끼리 주고받을 것은 호스트가 대신 전한다.
## 메시지는 사전 하나 {"t": 종류, ...}. 받으면 packet(보낸 id, 사전) 신호.

signal room_ready  # 방이 생겼거나 방에 들어감 (code·my_id·mode가 정해짐)
signal peers_changed  # 들어오고 나간 사람·연결 상태
signal packet(from: int, msg: Dictionary)
signal failed(reason: String)  # 방 만들기·참가 실패 또는 연결이 끊김 (방이 끝남)
signal status_changed  # 중개 서버의 멀티플레이 스위치(GET /status)를 새로 받음

const MAX_PLAYERS := 4
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const STUN := [{"urls": ["stun:stun.cloudflare.com:3478"]}]
const WAIT_JOIN := 15.0  # 들어간 뒤 호스트와 WebRTC 연결을 기다리는 시간
## 중개 서버에 보내는 이름은 "플랫폼 글자|닉네임" (닉네임 12자 + 2 ≤ Worker의 16자). 받으면 나눈다.
const PF := {"w": "windows", "m": "mac", "i": "ios", "a": "android", "l": "linux"}

var ws := WebSocketPeer.new()
var ws_open := false
var rtc: WebRTCMultiplayerPeer
var code := ""
var mode := ""  # "vs" 대결 | "coop" 협동
var my_id := 0
var host_name := ""
var ice: Array = STUN
var peers := {}  # id -> {"name", "pf", "conn", "ok"(WebRTC 연결됨), "t"(연결 시작 시각), "lc"/"rc"(주고받은 후보 종류 수)}
var my_name := ""
var diag_sent := {}  # id -> true (연결 실패 진단을 한 번만 남긴다)
var started := false  # 판을 시작함 (더는 들어올 수 없음)
var join_wait := -1.0
var closing := false

const WEBRTC_EXT := "res://addons/webrtc/webrtc.gdextension"
const WEBRTC_DLL := "libwebrtc_native.windows.template_release.x86_64.dll"
static var _dll_tried := false
## 서버 스위치 (Worker 환경 변수 MP_OFF): 비면 켜짐, "hide"면 버튼을 숨김, 다른 글이면 버튼은 두고 그 글로 막음.
## 못 받으면(오프라인 등) 켜진 것으로 둔다. 시작 화면을 열 때·멀티플레이 창을 열 때 다시 묻는다.
static var sw_on := true
static var sw_hide := false
static var sw_msg := ""
var _sw_req: HTTPRequest


## 이 기기에서 WebRTC 확장이 읽혔는지 (Android 32비트처럼 라이브러리가 없으면 false).
## 확장이 없어도 WebRTCPeerConnection.new()는 빈 기본 클래스를 돌려주고 initialize()도 OK라서 (0.6.0 Windows가 이랬다:
## 방은 열리는데 연결 단계에서 "_create_offer must be overridden") 실제 구현 클래스가 있는지로 본다.
static func available() -> bool:
	if url() == "":
		return false
	_load_embedded_dll()
	return loaded()


static func loaded() -> bool:
	return ClassDB.class_exists("WebRTCLibPeerConnection")


static var load_log := PackedStringArray()  # 확장 읽기 과정 (오류 로그가 켜지기 전에 일어나서 _ready에서 printerr)


## 자동 업데이트(updater.gd, 이미 나간 0.5.x 포함)는 exe만 바꿔 dll이 안 따라온다. exe 안에 담은 dll을 풀어 읽는다.
## ① exe 옆(Godot이 res:// 확장의 dll을 찾는 자리)에 풀고 res:// 확장을 읽는다.
## ② 그래도 안 되면 user://webrtc/ 에 dll과 .gdextension을 같이 써서 그걸 읽는다 (exe 폴더에 못 쓰는 경우 등).
static func _load_embedded_dll() -> void:
	if _dll_tried or not OS.has_feature("windows") or not OS.has_feature("template"):
		return
	_dll_tried = true
	if loaded():
		return
	load_log.append("start ext_loaded=%s exe=%s" % [GDExtensionManager.is_extension_loaded(WEBRTC_EXT), OS.get_executable_path()])
	var data := FileAccess.get_file_as_bytes("res://addons/webrtc/lib/" + WEBRTC_DLL)
	if data.is_empty():
		load_log.append("embedded dll missing err=%d" % FileAccess.get_open_error())
		return
	var dst := OS.get_executable_path().get_base_dir().path_join(WEBRTC_DLL)
	if not FileAccess.file_exists(dst) and not _write(dst, data):
		load_log.append("write exe dir failed err=%d" % FileAccess.get_open_error())
	elif not GDExtensionManager.is_extension_loaded(WEBRTC_EXT):
		load_log.append("load res = %d" % GDExtensionManager.load_extension(WEBRTC_EXT))
	if loaded():
		return
	var dir := "user://webrtc"
	DirAccess.make_dir_recursive_absolute(dir)
	var ext := dir.path_join("webrtc.gdextension")
	var cfg := "[configuration]\nentry_symbol = \"webrtc_extension_init\"\ncompatibility_minimum = 4.3\n\n[libraries]\n" + \
		"windows.debug.x86_64 = \"%s\"\nwindows.release.x86_64 = \"%s\"\n" % [WEBRTC_DLL, WEBRTC_DLL]
	var dll_u := dir.path_join(WEBRTC_DLL)
	if not (FileAccess.file_exists(dll_u) and FileAccess.get_file_as_bytes(dll_u).size() == data.size()) and not _write(dll_u, data):
		load_log.append("write user dir failed err=%d" % FileAccess.get_open_error())
		return
	var f := FileAccess.open(ext, FileAccess.WRITE)
	if f == null:
		load_log.append("write user ext failed err=%d" % FileAccess.get_open_error())
		return
	f.store_string(cfg)
	f.close()
	load_log.append("load user = %d (%s)" % [GDExtensionManager.load_extension(ext), ProjectSettings.globalize_path(dll_u)])
	load_log.append("loaded=%s" % loaded())


static func _write(path: String, data: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.close()
	return true


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


static func pf_code() -> String:
	match OS.get_name():
		"Windows": return "w"
		"macOS": return "m"
		"iOS": return "i"
		"Android": return "a"
	return "l"


## "w|닉네임" → ["닉네임", "windows"]. 예전 형식(플랫폼 이름만)은 플랫폼 없이 그 글을 이름으로.
static func split_name(raw: String) -> Array:
	if raw.length() >= 2 and raw[1] == "|" and PF.has(raw[0]):
		return [raw.substr(2), PF[raw[0]]]
	return [raw, ""]


static func clean_code(t: String) -> String:
	var out := ""
	for ch in t.to_upper():
		if ch in CODE_CHARS:
			out += ch
	return out.substr(0, 6)


func check_status() -> void:
	if url() == "" or _sw_req == null or _sw_req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_sw_req.request(url().trim_suffix("/") + "/status?v=" + Net.game_version().uri_encode())


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
	var full := "%s/ws?%s&v=%s&name=%s" % [base, q, Net.game_version().uri_encode(), (pf_code() + "|" + my_name.left(12)).uri_encode()]
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
	diag_sent.clear()
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
	# 확장 읽기는 시작 화면을 만들 때(오류 로그가 켜지기 전) 일어나서 여기서 남긴다
	if not load_log.is_empty():
		var msg := "MP webrtc 확장 " + ("읽음: " if loaded() else "못 읽음: ") + " | ".join(load_log)
		if loaded():
			print(msg)
		else:
			printerr(msg)
	_sw_req = HTTPRequest.new()
	_sw_req.timeout = 6.0
	add_child(_sw_req)
	_sw_req.request_completed.connect(func(res: int, code: int, _h, body: PackedByteArray):
		if res != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var j: Variant = JSON.parse_string(body.get_string_from_utf8())
		if j is Dictionary:
			sw_on = j.get("on", true) != false
			sw_hide = not sw_on and j.get("hide", false) == true
			sw_msg = str(j.get("msg", ""))
			status_changed.emit())
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
			_diag(1)
			_fail("호스트와 연결하지 못했습니다 (네트워크가 막혀 있을 수 있음)")
	if is_host():
		var now := Time.get_ticks_msec()
		for id in peers:
			var p: Dictionary = peers[id]
			if id != 1 and not p["ok"] and p.get("conn") and now - int(p.get("t", now)) > WAIT_JOIN * 1000.0 and not diag_sent.has(id):
				_diag(id)
				peers_changed.emit()  # "연결 중…" → "연결 안 됨"


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
					var nm := split_name(str(p.get("name", "")))
					peers[int(p["id"])] = {"name": nm[0], "pf": nm[1], "conn": null, "ok": false}
			peers[my_id] = {"name": my_name, "pf": PF[pf_code()], "conn": null, "ok": true}
			if my_id != 1:
				_make_conn(1)  # 호스트가 offer를 보낸다
				join_wait = WAIT_JOIN
			room_ready.emit()
			peers_changed.emit()
		"join":
			var id := int(j.get("id", 0))
			if id > 1:
				var nm := split_name(str(j.get("name", "")))
				peers[id] = {"name": nm[0], "pf": nm[1], "conn": null, "ok": false}
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
			if str(j.get("code", "")) == "off":
				sw_on = false
				sw_msg = str(j.get("msg", ""))
				status_changed.emit()
			var why := {"off": "멀티플레이를 잠시 쉬고 있어요" + (": " + sw_msg if sw_msg != "" else ""), "nocode": "없는 방 코드입니다", "full": "방이 가득 찼습니다 (최대 %d명)" % MAX_PLAYERS,
				"version": "호스트와 게임 버전이 다릅니다 (호스트 %s)" % str(j.get("host_v", "?")), "started": "이미 시작한 방입니다"}
			_fail(why.get(str(j.get("code", "")), "방에 들어가지 못했습니다"))


func _make_conn(id: int) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	var err := c.initialize({"iceServers": ice})
	if err != OK:
		printerr("MP initialize 실패 err=%d ice=%s" % [err, _ice_summary()])
	c.session_description_created.connect(func(type: String, sdp: String):
		c.set_local_description(type, sdp)
		_send_ws({"t": "sig", "to": id, "d": {"k": "sdp", "type": type, "sdp": sdp}}))
	c.ice_candidate_created.connect(func(mid: String, idx: int, cand: String):
		_count_cand(id, "lc", cand)
		_send_ws({"t": "sig", "to": id, "d": {"k": "ice", "mid": mid, "idx": idx, "cand": cand}}))
	rtc.add_peer(c, id)
	if peers.has(id):
		peers[id]["conn"] = c
	else:
		peers[id] = {"name": "", "pf": "", "conn": c, "ok": false}
	peers[id]["t"] = Time.get_ticks_msec()
	peers[id]["lc"] = {}
	peers[id]["rc"] = {}
	return c


func _on_rtc_signal(from: int, d: Variant) -> void:
	if not d is Dictionary or not peers.has(from) or peers[from]["conn"] == null:
		return
	var c: WebRTCPeerConnection = peers[from]["conn"]
	match str(d.get("k", "")):
		"sdp":
			c.set_remote_description(str(d.get("type", "")), str(d.get("sdp", "")))
		"ice":
			_count_cand(from, "rc", str(d.get("cand", "")))
			c.add_ice_candidate(str(d.get("mid", "")), int(d.get("idx", 0)), str(d.get("cand", "")))


## 후보 종류(host 같은 망·srflx 공인 주소·relay TURN 중계) 수. 연결 실패 진단용.
func _count_cand(id: int, key: String, cand: String) -> void:
	if not peers.has(id) or not peers[id].has(key):
		return
	var i := cand.find(" typ ")
	var typ := cand.substr(i + 5).get_slice(" ", 0) if i >= 0 else "?"
	var m: Dictionary = peers[id][key]
	m[typ] = int(m.get(typ, 0)) + 1


func _ice_summary() -> String:
	var out := PackedStringArray()
	for s in ice:
		if s is Dictionary:
			var u: Variant = s.get("urls", [])
			for x in (u if u is Array else [u]):
				out.append(str(x).get_slice("?", 0) + ("+cred" if s.has("credential") else ""))
	return ",".join(out)


## 연결 실패 진단 한 줄. printerr라 오류 로그(ErrLog → 서버 /v1/logs)로 모인다.
## 지문이 줄마다라 같은 줄은 처음 글만 남으니, 종류별로 줄을 나눈다.
func _diag(id: int) -> void:
	diag_sent[id] = true
	var p: Dictionary = peers.get(id, {})
	var c: WebRTCPeerConnection = p.get("conn")
	var cs := c.get_connection_state() if c else -1
	var gs := c.get_gathering_state() if c else -1
	var ss := c.get_signaling_state() if c else -1
	var line := "role=%s peer=%s conn=%d gather=%d signal=%d local=%s remote=%s ice=%s ws=%d" % [
		"host" if is_host() else "join", p.get("pf", "?"), cs, gs, ss, JSON.stringify(p.get("lc", {})),
		JSON.stringify(p.get("rc", {})), _ice_summary(), ws.get_ready_state()]
	_send_ws({"t": "log", "msg": line})  # 중개 Worker 로그에도 (방 코드로 양쪽을 맞춰 볼 수 있게)
	if p.get("rc", {}).is_empty():
		printerr("MP 연결 실패: 상대 후보를 못 받음 " + line)
	elif not p.get("lc", {}).has("relay"):
		printerr("MP 연결 실패: TURN 중계 후보 없음 " + line)
	else:
		printerr("MP 연결 실패: 후보는 주고받음 " + line)


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
	return ids.map(func(id): return [id, peers[id]["name"], peers[id]["ok"], peers[id].get("pf", ""), diag_sent.has(id)])


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
