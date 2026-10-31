class_name Garden
## 정원 모드: 끝나지 않는 판에서 처치로 이슬을 모아 상점에서 오브젝트를 키우고, 환생해 씨앗을 얻는다.
## 씨앗은 씨앗 나무(일반 판 영구 강화)에 쓴다. 정원에서 속성마다 처치한 수(숙련)는 일반 판 그 속성 피해를 올린다.
## 기획: 2026-10-30 "빈두 정원 모드 세부 기획" (권장안). 수치는 온라인 패치 data.garden.<키>로 조정한다.
## 정원 판은 user://garden.cfg (main의 이어하기 형식 + [run] garden), 씨앗·나무·숙련·분재는 best.cfg [garden].

const RUN_PATH := "user://garden.cfg"
const RETREAT := 5  # 중앙 점이 무너지면 물러나는 웨이브 수
const REBIRTH_FROM := 25  # 환생할 수 있는 최고 웨이브
const SEED_BASE := 20  # 씨앗 = 최고 웨이브 - 20
const OFFLINE_RATE := 0.5  # 꺼 둔 동안: 최근 초당 이슬의 50%
const OFFLINE_MAX := 8.0 * 3600.0  # 최대 8시간치
const MAX_TOWERS := 24
const PERK_EVERY := 10  # 특성은 10웨이브마다
const PERK_WAIT := 30.0  # 특성을 30초 안에 안 고르면 첫 번째를 고른다 (방치 중 멈추지 않게)
const NEXT_DELAY := 3.0  # 웨이브 사이 쉬는 시간 (자동 진행)
const START_DEW := 70.0
const REBIRTH_DEW := 0.10  # 환생 1번마다 이슬 획득 +10% (최대 +100%)
const SHOP_ELEMS := 2  # 상점 속성 카드 수 (하나는 이미 쓰는 속성에서)
const SHOP_OTHERS := 2  # 공격방식·강화·연계 카드 수
const REROLL_COST := 15
const LANE_ORDER := [0.0, PI, PI / 3.0, PI * 4.0 / 3.0, PI * 2.0 / 3.0, PI * 5.0 / 3.0]  # 정원 진입 방향: 늘 같은 자리

## 씨앗 나무: 가지마다 단계별 씨앗 비용과 단계별 설명
const TREE := {
	# 일반 판 효과는 최대한 약하게 (2026-10-31 사용자: 방치형이 일반 판에 과하게 영향 주지 않게)
	"root": {"name": "뿌리", "what": "생존", "cost": [3, 6], "lv": ["중앙 점 체력 +1"]},
	"stem": {"name": "줄기", "what": "화력", "cost": [4, 6, 9, 13, 18], "lv": ["모든 피해 +0.5%"]},
	"leaf": {"name": "잎", "what": "선택", "cost": [10, 15, 25], "lv": ["새로고침 +1 (첫 쉬는 시간)", "첫 쉬는 시간 카드 4장", "첫 쉬는 시간 고르기 +1"]},
	"fruit": {"name": "열매", "what": "특성", "cost": [20, 35], "lv": ["특성 선택지 4개", "판 시작에 특성 1개 무작위"]},
	"bonsai": {"name": "분재", "what": "정원 가져가기", "cost": [30, 50], "lv": ["분재 오브젝트를 속성 Lv1·공격방식 1단계로 놓고 시작", "분재에 강화 1개"]},
}
const TREE_IDS := ["root", "stem", "leaf", "fruit", "bonsai"]
const MASTERY_STEPS := [1000, 5000, 20000, 50000, 100000]  # 숙련 단계를 넘는 처치 수
const MASTERY_PER := 0.006  # 단계마다 그 속성 피해 +0.6% (최대 +3%, 패치 키 mastery_per)

