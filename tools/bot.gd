extends SceneTree
# 자동 플레이 봇: 반응 생기면 겹치기, 아니면 진입 방향을 가로지르게 새로 설치.
# 사용: tools/run.sh bots (또는 godot --headless --fixed-fps 60 --path . -s tools/bot.gd -- <시드> [stack])
# 환경 변수: BOT_ELEM=<속성 번호>·BOT_PAT=<공격방식 id>·BOT_MOD=<강화 id>(그 종류 카드를 전부 이것으로 바꿈, 조합 효율 측정용) WLOG=1(GOD일 때 웨이브마다 오브젝트별 피해 TW 줄)
# RULES(규칙 버전) MODES(모드, 쉼표로) MAP(맵) FLIP=1(회랑에서 구체가 왼쪽에서) SPEED(배속) SMART=1(사람처럼 배치) GOD=<웨이브>(죽지 않고 그 웨이브까지, 멈춤 감시)
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
var skip_w := -1
var dumped := false
var modes_set := false


## MODES=rush,steel: 첫 프레임에 모드를 켠다 (없으면 모두 끔: 시험 저장에 남은 모드가 섞이지 않게).
func _set_modes():
	modes_set = true
	Modes.set_on(Array(OS.get_environment("MODES").split(",", false)))
	main._apply_rules()
	main.start_modes()
	main.picks_left = maxi(2, Rules.picks)
	main.rerolls_left = Modes.rerolls(1)
