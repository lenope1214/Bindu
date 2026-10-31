class_name Projectile
extends Node2D
## 오브젝트가 쏘는 발사체. kind로 종류를 구분한다.
## lob(투척형)은 구체와 부딪히지 않고 max_travel만큼 날아간다. 투척 장판(blob)·장작(log)은 지나간 길에 장판(Zone.trail)을 남긴다.

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
var homing := 0.0  # 유도 강화
var prisms := {}  # 지나온 프리즘 오브젝트
var prism_els := {}  # 프리즘에서 묻은 속성
var col := Color.WHITE
var zap_t := 0.0  # 뇌우: 다음 낙뢰까지
var src := ""  # 피해 출처 (Tower.src 키, 비면 직접 타격). 쏠 때 오브젝트의 tag를 이어받는다
var form := false  # 공격방식이 쏜 탄: 형태 성질(Elem.TRAIT)이 붙는다
var ended := false  # 형태 성질 "끝" 효과를 이미 줬는지
var path_acc := 0.0  # 지나온 길 (불씨·물길 70마다)
var zone: Zone  # 지나간 자리 장판 (blob·log)
var seg_acc := 0.0  # 장판 점 사이 거리
var ghost := ""  # 혼불(ghost)이 어느 반응에서 나왔는지: plague(중독), spirit(속박), styx, ""(넋)
var chase: Orb = null  # 유도·혼불이 쫓는 구체
var chase_id := 0  # 그 구체 id (구체가 먼저 사라져도 오브젝트 쪽 수를 뺄 수 있게)
var chase_prev := Vector2.ZERO  # 쫓는 구체의 지난 위치 (속도 어림)
var chase_v := Vector2.ZERO
var chase_t := 0.0  # 이번 확인 구간에서 쫓은 시간
var chase_d0 := 0.0  # 확인 구간 시작 때 거리
var gave_up := {}  # 못 따라잡아 포기한 구체 id
var leash := 0.0  # 목줄 혼불: 오브젝트에서 이 거리 안 구체만 쫓는다 (0 = 제한 없음)
var next_hit := 0.0  # 목줄 혼불: 다음에 때릴 수 있는 시각 (t)
var route := PackedVector2Array()  # 그린 궤적: 따라갈 길 (전역 좌표)
var route_on := false  # 길 위를 가는 중 (튕기면 길을 벗어나 곧게)
var route_seg := 0  # 지금 지나는 선분
var route_acc := 0.0  # 그 선분 시작까지의 거리
var route_speed := 440.0
var rx := ""  # kind "rx": 2026-10-30에 채운 반응 발사체 (RxMore)
var look := ""  # 그 모양
var rxd := {}  # 그 반응 상태 (부메랑·커지기 등)


