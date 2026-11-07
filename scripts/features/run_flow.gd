class_name BinduRunFlow
extends BinduFeature
## 판 진행·일시정지·넘기기 전환. 예약 콜백은 main의 순서를 따른다.

var over_data := {}
func _apply_rules() -> void:
	var session: BinduSession = self.session
	Patch.commit()  # 받아 둔 온라인 패치는 새 판을 시작할 때 적용
	Rules.apply(Meta.rules)
	Modes.apply_rules()
	Vary.new_run(false)  # 판마다 다른 흐름: 일반 새 판에서만 켠다 (_on_rest_start), 이어하기는 저장에서
	Tower.tax_step = Rules.tax_step
	Tower.harmony_cap = session.perks_system._perk_val("harmony_cap")
	if session.legend:
		session.menu_system._refresh_legend()
	if session.ver_label:
		session.ver_label.text = _ver_text()
	if session.help_label:
		session.help_label.text = session.patchlog_system._kr_keep(_help_text())
		session.help_touch = session.touch_ui


## 도움말: 상한·장수는 고른 규칙 버전에 따라 다르다.
func _help_text() -> String:
	var session: BinduSession = self.session
	var elems := "속성 %d종까지, 레벨은 제한 없음" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "종류 제한 없음"
	var mods := "강화는 종류마다 %d개, 한 오브젝트에 합쳐 %d개까지" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "강화는 제한 없이 쌓이지만 쌓을수록 효과가 절반씩"
	var keys := [
		"[조작]",
		"1 / 2 / 3 또는 클릭: 카드 선택     Q: 선택지 새로고침     V: 선택지 내리고 필드 보기",
		"S: 웨이브 넘기기 — 카드 선택을 미루고 웨이브 n개(1·3·5·10)를 연달아 진행, 멈추면 쌓인 특성·카드·새로고침을 한꺼번에 (넘기는 중 S: 멈추기)",
		"속성 카드: 빈 곳에 설치(직선탄) → 클릭(또는 끌어서 놓기)으로 방향, Shift: 15도",
		"속성 카드를 오브젝트 위에: 속성 겹치기 (%s)" % elems,
		"공격방식·강화·연계 카드: 오브젝트 위에 놓기 (효과가 없는 강화는 못 넣음: 관통 연사·돌풍·철구에 관통·튕김, 벽에 유도, 벽·투척 장판에 분열)",
		"오브젝트 끌기: 방향은 그대로 두고 옮기기 (카드를 고른 뒤에는 꾹 눌러서)",
		"빈 곳 끌기 / Shift·Ctrl+클릭 / Ctrl+A(모두): 여러 개 선택 → 그중 하나를 끌면 함께 이동",
		"오브젝트 클릭: 선택 · 쉬는 시간에 선택한 오브젝트를 한 번 더 클릭하거나 상세의 [방향 변경]: 방향 바꾸기 · 선택한 오브젝트 위에서 휠: 15도씩 돌리기(Shift: 5도) · 우클릭한 채 끌기: 바로 조준",
		"Alt 누르고 있기: 모든 오브젝트의 공격 범위·피해 비율 보기     우클릭 / Esc: 한 단계 되돌리기, 선택 해제",
		"왼쪽 위 DPS 표: 웨이브 중엔 최근 5초 실시간 DPS, 쉬는 시간엔 지난 웨이브 DPS와 비율. 줄에 마우스를 올리면 그 오브젝트를 짚어 줌   D: 표 접기·펴기 (저장됨)",
		"Space: 웨이브 시작(자동 시작 끔일 때) / 웨이브 중 빠르게 켜기·끄기 (배율은 오른쪽 아래에서 x2~x8)",
		"F / V: 카드 패널 보기·접기   P / Esc: 일시정지(시작 화면으로·끄기)   M: 소리   O: 설정   H: 도움말   K: 도감(시작 화면)   F11: 전체 화면",
		"R: 처음부터 (일시정지 중 두 번) · 게임 오버 뒤 클릭·R·Esc: 시작 화면 (멀티 판은 대기방)",
		"E: 판 끝내기 (일시정지 중 두 번) — 지금 점수로 게임 오버, 기록·온라인 순위에 올라감",
		"쉬는 시간마다 자동 저장: 게임을 꺼도 시작 화면의 이어하기(Enter)로 그 쉬는 시간부터 (새로 시작은 N 두 번)",
		"첫 판은 카드가 단계별로 열려요 (공격방식 3·강화 4·연계 6웨이브)",
		"처음 생기는 일엔 위쪽에 한 줄 안내 (설정에서 끄기·처음부터 다시 보기)",
		"튜토리얼: 시작 화면 [튜토리얼]·일시정지에서 항목별로 다시 보기",
		"도감(시작 화면)에서 ☆로 선호 표시: 그 카드·조합이 선택지에 나오면 반짝여요",
	]
	# 폰·태블릿: 키보드·마우스 안내 대신 버튼·누르기로
	var touch := [
		"[조작 · 터치]",
		"카드 누르기: 카드 선택   [새로고침]: 선택지 바꾸기   [필드 보기]: 카드를 내리고 필드 보기",
		"화면 아래 [전장 넓게] / [패널 보기]: 카드·설명 패널 접기·복구",
		"[웨이브 n개 넘기기]: 카드 선택을 미루고 웨이브 n개(1·3·5·10)를 연달아 진행, 멈추면 쌓인 특성·카드·새로고침을 한꺼번에 (넘기는 중 아래 표시를 누르면 멈춤)",
		"속성 카드: 빈 곳을 눌러 설치(직선탄) → 쏠 쪽을 누르거나 끌어서 놓아 방향",
		"속성 카드를 오브젝트 위에: 속성 겹치기 (%s)" % elems,
		"공격방식·강화·연계 카드: 오브젝트를 눌러 넣기 (효과가 없는 강화는 못 넣음: 관통 연사·돌풍·철구에 관통·튕김, 벽에 유도, 벽·투척 장판에 분열)",
		"오브젝트 누르기: 선택 · 쉬는 시간에 선택한 오브젝트를 한 번 더 누르기: 쏠 방향 바꾸기   누른 채 끌기: 옮기기 (방향은 그대로)",
		"[취소]: 한 단계 되돌리기   [범위 보기]: 모든 오브젝트의 공격 범위·피해 비율",
		"왼쪽 위 DPS 표: 웨이브 중엔 최근 5초 실시간 DPS, 쉬는 시간엔 지난 웨이브 DPS와 비율. 제목을 누르면 접기·펴기 (저장됨)",
		"오른쪽 아래 [◀ 설정]: 소리·자동 시작·일시정지(시작 화면으로·판 끝내기·처음부터)·배속(x2~x8)",
		"쉬는 시간마다 자동 저장: 게임을 꺼도 시작 화면의 [이어하기]로 그 쉬는 시간부터",
		"첫 판은 카드가 단계별로 열려요 (공격방식 3·강화 4·연계 6웨이브)",
		"처음 생기는 일엔 위쪽에 한 줄 안내 (설정에서 끄기·처음부터 다시 보기)",
		"튜토리얼: 시작 화면 [튜토리얼]·일시정지에서 항목별로 다시 보기",
		"도감(시작 화면)에서 ☆로 선호 표시: 그 카드·조합이 선택지에 나오면 반짝여요",
	]
	return "\n".join((touch if session.touch_ui else keys) + [
		"",
		"[규칙 · %s]" % Rules.NAMES[Rules.version],
		"중앙 체력 10. 구체가 닿으면 줄어듭니다",
		"쉬는 시간마다 3개 중 1개를 고릅니다 (처음 두 번은 %d번)" % Rules.open_picks if Rules.picks == 1 else "쉬는 시간마다 3개 중 1개씩 %d번 고릅니다" % Rules.picks,
		"5웨이브마다 보스. 처치하면 체력 +2, 새로고침 +1",
		"콤보: 게임 시간 3초 안에 다음 구체를 잡으면 이어져요 (어느 오브젝트가 잡든, 배속과 상관없이). 쉬는 시간엔 멈춰서 다음 웨이브로 이어져요. 콤보마다 처치 점수 +10%, 콤보 20부터 x3. 오른쪽 위 상자에 배율과 남은 시간",
		"보스 웨이브를 넘기면 특성(모든 오브젝트에 붙는 강화) 3개 중 1개 선택",
		"공격방식은 직선탄일 때 한 번만 정할 수 있고, 같은 것을 넣으면 레벨업",
		"속성을 많이 겹칠수록 피해는 늘고 공격 속도는 조금씩 느려집니다. 오브젝트가 많을수록 모든 오브젝트의 피해가 늘어요(오브젝트 수 보너스, 5개 +16%% · 10개 +23%%, 늘수록 덜 오름). %s" % mods,
		"감속은 최대 70%, 밀기는 조금씩만. 기절·속박·얼림은 연달아 걸릴수록 짧아지다가 잠깐 면역",
		"화면 밖 구체는 맞지 않습니다. 시작 화면에서 규칙(랭크·도파민 모드)%s과 맵%s을 바꿀 수 있어요" % (["", ""] if session.touch_ui else ["(↑/↓)", "(←/→)"]),
		"모드(첫 판 뒤): 어렵게 하면 점수 배율이 오르고, 쉽게 하면 내려가요 (쉽게 모드 판은 기록 따로)",
	])


