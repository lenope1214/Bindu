class_name BinduOnboarding
extends BinduFeature

var guide_topic := ""
var guide_priority := 0
var tut_queue: Array[String] = []  # 판에서 처음 생겨서 띄울 항목 (쉬는 시간·시작 화면에서 띄움)
var tut_first := false  # 이 기기에서 첫 소개가 아직 완료되지 않음
func _tut_event(_id: String) -> void:
	# 판 중 설명은 _guide가 담당한다. 상세 설명은 직접 열 때만 seen으로 기록한다.
	pass


func _tut_tick() -> void:
	if session.tut.visible or DisplayServer.get_name() == "headless":
		return
	var panels := session.settings_panel.visible or session.records_panel.visible or session.help_label.visible or session.notes_panel.visible or session.modes_panel.visible or session.codex_panel.visible or session.vote_panel.visible or session.mp_panel.visible
	if panels:
		return
	if tut_first and session.title_label.visible:
		tut_first = false
		session.tut.touch = session.touch_ui
		session.tut.phone = session._phone()
		session.tut.open_welcome()
	tut_queue.clear()


func _first_action_text() -> String:
	if TutPlay.on or Tutorial.play_done or (Meta.games > 0 and not session.tutor) or session.wave != 0 or session.mp_mode != "" or not Meta.guide_on:
		return ""
	match session.phase:
		session.Phase.CHOOSE:
			if session.perk_mode:
				return ""
			if session.cards_hidden:
				return "선택지를 다시 열어 카드를 고르세요."
			return "카드를 한 장 더 고르세요." if session.towers.get_child_count() > 0 else "카드를 하나 고르세요."
		session.Phase.PLACE:
			return "넣을 오브젝트를 고르세요." if session.picked.get("type", "elem") != "elem" else "빨간 길목 쪽 빈 곳에 놓으세요."
		session.Phase.AIM:
			return "구체가 오는 쪽으로 방향을 정하세요."
		session.Phase.READY:
			return "웨이브를 시작하세요."
		session.Phase.MOVE:
			return "옮길 곳에 놓으세요. 취소하면 돌아가요."
	return ""


func _open_guide_details() -> void:
	if guide_topic == "":
		return
	if not session.get_tree().paused and not session.title_label.visible:
		session.get_tree().paused = true
		session.tut_paused = true
	_open_tut([guide_topic])


func _update_action_guide() -> void:
	var action := _first_action_text()
	if action != "" and not session.title_label.visible and not (session.settings_panel.visible or session.records_panel.visible or session.help_label.visible or session.notes_panel.visible or session.modes_panel.visible or session.codex_panel.visible or session.vote_panel.visible or session.mp_panel.visible or session.tut.visible):
		session.guide_label.text = session.patchlog_system._kr_keep(action)
		session.guide_label.reset_size()
		guide_topic = "cards" if session.phase == session.Phase.CHOOSE else "goal" if session.phase == session.Phase.READY else "place"
		session.guide_label.visible = not session.get_tree().paused and not session.tut.visible
		# 같은 조작을 화면 위 안내와 아래 긴 조작문으로 중복 설명하지 않는다.
		session.hint.text = ""
	session.guide_more.visible = session.guide_label.visible and guide_topic != ""
	session.guide_more.position = Vector2(session.guide_label.position.x, session.guide_label.get_rect().end.y + 6.0)


func _open_tut(ids: Array, first := false) -> void:
	session.tut.touch = session.touch_ui
	session.tut.phone = session._phone()
	session.tut.open_topics(ids, first)


## 다시 보기 목록 (시작 화면 [튜토리얼]·H, 일시정지 [튜토리얼]).
func _open_tut_list() -> void:
	session.help_label.visible = false
	session.tut.touch = session.touch_ui
	session.tut.phone = session._phone()
	session.tut.open_list()


func _on_tut_closed() -> void:
	if session.tut_paused:
		session.tut_paused = false
		session.get_tree().paused = false


## [플레이하며 배우기]·목록의 [플레이 튜토리얼]: 화면을 다시 불러 연습 판으로 (ch: 장 0~3).
## 진행 중인 판은 쉬는 시간 저장이 그대로 남아 시작 화면 [이어하기]로 돌아갈 수 있다.
func _play_tutorial(ch := 0) -> void:
	if session.mp_mode != "":
		return
	session.persistence_system._save_run()
	session.get_tree().paused = false
	if TutPlay.on:
		TutPlay.leave_meta()
	TutPlay.pending = ch
	session.run_flow_system._reload()


