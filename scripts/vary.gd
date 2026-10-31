class_name Vary
## 판마다 다른 흐름 (2026-10-31 사용자 요청 "최고점이 하나로 수렴하지 않게", 시험).
## 기획 docs/vary.md. 세 가지를 일반 판(랭크·도파민)에 얹는다. 정원·멀티플레이·첫 판(튜토리얼)은 끔.
## 1) 봉인: 판 시작 때 속성·공격방식·연계 몇 개가 이번 판 선택지에 안 나온다. 25·50웨이브에 하나씩 풀린다.
## 2) 웨이브 이벤트: 10웨이브마다 다음 10웨이브에 걸리는 사건 하나 (한 웨이브 전에 예고).
## 3) 적응 구체: 30웨이브부터 직전 5웨이브 피해 1위 속성·공격방식에 저항이 쌓인다 (오브젝트 피해 최대 -20%).
## 수치는 온라인 패치 rules의 vary_* 키 (Rules.TUNE).

const EVENTS := {
	"eclipse": {"name": "일식", "desc": "빛 피해 -{m}%, 어둠 피해 +{p}%"},
	"white": {"name": "백야", "desc": "어둠 피해 -{m}%, 빛 피해 +{p}%"},
	"flow": {"name": "기운의 흐름", "desc": "{up} 피해 +{p}%, {down} 피해 -{m}%"},
	"form": {"name": "형태의 날", "desc": "{up} 피해 +{p}%, {down} 피해 -{m}%"},
	"gold": {"name": "황금 무리", "desc": "처치 점수 x2, 구체 속도 +15%"},
	"shell": {"name": "굳은 껍질", "desc": "모든 구체가 굳셈(밀기·감속·기절·냉기 절반), 체력 -15%"},
	"swarm": {"name": "증식", "desc": "모든 구체가 죽으면 둘로 나뉨, 체력 -25%"},
}
const EVENT_IDS := ["eclipse", "white", "flow", "form", "gold", "shell", "swarm"]
const UNSEAL_WAVES := [25, 50]
const ADAPT_HIST := 5  # 적응: 이만큼의 지난 웨이브 피해로 1위를 정한다

static var on := false
static var sealed := {"elem": [], "pat": [], "link": []}
static var event := {}  # 지금 걸린 이벤트 {"id", "el": {속성: 배율}, "pt": {공격방식: 배율}}
static var next_event := {}  # 예고된 다음 이벤트
static var adapt_el := {}  # 속성 -> 저항 (0~vary_adapt_max)
static var adapt_pt := {}  # 공격방식 -> 저항
static var hist: Array = []  # 지난 웨이브 피해 [{"e": {속성: 피해}, "p": {공격방식: 피해}}]


## 새 판. use: 이 판에 켤지 (main이 정원·멀티·튜토리얼을 거른다)
static func new_run(use: bool) -> void:
	on = use and Rules.t("vary_on") > 0.0 and OS.get_environment("VARY") != "0"
	sealed = {"elem": [], "pat": [], "link": []}
	event = {}
	next_event = {}
	adapt_el = {}
	adapt_pt = {}
	hist = []
	if not on:
		return
	# 맵 친화 카드(MapRule)는 봉인하지 않는다
	sealed["elem"] = _pick(_no_aff("elem", Elem.ALL), int(Rules.t("vary_seal_elem")))
	sealed["pat"] = _pick(_no_aff("pat", Pat.PATTERN_IDS.slice(1)), int(Rules.t("vary_seal_pat")))
	sealed["link"] = _pick(_no_aff("link", Pat.LINK_IDS), int(Rules.t("vary_seal_link")))


static func _no_aff(kind: String, arr: Array) -> Array:
	return arr.filter(func(x): return not MapRule.is_aff(kind, x))


static func _pick(arr: Array, n: int) -> Array:
	var a := arr.duplicate()
	a.shuffle()
	return a.slice(0, clampi(n, 0, a.size() - 1))  # 하나는 늘 남긴다


