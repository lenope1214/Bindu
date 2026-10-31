class_name MapRule
## 맵마다 다른 규칙과 친화 카드 (2026-10-31 사용자 "맵별 특색이 약해 한 맵만 하게 될 것", 시험).
## 기획 docs/map-rules.md. 일반 판·멀티 판에 켠다. 정원은 끔.
## - 고유 규칙 하나: 평원 무리 보너스 x2·공명 거리 / 소용돌이 중앙 가속·보스 뒤 회전 반전 / 십자로 길목 /
##   폭풍 웨이브마다 바람 / 회랑 지나간 자리 장판·감속·밀치기
## - 친화 카드: 그 맵에서 더 자주 나오고(map_aff_w배) 피해 +map_aff_dmg (속성은 레벨 몫만큼, 공격방식은 그대로).
##   판마다 다른 흐름(Vary)의 봉인에서 빠진다.
## 수치는 온라인 패치 rules의 map_* 키 (Rules.TUNE).

const AFF := {
	"plain": {"elem": [Elem.WOOD, Elem.EARTH], "pat": ["wall"], "mod": [], "link": ["pincer", "prism", "reso"]},
	"spiral": {"elem": [Elem.WIND, Elem.TIME], "pat": ["vortex", "clock"], "mod": ["bounce"], "link": []},
	"cross": {"elem": [Elem.METAL, Elem.FIRE], "pat": ["laser", "stream", "thorn", "iron"], "mod": ["pierce"], "link": []},
	"storm": {"elem": [Elem.ELECTRIC, Elem.SOUND], "pat": ["sonic", "chain", "gust"], "mod": ["multi"], "link": []},
	"line": {"elem": [Elem.ICE, Elem.WATER, Elem.POISON], "pat": ["lob", "spray", "path"], "mod": ["size"], "link": []},
}

## 시작 화면·도움말에 보이는 규칙 한 줄 (수치는 지금 값)
const RULE_TEXT := {
	"plain": "들판: 무리 보너스 x{map_crowd} · 공명 거리 +{map_reso%}%",
	"spiral": "회오리: 중앙 가까이 x{map_spiral_in} 빨라짐 · 보스 뒤 회전 반전",
	"cross": "관문: 길 위에서 길 따라 겨누면 피해 +{map_cross_dmg%}%, 관통 감쇠 없음",
	"storm": "뇌우: 웨이브마다 바람 · 순풍 탄 +{map_wind_with%}% / 역풍 -{map_wind_against%}%",
	"line": "행진: 지나간 자리 장판 x{map_line_trail} · 감속·밀치기 +{map_line_cc%}%",
}

## 지금 판에 켜졌는지: 맵은 Meta.map_id 그대로 따른다 (시작 화면·이어하기·멀티 모두). 정원은 끔.
static func on() -> bool:
	if _env < 0:
		_env = 0 if OS.get_environment("MAPRULE") == "0" else 1  # 봇 비교용: MAPRULE=0이면 끔
	return _env == 1 and Rules.t("map_on") > 0.0 and not Garden.on and AFF.has(Meta.map_id)


static var _env := -1


static func is_map(m: String) -> bool:
	return Meta.map_id == m and on()


# ---------- 친화 카드 ----------

static func aff(kind: String, map_id := "") -> Array:
	var m := map_id if map_id != "" else Meta.map_id
	return AFF.get(m, {}).get(kind, [])


static func is_aff(kind: String, v: Variant) -> bool:
	return on() and v in aff(kind)


## 카드 하나가 친화인지 (속성·공격방식·강화·연계)
static func card_aff(card: Dictionary) -> bool:
	match card.get("type", ""):
		"elem": return is_aff("elem", card["e"])
		"pat": return is_aff("pat", card["id"])
		"mod": return is_aff("mod", card["id"])
		"link": return is_aff("link", card["id"])
	return false


## 목록에서 하나: 친화는 map_aff_w배 자주
static func pick(kind: String, arr: Array) -> Variant:
	if not on() or arr.is_empty():
		return arr.pick_random()
	var w := Rules.t("map_aff_w")
	var a: Array = aff(kind)
	var total := 0.0
	for x in arr:
		total += w if x in a else 1.0
	var r := randf() * total
	for x in arr:
		r -= w if x in a else 1.0
		if r <= 0.0:
			return x
	return arr.back()


