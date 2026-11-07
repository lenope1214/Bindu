class_name Nature
## 자연 현상·속성 4특성 (2026-11-07, 브랜치 elements-nature, 시험).
## 속성 = 기질(QUIRK) + 효과(Elem.RIDER) + 전달(Elem.TRAIT) + 문턱(BURST). 효과·전달은 Share가 그대로 맡는다.
## - 상태(STATES): 속성이 구체에 젖음·마름·열·얼음막·도체·접지·부식·진동을 남긴다. 덩굴은 Orb.vine.
##   속성은 지금 상태를 보고 다르게 움직이고, 부딪치는 상태는 지우지 않고 변환된다(증기·녹음·산불·파쇄…). 감쇄만 하는 조합은 없다.
##   상태는 구체에만 붙는다(바닥 장판 없음). 다른 오브젝트가 남긴 상태에도 반응하므로 배치가 시너지를 만든다.
## - 문턱: 구체마다 속성별 게이지(0~100). 그 속성 효과가 걸릴 때 차고(기질 배율), 차면 큐에 넣어 터진다.
##   터질 때 그 오브젝트의 모든 효과를 100% 걸고(문턱×효과), 맞은 구체의 다른 게이지를 채운다(문턱×문턱, 연쇄 chain_max 단계, 단계마다 x chain_fade).
##   전달로 실린 효과도 게이지를 gauge_carry 비율로 채운다(전달×문턱).
## - 기질: 그 속성 효과·게이지에 붙는 장점+단점 배율. 같은 오브젝트의 다른 효과에는 절반 세기(기질×효과).
## - 도파민 모드(규칙 3): 속성이 rot_n개보다 많은 오브젝트는 상태·문턱만 rot_iv초마다 rot_n개씩 돌아가며 건다 (효과는 모두 그대로).
##   2026-11-07 봇: 효과까지 돌리면 몰빵 오브젝트가 크게 약해짐(평균 56→14.5웨이브)이라 효과는 빼고 현상만 돌림.
## 피해 출처 키: "nat:<현상 id>" · "burst:<속성>".

## 상태 → [이름, 색, 기본 시간]
const STATES := {
	"wet": ["젖음", Color(0.35, 0.6, 1.0), 3.0],
	"dry": ["마름", Color(0.9, 0.75, 0.45), 3.0],
	"heat": ["열", Color(1.0, 0.45, 0.15), 2.0],
	"ice": ["얼음막", Color(0.75, 0.95, 1.0), 3.0],
	"cond": ["도체", Color(0.95, 0.85, 0.3), 3.0],
	"ground": ["접지", Color(0.65, 0.5, 0.3), 2.0],
	"rot": ["부식", Color(0.55, 0.8, 0.25), 3.0],
	"quake": ["진동", Color(1.0, 0.55, 0.8), 1.0],
}
const STATE_ORDER := ["wet", "dry", "heat", "ice", "cond", "ground", "rot", "quake"]

## 속성이 남기는 상태
const LEAVES := {
	Elem.WATER: "wet", Elem.FIRE: "heat", Elem.STAR: "heat", Elem.WIND: "dry", Elem.METAL: "cond",
	Elem.EARTH: "ground", Elem.POISON: "rot", Elem.BLOOD: "rot", Elem.SOUND: "quake",
}

## 변환(현상) id → [이름, 설명]. 도감·첫 발현 알림·피해 출처에 쓴다
const PHENOMENA := {
	"steam": ["증기", "젖은 구체에 열이 닿으면 증발해 둘레 무리가 느려지고 데어요."],
	"melt": ["녹음", "얼음막이 열에 녹아 온도 충격 피해를 주고 구체가 젖어요."],
	"freeze": ["얼어붙음", "젖은 구체가 얼어 얼음막이 생기고 오래 멈춰요."],
	"wildfire": ["산불", "마른 덩굴에 불이 붙어 덩굴을 태우며 크게 데고, 둘레 덩굴로 번져요."],
	"lightning_tree": ["낙뢰목", "마른 덩굴에 번개가 떨어져 덩굴이 타 버리고 화상이 남아요."],
	"circuit": ["덩굴 회로", "젖은 덩굴로 이어진 구체 모두에 번개가 한꺼번에 흘러요."],
	"conduct": ["감전", "젖거나 도체인 구체에서는 번개가 멀리 튀고 전하가 두 배로 쌓여요."],
	"ground": ["접지", "접지된 구체에선 번개가 튀지 않고 땅으로 빠지며 둘레 무리를 기절시켜요."],
	"shatter": ["파쇄", "얼음막이 진동에 깨져 큰 피해를 주고 파편이 튀어요."],
	"rust": ["녹", "도체 상태 구체가 부식되면 받는 피해가 늘어요."],
	"dry_out": ["말림", "바람이 젖음을 말려요. 마른 구체는 불이 잘 붙어요."],
	"cata": ["대격변", "17속성을 모두 모은 오브젝트가 한 바퀴 돌 때마다 맞힌 구체의 모든 게이지가 차올라요."],
}

