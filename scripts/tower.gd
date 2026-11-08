class_name Tower
extends Node2D
## 설치형 오브젝트. 설치 시 정한 방향으로 공격한다.
## - 공격방식(pattern): 형태. 하나만 갖고, 새 오브젝트는 직선탄.
## - 속성(elements): 효과. 모든 공격에 부가효과가 붙는다. 종류 수 상한은 Rules.max_elems.
## - 강화(mods): 공격방식에 붙는 변형. 종류마다 Rules.max_mod개, 합쳐서 Rules.mod_total개까지.
## - 연계: 협공, 프리즘, 공명.
## - 발동(trigs): 조건이 맞을 때 추가로 터지는 공격 (여진, 선봉, 축적, 삼연, 마무리, 호응).

const RADIUS := 18.0

var new_reactions := {}  # 이번 실행에서 새로 생긴 조합. 인스펙터에서 읽을 때까지 유지
var elements := {}  # 속성 -> 겹친 수(=그 속성 레벨)
var order: Array[int] = []  # 넣은 순서
var pattern := Pat.DEFAULT
var plv := 1  # 공격방식 레벨
var mods := {}  # 강화 id -> 겹친 수
const PRISM_FX_GAP := 0.8  # 프리즘 연출(번쩍·파편·육각형) 최소 간격 초
var pincer := 0  # 협공: 여러 오브젝트가 함께 맞힌 구체에 표식 폭발
var reso := 0
var trigs := {}  # 발동 id -> 겹친 수
var echo_cd := 0.0  # 여진: 다시 터질 때까지
var focus_t := 0.0  # 중앙 기술 집중: 공격 속도 배율 남은 시간 (Skill)
var jam_t := 0.0  # 방해 구체(그림자·표적)가 멈춘 남은 시간: 공격하지 않는다
var jam_imm := 0.0  # 멈춤이 풀린 뒤 다시 멈추지 않는 시간
var leech_n := 0  # 흡수 구체에게 빼앗긴 공격 속도 겹침 (하나에 Rules jam_leech)
var leech_t := 0.0  # 그 겹침이 풀릴 때까지
var charge := 0.0  # 축적: 모은 처치 (웨이브가 넘어가도 유지)
var third_n := 0  # 삼연: 지금까지 쏜 공격 수
var fire_boost := 1.0  # 지금 나가는 공격의 발동 배율 (축적·삼연, attack() 한 번 안에서만)
var fire_size := 1.0
var fire_key := ""  # 그 배율의 피해 출처 (trig:charge·trig:third)
var burst_t := 0.0  # 계속 뿜는 공격: 발동 배율이 남은 시간
var burst_mul := 1.0
var burst_size := 1.0
var burst_key := ""
var cont_acc := 0.0  # 계속 뿜는 공격: 공격 한 번으로 치는 시간 모으기
var answer_cd := 0.0  # 호응: 다시 쏠 때까지
var star_sum := 0.0  # 별: 모은 별빛 (다 차면 초신성)
var star_e := {}  # 별빛을 준 둘레 오브젝트의 속성 -> 모은 양 (초신성에 섞인다)
var nova_fx := 0.0  # 초신성 표시 남은 시간
var nova_pos := Vector2.ZERO  # 그 자리 (전역)
var nova_from := Vector2.ZERO  # 터질 때 별 자리 (전역, 빛줄기 시작)
var nova_aim: Orb = null  # 별빛이 NOVA_WARN 넘으면 터질 자리 예고 (표시용, NOVA_AIM_T마다 다시 고름)
var nova_aim_t := 0.0
var in_nova := false  # 초신성 피해 중 (별빛을 다시 모으지 않게)
var feed_fx := {}  # 별빛을 준 오브젝트 -> 빛줄 남은 시간 (표시용)
var notify_cd := 0.0  # 반응이 터졌다고 둘레에 알리는 간격 (호응)
var wind_buff := 0.0  # 둘레 바람 오브젝트가 주는 공격 속도 (main이 매 계산마다 정함)
var eff := {}  # 지금 쓰는 속성 (매 프레임 갱신)
var dir := Vector2.RIGHT
var reflex_target: Orb = null
var aim := Vector2.RIGHT  # 유도 강화로 살짝 돈 실제 공격 방향
var cd := {}  # 공격별 쿨다운
var fx := {}  # 공격별 이펙트 남은 시간
var t := 0.0
var dealt := 0.0  # 이번(또는 지난) 웨이브에 준 피해
var rx_dealt := 0.0  # 그중 특수 반응 피해 (측정·표시용)
var trail_hit := {}  # 지나간 자리 장판: 구체 → 마지막으로 맞은 sim_id (띠가 겹쳐도 한 조각에 한 번)
var fx_a := 1.0  # 이 오브젝트 탄·장판 진하기 (피해 몫이 작을수록 옅게, main._soften_fx)
var run_dealt := 0.0  # 지난 웨이브들까지 합친 피해 (게임 오버 요약용)
## 피해 출처 (DPS 표·판 기록 통계). 키: "hit"(직접 타격, breakdown()이 배율별로 나눔), elem:fire, share:electric(특징), mod:split, link:pincer ...
var src := {}  # 이번(또는 지난) 웨이브, 날것
var chase_n := {}  # 구체 id -> 이 오브젝트의 유도·혼불 탄 몇 개가 쫓는지 (Projectile._chase)
var run_src := {}  # 지난 웨이브들까지, 나눈 값
var tag := ""  # 지금 피해를 어느 출처로 셀지 (반응·반응 발사체·분열 파편). 비면 "hit"
var recoil := 0.0  # 발사 반동
var place_pop := 0.0  # 설치·겹치기 순간 커졌다 줄어드는 연출
var rocks: Array = []
var wisps: Array = []  # 떠 있는 범위 제한 혼불
var in_zone := false  # 지금 장판(바닥 효과)으로 때리는 중인지 (후반 구체 갑옷·흐림은 장판 피해를 그대로 받는다)
var in_rx := false  # 지금 특수 반응 공격 중인지 (hit 피해 계산용)
var clock_ph := 0.0  # 시계침 위상
var ring_t0 := 0.0  # 울림 음파 초당 상한: 이번 1초 구간 시작
var ring_n := 0  # 그 구간에 터뜨린 수
var clock_hit := {}  # 시계침: 이번 한 번 훑는 동안 맞힌 구체 ([바늘 번호, 구체] -> true, 다중 발사 바늘은 따로 센다)
var light_cd := 0.0  # 빛 꿰뚫음 다시 쓸 때까지 (Share.pierce)
var mirror_cd := 0.0  # 환영 비춤 다시 쓸 때까지 (Share.mark)
var mirror_src: Object = null  # 옆 환영 오브젝트가 전달한 효과: 다음 공격에 그 오브젝트 효과 (Share.reflect)
var mirror_t := 0.0
var mirror_f := 0.0
var aff_cd := 0.0  # 상성 둘레 효과(눈보라·비바람·증기) 다시 쓸 때까지 (Share.aff_hit)
var side_cd := 1.0  # 보조 공격까지 남은 시간 (Side)
var side_n := 0  # 지난 큰 보조 공격 뒤 보조 공격 수 (Side)
var side_big_fx := 0.0  # 큰 보조 공격 번쩍임
var side_mix_n := 0  # 일식(빛+어둠) 작은 일식까지 센 보조 공격 수 (Side)
var chain_end := Vector2.ZERO  # 연쇄 번개가 마지막으로 친 자리
var later: Array = []  # [남은 초, Callable]: 잠시 뒤 효과 (시간 되풀이, Share.on_hit)
var _abilities_port: BinduAbilities
var _combat_port: BinduCombat
var _hud_port: BinduHud
var _multiplayer_port: BinduMultiplayer
var _spawning_port: BinduSpawning
var _viewport_port: BinduViewport
var main: BinduSession:
	set(value):
		main = value
		_abilities_port = value.abilities_system if value != null else null
		_combat_port = value.combat_system if value != null else null
		_hud_port = value.hud_system if value != null else null
		_multiplayer_port = value.multiplayer_system if value != null else null
		_spawning_port = value.spawning_system if value != null else null
		_viewport_port = value.viewport_system if value != null else null
var owner_id := 0  # 협동 멀티플레이: 놓은 사람 id (0이면 혼자 하는 판)
var net_id := 0  # 협동 멀티플레이: 기기끼리 같은 오브젝트를 찾는 번호
var req_e := -1  # 협동: 주인이 요청한 속성 (-1 없음). 다른 사람이 그 속성 카드만 넣을 수 있다
var dice_x := 1.0  # 주사위 강화: 다음 공격까지 직접 피해에 곱하는 배율 (roll_dice)
var dice_miss := 0  # 마지막 대박(6) 뒤로 굴린 수
var dice_t := 0.0  # 계속 공격하는 형태: 다음에 굴릴 때까지 남은 초
var bounce_cd := 0.0  # 탄이 아닌 공격의 튕김 탄 간격 (공격 속도로 줄어듦)


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
static var harmony_cap := 0.2  # 조화 특성이 올려 주는 공격 속도 상한 (+20%, 온라인 패치 perks.harmony_cap)


## 쌓기 대가: 속성 종류 하나 늘 때마다 공격 속도 감소 (기본 15%, 버전 3은 25%).
func tax() -> float:
	return tax_of(order.size())


## 속성 n종일 때의 대가. 조화(tax_step이 규칙 값보다 작음)가 줄여 주는 몫은 공격 속도 +harmony_cap까지만
## (2026-11-01: 도파민은 속성 종류 상한이 없어 조화가 끝없이 커졌음. 랭크는 3종 +13%라 상한에 안 닿음)
static func tax_of(n: int) -> float:
	var t := 1.0 + tax_step * (n - 1)
	if tax_step < Rules.tax_step and harmony_cap > 0.0:
		t = maxf(t, (1.0 + Rules.tax_step * (n - 1)) / (1.0 + harmony_cap))
	return t


## 바람 속성: 이 거리 안의 다른 오브젝트 공격 속도 +Rules wind_buff(8%)/바람 레벨. 한 오브젝트에는 가장 큰 바람 하나만.
const WIND_RANGE := 240.0
static var SHADE_T := 3.0  # 어둠 형태 성질 그림자 표식 시간 (2026-10-31, 끌기 대신: 블랙홀과 겹치지 않게)


## 공격 속도 배율: 특성 × 속사 × 바람 버프 ÷ 속성을 겹친 대가 (모두 곱한다). 특수 반응 공격도 이 배율.
func spd_k() -> float:
	return spd_mul * (1.0 + Rules.rapid_k * mf("rapid")) * (1.0 + wind_buff) * skill_k() / tax()


## 중앙 기술 집중·흡수 구체가 바꾼 공격 속도 배율.
func skill_k() -> float:
	var k := Rules.t("skill_focus_spd") if focus_t > 0.0 else 1.0
	if leech_n > 0:
		k *= maxf(0.1, 1.0 - Rules.t("jam_leech") * leech_n)
	return k


## 방해 구체가 이 오브젝트를 멈춘다 (풀린 뒤 jam_imm 동안은 다시 안 멈춤). 멈췄으면 true.
func jam(sec: float) -> bool:
	if jam_t > 0.0 or jam_imm > 0.0:
		return false
	jam_t = sec
	jam_imm = sec + Rules.t("jam_imm")
	if main:
		_spawning_port.burst(position, Color(0.55, 0.45, 0.7), 10, 120.0)
	return true


## 흡수 구체를 맞혔다: 공격 속도 하나 더 빼앗김.
func leech() -> void:
	if leech_t > Rules.t("jam_leech_t") - 0.5:
		return  # 0.5초에 한 겹만 (계속 뿜는 공격이 한 번에 다 빼앗기지 않게)
	leech_n = mini(leech_n + 1, int(Rules.t("jam_leech_max")))
	leech_t = Rules.t("jam_leech_t")


## 발동 카드 수.
func tg(id: String) -> int:
	return trigs.get(id, 0)


## 여진(echo): 탄 수 3(+1/장), 탄 피해(파편 기본의 배), 다시 터질 때까지.
## 선봉: 체력 70% 이상 구체에 피해 x1.4(+0.15/장), 보스는 절반.
const TRIG_MAX := 5  # 발동 카드는 종류마다 5장까지
const ECHO_N := 3
const ECHO_DMG := 0.8
const ECHO_CD := 0.5


static func van_mul(n: int) -> float:
	return Rules.t("van_mul") + Rules.t("van_add") * (n - 1)


## 축적(1~5장): 필요한 처치, 강타 피해, 크기. 삼연(1~5장): 3번째 공격 피해. 호응·마무리는 Rules.
static var CHARGE_NEED := [15, 13, 11, 10, 9]  # 축적 강타까지 필요한 처치 (장 수별)
static var CHARGE_MUL := [5.0, 6.0, 7.0, 7.5, 8.0]  # 축적 강타 피해 배율 (장 수별)
static var THIRD_MUL := [1.8, 2.4, 2.9, 3.3, 3.6]  # 삼연 3번째 공격 피해 배율 (장 수별)
const CONT_BOOST := ["spray", "stream", "clock", "wisp"]  # 쏘는 순간이 없거나 오래 남는 공격: 발동 배율을 잠깐 동안 건다
static var CONT_IV := 0.5  # 그 공격은 이만큼을 공격 한 번으로 센다


static func _at(a: Array, n: int) -> float:
	return float(a[clampi(n, 1, a.size()) - 1])


func charge_need() -> int:
	return int(_at(CHARGE_NEED, tg("charge")))


static func charge_mul(n: int) -> float:
	return _at(CHARGE_MUL, n) * Rules.t("charge_k")


static func third_mul(n: int) -> float:
	return _at(THIRD_MUL, n) * Rules.t("third_k")


static func finish_mul(n: int) -> float:
	return Rules.t("finish_mul") + Rules.t("finish_add") * (n - 1)


static func answer_dmg(n: int) -> float:
	return Rules.t("answer_dmg") + Rules.t("answer_add") * (n - 1)


## 축적: 둘레에서 구체가 죽었다 (main 처치 처리에서). 특수 2, 보스 8.
func add_charge(o: Orb) -> void:
	if tg("charge") <= 0:
		return
	charge = minf(charge + (8.0 if o.kind == Orb.Kind.BOSS else 1.0 if o.kind == Orb.Kind.NORMAL else 2.0), charge_need())


## 공격 하나를 쏠 때 축적·삼연 배율 [피해, 크기, 출처]. commit이면 센다(삼연 수·축적 비움).
## 축적은 둘레에 구체가 있을 때만 쓴다 (빈 곳에 강타를 버리지 않게).
func _fire_mul(commit: bool) -> Array:
	var mul := 1.0
	var size := 1.0
	var key := ""
	var third := tg("third") > 0 and (third_n + 1) % 3 == 0
	if third:
		mul *= third_mul(tg("third"))
		size *= Rules.t("third_size")
		key = "trig:third"
	var strike: bool = tg("charge") > 0 and charge >= charge_need() and main != null and not _combat_port.near(position, 450.0).is_empty()
	if strike:
		var n := tg("charge")
		mul *= charge_mul(n)
		size *= 1.6 + 0.1 * (n - 1)
		key = "trig:charge"
	if commit:
		if tg("third") > 0:
			third_n += 1
		if strike:
			charge = 0.0
			_spawning_port.burst(position, Pat.TRIG_COLOR, 24, 220.0)
		if key != "":
			_notify_allies(position + aim * 120.0)
	return [mul, size, key]


func _set_fire(f: Array) -> void:
	fire_boost = f[0]
	fire_size = f[1]
	fire_key = f[2]


## 호응: 둘레(answer_r 안) 호응 오브젝트들이 p 쪽으로 한 발씩 쏜다.
func _notify_allies(p: Vector2) -> void:
	if main == null:
		return
	for t2 in main.towers.get_children():
		if t2 != self and t2.tg("answer") > 0 and t2.answer_cd <= 0.0 and t2.position.distance_to(position) < Rules.t("answer_r"):
			t2._answer(p)


func _answer(p: Vector2) -> void:
	answer_cd = Rules.t("answer_cd")
	var d := (p - position).normalized() if p.distance_to(position) > 1.0 else dir
	var pr: Projectile = _spawning_port.spawn_proj(self, "shot", plv, d)
	pr.src = "trig:answer"
	pr.dmg *= answer_dmg(tg("answer"))
	pr.form_init()


## 웨이브 시작 (main._start_wave).
func wave_begin() -> void:
	echo_cd = 0.0
	focus_t = 0.0
	jam_t = 0.0
	jam_imm = 0.0
	leech_n = 0
	leech_t = 0.0


## 투척 장판: 느린 탄이 날아간 길에 띠 장판이 남는다 (Zone.trail). 던지는 간격, 날아가는 거리(Lv1, reach 배율),
## 띠 반지름(Lv1, 레벨마다 +), 점마다 남는 시간, 띠 안의 구체에 초당 피해(Lv1).
static var LOB_IV := 1.6
static var LOB_RANGE := 420.0
static var LOB_R := 30.0
static var LOB_R_LV := 3.0
static var LOB_LIFE := 2.5
static var LOB_DPS := 3.4
## 빙결 감옥(얼음+어둠): 얼음 덩이가 날아간 길에 얼음 띠. 띠에 처음 닿은 구체를 멈추고 받는 피해 +50%.
static var PRISON_IV := 7.0
static var PRISON_RANGE := 300.0
static var PRISON_R := 44.0
static var PRISON_R_LV := 4.0
static var PRISON_LIFE := 1.2
## 독버섯(독+나무): 버섯이 굴러가며 MUSH_GAP마다 지뢰를 떨군다 (오브젝트당 4+레벨 개까지).
static var MUSH_IV := 2.5
static var MUSH_RANGE := 270.0
static var MUSH_GAP := 90.0
## 장작 반응(불+나무): 굴러간 길에 불 장판. 반응 피해라 _hurt + 화상.
static var BURN_IV := 2.2
static var BURN_RANGE := 320.0
static var BURN_R := 32.0
static var BURN_R_LV := 3.0
static var BURN_LIFE := 3.0
static var BURN_DPS := 4.5


static func lob_r(l: int) -> float:
	return LOB_R + LOB_R_LV * (l - 1)


