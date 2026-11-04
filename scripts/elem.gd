class_name Elem
## 속성 정의. 한 오브젝트에 넣는 속성 종류 수는 규칙 버전 상한(rules.gd), 레벨은 제한 없음.
## - 겹친 속성마다 고유 공격(FORM)이 모두 발사된다.
## - 모든 공격에 겹친 속성 전부의 부가효과(RIDER)가 붙는다.
## - 속성마다 효과(RIDER) 하나와 특징(TRAIT) 하나. 특징은 같은 오브젝트의 모든 효과를 실어 나른다 (Share, 2026-11-03).
##   정해 둔 조합 공격은 없다. 두 속성 짝 105개(REACTIONS)는 도감·알림용 이름표일 뿐이다.

enum { FIRE, WOOD, WATER, ELECTRIC, WIND, ICE, EARTH, DARK, LIGHT, POISON, METAL, SOUND, TIME, SOUL, STAR }

const ALL := [FIRE, WOOD, WATER, ELECTRIC, WIND, ICE, EARTH, DARK, LIGHT, POISON, METAL, SOUND, TIME, SOUL, STAR]

const NAMES := {
	FIRE: "불", WOOD: "나무", WATER: "물", ELECTRIC: "전기", WIND: "바람", ICE: "얼음",
	EARTH: "땅", DARK: "어둠", LIGHT: "빛", POISON: "독", METAL: "금속",
	SOUND: "소리", TIME: "시간", SOUL: "영혼", STAR: "별",
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
	STAR: Color(1.0, 0.93, 0.68),
}

## 속성 기호: 이름 첫 글자를 검은 테두리로 (색이 밝아도 어두워도 읽히게). c는 글자 가운데.
static func draw_symbol(ci: CanvasItem, _font: Font, c: Vector2, e: int, fs: int) -> void:
	# 글자 대신 속성 그림 (어두운 바탕 원 위 흰색). fs는 예전 글자 크기 → 그림 크기
	var s := fs * 0.5
	ci.draw_circle(c, s * 1.3, Color(0, 0, 0, 0.55))
	Glyph.elem(ci, e, c, s, Color.WHITE)


## 속성과 같은 색의 공격방식 (도감 설명용. 규칙 1·3에서 속성은 공격 모양을 바꾸지 않고, 공격방식은 따로 카드로 얻는다)
const FORM := {
	FIRE: "화염 방사 (부채꼴 지속 피해)",
	WOOD: "관통 가시 연사",
	WATER: "물줄기 (멈춰 세움)",
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
	STAR: "없음 (어느 공격방식이든 초신성은 같은 모양)",
}

