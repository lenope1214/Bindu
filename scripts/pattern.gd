class_name Pat
## 공격방식(형태)·강화(수식어)·연계 정의.
## 오브젝트 = 속성(효과, 종류 수는 규칙 버전 상한) + 공격방식 1개 + 강화(종류별 상한) + 연계. 상한은 rules.gd.
## 새 오브젝트는 직선탄으로 시작한다.

const DEFAULT := "shot"

## 공격방식. from: 이 형태를 가져온 원래 속성(아이콘 색 참고용)
const PATTERNS := {
	"shot": {"name": "직선탄", "desc": "정한 방향으로 탄을 쏴요.", "from": -1},
	"spray": {"name": "분사", "desc": "부채꼴로 계속 뿜어요. (지속 피해)", "from": Elem.FIRE},
	"thorn": {"name": "관통 연사", "desc": "작은 가시를 빠르게 쏴요. (관통)", "from": Elem.WOOD},
	"stream": {"name": "물줄기", "desc": "주기적으로 길게 뿜어 맞은 구체를 멈춰 세워요.", "from": Elem.WATER},
	"chain": {"name": "연쇄 번개", "desc": "앞쪽 구체를 치고 주변으로 튀어요.", "from": Elem.ELECTRIC},
	"gust": {"name": "돌풍", "desc": "넓은 바람이 지나가며 옆으로 밀어요.", "from": Elem.WIND},
	"shard": {"name": "파편탄", "desc": "맞으면 파편 3개로 갈라져요.", "from": Elem.ICE},
	"wall": {"name": "벽", "desc": "앞에 바위 벽을 세워 막아요. 무너질 때 둘레에 돌 파편이 나와요.", "from": Elem.EARTH},
	"vortex": {"name": "블랙홀", "desc": "구체가 가장 많이 모인 곳에 중력 우물을 떨어뜨려 가운데로 끌어모아요. 안에 든 구체가 다른 오브젝트에게 받은 피해 일부를 빨아들였다가 끝에 터지며 나눠 넣어요.", "from": Elem.DARK},
	"laser": {"name": "레이저", "desc": "충전 후 화면 끝까지 관통해요.", "from": Elem.LIGHT},
	"lob": {"name": "투척 장판", "desc": "느린 탄이 지나간 자리에 속성 장판이 남아요. 유도하면 휜 길 그대로 남아요.", "from": Elem.POISON},
	"iron": {"name": "철구", "desc": "느리고 무거운 관통탄을 쏴요.", "from": Elem.METAL},
	"sonic": {"name": "음파", "desc": "부채꼴로 퍼지는 파동이에요. 관통하고, 멀수록 약해져요.", "from": Elem.SOUND},
	"clock": {"name": "시계침", "desc": "앞쪽을 바늘이 왕복하며 훑어요.", "from": Elem.TIME},
	"wisp": {"name": "혼불", "desc": "오브젝트 곁을 떠돌며 가까이 온 구체를 쫓아 때리는 혼불 2개가 나와요.", "from": Elem.SOUL},
}

const PATTERN_IDS := ["shot", "spray", "thorn", "stream", "chain", "gust", "shard", "wall", "vortex", "laser", "lob", "iron", "sonic", "clock", "wisp"]

const ALL_IDS := PATTERN_IDS

## 날아가는 공격방식 (바람 형태 성질 "멀리"가 붙는다)
const FLYING := ["shot", "thorn", "gust", "shard", "iron", "wisp", "lob", "vortex"]

## 투사체를 쏘는 공격방식 (유도·튕김·관통 강화가 그대로 적용)
const PROJECTILE := ["shot", "thorn", "gust", "shard", "iron", "wisp"]

