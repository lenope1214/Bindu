class_name Tower
extends Node2D
## 설치형 오브젝트. 설치 시 정한 방향으로 공격한다.
## - 공격방식(pattern): 형태. 하나만 갖고, 새 오브젝트는 직선탄.
## - 속성(elements): 효과. 모든 공격에 부가효과가 붙는다. 종류 수 상한은 Rules.max_elems.
## - 강화(mods): 공격방식에 붙는 변형. 종류마다 Rules.max_mod개까지.
## - 연계: 협공, 프리즘, 공명.
## - 발동(trigs): 조건이 맞을 때 추가로 터지는 공격 (여진, 선봉).

const RADIUS := 18.0

var elements := {}  # 속성 -> 겹친 수(=그 속성 레벨)
var order: Array[int] = []  # 넣은 순서
var pattern := Pat.DEFAULT
var plv := 1  # 공격방식 레벨
var mods := {}  # 강화 id -> 겹친 수
var prism := 0
var prism_flash := 0.0  # 탄이 지나간 순간 프리즘이 번쩍인다 (표시용)
var pincer := 0  # 협공: 여러 오브젝트가 함께 맞힌 구체에 표식 폭발
var reso := 0
var trigs := {}  # 발동 id -> 겹친 수
var echo_cd := 0.0  # 여진: 다시 터질 때까지
var van_ready := false  # 선봉: 이번 웨이브에 아직 안 켜짐 (웨이브 시작 때 켜고, 처음 맞히면 발동)
var van_t := 0.0  # 선봉: 공격 속도 x2 남은 시간
var wind_buff := 0.0  # 둘레 바람 오브젝트가 주는 공격 속도 (main이 매 계산마다 정함)
var eff := {}  # 지금 쓰는 속성 (매 프레임 갱신)
var dir := Vector2.RIGHT
var aim := Vector2.RIGHT  # 유도 강화로 살짝 돈 실제 공격 방향
var cd := {}  # 공격별 쿨다운
var fx := {}  # 공격별 이펙트 남은 시간
var t := 0.0
var dealt := 0.0  # 이번(또는 지난) 웨이브에 준 피해
var rx_dealt := 0.0  # 그중 특수 반응 피해 (측정·표시용)
var trail_hit := {}  # 지나간 자리 장판: 구체 → 마지막으로 맞은 sim_id (띠가 겹쳐도 한 조각에 한 번)
var fx_a := 1.0  # 이 오브젝트 탄·장판 진하기 (피해 몫이 작을수록 옅게, main._soften_fx)
var run_dealt := 0.0  # 지난 웨이브들까지 합친 피해 (게임 오버 요약용)
## 피해 출처 (DPS 표·판 기록 통계). 키: "hit"(직접 타격, breakdown()이 배율별로 나눔), elem:fire, rx:lava, mod:split, link:pincer ...
var src := {}  # 이번(또는 지난) 웨이브, 날것
var chase_n := {}  # 구체 id -> 이 오브젝트의 유도·혼불 탄 몇 개가 쫓는지 (Projectile._chase)
var run_src := {}  # 지난 웨이브들까지, 나눈 값
var tag := ""  # 지금 피해를 어느 출처로 셀지 (반응·반응 발사체·분열 파편). 비면 "hit"
var recoil := 0.0  # 발사 반동
var place_pop := 0.0  # 설치·겹치기 순간 커졌다 줄어드는 연출
var rocks: Array = []
var mines: Array = []
var in_rx := false  # 지금 특수 반응 공격 중인지 (hit 피해 계산용)
var rail_dir := Vector2.RIGHT  # 레일건이 마지막으로 쏜 방향
var halo_cd := {}  # 광륜: 구체별 다시 맞힐 때까지 남은 시간
var vine_cd := {}  # 덩굴: 구체별 다시 묶을 때까지 남은 시간
var zaps: Array = []  # 감전 물길: 이번에 전류가 꽂힌 자리(로컬)
var clock_ph := 0.0  # 시계침 위상
var ring_t0 := 0.0  # 울림 음파 초당 상한: 이번 1초 구간 시작
var ring_n := 0  # 그 구간에 터뜨린 수
var clock_hit := {}  # 시계침: 이번 한 번 훑는 동안 맞힌 구체 ([바늘 번호, 구체] -> true, 다중 발사 바늘은 따로 센다)
var glint_d := Vector2.RIGHT  # 잔광: 1.2초 뒤 다시 쏠 방향
var rewind_q: Array = []  # 되감기 번개: 1초 뒤 다시 칠 구체들
var earth_rx := {}  # 맞힐 때 붙는 땅 반응 id → 레벨 (용암·독늪·모래시계). attack()마다 갱신
var bogs: Array = []  # 독늪 늪 (오브젝트당 BOG_MAX개까지)
var in_form := false  # 지금 형태 성질 효과를 주는 중인지 (자람·무게 보너스를 다시 받지 않게)
var fe_cd := 0.0  # 형태 성질 "끝" 효과 다시 쓸 때까지 (날아가는 공격)
var fe2 := 0.0  # 계속 공격하는 형태의 "끝" 효과 다시 쓸 때까지
var chain_end := Vector2.ZERO  # 연쇄 번개가 마지막으로 친 자리
## 2026-10-30에 채운 반응들 (RxMore)
var later: Array = []  # [남은 초, Callable]: 잠시 뒤 한 번 더 (시간 반응 등)
var rxfx: Array = []  # 즉시 효과 표시 (광선·파동)
var rxs := {}  # 반응별 상태 (전도 덩굴 대상, 진자 쿨다운)
var rx_trail_hit := {}  # 반응 띠 sub → {구체: sim_id} (같은 반응 띠가 겹쳐도 한 조각에 한 번)
var pend_ph := 0.0  # 진자 위상
var photo_t := 0.0  # 광합성: 공격 속도 증가 남은 시간
var photo_k := 0.0
var main: Node
## 그린 궤적: 갈래마다 오브젝트 기준 점 목록 (첫 점은 오브젝트 자리). 오브젝트를 옮기면 같이 옮겨진다.
var paths: Array = []
var dice_x := 1.0  # 주사위 강화: 다음 공격까지 직접 피해에 곱하는 배율 (roll_dice)
var dice_miss := 0  # 마지막 대박(6) 뒤로 굴린 수
var dice_t := 0.0  # 계속 공격하는 형태: 다음에 굴릴 때까지 남은 초
var path_i := 0  # 다음 탄이 갈 갈래
var path_q: Array = []  # 다중 발사: 같은 길로 조금 늦게 나갈 탄까지 남은 시간


func _ready() -> void:
	z_index = 1  # 공격 이펙트가 구체 위에 보이도록


func lv(e: int) -> int:
	return elements.get(e, 0)


func m(id: String) -> int:
	return mods.get(id, 0)


## 강화 효과량. 버전 3은 같은 강화를 쌓을수록 효과가 절반씩 준다 (1, 1.5, 1.75, ...).
func mf(id: String) -> float:
	var n := m(id)
	return 2.0 * (1.0 - pow(0.5, n)) if Rules.mod_decay else float(n)


## 개수로 쓰는 강화(다중·관통·튕김): 효과량의 소수 부분은 확률로 하나 더.
func mn(id: String) -> int:
	var f := mf(id)
	return int(f) + (1 if randf() < f - int(f) else 0)


## 형태 성질 세기: 속성 레벨, Lv3까지만 (몰아 넣기보다 나눠 넣기가 이득). Elem.TRAIT
func tk(e: int) -> float:
	return mini((eff if not eff.is_empty() else elements).get(e, 0), 3) * Rules.trait_mul


func total_level() -> int:
	var n := 0
	for e in order:
		n += lv(e)
	return n


## 반응이 91개라 매번 다 훑지 않고, 속성 종류가 바뀔 때만 다시 찾는다 (공격·그리기에서 조각마다 불렀다). 돌려준 배열은 고치지 말 것
var _rx: Array = []
var _rx_key := 0


func reactions() -> Array:
	var src: Dictionary = eff if not eff.is_empty() else elements
	var key := hash(src.keys())
	if key != _rx_key:
		_rx_key = key
		_rx = Elem.reactions_with(src)
	return _rx


# 특성(전역 강화) 배율. 새 판마다 main이 초기화한다.
static var dmg_mul := 1.0
static var spd_mul := 1.0
static var reach_mul := 1.0
static var tax_step := 0.1


## 쌓기 대가: 속성 종류 하나 늘 때마다 공격 속도 감소 (기본 15%, 버전 3은 25%).
func tax() -> float:
	return 1.0 + tax_step * (order.size() - 1)


## 바람 속성: 이 거리 안의 다른 오브젝트 공격 속도 +Rules wind_buff(8%)/바람 레벨. 한 오브젝트에는 가장 큰 바람 하나만.
const WIND_RANGE := 240.0
const SHADE_T := 3.0  # 어둠 형태 성질 그림자 표식 시간 (2026-10-31, 끌기 대신: 블랙홀과 겹치지 않게)


## 공격 속도 배율: 특성 × 속사 × 바람 버프 ÷ 속성을 겹친 대가 (모두 곱한다). 특수 반응 공격도 이 배율.
func spd_k() -> float:
	return spd_mul * (1.0 + 0.1 * mf("rapid")) * (1.0 + wind_buff) * (1.0 + (photo_k if photo_t > 0.0 else 0.0)) * van_k() / tax()


## 선봉이 켜져 있으면 공격 속도 배율.
func van_k() -> float:
	return VAN_SPD if van_t > 0.0 else 1.0


## 발동 카드 수.
func tg(id: String) -> int:
	return trigs.get(id, 0)


## 여진(echo): 탄 수 3(+1/장), 탄 피해(파편 기본의 배), 다시 터질 때까지.
## 선봉: 공격 속도 배율, 지속 5초(+2.5초/장).
const TRIG_MAX := 5  # 발동 카드는 종류마다 5장까지 (선봉을 끝없이 쌓으면 웨이브 내내 x2)
const ECHO_N := 3
const ECHO_DMG := 0.8
const ECHO_CD := 0.5
const VAN_SPD := 2.0
const VAN_T := 5.0
const VAN_T_ADD := 2.5


static func van_time(n: int) -> float:
	return VAN_T + VAN_T_ADD * (n - 1)


## 웨이브 시작 (main._start_wave).
func wave_begin() -> void:
	van_ready = tg("vanguard") > 0
	van_t = 0.0
	echo_cd = 0.0


## 투척 장판: 느린 탄이 날아간 길에 띠 장판이 남는다 (Zone.trail). 던지는 간격, 날아가는 거리(Lv1, reach 배율),
## 띠 반지름(Lv1, 레벨마다 +), 점마다 남는 시간, 띠 안의 구체에 초당 피해(Lv1).
const LOB_IV := 1.6
const LOB_RANGE := 420.0
const LOB_R := 30.0
const LOB_R_LV := 3.0
const LOB_LIFE := 2.5
const LOB_DPS := 3.4
## 빙결 감옥(얼음+어둠): 얼음 덩이가 날아간 길에 얼음 띠. 띠에 처음 닿은 구체를 멈추고 받는 피해 +50%.
const PRISON_IV := 7.0
const PRISON_RANGE := 300.0
const PRISON_R := 44.0
const PRISON_R_LV := 4.0
const PRISON_LIFE := 1.2
## 독버섯(독+나무): 버섯이 굴러가며 MUSH_GAP마다 지뢰를 떨군다 (오브젝트당 4+레벨 개까지).
const MUSH_IV := 2.5
const MUSH_RANGE := 270.0
const MUSH_GAP := 90.0
## 장작 반응(불+나무): 굴러간 길에 불 장판. 반응 피해라 _hurt + 화상.
const BURN_IV := 2.2
const BURN_RANGE := 320.0
const BURN_R := 32.0
const BURN_R_LV := 3.0
const BURN_LIFE := 3.0
const BURN_DPS := 4.5


static func lob_r(l: int) -> float:
	return LOB_R + LOB_R_LV * (l - 1)


## 공격방식 Lv1의 공격 간격(초). attack()과 같은 값. 분사는 계속 뿜어서 없음, 시계침은 한 번 훑는 시간.
const BASE_IV := {"shot": 0.5, "thorn": 0.35, "gust": 1.5, "shard": 0.9, "iron": 1.5, "stream": 1.0, "chain": 1.3,
	"wall": 4.0, "vortex": 5.0, "laser": 2.0, "lob": LOB_IV, "sonic": 1.0, "clock": 0.8, "wisp": 1.0, "path": 0.5}

## 공격방식 한 번 맞힐 때의 기본 피해(Lv1, 배율 전)와 설명. projectile.gd·zone.gd·attack()과 같은 값.
const BASE_HIT := {
	"shot": [2.4, "한 발"], "thorn": [0.85, "한 발, 모두 뚫음"], "gust": [2.2, "한 번, 모두 뚫음"],
	"shard": [3.0, "한 발, 파편 3개는 1.0씩"], "iron": [1.7, "한 발, 모두 뚫음"], "wisp": [4.0, "한 발"], "path": [2.4, "한 발"],
	"chain": [2.2, "한 번 튈 때"], "laser": [3.4, "한 번, 모두 뚫음"], "sonic": [2.6, "가까이, 끝에서는 절반"],
	"clock": [0.9, "한 번 훑을 때"], "vortex": [3.0, "터질 때, 날아가는 동안 초당 1.5~3.0"],
	"lob": [LOB_DPS, "지나간 띠 안 초당, 2.5초 남음"], "spray": [5.5, "초당, 계속 뿜음"], "stream": [3.0, "뿜는 동안 초당, 0.6초"],
	"wall": [3.0, "벽에 막힌 동안 초당"],
}


## 공격 간격(초, 공격 속도 배율까지). 분사는 0.
func attack_iv() -> float:
	return BASE_IV.get(pattern, 0.0) / spd(plv) / spd_k()


## 공격 속도 배율을 이루는 것들 [이름, 배율] (1이 아닌 것만).
func spd_parts() -> Array:
	var out := []
	if order.size() > 1:
		out.append(["속성 %d종" % order.size(), 1.0 / tax()])
	if m("rapid") > 0:
		out.append(["속사", 1.0 + 0.1 * mf("rapid")])
	if wind_buff > 0.0:
		out.append(["바람 버프", 1.0 + wind_buff])
	if spd_mul != 1.0:
		out.append(["특성", spd_mul])
	if van_t > 0.0:
		out.append(["선봉", VAN_SPD])
	return out


## 오브젝트 정보 한 줄: 최종 공격 속도·간격.
func spd_line() -> String:
	var k := spd_k()
	var pc := roundi((k - 1.0) * 100.0)
	var s := "공격 속도 x%.2f (%s%d%%)" % [k, "+" if pc >= 0 else "", pc]
	var iv := attack_iv()
	if iv > 0.0:
		s += " · %.2f초마다 (초당 %.2f번)" % [iv, 1.0 / iv]
	else:
		s += " · 계속 뿜음 (피해·추가 효과가 이만큼)"
	return s


## 공격 속도 배율 내역 ("속성 12종 ÷3.75 · 속사 x1.19"). 없으면 빈 문자열.
func spd_parts_text() -> String:
	var parts := PackedStringArray()
	for p in spd_parts():
		parts.append("%s %s%.2f" % [p[0], "÷" if p[1] < 1.0 else "x", 1.0 / p[1] if p[1] < 1.0 else p[1]])
	return " · ".join(parts)