## 공격방식 Lv1의 공격 간격(초). attack()과 같은 값. 분사는 계속 뿜어서 없음, 시계침은 한 번 훑는 시간.
## (온라인 패치 rules "Tower.BASE_IV.<공격방식>")
static var BASE_IV := {"shot": 0.5, "thorn": 0.35, "gust": 1.5, "shard": 0.9, "iron": 1.5, "stream": 1.0, "chain": 1.3,
	"wall": 3.5, "vortex": 5.0, "laser": 2.0, "lob": 1.6, "sonic": 1.0, "clock": 0.8, "wisp": 0.6}

## 공격방식 한 번 맞힐 때의 기본 피해(Lv1, 배율 전). attack()·projectile.gd가 이 값을 쓴다 (온라인 패치 rules "Tower.HIT.<공격방식>").
## 시계침·벽·블랙홀·투척 장판은 Rules 키(clock_dmg·wall_dmg·vortex_end)와 LOB_DPS.
static var HIT := {
	"shot": 2.4,  # 직선탄 한 발
	"thorn": 0.85,  # 관통 연사 한 발
	"gust": 2.2,  # 돌풍 한 번
	"shard": 3.0,  # 파편탄 한 발 (파편은 PROJ frag_dmg)
	"iron": 1.7,  # 철구 한 발
	"wisp": 1.15,  # 혼불 한 번 때릴 때
	"chain": 2.2,  # 연쇄 번개 한 번 튈 때
	"laser": 3.4,  # 레이저 한 번
	"sonic": 2.6,  # 음파 가까이 (끝에서는 SHAPE sonic_far만큼 약함)
	"spray": 5.5,  # 분사 초당
	"stream": 3.0,  # 물줄기 뿜는 동안 초당
}
## 공격 모양 (온라인 패치 rules "Tower.SHAPE.<이름>"). 길이는 공격방식 레벨 사거리·range_<id>·크기 강화를 곱한다.
static var SHAPE := {
	"spray_len": 200.0,  # 분사 길이
	"spray_ang": 0.35,  # 분사 부채꼴 반각(라디안)
	"stream_len": 260.0,  # 물줄기 길이
	"stream_w": 10.0,  # 물줄기 판정 반폭
	"stream_t": 0.6,  # 물줄기 한 번 뿜는 시간(초)
	"stream_stop": 60.0,  # 물줄기 경직(멈춰 세우는 세기)
	"chain_len": 280.0,  # 연쇄 번개 첫 대상 거리
	"chain_ang": 0.5,  # 연쇄 번개 첫 대상 찾는 반각(라디안)
	"chain_jump": 110.0,  # 연쇄 번개 튀는 거리
	"chain_n": 3,  # 연쇄 번개 튀는 수 (+공격방식 레벨 +튕김)
	"sonic_len": 230.0,  # 음파 길이
	"sonic_ang": 0.5,  # 음파 부채꼴 반각(라디안)
	"sonic_far": 0.5,  # 음파 끝에서 줄어드는 피해 몫
	"clock_len": 240.0,  # 시계침 길이
	"clock_w": 10.0,  # 시계침 판정 반폭
	"clock_arc": 0.7,  # 시계침 왕복 반각(라디안)
	"clock_sweep": 1.6,  # 시계침 한 번 왕복 시간(초, 공격 속도로 나눔)
}
const HIT_DESC := {
	"shot": "한 발", "thorn": "한 발, 모두 뚫음", "gust": "한 번, 모두 뚫음", "shard": "한 발, 파편 3개는 %s씩", "iron": "한 발, 모두 뚫음",
	"wisp": "혼불마다 공격 간격에 한 번", "chain": "한 번 튈 때", "laser": "한 번, 모두 뚫음", "sonic": "가까이, 끝에서는 절반",
	"clock": "한 번 훑을 때", "vortex": "터질 때 + 모은 피해, 안에서 초당 %s", "lob": "지나간 띠 안 초당, %s초 남음", "spray": "초당, 계속 뿜음",
	"stream": "뿜는 동안 초당, %s초", "wall": "벽에 막힌 동안 초당, 무너질 때 둘레 %s",
}


## 공격방식 기본 피해와 설명 [피해, 글] (정보창).
static func base_hit(p: String) -> Array:
	var d: String = HIT_DESC.get(p, "")
	match p:
		"clock": return [Rules.t("clock_dmg"), d]
		"wall": return [Rules.t("wall_dmg"), d % Rules.fmt("{wall_break}")]
		"vortex": return [Rules.t("vortex_end"), d % Rules.fmt("{vortex_dmg}")]
		"lob": return [LOB_DPS, d % str(LOB_LIFE)]
		"shard": return [HIT.shard, d % str(Projectile.PROJ.frag_dmg)]
		"stream": return [HIT.stream, d % str(SHAPE.stream_t)]
	return [HIT.get(p, 1.0), d]




## 범위 제한 혼불이 한꺼번에 떠 있는 수: 2 + 다중 발사.
func wisp_cap() -> int:
	return 2 + roundi(mf("multi"))


## 공격 간격(초, 공격 속도 배율까지). 분사는 0.
func attack_iv() -> float:
	return BASE_IV.get(pattern, 0.0) / spd(plv) / pspd()


## 공격방식 공격 속도 배율: spd_k × 공격방식별 패치 배율(spd_<id>).
func pspd() -> float:
	return spd_k() * Rules.t("spd_" + pattern)


## 공격방식 사거리 배율: reach × 공격방식별 패치 배율(range_<id>).
func rr(l: int) -> float:
	return reach(l) * Rules.t("range_" + pattern)


static func rr_of(pat: String, l: int) -> float:
	return reach(l) * Rules.t("range_" + pat)


## 공격 속도 배율을 이루는 것들 [이름, 배율] (1이 아닌 것만).
func spd_parts() -> Array:
	var out := []
	if order.size() > 1:
		out.append(["속성 %d종" % order.size(), 1.0 / tax()])
	if m("rapid") > 0:
		out.append(["속사", 1.0 + Rules.rapid_k * mf("rapid")])
	if wind_buff > 0.0:
		out.append(["바람 버프", 1.0 + wind_buff])
	if spd_mul != 1.0:
		out.append(["특성", spd_mul])
	if focus_t > 0.0:
		out.append(["집중", Rules.t("skill_focus_spd")])
	if leech_n > 0:
		out.append(["흡수당함", maxf(0.1, 1.0 - Rules.t("jam_leech") * leech_n)])
	if Rules.t("spd_" + pattern) != 1.0:
		out.append(["공격방식 보정", Rules.t("spd_" + pattern)])
	return out


## 오브젝트 정보 한 줄: 최종 공격 속도·간격.
func spd_line() -> String:
	var k := pspd()
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
	if auto_aim():
		return "%d 안 전방위 자동 조준" % roundi(reflex_range()) + (" (폭풍 바람에 따라 변함)" if MapRule.on() and MapRule.is_map("storm") else "")
	var l := plv
	var s := sz()
	match pattern:
		"shot", "gust", "stream": return "화면 끝까지 (%d부터 약해짐%s)" % [roundi(far_start()), ", 속성 레벨 합이 오를수록 멀리" if pattern == "shot" else ""]
		"chain": return "화면 끝까지 (%d부터 약해짐, 튀는 거리 %d)" % [roundi(far_start()), roundi(SHAPE.chain_jump * s)]
		"spray": return "%d" % roundi(SHAPE.spray_len * rr(l) * s)
		"sonic": return "%d" % roundi(sonic_r(l))
		"clock": return "%d" % roundi(SHAPE.clock_len * rr(l) * s)
		"lob": return "화면 끝까지 (%d부터 약해짐, 지나간 띠 반지름 %d)" % [roundi(far_start()), roundi(lob_r(l) * s)]
		"vortex": return "%d 안 구체 무리에 (우물 반지름 %d)" % [roundi(well_range()), roundi((100.0 + 10.0 * (l - 1)) * s)]
		"wall": return "앞 %d~ (벽 %d개)" % [roundi(90.0 * rr(l)), 2 + roundi(mf("multi"))]
		"wisp": return "추적 범위 %d · 혼불 %d개" % [roundi(Projectile.wisp_leash(mf("homing"), rr(l))), wisp_cap()]
		"shard": return "화면 끝까지 (파편 130)" if m("homing") == 0 else "%d (유도, 파편 130)" % roundi(Projectile.HOMING_TRAVEL)
	if m("homing") > 0 and pattern in Pat.PROJECTILE:
		return "%d (유도)" % roundi(Projectile.HOMING_TRAVEL)
	return "화면 끝까지"


## 한 번 공격의 피해 계산 (정보창 기본 줄·자세히 줄이 같은 값을 쓴다).
func hit_calc() -> Dictionary:
	var els: Dictionary = eff if not eff.is_empty() else elements
	var bh: Array = base_hit(pattern)
	var f := dmg_k(false)
	var one: float = bh[0] * pw(plv) * f
	var shots := 1.0 + mf("multi")
	var mk_on := m("multi") > 0 and not pattern in ["wall", "vortex", "lob"]  # 이 셋은 한 발 피해가 줄지 않는다
	if mk_on:
		one *= multi_k()
	if pattern == "spray" or pattern == "stream":
		one *= pspd()  # 계속 뿜는 공격은 공격 속도만큼 초당 피해가 는다
	var wood: float = 1.0 + Rules.wood_dmg * mini(els.get(Elem.WOOD, 0), int(Rules.wood_cap))
	one *= wood
	# 금속: 맞힌 피해 +metal_dmg/레벨 (2026-11-01 예전 고정 +0.4/레벨은 후반에 거의 0이었다)
	one *= final_damage_mul()
	var metal: float = one * Rules.metal_dmg * els.get(Elem.METAL, 0)
	return {"one": one, "metal": metal, "bh": bh, "f": f, "mk_on": mk_on, "wood": wood, "shots": shots}


## 치명타 [확률(0~1), 배율 글자]. 빛이 없으면 확률 0.
func crit_info() -> Array:
	var els: Dictionary = eff if not eff.is_empty() else elements
	var light: int = els.get(Elem.LIGHT, 0)
	return [minf(Rules.light_ch * light, Rules.light_max) if light > 0 else 0.0, Rules.fmt("{light_mul}")]


## 정보창 기본(간단히) 줄: 피해·공격 속도·치명타 숫자만. [글자, 색, 그림 id]
func basic_lines() -> Array:
	var out := []
	var hc := hit_calc()
	var dmg := "피해 %s" % tip_num(hc["one"] + hc["metal"])
	if hc["shots"] > 1.0 and pattern != "wall":
		dmg += "  × %s발" % tip_num(hc["shots"])
	if pattern in ["spray", "stream"]:
		dmg += " /초"
	out.append([dmg, Color(1, 0.9, 0.5), "dmg"])
	var iv := attack_iv()
	var k := pspd()
	var pc := roundi((k - 1.0) * 100.0)
	var rate := ("초당 %.2f번" % (1.0 / iv)) if iv > 0.0 else "계속 뿜음"
	if pc != 0:
		rate += "  (%s%d%%)" % ["+" if pc > 0 else "", pc]
	out.append([rate, Color(0.6, 0.9, 1.0), "rate"])
	var ci := crit_info()
	if ci[0] > 0.0:
		out.append(["치명타 %d%%  × %s" % [roundi(ci[0] * 100.0), ci[1]], Elem.COLORS[Elem.LIGHT], "e:%d" % Elem.LIGHT])
	return out


## 정보창 숫자: 100 넘으면 정수, 아니면 소수 한 자리.
static func tip_num(v: float) -> String:
	if v >= 100.0:
		return str(roundi(v))
	return ("%.1f" % v).trim_suffix(".0")


## Shift 상세 정보 [글자, 색].
func detail_lines() -> Array:
	var out := []
	var dim := Color(1, 1, 1, 0.65)
	var els: Dictionary = eff if not eff.is_empty() else elements
	var hc := hit_calc()
	var bh: Array = hc["bh"]
	var f: float = hc["f"]
	var one: float = hc["one"]
	var metal: float = hc["metal"]
	var wood: float = hc["wood"]
	var mk_on: bool = hc["mk_on"]
	var shots: float = hc["shots"]
	out.append(["공격력: %.1f  (%s)" % [one + metal, bh[1]], Color(1, 0.9, 0.5), "dmg"])
	var parts := PackedStringArray(["기본 %.2f" % bh[0], "공격방식 Lv%d x%.2f" % [plv, pw(plv)], "피해 배율 x%.2f" % f])
	if mk_on:
		parts.append("다중 발사 한 발 x%.2f" % multi_k())
	if wood > 1.0:
		parts.append("나무 x%.2f" % wood)
	if metal > 0.0:
		parts.append("금속 x%.2f" % (1.0 + Rules.metal_dmg * els.get(Elem.METAL, 0)))
	out.append(["  " + " · ".join(parts), dim])
	var fp := PackedStringArray()
	var tl := total_level()
	fp.append("기본 x%.2f" % Rules.t("dmg_base"))
	if tl > 1:
		fp.append("레벨 합 %d x%.2f" % [tl, 1.0 + Rules.t("dmg_sum") * (tl - 1)])
	if main and main.towers.get_child_count() > 1:
		fp.append("오브젝트 수 x%.2f" % (1.0 + Rules.crowd_bonus(main.towers.get_child_count())))
	if dmg_mul != 1.0:
		fp.append("특성 x%.2f" % dmg_mul)
	if main and _abilities_port.on_ley(self):
		fp.append("기맥 x%.2f" % (1.0 + Rules.t("ley_dmg")))
	out.append(["  피해 배율: " + " · ".join(fp) + " (공명·강화·패치 포함 x%.2f)" % f, dim])
	if shots > 1.0:
		out.append(["한 번에 %.2f개 (다중 발사)" % shots if pattern != "wall" else "벽 최대 %d개 (다중 발사)" % (2 + roundi(mf("multi"))), Color(1, 0.85, 0.45)])
	out.append([spd_line(), Color(0.6, 0.9, 1.0), "rate"])
	var sp := spd_parts_text()
	if sp != "":
		out.append(["  " + sp + " (모두 곱함)", dim])
	if BASE_IV.has(pattern):
		out.append(["  기본 간격 %.2f초 ÷ 공격방식 Lv%d x%.2f" % [BASE_IV[pattern], plv, spd(plv)], dim])
	out.append(["사거리: " + range_text(), Color(0.75, 1, 0.75), "range"])
	var ci := crit_info()
	if ci[0] > 0.0:
		out.append(["치명타: %d%% 확률로 피해 %s배" % [roundi(ci[0] * 100.0), ci[1]], Elem.COLORS[Elem.LIGHT], "e:%d" % Elem.LIGHT])
	var mp := PackedStringArray()
	if m("pierce") > 0:
		mp.append("관통 %.2f개" % mf("pierce") if pattern in Pat.PROJECTILE else "관통 피해 x%.2f" % (1.0 + Rules.t("pierce_dmg") * mf("pierce")))
	if m("bounce") > 0:
		mp.append("튕김 %.2f번" % mf("bounce") if pattern in Pat.PROJECTILE or pattern == "chain" else "튕김 탄 %d개/%.1f초" % [mn("bounce"), bounce_iv()])
	if m("split") > 0:
		mp.append("분열 %d%%" % roundi(split_ch() * 100.0))
	if m("size") > 0:
		mp.append("크기 x%.2f" % sz())
	if m("dice") > 0:
		mp.append("주사위 %d개 · 대박까지 최대 %d번" % [dice_n(), maxi(1, dice_pity() - dice_miss)])
	if not mp.is_empty():
		out.append(["강화: " + " · ".join(mp), Color(1, 0.85, 0.45), "k:mod"])
	return out


## 설명창 그림용 피해 내역. chain: 곱셈 사슬 [값 글, 이름] (마지막은 결과), mul: 피해 배율 내역 [이름, 배율, 그림 id], f: 피해 배율 전체.
func dmg_factors() -> Dictionary:
	var els: Dictionary = eff if not eff.is_empty() else elements
	var hc := hit_calc()
	var bh: Array = hc["bh"]
	var chain := [[tip_num(bh[0]), "기본"]]
	if plv > 1:
		chain.append(["×%.2f" % pw(plv), "Lv%d" % plv])
	chain.append(["×%.2f" % hc["f"], "배율"])
	if hc["mk_on"]:
		chain.append(["×%.2f" % multi_k(), "한 발"])
	if hc["wood"] > 1.0:
		chain.append(["×%.2f" % hc["wood"], Elem.NAMES[Elem.WOOD]])
	if hc["metal"] > 0.0:
		chain.append(["×%.2f" % (1.0 + Rules.metal_dmg * els.get(Elem.METAL, 0)), Elem.NAMES[Elem.METAL]])
	chain.append(["= " + tip_num(hc["one"] + hc["metal"]), ""])
	var mul := [["기본", Rules.t("dmg_base"), "dmg"]]
	var tl := total_level()
	if tl > 1:
		mul.append(["레벨 합 %d" % tl, 1.0 + Rules.t("dmg_sum") * (tl - 1), "k:elem"])
	if main and main.towers.get_child_count() > 1:
		mul.append(["오브젝트 %d개" % main.towers.get_child_count(), 1.0 + Rules.crowd_bonus(main.towers.get_child_count()), "i:crowd"])
	if dmg_mul != 1.0:
		mul.append(["특성", dmg_mul, "k:perk"])
	if main and _abilities_port.on_ley(self):
		mul.append(["기맥 위", 1.0 + Rules.t("ley_dmg"), "k:link"])
	return {"chain": chain, "mul": mul, "f": hc["f"]}


func wind_range() -> float:
	return Rules.t("wind_range") * reach_mul


static func pw(l: int) -> float:
	return (1.0 + Rules.lv_dmg * (l - 1)) * dmg_mul


static func spd(l: int) -> float:
	return 1.0 + Rules.lv_spd * (l - 1)


static func reach(l: int) -> float:
	return (1.0 + Rules.lv_reach * (l - 1)) * reach_mul


