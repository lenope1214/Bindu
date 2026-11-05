extends SceneTree
## Architecture contracts independent of gameplay fixtures and global RNG sequence.
class Source extends RefCounted:
	signal changed(value: int)
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
	print(("ok " if value else "FAIL ") + message)

func _initialize() -> void:
	var source := Source.new()
	var received: Array = []
	var callback := func(value: int): received.append(value)
	var scope := BinduSignalScope.new()
	scope.connect_to(source.changed, callback)
	scope.connect_to(source.changed, callback)
	source.changed.emit(7)
	check(received == [7], "service callback registered once, synchronous order preserved")
	scope.close()
	scope.close()
	source.changed.emit(8)
	check(received == [7], "close disconnects retained service and is idempotent")
	var scene: BinduSession = load("res://main.tscn").instantiate()
	var other: BinduSession = load("res://main.tscn").instantiate()
	check(scene.hud_system != other.hud_system, "feature state belongs to one session")
	var controller = scene.hud_system
	var scene_ref: WeakRef = weakref(scene)
	scene.free()
	check(scene_ref.get_ref() == null and controller.session == null, "surviving controller does not retain a destroyed scene")
	other.free()
	print("ARCHITECTURE failures=%d" % failures)
	quit(1 if failures else 0)
