class_name VirtualInput
extends Node
## 검사 전용 Viewport: OS 입력은 전달하지 않고 주입한 입력만 실제 GUI 경로로 보낸다.
static var viewport: SubViewport
static var sending := false
var host: Window

static func mount(main: Node, window: Window) -> void:
	# 최소화된 검사 창의 실제 포커스 알림은 가상 사용자 행동이 아니다.
	# 포커스 정책 검사는 해당 사례에서 명시적으로 다시 켜고 알림을 주입한다.
	Meta.pause_on_focus_loss = false
	window.unfocusable = true
	window.mode = Window.MODE_MINIMIZED
	window.set_deferred("mode", Window.MODE_MINIMIZED)
	window.gui_embed_subwindows = true
	var tree := Engine.get_main_loop() as SceneTree
	if not tree.node_added.is_connected(_isolate_clipboard):
		tree.node_added.connect(_isolate_clipboard)
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

## Buffer-only injection for worker probes. No Node access or shared sending flag.
## The caller owns accumulation/relay setup and flushes on the main thread.
static func enqueue(event: InputEvent) -> void:
	Input.parse_input_event(event)

static func move(at: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = mask
	send(event)

## 무작위 우클릭으로 텍스트 메뉴가 열릴 때 OS 클립보드를 조회하지 않는다.
## headless에는 클립보드가 없고, native 검사에서도 개인 클립보드를 사용하면 안 된다.
static func _isolate_clipboard(node: Node) -> void:
	if (node is LineEdit or node is TextEdit) and node.get_viewport() == viewport:
		node.set("context_menu_enabled", false)