# ---------- 저장되는 값 (best.cfg [garden]) ----------
static var seeds := 0
static var seeds_total := 0
static var rebirths := 0
static var best_ever := 0
static var tree := {}  # 가지 id -> 단계
static var tree_on := true  # 일반 판에 씨앗 나무·숙련을 쓰는지 (끄면 '순수' 기록)
static var mastery := {}  # 속성 키(Patch.ELEM_KEYS) -> 정원에서 처치한 수
static var hero_e := -1  # 영웅 속성 (-1 = 아직 없음). 바꾸기는 환생할 때만 (hero_free)
static var hero_free := true  # 지금 영웅 속성을 고를 수 있는지 (처음·환생 직후)
static var hero_xp := {}  # 속성 키 -> 영웅 경험치 (정원에서 그 속성이 처치한 몫, 속성마다 따로 남음)
static var auto_buy := true  # 자동 정원사: 쉬는 시간에 이슬로 알아서 산다
static var bonsai := {}  # {"e": 속성, "pat": 공격방식, "plv": 레벨, "mods": [강화 id...]} (비면 없음)
static var has_run := false  # 저장된 정원 판이 있는지 (시작 화면 표시용)
static var run_wave := 0
static var run_dew := 0.0

# ---------- 이번 정원 판 (garden.cfg) ----------
static var on := false  # 지금 정원 판인지 (장면을 다시 불러도 남는다)
static var dew := START_DEW
static var best := 0  # 이번 정원(환생 전까지)의 최고 웨이브
static var walls := {}  # 웨이브 -> 그 웨이브에서 물러난 횟수
static var rate := 0.0  # 최근 게임 시간 1초당 이슬 (오프라인 보상)
static var saved_at := 0  # 마지막 저장 시각 (유닉스 초)
static var prev := {}  # 정원에 들어오기 전 시작 화면 설정 {map, rules, modes}

# ---------- 이번 일반 판 ----------
static var boosted := false  # 이번 판에 씨앗 나무·숙련을 쓰는지 (기록 키 ~grow)
const GROW_TAG := "~grow"


static func k(key: String, d: float) -> float:
	return Patch.num("garden", key, d)


static func lv(id: String) -> int:
	return int(tree.get(id, 0))


static func max_lv(id: String) -> int:
	return TREE[id]["cost"].size()


## 다음 단계 비용 (다 올렸으면 -1).
static func next_cost(id: String) -> int:
	var l := lv(id)
	return -1 if l >= max_lv(id) else int(TREE[id]["cost"][l])


static func buy(id: String) -> bool:
	var c := next_cost(id)
	if c < 0 or seeds < c:
		return false
	seeds -= c
	tree[id] = lv(id) + 1
	return true


static func tree_total() -> int:
	var n := 0
	for id in TREE_IDS:
		n += lv(id)
	return n


## 씨앗 나무·숙련이 일반 판에 실제로 무엇이든 주는지.
static func has_power() -> bool:
	if tree_total() > 0:
		return true
	for e in Elem.ALL:
		if mastery_bonus(e) > 0.0:
			return true
	return hero_lv() > 0


# ---------- 영웅 (정원에서 속성 하나를 골라 키운다) ----------

const HERO_MAX := 10


static func hero_key(e: int) -> String:
	return Patch.ELEM_KEYS[Elem.ALL.find(e)]


## 레벨 L에서 L+1로 가는 데 드는 경험치: 100 x 1.5^L (Lv10까지 약 1.1만)
static func hero_need(l: int) -> float:
	return k("hero_xp", 100.0) * pow(1.5, l)


static func hero_lv_of(e: int) -> int:
	if e < 0:
		return 0
	var x := float(hero_xp.get(hero_key(e), 0.0))
	var l := 0
	while l < HERO_MAX and x >= hero_need(l):
		x -= hero_need(l)
		l += 1
	return l


static func hero_lv() -> int:
	return hero_lv_of(hero_e)


## [이번 레벨에서 모은 경험치, 다음 레벨까지 필요한 양] (최대 레벨이면 [0, 0])
static func hero_progress() -> Array:
	var x := float(hero_xp.get(hero_key(hero_e), 0.0)) if hero_e >= 0 else 0.0
	var l := 0
	while l < HERO_MAX and x >= hero_need(l):
		x -= hero_need(l)
		l += 1
	return [0.0, 0.0] if l >= HERO_MAX else [x, hero_need(l)]


static func set_hero(e: int) -> bool:
	if not hero_free or not e in Elem.ALL:
		return false
	hero_e = e
	hero_free = false
	return true


