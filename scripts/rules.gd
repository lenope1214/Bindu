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
	1: "오브젝트마다 속성 3종 · 같은 강화 5개까지 · 쉬는 시간마다 카드 2장 · 오브젝트 수 보너스(5개 +16% · 10개 +23%, 늘수록 덜 오름) · 저항 구체 10웨이브, 굳센 구체 13웨이브부터",
	2: "오브젝트마다 속성 2종 · 같은 강화 3개까지 · 오브젝트 1개당 모든 피해 +6%",
	3: "상한 없음 · 속성 종류마다 공격 속도 -25% · 같은 강화는 쌓을수록 효과 절반씩 · 그 밖은 랭크와 같음",
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
static var rx_mul := RX_MUL  # 2026-10-30에 채운 반응 65개(RxMore)의 피해·지속 피해 배율
const RX_MUL := 0.5
## 조합 효율 측정(2026-10-30, docs/combo-efficiency)으로 고친 수치. 온라인 패치 rules의 같은 키로 덮어쓴다.
const TUNE := {
	"wood_cap": 3.0,  # 나무 부가효과(이 오브젝트가 주는 피해 +20%/레벨)가 세는 최대 레벨 (예전 상한 없음. 규칙 1은 99 = 상한 없음, apply)
	"mod_fix": 1.0,  # 강화 보정표(Pat.MOD_FIX) 세기: 1 = 표대로, 0 = 끔, 0.5 = 절반만
	"wind_buff": 0.08,  # 바람 부가효과: 둘레 다른 오브젝트 공격 속도 +/레벨 (예전 0.10, 조합 점수표 돕기 1위라 2026-10-31 사용자 요청)
	"clock_dmg": 0.9,  # 시계침 한 번 훑을 때 피해 (예전 1.2)
	"vortex_speed": 90.0,  # 블랙홀 날아가는 속도 (예전 140)
	"vortex_dmg": 1.5,  # 블랙홀 날아가는 동안 초당 피해, 다 줄면 2배 (예전 0.8)
	"vortex_end": 3.0,  # 블랙홀 붕괴 피해 (예전 2.0)
	"gust_push_lv": 2.0,  # 돌풍 옆으로 미는 힘이 세는 최대 레벨 (예전 상한 없음: 밀어낸 구체를 다음 돌풍이 못 맞힘)
	"sound_cd": 1.0,  # 소리 울림 음파: 같은 구체에 다시 터질 때까지
	"sound_pulse": 1.2,  # 소리 울림 음파 피해
	"sound_rate": 3.0,  # 오브젝트 하나가 터뜨리는 울림 음파 초당 최대 (예전 상한 없음: 많이 맞히는 공격방식과 섞이면 3~6배)
	"loud_mul": 1.2,  # 울림 균열 위 구체의 음파 피해 배율 (예전 1.5)
	"strip_ring": 0.2,  # 땅+소리 울림 균열·물+소리 메아리 물결 띠가 쌓는 울림 (예전 1.0, 반응 중앙값의 4~8배이던 것)
	"prison_iv": 5.0,  # 빙결 감옥 얼음 덩이 간격 (예전 7초)
	"prison_dmg": 3.0,  # 빙결 감옥 가둘 때 피해 (예전 2.0)
	"styx_dmg": 1.5,  # 망자의 강 물길 초당 피해 (예전 1.0)
	"wall_dmg": 3.0,
	"dice_mid": 1.3,  # 주사위 강화 4~5 배율 (2026-10-30 도박 특성, 시험)
	"dice_top": 2.2,  # 주사위 강화 6(대박) 배율  # 벽 바위에 막힌 동안 초당 피해 (예전 4.0, 빈 앞자리를 다시 채우게 고치며 낮춤)
	# 판마다 다른 흐름 (2026-10-31, 시험, scripts/vary.gd)
	"vary_on": 1.0,  # 0이면 봉인·이벤트·적응 모두 끔
	"vary_seal_elem": 3.0, "vary_seal_pat": 4.0, "vary_seal_link": 1.0,  # 판 시작 때 봉인하는 수
	"vary_event_every": 10.0,  # 웨이브 이벤트 주기
	"vary_event_k": 0.4,  # 이벤트 속성·공격방식 피해 +/- (도파민 모드 x1.5)
	"vary_adapt_from": 30.0,  # 적응 구체가 시작하는 웨이브
	"vary_adapt_step": 0.02,  # 웨이브마다 1위 저항 +, 나머지 -
	"vary_adapt_max": 0.2,  # 적응 저항 최대 (오브젝트 피해 기준, 2026-10-31 사용자 "20%까지만 일단")
	# 협동 짧은 판 (2026-10-31 사용자 "난이도가 올라가는 폭을 대폭, 금방금방 한 판 끝내는 형식"). Main.coop_hp_k
	"coop_orb_per": 0.6,  # 한 사람 늘 때마다 구체 수 + (2명 x1.6, 3명 x2.2, 4명 x2.8)
	"coop_hp_per": 1.0,  # 한 사람 늘 때마다 구체 체력 + (2명 x2, 3명 x3, 4명 x4)
	"coop_ramp": 1.28,  # 웨이브마다 구체 체력 x (곱, 웨이브 1은 x1). 봇 근사 12판씩: 2·3·4명 모두 중간값 9~10웨이브, 게임 시간 4~7분
	# 멀티 잠수·대결 보낸 구체 (2026-10-31 사용자 승인 "전부 다 처리")
	"mp_wait": 45.0,  # 협동: 누군가 [웨이브 시작]을 누른 뒤 남은 사람이 고를 시간(초), 지나면 대신 골라 준비
	"mp_wait_force": 15.0,  # 협동 호스트: 그 뒤로도 안 오면(응답 없는 기기) 이만큼 더 기다리고 시작
	"mp_afk_after": 2.0,  # 협동: 연속 이만큼 대신 고르면 자리 비움 (다음부터 기다리지 않음)
	"vs_idle": 90.0,  # 대결: 쉬는 시간이 이만큼(초) 이어지면 대신 고르고 웨이브 시작
	"vs_idle_out": 3.0,  # 대결: 연속 이만큼 저절로 시작하면 탈락
	"vs_send3": 0.7, "vs_send4": 0.5,  # 대결: 살아 있는 인원 3명·4명 이상일 때 보내는 구체 수 배율 (2명 1.0)
	"vs_recv_cap": 1.5,  # 대결: 한 웨이브에 받는 구체 상한 = (1 + 웨이브/4) x 이 값, 넘치면 다음 사람에게
	# 맵별 규칙·친화 카드 (2026-10-31, 시험, scripts/maprule.gd)
	"map_on": 1.0,  # 0이면 맵 규칙·친화 카드 모두 끔
	"map_aff_w": 1.5,  # 친화 카드가 나오는 비중 (다른 카드 1)
	"map_aff_dmg": 0.15,  # 친화 속성(레벨 몫)·공격방식 피해 +
	"map_crowd": 2.0,  # 평원: 무리 보너스 배율
	"map_reso": 0.3,  # 평원: 공명 거리 +
	"map_spiral_in": 1.4, "map_spiral_out": 0.8,  # 소용돌이: 중앙·바깥 구체 속도 배율
	"map_cross_dmg": 0.25,  # 십자로: 길 위에서 길 따라 겨눈 오브젝트 피해 +
	"map_wind_with": 0.3, "map_wind_against": 0.15,  # 폭풍: 순풍 탄 속도·사거리 +, 역풍 -
	"map_line_trail": 2.0,  # 회랑: 지나간 자리 장판 지속 배율
	"map_line_cc": 0.3,  # 회랑: 감속·밀치기 세기 +
	# 후반 난이도 (2026-10-31 사용자 "600웨이브쯤이 한계로"): Main.hp_growth·count_k·orb_base_speed·wave_size
	"hp_late_from": 150.0,  # 이 웨이브까지 체력 x hp_growth(1.05), 그 뒤는 x hp_growth_late
	"hp_growth_late": 1.03,  # 봇으로 맞춤
	"orb_n_cap_w": 150.0,  # 구체 수가 이 웨이브 수(303개)에서 멈춤, 넘는 몫은 체력으로
	"orb_spd_cap_w": 450.0,  # 구체 기본 속도(30+3w)가 이 웨이브 값(1,380)에서 멈춤
	# 후반 구체 (2026-10-31 사용자 "100·175·250·350·500웨이브에 하나씩", Orb.late, Main._late_trait)
	"late_blink_from": 100.0, "late_armor_from": 175.0, "late_heal_from": 250.0, "late_phase_from": 350.0, "late_devour_from": 500.0,
	"late_share": 0.08, "late_share_step": 0.01, "late_share_max": 0.2,  # 처음 비율, 10웨이브마다 +, 최대 (종류마다)
	"late_blink_iv": 3.5, "late_blink_dist": 90.0,  # 깜빡: 순간이동 간격(초)·거리(px)
	"late_armor": 0.04, "late_armor_break": 0.02, "late_armor_floor": 0.5, "late_armor_min": 0.3,  # 갑옷: 그 웨이브 구체 체력 대비, 타격당 깨짐, 최소 남는 갑옷, 최소 들어가는 피해
	"late_heal_iv": 2.5, "late_heal_r": 120.0, "late_heal": 0.06, "late_heal_max": 4.0,  # 치유: 간격·반경·최대 체력 대비 회복·웨이브당 최대 수
	"late_phase_on": 2.5, "late_phase_off": 1.5, "late_phase_dmg": 0.3,  # 흐림: 실체·흐림 시간, 흐릴 때 직접 피해 배율
	"late_devour_n": 2.0, "late_devour_take": 0.5, "late_devour_core": 5.0,  # 포식: 웨이브당 수, 삼킨 체력 비율, 중앙 피해 최대
	# 중앙 기술 (2026-10-31 사용자 "디펜스 한계 개선 A", Skill): 웨이브 중에 쓰는 기술 2칸, 쿨다운은 게임 시간(웨이브 시작마다 다시 참)
	"skill_on": 1.0,  # 0이면 기술 버튼이 안 나옴
	"skill_focus_t": 6.0, "skill_focus_spd": 2.0, "skill_focus_cd": 25.0,  # 집중: 오브젝트 하나 공격 속도 배율·지속·다시 쓰기
	"skill_hold_r": 120.0, "skill_hold_t": 2.0, "skill_hold_cd": 30.0,  # 붙잡기: 반경 안 구체 멈춤(기절 한계·보스 절반 따름)
	"skill_brand_r": 150.0, "skill_brand_amp": 0.3, "skill_brand_t": 5.0, "skill_brand_cd": 20.0,  # 낙인: 반경 안 구체 받는 피해 +
	"skill_cool_perk": 0.2,  # 특성 '빠른 손': 겹칠 때마다 다시 쓰기 시간 x(1-값)
	# 방해 구체 (2026-10-31 "디펜스 한계 개선 B", Orb.jam): 오브젝트를 잠깐 멈추거나 느리게만 (오브젝트 체력은 없음)
	"jam_on": 1.0,
	"jam_shade_from": 20.0, "jam_leech_from": 30.0, "jam_seeker_from": 40.0,  # 등장 웨이브 (그림자·흡수·표적)
	"jam_share": 0.05, "jam_share_step": 0.01, "jam_share_max": 0.12,  # 종류마다 처음 비율, 10웨이브마다 +, 최대
	"jam_shade_r": 80.0, "jam_shade_t": 1.5,  # 그림자: 지나가며 이 거리 안 오브젝트 공격 멈춤 시간
	"jam_imm": 4.0,  # 멈춤이 풀린 뒤 같은 오브젝트가 다시 멈추지 않는 시간
	"jam_leech": 0.05, "jam_leech_max": 5.0, "jam_leech_t": 4.0, "jam_leech_free": 300.0,  # 흡수: 맞힐 때마다 공격 속도 -, 최대 겹침, 유지, 죽으면 이 거리 안 오브젝트 풀림
	"jam_seek_t": 3.0, "jam_seek_spd": 1.15,  # 표적: 가장 가까운 오브젝트로 와서 닿으면 그 오브젝트 멈춤 시간, 속도 배율
	# 기맥 (2026-10-31 "디펜스 한계 개선 F", main.ley): 판마다 전장에 생기는 자리, 그 위 오브젝트 피해 +
	"ley_on": 1.0, "ley_n": 3.0, "ley_r": 40.0, "ley_dmg": 0.15,
}

