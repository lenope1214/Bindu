class_name Share
## 특징 공유 (2026-11-03). 속성 = 효과(Elem.RIDER, 맞힌 구체에 거는 것) + 특징(Elem.TRAIT, 효과를 실어 나르는 방식).
## 한 오브젝트 안에서는 모든 특징이 모든 효과에 붙는다. 정해 둔 조합 공격은 없다.
## - apply(): 오브젝트의 실어 나를 수 있는 효과(Elem.CARRY)를 비율 f로 구체 하나에 건다. 피해는 주지 않는다(금속 응축·전기 감전 제외).
##   여기서 건 효과는 특징을 다시 타지 않는다 (한 번만 전달 → 끝없는 연쇄 없음).
## - 특징마다 실어 나르는 자리: 전기 튐(main.arc) · 소리 퍼짐(main.sound_pulse) · 독 전염·어둠 끌어당김·불 타오름(구체가 죽거나 화상이 끝날 때)
##   · 물 흐름(지나간 길 물길, Zone rill) · 땅 묻어둠·시간 되풀이·빛 꿰뚫음(Tower.hit) · 영혼 쫓아감(넋 혼불이 주인 오브젝트의 hit를 그대로 씀, 세기 배율 없음) · 별 모음(초신성)
## - 나무 자람·바람 넓힘·얼음 오래감·금속 응축은 실어 나르는 자리가 없고 세기·범위·시간을 바꾼다.
## 피해 출처 키는 "share:<특징 속성>" (Tower.src, 서버 통계).
## 실제 연상 개편 (2026-11-04): 특징은 두 종류.
## - 나르는 특징(SITE_E, 자리를 만듦): 불 번짐·물 물길·전기 튐·독 전염·소리 음파·빛 빛줄기·어둠 끌어당김·영혼 혼불·별 초신성.
## - 바꾸는 특징(MOD_E, 자리를 바꿈): 나무 자람·바람 실림·얼음 얼림·땅 다짐·금속 날 선·시간 되풀이. 같은 오브젝트의 모든 자리에 carry()가 한 번에 붙인다.
##   규칙이 모든 칸을 채우고, 이름 있는 칸(NAMED)만 따로 이름을 준다.

## 특징 속성 레벨별 세기 (Lv3에서 멈춤). 온라인 패치 rules.share_mul(전체) · rules.share_<속성>(특징마다)
static var LV_K := [0.0, 0.6, 0.8, 1.0]  # 특징 속성 레벨 0~3 세기

## 특징마다 실어 나르는 비율 (Lv3 기준, 세기 Share.k를 곱한다)
static var FIRE_F := 0.3  # 불 번짐: 타는 구체에 닿은 구체에 효과 비율 (FIRE_CD마다)
static var WATER_F := 0.3  # 물 흐름: 물길을 밟은 구체에 효과 비율
static var ELEC_F := 0.5  # 전기 튐: 튄 구체에 효과 비율
static var DARK_F := 0.3  # 어둠 끌어당김: 끌려온 구체에 효과 비율
static var LIGHT_F := 0.4  # 빛 꿰뚫음: 빛줄기 구체에 효과 비율
static var POISON_F := 0.5  # 독 전염: 둘레 구체에 효과 비율
static var SOUND_F := 0.5  # 소리 퍼짐: 음파에 닿은 구체에 효과 비율
static var TIME_F := 0.5  # 시간 되풀이: 한 번 더 거는 효과 비율
static var STAR_F := 1.0  # 별 모음: 초신성이 맞힌 구체에 효과 비율

