extends SceneTree
# 공격방식별 피해/초: 속성 하나(ELEM, 기본 불) Lv1 오브젝트에 공격방식 Lv(PLV, 기본 1) 하나를 넣고,
# 구체 무리(초당 3개, 죽지 않음)가 30초 지나갈 때 준 피해/초.
# cross: 앞 160에서 가로지름(폭 ±50). head: 정면 700에서 오브젝트 쪽으로 걸어옴(폭 ±30, 중앙 반대쪽을 겨눔).
# PAT=lob,shot 으로 골라 보기.
var main
func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var only := OS.get_environment("PAT")
	var e := int(OS.get_environment("ELEM")) if OS.get_environment("ELEM") != "" else Elem.FIRE
	var plv := int(OS.get_environment("PLV")) if OS.get_environment("PLV") != "" else 1
	for p in Pat.PATTERN_IDS:
		if only != "" and not p in only.split(","):
			continue
		var res := []
		for sc in ["cross", "head"]:
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
				main.picked = {"e": e, "lv": 1}
				main._place_tower(tp, Vector2.RIGHT if sc == "cross" else Vector2.LEFT)
				var t = main.towers.get_child(0)
				for i in plv:
					t.set_pattern(p)
				var spawn_t := 0.0
				for f in 60 * 30:
					spawn_t -= 1.0 / 60
					if spawn_t <= 0:
						spawn_t = 1.0 / 3.0
						var o = Orb.new(); o.main = main
						if sc == "cross":
							var x := randf_range(-50, 50)
							o.position = tp + Vector2(160 + x, -330); o.target = tp + Vector2(160 + x, 2000)
						else:
							var y := randf_range(-30, 30)
							o.position = tp + Vector2(-700, y); o.target = tp + Vector2(0, y)
						o.setup(Orb.Kind.NORMAL, 100000, 50)
						o.swirl = 0.0
						main.orbs.add_child(o)
					await process_frame
					for o in main.orbs.get_children():
						if (sc == "cross" and o.position.y > tp.y + 330) or (sc == "head" and o.position.x > tp.x - 30):
							o.queue_free()
				all += t.dealt / 30.0
			res.append(all / 2.0)
		print("PAT %-8s Lv%d cross/s=%6.2f  head/s=%6.2f" % [p, plv, res[0], res[1]])
	quit()
