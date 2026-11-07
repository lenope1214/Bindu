class_name Side
## 속성 보조 공격 (2026-11-05, 초반 난이도). 오브젝트는 정해 둔 방향으로만 쏴서 조준선 밖으로 지나가는 구체가 샌다.
## 보조 공격: 몇 초마다 조준과 상관없이 둘레(side_r)에서 가장 가까운 구체를 한 번 친다. Tower.hit 그대로라 효과·특징·상성이 모두 실린다.
## 간격 = side_iv / 속성 종류 수 (섞을수록 자주). 속성 하나짜리도 가진다 (분산 플레이).
## 큰 보조 공격: 보조 공격 side_big_n번마다 한 번은 크게. 모양은 대표 나르는 특징(레벨이 가장 높은 것)이 정하고,
## 맞은 구체마다 Share.carry로 그 오브젝트 효과 + 바꾸는 특징(바람 실림·얼음 얼림·땅 다짐·금속 날 세움·나무 자람·시간 되풀이)이 붙는다.
## 화면에는 큰 보조 공격이 하나씩만 (main.side_big_t 동안 다음 것은 기다림).
## 섞인 보조 공격 (2026-11-06 사용자 승인): 속성이 2종 이상이면 보통 보조 공격 모양이 섞은 조합으로 바뀐다.
## 모양 = 대표 나르는 특징(shape_e). 여러 대상(전기·소리·영혼·피·환영) · 장판 던지기(물·독·불: 맞은 구체가 지나간 길에만 장판, ELEM-10)
## · 맵 전체(어둠·별·빛) · 나르는 특징 없음은 휩쓸기. 큰 보조 공격은 같은 모양의 큰 판. 어울리는 짝 6개는 SPECIAL이 덮어쓴다.
## 오브젝트와 고정된 거리에 생기는 장판은 없다 (사용자 결정 2026-10-30).
## 온라인 패치: rules.side_iv · side_dmg · side_r · side_big_n · side_big_k · side_mix_k(섞인 보조 공격 피해 배율)
const BIG_R := 200.0  # 큰 보조 공격 둥근 터짐 반지름 (바람 넓힘 곱)
const BIG_CHAIN := 10  # 전기: 이어지는 구체 수
const BIG_JUMP := 160.0  # 전기: 다음 구체까지 거리 (바람 넓힘 곱)
const BIG_LINE_W := 26.0  # 빛: 빛줄기 반폭 (바람 넓힘 곱)
const BIG_CAP := 60  # 큰 보조 공격 하나가 맞히는 구체 최대 수
const BIG_F := 0.6  # 큰 보조 공격이 싣는 효과 비율
const BIG_LOCK := 1.2  # 큰 보조 공격 하나가 화면을 차지하는 시간(초)

