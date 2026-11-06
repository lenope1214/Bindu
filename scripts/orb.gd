class_name Orb
extends Node2D
## 화면 밖에서 중앙 점으로 이동하는 구체.

enum Kind { NORMAL, FAST, TANK, BOSS }

# 군중 제어 한계: 겹쳐 걸수록 효율이 떨어지고, 계속 맞아도 앞으로는 나아간다.
## 구체 종류별 체력·속도 배율 (일반 구체 대비), 보스가 중앙에 주는 피해. 온라인 패치 rules "Orb.KIND.<이름>"
static var KIND := {
	"fast_hp": 0.6,  # 빠른 구체 체력 배율
	"fast_spd": 1.62,  # 빠른 구체 속도 배율
	"tank_hp": 2.5,  # 단단한 구체 체력 배율
	"tank_spd": 0.6,  # 단단한 구체 속도 배율
	"boss_hp": 12.0,  # 보스 체력 배율 (성난 보스 모드는 더 곱함)
	"boss_spd": 0.45,  # 보스 속도 배율
	"boss_core": 3,  # 보스가 중앙에 닿으면 깎는 체력
}
static var SLOW_FLOOR := 0.3  # 감속은 최대 70% (보스 50%)
static var PUSH_BUDGET := 40.0  # 중앙 반대쪽으로 한 번에 밀릴 수 있는 거리 (보스 15)
static var PUSH_REGEN := 0.15  # 밀림 여유가 초당 이동 속도의 15%씩 회복 (보스 5%): 최대로 느려져도(30%) 조금씩은 전진
static var STAGGER_MAX := 0.6  # 경직은 한 번에 이만큼(초)까지만 쌓인다
static var ROOT_DR := [1.0, 0.5, 0.25]  # 연달아 기절·속박·빙결: 지속시간 100% → 50% → 25%, 그다음 면역
static var ROOT_IMMUNE := 2.0  # 세 번 연달아 걸린 뒤 기절·속박·빙결 면역 시간(초)
static var ROOT_DR_RESET := 4.0  # 이만큼 안 걸리면 처음부터

var kind := Kind.NORMAL
var core_dmg := 1  # 중앙에 닿았을 때 깎는 체력
var shield := 0.0  # 보호막: 이만큼 피해를 먼저 흡수
var walled := false  # 성벽 특성에 한 번 밀려났음
var swirl := 0.0  # 나선 이동 각도(라디안)
var lane_k := 1.0  # 진입 시간 맞추기: 나온 방향별 이동 속도 배율 (main.lane_k)
var splits := false  # 죽으면 작은 구체 2개
var resist_e := -1  # 이 속성 피해를 덜 받는다 (부분 저항)
var sturdy := false  # 굳셈: 밀기·감속·기절·냉기 효과 절반
var minion_t := 4.0  # 보스: 부하 소환 주기
## 후반 구체 (2026-10-31): 깜빡(blink)·갑옷(armor)·치유(mender)·흐림(phase)·포식(devour). 한 구체에 하나. main._late_trait
var late := ""
var jam := ""  # 방해 구체 (20~40웨이브~, Main._jam_trait): shade 그림자 · leech 흡수 · seeker 표적
var jam_tower: Object = null  # 표적 구체가 쫓는 오브젝트
var jam_home := Vector2.ZERO  # 표적 구체가 원래 가던 곳 (쫓던 오브젝트가 없어지면 그쪽으로)
var late_t := 0.0  # 깜빡: 다음 순간이동까지 / 치유: 다음 맥동까지 / 흐림: 주기 안 시각 / 포식: 다음 삼키기 검사까지
var armor := 0.0  # 갑옷: 한 번 맞을 때 빼는 피해 (맞을수록 깨짐)
var armor_hits := 0.0
var heal_fx := 0.0  # 치유 맥동 그림 남은 시간
var eaten := 0  # 포식: 삼킨 구체 수
var digest_t := 0.0  # 포식: 소화하느라 멈춘 시간
var prey: Object = null  # 포식: 쫓는 앞 구체
var minion := false  # 보스가 부른 부하 (모드 '성난 보스'의 처치 점수 계산)
var hp := 1.0
var last_rx := false  # 마지막으로 맞은 피해가 특징이 실어 나른 몫인가 (업적 "특징으로 마무리"). hurt()가 끄고 그 피해를 준 쪽이 켠다
var born := 0.0  # 나온 때 (main.run_game, 업적 보스 순살)
var max_hp := 1.0
var speed := 50.0
var target := Vector2.ZERO
var slow_timer := 0.0
var slow_factor := 1.0
var root_timer := 0.0
var burn_dps := 0.0
var burn_t := 0.0
var poison_dps := 0.0
var poison_t := 0.0
var burn_src: Object = null  # 화상·중독을 건 오브젝트: 지속 피해도 그 오브젝트의 피해 몫에 넣는다
var poison_src: Object = null
var burn_rx := false  # 특징이 실어 나른 것인지 (그러면 타오름·전염을 다시 타지 않음, 측정용)
var poison_rx := false
var burn_key := "elem:fire"  # 피해 출처 (Tower.src 키)
var poison_key := "elem:poison"
var vuln_t := 0.0
var vuln_k := 0.3  # 지금 걸린 약화 세기 (받는 피해 +)
var vuln_src: Object = null  # 약화를 건 오브젝트 (어둠 끌어당김, Share.pull)
var vuln_sh := false  # 특징이 실어 나른 약화인지 (그러면 끌어당김을 다시 타지 않음)
var vine := 0.0  # 나무 휘감기: 감긴 덩굴 (3이면 묶임, 조금씩 풀림)
var spread_cd := 0.0  # 불 번짐 간격 (Share.spread)
var rep_cd := 0.0  # 시간 되풀이 간격
var chill := 0.0
var frozen_t := 0.0  # 빙결 표시
var marks := {}  # 협공: 맞힌 오브젝트 id -> 맞은 시각(age)
var pincer_cd := 0.0
var tune_t := 0.0  # 소리 울림: 남은 시간 동안 어느 오브젝트에 맞든 울림이 쌓인다
var tune_lv := 1
var tune_src: Object = null
var ring := 0.0  # 쌓인 울림 (3이면 음파)
var ring_cd := 0.0
var echo_t := 0.0  # 시간 메아리: 남은 시간 동안 받은 피해를 기록했다가 끝나면 한 번 더 받는다
var echo_frac := 0.0
var echo_amt := 0.0
var echo_cd := 0.0
var echo_src: Object = null
var soul_t := 0.0  # 영혼 넋: 남은 시간 안에 죽으면 확률로 혼불
var soul_lv := 0
var soul_src: Object = null
var bleed_t := 0.0  # 피 출혈: 남은 시간 동안 움직인 거리만큼 피해
var bleed_k := 0.0  # 출혈: 100px마다 피해
var bleed_src: Object = null
var bleed_key := "elem:blood"
var bleed_sep := false  # 상성 패혈: 중독된 동안은 멈춰 있어도 피해가 흐름
var bleed_pos := Vector2.ZERO  # 지난 프레임 자리 (움직인 거리)
var gore_src: Object = null  # 피 핏자국: 이 오브젝트 효과를 지나간 길에 남긴다 (Share.gore)
var gore_t := 0.0
var gore_acc := 0.0
var gore_zone: Object = null  # 지금 점을 더하는 핏자국 줄 (Zone)
var confuse_t := 0.0  # 환영 현혹: 남은 시간 동안 왔던 길을 되돌아 걷는다
var confuse_cd := 0.0
var dread := false  # 상성 악몽: 현혹된 동안 받는 피해↑ x1.5
var amp := {}  # 키 → [받는 피해 증가, 남은 시간] (중앙 기술 낙인 brand 등)
var silence_t := 0.0  # 저항·굳셈을 잠깐 끔 (초신성 3종 이상 등), 보스 부하 소환이 멈춘다
var push_budget := PUSH_BUDGET
var stagger_t := 0.0  # 경직(금속·철구·물줄기·레일건): 제자리에 멈춤
var root_dr := 0  # 연달아 걸린 기절 횟수
var root_dr_t := 0.0  # 마지막 기절 뒤 지난 시간
var root_immune := 0.0  # 기절 면역 남은 시간
var flash := 0.0
var _combat_port: BinduCombat
var _field_view_port: BinduFieldView
var _spawning_port: BinduSpawning
var main: BinduSession:
	set(value):
		main = value
		_combat_port = value.combat_system if value != null else null
		_field_view_port = value.field_view_system if value != null else null
		_spawning_port = value.spawning_system if value != null else null