static var FIRE_R := 26.0  # 불 번짐: 타는 구체 몸에서 이만큼 안에 닿은 구체
static var FIRE_CD := 0.6  # 불 번짐 간격
static var DARK_R := 90.0  # 끌어당김 반지름
static var DARK_PULL := 30.0  # 끌어당기는 거리(px)
static var LIGHT_LEN := 200.0  # 꿰뚫는 빛줄기 길이
static var LIGHT_W := 14.0  # 빛줄기 반폭
static var LIGHT_CD := 0.3  # 오브젝트마다 빛줄기 간격
static var POISON_R := 80.0  # 중독 전염 반지름 (예전 독 전염과 같음)
static var TIME_T := 0.8  # 되풀이까지
static var WIND_R := 0.4  # 넓힘: 범위 +40%
static var ICE_T := 0.5  # 오래감: 지속 +50%
static var WOOD_K := 0.06  # 자람: 자리가 없을 때 공격 자체가 자리 (오브젝트에서 100마다 +6%)
static var WOOD_MAX := 0.3  # 자람 최대
static var METAL_K := 0.12  # 응축: 효과 하나당 위력의 12%
static var METAL_STAG := 2.0  # 응축: 효과 하나당 멈칫 거리(px) (제어 회복 2026-11-04)
static var GROW_K := 0.5  # 자람: 자리 끝(진행 1)에서 효과 +50%
static var GROW_END := 0.8  # 자람: 자리 진행이 이만큼 넘은 곳에 닿은 구체는 덩굴에 묶임
static var GROW_ROOT := 0.4  # 자람: 덩굴 묶음 시간
static var WIND_PUSH := 10.0  # 실림: 자리가 닿은 구체를 바깥으로 미는 거리(px)
static var ICE_SITE := 0.4  # 얼림: 자리가 닿은 구체에 냉기
static var EARTH_CH := 0.15  # 다짐: 자리가 닿은 구체가 묶일 확률
static var METAL_SITE := 0.15  # 날 선: 자리가 닿을 때 추가 피해 (위력 배율)
static var WOOD_VINE := 1.0  # 휘감기: 맞을 때마다 감기는 덩굴 (레벨마다, 3이면 묶임)
static var WIND_HIT := 6.0  # 밀쳐냄: 맞은 구체를 미는 거리(px, 레벨마다)
static var RILL_SLOW := 0.8  # 물길: 밟은 구체는 효과와 따로 늘 이만큼 느려짐 (제어 회복)
static var RILL_T := 0.5  # 물길 감속 시간
static var EARTH_ROOT := 0.4  # 다짐: 묶는 시간

## 피 핏자국·환영 비춤 (2026-11-04 새 속성). 핏자국은 구체 자신이 지나간 길에만 (오브젝트와 고정 거리 장판 아님, ELEM-10)
static var BLOOD_F := 0.3  # 피 핏자국: 밟은 구체에 효과 비율
static var GORE_T := 1.5  # 핏자국이 남는 시간
static var GORE_STEP := 36.0  # 핏자국 간격(px, 구체가 이만큼 움직일 때마다 한 점)
static var GORE_MARK := 3.0  # 맞은 구체가 핏자국을 남기는 시간 (얼음 오래감을 곱함)
static var ILLU_F := 0.4  # 환영 비춤: 옆 오브젝트 다음 공격에 실리는 효과 비율
static var MIRROR_R := 220.0  # 비춤 둘레
static var MIRROR_T := 2.0  # 전달한 효과이 남는 시간 (그 안에 쏜 다음 공격에)
static var MIRROR_CD := 0.5  # 오브젝트마다 비추는 간격
static var SEPSIS := 0.5  # 패혈: 멈춰 있어도 이동 속도의 이만큼 움직인 셈
static var HUNGER := 0.15  # 굶주림: 핏자국을 밟은 구체가 받는 피해 +
static var CLOT_STAG := 6.0  # 응고: 핏자국을 밟은 구체 멈칫 거리(px)
static var STANCH_T := 2.0  # 지혈: 핏자국 시간 배율
static var NIGHTMARE := 1.5  # 악몽: 현혹된 구체가 받는 피해↑ 배율

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
static var NOURISH_MAX := 0.5  # 성장 촉진: 자람 최대
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


