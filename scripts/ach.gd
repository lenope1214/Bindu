class_name Ach
## 업적: 정의(등급·조건)와 판 기록. 조건은 모두 "value(stat) >= goal" 하나로 판정한다.
## 누적 수(처치·반응 처치·카드 고른 횟수)와 판마다의 최고값은 Meta.tally(이 기기 몫)에 두고
## 계정 진행 저장(Progress, server/app/progress.py)이 기기마다 큰 값으로 합친다.
##   키 "max:..."  여러 기기 중 가장 큰 값 (한 판 최고 기록)
##   그 밖         기기마다 더한 값 (누적 수, "pick:<통계 키>"는 카드를 고른 횟수 = 도감 수집)
## 새 업적은 LIST에 한 줄. 등급은 TIERS의 예상 달성 비율로 고른다 (기획: 5웨이브 이상 해 본 플레이어 기준).

const TIERS := {
	"common": {"name": "일반", "rate": "30% 이상", "color": Color(0.8, 0.82, 0.86)},
	"rare": {"name": "희귀", "rate": "5~30%", "color": Color(0.45, 0.75, 1.0)},
	"hero": {"name": "영웅", "rate": "1~5%", "color": Color(0.78, 0.5, 1.0)},
	"legend": {"name": "전설", "rate": "0.1~1%", "color": Color(1.0, 0.78, 0.3)},
	"myth": {"name": "신화", "rate": "0.1% 미만", "color": Color(1.0, 0.45, 0.55)},
}
const TIER_IDS := ["common", "rare", "hero", "legend", "myth"]
## 이 등급부터 칭호로 고를 수 있다
const TITLE_FROM := "rare"
## 이 등급은 달성 전 조건을 숨긴다
const HIDE_FROM := "myth"

