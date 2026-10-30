class_name Zone
extends Node2D
## 바닥에 남는 효과(지나간 자리 장판, 블랙홀, 지뢰, 바위 벽, 형태 성질 장판). kind로 구분한다.
## 지나간 자리 장판(trail)은 탄 하나가 지나온 점들을 들고, 점마다 life만큼 남는다. sub: puddle(투척 장판)·burn(장작)·prison(빙결 감옥).
## 블랙홀은 앞으로 날아가며 줄어든다(launch). 형태 성질 장판(ember·rill·frost·ledge·fog·tick)의 세기는 amt.

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
var amt := 1.0  # 형태 성질 세기 (Tower.tk)
var vel := Vector2.ZERO  # 움직이는 장판 (블랙홀, 물 흐름)
var dir := Vector2.RIGHT
var r0 := 0.0  # 블랙홀 처음 반지름
var shrink := 1.0  # 블랙홀이 줄어드는 정도 (자람·멀리로 덜 줄어듦)
var pull := 80.0  # 블랙홀 끌기 (초당)
var path_acc := 0.0
var eaten := 0  # 블랙홀 안에서 죽은 구체 수: 하나마다 더 작아지고 터질 때 세짐
var eaten_set := {}
var sub := ""  # trail: puddle·burn
var pts := PackedVector2Array()  # trail: 지나온 점 (오래된 것부터)
var born := PackedFloat32Array()  # trail: 점이 생긴 시각 (t)
var feeding := true  # trail: 탄이 아직 날아가며 점을 더하는 중
var dps := 0.0  # trail: 안에 있는 구체에 초당 피해 (레벨 배율 전)
var caught := {}  # trail prison: 이미 가둔 구체 (띠 하나에 한 번)

## 효과 줄이기(설정)에서 옅게 그리는 장판: 형태 성질·반응·투척 장판. 블랙홀·바위 벽·턱·독버섯은 막거나 끌어서 그대로
const SOFT := ["trail", "bog", "cloud", "boom", "ember", "rill", "frost", "fog", "tick"]
## 모양이 바뀌지 않고 옅어지기만 하는 장판: 한 번 그리고 self_modulate로 옅게 (불씨·물길이 100개 가까이 깔려 매 프레임 다시 그리던 것). 바위 벽은 아예 그대로
const STILL := ["ember", "rill", "frost", "fog", "ledge"]


func setup(k: String, l: int, tower: Tower) -> void:
	kind = k
	level = l
	owner_tower = tower
	match k:
		"vortex":
			radius = 100.0 + 10.0 * (l - 1); max_life = 3.0
		"ember", "rill":
			radius = 22.0; max_life = 1.0
		"frost":
			radius = 40.0; max_life = 1.0
		"ledge":
			radius = 20.0; max_life = 0.6
		"fog":
			radius = 50.0; max_life = 1.5
		"tick":
			radius = 35.0; max_life = 0.6
		"mine":
			radius = 14.0; max_life = 20.0
		"bog":
			radius = Tower.BOG_R + 6.0 * (l - 1); max_life = Tower.BOG_LIFE
		"cloud":
			radius = 60.0; max_life = 2.0
		"rock":
			radius = 28.0; max_life = 12.0; hp = 10.0 * l
	# 공격방식이 만든 장판은 크기 강화를 받는다
	if k in ["rock", "vortex"] and is_instance_valid(tower):
		radius *= tower.sz()
	life = max_life


## 지나간 자리 장판: s = puddle(투척 장판, 공격방식) / burn(장작 반응). 탄이 add_pt로 점을 더한다.
func trail(s: String) -> void:
	sub = s
	if s == "burn":
		radius = Tower.BURN_R + Tower.BURN_R_LV * (level - 1); max_life = Tower.BURN_LIFE; dps = Tower.BURN_DPS
	elif s == "prison":
		radius = Tower.PRISON_R + Tower.PRISON_R_LV * (level - 1); max_life = Tower.PRISON_LIFE
	else:
		radius = Tower.lob_r(level); max_life = Tower.LOB_LIFE; dps = Tower.LOB_DPS
		if is_instance_valid(owner_tower):
			radius *= owner_tower.sz()
	life = max_life
	position = Vector2.ZERO


