extends "res://tools/spec_check.gd"
## 동일 시드·동일 표적·동일 배치에서 실제 _sim_step과 인스펙터를 대조한다.
## 스모크 검사가 아니라 피해·상태·발사체·장판·누적 발동 상태를 프레임별로 비교한다.
var cases := 0
var samples := 0
var suite := "basic"
const DT := 1.0 / 60.0
const FRAMES := 240
var preview: AttackPreview

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"):
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	suite = args[3] if args.size() > 3 else "basic"
	Tutorial.loaded = true
	Tutorial.done = true
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main.set_process(false)
	main.progression_system._hide_title()
	main.sfx.muted = true
	preview = main.card_dock.pic.attack_preview
	preview.set_process(false)
	preview.auto_refill = false
	preview.include_support_attacks = true
	Meta.guide_on = false
	Vary.new_run(false)
	for pat in Pat.ALL_IDS:
		if suite == "context":
			for map in Meta.MAP_IDS:
				for direction in [Vector2.RIGHT, Vector2.UP, Vector2(0.6, 0.8)]:
					run_case(pat, {Elem.WATER: 2, Elem.ELECTRIC: 2}, {}, {}, "map:" + map + ":" + str(direction), 2, true, {"map": map, "dir": direction})
		elif suite == "long":
			run_case(pat, {Elem.FIRE: 2, Elem.TIME: 2, Elem.STAR: 2}, {"multi": 1}, {"third": 2}, "long", 2, true)
		elif suite == "deaths":
			run_case(pat, {Elem.POISON: 2, Elem.WOOD: 2}, {}, {"charge": 2}, "death:poison")
			run_case(pat, {Elem.DARK: 2, Elem.SOUL: 2}, {}, {"charge": 2}, "death:soul")
			run_case(pat, {Elem.TIME: 2, Elem.FIRE: 2}, {"split": 2}, {"echo": 2}, "death:echo")
		elif suite == "pairs":
			for rx in Elem.REACTIONS:
				run_case(pat, {rx.a: 2, rx.b: 2}, {}, {}, "pair:" + rx.id)
		else:
			run_case(pat, {Elem.METAL: 1}, {}, {}, "base", 1)
			run_case(pat, {Elem.METAL: 3}, {}, {}, "level", 3)
			for mod in Pat.MOD_IDS:
				run_case(pat, {Elem.METAL: 2}, {mod: 2}, {}, "mod:" + mod)
			for trig in Pat.TRIG_IDS:
				run_case(pat, {Elem.METAL: 2}, {}, {trig: 2}, "trig:" + trig)
			run_case(pat, {Elem.STAR: 2}, {}, {}, "star", 2, true)
			run_case(pat, {Elem.STAR: 2, Elem.FIRE: 2}, {}, {}, "planet", 2, true)
			run_case(pat, {Elem.FIRE: 2, Elem.ELECTRIC: 2}, {}, {}, "links", 2, true)
		print("PARITY pattern=%s cases=%d failures=%d" % [pat, cases, fails])
	var per_pattern: int = {"pairs": Elem.REACTIONS.size(), "deaths": 3, "context": Meta.MAP_IDS.size() * 3, "long": 1}.get(suite, 2 + Pat.MOD_IDS.size() + Pat.TRIG_IDS.size() + 3)
	if cases != Pat.ALL_IDS.size() * per_pattern:
		fails += 1
		print("FAIL PARITY incomplete matrix")
	print("PARITY suite=%s cases=%d samples=%d failures=%d" % [suite, cases, samples, fails])
	quit(1 if fails > 0 else 0)