## 직선탄 사거리: 속성 레벨 합 n으로 늘어난다 (직선탄은 공격방식 레벨이 늘 1). 원거리 특성·크기 강화 포함, 바람(멀리)은 쏠 때 따로.
static func shot_range(n: int, size_n: float) -> float:
	return (Rules.t("shot_range") + Rules.t("shot_range_lv") * maxi(n - 1, 0)) * reach_mul * (1.0 + Rules.size_k * size_n) * Rules.t("range_shot")


## 방향성 공격(직선탄·돌풍·물줄기·연쇄 번개·투척 장판)은 화면 끝까지 닿고, 감소 시작 거리부터 far_len 동안 피해가 far_min까지 곧게 줄어든다.
## 투척 장판은 탄이 끝까지 날아가고, 예전 사거리 너머에 남긴 띠가 약하다 (Zone.add_pt의 몫).
const FAR_PATS := ["shot", "gust", "stream", "chain", "lob"]
const FAR := 1600.0  # 화면 끝까지 (전장 1280x720 대각선보다 김)


## 거리 d에서 피해 몫 (감소 시작 거리 start 안은 1).
static func far_k(d: float, start: float) -> float:
	if d <= start:
		return 1.0
	return maxf(Rules.far_min, 1.0 - (1.0 - Rules.far_min) * (d - start) / maxf(Rules.far_len, 1.0))


## 감소 시작 거리: 예전 사거리 그대로 (공격방식 레벨·크기 강화·원거리 특성·range_<id> 포함, 바람은 쏠 때 따로). 대상이 아니면 INF.
static func far_start_of(pat: String, l: int, total: int, size_n: float) -> float:
	var s := 1.0 + Rules.size_k * size_n
	match pat:
		"shot": return shot_range(total, size_n)
		"gust": return Projectile.PROJ.gust_far * s * Rules.t("range_gust")
		"stream": return SHAPE.stream_len * rr_of(pat, l) * s
		"chain": return SHAPE.chain_len * rr_of(pat, l) * s
		"lob": return LOB_RANGE * rr_of(pat, l)
	return INF


func far_start() -> float:
	return far_start_of(pattern, plv, total_level(), mf("size"))


## 크기 강화 배율.
func sz() -> float:
	return 1.0 + Rules.size_k * mf("size")


## 분열 확률.
func split_ch() -> float:
	return minf(Rules.split_max, Rules.split_ch * mf("split"))


## 튕김 (탄이 아닌 공격): 맞힌 구체에서 작은 탄이 가까운 다른 구체로 튀는 간격(초, 공격 속도 전)
func bounce_iv() -> float:
	return Rules.t("bounce_iv")


## 탄이 아닌 공격의 튕김: 맞힌 구체 o에서 가까운 다른 구체로 작은 탄 튕김 개수만큼 (직선탄 한 발 x bounce_hit)
func _area_bounce(o: Orb) -> void:
	var cands: Array = []
	for other in _combat_port.near(o.position, 140.0):
		if other != o and other.hp > 0.0 and other.position.distance_to(o.position) < 140.0:
			cands.append(other)
	if cands.is_empty():
		return
	bounce_cd = bounce_iv()
	cands.sort_custom(func(a, b): return a.position.distance_squared_to(o.position) < b.position.distance_squared_to(o.position))
	for i in mini(mn("bounce"), cands.size()):
		var p: Projectile = _spawning_port.spawn_proj(self, "frag", plv, (cands[i].position - o.position).normalized())
		p.src = "mod:bounce"
		p.dmg = 2.4 * pw(plv) * Rules.bounce_hit
		p.max_travel = 160.0
		p.position = o.position
		p.hit[o] = true


## 속성이 많을수록, 공명·관통 강화로 피해가 늘어난다.
## rx: 특수 반응 공격은 겹친 레벨 합 보너스를 받지 않는다 (반응은 자기 레벨로 강해짐).
## 한 오브젝트에 몰아 넣으면 반응 수 x 레벨 합으로 곱이 되던 문제를 막는다.
func dmg_factor(rx := false) -> float:
	var f := Rules.t("dmg_base") * (1.0 if rx else 1.0 + Rules.t("dmg_sum") * (total_level() - 1))
	# 오브젝트 수 보너스: 설치된 오브젝트가 많을수록 모두 강해진다 (늘수록 덜 오름, Rules.crowd_bonus)
	if main:
		f *= 1.0 + Rules.crowd_bonus(main.towers.get_child_count()) * MapRule.crowd_k()  # 평원: 무리 보너스 x2
	if reso > 0 and main:
		var near := 0
		for o in main.towers.get_children():
			if o != self and o.position.distance_to(position) < Rules.t("reso_r") * MapRule.reso_k():
				near += 1
		f *= 1.0 + Rules.t("reso_k") * reso * near
	if m("pierce") > 0 and not pattern in Pat.PROJECTILE:
		f *= 1.0 + Rules.t("pierce_dmg") * mf("pierce")
	if m("size") > 0 and pattern in Pat.PROJECTILE:
		f *= 1.0 + Rules.size_dmg * mf("size")
	if not rx:
		f *= mod_fix_all() * Rules.t("dmg_" + pattern)
	# 온라인 밸런스 패치: 공격방식·넣은 속성별 피해 배율
	if not Patch.pat_mul.is_empty():
		f *= Patch.pat_mul.get(pattern, 1.0)
	if not Patch.elem_mul.is_empty():
		for e in elements:
			f *= Patch.elem_mul.get(e, 1.0)
	f *= Vary.tower_mul(elements, pattern)  # 판마다 다른 흐름: 웨이브 이벤트·적응 구체
	f *= MapRule.tower_mul(elements, pattern)  # 맵 친화 속성·공격방식
	if main and on_lane():
		f *= 1.0 + Rules.t("map_cross_dmg")  # 십자로: 길목에서 길 따라 겨눔
	if main and _abilities_port.on_ley(self):
		f *= 1.0 + Rules.t("ley_dmg")  # 기맥 위
	return f


## 십자로: 길 위에서 길을 따라 겨누는지 (혼불은 떠돌아서 제외)
func on_lane() -> bool:
	return pattern != "wisp" and main != null and MapRule.on_lane(position, dir, _viewport_port.center(), main.lanes)


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
		fs.append(["elem:wood", log(1.0 + 0.2 * mini(lv(Elem.WOOD), int(Rules.wood_cap)))])
	if main and main.towers.get_child_count() > 1:
		fs.append(["etc:crowd", log(1.0 + Rules.crowd_bonus(main.towers.get_child_count()))])
	if reso > 0 and main:
		var near := 0
		for o in main.towers.get_children():
			if o != self and o.position.distance_to(position) < 150.0:
				near += 1
		if near > 0:
			fs.append(["link:reso", log(1.0 + Rules.t("reso_k") * reso * near)])
	if m("pierce") > 0 and not pattern in Pat.PROJECTILE:
		fs.append(["mod:pierce", log(1.0 + 0.06 * mf("pierce"))])
	if m("size") > 0 and pattern in Pat.PROJECTILE:
		fs.append(["mod:size", log(1.0 + 0.04 * mf("size"))])
	if m("rapid") > 0:
		fs.append(["mod:rapid", log(1.0 + 0.1 * mf("rapid"))])
	if m("multi") > 0:
		fs.append(["mod:multi", log((1 + mn("multi")) * multi_k())])
	if dmg_mul * spd_mul > 1.0:
		fs.append(["etc:perk", log(dmg_mul * spd_mul)])
	if main and _abilities_port.on_ley(self):
		fs.append(["etc:ley", log(1.0 + Rules.t("ley_dmg"))])
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
	for reaction in fresh: new_reactions[reaction["id"]] = true
	elements[e] = mini(lv(e) + n, elem_cap())
	eff = eff_now()
	if not order.has(e):
		order.append(e)
	place_pop = 1.0
	queue_redraw()
	if fresh.is_empty():
		return "%s Lv%d" % [Elem.NAMES[e], lv(e)]
	var names := PackedStringArray()
	for r in fresh:
		names.append(r["name"])
	return "조합: " + ", ".join(names)


## 한 오브젝트에서 같은 속성이 오를 수 있는 최대 레벨 (2026-11-01 사용자 "모든 속성 Lv5 상한")
static func elem_cap() -> int:
	return maxi(1, int(Rules.t("elem_cap")))


## 이 카드를 넣을 수 있는지 (속성 종류·강화 종류별 상한, 같은 속성 레벨 상한, 공격방식 고정).
func can_take(card: Dictionary) -> bool:
	match card["type"]:
		"elem":
			if elements.has(card["e"]):
				return lv(card["e"]) < elem_cap()
			# 별이 든 오브젝트는 별 + 하나(그 속성의 행성)까지
			if (elements.has(Elem.STAR) or card["e"] == Elem.STAR) and order.size() >= STAR_MAX_ELEMS:
				return false
			if not planet_refuse(card["e"]).is_empty():
				return false
			return order.size() < Rules.max_elems
		"pat":
			return can_pattern(card["id"])
		"mod":
			return m(card["id"]) < mod_cap(card["id"]) and mod_count() < Rules.mod_total and mod_useless(card["id"]).is_empty()
		"trig":
			return tg(card["id"]) < int(Rules.t("trig_max"))
	return true


func mod_cap(id: String) -> int:
	if id == "reflex":
		return 0 if Rules.t("auto_aim") > 0.0 else 1
	return Rules.max_mod


## 자동 조준 (2026-11-07 기본 기능, rules.auto_aim): 혼불·블랙홀은 원래 전방위라 빼고 모든 오브젝트.
static func auto_base(pat: String) -> bool:
	return Rules.t("auto_aim") > 0.0 and not pat in Pat.NO_MOD["reflex"]


## 이 오브젝트가 방향을 고정하지 않고 가까운 구체를 겨누는지 (기본 기능 또는 예전 강화 카드).
func auto_aim() -> bool:
	return m("reflex") > 0 or auto_base(pattern)


## 최종 피해 감산: 공격방식·반응·지속 피해의 마지막 피해 처리에서 한 번 적용. 강화 카드로 얻은 자동 조준만 -10%.
func final_damage_mul() -> float:
	return 0.9 if m("reflex") > 0 and Rules.t("auto_aim") <= 0.0 else 1.0


## 든 강화 합계 (Rules.mod_total까지).
func mod_count() -> int:
	var n := 0
	for k in mods:
		n += int(mods[k])
	return n


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
			if elements.has(card["e"]):
				return "같은 속성은 Lv%d까지예요. 다른 오브젝트에 넣거나 빈 곳에 놓아 새 오브젝트로 만드세요" % elem_cap()
			if (elements.has(Elem.STAR) or card["e"] == Elem.STAR) and order.size() >= STAR_MAX_ELEMS:
				return "별이 든 오브젝트는 별 + 속성 하나(행성)까지예요. 빈 곳에 놓아 새 오브젝트로 만드세요"
			if not planet_refuse(card["e"]).is_empty():
				return planet_refuse(card["e"])
			return "속성은 %d종까지예요. 빈 곳에 놓아 새 오브젝트로 만드세요" % Rules.max_elems
		"pat":
			var bad := pattern_blockers(card["id"])
			if not bad.is_empty():
				return "%s 강화가 들어 있어서 %s(으)로 바꿀 수 없어요 (효과가 없어져요)" % ["·".join(bad), Pat.pname(card["id"])]
			return "이 오브젝트는 %s(으)로 정해져 있어요. 같은 공격방식만 넣을 수 있어요" % Pat.pname(pattern)
		"mod":
			var why := mod_useless(card["id"])
			if not why.is_empty():
				return why
			if mod_count() >= Rules.mod_total:
				return "강화는 한 오브젝트에 %d개까지예요. 다른 오브젝트에 넣으세요" % Rules.mod_total
			return "%s은(는) %d개까지 쌓을 수 있어요" % [Pat.MODS[card["id"]]["name"], mod_cap(card["id"])]
		"trig":
			return "%s은(는) %d개까지 쌓을 수 있어요" % [Pat.TRIGS[card["id"]]["name"], int(Rules.t("trig_max"))]
	return ""


## 이 공격방식을 넣을 수 있는지: 직선탄은 한 번 교체 가능, 정해진 뒤에는 같은 것(레벨업)만.
## 이미 든 강화가 그 공격방식에서 효과가 없어지면 바꿀 수 없다.
func can_pattern(id: String) -> bool:
	return (pattern == Pat.DEFAULT or id == pattern) and pattern_blockers(id).is_empty()


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
	return "%s → %s" % [Pat.pname(old), Pat.pname(id)]


func add_mod(id: String) -> String:
	if id == "reflex" and not can_take({"type": "mod", "id": id}):
		return refuse_text({"type": "mod", "id": id})
	mods[id] = m(id) + 1
	place_pop = 1.0
	queue_redraw()
	return "%s %d (%s)" % [Pat.MODS[id]["name"], m(id), mod_effect(id)]


## 지금 든 강화의 효과량 (detail_lines·dmg_factor·multi_k 등과 같은 식). 공격방식마다 다르다.
func mod_effect(id: String) -> String:
	var fx := Pat.mod_fix(pattern, id, mf(id))
	var t := _mod_effect(id)
	if absf(fx - 1.0) >= 0.005 and id != "dice" and id != "size":  # 크기는 "이 공격방식 피해"에 합쳐 보임
		t += " · 공격방식 보정 x%.2f" % fx
	return t


func _mod_effect(id: String) -> String:
	var f := mf(id)
	match id:
		"reflex":
			return "전방위 자동 조준 · 최종 피해 -10% · 최대 1개"
		"multi":
			if pattern == "wall":
				return "벽 최대 %d개" % (2 + roundi(f))
			if pattern in ["vortex", "lob"]:
				return "한 번에 %.2f개" % (1.0 + f)
			if pattern == "wisp":
				return "혼불 %d개 (하나 피해 %d%%)" % [wisp_cap(), roundi(multi_k() * (1.0 + f) * 2.0 / wisp_cap() * 100.0)]
			return "한 번에 %.2f개 (한 발 피해 %d%%)" % [1.0 + f, roundi(multi_k() * 100.0)]
		"split":
			return "파편 확률 %d%%" % roundi(split_ch() * 100.0)
		"homing":
			if pattern == "wisp":
				return "추적 범위 +%d%% · 휘는 힘 x%.2f" % [roundi(Projectile.WISP_LEASH_HOMING * f * 100.0), f]
			return "휘는 힘 x%.2f" % f
		"bounce":
			if pattern in Pat.PROJECTILE or pattern == "chain":
				return "튕김 %.2f번" % f
			return "맞힐 때 %.1f초마다 작은 탄 %d개가 튐" % [bounce_iv(), mn("bounce")]
		"size":
			var sp := roundi((size_part() - 1.0) * 100.0)
			return "크기·범위·사거리 +%d%%" % roundi((sz() - 1.0) * 100.0) + (" · 이 공격방식 피해 %+d%%" % sp if sp != 0 else "")
		"rapid":
			return "공격 속도 +%d%%" % roundi(Rules.rapid_k * f * 100.0)
		"pierce":
			if pattern in Pat.PROJECTILE:
				return "%.2f개 더 뚫음" % f
			return "피해 +%d%% · 보호막 +%d%% 더 깎음 · 갑옷 %d%% 무시" % [roundi(Rules.t("pierce_dmg") * f * 100.0), roundi(Rules.pierce_shield * f * 100.0), roundi(minf(Rules.pierce_armor * f, 1.0) * 100.0)]
		"dice":
			return "주사위 %d개 · 대박 %d%% · 평균 피해 +%d%% · %d번 안에 대박" % [dice_n(), roundi((1.0 - pow(5.0 / 6.0, dice_n())) * 100.0), roundi((dice_avg() - 1.0) * 100.0), dice_pity()]
	return ""


func add_link(id: String) -> String:
	place_pop = 1.0
	queue_redraw()
	match id:
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
			return "탄 %d개" % (int(Rules.t("echo_n")) + n - 1)
		"vanguard":
			return "성한 구체 피해 x%s" % _num(van_mul(n))
		"charge":
			return "처치 %d마리 → 강타 x%s" % [int(_at(CHARGE_NEED, n)), _num(charge_mul(n))]
		"third":
			return "3번째 공격 x%s" % _num(third_mul(n))
		"finish":
			return "약한 구체 피해 x%s" % _num(finish_mul(n))
		"answer":
			return "한 발 피해 %d%%" % roundi(answer_dmg(n) * 100.0)
	return ""


