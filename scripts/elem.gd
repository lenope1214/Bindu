class_name Elem
## 속성 정의. 한 오브젝트에 넣는 속성 종류 수는 규칙 버전 상한(rules.gd), 레벨은 제한 없음.
## - 겹친 속성마다 고유 공격(FORM)이 모두 발사된다.
## - 모든 공격에 겹친 속성 전부의 부가효과(RIDER)가 붙는다.
## - 특정 두 속성이 함께 있으면 특수 반응(REACTIONS) 공격이 추가된다.
##   반응 모양은 한쪽 속성이 정한다: 물은 공격 방향으로 흐르는 물길, 땅은 가로로 서는 벽.
##   소리는 부채꼴 파동, 시간은 잠시 뒤 같은 공격이 한 번 더(잔상), 영혼은 쫓아가는 혼불.
##   바람·소리·시간·영혼은 반응 3개, 나머지 속성은 4개씩.

enum { FIRE, WOOD, WATER, ELECTRIC, WIND, ICE, EARTH, DARK, LIGHT, POISON, METAL, SOUND, TIME, SOUL }

const ALL := [FIRE, WOOD, WATER, ELECTRIC, WIND, ICE, EARTH, DARK, LIGHT, POISON, METAL, SOUND, TIME, SOUL]

const NAMES := {
	FIRE: "불", WOOD: "나무", WATER: "물", ELECTRIC: "전기", WIND: "바람", ICE: "얼음",
	EARTH: "땅", DARK: "어둠", LIGHT: "빛", POISON: "독", METAL: "금속",
	SOUND: "소리", TIME: "시간", SOUL: "영혼",
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
	SOUND: Color(1.0, 0.5, 0.7),
	TIME: Color(0.95, 0.8, 0.4),
	SOUL: Color(0.82, 0.62, 1.0),
}

## 속성 기호: 이름 첫 글자를 검은 테두리로 (색이 밝아도 어두워도 읽히게). c는 글자 가운데.
static func draw_symbol(ci: CanvasItem, font: Font, c: Vector2, e: int, fs: int) -> void:
	var ch: String = NAMES[e].left(1)
	var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := c + Vector2(-w / 2.0, fs * 0.38)
	ci.draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
	ci.draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## 속성과 같은 색의 공격방식 (도감 설명용. 규칙 1·3에서 속성은 공격 모양을 바꾸지 않고, 공격방식은 따로 카드로 얻는다)
const FORM := {
	FIRE: "화염 방사 (부채꼴 지속 피해)",
	WOOD: "관통 가시 연사",
	WATER: "물줄기 (경직)",
	ELECTRIC: "연쇄 번개",
	WIND: "돌풍 (옆으로 밀기)",
	ICE: "얼음 탄 (맞으면 파편 3개)",
	EARTH: "바위 벽 세우기",
	DARK: "블랙홀 (빨아들이기)",
	LIGHT: "충전 레이저 (화면 끝까지 관통)",
	POISON: "독 덩어리",
	METAL: "철구 (느리고 강함, 관통)",
	SOUND: "음파 (부채꼴 파동, 관통)",
	TIME: "시계침 (앞쪽을 왕복하며 훑음)",
	SOUL: "혼불 (구체를 쫓아감)",
}

