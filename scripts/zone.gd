class_name Zone
extends Node2D
## 바닥에 남는 효과(장판, 블랙홀, 지뢰, 바위 벽). kind로 구분한다.

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


func setup(k: String, l: int, tower: Tower) -> void:
	kind = k
	level = l
	owner_tower = tower
	match k:
		"burn":
			radius = 50.0 + 8.0 * (l - 1); max_life = 4.0
		"vortex":
			radius = 90.0 + 10.0 * (l - 1); max_life = 2.5
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
					o.burn(1.0, 1.0, owner_tower)
			"vortex":
				if inside:
					o.push((position - o.position).limit_length(80.0 * delta))
					_hit(o, 0.8 * _p() * delta, delta * 3.0)
			"puddle":
				if inside:
					_hit(o, 2.0 * _p() * delta, delta * 3.0)
			"cloud":
				if inside:
					o.poison(0.8 * level, 2.0, owner_tower)
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
			o.poison(1.0 * level, 4.0, owner_tower)
	# 터지는 모습만 잠깐 보여 주고 사라진다
	kind = "boom"
	radius = 80.0
	life = 0.3
	max_life = 0.3
	# 터진 자리에 독 안개가 잠깐 남는다
	var cloud := Zone.new()
	cloud.setup("cloud", level, owner_tower)
	cloud.position = position
	get_parent().add_child(cloud)


## main이 웨이브 중 호출한다(배속이면 한 프레임에 여러 번).
func step(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()


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
		owner_tower.hit(o, amount, k, {}, false)
	else:
		o.hurt(amount)


func _hurt(o: Orb, amount: float) -> void:
	o.hurt(amount)
	if is_instance_valid(owner_tower):
		owner_tower.dealt += amount
		if kind in ["burn", "mine", "boom"]:  # 장작 장판·독버섯은 반응 피해
			owner_tower.rx_dealt += amount
