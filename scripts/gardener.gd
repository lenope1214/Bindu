class_name Gardener
## 자동 정원사(키우기형): 0.35초마다 하나씩. 빈 칸이 있고 심는 값이 가장 싼 키우기의 3배보다 싸면 심고
## (영웅 속성 → 이미 심은 속성과 다른 것), 아니면 가장 싼 키우기(영웅 속성 칸은 값이 할인돼 저절로 먼저).


## 하나를 사면 true.
static func buy(main) -> bool:
	var low := -1
	var low_c := 1 << 60
	var empty := -1
	for i in Grow.SLOTS:
		if not Grow.is_open(i):
			continue
		var sl: Dictionary = Garden.slots[i]
		if sl.is_empty():
			if empty < 0:
				empty = i
			continue
		var c := Grow.grow_cost(int(sl["lv"]), int(sl["e"]))
		if c < low_c:
			low_c = c
			low = i
	var pc := Grow.plant_cost()
	if empty >= 0 and (low < 0 or pc <= low_c * 3):
		if Garden.dew >= pc:
			return main.grow_plant(empty, pick_elem())
		return false  # 빈 칸을 심을 만큼 모은다 (키우기에 다 쓰면 심을 이슬이 안 모임)
	if low >= 0 and Garden.dew >= low_c:
		return main.grow_up(low, 1) > 0
	return false


## 심을 속성: 영웅 속성이 아직 없으면 그것, 아니면 아직 안 심은 속성 중 하나.
static func pick_elem() -> int:
	var used: Array = []
	for sl in Garden.slots:
		if not (sl as Dictionary).is_empty():
			used.append(int(sl["e"]))
	if Garden.hero_e in Grow.PLANT_ELEMS and not Garden.hero_e in used:
		return Garden.hero_e
	var free: Array = Grow.PLANT_ELEMS.filter(func(e): return not e in used)
	return (free if not free.is_empty() else Grow.PLANT_ELEMS).pick_random()