static func _num(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0")


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
	return {"els": elements, "pat": pattern, "plv": plv, "mods": mods}


## 이어하기 저장용.
func to_save() -> Dictionary:
	return {"elements": elements, "order": Array(order), "pattern": pattern, "plv": plv, "mods": mods,
		"reso": reso, "pincer": pincer, "trigs": trigs, "charge": charge, "third_n": third_n, "star_sum": star_sum, "star_e": star_e, "pos": position, "dir": dir, "dealt": dealt, "run_dealt": run_dealt,
		"src": src, "run_src": run_src}


## 협동 멀티플레이: 다른 기기에 보낼 오브젝트 상태 (피해 기록은 빼서 웨이브 중에 자꾸 바뀌지 않게).
func mp_state() -> Dictionary:
	var d := to_save()
	for k in ["dealt", "run_dealt", "src", "run_src"]:
		d.erase(k)
	d["nid"] = net_id
	d["rq"] = req_e
	return d


## 협동 멀티플레이: 받은 상태로 이 오브젝트를 바꾼다 (피해 기록은 이 기기 것을 둔다).
func mp_apply(d0: Dictionary) -> void:
	var d := d0.duplicate(true)  # 내 mp_state()를 그대로 받아도 아래에서 지우는 사전과 겹치지 않게
	var keep := [dealt, run_dealt, src, run_src]
	elements.clear()
	order.clear()
	mods.clear()
	trigs.clear()
	pattern = Pat.DEFAULT
	load_save(d)
	dealt = keep[0]
	run_dealt = keep[1]
	src = keep[2]
	run_src = keep[3]
	req_e = int(d0.get("rq", -1)) if d0.get("rq", -1) is int or d0.get("rq", -1) is float else -1
	if not req_e in Elem.ALL:
		req_e = -1
	eff = eff_now()
	queue_redraw()


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
	# 없어진 공격방식(예전 그린 궤적)은 직선탄으로 남고 레벨은 그대로 (같은 탄·피해, 길만 곧게)
	plv = maxi(1, _int(d.get("plv")))
	var ms: Variant = d.get("mods", {})
	if ms is Dictionary:
		for id in ms:
			if Pat.MODS.has(id) and _int(ms[id]) > 0:
				if id == "reflex":
					if Rules.t("auto_aim") <= 0.0:  # 기본 기능이 된 뒤 예전 저장의 자동 조준 카드는 강화 칸을 차지하지 않게 버린다
						mods[id] = 1
				else:
					mods[id] = _int(ms[id])
	reso = maxi(0, _int(d.get("reso")))
	pincer = maxi(0, _int(d.get("pincer")))
	var tgs: Variant = d.get("trigs", {})
	if tgs is Dictionary:
		for id in tgs:
			if Pat.TRIGS.has(id) and _int(tgs[id]) > 0:
				trigs[id] = _int(tgs[id])
	charge = clampf(_float(d.get("charge")), 0.0, 99.0)
	star_sum = maxf(0.0, _float(d.get("star_sum")))
	var se: Variant = d.get("star_e", {})
	if se is Dictionary:
		for e in se:
			if e is int and e in Elem.ALL and _float(se[e]) > 0.0:
				star_e[e] = _float(se[e])
	third_n = maxi(0, _int(d.get("third_n")))
	var pos: Variant = d.get("pos")
	if pos is Vector2:
		position = pos
	var dv: Variant = d.get("dir")
	if dv is Vector2 and dv.length() > 0.01:
		set_attack_direction(dv)
	else:
		set_attack_direction(dir)
	dealt = maxf(0.0, _float(d.get("dealt")))
	run_dealt = maxf(0.0, _float(d.get("run_dealt")))
	src = _src_dict(d.get("src"))
	run_src = _src_dict(d.get("run_src"))
	set_attack_direction(dir)


## 방향 변경 시 공격 계산과 총구 표시를 같은 프레임에 갱신한다.
func set_attack_direction(value: Vector2) -> void:
	if value.length() < 0.01:
		return
	dir = value.normalized()
	aim = dir
	queue_redraw()


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
			if not pattern in CONT_BOOST:
				_set_fire(_fire_mul(true))
		return true
	cd[key] = v
	return false


## 주사위를 시간으로 굴리는 계속 공격 (그 밖의 공격은 쏠 때마다 _ready_to·연쇄 번개에서 굴린다)
const DICE_TIMED := ["spray", "clock"]
static var DICE_PITY := [8, 7, 6, 5, 4]  # 장 수별: 이만큼 굴리는 동안 6이 없으면 다음은 6


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
		dice_x = Rules.dice_top
		if main:
			_spawning_port.burst(position, Color(1, 0.85, 0.3), 6, 90.0)
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
	return lo + (mid - lo) * Rules.t("dice_mid") + (1.0 - mid) * Rules.dice_top


## 다중 발사 방향들 (가운데 기준 0.22라디안 간격). 옆 간격은 lanes()와 같은 순서.
func dirs() -> Array:
	var out := []
	for k in spread_ks(shots()):
		out.append(aim.rotated(spread_a(k)))
	return out


## 다중 발사 한 발마다 쏘는 자리 옆 간격 (dirs()와 같은 순서, 오브젝트 기준 위치 차이)
func lanes() -> Array:
	var out := []
	for k in spread_ks(shots()):
		out.append(aim.orthogonal() * spread_lane(k))
	return out


## 다중 발사 발 수. 소수 몫(도파민 규칙의 감쇠 등)은 확률로 한 발 더라, 같은 프레임 안에서는 한 번만 굴린다.
## 예전엔 dirs()와 lanes()가 따로 굴려 발 수가 달라지면 ls[i]가 배열 밖이었다 (2026-11-01 봇 도파민 속사 판 오류)
var _shots_f := -1
var _shots_n := 1
func shots() -> int:
	var f := Engine.get_process_frames()
	if f != _shots_f:
		_shots_f = f
		_shots_n = 1 + mn("multi")
	return _shots_n


## 짝수 개 다중 발사는 가운데 두 발을 같은 방향으로 나란히(옆 간격 ±MULTI_LANE) 쏜다.
## 예전에는 모든 발을 0.22라디안씩 벌려 2발이면 정중앙이 비어, 조준한 구체가 약 250px보다 멀면
## 두 발이 양옆으로 빗나가 피해가 0이었다 (2026-11-01 사용자 제보, tools/miss_audit.gd).
static var MULTI_LANE := 8.0  # 작은 구체(반지름 9)도 두 발이 다 맞는 간격


## n발의 자리 번호: 가운데 0, 홀수 n은 정수(-1, 0, 1), 짝수 n은 ±0.5, ±1.5 …
static func spread_ks(n: int) -> Array:
	var out := []
	for i in n:
		out.append(i - (n - 1) / 2.0)
	return out


## 자리 번호 → 각도. 짝수일 때 가운데 두 발(±0.5)은 0, 그 바깥은 한 칸씩 안으로 당긴다
static func spread_a(k: float) -> float:
	if is_equal_approx(absf(fmod(k, 1.0)), 0.5):
		return signf(k) * (absf(k) - 0.5) * Rules.multi_angle
	return k * Rules.multi_angle


static func spread_lane(k: float) -> float:
	return signf(k) * MULTI_LANE if is_equal_approx(absf(fmod(k, 1.0)), 0.5) else 0.0


## 다중 발사면 공격 하나당 피해 55%, 더 쌓을수록 한 발은 조금씩 약해진다 (1개 x1.1, 3개 x1.7).
## 강화 보정표(Pat.MOD_FIX)를 넣은 강화 전부에 대해 곱한 값
func mod_fix_all() -> float:
	var f := 1.0
	for id in mods:
		f *= Pat.mod_fix(pattern, id, mf(id))
	return f


func multi_k() -> float:
	return 1.0 if m("multi") == 0 else Rules.multi_dmg / (1.0 + Rules.multi_decay * (mf("multi") - 1.0))


## main이 웨이브 중 매 계산마다 호출한다.
## 웨이브 밖(쉬는 시간·카드 선택)에는 attack이 안 불려 그림 효과 시간이 멈춘다.
## 마지막 구체를 초신성·레이저 등으로 잡으면 그 효과가 다음 웨이브까지 남았다 (2026-10-31 회색 원 버그). main이 웨이브 밖에서 부른다.
func fade_fx(delta: float) -> void:
	if jam_t > 0.0 or focus_t > 0.0 or leech_n > 0:
		# 웨이브가 끝나면 집중·방해 표시는 바로 지운다 (쉬는 시간에 멈춘 것처럼 보이지 않게)
		jam_t = 0.0
		focus_t = 0.0
		leech_n = 0
		leech_t = 0.0
		queue_redraw()
	var any := nova_fx > 0.0 or nova_aim != null or not feed_fx.is_empty() or recoil > 0.0 or burst_t > 0.0
	for k in fx.keys():
		if fx[k] > 0.0:
			fx[k] = maxf(fx[k] - delta, 0.0)
			any = true
	if not any:
		return
	recoil = maxf(recoil - delta * 6.0, 0.0)
	burst_t = maxf(burst_t - delta, 0.0)
	nova_fx = maxf(nova_fx - delta, 0.0)
	nova_aim = null
	for f in feed_fx.keys():
		feed_fx[f] -= delta
		if not is_instance_valid(f) or feed_fx[f] <= 0.0:
			feed_fx.erase(f)
	queue_redraw()


func attack(delta: float, orbs: Array) -> void:
	t += delta
	eff = eff_now()
	for k in fx.keys():
		fx[k] = maxf(fx[k] - delta, 0.0)
	recoil = maxf(recoil - delta * 6.0, 0.0)
	echo_cd = maxf(echo_cd - delta, 0.0)
	focus_t = maxf(focus_t - delta, 0.0)
	jam_imm = maxf(jam_imm - delta, 0.0)
	if leech_t > 0.0:
		leech_t -= delta
		if leech_t <= 0.0:
			leech_n = 0
	answer_cd = maxf(answer_cd - delta, 0.0)
	notify_cd = maxf(notify_cd - delta, 0.0)
	burst_t = maxf(burst_t - delta, 0.0)
	if jam_t > 0.0:
		# 방해 구체에 멈춤: 공격하지 않는다 (이미 날아간 탄·장판은 그대로)
		jam_t = maxf(jam_t - delta, 0.0)
		queue_redraw()
		return
	_update_aim(orbs, delta)
	# 속성을 많이 겹칠수록 공격이 느려진다(쌓기 대가), 속사 강화로 빨라진다
	var de := delta * spd_k()
	var k := de * 3.0  # 지속 공격의 부가효과 세기
	var dp := de * Rules.t("spd_" + pattern)  # 공격방식 공격만 공격방식별 속도 배율(온라인 패치 spd_<id>), 반응은 de
	var kp := dp * 3.0
	var l := plv
	var s := sz()
	var mk := multi_k()
	bounce_cd = maxf(bounce_cd - dp, 0.0)
	if pattern in DICE_TIMED and m("dice") > 0:
		dice_t -= de
		if dice_t <= 0.0:
			dice_t = 1.0
			roll_dice()
	if pattern in CONT_BOOST and (tg("charge") > 0 or tg("third") > 0):
		cont_acc += dp
		if cont_acc >= CONT_IV:
			cont_acc -= CONT_IV
			var f := _fire_mul(true)
			if f[0] > 1.0:
				burst_t = 0.5 if f[2] == "trig:charge" else 0.4
				burst_mul = f[0]
				burst_size = f[1]
				burst_key = f[2]
		if burst_t > 0.0:
			_set_fire([burst_mul, burst_size, burst_key])
	var can_fire := not auto_aim() or is_instance_valid(reflex_target)
	if not can_fire and cd.has("p"):
		# 기본 공격만 건너뛰었으므로 그 쿨다운만 진행. 반응은 아래 _reactions에서 한 번 진행한다.
		cd["p"] = maxf(0.0, cd["p"] - dp)
	match pattern if can_fire else "":
		"gust":
			# 다중 발사: 부채꼴로 벌리지 않고 같은 방향으로 나란히 (넓은 돌풍이 길목 밖으로 빠지지 않게, 2026-11-01)
			if _ready_to("p", BASE_IV[pattern] / spd(l), dp):
				var n := shots()
				for i in n:
					var pr: Projectile = _spawning_port.spawn_proj(self, "gust", l, aim, aim.orthogonal() * Rules.t("gust_gap") * (i - (n - 1) / 2.0))
					pr.dmg *= mk
					pr.form_init()
		"shot", "thorn", "shard", "iron":
			if _ready_to("p", BASE_IV[pattern] / spd(l), dp):
				var ls := lanes()
				var ds := dirs()
				for i in ds.size():
					var pr: Projectile = _spawning_port.spawn_proj(self, pattern, l, ds[i], ls[i])
					pr.dmg *= mk  # 다중 발사: 한 발 피해 감소
					pr.form_init()
		"spray":
			var sdm: float = HIT.spray * pw(l)
			for d in dirs():
				_cone(orbs, d, SHAPE.spray_len * rr(l) * s, SHAPE.spray_ang, func(o): hit(o, sdm * dp * mk, kp))
		"stream":
			if _ready_to("p", BASE_IV.stream / spd(l), dp):
				fx["stream"] = SHAPE.stream_t
			if fx.get("stream", 0.0) > 0.0:
				var ls := lanes()
				var ds := dirs()
				for i in ds.size():
					var fs := far_start()
					_line(orbs, ds[i], FAR, SHAPE.stream_w * s, func(o):
						var fk := far_k(o.position.distance_to(position), fs)
						hit(o, HIT.stream * pw(l) * dp * mk * fk, kp)
						o.stagger(SHAPE.stream_stop * dp * fk), ls[i])
		"chain":
			if cd.get("p", 0.0) > 0.0:
				cd["p"] -= dp
			else:
				var fired := false
				var used := {}
				_set_fire(_fire_mul(false))
				for d in dirs():
					fired = _chain(orbs, d, l, used) or fired
				if fired:
					_fire_mul(true)
					cd["p"] = BASE_IV.chain / spd(l)
					roll_dice()
					recoil = 1.0
		"wall":
			rocks = rocks.filter(func(r): return is_instance_valid(r))
			if _ready_to("p", Rules.t("wall_iv") / spd(l), dp) and rocks.size() < 2 + roundi(mf("multi")):
				_spawning_port.spawn_rock(self, l)
		"vortex":
			# 중력 우물 (2026-11-01 사용자 "블랙홀을 중력·흡수 컨셉으로"): 사거리 안 구체가 가장 빽빽한 곳에 떨어져
			# 끌어모으고, 안에 든 구체가 다른 오브젝트에게 받은 피해 일부를 모았다가 끝에 터진다 (Zone.well).
			# 자리는 오브젝트에서 정한 거리가 아니라 구체 무리를 따라간다. 구체가 없으면 0.3초 뒤 다시 찾는다
			if _ready_to("p", BASE_IV.vortex / spd(l), dp):
				var spots := well_spots(dirs().size())
				if spots.is_empty():
					cd["p"] = 0.3
				for p in spots:
					_spawning_port.spawn_zone("vortex", l, p, self).well()
		"laser":
			if _ready_to("p", BASE_IV.laser / spd(l), dp):
				fx["laser"] = 0.3
				var ls := lanes()
				var ds := dirs()
				for i in ds.size():
					_line(orbs, ds[i], 2000.0, Rules.t("laser_w") * s, func(o): hit(o, HIT.laser * pw(l) * mk), ls[i])
		"lob":
			if _ready_to("p", BASE_IV.lob / spd(l), dp):
				var ls := lanes()
				var ds := dirs()
				for i in ds.size():
					_spawning_port.spawn_proj(self, "blob", l, ds[i], ls[i]).form_init()
		"sonic":
			# 부채꼴로 퍼지는 파동: 안의 구체를 모두 치고, 멀수록 약하다 (끝에서 50%)
			if _ready_to("p", BASE_IV.sonic / spd(l), dp):
				fx["sonic"] = 0.35
				var R := sonic_r(l)
				for d in dirs():
					_cone(orbs, d, R, SHAPE.sonic_ang, func(o):
						hit(o, HIT.sonic * pw(l) * mk * (1.0 - SHAPE.sonic_far * minf(o.position.distance_to(position) / R, 1.0))))
		"clock":
			# 바늘이 앞쪽 ±0.7라디안을 왕복한다. 한 번 훑을 때마다 같은 구체는 한 번씩
			var was := cos(clock_ph) >= 0.0
			clock_ph += dp * spd(l) * TAU / SHAPE.clock_sweep
			if (cos(clock_ph) >= 0.0) != was:
				clock_hit.clear()
			var ds := dirs()
			var ls := lanes()
			for i in ds.size():
				_line(orbs, ds[i].rotated(clock_a()), SHAPE.clock_len * rr(l) * s, SHAPE.clock_w * s, func(o):
					var key := [i, o]
					if not clock_hit.has(key):
						clock_hit[key] = true
						hit(o, Rules.t("clock_dmg") * pw(l) * mk), ls[i])
		"wisp":
			wisps = wisps.filter(func(w): return is_instance_valid(w) and not w.is_queued_for_deletion())
			var cap := wisp_cap()
			if wisps.size() < cap and _ready_to("p", Projectile.WISP_RESPAWN / spd(l), dp):
				var pr: Projectile = _spawning_port.spawn_proj(self, "wisp", l, aim.rotated(randf_range(-0.8, 0.8)))
				# 다중 발사: 혼불 수가 늘고, 모두 합친 세기는 다른 공격방식의 다중 발사와 같게 ((1 + 다중) x 한 발 배율)
				pr.dmg *= mk * (1.0 + mf("multi")) * 2.0 / cap
				pr.form_init()
				wisps.append(pr)
	_set_fire([1.0, 1.0, ""])
	_share_tick(delta)
	nova_fx = maxf(nova_fx - delta, 0.0)
	for f in feed_fx.keys():
		if not is_instance_valid(f):
			feed_fx.erase(f)
			continue
		feed_fx[f] -= delta
		if feed_fx[f] <= 0.0:
			feed_fx.erase(f)
	if lv(Elem.STAR) > 0 and star_sum >= star_need():
		_try_nova()
	_nova_aim_tick(delta)
	queue_redraw()


## 협공: 맞힌 오브젝트를 구체에 표시해 두고, 협공이 있는 오브젝트가 맞힐 때
## 최근 PINCER_T초 안에 서로 다른 오브젝트 PINCER_N개 이상에게 맞았으면 표식이 터진다.
static var PINCER_N := 2
const PINCER_T := 3.0
const PINCER_CD := 1.5  # 한 구체가 다시 터질 때까지


func _pincer(o: Orb) -> void:
	o.marks[get_instance_id()] = o.age
	if pincer <= 0 or o.pincer_cd > 0.0 or o.hp <= 0.0:
		return
	var n := 0
	for id in o.marks.keys():
		if o.age - o.marks[id] <= Rules.pincer_t:
			n += 1
		else:
			o.marks.erase(id)
	if n < PINCER_N:
		return
	o.pincer_cd = Rules.t("pincer_cd")
	# 최대 체력 비례 (협공을 겹치면 +50%씩, 3개를 넘는 오브젝트 하나당 +25%, 보스는 1/4)
	var f := Rules.pincer_frac * (1.0 + 0.5 * (pincer - 1)) * (1.0 + 0.25 * (n - PINCER_N))
	if o.kind == Orb.Kind.BOSS:
		f *= 0.25
	var d := o.max_hp * f
	d = o.hurt(d, false, self)
	credit(d, "link:pincer")
	if main:
		_spawning_port.popup(o.position, d, Color(1.0, 0.55, 0.85), true, "협공")
		_spawning_port.burst(o.position, Color(1.0, 0.55, 0.85), 8, 120.0)


## 특징 공유: 잠시 뒤 효과(시간 되풀이)·빛줄기 간격 (Share).
func _share_tick(delta: float) -> void:
	Side.tick(self, delta)
	side_big_fx = maxf(side_big_fx - delta, 0.0)
	light_cd = maxf(light_cd - delta, 0.0)
	mirror_cd = maxf(mirror_cd - delta, 0.0)
	if mirror_t > 0.0:
		mirror_t -= delta
		if mirror_t <= 0.0:
			mirror_src = null
	aff_cd = maxf(aff_cd - delta, 0.0)
	if later.is_empty():
		return
	var due: Array = []
	for i in range(later.size() - 1, -1, -1):
		later[i][0] -= delta
		if later[i][0] <= 0.0:
			due.append(later[i][1])
			later.remove_at(i)
	for f in due:
		f.call()


## 중력 우물 자리 n개: 사거리(well_range) 안 구체 중 둘레 110에 구체가 가장 많은 구체 자리. 둘째부터는 앞 자리에서 150 넘게 떨어진 곳
func well_spots(n: int) -> Array:
	var out: Array = []
	var rng := well_range()
	var cand: Array = []
	for o in _combat_port.near(position, rng):
		if o.hp > 0.0 and o.position.distance_to(position) <= rng:
			cand.append([_combat_port.near(o.position, 110.0).size(), o.position])
	cand.sort_custom(func(a, b): return a[0] > b[0])
	for c in cand:
		if out.size() >= n:
			break
		if out.all(func(p): return p.distance_to(c[1]) > 150.0):
			out.append(c[1])
	return out


## 중력 우물을 떨어뜨리는 사거리 (공격방식 레벨·바람 멀리·사거리 배율)
func well_range() -> float:
	return Rules.t("well_range") * rr(plv) * Rules.t("range_vortex")


## 벽 바위 k번째 자리(오브젝트 기준). 처음 두 개는 앞으로 한 줄(90·150), 다중 발사로 늘어난 바위는 그 사이 양옆에 번갈아
## (2026-10-30: 앞으로만 늘어서면 맨 앞 바위에 막힌 구체가 옆으로 비껴 나가 다중 발사가 피해를 0.65~0.76배로 깎던 것)
static func rock_slot(d: Vector2, k: int, l: int) -> Vector2:
	if k < 2:
		return d * (90.0 + 60.0 * k) * rr_of("wall", l)
	# 옆 벽은 앞 벽에 바짝 붙여(44) 넓은 담처럼 (56이면 틈으로 구체가 빠져 다중이 거의 놀았다, 2026-11-01)
	return d * 120.0 * rr_of("wall", l) + d.orthogonal() * 44.0 * (1 + (k - 2) / 2) * (1.0 if k % 2 == 0 else -1.0)


## 음파 사거리.
func sonic_r(l: int) -> float:
	return SHAPE.sonic_len * rr(l) * sz()


## 시계침 각도 (공격 방향 기준).
func clock_a() -> float:
	return sin(clock_ph) * SHAPE.clock_arc


## 앞쪽 가장 가까운 구체부터 n개를 잇는다 (되감기 번개).
func _chain_list(orbs: Array, d: Vector2, rng: float, n: int) -> Array:
	var first: Orb = null
	var best := rng
	for o in _combat_port.near_t(position, rng):
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
		for o in _combat_port.near_t(cur.position, nd):
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
		_spawning_port.sound_pulse(o)


## 물길: 공격 방향으로 흐르는 띠. 웨이브가 시작되면 물이 앞으로 흘러 나간다.
func chan_len(l: int) -> float:
	var full := 260.0 * reach(l)
	return minf(full, main.wave_time * 520.0) if main else full


func chan_w(l: int) -> float:
	return 20.0 + 3.0 * (l - 1)


## 반응의 감지 사거리. 공격·정보창과 같은 크기/레벨/사거리 보정을 쓴다.
## 자동 조준이 기본 기능이면 화면 끝까지 가는 방향성 공격(직선탄·돌풍·물줄기·연쇄 번개·투척 장판)은 화면 끝까지 겨눈다 (멀면 약해질 뿐, PAT-07).
func reflex_range(toward := Vector2.ZERO) -> float:
	if Rules.t("auto_aim") > 0.0 and pattern in FAR_PATS:
		return FAR
	var weather := MapRule.wind_k(toward, MapRule.wind_dir(main.lanes)) if main and MapRule.on() else 1.0
	return reflex_range_of(pattern, plv, total_level(), mf("size"), 0.0, mf("homing"), mf("multi"), weather)


## 지키는 곳까지 남은 거리: 중앙까지, 회랑 맵은 문(세로선)까지 가로 거리.
func goal_dist(o: Orb) -> float:
	if main == null:
		return o.position.distance_to(position)
	if Meta.map_id == "line":
		return absf(o.position.x - main.viewport_system.core().x)
	return o.position.distance_to(main.viewport_system.center())


## 자동 조준 대상 (2026-11-07): 사거리 안에서 지키는 곳에 가장 가까운 구체를 먼저.
## 그 구체와 지키는 곳까지 거리가 aim_band 안으로 비슷한 구체끼리는 정한 방향(±aim_pref) 쪽을 먼저, 그다음 지키는 곳에 가까운 것.
func _guard_pick(orbs: Array) -> Orb:
	var cand := []
	var top := INF
	for o in orbs:
		if not is_instance_valid(o) or o.hp <= 0.0:
			continue
		var v: Vector2 = o.position - position
		if v.length() > reflex_range(v):
			continue
		var g := goal_dist(o)
		cand.append([o, g, Rules.t("aim_pref") > 0.0 and absf(dir.angle_to(v)) <= Rules.t("aim_pref")])
		top = minf(top, g)
	var pick: Orb = null
	var pick_g := INF
	var pick_in := false
	for c in cand:
		if c[1] > top + Rules.t("aim_band"):
			continue
		if pick == null or (c[2] and not pick_in) or (c[2] == pick_in and c[1] < pick_g):
			pick = c[0]
			pick_g = c[1]
			pick_in = c[2]
	return pick


## 날아가는 탄의 속도 (예측 조준용). 바로 닿는 공격(분사·레이저·번개 등)은 0.
func lead_speed() -> float:
	var P := Projectile.PROJ
	match pattern:
		"shot": return P.shot_spd
		"thorn": return P.thorn_spd
		"gust": return P.gust_spd
		"shard": return P.shard_spd
		"iron": return P.iron_spd
		"lob": return P.blob_spd
	return 0.0


## 자동 조준 방향: 탄이 날아가는 동안 구체가 걸어갈 만큼 앞질러 겨눈다 (rules.aim_lead, 2026-11-07).
## 구체 속도는 지난 프레임에 스스로 걸은 거리(Orb.walk_vel, 밀림·순간이동 제외). 3초보다 멀리 앞서지는 않는다.
func lead_dir(o: Orb) -> Vector2:
	var to: Vector2 = o.position - position
	var sp := lead_speed()
	var k := Rules.t("aim_lead")
	var v: Vector2 = o.walk_vel
	if sp <= 0.0 or k <= 0.0 or v.length_squared() < 1.0:
		return to.normalized()
	var a := v.dot(v) - sp * sp
	var b := 2.0 * to.dot(v)
	var c := to.dot(to)
	var t := -1.0
	if absf(a) < 0.001:
		if b < 0.0:
			t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var r := sqrt(disc)
			var t1 := (-b - r) / (2.0 * a)
			var t2 := (-b + r) / (2.0 * a)
			t = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	if t <= 0.0:
		return to.normalized()
	var aimed := to + v * minf(t, 3.0) * k
	return aimed.normalized() if aimed.length_squared() > 0.01 else to.normalized()


## Projectile.setup → form_init 순서대로: 유한 탄에 맵 바람, 그 뒤 속성 바람을 적용.
static func _reflex_flight_range(travel: float, wind: float, weather: float) -> float:
	if travel < 2000.0:
		travel *= weather
	if travel < 2000.0:
		travel *= 1.0 + 0.12 * wind
	return travel


static func reflex_range_of(pat: String, l: int, total: int, size_n: float, wind: float, homing: float, multi: float = 0.0, weather: float = 1.0) -> float:
	var s := 1.0 + Rules.size_k * size_n
	var r := rr_of(pat, l)
	match pat:
		"shot": return _reflex_flight_range(shot_range(total, size_n), wind, weather)
		"spray": return 200.0 * r * s
		"stream": return 260.0 * r * s
		"chain": return 280.0 * r * s
		"gust": return _reflex_flight_range(far_start_of("gust", l, total, size_n), wind, weather)  # 화면 끝까지 날지만 감지는 감소 시작 거리까지
		"sonic": return 230.0 * r * s
		"clock": return 240.0 * r * s
		"lob": return _reflex_flight_range(LOB_RANGE * r, wind, weather)
		"wall":
			var farthest := 0.0
			for k in 2 + roundi(multi):
				farthest = maxf(farthest, rock_slot(Vector2.RIGHT, k, l).length())
			return farthest + 28.0 * s
	if homing > 0.0 and pat in Pat.PROJECTILE:
		return _reflex_flight_range(Projectile.HOMING_TRAVEL, wind, weather)
	return 2000.0  # 화면 끝까지 날아가는 탄·레이저


## 유도 강화: 범위·광선 공격은 앞쪽 가장 가까운 구체 쪽으로 방향이 돈다(최대 0.1라디안씩).
func _update_aim(orbs: Array, delta: float) -> void:
	if auto_aim():
		reflex_target = null
		var best := INF
		if Rules.t("auto_aim") > 0.0:
			reflex_target = _guard_pick(orbs)
			best = reflex_target.position.distance_to(position) if reflex_target != null else INF
		else:
			# 예전 강화 카드: 사거리 안 가장 가까운 구체
			for o in orbs:
				if not is_instance_valid(o) or o.hp <= 0.0:
					continue
				var dist: float = o.position.distance_to(position)
				if dist <= best and dist <= reflex_range(o.position - position):
					best = dist
					reflex_target = o
		if reflex_target != null and best > 0.001:
			aim = lead_dir(reflex_target)
		return
	var n := mf("homing")
	if n == 0.0 or pattern in Pat.PROJECTILE:
		aim = dir
		return
	var limit := 0.1 * n
	# 가장 가까운 구체가 아니라 구체가 가장 많이 모인 쪽으로 (2026-10-30: 가까운 한 개를 따라가 무리 가운데를 벗어나
	# 분사·음파·물줄기·레이저·시계침에서 유도가 피해를 0.65~0.86배로 깎던 것)
	var angs := PackedFloat32Array()
	for o in _combat_port.near_t(position, 400.0):
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


## 크기 강화가 주는 피해 몫 (탄 공격 +size_dmg/개 x 보정표 크기 칸). 공격방식 자기 공격에만 붙는다.
func size_part() -> float:
	if m("size") == 0:
		return 1.0
	var f := Pat.mod_fix(pattern, "size", mf("size"))
	if pattern in Pat.PROJECTILE:
		f *= 1.0 + Rules.size_dmg * mf("size")
	return f


## 보조 공격·실어 나른 특징 피해용 배율: 크기 몫을 뺀다 (크기는 공격방식 자기 판정에만, 2026-11-05 사용자 결정)
func dmg_k_bare() -> float:
	return dmg_k(false) / size_part()


var no_size := false  # 지금 hit이 보조 공격처럼 공격방식 밖 공격인지 (크기 피해 빼기)


## 이 오브젝트의 공격이 구체에 닿았을 때. 겹친(나눠 받은) 모든 속성의 부가효과가 붙는다.
## k: 부가효과 세기 (한 방=1, 지속 공격=프레임 비례)
## extra: 더 얹을 속성 {속성: 레벨} (지금은 쓰는 곳 없음), can_split: 파편은 다시 분열하지 않는다
func hit(o: Orb, dmg: float, k := 1.0, extra := {}, can_split := true, force_crit := false) -> void:
	if not is_instance_valid(o) or o.hp <= 0.0:
		return
	var els: Dictionary = eff if not eff.is_empty() else elements
	if not extra.is_empty():
		els = els.duplicate()
		for e in extra:
			els[e] = maxi(els.get(e, 0), extra[e])
	var d := dmg * (dmg_k_bare() if no_size and not in_rx else dmg_k(in_rx))
	var dx := dice_x if not in_rx else 1.0  # 주사위: 반응 피해에는 안 곱한다
	d *= dx
	# 발동: 축적·삼연이 실린 공격(쏘는 순간 바로 맞히는 공격), 마무리(약한 구체)
	var fb := fire_boost if not in_rx else 1.0
	d *= fb
	var vm := 1.0
	if tg("vanguard") > 0 and not in_rx and o.hp >= o.max_hp * Rules.t("van_hp"):
		vm = van_mul(tg("vanguard"))
		if o.kind == Orb.Kind.BOSS:
			vm = 1.0 + (vm - 1.0) * 0.5
		d *= vm
	var fm := 1.0
	if tg("finish") > 0 and o.hp < o.max_hp * Rules.t("finish_hp"):
		fm = finish_mul(tg("finish"))
		if o.kind == Orb.Kind.BOSS:
			fm = 1.0 + (fm - 1.0) * 0.5
		d *= fm
	var crit := dx >= Rules.dice_top and k >= 1.0  # 대박은 치명타처럼 금색 숫자
	var lit := false  # 빛 치명타
	var cc := minf(Rules.light_ch * els.get(Elem.LIGHT, 0), Rules.light_max) * Share.am(self, Elem.LIGHT) if els.has(Elem.LIGHT) else 0.0
	if force_crit or cc > 0.0 and randf() < cc * minf(k, 1.0):
		d *= Rules.light_mul
		crit = k >= 1.0
		lit = not force_crit
	if els.has(Elem.WOOD) and o.vine > 0.0:
		# 나무 휘감기: 덩굴이 감긴 구체에 가시 피해
		d *= 1.0 + Rules.wood_dmg * mini(els.get(Elem.WOOD, 0), int(Rules.wood_cap)) * Share.am(self, Elem.WOOD)
	var mt := 0.0
	if els.has(Elem.METAL):
		mt = d * Rules.metal_dmg * els.get(Elem.METAL, 0)
		d += mt
		o.stagger(Rules.metal_stagger * els.get(Elem.METAL, 0) * k * Share.am(self, Elem.METAL))
	# 관통 (탄이 아닌 공격): 갑옷이 빼는 피해를 줄이고 보호막을 더 깎는다
	var ap := mf("pierce") if not in_rx and m("pierce") > 0 and not pattern in Pat.PROJECTILE else 0.0
	if o.late != "" and not in_rx and not in_zone:
		d = o.late_direct(d, k, ap)  # 후반 구체 갑옷·흐림: 직접 맞힌 공격만
	if o.jam == "leech" and not in_rx and o.silence_t <= 0.0:
		leech()  # 흡수 구체: 맞힌 오브젝트 공격 속도를 빼앗는다 (침묵이면 못 함)
	var rm := o.resist_mul(els)
	d *= rm
	if ap > 0.0 and o.shield > 0.0:
		# 남은 보호막이 0이 되면 hurt()가 깨지는 효과를 내도록 아주 조금 남긴다
		o.shield = maxf(o.shield - d * Rules.pierce_shield * ap * final_damage_mul(), 0.001)
	d = o.hurt(d, crit, self)  # 받는 피해 배율(약점 등)까지 곱한 값
	if main and not main.wells.is_empty():
		_well_feed(o, d)
	o.last_rx = in_rx or tag.begins_with("share:")
	dealt += d
	# 별: 둘레 별 오브젝트가 이 피해의 일부를 복사해 별빛으로 모은다 (이 피해는 줄지 않는다)
	if not in_nova and main and not _combat_port.star_towers.is_empty():
		# 한 피해를 여러 별이 받으면 별 수로 나눠 받는다 (별을 겹쳐 둬도 보너스는 1개분, 2026-11-01)
		var feeders: Array = []
		for s2 in _combat_port.star_towers:
			if s2 == self or s2.position.distance_to(position) < Rules.t("star_r"):
				feeders.append(s2)
		for s2 in feeders:
			s2.star_feed(d / feeders.size(), self)
	if in_rx:
		rx_dealt += d
	# 출처: 금속 고정 피해·빛 치명타로 늘어난 절반은 그 속성, 나머지는 지금 출처
	var key := tag if tag != "" else "hit"
	var rest := d
	if mt > 0.0:
		mt *= rm * final_damage_mul()
		rest -= mt
		src["elem:metal"] = src.get("elem:metal", 0.0) + mt
	if dx > 1.0:
		var dd := rest * (1.0 - 1.0 / dx)
		rest -= dd
		src["mod:dice"] = src.get("mod:dice", 0.0) + dd
	for bk in [[fb, fire_key], [fm, "trig:finish"], [vm, "trig:vanguard"]]:
		if bk[0] > 1.0 and bk[1] != "":
			var dd: float = rest * (1.0 - 1.0 / bk[0])
			rest -= dd
			src[bk[1]] = src.get(bk[1], 0.0) + dd
	if lit:
		rest *= 0.5
		src["elem:light"] = src.get("elem:light", 0.0) + rest
	src[key] = src.get(key, 0.0) + rest
	_pincer(o)
	if in_rx and notify_cd <= 0.0:
		notify_cd = 0.3
		_notify_allies(o.position)
	if o.hp <= 0.0 and echo_cd <= 0.0 and tg("echo") > 0:
		_echo(o)
	# 효과 (Elem.RIDER). 얼음 오래감은 지속 시간, 나무 자람은 먼 구체일수록 세기를 키운다 (Share)
	var dm := Share.dur(self)
	var g := Share.grow(self, o)
	var had_chill := o.chill
	if els.has(Elem.FIRE):
		o.burn(Rules.fire_dps * els.get(Elem.FIRE, 0) * rm * g * Share.am(self, Elem.FIRE), Rules.fire_t * dm, self)
	if els.has(Elem.POISON):
		o.poison(Rules.poison_dps * els.get(Elem.POISON, 0) * rm * g * Share.am(self, Elem.POISON), Rules.poison_t * dm, self)
	if els.has(Elem.ICE):
		o.add_chill(Rules.ice_chill * k * els.get(Elem.ICE, 0) * g * Share.am(self, Elem.ICE), dm)
	if els.has(Elem.WATER):
		o.slow(Share.slow_f(els.get(Elem.WATER, 0), Share.am(self, Elem.WATER)), Rules.water_t * dm)
	if els.has(Elem.WOOD):
		o.entangle(Share.WOOD_VINE * els.get(Elem.WOOD, 0) * minf(k, 1.0) * Share.am(self, Elem.WOOD), dm)
	if els.has(Elem.WIND) and o.hp > 0.0:
		var away := o.position - position
		if away.length() > 0.5:
			o.knock(away.normalized() * Share.WIND_HIT * els.get(Elem.WIND, 0) * minf(k, 1.0) * Share.am(self, Elem.WIND))
	if els.has(Elem.EARTH) and randf() < Share.root_ch(self, els.get(Elem.EARTH, 0)) * k * g:
		o.root(Rules.earth_t * dm)
	if els.has(Elem.DARK):
		o.vuln(Rules.dark_t * dm, (Rules.dark_vuln + Rules.dark_lv * els.get(Elem.DARK, 0)) * g * Share.am(self, Elem.DARK), self)
	if els.has(Elem.ELECTRIC) and randf() < Rules.elec_ch * k * Share.am(self, Elem.ELECTRIC):
		_spawning_port.arc(o, d * Rules.elec_dmg * els.get(Elem.ELECTRIC, 0), self)
	if els.has(Elem.SOUND):
		# 울림을 걸어 둔다: 3초 동안 어느 오브젝트에 맞아도 쌓인다
		if o.tune_t <= 0.0 or els.get(Elem.SOUND, 0) >= o.tune_lv:
			o.tune_lv = els.get(Elem.SOUND, 0)
			o.tune_src = self
		o.tune_t = maxf(o.tune_t, Rules.sound_t * dm)
	if o.tune_t > 0.0:
		_ring(o, minf(k, 1.0))
	if els.has(Elem.TIME):
		o.echo(minf(Rules.time_base + Rules.time_lv * els.get(Elem.TIME, 0), Rules.time_max) * minf(g, 1.5), Rules.time_t * dm, self)
	if els.has(Elem.SOUL):
		if o.soul_t <= 0.0 or els.get(Elem.SOUL, 0) >= o.soul_lv:
			o.soul_lv = els.get(Elem.SOUL, 0)
			o.soul_src = self
		o.soul_t = maxf(o.soul_t, Rules.soul_t * dm)
	if els.has(Elem.BLOOD):
		o.bleed(Share.bleed_k(self, els.get(Elem.BLOOD, 0), rm) * g, Rules.blood_t * dm, self, "elem:blood", Share.has(self, "sepsis"))
	if els.has(Elem.ILLUSION) and o.hp > 0.0 and randf() < Share.illu_ch(self, els.get(Elem.ILLUSION, 0)) * minf(k, 1.0) * minf(g, 1.5):
		o.confuse(Rules.illu_t * dm, Share.has(self, "nightmare"))
	# 특징 공유: 금속 응축 · 빛 꿰뚫음 · 땅 묻어둠 · 시간 되풀이 (나머지 특징은 전류·음파·죽을 때·물길에서)
	if o.hp > 0.0:
		Share.condense(self, o, Share.carry_n(self), minf(k, 1.0))
	if lit:
		Share.pierce(self, o)
	Share.aff_hit(self, o, k, lit, had_chill)
	Share.on_hit(self, o, false)
	Share.mark(self, o)
	if not in_rx and mirror_src != null and mirror_t > 0.0:
		Share.reflect(self, o)
	if not in_rx and bounce_cd <= 0.0 and m("bounce") > 0 and not pattern in Pat.PROJECTILE and pattern != "chain" and not tag.begins_with("mod:"):
		_area_bounce(o)
	if can_split and m("split") > 0 and randf() < split_ch() * minf(k, 1.0):
		for i in 2:
			var p: Projectile = _spawning_port.spawn_proj(self, "frag", plv, Vector2.from_angle(randf() * TAU))
			p.src = "mod:split"
			p.dmg *= Rules.t("split_dmg")
			p.position = o.position
			p.hit[o] = true


# ---------- 별 ----------

## 별·행성 그림: 둘레 게이지 고리(찬 만큼, 행성은 그 속성 색), 행성은 기운 궤도 고리.
## NOVA_WARN부터 고리가 빨리 뛰고 빛이 별로 빨려 들며, 터질 자리(nova_aim)에 조준 고리. 다 차면 크게 맥동.
## 터질 때 별 → 자리 빛줄기, 섬광, 충격파 두 겹, 빛살 8갈래 (NOVA_FX_T초).
func _draw_star() -> void:
	var f := clampf(star_sum / maxf(star_need(), 0.001), 0.0, 1.0) if main else 0.0
	var sc := NOVA_COL
	var pe := planet()
	var gc: Color = Elem.COLORS[pe].lightened(0.3) if pe >= 0 else sc
	var gr := RADIUS + GAUGE_GAP
	if pe >= 0:
		var pc: Color = Elem.COLORS[pe]
		var ring := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			ring.append(Vector2(cos(a) * (gr + 7.0), sin(a) * (gr + 7.0) * 0.38).rotated(-0.35))
		draw_polyline(ring, Color(pc, 0.85), 2.5)
	var warn := f >= NOVA_WARN
	var full := f >= 1.0
	# 게이지: 몸체·속성 점(RADIUS+7)과 떨어진 바깥 고리. 어두운 바탕 + 옅은 빈 칸 + 찬 만큼 (위에서 시계 방향), 4분의 1마다 눈금
	draw_arc(Vector2.ZERO, gr, 0, TAU, 48, Color(0, 0, 0, 0.7), GAUGE_W + 4.0)
	draw_arc(Vector2.ZERO, gr, 0, TAU, 48, Color(gc, 0.3), GAUGE_W)
	if f > 0.0:
		var w := GAUGE_W
		if warn and not full:
			w = GAUGE_W + 2.5 * (0.5 + 0.5 * sin(t * 14.0))
		draw_arc(Vector2.ZERO, gr, -PI / 2.0, -PI / 2.0 + TAU * f, 48, Color(gc.lightened(0.15), 1.0), w)
		if not full:
			draw_circle(Vector2.from_angle(-PI / 2.0 + TAU * f) * gr, GAUGE_W * 0.6, Color.WHITE)
	for i in 4:
		var dv := Vector2.from_angle(-PI / 2.0 + PI / 2.0 * i)
		draw_line(dv * (gr - GAUGE_W * 0.5 - 1.0), dv * (gr + GAUGE_W * 0.5 + 1.0), Color(0, 0, 0, 0.8), 1.5)
	if warn:
		# 곧 터짐: 바깥에서 별로 빨려 드는 빛
		var n := 6
		for i in n:
			var ph := fmod(t * 1.6 + float(i) / n, 1.0)
			var d := lerpf(gr + 26.0, gr, ph)
			draw_circle(Vector2.from_angle(TAU * i / n + t * 0.7) * d, 1.2 + 1.8 * ph, Color(gc, 0.25 + 0.6 * ph))
	if full:
		var pu := 0.5 + 0.5 * sin(t * 9.0)
		draw_circle(Vector2.ZERO, gr + 2.0 + 3.0 * pu, Color(sc, 0.18))
		draw_arc(Vector2.ZERO, gr + GAUGE_W + 2.0 + 4.0 * pu, 0, TAU, 48, Color(1, 1, 1, 0.5 + 0.4 * pu), 2.0)
	for fr in feed_fx:
		if is_instance_valid(fr):
			draw_line(fr.position - position, Vector2.ZERO, Color(gc, 0.35 * feed_fx[fr] / 0.4), 1.5)
	var nr := NOVA_R + 10.0 * (lv(Elem.STAR) - 1)
	if warn and is_instance_valid(nova_aim) and nova_aim.hp > 0.0:
		# 터질 자리 예고: 초신성 반지름 점선 고리 + 가운데 십자, 찰수록 진해짐
		var p := nova_aim.position - position
		var al := lerpf(0.45, 0.95, clampf((f - NOVA_WARN) / (1.0 - NOVA_WARN), 0.0, 1.0))
		var rot := t * 0.8
		var segs := 24
		for i in segs:
			var a := rot + TAU * i / segs
			draw_arc(p, nr, a, a + TAU / segs * 0.5, 4, Color(sc, al), 3.0)
		draw_circle(p, nr, Color(sc, 0.07 * al))
		for i in 4:
			var dv := Vector2.from_angle(-rot * 1.5 + PI / 2.0 * i)
			draw_line(p + dv * 10.0, p + dv * 24.0, Color(sc, al), 3.0)
	if nova_fx > 0.0:
		var p := nova_pos - position
		var o := nova_from - position
		var k := nova_fx / NOVA_FX_T  # 1 → 0
		var e := 1.0 - k
		# 빛줄기 (처음 0.3만 굵게)
		var bk := clampf(1.0 - e / 0.4, 0.0, 1.0)
		if bk > 0.0:
			draw_line(o, p, Color(sc, 0.85 * bk), 12.0 * bk + 1.0)
			draw_line(o, p, Color(1, 1, 1, 0.9 * bk), 4.0 * bk + 0.5)
		# 섬광: 처음에 반지름만큼 밝게, 빨리 꺼짐
		var fl := clampf(1.0 - e / 0.35, 0.0, 1.0)
		if fl > 0.0:
			draw_circle(p, nr * (0.6 + 0.4 * e), Color(sc.lerp(Color.WHITE, 0.6), 0.45 * fl))
			draw_circle(p, nr * 0.35, Color(1, 1, 1, 0.8 * fl))
		# 충격파 두 겹
		draw_arc(p, nr * (0.2 + 1.1 * e), 0, TAU, 48, Color(sc, k), 2.0 + 6.0 * k)
		var e2 := clampf((e - 0.2) / 0.8, 0.0, 1.0)
		if e2 > 0.0:
			draw_arc(p, nr * (0.2 + 0.8 * e2), 0, TAU, 48, Color(1, 1, 1, 0.6 * (1.0 - e2)), 2.0)
		# 빛살 8갈래
		for i in 8:
			var dv := Vector2.from_angle(TAU * i / 8.0 + e * 0.6)
			var l0 := nr * 0.25
			var l1 := nr * (0.7 + 0.7 * e) * (1.0 if i % 2 == 0 else 0.65)
			draw_line(p + dv * l0, p + dv * l1, Color(sc.lerp(Color.WHITE, 0.4), 0.85 * k), 3.0 * k + 0.5)
		# 별 자리: 터뜨린 별 둘레로 퍼지는 고리
		draw_arc(o, RADIUS + 6.0 + 40.0 * e, 0, TAU, 32, Color(sc, 0.8 * k), 2.5)

const STAR_MAX_ELEMS := 2  # 별 + 속성 하나 = 그 속성의 행성
static var NOVA_R := 110.0  # 초신성 반지름 (별 레벨마다 +10)
const NOVA_COL := Color(1.0, 0.85, 0.35)  # 별빛 게이지·예고·초신성 색 (별 속성 색보다 진한 금빛)
const NOVA_FX_T := 0.75  # 초신성 그림 시간
const GAUGE_GAP := 16.0  # 별빛 게이지 고리 반지름 = RADIUS + 이만큼 (속성 점 RADIUS+7·축적 고리 RADIUS+10보다 바깥)
const GAUGE_W := 5.0  # 별빛 게이지 두께
static var NOVA_WARN := 0.85  # 별빛이 이만큼 차면 곧 터짐 표시·터질 자리 예고
const NOVA_AIM_T := 0.25  # 터질 자리 다시 고르는 간격


## 별만 든 오브젝트(행성이 아닌 별).
func pure_star() -> bool:
	return order.size() == 1 and elements.has(Elem.STAR)


## 속성 e를 넣으면 행성이 되는데 못 만드는 이유 (같은 행성이 이미 있음·행성 최대·별 최대). 행성이 안 되면 빈 글.
func planet_refuse(e: int) -> String:
	if elements.has(e) or order.size() != 1 or main == null:
		return ""
	if e == Elem.STAR and not elements.has(Elem.STAR) and star_count(main, self) >= int(Rules.t("star_max")):
		return star_full_text()
	var pe := -1
	if elements.has(Elem.STAR) and e != Elem.STAR:
		pe = e
	elif e == Elem.STAR and not elements.has(Elem.STAR):
		pe = order[0]
	if pe < 0:
		return ""
	var n := 0
	for t2 in main.towers.get_children():
		if t2 != self and t2.planet() >= 0:
			if t2.planet() == pe:
				return "%s의 행성은 이미 있어요 (같은 행성은 한 판에 하나)" % Elem.NAMES[pe]
			n += 1
	if n >= int(Rules.t("planet_max")):
		return "행성은 %d개까지예요" % int(Rules.t("planet_max"))
	return ""


## 별이 든 오브젝트(별·행성) 수. except는 빼고 센다.
static func star_count(m: Node, except: Node = null) -> int:
	var n := 0
	for t2 in m.towers.get_children():
		if t2 != except and not t2.is_queued_for_deletion() and t2.elements.has(Elem.STAR):
			n += 1
	return n


static func star_full_text() -> String:
	return "별·행성은 합쳐 %d개까지예요. 있는 별에 겹치면 레벨업" % int(Rules.t("star_max"))


## 행성이면 별과 함께 든 속성, 아니면 -1.
func planet() -> int:
	if not elements.has(Elem.STAR):
		return -1
	for e in order:
		if e != Elem.STAR:
			return e
	return -1


## 초신성까지 필요한 별빛: 이번 웨이브 구체 평균 체력(종류 보정 전) x star_need.
func star_need() -> float:
	var w: int = maxi(main.wave, 1) if main else 1
	var g: float = main.hp_growth(w) if main else 1.0
	return (1.5 + 0.7 * w) * g * Rules.orb_hp * Rules.t("star_need")


## 별빛 모으는 비율: 다른 오브젝트 피해의 star_take(+레벨), 자기 피해는 star_self. 별만 든 오브젝트는 x star_pure.
func star_rate(from_self: bool) -> float:
	if from_self:
		return Rules.t("star_self")  # 자기 피해 흡수엔 순수 별 보너스 없음 (혼자 굴러가지 않게, 2026-11-01)
	var l := mini(lv(Elem.STAR), int(Rules.t("star_lv_cap"))) - 1  # 레벨 성장은 star_lv_cap(Lv5)까지, 그 뒤 레벨은 초신성 범위만
	return (Rules.t("star_take") + Rules.t("star_lv") * maxi(l, 0)) * (Rules.t("star_pure") if pure_star() else 1.0)


## 행성이 오브젝트 from의 피해에서 모으는 비율: 내 속성 몫(속성 레벨 비율)은 planet_take(+별 레벨마다 planet_lv),
## 나머지 몫은 planet_other, 자기 피해는 planet_self (2026-11-01: 예전엔 내 속성 몫 30%만·자기 20%라 순수 별보다 훨씬 늦게 찼음)
func planet_rate(from: Tower) -> float:
	if from == self:
		return Rules.t("planet_self")
	var pe := planet()
	var share := float(from.lv(pe)) / maxf(from.total_level(), 1.0) if from.elements.has(pe) else 0.0
	var pl := maxi(mini(lv(Elem.STAR), int(Rules.t("star_lv_cap"))) - 1, 0)  # 별 레벨 성장은 star_lv_cap(Lv5)까지
	return (Rules.t("planet_take") + Rules.t("planet_lv") * pl) * share + Rules.t("planet_other") * (1.0 - share)


## 중력 우물 흡수: 우물 안 구체가 다른 오브젝트에게 받은 피해의 일부를 그 우물에 모은다 (피해는 줄지 않음)
func _well_feed(o: Orb, d: float) -> void:
	for w in main.wells:
		if is_instance_valid(w) and not w.dead and w.owner_tower != self and o.position.distance_squared_to(w.position) < w.radius * w.radius:
			w.store += d * w.absorb


## 피해 d를 준 오브젝트 from에게서 별빛을 모은다. 둘레 오브젝트의 속성(별 제외)도 같이 적어 둔다.
## 행성은 planet_rate: 내 속성 몫은 크게, 나머지 몫은 조금.
func star_feed(d: float, from: Tower) -> void:
	var need := star_need()
	if star_sum >= need or d <= 0.0:
		return
	var pe := planet()
	var rate := star_rate(from == self)
	if pe >= 0:
		rate = planet_rate(from)
	var amt := minf(d * rate, need - star_sum)
	star_sum += amt
	if from != self:
		feed_fx[from] = 0.4
	if pe >= 0:
		if from != self:
			star_e[pe] = star_e.get(pe, 0.0) + amt
		return
	if from != self:
		var n := 0
		for e in from.elements:
			if e != Elem.STAR:
				n += 1
		for e in from.elements:
			if e != Elem.STAR:
				star_e[e] = star_e.get(e, 0.0) + amt / n


## 초신성 자리: 사거리(450) 안에서 둘레(110)에 구체가 가장 많이 모인 구체. 없으면 아낀다.
func _try_nova() -> void:
	var best := _nova_pick()
	if best:
		_supernova(best)


## 별빛이 NOVA_WARN 이상이면 지금 터지면 맞을 구체를 골라 둔다 (그림이 그 자리에 예고를 그린다).
func _nova_aim_tick(delta: float) -> void:
	if lv(Elem.STAR) <= 0 or star_sum < star_need() * NOVA_WARN:
		nova_aim = null
		return
	nova_aim_t -= delta
	if nova_aim_t <= 0.0 or not is_instance_valid(nova_aim) or nova_aim.hp <= 0.0:
		nova_aim_t = NOVA_AIM_T
		nova_aim = _nova_pick()


## 초신성 자리 고르기 (_try_nova와 예고가 같이 쓴다).
func _nova_pick() -> Orb:
	var best: Orb = null
	var bn := -1
	for o in _combat_port.near(position, 450.0):
		if o.hp <= 0.0 or o.position.distance_to(position) > 450.0:
			continue
		var n: int = _combat_port.near(o.position, 110.0).size()
		if n > bn:
			bn = n
			best = o
	return best


## 모은 속성 중 많은 순 3개 → 레벨 3·2·1.
func nova_mix() -> Dictionary:
	var ks := star_e.keys()
	ks.sort_custom(func(a, b): return star_e[a] > star_e[b])
	var out := {}
	for i in mini(ks.size(), 3):
		out[ks[i]] = 3 - i
	return out


## 초신성: 별빛 x star_mul을 가운데 구체에 절반, 둘레 구체에 나머지 절반을 나눠 넣는다.
## 모은 속성의 부가효과를 한꺼번에 걸고, 모은 속성끼리 반응이 있으면 그 몫(별빛 x0.15)을 더한다.
## 모은 속성이 3종이면 저항·굳셈을 무시한다. 행성이면 그 속성 효과가 따라붙는다(_nova_follow).
func _supernova(c: Orb) -> void:
	var pool := star_sum * Rules.t("star_mul") * (Rules.t("planet_mul") if planet() >= 0 else 1.0)
	var mix := nova_mix()
	star_sum = 0.0
	star_e.clear()
	in_nova = true
	var r := NOVA_R + 10.0 * (lv(Elem.STAR) - 1)
	var hits := []
	for o in _combat_port.near(c.position, r + 30.0):
		if o.hp > 0.0 and o.position.distance_to(c.position) < r + o.radius():
			hits.append(o)
	if not c in hits:
		hits.append(c)
	var others := hits.size() - 1
	var rx_bonus := 0.0
	var ids := mix.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var rr := Elem.reaction_of(ids[i], ids[j])
			if not rr.is_empty():
				rx_bonus += 0.15
				_spawning_port.burst(c.position, rr["color"], 12, 200.0)
	var total := 0.0
	var cap := {}  # 보스마다 이번 초신성(행성 효과 포함)으로 더 깎을 수 있는 체력 (star_boss_cap, nova_hurt가 채움)
	for o in hits:
		var share: float = (pool * (0.5 if others > 0 else 1.0) if o == c else pool * 0.5 / others) * (1.0 + rx_bonus)
		if mix.size() >= 3:
			o.silence_t = maxf(o.silence_t, 0.3)  # 저항·굳셈 무시
		else:
			share *= o.resist_mul(mix)
		var got: float = nova_hurt(o, share, cap, o == c)
		credit(got, "elem:star")
		total += got
		if not mix.is_empty() and o.hp > 0.0:
			# 모은 속성의 부가효과만 (피해는 거의 없음)
			in_rx = true
			tag = "elem:star"
			hit(o, 0.01, 1.0, mix, false)
			in_rx = false
			tag = ""
	_nova_follow(c.position, hits, pool, cap)
	in_nova = false
	nova_fx = NOVA_FX_T
	nova_pos = c.position
	nova_from = position
	nova_aim = null
	_spawning_port.burst(c.position, Elem.COLORS[Elem.STAR], 40, 320.0)
	_spawning_port.popup(c.position + Vector2(0, -30), total, Elem.COLORS[Elem.STAR], true, "초신성!", 1.2)
	main.shake = maxf(main.shake, 0.25)
	_notify_allies(c.position)


## 초신성 피해: 보스면 cap에 남은 만큼만 (받는 피해 배율까지 맞춰 줄이고, 깎인 만큼 cap에서 뺀다).
func nova_hurt(o: Orb, d: float, cap: Dictionary, crit := false) -> float:
	if o.kind != Orb.Kind.BOSS:
		return o.hurt(d, crit, self)
	if not cap.has(o):
		cap[o] = o.max_hp * Rules.t("star_boss_cap")
	var left: float = cap[o]
	if left <= 0.0:
		return 0.0
	var k := o.hurt_mul()
	if d * k > left:
		d = left / maxf(k, 0.001)
	var got := o.hurt(d, crit, self)
	cap[o] = maxf(left - got, 0.0)
	return got


## 지속 피해(화상·중독)를 보스에게 걸 때 총량을 cap 안으로 줄이고 그만큼 미리 뺀다.
func _nova_dot(o: Orb, total: float, cap: Dictionary) -> float:
	if o.kind != Orb.Kind.BOSS:
		return total
	if not cap.has(o):
		cap[o] = o.max_hp * Rules.t("star_boss_cap")
	var t := minf(total, cap[o])
	cap[o] = cap[o] - t
	return t


func _nova_follow(at: Vector2, hits: Array, _pool: float, _cap: Dictionary) -> void:
	# 별 모음 (특징 공유): 초신성이 맞힌 구체 모두에 이 오브젝트 효과 (행성이면 그 속성 효과, 그 속성 특징도 붙음)
	var ks := Share.k(self, Elem.STAR)
	if ks <= 0.0 or hits.is_empty() or not Share.has_carry(self):
		return
	for o in hits:
		Share.carry(self, o, Share.STAR_F * ks, "share:star", at, o.position.distance_to(at) / 200.0)
	var e := planet()
	_spawning_port.burst(at, Elem.COLORS[e] if e >= 0 else NOVA_COL, 24, 240.0)


## 여진: 잡은 구체 자리에서 작은 탄이 고르게 사방으로 (쏘는 방향은 판마다 조금씩 돈다).
func _echo(o: Orb) -> void:
	echo_cd = Rules.t("echo_cd")
	_notify_allies(o.position)
	var n := int(Rules.t("echo_n")) + tg("echo") - 1
	var a0 := randf() * TAU
	for i in n:
		var p: Projectile = _spawning_port.spawn_proj(self, "frag", plv, Vector2.from_angle(a0 + TAU * i / n))
		p.src = "trig:echo"
		p.dmg *= Rules.t("echo_dmg")
		p.position = o.position
		p.hit[o] = true


# ---------- 물 흐름 (Elem.TRAIT 물) ----------

## 날아가는 공격이 지나간 길 (70마다): 물이 든 오브젝트면 물길 (밟은 구체에 이 오브젝트 효과, Zone rill).
func form_path(pos: Vector2) -> void:
	var a := Share.k(self, Elem.WATER)
	if a <= 0.0 or not Share.has_carry(self) or main.zones.get_child_count() >= 160:
		return
	var old_tag := tag
	tag = "share:water"
	var z: Zone = _spawning_port.spawn_zone("rill", plv, pos, self)
	z.amt = a
	z.life *= Share.dur(self)
	z.max_life = z.life
	tag = old_tag


## 특징이 만들 수 있는 장판: 날아가는 공격이 지나간 길(form_path)의 물길뿐 (spec ELEM-10)
const FORM_ZONES := ["rill"]


## d 방향 부채꼴 안의 구체에 효과.
func _cone(_orbs: Array, d: Vector2, rng: float, half: float, f: Callable) -> void:
	for o in _combat_port.near_t(position, rng):
		var v: Vector2 = o.position - position
		if v.length() < rng + o.radius() and absf(d.angle_to(v)) < half:
			f.call(o)


## from에서 d 방향 띠(길이 length, 반폭 half_w) 안의 구체에 효과.
func _band(_orbs: Array, from: Vector2, d: Vector2, length: float, half_w: float, f: Callable) -> void:
	for o in _combat_port.near_t(from + d * length * 0.5, length * 0.5 + half_w + 32.0):
		var v: Vector2 = o.position - from
		var along := v.dot(d)
		if along > -o.radius() and along < length + o.radius() and absf(v.cross(d)) < half_w + o.radius():
			f.call(o)


## d 방향 직선 위의 구체에 효과.
func _line(_orbs: Array, d: Vector2, length: float, width: float, f: Callable, off := Vector2.ZERO) -> void:
	var p0 := position + off  # off: 다중 발사 짝수 개일 때 나란히 쏘는 옆 간격 (lanes)
	for o in _combat_port.near_t(p0 + d * length * 0.5, length * 0.5 + width):
		var v: Vector2 = o.position - p0
		var along := v.dot(d)
		if along > 0.0 and along < length and absf(v.cross(d)) < width + o.radius():
			f.call(o)


## d 방향 앞쪽의 가장 가까운 구체를 치고 주변으로 튄다. used: 다중 발사 때 같은 첫 대상 피하기
func _chain(orbs: Array, d: Vector2, l: int, used: Dictionary) -> bool:
	var first: Orb = null
	var best: float = FAR
	for o in _combat_port.near_t(position, best):
		var v: Vector2 = o.position - position
		if not used.has(o) and v.length() < best and absf(d.angle_to(v)) < SHAPE.chain_ang:
			best = v.length()
			first = o
	if first == null:
		return false
	used[first] = true
	var fk := far_k(best, far_start())  # 첫 대상이 멀면 번개 전체가 약해진다
	var pts := PackedVector2Array([position + d * RADIUS])
	var cur := first
	var hitset := {}
	for i in int(SHAPE.chain_n) + l + mn("bounce"):
		hitset[cur] = true
		pts.append(cur.position)
		hit(cur, HIT.chain * pw(l) * multi_k() * fk)
		var nxt: Orb = null
		var nd: float = SHAPE.chain_jump * sz()
		for o in _combat_port.near_t(cur.position, nd):
			if not hitset.has(o) and o.position.distance_to(cur.position) < nd:
				nd = o.position.distance_to(cur.position)
				nxt = o
		if nxt == null:
			break
		cur = nxt
	chain_end = cur.position
	# 번개는 구체·블랙홀에 가려지지 않게 맨 위 층(main)에 그린다
	_spawning_port.bolt(pts)
	return true


# ---------- 그리기 ----------

func _draw() -> void:
	if owner_id > 0:
		_draw_owner_glow()
	if main and main.wave_active:
		_draw_attack()
	_draw_body()
	_draw_rank()
	if owner_id > 0:
		_draw_owner_mark()
	if req_e >= 0 and Elem.COLORS.has(req_e):
		# 협동 속성 요청: 머리 위 그 속성 색 방울 + 물음표 (다른 사람이 그 속성을 넣어 줄 수 있음)
		var c := Elem.COLORS[req_e] as Color
		var p := Vector2(RADIUS + 8.0, -RADIUS - 12.0)
		draw_line(p + Vector2(-5, 7), Vector2(RADIUS * 0.5, -RADIUS * 0.5), Color(1, 1, 1, 0.5), 1.5)
		draw_circle(p, 10.0, Color(0, 0, 0, 0.7))
		draw_circle(p, 8.0, c)
		draw_arc(p, 10.5, 0.0, TAU, 24, Color(1, 1, 1, 0.95), 2.0)
		draw_circle(p, 2.5, Color(1, 1, 1, 0.95))


## 협동: 누가 놓은 오브젝트인지. 발밑에 주인 색 빛 + 바깥 고리, 남의 것엔 아래에 이름 첫 글자 배지.
## [보기] 필터로 고른 사람 것은 고리가 숨 쉬듯 밝아진다 (나머지는 main이 흐리게).
func _draw_owner_glow() -> void:
	var c := Mp.owner_color(owner_id)
	var r := RADIUS  # 몸은 크기와 무관하게 RADIUS로 그려진다
	draw_circle(Vector2.ZERO, r + 14.0, Color(c, 0.08))
	draw_circle(Vector2.ZERO, r + 8.0, Color(c, 0.14))


func _draw_owner_mark() -> void:
	var c := Mp.owner_color(owner_id)
	var r := RADIUS + 5.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, c, 3.0, true)
	var focus: bool = main != null and int(main.get("mp_view")) == owner_id
	if focus:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_arc(Vector2.ZERO, r + 4.0 + 3.0 * k, 0.0, TAU, 36, Color(c, 0.35 + 0.4 * k), 2.0, true)
	if main == null or owner_id == main.mp.my_id:
		return
	var nm: String = _multiplayer_port._mp_name(owner_id)
	var p := Vector2(r * 0.71, r * 0.71)  # 오른쪽 아래 (왕관은 왼쪽 위, 요청 방울은 오른쪽 위)
	draw_circle(p, 8.5, Color(0, 0, 0, 0.75))
	draw_circle(p, 7.0, c)
	var font: Font = main.ui_font if main.ui_font else ThemeDB.fallback_font
	draw_string(font, p + Vector2(-8.0, 4.5), nm.left(1), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 12, Color(0.05, 0.05, 0.08))


