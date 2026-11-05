class_name RxCard
extends Control
## 조합 카드 (2026-11-05): 속성을 합쳐 새 조합이 생기면 오브젝트 옆에 뜨는 그림 카드.
## 머리(두 속성 그림 + 이름 + 상성 배지) · 움직이는 미리보기(효과가 특징을 따라 옮겨 가는 2초 반복) · 방향마다 한 줄
## "[효과 칩] → (특징 그림) 짧은 말". 한 번에 2장까지, 더 있으면 "+N". main이 show_for로 띄우고 _process가 자리를 잡는다.

const LIFE := 6.0  # 뜨는 시간(초). 마우스를 올린 동안은 줄지 않는다
const W := 390.0
const PREV_H := 74.0
const ROW_H := 30.0
const GOLD := Color(1, 0.8, 0.4)
const BG := Color(0.07, 0.085, 0.125, 0.96)
const ORB := Color(0.93, 0.89, 0.92)
const ORB_EDGE := Color(0.88, 0.35, 0.45)

var game
var font: Font
var tower: Tower
var rxs: Array = []  # 보여 줄 짝 (최대 2)
var extra := 0  # 못 보여 준 짝 수
var found := {}  # 이번에 도감에 처음 들어간 짝 id
var life := 0.0
var t := 0.0
var fs := 15
var _h := 0.0


func _init(main) -> void:
	game = main
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 3  # 카드 선택 막(z 1)·카드 줄(z 2) 위


## 새로 생긴 짝들(Elem.new_reactions 결과)을 tower 옆에 띄운다.
func show_for(tw: Tower, fresh: Array) -> void:
	if fresh.is_empty() or not is_instance_valid(tw):
		return
	tower = tw
	rxs = fresh.slice(0, 2)
	extra = fresh.size() - rxs.size()
	life = LIFE
	t = 0.0
	found = {}
	font = game.ui_font
	fs = 15  # ui_root가 글자 크기 설정만큼 커진다
	_resize()
	visible = true
	queue_redraw()


## 화면(폰 1.3 등)에 두 장이 들어갈 빈자리가 없으면 한 장 + "+N"으로 줄인다 (main._place_rx_card가 부름)
func shrink_to_one() -> bool:
	if rxs.size() < 2:
		return false
	extra += rxs.size() - 1
	rxs = rxs.slice(0, 1)
	_resize()
	queue_redraw()
	return true


func _resize() -> void:
	_h = 0.0
	for i in rxs.size():
		_h += block_h(rxs[i], i == 0)
	_h += 8.0 * (rxs.size() - 1) + (22.0 if extra > 0 else 0.0)
	size = Vector2(W * fs / 15.0, _h)


func hide_card() -> void:
	visible = false
	life = 0.0
	tower = null


func active() -> bool:
	return visible and life > 0.0


## 짝 하나의 높이: 머리 36 + (첫 짝만) 미리보기 + 줄들 + 상성 한 줄
func block_h(r: Dictionary, first: bool) -> float:
	var k := fs / 15.0
	var h := 38.0 * k
	if first:
		h += PREV_H * k + 6.0
	h += Elem.pair_rows(r["a"], r["b"]).size() * ROW_H * k
	if aff_note(r) != "":
		h += 22.0 * k
	return h + 6.0


## 두 속성 짝의 이름 있는 칸 이름 (Share.NAMED, 없으면 "")
static func named(a: int, b: int) -> String:
	for key in [[a, b], [b, a]]:
		if Share.NAMED.has(key):
			return Share.NAMED[key][0]
	return ""


## 상성 배지 글 ("▲ 강 · 감전", 보통이면 "")
static func aff_badge(r: Dictionary) -> String:
	var af := Elem.aff_of(r["a"], r["b"])
	if af["ids"].is_empty():
		return ""
	return ("▲ 강 · " if af["strong"] and not af["weak"] else "∿ 약 · ") + str(af["names"][0])


