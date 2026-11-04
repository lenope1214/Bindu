class_name Zone
extends Node2D
## 바닥에 남는 효과(지나간 자리 장판, 블랙홀, 바위 벽, 물 흐름 물길). kind로 구분한다.
## 지나간 자리 장판(trail)은 탄 하나가 지나온 점들을 들고, 점마다 life만큼 남는다. sub: puddle(투척 장판).
## 물길(rill, 물 특징 흐름: 날아가는 공격이 지나간 길에만)의 세기는 amt.
## 오브젝트에서 고정된 거리(사거리 끝·착지 자리)에 생기는 장판은 만들지 않는다 (ELEM-10, Tower.FORM_ZONES).

var kind := "burn"
var level := 1
var radius := 55.0
var life := 4.0
var max_life := 4.0
var owner_tower: Tower
var t := 0.0
var tick := 0.0
var hp := 1.0  # 바위 벽
var dead := false
var src := ""  # 피해 출처 (Tower.src 키, 비면 직접 타격)
var amt := 1.0  # 물길 세기 (Share.k 물)
var rill_cd := {}  # 물길·핏자국: 구체 → 다시 효과를 줄 수 있는 남은 수명
var maker: Object = null  # 핏자국을 남긴 구체 (자기 핏자국은 밟지 않음)
var boost := 1.0  # 축적·삼연이 실린 장판·바위·블랙홀 (Tower.fire_boost)
var vel := Vector2.ZERO  # 움직이는 장판 (블랙홀, 물 흐름)
var dir := Vector2.RIGHT
var r0 := 0.0  # 블랙홀 처음 반지름
var shrink := 1.0  # 블랙홀이 줄어드는 정도 (자람·멀리로 덜 줄어듦)
var pull := 80.0  # 블랙홀 끌기 (초당)
var path_acc := 0.0
var eaten := 0  # 블랙홀 안에서 죽은 구체 수: 하나마다 더 작아지고 터질 때 세짐
var eaten_set := {}
var store := 0.0  # 중력 우물: 안 구체가 남에게 받은 피해에서 모은 양 (끝에 터질 때 나눠 넣음)
var absorb := 0.0  # 중력 우물: 모으는 비율
var sub := ""  # trail: puddle·burn
var pts := PackedVector2Array()  # trail: 지나온 점 (오래된 것부터)
var born := PackedFloat32Array()  # trail: 점이 생긴 시각 (t)
var pk := PackedFloat32Array()  # trail: 점마다 피해 몫 (투척 장판이 멀리 남긴 점은 약함, Tower.far_k)
var orb_k := {}  # trail: trail_orbs가 고른 구체마다 닿은 점 중 가장 센 몫
var feeding := true  # trail: 탄이 아직 날아가며 점을 더하는 중
var dps := 0.0  # trail: 안에 있는 구체에 초당 피해 (레벨 배율 전)

## 효과 줄이기(설정)에서 옅게 그리는 장판: 물길·투척 장판. 블랙홀·바위 벽은 막거나 끌어서 그대로
const SOFT := ["trail", "rill", "gore"]
## 모양이 바뀌지 않고 옅어지기만 하는 장판: 한 번 그리고 self_modulate로 옅게 (물길이 100개 가까이 깔려 매 프레임 다시 그리던 것). 바위 벽은 아예 그대로
const STILL := ["rill", "gore"]
## 구체 자신이 지나간 길에 남는 장판 (피 핏자국, Share.gore). 오브젝트와 고정 거리가 아니다 (ELEM-10)
const ORB_PATH := ["gore"]


func setup(k: String, l: int, tower: Tower) -> void:
	kind = k
	level = l
	owner_tower = tower
	match k:
		"vortex":
			radius = 100.0 + 10.0 * (l - 1); max_life = 3.0
		"rill":
			radius = 22.0; max_life = 1.0
		"gore":
			radius = 16.0; max_life = Share.GORE_T
		"rock":
			radius = Rules.t("wall_r"); max_life = 12.0; hp = Rules.t("wall_hp") * l
			if is_instance_valid(tower):
				max_life *= tower.sz()  # 크기: 벽이 오래·단단하게 (반지름만 커지면 2개에 +3%였다, 2026-11-01)
				hp *= tower.sz()
	# 공격방식이 만든 장판은 크기 강화를 받는다
	if k in ["rock", "vortex"] and is_instance_valid(tower):
		radius *= tower.sz()
	life = max_life


