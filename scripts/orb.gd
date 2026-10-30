class_name Orb
extends Node2D
## 화면 밖에서 중앙 점으로 이동하는 구체.

enum Kind { NORMAL, FAST, TANK, BOSS }

# 군중 제어 한계: 겹쳐 걸수록 효율이 떨어지고, 계속 맞아도 앞으로는 나아간다.
const SLOW_FLOOR := 0.3  # 감속은 최대 70% (보스 50%)
const PUSH_BUDGET := 40.0  # 중앙 반대쪽으로 한 번에 밀릴 수 있는 거리 (보스 15)
const PUSH_REGEN := 0.15  # 밀림 여유가 초당 이동 속도의 15%씩 회복 (보스 5%): 최대로 느려져도(30%) 조금씩은 전진
const STAGGER_MAX := 0.6  # 경직은 한 번에 이만큼(초)까지만 쌓인다
const ROOT_DR := [1.0, 0.5, 0.25]  # 연달아 기절·속박·빙결: 지속시간 100% → 50% → 25%, 그다음 면역
const ROOT_IMMUNE := 2.0
const ROOT_DR_RESET := 4.0  # 이만큼 안 걸리면 처음부터

var kind := Kind.NORMAL
var core_dmg := 1  # 중앙에 닿았을 때 깎는 체력
var shield := 0.0  # 보호막: 이만큼 피해를 먼저 흡수
var swirl := 0.0  # 나선 이동 각도(라디안)
var splits := false  # 죽으면 작은 구체 2개
var resist_e := -1  # 이 속성 피해를 덜 받는다 (부분 저항)
var sturdy := false  # 굳셈: 밀기·감속·기절·냉기 효과 절반
var minion_t := 4.0  # 보스: 부하 소환 주기
var minion := false  # 보스가 부른 부하 (모드 '성난 보스'의 처치 점수 계산)
var hp := 1.0
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
var burn_rx := false  # 특수 반응이 건 것인지 (반응 피해 측정용)
var poison_rx := false
var vuln_t := 0.0
var chill := 0.0
var frozen_t := 0.0  # 빙결 표시
var swamp_t := 0.0  # 독늪 안: 중독 2배, 죽으면 독 폭발
var swamp_lv := 1
var prison_t := 0.0  # 빙결 감옥: 받는 피해 +50%
var marks := {}  # 협공: 맞힌 오브젝트 id -> 맞은 시각(age)
var pincer_cd := 0.0
var curse_lv := 0  # 저주 표식 (죽으면 주변 피해, 표식이 옮겨 감)
var curse_owner: Object = null
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
var styx_t := 0.0  # 망자의 강 안: 죽으면 반드시 혼불
var styx_lv := 1
var styx_src: Object = null
var silence_t := 0.0  # 침묵: 저항·굳셈이 꺼지고 보스 부하 소환이 멈춘다
var push_budget := PUSH_BUDGET
var stagger_t := 0.0  # 경직(금속·철구·물줄기·레일건): 제자리에 멈춤
var root_dr := 0  # 연달아 걸린 기절 횟수
var root_dr_t := 0.0  # 마지막 기절 뒤 지난 시간
var root_immune := 0.0  # 기절 면역 남은 시간
var flash := 0.0
var main: Node
var dmg_acc := 0.0  # 피해 숫자 팝업용 누적
var pop_t := 0.0
var age := 0.0  # 등장 연출
var ti := 0  # main.targets 안 순서 (격자 조회 결과를 원래 순서로 맞출 때)
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
	return 9.0 + minf(max_hp, 12.0)


## 종류에 맞춰 체력·속도 보정.
func setup(k: int, base_hp: float, base_speed: float) -> void:
	kind = k
	match k:
		Kind.NORMAL:
			max_hp = base_hp; speed = base_speed
		Kind.FAST:
			max_hp = maxf(1.0, ceilf(base_hp * 0.6)); speed = base_speed * 1.8
		Kind.TANK:
			max_hp = ceilf(base_hp * 2.5); speed = base_speed * 0.6
		Kind.BOSS:
			max_hp = ceilf(base_hp * 12.0 * Modes.boss_hp()); speed = base_speed * 0.45; core_dmg = 3
	hp = max_hp
	if main:
		speed *= main.orb_speed_mul * Modes.speed()
	push_budget = _push_max()


