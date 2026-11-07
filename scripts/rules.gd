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
## 보이는 이름 (2026-10-31 사용자 결정: 1 = 랭크, 3 = 도파민 모드). id는 기록 키·서버와 맞춰 그대로 둔다.
const NAMES := {1: "랭크", 2: "버전 2 · 분산형", 3: "도파민 모드", 4: "버전 4 · 빠른 템포", 5: "버전 5 · 조합형 (폐기)"}
const DESCS := {
	1: "오브젝트마다 속성 3종 · 같은 강화 5개까지 · 쉬는 시간마다 카드 1장(처음 두 번 2장) · 오브젝트 수 보너스(5개 +16% · 10개 +23%, 늘수록 덜 오름) · 저항 구체 10웨이브, 굳센 구체 13웨이브부터",
	2: "오브젝트마다 속성 2종 · 같은 강화 3개까지 · 오브젝트 1개당 모든 피해 +6%",
	3: "상한 없음 · 속성 종류마다 공격 속도 -25% · 같은 강화는 쌓을수록 효과 절반씩 · 그 밖은 랭크와 같음",
	4: "쉬는 시간마다 카드 2장 · 11웨이브부터 구체 체력 웨이브마다 +8% · 특수 구체 8웨이브부터 · 구체 수 1.4배",
	5: "폐기 (2026-10-30, 너무 어려움). 예전 기록만 남음",
}
const NO_CAP := 99