static func add_hero_xp(e: int, n: float) -> void:
	if e != hero_e or e < 0:
		return
	var key := hero_key(e)
	hero_xp[key] = float(hero_xp.get(key, 0.0)) + n


## 정원 안: 영웅 속성이 든 오브젝트 피해 +2%/Lv (여러 속성이면 그 몫만큼)
static func hero_garden_mul(elements: Dictionary) -> float:
	if hero_e < 0 or not elements.has(hero_e):
		return 1.0
	return 1.0 + k("hero_garden", 0.02) * hero_lv() / elements.size()


## 일반 판: 영웅 속성 피해 +0.5%/Lv (최대 +5%, 씨앗 나무를 켠 '성장' 판만)
static func hero_norm_bonus() -> float:
	return k("hero_norm", 0.005) * hero_lv()


## 일반 판 첫 쉬는 시간에 영웅 속성 카드 보장 (Lv5부터)
static func hero_card() -> bool:
	return boosted and hero_e >= 0 and hero_lv() >= int(k("hero_card_lv", 5.0))


## 정원 안 Lv10: 영웅 속성 추가 효과 한 단계 (효과 계산 레벨 +1)
static func hero_eff_bonus(e: int) -> int:
	return 1 if on and e == hero_e and hero_lv() >= HERO_MAX else 0


## 새 일반 판이 씨앗 나무를 쓸지 (시작할 때 정해 판 끝까지).
static func want_boost() -> bool:
	return tree_on and has_power()


static func mastery_lv(e: int) -> int:
	var n := float(mastery.get(Patch.ELEM_KEYS[Elem.ALL.find(e)], 0.0))
	var l := 0
	for s in MASTERY_STEPS:
		if n >= s:
			l += 1
	return l


static func mastery_bonus(e: int) -> float:
	return k("mastery_per", MASTERY_PER) * mastery_lv(e)


static func mastery_next(e: int) -> int:
	var l := mastery_lv(e)
	return -1 if l >= MASTERY_STEPS.size() else MASTERY_STEPS[l]


static func add_mastery(e: int, n: float) -> void:
	var key: String = Patch.ELEM_KEYS[Elem.ALL.find(e)]
	mastery[key] = float(mastery.get(key, 0.0)) + n


## 일반 판 오브젝트 피해 배율: 넣은 속성들의 숙련 보너스 평균.
static func elem_mul(elements: Dictionary) -> float:
	if not boosted or elements.is_empty():
		return 1.0
	var s := 0.0
	for e in elements:
		s += mastery_bonus(e) + (hero_norm_bonus() if e == hero_e else 0.0)
	return 1.0 + s / elements.size()


# ---------- 정원 수치 ----------

## 구체 하나를 처치하면 얻는 이슬. 보스는 10배.
static func kill_dew(w: int, boss: bool) -> float:
	var d := k("dew_kill", 8.0) * pow(k("dew_growth", 1.05), w) * (10.0 if boss else 1.0)
	return d * (1.0 + minf(1.0, REBIRTH_DEW * rebirths))


## 정원 구체 체력 배율: 끝이 없는 판이라 8웨이브부터 웨이브마다 더 단단해져 막히는 곳(벽)이 생긴다.
## 초반은 상점으로 하나씩 사 모으는 동안 물러나지 않게 무르게 시작해 12웨이브에 일반 판과 같아진다 (hp_early).
static func hp_k(w: int) -> float:
	var early := lerpf(k("hp_early", 0.8), 1.0, clampf(w / 12.0, 0.0, 1.0))
	return early * pow(k("hp_growth", 1.10), maxi(0, w - 8))


static func start_dew() -> float:
	return START_DEW + 25.0 * rebirths


static func cost_new(n_towers: int) -> int:
	return roundi(k("cost_new", 20.0) * pow(1.25, n_towers))


static func cost_level(cur: int) -> int:
	return roundi(k("cost_level", 10.0) * pow(1.5, cur))


static func cost_elem(n_elems: int) -> int:
	return roundi(k("cost_elem", 40.0) * pow(2.0, n_elems))


