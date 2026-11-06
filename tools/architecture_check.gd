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
	await process_frame
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
	var tower := Tower.new()
	tower.main = scene
	check(tower._combat_port == scene.combat_system, "entity receives the session combat port")
	tower.main = other
	check(tower._combat_port == other.combat_system, "entity rebinding refreshes service ports")
	tower.main = null
	check(tower._combat_port == null, "unbinding clears service ports")
	tower.free()
	var live_session := BinduSession.new()
	root.add_child(live_session)
	live_session.service_signals.connect_to(source.changed, callback)
	live_session.free()
	source.changed.emit(9)
	check(received == [7], "scene exit disconnects surviving service subscriptions")
	var controller = scene.hud_system
	var scene_ref: WeakRef = weakref(scene)
	scene.free()
	check(scene_ref.get_ref() == null and controller.session == null, "surviving controller does not retain a destroyed scene")
	other.free()
	var origins: Array[Vector2] = [Vector2(10, 10), Vector2(30, 30)]
	var delta := BinduPlacementPolicy.clamp_group_delta(origins, Vector2(100, 100), Rect2(0, 0, 100, 100))
	check(delta == Vector2(70, 70) and origins[0] == Vector2(10, 10), "group clamp preserves offsets and caller input")
	var occupied: Array[Vector2] = [Vector2(80, 0)]
	check(BinduPlacementPolicy.refusal(Vector2(50, 0), Vector2.ZERO, occupied, 30) == "", "placement distance boundary is inclusive")
	check(BinduPlacementPolicy.refusal(Vector2(49, 0), Vector2.ZERO, occupied, 30) != "", "placement rejects core overlap")
	occupied[0] = Vector2(79, 0)
	check(BinduPlacementPolicy.refusal(Vector2(50, 0), Vector2.ZERO, occupied, 30) != "", "placement rejects other object overlap")
	print("ARCHITECTURE failures=%d" % failures)
	quit(1 if failures else 0)
