class_name Tower
extends Node2D
## 설치형 오브젝트. 설치 시 정한 방향으로 공격한다.
## - 공격방식(pattern): 형태. 하나만 갖고, 새 오브젝트는 직선탄.
## - 속성(elements): 효과. 모든 공격에 부가효과가 붙는다. 종류 수 상한은 Rules.max_elems.
## - 강화(mods): 공격방식에 붙는 변형. 종류마다 Rules.max_mod개까지.
## - 연계: 연결선(links), 프리즘, 공명.

const RADIUS := 18.0

var elements := {}  # 속성 -> 겹친 수(=그 속성 레벨)
var order: Array[int] = []  # 넣은 순서
var pattern := Pat.DEFAULT
var plv := 1  # 공격방식 레벨
var mods := {}  # 강화 id -> 겹친 수
var links: Array = []  # 연결선으로 이어진 오브젝트
var prism := 0
var reso := 0
var eff := {}  # 연결선으로 나눠 받은 속성까지 합친 속성 (매 프레임 갱신)
var dir := Vector2.RIGHT
var aim := Vector2.RIGHT  # 유도 강화로 살짝 돈 실제 공격 방향
var cd := {}  # 공격별 쿨다운
var fx := {}  # 공격별 이펙트 남은 시간
var t := 0.0
var dealt := 0.0  # 이번(또는 지난) 웨이브에 준 피해
var rx_dealt := 0.0  # 그중 특수 반응 피해 (측정·표시용)
var run_dealt := 0.0  # 지난 웨이브들까지 합친 피해 (게임 오버 요약용)
var recoil := 0.0  # 발사 반동
var place_pop := 0.0  # 설치·겹치기 순간 커졌다 줄어드는 연출
var rocks: Array = []
var mines: Array = []
var in_rx := false  # 지금 특수 반응 공격 중인지 (hit 피해 계산용)
var rail_dir := Vector2.RIGHT  # 레일건이 마지막으로 쏜 방향
var halo_cd := {}  # 광륜: 구체별 다시 맞힐 때까지 남은 시간
var vine_cd := {}  # 덩굴: 구체별 다시 묶을 때까지 남은 시간
var zaps: Array = []  # 감전 물길: 이번에 전류가 꽂힌 자리(로컬)
var prison_c := Vector2.ZERO  # 빙결 감옥 중심(로컬)
var main: Node


func _ready() -> void:
	z_index = 1  # 공격 이펙트가 구체 위에 보이도록


func lv(e: int) -> int:
	return elements.get(e, 0)


func m(id: String) -> int:
	return mods.get(id, 0)


## 강화 효과량. 버전 3은 같은 강화를 쌓을수록 효과가 절반씩 준다 (1, 1.5, 1.75, ...).
func mf(id: String) -> float:
	var n := m(id)
	return 2.0 * (1.0 - pow(0.5, n)) if Rules.mod_decay else float(n)


## 개수로 쓰는 강화(다중·관통·튕김): 효과량의 소수 부분은 확률로 하나 더.
func mn(id: String) -> int:
	var f := mf(id)
	return int(f) + (1 if randf() < f - int(f) else 0)


func total_level() -> int:
	var n := 0
	for e in order:
		n += lv(e)
	return n


func reactions() -> Array:
	return Elem.reactions_with(eff if not eff.is_empty() else elements)


# 특성(전역 강화) 배율. 새 판마다 main이 초기화한다.
static var dmg_mul := 1.0
static var spd_mul := 1.0
static var reach_mul := 1.0
static var tax_step := 0.1


## 쌓기 대가: 속성 종류 하나 늘 때마다 공격 속도 감소 (기본 15%, 버전 3은 25%).
func tax() -> float:
	return 1.0 + tax_step * (order.size() - 1)


static func pw(l: int) -> float:
	return (1.0 + 0.5 * (l - 1)) * dmg_mul


static func spd(l: int) -> float:
	return 1.0 + 0.2 * (l - 1)


static func reach(l: int) -> float:
	return (1.0 + 0.1 * (l - 1)) * reach_mul


## 크기 강화 배율.
func sz() -> float:
	return 1.0 + 0.12 * mf("size")


## 속성이 많을수록, 공명·관통 강화로 피해가 늘어난다.
## rx: 특수 반응 공격은 겹친 레벨 합 보너스를 받지 않는다 (반응은 자기 레벨로 강해짐).
## 한 오브젝트에 몰아 넣으면 반응 수 x 레벨 합으로 곱이 되던 문제를 막는다.
func dmg_factor(rx := false) -> float:
	var f := 1.3 * (1.0 if rx else 1.0 + 0.35 * (total_level() - 1))
	# 무리: 설치된 오브젝트가 많을수록 모두 강해진다 (하나당 +3%, 버전 2는 +6%)
	if main:
		f *= 1.0 + Rules.crowd * (main.towers.get_child_count() - 1)
	if reso > 0 and main:
		var near := 0
		for o in main.towers.get_children():
			if o != self and o.position.distance_to(position) < 150.0:
				near += 1
		f *= 1.0 + 0.12 * reso * near
	if m("pierce") > 0 and not pattern in Pat.PROJECTILE:
		f *= 1.0 + 0.06 * mf("pierce")
	if m("bounce") > 0 and not pattern in Pat.PROJECTILE and pattern != "chain":
		f *= 1.0 + 0.04 * mf("bounce")
	if m("size") > 0 and pattern in Pat.PROJECTILE:
		f *= 1.0 + 0.04 * mf("size")
	# 온라인 밸런스 패치: 공격방식·넣은 속성별 피해 배율
	if not Patch.pat_mul.is_empty():
		f *= Patch.pat_mul.get(pattern, 1.0)
	if not Patch.elem_mul.is_empty():
		for e in elements:
			f *= Patch.elem_mul.get(e, 1.0)
	return f


## 대표 색: 속성 색을 레벨 비율로 섞는다.
func color() -> Color:
	if order.is_empty():
		return Color.WHITE
	var c := Color(0, 0, 0, 1)
	var tot := float(total_level())
	for e in order:
		var k := lv(e) / tot
		c.r += Elem.COLORS[e].r * k
		c.g += Elem.COLORS[e].g * k
		c.b += Elem.COLORS[e].b * k
	return c


## 속성을 겹친다. 결과 메시지를 돌려준다.
func add(e: int, n: int) -> String:
	var fresh := Elem.new_reactions(eff_now(), e)
	elements[e] = lv(e) + n
	if not order.has(e):
		order.append(e)
	place_pop = 1.0
	queue_redraw()
	if fresh.is_empty():
		return "%s Lv%d" % [Elem.NAMES[e], lv(e)]
	var names := PackedStringArray()
	for r in fresh:
		names.append(r["name"])
	return "반응: " + ", ".join(names)


## 이 카드를 넣을 수 있는지 (속성 종류·강화 종류별 상한, 공격방식 고정).
func can_take(card: Dictionary) -> bool:
	match card["type"]:
		"elem":
			return elements.has(card["e"]) or order.size() < Rules.max_elems
		"pat":
			return can_pattern(card["id"])
		"mod":
			return m(card["id"]) < Rules.max_mod
	return true


