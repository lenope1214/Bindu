extends SceneTree
# 혼불 전수조사: 혼불 오브젝트에 강화(하나·둘·셋 조합)·두 번째 속성(반응·형태 성질)·연계·발동을 붙여
# 탄 수명(가장 오래 산 탄·10초 넘게 산 탄 수), 동시에 떠 있던 탄 수, 피해/초, 처치 수, 피해 출처를 본다.
# 사용: godot --headless --fixed-fps 60 --path . -s tools/wisp_audit.gd
# 환경 변수: RULES=1|3  MODE=immortal(죽지 않는 구체, 추적·수명) | kill(실제 웨이브 구체, 처치 효과 포함)
#   SET=mods1|mods2|mods3|elems|links|base  PART=i/n  SECS(기본 20)  WAVE(kill, 기본 15)  OSPD(immortal 구체 속도, 기본 90)
var main
var secs := 20.0
var mode := "immortal"
var ospd := 90.0
var wave := 15


func _initialize():
	Meta.map_id = "spiral"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	Meta.rules = int(OS.get_environment("RULES")) if OS.get_environment("RULES") != "" else 1
	Meta.map_id = "spiral"
	main._apply_rules()
	secs = float(_env("SECS", "20"))
	mode = _env("MODE", "immortal")
	ospd = float(_env("OSPD", "90"))
	wave = int(_env("WAVE", "15"))
	var mods: Array = Pat.MOD_IDS.duplicate()
	var jobs := []
	match _env("SET", "base"):
		"base":
			for p in ["shot", "wisp", "thorn", "iron", "shard", "spray", "sonic", "clock"]:
				jobs.append({"pat": p, "mods": {}})
				jobs.append({"pat": p, "mods": {"homing": 3}})
		"mods1":
			jobs.append({"pat": "wisp", "mods": {}})
			for m in mods:
				for n in [1, 3, 5]:
					jobs.append({"pat": "wisp", "mods": {m: n}})
		"mods2":
			for i in mods.size():
				for k in range(i + 1, mods.size()):
					jobs.append({"pat": "wisp", "mods": {mods[i]: 3, mods[k]: 3}})
		"mods3":
			for i in mods.size():
				for k in range(i + 1, mods.size()):
					for q in range(k + 1, mods.size()):
						jobs.append({"pat": "wisp", "mods": {mods[i]: 3, mods[k]: 3, mods[q]: 3}})
			var all := {}
			for m in mods:
				all[m] = 5
			jobs.append({"pat": "wisp", "mods": all})
		"elems":
			for e in Elem.ALL:
				if e != Elem.SOUL:
					jobs.append({"pat": "wisp", "mods": {}, "e2": e})
					jobs.append({"pat": "wisp", "mods": {"homing": 3, "multi": 3}, "e2": e})
		"links":
			for l in Pat.LINK_IDS:
				for n in [1, 3]:
					jobs.append({"pat": "wisp", "mods": {}, "link": l, "ln": n})
					jobs.append({"pat": "wisp", "mods": {"homing": 3}, "link": l, "ln": n})
			for g in Pat.TRIG_IDS:
				for n in [1, 5]:
					jobs.append({"pat": "wisp", "mods": {}, "trig": g, "tn": n})
					jobs.append({"pat": "wisp", "mods": {"homing": 3, "multi": 3}, "trig": g, "tn": n})
	var part := _env("PART", "")
	if part != "":
		var a := part.split("/")
		var mine := []
		for k in jobs.size():
			if k % int(a[1]) == int(a[0]):
				mine.append(jobs[k])
		jobs = mine
	for j in jobs:
		var r: Dictionary = await _run(j)
		var md := ",".join(j["mods"].keys().map(func(k): return "%s%d" % [k, j["mods"][k]]))
		var extra := ""
		if j.has("e2"): extra = "e2=" + Elem.NAMES[j["e2"]]
		if j.has("link"): extra = "link=%s%d" % [j["link"], j["ln"]]
		if j.has("trig"): extra = "trig=%s%d" % [j["trig"], j["tn"]]
		print("AUDIT rules=%d mode=%s pat=%s mods=%s %s dps=%.1f kills=%d max_t=%.1f avg_t=%.2f over6=%d peak=%d ghosts=%d top=%s" % [
			Meta.rules, mode, j["pat"], md if md != "" else "-", extra if extra != "" else "-",
			r["dps"], r["kills"], r["max_t"], r["avg_t"], r["over"], r["peak"], r["ghosts"], r["top"]])
	quit()


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d


