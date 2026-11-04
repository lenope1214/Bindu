class_name VirtualInput
extends Node
## 검사 전용 Viewport: OS 입력은 전달하지 않고 주입한 입력만 실제 GUI 경로로 보낸다.
static var viewport: SubViewport
static var sending := false
var host: Window

static func mount(main: Node, window: Window) -> void:
	window.unfocusable = true
	window.mode = Window.MODE_MINIMIZED
	window.set_deferred("mode", Window.MODE_MINIMIZED)
	window.gui_embed_subwindows = true
	if not is_instance_valid(viewport):
		viewport = SubViewport.new()
		viewport.name = "AutomationViewport"
		viewport.size = window.size
		viewport.size_2d_override = Vector2i(window.get_visible_rect().size)
		viewport.size_2d_override_stretch = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.gui_embed_subwindows = true
		window.add_child(viewport)
		var relay := VirtualInput.new()
		relay.process_mode = Node.PROCESS_MODE_ALWAYS
		relay.host = window
		window.add_child(relay)
		window.size_changed.connect(relay._resize)
		relay.call_deferred("_resize")
		Input.use_accumulated_input = false
		viewport.notify_mouse_entered()
	viewport.add_child(main)

func _resize() -> void:
	viewport.size = host.size
	viewport.size_2d_override = Vector2i(host.get_visible_rect().size)

func _input(event: InputEvent) -> void:
	if sending:
		viewport.push_input(event, true)

static func send(event: InputEvent) -> void:
	# parse_input_event로 버튼·수정키·터치 에뮬레이션 상태도 갱신한다. OS 커서는 움직이지 않는다.
	sending = true
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		event = event.xformed_by(viewport.get_tree().root.get_final_transform())
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	sending = false

static func move(at: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = mask
	send(event)