func setup(k: String, tower: Tower, l: int, d := Vector2.ZERO) -> void:
	kind = k
	owner_tower = tower
	level = l
	src = tower.tag
	col = tower.color()
	if d == Vector2.ZERO:
		d = tower.dir
	var p := Tower.pw(l)
	var speed := 400.0
	match k:
		"shot":
			speed = 440.0; dmg = 2.4 * p; radius = 6.0; max_travel = Tower.shot_range(tower.total_level(), tower.mf("size"))
		"path":
			speed = 440.0; dmg = 2.4 * p; radius = 6.0
		"blob":
			speed = 260.0; lob = true; max_travel = Tower.LOB_RANGE * Tower.rr_of("lob", l)
			homing = tower.mf("homing")  # 휜 길 그대로 장판이 깔린다
		"thorn":
			speed = 460.0; dmg = 0.85 * p; pierce = true
		"gust":
			speed = 300.0; dmg = 2.2 * p; radius = 34.0; pierce = true; max_travel = 420.0 * Rules.t("range_gust")
		"shard":
			speed = 380.0; dmg = 3.0 * p; radius = 7.0
		"frag":
			speed = 380.0; dmg = 1.0 * p; radius = 4.0; max_travel = 130.0
		"glob":
			speed = 300.0; dmg = 0.6 * p; radius = 7.0
		"iron":
			speed = 200.0; dmg = 1.7 * p; radius = 12.0; pierce = true
		"log":
			speed = 240.0; lob = true; max_travel = Tower.BURN_RANGE * Tower.reach(l)
		"tornado":
			speed = 110.0; dmg = 1.2 * p; radius = 26.0; continuous = true; max_travel = 380.0
		"mushroom":
			speed = 220.0; lob = true; max_travel = Tower.MUSH_RANGE * Tower.reach(l)
		"icebolt":
			speed = 300.0; lob = true; max_travel = Tower.PRISON_RANGE * Tower.reach(l)
		"storm":
			speed = 75.0; lob = true; dmg = 2.0 * p; radius = 100.0; max_travel = 360.0 * Tower.reach(l)
		"wisp":
			speed = 210.0; dmg = WISP_DMG * p; radius = 7.0; max_travel = INF  # 목줄 혼불: 거리 대신 WISP_LIFE초 (finished)
		"ghost":
			speed = 230.0; dmg = 2.4 * p; radius = 7.0; max_travel = 900.0
	if k in Pat.PROJECTILE:
		radius *= tower.sz()
		pierce_left = tower.mn("pierce")
		bounces = tower.mn("bounce")
		homing = tower.mf("homing")
		if homing > 0.0 and max_travel >= 2000.0:
			max_travel = HOMING_TRAVEL  # 끝까지 가는 관통탄(철구·관통 연사)이 유도로 전장 안을 맴돌며 끝없이 쫓지 않게
	vel = d * speed
	if tower.main:
		# 폭풍: 바람을 탄 탄은 빠르고 멀리, 거스르면 느리고 짧게
		var wk := MapRule.wind_k(d, MapRule.wind_dir(tower.main.lanes)) if MapRule.on() else 1.0
		vel *= wk
		if max_travel < 2000.0:
			max_travel *= wk
	position = tower.position + d * Tower.RADIUS
	if k in ["blob", "log", "icebolt"]:
		zone = tower.main.spawn_zone("trail", l, position, tower)
		zone.trail({"blob": "puddle", "log": "burn", "icebolt": "prison"}[k])
		zone.add_pt(position)


## 그린 궤적: 이 길을 따라가고 길 끝에서 사라진다.
func set_route(g: PackedVector2Array) -> void:
	route = g
	route_on = g.size() >= 2
	route_seg = 0
	route_acc = 0.0
	route_speed = vel.length()
	max_travel = Tower.poly_len(g)
	position = g[0]


## 공격방식 탄으로 표시하고 바람 형태 성질(멀리)을 붙인다. 그린 궤적은 길이가 정해져 있어 빨라지기만 한다.
func form_init() -> void:
	form = true
	var w := 1.0 + 0.12 * owner_tower.tk(Elem.WIND)
	vel *= w
	route_speed *= w
	if max_travel < 2000.0 and not route_on:
		max_travel *= w


## 형태 성질 "끝" 효과 (탄 하나에 한 번).
func end_form() -> void:
	if form and not ended and is_instance_valid(owner_tower):
		ended = true
		owner_tower.form_end(position, vel)


## main이 웨이브 중 호출한다(배속이면 한 프레임에 여러 번).
func step(delta: float) -> void:
	if not lob and kind != "gust" and kind != "tornado" and not (kind == "rx" and radius > 12.0):
		trail.append(position)
		if trail.size() > 7:
			trail.remove_at(0)
	if kind == "wisp" or kind == "ghost":
		_seek(delta)
	elif homing > 0 and is_instance_valid(owner_tower):
		_steer(delta)
	if route_on:
		_follow_route(delta)
	else:
		position += vel * delta
		travel += vel.length() * delta
	if zone and is_instance_valid(zone):
		seg_acc += vel.length() * delta
		if seg_acc >= zone.radius * 0.8:
			seg_acc = 0.0
			zone.add_pt(position)
	if kind == "mushroom":
		_drop_mines(vel.length() * delta)
	if form and is_instance_valid(owner_tower):
		path_acc += vel.length() * delta
		if path_acc >= 70.0:
			path_acc -= 70.0
			owner_tower.form_path(position)
	if is_instance_valid(owner_tower) and not lob and kind != "tornado":
		_check_prisms()
	t += delta
	if kind == "storm":
		_strike(delta)
	elif kind == "rx":
		RxMore.proj_step(self, delta)
	queue_redraw()