## 특징 (2026-11-03 특징 공유): 이 속성이 든 오브젝트의 효과(적중 효과, RIDER)를 어떻게 다른 구체·때·자리로 실어 나르는지.
## 자기 효과와 같은 오브젝트 다른 속성 효과에 모두 붙는다. 실어 나른 효과는 특징을 다시 타지 않는다(한 번만).
## 세기는 특징 속성 레벨 Lv1 60% · Lv2 80% · Lv3 이상 100% (Share.k). 실어 나르는 비율은 Share 상수.
## 나무·바람·빛·별의 효과는 오브젝트에 걸려서 실어 나르지 않는다 (CARRY 밖). 이 넷은 특징으로만 섞인다.
const TRAIT := {
	FIRE: "죽으면 불꽃: 효과가 걸린 구체의 화상이 끝나거나 죽을 때 불꽃이 터져 주변 구체에 효과 40%를 전해요.",
	WOOD: "멀수록 셈: 오브젝트에서 멀리 맞힐수록 효과가 세져요. (100마다 +6%, 최대 +30%)",
	WATER: "물길에 남김: 날아가는 공격이 지나간 길에 물길(2초)이 남고, 밟은 구체에 효과 30%를 전해요.",
	ELECTRIC: "번개로 옮김: 번개가 튈 때 효과도 옆 구체로 50% 전해요.",
	WIND: "범위 넓힘: 번개·음파·전염·불꽃·끌어모음·빛줄기 범위 +40%",
	ICE: "오래 지속: 효과 지속 시간 x1.5",
	EARTH: "다시 맞으면 더: 효과가 구체에 묻어, 2초 안에 다시 맞으면 효과 70%를 한 번 더 전해요.",
	DARK: "죽으면 끌어모음: 받는 피해↑가 걸린 구체가 죽으면 주변 구체를 그 자리로 끌고 효과 30%를 전해요.",
	LIGHT: "치명타 관통: 치명타가 나면 그 뒤 일직선 구체들에 효과 40%를 전해요.",
	POISON: "죽으면 전염: 중독된 구체가 죽으면 주변 구체에 효과 50%를 전해요.",
	METAL: "효과 수만큼 피해: 효과를 걸 때마다 효과 수만큼 추가 피해를 줘요. (하나당 위력의 12%)",
	SOUND: "음파로 퍼짐: 3타 음파가 터질 때 음파에 닿은 구체에 효과 50%를 전해요.",
	TIME: "조금 뒤 한 번 더: 0.8초 뒤 같은 구체에 효과 50%를 한 번 더 전해요.",
	SOUL: "혼불이 실어 감: 소환된 혼불이 이 오브젝트의 공격처럼 맞혀 모든 효과를 그대로 걸어요.",
	STAR: "초신성에 실음: 초신성이 맞힌 구체 모두에 효과 100%를 전해요.",
}

## 특징이 실어 나를 수 있는 효과(구체에 걸리는 적중 효과)
const CARRY := [FIRE, WATER, ELECTRIC, ICE, EARTH, DARK, POISON, METAL, SOUND, TIME, SOUL]

## 카드 간소화용 짧은 이름. 부가효과(적중 효과)는 맞힌 구체에, 형태 성질은 공격 모양(지나간 길·끝 자리)에 붙는다.
## 두 이름이 같으면 안 된다 (2026-10-31 소리 울림·울림 → 형태는 잔향)
static func rider_name(e: int) -> String:
	return (RIDER[e] as String).get_slice(":", 0)


static func trait_name(e: int) -> String:
	return (TRAIT[e] as String).get_slice(":", 0)


## 기본 카드의 주효과. 용어를 몰라도 결과를 예상할 수 있게 쓰며 수치·형태 성질은 자세히에 남긴다.
const BRIEF := {
	FIRE: "맞은 구체를 태워 한동안 계속 피해를 줘요.",
	WOOD: "이 오브젝트의 모든 공격 피해를 높여요.",
	WATER: "맞은 구체를 느리게 해요.",
	ELECTRIC: "확률로 주변 구체에 전기가 튀어요.",
	WIND: "주변 다른 오브젝트의 공격을 빠르게 해요. 가장 강한 바람 하나만 적용돼요.",
	ICE: "냉기를 쌓아 구체를 잠깐 멈춰요.",
	EARTH: "맞은 구체를 확률로 잠깐 기절시켜요.",
	DARK: "맞은 구체가 받는 피해를 늘려요.",
	LIGHT: "확률로 치명타를 내 더 큰 피해를 줘요.",
	POISON: "독으로 계속 피해를 주고, 죽으면 주변에 독이 퍼져요.",
	METAL: "맞힐 때 피해를 더하고 구체를 잠깐 멈칫하게 해요.",
	SOUND: "울림이 남은 구체는 세 번 맞을 때마다 주변에 음파를 터뜨려요.",
	TIME: "맞은 구체가 잠시 동안 받은 피해 일부를 나중에 한 번 더 받아요.",
	SOUL: "맞은 구체가 곧 죽으면 확률로 다른 구체를 쫓는 혼불이 나와요.",
	STAR: "주변과 자신의 공격 피해를 복사해 모으고, 다 차면 폭발해요.",
}


