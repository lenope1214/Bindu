extends SceneTree
## 계정·진행 맞추기 점검 (로컬 서버 필요, 창이 있는 실행이어야 Net이 켜진다 — xvfb):
##   uvicorn(AUTH_TEST_PROVIDER=1) 을 띄우고, SERVER_URL을 그 주소로 바꾼 사본 두 개(기기 A·B, config/name이 달라 user:// 폴더가 다름)에서
##   godot --path <A> -s tools/sync_check.gd -- a1   → A 진행 올리기, 소셜(시험용) 연결, 진행 중 판 올리기
##   godot --path <B> -s tools/sync_check.gd -- b    → B 진행 올리고 같은 소셜 연결(계정 합침), 합친 진행 확인, A의 판 가져오기
##   godot --path <A> -s tools/sync_check.gd -- a2   → A가 B 진행을 받고, 가져가진 판은 run_moved
## 마지막 줄 SYNC OK / SYNC FAIL.

var net: Net
var fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://best.cfg") == OK:
		Meta.load_into(cfg)
	if Meta.device_id == "":
		Meta.device_id = Crypto.new().generate_random_bytes(16).hex_encode()


func _save() -> void:
	var cfg := ConfigFile.new()
	Meta.save_into(cfg)
	cfg.save("user://best.cfg")


func _sync() -> void:
	net.sync()
	await net.progress_synced
	_save()


func _link(sub: String) -> Dictionary:
	var r := await net._authed(HTTPClient.METHOD_POST, "/v1/auth/link", JSON.stringify({"provider": "test", "credential": sub}))
	if r["code"] == 200:
		Account.take(r["data"])
	return r["data"] if r["data"] is Dictionary else {}


func _run() -> void:
	var role: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "a1"
	_load()
	net = Net.new()
	root.add_child(net)
	if not Net.info.get("acct", false):
		await net.booted
	_check("서버가 계정 API를 알림", Net.acct_ok())
	match role:
		"a1":
			Meta.achieved = {"first": true, "wave10": true, "wave15": true}
			Meta.tally = {"pick:elem:fire": 3, "max:wave": 12}
			Meta.title = "wave15"
			Meta.map_best = {"plain@v1r2": [10, 3000]}
			Meta.total_kills = 100
			Meta.games = 3
			Meta.tower_skin = "hex"
			Meta.favs = {"elem:불": true}
			Meta.nickname = "피시"
			_save()
			await _sync()
			_check("토큰 받음", Account.has_token() and Account.id != "")
			var l := await _link("g-sync")
			_check("소셜 연결", l.get("linked", []) == ["test"])
			net.put_run("run-sync-1", "[run]\nformat=99\nwave=7\n", {"game": Net.game_version(), "platform": "linux", "map": "line", "rules": 1, "wave": 7, "score": 1234})
			await create_timer(1.0).timeout
			print("ACCOUNT " + Account.id)
		"b":
			Meta.achieved = {"first": true, "boss": true}
			Meta.tally = {"pick:elem:fire": 1, "pick:pat:spray": 2, "max:wave": 20}
			Meta.codex = {"steam": true}
			Meta.map_best = {"plain@v1r2": [12, 2500]}
			Meta.total_kills = 40
			Meta.games = 2
			_save()
			await _sync()
			var before := Account.id
			var l := await _link("g-sync")
			_check("같은 소셜: 계정 합침", l.get("merged", false) and Account.id != before)
			await _sync()
			_check("업적 합집합", Meta.achieved.has("wave10") and Meta.achieved.has("boss"))
			_check("도감", Meta.codex.has("steam"))
			_check("최고 기록 키마다 큰 값", Meta.map_best["plain@v1r2"] == [12, 3000])
			_check("처치·판 수 합계", Meta.total_kills == 140 and Meta.games == 5)
			_check("선호 표시·닉네임", Meta.favs.has("elem:불") and Meta.nickname == "피시")
			_check("수집 누적은 기기끼리 더함·최고값은 큰 값", Ach.picks("elem:fire") == 4 and Ach.picks("pat:spray") == 2 and Ach.total("max:wave") == 20)
			_check("칭호", Meta.title == "wave15")
			# 다시 맞춰도 늘지 않는다 (두 번 세지 않음)
			await _sync()
			_check("다시 맞춰도 그대로", Meta.total_kills == 140 and Meta.games == 5 and Ach.picks("elem:fire") == 4)
			net.list_runs()
			var list: Array = await net.runs_listed
			_check("A의 진행 중 판이 보임", list.size() == 1 and list[0]["run"] == "run-sync-1" and not list[0]["mine"] and int(list[0]["wave"]) == 7)
			net.claim_run("run-sync-1")
			var got: Dictionary = await net.run_claimed
			_check("판 가져오기", str(got.get("data", "")).contains("wave=7") and got.get("mine", false))
			Meta.total_kills += 10
			Meta.games += 1
			Meta.tower_skin = "circle"
			_save()
			await _sync()
		"a2":
			await _sync()
			_check("A가 B 진행을 받음", Meta.achieved.has("boss") and Meta.total_kills == 150 and Meta.games == 6)
			_check("나중에 바꾼 모양", Meta.tower_skin == "circle")
			_check("A가 B의 수집을 받음", Ach.picks("elem:fire") == 4 and Ach.picks("pat:spray") == 2 and int(Meta.tally["pick:elem:fire"]) == 3)
			var moved := [""]
			net.run_moved.connect(func(k): moved[0] = k)
			net.put_run("run-sync-1", "x", {"game": Net.game_version(), "platform": "linux", "map": "line", "rules": 1, "wave": 8, "score": 1})
			await create_timer(1.5).timeout
			_check("B가 가져간 판은 더 못 올림 (run_moved)", moved[0] == "run-sync-1")
			net.drop_run("run-sync-1")
			await create_timer(1.0).timeout
			_check("가져간 판은 지우지 않고 지울 목록에서 뺌", Account.drops.is_empty())
			net.list_runs()
			var list: Array = await net.runs_listed
			_check("판은 B에 남음", list.size() == 1 and not list[0]["mine"])
	print("SYNC " + ("OK" if fails == 0 else "FAIL %d" % fails))
	quit(0 if fails == 0 else 1)