## main이 웨이브 중 호출한다(배속이면 한 프레임에 여러 번).
func step(delta: float) -> void:
	age += delta
	pincer_cd = maxf(pincer_cd - delta, 0.0)
	# A6: 보스는 주기적으로 빠른 부하를 부른다
	if kind == Kind.BOSS and main and silence_t <= 0.0:
		minion_t -= delta
		if minion_t <= 0.0:
			minion_t = minion_every(main.wave)
			main.spawn_minion(self)
	slow_timer = maxf(slow_timer - delta, 0.0)
	root_timer = maxf(root_timer - delta, 0.0)
	stagger_t = maxf(stagger_t - delta, 0.0)
	vuln_t = maxf(vuln_t - delta, 0.0)
	flash = maxf(flash - delta, 0.0)
	frozen_t = maxf(frozen_t - delta, 0.0)
	swamp_t = maxf(swamp_t - delta, 0.0)
	prison_t = maxf(prison_t - delta, 0.0)
	tune_t = maxf(tune_t - delta, 0.0)
	ring_cd = maxf(ring_cd - delta, 0.0)
	soul_t = maxf(soul_t - delta, 0.0)
	styx_t = maxf(styx_t - delta, 0.0)
	silence_t = maxf(silence_t - delta, 0.0)
	echo_cd = maxf(echo_cd - delta, 0.0)
	if tune_t <= 0.0:
		ring = 0.0
	if echo_t > 0.0:
		echo_t -= delta
		if echo_t <= 0.0:
			_echo_release()
	push_budget = minf(push_budget + speed * (0.05 if kind == Kind.BOSS else PUSH_REGEN) * delta, _push_max())
	root_immune = maxf(root_immune - delta, 0.0)
	root_dr_t += delta
	if root_dr_t > ROOT_DR_RESET:
		root_dr = 0
	chill = maxf(chill - 0.4 * delta, 0.0)
	if burn_t > 0.0:
		burn_t -= delta
		hurt(burn_dps * delta)
		_credit(burn_src, burn_dps * delta, burn_rx)
	if poison_t > 0.0:
		poison_t -= delta
		var pd := poison_dps * delta * (2.0 if swamp_t > 0.0 else 1.0)
		hurt(pd)
		_credit(poison_src, pd, poison_rx)
	# 피해 숫자는 0.35초마다 묶어서 표시
	pop_t -= delta
	if pop_t <= 0.0 and dmg_acc >= 1.0 and main:
		main.popup(position, dmg_acc, Color.WHITE, false)
		dmg_acc = 0.0
		pop_t = 0.35
	var mult := slow_factor if slow_timer > 0.0 else 1.0
	if root_timer > 0.0 or stagger_t > 0.0:
		mult = 0.0
	if swirl != 0.0 and position.distance_to(target) > 60.0:
		# 소용돌이 맵: 중앙을 향하되 옆으로 비껴 나선을 그린다
		position += (target - position).normalized().rotated(swirl) * speed * mult * delta
	else:
		position = position.move_toward(target, speed * mult * delta)
	queue_redraw()


func hurt(amount: float, crit := false) -> void:
	var d := amount * (1.5 if prison_t > 0.0 else 1.3 if vuln_t > 0.0 else 1.0)
	if shield > 0.0:
		var absorbed := minf(shield, d)
		shield -= absorbed
		d -= absorbed
		if shield <= 0.0 and main:
			main.burst(position, Color(0.6, 0.9, 1.0), 8, 140.0)
			main.sfx.play("shield", 0.0)
	hp -= d
	if echo_t > 0.0:
		echo_amt += d * echo_frac
	if amount > 0.3:
		flash = 0.08
	if crit and main:
		main.popup(position, d, Color(1, 0.9, 0.3), true)
		main.sfx.play("crit")
	elif amount >= 0.5 and main:
		main.sfx.play("hit", 0.12)
	else:
		dmg_acc += d