## 다시 불러온 뒤 (_ready): 시작 화면을 닫고 연습 판의 첫 쉬는 시간을 연다.
func _start_tut_play(ch: int) -> void:
	TutPlay.pending = -1
	session.progression_system._hide_title()
	session.title_seen = false  # 연습 판을 마치면 시작 화면으로
	session.tplay = TutPlay.new()
	session.tplay.z_index = 19  # 카드·전장 위, 일시정지 어둠(20)·창 아래 (끝내기 확인은 그 위)
	session.ui_root.add_child(session.tplay)
	session.lanes.clear()
	session.wave = 0
	Ach.mp = "tut"  # _ready가 멀티 표시를 지운 뒤라 다시 (누적 수·도감 수집이 오르지 않게)
	session.tplay.setup(session, ch)
	session.run_flow_system._start_choose()


# ---------- 처음 안내 ----------

## 처음 생기는 일에 한 줄 안내. 안내마다 한 번만(Meta.guide_seen), 설정에서 끌 수 있다.
## 쉬는 시간은 웨이브 시작까지, 웨이브 중은 8초. 한 번에 하나만, 위험 경고를 일반 안내보다 우선한다.
func _guide(id: String, text: String) -> void:
	if TutPlay.on:
		return  # 연습 판은 위 안내 칸이 대신한다
	if not Meta.guide_on or Meta.guide_seen.has(id) or session.title_label.visible or _first_action_text() != "":
		return
	var priority := 3 if id == "boss" else 2 if id in ["resist", "sturdy", "jam", "leak"] else 1
	if not session.guide_lines.is_empty() and priority < guide_priority:
		return  # 판단에 필요한 경고를 일반 설명이 덮지 않는다. 보여 주지 않은 항목은 seen으로 기록하지 않는다.
	var short := {
		"stack": "같은 속성은 레벨업, 다른 속성은 효과를 더해요.",
		"boss": "다음 웨이브에 보스가 와요. 분홍 경로를 확인하세요.",
		"resist": "저항 속성 외의 공격도 준비하세요.",
		"sturdy": "굳센 구체는 이동 방해에 강해요.",
		"ley": "청록 고리 위 오브젝트는 피해가 늘어요.",
		"jam": "방해 구체가 와요. 오브젝트를 나눠 배치하세요.",
		"pat": "새 공격방식: 직선탄 오브젝트에 넣어 공격을 바꿔요.",
		"mod": "새 강화: 오브젝트에 넣어 공격을 강화해요.",
		"trig": "새 발동: 조건이 맞으면 추가 효과가 나와요.",
		"link": "새 연계: 주변 오브젝트와 함께 싸워요.",
		"skill": "웨이브 중 기술 버튼으로 전투를 도울 수 있어요.",
		"leak": "구체가 중앙에 닿았어요. 빈 길목을 보강하세요.",
		"lanes": "빨간 부채꼴이 구체가 들어오는 길목이에요.",
		"react": "조합: 한 속성의 효과가 다른 속성의 특징을 따라 퍼져요.",
	}
	var line: String = short.get(id, text.get_slice(". ", 0))
	Meta.guide_seen[id] = true
	session.progression_system._save_best()
	session.guide_lines.assign([line])
	guide_priority = priority
	guide_topic = Tutorial.ON_EVENT.get(id, "goal" if id == "lanes" else "")
	session.guide_t = 8.0 if session.phase == session.Phase.WAVE else -1.0
	session.guide_label.text = session.patchlog_system._kr_keep(_wrap_words(line, minf(570.0, session.ui_root.size.x - 40.0), 16))
	session.guide_label.reset_size()


