extends SceneTree
# 자동 플레이 봇: 반응 생기면 겹치기, 아니면 진입 방향을 가로지르게 새로 설치.
# 사용: tools/run.sh bots (또는 godot --headless --fixed-fps 60 --path . -s tools/bot.gd -- <시드> [stack])
# 환경 변수: BOT_ELEM=<속성 번호>·BOT_PAT=<공격방식 id>·BOT_MOD=<강화 id>(그 종류 카드를 전부 이것으로 바꿈, 조합 효율 측정용) WLOG=1(GOD일 때 웨이브마다 오브젝트별 피해 TW 줄)
# SKILL=0(중앙 기술 끔, 기본은 자동 사용) SKILLSET=0|1|2(기술 묶음) JAM=0(방해 구체 끔) LEY=0(기맥 끔)
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
var stages: Array = []  # STAGES: 잴 웨이브 (그 사이 웨이브는 전투 없이 넘기고 선택지만 고른다)
var stage_w := -1  # 지금 재는 웨이브
var stage_ms := 0
var fast_now := false  # 지금 사이 웨이브를 빨리 넘기는 중
var core0 := -1  # 재기 전 중앙 최대 체력


## MODES=rush,steel: 첫 프레임에 모드를 켠다 (없으면 모두 끔: 시험 저장에 남은 모드가 섞이지 않게).
func _set_modes():
	modes_set = true
	# 중앙 기술: 봇은 자동으로 쓴다 (SKILL=0이면 기술 없이, SKILLSET=0|1|2 묶음)
	main.abilities_system.auto_skills = OS.get_environment("SKILL") != "0"
	Meta.skill_set = int(OS.get_environment("SKILLSET")) if OS.get_environment("SKILLSET") != "" else 0
	Modes.set_on(Array(OS.get_environment("MODES").split(",", false)))
	# BOT_PATCH='{"orb_hp":0.8}': 온라인 패치 rules.all에 넣은 것처럼 (패치 전 수치 시험)
	if OS.get_environment("BOT_PATCH") != "":
		Patch.pending = {"id": -1, "data": {"rules": {"all": JSON.parse_string(OS.get_environment("BOT_PATCH"))}}}
	main.run_flow_system._apply_rules()
	# VS=1: 대결 판 배율만 켠 혼자 판 (보낸 구체는 없음). COOP=N: N명 협동 근사 (구체·체력은 N명, 카드는 쉬는 시간마다 N명 몫)
	main.vs_on = OS.get_environment("VS") != ""
	if OS.get_environment("COOP") != "":
		main.coop_n = int(OS.get_environment("COOP"))
		main.coop_orbs = 1.0 + float(Rules.tune["coop_orb_per"]) * (main.coop_n - 1)
	main.hud_system.start_modes()
	main.picks_left = maxi(Rules.open_picks, Rules.picks)
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
			print("  ORB kind=", o.kind, " pos=", o.position, " d=", o.position.distance_to(main.viewport_system.core()), " hp=", o.hp, "/", o.max_hp, " sh=", o.shield, " spd=", o.speed, " slow=", o.slow_factor, " root=", o.root_timer, " frozen=", o.frozen_t, " prison=", o.prison_t, " push=", o.push_budget, " q=", o.is_queued_for_deletion(), " target=", o.target, " age=", o.age, " resist=", o.resist_e, " sturdy=", o.sturdy)
		for t in main.towers.get_children():
			print("  TW ", t.title(), " @", t.position, " ", t.extras_text(), " rx=", t.reactions().map(func(r): return r["name"]))
		quit()
	if OS.get_environment("STAGES") != "" and _stages():
		return true
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
		main.run_flow_system._apply_rules()
	if Meta.line_flip != (OS.get_environment("FLIP") != ""):
		Meta.line_flip = not Meta.line_flip  # 회랑: 구체가 왼쪽에서
		main.lanes.clear()
		main.waves_system._roll_lanes()
	if OS.get_environment("MAP") != "" and Meta.map_id != OS.get_environment("MAP"):
		Meta.map_id = OS.get_environment("MAP")
		main.lanes.clear()
		main.waves_system._roll_lanes()
	if OS.get_environment("DIAG") != "" and main.phase == 0 and main.wave != last_wave:
		last_wave = main.wave
		var info = []
		for t in main.towers.get_children(): info.append("%s@%d,%d dir%.0f dealt%d" % [t.title(), t.position.x, t.position.y, rad_to_deg(t.dir.angle()), t.dealt])
		print("W", main.wave, " picks=", main.picks_left, " rr=", main.rerolls_left, " perk=", main.perk_mode, " core=", main.core_hp, " lanes=", main.lanes.map(func(a): return int(rad_to_deg(a))), " ", info)
	main.auto_start = true
	main.game_speed = float(OS.get_environment("SPEED")) if OS.get_environment("SPEED") != "" else 1.0
	if fast_now:
		main.game_speed = float(OS.get_environment("FAST_SPEED")) if OS.get_environment("FAST_SPEED") != "" else 16.0
	if main.phase == 6: main.run_flow_system._start_wave()
	# SKIP=3: SKIP_FROM(기본 8)웨이브부터 웨이브 넘기기를 3개씩 쓰고, 멈추면 쌓인 것을 다 고른 뒤 다시 넘긴다
	if not main.bank_picks.is_empty() or main.bank_perks > 0:
		skip_w = main.wave  # 넘기기를 멈춘 쉬는 시간: 이번엔 다 고른다
	if OS.get_environment("SKIP") != "" and main.phase == 0 and main.wave >= (int(OS.get_environment("SKIP_FROM")) if OS.get_environment("SKIP_FROM") != "" else 8) and main.wave != skip_w and main.bank_picks.is_empty() and main.bank_perks == 0 and main.run_flow_system._can_skip():
		skip_w = main.wave
		Meta.skip_n = int(OS.get_environment("SKIP"))
		main.run_flow_system._on_skip()
		if OS.get_environment("DIAG") != "": print("SKIP w=", main.wave, " bank=", main.bank_picks, " rr=", main.bank_rerolls)
		return false
	if main.perk_mode:
		# BOT_PERK=<id>: 특성 하나의 효율을 재려고 그 특성을 고를 수 있는 한 매번 고른다 (선택지에 없어도. 빠지는 조건은 지킴: 조화는 한 번 등)
		var want := OS.get_environment("BOT_PERK")
		var forced = null
		if want != "":
			for pk in main.perks_system._perk_pool():
				if pk["id"] == want:
					forced = pk
		main.perks_system._on_perk(forced if forced != null else main.perk_offer[randi() % main.perk_offer.size()])
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
				if o["type"] in ["mod", "link", "trig"]:
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
			main.cards_system._on_pick(pick); return false
		# 상한: 넣을 수 없는 오브젝트면 넣을 수 있는 다른 오브젝트로, 없으면 속성은 새로 설치
		if target and not target.can_take(pick):
			target = null
			for t in ts:
				if t.can_take(pick): target = t; break
		if pick["type"] != "elem" and target == null:
			for t in ts:
				if t.can_take(pick): target = t; break
		if pick["type"] == "elem" and target == null and pick["e"] == Elem.STAR and main.cards_system.star_full():
			pick = null  # 별·행성이 다 참: 다른 카드 (사람도 새로 놓을 수 없음)
			for o in offer:
				if o["type"] == "elem" and o["e"] != Elem.STAR: pick = o; break
			if pick == null:
				main.cards_system._on_reroll()
				if main.phase == 0 and main.rerolls_left <= 0 and main.offer == offer:
					main.picks_left = 1; main.cards_system._after_place()
				return false
		main.cards_system._on_pick(pick)
		if pick["type"] != "elem":
			if target == null: target = ts[0] if ts.size() > 0 else null
			if pick["type"] == "pat" and target and not target.can_pattern(pick["id"]): target = null
			if target == null:
				main.interaction_system._back_to_choose(); main.cards_system._on_reroll()
				if main.phase == 0 and main.rerolls_left <= 0 and main.offer == offer:
					main.picks_left = 1; main.cards_system._after_place()
				return false
			main.cards_system._apply_card(target)
		elif target:
			main.hud_system._show_toast(target.add(pick["e"], pick["lv"]))
			main.cards_system._after_place()
		else:
			var c = main.viewport_system.core()
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
				main.interaction_system._place_tower(p, Vector2(0, -ud))
			elif _smart():
				# 사람처럼: 중앙 가까이에서 진입 방향 그대로 겨눈다
				p = c + ld * (90 + 25 * (lane_i % 3)) + ld.orthogonal() * 22 * side
				main.interaction_system._place_tower(p, ld)
			else:
				p = c + ld * (150 + 30 * (lane_i % 3)) + ld.orthogonal() * 70 * side
				# 직선탄은 진입 방향을 향해 겨눈다
				main.interaction_system._place_tower(p, (c + ld * 600 - p).normalized())
			main.cards_system._after_place()
	# CAP=<웨이브>: 그 웨이브에 닿으면 끝 (도파민처럼 판이 아주 길어지는 규칙에서 특성·카드 비교를 빨리)
	var cap := int(OS.get_environment("CAP")) if OS.get_environment("CAP") != "" else 0
	if main.phase == 4 or cap > 0 and main.wave >= cap or frames > 60 * 60 * (int(OS.get_environment("MINS")) if OS.get_environment("MINS") != "" else 25) / main.game_speed:
		var ts = []
		for t in main.towers.get_children(): ts.append(t.title())
		print("RESULT wave=", main.wave, " score=", main.score, " mul=", Modes.mul(), " skills=", main.skill_used, " ", main.perks_system._perk_text(), " towers=", ts)
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
	var c = main.viewport_system.core()
	var ld = Vector2(cos(a), sin(a))
	var far = c + ld * (1200 if Meta.map_id == "line" else 600)
	var q = Geometry2D.get_closest_point_to_segment(t.position, c, far)
	return t.position.distance_to(q) < 120 and absf(angle_difference(t.dir.angle(), (far - t.position).angle())) < 0.35