var dmg_acc := 0.0  # 피해 숫자 팝업용 누적
var pop_t := 0.0
var age := 0.0  # 등장 연출
var ti := 0  # main.targets 안 순서 (격자 조회 결과를 원래 순서로 맞출 때)
var net_id := 0  # 협동 멀티플레이: 호스트가 붙인 번호
var ghost := false  # 협동 참가자 화면의 구체: 움직임·체력은 호스트가 보낸 대로
var net_pos := Vector2.ZERO
var from_a := 0.0  # 나온 방향(중앙 기준 각도): 누수 기록·표시용


## 보스 부하 소환 주기 (첫 부하는 나온 지 4초 뒤): 첫 보스는 7초, 웨이브마다 빨라져 13웨이브부터 4초.
static func minion_every(w: int) -> float:
	return clampf(9.0 - w * 0.4, 4.0, 7.0) / Modes.minion_rate()


func radius() -> float:
	match kind:
		Kind.FAST:
			return 9.0
		Kind.BOSS:
			return 30.0
	if late == "devour":
		return 16.0 + minf(eaten * 1.5, 16.0)
	return 9.0 + minf(max_hp, 12.0)


## 종류에 맞춰 체력·속도 보정.
func setup(k: int, base_hp: float, base_speed: float) -> void:
	kind = k
	match k:
		Kind.NORMAL:
			max_hp = base_hp; speed = base_speed
		Kind.FAST:
			max_hp = maxf(1.0, ceilf(base_hp * KIND.fast_hp)); speed = base_speed * KIND.fast_spd
		Kind.TANK:
			max_hp = ceilf(base_hp * KIND.tank_hp); speed = base_speed * KIND.tank_spd
		Kind.BOSS:
			max_hp = ceilf(base_hp * KIND.boss_hp * Modes.boss_hp()); speed = base_speed * KIND.boss_spd; core_dmg = int(KIND.boss_core)
	hp = max_hp
	if main:
		speed *= main.orb_speed_mul * Modes.speed()
	push_budget = _push_max()