const CROWN_FLY := 0.4  # 1위가 바뀔 때 왕관이 날아가는 시간
var crown_from := Vector2.ZERO  # 날아오기 시작한 자리 (이 오브젝트 기준)
var crown_t := 0.0
const RANK_COLORS := [Color(1.0, 0.82, 0.25), Color(0.85, 0.88, 0.95), Color(0.85, 0.55, 0.3)]


## 피해 1위 왕관, 2·3위 메달 (왼쪽 위, 협동 요청 방울은 오른쪽 위)
func _draw_rank() -> void:
	if not main:
		return
	var r: int = _hud_port.rank_of.get(get_instance_id(), 0)
	if r == 0:
		return
	var c: Color = RANK_COLORS[r - 1]
	var bob := sin(Time.get_ticks_msec() / 400.0) * 1.5
	var k := clampf(Meta.ui_scale, 1.0, 1.4)  # 글자 크기 설정만큼 같이 키운다 (폰 1.3)
	if r == 1:
		var at := Vector2(-RADIUS * 1.05, -RADIUS - 1.0 + bob)
		if crown_t > 0.0:
			var f := 1.0 - crown_t / CROWN_FLY
			at = (crown_from + at).lerp(at, f) + Vector2(0, -30.0 * sin(PI * f))  # 위로 포물선
		draw_set_transform(at, -0.6, Vector2(k, k) * 1.15)
		var w := 12.0
		var pts := PackedVector2Array([Vector2(-w, 5), Vector2(-w, -4), Vector2(-w * 0.5, 1), Vector2(0, -8), Vector2(w * 0.5, 1), Vector2(w, -4), Vector2(w, 5)])
		var out := pts.duplicate()
		out.append(pts[0])
		draw_colored_polygon(pts, c)
		draw_polyline(out, Color(0.25, 0.15, 0.0, 0.95), 1.6)
		draw_rect(Rect2(-w, 5, w * 2.0, 3), c.darkened(0.25))
		for p in [Vector2(-w, -4), Vector2(0, -8), Vector2(w, -4)]:
			draw_circle(p, 1.8, Color(1, 1, 0.9))
		draw_circle(Vector2(0, 2), 1.8, Color(0.95, 0.25, 0.3))
		var sp := fmod(Time.get_ticks_msec() / 1000.0, 2.0)
		if sp < 0.4:
			var a: float = 1.0 - absf(sp - 0.2) / 0.2
			draw_line(Vector2(w * 0.5, -6) + Vector2(-3, 0), Vector2(w * 0.5, -6) + Vector2(3, 0), Color(1, 1, 1, a), 1.2)
			draw_line(Vector2(w * 0.5, -6) + Vector2(0, -3), Vector2(w * 0.5, -6) + Vector2(0, 3), Color(1, 1, 1, a), 1.2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(Vector2(-RADIUS * 0.95, -RADIUS * 0.95), 0.0, Vector2(k, k))
		draw_circle(Vector2.ZERO, 9.0, Color(0.1, 0.08, 0.05, 0.9))
		draw_circle(Vector2.ZERO, 7.5, c)
		draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 20, c.lightened(0.4), 1.2)
		draw_string(ThemeDB.fallback_font, Vector2(-7.5, 4.8), str(r), HORIZONTAL_ALIGNMENT_CENTER, 15, 13, Color(0.12, 0.08, 0.04))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _process(delta: float) -> void:
	if crown_t > 0.0:
		crown_t = maxf(crown_t - delta, 0.0)
	if main and _hud_port.rank_of.has(get_instance_id()):
		queue_redraw()  # 왕관 흔들림·반짝임 (오브젝트 최대 3개)
	if place_pop > 0.0:
		place_pop = maxf(place_pop - delta * 3.0, 0.0)
		queue_redraw()
		queue_redraw()


