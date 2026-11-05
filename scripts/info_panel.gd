class_name InfoPanel
extends Control
## 설명창(카드 도크 오른쪽/왼쪽 위)의 그림 부분: 오브젝트 정보·카드 미리보기를 글 대신 그림·움직임·숫자 타일로.
## card_dock이 show_tower/show_card로 내용을 넣고, 높이(custom_minimum_size.y)는 넣을 때 정해진다.

const DIM := Color(1, 1, 1, 0.55)
const GOLD := Color(1, 0.9, 0.5)
const BLUE := Color(0.6, 0.9, 1.0)
const GREEN := Color(0.55, 0.9, 0.55)
const ORB := Color(0.95, 0.4, 0.5)
## 미리보기 모양 묶음
const LINE_PATS := ["shot", "thorn", "gust", "shard", "iron", "chain", "wisp"]

var game
var font: Font
var mode := ""  # "" · "tower" · "card"
var tower: Tower
var detail := false
var share := -1.0  # 이번(지난) 웨이브 피해 몫 0~1, 모르면 -1
var share_label := ""
var card := {}
var head := {}
var take := 0
var react := 0
var partners: Array = []
var t := 0.0
var _w := 300.0


func _init(main) -> void:
	game = main
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _process(delta: float) -> void:
	if not is_visible_in_tree() or mode == "":
		return
	t = fmod(t + delta, 2.0)
	queue_redraw()


func clear() -> void:
	mode = ""
	tower = null
	card = {}
	custom_minimum_size = Vector2.ZERO
	hide()


func show_tower(tw: Tower, more: bool, part: float, label: String, w: float) -> void:
	mode = "tower"
	tower = tw
	detail = more
	share = part
	share_label = label
	_w = w
	custom_minimum_size = Vector2(0, tower_h())
	show()


func show_card(c: Dictionary, hd: Dictionary, n_take: int, n_react: int, els: Array, w: float) -> void:
	mode = "card"
	card = c
	head = hd
	take = n_take
	react = n_react
	partners = els
	_w = w
	custom_minimum_size = Vector2(0, card_h())
	show()


# ---------------- 높이 ----------------

func tower_h() -> float:
	var h := 30.0 + 8.0 + 96.0 + 8.0 + 52.0 * 2 + 8.0 + 8.0  # 제목·미리보기·타일
	if Rules.t("side_iv") > 0.0:
		h += 20.0  # 보조 공격 줄
	if share >= 0.0:
		h += 22.0
	h += 22.0  # 자세히 안내 / 구분선
	if detail and is_instance_valid(tower):
		var df: Dictionary = tower.dmg_factors()
		h += 20.0 + _chain_rows(df["chain"]) * 46.0 + 4.0
		h += 20.0 * (_mul_rows(df).size()) + 8.0
		var sp: Array = tower.spd_parts()
		h += 20.0 + 20.0 * sp.size() + (34.0 if tower.attack_iv() > 0.0 else 0.0) + 8.0
		h += 22.0 * tower.reactions().size()
		if tower.extras_text() != "":
			h += 24.0
	return h


func card_h() -> float:
	var h := 30.0 + 8.0 + 90.0 + 8.0 + 50.0 + 10.0 + 22.0
	if not partners.is_empty():
		h += 24.0
	return h


# ---------------- 그리기 도구 ----------------

func _txt(p: Vector2, s: String, fs: float, col := Color("d9e5f5"), w := -1.0) -> void:
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, w, int(fs), col)


func _tw(s: String, fs: float) -> float:
	if font == null:
		font = game.ui_font
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x


func _box(r: Rect2, bg: Color, border := Color(1, 1, 1, 0.1), rad := 6.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(rad))
	draw_style_box(sb, r)