## 실행 중인 빌드가 최신인지 알아보도록 구석에 표시 (버전은 project.godot의 config/version).
func _ver_text() -> String:
	return "빈두 v%s · 규칙 %s" % [ProjectSettings.get_setting("application/config/version", "?"), Rules.NAMES[Meta.rules]]


## 웨이브 구체 수: 기존 공식 3 + 2w. 150웨이브 이후에는 기존처럼 수를 고정하고 초과 몫은 체력으로 반영한다.
func _start_choose(new_round := true) -> void:
	var session: BinduSession = self.session
	if new_round and session.wave == 0:
		# 새 판. 헤드리스(봇·점검)는 늘 모두 열린 채로
		session.tutor = Meta.tutor_next and DisplayServer.get_name() != "headless" and not TutPlay.on
		session.tutor_given = {}
		session.hud_system.start_modes()
		Vary.new_run(session.mp_mode == "" and not session.tutor and not TutPlay.on)
		if Vary.count() > 0:
			session.hud_system._show_toast("봉인: " + Vary.sealed_text())
			session.toast_timer = 5.0  # 카드 줄 위 봉인 칩에도 계속 보임 (_draw_seal_chip)
		session.run_id = session._new_run_id()
		Ach.new_run()
		session.legacy_grow = false
		session.abilities_system._skills_new_run(Meta.skill_set)
		session.abilities_system._ley_new_run()
	if new_round and session.tutor and session.wave + 1 >= BinduSession.TUTOR_OPEN.values().max() and Meta.tutor_next:
		Meta.tutor_next = false  # 모두 열렸다: 다음 판부터는 처음부터 모두
		session.progression_system._save_best()
	if new_round:
		_new_rest()
		_take_bank()
	session.phase = BinduSession.Phase.CHOOSE  # 웨이브를 막 끝낸 때도 카드 안내가 쉬는 시간 안내로 뜨게 (_open_choose가 다시 정함)
	session.cards_system._make_choices()
	session.cards_system._open_choose()
	session.persistence_system._save_run()
	if new_round:
		session.onboarding_system._rest_guides()