## 약상성은 무엇이 줄고 무엇이 생기는지 한 줄 (강상성은 배지만)
static func aff_note(r: Dictionary) -> String:
	var af := Elem.aff_of(r["a"], r["b"])
	if not af["weak"]:
		return ""
	for i in af["ids"].size():
		var d: String = af["descs"][i]
		if "대신" in d or "지만" in d:
			return d
	return ""


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(tower) or tower.is_queued_for_deletion():
		hide_card()
		return
	var hover := get_global_rect().has_point(get_global_mouse_position())
	if not hover:
		life -= delta
	if life <= 0.0:
		hide_card()
		return
	t = fmod(t + delta, 4.0)
	modulate.a = clampf(life / 0.4, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if rxs.is_empty() or font == null:
		return
	var k := fs / 15.0
	var y := 0.0
	for i in rxs.size():
		var r: Dictionary = rxs[i]
		var h := block_h(r, i == 0)
		_block(r, Rect2(0, y, size.x, h), i == 0, k)
		y += h + 8.0
	if extra > 0:
		draw_string(font, Vector2(10, y + 10 * k), "+%d개 더 (도감에서 보기)" % extra, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), Color(1, 1, 1, 0.55))
	# 남은 시간 띠
	var f := clampf(life / LIFE, 0.0, 1.0)
	draw_rect(Rect2(10, y - 8.0 + 2.0, (size.x - 20) * f, 2), Color(GOLD, 0.6))


func _block(r: Dictionary, box: Rect2, first: bool, k: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = Color(r["color"], 0.75) if first else Color(GOLD, 0.5)
	sb.set_border_width_all(2 if first else 1)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, box)
	var x := box.position.x + 12.0
	var y := box.position.y + 19.0 * k
	Glyph.elem(self, r["a"], Vector2(x + 7 * k, y), 8.0 * k)
	draw_string(font, Vector2(x + 17 * k, y + 5 * k), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Color(1, 1, 1, 0.6))
	Glyph.elem(self, r["b"], Vector2(x + 34 * k, y), 8.0 * k)
	var nm := named(r["a"], r["b"])
	var title := nm if nm != "" else "새 조합"
	draw_string(font, Vector2(x + 48 * k, y + 6 * k), title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k), GOLD)
	if found.has(r["id"]):
		var tx := x + 56 * k + font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k)).x
		draw_string(font, Vector2(tx, y + 5 * k), "도감 +", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), Color(0.6, 0.9, 1.0))
	var badge := aff_badge(r)
	if badge != "":
		var col: Color = game.AFF_COL["strong" if badge.begins_with("▲") else "weak"]
		var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k)).x + 16.0
		var br := Rect2(box.end.x - bw - 10.0, y - 10 * k, bw, 20 * k)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(col, 0.12)
		bs.border_color = col
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(int(10 * k))
		draw_style_box(bs, br)
		draw_string(font, Vector2(br.position.x + 8, br.position.y + 15 * k), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), col)
	y = box.position.y + 38.0 * k
	var rows := Elem.pair_rows(r["a"], r["b"])
	var cur := int(t / 2.0) % rows.size()  # 미리보기는 줄마다 번갈아 (2초씩)
	if first:
		var pr := Rect2(box.position.x + 10, y, box.size.x - 20, PREV_H * k)
		draw_rect(pr, Color(0, 0, 0, 0.35))
		_preview(pr, rows[cur], fmod(t, 2.0), r, k)
		y += PREV_H * k + 6.0
	for i in rows.size():
		_row(Vector2(x, y + ROW_H * k * 0.5), rows[i], k, first and i == cur and rows.size() > 1)
		y += ROW_H * k
	var note := aff_note(r)
	if note != "":
		var col2: Color = game.AFF_COL["weak"]
		draw_string(font, Vector2(x, y + 12 * k), note, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24.0, int(12 * k), col2)