## 사거리 (글자). draw_range·attack()과 같은 값.
func range_text() -> String:
	var l := plv
	var s := sz()
	match pattern:
		"shot": return "%d (속성 레벨 합이 오를수록 멀리)" % roundi(shot_range(total_level(), mf("size")) * (1.0 + 0.12 * tk(Elem.WIND)))
		"spray": return "%d" % roundi(200.0 * reach(l) * s)
		"stream": return "%d" % roundi(260.0 * reach(l) * s)
		"chain": return "%d (튀는 거리 %d)" % [roundi(280.0 * reach(l) * s), roundi(110.0 * s)]
		"gust": return "%d" % roundi(420.0 * s)
		"sonic": return "%d" % roundi(sonic_r(l))
		"clock": return "%d" % roundi(240.0 * reach(l) * s)
		"lob": return "%d 날아감 (지나간 띠 반지름 %d)" % [roundi(LOB_RANGE * reach(l)), roundi(lob_r(l) * s)]
		"vortex": return "약 420 날아감 (반지름 %d)" % roundi((100.0 + 10.0 * (l - 1)) * s)
		"wall": return "앞 %d~ (벽 %d개)" % [roundi(90.0 * reach(l)), 2 + roundi(mf("multi"))]
		"wisp": return "900 (구체를 쫓아감)"
		"path": return "그린 길 최대 %d (갈래 %d/%d)" % [roundi(Pat.path_len(plv)), paths.size(), Pat.path_branches(plv)]
		"shard": return "화면 끝까지 (파편 130)"
	return "화면 끝까지"


## Shift 상세 정보 [글자, 색].
func detail_lines() -> Array:
	var out := []
	var dim := Color(1, 1, 1, 0.65)
	var els: Dictionary = eff if not eff.is_empty() else elements
	var bh: Array = BASE_HIT.get(pattern, [1.0, ""])
	match pattern:  # Rules.tune(온라인 패치)로 바뀌는 값
		"clock": bh = [Rules.t("clock_dmg"), bh[1]]
		"wall": bh = [Rules.t("wall_dmg"), bh[1]]
		"vortex": bh = [Rules.t("vortex_end"), "터질 때, 날아가는 동안 초당 %.1f~%.1f" % [Rules.t("vortex_dmg"), 2.0 * Rules.t("vortex_dmg")]]
	var f := dmg_k(false)
	var one: float = bh[0] * pw(plv) * f
	var shots := 1.0 + mf("multi")
	var mk_on := m("multi") > 0 and not pattern in ["wall", "vortex", "lob"]  # 이 셋은 한 발 피해가 줄지 않는다
	if mk_on:
		one *= multi_k()
	if pattern == "spray" or pattern == "stream":
		one *= spd_k()  # 계속 뿜는 공격은 공격 속도만큼 초당 피해가 는다
	var wood: float = 1.0 + 0.2 * mini(els.get(Elem.WOOD, 0), int(Rules.t("wood_cap")))
	one *= wood
	var metal: float = 0.4 * els.get(Elem.METAL, 0)
	if pattern in ["spray", "stream", "lob", "wall"]:
		metal *= 3.0 * (spd_k() if pattern in ["spray", "stream"] else 1.0)  # 계속 때리는 공격은 초당 (hit의 k = 조각 시간 x3)
	out.append(["공격력: %.1f  (%s)" % [one + metal, bh[1]], Color(1, 0.9, 0.5)])
	var parts := PackedStringArray(["기본 %.2f" % bh[0], "공격방식 Lv%d x%.2f" % [plv, pw(plv)], "피해 배율 x%.2f" % f])
	if mk_on:
		parts.append("다중 발사 한 발 x%.2f" % multi_k())
	if wood > 1.0:
		parts.append("나무 x%.2f" % wood)
	if metal > 0.0:
		parts.append("금속 +%.1f" % metal)
	out.append(["  " + " · ".join(parts), dim])
	var fp := PackedStringArray()
	var tl := total_level()
	fp.append("기본 x1.30")
	if tl > 1:
		fp.append("레벨 합 %d x%.2f" % [tl, 1.0 + 0.35 * (tl - 1)])
	if main and main.towers.get_child_count() > 1:
		fp.append("오브젝트 수 x%.2f" % (1.0 + Rules.crowd_bonus(main.towers.get_child_count())))
	if dmg_mul != 1.0:
		fp.append("특성 x%.2f" % dmg_mul)
	out.append(["  피해 배율: " + " · ".join(fp) + " (공명·강화·패치 포함 x%.2f)" % f, dim])
	if shots > 1.0:
		out.append(["한 번에 %.2f개 (다중 발사)" % shots if pattern != "wall" else "벽 최대 %d개 (다중 발사)" % (2 + roundi(mf("multi"))), Color(1, 0.85, 0.45)])
	out.append([spd_line(), Color(0.6, 0.9, 1.0)])
	var sp := spd_parts_text()
	if sp != "":
		out.append(["  " + sp + " (모두 곱함)", dim])
	if BASE_IV.has(pattern):
		out.append(["  기본 간격 %.2f초 ÷ 공격방식 Lv%d x%.2f" % [BASE_IV[pattern], plv, spd(plv)], dim])
	out.append(["사거리: " + range_text(), Color(0.75, 1, 0.75)])
	var light: int = els.get(Elem.LIGHT, 0)
	if light > 0:
		out.append(["치명타: %d%% 확률로 피해 2배" % roundi(minf(0.12 * light, 0.6) * 100.0), Elem.COLORS[Elem.LIGHT]])
	var mp := PackedStringArray()
	if m("pierce") > 0:
		mp.append("관통 %.2f개" % mf("pierce") if pattern in Pat.PROJECTILE else "관통 피해 x%.2f" % (1.0 + 0.06 * mf("pierce")))
	if m("bounce") > 0:
		mp.append("튕김 %.2f번" % mf("bounce") if pattern in Pat.PROJECTILE or pattern == "chain" else "튕김 피해 x%.2f" % (1.0 + 0.04 * mf("bounce")))
	if m("split") > 0:
		mp.append("분열 %d%%" % roundi(minf(0.6, 0.12 * mf("split")) * 100.0))
	if m("size") > 0:
		mp.append("크기 x%.2f" % sz())
	if m("dice") > 0:
		mp.append("주사위 %d개 · 대박까지 최대 %d번" % [dice_n(), maxi(1, dice_pity() - dice_miss)])
	if not mp.is_empty():
		out.append(["강화: " + " · ".join(mp), Color(1, 0.85, 0.45)])
	return out


func wind_range() -> float:
	return WIND_RANGE * reach_mul


static func pw(l: int) -> float:
	return (1.0 + 0.5 * (l - 1)) * dmg_mul


static func spd(l: int) -> float:
	return 1.0 + 0.2 * (l - 1)


static func reach(l: int) -> float:
	return (1.0 + 0.1 * (l - 1)) * reach_mul


## 직선탄 사거리: 속성 레벨 합 n으로 늘어난다 (직선탄은 공격방식 레벨이 늘 1). 원거리 특성·크기 강화 포함, 바람(멀리)은 쏠 때 따로.
static func shot_range(n: int, size_n: float) -> float:
	return (400.0 + 50.0 * maxi(n - 1, 0)) * reach_mul * (1.0 + 0.12 * size_n)


## 크기 강화 배율.
func sz() -> float:
	return 1.0 + 0.12 * mf("size")


## 속성이 많을수록, 공명·관통 강화로 피해가 늘어난다.
## rx: 특수 반응 공격은 겹친 레벨 합 보너스를 받지 않는다 (반응은 자기 레벨로 강해짐).
## 한 오브젝트에 몰아 넣으면 반응 수 x 레벨 합으로 곱이 되던 문제를 막는다.
func dmg_factor(rx := false) -> float:
	var f := 1.3 * (1.0 if rx else 1.0 + 0.35 * (total_level() - 1))
	# 오브젝트 수 보너스: 설치된 오브젝트가 많을수록 모두 강해진다 (늘수록 덜 오름, Rules.crowd_bonus)
	if main:
		f *= 1.0 + Rules.crowd_bonus(main.towers.get_child_count())
	if reso > 0 and main:
		var near := 0
		for o in main.towers.get_children():
			if o != self and o.position.distance_to(position) < 150.0:
				near += 1
		f *= 1.0 + 0.12 * reso * near
	if m("pierce") > 0 and not pattern in Pat.PROJECTILE:
		f *= 1.0 + 0.06 * mf("pierce")
	if m("bounce") > 0 and not pattern in Pat.PROJECTILE and pattern != "chain":
		f *= 1.0 + 0.04 * mf("bounce")
	if m("size") > 0 and pattern in Pat.PROJECTILE:
		f *= 1.0 + 0.04 * mf("size")
	if not rx:
		f *= mod_fix_all()
	# 온라인 밸런스 패치: 공격방식·넣은 속성별 피해 배율
	if not Patch.pat_mul.is_empty():
		f *= Patch.pat_mul.get(pattern, 1.0)
	if not Patch.elem_mul.is_empty():
		for e in elements:
			f *= Patch.elem_mul.get(e, 1.0)
	return f


## hit용 피해 배율. 한 계산 조각 안에서는 변하지 않으니 조각마다 한 번만 계산한다
## (지속 공격은 조각마다 구체마다 hit을 부르고, 공명은 오브젝트 전체를 돈다).
var _dk := [0.0, 0.0]
var _dk_id := -1


func dmg_k(rx: bool) -> float:
	if main == null:
		return dmg_factor(rx)
	if _dk_id != main.sim_id:
		_dk_id = main.sim_id
		_dk = [dmg_factor(false), dmg_factor(true)]
	return _dk[1 if rx else 0]


## 직접 더하는 피해 (반응 지속 피해·전류·울림 등). key: src 키
func credit(d: float, key: String) -> void:
	dealt += d
	src[key] = src.get(key, 0.0) + d


## 이번(또는 지난) 웨이브 피해를 출처별로. 직접 타격("hit")은 배율로 나눈다(추정):
## 배율을 다 걷어 낸 기본 피해는 공격방식 몫, 배율이 늘린 나머지는 각 배율의 log 크기 비율로 나눈다
## (순서와 상관없이 합이 맞는다). 웨이브 끝·표시할 때만 부른다.
func breakdown() -> Dictionary:
	var out := {}
	for key in src:
		if key != "hit":
			out[key] = src[key]
	var h: float = src.get("hit", 0.0)
	if h <= 0.0:
		return out
	var fs := []  # [키, log 배율]
	var tl := total_level()
	if tl > 1:
		var lf := log(1.0 + 0.35 * (tl - 1))
		for e in elements:
			fs.append([elem_key(e), lf * lv(e) / tl])
	if lv(Elem.WOOD) > 0:
		fs.append(["elem:wood", log(1.0 + 0.2 * mini(lv(Elem.WOOD), int(Rules.t("wood_cap"))))])
	if main and main.towers.get_child_count() > 1:
		fs.append(["etc:crowd", log(1.0 + Rules.crowd_bonus(main.towers.get_child_count()))])
	if reso > 0 and main:
		var near := 0
		for o in main.towers.get_children():
			if o != self and o.position.distance_to(position) < 150.0:
				near += 1
		if near > 0:
			fs.append(["link:reso", log(1.0 + 0.12 * reso * near)])
	if m("pierce") > 0 and not pattern in Pat.PROJECTILE:
		fs.append(["mod:pierce", log(1.0 + 0.06 * mf("pierce"))])
	if m("bounce") > 0 and not pattern in Pat.PROJECTILE and pattern != "chain":
		fs.append(["mod:bounce", log(1.0 + 0.04 * mf("bounce"))])
	if m("size") > 0 and pattern in Pat.PROJECTILE:
		fs.append(["mod:size", log(1.0 + 0.04 * mf("size"))])
	if m("rapid") > 0:
		fs.append(["mod:rapid", log(1.0 + 0.1 * mf("rapid"))])
	if m("multi") > 0:
		fs.append(["mod:multi", log((1 + mn("multi")) * multi_k())])
	if dmg_mul * spd_mul > 1.0:
		fs.append(["etc:perk", log(dmg_mul * spd_mul)])
	for id in mods:  # 강화 보정표로 늘어난 몫은 그 강화로 (줄어든 몫은 0 이하라 아래에서 빠짐)
		fs.append(["mod:" + id, log(Pat.mod_fix(pattern, id, mf(id)))])
	var sum := 0.0
	for f in fs:
		if f[1] > 0.0:
			sum += f[1]
	var base := h / exp(sum)
	var pk := "pat:" + pattern
	out[pk] = out.get(pk, 0.0) + base
	for f in fs:
		if f[1] > 0.0:
			out[f[0]] = out.get(f[0], 0.0) + (h - base) * f[1] / sum
	return out


## 웨이브가 바뀔 때: 지난 웨이브 출처를 판 누적에 넣고 비운다.
func close_src() -> void:
	var b := breakdown()
	for key in b:
		run_src[key] = run_src.get(key, 0.0) + b[key]
	src.clear()


## 판 전체 출처 (누적 + 이번 웨이브).
func all_src() -> Dictionary:
	var out := run_src.duplicate()
	var b := breakdown()
	for key in b:
		out[key] = out.get(key, 0.0) + b[key]
	return out


static func elem_key(e: int) -> String:
	return "elem:" + Patch.ELEM_KEYS[Elem.ALL.find(e)]


## 대표 색: 속성 색을 레벨 비율로 섞는다.
func color() -> Color:
	if order.is_empty():
		return Color.WHITE
	var c := Color(0, 0, 0, 1)
	var tot := float(total_level())
	for e in order:
		var k := lv(e) / tot
		c.r += Elem.COLORS[e].r * k
		c.g += Elem.COLORS[e].g * k
		c.b += Elem.COLORS[e].b * k
	return c


## 속성을 겹친다. 결과 메시지를 돌려준다.
func add(e: int, n: int) -> String:
	var fresh := Elem.new_reactions(eff_now(), e)
	elements[e] = lv(e) + n
	if not order.has(e):
		order.append(e)
	place_pop = 1.0
	queue_redraw()
	if fresh.is_empty():
		return "%s Lv%d" % [Elem.NAMES[e], lv(e)]
	var names := PackedStringArray()
	for r in fresh:
		names.append(r["name"])
	return "반응: " + ", ".join(names)


## 이 카드를 넣을 수 있는지 (속성 종류·강화 종류별 상한, 공격방식 고정).
func can_take(card: Dictionary) -> bool:
	match card["type"]:
		"elem":
			return elements.has(card["e"]) or order.size() < Rules.max_elems
		"pat":
			return can_pattern(card["id"])
		"mod":
			return m(card["id"]) < Rules.max_mod and mod_useless(card["id"]).is_empty()
		"trig":
			return tg(card["id"]) < TRIG_MAX
	return true


## 버전 3(쌓을수록 절반): 이만큼 쌓으면 효과가 최대의 97%라 더 넣어도 거의 늘지 않는다.
const DECAY_FULL := 5


## 이 강화를 넣어도 효과가 없는 이유 (효과가 있으면 빈 문자열).
func mod_useless(id: String) -> String:
	var why := Pat.no_mod_why(pattern, id)
	if not why.is_empty():
		return why
	if Rules.mod_decay and m(id) >= DECAY_FULL:
		return "%s은(는) 효과가 거의 다 찼어요 (x%.2f / 최대 x2.00)" % [Pat.MODS[id]["name"], mf(id)]
	return ""