func _rearrange():
	var c = main.viewport_system.core()
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
			if main.interaction_system._tower_at(p, t) == null and p.distance_to(c) > 60:
				t.position = p.clamp(main.combat_system.field_rect().position, main.combat_system.field_rect().end)
				t.dir = ld if _smart() else (c + ld * 600 - p).normalized()
				t.queue_redraw()
				break

# 소용돌이 맵: 구체가 반지름 r을 지날 때의 각도
func eff_lane(a):
	if Meta.map_id != "spiral": return a
	var c = main.viewport_system.core()
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


## STAGES=5,10,...(1이면 기본 목록): 잴 웨이브만 실제로 싸우고, 사이 웨이브는 나온 구체를 바로 처치해(처치 보상은 그대로) 쉬는 시간 선택지만 빠르게 고른다.
## 그 웨이브까지 받은 만큼의 카드·특성(웨이브에 맞는 Lv2 확률 그대로)으로 그 웨이브를 치른 결과를 STAGE 줄로 남긴다.
## 재는 웨이브는 중앙이 죽지 않고(새어 든 피해만 기록), 마지막 웨이브를 재면 끝.
const STAGE_DEFAULT := [5, 10, 15, 20, 30, 40, 50, 75, 100, 150, 200]
func _stages() -> bool:
	if stages.is_empty():
		var env := OS.get_environment("STAGES")
		stages = STAGE_DEFAULT.duplicate() if env == "1" else Array(env.split(",", false)).map(func(x): return int(x))
	fast_now = false
	if main.phase == 3:
		if main.wave in stages:
			if stage_w != main.wave:
				stage_w = main.wave
				stage_ms = frames
				if core0 < 0:
					core0 = main.core_max
				main.core_hp = 99999
				main.core_max = 99999
				for t in main.towers.get_children():
					t.dealt = 0.0
					t.src = {}
		else:
			# 사이 웨이브: 나온 구체를 바로 처치한다 (점수·보스 처치 새로고침·중앙 회복·분열 등 처치 보상은 그대로 생김)
			fast_now = true
			for o in main.live_orbs:
				if is_instance_valid(o) and o.hp > 0.0:
					o.hp = 0.0
			main.core_hp = maxi(main.core_hp, main.core_max)
	elif stage_w >= 0 and main.wave != stage_w:
		var lost: int = 0
		var leaked: int = 0
		for e in (main.leak_log if "leak_log" in main else []):
			if e["w"] == stage_w:
				leaked = e["n"]
				lost = e["dmg"]
				if OS.get_environment("STAGE_LOG") != "":
					print("STAGELEAK w=%d kinds=%s" % [stage_w, JSON.stringify(e["kinds"])])
					for t in main.towers.get_children():
						print("STAGETW %s dealt=%.0f src=%s" % [t.title(), t.dealt, JSON.stringify(t.src)])
		var dealt := 0.0
		var share := 0.0
		for t in main.towers.get_children():
			dealt += t.dealt
			for k in t.src:
				if str(k).begins_with("share:"):
					share += t.src[k]
		print("STAGE w=%d n=%d leaked=%d lost=%d secs=%.1f towers=%d share=%.3f" % [stage_w, main.wave_size(stage_w), leaked, lost, (frames - stage_ms) / 60.0 * main.game_speed, main.towers.get_child_count(), share / maxf(dealt, 1.0)])
		main.core_max = core0
		main.core_hp = core0
		if stage_w >= stages.max():
			print("RESULT wave=", stage_w, " score=", main.score, " mul=", Modes.mul())
			return true
		stage_w = -1
	return false
