extends SceneTree
# 관리자 페이지 "수치" 표가 읽는 온라인 패치 rules 키 목록(server/app/rule_keys.json)을 만든다.
# 키·기본값은 Rules.DEFAULTS와 Rules.apply의 기본 변수, 설명·묶음은 scripts/rules.gd 주석에서 읽는다.
# 사용: tools/run.sh rulekeys   (만들어 server/app/rule_keys.json에 씀, run.sh check는 같은지 비교)
# 직접: godot --headless --path . -s tools/rule_keys.gd  → 프로젝트 폴더에 rule_keys.json

## Rules.apply가 직접 바꾸는 기본 변수 (TUNE·STAT 밖). [키, 묶음, 설명, Rules 변수 이름]
## 묶음은 관리자 페이지 탭을 정한다 (tools/patch_keys.py의 TABS).
const BASE := [
	["max_elems", "오브젝트 상한", "한 오브젝트에 넣을 수 있는 속성 종류 (도파민 모드 99)", "max_elems"],
	["max_mod", "오브젝트 상한", "강화 종류마다 한 오브젝트에 쌓을 수 있는 수 (도파민 모드 99)", "max_mod"],
	["mod_total", "오브젝트 상한", "한 오브젝트에 넣을 수 있는 강화 합계 (도파민 모드 99)", "mod_total"],
	["picks", "카드 수", "쉬는 시간마다 고르는 카드 수 (모드 '두 장'이면 +1)", "picks"],
	["open_picks", "카드 수", "처음 두 쉬는 시간(웨이브 0·1 뒤)에 고르는 카드 수", "open_picks"],
	["resist_from", "구체 기본", "저항 구체가 나오는 웨이브 (모드 '이른 위협'이면 3 일찍)", "resist_from"],
	["sturdy_from", "구체 기본", "굳센 구체가 나오는 웨이브 (모드 '이른 위협'이면 3 일찍)", "sturdy_from"],
	["crowd_log", "오브젝트 피해·성장", "오브젝트 수 보너스 계수: 모든 피해 x(1 + 값 x ln(오브젝트 수))", "crowd"],
	["pincer_frac", "연계", "협공 폭발 피해: 구체 최대 체력 대비", "pincer_frac"],
	["orb_mul", "구체 기본", "웨이브 구체 수 배율", "orb_mul"],
	["tax_step", "오브젝트 피해·성장", "속성 종류가 하나 늘 때마다 공격 속도 감소 (도파민 모드 0.25)", "tax_step"],
	["hp_growth", "구체 기본", "11웨이브부터 웨이브마다 구체 체력 배율 (hp_late_from 웨이브까지)", "hp_growth"],
	["orb_hp", "구체 기본", "구체 체력 배율 (보호막·별빛 필요량에도 곱함)", "orb_hp"],
]


static func _base(n: String) -> Variant:
	match n:
		"max_elems": return Rules.max_elems
		"max_mod": return Rules.max_mod
		"mod_total": return Rules.mod_total
		"picks": return Rules.picks
		"open_picks": return Rules.open_picks
		"resist_from": return Rules.resist_from
		"sturdy_from": return Rules.sturdy_from
		"crowd": return Rules.crowd
		"pincer_frac": return Rules.pincer_frac
		"orb_mul": return Rules.orb_mul
		"tax_step": return Rules.tax_step
		"hp_growth": return Rules.hp_growth
		"orb_hp": return Rules.orb_hp
	return null


static func _num(v: Variant) -> Variant:
	var f := float(v)
	return int(f) if is_equal_approx(f, roundf(f)) and absf(f) < 1e9 else snappedf(f, 0.0001)


