class_name Share
## 특징 공유 (2026-11-03). 속성 = 효과(Elem.RIDER, 맞힌 구체에 거는 것) + 특징(Elem.TRAIT, 효과를 실어 나르는 방식).
## 한 오브젝트 안에서는 모든 특징이 모든 효과에 붙는다. 정해 둔 조합 공격은 없다.
## - apply(): 오브젝트의 실어 나를 수 있는 효과(Elem.CARRY)를 비율 f로 구체 하나에 건다. 피해는 주지 않는다(금속 응축·전기 감전 제외).
##   여기서 건 효과는 특징을 다시 타지 않는다 (한 번만 전달 → 끝없는 연쇄 없음).
## - 특징마다 실어 나르는 자리: 전기 튐(main.arc) · 소리 퍼짐(main.sound_pulse) · 독 전염·어둠 끌어당김·불 타오름(구체가 죽거나 화상이 끝날 때)
##   · 물 흐름(지나간 길 물길, Zone rill) · 땅 묻어둠·시간 되풀이·빛 꿰뚫음(Tower.hit) · 영혼 쫓아감(넋 혼불이 주인 오브젝트의 hit를 그대로 씀, 세기 배율 없음) · 별 모음(초신성)
## - 나무 자람·바람 넓힘·얼음 오래감·금속 응축은 실어 나르는 자리가 없고 세기·범위·시간을 바꾼다.
## 피해 출처 키는 "share:<특징 속성>" (Tower.src, 서버 통계).

## 특징 속성 레벨별 세기 (Lv3에서 멈춤). 온라인 패치 rules.share_mul(전체) · rules.share_<속성>(특징마다)
static var LV_K := [0.0, 0.6, 0.8, 1.0]  # 특징 속성 레벨 0~3 세기

## 특징마다 실어 나르는 비율 (Lv3 기준, 세기 Share.k를 곱한다)
static var FIRE_F := 0.4  # 불 타오름: 불꽃에 닿은 구체에 효과 비율
static var WATER_F := 0.3  # 물 흐름: 물길을 밟은 구체에 효과 비율
static var ELEC_F := 0.5  # 전기 튐: 튄 구체에 효과 비율
static var EARTH_F := 0.7  # 땅 묻어둠: 다시 맞을 때 효과 비율
static var DARK_F := 0.3  # 어둠 끌어당김: 끌려온 구체에 효과 비율
static var LIGHT_F := 0.4  # 빛 꿰뚫음: 빛줄기 구체에 효과 비율
static var POISON_F := 0.5  # 독 전염: 둘레 구체에 효과 비율
static var SOUND_F := 0.5  # 소리 퍼짐: 음파에 닿은 구체에 효과 비율
static var TIME_F := 0.5  # 시간 되풀이: 한 번 더 거는 효과 비율
static var STAR_F := 1.0  # 별 모음: 초신성이 맞힌 구체에 효과 비율

static var FIRE_R := 50.0  # 불꽃 반지름
static var DARK_R := 90.0  # 끌어당김 반지름
static var DARK_PULL := 30.0  # 끌어당기는 거리(px)
static var LIGHT_LEN := 200.0  # 꿰뚫는 빛줄기 길이
static var LIGHT_W := 14.0  # 빛줄기 반폭
static var LIGHT_CD := 0.3  # 오브젝트마다 빛줄기 간격
static var POISON_R := 80.0  # 중독 전염 반지름 (예전 독 전염과 같음)
static var EARTH_T := 2.0  # 묻어둠 기다리는 시간
static var TIME_T := 0.8  # 되풀이까지
static var WIND_R := 0.4  # 넓힘: 범위 +40%
static var ICE_T := 0.5  # 오래감: 지속 +50%
static var WOOD_K := 0.06  # 자람: 100마다 +6%
static var WOOD_MAX := 0.3  # 자람 최대
static var METAL_K := 0.12  # 응축: 효과 하나당 위력의 12%


static func key_of(e: int) -> String:
	return "share:" + Patch.ELEM_KEYS[Elem.ALL.find(e)]


## 특징 세기 (0이면 그 특징이 없음)
static func k(tw: Object, e: int) -> float:
	if not is_instance_valid(tw):
		return 0.0
	var l: int = _els(tw).get(e, 0)
	if l <= 0:
		return 0.0
	return LV_K[mini(l, 3)] * Rules.share_mul * Rules.share_k.get(e, 1.0)


static func _els(tw: Object) -> Dictionary:
	return tw.eff if not tw.eff.is_empty() else tw.elements