## 새 쉬는 시간: 다음 웨이브(방향·저항·보스)를 뽑고 고르기·새로고침 수를 정한다.
func _new_rest() -> void:
	var session: BinduSession = self.session
	session.hud_system._refresh_build()
	if session.mp_seed != 0:
		session.wrng.seed = hash([session.mp_seed, session.wave])  # 대결: 모두 같은 웨이브 (방향·저항·보스·구체)
	if session.mp_ghost:
		session.multiplayer_system._mp_ghost_rest()  # 협동 참가자: 다음 웨이브는 호스트가 정한 것
	else:
		if session.wave > 0:
			for msg in Vary.rest(session.wave):
				session.hud_system._show_toast(msg)
			if MapRule.is_map("spiral") and session.wave % 5 == 0:
				session.hud_system._show_toast("회오리: 다음 웨이브부터 회전 방향이 반대로 바뀌어요")
		session.waves_system._roll_lanes()
		# 다음 웨이브 저항 속성: 12웨이브(버전 4는 8)부터 60% 확률
		session.wave_resist = session.multiplayer_system._wpick(Elem.ALL) if session.wave + 1 >= Rules.resist_from and session.multiplayer_system.wf() < 0.6 else -1
		session.spawning_system._plan_boss()
	session.multiplayer_system._mp_rest_begin()
	session.picks_left = maxi(Rules.open_picks, Rules.picks) if session.wave <= 1 else Rules.picks  # 처음 두 번의 쉬는 시간은 2개씩, 그 뒤 1개 (모드 '두 장'이면 계속 2개)
	if TutPlay.on and session.tplay != null and session.tplay.rest_picks(session.wave) >= 0:
		session.picks_left = session.tplay.rest_picks(session.wave)  # 플레이 튜토리얼: 그 쉬는 시간의 카드 단계 수
	session.rerolls_left = Modes.rerolls(1 + session.bonus_rerolls + session.perks.get("reroll", 0) * int(session.perks_system._perk_val("reroll")))
	session.bonus_rerolls = 0


# ---------- 웨이브 넘기기 ----------

## 넘기기를 쓸 수 있나: 오브젝트가 있고, 첫 판이면 카드 종류가 다 열린 뒤.
func _can_skip() -> bool:
	var session: BinduSession = self.session
	if session.mp_mode != "":
		return false  # 멀티플레이는 웨이브 넘기기 없음 (협동은 함께, 대결은 같은 웨이브 순서)
	return session.towers.get_child_count() > 0 and not (session.tutor and session.wave + 1 < BinduSession.TUTOR_OPEN.values().max()) and session.skip_left == 0


## 선택지(또는 특성) 화면에서 넘기기: 이번 쉬는 시간의 고르기를 쌓아 두고 웨이브를 시작한다.
func _on_skip() -> void:
	var session: BinduSession = self.session
	if session.phase not in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] or not _can_skip() or session.title_label.visible or session.get_tree().paused:
		return
	if TutPlay.on and session.tplay != null and not session.tplay.allow_skip():
		session.hud_system._show_toast("웨이브 넘기기는 튜토리얼 마지막 장에서 해 봐요")
		return
	if session.perk_mode:
		session.perk_mode = false
		session.bank_perks += 1
		if not session.rest_ready:
			_new_rest()  # 특성 뒤에 올 카드 고르기도 같이 쌓는다
			_take_bank()
	session.skip_total = int(Meta.skip_n)
	session.skip_left = session.skip_total
	session.skip_stop = false
	_bank_rest()
	session.hud_system._show_toast("웨이브 %d개 넘기기: 카드 선택은 멈춘 뒤 한꺼번에 (%s)" % [session.skip_total, "아래 표시를 누르면 멈춤" if session.touch_ui else "S: 멈추기"])


## 이번 쉬는 시간의 남은 고르기·새로고침을 쌓고 바로 다음 웨이브로 (1초 뒤 시작).
## picks_left에는 이미 쌓인 고르기(bank_picks)도 들어 있다.
func _bank_rest() -> void:
	var session: BinduSession = self.session
	for i in session.picks_left - session.bank_picks.size():
		session.bank_picks.append(session.wave)
	session.picks_left = 0
	session.bank_rerolls += session.rerolls_left
	session.rerolls_left = 0
	session.offer.clear()
	for c in session.choice_box.get_children():
		c.queue_free()
	session.rest_ready = false
	session.cards_hidden = false
	session.cards_system._enter_ready()
	session.countdown = 1.0


## 넘기는 중에 웨이브가 끝났다: 고르지 않고 다음 쉬는 시간을 쌓는다.
func _skip_rest() -> void:
	var session: BinduSession = self.session
	if session.wave % 5 == 0:
		session.bank_perks += 1
	session.wave_active = false
	session.cards_system._clear_shots()  # 쉬는 시간처럼 남은 탄·장판을 지운다
	_new_rest()
	_take_bank()
	session.waves_system._update_preview()
	_bank_rest()


## 쌓아 둔 고르기·새로고침을 이번 쉬는 시간에 더한다.
func _take_bank() -> void:
	var session: BinduSession = self.session
	session.picks_left += session.bank_picks.size()
	session.rerolls_left += session.bank_rerolls
	session.bank_rerolls = 0


## 넘기기를 끝내고 쌓인 것을 연다: 특성부터 하나씩, 그다음 카드.
## now_rest: 이번 쉬는 시간의 다음 웨이브를 이미 뽑아 둔 채(넘기기 대기 중) 멈췄나.
func _end_skip(now_rest: bool) -> void:
	var session: BinduSession = self.session
	if not now_rest and not session.skip_stop:
		Ach.on_skip_done(session.skip_total)  # 멈추지 않고 끝까지 넘김
	session.skip_left = 0
	session.skip_stop = false
	session.countdown = -1.0
	session.start_btn.visible = false
	if now_rest:
		session.rest_ready = true
		session.picks_left = 0
		_take_bank()
	if not now_rest and session.wave % 5 == 0:
		session.perks_system._start_perk()  # 이번 쉬는 시간의 특성 (미룬 특성은 그 뒤에 이어서)
	elif session.bank_perks > 0:
		session.bank_perks -= 1
		session.perks_system._start_perk()
	else:
		_start_choose(not now_rest)