## 기질: 속성 → [이름, 설명]. 배율은 quirk()
const QUIRK := {
	Elem.FIRE: ["불씨", "처음 두 번은 약하고(x0.8), 그 뒤로는 세게 타요(x1.25)."],
	Elem.WOOD: ["뿌리", "덩굴이 두 겹 넘게 감겼거나 묶인 구체에 x1.4, 아니면 x0.9."],
	Elem.WATER: ["흐름", "효과는 x0.85로 약하지만 젖음이 오래 남아요."],
	Elem.ELECTRIC: ["전하", "첫 피해는 x0.8, 같은 구체를 연달아 맞힐 때마다 +12% (최대 x1.5)."],
	Elem.WIND: ["기류", "가까운 구체엔 x0.85, 멀수록 세져 300 밖에서 x1.3."],
	Elem.ICE: ["느린 냉기", "냉기가 x0.85로 천천히 쌓이지만 오래가요."],
	Elem.EARTH: ["무게", "효과 x1.25, 대신 게이지가 x0.7로 천천히 차요."],
	Elem.DARK: ["잠식", "처음 맞힐 땐 x0.8, 두 번째부터 x1.2."],
	Elem.LIGHT: ["집중", "체력이 70% 넘게 남은 구체에 x1.3, 아니면 x0.85."],
	Elem.POISON: ["잠복", "세 번째 맞힐 때까진 x0.8, 그 뒤로 x1.35."],
	Elem.METAL: ["자성", "단단한 구체·보스·보호막 구체에 x1.4, 아니면 x0.85."],
	Elem.SOUND: ["박자", "같은 간격으로 맞히면 x1.3, 박자가 어긋나면 x0.8."],
	Elem.TIME: ["지연", "효과 x1.2, 대신 게이지가 x0.7로 천천히 차요."],
	Elem.SOUL: ["염원", "체력 30% 아래 구체에 x1.5, 아니면 x0.85."],
	Elem.STAR: ["인력", "기질이 따로 없고 초신성이 문턱이에요."],
	Elem.BLOOD: ["혈관", "빠르게 움직이는 구체에 x1.3, 멈춘 구체엔 x0.5."],
	Elem.ILLUSION: ["안개", "효과 x0.8, 대신 게이지가 x1.3으로 빨리 차요."],
}

## 문턱: 속성 → [이름, 설명, 피해(위력 배율), 반지름(0이면 그 구체만)]
const BURST := {
	Elem.FIRE: ["발화점", "열이 차면 폭연: 둘레 구체를 크게 태워요.", 1.2, 70.0],
	Elem.WOOD: ["만개", "덩굴이 차면 가시가 터져 둘레 덩굴 감긴 구체에 큰 피해·묶음.", 1.6, 70.0],
	Elem.WATER: ["수압", "젖음이 차면 물살이 구체를 왔던 길로 되밀어요.", 0.6, 0.0],
	Elem.ELECTRIC: ["저항 돌파", "전하가 차면 x4 방전, 젖거나 도체인 둘레 구체로 이어 튀어요.", 4.0, 0.0],
	Elem.WIND: ["돌풍", "회오리에 떠 1초 멈춘 뒤 떨어지며 피해.", 1.0, 0.0],
	Elem.ICE: ["파쇄", "얼어 있는 구체가 산산조각: x3 피해, 둘레로 파편.", 3.0, 0.0],
	Elem.EARTH: ["균열", "땅이 갈라져 둘레 구체가 기절해요.", 0.8, 80.0],
	Elem.DARK: ["삼킴", "체력 15% 아래(보스 5%)면 그대로 삼켜요.", 0.0, 0.0],
	Elem.LIGHT: ["집광", "섬광이 터져 둘레 구체가 눈부셔 멈춰요.", 0.5, 90.0],
	Elem.POISON: ["치사량", "남은 독 피해를 한꺼번에 받아요.", 0.0, 0.0],
	Elem.METAL: ["자화", "둘레 구체를 끌어당겨 부딪히게 해요.", 0.8, 100.0],
	Elem.SOUND: ["공진 붕괴", "터지며 둘레 구체를 흔들어 다른 게이지를 채워요.", 1.0, 80.0],
	Elem.TIME: ["정지", "1초 멈춘 뒤 쌓인 피해를 한꺼번에 받아요.", 2.0, 0.0],
	Elem.SOUL: ["빙의", "넋이 들려 헤매며 둘레 구체와 부딪혀요.", 1.0, 60.0],
	Elem.BLOOD: ["과다출혈", "피가 터져 크게 다치고 핏자국이 길게 남아요.", 2.0, 0.0],
	Elem.ILLUSION: ["미궁", "둘레 구체까지 길을 잃고 되돌아가요.", 0.0, 60.0],
}

