extends SceneTree
# 그린 궤적 점검: 카드로 넣기 → 그리기(꺾기·길이 제한) → 웨이브에서 길 따라 맞히는지, 레벨업 길이·갈래, 4개 상한,
# 유도 차단, 저장·불러오기, 대격변, 카드 등장 비율. 실패하면 FAIL 줄과 함께 끝 코드 1.
var main
var fails := 0


func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _clear() -> void:
	for n in [main.towers, main.orbs, main.zones, main.projectiles]:
		for c in n.get_children():
			c.free()


func _new_tower(p: Vector2, d: Vector2) -> Tower:
	main.picked = {"type": "elem", "e": Elem.FIRE, "lv": 1}
	main._place_tower(p, d)
	return main.towers.get_child(main.towers.get_child_count() - 1)


func _give_path(t: Tower) -> void:
	main.picks_left = 5
	main.picked = {"type": "pat", "id": "path"}
	main._apply_card(t)


## a에서 b로 마우스를 4px씩 끄는 것처럼
func _drag(a: Vector2, b: Vector2) -> void:
	var n := ceili(a.distance_to(b) / 4.0)
	for i in n + 1:
		main._draw_extend(a.lerp(b, float(i) / n))


func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tutor = false
	_clear()
	main.wave = 5
	var tp: Vector2 = main.center() + Vector2(-420, 0)
	var t := _new_tower(tp, Vector2.RIGHT)

	# 1. 카드로 넣으면 그리기 단계
	_give_path(t)
	ok(t.pattern == "path" and t.plv == 1, "직선탄 → 그린 궤적")
	ok(main.phase == main.Phase.DRAW and main.draw_queue == [0], "카드를 넣으면 그리기 단계 (갈래 0)")
	ok(t.paths.size() == 1 and absf(Tower.poly_len(t.paths[0]) - 400.0) < 1.0, "그리기 전 기본 길: 곧게 400")

	# 2. 그리기: 오른쪽 200 → 아래 150 → 왼쪽 … (꺾기 2번), 길이 400에서 멈춤
	main._draw_input(_btn(true))
	_drag(tp, tp + Vector2(200, 0))
	_drag(tp + Vector2(200, 0), tp + Vector2(200, 150))
	_drag(tp + Vector2(200, 150), tp + Vector2(-100, 150))
	ok(main.draw_bends == 2, "꺾기 2번으로 셈 (%d)" % main.draw_bends)
	ok(absf(main.draw_len - 400.0) < 0.5 and main.draw_stop != "", "길이 400에서 멈춤 (%.1f, %s)" % [main.draw_len, main.draw_stop])
	main._draw_input(_btn(false))
	ok(main.phase == main.Phase.DRAW and main.draw_wait, "떼면 바로 넣지 않고 [적용]/[취소] 기다림")
	main.draw_ok_btn.pressed.emit()
	ok(main.phase != main.Phase.DRAW, "[적용]을 누르면 넣고 그리기 끝 (phase %d)" % main.phase)
	var L0 := Tower.poly_len(t.paths[0])
	ok(absf(L0 - 400.0) < 2.0, "저장된 길 길이 %.1f" % L0)
	ok(t.dir.dot(Vector2.RIGHT) > 0.99, "오브젝트 방향 = 첫 조각 방향")

	# 3. 꺾기 상한: 지그재그는 3번째 뒤에 멈춤
	main._start_draw(t, [0], false)
	main._draw_input(_btn(true))
	var p := tp
	for i in 6:
		var q := p + (Vector2(60, -60) if i % 2 == 0 else Vector2(60, 60))
		_drag(p, q)
		p = q
	ok(main.draw_bends == 3 and main.draw_stop.contains("꺾기"), "꺾기 3번에서 멈춤 (%d, %s)" % [main.draw_bends, main.draw_stop])
	# 완만한 곡선은 세지 않음 (반지름 150 반원)
	main._draw_begin_branch()
	main.draw_on = true
	main.draw_pts.append(tp)
	var c0 := tp + Vector2(0, 150)
	for k in 120:
		main._draw_extend(c0 + Vector2(0, -150).rotated(PI * k / 119.0))
	ok(main.draw_bends == 0, "완만한 곡선은 꺾기 0 (%d, 길이 %.0f)" % [main.draw_bends, main.draw_len])
	main._cancel_step()  # 이 길은 그대로
	ok(absf(Tower.poly_len(t.paths[0]) - L0) < 0.1, "취소하면 원래 길 그대로")

	# 4. 짧게 그리면 다시
	main._start_draw(t, [0], false)
	main._draw_input(_btn(true))
	_drag(tp, tp + Vector2(20, 0))
	main._draw_input(_btn(false))
	ok(main.phase == main.Phase.DRAW, "48보다 짧으면 확정 안 함")
	main._cancel_step()

	# 5. 웨이브: 직선탄이 못 닿는 아래쪽(길의 가로 구간, y+150)을 지나는 구체를 맞힘
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.wave_time = 10.0
	main.to_spawn = 0
	main.core_hp = 999
	t.dealt = 0.0
	var on_route := 0
	var spawn_t := 0.0
	for f in 60 * 20:
		spawn_t -= 1.0 / 60
		if spawn_t <= 0:
			spawn_t = 0.5
			var o = Orb.new(); o.main = main
			o.position = tp + Vector2(60, 150); o.target = tp + Vector2(800, 150)
			o.setup(Orb.Kind.NORMAL, 100000, 50)
			o.swirl = 0.0
			main.orbs.add_child(o)
		await process_frame
		for pr in main.projectiles.get_children():
			if pr.kind == "path" and pr.route_on:
				on_route += 1
				if f % 120 == 0 and OS.get_environment("DBG") != "":
					print("proj ", pr.position - tp, " travel ", pr.travel, " / ", pr.max_travel)
		if f % 120 == 0 and OS.get_environment("DBG") != "":
			for o in main.orbs.get_children():
				print("orb ", o.position - tp)
		for o in main.orbs.get_children():
			if o.position.x > tp.x + 700:
				o.queue_free()
	ok(t.dealt > 0.0, "길 위(y+150) 구체에 피해 %.1f" % t.dealt)
	ok(on_route > 0, "탄이 길을 따라감")
	main.wave_active = false
	_clear()

	# 6. 레벨업: Lv2·3 길이 늘면 다시 그리기, Lv4·5 갈래 추가, Lv6 그리기 없음
	main.phase = main.Phase.CHOOSE
	t = _new_tower(tp, Vector2.RIGHT)
	_give_path(t)
	main._cancel_step()
	for lv in [2, 3, 4, 5, 6]:
		_give_path(t)
		var drew: bool = main.phase == main.Phase.DRAW
		var q: Array = main.draw_queue.duplicate()
		if drew:
			main._cancel_step()
		match lv:
			2, 3: ok(t.plv == lv and drew and q == [0], "Lv%d: 길이 %d, 갈래 0 다시 그리기" % [lv, Pat.path_len(lv)])
			4, 5: ok(drew and q == [lv - 3] and t.paths.size() == lv - 2, "Lv%d: 갈래 %d개, 새 갈래 그리기" % [lv, t.paths.size()])
			6: ok(not drew and t.paths.size() == 3, "Lv6: 그리기 없음, 갈래 3개")
	ok(absf(Tower.poly_len(t.paths[1]) - 600.0) < 1.0, "새 갈래 기본 길 600")

	# 7. 유도는 못 넣음, 관통·튕김은 됨
	ok(not t.can_take({"type": "mod", "id": "homing"}), "유도 못 넣음: " + t.refuse_text({"type": "mod", "id": "homing"}))
	ok(t.can_take({"type": "mod", "id": "pierce"}) and t.can_take({"type": "mod", "id": "bounce"}) and t.can_take({"type": "mod", "id": "split"}), "관통·튕김·분열은 넣음")
	var h := _new_tower(tp + Vector2(0, 200), Vector2.RIGHT)
	h.add_mod("homing")
	ok(not h.can_pattern("path"), "유도가 든 직선탄은 궤적으로 못 바꿈")

	# 8. 저장·불러오기
	var d := t.to_save()
	var t2 := Tower.new()
	t2.load_save(str_to_var(var_to_str(d)))
	ok(t2.pattern == "path" and t2.paths.size() == 3 and absf(Tower.poly_len(t2.paths[0]) - Tower.poly_len(t.paths[0])) < 0.1, "저장·불러오기: 갈래 %d개" % t2.paths.size())
	t2.free()

	# 9. 4개 상한
	_clear()
	for i in 4:
		var ti := _new_tower(tp + Vector2(0, -200 + 100 * i), Vector2.RIGHT)
		_give_path(ti)
		main._cancel_step()
	var t5 := _new_tower(tp + Vector2(150, 0), Vector2.RIGHT)
	ok(not t5.can_pattern("path"), "5번째 직선탄엔 못 넣음: " + t5.refuse_text({"type": "pat", "id": "path"}))
	ok(main.towers.get_child(0).can_pattern("path"), "있는 궤적은 레벨업 가능")

	# 10. 대격변: 궤적이 다른 공격방식이 되면 길은 지움, 다른 오브젝트가 궤적이 되지는 않음
	var tc: Tower = main.towers.get_child(0)
	tc.cataclysm_pattern()
	ok(tc.pattern != "path" and tc.paths.is_empty(), "대격변: 궤적 → %s, 길 지움" % tc.pattern)
	var bad := false
	for i in 300:
		t5.pattern = "shot"
		t5.cataclysm_pattern()
		bad = bad or t5.pattern == "path"
	ok(not bad, "대격변은 궤적을 만들지 않음")

	# 11. 등장 비율: 궤적 없으면 0.7%, 있으면 1.2%
	_clear()
	_new_tower(tp, Vector2.RIGHT)
	var n := 200000
	var c := 0
	for i in n:
		if main._roll_card().get("id", "") == "path":
			c += 1
	ok(absf(float(c) / n - 0.007) < 0.001, "궤적 없을 때 %.3f%%" % (100.0 * c / n))
	_give_path(main.towers.get_child(0))
	main._cancel_step()
	c = 0
	for i in n:
		if main._roll_card().get("id", "") == "path":
			c += 1
	ok(absf(float(c) / n - 0.012) < 0.0012, "궤적 있을 때 %.3f%%" % (100.0 * c / n))
	ok(main._valid_card({"type": "pat", "id": "path"}), "이어하기 선택지에 궤적 카드 허용")

	print("PATHTEST fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _btn(pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e