## 넣을 수 없는 이유 (넣을 수 있으면 빈 문자열).
func refuse_text(card: Dictionary) -> String:
	if can_take(card):
		return ""
	match card["type"]:
		"elem":
			return "속성은 %d종까지예요. 빈 곳에 새 오브젝트로 놓거나 연결선으로 나누세요" % Rules.max_elems
		"pat":
			return "이 오브젝트는 %s(으)로 정해져 있어요. 같은 공격방식만 넣을 수 있어요" % Pat.pname(pattern)
		"mod":
			return "%s은(는) %d개까지 쌓을 수 있어요" % [Pat.MODS[card["id"]]["name"], Rules.max_mod]
	return ""


## 이 공격방식을 넣을 수 있는지: 직선탄은 한 번 교체 가능, 정해진 뒤에는 같은 것(레벨업)만.
func can_pattern(id: String) -> bool:
	return pattern == Pat.DEFAULT or id == pattern


## 공격방식을 넣는다. 같은 것이면 레벨업, 직선탄이면 교체(이후 고정).
func set_pattern(id: String) -> String:
	if not can_pattern(id):
		return ""
	place_pop = 1.0
	cd.clear()
	fx.clear()
	queue_redraw()
	if id == pattern:
		plv += 1
		return "%s Lv%d" % [Pat.pname(id), plv]
	var old := pattern
	pattern = id
	plv = 1
	return "%s → %s" % [Pat.pname(old), Pat.pname(id)]


## 속성 대격변: 속성마다 무작위로 다시 뽑는다. 같은 속성이 나오면 레벨 +1.
func cataclysm_elements() -> void:
	var old := order.duplicate()
	var olds := elements.duplicate()
	elements.clear()
	order.clear()
	for e in old:
		var ne: int = Elem.ALL.pick_random()
		elements[ne] = lv(ne) + olds[e] + (1 if ne == e else 0)
		if not order.has(ne):
			order.append(ne)
	place_pop = 1.0
	queue_redraw()


## 공격방식 대격변: 직선탄을 뺀 공격방식 중 하나로 바뀐다(고정 무시). 레벨은 유지, 같은 것이면 +1.
func cataclysm_pattern() -> void:
	var id: String = Pat.PATTERN_IDS.slice(1).pick_random()
	if id == pattern:
		plv += 1
	else:
		pattern = id
	cd.clear()
	fx.clear()
	place_pop = 1.0
	queue_redraw()


func add_mod(id: String) -> String:
	mods[id] = m(id) + 1
	place_pop = 1.0
	queue_redraw()
	return "%s %d" % [Pat.MODS[id]["name"], m(id)]


func add_link(id: String, other: Tower = null) -> String:
	place_pop = 1.0
	queue_redraw()
	match id:
		"prism":
			prism += 1
		"reso":
			reso += 1
		"link":
			if other and not links.has(other):
				links.append(other)
				other.links.append(self)
				other.place_pop = 1.0
	return Pat.LINKS[id]["name"]


## 연결선이 지금 작동하는지: 옮겨서 거리(Rules.link_range)를 넘으면 끊긴 상태.
func link_on(o) -> bool:
	return is_instance_valid(o) and position.distance_to(o.position) <= Rules.link_range


## 연결된 오브젝트의 속성까지 합친 속성 (레벨은 큰 쪽).
func eff_now() -> Dictionary:
	var d := elements.duplicate()
	for o in links:
		if link_on(o):
			for e in o.elements:
				d[e] = maxi(d.get(e, 0), o.elements[e])
	return d


func title() -> String:
	var parts := PackedStringArray()
	for e in order:
		parts.append(Elem.NAMES[e] + ("" if lv(e) == 1 else str(lv(e))))
	return "%s%s · %s" % [Pat.pname(pattern), "" if plv == 1 else " Lv%d" % plv, "·".join(parts)]


## 강화·연계 요약 문구.
func extras_text() -> String:
	var parts := PackedStringArray()
	for id in Pat.MOD_IDS:
		if m(id) > 0:
			parts.append(Pat.MODS[id]["name"] + ("" if m(id) == 1 else " x%d" % m(id)))
	if prism > 0:
		parts.append("프리즘" + ("" if prism == 1 else " x%d" % prism))
	if reso > 0:
		parts.append("공명" + ("" if reso == 1 else " x%d" % reso))
	if not links.is_empty():
		parts.append("연결 %d" % links.size())
	return ", ".join(parts)


## 미리보기·사거리 표시에 쓰는 묶음.
func spec() -> Dictionary:
	return {"els": elements, "pat": pattern, "plv": plv, "mods": mods}


## 이어하기 저장용 (연결선은 main이 오브젝트 번호로 따로 저장).
func to_save() -> Dictionary:
	return {"elements": elements, "order": Array(order), "pattern": pattern, "plv": plv, "mods": mods,
		"prism": prism, "reso": reso, "pos": position, "dir": dir, "dealt": dealt, "run_dealt": run_dealt}


## 저장값으로 되살린다. 알 수 없는 속성·공격방식·강화나 형식이 다른 값은 버린다.
func load_save(d: Dictionary) -> void:
	var els: Variant = d.get("elements", {})
	var ord: Variant = d.get("order", [])
	if els is Dictionary and ord is Array:
		for e in ord:
			if e is int and e in Elem.ALL and els.get(e) is int and els[e] > 0 and not order.has(e):
				elements[e] = els[e]
				order.append(e)
	var p: Variant = d.get("pattern")
	if p is String and p in Pat.PATTERN_IDS:
		pattern = p
	plv = maxi(1, _int(d.get("plv")))
	var ms: Variant = d.get("mods", {})
	if ms is Dictionary:
		for id in ms:
			if Pat.MODS.has(id) and _int(ms[id]) > 0:
				mods[id] = _int(ms[id])
	prism = maxi(0, _int(d.get("prism")))
	reso = maxi(0, _int(d.get("reso")))
	var pos: Variant = d.get("pos")
	if pos is Vector2:
		position = pos
	var dv: Variant = d.get("dir")
	if dv is Vector2 and dv.length() > 0.01:
		dir = dv.normalized()
	aim = dir
	dealt = maxf(0.0, _float(d.get("dealt")))
	run_dealt = maxf(0.0, _float(d.get("run_dealt")))