## 지나간 자리 장판: s = puddle(투척 장판, 공격방식). 탄이 add_pt로 점을 더한다.
func trail(s: String) -> void:
	sub = s
	radius = Tower.lob_r(level); max_life = Tower.LOB_LIFE; dps = Tower.LOB_DPS
	if is_instance_valid(owner_tower):
		radius *= owner_tower.sz()
	max_life *= MapRule.trail_k()  # 회랑: 지나간 자리 장판이 오래 남는다
	life = max_life
	position = Vector2.ZERO


func add_pt(p: Vector2, k := 1.0) -> void:
	pts.append(p)
	born.append(t)
	pk.append(k)
	life = max_life


## 지나간 자리 장판 안의 구체. 점들이 걸친 격자 칸을 한 번씩만 모아 그 안의 구체를 점과 비교한다.
func trail_orbs(main) -> Array:
	var out: Array = []
	orb_k.clear()
	if pts.is_empty():
		return out
	var g: float = main.GRID
	var pad := radius + 32.0
	var cells := {}
	for p in pts:
		for x in range(floori((p.x - pad) / g), floori((p.x + pad) / g) + 1):
			for y in range(floori((p.y - pad) / g), floori((p.y + pad) / g) + 1):
				cells[Vector2i(x, y)] = true
	for key in cells:
		var cell = main.grid.get(key)
		if not cell:
			continue
		for o in cell:
			if not is_instance_valid(o) or o.is_queued_for_deletion():
				continue
			var rr: float = radius + o.radius()
			rr *= rr
			var best := -1.0
			for i in pts.size():
				if pk[i] > best and o.position.distance_squared_to(pts[i]) < rr:
					best = pk[i]
					if best >= 1.0:
						break
			if best >= 0.0:
				out.append(o)
				orb_k[o] = best
	return out


## 중력 우물 (블랙홀 공격방식, 2026-11-01): 그 자리에 머물며 가운데로 끌고, 남의 피해를 모았다가 끝에 터진다.

func well() -> void:
	var tw := owner_tower
	r0 = radius
	pull = Rules.t("well_pull")
	max_life = Rules.t("well_life")
	life = max_life
	absorb = Rules.t("well_absorb") + Rules.t("well_absorb_lv") * (level - 1)
	tw.main.wells = tw.main.wells.filter(func(w): return is_instance_valid(w) and not w.dead)  # 웨이브 끝에 그냥 지워진 우물
	tw.main.wells.append(self)


## 블랙홀(예전 이동형): 방향 d로 날아간다. 바람(멀리)은 빠르고 멀리, 나무(자람)·바람은 덜 줄고, 어둠(그림자)은 안에 든 구체에 표식.
func launch(d: Vector2) -> void:
	dir = d
	var tw := owner_tower
	vel = d * Rules.t("vortex_speed") * Rules.t("range_vortex")  # 사거리 배율은 속도로 (지속 시간은 그대로)
	shrink = 1.0
	pull = 80.0
	r0 = radius


func _p() -> float:
	return Tower.pw(level)


