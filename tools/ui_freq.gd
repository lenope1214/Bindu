extends SceneTree
## UI 갱신 빈도 측정: 장면마다 600프레임 동안 화면 요소(CanvasItem)가 몇 번 다시 그려지고(draw 신호),
## 글(text)이 몇 번 바뀌는지 세고, 프레임 시간을 _process(노드 처리)·그 밖(다시 그리기·배치·출력)으로 나눠 찍는다.
## 장면: ready(쉬는 시간, 오브젝트 16개) · choose(카드 선택) · wave(구체 250개 웨이브, 1배속)
## 사용: tools/run.sh uifreq  (헤드리스: 실제 GPU 그리기는 빠지고 스크립트 _draw·글 모양 계산은 들어간다)
var main
var f := 0
var scene := 0
const SCENES := ["ready", "choose", "wave"]
const N := 600
const WARM := 120
var draws := {}  # 경로 → 횟수
var texts := {}  # 경로 → 바뀐 횟수
var last_text := {}  # 노드 id → 글
var watched := {}  # 노드 id → true
var frame_us: Array = []
var proc_us: Array = []
var poll_us := 0
var last := 0
var t0 := 0
var t1 := 0
var world: Array = []
var warm := 0
var why := OS.get_environment("WHY") == "1"
var causes := {}
var draw_us := {}  # 경로 → 신호로 그린 함수 시간 합


class Mark extends Node:
	var cb: Callable
	func _process(_d):
		cb.call()


func _initialize():
	seed(7)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var a := Mark.new()
	a.process_priority = -1000000
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	a.cb = func(): t0 = Time.get_ticks_usec()
	root.add_child(a)
	var b := Mark.new()
	b.process_priority = 1000000
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.cb = func(): t1 = Time.get_ticks_usec()
	root.add_child(b)


func _place() -> void:
	if main.title_label.visible:
		main.title_label.visible = false
		main._start_choose()
	var c: Vector2 = main.center()
	for i in 16:
		var a := TAU * i / 16
		main.picked = {"e": Elem.ALL[i % Elem.ALL.size()], "lv": 3}
		main._place_tower(c + Vector2(cos(a), sin(a)) * (150 + 70 * (i % 3)), Vector2(cos(a + 1.6), sin(a + 1.6)))
		var t = main.towers.get_child(i)
		t.set_pattern(Pat.PATTERN_IDS[i % Pat.PATTERN_IDS.size()])
		for k in 2:
			t.add(Elem.ALL[(i * 3 + k * 5 + 1) % Elem.ALL.size()], 2)
		for k in 5:
			t.add_mod(Pat.MOD_IDS[i % Pat.MOD_IDS.size()])
		t.eff = t.eff_now()
	main.core_hp = 99999
	main.core_max = 99999
	world = [main.orbs, main.towers, main.projectiles, main.zones, main.fx_layer]


func _begin(s: String) -> void:
	match s:
		"ready":
			main.wave = 12
			main._enter_ready()
			main.countdown = -1.0
		"choose":
			main.wave = 13
			main._start_choose()
		"wave":
			Rules.orb_hp = 40.0
			main.wave = 29
			main._start_wave()
			main.to_spawn = 400
			main.spawn_interval = 0.02
			main.game_speed = 1.0


func _is_world(n: Node) -> bool:
	if n == main:
		return true
	for w in world:
		if w == n or w.is_ancestor_of(n):
			return true
	return false


func _watch(n: Node) -> void:
	if n is CanvasItem and not watched.has(n.get_instance_id()):
		watched[n.get_instance_id()] = true
		var key := _key(n)
		# 신호로 그리는 함수(_draw_info 등)는 감싸서 시간을 잰다
		for c in n.get_signal_connection_list("draw"):
			var cb: Callable = c["callable"]
			n.draw.disconnect(cb)
			n.draw.connect(func():
				var u := Time.get_ticks_usec()
				cb.call()
				if f > WARM:
					draw_us[key] = draw_us.get(key, 0) + Time.get_ticks_usec() - u)
		n.draw.connect(func(): if f > WARM: draws[key] = draws.get(key, 0) + 1)
		if why and n is Control and not _is_world(n):
			# WHY=1: 크기·자리·테마가 바뀐 곳(호출 줄)을 센다. 다시 그리기의 원인을 찾을 때
			for sg in ["item_rect_changed", "theme_changed", "minimum_size_changed"]:
				n.connect(sg, func():
					if f > WARM:
						var st: Array = get_stack()
						var k: String = "%s %s < %s" % [key, sg, " < ".join(st.slice(1, 4).map(func(x): return "%s:%d" % [x["function"], x["line"]]))]
						causes[k] = causes.get(k, 0) + 1)
	for c in n.get_children():
		_watch(c)


