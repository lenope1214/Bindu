class_name BinduAbilities
extends BinduFeature
## 기맥·중앙 기술과 쿨다운. 예약 콜백은 main의 순서를 따른다.

func leys_on() -> bool:
	var session: BinduSession = self.session
	return Rules.t("ley_on") > 0.0 and session.mp_mode == "" and OS.get_environment("LEY") != "0"  # 봇 비교용: LEY=0이면 끔


## 새 판: 중앙에서 150~360, 가장자리에서 90 넘게, 서로 220 넘게 떨어진 자리. 회랑은 문에서 150 넘게.
func _ley_new_run() -> void:
	var session: BinduSession = self.session
	session.ley = []
	if not leys_on():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(session.run_id + "ley")
	var fr := session.combat_system.field_rect().grow(-90.0)
	var c := session.viewport_system.core()
	var n := int(Rules.t("ley_n"))
	for tries in 400:
		if session.ley.size() >= n:
			break
		var p := Vector2(rng.randf_range(fr.position.x, fr.end.x), rng.randf_range(fr.position.y, fr.end.y))
		if Meta.map_id == "line":
			p.y = c.y + rng.randf_range(-BinduSession.LINE_HALF + 50.0, BinduSession.LINE_HALF - 50.0)  # 회랑: 길 안에만
		var d := absf(p.x - c.x) if Meta.map_id == "line" else p.distance_to(c)
		if d < 150.0 or (Meta.map_id != "line" and d > 360.0):
			continue
		if session.ley.any(func(q): return q.distance_to(p) < 220.0):
			continue
		session.ley.append(p)


## 이 오브젝트가 기맥 위인가: 어느 자리에서 ley_r 안이고, 그 자리에 가장 가까운 오브젝트.
## 한 시뮬 단계 안에서는 맞을 때마다 다시 세지 않는다(ley_memo: sim_id → 결과).
var ley_memo := {}
var ley_memo_id := -1


func on_ley(t: Node) -> bool:
	var session: BinduSession = self.session
	if session.ley.is_empty():
		return false
	if session.phase == BinduSession.Phase.WAVE:
		if ley_memo_id != session.sim_id:
			ley_memo_id = session.sim_id
			ley_memo = {}
		var id := t.get_instance_id()
		if not ley_memo.has(id):
			ley_memo[id] = _on_ley(t)
		return ley_memo[id]
	return _on_ley(t)


func _on_ley(t: Node) -> bool:
	var session: BinduSession = self.session
	var r := Rules.t("ley_r")
	for p in session.ley:
		if t.position.distance_to(p) >= r:
			continue
		var mine := true
		for o in session.towers.get_children():
			if o != t and o.position.distance_to(p) < t.position.distance_to(p):
				mine = false
				break
		if mine:
			return true
	return false


func _draw_ley() -> void:
	var session: BinduSession = self.session
	var now := Time.get_ticks_msec() / 1000.0
	var r := Rules.t("ley_r")
	for p in session.ley:
		var used := false
		for t in session.towers.get_children():
			if t.position.distance_to(p) < r:
				used = true
				break
		var a := 0.5 + 0.2 * sin(now * 2.0 + p.x * 0.01)
		session.draw_circle(p, r, Color(BinduSession.BUILD_COLOR, 0.08 if not used else 0.16))
		for k in 6:
			var a0 := TAU * k / 6.0 + now * 0.4
			session.draw_arc(p, r, a0, a0 + 0.6, 6, Color(BinduSession.BUILD_COLOR, a if not used else 0.9), 2.0)
		session.draw_circle(p, 3.0, Color(BinduSession.BUILD_COLOR, a))


# ---------- 중앙 기술 (Skill) ----------

var auto_skills := false  # 봇·점검: 설정과 상관없이 자동 사용
var skill_auto_btn: Button

## 전투 조작부 전체. 정보창·배지는 수동/자동 전환도 기술 버튼과 함께 피한다.
func skill_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for button: Button in session.skill_btns:
		controls.append(button)
	if is_instance_valid(skill_auto_btn):
		controls.append(skill_auto_btn)
	return controls
var _automatic_cast := false


## 이번 판에 중앙 기술을 쓰는가 (멀티플레이·온라인 패치 skill_on 0이면 없음).
func skills_on() -> bool:
	var session: BinduSession = self.session
	return Rules.t("skill_on") > 0.0 and session.mp_mode == "" and OS.get_environment("SKILL") != "0"  # 봇 비교용: SKILL=0이면 끔


