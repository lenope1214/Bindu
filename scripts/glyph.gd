class_name Glyph
## 글 대신 쓰는 그림: 속성 14개·공격방식 16개·카드 종류·메뉴 버튼·결과 칩.
## Icons(점수 줄·배지용)와 같은 규칙: c는 가운데, s는 반지름 정도의 크기.


static func _w(s: float, k := 0.18) -> float:
	return maxf(1.4, s * k)


## 속성 그림. e는 Elem 값.
static func elem(ci: CanvasItem, e: int, c: Vector2, s: float, col := Color(-1, 0, 0)) -> void:
	var k: Color = Elem.COLORS[e] if col.r < 0 else col
	match e:
		Elem.FIRE:
			ci.draw_colored_polygon(_flame(c, s), k)
			ci.draw_colored_polygon(_flame(c + Vector2(0, s * 0.3), s * 0.5), k.lightened(0.55))
		Elem.WOOD:
			var p := PackedVector2Array()
			for i in 13:
				var t := PI * i / 12.0
				p.append(c + Vector2(-s * 0.85 + s * 1.7 * i / 12.0, -sin(t) * s * 0.55).rotated(-0.6))
			for i in range(11, 0, -1):
				var t := PI * i / 12.0
				p.append(c + Vector2(-s * 0.85 + s * 1.7 * i / 12.0, sin(t) * s * 0.55).rotated(-0.6))
			ci.draw_colored_polygon(p, k)
			ci.draw_line(c + Vector2(-s, 0).rotated(-0.6), c + Vector2(s * 0.7, 0).rotated(-0.6), k.darkened(0.45), _w(s, 0.12))
		Elem.WATER:
			var p := PackedVector2Array([c + Vector2(0, -s)])
			for i in 13:
				var t := -PI * 0.15 + PI * 1.3 * i / 12.0
				p.append(c + Vector2(0, s * 0.3) + Vector2(cos(t), sin(t)) * s * 0.62)
			ci.draw_colored_polygon(p, k)
			ci.draw_arc(c + Vector2(0, s * 0.3), s * 0.36, PI * 0.55, PI * 0.95, 6, k.lightened(0.6), _w(s, 0.12))
		Elem.ELECTRIC:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.25, -s), c + Vector2(-s * 0.6, s * 0.15), c + Vector2(-s * 0.02, s * 0.15), c + Vector2(-s * 0.25, s), c + Vector2(s * 0.6, -s * 0.15), c + Vector2(s * 0.02, -s * 0.15)]), k)
		Elem.WIND:
			for i in 3:
				var y := c.y - s * 0.55 + i * s * 0.55
				var L := s * (1.5 if i == 1 else 1.1)
				var x0 := c.x - s * 0.85 + (s * 0.3 if i == 2 else 0.0)
				ci.draw_line(Vector2(x0, y), Vector2(x0 + L, y), k, _w(s, 0.2))
				ci.draw_arc(Vector2(x0 + L, y - s * 0.2), s * 0.2, -PI / 2, PI / 2, 6, k, _w(s, 0.2))
		Elem.ICE:
			for i in 3:
				var d := Vector2.from_angle(PI / 2 + i * PI / 3) * s
				ci.draw_line(c - d, c + d, k, _w(s, 0.17))
				for sg in [-1.0, 1.0]:
					var m: Vector2 = c + d * 0.55 * sg
					var n: Vector2 = d.normalized() * s * 0.28 * sg
					ci.draw_line(m, m + n.rotated(0.8), k, _w(s, 0.12))
					ci.draw_line(m, m + n.rotated(-0.8), k, _w(s, 0.12))
		Elem.EARTH:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s * 0.7), c + Vector2(-s * 0.25, -s * 0.55), c + Vector2(s * 0.1, 0), c + Vector2(s * 0.4, -s * 0.85), c + Vector2(s, s * 0.7)]), k)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.4, -s * 0.85), c + Vector2(s * 0.62, -s * 0.47), c + Vector2(s * 0.4, -s * 0.38), c + Vector2(s * 0.2, -s * 0.5)]), k.lightened(0.5))
		Elem.DARK:
			# 초승달: 바깥 원 60°~300°(왼쪽으로) + 안쪽 원(가운데 오른쪽으로 0.55) 거꾸로
			var p := PackedVector2Array()
			var R := s * 0.92
			for i in 17:
				p.append(c + Vector2.from_angle(deg_to_rad(60.0 + 240.0 * i / 16.0)) * R)
			var ic := c + Vector2(R * 0.55, 0)
			var ir := R * 0.8675
			for i in range(1, 16):
				p.append(ic + Vector2.from_angle(deg_to_rad(266.7 - 173.4 * i / 16.0)) * ir)
			ci.draw_colored_polygon(p, k)
		Elem.LIGHT:
			ci.draw_circle(c, s * 0.45, k)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				ci.draw_line(c + d * s * 0.62, c + d * s, k, _w(s, 0.16))
		Elem.POISON:
			ci.draw_circle(c + Vector2(-s * 0.3, s * 0.3), s * 0.5, k)
			ci.draw_circle(c + Vector2(s * 0.45, -s * 0.15), s * 0.32, k)
			ci.draw_circle(c + Vector2(s * 0.05, -s * 0.7), s * 0.2, k)
			ci.draw_circle(c + Vector2(-s * 0.45, s * 0.15), s * 0.14, k.lightened(0.6))
		Elem.METAL:
			var hx := PackedVector2Array()
			for i in 6:
				hx.append(c + Vector2.from_angle(PI / 6 + TAU * i / 6.0) * s * 0.95)
			ci.draw_colored_polygon(hx, k)
			ci.draw_circle(c, s * 0.36, Color(0.06, 0.07, 0.1))
		Elem.SOUND:
			ci.draw_circle(c + Vector2(-s * 0.35, s * 0.55), s * 0.34, k)
			ci.draw_line(c + Vector2(-s * 0.05, s * 0.55), c + Vector2(-s * 0.05, -s * 0.9), k, _w(s, 0.17))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.05, -s * 0.9), c + Vector2(s * 0.7, -s * 0.5), c + Vector2(s * 0.7, -s * 0.2), c + Vector2(-s * 0.05, -s * 0.55)]), k)
		Elem.TIME:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.65, -s * 0.9), c + Vector2(s * 0.65, -s * 0.9), c + Vector2(0, 0)]), k)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(s * 0.65, s * 0.9), c + Vector2(-s * 0.65, s * 0.9)]), Color(k, 0.55))
			ci.draw_line(c + Vector2(-s * 0.8, -s * 0.95), c + Vector2(s * 0.8, -s * 0.95), k, _w(s, 0.14))
			ci.draw_line(c + Vector2(-s * 0.8, s * 0.95), c + Vector2(s * 0.8, s * 0.95), k, _w(s, 0.14))
		Elem.SOUL:
			# 꼬리가 위로 날리는 혼불 + 눈
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.55, k)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.54, s * 0.2), c + Vector2(-s * 0.2, -s * 0.5), c + Vector2(s * 0.45, -s * 1.0), c + Vector2(s * 0.54, s * 0.2)]), k)
			ci.draw_circle(c + Vector2(-s * 0.2, s * 0.3), s * 0.11, Color(0.06, 0.07, 0.1))
			ci.draw_circle(c + Vector2(s * 0.18, s * 0.3), s * 0.11, Color(0.06, 0.07, 0.1))


