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
static var METAL_STAG := 2.0  # 응축: 효과 하나당 멈칫 거리(px) (제어 회복 2026-11-04)
static var RILL_SLOW := 0.8  # 물길: 밟은 구체는 효과와 따로 늘 이만큼 느려짐 (제어 회복)
static var RILL_T := 0.5  # 물길 감속 시간
static var EARTH_ROOT := 0.3  # 묻어둠이 터질 때 묶는 시간 (제어 회복)

## 상성 (2026-11-04, Elem.TAGS·AFF_RULES). 같은 오브젝트 안 두 속성 짝마다.
static var AFF_CARRY := 1.5  # 강상성 속성의 특징 세기
static var AFF_EFF := 1.2  # 강상성 속성의 효과 세기
static var AFF_WEAK := 0.5  # 약상성으로 줄어드는 효과
static var SHOCK_R := 0.4  # 감전: 전기 튀는 거리 +
static var SHOCK_STAG := 6.0  # 감전: 튄 구체 멈칫 거리(px)
static var FUEL := 1.5  # 연료: 화상
static var BLAZE_R := 0.5  # 불길: 타오름 범위 +
static var FREEZE := 1.5  # 얼어붙음: 냉기
static var NEAR_R := 60.0  # 눈보라·비바람·증기: 맞은 구체 둘레
static var NEAR_F := 0.5  # 눈보라·비바람: 둘레 구체에 거는 비율
static var NEAR_CD := 0.2  # 둘레에 거는 간격 (오브젝트마다)
static var QUAKE := 1.5  # 지진: 기절 확률·경직
static var RUST := 0.15  # 녹: 중독된 구체가 받는 피해 +
static var RESO_R := 0.5  # 공진: 음파 범위 +
static var NOURISH_MAX := 0.5  # 자양: 자람 최대
static var AFTER_N := 2  # 잔상: 시간 되풀이 횟수
static var THERMO_DMG := 0.6  # 온도 충격: 냉기를 터뜨린 피해 (위력 배율)
static var THERMO_STAG := 10.0  # 온도 충격: 멈칫 거리(px)
static var THERMO_MIN := 1.0  # 온도 충격: 이만큼 냉기가 쌓인 구체만
static var ECLIPSE_T := 2.0  # 일식: 치명타 때 약화 시간 배율
static var GROUND_CH := 0.2  # 접지: 기절 확률 +
static var WITHER_SLOW := 0.85  # 시듦: 중독된 구체 이동 속도


static func key_of(e: int) -> String:
	return "share:" + Patch.ELEM_KEYS[Elem.ALL.find(e)]


## 특징 세기 (0이면 그 특징이 없음)
static func k(tw: Object, e: int) -> float:
	if not is_instance_valid(tw):
		return 0.0
	var l: int = _els(tw).get(e, 0)
	if l <= 0:
		return 0.0
	var v: float = LV_K[mini(l, 3)] * Rules.share_mul * Rules.share_k.get(e, 1.0)
	if aff(tw)["strong_e"].has(e):
		v *= AFF_CARRY
	return v


## 오브젝트의 상성: {"ids": {규칙 id: true}, "strong_e": {강상성에 든 속성: true}, "pairs": [[a, b, Elem.aff_of]]}
static var _aff := {}


static func aff(tw: Object) -> Dictionary:
	var els := _els(tw)
	var ck := 0
	for e in els:
		ck |= 1 << int(e)
	if _aff.has(ck):
		return _aff[ck]
	var ks: Array = els.keys()
	ks.sort()
	var out := {"ids": {}, "strong_e": {}, "pairs": []}
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			var r := Elem.aff_of(ks[i], ks[j])
			if r["ids"].is_empty():
				continue
			out["pairs"].append([ks[i], ks[j], r])
			for id in r["ids"]:
				out["ids"][id] = true
			if r["strong"]:
				out["strong_e"][ks[i]] = true
				out["strong_e"][ks[j]] = true
	_aff[ck] = out
	return out


static func has(tw: Object, id: String) -> bool:
	return is_instance_valid(tw) and aff(tw)["ids"].has(id)


## 상성이 바꾸는 효과 세기 배율 (속성 e의 효과). 접지면 전기는 0 (튀지 않음)
static func am(tw: Object, e: int) -> float:
	if not is_instance_valid(tw):
		return 1.0
	var a := aff(tw)
	if a["pairs"].is_empty():
		return 1.0
	var ids: Dictionary = a["ids"]
	var v := AFF_EFF if a["strong_e"].has(e) else 1.0
	match e:
		Elem.FIRE:
			if ids.has("fuel"):
				v *= FUEL
			if ids.has("steam") or ids.has("thermo"):
				v *= AFF_WEAK
		Elem.ICE:
			if ids.has("freeze"):
				v *= FREEZE
			if ids.has("thermo"):
				v *= AFF_WEAK
		Elem.WATER:
			if ids.has("steam"):
				v *= AFF_WEAK
		Elem.EARTH, Elem.METAL:
			if ids.has("quake"):
				v *= QUAKE
		Elem.DARK, Elem.LIGHT:
			if ids.has("eclipse"):
				v *= AFF_WEAK
		Elem.WOOD:
			if ids.has("wither"):
				v *= AFF_WEAK
		Elem.ELECTRIC:
			if ids.has("ground"):
				v = 0.0
	return v


## 물 감속 배율 (1에 가까울수록 약함): 기본 감속을 상성 세기 m만큼
static func slow_f(l: int, m: float) -> float:
	var sf: float = Rules.water_slow - Rules.water_lv * l
	return clampf(1.0 - (1.0 - sf) * m, 0.3, 1.0)