func _skills_new_run(set_i: int) -> void:
	var session: BinduSession = self.session
	session.skill_set = clampi(set_i, 0, Skill.SETS.size() - 1)
	session.skill_ids = Skill.set_ids(session.skill_set).duplicate() if skills_on() else []
	session.skill_cd = {}
	session.skill_arm = ""
	session.skill_used = 0


func skill_left(id: String) -> float:
	var session: BinduSession = self.session
	return session.skill_cd.get(id, 0.0)


func _skill_tick(delta: float) -> void:
	var session: BinduSession = self.session
	if session.skill_ids.is_empty() or session.mp_ghost:
		return
	for id in session.skill_cd.keys():
		session.skill_cd[id] = maxf(session.skill_cd[id] - delta, 0.0)
	if Meta.skill_auto or auto_skills:
		for id in session.skill_ids:
			if skill_left(id) <= 0.0 and id != session.skill_arm:
				var p: Variant = Skill.auto_target(session, id)
				if p != null:
					_automatic_cast = true
					_use_skill(id, p)
					_automatic_cast = false


## 기술 버튼(1·2 키): 쓸 곳을 누르기를 기다린다. 다시 누르면 취소.
func _arm_skill(i: int) -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.WAVE or i < 0 or i >= session.skill_ids.size():
		return
	var id: String = session.skill_ids[i]
	if skill_left(id) > 0.0:
		session.hud_system._show_toast("%s: %s" % [Skill.NAMES[id], skill_cooldown_text(id)])
		return
	session.skill_arm = "" if session.skill_arm == id else id
	if session.skill_arm != "":
		# 이름(집중·붙잡기·낙인)만으로는 무엇을 하는지 몰라 설명을 같이 (2026-11-03)
		session.hud_system._show_toast(("%s (%s): 쓸 곳을 누르세요" if session.touch_ui else "%s (%s): 쓸 곳을 클릭 (우클릭·Esc 취소)") % [Skill.NAMES[id], Skill.short(id)])


## p에 기술을 쓴다. 적용할 대상이 없으면 쓰지 않는다 (누른 기술이면 이유를 알림).
func _use_skill(id: String, p: Vector2) -> bool:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.WAVE or skill_left(id) > 0.0 or not id in session.skill_ids:
		return false
	if not Skill.use(session, id, p):
		if session.skill_arm == id:
			if id == "hold" and not Skill.hold_targets(session, p).is_empty():
				session.hud_system._show_toast("붙잡기: 구체가 기절·속박 면역 중이에요")
			else:
				session.hud_system._show_toast("집중: 오브젝트 위를 누르세요" if id == "focus" else "%s: 둘레에 구체가 없어요" % Skill.NAMES[id])
		return false
	session.skill_cd[id] = Skill.cd_full(id, session.perks.get("quick", 0))
	session.skill_used += 1
	if session.skill_arm == id:
		session.skill_arm = ""
	session.sfx.play("place")
	if _automatic_cast and not auto_skills:
		session.hud_system._show_toast("%s 자동 사용 · %s" % [Skill.NAMES[id], Skill.short(id)])
	return true


## 수동 조준만 감속한다. 멀티·미리보기·봇의 전투 규칙은 바꾸지 않는다.
func skill_speed_factor() -> float:
	return 0.25 if Meta.skill_aim_slow and session.mp_mode == "" and session.phase == BinduSession.Phase.WAVE and session.skill_arm != "" and not auto_skills else 1.0


func skill_mode_text() -> String:
	return "기술: 자동" if Meta.skill_auto else "기술: 수동"


func toggle_skill_auto() -> void:
	Meta.skill_auto = not Meta.skill_auto
	session.progression_system._save_best()
	_skill_ui()
	session.hud_system._show_toast(skill_mode_text() + (" · 조건에 맞으면 바로 사용해요" if Meta.skill_auto else " · 기술을 고른 뒤 쓸 곳을 누르세요"))


func skill_cooldown_text(id: String) -> String:
	var left := skill_left(id)
	if left <= 0.0:
		return "준비됨 · 웨이브마다 재충전"
	if session.get_tree().paused:
		return "정지 중 · 게임 시간 %.1f초 남음" % left
	var speed := maxf(0.01, session.game_speed * skill_speed_factor())
	return "실제 약 %.1f초 · 게임 시간 %.1f초" % [left / speed, left]


