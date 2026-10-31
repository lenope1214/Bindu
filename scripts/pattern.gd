class_name Pat
## 공격방식(형태)·강화(수식어)·연계 정의.
## 오브젝트 = 속성(효과, 종류 수는 규칙 버전 상한) + 공격방식 1개 + 강화(종류별 상한) + 연계. 상한은 rules.gd.
## 새 오브젝트는 직선탄으로 시작한다.

const DEFAULT := "shot"

## 공격방식. from: 이 형태를 가져온 원래 속성(아이콘 색 참고용)
const PATTERNS := {
	"shot": {"name": "직선탄", "desc": "정한 방향으로 탄을 쏜다", "from": -1},
	"spray": {"name": "분사", "desc": "부채꼴로 계속 뿜는다 (지속 피해)", "from": Elem.FIRE},
	"thorn": {"name": "관통 연사", "desc": "작은 가시를 빠르게 쏜다 (관통)", "from": Elem.WOOD},
	"stream": {"name": "물줄기", "desc": "주기적으로 길게 뿜어 맞은 구체를 멈춰 세운다", "from": Elem.WATER},
	"chain": {"name": "연쇄 번개", "desc": "앞쪽 구체를 치고 주변으로 튄다", "from": Elem.ELECTRIC},
	"gust": {"name": "돌풍", "desc": "넓은 바람이 지나가며 옆으로 민다", "from": Elem.WIND},
	"shard": {"name": "파편탄", "desc": "맞으면 파편 3개로 갈라진다", "from": Elem.ICE},
	"wall": {"name": "벽", "desc": "앞에 바위 벽을 세워 막는다", "from": Elem.EARTH},
	"vortex": {"name": "블랙홀", "desc": "앞으로 날아가며 양옆 구체를 길 위로 끌어모은다. 점점 작아지며 세지다 끝에서 터진다. 구체를 먹을수록 빨리 작아지고 세게 터진다", "from": Elem.DARK},
	"laser": {"name": "레이저", "desc": "충전 후 화면 끝까지 관통", "from": Elem.LIGHT},
	"lob": {"name": "투척 장판", "desc": "느린 탄이 지나간 자리에 속성 장판이 남는다 (유도하면 휜 길 그대로)", "from": Elem.POISON},
	"iron": {"name": "철구", "desc": "느리고 무거운 관통탄", "from": Elem.METAL},
	"sonic": {"name": "음파", "desc": "부채꼴로 퍼지는 파동 (관통, 멀수록 약함)", "from": Elem.SOUND},
	"clock": {"name": "시계침", "desc": "앞쪽을 바늘이 왕복하며 훑는다", "from": Elem.TIME},
	"wisp": {"name": "혼불", "desc": "오브젝트 곁을 떠돌며 가까이 온 구체를 쫓아 때리는 혼불 2개", "from": Elem.SOUL},
	"path": {"name": "그린 궤적", "desc": "직접 그린 길을 따라 탄이 날아간다. 레벨마다 길이 400→500→600, 그 뒤 갈래 최대 3개 (희귀, 시험)", "from": -1},
}

const PATTERN_IDS := ["shot", "spray", "thorn", "stream", "chain", "gust", "shard", "wall", "vortex", "laser", "lob", "iron", "sonic", "clock", "wisp"]

## 희귀 공격방식: 보통 공격방식 카드·대격변·튜토리얼에는 나오지 않고 따로 뽑힌다 (main._roll_card)
const RARE_IDS := ["path"]
const ALL_IDS := PATTERN_IDS + RARE_IDS

## 그린 궤적 (2026-10-30 기획안): 카드당 0.7%, 이 판에 궤적이 있으면 1.2%. 오브젝트 4개까지.
## 레벨 1~3은 그릴 수 있는 길이, 4·5는 갈래 하나씩, 그 뒤로는 피해만 오른다.
const PATH_CHANCE := 0.007
const PATH_CHANCE_AGAIN := 0.012
const PATH_MAX := 4
const PATH_LEN := [400.0, 500.0, 600.0]
const PATH_BRANCH_MAX := 3
const PATH_BENDS := 3  # 갈래마다 꺾을 수 있는 수 (45도 넘게 방향이 바뀌면 한 번)
const PATH_BEND_ANGLE := PI / 4.0


static func path_len(l: int) -> float:
	return PATH_LEN[clampi(l, 1, PATH_LEN.size()) - 1]


static func path_branches(l: int) -> int:
	return clampi(l - PATH_LEN.size() + 1, 1, PATH_BRANCH_MAX)

## 날아가는 공격방식 (바람 형태 성질 "멀리"가 붙는다)
const FLYING := ["shot", "thorn", "gust", "shard", "iron", "wisp", "lob", "vortex"]

## 투사체를 쏘는 공격방식 (유도·튕김·관통 강화가 그대로 적용)
const PROJECTILE := ["shot", "thorn", "gust", "shard", "iron", "wisp", "path"]

