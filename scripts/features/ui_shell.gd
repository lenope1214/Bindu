class_name BinduUiShell
extends BinduFeature
## UI 노드 생성과 이벤트 연결. 예약 콜백은 main의 순서를 따른다.

func _build_ui() -> void:
	var session: BinduSession = self.session
	var layer := CanvasLayer.new()
	session.add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Malgun Gothic", "sans-serif"])
	theme.default_font = font
	session.ui_font = font
	theme.default_font_size = 18
	root.theme = theme
	layer.add_child(root)
	session.ui_root = root
	session.card_dock = CardDock.new(session)
	session.get_viewport().size_changed.connect(session.hud_system._apply_ui_scale)

	session.hud = Control.new()
	session.hud.position = Vector2(10, 6)
	session.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 칩 말풍선은 _draw_info가 마우스 자리로 띄운다 (필드 누르기를 막지 않게)
	session.hud.draw.connect(session.hud_system._draw_hud)
	root.add_child(session.hud)

	session.hint = Label.new()
	session.hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	session.hint.position = Vector2(16, -66)
	session.hint.size = Vector2(590, 44)  # 오른쪽 아래 설정 버튼 줄(펼쳤을 때 648)과 겹치지 않게
	session.hint.grow_vertical = Control.GROW_DIRECTION_BEGIN  # 줄이 늘면 위로 (아래는 버전 표시)
	session.hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	session.hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session.hint.add_theme_font_size_override("font_size", 15)
	root.add_child(session.hint)

	session.ver_label = Label.new()
	session.ver_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	session.ver_label.position = Vector2(16, -22)
	session.ver_label.size = Vector2(400, 18)
	session.ver_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.ver_label.add_theme_font_size_override("font_size", 12)
	session.ver_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	session.ver_label.text = session.run_flow_system._ver_text()
	root.add_child(session.ver_label)

	session.toast = Label.new()
	session.toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	session.toast.position = Vector2(-300, 100)  # 점수 줄·보스 체력 막대 아래
	session.toast.size = Vector2(600, 30)
	session.toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	session.toast.add_theme_font_size_override("font_size", 22)
	session.toast.add_theme_color_override("font_outline_color", Color.BLACK)
	session.toast.add_theme_constant_override("outline_size", 5)
	root.add_child(session.toast)

	session.guide_label = Label.new()
	session.guide_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# 토스트 아래, 선택지 카드 위. 오른쪽 설명(x 950~)과 겹치지 않게 폭 600
	session.guide_label.position = Vector2(-300, 140)
	session.guide_label.size = Vector2(600, 0)
	session.guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.guide_label.add_theme_font_size_override("font_size", 16)
	session.guide_label.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.08, 0.07, 0.04, 0.9)
	gsb.border_color = Color(1, 0.82, 0.4, 0.7)
	gsb.set_border_width_all(1)
	gsb.set_corner_radius_all(6)
	gsb.set_content_margin_all(10)
	session.guide_label.add_theme_stylebox_override("normal", gsb)
	session.guide_label.visible = false
	root.add_child(session.guide_label)
	session.guide_more = Button.new()
	session.guide_more.text = "더 알아보기"
	session.guide_more.focus_mode = Control.FOCUS_NONE
	session.guide_more.z_index = 2
	session.guide_more.custom_minimum_size = Vector2(130, 32)
	# 안내 말풍선과 같은 노란 테두리 버튼: 예전엔 테두리 없는 글처럼 보여 누를 수 있는지 몰랐다
	for st in ["normal", "hover", "pressed"]:
		var mb := StyleBoxFlat.new()
		mb.bg_color = Color(0.08, 0.07, 0.04, 0.9) if st == "normal" else Color(0.18, 0.15, 0.07, 0.95)
		mb.border_color = Color(1, 0.82, 0.4, 0.7)
		mb.set_border_width_all(1)
		mb.set_corner_radius_all(6)
		mb.set_content_margin_all(6)
		session.guide_more.add_theme_stylebox_override(st, mb)
	session.guide_more.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	session.guide_more.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	session.guide_more.text = "더 알아보기 ›"
	session.guide_more.visible = false
	session.guide_more.pressed.connect(session.onboarding_system._open_guide_details)
	root.add_child(session.guide_more)

	# 카드 선택 중 전장·점수 줄·설명을 어둡게 (카드·카드 줄 버튼·알림·안내는 z 2로 그 위). 마우스는 통과
	session.card_dim = ColorRect.new()
	session.card_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	session.card_dim.color = Color(0, 0, 0, BinduSession.CARD_DIM_A)
	session.card_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.card_dim.z_index = 1
	session.card_dim.visible = false
	root.add_child(session.card_dim)
	session.toast.z_index = 2
	session.guide_label.z_index = 2

	session.choice_box = HBoxContainer.new()
	session.choice_box.z_index = 2
	session.choice_box.set_anchors_preset(Control.PRESET_CENTER)
	session.choice_box.position = Vector2(-440, -90)
	session.choice_box.size = Vector2(730, 180)
	session.choice_box.add_theme_constant_override("separation", 20)
	session.choice_box.alignment = BoxContainer.ALIGNMENT_CENTER  # 카드가 2장일 때도 가운데
	root.add_child(session.choice_box)
	session.choice_header = PanelContainer.new()
	session.choice_header.z_index = 2
	session.choice_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.choice_header.visible = false
	var chs := CardDock.surface()
	chs.content_margin_left = 14
	chs.content_margin_right = 14
	chs.content_margin_top = 6
	chs.content_margin_bottom = 6
	session.choice_header.add_theme_stylebox_override("panel", chs)
	var chr := HBoxContainer.new()
	chr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chr.add_theme_constant_override("separation", 20)
	session.choice_header.add_child(chr)
	var cht := Label.new()
	cht.text = "카드 선택"
	cht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cht.add_theme_font_size_override("font_size", 16)
	cht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chr.add_child(cht)
	session.choice_remaining = Label.new()
	session.choice_remaining.add_theme_font_size_override("font_size", 16)
	session.choice_remaining.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	session.choice_remaining.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chr.add_child(session.choice_remaining)
	root.add_child(session.choice_header)

	session.legend = Label.new()
	session.legend.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	session.legend.position = Vector2(-330, 48)
	session.legend.size = Vector2(320, 380)
	# 터치 화면용 Alt: 누를 때마다 모든 오브젝트 범위·피해 몫 보기 켜기·끄기 (터치를 한 번 쓰면 나타남)
	session.range_btn = Button.new()
	session.range_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	session.range_btn.position = Vector2(-280, 10)
	session.range_btn.size = Vector2(112, 30)
	session.range_btn.focus_mode = Control.FOCUS_NONE
	session.range_btn.add_theme_font_size_override("font_size", 14)
	session.range_btn.pressed.connect(func(): session.range_all = not session.range_all)
	session.range_btn.visible = false
	root.add_child(session.range_btn)
	# 확대했을 때만: 1배로 돌아가기
	session.zoom_btn = Button.new()
	session.zoom_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	session.zoom_btn.position = Vector2(-400, 10)
	session.zoom_btn.size = Vector2(112, 30)
	session.zoom_btn.focus_mode = Control.FOCUS_NONE
	session.zoom_btn.add_theme_font_size_override("font_size", 14)
	session.zoom_btn.pressed.connect(session.viewport_system._reset_zoom)
	session.zoom_btn.visible = false
	root.add_child(session.zoom_btn)
	session.legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 긴 줄이 화면 밖으로 잘리지 않게
	session.legend.add_theme_font_size_override("font_size", 14)
	# 옅은 바탕: 지나가는 구체 위에서도, 글자를 키워(설정) 카드와 겹칠 때도 읽히게
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.02, 0.03, 0.05, 0.85)
	lsb.set_corner_radius_all(5)
	lsb.set_content_margin_all(8)
	session.legend.add_theme_stylebox_override("normal", lsb)
	session.legend.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	lsb.content_margin_left = 32.0
	session.legend.draw.connect(session.menu_system._draw_legend_icons)
	session.menu_system._refresh_legend()
	root.add_child(session.legend)

	session.reroll_btn = Button.new()
	session.reroll_btn.text = "1"
	session.cards_system._icon_btn(session.reroll_btn, func(): return ["reroll", Color(0.6, 0.85, 1.0)])
	session.cards_system._keycap(session.reroll_btn, "Q")
	session.reroll_btn.set_anchors_preset(Control.PRESET_CENTER)
	session.reroll_btn.position = Vector2(-170, 105)
	session.reroll_btn.size = Vector2(340, 36)
	session.reroll_btn.pressed.connect(session.cards_system._on_reroll)
	session.reroll_btn.visible = false
	session.reroll_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(session.reroll_btn)

	session.apply_btn = Button.new()
	session.apply_btn.text = "적용"
	session.apply_btn.set_anchors_preset(Control.PRESET_CENTER)
	session.apply_btn.focus_mode = Control.FOCUS_NONE
	session.apply_btn.draw.connect(session.field_overlay_system._draw_apply_icon)
	session.apply_btn.add_theme_font_size_override("font_size", 17)
	# 선택 조작 줄의 기본 동작을 금색으로 강조
	for st in ["normal", "hover", "pressed"]:
		var asb := StyleBoxFlat.new()
		asb.bg_color = Color(1.0, 0.82, 0.4) if st == "normal" else Color(1.0, 0.9, 0.6)
		asb.set_corner_radius_all(6)
		asb.content_margin_left = 38
		asb.content_margin_right = 12
		session.apply_btn.add_theme_stylebox_override(st, asb)
	for fc in ["font_color", "font_hover_color", "font_pressed_color"]:
		session.apply_btn.add_theme_color_override(fc, Color(0.12, 0.09, 0.02))
	session.apply_btn.pressed.connect(func():
		if session.tap_sel >= 0 and session.tap_sel < session.offer.size():
			session.cards_system._on_pick(session.offer[session.tap_sel]))
	session.apply_btn.visible = false
	session.apply_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(session.apply_btn)

	session.skip_btn = Button.new()
	session.skip_btn.set_anchors_preset(Control.PRESET_CENTER)
	session.skip_btn.tooltip_text = "카드 선택을 미루고 웨이브를 연달아 진행합니다. 미룬 카드·새로고침·특성은 멈춘 뒤 한꺼번에 고릅니다\n중앙이 위험해지면(설정) 그 웨이브가 끝나고 멈춥니다"
	session.skip_btn.pressed.connect(session.run_flow_system._on_skip)
	session.cards_system._icon_btn(session.skip_btn, func(): return ["skip", Color(0.75, 0.9, 1.0)])
	session.cards_system._keycap(session.skip_btn, "S")
	session.skip_btn.visible = false
	session.skip_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(session.skip_btn)
	session.skip_n_btn = Button.new()
	session.skip_n_btn.set_anchors_preset(Control.PRESET_CENTER)
	session.skip_n_btn.tooltip_text = "넘길 웨이브 수 바꾸기 (1·3·5·10)"
	session.skip_n_btn.pressed.connect(session.run_flow_system._cycle_skip_n)
	session.skip_n_btn.visible = false
	session.skip_n_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(session.skip_n_btn)
	session.skip_badge = Button.new()
	session.skip_badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	session.skip_badge.position = Vector2(-210, -146)  # 웨이브 시작 버튼 위
	session.skip_badge.size = Vector2(420, 36)
	session.skip_badge.add_theme_color_override("font_color", Color(0.75, 0.9, 1))
	session.skip_badge.pressed.connect(session.run_flow_system._toggle_skip_stop)
	session.skip_badge.visible = false
	root.add_child(session.skip_badge)

	session.hide_btn = session.card_dock.focus_btn  # V·F·화면 버튼이 같은 컨트롤을 사용한다.
	session.card_detail_btn = Button.new()
	session.card_detail_btn.set_anchors_preset(Control.PRESET_CENTER)
	session.card_detail_btn.focus_mode = Control.FOCUS_NONE
	session.card_detail_btn.add_theme_font_size_override("font_size", 14)
	session.card_detail_btn.text = "자세히"
	session.card_detail_btn.toggle_mode = true
	session.card_detail_btn.button_pressed = Meta.card_detail
	session.card_detail_btn.tooltip_text = "카드 설명 자세히 (Z): 켜면 설명 전체, 카드에 올리면(터치는 한 번 누르면) 위에 모든 내용"
	session.card_detail_btn.toggled.connect(session.cards_system._set_card_detail)
	session.cards_system._icon_btn(session.card_detail_btn, func(): return ["help", Color(1, 0.88, 0.5) if Meta.card_detail else Color(1, 1, 1, 0.7)])
	session.cards_system._keycap(session.card_detail_btn, "Z")
	session.card_detail_btn.visible = false
	session.card_detail_btn.z_index = 2  # 카드 선택 막(card_dim) 위
	root.add_child(session.card_detail_btn)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# 버튼이 늘어나도 오른쪽 여백(16)을 지키고 왼쪽으로 자란다
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.offset_left = -616.0
	bar.offset_right = -12.0
	bar.offset_top = -48.0
	bar.offset_bottom = -12.0
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	session.bar_box = bar
	bar.theme = session.card_dock.controls_theme
	# 글 대신 아이콘 (이름·단축키는 올리면 말풍선)
	session.fx_pick = OptionButton.new()
	for i in BinduSession.FX_DPS.size():
		session.fx_pick.add_item("효과 %d%%" % roundi(maxf(0.15, 1.0 - BinduSession.FX_DPS[i]) * 100))
	session.fx_pick.select(Meta.fx_dps)
	session.fx_pick.custom_minimum_size = Vector2(104, 36)
	session.fx_pick.focus_mode = Control.FOCUS_NONE
	session.fx_pick.tooltip_text = "피해를 적게 주는 오브젝트의 탄·장판 진하기\n(가장 센 오브젝트와 비교해 약할수록 이 값까지 옅어짐. 센 오브젝트는 그대로)"
	session.fx_pick.item_selected.connect(func(i):
		Meta.fx_dps = i
		session.progression_system._save_best())
	bar.add_child(session.fx_pick)
	session.mute_btn = Button.new()
	session.mute_btn.custom_minimum_size = Vector2(44, 36)
	session.mute_btn.pressed.connect(session.cards_system._toggle_mute)
	session.mute_btn.pressed.connect(session.cards_system._icon_toast.bind(session.mute_btn))
	session.cards_system._icon_btn(session.mute_btn, func(): return ["mute" if session.sfx.muted else "sound", Color(1, 1, 1, 0.9)])
	bar.add_child(session.mute_btn)
	session.auto_btn = Button.new()
	session.auto_btn.custom_minimum_size = Vector2(44, 36)
	session.auto_btn.pressed.connect(session.cards_system._toggle_auto)
	session.auto_btn.pressed.connect(session.cards_system._icon_toast.bind(session.auto_btn))
	session.cards_system._icon_btn(session.auto_btn, func(): return ["auto", Color(0.5, 0.9, 0.6) if session.auto_start else Color(1, 1, 1, 0.35)])
	bar.add_child(session.auto_btn)
	session.pause_btn = Button.new()
	session.pause_btn.tooltip_text = "일시정지 (P)"
	session.pause_btn.custom_minimum_size = Vector2(44, 36)
	session.pause_btn.pressed.connect(session.run_flow_system._toggle_pause)
	session.cards_system._icon_btn(session.pause_btn, func(): return ["pause", Color(1, 1, 1, 0.9)])
	bar.add_child(session.pause_btn)
	session.speed_group = HBoxContainer.new()
	session.speed_group.name = "SpeedControls"
	session.speed_group.add_theme_constant_override("separation", 0)
	bar.add_child(session.speed_group)
	session.speed_btn = Button.new()
	session.speed_btn.custom_minimum_size = Vector2(72, 36)
	session.speed_btn.pressed.connect(session.run_flow_system._toggle_speed)
	session.cards_system._icon_btn(session.speed_btn, func(): return ["speed", Color(1, 0.85, 0.45) if session.game_speed > 1.0 else Color(1, 1, 1, 0.9)])
	session.speed_group.add_child(session.speed_btn)
	session.speed_pick = OptionButton.new()
	for sp in BinduSession.SPEEDS:
		session.speed_pick.add_item("x%d" % roundi(sp))
	session.speed_pick.custom_minimum_size = Vector2(64, 36)
	session.speed_pick.focus_mode = Control.FOCUS_NONE
	session.speed_pick.tooltip_text = "빠르게 할 때 배속 (Space로 1배속과 오감)"
	session.speed_pick.item_selected.connect(session.run_flow_system._on_speed_pick)
	session.speed_group.add_child(session.speed_pick)
	# 맨 오른쪽: 접으면 이것만 남고, 펼치면 왼쪽으로 버튼이 늘어선다
	session.bar_btn = Button.new()
	session.bar_btn.custom_minimum_size = Vector2(96, 36)
	session.bar_btn.pressed.connect(session.cards_system._toggle_bar)
	bar.add_child(session.bar_btn)
	session.start_btn = Button.new()
	session.start_btn.text = "웨이브 시작 (Space)"
	session.start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	session.start_btn.position = Vector2(-110, -100)
	session.start_btn.size = Vector2(220, 44)
	session.start_btn.add_theme_font_size_override("font_size", 20)
	session.start_btn.pressed.connect(session.cards_system._start_wave_from_ready)
	session.start_btn.visible = false
	root.add_child(session.start_btn)
	session.abilities_system._make_skill_btns(root)
	session.cancel_btn = Button.new()
	session.cancel_btn.text = "취소 (Esc)" if OS.has_feature("pc") else "취소"
	session.cancel_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	session.cancel_btn.position = Vector2(-70, -100)  # 웨이브 시작 버튼 자리 (옮기기·설치 중엔 비어 있다)
	session.cancel_btn.size = Vector2(140, 40)
	session.cancel_btn.add_theme_font_size_override("font_size", 18)
	session.cancel_btn.pressed.connect(session.interaction_system._cancel_step)
	session.cancel_btn.visible = false
	root.add_child(session.cancel_btn)
	session.aim_ok_btn = Button.new()
	session.aim_ok_btn.text = "확정"
	session.aim_ok_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	session.aim_ok_btn.position = Vector2(-70.0 + 150.0, -100.0)  # 취소 오른쪽
	session.aim_ok_btn.size = Vector2(140, 40)
	session.aim_ok_btn.add_theme_font_size_override("font_size", 18)
	session.aim_ok_btn.focus_mode = Control.FOCUS_NONE
	session.aim_ok_btn.pressed.connect(func():
		if session.phase == BinduSession.Phase.AIM and session.aim_wait:
			session.interaction_system._confirm_aim())
	session.aim_ok_btn.visible = false
	root.add_child(session.aim_ok_btn)
	for button: Button in [session.reroll_btn, session.skip_btn, session.skip_n_btn, session.hide_btn, session.card_detail_btn, session.start_btn, session.cancel_btn, session.aim_ok_btn]:
		button.theme = session.card_dock.controls_theme
	for pair in [[session.skip_btn, session.skip_n_btn], [session.speed_btn, session.speed_pick]]:
		for button: Button in pair:
			for state_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
				var segment: StyleBoxFlat = button.get_theme_stylebox(state_name).duplicate()
				if button == pair[0]:
					segment.corner_radius_top_right = 0
					segment.corner_radius_bottom_right = 0
					segment.border_width_right = 0
				else:
					segment.corner_radius_top_left = 0
					segment.corner_radius_bottom_left = 0
				button.add_theme_stylebox_override(state_name, segment)
	session.detail_btn = Button.new()
	session.detail_btn.theme = session.card_dock.controls_theme
	session.detail_btn.custom_minimum_size = Vector2(64, 36)
	session.detail_btn.focus_mode = Control.FOCUS_NONE
	session.detail_btn.pressed.connect(func():
		session.tip_detail = not session.tip_detail
		session.touch_tip_t = BinduSession.TOUCH_TIP_SEC * 3.0)  # 자세히는 읽을 게 많아 더 오래
	session.detail_btn.visible = false
	session.card_dock.inspector_header.add_child(session.detail_btn)
	session.card_dock.inspector_header.move_child(session.detail_btn, 1)
	for b in [session.pause_btn, session.speed_btn, session.reroll_btn, session.skip_btn, session.skip_n_btn, session.skip_badge, session.auto_btn, session.start_btn, session.mute_btn, session.cancel_btn, session.bar_btn]:
		b.focus_mode = Control.FOCUS_NONE
	session.cards_system._update_auto_btn()
	session.mute_btn.tooltip_text = "소리: " + ("끔" if session.sfx.muted else "켬") + " (M)"

	# 일시정지 중엔 뒤 화면(카드·설명·큰 글)을 어둡게 덮고 그 위에 글·버튼 (카드가 일시정지 버튼 위에 그려져 겹치던 것)
	session.pause_dim = ColorRect.new()
	session.pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	session.pause_dim.color = Color(0.02, 0.02, 0.04, 0.82)
	session.pause_dim.mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤 카드가 눌리지 않게
	session.pause_dim.z_index = 20
	session.pause_dim.visible = false
	root.add_child(session.pause_dim)
	session.paused_label = Label.new()
	session.paused_label.z_index = 21
	session.paused_label.set_anchors_preset(Control.PRESET_CENTER)
	# 화면 위쪽에 두어 멈춘 채로 가운데 필드의 오브젝트·구체 정보를 볼 수 있게
	session.paused_label.position = Vector2(-350, -248)  # 점수 줄·보스 막대 아래
	session.paused_label.size = Vector2(700, 80)  # 글줄이 늘면 아래로 자란다
	session.paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	session.paused_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	session.paused_label.add_theme_font_size_override("font_size", 20)
	session.paused_label.add_theme_color_override("font_outline_color", Color.BLACK)
	session.paused_label.add_theme_constant_override("outline_size", 5)
	session.paused_label.text = session.run_flow_system._pause_text()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.03, 0.04, 0.06, 0.85)
	psb.set_corner_radius_all(8)
	session.paused_label.add_theme_stylebox_override("normal", psb)
	session.paused_label.visible = false
	root.add_child(session.paused_label)
	session.pause_box = HBoxContainer.new()
	session.pause_box.z_index = 21
	session.pause_box.set_anchors_preset(Control.PRESET_CENTER)
	session.pause_box.position = Vector2(-385, -150)  # 글 아래 (_process에서 글 높이에 맞춤)
	session.pause_box.size = Vector2(770, 60)
	session.pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	session.pause_box.add_theme_constant_override("separation", 12)
	# 글 대신 그림 버튼 (키 안내 글 두 줄을 없애고 키는 모서리에). 작은 버튼 셋은 그림만 (이름은 말풍선)
	var pspecs := [["계속", session.run_flow_system._toggle_pause, "play", "P"], ["튜토리얼", session.onboarding_system._open_tut_list, "help", ""], ["처음부터", session.run_flow_system._pause_restart, "restart", "R"], ["판 끝내기", session.run_flow_system._end_run, "flag", "E"], ["시작 화면", session.run_flow_system._leave.bind(false), "home", "T"]]
	if OS.has_feature("pc"):
		pspecs.append(["끄기", session.run_flow_system._leave.bind(true), "power", "X"])  # 모바일은 운영체제가 앱을 닫는다
	pspecs += [["소리 (M)", session.cards_system._toggle_mute, "sound", "M", true], ["설정 (O)", session.menu_system._toggle_settings, "gear", "O", true]]
	if OS.has_feature("pc"):
		pspecs.append(["전체 화면 (F11)", session.menu_system._toggle_fullscreen, "full", "F11", true])
	for spec in pspecs:
		var b := Button.new()
		var small: bool = spec.size() > 4
		b.custom_minimum_size = Vector2(56 if small else 92, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		if small:
			b.tooltip_text = spec[0]
			session.cards_system._icon_btn(b, func(): return [("mute" if session.sfx.muted else "sound") if spec[2] == "sound" else spec[2], Color(1, 1, 1, 0.85)])
			b.pressed.connect(session.cards_system._icon_toast.bind(b))
		else:
			session.cards_system._menu_glyph(b, spec[2], spec[0])
		session.cards_system._keycap(b, spec[3])
		session.pause_box.add_child(b)
	session.pause_box.visible = false
	root.add_child(session.pause_box)

	session.info = Control.new()
	session.info.set_anchors_preset(Control.PRESET_FULL_RECT)
	session.info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.info.z_index = 5  # 카드 위에 말풍선이 뜬다
	session.info.draw.connect(session.field_overlay_system._draw_info)
	root.add_child(session.info)

	session.coin_fx = Control.new()
	session.coin_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	session.coin_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.coin_fx.z_index = 15  # 카드 줄 버튼(넘기기·필드 보기) 위, 일시정지(20) 아래
	session.coin_fx.visible = false
	session.coin_fx.draw.connect(session.perks_system._draw_coin)
	session.coin_fx.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed:
			session.perks_system._coin_tap()
			session.coin_fx.accept_event())
	root.add_child(session.coin_fx)

	session.banner = Label.new()
	session.banner.set_anchors_preset(Control.PRESET_CENTER)
	session.banner.position = Vector2(-400, -140)
	session.banner.size = Vector2(800, 60)
	session.banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	session.banner.add_theme_font_size_override("font_size", 40)
	session.banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	session.banner.add_theme_constant_override("outline_size", 6)
	session.banner.visible = false
	session.banner.z_index = 16  # 동전 연출(15) 위에 결과 글
	root.add_child(session.banner)

	session.over_label = Label.new()
	session.over_label.set_anchors_preset(Control.PRESET_CENTER)
	session.over_label.position = Vector2(-450, 70)  # 그림 카드(over_card) 아래
	session.over_label.size = Vector2(900, 150)
	# 줄이 늘어도 가운데를 지키며 위아래로 자란다
	session.over_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	session.over_label.grow_vertical = Control.GROW_DIRECTION_END
	session.over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	session.over_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	session.over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 최다 피해 오브젝트 이름 등이 길면 화면 밖으로 나가던 것: 900 안에서 접는다
	session.over_label.add_theme_font_size_override("font_size", 18)
	session.over_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	session.over_label.visible = false
	root.add_child(session.over_label)
	# 글이 바뀌어 다시 그려지면(온라인 순위가 나중에 붙는 등) 그림 카드 바탕 높이·나가는 법 줄도 다시
	session.over_label.draw.connect(func(): if session.over_card: session.over_card.queue_redraw())
	# 판 끝난 화면: 다음 패치 투표 (투표 API가 있는 서버일 때만, 자리는 over_label 바로 아래로 매 프레임 맞춤)
	session.vote_over_btn = Button.new()
	session.vote_over_btn.set_anchors_preset(Control.PRESET_CENTER)
	session.vote_over_btn.text = "다음 패치 투표"
	session.vote_over_btn.focus_mode = Control.FOCUS_NONE
	session.vote_over_btn.size = Vector2(220, 44)
	session.vote_over_btn.position = Vector2(-110, 200)
	session.vote_over_btn.add_theme_font_size_override("font_size", 17)
	session.vote_over_btn.add_theme_color_override("font_color", Color(1, 0.86, 0.35))
	session.vote_over_btn.tooltip_text = "이번 판에 쓴 카드 중 다음 패치에서 강해졌으면·약해졌으면·바뀌었으면 하는 것에 투표"
	session.vote_over_btn.pressed.connect(func(): session.menu_system._toggle_vote(true))
	session.vote_over_btn.visible = false
	session.cards_system._icon_btn(session.vote_over_btn, func(): return ["vote", Color(1, 0.86, 0.35)])
	root.add_child(session.vote_over_btn)
	# 게임 오버 그림 카드: 웨이브·점수 큰 칩, 처치·콤보·오브젝트 작은 칩, 새 업적 배지 (나머지 글은 아래 over_label)
	session.over_card = Control.new()
	session.over_card.set_anchors_preset(Control.PRESET_CENTER)
	session.over_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.over_card.draw.connect(session.run_flow_system._draw_over_card)
	session.over_card.add_to_group("keycap")  # 터치·마우스가 바뀌면 나가는 법 줄을 다시
	session.over_card.visible = false
	root.add_child(session.over_card)
	root.move_child(session.over_card, session.over_label.get_index())  # 바탕이 남은 글(over_label)을 덮지 않게 글 밑에
	# 광고가 되는 폰의 결과 화면 버튼 (자리는 _draw_over_card가 바탕 끝 줄에 맞춤)
	session.over_revive_btn = Button.new()
	session.over_revive_btn.text = "▶ 광고 보고 한 번 더"
	session.over_revive_btn.tooltip_text = "광고를 끝까지 보면 이 웨이브 앞 쉬는 시간부터 중앙 %d로 다시 해요. 판마다 한 번, 이어 한 판은 리더보드에 올라가지 않아요" % Ads.REVIVE_HP
	session.over_revive_btn.focus_mode = Control.FOCUS_NONE
	session.over_revive_btn.size = Vector2(250, 52)
	session.over_revive_btn.add_theme_font_size_override("font_size", 18)
	session.over_revive_btn.add_theme_color_override("font_color", Color(1, 0.84, 0.43))
	session.over_revive_btn.pressed.connect(session.run_flow_system._revive)
	session.over_revive_btn.visible = false
	session.over_card.add_child(session.over_revive_btn)
	session.over_home_btn = Button.new()
	session.over_home_btn.text = "시작 화면으로"
	session.over_home_btn.focus_mode = Control.FOCUS_NONE
	session.over_home_btn.size = Vector2(190, 52)
	session.over_home_btn.add_theme_font_size_override("font_size", 18)
	session.over_home_btn.pressed.connect(session.run_flow_system._over_home)
	session.over_home_btn.visible = false
	session.over_card.add_child(session.over_home_btn)
	session.over_detail_btn = Button.new()
	session.over_detail_btn.text = "결과 상세"
	session.over_detail_btn.tooltip_text = "오브젝트마다 웨이브별 DPS·처치를 봐요"
	session.over_detail_btn.focus_mode = Control.FOCUS_NONE
	session.over_detail_btn.size = Vector2(150, 52)
	session.over_detail_btn.add_theme_font_size_override("font_size", 18)
	session.over_detail_btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	session.over_detail_btn.pressed.connect(session.run_flow_system._open_detail)
	session.over_detail_btn.visible = false
	session.over_card.add_child(session.over_detail_btn)
	session.run_detail = RunDetail.new()
	root.add_child(session.run_detail)

	session.dps_hidden = Meta.dps_fold
	session.hud_system._build_dps(root)
	session.menu_system._build_menu(root)

	# 도움말은 굴려 보는 창 안에 (줄이 많아 화면 높이에 맞춰 줄이면 글자를 읽을 수 없게 작아지던 것).
	# 열고 닫는 것은 그대로 help_label.visible, 창(help_scroll)은 _process에서 따라간다
	session.help_scroll = ScrollContainer.new()
	session.help_scroll.z_index = 22  # 일시정지 어둠(z 20) 위에
	session.help_scroll.set_anchors_preset(Control.PRESET_CENTER)
	session.help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	session.help_scroll.visible = false
	session.help_label = Label.new()
	# 긴 줄은 창 안에서 줄바꿈 (오른쪽 끝이 화면 밖으로 잘리던 것)
	session.help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session.help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session.help_label.add_theme_font_size_override("font_size", 15)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.05, 0.06, 0.09, 1.0)  # 뒤 카드·설명 글자가 비쳐 보이지 않게
	hsb.set_border_width_all(1)
	hsb.border_color = Color(1, 1, 1, 0.25)
	hsb.set_content_margin_all(18)
	hsb.set_corner_radius_all(6)
	session.help_scroll.add_theme_stylebox_override("panel", hsb)
	session.help_label.text = session.patchlog_system._kr_keep(session.run_flow_system._help_text())
	session.help_label.visible = false
	session.help_scroll.add_child(session.help_label)
	root.add_child(session.help_scroll)