## 넣을 수 없는 이유 (넣을 수 있으면 빈 문자열).
func refuse_text(card: Dictionary) -> String:
	if can_take(card):
		return ""
	match card["type"]:
		"elem":
			return "속성은 %d종까지예요. 빈 곳에 놓아 새 오브젝트로 만드세요" % Rules.max_elems
		"pat":
			var bad := pattern_blockers(card["id"])
			if card["id"] == "path" and pattern == Pat.DEFAULT and path_full():
				return "%s은(는) 오브젝트 %d개까지예요. 이미 있는 궤적에 넣으면 레벨업" % [Pat.pname("path"), Pat.PATH_MAX]
			if not bad.is_empty():
				return "%s 강화가 들어 있어서 %s(으)로 바꿀 수 없어요 (효과가 없어져요)" % ["·".join(bad), Pat.pname(card["id"])]
			return "이 오브젝트는 %s(으)로 정해져 있어요. 같은 공격방식만 넣을 수 있어요" % Pat.pname(pattern)
		"mod":
			var why := mod_useless(card["id"])
			if not why.is_empty():
				return why
			return "%s은(는) %d개까지 쌓을 수 있어요" % [Pat.MODS[card["id"]]["name"], Rules.max_mod]
		"trig":
			return "%s은(는) %d개까지 쌓을 수 있어요" % [Pat.TRIGS[card["id"]]["name"], TRIG_MAX]
	return ""


## 이 공격방식을 넣을 수 있는지: 직선탄은 한 번 교체 가능, 정해진 뒤에는 같은 것(레벨업)만.
## 이미 든 강화가 그 공격방식에서 효과가 없어지면 바꿀 수 없다.
func can_pattern(id: String) -> bool:
	if id == "path" and pattern != "path" and path_full():
		return false
	return (pattern == Pat.DEFAULT or id == pattern) and pattern_blockers(id).is_empty()


## 그린 궤적 오브젝트가 이미 Pat.PATH_MAX개인지.
func path_full() -> bool:
	return main != null and main.towers.get_children().filter(func(t): return t.pattern == "path").size() >= Pat.PATH_MAX


