class_name Meta
## 게임 밖 요소: 맵, 스킨, 업적, 반응 도감, 기록, 설정. 저장은 user://best.cfg.

const SAVE_PATH := "user://best.cfg"

const MAPS := {
	"plain": {"name": "평원", "desc": "기본 맵. 진입 방향이 웨이브마다 조금씩 늘어난다", "bg": Color(0.07, 0.08, 0.11), "ring": Color(1, 1, 1, 0.04)},
	"spiral": {"name": "소용돌이", "desc": "구체가 나선을 그리며 들어온다.\n들어오는 방향과 맞는 방향이 다르다", "bg": Color(0.08, 0.06, 0.12), "ring": Color(0.8, 0.6, 1, 0.06)},
	"cross": {"name": "십자로", "desc": "처음부터 네 갈래 길.\n구체가 길 위로만 오지만 많고 단단하다", "bg": Color(0.06, 0.09, 0.08), "ring": Color(0.6, 1, 0.8, 0.05)},
	"storm": {"name": "폭풍", "desc": "진입 방향이 웨이브마다 전부 바뀐다.\n대신 구체가 약하다", "bg": Color(0.1, 0.07, 0.06), "ring": Color(1, 0.7, 0.5, 0.05)},
	"line": {"name": "회랑", "desc": "가로로 긴 길 하나. 구체가 한쪽 끝에서만 와서\n반대쪽 끝의 문으로 간다. 길이 긴 대신 구체가 많고 빠르고 단단하다", "bg": Color(0.07, 0.07, 0.1), "ring": Color(0.75, 0.8, 1, 0.07)},
}
const MAP_IDS := ["plain", "spiral", "cross", "storm", "line"]
const TRIAL_MAPS := ["line"]  # 새 맵은 사람 시험판·통계를 볼 때까지 "(시험)" (docs/rule-history.md). 업적 "모든 맵"에서도 뺀다

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
	"links3": {"name": "협공진", "desc": "한 판에 협공 오브젝트 3개"},
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
static var symbols_on := true  # 속성 색 위에 첫 글자 표시 (색만으로 구분하기 어려울 때). 새 저장은 켬
static var orb_hp_on := false  # 모든 구체에 체력 숫자 (끄면 고리만, 보스·마우스를 올린 구체는 숫자도)
static var online_on := true  # 판 기록 보내기 (리더보드·사용 통계). 끄면 아무것도 보내지 않음
static var nickname := ""
static var device_id := ""  # 이 기기의 무작위 id (개인정보 아님). 처음 켤 때 만든다
static var guide_on := true  # 처음 생기는 일에 한 줄 안내 (설정에서 끔)
static var guide_seen := {}  # 이미 본 안내 id -> true
static var tutor_next := true  # 다음 새 판은 카드 종류를 웨이브마다 하나씩 연다 (첫 판, 설정에서 다시 켬)
static var notes_seen := ""  # 마지막으로 패치노트를 연 게임 버전 (다르면 시작 화면 버튼 강조)
static var ui_scale := 1.0  # 글자·버튼 크기 (UI_SCALES 중 하나). 폰은 기본 1.3
static var modes: Array = []  # 시작 화면에서 고른 모드 (Modes). 다음 판에도 남는다
const UI_SCALES := [1.0, 1.15, 1.3]
static var loaded := false
const EASY_TAG := "~easy"  # 쉽게 모드를 쓴 판의 기록 키 끝 (run_key)
static var line_flip := false  # 회랑 맵: false면 구체가 오른쪽에서 와서 왼쪽 끝 문으로, true면 반대


## 시작 화면·결과에 쓰는 맵 이름 (시험 중인 맵은 "(시험)").
static func map_name(id: String = map_id) -> String:
	return MAPS[id]["name"] + (" (시험)" if id in TRIAL_MAPS else "")


## 기록 키: 버전 1은 맵 id 그대로(예전 기록 유지), 다른 버전은 따로 센다.
## 최고 기록 키. 2026-10-30에 고친 버전 1·3은 기록을 새로 시작한다 (old: 그 전 규칙의 키).
static func key(id: String = map_id, r: int = -1, old := false) -> String:
	if r < 0:
		r = rules
	if old:
		return id if r == 1 else "%s@v%d" % [id, r]
	return "%s@v%d%s" % [id, r, Rules.REC_TAG]


## 이번 판 기록 키: 쉽게 모드를 쓴 판은 따로 센다 (Modes).
static func run_key(id: String = map_id) -> String:
	return key(id) + (EASY_TAG if Modes.easy() else "")


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
	line_flip = val(cfg, "meta", "line_flip", false)
	map_best = val(cfg, "meta", "map_best", {})
	achieved = val(cfg, "meta", "achieved", {})
	codex = val(cfg, "meta", "codex", {})
	total_kills = val(cfg, "meta", "kills", 0)
	games = val(cfg, "meta", "games", 0)
	volume = val(cfg, "settings", "volume", 1.0)
	shake_on = val(cfg, "settings", "shake", true)
	numbers_on = val(cfg, "settings", "numbers", true)
	symbols_on = val(cfg, "settings", "symbols", false)  # 예전 저장(키가 없던 v0.4.20 이전)은 그대로 끔
	orb_hp_on = val(cfg, "settings", "orb_hp", false)
	online_on = val(cfg, "online", "on", true)
	nickname = val(cfg, "online", "nickname", "")
	device_id = val(cfg, "online", "device", "")
	guide_on = val(cfg, "guide", "on", true)
	guide_seen = val(cfg, "guide", "seen", {})
	tutor_next = val(cfg, "guide", "tutor", games == 0)  # 이미 해 본 저장은 단계별로 열지 않는다
	notes_seen = val(cfg, "guide", "notes_seen", "")
	modes = (val(cfg, "meta", "modes", []) as Array).filter(func(m): return Modes.LIST.has(m))
	ui_scale = val(cfg, "settings", "ui_scale", 1.3 if OS.has_feature("mobile") else 1.0)
	if not ui_scale in UI_SCALES:
		ui_scale = 1.0
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
	cfg.set_value("meta", "line_flip", line_flip)
	cfg.set_value("meta", "map_best", map_best)
	cfg.set_value("meta", "achieved", achieved)
	cfg.set_value("meta", "codex", codex)
	cfg.set_value("meta", "kills", total_kills)
	cfg.set_value("meta", "games", games)
	cfg.set_value("meta", "modes", modes)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "shake", shake_on)
	cfg.set_value("settings", "numbers", numbers_on)
	cfg.set_value("settings", "symbols", symbols_on)
	cfg.set_value("settings", "orb_hp", orb_hp_on)
	cfg.set_value("settings", "ui_scale", ui_scale)
	cfg.set_value("online", "on", online_on)
	cfg.set_value("online", "nickname", nickname)
	cfg.set_value("online", "device", device_id)
	cfg.set_value("guide", "on", guide_on)
	cfg.set_value("guide", "seen", guide_seen)
	cfg.set_value("guide", "tutor", tutor_next)
	cfg.set_value("guide", "notes_seen", notes_seen)