## 게이지가 한 번(Lv1, 세기 1) 걸릴 때 차는 양
const FILL := {
	Elem.FIRE: 14.0, Elem.WOOD: 14.0, Elem.WATER: 12.0, Elem.ELECTRIC: 13.0, Elem.WIND: 12.0, Elem.ICE: 14.0,
	Elem.EARTH: 12.0, Elem.DARK: 16.0, Elem.LIGHT: 12.0, Elem.POISON: 13.0, Elem.METAL: 12.0, Elem.SOUND: 14.0,
	Elem.TIME: 12.0, Elem.SOUL: 14.0, Elem.BLOOD: 13.0, Elem.ILLUSION: 12.0,
}
const FULL := 100.0
const DECAY := 6.0  # 게이지가 초당 줄어드는 양
const BURST_CD := 1.0  # 한 구체에서 같은 문턱은 이만큼에 한 번
const CHAIN_FILL := 40.0  # 터진 문턱이 맞은 구체의 다른 게이지에 더하는 양
const STATE_CD := 0.2  # 한 구체의 변환은 이만큼에 한 번
const BUDGET := 8  # 0.1초마다 터질 수 있는 문턱 수 (넘치면 다음으로 미룸)
const CIRCUIT_R := 90.0  # 덩굴 회로: 이웃으로 이어지는 거리
const CIRCUIT_MAX := 12

static var queue: Array = []  # [orb, elem, tower, depth]
static var _budget_t := 0.0
static var _budget_n := 0
static var seen := {}  # 이번 판에 처음 본 현상·문턱 (알림 한 번)
static var depth := 0  # 지금 처리 중인 문턱 연쇄 단계 (apply가 게이지를 채울 때 씀)


static func reset() -> void:
	queue.clear()
	seen.clear()
	depth = 0


static func on() -> bool:
	return Rules.t("nat_on") > 0.0


# ───────────── 상태 ─────────────

static func has(o: Orb, s: String) -> bool:
	return o.nat.get(s, 0.0) > 0.0


static func wet_vine(o: Orb) -> bool:
	return o.vine >= 0.5 and has(o, "wet")


static func dry_vine(o: Orb) -> bool:
	return o.vine >= 0.5 and not has(o, "wet")


static func _put(o: Orb, s: String, t := -1.0) -> void:
	o.nat[s] = maxf(o.nat.get(s, 0.0), STATES[s][2] if t < 0.0 else t)


static func _drop(o: Orb, s: String) -> void:
	o.nat.erase(s)


## 속성 e가 구체에 닿았다 (맞힘·전달 모두). f: 세기. 남기는 상태를 붙이고, 부딪치는 상태는 변환한다.
static func touch(tw: Object, o: Orb, e: int, f: float) -> void:
	if not on() or not is_instance_valid(o) or o.hp <= 0.0:
		return
	var free := o.nat_cd <= 0.0
	match e:
		Elem.WATER:
			if has(o, "heat") and free:
				_steam(tw, o)
			else:
				_drop(o, "dry")
				_put(o, "wet", STATES["wet"][2] * (1.5 if is_instance_valid(tw) and tw.elements.has(Elem.WATER) else 1.0))
		Elem.FIRE, Elem.STAR:
			if has(o, "ice") and free:
				_melt(tw, o)
			elif has(o, "wet") and free:
				_steam(tw, o)
			else:
				if dry_vine(o) and free and e == Elem.FIRE:
					_wildfire(tw, o)
				_put(o, "heat")
		Elem.ICE:
			if has(o, "heat") and free:
				_melt(tw, o)
			elif has(o, "wet"):
				if not has(o, "ice"):
					_note(tw, "freeze", o.position)
				_drop(o, "wet")
				_put(o, "ice")
				o.add_chill(1.0 * minf(f, 1.0), 1.5)
		Elem.WIND:
			if has(o, "wet"):
				_drop(o, "wet")
				_note(tw, "dry_out", o.position)
			_put(o, "dry")
			if has(o, "heat") and dry_vine(o) and free:
				_wildfire(tw, o, 1.6)
		Elem.METAL:
			if has(o, "rot") and not has(o, "cond"):
				_rust(tw, o)
			_put(o, "cond")
		Elem.EARTH:
			_put(o, "ground")
		Elem.POISON, Elem.BLOOD:
			if has(o, "cond"):
				_rust(tw, o)
			_put(o, "rot")
		Elem.SOUND:
			if (has(o, "ice") or o.frozen_t > 0.0) and free:
				_shatter(tw, o)
			_put(o, "quake")