## 이 공격방식으로 바꾸면 효과가 없어지는 이미 든 강화 이름들.
func pattern_blockers(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for k in mods:
		if m(k) > 0 and not Pat.mod_ok(id, k):
			out.append(Pat.MODS[k]["name"])
	return out


## 공격방식을 넣는다. 같은 것이면 레벨업, 직선탄이면 교체(이후 고정).
func set_pattern(id: String) -> String:
	if not can_pattern(id):
		return ""
	place_pop = 1.0
	cd.clear()
	fx.clear()
	queue_redraw()
	if id == pattern:
		plv += 1
		return "%s Lv%d" % [Pat.pname(id), plv]
	var old := pattern
	pattern = id
	plv = 1
	if id == "path":
		paths = [straight_path(dir)]
	return "%s → %s" % [Pat.pname(old), Pat.pname(id)]


## 아직 그리지 않은 갈래: 그 방향으로 곧은 길 (그릴 수 있는 길이만큼).
func straight_path(d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var L := Pat.path_len(plv)
	var n := ceili(L / 20.0)
	for i in n + 1:
		out.append(d * L * i / n)
	return out


## 그린 궤적 레벨업으로 새로 그릴 갈래 (Pat.path_branches보다 적으면 곧은 길을 하나 더 붙이고 그 번호, 아니면 -1).
func add_branch() -> int:
	if pattern != "path" or paths.size() >= Pat.path_branches(plv):
		return -1
	paths.append(straight_path(dir.rotated(0.5 * (1 if paths.size() % 2 == 1 else -1))))
	return paths.size() - 1


## 갈래 하나의 길이.
static func poly_len(pts: PackedVector2Array) -> float:
	var L := 0.0
	for i in range(1, pts.size()):
		L += pts[i].distance_to(pts[i - 1])
	return L


## 속성 대격변: 속성마다 무작위로 다시 뽑는다. 같은 속성이 나오면 레벨 +1.
func cataclysm_elements() -> void:
	var old := order.duplicate()
	var olds := elements.duplicate()
	elements.clear()
	order.clear()
	for e in old:
		var ne: int = Elem.ALL.pick_random()
		elements[ne] = lv(ne) + olds[e] + (1 if ne == e else 0)
		if not order.has(ne):
			order.append(ne)
	place_pop = 1.0
	queue_redraw()


## 공격방식 대격변: 직선탄을 뺀 공격방식 중 하나로 바뀐다(고정 무시). 레벨은 유지, 같은 것이면 +1.
func cataclysm_pattern() -> void:
	var id: String = Pat.PATTERN_IDS.slice(1).pick_random()
	if id == pattern:
		plv += 1
	else:
		pattern = id
		paths.clear()
	cd.clear()
	fx.clear()
	place_pop = 1.0
	queue_redraw()


func add_mod(id: String) -> String:
	mods[id] = m(id) + 1
	place_pop = 1.0
	queue_redraw()
	return "%s %d (%s)" % [Pat.MODS[id]["name"], m(id), mod_effect(id)]


## 지금 든 강화의 효과량 (detail_lines·dmg_factor·multi_k 등과 같은 식). 공격방식마다 다르다.
func mod_effect(id: String) -> String:
	var fx := Pat.mod_fix(pattern, id, mf(id))
	var t := _mod_effect(id)
	if absf(fx - 1.0) >= 0.005 and id != "dice":
		t += " · 이 공격방식 보정 피해 x%.2f" % fx
	return t


func _mod_effect(id: String) -> String:
	var f := mf(id)
	match id:
		"multi":
			if pattern == "wall":
				return "벽 최대 %d개" % (2 + roundi(f))
			if pattern in ["vortex", "lob"]:
				return "한 번에 %.2f개" % (1.0 + f)
			return "한 번에 %.2f개 (한 발 피해 %d%%)" % [1.0 + f, roundi(multi_k() * 100.0)]
		"split":
			return "파편 확률 %d%%" % roundi(minf(0.6, 0.12 * f) * 100.0)
		"homing":
			return "휘는 힘 x%.2f" % f
		"bounce":
			if pattern in Pat.PROJECTILE or pattern == "chain":
				return "튕김 %.2f번" % f
			return "피해 +%d%%" % roundi(0.04 * f * 100.0)
		"size":
			return "크기·범위·사거리 +%d%%" % roundi((sz() - 1.0) * 100.0) + (" · 피해 +%d%%" % roundi(0.04 * f * 100.0) if pattern in Pat.PROJECTILE else "")
		"rapid":
			return "공격 속도 +%d%%" % roundi(0.1 * f * 100.0)
		"pierce":
			if pattern in Pat.PROJECTILE:
				return "%.2f개 더 뚫음" % f
			return "피해 +%d%%" % roundi(0.06 * f * 100.0)
		"dice":
			return "주사위 %d개 · 대박 %d%% · 평균 피해 +%d%% · %d번 안에 대박" % [dice_n(), roundi((1.0 - pow(5.0 / 6.0, dice_n())) * 100.0), roundi((dice_avg() - 1.0) * 100.0), dice_pity()]
	return ""


func add_link(id: String) -> String:
	place_pop = 1.0
	queue_redraw()
	match id:
		"prism":
			prism += 1
		"reso":
			reso += 1
		"pincer":
			pincer += 1
	var n := link_lv(id)
	return Pat.LINKS[id]["name"] + ("" if n <= 1 else " x%d (%s %s)" % [n, LINK_POWER[id], link_value(id, n)])


func add_trig(id: String) -> String:
	place_pop = 1.0
	queue_redraw()
	trigs[id] = tg(id) + 1
	var n := tg(id)
	return Pat.TRIGS[id]["name"] + ("" if n <= 1 else " x%d (%s)" % [n, trig_value(id, n)])


## 발동 카드를 n장 넣었을 때의 세기 (hit의 여진·선봉과 같은 식).
static func trig_value(id: String, n: int) -> String:
	match id:
		"echo":
			return "탄 %d개" % (ECHO_N + n - 1)
		"vanguard":
			return "%.1f초" % van_time(n)
	return ""


## 지금 쓰는 속성 (예전 연결선은 여기서 이어진 오브젝트 속성을 더했다).
func eff_now() -> Dictionary:
	return elements.duplicate()


func title() -> String:
	var parts := PackedStringArray()
	for e in order:
		parts.append(Elem.NAMES[e] + ("" if lv(e) == 1 else str(lv(e))))
	return "%s%s · %s" % [Pat.pname(pattern), "" if plv == 1 else " Lv%d" % plv, "·".join(parts)]


## 강화·연계 요약 문구.
func extras_text() -> String:
	var parts := PackedStringArray()
	for id in Pat.MOD_IDS:
		if m(id) > 0:
			parts.append(Pat.MODS[id]["name"] + ("" if m(id) == 1 else " x%d" % m(id)))
	if prism > 0:
		parts.append("프리즘" + ("" if prism == 1 else " x%d" % prism))
	if reso > 0:
		parts.append("공명" + ("" if reso == 1 else " x%d" % reso))
	if pincer > 0:
		parts.append("협공" + ("" if pincer == 1 else " x%d" % pincer))
	for id in Pat.TRIG_IDS:
		if tg(id) > 0:
			parts.append(Pat.TRIGS[id]["name"] + ("" if tg(id) == 1 else " x%d" % tg(id)))
	return ", ".join(parts)


## 미리보기·사거리 표시에 쓰는 묶음.
func spec() -> Dictionary:
	return {"els": elements, "pat": pattern, "plv": plv, "mods": mods, "paths": paths}


## 이어하기 저장용.
func to_save() -> Dictionary:
	return {"elements": elements, "order": Array(order), "pattern": pattern, "plv": plv, "mods": mods,
		"prism": prism, "reso": reso, "pincer": pincer, "trigs": trigs, "pos": position, "dir": dir, "dealt": dealt, "run_dealt": run_dealt,
		"src": src, "run_src": run_src, "paths": paths.map(func(p): return Array(p))}


## 저장값으로 되살린다. 알 수 없는 속성·공격방식·강화나 형식이 다른 값은 버린다.
func load_save(d: Dictionary) -> void:
	var els: Variant = d.get("elements", {})
	var ord: Variant = d.get("order", [])
	if els is Dictionary and ord is Array:
		for e in ord:
			if e is int and e in Elem.ALL and els.get(e) is int and els[e] > 0 and not order.has(e):
				elements[e] = els[e]
				order.append(e)
	var p: Variant = d.get("pattern")
	if p is String and p in Pat.ALL_IDS:
		pattern = p
	plv = maxi(1, _int(d.get("plv")))
	var ms: Variant = d.get("mods", {})
	if ms is Dictionary:
		for id in ms:
			if Pat.MODS.has(id) and _int(ms[id]) > 0:
				mods[id] = _int(ms[id])
	prism = maxi(0, _int(d.get("prism")))
	reso = maxi(0, _int(d.get("reso")))
	pincer = maxi(0, _int(d.get("pincer")))
	var tgs: Variant = d.get("trigs", {})
	if tgs is Dictionary:
		for id in tgs:
			if Pat.TRIGS.has(id) and _int(tgs[id]) > 0:
				trigs[id] = _int(tgs[id])
	var pos: Variant = d.get("pos")
	if pos is Vector2:
		position = pos
	var dv: Variant = d.get("dir")
	if dv is Vector2 and dv.length() > 0.01:
		dir = dv.normalized()
	aim = dir
	dealt = maxf(0.0, _float(d.get("dealt")))
	run_dealt = maxf(0.0, _float(d.get("run_dealt")))
	src = _src_dict(d.get("src"))
	run_src = _src_dict(d.get("run_src"))
	paths.clear()
	var ps: Variant = d.get("paths", [])
	if pattern == "path" and ps is Array:
		for br in ps.slice(0, Pat.PATH_BRANCH_MAX):
			var pts := PackedVector2Array()
			if br is Array:
				for q in br.slice(0, 64):
					if q is Vector2 and q.is_finite():
						pts.append(q)
			if pts.size() >= 2:
				paths.append(pts)
	if pattern == "path" and paths.is_empty():
		paths.append(straight_path(dir))


static func _src_dict(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for key in v:
			if key is String and key.length() < 40 and _float(v[key]) > 0.0:
				out[key] = _float(v[key])
	return out


static func _int(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


static func _float(v: Variant) -> float:
	return float(v) if v is int or v is float else 0.0


# ---------- 공격 ----------

func _ready_to(key, interval: float, delta: float) -> bool:
	var v: float = cd.get(key, 0.0) - delta
	if v <= 0.0:
		cd[key] = interval
		recoil = 1.0
		if key == "p":
			roll_dice()
		return true
	cd[key] = v
	return false


## 주사위를 시간으로 굴리는 계속 공격 (그 밖의 공격은 쏠 때마다 _ready_to·연쇄 번개에서 굴린다)
const DICE_TIMED := ["spray", "clock"]
const DICE_PITY := [8, 7, 6, 5, 4]  # 장 수별: 이만큼 굴리는 동안 6이 없으면 다음은 6


## 주사위 강화: 굴려서 다음 공격까지 이 오브젝트의 직접 피해 배율을 정한다.
## 장 수만큼(3개까지) 굴려 높은 눈. 1~3은 그대로라 넣어서 약해지는 일은 없다.
func roll_dice() -> void:
	if m("dice") <= 0:
		dice_x = 1.0
		return
	var best := 1
	for i in dice_n():
		best = maxi(best, randi_range(1, 6))
	dice_miss += 1
	if best < 6 and dice_miss >= dice_pity():
		best = 6
	if best == 6:
		dice_miss = 0
		dice_x = Rules.t("dice_top")
		if main:
			main.burst(position, Color(1, 0.85, 0.3), 6, 90.0)
	else:
		dice_x = Rules.t("dice_mid") if best >= 4 else 1.0


func dice_n() -> int:
	return mini(m("dice"), 3)


func dice_pity() -> int:
	return DICE_PITY[clampi(m("dice"), 1, DICE_PITY.size()) - 1]


## 평균 배율 (대박 보장은 빼고 계산, 설명용)
func dice_avg() -> float:
	var n := dice_n()
	var lo := pow(0.5, n)  # 모두 3 이하
	var mid := pow(5.0 / 6.0, n)  # 모두 5 이하
	return lo + (mid - lo) * Rules.t("dice_mid") + (1.0 - mid) * Rules.t("dice_top")


## 다중 발사 방향들 (가운데 기준 0.22라디안 간격).
func dirs() -> Array:
	var n := 1 + mn("multi")
	var out := []
	for i in n:
		out.append(aim.rotated((i - (n - 1) / 2.0) * 0.22))
	return out


## 다중 발사면 공격 하나당 피해 55%, 더 쌓을수록 한 발은 조금씩 약해진다 (1개 x1.1, 3개 x1.7).
## 강화 보정표(Pat.MOD_FIX)를 넣은 강화 전부에 대해 곱한 값
func mod_fix_all() -> float:
	var f := 1.0
	for id in mods:
		f *= Pat.mod_fix(pattern, id, mf(id))
	return f


func multi_k() -> float:
	return 1.0 if m("multi") == 0 else 0.55 / (1.0 + 0.15 * (mf("multi") - 1.0))


## main이 웨이브 중 매 계산마다 호출한다.
func attack(delta: float, orbs: Array) -> void:
	t += delta
	eff = eff_now()
	earth_rx.clear()
	for r in reactions():
		if r["id"] in ["lava", "swamp", "hourglass"]:
			earth_rx[r["id"]] = mini(eff.get(r["a"], 1), eff.get(r["b"], 1))
	for k in fx.keys():
		fx[k] = maxf(fx[k] - delta, 0.0)
	recoil = maxf(recoil - delta * 6.0, 0.0)
	fe_cd = maxf(fe_cd - delta, 0.0)
	fe2 = maxf(fe2 - delta, 0.0)
	echo_cd = maxf(echo_cd - delta, 0.0)
	van_t = maxf(van_t - delta, 0.0)
	_update_aim(orbs, delta)
	# 속성을 많이 겹칠수록 공격이 느려진다(쌓기 대가), 속사 강화로 빨라진다
	var de := delta * spd_k()
	var k := de * 3.0  # 지속 공격의 부가효과 세기
	var l := plv
	var s := sz()
	var mk := multi_k()
	if pattern in DICE_TIMED and m("dice") > 0:
		dice_t -= de
		if dice_t <= 0.0:
			dice_t = 1.0
			roll_dice()
	match pattern:
		"shot", "thorn", "gust", "shard", "iron":
			if _ready_to("p", BASE_IV[pattern] / spd(l), de):
				for d in dirs():
					var pr: Projectile = main.spawn_proj(self, pattern, l, d)
					pr.dmg *= mk  # 다중 발사: 한 발 피해 감소
					pr.form_init()
		"spray":
			for d in dirs():
				_cone(orbs, d, 200.0 * reach(l) * s, 0.35, func(o): hit(o, 5.5 * pw(l) * de * mk, k))
		"stream":
			if _ready_to("p", 1.0 / spd(l), de):
				fx["stream"] = 0.6
			if fx.get("stream", 0.0) > 0.0:
				for d in dirs():
					_line(orbs, d, 260.0 * reach(l) * s, 10.0 * s, func(o):
						hit(o, 3.0 * pw(l) * de * mk, k)
						o.stagger(60.0 * de))
		"chain":
			if cd.get("p", 0.0) > 0.0:
				cd["p"] -= de
			else:
				var fired := false
				var used := {}
				for d in dirs():
					fired = _chain(orbs, d, l, used) or fired
				if fired:
					cd["p"] = 1.3 / spd(l)
					roll_dice()
					recoil = 1.0
					if fe2 <= 0.0:
						fe2 = 2.0
						form_end(chain_end, aim, true)
		"wall":
			rocks = rocks.filter(func(r): return is_instance_valid(r))
			if _ready_to("p", 4.0 / spd(l), de) and rocks.size() < 2 + roundi(mf("multi")):
				main.spawn_rock(self, l)
		"vortex":
			# 앞으로 날아가며 작아지는 블랙홀 (Zone.launch)
			if _ready_to("p", 5.0 / spd(l), de):
				for d in dirs():
					main.spawn_zone("vortex", l, position + d * RADIUS, self).launch(d)
		"laser":
			if _ready_to("p", 2.0 / spd(l), de):
				fx["laser"] = 0.3
				for d in dirs():
					_line(orbs, d, 2000.0, 14.0 * s, func(o): hit(o, 3.4 * pw(l) * mk))
		"lob":
			if _ready_to("p", LOB_IV / spd(l), de):
				for d in dirs():
					main.spawn_proj(self, "blob", l, d).form_init()
		"sonic":
			# 부채꼴로 퍼지는 파동: 안의 구체를 모두 치고, 멀수록 약하다 (끝에서 50%)
			if _ready_to("p", 1.0 / spd(l), de):
				fx["sonic"] = 0.35
				var R := sonic_r(l)
				for d in dirs():
					_cone(orbs, d, R, 0.5, func(o):
						hit(o, 2.6 * pw(l) * mk * (1.0 - 0.5 * minf(o.position.distance_to(position) / R, 1.0))))
		"clock":
			# 바늘이 앞쪽 ±0.7라디안을 왕복한다. 한 번 훑을 때마다 같은 구체는 한 번씩
			var was := cos(clock_ph) >= 0.0
			clock_ph += de * spd(l) * TAU / 1.6
			if (cos(clock_ph) >= 0.0) != was:
				clock_hit.clear()
			var ds := dirs()
			for i in ds.size():
				_line(orbs, ds[i].rotated(clock_a()), 240.0 * reach(l) * s, 10.0 * s, func(o):
					var key := [i, o]
					if not clock_hit.has(key):
						clock_hit[key] = true
						hit(o, Rules.t("clock_dmg") * pw(l) * mk))
		"wisp":
			if _ready_to("p", 1.0 / spd(l), de):
				for d in dirs():
					var pr: Projectile = main.spawn_proj(self, "wisp", l, d)
					pr.dmg *= mk
					pr.form_init()
		"path":
			# 갈래를 번갈아 쓰고, 다중 발사는 같은 길로 조금씩 늦게 나간다
			for i in range(path_q.size() - 1, -1, -1):
				path_q[i][0] -= de
				if path_q[i][0] <= 0.0:
					_fire_path(path_q[i][1], mk)
					path_q.remove_at(i)
			if not paths.is_empty() and _ready_to("p", BASE_IV["path"] / spd(l), de):
				var br := path_i % paths.size()
				path_i += 1
				_fire_path(br, mk)
				for i in mn("multi"):
					path_q.append([PATH_GAP * (i + 1), br])
	_cont_end(orbs, l, s)
	_reactions(orbs, de, k)
	queue_redraw()


const PATH_GAP := 0.08  # 다중 발사 탄 사이 시간(초)


func _fire_path(br: int, mk: float) -> void:
	if br >= paths.size():
		return
	var pts: PackedVector2Array = paths[br]
	var g := PackedVector2Array()
	for q in pts:
		g.append(position + q)
	var pr: Projectile = main.spawn_proj(self, "path", plv, (pts[1] - pts[0]).normalized())
	pr.set_route(g)
	pr.dmg *= mk
	pr.form_init()


## 협공: 맞힌 오브젝트를 구체에 표시해 두고, 협공이 있는 오브젝트가 맞힐 때
## 최근 PINCER_T초 안에 서로 다른 오브젝트 PINCER_N개 이상에게 맞았으면 표식이 터진다.
const PINCER_N := 2
const PINCER_T := 3.0
const PINCER_CD := 1.5  # 한 구체가 다시 터질 때까지


func _pincer(o: Orb) -> void:
	o.marks[get_instance_id()] = o.age
	if pincer <= 0 or o.pincer_cd > 0.0 or o.hp <= 0.0:
		return
	var n := 0
	for id in o.marks.keys():
		if o.age - o.marks[id] <= PINCER_T:
			n += 1
		else:
			o.marks.erase(id)
	if n < PINCER_N:
		return
	o.pincer_cd = PINCER_CD
	# 최대 체력 비례 (협공을 겹치면 +50%씩, 3개를 넘는 오브젝트 하나당 +25%, 보스는 1/4)
	var f := Rules.pincer_frac * (1.0 + 0.5 * (pincer - 1)) * (1.0 + 0.25 * (n - PINCER_N))
	if o.kind == Orb.Kind.BOSS:
		f *= 0.25
	var d := o.max_hp * f
	d = o.hurt(d, false)
	credit(d, "link:pincer")
	if main:
		main.popup(o.position, d, Color(1.0, 0.55, 0.85), true, "협공")
		main.burst(o.position, Color(1.0, 0.55, 0.85), 8, 120.0)


## 특수 반응: 두 속성이 함께 있으면 공격방식과 별개로 추가 공격.
func _reactions(orbs: Array, de: float, k: float) -> void:
	in_rx = true
	_reactions_inner(orbs, de, k)
	in_rx = false
	tag = ""


func _reactions_inner(orbs: Array, de: float, k: float) -> void:
	for key in halo_cd.keys():
		halo_cd[key] -= de
		if halo_cd[key] <= 0.0 or not is_instance_valid(key):
			halo_cd.erase(key)
	for key in vine_cd.keys():
		vine_cd[key] -= de
		if vine_cd[key] <= 0.0 or not is_instance_valid(key):
			vine_cd.erase(key)
	RxMore.pre(self, de)
	for r in reactions():
		var l := mini(eff.get(r["a"], 1), eff.get(r["b"], 1))
		var id: String = r["id"]
		tag = "rx:" + id
		match id:
			"burning":
				if _ready_to(id, BURN_IV / spd(l), de):
					main.spawn_proj(self, "log", l, dir)
			"steam":
				# 물길 위로 증기: 띠 전체 감속·약화
				_band(orbs, position, dir, chan_len(l), chan_w(l), func(o):
					hit(o, 1.2 * pw(l) * de, k)
					o.slow(0.35, 0.3)
					o.vuln(0.5))
			"vine":
				# 물길 따라 자란 덩굴: 지나가는 구체를 묶는다 (같은 구체는 3초에 한 번)
				_band(orbs, position, dir, chan_len(l), chan_w(l), func(o):
					if not vine_cd.has(o):
						vine_cd[o] = 3.0
						hit(o, 2.0 * pw(l))
						o.root(1.2 + 0.25 * (l - 1)))
			"shock":
				# 공격 방향으로 흐르는 물길: 0.5초마다 안의 구체에 전류
				if _ready_to(id, 0.5, de):
					zaps.clear()
					fx[id] = 0.15
					_band(orbs, position, dir, chan_len(l), chan_w(l), func(o):
						hit(o, 0.9 * pw(l), 0.3)
						o.slow(0.6, 0.5)
						zaps.append(o.position - position))
			"firestorm":
				if _ready_to(id, 2.5 / spd(l), de):
					main.spawn_proj(self, "tornado", l, dir)
			"blizzard":
				for o in main.near_t(position, 130.0 * reach(l)):
					if o.position.distance_to(position) < 130.0 * reach(l):
						hit(o, 1.0 * pw(l) * de, k)
						o.slow(0.45, 0.3)
						o.add_chill(0.8 * de)
			"eclipse":
				if _ready_to(id, 6.0 / spd(l), de):
					if main.eclipse_screen():
						fx[id] = 0.8
					else:
						fx["eclipse_small"] = 0.5
					for o in orbs:
						hit(o, 3.0 * pw(l))
						o.vuln(3.0)
			"mushroom":
				mines = mines.filter(func(mm): return is_instance_valid(mm))
				if _ready_to(id, MUSH_IV / spd(l), de) and mines.size() < 4 + l:
					main.spawn_proj(self, "mushroom", l, dir)
			"railgun":
				# 체력이 가장 많은 구체를 조준해 화면 끝까지 관통
				if not orbs.is_empty() and _ready_to(id, 3.5 / spd(l), de):
					var best: Orb = null
					for o in orbs:
						if best == null or o.hp > best.hp:
							best = o
					rail_dir = (best.position - position).normalized()
					fx[id] = 0.3
					_line(orbs, rail_dir, 2000.0, 12.0, func(o):
						hit(o, 6.0 * pw(l))
						o.stagger(25.0))
			"halo":
				# 주위를 도는 빛 칼날: 닿으면 반드시 치명타 (같은 구체는 0.5초에 한 번)
				for bp in halo_blades(l):
					for o in main.near(position + bp, 14.0):
						if not halo_cd.has(o) and o.position.distance_to(position + bp) < 14.0 + o.radius():
							halo_cd[o] = 0.5
							hit(o, 1.0 * pw(l), 1.0, {}, true, true)
			"quake":
				if _ready_to(id, 3.5 / spd(l), de):
					fx[id] = 0.4
					for o in main.near_t(position, 150.0 * reach(l)):
						if o.position.distance_to(position) < 150.0 * reach(l) + o.radius():
							hit(o, 2.5 * pw(l))
							o.root(0.8)
			"storm":
				if _ready_to(id, 2.5 / spd(l), de):
					main.spawn_proj(self, "storm", l, dir)
			"aurora":
				if _ready_to(id, 2.5 / spd(l), de):
					fx[id] = 0.35
					var done := {}
					for i in 5:
						_line(orbs, dir.rotated((i - 2) * 0.22), 300.0 * reach(l), 8.0, func(o):
							if not done.has(o):
								done[o] = true
								hit(o, 2.2 * pw(l))
								o.add_chill(1.2))
			"curse":
				# 표식 구체는 계속 피해를 받는다
				for o in orbs:
					if o.curse_owner == self:
						hit(o, 1.2 * pw(l) * de, k)
				# 가장 가까운 구체에 표식 (동시에 레벨 수만큼)
				if _ready_to(id, 2.0 / spd(l), de):
					var mine := 0
					var best: Orb = null
					var bd := 320.0 * reach(l)
					for o in orbs:
						if o.curse_lv > 0:
							if o.curse_owner == self:
								mine += 1
							continue
						var dd: float = o.position.distance_to(position)
						if dd < bd:
							bd = dd
							best = o
					if best and mine < l:
						best.curse_lv = l
						best.curse_owner = self
			"bell":
				# 종: 앞쪽 부채꼴에 울림 2번씩 (다음 한 번에 음파가 터진다)
				if _ready_to(id, 3.5 / spd(l), de):
					fx[id] = 0.4
					_cone(orbs, dir, 260.0 * reach(l), 0.6, func(o):
						hit(o, 2.5 * pw(l))  # 소리가 있어 여기서 울림 1번
						_ring(o, 1.0))
			"shatter":
				# 파쇄: 파동이 냉기를 쌓고, 빙결된 구체는 깨지며 큰 피해·파편 3개
				if _ready_to(id, 2.5 / spd(l), de):
					fx[id] = 0.35
					_cone(orbs, dir, 240.0 * reach(l), 0.5, func(o):
						if o.frozen_t > 0.0:
							o.frozen_t = 0.0
							hit(o, 7.0 * pw(l))
							main.burst(o.position, Elem.COLORS[Elem.ICE], 10, 160.0)
							for i in 3:
								var p: Projectile = main.spawn_proj(self, "frag", l, Vector2.from_angle(randf() * TAU))
								p.position = o.position
								p.hit[o] = true
						else:
							hit(o, 1.5 * pw(l))
							o.add_chill(1.0))
			"silence":
				if _ready_to(id, 4.0 / spd(l), de):
					fx[id] = 0.4
					_cone(orbs, dir, 260.0 * reach(l), 0.6, func(o):
						hit(o, 2.0 * pw(l))
						o.silence_t = maxf(o.silence_t, 2.0))
			"afterimage":
				# 잔광: 광선, 1.2초 뒤 같은 방향으로 한 번 더
				if _ready_to(id, 3.0 / spd(l), de):
					fx[id] = 0.3
					glint_d = dir
					cd["afterimage2"] = 1.2
					_line(orbs, dir, 2000.0, 12.0, func(o): hit(o, 3.0 * pw(l)))
				var f2: float = cd.get("afterimage2", 0.0)
				if f2 > 0.0:
					cd["afterimage2"] = f2 - de
					if cd["afterimage2"] <= 0.0:
						fx["afterimage2"] = 0.3
						_line(orbs, glint_d, 2000.0, 12.0, func(o): hit(o, 3.0 * pw(l)))
			"rewind":
				# 되감기 번개: 앞쪽 구체부터 연쇄, 1초 뒤 같은 구체들을 한 번 더
				if not rewind_q.is_empty():
					rewind_q[0] -= de
					if rewind_q[0] <= 0.0:
						var pts := PackedVector2Array([position])
						for o in rewind_q[1]:
							if is_instance_valid(o) and o.hp > 0.0:
								pts.append(o.position)
								hit(o, 2.0 * pw(l))
						if pts.size() > 1:
							main.bolt(pts)
						rewind_q = []
				elif _ready_to(id, 2.5 / spd(l), de):
					var got := _chain_list(orbs, dir, 280.0 * reach(l), 3 + l)
					if not got.is_empty():
						var pts := PackedVector2Array([position])
						for o in got:
							pts.append(o.position)
							hit(o, 2.0 * pw(l))
						main.bolt(pts)
						rewind_q = [1.0, got]
			"styx":
				# 망자의 강: 물길 안에서 죽으면 반드시 혼불
				_band(orbs, position, dir, chan_len(l), chan_w(l), func(o):
					hit(o, Rules.t("styx_dmg") * pw(l) * de, k)
					o.slow(0.7, 0.3)
					o.styx_t = 0.3
					o.styx_lv = l
					o.styx_src = self)
			"plague", "spirit":
				if _ready_to(id, (2.2 if id == "plague" else 2.5) / spd(l), de):
					for a in [-0.35, 0.35]:
						var pr: Projectile = main.spawn_proj(self, "ghost", l, dir.rotated(a))
						pr.dmg = 2.4 * pw(l)
						pr.ghost = id
			"prison":
				if _ready_to(id, Rules.t("prison_iv") / spd(l), de):
					main.spawn_proj(self, "icebolt", l, dir)
			_:
				RxMore.tick(self, id, l, orbs, de, k)


## 벽 바위 k번째 자리(오브젝트 기준). 처음 두 개는 앞으로 한 줄(90·150), 다중 발사로 늘어난 바위는 그 사이 양옆에 번갈아
## (2026-10-30: 앞으로만 늘어서면 맨 앞 바위에 막힌 구체가 옆으로 비껴 나가 다중 발사가 피해를 0.65~0.76배로 깎던 것)
static func rock_slot(d: Vector2, k: int, l: int) -> Vector2:
	if k < 2:
		return d * (90.0 + 60.0 * k) * reach(l)
	return d * 120.0 * reach(l) + d.orthogonal() * 56.0 * (1 + (k - 2) / 2) * (1.0 if k % 2 == 0 else -1.0)


## 음파 사거리.
func sonic_r(l: int) -> float:
	return 230.0 * reach(l) * sz()


## 시계침 각도 (공격 방향 기준).
func clock_a() -> float:
	return sin(clock_ph) * 0.7


## 앞쪽 가장 가까운 구체부터 n개를 잇는다 (되감기 번개).
func _chain_list(orbs: Array, d: Vector2, rng: float, n: int) -> Array:
	var first: Orb = null
	var best := rng
	for o in main.near_t(position, rng):
		var v: Vector2 = o.position - position
		if v.length() < best and absf(d.angle_to(v)) < 0.5:
			best = v.length()
			first = o
	if first == null:
		return []
	var out := [first]
	var cur := first
	while out.size() < n:
		var nxt: Orb = null
		var nd := 110.0
		for o in main.near_t(cur.position, nd):
			if not out.has(o) and o.position.distance_to(cur.position) < nd:
				nd = o.position.distance_to(cur.position)
				nxt = o
		if nxt == null:
			break
		out.append(nxt)
		cur = nxt
	return out


## 울림을 쌓는다. 3이 되면 그 구체 주변에 음파 (같은 구체는 1초에 한 번).
func _ring(o: Orb, amount: float) -> void:
	o.ring += amount
	if o.ring < 3.0 or o.ring_cd > 0.0:
		return
	# 오브젝트 하나가 터뜨리는 울림 음파는 초당 sound_rate번까지 (2026-10-30: 빽빽한 무리에서 구체마다 터진
	# 음파가 서로를 다 맞혀 계속 때리는 공격·울림 균열과 섞이면 3~6배이던 것). 모자라면 울림을 그대로 쌓아 둔다
	if t - ring_t0 >= 1.0:
		ring_t0 = t
		ring_n = 0
	if ring_n >= int(Rules.t("sound_rate")):
		return
	ring_n += 1
	o.ring = 0.0
	o.ring_cd = Rules.t("sound_cd")
	if main:
		main.sound_pulse(o)


## 물길: 공격 방향으로 흐르는 띠. 웨이브가 시작되면 물이 앞으로 흘러 나간다.
func chan_len(l: int) -> float:
	var full := 260.0 * reach(l)
	return minf(full, main.wave_time * 520.0) if main else full


func chan_w(l: int) -> float:
	return 20.0 + 3.0 * (l - 1)


## 땅 반응은 오브젝트 공격(공격방식)이 맞힐 때 붙는다 (2026-10-30, 앞쪽 가로 벽 대신).
## 용암: 묻은 구체가 LAVA_FUSE초 뒤(또는 죽을 때) 그 자리에서 터짐. 같은 구체는 터질 때까지 한 번만.
const LAVA_FUSE := 2.0
const LAVA_DMG := 2.4
const LAVA_R := 70.0
## 독늪: 맞은 구체가 BOG_MARK초 안에 죽으면 그 자리에 늪. 늪 안에서 죽으면 또 늪(번짐), 오브젝트당 BOG_MAX개.
const BOG_MARK := 4.0
const BOG_MAX := 6
const BOG_R := 56.0
const BOG_LIFE := 4.0
## 모래시계: 맞은 구체를 약 1초 전 위치로 되감기 (같은 구체는 SAND_CD초에 한 번, 보스는 절반만), 받은 피해 메아리 50%.
const SAND_CD := 3.0
const SAND_DMG := 8.0


func _earth_on_hit(o: Orb) -> void:
	if earth_rx.has("lava") and o.lava_t <= 0.0:
		o.lava_t = LAVA_FUSE
		o.lava_lv = earth_rx["lava"]
		o.lava_src = self
	if earth_rx.has("swamp"):
		o.bog_t = BOG_MARK
		o.bog_lv = earth_rx["swamp"]
		o.bog_src = self
	if earth_rx.has("hourglass") and o.sand_cd <= 0.0 and o.hp > 0.0:
		o.sand_cd = SAND_CD
		var back := o.past_pos()
		var to := o.position.lerp(back, 0.5 if o.kind == Orb.Kind.BOSS else 1.0)
		main.burst(o.position, Color(0.85, 0.7, 0.4), 6, 90.0)
		o.position = to
		main.burst(to, Color(0.85, 0.7, 0.4), 6, 90.0)
		o.echo(0.5, 2.0, self)
		var tg := tag
		in_rx = true
		tag = "rx:hourglass"
		hit(o, SAND_DMG * pw(earth_rx["hourglass"]))
		in_rx = false
		tag = tg


## 독늪 늪 하나 (자리가 차 있으면 가장 오래된 늪을 없앤다).
func spawn_bog(p: Vector2, l: int) -> void:
	bogs = bogs.filter(func(z): return is_instance_valid(z) and not z.is_queued_for_deletion())
	if bogs.size() >= BOG_MAX:
		bogs[0].queue_free()
		bogs.remove_at(0)
	tag = "rx:swamp"
	bogs.append(main.spawn_zone("bog", l, p, self))
	tag = ""


## 광륜 칼날 위치(로컬). 레벨마다 하나씩 늘어난다(최대 6).
func halo_r(l: int) -> float:
	return 110.0 * reach(l)


func halo_blades(l: int) -> Array:
	var n := mini(1 + l, 6)
	var out := []
	for i in n:
		out.append(Vector2.from_angle(t * 2.4 + TAU * i / n) * halo_r(l))
	return out


## 유도 강화: 범위·광선 공격은 앞쪽 가장 가까운 구체 쪽으로 방향이 돈다(최대 0.1라디안씩).
func _update_aim(orbs: Array, delta: float) -> void:
	var n := mf("homing")
	if n == 0.0 or pattern in Pat.PROJECTILE:
		aim = dir
		return
	var limit := 0.1 * n
	# 가장 가까운 구체가 아니라 구체가 가장 많이 모인 쪽으로 (2026-10-30: 가까운 한 개를 따라가 무리 가운데를 벗어나
	# 분사·음파·물줄기·레이저·시계침에서 유도가 피해를 0.65~0.86배로 깎던 것)
	var angs := PackedFloat32Array()
	for o in main.near_t(position, 400.0):
		var v: Vector2 = o.position - position
		if v.length() < 400.0:
			var a := dir.angle_to(v)
			if absf(a) < limit + 0.4:
				angs.append(a)
	var want := dir
	if not angs.is_empty():
		angs.sort()
		var best_a := 0.0
		var best_n := 0
		var j := 0
		for i in angs.size():  # 0.6라디안 창에 가장 많이 든 곳의 가운데
			while angs[i] - angs[j] > 0.6:
				j += 1
			if i - j + 1 > best_n:
				best_n = i - j + 1
				best_a = (angs[i] + angs[j]) * 0.5
		want = dir.rotated(clampf(best_a, -limit, limit))
	aim = aim.slerp(want, minf(1.0, delta * 6.0)).normalized()


## 이 오브젝트의 공격이 구체에 닿았을 때. 겹친(나눠 받은) 모든 속성의 부가효과가 붙는다.
## k: 부가효과 세기 (한 방=1, 지속 공격=프레임 비례)
## extra: 프리즘에서 묻어 온 속성, can_split: 파편은 다시 분열하지 않는다
func hit(o: Orb, dmg: float, k := 1.0, extra := {}, can_split := true, force_crit := false) -> void:
	if not is_instance_valid(o) or o.hp <= 0.0:
		return
	var els: Dictionary = eff if not eff.is_empty() else elements
	if not extra.is_empty():
		els = els.duplicate()
		for e in extra:
			els[e] = maxi(els.get(e, 0), extra[e])
	var d := dmg * dmg_k(in_rx)
	var dx := dice_x if not in_rx else 1.0  # 주사위: 반응 피해에는 안 곱한다
	d *= dx
	var crit := dx >= Rules.t("dice_top") and k >= 1.0  # 대박은 치명타처럼 금색 숫자
	var lit := false  # 빛 치명타 (확정 치명타 반응은 반응 몫)
	var cc := minf(0.12 * els.get(Elem.LIGHT, 0), 0.6) if els.has(Elem.LIGHT) else 0.0
	if o.lucky_t > 0.0:
		cc += 0.3  # 무지개 물길 위
	if force_crit or cc > 0.0 and randf() < cc * minf(k, 1.0):
		d *= 2.0
		crit = k >= 1.0
		lit = not force_crit
	if els.has(Elem.WOOD):
		d *= 1.0 + 0.2 * mini(els.get(Elem.WOOD, 0), int(Rules.t("wood_cap")))
	var mt := 0.0
	if els.has(Elem.METAL):
		mt = 0.4 * els.get(Elem.METAL, 0) * k
		d += mt
		o.stagger(4.0 * els.get(Elem.METAL, 0) * k)
	# 형태 성질 자람·무게: 공격방식 공격만 (반응·형태 성질 효과 제외)
	if not in_rx and not in_form:
		if els.has(Elem.WOOD):
			d *= 1.0 + minf(0.04 * tk(Elem.WOOD) * o.position.distance_to(position) / 100.0, 0.2)
		if els.has(Elem.METAL):
			o.stagger(o.speed * 0.1 * tk(Elem.METAL) * minf(k, 1.0))
	var rm := o.resist_mul(els)
	d *= rm
	d = o.hurt(d, crit)  # 받는 피해 배율(약점 등)까지 곱한 값
	dealt += d
	if in_rx:
		rx_dealt += d
	# 출처: 금속 고정 피해·빛 치명타로 늘어난 절반은 그 속성, 나머지는 지금 출처
	var key := tag if tag != "" else "hit"
	var rest := d
	if mt > 0.0:
		mt *= rm
		rest -= mt
		src["elem:metal"] = src.get("elem:metal", 0.0) + mt
	if dx > 1.0:
		var dd := rest * (1.0 - 1.0 / dx)
		rest -= dd
		src["mod:dice"] = src.get("mod:dice", 0.0) + dd
	if lit:
		rest *= 0.5
		src["elem:light"] = src.get("elem:light", 0.0) + rest
	src[key] = src.get(key, 0.0) + rest
	_pincer(o)
	if van_ready and not in_rx:
		van_ready = false
		van_t = van_time(tg("vanguard"))
	if o.hp <= 0.0 and echo_cd <= 0.0 and tg("echo") > 0:
		_echo(o)
	if els.has(Elem.FIRE):
		o.burn(0.8 * els.get(Elem.FIRE, 0) * rm, 2.0, self)
	if els.has(Elem.POISON):
		o.poison(0.5 * els.get(Elem.POISON, 0) * rm, 4.0, self)
	if els.has(Elem.ICE):
		o.add_chill(0.6 * k * els.get(Elem.ICE, 0))
	if els.has(Elem.WATER):
		o.slow(0.8, 0.8)
	if els.has(Elem.EARTH) and randf() < minf(0.2 * els.get(Elem.EARTH, 0), 0.7) * k * (2.0 if o.mud_t > 0.0 else 1.0):
		o.root(0.8)
	if els.has(Elem.DARK):
		o.vuln(2.0)
	if els.has(Elem.ELECTRIC) and randf() < 0.3 * k:
		main.arc(o, d * 0.5 * els.get(Elem.ELECTRIC, 0), self)
	if els.has(Elem.SOUND):
		# 울림을 걸어 둔다: 3초 동안 어느 오브젝트에 맞아도 쌓인다
		if o.tune_t <= 0.0 or els.get(Elem.SOUND, 0) >= o.tune_lv:
			o.tune_lv = els.get(Elem.SOUND, 0)
			o.tune_src = self
		o.tune_t = 3.0
	if o.tune_t > 0.0:
		_ring(o, minf(k, 1.0))
	if els.has(Elem.TIME):
		o.echo(minf(0.15 + 0.05 * els.get(Elem.TIME, 0), 0.4), 2.0, self)
	if not in_rx and not in_form and not earth_rx.is_empty():
		_earth_on_hit(o)
	if els.has(Elem.SOUL):
		if o.soul_t <= 0.0 or els.get(Elem.SOUL, 0) >= o.soul_lv:
			o.soul_lv = els.get(Elem.SOUL, 0)
			o.soul_src = self
		o.soul_t = 3.0
	if can_split and m("split") > 0 and randf() < minf(0.6, 0.12 * mf("split")) * minf(k, 1.0):
		for i in 2:
			var p: Projectile = main.spawn_proj(self, "frag", plv, Vector2.from_angle(randf() * TAU))
			p.src = "mod:split"
			p.dmg *= 0.5
			p.position = o.position
			p.hit[o] = true


## 여진: 잡은 구체 자리에서 작은 탄이 고르게 사방으로 (쏘는 방향은 판마다 조금씩 돈다).
func _echo(o: Orb) -> void:
	echo_cd = ECHO_CD
	var n := ECHO_N + tg("echo") - 1
	var a0 := randf() * TAU
	for i in n:
		var p: Projectile = main.spawn_proj(self, "frag", plv, Vector2.from_angle(a0 + TAU * i / n))
		p.src = "trig:echo"
		p.dmg *= ECHO_DMG
		p.position = o.position
		p.hit[o] = true


# ---------- 형태 성질 (Elem.TRAIT) ----------

## 계속 공격하는 형태: 2초에 한 번 사거리 끝에서 "끝" 효과 (사거리 안에 구체가 있을 때).
func _cont_end(orbs: Array, l: int, s: float) -> void:
	if fe2 > 0.0 or orbs.is_empty():
		return
	var rng := 0.0
	var d := aim
	match pattern:
		"spray": rng = 200.0 * reach(l) * s
		"stream": rng = 260.0 * reach(l) * s
		"laser": rng = 400.0
		"sonic": rng = sonic_r(l)
		"clock":
			rng = 240.0 * reach(l) * s
			d = aim.rotated(clock_a())
		_: return
	if not orbs.any(func(o): return o.position.distance_to(position) < rng):
		return
	fe2 = 2.0
	form_end(position + d * rng, d, true)


## 공격이 끝난 자리 pos(방향 d)에서 속성마다 형태 성질. big: 날아가는 공격의 재사용 대기(1.5초)를 무시.
func form_end(pos: Vector2, d: Vector2, big := false) -> void:
	if not main or not pos.is_finite():
		return
	if not big:
		if fe_cd > 0.0:
			return
		fe_cd = 1.5
	d = d.normalized() if d.length_squared() > 0.0001 else aim
	var p := pw(plv)
	var old_tag := tag
	in_form = true
	for e in (eff if not eff.is_empty() else elements):
		var a := tk(e)
		if a <= 0.0:
			continue
		tag = trait_tag(e)
		match e:
			Elem.FIRE: _fz("ember", pos, a)
			Elem.WATER: _fz("rill", pos, a)
			Elem.ICE: _fz("frost", pos, a)
			Elem.EARTH: _fz("ledge", pos, a)
			Elem.POISON: _fz("fog", pos, a)
			Elem.TIME: _fz("tick", pos, a)
			Elem.ELECTRIC:
				var best: Orb = null
				var bd := 120.0
				for o in main.near(pos, bd):
					if o.hp > 0.0 and o.position.distance_to(pos) < bd:
						bd = o.position.distance_to(pos)
						best = o
				if best:
					hit(best, 0.45 * p * a, 0.5)
					main.bolt(PackedVector2Array([pos, best.position]))
			Elem.DARK:
				for o in main.near(pos, 60.0):
					if o.hp > 0.0 and o.position.distance_to(pos) < 60.0 + o.radius():
						o.shade(SHADE_T)
			Elem.LIGHT:
				var to := pos + d * 200.0
				for o in main.near(pos + d * 100.0, 110.0):
					if o.hp > 0.0 and Geometry2D.get_closest_point_to_segment(o.position, pos, to).distance_to(o.position) < 8.0 + o.radius():
						hit(o, 0.3 * p * a, 0.5)
				main.beam(pos, to, Elem.COLORS[Elem.LIGHT])
			Elem.SOUND:
				for o in main.near(pos, 50.0):
					if o.hp > 0.0 and o.position.distance_to(pos) < 50.0 + o.radius():
						hit(o, 0.25 * p * a, 0.3)
				if main.pulses.size() < 40:
					main.pulses.append([pos, 50.0, 0.3])
			Elem.SOUL:
				if randf() < 0.1 * a:
					main.form_ghost(self, pos, 1.5 * p)
	in_form = false
	tag = old_tag


## 피해 출처 키 (main.src_name이 "형태 성질 불"처럼 보여 준다).
static func trait_tag(e: int) -> String:
	return "trait:" + Patch.ELEM_KEYS[Elem.ALL.find(e)]


## 날아가는 공격이 지나간 길 (70마다): 불씨·물길.
func form_path(pos: Vector2) -> void:
	var old_tag := tag
	var a := tk(Elem.FIRE)
	if a > 0.0:
		tag = trait_tag(Elem.FIRE)
		_fz("ember", pos, a)
	a = tk(Elem.WATER)
	if a > 0.0:
		tag = trait_tag(Elem.WATER)
		_fz("rill", pos, a)
	tag = old_tag


## 형태 성질 장판. 화면의 장판이 많으면 건너뛴다 (후반 부하).
func _fz(kind: String, pos: Vector2, a: float) -> void:
	if main.zones.get_child_count() >= 160:
		return
	main.spawn_zone(kind, plv, pos, self).amt = a


## d 방향 부채꼴 안의 구체에 효과.
func _cone(_orbs: Array, d: Vector2, rng: float, half: float, f: Callable) -> void:
	for o in main.near_t(position, rng):
		var v: Vector2 = o.position - position
		if v.length() < rng + o.radius() and absf(d.angle_to(v)) < half:
			f.call(o)


## from에서 d 방향 띠(길이 length, 반폭 half_w) 안의 구체에 효과.
func _band(_orbs: Array, from: Vector2, d: Vector2, length: float, half_w: float, f: Callable) -> void:
	for o in main.near_t(from + d * length * 0.5, length * 0.5 + half_w + 32.0):
		var v: Vector2 = o.position - from
		var along := v.dot(d)
		if along > -o.radius() and along < length + o.radius() and absf(v.cross(d)) < half_w + o.radius():
			f.call(o)


## d 방향 직선 위의 구체에 효과.
func _line(_orbs: Array, d: Vector2, length: float, width: float, f: Callable) -> void:
	for o in main.near_t(position + d * length * 0.5, length * 0.5 + width):
		var v: Vector2 = o.position - position
		var along := v.dot(d)
		if along > 0.0 and along < length and absf(v.cross(d)) < width + o.radius():
			f.call(o)


## d 방향 앞쪽의 가장 가까운 구체를 치고 주변으로 튄다. used: 다중 발사 때 같은 첫 대상 피하기
func _chain(orbs: Array, d: Vector2, l: int, used: Dictionary) -> bool:
	var first: Orb = null
	var best := 280.0 * reach(l) * sz()
	for o in main.near_t(position, best):
		var v: Vector2 = o.position - position
		if not used.has(o) and v.length() < best and absf(d.angle_to(v)) < 0.5:
			best = v.length()
			first = o
	if first == null:
		return false
	used[first] = true
	var pts := PackedVector2Array([position + d * RADIUS])
	var cur := first
	var hitset := {}
	for i in 3 + l + mn("bounce"):
		hitset[cur] = true
		pts.append(cur.position)
		hit(cur, 2.2 * pw(l) * multi_k())
		var nxt: Orb = null
		var nd := 110.0 * sz()
		for o in main.near_t(cur.position, nd):
			if not hitset.has(o) and o.position.distance_to(cur.position) < nd:
				nd = o.position.distance_to(cur.position)
				nxt = o
		if nxt == null:
			break
		cur = nxt
	chain_end = cur.position
	# 번개는 구체·블랙홀에 가려지지 않게 맨 위 층(main)에 그린다
	main.bolt(pts)
	return true


# ---------- 그리기 ----------

func _draw() -> void:
	if pattern == "path":
		_draw_paths()
	if main and main.wave_active:
		_draw_attack()
	_draw_body()


## 그린 길: 쉬는 시간엔 또렷하게, 웨이브 중엔 옅게. 끝에 화살촉.
func _draw_paths() -> void:
	var c := color()
	var a := 0.16 if main and main.wave_active else 0.45
	for pts: PackedVector2Array in paths:
		if pts.size() < 2:
			continue
		draw_polyline(pts, Color(c, a), 2.0)
		var e := pts[pts.size() - 1]
		var d := (e - pts[pts.size() - 2]).normalized()
		draw_colored_polygon(PackedVector2Array([e + d * 7.0, e - d * 5.0 + d.orthogonal() * 5.0, e - d * 5.0 - d.orthogonal() * 5.0]), Color(c, a + 0.15))


func _process(delta: float) -> void:
	if place_pop > 0.0:
		place_pop = maxf(place_pop - delta * 3.0, 0.0)
		queue_redraw()
	if prism_flash > 0.0:
		prism_flash = maxf(prism_flash - delta * 4.0, 0.0)
		queue_redraw()


var _body: Array = []  # [점들, 색, 고리 모양이면 true]
var _body_key := 0


func _draw_body() -> void:
	var s := 1.0 + 0.5 * place_pop
	draw_set_transform(-dir * recoil * 5.0, 0.0, Vector2(s, s))
	if place_pop > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 20.0 * (1.0 - place_pop), 0, TAU, 32, Color(1, 1, 1, place_pop), 3.0)
	if prism > 0:
		var hx := PackedVector2Array()
		for i in 7:
			hx.append(Vector2.from_angle(TAU * i / 6.0 + t) * (RADIUS + 6.0 + 3.0 * prism_flash))
		if prism_flash > 0.0:
			draw_colored_polygon(hx.slice(0, 6), Color(1, 1, 1, 0.35 * prism_flash))
		draw_polyline(hx, Color(0.8, 0.95, 1.0, 0.8).lerp(Color.WHITE, prism_flash), 2.0 + 2.0 * prism_flash)
		# 겹친 프리즘: 바깥으로 반대 방향으로 도는 육각 테두리를 하나씩 더 (최대 3겹)
		for j in range(1, mini(prism, 3)):
			var hx2 := PackedVector2Array()
			for i in 7:
				hx2.append(Vector2.from_angle(TAU * i / 6.0 + (t if j % 2 == 0 else -t)) * (RADIUS + 6.0 + 5.0 * j + 3.0 * prism_flash))
			draw_polyline(hx2, Color(0.8, 0.95, 1.0, 0.6 - 0.15 * j).lerp(Color.WHITE, prism_flash), 1.5)
	if pincer > 0:
		# 협공: 세 갈래 화살표가 안쪽을 겨눈다
		for i in 3:
			var a := TAU * i / 3.0 - t * 0.8
			var p := Vector2.from_angle(a) * (RADIUS + 10.0)
			var tip := Vector2.from_angle(a) * (RADIUS + 3.0)
			var side := Vector2.from_angle(a).orthogonal() * 4.0
			draw_colored_polygon(PackedVector2Array([tip, p + side, p - side]), Color(1.0, 0.55, 0.85, 0.85))
	if van_t > 0.0:
		# 선봉: 켜져 있는 동안 남은 시간만큼 줄어드는 고리
		var f := van_t / van_time(tg("vanguard"))
		draw_arc(Vector2.ZERO, RADIUS + 6.0, -PI / 2.0, -PI / 2.0 + TAU * f, 24, Color(Pat.TRIG_COLOR, 0.9), 3.0)
	# 바람 버프 둘레는 main._draw_wind_rings (마우스를 올리거나 옮길 때만)
	if wind_buff > 0.0:
		# 바람 버프를 받는 중: 작은 바람 꼬리 둘
		for i in 2:
			var a := Time.get_ticks_msec() / 300.0 + PI * i
			draw_arc(Vector2.ZERO, RADIUS + 7.0, a, a + 0.9, 8, Color(Elem.COLORS[Elem.WIND], 0.85), 2.0)
	if reso > 0:
		var pulse := fmod(Time.get_ticks_msec() / 1000.0, 1.0)
		draw_arc(Vector2.ZERO, RADIUS + 4.0 + pulse * 14.0, 0, TAU, 32, Color(1, 0.85, 0.5, 0.6 * (1.0 - pulse)), 2.0)
	# 겹친 속성 비율대로 나눈 몸체 (모양은 메뉴에서 고른 스킨)
	var total := total_level()
	var skin := Meta.tower_skin
	# 몸체 다각형은 속성·레벨·모양이 바뀔 때만 다시 만든다 (오브젝트마다 점 80개를 매 프레임 계산하던 것이 그리기 시간의 대부분)
	var key := hash(skin)
	for e in order:
		key = key * 31 + e * 1000 + lv(e)
	if key != _body_key:
		_body_key = key
		_body.clear()
		var a0 := -PI / 2
		for e in order:
			var span := TAU * lv(e) / total
			var steps := maxi(2, int(span / 0.08))
			if skin == "ring":
				var pts := PackedVector2Array()
				for i in steps + 1:
					pts.append(Vector2.from_angle(a0 + span * i / steps) * RADIUS * 0.8)
				_body.append([pts, Elem.COLORS[e], true])
			elif order.size() == 1:
				# 한 칸뿐이면 가운데 점·겹친 끝점 없이 외곽선만 (별 모양은 부채꼴이면 삼각분할이 실패해 투명해짐)
				var pts := PackedVector2Array()
				for i in steps:
					var a := a0 + span * i / steps
					pts.append(Vector2.from_angle(a) * _skin_r(skin, a))
				_body.append([pts, Elem.COLORS[e], false])
			else:
				var pts := PackedVector2Array([Vector2.ZERO])
				for i in steps + 1:
					var a := a0 + span * i / steps
					pts.append(Vector2.from_angle(a) * _skin_r(skin, a))
				_body.append([pts, Elem.COLORS[e], false])
			a0 += span
	for b in _body:
		if b[2]:
			draw_polyline(b[0], b[1], RADIUS * 0.4)
		else:
			draw_colored_polygon(b[0], b[1])
	if skin == "gem":
		draw_line(Vector2(0, -RADIUS * 1.15), Vector2(0, RADIUS * 1.15), Color(1, 1, 1, 0.35), 1.5)
		draw_line(Vector2(-RADIUS * 0.85, 0), Vector2(RADIUS * 0.85, 0), Color(1, 1, 1, 0.35), 1.5)
	if not reactions().is_empty():
		draw_arc(Vector2.ZERO, RADIUS + 2.0, 0, TAU, 32, Color.WHITE, 2.0)
	# 겹친 속성 수만큼 주위를 도는 작은 점
	if order.size() > 1:
		var now := Time.get_ticks_msec() / 1000.0
		for i in order.size():
			var a := now * 1.2 + TAU * i / order.size()
			draw_circle(Vector2(cos(a), sin(a)) * (RADIUS + 7.0), 2.5, Elem.COLORS[order[i]])
	draw_set_transform(Vector2.ZERO)
	_draw_barrel()
	if Meta.symbols_on:
		# 포신에 가리지 않게 포신 위에 그린다
		draw_set_transform(-dir * recoil * 5.0, 0.0, Vector2(s, s))
		_draw_symbols(total, skin)
		draw_set_transform(Vector2.ZERO)
	if total > 1 and not (main and main.wave_active):  # 레벨 숫자는 쉬는 시간에만 (웨이브 중 글자 줄이기)
		draw_string(ThemeDB.fallback_font, Vector2(-6, -RADIUS - 6), str(total), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# 강화 개수: 아래쪽 작은 점
	var nm := 0
	for id in mods:
		nm += mods[id]
	for i in mini(nm, 8):
		draw_circle(Vector2(-(mini(nm, 8) - 1) * 3.0 + i * 6.0, RADIUS + 7.0), 2.0, Color(1, 0.85, 0.45))


## 속성 기호(설정): 몸체의 속성 칸마다 그 속성 이름 첫 글자. 하나뿐이면 가운데.
func _draw_symbols(total: int, skin: String) -> void:
	var font: Font = main.ui_font if main and main.ui_font else ThemeDB.fallback_font
	var fs := 12 if order.size() <= 3 else 9
	var rr := RADIUS * (0.8 if skin == "ring" else 0.55)
	var a0 := -PI / 2
	for e in order:
		var span := TAU * lv(e) / total
		var c := Vector2.ZERO if order.size() == 1 else Vector2.from_angle(a0 + span / 2.0) * rr
		Elem.draw_symbol(self, font, c, e, fs)
		a0 += span


## 스킨 외곽선: 각도 a에서 중심까지 거리.
static func _skin_r(skin: String, a: float) -> float:
	match skin:
		"hex":
			var k := PI / 6.0
			return RADIUS * cos(k) / cos(fposmod(a + PI / 2, 2 * k) - k) * 1.05
		"gem":
			var k := PI / 4.0
			return RADIUS * 1.15 * cos(k) / cos(fposmod(a + PI / 2, 2 * k) - k)
		"star":
			return RADIUS * (0.78 + 0.32 * cos(5.0 * (a + PI / 2)))
	return RADIUS


## 포신: 공격방식마다 모양이 다르다.
func _draw_barrel() -> void:
	var d := aim
	var n := d.orthogonal()
	var w := Color.WHITE
	var b := -d * recoil * 5.0
	match pattern:
		"spray":
			draw_colored_polygon(PackedVector2Array([b + d * RADIUS * 0.4, b + d * (RADIUS + 10) + n * 7, b + d * (RADIUS + 10) - n * 7]), w)
		"chain":
			draw_polyline(PackedVector2Array([b + d * 6, b + d * 12 + n * 4, b + d * 18 - n * 4, b + d * 26]), w, 2.5)
		"laser":
			draw_line(b + d * 4, b + d * (RADIUS + 16.0), w, 2.0)
			draw_circle(b + d * (RADIUS + 16.0), 2.5, w)
		"wall":
			draw_rect(Rect2(b + d * (RADIUS + 4) - Vector2(5, 5), Vector2(10, 10)), w)
		"vortex":
			draw_arc(b + d * (RADIUS + 6), 6.0, 0, TAU, 16, w, 2.5)
		"lob":
			draw_arc(b + d * (RADIUS + 2), 7.0, d.angle() - 1.2, d.angle() + 1.2, 12, w, 3.0)
		"iron":
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 8.0), w, 6.0)
		"stream":
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 12.0) + n * 3, w, 3.0)
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 12.0) - n * 3, w, 3.0)
		"gust":
			draw_arc(b + d * (RADIUS + 2), 8.0, d.angle() - 0.9, d.angle() + 0.9, 12, w, 3.0)
		"thorn":
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 12.0), w, 2.0)
			draw_line(b + d * RADIUS * 0.4 + n * 4, b + d * (RADIUS + 8.0) + n * 4, w, 2.0)
		"sonic":
			for i in 3:
				draw_arc(b + d * (RADIUS - 4.0), 6.0 + i * 4.0, d.angle() - 0.6, d.angle() + 0.6, 8, w, 2.0)
		"clock":
			draw_line(b, b + d.rotated(clock_a()) * (RADIUS + 10.0), w, 2.5)
			draw_circle(b, 3.0, w)
		"wisp":
			draw_circle(b + d * (RADIUS + 4.0), 4.0, w)
			draw_circle(b + d * (RADIUS + 4.0) - d * 6.0, 2.5, Color(w, 0.6))
		_:
			draw_line(b + d * RADIUS * 0.4, b + d * (RADIUS + 10.0), w, 3.0)
			if pattern == "shard":
				draw_circle(b + d * (RADIUS + 10.0), 3.0, Elem.COLORS[Elem.ICE])