## 섞인 보조 공격 수치 (피해는 보조 공격 피해 x 이 값 x rules.side_mix_k)
static var MULTI_N := 3  # 여러 대상: 맞히는 구체 수 (바람이 있으면 +1)
static var MULTI_K := 0.7  # 여러 대상: 한 마리 피해
static var MULTI_JUMP := 160.0  # 전기: 다음 구체까지 거리 (바람 넓힘 곱)
static var LINK_T := 3.0  # 피 핏줄 엮기: 묶이는 시간 (얼음 오래감 곱)
static var LINK_K := 0.3  # 피 핏줄 엮기: 한 구체가 받은 피해를 나머지가 이만큼 받음
static var ECHO_R := 220.0  # 환영 분신: 함께 치는 다른 오브젝트 거리 (바람 넓힘 곱)
static var THROW_K := 1.0  # 장판 던지기: 맞은 구체 피해
static var SMEAR_T := {Elem.WATER: 2.0, Elem.POISON: 3.0, Elem.FIRE: 3.0}  # 묻은 구체가 장판을 남기는 시간 (얼음 오래감 곱)
static var SMEAR_F := 0.3  # 장판을 밟은 구체에 오브젝트 효과 비율
static var SMEAR_DMG := 0.3  # 장판을 밟을 때 피해 (같은 점은 0.5초에 한 번)
static var SMEAR_LIFE := 1.5  # 장판 점이 남는 시간 (얼음 오래감 곱)
static var SMEAR_STEP := 30.0  # 장판 점 간격(px)
static var POISON_BURST_R := 80.0  # 독병: 묻은 구체가 죽으면 이 둘레 중독
static var MAP_K := 1.2  # 맵 전체: 한 마리 피해
static var DARK_PULL_R := 90.0  # 그림자 낙하: 끌어당기는 둘레
static var DARK_PULL := 30.0  # 그림자 낙하: 끌어당기는 거리(px)
static var STAR_R := 70.0  # 유성 둘레 (바람 넓힘 곱)
static var STAR_K := 0.8  # 유성 피해
static var LINE_W := 14.0  # 빛줄기 반폭 (바람 넓힘 곱)
static var LINE_K := 0.7  # 빛줄기 위 구체마다 피해
static var LINE_CAP := 8  # 빛줄기가 맞히는 구체 최대 수
static var SWEEP_R := 80.0  # 휩쓸기 둘레 (바람 넓힘 곱)
static var SWEEP_K := 0.5  # 휩쓸기 둘레 피해
static var TIME_AGAIN := 0.8  # 시간: 이만큼 뒤 같은 모양을 한 번 더
static var TIME_K := 0.5  # 시간: 한 번 더의 피해 비율
static var BIG_MULTI := {Elem.SOUND: 20, Elem.SOUL: 8, Elem.BLOOD: 6, Elem.ILLUSION: 4}  # 큰 판 대상 수
static var BIG_THROW_N := 3  # 큰 판 장판 던지기: 구체 수
static var BIG_STARS := 5  # 큰 판 유성 수
static var MINI_ECLIPSE_N := 4  # 일식(빛+어둠): 보통 보조 공격 이 수마다 작은 일식
static var MINI_ECLIPSE_K := 0.2  # 작은 일식 피해 (보조 공격 피해 x, 화면 전체)
static var DOOM_N := 3  # 저승길(영혼+어둠): 혼불이 쫓는 체력 높은 구체 수
static var WHEEL_N := 3  # 불바퀴(불+바람): 굴러다니며 맞히는 구체 수

## 특별 칸: [속성, 속성, id, 이름, 이 모양일 때만]
const SPECIAL := [
	[Elem.LIGHT, Elem.DARK, "eclipse", "일식", -1],
	[Elem.WATER, Elem.ELECTRIC, "shock", "감전 물폭탄", Elem.WATER],
	[Elem.FIRE, Elem.WIND, "wheel", "불바퀴", Elem.FIRE],
	[Elem.POISON, Elem.DARK, "curse", "저주병", Elem.POISON],
	[Elem.SOUL, Elem.DARK, "doom", "저승길", Elem.SOUL],
	[Elem.STAR, Elem.LIGHT, "shower", "유성우", Elem.STAR],
]
const MIX_NAMES := {
	Elem.ELECTRIC: "이어지는 번개", Elem.SOUND: "메아리", Elem.SOUL: "혼불 떼", Elem.BLOOD: "핏줄 엮기", Elem.ILLUSION: "분신",
	Elem.WATER: "물폭탄", Elem.POISON: "독병", Elem.FIRE: "불덩이",
	Elem.DARK: "그림자 낙하", Elem.STAR: "유성", Elem.LIGHT: "빛줄기",
}
const MIX_DESC := {
	Elem.ELECTRIC: "가까운 구체부터 3마리를 번개로 이어 쳐요",
	Elem.SOUND: "둘레 구체 3마리를 한꺼번에 쳐요",
	Elem.SOUL: "혼불 3개가 서로 다른 구체를 쫓아가 맞혀요",
	Elem.BLOOD: "3마리를 핏줄로 묶어, 3초 동안 한 구체가 받은 피해 30%를 나머지도 받아요",
	Elem.ILLUSION: "둘레 다른 오브젝트 2개 자리에서도 한 번씩 쳐요",
	Elem.WATER: "구체에 던져 묻혀요. 그 구체가 2초 동안 지나간 길에 물이 남아 밟은 구체가 느려지고 효과 30%를 받아요",
	Elem.POISON: "구체에 던져 묻혀요. 그 구체가 3초 동안 지나간 길에 독이 남고, 죽으면 둘레 80을 중독시켜요",
	Elem.FIRE: "구체에 던져 묻혀요. 그 구체가 3초 동안 지나간 길에 불이 남아 밟은 구체가 타요",
	Elem.DARK: "화면 어디든 체력이 가장 많은 구체 위로 떨어져 치고 둘레를 끌어당겨요",
	Elem.STAR: "화면에서 구체가 가장 몰린 곳에 별똥별이 떨어져요",
	Elem.LIGHT: "가장 가까운 구체 쪽으로 화면 끝까지 빛줄기를 쏴요",
	-1: "가장 가까운 구체를 치고 그 둘레 80도 함께 쳐요",
}
const SPECIAL_DESC := {
	"eclipse": "보조 공격 4번에 한 번 화면 전체에 작은 일식",
	"shock": "물을 밟은 구체에서 번개가 옆 구체로 튀어요",
	"wheel": "불덩이가 구체 3마리를 차례로 굴러다니며 묻어요",
	"curse": "독 묻은 구체가 죽으면 둘레 구체를 그 자리로 끌어모아요",
	"doom": "혼불이 화면 어디든 체력이 높은 구체를 쫓아가요",
	"shower": "유성이 2개 떨어져요",
}


