extends Node
## QA-copy-only observer. Does not seed, draw RNG, resize, or query minimum sizes.

var file: FileAccess
var main
var frame := 0
var events := 0
var cancels := 0
var minimum_total := 0
var minimum_frame := 0
var tracked := {}
var truncated := false
const LIMIT := 32 * 1024 * 1024

func start(session, tree: SceneTree) -> void:
	main = session
	file = FileAccess.open(OS.get_environment("BINDU_QUEUE_TRACE"), FileAccess.WRITE)
	assert(file != null)
	tree.node_added.connect(_watch)
	_scan(tree.root)
	write({"kind":"start", "engine":Engine.get_version_info(),
		"nominal_args":OS.get_cmdline_user_args(), "config":config(),
		"scope":"QA observer; global RNG and wall-clock order not captured. Not exact replay."})
	VirtualInput.qa_trace = capture

func _scan(node: Node) -> void:
	_watch(node)
	for child in node.get_children():
		_scan(child)

func _watch(node: Node) -> void:
	if not node is Control or tracked.has(node.get_instance_id()):
		return
	var id := node.get_instance_id()
	tracked[id] = {"ref":weakref(node), "path":str(node.get_path()),
		"changes":0, "frame":-1, "frame_changes":0}
	node.minimum_size_changed.connect(_minimum_changed.bind(id))

func _minimum_changed(id: int) -> void:
	minimum_total += 1
	minimum_frame += 1
	var row: Dictionary = tracked[id]
	row.changes += 1
	if row.frame != frame:
		row.frame = frame
		row.frame_changes = 0
	row.frame_changes += 1
	# Logarithmic burst reporting also works while the deferred queue is draining.
	if row.frame_changes >= 64 and (int(row.frame_changes) & (int(row.frame_changes) - 1)) == 0:
		var control = row.ref.get_ref()
		write({"kind":"minimum_burst", "control":row.path, "changes":row.changes,
			"frame_changes":row.frame_changes,
			"size":str(control.size) if is_instance_valid(control) else null,
			"custom_minimum_size":str(control.custom_minimum_size) if is_instance_valid(control) else null,
			"observer_stack":get_stack()})

func config() -> Dictionary:
	return {"rules":Meta.rules, "map":Meta.map_id, "modes":Modes.on.duplicate(),
		"tutor":main.tutor, "ui_scale_actual":Meta.ui_scale,
		"user_data_dir":OS.get_user_data_dir(), "inside_tree":main.is_inside_tree(),
		"viewport":str(main.get_viewport_rect()) if main.is_inside_tree() else null}

func state() -> Dictionary:
	return {"phase":main.phase, "wave":main.wave, "picks":main.picks_left,
		"core_hp":main.core_hp, "towers":main.towers.get_child_count(),
		"selected":main.interaction_system.selected.size(), "paused":get_tree().paused,
		"cancel_visible":main.cancel_btn.is_visible_in_tree(),
		"ui_scale_actual":Meta.ui_scale, "modes":Modes.on.duplicate(),
		"queue_peak_bytes":Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)}

func begin_frame(number: int, delta: float) -> void:
	frame = number
	write({"kind":"frame_before", "delta":delta, "state":state(),
		"minimum_since_previous_frame_begin":minimum_frame})
	minimum_frame = 0

func end_frame(done: bool) -> void:
	write({"kind":"frame_after", "state":state(), "minimum_changes":minimum_frame})
	if done:
		var controls := []
		for id in tracked:
			var row: Dictionary = tracked[id]
			controls.append({"path":row.path, "changes":row.changes,
				"alive":is_instance_valid(row.ref.get_ref())})
		write({"kind":"done", "events":events, "direct_cancels":cancels,
			"minimum_changes":minimum_total, "config":config(), "controls":controls})
		file.flush()

func direct_cancel() -> void:
	cancels += 1
	write({"kind":"direct_cancel", "state":state()})

func capture(event: InputEvent) -> void:
	events += 1
	var row := {"kind":"input", "sequence":events, "type":event.get_class()}
	if event is InputEventWithModifiers:
		row.merge({"shift":event.shift_pressed, "ctrl":event.ctrl_pressed,
			"alt":event.alt_pressed, "meta":event.meta_pressed})
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		row.position = [event.position.x, event.position.y]
	if event is InputEventMouse:
		row.global_position = [event.global_position.x, event.global_position.y]
		row.button_mask = event.button_mask
	if event is InputEventMouseButton:
		row.merge({"button_index":event.button_index, "pressed":event.pressed,
			"double_click":event.double_click, "factor":event.factor})
	if event is InputEventMouseMotion:
		row.relative = [event.relative.x, event.relative.y]
		row.velocity = [event.velocity.x, event.velocity.y]
	if event is InputEventKey:
		row.merge({"keycode":event.keycode, "physical_keycode":event.physical_keycode,
			"unicode":event.unicode, "pressed":event.pressed, "echo":event.echo})
	if event is InputEventScreenTouch:
		row.merge({"index":event.index, "pressed":event.pressed, "canceled":event.canceled})
	write(row)

func write(row: Dictionary) -> void:
	if truncated:
		return
	row.frame = frame
	row.ticks_usec = Time.get_ticks_usec()
	row.engine_process_frame = Engine.get_process_frames()
	if file.get_position() >= LIMIT:
		file.store_line(JSON.stringify({"kind":"trace_limit", "bytes":file.get_position()}))
		file.flush()
		truncated = true
		return
	file.store_line(JSON.stringify(row))
	# Preserve the prefix if the engine faults before orderly exit.
	file.flush()
