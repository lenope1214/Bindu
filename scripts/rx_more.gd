class_name RxMore
## 2026-10-30에 채운 특수 반응 65개 (속성 14개의 두 속성 조합 91개 중 비어 있던 칸).
## 모양 규칙: 물=앞으로 흘러가는 물결(지나간 자리에 물길), 땅=앞으로 뻗는 균열(지나간 자리에 띠), 바람=앞으로 떠감,
## 빛=즉시 광선, 소리=부채꼴 파동, 시간=잠시 뒤 한 번 더, 영혼=혼불. 오브젝트에서 고정된 거리에 생기는 장판은 쓰지 않는다.
## 독·바람·얼음·땅이 들어간 반응은 0.5.1 통계에서 약한 속성을 살리려고 위력을 약 20% 높게 잡았다.
## 동작은 Tower._reactions_inner가 tick을, Projectile·Zone·Orb·main이 아래 훅을 부른다.

## 반응 id → 마지막 쿨다운(초, 공속으로 줄어듦). 지속형(진자)은 0.
const IV := {
	"miasma": 2.5, "sandstorm": 2.5, "seedwind": 2.5, "tidal": 3.0, "vacuum": 3.0, "feather": 2.5,
	"bladewind": 3.0, "whistle": 2.5, "galeback": 3.0, "wraith": 3.0,
	"thermal": 3.0, "frostthorn": 2.0, "glacier": 2.5, "frostbolt": 2.5, "icecrack": 2.5, "coldneedle": 2.0,
	"icelance": 3.0, "frostecho": 3.0, "frostsoul": 2.5,
	"thornvine": 2.5, "mud": 2.5, "ground": 2.5, "shadowcrack": 2.5, "crystal": 2.5, "rumble": 2.5, "tomb": 2.5,
	"smog": 3.0, "foulwater": 2.5, "neurotoxin": 2.0, "corrosive": 3.0, "rust": 2.0, "toxecho": 2.5, "latent": 2.5,
	"plasma": 2.5, "blackfire": 2.5, "solar": 3.0, "hotiron": 3.0, "blast": 3.0, "embers": 3.0, "foxfire": 2.5,
	"conduct": 3.0, "rotroot": 3.0, "photo": 3.0, "saw": 2.5, "drum": 3.0, "rings": 3.0,
	"blackwater": 2.5, "rainbow": 2.5, "mercury": 2.5, "ripple": 2.5, "backflow": 3.0,
	"darkbolt": 2.5, "flash": 3.0, "resonate": 2.5, "soulbolt": 2.5,
	"scythe": 3.0, "dusk": 2.5, "phantom": 2.5, "clarion": 2.5, "angel": 2.5,
	"pendulum": 0.0, "sword": 3.0, "reverb": 3.0, "requiem": 3.0, "samsara": 2.5,
}

## 혼불(ghost)로 나가는 반응: Projectile._on_hit이 ghost_hit으로 넘긴다.
const GHOSTS := ["frostsoul", "foxfire", "soulbolt", "phantom", "angel", "sword", "samsara", "samsara2"]

## 물결(지나간 자리 물길)·균열(지나간 자리 띠) 반응
const WAVES := ["tidal", "glacier", "mud", "foulwater", "blackwater", "rainbow", "mercury", "ripple", "backflow"]
const CRACKS := ["icecrack", "thornvine", "ground", "shadowcrack", "crystal", "rumble", "tomb"]
const WAVE_RANGE := 300.0
const CRACK_RANGE := 280.0
const STRIP_LIFE := 2.0


## 새 반응 위력 단위: Tower.pw × Rules.rx_mul (봇 32판에서 반응 65개를 다 채우자 판이 크게 쉬워져 한꺼번에 낮춘다)
static func pwx(l: int) -> float:
	return Tower.pw(l) * Rules.rx_mul


static func color(id: String) -> Color:
	for r in Elem.REACTIONS:
		if r["id"] == id:
			return r["color"]
	return Color.WHITE


# ---------- 매 프레임 (Tower._reactions_inner) ----------

## 오브젝트마다 한 번: 미뤄 둔 효과·표시 시간을 줄인다.
static func pre(t: Tower, de: float) -> void:
	if not t.later.is_empty():
		var keep := []
		var due := []
		for q in t.later:
			q[0] -= de
			if q[0] <= 0.0:
				due.append(q[1])
			else:
				keep.append(q)
		t.later = keep
		for f in due:
			f.call()
	if not t.rxfx.is_empty():
		for f in t.rxfx:
			f["t"] -= de
		t.rxfx = t.rxfx.filter(func(f): return f["t"] > 0.0)
	t.photo_t = maxf(t.photo_t - de, 0.0)


