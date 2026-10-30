class_name Rules
## 규칙 버전: 시작 화면에서 골라 같은 게임을 다른 규칙으로 비교해 본다.
## 2026-10-30 결정: 1 기준(상한)과 3 자유 쌓기(상한 없음 + 대가) 두 개만 고른다.
## 버전 1은 2(분산: 연결 거리·무리)와 4(카드 2장·이른 특수 구체)의 좋은 점을 넣어 고쳤고, 3도 같은 공통 항목을 쓴다.
## 2·4·5는 예전 기록·비교용으로 코드만 남긴다 (시작 화면에서 고를 수 없음, 이어하기는 버전 1로).

const IDS := [1, 3]  # 시작 화면에서 고르는 버전
const ALL_IDS := [1, 2, 3, 4, 5]  # apply가 아는 버전 (봇 비교용)
const OLD_IDS := [1, 2, 3, 4, 5]  # 2026-10-30 이전 규칙의 최고 기록 (기록 화면에 "이전 규칙"으로)
const REC_TAG := "r2"  # 고친 버전 1·3은 최고 기록을 새로 시작한다 (예전 기록은 그대로 보관)
const NAMES := {1: "버전 1 · 기준", 2: "버전 2 · 분산형", 3: "버전 3 · 자유 쌓기", 4: "버전 4 · 빠른 템포", 5: "버전 5 · 조합형"}
const DESCS := {
	1: "속성 3종 · 강화 종류별 5개 · 쉬는 시간마다 2장 · 무리 +4% · 연결 420 · 저항 10·굳셈 13웨이브부터",
	2: "속성 2종 · 강화 종류별 3개 · 무리 +6% · 연결 거리 420",
	3: "상한 없음 · 속성 종류마다 공격 속도 -25% · 같은 강화는 쌓을수록 효과 절반씩 · 그 밖은 버전 1과 같음",
	4: "쉬는 시간마다 2장 · 체력 +8%씩 · 특수 구체 8웨이브부터 · 구체 1.4배",
	5: "버전 1 + 강화 칸: 속성마다 칸 1~3, 2종 섞으면 x1.5 · 3종 x2 · 강화는 무게만큼 칸을 씀",
}
const NO_CAP := 99

static var version := 1
static var max_elems := 3  # 한 오브젝트에 넣을 수 있는 속성 종류 (레벨은 무제한)
static var max_mod := 5  # 강화 종류마다 쌓을 수 있는 수
static var crowd := 0.04  # 오브젝트 하나당 전체 피해 보너스
static var link_range := 420.0
static var orb_mul := 1.0  # 웨이브 구체 수 배율
static var tax_step := 0.15  # 속성 종류 하나당 공격 속도 감소
static var mod_decay := false  # 같은 강화를 쌓을수록 효과가 절반씩 (1, 1.5, 1.75, ...)
static var picks := 2  # 쉬는 시간마다 고르는 수
static var hp_growth := 1.05  # 11웨이브부터 웨이브마다 구체 체력 배율
static var resist_from := 10  # 저항 구체가 나오는 웨이브
static var sturdy_from := 13  # 굳센 구체가 나오는 웨이브
static var orb_hp := 1.0  # 구체 체력 배율 (온라인 패치로만 바뀜)
static var mod_slots := false  # 강화 칸: 속성이 정하는 칸 안에서만 강화를 넣는다 (버전 5)

## 강화 칸 (버전 5). 속성 칸: 혼자 내는 피해가 큰 속성일수록 작다 (2026-10-30 측정, 직선탄 Lv2 피해/초).
const ELEM_SLOTS := {
	Elem.POISON: 1, Elem.FIRE: 1, Elem.WOOD: 1,
	Elem.ELECTRIC: 2, Elem.LIGHT: 2, Elem.METAL: 2, Elem.DARK: 2,
	Elem.WATER: 3, Elem.WIND: 3, Elem.ICE: 3, Elem.EARTH: 3,
}
## 섞은 속성 종류 수에 따른 칸 배율
const SLOT_MUL := [1.0, 1.0, 1.5, 2.0]
## 강화 무게: 효과가 클수록 칸을 많이 쓴다
const MOD_WEIGHT := {"homing": 1, "size": 1, "rapid": 1, "pierce": 2, "bounce": 2, "split": 2, "multi": 3}
const LINK_SLOT := 0.5  # 연결선으로 나눠 받은 속성은 칸 절반


static func apply(v: int) -> void:
	version = v if v in ALL_IDS else 1
	max_elems = 3
	max_mod = 5
	crowd = 0.04
	link_range = 420.0
	orb_mul = 1.0
	tax_step = 0.15
	mod_decay = false
	picks = 2
	hp_growth = 1.05
	resist_from = 10
	sturdy_from = 13
	mod_slots = false
	orb_hp = 1.0
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
		5:
			mod_slots = true
	_apply_patch(Patch.rules_for(version))


## 온라인 패치(Patch)의 rules 덮어쓰기. 모르는 키·형식이 틀린 값은 무시.
static func _apply_patch(p: Dictionary) -> void:
	for k in p:
		var v: Variant = p[k]
		if k == "mod_decay":
			if v is bool:
				mod_decay = v
			continue
		if not (v is float or v is int):
			continue
		match k:
			"max_elems": max_elems = maxi(1, int(v))
			"max_mod": max_mod = maxi(1, int(v))
			"picks": picks = maxi(1, int(v))
			"resist_from": resist_from = int(v)
			"sturdy_from": sturdy_from = int(v)
			"crowd": crowd = float(v)
			"link_range": link_range = float(v)
			"orb_mul": orb_mul = maxf(0.1, float(v))
			"tax_step": tax_step = float(v)
			"hp_growth": hp_growth = maxf(1.0, float(v))
			"orb_hp": orb_hp = maxf(0.1, float(v))