## "피해 +N%"의 공백은 줄바꿈하지 않는 공백(U+00A0): 카드에서 숫자만 다음 줄로 넘어가지 않게
const MODS := {
	"reflex": {"name": "자동 조준", "desc": "공격 방향을 고정하지 않고 사거리 안 가장 가까운 구체를 향해 공격해요. 최종 피해 -10%. 오브젝트마다 1번만 선택할 수 있어요. 혼불·블랙홀에는 못 넣어요."},
	"multi": {"name": "다중 발사", "desc": "공격이 1개 더 나가요. (하나하나는 피해 {multi_dmg%}%, 많이 쌓을수록 조금씩 줄어요.)"},
	"split": {"name": "분열", "desc": "맞은 구체에서 약한 파편 2개가 튀어요. (1개마다 확률 +{split_ch%}%, 최대 {split_max%}%) 벽·투척 장판에는 못 넣어요."},
	"homing": {"name": "유도", "desc": "탄이 구체 쪽으로 천천히 휘어요. (많이 휠수록 피해가 줄어 최저 {homing_fade_min%}%) 범위 공격은 구체 쪽으로 조금 돌아요. 한 구체는 탄 2개까지만 쫓고, 못 따라잡으면 다른 구체를 쫓아요. 벽·혼불·시계침·연쇄 번개에는 못 넣어요."},
	"bounce": {"name": "튕김", "desc": "탄이 가까운 구체로 튀어요. (튕긴 탄 피해 {bounce_hit%}%) 번개는 1번 더 튀어요. 그 밖의 공격은 맞힌 구체에서 작은 탄이 1개 더 튀어요. ({bounce_iv}초마다)"},
	"size": {"name": "크기", "desc": "탄 크기·범위·사거리 +{size_k%}% (공격방식 자기 공격 피해도 조금 오름, 탄은 +{size_dmg%}%)"},
	"rapid": {"name": "속사", "desc": "공격 속도 +{rapid_k%}%"},
	"pierce": {"name": "관통", "desc": "탄이 1개 더 뚫어요. (뚫을 때마다 피해 x{pierce_hit}) 그 밖의 공격은 피해 +{pierce_dmg%}%, 보호막을 {pierce_shield%}% 더 깎고 갑옷을 {pierce_armor%}% 무시해요."},
	"dice": {"name": "주사위", "desc": "공격할 때마다 주사위를 굴려요. 4~5는 피해 x{dice_mid}, 6은 x{dice_top} 대박이에요. (다음 공격까지) 1~3은 그대로예요. 더 넣으면 주사위가 늘어 높은 눈을 써요. (3개까지) 대박은 8번 안에 꼭 나와요. 반응 피해는 제외해요. (시험)"},
}

const MOD_IDS := ["multi", "split", "homing", "bounce", "size", "rapid", "pierce", "dice", "reflex"]


## 지금 카드로 나오는 강화 (자동 조준이 기본 기능이면 자동 조준 카드는 빠진다). 도감·업적 분모·카드 풀은 이것을 쓴다.
static func mod_ids() -> Array:
	if Rules.t("auto_aim") > 0.0:
		return MOD_IDS.filter(func(id): return id != "reflex")
	return MOD_IDS

## 넣어도 효과가 없는 강화 → 공격방식. 그 오브젝트에는 넣을 수 없고, 넣을 곳이 없으면 선택지에서도 빠진다.
## 이 강화가 든 오브젝트는 그 공격방식으로 바꿀 수도 없다.
## 새 공격방식을 넣을 때 여기에 같이 적는다.
const NO_MOD := {
	"reflex": ["wisp", "vortex"],  # 이미 전방위로 구체를 찾는 공격
	"pierce": ["thorn", "gust", "iron", "wisp"],  # 원래 모두 뚫는다 (혼불은 맞혀도 사라지지 않는다)
	"bounce": ["thorn", "gust", "iron", "wisp"],  # 뚫고 나가서 튕길 일이 없다
	"homing": ["wall", "wisp", "clock", "chain"],  # 벽은 정한 방향에만 세운다. 혼불은 원래 쫓아가서 유도를 못 넣는다 (2026-10-31 사용자). 시계침·연쇄 번개는 범위 공격이라 차이가 없다 (2026-11-01 측정, 사용자 승인)
	"split": ["wall", "lob"],  # 바닥에 남아 때리는 피해는 분열을 일으키지 않는다 (블랙홀은 끝에서 터질 때 분열)
}