func _draw_attack() -> void:
	var l := plv
	var s := sz()
	var c := color()
	match pattern:
		"spray":
			for d in dirs():
				_draw_puffs(d, 200.0 * reach(l) * s, 0.35, 34, 2.4, c.lightened(0.4), c, 3.0, 10.0)
		"stream":
			if fx.get("stream", 0.0) > 0.0:
				for d in dirs():
					_draw_wave(d, 260.0 * reach(l) * s, 5.0 * s, 0.05, c, 7.0 * s)
		"laser":
			var f: float = fx.get("laser", 0.0)
			for d in dirs():
				if f > 0.0:
					draw_line(d * RADIUS, d * 2000.0, Color(c, f / 0.3), (10.0 * f / 0.3 + 2.0) * s)
					draw_line(d * RADIUS, d * 2000.0, Color(1, 1, 1, f / 0.3), 3.0)
				else:
					var ch: float = 1.0 - cd.get("p", 0.0) / (2.0 / spd(l))
					draw_circle(d * (RADIUS + 4.0), 2.0 + 4.0 * ch, Color(c, 0.4 + 0.6 * ch))
		"sonic":
			var f: float = fx.get("sonic", 0.0)
			if f > 0.0:
				var k := 1.0 - f / 0.35
				var R := sonic_r(l)
				for d in dirs():
					for i in 3:
						var rr := R * clampf(k - i * 0.15, 0.05, 1.0)
						draw_arc(Vector2.ZERO, rr, d.angle() - 0.5, d.angle() + 0.5, 16, Color(c.lightened(0.3), (1.0 - k) * (1.0 - i * 0.25)), 3.0)
		"clock":
			for d in dirs():
				var hd: Vector2 = d.rotated(clock_a())
				var L := 240.0 * reach(l) * s
				draw_arc(Vector2.ZERO, L, d.angle() - 0.7, d.angle() + 0.7, 24, Color(c, 0.15), 2.0)
				draw_line(hd * RADIUS, hd * L, Color(c, 0.85), 4.0 * s)
				draw_line(hd * RADIUS, hd * L, Color(1, 1, 1, 0.5), 1.5)
	# 물이 들어간 반응은 같은 물길 하나 위에 겹쳐 그린다
	var rxs := reactions()
	var chan := 0.0
	var cw := 0.0
	for r in rxs:
		if r["id"] in ["steam", "vine", "shock", "styx"]:
			var rl0 := mini(eff.get(r["a"], 1), eff.get(r["b"], 1))
			chan = maxf(chan, chan_len(rl0))
			cw = maxf(cw, chan_w(rl0))
	if chan > 0.0:
		_draw_channel(chan, cw)
	for r in rxs:
		var rl := mini(eff.get(r["a"], 1), eff.get(r["b"], 1))
		var n := dir.orthogonal()
		match r["id"]:
			"steam":
				var L := chan_len(rl)
				for i in 12:
					var f := fmod(t * 0.6 + i * 0.13, 1.0)
					var p := dir * L * fmod(i * 0.37 + 0.05, 1.0) + n * sin(i * 1.7) * chan_w(rl) * 0.6 + Vector2(0, -f * 18.0)
					draw_circle(p, 5.0 + f * 10.0, Color(1, 1, 1, 0.28 * (1.0 - f)))
			"vine":
				var L := chan_len(rl)
				for side in [-1.0, 1.0]:
					var pts := PackedVector2Array()
					var steps := maxi(int(L / 12.0), 2)
					for i in steps + 1:
						var x := L * i / steps
						pts.append(dir * x + n * (side * chan_w(rl) * 0.85 + sin(x * 0.06 + t * 2.0 + side) * 4.0))
					draw_polyline(pts, r["color"], 3.0)
					for i in range(1, steps, 3):
						draw_circle(pts[i] + n * side * 4.0, 3.0, r["color"].lightened(0.25))
			"shock":
				var L := chan_len(rl)
				var w := chan_w(rl)
				for i in 4:
					var p0 := dir * randf() * L + n * randf_range(-w, w) * 0.8
					draw_line(p0, p0 + Vector2(randf_range(-14, 14), randf_range(-14, 14)), Color(Elem.COLORS[Elem.ELECTRIC], 0.9), 2.0)
				if fx.get("shock", 0.0) > 0.0:
					for zp in zaps:
						var p0: Vector2 = dir * clampf(zp.dot(dir), 0.0, L)
						var pts := PackedVector2Array([p0])
						for s2 in 3:
							pts.append(p0.lerp(zp, (s2 + 1) / 4.0) + Vector2(randf_range(-5, 5), randf_range(-5, 5)))
						pts.append(zp)
						draw_polyline(pts, Elem.COLORS[Elem.ELECTRIC], 2.5)
			"bell", "shatter", "silence":
				var f: float = fx.get(r["id"], 0.0)
				if f > 0.0:
					var k := 1.0 - f / 0.4
					var R: float = {"bell": 260.0, "shatter": 240.0, "silence": 260.0}[r["id"]] * reach(rl)
					var half := 0.5 if r["id"] == "shatter" else 0.6
					for i in 3:
						draw_arc(Vector2.ZERO, R * clampf(k - i * 0.12, 0.05, 1.0), dir.angle() - half, dir.angle() + half, 20, Color(r["color"], (1.0 - k) * 0.9), 4.0 - i)
				if r["id"] == "bell":
					draw_arc(dir * -4.0, 7.0, dir.angle() + 0.6, dir.angle() + TAU - 0.6, 12, Color(r["color"], 0.8), 2.5)
			"afterimage":
				for key in ["afterimage", "afterimage2"]:
					var f: float = fx.get(key, 0.0)
					if f > 0.0:
						var d2 := dir if key == "afterimage" else glint_d
						draw_line(d2 * RADIUS, d2 * 2000.0, Color(r["color"], f / 0.3 * (1.0 if key == "afterimage" else 0.6)), 9.0 * f / 0.3 + 2.0)
				if cd.get("afterimage2", 0.0) > 0.0:
					draw_line(glint_d * RADIUS, glint_d * 2000.0, Color(r["color"], 0.12), 1.5)
			"styx":
				var L := chan_len(rl)
				for i in 6:
					var f := fmod(t * 0.5 + i / 6.0, 1.0)
					draw_circle(dir * L * f + n * sin(i * 2.3 + t) * chan_w(rl) * 0.5, 3.5, Color(r["color"].lightened(0.3), 0.7 * (1.0 - f)))
			"railgun":
				var f: float = fx.get("railgun", 0.0)
				if f > 0.0:
					draw_line(rail_dir * RADIUS, rail_dir * 2000.0, Color(r["color"], f / 0.3), 10.0 * f / 0.3 + 2.0)
					draw_line(rail_dir * RADIUS, rail_dir * 2000.0, Color(1, 1, 1, f / 0.3), 2.5)
			"halo":
				draw_arc(Vector2.ZERO, halo_r(rl), 0, TAU, 48, Color(r["color"], 0.12), 2.0)
				for bp in halo_blades(rl):
					var tg: Vector2 = bp.normalized().orthogonal() * 12.0
					var rd: Vector2 = bp.normalized() * 5.0
					draw_colored_polygon(PackedVector2Array([bp + tg, bp + rd, bp - tg, bp - rd]), r["color"])
					draw_circle(bp, 3.0, Color.WHITE)
			"quake":
				var f: float = fx.get("quake", 0.0)
				if f > 0.0:
					var k2 := 1.0 - f / 0.4
					var rad := 150.0 * reach(rl) * (0.3 + 0.7 * k2)
					draw_arc(Vector2.ZERO, rad, 0, TAU, 48, Color(r["color"], 1.0 - k2), 6.0 * (1.0 - k2) + 1.5)
					for i in 8:
						var d2 := Vector2.from_angle(TAU * i / 8 + 0.3)
						draw_line(d2 * RADIUS, d2 * rad + d2.orthogonal() * 8.0 * sin(i * 3.1), Color(0.35, 0.25, 0.15, 1.0 - k2), 3.0)
			"aurora":
				var f: float = fx.get("aurora", 0.0)
				if f > 0.0:
					var cols := [Color(0.4, 1.0, 0.6), Color(0.4, 0.9, 1.0), Color(0.7, 0.6, 1.0), Color(0.4, 0.9, 1.0), Color(0.4, 1.0, 0.6)]
					for i in 5:
						var d2 := dir.rotated((i - 2) * 0.22)
						draw_line(d2 * RADIUS, d2 * 300.0 * reach(rl), Color(cols[i], f / 0.35 * 0.8), 6.0 * f / 0.35 + 1.5)
			"blizzard":
				var rad := 130.0 * reach(rl)
				draw_circle(Vector2.ZERO, rad, Color(r["color"], 0.08))
				for i in 24:
					var a := t * 1.5 + i * 0.7
					var rr := rad * fmod(i * 0.41 + t * 0.2, 1.0)
					draw_circle(Vector2(cos(a), sin(a)) * rr, 2.0, Color(1, 1, 1, 0.8))
			"eclipse":
				var f: float = fx.get("eclipse", 0.0)
				if f > 0.0:
					var k := 1.0 - f / 0.8
					draw_arc(Vector2.ZERO, 40.0 + k * 1400.0, 0, TAU, 96, Color(r["color"], 0.5 * (1.0 - k)), 6.0 * (1.0 - k) + 1.5)
					draw_circle(Vector2.ZERO, RADIUS + 10.0, Color(0, 0, 0, 0.4 * (1.0 - k)))
				# 다른 오브젝트가 방금 화면 연출을 했으면 이 오브젝트 둘레에만 작은 고리
				var fs: float = fx.get("eclipse_small", 0.0)
				if fs > 0.0:
					var ks := 1.0 - fs / 0.5
					draw_arc(Vector2.ZERO, RADIUS + 6.0 + ks * 60.0, 0, TAU, 48, Color(r["color"], 0.5 * (1.0 - ks)), 3.0)
	RxMore.draw_tower(self)


