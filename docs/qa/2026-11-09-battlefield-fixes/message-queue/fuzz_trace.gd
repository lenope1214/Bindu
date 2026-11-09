extends "res://tools/fuzz.gd"

const Observer = preload("res://tools/message_queue_trace.gd")
var observer

func _initialize():
	super._initialize()
	observer = Observer.new()
	root.add_child(observer)
	observer.start(main, self)
	qa_cancel = observer.direct_cancel

func _process(delta):
	observer.begin_frame(f + 1, delta)
	var done = super._process(delta)
	observer.end_frame(done)
	return done