static func tick(t: Tower, id: String, l: int, orbs: Array, de: float, k: float) -> void:
	var p := pwx(l)
	var R := Tower.reach(l)
	var d := t.dir
	if id == "pendulum":
		_pendulum(t, l, orbs, de)
		return
	if id == "conduct":
		_conduct_tick(t, l, de)
	if not IV.has(id) or not t._ready_to(id, IV[id] / Tower.spd(l), de):
		return
	var c := color(id)
	match id:
		# --- 바람: 앞으로 떠감 ---
		"miasma":
			var pr := shoot(t, id, l, d, "cloud", 150.0, 450.0 * R, 30.0, true)
			pr.rxd["grow"] = 70.0
		"sandstorm":
			shoot(t, id, l, d, "sand", 140.0, 420.0 * R, 40.0, true, true)
		"seedwind":
			shoot(t, id, l, d, "seeds", 220.0, 380.0 * R, 30.0, true)
		"tidal":
			wave(t, id, l, d, "tide", 260.0, 320.0 * R, 60.0)
		"vacuum":
			shoot(t, id, l, d, "vacuum", 120.0, 360.0 * R, 45.0, true, true)
		"feather":
			for i in 6:
				shoot(t, id, l, d.rotated(lerpf(-0.5, 0.5, i / 5.0)), "feather", 380.0, 320.0 * R, 6.0, false)
		"bladewind":
			for a in [-0.25, 0.0, 0.25]:
				var pr := shoot(t, id, l, d.rotated(a), "blade", 320.0, 600.0 * R, 10.0, true)
				pr.rxd["back"] = 300.0 * R
		"whistle":
			var pr := shoot(t, id, l, d, "arc", 260.0, 345.0 * R, 20.0, true)
			pr.rxd["grow"] = 110.0
		"galeback":
			var pr := shoot(t, id, l, d, "gale", 160.0, 640.0 * R, 30.0, true, true)
			pr.rxd["back"] = 320.0 * R
		"wraith":
			shoot(t, id, l, d, "wraith", 140.0, 420.0 * R, 30.0, true, true)
		# --- 빛: 즉시 광선 ---
		"solar":
			fx_line(t, d, 2000.0, 14.0, c)
			t._line(orbs, d, 2000.0, 14.0, func(o):
				t.hit(o, 3.5 * p)
				o.burn(1.0 * l * Rules.rx_mul, 1.5, t, true))
		"photo":
			fx_line(t, d, 2000.0, 12.0, c)
			var n := [0]
			t._line(orbs, d, 2000.0, 12.0, func(o):
				t.hit(o, 3.0 * p)
				n[0] += 1)
			if n[0] > 0:
				t.photo_t = 2.0
				t.photo_k = minf(0.05 * n[0], 0.25)
		"corrosive":
			fx_line(t, d, 2000.0, 12.0, c)
			t._line(orbs, d, 2000.0, 12.0, func(o):
				t.hit(o, 3.0 * p)
				if o.poison_t > 0.0:
					o.poison(minf(o.poison_dps * 2.0, o.poison_dps + 3.0 * l * Rules.rx_mul), 4.0, t, true)
				else:
					o.poison(1.2 * l * Rules.rx_mul, 4.0, t, true))
		"flash":
			fx_line(t, d, 2000.0, 14.0, c)
			t._line(orbs, d, 2000.0, 14.0, func(o):
				t.hit(o, 2.6 * p)
				o.root(0.6))
		# --- 소리: 부채꼴 파동 ---
		"blast":
			fx_cone(t, d, 240.0 * R, 0.5, c)
			t._cone(orbs, d, 240.0 * R, 0.5, func(o):
				t.hit(o, 1.5 * p)
				if o.burn_t > 0.0 and o.hp > 0.0:
					_raw(t, o, o.burn_dps * o.burn_t)
					o.burn_t = 0.0)
		"drum":
			fx_cone(t, d, 240.0 * R, 0.5, c)
			t._cone(orbs, d, 240.0 * R, 0.5, func(o):
				t.hit(o, 1.8 * p)
				o.root(0.4)
				t._ring(o, 1.0))
		"resonate":
			fx_cone(t, d, 240.0 * R, 0.5, c)
			t._cone(orbs, d, 240.0 * R, 0.5, func(o):
				t.hit(o, 1.8 * p)
				var nb := _nearest(t, o.position, 90.0, [o])
				if nb:
					t.hit(nb, 1.2 * p)
					t.main.bolt(PackedVector2Array([o.position, nb.position])))
		"clarion":
			fx_cone(t, d, 240.0 * R, 0.5, c)
			t._cone(orbs, d, 240.0 * R, 0.5, func(o): t.hit(o, 1.6 * p, 0.99, {}, true, true))
		"toxecho":
			fx_cone(t, d, 240.0 * R, 0.5, c)
			t._cone(orbs, d, 240.0 * R, 0.5, func(o):
				t.hit(o, 1.0 * p)
				o.poison(1.0 * l * Rules.rx_mul, 4.0, t, true)
				o.toxring_t = 3.0
				o.toxring_lv = l
				o.toxring_src = t)
		"requiem":
			fx_cone(t, d, 240.0 * R, 0.5, c)
			t._cone(orbs, d, 240.0 * R, 0.5, func(o):
				t.hit(o, 1.5 * p)
				mark_death(o, t, id, l, 3.0))
		"reverb":
			_reverb(t, l, d, 2.0, 1.0)
			t.later.append([1.0, func(): _reverb(t, l, d, 1.4, 0.7)])
			t.later.append([2.0, func(): _reverb(t, l, d, 1.0, 0.5)])
		# --- 영혼: 혼불 ---
		"frostsoul":
			ghosts(t, id, l, 3, 2.4 * p)
		"foxfire":
			ghosts(t, id, l, 3, 1.8 * p)
		"soulbolt":
			ghosts(t, id, l, 2, 1.5 * p)
		"phantom":
			ghosts(t, id, l, 3, 1.8 * p)
		"angel":
			ghosts(t, id, l, 4, 1.4 * p)
		"samsara":
			ghosts(t, id, l, 2, 2.4 * p)
		"sword":
			for g in ghosts(t, id, l, 2, 1.0 * p):
				g.max_travel = 600.0
		# --- 그 밖 ---
		"thermal":
			fx_line(t, d, 300.0 * R, 12.0, c)
			t._line(orbs, d, 300.0 * R, 12.0, func(o):
				var ch: float = maxf(o.chill, 1.5 if o.frozen_t > 0.0 else 0.0)
				if ch >= 0.3:
					o.chill = 0.0
					t.hit(o, (1.8 + 2.4 * ch) * p)
					for nb in t.main.near_t(o.position, 50.0):
						if not is_instance_valid(nb):
							continue
						if nb != o and nb.position.distance_to(o.position) < 50.0 + nb.radius():
							t.hit(nb, 1.2 * p)
					t.main.burst(o.position, Color(1.0, 0.7, 0.5), 8, 140.0)
				else:
					t.hit(o, 1.8 * p)
					o.add_chill(1.0))
		"frostthorn":
			for i in 5:
				shoot(t, id, l, d.rotated(lerpf(-0.4, 0.4, i / 4.0)), "icethorn", 460.0, 320.0 * R, 5.0, false)
		"frostbolt":
			_frostbolt(t, l, d)
		"coldneedle":
			for a in [-0.2, 0.0, 0.2]:
				shoot(t, id, l, d.rotated(a), "needle", 420.0, 340.0 * R, 5.0, false)
		"icelance":
			shoot(t, id, l, d, "lance", 360.0, 400.0 * R, 10.0, true)
		"frostecho":
			_frostline(t, l, d)
			t.later.append([1.0, func(): _frostline(t, l, d)])
		"smog":
			var pr := shoot(t, id, l, d, "smog", 60.0, 240.0 * R, 50.0, true, true)
			pr.rxd["grow"] = 60.0
		"neurotoxin":
			var pts := []
			t._cone(orbs, d, 270.0 * R, 0.9, func(o):
				if o.poison_t > 0.0:
					t.hit(o, 1.0 * p)
					o.stagger(15.0)
					o.poison(minf(o.poison_dps + 0.5 * l * Rules.rx_mul, 1.2 * l * Rules.rx_mul), maxf(o.poison_t, 3.0), t, true)
					pts.append(o.position))
			for q in pts.slice(0, 8):
				t.main.bolt(PackedVector2Array([t.position, q]))
		"rust":
			for a in [-0.2, 0.0, 0.2]:
				shoot(t, id, l, d.rotated(a), "rust", 400.0, 340.0 * R, 6.0, false)
		"latent":
			var cand := []
			for o in t.main.near_t(t.position, 320.0 * R):
				if not is_instance_valid(o):
					continue
				if o.position.distance_to(t.position) < 320.0 * R and o.hp > 0.0:
					cand.append(o)
			cand.sort_custom(func(a, b): return a.poison_dps * a.poison_t > b.poison_dps * b.poison_t)
			var got: Array = cand.slice(0, 5)
			for o in got:
				o.poison(1.0 * l * Rules.rx_mul, 4.0, t, true)
				t.main.burst(o.position, c, 4, 60.0)
			t.later.append([2.0, func():
				for o in got:
					if is_instance_valid(o) and o.hp > 0.0:
						t.in_rx = true
						t.tag = "rx:latent"
						t.hit(o, 2.0 * p)
						if o.poison_t > 0.0:
							_raw(t, o, o.poison_dps * o.poison_t * 1.3)
							o.poison_t = 0.0
						t.in_rx = false
						t.tag = ""
						t.main.burst(o.position, c, 8, 120.0)])
		"plasma":
			shoot(t, id, l, d, "plasma", 180.0, 360.0 * R, 10.0, true)
		"blackfire":
			for a in [-0.25, 0.0, 0.25]:
				shoot(t, id, l, d.rotated(a), "flame", 380.0, 320.0 * R, 6.0, false)
		"hotiron":
			shoot(t, id, l, d, "hotiron", 200.0, 340.0 * R, 12.0, true)
		"embers":
			shoot(t, id, l, d, "fireball", 380.0, 340.0 * R, 7.0, false)
		"conduct":
			var o := _front(t, d, 260.0 * R, 0.8)
			if o:
				t.rxs["wire"] = [o, 1.5, 0.0, l]
		"rotroot":
			var best: Orb = null
			for o in t.main.near_t(t.position, 300.0 * R):
				if not is_instance_valid(o):
					continue
				if o.position.distance_to(t.position) < 300.0 * R and (best == null or o.hp > best.hp):
					best = o
			if best:
				t.hit(best, 5.0 * p)
				best.root(1.5)
				amp(best, "rot", 0.4, 1.5)
				fx_to(t, best.position, c)
		"saw":
			shoot(t, id, l, d, "saw", 260.0, 320.0 * R, 14.0, true)
		"rings":
			fx_line(t, d, 240.0 * R, 16.0, c)
			t._line(orbs, d, 240.0 * R, 16.0, func(o): t.hit(o, 2.0 * p))
			t.later.append([1.2, func():
				fx_line(t, d, 240.0 * R, 22.0, c)
				t._line(t.main.targets, d, 240.0 * R, 22.0, func(o): t.hit(o, 3.0 * p))])
		"darkbolt":
			var got := []
			for o in t.main.near_t(t.position, 400.0 * R):
				if not is_instance_valid(o):
					continue
				if o.hp > 0.0 and (o.vuln_t > 0.0 or not o.amp.is_empty()) and o.position.distance_to(t.position) < 400.0 * R:
					got.append(o)
			got.sort_custom(func(a, b): return a.position.distance_squared_to(t.position) < b.position.distance_squared_to(t.position))
			for o in got.slice(0, 8):
				t.hit(o, 2.6 * p)
				t.main.bolt(_zig(t.position, o.position))
		"scythe":
			fx_cone(t, d, 160.0 * R, 1.4, c)
			t._cone(orbs, d, 160.0 * R, 1.4, func(o):
				t.hit(o, 2.5 * p)
				if o.hp > 0.0 and o.hp < 0.2 * o.max_hp and o.kind in [Orb.Kind.NORMAL, Orb.Kind.FAST]:
					_raw(t, o, o.hp + 0.01, false)
					t.main.popup(o.position, 0, c, true, "처형"))
		"dusk":
			var near := []
			t._cone(orbs, d, 320.0 * R, 0.8, func(o): near.append(o))
			near.sort_custom(func(a, b): return a.position.distance_squared_to(t.position) < b.position.distance_squared_to(t.position))
			var got: Array = near.slice(0, 3)
			for o in got:
				amp(o, "dusk", 0.3, 2.0)
			t.later.append([2.0, func():
				for o in got:
					if is_instance_valid(o) and o.hp > 0.0:
						t.in_rx = true
						t.tag = "rx:dusk"
						t.hit(o, 3.0 * p)
						t.in_rx = false
						t.tag = ""
						t.main.burst(o.position, c, 8, 120.0)])
		_ when id in WAVES:
			wave(t, id, l, d, "water", 220.0 if id != "backflow" else 240.0, (WAVE_RANGE if id != "backflow" else 600.0) * R, 14.0)
		_ when id in CRACKS:
			wave(t, id, l, d, "crack", 240.0, CRACK_RANGE * R, 14.0)