## 나르는 특징(자리) · 바꾸는 특징
const SITE_E := [Elem.FIRE, Elem.WATER, Elem.ELECTRIC, Elem.POISON, Elem.SOUND, Elem.LIGHT, Elem.DARK, Elem.SOUL, Elem.STAR, Elem.BLOOD, Elem.ILLUSION]
const MOD_E := [Elem.WOOD, Elem.WIND, Elem.ICE, Elem.EARTH, Elem.METAL, Elem.TIME]
const SITE_NOUN := {Elem.FIRE: "불", Elem.WATER: "물길", Elem.ELECTRIC: "전기", Elem.POISON: "독", Elem.SOUND: "음파",
	Elem.LIGHT: "빛줄기", Elem.DARK: "끌어당김", Elem.SOUL: "혼불", Elem.STAR: "초신성",
	Elem.BLOOD: "핏자국", Elem.ILLUSION: "효과 전달"}
const MOD_ADJ := {Elem.WOOD: "자라는", Elem.WIND: "바람에 실린", Elem.ICE: "얼어붙은", Elem.EARTH: "다져진", Elem.METAL: "날 선", Elem.TIME: "되풀이되는"}
## 따로 이름을 준 칸 [자리, 바꾸는 특징] → [이름, 설명]
const NAMED := {
	[Elem.WATER, Elem.WOOD]: ["덩굴 길", "물길을 따라 덩굴이 자라 갈수록 느리게 하다 끝에서 묶음"],
	[Elem.WATER, Elem.ICE]: ["얼음길", "물길이 얼어 오래 남고 밟은 구체에 냉기"],
	[Elem.WATER, Elem.EARTH]: ["진흙길", "물길이 진흙이 되어 밟은 구체가 확률로 묶임"],
	[Elem.FIRE, Elem.WIND]: ["불바람", "바람에 실려 불이 더 멀리 번지고 닿은 구체를 밀어냄"],
	[Elem.ELECTRIC, Elem.TIME]: ["연쇄 번개", "튄 전기가 잠시 뒤 한 번 더 튐"],
	[Elem.POISON, Elem.WIND]: ["독안개", "바람에 실려 독이 넓게 옮음"],
	[Elem.SOUND, Elem.ICE]: ["서리 음파", "음파에 닿은 구체에 냉기"],
	[Elem.SOUND, Elem.EARTH]: ["땅울림", "음파에 닿은 구체가 확률로 묶임"],
	[Elem.SOUND, Elem.TIME]: ["여운", "음파가 잠시 뒤 한 번 더 울림"],
	[Elem.LIGHT, Elem.METAL]: ["빛의 칼", "빛줄기에 날이 서서 닿은 구체에 추가 피해"],
}


## 자리 이름: 이름 있는 칸이면 그 이름, 아니면 "꾸밈말 자리"
static func site_name(site: int, mod: int) -> String:
	if site == Elem.ILLUSION:
		return Elem.pair_name(site, mod)
	if NAMED.has([site, mod]):
		return NAMED[[site, mod]][0]
	return "%s %s" % [MOD_ADJ[mod], SITE_NOUN[site]]


## 환영 자리의 설명은 도감·조합 카드와 같은 원문을 쓴다.
static func site_desc(site: int, mod: int) -> String:
	if site == Elem.ILLUSION:
		return Elem.pair_desc(site, mod)
	return NAMED[[site, mod]][1] if NAMED.has([site, mod]) else ""


## 오브젝트에 생긴 자리들 [[자리, 바꾸는 특징, 이름]] (속성 묶음 els)
static func sites_of(els: Dictionary) -> Array:
	var out := []
	for a in els:
		if a in SITE_E:
			for b in els:
				if b in MOD_E:
					out.append([a, b, site_name(a, b)])
	return out


## 속성 e를 더하면 새로 생기는 자리 이름들
static func new_sites(els: Dictionary, e: int) -> PackedStringArray:
	var out := PackedStringArray()
	if els.has(e):
		return out
	var more := els.duplicate()
	more[e] = 1
	for s2 in sites_of(more):
		if s2[0] == e or s2[1] == e:
			out.append(s2[2])
	return out


