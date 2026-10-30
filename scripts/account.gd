class_name Account
## 계정: 이 기기의 비밀값과 서버 토큰 (user://account.cfg, 다른 기기로 넘기지 않음).
## 처음 켜면 기기 id + 비밀값으로 익명 계정을 받고, 나중에 소셜 로그인을 붙이면 같은 계정에 연결된다 (server/app/accounts.py).

const PATH := "user://account.cfg"

static var secret := ""  # 이 기기만 아는 무작위 값 (서버는 해시만 둔다)
static var token := ""
static var expires := 0
static var id := ""  # 서버 계정 id
static var linked: Array = []  # 붙은 소셜 수단 (google·apple …)
static var drops: Array = []  # 서버에서 지워야 하는데 못 지운 진행 중 판 (오프라인일 때 끝낸 판)
static var loaded := false


static func load_file() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		secret = Meta.val(cfg, "account", "secret", "")
		token = Meta.val(cfg, "account", "token", "")
		expires = Meta.val(cfg, "account", "expires", 0)
		id = Meta.val(cfg, "account", "id", "")
		linked = Meta.val(cfg, "account", "linked", [])
		drops = Meta.val(cfg, "account", "drops", [])
	if secret.length() != 64:
		secret = Crypto.new().generate_random_bytes(32).hex_encode()
		save_file()


static func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "secret", secret)
	cfg.set_value("account", "token", token)
	cfg.set_value("account", "expires", expires)
	cfg.set_value("account", "id", id)
	cfg.set_value("account", "linked", linked)
	cfg.set_value("account", "drops", drops.slice(-20))
	cfg.save(PATH)


## 하루 안에 만료될 토큰은 새로 받는다.
static func has_token() -> bool:
	return token != "" and expires > int(Time.get_unix_time_from_system()) + 86400


static func take(d: Dictionary) -> void:
	token = str(d.get("token", ""))
	expires = int(d.get("expires", 0))
	id = str(d.get("account", ""))
	linked = d.get("linked", []) if d.get("linked") is Array else []
	save_file()


static func forget_token() -> void:
	token = ""
	expires = 0
	save_file()


## 설정 화면 한 줄.
static func label() -> String:
	if id == "":
		return "계정: 아직 서버에 연결 안 됨 (온라인이면 켤 때 자동으로 만들어요)"
	var how := "익명 (이 기기)" if linked.is_empty() else ", ".join(linked.map(func(p): return {"google": "Google", "apple": "Apple"}.get(p, p))) + " 연결됨"
	return "계정: %s · 진행은 서버에도 저장돼요" % how