## 메아리가 끝나면 기록해 둔 피해를 한 번에 (이 피해는 다시 기록하지 않는다).
func _echo_release() -> void:
	echo_t = 0.0
	echo_cd = 0.5
	var d := echo_amt
	echo_amt = 0.0
	if d <= 0.0 or hp <= 0.0:
		return
	hurt(d)
	_credit(echo_src, d, false)
	if main and d >= 1.0:
		main.popup(position, d, Elem.COLORS[Elem.TIME], true, "메아리")


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


## 저항 속성이 오브젝트 속성에서 차지하는 비율만큼 피해를 줄인다 (최대 60%).
func resist_mul(els: Dictionary) -> float:
	if resist_e < 0 or not els.has(resist_e) or silence_t > 0.0:
		return 1.0
	var total := 0
	for e in els:
		total += els[e]
	return 1.0 - 0.6 * float(els[resist_e]) / maxf(total, 1.0)


func slow(factor: float, duration: float) -> void:
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


func _push_max() -> float:
	return 15.0 if kind == Kind.BOSS else PUSH_BUDGET


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


## 밀기: 중앙 반대쪽으로 밀리는 만큼은 밀림 여유에서 빠진다(옆·안쪽은 그대로).
func push(v: Vector2) -> void:
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
func burn(dps: float, duration: float, src = null, rx := false) -> void:
	var cur := burn_dps if burn_t > 0.0 else 0.0
	if is_instance_valid(src) and dps >= cur:
		burn_src = src  # 가장 센 화상을 건 쪽
		burn_rx = rx
	burn_dps = maxf(cur, dps)
	burn_t = maxf(burn_t, duration)


func poison(dps: float, duration: float, src = null, rx := false) -> void:
	var cur := poison_dps if poison_t > 0.0 else 0.0
	if is_instance_valid(src) and dps >= cur:
		poison_src = src
		poison_rx = rx
	poison_dps = maxf(cur, dps)
	poison_t = maxf(poison_t, duration)


## 지속 피해를 건 오브젝트의 피해 기록에 더한다 (표시용, 오브젝트가 사라졌으면 무시).
func _credit(src, d: float, rx: bool) -> void:
	if is_instance_valid(src):
		src.dealt += d
		if rx:
			src.rx_dealt += d


func vuln(duration: float) -> void:
	vuln_t = maxf(vuln_t, duration)


## 냉기가 3 쌓이면 1초 빙결.
func add_chill(amount: float) -> void:
	if sturdy and silence_t <= 0.0:
		amount *= 0.5
	chill += amount
	slow(0.7, 0.5)
	if chill >= 3.0:
		chill = 0.0
		if root(1.0):
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
	if prison_t > 0.0:
		# 빙결 감옥: 어두운 얼음 창살
		for i in 8:
			var a := TAU * i / 8
			draw_line(Vector2(cos(a), sin(a)) * (r + 2.0), Vector2(cos(a), sin(a)) * (r + 10.0), Color(0.45, 0.5, 0.95, 0.9), 3.0)
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
	if curse_lv > 0:
		# 저주 표식: 머리 위에서 도는 보라색 눈
		var cp := Vector2(0, -r - 18.0)
		var cc := Color(0.75, 0.3, 0.9)
		draw_arc(cp, 7.0, age * 3.0, age * 3.0 + TAU * 0.75, 12, cc, 2.0)
		draw_circle(cp, 2.5, cc)
	# 상태 표시 점: 화상·중독·약화·감속
	var icons: Array = []
	if burn_t > 0.0: icons.append(Elem.COLORS[Elem.FIRE])
	if poison_t > 0.0: icons.append(Elem.COLORS[Elem.POISON])
	if vuln_t > 0.0: icons.append(Elem.COLORS[Elem.DARK])
	if slow_timer > 0.0: icons.append(Elem.COLORS[Elem.WATER])
	for i in icons.size():
		draw_circle(Vector2(-(icons.size() - 1) * 4.0 + i * 8.0, -r - 9.0), 3.0, icons[i])
	# 체력 숫자: 보스·마우스를 올린 구체·설정에서 켠 때만 (평소엔 위의 붉은 고리로 본다)
	if kind == Kind.BOSS or Meta.orb_hp_on or (main and main.tip_orb == self):
		var font := ThemeDB.fallback_font
		var txt := str(ceili(hp))
		var size := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(-size.x / 2, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.1, 0.15))