func _clear():
	for c in main.towers.get_children(): c.free()
	for c in main.orbs.get_children(): c.free()
	for c in main.zones.get_children(): c.free()
	for c in main.projectiles.get_children(): c.free()


func _run(j: Dictionary) -> Dictionary:
	seed(7)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	_clear()
	main.wave = wave if mode == "kill" else 20
	main.phase = main.Phase.WAVE; main.wave_active = true; main.wave_time = 10.0; main.to_spawn = 0
	var c = main.center()
	var ld := Vector2.UP
	main.picked = {"e": Elem.SOUL, "lv": 3}
	main._place_tower(c + ld * 100.0, ld)
	var t = main.towers.get_child(0)
	if j.has("e2"):
		t.add(j["e2"], 3)
	if j["pat"] != "shot":
		t.set_pattern(j["pat"])
	while t.plv < 2:
		t.set_pattern(j["pat"])
	for k in j["mods"]:
		for i in j["mods"][k]:
			t.add_mod(k)
	if j.has("trig"):
		for i in j["tn"]:
			t.add_trig(j["trig"])
	if j.has("link"):
		# 연계 짝: 옆(50)에 금속 직선탄 하나. 프리즘은 짝에 두고 혼불이 지나가게, 공명·협공은 혼불 쪽에
		main.picked = {"e": Elem.METAL, "lv": 3}
		var pp: Vector2 = c + ld * 100.0 + ld.orthogonal() * 45.0
		if j["link"] == "prism":
			pp = c + ld * 150.0
		main._place_tower(pp, ld)
		var pt = main.towers.get_child(main.towers.get_child_count() - 1)
		for i in j["ln"]:
			if j["link"] == "prism":
				pt.add_link("prism")
			else:
				t.add_link(j["link"])
	t.dealt = 0.0; t.rx_dealt = 0.0; t.src = {}
	main.kills = 0
	var born := {}
	var lives := []
	var peak := 0
	var ghosts := 0
	var kills := 0
	var spawn_t := 0.0
	var frames := int(60 * secs)
	for f in frames:
		main.phase = main.Phase.WAVE; main.wave_active = true; main.core_hp = 99999
		spawn_t -= 1.0 / 60
		if spawn_t <= 0 and f < frames - 60 * 6:
			spawn_t = 0.5 if mode == "immortal" else 0.35
			if mode == "kill":
				main._spawn_orb()
			else:
				var o = Orb.new(); o.main = main
				var a := rng.randf_range(0, TAU)
				o.position = c + Vector2.from_angle(a) * main._spawn_radius()
				o.from_a = a; o.target = c; o.swirl = main.SPIRAL_SWIRL
				o.setup(Orb.Kind.NORMAL, 1000000, ospd)
				main.orbs.add_child(o)
		await process_frame
		var alive := {}
		var n := 0
		for p in main.projectiles.get_children():
			if p.is_queued_for_deletion(): continue
			n += 1
			if p.kind != "wisp" and p.kind != "ghost" and p.homing <= 0.0: continue
			var id = p.get_instance_id()
			alive[id] = true
			if not born.has(id):
				born[id] = f
				if p.kind == "ghost": ghosts += 1
		peak = maxi(peak, n)
		for id in born.keys():
			if not alive.has(id):
				lives.append((f - born[id]) / 60.0)
				born.erase(id)
		for o in main.orbs.get_children():
			if not o.is_queued_for_deletion() and o.position.distance_to(c) < 45.0:
				o.queue_free()
	kills = main.kills
	for id in born: lives.append((frames - born[id]) / 60.0)
	var mx := 0.0; var sum := 0.0; var over := 0
	for l in lives:
		mx = maxf(mx, l); sum += l
		if l > 6.0: over += 1
	var tot := 0.0
	for k in t.src: tot += t.src[k]
	var ks: Array = t.src.keys()
	ks.sort_custom(func(a, b): return t.src[a] > t.src[b])
	var top := PackedStringArray()
	for k in ks.slice(0, 3):
		top.append("%s:%d%%" % [k, roundi(100.0 * t.src[k] / maxf(tot, 1.0))])
	return {"dps": t.dealt / secs, "kills": kills, "max_t": mx, "avg_t": sum / maxf(lives.size(), 1), "over": over,
		"peak": peak, "ghosts": ghosts, "top": ",".join(top)}