var _body: Array = []  # [점들, 색, 고리 모양이면 true]
var _body_key := 0


func _draw_body() -> void:
	var s := 1.0 + 0.5 * place_pop
	draw_set_transform(-dir * recoil * 5.0, 0.0, Vector2(s, s))
	if place_pop > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 20.0 * (1.0 - place_pop), 0, TAU, 32, Color(1, 1, 1, place_pop), 3.0)
	if pincer > 0:
		# 협공: 세 갈래 화살표가 안쪽을 겨눈다
		for i in 3:
			var a := TAU * i / 3.0 - t * 0.8
			var p := Vector2.from_angle(a) * (RADIUS + 10.0)
			var tip := Vector2.from_angle(a) * (RADIUS + 3.0)
			var side := Vector2.from_angle(a).orthogonal() * 4.0
			draw_colored_polygon(PackedVector2Array([tip, p + side, p - side]), Color(1.0, 0.55, 0.85, 0.85))
	if focus_t > 0.0:
		# 중앙 기술 집중: 남은 시간만큼 줄어드는 금색 두꺼운 고리
		var ff := focus_t / maxf(Rules.t("skill_focus_t"), 0.01)
		draw_arc(Vector2.ZERO, RADIUS + 9.0, -PI / 2.0, -PI / 2.0 + TAU * ff, 28, Color(Skill.COLORS["focus"], 0.95), 4.0)
	if jam_t > 0.0:
		# 방해 구체에 멈춤: 어두운 막 + 가로 막대
		draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(0.05, 0.03, 0.1, 0.6))
		draw_line(Vector2(-RADIUS * 0.7, 0), Vector2(RADIUS * 0.7, 0), Color(0.75, 0.6, 1.0, 0.95), 4.0)
	elif leech_n > 0:
		# 흡수당함: 겹친 만큼 초록 점
		for i in leech_n:
			draw_circle(Vector2.from_angle(PI / 2.0 + (i - (leech_n - 1) / 2.0) * 0.35) * (RADIUS + 7.0), 2.5, Color(0.45, 0.95, 0.5, 0.95))
	if tg("vanguard") > 0:
		# 선봉: 겨눈 쪽 바깥에 작은 화살촉 (앞줄에서 먼저 때리는 오브젝트)
		var vd := aim.normalized() if aim.length() > 0.01 else dir
		var tip := vd * (RADIUS + 11.0)
		draw_colored_polygon(PackedVector2Array([tip, tip - vd * 7.0 + vd.orthogonal() * 5.0, tip - vd * 7.0 - vd.orthogonal() * 5.0]), Color(Pat.TRIG_COLOR, 0.9))
	if elements.has(Elem.STAR):
		_draw_star()
	if tg("charge") > 0:
		# 축적: 모인 만큼 차오르는 얇은 고리, 다 차면 진하게 깜빡임
		var cf := charge / float(charge_need())
		var ca := 0.9 if cf < 1.0 else 0.6 + 0.4 * sin(t * 10.0)
		draw_arc(Vector2.ZERO, RADIUS + 10.0, -PI / 2.0, -PI / 2.0 + TAU * cf, 32, Color(1.0, 0.85, 0.35, ca), 2.0)
	if tg("third") > 0:
		# 삼연: 위에 점 3개, 쏜 만큼 켜짐 (다 켜지면 다음이 강한 공격)
		for i in 3:
			draw_circle(Vector2(-7.0 + 7.0 * i, -RADIUS - 8.0), 2.2, Color(Pat.TRIG_COLOR, 0.95 if i < third_n % 3 else 0.3))
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
	if skin == "halo":
		# 후광 (전설 업적 '외로운 탑'): 머리 위 고리와 도는 빛 셋
		var now := Time.get_ticks_msec() / 1000.0
		draw_arc(Vector2(0, -RADIUS * 0.15), RADIUS + 5.0, 0, TAU, 40, Color(1, 0.9, 0.55, 0.55 + 0.25 * sin(now * 2.4)), 2.0)
		for i in 3:
			draw_circle(Vector2.from_angle(now * 1.6 + TAU * i / 3.0) * (RADIUS + 5.0) + Vector2(0, -RADIUS * 0.15), 2.2, Color(1, 0.95, 0.7))
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
		draw_string(ThemeDB.fallback_font, Vector2(-6, -RADIUS - 6), str(total), HORIZONTAL_ALIGNMENT_LEFT, -1, Meta.fs(13), Color.WHITE)
	# 강화 개수: 아래쪽 작은 점
	var nm := 0
	for id in mods:
		nm += mods[id]
	for i in mini(nm, 8):
		draw_circle(Vector2(-(mini(nm, 8) - 1) * 3.0 + i * 6.0, RADIUS + 7.0), 2.0, Color(1, 0.85, 0.45))


