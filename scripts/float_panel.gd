class_name FloatPanel
extends PanelContainer
## 떠 있는 정보 창 공용 틀 (DPS 표·오브젝트/카드 정보창).
## 머리 줄(손잡이·제목·창별 버튼·압정·접기·닫기), 옮기기(끌기·꾹 누르기), 놓은 자리 기억(Meta.panel_pos, 기기별),
## 화면 안·다른 UI 비켜 놓기, 밑에 깔린 오브젝트 먼저 누르기(통과)를 함께 쓴다. 내용은 body에 넣는다.
## 압정이 꺼져 있으면 주인이 정한 자동 자리, 옮기면 압정이 켜지고 그 자리에 머문다. 압정을 다시 누르면 자동 자리로.

signal fold_pressed  ## 머리 줄 짧게 누르기 또는 [–] (접기·펴기는 주인이 정한다)
signal close_pressed
signal moved  ## 놓거나 압정을 바꿈 (자리 저장 뒤)

const HOLD := 0.35  # 꾹 누르면 손을 안 움직여도 집어 든다
const DRAG_MIN := 10.0  # 이만큼 끌면 집어 든다
const SNAP := 24.0  # 마우스: 가장자리 이만큼 안에 놓으면 붙는다
const EDGE := 8.0  # 붙을 때 가장자리 여백
const TIP := "누르면 접기·펴기 · 끌면 옮기기\n압정: 놓은 자리 고정 / 다시 누르면 자동 자리"
const TIP_TOUCH := "누르면 접기·펴기 · 꾹 눌러 옮기기"

var id := ""
var game
var head: HBoxContainer
var grip: Control
var title: Label
var tools: HBoxContainer  # 창마다 다른 머리 줄 버튼 (방향 변경·자세히 등)
var pin_btn: Button
var fold_btn: Button
var close_btn: Button
var body: VBoxContainer
var drag := 0  # 0 아님 · 1 머리 줄을 누르는 중 · 2 옮기는 중
var press := Vector2.ZERO  # 머리 줄을 누른 자리 (부모 좌표)
var press_t := 0.0
var grab := Vector2.ZERO  # 집은 곳 - 창 왼쪽 위
var passing := false  # 밑에 깔린 오브젝트를 누르도록 마우스를 통과시키는 중
var folded := false
var guide: Control  # 터치로 옮기는 동안 붙을 자리 여섯 곳 점선
var style: StyleBoxFlat


func _init(panel_id := "", main = null, closable := false) -> void:
	id = panel_id
	game = main
	name = "Float_" + panel_id
	style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.07, 0.92)
	style.border_color = Color("303c50")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	head = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_theme_constant_override("separation", 4)
	head.gui_input.connect(head_input)  # 짧게 누르면 접기·펴기, 꾹 누르거나 끌면 옮기기
	head.tooltip_text = TIP
	col.add_child(head)
	grip = Control.new()
	grip.custom_minimum_size = Vector2(12, 24)
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip.draw.connect(func():
		var c := grip.size / 2.0
		for i in 3:
			for j in 2:
				grip.draw_circle(c + Vector2(-2.5 + j * 5.0, -5.0 + i * 5.0), 1.5, Color(1, 1, 1, 0.75 if drag == 2 else 0.4)))
	head.add_child(grip)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	head.add_child(title)
	var gap := Control.new()  # 제목을 숨겨도(폰 오브젝트 정보) 버튼은 오른쪽에 붙게
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 0.001  # 제목이 있으면 남는 폭은 거의 다 제목에
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gap)
	tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tools)
	pin_btn = _head_btn("")
	pin_btn.pressed.connect(toggle_pin)
	pin_btn.draw.connect(_draw_pin)
	fold_btn = _head_btn("–")
	fold_btn.pressed.connect(func(): fold_pressed.emit())
	fold_btn.tooltip_text = "접기·펴기"
	if closable:
		close_btn = _head_btn("×")
		close_btn.pressed.connect(func(): close_pressed.emit())
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	_update_pin_tip()


func _head_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 26)
	b.add_theme_font_size_override("font_size", 16)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.0 if s == "focus" else (0.16 if s in ["hover", "hover_pressed"] else 0.06))
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(0)
		b.add_theme_stylebox_override(s, sb)
	head.add_child(b)
	return b