## 이 오브젝트가 실어 나를 효과가 있는지
static func has_carry(tw: Object) -> bool:
	for e in _els(tw):
		if e in Elem.CARRY:
			return true
	return false


## 바람 넓힘: 퍼지는 특징 범위 배율
static func wide(tw: Object) -> float:
	return 1.0 + WIND_R * k(tw, Elem.WIND)


## 얼음 오래감: 효과 지속 배율 (맞힌 효과·실어 나른 효과 모두)
static func dur(tw: Object) -> float:
	return 1.0 + ICE_T * k(tw, Elem.ICE)


## 나무 자람: 오브젝트에서 먼 구체일수록 효과 세기 배율
static func grow(tw: Object, o: Orb) -> float:
	var kw := k(tw, Elem.WOOD)
	if kw <= 0.0:
		return 1.0
	return 1.0 + minf(WOOD_K * tw.position.distance_to(o.position) / 100.0, WOOD_MAX) * kw


## 실어 나른 효과가 주는 순간 피해의 기준 (오브젝트 위력, 공격방식 배율 제외)
static func ref_dmg(tw: Object) -> float:
	return Tower.pw(tw.plv) * tw.dmg_k(false)


## 효과를 비율 f로 구체 o에 건다. key: 피해 출처 ("share:<특징>")
static func apply(tw: Object, o: Orb, f: float, key: String) -> void:
	if f <= 0.0 or not is_instance_valid(tw) or not is_instance_valid(o) or o.hp <= 0.0:
		return
	var els := _els(tw)
	var dm := dur(tw)
	f *= grow(tw, o)
	var rm := o.resist_mul(els)
	var n := 0
	for e in els:
		var l: int = els[e]
		match e:
			Elem.FIRE:
				o.burn(Rules.fire_dps * l * rm * f, Rules.fire_t * dm, tw, true, key)
			Elem.POISON:
				o.poison(Rules.poison_dps * l * rm * f, Rules.poison_t * dm, tw, true, key)
			Elem.ICE:
				o.add_chill(Rules.ice_chill * l * f)
			Elem.WATER:
				var sf: float = Rules.water_slow - Rules.water_lv * l
				o.slow(1.0 - (1.0 - sf) * minf(f, 1.0), Rules.water_t * dm)
			Elem.EARTH:
				if randf() < minf(Rules.earth_ch * l, Rules.earth_max) * minf(f, 1.0):
					o.root(Rules.earth_t * dm)
			Elem.DARK:
				o.vuln(Rules.dark_t * dm, (Rules.dark_vuln + Rules.dark_lv * l) * minf(f, 1.0), tw, true)
			Elem.ELECTRIC:
				var d: float = o.hurt(ref_dmg(tw) * Rules.elec_dmg * l * f * rm, false, tw)
				tw.credit(d, key)
				tw.rx_dealt += d
				o.last_rx = true
			Elem.METAL:
				o.stagger(Rules.metal_stagger * l * f)
			Elem.SOUND:
				if o.tune_t <= 0.0 or l >= o.tune_lv:
					o.tune_lv = l
					o.tune_src = tw
				o.tune_t = maxf(o.tune_t, Rules.sound_t * dm * minf(f, 1.0))
			Elem.TIME:
				o.echo(minf(Rules.time_base + Rules.time_lv * l, Rules.time_max) * minf(f, 1.0), Rules.time_t * dm, tw)
			Elem.SOUL:
				if o.soul_t <= 0.0 or l >= o.soul_lv:
					o.soul_lv = l
					o.soul_src = tw
				o.soul_t = maxf(o.soul_t, Rules.soul_t * dm * minf(f, 1.0))
			_:
				continue
		n += 1
	condense(tw, o, n, f, key)


## 금속 응축: 효과 n개를 걸 때 추가 피해
static func condense(tw: Object, o: Orb, n: int, f: float, key := "share:metal") -> void:
	var km := k(tw, Elem.METAL)
	if km <= 0.0 or n <= 0 or o.hp <= 0.0:
		return
	var d: float = o.hurt(ref_dmg(tw) * METAL_K * n * km * f * o.resist_mul(_els(tw)), false, tw)
	tw.credit(d, "share:metal" if key == "" else key)
	tw.rx_dealt += d


## 효과 개수 (응축 계산용)
static func carry_n(tw: Object) -> int:
	var n := 0
	for e in _els(tw):
		if e in Elem.CARRY:
			n += 1
	return n


