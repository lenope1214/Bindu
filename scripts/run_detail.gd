class_name RunDetail
extends Control
## 결과 상세 (판이 끝난 결과 화면의 [결과 상세]).
## 왼쪽: 오브젝트마다 판 전체 피해 몫·처치·평균 DPS (맨 위 줄은 전체). 누르면 그 오브젝트를 고른다.
## 오른쪽: 고른 줄의 웨이브별 DPS 막대, 막대 위 처치 수, 아래 요약 (가장 센 웨이브·처치·평균 DPS).
## 처치는 마지막으로 피해를 준 오브젝트 몫 (Orb.last_by). 기록은 Tower.hist (웨이브 끝마다 [웨이브, 피해, 처치, 초]).

const ROW_H := 42.0
const HEAD_H := 54.0
const BG := Color(0.03, 0.04, 0.06, 1.0)
const LINE := Color(1, 1, 1, 0.08)
const DIM := Color(1, 1, 1, 0.5)
const KILL_COL := Color(1, 0.85, 0.4)

var game: Node  # BinduSession
var font: Font
var rows: Array = []
var sel := 0
var scroll := 0.0
var close_btn: Button
var _drag_y := -1.0
var _drag_moved := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30  # 결과 카드·안내 말풍선·일시정지 창(20~22) 위
	visible = false
	close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.size = Vector2(96, 40)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(close)
	add_child(close_btn)


func open(session: Node, towers: Array) -> void:
	game = session
	font = session.ui_font
	rows = build(towers)
	sel = 0
	scroll = 0.0
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


## 오브젝트들 → 줄 목록. 첫 줄은 전체(웨이브마다 합). 나머지는 판 전체 피해 순.
static func build(towers: Array) -> Array:
	var out: Array = []
	var total := 0.0
	var kills := 0
	var by_w := {}  # 웨이브 -> [피해, 처치, 초]
	for t in towers:
		var d: float = t.run_dealt + t.dealt
		var k: int = t.run_kills()
		total += d
		kills += k
		for h in t.hist:
			var a: Array = by_w.get(h[0], [0, 0, h[3]])
			a[0] += h[1]
			a[1] += h[2]
			a[2] = maxf(a[2], h[3])
			by_w[h[0]] = a
		out.append({"name": t.title(), "color": t.color(), "dealt": d, "kills": k, "hist": t.hist.duplicate()})
	out.sort_custom(func(a, b): return a["dealt"] > b["dealt"])
	for r in out:
		r["share"] = r["dealt"] / total if total > 0.0 else 0.0
	var ws: Array = by_w.keys()
	ws.sort()
	var all_hist: Array = []
	for w in ws:
		all_hist.append([w, by_w[w][0], by_w[w][1], by_w[w][2]])
	return [{"name": "전체", "color": Color.WHITE, "dealt": total, "kills": kills, "hist": all_hist, "share": 1.0}] + out


## 웨이브 기록의 평균 DPS (피해 합 / 웨이브 시간 합).
static func avg_dps(hist: Array) -> float:
	var d := 0.0
	var s := 0.0
	for h in hist:
		d += h[1]
		s += h[3]
	return d / s if s > 0.0 else 0.0


static func wave_dps(h: Array) -> float:
	return h[1] / h[3] if h[3] > 0.0 else 0.0


func _box() -> Rect2:
	var m := Vector2(minf(48.0, size.x * 0.03), minf(36.0, size.y * 0.05))
	return Rect2(m, size - m * 2.0)


func _list_rect() -> Rect2:
	var b := _box()
	var lw := clampf(b.size.x * 0.42, 300.0, 520.0)
	return Rect2(b.position + Vector2(16, HEAD_H + 30.0), Vector2(lw, b.size.y - HEAD_H - 46.0))


func _chart_rect() -> Rect2:
	var b := _box()
	var l := _list_rect()
	var x := l.end.x + 28.0
	return Rect2(Vector2(x, b.position.y + HEAD_H + 30.0), Vector2(b.end.x - 20.0 - x, b.size.y - HEAD_H - 46.0))