## 넘기는 중 멈추기: 웨이브 중이면 그 웨이브 뒤에, 다음 웨이브를 기다리는 중이면 바로.
func _toggle_skip_stop() -> void:
	var session: BinduSession = self.session
	if session.skip_left <= 0:
		return
	if session.phase == BinduSession.Phase.READY:
		_end_skip(true)
		return
	session.skip_stop = not session.skip_stop
	session.hud_system._show_toast("이번 웨이브가 끝나면 넘기기를 멈춰요" if session.skip_stop else "넘기기를 계속해요")


func _cycle_skip_n() -> void:
	var session: BinduSession = self.session
	var i := BinduSession.SKIP_NS.find(int(Meta.skip_n))
	Meta.skip_n = BinduSession.SKIP_NS[(i + 1) % BinduSession.SKIP_NS.size()]
	session.progression_system._save_best()


## 넘기기 버튼·넘기는 중 표시 (매 프레임).
func _update_skip_ui() -> void:
	var session: BinduSession = self.session
	# 카드를 다 고른 뒤(웨이브 시작 대기)에도 [웨이브 시작] 옆에서 넘기기를 쓸 수 있다
	var ready_skip := session.phase == BinduSession.Phase.READY and session.skip_left == 0
	var show_btn := (session.phase == BinduSession.Phase.CHOOSE and not session.cards_hidden or ready_skip) and not session.title_label.visible and _can_skip() and not session.get_tree().paused and session.coin_stage == 0
	session.skip_btn.visible = show_btn
	session.skip_n_btn.visible = show_btn
	# 글자를 키우면(폰 기본) 카드 아래 버튼 줄이 왼쪽 아래 안내 글까지 내려와 겹친다. 카드를 고르라는 글이라 겹칠 때만 숨긴다
	# 글이 빈 안내는 띄우지 않는다 (판 끝 화면 아래에 빈 상자로 남았다)
	session.hint.visible = session.hint.text != "" and not (show_btn and session.hint.get_global_rect().intersects(session.skip_btn.get_global_rect()))
	if show_btn:
		var n := int(Meta.skip_n)
		var deferred := "특성 선택 1회 보류" if session.perk_mode else "카드 선택 %d회 보류 · 새로고침 %d회 보류" % [session.picks_left, session.rerolls_left]
		session.skip_btn.tooltip_text = "%d웨이브 넘기기 (S)\n%s\n미룬 카드·새로고침·특성은 멈춘 뒤 한꺼번에 고릅니다. 중앙이 위험해지면(설정) 그 웨이브가 끝나고 멈춥니다" % [n, deferred]
		session.skip_btn.text = "넘기기"
		session.skip_n_btn.text = "%d웨이브 ▸" % n
	session.skip_badge.visible = session.skip_left > 0 and session.phase in [BinduSession.Phase.WAVE, BinduSession.Phase.READY] and not session.title_label.visible
	if session.skip_badge.visible:
		var done := session.skip_total - session.skip_left + 1
		var cards := session.bank_picks.size()
		var extra := " · 특성 %d" % session.bank_perks if session.bank_perks > 0 else ""
		if session.skip_stop:
			session.skip_badge.text = session.ui_layout_system._kh("이번 웨이브 뒤 멈춤 · 쌓인 카드 %d%s (S: 계속)" % [cards, extra], true)
		elif session.phase == BinduSession.Phase.READY:
			session.skip_badge.text = session.ui_layout_system._kh("넘기는 중 %d/%d · 쌓인 카드 %d%s (S: 지금 멈추고 선택)" % [done, session.skip_total, cards, extra], true)
		else:
			session.skip_badge.text = session.ui_layout_system._kh("넘기는 중 %d/%d · 쌓인 카드 %d%s (S: 멈추기)" % [done, session.skip_total, cards, extra], true)


## 선택지 화면을 연다 (offer는 이미 정해져 있음).
func _reload() -> void:
	var session: BinduSession = self.session
	session.run_detail.close()
	_mp_keep_room()
	if session.is_inside_tree() and session.get_tree().current_scene != null:
		session.get_tree().reload_current_scene()


## 멀티 판 끝 → 다시 불러오기 전에: 방 연결(Mp)을 루트에 옮겨 두고, 새 화면이 대기방을 열게 표시한다.
func _mp_keep_room() -> void:
	var session: BinduSession = self.session
	if session.mp != null and session.mp_mode != "" and session.phase == BinduSession.Phase.GAMEOVER and session.is_inside_tree():
		# 멀티 판 끝 → 대기방으로 (방은 나가기 전까지 남는다)
		BinduSession.mp_back = true
		BinduSession.mp_back_msg = ""
		if session.mp.active():
			BinduSession.mp_keep = session.mp
			session.mp.reparent(session.get_tree().root)
		else:
			BinduSession.mp_back_msg = session.mp_fail_msg if session.mp_fail_msg != "" else "방이 없어져 대기방으로 돌아가지 못했어요"


