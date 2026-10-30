class_name Net
extends Node
## 온라인: 켤 때 패치·새 버전 확인, 판 기록 보내기(못 보내면 모아 뒀다 다음에), 리더보드.
## 서버 주소(OnlineConfig.SERVER_URL)가 비었거나 설정에서 끄면 아무것도 보내지 않는다.

signal booted(info: Dictionary)
signal run_sent(res: Dictionary)  # 이번 판 기록의 서버 응답 {accepted, season, rank}
signal board_loaded(res: Dictionary)  # 실패면 {"error": 이유}
signal seasons_loaded(list: Array)  # [{id, name, started}] 새 시즌부터. 실패면 []

const OUTBOX_PATH := "user://outbox.json"
const OUTBOX_MAX := 30  # 오프라인으로 쌓아 둘 판 수
const TIMEOUT := 10.0
const LOGBOX_PATH := "user://logbox.json"
const LOGBOX_MAX := 60  # 못 보내고 쌓아 둘 오류 수
const LOG_EVERY := 30.0  # 오류를 서버로 보내는 최소 간격(초)

static var info := {}  # 마지막 /v1/boot 응답
static var boot_done := false  # 다시 시작(장면 새로 불러오기)해도 한 번만
var sending := false
var watch := ""  # 응답을 알려 줄 이번 판 기록
var sending_logs := false
var log_tick := 0.0
var log_wait := 0.0  # 다음 오류 보내기까지 남은 초


static func enabled() -> bool:
	# 봇 측정(헤드리스)은 보내지 않는다
	return reachable() and Meta.online_on


static func platform() -> String:
	return OS.get_name().to_lower()


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## 서버 주소가 있으면 패치·새 버전 확인과 리더보드 보기는 된다 (보내는 것이 없음).
static func reachable() -> bool:
	return OnlineConfig.SERVER_URL != "" and DisplayServer.get_name() != "headless"


func _ready() -> void:
	if reachable():
		ErrLog.install()
		_update_ctx()
	if reachable() and not boot_done:
		boot_done = true
		boot()
	if enabled():
		flush.call_deferred()


## 1초마다 오류에 붙일 판 정보를 갱신하고, 새 오류는 파일에 쌓았다가 LOG_EVERY초마다 보낸다.
func _process(delta: float) -> void:
	if not reachable():
		return
	log_tick += delta
	log_wait -= delta
	if log_tick < 1.0:
		return
	log_tick = 0.0
	_update_ctx()
	var fresh := ErrLog.take()
	if not fresh.is_empty():
		var box := _load_json(LOGBOX_PATH)
		box.append_array(fresh)
		_save_json(LOGBOX_PATH, box.slice(-LOGBOX_MAX))
	if log_wait <= 0.0 and enabled():
		flush_logs()


func _update_ctx() -> void:
	var m := get_parent()
	ErrLog.set_ctx({"map": Meta.map_id, "rules": Meta.rules, "modes": ",".join(Modes.on), "skin": Meta.tower_skin,
		"wave": int(m.get("wave")) if m and m.get("wave") != null else 0})


## 쌓인 오류를 한 번에 보낸다 (기록 보내기를 끄면 안 보냄).
func flush_logs() -> void:
	if sending_logs or not enabled():
		return
	var box := _load_json(LOGBOX_PATH)
	if box.is_empty():
		return
	sending_logs = true
	log_wait = LOG_EVERY
	var part := box.slice(0, 20)
	var body := JSON.stringify({"device": Meta.device_id, "platform": platform(), "os": OS.get_name() + " " + OS.get_version(),
		"game": game_version(), "patch": Patch.id, "entries": part})
	var mac := Crypto.new().hmac_digest(HashingContext.HASH_SHA256, OnlineConfig.RUN_HMAC_KEY.to_utf8_buffer(), body.to_utf8_buffer()).hex_encode()
	var r := await _request(HTTPClient.METHOD_POST, "/v1/logs", body, PackedStringArray(["X-Bindu-Mac: " + mac]))
	var code: int = r["code"]
	if code != 0 and code != 429 and code < 500:
		# 받았거나 영영 안 받을 것: 보낸 만큼 뺀다 (보내는 사이 새로 쌓인 것은 남김)
		_save_json(LOGBOX_PATH, _load_json(LOGBOX_PATH).slice(part.size()))
	sending_logs = false


