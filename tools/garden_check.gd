extends SceneTree
## 정원 모드 점검: 저장·이어하기, 꺼 둔 동안 보상, 물러남, 환생·씨앗, 씨앗 나무 사기, 일반 판 시작 보너스·기록 키.
## 사용: godot --headless --path . -s tools/garden_check.gd  (실패가 있으면 끝 코드 1)
var main
var fails := 0
var step := 0
var f := 0
var snap := {}


func _ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _initialize():
	for p in [Garden.RUN_PATH, "user://run.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	Garden.on = true
	_spawn()


func _spawn() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _towers_sig() -> Array:
	var a := []
	for t in main.towers.get_children():
		a.append([t.elements.duplicate(), t.pattern, t.total_level(), snappedf(t.position.x, 1.0)])
	a.sort()
	return a


func _process(_d) -> bool:
	f += 1
	if step == 2 and main != null and is_instance_valid(main):
		main.core_hp = main.core_max  # 웨이브 끝까지 (물러남은 따로 본다)
	if f % 5 != 0:
		return false
	match step:
		0:
			_ok(Garden.on and main.phase == 0 and main.wave == 0, "정원으로 시작: 쉬는 시간 웨이브 0")
			_ok(main.offer.size() == Garden.SHOP_ELEMS, "첫 상점은 속성 카드 %d장 (오브젝트가 없으면 다른 카드 없음)" % Garden.SHOP_ELEMS)
			_ok(is_equal_approx(Garden.dew, Garden.START_DEW), "시작 이슬 %d" % int(Garden.START_DEW))
			# 새 오브젝트 사기: 값만큼 줄어야
			var c := Garden.cost_new(0)
			main._on_pick(main.offer[0])
			main.place_pos = main.core() + Vector2(120, 0)
			Input.warp_mouse(main.place_pos + Vector2(100, 0))
			main._confirm_aim()
			_ok(main.towers.get_child_count() == 1, "새 오브젝트를 놓음")
			_ok(is_equal_approx(Garden.dew, Garden.START_DEW - c), "새 오브젝트 값 %d만큼 이슬이 줆" % c)
			# 모자라면 못 산다
			Garden.dew = 1.0
			_ok(not main._garden_pay(Garden.cost_new(1)), "이슬이 모자라면 못 삼")
			_ok(is_equal_approx(Garden.dew, 1.0), "못 사면 이슬 그대로")
			Garden.dew = 5000.0
			main.wave = 1
			main._garden_rest(true)
			print("  상점: ", main.offer.map(func(o): return o["type"]), " phase=", main.phase)
			_ok(main.offer.size() == Garden.SHOP_ELEMS + Garden.SHOP_OTHERS, "오브젝트가 있으면 상점 4장")
			step = 1
		1:
			# 웨이브 진행: 처치하면 이슬
			# 길목마다 하나씩 (처치가 나오게)
			for a in main.lanes:
				main.picked = {"type": "elem", "e": Elem.FIRE, "lv": 1}
				main._place_tower(main.core() + Vector2.from_angle(a) * 140.0, Vector2.from_angle(a))
			main.wave = 3
			var d0 := Garden.dew
			main._start_wave()
			print("  웨이브 시작 phase=", main.phase, " wave=", main.wave)
			main.game_speed = 8.0
			snap["d0"] = d0
			step = 2
		2:
			if main.phase == 0:
				print("  웨이브 끝 wave=", main.wave, " hp=", main.core_hp, " walls=", Garden.walls)
				_ok(main.wave == 4 and Garden.walls.is_empty(), "웨이브가 끝나면 다음 쉬는 시간 (웨이브 4)")
				_ok(Garden.dew > float(snap["d0"]), "처치로 이슬이 늘어남 (%d → %d)" % [int(snap["d0"]), int(Garden.dew)])
				_ok(Garden.best >= 4, "이번 정원 최고 웨이브 갱신")
				_ok(Garden.rate > 0.0, "이슬 속도 기록 (꺼 둔 동안 보상용)")
				step = 3
		3:
			# 물러남
			main._start_wave()
			main.core_hp = 0
			step = 4
		4:
			if main.phase == 0:
				_ok(main.wave == 0 and Garden.walls.get("5", 0) == 1, "웨이브 5에서 무너지면 %d웨이브 물러남, 0 아래로는 안 감 (웨이브 %d)" % [Garden.RETREAT, main.wave])
				_ok(main.core_hp == main.core_max, "물러나면 중앙 체력 회복")
				_ok(main.offer.any(func(o): return o["type"] != "elem"), "웨이브 0으로 물러나도 상점에 속성 말고 다른 카드")
				_ok(Garden.on and main.phase != 4, "판이 끝나지 않음")
				# 저장 → 다시 열기
				main._save_run()
				snap = {"wave": main.wave, "dew": Garden.dew, "t": _towers_sig(), "best": Garden.best}
				main.queue_free()
				step = 5
		5:
			_spawn()
			step = 6
		6:
			_ok(main.wave == int(snap["wave"]), "이어하기: 웨이브 같음")
			_ok(absf(Garden.dew - float(snap["dew"])) < 1.0, "이어하기: 이슬 같음 (1분 안이라 보상 없음)")
			_ok(_towers_sig() == snap["t"], "이어하기: 오브젝트 같음")
			_ok(Garden.best == int(snap["best"]), "이어하기: 최고 웨이브 같음")
			# 꺼 둔 동안 보상: 2시간 전에 저장한 것으로
			var cf := ConfigFile.new()
			cf.load(Garden.RUN_PATH)
			Garden.saved_at = int(Time.get_unix_time_from_system()) - 7200
			Garden.rate = 2.0
			var g: Array = Garden.offline_gain()
			_ok(absf(g[0] - 2.0 * 7200.0 * Garden.OFFLINE_RATE) < 5.0, "꺼 둔 2시간: 이슬 속도 x 50%% (%d)" % int(g[0]))
			Garden.saved_at = int(Time.get_unix_time_from_system()) - 20 * 3600
			g = Garden.offline_gain()
			_ok(absf(g[1] - Garden.OFFLINE_MAX) < 1.0, "꺼 둔 20시간: 8시간치까지만")
			Garden.saved_at = int(Time.get_unix_time_from_system()) - 30
			_ok(Garden.offline_gain()[0] == 0.0, "1분 안이면 보상 없음")
			# 환생
			Garden.best = 31
			Garden.seeds = 0
			var s0 := Garden.seeds_total
			main._rebirth()
			_ok(Garden.seeds == 0, "환생은 두 번 눌러야 (한 번이면 그대로)")
			main._rebirth()
			snap = {"s0": s0}
			step = 7
		7:
			main = current_scene
			if main == null:
				return false
			_ok(Garden.seeds == 11 and Garden.seeds_total == int(snap["s0"]) + 11, "환생: 최고 31 → 씨앗 +11")
			_ok(Garden.rebirths == 1, "환생 횟수 1")
			_ok(main.wave == 0 and main.towers.get_child_count() == 0, "환생하면 정원을 처음부터")
			_ok(is_equal_approx(Garden.dew, Garden.start_dew()), "환생 뒤 시작 이슬 %d" % int(Garden.start_dew()))
			_ok(Garden.kill_dew(10, false) > Garden.k("dew_kill", 8.0) * pow(1.05, 10) * 1.05, "환생하면 처치 이슬 +10%")
			# 씨앗 나무
			Garden.seeds = 30
			_ok(Garden.buy("root") and Garden.lv("root") == 1 and Garden.seeds == 27, "뿌리 1단계 사기 (씨앗 3)")
			_ok(Garden.buy("leaf") and Garden.lv("leaf") == 1 and Garden.seeds == 17, "잎 1단계 사기 (씨앗 10)")
			_ok(not Garden.buy("fruit") and Garden.seeds == 17, "씨앗이 모자라면 못 삼")
			Garden.mastery["fire"] = 6000.0
			_ok(Garden.mastery_lv(Elem.FIRE) == 2, "불 숙련 6000 → 2단계")
			# 일반 판으로
			main._leave(false)
			step = 8
		8:
			main = current_scene
			if main == null or Garden.on:
				return false
			_ok(Meta.map_id == Garden.prev.get("map", Meta.map_id), "정원에서 나가면 맵 원래대로")
			main._close_title()
			step = 9
		9:
			main = current_scene
			if main == null or main.title_label.visible:
				return false
			_ok(Garden.boosted, "씨앗 나무를 켜 두면 일반 판에 적용")
			_ok(main.core_max == 10 + 1, "뿌리 1: 중앙 체력 +1 (%d)" % main.core_max)
			_ok(Meta.run_key().ends_with(Garden.GROW_TAG), "기록 키에 ~grow (성장)")
			Garden.tree_on = false
			_ok(not Garden.want_boost(), "끄면 다음 판은 순수")
			print("RESULT fails=", fails)
			quit(1 if fails > 0 else 0)
	return false