static var version := 1
static var max_elems := 3  # 한 오브젝트에 넣을 수 있는 속성 종류 (레벨은 elem_cap까지)
static var max_mod := 5  # 강화 종류마다 쌓을 수 있는 수
static var mod_total := 12  # 한 오브젝트에 넣을 수 있는 강화 합계 (2026-11-01: 종류 수 제한이 없어 40개까지 몰아 넣으면 강화 없을 때의 17배)
static var crowd := 0.10  # 오브젝트 수 보너스 계수: 모든 피해 x(1 + crowd x ln(오브젝트 수)), crowd_bonus 참고
static var pincer_frac := 0.10  # 협공 표식 폭발: 구체 최대 체력 대비
static var orb_mul := 1.0  # 웨이브 구체 수 배율
static var tax_step := 0.15  # 속성 종류 하나당 공격 속도 감소
static var mod_decay := false  # 같은 강화를 쌓을수록 효과가 절반씩 (1, 1.5, 1.75, ...)
static var picks := 1  # 쉬는 시간마다 고르는 수 (2026-11-01 2 → 1)
static var open_picks := 2  # 처음 두 쉬는 시간(웨이브 0·1 뒤)에 고르는 수
static var hp_growth := 1.05  # 11웨이브부터 웨이브마다 구체 체력 배율
static var resist_from := 10  # 저항 구체가 나오는 웨이브
static var sturdy_from := 13  # 굳센 구체가 나오는 웨이브
static var orb_hp := 1.0  # 구체 체력 배율 (온라인 패치로만 바뀜)
## 조합 효율 측정(2026-10-30, docs/combo-efficiency)으로 고친 수치. 온라인 패치 rules의 같은 키로 덮어쓴다.
const TUNE := {
	# 오브젝트 상한
	"elem_cap": 5.0,  # 한 오브젝트에서 같은 속성 최대 레벨 
	# 자동 조준 (2026-11-07 기본 기능): 1이면 모든 오브젝트가 사거리 안 가장 가까운 구체를 겨누고 자동 조준 강화 카드는 나오지 않는다. 0이면 예전처럼 카드로만
	"auto_aim": 1.0,
	"aim_lead": 1.0,  # 자동 조준 예측: 탄이 날아가는 동안 구체가 갈 거리를 이만큼 앞질러 겨눔 (0이면 지금 자리)
	"auto_hp": 8.0,  # 자동 조준이 기본일 때 구체 체력 배율 (빗나가던 공격이 다 맞는 만큼 난이도 보정. 2026-11-07 봇 32판: 바꾸기 전 중간값 14, 자동 조준만 43, x4는 20, x8은 15)
	# 보조 공격 (Side, 2026-11-05 초반 난이도): 조준과 상관없이 둘레에서 가장 가까운 구체를 한 번
	"side_iv": 5.0,  # 보조 공격 간격(초) = 이 값 / 속성 종류 수 (0이면 보조 공격 없음)
	"side_dmg": 0.5,  # 보조 공격 피해 (x 위력)
	"side_r": 300.0,  # 보조 공격 둘레(px)
	"side_big_n": 8.0,  # 보조 공격 이 수마다 한 번은 큰 보조 공격 (0이면 없음)
	"side_mix_k": 0.2,  # 섞인 보조 공격(속성 2종 이상) 피해 배율 (Side.mdmg)
	"side_mix_floor": 0.85,  # 섞인 보통 보조 공격이 처음 맞힌 구체가 적어도 받는 피해 (한 마리 보조 공격 대비, Side.floor_hit)
	"side_big_k": 1.0,  # 큰 보조 공격 피해 = 보조 공격 피해 x 이 값 (어둠 일식은 그 절반)
	# 공격방식 수치 (공격방식마다 따로 쓰는 값)
	"clock_dmg": 0.9,  # 시계침: 바늘이 구체 하나를 한 번 훑을 때 피해 (x 위력)
	"gust_push_lv": 2.0,  # 돌풍: 옆으로 미는 힘이 세는 공격방식 최대 레벨 (미는 거리 20px x 레벨)
	"vortex_speed": 90.0,  # 지금은 안 씀 (예전 날아가는 블랙홀의 속도)
	"vortex_dmg": 0.4,  # 블랙홀: 중력 우물 안 구체가 받는 초당 피해 (x 위력)
	"vortex_end": 1.5,  # 블랙홀: 중력 우물이 사라질 때 터지는 피해 (x 위력, 모은 피해가 더해짐)
	"well_range": 450.0,  # 블랙홀: 중력 우물을 떨어뜨리는 사거리(px, 레벨·바람·사거리 배율 곱)
	"well_life": 4.0,  # 블랙홀: 중력 우물이 머무는 시간(초)
	"well_pull": 90.0,  # 블랙홀: 중력 우물이 구체를 끌어당기는 속도(초당 px)
	"well_core": 40.0,  # 블랙홀: 우물 가운데 이 거리(px) 안에 든 구체는 느려짐
	"well_absorb": 0.2,  # 블랙홀: 우물 안 구체가 다른 오브젝트에게 받은 피해 중 모으는 비율 (공격방식 레벨 1)
	"well_absorb_lv": 0.03,  # 블랙홀: 공격방식 레벨이 1 오를 때마다 모으는 비율 +
	"wall_dmg": 3.5,  # 벽: 바위에 막혀 있는 구체가 받는 초당 피해 (x 위력, 속사 곱)
	"wall_hp": 12.0,  # 벽: 바위 내구 (x 공격방식 레벨)
	"wall_drain": 1.5,  # 벽: 바위에 닿은 구체 하나가 초당 깎는 내구 (보스 x3)
	"wall_r": 32.0,  # 벽: 바위 반지름(px)
	"wall_iv": 3.5,  # 벽: 바위를 세우는 간격(초, 공격 속도로 나눔)
	"wall_break": 2.0,  # 벽: 바위가 무너지거나 사라질 때 둘레 구체 피해 (x 위력, 0이면 없음)
	# 강화 (보정표 세기)
	"mod_fix": 1.0,  # 강화 보정표(Pat.MOD_FIX) 세기: 1 = 표대로, 0 = 끔, 0.5 = 절반만
	# 강화 (주사위: 도박 특성)
	"dice_mid": 1.3,  # 주사위 4·5가 나왔을 때 강화 효과 배율
	"dice_top": 2.2,  # 주사위 6(대박)이 나왔을 때 강화 효과 배율
	# 속성 부가효과 (조정)
	"wood_cap": 5.0,  # 나무 부가효과(이 오브젝트 피해 +wood_dmg/레벨)가 세는 최대 레벨
	"wind_buff": 0.08,  # 바람 부가효과: 둘레(wind_range) 다른 오브젝트 공격 속도 + (x 바람 레벨, 여러 바람이면 가장 큰 것 하나)
	"sound_cd": 1.0,  # 소리 울림 음파: 한 구체에서 다시 터질 수 있을 때까지(초)
	"sound_pulse": 1.2,  # 소리 울림 음파 피해 (x 위력, 울림이 3번 쌓이면 둘레에 터짐)
	"sound_rate": 3.0,  # 소리 울림 음파: 오브젝트 하나가 1초에 터뜨릴 수 있는 최대 수
	# 판마다 다른 흐름 (2026-10-31, 시험, scripts/vary.gd)
	"vary_on": 1.0,  # 0이면 웨이브 이벤트·적응 구체를 끔 (봉인은 모드 '봉인'에서만)
	"vary_seal_elem": 3.0,  # 봉인: 판 시작 때 선택지에서 빼는 속성 수 (25·50웨이브에 하나씩 풀림)
	"vary_seal_pat": 4.0,  # 봉인: 판 시작 때 선택지에서 빼는 공격방식 수
	"vary_seal_link": 1.0,  # 봉인: 판 시작 때 선택지에서 빼는 연계 수
	"vary_event_every": 10.0,  # 웨이브 이벤트: 몇 웨이브마다 새 이벤트 (최소 2)
	"vary_event_k": 0.4,  # 웨이브 이벤트: 속성·공격방식 피해 +/- 크기 (도파민 모드 x1.5)
	"vary_adapt_from": 30.0,  # 적응 구체: 시작하는 웨이브
	"vary_adapt_step": 0.02,  # 적응 구체: 웨이브마다 피해 1위 속성·공격방식 저항 +, 나머지 -
	"vary_adapt_max": 0.2,  # 적응 구체: 저항 최대 (오브젝트 피해 기준)
	# 협동 짧은 판 (2026-10-31 사용자 "난이도가 올라가는 폭을 대폭, 금방금방 한 판 끝내는 형식"). Main.coop_hp_k
	"coop_orb_per": 0.6,  # 협동: 한 사람 늘 때마다 구체 수 + (2명 x1.6, 3명 x2.2, 4명 x2.8)
	"coop_hp_per": 0.5,  # 협동: 한 사람 늘 때마다 구체 체력 + (2명 x1.5, 3명 x2, 4명 x2.5)
	"coop_ramp": 1.18,  # 협동: 웨이브마다 구체 체력 x (곱, 웨이브 1은 x1)
	# 멀티 기다리기·대결 보낸 구체 (2026-10-31 사용자 승인 "전부 다 처리")
	"mp_wait": 45.0,  # 협동: 누군가 [웨이브 시작]을 누른 뒤 남은 사람이 고를 시간(초), 지나면 대신 골라 준비
	"mp_wait_force": 15.0,  # 협동 호스트: 그 뒤로도 안 오면(응답 없는 기기) 이만큼(초) 더 기다리고 시작
	"mp_afk_after": 2.0,  # 협동: 연속 이만큼 대신 고르면 자리 비움 (다음부터 기다리지 않음)
	"vs_idle": 90.0,  # 대결: 쉬는 시간이 이만큼(초) 이어지면 대신 고르고 웨이브 시작
	"vs_idle_out": 3.0,  # 대결: 연속 이만큼 저절로 시작하면 탈락
	"vs_send3": 0.7,  # 대결: 살아 있는 사람이 3명일 때 보내는 구체 수 배율 (2명 1)
	"vs_send4": 0.5,  # 대결: 살아 있는 사람이 4명 이상일 때 보내는 구체 수 배율
	"vs_recv_cap": 1.5,  # 대결: 한 웨이브에 받는 구체 상한 = (1 + 웨이브/4) x 이 값, 넘치면 다음 사람에게
	# 멀티 난이도 (2026-11-01 사용자 "멀티에서만 30% 쉽게", 혼자 판은 그대로)
	"vs_hp": 0.7,  # 대결: 구체 체력 배율
	"vs_spd": 1.0,  # 대결: 구체 속도 배율
	"mp_core": 1.3,  # 대결·협동: 중앙 체력 배율 (10 x 이 값)
	# 맵별 규칙·친화 카드 (2026-10-31, 시험, scripts/maprule.gd)
	"map_on": 1.0,  # 0이면 맵 규칙·친화 카드 모두 끔
	"map_aff_w": 1.5,  # 친화 카드가 선택지에 나오는 비중 (다른 카드 1)
	"map_aff_dmg": 0.15,  # 친화 속성(레벨 몫만큼)·친화 공격방식 피해 +
	"map_crowd": 2.0,  # 평원: 오브젝트 수 보너스 배율
	"map_reso": 0.3,  # 평원: 공명 거리 +
	"map_spiral_in": 1.4,  # 소용돌이: 중앙 가까이 구체 속도 배율
	"map_spiral_out": 0.8,  # 소용돌이: 바깥 구체 속도 배율 (중앙까지 거리에 따라 사이 값)
	"map_cross_dmg": 0.25,  # 십자로: 길 위에서 길 따라 겨눈 오브젝트 피해 +
	"map_wind_with": 0.3,  # 폭풍: 순풍을 탄 탄 속도·사거리 + (바람 방향과 맞는 만큼)
	"map_wind_against": 0.15,  # 폭풍: 역풍을 맞은 탄 속도·사거리 -
	"map_line_trail": 2.0,  # 회랑: 지나간 자리 장판 지속 시간 배율
	"map_line_cc": 0.3,  # 회랑: 감속·밀치기 세기 +
	# 기맥 (2026-10-31 "디펜스 한계 개선 F", main.ley)
	"ley_on": 1.0,  # 0이면 기맥을 끔 (일반 판만, 멀티는 없음)
	"ley_n": 3.0,  # 기맥: 판마다 전장에 생기는 자리 수
	"ley_r": 40.0,  # 기맥: 자리 반지름(px)
	"ley_dmg": 0.15,  # 기맥: 자리 위 오브젝트 피해 + (자리마다 가장 가까운 하나)
	# 진입 시간 맞추기 (2026-11-01): 구체가 전장 가장자리 바로 밖에서 나오고, 가장자리→중앙 시간이 방향과 상관없이 같다 (Main.lane_k)
	"lane_even": 1.0,  # 0이면 예전처럼 모든 방향 같은 거리(대각선 반 + 30)에서 같은 속도
	"lane_margin": 30.0,  # 구체가 전장 가장자리 밖 몇 px에서 나오는지
	"lane_speed": 1.1,  # 모든 방향 구체 속도에 곱함 (소용돌이 말고)
	"lane_speed_spiral": 1.0,  # 소용돌이 맵 구체 속도에 곱함
	# 후반 난이도 (2026-10-31 사용자 "600웨이브쯤이 한계로"): Main.hp_growth·count_k·orb_base_speed·wave_size
	"hp_late_from": 150.0,  # 이 웨이브까지 구체 체력 x hp_growth, 그 뒤는 x hp_growth_late
	"hp_growth_late": 1.03,  # hp_late_from 웨이브 뒤 웨이브마다 구체 체력 배율
	"orb_n_cap_w": 150.0,  # 구체 수가 이 웨이브 수(3 + 2 x 웨이브)에서 멈춤, 넘는 몫은 구체 체력으로
	"orb_spd_cap_w": 34.0,  # 구체 기본 속도(30 + 3 x 웨이브)가 이 웨이브 값에서 멈춤 (2026-11-06: 34 = 일반 구체 평균 약 150px/초)
	# 후반 구체 (2026-10-31 사용자 "100·175·250·350·500웨이브에 하나씩", Orb.late, Main._late_trait)
	"late_blink_from": 100.0,  # 깜빡 구체가 나오는 웨이브
	"late_armor_from": 175.0,  # 갑옷 구체가 나오는 웨이브
	"late_heal_from": 250.0,  # 치유 구체가 나오는 웨이브
	"late_phase_from": 350.0,  # 흐림 구체가 나오는 웨이브
	"late_devour_from": 500.0,  # 포식 구체가 나오는 웨이브
	"late_share": 0.08,  # 후반 구체(포식 말고): 처음 나올 때 웨이브 구체 중 비율
	"late_share_step": 0.01,  # 후반 구체: 10웨이브마다 비율 +
	"late_share_max": 0.2,  # 후반 구체: 종류마다 최대 비율
	"late_blink_iv": 3.5,  # 깜빡: 앞으로 순간이동하는 간격(초)
	"late_blink_dist": 90.0,  # 깜빡: 순간이동 거리(px)
	"late_armor": 0.04,  # 갑옷: 한 대 맞을 때 빼는 피해 (그 웨이브 구체 체력 대비)
	"late_armor_break": 0.02,  # 갑옷: 맞을 때마다 갑옷이 줄어드는 비율
	"late_armor_floor": 0.5,  # 갑옷: 아무리 맞아도 남는 갑옷 비율
	"late_armor_min": 0.3,  # 갑옷: 갑옷이 커도 최소 이 비율의 피해는 들어감
	"late_heal_iv": 2.5,  # 치유: 둘레 구체를 고치는 간격(초)
	"late_heal_r": 120.0,  # 치유: 고치는 반경(px)
	"late_heal": 0.06,  # 치유: 한 번에 고치는 양 (최대 체력 대비, 화상·중독 중이면 절반)
	"late_heal_max": 4.0,  # 치유: 웨이브당 치유 구체 최대 수
	"late_phase_on": 2.5,  # 흐림: 실체인 시간(초)
	"late_phase_off": 1.5,  # 흐림: 흐려지는 시간(초)
	"late_phase_dmg": 0.3,  # 흐림: 흐릴 때 받는 직접 피해 배율
	"late_devour_n": 2.0,  # 포식: 웨이브당 수
	"late_devour_take": 0.5,  # 포식: 삼킨 구체 체력 중 제 체력으로 가져가는 비율
	"late_devour_core": 5.0,  # 포식: 중앙에 닿을 때 피해 최대 (1 + 삼킨 수)
	# 중앙 기술 (2026-10-31 사용자 "디펜스 한계 개선 A", Skill): 웨이브 중에 쓰는 기술 2칸, 쿨다운은 게임 시간(웨이브 시작마다 다시 참)
	"skill_on": 1.0,  # 0이면 기술 버튼이 안 나옴
	"skill_focus_t": 6.0,  # 집중: 지속 시간(초)
	"skill_focus_spd": 2.0,  # 집중: 고른 오브젝트 하나 공격 속도 배율
	"skill_focus_cd": 25.0,  # 집중: 다시 쓰기까지(초)
	"skill_hold_r": 120.0,  # 붙잡기: 반경(px)
	"skill_hold_t": 2.0,  # 붙잡기: 반경 안 구체를 멈추는 시간(초, 기절 한계·보스 절반 따름)
	"skill_hold_cd": 30.0,  # 붙잡기: 다시 쓰기까지(초)
	"skill_brand_r": 150.0,  # 낙인: 반경(px)
	"skill_brand_amp": 0.3,  # 낙인: 반경 안 구체가 받는 피해 +
	"skill_brand_t": 5.0,  # 낙인: 지속 시간(초)
	"skill_brand_cd": 20.0,  # 낙인: 다시 쓰기까지(초)
	"skill_cool_perk": 0.2,  # 특성 '빠른 손': 고를 때마다 다시 쓰기 시간 x(1 - 값)
	# 방해 구체 (2026-10-31 "디펜스 한계 개선 B", Orb.jam): 오브젝트를 잠깐 멈추거나 느리게만 (오브젝트 체력은 없음)
	"jam_on": 1.0,  # 0이면 방해 구체가 안 나옴 (일반 판만)
	"jam_shade_from": 20.0,  # 그림자 구체가 나오는 웨이브
	"jam_leech_from": 30.0,  # 흡수 구체가 나오는 웨이브
	"jam_seeker_from": 40.0,  # 표적 구체가 나오는 웨이브
	"jam_share": 0.05,  # 방해 구체: 종류마다 처음 나올 때 웨이브 구체 중 비율
	"jam_share_step": 0.01,  # 방해 구체: 10웨이브마다 비율 +
	"jam_share_max": 0.12,  # 방해 구체: 종류마다 최대 비율
	"jam_shade_r": 80.0,  # 그림자: 지나가며 오브젝트 공격을 멈추는 거리(px)
	"jam_shade_t": 1.5,  # 그림자: 오브젝트 공격을 멈추는 시간(초)
	"jam_imm": 4.0,  # 멈춤이 풀린 뒤 같은 오브젝트가 다시 멈추지 않는 시간(초)
	"jam_leech": 0.05,  # 흡수: 오브젝트가 맞힐 때마다 그 오브젝트 공격 속도 - (겹칠수록)
	"jam_leech_max": 5.0,  # 흡수: 최대 겹침 수
	"jam_leech_t": 4.0,  # 흡수: 느려짐 유지 시간(초)
	"jam_leech_free": 300.0,  # 흡수: 죽으면 이 거리(px) 안 오브젝트 느려짐이 풀림
	"jam_seek_t": 3.0,  # 표적: 가장 가까운 오브젝트로 와서 닿으면 그 오브젝트를 멈추는 시간(초)
	"jam_seek_spd": 1.15,  # 표적: 이동 속도 배율
}