## 한 번 더 울리는 부채꼴 (메아리).
static func _reverb(t: Tower, l: int, d: Vector2, m: float, a: float) -> void:
	if not is_instance_valid(t):
		return
	var c := color("reverb")
	fx_cone(t, d, 260.0 * Tower.reach(l), 0.5, Color(c, a))
	t.in_rx = true
	t.tag = "rx:reverb"
	t._cone(t.main.targets, d, 260.0 * Tower.reach(l), 0.5, func(o): t.hit(o, m * pwx(l)))
	t.in_rx = false
	t.tag = ""


## 서리 메아리: 앞 직선 냉기 파동.
static func _frostline(t: Tower, l: int, d: Vector2) -> void:
	if not is_instance_valid(t):
		return
	var L := 280.0 * Tower.reach(l)
	fx_line(t, d, L, 18.0, color("frostecho"))
	t.in_rx = true
	t.tag = "rx:frostecho"
	t._line(t.main.targets, d, L, 18.0, func(o):
		t.hit(o, 2.3 * pwx(l))
		o.add_chill(1.0))
	t.in_rx = false
	t.tag = ""


## 빙뢰: 연쇄 번개 5개. 냉기 있는 구체끼리는 멀리(600)까지 튀고 피해 2배.
static func _frostbolt(t: Tower, l: int, d: Vector2) -> void:
	var first := _front(t, d, 280.0 * Tower.reach(l), 0.5)
	if first == null:
		return
	var got := [first]
	var cur := first
	while got.size() < 5:
		var nxt: Orb = null
		var bd := INF
		for o in t.main.near_t(cur.position, 600.0):
			if not is_instance_valid(o):
				continue
			if got.has(o) or o.hp <= 0.0:
				continue
			var dd: float = o.position.distance_to(cur.position)
			var cold: bool = o.chill > 0.0 or o.frozen_t > 0.0
			if (dd < 110.0 or cold and dd < 600.0) and dd < bd:
				bd = dd
				nxt = o
		if nxt == null:
			break
		got.append(nxt)
		cur = nxt
	var pts := PackedVector2Array([t.position])
	for o in got:
		pts.append(o.position)
		var cold: bool = o.chill > 0.0 or o.frozen_t > 0.0
		t.hit(o, 2.4 * pwx(l) * (2.0 if cold else 1.0))
	t.main.bolt(pts)


