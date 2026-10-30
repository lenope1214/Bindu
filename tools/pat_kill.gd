extends SceneTree
# 공격방식별 처치율: 중앙 왼쪽 150에서 바깥을 겨눈 오브젝트 하나(속성 ELEM Lv1, 공격방식 Lv PLV) 앞으로
# 체력 HP(기본 30)인 구체가 초당 RATE(기본 1)개씩 60초간 중앙을 향해 온다. lane: 곧게, spiral: 소용돌이처럼 비껴 돎.
# 처치한 비율(%)을 본다. PAT=lob,shot 으로 골라 보기.
var main
func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var only := OS.get_environment("PAT")
	var e := int(OS.get_environment("ELEM")) if OS.get_environment("ELEM") != "" else Elem.FIRE
	var plv := int(OS.get_environment("PLV")) if OS.get_environment("PLV") != "" else 1
	var hp := float(OS.get_environment("HP")) if OS.get_environment("HP") != "" else 30.0
	var rate := float(OS.get_environment("RATE")) if OS.get_environment("RATE") != "" else 1.0
	for p in Pat.PATTERN_IDS:
		if only != "" and not p in only.split(","):
			continue
		var res := []
		for sc in ["lane", "spiral"]:
			var killed := 0
			var total := 0
			for rep in 2:
				for c in main.towers.get_children(): c.free()
				for c in main.orbs.get_children(): c.free()
				for c in main.zones.get_children(): c.free()
				for c in main.projectiles.get_children(): c.free()
				main.wave = 5
				main.phase = main.Phase.WAVE
				main.wave_active = true
				main.wave_time = 10.0
				main.to_spawn = 0
				main.core_hp = 99999
				var c0: Vector2 = main.center()
				main.picked = {"e": e, "lv": 1}
				main._place_tower(c0 + Vector2(-150, 0), Vector2.LEFT)
				var t = main.towers.get_child(0)
				for i in plv:
					t.set_pattern(p)
				var live := {}
				var spawn_t := 0.0
				for f in 60 * 60:
					spawn_t -= 1.0 / 60
					if spawn_t <= 0 and f < 60 * 50:
						spawn_t = 1.0 / rate
						var o = Orb.new(); o.main = main
						var a := PI + randf_range(-0.12, 0.12) + (0.6 if sc == "spiral" else 0.0)
						o.position = c0 + Vector2.from_angle(a) * 620.0; o.target = c0
						if sc == "spiral":
							o.swirl = main.SPIRAL_SWIRL
						o.setup(Orb.Kind.NORMAL, hp, 50)
						main.orbs.add_child(o)
						live[o] = 999.0
						total += 1
					await process_frame
					for o in live.keys():
						if is_instance_valid(o) and not o.is_queued_for_deletion():
							live[o] = o.position.distance_to(c0)
							if live[o] < 40.0:
								live.erase(o); o.queue_free()  # 중앙에 닿음
						else:
							if live[o] >= 40.0:
								killed += 1
							live.erase(o)
			res.append(100.0 * killed / maxf(total, 1))
		print("KILL %-8s Lv%d lane=%5.1f%%  spiral=%5.1f%%" % [p, plv, res[0], res[1]])
	quit()