static func is_sealed(kind: String, id: Variant) -> bool:
	return on and sealed.has(kind) and id in sealed[kind]


## 봉인 안 된 것만 (모두 봉인이면 원래 목록)
static func open(kind: String, arr: Array) -> Array:
	if not on:
		return arr
	var out := arr.filter(func(x): return not x in sealed[kind])
	return out if not out.is_empty() else arr


static func count() -> int:
	return sealed["elem"].size() + sealed["pat"].size() + sealed["link"].size()


## 봉인 글: "불·물 · 혼불·벽 · 협공"
static func sealed_text() -> String:
	var parts := PackedStringArray()
	if not sealed["elem"].is_empty():
		parts.append("·".join(sealed["elem"].map(func(e): return Elem.NAMES[e])))
	if not sealed["pat"].is_empty():
		parts.append("·".join(sealed["pat"].map(func(p): return Pat.pname(p))))
	if not sealed["link"].is_empty():
		parts.append("·".join(sealed["link"].map(func(l): return Pat.LINKS[l]["name"])))
	return " / ".join(parts)


# ---------- 쉬는 시간 ----------

## 쉬는 시간 시작 (w: 방금 끝낸 웨이브). 알릴 글 목록을 돌려준다.
static func rest(w: int) -> Array:
	var msgs: Array = []
	if not on:
		return msgs
	if w in UNSEAL_WAVES and count() > 0:
		var kinds := sealed.keys().filter(func(k): return not sealed[k].is_empty())
		var k: String = kinds.pick_random()
		var id: Variant = sealed[k].pick_random()
		sealed[k].erase(id)
		msgs.append("봉인 풀림: %s" % _name(k, id))
	var every := maxi(2, int(Rules.t("vary_event_every")))
	if w >= every and w % every == 0:
		if next_event.is_empty():
			next_event = _roll_event()  # 예고 없이 시작한 판 (10웨이브 시작 등)
		event = next_event
		next_event = {}
		msgs.append("이벤트 %s (웨이브 %d~%d): %s" % [ename(event), w + 1, w + every, edesc(event)])
	if (w + 1) % every == 0 and next_event.is_empty():
		next_event = _roll_event()
		msgs.append("웨이브 %d가 끝나면 이벤트 %s: %s" % [w + 1, ename(next_event), edesc(next_event)])
	return msgs


static func _name(k: String, id: Variant) -> String:
	match k:
		"elem": return Elem.NAMES[id]
		"pat": return Pat.pname(id)
	return Pat.LINKS[id]["name"]


static func _k() -> float:
	return Rules.t("vary_event_k") * (1.5 if Rules.version == 3 else 1.0)  # 도파민 모드는 더 요란하게


static func _roll_event() -> Dictionary:
	var ids := EVENT_IDS.duplicate()
	if not event.is_empty():
		ids.erase(event["id"])  # 같은 이벤트 연달아 안 나옴
	var id: String = ids.pick_random()
	var k := _k()
	var ev := {"id": id, "el": {}, "pt": {}}
	match id:
		"eclipse":
			ev["el"] = {Elem.LIGHT: 1.0 - k, Elem.DARK: 1.0 + k}
		"white":
			ev["el"] = {Elem.DARK: 1.0 - k, Elem.LIGHT: 1.0 + k}
		"flow":
			var es := Elem.ALL.duplicate()
			es.shuffle()
			ev["el"] = {es[0]: 1.0 + k, es[1]: 1.0 + k, es[2]: 1.0 - k}
		"form":
			var ps: Array = Pat.PATTERN_IDS.duplicate()
			ps.shuffle()
			ev["pt"] = {ps[0]: 1.0 + k, ps[1]: 1.0 + k, ps[2]: 1.0 - k}
	return ev


static func ename(ev: Dictionary) -> String:
	return EVENTS[ev["id"]]["name"] if not ev.is_empty() else ""