## scripts/rules.gd의 TUNE·STAT 줄 주석 → {키: [묶음, 설명]}
static func _comments() -> Dictionary:
	var out := {}
	var src := FileAccess.get_file_as_string("res://scripts/rules.gd").split("\n")
	var block := ""
	var group := ""
	var last := ""
	var prev_c := false
	var re := RegEx.create_from_string("\"([a-z0-9_]+)\"\\s*:")
	for line in src:
		var s := line.strip_edges()
		if s.begins_with("const TUNE"):
			block = "TUNE"
			group = "조합 효율 조정"
			last = ""
			continue
		if s.begins_with("const STAT"):
			block = "STAT"
			group = "오브젝트 수치"
			last = ""
			continue
		if block == "":
			continue
		if s == "}":
			block = ""
			continue
		if s.begins_with("#"):
			if prev_c:  # 여러 줄 주석: 첫 줄이 묶음, 나머지는 설명에 이어 붙임
				last += " " + s.trim_prefix("#").strip_edges()
				continue
			prev_c = true
			last = s.trim_prefix("#").strip_edges()
			var h := last
			for cut in [" (", ":", "("]:
				var i := h.find(cut)
				if i > 0:
					h = h.substr(0, i)
			group = h.strip_edges().left(24)
			continue
		prev_c = false
		var ci := s.find("  # ")
		var desc := s.substr(ci + 4).strip_edges() if ci >= 0 else last
		for m in re.search_all(s.substr(0, ci) if ci >= 0 else s):
			out[m.get_string(1)] = [group, desc]
	return out


static func build() -> Array:
	var cm := _comments()
	var out := []
	Patch.data = {}
	Rules.apply(3)
	var r3 := {}
	for b in BASE:
		r3[b[0]] = _base(b[3])
	Rules.apply(1)
	for b in BASE:
		var e := {"k": b[0], "g": b[1], "d": b[2], "v": _num(_base(b[3]))}
		if r3[b[0]] != _base(b[3]):
			e["v3"] = _num(r3[b[0]])
		out.append(e)
	var names := {}
	for id in Pat.ALL_IDS:
		names[id] = Pat.PATTERNS[id]["name"]
	var rx := {}
	for r in Elem.REACTIONS:
		rx[r["id"]] = r["name"]
	for k in Rules.DEFAULTS:
		var e := {"k": k, "v": _num(Rules.DEFAULTS[k])}
		if cm.has(k):
			e["g"] = cm[k][0]
			e["d"] = cm[k][1]
		else:
			var p: String = k.substr(0, k.find("_") + 1)
			var id: String = k.substr(p.length())
			if p in ["dmg_", "spd_", "range_"] and names.has(id):
				e["g"] = {"dmg_": "공격방식 피해 배율", "spd_": "공격방식 공격 속도 배율", "range_": "공격방식 사거리 배율"}[p]
				e["d"] = "%s %s (1 = 그대로)" % [names[id], {"dmg_": "피해 배율, 반응 제외", "spd_": "공격 속도 배율", "range_": "사거리 배율"}[p]]
			elif k == "share_mul":
				e["g"] = "특징 공유"
				e["d"] = "모든 특징 세기 배율 (1 = 그대로, 0 = 특징 끔)"
			elif p == "share_" and Patch.ELEM_KEYS.has(id):
				var el: int = Elem.ALL[Patch.ELEM_KEYS.find(id)]
				e["g"] = "특징 공유"
				e["d"] = "%s 특징 '%s' 세기 배율" % [Elem.NAMES[el], Elem.TRAIT[el].get_slice(":", 0)]
			else:
				e["g"] = "기타"
				e["d"] = ""
		out.append(e)
	var nm := names.duplicate()
	nm.merge(rx)
	out.append_array(_code(nm))
	return out


## 게임 코드 수치 묶음 이름 (관리 화면 하위 탭은 tools/patch_keys.py TABS가 이 이름으로 나눈다). 변수별이 먼저, 없으면 스크립트별
const CODE_GROUP := {
	"Tower.HIT": "공격방식 기본 피해", "Tower.BASE_IV": "공격방식 기본 간격", "Tower.SHAPE": "공격방식 모양", "Orb.KIND": "구체 종류",
	"Main.SPECIAL": "저항·굳센 구체",
	"Tower": "오브젝트 코드 수치", "Projectile": "탄", "Orb": "구체 상태 수치", "Main": "맵·중앙 코드 수치", "Modes": "모드 코드 수치",
	"Share": "특징 코드 수치", "Pat": "그린 궤적 코드 수치", "MapRule": "맵 규칙 코드 수치", "Skill": "중앙 기술 코드 수치",
}