func run_case(pat: String, els: Dictionary, mods: Dictionary, trigs: Dictionary, label: String, level := 2, peers := false, context := {}) -> void:
	_fresh(8)
	# 이전 사례 전투를 정리한다. 전역 수치는 두 경로에서 같다.
	main.sfx.muted = true
	if not context.is_empty():
		Meta.map_id = context.map
		Rules.tune["map_on"] = 1.0
		main.lanes.assign([0.0, PI / 2.0])
		main.ley.assign([Vector2(140, 360), Vector2(500, 360)])
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.to_spawn = 1
	main.spawn_timer = INF
	main.mp_extra_left = 0
	main.skill_ids.clear()
	main.jam_any = false
	main.sim_id = 0
	main.run_game = 0.0
	main.wave_time = 0.0
	# 콤보 점수 말풍선의 난수 위치는 전투 효과가 아니므로 비교에서 배제한다.
	main.combo = -100
	main.combo_t = 999.0
	main.wells.clear()
	main.side_big_t = 0.0
	main.eclipse_cd = 0.0
	main.eclipse_flash = 0.0
	main.particles.clear()
	main.popups.clear()
	main.bolts.clear()
	main.pulses.clear()
	main.beams.clear()
	main.arcs.clear()
	var t := _tower(Vector2(640, 240) if not context.is_empty() else Vector2(180, 360), Elem.METAL)
	t.elements = els.duplicate(true)
	t.order.assign(els.keys())
	t.eff = t.eff_now()
	t.pattern = pat
	t.plv = level
	t.dir = context.get("dir", Vector2.RIGHT)
	if not context.is_empty():
		t.focus_t = 5.0
		t.leech_n = 1
		t.leech_t = 7.0
	t.mods = mods.duplicate(true)
	t.trigs = trigs.duplicate(true)
	t.charge = t.charge_need()
	t.third_n = 2
	if els.has(Elem.STAR): t.star_sum = t.star_need() * 0.99
	if peers:
		t.pincer = 2
		t.reso = 2
		var ally := _tower(t.position + Vector2(30, 20), Elem.FIRE, 2)
		ally.pattern = "shot"
	preview.signature = ""
	preview.configure(t)
	for o: Orb in preview.world.orbs.get_children():
		o.hp = 1.0 if suite == "deaths" else 1e8
		o.max_hp = o.hp
		o.speed = 0.0
		var actual := _orb(o.position, o.hp)
		actual.target = o.target
	# 카메라·음향의 난수는 제외하고 같은 전투 프레임을 순서대로 실행한다.
	var expected := []
	seed(419)
	var frames := 720 if suite == "long" else FRAMES
	for frame in frames:
		main.combat_system.tick_effects(DT)
		main.combat_system._sim_step(DT)
		if frame % 20 == 0: expected.append(state(main))
	seed(419)
	var index := 0
	for frame in frames:
		preview.advance(DT)
		if frame % 20 == 0:
			var actual := state(preview.world)
			samples += 1
			if actual != expected[index]:
				fails += 1
				print("FAIL PARITY %s %s frame=%d %s" % [pat, label, frame, difference(expected[index], actual)])
				break
			index += 1
	cases += 1

func state(w: BinduSession) -> Array:
	var result := []
	for layer in [w.towers, w.orbs, w.projectiles, w.zones]:
		var rows := []
		for n in layer.get_children():
			if n.is_queued_for_deletion(): continue
			var keys: Array
			if n is Tower: keys = ["position", "dealt", "rx_dealt", "src", "charge", "third_n", "star_sum", "side_n", "side_cd"]
			elif n is Orb: keys = ["position", "hp", "burn_t", "poison_t", "slow_timer", "slow_factor", "root_timer", "frozen_t", "vuln_t", "vine", "chill", "echo_t", "echo_amt", "bleed_t", "confuse_t"]
			elif n is Projectile: keys = ["kind", "position", "vel", "dmg", "radius", "t", "travel", "pierce_left", "bounces"]
			else: keys = ["kind", "position", "life", "radius", "hp", "store", "pts"]
			var row := []
			for key in keys: row.append(normalize(n.get(key)))
			rows.append(row)
		result.append(rows)
	return result

func normalize(v):
	if v is float: return snappedf(v, 0.00001)
	if v is Vector2: return [snappedf(v.x, 0.00001), snappedf(v.y, 0.00001)]
	if v is Dictionary:
		var d := {}
		for k in v: d[k] = normalize(v[k])
		return d
	if v is Array or v is PackedVector2Array:
		var a := []
		for x in v: a.append(normalize(x))
		return a
	return v

func difference(a: Array, b: Array) -> String:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]: return "layer=%d expected=%s actual=%s" % [i, str(a[i]).left(650), str(b[i]).left(650)]
	return "layer count differs"
