class_name BinduFrame
extends BinduFeature
## 루트에서 호출하는 프레임 갱신 순서. 예약 콜백은 main의 순서를 따른다.

var key_t := 0.0
var _hint_kept := ""  # 낱말 붙임(_kr_keep)을 넣은 아래 안내 글
func _process(delta: float) -> void:
	var session: BinduSession = self.session
	session.rank_t -= delta
	if session.rank_t <= 0.0:
		session.rank_t = BinduSession.RANK_STEP
		session.hud_system._rank_update()
	key_t -= delta
	session.lobby_system._mp_lobby_tick()
	session.multiplayer_system._mp_tick(delta)
	if session.coin_stage > 0 and not session.get_tree().paused:
		session.perks_system._coin_step(delta)
	session.touch_tip_t -= delta
	# 터치 자세히는 유지 중인 인스펙터를 기준으로 표시한다.
	var tip_on := session.touch_ui and not session.title_label.visible and (is_instance_valid(session.card_dock.inspected_tower) if session.card_dock.active() else Engine.get_process_frames() - session.tip_frame <= 2)
	if session.touch_ui or session.phase == BinduSession.Phase.PLACE:
		session.fx_layer.queue_redraw()  # PLACE: 올린 오브젝트 설명(place_note)이 마우스를 따라가게. 정보창이 떠 있는지(tip_frame)를 매 프레임 알도록 (쉬는 시간엔 다시 그리지 않는 프레임이 있다)
	if not tip_on:
		session.tip_detail = false
	session.detail_btn.visible = tip_on
	session.aim_ok_btn.visible = session.interaction_system._ok_btn_on() and not session.get_tree().paused
	session.detail_btn.text = "간단히" if session.tip_detail else "자세히"
	session.field_overlay_system._place_apply_btn()
	for c in [session.hint, session.skip_badge, session.hide_btn]:
		c.self_modulate.a = 0.12 if Engine.get_process_frames() - session.tip_fade.get(c, -10) <= 2 else 1.0
	if session.touch_ui and key_t <= 0.0:
		key_t = 0.2
		session.ui_layout_system._strip_key_hints()
	var us := Time.get_ticks_usec() if session.prof_on else 0
	if session.new_armed > 0.0:
		session.new_armed -= delta
		if session.new_armed <= 0.0:
			session.new_btn.text = "새로 시작"
	session.toast_timer -= delta
	session.toast.visible = session.toast_timer > 0.0
	session.onboarding_system._tut_tick()
	if session.guide_t > 0.0 and not session.get_tree().paused:
		session.guide_t -= delta
		if session.guide_t <= 0.0:
			session.guide_lines.clear()
			session.guide_t = 0.0
	session.guide_label.visible = Meta.guide_on and not session.guide_lines.is_empty() and not session.title_label.visible and session.phase != BinduSession.Phase.GAMEOVER and not session.get_tree().paused and not session.help_label.visible and not session.settings_panel.visible and not session.records_panel.visible and not session.notes_panel.visible and not session.modes_panel.visible and not session.codex_panel.visible and not session.vote_panel.visible and session.skill_arm == ""  # 기술 조준 중엔 위 가운데 조준 안내만 (글이 겹겹이 쌓였다)
	if not session.guide_label.visible:
		session.guide_more.visible = false  # 안내가 꺼졌는데 [더 알아보기]만 남던 것
	# 글자를 키운(설정) 좁은 화면에서 펼친 버튼 줄이 왼쪽 아래 안내 글에 닿으면 안내 글을 버튼 줄 앞까지로 줄인다.
	# 줄이 늘면 위로 자라고, 다음 웨이브 미리보기는 그 위에 붙는다
	var hw := 590.0
	if session.pause_btn.visible:
		hw = clampf(session.bar_box.get_rect().position.x - session.hint.position.x - 12.0, 240.0, 590.0)
	# 아래 가운데 버튼([웨이브 시작]·[취소]·[자세히]·[적용])에도 닿지 않게 (글이 길면 버튼 밑으로 지나갔다)
	var hb := session.hint.get_rect().end.y
	for b: Control in [session.start_btn, session.cancel_btn, session.detail_btn, session.aim_ok_btn, session.skip_badge]:
		if b != null and b.visible:
			var br := b.get_rect()
			if br.end.y > hb - 70.0 and br.position.x > session.hint.position.x + 120.0:
				hw = minf(hw, maxf(240.0, br.position.x - session.hint.position.x - 12.0))
	if not is_equal_approx(session.hint.size.x, hw):
		session.hint.size.x = hw
	if session.hint.text != _hint_kept:
		session.hint.text = session.patchlog_system._kr_keep(session.hint.text)  # 줄이 접힐 때 한글 낱말 중간("방향 바/꾸기")에서 끊기지 않게
		_hint_kept = session.hint.text
	session.toast.position.y = maxf(100.0, session.hud.position.y + session.hud.size.y + 36.0)  # 점수 줄이 길어져도 보스 체력 막대 아래
	if session.tplay != null:
		session.toast.position.y = maxf(session.toast.position.y, session.tplay.panel_bottom() + 8.0)  # 연습 판 안내 칸 아래
	# 안내·큰 글자도 점수 줄이 길어지거나 글자를 키우면(설정) 그 아래로 밀어 겹치지 않게
	session.guide_label.position.y = maxf(8.0, session.hud.get_rect().end.y + 8.0)
	if session.tplay != null:
		session.guide_label.position.y = maxf(session.guide_label.position.y, session.tplay.panel_bottom() + 8.0)
	session.ui_layout_system._beside_legend(session.guide_label, 0.0)
	session.onboarding_system._update_action_guide()
	if session.guide_label.visible:
		session.toast.position.y = maxf(session.toast.position.y, session.guide_more.get_rect().end.y + 8.0)
	# 왼쪽 위 DPS 표를 펼쳐 두면 알림이 표 위에 겹치던 것 (글자 115% 이상·표가 길 때): 표와 오른쪽 설명 사이에 두고,
	# 글이 그 폭보다 길면 두 줄로 접는다 (예전엔 표 아래로 내려 카드 줄 밑에 깔렸다: 봉인·이벤트 알림)
	if session.toast.visible:
		var left := 8.0
		var right := session.ui_layout_system._right_panel_x() - 8.0
		if session.dps_panel.visible and session.dps_panel.get_rect().end.y > session.toast.position.y:
			left = session.dps_panel.get_rect().end.x + 8.0
		var avail := maxf(240.0, right - left)
		var tw := session.ui_font.get_string_size(session.toast.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 12.0
		var wrap := tw > avail
		session.toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		session.hud_system._font_size(session.toast, 18 if wrap else 22)  # 접을 때는 조금 작게 (세 줄로 전장 가운데를 덮지 않게)
		var w := minf(maxf(tw, 600.0), avail)
		if not is_equal_approx(session.toast.size.x, w):
			session.toast.size = Vector2(w, 0.0)
		session.toast.position.x = clampf((session.ui_root.size.x - w) / 2.0, left, maxf(left, right - w))
	session.banner.position.y = maxf(session.ui_root.size.y / 2.0 - 140.0, session.hud.position.y + session.hud.size.y + 12.0)
	if session.toast.visible and session.toast.text != "":
		session.banner.position.y = maxf(session.banner.position.y, session.toast.get_rect().end.y + 4.0)  # 점수 줄이 세 줄일 때 알림과 겹치던 것
	if session.guide_more.visible:
		session.banner.position.y = maxf(session.banner.position.y, session.guide_more.get_rect().end.y + 4.0)  # [더 알아보기]가 "특성 선택" 큰 글 위에 걸치던 것
	var ban_w := session.ui_root.size.x
	var ban_full := session.ui_font.get_string_size(session.banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	if ban_w / 2.0 + minf(ban_full, 800.0) / 2.0 > session.ui_layout_system._right_panel_x() - 8.0:
		ban_w = minf(ban_w, session.ui_layout_system._right_panel_x() - 8.0)  # 긴 큰 글이 오른쪽 설명 위로 넘치던 것 (폰 "웨이브 3개 넘기기")
	session.banner.size.x = minf(800.0, ban_w - 16.0)
	session.banner.position.x = (ban_w - session.banner.size.x) / 2.0
	session.banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if session.ui_font.get_string_size(session.banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x > session.banner.size.x else TextServer.AUTOWRAP_OFF
	if session.choice_box.visible and not session.cards_hidden and session.choice_box.get_child_count() > 0:
		# 카드가 떠 있으면 "웨이브 N" 큰 글이 카드 윗변에 걸치지 않게 그 위로
		session.banner.position.y = maxf(minf(session.banner.position.y, session.choice_box.get_rect().position.y - session.banner.size.y - 4.0), session.hud.position.y + session.hud.size.y + 12.0)
	session.banner_t -= delta
	if session.banner_t <= 0.0 and not session.banner_queue.is_empty():
		var nb: Array = session.banner_queue.pop_front()
		session.hud_system.big_banner(nb[0], nb[1])
	session.banner.visible = session.banner_t > 0.0
	session.banner.modulate.a = clampf(session.banner_t / 0.4, 0.0, 1.0)
	session.legend.visible = session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.PLACE, BinduSession.Phase.AIM, BinduSession.Phase.MOVE, BinduSession.Phase.READY] and not session.title_label.visible
	session.range_btn.visible = session.touch_ui and not session.title_label.visible and session.phase != BinduSession.Phase.GAMEOVER
	session.zoom_btn.visible = not is_equal_approx(session.view_zoom, 1.0) and not session.title_label.visible
	session.zoom_btn.text = "확대 풀기 x%.1f" % session.view_zoom
	session.range_btn.text = "범위 끄기" if session.range_all else "범위 보기"
	session.legend.visible = session.legend.visible and not session.legend_hidden
	if session.legend.visible:
		# 설명 아래끝이 오른쪽 아래 설정 버튼(없으면 화면 끝)에 닿으면 반응 줄을 줄인다
		var lim := minf(session.bar_btn.get_global_rect().position.y if session.bar_btn.visible else 1e9, session.get_viewport_rect().size.y) - 8.0
		var over_px := session.legend.get_global_rect().end.y - lim
		if over_px > 0.0 and session.legend_rows > 0:
			var lh := session.legend.get_line_height() * session.ui_root.scale.y
			session.legend_rx_rows = maxi(session.legend_rows - maxi(1, floori(over_px / (lh * 2.0))), 0)  # 반응 한 줄이 접혀 두 줄일 수 있어 덜 줄이고 다음 프레임에 더
			session.menu_system._refresh_legend()
	# 시작 화면 위에 설정·기록·도움말·패치노트 창을 열면 뒤 메뉴는 숨긴다 (흐리게만 하면 창 아래로 삐져나온 버튼 줄이 겹쳐 보이고 눌리던 것)
	if session.help_label.visible and not session.help_scroll.visible:
		session.help_scroll.scroll_vertical = 0  # 열 때마다 맨 위부터
		if session.help_touch != session.touch_ui:  # 터치면 조작 안내를 버튼·누르기로
			session.help_touch = session.touch_ui
			session.help_label.text = session.patchlog_system._kr_keep(session.run_flow_system._help_text())
	session.help_scroll.visible = session.help_label.visible
	if session.help_scroll.visible:
		var hw2 := minf(1040.0, session.ui_root.size.x - 40.0)  # 글자를 키우면 화면 폭보다 넓어지던 것
		session.help_scroll.offset_left = -hw2 / 2.0
		session.help_scroll.offset_right = hw2 / 2.0
		session.help_label.custom_minimum_size.x = hw2 - 36.0 - 12.0  # 안쪽 여백 + 굴림 막대
		var hh := minf(session.help_label.get_combined_minimum_size().y + 36.0, session.ui_root.size.y - 100.0)
		session.help_scroll.offset_top = -hh / 2.0
		session.help_scroll.offset_bottom = hh / 2.0
	session.title_box.visible = not (session.tut.visible or session.settings_panel.visible or session.records_panel.visible or session.help_label.visible or session.notes_panel.visible or session.modes_panel.visible or session.codex_panel.visible or session.vote_panel.visible or session.mp_panel.visible)
	session.prep_back.visible = session.prep and session.title_box.visible  # 준비 화면에서 모드 창 등을 열면 [뒤로]도 숨김
	# 투표 버튼: 투표 API가 있는 서버(boot의 vote)에 닿았을 때만. 판 끝난 화면 버튼은 남은 글 바로 아래
	if session.vote_btn:
		session.vote_btn.visible = Net.vote_ok()
	session.vote_over_btn.visible = session.over_label.visible and session.phase == BinduSession.Phase.GAMEOVER and session.mp_mode == "" and Net.vote_ok() and not session.vote_panel.visible
	# 보상형 광고가 결과 화면이 뜬 뒤에 준비되면 [한 번 더] 버튼 줄을 다시 맞춘다
	if session.run_flow_system.over_buttons() and session.over_revive_btn.visible != (session.run_flow_system.over_data.get("revive", false) and Ads.rewarded_ready()):
		session.over_card.queue_redraw()
	if session.vote_over_btn.visible:
		var lh := session.over_label.get_line_count() * session.over_label.get_line_height() if session.over_label.text != "" else 0
		session.vote_over_btn.position = Vector2(session.over_label.position.x + (session.over_label.size.x - session.vote_over_btn.size.x) / 2.0, session.over_label.position.y + lh + (90.0 if session.run_flow_system.over_buttons() else 34.0))  # 바탕 끝 나가는 법 줄(광고가 되는 폰은 버튼 줄) 아래
	session.hud.visible = not session.title_label.visible  # 시작 화면엔 메뉴에 최고 기록이 따로 있다
	# 시작 화면에서 일시정지·배속 버튼을 누르면 메뉴 위에 일시정지 창이 뜨던 문제
	# 게임 중엔 펼쳤을 때만 보인다 (단축키 M·P·Space는 접어도 된다). 시작 화면엔 소리·자동 시작만
	var in_game := not session.title_label.visible
	session.bar_btn.visible = in_game
	# 펼쳤을 땐 좁은 ▶만 (버튼 줄이 왼쪽 아래 안내 문구까지 뻗지 않게)
	session.bar_btn.text = "▶" if session.bar_open else "◀ 설정"
	session.bar_btn.custom_minimum_size.x = 40.0 if session.bar_open else 96.0
	session.bar_btn.tooltip_text = "설정 버튼 접기" if session.bar_open else "소리·자동 시작·일시정지·배속 버튼 펼치기"
	session.mute_btn.visible = not in_game or session.bar_open
	session.auto_btn.visible = not in_game or session.bar_open
	session.pause_btn.visible = in_game and session.bar_open
	session.speed_group.visible = in_game and session.bar_open
	session.speed_btn.visible = in_game and session.bar_open
	session.speed_pick.visible = in_game and session.bar_open
	session.fx_pick.visible = in_game and session.bar_open
	session.hud_cool -= delta
	session.hud_system._update_hud()
	# 일시정지 위에 설정·도움말 등을 열면 일시정지 글·버튼은 잠깐 숨기고, 어둠은 남겨 창이 그 위에 뜬다 (창 z 22 > 어둠 20)
	var over := session.settings_panel.visible or session.help_label.visible or session.records_panel.visible or session.notes_panel.visible or session.codex_panel.visible or session.vote_panel.visible
	var dim := session.get_tree().paused and not session.title_label.visible and session.phase != BinduSession.Phase.GAMEOVER
	var show_pause := dim and not over and not session.tut_paused  # 튜토리얼이 멈춘 것은 일시정지 창 없이
	session.paused_label.visible = show_pause
	session.pause_box.visible = show_pause
	session.pause_dim.visible = dim
	# 카드 선택 중: 카드 밖은 검은 막 (닫히면 곧바로 걷는다). 카드를 내리면(필드 보기) 막도 걷는다
	session.card_dim.visible = session.interaction_system._card_dim_on()
	session.interaction_system._update_place_dim()
	# 일시정지 창 버튼이 어둠 밑 카드 글 위에 겹쳐 읽기 힘들던 것 (폰·글자 130%): 멈춘 동안 카드 줄은 더 옅게
	session.choice_box.modulate.a = 0.25 if dim else 1.0
	if session.pause_box.visible:
		# 글자를 키우면(설정) 가운데 기준 자리가 점수 줄에 닿는다: 점수 줄 아래로
		session.paused_label.position.y = maxf(session.ui_root.size.y / 2.0 - 248.0, session.hud.get_rect().end.y + 8.0 if session.hud.visible else 8.0)
		session.pause_box.position.y = session.paused_label.position.y + session.paused_label.size.y + 10.0
		session.pause_box.size.x = 0.0  # 버튼 수(튜토리얼·끄기)만큼 넓어져도 가운데
		session.pause_box.position.x = floorf((session.ui_root.size.x - session.pause_box.get_combined_minimum_size().x) / 2.0)
	if session.vote_panel.visible:
		# 넓은 화면(폰 가로·와이드)에서는 투표 창을 넓혀 카드 설명이 덜 잘리게 (860 고정이라 설명 끝이 … 로 많이 잘렸다)
		var vh := clampf((session.ui_root.size.x - 48.0) / 2.0, 430.0, 580.0)
		session.vote_panel.offset_left = -vh
		session.vote_panel.offset_right = vh
	session.hud_system._fit_panels()
	session.hud_system._refresh_dps()
	session.field_view_system._soften_fx()
	session.queue_redraw()
	var isig := session.field_overlay_system._info_sig()
	if isig != session.field_overlay_system.info_sig:
		session.field_overlay_system.info_sig = isig.duplicate(true)
		session.info.queue_redraw()
	if session.phase == BinduSession.Phase.MOVE and session.interaction_system.moving and not session.get_tree().paused:
		session.interaction_system.moving.position = session.interaction_system._pointer_world().clamp(session.combat_system.field_rect().position, session.combat_system.field_rect().end)
	session.interaction_system._update_press()
	if session.interaction_system.boxing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		session.interaction_system._finish_box()  # 창 밖에서 손을 떼 놓기 이벤트를 못 받은 경우
	session.card_detail_btn.visible = session.phase == BinduSession.Phase.CHOOSE and not session.title_label.visible and session.coin_stage == 0 and not session.cards_hidden and not session.perk_mode
	session.run_flow_system._update_skip_ui()
	session.cancel_btn.visible = session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.AIM, BinduSession.Phase.MOVE] and not session.title_label.visible and not session.get_tree().paused
	if session.speed_btn.visible and session.speed_btn.get_meta("fast", false) != (session.game_speed > 1.0):
		session.speed_btn.set_meta("fast", session.game_speed > 1.0)
		session.speed_btn.queue_redraw()
	session.field_overlay_system._update_choice_header()
	if not session.card_dock.active():
		_legacy_card_layout()
	session.abilities_system._skill_ui()
	session.card_dock.tick()
	session.restart_armed = maxf(session.restart_armed - delta, 0.0)
	session.end_armed = maxf(session.end_armed - delta, 0.0)
	if not session.get_tree().paused and not session.title_label.visible and session.phase != BinduSession.Phase.GAMEOVER:
		session.run_real += delta
	if session.get_tree().paused:
		session.fx_layer.queue_redraw()  # 멈춘 동안에도 오브젝트·구체 정보창은 마우스를 따라간다
		return
	# 도움말·설정 창을 보는 동안은 게임이 멈춘다 (읽는 사이 구체가 중앙에 닿거나 웨이브가 시작되지 않게)
	var reading := (session.help_label.visible or session.settings_panel.visible or session.records_panel.visible or session.notes_panel.visible) and not session.title_label.visible
	if session.countdown >= 0.0 and session.phase == BinduSession.Phase.READY:
		# 오브젝트를 끌거나 상자로 고르는 동안은 자동 시작을 멈춘다 (시작하면 끌던 것이 되돌아감)
		if session.interaction_system.press_t or session.interaction_system.boxing or reading:
			session.countdown = maxf(session.countdown, 1.0)
		else:
			session.countdown -= delta
		session.start_btn.text = session.ui_layout_system._kh("%.1f초 뒤 시작 (Space: 바로)" % maxf(session.countdown, 0.0))
		if session.countdown <= 0.0:
			session.run_flow_system._start_wave()
	if reading:

		return
	session.combat_system._update_fx(delta)
	if session.phase != BinduSession.Phase.WAVE:
		for t in session.towers.get_children():
			t.fade_fx(delta)
		return
	if session.prof_on:
		session.combat_system._prof_add("UI·효과", us)
	# 배속: 한 프레임을 1배속 크기의 조각으로 나눠 여러 번 계산한다.
	# 공격 주기·충돌이 배속과 상관없이 1배속과 같게 나온다.
	var steps := ceili(session.game_speed)
	# 프레임이 한 번 크게 끊겨도(창 끌기·버벅임) 한 조각이 1/20초를 넘지 않게: 구체가 지뢰·벽을 건너뛰지 않는다
	var dt := minf(delta, 0.05) * session.game_speed / steps
	for i in steps:
		session.combat_system._sim_step(dt)
		if session.phase != BinduSession.Phase.WAVE:
			break


func _legacy_card_layout() -> void:
	var session: BinduSession = self.session
	# 카드 줄은 오른쪽 설명을 피해 왼쪽으로 비켜 있다. 설명을 숨기면 가운데로, 버튼도 카드 가운데에 맞춘다
	var cx := 0.0 if session.legend_hidden else -75.0
	# 카드 4장이 오른쪽 설명 밑으로 들어가면(글자 크게) 쉬는 시간 동안 설명을 접고 가운데로
	if session.legend.visible and session.phase == BinduSession.Phase.CHOOSE and session.choice_box.get_child_count() > 3 and session.ui_root.size.x / 2.0 + cx + 365.0 > session.legend.position.x - 8.0:
		session.legend.visible = false
		cx = 0.0
	# 글자를 키우면(설정) 카드 줄 오른쪽이 설명 밑으로 들어가던 것: 설명 왼쪽까지 들어가게 왼쪽으로 옮기고, 모자라면 줄인다
	var room := (session.legend.get_rect().position.x - 8.0) if session.legend.visible else session.ui_root.size.x - 8.0
	var half := maxf(365.0, session.choice_box.get_combined_minimum_size().x / 2.0)  # 카드 4장은 730보다 넓다
	var kw := minf((room - 8.0) / (half * 2.0), 1.0)
	# 새로고침·내리기 버튼은 카드 바로 아래 한 줄에 (카드가 길어지면 버튼이 카드 글을 덮던 것).
	# 카드+버튼 줄이 왼쪽 아래 안내 글에 닿으면 카드 줄을 위로 올리고, 그래도 모자라면(글자 크게) 0.7배까지 줄인다
	var mid := session.ui_root.size.y / 2.0
	var ch := session.choice_box.get_combined_minimum_size().y
	var lim := session.ui_layout_system._bottom_free() - 6.0
	var floor_y := (session.hud.position.y + session.hud.size.y + 8.0) if session.hud.visible else 8.0
	if session.dps_panel.visible and session.ui_root.size.x / 2.0 + cx - 365.0 < 320.0:
		floor_y += 44.0 + 48.0 + 6.0  # 왼쪽 위 DPS 표(머리 + 2줄, 나머지는 굴려 봄)를 덮지 않게
	if session.guide_label.visible:
		floor_y = maxf(floor_y, (session.guide_more.get_rect().end.y if session.guide_more.visible else session.guide_label.get_rect().end.y) + 26.0)  # 처음 안내 글이 카드 글 뒤로 겹치던 것 (고르기 꼬리표 자리 포함)
	var need := ch + 8.0 + 40.0
	var k := clampf(minf((lim - floor_y) / need, kw), minf(0.7, kw), 1.0)
	cx = minf(cx, room - half * k - session.ui_root.size.x / 2.0)
	cx = maxf(cx, 8.0 + half * k - session.ui_root.size.x / 2.0)
	session.choice_box.offset_left = cx - half
	session.choice_box.offset_right = cx + half
	var ctop := maxf(minf(mid - 90.0, lim - need * k), floor_y)
	session.choice_box.pivot_offset = Vector2(session.choice_box.size.x / 2.0, 0.0)
	session.choice_box.scale = Vector2(k, k)
	session.choice_box.offset_top = ctop - mid
	session.choice_box.offset_bottom = session.choice_box.offset_top + ch
	var by := session.choice_box.offset_top + ch * k + 8.0
	# 카드 밑 한 줄 그림 버튼: [새로고침 N] [필드 보기] [넘기기] [×N]. 없는 버튼 자리는 당겨 가운데 맞춘다
	var row: Array = []
	for bt in [session.reroll_btn, session.card_detail_btn, session.skip_btn, session.skip_n_btn, session.apply_btn]:
		if bt.visible:
			row.append(bt)
	var bw := {session.reroll_btn: 96.0, session.card_detail_btn: 104.0, session.hide_btn: 76.0, session.skip_btn: 76.0, session.skip_n_btn: 76.0}
	if session.apply_btn.visible:
		bw = {session.reroll_btn: 76.0, session.card_detail_btn: 88.0, session.hide_btn: 60.0, session.skip_btn: 60.0, session.skip_n_btn: 60.0}
		bw[session.apply_btn] = maxf(120.0, session.ui_font.get_string_size(session.apply_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 50.0)
	var rw := -10.0
	for bt in row:
		rw += bw[bt] + 10.0
	var bx := cx - rw / 2.0
	for bt in row:
		bt.offset_left = bx
		bt.offset_right = bx + bw[bt]
		bt.offset_top = by
		bt.offset_bottom = by + 40.0
		bx += bw[bt] + 10.0
	if session.phase == BinduSession.Phase.READY and session.skip_btn.visible:
		# 웨이브 시작 대기: [웨이브 시작] 바로 오른쪽에 [넘기기] [×N]
		var pw: Vector2 = session.skip_btn.get_parent().size
		var sx := session.start_btn.position.x + session.start_btn.size.x + 10.0 - pw.x / 2.0
		var sy := session.start_btn.position.y + (session.start_btn.size.y - 40.0) / 2.0 - pw.y / 2.0
		for bt in [session.skip_btn, session.skip_n_btn]:
			bt.offset_left = sx
			bt.offset_right = sx + 76.0
			bt.offset_top = sy
			bt.offset_bottom = sy + 40.0
			sx += 86.0
	session.cards_system._start_btn_layout()