## 그림 id: "e:<속성>", "k:<카드 종류>", "i:<Icons>", "p:<공격방식>", 그 밖은 Glyph.ui
func _icon(id: String, c: Vector2, s: float, col: Color) -> void:
	if id.begins_with("e:"):
		Glyph.elem(self, int(id.substr(2)), c, s)
	elif id.begins_with("k:"):
		Glyph.kind(self, id.substr(2), c, s, col)
	elif id.begins_with("i:"):
		Icons.draw(self, id.substr(2), c, s, col)
	elif id.begins_with("p:"):
		Glyph.pat(self, id.substr(2), c, s, col)
	else:
		Glyph.ui(self, id, c, s, col)


func _chip(p: Vector2, icon: String, label: String, col: Color) -> float:
	var w := 26.0 + _tw(label, 13) + 8.0
	_box(Rect2(p, Vector2(w, 24)), Color(col, 0.12), Color(col, 0.35), 12)
	_icon(icon, p + Vector2(13, 12), 7, col)
	_txt(p + Vector2(24, 17), label, 13, col.lightened(0.3))
	return w


func _tile(r: Rect2, icon: String, icol: Color, big: String, small: String) -> void:
	_box(r, Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.07))
	_icon(icon, r.position + Vector2(18, r.size.y / 2), 8, icol)
	var fs := 21.0
	while fs > 13.0 and _tw(big, fs) > r.size.x - 42:
		fs -= 1.0
	_txt(r.position + Vector2(34, r.size.y / 2 + 2), big, fs, Color.WHITE)
	_txt(r.position + Vector2(34, r.size.y - 7), small, 11, DIM, r.size.x - 38)


# ---------------- 미리보기 ----------------

## 공격방식 미리보기: 오브젝트가 공격 간격마다 공격, 세게 맞는 거리는 진하게·그 너머는 옅게.
func _pat_preview(r: Rect2, pat: String, e: int, iv: float, far: bool, dmg: String, range_txt: String) -> void:
	_box(r, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.08))
	var col: Color = Elem.COLORS[e] if e >= 0 else Color(0.8, 0.85, 0.95)
	var o := r.position + Vector2(24, r.size.y * 0.42)
	var endx := r.end.x - 10.0
	var full := r.position.x + r.size.x * (0.62 if far else 0.86)
	# 거리 띠
	var by := r.end.y - 16.0
	draw_rect(Rect2(o.x, by, full - o.x, 5), Color(GREEN, 0.8))
	if far:
		for i in 12:
			var x0 := full + (endx - full) * i / 12.0
			draw_rect(Rect2(x0, by, (endx - full) / 12.0 + 0.5, 5), Color(GREEN, 0.8 * (1.0 - i / 12.0) + 0.1))
		_txt(Vector2(endx - _tw("끝까지", 10), by - 3), "끝까지", 10, Color(0.7, 1, 0.7, 0.5))
	var rl := range_txt
	_txt(Vector2(minf(full - _tw(rl, 10) / 2.0, endx - _tw(rl, 10) - (40 if far else 0)), by - 3), rl, 10, Color(0.7, 1, 0.7, 0.85))
	var orbs := [o.x + (full - o.x) * 0.5, minf(full + 18.0, endx - 30), endx - 18.0] if far else [o.x + (full - o.x) * 0.45, o.x + (full - o.x) * 0.8]
	var period := clampf(iv, 0.25, 1.0) if iv > 0.0 else 0.0
	match pat:
		"spray", "stream", "sonic", "clock", "vortex", "lob", "wall", "laser":
			_area_anim(o, full, endx, pat, col, period, orbs, dmg)
		_:
			_shot_anim(o, full, endx, col, period, orbs, dmg, far)
	for ox in orbs:
		draw_circle(Vector2(ox, o.y), 8, Color(ORB, 0.9))
	draw_circle(o, 12, col)
	Glyph.pat(self, pat, o, 6, Color(0.05, 0.06, 0.1))