## main이 웨이브 중 호출한다(배속이면 한 프레임에 여러 번).
func step(delta: float) -> void:
	age += delta
	if ghost:
		position = position.lerp(net_pos, minf(1.0, delta * 15.0)) if position.distance_to(net_pos) < 120.0 else net_pos
		if flash > 0.0: flash = maxf(flash - delta, 0.0)
		_redraw_if_changed()
		return
	if pincer_cd > 0.0: pincer_cd = maxf(pincer_cd - delta, 0.0)
	# A6: 보스는 주기적으로 빠른 부하를 부른다
	if kind == Kind.BOSS and main and silence_t <= 0.0:
		minion_t -= delta
		if minion_t <= 0.0:
			minion_t = minion_every(main.wave)
			_spawning_port.spawn_minion(self)
	if slow_timer > 0.0: slow_timer = maxf(slow_timer - delta, 0.0)
	if root_timer > 0.0: root_timer = maxf(root_timer - delta, 0.0)
	if stagger_t > 0.0: stagger_t = maxf(stagger_t - delta, 0.0)
	if vuln_t > 0.0: vuln_t = maxf(vuln_t - delta, 0.0)
	if flash > 0.0: flash = maxf(flash - delta, 0.0)
	if frozen_t > 0.0: frozen_t = maxf(frozen_t - delta, 0.0)
	if tune_t > 0.0: tune_t = maxf(tune_t - delta, 0.0)
	if ring_cd > 0.0: ring_cd = maxf(ring_cd - delta, 0.0)
	if soul_t > 0.0: soul_t = maxf(soul_t - delta, 0.0)
	if confuse_cd > 0.0: confuse_cd = maxf(confuse_cd - delta, 0.0)
	if gore_t > 0.0: gore_t = maxf(gore_t - delta, 0.0)
	if silence_t > 0.0: silence_t = maxf(silence_t - delta, 0.0)
	if not amp.is_empty():
		for key in amp.keys():
			amp[key][1] -= delta
			if amp[key][1] <= 0.0:
				amp.erase(key)
	if rep_cd > 0.0: rep_cd = maxf(rep_cd - delta, 0.0)
	if echo_cd > 0.0: echo_cd = maxf(echo_cd - delta, 0.0)
	if tune_t <= 0.0:
		ring = 0.0
	if echo_t > 0.0:
		echo_t -= delta
		if echo_t <= 0.0:
			_echo_release()
	push_budget = minf(push_budget + speed * (0.05 if kind == Kind.BOSS else PUSH_REGEN) * delta, _push_max())
	if root_immune > 0.0: root_immune = maxf(root_immune - delta, 0.0)
	root_dr_t += delta
	if root_dr_t > ROOT_DR_RESET:
		root_dr = 0
	chill = maxf(chill - 0.4 * delta, 0.0)
	vine = maxf(vine - 0.5 * delta, 0.0)
	if burn_t > 0.0:
		burn_t -= delta
		_credit(burn_src, hurt(burn_dps * delta, false, burn_src), burn_rx, burn_key)
		last_rx = burn_rx
		spread_cd -= delta
		if spread_cd <= 0.0 and hp > 0.0:
			spread_cd = Share.FIRE_CD
			Share.spread(self)  # 불 번짐: 타는 동안 닿은 구체에 옮겨 붙음
	if poison_t > 0.0:
		poison_t -= delta
		var pd := poison_dps * delta
		_credit(poison_src, hurt(pd, false, poison_src), poison_rx, poison_key)
		last_rx = poison_rx
	# 피해 숫자는 0.35초마다 묶어서 표시
	pop_t -= delta
	if pop_t <= 0.0 and dmg_acc >= 1.0 and main:
		_spawning_port.popup(position, dmg_acc, Color.WHITE, false)
		dmg_acc = 0.0
		pop_t = 0.35
	var mult := slow_factor if slow_timer > 0.0 else 1.0
	if root_timer > 0.0 or stagger_t > 0.0:
		mult = 0.0
	mult *= lane_k
	if late != "":
		_late_step(delta, mult)
		if digest_t > 0.0:
			mult = 0.0
	if confuse_t > 0.0:
		# 환영 현혹: 왔던 길을 되돌아 걷는다 (중앙에서 멀어지는 쪽으로, 느리게)
		confuse_t = maxf(confuse_t - delta, 0.0)
		if confuse_t <= 0.0:
			dread = false
		position += (position - target).normalized() * speed * mult * Rules.illu_spd * delta
	elif swirl != 0.0 and position.distance_to(target) > 60.0:
		# 소용돌이 맵: 중앙을 향하되 옆으로 비껴 나선을 그린다. 중앙에 가까울수록 빨라진다 (MapRule 회오리)
		mult *= MapRule.spiral_speed(position.distance_to(target))
		position += (target - position).normalized().rotated(swirl) * speed * mult * delta
	else:
		position = position.move_toward(target, speed * mult * delta)
	_blood_step(delta)
	_redraw_if_changed()


## 피: 이번 프레임 움직인 거리(밀림 포함, 순간이동처럼 튄 것은 이동 속도 3배까지만)만큼 출혈 피해, 핏자국 남기기
func _blood_step(delta: float) -> void:
	var moved := minf(position.distance_to(bleed_pos), speed * 3.0 * delta + 4.0)
	bleed_pos = position
	if bleed_t > 0.0:
		bleed_t = maxf(bleed_t - delta, 0.0)
		var m := moved
		if bleed_sep and poison_t > 0.0:
			m = maxf(m, speed * 0.5 * delta)
		if m > 0.0:
			_credit(bleed_src, hurt(bleed_k * m / 100.0, false, bleed_src), false, bleed_key)
	if gore_t > 0.0 and is_instance_valid(gore_src):
		gore_acc += moved
		if gore_acc >= Share.GORE_STEP:
			gore_acc = 0.0
			Share.gore(self)


## 구체는 위치가 바뀌어도 다시 그릴 필요가 없다(노드 위치로 옮겨진다). 모양을 바꾸는 상태가 달라졌을 때만 다시 그린다.
## 후반 구체 300개를 매 프레임 다시 그리던 것이 그리기 비용의 대부분이었다. 보스·등장 연출은 매 프레임.
var _sig := -1
var _sig_frame := -1


func _redraw_if_changed() -> void:
	var fr := Engine.get_process_frames()
	if fr == _sig_frame:
		return  # 배속이면 한 프레임에 step이 여러 번: 한 번만 본다
	_sig_frame = fr
	if kind == Kind.BOSS or age < 0.3:
		queue_redraw()
		_sig = -1
		return
	var state := 1 if frozen_t > 0.0 else 2 if root_timer > 0.0 else 3 if stagger_t > 0.0 else 4 if root_immune > 0.0 else 0
	# 체력 고리는 24칸으로 그려 48단계면 충분하다
	var sg := int(flash > 0.0) | int(poison_t > 0.0) << 1 | int(burn_t > 0.0) << 2 | int(vuln_t > 0.0) << 3 \
		| int(slow_timer > 0.0) << 4 | int(sturdy and silence_t <= 0.0) << 5 | int(silence_t > 0.0) << 7 \
		| int(bleed_t > 0.0) << 6 | state << 8 | (int(ring) + 1 if tune_t > 0.0 else 0) << 11 | roundi(clampf(hp / max_hp, 0.0, 1.0) * 48.0) << 14 \
		| int(radius()) << 22
	if kind == Kind.FAST:
		sg |= posmod(roundi((target - position).angle() / TAU * 90.0), 90) << 30
	if Meta.orb_hp_on or (main and _field_view_port.tip_orb == self):
		sg |= (ceili(hp) + 1) << 37
	# 천천히 도는 표시는 초당 16~30번만 다시 그린다 (보호막 육각·저항 점선·저주 눈·메아리 바늘. 후반엔 구체 절반이 이것들이라 매 프레임 다시 그렸다)
	var spin := 0
	if shield > 0.0: spin += roundi(age * 20.0)
	if resist_e >= 0: spin += roundi(age * 16.0) << 16
	if echo_t > 0.0: spin += (roundi(echo_t * 10.0) + 1) << 48
	if late != "":
		spin += roundi(age * 20.0) << 8
	sg ^= spin * 1000003
	if amp.has("brand"):
		sg ^= 0x5bd1e995
	if confuse_t > 0.0:
		sg ^= 0x2c1b3c6d
	if sg != _sig:
		_sig = sg
		queue_redraw()


