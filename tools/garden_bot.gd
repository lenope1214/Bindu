extends SceneTree
# 정원 봇: 정원 판을 자동으로 사고 놓으며 돌린다 (성장 곡선·벽·성능 점검).
# 사용: tools/run.sh garden [시드] [웨이브=40]  (또는 godot --headless --fixed-fps 60 --path . -s tools/garden_bot.gd -- <시드> <웨이브>)
# 환경 변수: SPEED(배속, 기본 8) REBIRTHS(환생 수로 시작) MINS(실제 시간 제한, 분)
# 출력: 웨이브마다 "W 웨이브 이슬 오브젝트 게임시간 ms=프레임당 계산 평균/최대", 물러나면 "RETREAT", 끝에 "RESULT"
var main
var frames := 0
var target := 40
var last_w := -1
var retreats := 0
var game_t := 0.0
var start_ms := 0
var lane_i := 0
var pt_sum := 0.0  # 이번 웨이브 프레임당 계산 시간(ms) 합·최대 (후반 렉 점검)
var pt_n := 0
var pt_max := 0.0


func _initialize():
	var args = OS.get_cmdline_user_args()
	seed(int(args[0]) if args.size() > 0 else 1)
	target = int(args[1]) if args.size() > 1 else 40
	if FileAccess.file_exists(Garden.RUN_PATH):
		DirAccess.remove_absolute(Garden.RUN_PATH)
	Garden.on = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	if OS.get_environment("REBIRTHS") != "":
		Garden.rebirths = int(OS.get_environment("REBIRTHS"))
	start_ms = Time.get_ticks_msec()


func _process(_d):
	frames += 1
	main.game_speed = float(OS.get_environment("SPEED")) if OS.get_environment("SPEED") != "" else 8.0
	if main.phase == 3:
		game_t += _d * main.game_speed
		var pt := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		pt_sum += pt; pt_n += 1; pt_max = maxf(pt_max, pt)
	if main.wave < last_w:
		retreats += 1
		print("RETREAT from=", last_w, " to=", main.wave, " dew=", int(Garden.dew), " towers=", main.towers.get_child_count())
	if main.wave != last_w and main.phase == 0:
		last_w = main.wave
		var tl := 0
		for t in main.towers.get_children():
			tl += t.total_level()
		print("W ", main.wave, " lanes=", main.lanes.size(), " core=", main.core_hp, " dew=", int(Garden.dew), " towers=", main.towers.get_child_count(), " levels=", tl, " t=", int(game_t + 3.0 * main.wave), " rate=", snappedf(Garden.rate, 0.1), " ms=", snappedf(pt_sum / maxi(pt_n, 1), 0.1), "/", snappedf(pt_max, 0.1), " perks=", main.perks)
		pt_sum = 0.0; pt_n = 0; pt_max = 0.0
	var mins := int(OS.get_environment("MINS")) if OS.get_environment("MINS") != "" else 20
	if main.wave >= target or Time.get_ticks_msec() - start_ms > mins * 60000:
		print("RESULT wave=", main.wave, " best=", Garden.best, " retreats=", retreats, " game_secs=", int(game_t + 3.0 * main.wave), " towers=", main.towers.get_child_count(), " dew=", int(Garden.dew), " seeds_if_rebirth=", Garden.seeds_for(Garden.best))
		var ms := {}
		for k in Garden.mastery:
			ms[k] = int(Garden.mastery[k])
		print("MASTERY ", ms)
		return true
	if main.phase == 7:
		main._cancel_step()
	if main.phase != 0:
		return false
	if main.perk_mode:
		main._on_perk(main.perk_offer[randi() % main.perk_offer.size()])
		return false
	if not _buy():
		main._start_wave()
	return false


## 살 수 있는 것 하나를 사서 놓는다. 살 게 없으면 false.
func _buy() -> bool:
	var ts = main.towers.get_children()
	var n = ts.size()
	var want = main.lanes.size() + 1 + main.wave / 8
	for o in main.offer:
		if o["type"] != "elem":
			continue
		# 새 오브젝트: 길목보다 적으면, 또는 레벨업보다 싸면
		var newc = Garden.cost_new(n)
		if n < Garden.MAX_TOWERS and Garden.dew >= newc and (n < want or newc < _cheapest_level(o, ts)):
			main.picked = o
			main._garden_pay(newc)
			_place_new(o)
			main._after_place()
			return true
	# 반응·레벨업·공격방식·강화 중 가장 싼 것
	var best = null
	var best_t = null
	var best_c = 1e18
	for o in main.offer:
		for t in ts:
			if not t.can_take(o):
				continue
			var c = 0
			match o["type"]:
				"elem": c = Garden.cost_elem_on(t, o["e"], n) * (0.5 if not Elem.new_reactions(t.eff_now(), o["e"]).is_empty() else 1.0)
				"pat":
					if not t.can_pattern(o["id"]): continue
					c = Garden.cost_pat(t, o["id"])
				"mod": c = Garden.cost_mod(t, o["id"]) * 0.8
				"link": c = Garden.cost_link(main._garden_links()) * 1.2
			if c < best_c and Garden.dew >= _real(o, t, n):  # 지금 살 수 있는 것 중에서 (반응 할인으로 못 사는 걸 고르고 멈추던 것)
				best_c = c; best = o; best_t = t
	if best == null:
		if Garden.dew > Garden.REROLL_COST * 8:
			main._on_reroll()
			return true
		return false
	main._on_pick(best)
	if best["type"] == "elem":
		main._place_on(best_t)
	else:
		main._apply_card(best_t)
	if main.phase == 1:
		main._back_to_choose()
	return true


func _real(o, t, n) -> int:
	match o["type"]:
		"elem": return Garden.cost_elem_on(t, o["e"], n)
		"pat": return Garden.cost_pat(t, o["id"])
		"mod": return Garden.cost_mod(t, o["id"])
		"link": return Garden.cost_link(main._garden_links())
	return 0


func _cheapest_level(o, ts) -> float:
	var low = 1e18
	for t in ts:
		if t.can_take(o):
			low = minf(low, Garden.cost_elem_on(t, o["e"], ts.size()))
	return low


func _place_new(o) -> void:
	var c = main.core()
	var ts = main.towers.get_children()
	var la = main.lanes[0]
	var fewest = 999
	for a in main.lanes:
		var cnt = 0
		for t in ts:
			if absf(angle_difference((t.position - c).angle(), a)) < 0.4:
				cnt += 1
		if cnt < fewest:
			fewest = cnt; la = a
	lane_i += 1
	var ld = Vector2(cos(la), sin(la))
	for k in 8:
		var p = c + ld * (90 + 30 * (k % 4) + 25 * (lane_i % 3)) + ld.orthogonal() * 30 * (1 if (lane_i + k) % 2 == 0 else -1) * (1 + k / 4)
		p = p.clamp(main.field_rect().position, main.field_rect().end)
		if main._tower_at(p) == null and p.distance_to(c) > 60:
			main._place_tower(p, ld)
			return
	main._place_tower(c + ld * 200, ld)