## 물길 바닥: 공격 방향으로 흐르는 물.
func _draw_channel(L: float, w: float) -> void:
	var n := dir.orthogonal() * w
	var a := dir * RADIUS * 0.6
	var b := dir * L
	var wc: Color = Elem.COLORS[Elem.WATER]
	draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(wc, 0.22))
	draw_line(a + n, b + n, Color(wc, 0.6), 2.0)
	draw_line(a - n, b - n, Color(wc, 0.6), 2.0)
	# 흐르는 물결
	for i in 9:
		var f := fmod(t * 0.9 + i / 9.0, 1.0)
		var p := a.lerp(b, f)
		draw_line(p + n * 0.7 + dir * 6.0, p - n * 0.7 + dir * 6.0, Color(0.75, 0.9, 1.0, 0.45 * (1.0 - f)), 2.0)
	draw_arc(b, w, dir.angle() - PI / 2, dir.angle() + PI / 2, 12, Color(0.75, 0.9, 1.0, 0.7), 2.5)


## 부채꼴로 퍼져 나가는 입자(분사·증기).
func _draw_puffs(d: Vector2, rng: float, half: float, n: int, speed: float, c0: Color, c1: Color, r0: float, r1: float) -> void:
	var fan := PackedVector2Array([d * RADIUS * 0.8])
	for k in 9:
		fan.append(d.rotated(lerpf(-half, half, k / 8.0)) * rng)
	draw_colored_polygon(fan, Color(c1, 0.12))
	for i in n:
		var cyc := t * speed + float(i) / n
		var f := fmod(cyc, 1.0)
		var spread := _hash(floorf(cyc) * 7.0 + i) * half * (0.35 + 0.65 * f)
		var p := d.rotated(spread) * (RADIUS + f * (rng - RADIUS))
		draw_circle(p, lerpf(r0, r1, f), Color(c0.lerp(c1, f), 0.9 * (1.0 - f * 0.7)))