## 쉬는 시간이 열릴 때: 길목·겹치기·보스·저항·굳센 구체 안내.
func _rest_guides() -> void:
	if session.wave == 0:
		_guide("start", "빨간 부채꼴이 구체가 들어오는 길목이에요. 그 넓이 어디로든 와요. 속성 카드를 고른 뒤 길목 쪽 빈 곳을 눌러 놓고, 한 번 더 눌러 쏠 방향을 정하세요")
	elif session.towers.get_child_count() > 0:
		_guide("stack", "속성 카드를 오브젝트 위에 놓으면 겹쳐져요. 같은 속성은 레벨업, 다른 속성은 추가 효과가 더해지고, 속성마다 특징이 다른 속성 효과까지 실어 날라요")
	if not session.boss_plan.is_empty() and session.boss_plan["wave"] == session.wave + 1:
		_guide("boss", "다음 웨이브 끝에 보스가 와요. 분홍 선이 실제로 지나갈 길이에요. 중앙에 닿으면 3 피해, 웨이브를 넘기면 특성을 하나 골라요")
	if session.wave_resist >= 0:
		_guide("resist", "저항 구체(점선 고리)가 섞여 와요. 다음 웨이브는 %s 속성 피해를 덜 받으니 다른 속성 오브젝트도 길목에 두세요" % Elem.NAMES[session.wave_resist])
	if not session.ley.is_empty():
		_guide("ley", "청록 고리는 기맥이에요. 그 위에 놓은 오브젝트는 피해 +%d%% (자리마다 가장 가까운 하나)" % roundi(Rules.t("ley_dmg") * 100))
	if session.jams_on() and session.wave + 1 >= session.jam_from("shade"):
		_guide("jam", "방해 구체가 섞여 와요. 그림자·표적은 오브젝트를 잠깐 멈추고, 흡수는 공격 속도를 빼앗아요. 오브젝트를 여러 곳에 나눠 두면 덜 막혀요")
	if session.wave + 1 >= Rules.sturdy_from:
		_guide("sturdy", "굳센 구체(회색 쐐기)가 섞여 와요. 밀기·감속·기절·냉기가 절반만 들으니 피해로 잡아야 해요")


## 선택지에 처음 나온 카드 종류 안내.
func _card_guides() -> void:
	var types := session.offer.map(func(cd): return cd["type"])
	if "pat" in types:
		_guide("pat", "새 카드 · 공격방식: 직선탄 오브젝트에 넣으면 공격 모양이 바뀌고 그 뒤로 고정돼요. 같은 공격방식을 넣으면 레벨업")
	if "mod" in types:
		var cap := "같은 강화는 %d개, 한 오브젝트에 합쳐 %d개까지 넣어요" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "쌓을수록 효과가 절반씩 줄어요"
		_guide("mod", "새 카드 · 강화: 오브젝트 위에 놓아 공격을 바꿔요(빠르게·크게·관통 등). " + cap)
	if "link" in types:
		_guide("link", "새 카드 · 연계: 오브젝트 위에 놓아 주변과 함께 싸워요. 협공은 여러 오브젝트가 같이 맞힌 구체를 터뜨려요")
	if "trig" in types:
		_guide("trig", "새 카드 · 발동: 오브젝트 위에 놓으면 조건이 맞을 때 공격이 더 나가요. 처치 폭발은 잡은 자리에서 탄이 터지고, 앞줄 강타는 체력이 많이 남은 구체를 더 세게 때려요")


## 띄어쓰기 단위로 줄을 나눈다. Godot 자동 줄바꿈은 한글을 음절마다 끊어 "형\n태"처럼 단어가 잘린다.
func _wrap_words(text: String, width: float, fs: int) -> String:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for w in para.split(" ", false):
			var cand: String = w if line == "" else line + " " + w
			if line != "" and session.ui_font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
				out.append(line)
				line = w
			else:
				line = cand
		out.append(line)
	return "\n".join(out)


## "a · b · c"처럼 구분자로 나뉜 글을 항목 단위로 줄바꿈 (항목 중간에서 끊지 않음).
func _wrap_parts(text: String, sep: String, width: float, fs: int) -> String:
	var out := PackedStringArray()
	var line := ""
	for part in text.split(sep):
		var cand: String = part if line == "" else line + sep + part
		if line != "" and session.ui_font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			out.append(line)
			line = part
		else:
			line = cand
	out.append(line)
	return "\n".join(out)


## 5웨이브마다: 특성 3개 중 1개.
## 바람 속성 오브젝트 둘레의 다른 오브젝트 공격 속도를 정한다 (가장 큰 바람 하나만).
func _wind_buffs() -> void:
	var ts := session.towers.get_children()
	var winds := []  # 2026-11-04: 바람 효과가 밀쳐냄으로 바뀌어 순풍은 없다 (패치로 되살릴 때를 위해 계산은 남김)
	for t in ts:
		var b := 0.0
		for w in winds:
			if w != t and w.position.distance_to(t.position) < w.wind_range():
				b = maxf(b, Rules.t("wind_buff") * w.lv(Elem.WIND))
		t.wind_buff = b


## 속성 카드가 Lv2로 나올 확률 (행운 특성 포함).