func _draw_pin() -> void:
	var c := pin_btn.size / 2.0
	var k := pin_btn.size.y / 26.0
	var col := Color(1, 0.85, 0.35) if pinned() else Color(1, 1, 1, 0.55)
	pin_btn.draw_circle(c + Vector2(0, -3.5) * k, 4.0 * k, col)
	pin_btn.draw_line(c + Vector2(-5, 0.5) * k, c + Vector2(5, 0.5) * k, col, 2.0 * k)
	pin_btn.draw_line(c + Vector2(0, 0.5) * k, c + Vector2(0, 8) * k, col, 1.6 * k)


## 머리 줄 버튼 크기: 터치는 손가락에 맞게 크게.
func set_touch(on: bool) -> void:
	var s := 36.0 if on else 26.0
	for b in [pin_btn, fold_btn, close_btn]:
		if b != null and b.custom_minimum_size.y != s:
			b.custom_minimum_size = Vector2(s, s)
	head.tooltip_text = TIP_TOUCH if on else TIP


func pinned() -> bool:
	return Meta.panel_pos.has(id)


## 압정: 켜면 지금 자리에 고정, 끄면 자동 자리로.
func toggle_pin() -> void:
	if pinned():
		Meta.panel_pos.erase(id)
	else:
		Meta.panel_pos[id] = _ratio(position)
	_after_move()


func set_folded(on: bool) -> void:
	folded = on
	fold_btn.text = "+" if on else "–"
	body.visible = not on


func _par() -> Control:
	return get_parent() as Control


func _local_pointer() -> Vector2:
	return _par().get_global_transform().affine_inverse() * game._pointer_screen()


## 머리 줄 누르기: 놓을 때 옮기지 않았으면 접기·펴기, 꾹 누르거나(HOLD) 끌면(DRAG_MIN) 집어 옮긴다.
func head_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			drag = 1
			press = _local_pointer()
			press_t = 0.0
		elif drag > 0:
			if drag == 2:
				drop()
			else:
				fold_pressed.emit()
			drag = 0
		head.accept_event()
	elif e is InputEventMouseMotion and drag == 1:
		if _local_pointer().distance_to(press) > DRAG_MIN:
			pick()


## 집어 든다 (꾹 누르기·끌기).
func pick() -> void:
	drag = 2
	grab = press - position
	head.tooltip_text = ""  # 옮기는 동안 말풍선이 창을 가리지 않게
	if guide == null and _par() != null:
		guide = Control.new()
		guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide.z_index = 30
		guide.draw.connect(_draw_guide)
		_par().add_child(guide)
	grip.queue_redraw()


## 옮기는 동안 창 왼쪽 위 (손가락·마우스를 따라, 화면 안).
func drag_pos() -> Vector2:
	return (_local_pointer() - grab).clamp(Vector2.ZERO, (_par().size - size).max(Vector2.ZERO))


## 놓기: 가까운 자리에 붙이고(터치는 여섯 자리, 마우스는 가장자리) 화면 안 빈 폭 비율로 저장한다.
func drop() -> void:
	var p := snap(drag_pos())
	position = p
	Meta.panel_pos[id] = _ratio(p)
	_after_move()


func _after_move() -> void:
	set_touch(game.touch_ui)
	pin_btn.queue_redraw()
	grip.queue_redraw()
	_update_pin_tip()
	moved.emit()
	game.progression_system._save_best()


func _update_pin_tip() -> void:
	pin_btn.tooltip_text = "자리 고정됨 · 누르면 자동 자리로" if pinned() else "지금 자리에 고정"


func _ratio(p: Vector2) -> Vector2:
	return (p / (_par().size - size).max(Vector2.ONE)).clamp(Vector2.ZERO, Vector2.ONE)


## 저장한 비율 → 지금 화면의 자리 (창·화면 크기가 바뀌어도 같은 쪽).
func saved_pos() -> Vector2:
	return Meta.panel_pos.get(id, Vector2.ZERO) * (_par().size - size).max(Vector2.ONE)


## 붙을 자리 여섯 곳 (위·아래 x 왼쪽·가운데·오른쪽, 왼쪽 위 좌표). 위는 점수 줄 아래, 아래는 아래 버튼 줄 위.
func slots() -> Array[Vector2]:
	var ps := _par().size
	var top: float = game.hud_system._dps_home().y
	var bottom := maxf(top, ps.y - size.y - 64.0)
	var out: Array[Vector2] = []
	for y in [top, bottom]:
		for x in [EDGE, (ps.x - size.x) / 2.0, ps.x - size.x - EDGE]:
			out.append(Vector2(x, y))
	return out