static func has_site(tw: Object) -> bool:
	for e in _els(tw):
		if e in SITE_E:
			return true
	return false


## 자리가 구체 o에 효과를 건다 (나르는 특징이 부름). at: 자리 가운데, stage: 자리 진행 0~1 (멀리·오래·끝으로 갈수록 1)
## 바꾸는 특징: 자람(진행할수록 세지고 끝에 묶음) · 실림(바깥으로 밀기) · 얼림(냉기) · 다짐(확률 묶음) · 날 선(추가 피해·멈칫) · 되풀이(잠시 뒤 한 번 더)
static func carry(tw: Object, o: Orb, f: float, key: String, at: Vector2, stage := 0.0, rep := false) -> void:
	if f <= 0.0 or not is_instance_valid(tw) or not is_instance_valid(o) or o.hp <= 0.0:
		return
	var st := clampf(stage * (1.5 if has(tw, "nourish") else 1.0), 0.0, 1.0)
	var kw := k(tw, Elem.WOOD)
	apply(tw, o, f * (1.0 + GROW_K * st * kw), key)
	if o.hp <= 0.0:
		return
	if kw > 0.0 and st >= GROW_END:
		o.root(GROW_ROOT * minf(kw, 1.5))
	var kn := k(tw, Elem.WIND)
	if kn > 0.0:
		var away := o.position - at
		if away.length() > 0.5:
			o.knock(away.normalized() * WIND_PUSH * kn * minf(f, 1.0))
	var ki := k(tw, Elem.ICE)
	if ki > 0.0:
		o.add_chill(ICE_SITE * ki * minf(f, 1.0), dur(tw))
	var ke := k(tw, Elem.EARTH)
	if ke > 0.0 and randf() < EARTH_CH * ke * minf(f * 2.0, 1.0):
		o.root(EARTH_ROOT * dur(tw))
	var km := k(tw, Elem.METAL)
	if km > 0.0:
		o.stagger(METAL_STAG * km)
		var d: float = o.hurt(ref_dmg(tw) * METAL_SITE * km * minf(f * 2.0, 1.0) * o.resist_mul(_els(tw)), false, tw)
		tw.credit(d, "share:metal")
		tw.rx_dealt += d
	var kt := k(tw, Elem.TIME)
	if kt > 0.0 and not rep:
		var oid := o.get_instance_id()
		for i in (AFTER_N if has(tw, "after") else 1):
			tw.later.append([TIME_T * (i + 1), func():
				var oo = instance_from_id(oid)
				if oo != null and oo.hp > 0.0:
					carry(tw, oo, f * TIME_F * kt, key, at, stage, true)])


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
		Elem.BLOOD:
			if ids.has("clot") or ids.has("stanch"):
				v *= AFF_WEAK
		Elem.ILLUSION:
			if ids.has("mirage"):
				v *= AFF_WEAK
	return v


## 피 출혈 세기 (100px마다)
static func bleed_k(tw: Object, l: int, rm := 1.0) -> float:
	return Rules.blood_dmg * l * rm * am(tw, Elem.BLOOD)


## 환영 현혹 확률
static func illu_ch(tw: Object, l: int) -> float:
	return minf(Rules.illu_ch * l, Rules.illu_max) * am(tw, Elem.ILLUSION)


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
	return Tower.pw(tw.plv) * tw.dmg_k_bare()


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
			Elem.WOOD:
				o.entangle(WOOD_VINE * l * f * am(tw, e), dm)
			Elem.SOUL:
				if o.soul_t <= 0.0 or l >= o.soul_lv:
					o.soul_lv = l
					o.soul_src = tw
				o.soul_t = maxf(o.soul_t, Rules.soul_t * dm * minf(f, 1.0))
			Elem.BLOOD:
				o.bleed(bleed_k(tw, l, rm) * f, Rules.blood_t * dm, tw, key, has(tw, "sepsis"))
			Elem.ILLUSION:
				if randf() < illu_ch(tw, l) * minf(f, 1.0):
					o.confuse(Rules.illu_t * dm, has(tw, "nightmare"))
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
	for o in main.combat_system.near(at, r + 20.0):
		if o != skip and is_instance_valid(o) and o.hp > 0.0 and o.position.distance_to(at) < r + o.radius():
			carry(tw, o, f, key, at, o.position.distance_to(at) / maxf(r, 1.0))
			n += 1
	return n


