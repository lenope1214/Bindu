class_name BinduWaves
extends BinduFeature
## 진입 방향과 웨이브 미리보기. 예약 콜백은 main의 순서를 따른다.

var new_angles: Array = []  # 다음 웨이브에서 처음 열리는 방향. 선택 단계부터 표시한다.

func _roll_lanes() -> void:
	var previous: Array = session.lanes.duplicate()
	_choose_lanes()
	mark_new_angles(previous)

func mark_new_angles(previous: Array) -> void:
	new_angles = [] if previous.is_empty() else session.lanes.filter(func(a): return not previous.any(func(b): return absf(angle_difference(a, b)) < 0.001))

func lane_is_new(index: int) -> bool:
	return index >= 0 and index < session.lanes.size() and new_angles.any(func(a): return absf(angle_difference(a, session.lanes[index])) < 0.001)

func _choose_lanes() -> void:
	var session: BinduSession = self.session
	if TutPlay.on:
		session.lanes.assign(TutPlay.lanes_for(session.wave + 1))  # 연습 판: 정해진 길목
		return
	var n := session.lanes_for(session.wave + 1)
	if Meta.map_id == "line":
		# 회랑: 한쪽 끝 하나 (각도는 중앙 점에서 구체가 오는 쪽)
		session.lanes = [PI if Meta.line_flip else 0.0]
		return
	if Meta.map_id == "cross":
		# 십자로: 처음부터 네 방향 고정
		if session.lanes.size() != 4:
			var r0 := session.multiplayer_system.wf() * TAU
			session.lanes = [r0, r0 + PI / 2, r0 + PI, r0 + PI * 1.5]
		return
	if Meta.map_id == "storm":
		# 폭풍: 매번 전부 새로
		session.lanes.clear()
	if not session.lanes.is_empty() and session.multiplayer_system.wf() < 0.25:
		session.lanes.remove_at(session.multiplayer_system.wi() % session.lanes.size())
	while session.lanes.size() < n:
		session.lanes.append(_free_lane())


## 다른 방향과 0.8 이상 떨어진 새 방향. 자리가 모자라면 가장 넓은 틈의 가운데에 둔다
## (6곳이 될 때 기존 방향이 고르게 퍼져 있으면 빈자리가 없어 게임이 멈추던 것).
func _free_lane() -> float:
	var session: BinduSession = self.session
	for i in 40:
		var a := session.multiplayer_system.wf() * TAU
		if session.lanes.all(func(b): return absf(angle_difference(a, b)) >= 0.8):
			return a
	var ls: Array = session.lanes.map(func(b): return fposmod(b, TAU))
	ls.sort()
	var best := 0
	var gap := 0.0
	for i in ls.size():
		var g := fposmod(ls[(i + 1) % ls.size()] - ls[i], TAU)
		if g <= 0.0:
			g = TAU  # 방향이 하나뿐일 때
		if g > gap:
			gap = g
			best = i
	return fposmod(ls[best] + gap / 2.0, TAU)


## 설치된 오브젝트에 겹쳤을 때 생기는 특수 반응 안내 문구들.
## 속성 카드: 넣으면 생길 반응의 짝 속성·반응 이름, 레벨업 가능한 곳 수.
func _combo_parts(e: int) -> Dictionary:
	var session: BinduSession = self.session
	var els: Array = []
	var names := PackedStringArray()
	var ups := 0
	var card := {"type": "elem", "e": e}
	for t in session.towers.get_children():
		if not t.can_take(card):  # 속성 종류 상한으로 못 넣는 오브젝트는 셈에서 뺀다
			continue
		for r in Elem.new_reactions(t.elements, e):
			var o: int = r["b"] if r["a"] == e else r["a"]
			if not els.has(o):
				els.append(o)
			if not names.has(r["name"]):
				names.append(r["name"])
		if t.elements.has(e):
			ups += 1
	return {"els": els, "names": names, "ups": ups}


func _els_name(t: Tower) -> String:
	var parts := PackedStringArray()
	for e in t.order:
		parts.append(Elem.NAMES[e])
	return "·".join(parts)


