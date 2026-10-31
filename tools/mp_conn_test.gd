extends SceneTree
## 멀티플레이 연결 시험: 로컬 중개 서버(tools/mp_signal.gd)를 거쳐 WebRTC로 두 프로세스가 이어지는지.
## BINDU_MP_URL=http://127.0.0.1:8790 godot --headless -s tools/mp_conn_test.gd -- host <코드 파일>
## BINDU_MP_URL=http://127.0.0.1:8790 godot --headless -s tools/mp_conn_test.gd -- join <코드 파일>
## 둘 다 상대 메시지를 받고 핑을 재면 "MPCONN ok", 20초 안에 못 받으면 "MPCONN FAIL".

var mp: Mp
var role := ""
var file := ""
var t := 0.0
var got := false
var sent := false
var done_t := -1.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	role = a[0]
	file = a[1]
	mp = Mp.new()
	root.add_child(mp)
	mp.packet.connect(func(from: int, msg: Dictionary):
		if msg.get("t") == "hi":
			print("MPCONN got from %d: %s" % [from, msg.get("x")])
			got = true)
	mp.failed.connect(func(r): print("MPCONN failed: ", r))
	if not Mp.available():
		print("MPCONN FAIL webrtc unavailable")
		quit(1)
		return
	if role == "host":
		mp.room_ready.connect(func():
			var f := FileAccess.open(file, FileAccess.WRITE)
			f.store_string(mp.code)
			f.close()
			print("MPCONN room ", mp.code))
		mp.host("vs", "호스트")
	else:
		var code := ""
		while code == "" and t < 5.0:
			OS.delay_msec(200)
			t += 0.2
			code = FileAccess.get_file_as_string(file) if FileAccess.file_exists(file) else ""
		mp.join(code, "참가자")


func _process(d: float) -> bool:
	t += d
	if not sent and not mp.connected_ids().is_empty():
		sent = true
		mp.send({"t": "hi", "x": role})
	var other := 2 if role == "host" else 1
	if done_t >= 0.0 and t - done_t > (2.5 if role == "host" else 1.0):  # 상대도 핑을 잴 때까지 조금 더 이어 둔다
		quit(0)
	elif got and sent and mp.ping.has(other):  # 핑(Mp._send_pings)도 한 번은 재야
		if done_t < 0.0:
			print("MPCONN ok ", role, " ping=", mp.ping[other], "ms")
			done_t = t
	elif t > 20.0 and done_t < 0.0:
		print("MPCONN FAIL timeout ", role, " peers=", mp.names())
		quit(1)
	return false