static func _int(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


static func _float(v: Variant) -> float:
	return float(v) if v is int or v is float else 0.0


# ---------- 공격 ----------

func _ready_to(key, interval: float, delta: float) -> bool:
	var v: float = cd.get(key, 0.0) - delta
	if v <= 0.0:
		cd[key] = interval
		recoil = 1.0
		return true
	cd[key] = v
	return false


## 다중 발사 방향들 (가운데 기준 0.22라디안 간격).
func dirs() -> Array:
	var n := 1 + mn("multi")
	var out := []
	for i in n:
		out.append(aim.rotated((i - (n - 1) / 2.0) * 0.22))
	return out


## 다중 발사면 공격 하나당 피해 55%, 더 쌓을수록 한 발은 조금씩 약해진다 (1개 x1.1, 3개 x1.7).
func multi_k() -> float:
	return 1.0 if m("multi") == 0 else 0.55 / (1.0 + 0.15 * (mf("multi") - 1.0))


## main이 웨이브 중 매 계산마다 호출한다.
func attack(delta: float, orbs: Array) -> void:
	t += delta
	eff = eff_now()
	for k in fx.keys():
		fx[k] = maxf(fx[k] - delta, 0.0)
	recoil = maxf(recoil - delta * 6.0, 0.0)
	_update_aim(orbs, delta)
	# 속성을 많이 겹칠수록 공격이 느려진다(쌓기 대가), 속사 강화로 빨라진다
	var de := delta * spd_mul * (1.0 + 0.1 * mf("rapid")) / tax()
	var k := de * 3.0  # 지속 공격의 부가효과 세기
	var l := plv
	var s := sz()
	var mk := multi_k()
	match pattern:
		"shot", "thorn", "gust", "shard", "iron":
			var iv: float = {"shot": 0.5, "thorn": 0.35, "gust": 1.5, "shard": 0.9, "iron": 1.5}[pattern]
			if _ready_to("p", iv / spd(l), de):
				for d in dirs():
					var pr: Projectile = main.spawn_proj(self, pattern, l, d)
					pr.dmg *= mk  # 다중 발사: 한 발 피해 감소
		"spray":
			for d in dirs():
				_cone(orbs, d, 150.0 * reach(l) * s, 0.35, func(o): hit(o, 4.2 * pw(l) * de * mk, k))
		"stream":
			if _ready_to("p", 1.0 / spd(l), de):
				fx["stream"] = 0.6
			if fx.get("stream", 0.0) > 0.0:
				for d in dirs():
					_line(orbs, d, 260.0 * reach(l) * s, 10.0 * s, func(o):
						hit(o, 3.0 * pw(l) * de * mk, k)
						o.push(d * 60.0 * de))
		"chain":
			if cd.get("p", 0.0) > 0.0:
				cd["p"] -= de
			else:
				var fired := false
				var used := {}
				for d in dirs():
					fired = _chain(orbs, d, l, used) or fired
				if fired:
					cd["p"] = 1.3 / spd(l)
					recoil = 1.0
		"wall":
			rocks = rocks.filter(func(r): return is_instance_valid(r))
			if _ready_to("p", 4.0 / spd(l), de) and rocks.size() < 2 + roundi(mf("multi")):
				main.spawn_rock(self, l)
		"vortex":
			if _ready_to("p", 4.5 / spd(l), de):
				for d in dirs():
					main.spawn_proj(self, "dark", l, d)
		"laser":
			if _ready_to("p", 2.0 / spd(l), de):
				fx["laser"] = 0.3
				for d in dirs():
					_line(orbs, d, 2000.0, 14.0 * s, func(o): hit(o, 3.4 * pw(l) * mk))
		"lob":
			if _ready_to("p", 2.0 / spd(l), de):
				for d in dirs():
					main.spawn_proj(self, "blob", l, d)
	_reactions(orbs, de, k)
	# 연결선: 두 오브젝트 사이 레이저 (한쪽만 계산)
	for o in links:
		if link_on(o) and get_instance_id() < o.get_instance_id():
			for orb in orbs:
				var q := Geometry2D.get_closest_point_to_segment(orb.position, position, o.position)
				if q.distance_to(orb.position) < 8.0 + orb.radius():
					hit(orb, 2.0 * pw(1) * delta, delta * 3.0)
	queue_redraw()


## 특수 반응: 두 속성이 함께 있으면 공격방식과 별개로 추가 공격.
func _reactions(orbs: Array, de: float, k: float) -> void:
	in_rx = true
	_reactions_inner(orbs, de, k)
	in_rx = false


func _reactions_inner(orbs: Array, de: float, k: float) -> void:
	for key in halo_cd.keys():
		halo_cd[key] -= de
		if halo_cd[key] <= 0.0 or not is_instance_valid(key):
			halo_cd.erase(key)
	for key in vine_cd.keys():
		vine_cd[key] -= de
		if vine_cd[key] <= 0.0 or not is_instance_valid(key):
			vine_cd.erase(key)
	for r in reactions():
		var l := mini(eff.get(r["a"], 1), eff.get(r["b"], 1))
		var id: String = r["id"]
		match id:
			"burning":
				if _ready_to(id, 2.2 / spd(l), de):
					main.spawn_proj(self, "log", l, dir)
			"steam":
				# 물길 위로 증기: 띠 전체 감속·약화
				_band(orbs, position, dir, chan_len(l), chan_w(l), func(o):
					hit(o, 1.2 * pw(l) * de, k)
					o.slow(0.35, 0.3)
					o.vuln(0.5))
			"vine":
				# 물길 따라 자란 덩굴: 지나가는 구체를 묶는다 (같은 구체는 3초에 한 번)
				_band(orbs, position, dir, chan_len(l), chan_w(l), func(o):
					if not vine_cd.has(o):
						vine_cd[o] = 3.0
						hit(o, 2.0 * pw(l))
						o.root(1.2 + 0.25 * (l - 1)))
			"shock":
				# 공격 방향으로 흐르는 물길: 0.5초마다 안의 구체에 전류
				if _ready_to(id, 0.5, de):
					zaps.clear()
					fx[id] = 0.15
					_band(orbs, position, dir, chan_len(l), chan_w(l), func(o):
						hit(o, 0.9 * pw(l), 0.3)
						o.slow(0.6, 0.5)
						zaps.append(o.position - position))
			"firestorm":
				if _ready_to(id, 2.5 / spd(l), de):
					main.spawn_proj(self, "tornado", l, dir)
			"blizzard":
				for o in orbs:
					if o.position.distance_to(position) < 130.0 * reach(l):
						hit(o, 1.0 * pw(l) * de, k)
						o.slow(0.45, 0.3)
						o.add_chill(0.8 * de)
			"eclipse":
				if _ready_to(id, 6.0 / spd(l), de):
					fx[id] = 0.8
					main.eclipse_flash = 0.6
					for o in orbs:
						hit(o, 3.0 * pw(l))
						o.vuln(3.0)
			"lava":
				# 앞쪽에 가로로 서는 불타는 벽: 지나가면 크게 느려지고 탄다
				var w := wall_of(id, l)
				_band(orbs, w[0], w[1], w[2], 9.0, func(o):
					hit(o, 1.4 * pw(l) * de, k)
					o.slow(0.35, 0.3)
					o.burn(1.0 * l, 1.5, self, true))
			"mushroom":
				mines = mines.filter(func(mm): return is_instance_valid(mm))
				if _ready_to(id, 2.0 / spd(l), de) and mines.size() < 4 + l:
					main.spawn_proj(self, "mushroom", l, dir)
			"railgun":
				# 체력이 가장 많은 구체를 조준해 화면 끝까지 관통
				if not orbs.is_empty() and _ready_to(id, 3.5 / spd(l), de):
					var best: Orb = null
					for o in orbs:
						if best == null or o.hp > best.hp:
							best = o
					rail_dir = (best.position - position).normalized()
					fx[id] = 0.3
					_line(orbs, rail_dir, 2000.0, 12.0, func(o):
						hit(o, 6.0 * pw(l))
						o.push(rail_dir * 25.0))
			"halo":
				# 주위를 도는 빛 칼날: 닿으면 반드시 치명타 (같은 구체는 0.5초에 한 번)
				for bp in halo_blades(l):
					for o in main.near(position + bp, 14.0):
						if not halo_cd.has(o) and o.position.distance_to(position + bp) < 14.0 + o.radius():
							halo_cd[o] = 0.5
							hit(o, 1.0 * pw(l), 1.0, {}, true, true)
			"quake":
				if _ready_to(id, 3.5 / spd(l), de):
					fx[id] = 0.4
					for o in orbs:
						if o.position.distance_to(position) < 150.0 * reach(l) + o.radius():
							hit(o, 2.5 * pw(l))
							o.root(0.8)
			"storm":
				if _ready_to(id, 2.5 / spd(l), de):
					main.spawn_proj(self, "storm", l, dir)
			"aurora":
				if _ready_to(id, 2.5 / spd(l), de):
					fx[id] = 0.35
					var done := {}
					for i in 5:
						_line(orbs, dir.rotated((i - 2) * 0.22), 300.0 * reach(l), 8.0, func(o):
							if not done.has(o):
								done[o] = true
								hit(o, 2.2 * pw(l))
								o.add_chill(1.2))
			"swamp":
				# 가로로 깔리는 독 진흙: 크게 느려지고 중독 2배, 안에서 죽으면 독 폭발
				var w := wall_of(id, l)
				_band(orbs, w[0], w[1], w[2], 18.0, func(o):
					hit(o, 1.0 * pw(l) * de, k)
					o.slow(0.5, 0.3)
					o.poison(0.8 * l, 3.0, self, true)
					o.swamp_t = 0.3
					o.swamp_lv = l)
			"curse":
				# 표식 구체는 계속 피해를 받는다
				for o in orbs:
					if o.curse_owner == self:
						hit(o, 1.2 * pw(l) * de, k)
				# 가장 가까운 구체에 표식 (동시에 레벨 수만큼)
				if _ready_to(id, 2.0 / spd(l), de):
					var mine := 0
					var best: Orb = null
					var bd := 320.0 * reach(l)
					for o in orbs:
						if o.curse_lv > 0:
							if o.curse_owner == self:
								mine += 1
							continue
						var dd: float = o.position.distance_to(position)
						if dd < bd:
							bd = dd
							best = o
					if best and mine < l:
						best.curse_lv = l
						best.curse_owner = self
			"prison":
				if _ready_to(id, 7.0 / spd(l), de):
					fx[id] = 0.5
					prison_c = dir * 150.0 * reach(l)
					for o in orbs:
						if o.position.distance_to(position + prison_c) < 90.0 + 8.0 * (l - 1) + o.radius():
							hit(o, 2.0 * pw(l))
							o.root(1.5)
							o.prison_t = 1.5


## 물길: 공격 방향으로 흐르는 띠. 웨이브가 시작되면 물이 앞으로 흘러 나간다.
func chan_len(l: int) -> float:
	var full := 260.0 * reach(l)
	return minf(full, main.wave_time * 520.0) if main else full


func chan_w(l: int) -> float:
	return 20.0 + 3.0 * (l - 1)


## 가로 벽(용암·독늪): [시작점(전역), 방향, 길이]. 공격 방향과 수직으로 선다.
func wall_of(id: String, l: int) -> Array:
	var dist := (120.0 if id == "lava" else 170.0) * reach(l)
	var half := (70.0 if id == "lava" else 80.0) + 10.0 * (l - 1)
	var n := dir.orthogonal()
	return [position + dir * dist - n * half, n, half * 2.0]


## 광륜 칼날 위치(로컬). 레벨마다 하나씩 늘어난다(최대 6).
func halo_r(l: int) -> float:
	return 110.0 * reach(l)


func halo_blades(l: int) -> Array:
	var n := mini(1 + l, 6)
	var out := []
	for i in n:
		out.append(Vector2.from_angle(t * 2.4 + TAU * i / n) * halo_r(l))
	return out


## 유도 강화: 범위·광선 공격은 앞쪽 가장 가까운 구체 쪽으로 방향이 돈다(최대 0.1라디안씩).
func _update_aim(orbs: Array, delta: float) -> void:
	var n := mf("homing")
	if n == 0.0 or pattern in Pat.PROJECTILE:
		aim = dir
		return
	var limit := 0.1 * n
	var best: Orb = null
	var bd := 400.0
	for o in orbs:
		var v: Vector2 = o.position - position
		if v.length() < bd and absf(dir.angle_to(v)) < limit + 0.4:
			bd = v.length()
			best = o
	var want := dir
	if best:
		var a := clampf(dir.angle_to(best.position - position), -limit, limit)
		want = dir.rotated(a)
	aim = aim.slerp(want, minf(1.0, delta * 6.0)).normalized()


## 이 오브젝트의 공격이 구체에 닿았을 때. 겹친(나눠 받은) 모든 속성의 부가효과가 붙는다.
## k: 부가효과 세기 (한 방=1, 지속 공격=프레임 비례)
## extra: 프리즘에서 묻어 온 속성, can_split: 파편은 다시 분열하지 않는다
func hit(o: Orb, dmg: float, k := 1.0, extra := {}, can_split := true, force_crit := false) -> void:
	if not is_instance_valid(o) or o.hp <= 0.0:
		return
	var els: Dictionary = eff if not eff.is_empty() else elements
	if not extra.is_empty():
		els = els.duplicate()
		for e in extra:
			els[e] = maxi(els.get(e, 0), extra[e])
	var L := func(e: int) -> int: return els.get(e, 0)
	var d := dmg * dmg_factor(in_rx)
	var crit := false
	if force_crit or els.has(Elem.LIGHT) and randf() < minf(0.12 * L.call(Elem.LIGHT), 0.6) * minf(k, 1.0):
		d *= 2.0
		crit = k >= 1.0
	if els.has(Elem.WOOD):
		d *= 1.0 + 0.2 * L.call(Elem.WOOD)
	if els.has(Elem.METAL):
		d += 0.4 * L.call(Elem.METAL) * k
		o.push(dir * 4.0 * L.call(Elem.METAL) * k)
	var rm := o.resist_mul(els)
	d *= rm
	o.hurt(d, crit)
	dealt += d
	if in_rx:
		rx_dealt += d
	if els.has(Elem.FIRE):
		o.burn(0.8 * L.call(Elem.FIRE) * rm, 2.0, self)
	if els.has(Elem.POISON):
		o.poison(0.5 * L.call(Elem.POISON) * rm, 4.0, self)
	if els.has(Elem.ICE):
		o.add_chill(0.6 * k * L.call(Elem.ICE))
	if els.has(Elem.WATER):
		o.slow(0.8, 0.8)
	if els.has(Elem.WIND):
		# 중앙 반대쪽으로 밀어낸다
		o.push((o.position - o.target).normalized() * 7.0 * L.call(Elem.WIND) * k)
	if els.has(Elem.EARTH) and randf() < minf(0.2 * L.call(Elem.EARTH), 0.7) * k:
		o.root(0.8)
	if els.has(Elem.DARK):
		o.vuln(2.0)
	if els.has(Elem.ELECTRIC) and randf() < 0.3 * k:
		main.arc(o, d * 0.5 * L.call(Elem.ELECTRIC), self)
	if can_split and m("split") > 0 and randf() < minf(0.6, 0.12 * mf("split")) * minf(k, 1.0):
		for i in 2:
			var p: Projectile = main.spawn_proj(self, "frag", plv, Vector2.from_angle(randf() * TAU))
			p.dmg *= 0.5
			p.position = o.position
			p.hit[o] = true


## d 방향 부채꼴 안의 구체에 효과.
func _cone(orbs: Array, d: Vector2, rng: float, half: float, f: Callable) -> void:
	for o in orbs:
		var v: Vector2 = o.position - position
		if v.length() < rng + o.radius() and absf(d.angle_to(v)) < half:
			f.call(o)


## from에서 d 방향 띠(길이 length, 반폭 half_w) 안의 구체에 효과.
func _band(orbs: Array, from: Vector2, d: Vector2, length: float, half_w: float, f: Callable) -> void:
	for o in orbs:
		var v: Vector2 = o.position - from
		var along := v.dot(d)
		if along > -o.radius() and along < length + o.radius() and absf(v.cross(d)) < half_w + o.radius():
			f.call(o)


## d 방향 직선 위의 구체에 효과.
func _line(orbs: Array, d: Vector2, length: float, width: float, f: Callable) -> void:
	for o in orbs:
		var v: Vector2 = o.position - position
		var along := v.dot(d)
		if along > 0.0 and along < length and absf(v.cross(d)) < width + o.radius():
			f.call(o)


## d 방향 앞쪽의 가장 가까운 구체를 치고 주변으로 튄다. used: 다중 발사 때 같은 첫 대상 피하기
func _chain(orbs: Array, d: Vector2, l: int, used: Dictionary) -> bool:
	var first: Orb = null
	var best := 280.0 * reach(l) * sz()
	for o in orbs:
		var v: Vector2 = o.position - position
		if not used.has(o) and v.length() < best and absf(d.angle_to(v)) < 0.5:
			best = v.length()
			first = o
	if first == null:
		return false
	used[first] = true
	var pts := PackedVector2Array([position + d * RADIUS])
	var cur := first
	var hitset := {}
	for i in 3 + l + mn("bounce"):
		hitset[cur] = true
		pts.append(cur.position)
		hit(cur, 2.2 * pw(l) * multi_k())
		var nxt: Orb = null
		var nd := 110.0 * sz()
		for o in orbs:
			if not hitset.has(o) and o.position.distance_to(cur.position) < nd:
				nd = o.position.distance_to(cur.position)
				nxt = o
		if nxt == null:
			break
		cur = nxt
	# 번개는 구체·블랙홀에 가려지지 않게 맨 위 층(main)에 그린다
	main.bolt(pts)
	return true


# ---------- 그리기 ----------

func _draw() -> void:
	if main and main.wave_active:
		_draw_attack()
	_draw_body()


func _process(delta: float) -> void:
	if place_pop > 0.0:
		place_pop = maxf(place_pop - delta * 3.0, 0.0)
		queue_redraw()


func _draw_body() -> void:
	var s := 1.0 + 0.5 * place_pop
	draw_set_transform(-dir * recoil * 5.0, 0.0, Vector2(s, s))
	if place_pop > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 20.0 * (1.0 - place_pop), 0, TAU, 32, Color(1, 1, 1, place_pop), 3.0)
	if prism > 0:
		var hx := PackedVector2Array()
		for i in 7:
			hx.append(Vector2.from_angle(TAU * i / 6.0 + t) * (RADIUS + 6.0))
		draw_polyline(hx, Color(0.8, 0.95, 1.0, 0.8), 2.0)
	if reso > 0:
		var pulse := fmod(Time.get_ticks_msec() / 1000.0, 1.0)
		draw_arc(Vector2.ZERO, RADIUS + 4.0 + pulse * 14.0, 0, TAU, 32, Color(1, 0.85, 0.5, 0.6 * (1.0 - pulse)), 2.0)
	# 겹친 속성 비율대로 나눈 몸체 (모양은 메뉴에서 고른 스킨)
	var total := total_level()
	var skin := Meta.tower_skin
	var a0 := -PI / 2
	for e in order:
		var span := TAU * lv(e) / total
		var steps := maxi(2, int(span / 0.08))
		if skin == "ring":
			var pts := PackedVector2Array()
			for i in steps + 1:
				pts.append(Vector2.from_angle(a0 + span * i / steps) * RADIUS * 0.8)
			draw_polyline(pts, Elem.COLORS[e], RADIUS * 0.4)
		else:
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in steps + 1:
				var a := a0 + span * i / steps
				pts.append(Vector2.from_angle(a) * _skin_r(skin, a))
			draw_colored_polygon(pts, Elem.COLORS[e])
		a0 += span
	if skin == "gem":
		draw_line(Vector2(0, -RADIUS * 1.15), Vector2(0, RADIUS * 1.15), Color(1, 1, 1, 0.35), 1.5)
		draw_line(Vector2(-RADIUS * 0.85, 0), Vector2(RADIUS * 0.85, 0), Color(1, 1, 1, 0.35), 1.5)
	if not reactions().is_empty():
		draw_arc(Vector2.ZERO, RADIUS + 2.0, 0, TAU, 32, Color.WHITE, 2.0)
	# 겹친 속성 수만큼 주위를 도는 작은 점
	if order.size() > 1:
		var now := Time.get_ticks_msec() / 1000.0
		for i in order.size():
			var a := now * 1.2 + TAU * i / order.size()
			draw_circle(Vector2(cos(a), sin(a)) * (RADIUS + 7.0), 2.5, Elem.COLORS[order[i]])
	draw_set_transform(Vector2.ZERO)
	_draw_barrel()
	if Meta.symbols_on:
		# 포신에 가리지 않게 포신 위에 그린다
		draw_set_transform(-dir * recoil * 5.0, 0.0, Vector2(s, s))
		_draw_symbols(total, skin)
		draw_set_transform(Vector2.ZERO)
	if total > 1 and not (main and main.wave_active):  # 레벨 숫자는 쉬는 시간에만 (웨이브 중 글자 줄이기)
		draw_string(ThemeDB.fallback_font, Vector2(-6, -RADIUS - 6), str(total), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# 강화 개수: 아래쪽 작은 점
	var nm := 0
	for id in mods:
		nm += mods[id]
	for i in mini(nm, 8):
		draw_circle(Vector2(-(mini(nm, 8) - 1) * 3.0 + i * 6.0, RADIUS + 7.0), 2.0, Color(1, 0.85, 0.45))


## 속성 기호(설정): 몸체의 속성 칸마다 그 속성 이름 첫 글자. 하나뿐이면 가운데.
func _draw_symbols(total: int, skin: String) -> void:
	var font: Font = main.ui_font if main and main.ui_font else ThemeDB.fallback_font
	var fs := 12 if order.size() <= 3 else 9
	var rr := RADIUS * (0.8 if skin == "ring" else 0.55)
	var a0 := -PI / 2
	for e in order:
		var span := TAU * lv(e) / total
		var c := Vector2.ZERO if order.size() == 1 else Vector2.from_angle(a0 + span / 2.0) * rr
		Elem.draw_symbol(self, font, c, e, fs)
		a0 += span


## 스킨 외곽선: 각도 a에서 중심까지 거리.
static func _skin_r(skin: String, a: float) -> float:
	match skin:
		"hex":
			var k := PI / 6.0
			return RADIUS * cos(k) / cos(fposmod(a + PI / 2, 2 * k) - k) * 1.05
		"gem":
			var k := PI / 4.0
			return RADIUS * 1.15 * cos(k) / cos(fposmod(a + PI / 2, 2 * k) - k)
		"star":
			return RADIUS * (0.78 + 0.32 * cos(5.0 * (a + PI / 2)))
	return RADIUS


## 포신: 공격방식마다 모양이 다르다.
func _draw_barrel() -> void:
	var d := aim
	var n := d.orthogonal()
	var w := Color.WHITE
	var b := -d * recoil * 5.0
	match pattern:
		"spray":
			draw_colored_polygon(PackedVector2Array([b + d * RADIUS * 0.4, b + d * (RADIUS + 10) + n * 7, b + d * (RADIUS + 10) - n * 7]), w)
		"chain":
			draw_polyline(PackedVector2Array([b + d * 6, b + d * 12 + n * 4, b + d * 18 - n * 4, b + d * 26]), w, 2.5)
		"laser":
			draw_line(b + d * 4, b + d * (RADIUS + 16.0), w, 2.0)
			draw_circle(b + d * (RADIUS + 16.0), 2.5, w)
		"wall":
			draw_rect(Rect2(b + d * (RADIUS + 4) - Vector2(5, 5), Vector2(10, 10)), w)
		"vortex":
			draw_arc(b + d * (RADIUS + 6), 6.0, 0, TAU, 16, w, 2.5)
		"lob":
			draw_arc(b + d * (RADIUS + 2), 7.0, d.angle() - 1.2, d.angle() + 1.2, 12, w, 3.0)
		"iron":
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 8.0), w, 6.0)
		"stream":
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 12.0) + n * 3, w, 3.0)
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 12.0) - n * 3, w, 3.0)
		"gust":
			draw_arc(b + d * (RADIUS + 2), 8.0, d.angle() - 0.9, d.angle() + 0.9, 12, w, 3.0)
		"thorn":
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 12.0), w, 2.0)
			draw_line(b + d * RADIUS * 0.4 + n * 4, b + d * (RADIUS + 8.0) + n * 4, w, 2.0)
		_:
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 10.0), w, 3.0)
			if pattern == "shard":
				draw_circle(b + d * (RADIUS + 10.0), 3.0, Elem.COLORS[Elem.ICE])