## 형태 성질(시험): 속성이 공격방식 공격의 모양에 더하는 성질. 공격방식이 무엇이든 같은 규칙.
## 세기는 그 속성 레벨에 비례하되 Lv3까지만 오른다 (Tower.tk). 특수 반응 공격에는 붙지 않는다.
## "끝"은 탄이 사라지는 곳(관통탄은 처음 맞힌 곳) · 블랙홀은 터질 때 · 벽은 무너질 때 ·
## 계속 공격하는 형태(분사·물줄기·레이저·음파·시계침·번개)는 2초에 한 번 사거리 끝(번개는 마지막 구체).
const TRAIT := {
	FIRE: "불씨: 날아가는 공격이 지나간 길과 끝 자리에 불씨 (1초, 화상)",
	WOOD: "자람: 오브젝트에서 멀리 맞힐수록 피해 증가 (100마다 +4%/Lv, 최대 +20%) · 블랙홀은 덜 줄어듦",
	WATER: "흐름: 지나간 길과 끝 자리에 물길 (감속) · 투척 장판이 공격 방향으로 흐름",
	ELECTRIC: "튐: 끝에서 가까운 구체 하나에 번개",
	WIND: "멀리: 날아가는 공격의 속도·거리 +12%/Lv · 블랙홀은 덜 줄어듦",
	ICE: "서리: 끝 자리에 서리 (1초, 냉기)",
	EARTH: "턱: 끝 자리에 1초 동안 작은 바위 턱 (막기)",
	DARK: "끌기: 끝 자리 주변 구체를 끌어모음 · 블랙홀은 끌기 범위·힘 +15%/Lv",
	LIGHT: "빛줄기: 끝에서 앞으로 빛줄기",
	POISON: "안개: 끝 자리에 독 안개 (1.5초, 중독)",
	METAL: "무게: 공격방식 공격의 경직 +0.1초/Lv · 블랙홀은 터질 때 모인 구체 경직",
	SOUND: "울림: 끝 자리에 작은 음파",
	TIME: "째깍: 끝 자리가 0.6초 뒤 한 번 더 터짐",
	SOUL: "넋불: 끝 자리에서 확률로 혼불 (10%/Lv)",
}

## 부가효과: 같은 오브젝트의 모든 공격에 붙는다
const RIDER := {
	FIRE: "화상: 한동안 계속 피해",
	WOOD: "가시 박힘: 받는 피해 +20% (레벨마다)",
	WATER: "감속 (느려짐)",
	ELECTRIC: "주변 구체로 튀는 전류 (확률 30%)",
	WIND: "둘레(240) 다른 오브젝트 공격 속도 +10%/레벨 (가장 큰 바람 하나만)",
	ICE: "냉기가 쌓이면 빙결 (잠깐 멈춤)",
	EARTH: "기절 (레벨마다 확률 +20%, 최대 70%)",
	DARK: "2초간 받는 피해 +30%",
	LIGHT: "치명타: 피해 2배 (레벨마다 확률 +12%, 최대 60%)",
	POISON: "중독 (죽으면 주변에 전염)",
	METAL: "추가 피해 + 경직 (제자리에 잠깐 멈춤)",
	SOUND: "울림: 3초간 어느 오브젝트에 맞든 3번째마다 주변에 음파",
	TIME: "메아리: 2초간 받은 피해의 일부를 한 번 더 받음",
	SOUL: "넋: 3초 안에 죽으면 확률로 혼불이 나와 다른 구체를 쫓음",
}