func _shot_anim(o: Vector2, full: float, endx: float, col: Color, period: float, orbs: Array, dmg: String, far: bool) -> void:
	var p := maxf(period, 0.25)
	var spd := (endx - o.x) / 0.9
	var n := ceili(1.0 / p) + 1
	for k in n:
		var age := fmod(t + 2.0 - k * p, 2.0)
		if age > 0.9:
			continue
		var x := o.x + spd * age
		var a := 1.0 if (x < full or not far) else lerpf(1.0, 0.3, (x - full) / maxf(1.0, endx - full))
		draw_line(Vector2(x - 20, o.y), Vector2(x, o.y), Color(col, 0.5 * a), 3)
		draw_circle(Vector2(x, o.y), 4.5, Color(col.lightened(0.4), a))
		for ox in orbs:
			var dx: float = x - ox
			if dx > 0.0 and dx < 36.0:
				var up := dx / 36.0
				var weak: bool = far and ox > full
				_txt(Vector2(ox - 8, o.y - 12 - up * 14), "약" if weak else dmg, 11, Color(GOLD, (1.0 - up) * (0.6 if weak else 1.0)))


func _area_anim(o: Vector2, full: float, endx: float, pat: String, col: Color, period: float, orbs: Array, dmg: String) -> void:
	var ph := fmod(t, maxf(period, 0.5)) / maxf(period, 0.5) if period > 0.0 else fmod(t, 0.5) / 0.5
	var reach := full - o.x
	match pat:
		"spray":
			var pts := PackedVector2Array([o, o + Vector2(reach, -26), o + Vector2(reach, 26)])
			draw_colored_polygon(pts, Color(col, 0.18 + 0.12 * sin(t * 12.0)))
		"stream", "laser":
			var w := 6.0 if pat == "stream" else 3.0 + 4.0 * (1.0 - ph)
			draw_line(o, Vector2(endx if pat == "laser" else full, o.y), Color(col, 0.35 + 0.4 * (1.0 - ph)), w)
		"sonic", "clock", "vortex":
			draw_arc(o, reach * ph, -0.5, 0.5, 18, Color(col, 1.0 - ph), 3)
		"lob":
			var x := o.x + reach * 0.8 * ph
			var y := o.y - sin(ph * PI) * 26.0
			draw_circle(Vector2(x, y), 5, col)
			draw_rect(Rect2(o.x + 6, o.y + 8, (x - o.x), 4), Color(col, 0.25))
		"wall":
			draw_rect(Rect2(o.x + reach * 0.35, o.y - 22, 6, 44), Color(col, 0.6 + 0.3 * sin(t * 6.0)))
	if ph < 0.35:
		for ox in orbs:
			_txt(Vector2(ox - 8, o.y - 14 - ph * 30), dmg, 11, Color(GOLD, 1.0 - ph * 2.5))