func _draw_attack() -> void:
	var l := plv
	var s := sz()
	var c := color()
	match pattern:
		"spray":
			for d in dirs():
				_draw_puffs(d, 150.0 * reach(l) * s, 0.35, 34, 2.4, c.lightened(0.4), c, 3.0, 10.0)
		"stream":
			if fx.get("stream", 0.0) > 0.0:
				for d in dirs():
					_draw_wave(d, 260.0 * reach(l) * s, 5.0 * s, 0.05, c, 7.0 * s)
		"laser":
			var f: float = fx.get("laser", 0.0)
			for d in dirs():
				if f > 0.0:
					draw_line(d * RADIUS, d * 2000.0, Color(c, f / 0.3), (10.0 * f / 0.3 + 2.0) * s)
					draw_line(d * RADIUS, d * 2000.0, Color(1, 1, 1, f / 0.3), 3.0)
				else:
					var ch: float = 1.0 - cd.get("p", 0.0) / (2.0 / spd(l))
					draw_circle(d * (RADIUS + 4.0), 2.0 + 4.0 * ch, Color(c, 0.4 + 0.6 * ch))
	# 물이 들어간 반응은 같은 물길 하나 위에 겹쳐 그린다
	var rxs := reactions()
	var chan := 0.0
	var cw := 0.0
	for r in rxs:
		if r["id"] in ["steam", "vine", "shock"]:
			var rl0 := mini(eff.get(r["a"], 1), eff.get(r["b"], 1))
			chan = maxf(chan, chan_len(rl0))
			cw = maxf(cw, chan_w(rl0))
	if chan > 0.0:
		_draw_channel(chan, cw)
	for r in rxs:
		var rl := mini(eff.get(r["a"], 1), eff.get(r["b"], 1))
		var n := dir.orthogonal()
		match r["id"]:
			"steam":
				var L := chan_len(rl)
				for i in 12:
					var f := fmod(t * 0.6 + i * 0.13, 1.0)
					var p := dir * L * fmod(i * 0.37 + 0.05, 1.0) + n * sin(i * 1.7) * chan_w(rl) * 0.6 + Vector2(0, -f * 18.0)
					draw_circle(p, 5.0 + f * 10.0, Color(1, 1, 1, 0.28 * (1.0 - f)))
			"vine":
				var L := chan_len(rl)
				for side in [-1.0, 1.0]:
					var pts := PackedVector2Array()
					var steps := maxi(int(L / 12.0), 2)
					for i in steps + 1:
						var x := L * i / steps
						pts.append(dir * x + n * (side * chan_w(rl) * 0.85 + sin(x * 0.06 + t * 2.0 + side) * 4.0))
					draw_polyline(pts, r["color"], 3.0)
					for i in range(1, steps, 3):
						draw_circle(pts[i] + n * side * 4.0, 3.0, r["color"].lightened(0.25))
			"shock":
				var L := chan_len(rl)
				var w := chan_w(rl)
				for i in 4:
					var p0 := dir * randf() * L + n * randf_range(-w, w) * 0.8
					draw_line(p0, p0 + Vector2(randf_range(-14, 14), randf_range(-14, 14)), Color(Elem.COLORS[Elem.ELECTRIC], 0.9), 2.0)
				if fx.get("shock", 0.0) > 0.0:
					for zp in zaps:
						var p0: Vector2 = dir * clampf(zp.dot(dir), 0.0, L)
						var pts := PackedVector2Array([p0])
						for s2 in 3:
							pts.append(p0.lerp(zp, (s2 + 1) / 4.0) + Vector2(randf_range(-5, 5), randf_range(-5, 5)))
						pts.append(zp)
						draw_polyline(pts, Elem.COLORS[Elem.ELECTRIC], 2.5)
			"lava", "swamp":
				var wl := wall_of(r["id"], rl)
				var a: Vector2 = wl[0] - position
				var b: Vector2 = a + wl[1] * wl[2]
				var hw := 9.0 if r["id"] == "lava" else 18.0
				var dn := dir * hw
				draw_colored_polygon(PackedVector2Array([a - dn, b - dn, b + dn, a + dn]), Color(r["color"], 0.55 if r["id"] == "lava" else 0.35))
				if r["id"] == "lava":
					draw_line(a, b, Color(1, 0.75, 0.2, 0.6 + 0.3 * sin(t * 5.0)), 4.0)
					for i in 8:
						var f := fmod(t * 0.9 + i * 0.29, 1.0)
						draw_circle(a.lerp(b, fmod(i * 0.41, 1.0)) + Vector2(0, -f * 16.0), 2.5 * (1.0 - f) + 0.5, Color(1, 0.6, 0.15, 1.0 - f))
				else:
					for i in 7:
						var f := fmod(t * 0.7 + i * 0.37, 1.0)
						draw_arc(a.lerp(b, fmod(i * 0.53, 1.0)) + dir * sin(i * 2.3) * hw * 0.5, 2.0 + f * 6.0, 0, TAU, 10, Color(0.7, 0.95, 0.25, 1.0 - f), 1.5)
			"railgun":
				var f: float = fx.get("railgun", 0.0)
				if f > 0.0:
					draw_line(rail_dir * RADIUS, rail_dir * 2000.0, Color(r["color"], f / 0.3), 10.0 * f / 0.3 + 2.0)
					draw_line(rail_dir * RADIUS, rail_dir * 2000.0, Color(1, 1, 1, f / 0.3), 2.5)
			"halo":
				draw_arc(Vector2.ZERO, halo_r(rl), 0, TAU, 48, Color(r["color"], 0.12), 2.0)
				for bp in halo_blades(rl):
					var tg: Vector2 = bp.normalized().orthogonal() * 12.0
					var rd: Vector2 = bp.normalized() * 5.0
					draw_colored_polygon(PackedVector2Array([bp + tg, bp + rd, bp - tg, bp - rd]), r["color"])
					draw_circle(bp, 3.0, Color.WHITE)
			"quake":
				var f: float = fx.get("quake", 0.0)
				if f > 0.0:
					var k2 := 1.0 - f / 0.4
					var rad := 150.0 * reach(rl) * (0.3 + 0.7 * k2)
					draw_arc(Vector2.ZERO, rad, 0, TAU, 48, Color(r["color"], 1.0 - k2), 6.0 * (1.0 - k2) + 1.5)
					for i in 8:
						var d2 := Vector2.from_angle(TAU * i / 8 + 0.3)
						draw_line(d2 * RADIUS, d2 * rad + d2.orthogonal() * 8.0 * sin(i * 3.1), Color(0.35, 0.25, 0.15, 1.0 - k2), 3.0)
			"aurora":
				var f: float = fx.get("aurora", 0.0)
				if f > 0.0:
					var cols := [Color(0.4, 1.0, 0.6), Color(0.4, 0.9, 1.0), Color(0.7, 0.6, 1.0), Color(0.4, 0.9, 1.0), Color(0.4, 1.0, 0.6)]
					for i in 5:
						var d2 := dir.rotated((i - 2) * 0.22)
						draw_line(d2 * RADIUS, d2 * 300.0 * reach(rl), Color(cols[i], f / 0.35 * 0.8), 6.0 * f / 0.35 + 1.5)
			"prison":
				var f: float = fx.get("prison", 0.0)
				if f > 0.0:
					var rad := 90.0 + 8.0 * (rl - 1)
					draw_circle(prison_c, rad, Color(r["color"], 0.25 * f / 0.5))
					for i in 10:
						var d2 := Vector2.from_angle(TAU * i / 10)
						draw_line(prison_c + d2 * rad * 0.6, prison_c + d2 * rad, Color(0.8, 0.85, 1.0, f / 0.5), 3.0)
			"blizzard":
				var rad := 130.0 * reach(rl)
				draw_circle(Vector2.ZERO, rad, Color(r["color"], 0.08))
				for i in 24:
					var a := t * 1.5 + i * 0.7
					var rr := rad * fmod(i * 0.41 + t * 0.2, 1.0)
					draw_circle(Vector2(cos(a), sin(a)) * rr, 2.0, Color(1, 1, 1, 0.8))
			"eclipse":
				var f: float = fx.get("eclipse", 0.0)
				if f > 0.0:
					var k := 1.0 - f / 0.8
					draw_arc(Vector2.ZERO, 40.0 + k * 1400.0, 0, TAU, 96, Color(r["color"], 1.0 - k), 12.0 * (1.0 - k) + 2.0)
					draw_circle(Vector2.ZERO, RADIUS + 10.0, Color(0, 0, 0, 0.8 * (1.0 - k)))


