class_name Progress
## 계정 진행 저장(클라우드 세이브): Meta의 진행을 서버 형식으로 꺼내고, 합친 결과를 Meta에 넣는다.
## 형식·합치기 규칙은 server/app/progress.py와 같아야 한다 (기기마다 다른 설정은 넣지 않음).
##   best 키마다 둘 다 큰 값 · ach·codex·seen 합집합 · counts 기기마다 큰 값 · lww 이름마다 늦게 고친 쪽

const FORMAT := 1
## 늦게 고친 쪽이 이기는 값 (Meta 변수는 _value·_assign)
const LWW := ["map", "rules", "modes", "tower_skin", "core_skin", "line_flip", "tutor", "notes_seen", "nick"]
const FAV := "fav:"

## 이름 -> [고친 시각(초), 그때 값]. 저장할 때 값이 바뀐 이름만 시각을 새로 찍는다 (best.cfg [sync] stamps)
static var stamps := {}
## 기기 id -> [처치, 판 수]. 이 기기 칸은 Meta 합계에서 다른 기기 칸을 뺀 값
static var counts := {}


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func _norm(name: String, v: Variant) -> Variant:
	if name == "rules":
		return int(v)
	if name == "modes":
		return Array(v).map(func(x): return str(x))
	return v


static func _value(name: String) -> Variant:
	match name:
		"map": return Meta.map_id
		"rules": return Meta.rules
		"modes": return _norm("modes", Meta.modes)
		"tower_skin": return Meta.tower_skin
		"core_skin": return Meta.core_skin
		"line_flip": return Meta.line_flip
		"tutor": return Meta.tutor_next
		"notes_seen": return Meta.notes_seen
		"nick": return Meta.nickname
	return null


static func _assign(name: String, v: Variant) -> void:
	match name:
		"map": Meta.map_id = v
		"rules": Meta.rules = v
		"modes": Meta.modes = v
		"tower_skin": Meta.tower_skin = v
		"core_skin": Meta.core_skin = v
		"line_flip": Meta.line_flip = v
		"tutor": Meta.tutor_next = v
		"notes_seen": Meta.notes_seen = v
		"nick": Meta.nickname = v


static func _current() -> Dictionary:
	var cur := {}
	for name in LWW:
		cur[name] = _value(name)
	for k in Meta.favs:
		cur[FAV + str(k)] = true
	for name in stamps:
		if str(name).begins_with(FAV) and not cur.has(name):
			cur[name] = false  # 선호 표시를 끈 것도 다른 기기에 넘어가게
	return cur


## 지금 값과 마지막으로 찍은 값이 다르면 지금 시각으로 찍는다. 처음 찍을 때는 0초(어느 기기 값이든 먼저 있던 쪽을 이기지 않게).
static func stamp() -> void:
	var t := _now()
	var cur := _current()
	for name in cur:
		var s: Variant = stamps.get(name)
		if s == null:
			stamps[name] = [0, cur[name]]
		elif not _same(s[1], cur[name]):
			stamps[name] = [t, cur[name]]


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	return typeof(a) == typeof(b) and a == b


static func _own() -> Array:
	var k := 0
	var g := 0
	for dev in counts:
		if dev != Meta.device_id:
			k += int(counts[dev][0])
			g += int(counts[dev][1])
	return [maxi(0, Meta.total_kills - k), maxi(0, Meta.games - g)]


## 서버에 올릴 진행.
static func build() -> Dictionary:
	stamp()
	var c := counts.duplicate(true)
	if Meta.device_id != "":
		c[Meta.device_id] = _own()
	var best := {}
	for k in Meta.map_best:
		best[k] = Meta.best_of(k)
	return {"format": FORMAT, "best": best, "ach": Meta.achieved.keys(), "codex": Meta.codex.keys(), "seen": Meta.guide_seen.keys(),
		"counts": c, "lww": stamps.duplicate(true)}