## 속성 기호(설정): 몸체의 속성 칸마다 그 속성 그림(Glyph.elem). 하나뿐이면 가운데.
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
		"flower":
			return RADIUS * (0.82 + 0.26 * absf(cos(3.0 * (a + PI / 2))))
		"prism":
			var k := PI / 3.0
			return RADIUS * 1.25 * cos(k) / cos(fposmod(a + PI / 2, 2 * k) - k)
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
				_draw_puffs(d, SHAPE.spray_len * rr(l) * s, SHAPE.spray_ang, 34, 2.4, c.lightened(0.4), c, 3.0, 10.0)
		"stream":
			if fx.get("stream", 0.0) > 0.0:
				var ls := lanes()
				var ds := dirs()
				for i in ds.size():
					_draw_wave(ds[i], FAR, SHAPE.stream_w * 0.5 * s, 0.05, c, 7.0 * s, ls[i])
		"laser":
			var f: float = fx.get("laser", 0.0)
			var ls := lanes()
			var ds := dirs()
			for i in ds.size():
				var d: Vector2 = ds[i]
				var o2: Vector2 = ls[i]
				if f > 0.0:
					var wk: float = Rules.t("laser_w") / 14.0  # 판정 폭(laser_w)에 맞춰 빛줄기 두께도 (14가 예전 기본)
					draw_line(o2 + d * RADIUS, o2 + d * 2000.0, Color(c, f / 0.3), (10.0 * f / 0.3 + 2.0) * s * wk)
					draw_line(o2 + d * RADIUS, o2 + d * 2000.0, Color(1, 1, 1, f / 0.3), 3.0 * wk)
				else:
					var ch: float = 1.0 - cd.get("p", 0.0) / (BASE_IV.laser / spd(l))
					draw_circle(d * (RADIUS + 4.0), 2.0 + 4.0 * ch, Color(c, 0.4 + 0.6 * ch))
		"sonic":
			var f: float = fx.get("sonic", 0.0)
			if f > 0.0:
				var k := 1.0 - f / 0.35
				var R := sonic_r(l)
				for d in dirs():
					for i in 3:
						var rr := R * clampf(k - i * 0.15, 0.05, 1.0)
						draw_arc(Vector2.ZERO, rr, d.angle() - SHAPE.sonic_ang, d.angle() + SHAPE.sonic_ang, 16, Color(c.lightened(0.3), (1.0 - k) * (1.0 - i * 0.25)), 3.0)
		"clock":
			var ls := lanes()
			var ds := dirs()
			for i in ds.size():
				var d: Vector2 = ds[i]
				var o2: Vector2 = ls[i]
				var hd: Vector2 = d.rotated(clock_a())
				var L: float = SHAPE.clock_len * rr(l) * s
				draw_arc(o2, L, d.angle() - SHAPE.clock_arc, d.angle() + SHAPE.clock_arc, 24, Color(c, 0.15), 2.0)
				draw_line(o2 + hd * RADIUS, o2 + hd * L, Color(c, 0.85), 4.0 * s)
				draw_line(o2 + hd * RADIUS, o2 + hd * L, Color(1, 1, 1, 0.5), 1.5)


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
func _draw_wave(d: Vector2, length: float, amp: float, freq: float, c: Color, width: float, o := Vector2.ZERO) -> void:
	if length < 2.0:
		return
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var dd := length * i / n
		var off := sin(dd * freq * TAU - t * 14.0) * amp
		pts.append(o + d * (RADIUS + dd) + d.orthogonal() * off)
	draw_polyline(pts, c, width)
	draw_polyline(pts, Color(1, 1, 1, 0.5), width * 0.35)


