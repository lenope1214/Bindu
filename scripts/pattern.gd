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
	"wisp": {"name": "혼불", "desc": "구체를 쫓아가는 혼불을 띄운다", "from": Elem.SOUL},
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
	"multi": {"name": "다중 발사", "desc": "공격이 1개 더 나간다 (하나하나는 피해 55%, 많이 쌓을수록 조금씩 줄어듦)"},
	"split": {"name": "분열", "desc": "맞은 구체에서 약한 파편 2개가 튄다 (1개마다 확률 +12%, 최대 60%). 벽·투척 장판에는 못 넣음"},
	"homing": {"name": "유도", "desc": "탄이 구체 쪽으로 천천히 휜다. 범위 공격은 구체 쪽으로 조금 돈다. 한 구체는 탄 2개까지만 쫓고, 못 따라잡으면 다른 구체로. 혼불은 찾는 범위 +30%. 벽·그린 궤적에는 못 넣음"},
	"bounce": {"name": "튕김", "desc": "탄이 가까운 구체로 튄다(튕긴 탄 피해 40%). 번개는 1번 더 튄다. 그 밖의 공격은 피해 +4%"},
	"size": {"name": "크기", "desc": "탄 크기·범위·사거리 +12% (탄을 쏘는 공격은 피해도 +4%)"},
	"rapid": {"name": "속사", "desc": "공격 속도 +10%"},
	"pierce": {"name": "관통", "desc": "탄이 1개 더 뚫는다(뚫을 때마다 피해 절반). 그 밖의 공격은 피해 +6%"},
}

const MOD_IDS := ["multi", "split", "homing", "bounce", "size", "rapid", "pierce"]

## 넣어도 효과가 없는 강화 → 공격방식. 그 오브젝트에는 넣을 수 없고, 넣을 곳이 없으면 선택지에서도 빠진다.
## 이 강화가 든 오브젝트는 그 공격방식으로 바꿀 수도 없다.
## 새 공격방식을 넣을 때 여기에 같이 적는다 (그린 길을 따라가는 공격방식은 homing).
const NO_MOD := {
	"pierce": ["thorn", "gust", "iron"],  # 원래 모두 뚫는다
	"bounce": ["thorn", "gust", "iron"],  # 뚫고 나가서 튕길 일이 없다
	"homing": ["wall", "path"],  # 벽은 정한 방향에만 세우고, 그린 궤적은 그린 길만 따라간다
	"split": ["wall", "lob"],  # 바닥에 남아 때리는 피해는 분열을 일으키지 않는다 (블랙홀은 끝에서 터질 때 분열)
}


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
	"pincer": {"name": "협공", "desc": "다른 오브젝트가 맞힌 구체를 3초 안에 이 오브젝트도 맞히면 터져서 그 구체 최대 체력의 10% 피해"},
	"prism": {"name": "프리즘", "desc": "다른 오브젝트의 탄이 지나가면 이 속성이 묻고 피해 +20%"},
	"reso": {"name": "공명", "desc": "가까이(거리 150 안) 있는 다른 오브젝트 하나당 피해 +12%"},
}

const LINK_IDS := ["pincer", "prism", "reso"]


static func pname(id: String) -> String:
	return PATTERNS[id]["name"]


static func pcolor(id: String) -> Color:
	if id == "path":
		return Color(1.0, 0.85, 0.4)
	var f: int = PATTERNS[id]["from"]
	return Color(0.85, 0.85, 0.9) if f < 0 else Elem.COLORS[f]
