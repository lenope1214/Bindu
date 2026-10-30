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
	"lob": {"name": "투척 장판", "desc": "던진 자리에 속성 장판을 남긴다", "from": Elem.POISON},
	"iron": {"name": "철구", "desc": "느리고 무거운 관통탄", "from": Elem.METAL},
	"sonic": {"name": "음파", "desc": "부채꼴로 퍼지는 파동 (관통, 멀수록 약함)", "from": Elem.SOUND},
	"clock": {"name": "시계침", "desc": "앞쪽을 바늘이 왕복하며 훑는다", "from": Elem.TIME},
	"wisp": {"name": "혼불", "desc": "구체를 쫓아가는 혼불을 띄운다", "from": Elem.SOUL},
}

const PATTERN_IDS := ["shot", "spray", "thorn", "stream", "chain", "gust", "shard", "wall", "vortex", "laser", "lob", "iron", "sonic", "clock", "wisp"]

## 날아가는 공격방식 (바람 형태 성질 "멀리"가 붙는다)
const FLYING := ["shot", "thorn", "gust", "shard", "iron", "wisp", "lob", "vortex"]

## 투사체를 쏘는 공격방식 (유도·튕김·관통 강화가 그대로 적용)
const PROJECTILE := ["shot", "thorn", "gust", "shard", "iron", "wisp"]

## "피해 +N%"의 공백은 줄바꿈하지 않는 공백(U+00A0): 카드에서 숫자만 다음 줄로 넘어가지 않게
const MODS := {
	"multi": {"name": "다중 발사", "desc": "공격이 1개 더 나간다 (하나하나는 피해 55%, 많이 쌓을수록 조금씩 줄어듦)"},
	"split": {"name": "분열", "desc": "맞은 구체에서 약한 파편 2개가 튄다 (1개마다 확률 +12%, 최대 60%)"},
	"homing": {"name": "유도", "desc": "탄이 구체 쪽으로 천천히 휜다. 범위 공격은 구체 쪽으로 조금 돈다"},
	"bounce": {"name": "튕김", "desc": "탄이 가까운 구체로 튄다(튕긴 탄 피해 40%). 번개는 1번 더 튄다. 그 밖의 공격은 피해 +4%"},
	"size": {"name": "크기", "desc": "탄 크기·범위·사거리 +12% (탄을 쏘는 공격은 피해도 +4%)"},
	"rapid": {"name": "속사", "desc": "공격 속도 +10%"},
	"pierce": {"name": "관통", "desc": "탄이 1개 더 뚫는다(뚫을 때마다 피해 절반). 그 밖의 공격은 피해 +6%"},
}

const MOD_IDS := ["multi", "split", "homing", "bounce", "size", "rapid", "pierce"]

const LINKS := {
	"pincer": {"name": "협공", "desc": "다른 오브젝트가 맞힌 구체를 3초 안에 이 오브젝트도 맞히면 터져서 그 구체 최대 체력의 10% 피해"},
	"prism": {"name": "프리즘", "desc": "다른 오브젝트의 탄이 지나가면 이 속성이 묻고 피해 +20%"},
	"reso": {"name": "공명", "desc": "가까이(거리 150 안) 있는 다른 오브젝트 하나당 피해 +12%"},
}

const LINK_IDS := ["pincer", "prism", "reso"]


static func pname(id: String) -> String:
	return PATTERNS[id]["name"]


static func pcolor(id: String) -> Color:
	var f: int = PATTERNS[id]["from"]
	return Color(0.85, 0.85, 0.9) if f < 0 else Elem.COLORS[f]
