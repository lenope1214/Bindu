extends SceneTree
# 자동 플레이 봇: 반응 생기면 겹치기, 아니면 진입 방향을 가로지르게 새로 설치.
# 사용: tools/run.sh bots (또는 godot --headless --fixed-fps 60 --path . -s tools/bot.gd -- <시드> [stack])
# 환경 변수: RULES(규칙 버전) MAP(맵) SPEED(배속) SMART=1(사람처럼 배치) GOD=<웨이브>(죽지 않고 그 웨이브까지, 멈춤 감시)
var main
var frames := 0
var stack_all := false
var lane_i := 0
func _initialize():
	var args = OS.get_cmdline_user_args()
	seed(int(args[0]) if args.size() > 0 else 1)
	stack_all = args.size() > 1 and args[1] == "stack"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

var last_wave := -1
var god_w := -1
var picks_w := -1
var dumped := false
var wave_ms := 0
func _process(_d):
	frames += 1
	if main.phase != 3:
		wave_ms = Time.get_ticks_msec()
	if main.phase == 3 and (main.wave_time > 240.0 or Time.get_ticks_msec() - wave_ms > 240000) and not dumped:
		dumped = true
		print("STUCK real=", Time.get_ticks_msec() - wave_ms, " wave=", main.wave, " t=", main.wave_time, " to_spawn=", main.to_spawn, " alive=", main.orbs.get_child_count(), " proj=", main.projectiles.get_child_count(), " zones=", main.zones.get_child_count())
		for o in main.orbs.get_children():
			print("  ORB kind=", o.kind, " pos=", o.position, " d=", o.position.distance_to(main.center()), " hp=", o.hp, "/", o.max_hp, " sh=", o.shield, " spd=", o.speed, " slow=", o.slow_factor, " root=", o.root_timer, " frozen=", o.frozen_t, " prison=", o.prison_t, " push=", o.push_budget, " q=", o.is_queued_for_deletion(), " target=", o.target, " age=", o.age, " resist=", o.resist_e, " sturdy=", o.sturdy)
		for t in main.towers.get_children():
			print("  TW ", t.title(), " @", t.position, " ", t.extras_text(), " rx=", t.reactions().map(func(r): return r["name"]))
		quit()
	if OS.get_environment("GOD") != "":
		if main.phase == 0 and main.wave != god_w:
			if god_w >= 0:
				print("LEAK ms=", Time.get_ticks_msec(), " orbs=", main.live_orbs.size(), " w=", main.wave, " lost=", 99999 - main.core_hp, " n=", main.wave_size(main.wave), " towers=", main.towers.get_child_count())
			god_w = main.wave
			main.core_hp = 99999
			main.core_max = 99999
		if main.wave >= int(OS.get_environment("GOD")):
			print("RESULT wave=", main.wave, " score=", main.score)
			if Rules.mod_slots:
				for t in main.towers.get_children():
					print("  SLOT ", t.title(), " | ", t.slots_text(), " | ", t.extras_text())
			return true
	if OS.get_environment("RULES") != "" and Meta.rules != int(OS.get_environment("RULES")):
		Meta.rules = int(OS.get_environment("RULES"))
		main._apply_rules()
	if OS.get_environment("MAP") != "" and Meta.map_id != OS.get_environment("MAP"):
		Meta.map_id = OS.get_environment("MAP")
		main.lanes.clear()
		main._roll_lanes()
	if OS.get_environment("DIAG") != "" and main.phase == 0 and main.wave != last_wave:
		last_wave = main.wave
		var info = []
		for t in main.towers.get_children(): info.append("%s@%d,%d dir%.0f dealt%d" % [t.title(), t.position.x, t.position.y, rad_to_deg(t.dir.angle()), t.dealt])
		print("W", main.wave, " core=", main.core_hp, " lanes=", main.lanes.map(func(a): return int(rad_to_deg(a))), " ", info)
	main.auto_start = true
	main.game_speed = float(OS.get_environment("SPEED")) if OS.get_environment("SPEED") != "" else 1.0
	if main.phase == 6: main._start_wave()
	if main.perk_mode:
		main._on_perk(main.perk_offer[randi() % 3])
		return false
	if OS.get_environment("PICKS") != "" and main.phase == 0 and main.wave != picks_w:
		picks_w = main.wave
		main.picks_left += int(OS.get_environment("PICKS"))
	if main.phase == 0 and main.offer.size() > 0 and not main.perk_mode:
		var offer = main.offer
		var ts = main.towers.get_children()
		var pick = null
		var target = null
		# 0) 진입 방향보다 오브젝트가 적으면 새로 설치
		var uncovered = false
		for cand0 in main.lanes:
			var cand = eff_lane(cand0)
			var lp = main.center() + Vector2(cos(cand), sin(cand)) * 170
			if not ts.any(func(t): return t.position.distance_to(lp) < 160): uncovered = true
		if uncovered or ts.size() < main.lanes.size() + 1:
			for o in offer:
				if o["type"] == "elem": pick = o; break
		# 1) 반응이 생기는 속성 겹치기
		for o in offer:
			if pick: break
			if o["type"] == "elem":
				for t in ts:
					if not Elem.new_reactions(t.eff_now(), o["e"]).is_empty():
						pick = o; target = t; break
			if pick: break
		# 2) 직선탄인 오브젝트에 공격방식
		if pick == null:
			for o in offer:
				if o["type"] == "pat":
					for t in ts:
						if t.pattern == o["id"]: pick = o; target = t; break
					if pick: break
					for t in ts:
						if t.pattern == "shot": pick = o; target = t; break
				if pick: break
		# 3) 강화는 가장 강한 오브젝트에
		if pick == null and ts.size() > 0:
			for o in offer:
				if o["type"] == "mod" or (o["type"] == "link" and o["id"] != "link"):
					pick = o
					target = ts[0]
					for t in ts:
						if t.total_level() > target.total_level(): target = t
					break
		if pick == null and ts.size() >= 2:
			for o in offer:
				if o["type"] == "link" and o["id"] == "link":
					var best = null
					for a in ts:
						for b in ts:
							if a != b and not a.links.has(b) and a.position.distance_to(b.position) < Rules.link_range:
								best = [a, b]
					if best:
						main._on_pick(o); main._apply_card(best[0]); main._apply_card(best[1]); return false
		if pick == null:
			for o in offer:
				if o["type"] == "elem": pick = o; break
		if pick == null:
			pick = offer[0]
			if ts.size() > 0: target = ts[0]
		if stack_all and ts.size() > 0 and pick["type"] == "elem":
			target = ts[0]
		if pick["type"] == "cata":
			main._on_pick(pick); return false
		# 상한: 넣을 수 없는 오브젝트면 넣을 수 있는 다른 오브젝트로, 없으면 속성은 새로 설치
		if target and not target.can_take(pick):
			target = null
			for t in ts:
				if t.can_take(pick): target = t; break
		if pick["type"] != "elem" and target == null:
			for t in ts:
				if t.can_take(pick): target = t; break
		main._on_pick(pick)
		if pick["type"] != "elem":
			if target == null: target = ts[0] if ts.size() > 0 else null
			if pick["type"] == "pat" and target and not target.can_pattern(pick["id"]): target = null
			if target == null or (pick["type"] == "link" and pick["id"] == "link"):
				main._back_to_choose(); main._on_reroll()
				if main.phase == 0 and main.rerolls_left <= 0 and main.offer == offer:
					main.picks_left = 1; main._after_place()
				return false
			main._apply_card(target)
		elif target:
			main._show_toast(target.add(pick["e"], pick["lv"]))
			main._after_place()
		else:
			var c = main.center()
			# 오브젝트가 가장 적은 진입 방향에 설치
			var la = eff_lane(main.lanes[0])
			var fewest = 999
			for cand0 in main.lanes:
				var cand = eff_lane(cand0)
				var lp = c + Vector2(cos(cand), sin(cand)) * 170
				var cnt = 0
				for t in ts:
					if t.position.distance_to(lp) < 160: cnt += 1
				if cnt < fewest: fewest = cnt; la = cand
			lane_i += 1
			var ld = Vector2(cos(la), sin(la))
			var side = (1 if lane_i % 2 == 0 else -1) * (0.15 if Meta.map_id == "cross" else 1.0)
			var p
			if OS.get_environment("SMART") != "":
				# 사람처럼: 중앙 가까이에서 진입 방향 그대로 겨눈다
				p = c + ld * (90 + 25 * (lane_i % 3)) + ld.orthogonal() * 22 * side
				main._place_tower(p, ld)
			else:
				p = c + ld * (150 + 30 * (lane_i % 3)) + ld.orthogonal() * 70 * side
				# 직선탄은 진입 방향을 향해 겨눈다
				main._place_tower(p, (c + ld * 600 - p).normalized())
			main._after_place()
	if main.phase == 4 or frames > 60 * 60 * (int(OS.get_environment("MINS")) if OS.get_environment("MINS") != "" else 25) / main.game_speed:
		var ts = []
		for t in main.towers.get_children(): ts.append(t.title())
		print("RESULT wave=", main.wave, " score=", main.score, " ", main._perk_text(), " towers=", ts)
		return true
	return false

# 소용돌이 맵: 구체가 반지름 r을 지날 때의 각도
func eff_lane(a):
	if Meta.map_id != "spiral": return a
	var c = main.center()
	var p = c + Vector2(cos(a), sin(a)) * 650
	while p.distance_to(c) > 170:
		p += (c - p).normalized().rotated(0.6) * 4.0
	return (p - c).angle()