## 불꽃 모양 (아래 둥글고 위 뾰족)
static func _flame(c: Vector2, s: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var b := c + Vector2(0, s * 0.3)
	for i in 13:
		p.append(b + Vector2.from_angle(PI * i / 12.0) * s * 0.6)
	var tip := c + Vector2(s * 0.12, -s)
	for i in range(1, 9):
		var t := i / 8.0
		p.append((b + Vector2(-s * 0.6, 0)).lerp(c + Vector2(-s * 0.55, -s * 0.35), t).lerp((c + Vector2(-s * 0.55, -s * 0.35)).lerp(tip, t), t))
	for i in range(1, 8):
		var t := i / 8.0
		p.append(tip.lerp(c + Vector2(s * 0.55, -s * 0.2), t).lerp((c + Vector2(s * 0.55, -s * 0.2)).lerp(b + Vector2(s * 0.6, 0), t), t))
	return p


## 공격방식 그림 (오브젝트 포신 모양을 키운 것).
static func pat(ci: CanvasItem, id: String, c: Vector2, s: float, k := Color.WHITE) -> void:
	var w := _w(s)
	var a := c + Vector2(-s * 0.85, 0)
	match id:
		"shot":
			ci.draw_line(a, c + Vector2(s * 0.2, 0), Color(k, 0.5), w)
			ci.draw_circle(c + Vector2(s * 0.55, 0), s * 0.32, k)
		"spray":
			ci.draw_colored_polygon(PackedVector2Array([a, c + Vector2(s, -s * 0.7), c + Vector2(s, s * 0.7)]), Color(k, 0.85))
		"thorn":
			for dy in [-0.3, 0.3]:
				ci.draw_line(a + Vector2(0, s * dy), c + Vector2(s * 0.6, s * dy), k, w * 0.8)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.6, s * (dy - 0.15)), c + Vector2(s, s * dy), c + Vector2(s * 0.6, s * (dy + 0.15))]), k)
		"stream":
			var p := PackedVector2Array()
			for i in 13:
				p.append(a + Vector2(s * 1.8 * i / 12.0, sin(i * 0.9) * s * 0.3))
			ci.draw_polyline(p, k, w * 1.3)
		"chain":
			ci.draw_polyline(PackedVector2Array([a, c + Vector2(-s * 0.3, -s * 0.5), c + Vector2(s * 0.1, s * 0.4), c + Vector2(s * 0.5, -s * 0.35), c + Vector2(s, 0)]), k, w)
			ci.draw_circle(c + Vector2(s, 0), s * 0.16, k)
		"gust":
			for i in 3:
				ci.draw_arc(c + Vector2(-s * 0.8, 0), s * (0.6 + i * 0.4), -0.7, 0.7, 8, Color(k, 1.0 - i * 0.25), w)
		"shard":
			ci.draw_circle(c + Vector2(-s * 0.35, 0), s * 0.32, k)
			for t in [-0.7, 0.0, 0.7]:
				var d := Vector2.from_angle(t)
				ci.draw_line(c + d * s * 0.15, c + d * s * 0.85, Color(k, 0.7), w * 0.8)
		"wall":
			for r in [Rect2(-0.9, -0.6, 0.85, 0.5), Rect2(0.05, -0.6, 0.85, 0.5), Rect2(-0.45, 0.05, 0.9, 0.5)]:
				ci.draw_rect(Rect2(c + r.position * s, r.size * s), k)
		"vortex":
			var p := PackedVector2Array()
			for i in 25:
				p.append(c + Vector2.from_angle(i * 0.5) * s * (0.1 + 0.85 * i / 24.0))
			ci.draw_polyline(p, k, w)
		"laser":
			ci.draw_line(a, c + Vector2(s, 0), Color(k, 0.35), w * 3.0)
			ci.draw_line(a, c + Vector2(s, 0), k, w)
			ci.draw_circle(a, s * 0.2, k)
		"lob":
			ci.draw_arc(c + Vector2(0, s * 0.55), s * 0.85, PI * 1.1, PI * 1.9, 12, Color(k, 0.6), w * 0.8)
			ci.draw_circle(c + Vector2(s * 0.62, s * 0.05), s * 0.25, k)
			ci.draw_line(c + Vector2(-s * 0.9, s * 0.75), c + Vector2(s, s * 0.75), Color(k, 0.4), w * 0.7)
		"iron":
			ci.draw_circle(c, s * 0.62, k)
			ci.draw_circle(c + Vector2(-s * 0.2, -s * 0.2), s * 0.16, Color(1, 1, 1, 0.6))
		"sonic":
			for i in 3:
				ci.draw_arc(a, s * (0.5 + i * 0.5), -0.6, 0.6, 8, k, w)
		"clock":
			ci.draw_arc(c, s * 0.85, 0, TAU, 20, k, w)
			ci.draw_line(c, c + Vector2(0, -s * 0.6), k, w)
			ci.draw_line(c, c + Vector2(s * 0.45, 0), k, w)
		"wisp":
			ci.draw_arc(c, s * 0.75, 0, TAU, 20, Color(k, 0.35), w * 0.7)
			ci.draw_circle(c, s * 0.2, k)
			ci.draw_circle(c + Vector2.from_angle(-0.6) * s * 0.75, s * 0.24, k)
		"path":
			for i in 7:
				var t := i / 6.0
				ci.draw_circle(c + Vector2(-s * 0.85 + s * 1.7 * t, sin(t * TAU) * s * 0.45), s * 0.11, k)
		_:
			ci.draw_line(a, c + Vector2(s, 0), k, w)