## 한 줄: [효과 그림 + 효과 이름] → (특징 그림) 짧은 말. 효과가 없는 짝(특징끼리)은 [특징 그림 + 특징 이름] 짧은 말
func _row(at: Vector2, row: Dictionary, k: float, lit: bool) -> void:
	var x := at.x
	var e: int = row["eff"] if row["eff"] >= 0 else row["by"]
	var label: String = Elem.rider_name(e) if row["eff"] >= 0 else Elem.trait_name(e)
	var lfs := int(14 * k)
	var cw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 30.0 * k
	var cr := Rect2(x, at.y - 12 * k, cw, 24 * k)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(Elem.COLORS[e], 0.22 if lit else 0.1)
	cs.border_color = Color(Elem.COLORS[e], 0.9 if lit else 0.5)
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(int(12 * k))
	draw_style_box(cs, cr)
	Glyph.elem(self, e, Vector2(x + 12 * k, at.y), 6.5 * k)
	draw_string(font, Vector2(x + 22 * k, at.y + 5 * k), label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Elem.COLORS[e].lightened(0.25))
	x += cw + 8.0
	if row["eff"] >= 0:
		var ac := Color(1, 1, 1, 0.55)
		draw_line(Vector2(x, at.y), Vector2(x + 30 * k, at.y), ac, 2.0)
		draw_line(Vector2(x + 30 * k, at.y), Vector2(x + 24 * k, at.y - 5 * k), ac, 2.0)
		draw_line(Vector2(x + 30 * k, at.y), Vector2(x + 24 * k, at.y + 5 * k), ac, 2.0)
		Glyph.elem(self, row["by"], Vector2(x + 14 * k, at.y - 10 * k), 5.0 * k)
		x += 38.0 * k
	draw_string(font, Vector2(x, at.y + 5 * k), row["say"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Color(1, 1, 1, 0.92))


# ---------------- 움직이는 미리보기 ----------------

## 효과 표시: 구체 위 효과 그림 + 테두리 색
func _mark(p: Vector2, e: int, k: float, a := 1.0) -> void:
	draw_arc(p, 11 * k, 0, TAU, 20, Color(Elem.COLORS[e], a), 2.5)
	Glyph.elem(self, e, p + Vector2(0, -17 * k), 5.0 * k, Color(Elem.COLORS[e], a))


func _orb(p: Vector2, k: float, a := 1.0) -> void:
	draw_circle(p, 10 * k, Color(ORB, 0.92 * a))
	draw_arc(p, 10 * k, 0, TAU, 20, Color(ORB_EDGE, a), 1.5)


## 오브젝트 → 첫 구체 → 특징(by)의 모양으로 효과(eff)가 다른 구체에 옮겨 감. s: 0~2초
func _preview(r: Rect2, row: Dictionary, s: float, pair: Dictionary, k: float) -> void:
	var by: int = row["by"]
	var e: int = row["eff"] if row["eff"] >= 0 else by
	var cy := r.position.y + r.size.y * 0.58
	var src := Vector2(r.position.x + 20 * k, cy)
	var gap := (r.size.x - 70 * k) / 3.0
	var orbs: Array[Vector2] = []
	for i in 4:
		orbs.append(Vector2(r.position.x + 60 * k + gap * i, cy + [0.0, -12.0, 8.0, -6.0][i] * k))
	# 오브젝트
	draw_circle(src, 11 * k, Color(0.11, 0.13, 0.19))
	draw_arc(src, 11 * k, 0, TAU, 20, Color(1, 1, 1, 0.5), 1.5)
	Glyph.elem(self, pair["a"], src + Vector2(-4 * k, 0), 4.0 * k)
	Glyph.elem(self, pair["b"], src + Vector2(4 * k, 0), 4.0 * k)
	var hit := 0.35
	var got := [false, false, false, false]  # 효과가 걸린 구체
	var dead := -1
	var move := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var u := clampf((s - 0.45) / 0.9, 0.0, 1.0)  # 특징 진행 0~1
	if s < hit:
		var q := src.lerp(orbs[0], s / hit)
		draw_circle(q, 3.5 * k, Elem.COLORS[e].lightened(0.3))
		if by == Elem.WATER:
			draw_line(src, q, Color(Elem.COLORS[Elem.WATER], 0.5), 6 * k)
	else:
		got[0] = true
	match by:
		Elem.FIRE:  # 번짐: 옆 구체가 다가와 닿으면 옮겨 붙음
			move[1] = (orbs[0] + Vector2(18 * k, -6 * k) - orbs[1]) * minf(u * 1.6, 1.0)
			if u > 0.6:
				got[1] = true
				draw_arc(orbs[0].lerp(orbs[1] + move[1], 0.5), 8 * k, 0, TAU, 16, Color(Elem.COLORS[Elem.FIRE], 0.8), 2.0)
		Elem.WATER:  # 물길: 지나간 길에 물길, 밟은 구체에
			if s >= hit:
				draw_line(src, orbs[3] + Vector2(20 * k, 0), Color(Elem.COLORS[Elem.WATER], 0.35), 8 * k)
			for i in [1, 2]:
				move[i] = Vector2(0, (cy - orbs[i].y) * minf(u * 1.5, 1.0))
				if u > 0.5 + 0.2 * (i - 1):
					got[i] = true
		Elem.ELECTRIC:  # 번개: 옆 구체로 지그재그
			for i in [1, 2]:
				var f := clampf(u * 2.0 - (i - 1), 0.0, 1.0)
				if f > 0.0 and f < 1.0 or (f >= 1.0 and u < 0.9):
					_zap(orbs[i - 1], orbs[i - 1].lerp(orbs[i], f), Elem.COLORS[Elem.ELECTRIC], k)
				if f >= 1.0:
					got[i] = true
		Elem.POISON, Elem.DARK, Elem.SOUL:  # 죽으면 전염 / 끌어모음 / 혼불
			if u > 0.15:
				dead = 0
			if by == Elem.POISON and u > 0.15:
				var rr := 18 * k + 70 * k * minf((u - 0.15) * 2.0, 1.0)
				draw_arc(orbs[0], rr, 0, TAU, 32, Color(Elem.COLORS[Elem.POISON], 0.7 * (1.0 - u)), 2.5)
				if rr > orbs[0].distance_to(orbs[1]) - 10 * k:
					got[1] = true
			elif by == Elem.DARK and u > 0.15:
				for i in [1, 2]:
					move[i] = (orbs[0] + Vector2(16 * k * i, 0) - orbs[i]) * minf((u - 0.15) * 1.8, 1.0)
					if u > 0.6:
						got[i] = true
			elif by == Elem.SOUL and u > 0.15:
				var w := clampf((u - 0.15) / 0.6, 0.0, 1.0)
				var wp := orbs[0].lerp(orbs[2], w) + Vector2(0, -sin(w * PI) * 20 * k)
				draw_circle(wp, 5 * k, Color(Elem.COLORS[Elem.SOUL], 0.9))
				if w >= 1.0:
					got[2] = true
		Elem.SOUND:  # 음파: 둘레로 퍼지는 고리
			if u > 0.1:
				var rr := 80 * k * minf((u - 0.1) * 1.6, 1.0)
				draw_arc(orbs[0], rr, 0, TAU, 36, Color(Elem.COLORS[Elem.SOUND], 0.7 * (1.0 - u)), 2.5)
				if rr > orbs[0].distance_to(orbs[1]) - 10 * k:
					got[1] = true
		Elem.LIGHT:  # 치명타 관통: 일직선 빛줄기
			if u > 0.1:
				var end := orbs[0] + Vector2(r.end.x - orbs[0].x - 6 * k, 0)
				draw_line(orbs[0], end, Color(Elem.COLORS[Elem.LIGHT], 0.8 * (1.0 - u * 0.6)), 4 * k)
				for i in [1, 2, 3]:
					move[i] = Vector2(0, (cy - orbs[i].y))
				got[1] = true
				got[2] = u > 0.3
		Elem.STAR:  # 초신성: 크게 터져 모두에게
			if u > 0.2:
				var rr := 200 * k * minf((u - 0.2) * 1.5, 1.0)
				draw_arc(orbs[1], rr, 0, TAU, 48, Color(Elem.COLORS[Elem.STAR], 0.8 * (1.0 - u)), 3.0)
				for i in [1, 2, 3]:
					got[i] = rr > orbs[1].distance_to(orbs[i]) - 10 * k
		Elem.BLOOD:  # 핏자국: 맞은 구체가 지나간 길을 뒤 구체가 밟음
			move[0] = Vector2(-50 * k * u, 0)
			if s >= hit:
				draw_line(orbs[0], orbs[0] + move[0] + Vector2(60 * k, 0), Color(Elem.COLORS[Elem.BLOOD], 0.45), 6 * k)
			move[1] = Vector2(-60 * k * u, (cy - orbs[1].y) * minf(u * 2.0, 1.0))
			got[1] = u > 0.55
		Elem.ILLUSION:  # 옆 오브젝트에 비춤: 아래 오브젝트 공격에 실림
			var ally := Vector2(src.x + 30 * k, r.end.y - 12 * k)
			draw_circle(ally, 8 * k, Color(0.11, 0.13, 0.19))
			draw_arc(ally, 8 * k, 0, TAU, 16, Color(Elem.COLORS[Elem.ILLUSION], 0.7), 1.5)
			if u > 0.1:
				draw_line(src, ally, Color(Elem.COLORS[Elem.ILLUSION], 0.5), 2.0)
				var q := ally.lerp(orbs[2], clampf((u - 0.3) / 0.5, 0.0, 1.0))
				if u > 0.3 and u < 0.8:
					draw_circle(q, 3.5 * k, Elem.COLORS[Elem.ILLUSION])
				got[2] = u >= 0.8
		Elem.TIME:  # 잠시 뒤 한 번 더: 같은 구체에 두 번째 고리
			if u > 0.5:
				var f := clampf((u - 0.5) * 3.0, 0.0, 1.0)
				draw_arc(orbs[0], 11 * k + 10 * k * f, 0, TAU, 24, Color(Elem.COLORS[Elem.TIME], 1.0 - f), 2.0)
				draw_string(font, orbs[0] + Vector2(14 * k, 16 * k), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k), Elem.COLORS[Elem.TIME])
		Elem.WOOD:  # 갈수록 자람: 멀리 맞을수록 표시가 커지고 끝에서 묶음
			for i in [1, 2, 3]:
				got[i] = u > 0.25 * i
			if u > 0.85:
				_root_mark(orbs[3], k)
		Elem.WIND:  # 더 넓게: 범위 고리가 커지고 바깥으로 밀림
			if u > 0.1:
				draw_arc(orbs[0], 26 * k + 40 * k * minf(u, 1.0), 0, TAU, 32, Color(Elem.COLORS[Elem.WIND], 0.5 * (1.0 - u)), 2.0)
			move[0] = Vector2(16 * k * u, 0)
			got[1] = u > 0.55
		Elem.ICE:  # 더 오래: 효과 시간 막대가 길게 남음
			var bw := 60 * k * (1.0 - u * 0.35)
			draw_rect(Rect2(orbs[0] + Vector2(-30 * k, 16 * k), Vector2(bw, 4 * k)), Color(Elem.COLORS[Elem.ICE], 0.85))
			draw_rect(Rect2(orbs[0] + Vector2(-30 * k, 16 * k), Vector2(60 * k, 4 * k)), Color(1, 1, 1, 0.25), false, 1.0)
		Elem.EARTH:  # 묶음
			if u > 0.3:
				_root_mark(orbs[0], k)
		Elem.METAL:  # 추가 피해
			if u > 0.15 and u < 0.85:
				draw_string(font, orbs[0] + Vector2(-8 * k, -26 * k - 10 * k * u), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k), Elem.COLORS[Elem.METAL].lightened(0.3))
	for i in 4:
		if i == dead:
			_orb(orbs[i] + move[i], k, maxf(0.0, 1.0 - u * 3.0))
			continue
		_orb(orbs[i] + move[i], k)
		if got[i]:
			_mark(orbs[i] + move[i], e, k)


func _zap(a: Vector2, b: Vector2, col: Color, k: float) -> void:
	var pts := PackedVector2Array()
	var n := 6
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		if i > 0 and i < n:
			q += Vector2(0, (6.0 if i % 2 else -6.0) * k)
		pts.append(q)
	draw_polyline(pts, col, 2.5)


func _root_mark(p: Vector2, k: float) -> void:
	var c := Color(Elem.COLORS[Elem.EARTH].lightened(0.2), 0.9)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		draw_line(p + Vector2(cos(a), sin(a)) * 6 * k, p + Vector2(cos(a), sin(a)) * 15 * k, c, 2.0)