## 오브젝트·강화·속성·연계·발동 수치 (2026-10-31 사용자 요청 "공격력·사거리·공격속도 등 모든 옵션을 서버에서 임의 수정").
## 온라인 패치 rules의 같은 키로 덮어쓴다 (TUNE과 같은 길). 값은 지금 게임과 같다. 키 설명은 server/README.md.
const STAT := {
	# 공격방식 레벨·피해 배율
	"lv_dmg": 0.5,  # 공격방식 레벨마다 피해 +
	"lv_spd": 0.2,  # 공격방식 레벨마다 공격 속도 +
	"lv_reach": 0.1,  # 공격방식 레벨마다 사거리 +
	"dmg_base": 1.43,  # 모든 오브젝트 기본 피해 배율 (2026-10-31 1.3 → 1.43, 사용자 "모든 속성 기본 공격력 +10%")
	"dmg_sum": 0.35,  # 속성 레벨 합 1 늘 때마다 피해 + (반응 제외)
	"shot_range": 400.0,  # 직선탄 사거리
	"shot_range_lv": 50.0,  # 속성 레벨 합 1 늘 때마다 직선탄 사거리 +
	# 강화
	"multi_dmg": 0.55,  # 다중 발사 한 발 피해 (1개)
	"multi_decay": 0.15,  # 다중 발사 더 쌓을 때마다 한 발 피해 나누는 몫
	"multi_angle": 0.22,  # 다중 발사 탄 사이 각도(라디안)
	"split_ch": 0.12,  # 분열 1개마다 파편 확률
	"split_max": 0.6,  # 분열 확률 최대
	"split_dmg": 0.5,  # 분열 파편 피해 (파편 기본의 배)
	"size_k": 0.12,  # 크기 1개마다 크기·범위·사거리 +
	"size_dmg": 0.04,  # 크기 1개마다 탄 쏘는 공격 피해 +
	"rapid_k": 0.1,  # 속사 1개마다 공격 속도 +
	"pierce_hit": 0.5,  # 관통: 뚫고 나간 탄 피해 배율
	"pierce_dmg": 0.06,  # 관통: 탄이 아닌 공격 피해 +
	"bounce_hit": 0.4,  # 튕김: 튕긴 탄 피해 배율
	"bounce_dmg": 0.04,  # 튕김: 탄·번개가 아닌 공격 피해 +
	"homing_k": 0.8,  # 유도: 휘는 힘
	# 속성 부가효과
	"fire_dps": 0.8, "fire_t": 2.0,  # 화상 초당 피해/레벨, 시간
	"poison_dps": 0.5, "poison_t": 4.0,  # 중독 초당 피해/레벨, 시간
	"wood_dmg": 0.2,  # 가시: 주는 피해 +/레벨
	"water_slow": 0.8, "water_t": 0.8,  # 감속 배율(낮을수록 느림), 시간
	"elec_ch": 0.3, "elec_dmg": 0.5,  # 전류 확률, 피해(맞힌 피해 대비/레벨)
	"wind_range": 240.0,  # 바람 버프 둘레 (버프 세기는 wind_buff)
	"ice_chill": 0.6,  # 냉기 쌓는 양/레벨
	"earth_ch": 0.2, "earth_max": 0.7, "earth_t": 0.8,  # 기절 확률/레벨, 최대, 시간
	"dark_vuln": 0.3, "dark_t": 2.0,  # 받는 피해 +, 시간
	"light_ch": 0.12, "light_max": 0.6, "light_mul": 2.0,  # 치명타 확률/레벨, 최대, 배율
	"metal_dmg": 0.4, "metal_stagger": 4.0,  # 추가 피해/레벨, 경직
	"sound_t": 3.0,  # 울림 지속
	"time_base": 0.15, "time_lv": 0.05, "time_max": 0.4, "time_t": 2.0,  # 메아리 비율 기본, +/레벨, 최대, 시간
	"soul_t": 3.0, "soul_base": 0.2, "soul_lv": 0.1, "soul_max": 0.6,  # 넋 시간, 혼불 확률 기본, +/레벨, 최대
	# 연계
	"reso_k": 0.12, "reso_r": 150.0,  # 공명: 가까운 오브젝트 하나당 피해 +, 거리
	"prism_dmg": 0.2,  # 프리즘: 지나간 탄 피해 +
	"pincer_t": 3.0, "pincer_cd": 1.5,  # 협공: 함께 맞힌 시간, 한 구체 다시 터질 때까지 (폭발 세기는 pincer_frac)
	# 발동
	"trig_max": 5.0,  # 발동 카드 종류마다 최대
	"echo_n": 3.0, "echo_dmg": 0.8, "echo_cd": 0.5,  # 여진 탄 수(+1/장), 탄 피해, 다시 터질 때까지
	"van_spd": 2.0, "van_t": 5.0, "van_t_add": 2.5,  # 선봉 공격 속도 배율, 지속, +/장
	"charge_r": 220.0, "charge_k": 1.0,  # 축적: 처치를 세는 거리, 강타 피해 배율(표 x이 값)
	"third_k": 1.0, "third_size": 1.3,  # 삼연: 3번째 공격 피해 배율(표 x이 값), 탄 크기
	"finish_hp": 0.3, "finish_mul": 1.6, "finish_add": 0.3,  # 마무리: 체력 이만큼 아래, 피해 배율, +/장
	# 별: 둘레 거리, 다른 오브젝트 피해 복사 비율(+/레벨), 자기 피해 비율, 별만 든 오브젝트 배율,
	# 초신성까지 필요한 별빛(이번 웨이브 구체 체력 x), 초신성 피해(별빛 x), 별 반응 따라붙는 피해(초신성 x)
	# 행성(별 + 속성 하나)은 둘레 피해 중 자기 속성 몫만 planet_take로 모은다. 같은 행성은 한 판에 하나, 행성은 planet_max개까지, 별이 든 오브젝트(별·행성 합쳐)는 star_max개까지
	"star_r": 220.0, "star_take": 0.10, "star_lv": 0.03, "star_self": 0.2, "star_pure": 1.5, "planet_take": 0.30, "planet_max": 3.0, "star_max": 3.0,
	"star_need": 8.0, "star_mul": 3.0, "star_rx": 0.3,
	# 보스는 초신성 한 번(행성 효과·시간의 행성 한 번 더 포함)에 최대 체력의 star_boss_cap만큼만 깎인다 (2026-10-31: 다 찬 별 하나면 보스 즉사)
	"star_boss_cap": 0.15,
	"answer_r": 220.0, "answer_cd": 0.6, "answer_dmg": 0.6, "answer_add": 0.15,  # 호응: 거리, 다시 쏠 때까지, 피해(직선탄 한 발 대비), +/장
}


