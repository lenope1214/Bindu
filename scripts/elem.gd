class_name Elem
## 속성 정의. 한 오브젝트에 넣는 속성 종류 수는 규칙 버전 상한(rules.gd), 레벨은 제한 없음.
## - 겹친 속성마다 고유 공격(FORM)이 모두 발사된다.
## - 모든 공격에 겹친 속성 전부의 부가효과(RIDER)가 붙는다.
## - 특정 두 속성이 함께 있으면 특수 반응(REACTIONS) 공격이 추가된다.
##   반응 모양은 한쪽 속성이 정한다: 물은 공격 방향으로 흐르는 물길, 땅은 오브젝트 공격이 맞힌 구체에 붙는다(용암·독늪·모래시계).
##   소리는 부채꼴 파동, 시간은 잠시 뒤 같은 공격이 한 번 더(잔상), 영혼은 쫓아가는 혼불.
##   두 속성 조합 91개 모두에 반응이 있다 (속성마다 13개). 2026-10-30에 채운 65개는 RxMore.

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
	WATER: "흐름: 지나간 길과 끝 자리에 물길 (감속)",
	ELECTRIC: "튐: 끝에서 가까운 구체 하나에 번개",
	WIND: "멀리: 날아가는 공격의 속도·거리 +12%/Lv · 블랙홀은 덜 줄어듦",
	ICE: "서리: 끝 자리에 서리 (1초, 냉기)",
	EARTH: "턱: 끝 자리에 1초 동안 작은 바위 턱 (막기)",
	DARK: "그림자: 끝 자리 주변 구체에 표식 3초 (받는 피해 +30%, 죽으면 가까운 구체로 옮겨 감) · 블랙홀은 안에 든 구체 전부",
	LIGHT: "빛줄기: 끝에서 앞으로 빛줄기",
	POISON: "안개: 끝 자리에 독 안개 (1.5초, 중독)",
	METAL: "무게: 공격방식 공격의 경직 +0.1초/Lv · 블랙홀은 터질 때 모인 구체 경직",
	SOUND: "울림: 끝 자리에 작은 음파",
	TIME: "째깍: 끝 자리가 0.6초 뒤 한 번 더 터짐",
	SOUL: "넋불: 끝 자리에서 확률로 혼불 (10%/Lv)",
}

## 부가효과 설명. 나무는 규칙마다 세는 최대 레벨(Rules wood_cap)이 달라 붙여 보여 준다
static func rider(e: int) -> String:
	if e == WOOD and Rules.t("wood_cap") < 50.0:
		return RIDER[e].trim_suffix(")") + ", Lv%d까지)" % int(Rules.t("wood_cap"))
	return RIDER[e]


