class_name Projectile
extends Node2D
## 오브젝트가 쏘는 발사체. kind로 종류를 구분한다.
## lob(투척형)은 구체와 부딪히지 않고 max_travel만큼 날아가 착지한다.

var kind := "thorn"
var owner_tower: Tower
var level := 1
var vel := Vector2.ZERO
var dmg := 1.0
var radius := 6.0
var pierce := false
var lob := false
var continuous := false  # 화염 회오리: 닿아 있는 동안 계속 피해
var hit := {}
var travel := 0.0
var max_travel := 2000.0
var t := 0.0
var trail := PackedVector2Array()  # 잔상(전역 좌표)
var pierce_left := 0  # 관통 강화로 더 뚫을 수 있는 수
var bounces := 0  # 튕김 강화
var homing := 0  # 유도 강화
var prisms := {}  # 지나온 프리즘 오브젝트
var prism_els := {}  # 프리즘에서 묻은 속성
var col := Color.WHITE


func setup(k: String, tower: Tower, l: int, d := Vector2.ZERO) -> void:
	kind = k
	owner_tower = tower
	level = l
	col = tower.color()
	if d == Vector2.ZERO:
		d = tower.dir
	var p := Tower.pw(l)
	var speed := 400.0
	match k:
		"shot":
			speed = 440.0; dmg = 2.4 * p; radius = 6.0
		"blob":
			speed = 260.0; lob = true; max_travel = 180.0 * Tower.reach(l)
		"thorn":
			speed = 460.0; dmg = 0.85 * p; pierce = true
		"gust":
			speed = 300.0; dmg = 2.2 * p; radius = 34.0; pierce = true; max_travel = 420.0
		"shard":
			speed = 380.0; dmg = 3.0 * p; radius = 7.0
		"frag":
			speed = 380.0; dmg = 1.0 * p; radius = 4.0; max_travel = 130.0
		"dark":
			speed = 170.0; lob = true; max_travel = 170.0 * Tower.reach(l)
		"glob":
			speed = 300.0; dmg = 0.6 * p; radius = 7.0
		"iron":
			speed = 200.0; dmg = 1.7 * p; radius = 12.0; pierce = true
		"log":
			speed = 260.0; lob = true; max_travel = 180.0 * Tower.reach(l)
		"tornado":
			speed = 110.0; dmg = 1.2 * p; radius = 26.0; continuous = true; max_travel = 380.0
		"mushroom":
			speed = 220.0; lob = true; max_travel = randf_range(80.0, 240.0)
	if k in Pat.PROJECTILE:
		radius *= tower.sz()
		pierce_left = tower.m("pierce")
		bounces = tower.m("bounce")
		homing = tower.m("homing")
	vel = d * speed
	position = tower.position + d * Tower.RADIUS


## main이 웨이브 중 호출한다(배속이면 한 프레임에 여러 번).
func step(delta: float) -> void:
	if not lob and kind != "gust" and kind != "tornado":
		trail.append(position)
		if trail.size() > 7:
			trail.remove_at(0)
	if homing > 0 and is_instance_valid(owner_tower):
		_steer(delta)
	position += vel * delta
	travel += vel.length() * delta
	if is_instance_valid(owner_tower) and not lob and kind != "tornado":
		_check_prisms()
	t += delta
	queue_redraw()


## 유도: 앞쪽 가까운 구체 쪽으로 방향을 튼다.
func _steer(delta: float) -> void:
	var best: Orb = null
	var bd := 260.0
	for o in owner_tower.main.near(position, bd):
		if hit.has(o) or o.hp <= 0.0:
			continue
		var v: Vector2 = o.position - position
		if v.length() < bd and absf(vel.angle_to(v)) < 1.6:
			bd = v.length()
			best = o
	if best:
		var a := clampf(vel.angle_to(best.position - position), -0.8 * homing * delta, 0.8 * homing * delta)
		vel = vel.rotated(a)


## 프리즘: 다른 오브젝트의 프리즘을 지나면 그 속성이 묻고 피해가 오른다.
func _check_prisms() -> void:
	for tw in owner_tower.main.towers.get_children():
		if tw.prism > 0 and tw != owner_tower and not prisms.has(tw) and tw.position.distance_to(position) < Tower.RADIUS + 10.0 + radius:
			prisms[tw] = true
			dmg *= 1.0 + 0.2 * tw.prism
			for e in tw.elements:
				prism_els[e] = maxi(prism_els.get(e, 0), tw.elements[e])
			col = col.lerp(tw.color(), 0.5)
			owner_tower.main.burst(position, tw.color(), 4, 80.0)


func finished() -> bool:
	return travel >= max_travel