## 불 번짐: 타는 구체가 몸에 닿은 구체에 불을 옮겨 붙인다 (Orb가 탈 때 FIRE_CD마다). 옮겨 붙은 불은 다시 번지지 않는다(1세대)
static func spread(o: Orb) -> void:
	var tw: Object = o.burn_src
	if o.burn_rx or not is_instance_valid(tw) or o.main == null:
		return
	var kf := k(tw, Elem.FIRE)
	if kf <= 0.0:
		return
	var r := o.radius() + FIRE_R * wide(tw) * (1.0 + BLAZE_R if has(tw, "blaze") else 1.0)
	if around(tw, o.main, o.position, r, FIRE_F * kf, "share:fire", o) > 0:
		o._spawning_port.burst(o.position, Elem.COLORS[Elem.FIRE], 3, 60.0)


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
	for other in o._combat_port.near(o.position, r + 20.0):
		if other != o and is_instance_valid(other) and other.hp > 0.0 and other.position.distance_to(o.position) < r:
			other.push((o.position - other.position).normalized() * DARK_PULL * kd)
			carry(tw, other, DARK_F * kd, "share:dark", o.position, other.position.distance_to(o.position) / r)
	o._spawning_port.burst(o.position, Elem.COLORS[Elem.DARK], 8, -90.0)


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
	for other in tw._combat_port.near(mid, length * 0.5 + 20.0):
		if other == o or not is_instance_valid(other) or other.hp <= 0.0:
			continue
		var rel: Vector2 = other.position - o.position
		var along := rel.dot(d)
		if along > 0.0 and along < length and absf(rel.cross(d)) < LIGHT_W + other.radius():
			carry(tw, other, LIGHT_F * kl, "share:light", other.position - d, along / length)
	tw._spawning_port.beam(o.position, o.position + d * length, Elem.COLORS[Elem.LIGHT])


## Tower.hit에서: 자리가 없는 오브젝트는 공격 자체를 자리로 본다 (땅 다짐: 맞은 구체가 확률로 묶임) · 시간 되풀이(맞힌 구체에 효과 한 번 더)
static func on_hit(tw: Object, o: Orb, shared: bool) -> void:
	if shared or o.hp <= 0.0:
		return
	var ke := k(tw, Elem.EARTH)
	if ke > 0.0 and not has_site(tw) and randf() < EARTH_CH * ke:
		o.root(EARTH_ROOT * dur(tw))
	if not has_carry(tw):
		return
	var kt := k(tw, Elem.TIME)
	if kt > 0.0 and o.rep_cd <= 0.0:
		o.rep_cd = TIME_T
		var oid := o.get_instance_id()
		for i in (AFTER_N if has(tw, "after") else 1):
			tw.later.append([TIME_T * (i + 1), func():
				var oo = instance_from_id(oid)
				if oo != null and oo.hp > 0.0:
					apply(tw, oo, TIME_F * kt, "share:time")])


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
			tw._spawning_port.burst(o.position, Color(0.8, 0.9, 1.0), 6, 100.0)
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
	for other in tw._combat_port.near(o.position, r + 20.0):
		if other == o or not is_instance_valid(other) or other.hp <= 0.0 or other.position.distance_to(o.position) > r + other.radius():
			continue
		if blz:
			other.add_chill(Rules.ice_chill * els[Elem.ICE] * NEAR_F * minf(k, 1.0) * am(tw, Elem.ICE), dm)
		if stm or rain:
			var m := am(tw, Elem.WATER) * (1.0 if stm else NEAR_F)
			other.slow(slow_f(els[Elem.WATER], m), Rules.water_t * dm)
	if tw.main.pulses.size() < 40:
		tw.main.pulses.append([o.position, r, 0.2])


