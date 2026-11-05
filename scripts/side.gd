class_name Side
## 속성 곁공격 (2026-11-05, 초반 난이도). 오브젝트는 정해 둔 방향으로만 쏴서 조준선 밖으로 지나가는 구체가 샌다.
## 곁공격: 몇 초마다 조준과 상관없이 둘레(side_r)에서 가장 가까운 구체를 한 번 친다. Tower.hit 그대로라 효과·특징·상성이 모두 실린다.
## 간격 = side_iv / 속성 종류 수 (섞을수록 자주). 속성 하나짜리도 가진다 (분산 플레이).
## 큰 곁공격: 곁공격 side_big_n번마다 한 번은 크게. 모양은 대표 나르는 특징(레벨이 가장 높은 것)이 정하고,
## 맞은 구체마다 Share.carry로 그 오브젝트 효과 + 바꾸는 특징(바람 실림·얼음 얼림·땅 다짐·금속 날 세움·나무 자람·시간 되풀이)이 붙는다.
## 화면에는 큰 곁공격이 하나씩만 (main.side_big_t 동안 다음 것은 기다림).
## 온라인 패치: rules.side_iv · side_dmg · side_r · side_big_n · side_big_k
const BIG_R := 200.0  # 큰 곁공격 둥근 터짐 반지름 (바람 넓힘 곱)
const BIG_CHAIN := 10  # 전기: 이어지는 구체 수
const BIG_JUMP := 160.0  # 전기: 다음 구체까지 거리 (바람 넓힘 곱)
const BIG_LINE_W := 26.0  # 빛: 빛줄기 반폭 (바람 넓힘 곱)
const BIG_CAP := 60  # 큰 곁공격 하나가 맞히는 구체 최대 수
const BIG_F := 0.6  # 큰 곁공격이 싣는 효과 비율
const BIG_LOCK := 1.2  # 큰 곁공격 하나가 화면을 차지하는 시간(초)


static func kinds(tw: Object) -> int:
	return maxi(1, (tw.eff if not tw.eff.is_empty() else tw.elements).size())


## 곁공격 간격(초)
static func iv(tw: Object) -> float:
	return Rules.t("side_iv") / kinds(tw)


## 큰 곁공격 모양을 정하는 속성 (나르는 특징 중 레벨이 가장 높은 것, 없으면 -1 = 둥근 터짐)
static func shape_e(tw: Object) -> int:
	var els: Dictionary = tw.eff if not tw.eff.is_empty() else tw.elements
	var best := -1
	var bl := 0
	for e in els:
		if e in Share.SITE_E and int(els[e]) > bl:
			best = e
			bl = int(els[e])
	return best


## 이름 (정보창·카드)
static func big_name(e: int) -> String:
	match e:
		Elem.ELECTRIC: return "이어지는 번개"
		Elem.LIGHT: return "가로지르는 빛줄기"
		Elem.DARK: return "일식"
	return "크게 터짐"


## Tower._share_tick에서 매 프레임. 웨이브 중에만 불린다.
static func tick(tw: Object, delta: float) -> void:
	if Rules.t("side_iv") <= 0.0 or not tw.main:
		return
	tw.side_cd -= delta
	if tw.side_cd > 0.0:
		return
	var main: Node = tw.main
	var big: bool = tw.side_n + 1 >= int(Rules.t("side_big_n")) and Rules.t("side_big_n") > 0.0
	if big and main.side_big_t > 0.0:
		big = false  # 화면에 큰 곁공격이 이미 있으면 이번엔 보통 곁공격 (차례는 남겨 둠)
		tw.side_n = int(Rules.t("side_big_n")) - 2
	var o: Orb = nearest(tw, Rules.t("side_r"))
	if o == null:
		tw.side_cd = 0.2  # 둘레에 구체가 없으면 잠깐 뒤 다시 본다
		return
	tw.side_cd = iv(tw)
	tw.side_n += 1
	if big:
		tw.side_n = 0
		big_hit(tw, o)
	else:
		hit_one(tw, o)


static func nearest(tw: Object, r: float) -> Orb:
	var best: Orb = null
	var bd := r * r
	for o in tw.main.near(tw.position, r):
		if is_instance_valid(o) and o.hp > 0.0:
			var d: float = tw.position.distance_squared_to(o.position)
			if d < bd:
				bd = d
				best = o
	return best


## 보통 곁공격: 구체 하나를 오브젝트 공격처럼 친다
static func hit_one(tw: Object, o: Orb) -> void:
	var col: Color = tw.color()
	col.a = 0.7
	tw.main.beam(tw.position, o.position, col)
	var old: String = tw.tag
	tw.tag = "share:side"
	tw.hit(o, Tower.pw(tw.plv) * Rules.t("side_dmg"))
	tw.tag = old


## 큰 곁공격
static func big_hit(tw: Object, o: Orb) -> void:
	var main: Node = tw.main
	main.side_big_t = BIG_LOCK
	var w: float = Share.wide(tw)
	var at: Vector2 = o.position
	var got: Array = []
	var e := shape_e(tw)
	match e:
		Elem.ELECTRIC:
			var cur: Orb = o
			var pts := PackedVector2Array([tw.position, cur.position])
			got.append(cur)
			while got.size() < BIG_CHAIN:
				var nx: Orb = null
				var nd := BIG_JUMP * w * BIG_JUMP * w
				for c in main.near(cur.position, BIG_JUMP * w):
					if is_instance_valid(c) and c.hp > 0.0 and not got.has(c):
						var d: float = c.position.distance_squared_to(cur.position)
						if d < nd:
							nd = d
							nx = c
				if nx == null:
					break
				got.append(nx)
				pts.append(nx.position)
				cur = nx
			main.bolt(pts)
		Elem.LIGHT:
			var dir: Vector2 = (o.position - tw.position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var hw := BIG_LINE_W * w
			for c in main.live_orbs:
				if is_instance_valid(c) and c.hp > 0.0:
					var rel: Vector2 = c.position - tw.position
					var along := rel.dot(dir)
					if along > 0.0 and absf(rel.cross(dir)) < hw + c.radius():
						got.append(c)
			main.beam(tw.position, tw.position + dir * 1600.0, Elem.COLORS[Elem.LIGHT])
		Elem.DARK:
			for c in main.live_orbs:
				if is_instance_valid(c) and c.hp > 0.0:
					got.append(c)
			main.eclipse_screen()
		_:
			var r := BIG_R * w
			for c in main.near(at, r):
				if is_instance_valid(c) and c.hp > 0.0 and c.position.distance_to(at) < r + c.radius():
					got.append(c)
			if main.pulses.size() < 40:
				main.pulses.append([at, r, 0.45])
	if got.size() > BIG_CAP:
		got.sort_custom(func(a, b): return a.position.distance_squared_to(at) < b.position.distance_squared_to(at))
		got = got.slice(0, BIG_CAP)
	var d0: float = Tower.pw(tw.plv) * Rules.t("side_dmg") * Rules.t("side_big_k") * tw.dmg_k(false)
	if e == Elem.DARK:
		d0 *= 0.5  # 화면 전체는 피해를 반으로
	var r0 := maxf(BIG_R * w, 1.0)
	for c in got:
		if not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var dd: float = c.hurt(d0 * c.resist_mul(tw.eff if not tw.eff.is_empty() else tw.elements), false, tw)
		tw.credit(dd, "share:side_big")
		if c.hp > 0.0:
			Share.carry(tw, c, BIG_F, "share:side_big", at, minf(c.position.distance_to(at) / r0, 1.0))
	main.burst(at, tw.color(), 10, 160.0)
	tw.side_big_fx = 0.5