## 속성 카드 미리보기: 탄이 구체를 맞히고 그 속성 효과가 붙는 모습 (불·독은 틱 피해, 물·얼음은 느려짐).
func _elem_preview(r: Rect2, e: int) -> void:
	_box(r, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.08))
	var col: Color = Elem.COLORS[e]
	var o := r.position + Vector2(24, r.size.y * 0.45)
	var orb0 := r.position + Vector2(r.size.x * 0.62, r.size.y * 0.45)
	var hit_t := 0.35
	var slow := e in [Elem.WATER, Elem.ICE, Elem.EARTH, Elem.TIME]
	var drift := t * 14.0 if t < hit_t else hit_t * 14.0 + (t - hit_t) * (3.0 if slow else 14.0)
	if e == Elem.ILLUSION and t >= hit_t:
		drift = hit_t * 14.0 - minf(t - hit_t, 0.8) * 8.0 + maxf(t - hit_t - 0.8, 0.0) * 14.0  # 현혹: 잠깐 되돌아 걸음
	var orb := orb0 - Vector2(drift, 0)
	if t < hit_t:
		draw_circle(Vector2(lerpf(o.x, orb.x, t / hit_t), o.y), 4, col)
	draw_circle(orb, 10, ORB)
	var on := t >= hit_t and t < 1.85
	if on:
		var since := t - hit_t
		for i in 3:
			var p := t * 7.0 + i * 2.1
			Glyph.elem(self, e, orb + Vector2((i - 1) * 8, -14 - sin(p) * 2), 4.0 + sin(p))
		if e in [Elem.FIRE, Elem.POISON, Elem.DARK]:
			for n in 4:
				var age := since - n * 0.35
				if age > 0.0 and age < 0.5:
					_txt(orb + Vector2(14, -6 - age * 30), "-", 13, Color(col.lightened(0.3), 1.0 - age * 2))
	var by := r.end.y - 16.0
	var x0 := r.position.x + 14.0
	var w := r.size.x - 28.0
	draw_rect(Rect2(x0, by, w, 5), Color(1, 1, 1, 0.08))
	if t >= hit_t:
		draw_rect(Rect2(x0, by, w * clampf((t - hit_t) / 1.5, 0, 1), 5), Color(col, 0.8))
	_txt(Vector2(x0, by - 4), "느려짐" if slow else "맞은 구체에 효과", 10, Color(col.lightened(0.3), 0.85))
	draw_circle(o, 11, Color(0.45, 0.5, 0.6))
	Glyph.pat(self, "shot", o, 5, Color(0.05, 0.06, 0.1))


## 그 밖의 카드(강화·연계·발동): 카드 그림이 오브젝트 위에서 맥박치며 들어간다.
func _kind_preview(r: Rect2) -> void:
	_box(r, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.08))
	var c := r.get_center()
	var ph := fmod(t, 1.0)
	draw_circle(c + Vector2(0, 8), 14, Color(0.45, 0.5, 0.6))
	draw_arc(c + Vector2(0, 8), 18.0 + ph * 16.0, 0, TAU, 32, Color(1, 0.85, 0.45, 1.0 - ph), 2)
	var y := lerpf(r.position.y + 14, c.y + 8, minf(ph * 2.0, 1.0))
	Glyph.kind(self, str(head.get("kind", "mod")), Vector2(c.x, y), 9, Color(1, 0.85, 0.45))


# ---------------- 내용 ----------------

func _chain_rows(chain: Array) -> int:
	var x := 0.0
	var rows := 1
	for c in chain:
		var cw := _tw(c[0], 15) + 14.0
		if x > 0.0 and x + cw > _w:
			rows += 1
			x = 0.0
		x += cw + 6.0
	return rows


func _mul_rows(df: Dictionary) -> Array:
	var rows: Array = df["mul"].duplicate()
	var prod := 1.0
	for m in rows:
		prod *= m[1]
	var rest: float = df["f"] / maxf(prod, 0.001)
	if absf(rest - 1.0) > 0.01:
		rows.append(["공명·강화·패치", rest, "k:mod"])
	return rows


func _draw() -> void:
	font = game.ui_font
	_w = size.x
	if mode == "tower" and is_instance_valid(tower):
		_draw_tower()
	elif mode == "card":
		_draw_card()