static func kinds(tw: Object) -> int:
	return maxi(1, (tw.eff if not tw.eff.is_empty() else tw.elements).size())


## 보조 공격 간격(초)
static func iv(tw: Object) -> float:
	return Rules.t("side_iv") / kinds(tw)


## 큰 보조 공격·섞인 보조 공격 모양을 정하는 속성 (나르는 특징 중 레벨이 가장 높은 것, 같으면 먼저 넣은 것, 없으면 -1)
static func shape_e(tw: Object) -> int:
	var els: Dictionary = tw.eff if not tw.eff.is_empty() else tw.elements
	var keys: Array = []
	for e in tw.order:
		if els.has(e) and not keys.has(e):
			keys.append(e)
	for e in els:
		if not keys.has(e):
			keys.append(e)
	var best := -1
	var bl := 0
	for e in keys:
		if e in Share.SITE_E and int(els[e]) > bl:
			best = e
			bl = int(els[e])
	return best


## 섞인 보조 공격인지 (속성 2종 이상)
static func mixed(tw: Object) -> bool:
	return kinds(tw) >= 2


static func _els(tw: Object) -> Dictionary:
	return tw.eff if not tw.eff.is_empty() else tw.elements


## 이 오브젝트에 켜진 특별 칸 id들 (모양 조건까지 맞는 것)
static func specials(tw: Object) -> Array:
	var out: Array = []
	if not mixed(tw):
		return out
	var els := _els(tw)
	var e := shape_e(tw)
	for sp in SPECIAL:
		if els.has(sp[0]) and els.has(sp[1]) and (sp[4] == -1 or sp[4] == e):
			out.append(sp[2])
	return out


static func has_sp(tw: Object, id: String) -> bool:
	return specials(tw).has(id)


## 섞인 보조 공격 이름 (정보창). 섞지 않았으면 ""
static func mix_name(tw: Object) -> String:
	if not mixed(tw):
		return ""
	var n: String = MIX_NAMES.get(shape_e(tw), "휩쓸기")
	for sp in SPECIAL:
		if has_sp(tw, sp[2]):
			n += " · " + sp[3]
	return n


