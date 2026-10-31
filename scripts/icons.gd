class_name Icons
## 화면 정보를 글 대신 보여 주는 작은 그림들 (점수 줄 칩·진입 화살표 배지·아래 버튼·카드 아래 줄).
## c는 가운데, s는 반지름 정도의 크기.


static func draw(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	match id:
		"wave":
			for k in 3:
				var y := c.y - s * 0.55 + k * s * 0.55
				ci.draw_arc(Vector2(c.x, y + s * 0.5), s * 0.9, -PI * 0.8, -PI * 0.2, 10, col, maxf(1.5, s * 0.22))
		"score":
			_star(ci, c, s, col)
		"core":
			ci.draw_arc(c, s * 0.9, 0, TAU, 24, col, maxf(1.5, s * 0.18))
			ci.draw_circle(c, s * 0.42, col)
		"best":
			# 트로피
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.85), c + Vector2(s * 0.8, -s * 0.85), c + Vector2(s * 0.55, -s * 0.05), c + Vector2(0, s * 0.25), c + Vector2(-s * 0.55, -s * 0.05)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.12, s * 0.2), Vector2(s * 0.24, s * 0.4)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.5, s * 0.6), Vector2(s, s * 0.25)), col)
		"crowd":
			for o in [Vector2(-0.5, -0.35), Vector2(0.5, -0.35), Vector2(0, 0.5)]:
				ci.draw_circle(c + o * s, s * 0.38, col)
		"boss":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s * 0.6), c + Vector2(-s, -s * 0.5), c + Vector2(-s * 0.45, 0), c + Vector2(0, -s * 0.85), c + Vector2(s * 0.45, 0), c + Vector2(s, -s * 0.5), c + Vector2(s, s * 0.6)]), col)
		"orb":
			ci.draw_circle(c, s * 0.7, col)
			ci.draw_arc(c, s * 0.95, -PI / 2, PI, 16, Color(1, 0.3, 0.4), maxf(1.2, s * 0.15))
		"perk":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)]), col)
		"tag":
			ci.draw_rect(Rect2(c - Vector2(s * 0.75, s * 0.55), Vector2(s * 1.5, s * 1.1)), col, false, maxf(1.5, s * 0.18))
		"sel":
			for k in 4:
				var a := Vector2.from_angle(PI / 4 + k * PI / 2) * s * 0.75
				ci.draw_line(c + a, c + a * 0.45, col, maxf(1.5, s * 0.2))
		# 구체 종류 (orb.gd 모양과 같게)
		"fast":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.1, 0), c + Vector2(0, -s * 0.7), c + Vector2(-s * 0.45, 0), c + Vector2(0, s * 0.7)]), col)
		"tank":
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), col)
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), Color(0.4, 0.4, 0.45), false, 1.5)
		"shield":
			ci.draw_circle(c, s * 0.5, col)
			var hex := PackedVector2Array()
			for k in 7:
				hex.append(c + Vector2.from_angle(TAU * k / 6.0) * s * 0.95)
			ci.draw_polyline(hex, Color(0.6, 0.9, 1.0), maxf(1.5, s * 0.18))
		"split":
			ci.draw_circle(c, s * 0.8, col)
			ci.draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.7), Color(0.3, 0.3, 0.4), maxf(1.5, s * 0.2))
		"resist":
			# col = 저항 속성 색. 점선 고리
			ci.draw_circle(c, s * 0.42, Color(0.85, 0.85, 0.9))
			for k in 6:
				var a0 := TAU * k / 6.0
				ci.draw_arc(c, s * 0.9, a0, a0 + 0.6, 4, col, maxf(1.5, s * 0.22))
		"sturdy":
			ci.draw_circle(c, s * 0.5, Color(0.85, 0.85, 0.9))
			for k in 4:
				var d := Vector2.from_angle(PI / 4 + k * PI / 2)
				ci.draw_line(c + d * s * 0.6, c + d * s, col, maxf(2.0, s * 0.28))
		# 후반 구체 (orb.gd _draw_late와 같게)
		"blink":
			ci.draw_circle(c, s * 0.5, Color(0.85, 0.85, 0.9))
			for k in 6:
				var a0 := TAU * k / 6.0
				ci.draw_arc(c, s * 0.85, a0, a0 + 0.5, 4, Color(0.75, 0.6, 1.0), maxf(1.5, s * 0.2))
			ci.draw_circle(c + Vector2(s * 1.1, 0), s * 0.3, Color(0.75, 0.6, 1.0, 0.5))
		"armor":
			ci.draw_circle(c, s * 0.6, Color(0.85, 0.85, 0.9))
			ci.draw_arc(c, s * 0.75, 0, TAU, 16, Color(0.55, 0.5, 0.42), maxf(2.5, s * 0.4))
		"mender":
			ci.draw_circle(c, s * 0.8, Color(0.85, 0.85, 0.9))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.55), Vector2(s * 0.3, s * 1.1)), Color(0.3, 0.8, 0.4))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.15), Vector2(s * 1.1, s * 0.3)), Color(0.3, 0.8, 0.4))
		"phase":
			ci.draw_circle(c, s * 0.75, Color(0.85, 0.85, 0.9, 0.45))
			ci.draw_arc(c, s * 0.95, 0, TAU, 16, Color(0.6, 0.85, 1.0), maxf(1.5, s * 0.16))
		"devour":
			ci.draw_circle(c, s * 0.8, Color(0.85, 0.85, 0.9))
			ci.draw_arc(c, s * 0.9, 0.5, TAU - 0.5, 16, Color(0.85, 0.3, 0.4), maxf(2.0, s * 0.28))
		"build":
			# 이번 판 주력: 높이가 다른 막대 셋
			for k in 3:
				var h: float = s * [1.6, 1.0, 0.6][k]
				ci.draw_rect(Rect2(c + Vector2(-s * 0.9 + k * s * 0.65, s * 0.8 - h), Vector2(s * 0.45, h)), col)
		# 방해 구체 (orb.gd _draw_jam과 같게)
		"shade":
			ci.draw_circle(c, s * 0.95, Color(0.55, 0.4, 0.8, 0.35))
			ci.draw_circle(c, s * 0.55, Color(0.85, 0.85, 0.9))
			ci.draw_circle(c, s * 0.3, Color(0.2, 0.12, 0.3))
		"leech":
			ci.draw_circle(c, s * 0.8, Color(0.85, 0.85, 0.9))
			for sx in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * s * 0.5, -s * 0.2), c + Vector2(sx * s * 0.12, -s * 0.2), c + Vector2(sx * s * 0.3, s * 0.55)]), Color(0.3, 0.75, 0.4))
		"seeker":
			ci.draw_circle(c, s * 0.7, Color(0.85, 0.85, 0.9))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.15, 0), c + Vector2(s * 0.6, -s * 0.4), c + Vector2(s * 0.6, s * 0.4)]), Color(1.0, 0.35, 0.3))
		# 버튼
		"sound", "mute":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.35), c + Vector2(-s * 0.45, -s * 0.35), c + Vector2(s * 0.15, -s * 0.9), c + Vector2(s * 0.15, s * 0.9), c + Vector2(-s * 0.45, s * 0.35), c + Vector2(-s, s * 0.35)]), col)
			if id == "mute":
				var r := Color(1, 0.4, 0.45)
				ci.draw_line(c + Vector2(s * 0.4, -s * 0.45), c + Vector2(s * 1.1, s * 0.45), r, maxf(2.0, s * 0.2))
				ci.draw_line(c + Vector2(s * 0.4, s * 0.45), c + Vector2(s * 1.1, -s * 0.45), r, maxf(2.0, s * 0.2))
			else:
				ci.draw_arc(c + Vector2(s * 0.2, 0), s * 0.5, -PI / 3, PI / 3, 8, col, maxf(1.5, s * 0.16))
				ci.draw_arc(c + Vector2(s * 0.2, 0), s * 0.9, -PI / 3, PI / 3, 10, col, maxf(1.5, s * 0.16))
		"auto", "reroll":
			ci.draw_arc(c, s * 0.8, -PI * 0.15, PI * 1.55, 20, col, maxf(2.0, s * 0.2))
			var tip := c + Vector2.from_angle(-PI * 0.15) * s * 0.8
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.45, -s * 0.2), tip + Vector2(s * 0.35, -s * 0.2), tip + Vector2(0, s * 0.45)]), col)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.8), Vector2(s * 0.45, s * 1.6)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.25, -s * 0.8), Vector2(s * 0.45, s * 1.6)), col)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.85), c + Vector2(s * 0.85, 0), c + Vector2(-s * 0.6, s * 0.85)]), col)
		"speed":
			for dx in [-0.55, 0.45]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2((dx - 0.5) * s, -s * 0.75), c + Vector2((dx + 0.5) * s, 0), c + Vector2((dx - 0.5) * s, s * 0.75)]), col)
		"place_new":
			# 빈 곳에 새 오브젝트: 점선 원 + 더하기
			for k in 8:
				var a0 := TAU * k / 8.0
				ci.draw_arc(c, s * 0.85, a0, a0 + 0.45, 3, col, maxf(1.2, s * 0.15))
			ci.draw_line(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.4, 0), col, maxf(1.5, s * 0.18))
			ci.draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.4), col, maxf(1.5, s * 0.18))
		"place_on":
			# 오브젝트 위에: 원 위로 내려오는 화살
			ci.draw_arc(c + Vector2(0, s * 0.3), s * 0.6, 0, TAU, 16, col, maxf(1.2, s * 0.15))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.35, -s * 0.9), c + Vector2(s * 0.35, -s * 0.9), c + Vector2(0, -s * 0.35)]), col)


static func _star(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5) * (s if k % 2 == 0 else s * 0.45))
	ci.draw_colored_polygon(pts, col)


## 칩 하나의 폭 (아이콘 + 글).
static func chip_w(font: Font, text: String, fs: int, icon := true) -> float:
	return (8.0 + (22.0 if icon else 0.0) + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 9.0) if text != "" else 34.0


## 둥근 바탕 칩: 아이콘 + 글. r은 칩 자리.
static func chip(ci: CanvasItem, font: Font, r: Rect2, icon: String, icol: Color, text: String, tcol: Color, fs: int, bg := Color(0.02, 0.03, 0.05, 0.7), border := Color(1, 1, 1, 0.12)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	ci.draw_style_box(sb, r)
	var x := r.position.x + 8.0
	if icon != "":
		draw(ci, icon, Vector2(x + 9.0, r.get_center().y), 8.0, icol)
		x += 22.0
	if text != "":
		ci.draw_string(font, Vector2(x, r.get_center().y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