## 반응 띠 (RxMore 물결·균열): 지나간 자리에 life초 남는다.
func trail_rx(id: String, r: float, sec: float) -> void:
	sub = "rx:" + id
	radius = r
	max_life = sec
	life = sec
	position = Vector2.ZERO


func add_pt(p: Vector2) -> void:
	pts.append(p)
	born.append(t)
	life = max_life


## 지나간 자리 장판 안의 구체. 점들이 걸친 격자 칸을 한 번씩만 모아 그 안의 구체를 점과 비교한다.
func trail_orbs(main) -> Array:
	var out: Array = []
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
			for p in pts:
				if o.position.distance_squared_to(p) < rr:
					out.append(o)
					break
	return out


## 블랙홀: 방향 d로 날아간다. 바람(멀리)은 빠르고 멀리, 나무(자람)·바람은 덜 줄고, 어둠(끌기)은 크고 세게.
func launch(d: Vector2) -> void:
	dir = d
	var tw := owner_tower
	vel = d * 140.0 * (1.0 + 0.12 * tw.tk(Elem.WIND))
	shrink = maxf(0.3, 1.0 - 0.15 * (tw.tk(Elem.WOOD) + tw.tk(Elem.WIND)))
	var dk := 1.0 + 0.15 * tw.tk(Elem.DARK)
	pull = 80.0 * dk
	radius *= dk
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
			"trail" when sub.begins_with("rx:"):
				RxMore.zone_hit(self, o, delta)
			"trail" when sub == "prison":
				# 띠에 처음 닿은 구체를 가둔다 (예전 앞쪽 원과 같은 세기)
				if caught.has(o) or not is_instance_valid(owner_tower):
					continue
				caught[o] = true
				owner_tower.in_rx = true
				_hit(o, 2.0 * _p(), 1.0)
				owner_tower.in_rx = false
				o.root(1.5)
				o.prison_t = 1.5
			"trail":
				# 오브젝트 하나의 띠가 겹쳐도 한 구체는 한 조각에 한 번만
				if not is_instance_valid(owner_tower) or owner_tower.trail_hit.get(o, -1) == owner_tower.main.sim_id:
					continue
				if owner_tower.trail_hit.size() > 300:
					owner_tower.trail_hit.clear()  # 죽은 구체가 쌓이지 않게 (한 조각의 중복만 막으면 됨)
				owner_tower.trail_hit[o] = owner_tower.main.sim_id
				if sub == "burn":
					_hurt(o, dps * _p() * delta)
					o.burn(1.0, 1.0, owner_tower, true, src)
				else:
					_hit(o, dps * _p() * delta, delta * 3.0)
			"vortex":
				# 진행 방향에 수직으로만 끌어 길 위 한 줄로 모은다 (구체를 바깥으로 끌고 가지 않게)
				var v: Vector2 = position - o.position
				v -= dir * v.dot(dir)
				o.push(v.limit_length(pull * delta))
				# 작아질수록 세진다: 처음 0.8 → 다 줄면 1.6
				var ramp := 1.0 + (1.0 - radius / r0) / 0.6 if r0 > 0.0 else 1.0
				_hit(o, 0.8 * _p() * ramp * delta, delta * 3.0)
				if o.hp <= 0.0 and not eaten_set.has(o):
					eaten_set[o] = true
					eaten += 1
			"ember":
				o.burn(0.4 * amt * _p(), 1.5, owner_tower, false, src)
			"rill":
				o.slow(0.7, 0.6)
			"frost":
				o.add_chill(0.5 * amt * delta)
			"fog":
				o.poison(0.4 * amt * _p(), 2.0, owner_tower, false, src)
			"ledge":
				var away: Vector2 = (o.position - position).normalized()
				o.position = position + away * (radius + o.radius())
				o.root(0.1, false)
			"cloud":
				o.poison(0.8 * level, 2.0, owner_tower, true, src)
			"bog":
				# 독늪: 느려지고 중독 2배, 안에서 죽으면 독 폭발·늪이 번짐
				if is_instance_valid(owner_tower):
					owner_tower.in_rx = true
					_hit(o, 1.0 * _p() * delta, delta * 3.0)
					owner_tower.in_rx = false
					o.slow(0.5, 0.3)
					o.poison(0.8 * level, 3.0, owner_tower, true, src)
					o.swamp_t = 0.3
					o.swamp_lv = level
					o.swamp_src = owner_tower
			"mine":
				if not dead:
					_explode(orbs)
					return
			"rock":
				var away: Vector2 = (o.position - position).normalized()
				o.position = position + away * (radius + o.radius())
				o.root(0.1, false)
				_hit(o, 4.0 * Tower.pw(level) * delta, delta * 3.0)
				hp -= 2.0 * delta
	if kind == "rock" and hp <= 0.0:
		life = 0.0


