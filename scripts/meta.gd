class_name Meta
## 게임 밖 요소: 맵, 스킨, 업적, 반응 도감, 선호 표시, 기록, 설정. 저장은 user://best.cfg.

const SAVE_PATH := "user://best.cfg"

const MAPS := {
	"plain": {"name": "평원", "desc": "기본 맵. 진입 방향이 웨이브마다 조금씩 늘어난다", "bg": Color(0.07, 0.08, 0.11), "ring": Color(1, 1, 1, 0.04)},
	"spiral": {"name": "소용돌이", "desc": "구체가 나선을 그리며 들어온다.\n화면에 들어오는 곳과 중앙에 다가오는 방향이 다르다", "bg": Color(0.08, 0.06, 0.12), "ring": Color(0.8, 0.6, 1, 0.06)},
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
	"flower": {"name": "꽃", "need": "wave30"},
	"prism": {"name": "삼각", "need": "got_elem"},
	"halo": {"name": "후광", "need": "solo30"},
}
const TOWER_SKIN_IDS := ["circle", "hex", "gem", "ring", "star", "flower", "prism", "halo"]

const CORE_SKINS := {
	"dot": {"name": "점", "need": ""},
	"eye": {"name": "눈", "need": "wave15"},
	"sun": {"name": "태양", "need": "allmaps"},
	"crown": {"name": "왕관", "need": "boss25"},
	"galaxy": {"name": "은하", "need": "bindu"},
}
const CORE_SKIN_IDS := ["dot", "eye", "sun", "crown", "galaxy"]

## 업적 정의는 Ach.LIST (등급·조건)
static var ACHIEVEMENTS: Dictionary = Ach.names()
static var ACH_IDS: Array = Ach.ids()

# ---------- 저장되는 값 ----------
static var map_id := "plain"
static var rules := 1  # 규칙 버전 (Rules)
static var tower_skin := "circle"
static var core_skin := "dot"
static var map_best := {}  # 맵 id -> [웨이브, 점수]
static var achieved := {}  # 업적 id -> true
static var codex := {}  # 발견한 반응 id -> true
static var favs := {}  # 도감에서 선호 표시한 항목 (Codex.card_key 등) -> true
static var tally := {}  # 업적·도감 수집용 누적 수 중 이 기기 몫 (Ach: "pick:elem:fire" 고른 횟수, "max:..." 한 판 최고)
static var coin_streak := 0  # 운명의 동전 연속 앞면 (판을 넘어 이어짐, 이 기기만)
static var title := ""  # 고른 칭호 (업적 id, 리더보드 닉네임 옆)
static var total_kills := 0
static var games := 0
static var volume := 1.0
static var shake_on := true
static var numbers_on := true
static var symbols_on := true  # 속성 색 위에 첫 글자 표시 (색만으로 구분하기 어려울 때). 새 저장은 켬
static var fx_low := false  # 효과 줄이기: 형태 성질·반응 장판과 터지는 효과를 옅게, 많이 겹칠수록 더 옅게 (기본 끔)
static var fx_dps := 2  # 피해 몫이 작은 오브젝트의 탄·장판을 옅게: 0 그대로 · 1 조금 · 2 보통 · 3 많이 (아래 버튼 줄)
static var skip_n := 3  # 웨이브 넘기기 한 번에 넘길 웨이브 수 (1·3·5·10)
static var skip_danger := true  # 넘기는 중 중앙 체력이 50% 아래로 처음 떨어지면 그 웨이브 뒤 멈춤
static var danger_slow := false  # 중앙 체력이 50%·25% 아래로 처음 떨어질 때 1배속으로 (기본 끔)
static var orb_hp_on := false  # 모든 구체에 체력 숫자 (끄면 고리만, 보스·마우스를 올린 구체는 숫자도)
static var online_on := true  # 판 기록 보내기 (리더보드·사용 통계). 끄면 아무것도 보내지 않음
static var nickname := ""
static var device_id := ""  # 이 기기의 무작위 id (개인정보 아님). 처음 켤 때 만든다
static var guide_on := true  # 처음 생기는 일에 한 줄 안내 (설정에서 끔)
static var guide_seen := {}  # 이미 본 안내 id -> true
static var tutor_next := true  # 다음 새 판은 카드 종류를 웨이브마다 하나씩 연다 (첫 판, 설정에서 다시 켬)
static var notes_seen := ""  # 마지막으로 패치노트를 연 게임 버전 (다르면 시작 화면 버튼 강조)
const FIELD := Vector2(1280, 720)  # 전장 크기. 화면비가 달라도(폰 20:9, 태블릿 4:3) 이 넓이만 쓰고 남는 곳은 배경·UI (main.arena)
static var sim_phone := false  # 점검 도구(tools/shot.gd phone): 데스크톱에서 폰 화면 구성 흉내 (main._phone)
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
	return key(id) + (EASY_TAG if Modes.easy() else "") + (Garden.GROW_TAG if Garden.boosted else "")


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
	rules = val(cfg, "meta", "rules", 1)
	tower_skin = val(cfg, "meta", "tower_skin", "circle")
	core_skin = val(cfg, "meta", "core_skin", "dot")
	line_flip = val(cfg, "meta", "line_flip", false)
	map_best = val(cfg, "meta", "map_best", {})
	achieved = val(cfg, "meta", "achieved", {})
	codex = val(cfg, "meta", "codex", {})
	favs = val(cfg, "meta", "favs", {})
	total_kills = val(cfg, "meta", "kills", 0)
	games = val(cfg, "meta", "games", 0)
	tally = val(cfg, "meta", "tally", {})
	coin_streak = val(cfg, "meta", "coin_streak", 0)
	title = val(cfg, "meta", "title", "")
	volume = val(cfg, "settings", "volume", 1.0)
	shake_on = val(cfg, "settings", "shake", true)
	numbers_on = val(cfg, "settings", "numbers", true)
	symbols_on = val(cfg, "settings", "symbols", false)  # 예전 저장(키가 없던 v0.4.20 이전)은 그대로 끔
	orb_hp_on = val(cfg, "settings", "orb_hp", false)
	danger_slow = val(cfg, "settings", "danger_slow", false)
	skip_n = val(cfg, "settings", "skip_n", 3)
	if not skip_n in [1, 3, 5, 10]:
		skip_n = 3
	skip_danger = val(cfg, "settings", "skip_danger", true)
	fx_low = val(cfg, "settings", "fx_low", false)
	fx_dps = clampi(val(cfg, "settings", "fx_dps", 2), 0, 3)
	online_on = val(cfg, "online", "on", true)
	nickname = val(cfg, "online", "nickname", "")
	device_id = val(cfg, "online", "device", "")
	guide_on = val(cfg, "guide", "on", true)
	guide_seen = val(cfg, "guide", "seen", {})
	tutor_next = val(cfg, "guide", "tutor", games == 0)  # 이미 해 본 저장은 단계별로 열지 않는다
	notes_seen = val(cfg, "guide", "notes_seen", "")
	modes = val(cfg, "meta", "modes", [])
	ui_scale = val(cfg, "settings", "ui_scale", 1.3 if OS.has_feature("mobile") else 1.0)
	if not ui_scale in UI_SCALES:
		ui_scale = 1.0
	volume = clampf(volume, 0.0, 1.0)
	# 예전 저장의 최고 기록은 평원 기록으로 옮긴다
	if not map_best.has("plain") and cfg.has_section_key("best", "wave"):
		map_best["plain"] = [cfg.get_value("best", "wave", 0), cfg.get_value("best", "score", 0)]
	Progress.load_into(cfg)
	fix()
	loaded = true