## 받는 피해 배율(약점·감옥·증폭)까지 곱한 피해를 돌려준다. 때린 쪽은 이 값을 자기 피해로 센다 (2026-10-31: 예전엔 배율 전 값을 세서
## 어둠 "받는 피해 +30%"·씨앗 바람 등 증폭이 어느 피해 기록에도 안 잡혔다).
## hurt가 곱하는 받는 피해 배율 (가둠·약화·증폭). 보호막은 빼고.
func hurt_mul() -> float:
	var m := 1.0 + _vk() if vuln_t > 0.0 else 1.0
	for v in amp.values():
		m *= 1.0 + v[0]
	return m


## 받는 피해↑ 세기 (상성 악몽: 현혹된 동안 x1.5)
func _vk() -> float:
	return vuln_k * (Share.NIGHTMARE if dread and confuse_t > 0.0 else 1.0)


func hurt(amount: float, crit := false, source = null) -> float:
	if is_instance_valid(source):
		amount *= source.final_damage_mul()
	var d := amount * (1.0 + _vk() if vuln_t > 0.0 else 1.0)
	last_rx = false
	if not amp.is_empty():
		for v in amp.values():
			d *= 1.0 + v[0]
	var out := d
	if shield > 0.0:
		var absorbed := minf(shield, d)
		shield -= absorbed
		d -= absorbed
		if shield <= 0.0 and main:
			_spawning_port.burst(position, Color(0.6, 0.9, 1.0), 8, 140.0)
			main.sfx.play("shield", 0.0)
	hp -= d
	if echo_t > 0.0:
		echo_amt += d * echo_frac
	if amount > 0.3:
		flash = 0.08
	if crit and main:
		_spawning_port.popup(position, d, Color(1, 0.9, 0.3), true)
		main.sfx.play("crit")
	elif amount >= 0.5 and main:
		main.sfx.play("hit", 0.12)
	else:
		dmg_acc += d
	return out


## 메아리가 끝나면 기록해 둔 피해를 한 번에 (이 피해는 다시 기록하지 않는다).
func _echo_release() -> void:
	echo_t = 0.0
	echo_cd = 0.5
	var d := echo_amt
	echo_amt = 0.0
	if d <= 0.0 or hp <= 0.0:
		return
	_credit(echo_src, hurt(d, false, echo_src), false, "elem:time")
	if main and d >= 1.0:
		_spawning_port.popup(position, d, Elem.COLORS[Elem.TIME], true, "되풀이")


## 시간 메아리를 건다. 이미 기록 중이면 더 큰 비율로만 바꾼다.
func echo(frac: float, duration: float, src = null) -> void:
	if echo_t > 0.0:
		if frac > echo_frac:
			echo_frac = frac
			echo_src = src
		return
	if echo_cd > 0.0:
		return
	echo_t = duration
	echo_frac = frac
	echo_amt = 0.0
	echo_src = src


## 후반 구체 행동 (step에서). mult: 감속·기절을 반영한 이동 배율 (0이면 멈춤).
func _late_step(delta: float, mult: float) -> void:
	if heal_fx > 0.0: heal_fx = maxf(heal_fx - delta, 0.0)
	if digest_t > 0.0: digest_t = maxf(digest_t - delta, 0.0)
	match late:
		"blink":
			# 기절·경직 중엔 타이머가 멈추고, 감속하면 그만큼 느리게 찬다
			late_t -= delta * mult
			if late_t <= 0.0:
				late_t = Rules.t("late_blink_iv")
				var to := target - position
				var dist := minf(Rules.t("late_blink_dist"), to.length() - 70.0)
				if dist > 0.0:
					var dir := to.normalized().rotated(swirl) if swirl != 0.0 else to.normalized()
					if main:
						_spawning_port.burst(position, Color(0.75, 0.6, 1.0), 6, 90.0)
					position += dir * dist
		"mender":
			if silence_t > 0.0:
				return
			late_t -= delta
			if late_t <= 0.0:
				late_t = Rules.t("late_heal_iv")
				heal_fx = 0.4
				if main:
					var rr := Rules.t("late_heal_r")
					for o in _combat_port.near(position, rr):
						if o == self or o.hp <= 0.0 or o.kind == Kind.BOSS or o.position.distance_to(position) > rr + o.radius():
							continue
						var h: float = o.max_hp * Rules.t("late_heal") * (0.5 if o.burn_t > 0.0 or o.poison_t > 0.0 else 1.0)
						o.hp = minf(o.max_hp, o.hp + h)
		"phase":
			if root_timer <= 0.0 and stagger_t <= 0.0:
				late_t = fmod(late_t + delta, Rules.t("late_phase_on") + Rules.t("late_phase_off"))
			modulate.a = 0.45 if phased() else 1.0
		"devour":
			if digest_t <= 0.0 and is_instance_valid(prey) and prey.hp > 0.0 and not prey.is_queued_for_deletion():
				# 앞에 있는 가까운 구체 쪽으로 비껴 간다 (이동 속도의 절반만큼)
				position += (prey.position - position).normalized() * speed * 0.5 * mult * delta
			late_t -= delta
			if late_t > 0.0 or digest_t > 0.0 or not main:
				return
			late_t = 0.2
			var r := radius()
			prey = null
			var best := 160.0
			var my_d := position.distance_to(target)
			for o in _combat_port.near(position, 160.0):
				if o == self or o.hp <= 0.0 or o.kind == Kind.BOSS or o.late == "devour" or o.ghost:
					continue
				var d: float = o.position.distance_to(position)
				if d < best and o.position.distance_to(target) < my_d:
					best = d
					prey = o
			for o in _combat_port.near(position, r + 12.0):
				if o == self or o.hp <= 0.0 or o.kind == Kind.BOSS or o.late == "devour" or o.ghost or o.is_queued_for_deletion():
					continue
				if o.position.distance_to(position) > r + o.radius():
					continue
				var gain: float = maxf(o.hp, 0.0) * Rules.t("late_devour_take")
				max_hp += gain
				hp += gain
				eaten += 1
				core_dmg = mini(1 + eaten, int(Rules.t("late_devour_core")))
				_spawning_port.burst(o.position, Color(0.85, 0.35, 0.45), 8, 120.0)
				o.queue_free()
				if eaten % 3 == 0:
					digest_t = 0.5
					return


