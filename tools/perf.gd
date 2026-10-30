extends SceneTree
## 후반 부하 측정: 오브젝트 16개(공격방식·속성 3종·강화 10개씩)로 30웨이브를 돌려
## 배속마다 프레임 시간(기다리지 않고 바로 다음 프레임을 돌리므로 프레임 사이 시간 = 한 프레임 비용)과
## 화면 위 구체·탄 수를 찍는다. 구체 체력을 크게 올려 화면 구체가 PERF_ORBS(기본 250)개 넘게 쌓인 뒤부터 잰다
## (예전엔 바로 죽어 60~90개만 남아 후반 부하가 나오지 않았다).
## 이어서 부분별(이동·목록·오브젝트 공격·장판·발사체 판정·처치·UI·효과) 계산 시간을 프레임당 ms로 찍는다.
## 사용: tools/run.sh perf (헤드리스, 그리기 비용 빠짐) / tools/run.sh perfwin (창을 띄워 그리기까지, 수직 동기 끔)
var main
var f := 0
var stage := 0
var speeds := [1.0, 4.0, 8.0]
var samples: Array = []
var counts := Vector3.ZERO
var last_us := 0
var goal := int(OS.get_environment("PERF_ORBS")) if OS.get_environment("PERF_ORBS") != "" else 250
var warm := 0  # 구체가 쌓이기를 기다린 프레임
var win := false  # 창 모드: 그리기 시간(CPU·GPU)도 재고, 끝에 층을 하나씩 숨겨 층별 그리기 비용을 잰다
var vp: RID
var rcpu := 0.0
var rgpu := 0.0
const HIDES := [[], ["Orbs"], ["Towers"], ["Projectiles", "Zones"], ["Fx"], ["Orbs", "Towers", "Projectiles", "Zones", "Fx"]]
var hide_i := -1

func _initialize():
	seed(7)
	if DisplayServer.get_name() != "headless":
		win = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		vp = root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _setup() -> void:
	if main.title_label.visible:  # 창 모드는 타이틀에서 시작한다: 헤드리스처럼 바로 판으로
		main.title_label.visible = false
		main._start_choose()
	var c: Vector2 = main.center()
	var n := 16
	for i in n:
		var a := TAU * i / n
		main.picked = {"e": Elem.ALL[i % Elem.ALL.size()], "lv": 3}
		main._place_tower(c + Vector2(cos(a), sin(a)) * (150 + 70 * (i % 3)), Vector2(cos(a + 1.6), sin(a + 1.6)))
		var t = main.towers.get_child(i)
		t.set_pattern(Pat.PATTERN_IDS[i % Pat.PATTERN_IDS.size()])
		for k in 2:
			t.add(Elem.ALL[(i * 3 + k * 5 + 1) % Elem.ALL.size()], 2)
		for k in 5:
			t.add_mod(Pat.MOD_IDS[i % Pat.MOD_IDS.size()])
			t.add_mod(Pat.MOD_IDS[(i + 3) % Pat.MOD_IDS.size()])
		t.eff = t.eff_now()
	main.core_hp = 99999
	main.core_max = 99999
	main.prof_on = true
	Rules.orb_hp = 40.0  # 잘 죽지 않게: 구체 수를 후반처럼 쌓는다
	main.wave = 29
	main._start_wave()
	main.to_spawn = 400
	main.spawn_interval = 0.02


func _process(_d):
	f += 1
	if f == 3:
		_setup()
		return false
	if f < 3:
		return false
	main.core_hp = 99999
	main.to_spawn = maxi(main.to_spawn, 50)  # 웨이브가 끝나지 않게
	main.game_speed = 1.0 if hide_i >= 0 else speeds[stage]
	var now := Time.get_ticks_usec()
	# 구체가 goal개 넘게 쌓일 때까지(최대 4000프레임) 기다린 뒤 잰다
	if samples.is_empty() and main.live_orbs.size() < goal and warm < 4000:
		warm += 1
		main.prof.clear()
		last_us = now
		return false
	if f <= 120:
		main.prof.clear()  # 잴 프레임만 더한다 (배속을 바꾼 직후 120프레임은 빼고)
	if f > 120:
		samples.append((now - last_us) / 1000.0)
		counts += Vector3(main.live_orbs.size(), main.projectiles.get_child_count(), main.zones.get_child_count())
		if win:
			rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			rgpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	last_us = now
	if samples.size() >= (300 if hide_i >= 0 else 600):
		samples.sort()
		var avg := 0.0
		for s in samples:
			avg += s
		avg /= samples.size()
		counts /= samples.size()
		var rt := " · 그리기 CPU %.2fms · GPU %.2fms" % [rcpu / samples.size(), rgpu / samples.size()] if win else ""
		rcpu = 0.0
		rgpu = 0.0
		if hide_i >= 0:
			print("PERF 그리기 x1 %s 숨김: 평균 %.2fms%s (구체 %d)" % [",".join(HIDES[hide_i]) if hide_i > 0 else "아무것도 안", avg, rt, roundi(counts.x)])
			_next_hide()
			return false
		print("PERF x%d: 평균 %.2fms · 95%% %.2fms · 최대 %.2fms (구체 %d · 탄 %d · 장판 %d)%s" % [roundi(speeds[stage]), avg, samples[int(samples.size() * 0.95)], samples[-1], roundi(counts.x), roundi(counts.y), roundi(counts.z), rt])
		var parts := PackedStringArray()
		for k in main.prof:
			parts.append("%s %.2f" % [k, main.prof[k] / 1000.0 / samples.size()])
		print("PERF x%d 부분(ms/프레임): %s" % [roundi(speeds[stage]), " · ".join(parts)])
		samples.clear()
		counts = Vector3.ZERO
		stage += 1
		f = 3
		if stage >= speeds.size():
			if win:
				_next_hide()
			else:
				quit()
	return false


## 창 모드 끝: 층을 하나씩 숨기고 1배속으로 300프레임씩 (숨긴 층만큼 빠지는 시간 = 그 층 그리기 비용)
func _next_hide() -> void:
	samples.clear()
	counts = Vector3.ZERO
	hide_i += 1
	if hide_i >= HIDES.size():
		quit()
		return
	for n in ["Orbs", "Towers", "Projectiles", "Zones", "Fx"]:
		main.get_node(n).visible = not n in HIDES[hide_i]