func _draw_tower() -> void:
	var tw := tower
	var x := 0.0
	var y := 0.0
	var w := size.x
	var els: Dictionary = tw.eff if not tw.eff.is_empty() else tw.elements
	# 제목: 공격방식 그림 + 이름 (+Lv) + 속성 칩
	var pname := Pat.pname(tw.pattern) + ("" if tw.plv == 1 else " Lv%d" % tw.plv)
	Glyph.pat(self, tw.pattern, Vector2(10, 14), 9, Color.WHITE)
	_txt(Vector2(26, 21), pname, 18, Color.WHITE)
	var cx := 32.0 + _tw(pname, 18) + 6.0
	var cy := 2.0
	for e in tw.order:
		var label := "%s %d" % [Elem.NAMES[e], tw.lv(e)]
		var cw := 34.0 + _tw(label, 13)
		if cx + cw > w:
			break  # 넘치는 속성은 미리보기 색으로만
		cx += _chip(Vector2(cx, cy), "e:%d" % e, label, Elem.COLORS[e]) + 4.0
	y = 38.0
	var hc := tw.hit_calc()
	var one: float = hc["one"] + hc["metal"]
	var iv := tw.attack_iv()
	var main_e: int = tw.order[0] if not tw.order.is_empty() else -1
	var rt := tw.range_text()
	var far := rt.begins_with("화면 끝까지")
	var rnum := rt
	var m := RegEx.create_from_string("\\d+").search(rt)
	if m:
		rnum = m.get_string()
	_pat_preview(Rect2(0, y, w, 96), tw.pattern, main_e, iv, far, Tower.tip_num(one), rnum)
	y += 104.0
	# 숫자 타일 2x2
	var tw2 := (w - 8.0) / 2.0
	var shots: float = hc["shots"] if tw.pattern != "wall" else 1.0
	var cont := tw.pattern in ["spray", "stream"]
	var dmg_big := Tower.tip_num(one) + (" ×%s" % Tower.tip_num(shots) if shots > 1.0 else "")
	_tile(Rect2(0, y, tw2, 52), "dmg", GOLD, dmg_big, "초당 피해 (계속)" if cont else "한 발 피해")
	var rate := ("%s번" % Tower.tip_num(1.0 / iv)) if iv > 0.0 else "계속"
	var pc := roundi((tw.pspd() - 1.0) * 100.0)
	_tile(Rect2(tw2 + 8, y, tw2, 52), "rate", BLUE, rate, "1초에" + ("  (%s%d%%)" % ["+" if pc > 0 else "", pc] if pc != 0 else ""))
	var dps := one * shots * (1.0 / iv if iv > 0.0 else 1.0)
	_tile(Rect2(0, y + 60, tw2, 52), "kill", Color(1, 0.6, 0.4), Tower.tip_num(dps), "초당 피해 (계산)")
	var ci := tw.crit_info()
	if ci[0] > 0.0:
		_tile(Rect2(tw2 + 8, y + 60, tw2, 52), "e:%d" % Elem.LIGHT, Color.WHITE, "%d%%" % roundi(ci[0] * 100.0), "치명타 ×%s" % ci[1])
	else:
		_tile(Rect2(tw2 + 8, y + 60, tw2, 52), "range", GREEN, "끝까지" if far else rnum, ("%s부터 약해짐" % rnum) if far else "사거리")
	y += 120.0
	if Rules.t("side_iv") > 0.0:
		var sl := "보조 공격 %s초마다 · %d번째는 %s" % [Tower.tip_num(Side.iv(tw)), int(Rules.t("side_big_n")), Side.big_name(Side.shape_e(tw))]
		_txt(Vector2(0, y + 12), sl, 12, Color(1, 0.85, 0.55, 0.85), w)
		y += 20.0
	if share >= 0.0:
		_txt(Vector2(0, y + 12), share_label, 12, DIM)
		var bx := _tw(share_label, 12) + 8.0
		var bw := w - bx - 40.0
		draw_rect(Rect2(bx, y + 4, bw, 8), Color(1, 1, 1, 0.06))
		draw_rect(Rect2(bx, y + 4, bw * clampf(share, 0, 1), 8), GREEN)
		_txt(Vector2(w - 34, y + 13), "%d%%" % roundi(share * 100.0), 12, Color(0.7, 1, 0.7))
		y += 22.0
	if not detail:
		if game.touch_ui:
			_txt(Vector2(0, y + 15), "[자세히]: 피해 내역·반응", 12, DIM)
		else:
			Glyph.keycap(self, font, Vector2(40, y + 3), "Shift", 11)
			_txt(Vector2(48, y + 15), "피해 내역·반응", 12, DIM)
		return
	draw_line(Vector2(0, y + 8), Vector2(w, y + 8), Color(1, 1, 1, 0.08), 1)
	y += 22.0
	# 피해 만들기: 곱셈 사슬
	var df := tw.dmg_factors()
	_txt(Vector2(0, y + 10), "피해 만들기", 12, DIM)
	y += 20.0
	var px := 0.0
	for c in df["chain"]:
		var cw := _tw(c[0], 15) + 14.0
		if px > 0.0 and px + cw > w:
			px = 0.0
			y += 46.0
		var last: bool = c[1] == ""
		_box(Rect2(px, y, cw, 26), Color(1, 0.85, 0.45, 0.18 if last else 0.07), Color(1, 0.85, 0.45, 0.3), 5)
		_txt(Vector2(px + 7, y + 19), c[0], 15, Color(1, 0.92, 0.6) if last else Color.WHITE)
		if not last:
			_txt(Vector2(px + 7, y + 39), c[1], 10, Color(1, 1, 1, 0.45), cw)
		px += cw + 6.0
	y += 50.0
	# 배율 내역: 막대 길이 = 얼마나 키웠나 (x2면 꽉 참)
	for row in _mul_rows(df):
		_bar(Vector2(0, y + 12), w, row[2], row[0], row[1], GOLD)
		y += 20.0
	y += 8.0
	# 공격 속도: 내역 막대 + 1초 동안 쏘는 순간
	_txt(Vector2(0, y + 10), ("%.2f초마다 한 번" % iv) if iv > 0.0 else "계속 뿜음", 12, Color(BLUE, 0.85))
	y += 20.0
	for sp in tw.spd_parts():
		_bar(Vector2(0, y + 12), w, "rate", sp[0], sp[1], BLUE)
		y += 20.0
	if iv > 0.0:
		_rate_strip(Vector2(6, y + 12), w - 12, iv)
		y += 34.0
	y += 8.0
	# 반응: 짝 속성 그림 + 이름
	for rx in tw.reactions():
		Glyph.elem(self, rx["a"], Vector2(8, y + 9), 7)
		_txt(Vector2(17, y + 14), "+", 13, DIM)
		Glyph.elem(self, rx["b"], Vector2(34, y + 9), 7)
		_txt(Vector2(48, y + 14), str(rx["name"]), 13, rx.get("color", Color(1, 0.75, 0.4)), w - 48)
		y += 22.0
	var ex := tw.extras_text()
	if ex != "":
		Glyph.kind(self, "mod", Vector2(8, y + 9), 7, Color(1, 0.85, 0.45))
		_txt(Vector2(22, y + 14), ex, 12, Color(1, 0.85, 0.45), w - 22)