## 카드 종류: elem·pat·mod·link·trig·perk·rx·cata
static func kind(ci: CanvasItem, id: String, c: Vector2, s: float, k: Color) -> void:
	var w := _w(s)
	match id:
		"elem":
			# 네 속성 꽃잎
			for i in 4:
				ci.draw_circle(c + Vector2.from_angle(PI / 4 + i * PI / 2) * s * 0.42, s * 0.36, [Elem.COLORS[Elem.FIRE], Elem.COLORS[Elem.WATER], Elem.COLORS[Elem.WOOD], Elem.COLORS[Elem.ELECTRIC]][i])
		"pat":
			ci.draw_arc(c, s * 0.75, 0, TAU, 20, k, w)
			for i in 4:
				var d := Vector2.from_angle(i * PI / 2)
				ci.draw_line(c + d * s * 0.4, c + d * s, k, w)
		"mod":
			for i in 8:
				var d := Vector2.from_angle(i * PI / 4)
				ci.draw_line(c + d * s * 0.5, c + d * s * 0.95, k, w * 1.6)
			ci.draw_arc(c, s * 0.55, 0, TAU, 16, k, w * 1.3)
		"link":
			ci.draw_arc(c + Vector2(-s * 0.35, 0), s * 0.5, 0, TAU, 16, k, w)
			ci.draw_arc(c + Vector2(s * 0.35, 0), s * 0.5, 0, TAU, 16, k, w)
		"trig":
			ci.draw_arc(c, s * 0.9, 0, TAU, 20, Color(k, 0.5), w * 0.8)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.2, -s * 0.75), c + Vector2(-s * 0.45, s * 0.1), c + Vector2(0, s * 0.1), c + Vector2(-s * 0.2, s * 0.75), c + Vector2(s * 0.45, -s * 0.1), c + Vector2(0, -s * 0.1)]), k)
		"perk":
			Icons.draw(ci, "perk", c, s, k)
		"rx":
			ci.draw_circle(c + Vector2(-s * 0.32, 0), s * 0.55, Color(1.0, 0.45, 0.3, 0.8))
			ci.draw_circle(c + Vector2(s * 0.32, 0), s * 0.55, Color(0.35, 0.6, 1.0, 0.8))
		"cata":
			for i in 8:
				var d := Vector2.from_angle(i * PI / 4)
				ci.draw_line(c + d * s * 0.2, c + d * s * (1.0 if i % 2 == 0 else 0.6), k, w)
		"ach":
			ci.draw_circle(c + Vector2(0, s * 0.25), s * 0.55, k)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.55, -s), c + Vector2(-s * 0.15, -s), c + Vector2(0, -s * 0.3), c + Vector2(-s * 0.3, -s * 0.3)]), k.darkened(0.3))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.55, -s), c + Vector2(s * 0.15, -s), c + Vector2(0, -s * 0.3), c + Vector2(s * 0.3, -s * 0.3)]), k.darkened(0.3))