## 고를 수 없는 값(없는 맵·규칙·모드, 해금 안 된 모양)은 기본값으로. 불러올 때와 다른 기기 진행을 합친 뒤.
static func fix() -> void:
	if not map_id in MAP_IDS:
		map_id = "plain"
	if not rules in Rules.IDS:
		rules = 1
	modes = modes.filter(func(m): return Modes.LIST.has(m))
	if not TOWER_SKINS.has(tower_skin) or not unlocked(TOWER_SKINS[tower_skin]["need"]):
		tower_skin = "circle"
	if not CORE_SKINS.has(core_skin) or not unlocked(CORE_SKINS[core_skin]["need"]):
		core_skin = "dot"
	if title != "" and not (achieved.has(title) and Ach.can_title(title)):
		title = ""


static func save_into(cfg: ConfigFile) -> void:
	cfg.set_value("meta", "map", map_id)
	cfg.set_value("meta", "rules", rules)
	cfg.set_value("meta", "tower_skin", tower_skin)
	cfg.set_value("meta", "core_skin", core_skin)
	cfg.set_value("meta", "line_flip", line_flip)
	cfg.set_value("meta", "map_best", map_best)
	cfg.set_value("meta", "achieved", achieved)
	cfg.set_value("meta", "codex", codex)
	cfg.set_value("meta", "favs", favs)
	cfg.set_value("meta", "kills", total_kills)
	cfg.set_value("meta", "games", games)
	cfg.set_value("meta", "tally", tally)
	cfg.set_value("meta", "coin_streak", coin_streak)
	cfg.set_value("meta", "title", title)
	cfg.set_value("meta", "modes", modes)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "shake", shake_on)
	cfg.set_value("settings", "numbers", numbers_on)
	cfg.set_value("settings", "symbols", symbols_on)
	cfg.set_value("settings", "orb_hp", orb_hp_on)
	cfg.set_value("settings", "danger_slow", danger_slow)
	cfg.set_value("settings", "skip_n", skip_n)
	cfg.set_value("settings", "skip_danger", skip_danger)
	cfg.set_value("settings", "fx_low", fx_low)
	cfg.set_value("settings", "fx_dps", fx_dps)
	cfg.set_value("settings", "ui_scale", ui_scale)
	cfg.set_value("online", "on", online_on)
	cfg.set_value("online", "nickname", nickname)
	cfg.set_value("online", "device", device_id)
	cfg.set_value("guide", "on", guide_on)
	cfg.set_value("guide", "seen", guide_seen)
	cfg.set_value("guide", "tutor", tutor_next)
	cfg.set_value("guide", "notes_seen", notes_seen)
	Progress.save_into(cfg)