## 오브젝트·강화·속성·연계·발동 수치 (2026-10-31 사용자 요청 "공격력·사거리·공격속도 등 모든 옵션을 서버에서 임의 수정").
## 온라인 패치 rules의 같은 키로 덮어쓴다 (TUNE과 같은 길). 값은 지금 게임과 같다. 키 설명은 server/README.md.
const STAT := {
	# 오브젝트 피해·성장
	"lv_dmg": 0.5,  # 레벨이 1 오를 때마다 위력 + (공격방식 레벨, 반응·부가효과는 그 속성 레벨)
	"lv_spd": 0.2,  # 공격방식 레벨이 1 오를 때마다 공격 속도 +
	"lv_reach": 0.1,  # 공격방식 레벨이 1 오를 때마다 사거리 +
	"dmg_base": 2.1,  # 모든 오브젝트 기본 피해 배율
	"dmg_sum": 0.35,  # 오브젝트에 든 속성 레벨 합이 1 늘 때마다 피해 + (반응 제외)
	# 공격방식 수치
	"shot_range": 400.0,  # 직선탄 사거리(px)
	"shot_range_lv": 50.0,  # 속성 레벨 합이 1 늘 때마다 직선탄 사거리 +(px)
	"far_len": 400.0,  # 직선탄·돌풍·물줄기·연쇄 번개: 감소 시작 거리(옛 사거리)를 넘어 이 거리(px) 동안 피해가 줄어든다
	"far_min": 0.5,  # 위 감소가 멈추는 피해 몫(하한)
	"laser_w": 21.0,  # 레이저 판정 반폭(px, 크기 강화 곱, 구체 반지름 더함). 빛줄기 두께도 이 값에 맞춰 커짐
	# 강화
	"multi_dmg": 0.55,  # 다중 발사: 1개일 때 한 발 피해 배율
	"multi_decay": 0.15,  # 다중 발사: 더 쌓을 때마다 한 발 피해를 (1 + 값 x (개수-1))로 나눔
	"multi_angle": 0.22,  # 다중 발사: 탄 사이 각도(라디안)
	"split_ch": 0.12,  # 분열: 1개마다 맞힐 때 파편 2개가 튈 확률 +
	"split_max": 0.6,  # 분열: 파편 확률 최대
	"split_dmg": 0.5,  # 분열: 파편 피해 배율 (파편 기본 피해 x 값)
	"size_k": 0.12,  # 크기: 1개마다 탄 크기·범위·사거리 +
	"size_dmg": 0.04,  # 크기: 1개마다 탄 쏘는 공격방식 피해 +
	"rapid_k": 0.1,  # 속사: 1개마다 공격 속도 +
	"pierce_hit": 0.5,  # 관통: 구체를 뚫고 나간 탄의 피해 배율
	"pierce_dmg": 0.06,  # 관통: 1개마다 탄이 아닌 공격방식 피해 +
	"pierce_shield": 0.25,  # 관통: 1개마다 탄이 아닌 공격이 보호막을 피해의 이만큼 더 깎음
	"pierce_armor": 0.2,  # 관통: 1개마다 탄이 아닌 공격에 후반 갑옷이 빼는 피해 -
	"bounce_hit": 0.4,  # 튕김: 튕긴 탄 피해 배율
	"bounce_iv": 0.8,  # 튕김: 탄·번개가 아닌 공격이 맞힐 때 튕김 탄을 내는 간격(초, 공격 속도로 나눔)
	"gust_gap": 45.0,  # 돌풍 다중 발사: 나란히 나가는 돌풍 사이 옆 간격(px)
	"homing_k": 0.8,  # 유도: 휘는 힘
	"homing_fade": 0.15,  # 유도탄: 휜 각도 90도마다 피해 -
	"homing_fade_min": 0.55,  # 유도탄: 휘어 줄어든 피해의 최저 배율
	"wisp_fade_from": 2.0,  # 혼불: 이만큼(초) 떠돈 뒤부터 피해가 줄어듦
	"wisp_fade": 0.12,  # 혼불: 그 뒤 1초마다 피해 -
	"wisp_fade_min": 0.5,  # 혼불: 줄어든 피해의 최저 배율
	# 속성 부가효과
	"fire_dps": 1.0,  # 불: 화상 초당 피해 (x 불 레벨)
	"fire_t": 2.0,  # 불: 화상 시간(초)
	"poison_dps": 0.6,  # 독: 중독 초당 피해 (x 독 레벨)
	"poison_t": 4.0,  # 독: 중독 시간(초)
	"wood_dmg": 0.16,  # 나무: 이 오브젝트가 주는 피해 + (x 나무 레벨, wood_cap까지)
	"water_slow": 0.85,  # 물: 감속된 이동 속도 배율 = 값 - water_lv x 물 레벨 (낮을수록 느림)
	"water_t": 0.8,  # 물: 감속 시간(초)
	"water_lv": 0.03,  # 물: 물 레벨마다 감속 배율 -
	"elec_ch": 0.3,  # 전기: 맞힐 때 전류가 튈 확률
	"elec_dmg": 0.4,  # 전기: 전류 피해 (맞힌 피해 x 값 x 전기 레벨)
	"wind_range": 240.0,  # 바람: 공격 속도를 올려 주는 둘레(px, 세기는 wind_buff)
	"ice_chill": 0.6,  # 얼음: 맞힐 때 쌓는 냉기 (x 얼음 레벨, 3 쌓이면 얼어붙음)
	"earth_ch": 0.14,  # 땅: 기절 확률 (x 땅 레벨, 진흙 위 2배)
	"earth_max": 0.7,  # 땅: 기절 확률 최대
	"earth_t": 0.8,  # 땅: 기절 시간(초)
	"dark_vuln": 0.2,  # 어둠: 받는 피해 + (기본, 여기에 dark_lv x 어둠 레벨을 더함)
	"dark_t": 2.0,  # 어둠: 받는 피해 증가 시간(초)
	"dark_lv": 0.04,  # 어둠: 어둠 레벨마다 받는 피해 +
	"light_ch": 0.12,  # 빛: 치명타 확률 (x 빛 레벨)
	"light_max": 0.6,  # 빛: 치명타 확률 최대
	"light_mul": 2.0,  # 빛: 치명타 피해 배율
	"metal_dmg": 0.08,  # 금속: 맞힐 때 더하는 피해 (맞힌 피해 x 값 x 금속 레벨)
	"metal_stagger": 4.0,  # 금속: 맞은 구체를 멈칫하게 하는 거리(px, x 금속 레벨)
	"sound_t": 3.0,  # 소리: 울림이 걸려 있는 시간(초, 그동안 어느 오브젝트에 맞아도 울림이 쌓임)
	"time_base": 0.15,  # 시간: 메아리 비율 기본 (받은 피해의 이만큼을 나중에 한 번 더)
	"time_lv": 0.05,  # 시간: 시간 레벨마다 메아리 비율 +
	"time_max": 0.4,  # 시간: 메아리 비율 최대
	"time_t": 2.0,  # 시간: 메아리가 모으는 시간(초)
	"soul_t": 3.0,  # 영혼: 넋 표식 시간(초)
	"soul_base": 0.2,  # 영혼: 넋 표식이 있는 구체가 죽을 때 혼불이 나올 확률 기본
	"soul_lv": 0.08,  # 영혼: 영혼 레벨마다 혼불 확률 +
	"soul_max": 0.6,  # 영혼: 혼불 확률 최대
	"blood_dmg": 1.6,  # 피: 출혈 피해 (구체가 100px 움직일 때마다, x 피 레벨)
	"blood_t": 3.0,  # 피: 출혈 시간(초)
	"illu_ch": 0.06,  # 환영: 현혹 확률 (x 환영 레벨)
	"illu_max": 0.3,  # 환영: 현혹 확률 최대
	"illu_t": 0.8,  # 환영: 왔던 길을 되돌아 걷는 시간(초, 보스는 절반)
	"illu_cd": 2.0,  # 환영: 같은 구체가 다시 현혹될 때까지(초)
	"illu_spd": 0.6,  # 환영: 되돌아 걷는 속도 (이동 속도 x 값)
	# 연계
	"reso_k": 0.12,  # 공명: 둘레 다른 오브젝트 하나당 피해 + (x 공명 수)
	"reso_r": 150.0,  # 공명: 둘레 거리(px)
	"pincer_t": 3.0,  # 협공: 두 오브젝트가 이 시간(초) 안에 같은 구체를 맞히면 폭발 (세기는 pincer_frac)
	"pincer_cd": 1.5,  # 협공: 같은 구체에서 다시 터질 때까지(초)
	# 발동
	"trig_max": 5.0,  # 발동 카드 종류마다 한 오브젝트에 넣을 수 있는 최대 수
	"echo_n": 3.0,  # 여진: 처치할 때 터지는 탄 수 (+1/장)
	"echo_dmg": 0.8,  # 여진: 탄 피해 배율
	"echo_cd": 0.5,  # 여진: 다시 터질 때까지(초)
	"van_hp": 0.7,  # 선봉: 체력이 이 비율 이상인 구체에 피해 배율을 줌
	"van_mul": 1.4,  # 선봉: 피해 배율 (1장)
	"van_add": 0.15,  # 선봉: 1장 더할 때마다 피해 배율 +
	"charge_r": 220.0,  # 축적: 처치를 세는 거리(px)
	"charge_k": 1.0,  # 축적: 강타 피해 배율 (표 x 이 값)
	"third_k": 1.0,  # 삼연: 3번째 공격 피해 배율 (표 x 이 값)
	"third_size": 1.3,  # 삼연: 3번째 공격 탄 크기 배율
	"finish_hp": 0.3,  # 마무리: 체력이 이 비율 아래인 구체에 피해 배율을 줌
	"finish_mul": 1.6,  # 마무리: 피해 배율 (1장)
	"finish_add": 0.3,  # 마무리: 1장 더할 때마다 피해 배율 +
	"answer_r": 220.0,  # 호응: 맞힌 오브젝트 둘레 이 거리(px) 안의 호응 오브젝트가 그쪽으로 한 발씩 따라 쏨
	"answer_cd": 0.6,  # 호응: 다시 쏠 때까지(초)
	"answer_dmg": 0.6,  # 호응: 피해 (직선탄 한 발 대비, 1장)
	"answer_add": 0.15,  # 호응: 1장 더할 때마다 피해 +
	# 별·행성 (별: 둘레 다른 오브젝트 피해를 별빛으로 모아 다 차면 초신성. 행성 = 별 + 속성 하나, 둘레 피해 중 자기 속성 몫을 모음)
	"star_r": 220.0,  # 별: 피해를 모으는 둘레 거리(px)
	"star_take": 0.10,  # 별: 둘레 다른 오브젝트 피해 중 별빛으로 모으는 비율 (별 Lv1)
	"star_lv": 0.03,  # 별: 별 레벨마다 모으는 비율 + (star_lv_cap까지)
	"star_lv_cap": 5.0,  # 별: 모으는 비율이 오르는 최대 별 레벨 (그 뒤 레벨은 초신성 범위만)
	"star_self": 0.2,  # 별: 자기 피해 중 모으는 비율
	"star_pure": 1.5,  # 별: 별만 든 오브젝트(순수 별)의 모으는 비율 배율
	"star_need": 8.0,  # 별: 초신성까지 필요한 별빛 (이번 웨이브 구체 체력 x 값)
	"star_mul": 3.0,  # 별: 초신성 피해 (모은 별빛 x 값)
	"star_boss_cap": 0.15,  # 보스는 초신성 한 번에 최대 체력의 이 비율까지만 깎임
	"star_max": 3.0,  # 별이 든 오브젝트(별·행성 합쳐) 최대 수
	"planet_max": 3.0,  # 행성 최대 수 (같은 행성은 한 판에 하나)
	"planet_take": 0.45,  # 행성: 둘레 피해 중 자기 속성 몫에서 모으는 비율 (별 Lv1)
	"planet_lv": 0.045,  # 행성: 별 레벨마다 자기 속성 몫 비율 +
	"planet_other": 0.05,  # 행성: 자기 속성이 아닌 몫에서 모으는 비율
	"planet_self": 0.3,  # 행성: 자기 피해 중 모으는 비율
	"planet_mul": 0.85,  # 행성: 초신성 피해 배율 (star_mul에 곱함)
}