static func _steam(tw: Object, o: Orb) -> void:
	o.nat_cd = STATE_CD
	_drop(o, "wet")
	_drop(o, "heat")
	_put(o, "dry", 1.5)
	var r := 70.0
	for x in _near(o, r):
		x.slow(0.6, 1.2)
		_hurt(tw, x, 0.3, "nat:steam")
	_note(tw, "steam", o.position, Color(0.9, 0.92, 0.96), r)


static func _melt(tw: Object, o: Orb) -> void:
	o.nat_cd = STATE_CD
	_drop(o, "ice")
	_drop(o, "heat")
	o.chill = 0.0
	_put(o, "wet")
	o.stagger(10.0)
	_hurt(tw, o, 1.2, "nat:melt")
	_note(tw, "melt", o.position, Color(0.8, 0.9, 1.0))


static func _wildfire(tw: Object, o: Orb, wide := 1.0) -> void:
	o.nat_cd = STATE_CD
	var v := o.vine
	o.vine = 0.0
	_hurt(tw, o, 0.6 + 0.3 * minf(v, 3.0), "nat:wildfire")
	if is_instance_valid(tw):
		o.burn(Rules.fire_dps * 2.0, Rules.fire_t, tw, true, "nat:wildfire")
	for x in _near(o, 60.0 * wide):
		if x.vine >= 0.5 and not has(x, "wet"):
			x.vine = maxf(x.vine - 1.0, 0.0)
			if is_instance_valid(tw):
				x.burn(Rules.fire_dps * 1.5, Rules.fire_t, tw, true, "nat:wildfire")
			_put(x, "heat")
	_note(tw, "wildfire", o.position, Elem.COLORS[Elem.FIRE], 60.0 * wide)


static func _rust(tw: Object, o: Orb) -> void:
	o.vuln(3.0, 0.15, tw if is_instance_valid(tw) else null, true)
	_note(tw, "rust", o.position)


static func _shatter(tw: Object, o: Orb) -> void:
	o.nat_cd = STATE_CD
	_drop(o, "ice")
	o.frozen_t = 0.0
	o.chill = 0.0
	_hurt(tw, o, 2.0, "nat:shatter")
	for x in _near(o, 60.0):
		_hurt(tw, x, 0.5, "nat:shatter")
	_note(tw, "shatter", o.position, Color(0.85, 0.97, 1.0), 60.0)


## 전기가 이 구체에 닿을 때 (Tower.hit 전기 · 전달된 전기). 돌려주는 값: 번개가 평소처럼 튀어도 되는가
static func electric(tw: Object, o: Orb, dmg: float) -> bool:
	if not on() or not is_instance_valid(o) or o.hp <= 0.0:
		return true
	if has(o, "ground"):
		# 접지: 튀지 않고 땅으로 빠진다. 대신 둘레 무리가 기절
		if o.nat_cd <= 0.0:
			o.nat_cd = STATE_CD
			o.root(0.5)
			for x in _near(o, 70.0):
				x.root(0.4)
			_note(tw, "ground", o.position, Elem.COLORS[Elem.EARTH], 70.0)
		return false
	if wet_vine(o) and o.nat_cd <= 0.0:
		_circuit(tw, o, dmg)
		return true
	if dry_vine(o) and o.nat_cd <= 0.0:
		# 낙뢰목: 마른 덩굴은 전기가 통하지 않고 타 버린다
		o.nat_cd = STATE_CD
		o.vine = maxf(o.vine - 1.5, 0.0)
		if is_instance_valid(tw):
			o.burn(Rules.fire_dps * 1.5, Rules.fire_t, tw, true, "nat:lightning_tree")
		_put(o, "heat")
		_note(tw, "lightning_tree", o.position, Elem.COLORS[Elem.ELECTRIC])
		return false
	return true