## 흐린 중인가 (흐림 구체: 실체 late_phase_on초 → 흐림 late_phase_off초).
func phased() -> bool:
	return late == "phase" and late_t >= Rules.late_phase_on


## 오브젝트가 직접 맞힌 피해(탄·광선 등, 반응·장판·지속 피해 제외)에 후반 구체 저항을 건다. k: 이 타격의 무게 (광선은 프레임마다 작게)
## ap: 관통 강화 개수 (탄이 아닌 공격) — 갑옷이 빼는 피해를 1개마다 Rules.pierce_armor씩 줄인다
func late_direct(d: float, k := 1.0, ap := 0.0) -> float:
	if late == "armor" and armor > 0.0:
		var w := clampf(k, 0.0, 1.0)
		var cur := armor * maxf(Rules.late_armor_floor, 1.0 - Rules.late_armor_break * armor_hits) * w * maxf(0.0, 1.0 - Rules.pierce_armor * ap)
		armor_hits += w
		d = maxf(d - cur, d * Rules.late_armor_min)
	elif phased():
		d *= Rules.late_phase_dmg
	return d


## 저항 속성이 오브젝트 속성에서 차지하는 비율만큼 피해를 줄인다 (최대 60%).
func resist_mul(els: Dictionary) -> float:
	if resist_e < 0 or not els.has(resist_e) or silence_t > 0.0:
		return 1.0
	var total := 0
	for e in els:
		total += els[e]
	return 1.0 - 0.6 * float(els[resist_e]) / maxf(total, 1.0)


func slow(factor: float, duration: float) -> void:
	factor = 1.0 - (1.0 - factor) * MapRule.cc_k()  # 회랑: 감속 +30%
	if sturdy and silence_t <= 0.0:
		factor = lerpf(factor, 1.0, 0.5)
		duration *= 0.5
	factor = maxf(factor, 0.5 if kind == Kind.BOSS else SLOW_FLOOR)
	slow_factor = minf(slow_factor, factor) if slow_timer > 0.0 else factor
	slow_timer = maxf(slow_timer, duration)


## 기절·속박·빙결. dr=false는 바위 벽처럼 몸으로 막는 경우(효율 감소 없음). 걸렸으면 true.
func root(duration: float, dr := true) -> bool:
	if sturdy and silence_t <= 0.0:
		duration *= 0.5
	if kind == Kind.BOSS:
		duration *= 0.5
	if dr:
		if root_immune > 0.0:
			return false
		duration *= ROOT_DR[root_dr]
		root_dr += 1
		root_dr_t = 0.0
		if root_dr >= ROOT_DR.size():
			root_dr = 0
			root_immune = duration + ROOT_IMMUNE
	root_timer = maxf(root_timer, duration)
	return true


static var BOSS_PUSH := 15.0  # 보스가 한 번에 밀릴 수 있는 거리


func _push_max() -> float:
	return BOSS_PUSH if kind == Kind.BOSS else PUSH_BUDGET


## 경직: 그만큼 밀려났다 다시 오는 시간만큼 제자리에 멈춘다(위치는 그대로라 사거리·장판을 벗어나지 않는다).
## 밀기와 같은 밀림 여유를 쓰므로 계속 맞아도 앞으로는 나아간다.
func stagger(dist: float) -> void:
	if sturdy:
		dist *= 0.5
	var ok := minf(dist, push_budget)
	if ok <= 0.0 or speed <= 0.0:
		return
	push_budget -= ok
	stagger_t = minf(stagger_t + ok / speed, STAGGER_MAX)


## 밀쳐내기(바람·돌풍·밀물·역류·반격 등 맞혀서 미는 것): 중앙(목표) 쪽 힘은 없애고, 바깥으로 밀리는 거리는 밀림 여유에서.
## 보스는 옆으로 밀리는 것도 여유에서 (중앙을 둘러싼 오브젝트가 건너편에서 쏘면 보스를 중앙으로 밀어 넣던 것,
## 돌풍이 보스를 옆으로 끝없이 밀던 것). 보통 구체까지 옆을 묶으면 봇 16판 중간값 20→12라 보스만.
## 맵 모양과 상관없이 구체가 가는 목표를 기준으로 (회랑도 같음).
func knock(v: Vector2) -> void:
	v *= MapRule.cc_k()  # 회랑: 밀치기 +30%
	if sturdy and silence_t <= 0.0:
		v *= 0.5
	var away := (position - target).normalized()
	var out := v.dot(away)
	if out < 0.0:
		v -= away * out
		out = 0.0
	var ok := minf(out, push_budget)
	push_budget -= ok
	v -= away * (out - ok)
	if kind == Kind.BOSS:
		# 보스: 옆으로 밀리는 것도 밀림 여유에서 (돌풍이 보스를 끝없이 옆으로 밀던 것)
		var side := v - away * ok
		var sl := side.length()
		if sl > 0.0:
			var sok := minf(sl, push_budget)
			push_budget -= sok
			v -= side * (1.0 - sok / sl)
	position += v