## 그린 길을 따라 route_speed만큼 간다. vel은 이번 조각에 실제로 움직인 만큼 (main의 충돌 판정이 쓴다).
func _follow_route(delta: float) -> void:
	travel = minf(travel + route_speed * delta, max_travel)
	while route_seg < route.size() - 2 and route_acc + route[route_seg].distance_to(route[route_seg + 1]) < travel:
		route_acc += route[route_seg].distance_to(route[route_seg + 1])
		route_seg += 1
	var a := route[route_seg]
	var b := route[route_seg + 1]
	var sl := a.distance_to(b)
	var np := a.lerp(b, clampf((travel - route_acc) / sl, 0.0, 1.0) if sl > 0.0 else 1.0)
	if delta > 0.0 and np != position:
		vel = (np - position) / delta
	position = np


## 뇌우: 구름 아래(radius 안) 구체 하나에 0.35초마다 낙뢰.
func _strike(delta: float) -> void:
	zap_t -= delta
	if zap_t > 0.0 or not is_instance_valid(owner_tower):
		return
	zap_t = 0.35
	var tw := owner_tower
	var cands: Array = tw.main.near(position, radius).filter(func(o): return o.hp > 0.0 and o.position.distance_to(position) < radius)
	if cands.is_empty():
		return
	var o: Orb = cands.pick_random()
	tw.in_rx = true
	tw.tag = src
	tw.hit(o, dmg)
	tw.in_rx = false
	tw.tag = ""
	var top := position + Vector2(0, -24)
	var pts := PackedVector2Array([top])
	for i in 4:
		pts.append(top.lerp(o.position, (i + 1) / 5.0) + Vector2(randf_range(-10, 10), randf_range(-4, 4)))
	pts.append(o.position)
	tw.main.bolt(pts)


## 유도·혼불이 노릴 구체 고르기 (2026-10-30):
## - 같은 오브젝트의 탄은 한 구체를 CHASE_MAX개까지만 쫓는다 (다 차 있으면 그중 가장 가까운 것)
## - CHASE_CHECK초 쫓아도 거리가 줄지 않으면 그 구체는 포기한다 (빠른 구체를 끝없이 따라가지 않게)
## - 구체가 갈 자리를 어림해 그쪽으로 튼다
const CHASE_MAX := 2
const CHASE_CHECK := 0.8
const STEER_CONE := 1.6  # 유도 탄이 노리는 앞쪽 각도(라디안). 50도로 좁히면 덜 맞혀서 그대로 두고, 둘레를 도는 것은 포기 규칙으로 막는다
const HOMING_TRAVEL := 900.0  # 화면 끝까지 가던 탄도 유도가 붙으면 혼불처럼 900까지만
const WISP_SEEK := 380.0  # 반응·영혼 넋불(ghost)이 찾는 범위
## 목줄 혼불 (2026-10-31 개편, 사용자 선택 A): 오브젝트 곁에 머물며 목줄 안 구체를 쫓아 여러 번 때린다.
## 떠 있는 수는 Tower.wisp_cap(), 사라지면 WISP_RESPAWN초 뒤 다시. 화면 끝까지 쫓아가던 예전 혼불이 배치와 상관없이 다 맞혀 너무 셌다
const WISP_DMG := 1.0  # 한 번 때릴 때 (예전 한 발 4.0)
const WISP_LIFE := 6.0
const WISP_LEASH := 300.0  # 오브젝트에서 이만큼 안의 구체만 쫓는다 (공격방식 레벨 사거리·range_wisp 배율)
const WISP_LEASH_HOMING := 0.15  # 유도 하나마다 목줄 +15%
const WISP_RESPAWN := 1.2


static func wisp_leash(h: float, reach := 1.0) -> float:
	return WISP_LEASH * (1.0 + WISP_LEASH_HOMING * h) * reach


func _exit_tree() -> void:
	_set_chase(null)
	# 지나간 자리 장판은 더 자라지 않고 남은 점이 사라질 때까지 둔다
	if zone and is_instance_valid(zone):
		zone.feeding = false


func _set_chase(o: Orb) -> void:
	var id2 := o.get_instance_id() if o != null else 0
	if id2 == chase_id:
		return
	if is_instance_valid(owner_tower):
		if chase_id != 0:
			var n: int = owner_tower.chase_n.get(chase_id, 0) - 1
			if n <= 0:
				owner_tower.chase_n.erase(chase_id)
			else:
				owner_tower.chase_n[chase_id] = n
		if id2 != 0:
			owner_tower.chase_n[id2] = owner_tower.chase_n.get(id2, 0) + 1
	chase = o
	chase_id = id2
	chase_t = 0.0
	if o != null:
		chase_prev = o.position
		chase_v = Vector2.ZERO
		chase_d0 = o.position.distance_to(position)