## "피해 +N%"의 공백은 줄바꿈하지 않는 공백(U+00A0): 카드에서 숫자만 다음 줄로 넘어가지 않게
const MODS := {
	"multi": {"name": "다중 발사", "desc": "공격이 1개 더 나간다 (하나하나는 피해 {multi_dmg%}%, 많이 쌓을수록 조금씩 줄어듦)"},
	"split": {"name": "분열", "desc": "맞은 구체에서 약한 파편 2개가 튄다 (1개마다 확률 +{split_ch%}%, 최대 {split_max%}%). 벽·투척 장판에는 못 넣음"},
	"homing": {"name": "유도", "desc": "탄이 구체 쪽으로 천천히 휜다. 범위 공격은 구체 쪽으로 조금 돈다. 한 구체는 탄 2개까지만 쫓고, 못 따라잡으면 다른 구체로. 혼불은 목줄 +15%. 벽·그린 궤적에는 못 넣음"},
	"bounce": {"name": "튕김", "desc": "탄이 가까운 구체로 튄다(튕긴 탄 피해 {bounce_hit%}%). 번개는 1번 더 튄다. 그 밖의 공격은 피해 +{bounce_dmg%}%"},
	"size": {"name": "크기", "desc": "탄 크기·범위·사거리 +{size_k%}% (탄을 쏘는 공격은 피해도 +{size_dmg%}%)"},
	"rapid": {"name": "속사", "desc": "공격 속도 +{rapid_k%}%"},
	"pierce": {"name": "관통", "desc": "탄이 1개 더 뚫는다(뚫을 때마다 피해 x{pierce_hit}). 그 밖의 공격은 피해 +{pierce_dmg%}%"},
	"dice": {"name": "주사위", "desc": "공격할 때마다 주사위: 4~5는 피해 x{dice_mid}, 6은 x{dice_top} 대박 (다음 공격까지). 1~3은 그대로. 더 넣으면 주사위가 늘어 높은 눈을 쓴다(3개까지). 대박은 8번 안에 꼭. 반응 피해 제외 (시험)"},
}

const MOD_IDS := ["multi", "split", "homing", "bounce", "size", "rapid", "pierce", "dice"]

## 넣어도 효과가 없는 강화 → 공격방식. 그 오브젝트에는 넣을 수 없고, 넣을 곳이 없으면 선택지에서도 빠진다.
## 이 강화가 든 오브젝트는 그 공격방식으로 바꿀 수도 없다.
## 새 공격방식을 넣을 때 여기에 같이 적는다 (그린 길을 따라가는 공격방식은 homing).
const NO_MOD := {
	"pierce": ["thorn", "gust", "iron", "wisp"],  # 원래 모두 뚫는다 (혼불은 맞혀도 사라지지 않는다)
	"bounce": ["thorn", "gust", "iron", "wisp"],  # 뚫고 나가서 튕길 일이 없다
	"homing": ["wall", "path", "wisp"],  # 벽은 정한 방향에만 세우고, 그린 궤적은 그린 길만 따라간다. 혼불은 원래 쫓아가서 유도를 못 넣는다 (2026-10-31 사용자)
	"split": ["wall", "lob"],  # 바닥에 남아 때리는 피해는 분열을 일으키지 않는다 (블랙홀은 끝에서 터질 때 분열)
}


## 강화 보정표 (2026-10-31, 사용자 선택 "목표 띠 + 보정표"): 같은 강화 5개일 때 이 피해 배율을 곱한다(개수에 비례해 배율^(개수/5)).
## 조합 효율 측정(tools/combo_eff.gd SET=pm STAGE=late, 규칙 1)에서 강화 효과가 1.65배를 넘는 칸은 1.6배로, 1.3배 미만인 칸은 1.35배로 맞춘 값.
## 강화 성격(다중·유도 등)은 그대로고 숫자만 맞춘다. Rules.t("mod_fix")가 세기(1 = 이 표, 0 = 끔)
const MOD_FIX := {
	"shot": {"multi": 0.79, "split": 1.19, "homing": 1.14, "bounce": 0.92, "size": 1.17, "pierce": 0.91},
	"spray": {"multi": 0.86, "split": 1.12, "bounce": 1.16, "size": 1.35, "pierce": 1.08},
	"thorn": {"multi": 0.79, "homing": 0.65},
	"stream": {"multi": 0.8, "bounce": 1.18, "size": 1.16, "pierce": 1.11},
	"chain": {"split": 1.2, "homing": 1.36, "bounce": 1.08, "size": 1.3, "pierce": 1.1},
	"gust": {"multi": 1.09, "split": 1.21, "homing": 0.82, "rapid": 1.38},
	"shard": {"multi": 0.49, "split": 1.29, "homing": 1.22, "size": 1.16, "pierce": 1.29},
	"wall": {"bounce": 1.17, "pierce": 1.1},
	"vortex": {"multi": 0.42, "split": 1.35, "bounce": 1.19, "pierce": 1.12},
	"laser": {"multi": 0.81, "split": 1.19, "bounce": 1.16, "size": 1.14, "pierce": 1.09},
	"lob": {"multi": 0.88, "homing": 0.94, "bounce": 1.16, "size": 1.08, "rapid": 1.35, "pierce": 1.08},
	"iron": {"multi": 0.93, "split": 1.13, "homing": 0.7, "size": 1.04},
	"sonic": {"multi": 0.97, "split": 1.15, "homing": 1.13, "bounce": 1.16, "size": 1.22, "pierce": 1.09},
	"clock": {"homing": 1.36, "bounce": 1.17, "size": 1.24, "pierce": 1.1},
	"wisp": {"multi": 1.15},  # 2026-10-31 목줄 혼불: 늘어난 혼불은 구체가 적으면 놀아서 다중 발사를 조금 올린다 (봇 GOD 판 누수로 맞춤)
}