## 둘레 구체 모두에 (자기 빼고)
static func around(tw: Object, main: Node, at: Vector2, r: float, f: float, key: String, skip: Object = null) -> int:
	var n := 0
	for o in main.near(at, r + 20.0):
		if o != skip and is_instance_valid(o) and o.hp > 0.0 and o.position.distance_to(at) < r + o.radius():
			apply(tw, o, f, key)
			n += 1
	return n


## 불 타오름: 화상이 끝나거나 화상 걸린 채 죽으면 그 자리에서 불꽃
static func flare(o: Orb) -> void:
	var tw: Object = o.burn_src
	if o.burn_rx or not is_instance_valid(tw) or o.main == null:
		return
	var kf := k(tw, Elem.FIRE)
	if kf <= 0.0:
		return
	var r := FIRE_R * wide(tw)
	around(tw, o.main, o.position, r, FIRE_F * kf, "share:fire", o)
	o.main.burst(o.position, Elem.COLORS[Elem.FIRE], 6, 120.0)
	if o.main.pulses.size() < 40:
		o.main.pulses.append([o.position, r, 0.25])


## 독 전염: 중독된 채 죽으면 주변에 효과
static func contagion(o: Orb) -> void:
	var tw: Object = o.poison_src
	if o.poison_rx or not is_instance_valid(tw) or o.main == null:
		return
	var kp := k(tw, Elem.POISON)
	if kp > 0.0:
		around(tw, o.main, o.position, POISON_R * wide(tw), POISON_F * kp, "share:poison", o)


## 어둠 끌어당김: 약화된 채 죽으면 주변 구체를 그 자리로 끌고 효과
static func pull(o: Orb) -> void:
	var tw: Object = o.vuln_src
	if o.vuln_sh or o.vuln_t <= 0.0 or not is_instance_valid(tw) or o.main == null:
		return
	var kd := k(tw, Elem.DARK)
	if kd <= 0.0:
		return
	var r := DARK_R * wide(tw)
	for other in o.main.near(o.position, r + 20.0):
		if other != o and is_instance_valid(other) and other.hp > 0.0 and other.position.distance_to(o.position) < r:
			other.push((o.position - other.position).normalized() * DARK_PULL * kd)
			apply(tw, other, DARK_F * kd, "share:dark")
	o.main.burst(o.position, Elem.COLORS[Elem.DARK], 8, -90.0)


## 빛 꿰뚫음: 치명타가 난 구체 뒤쪽 일직선
static func pierce(tw: Object, o: Orb) -> void:
	var kl := k(tw, Elem.LIGHT)
	if kl <= 0.0 or tw.light_cd > 0.0 or tw.main == null:
		return
	tw.light_cd = LIGHT_CD
	var d: Vector2 = (o.position - tw.position).normalized()
	if d == Vector2.ZERO:
		d = tw.aim
	var length := LIGHT_LEN * wide(tw)
	var mid := o.position + d * length * 0.5
	for other in tw.main.near(mid, length * 0.5 + 20.0):
		if other == o or not is_instance_valid(other) or other.hp <= 0.0:
			continue
		var rel: Vector2 = other.position - o.position
		var along := rel.dot(d)
		if along > 0.0 and along < length and absf(rel.cross(d)) < LIGHT_W + other.radius():
			apply(tw, other, LIGHT_F * kl, "share:light")
	tw.main.beam(o.position, o.position + d * length, Elem.COLORS[Elem.LIGHT])


## Tower.hit에서: 땅 묻어둠(전에 묻어 둔 효과가 터짐 → 이번 오브젝트가 땅이면 새로 묻음) · 시간 되풀이
static func on_hit(tw: Object, o: Orb, shared: bool) -> void:
	if is_instance_valid(o.bury_src) and o.age <= o.bury_until:
		var b: Object = o.bury_src
		o.bury_src = null
		apply(b, o, EARTH_F * k(b, Elem.EARTH), "share:earth")
	if shared or o.hp <= 0.0 or not has_carry(tw):
		return
	if k(tw, Elem.EARTH) > 0.0:
		o.bury_src = tw
		o.bury_until = o.age + EARTH_T * dur(tw)
	var kt := k(tw, Elem.TIME)
	if kt > 0.0 and o.rep_cd <= 0.0:
		o.rep_cd = TIME_T
		tw.later.append([TIME_T, func():
			if is_instance_valid(o) and o.hp > 0.0:
				apply(tw, o, TIME_F * kt, "share:time")])
