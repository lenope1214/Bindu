extends SceneTree
## 무작위 입력(클릭·끌기·키)을 오래 넣어 스크립트 오류를 찾는다. 인자: 시드 프레임수
var main
var f := 0
var n := 6000
var held := false
var keys := [KEY_1, KEY_2, KEY_3, KEY_Q, KEY_V, KEY_SPACE, KEY_ESCAPE, KEY_TAB, KEY_H, KEY_P, KEY_R, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_O, KEY_M, KEY_SHIFT]
func _initialize():
	var a := OS.get_cmdline_user_args()
	seed(int(a[0]) if a.size() > 0 else 1)
	if a.size() > 1: n = int(a[1])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var sd: int = int(a[0]) if a.size() > 0 else 1
	Meta.rules = Rules.IDS[sd % Rules.IDS.size()]
	Meta.map_id = Meta.MAP_IDS[(sd / 4) % Meta.MAP_IDS.size()]
	main._apply_rules()
	main.lanes.clear()
	main._roll_lanes()
	print("FUZZR rules=", Meta.rules, " map=", Meta.map_id)
func _mouse(pos: Vector2, btn: int, pressed: bool, shift := false):
	var e := InputEventMouseButton.new()
	e.position = pos; e.global_position = pos; e.button_index = btn; e.pressed = pressed; e.shift_pressed = shift
	Input.parse_input_event(e)
func _move(pos: Vector2):
	root.get_viewport().warp_mouse(pos)
	var e := InputEventMouseMotion.new()
	e.position = pos; e.global_position = pos
	Input.parse_input_event(e)
func _key(k: int):
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k; e.physical_keycode = k; e.pressed = p
		Input.parse_input_event(e)
func _process(_d):
	f += 1
	if main.core_hp < 5: main.core_hp = 10  # 오래 돌도록
	var vs: Vector2 = root.get_viewport().get_visible_rect().size
	var r := randf()
	var pos := Vector2(randf() * vs.x, randf() * vs.y)
	if randf() < 0.5 and main.towers.get_child_count() > 0:
		# 오브젝트 근처를 자주 누른다
		pos = main.towers.get_child(randi() % main.towers.get_child_count()).position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		pos = root.get_viewport().get_canvas_transform() * pos
	if r < 0.08:
		_mouse(pos, MOUSE_BUTTON_LEFT, true, randf() < 0.2); held = true
	elif r < 0.16 and held:
		_move(pos); _mouse(pos, MOUSE_BUTTON_LEFT, false); held = false
	elif r < 0.40:
		_move(pos)
	elif r < 0.43:
		_mouse(pos, MOUSE_BUTTON_RIGHT, true); _mouse(pos, MOUSE_BUTTON_RIGHT, false)
	elif r < 0.50:
		_key(keys[randi() % keys.size()])
	elif r < 0.56:
		# 터치 (흉내 낸 마우스) + 화면의 취소 버튼
		var t := InputEventScreenTouch.new()
		t.position = pos; t.pressed = randf() < 0.5
		Input.parse_input_event(t)
	elif r < 0.58 and main.cancel_btn.visible:
		main.cancel_btn.emit_signal("pressed")
	if main.get_tree().paused and randf() < 0.05: _key(KEY_P)
	if f % 1000 == 0:
		print("FUZZ f=%d phase=%d wave=%d towers=%d sel=%d" % [f, main.phase, main.wave, main.towers.get_child_count(), main.selected.size()])
	return f >= n