## TUNE + STAT + 공격방식마다 dmg_/spd_/range_<id>(배율 1) + 특징 공유 share_mul·share_<속성>(특징마다 세기 배율, 기본은 SHARE).
static func defaults() -> Dictionary:
	var d := TUNE.merged(STAT)
	for id in Pat.ALL_IDS:
		for p in ["dmg_", "spd_", "range_"]:
			d[p + id] = 1.0
	d["share_mul"] = 1.5  # 고정 반응을 뺀 만큼 (2026-11-03 웨이브 단계 봇, 기본 피해 1.43→2.1과 함께)
	for key in Patch.ELEM_KEYS:
		if key != "soul":  # 영혼 쫓아감은 혼불이 주인 공격을 그대로 쓴다 (세기 배율 없음)
			d["share_" + key] = SHARE.get(key, 1.0)
	return d


## 특징 세기 차등 (2026-11-03). 피해를 직접 늘리는 특징은 낮게, 드물게 터지는 특징은 높게. 없는 속성은 1.
## 온라인 패치 rules.share_<속성>이 이 값을 덮어쓴다.
const SHARE := {
	"fire": 0.8,  # 타오름: 화상이 끝나거나 죽을 때 불꽃 (피해)
	"electric": 0.8,  # 튐: 번개가 튀는 구체마다 (피해)
	"metal": 0.7,  # 응축: 효과 하나당 추가 피해 (피해)
	"poison": 0.9,  # 전염: 중독된 채 죽으면 둘레 (지속 피해)
	"time": 0.9,  # 되풀이: 맞힐 때마다 0.8초 뒤 다시 (자주 터짐)
	"earth": 1.1,  # 묻어둠: 2초 안에 다시 맞아야 터짐
	"light": 1.1,  # 꿰뚫음: 치명타 때만
	"dark": 1.2,  # 끌어당김: 약화된 채 죽을 때만
	"blood": 0.9,  # 핏자국: 뒤따르는 구체가 많을수록 자주 (2026-11-04)
}


