class_name BinduSignalScope
extends RefCounted
## Own only service subscriptions that may outlive a scene (for example retained Mp).
## Scene-local button/draw subscriptions die with their nodes and stay with their feature.
var _bindings: Array = []

func connect_to(source: Signal, callback: Callable) -> void:
	if not source.is_connected(callback):
		source.connect(callback)
		_bindings.append([source, callback])

func close() -> void:
	for binding in _bindings:
		var source: Signal = binding[0]
		var callback: Callable = binding[1]
		if is_instance_valid(source.get_object()) and source.is_connected(callback):
			source.disconnect(callback)
	_bindings.clear()