## 구체들에 효과를 준다. main이 웨이브 중 매 프레임 호출한다.
func affect(orbs: Array, delta: float) -> void:
	t += delta
	tick -= delta
	for o in orbs:
		# 지나간 자리 장판(trail)은 trail_orbs가 이미 골랐다. 나머지는 모두 원 안의 구체에만 듣는다:
		# 원 밖이면 match까지 가지 않는다 (불씨·물길이 한 번에 100개 가까이 깔려 장판 계산의 절반이던 것)
		if kind != "trail":
			var rr: float = radius + o.radius()
			if o.position.distance_squared_to(position) >= rr * rr:
				continue
		match kind:
			"trail":
				# 오브젝트 하나의 띠가 겹쳐도 한 구체는 한 조각에 한 번만
				if not is_instance_valid(owner_tower) or owner_tower.trail_hit.get(o, -1) == owner_tower.main.sim_id:
					continue
				if owner_tower.trail_hit.size() > 300:
					owner_tower.trail_hit.clear()  # 죽은 구체가 쌓이지 않게 (한 조각의 중복만 막으면 됨)
				owner_tower.trail_hit[o] = owner_tower.main.sim_id
				_hit(o, dps * _p() * delta * _rapid() * orb_k.get(o, 1.0), delta * 3.0)
			"vortex":
				# 중력 우물: 가운데로 끈다 (안에서 죽은 구체마다 +10%, 최대 +50%), 가운데 둘레는 느리게
				var v: Vector2 = position - o.position
				o.push(v.limit_length(pull * (1.0 + minf(0.1 * eaten, 0.5)) * delta))
				if v.length() < Rules.t("well_core"):
					o.slow(0.5, 0.2)
				_hit(o, Rules.t("vortex_dmg") * _p() * delta, delta * 3.0)
				if o.hp <= 0.0 and not eaten_set.has(o):
					eaten_set[o] = true
					eaten += 1
			"rill":
				# 물 흐름: 지나간 길 물길을 밟은 구체에 오브젝트 효과 (같은 구체는 0.5초에 한 번)
				if is_instance_valid(owner_tower) and (not rill_cd.has(o) or life <= rill_cd[o]):
					rill_cd[o] = life - 0.5
					o.slow(Share.RILL_SLOW, Share.RILL_T)  # 효과와 따로 늘 느려짐 (제어 회복 2026-11-04)
					Share.carry(owner_tower, o, Share.WATER_F * amt, "share:water", position, 1.0 - life / maxf(max_life, 0.01))
			"gore":
				# 피 핏자국: 뒤따라 밟은 구체에 오브젝트 효과 (같은 구체는 0.5초에 한 번, 남긴 구체는 빼고)
				if o != maker and is_instance_valid(owner_tower) and (not rill_cd.has(o) or life <= rill_cd[o]):
					rill_cd[o] = life - 0.5
					Share.gore_step(owner_tower, o, amt, position, 1.0 - life / maxf(max_life, 0.01))
			"rock":
				var away: Vector2 = (o.position - position).normalized()
				o.position = position + away * (radius + o.radius())
				o.root(0.1, false)
				_hit(o, Rules.t("wall_dmg") * Tower.pw(level) * delta * _rapid(), delta * 3.0)
				hp -= Rules.t("wall_drain") * (3.0 if o.kind == Orb.Kind.BOSS else 1.0) * delta
	if kind == "rock" and hp <= 0.0:
		life = 0.0


## main이 웨이브 중 호출한다(배속이면 한 프레임에 여러 번).
func step(delta: float) -> void:
	if kind == "trail":
		t += delta
		# 다 사라진 앞쪽 점은 버린다
		var drop := 0
		while drop < pts.size() and t - born[drop] >= max_life:
			drop += 1
		if drop > 0:
			pts = pts.slice(drop)
			born = born.slice(drop)
			pk = pk.slice(drop)
		if pts.is_empty() and not feeding:
			queue_free()
		queue_redraw()
		return
	life -= delta
	if vel != Vector2.ZERO:
		position += vel * delta
		if kind == "vortex" and r0 > 0.0:
			radius = r0 * (1.0 - 0.6 * shrink * (1.0 - life / max_life) - 0.06 * eaten)
			if radius <= r0 * 0.3:
				life = 0.0  # 많이 먹으면 그 자리에서 터진다
			path_acc += vel.length() * delta
			if path_acc >= 70.0 and is_instance_valid(owner_tower):
				path_acc -= 70.0
				owner_tower.form_path(position)
	if life <= 0.0:
		_end()
		queue_free()
	if kind in STILL:
		self_modulate.a = clampf(life / max_life, 0.0, 1.0)  # 모양은 그대로, 옅어지기만: 다시 그리지 않는다
	elif kind != "rock":
		queue_redraw()


## 사라질 때: 블랙홀 붕괴, 바위 벽 무너짐.
func _end() -> void:
	if dead or not is_instance_valid(owner_tower):
		return
	dead = true
	var tw := owner_tower
	match kind:
		"vortex":
			if r0 <= 0.0:
				return
			tw.main.wells.erase(self)
			var inside: Array = []
			for o in tw.main.near(position, radius + 30.0):
				if o.hp > 0.0 and o.position.distance_to(position) < radius + o.radius():
					inside.append(o)
			# 모은 피해는 안에 있는 구체에 나눠 넣는다 (이미 배율이 다 곱해진 피해라 그대로)
			var share := store / inside.size() if not inside.is_empty() else 0.0
			for o in inside:
				tw.hit(o, Rules.t("vortex_end") * _p() * (1.0 + minf(0.1 * eaten, 0.5)) * boost)
				if share > 0.0 and o.hp > 0.0:
					_hurt(o, share)
			tw.main.burst(position, Elem.COLORS[Elem.DARK], 10, 120.0)
		"rock":
			# 무너지거나 사라질 때 둘레 구체에 돌 파편 피해 (2026-11-01 사용자 "벽 대폭 상향")
			if Rules.t("wall_break") > 0.0:
				for o in tw.main.near(position, radius + 60.0):
					if o.hp > 0.0 and o.position.distance_to(position) < radius + 40.0 + o.radius():
						_hit(o, Rules.t("wall_break") * _p(), 1.0)
				tw.main.burst(position, Elem.COLORS[Elem.EARTH], 8, 100.0)