## 부가효과 설명. 나무는 규칙마다 세는 최대 레벨(Rules wood_cap)이 달라 붙여 보여 준다
static func rider(e: int) -> String:
	if e == WOOD and Rules.wood_cap < 50.0:
		return Rules.fmt(RIDER[e]).trim_suffix(")") + ", Lv%d까지)" % int(Rules.wood_cap)
	return Rules.fmt(RIDER[e])


## 부가효과: 같은 오브젝트의 모든 공격에 붙는다
const RIDER := {
	FIRE: "화상: 한동안 계속 피해를 줘요.",
	WOOD: "피해 증가: 이 오브젝트가 주는 피해 +{wood_dmg%}% (레벨마다)",
	WATER: "감속: 느려져요. (레벨이 높을수록 더)",
	ELECTRIC: "번개 튐: 주변 구체로 번개가 튀어요. (확률 {elec_ch%}%)",
	WIND: "주변 가속: 둘레({wind_range}) 다른 오브젝트 공격 속도 +{wind_buff%}%/레벨 (가장 큰 바람 하나만)",
	ICE: "얼림: 냉기가 쌓이면 잠깐 멈춰요.",
	EARTH: "기절: 레벨마다 확률 +{earth_ch%}%, 최대 {earth_max%}%",
	DARK: "받는 피해↑: {dark_t}초간 받는 피해 +{dark_vuln%}% (레벨마다 +{dark_lv%}%)",
	LIGHT: "치명타: 피해 {light_mul}배 (레벨마다 확률 +{light_ch%}%, 최대 {light_max%}%)",
	POISON: "중독: 죽으면 주변에 전염돼요.",
	METAL: "일격·멈칫: 맞힌 피해 +{metal_dmg%}% (레벨마다) + 제자리에 잠깐 멈춰요.",
	SOUND: "3타 음파: {sound_t}초간 어느 오브젝트에 맞든 3번째마다 주변에 음파가 터져요.",
	TIME: "피해 되풀이: {time_t}초간 받은 피해의 일부를 한 번 더 받아요.",
	SOUL: "혼불 소환: {soul_t}초 안에 죽으면 확률로 혼불이 나와 다른 구체를 쫓아요.",
	STAR: "피해 모으기: 둘레({star_r}) 다른 오브젝트 피해의 {star_take%}%(+{star_lv%}%/레벨)를 복사해 모으고, 다 차면 초신성이 터져요. (별만 들면 x{star_pure}, 보스는 한 번에 체력 {star_boss_cap%}%까지)",
}