func _bar(p: Vector2, w: float, icon: String, label: String, val: float, col: Color) -> void:
	_icon(icon, p + Vector2(7, -4), 6, col)
	_txt(p + Vector2(18, 0), label, 12, Color(1, 1, 1, 0.7), 96)
	var bx := p.x + 116.0
	var bw := w - 116.0 - 48.0
	draw_rect(Rect2(bx, p.y - 9, bw, 7), Color(1, 1, 1, 0.06))
	var k := log(maxf(val, 0.01)) / log(2.0)
	if k >= 0.0:
		draw_rect(Rect2(bx, p.y - 9, bw * clampf(k, 0.03, 1.0), 7), Color(col, 0.85))
	else:
		draw_rect(Rect2(bx, p.y - 9, bw * clampf(-k, 0.03, 1.0), 7), Color(1, 0.5, 0.45, 0.85))
	_txt(Vector2(p.x + w - 44, p.y), "×%.2f" % val, 12, col.lightened(0.2))


## 1초 동안 공격하는 순간: 점이 지나가며 빛난다.
func _rate_strip(p: Vector2, w: float, iv: float) -> void:
	draw_line(p, p + Vector2(w, 0), Color(1, 1, 1, 0.15), 2)
	for i in 3:
		var x := p.x + w * i / 2.0
		draw_line(Vector2(x, p.y - 3), Vector2(x, p.y + 3), Color(1, 1, 1, 0.25), 1)
		_txt(Vector2(x - (10 if i == 2 else 4), p.y + 16), ["0", "0.5", "1초"][i], 9, Color(1, 1, 1, 0.4))
	var n := mini(floori(1.0 / iv), 20)
	var now := fmod(t, 1.0)
	for i in n:
		var at := (i + 0.5) * iv
		if at > 1.0:
			break
		var lit := absf(now - at) < 0.06
		draw_circle(Vector2(p.x + w * at, p.y), 6.0 if lit else 4.0, Color(BLUE, 1.0 if lit else 0.55))
	draw_circle(Vector2(p.x + w * now, p.y), 2, Color.WHITE)