func _can_chase(o: Orb, r: float, cone: float) -> bool:
	if not is_instance_valid(o) or hit.has(o) or o.hp <= 0.0 or gave_up.has(o.get_instance_id()):
		return false
	if leash > 0.0:
		return o.position.distance_to(owner_tower.position) < leash
	var v: Vector2 = o.position - position
	return v.length() < r and (cone <= 0.0 or absf(vel.angle_to(v)) < cone)


## 쫓을 구체를 정해 그쪽(갈 자리)으로 최대 lim만큼 튼다. cone <= 0이면 각도 제한 없음.
func _chase(delta: float, r: float, cone: float, lim: float) -> void:
	var c: Orb = chase if is_instance_valid(chase) else null
	if c != null and not _can_chase(c, r, cone):
		c = null
	if c != null:
		chase_t += delta
		if chase_t >= CHASE_CHECK:
			var d: float = c.position.distance_to(position)
			if d > chase_d0 * 0.9:
				gave_up[c.get_instance_id()] = true
				c = null
			else:
				chase_t = 0.0
				chase_d0 = d
	if c == null:
		var best: Orb = null
		var bd := INF
		var full: Orb = null
		var fd := INF
		for o in owner_tower.main.near(owner_tower.position if leash > 0.0 else position, leash if leash > 0.0 else r):
			if not _can_chase(o, r, cone):
				continue
			var dd: float = o.position.distance_to(position)
			if owner_tower.chase_n.get(o.get_instance_id(), 0) >= CHASE_MAX:
				if dd < fd:
					fd = dd
					full = o
			elif dd < bd:
				bd = dd
				best = o
		c = best if best != null else full
		if c == null:
			_set_chase(null)
			if leash > 0.0:
				_drift(lim)
			return
	if c.get_instance_id() != chase_id:
		_set_chase(c)
	elif delta > 0.0:
		chase_v = chase_v.lerp((c.position - chase_prev) / delta, 0.3)
	chase_prev = c.position
	var sp := maxf(vel.length(), 1.0)
	var aim_at: Vector2 = c.position + chase_v * minf(c.position.distance_to(position) / sp, 1.0)
	vel = vel.rotated(clampf(vel.angle_to(aim_at - position), -lim, lim))


## 유도: 앞쪽 구체 쪽으로 방향을 튼다.
func _steer(delta: float) -> void:
	_chase(delta, 260.0, STEER_CONE, Rules.homing_k * homing * delta)


## 혼불·넋불: 구체를 쫓아간다. 목줄 혼불은 유도 강화면 더 빨리 돌고 목줄이 길어진다.
func _seek(delta: float) -> void:
	if not is_instance_valid(owner_tower):
		return
	if kind == "wisp":
		leash = wisp_leash(homing, owner_tower.rr(level))
		# 때린 뒤 다음 때릴 때까지는 막 때린 구체를 놓아 둔다 (같은 구체만 맴돌지 않게)
		for o in hit.keys():
			if not is_instance_valid(o) or t >= hit[o]:
				hit.erase(o)
	_chase(delta, WISP_SEEK, 0.0, (5.0 + 2.0 * homing) * delta)


## 목줄 혼불이 쫓을 구체가 없을 때: 오브젝트 쪽으로 돌아와 둘레를 떠돈다.
func _drift(lim: float) -> void:
	var home: Vector2 = owner_tower.position
	var to := home - position
	if to.length() > 70.0:
		vel = vel.rotated(clampf(vel.angle_to(to), -lim, lim))
	else:
		vel = vel.rotated(lim * 0.6)


## 프리즘: 다른 오브젝트의 프리즘을 지나면 그 속성이 묻고 피해가 오른다.
func _check_prisms() -> void:
	for tw in owner_tower.main.prism_towers:
		if tw != owner_tower and not prisms.has(tw) and tw.position.distance_to(position) < Tower.RADIUS + 10.0 + radius:
			prisms[tw] = true
			dmg *= 1.0 + Rules.prism_dmg * tw.prism
			for e in tw.elements:
				prism_els[e] = maxi(prism_els.get(e, 0), tw.elements[e])
			col = col.lerp(tw.color(), 0.5)
			owner_tower.main.burst(position, tw.color(), 4, 80.0)
			owner_tower.main.refract(tw.position, vel.normalized(), tw.color())
			tw.prism_flash = 1.0