## 강화 보정표 (2026-10-31, 사용자 선택 "목표 띠 + 보정표"): 같은 강화 5개일 때 이 피해 배율을 곱한다(개수에 비례해 배율^(개수/5)).
## 조합 효율 측정(tools/combo_eff.gd SET=pm STAGE=late, 규칙 1)에서 강화 효과가 1.65배를 넘는 칸은 1.6배로, 1.3배 미만인 칸은 1.35배로 맞춘 값.
## 2026-11-01: 탄 아닌 공격의 튕김(진짜 튕김 탄)·벽 다중·크기·돌풍 다중(나란히)을 바꾸며 그 칸을 다시 맞춤 (5개 1.4~1.5배)
## 강화 성격(다중·유도 등)은 그대로고 숫자만 맞춘다. Rules.t("mod_fix")가 세기(1 = 이 표, 0 = 끔)
const MOD_FIX := {
	"shot": {"multi": 0.79, "split": 1.19, "homing": 1.14, "bounce": 0.92, "size": 1.17, "pierce": 0.91},
	"spray": {"multi": 0.86, "split": 1.12, "bounce": 1.19, "size": 1.35, "pierce": 1.08},
	"thorn": {"multi": 0.79, "homing": 0.65},
	"stream": {"multi": 0.8, "size": 1.16, "pierce": 1.11},
	"chain": {"split": 1.2, "bounce": 1.08, "size": 1.3, "pierce": 1.1},
	"gust": {"split": 1.21, "homing": 0.82, "rapid": 1.38},
	"shard": {"multi": 0.49, "split": 1.29, "homing": 1.22, "size": 1.16, "pierce": 1.29},
	"wall": {"bounce": 1.22, "size": 0.95, "pierce": 1.1},
	"vortex": {"multi": 0.42, "split": 1.35, "pierce": 1.12},
	"laser": {"multi": 0.81, "split": 1.19, "bounce": 1.14, "size": 1.14, "pierce": 1.09},
	"lob": {"multi": 0.88, "homing": 0.94, "bounce": 1.18, "size": 1.08, "pierce": 1.08},
	"iron": {"multi": 0.93, "split": 1.13, "homing": 0.7, "size": 1.04},
	"sonic": {"multi": 0.97, "split": 1.15, "homing": 1.13, "bounce": 1.29, "size": 1.22, "pierce": 1.09},
	"clock": {"bounce": 1.24, "size": 1.24, "pierce": 1.1},
	"wisp": {"multi": 1.15},  # 2026-10-31 범위 제한 혼불: 늘어난 혼불은 구체가 적으면 놀아서 다중 발사를 조금 올린다 (봇 GOD 판 누수로 맞춤)
}


## 보정표를 이 개수를 넘는 몫에만 건다 (5개 값은 그대로). 관통 연사 유도는 적게 넣으면 거의 안 휘어서
## 개수에 비례해 깎으면 2개가 +1%였다 (2026-11-01 측정, 사용자 승인)
const MOD_FIX_FROM := {"thorn": {"homing": 2.0}}


## 이 공격방식에서 강화 n개(효과량)의 보정 배율
static func mod_fix(pat: String, mod: String, n: float) -> float:
	var t: Dictionary = MOD_FIX.get(pat, {})
	if not t.has(mod) or n <= 0.0:
		return 1.0
	var from: float = MOD_FIX_FROM.get(pat, {}).get(mod, 0.0)
	if n <= from:
		return 1.0
	return pow(t[mod], (n - from) / (5.0 - from) * Rules.t("mod_fix"))


static func mod_ok(pat: String, mod: String) -> bool:
	return not NO_MOD.get(mod, []).has(pat)


## 효과가 없는 이유 (효과가 있으면 빈 문자열).
static func no_mod_why(pat: String, mod: String) -> String:
	if mod_ok(pat, mod):
		return ""
	match mod:
		"pierce", "bounce":
			return "%s은(는) 원래 모두 뚫고 나가서 %s이(가) 효과가 없어요." % [pname(pat), MODS[mod]["name"]]
		"homing":
			if pat == "wisp":
				return "%s은(는) 원래 구체를 쫓아가서 유도를 넣을 수 없어요." % pname(pat)
			if pat in ["clock", "chain"]:
				return "%s은(는) 범위를 훑는 공격이라 유도가 효과가 없어요." % pname(pat)
			return "%s은(는) 정한 방향에만 세워져서 유도가 효과가 없어요." % pname(pat)
		"split":
			return "%s은(는) 바닥에 남아 때리는 공격이라 분열이 일어나지 않아요." % pname(pat)
	return "%s에는 %s이(가) 효과가 없어요." % [pname(pat), MODS[mod]["name"]]