## 두 속성 짝 105개 (id는 도감 저장과 맞추려고 예전 특수 반응 id를 그대로 쓴다). 이름·설명은 특징 공유에서 만든다 (_build_pairs)
const PAIRS := [
	["burning", FIRE, WOOD, Color(1.0, 0.62, 0.1)],
	["steam", FIRE, WATER, Color(0.85, 0.88, 0.94)],
	["vine", WATER, WOOD, Color(0.16, 0.58, 0.3)],
	["shock", WATER, ELECTRIC, Color(0.55, 0.85, 1.0)],
	["firestorm", FIRE, WIND, Color(1.0, 0.5, 0.15)],
	["blizzard", ICE, WIND, Color(0.85, 0.95, 1.0)],
	["eclipse", DARK, LIGHT, Color(0.95, 0.75, 1.0)],
	["lava", EARTH, FIRE, Color(0.95, 0.3, 0.05)],
	["mushroom", POISON, WOOD, Color(0.8, 0.5, 0.95)],
	["railgun", METAL, ELECTRIC, Color(0.7, 0.95, 1.0)],
	["halo", METAL, LIGHT, Color(1.0, 0.95, 0.6)],
	["quake", METAL, EARTH, Color(0.75, 0.6, 0.45)],
	["storm", ELECTRIC, WIND, Color(0.75, 0.8, 1.0)],
	["aurora", ICE, LIGHT, Color(0.5, 1.0, 0.8)],
	["swamp", EARTH, POISON, Color(0.5, 0.6, 0.2)],
	["curse", DARK, POISON, Color(0.6, 0.2, 0.7)],
	["prison", ICE, DARK, Color(0.45, 0.5, 0.95)],
	["bell", METAL, SOUND, Color(0.95, 0.8, 0.55)],
	["shatter", ICE, SOUND, Color(0.8, 0.85, 1.0)],
	["silence", DARK, SOUND, Color(0.55, 0.4, 0.65)],
	["afterimage", LIGHT, TIME, Color(1.0, 0.9, 0.6)],
	["rewind", ELECTRIC, TIME, Color(0.95, 0.95, 0.5)],
	["hourglass", EARTH, TIME, Color(0.85, 0.7, 0.4)],
	["styx", WATER, SOUL, Color(0.5, 0.55, 0.95)],
	["plague", POISON, SOUL, Color(0.65, 0.9, 0.5)],
	["spirit", WOOD, SOUL, Color(0.5, 0.8, 0.55)],
	["nova_fire", STAR, FIRE, Color(1.0, 0.6, 0.3)],
	["nova_wood", STAR, WOOD, Color(0.7, 0.95, 0.55)],
	["nova_water", STAR, WATER, Color(0.6, 0.85, 1.0)],
	["nova_electric", STAR, ELECTRIC, Color(1.0, 1.0, 0.6)],
	["nova_wind", STAR, WIND, Color(0.8, 1.0, 0.9)],
	["nova_ice", STAR, ICE, Color(0.85, 0.95, 1.0)],
	["nova_earth", STAR, EARTH, Color(0.9, 0.75, 0.5)],
	["nova_dark", STAR, DARK, Color(0.75, 0.55, 1.0)],
	["nova_light", STAR, LIGHT, Color(1.0, 1.0, 0.9)],
	["nova_poison", STAR, POISON, Color(0.8, 1.0, 0.45)],
	["nova_metal", STAR, METAL, Color(0.85, 0.87, 0.95)],
	["nova_sound", STAR, SOUND, Color(1.0, 0.7, 0.85)],
	["nova_time", STAR, TIME, Color(1.0, 0.88, 0.55)],
	["nova_soul", STAR, SOUL, Color(0.9, 0.78, 1.0)],
	["miasma", WIND, POISON, Color(0.6, 0.85, 0.35)],
	["sandstorm", WIND, EARTH, Color(0.85, 0.72, 0.45)],
	["seedwind", WIND, WOOD, Color(0.55, 0.85, 0.4)],
	["tidal", WIND, WATER, Color(0.4, 0.75, 1.0)],
	["vacuum", WIND, DARK, Color(0.5, 0.4, 0.75)],
	["feather", WIND, LIGHT, Color(1.0, 1.0, 0.75)],
	["bladewind", WIND, METAL, Color(0.75, 0.85, 0.85)],
	["whistle", WIND, SOUND, Color(0.85, 0.7, 0.8)],
	["galeback", WIND, TIME, Color(0.8, 0.9, 0.7)],
	["wraith", WIND, SOUL, Color(0.7, 0.75, 1.0)],
	["thermal", ICE, FIRE, Color(1.0, 0.6, 0.6)],
	["frostthorn", ICE, WOOD, Color(0.6, 0.9, 0.85)],
	["glacier", ICE, WATER, Color(0.6, 0.85, 1.0)],
	["frostbolt", ICE, ELECTRIC, Color(0.75, 0.95, 1.0)],
	["icecrack", ICE, EARTH, Color(0.7, 0.8, 0.9)],
	["coldneedle", ICE, POISON, Color(0.6, 0.95, 0.8)],
	["icelance", ICE, METAL, Color(0.75, 0.85, 0.95)],
	["frostecho", ICE, TIME, Color(0.8, 0.9, 0.95)],
	["frostsoul", ICE, SOUL, Color(0.7, 0.8, 1.0)],
	["thornvine", EARTH, WOOD, Color(0.45, 0.6, 0.3)],
	["mud", EARTH, WATER, Color(0.55, 0.45, 0.3)],
	["ground", EARTH, ELECTRIC, Color(0.85, 0.8, 0.4)],
	["shadowcrack", EARTH, DARK, Color(0.45, 0.35, 0.55)],
	["crystal", EARTH, LIGHT, Color(0.85, 0.95, 1.0)],
	["rumble", EARTH, SOUND, Color(0.8, 0.6, 0.55)],
	["tomb", EARTH, SOUL, Color(0.6, 0.55, 0.75)],
	["smog", POISON, FIRE, Color(0.7, 0.65, 0.3)],
	["foulwater", POISON, WATER, Color(0.5, 0.75, 0.45)],
	["neurotoxin", POISON, ELECTRIC, Color(0.8, 0.95, 0.3)],
	["corrosive", POISON, LIGHT, Color(0.85, 1.0, 0.45)],
	["rust", POISON, METAL, Color(0.75, 0.5, 0.3)],
	["toxecho", POISON, SOUND, Color(0.75, 0.85, 0.55)],
	["latent", POISON, TIME, Color(0.6, 0.8, 0.35)],
	["plasma", FIRE, ELECTRIC, Color(1.0, 0.7, 0.9)],
	["blackfire", FIRE, DARK, Color(0.6, 0.25, 0.4)],
	["solar", FIRE, LIGHT, Color(1.0, 0.85, 0.4)],
	["hotiron", FIRE, METAL, Color(1.0, 0.5, 0.3)],
	["blast", FIRE, SOUND, Color(1.0, 0.55, 0.45)],
	["embers", FIRE, TIME, Color(1.0, 0.65, 0.3)],
	["foxfire", FIRE, SOUL, Color(0.6, 0.75, 1.0)],
	["conduct", WOOD, ELECTRIC, Color(0.6, 0.85, 0.35)],
	["rotroot", WOOD, DARK, Color(0.4, 0.35, 0.3)],
	["photo", WOOD, LIGHT, Color(0.75, 1.0, 0.5)],
	["saw", WOOD, METAL, Color(0.7, 0.7, 0.6)],
	["drum", WOOD, SOUND, Color(0.75, 0.6, 0.4)],
	["rings", WOOD, TIME, Color(0.65, 0.55, 0.35)],
	["blackwater", WATER, DARK, Color(0.3, 0.35, 0.6)],
	["rainbow", WATER, LIGHT, Color(0.75, 0.85, 1.0)],
	["mercury", WATER, METAL, Color(0.75, 0.78, 0.85)],
	["ripple", WATER, SOUND, Color(0.6, 0.7, 0.95)],
	["backflow", WATER, TIME, Color(0.5, 0.7, 0.85)],
	["darkbolt", ELECTRIC, DARK, Color(0.65, 0.5, 0.9)],
	["flash", ELECTRIC, LIGHT, Color(1.0, 1.0, 0.6)],
	["resonate", ELECTRIC, SOUND, Color(1.0, 0.75, 0.6)],
	["soulbolt", ELECTRIC, SOUL, Color(0.85, 0.8, 1.0)],
	["scythe", DARK, METAL, Color(0.55, 0.5, 0.65)],
	["dusk", DARK, TIME, Color(0.7, 0.45, 0.6)],
	["phantom", DARK, SOUL, Color(0.6, 0.45, 0.85)],
	["clarion", LIGHT, SOUND, Color(1.0, 0.9, 0.7)],
	["angel", LIGHT, SOUL, Color(1.0, 0.95, 0.85)],
	["pendulum", METAL, TIME, Color(0.8, 0.75, 0.55)],
	["sword", METAL, SOUL, Color(0.75, 0.75, 0.95)],
	["reverb", SOUND, TIME, Color(0.95, 0.7, 0.6)],
	["requiem", SOUND, SOUL, Color(0.75, 0.6, 0.85)],
	["samsara", TIME, SOUL, Color(0.9, 0.75, 0.85)],
]