## 오브젝트 피해 배율: 친화 속성(레벨 몫) + 친화 공격방식
static func tower_mul(els: Dictionary, pattern: String) -> float:
	if not on():
		return 1.0
	var k := Rules.t("map_aff_dmg")
	var a: Array = aff("elem")
	var L := 0
	var A := 0
	for e in els:
		L += els[e]
		if e in a:
			A += els[e]
	var f := 1.0
	if L > 0:
		f *= 1.0 + k * float(A) / L
	if pattern in aff("pat"):
		f *= 1.0 + k
	return f


## "친화: 나무·땅 · 벽 · 협공·프리즘·공명"
static func aff_text(map_id := "") -> String:
	var m := map_id if map_id != "" else Meta.map_id
	var parts := PackedStringArray()
	var e: Array = aff("elem", m)
	if not e.is_empty():
		parts.append("·".join(e.map(func(x): return Elem.NAMES[x])))
	var p: Array = aff("pat", m)
	if not p.is_empty():
		parts.append("·".join(p.map(func(x): return Pat.pname(x))))
	var md: Array = aff("mod", m)
	if not md.is_empty():
		parts.append("·".join(md.map(func(x): return Pat.MODS[x]["name"])))
	var l: Array = aff("link", m)
	if not l.is_empty():
		parts.append("·".join(l.map(func(x): return Pat.LINKS[x]["name"])))
	return " · ".join(parts)


static func rule_text(map_id := "") -> String:
	var m := map_id if map_id != "" else Meta.map_id
	return Rules.fmt(RULE_TEXT.get(m, ""))


# ---------- 평원: 들판 ----------

static func crowd_k() -> float:
	return Rules.t("map_crowd") if is_map("plain") else 1.0


static func reso_k() -> float:
	return 1.0 + Rules.t("map_reso") if is_map("plain") else 1.0


# ---------- 소용돌이: 회오리 ----------

## 웨이브 w의 회전 방향: 1~5 웨이브 +, 6~10 -, ... (보스 웨이브가 끝나면 바뀜)
static func swirl_sign(w: int) -> float:
	if not is_map("spiral"):
		return 1.0
	return 1.0 if (maxi(w, 1) - 1) / 5 % 2 == 0 else -1.0


## 중앙까지 거리 d에서 구체 속도 배율 (바깥 map_spiral_out → 중앙 map_spiral_in)
static func spiral_speed(d: float) -> float:
	if not is_map("spiral"):
		return 1.0
	var t := clampf((d - 60.0) / 620.0, 0.0, 1.0)
	return lerpf(Rules.t("map_spiral_in"), Rules.t("map_spiral_out"), t)


# ---------- 십자로: 관문 ----------

const LANE_W := 60.0  # 길 가운데 선에서 이만큼 안이면 길 위
const LANE_ALIGN := 0.9  # 겨눈 방향과 길 방향 cos (약 25도 안)


## 오브젝트가 길 위에서 길을 따라 겨누는지
static func on_lane(pos: Vector2, dir: Vector2, center: Vector2, lanes: Array) -> bool:
	if not is_map("cross"):
		return false
	var rel := pos - center
	for a in lanes:
		var u := Vector2.from_angle(a)
		if rel.dot(u) > 0.0 and absf(rel.cross(u)) < LANE_W and absf(dir.dot(u)) > LANE_ALIGN:
			return true
	return false


# ---------- 폭풍: 뇌우 ----------

## 바람 방향: 진입 방향에서 정해진다 (멀티·이어하기도 같은 값, 따로 저장하지 않음)
static func wind_dir(lanes: Array) -> Vector2:
	if not is_map("storm") or lanes.is_empty():
		return Vector2.ZERO
	var s := 0.0
	for a in lanes:
		s += a
	return Vector2.from_angle(fposmod(s * 3.7 + 1.1, TAU))


## 탄 방향 d의 바람 배율 (순풍 1+with, 역풍 1-against, 옆바람은 사이)
static func wind_k(d: Vector2, wind: Vector2) -> float:
	if wind == Vector2.ZERO or d == Vector2.ZERO:
		return 1.0
	var c := d.normalized().dot(wind)
	return 1.0 + (Rules.t("map_wind_with") * c if c > 0.0 else Rules.t("map_wind_against") * c)


# ---------- 회랑: 행진 ----------

static func trail_k() -> float:
	return Rules.t("map_line_trail") if is_map("line") else 1.0


static func cc_k() -> float:
	return 1.0 + Rules.t("map_line_cc") if is_map("line") else 1.0