## 왼쪽 아래 안내 글 위쪽 끝 (안내 글이 없으면 아래 버튼 줄 위).
func _start_wave() -> void:
	var session: BinduSession = self.session
	if TutPlay.on and session.tplay != null and not session.tplay.can_start():
		session.countdown = -1.0
		return
	if session.mp_mode == "coop" and not session.mp_wave_go:
		session.countdown = -1.0
		session.multiplayer_system._mp_coop_ready()
		return
	session.countdown = -1.0
	session.interaction_system._drop_press()
	session.interaction_system.boxing = false
	session.interaction_system.selected.clear()
	session.start_btn.visible = false
	session.wave += 1
	session.rest_ready = false
	session.phase = BinduSession.Phase.WAVE
	session.wave_active = true
	session.choice_box.visible = false
	session.reroll_btn.visible = false
	session.to_spawn = session.spawn_count(session.wave)
	session.mp_extra_left = session.mp_next_extra
	session.mp_wave_extra = session.mp_next_extra
	session.mp_next_extra = 0
	session.mp_recv_n = 0
	session.mp_idle_t = 0.0
	# 진입 방향은 배지에 띄운 수대로 고르게 나눠 섞는다 (구체마다 무작위로 고르면 화살표의 수와 달라짐)
	session.lane_bag.clear()
	var lc := session.waves_system.lane_counts(session.wave)
	for i in lc.size():
		for k in lc[i]:
			session.lane_bag.append(i)
	session.multiplayer_system._wshuffle(session.lane_bag)
	if session.mp_ghost:
		session.to_spawn = 0  # 협동 참가자: 구체는 호스트가 보낸 대로
		session.lane_bag.clear()
	session.wave_leaks.clear()
	session.leak_marks.clear()
	session.wave_stat = {"hp": 0.0, "kn": 0, "life": 0.0, "close": -1.0, "peak": 0}
	session.wave_dmg = 0
	session.jam_any = false
	session.skill_cd = {}  # 중앙 기술은 웨이브마다 다시 찬다
	session.skill_arm = ""
	if not session.skill_ids.is_empty():
		session.onboarding_system._guide("skill", "아래 기술 버튼%s을 누르고 쓸 곳을 누르면 웨이브 중에 도울 수 있어요. 웨이브마다 다시 차요" % ("" if session.touch_ui else "(1·2 키)"))
	session.shield = session.perks_system._shield_wave()
	session.rampart_left = session.perks_system._rampart_n()
	if session.guide_t < 0.0:
		session.guide_lines.clear()
		session.guide_t = 0.0
	for w in [10, 15, 20]:
		if session.wave >= w:
			session.progression_system._achieve("wave%d" % w)
	Ach.on_wave_start(session.wave, session.towers.get_children(), Meta.map_id)
	session.progression_system._ach_check()
	session.spawn_interval = maxf(0.35, 1.2 - session.wave * 0.06)
	session.spawn_timer = 0.5
	session.wave_time = 0.0
	session.late_n = {}
	session.dps_hist.clear()
	session.dps_t = 0.0
	session.dps_n = 0
	session.rank_t = BinduSession.RANK_HOLD + 0.05  # 피해가 다시 쌓인 뒤에 매긴다
	for t in session.towers.get_children():
		t.cd.clear()
		t.fx.clear()
		t.run_dealt += t.dealt
		t.close_src()
		t.wave_begin()
		t.dealt = 0.0
		t.rx_dealt = 0.0
		t.queue_redraw()  # 레벨 숫자는 쉬는 시간에만
	session.hint.text = ""
	session.hud_system.big_banner("웨이브 %d" % session.wave, Color.WHITE)
	session.sfx.play("wave", 0.0)


## 길목별 참고 경고. 기본 공격의 근사 범위이며 시작을 차단하지 않는다.
func lane_warning(index: int) -> String:
	var session: BinduSession = self.session
	if index < 0 or index >= session.lanes.size(): return ""
	return "" if _wave_lane_covered(session.lanes[index], session.wave + 1, session.lane_spread(session.wave + 1)) else "기본 공격 범위 밖"


## 진입 길을 따라 여러 지점을 살펴 공격 사거리·방향 안에 들어오는 오브젝트를 찾는다.
func _wave_lane_covered(a: float, w: int, spread: float) -> bool:
	var session: BinduSession = self.session
	var path := session.spawning_system._orb_path(a)
	if path.size() < 2:
		return true
	var samples: Array[Vector2] = []
	if Meta.map_id == "line":
		for y in [-BinduSession.LINE_HALF + 20.0, 0.0, BinduSession.LINE_HALF - 20.0]:
			var line_path := session.spawning_system._orb_path(a, y)
			for k in range(1, 9):
				samples.append(line_path[0].lerp(line_path[1], float(k) / 9.0))
	else:
		for seg in range(path.size() - 1):
			var length := path[seg].distance_to(path[seg + 1])
			var n := maxi(1, ceili(length / 45.0))
			for k in n:
				samples.append(path[seg].lerp(path[seg + 1], float(k) / n))
	for t: Tower in session.towers.get_children():
		var reach := _wave_attack_reach(t)
		if reach <= 0.0:
			continue
		for p in samples:
			var v := p - t.position
			var dist := v.length()
			if dist < 8.0 or dist > reach:
				continue
			# 자동 조준·중력 우물은 공격 방향을 고정하지 않는다. 나머지는 공격 폭과
			# 구체의 진입 부채꼴을 함께 고려해 중앙선을 겨눈 공격도 유효하게 판정한다.
			if t.auto_aim() or t.pattern == "vortex":
				return true
			var half := 0.12
			match t.pattern:
				"spray": half = 0.35
				"chain": half = 0.5
				"sonic": half = 0.5
				"clock": half = 0.7
			var width := atan(18.0 / dist)
			if absf(t.dir.angle_to(v)) <= maxf(half, width) + spread:
				return true
	return false


## 기본 공격방식별 유효 사거리. 수치는 실제 공격·사거리 표시와 같은 기준이다.
func _wave_attack_reach(t: Tower) -> float:
	if t.pattern in Tower.FAR_PATS and not t.auto_aim():
		return Tower.FAR  # 직선탄·돌풍·물줄기·연쇄 번개는 화면 끝까지 (멀면 약해질 뿐)
	return t.well_range() if t.pattern == "vortex" else t.reflex_range()