static var DEFAULTS := defaults()
static var tune := DEFAULTS.duplicate()
## 자주 읽는 값(맞힐 때마다 등)은 tune 사전 대신 이 변수로 읽는다 (apply 끝에 _cache). 사전 찾기가 한 번 맞힐 때 열 번 넘게 돌아 후반 렉이 늘던 것
static var lv_dmg: float = STAT["lv_dmg"]
static var lv_spd: float = STAT["lv_spd"]
static var lv_reach: float = STAT["lv_reach"]
static var rapid_k: float = STAT["rapid_k"]
static var size_k: float = STAT["size_k"]
static var far_len: float = STAT["far_len"]
static var far_min: float = STAT["far_min"]
static var size_dmg: float = STAT["size_dmg"]
static var fire_dps: float = STAT["fire_dps"]
static var fire_t: float = STAT["fire_t"]
static var poison_dps: float = STAT["poison_dps"]
static var poison_t: float = STAT["poison_t"]
static var ice_chill: float = STAT["ice_chill"]
static var water_slow: float = STAT["water_slow"]
static var water_lv: float = STAT["water_lv"]
static var dark_lv: float = STAT["dark_lv"]
static var water_t: float = STAT["water_t"]
static var earth_ch: float = STAT["earth_ch"]
static var earth_max: float = STAT["earth_max"]
static var earth_t: float = STAT["earth_t"]
static var dark_t: float = STAT["dark_t"]
static var dark_vuln: float = STAT["dark_vuln"]
static var light_ch: float = STAT["light_ch"]
static var light_max: float = STAT["light_max"]
static var light_mul: float = STAT["light_mul"]
static var elec_ch: float = STAT["elec_ch"]
static var elec_dmg: float = STAT["elec_dmg"]
static var wood_dmg: float = STAT["wood_dmg"]
static var metal_dmg: float = STAT["metal_dmg"]
static var metal_stagger: float = STAT["metal_stagger"]
static var sound_t: float = STAT["sound_t"]
static var time_base: float = STAT["time_base"]
static var time_lv: float = STAT["time_lv"]
static var time_max: float = STAT["time_max"]
static var time_t: float = STAT["time_t"]
static var soul_t: float = STAT["soul_t"]
static var blood_dmg: float = STAT["blood_dmg"]
static var blood_t: float = STAT["blood_t"]
static var illu_ch: float = STAT["illu_ch"]
static var illu_max: float = STAT["illu_max"]
static var illu_t: float = STAT["illu_t"]
static var illu_cd: float = STAT["illu_cd"]
static var illu_spd: float = STAT["illu_spd"]
static var split_ch: float = STAT["split_ch"]
static var split_max: float = STAT["split_max"]
static var multi_dmg: float = STAT["multi_dmg"]
static var multi_decay: float = STAT["multi_decay"]
static var multi_angle: float = STAT["multi_angle"]
static var wood_cap: float = TUNE["wood_cap"]
static var dice_top: float = TUNE["dice_top"]
static var pierce_hit: float = STAT["pierce_hit"]
static var bounce_hit: float = STAT["bounce_hit"]
static var pierce_shield: float = STAT["pierce_shield"]
static var pierce_armor: float = STAT["pierce_armor"]
static var homing_k: float = STAT["homing_k"]
static var pincer_t: float = STAT["pincer_t"]
static var late_armor_break: float = TUNE["late_armor_break"]
static var late_armor_floor: float = TUNE["late_armor_floor"]
static var late_armor_min: float = TUNE["late_armor_min"]
static var late_phase_on: float = TUNE["late_phase_on"]
static var late_phase_dmg: float = TUNE["late_phase_dmg"]
static var share_mul := 1.0  # 특징 공유 전체 세기 (Share.k)
static var share_k := {}  # 속성 → 그 특징 세기 배율 (1이 아닌 것만)