var wave_ms := 0
func _process(_d):
	frames += 1
	if main.phase != 3:
		wave_ms = Time.get_ticks_msec()
	if main.phase == 3 and (main.wave_time > 240.0 or Time.get_ticks_msec() - wave_ms > 240000) and not dumped:
		dumped = true
		print("STUCK real=", Time.get_ticks_msec() - wave_ms, " wave=", main.wave, " t=", main.wave_time, " to_spawn=", main.to_spawn, " alive=", main.orbs.get_child_count(), " proj=", main.projectiles.get_child_count(), " zones=", main.zones.get_child_count())
		for o in main.orbs.get_children():
			print("  ORB kind=", o.kind, " pos=", o.position, " d=", o.position.distance_to(main.core()), " hp=", o.hp, "/", o.max_hp, " sh=", o.shield, " spd=", o.speed, " slow=", o.slow_factor, " root=", o.root_timer, " frozen=", o.frozen_t, " prison=", o.prison_t, " push=", o.push_budget, " q=", o.is_queued_for_deletion(), " target=", o.target, " age=", o.age, " resist=", o.resist_e, " sturdy=", o.sturdy)
		for t in main.towers.get_children():
			print("  TW ", t.title(), " @", t.position, " ", t.extras_text(), " rx=", t.reactions().map(func(r): return r["name"]))
		quit()
	if OS.get_environment("GOD") != "":
		if main.phase == 0 and main.wave != god_w:
			if god_w >= 0:
				print("LEAK ms=", Time.get_ticks_msec(), " orbs=", main.live_orbs.size(), " w=", main.wave, " lost=", 99999 - main.core_hp, " n=", main.wave_size(main.wave), " towers=", main.towers.get_child_count())
				if OS.get_environment("WLOG") != "":
					for t in main.towers.get_children():
						print("TW w=%d pat=%s plv=%d els=%s mods=%s dealt=%.0f rx=%.0f" % [main.wave, t.pattern, t.plv, JSON.stringify(t.elements), JSON.stringify(t.mods), t.dealt, t.rx_dealt])
			god_w = main.wave
			main.core_hp = 99999
			main.core_max = 99999
		if main.wave >= int(OS.get_environment("GOD")):
			print("RESULT wave=", main.wave, " score=", main.score)
			return true
	if not modes_set:
		_set_modes()
	if OS.get_environment("RULES") != "" and Meta.rules != int(OS.get_environment("RULES")):
		Meta.rules = int(OS.get_environment("RULES"))
		main._apply_rules()
	if Meta.line_flip != (OS.get_environment("FLIP") != ""):
		Meta.line_flip = not Meta.line_flip  # 회랑: 구체가 왼쪽에서
		main.lanes.clear()
		main._roll_lanes()
	if OS.get_environment("MAP") != "" and Meta.map_id != OS.get_environment("MAP"):
		Meta.map_id = OS.get_environment("MAP")
		main.lanes.clear()
		main._roll_lanes()
	if OS.get_environment("DIAG") != "" and main.phase == 0 and main.wave != last_wave:
		last_wave = main.wave
		var info = []
		for t in main.towers.get_children(): info.append("%s@%d,%d dir%.0f dealt%d" % [t.title(), t.position.x, t.position.y, rad_to_deg(t.dir.angle()), t.dealt])
		print("W", main.wave, " picks=", main.picks_left, " rr=", main.rerolls_left, " perk=", main.perk_mode, " core=", main.core_hp, " lanes=", main.lanes.map(func(a): return int(rad_to_deg(a))), " ", info)
	main.auto_start = true
	main.game_speed = float(OS.get_environment("SPEED")) if OS.get_environment("SPEED") != "" else 1.0
	if main.phase == 7: main._cancel_step()  # 그린 궤적: 봇은 길을 못 그려 곧은 기본 길 그대로
	if main.phase == 6: main._start_wave()
	# SKIP=3: SKIP_FROM(기본 8)웨이브부터 웨이브 넘기기를 3개씩 쓰고, 멈추면 쌓인 것을 다 고른 뒤 다시 넘긴다
	if not main.bank_picks.is_empty() or main.bank_perks > 0:
		skip_w = main.wave  # 넘기기를 멈춘 쉬는 시간: 이번엔 다 고른다
	if OS.get_environment("SKIP") != "" and main.phase == 0 and main.wave >= (int(OS.get_environment("SKIP_FROM")) if OS.get_environment("SKIP_FROM") != "" else 8) and main.wave != skip_w and main.bank_picks.is_empty() and main.bank_perks == 0 and main._can_skip():
		skip_w = main.wave
		Meta.skip_n = int(OS.get_environment("SKIP"))
		main._on_skip()
		if OS.get_environment("DIAG") != "": print("SKIP w=", main.wave, " bank=", main.bank_picks, " rr=", main.bank_rerolls)
		return false
	if main.perk_mode:
		main._on_perk(main.perk_offer[randi() % 3])
		return false
	if OS.get_environment("PICKS") != "" and main.phase == 0 and main.wave != picks_w:
		picks_w = main.wave
		main.picks_left += int(OS.get_environment("PICKS"))
	# 사람처럼: 쉬는 시간마다 진입 방향이 옮겨 가 비게 된 오브젝트를 빈 길목으로 옮긴다 (NOADAPT=1이면 안 함)
	if OS.get_environment("NOADAPT") == "" and main.phase == 0 and main.wave != adapt_w:
		adapt_w = main.wave
		_rearrange()
	if main.phase == 0 and main.offer.size() > 0 and not main.perk_mode:
		_force_offer()
		var offer = main.offer
		var ts = main.towers.get_children()
		var pick = null
		var target = null
		# 0) 진입 방향보다 오브젝트가 적으면 새로 설치
		var uncovered = false
		for cand0 in main.lanes:
			var cand = eff_lane(cand0)
			if not ts.any(func(t): return serves(t, cand)): uncovered = true
		# 회랑: 방향은 하나지만 사람처럼 길을 따라 여러 개를 나눠 놓는다 (평원에서 방향 수만큼 놓는 것과 같은 수)
		var want = (main.lanes_for(main.wave + 1) if Meta.map_id == "line" else main.lanes.size()) + 1
		if uncovered or ts.size() < want:
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
				if o["type"] == "mod" or o["type"] == "link":
					pick = o
					target = ts[0]
					for t in ts:
						if t.total_level() > target.total_level(): target = t
					break
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
			if target == null:
				main._back_to_choose(); main._on_reroll()
				if main.phase == 0 and main.rerolls_left <= 0 and main.offer == offer:
					main.picks_left = 1; main._after_place()
				return false
			main._apply_card(target)
		elif target:
			main._show_toast(target.add(pick["e"], pick["lv"]))
			main._after_place()
		else:
			var c = main.core()
			# 오브젝트가 가장 적은 진입 방향에 설치
			var la = eff_lane(main.lanes[0])
			var fewest = 999
			for cand0 in main.lanes:
				var cand = eff_lane(cand0)
				var cnt = 0
				for t in ts:
					if serves(t, cand): cnt += 1
				if cnt < fewest: fewest = cnt; la = cand
			lane_i += 1
			var ld = Vector2(cos(la), sin(la))
			var side = (1 if lane_i % 2 == 0 else -1) * (0.15 if Meta.map_id == "cross" else 1.0)
			var p
			if Meta.map_id == "line":
				# 회랑: 공격 방향이 고정이라 사람처럼 길 위·아래 가장자리에서 길을 가로질러 겨눈다
				var k = ts.size()
				var ud = 1 if k % 2 == 0 else -1
				p = c + ld * (130 + 95 * (k / 2)) + Vector2(0, ud * (main.LINE_HALF + 30))
				main._place_tower(p, Vector2(0, -ud))
			elif _smart():
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
		print("RESULT wave=", main.wave, " score=", main.score, " mul=", Modes.mul(), " ", main._perk_text(), " towers=", ts)
		# 죽음 기록: 웨이브마다 새어 든 구체 수·방향·종류 (tools/run.sh bots가 모아 보여 줌)
		for e in (main.leak_log if "leak_log" in main else []):
			if e["n"] > 0:
				print("LEAKS w=%d n=%d dmg=%d towers=%d lanes=%d kinds=%s dirs=%s" % [e["w"], e["n"], e["dmg"], e["towers"], e["lanes"], JSON.stringify(e["kinds"]), JSON.stringify(e["dirs"])])
		return true
	return false