## 두 진행을 합친다 (서버 progress.merge와 같은 규칙). 게임은 서버가 돌려준 합친 결과를 지금 것과 다시 합쳐 넣는다
## (올린 뒤 그 사이에 바뀐 것을 잃지 않게).
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {"format": FORMAT, "best": {}, "ach": [], "codex": [], "seen": [], "counts": {}, "lww": {}}
	for part in ["best", "counts"]:
		var x: Dictionary = a.get(part, {})
		var y: Dictionary = b.get(part, {})
		for k in _keys(x, y):
			var p: Array = x.get(k, [0, 0])
			var q: Array = y.get(k, [0, 0])
			out[part][k] = [maxi(int(p[0]), int(q[0])), maxi(int(p[1]), int(q[1]))]
	for part in ["ach", "codex", "seen"]:
		var s := {}
		for k in a.get(part, []) + b.get(part, []):
			s[str(k)] = true
		var ks := s.keys()
		ks.sort()
		out[part] = ks
	var la: Dictionary = a.get("lww", {})
	var lb: Dictionary = b.get("lww", {})
	for k in _keys(la, lb):
		if not la.has(k):
			out["lww"][k] = lb[k]
		elif not lb.has(k):
			out["lww"][k] = la[k]
		else:
			out["lww"][k] = _later(la[k], lb[k])
	return out


static func _keys(x: Dictionary, y: Dictionary) -> Array:
	var s := {}
	for k in x:
		s[k] = true
	for k in y:
		s[k] = true
	return s.keys()


static func _later(a: Array, b: Array) -> Array:
	if int(a[0]) != int(b[0]):
		return a if int(a[0]) > int(b[0]) else b
	# 같은 시각이면 값 글자로 (서버는 json.dumps 비교: 어느 쪽이 이겨도 양쪽이 같은 값으로 모이면 됨)
	return a if JSON.stringify(a[1]) >= JSON.stringify(b[1]) else b


## 합친 진행을 Meta에 넣는다. 이 기기 칸은 합계로 다시 계산한다.
static func apply(d: Dictionary) -> void:
	if int(d.get("format", 0)) != FORMAT:
		return
	var m := merge(build(), d)
	# 시각이 같으면 서버 값 (서버가 고른 값이 이미 이 기기 값과 합친 결과라서, 기기마다 다르게 고르지 않게)
	var dl: Dictionary = d.get("lww", {})
	for name in dl:
		if int(m["lww"][name][0]) == int(dl[name][0]):
			m["lww"][name] = dl[name]
	for k in m["best"]:
		Meta.map_best[k] = m["best"][k]
	# 이 버전이 모르는 업적·반응(새 버전에서 생긴 것)은 서버에만 남겨 둔다
	for k in m["ach"]:
		if Meta.ACHIEVEMENTS.has(k):
			Meta.achieved[k] = true
	var rx := Elem.REACTIONS.map(func(r): return r["id"])
	for k in m["codex"]:
		if k in rx:
			Meta.codex[k] = true
	for k in m["seen"]:
		Meta.guide_seen[k] = true
	counts = m["counts"]
	var k_sum := 0
	var g_sum := 0
	for dev in counts:
		k_sum += int(counts[dev][0])
		g_sum += int(counts[dev][1])
	Meta.total_kills = maxi(Meta.total_kills, k_sum)
	Meta.games = maxi(Meta.games, g_sum)
	for name in m["lww"]:
		var e: Array = m["lww"][name]
		var v: Variant = e[1]
		if str(name).begins_with(FAV):
			var key := str(name).substr(FAV.length())
			if v == true:
				Meta.favs[key] = true
			else:
				Meta.favs.erase(key)
		elif name in LWW:
			if typeof(v) == TYPE_FLOAT and typeof(_value(name)) == TYPE_INT:
				v = int(v)
			if typeof(v) != typeof(_value(name)):
				continue  # 형식이 다르면 (예전·깨진 값) 이 기기 값 그대로
			_assign(name, _norm(name, v))
		stamps[name] = [int(e[0]), v]
	Meta.fix()


static func load_into(cfg: ConfigFile) -> void:
	stamps = Meta.val(cfg, "sync", "stamps", {})
	counts = Meta.val(cfg, "sync", "counts", {})


static func save_into(cfg: ConfigFile) -> void:
	stamp()
	cfg.set_value("sync", "stamps", stamps)
	cfg.set_value("sync", "counts", counts)
