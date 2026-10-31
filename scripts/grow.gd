class_name Grow
## 정원 키우기형(2026-10-31 B안): 중앙 둘레 8칸에 속성을 심고 이슬로 레벨만 올린다.
## 칸 = {"e": 속성, "lv": 레벨, "seed": 보상 순서용 난수} (비면 {}). 오브젝트는 칸에서 늘 같은 모양으로 다시 만든다:
## 레벨 구간마다 공격방식·강화·두 번째 속성·발동이 저절로 붙고(칸의 seed로 정해져 다시 만들어도 같음),
## 방향은 가까운 구체를 저절로 겨눈다. 카드·상점·놓기·옮기기는 없다.

const SLOTS := 8
const SLOT_R := 150.0  # 중앙에서 칸까지
const OPEN_AT := [0, 0, 0, 4, 8, 13, 19, 26]  # 칸 i가 열리는 최고 단계 (처음 3칸)
## 레벨 보상: [레벨, 종류]. 종류: pat(공격방식), plv(공격방식 단계), mod(강화), elem(속성 하나 더), trig(발동)
const REWARDS := [[5, "pat"], [12, "mod"], [20, "elem"], [30, "mod"], [40, "plv"], [50, "trig"], [60, "mod"], [75, "elem"], [90, "plv"], [100, "mod"], [120, "mod"], [140, "trig"], [160, "mod"]]
const PAT_POOL := ["spray", "thorn", "stream", "chain", "gust", "shard", "vortex", "laser", "lob", "iron", "sonic", "clock", "wisp"]  # 그린 궤적·벽(방향 고정)은 빼고
const PLANT_ELEMS := [Elem.FIRE, Elem.WOOD, Elem.WATER, Elem.ELECTRIC, Elem.WIND, Elem.ICE, Elem.EARTH, Elem.DARK, Elem.LIGHT, Elem.POISON, Elem.METAL, Elem.SOUND, Elem.TIME, Elem.SOUL]  # 별은 둘레를 모으는 속성이라 칸에는 안 심음
const REWARD_NAMES := {"pat": "공격방식", "plv": "공격방식 단계", "mod": "강화", "elem": "속성 하나 더", "trig": "발동"}


static func is_open(i: int) -> bool:
	return Garden.best >= OPEN_AT[i]


static func open_count() -> int:
	var n := 0
	for i in SLOTS:
		if is_open(i):
			n += 1
	return n


static func planted() -> int:
	var n := 0
	for s in Garden.slots:
		if not (s as Dictionary).is_empty():
			n += 1
	return n


static func slot_pos(center: Vector2, i: int) -> Vector2:
	return center + Vector2.from_angle(-PI / 2.0 + TAU * i / SLOTS) * SLOT_R


## 심는 값: 이미 심은 칸 수에 따라.
static func plant_cost() -> int:
	return roundi(Garden.k("plant", 20.0) * pow(Garden.k("plant_mul", 2.2), planted()))


## 레벨 lv → lv+1 값. 영웅 속성 칸은 할인.
static func grow_cost(lv: int, e: int) -> int:
	var c := Garden.k("grow_base", 8.0) * pow(Garden.k("grow_mul", 1.12), lv - 1)
	if e == Garden.hero_e:
		c *= Garden.k("hero_disc", 0.8)
	return maxi(1, roundi(c))


## 레벨 lv에서 n번 키우는 값 (n<0이면 지금 이슬로 가능한 만큼) → [번수, 값].
static func grow_many(lv: int, e: int, n: int, dew: float) -> Array:
	var k := 0
	var sum := 0
	while (n < 0 or k < n) and k < 1000:
		var c := grow_cost(lv + k, e)
		if n < 0 and sum + c > dew:
			break
		sum += c
		k += 1
	return [k, sum]


## 다음 레벨 보상 [레벨, 이름] (없으면 [0, ""]).
static func next_reward(lv: int) -> Array:
	for r in REWARDS:
		if r[0] > lv:
			return [r[0], REWARD_NAMES[r[1]]]
	return [0, ""]


## 칸 정보로 오브젝트 모양을 다시 만든다 (같은 칸이면 늘 같은 결과).
static func apply(t: Tower, s: Dictionary) -> void:
	var e: int = s["e"]
	var lv: int = maxi(1, int(s["lv"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.get("seed", 1))
	t.elements = {}
	t.order.clear()
	t.pattern = Pat.DEFAULT
	t.plv = 1
	t.mods = {}
	t.trigs = {}
	t.paths = []
	t.elements[e] = 1
	t.order.append(e)
	var extra := 0
	for r in REWARDS:
		if r[0] > lv:
			break
		match r[1]:
			"pat":
				t.pattern = PAT_POOL[rng.randi() % PAT_POOL.size()]
			"plv":
				t.plv += 1
			"mod":
				var ids: Array = Pat.MOD_IDS.filter(func(id): return t.can_take({"type": "mod", "id": id}))
				if not ids.is_empty():
					var id: String = ids[rng.randi() % ids.size()]
					t.mods[id] = t.m(id) + 1
			"elem":
				var es: Array = PLANT_ELEMS.filter(func(x): return not t.elements.has(x) and t.can_take({"type": "elem", "e": x}))
				if not es.is_empty():
					var x: int = es[rng.randi() % es.size()]
					t.elements[x] = 1
					t.order.append(x)
					extra += 1
			"trig":
				var tid: String = Pat.TRIG_IDS[rng.randi() % Pat.TRIG_IDS.size()]
				t.trigs[tid] = t.tg(tid) + 1
	# 레벨은 심은 속성에 (더 붙은 속성은 1씩, 합이 칸 레벨)
	t.elements[e] = maxi(1, lv - extra)
	t.cd.clear()
	t.fx.clear()
	t.eff = t.eff_now()
	t.queue_redraw()


## 칸 이름: "불 Lv12" (+ 붙은 속성)
static func slot_title(s: Dictionary) -> String:
	return "%s Lv%d" % [Elem.NAMES[s["e"]], int(s["lv"])]