static func edesc(ev: Dictionary) -> String:
	if ev.is_empty():
		return ""
	var up := PackedStringArray()
	var down := PackedStringArray()
	var p := 0
	var m := 0
	for e in ev["el"]:
		(up if ev["el"][e] > 1.0 else down).append(Elem.NAMES[e])
	for id in ev["pt"]:
		(up if ev["pt"][id] > 1.0 else down).append(Pat.pname(id))
	for v in ev["el"].values() + ev["pt"].values():
		if v > 1.0:
			p = roundi((v - 1.0) * 100)
		else:
			m = roundi((1.0 - v) * 100)
	return EVENTS[ev["id"]]["desc"].format({"up": "·".join(up), "down": "·".join(down), "p": p, "m": m})


# ---------- 효과 ----------

static func ev_id() -> String:
	return event.get("id", "") if on else ""


static func hp_k() -> float:
	match ev_id():
		"shell": return 0.85
		"swarm": return 0.75
	return 1.0


static func spd_k() -> float:
	return 1.15 if ev_id() == "gold" else 1.0


static func score_k() -> float:
	return 2.0 if ev_id() == "gold" else 1.0


static func all_sturdy() -> bool:
	return ev_id() == "shell"


static func all_split() -> bool:
	return ev_id() == "swarm"


## 오브젝트 피해 배율: 이벤트(속성은 레벨 몫만큼) x 적응 저항(최대 vary_adapt_max).
static func tower_mul(els: Dictionary, pattern: String) -> float:
	if not on:
		return 1.0
	var L := 0
	for e in els:
		L += els[e]
	if L <= 0:
		return 1.0
	var f := 1.0
	if not event.is_empty():
		if not event["el"].is_empty():
			var s := 0.0
			for e in els:
				s += els[e] * event["el"].get(e, 1.0)
			f *= s / L
		f *= event["pt"].get(pattern, 1.0)
	if not adapt_el.is_empty() or not adapt_pt.is_empty():
		var ra := 0.0
		for e in els:
			ra += els[e] * adapt_el.get(e, 0.0)
		ra /= L
		var rp: float = adapt_pt.get(pattern, 0.0)
		f *= 1.0 - minf(1.0 - (1.0 - ra) * (1.0 - rp), Rules.t("vary_adapt_max"))
	return f


# ---------- 적응 ----------

## 웨이브를 마칠 때: 오브젝트마다 이번 웨이브 피해를 속성(레벨 몫)·공격방식으로 모아 두고, 30웨이브부터 1위에 저항을 쌓는다.
static func wave_done(w: int, towers: Array) -> void:
	if not on:
		return
	var de := {}
	var dp := {}
	for t in towers:
		var d: float = t.dealt
		if d <= 0.0:
			continue
		dp[t.pattern] = dp.get(t.pattern, 0.0) + d
		var L := 0
		for e in t.elements:
			L += t.elements[e]
		for e in t.elements:
			de[e] = de.get(e, 0.0) + d * t.elements[e] / maxf(L, 1.0)
	hist.append({"e": de, "p": dp})
	while hist.size() > ADAPT_HIST:
		hist.pop_front()
	if w < int(Rules.t("vary_adapt_from")):
		return
	_step(adapt_el, _top("e"))
	_step(adapt_pt, _top("p"))


static func _top(k: String) -> Variant:
	var sum := {}
	for h in hist:
		for id in h[k]:
			sum[id] = sum.get(id, 0.0) + h[k][id]
	var best: Variant = null
	var bd := 0.0
	for id in sum:
		if sum[id] > bd:
			bd = sum[id]
			best = id
	return best