## 발사 방향으로 뻗은 물결선(물줄기·덩굴).
func _draw_wave(d: Vector2, length: float, amp: float, freq: float, c: Color, width: float) -> void:
	if length < 2.0:
		return
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var dd := length * i / n
		var off := sin(dd * freq * TAU - t * 14.0) * amp
		pts.append(d * (RADIUS + dd) + d.orthogonal() * off)
	draw_polyline(pts, c, width)
	draw_polyline(pts, Color(1, 1, 1, 0.5), width * 0.35)


## -1~1 의사 난수.
static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0


# ---------- 사거리 미리보기 ----------

## 공격 범위를 ci(전역 좌표 캔버스)에 그린다. 설치·겹치기 전 미리보기와 툴팁용.
## sp: spec() 묶음 {"els", "pat", "plv", "mods"}
## focus: 바뀌는 부분(-2: 공격방식, 0 이상: 그 속성의 반응)만 진하게, 나머지는 옅게
static func draw_range(ci: CanvasItem, o: Vector2, d: Vector2, sp: Dictionary, focus := -1) -> void:
	# 방향을 고를 때 마우스가 설치 지점과 겹치면 방향이 0이 되어 다각형이 깨진다
	if not o.is_finite():
		return
	d = d.normalized() if d.is_finite() and d.length_squared() > 0.0001 else Vector2.RIGHT
	var far := 1600.0
	var els: Dictionary = sp["els"]
	var l: int = sp["plv"]
	var md: Dictionary = sp["mods"]
	var s: float = 1.0 + 0.12 * md.get("size", 0)
	var n: int = 1 + md.get("multi", 0)
	var c := Pat.pcolor(sp["pat"])
	if not els.is_empty():
		c = Elem.COLORS[els.keys()[0]]
	if focus >= 0:
		c.a = 0.35
	for i in n:
		var dd := d.rotated((i - (n - 1) / 2.0) * 0.22)
		match sp["pat"]:
			"spray":
				_r_cone(ci, o, dd, 200.0 * reach(l) * s, 0.35, c)
			"chain":
				_r_cone(ci, o, dd, 280.0 * reach(l) * s, 0.5, c)
			"stream":
				_r_band(ci, o, dd, 0.0, 260.0 * reach(l) * s, 10.0 * s, c)
			"gust":
				_r_band(ci, o, dd, 0.0, 420.0 * s, 34.0 * s, c)
			"laser":
				_r_band(ci, o, dd, 0.0, far, 14.0 * s, c)
			"wall":
				if i == 0:
					var inner := Rect2(Vector2.ZERO, Meta.FIELD).grow(-100.0)  # main.spawn_rock처럼 전장 가장자리 안쪽
					for k in 2 + md.get("multi", 0):
						_r_circle(ci, (o + rock_slot(d, k, l)).clamp(inner.position, inner.end), 28.0 * s, c)
			"vortex":
				# 앞으로 날아가며 줄어드는 띠 (Zone.launch와 같은 계산)
				var wk := 1.0 + 0.12 * mini(els.get(Elem.WIND, 0), 3) * Rules.trait_mul
				var shr := maxf(0.3, 1.0 - 0.15 * (mini(els.get(Elem.WOOD, 0), 3) + mini(els.get(Elem.WIND, 0), 3)) * Rules.trait_mul)
				var r0 := (100.0 + 10.0 * (l - 1)) * s
				var nn := dd.orthogonal()
				var a0 := o + dd * RADIUS
				var b0 := a0 + dd * 420.0 * wk
				var r1 := r0 * (1.0 - 0.6 * shr)
				var vp := PackedVector2Array([a0 + nn * r0, b0 + nn * r1, b0 - nn * r1, a0 - nn * r0])
				ci.draw_colored_polygon(vp, Color(c.r, c.g, c.b, 0.14 * c.a))
				vp.append(vp[0])
				ci.draw_polyline(vp, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)
			"lob":
				_r_band(ci, o, dd, 0.0, LOB_RANGE * reach(l), lob_r(l) * s, c)
			"iron":
				_r_band(ci, o, dd, 0.0, far, 12.0 * s, c)
			"sonic":
				_r_cone(ci, o, dd, 230.0 * reach(l) * s, 0.5, c)
			"clock":
				_r_cone(ci, o, dd, 240.0 * reach(l) * s, 0.7, c)
			"path":
				if i == 0:
					for pts: PackedVector2Array in sp.get("paths", []):
						var g := PackedVector2Array()
						for q in pts:
							g.append(o + q)
						if g.size() >= 2:
							ci.draw_polyline(g, Color(c.r, c.g, c.b, 0.35 * c.a), 12.0 * s)
			"wisp":
				var hm: int = md.get("homing", 0)
				var hf := 2.0 * (1.0 - pow(0.5, hm)) if Rules.mod_decay else float(hm)
				ci.draw_arc(o, Projectile.wisp_seek(hf), 0, TAU, 64, Color(c.r, c.g, c.b, 0.5 * c.a), 1.5)
			"shot":
				var tl := 0
				for e in els:
					tl += els[e]
				var wr := 1.0 + 0.12 * mini(els.get(Elem.WIND, 0), 3) * Rules.trait_mul
				_r_band(ci, o, dd, 0.0, shot_range(tl, md.get("size", 0)) * wr, 6.0 * s, c)
			_:
				_r_band(ci, o, dd, 0.0, far, 6.0 * s, c)
	for r in Elem.reactions_with(els):
		var rl: int = mini(els[r["a"]], els[r["b"]])
		var rc: Color = r["color"]
		if focus != -1 and r["a"] != focus and r["b"] != focus:
			rc.a = 0.35
		match r["id"]:
			"burning":
				_r_band(ci, o, d, 0.0, BURN_RANGE * reach(rl), BURN_R + BURN_R_LV * (rl - 1), rc)
			"steam", "vine", "shock", "styx":
				_r_band(ci, o, d, 0.0, 260.0 * reach(rl), 20.0 + 3.0 * (rl - 1), rc)
			"bell", "silence":
				_r_cone(ci, o, d, 260.0 * reach(rl), 0.6, rc)
			"shatter":
				_r_cone(ci, o, d, 240.0 * reach(rl), 0.5, rc)
			"afterimage":
				_r_band(ci, o, d, 0.0, far, 12.0, rc)
			"rewind":
				_r_cone(ci, o, d, 280.0 * reach(rl), 0.5, rc)
			"plague", "spirit":
				ci.draw_arc(o, 380.0, 0, TAU, 64, Color(rc.r, rc.g, rc.b, 0.5 * rc.a), 1.5)
			"firestorm":
				_r_band(ci, o, d, 0.0, 380.0, 26.0, rc)
			"blizzard":
				_r_circle(ci, o, 130.0 * reach(rl), rc)
			"railgun":
				_r_circle(ci, o, RADIUS + 14.0, rc)
			"halo":
				ci.draw_arc(o, 110.0 * reach(rl), 0, TAU, 48, Color(rc.r, rc.g, rc.b, 0.3 * rc.a), 26.0)
			"quake":
				_r_circle(ci, o, 150.0 * reach(rl), rc)
			"storm":
				_r_band(ci, o, d, 0.0, 360.0 * reach(rl), 100.0, rc)
			"aurora":
				_r_cone(ci, o, d, 300.0 * reach(rl), 0.5, rc)
			"curse":
				ci.draw_arc(o, 320.0 * reach(rl), 0, TAU, 64, Color(rc.r, rc.g, rc.b, 0.5 * rc.a), 1.5)
			"prison":
				_r_band(ci, o, d, 0.0, PRISON_RANGE * reach(rl), PRISON_R + PRISON_R_LV * (rl - 1), rc)
			"mushroom":
				_r_band(ci, o, d, 0.0, MUSH_RANGE * reach(rl), 14.0, rc)
			"eclipse":
				ci.draw_rect(Rect2((Meta.FIELD - ci.get_viewport_rect().size) / 2.0, ci.get_viewport_rect().size), Color(rc.r, rc.g, rc.b, 0.05 * rc.a))  # 보이는 화면 전체 (main.view_rect)
			_:
				RxMore.range_preview(ci, o, d, r["id"], rl, rc)