static func cost_pat(t: Tower, id: String) -> int:
	var base := k("cost_pat", 100.0)
	return roundi(base * pow(2.0, t.plv)) if t.pattern == id else roundi(base)


static func cost_mod(t: Tower, id: String) -> int:
	return roundi(k("cost_mod", 60.0) * pow(1.8, t.m(id)))


## 발동 카드: 강화처럼 같은 종류를 겹칠수록 비싸진다.
static func cost_trig(t: Tower, id: String) -> int:
	return roundi(k("cost_trig", 70.0) * pow(1.8, int(t.trigs.get(id, 0))))


static func cost_link(links: int) -> int:
	return roundi(k("cost_link", 80.0) * pow(2.0, links))


## 속성 카드를 그 오브젝트에 겹칠 때 (target이 null이면 새로 놓기).
static func cost_elem_on(target: Tower, e: int, n_towers: int) -> int:
	if target == null:
		return cost_new(n_towers)
	if target.elements.has(e):
		return cost_level(target.lv(e))
	return cost_elem(target.order.size())


static func seeds_for(w: int) -> int:
	return maxi(0, w - SEED_BASE)


static func can_rebirth() -> bool:
	return best >= REBIRTH_FROM


# ---------- 저장 ----------

## 정원에 들어오기 전 시작 화면 맵·규칙으로 돌려 놓는다.
static func restore_prev() -> void:
	if prev.is_empty():
		return
	var mp: Variant = prev.get("map", "plain")
	if mp in Meta.MAP_IDS:
		Meta.map_id = mp
	var r: Variant = prev.get("rules", 1)
	if r in Rules.IDS:
		Meta.rules = r
	Meta.line_flip = prev.get("line_flip", false) == true
	prev = {}

static func reset_run() -> void:
	dew = start_dew()
	best = 0
	walls = {}
	rate = 0.0
	saved_at = 0


static func run_state() -> Dictionary:
	saved_at = int(Time.get_unix_time_from_system())
	return {"dew": dew, "best": best, "walls": walls, "rate": rate, "saved_at": saved_at}


static func load_run(d: Variant) -> void:
	reset_run()
	if not d is Dictionary:
		return
	dew = maxf(0.0, float(d.get("dew", dew)))
	best = maxi(0, int(d.get("best", 0)))
	var wl: Variant = d.get("walls", {})
	walls = wl if wl is Dictionary else {}
	rate = maxf(0.0, float(d.get("rate", 0.0)))
	saved_at = int(d.get("saved_at", 0))


## 꺼 둔 동안 쌓인 이슬 [이슬, 초]. 시계를 되돌렸거나 처음이면 0.
static func offline_gain() -> Array:
	if saved_at <= 0:
		return [0.0, 0.0]
	var secs := clampf(float(int(Time.get_unix_time_from_system()) - saved_at), 0.0, OFFLINE_MAX)
	if secs < 60.0:
		return [0.0, secs]
	return [rate * secs * k("offline", OFFLINE_RATE), secs]


static func load_into(cfg: ConfigFile) -> void:
	seeds = maxi(0, Meta.val(cfg, "garden", "seeds", 0))
	seeds_total = maxi(seeds, Meta.val(cfg, "garden", "seeds_total", 0))
	rebirths = maxi(0, Meta.val(cfg, "garden", "rebirths", 0))
	best_ever = maxi(0, Meta.val(cfg, "garden", "best_ever", 0))
	tree = {}
	var tr: Dictionary = Meta.val(cfg, "garden", "tree", {})
	for id in TREE_IDS:
		if tr.has(id):
			tree[id] = clampi(int(tr[id]), 0, max_lv(id))
	tree_on = Meta.val(cfg, "garden", "tree_on", true)
	var he: int = Meta.val(cfg, "garden", "hero_e", -1)
	hero_e = he if he in Elem.ALL else -1
	hero_free = Meta.val(cfg, "garden", "hero_free", true) or hero_e < 0
	hero_xp = {}
	var hx: Dictionary = Meta.val(cfg, "garden", "hero_xp", {})
	for key in hx:
		if str(key) in Patch.ELEM_KEYS:
			hero_xp[str(key)] = maxf(0.0, float(hx[key]))
	auto_buy = Meta.val(cfg, "garden", "auto_buy2", true)  # 기본 켬 (예전 auto_buy 끔은 무시하고 새 키로)
	mastery = {}
	var ms: Dictionary = Meta.val(cfg, "garden", "mastery", {})
	for key in ms:
		if str(key) in Patch.ELEM_KEYS and (ms[key] is float or ms[key] is int):
			mastery[str(key)] = maxf(0.0, float(ms[key]))
	bonsai = _valid_bonsai(Meta.val(cfg, "garden", "bonsai", {}))
	var pv: Variant = Meta.val(cfg, "garden", "prev", {})
	if not on and pv is Dictionary and not pv.is_empty():
		prev = pv  # 정원에서 게임을 끈 저장: 시작 화면 설정을 돌려 놓는다 (restore_prev)