## 구체에 닿았을 때. 발사체가 사라져야 하면 true.
func on_hit(o: Orb, delta: float) -> bool:
	var tw := owner_tower if is_instance_valid(owner_tower) else null
	if continuous:
		if tw:
			tw.in_rx = kind in ["log", "tornado", "mushroom"]
			tw.hit(o, dmg * delta, delta * 3.0)
			tw.in_rx = false
		else:
			o.hurt(dmg * delta)  # 주인 오브젝트가 사라진 경우
		o.burn(1.0 * level, 2.0)
		return false
	if hit.has(o):
		return false
	hit[o] = true
	if tw:
		tw.in_rx = kind in ["log", "tornado", "mushroom"]
		tw.hit(o, dmg, 1.0, prism_els, kind != "frag")
		tw.in_rx = false
	else:
		o.hurt(dmg)
	match kind:
		"gust":
			o.push(vel.normalized().orthogonal() * 20.0 * level)
		"glob":
			o.poison(1.2 * level, 5.0)
		"iron":
			o.push(vel.normalized() * 30.0)
	if pierce:
		return false
	if pierce_left > 0:
		pierce_left -= 1
		dmg *= 0.5  # 뚫고 나간 탄은 피해 절반
		return false
	if bounces > 0 and tw:
		# 튕김: 아직 안 맞힌 가장 가까운 구체 쪽으로
		var best: Orb = null
		var bd := 140.0
		for other in tw.main.near(position, bd):
			if not hit.has(other) and other.hp > 0.0 and other.position.distance_to(position) < bd:
				bd = other.position.distance_to(position)
				best = other
		if best:
			bounces -= 1
			dmg *= 0.4  # 튕긴 탄은 피해 40%
			vel = (best.position - position).normalized() * vel.length()
			travel = 0.0
			return false
	return true


func _draw() -> void:
	if trail.size() > 1:
		var col := _trail_color()
		for i in trail.size() - 1:
			var a := float(i + 1) / trail.size()
			draw_line(trail[i] - position, trail[i + 1] - position, Color(col, 0.5 * a), radius * a * 1.4)
	var d := vel.normalized()
	var n := d.orthogonal()
	if not lob and kind != "gust":
		draw_circle(Vector2.ZERO, radius * 2.2, Color(_trail_color(), 0.12))
	match kind:
		"thorn":
			draw_colored_polygon(PackedVector2Array([d * 12, -d * 8 - n * 4, -d * 4, -d * 8 + n * 4]), col)
		"gust":
			var c: Color = col.lerp(Color.WHITE, 0.4)
			for i in 3:
				draw_arc(-d * i * 8.0, radius - i * 6.0, d.angle() - 0.9, d.angle() + 0.9, 16, Color(c, 0.8 - i * 0.2), 3.0)
		"shard", "frag":
			var s := radius * 1.4
			draw_colored_polygon(PackedVector2Array([d * s, n * s * 0.5, -d * s, -n * s * 0.5]), col.lightened(0.3))
		"shot":
			draw_circle(Vector2.ZERO, radius, col)
			draw_circle(-d * radius * 0.3, radius * 0.45, Color(1, 1, 1, 0.7))
		"blob":
			var s := 1.0 + sin(travel / max_travel * PI) * 0.8
			draw_circle(Vector2.ZERO, 7.0 * s, col)
			draw_circle(Vector2(-2, -2) * s, 2.0 * s, Color(1, 1, 1, 0.6))
		"dark":
			draw_circle(Vector2.ZERO, 9.0, Color(0.05, 0.0, 0.1))
			draw_arc(Vector2.ZERO, 11.0, 0, TAU, 20, Elem.COLORS[Elem.DARK], 2.0)
		"glob":
			draw_circle(Vector2.ZERO, radius, Elem.COLORS[Elem.POISON])
			draw_circle(Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.6))
		"iron":
			draw_circle(Vector2.ZERO, radius, Elem.COLORS[Elem.METAL])
			draw_circle(Vector2.ZERO, radius * 0.55, col)
			draw_arc(Vector2.ZERO, radius, 0, TAU, 20, Color(0.3, 0.3, 0.35), 2.0)
		"log":
			var s := 1.0 + sin(travel / max_travel * PI) * 0.8
			var rot := Transform2D(t * 8.0, Vector2.ZERO)
			var pts := PackedVector2Array([Vector2(-10, -4) * s, Vector2(10, -4) * s, Vector2(10, 4) * s, Vector2(-10, 4) * s])
			draw_colored_polygon(rot * pts, Color(0.55, 0.33, 0.15))
			draw_circle(rot * Vector2(6 * s, 0), 3.5 * s, Elem.COLORS[Elem.FIRE])
		"tornado":
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.45, 0.1, 0.15))
			for i in 18:
				var a := t * 10.0 + i * 0.7
				var rr := radius * (0.2 + 0.045 * i)
				var y := -i * 1.5 + 12.0
				draw_circle(Vector2(cos(a) * rr, sin(a) * rr * 0.45 + y), 3.0 + i * 0.25, Color(1.0, 0.3 + 0.035 * i, 0.08, 0.85 - i * 0.03))
		"mushroom":
			var s := 1.0 + sin(travel / max_travel * PI) * 0.8
			_draw_mushroom(self, s)


func _trail_color() -> Color:
	match kind:
		"shot", "thorn", "shard", "frag", "iron", "blob": return col
		"glob": return Elem.COLORS[Elem.POISON]
	return Color.WHITE


static func _draw_mushroom(ci: CanvasItem, s: float) -> void:
	ci.draw_rect(Rect2(Vector2(-2, 0) * s, Vector2(4, 6) * s), Color(0.95, 0.9, 0.8))
	ci.draw_circle(Vector2.ZERO, 6.0 * s, Color(0.8, 0.5, 0.95))
	ci.draw_circle(Vector2(-2, -2) * s, 1.5 * s, Elem.COLORS[Elem.POISON])
