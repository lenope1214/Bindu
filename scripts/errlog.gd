class_name ErrLog
extends Logger
## 엔진·스크립트 오류를 모아 두었다가 Net이 서버(/v1/logs)로 보낸다.
## Logger는 다른 스레드에서도 불리므로 여기서는 print·파일·노드를 건드리지 않고 목록에만 넣는다.

const MAX_PER_SESSION := 20  # 한 번 켤 때 모을 서로 다른 오류 수
const MSG_MAX := 1000
const BT_MAX := 4000

static var _inst: ErrLog
static var _mutex := Mutex.new()
static var _seen := {}  # 지문 -> 모아 둔 항목 (같은 오류는 횟수만 올림)
static var _fresh: Array = []  # 아직 Net이 가져가지 않은 항목
static var _ctx := {}  # 오류 때 같이 적을 판 정보 (Net이 주기적으로 채움)

const TYPES := ["error", "warning", "script", "shader"]


static func install() -> void:
	if _inst:
		return
	_inst = ErrLog.new()
	OS.add_logger(_inst)


static func set_ctx(ctx: Dictionary) -> void:
	_mutex.lock()
	_ctx = ctx
	_mutex.unlock()


## 새로 생긴 항목을 가져간다. 같은 오류가 다시 나면 지난번에 가져간 뒤 늘어난 횟수만 n으로 다시 나온다.
static func take() -> Array:
	_mutex.lock()
	var out := []
	for e in _fresh:
		var c: Dictionary = e.duplicate()
		c["n"] = e["n"] - e["sent"]
		c.erase("sent")
		e["sent"] = e["n"]
		out.append(c)
	_fresh.clear()
	_mutex.unlock()
	return out


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var msg := rationale if rationale != "" else code
	if rationale != "" and code != "" and code != rationale:
		msg = "%s (%s)" % [rationale, code]
	var bt := ""
	for b in script_backtraces:
		if b and not b.is_empty():
			bt += b.format()
	_add(TYPES[error_type] if error_type >= 0 and error_type < TYPES.size() else "error", msg, file, line, function, bt)


func _log_message(message: String, error: bool) -> void:
	if error:
		_add("printerr", message.strip_edges(), "", 0, "", "")


static func _add(kind: String, msg: String, file: String, line: int, fn: String, bt: String) -> void:
	# 엔진 위치(push_error는 모두 같음)에 스크립트 쪽 첫 줄을 더해 묶는다. 둘 다 없으면 글로
	var top := _top_frame(bt)
	var fp := "%s|%s|%d|%s|%s" % [kind, file, line, top, msg.left(200) if top == "" and file == "" else ""]
	_mutex.lock()
	var e: Variant = _seen.get(fp)
	if e != null:
		e["n"] += 1
		if not _fresh.has(e):
			_fresh.append(e)
	elif _seen.size() < MAX_PER_SESSION:
		e = _ctx.duplicate()
		e.merge({"kind": kind, "msg": msg.left(MSG_MAX), "file": file.left(200), "line": line, "fn": fn.left(100),
			"bt": bt.left(BT_MAX), "n": 1, "sent": 0, "t": int(Time.get_unix_time_from_system())})
		_seen[fp] = e
		_fresh.append(e)
	_mutex.unlock()


static func _top_frame(bt: String) -> String:
	var i := bt.find("[0]")
	if i < 0:
		return ""
	var j := bt.find("\n", i)
	return bt.substr(i + 3, -1 if j < 0 else j - i - 3).strip_edges()