## 독버섯: 굴러가며 MUSH_GAP마다 지뢰 (마지막 하나는 멈춘 자리에, main._land).
func _drop_mines(dist: float) -> void:
	seg_acc += dist
	if seg_acc < Tower.MUSH_GAP or travel >= max_travel or not is_instance_valid(owner_tower):
		return
	seg_acc -= Tower.MUSH_GAP
	var tw := owner_tower
	if tw.mines.size() >= 4 + level:
		return
	tw.tag = src
	tw.mines.append(tw.main.spawn_zone("mine", level, position, tw))
	tw.tag = ""


func finished() -> bool:
	if kind == "wisp":
		return t >= WISP_LIFE
	return travel >= max_travel


## 구체에 닿았을 때. 발사체가 사라져야 하면 true.
func on_hit(o: Orb, delta: float) -> bool:
	var tw := owner_tower if is_instance_valid(owner_tower) else null
	if tw == null:
		return _on_hit(o, delta, null)
	tw.tag = src
	var r := _on_hit(o, delta, tw)
	tw.tag = ""
	return r


func _on_hit(o: Orb, delta: float, tw: Tower) -> bool:
	if tw and (kind == "rx" or ghost in RxMore.GHOSTS):
		tw.in_rx = true
		var gone := RxMore.proj_hit(self, o, delta, tw) if kind == "rx" else RxMore.ghost_hit(self, o, tw)
		tw.in_rx = false
		return gone
	if kind == "rx":
		return false
	if kind == "wisp":
		return _wisp_hit(o, tw)
	if continuous:
		if tw:
			tw.in_rx = kind in ["log", "tornado", "mushroom"]
			tw.hit(o, dmg * delta, delta * 3.0)
			tw.in_rx = false
		else:
			o.hurt(dmg * delta)  # 주인 오브젝트가 사라진 경우
		o.burn(1.0 * level, 2.0, tw, kind in ["log", "tornado", "mushroom"])
		return false
	if hit.has(o):
		return false
	hit[o] = true
	if tw:
		tw.in_rx = kind in ["log", "tornado", "mushroom"] or ghost in ["plague", "spirit", "styx"] or src.begins_with("rx:")
		tw.hit(o, dmg, 1.0, prism_els, kind != "frag")
		tw.in_rx = false
	else:
		o.hurt(dmg)
	# 관통·튕김 탄은 처음 맞힌 자리가 "끝"
	if pierce or pierce_left > 0 or bounces > 0:
		end_form()
	match ghost:
		"plague":
			o.poison(1.5 * level, 4.0, tw, true)
		"spirit":
			o.root(0.7)
	match kind:
		"gust":
			o.push(vel.normalized().orthogonal() * 20.0 * minf(level, Rules.t("gust_push_lv")))
		"glob":
			o.poison(1.2 * level, 5.0, tw)
		"iron":
			o.stagger(30.0)
	if pierce:
		return false
	if pierce_left > 0:
		pierce_left -= 1
		if not (is_instance_valid(owner_tower) and owner_tower.on_lane()):  # 십자로 길목: 줄지 않음
			dmg *= Rules.pierce_hit  # 뚫고 나간 탄은 피해 절반
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
			dmg *= Rules.bounce_hit  # 튕긴 탄은 피해 40%
			if route_on:
				# 그린 궤적은 튕기면 길을 벗어나 곧게 날아간다
				route_on = false
				vel = vel.normalized() * route_speed
				max_travel = 400.0
			vel = (best.position - position).normalized() * vel.length()
			if homing <= 0.0 and kind != "wisp":
				travel = 0.0  # 곧게 나는 탄은 튕긴 자리에서 다시 사거리만큼. 쫓는 탄(혼불·유도)은 그대로 이어 세야 튕길 때마다 900씩 늘며 끝없이 쫓지 않는다
			return false
	end_form()
	return true


## 목줄 혼불: 사라지지 않고 공격 간격마다 한 번 때린다. 맞힌 구체는 그 간격 동안 다시 쫓지 않는다.
func _wisp_hit(o: Orb, tw: Tower) -> bool:
	if t < next_hit or hit.has(o):
		return false
	var iv := tw.attack_iv() if tw else 0.5
	next_hit = t + iv
	hit[o] = t + iv * 2.0
	if chase == o:
		_set_chase(null)
	if tw:
		tw.hit(o, dmg, 1.0, prism_els)
	else:
		o.hurt(dmg)
	return false