func snap(p: Vector2) -> Vector2:
	if game.touch_ui:
		var best := p
		var bd := INF
		for s in slots():
			if s.distance_to(p) < bd:
				bd = s.distance_to(p)
				best = s
		return best
	var ps := _par().size
	if p.x < EDGE + SNAP:
		p.x = EDGE
	elif ps.x - size.x - p.x < EDGE + SNAP:
		p.x = ps.x - size.x - EDGE
	if ps.y - size.y - p.y < EDGE + SNAP:
		p.y = ps.y - size.y - EDGE
	return p


## 옮겨 둔 자리: 점수 줄·아래 버튼·기술 버튼 등(game._panel_blocks)과 겹치면 위나 아래로 비켜 화면 안에.
func place(p: Vector2) -> Vector2:
	var ps := _par().size
	var blocks: Array[Rect2] = game.hud_system._panel_blocks(self)
	for _i in 3:
		var r := Rect2(p, size)
		var hit := false
		for b in blocks:
			if r.intersects(b):
				# 막는 것이 위쪽 반이면 그 아래로, 아니면 그 위로
				p.y = b.end.y if b.get_center().y < ps.y / 2.0 else b.position.y - size.y
				hit = true
				break
		if not hit:
			break
	return p.clamp(Vector2(EDGE, EDGE), (ps - size - Vector2(EDGE, EDGE)).max(Vector2(EDGE, EDGE)))


## 매 프레임: 꾹 누르기 시간, 옮기는 중이면 따라가기, 아니면 고정 자리(비켜 놓기) 또는 자동 자리.
func follow(auto_pos: Vector2, delta: float) -> void:
	if not is_visible_in_tree():
		stop_drag()
	if drag == 1:
		press_t += delta
		if press_t >= HOLD:
			pick()
	if drag == 2:
		position = drag_pos()
	elif pinned():
		position = place(saved_pos())
	else:
		position = auto_pos
	style.border_color = Color(1, 0.9, 0.5, 0.95) if drag == 2 else Color("303c50")
	if guide != null:
		guide.visible = drag == 2 and game.touch_ui
		if guide.visible:
			guide.size = _par().size
			guide.queue_redraw()


func stop_drag() -> void:
	if drag != 0:
		drag = 0
		set_touch(game.touch_ui)
		grip.queue_redraw()
	if guide != null:
		guide.visible = false


func _draw_guide() -> void:
	var near := snap(position)
	for s in slots():
		var r := Rect2(s, size)
		var col := Color(1, 0.85, 0.35, 0.85 if s == near else 0.3)
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			guide.draw_dashed_line(pts[i], pts[i + 1], col, 2.0, 8.0)


## 밑에 깔린 오브젝트를 누르게 마우스 통과 (점수 줄 칩과 같은 규칙). 바뀔 때만 자식까지 고친다.
func set_pass(on: bool, force := false) -> void:
	if on == passing and not force:
		return
	passing = on
	var nodes: Array = [self]
	nodes.append_array(find_children("*", "Control", true, false))
	for c: Control in nodes:
		if on:
			if not c.has_meta("fp_mf"):
				c.set_meta("fp_mf", c.mouse_filter)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif c.has_meta("fp_mf"):
			c.mouse_filter = c.get_meta("fp_mf")
			c.remove_meta("fp_mf")


## 창 밑(전장)에 오브젝트가 있고 누르는 자리가 그 오브젝트면 통과, 아니면 창이 받는다.
## fade면 마우스가 창 밖일 때 밑에 오브젝트·진입 화살표가 있으면 옅게 해서 보이게 한다.
func cover(fade: bool) -> void:
	if not is_visible_in_tree():
		return
	var inv: Transform2D = game.get_canvas_transform().affine_inverse()
	var pr: Rect2 = inv * get_global_rect()
	var wp: Vector2 = game._pointer_world()
	var under := false
	if fade and not pr.has_point(wp):
		for t in game.towers.get_children():
			if pr.grow(14.0).has_point(t.position):
				under = true
				break
		if not under:
			for arr in game.ui_layout_system._lane_arrows():
				if pr.grow(14.0).has_point(arr[0]):
					under = true
					break
	modulate.a = 0.4 if under and drag != 2 else 1.0
	set_pass(drag == 0 and pr.has_point(wp) and game._tower_at(wp) != null)


## 누르는 순간 다시 판정 (마우스가 움직이지 않고 눌러도 맞게).
func press_check(screen: Vector2) -> void:
	if not is_visible_in_tree() or drag != 0:
		return
	var inv: Transform2D = game.get_canvas_transform().affine_inverse()
	var wp: Vector2 = inv * screen
	set_pass((inv * get_global_rect()).has_point(wp) and game._tower_at(wp) != null)
