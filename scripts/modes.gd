class_name Modes
## 모드: 판 전체 난이도를 바꾸는 대신 점수 배율이 달라진다 (2026-10-30 사용자 요청, docs/modes.md).
## 이미 있는 수치(구체 속도·수·체력, 중앙 체력, 카드 수, 새로고침, 특수 구체 시점, 보스)만 바꾸고 새 규칙은 넣지 않는다.
## 규칙 버전 1·3 위에 똑같이 얹는다. 점수 배율 = 고른 모드 배율의 곱 (MUL_MIN~MUL_MAX).
## 처치 점수는 모드 전 체력·수 기준으로 매긴다: 체력·수를 늘린 모드가 배율과 겹쳐 두 번 오르지 않게 (kill_k).
## 쉽게 모드를 하나라도 쓴 판은 리더보드에 올리지 않고, 개인 최고 기록도 따로 센다 (Meta.run_key).
## 배율은 온라인 패치 data.modes.<id>로 바꿀 수 있다. 서버 server/app/validate.py의 MODES도 같은 수치로 맞춘다.

const LIST := {
	"rush": {"name": "질주", "hard": true, "desc": "구체 속도 +20%", "score": 1.30, "vs": "stroll"},
	"swarm": {"name": "물량", "hard": true, "desc": "웨이브 구체 수 +25%", "score": 1.30, "vs": ""},
	"steel": {"name": "강철", "hard": true, "desc": "구체 체력 +30%", "score": 1.30, "vs": "soft"},
	"glass": {"name": "유리 중앙", "hard": true, "desc": "중앙 체력 10 → 5 (보스는 3을 깎음)", "score": 1.25, "vs": "fort"},
	"narrow": {"name": "외길", "hard": true, "desc": "선택지 새로고침 없음", "score": 1.15, "vs": "ease"},
	"early": {"name": "이른 위협", "hard": true, "desc": "저항·굳센 구체가 3웨이브 일찍", "score": 1.15, "vs": ""},
	"angry": {"name": "성난 보스", "hard": true, "desc": "보스 체력 x1.5, 부하를 2배 자주 부름", "score": 1.25, "vs": ""},
	"stroll": {"name": "산책", "hard": false, "desc": "구체 속도 -20%", "score": 0.70, "vs": "rush"},
	"fort": {"name": "든든한 중앙", "hard": false, "desc": "중앙 체력 10 → 20", "score": 0.70, "vs": "glass"},
	"three": {"name": "세 장", "hard": false, "desc": "쉬는 시간에 고르는 카드 2장 → 3장", "score": 0.50, "vs": ""},
	"soft": {"name": "물렁", "hard": false, "desc": "구체 체력 -25%", "score": 0.70, "vs": "steel"},
	"ease": {"name": "여유", "hard": false, "desc": "쉬는 시간마다 새로고침 +2", "score": 0.85, "vs": "narrow"},
}
const ORDER := ["rush", "swarm", "steel", "glass", "narrow", "early", "angry", "stroll", "fort", "three", "soft", "ease"]
const MUL_MIN := 0.2
const MUL_MAX := 2.5
const SWARM := 1.25  # 물량: 웨이브 구체 수
const STEEL := 1.3  # 강철: 구체 체력
const SOFT := 0.75  # 물렁: 구체 체력
const EARLY := 3  # 이른 위협: 저항·굳센 구체가 이만큼 일찍
const ANGRY_HP := 1.5
const ANGRY_MINIONS := 2.0

static var on: Array[String] = []  # 이번 판에 쓰는 모드 (판 도중에는 바뀌지 않는다)


## 고른 모드를 정한다: 모르는 id·겹친 것·반대 쌍의 뒤쪽은 버린다.
static func set_on(ids: Array) -> void:
	on.clear()
	for id in ids:
		if id is String and LIST.has(id) and not id in on and not LIST[id]["vs"] in on:
			on.append(id)


## 모드 창에서 하나를 켜고 끈다. 켜면 반대 모드는 꺼진다.
static func toggle(id: String) -> void:
	if id in on:
		on.erase(id)
	elif LIST.has(id):
		on.erase(LIST[id]["vs"])
		on.append(id)


static func has(id: String) -> bool:
	return id in on


## 모드 하나의 점수 배율 (1.3이면 +30%).
static func score_of(id: String) -> float:
	return Patch.num("modes", id, LIST[id]["score"])


## 점수 배율 (얻는 점수마다 곱한다).
static func mul() -> float:
	var m := 1.0
	for id in on:
		m *= score_of(id)
	return clampf(m, MUL_MIN, MUL_MAX)


## "+30%" / "-25%"
static func pct(m: float) -> String:
	return "%+d%%" % roundi((m - 1.0) * 100.0)


## 쉽게 하는 모드를 하나라도 썼는지 (리더보드에 올리지 않고 기록도 따로).
static func easy() -> bool:
	return on.any(func(id): return not LIST[id]["hard"])


## Rules.apply 뒤에: 규칙 버전 값 위에 모드를 얹는다.
static func apply_rules() -> void:
	if has("swarm"):
		Rules.orb_mul *= SWARM
	Rules.orb_hp *= hp_k()
	if has("three"):
		Rules.picks = 3
	if has("early"):
		Rules.resist_from -= EARLY
		Rules.sturdy_from -= EARLY


## 구체 체력 배율.
static func hp_k() -> float:
	return STEEL if has("steel") else (SOFT if has("soft") else 1.0)


## 처치 점수를 모드 전 기준으로 되돌리는 값: 체력·수·보스 체력·부하 수를 늘리거나 줄인 만큼 나눈다.
static func kill_k(boss: bool, minion: bool) -> float:
	var k := 1.0 / hp_k()
	if has("swarm"):
		k /= SWARM
	if boss:
		k /= boss_hp()
	if minion:
		k /= minion_rate()
	return k


## 구체 속도 배율.
static func speed() -> float:
	return 1.2 if has("rush") else (0.8 if has("stroll") else 1.0)


## 새 판의 중앙 체력.
static func core_max(base: int) -> int:
	return 5 if has("glass") else (20 if has("fort") else base)


## 쉬는 시간의 새로고침 수.
static func rerolls(base: int) -> int:
	return 0 if has("narrow") else (base + 2 if has("ease") else base)


static func boss_hp() -> float:
	return ANGRY_HP if has("angry") else 1.0


## 보스 부하를 부르는 빠르기 배율 (2면 두 배 자주).
static func minion_rate() -> float:
	return ANGRY_MINIONS if has("angry") else 1.0


## "모드 3개 · 점수 x1.25" (없으면 "모드 없음").
static func summary() -> String:
	if on.is_empty():
		return "모드 없음"
	return "모드 %d개 · 점수 x%.2f" % [on.size(), mul()]


## 고른 모드 이름 (ORDER 순서).
static func names() -> String:
	return ", ".join(ORDER.filter(func(id): return id in on).map(func(id): return LIST[id]["name"]))