## 상성 (2026-11-04): 속성마다 성질 꼬리표 1~2개. 꼬리표끼리 규칙(AFF_RULES)으로 105짝의 강·약이 저절로 정해진다.
## 새 속성은 꼬리표만 정하면 된다. 같은 오브젝트 안의 두 속성에만 걸린다 (Share.aff).
const TAGS := {
	FIRE: ["열"], WOOD: ["생명"], WATER: ["젖음"], ELECTRIC: ["전도"], WIND: ["기류"], ICE: ["차가움"],
	EARTH: ["흙"], DARK: ["그늘"], LIGHT: ["빛"], POISON: ["부식"], METAL: ["단단함", "전도"],
	SOUND: ["진동"], TIME: ["흐름"], SOUL: ["그늘"], STAR: ["빛", "열"],
}

## [꼬리표, 꼬리표, id, 이름, 강(true)·약(false), 설명]. 같은 꼬리표끼리는 SAME_AFF(강, 더하는 것 없음).
## 강: 두 속성 특징 세기 x Share.AFF_CARRY, 효과 세기 x Share.AFF_EFF + 설명의 것. 약: 줄어드는 대신 다른 효과가 생긴다.
const AFF_RULES := [
	["젖음", "전도", "shock", "감전", true, "전기가 튀는 거리 +40%, 튄 구체가 잠깐 멈칫해요."],
	["열", "생명", "fuel", "연료", true, "화상 x1.5"],
	["열", "기류", "blaze", "불길", true, "불 '죽으면 불꽃' 범위 +50%"],
	["차가움", "젖음", "freeze", "얼어붙음", true, "냉기 x1.5"],
	["차가움", "기류", "blizzard", "눈보라", true, "맞은 구체 둘레 구체에도 냉기 절반을 전해요."],
	["흙", "진동", "quake", "지진", true, "기절 확률·멈칫 x1.5"],
	["단단함", "진동", "quake", "지진", true, "기절 확률·멈칫 x1.5"],
	["부식", "단단함", "rust", "녹", true, "중독된 구체가 받는 피해 +15%"],
	["기류", "진동", "reso", "공진", true, "음파 범위 +50%"],
	["기류", "젖음", "storm", "비바람", true, "맞은 구체 둘레 구체에도 감속 절반을 전해요."],
	["젖음", "생명", "nourish", "자양", true, "나무 '멀수록 셈' 최대 +30% → +50%"],
	["그늘", "흐름", "after", "잔상", true, "시간 '조금 뒤 한 번 더'가 2번 적용돼요."],
	["열", "젖음", "steam", "증기", false, "화상·감속 절반, 대신 맞은 구체 둘레 구체도 모두 느려져요."],
	["열", "차가움", "thermo", "온도 충격", false, "화상·냉기 절반, 대신 냉기가 남은 구체를 맞히면 냉기를 터뜨려 멈칫하게 하고 피해를 줘요."],
	["빛", "그늘", "eclipse", "일식", false, "치명타 확률·받는 피해↑ 절반, 대신 치명타가 나면 받는 피해↑를 그대로 2배 시간 동안 걸어요."],
	["전도", "흙", "ground", "접지", false, "전기가 튀지 않아요. 대신 기절 확률 +20%"],
	["부식", "생명", "wither", "시듦", false, "피해 증가 절반, 대신 중독된 구체가 15% 느려져요."],
]
const SAME_AFF := ["same", "닮음", true, "같은 성질끼리 특징·효과가 함께 세져요."]