func _game_over() -> void:
	var session: BinduSession = self.session
	session.multiplayer_system._mp_over()
	session.onboarding_system._tut_event("over")
	session.combat_system._log_wave()
	session.phase = BinduSession.Phase.GAMEOVER
	session.over_ms = Time.get_ticks_msec()
	session.toast_timer = 0.0  # 넘기기 알림 등이 게임 오버 글 위에 남지 않게
	session.wave_active = false
	session.game_speed = 1.0
	_update_speed_btn()
	session.banner_queue.clear()  # 남은 가운데 글자가 게임 오버 글 위에 뜨지 않게 (새 업적은 아래 글에 나옴)
	session.banner_t = minf(session.banner_t, 0.4)
	# 특성 고르기·동전 연출 중에 판을 끝내면(일시정지 [판 끝내기]) 특성 카드 줄과 동전이 결과 화면 위에 남았다.
	session.perk_mode = false
	session.coin_stage = 0
	if session.coin_fx:
		session.coin_fx.visible = false
		session.coin_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 기록은 지금 맵·규칙 버전의 저장값과 비교한다 (다른 키에서 남은 값이 섞이지 않게)
	var prev := Meta.best_of(Meta.run_key())
	var record := "  최고 기록!" if (session.score > prev[1] or session.wave > prev[0]) and session.mp_mode == "" else ""
	if session.mp_mode == "":  # 멀티플레이 판은 혼자 하는 판 최고 기록에 넣지 않는다
		session.best_score = maxi(session.score, prev[1])
		session.best_wave = maxi(session.wave, prev[0])
	if session.mp_mode == "":  # 멀티 판은 누적 처치·판 수(업적)에 넣지 않는다
		Meta.total_kills += session.kills
		Meta.games += 1
	Ach.live_kills = 0
	session.progression_system._ach_check()
	if session.tutor:
		Meta.tutor_next = false
	session.progression_system._save_best()
	session.persistence_system._clear_run()
	session.net.sync()
	var ach := "\n새 업적: " + ", ".join(session.new_achievements) if not session.new_achievements.is_empty() else ""
	# 판 전체에서 가장 많이 때린 오브젝트
	var mvp := ""
	var top: Tower = null
	var total := 0.0
	for t in session.towers.get_children():
		total += t.run_dealt + t.dealt
		if top == null or t.run_dealt + t.dealt > top.run_dealt + top.dealt:
			top = t
	if top and total > 0.0 and session.towers.get_child_count() > 1:
		mvp = "\n최다 피해: %s (%d%%)" % [top.title(), roundi((top.run_dealt + top.dealt) / total * 100.0)]
	var rs := session.hud_system._run_src()
	if total > 0.0 and not rs.is_empty():
		var tops := PackedStringArray()
		for key in session.hud_system._src_top(rs, 3):
			tops.append("%s %d%%" % [session.src_name(key), roundi(rs[key] / total * 100.0)])
		mvp += "\n피해 출처: " + ", ".join(tops)
	var md := "" if Modes.on.is_empty() else "\n모드: %s · 점수 x%.2f%s" % [Modes.names(), Modes.mul(), "\n쉽게 모드: 최고 기록 따로, 쉽게 모드 리더보드에 올라감" if Modes.easy() else ""]
	if session.mp_mode != "":
		record = ""
		md = "\n" + session.mp_rank if session.mp_rank != "" else ""
	var head: String = ("협동 끝" if session.mp_mode == "coop" else "탈락") if session.mp_mode != "" else "판 끝냄" if session.ended else "게임 오버"
	over_data = {"head": head, "sub": "%s · %s" % [Meta.map_name(Meta.map_id), Rules.NAMES[Meta.rules]], "wave": session.wave, "score": session.score, "record": record != "", "best_wave": session.best_wave if session.mp_mode == "" else -1,
		"kills": session.kills, "combo": session.best_combo, "towers": session.towers.get_child_count(), "ach": session.new_achievements.duplicate()}
	# 아래 글은 그림으로 못 줄인 것만 (모드·순위·최다 피해·피해 출처, 온라인 순위는 나중에 붙음)
	session.over_label.text = session.patchlog_system._kr_keep((md + mvp).strip_edges())
	session.over_card.visible = true
	session.over_card.queue_redraw()
	session.over_label.visible = true
	session.online_system._submit_run()
	session.sfx.play("over", 0.0)
	session.reroll_btn.visible = false
	session.choice_box.visible = false
	session.hint.text = ""
	session.hint.visible = false  # 카드 줄이 꺼진 뒤라 빈 안내 상자가 결과 아래에 남았다


## 결과 상세를 열 수 있는지: 혼자·멀티 모두, 내 오브젝트가 하나라도 있으면 (연습 판 제외).
func detail_ok() -> bool:
	var session: BinduSession = self.session
	return session.phase == BinduSession.Phase.GAMEOVER and not TutPlay.on and not over_data.is_empty() and not session.multiplayer_system._my_towers().is_empty()


## 결과 화면 [결과 상세]에서 버튼 줄 아래 투표 버튼까지 거리 (남은 글 끝 기준).
func over_tail_h() -> float:
	return 92.0 if detail_ok() else 34.0


func _open_detail() -> void:
	var session: BinduSession = self.session
	if detail_ok():
		session.run_detail.open(session, session.multiplayer_system._my_towers())