## 이 공격방식에 넣을 수 없는 강화 이름들 (설명용).
static func no_mods(pat: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in mod_ids():
		if not mod_ok(pat, id):
			out.append(MODS[id]["name"])
	return out

const LINKS := {
	"pincer": {"name": "협공", "desc": "다른 오브젝트가 맞힌 구체를 {pincer_t}초 안에 이 오브젝트도 맞히면 터져서 그 구체 최대 체력의 10% 피해를 줘요."},
	"reso": {"name": "공명", "desc": "가까이(거리 {reso_r} 안) 있는 다른 오브젝트 하나당 피해 +{reso_k%}%"},
	"ensemble": {"name": "합주", "desc": "같은 속성을 하나라도 가진 다른 오브젝트 하나당 공격 속도 +6% (장마다 +6%, 8개까지 셈). 거리는 상관없어요. (시험)"},
}

const LINK_IDS := ["pincer", "reso", "ensemble"]  # 프리즘(속성 나눠 주기)은 2026-11-03 특징 공유로 삭제

## 발동: 기본 공격과 별개로, 조건이 맞을 때 추가로 터지는 공격 (Tower.trigs). 겹치면 세진다.
const TRIGS := {
	"echo": {"name": "처치 폭발", "desc": "이 오브젝트가 맞혀 구체를 잡으면 그 자리에서 작은 탄 {echo_n}개가 사방으로 나가요. ({echo_cd}초에 한 번)"},
	"vanguard": {"name": "앞줄 강타", "desc": "체력 {van_hp%}% 이상인 구체에 피해 x{van_mul} (장마다 +{van_add}, 보스는 절반). 마무리의 반대예요. 앞쪽에서 먼저 때리는 오브젝트에 넣으면 좋아요."},
	"charge": {"name": "모아 강타", "desc": "거리 {charge_r} 안에서 구체가 15마리 죽으면(누가 잡든, 특수 2·보스 8) 다음 공격이 x5 강타가 돼요. 웨이브가 넘어가도 유지돼요."},
	"third": {"name": "3타 강타", "desc": "3번째 공격마다 피해 x1.8 (탄은 크기도 x{third_size}). 계속 뿜는 공격은 1.5초마다 잠깐 강해져요."},
	"finish": {"name": "마무리", "desc": "체력이 {finish_hp%}% 아래인 구체에 피해 x{finish_mul} (보스는 절반). 다른 오브젝트가 깎은 구체에 강해요."},
	"answer": {"name": "따라 쏘기", "desc": "거리 {answer_r} 안 다른 오브젝트의 발동이 터지면 그쪽으로 한 발 더 쏴요. ({answer_cd}초에 한 번)"},
}

const TRIG_IDS := ["echo", "vanguard", "charge", "third", "finish", "answer"]
const TRIG_COLOR := Color(1.0, 0.55, 0.45)


## 긴 설명의 기본 카드용 주효과. 선택을 바꾸는 조건은 요약에서도 남긴다.
const BRIEF := {
	"pat": {
		"vortex": "구체가 모인 곳에 우물을 만들어 끌어모아요. 다른 오브젝트에게 받은 피해 일부를 모아 마지막에 터뜨려요.",
	},
	"mod": {
		"multi": "공격이 하나 더 나가요. 벽·블랙홀·투척 장판을 빼고 하나하나의 피해는 줄어요.",
		"split": "맞은 구체에서 확률로 약한 파편 2개가 튀어요. 벽·투척 장판에는 못 넣어요.",
		"homing": "공격이 구체 쪽으로 휘지만 많이 휠수록 약해져요. 벽·혼불·시계침·연쇄 번개에는 못 넣어요.",
		"bounce": "탄은 주변으로 튀고 번개는 한 번 더 튀어요. 다른 공격은 옆 구체에 작은 탄을 보내요.",
		"pierce": "탄이 하나 더 뚫지만 뚫을 때마다 약해져요. 다른 공격은 피해를 높이고 보호막·갑옷을 더 잘 뚫어요.",
		"dice": "공격마다 주사위를 굴려 높은 눈이면 피해가 커져요. 반응 피해에는 적용되지 않아요.",
	},
	"trig": {
		"echo": "이 오브젝트가 구체를 잡으면 그 자리에서 작은 탄이 사방으로 나가요.",
		"vanguard": "체력이 많이 남은 구체를 더 세게 때려요. 보스에게는 효과가 절반이에요.",
		"charge": "근처에서 구체가 쓰러지면 힘을 모아 다음 공격을 강하게 해요. 웨이브가 지나도 모은 힘은 남아요.",
		"third": "세 번째 공격마다 강해져요. 계속 뿜는 공격은 일정 시간마다 잠깐 강해져요.",
		"finish": "체력이 얼마 남지 않은 구체를 더 세게 때려요. 보스에게는 효과가 절반이에요.",
		"answer": "근처 다른 오브젝트가 발동·반응 공격을 하면 그쪽으로 한 발 더 쏴요.",
	},
}


static func brief(kind: String, id: String, fallback: String) -> String:
	return Rules.fmt(BRIEF.get(kind, {}).get(id, fallback))


## 강화·연계·발동 설명 (글 안의 {키}는 지금 수치, Rules.fmt)
static func mdesc(id: String) -> String:
	return Rules.fmt(MODS[id]["desc"])


static func ldesc(id: String) -> String:
	return Rules.fmt(LINKS[id]["desc"])


static func tdesc(id: String) -> String:
	return Rules.fmt(TRIGS[id]["desc"])


static func pname(id: String) -> String:
	return PATTERNS[id]["name"]


static func pcolor(id: String) -> Color:
	var f: int = PATTERNS[id]["from"]
	return Color(0.85, 0.85, 0.9) if f < 0 else Elem.COLORS[f]
