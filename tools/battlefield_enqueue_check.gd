extends SceneTree
var received := []
class Receiver extends Node:
	var owner_loop
	func _input(event: InputEvent) -> void:
		if event.device == 0xB1D0 and event is InputEventKey:
			owner_loop.received.append([event.keycode, event.pressed])

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2); return
	root.unfocusable = true
	var receiver := Receiver.new()
	receiver.owner_loop = self
	root.add_child(receiver)
	await process_frame
	Input.use_accumulated_input = true
	var worker := Thread.new()
	worker.start(func():
		for code in [KEY_F17, KEY_F18]:
			for down in [true, false]:
				var event := InputEventKey.new()
				event.keycode = code; event.pressed = down; event.device = 0xB1D0
				VirtualInput.enqueue(event))
	worker.wait_to_finish()
	var buffered_only := received.is_empty()
	Input.flush_buffered_events()
	var exact_order := received == [[KEY_F17, true], [KEY_F17, false], [KEY_F18, true], [KEY_F18, false]]
	var released := not Input.is_key_pressed(KEY_F17) and not Input.is_key_pressed(KEY_F18)
	var result := {"buffered_until_main_flush": buffered_only, "exact_four_fresh_events": exact_order, "keys_released": released, "received": received, "virtual_input_sha256": FileAccess.get_sha256("res://tools/virtual_input.gd")}
	FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("BUFFER ENQUEUE ", JSON.stringify(result))
	quit(0 if buffered_only and exact_order and released else 1)
