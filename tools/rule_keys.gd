extends SceneTree
# 관리자 페이지 "수치" 표가 읽는 온라인 패치 rules 키 목록(server/app/rule_keys.json)을 만든다.
# 키·기본값은 Rules.DEFAULTS와 Rules.apply의 기본 변수, 설명·묶음은 scripts/rules.gd 주석에서 읽는다.
# 사용: tools/run.sh rulekeys   (만들어 server/app/rule_keys.json에 씀, run.sh check는 같은지 비교)
# 직접: godot --headless --path . -s tools/rule_keys.gd  → 프로젝트 폴더에 rule_keys.json

## Rules.apply가 직접 바꾸는 기본 변수 (TUNE·STAT 밖). [키, 설명, Rules 변수 이름]
const BASE := [
	["max_elems", "한 오브젝트에 넣을 수 있는 속성 종류 (도파민 모드 99)", "max_elems"],
	["max_mod", "강화 종류마다 쌓을 수 있는 수 (도파민 모드 99)", "max_mod"],
	["mod_total", "한 오브젝트에 넣을 수 있는 강화 합계 (도파민 모드 99)", "mod_total"],
	["picks", "쉬는 시간마다 고르는 카드 수", "picks"],
	["open_picks", "처음 두 쉬는 시간에 고르는 카드 수", "open_picks"],
	["resist_from", "저항 구체가 나오는 웨이브", "resist_from"],
	["sturdy_from", "굳센 구체가 나오는 웨이브", "sturdy_from"],
	["crowd_log", "오브젝트 수 보너스 계수: 모든 피해 x(1 + 값 x ln(오브젝트 수))", "crowd"],
	["pincer_frac", "협공 표식 폭발: 구체 최대 체력 대비", "pincer_frac"],
	["orb_mul", "웨이브 구체 수 배율", "orb_mul"],
	["tax_step", "속성 종류 하나당 공격 속도 감소 (도파민 모드 0.25)", "tax_step"],
	["hp_growth", "11웨이브부터 웨이브마다 구체 체력 배율", "hp_growth"],
	["orb_hp", "구체 체력 배율", "orb_hp"],
	["trait_mul", "속성 형태 성질 세기", "trait_mul"],
	["rx_mul", "새 반응 65개의 피해·지속 피해 배율", "rx_mul"],
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
		"trait_mul": return Rules.trait_mul
		"rx_mul": return Rules.rx_mul
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
		r3[b[0]] = _base(b[2])
	Rules.apply(1)
	for b in BASE:
		var e := {"k": b[0], "g": "규칙 기본", "d": b[1], "v": _num(_base(b[2]))}
		if r3[b[0]] != _base(b[2]):
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
			elif p == "rxd_" and rx.has(id):
				e["g"] = "반응 피해 배율"
				e["d"] = "%s 반응이 맞혀 주는 피해 배율 (1 = 그대로)" % rx[id]
			else:
				e["g"] = "기타"
				e["d"] = ""
		out.append(e)
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