## 부가효과: 같은 오브젝트의 모든 공격에 붙는다
const RIDER := {
	FIRE: "화상: 한동안 계속 피해",
	WOOD: "가시: 이 오브젝트가 주는 피해 +20% (레벨마다)",
	WATER: "감속 (느려짐)",
	ELECTRIC: "주변 구체로 튀는 전류 (확률 30%)",
	WIND: "둘레(240) 다른 오브젝트 공격 속도 +8%/레벨 (가장 큰 바람 하나만)",
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
	{"id": "burning", "a": FIRE, "b": WOOD, "name": "장작 장판", "desc": "장작이 굴러간 자리에 불 장판", "color": Color(1.0, 0.62, 0.1)},
	{"id": "steam", "a": FIRE, "b": WATER, "name": "증기", "desc": "물길 위 증기가 그 줄의 구체를 느리게 하고 받는 피해 +30%", "color": Color(0.85, 0.88, 0.94)},
	{"id": "vine", "a": WATER, "b": WOOD, "name": "덩굴", "desc": "물길 따라 자란 덩굴이 지나가는 구체를 묶음", "color": Color(0.16, 0.58, 0.3)},
	{"id": "shock", "a": WATER, "b": ELECTRIC, "name": "감전 물길", "desc": "공격 방향으로 흐르는 물길에 전기가 흘러 지나가는 구체에 피해", "color": Color(0.55, 0.85, 1.0)},
	{"id": "firestorm", "a": FIRE, "b": WIND, "name": "화염 회오리", "desc": "불타는 회오리가 전진", "color": Color(1.0, 0.5, 0.15)},
	{"id": "blizzard", "a": ICE, "b": WIND, "name": "눈보라", "desc": "주변 원 안의 구체를 느리게 하고 냉기를 쌓음", "color": Color(0.85, 0.95, 1.0)},
	{"id": "eclipse", "a": DARK, "b": LIGHT, "name": "일식", "desc": "몇 초마다 화면 안 모든 구체에 피해", "color": Color(0.95, 0.75, 1.0)},
	{"id": "lava", "a": EARTH, "b": FIRE, "name": "용암", "desc": "맞은 구체에 용암이 묻어 2초 뒤(죽으면 바로) 그 자리에서 터짐, 주변 피해·화상", "color": Color(0.95, 0.3, 0.05)},
	{"id": "mushroom", "a": POISON, "b": WOOD, "name": "독버섯 지뢰", "desc": "굴러가며 길에 떨군 독버섯, 밟으면 터짐", "color": Color(0.8, 0.5, 0.95)},
	{"id": "railgun", "a": METAL, "b": ELECTRIC, "name": "레일건", "desc": "체력이 가장 많은 구체를 조준해 화면 끝까지 관통 일격", "color": Color(0.7, 0.95, 1.0)},
	{"id": "halo", "a": METAL, "b": LIGHT, "name": "광륜", "desc": "주위를 도는 빛 칼날, 닿으면 반드시 치명타", "color": Color(1.0, 0.95, 0.6)},
	{"id": "quake", "a": METAL, "b": EARTH, "name": "지진", "desc": "몇 초마다 주변 구체 모두에 피해를 주고 기절시킴", "color": Color(0.75, 0.6, 0.45)},
	{"id": "storm", "a": ELECTRIC, "b": WIND, "name": "뇌우", "desc": "번개 구름이 앞으로 떠가며 낙뢰", "color": Color(0.75, 0.8, 1.0)},
	{"id": "aurora", "a": ICE, "b": LIGHT, "name": "오로라", "desc": "5갈래 빛줄기, 냉기가 크게 쌓임", "color": Color(0.5, 1.0, 0.8)},
	{"id": "swamp", "a": EARTH, "b": POISON, "name": "독늪", "desc": "맞은 구체가 3초 안에 죽으면 그 자리에 늪, 늪 안은 느려지고 중독 2배·죽으면 독 폭발과 늪이 번짐", "color": Color(0.5, 0.6, 0.2)},
	{"id": "curse", "a": DARK, "b": POISON, "name": "저주", "desc": "저주 걸린 구체는 계속 피해를 받고, 죽으면 주변에 큰 피해를 주며 저주가 옆 구체로 옮겨 감", "color": Color(0.6, 0.2, 0.7)},
	{"id": "prison", "a": ICE, "b": DARK, "name": "빙결 감옥", "desc": "얼음 덩이가 지나간 길에 닿은 구체를 멈추고 받는 피해 +50%", "color": Color(0.45, 0.5, 0.95)},
	{"id": "bell", "a": METAL, "b": SOUND, "name": "종", "desc": "주기적으로 종이 울려 앞쪽 부채꼴 구체에 울림 2번씩", "color": Color(0.95, 0.8, 0.55)},
	{"id": "shatter", "a": ICE, "b": SOUND, "name": "파쇄", "desc": "앞쪽 파동이 냉기를 쌓고, 빙결된 구체는 깨지며 큰 피해·파편", "color": Color(0.8, 0.85, 1.0)},
	{"id": "silence", "a": DARK, "b": SOUND, "name": "침묵", "desc": "앞쪽 파동에 맞은 구체는 2초간 저항·굳셈이 꺼지고 보스는 부하를 못 부름", "color": Color(0.55, 0.4, 0.65)},
	{"id": "afterimage", "a": LIGHT, "b": TIME, "name": "잔광", "desc": "화면 끝까지 관통하는 광선, 1.2초 뒤 같은 자리에 한 번 더", "color": Color(1.0, 0.9, 0.6)},
	{"id": "rewind", "a": ELECTRIC, "b": TIME, "name": "되감기 번개", "desc": "연쇄 번개가 친 구체들을 1초 뒤 한 번 더 침", "color": Color(0.95, 0.95, 0.5)},
	{"id": "hourglass", "a": EARTH, "b": TIME, "name": "모래시계", "desc": "맞은 구체를 1초 전 위치로 되감고(같은 구체는 4초에 한 번, 보스는 절반) 받은 피해의 절반을 다시 받음", "color": Color(0.85, 0.7, 0.4)},
	{"id": "styx", "a": WATER, "b": SOUL, "name": "망자의 강", "desc": "물길 안에서 죽은 구체는 반드시 혼불이 됨", "color": Color(0.5, 0.55, 0.95)},
	{"id": "plague", "a": POISON, "b": SOUL, "name": "역병 혼불", "desc": "쫓아가 맞힌 구체를 강하게 중독시키는 혼불 2개", "color": Color(0.65, 0.9, 0.5)},
	{"id": "spirit", "a": WOOD, "b": SOUL, "name": "고목령", "desc": "쫓아가 맞힌 구체를 묶는 혼불 2개", "color": Color(0.5, 0.8, 0.55)},
	# 2026-10-30: 빈 칸 65개 (RxMore)
	{"id": "miasma", "a": WIND, "b": POISON, "name": "독바람", "desc": "독 안개가 넓어지며 전진, 지나간 구체 중독. 이미 중독된 구체는 남은 중독의 절반을 바로 받음", "color": Color(0.6, 0.85, 0.35)},
	{"id": "sandstorm", "a": WIND, "b": EARTH, "name": "모래 폭풍", "desc": "모래 회오리가 전진, 안에서 느려지고 자주 기절", "color": Color(0.85, 0.72, 0.45)},
	{"id": "seedwind", "a": WIND, "b": WOOD, "name": "씨앗 바람", "desc": "씨앗이 날아가 박힘: 받는 피해 +15%씩(최대 3), 3초 뒤 싹이 터 피해·묶음", "color": Color(0.55, 0.85, 0.4)},
	{"id": "tidal", "a": WIND, "b": WATER, "name": "파도", "desc": "넓은 파도가 밀려가며 구체를 밀어내고, 지나간 자리에 물길", "color": Color(0.4, 0.75, 1.0)},
	{"id": "vacuum", "a": WIND, "b": DARK, "name": "진공 회오리", "desc": "작은 블랙홀이 전진하며 가운데로 끌고 받는 피해 +30%", "color": Color(0.5, 0.4, 0.75)},
	{"id": "feather", "a": WIND, "b": LIGHT, "name": "빛 깃털", "desc": "빛 깃털 6개가 퍼지며 날아감, 반드시 치명타", "color": Color(1.0, 1.0, 0.75)},
	{"id": "bladewind", "a": WIND, "b": METAL, "name": "칼바람", "desc": "칼날 3개가 날아갔다 돌아옴, 관통·경직", "color": Color(0.75, 0.85, 0.85)},
	{"id": "whistle", "a": WIND, "b": SOUND, "name": "휘파람", "desc": "앞으로 나아가며 넓어지는 파동, 울림", "color": Color(0.85, 0.7, 0.8)},
	{"id": "galeback", "a": WIND, "b": TIME, "name": "되돌이 바람", "desc": "회오리가 가다가 같은 길로 되돌아옴", "color": Color(0.8, 0.9, 0.7)},
	{"id": "wraith", "a": WIND, "b": SOUL, "name": "원령 회오리", "desc": "회오리 안에서 죽은 구체는 반드시 혼불이 됨", "color": Color(0.7, 0.75, 1.0)},
	{"id": "thermal", "a": ICE, "b": FIRE, "name": "열충격", "desc": "앞 직선, 냉기 쌓인 구체는 냉기를 모두 써서 터짐 (없으면 냉기)", "color": Color(1.0, 0.6, 0.6)},
	{"id": "frostthorn", "a": ICE, "b": WOOD, "name": "서리 가시", "desc": "가시 5발, 냉기를 쌓고 빙결된 구체에는 피해 3배", "color": Color(0.6, 0.9, 0.85)},
	{"id": "glacier", "a": ICE, "b": WATER, "name": "빙하 물결", "desc": "흘러가는 물결이 남긴 물길에서 냉기가 쌓이고 빙결이 1.5배 오래감", "color": Color(0.6, 0.85, 1.0)},
	{"id": "frostbolt", "a": ICE, "b": ELECTRIC, "name": "빙뢰", "desc": "연쇄 번개, 냉기 있는 구체끼리는 멀리 튀고 피해 2배", "color": Color(0.75, 0.95, 1.0)},
	{"id": "icecrack", "a": ICE, "b": EARTH, "name": "빙하 균열", "desc": "앞으로 뻗는 균열이 남긴 얼음 띠: 냉기·감속, 빙결된 채 닿으면 기절", "color": Color(0.7, 0.8, 0.9)},
	{"id": "coldneedle", "a": ICE, "b": POISON, "name": "냉독침", "desc": "독침 3발, 중독·냉기, 빙결된 동안 중독 피해 2배", "color": Color(0.6, 0.95, 0.8)},
	{"id": "icelance", "a": ICE, "b": METAL, "name": "빙창", "desc": "관통하는 얼음 창, 빙결된 구체는 피해 3배·파편", "color": Color(0.75, 0.85, 0.95)},
	{"id": "frostecho", "a": ICE, "b": TIME, "name": "서리 메아리", "desc": "앞 직선 냉기 파동이 1초 뒤 한 번 더", "color": Color(0.8, 0.9, 0.95)},
	{"id": "frostsoul", "a": ICE, "b": SOUL, "name": "얼음 넋", "desc": "쫓아가 맞힌 구체를 바로 얼리는 혼불 2개", "color": Color(0.7, 0.8, 1.0)},
	{"id": "thornvine", "a": EARTH, "b": WOOD, "name": "가시 덩굴", "desc": "균열이 남긴 가시 띠: 느려지고 받는 피해 +20%", "color": Color(0.45, 0.6, 0.3)},
	{"id": "mud", "a": EARTH, "b": WATER, "name": "진흙 물결", "desc": "물결이 남긴 진흙: 크게 느려지고 기절 확률 2배", "color": Color(0.55, 0.45, 0.3)},
	{"id": "ground", "a": EARTH, "b": ELECTRIC, "name": "전류 균열", "desc": "균열이 남긴 띠에서 0.5초마다 전류, 가끔 기절", "color": Color(0.85, 0.8, 0.4)},
	{"id": "shadowcrack", "a": EARTH, "b": DARK, "name": "그림자 균열", "desc": "균열이 남긴 그림자 띠: 받는 피해 +40%·감속", "color": Color(0.45, 0.35, 0.55)},
	{"id": "crystal", "a": EARTH, "b": LIGHT, "name": "수정 균열", "desc": "균열이 남긴 수정 띠 위 피해는 반드시 치명타", "color": Color(0.85, 0.95, 1.0)},
	{"id": "rumble", "a": EARTH, "b": SOUND, "name": "울림 균열", "desc": "균열이 남긴 띠: 울림이 쌓이고 음파 피해 +20%", "color": Color(0.8, 0.6, 0.55)},
	{"id": "tomb", "a": EARTH, "b": SOUL, "name": "무덤 균열", "desc": "균열이 남긴 띠에서 죽으면 혼불 2개", "color": Color(0.6, 0.55, 0.75)},
	{"id": "smog", "a": POISON, "b": FIRE, "name": "독연기", "desc": "느리게 떠가는 연기, 화상과 중독을 같이 걸고 둘 다 걸리면 중독 2배", "color": Color(0.7, 0.65, 0.3)},
	{"id": "foulwater", "a": POISON, "b": WATER, "name": "오염 물결", "desc": "물결이 남긴 물길에서 중독, 안에서 죽으면 중독이 주변으로 퍼짐", "color": Color(0.5, 0.75, 0.45)},
	{"id": "neurotoxin", "a": POISON, "b": ELECTRIC, "name": "신경독", "desc": "앞쪽 중독된 구체 전부에 전류·경직, 중독이 더 세짐", "color": Color(0.8, 0.95, 0.3)},
	{"id": "corrosive", "a": POISON, "b": LIGHT, "name": "부식광", "desc": "화면 끝까지 광선, 맞은 구체 중독 2배", "color": Color(0.85, 1.0, 0.45)},
	{"id": "rust", "a": POISON, "b": METAL, "name": "부식", "desc": "녹 탄 3발: 중독, 받는 피해 +8%씩 (최대 5번)", "color": Color(0.75, 0.5, 0.3)},
	{"id": "toxecho", "a": POISON, "b": SOUND, "name": "독 메아리", "desc": "부채꼴 파동이 중독, 울림 음파가 터지면 주변에 중독", "color": Color(0.75, 0.85, 0.55)},
	{"id": "latent", "a": POISON, "b": TIME, "name": "잠복 독", "desc": "가장 많이 중독된 구체 5개가 2초 뒤 남은 중독을 한 번에 받음", "color": Color(0.6, 0.8, 0.35)},
	{"id": "plasma", "a": FIRE, "b": ELECTRIC, "name": "플라스마 구", "desc": "느린 불덩이가 지나가며 주변에 번개·화상", "color": Color(1.0, 0.7, 0.9)},
	{"id": "blackfire", "a": FIRE, "b": DARK, "name": "흑염", "desc": "검은 불꽃 3발: 화상, 받는 피해 +25%", "color": Color(0.6, 0.25, 0.4)},
	{"id": "solar", "a": FIRE, "b": LIGHT, "name": "태양 광선", "desc": "화면 끝까지 굵은 광선, 화상", "color": Color(1.0, 0.85, 0.4)},
	{"id": "hotiron", "a": FIRE, "b": METAL, "name": "달군 철구", "desc": "관통 철구가 화상, 끝에서 폭발", "color": Color(1.0, 0.5, 0.3)},
	{"id": "blast", "a": FIRE, "b": SOUND, "name": "폭음", "desc": "부채꼴 파동, 화상 걸린 구체는 남은 화상을 바로 받음", "color": Color(1.0, 0.55, 0.45)},
	{"id": "embers", "a": FIRE, "b": TIME, "name": "잔불", "desc": "불덩이에 맞은 구체가 1초·2초 뒤 그 자리에서 또 터짐", "color": Color(1.0, 0.65, 0.3)},
	{"id": "foxfire", "a": FIRE, "b": SOUL, "name": "도깨비불", "desc": "화상 혼불 3개, 맞은 구체가 죽으면 옆으로 불이 옮음", "color": Color(0.6, 0.75, 1.0)},
	{"id": "conduct", "a": WOOD, "b": ELECTRIC, "name": "전도 덩굴", "desc": "가까운 구체를 덩굴로 감아 전기, 옆 구체로 튐", "color": Color(0.6, 0.85, 0.35)},
	{"id": "rotroot", "a": WOOD, "b": DARK, "name": "썩은 뿌리", "desc": "체력이 가장 많은 구체를 묶고 받는 피해 +40%", "color": Color(0.4, 0.35, 0.3)},
	{"id": "photo", "a": WOOD, "b": LIGHT, "name": "광합성", "desc": "화면 끝까지 광선, 맞힌 수만큼 이 오브젝트 공격 속도 증가", "color": Color(0.75, 1.0, 0.5)},
	{"id": "saw", "a": WOOD, "b": METAL, "name": "톱날", "desc": "굴러가는 톱날이 관통, 받는 피해 +20%", "color": Color(0.7, 0.7, 0.6)},
	{"id": "drum", "a": WOOD, "b": SOUND, "name": "공명목", "desc": "부채꼴 파동이 잠깐 묶고 울림", "color": Color(0.75, 0.6, 0.4)},
	{"id": "rings", "a": WOOD, "b": TIME, "name": "나이테", "desc": "앞 직선 가시 줄기가 1.2초 뒤 더 크게 한 번 더", "color": Color(0.65, 0.55, 0.35)},
	{"id": "blackwater", "a": WATER, "b": DARK, "name": "검은 물결", "desc": "물결이 남긴 검은 물길: 가운데로 끌리고 받는 피해 +30%", "color": Color(0.3, 0.35, 0.6)},
	{"id": "rainbow", "a": WATER, "b": LIGHT, "name": "무지개", "desc": "물결이 남긴 물길 위 구체는 치명타 확률 +30%", "color": Color(0.75, 0.85, 1.0)},
	{"id": "mercury", "a": WATER, "b": METAL, "name": "수은 물결", "desc": "물결이 남긴 수은 물길에서 0.5초마다 피해·경직", "color": Color(0.75, 0.78, 0.85)},
	{"id": "ripple", "a": WATER, "b": SOUND, "name": "파문", "desc": "물결이 남긴 물길에서 울림이 쌓임", "color": Color(0.6, 0.7, 0.95)},
	{"id": "backflow", "a": WATER, "b": TIME, "name": "역류", "desc": "물결이 가다가 거꾸로 돌아오며 밀어냄", "color": Color(0.5, 0.7, 0.85)},
	{"id": "darkbolt", "a": ELECTRIC, "b": DARK, "name": "검은 번개", "desc": "받는 피해가 늘어난 구체 전부에 번개", "color": Color(0.65, 0.5, 0.9)},
	{"id": "flash", "a": ELECTRIC, "b": LIGHT, "name": "섬광", "desc": "화면 끝까지 광선, 맞은 구체 잠깐 기절", "color": Color(1.0, 1.0, 0.6)},
	{"id": "resonate", "a": ELECTRIC, "b": SOUND, "name": "공진", "desc": "부채꼴 파동, 맞은 구체마다 옆으로 번개", "color": Color(1.0, 0.75, 0.6)},
	{"id": "soulbolt", "a": ELECTRIC, "b": SOUL, "name": "혼뢰", "desc": "맞히면 3개로 연쇄하는 혼불 2개", "color": Color(0.85, 0.8, 1.0)},
	{"id": "scythe", "a": DARK, "b": METAL, "name": "처형 낫", "desc": "앞 반원 휘두르기, 체력 20% 아래 일반·빠른 구체는 바로 처치", "color": Color(0.55, 0.5, 0.65)},
	{"id": "dusk", "a": DARK, "b": TIME, "name": "황혼", "desc": "앞쪽 구체 3개에 표식, 2초 뒤 터지고 그동안 받는 피해 +30%", "color": Color(0.7, 0.45, 0.6)},
	{"id": "phantom", "a": DARK, "b": SOUL, "name": "망령", "desc": "받는 피해 +30% 혼불 3개, 맞은 구체가 죽으면 혼불", "color": Color(0.6, 0.45, 0.85)},
	{"id": "clarion", "a": LIGHT, "b": SOUND, "name": "섬광음", "desc": "부채꼴 파동, 반드시 치명타", "color": Color(1.0, 0.9, 0.7)},
	{"id": "angel", "a": LIGHT, "b": SOUL, "name": "빛 혼불", "desc": "반드시 치명타인 혼불 4개", "color": Color(1.0, 0.95, 0.85)},
	{"id": "pendulum", "a": METAL, "b": TIME, "name": "진자", "desc": "앞에서 크게 왕복하는 철 추, 경직", "color": Color(0.8, 0.75, 0.55)},
	{"id": "sword", "a": METAL, "b": SOUL, "name": "떠도는 검", "desc": "구체를 쫓아가며 관통하는 검 2개", "color": Color(0.75, 0.75, 0.95)},
	{"id": "reverb", "a": SOUND, "b": TIME, "name": "메아리", "desc": "부채꼴 파동이 1초·2초 뒤 두 번 더", "color": Color(0.95, 0.7, 0.6)},
	{"id": "requiem", "a": SOUND, "b": SOUL, "name": "진혼곡", "desc": "부채꼴 파동에 맞은 구체는 3초 안에 죽으면 혼불", "color": Color(0.75, 0.6, 0.85)},
	{"id": "samsara", "a": TIME, "b": SOUL, "name": "윤회", "desc": "혼불 2개, 맞힌 구체가 죽으면 1초 뒤 그 자리에서 혼불 2개", "color": Color(0.9, 0.75, 0.85)},
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
