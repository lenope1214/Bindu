extends SceneTree
## 후반 부하 측정: 오브젝트 16개(공격방식·속성 3종·강화 10개씩)와 구체 400개로 30웨이브를 돌려
## 배속마다 프레임 시간(헤드리스는 기다리지 않고 바로 다음 프레임을 돌리므로 프레임 사이 시간 = 한 프레임 비용)과
## 화면 위 구체·탄 수를 찍는다.
## 사용: tools/run.sh perf  (헤드리스라 그리기 비용은 빠짐. 그리기까지 보려면 창을 띄워 직접 실행)
var main
var f := 0
var stage := 0
var speeds := [1.0, 4.0, 8.0]
var samples: Array = []
var counts := Vector3.ZERO
var last_us := 0

func _initialize():
	seed(7)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _setup() -> void:
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
	main.wave = 29
	main._start_wave()
	main.to_spawn = 400
	main.spawn_interval = 0.05


func _process(_d):
	f += 1
	if f == 3:
		_setup()
		return false
	if f < 3:
		return false
	main.core_hp = 99999
	main.to_spawn = maxi(main.to_spawn, 50)  # 웨이브가 끝나지 않게
	main.game_speed = speeds[stage]
	var now := Time.get_ticks_usec()
	if f > 120:  # 구체가 화면에 들어올 때까지 기다린 뒤 잰다
		samples.append((now - last_us) / 1000.0)
		counts += Vector3(main.live_orbs.size(), main.projectiles.get_child_count(), main.zones.get_child_count())
	last_us = now
	if samples.size() >= 600:
		samples.sort()
		var avg := 0.0
		for s in samples:
			avg += s
		avg /= samples.size()
		counts /= samples.size()
		print("PERF x%d: 평균 %.2fms · 95%% %.2fms · 최대 %.2fms (구체 %d · 탄 %d · 장판 %d)" % [roundi(speeds[stage]), avg, samples[int(samples.size() * 0.95)], samples[-1], roundi(counts.x), roundi(counts.y), roundi(counts.z)])
		samples.clear()
		counts = Vector3.ZERO
		stage += 1
		f = 3
		if stage >= speeds.size():
			quit()
	return false