## TUNE + STAT + 공격방식마다 dmg_/spd_/range_<id>(배율 1) + 반응마다 rxd_<id>(피해 배율 1).
static func defaults() -> Dictionary:
	var d := TUNE.merged(STAT)
	for id in Pat.ALL_IDS:
		for p in ["dmg_", "spd_", "range_"]:
			d[p + id] = 1.0
	for r in Elem.REACTIONS:
		d["rxd_" + r["id"]] = 1.0
	return d


static var DEFAULTS := defaults()
static var tune := DEFAULTS.duplicate()
## 자주 읽는 값(맞힐 때마다 등)은 tune 사전 대신 이 변수로 읽는다 (apply 끝에 _cache). 사전 찾기가 한 번 맞힐 때 열 번 넘게 돌아 후반 렉이 늘던 것
static var lv_dmg: float = STAT["lv_dmg"]
static var lv_spd: float = STAT["lv_spd"]
static var lv_reach: float = STAT["lv_reach"]
static var rapid_k: float = STAT["rapid_k"]
static var size_k: float = STAT["size_k"]
static var size_dmg: float = STAT["size_dmg"]
static var fire_dps: float = STAT["fire_dps"]
static var fire_t: float = STAT["fire_t"]
static var poison_dps: float = STAT["poison_dps"]
static var poison_t: float = STAT["poison_t"]
static var ice_chill: float = STAT["ice_chill"]
static var water_slow: float = STAT["water_slow"]
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
static var split_ch: float = STAT["split_ch"]
static var split_max: float = STAT["split_max"]
static var multi_dmg: float = STAT["multi_dmg"]
static var multi_decay: float = STAT["multi_decay"]
static var multi_angle: float = STAT["multi_angle"]
static var wood_cap: float = TUNE["wood_cap"]
static var dice_top: float = TUNE["dice_top"]
static var pierce_hit: float = STAT["pierce_hit"]
static var bounce_hit: float = STAT["bounce_hit"]
static var homing_k: float = STAT["homing_k"]
static var prism_dmg: float = STAT["prism_dmg"]
static var pincer_t: float = STAT["pincer_t"]
static var late_armor_break: float = TUNE["late_armor_break"]
static var late_armor_floor: float = TUNE["late_armor_floor"]
static var late_armor_min: float = TUNE["late_armor_min"]
static var late_phase_on: float = TUNE["late_phase_on"]
static var late_phase_dmg: float = TUNE["late_phase_dmg"]
static var rxd := {}  # "rx:<반응 id>" → 피해 배율 (1이 아닌 것만)