## 기술 버튼: 웨이브 중에만, 다시 쓰기까지 남은 초를 글로.
func _skill_ui() -> void:
	var session: BinduSession = self.session
	var show := session.phase == session.Phase.WAVE and not session.skill_ids.is_empty() and not session.title_label.visible
	if is_instance_valid(skill_auto_btn):
		skill_auto_btn.visible = show
		if skill_auto_btn.text != skill_mode_text():
			skill_auto_btn.text = skill_mode_text()
		skill_auto_btn.set_pressed_no_signal(Meta.skill_auto)
	for i in session.skill_btns.size():
		var b: Button = session.skill_btns[i]
		b.visible = show and i < session.skill_ids.size()
		if not b.visible:
			continue
		var id: String = session.skill_ids[i]
		var left := skill_left(id)
		var effect: String = {"focus": "공격 속도↑", "hold": "구체 멈춤", "brand": "받는 피해↑"}[id]
		var readiness := "준비" if left <= 0.0 else "실제 약 %.1f초" % (left / maxf(0.01, session.game_speed * skill_speed_factor()))
		var txt: String = "%s · %s\n%s" % [Skill.NAMES[id], effect, readiness]
		if b.text != txt:
			b.text = txt
		var col: Color = Skill.COLORS[id]
		b.modulate = Color(1, 1, 1, 1) if left <= 0.0 else Color(1, 1, 1, 0.55)
		var fc: Color = col if left <= 0.0 else Color(1, 1, 1, 0.8)
		if b.get_theme_color("font_color") != fc:  # 같은 값으로 덮어써도 테마가 바뀐 것으로 쳐 매 프레임 다시 그렸다
			b.add_theme_color_override("font_color", fc)
		b.tooltip_text = "%s (%d): %s\n%s\n웨이브마다 재충전 · 현재 x%.2f · %s" % [Skill.NAMES[id], i + 1, Skill.desc(id), skill_cooldown_text(id), session.game_speed * skill_speed_factor(), skill_mode_text()]
		var armed := session.skill_arm == id
		if not b.has_meta("armed") or b.get_meta("armed") != armed:
			b.set_meta("armed", armed)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col, 0.35) if armed else Color(0.06, 0.07, 0.1, 0.85)
			sb.border_color = col
			sb.set_border_width_all(3 if armed else 2)
			sb.set_corner_radius_all(10)
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, sb)


func _make_skill_btns(root: Control) -> void:
	var session: BinduSession = self.session
	skill_auto_btn = Button.new()
	skill_auto_btn.name = "SkillAutoMode"
	skill_auto_btn.toggle_mode = true
	skill_auto_btn.text = skill_mode_text()
	skill_auto_btn.tooltip_text = "자동은 조건에 맞을 때 기술을 사용해요. 누르면 수동·자동 전환"
	skill_auto_btn.custom_minimum_size = Vector2(120, 36)
	skill_auto_btn.focus_mode = Control.FOCUS_ALL
	skill_auto_btn.hide()
	skill_auto_btn.pressed.connect(toggle_skill_auto)
	root.add_child(skill_auto_btn)
	for i in 2:
		var b := Button.new()
		b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		b.position = Vector2(-176 + i * 186, -104)
		b.size = Vector2(166, 50)
		b.add_theme_font_size_override("font_size", Meta.fs(20))
		b.focus_mode = Control.FOCUS_NONE
		b.visible = false
		b.pressed.connect(_arm_skill.bind(i))
		root.add_child(b)
		session.cards_system._keycap(b, str(i + 1))
		session.skill_btns.append(b)


## 기술 효과·고른 기술의 범위 (fx_layer, 전장 좌표).
func _draw_skill_fx() -> void:
	var session: BinduSession = self.session
	for q in session.skill_fx:
		var k: float = 1.0 - q[2] / 0.5
		session.fx_layer.draw_arc(q[0], q[1] * (0.6 + 0.4 * k), 0, TAU, 48, Color(q[3], 0.9 * (1.0 - k)), 4.0)
	if session.skill_arm != "" and session.phase == BinduSession.Phase.WAVE:
		var mp := session.interaction_system._pointer_world()
		var col: Color = Skill.COLORS[session.skill_arm]
		if session.skill_arm == "focus":
			var t := Skill.focus_tower(session, mp)
			if t:
				session.fx_layer.draw_arc(t.position, Tower.RADIUS + 12.0, 0, TAU, 28, col, 3.0)
			session.fx_layer.draw_arc(mp, Skill.PICK_R, 0, TAU, 32, Color(col, 0.35), 1.5)
		else:
			var r := Skill.radius(session.skill_arm)
			session.fx_layer.draw_circle(mp, r, Color(col, 0.12))
			session.fx_layer.draw_arc(mp, r, 0, TAU, 48, Color(col, 0.8), 2.0)
