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
var pt_sum := 0.0  # 이번 웨이브 프레임당 계산 시간(ms) 합·최대 (후반 렉 점검)
var pt_n := 0
var pt_max := 0.0
var core_min := 999  # 이번 웨이브 중 가장 낮았던 중앙 체력 (방치형 피해 빈도 점검)
var hit_waves := 0


func _initialize():
	var args = OS.get_cmdline_user_args()
	seed(int(args[0]) if args.size() > 0 else 1)
	target = int(args[1]) if args.size() > 1 else 40
	if FileAccess.file_exists(Garden.RUN_PATH):
		DirAccess.remove_absolute(Garden.RUN_PATH)
	Garden.on = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	Garden.auto_buy = false  # 자동 정원사는 기본 켬: 점검·촬영·봇은 직접 산다
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
		core_min = mini(core_min, main.core_hp)
	if main.wave < last_w:
		retreats += 1
		print("RETREAT from=", last_w, " to=", main.wave, " dew=", int(Garden.dew), " towers=", main.towers.get_child_count())
	if main.wave != last_w and main.phase == 0:
		last_w = main.wave
		var tl := 0
		for t in main.towers.get_children():
			tl += t.total_level()
		var lost: int = maxi(0, main.core_max - core_min) if core_min < 999 else 0
		if lost > 0:
			hit_waves += 1
		core_min = 999
		print("W ", main.wave, " lost=", lost, " lanes=", main.lanes.size(), " core=", main.core_hp, " dew=", int(Garden.dew), " towers=", main.towers.get_child_count(), " levels=", tl, " t=", int(game_t + 3.0 * main.wave), " rate=", snappedf(Garden.rate, 0.1), " ms=", snappedf(pt_sum / maxi(pt_n, 1), 0.1), "/", snappedf(pt_max, 0.1), " perks=", main.perks)
		pt_sum = 0.0; pt_n = 0; pt_max = 0.0
	var mins := int(OS.get_environment("MINS")) if OS.get_environment("MINS") != "" else 20
	if main.wave >= target or Time.get_ticks_msec() - start_ms > mins * 60000:
		print("RESULT wave=", main.wave, " best=", Garden.best, " retreats=", retreats, " hit_waves=", hit_waves, " game_secs=", int(game_t + 3.0 * main.wave), " towers=", main.towers.get_child_count(), " dew=", int(Garden.dew), " seeds_if_rebirth=", Garden.seeds_for(Garden.best))
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


## 살 수 있는 것 하나를 사서 놓는다 (게임의 자동 정원사와 같은 판단).
func _buy() -> bool:
	return Gardener.buy(main)
