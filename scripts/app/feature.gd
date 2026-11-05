class_name BinduFeature
extends RefCounted
## Feature controllers are called by the scene; they never register their own frame/input loop.
## Weak ownership prevents session -> feature -> session reference cycles.
var _session_ref: WeakRef
var session: BinduSession:
	get: return _session_ref.get_ref() as BinduSession

func _init(owner_session: BinduSession) -> void:
	_session_ref = weakref(owner_session)