## 이 공격방식에서 강화 n개(효과량)의 보정 배율
static func mod_fix(pat: String, mod: String, n: float) -> float:
	var t: Dictionary = MOD_FIX.get(pat, {})
	if not t.has(mod) or n <= 0.0:
		return 1.0
	return pow(t[mod], n / 5.0 * Rules.t("mod_fix"))


static func mod_ok(pat: String, mod: String) -> bool:
	return not NO_MOD.get(mod, []).has(pat)


## 효과가 없는 이유 (효과가 있으면 빈 문자열).
static func no_mod_why(pat: String, mod: String) -> String:
	if mod_ok(pat, mod):
		return ""
	match mod:
		"pierce", "bounce":
			return "%s은(는) 원래 모두 뚫고 나가서 %s이(가) 효과가 없어요" % [pname(pat), MODS[mod]["name"]]
		"homing":
			if pat == "path":
				return "%s은(는) 그린 길만 따라가서 유도가 효과가 없어요" % pname(pat)
			if pat == "wisp":
				return "%s은(는) 원래 구체를 쫓아가서 유도를 넣을 수 없어요" % pname(pat)
			return "%s은(는) 정한 방향에만 세워져서 유도가 효과가 없어요" % pname(pat)
		"split":
			return "%s은(는) 바닥에 남아 때리는 공격이라 분열이 일어나지 않아요" % pname(pat)
	return "%s에는 %s이(가) 효과가 없어요" % [pname(pat), MODS[mod]["name"]]


## 이 공격방식에 넣을 수 없는 강화 이름들 (설명용).
static func no_mods(pat: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in MOD_IDS:
		if not mod_ok(pat, id):
			out.append(MODS[id]["name"])
	return out

const LINKS := {
	"pincer": {"name": "협공", "desc": "다른 오브젝트가 맞힌 구체를 {pincer_t}초 안에 이 오브젝트도 맞히면 터져서 그 구체 최대 체력의 10% 피해"},
	"prism": {"name": "프리즘", "desc": "다른 오브젝트의 탄이 지나가면 이 속성이 묻고 피해 +{prism_dmg%}%"},
	"reso": {"name": "공명", "desc": "가까이(거리 {reso_r} 안) 있는 다른 오브젝트 하나당 피해 +{reso_k%}%"},
}

const LINK_IDS := ["pincer", "prism", "reso"]

## 발동: 기본 공격과 별개로, 조건이 맞을 때 추가로 터지는 공격 (Tower.trigs). 겹치면 세진다.
const TRIGS := {
	"echo": {"name": "여진", "desc": "이 오브젝트가 맞혀 구체를 잡으면 그 자리에서 작은 탄 {echo_n}개가 사방으로 ({echo_cd}초에 한 번)"},
	"vanguard": {"name": "선봉", "desc": "웨이브마다 처음 구체를 맞힌 순간부터 {van_t}초 동안 공격 속도 x{van_spd}"},
	"charge": {"name": "축적", "desc": "거리 {charge_r} 안에서 구체가 15마리 죽으면(누가 잡든, 특수 2·보스 8) 다음 공격이 x5 강타. 웨이브가 넘어가도 유지"},
	"third": {"name": "삼연", "desc": "3번째 공격마다 피해 x1.8 (탄은 크기도 x{third_size}). 계속 뿜는 공격은 1.5초마다 잠깐"},
	"finish": {"name": "마무리", "desc": "체력이 {finish_hp%}% 아래인 구체에 피해 x{finish_mul} (보스는 절반). 다른 오브젝트가 깎은 구체에 강해요"},
	"answer": {"name": "호응", "desc": "거리 {answer_r} 안 다른 오브젝트의 발동·특수 반응이 터지면 그쪽으로 한 발 더 ({answer_cd}초에 한 번)"},
}

const TRIG_IDS := ["echo", "vanguard", "charge", "third", "finish", "answer"]
const TRIG_COLOR := Color(1.0, 0.55, 0.45)


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
	if id == "path":
		return Color(1.0, 0.85, 0.4)
	var f: int = PATTERNS[id]["from"]
	return Color(0.85, 0.85, 0.9) if f < 0 else Elem.COLORS[f]
