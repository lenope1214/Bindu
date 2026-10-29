class_name Elem
## 속성 정의. 속성은 제한 없이 겹칠 수 있다.
## - 겹친 속성마다 고유 공격(FORM)이 모두 발사된다.
## - 모든 공격에 겹친 속성 전부의 부가효과(RIDER)가 붙는다.
## - 특정 두 속성이 함께 있으면 특수 반응(REACTIONS) 공격이 추가된다.
##   반응 모양은 한쪽 속성이 정한다: 물은 공격 방향으로 흐르는 물길, 땅은 가로로 서는 벽.
##   불 4개, 나머지 속성은 반응 3개씩.

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
	{"id": "steam", "a": FIRE, "b": WATER, "name": "증기", "desc": "물길 위 증기가 띠 전체를 감속·약화", "color": Color(0.85, 0.88, 0.94)},
	{"id": "vine", "a": WATER, "b": WOOD, "name": "덩굴", "desc": "물길 따라 자란 덩굴이 지나가는 구체를 묶음", "color": Color(0.16, 0.58, 0.3)},
	{"id": "shock", "a": WATER, "b": ELECTRIC, "name": "감전 물길", "desc": "공격 방향으로 흐르는 물길에 전류", "color": Color(0.55, 0.85, 1.0)},
	{"id": "firestorm", "a": FIRE, "b": WIND, "name": "화염 회오리", "desc": "불타는 회오리가 전진", "color": Color(1.0, 0.5, 0.15)},
	{"id": "blizzard", "a": ICE, "b": WIND, "name": "눈보라", "desc": "주변 원형 감속·냉기", "color": Color(0.85, 0.95, 1.0)},
	{"id": "eclipse", "a": DARK, "b": LIGHT, "name": "일식", "desc": "주기적으로 화면 전체 피해", "color": Color(0.95, 0.75, 1.0)},
	{"id": "lava", "a": EARTH, "b": FIRE, "name": "용암 벽", "desc": "앞쪽에 가로로 서는 불타는 벽, 지나가면 크게 느려지고 탐", "color": Color(0.95, 0.3, 0.05)},
	{"id": "mushroom", "a": POISON, "b": WOOD, "name": "독버섯 지뢰", "desc": "밟으면 터지는 독버섯", "color": Color(0.8, 0.5, 0.95)},
	{"id": "railgun", "a": METAL, "b": ELECTRIC, "name": "레일건", "desc": "체력이 가장 많은 구체를 조준해 화면 끝까지 관통 일격", "color": Color(0.7, 0.95, 1.0)},
	{"id": "halo", "a": METAL, "b": LIGHT, "name": "광륜", "desc": "주위를 도는 빛 칼날, 닿으면 반드시 치명타", "color": Color(1.0, 0.95, 0.6)},
	{"id": "quake", "a": METAL, "b": EARTH, "name": "지진", "desc": "주기적으로 주변 모두 피해·기절", "color": Color(0.75, 0.6, 0.45)},
	{"id": "storm", "a": ELECTRIC, "b": WIND, "name": "뇌우", "desc": "번개 구름이 앞으로 떠가며 낙뢰", "color": Color(0.75, 0.8, 1.0)},
	{"id": "aurora", "a": ICE, "b": LIGHT, "name": "오로라", "desc": "5갈래 빛줄기, 냉기가 크게 쌓임", "color": Color(0.5, 1.0, 0.8)},
	{"id": "swamp", "a": EARTH, "b": POISON, "name": "독늪", "desc": "가로로 깔리는 독 진흙, 안에서 중독 2배·죽으면 독 폭발", "color": Color(0.5, 0.6, 0.2)},
	{"id": "curse", "a": DARK, "b": POISON, "name": "저주", "desc": "표식 구체는 계속 피해, 죽으면 주변에 큰 피해·표식이 옮겨 감", "color": Color(0.6, 0.2, 0.7)},
	{"id": "prison", "a": ICE, "b": DARK, "name": "빙결 감옥", "desc": "앞쪽 원 안 구체를 멈추고 받는 피해 +50%", "color": Color(0.45, 0.5, 0.95)},
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
