class_name BinduProgression
extends BinduFeature

func _achieve(id: String) -> void:
	if TutPlay.on:
		return  # 연습 판은 업적이 없다
	if session.mp_mode != "" and not Ach.is_mp(id):
		return  # 멀티 판은 멀티 업적만
	if not Meta.achieve(id):
		return
	session.onboarding_system._tut_event("ach")
	var a: Dictionary = Meta.ACHIEVEMENTS[id]
	session.new_achievements.append(a["name"])
	session.hud_system.big_banner("업적: " + a["name"], Color(1, 0.85, 0.4))
	session.sfx.play("reaction", 0.0)
	for sk in Meta.TOWER_SKIN_IDS:
		if Meta.TOWER_SKINS[sk]["need"] == id:
			session.hud_system._show_toast("오브젝트 모양 '%s' 해금 (메뉴에서 선택)" % Meta.TOWER_SKINS[sk]["name"])
	for sk in Meta.CORE_SKIN_IDS:
		if Meta.CORE_SKINS[sk]["need"] == id:
			session.hud_system._show_toast("중앙 모양 '%s' 해금 (메뉴에서 선택)" % Meta.CORE_SKINS[sk]["name"])
	_save_best()


## 조건을 넘긴 업적을 준다 (Ach.LIST).
func _ach_check() -> void:
	for id in Ach.newly_met():
		_achieve(id)


## 이전 기록·다른 기기 진행으로 이미 넘긴 업적은 배너 없이 한꺼번에 (불러올 때·진행 맞춘 뒤).
func _ach_catch_up() -> void:
	var got := Ach.newly_met()
	if got.is_empty():
		return
	for id in got:
		Meta.achieve(id)
	if session.is_inside_tree() and session.hint:
		session.hud_system._show_toast("업적 %d개 달성: %s" % [got.size(), ", ".join(got.map(func(id): return Meta.ACHIEVEMENTS[id]["name"]))])


## 설치 후 확인하는 업적·도감.
func _check_progress() -> void:
	var pincers := 0
	for t in session.towers.get_children():
		pincers += 1 if t.pincer > 0 else 0
		if t.order.size() >= 5:
			_achieve("stack5")
		var rs: Array = t.reactions()
		Ach.on_reactions(rs.map(func(r): return r["id"]))
		for r in rs:
			if session.mp_mode == "" and not TutPlay.on and Meta.discover(r["id"]):
				if session.rx_card.active():
					session.rx_card.found[r["id"]] = true  # 카드 머리에 "도감 +" 표시
				else:
					session.hud_system._show_toast("조합 도감에 추가: " + r["name"])
				_save_best()
				session.menu_system._refresh_legend()
				session.onboarding_system._guide("react", "")
	if pincers >= 3:
		_achieve("links3")
	_ach_check()


func _close_title() -> void:
	if session.continue_btn.visible and session.new_armed <= 0.0:
		session.new_armed = 2.5
		session.new_btn.text = "정말 새로 시작?"
		return
	session._clear_run()
	_hide_title()
	session.lanes.clear()
	session._start_choose()


func _hide_title() -> void:
	session.title_label.visible = false
	session.help_label.visible = false
	session.records_panel.visible = false
	session.settings_panel.visible = false
	session.notes_panel.visible = false
	session.codex_panel.visible = false
	if session.vote_panel.visible:
		session.vote_panel.hide_panel()
	session.remote_btn.visible = false
	session.title_seen = true


# ---------- 이어하기 ----------

## 쉬는 시간마다 판을 저장한다. 웨이브 중에 끄면 그 웨이브 앞 쉬는 시간부터 이어진다.
func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(session.SAVE_PATH) == OK:
		Meta.load_into(cfg)
		# 예전 버전의 정원 기록([garden] 칸)은 읽지 않고, 다음 저장 때 빠진다
		if FileAccess.file_exists(session.OLD_GARDEN_RUN):
			DirAccess.remove_absolute(session.OLD_GARDEN_RUN)  # 정원 저장 판은 더 쓰지 않는다

		var b := Meta.best_of(Meta.run_key())
		session.best_wave = b[0]
		session.best_score = b[1]
		session.auto_start = Meta.val(cfg, "option", "auto_start", false)
		session.legend_hidden = Meta.val(cfg, "option", "legend_hidden", session.legend_hidden)
		session.bar_open = Meta.val(cfg, "option", "bar_open", false)
		session.sfx.set_muted(Meta.val(cfg, "option", "muted", false))
		session.fast_speed = Meta.val(cfg, "option", "fast_speed", 2.0)
		if not session.fast_speed in session.SPEEDS:
			session.fast_speed = 2.0


func _save_best() -> void:
	TutPlay.swap()  # 연습 판: 원래 맵·규칙·모드로 저장
	var cfg := ConfigFile.new()
	var b := Meta.best_of(Meta.run_key())
	if session.best_wave > b[0] or session.best_score > b[1]:
		Meta.map_best[Meta.run_key()] = [maxi(session.best_wave, b[0]), maxi(session.best_score, b[1])]
	Meta.save_into(cfg)
	cfg.set_value("option", "auto_start", session.auto_start)
	cfg.set_value("option", "legend_hidden", session.legend_hidden)
	cfg.set_value("option", "bar_open", session.bar_open)
	cfg.set_value("option", "muted", session.sfx.muted)
	cfg.set_value("option", "fast_speed", session.fast_speed)
	cfg.save(session.SAVE_PATH)
	TutPlay.swap()


# ---------- 멀티플레이 ----------
# 대결(vs): 모두 같은 씨앗으로 같은 웨이브를 받아 각자 판을 하고, 상태·보낸 구체·탈락만 주고받는다.
# 협동(coop): 호스트가 한 전장을 계산하고 참가자는 받은 구체를 그린다. 오브젝트는 놓은 사람이 바꾸고 서로 보낸다.

## 대결 씨앗이 있으면 모두 같은 난수, 없으면 전역 난수(혼자 하는 판·봇 측정과 같은 순서).