## 끌기(블랙홀·소용돌이 등 한곳으로 모으는 것): 중앙 반대쪽으로 끌리는 만큼만 밀림 여유에서 빠진다(옆·안쪽은 그대로).
func push(v: Vector2) -> void:
	v *= MapRule.cc_k()  # 회랑: 밀치기 +30%
	if sturdy and silence_t <= 0.0:
		v *= 0.5
	var away := (position - target).normalized()
	var out := v.dot(away)
	if out > 0.0:
		var ok := minf(out, push_budget)
		push_budget -= ok
		v -= away * (out - ok)
	position += v


## src: 건 오브젝트. 형을 두지 않는다(이미 사라진 오브젝트가 넘어와도 오류 없게).
## rx: 특수 반응 고유의 화상·중독 (반응 공격에 맞아 생긴 속성 부가효과는 아님).
## key: 피해 출처를 정해 줄 때 (비면 반응이면 건 오브젝트의 tag, 아니면 속성)
func burn(dps: float, duration: float, src = null, rx := false, key := "") -> void:
	var cur := burn_dps if burn_t > 0.0 else 0.0
	if is_instance_valid(src) and dps >= cur:
		burn_src = src  # 가장 센 화상을 건 쪽
		burn_rx = rx
		burn_key = key if key != "" else src.tag if rx and src.tag != "" else "elem:fire"
	burn_dps = maxf(cur, dps)
	burn_t = maxf(burn_t, duration)


func poison(dps: float, duration: float, src = null, rx := false, key := "") -> void:
	var cur := poison_dps if poison_t > 0.0 else 0.0
	if is_instance_valid(src) and dps >= cur:
		poison_src = src
		poison_rx = rx
		poison_key = key if key != "" else src.tag if rx and src.tag != "" else "elem:poison"
	poison_dps = maxf(cur, dps)
	poison_t = maxf(poison_t, duration)


## 지속 피해를 건 오브젝트의 피해 기록에 더한다 (표시용, 오브젝트가 사라졌으면 무시).
func _credit(src, d: float, rx: bool, key: String) -> void:
	if is_instance_valid(src):
		src.credit(d, key)
		if rx:
			src.rx_dealt += d


## 어둠 약화: 받는 피해 +amount (레벨이 높은 어둠이 걸면 큰 값으로, 2026-11-01 레벨마다 오름)
func vuln(duration: float, amount := -1.0, src: Object = null, sh := false) -> void:
	if amount < 0.0:
		amount = 0.3
	if vuln_t <= 0.0 or amount > vuln_k:
		vuln_k = amount
		if src != null:
			vuln_src = src
			vuln_sh = sh
	vuln_t = maxf(vuln_t, duration)


## 피 출혈: 100px 움직일 때마다 k 피해 (더 센 출혈이면 바꿔 건다)
func bleed(k: float, duration: float, src: Object = null, key := "elem:blood", sep := false) -> void:
	if bleed_t <= 0.0 or k >= bleed_k:
		bleed_k = k
		bleed_src = src
		bleed_key = key
		bleed_sep = sep
		if bleed_t <= 0.0:
			bleed_pos = position
	bleed_t = maxf(bleed_t, duration)


## 환영 현혹: 걸렸으면 true. 같은 구체는 illu_cd초에 한 번, 보스·굳센 구체는 절반 시간
func confuse(duration: float, nightmare := false) -> bool:
	if confuse_cd > 0.0 or confuse_t > 0.0:
		return false
	duration *= MapRule.cc_k()
	if kind == Kind.BOSS:
		duration *= 0.5
	if sturdy and silence_t <= 0.0:
		duration *= 0.5
	confuse_t = duration
	confuse_cd = Rules.illu_cd + duration
	dread = nightmare
	return true


## 냉기가 3 쌓이면 1초 빙결.
## 나무 휘감기: 덩굴이 감길수록 느려지고 3이 차면 묶임. freeze_t: 묶이는 시간 배율 (얼음 오래감)
func entangle(amount: float, freeze_t := 1.0) -> void:
	if sturdy and silence_t <= 0.0:
		amount *= 0.5
	vine += amount
	slow(maxf(1.0 - 0.08 * vine, 0.76), 0.6)
	if vine >= 3.0:
		vine = 0.0
		root(0.6 * freeze_t)


## freeze_t: 빙결 시간 배율 (얼음 오래감·제어 회복 2026-11-04, Share.dur)
func add_chill(amount: float, freeze_t := 1.0) -> void:
	if sturdy and silence_t <= 0.0:
		amount *= 0.5
	chill += amount
	slow(0.7, 0.5)
	if chill >= 3.0:
		chill = 0.0
		if root(freeze_t):
			frozen_t = root_timer


## 터질 때 파편 색: 걸려 있던 상태를 따른다.
func death_color() -> Color:
	if burn_t > 0.0: return Elem.COLORS[Elem.FIRE]
	if poison_t > 0.0: return Elem.COLORS[Elem.POISON]
	if frozen_t > 0.0: return Elem.COLORS[Elem.ICE]
	if vuln_t > 0.0: return Elem.COLORS[Elem.DARK]
	return Color(0.9, 0.9, 1.0)


