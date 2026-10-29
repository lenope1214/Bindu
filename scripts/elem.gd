class_name Elem
## 속성 정의. 속성은 제한 없이 겹칠 수 있다.
## - 겹친 속성마다 고유 공격(FORM)이 모두 발사된다.
## - 모든 공격에 겹친 속성 전부의 부가효과(RIDER)가 붙는다.
## - 특정 두 속성이 함께 있으면 특수 반응(REACTIONS) 공격이 추가된다.

enum { FIRE, WOOD, WATER, ELECTRIC, WIND, ICE, EARTH, DARK, LIGHT, POISON, METAL }

const ALL := [FIRE, WOOD, WATER, ELECTRIC, WIND, ICE, EARTH, DARK, LIGHT, POISON, METAL]

const NAMES := {
	FIRE: "불", WOOD: "나무", WATER: "물", ELECTRIC: "전기", WIND: "바람", ICE: "얼음",
	EARTH: "땅", DARK: "어둠", LIGHT: "빛", POISON: "독", METAL: "금속",
}

const COLORS := {
	FIRE: Color(1.0, 0.36, 0.22),
	WOOD: Color(0.3, 0.66, 0.3),
	WATER: Color(0.3, 0.6, 1.0),
	ELECTRIC: Color(1.0, 0.9, 0.25),
	WIND: Color(0.6, 0.95, 0.85),
	ICE: Color(0.7, 0.92, 1.0),
	EARTH: Color(0.62, 0.45, 0.28),
	DARK: Color(0.58, 0.32, 0.85),
	LIGHT: Color(1.0, 1.0, 0.82),
	POISON: Color(0.72, 0.96, 0.2),
	METAL: Color(0.66, 0.68, 0.75),
}

## 고유 공격
const FORM := {
	FIRE: "화염 방사 (부채꼴 지속 피해)",
	WOOD: "관통 가시 연사",
	WATER: "물줄기 (밀어내기)",
	ELECTRIC: "연쇄 번개",
	WIND: "돌풍 (옆으로 밀기)",
	ICE: "얼음 탄 (맞으면 파편 3개)",
	EARTH: "바위 벽 세우기",
	DARK: "블랙홀 (빨아들이기)",
	LIGHT: "충전 레이저 (화면 끝까지 관통)",
	POISON: "독 덩어리",
	METAL: "철구 (느리고 강함, 관통)",
}

## 부가효과: 같은 오브젝트의 모든 공격에 붙는다
const RIDER := {
	FIRE: "화상 지속 피해",
	WOOD: "가시 박힘: 피해 20% 증가",
	WATER: "감속",
	ELECTRIC: "주변 구체로 튀는 전류",
	WIND: "중앙 반대쪽으로 밀어내기",
	ICE: "냉기 누적 시 빙결",
	EARTH: "기절 (확률 20%씩)",
	DARK: "받는 피해 증가",
	LIGHT: "치명타(2배)",
	POISON: "중독 (죽으면 주변에 전염)",
	METAL: "추가 피해 + 넉백",
}

const REACTIONS := [
	{"id": "burning", "a": FIRE, "b": WOOD, "name": "장작 장판", "desc": "장작 투척, 불타는 장판", "color": Color(1.0, 0.62, 0.1)},
	{"id": "steam", "a": FIRE, "b": WATER, "name": "증기", "desc": "넓은 부채꼴 강한 감속", "color": Color(0.85, 0.88, 0.94)},
	{"id": "vine", "a": WATER, "b": WOOD, "name": "덩굴", "desc": "채찍으로 속박", "color": Color(0.16, 0.58, 0.3)},
	{"id": "shock", "a": WATER, "b": ELECTRIC, "name": "감전 장판", "desc": "전기 흐르는 물웅덩이", "color": Color(0.55, 0.85, 1.0)},
	{"id": "firestorm", "a": FIRE, "b": WIND, "name": "화염 회오리", "desc": "불타는 회오리가 전진", "color": Color(1.0, 0.5, 0.15)},
	{"id": "blizzard", "a": ICE, "b": WIND, "name": "눈보라", "desc": "주변 원형 감속·냉기", "color": Color(0.85, 0.95, 1.0)},
	{"id": "eclipse", "a": DARK, "b": LIGHT, "name": "일식", "desc": "주기적으로 화면 전체 피해", "color": Color(0.95, 0.75, 1.0)},
	{"id": "lava", "a": EARTH, "b": FIRE, "name": "용암", "desc": "느려지고 타는 용암 지대", "color": Color(0.95, 0.3, 0.05)},
	{"id": "mushroom", "a": POISON, "b": WOOD, "name": "독버섯 지뢰", "desc": "밟으면 터지는 독버섯", "color": Color(0.8, 0.5, 0.95)},
]


## 속성 묶음에서 성립하는 특수 반응들.
static func reactions_with(elements: Dictionary) -> Array:
	var out := []
	for r in REACTIONS:
		if elements.has(r["a"]) and elements.has(r["b"]):
			out.append(r)
	return out


## 속성 e를 더하면 새로 생기는 특수 반응들.
static func new_reactions(elements: Dictionary, e: int) -> Array:
	var out := []
	if elements.has(e):
		return out
	for r in REACTIONS:
		if (r["a"] == e and elements.has(r["b"])) or (r["b"] == e and elements.has(r["a"])):
			out.append(r)
	return out


## 이 속성과 반응하는 상대 속성 이름들.
static func partners(e: int) -> PackedStringArray:
	var out := PackedStringArray()
	for r in REACTIONS:
		if r["a"] == e:
			out.append("%s(%s)" % [NAMES[r["b"]], r["name"]])
		elif r["b"] == e:
			out.append("%s(%s)" % [NAMES[r["a"]], r["name"]])
	return out