## group: 업적 탭 묶음. stat이 빈 글자면 게임이 직접 _achieve로 주는 업적 (진행 막대 없음).
## goal -1: 그 분류 전부 (반응·카드 수가 늘어도 맞게)
const LIST := [
	# 누적
	{"id": "kill1k", "name": "사냥꾼 I", "desc": "구체 누적 처치 1,000", "tier": "common", "group": "누적", "stat": "kills", "goal": 1000},
	{"id": "kill10k", "name": "사냥꾼 II", "desc": "구체 누적 처치 10,000", "tier": "rare", "group": "누적", "stat": "kills", "goal": 10000},
	{"id": "kill100k", "name": "사냥꾼 III", "desc": "구체 누적 처치 100,000", "tier": "hero", "group": "누적", "stat": "kills", "goal": 100000},
	{"id": "kill1m", "name": "백만 대군", "desc": "구체 누적 처치 1,000,000", "tier": "myth", "group": "누적", "stat": "kills", "goal": 1000000},
	{"id": "rxk500", "name": "연금 사냥 I", "desc": "특수 반응으로 마무리한 처치 500", "tier": "rare", "group": "누적", "stat": "rx_kills", "goal": 500},
	{"id": "rxk5k", "name": "연금 사냥 II", "desc": "특수 반응으로 마무리한 처치 5,000", "tier": "hero", "group": "누적", "stat": "rx_kills", "goal": 5000},
	{"id": "boss", "name": "보스 사냥", "desc": "보스 처치", "tier": "common", "group": "누적", "stat": "boss_kills", "goal": 1},
	{"id": "boss25", "name": "보스 사냥꾼", "desc": "보스 누적 처치 25", "tier": "rare", "group": "누적", "stat": "boss_kills", "goal": 25},
	{"id": "games10", "name": "손에 익음", "desc": "10판 플레이", "tier": "common", "group": "누적", "stat": "games", "goal": 10},
	{"id": "games50", "name": "단골", "desc": "50판 플레이", "tier": "rare", "group": "누적", "stat": "games", "goal": 50},
	{"id": "games1k", "name": "천 판의 장인", "desc": "1,000판 플레이", "tier": "legend", "group": "누적", "stat": "games", "goal": 1000},
	# 한 판 (쉽게 모드를 쓴 판은 세지 않음, 첫걸음~철벽은 예전부터 모든 판)
	{"id": "first", "name": "첫걸음", "desc": "웨이브 1 클리어", "tier": "common", "group": "한 판", "stat": "", "goal": 1},
	{"id": "wave10", "name": "버티기", "desc": "웨이브 10 도달", "tier": "common", "group": "한 판", "stat": "wave", "goal": 10},
	{"id": "wave15", "name": "수호자", "desc": "웨이브 15 도달", "tier": "rare", "group": "한 판", "stat": "wave", "goal": 15},
	{"id": "wave20", "name": "철벽", "desc": "웨이브 20 도달", "tier": "rare", "group": "한 판", "stat": "wave", "goal": 20},
	{"id": "wave25", "name": "불굴", "desc": "웨이브 25 도달", "tier": "hero", "group": "한 판", "stat": "wave", "goal": 25},
	{"id": "wave30", "name": "불멸", "desc": "웨이브 30 도달", "tier": "hero", "group": "한 판", "stat": "wave", "goal": 30},
	{"id": "wave40", "name": "끝없는 싸움", "desc": "웨이브 40 도달", "tier": "legend", "group": "한 판", "stat": "wave", "goal": 40},
	{"id": "wave100", "name": "끝없는 밤", "desc": "웨이브 100 도달", "tier": "myth", "group": "한 판", "stat": "wave", "goal": 100},
	{"id": "combo30", "name": "연쇄 폭발", "desc": "콤보 30 달성", "tier": "rare", "group": "한 판", "stat": "max:combo", "goal": 30},
	{"id": "combo1k", "name": "끝없는 연쇄", "desc": "콤보 1,000 달성", "tier": "legend", "group": "한 판", "stat": "max:combo", "goal": 1000},
	# 2026-10-31 죽지 않는 봇 웨이브 40까지: 1초 최다 처치 12·한 판 처치 1,381·콤보 103·반응 16종 → 몰살·대량 학살 목표를 낮추고 등급을 올림
	{"id": "burst20", "name": "몰살", "desc": "1초 안에 구체 20마리 처치", "tier": "hero", "group": "한 판", "stat": "max:burst", "goal": 20},
	{"id": "burst100", "name": "백 마리 한 방", "desc": "1초 안에 구체 100마리 처치", "tier": "myth", "group": "한 판", "stat": "max:burst", "goal": 100},
	{"id": "run1k", "name": "대량 학살", "desc": "한 판 처치 1,000", "tier": "hero", "group": "한 판", "stat": "max:run_kills", "goal": 1000},
	{"id": "lowhp", "name": "기사회생", "desc": "중앙 체력 10% 이하로 웨이브 클리어", "tier": "rare", "group": "한 판", "stat": "max:lowhp", "goal": 1},
	{"id": "calm10", "name": "철옹성", "desc": "중앙 피해 없이 연속 10웨이브 클리어", "tier": "rare", "group": "한 판", "stat": "max:calm", "goal": 10},
	{"id": "needle10", "name": "바늘구멍", "desc": "중앙 체력 1인 채로 연속 10웨이브 클리어", "tier": "legend", "group": "한 판", "stat": "max:needle", "goal": 10},
	{"id": "skip10", "name": "넘기기 달인", "desc": "웨이브 넘기기 10개를 멈추지 않고 끝까지", "tier": "rare", "group": "한 판", "stat": "max:skip", "goal": 10},
	{"id": "hard15", "name": "고수의 길", "desc": "어렵게 모드(쉽게 없이)로 웨이브 15 도달", "tier": "rare", "group": "한 판", "stat": "max:hard", "goal": 15},
	{"id": "bossfast10", "name": "보스 순살", "desc": "한 판에 보스 10마리를 각각 나온 지 5초 안에 처치", "tier": "legend", "group": "한 판", "stat": "max:boss_fast", "goal": 10},
	# 조합
	{"id": "links3", "name": "협공진", "desc": "한 판에 협공을 넣은 오브젝트 3개", "tier": "rare", "group": "조합", "stat": "", "goal": 1},
	{"id": "stack5", "name": "무지개", "desc": "오브젝트 하나에 속성 5종", "tier": "rare", "group": "조합", "stat": "", "goal": 1},
	{"id": "crowd20", "name": "군단", "desc": "오브젝트 12개 이상으로 웨이브 20 도달", "tier": "hero", "group": "조합", "stat": "max:crowd", "goal": 20},
	{"id": "mono15", "name": "한 우물", "desc": "한 판 내내 속성 1종만으로 웨이브 15 도달", "tier": "hero", "group": "조합", "stat": "max:mono", "goal": 15},
	{"id": "wide15", "name": "팔방미인", "desc": "한 판에 속성 8종 이상 쓰고 웨이브 15 도달", "tier": "hero", "group": "조합", "stat": "max:wide", "goal": 15},
	{"id": "rxs15", "name": "연금 공방", "desc": "한 판에 특수 반응 15종 만들기", "tier": "rare", "group": "조합", "stat": "max:rxs", "goal": 15},
	{"id": "bossrx", "name": "보스 연금술", "desc": "특수 반응으로 보스 마무리", "tier": "hero", "group": "조합", "stat": "max:boss_rx", "goal": 1},
	{"id": "solo30", "name": "외로운 탑", "desc": "한 판 내내 오브젝트 1개만으로 웨이브 30 도달", "tier": "legend", "group": "조합", "stat": "max:solo", "goal": 30},
	{"id": "flawless30", "name": "무결", "desc": "한 판 내내 중앙 피해 0으로 웨이브 30 도달", "tier": "legend", "group": "조합", "stat": "max:flawless", "goal": 30},
	{"id": "pure20", "name": "순수 연금", "desc": "웨이브 20까지 처치의 90% 이상을 특수 반응으로 마무리", "tier": "legend", "group": "조합", "stat": "max:pure", "goal": 1},
	{"id": "rainbow30", "name": "무지개 군단", "desc": "속성이 모두 다른 오브젝트 14개로 웨이브 30 도달", "tier": "legend", "group": "조합", "stat": "max:rainbow", "goal": 30},
	{"id": "norr40", "name": "금욕", "desc": "새로고침을 한 번도 안 쓰고 웨이브 40 도달", "tier": "legend", "group": "조합", "stat": "max:norr", "goal": 40},
	{"id": "coin10", "name": "동전의 신", "desc": "운명의 동전 10번 연속 앞면 (판을 넘어 이어짐)", "tier": "legend", "group": "조합", "stat": "max:coin", "goal": 10},
	{"id": "rxsall", "name": "연금술의 끝", "desc": "한 판에 특수 반응 모두 만들기", "tier": "myth", "group": "조합", "stat": "max:rxs", "goal": -1},
	# 맵
	{"id": "allmaps", "name": "여행자", "desc": "모든 맵에서 웨이브 5 도달", "tier": "rare", "group": "맵", "stat": "", "goal": 1},
	{"id": "maps15", "name": "여행자 II", "desc": "모든 맵에서 웨이브 15 도달", "tier": "hero", "group": "맵", "stat": "maps15", "goal": -1},
	{"id": "hardall30", "name": "모든 길의 끝", "desc": "모든 맵에서 어렵게 모드로 웨이브 30 도달", "tier": "myth", "group": "맵", "stat": "maps_hard30", "goal": -1},
	# 수집 (도감)
	{"id": "codex5", "name": "연금술사", "desc": "특수 반응 5종 발견 (도감)", "tier": "common", "group": "수집", "stat": "codex", "goal": 5},
	{"id": "codex9", "name": "현자", "desc": "특수 반응 모두 발견", "tier": "hero", "group": "수집", "stat": "codex", "goal": -1},
	{"id": "got_elem", "name": "속성 수집가", "desc": "속성 카드 모두 골라 보기", "tier": "hero", "group": "수집", "stat": "got:elem", "goal": -1},
	{"id": "got_pat", "name": "공격방식 수집가", "desc": "공격방식 카드 모두 골라 보기", "tier": "hero", "group": "수집", "stat": "got:pat", "goal": -1},
	{"id": "got_mod", "name": "강화 수집가", "desc": "강화 카드 모두 골라 보기", "tier": "rare", "group": "수집", "stat": "got:mod", "goal": -1},
	{"id": "got_link", "name": "연계 수집가", "desc": "연계 카드 모두 골라 보기", "tier": "rare", "group": "수집", "stat": "got:link", "goal": -1},
	{"id": "got_trig", "name": "발동 수집가", "desc": "발동 카드 모두 골라 보기", "tier": "rare", "group": "수집", "stat": "got:trig", "goal": -1},
	{"id": "got_perk", "name": "특성 수집가", "desc": "특성 모두 골라 보기", "tier": "rare", "group": "수집", "stat": "got:perk", "goal": -1},
	{"id": "bindu", "name": "빈두", "desc": "다른 업적 모두 달성", "tier": "myth", "group": "수집", "stat": "achs", "goal": -1},
]
const GROUPS := ["누적", "한 판", "조합", "맵", "수집"]