## 진자: 앞에서 크게 왕복하는 철 추 (같은 구체는 1초에 한 번).
static func _pendulum(t: Tower, l: int, orbs: Array, de: float) -> void:
	t.pend_ph += de * TAU / 2.0
	var cdm: Dictionary = t.rxs.get("pend_cd", {})
	for key in cdm.keys():
		cdm[key] -= de
		if cdm[key] <= 0.0 or not is_instance_valid(key):
			cdm.erase(key)
	t.rxs["pend_cd"] = cdm
	var hd := t.dir.rotated(sin(t.pend_ph) * 1.1)
	t._line(orbs, hd, 220.0 * Tower.reach(l), 14.0, func(o):
		if not cdm.has(o):
			cdm[o] = 1.0
			t.hit(o, 0.8 * pwx(l))
			o.stagger(20.0))


## 전도 덩굴: 감긴 구체에 1.5초 동안 전기, 0.5초마다 옆 구체로 튐.
static func _conduct_tick(t: Tower, l: int, de: float) -> void:
	var w: Array = t.rxs.get("wire", [])
	if w.is_empty():
		return
	var o: Orb = w[0] if is_instance_valid(w[0]) else null
	w[1] -= de
	if o == null or o.hp <= 0.0 or w[1] <= 0.0:
		t.rxs.erase("wire")
		return
	var p := pwx(w[3])
	t.hit(o, 3.0 * p * de, de * 3.0)
	w[2] -= de
	if w[2] <= 0.0:
		w[2] = 0.5
		var nb := _nearest(t, o.position, 90.0, [o])
		if nb:
			t.hit(nb, 1.5 * p)
			t.main.bolt(PackedVector2Array([o.position, nb.position]))


# ---------- 만드는 것 ----------

## 반응 발사체 (kind "rx"). cont: 닿아 있는 동안 계속(프레임마다 on_hit), pierce: 뚫고 지나감(구체마다 한 번).
static func shoot(t: Tower, id: String, l: int, d: Vector2, look: String, speed: float, travel: float, radius: float, pierce: bool, cont := false) -> Projectile:
	var pr: Projectile = t.main.spawn_proj(t, "rx", l, d)
	pr.rx = id
	pr.look = look
	pr.vel = d * speed
	pr.max_travel = travel
	pr.radius = radius
	pr.pierce = pierce
	pr.continuous = cont
	pr.col = color(id)
	pr.dmg = 0.0
	return pr


## 물결·균열: 앞으로 나가며 지나간 자리에 띠(Zone trail "rx:id")를 남긴다.
static func wave(t: Tower, id: String, l: int, d: Vector2, look: String, speed: float, travel: float, radius: float) -> Projectile:
	var pr := shoot(t, id, l, d, look, speed, travel, radius, true)
	if id == "backflow":
		pr.rxd["back"] = travel * 0.5
	var z: Zone = t.main.spawn_zone("trail", l, pr.position, t)
	z.trail_rx(id, 20.0 + 2.0 * (l - 1), STRIP_LIFE)
	z.add_pt(pr.position)
	pr.zone = z
	return pr


## 혼불 n개 (화면의 혼불 30개 상한은 넋 혼불과 같이 센다).
static func ghosts(t: Tower, id: String, l: int, n: int, dmg: float) -> Array:
	var out := []
	var cnt := 0
	for q in t.main.projectiles.get_children():
		if q.kind == "ghost":
			cnt += 1
	for i in n:
		if cnt >= 30:
			break
		cnt += 1
		var a := lerpf(-0.35, 0.35, i / maxf(n - 1, 1.0)) if n > 1 else 0.0
		var g: Projectile = t.main.spawn_proj(t, "ghost", l, t.dir.rotated(a))
		g.dmg = dmg
		g.ghost = id
		if id == "sword":
			g.pierce = true
		out.append(g)
	return out


## 구체가 죽으면 그 반응 효과 (sec초 안에). main의 처치 처리가 on_death를 부른다.
static func mark_death(o: Orb, t: Tower, id: String, l: int, sec: float) -> void:
	o.dfx[id] = [t, l, o.age + sec]


## 받는 피해 증가 (반응마다 따로 곱한다).
static func amp(o: Orb, key: String, k: float, sec: float) -> void:
	var cur: Array = o.amp.get(key, [0.0, 0.0])
	o.amp[key] = [maxf(cur[0], k), maxf(cur[1], sec)]


## 배율 없이 그대로 주는 피해 (남은 화상·중독을 한 번에 등). 반응 피해로 센다.
static func _raw(t: Tower, o: Orb, d: float, mul := true) -> void:
	if d <= 0.0:
		return
	if mul:
		o.hurt(d)
	else:
		o.hp -= d
	t.credit(d, t.tag if t.tag != "" else "hit")
	t.rx_dealt += d
	if d >= 1.0:
		t.main.popup(o.position, d, t.color(), true)


static func _nearest(t: Tower, p: Vector2, r: float, skip: Array) -> Orb:
	var best: Orb = null
	var bd := r
	for o in t.main.near_t(p, r):
		if not is_instance_valid(o):
			continue
		if skip.has(o) or o.hp <= 0.0:
			continue
		var dd: float = o.position.distance_to(p)
		if dd < bd:
			bd = dd
			best = o
	return best


## 앞쪽(각도 half 안) 가장 가까운 구체.
static func _front(t: Tower, d: Vector2, rng: float, half: float) -> Orb:
	var best: Orb = null
	var bd := rng
	for o in t.main.near_t(t.position, rng):
		if not is_instance_valid(o):
			continue
		var v: Vector2 = o.position - t.position
		if o.hp > 0.0 and v.length() < bd and absf(d.angle_to(v)) < half:
			bd = v.length()
			best = o
	return best