## 메뉴·결과 그림
static func ui(ci: CanvasItem, id: String, c: Vector2, s: float, k: Color) -> void:
	var w := _w(s)
	match id:
		"home":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s * 0.9), c + Vector2(s, -s * 0.05)]), k)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.65, -s * 0.05), Vector2(s * 1.3, s * 0.9)), k)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.3), Vector2(s * 0.36, s * 0.55)), Color(0.06, 0.07, 0.1))
		"flag":
			ci.draw_line(c + Vector2(-s * 0.6, -s), c + Vector2(-s * 0.6, s), k, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s), c + Vector2(s * 0.8, -s * 0.6), c + Vector2(-s * 0.6, -s * 0.15)]), k)
		"power":
			ci.draw_arc(c, s * 0.8, -PI * 0.3, PI * 1.3, 18, k, w * 1.2)
			ci.draw_line(c + Vector2(0, -s), c + Vector2(0, -s * 0.1), k, w * 1.2)
		"restart":
			Icons.draw(ci, "reroll", c, s, k)
		"gear":
			kind(ci, "mod", c, s, k)
		"book":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.85, -s * 0.75), Vector2(s * 0.8, s * 1.5)), k, false, w)
			ci.draw_rect(Rect2(c + Vector2(s * 0.05, -s * 0.75), Vector2(s * 0.8, s * 1.5)), k, false, w)
		"help":
			ci.draw_arc(c, s * 0.9, 0, TAU, 20, k, w)
			ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.3, PI, TAU + PI * 0.4, 10, k, w)
			ci.draw_line(c + Vector2(s * 0.08, s * 0.05), c + Vector2(0, s * 0.3), k, w)
			ci.draw_circle(c + Vector2(0, s * 0.55), w * 0.7, k)
		"rank":
			for i in 3:
				var h: float = [0.9, 1.4, 0.6][i]
				ci.draw_rect(Rect2(c + Vector2(-s + i * s * 0.68, s * 0.8 - s * h), Vector2(s * 0.6, s * h)), k)
		"vote":
			# 투표함: 상자 + 넣는 칸 + 위로 꽂힌 종이(체크)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.9, -s * 0.05), Vector2(s * 1.8, s * 0.95)), k, false, w)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.05), c + Vector2(s * 0.4, -s * 0.05), Color(0.06, 0.07, 0.1), w * 1.6)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.95), Vector2(s * 0.9, s * 0.95)), k, false, w * 0.9)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.25, -s * 0.5), c + Vector2(-s * 0.05, -s * 0.3), c + Vector2(s * 0.28, -s * 0.72)]), k, w)
		"records":
			ci.draw_line(c + Vector2(-s, s * 0.8), c + Vector2(s, s * 0.8), k, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.85, s * 0.4), c + Vector2(-s * 0.3, -s * 0.1), c + Vector2(s * 0.1, s * 0.2), c + Vector2(s * 0.85, -s * 0.7)]), k, w)
		"multi":
			ci.draw_circle(c + Vector2(-s * 0.4, -s * 0.35), s * 0.3, k)
			ci.draw_circle(c + Vector2(s * 0.4, -s * 0.35), s * 0.3, k)
			ci.draw_arc(c + Vector2(-s * 0.4, s * 0.6), s * 0.45, PI, TAU, 10, k, w * 1.4)
			ci.draw_arc(c + Vector2(s * 0.4, s * 0.6), s * 0.45, PI, TAU, 10, k, w * 1.4)
		"notes":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.9), Vector2(s * 1.4, s * 1.8)), k, false, w)
			for i in 3:
				ci.draw_line(c + Vector2(-s * 0.4, -s * 0.4 + i * s * 0.4), c + Vector2(s * 0.4, -s * 0.4 + i * s * 0.4), k, w * 0.8)
		"eye":
			ci.draw_arc(c + Vector2(0, s * 0.55), s, -PI * 0.82, -PI * 0.18, 12, k, w)
			ci.draw_arc(c + Vector2(0, -s * 0.55), s, PI * 0.18, PI * 0.82, 12, k, w)
			ci.draw_circle(c, s * 0.3, k)
		"skip":
			Icons.draw(ci, "speed", c + Vector2(-s * 0.15, 0), s * 0.8, k)
			ci.draw_rect(Rect2(c + Vector2(s * 0.6, -s * 0.6), Vector2(s * 0.22, s * 1.2)), k)
		"kill":
			ci.draw_arc(c, s * 0.7, 0, TAU, 18, k, w)
			ci.draw_line(c + Vector2(-s, 0), c + Vector2(-s * 0.35, 0), k, w)
			ci.draw_line(c + Vector2(s, 0), c + Vector2(s * 0.35, 0), k, w)
			ci.draw_line(c + Vector2(0, -s), c + Vector2(0, -s * 0.35), k, w)
			ci.draw_line(c + Vector2(0, s), c + Vector2(0, s * 0.35), k, w)
		"combo":
			kind(ci, "trig", c, s, k)
		"tower":
			ci.draw_circle(c, s * 0.6, k)
			ci.draw_line(c, c + Vector2(s, -s * 0.35), k, w * 1.3)
		"dmg":
			# 칼
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.8, -s * 0.8), k, w * 1.4)
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.05), c + Vector2(-s * 0.05, s * 0.7), k, w * 1.4)
		"rate":
			Icons.draw(ci, "speed", c, s * 0.85, k)
		"range":
			ci.draw_arc(c, s * 0.9, 0, TAU, 20, Color(k, 0.6), w * 0.8)
			ci.draw_line(c, c + Vector2(s * 0.9, 0), k, w)
			ci.draw_circle(c, s * 0.18, k)
		"rider":
			ci.draw_line(c + Vector2(-s * 0.7, 0), c + Vector2(s * 0.7, 0), k, w * 1.3)
			ci.draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.7), k, w * 1.3)
		"trait":
			for i in 3:
				ci.draw_arc(c + Vector2(0, s * 0.2), s * (0.3 + i * 0.3), PI * 1.15, PI * 1.85, 8, Color(k, 1.0 - i * 0.25), w)
		"click", "drag":
			# 마우스: 왼쪽 단추 칠함. 끌기는 옆에 화살
			var mx := c + (Vector2(-s * 0.35, 0) if id == "drag" else Vector2.ZERO)
			var r := Rect2(mx - Vector2(s * 0.55, s * 0.8), Vector2(s * 1.1, s * 1.6))
			ci.draw_rect(r, k, false, maxf(1.2, s * 0.13))
			ci.draw_rect(Rect2(r.position, Vector2(s * 0.55, s * 0.6)), k)
			if id == "drag":
				var a := c + Vector2(s * 0.5, s * 0.1)
				ci.draw_line(a, a + Vector2(s * 0.8, 0), k, maxf(1.2, s * 0.15))
				ci.draw_colored_polygon(PackedVector2Array([a + Vector2(s * 1.05, 0), a + Vector2(s * 0.7, -s * 0.3), a + Vector2(s * 0.7, s * 0.3)]), k)
		"full":
			for i in 4:
				var d := Vector2.from_angle(PI / 4 + i * PI / 2) * s
				ci.draw_line(c + d, c + d * 0.5, k, w)
				ci.draw_line(c + d, c + Vector2(d.x, d.y * 0.5), k, w)
				ci.draw_line(c + d, c + Vector2(d.x * 0.5, d.y), k, w)
		"pf_windows":  # 네 칸 창
			var g := s * 0.12
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				ci.draw_rect(Rect2(c + Vector2(-s if q.x < 0 else g * 0.5, -s if q.y < 0 else g * 0.5), Vector2(s - g * 0.5, s - g * 0.5)), k)
		"pf_mac":  # 노트북
			ci.draw_rect(Rect2(c + Vector2(-s * 0.75, -s * 0.75), Vector2(s * 1.5, s * 1.05)), k, false, w)
			ci.draw_rect(Rect2(c + Vector2(-s, s * 0.45), Vector2(s * 2.0, s * 0.3)), k)
		"pf_ios":  # 전화기
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s), Vector2(s * 1.1, s * 2.0)), k, false, w)
			ci.draw_circle(c + Vector2(0, s * 0.7), s * 0.12, k)
		"pf_android":  # 안테나 둘 달린 반원 머리
			ci.draw_arc(c + Vector2(0, s * 0.35), s * 0.85, PI, TAU, 16, k, w)
			ci.draw_line(c + Vector2(-s * 0.85, s * 0.35), c + Vector2(s * 0.85, s * 0.35), k, w)
			ci.draw_line(c + Vector2(-s * 0.45, -s * 0.4), c + Vector2(-s * 0.75, -s * 0.9), k, w)
			ci.draw_line(c + Vector2(s * 0.45, -s * 0.4), c + Vector2(s * 0.75, -s * 0.9), k, w)
			ci.draw_circle(c + Vector2(-s * 0.35, 0), s * 0.12, k)
			ci.draw_circle(c + Vector2(s * 0.35, 0), s * 0.12, k)
		"pf_linux", "pf_unknown":  # 화면
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.8), Vector2(s * 2.0, s * 1.3)), k, false, w)
			ci.draw_line(c + Vector2(0, s * 0.5), c + Vector2(0, s * 0.85), k, w)
			ci.draw_line(c + Vector2(-s * 0.5, s * 0.9), c + Vector2(s * 0.5, s * 0.9), k, w)
		"star_off":
			Icons.draw(ci, "score", c, s, Color(k, 0.35))
		_:
			Icons.draw(ci, id, c, s, k)


## 키 모양 작은 상자 (터치 화면에선 안 그림). r의 오른쪽 위 모서리에 붙인다.
static func keycap(ci: CanvasItem, font: Font, at: Vector2, key: String, fs := 11, k := Color(1, 1, 1, 0.6)) -> void:
	var tw := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(at - Vector2(tw + 8.0, 0), Vector2(tw + 8.0, fs + 5.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = Color(k, 0.5)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(3)
	ci.draw_style_box(sb, r)
	ci.draw_string(font, r.position + Vector2(4.0, fs + 1.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, k)