static func mix_desc(tw: Object) -> String:
	if not mixed(tw):
		return ""
	var d: String = MIX_DESC.get(shape_e(tw), MIX_DESC[-1])
	for id in specials(tw):
		d += ". " + SPECIAL_DESC[id]
	return d + "."


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
	if not tw.main.combat_system.side_attacks_enabled:
		return
	tw.side_cd -= delta
	if tw.side_cd > 0.0:
		return
	var main: Node = tw.main
	var big: bool = tw.side_n + 1 >= int(Rules.t("side_big_n")) and Rules.t("side_big_n") > 0.0
	if big and main.side_big_t > 0.0:
		big = false  # 화면에 큰 보조 공격이 이미 있으면 이번엔 보통 보조 공격 (차례는 남겨 둠)
		tw.side_n = int(Rules.t("side_big_n")) - 2
	var o: Orb = nearest(tw, Rules.t("side_r"))
	if o == null:
		tw.side_cd = 0.2  # 둘레에 구체가 없으면 잠깐 뒤 다시 본다
		return
	tw.side_cd = iv(tw)
	tw.side_n += 1
	if big:
		tw.side_n = 0
		if mixed(tw) and not shape_e(tw) in [Elem.ELECTRIC, Elem.LIGHT, Elem.DARK, -1]:
			main.side_big_t = BIG_LOCK
			mix_hit(tw, o, true)
			tw.side_big_fx = 0.5
		else:
			big_hit(tw, o)
	elif mixed(tw):
		mix_hit(tw, o, false)
	else:
		hit_one(tw, o)


static func nearest(tw: Object, r: float) -> Orb:
	var best: Orb = null
	var bd := r * r
	for o in tw._combat_port.near(tw.position, r):
		if is_instance_valid(o) and o.hp > 0.0:
			var d: float = tw.position.distance_squared_to(o.position)
			if d < bd:
				bd = d
				best = o
	return best


## 보통 보조 공격: 구체 하나를 오브젝트 공격처럼 친다
static func hit_one(tw: Object, o: Orb) -> void:
	var col: Color = tw.color()
	col.a = 0.7
	tw._spawning_port.beam(tw.position, o.position, col)
	var old: String = tw.tag
	tw.tag = "share:side"
	tw.no_size = true
	tw.hit(o, Tower.pw(tw.plv) * Rules.t("side_dmg"))
	tw.no_size = false
	tw.tag = old


## 큰 보조 공격
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
				for c in main.combat_system.near(cur.position, BIG_JUMP * w):
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
			main.spawning_system.bolt(pts)
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
			main.spawning_system.beam(tw.position, tw.position + dir * 1600.0, Elem.COLORS[Elem.LIGHT])
		Elem.DARK:
			for c in main.live_orbs:
				if is_instance_valid(c) and c.hp > 0.0:
					got.append(c)
			main.field_view_system.eclipse_screen()
		_:
			var r := BIG_R * w
			for c in main.combat_system.near(at, r):
				if is_instance_valid(c) and c.hp > 0.0 and c.position.distance_to(at) < r + c.radius():
					got.append(c)
			if main.pulses.size() < 40:
				main.pulses.append([at, r, 0.45])
	if got.size() > BIG_CAP:
		got.sort_custom(func(a, b): return a.position.distance_squared_to(at) < b.position.distance_squared_to(at))
		got = got.slice(0, BIG_CAP)
	var d0: float = Tower.pw(tw.plv) * Rules.t("side_dmg") * Rules.t("side_big_k") * tw.dmg_k_bare()
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
	main.spawning_system.burst(at, tw.color(), 10, 160.0)
	tw.side_big_fx = 0.5


# ---------- 섞인 보조 공격 ----------

## 섞인 보조 공격 한 마리 피해 (배율 k)
static func mdmg(tw: Object, k: float) -> float:
	return Tower.pw(tw.plv) * Rules.t("side_dmg") * Rules.t("side_mix_k") * k


## 오브젝트 공격처럼 친다 (효과·특징·상성 실림, 크기 피해 뺌)
static func strike(tw: Object, o: Orb, d: float, from: Vector2, col: Color, key := "share:side") -> void:
	if not is_instance_valid(o) or o.hp <= 0.0:
		return
	tw._spawning_port.beam(from, o.position, col)
	var old: String = tw.tag
	tw.tag = key
	tw.no_size = true
	tw.hit(o, d)
	tw.no_size = false
	tw.tag = old


## 맞은 구체에 바로 피해 + 효과 (여러 마리를 한꺼번에 칠 때, 특징을 다시 타지 않음)
static func splash(tw: Object, o: Orb, d: float, at: Vector2, key: String) -> void:
	if not is_instance_valid(o) or o.hp <= 0.0:
		return
	var got: float = o.hurt(d * tw.dmg_k_bare() * o.resist_mul(_els(tw)), false, tw)
	tw.credit(got, key)
	if o.hp > 0.0:
		Share.carry(tw, o, BIG_F, key, at, 0.0)