## 덩굴 회로: 젖은 덩굴로 이어진 구체 모두에 한꺼번에
static func _circuit(tw: Object, o: Orb, dmg: float) -> void:
	o.nat_cd = STATE_CD
	var net: Array = [o]
	var i := 0
	while i < net.size() and net.size() < CIRCUIT_MAX:
		for x in _near(net[i], CIRCUIT_R):
			if not x in net and wet_vine(x):
				net.append(x)
				if net.size() >= CIRCUIT_MAX:
					break
		i += 1
	var main = o.main
	for j in range(1, net.size()):
		var x: Orb = net[j]
		_hurt_raw(tw, x, maxf(dmg, 0.5) * 0.8, "nat:circuit")
		x.stagger(6.0)
		if main and main.arcs.size() < 80:
			main.arcs.append([net[j - 1].position if j > 0 else o.position, x.position, 0.15])
	_note(tw, "circuit", o.position, Elem.COLORS[Elem.ELECTRIC])


## 전기 튀는 거리 배율 (젖음·도체)
static func arc_range(o: Orb) -> float:
	if not on() or not is_instance_valid(o):
		return 1.0
	return 1.4 if has(o, "wet") or has(o, "cond") else 1.0


# ───────────── 기질 ─────────────

## 오브젝트 tw가 구체 o를 맞힐 때 속성 e 기질 배율 [효과, 게이지]
static func quirk(tw: Object, o: Orb, e: int) -> Vector2:
	var n := _hits(tw, o)
	match e:
		Elem.FIRE:
			return Vector2(0.8 if n < 2 else 1.25, 1.0)
		Elem.WOOD:
			return Vector2(1.4 if o.vine >= 2.0 or o.root_timer > 0.0 else 0.9, 1.0)
		Elem.WATER:
			return Vector2(0.85, 1.0)
		Elem.ELECTRIC:
			return Vector2(minf(0.8 + 0.12 * n, 1.5), 2.0 if has(o, "wet") or has(o, "cond") else 1.0)
		Elem.WIND:
			var d: float = tw.position.distance_to(o.position) if is_instance_valid(tw) else 200.0
			return Vector2(lerpf(0.85, 1.3, clampf((d - 120.0) / 180.0, 0.0, 1.0)), 1.0)
		Elem.ICE:
			return Vector2(0.85, 1.0)
		Elem.EARTH:
			return Vector2(1.25, 0.7)
		Elem.DARK:
			return Vector2(0.8 if n < 1 else 1.2, 1.0)
		Elem.LIGHT:
			return Vector2(1.3 if o.hp > o.max_hp * 0.7 else 0.85, 1.0)
		Elem.POISON:
			return Vector2(0.8 if n < 3 else 1.35, 1.0)
		Elem.METAL:
			return Vector2(1.4 if o.kind == Orb.Kind.TANK or o.kind == Orb.Kind.BOSS or o.shield > 0.0 else 0.85, 1.0)
		Elem.SOUND:
			return Vector2(1.3 if _on_beat(tw, o) else 0.8, 1.3 if _on_beat(tw, o) else 1.0)
		Elem.TIME:
			return Vector2(1.2, 0.7)
		Elem.SOUL:
			return Vector2(1.5 if o.hp < o.max_hp * 0.3 else 0.85, 1.0)
		Elem.BLOOD:
			var still := o.root_timer > 0.0 or o.stagger_t > 0.0
			return Vector2(0.5 if still else 1.3 if o.speed * (o.slow_factor if o.slow_timer > 0.0 else 1.0) > 60.0 else 1.0, 1.0)
		Elem.ILLUSION:
			return Vector2(0.8, 1.3)
	return Vector2.ONE


## 기질 표: 속성마다 효과 배율. 자기 속성은 그대로, 같은 오브젝트의 다른 효과에는 (배율-1)의 절반 (기질×효과)
static func qmap(tw: Object, o: Orb, els: Dictionary) -> Dictionary:
	var out := {}
	if not on() or not is_instance_valid(tw) or not is_instance_valid(o):
		return out
	var own := {}
	for e in els:
		own[e] = quirk(tw, o, e).x
	for e in els:
		var v: float = own[e]
		for x in own:
			if x != e:
				v *= 1.0 + (own[x] - 1.0) * 0.5
		out[e] = clampf(v, 0.3, 2.5)
	return out


static func qm(q: Dictionary, e: int) -> float:
	return q.get(e, 1.0)


## 같은 오브젝트가 이 구체를 연달아 맞힌 횟수 (2초 넘게 안 맞히면 처음부터)
static func _hits(tw: Object, o: Orb) -> int:
	if not is_instance_valid(tw):
		return 0
	var r: Array = o.qh.get(tw.get_instance_id(), [])
	if r.is_empty() or o.age - r[1] > 2.0:
		return 0
	return r[0]


static func _on_beat(tw: Object, o: Orb) -> bool:
	if not is_instance_valid(tw):
		return false
	var r: Array = o.qh.get(tw.get_instance_id(), [])
	if r.size() < 3 or r[2] <= 0.0:
		return false
	var iv: float = o.age - r[1]
	return absf(iv - r[2]) < r[2] * 0.25