func _explode(orbs: Array) -> void:
	dead = true
	for o in orbs:
		if o.position.distance_to(position) < 80.0:
			_hurt(o, 3.0 * _p())
			o.poison(1.0 * level, 4.0, owner_tower, true, src)
	# 터지는 모습만 잠깐 보여 주고 사라진다
	kind = "boom"
	radius = 80.0
	life = 0.3
	max_life = 0.3
	# 터진 자리에 독 안개가 잠깐 남는다
	var cloud := Zone.new()
	cloud.setup("cloud", level, owner_tower)
	cloud.src = src
	cloud.position = position
	get_parent().add_child(cloud)


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


## 사라질 때: 블랙홀 붕괴, 째깍 폭발, 바위 벽 무너짐 → 형태 성질 "끝".
func _end() -> void:
	if dead or not is_instance_valid(owner_tower):
		return
	dead = true
	var tw := owner_tower
	match kind:
		"vortex":
			if r0 <= 0.0:
				return
			for o in tw.main.near(position, radius + 30.0):
				if o.hp > 0.0 and o.position.distance_to(position) < radius + o.radius():
					tw.hit(o, 2.0 * _p() * (1.0 + minf(0.1 * eaten, 0.5)))
					if tw.tk(Elem.METAL) > 0.0:
						o.stagger(o.speed * 0.2 * tw.tk(Elem.METAL))
			tw.main.burst(position, Elem.COLORS[Elem.DARK], 10, 120.0)
			tw.form_end(position, dir, true)
		"tick":
			tw.in_form = true
			tw.tag = src
			for o in tw.main.near(position, radius + 30.0):
				if o.hp > 0.0 and o.position.distance_to(position) < radius + o.radius():
					tw.hit(o, 0.25 * _p() * amt, 0.5)
			tw.in_form = false
			tw.tag = ""
			tw.main.burst(position, Elem.COLORS[Elem.TIME], 6, 90.0)
		"rock":
			tw.form_end(position, tw.dir, true)


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
		"ember":
			_ground(Elem.COLORS[Elem.FIRE], a, 0.3)
		"rill":
			_ground(Elem.COLORS[Elem.WATER], a, 0.25)
		"frost":
			_ground(Elem.COLORS[Elem.ICE], a, 0.25)
		"fog":
			_ground(Elem.COLORS[Elem.POISON], a, 0.15)
		"ledge":
			draw_circle(Vector2.ZERO, radius, Color(Elem.COLORS[Elem.EARTH], a))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 16, Color(0.35, 0.25, 0.15, a), 2.0)
		"tick":
			var tc: Color = Elem.COLORS[Elem.TIME]
			draw_arc(Vector2.ZERO, radius, -PI / 2, -PI / 2 + TAU * (1.0 - a), 32, Color(tc, 0.8), 3.0)
			draw_line(Vector2.ZERO, Vector2.from_angle(-PI / 2 + TAU * (1.0 - a)) * radius * 0.8, Color(tc, 0.8), 2.0)
		"mine":
			var pulse := 1.0 + 0.1 * sin(t * 6.0)
			Projectile._draw_mushroom(self, pulse)
		"bog":
			var bc := Color(0.5, 0.6, 0.2)
			_ground(bc, a, 0.3)
			for i in 5:
				var f := fmod(t * 0.7 + i * 0.37, 1.0)
				var p := Vector2(cos(i * 2.3), sin(i * 2.3)) * radius * fmod(i * 0.61, 0.8)
				draw_arc(p, 2.0 + f * 6.0, 0, TAU, 10, Color(0.7, 0.95, 0.25, a * (1.0 - f)), 1.5)
		"cloud":
			for i in 7:
				var ang := i * 0.9 + t * 0.5
				draw_circle(Vector2(cos(ang), sin(ang)) * radius * 0.5, radius * 0.45, Color(0.6, 0.85, 0.2, 0.1 * a))
		"boom":
			draw_circle(Vector2.ZERO, radius * (1.0 - a * 0.5), Color(0.8, 0.5, 0.95, 0.5 * a))
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
	var c: Color = RxMore.strip_color(sub) if sub.begins_with("rx:") else Color(1.0, 0.62, 0.1) if sub == "burn" else Color(0.45, 0.5, 0.95) if sub == "prison" else (owner_tower.color() if is_instance_valid(owner_tower) else Color(0.7, 0.9, 0.3))
	var fill := 0.22 if sub == "burn" else 0.3 if sub == "prison" else 0.25
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
		var f := fmod(t * (1.6 if sub == "burn" else 0.9) + i * 0.37, 1.0)
		var p := pts[i] + Vector2(cos(i * 2.3), sin(i * 2.3)) * radius * fmod(i * 0.61, 0.7)
		if sub == "prison":
			# 얼음 가시
			var d2 := Vector2.from_angle(i * 1.7)
			draw_line(pts[i] + d2 * radius * 0.4, pts[i] + d2 * radius * 0.9, Color(0.8, 0.85, 1.0, a), 2.5)
		elif sub.begins_with("rx:"):
			draw_circle(p, (1.0 - f) * 4.0 + 1.0, Color(c.lightened(0.35), a * (1.0 - f)))
		elif sub == "burn":
			draw_circle(p + Vector2(0, -f * 12.0), (1.0 - f) * 5.0, Color(Elem.COLORS[Elem.FIRE].lerp(Color(1, 0.9, 0.3), f), a * (1.0 - f)))
		else:
			draw_arc(p, 2.0 + f * 6.0, 0, TAU, 10, Color(c.lightened(0.3), a * (1.0 - f)), 1.5)


func _ground(c: Color, a: float, fill := 0.18) -> void:
	draw_circle(Vector2.ZERO, radius, Color(c, fill * a))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(c, 0.6 * a), 2.0)


## 공격방식 장판: 주인 오브젝트의 속성 부가효과까지 붙는다.
func _hit(o: Orb, amount: float, k: float) -> void:
	if is_instance_valid(owner_tower):
		owner_tower.tag = src
		owner_tower.hit(o, amount, k, {}, false)
		owner_tower.tag = ""
	else:
		o.hurt(amount)


func _hurt(o: Orb, amount: float) -> void:
	o.hurt(amount)
	if is_instance_valid(owner_tower):
		owner_tower.credit(amount, src if src != "" else "hit")
		if kind in ["trail", "mine", "boom"]:  # 장작 장판(trail은 불만 _hurt)·독버섯은 반응 피해
			owner_tower.rx_dealt += amount
