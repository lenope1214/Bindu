class_name BinduPlacementPolicy
extends RefCounted
## Placement decisions use values only: no scene, UI, signals, Rules or ownership lookups.
static func clamp_group_delta(origins: Array[Vector2], delta: Vector2, field: Rect2) -> Vector2:
	for origin in origins:
		var point := origin + delta
		delta += point.clamp(field.position, field.end) - point
	return delta

static func refusal(position: Vector2, core: Vector2, occupied: Array[Vector2], merge_distance: float) -> String:
	if position.distance_to(core) < 50.0:
		return "중앙 점에 너무 가까워요"
	for other in occupied:
		if other.distance_to(position) < merge_distance:
			return "다른 오브젝트와 겹칠 수 없어요"
	return ""
