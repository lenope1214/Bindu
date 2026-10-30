extends SceneTree
# 특수 반응별 기여: 두 속성 Lv1 직선탄 오브젝트 하나 앞을 지나가는 구체 무리(초당 3개, 폭 ±50)에
# 30초간 준 반응 피해/초(rx)와 전체 피해/초(all). 구체는 죽지 않아 처치로 터지는 효과(저주·혼불 일부)는 빠진다.
# SOLO=1: 반응 대신 속성 하나(Lv2)씩 같은 무리에 (무리에서 강해지는 소리 울림 등 비교)
var main
func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var only := OS.get_environment("RX")
	var list: Array = Elem.REACTIONS
	if OS.get_environment("SOLO") == "1":
		list = []
		for e in Elem.ALL:
			list.append({"id": "solo", "a": e, "b": e, "name": Elem.NAMES[e]})
	for r in list:
		if only != "" and not r["id"] in only.split(","):
			continue
		var rx := 0.0
		var all := 0.0
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
			main.core_hp = 999
			var tp = main.center() + Vector2(-420, 0)
			main.picked = {"e": r["a"], "lv": 1}
			main._place_tower(tp, Vector2.RIGHT)
			var t = main.towers.get_child(0)
			t.add(r["b"], 1)  # SOLO면 같은 속성 Lv2
			var spawn_t := 0.0
			for f in 60 * 30:
				spawn_t -= 1.0 / 60
				if spawn_t <= 0:
					spawn_t = 1.0 / 3.0
					var o = Orb.new(); o.main = main
					var x := randf_range(-50, 50)
					o.position = tp + Vector2(160 + x, -330); o.target = tp + Vector2(160 + x, 2000)
					o.setup(Orb.Kind.NORMAL, 100000, 50)
					main.orbs.add_child(o)
				await process_frame
				for o in main.orbs.get_children():
					if o.position.y > tp.y + 330:
						o.queue_free()
			rx += t.rx_dealt / 30.0
			all += t.dealt / 30.0
		print("RX %-6s %-14s rx/s=%6.2f  all/s=%6.2f" % [r["name"], r["id"], rx / 2.0, all / 2.0])
	quit()
