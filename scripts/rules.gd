class_name Rules
## 규칙 버전: 시작 화면에서 골라 같은 게임을 다른 규칙으로 비교해 본다.
## 1 기준(상한), 2 분산형, 3 자유 쌓기 + 대가, 4 빠른 템포.

const IDS := [1, 2, 3, 4]
const NAMES := {1: "버전 1 · 기준", 2: "버전 2 · 분산형", 3: "버전 3 · 자유 쌓기", 4: "버전 4 · 빠른 템포"}
const DESCS := {
	1: "속성 3종 · 강화 종류별 5개 · 11웨이브부터 체력 +5%씩",
	2: "속성 2종 · 강화 종류별 3개 · 무리 +6% · 연결 거리 420",
	3: "상한 없음 · 속성 종류마다 공격 속도 -25% · 같은 강화는 쌓을수록 효과 절반씩",
	4: "쉬는 시간마다 2장 · 체력 +8%씩 · 특수 구체 8웨이브부터 · 구체 1.4배",
}
const NO_CAP := 99

static var version := 1
static var max_elems := 3  # 한 오브젝트에 넣을 수 있는 속성 종류 (레벨은 무제한)
static var max_mod := 5  # 강화 종류마다 쌓을 수 있는 수
static var crowd := 0.03  # 오브젝트 하나당 전체 피해 보너스
static var link_range := 320.0
static var orb_mul := 1.0  # 웨이브 구체 수 배율
static var tax_step := 0.15  # 속성 종류 하나당 공격 속도 감소
static var mod_decay := false  # 같은 강화를 쌓을수록 효과가 절반씩 (1, 1.5, 1.75, ...)
static var picks := 1  # 3웨이브부터 쉬는 시간마다 고르는 수
static var hp_growth := 1.05  # 11웨이브부터 웨이브마다 구체 체력 배율
static var resist_from := 12  # 저항 구체가 나오는 웨이브
static var sturdy_from := 15  # 굳센 구체가 나오는 웨이브


static func apply(v: int) -> void:
	version = v if v in IDS else 1
	max_elems = 3
	max_mod = 5
	crowd = 0.03
	link_range = 320.0
	orb_mul = 1.0
	tax_step = 0.15
	mod_decay = false
	picks = 1
	hp_growth = 1.05
	resist_from = 12
	sturdy_from = 15
	match version:
		2:
			max_elems = 2
			max_mod = 3
			crowd = 0.06
			link_range = 420.0
		3:
			max_elems = NO_CAP
			max_mod = NO_CAP
			tax_step = 0.25
			mod_decay = true
		4:
			picks = 2
			orb_mul = 1.4  # 2장씩 고르는 만큼 구체를 늘려 버전 1과 비슷한 난이도로 (봇 평균 10.2 → 6.2, 버전 1은 6.9)
			hp_growth = 1.08
			resist_from = 8
			sturdy_from = 11