## 맞힌 뒤 횟수·간격을 센다 (Tower.hit 끝)
static func count_hit(tw: Object, o: Orb) -> void:
	if not on() or not is_instance_valid(tw):
		return
	var id := tw.get_instance_id()
	var r: Array = o.qh.get(id, [])
	if r.is_empty() or o.age - r[1] > 2.0:
		o.qh[id] = [1, o.age, 0.0]
	else:
		o.qh[id] = [r[0] + 1, o.age, o.age - r[1]]
	if o.qh.size() > 8:
		o.qh.erase(o.qh.keys()[0])


# ───────────── 문턱 ─────────────

## 속성 e 게이지를 채운다. f: 효과 세기(전달이면 작음), carried: 전달로 실린 것
static func fill(tw: Object, o: Orb, e: int, l: int, f: float, carried := false) -> void:
	if not on() or not BURST.has(e) or not is_instance_valid(o) or o.hp <= 0.0:
		return
	var g: float = FILL[e] * (1.0 + 0.25 * (l - 1)) * minf(f, 1.5) * quirk(tw, o, e).y * Rules.t("nat_gauge")
	if carried:
		g *= Rules.t("nat_gauge_carry")
	if e == Elem.WOOD:
		g *= 1.0 + minf(o.vine, 3.0) * 0.3
	_add_gauge(tw, o, e, g)


static func _add_gauge(tw: Object, o: Orb, e: int, g: float) -> void:
	if depth >= int(Rules.t("nat_chain_max")):
		return
	var v: float = minf(o.gauge.get(e, 0.0) + g, FULL)
	o.gauge[e] = v
	if is_instance_valid(tw):
		o.gauge_src[e] = tw
	if v >= FULL and o.burst_cd.get(e, 0.0) <= 0.0 and _ready(o, e):
		o.burst_cd[e] = BURST_CD
		o.gauge[e] = 0.0
		queue.append([o, e, o.gauge_src.get(e), depth])


## 터질 조건이 있는 문턱
static func _ready(o: Orb, e: int) -> bool:
	match e:
		Elem.ICE:
			return o.frozen_t > 0.0 or has(o, "ice")
		Elem.DARK:
			return o.hp < o.max_hp * (0.05 if o.kind == Orb.Kind.BOSS else 0.15)
		Elem.POISON:
			return o.poison_t > 0.0
	return true


## 매 프레임 (BinduCombat.step_entities 뒤): 큐에 든 문턱을 예산만큼 터뜨린다
static func tick(delta: float) -> void:
	_budget_t -= delta
	if _budget_t <= 0.0:
		_budget_t = 0.1
		_budget_n = 0
	while not queue.is_empty() and _budget_n < BUDGET:
		var q: Array = queue.pop_front()
		_budget_n += 1
		var o = q[0]
		var tw = q[2]
		if not is_instance_valid(o) or o.hp <= 0.0 or not is_instance_valid(tw):
			continue
		_burst(tw, o, q[1], q[3])


