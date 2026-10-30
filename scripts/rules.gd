class_name Rules
## 규칙 버전: 시작 화면에서 골라 같은 게임을 다른 규칙으로 비교해 본다.
## 2026-10-30 결정: 1 기준(상한)과 3 자유 쌓기(상한 없음 + 대가) 두 개만 고른다.
## 버전 1은 2(분산: 연결 거리·무리)와 4(카드 2장·이른 특수 구체)의 좋은 점을 넣어 고쳤고, 3도 같은 공통 항목을 쓴다.
## 2·4는 예전 기록·비교용으로 코드만 남긴다 (시작 화면에서 고를 수 없음, 이어하기는 버전 1로).
## 5(조합형, 강화 칸)는 2026-10-30 "너무 어렵다"는 반응으로 폐기하고 코드를 지웠다: docs/rule-history.md

const IDS := [1, 3]  # 시작 화면에서 고르는 버전
const TRIAL_IDS := []  # 새로 낸 버전은 사람 시험판·통계를 볼 때까지 여기 넣어 시작 화면에 "(시험)" (docs/rule-history.md)
const ALL_IDS := [1, 2, 3, 4]  # apply가 아는 버전 (봇 비교용)
const OLD_IDS := [1, 2, 3, 4, 5]  # 2026-10-30 이전 규칙의 최고 기록 (기록 화면에 "이전 규칙"으로). 이 버전으로 저장된 이어하기는 버전 1로
const REC_TAG := "r2"  # 고친 버전 1·3은 최고 기록을 새로 시작한다 (예전 기록은 그대로 보관)
const NAMES := {1: "버전 1 · 기준", 2: "버전 2 · 분산형", 3: "버전 3 · 자유 쌓기", 4: "버전 4 · 빠른 템포", 5: "버전 5 · 조합형 (폐기)"}
const DESCS := {
	1: "오브젝트마다 속성 3종 · 같은 강화 5개까지 · 쉬는 시간마다 카드 2장 · 오브젝트 수 보너스(5개 +16% · 10개 +23%, 늘수록 덜 오름) · 저항 구체 10웨이브, 굳센 구체 13웨이브부터",
	2: "오브젝트마다 속성 2종 · 같은 강화 3개까지 · 오브젝트 1개당 모든 피해 +6%",
	3: "상한 없음 · 속성 종류마다 공격 속도 -25% · 같은 강화는 쌓을수록 효과 절반씩 · 그 밖은 버전 1과 같음",
	4: "쉬는 시간마다 카드 2장 · 11웨이브부터 구체 체력 웨이브마다 +8% · 특수 구체 8웨이브부터 · 구체 수 1.4배",
	5: "폐기 (2026-10-30, 너무 어려움). 예전 기록만 남음",
}
const NO_CAP := 99

static var version := 1
static var max_elems := 3  # 한 오브젝트에 넣을 수 있는 속성 종류 (레벨은 무제한)
static var max_mod := 5  # 강화 종류마다 쌓을 수 있는 수
static var crowd := 0.10  # 오브젝트 수 보너스 계수: 모든 피해 x(1 + crowd x ln(오브젝트 수)), crowd_bonus 참고
static var pincer_frac := 0.10  # 협공 표식 폭발: 구체 최대 체력 대비
static var orb_mul := 1.0  # 웨이브 구체 수 배율
static var tax_step := 0.15  # 속성 종류 하나당 공격 속도 감소
static var mod_decay := false  # 같은 강화를 쌓을수록 효과가 절반씩 (1, 1.5, 1.75, ...)
static var picks := 2  # 쉬는 시간마다 고르는 수
static var hp_growth := 1.05  # 11웨이브부터 웨이브마다 구체 체력 배율
static var resist_from := 10  # 저항 구체가 나오는 웨이브
static var sturdy_from := 13  # 굳센 구체가 나오는 웨이브
static var orb_hp := 1.0  # 구체 체력 배율 (온라인 패치로만 바뀜)
static var trait_mul := 1.0  # 속성 형태 성질 세기 (Elem.TRAIT)


## 오브젝트 수 보너스(모든 오브젝트 피해에 더하는 몫). 2026-10-30 직선(하나당 +4%, 10개 +36%)이 후반에 과해
## 늘수록 덜 오르는 로그 곡선으로: 2개 +7% · 5개 +16% · 10개 +23% · 16개 +28% (crowd 0.10)
static func crowd_bonus(n: int) -> float:
	return crowd * log(float(maxi(n, 1)))


static func apply(v: int) -> void:
	version = v if v in ALL_IDS else 1
	max_elems = 3
	max_mod = 5
	crowd = 0.10
	pincer_frac = 0.10
	orb_mul = 1.0
	tax_step = 0.15
	mod_decay = false
	picks = 2
	hp_growth = 1.05
	resist_from = 10
	sturdy_from = 13
	orb_hp = 1.0
	trait_mul = 1.0
	match version:
		2:
			max_elems = 2
			max_mod = 3
			crowd = 0.15
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
			"crowd_log": crowd = maxf(0.0, float(v))  # 예전 "crowd"(하나당 +4% 직선)는 뜻이 달라 무시
			"pincer_frac": pincer_frac = float(v)
			"orb_mul": orb_mul = maxf(0.1, float(v))
			"tax_step": tax_step = float(v)
			"hp_growth": hp_growth = maxf(1.0, float(v))
			"orb_hp": orb_hp = maxf(0.1, float(v))
			"trait_mul": trait_mul = maxf(0.0, float(v))