static func _zig(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	for i in 3:
		pts.append(a.lerp(b, (i + 1) / 4.0) + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
	pts.append(b)
	return pts


# ---------- 발사체 (Projectile) ----------

static func proj_step(pr: Projectile, delta: float) -> void:
	var tw := pr.owner_tower
	if pr.rxd.has("grow"):
		var f := clampf(pr.travel / maxf(pr.max_travel, 1.0), 0.0, 1.0)
		if not pr.rxd.has("r0"):
			pr.rxd["r0"] = pr.radius
		pr.radius = lerpf(pr.rxd["r0"], pr.rxd["grow"], f)
	# 부메랑·되돌이: 반쯤 가면 같은 길로 돌아온다
	if pr.rxd.has("back") and not pr.rxd.has("turned") and pr.travel >= pr.rxd["back"]:
		pr.rxd["turned"] = true
		pr.vel = -pr.vel
		pr.hit.clear()
	if not is_instance_valid(tw):
		return
	match pr.rx:
		"plasma":
			pr.zap_t -= delta
			if pr.zap_t <= 0.0:
				pr.zap_t = 0.4
				var n := 0
				tw.in_rx = true
				tw.tag = pr.src
				for o in tw.main.near_t(pr.position, 70.0):
					if not is_instance_valid(o):
						continue
					if n >= 3:
						break
					if o.hp > 0.0 and o.position.distance_to(pr.position) < 70.0:
						n += 1
						tw.hit(o, 1.2 * pwx(pr.level))
						o.burn(1.0 * pr.level, 2.0, tw, true)
						tw.main.bolt(PackedVector2Array([pr.position, o.position]))
				tw.in_rx = false
				tw.tag = ""
		"hotiron":
			if not pr.rxd.has("boom") and pr.travel >= pr.max_travel - pr.vel.length() / 60.0:
				pr.rxd["boom"] = true
				_boom(tw, pr.src, pr.position, 80.0, 3.0 * pwx(pr.level), pr.col)


## 반응 발사체가 구체에 닿았을 때. 사라져야 하면 true. (tw.tag·in_rx는 부르는 쪽이 정함)
static func proj_hit(pr: Projectile, o: Orb, delta: float, tw: Tower) -> bool:
	var l := pr.level
	var p := pwx(l)
	if pr.continuous:
		match pr.rx:
			"sandstorm":
				tw.hit(o, 3.5 * p * delta, delta * 3.0)
				o.slow(0.5, 0.3)
				if not pr.hit.has(o) or pr.t - pr.hit[o] >= 0.5:
					pr.hit[o] = pr.t
					if randf() < 0.25:
						o.root(0.6)
			"vacuum":
				var v: Vector2 = pr.position - o.position
				var dd := pr.vel.normalized()
				v -= dd * v.dot(dd)
				o.push(v.limit_length(60.0 * delta))
				tw.hit(o, 3.5 * p * delta, delta * 3.0)
				amp(o, "vacuum", 0.3, 0.5)
			"galeback":
				tw.hit(o, 3.0 * p * delta, delta * 3.0)
				o.slow(0.7, 0.3)
			"wraith":
				tw.hit(o, 3.0 * p * delta, delta * 3.0)
				mark_death(o, tw, "wraith", l, 0.3)
			"smog":
				tw.hit(o, 0.4 * p * delta, delta * 3.0)
				o.burn(0.5 * l * Rules.rx_mul, 2.0, tw, true)
				o.poison(0.6 * l * Rules.rx_mul, 3.0, tw, true)
				o.smog_t = 2.0
		return false
	if pr.hit.has(o):
		return false
	pr.hit[o] = true
	match pr.rx:
		"miasma":
			tw.hit(o, 1.5 * p)
			if o.poison_t > 0.0:
				_raw(tw, o, o.poison_dps * o.poison_t * 0.5)
				o.poison_t *= 0.5
			o.poison(1.4 * l * Rules.rx_mul, 4.0, tw, true)
		"seedwind":
			tw.hit(o, 1.0 * p)
			o.seed_n = mini(o.seed_n + 1, 3)
			o.seed_t = 3.0
			o.seed_lv = l
			o.seed_src = tw
			amp(o, "seed", 0.15 * o.seed_n, 3.0)
		"tidal":
			tw.hit(o, 2.4 * p)
			o.push(pr.vel.normalized() * 40.0)
			o.slow(0.6, 0.6)
		"feather":
			tw.hit(o, 1.8 * p, 0.99, {}, true, true)
			return true
		"bladewind":
			tw.hit(o, 1.6 * p)
			o.stagger(20.0)
		"whistle":
			tw.hit(o, 2.2 * p)
			tw._ring(o, 1.0)
		"frostthorn":
			tw.hit(o, 2.2 * p * (3.0 if o.frozen_t > 0.0 else 1.0))
			o.add_chill(0.8)
			return true
		"coldneedle":
			tw.hit(o, 1.7 * p)
			o.poison(1.4 * l * Rules.rx_mul, 4.0, tw, true)
			o.add_chill(0.8)
			o.frostpo_t = 4.0
			return true
		"icelance":
			if o.frozen_t > 0.0:
				tw.hit(o, 4.5 * p * 3.0)
				for a in [-0.6, 0.0, 0.6]:
					var f: Projectile = tw.main.spawn_proj(tw, "frag", l, pr.vel.normalized().rotated(a))
					f.position = o.position
					f.hit[o] = true
					f.src = pr.src
			else:
				tw.hit(o, 4.5 * p)
		"rust":
			tw.hit(o, 1.5 * p)
			o.poison(1.4 * l * Rules.rx_mul, 4.0, tw, true)
			o.rust_n = mini(o.rust_n + 1, 5)
			o.amp["rust"] = [0.08 * o.rust_n, 4.0]
			return true
		"plasma":
			tw.hit(o, 1.2 * p)
			o.burn(1.0 * l * Rules.rx_mul, 2.0, tw, true)
		"blackfire":
			tw.hit(o, 1.8 * p)
			o.burn(1.2 * l * Rules.rx_mul, 3.0, tw, true)
			amp(o, "blackfire", 0.25, 3.0)
			return true
		"hotiron":
			tw.hit(o, 2.0 * p)
			o.burn(1.0 * l * Rules.rx_mul, 2.0, tw, true)
		"embers":
			tw.hit(o, 2.5 * p)
			var src := pr.src
			var c := pr.col
			var at := o.position
			for q in [[1.0, 0.7], [2.0, 0.5]]:
				tw.later.append([q[0], func():
					if is_instance_valid(tw):
						_boom(tw, src, o.position if is_instance_valid(o) else at, 50.0, 2.5 * p * q[1], c)])
			return true
		"saw":
			tw.hit(o, 2.2 * p)
			amp(o, "thorn", 0.2, 3.0)
		_ when pr.rx in WAVES or pr.rx in CRACKS:
			tw.hit(o, (1.8 if pr.rx in ["glacier", "mud", "foulwater"] else 2.5 if pr.rx == "rainbow" else 2.0 if pr.rx in CRACKS else 1.5) * p)
			if pr.rx == "glacier":
				o.add_chill(0.6)
			elif pr.rx == "backflow" and pr.rxd.has("turned"):
				o.push(pr.vel.normalized() * 30.0)
	return false


## 혼불 반응이 맞혔을 때. 사라져야 하면 true.
static func ghost_hit(pr: Projectile, o: Orb, tw: Tower) -> bool:
	if pr.hit.has(o):
		return false
	pr.hit[o] = true
	var l := pr.level
	var p := pwx(l)
	match pr.ghost:
		"angel":
			tw.hit(o, pr.dmg, 0.99, {}, false, true)
		_:
			tw.hit(o, pr.dmg, 1.0, {}, false)
	match pr.ghost:
		"frostsoul":
			if o.root(0.8):
				o.frozen_t = o.root_timer
		"foxfire":
			o.burn(1.2 * l * Rules.rx_mul, 3.0, tw, true)
			mark_death(o, tw, "foxfire", l, 3.0)
		"soulbolt":
			var got := [o]
			var cur := o
			var pts := PackedVector2Array([o.position])
			for i in 3:
				var nb := _nearest(tw, cur.position, 110.0, got)
				if nb == null:
					break
				got.append(nb)
				pts.append(nb.position)
				tw.hit(nb, 1.5 * p)
				cur = nb
			if pts.size() > 1:
				tw.main.bolt(pts)
		"phantom":
			amp(o, "phantom", 0.3, 3.0)
			mark_death(o, tw, "phantom", l, 3.0)
		"samsara":
			mark_death(o, tw, "samsara", l, 3.0)
		"sword":
			o.stagger(10.0)
			return false
	return true


# ---------- 띠 (Zone trail "rx:id") ----------

## 띠 위의 구체 (Zone.affect, 프레임마다). 같은 반응의 띠가 겹쳐도 한 구체는 한 조각에 한 번.
static func zone_hit(z: Zone, o: Orb, delta: float) -> void:
	var tw := z.owner_tower
	if not is_instance_valid(tw):
		return
	var seen: Dictionary = tw.rx_trail_hit.get(z.sub, {})
	if seen.get(o, -1) == tw.main.sim_id:
		return
	if seen.size() > 300:
		seen.clear()
	seen[o] = tw.main.sim_id
	tw.rx_trail_hit[z.sub] = seen
	var id := z.sub.substr(3)
	var l := z.level
	var p := pwx(l)
	var k := delta * 3.0
	tw.in_rx = true
	tw.tag = z.src
	match id:
		"tidal":
			o.slow(0.6, 0.3)
		"glacier":
			tw.hit(o, 1.2 * p * delta, k)
			o.add_chill(1.2 * delta)
			o.slow(0.6, 0.3)
			o.glacier_t = 0.3
		"mud":
			tw.hit(o, 1.0 * p * delta, k)
			o.slow(0.4, 0.3)
			o.mud_t = 0.5
		"foulwater":
			tw.hit(o, 0.8 * p * delta, k)
			o.poison(1.2 * l * Rules.rx_mul, 3.0, tw, true)
			mark_death(o, tw, "foulwater", l, 0.3)
		"blackwater":
			tw.hit(o, 0.8 * p * delta, k)
			var best := o.position
			var bd := INF
			for q in z.pts:
				var dd := q.distance_squared_to(o.position)
				if dd < bd:
					bd = dd
					best = q
			o.push((best - o.position).limit_length(40.0 * delta))
			amp(o, "blackwater", 0.3, 0.5)
		"rainbow":
			tw.hit(o, 0.6 * p * delta, k)
			o.lucky_t = 0.5
		"mercury":
			if z.caught.get(o, -1.0) <= z.t:
				z.caught[o] = z.t + 0.8
				tw.hit(o, 0.8 * p)
				o.stagger(8.0)
		"ripple":
			tw.hit(o, 0.6 * p * delta, k)
			tw._ring(o, delta * Rules.t("strip_ring"))
		"backflow":
			o.slow(0.7, 0.3)
		"icecrack":
			tw.hit(o, 1.2 * p * delta, k)
			o.add_chill(1.2 * delta)
			o.slow(0.4, 0.3)
			if o.frozen_t > 0.0 and not z.caught.has(o):
				z.caught[o] = true
				o.root(1.0)
		"thornvine":
			tw.hit(o, 1.4 * p * delta, k)
			o.slow(0.5, 0.3)
			amp(o, "thorn", 0.2, 3.0)
		"ground":
			if z.caught.get(o, -1.0) <= z.t:
				z.caught[o] = z.t + 0.5
				tw.hit(o, 0.85 * p)
				if randf() < 0.3:
					o.root(0.6)
				tw.main.bolt(PackedVector2Array([o.position + Vector2(0, -26), o.position]))
		"shadowcrack":
			tw.hit(o, 1.0 * p * delta, k)
			o.slow(0.6, 0.3)
			amp(o, "shadow", 0.4, 1.0)
		"crystal":
			tw.hit(o, 1.2 * p * delta, k, {}, true, true)
		"rumble":
			tw.hit(o, 1.0 * p * delta, k)
			tw._ring(o, delta * Rules.t("strip_ring"))
			o.loud_t = 0.5
		"tomb":
			tw.hit(o, 1.5 * p * delta, k)
			mark_death(o, tw, "tomb", l, 0.3)
	tw.in_rx = false
	tw.tag = ""


# ---------- 구체 쪽 (Orb·main) ----------

## 씨앗 바람: 씨앗이 다 자라면 터져 피해·묶음.
static func sprout(o: Orb) -> void:
	var tw: Tower = o.seed_src if is_instance_valid(o.seed_src) else null
	o.seed_n = 0
	o.amp.erase("seed")
	if tw == null or o.hp <= 0.0:
		return
	tw.in_rx = true
	tw.tag = "rx:seedwind"
	tw.hit(o, 2.4 * pwx(o.seed_lv))
	tw.in_rx = false
	tw.tag = ""
	o.root(0.6)
	tw.main.burst(o.position, color("seedwind"), 8, 100.0)


## 반응 표식을 단 채 죽은 구체 (main 처치 처리).
static func on_death(o: Orb) -> void:
	for id in o.dfx:
		var q: Array = o.dfx[id]
		var tw: Tower = q[0] if is_instance_valid(q[0]) else null
		if tw == null or o.age > q[2]:
			continue
		var l: int = q[1]
		var pos := o.position
		tw.tag = "rx:" + id
		match id:
			"wraith", "requiem", "phantom":
				_ghost_at(tw, id, l, pos, 2.4 * pwx(l), 1)
			"tomb":
				_ghost_at(tw, id, l, pos, 2.4 * pwx(l), 2)
			"samsara":
				var src_t := tw
				tw.later.append([1.0, func():
					if is_instance_valid(src_t):
						src_t.tag = "rx:samsara"
						_ghost_at(src_t, "samsara2", l, pos, 2.0 * pwx(l), 2)
						src_t.tag = ""])
			"foxfire":
				var nb := _nearest(tw, pos, 120.0, [o])
				if nb:
					nb.burn(1.2 * l * Rules.rx_mul, 3.0, tw, true)
					tw.main.burst(nb.position, color(id), 5, 80.0)
			"foulwater":
				if o.poison_t > 0.0:
					for nb in tw.main.near_t(pos, 140.0):
						if not is_instance_valid(nb):
							continue
						if nb != o and nb.position.distance_to(pos) < 140.0:
							nb.poison(o.poison_dps, 3.0, tw, true)
		tw.tag = ""


static func _ghost_at(tw: Tower, id: String, l: int, pos: Vector2, dmg: float, n: int) -> void:
	var cnt := 0
	for q in tw.main.projectiles.get_children():
		if q.kind == "ghost":
			cnt += 1
	for i in n:
		if cnt >= 30:
			return
		cnt += 1
		var g: Projectile = tw.main.spawn_proj(tw, "ghost", l, Vector2.from_angle(randf() * TAU))
		g.position = pos
		g.dmg = dmg
		g.ghost = "samsara2" if id == "samsara2" else ""  # 죽으며 나온 혼불은 표식을 다시 달지 않는다
		g.src = "rx:" + (id if id != "samsara2" else "samsara")


static func _boom(tw: Tower, src: String, pos: Vector2, r: float, dmg: float, c: Color) -> void:
	tw.in_rx = true
	tw.tag = src
	for o in tw.main.near_t(pos, r):
		if is_instance_valid(o) and o.hp > 0.0 and o.position.distance_to(pos) < r + o.radius():
			tw.hit(o, dmg)
	tw.in_rx = false
	tw.tag = ""
	tw.main.burst(pos, c, 10, 150.0)
	if tw.main.pulses.size() < 40:
		tw.main.pulses.append([pos, r, 0.3])


# ---------- 표시 ----------

static func fx_line(t: Tower, d: Vector2, length: float, w: float, c: Color) -> void:
	if t.rxfx.size() < 12:
		t.rxfx.append({"k": "line", "d": d, "L": minf(length, 1400.0), "w": w, "c": c, "t": 0.3, "T": 0.3})


static func fx_cone(t: Tower, d: Vector2, R: float, half: float, c: Color) -> void:
	if t.rxfx.size() < 12:
		t.rxfx.append({"k": "cone", "d": d, "L": R, "w": half, "c": c, "t": 0.4, "T": 0.4})


## 오브젝트에서 한 지점(전역)까지 잠깐 잇는 선 (썩은 뿌리).
static func fx_to(t: Tower, pos: Vector2, c: Color) -> void:
	if t.rxfx.size() < 12:
		t.rxfx.append({"k": "to", "p": pos, "c": c, "t": 0.5, "T": 0.5})


## Tower._draw_attack 끝에서: 즉시 효과·진자·전도 덩굴.
static func draw_tower(t: Tower) -> void:
	for f in t.rxfx:
		var a: float = f["t"] / f["T"]
		var c: Color = f["c"]
		match f["k"]:
			"line":
				var d: Vector2 = f["d"]
				t.draw_line(d * Tower.RADIUS, d * f["L"], Color(c, c.a * a * 0.85), f["w"] * a + 2.0)
				t.draw_line(d * Tower.RADIUS, d * f["L"], Color(1, 1, 1, 0.6 * a * c.a), 2.0)
			"cone":
				var k := 1.0 - a
				var d: Vector2 = f["d"]
				for i in 3:
					t.draw_arc(Vector2.ZERO, f["L"] * clampf(k - i * 0.12, 0.05, 1.0), d.angle() - f["w"], d.angle() + f["w"], 20, Color(c, c.a * a * 0.9), 4.0 - i)
			"to":
				var p: Vector2 = f["p"] - t.position
				var pts := PackedVector2Array()
				for i in 9:
					var x := i / 8.0
					pts.append(p * x + p.orthogonal().normalized() * sin(x * PI * 3.0) * 6.0)
				t.draw_polyline(pts, Color(c, a), 3.0)
	for r in t.reactions():
		match r["id"]:
			"pendulum":
				var rl := mini(t.eff.get(r["a"], 1), t.eff.get(r["b"], 1))
				var L := 220.0 * Tower.reach(rl)
				var hd := t.dir.rotated(sin(t.pend_ph) * 1.1)
				t.draw_arc(Vector2.ZERO, L, t.dir.angle() - 1.1, t.dir.angle() + 1.1, 28, Color(r["color"], 0.12), 2.0)
				t.draw_line(hd * Tower.RADIUS, hd * L, Color(r["color"], 0.7), 3.0)
				t.draw_circle(hd * L, 10.0, r["color"])
				t.draw_circle(hd * L, 5.0, Color(0.3, 0.3, 0.35))
			"conduct":
				var w: Array = t.rxs.get("wire", [])
				if not w.is_empty() and is_instance_valid(w[0]):
					var p: Vector2 = w[0].position - t.position
					var pts := PackedVector2Array()
					for i in 9:
						var x := i / 8.0
						pts.append(p * x + p.orthogonal().normalized() * sin(x * PI * 4.0 + t.t * 6.0) * 5.0)
					t.draw_polyline(pts, Elem.COLORS[Elem.WOOD], 3.0)
					t.draw_polyline(_zig(Vector2.ZERO, p), Color(Elem.COLORS[Elem.ELECTRIC], 0.8), 1.5)


static func draw_proj(pr: Projectile) -> void:
	var c := pr.col
	var d := pr.vel.normalized()
	var n := d.orthogonal()
	var fade := clampf((pr.max_travel - pr.travel) / 40.0, 0.0, 1.0)
	var tt := pr.t
	match pr.look:
		"cloud", "smog":
			for i in 7:
				var a := i * 0.9 + tt * 0.8
				pr.draw_circle(Vector2(cos(a), sin(a)) * pr.radius * 0.5, pr.radius * 0.5, Color(c, 0.16 * fade))
			if pr.look == "smog":
				for i in 3:
					pr.draw_circle(Vector2(cos(i * 2.1 + tt * 3.0), sin(i * 2.1)) * pr.radius * 0.4, 4.0, Color(Elem.COLORS[Elem.FIRE], 0.7 * fade))
		"sand", "gale", "wraith":
			pr.draw_circle(Vector2.ZERO, pr.radius, Color(c, 0.12 * fade))
			for i in 14:
				var a := tt * 9.0 + i * 0.7
				var rr := pr.radius * (0.2 + 0.055 * i)
				pr.draw_circle(Vector2(cos(a) * rr, sin(a) * rr * 0.5 - i + 8.0), 2.0 + i * 0.2, Color(c, (0.85 - i * 0.04) * fade))
		"vacuum":
			pr.draw_circle(Vector2.ZERO, pr.radius, Color(c, 0.1 * fade))
			for i in 3:
				var pts := PackedVector2Array()
				for s in 12:
					var ang := -tt * 5.0 + i * TAU / 3 + s * 0.4
					pts.append(Vector2(cos(ang), sin(ang)) * pr.radius * (1.0 - s / 12.0))
				pr.draw_polyline(pts, Color(c, 0.8 * fade), 2.0)
			pr.draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, fade))
		"seeds":
			for i in 7:
				var p := n * sin(i * 1.9) * pr.radius * 0.8 - d * (i % 3) * 6.0
				pr.draw_circle(p, 2.5, Color(Elem.COLORS[Elem.WOOD].lightened(0.3), fade))
		"tide", "water":
			var w := pr.radius
			var pts := PackedVector2Array()
			for i in 9:
				var x := lerpf(-1.0, 1.0, i / 8.0)
				pts.append(n * x * w + d * (cos(x * 1.5) * 8.0 + sin(tt * 10.0 + i) * 2.0))
			pr.draw_polyline(pts, Color(c, 0.9 * fade), 5.0)
			pr.draw_polyline(pts, Color(1, 1, 1, 0.5 * fade), 1.5)
		"crack":
			for i in 4:
				var a := d.rotated(randf_range(-1.2, 1.2))
				pr.draw_line(Vector2.ZERO, a * randf_range(6.0, 16.0), Color(c.darkened(0.3), fade), 2.5)
			pr.draw_circle(Vector2.ZERO, 6.0, Color(c, fade))
		"feather":
			pr.draw_colored_polygon(PackedVector2Array([d * 10, n * 3, -d * 8, -n * 3]), Color(c, fade))
		"blade":
			var rot := Transform2D(tt * 18.0, Vector2.ZERO)
			for a in [0.0, TAU / 3, TAU * 2 / 3]:
				var v := Vector2.from_angle(a) * pr.radius
				pr.draw_colored_polygon(rot * PackedVector2Array([v, v.rotated(0.9) * 0.4, Vector2.ZERO]), c)
		"arc":
			for i in 3:
				pr.draw_arc(-d * pr.radius * 0.5, pr.radius - i * 5.0, d.angle() - 0.6, d.angle() + 0.6, 16, Color(c, (0.8 - i * 0.2) * fade), 3.0)
		"icethorn", "needle", "rust", "flame":
			var cc := c if pr.look != "flame" else Elem.COLORS[Elem.FIRE].lerp(c, 0.5)
			pr.draw_colored_polygon(PackedVector2Array([d * 11, -d * 7 - n * 3.5, -d * 3, -d * 7 + n * 3.5]), cc)
		"lance":
			pr.draw_line(-d * 18.0, d * 14.0, c, 5.0)
			pr.draw_colored_polygon(PackedVector2Array([d * 22, d * 12 + n * 6, d * 12 - n * 6]), c.lightened(0.3))
		"plasma", "fireball":
			var fl := 1.0 + 0.15 * sin(tt * 20.0)
			pr.draw_circle(Vector2.ZERO, pr.radius * 1.8 * fl, Color(c, 0.25))
			pr.draw_circle(Vector2.ZERO, pr.radius * fl, c)
			pr.draw_circle(Vector2.ZERO, pr.radius * 0.45, Color(1, 1, 1, 0.8))
		"hotiron":
			pr.draw_circle(Vector2.ZERO, pr.radius, Elem.COLORS[Elem.METAL].lerp(Elem.COLORS[Elem.FIRE], 0.6))
			pr.draw_arc(Vector2.ZERO, pr.radius, 0, TAU, 20, Color(1.0, 0.8, 0.4), 2.0)
		"saw":
			var pts := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16 + tt * 14.0
				pts.append(Vector2.from_angle(a) * pr.radius * (1.0 if i % 2 == 0 else 0.7))
			pr.draw_colored_polygon(pts, Elem.COLORS[Elem.METAL])
			pr.draw_circle(Vector2.ZERO, pr.radius * 0.35, Elem.COLORS[Elem.WOOD])
		_:
			pr.draw_circle(Vector2.ZERO, pr.radius, c)