static func _cache() -> void:
	lv_dmg = tune["lv_dmg"]
	lv_spd = tune["lv_spd"]
	lv_reach = tune["lv_reach"]
	rapid_k = tune["rapid_k"]
	size_k = tune["size_k"]
	far_len = tune["far_len"]
	far_min = tune["far_min"]
	size_dmg = tune["size_dmg"]
	fire_dps = tune["fire_dps"]
	fire_t = tune["fire_t"]
	poison_dps = tune["poison_dps"]
	poison_t = tune["poison_t"]
	ice_chill = tune["ice_chill"]
	water_slow = tune["water_slow"]
	water_lv = tune["water_lv"]
	dark_lv = tune["dark_lv"]
	water_t = tune["water_t"]
	earth_ch = tune["earth_ch"]
	earth_max = tune["earth_max"]
	earth_t = tune["earth_t"]
	dark_t = tune["dark_t"]
	dark_vuln = tune["dark_vuln"]
	light_ch = tune["light_ch"]
	light_max = tune["light_max"]
	light_mul = tune["light_mul"]
	elec_ch = tune["elec_ch"]
	elec_dmg = tune["elec_dmg"]
	wood_dmg = tune["wood_dmg"]
	metal_dmg = tune["metal_dmg"]
	metal_stagger = tune["metal_stagger"]
	sound_t = tune["sound_t"]
	time_base = tune["time_base"]
	time_lv = tune["time_lv"]
	time_max = tune["time_max"]
	time_t = tune["time_t"]
	soul_t = tune["soul_t"]
	blood_dmg = tune["blood_dmg"]
	blood_t = tune["blood_t"]
	illu_ch = tune["illu_ch"]
	illu_max = tune["illu_max"]
	illu_t = tune["illu_t"]
	illu_cd = tune["illu_cd"]
	illu_spd = tune["illu_spd"]
	split_ch = tune["split_ch"]
	split_max = tune["split_max"]
	multi_dmg = tune["multi_dmg"]
	multi_decay = tune["multi_decay"]
	multi_angle = tune["multi_angle"]
	wood_cap = tune["wood_cap"]
	dice_top = tune["dice_top"]
	pierce_hit = tune["pierce_hit"]
	bounce_hit = tune["bounce_hit"]
	pierce_shield = tune["pierce_shield"]
	pierce_armor = tune["pierce_armor"]
	homing_k = tune["homing_k"]
	pincer_t = tune["pincer_t"]
	late_armor_break = tune["late_armor_break"]
	late_armor_floor = tune["late_armor_floor"]
	late_armor_min = tune["late_armor_min"]
	late_phase_on = tune["late_phase_on"]
	late_phase_dmg = tune["late_phase_dmg"]
	share_mul = tune["share_mul"]
	share_k.clear()
	for i in Patch.ELEM_KEYS.size():
		var v: float = tune.get("share_" + Patch.ELEM_KEYS[i], 1.0)
		if v != 1.0:
			share_k[Elem.ALL[i]] = v