## 물길 바닥: 공격 방향으로 흐르는 물.
func _draw_channel(L: float, w: float) -> void:
	var n := dir.orthogonal() * w
	var a := dir * RADIUS * 0.6
	var b := dir * L
	var wc: Color = Elem.COLORS[Elem.WATER]
	draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(wc, 0.22))
	draw_line(a + n, b + n, Color(wc, 0.6), 2.0)
	draw_line(a - n, b - n, Color(wc, 0.6), 2.0)
	# 흐르는 물결
	for i in 9:
		var f := fmod(t * 0.9 + i / 9.0, 1.0)
		var p := a.lerp(b, f)
		draw_line(p + n * 0.7 + dir * 6.0, p - n * 0.7 + dir * 6.0, Color(0.75, 0.9, 1.0, 0.45 * (1.0 - f)), 2.0)
	draw_arc(b, w, dir.angle() - PI / 2, dir.angle() + PI / 2, 12, Color(0.75, 0.9, 1.0, 0.7), 2.5)


## 부채꼴로 퍼져 나가는 입자(분사·증기).
func _draw_puffs(d: Vector2, rng: float, half: float, n: int, speed: float, c0: Color, c1: Color, r0: float, r1: float) -> void:
	var fan := PackedVector2Array([d * RADIUS * 0.8])
	for k in 9:
		fan.append(d.rotated(lerpf(-half, half, k / 8.0)) * rng)
	draw_colored_polygon(fan, Color(c1, 0.12))
	for i in n:
		var cyc := t * speed + float(i) / n
		var f := fmod(cyc, 1.0)
		var spread := _hash(floorf(cyc) * 7.0 + i) * half * (0.35 + 0.65 * f)
		var p := d.rotated(spread) * (RADIUS + f * (rng - RADIUS))
		draw_circle(p, lerpf(r0, r1, f), Color(c0.lerp(c1, f), 0.9 * (1.0 - f * 0.7)))


