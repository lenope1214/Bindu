class_name Zone
extends Node2D
## 바닥에 남는 효과(장판, 블랙홀, 지뢰, 바위 벽, 형태 성질 장판). kind로 구분한다.
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


func setup(k: String, l: int, tower: Tower) -> void:
	kind = k
	level = l
	owner_tower = tower
	match k:
		"burn":
			radius = 50.0 + 8.0 * (l - 1); max_life = 4.0
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
		"cloud":
			radius = 60.0; max_life = 2.0
		"rock":
			radius = 28.0; max_life = 12.0; hp = 10.0 * l
		"puddle":
			radius = 50.0 + 8.0 * (l - 1); max_life = 3.0
	# 공격방식이 만든 장판은 크기 강화를 받는다
	if k in ["rock", "vortex", "puddle"] and is_instance_valid(tower):
		radius *= tower.sz()
	life = max_life


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
		var dist: float = o.position.distance_to(position)
		var inside: bool = dist < radius + o.radius()
		match kind:
			"burn":
				if inside:
					_hurt(o, 2.5 * _p() * delta)
					o.burn(1.0, 1.0, owner_tower, true, src)
			"vortex":
				if inside:
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
				if inside:
					o.burn(0.4 * amt * _p(), 1.5, owner_tower, false, src)
			"rill":
				if inside:
					o.slow(0.7, 0.6)
			"frost":
				if inside:
					o.add_chill(0.5 * amt * delta)
			"fog":
				if inside:
					o.poison(0.4 * amt * _p(), 2.0, owner_tower, false, src)
			"ledge":
				if inside:
					var away: Vector2 = (o.position - position).normalized()
					o.position = position + away * (radius + o.radius())
					o.root(0.1, false)
			"puddle":
				if inside:
					_hit(o, 2.0 * _p() * delta, delta * 3.0)
			"cloud":
				if inside:
					o.poison(0.8 * level, 2.0, owner_tower, true, src)
			"mine":
				if inside and not dead:
					_explode(orbs)
					return
			"rock":
				if inside:
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
	var a := clampf(life / max_life, 0.0, 1.0)
	match kind:
		"burn":
			_ground(Color(1.0, 0.62, 0.1), a)
			for i in 14:
				var ang := i * 2.4
				var rr := radius * fmod(i * 0.37, 1.0)
				var f := fmod(t * 1.6 + i * 0.13, 1.0)
				var p := Vector2(cos(ang), sin(ang)) * rr + Vector2(0, -f * 14.0)
				draw_circle(p, (1.0 - f) * 6.0, Color(Elem.COLORS[Elem.FIRE].lerp(Color(1, 0.9, 0.3), f), a * (1.0 - f)))
		"puddle":
			var pc: Color = owner_tower.color() if is_instance_valid(owner_tower) else Color(0.7, 0.9, 0.3)
			_ground(pc, a, 0.25)
			for i in 6:
				var f := fmod(t * 0.9 + i * 0.37, 1.0)
				var p := Vector2(cos(i * 2.3), sin(i * 2.3)) * radius * fmod(i * 0.61, 0.85)
				draw_arc(p, 2.0 + f * 7.0, 0, TAU, 12, Color(pc.lightened(0.3), a * (1.0 - f)), 1.5)
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
		if kind in ["burn", "mine", "boom"]:  # 장작 장판·독버섯은 반응 피해
			owner_tower.rx_dealt += amount