var adapt_w := -1
## 오브젝트가 길목 a를 지키는지: 길목 선 가까이(120)에 있고, 길목 바깥쪽을 겨눔
func serves(t, a) -> bool:
	if Meta.map_id == "line":
		return true
	var c = main.core()
	var ld = Vector2(cos(a), sin(a))
	var far = c + ld * (1200 if Meta.map_id == "line" else 600)
	var q = Geometry2D.get_closest_point_to_segment(t.position, c, far)
	return t.position.distance_to(q) < 120 and absf(angle_difference(t.dir.angle(), (far - t.position).angle())) < 0.35

func _rearrange():
	var c = main.core()
	var ls = main.lanes.map(func(a): return eff_lane(a))
	for t in main.towers.get_children():
		if ls.any(func(a): return serves(t, a)):
			continue
		# 지키는 오브젝트가 가장 적은 길목
		var la = ls[0]
		var fewest = 999
		for a in ls:
			var cnt = main.towers.get_children().filter(func(o): return o != t and serves(o, a)).size()
			if cnt < fewest: fewest = cnt; la = a
		lane_i += 1
		var ld = Vector2(cos(la), sin(la))
		var side = (1 if lane_i % 2 == 0 else -1) * (0.15 if Meta.map_id == "cross" else 1.0)
		for k in 6:
			var p
			if _smart():
				p = c + ld * (90 + 25 * ((lane_i + k) % 3) + 30 * k) + ld.orthogonal() * 22 * side
			else:
				p = c + ld * (150 + 30 * ((lane_i + k) % 3) + 30 * k) + ld.orthogonal() * 70 * side
			if main._tower_at(p, t) == null and p.distance_to(c) > 60:
				t.position = p.clamp(main.field_rect().position, main.field_rect().end)
				t.dir = ld if _smart() else (c + ld * 600 - p).normalized()
				t.queue_redraw()
				break

# 소용돌이 맵: 구체가 반지름 r을 지날 때의 각도
func eff_lane(a):
	if Meta.map_id != "spiral": return a
	var c = main.core()
	var p = c + Vector2(cos(a), sin(a)) * 650
	while p.distance_to(c) > 170:
		p += (c - p).normalized().rotated(0.6) * 4.0
	return (p - c).angle()

## 사람처럼 배치(중앙 가까이에서 길목 바깥쪽을 겨눔). tools/run.sh는 기본으로 켬, SMART=0이면 예전 봇
func _smart() -> bool:
	return not OS.get_environment("SMART") in ["", "0"]


## BOT_ELEM·BOT_PAT·BOT_MOD: 선택지의 그 종류 카드를 전부 정한 것으로 바꾼다 (축 하나만 고정해 효율 비교)
func _force_offer():
	for o in main.offer:
		if o["type"] == "elem" and OS.get_environment("BOT_ELEM") != "":
			o["e"] = int(OS.get_environment("BOT_ELEM"))
		elif o["type"] == "pat" and OS.get_environment("BOT_PAT") != "":
			o["id"] = OS.get_environment("BOT_PAT")
		elif o["type"] == "mod" and OS.get_environment("BOT_MOD") != "":
			o["id"] = OS.get_environment("BOT_MOD")