static func save_into(cfg: ConfigFile) -> void:
	cfg.set_value("garden", "seeds", seeds)
	cfg.set_value("garden", "seeds_total", seeds_total)
	cfg.set_value("garden", "rebirths", rebirths)
	cfg.set_value("garden", "best_ever", best_ever)
	cfg.set_value("garden", "tree", tree)
	cfg.set_value("garden", "tree_on", tree_on)
	cfg.set_value("garden", "mastery", mastery)
	cfg.set_value("garden", "bonsai", bonsai)
	cfg.set_value("garden", "hero_e", hero_e)
	cfg.set_value("garden", "hero_free", hero_free)
	cfg.set_value("garden", "hero_xp", hero_xp)
	cfg.set_value("garden", "auto_buy2", auto_buy)
	cfg.set_value("garden", "prev", prev if on else {})


static func _valid_bonsai(b: Variant) -> Dictionary:
	if not b is Dictionary or not b.get("e") in Elem.ALL or not b.get("pat") in Pat.ALL_IDS or b.get("pat") == "path":
		return {}
	var mods: Array = (b.get("mods", []) as Array).filter(func(m): return Pat.MODS.has(m))
	return {"e": b["e"], "pat": b["pat"], "plv": clampi(int(b.get("plv", 1)), 1, 3), "mods": mods.slice(0, 1)}


## 정원 오브젝트를 분재로 (속성은 가장 높은 레벨, 강화는 많이 넣은 순 2개까지).
static func bonsai_of(t: Tower) -> Dictionary:
	var e: int = t.order[0]
	for x in t.order:
		if t.lv(x) > t.lv(e):
			e = x
	var ms: Array = t.mods.keys()
	ms.sort_custom(func(a, b): return t.mods[a] > t.mods[b])
	return _valid_bonsai({"e": e, "pat": t.pattern if t.pattern != "path" else Pat.DEFAULT, "plv": t.plv, "mods": ms})


static func bonsai_text() -> String:
	if bonsai.is_empty():
		return "없음 (정원 오브젝트를 누르고 [분재로 지정])"
	var s := "%s · %s" % [Elem.NAMES[bonsai["e"]], Pat.pname(bonsai["pat"])]  # 일반 판엔 속성 Lv1·공격방식 1단계로
	var ms: Array = bonsai["mods"]
	if not ms.is_empty():
		s += " · 강화 " + ", ".join(ms.map(func(m): return Pat.MODS[m]["name"]))
	return s


## 시작 화면 [정원] 버튼 글.
static func menu_text() -> String:
	if has_run:
		return "이어하기\n웨이브 %d · 이슬 %s" % [run_wave, short(run_dew)]
	return "꺼 두어도 자라는\n끝없는 판"


static func tree_btn_text() -> String:
	return "씨앗 나무 · 씨앗 %d%s" % [seeds, " · 켬" if want_boost() else (" · 꺼 둠" if has_power() else "")]


## 큰 수를 짧게 (1.2만, 3.4억).
static func short(v: float) -> String:
	if v >= 1e8:
		return "%.1f억" % (v / 1e8)
	if v >= 1e4:
		return "%.1f만" % (v / 1e4)
	return str(int(v))