const REACTIONS := [
	{"id": "burning", "a": FIRE, "b": WOOD, "name": "장작 장판", "desc": "장작 투척, 불타는 장판", "color": Color(1.0, 0.62, 0.1)},
	{"id": "steam", "a": FIRE, "b": WATER, "name": "증기", "desc": "물길 위 증기가 그 줄의 구체를 느리게 하고 받는 피해 +30%", "color": Color(0.85, 0.88, 0.94)},
	{"id": "vine", "a": WATER, "b": WOOD, "name": "덩굴", "desc": "물길 따라 자란 덩굴이 지나가는 구체를 묶음", "color": Color(0.16, 0.58, 0.3)},
	{"id": "shock", "a": WATER, "b": ELECTRIC, "name": "감전 물길", "desc": "공격 방향으로 흐르는 물길에 전기가 흘러 지나가는 구체에 피해", "color": Color(0.55, 0.85, 1.0)},
	{"id": "firestorm", "a": FIRE, "b": WIND, "name": "화염 회오리", "desc": "불타는 회오리가 전진", "color": Color(1.0, 0.5, 0.15)},
	{"id": "blizzard", "a": ICE, "b": WIND, "name": "눈보라", "desc": "주변 원 안의 구체를 느리게 하고 냉기를 쌓음", "color": Color(0.85, 0.95, 1.0)},
	{"id": "eclipse", "a": DARK, "b": LIGHT, "name": "일식", "desc": "몇 초마다 화면 안 모든 구체에 피해", "color": Color(0.95, 0.75, 1.0)},
	{"id": "lava", "a": EARTH, "b": FIRE, "name": "용암 벽", "desc": "앞쪽에 가로로 서는 불타는 벽, 지나가면 크게 느려지고 탐", "color": Color(0.95, 0.3, 0.05)},
	{"id": "mushroom", "a": POISON, "b": WOOD, "name": "독버섯 지뢰", "desc": "밟으면 터지는 독버섯", "color": Color(0.8, 0.5, 0.95)},
	{"id": "railgun", "a": METAL, "b": ELECTRIC, "name": "레일건", "desc": "체력이 가장 많은 구체를 조준해 화면 끝까지 관통 일격", "color": Color(0.7, 0.95, 1.0)},
	{"id": "halo", "a": METAL, "b": LIGHT, "name": "광륜", "desc": "주위를 도는 빛 칼날, 닿으면 반드시 치명타", "color": Color(1.0, 0.95, 0.6)},
	{"id": "quake", "a": METAL, "b": EARTH, "name": "지진", "desc": "몇 초마다 주변 구체 모두에 피해를 주고 기절시킴", "color": Color(0.75, 0.6, 0.45)},
	{"id": "storm", "a": ELECTRIC, "b": WIND, "name": "뇌우", "desc": "번개 구름이 앞으로 떠가며 낙뢰", "color": Color(0.75, 0.8, 1.0)},
	{"id": "aurora", "a": ICE, "b": LIGHT, "name": "오로라", "desc": "5갈래 빛줄기, 냉기가 크게 쌓임", "color": Color(0.5, 1.0, 0.8)},
	{"id": "swamp", "a": EARTH, "b": POISON, "name": "독늪", "desc": "가로로 깔리는 독 진흙, 안에서 중독 2배·죽으면 독 폭발", "color": Color(0.5, 0.6, 0.2)},
	{"id": "curse", "a": DARK, "b": POISON, "name": "저주", "desc": "저주 걸린 구체는 계속 피해를 받고, 죽으면 주변에 큰 피해를 주며 저주가 옆 구체로 옮겨 감", "color": Color(0.6, 0.2, 0.7)},
	{"id": "prison", "a": ICE, "b": DARK, "name": "빙결 감옥", "desc": "앞쪽 원 안 구체를 멈추고 받는 피해 +50%", "color": Color(0.45, 0.5, 0.95)},
	{"id": "bell", "a": METAL, "b": SOUND, "name": "종", "desc": "주기적으로 종이 울려 앞쪽 부채꼴 구체에 울림 2번씩", "color": Color(0.95, 0.8, 0.55)},
	{"id": "shatter", "a": ICE, "b": SOUND, "name": "파쇄", "desc": "앞쪽 파동이 냉기를 쌓고, 빙결된 구체는 깨지며 큰 피해·파편", "color": Color(0.8, 0.85, 1.0)},
	{"id": "silence", "a": DARK, "b": SOUND, "name": "침묵", "desc": "앞쪽 파동에 맞은 구체는 2초간 저항·굳셈이 꺼지고 보스는 부하를 못 부름", "color": Color(0.55, 0.4, 0.65)},
	{"id": "afterimage", "a": LIGHT, "b": TIME, "name": "잔광", "desc": "화면 끝까지 관통하는 광선, 1.2초 뒤 같은 자리에 한 번 더", "color": Color(1.0, 0.9, 0.6)},
	{"id": "rewind", "a": ELECTRIC, "b": TIME, "name": "되감기 번개", "desc": "연쇄 번개가 친 구체들을 1초 뒤 한 번 더 침", "color": Color(0.95, 0.95, 0.5)},
	{"id": "hourglass", "a": EARTH, "b": TIME, "name": "모래시계 벽", "desc": "가로로 서는 모래 벽, 지나가면 느려지고 받은 피해의 절반을 다시 받음", "color": Color(0.85, 0.7, 0.4)},
	{"id": "styx", "a": WATER, "b": SOUL, "name": "망자의 강", "desc": "물길 안에서 죽은 구체는 반드시 혼불이 됨", "color": Color(0.5, 0.55, 0.95)},
	{"id": "plague", "a": POISON, "b": SOUL, "name": "역병 혼불", "desc": "쫓아가 맞힌 구체를 강하게 중독시키는 혼불 2개", "color": Color(0.65, 0.9, 0.5)},
	{"id": "spirit", "a": WOOD, "b": SOUL, "name": "고목령", "desc": "쫓아가 맞힌 구체를 묶는 혼불 2개", "color": Color(0.5, 0.8, 0.55)},
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