static func _all(main: Node) -> Array:
	var src: Array = main.live_orbs if not main.live_orbs.is_empty() else main.combat_system.targets
	var out: Array = []
	for c in src:
		if is_instance_valid(c) and c.hp > 0.0:
			out.append(c)
	return out


## 둘레 r 안 가까운 순 구체 n개
static func nearest_n(tw: Object, at: Vector2, r: float, n: int, skip: Array = []) -> Array:
	var got: Array = []
	for c in tw._combat_port.near(at, r):
		if is_instance_valid(c) and c.hp > 0.0 and not skip.has(c) and c.position.distance_to(at) < r + c.radius():
			got.append(c)
	got.sort_custom(func(a, b): return a.position.distance_squared_to(at) < b.position.distance_squared_to(at))
	return got.slice(0, n)


static func _wind_n(tw: Object) -> int:
	return 1 if Share.k(tw, Elem.WIND) > 0.0 else 0


## 섞인 보조 공격. big: 같은 모양의 큰 판. rep: 시간 '한 번 더'로 다시 부른 것
static func mix_hit(tw: Object, o: Orb, big: bool, rep := false) -> void:
	var main: Node = tw.main
	var e := shape_e(tw)
	var w: float = Share.wide(tw)
	var col: Color = Elem.COLORS[e] if e >= 0 else tw.color()
	col.a = 0.8
	var rk := TIME_K if rep else 1.0
	var bk: float = Rules.t("side_big_k") if big else 1.0
	var r: float = Rules.t("side_r")
	match e:
		Elem.ELECTRIC:
			var n := MULTI_N + _wind_n(tw)
			var got: Array = [o]
			var pts := PackedVector2Array([tw.position, o.position])
			while got.size() < n:
				var nx: Array = nearest_n(tw, got[got.size() - 1].position, MULTI_JUMP * w, 1, got)
				if nx.is_empty():
					break
				got.append(nx[0])
				pts.append(nx[0].position)
			main.spawning_system.bolt(pts)
			for c in got:
				strike(tw, c, mdmg(tw, MULTI_K) * rk * bk, tw.position, Color(col, 0.0))
		Elem.SOUND:
			var n: int = (BIG_MULTI[Elem.SOUND] if big else MULTI_N) + _wind_n(tw)
			for c in nearest_n(tw, tw.position, r * (w if big else 1.0), n):
				strike(tw, c, mdmg(tw, MULTI_K) * rk * bk, tw.position, col)
			if main.pulses.size() < 40:
				main.pulses.append([tw.position, r * 0.3, 0.35])
		Elem.SOUL:
			var n: int = (BIG_MULTI[Elem.SOUL] if big else MULTI_N) + _wind_n(tw)
			var goals: Array = []
			if has_sp(tw, "doom"):
				goals = _all(main)
				goals.sort_custom(func(a, b): return a.hp > b.hp)
				goals = goals.slice(0, maxi(DOOM_N, n))
			else:
				goals = nearest_n(tw, tw.position, r, n)
			for i in mini(n, maxi(goals.size(), 1)):
				var tg: Orb = goals[i] if i < goals.size() else o
				var from: Vector2 = tw.position
				if has_sp(tw, "doom"):
					from = tg.position + Vector2.from_angle(randf() * TAU) * 70.0  # 그림자에서 나와 쫓아감
				_ghost(tw, from, tg, mdmg(tw, MULTI_K) * rk * bk)
		Elem.BLOOD:
			var n: int = (BIG_MULTI[Elem.BLOOD] if big else MULTI_N) + _wind_n(tw)
			var got: Array = [o] + nearest_n(tw, o.position, MULTI_JUMP * w, n - 1, [o])
			for c in got:
				strike(tw, c, mdmg(tw, MULTI_K) * rk * bk, tw.position, col)
			link(tw, got)
		Elem.ILLUSION:
			strike(tw, o, mdmg(tw, MULTI_K) * rk * bk, tw.position, col)
			var n: int = (BIG_MULTI[Elem.ILLUSION] if big else 2) + _wind_n(tw)
			var near: Array = []
			for t2 in main.towers.get_children():
				if t2 != tw and is_instance_valid(t2) and not t2.is_queued_for_deletion() and t2.position.distance_to(tw.position) < ECHO_R * w:
					near.append(t2)
			near.sort_custom(func(a, b): return a.position.distance_to(tw.position) < b.position.distance_to(tw.position))
			for t2 in near.slice(0, n):
				var tg: Array = nearest_n(tw, t2.position, r, 1)
				if not tg.is_empty():
					main.spawning_system.beam(tw.position, t2.position, Color(col, 0.35))
					strike(tw, tg[0], mdmg(tw, MULTI_K) * rk * bk, t2.position, col)
		Elem.WATER, Elem.POISON, Elem.FIRE:
			var n := BIG_THROW_N if big else 1
			var got: Array = [o]
			if has_sp(tw, "wheel"):
				n = WHEEL_N * (2 if big else 1)
			if n > 1:
				if has_sp(tw, "wheel"):
					while got.size() < n:  # 불바퀴: 맞은 구체에서 다음 구체로 굴러감
						var nx: Array = nearest_n(tw, got[got.size() - 1].position, MULTI_JUMP * w, 1, got)
						if nx.is_empty():
							break
						got.append(nx[0])
				else:
					got = [o] + nearest_n(tw, tw.position, r, n - 1, [o])
			var prev: Vector2 = tw.position
			for c in got:
				strike(tw, c, mdmg(tw, THROW_K) * rk * bk, prev, col)
				if has_sp(tw, "wheel"):
					prev = c.position
				smear(tw, c, e)
		Elem.DARK:
			var all := _all(main)
			var tg: Orb = o
			for c in all:
				if c.hp > tg.hp:
					tg = c
			main.spawning_system.beam(tg.position + Vector2(0, -260), tg.position, col)
			strike(tw, tg, mdmg(tw, MAP_K) * rk * bk, tg.position + Vector2(0, -60), Color(col, 0.0))
			for c in tw._combat_port.near(tg.position, DARK_PULL_R * w):
				if c != tg and is_instance_valid(c) and c.hp > 0.0 and c.position.distance_to(tg.position) < DARK_PULL_R * w:
					c.push((tg.position - c.position).limit_length(DARK_PULL))
			if main.pulses.size() < 40:
				main.pulses.append([tg.position, DARK_PULL_R * w, 0.3])
		Elem.STAR:
			var n := (BIG_STARS if big else 1) + (1 if has_sp(tw, "shower") else 0)
			var used: Array = []
			for i in n:
				var at := _densest(main, STAR_R * w, used)
				if at == Vector2.INF:
					break
				used.append(at)
				_meteor(tw, at, STAR_R * w, mdmg(tw, STAR_K) * rk * bk)
		Elem.LIGHT:
			var dir: Vector2 = (o.position - tw.position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var hw := LINE_W * w
			var got: Array = []
			for c in _all(main):
				var rel: Vector2 = c.position - tw.position
				if rel.dot(dir) > 0.0 and absf(rel.cross(dir)) < hw + c.radius():
					got.append(c)
			got.sort_custom(func(a, b): return a.position.distance_squared_to(tw.position) < b.position.distance_squared_to(tw.position))
			main.spawning_system.beam(tw.position, tw.position + dir * 1600.0, col)
			for c in got.slice(0, LINE_CAP):
				strike(tw, c, mdmg(tw, LINE_K) * rk * bk, tw.position, Color(col, 0.0))
		_:
			strike(tw, o, mdmg(tw, 1.0) * rk * bk, tw.position, col)
			var at: Vector2 = o.position
			for c in nearest_n(tw, at, SWEEP_R * w, 12, [o]):
				splash(tw, c, mdmg(tw, SWEEP_K) * rk * bk, at, "share:side")
			if main.pulses.size() < 40:
				main.pulses.append([at, SWEEP_R * w, 0.3])
	if rep:
		return
	# 일식(빛+어둠): 보통 보조 공격 MINI_ECLIPSE_N번마다 화면 전체에 작은 일식
	if has_sp(tw, "eclipse") and not big:
		tw.side_mix_n += 1
		if tw.side_mix_n >= MINI_ECLIPSE_N:
			tw.side_mix_n = 0
			for c in _all(main):
				splash(tw, c, mdmg(tw, MINI_ECLIPSE_K), c.position, "share:side")
			main.field_view_system.eclipse_screen()
	# 시간: 잠시 뒤 같은 모양 한 번 더 (절반)
	if Share.k(tw, Elem.TIME) > 0.0:
		var ref: WeakRef = weakref(o)
		tw.later.append([TIME_AGAIN, func():
			var oo: Orb = ref.get_ref() as Orb
			if is_instance_valid(tw) and tw.main and oo != null and is_instance_valid(oo) and oo.hp > 0.0:
				mix_hit(tw, oo, big, true)])


## 혼불: from에서 나와 tg를 쫓아간다 (영혼 넋불과 같은 탄)
static func _ghost(tw: Object, from: Vector2, tg: Orb, d: float) -> void:
	var main: Node = tw.main
	var n := 0
	for p in main.projectiles.get_children():
		if p.kind == "ghost":
			n += 1
	if n >= 40:
		strike(tw, tg, d, from, Elem.COLORS[Elem.SOUL])
		return
	var dir: Vector2 = (tg.position - from).normalized() if tg.position != from else Vector2.RIGHT
	var g: Projectile = main.spawning_system.spawn_proj(tw, "ghost", tw.plv, dir)
	g.position = from
	g.dmg = d
	g.src = "share:side"


## 장판 던지기: 맞은 구체 o에 속성 e를 묻힌다. 그 구체가 움직인 길에만 장판이 남는다 (Orb._blood_step → smear_pt)
static func smear(tw: Object, o: Orb, e: int) -> void:
	if not is_instance_valid(o) or o.hp <= 0.0:
		return
	o.smear_src = tw
	o.smear_e = e
	o.smear_t = maxf(o.smear_t, float(SMEAR_T.get(e, 2.0)) * Share.dur(tw))
	o.smear_acc = SMEAR_STEP  # 바로 첫 점


## 묻은 구체가 SMEAR_STEP 움직일 때마다 (Orb._blood_step)
static func smear_pt(o: Orb) -> void:
	var tw: Object = o.smear_src
	if not is_instance_valid(tw) or tw.main == null:
		return
	var z: Zone = o.smear_zone as Zone if is_instance_valid(o.smear_zone) else null
	if z == null or z.is_queued_for_deletion() or z.owner_tower != tw or z.elem != o.smear_e:
		if tw.main.zones.get_child_count() >= 160:
			return
		var old_tag: String = tw.tag
		tw.tag = "share:side"
		z = tw._spawning_port.spawn_zone("smear", tw.plv, o.position, tw)
		tw.tag = old_tag
		z.elem = o.smear_e
		z.radius *= Share.wide(tw)
		z.gore_path(o)
		o.smear_zone = z
	z.add_gore_pt(o.position, 1.0, SMEAR_LIFE * Share.dur(tw))


## 묻은 자리를 밟은 구체 (Zone smear, 같은 점은 0.5초에 한 번, 묻은 구체는 빼고)
static func smear_step(tw: Object, o: Orb, e: int, at: Vector2, stage: float) -> void:
	var got: float = o.hurt(mdmg(tw, SMEAR_DMG) * tw.dmg_k_bare() * o.resist_mul(_els(tw)), false, tw)
	tw.credit(got, "share:side")
	if o.hp <= 0.0:
		return
	if e == Elem.WATER:
		o.slow(Share.RILL_SLOW, Share.RILL_T)
	Share.carry(tw, o, SMEAR_F, "share:side", at, stage)
	if e == Elem.WATER and has_sp(tw, "shock") and o.hp > 0.0:
		var nx: Array = nearest_n(tw, o.position, 120.0 * Share.wide(tw), 1, [o])
		if not nx.is_empty():
			tw.main.spawning_system.bolt(PackedVector2Array([o.position, nx[0].position]))
			Share.carry(tw, nx[0], SMEAR_F, "share:side", o.position, stage)
			var d2: float = nx[0].hurt(mdmg(tw, SMEAR_DMG) * tw.dmg_k_bare(), false, tw)
			tw.credit(d2, "share:side")


## 묻은 구체가 죽을 때 (combat._death_effects): 독병은 둘레 중독, 저주병은 둘레를 끌어모음
static func on_death(o: Orb) -> void:
	if o.smear_t <= 0.0 or o.smear_e != Elem.POISON:
		return
	var tw: Object = o.smear_src
	if not is_instance_valid(tw) or tw.main == null:
		return
	var curse := has_sp(tw, "curse")
	var r := POISON_BURST_R * Share.wide(tw)
	for c in tw._combat_port.near(o.position, r):
		if c == o or not is_instance_valid(c) or c.hp <= 0.0 or c.position.distance_to(o.position) >= r + c.radius():
			continue
		c.poison(Rules.poison_dps * maxi(tw.lv(Elem.POISON), 1) * SMEAR_F * 2.0, Rules.poison_t, tw, true, "share:side")
		if curse:
			c.push((o.position - c.position).limit_length(DARK_PULL * 1.5))
	if tw.main.pulses.size() < 40:
		tw.main.pulses.append([o.position, r, 0.3])


## 피 핏줄 엮기: 묶인 구체끼리 받은 피해를 나눈다 (Orb.hurt)
static func link(tw: Object, got: Array) -> void:
	var grp: Array = []
	for c in got:
		if is_instance_valid(c) and c.hp > 0.0:
			grp.append(weakref(c))
	if grp.size() < 2:
		return
	var t := LINK_T * Share.dur(tw)
	for c in got:
		if is_instance_valid(c) and c.hp > 0.0:
			c.link_grp = grp
			c.link_t = t
			c.link_src = tw
	var pts := PackedVector2Array()
	for c in got:
		if is_instance_valid(c):
			pts.append(c.position)
	if pts.size() >= 2:
		tw._spawning_port.beam(pts[0], pts[pts.size() - 1], Color(Elem.COLORS[Elem.BLOOD], 0.6))


static var _linking := false


## Orb.hurt에서: 묶인 구체가 피해 d를 받으면 나머지도 LINK_K만큼
static func share_link(o: Orb, d: float) -> void:
	if _linking or d <= 0.0:
		return
	var tw: Object = o.link_src
	if not is_instance_valid(tw):
		return
	_linking = true
	for wr in o.link_grp:
		var c: Orb = wr.get_ref() as Orb
		if c == null or c == o or not is_instance_valid(c) or c.hp <= 0.0 or c.link_t <= 0.0:
			continue
		c.hp -= d * LINK_K
		c.flash = 0.08
		tw.credit(d * LINK_K, "share:side")
	_linking = false


## 구체가 가장 몰린 자리 (구체 위치 중 둘레 r 안 구체가 가장 많은 곳, used 둘레는 뺌). 없으면 INF
static func _densest(main: Node, r: float, used: Array) -> Vector2:
	var all := _all(main)
	if all.is_empty():
		return Vector2.INF
	var best := Vector2.INF
	var bn := -1
	var step := maxi(1, all.size() / 60)
	for i in range(0, all.size(), step):
		var p: Vector2 = all[i].position
		var skip := false
		for u in used:
			if p.distance_to(u) < r * 1.5:
				skip = true
		if skip:
			continue
		var n := 0
		for c in main.combat_system.near(p, r):
			if is_instance_valid(c) and c.hp > 0.0 and c.position.distance_to(p) < r:
				n += 1
		if n > bn:
			bn = n
			best = p
	return best


## 유성: at 둘레 r에 떨어진다
static func _meteor(tw: Object, at: Vector2, r: float, d: float) -> void:
	var main: Node = tw.main
	main.spawning_system.beam(at + Vector2(180, -300), at, Elem.COLORS[Elem.STAR])
	for c in main.combat_system.near(at, r):
		if is_instance_valid(c) and c.hp > 0.0 and c.position.distance_to(at) < r + c.radius():
			splash(tw, c, d, at, "share:side")
	if main.pulses.size() < 40:
		main.pulses.append([at, r, 0.4])
	main.spawning_system.burst(at, Elem.COLORS[Elem.STAR], 8, 140.0)