static func t(k: String) -> float:
	return tune[k]


## 설명 글의 {키}를 지금 값으로: {키%}는 퍼센트(0.12 → 12), {키}는 숫자(정수면 소수점 없이).
static func fmt(s: String) -> String:
	if not "{" in s:
		return s
	var out := ""
	var i := 0
	while true:
		var a := s.find("{", i)
		var b := s.find("}", a + 1) if a >= 0 else -1
		if a < 0 or b < 0:
			break
		out += s.substr(i, a - i)
		var k := s.substr(a + 1, b - a - 1)
		var pc := k.ends_with("%")
		k = k.trim_suffix("%")
		if tune.has(k):
			var v: float = tune[k] * (100.0 if pc else 1.0)
			out += str(roundi(v)) if absf(v - roundf(v)) < 0.005 else ("%.2f" % v).rstrip("0")
		else:
			out += s.substr(a, b - a + 1)
		i = b + 1
	return out + s.substr(i)


## 오브젝트 수 보너스(모든 오브젝트 피해에 더하는 몫). 2026-10-30 직선(하나당 +4%, 10개 +36%)이 후반에 과해
## 늘수록 덜 오르는 로그 곡선으로: 2개 +7% · 5개 +16% · 10개 +23% · 16개 +28% (crowd 0.10)
static func crowd_bonus(n: int) -> float:
	return crowd * log(float(maxi(n, 1)))