static func _r_cone(ci: CanvasItem, o: Vector2, d: Vector2, rng: float, half: float, c: Color) -> void:
	var pts := PackedVector2Array([o])
	for k in 13:
		pts.append(o + d.rotated(lerpf(-half, half, k / 12.0)) * rng)
	ci.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.14 * c.a))
	pts.append(o)
	ci.draw_polyline(pts, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)


static func _r_band(ci: CanvasItem, o: Vector2, d: Vector2, from: float, to: float, half_w: float, c: Color) -> void:
	var n := d.orthogonal() * half_w
	var a := o + d * maxf(from, RADIUS)
	var b := o + d * to
	var pts := PackedVector2Array([a + n, b + n, b - n, a - n])
	ci.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.14 * c.a))
	pts.append(a + n)
	ci.draw_polyline(pts, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)


## 가로 벽 미리보기: 중심 c, 공격 방향 d와 수직으로 반길이 half, 두께 반 hw.
static func _r_circle(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	ci.draw_circle(p, r, Color(c.r, c.g, c.b, 0.14 * c.a))
	ci.draw_arc(p, r, 0, TAU, 40, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)


## 선택지 하나를 이 오브젝트에 넣었을 때 바뀌는 점(미리보기 문구)과, 넣은 뒤의 spec.
## card: {"type": "elem"|"pat"|"mod"|"link"|"trig", ...}
func preview(card: Dictionary) -> Array:
	var out := PackedStringArray()
	var sp := spec().duplicate(true)
	if card["type"] in ["elem", "mod", "trig"] and not can_take(card):
		out.append("넣을 수 없음")
		out.append(refuse_text(card))
		return [out, sp]
	match card["type"]:
		"elem":
			var e: int = card["e"]
			var n: int = card["lv"]
			sp["els"][e] = lv(e) + n
			if elements.has(e):
				out.append("%s Lv%d → Lv%d (추가 효과 강화)" % [Elem.NAMES[e], lv(e), lv(e) + n])
			else:
				out.append("%s + %s" % [title(), Elem.NAMES[e]])
				out.append("모든 공격에 추가 효과: " + Elem.rider(e))
				out.append("형태 성질(시험): " + Elem.TRAIT[e])
				var before := roundi((1.0 - 1.0 / tax()) * 100.0)
				var after := roundi((1.0 - 1.0 / (tax() + tax_step)) * 100.0)
				out.append("속성을 겹친 대가: 공격 속도 -%d%% → -%d%%" % [before, after])
			out.append("피해 x%.1f → x%.1f" % [dmg_factor(), dmg_factor() + 1.3 * 0.35 * n])
		"pat":
			var id: String = card["id"]
			if not can_pattern(id) and not pattern_blockers(id).is_empty():
				out.append("넣을 수 없음")
				out.append(refuse_text(card))
			elif not can_pattern(id):
				out.append("넣을 수 없음: 공격방식이 %s(으)로 정해져 있음" % Pat.pname(pattern))
				out.append("같은 공격방식만 넣어 레벨업할 수 있어요")
			elif id == pattern:
				sp["plv"] = plv + 1
				out.append("%s Lv%d → Lv%d" % [Pat.pname(id), plv, plv + 1])
				if id == "path":
					out.append("피해 x%.1f → x%.1f   공격 속도 x%.1f → x%.1f" % [pw(plv), pw(plv + 1), spd(plv), spd(plv + 1)])
					if Pat.path_len(plv + 1) > Pat.path_len(plv):
						out.append("그릴 수 있는 길이 %d → %d (넣으면 다시 그림, 취소하면 그대로)" % [roundi(Pat.path_len(plv)), roundi(Pat.path_len(plv + 1))])
					elif Pat.path_branches(plv + 1) > paths.size():
						out.append("갈래 %d → %d (넣으면 새 갈래를 그림)" % [paths.size(), Pat.path_branches(plv + 1)])
				else:
					out.append("피해 x%.1f → x%.1f   공격 속도 x%.1f → x%.1f   사거리 x%.1f → x%.1f" % [pw(plv), pw(plv + 1), spd(plv), spd(plv + 1), reach(plv), reach(plv + 1)])
			else:
				sp["pat"] = id
				sp["plv"] = 1
				out.append("공격방식: %s → %s" % [Pat.pname(pattern), Pat.pname(id)])
				out.append(Pat.PATTERNS[id]["desc"])
				out.append("한 번 정하면 바꿀 수 없음 (같은 것을 넣으면 레벨업)")
				if id == "path":
					out.append("넣으면 길을 그림: 오브젝트에서 시작해 누른 채 끌기, 꺾기 %d번까지" % Pat.PATH_BENDS)
		"mod":
			var id: String = card["id"]
			sp["mods"][id] = m(id) + 1
			out.append("%s %d → %d" % [Pat.MODS[id]["name"], m(id), m(id) + 1] + (" (최대 %d)" % Rules.max_mod if Rules.max_mod < Rules.NO_CAP else "") + ("  효과 x%.2f → x%.2f" % [mf(id), 2.0 * (1.0 - pow(0.5, m(id) + 1))] if Rules.mod_decay else "") + ("  (이미 들어 있음, 겹쳐서 세짐)" if m(id) > 0 else ""))
			var before := mod_effect(id) if m(id) > 0 else "없음"
			mods[id] = m(id) + 1
			var after := mod_effect(id)
			mods[id] -= 1
			if mods[id] == 0:
				mods.erase(id)
			out.append("%s → %s" % [before, after])
			if m(id) == 0:
				out.append(Pat.MODS[id]["desc"])
		"link":
			var id: String = card["id"]
			var n := link_lv(id)
			if n > 0:
				out.append("%s x%d → x%d (이미 들어 있음, 겹쳐서 세짐)" % [Pat.LINKS[id]["name"], n, n + 1])
				out.append("%s %s → %s" % [LINK_POWER[id], link_value(id, n), link_value(id, n + 1)])
			else:
				out.append(Pat.LINKS[id]["name"])
				out.append(Pat.LINKS[id]["desc"])
		"trig":
			var id: String = card["id"]
			var n := tg(id)
			if n > 0:
				out.append("%s x%d → x%d (이미 들어 있음, 겹쳐서 세짐)" % [Pat.TRIGS[id]["name"], n, n + 1])
				out.append("%s → %s" % [trig_value(id, n), trig_value(id, n + 1)])
			else:
				out.append(Pat.TRIGS[id]["name"])
				out.append(Pat.TRIGS[id]["desc"])
	return [out, sp]


## 이 오브젝트에 든 연계 카드 수.
func link_lv(id: String) -> int:
	match id:
		"prism":
			return prism
		"reso":
			return reso
		"pincer":
			return pincer
	return 0


## 연계 카드를 n장 넣었을 때의 세기 (_check_prisms·dmg_factor·_pincer와 같은 식).
const LINK_POWER := {"prism": "지나가는 탄 피해", "reso": "가까운 오브젝트 하나당 피해", "pincer": "폭발 피해: 구체 최대 체력의"}


static func link_value(id: String, n: int) -> String:
	match id:
		"prism":
			return "+%d%%" % (20 * n)
		"reso":
			return "+%d%%" % (12 * n)
		"pincer":
			return "%d%%" % roundi(Rules.pincer_frac * (1.0 + 0.5 * (n - 1)) * 100.0)
	return ""