## 발사 방향으로 뻗은 물결선(물줄기·덩굴).
func _draw_wave(d: Vector2, length: float, amp: float, freq: float, c: Color, width: float) -> void:
	if length < 2.0:
		return
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var dd := length * i / n
		var off := sin(dd * freq * TAU - t * 14.0) * amp
		pts.append(d * (RADIUS + dd) + d.orthogonal() * off)
	draw_polyline(pts, c, width)
	draw_polyline(pts, Color(1, 1, 1, 0.5), width * 0.35)


## -1~1 의사 난수.
static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0


# ---------- 사거리 미리보기 ----------

## 공격 범위를 ci(전역 좌표 캔버스)에 그린다. 설치·겹치기 전 미리보기와 툴팁용.
## sp: spec() 묶음 {"els", "pat", "plv", "mods"}
## focus: 바뀌는 부분(-2: 공격방식, 0 이상: 그 속성의 반응)만 진하게, 나머지는 옅게
static func draw_range(ci: CanvasItem, o: Vector2, d: Vector2, sp: Dictionary, focus := -1) -> void:
	# 방향을 고를 때 마우스가 설치 지점과 겹치면 방향이 0이 되어 다각형이 깨진다
	if not o.is_finite():
		return
	d = d.normalized() if d.is_finite() and d.length_squared() > 0.0001 else Vector2.RIGHT
	var far := 1600.0
	var els: Dictionary = sp["els"]
	var l: int = sp["plv"]
	var md: Dictionary = sp["mods"]
	var s: float = 1.0 + 0.12 * md.get("size", 0)
	var n: int = 1 + md.get("multi", 0)
	var c := Pat.pcolor(sp["pat"])
	if not els.is_empty():
		c = Elem.COLORS[els.keys()[0]]
	if focus >= 0:
		c.a = 0.35
	for i in n:
		var dd := d.rotated((i - (n - 1) / 2.0) * 0.22)
		match sp["pat"]:
			"spray":
				_r_cone(ci, o, dd, 150.0 * reach(l) * s, 0.35, c)
			"chain":
				_r_cone(ci, o, dd, 280.0 * reach(l) * s, 0.5, c)
			"stream":
				_r_band(ci, o, dd, 0.0, 260.0 * reach(l) * s, 10.0 * s, c)
			"gust":
				_r_band(ci, o, dd, 0.0, 420.0 * s, 34.0 * s, c)
			"laser":
				_r_band(ci, o, dd, 0.0, far, 14.0 * s, c)
			"wall":
				if i == 0:
					var inner := ci.get_viewport_rect().grow(-100.0)  # main.spawn_rock처럼 가장자리 안쪽
					for k in 2 + md.get("multi", 0):
						_r_circle(ci, (o + d * (90.0 + 60.0 * k) * reach(l)).clamp(inner.position, inner.end), 28.0 * s, c)
			"vortex":
				_r_circle(ci, o + dd * 170.0 * reach(l), (90.0 + 10.0 * (l - 1)) * s, c)
			"lob":
				_r_circle(ci, o + dd * 180.0 * reach(l), (50.0 + 8.0 * (l - 1)) * s, c)
			"iron":
				_r_band(ci, o, dd, 0.0, far, 12.0 * s, c)
			_:
				_r_band(ci, o, dd, 0.0, far, 6.0 * s, c)
	for r in Elem.reactions_with(els):
		var rl: int = mini(els[r["a"]], els[r["b"]])
		var rc: Color = r["color"]
		if focus != -1 and r["a"] != focus and r["b"] != focus:
			rc.a = 0.35
		match r["id"]:
			"burning":
				_r_circle(ci, o + d * 180.0 * reach(rl), 50.0 + 8.0 * (rl - 1), rc)
			"steam", "vine", "shock":
				_r_band(ci, o, d, 0.0, 260.0 * reach(rl), 20.0 + 3.0 * (rl - 1), rc)
			"firestorm":
				_r_band(ci, o, d, 0.0, 380.0, 26.0, rc)
			"blizzard":
				_r_circle(ci, o, 130.0 * reach(rl), rc)
			"lava":
				_r_wall(ci, o + d * 120.0 * reach(rl), d, 70.0 + 10.0 * (rl - 1), 9.0, rc)
			"swamp":
				_r_wall(ci, o + d * 170.0 * reach(rl), d, 80.0 + 10.0 * (rl - 1), 18.0, rc)
			"railgun":
				_r_circle(ci, o, RADIUS + 14.0, rc)
			"halo":
				ci.draw_arc(o, 110.0 * reach(rl), 0, TAU, 48, Color(rc.r, rc.g, rc.b, 0.3 * rc.a), 26.0)
			"quake":
				_r_circle(ci, o, 150.0 * reach(rl), rc)
			"storm":
				_r_band(ci, o, d, 0.0, 360.0 * reach(rl), 100.0, rc)
			"aurora":
				_r_cone(ci, o, d, 300.0 * reach(rl), 0.5, rc)
			"curse":
				ci.draw_arc(o, 320.0 * reach(rl), 0, TAU, 64, Color(rc.r, rc.g, rc.b, 0.5 * rc.a), 1.5)
			"prison":
				_r_circle(ci, o + d * 150.0 * reach(rl), 90.0 + 8.0 * (rl - 1), rc)
			"mushroom":
				_r_band(ci, o, d, 80.0, 240.0, 14.0, rc)
			"eclipse":
				ci.draw_rect(ci.get_viewport_rect(), Color(rc.r, rc.g, rc.b, 0.05 * rc.a))