## -1~1 의사 난수.
static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0


# ---------- 사거리 미리보기 ----------

## 공격 범위를 ci(전역 좌표 캔버스)에 그린다. 설치·겹치기 전 미리보기와 툴팁용.
## sp: spec() 묶음 {"els", "pat", "plv", "mods"}
## focus: 바뀌는 부분(-2: 공격방식, 0 이상: 그 속성의 반응)만 진하게, 나머지는 옅게
## rings = false면 별 흡수 둘레는 빼고 공격 범위만 (정보창 기본: 주변과 주고받는 둘레는 자세히에서).
static func draw_range(ci: CanvasItem, o: Vector2, d: Vector2, sp: Dictionary, focus := -1, rings := true) -> void:
	# 방향을 고를 때 마우스가 설치 지점과 겹치면 방향이 0이 되어 다각형이 깨진다
	if not o.is_finite():
		return
	d = d.normalized() if d.is_finite() and d.length_squared() > 0.0001 else Vector2.RIGHT
	var far := 1600.0
	var els: Dictionary = sp["els"]
	var l: int = sp["plv"]
	var md: Dictionary = sp["mods"]
	var s: float = 1.0 + Rules.size_k * md.get("size", 0)
	var n: int = 1 + md.get("multi", 0)
	var pr := rr_of(sp["pat"], l)
	var c := Pat.pcolor(sp["pat"])
	if not els.is_empty():
		c = Elem.COLORS[els.keys()[0]]
	if focus >= 0:
		c.a = 0.35
	if md.get("reflex", 0) > 0 or auto_base(sp["pat"]):
		var total := 0
		for e in els:
			total += int(els[e])
		var sn := float(md.get("size", 0))
		if Rules.mod_decay:
			sn = 2.0 * (1.0 - pow(0.5, sn))
		var mn := float(md.get("multi", 0))
		if Rules.mod_decay:
			mn = 2.0 * (1.0 - pow(0.5, mn))
		var r := reflex_range_of(sp["pat"], l, total, sn, 0.0, md.get("homing", 0), mn)
		if MapRule.on() and MapRule.is_map("storm"):
			var points := PackedVector2Array()
			var wind_dir := MapRule.wind_dir(ci.get("lanes"))
			for i in 97:
				var toward := Vector2.from_angle(TAU * i / 96.0)
				var weather := MapRule.wind_k(toward, wind_dir)
				var reach := reflex_range_of(sp["pat"], l, total, sn, 0.0, md.get("homing", 0), mn, weather)
				points.append(o + toward * reach)
			ci.draw_polyline(points, Color(c, 0.3), 1.5)
		else:
			ci.draw_arc(o, r, 0.0, TAU, 96, Color(c, 0.3), 1.5)
	var ks := spread_ks(n)
	for i in n:
		var dd := d.rotated(spread_a(ks[i]))
		var lo: Vector2 = o + d.orthogonal() * spread_lane(ks[i])  # 짝수 개 가운데 두 발은 나란히
		match sp["pat"]:
			"spray":
				_r_cone(ci, o, dd, SHAPE.spray_len * pr * s, SHAPE.spray_ang, c)
			"chain":
				var fs: float = SHAPE.chain_len * pr * s
				_r_cone(ci, o, dd, fs, SHAPE.chain_ang, c)
				_r_far(ci, o, dd, fs, far, 0.0, c, SHAPE.chain_ang)
			"stream":
				var fs: float = SHAPE.stream_len * pr * s
				_r_band(ci, lo, dd, 0.0, fs, SHAPE.stream_w * s, c)
				_r_far(ci, lo, dd, fs, far, SHAPE.stream_w * s, c)
			"gust":
				var fs: float = Projectile.PROJ.gust_far * s * Rules.t("range_gust")
				_r_band(ci, lo, dd, 0.0, fs, Projectile.PROJ.gust_r * s, c)
				_r_far(ci, lo, dd, fs, far, Projectile.PROJ.gust_r * s, c)
			"laser":
				_r_band(ci, lo, dd, 0.0, far, Rules.t("laser_w") * s, c)
			"wall":
				if i == 0:
					var inner := Rect2(Vector2.ZERO, Meta.FIELD).grow(-100.0)  # main.spawn_rock처럼 전장 가장자리 안쪽
					for k in 2 + md.get("multi", 0):
						_r_circle(ci, (o + rock_slot(d, k, l)).clamp(inner.position, inner.end), 28.0 * s, c)
			"vortex":
				# 중력 우물을 떨어뜨리는 사거리 (Tower.well_range와 같은 계산, 다중 발사여도 원 하나)
				if i == 0:
					var wr := Rules.t("well_range") * pr * Rules.t("range_vortex")
					ci.draw_arc(o, wr, 0, TAU, 64, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)
			"lob":
				var fs: float = LOB_RANGE * pr
				_r_band(ci, lo, dd, 0.0, fs, lob_r(l) * s, c)
				_r_far(ci, lo, dd, fs, far, lob_r(l) * s, c)
			"iron":
				_r_band(ci, lo, dd, 0.0, far, 12.0 * s, c)
			"sonic":
				_r_cone(ci, o, dd, SHAPE.sonic_len * pr * s, SHAPE.sonic_ang, c)
			"clock":
				_r_cone(ci, o, dd, SHAPE.clock_len * pr * s, SHAPE.clock_arc, c)
			"wisp":
				var hm: int = md.get("homing", 0)
				var hf := 2.0 * (1.0 - pow(0.5, hm)) if Rules.mod_decay else float(hm)
				if i == 0:
					ci.draw_arc(o, Projectile.wisp_leash(hf, pr), 0, TAU, 64, Color(c.r, c.g, c.b, 0.5 * c.a), 1.5)
			"shot":
				var tl := 0
				for e in els:
					tl += els[e]
				var fs := shot_range(tl, md.get("size", 0))
				_r_band(ci, lo, dd, 0.0, fs, 6.0 * s, c)
				_r_far(ci, lo, dd, fs, far, 6.0 * s, c)
			_:
				_r_band(ci, lo, dd, 0.0, far, 6.0 * s, c)
	if els.has(Elem.STAR) and rings:
		# 별빛을 모으는 둘레: 이 안에 중심이 있는 오브젝트의 피해를 복사해 모은다 (채우지 않고 점선 윤곽만)
		var sc: Color = Elem.COLORS[Elem.STAR]
		if focus >= 0 and focus != Elem.STAR:
			sc.a = 0.35
		draw_star_ring(ci, o, sc)


## 별 흡수 둘레(star_r): 천천히 도는 얇은 점선 원. 장판처럼 보이지 않게 채우지 않는다.
static func draw_star_ring(ci: CanvasItem, o: Vector2, c: Color) -> void:
	var r := Rules.t("star_r")
	var n := 36
	var rot := fmod(Time.get_ticks_msec() / 1000.0 * 0.15, 1.0) * TAU / n
	for i in n:
		var a := rot + TAU * i / n
		ci.draw_arc(o, r, a, a + TAU / n * 0.55, 4, Color(c.r, c.g, c.b, 0.75 * c.a), 1.5)


static func _r_cone(ci: CanvasItem, o: Vector2, d: Vector2, rng: float, half: float, c: Color) -> void:
	var pts := PackedVector2Array([o])
	for k in 13:
		pts.append(o + d.rotated(lerpf(-half, half, k / 12.0)) * rng)
	ci.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.14 * c.a))
	pts.append(o)
	ci.draw_polyline(pts, Color(c.r, c.g, c.b, 0.6 * c.a), 1.5)


## 감소 시작 거리 너머(약해지는 구간): 옅은 띠(half_w) 또는 옅은 부채꼴(half_ang)을 화면 끝까지.
static func _r_far(ci: CanvasItem, o: Vector2, d: Vector2, from: float, to: float, half_w: float, c: Color, half_ang := 0.0) -> void:
	if from >= to:
		return
	var fc := Color(c.r, c.g, c.b, c.a * 0.35)
	if half_ang <= 0.0:
		_r_band(ci, o, d, from, to, half_w, fc)
		return
	var pts := PackedVector2Array()
	for k in 13:
		pts.append(o + d.rotated(lerpf(-half_ang, half_ang, k / 12.0)) * from)
	for k in 13:
		pts.append(o + d.rotated(lerpf(half_ang, -half_ang, k / 12.0)) * to)
	ci.draw_colored_polygon(pts, Color(fc.r, fc.g, fc.b, 0.14 * fc.a))


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
				out.append("특징: " + Elem.TRAIT[e])
				var before := roundi((1.0 - 1.0 / tax()) * 100.0)
				var after := roundi((1.0 - 1.0 / tax_of(order.size() + 1)) * 100.0)
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
				out.append("피해 x%.1f → x%.1f   공격 속도 x%.1f → x%.1f   사거리 x%.1f → x%.1f" % [pw(plv), pw(plv + 1), spd(plv), spd(plv + 1), reach(plv), reach(plv + 1)])
			else:
				sp["pat"] = id
				sp["plv"] = 1
				out.append("공격방식: %s → %s" % [Pat.pname(pattern), Pat.pname(id)])
				out.append(Pat.PATTERNS[id]["desc"])
				out.append("한 번 정하면 바꿀 수 없음 (같은 것을 넣으면 레벨업)")
		"mod":
			var id: String = card["id"]
			sp["mods"][id] = m(id) + 1
			out.append("%s %d → %d" % [Pat.MODS[id]["name"], m(id), m(id) + 1] + (" (최대 %d)" % mod_cap(id) if mod_cap(id) < Rules.NO_CAP else "") + ("  효과 x%.2f → x%.2f" % [mf(id), 2.0 * (1.0 - pow(0.5, m(id) + 1))] if Rules.mod_decay and id != "reflex" else "") )
			if Rules.mod_total < Rules.NO_CAP:
				out.append("강화 합계 %d → %d (한 오브젝트 %d개까지)" % [mod_count(), mod_count() + 1, Rules.mod_total])
			var before := mod_effect(id) if m(id) > 0 else "없음"
			mods[id] = m(id) + 1
			var after := mod_effect(id)
			mods[id] -= 1
			if mods[id] == 0:
				mods.erase(id)
			out.append(arrow_merge(before, after))
			if m(id) == 0:
				out.append(Pat.mdesc(id))
		"link":
			var id: String = card["id"]
			var n := link_lv(id)
			if n > 0:
				out.append("%s x%d → x%d" % [Pat.LINKS[id]["name"], n, n + 1])
				out.append("%s %s → %s" % [LINK_POWER[id], link_value(id, n), link_value(id, n + 1)])
			else:
				out.append(Pat.LINKS[id]["name"])
				out.append(Pat.ldesc(id))
		"trig":
			var id: String = card["id"]
			var n := tg(id)
			if n > 0:
				out.append("%s x%d → x%d" % [Pat.TRIGS[id]["name"], n, n + 1])
				out.append(arrow_merge(trig_value(id, n), trig_value(id, n + 1)))
			else:
				out.append(Pat.TRIGS[id]["name"])
				out.append(Pat.tdesc(id))
	return [out, sp]


## 넣기 전·후 글 두 개를 한 줄로: 숫자만 다르고 나머지가 같으면 바뀐 숫자 자리에만 "앞→뒤"를 넣는다.
## 예) "혼불 3개 (하나 피해 73%) · 공격방식 보정 x1.06" / "혼불 4개 (하나 피해 72%) · …" → "혼불 3→4개 (하나 피해 73→72%) · 공격방식 보정 x1.06"
## 모양이 다르면 "앞 → 뒤" 그대로.
static func arrow_merge(a: String, b: String) -> String:
	var re := RegEx.create_from_string("-?\\d+(?:\\.\\d+)?")
	var ma := re.search_all(a)
	var mb := re.search_all(b)
	if ma.size() != mb.size() or ma.is_empty() or re.sub(a, "#", true) != re.sub(b, "#", true):
		return "%s → %s" % [a, b]
	var out := ""
	var at := 0
	for i in mb.size():
		out += b.substr(at, mb[i].get_start() - at)
		var na := ma[i].get_string()
		var nb := mb[i].get_string()
		out += nb if na == nb else "%s→%s" % [na, nb]
		at = mb[i].get_end()
	return out + b.substr(at)


## 이 오브젝트에 든 연계 카드 수.
func link_lv(id: String) -> int:
	match id:
		"reso":
			return reso
		"pincer":
			return pincer
	return 0


## 연계 카드를 n장 넣었을 때의 세기 (dmg_factor·_pincer와 같은 식).
const LINK_POWER := {"reso": "가까운 오브젝트 하나당 피해", "pincer": "폭발 피해: 구체 최대 체력의"}


static func link_value(id: String, n: int) -> String:
	match id:
		"reso":
			return "+%d%%" % (12 * n)
		"pincer":
			return "%d%%" % roundi(Rules.pincer_frac * (1.0 + 0.5 * (n - 1)) * 100.0)
	return ""
