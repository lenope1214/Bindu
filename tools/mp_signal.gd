extends SceneTree
## 멀티플레이 중개 서버(server/mp-worker)와 같은 약속으로 도는 로컬 시험용 서버.
## godot --headless -s tools/mp_signal.gd -- [포트=8790]
## 게임은 BINDU_MP_URL=http://127.0.0.1:8790 으로 붙는다. 중계(TURN)는 없고 STUN도 쓰지 않는다(같은 기기라 필요 없음).

const MAX := 4
var tcp := TCPServer.new()
var pending: Array = []  # 업그레이드 중인 WebSocketPeer
var socks: Array = []  # [{ws, room, id, name}]
var rooms := {}  # code -> {mode, v, next, locked, members: {id: sock}}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var port := int(args[0]) if args.size() > 0 else 8790
	if tcp.listen(port, "127.0.0.1") != OK:
		print("MPSIG listen failed")
		quit(1)
		return
	print("MPSIG listening %d" % port)


func _process(_d: float) -> bool:
	while tcp.is_connection_available():
		var w := WebSocketPeer.new()
		w.accept_stream(tcp.take_connection())
		pending.append(w)
	for w in pending.duplicate():
		w.poll()
		if w.get_ready_state() == WebSocketPeer.STATE_OPEN:
			pending.erase(w)
			_open(w)
		elif w.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			pending.erase(w)
	for s in socks.duplicate():
		var w: WebSocketPeer = s["ws"]
		w.poll()
		while w.get_available_packet_count() > 0:
			var j: Variant = JSON.parse_string(w.get_packet().get_string_from_utf8())
			if j is Dictionary:
				_msg(s, j)
		if w.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_close(s)
	return false


func _q(path: String) -> Dictionary:
	var out := {}
	var i := path.find("?")
	if i < 0:
		return out
	for kv in path.substr(i + 1).split("&"):
		var p := kv.split("=")
		if p.size() == 2:
			out[p[0]] = p[1].uri_decode()
	return out


func _send(s: Dictionary, d: Dictionary) -> void:
	s["ws"].send_text(JSON.stringify(d))


func _open(w: WebSocketPeer) -> void:
	var q := _q(w.get_requested_url())
	var s := {"ws": w, "room": "", "id": 0, "name": str(q.get("name", ""))}
	socks.append(s)
	var code := ""
	if q.get("op") == "host":
		code = ""
		while code == "" or rooms.has(code):
			code = ""
			for i in 6:
				code += Mp.CODE_CHARS[randi() % Mp.CODE_CHARS.length()]
		rooms[code] = {"mode": q.get("mode", "vs"), "v": q.get("v", ""), "next": 1, "locked": false, "members": {}}
	else:
		code = str(q.get("code", ""))
		if not rooms.has(code):
			_send(s, {"t": "err", "code": "nocode"})
			w.close()
			return
		var r: Dictionary = rooms[code]
		if r["v"] != q.get("v", ""):
			_send(s, {"t": "err", "code": "version", "host_v": r["v"]})
			w.close()
			return
		if r["locked"]:
			_send(s, {"t": "err", "code": "started"})
			w.close()
			return
		if r["members"].size() >= MAX:
			_send(s, {"t": "err", "code": "full"})
			w.close()
			return
	var room: Dictionary = rooms[code]
	s["room"] = code
	s["id"] = room["next"]
	room["next"] += 1
	var list: Array = []
	for id in room["members"]:
		list.append({"id": id, "name": room["members"][id]["name"]})
		_send(room["members"][id], {"t": "join", "id": s["id"], "name": s["name"]})
	room["members"][s["id"]] = s
	_send(s, {"t": "room", "code": code, "id": s["id"], "mode": room["mode"], "ice": [], "peers": list})


func _msg(s: Dictionary, j: Dictionary) -> void:
	if not rooms.has(s["room"]):
		return
	var room: Dictionary = rooms[s["room"]]
	match str(j.get("t", "")):
		"sig":
			var to := int(j.get("to", 0))
			if room["members"].has(to):
				_send(room["members"][to], {"t": "sig", "from": s["id"], "d": j.get("d", {})})
		"lock":
			if s["id"] == 1:
				room["locked"] = true


func _close(s: Dictionary) -> void:
	socks.erase(s)
	if not rooms.has(s["room"]):
		return
	var room: Dictionary = rooms[s["room"]]
	room["members"].erase(s["id"])
	for id in room["members"]:
		_send(room["members"][id], {"t": "closed"} if s["id"] == 1 else {"t": "leave", "id": s["id"]})
	if s["id"] == 1:
		for id in room["members"]:
			room["members"][id]["ws"].close()
		rooms.erase(s["room"])