## 반응 띠 그리기 색
static func strip_color(sub: String) -> Color:
	return color(sub.substr(3))


# ---------- 범위 미리보기 (Tower.draw_range) ----------

static func range_preview(ci: CanvasItem, o: Vector2, d: Vector2, id: String, rl: int, rc: Color) -> void:
	var R := Tower.reach(rl)
	match id:
		"miasma":
			Tower._r_band(ci, o, d, 0.0, 450.0 * R, 50.0, rc)
		"sandstorm", "wraith":
			Tower._r_band(ci, o, d, 0.0, 420.0 * R, 34.0, rc)
		"seedwind":
			Tower._r_band(ci, o, d, 0.0, 380.0 * R, 30.0, rc)
		"tidal":
			Tower._r_band(ci, o, d, 0.0, 320.0 * R, 60.0, rc)
		"vacuum":
			Tower._r_band(ci, o, d, 0.0, 360.0 * R, 45.0, rc)
		"feather":
			Tower._r_cone(ci, o, d, 320.0 * R, 0.5, rc)
		"bladewind":
			Tower._r_cone(ci, o, d, 300.0 * R, 0.25, rc)
		"whistle":
			Tower._r_cone(ci, o, d, 345.0 * R, 0.45, rc)
		"galeback":
			Tower._r_band(ci, o, d, 0.0, 320.0 * R, 30.0, rc)
		"solar", "photo", "corrosive", "flash":
			Tower._r_band(ci, o, d, 0.0, 2000.0, 12.0, rc)
		"blast", "drum", "resonate", "clarion", "toxecho", "requiem":
			Tower._r_cone(ci, o, d, 240.0 * R, 0.5, rc)
		"reverb":
			Tower._r_cone(ci, o, d, 260.0 * R, 0.5, rc)
		"thermal":
			Tower._r_band(ci, o, d, 0.0, 300.0 * R, 12.0, rc)
		"frostecho":
			Tower._r_band(ci, o, d, 0.0, 280.0 * R, 18.0, rc)
		"rings":
			Tower._r_band(ci, o, d, 0.0, 240.0 * R, 22.0, rc)
		"frostthorn", "coldneedle", "rust", "blackfire":
			Tower._r_cone(ci, o, d, 330.0 * R, 0.4, rc)
		"icelance", "hotiron", "saw", "embers", "plasma":
			Tower._r_band(ci, o, d, 0.0, 360.0 * R, 12.0, rc)
		"frostbolt":
			Tower._r_cone(ci, o, d, 280.0 * R, 0.5, rc)
		"neurotoxin":
			Tower._r_cone(ci, o, d, 270.0 * R, 0.9, rc)
		"smog":
			Tower._r_band(ci, o, d, 0.0, 240.0 * R, 55.0, rc)
		"latent", "rotroot", "darkbolt":
			ci.draw_arc(o, (320.0 if id == "latent" else 300.0 if id == "rotroot" else 400.0) * R, 0, TAU, 64, Color(rc.r, rc.g, rc.b, 0.5 * rc.a), 1.5)
		"conduct":
			Tower._r_cone(ci, o, d, 260.0 * R, 0.8, rc)
		"scythe":
			Tower._r_cone(ci, o, d, 160.0 * R, 1.4, rc)
		"dusk":
			Tower._r_cone(ci, o, d, 320.0 * R, 0.8, rc)
		"pendulum":
			Tower._r_cone(ci, o, d, 220.0 * R, 1.1, rc)
		_ when id in WAVES:
			Tower._r_band(ci, o, d, 0.0, WAVE_RANGE * R, 22.0, rc)
		_ when id in CRACKS:
			Tower._r_band(ci, o, d, 0.0, CRACK_RANGE * R, 22.0, rc)
		_ when id in GHOSTS:
			ci.draw_arc(o, 380.0, 0, TAU, 64, Color(rc.r, rc.g, rc.b, 0.5 * rc.a), 1.5)