func _draw() -> void:
	if trail.size() > 1:
		var col := _trail_color()
		for i in trail.size() - 1:
			var a := float(i + 1) / trail.size()
			draw_line(trail[i] - position, trail[i + 1] - position, Color(col, 0.5 * a), radius * a * 1.4)
	var d := vel.normalized()
	var n := d.orthogonal()
	if not lob and kind != "gust" and kind != "rx":
		draw_circle(Vector2.ZERO, radius * 2.2, Color(_trail_color(), 0.12))
	if not prisms.is_empty():
		# 프리즘을 지난 탄: 도는 육각 테두리 (지난 프리즘 수만큼 겹)
		for j in mini(prisms.size(), 3):
			var hx := PackedVector2Array()
			var rr := radius * 1.6 + 5.0 + 4.0 * j
			for i in 7:
				hx.append(Vector2.from_angle(TAU * i / 6.0 + t * (6.0 if j % 2 == 0 else -6.0)) * rr)
			draw_polyline(hx, Color(col.lerp(Color.WHITE, 0.6), 0.85 - 0.2 * j), 1.5)
	if kind == "rx":
		RxMore.draw_proj(self)
		return
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
		"shot", "path":
			var fade := clampf((max_travel - travel) / 40.0, 0.0, 1.0)  # 사거리 끝에서 흐려짐
			draw_circle(Vector2.ZERO, radius, Color(col, col.a * fade))
			draw_circle(-d * radius * 0.3, radius * 0.45, Color(1, 1, 1, 0.7 * fade))
		"blob":
			var s := 1.0 + sin(travel / max_travel * PI) * 0.8
			draw_circle(Vector2.ZERO, 7.0 * s, col)
			draw_circle(Vector2(-2, -2) * s, 2.0 * s, Color(1, 1, 1, 0.6))
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
		"icebolt":
			var ic := Color(0.45, 0.5, 0.95)
			draw_circle(Vector2.ZERO, 9.0, ic)
			for i in 6:
				var d2 := Vector2.from_angle(TAU * i / 6.0 + t * 3.0)
				draw_line(d2 * 6.0, d2 * 13.0, Color(0.8, 0.85, 1.0), 2.0)
		"wisp", "ghost":
			var gc: Color = Elem.COLORS[Elem.SOUL] if kind == "ghost" else col
			if ghost == "plague":
				gc = Elem.COLORS[Elem.POISON]
			elif ghost == "spirit":
				gc = Elem.COLORS[Elem.WOOD].lightened(0.3)
			elif ghost in RxMore.GHOSTS:
				gc = RxMore.color(ghost if ghost != "samsara2" else "samsara")
			var fl := 1.0 + 0.15 * sin(t * 18.0)
			draw_colored_polygon(PackedVector2Array([-d * radius * 2.6 * fl, n * radius * 0.9, d * radius, -n * radius * 0.9]), Color(gc, 0.45))
			draw_circle(Vector2.ZERO, radius * fl, gc)
			draw_circle(d * radius * 0.2, radius * 0.45, Color(1, 1, 1, 0.8))
		"storm":
			var fade := clampf((max_travel - travel) / 40.0, 0.0, 1.0)
			draw_circle(Vector2(0, 30), radius * 0.9, Color(0.6, 0.65, 0.9, 0.06 * fade))
			for i in 7:
				var p := Vector2(cos(i * 0.9 + t * 0.6) * 26.0, sin(i * 1.7) * 7.0 - 24.0)
				draw_circle(p, 15.0 + 4.0 * sin(i * 2.1 + t), Color(0.55, 0.58, 0.72, 0.85 * fade))
			for i in 4:
				draw_circle(Vector2(-24 + i * 16, -30), 9.0, Color(0.75, 0.78, 0.9, 0.7 * fade))


func _trail_color() -> Color:
	match kind:
		"shot", "path", "thorn", "shard", "frag", "iron", "blob", "wisp", "rx": return col
		"ghost": return Elem.COLORS[Elem.SOUL]
		"glob": return Elem.COLORS[Elem.POISON]
	return Color.WHITE


static func _draw_mushroom(ci: CanvasItem, s: float) -> void:
	ci.draw_rect(Rect2(Vector2(-2, 0) * s, Vector2(4, 6) * s), Color(0.95, 0.9, 0.8))
	ci.draw_circle(Vector2.ZERO, 6.0 * s, Color(0.8, 0.5, 0.95))
	ci.draw_circle(Vector2(-2, -2) * s, 1.5 * s, Elem.COLORS[Elem.POISON])