static func _r_cone(ci: CanvasItem, o: Vector2, d: Vector2, rng: float, half: float, c: Color) -> void:
	var pts := PackedVector2Array([o])
	for k in 13:
		pts.append(o + d.rotated(lerpf(-half, half, k / 12.0)) * rng)
	ci.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.14 * c.a))
	pts.append(o)
	ci.draw_polyline(pts, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)


static func _r_band(ci: CanvasItem, o: Vector2, d: Vector2, from: float, to: float, half_w: float, c: Color) -> void:
	var n := d.orthogonal() * half_w
	var a := o + d * maxf(from, RADIUS)
	var b := o + d * to
	var pts := PackedVector2Array([a + n, b + n, b - n, a - n])
	ci.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.14 * c.a))
	pts.append(a + n)
	ci.draw_polyline(pts, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)


## 가로 벽 미리보기: 중심 c, 공격 방향 d와 수직으로 반길이 half, 두께 반 hw.
static func _r_wall(ci: CanvasItem, c: Vector2, d: Vector2, half: float, hw: float, col: Color) -> void:
	var n := d.orthogonal() * half
	var t2 := d * hw
	var pts := PackedVector2Array([c - n - t2, c + n - t2, c + n + t2, c - n + t2])
	ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.14 * col.a))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(col.r, col.g, col.b, 0.6 * col.a), 1.5)