## 다음 웨이브 안내: 진입 화살표 배지(구체 수·섞여 나오는 종류)와, 배지에 올리면 뜨는 자세한 글.
func _update_preview() -> void:
	var session: BinduSession = self.session
	var nw := session.wave + 1
	var info_l: Array = []
	var kinds: Array = []
	var W := Color(1, 1, 1, 0.9)
	var lk := session.combat_system._leak_text()
	if lk != "":
		info_l.append([lk, Color(1, 0.6, 0.6)])
	info_l.append(["다음 웨이브 %d: 구체 %d개, 진입 방향 %d곳" % [nw, session.spawn_count(nw), session.lanes.size()], W])
	if session.mp_next_extra > 0:
		info_l.append(["상대가 보낸 구체 +%d개 (이번 웨이브 구체와 같은 세기, 아무 방향)" % session.mp_next_extra, Color(1, 0.55, 0.45)])
	var firsts := {4: "빠른 구체", 7: "단단한 구체", 8: "보호막 두른 구체(먼저 보호막을 깎아야 함)", 12: "분열 구체(터지면 둘로 나뉨)", 11: "이제부터 구체 체력이 웨이브마다 %d%%씩 곱으로 늘어남" % roundi((Rules.hp_growth - 1.0) * 100)}
	for f in [[Rules.resist_from, "저항 구체(같은 색 점선 고리: 그 속성 피해를 덜 받음. 오브젝트에서 그 속성이 차지하는 만큼, 최대 60%)"], [Rules.sturdy_from, "굳센 구체(회색 쐐기: 밀기·감속·기절·냉기 절반)"]]:
		firsts[f[0]] = (firsts[f[0]] + ", " if firsts.has(f[0]) else "") + f[1]
	var body := Color(0.85, 0.85, 0.9)
	var mix := PackedStringArray()
	for m in [[4, "fast", "빠른 구체(뾰족)"], [7, "tank", "단단한 구체(네모)"], [8, "shield", "보호막"], [12, "split", "분열"]]:
		if nw >= m[0]:
			mix.append(m[2])
			kinds.append([m[1], body, nw == m[0]])
	for id in BinduSession.LATE_IDS:
		var lf := session.late_from(id)
		if nw >= lf:
			mix.append(BinduSession.LATE_NAMES[id] + (" %d%%" % roundi(session.late_share(id, nw) * 100) if id != "devour" else " %d" % int(Rules.t("late_devour_n"))))
			kinds.append([id, body, nw == lf])
			if nw == lf:
				firsts[lf] = (firsts[lf] + ", " if firsts.has(lf) else "") + BinduSession.LATE_DESC[id]
	for id in BinduSession.JAM_IDS:
		var jf := session.jam_from(id)
		if nw >= jf and session.spawning_system.jams_on():
			mix.append(BinduSession.JAM_NAMES[id] + " %d%%" % roundi(session.jam_share(id, nw) * 100))
			kinds.append([id, body, nw == jf])
			if nw == jf:
				firsts[jf] = (firsts[jf] + ", " if firsts.has(jf) else "") + BinduSession.JAM_DESC[id]
	if not mix.is_empty():
		info_l.append(["섞여 나옴: " + ", ".join(mix), W])
	var sp := PackedStringArray()
	if session.wave_resist >= 0:
		sp.append("%s 저항 구체 %d%%" % [Elem.NAMES[session.wave_resist], roundi(session.resist_share(nw) * 100)])
		kinds.append(["resist", Elem.COLORS[session.wave_resist], nw == Rules.resist_from])
	if session.sturdy_share(nw) > 0.0:
		sp.append("굳센 구체 %d%%" % roundi(session.sturdy_share(nw) * 100))
		kinds.append(["sturdy", Color(0.75, 0.75, 0.8), nw == Rules.sturdy_from])
	if nw > 10:
		sp.append("구체 체력 x%.1f" % session.hp_growth(nw))
	if not sp.is_empty():
		info_l.append(["특수 구체: " + " · ".join(sp), W])
	if firsts.has(nw):
		info_l.append(["처음 등장: " + firsts[nw], Color(1, 0.75, 0.75)])
	if nw % 5 == 0:
		info_l.insert(0, ["⚠ 보스 웨이브 · 놓치면 중앙 체력 -%d" % int(Orb.KIND.boss_core), Color(1, 0.35, 0.4)])
		for l in session.field_overlay_system._boss_text().split("\n"):
			info_l.append([l, Color(1, 0.75, 0.85)])
	else:
		var bw := ceili(nw / 5.0) * 5
		info_l.append(["다음 보스: 웨이브 %d (%d웨이브 뒤)" % [bw, bw - session.wave], Color(1, 0.75, 0.85)])
	if MapRule.is_map("spiral") and session.wave > 0 and session.wave % 5 == 0:
		info_l.append(["회오리: 이번 웨이브부터 회전 방향이 바뀜", BinduSession.MAP_AFF_COLOR])
	if MapRule.is_map("storm"):
		info_l.append(["뇌우: 바람 방향은 화면의 흰 화살표 (순풍 탄 +%d%%, 역풍 -%d%%)" % [roundi(Rules.t("map_wind_with") * 100), roundi(Rules.t("map_wind_against") * 100)], BinduSession.MAP_AFF_COLOR])
	if Vary.on or Vary.count() > 0:
		var vc := Color(0.75, 0.85, 1.0)
		if not Vary.event.is_empty():
			info_l.append(["이벤트 %s: %s" % [Vary.ename(Vary.event), Vary.edesc(Vary.event)], vc])
		if not Vary.next_event.is_empty():
			info_l.append(["웨이브 %d 뒤 이벤트 %s: %s" % [nw, Vary.ename(Vary.next_event), Vary.edesc(Vary.next_event)], vc])
		if Vary.count() > 0:
			info_l.append(["봉인: " + Vary.sealed_text(), vc])
		var ad := Vary.adapt_text()
		if ad != "":
			info_l.append(["적응 구체 (많이 쓴 것에 저항): " + ad, vc])
	session.wave_info = info_l
	session.wave_kinds = kinds
	if session.wave == 0:
		session.onboarding_system._guide("lanes", "구체는 빨간 부채꼴 넓이 어디로든 와요. 옆 숫자는 그쪽에서 오는 구체 수(%s 자세히). 부채꼴을 가로지르게, 좁은 중앙 쪽에 설치하면 다 막혀요" % ("누르면" if session.touch_ui else "올리면"))


## 다음 웨이브 구체를 진입 방향별로 고르게 나눈 수 (보스 제외). 화살표 배지와 실제 웨이브(lane_bag)가 같은 값을 쓴다.
func lane_counts(w: int) -> Array[int]:
	var session: BinduSession = self.session
	var out: Array[int] = []
	var nl := session.lanes.size()
	if nl == 0:
		return out
	var n := session.spawn_count(w) - (1 if w % 5 == 0 else 0)
	for i in nl:
		out.append(n / nl + (1 if i < n % nl else 0))
	return out