static func apply(v: int) -> void:
	version = v if v in ALL_IDS else 1
	max_elems = 3
	max_mod = 5
	mod_total = 12
	crowd = 0.10
	pincer_frac = 0.10
	orb_mul = 1.0
	tax_step = 0.15
	mod_decay = false
	picks = 1
	open_picks = 2
	hp_growth = 1.05
	resist_from = 10
	sturdy_from = 13
	orb_hp = 1.0
	tune = DEFAULTS.duplicate()
	match version:
		1:
			pass  # 예전 wood_cap 99 (레벨 무제한 규칙). 2026-11-01부터 모든 규칙이 속성 Lv5 상한(elem_cap)이라 나무도 Lv5까지 다 센다
		2:
			max_elems = 2
			max_mod = 3
			crowd = 0.15
		3:
			max_elems = NO_CAP
			max_mod = NO_CAP
			mod_total = NO_CAP
			tax_step = 0.25
			mod_decay = true
		4:
			picks = 2
			orb_mul = 1.4  # 2장씩 고르는 만큼 구체를 늘려 버전 1과 비슷한 난이도로 (봇 평균 10.2 → 6.2, 버전 1은 6.9)
			hp_growth = 1.08
			resist_from = 8
			sturdy_from = 11
	_apply_patch(Patch.rules_for(version))
	if tune["auto_aim"] > 0.0:
		orb_hp *= tune["auto_hp"]
	_cache()


## 게임 코드 수치 (2026-11-03 사용자 "모든 값을 온라인으로 패치"): 아래 스크립트의 대문자 static var(숫자, 숫자 배열,
## 숫자 사전)를 rules 키 "<이름>.<변수>" 또는 "<이름>.<변수>.<칸>"으로 덮어쓴다. 예) "Tower.HIT.laser": 4.0, "Orb.KIND.boss_hp": 10
## 목록·설명은 tools/rule_keys.gd가 만든다 (관리 화면 수치 편집 표).
const CODE := {
	"Tower": "res://scripts/tower.gd", "Projectile": "res://scripts/projectile.gd", "Orb": "res://scripts/orb.gd",
	"Main": "res://scripts/app/session.gd", "Modes": "res://scripts/modes.gd", "Share": "res://scripts/share.gd",
	"Pat": "res://scripts/pattern.gd", "MapRule": "res://scripts/maprule.gd", "Skill": "res://scripts/skill.gd",
}
static var _code_orig := {}  # "Tower.HIT" → 패치 전 값 (처음 바꿀 때 기억해 두고, 다음 apply마다 되돌린다)


static func _code_reset() -> void:
	for full in _code_orig:
		var i: int = full.find(".")
		var v: Variant = _code_orig[full]
		(load(CODE[full.left(i)]) as GDScript).set(full.substr(i + 1), v.duplicate() if v is Array or v is Dictionary else v)


## "Tower.HIT.laser" 같은 키 하나. 모르는 이름·칸, 숫자가 아닌 값은 무시. 정수 칸은 정수로.
static func _code_set(k: String, v: float) -> bool:
	var parts := k.split(".")
	if parts.size() < 2 or parts.size() > 3 or not CODE.has(parts[0]) or parts[1] != parts[1].to_upper():
		return false
	var sc := load(CODE[parts[0]]) as GDScript
	var cur: Variant = sc.get(parts[1])
	if cur == null:
		return false
	var full := parts[0] + "." + parts[1]
	if not _code_orig.has(full):
		_code_orig[full] = cur.duplicate() if cur is Array or cur is Dictionary else cur
	if parts.size() == 2:
		if not (cur is float or cur is int):
			return false
		sc.set(parts[1], int(v) if cur is int else v)
		return true
	var sub := parts[2]
	if cur is Dictionary:
		if not cur.has(sub) or not (cur[sub] is float or cur[sub] is int):
			return false
		var d: Dictionary = cur.duplicate()
		d[sub] = int(v) if cur[sub] is int else v
		sc.set(parts[1], d)
		return true
	if cur is Array and sub.is_valid_int() and int(sub) >= 0 and int(sub) < cur.size() and (cur[int(sub)] is float or cur[int(sub)] is int):
		var a: Array = cur.duplicate()
		a[int(sub)] = int(v) if cur[int(sub)] is int else v
		sc.set(parts[1], a)
		return true
	return false


## 온라인 패치(Patch)의 rules 덮어쓰기. 모르는 키·형식이 틀린 값은 무시.
static func _apply_patch(p: Dictionary) -> void:
	_code_reset()
	for k in p:
		var v: Variant = p[k]
		if "." in k:
			if v is float or v is int:
				_code_set(k, float(v))
			continue
		if k == "mod_decay":
			if v is bool:
				mod_decay = v
			continue
		if not (v is float or v is int):
			continue
		if DEFAULTS.has(k):
			tune[k] = maxf(0.0, float(v))
			continue
		match k:
			"max_elems": max_elems = maxi(1, int(v))
			"max_mod": max_mod = maxi(1, int(v))
			"mod_total": mod_total = maxi(1, int(v))
			"picks": picks = maxi(1, int(v))
			"open_picks": open_picks = maxi(1, int(v))
			"resist_from": resist_from = int(v)
			"sturdy_from": sturdy_from = int(v)
			"crowd_log": crowd = maxf(0.0, float(v))  # 예전 "crowd"(하나당 +4% 직선)는 뜻이 달라 무시
			"pincer_frac": pincer_frac = float(v)
			"orb_mul": orb_mul = maxf(0.1, float(v))
			"tax_step": tax_step = float(v)
			"hp_growth": hp_growth = maxf(1.0, float(v))
			"orb_hp": orb_hp = maxf(0.1, float(v))