## 1위는 +vary_adapt_step (최대 vary_adapt_max), 나머지는 같은 만큼 빠진다.
static func _step(d: Dictionary, top: Variant) -> void:
	var step := Rules.t("vary_adapt_step")
	for id in d.keys():
		if id != top:
			d[id] = maxf(0.0, d[id] - step)
			if d[id] <= 0.0:
				d.erase(id)
	if top != null:
		d[top] = minf(d.get(top, 0.0) + step, Rules.t("vary_adapt_max"))


## "영혼 -12% · 혼불 -8%"
static func adapt_text() -> String:
	var parts := PackedStringArray()
	for e in adapt_el:
		parts.append("%s -%d%%" % [Elem.NAMES[e], roundi(adapt_el[e] * 100)])
	for p in adapt_pt:
		parts.append("%s -%d%%" % [Pat.pname(p), roundi(adapt_pt[p] * 100)])
	return " · ".join(parts)


# ---------- 저장 ----------

static func save() -> Dictionary:
	return {"on": on, "sealed": sealed, "event": _ev_out(event), "next": _ev_out(next_event),
		"ae": adapt_el.keys().map(func(k): return [k, adapt_el[k]]), "ap": adapt_pt.keys().map(func(k): return [k, adapt_pt[k]]),
		"hist": hist.map(func(h): return {"e": h["e"].keys().map(func(k): return [k, h["e"][k]]), "p": h["p"]})}


## 이어하기 저장·서버 기록용: 사전 키가 숫자(속성)면 JSON에서 글자가 되므로 [키, 값] 목록으로
static func _ev_out(ev: Dictionary) -> Dictionary:
	if ev.is_empty():
		return {}
	return {"id": ev["id"], "el": ev["el"].keys().map(func(k): return [k, ev["el"][k]]), "pt": ev["pt"]}


static func _ev_in(v: Variant) -> Dictionary:
	if not v is Dictionary or not EVENTS.has(v.get("id", "")):
		return {}
	var ev := {"id": v["id"], "el": {}, "pt": {}}
	for p in v.get("el", []):
		if p is Array and p.size() == 2 and int(p[0]) in Elem.ALL:
			ev["el"][int(p[0])] = float(p[1])
	var pt: Variant = v.get("pt", {})
	if pt is Dictionary:
		for id in pt:
			if id in Pat.PATTERN_IDS:
				ev["pt"][id] = float(pt[id])
	return ev


static func load_from(g: Variant) -> void:
	new_run(false)
	if not g is Dictionary or not g.get("on", false):
		return
	on = true
	var s: Variant = g.get("sealed", {})
	if s is Dictionary:
		sealed["elem"] = Array(s.get("elem", [])).map(func(x): return int(x)).filter(func(x): return x in Elem.ALL)
		sealed["pat"] = Array(s.get("pat", [])).filter(func(x): return x in Pat.PATTERN_IDS)
		sealed["link"] = Array(s.get("link", [])).filter(func(x): return x in Pat.LINK_IDS)
	event = _ev_in(g.get("event"))
	next_event = _ev_in(g.get("next"))
	for p in g.get("ae", []):
		if p is Array and p.size() == 2 and int(p[0]) in Elem.ALL:
			adapt_el[int(p[0])] = float(p[1])
	for p in g.get("ap", []):
		if p is Array and p.size() == 2 and str(p[0]) in Pat.ALL_IDS:
			adapt_pt[str(p[0])] = float(p[1])
	for h in g.get("hist", []):
		if h is Dictionary:
			var de := {}
			for p in h.get("e", []):
				if p is Array and p.size() == 2:
					de[int(p[0])] = float(p[1])
			hist.append({"e": de, "p": h.get("p", {}) if h.get("p") is Dictionary else {}})


## 서버 판 기록용 (detail.vary)
static func record() -> Dictionary:
	if not on:
		return {}
	return {"seal_e": sealed["elem"].map(func(e): return Patch.ELEM_KEYS[Elem.ALL.find(e)]), "seal_p": sealed["pat"], "seal_l": sealed["link"],
		"event": ev_id(), "adapt": adapt_text()}
