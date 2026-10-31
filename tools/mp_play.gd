extends "res://tools/bot.gd"
## 멀티플레이 자동 판: 두(이상) 프로세스가 로컬 중개 서버로 방을 만들고 들어가 봇으로 판을 한다.
## 환경 변수: BINDU_MP_URL(중개 서버) MP_ROLE=host|join MP_MODE=vs|coop MP_FILE(방 코드를 주고받는 파일) MP_WAVES(이 웨이브에서 끝, 기본 8)
##   MP_IDLE=<역할>(그 역할은 판이 시작되면 아무것도 안 함: 잠수 처리 시험)
## 끊김 시험: MP_BLIP_AT=N 참가자가 웨이브 N에서 연결을 끊음 (협동은 같은 판에 다시 붙음, 대결은 패배),
##   MP_DROP_AT=N 참가자 프로세스가 웨이브 N에서 꺼짐 → MP_REJOIN=1로 새로 띄운 참가자가 같은 코드로 들어와 이어 함.
## 출력: 웨이브마다 "MPW 역할 w=.. lanes=.. n=.. res=.. boss=.."(대결은 역할끼리 같아야 함),
##       끝에 "MPPLAY 역할 mode=.. wave=.. score=.. towers=.. mine=.. ghosts=.."

var role := ""
var mmode := ""
var mfile := ""
var started := false
var tried := false
var tt := 0.0
var max_w := 8
var seen_w := -1
var placed := 0
var blipped := false


func _initialize():
	super()
	role = OS.get_environment("MP_ROLE")
	mmode = OS.get_environment("MP_MODE")
	mfile = OS.get_environment("MP_FILE")
	if OS.get_environment("MP_WAVES") != "":
		max_w = int(OS.get_environment("MP_WAVES"))


func _process(d):
	tt += d
	if Time.get_ticks_msec() > 600000:
		print("MPPLAY FAIL timeout ", role)
		quit(1)
		return true
	if not started:
		if not tried and main.mp != null:
			tried = true
			if role == "host":
				main.mp.room_ready.connect(func():
					var f := FileAccess.open(mfile, FileAccess.WRITE)
					f.store_string(main.mp.code)
					f.close())
				main.mp.host(mmode, "봇H")
			else:
				var code := ""
				for i in 50:
					code = FileAccess.get_file_as_string(mfile) if FileAccess.file_exists(mfile) else ""
					if code.length() == 6:
						break
					OS.delay_msec(200)
				main.mp.join(code, "봇" + role)
		if role == "host" and main.mp.connected_ids().size() >= int(OS.get_environment("MP_N") if OS.get_environment("MP_N") != "" else "1") and main.mp_mode == "":
			main._mp_start()
		if Engine.get_process_frames() % 300 == 0:
			print("MPPLAY wait ", role, " code=", main.mp.code, " id=", main.mp.my_id, " peers=", main.mp.names())
		if main.mp_mode != "":
			started = true
			print("MPPLAY started ", role, " id=", main.mp.my_id, " mode=", main.mp_mode)
		return false
	if role != "host" and main.mp_mode != "":
		var blip := int(OS.get_environment("MP_BLIP_AT")) if OS.get_environment("MP_BLIP_AT") != "" else -1
		var drop := int(OS.get_environment("MP_DROP_AT")) if OS.get_environment("MP_DROP_AT") != "" else -1
		if not blipped and blip > 0 and main.wave >= blip:
			blipped = true
			print("MPBLIP ", role, " w=", main.wave)
			main.mp._fail("시험 끊김")
		if drop > 0 and main.wave >= drop:
			print("MPDROP ", role, " w=", main.wave)
			quit(0)
			return true
	if main.phase == 3 and main.wave != seen_w:
		seen_w = main.wave
		print("MPW %s w=%d lanes=%s n=%d res=%d extra=%d ghosts=%d towers=%d" % [role, main.wave, main.lanes.map(func(a): return snappedf(a, 0.001)), main.to_spawn + main.mp_extra_left, main.wave_resist, main.mp_extra_left, main.mp_ghosts.size(), main.towers.get_child_count()])
		var by := {}
		for t in main.towers.get_children():
			by[t.owner_id] = by.get(t.owner_id, 0) + int(t.run_dealt)
		print("MPDEALT %s %s core=%d" % [role, JSON.stringify(by), main.core_hp])
	if main.wave >= max_w or main.phase == 4:
		var mine: int = main._my_towers().size()
		print("MPAFK %s afk=%s afk_n=%d" % [role, main.mp_afk, main.mp_afk_n])
		print("MPPLAY %s mode=%s wave=%d score=%d core=%d towers=%d mine=%d ghosts=%d others=%s" % [role, main.mp_mode, main.wave, main.score, main.core_hp, main.towers.get_child_count(), mine, main.orbs.get_child_count(), JSON.stringify(main.mp_others)])
		return true
	if OS.get_environment("MP_IDLE") == role:
		return false  # 잠수 시험: 이 역할은 아무것도 안 함 (기다림·대신 고르기·자리 비움이 돌아야 함)
	if main.mp_mode == "coop":
		return _coop_bot()
	return super(d)


## 협동: 내 오브젝트에만 넣는 단순한 봇 (기본 봇은 모든 오브젝트를 건드려서).
func _coop_bot() -> bool:
	main.auto_start = false
	main.game_speed = float(OS.get_environment("SPEED")) if OS.get_environment("SPEED") != "" else 1.0
	if main.phase == 7:
		main._cancel_step()
	if main.phase == 6:
		main._start_wave()
		return false
	if main.perk_mode:
		main._on_perk(main.perk_offer[randi() % main.perk_offer.size()])
		return false
	if main.phase != 0 or main.offer.is_empty() or main.lanes.is_empty():
		return false
	var mine: Array = main._my_towers()
	var pick = null
	var target = null
	for o in main.offer:
		if o["type"] == "elem" and (mine.size() < 3 or randf() < 0.5):
			pick = o
			break
		if o["type"] in ["pat", "mod", "trig", "link"]:
			for t in mine:
				if t.can_take(o):
					pick = o
					target = t
					break
		if pick:
			break
	if pick == null:
		for o in main.offer:
			if o["type"] == "elem":
				pick = o
				break
	if pick == null:
		main.picks_left = 1
		main._after_place()
		return false
	main._on_pick(pick)
	if pick["type"] != "elem":
		main._apply_card(target)
		return false
	# 진입 방향마다 돌아가며, 사람마다 다른 쪽에 놓는다
	placed += 1
	var la: float = main.lanes[placed % main.lanes.size()]
	var ld := Vector2.from_angle(la)
	var side := 1.0 if main.mp.my_id % 2 == 0 else -1.0
	var p: Vector2 = main.core() + ld * (90.0 + 30.0 * (placed % 4)) + ld.orthogonal() * 26.0 * side
	main._place_tower(p, ld)
	main._after_place()
	return false
