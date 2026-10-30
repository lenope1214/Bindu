extends SceneTree
# 속성별 기여: 직선탄 오브젝트 하나(속성 Lv2) 앞을 지나가는 구체 줄기에 30초간 준 피해와 통과 시간
var main
func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var lv := int(OS.get_environment("LV")) if OS.get_environment("LV") != "" else 2
	var pat := OS.get_environment("PAT") if OS.get_environment("PAT") != "" else "shot"
	var combos = [[]]
	for e in Elem.ALL: combos.append([e])
	for els in combos:
		var dsum := 0.0
		var tsum := 0.0
		for rep in 2:
			for c in main.towers.get_children(): c.free()
			for c in main.orbs.get_children(): c.free()
			for c in main.zones.get_children(): c.free()
			for c in main.projectiles.get_children(): c.free()
			main.wave = 5
			main.phase = main.Phase.WAVE
			main.wave_active = true
			main.to_spawn = 0
			main.core_hp = 999
			var tp = main.center() + Vector2(-420, 0)
			# 속성 없는 비교용: 금속 Lv1을 넣고 부가효과 없이 보려면 따로 — 여기서는 빈 목록이면 불 Lv1 대신 직선탄만
			main.picked = {"e": els[0] if els.size() > 0 else Elem.METAL, "lv": lv}
			main._place_tower(tp, Vector2.RIGHT)
			var t = main.towers.get_child(0)
			if pat != "shot": t.set_pattern(pat)
			var orbs := []
			var spawn_t := 0.0
			var travel := 0.0
			var crossed := 0
			var dealt := 0.0
			for f in 60 * 30:
				spawn_t -= 1.0 / 60
				if spawn_t <= 0:
					spawn_t = 1.0
					var o = Orb.new(); o.main = main
					o.position = tp + Vector2(160, -330); o.target = tp + Vector2(160, 2000)
					o.setup(Orb.Kind.NORMAL, 100000, 50)
					o.set_meta("born", f)
					main.orbs.add_child(o); orbs.append(o)
				await process_frame
				for o in orbs.duplicate():
					if not is_instance_valid(o): orbs.erase(o); continue
					if o.position.y > tp.y + 330:
						crossed += 1
						travel += (f - o.get_meta("born")) / 60.0
						dealt += 100000 - o.hp
						orbs.erase(o); o.queue_free()
			for o in orbs:
				if is_instance_valid(o): dealt += 100000 - o.hp
			dsum += dealt / 30.0
			tsum += travel / maxf(crossed, 1)
		var name: String = Elem.NAMES[els[0]] if els.size() > 0 else "(금속 기준)"
		print("ELEM %-8s dmg/s=%6.2f  cross=%.2fs" % [name, dsum / 2.0, tsum / 2.0])
	quit()
