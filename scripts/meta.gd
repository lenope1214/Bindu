class_name Meta
## 게임 밖 요소: 맵, 스킨, 업적, 반응 도감, 기록, 설정. 저장은 user://best.cfg.

const SAVE_PATH := "user://best.cfg"

const MAPS := {
	"plain": {"name": "평원", "desc": "기본 맵. 진입 방향이 웨이브마다 조금씩 늘어난다", "bg": Color(0.07, 0.08, 0.11), "ring": Color(1, 1, 1, 0.04)},
	"spiral": {"name": "소용돌이", "desc": "구체가 나선을 그리며 들어온다.\n들어오는 방향과 맞는 방향이 다르다", "bg": Color(0.08, 0.06, 0.12), "ring": Color(0.8, 0.6, 1, 0.06)},
	"cross": {"name": "십자로", "desc": "처음부터 네 갈래 길.\n구체가 길 위로만 오지만 많고 단단하다", "bg": Color(0.06, 0.09, 0.08), "ring": Color(0.6, 1, 0.8, 0.05)},
	"storm": {"name": "폭풍", "desc": "진입 방향이 웨이브마다 전부 바뀐다.\n대신 구체가 약하다", "bg": Color(0.1, 0.07, 0.06), "ring": Color(1, 0.7, 0.5, 0.05)},
}
const MAP_IDS := ["plain", "spiral", "cross", "storm"]

## 오브젝트 몸체 모양. need: 해금 조건(업적 id), 없으면 처음부터
const TOWER_SKINS := {
	"circle": {"name": "원", "need": ""},
	"hex": {"name": "육각", "need": "wave10"},
	"gem": {"name": "보석", "need": "boss"},
	"ring": {"name": "고리", "need": "codex5"},
	"star": {"name": "별", "need": "wave20"},
}
const TOWER_SKIN_IDS := ["circle", "hex", "gem", "ring", "star"]

const CORE_SKINS := {
	"dot": {"name": "점", "need": ""},
	"eye": {"name": "눈", "need": "wave15"},
	"sun": {"name": "태양", "need": "allmaps"},
}
const CORE_SKIN_IDS := ["dot", "eye", "sun"]

const ACHIEVEMENTS := {
	"first": {"name": "첫걸음", "desc": "웨이브 1 클리어"},
	"wave10": {"name": "버티기", "desc": "웨이브 10 도달"},
	"wave15": {"name": "수호자", "desc": "웨이브 15 도달"},
	"wave20": {"name": "철벽", "desc": "웨이브 20 도달"},
	"boss": {"name": "보스 사냥", "desc": "보스 처치"},
	"codex5": {"name": "연금술사", "desc": "특수 반응 5종 발견 (도감)"},
	"codex9": {"name": "현자", "desc": "특수 반응 모두 발견"},
	"links3": {"name": "연결망", "desc": "한 판에 연결선 3개"},
	"stack5": {"name": "무지개", "desc": "오브젝트 하나에 속성 5종"},
	"combo30": {"name": "연쇄 폭발", "desc": "콤보 30"},
	"allmaps": {"name": "여행자", "desc": "모든 맵에서 웨이브 5 도달"},
}
const ACH_IDS := ["first", "wave10", "wave15", "wave20", "boss", "codex5", "codex9", "links3", "stack5", "combo30", "allmaps"]

# ---------- 저장되는 값 ----------
static var map_id := "plain"
static var rules := 1  # 규칙 버전 (Rules)
static var tower_skin := "circle"
static var core_skin := "dot"
static var map_best := {}  # 맵 id -> [웨이브, 점수]
static var achieved := {}  # 업적 id -> true
static var codex := {}  # 발견한 반응 id -> true
static var total_kills := 0
static var games := 0
static var volume := 1.0
static var shake_on := true
static var numbers_on := true
static var loaded := false


## 기록 키: 버전 1은 맵 id 그대로(예전 기록 유지), 다른 버전은 따로 센다.
static func key(id: String = map_id) -> String:
	return id if rules == 1 else "%s@v%d" % [id, rules]


static func best_of(id: String) -> Array:
	var b: Variant = map_best.get(id, [0, 0])
	return b if b is Array and b.size() >= 2 else [0, 0]


## 저장값 읽기: 형식이 다르면(깨졌거나 손으로 고친 파일) 기본값으로. 숫자는 정수·실수를 서로 받아 준다.
static func val(cfg: ConfigFile, sec: String, key: String, d: Variant) -> Variant:
	var v: Variant = cfg.get_value(sec, key, d)
	if typeof(d) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	if typeof(d) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(v)
	return v if typeof(v) == typeof(d) else d


static func unlocked(need: String) -> bool:
	return need == "" or achieved.has(need)


## 새로 달성한 업적이면 true.
static func achieve(id: String) -> bool:
	if achieved.has(id):
		return false
	achieved[id] = true
	return true


## 반응을 처음 발견하면 true.
static func discover(rid: String) -> bool:
	if codex.has(rid):
		return false
	codex[rid] = true
	return true


static func load_into(cfg: ConfigFile) -> void:
	map_id = val(cfg, "meta", "map", "plain")
	if not map_id in MAP_IDS:
		map_id = "plain"
	rules = val(cfg, "meta", "rules", 1)
	if not rules in Rules.IDS:
		rules = 1
	tower_skin = val(cfg, "meta", "tower_skin", "circle")
	core_skin = val(cfg, "meta", "core_skin", "dot")
	map_best = val(cfg, "meta", "map_best", {})
	achieved = val(cfg, "meta", "achieved", {})
	codex = val(cfg, "meta", "codex", {})
	total_kills = val(cfg, "meta", "kills", 0)
	games = val(cfg, "meta", "games", 0)
	volume = val(cfg, "settings", "volume", 1.0)
	shake_on = val(cfg, "settings", "shake", true)
	numbers_on = val(cfg, "settings", "numbers", true)
	volume = clampf(volume, 0.0, 1.0)
	# 예전 저장의 최고 기록은 평원 기록으로 옮긴다
	if not map_best.has("plain") and cfg.has_section_key("best", "wave"):
		map_best["plain"] = [cfg.get_value("best", "wave", 0), cfg.get_value("best", "score", 0)]
	if not TOWER_SKINS.has(tower_skin) or not unlocked(TOWER_SKINS[tower_skin]["need"]):
		tower_skin = "circle"
	if not CORE_SKINS.has(core_skin) or not unlocked(CORE_SKINS[core_skin]["need"]):
		core_skin = "dot"
	loaded = true


static func save_into(cfg: ConfigFile) -> void:
	cfg.set_value("meta", "map", map_id)
	cfg.set_value("meta", "rules", rules)
	cfg.set_value("meta", "tower_skin", tower_skin)
	cfg.set_value("meta", "core_skin", core_skin)
	cfg.set_value("meta", "map_best", map_best)
	cfg.set_value("meta", "achieved", achieved)
	cfg.set_value("meta", "codex", codex)
	cfg.set_value("meta", "kills", total_kills)
	cfg.set_value("meta", "games", games)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "shake", shake_on)
	cfg.set_value("settings", "numbers", numbers_on)