## main.PERKS의 id (main이 넣는다: 수집 분모)
static var perk_ids: Array = []
## 진행 중 판의 처치 (게임 오버 전에도 누적 처치 업적이 바로 되게)
static var live_kills := 0
## 다른 기기의 몫 {기기 id: {키: 수}} (Progress가 채움). 이 기기 몫은 Meta.tally
static var others := {}

## 판 기록. 이어하기 저장에 "ach_run"으로 들어간다
static var run := {}
## 최근 1초 처치 시각 (게임 시간)
static var _recent: Array[float] = []


static func by_id(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id:
			return a
	return {}


## Meta.ACHIEVEMENTS 형식 {id: {name, desc}}.
static func names() -> Dictionary:
	var d := {}
	for a in LIST:
		d[a["id"]] = {"name": a["name"], "desc": a["desc"]}
	return d


static func ids() -> Array:
	return LIST.map(func(a): return a["id"])


static func tier_rank(t: String) -> int:
	return TIER_IDS.find(t)


static func can_title(id: String) -> bool:
	var a := by_id(id)
	return not a.is_empty() and tier_rank(a["tier"]) >= tier_rank(TITLE_FROM)


static func hidden(a: Dictionary) -> bool:
	return tier_rank(a["tier"]) >= tier_rank(HIDE_FROM) and not Meta.achieved.has(a["id"])


# ---------- 누적 수 ----------

static func add(key: String, n := 1) -> void:
	Meta.tally[key] = int(Meta.tally.get(key, 0)) + n


static func raise(key: String, v: int) -> void:
	if v > int(Meta.tally.get(key, 0)):
		Meta.tally[key] = v


## 모든 기기를 합친 값 ("max:"는 가장 큰 값).
static func total(key: String) -> int:
	var mx := key.begins_with("max:")
	var v := int(Meta.tally.get(key, 0))
	for dev in others:
		var o := int((others[dev] as Dictionary).get(key, 0))
		v = maxi(v, o) if mx else v + o
	return v


## 카드 분류의 통계 키 목록 (도감 수집 분모).
static func cat_keys(cat: String) -> Array:
	match cat:
		"elem": return Patch.ELEM_KEYS.map(func(k): return "elem:" + k)
		"pat": return Pat.ALL_IDS.filter(func(id): return id != Pat.DEFAULT).map(func(id): return "pat:" + id)
		"mod": return Pat.MOD_IDS.map(func(id): return "mod:" + id)
		"link": return Pat.LINK_IDS.map(func(id): return "link:" + id)
		"trig": return Pat.TRIG_IDS.map(func(id): return "trig:" + id)
		"perk": return perk_ids.map(func(id): return "perk:" + id)
	return []


## 카드를 고른 횟수 (모든 기기).
static func picks(stat_key: String) -> int:
	return total("pick:" + stat_key)


static func got(cat: String) -> int:
	return cat_keys(cat).filter(func(k): return picks(k) > 0).size()


## 모든 맵(시험 맵 제외) 중 조건을 넘긴 맵 수.
static func _maps(f: Callable) -> int:
	return Meta.MAP_IDS.filter(func(id): return not id in Meta.TRIAL_MAPS and f.call(id)).size()


static func _map_count() -> int:
	return _maps(func(_id): return true)


## 기록 키 중 쉽게 모드가 아닌 그 맵의 최고 웨이브.
static func _map_wave(id: String) -> int:
	var w := 0
	for k in Meta.map_best:
		var s := str(k)
		if (s == id or s.begins_with(id + "@")) and not s.ends_with(Meta.EASY_TAG):
			w = maxi(w, int(Meta.best_of(s)[0]))
	return w


static func goal(a: Dictionary) -> int:
	if int(a["goal"]) >= 0:
		return int(a["goal"])
	match a["stat"]:
		"max:rxs", "codex": return Elem.REACTIONS.size()
		"maps15", "maps_hard30": return _map_count()
		"achs": return LIST.size() - 1
	if str(a["stat"]).begins_with("got:"):
		return cat_keys(str(a["stat"]).substr(4)).size()
	return 1


static func value(stat: String) -> int:
	match stat:
		"kills": return Meta.total_kills + live_kills
		"games": return Meta.games
		"codex": return Meta.codex.size()
		"wave":
			var w := total("max:wave")
			for id in Meta.MAP_IDS:
				w = maxi(w, _map_wave(id))
			return w
		"maps15": return _maps(func(id): return _map_wave(id) >= 15)
		"maps_hard30": return _maps(func(id): return total("max:hard:" + id) >= 30)
		"achs": return Meta.achieved.keys().filter(func(k): return k != "bindu").size()
	if stat.begins_with("got:"):
		return got(stat.substr(4))
	return total(stat)


## 조건을 넘긴 업적 id (아직 안 받은 것만).
static func newly_met() -> Array:
	var out := []
	for a in LIST:
		if a["stat"] != "" and not Meta.achieved.has(a["id"]) and value(a["stat"]) >= goal(a):
			out.append(a["id"])
	return out


# ---------- 판 기록 ----------

static func new_run() -> void:
	run = {"towers_max": 0, "elems": [], "rerolls": 0, "core_lost": 0, "calm": 0, "needle": 0, "rx_kills": 0, "kills": 0,
		"rxs": [], "boss_fast": 0}
	_recent.clear()
	live_kills = 0


static func load_run(d: Variant) -> void:
	new_run()
	if d is Dictionary:
		for k in run:
			if d.has(k) and typeof(d[k]) in [typeof(run[k]), TYPE_FLOAT, TYPE_INT]:
				run[k] = d[k] if not run[k] is int else int(d[k])
	live_kills = int(run["kills"])


static func _counts() -> bool:
	return not Modes.easy()


## 카드·특성을 골랐다 (도감 수집).
static func on_pick(stat_key: String) -> void:
	if stat_key == "" or stat_key.begins_with("cata:"):
		return
	add("pick:" + stat_key)
	if stat_key.begins_with("elem:"):
		var e := stat_key.substr(5)
		if not e in run["elems"]:
			run["elems"].append(e)


static func on_reroll() -> void:
	run["rerolls"] = int(run["rerolls"]) + 1


## 운명의 동전 (판을 넘어 이어지는 연속 앞면).
static func on_coin(heads: bool) -> void:
	Meta.coin_streak = Meta.coin_streak + 1 if heads else 0
	raise("max:coin", Meta.coin_streak)


static func on_kill(o: Orb, now: float, combo: int) -> void:
	run["kills"] = int(run["kills"]) + 1
	live_kills = int(run["kills"])
	var rx: bool = o.last_rx
	if rx:
		run["rx_kills"] = int(run["rx_kills"]) + 1
		add("rx_kills")
	if o.kind == Orb.Kind.BOSS:
		add("boss_kills")
		if rx:
			raise("max:boss_rx", 1)
		if now - o.born <= 5.0:
			run["boss_fast"] = int(run["boss_fast"]) + 1
	_recent.append(now)
	while not _recent.is_empty() and now - _recent[0] > 1.0:
		_recent.pop_front()
	if _counts():
		raise("max:burst", _recent.size())
		raise("max:combo", combo)
		raise("max:run_kills", int(run["kills"]))
		raise("max:boss_fast", int(run["boss_fast"]))


static func on_core_hit(d: int) -> void:
	run["core_lost"] = int(run["core_lost"]) + d


static func on_reactions(rids: Array) -> void:
	for id in rids:
		if not id in run["rxs"]:
			run["rxs"].append(id)
	if _counts():
		raise("max:rxs", run["rxs"].size())


## 웨이브 시작: "웨이브 N 도달" 조건들 (지금 오브젝트로 그 웨이브에 들어섰다).
static func on_wave_start(w: int, towers: Array, map_id: String) -> void:
	var n := towers.size()
	run["towers_max"] = maxi(int(run["towers_max"]), n)
	for t in towers:
		for e in t.order:
			var k: String = Patch.ELEM_KEYS[Elem.ALL.find(e)]
			if not k in run["elems"]:
				run["elems"].append(k)
	if not _counts():
		return
	raise("max:wave", w)
	if Modes.on.any(func(id): return Modes.LIST[id]["hard"]):
		raise("max:hard", w)
		raise("max:hard:" + map_id, w)
	if n >= 12:
		raise("max:crowd", w)
	if int(run["towers_max"]) <= 1 and n == 1:
		raise("max:solo", w)
	if run["elems"].size() == 1:
		raise("max:mono", w)
	if run["elems"].size() >= 8:
		raise("max:wide", w)
	if int(run["core_lost"]) == 0:
		raise("max:flawless", w)
	if int(run["rerolls"]) == 0:
		raise("max:norr", w)
	var mains := {}
	for t in towers:
		if not t.order.is_empty():
			mains[t.order[0]] = true
	if n >= 14 and mains.size() >= 14:
		raise("max:rainbow", w)


## 웨이브 클리어.
static func on_wave_clear(w: int, wave_dmg: int, core_hp: int, core_max: int) -> void:
	run["calm"] = int(run["calm"]) + 1 if wave_dmg == 0 else 0
	run["needle"] = int(run["needle"]) + 1 if core_hp == 1 else 0
	if not _counts():
		return
	raise("max:calm", int(run["calm"]))
	raise("max:needle", int(run["needle"]))
	if core_hp * 10 <= core_max:
		raise("max:lowhp", 1)
	if w == 20 and int(run["kills"]) > 0 and float(run["rx_kills"]) / float(run["kills"]) >= 0.9:
		raise("max:pure", 1)


## 넘기기를 끝냈다: 멈추지 않고 넘긴 웨이브 수.
static func on_skip_done(n: int) -> void:
	if _counts():
		raise("max:skip", n)