static func _r_circle(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	ci.draw_circle(p, r, Color(c.r, c.g, c.b, 0.14 * c.a))
	ci.draw_arc(p, r, 0, TAU, 40, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)


## 선택지 하나를 이 오브젝트에 넣었을 때 바뀌는 점(미리보기 문구)과, 넣은 뒤의 spec.
## card: {"type": "elem"|"pat"|"mod"|"link", ...}
func preview(card: Dictionary) -> Array:
	var out := PackedStringArray()
	var sp := spec().duplicate(true)
	if card["type"] in ["elem", "mod"] and not can_take(card):
		out.append("넣을 수 없음")
		out.append(refuse_text(card))
		return [out, sp]
	match card["type"]:
		"elem":
			var e: int = card["e"]
			var n: int = card["lv"]
			sp["els"][e] = lv(e) + n
			if elements.has(e):
				out.append("%s Lv%d → Lv%d (부가효과 강화)" % [Elem.NAMES[e], lv(e), lv(e) + n])
			else:
				out.append("%s + %s" % [title(), Elem.NAMES[e]])
				out.append("모든 공격에 부가효과: " + Elem.RIDER[e])
				var before := roundi((1.0 - 1.0 / tax()) * 100.0)
				var after := roundi((1.0 - 1.0 / (tax() + tax_step)) * 100.0)
				out.append("쌓기 대가: 공격 속도 -%d%% → -%d%%" % [before, after])
			out.append("피해 x%.1f → x%.1f" % [dmg_factor(), dmg_factor() + 1.3 * 0.35 * n])
		"pat":
			var id: String = card["id"]
			if not can_pattern(id):
				out.append("넣을 수 없음: 공격방식이 %s(으)로 정해져 있음" % Pat.pname(pattern))
				out.append("같은 공격방식만 넣어 레벨업할 수 있어요")
			elif id == pattern:
				sp["plv"] = plv + 1
				out.append("%s Lv%d → Lv%d" % [Pat.pname(id), plv, plv + 1])
				out.append("피해 x%.1f → x%.1f   공격 속도 x%.1f → x%.1f   사거리 x%.1f → x%.1f" % [pw(plv), pw(plv + 1), spd(plv), spd(plv + 1), reach(plv), reach(plv + 1)])
			else:
				sp["pat"] = id
				sp["plv"] = 1
				out.append("공격방식: %s → %s" % [Pat.pname(pattern), Pat.pname(id)])
				out.append(Pat.PATTERNS[id]["desc"])
				out.append("한 번 정하면 바꿀 수 없음 (같은 것을 넣으면 레벨업)")
		"mod":
			var id: String = card["id"]
			sp["mods"][id] = m(id) + 1
			out.append("%s %d → %d" % [Pat.MODS[id]["name"], m(id), m(id) + 1] + (" (최대 %d)" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "") + ("  효과 x%.2f → x%.2f" % [mf(id), 2.0 * (1.0 - pow(0.5, m(id) + 1))] if Rules.mod_decay else ""))
			out.append(Pat.MODS[id]["desc"])
		"link":
			var id: String = card["id"]
			out.append(Pat.LINKS[id]["name"])
			out.append(Pat.LINKS[id]["desc"])
	return [out, sp]