func _max_scroll() -> float:
	return maxf(0.0, rows.size() * ROW_H - _list_rect().size.y)


func _num(v: float) -> String:
	if game != null and game.has_method("num"):
		return game.num(roundi(v))
	return str(roundi(v))


func _draw() -> void:
	if rows.is_empty() or font == null:
		return
	var b := _box()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(12)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	draw_style_box(sb, b)
	close_btn.position = Vector2(b.end.x - close_btn.size.x - 14.0, b.position.y + 10.0)
	draw_string(font, b.position + Vector2(20, 38), "결과 상세", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(font, b.position + Vector2(150, 37), "처치는 마지막으로 맞힌 오브젝트 몫이에요", HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 300.0, 13, DIM)
	_draw_list()
	_draw_chart()


func _draw_list() -> void:
	var l := _list_rect()
	var cols := _cols(l)
	var hy := l.position.y - 8.0
	draw_string(font, Vector2(cols[0], hy), "오브젝트", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	draw_string(font, Vector2(cols[1], hy), "피해", HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 13, DIM)
	draw_string(font, Vector2(cols[2], hy), "처치", HORIZONTAL_ALIGNMENT_RIGHT, 56.0, 13, DIM)
	draw_string(font, Vector2(cols[3], hy), "평균 DPS", HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 13, DIM)
	for i in rows.size():
		var y := l.position.y + i * ROW_H - scroll
		if y + ROW_H < l.position.y or y > l.end.y:
			continue
		var r: Dictionary = rows[i]
		var rr := Rect2(l.position.x, y, l.size.x, ROW_H - 4.0)
		if i == sel:
			draw_rect(rr, Color(0.35, 0.55, 0.9, 0.22))
			draw_rect(Rect2(rr.position, Vector2(3, rr.size.y)), Color(0.55, 0.75, 1.0))
		elif i % 2 == 0:
			draw_rect(rr, Color(1, 1, 1, 0.03))
		var cy := y + ROW_H / 2.0 - 2.0
		draw_circle(Vector2(l.position.x + 16.0, cy), 7.0, r["color"])
		# 피해 몫 막대 (이름 아래 얇게)
		if i > 0:
			draw_rect(Rect2(l.position.x + 30.0, y + ROW_H - 9.0, (cols[1] - l.position.x - 40.0) * r["share"], 3.0), Color(r["color"], 0.7))
		var nw: float = cols[1] - l.position.x - 36.0
		var nf := 15
		while nf > 12 and font.get_string_size(r["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, nf).x > nw:
			nf -= 1
		draw_string(font, Vector2(l.position.x + 30.0, cy + 5.0), _fit(r["name"], nw, nf), HORIZONTAL_ALIGNMENT_LEFT, -1, nf, Color.WHITE)
		var share := "%d%%" % roundi(r["share"] * 100.0) if i > 0 else _num(r["dealt"])
		draw_string(font, Vector2(cols[1], cy + 5.0), share, HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 15, Color.WHITE)
		draw_string(font, Vector2(cols[2], cy + 5.0), str(r["kills"]), HORIZONTAL_ALIGNMENT_RIGHT, 56.0, 15, KILL_COL)
		draw_string(font, Vector2(cols[3], cy + 5.0), _num(avg_dps(r["hist"])), HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 15, Color(0.7, 0.85, 1.0))
	if _max_scroll() > 0.0:
		var frac := l.size.y / (rows.size() * ROW_H)
		var bh := l.size.y * frac
		draw_rect(Rect2(l.end.x + 6.0, l.position.y + (l.size.y - bh) * (scroll / _max_scroll()), 3.0, bh), Color(1, 1, 1, 0.25))


## 칸에 안 들어가는 이름은 뒤를 줄여 "…" (오른쪽 그래프 제목엔 다 나온다).
func _fit(t: String, w: float, fs: int) -> String:
	if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return t
	while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


func _cols(l: Rect2) -> Array:
	var x3 := l.end.x - 84.0
	var x2 := x3 - 62.0
	var x1 := x2 - 76.0
	return [l.position.x + 30.0, x1, x2, x3]


func _draw_chart() -> void:
	var c := _chart_rect()
	var r: Dictionary = rows[clampi(sel, 0, rows.size() - 1)]
	var hist: Array = r["hist"]
	draw_string(font, Vector2(c.position.x, c.position.y - 8.0), "%s · 웨이브별 DPS" % r["name"], HORIZONTAL_ALIGNMENT_LEFT, c.size.x, 15, Color.WHITE)
	var plot := Rect2(c.position + Vector2(52, 26), c.size - Vector2(60, 26 + 78))
	draw_line(plot.position + Vector2(0, plot.size.y), plot.end, LINE, 1.0)
	if hist.is_empty():
		draw_string(font, plot.position + Vector2(0, plot.size.y / 2.0), "끝난 웨이브 기록이 없어요", HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, 15, DIM)
		return
	var top := 1.0
	var best: Array = hist[0]
	var kill_sum := 0
	for h in hist:
		top = maxf(top, wave_dps(h))
		if wave_dps(h) > wave_dps(best):
			best = h
		kill_sum += h[2]
	# 눈금 (위·가운데)
	for f: float in [1.0, 0.5]:
		var gy := plot.end.y - plot.size.y * f
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), LINE, 1.0)
		draw_string(font, Vector2(plot.position.x - 52.0, gy + 5.0), _num(top * f), HORIZONTAL_ALIGNMENT_RIGHT, 46.0, 12, DIM)
	var n := hist.size()
	var bw := plot.size.x / n
	var col: Color = r["color"] if sel > 0 else Color(0.55, 0.75, 1.0)
	var label_every := maxi(1, ceili(n * 30.0 / plot.size.x))  # 웨이브 번호가 겹치지 않게 (번호 하나에 30px)
	for i in n:
		var h: Array = hist[i]
		var bh := plot.size.y * wave_dps(h) / top
		var x := plot.position.x + i * bw
		draw_rect(Rect2(x + bw * 0.12, plot.end.y - bh, maxf(1.0, bw * 0.76), bh), Color(col, 0.85 if h == best else 0.6))
		if h[2] > 0 and bw >= 14.0:
			draw_string(font, Vector2(x, plot.end.y - bh - 4.0), str(h[2]), HORIZONTAL_ALIGNMENT_CENTER, bw, 11, KILL_COL)
		if i % label_every == 0 or i == n - 1:
			draw_string(font, Vector2(x - 10.0, plot.end.y + 16.0), str(h[0]), HORIZONTAL_ALIGNMENT_CENTER, bw + 20.0, 11, DIM)
	draw_string(font, Vector2(plot.position.x, plot.end.y + 34.0), "웨이브", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	# 요약
	var sy := plot.end.y + 62.0
	var items := [["가장 센 웨이브", "%d · DPS %s" % [best[0], _num(wave_dps(best))]], ["평균 DPS", _num(avg_dps(hist))], ["처치", str(kill_sum)], ["판 피해", _num(r["dealt"])]]
	var iw := c.size.x / items.size()
	for i in items.size():
		draw_string(font, Vector2(c.position.x + i * iw, sy), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, iw - 8.0, 12, DIM)
		draw_string(font, Vector2(c.position.x + i * iw, sy + 20.0), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, iw - 8.0, 16, KILL_COL if i == 2 else Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	var l := _list_rect()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = clampf(scroll + (ROW_H if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -ROW_H), 0.0, _max_scroll())
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag_y = event.position.y
			_drag_moved = false
	elif event is InputEventMouseMotion and _drag_y >= 0.0 and l.has_point(event.position):
		var dy: float = event.position.y - _drag_y
		if absf(dy) > 6.0 or _drag_moved:
			_drag_moved = true
			scroll = clampf(scroll - event.relative.y, 0.0, _max_scroll())
			queue_redraw()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _drag_moved and l.has_point(event.position):
			var i := int((event.position.y - l.position.y + scroll) / ROW_H)
			if i >= 0 and i < rows.size():
				sel = i
				queue_redraw()
		_drag_y = -1.0
	accept_event()