static func _cache() -> void:
	lv_dmg = tune["lv_dmg"]
	lv_spd = tune["lv_spd"]
	lv_reach = tune["lv_reach"]
	rapid_k = tune["rapid_k"]
	size_k = tune["size_k"]
	size_dmg = tune["size_dmg"]
	fire_dps = tune["fire_dps"]
	fire_t = tune["fire_t"]
	poison_dps = tune["poison_dps"]
	poison_t = tune["poison_t"]
	ice_chill = tune["ice_chill"]
	water_slow = tune["water_slow"]
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
	split_ch = tune["split_ch"]
	split_max = tune["split_max"]
	multi_dmg = tune["multi_dmg"]
	multi_decay = tune["multi_decay"]
	multi_angle = tune["multi_angle"]
	wood_cap = tune["wood_cap"]
	dice_top = tune["dice_top"]
	pierce_hit = tune["pierce_hit"]
	bounce_hit = tune["bounce_hit"]
	homing_k = tune["homing_k"]
	prism_dmg = tune["prism_dmg"]
	pincer_t = tune["pincer_t"]
	late_armor_break = tune["late_armor_break"]
	late_armor_floor = tune["late_armor_floor"]
	late_armor_min = tune["late_armor_min"]
	late_phase_on = tune["late_phase_on"]
	late_phase_dmg = tune["late_phase_dmg"]
	rxd.clear()
	for r in Elem.REACTIONS:
		var v: float = tune["rxd_" + r["id"]]
		if v != 1.0:
			rxd["rx:" + r["id"]] = v


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
	rx_mul = RX_MUL
	tune = DEFAULTS.duplicate()
	match version:
		1:
			tune["wood_cap"] = 99.0  # 같은 속성 레벨이 무제한인 규칙이라 상한을 두면 후반이 크게 어려워짐 (봇 81~100웨이브 누수 70% → 상한 3: 86%, 6·10: 80%)
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
	_cache()


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
		if DEFAULTS.has(k):
			tune[k] = maxf(0.0, float(v))
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
			"rx_mul": rx_mul = maxf(0.0, float(v))