func _request(method: int, path: String, body := "", headers := PackedStringArray()) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var h := PackedStringArray(["Content-Type: application/json"])
	h.append_array(headers)
	if http.request(OnlineConfig.SERVER_URL + path, h, method, body) != OK:
		http.queue_free()
		return {"code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var data: Variant = null
	if res[0] == HTTPRequest.RESULT_SUCCESS:
		data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return {"code": res[1] if res[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": data}


func boot() -> void:
	var have: int = Patch.pending["id"] if Patch.pending != null else Patch.id
	var r := await _request(HTTPClient.METHOD_GET, "/v1/boot?game=%s&platform=%s&patch=%d" % [game_version(), platform(), have])
	if r["code"] != 200 or not r["data"] is Dictionary:
		return
	info = r["data"]
	var p: Variant = info.get("patch")
	if p is Dictionary:
		if int(p.get("id", 0)) == 0:
			if have != 0:
				Patch.clear()
		elif not p.get("same", false):
			Patch.accept(str(p.get("payload", "")), str(p.get("sig", "")))
	booted.emit(info)


## 판이 끝나면: 기록을 보낼 목록에 넣고 보낸다.
func submit(record: Dictionary) -> void:
	if not enabled():
		return
	record["local"] = "%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	var box := _load_outbox()
	box.append(record)
	_save_outbox(box.slice(-OUTBOX_MAX))
	watch = record["local"]
	flush()


## 쌓인 기록을 오래된 것부터 보낸다. 서버가 받거나(200) 영영 안 받을 기록(4xx)이면 목록에서 뺀다.
func flush() -> void:
	if sending or not enabled():
		return
	sending = true
	while true:
		var box := _load_outbox()
		if box.is_empty():
			break
		var rec: Dictionary = box[0]
		var body := JSON.stringify(rec)
		var mac := Crypto.new().hmac_digest(HashingContext.HASH_SHA256, OnlineConfig.RUN_HMAC_KEY.to_utf8_buffer(), body.to_utf8_buffer()).hex_encode()
		var r := await _request(HTTPClient.METHOD_POST, "/v1/runs", body, PackedStringArray(["X-Bindu-Mac: " + mac]))
		var code: int = r["code"]
		if code == 0 or code == 429 or code >= 500:
			break  # 오프라인·서버 문제·너무 잦음: 다음에 다시
		box = _load_outbox()
		box = box.filter(func(x): return x.get("local") != rec.get("local"))
		_save_outbox(box)
		if code == 200 and r["data"] is Dictionary and rec.get("local") == watch:
			run_sent.emit(r["data"])
	sending = false


## season 0은 이번 시즌. 응답에 tag를 붙여 돌려준다 (필터를 바꾼 뒤 늦게 온 지난 응답을 버리게).
func leaderboard(map_id: String, rules: int, period: String, season := 0, tag := "") -> void:
	var r := await _request(HTTPClient.METHOD_GET, "/v1/leaderboard?map=%s&rules=%d&season=%d&period=%s&limit=10&device=%s" % [map_id, rules, season, period, Meta.device_id])
	if r["code"] == 200 and r["data"] is Dictionary:
		var d: Dictionary = r["data"]
		d["period"] = period
		d["tag"] = tag
		board_loaded.emit(d)
	else:
		board_loaded.emit({"error": "연결 실패" if r["code"] == 0 else ("기록이 없는 시즌" if r["code"] == 404 else "서버 오류 %d" % r["code"]), "period": period, "tag": tag})


func seasons() -> void:
	var r := await _request(HTTPClient.METHOD_GET, "/v1/seasons")
	seasons_loaded.emit(r["data"] if r["code"] == 200 and r["data"] is Array else [])


func _load_outbox() -> Array:
	return _load_json(OUTBOX_PATH)


func _save_outbox(box: Array) -> void:
	_save_json(OUTBOX_PATH, box)


static func _load_json(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var j: Variant = JSON.parse_string(f.get_as_text())
	return j if j is Array else []


static func _save_json(path: String, box: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(box))
