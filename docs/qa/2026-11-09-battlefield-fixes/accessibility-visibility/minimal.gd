extends SceneTree
## Isolate native visibility semantics without the game's UI or frame systems.
var output := ""
var button: Button
var presses := 0
var observations := []
var owner_session: BinduSession

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless":
		quit(2); return
	output = OS.get_cmdline_user_args()[0]
	root.unfocusable = true
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(container)
	if "bridge" in OS.get_cmdline_user_args():
		owner_session = BinduSession.new()
		owner_session.ui_shell_system._watch_accessibility_visibility(container)
	button = Button.new()
	button.text = "QA Start"
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(404, 608)
	button.size = Vector2(240, 44)
	button.pressed.connect(func(): presses += 1)
	container.add_child(button)
	await process_frame
	root.mode = Window.MODE_WINDOWED
	for label in ["visible", "hidden", "shown", "visible_again", "hidden_again", "ready", "wave"]:
		button.visible = not label in ["hidden", "hidden_again", "wave"] and not (label == "visible" and "start-hidden" in OS.get_cmdline_user_args())
		await expose(label)
	FileAccess.open(output.path_join("observations.json"), FileAccess.WRITE).store_string(JSON.stringify(observations, "\t"))
	container.queue_free()
	for i in 4: await process_frame
	if owner_session != null: owner_session.free()
	print("MINIMAL AX VISIBILITY states=%d" % observations.size())
	quit(0)

func state() -> Dictionary:
	return {"phase":-1, "visible":button.is_visible_in_tree(), "presses":presses, "focus":root.has_focus()}

func expose(label: String) -> void:
	root.title = "Bindu QA " + label
	for i in 7: await process_frame
	RenderingServer.force_draw()
	var before := state()
	FileAccess.open(output.path_join(label + "-ready.json"), FileAccess.WRITE).store_string(JSON.stringify({"label":label, "pid":OS.get_process_id(), "supported":AccessibilityServer.is_supported(), "card_name":button.text,
		"sentinels":[{"name":button.text, "visible":button.is_visible_in_tree()}], "before":before, "controls":[]}, "\t"))
	var deadline := Time.get_ticks_usec() + 30000000
	while not FileAccess.file_exists(output.path_join(label + "-done.json")) and Time.get_ticks_usec() < deadline:
		await create_timer(0.05).timeout
	assert(FileAccess.file_exists(output.path_join(label + "-done.json")))
	for i in 3: await process_frame
	var row := {"label":label, "before":before, "after":state(), "controls":[]}
	observations.append(row)
	FileAccess.open(output.path_join(label + "-result.json"), FileAccess.WRITE).store_string(JSON.stringify(row, "\t"))