static var _aff_cache := {}


## 두 속성의 상성: {"strong": bool, "weak": bool, "ids": [규칙 id], "names": [이름], "descs": [설명]} (보통이면 둘 다 false)
static func aff_of(a: int, b: int) -> Dictionary:
	var ck := mini(a, b) * 100 + maxi(a, b)
	if _aff_cache.has(ck):
		return _aff_cache[ck]
	var out := {"strong": false, "weak": false, "ids": [], "names": [], "descs": []}
	if a != b:
		for x in TAGS.get(a, []):
			for y in TAGS.get(b, []):
				var hits := []
				if x == y:
					hits.append(SAME_AFF)
				for r in AFF_RULES:
					if (r[0] == x and r[1] == y) or (r[0] == y and r[1] == x):
						hits.append(r.slice(2))
				for h in hits:
					if h[0] in out["ids"]:
						continue
					out["ids"].append(h[0])
					out["names"].append(h[1])
					out["descs"].append(h[3])
					out["strong" if h[2] else "weak"] = true
	_aff_cache[ck] = out
	return out


## 상성 한 줄 ("감전(강)", 보통이면 "")
static func aff_label(a: int, b: int) -> String:
	var r := aff_of(a, b)
	var parts := PackedStringArray()
	for i in r["ids"].size():
		parts.append("%s(%s)" % [r["names"][i], "강" if _rule_strong(r["ids"][i]) else "약"])
	return " · ".join(parts)