## 게임 오버 그림 카드 (over_card 가운데가 화면 가운데 위쪽).
func _draw_over_card() -> void:
	var session: BinduSession = self.session
	if not session.over_label.visible or over_data.is_empty():
		return
	var d := over_data
	var c := session.over_card
	var W := 620.0
	var x0 := -W / 2.0
	var y := -210.0
	# 업적 배지 줄 나누기를 먼저 해서 바탕 높이를 안다
	var ach_rows: Array = []
	var ach_w: Array = []
	for a in d["ach"]:
		var aw := session.ui_font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 36.0
		if ach_rows.is_empty() or ach_w[-1] + aw > W:
			ach_rows.append([])
			ach_w.append(0.0)
		ach_rows[-1].append([a, aw])
		ach_w[-1] += aw + 6.0
	var bh := 84.0 + 96.0 + 50.0 + (Meta.fs(11) - 11) + ach_rows.size() * 30.0 + 34.0 + (Meta.fs(13) - 13)
	# 아래 남은 글(over_label: 모드·최다 피해·피해 출처)까지 바탕에 넣는다: 예전엔 바탕 밖 전장 위에 떠 읽기 어려웠다
	var lab_h := 0.0
	if session.over_label.text != "" and session.over_label.get_line_count() > 0:
		lab_h = session.over_label.get_line_count() * session.over_label.get_line_height() + 10.0
	bh += lab_h
	if detail_ok():
		bh += 58.0  # [결과 상세] 버튼 줄 + 그 아래 나가는 법 글 줄
	# 점수 줄 아래에서 시작 (폰 글자 1.3이면 화면 높이가 줄어 제목이 점수 줄 둘째 줄을 덮었다), 아래 버튼 줄 위까지
	var top_free := session.hud_system._dps_home().y - c.position.y
	var bottom_free := (c.get_parent() as Control).size.y - 56.0 - c.position.y
	if y - 6.0 < top_free:
		y = maxf(minf(top_free, bottom_free - bh), y - 6.0) + 6.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	bg.set_corner_radius_all(12)
	c.draw_style_box(bg, Rect2(x0 - 10.0, y - 6.0, W + 20.0, bh))
	c.draw_string(session.ui_font, Vector2(x0, y + 34.0), d["head"], HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color.WHITE)
	var sw := session.ui_font.get_string_size(d["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, Meta.fs(14)).x + 24.0
	Icons.chip(c, session.ui_font, Rect2(-sw / 2.0, y + 46.0, sw, 28.0), "", Color.WHITE, d["sub"], Color(1, 1, 1, 0.65), Meta.fs(14), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12))
	# 큰 칩 둘: 웨이브 · 점수
	y += 84.0
	for i in 2:
		var r := Rect2(-196.0 + i * 204.0, y, 188.0, 62.0)
		var gold := i == 1
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.15, 0.08, 0.95) if gold else Color(0.1, 0.12, 0.17, 0.95)
		sb.border_color = Color(1, 0.85, 0.4, 0.6) if gold else Color(0.5, 0.7, 1, 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		c.draw_style_box(sb, r)
		Icons.draw(c, "score" if gold else "wave", r.position + Vector2(30, 31), 13.0, Color(1, 0.85, 0.4) if gold else Color(0.6, 0.8, 1))
		var txt := session.num(d["score"]) if gold else str(d["wave"])
		var fs := 32
		while fs > 18 and session.ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 120.0:
			fs -= 2
		c.draw_string(session.ui_font, r.position + Vector2(54, 31 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if d["record"]:
		Icons.chip(c, session.ui_font, Rect2(132.0, y - 9.0, 64.0, 20.0), "", Color.WHITE, "최고!", Color(0.12, 0.09, 0.0), 12, Color(1, 0.85, 0.4), Color(1, 0.85, 0.4))
	elif d["best_wave"] >= 0:
		Icons.draw(c, "best", Vector2(-110.0, y + 76.0), 6.0, Color(1, 1, 1, 0.5))
		c.draw_string(session.ui_font, Vector2(-100.0, y + 80.0), "최고 %d" % d["best_wave"], HORIZONTAL_ALIGNMENT_LEFT, -1, Meta.fs(12), Color(1, 1, 1, 0.5))
	# 작은 칩: 처치 · 최고 콤보 · 오브젝트
	y += 110.0
	var smalls := [["kill", session.num(d["kills"]), "처치"], ["combo", str(d["combo"]), "최고 콤보"], ["tower", str(d["towers"]), "오브젝트"]]
	for i in smalls.size():
		var cx := -130.0 + i * 130.0
		Glyph.ui(c, smalls[i][0], Vector2(cx - 22.0, y), 9.0, Color(0.85, 0.9, 1))
		c.draw_string(session.ui_font, Vector2(cx - 8.0, y + 7.0), smalls[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
		c.draw_string(session.ui_font, Vector2(cx - 50.0, y + 13.0 + Meta.fs(11)), smalls[i][2], HORIZONTAL_ALIGNMENT_CENTER, 100.0, Meta.fs(11), Color(1, 1, 1, 0.45))
	# 새 업적 배지 (줄이 넘치면 다음 줄)
	y += 31.0 + Meta.fs(11)
	for ri in ach_rows.size():
		var x: float = -(ach_w[ri] - 6.0) / 2.0
		for it in ach_rows[ri]:
			var r := Rect2(x, y + ri * 30.0, it[1], 24.0)
			Icons.chip(c, session.ui_font, r, "", Color.WHITE, "", Color.WHITE, 13, Color(0.15, 0.12, 0.2, 0.95), Color(0.8, 0.6, 1, 0.5))
			Glyph.kind(c, "ach", r.position + Vector2(14, 12), 7.0, Color(1, 0.8, 0.4))
			c.draw_string(session.ui_font, r.position + Vector2(26, 17), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			x += it[1] + 6.0
	y += ach_rows.size() * 30.0
	# 남은 글(over_label)은 배지 바로 아래, 나가는 법은 그 아래 바탕 끝 줄
	if absf(session.over_label.offset_top - (y + 4.0)) > 0.5:
		session.over_label.offset_top = y + 4.0  # (둘 다 화면 가운데 기준)
		session.over_label.offset_bottom = y + 154.0
	var dim := Color(1, 1, 1, 0.5)
	var to_lobby := session.mp_mode != "" and session.mp.active()  # 멀티 판: 방이 남아 있으면 대기방으로
	var hy := y + lab_h + 14.0
	var detail := detail_ok()
	session.over_detail_btn.visible = detail
	if detail:
		session.over_detail_btn.position = Vector2(-session.over_detail_btn.size.x / 2.0, hy - 10.0)
		hy += 58.0
	if session.touch_ui:
		c.draw_string(session.ui_font, Vector2(x0, hy), "눌러서 대기방으로" if to_lobby else "눌러서 시작 화면으로", HORIZONTAL_ALIGNMENT_CENTER, W, Meta.fs(13), dim)
	else:
		# 그림(마우스·집)만으로는 무엇을 누르면 어디로 가는지 알기 어려웠다: 글로
		# 폰·태블릿엔 키보드 안내를 띄우지 않는다
		c.draw_string(session.ui_font, Vector2(x0, hy), ("눌러서 " if session.touch_ui else "클릭 · R · Esc: ") + ("대기방으로" if to_lobby else "시작 화면으로"), HORIZONTAL_ALIGNMENT_CENTER, W, Meta.fs(13), dim)


# ---------- 입력 ----------

## 두 손가락 벌리기·모으기 = 확대, 두 손가락 끌기 = 이동. PC는 휠 = 확대(커서 쪽), 휠 누른 채 끌기 = 이동.
## 처리했으면 true (그 입력은 게임·UI로 넘기지 않는다).
func _toggle_pause() -> void:
	var session: BinduSession = self.session
	if session.phase == BinduSession.Phase.GAMEOVER or session.title_label.visible:
		return
	session.get_tree().paused = not session.get_tree().paused
	if session.get_tree().paused:
		session.interaction_system._abort_touch_action()
	session.paused_label.visible = session.get_tree().paused
	session.pause_box.visible = session.get_tree().paused
	session.paused_label.text = _pause_text()
	session.restart_armed = 0.0
	session.end_armed = 0.0
	session.pause_btn.tooltip_text = "계속 (P)" if session.get_tree().paused else "일시정지 (P)"  # 그림 버튼이라 글은 말풍선에만


## 일시정지에서 처음부터: 두 번 눌러야 (R 또는 버튼).
func _pause_restart() -> void:
	var session: BinduSession = self.session
	if session.restart_armed > 0.0:
		session.get_tree().paused = false
		if TutPlay.on and session.tplay != null:
			var ch := session.tplay.start_ch
			TutPlay.leave_meta()
			TutPlay.pending = ch  # 연습 판: 그 장 처음부터
		_reload()
	else:
		session.restart_armed = 2.0
		session.paused_label.text = _pause_text() + "\n처음부터를 한 번 더 누르면 새 판"


## 일시정지 글: 지금 나가면 어디서부터 이어지는지도 알려 준다. 키는 아래 그림 버튼 모서리에.
func _pause_text() -> String:
	var session: BinduSession = self.session
	var keys := "일시정지"
	if TutPlay.on:
		return keys + "\n연습 판이에요. 기록·업적은 남지 않아요"
	if session.phase == BinduSession.Phase.WAVE:
		return keys + "\n지금 나가면 웨이브 %d 앞 쉬는 시간부터 이어집니다" % session.wave
	return keys + "\n지금 나가도 이 쉬는 시간부터 이어서 할 수 있어요"


## 일시정지에서 판 끝내기: 두 번 누르면 지금 점수로 게임 오버 (기록 저장·온라인 전송은 보통 게임 오버와 같다).
## 실수로 누르지 않게 처음 누르면 안내만 한다.
func _end_run() -> void:
	var session: BinduSession = self.session
	if TutPlay.on and session.tplay != null:
		_toggle_pause()
		session.tplay.ask_quit()  # 연습 판: 튜토리얼 끝내기 확인
		return
	if session.end_armed <= 0.0:
		session.end_armed = 3.0
		session.paused_label.text = _pause_text() + "\n판 끝내기를 한 번 더 누르면 지금 점수 %s로 끝냅니다 (기록·순위에 올라가요)" % session.num(session.score)
		return
	session.end_armed = 0.0
	session.get_tree().paused = false
	session.paused_label.visible = false
	session.pause_box.visible = false
	session.pause_btn.tooltip_text = "일시정지 (P)"
	session.ended = true
	_game_over()


## 일시정지에서 시작 화면으로 가거나 게임을 끈다. 쉬는 시간이면 지금 상태를 저장하고,
## 웨이브 중이면 그 웨이브 앞 쉬는 시간의 저장이 남는다 (시작 화면의 이어하기).
func _leave(quit_game: bool) -> void:
	var session: BinduSession = self.session
	if TutPlay.on and session.tplay != null and not quit_game:
		session.tplay.finish(false)  # 연습 판에서 시작 화면으로 = 튜토리얼 끝내기
		return
	session.persistence_system._save_run()
	if quit_game:
		TutPlay.leave_meta()
	session.get_tree().paused = false
	if quit_game:
		session.get_tree().quit()
		return
	BinduSession.title_seen = false
	_reload()


# ---------- 기맥 (2026-10-31 "디펜스 한계 개선 F") ----------
## 판마다 전장에 기맥 자리 ley_n개가 생긴다(판 번호로 정해 이어하기도 같음). 자리마다 ley_r 안 가장 가까운 오브젝트 하나가 피해 +ley_dmg.
func _toggle_speed() -> void:
	var session: BinduSession = self.session
	# Space·버튼: 1배속 ↔ 고른 배속
	session.game_speed = _fast_now() if session.game_speed == 1.0 else 1.0
	_update_speed_btn()


## 빠르게 켤 때 배속
func _fast_now() -> float:
	var session: BinduSession = self.session
	return session.fast_speed


func _update_speed_btn() -> void:
	var session: BinduSession = self.session
	session.speed_btn.text = "x%d" % roundi(session.game_speed)
	session.speed_btn.tooltip_text = "배속 x%d (Space)" % roundi(session.game_speed)
	session.speed_btn.queue_redraw()
	for i in BinduSession.SPEEDS.size():
		if BinduSession.SPEEDS[i] == session.fast_speed:
			session.speed_pick.select(i)


func _on_speed_pick(i: int) -> void:
	var session: BinduSession = self.session
	session.fast_speed = BinduSession.SPEEDS[i]
	if session.game_speed > 1.0:
		session.game_speed = _fast_now()
	_update_speed_btn()
	session.progression_system._save_best()