func _key(n: Node, with_text := true) -> String:
	if _is_world(n):
		# 전장 쪽은 종류별로 묶는다 (구체 300개를 따로 찍지 않게)
		if n == main:
			return "[전장] main(배경)"
		for w in world:
			if w != n and w.is_ancestor_of(n):
				return "[전장] %s/*" % w.name
		return "[전장] " + str(n.name)
	var p := str(main.get_path_to(n))
	# 이름 없는 노드(@Label@12)는 종류만 남긴다 (카드·줄 등 여럿인 것은 하나로 묶인다)
	var r := RegEx.create_from_string("@([A-Za-z0-9]+)@[0-9]+")
	p = r.sub(p, "$1", true)
	if with_text and (n is Label or n is Button or n is RichTextLabel):
		var t := str(n.text).replace("\n", " ").left(18)
		if t != "":
			p += " \"%s\"" % t
	var ms := PackedStringArray()
	for c in n.get_signal_connection_list("draw"):
		var cb: Callable = c["callable"]
		if cb.get_object() != self:
			ms.append(cb.get_method())
	if not ms.is_empty():
		p += " [%s]" % ",".join(ms)
	return p


func _poll_text(n: Node) -> void:
	if (n is Label or n is Button or n is RichTextLabel) and not _is_world(n):
		var id := n.get_instance_id()
		var t: String = n.text
		if last_text.has(id) and last_text[id] != t:
			var k := _key(n, false)
			texts[k] = texts.get(k, 0) + 1
		last_text[id] = t
	for c in n.get_children():
		_poll_text(c)


func _process(_d):
	f += 1
	var now := Time.get_ticks_usec()
	if f == 3 and scene == 0:
		_place()
	if f == 4:
		_begin(SCENES[scene])
	if f < 5:
		last = now
		return false
	if SCENES[scene] == "wave":
		main.core_hp = 99999
		main.to_spawn = maxi(main.to_spawn, 50)
		if main.live_orbs.size() < 250 and warm < 4000 and f == WARM:
			warm += 1
			f -= 1  # 구체가 쌓일 때까지 WARM에 머문다
	if f > WARM:
		frame_us.append(now - last)
		proc_us.append(t1 - t0)
	if f % 30 == 0:
		_watch(main)
	var p0 := Time.get_ticks_usec()
	_poll_text(main)
	var pd := Time.get_ticks_usec() - p0
	if f > WARM:
		poll_us += pd
	last = Time.get_ticks_usec()
	if f >= WARM + N:
		_report(SCENES[scene])
		scene += 1
		f = 3
		draws.clear()
		texts.clear()
		causes.clear()
		draw_us.clear()
		last_text.clear()
		frame_us.clear()
		proc_us.clear()
		poll_us = 0
		if scene >= SCENES.size():
			quit()
	return false


func _report(s: String) -> void:
	var sec := N / 60.0
	var fa := 0.0
	var pa := 0.0
	for i in frame_us.size():
		fa += frame_us[i]
		pa += proc_us[i]
	fa = (fa - poll_us) / frame_us.size() / 1000.0
	pa /= frame_us.size() * 1000.0
	var ui_d := 0
	var w_d := 0
	for k in draws:
		if k.begins_with("[전장]"):
			w_d += draws[k]
		else:
			ui_d += draws[k]
	var ui_t := 0
	for k in texts:
		ui_t += texts[k]
	print("UIFREQ %s: 프레임 %.2fms (노드 처리 %.2f · 그 밖 %.2f) · UI 다시 그리기 %.1f/프레임 · 전장 %.1f/프레임 · UI 글 바뀜 %.2f/프레임 · 구체 %d" % [s, fa, pa, fa - pa, ui_d / float(N), w_d / float(N), ui_t / float(N), main.live_orbs.size()])
	var ks := draws.keys()
	ks.sort_custom(func(a, b): return draws[a] > draws[b])
	for k in ks.slice(0, 25):
		print("UIFREQ %s draw %6.1f/s %s%s" % [s, draws[k] / sec, k, " · %.3fms/프레임" % (draw_us[k] / 1000.0 / N) if draw_us.has(k) else ""])
	ks = texts.keys()
	ks.sort_custom(func(a, b): return texts[a] > texts[b])
	for k in ks.slice(0, 15):
		print("UIFREQ %s text %6.1f/s %s" % [s, texts[k] / sec, k])
	ks = causes.keys()
	ks.sort_custom(func(a, b): return causes[a] > causes[b])
	for k in ks.slice(0, 40):
		print("UIFREQ %s why %6.1f/s %s" % [s, causes[k] / sec, k])