static func _rule_strong(id: String) -> bool:
	if id == SAME_AFF[0]:
		return true
	for r in AFF_RULES:
		if r[2] == id:
			return r[4]
	return false


## 짝마다 {"id","a","b","name","desc","color"}. 예전 REACTIONS와 같은 모양이라 도감·알림·업적이 그대로 쓴다.
## 특징 공유(2026-11-03): 고정된 반응 공격은 없고, a의 특징이 b의 효과를, b의 특징이 a의 효과를 실어 나른다 (Share).
static var REACTIONS: Array = _build_pairs()


static func _build_pairs() -> Array:
	var out := []
	for p in PAIRS:
		var af := aff_of(p[1], p[2])
		var aff := "strong" if af["strong"] else "weak" if af["weak"] else ""
		out.append({"id": p[0], "a": p[1], "b": p[2], "name": pair_name(p[1], p[2]), "desc": pair_desc(p[1], p[2]), "color": p[3], "aff": aff, "aff_txt": aff_text(p[1], p[2])})
	return out


## 짝 이름: "화상 · 번개로 옮김"처럼 한쪽 효과 + 다른 쪽 특징 (실어 나를 효과가 없으면 두 특징 이름)
static func pair_name(a: int, b: int) -> String:
	# 2026-11-03: 꾸밈말("타오르는 메아리")은 뜻을 알기 어려워 "효과 · 특징" 그대로 잇는다 ("피해 되풀이 · 죽으면 불꽃")
	if b in CARRY:
		return "%s · %s" % [rider_name(b), trait_name(a)]
	if a in CARRY:
		return "%s · %s" % [rider_name(a), trait_name(b)]
	return "%s · %s" % [trait_name(a), trait_name(b)]


## 짝 설명: 두 방향을 모두 적는다.
static func pair_desc(a: int, b: int) -> String:
	var parts := PackedStringArray()
	for d in [[a, b], [b, a]]:
		if d[1] in CARRY:
			parts.append("%s(%s) → %s(%s)" % [rider_name(d[1]), NAMES[d[1]], trait_name(d[0]), NAMES[d[0]]])
	if parts.is_empty():
		return "%s(%s) · %s(%s) (특징끼리)" % [trait_name(a), NAMES[a], trait_name(b), NAMES[b]]
	return " · ".join(parts)


## 상성 설명 한 줄 ("상성 감전(강): 전기가 …", 보통이면 "")
static func aff_text(a: int, b: int) -> String:
	var af := aff_of(a, b)
	var parts := PackedStringArray()
	for i in af["ids"].size():
		parts.append("상성 %s(%s): %s" % [af["names"][i], "강" if _rule_strong(af["ids"][i]) else "약", af["descs"][i]])
	return " · ".join(parts)


## 속성 묶음에서 성립하는 특수 반응들.
static func reactions_with(elements: Dictionary) -> Array:
	var out := []
	for r in REACTIONS:
		if elements.has(r["a"]) and elements.has(r["b"]):
			out.append(r)
	return out


## 두 속성 a·b의 반응 (없으면 빈 사전).
static func reaction_of(a: int, b: int) -> Dictionary:
	for r in REACTIONS:
		if (r["a"] == a and r["b"] == b) or (r["a"] == b and r["b"] == a):
			return r
	return {}


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
