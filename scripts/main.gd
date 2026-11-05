extends BinduSession
## Scene entry point. Only this node receives Godot callbacks.

func _ready() -> void:
	boot()

func _input(event: InputEvent) -> void:
	interaction_system._input(event)

func _unhandled_input(event: InputEvent) -> void:
	interaction_system._unhandled_input(event)

func _process(delta: float) -> void:
	frame_system._process(delta)

func _draw() -> void:
	field_view_system._draw()