## 사전 묶음 이름: 설명 첫 마디 (없으면 변수 이름)
static func _short(doc: String, name: String) -> String:
	var h := doc
	for cut in [" (", ".", ":", "("]:
		var i := h.find(cut)
		if i > 0:
			h = h.substr(0, i)
	h = h.strip_edges()
	return h.left(30) if h != "" else name


## Rules.CODE 스크립트의 대문자 static var (숫자·숫자 배열·숫자 사전). 설명은 줄 끝 주석, 없으면 바로 위 ## 주석.
static func _code(names: Dictionary) -> Array:
	var out := []
	var re_var := RegEx.create_from_string("^static var ([A-Z][A-Z0-9_]*)")
	var re_key := RegEx.create_from_string("\"([a-z0-9_]+)\"\\s*:")
	for cls in Rules.CODE:
		var sc := load(Rules.CODE[cls]) as GDScript
		var src := FileAccess.get_file_as_string(Rules.CODE[cls]).split("\n")
		var doc := ""
		var i := 0
		while i < src.size():
			var line: String = src[i]
			if line.begins_with("##"):
				var start := i == 0 or not src[i - 1].begins_with("##")
				doc = (doc + " " if doc != "" and not start else "") + line.trim_prefix("##").strip_edges()
				i += 1
				continue
			var m := re_var.search(line)
			if m == null:
				if line.strip_edges() == "" or not line.begins_with("static var"):
					doc = ""  # 빈 줄·다른 코드까지: 바로 위 ## 설명은 이어진 static var 묶음에만
				i += 1
				continue
			var name := m.get_string(1)
			var val: Variant = sc.get(name)
			var ci := line.find("  # ")
			var desc := line.substr(ci + 4).strip_edges() if ci >= 0 else doc
			var g: String = CODE_GROUP.get(cls + "." + name, CODE_GROUP[cls])
			var key0: String = cls + "." + name
			if val is float or val is int:
				out.append({"k": key0, "g": g, "d": desc, "v": _num(val)})
			elif val is Array:
				for j in val.size():
					if val[j] is float or val[j] is int:
						out.append({"k": "%s.%d" % [key0, j], "g": g, "d": "%s (%d번째)" % [desc, j + 1], "v": _num(val[j])})
			elif val is Dictionary:
				# 사전: 여러 줄이면 칸마다 줄 끝 주석, 한 줄이면 사전 설명
				var dc := {}
				var j := i
				while j < src.size():
					var ln: String = src[j]
					var c2 := ln.find("  # ")
					var body := ln.substr(0, c2) if c2 >= 0 else ln
					for km in re_key.search_all(body):
						dc[km.get_string(1)] = ln.substr(c2 + 4).strip_edges() if c2 >= 0 else ""
					if ln.strip_edges().ends_with("}") or (j == i and "}" in body):
						break
					j += 1
				for sub in val:
					if not (val[sub] is float or val[sub] is int):
						continue
					var sd: String = dc.get(sub, "")
					if sd == "" and names.has(sub):
						sd = names[sub]
					out.append({"k": "%s.%s" % [key0, sub], "g": g, "d": sd if sd != "" else sub, "v": _num(val[sub])})
				i = j
			i += 1
	return out


func _initialize():
	var f := FileAccess.open("res://rule_keys.json", FileAccess.WRITE)
	var arr := build()
	var lines := PackedStringArray()
	for e in arr:
		lines.append("  " + JSON.stringify(e, "", false))
	f.store_string("[\n" + ",\n".join(lines) + "\n]\n")
	f.close()
	print("RULEKEYS ok keys=%d" % arr.size())
	quit()