static func _burst(tw: Object, o: Orb, e: int, d: int) -> void:
	var b: Array = BURST[e]
	var fade := pow(Rules.t("nat_chain_fade"), d)
	var k := Rules.t("nat_burst") * fade
	var key: String = "burst:" + Patch.ELEM_KEYS[Elem.ALL.find(e)]
	var hit: Array = [o]
	var r: float = b[3]
	if r > 0.0:
		for x in _near(o, r):
			if e == Elem.WOOD and x.vine < 0.5:
				continue
			hit.append(x)
	match e:
		Elem.WATER:
			var back := o.position - o.target
			if back.length() > 1.0:
				o.knock(back.normalized() * 60.0)
		Elem.ELECTRIC:
			var n := 0
			for x in _near(o, 160.0):
				if n >= 4:
					break
				if has(x, "wet") or has(x, "cond") or wet_vine(x):
					hit.append(x)
					n += 1
					if o.main and o.main.arcs.size() < 80:
						o.main.arcs.append([o.position, x.position, 0.15])
		Elem.WIND:
			o.root(1.0, false)
		Elem.ICE:
			o.frozen_t = 0.0
			o.chill = 0.0
			_drop(o, "ice")
			for x in _near(o, 60.0):
				_hurt(tw, x, 0.8 * k, key)
		Elem.EARTH, Elem.LIGHT:
			for x in hit:
				x.root(0.6 if e == Elem.EARTH else 0.5)
		Elem.WOOD:
			for x in hit:
				x.root(0.4)
		Elem.DARK:
			_hurt_raw(tw, o, o.hp + o.shield + 1.0, key)
		Elem.POISON:
			var rest := o.poison_dps * o.poison_t
			o.poison_t = 0.0
			_hurt_raw(tw, o, rest * fade, key)
		Elem.METAL:
			for x in hit:
				if x != o:
					x.push((o.position - x.position).normalized() * 40.0)
		Elem.TIME:
			o.root(1.0, false)
		Elem.SOUL:
			o.confuse(1.5)
		Elem.BLOOD:
			o.gore_src = tw
			o.gore_t = maxf(o.gore_t, 4.0)
		Elem.ILLUSION:
			for x in hit:
				x.confuse(1.2)
	var dm: float = b[2]
	if dm > 0.0:
		if e == Elem.TIME:
			var oid := o.get_instance_id()
			tw.later.append([1.0, func():
				var oo = instance_from_id(oid)
				if oo != null and oo.hp > 0.0:
					_hurt(tw, oo, dm * k, key)])
		else:
			for x in hit:
				var m := 1.0 if x == o else 0.6
				if e == Elem.ELECTRIC and x != o:
					m = 0.4
				_hurt(tw, x, dm * k * m, key)
	# 문턱×효과: 그 오브젝트의 효과를 모두 100% · 문턱×문턱: 다른 게이지 +CHAIN_FILL (연쇄 단계 상한)
	var deeper := d + 1 < int(Rules.t("nat_chain_max"))
	depth = d + 1 if deeper else 99
	for x in hit:
		if not is_instance_valid(x) or x.hp <= 0.0:
			continue
		Share.apply(tw, x, 1.0 * fade, key)
		if deeper:
			for g in x.gauge.keys():
				if g != e:
					_add_gauge(x.gauge_src.get(g, tw), x, g, CHAIN_FILL * fade)
	depth = 0
	var col: Color = Elem.COLORS[e]
	_note(tw, "b%d" % e, o.position, col, maxf(r, 30.0), b[0] + ("" if d == 0 else " 연쇄 x%d" % (d + 1)))


# ───────────── 공용 ─────────────

static func _near(o: Orb, r: float) -> Array:
	var out: Array = []
	if o.main == null or o._combat_port == null:
		return out
	for x in o._combat_port.near(o.position, r + 20.0):
		if x != o and is_instance_valid(x) and x.hp > 0.0 and x.position.distance_to(o.position) < r + x.radius():
			out.append(x)
	return out


## 위력 배율 m만큼 피해 (오브젝트 위력 기준, 저항 반영)
static func _hurt(tw: Object, o: Orb, m: float, key: String) -> void:
	if not is_instance_valid(tw) or not is_instance_valid(o) or o.hp <= 0.0:
		return
	_hurt_raw(tw, o, Share.ref_dmg(tw) * m * o.resist_mul(Share._els(tw)), key)


static func _hurt_raw(tw: Object, o: Orb, amt: float, key: String) -> void:
	if not is_instance_valid(o) or o.hp <= 0.0 or amt <= 0.0:
		return
	var src = tw if is_instance_valid(tw) else null
	var d: float = o.hurt(amt, false, src)
	o.last_rx = true
	if src:
		src.credit(d, key)
		src.rx_dealt += d


## 화면 표시: 터진 자리 고리 + 이름 글자. 이번 판에 처음 본 것은 위쪽 알림 한 줄
static func _note(tw: Object, id: String, at: Vector2, col := Color.WHITE, r := 30.0, label := "") -> void:
	var main = tw.main if is_instance_valid(tw) else null
	if main == null:
		return
	var name: String = label if label != "" else PHENOMENA[id][0] if PHENOMENA.has(id) else id
	if main.pulses.size() < 40:
		main.pulses.append([at, r, 0.25])
	main.spawning_system.popup(at + Vector2(-12, -18), 0.0, col, false, name, 0.8)
	var sid := id if not id.begins_with("b") else id
	if not seen.has(sid):
		seen[sid] = true
		var desc: String = PHENOMENA[id][1] if PHENOMENA.has(id) else ""
		if desc == "" and id.begins_with("b"):
			var e := int(id.substr(1))
			desc = BURST[e][1]
		main.hud_system._show_toast("새 현상 · %s: %s" % [PHENOMENA[id][0] if PHENOMENA.has(id) else BURST[int(id.substr(1))][0], desc])