func _draw() -> void:
	var a := 1.0 if kind in STILL else clampf(life / max_life, 0.0, 1.0)
	match kind:
		"trail":
			_draw_trail()
		"vortex":
			draw_circle(Vector2.ZERO, radius, Color(Elem.COLORS[Elem.DARK], 0.12 * a))
			for i in 4:
				var pts := PackedVector2Array()
				for s in 16:
					var r := radius * (1.0 - s / 16.0)
					var ang := -t * 4.0 + i * TAU / 4 + s * 0.35
					pts.append(Vector2(cos(ang), sin(ang)) * r)
				draw_polyline(pts, Color(Elem.COLORS[Elem.DARK], 0.8 * a), 2.0)
			draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0))
		"rill":
			_ground(Elem.COLORS[Elem.WATER], a, 0.25)
		"gore":
			# 핏자국: 작은 핏방울 셋 (테두리 없이)
			var bc: Color = Elem.COLORS[Elem.BLOOD]
			draw_circle(Vector2.ZERO, radius * 0.75, Color(bc, 0.45 * a))
			draw_circle(Vector2(radius * 0.6, radius * 0.35), radius * 0.35, Color(bc, 0.4 * a))
			draw_circle(Vector2(-radius * 0.5, -radius * 0.45), radius * 0.25, Color(bc, 0.4 * a))
		"rock":
			var pts := PackedVector2Array()
			for i in 7:
				var ang := TAU * i / 7
				pts.append(Vector2(cos(ang), sin(ang)) * radius * (0.85 + 0.15 * sin(i * 3.7)))
			draw_colored_polygon(pts, Elem.COLORS[Elem.EARTH])
			pts.append(pts[0])
			draw_polyline(pts, Color(0.35, 0.25, 0.15), 2.0)


## 지나간 자리 장판: 점을 잇는 굵은 띠 (오래된 쪽일수록 옅게). 불은 작은 불꽃, 투척 장판은 거품.
func _draw_trail() -> void:
	if pts.size() == 0:
		return
	var c: Color = owner_tower.color() if is_instance_valid(owner_tower) else Color(0.7, 0.9, 0.3)
	var fill := 0.25
	var cols := PackedColorArray()
	for i in pts.size():
		cols.append(Color(c, fill * clampf(1.0 - (t - born[i]) / max_life, 0.0, 1.0)))
	if pts.size() == 1:
		draw_circle(pts[0], radius, cols[0])
	else:
		draw_polyline_colors(pts, cols, radius * 2.0)
		draw_circle(pts[0], radius, cols[0])
		draw_circle(pts[pts.size() - 1], radius, cols[pts.size() - 1])
	for i in range(0, pts.size(), 2):
		var a := clampf(1.0 - (t - born[i]) / max_life, 0.0, 1.0)
		var f := fmod(t * 0.9 + i * 0.37, 1.0)
		var p := pts[i] + Vector2(cos(i * 2.3), sin(i * 2.3)) * radius * fmod(i * 0.61, 0.7)
		draw_arc(p, 2.0 + f * 6.0, 0, TAU, 10, Color(c.lightened(0.3), a * (1.0 - f)), 1.5)


func _ground(c: Color, a: float, fill := 0.18) -> void:
	draw_circle(Vector2.ZERO, radius, Color(c, fill * a))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(c, 0.6 * a), 2.0)


## 공격방식 장판: 주인 오브젝트의 속성 부가효과까지 붙는다.
## 속사: 벽·투척 장판은 다시 세우거나 던지는 속도만 빨라지면 상한·겹침 때문에 거의 놀아서, 닿은 피해 속도에도 건다 (2026-11-01)
func _rapid() -> float:
	return 1.0 + Rules.rapid_k * owner_tower.mf("rapid") if is_instance_valid(owner_tower) else 1.0


func _hit(o: Orb, amount: float, k: float) -> void:
	if is_instance_valid(owner_tower):
		owner_tower.tag = src
		owner_tower.in_zone = true
		owner_tower.hit(o, amount * boost, k, {}, false)
		owner_tower.in_zone = false
		owner_tower.tag = ""
	else:
		o.hurt(amount)


func _hurt(o: Orb, amount: float) -> void:
	amount = o.hurt(amount, false, owner_tower)
	o.last_rx = src.begins_with("share:")
	if is_instance_valid(owner_tower):
		owner_tower.credit(amount, src if src != "" else "hit")