func _draw() -> void:
	var r := radius()
	var appear := clampf(age / 0.3, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * appear)
	# 그림자
	draw_circle(Vector2(3, 4), r, Color(0, 0, 0, 0.35))
	var body := Color(0.85, 0.85, 0.9)
	if flash > 0.0:
		body = Color.WHITE
	if poison_t > 0.0:
		body = body.lerp(Elem.COLORS[Elem.POISON], 0.35)
	if burn_t > 0.0:
		body = body.lerp(Elem.COLORS[Elem.FIRE], 0.35)
	if vuln_t > 0.0:
		body = body.lerp(Elem.COLORS[Elem.DARK], 0.35)
	match kind:
		Kind.FAST:
			# 진행 방향을 향한 뾰족한 모양
			var d := (target - position).normalized()
			draw_colored_polygon(PackedVector2Array([d * r * 1.6, d.orthogonal() * r, -d * r * 0.6, -d.orthogonal() * r]), body)
		Kind.TANK:
			draw_rect(Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), body)
			draw_rect(Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), Color(0.4, 0.4, 0.45), false, 3.0)
		Kind.BOSS:
			draw_circle(Vector2.ZERO, r, body.darkened(0.15))
			for i in 8:
				var a := TAU * i / 8 + Time.get_ticks_msec() / 900.0
				draw_line(Vector2(cos(a), sin(a)) * r, Vector2(cos(a), sin(a)) * (r + 8), Color(1, 0.3, 0.4), 3.0)
		_:
			draw_circle(Vector2.ZERO, r, body)
	if late != "":
		_draw_late(r)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	draw_arc(Vector2.ZERO, r + 3.0, -PI / 2, -PI / 2 + TAU * frac, 24, Color(1, 0.3, 0.4), 2.0)
	if slow_timer > 0.0:
		draw_arc(Vector2.ZERO, r - 3.0, 0, TAU, 24, Elem.COLORS[Elem.WATER], 2.0)
	if shield > 0.0:
		var hex := PackedVector2Array()
		for i in 7:
			var a := TAU * i / 6 + age
			hex.append(Vector2(cos(a), sin(a)) * (r + 7.0))
		draw_polyline(hex, Color(0.6, 0.9, 1.0, 0.9), 2.5)
	if splits:
		draw_line(Vector2(0, -r * 0.8), Vector2(0, r * 0.8), Color(0.3, 0.3, 0.4), 2.0)
	if resist_e >= 0:
		# 저항: 그 속성 색 점선 고리
		var rc: Color = Elem.COLORS[resist_e]
		for i in 6:
			var a0 := TAU * i / 6 - age * 0.8
			draw_arc(Vector2.ZERO, r + 11.0, a0, a0 + 0.6, 6, rc, 3.0)
		if Meta.symbols_on and main:
			# 속성 기호(설정): 어느 속성에 강한지 글자로도
			Elem.draw_symbol(self, main.ui_font, Vector2.from_angle(-PI / 4) * (r + 17.0), resist_e, 11)
	if sturdy and silence_t <= 0.0:
		# 굳셈: 네 귀퉁이 쐐기 (네모 구체는 모서리가 r*1.41까지 나와 있어 그 바깥에)
		var base := r * 1.45 if kind == Kind.TANK else r + 1.0
		for i in 4:
			var d := Vector2.from_angle(PI / 4 + i * PI / 2)
			draw_line(d * base, d * (base + 7.0), Color(0.75, 0.75, 0.8), 4.0)
	if frozen_t > 0.0:
		# 얼음 결정
		draw_circle(Vector2.ZERO, r + 2.0, Color(0.75, 0.93, 1.0, 0.5))
		for i in 6:
			var a := TAU * i / 6
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (r + 6.0), Color(1, 1, 1, 0.8), 2.0)
	elif root_timer > 0.0:
		draw_arc(Vector2.ZERO, r + 6.0, 0, TAU, 24, Elem.COLORS[Elem.EARTH], 3.0)
	elif stagger_t > 0.0:
		# 경직: 금속색 고리
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Elem.COLORS[Elem.METAL], 2.5)
	elif root_immune > 0.0:
		# 기절 면역: 옅은 흰 고리
		draw_arc(Vector2.ZERO, r + 6.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)
	if bleed_t > 0.0:
		# 출혈: 아래로 맺힌 핏방울
		var bc: Color = Elem.COLORS[Elem.BLOOD]
		draw_circle(Vector2(0, r + 4.0), 3.0, bc)
		draw_colored_polygon(PackedVector2Array([Vector2(-2.6, r + 3.0), Vector2(0, r - 2.0), Vector2(2.6, r + 3.0)]), bc)
	if confuse_t > 0.0:
		# 현혹: 머리 위 도는 물결 두 개
		var ic: Color = Elem.COLORS[Elem.ILLUSION]
		draw_arc(Vector2(-4.0, -r - 6.0), 4.0, PI, TAU, 8, ic, 2.0)
		draw_arc(Vector2(4.0, -r - 6.0), 4.0, 0.0, PI, 8, ic, 2.0)
	if tune_t > 0.0:
		# 울림: 쌓인 만큼 분홍 호
		var rc: Color = Elem.COLORS[Elem.SOUND]
		for i in 3:
			var a0 := -PI / 2 + TAU * i / 3
			draw_arc(Vector2.ZERO, r + 4.5, a0 + 0.25, a0 + TAU / 3 - 0.25, 8, Color(rc, 0.9 if i < int(ring) else 0.3), 2.0)
	if echo_t > 0.0:
		# 메아리: 금빛 시계 바늘
		var tc: Color = Elem.COLORS[Elem.TIME]
		draw_line(Vector2.ZERO, Vector2.from_angle(-PI / 2 + echo_t * PI) * (r - 2.0), tc, 2.0)
	if silence_t > 0.0:
		draw_line(Vector2(-r, -r) * 0.7, Vector2(r, r) * 0.7, Color(0.4, 0.3, 0.5, 0.8), 2.5)
	if jam != "":
		_draw_jam(r)
	# 상태 표시 점: 화상·중독·약화·감속
	var icons: Array = []
	if burn_t > 0.0: icons.append(Elem.COLORS[Elem.FIRE])
	if poison_t > 0.0: icons.append(Elem.COLORS[Elem.POISON])
	if vuln_t > 0.0: icons.append(Elem.COLORS[Elem.DARK])
	if slow_timer > 0.0: icons.append(Elem.COLORS[Elem.WATER])
	if amp.has("brand"):
		# 중앙 기술 낙인: 붉은 과녁
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 20, Color(1.0, 0.45, 0.55, 0.9), 2.0)
		for k in 4:
			var d := Vector2.from_angle(k * PI / 2.0)
			draw_line(d * (r + 2.0), d * (r + 9.0), Color(1.0, 0.45, 0.55, 0.9), 2.0)
	for i in icons.size():
		draw_circle(Vector2(-(icons.size() - 1) * 4.0 + i * 8.0, -r - 9.0), 3.0, icons[i])
	# 체력 숫자: 보스·마우스를 올린 구체·설정에서 켠 때만 (평소엔 위의 붉은 고리로 본다)
	if kind == Kind.BOSS or Meta.orb_hp_on or (main and _field_view_port.tip_orb == self):
		var font := ThemeDB.fallback_font
		var txt := str(ceili(hp))
		var size := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(-size.x / 2, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.1, 0.15))