## 피 핏자국: 핏자국을 남기는 구체가 GORE_STEP 움직일 때마다 (Orb._blood_step). 장판은 그 구체가 지나간 자리에만
static func gore(o: Orb) -> void:
	var tw: Object = o.gore_src
	if not is_instance_valid(tw) or tw.main == null:
		return
	var kb := k(tw, Elem.BLOOD)
	if kb <= 0.0:
		return
	# 구체 하나에 핏자국 장판 하나 (점을 더함). 남긴 오브젝트가 바뀌면 새 줄
	var z: Zone = o.gore_zone as Zone if is_instance_valid(o.gore_zone) else null
	if z == null or z.is_queued_for_deletion() or z.owner_tower != tw:
		if tw.main.zones.get_child_count() >= 160:
			return
		var old_tag: String = tw.tag
		tw.tag = "share:blood"
		z = tw._spawning_port.spawn_zone("gore", tw.plv, o.position, tw)
		tw.tag = old_tag
		z.gore_path(o)
		o.gore_zone = z
	z.amt = kb
	z.add_gore_pt(o.position, kb, GORE_T * dur(tw) * (STANCH_T if has(tw, "stanch") else 1.0))


## 핏자국을 밟은 구체 (Zone gore, 같은 구체는 0.5초에 한 번, 핏자국을 남긴 구체는 빼고)
static func gore_step(tw: Object, o: Orb, amt: float, at: Vector2, stage: float) -> void:
	carry(tw, o, BLOOD_F * amt, "share:blood", at, stage)
	if o.hp <= 0.0:
		return
	if has(tw, "clot"):
		o.stagger(CLOT_STAG)
	if has(tw, "hunger"):
		o.vuln(Rules.dark_t, HUNGER)


## Tower.hit에서: 피가 든 오브젝트가 맞힌 구체는 한동안 핏자국을 남긴다 · 환영이 든 오브젝트는 옆 오브젝트에 상을 비춘다
static func mark(tw: Object, o: Orb) -> void:
	if o.hp <= 0.0 or not has_carry(tw):
		return
	if k(tw, Elem.BLOOD) > 0.0:
		o.gore_src = tw
		o.gore_t = maxf(o.gore_t, GORE_MARK * dur(tw))
	var ki := k(tw, Elem.ILLUSION)
	if ki > 0.0 and tw.mirror_cd <= 0.0 and tw.main:
		tw.mirror_cd = MIRROR_CD
		var r := MIRROR_R * wide(tw)
		var near: Array = []
		for t2 in tw.main.towers.get_children():
			if t2 != tw and is_instance_valid(t2) and not t2.is_queued_for_deletion() and t2.position.distance_to(tw.position) < r:
				near.append(t2)
		near.sort_custom(func(a, b): return a.position.distance_to(tw.position) < b.position.distance_to(tw.position))
		for t2 in near.slice(0, 2 if has(tw, "mirage") else 1):
			t2.mirror_src = tw
			t2.mirror_t = MIRROR_T
			t2.mirror_f = ILLU_F * ki


## 전달한 효과을 받은 오브젝트가 다음에 맞힐 때 (Tower.hit): 비춘 오브젝트 효과를 이 구체에 (한 번 쓰면 사라짐)
static func reflect(tw: Object, o: Orb) -> void:
	var src: Object = tw.mirror_src
	tw.mirror_src = null
	if not is_instance_valid(src) or src == tw or o.hp <= 0.0:
		return
	carry(src, o, tw.mirror_f, "share:illusion", tw.position, 0.0)
	if tw.main and tw.main.pulses.size() < 40:
		tw._spawning_port.beam(src.position, tw.position, Elem.COLORS[Elem.ILLUSION])