## Orb.step에서: 상태·게이지·쿨다운 줄이기
static func orb_step(o: Orb, delta: float) -> void:
	if o.nat_cd > 0.0:
		o.nat_cd = maxf(o.nat_cd - delta, 0.0)
	if not o.nat.is_empty():
		for s in o.nat.keys():
			var v: float = o.nat[s] - delta
			if v <= 0.0:
				o.nat.erase(s)
			else:
				o.nat[s] = v
	if not o.gauge.is_empty():
		for e in o.gauge.keys():
			var v: float = o.gauge[e] - DECAY * delta
			if v <= 0.0:
				o.gauge.erase(e)
			else:
				o.gauge[e] = v
	if not o.burst_cd.is_empty():
		for e in o.burst_cd.keys():
			o.burst_cd[e] -= delta
			if o.burst_cd[e] <= 0.0:
				o.burst_cd.erase(e)


## 구체 그림: 상태 점(위쪽 왼편부터) · 가장 찬 게이지 둘 (바깥 호, 90% 넘으면 밝게)
static func draw_orb(o: Orb, r: float) -> void:
	if not o.nat.is_empty():
		var i := 0
		for s in STATE_ORDER:
			if o.nat.has(s):
				var c: Color = STATES[s][1]
				o.draw_rect(Rect2(Vector2(-r - 2.0 + i * 6.0, r + 8.0), Vector2(4.5, 4.5)), c)
				i += 1
	if o.gauge.is_empty():
		return
	var es: Array = o.gauge.keys()
	es.sort_custom(func(a, b): return o.gauge[a] > o.gauge[b])
	for j in mini(es.size(), 2):
		var e: int = es[j]
		var v: float = o.gauge[e] / FULL
		if v < 0.15:
			continue
		var c: Color = Elem.COLORS[e]
		c.a = 1.0 if v >= 0.9 else 0.65
		var rr := r + 14.0 + j * 4.0
		o.draw_arc(Vector2.ZERO, rr, PI / 2, PI / 2 + TAU * v, 20, c, 2.0)


## 그림을 다시 그릴지 보는 서명 조각
static func sig(o: Orb) -> int:
	var s := 0
	var i := 0
	for st in STATE_ORDER:
		if o.nat.has(st):
			s |= 1 << i
		i += 1
	for e in o.gauge:
		s ^= (int(e) * 131 + int(o.gauge[e] / 10.0)) * 2654435761
	return s


## 도파민 모드 속성 순환: 이번에 쓸 속성들 (elements, order는 넣은 순서)
static func rotate(els: Dictionary, order: Array, t: float) -> Dictionary:
	var n := int(Rules.t("rot_n"))
	if not on() or Rules.version != 3 or els.size() <= n or n <= 0:
		return els.duplicate()
	var keys: Array = []
	for e in order:
		if els.has(e):
			keys.append(e)
	for e in els:
		if not e in keys:
			keys.append(e)
	var iv := maxf(Rules.t("rot_iv"), 0.1)
	var step := int(floorf(t / iv))
	var start := (step * n) % keys.size()
	var out := {}
	for i in n:
		var e = keys[(start + i) % keys.size()]
		out[e] = els[e]
	return out


## 17속성을 모두 가진 오브젝트: 한 바퀴 돌 때마다 대격변(맞힌 구체 게이지 전부 +20)
static func cataclysm(tw: Object, o: Orb) -> void:
	if not on() or Rules.version != 3 or tw.elements.size() < Elem.ALL.size():
		return
	var n := int(Rules.t("rot_n"))
	var lap := maxf(Rules.t("rot_iv"), 0.1) * ceilf(float(Elem.ALL.size()) / n)
	var cyc := int(floorf(tw.t / lap))
	if cyc == tw.cata_lap:
		return
	tw.cata_lap = cyc
	for e in BURST:
		_add_gauge(tw, o, e, 20.0)
	_note(tw, "cata", o.position, Color(1, 1, 1), 60.0, "대격변")


## 카드 자세히 줄: 기질·문턱·남기는 상태
static func card_lines(e: int) -> PackedStringArray:
	var out := PackedStringArray()
	if QUIRK.has(e):
		out.append("기질 · %s: %s" % [QUIRK[e][0], QUIRK[e][1]])
	if BURST.has(e):
		out.append("문턱 · %s: %s" % [BURST[e][0], BURST[e][1]])
	if LEAVES.has(e):
		out.append("남기는 상태 · %s" % STATES[LEAVES[e]][0])
	elif e == Elem.ICE:
		out.append("남기는 상태 · 젖은 구체를 얼음막으로")
	elif e == Elem.ELECTRIC:
		out.append("상태를 봐요 · 젖음·도체에서 멀리 튀고, 접지에선 빠지고, 마른 덩굴은 태우고, 젖은 덩굴은 회로가 돼요")
	return out