## 방해 구체 표시: 그림자는 닿는 거리 옅은 보라 원, 흡수는 초록 송곳니, 표적은 쫓는 오브젝트 쪽 붉은 화살촉.
func _draw_jam(r: float) -> void:
	match jam:
		"shade":
			var col := Color(0.55, 0.4, 0.8)
			draw_circle(Vector2.ZERO, Rules.t("jam_shade_r"), Color(col, 0.07))
			draw_arc(Vector2.ZERO, Rules.t("jam_shade_r"), 0, TAU, 40, Color(col, 0.3), 1.5)
			draw_circle(Vector2.ZERO, r * 0.55, Color(0.2, 0.12, 0.3, 0.9))
		"leech":
			var g := Color(0.45, 0.95, 0.5)
			for sx in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(sx * r * 0.55, -r * 0.2), Vector2(sx * r * 0.15, -r * 0.2), Vector2(sx * r * 0.35, r * 0.55)]), g)
			draw_arc(Vector2.ZERO, r + 3.0, 0, TAU, 20, Color(g, 0.7), 1.5)
		"seeker":
			var col := Color(1.0, 0.35, 0.3)
			var d := (target - position).normalized() if target.distance_to(position) > 1.0 else Vector2.RIGHT
			var tip := d * (r + 9.0)
			draw_colored_polygon(PackedVector2Array([tip, d * (r + 1.0) + d.orthogonal() * 5.0, d * (r + 1.0) - d.orthogonal() * 5.0]), col)
			draw_arc(Vector2.ZERO, r * 0.5, 0, TAU, 16, col, 2.0)


## 후반 구체 표시: 예고(깜빡 점·치유 불빛·흐림 물결·포식 입)가 행동보다 먼저 보인다.
func _draw_late(r: float) -> void:
	match late:
		"blink":
			var col := Color(0.75, 0.6, 1.0)
			for i in 8:
				var a0 := TAU * i / 8 + age
				draw_arc(Vector2.ZERO, r + 5.0, a0, a0 + 0.35, 4, col, 2.0)
			if late_t < 0.8:
				# 곧 순간이동: 깜빡이고, 도착할 자리에 흐린 점
				if fmod(age * 10.0, 1.0) < 0.5:
					draw_circle(Vector2.ZERO, r, Color(col, 0.5))
				var to := target - position
				var dist := minf(Rules.t("late_blink_dist"), to.length() - 70.0)
				if dist > 0.0:
					var dir := to.normalized().rotated(swirl) if swirl != 0.0 else to.normalized()
					draw_circle(dir * dist, r * 0.7, Color(col, 0.35))
		"armor":
			var left := clampf(1.0 - Rules.t("late_armor_break") * armor_hits, Rules.t("late_armor_floor"), 1.0)
			draw_arc(Vector2.ZERO, r + 1.0, 0, TAU, 24, Color(0.55, 0.5, 0.42), 2.0 + 5.0 * left)
			if left < 0.9:
				for i in 3:
					var d := Vector2.from_angle(1.3 + i * 2.1)
					draw_line(d * r * 0.3, d * (r + 3.0), Color(0.25, 0.22, 0.2), 1.5)
		"mender":
			var g := Color(0.4, 0.95, 0.5)
			var glow := 1.0 - clampf(late_t / 0.5, 0.0, 1.0)
			draw_rect(Rect2(-r * 0.2, -r * 0.65, r * 0.4, r * 1.3), g)
			draw_rect(Rect2(-r * 0.65, -r * 0.2, r * 1.3, r * 0.4), g)
			if glow > 0.0:
				draw_circle(Vector2.ZERO, r + 4.0, Color(g, 0.35 * glow))
			if heal_fx > 0.0:
				var f := 1.0 - heal_fx / 0.4
				draw_arc(Vector2.ZERO, lerpf(r, Rules.t("late_heal_r"), f), 0, TAU, 40, Color(g, 0.6 * (1.0 - f)), 2.5)
		"phase":
			var on := Rules.t("late_phase_on")
			var col := Color(0.6, 0.85, 1.0)
			if phased():
				draw_circle(Vector2.ZERO, r + 2.0, Color(0.05, 0.08, 0.15, 0.55))
				draw_arc(Vector2.ZERO, r + 6.0, 0, TAU, 24, Color(col, 0.5), 1.5)
			elif late_t > on - 0.5:
				# 곧 흐려짐: 물결
				var f := (late_t - (on - 0.5)) / 0.5
				draw_arc(Vector2.ZERO, r + 4.0 + f * 8.0, 0, TAU, 24, Color(col, 0.8 * (1.0 - f)), 2.0)
			else:
				draw_arc(Vector2.ZERO, r + 6.0, 0, TAU, 24, Color(col, 0.7), 1.5)
		"devour":
			# 진행 방향으로 벌어진 입 (삼킬수록 몸이 커진다)
			var col := Color(0.85, 0.3, 0.4)
			var a := (target - position).angle()
			var open := 0.45 + 0.2 * sin(age * 6.0)
			var mouth := PackedVector2Array([Vector2.ZERO])
			for k in 7:
				mouth.append(Vector2.from_angle(a - open + open * 2.0 * k / 6.0) * (r + 0.5))
			draw_colored_polygon(mouth, Color(0.25, 0.05, 0.1))
			draw_arc(Vector2.ZERO, r + 7.0, a + open + 0.2, a + TAU - open - 0.2, 24, col, 3.0)
