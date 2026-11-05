extends SceneTree
# 피해가 안 들어가는 상황 전수조사 (2026-11-01): 공격방식 x 다중 발사 수 x 강화 하나마다
# 오브젝트 정면(조준한 바로 그 방향)에 멈춘 구체 하나를 거리별로 두고 4초 동안 준 피해를 잰다.
# 사거리 안인데 피해 0이면 MISS. 맨 끝에 MISS 줄 수와 "AUDIT miss=N".
# KIND=fast 이면 작은 빠른 구체(반지름 9), 기본은 일반 구체(반지름 21). PAT=shot,spray 로 골라 보기.
var main

const DISTS := [90.0, 160.0, 240.0, 320.0, 400.0, 440.0]
const EXTRA := ["", "homing", "size", "pierce", "bounce", "split", "rapid"]


## 이 공격방식·강화로 정면 구체를 맞힐 수 있어야 하는 거리 (그 너머는 원래 안 닿는 사거리)
func reach(t, p: String) -> float:
	var s: float = t.sz()
	match p:
		"shot", "shard": return Tower.shot_range(t.total_level(), t.mf("size")) * 0.95
		"thorn", "iron": return 480.0
		"gust": return 400.0 * Rules.t("range_gust")
		"spray": return 200.0 * t.rr(t.plv) * s * 0.9
		"stream": return 260.0 * t.rr(t.plv) * s * 0.9
		"chain": return 280.0 * t.rr(t.plv) * s * 0.9
		"laser": return 480.0
		"sonic": return t.sonic_r(t.plv) * 0.9
		"clock": return 240.0 * t.rr(t.plv) * s * 0.9
		"wall": return 90.0 * t.rr(t.plv)
		"vortex", "lob": return 300.0
		"wisp": return 250.0
	return 0.0


func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var only := OS.get_environment("PAT")
	var fast := OS.get_environment("KIND") == "fast"
	var miss := 0
	for p in Pat.ALL_IDS:
		if only != "" and not p in only.split(","):
			continue
		for ex in EXTRA:
			if ex != "" and Pat.NO_MOD.get(ex, []).has(p):
				continue
			for nm in 4:
				var row := []
				var bad := []
				var top := 0.0
				for dist in DISTS:
					var r := await _one(p, ex, nm, dist, fast)
					top = maxf(top, r[0])
					# 사거리 안인데 피해가 없거나, 가장 잘 맞힌 거리의 15%도 안 되면 못 맞힌 것으로 본다
					var low: bool = dist <= r[1] and r[0] < top * 0.15
					row.append("%d:%s" % [dist, ("%.0f" % r[0]) + ("!" if low else "") if r[0] > 0.0 else ("--" if dist > r[1] else "0!")])
					if low:
						bad.append(dist)
				var tag := "MISS" if not bad.is_empty() else "ok  "
				if not bad.is_empty():
					miss += 1
				print("%s %-6s %-7s multi=%d  %s" % [tag, p, ex if ex != "" else "-", nm, " ".join(row)])
	print("AUDIT miss=%d" % miss)
	quit()


func _one(p: String, ex: String, nm: int, dist: float, fast: bool) -> Array:
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
	var tp: Vector2 = main.center() + Vector2(-560, 0)  # 구체가 가운데(핵)에 닿지 않게
	main.picked = {"e": Elem.FIRE, "lv": 1}
	main.interaction_system._place_tower(tp, Vector2.RIGHT)
	var t = main.towers.get_child(0)
	if p != "shot":
		t.set_pattern(p)
	for i in nm:
		t.add_mod("multi")
	if ex != "":
		t.add_mod(ex)
	var o = Orb.new(); o.main = main
	o.position = tp + Vector2(dist, 0)
	o.target = o.position
	o.setup(Orb.Kind.FAST if fast else Orb.Kind.NORMAL, 1e9, 0.0)
	o.swirl = 0.0
	main.orbs.add_child(o)
	var rch := reach(t, p)
	for f in 60 * 4:
		if is_instance_valid(o):
			o.position = tp + Vector2(dist, 0)  # 밀림·끌림을 지운다 (정면에 그대로)
		await process_frame
	return [t.dealt, rch]
