class_name Patch
## 서버에서 받은 JSON 데이터 패치: 규칙·특성·카드 확률·속성/공격방식 피해 배율 덮어쓰기.
## 서명(OnlineConfig.PATCH_PUBLIC_KEY)이 맞을 때만 쓰고, 없거나 틀리면 내장 값 그대로.
## 받은 패치는 다음 판부터 적용된다(판 도중에 수치가 바뀌지 않게): accept()로 pending에 두고 commit()으로 적용.
## 키 설명은 server/README.md.

const CACHE_PATH := "user://patch.json"
## elem_dmg 키 → Elem 값 (Elem.ALL 순서)
const ELEM_KEYS := ["fire", "wood", "water", "electric", "wind", "ice", "earth", "dark", "light", "poison", "metal"]

static var id := 0  # 지금 적용된 패치 번호 (0: 내장 값)
static var data := {}
static var pending: Variant = null  # 받았지만 아직 적용 안 한 {"id", "data"}
static var elem_mul := {}  # Elem → 피해 배율
static var pat_mul := {}  # 공격방식 id → 피해 배율
static var cache_loaded := false


## 켤 때 한 번: 지난번에 받아 둔 패치를 다시 확인해서 쓴다 (오프라인이어도 적용).
static func load_cache() -> void:
	if cache_loaded:
		return
	cache_loaded = true
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	if j is Dictionary and accept(str(j.get("payload", "")), str(j.get("sig", "")), false):
		commit()


static func verify(payload: String, sig: String, pem: String = OnlineConfig.PATCH_PUBLIC_KEY) -> bool:
	if pem == "" or payload == "" or sig == "":
		return false
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, payload.sha256_buffer(), Marshalls.base64_to_raw(sig), key)


## 서버가 준 패치: 서명이 맞으면 pending에 두고 저장. 틀리면 무시.
static func accept(payload: String, sig: String, save := true) -> bool:
	if not verify(payload, sig):
		push_warning("패치 서명이 맞지 않아 무시합니다")
		return false
	var j: Variant = JSON.parse_string(payload)
	if not j is Dictionary or not j.get("data") is Dictionary:
		return false
	pending = {"id": int(j.get("id", 0)), "data": j["data"]}
	if save:
		var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"payload": payload, "sig": sig}))
	return true


## 서버에 맞는 패치가 없으면 내장 값으로 돌아간다 (다음 판부터).
static func clear() -> void:
	pending = {"id": 0, "data": {}}
	if FileAccess.file_exists(CACHE_PATH):
		DirAccess.remove_absolute(CACHE_PATH)


## 새 판을 시작할 때(Rules.apply 전에) 부른다.
static func commit() -> void:
	if pending == null:
		return
	id = pending["id"]
	data = pending["data"]
	pending = null
	elem_mul.clear()
	pat_mul.clear()
	var ed: Variant = data.get("elem_dmg", {})
	if ed is Dictionary:
		for k in ed:
			var i := ELEM_KEYS.find(str(k))
			if i >= 0 and (ed[k] is float or ed[k] is int):
				elem_mul[Elem.ALL[i]] = float(ed[k])
	var pd: Variant = data.get("pat_dmg", {})
	if pd is Dictionary:
		for k in pd:
			if pd[k] is float or pd[k] is int:
				pat_mul[str(k)] = float(pd[k])


## data[section][key] 숫자 (없으면 d).
static func num(section: String, key: String, d: float) -> float:
	var s: Variant = data.get(section)
	if s is Dictionary:
		var v: Variant = s.get(key)
		if v is float or v is int:
			return float(v)
	return d


## data[section][key] 글자 (없으면 d). section이 ""이면 data[key].
static func text(section: String, key: String, d: String) -> String:
	var s: Variant = data if section == "" else data.get(section)
	if s is Dictionary and s.get(key) is String and s[key] != "":
		return s[key]
	return d


## 규칙 버전 v에 덮어쓸 값: rules.all 위에 rules["v"].
static func rules_for(v: int) -> Dictionary:
	var out := {}
	var r: Variant = data.get("rules")
	if r is Dictionary:
		for k in ["all", str(v)]:
			if r.get(k) is Dictionary:
				out.merge(r[k], true)
	return out