## 땅 기절 확률 (상성·접지 포함)
static func root_ch(tw: Object, l: int) -> float:
	var c := minf(Rules.earth_ch * l, Rules.earth_max) * am(tw, Elem.EARTH)
	if has(tw, "ground"):
		c += GROUND_CH
	return minf(c, 0.95)


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
	var mx := NOURISH_MAX if has(tw, "nourish") else WOOD_MAX
	return 1.0 + minf(WOOD_K * tw.position.distance_to(o.position) / 100.0, mx) * kw


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
				o.burn(Rules.fire_dps * l * rm * f * am(tw, e), Rules.fire_t * dm, tw, true, key)
			Elem.POISON:
				o.poison(Rules.poison_dps * l * rm * f * am(tw, e), Rules.poison_t * dm, tw, true, key)
			Elem.ICE:
				o.add_chill(Rules.ice_chill * l * f * am(tw, e), dm)
			Elem.WATER:
				o.slow(slow_f(l, minf(f, 1.0) * am(tw, e)), Rules.water_t * dm)
			Elem.EARTH:
				if randf() < root_ch(tw, l) * minf(f, 1.0):
					o.root(Rules.earth_t * dm)
			Elem.DARK:
				o.vuln(Rules.dark_t * dm, (Rules.dark_vuln + Rules.dark_lv * l) * minf(f, 1.0) * am(tw, e), tw, true)
			Elem.ELECTRIC:
				var d: float = o.hurt(ref_dmg(tw) * Rules.elec_dmg * l * f * rm, false, tw)
				tw.credit(d, key)
				tw.rx_dealt += d
				o.last_rx = true
			Elem.METAL:
				o.stagger(Rules.metal_stagger * l * f * am(tw, e))
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
	o.stagger(METAL_STAG * n * km * f)
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
	var r := FIRE_R * wide(tw) * (1.0 + BLAZE_R if has(tw, "blaze") else 1.0)
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
		if o.hp > 0.0:
			o.root(EARTH_ROOT * dur(b))
	if shared or o.hp <= 0.0 or not has_carry(tw):
		return
	if k(tw, Elem.EARTH) > 0.0:
		o.bury_src = tw
		o.bury_until = o.age + EARTH_T * dur(tw)
	var kt := k(tw, Elem.TIME)
	if kt > 0.0 and o.rep_cd <= 0.0:
		o.rep_cd = TIME_T
		for i in (AFTER_N if has(tw, "after") else 1):
			tw.later.append([TIME_T * (i + 1), func():
				if is_instance_valid(o) and o.hp > 0.0:
					apply(tw, o, TIME_F * kt, "share:time")])


## Tower.hit에서 효과를 건 뒤: 상성이 더하는 것 (눈보라·비바람·증기 둘레, 녹, 시듦, 온도 충격, 일식). lit: 빛 치명타, had_chill: 맞기 전 냉기
static func aff_hit(tw: Object, o: Orb, k: float, lit: bool, had_chill: float) -> void:
	var a := aff(tw)
	if a["pairs"].is_empty() or not is_instance_valid(o):
		return
	var ids: Dictionary = a["ids"]
	var els := _els(tw)
	var dm := dur(tw)
	# 온도 충격: 냉기가 쌓인 구체에 불이 닿으면 냉기를 터뜨린다
	if ids.has("thermo") and els.has(Elem.FIRE) and had_chill >= THERMO_MIN and o.hp > 0.0:
		o.chill = 0.0
		o.stagger(THERMO_STAG)
		var d: float = o.hurt(ref_dmg(tw) * THERMO_DMG * minf(had_chill, 3.0) / 3.0 * o.resist_mul(els), false, tw)
		tw.credit(d, "aff:thermo")
		if tw.main:
			tw.main.burst(o.position, Color(0.8, 0.9, 1.0), 6, 100.0)
	if o.hp <= 0.0:
		return
	if ids.has("rust") and els.has(Elem.POISON) and o.poison_t > 0.0:
		o.vuln(Rules.poison_t * dm, RUST)
	if ids.has("wither") and els.has(Elem.POISON):
		o.slow(WITHER_SLOW, Rules.poison_t * dm)
	if ids.has("eclipse") and lit and els.has(Elem.DARK):
		o.vuln(Rules.dark_t * dm * ECLIPSE_T, Rules.dark_vuln + Rules.dark_lv * els[Elem.DARK], tw)
	# 둘레: 맞은 구체 둘레 구체들 (장판 없이 그 순간 거기 있는 구체에만)
	var blz: bool = ids.has("blizzard") and els.has(Elem.ICE)
	var stm: bool = ids.has("steam") and els.has(Elem.WATER)
	var rain: bool = ids.has("storm") and els.has(Elem.WATER)
	if not (blz or stm or rain) or tw.aff_cd > 0.0 or tw.main == null:
		return
	tw.aff_cd = NEAR_CD
	var r := NEAR_R * wide(tw)
	for other in tw.main.near(o.position, r + 20.0):
		if other == o or not is_instance_valid(other) or other.hp <= 0.0 or other.position.distance_to(o.position) > r + other.radius():
			continue
		if blz:
			other.add_chill(Rules.ice_chill * els[Elem.ICE] * NEAR_F * minf(k, 1.0) * am(tw, Elem.ICE), dm)
		if stm or rain:
			var m := am(tw, Elem.WATER) * (1.0 if stm else NEAR_F)
			other.slow(slow_f(els[Elem.WATER], m), Rules.water_t * dm)
	if tw.main.pulses.size() < 40:
		tw.main.pulses.append([o.position, r, 0.2])
