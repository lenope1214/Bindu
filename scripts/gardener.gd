class_name Gardener
## 자동 정원사: 정원 쉬는 시간에 이슬로 알아서 하나씩 산다 (Garden.auto_buy, 정원 봇도 같은 판단을 쓴다).
## 판단: 길목보다 오브젝트가 적거나 새로 놓기가 레벨업보다 싸면 새 오브젝트, 아니면 지금 살 수 있는 것 중 가장 싼 것
## (새 반응이 생기는 속성은 반값, 영웅 속성은 0.7배로 쳐서 먼저). 살 게 없고 이슬이 넉넉하면 새로고침.


## 하나를 사서 놓는다. 산 게 없으면 false.
static func buy(main) -> bool:
	var ts: Array = main.towers.get_children()
	var n := ts.size()
	var want: int = main.lanes.size() + 1 + main.wave / 8
	var elems: Array = main.offer.filter(func(o): return o["type"] == "elem")
	elems.sort_custom(func(a, b): return a["e"] == Garden.hero_e and b["e"] != Garden.hero_e)
	for o in elems:
		# 새 오브젝트: 길목보다 적으면, 또는 레벨업보다 싸면
		var newc := Garden.cost_new(n)
		if n < Garden.MAX_TOWERS and Garden.dew >= newc and (n < want or newc < _cheapest_level(o, ts)):
			main.picked = o
			main._garden_pay(newc)
			_place_new(main, o)
			main._after_place()
			return true
	var best = null
	var best_t = null
	var best_c := 1e18
	for o in main.offer:
		for t in ts:
			if not t.can_take(o):
				continue
			var c := 0.0
			match o["type"]:
				"elem":
					c = Garden.cost_elem_on(t, o["e"], n) * (0.5 if not Elem.new_reactions(t.eff_now(), o["e"]).is_empty() else 1.0)
					if o["e"] == Garden.hero_e:
						c *= 0.7
				"pat":
					if not t.can_pattern(o["id"]):
						continue
					c = Garden.cost_pat(t, o["id"])
				"mod": c = Garden.cost_mod(t, o["id"]) * 0.8
				"trig": c = Garden.cost_trig(t, o["id"]) * 0.9
				"link": c = Garden.cost_link(main._garden_links()) * 1.2
			if c < best_c and Garden.dew >= real_cost(main, o, t, n):
				best_c = c
				best = o
				best_t = t
	if best == null:
		if Garden.dew > Garden.REROLL_COST * 8 and main.offer.size() > 0:
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


static func real_cost(main, o: Dictionary, t, n: int) -> int:
	match o["type"]:
		"elem": return Garden.cost_elem_on(t, o["e"], n)
		"pat": return Garden.cost_pat(t, o["id"])
		"mod": return Garden.cost_mod(t, o["id"])
		"trig": return Garden.cost_trig(t, o["id"])
		"link": return Garden.cost_link(main._garden_links())
	return 0


static func _cheapest_level(o: Dictionary, ts: Array) -> float:
	var low := 1e18
	for t in ts:
		if t.can_take(o):
			low = minf(low, Garden.cost_elem_on(t, o["e"], ts.size()))
	return low


## 새 오브젝트는 오브젝트가 가장 적은 길목 쪽, 중앙에서 90~240 사이 빈자리에.
static func _place_new(main, o: Dictionary) -> void:
	var c: Vector2 = main.core()
	var ts: Array = main.towers.get_children()
	var la: float = main.lanes[0] if not main.lanes.is_empty() else 0.0
	var fewest := 999
	for a in main.lanes:
		var cnt := 0
		for t in ts:
			if absf(angle_difference((t.position - c).angle(), a)) < 0.4:
				cnt += 1
		if cnt < fewest:
			fewest = cnt
			la = a
	var ld := Vector2(cos(la), sin(la))
	var i := ts.size()
	for k in 8:
		var p: Vector2 = c + ld * (90 + 30 * (k % 4) + 25 * (i % 3)) + ld.orthogonal() * 30 * (1 if (i + k) % 2 == 0 else -1) * (1 + k / 4)
		p = p.clamp(main.field_rect().position, main.field_rect().end)
		if main._tower_at(p) == null and p.distance_to(c) > 60:
			main._place_tower(p, ld)
			return
	main._place_tower(c + ld * 200, ld)
