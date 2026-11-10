extends Control
## Isolated-copy observation only. No visibility, sizing, RNG or AX mutation.
var qa_ax_notifications := []

func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		qa_ax_notifications.append({"frame":Engine.get_process_frames(),
			"time_usec":Time.get_ticks_usec(), "visible":visible,
			"visible_in_tree":is_visible_in_tree(), "name":name,
			"children":get_children().map(func(child): return str(child.name))})