func _draw_card() -> void:
	var w := size.x
	var col := Color(1, 0.85, 0.45)
	if head.has("e"):
		col = Elem.COLORS[head["e"]]
		Glyph.elem(self, head["e"], Vector2(10, 14), 9)
	elif head.has("pat"):
		col = Color.WHITE
		Glyph.pat(self, head["pat"], Vector2(10, 14), 9, col)
	else:
		Glyph.kind(self, str(head.get("kind", "mod")), Vector2(10, 14), 9, col)
	var name: String = head.get("name", "")
	_txt(Vector2(26, 21), name, 18, col.lightened(0.2), w - 70)
	if head.has("lv"):
		var bx := 32.0 + _tw(name, 18)
		_box(Rect2(bx, 3, 34, 20), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.2), 4)
		_txt(Vector2(bx + 6, 18), str(head["lv"]), 12)
	var y := 38.0
	var pr := Rect2(0, y, w, 90)
	match str(card.get("type", "")):
		"elem":
			_elem_preview(pr, card["e"])
		"pat":
			_pat_preview(pr, card["id"], -1, Tower.BASE_IV.get(card["id"], 0.0), card["id"] in Tower.FAR_PATS, "", "")
		_:
			_kind_preview(pr)
	y += 98.0
	var tw2 := (w - 8.0) / 2.0
	_tile(Rect2(0, y, tw2, 50), "i:place_on", Color(0.6, 0.85, 0.9), "%d곳" % take, "넣을 수 있음")
	_tile(Rect2(tw2 + 8, y, tw2, 50), "k:rx", Color(1, 0.75, 0.4), "%d곳" % react, "새 반응")
	y += 60.0
	# 고리 범례
	draw_arc(Vector2(9, y + 8), 7, 0, TAU, 20, Color(0.6, 0.85, 0.9), 1.5)
	_txt(Vector2(22, y + 13), "넣을 곳", 12, DIM)
	var lx := 34.0 + _tw("넣을 곳", 12)
	draw_arc(Vector2(lx + 10, y + 8), 7, 0, TAU, 20, Color(1, 0.75, 0.4), 3)
	draw_arc(Vector2(lx + 10, y + 8), 10, 0, TAU, 20, Color(1, 0.75, 0.4, 0.35), 3)
	_txt(Vector2(lx + 24, y + 13), "새 반응", 12, DIM)
	y += 22.0
	if not partners.is_empty():
		_txt(Vector2(0, y + 14), "반응 짝", 12, DIM)
		var px := _tw("반응 짝", 12) + 12.0
		var shown := 0
		for e in partners:
			if px + 24.0 > w - 26.0:
				break
			Glyph.elem(self, e, Vector2(px + 8, y + 9), 7)
			px += 24.0
			shown += 1
		if shown < partners.size():
			_txt(Vector2(px + 2, y + 14), "+%d" % (partners.size() - shown), 12, Color(1, 1, 1, 0.45))
