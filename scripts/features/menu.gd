class_name BinduMenu
extends BinduFeature
## 시작·준비·설정·모드 UI. 예약 콜백은 main의 순서를 따른다.

var volume_sliders := {}  # 설정 창 음량 슬라이더: "전체 음량"·"배경음"·"효과음" -> HSlider
var volume_rows: Array = []  # 음량 줄 전부 [이름, 슬라이더, 글, getter] (설정 창 + 소리 버튼 작은 창, 서로 맞춤)
var sound_pop: Control  # 오른쪽 아래 소리 버튼을 누르면 뜨는 작은 창 (바깥 막 + 창)
var sound_panel: PanelContainer
var sound_toggle: CheckButton  # 작은 창의 소리 켜기·끄기
var account_label: Label  # 설정: 계정 상태 한 줄
var map_label: Label  # 준비 화면 맵 카드 아래 설명 (고른 맵 이름·규칙, 작은 설명은 meta "sub")
var map_cards: Array[Button] = []  # 준비 화면 맵 카드 (Meta.MAP_IDS 순서, _draw_map_card)
var rules_label: Label
var skill_label: Label  # 준비 화면 중앙 기술 묶음
var skin_label: Label
var core_label: Label
var easy_notice: PanelContainer  # 쉽게 모드를 처음 켤 때: 쉽게 모드 리더보드로 간다는 안내 (다시 보지 않기)
var easy_notice_skip: CheckBox
var modes_head: Label
var modes_btns := {}  # 모드 id -> 켜고 끄는 버튼
var home_box: VBoxContainer  # 시작 화면 첫 화면: 이어하기·큰 타일(일반 판·멀티)·그림 버튼 줄
var prep_cols: GridContainer  # 준비 화면: [맵 카드 | 규칙·기술·모드·시작] 두 칸 또는 위아래 (_prep_layout)
var prep_right: VBoxContainer
var prep_box: VBoxContainer  # [일반 판]을 누르면: 맵·규칙·모드 + 시작 (Esc 뒤로)
var prep_title: Label
var modes_label: Label  # 준비 화면 모드 줄 가운데 글
var normal_info: Label  # 일반 판 타일의 맵·최고 기록 줄
func _build_menu(root: Control) -> void:
	var session: BinduSession = self.session
	session.title_label = Control.new()
	session.title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	session.title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.title_label.visible = false
	root.add_child(session.title_label)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-330, -300)
	box.size = Vector2(660, 600)
	# 줄이 늘면(회랑 설명·규칙·모드·이어하기·새 버전 알림) 위아래로 같이 자라고, 화면보다 크면 _fit_panels가 줄인다
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	session.title_label.add_child(box)
	session.title_box = box
	var logo := Label.new()
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 56 if session.viewport_system._phone() else 72)
	logo.text = "빈두"
	box.add_child(logo)
	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", Meta.fs(19))
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	desc.text = "밖에서 몰려오는 구체를 막아 중앙 점을 지키세요\n공격방식·속성·강화·연계를 조합해 오브젝트를 키우세요"
	desc.visible = not session.viewport_system._phone()  # 폰: 줄을 줄여야 시작 화면을 덜 줄여서 버튼이 손가락 크기로 남는다
	box.add_child(desc)
	# [일반 판]을 누르면 나오는 준비 화면 (맵·오는 쪽·규칙·모드 + 시작)
	prep_title = Label.new()
	prep_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prep_title.add_theme_font_size_override("font_size", Meta.fs(38))
	prep_title.text = "일반 판"
	prep_title.visible = false
	box.add_child(prep_title)
	prep_box = VBoxContainer.new()
	prep_box.add_theme_constant_override("separation", 10)
	prep_box.visible = false
	box.add_child(prep_box)
	home_box = VBoxContainer.new()
	home_box.add_theme_constant_override("separation", 10)
	box.add_child(home_box)
	map_label = _build_map_cards(prep_box)
	session.flip_label = _prep_row(prep_box, "오는 쪽", _toggle_flip, _toggle_flip)
	rules_label = _prep_row(prep_box, "규칙", func(): _cycle_rules(-1), func(): _cycle_rules(1))
	skill_label = _prep_row(prep_box, "중앙 기술", func(): _cycle_skill(-1), func(): _cycle_skill(1))
	# 모드: 여러 개를 켜고 끄는 창이라 화살표 대신 줄 전체가 [모드] 창을 연다
	session.modes_btn = Button.new()
	session.modes_btn.custom_minimum_size = Vector2(BinduSession.PREP_W, 64 if session.viewport_system._phone() else 56)
	session.modes_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	session.modes_btn.focus_mode = Control.FOCUS_NONE
	session.modes_btn.pressed.connect(_toggle_modes)
	for st in ["normal", "hover", "pressed"]:
		session.modes_btn.add_theme_stylebox_override(st, _prep_sb(st != "normal"))
	var mh := HBoxContainer.new()
	mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mh.add_theme_constant_override("separation", 12)
	session.modes_btn.add_child(mh)
	mh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	mh.offset_left = 14.0
	mh.offset_right = -10.0
	var mn := _prep_name("모드 (시험)")
	mh.add_child(mn)
	var mv := VBoxContainer.new()
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(mv)
	modes_label = _prep_main()
	mv.add_child(modes_label)
	var msub := _prep_sub()
	mv.add_child(msub)
	modes_label.set_meta("sub", msub)
	var marrow := Label.new()
	marrow.text = "바꾸기 ▶"
	marrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marrow.custom_minimum_size = Vector2(90, 0)
	marrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	mh.add_child(marrow)
	prep_box.add_child(session.modes_btn)
	session.new_btn = Button.new()
	session.new_btn.custom_minimum_size = Vector2(BinduSession.PREP_W, 72 if session.viewport_system._phone() else 64)
	session.new_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	session.new_btn.focus_mode = Control.FOCUS_NONE
	session.new_btn.add_theme_font_size_override("font_size", Meta.fs(24))
	for st in ["normal", "hover", "pressed"]:
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(0.15, 0.22, 0.13) if st == "normal" else Color(0.2, 0.3, 0.17)
		gsb.set_border_width_all(2)
		gsb.border_color = Color(0.56, 0.82, 0.44)
		gsb.set_corner_radius_all(10)
		session.new_btn.add_theme_stylebox_override(st, gsb)
	session.new_btn.pressed.connect(session.progression_system._close_title)
	prep_box.add_child(session.new_btn)
	session.cards_system._icon_btn(session.new_btn, func(): return ["play", Color(1, 0.9, 0.6)])
	session.cards_system._keycap(session.new_btn, "Enter")
	# 맵 카드와 규칙·기술·모드·시작 묶음: 화면이 넓으면 두 칸(_prep_layout), 좁으면 위아래.
	# 한 줄로 쌓으면 화면 높이를 넘어 준비 화면 전체가 줄었다 (PC 0.87배·폰 0.69배, 설명 글 9~11px)
	prep_cols = GridContainer.new()
	prep_cols.add_theme_constant_override("h_separation", 12)
	prep_cols.add_theme_constant_override("v_separation", 10)
	prep_right = VBoxContainer.new()
	prep_right.add_theme_constant_override("separation", 10)
	prep_right.alignment = BoxContainer.ALIGNMENT_CENTER
	var kids := prep_box.get_children()
	for k: Control in kids:
		prep_box.remove_child(k)
	prep_cols.add_child(kids[0])
	for k: Control in kids.slice(1):
		prep_right.add_child(k)
	prep_cols.add_child(prep_right)
	prep_box.add_child(prep_cols)
	_prep_layout()
	session.prep_back = Button.new()
	session.prep_back.text = "◀ 뒤로 (Esc)"
	session.prep_back.add_to_group("key_hint")
	session.prep_back.custom_minimum_size = Vector2(150, 56 if session.viewport_system._phone() else 42)
	session.prep_back.position = Vector2(20, 20)
	session.prep_back.focus_mode = Control.FOCUS_NONE
	session.prep_back.add_theme_font_size_override("font_size", Meta.fs(18))
	session.prep_back.pressed.connect(func(): _set_prep(false))
	session.prep_back.visible = false
	session.title_label.add_child(session.prep_back)
	# 첫 화면: 큰 타일 (일반 판 · 멀티플레이)
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 16)
	home_box.add_child(tiles)
	var normal_tile := Button.new()
	normal_tile.pressed.connect(func(): _set_prep(true))
	normal_info = _tile(normal_tile, "일반 판", Color(0.55, 0.78, 1.0), func(): return "" if session.continue_btn.visible else "Enter")
	tiles.add_child(normal_tile)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	home_box.add_child(row)
	# 그림 + 짧은 이름 (단축키는 모서리 작은 키, 긴 이름은 말풍선)
	var specs := [["기록", _toggle_records, "records", "", "기록·업적"], ["도감", _toggle_codex, "book", "K", "도감 (K)"], ["설정", _toggle_settings, "gear", "O", "설정 (O)"], ["튜토리얼", session.onboarding_system._open_tut_list, "help", "H", "튜토리얼 (H)"]]
	if OnlineConfig.SERVER_URL != "":
		specs.insert(2, ["순위", session.leaderboard_system._toggle_board, "rank", "", "리더보드"])
		specs.insert(4, ["투표", _toggle_vote, "vote", "V", "다음 패치 투표 (V)"])
	# 게임 끄기: PC만 (iOS·Android는 앱이 스스로 끄지 않는다)
	if OS.has_feature("pc"):
		specs.append(["종료", func(): session.get_tree().quit(), "power", "", "게임 종료"])
	for spec in specs:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
		b.custom_minimum_size = Vector2(96, 66) if session.viewport_system._phone() else Vector2(78, 54)
		b.tooltip_text = spec[4]
		if spec[2] == "vote":
			session.vote_btn = b
			b.visible = Net.vote_ok()
		session.cards_system._menu_glyph(b, spec[2], spec[0])
		session.cards_system._keycap(b, spec[3])
	# 이어하기: 저장된 판이 있을 때만 (쉬는 시간마다 자동 저장)
	# 아래 타일과 같은 카드 모양(호박색 테두리·이름·설명 줄), 폭은 타일 줄과 같게 (_refresh_continue)
	session.continue_btn = Button.new()
	session.continue_info = _tile(session.continue_btn, "이어하기", BinduSession.CONT_COL, "Enter")
	session.continue_btn.custom_minimum_size.y = 104 if session.viewport_system._phone() else 92
	session.continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed"]:
		var csb: StyleBoxFlat = session.continue_btn.get_theme_stylebox(st).duplicate()
		csb.bg_color = Color(0.13, 0.11, 0.07) if st == "normal" else Color(0.18, 0.15, 0.09)
		csb.border_color = Color(BinduSession.CONT_COL, 0.8 if st == "normal" else 1.0)
		session.continue_btn.add_theme_stylebox_override(st, csb)
	session.continue_info.add_theme_font_size_override("font_size", Meta.fs(17))
	session.continue_info.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 0.85))
	session.continue_btn.pressed.connect(session.persistence_system._continue_run)
	session.continue_btn.visible = false
	if session.viewport_system._phone():
		# 폰: 이어하기를 일반 판 타일 옆에 (위아래로 쌓으면 시작 화면이 화면보다 길어져 통째로 줄고 글이 작아졌다)
		session.continue_btn.custom_minimum_size.y = 170
		tiles.add_child(session.continue_btn)
		tiles.move_child(session.continue_btn, 0)
	else:
		home_box.add_child(session.continue_btn)
		home_box.move_child(session.continue_btn, 0)
	session.remote_btn = Button.new()
	session.remote_btn.custom_minimum_size = Vector2(630, 56 if session.viewport_system._phone() else 44)
	session.remote_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	session.remote_btn.focus_mode = Control.FOCUS_NONE
	session.remote_btn.add_theme_font_size_override("font_size", Meta.fs(17))
	session.remote_btn.pressed.connect(session.online_system._claim_remote_run)
	session.remote_btn.visible = false
	home_box.add_child(session.remote_btn)
	home_box.move_child(session.remote_btn, 1)
	# 멀티플레이: 중개 서버 주소가 있고 WebRTC 확장이 읽힌 기기에서만
	session.mp_btn = Button.new()
	_tile(session.mp_btn, "멀티플레이", Color(0.8, 0.62, 1.0), "").text = "친구와 대결 · 협동\n방 만들기 · 코드로 참가"
	session.mp_btn.pressed.connect(session.lobby_system._toggle_mp_lobby)
	# Windows는 exe 안 dll을 풀어 읽어서 실패할 수 있다: 버튼은 두고 방을 만들 때 까닭을 보여 준다
	session.mp_btn.visible = session.lobby_system._mp_btn_shown()
	tiles.add_child(session.mp_btn)
	session.lobby_system._build_mp_lobby(root)
	# 온라인: 새 버전 알림, 패치 공지 (서버에서 받았을 때만 보임)
	session.update_btn = Button.new()
	session.update_btn.custom_minimum_size = Vector2(630, 56 if session.viewport_system._phone() else 40)
	session.update_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	session.update_btn.focus_mode = Control.FOCUS_NONE
	session.update_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	session.update_btn.visible = false
	home_box.add_child(session.update_btn)
	session.notes_btn = Button.new()
	session.notes_btn.custom_minimum_size = Vector2(320, 52 if session.viewport_system._phone() else 36)
	session.cards_system._icon_btn(session.notes_btn, func(): return ["notes", Color(1, 1, 1, 0.8)])
	session.notes_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	session.notes_btn.focus_mode = Control.FOCUS_NONE
	session.notes_btn.pressed.connect(session.patchlog_system._toggle_notes)
	if session.viewport_system._phone():
		row.add_child(session.notes_btn)  # 폰: 그림 버튼 줄 끝에 (한 줄 아끼기)
		session.notes_btn.custom_minimum_size = Vector2(300, 66)
		session.notes_btn.size_flags_vertical = Control.SIZE_FILL
	else:
		home_box.add_child(session.notes_btn)
		home_box.move_child(session.notes_btn, session.update_btn.get_index())
	session.notice_label = Label.new()
	session.notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	session.notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session.notice_label.custom_minimum_size = Vector2(630, 0)
	session.notice_label.add_theme_font_size_override("font_size", Meta.fs(16))
	session.notice_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	session.notice_label.visible = false
	home_box.add_child(session.notice_label)

	session.records_panel = Label.new()
	session.records_panel.z_index = 22  # 일시정지 어둠(z 20) 위에
	session.records_panel.set_anchors_preset(Control.PRESET_CENTER)
	# 내용이 늘면 위아래로 같이 자라게 (아래로만 자라면 오른쪽 아래 소리 버튼을 덮음)
	session.records_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	session.records_panel.offset_left = -430.0
	session.records_panel.offset_right = 430.0
	session.records_panel.offset_top = -325.0
	session.records_panel.offset_bottom = 285.0
	session.records_panel.add_theme_font_size_override("font_size", Meta.fs(15))
	session.records_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	rsb.set_border_width_all(1)
	rsb.border_color = Color(1, 1, 1, 0.25)
	rsb.set_content_margin_all(18)
	rsb.set_corner_radius_all(6)
	session.records_panel.add_theme_stylebox_override("normal", rsb)
	session.records_panel.visible = false
	root.add_child(session.records_panel)
	session.leaderboard_system._build_board()
	session.board_ugc_panel = PanelContainer.new()
	var usb: StyleBoxFlat = rsb.duplicate()
	usb.bg_color = Color(0.08, 0.09, 0.13, 1.0)
	usb.border_color = Color(1, 1, 1, 0.45)
	session.board_ugc_panel.add_theme_stylebox_override("panel", usb)
	session.board_ugc_panel.set_anchors_preset(Control.PRESET_CENTER)
	session.board_ugc_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	session.board_ugc_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	session.board_ugc_panel.visible = false
	session.records_panel.add_child(session.board_ugc_panel)
	session.patchlog_system._build_notes(root)
	_build_modes(root, rsb)
	session.codex_panel = Codex.new()
	session.codex_panel.z_index = 22  # 일시정지 어둠(z 20) 위에
	session.codex_panel.setup(BinduSession.PERKS, rsb.duplicate(), session.progression_system._save_best)
	root.add_child(session.codex_panel)
	session.vote_panel = Vote.new()
	session.vote_panel.z_index = 22
	session.vote_panel.setup(BinduSession.PERKS, rsb.duplicate(), session.net)
	root.add_child(session.vote_panel)
	session.tut = Tutorial.new()
	session.tut.z_index = 23  # 일시정지 어둠(20)·다른 창(22) 위에
	session.tut.setup(rsb.duplicate(), func(): session.help_label.visible = true)
	session.tut.closed.connect(session.onboarding_system._on_tut_closed)
	session.tut.play_requested.connect(session.onboarding_system._play_tutorial)
	root.add_child(session.tut)

	session.settings_panel = PanelContainer.new()
	session.settings_panel.z_index = 22  # 일시정지 어둠(z 20) 위에
	session.settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	# 폰: 켜기·끄기 줄을 두 칸으로 나누고 줄을 손가락 크기로 (한 칸이면 창이 화면보다 길어져 줄어들고 줄이 3mm 남짓이었다)
	var sw := clampf(session.viewport_system._phone_ui_w(), 480.0, 980.0) if session.viewport_system._phone() else 480.0
	session.settings_panel.position = Vector2(-sw / 2.0, 0)
	session.settings_panel.size = Vector2(sw, 0)
	session.settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH  # 내용 높이에 맞춰 위아래로 자라 가운데에 (온라인 줄이 생기면 아래가 잘리던 것)
	session.settings_panel.add_theme_stylebox_override("panel", rsb.duplicate())
	session.settings_panel.visible = false
	root.add_child(session.settings_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	session.settings_panel.add_child(sv)
	var st := Label.new()
	st.text = "설정 (O / Esc: 닫기)"
	st.add_to_group("key_hint")
	st.add_theme_font_size_override("font_size", Meta.fs(22))
	sv.add_child(st)
	# 음량: 전체 x 배경음·효과음 (따로 줄일 수 있게)
	_volume_row(sv, "전체 음량", func(): return Meta.volume, func(v): Meta.volume = v)
	_volume_row(sv, "배경음", func(): return Meta.music_volume, func(v): Meta.music_volume = v)
	_volume_row(sv, "효과음", func(): return Meta.sfx_volume, func(v): Meta.sfx_volume = v)
	var zrow := HBoxContainer.new()
	zrow.add_theme_constant_override("separation", 6)
	var zl := Label.new()
	zl.text = "글자·버튼 크기"
	zl.custom_minimum_size = Vector2(120, 0)
	zrow.add_child(zl)
	var zg := ButtonGroup.new()
	for v in Meta.UI_SCALES:
		var zb := Button.new()
		zb.text = "%d%%" % roundi(v * 100.0)
		zb.toggle_mode = true
		zb.button_group = zg
		zb.button_pressed = is_equal_approx(v, Meta.ui_scale)
		zb.custom_minimum_size = Vector2(72, 30)
		zb.focus_mode = Control.FOCUS_NONE
		zb.pressed.connect(func():
			Meta.ui_scale = v
			session.hud_system._apply_ui_scale()
			session.progression_system._save_best())
		zrow.add_child(zb)
	sv.add_child(zrow)
	# 오브젝트·중앙 모양 (예전엔 시작 화면에 있었다)
	skin_label = _menu_row(sv, func(): _cycle_skin("tower", -1), func(): _cycle_skin("tower", 1), sw - (220.0 if session.viewport_system._phone() else 160.0))
	core_label = _menu_row(sv, func(): _cycle_skin("core", -1), func(): _cycle_skin("core", 1), sw - (220.0 if session.viewport_system._phone() else 160.0))
	var cbox: Container = sv
	if session.viewport_system._phone():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 4)
		sv.add_child(grid)
		cbox = grid
	for spec in [["화면 흔들림", "shake_on"], ["피해 숫자", "numbers_on"], ["속성 기호 표시 (색 위에 속성 그림)", "symbols_on"], ["모든 구체에 체력 숫자 (끄면 고리만)", "orb_hp_on"], ["중앙이 위험하면 1배속으로 (체력 50%·25%)", "danger_slow"], ["웨이브 넘기기 중 중앙이 위험하면 멈춤 (체력 50%)", "skip_danger"], ["중앙 기술 자동 사용 (구체가 몰린 곳에)", "skill_auto"], ["효과 줄이기 (장판·터지는 효과를 옅게, 많을수록 더)", "fx_low"], ["피해 1~3위 왕관·메달", "rank_on"]]:
		var cb := CheckButton.new()
		cb.text = spec[0]
		if cbox != sv:
			# 폰 두 칸: 글자를 키워 긴 줄은 두 줄로 접는다 (한 줄이면 창이 화면보다 넓어졌다)
			cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cb.custom_minimum_size.x = (sw - 60.0) / 2.0
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = spec[1]
		match key:
			"shake_on": cb.button_pressed = Meta.shake_on
			"numbers_on": cb.button_pressed = Meta.numbers_on
			"symbols_on": cb.button_pressed = Meta.symbols_on
			"orb_hp_on": cb.button_pressed = Meta.orb_hp_on
			"danger_slow": cb.button_pressed = Meta.danger_slow
			"skip_danger": cb.button_pressed = Meta.skip_danger
			"skill_auto": cb.button_pressed = Meta.skill_auto
			"fx_low": cb.button_pressed = Meta.fx_low
			"rank_on": cb.button_pressed = Meta.rank_on
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			match key:
				"shake_on": Meta.shake_on = on
				"numbers_on": Meta.numbers_on = on
				"orb_hp_on": Meta.orb_hp_on = on
				"danger_slow": Meta.danger_slow = on
				"skip_danger": Meta.skip_danger = on
				"skill_auto": Meta.skill_auto = on
				"fx_low": Meta.fx_low = on
				"rank_on":
					Meta.rank_on = on
					session.hud_system._rank_update()
				"symbols_on":
					Meta.symbols_on = on
					for t in session.towers.get_children():
						t.queue_redraw()
			session.progression_system._save_best())
		cbox.add_child(cb)
	var gc := CheckButton.new()
	gc.text = "처음 안내 보기 (처음 생기는 일에 한 줄 설명)"
	gc.button_pressed = Meta.guide_on
	gc.focus_mode = Control.FOCUS_NONE
	gc.toggled.connect(func(on):
		Meta.guide_on = on
		if not on:
			session.guide_lines.clear()
		session.progression_system._save_best())
	cbox.add_child(gc)
	var gr := Button.new()
	gr.text = "안내 처음부터 다시 보기"
	gr.tooltip_text = "본 안내를 지우고, 다음 새 판은 첫 판처럼 카드 종류를 웨이브마다 하나씩 엽니다"
	gr.focus_mode = Control.FOCUS_NONE
	gr.pressed.connect(func():
		Meta.guide_seen = {}
		Tutorial.seen = {}  # 직접 열어 본 항목 기록만 초기화. 첫 소개 완료(done)는 보존
		Tutorial.save_file()
		Meta.guide_on = true
		Meta.tutor_next = true
		gc.set_pressed_no_signal(true)
		session.progression_system._save_best()
		session.hud_system._show_toast("다음 새 판부터 안내를 처음부터 보여 줘요"))
	sv.add_child(gr)
	if OnlineConfig.SERVER_URL != "":
		var oc := CheckButton.new()
		oc.text = "기록 보내기 (리더보드·사용 통계, 익명)"
		oc.button_pressed = Meta.online_on
		oc.focus_mode = Control.FOCUS_NONE
		oc.toggled.connect(func(on):
			Meta.online_on = on
			session.progression_system._save_best())
		cbox.add_child(oc)
		var nrow := HBoxContainer.new()
		var nl := Label.new()
		nl.text = "닉네임"
		nl.custom_minimum_size = Vector2(120, 0)
		nrow.add_child(nl)
		var ne := LineEdit.new()
		ne.max_length = 12
		ne.placeholder_text = "비우면 익명"
		ne.text = Meta.nickname
		ne.custom_minimum_size = Vector2(240, 0)
		var nbad := Label.new()  # 욕설·운영자 사칭 등 (NickFilter): 저장하지 않고 익명으로
		nbad.text = "쓸 수 없는 낱말이 있어요"
		nbad.add_theme_font_size_override("font_size", Meta.fs(14))
		nbad.add_theme_color_override("font_color", Color(1, 0.5, 0.45))
		nbad.visible = NickFilter.bad(Meta.nickname)
		ne.text_changed.connect(func(t):
			var bad := NickFilter.bad(t)
			nbad.visible = bad
			Meta.nickname = "" if bad else t.strip_edges()
			session.progression_system._save_best())
		ne.text_submitted.connect(func(_t): ne.release_focus())
		nrow.add_child(ne)
		nrow.add_child(nbad)
		sv.add_child(nrow)
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 8)
		account_label = Label.new()
		account_label.add_theme_font_size_override("font_size", Meta.fs(14))
		account_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		account_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		account_label.text = Account.label()
		arow.add_child(account_label)
		# 내 온라인 데이터 지우기 (App Store 5.1.1(v)): 두 번 눌러야 지운다. 서버 계정·진행·리더보드 이름과 기록을 지우고 기록 보내기를 끈다.
		var del := Button.new()
		del.text = "내 온라인 데이터 지우기"
		del.tooltip_text = "서버에 저장된 진행·리더보드 이름과 기록을 지웁니다. 이 기기의 기록·업적은 남아요"
		del.focus_mode = Control.FOCUS_NONE
		del.pressed.connect(_on_delete_data.bind(del, ne))
		arow.add_child(del)
		sv.add_child(arow)
	var nb := Button.new()
	nb.text = "패치노트 (N)"
	nb.focus_mode = Control.FOCUS_NONE
	nb.pressed.connect(session.patchlog_system._toggle_notes)
	sv.add_child(nb)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	var fs := Button.new()
	fs.text = "전체 화면 전환 (F11)"
	fs.focus_mode = Control.FOCUS_NONE
	fs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs.pressed.connect(_toggle_fullscreen)
	fs.visible = not OS.has_feature("mobile")  # 폰·태블릿은 늘 전체 화면 (누르면 창 모드로 바뀌어 위아래 막대가 생길 수 있다)
	brow.add_child(fs)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(_toggle_settings)
	brow.add_child(close)
	sv.add_child(brow)
	if session.viewport_system._phone():
		for c: Control in session.settings_panel.find_children("*", "", true, false):
			if c is BaseButton or c is LineEdit or c is HSlider:
				c.custom_minimum_size.y = maxf(c.custom_minimum_size.y, 52.0)
			if c is CheckButton:
				c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session.hud_system._phone_scroll(session.settings_panel)
	_refresh_menu()


## 설정의 [내 온라인 데이터 지우기]: 첫 누름은 확인 글로 바꾸고 4초 안에 한 번 더 누르면 지운다.
func _on_delete_data(b: Button, nick_edit: LineEdit) -> void:
	if not b.has_meta("armed"):
		b.set_meta("armed", true)
		b.text = "한 번 더 누르면 지워요"
		b.add_theme_color_override("font_color", Color(1, 0.55, 0.5))
		var bref: WeakRef = weakref(b)  # 4초 안에 설정 창을 닫아 버튼이 지워져도 오류가 안 나게
		session.get_tree().create_timer(4.0).timeout.connect(func():
			var b2: Button = bref.get_ref()
			if b2 != null and b2.has_meta("armed") and not b2.disabled:
				b2.remove_meta("armed")
				b2.text = "내 온라인 데이터 지우기"
				b2.remove_theme_color_override("font_color"))
		return
	b.remove_meta("armed")
	b.disabled = true
	b.text = "지우는 중…"
	var code := await session.net.delete_account()
	if not is_instance_valid(session) or not is_instance_valid(b) or not is_instance_valid(nick_edit):
		return
	b.disabled = false
	b.text = "내 온라인 데이터 지우기"
	b.remove_theme_color_override("font_color")
	if code == 200:
		Meta.online_on = false  # 바로 새 계정이 생기지 않게: 다시 켜면 새 익명 계정으로 시작
		Meta.nickname = ""
		nick_edit.text = ""
		for c in session.settings_panel.find_children("*", "CheckButton", true, false):
			if (c as CheckButton).text.begins_with("기록 보내기"):
				(c as CheckButton).set_pressed_no_signal(false)
		session.progression_system._save_best()
		if account_label:
			account_label.text = Account.label()
		session.hud_system._show_toast("서버에 저장된 내 데이터를 지웠어요. '기록 보내기'를 다시 켜면 새 익명 계정으로 시작해요")
	else:
		session.hud_system._show_toast("지우지 못했어요. 인터넷 연결을 확인하고 다시 눌러 주세요" if code == 0 else "지우지 못했어요 (서버 %d)" % code)


## ◀ 글자 ▶ 한 줄.
## 시작 화면 큰 타일: 버튼 위에 이름(색)과 설명 줄. 설명 Label을 돌려준다.
func _tile(b: Button, title: String, col: Color, key: Variant) -> Label:
	var session: BinduSession = self.session
	b.text = ""
	b.custom_minimum_size = Vector2(_tile_w(), 170 if session.viewport_system._phone() else 150)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.09, 0.12) if st == "normal" else Color(0.1, 0.13, 0.17)
		sb.set_border_width_all(2)
		sb.border_color = Color(col, 0.55 if st == "normal" else 0.95)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st, sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	var n := Label.new()
	n.text = title
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_font_size_override("font_size", Meta.fs(26))
	n.add_theme_color_override("font_color", col)
	v.add_child(n)
	var info := Label.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", Meta.fs(15))
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(info)
	session.cards_system._keycap(b, key)
	return info


func _tile_w() -> float:
	var session: BinduSession = self.session
	return 290.0 if session.viewport_system._phone() else 210.0


## 시작 화면: 첫 화면(큰 타일) ↔ 일반 판 준비 화면.
func _set_prep(on: bool) -> void:
	var session: BinduSession = self.session
	session.prep = on
	prep_title.visible = on
	prep_box.visible = on
	session.prep_back.visible = on
	home_box.visible = not on
	session.title_box.get_child(0).visible = not on  # 로고·소개 줄은 첫 화면에만
	session.title_box.get_child(1).visible = not on and not session.viewport_system._phone()
	session.new_armed = 0.0
	session.new_btn.text = "새로 시작" if session.continue_btn.visible else "시작"
	session.sfx.play("place")
	_refresh_menu()


func _prep_layout() -> void:
	var session: BinduSession = self.session
	if prep_cols == null:
		return
	# 오른쪽 칸 폭: 남는 폭에 맞춰 420~520 (폰 가로 글자 130%는 UI 폭 약 1120)
	# 조금 모자라면 _fit_panels가 폭에 맞춰 살짝 줄인다 (한 칸으로 두면 높이 탓에 0.57배까지 줄었다)
	var rw := clampf(session.ui_root.size.x - BinduSession.PREP_W - 12.0 - 24.0, 420.0, 520.0)
	var two := session.ui_root.size.x >= 960.0
	var w := floorf(rw) if two else BinduSession.PREP_W
	if prep_cols.columns == (2 if two else 1) and prep_cols.get_meta("laid", -1.0) == w:
		return
	prep_cols.set_meta("laid", w)
	prep_cols.columns = 2 if two else 1
	for k: Control in prep_right.get_children():
		k.custom_minimum_size.x = w
		k.size_flags_horizontal = Control.SIZE_FILL if two else Control.SIZE_SHRINK_CENTER  # 긴 글로 넓어진 줄에 다른 줄도 폭을 맞춘다
	for l: Control in prep_right.find_children("*", "Label", true, false):
		if l.has_meta("sub_w"):
			l.custom_minimum_size.x = w - 220.0


func _prep_sb(hov := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16) if hov else Color(0.07, 0.085, 0.115)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _prep_name(t: String) -> Label:
	var n := Label.new()
	n.text = t
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.custom_minimum_size = Vector2(96, 0)
	n.add_theme_font_size_override("font_size", Meta.fs(15))
	n.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	return n


func _prep_main() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", Meta.fs(19))
	return l


func _prep_sub() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(BinduSession.PREP_W - 220.0, 0)
	l.set_meta("sub_w", true)
	l.add_theme_font_size_override("font_size", Meta.fs(14))
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	return l


## 준비 화면 한 줄: [이름표 | ◀ | 가운데 글(+작은 설명) | ▶]. 가운데 글을 눌러도 다음으로.
## 가운데 Label을 돌려주고, 작은 설명 Label은 meta "sub", 줄 전체는 meta "row".
func _prep_row(box: BoxContainer, title: String, prev: Callable, next: Callable) -> Label:
	var session: BinduSession = self.session
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(BinduSession.PREP_W, 64 if session.viewport_system._phone() else 56)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_stylebox_override("panel", _prep_sb())
	box.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	h.add_child(_prep_name(title))
	var bs := Vector2(56, 52) if OS.has_feature("mobile") else Vector2(40, 40)
	var a := Button.new()
	a.text = "◀"
	a.flat = true
	a.focus_mode = Control.FOCUS_NONE
	a.custom_minimum_size = bs
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	a.pressed.connect(prev)
	h.add_child(a)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var l := _prep_main()
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			next.call()
			l.accept_event())
	v.add_child(l)
	var sub := _prep_sub()
	v.add_child(sub)
	var b := Button.new()
	b.text = "▶"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = bs
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(next)
	h.add_child(b)
	l.set_meta("sub", sub)
	l.set_meta("row", row)
	return l


## 준비 화면 맵 고르기: 맵 카드 다섯 장(이름·길 모양·규칙·친화 속성 그림·최고 웨이브) + 아래 고른 맵 설명.
## 2026-11-01 사용자 요청 "맵 친화 속성도 게임 시작 전에 알 수 있게, 텍스트 대신 카드 형식으로". ←/→도 그대로.
func _build_map_cards(box: BoxContainer) -> Label:
	var session: BinduSession = self.session
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(BinduSession.PREP_W, 0)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var psb := _prep_sb()
	psb.content_margin_left = 8
	psb.content_margin_top = 8
	psb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", psb)
	box.add_child(row)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	map_cards.clear()
	var cw := floorf((BinduSession.PREP_W - 16.0 - 8.0 * (Meta.MAP_IDS.size() - 1)) / Meta.MAP_IDS.size())
	for id in Meta.MAP_IDS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(cw, 150 if session.viewport_system._phone() else 138)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("map", id)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())  # 바탕·테두리는 _draw_map_card가 (고른 맵 강조)
		b.pressed.connect(func():
			if Meta.map_id != id:
				Meta.map_id = id
				session.sfx.play("place")
				_refresh_menu()
				session.progression_system._save_best()
				session.queue_redraw())
		b.draw.connect(_draw_map_card.bind(b))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		h.add_child(b)
		map_cards.append(b)
	var l := _prep_main()
	v.add_child(l)
	var sub := _prep_sub()
	sub.custom_minimum_size = Vector2(BinduSession.PREP_W - 40.0, 0)
	v.add_child(sub)
	l.set_meta("sub", sub)
	l.set_meta("row", row)
	return l


## 맵 카드 한 장: 고른 맵은 밝은 테두리. 위 이름, 가운데 길 모양, 규칙 이름, 친화 속성 그림, 최고 웨이브.
func _draw_map_card(b: Button) -> void:
	var session: BinduSession = self.session
	var id: String = b.get_meta("map")
	var m: Dictionary = Meta.MAPS[id]
	var sel := Meta.map_id == id
	var hov := b.is_hovered()
	var r := Rect2(Vector2.ZERO, b.size)
	var acc := Color(0.75, 0.85, 1.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = (m["bg"] as Color).lightened(0.12 if sel else (0.07 if hov else 0.03))
	sb.border_color = Color(1, 0.85, 0.45) if sel else Color(1, 1, 1, 0.25 if hov else 0.1)
	sb.set_border_width_all(3 if sel else 1)
	sb.set_corner_radius_all(8)
	b.draw_style_box(sb, r)
	var cx := b.size.x / 2.0
	var nc := Color(1, 0.92, 0.7) if sel else Color(1, 1, 1, 0.85)
	b.draw_string(session.ui_font, Vector2(0, 22), m["name"], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, Meta.fs(16), nc)
	if id in Meta.TRIAL_MAPS:
		b.draw_string(session.ui_font, Vector2(0, 35), "시험", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 10, Color(1, 1, 1, 0.45))
	_draw_map_path(b, id, Vector2(cx, 62.0), 20.0, Color(acc, 0.75 if sel else 0.5))
	var rt := MapRule.rule_text(id).get_slice(":", 0)
	b.draw_string(session.ui_font, Vector2(0, 100), rt, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, Meta.fs(13), Color(BinduSession.MAP_AFF_COLOR, 0.95 if sel else 0.7))
	# 친화 속성 그림 (자주 나오고 피해 +)
	var es: Array = MapRule.aff("elem", id)
	var gap := 26.0
	var x0 := cx - gap * (es.size() - 1) / 2.0
	for i in es.size():
		Glyph.elem(b, es[i], Vector2(x0 + gap * i, 118.0), 9.0)
	var best := Meta.best_of(Meta.run_key(id))
	if best[0] > 0:
		b.draw_string(session.ui_font, Vector2(0, b.size.y - 6.0), "최고 %d" % best[0], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, Meta.fs(11), Color(1, 1, 1, 0.5))


## 맵 카드 가운데 길 모양 그림 (구체가 들어오는 모양). c 가운데, s 반지름.
func _draw_map_path(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c, 3.0, Color(1, 0.9, 0.6))
	match id:
		"plain":
			for k in 3:
				var d := Vector2.from_angle(-PI / 2.0 + k * TAU / 3.0)
				ci.draw_line(c + d * s * 1.5, c + d * s * 0.45, col, 2.0)
		"spiral":
			var pts := PackedVector2Array()
			for i in 40:
				var t := i / 39.0
				pts.append(c + Vector2.from_angle(t * TAU * 1.4) * s * (1.5 - t * 1.1))
			ci.draw_polyline(pts, col, 2.0)
		"cross":
			for k in 4:
				var d := Vector2.from_angle(k * PI / 2.0)
				ci.draw_line(c + d * s * 1.5, c + d * s * 0.45, col, 3.0)
		"storm":
			for k in 6:
				var a := k * TAU / 6.0 + 0.3
				var d := Vector2.from_angle(a)
				ci.draw_line(c + d * s * 1.5, c + d * s * 1.0, Color(col, 0.4 + 0.1 * (k % 3)), 2.0)
			ci.draw_arc(c, s * 0.75, 0.6, 2.4, 10, Color(col, 0.6), 1.5)
			ci.draw_arc(c, s * 0.75, 3.7, 5.5, 10, Color(col, 0.6), 1.5)
		"line":
			ci.draw_line(c + Vector2(-s * 2.2, 0), c + Vector2(s * 2.2, 0), col, 3.0)
			ci.draw_line(c + Vector2(-s * 2.2, -6), c + Vector2(-s * 2.2, 6), Color(1, 0.9, 0.6, 0.8), 2.0)


## 준비 화면 줄 글: 가운데 글과 작은 설명 (설명이 비면 숨김).
func _prep_set(l: Label, main_t: String, sub_t: String) -> void:
	var session: BinduSession = self.session
	l.text = main_t
	var sub: Label = l.get_meta("sub")
	sub.text = session.patchlog_system._kr_keep(sub_t)
	sub.visible = sub_t != ""


func _menu_row(box: BoxContainer, prev: Callable, next: Callable, w := 560.0) -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	# 폰에선 화면이 작아 화살표 버튼이 손가락보다 작다: 버튼을 키우고 가운데 글을 눌러도 다음으로 (2026-10-31)
	var bs := Vector2(64, 56) if OS.has_feature("mobile") else Vector2(44, 40)
	var a := Button.new()
	a.text = "◀"
	a.focus_mode = Control.FOCUS_NONE
	a.custom_minimum_size = bs
	a.pressed.connect(prev)
	row.add_child(a)
	var l := Label.new()
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			next.call()
			l.accept_event())
	row.add_child(l)
	var b := Button.new()
	b.text = "▶"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = bs
	b.pressed.connect(next)
	row.add_child(b)
	return l


## 맵 규칙 그림: 십자로 길목 띠(쉬는 시간), 폭풍 바람 줄기와 화살표.
func _draw_map_rule(c: Vector2, now: float) -> void:
	var session: BinduSession = self.session
	if session.title_label.visible:
		return
	if MapRule.is_map("cross") and session.phase != BinduSession.Phase.WAVE:
		for a in session.lanes:
			var u := Vector2.from_angle(a)
			var e := session.field_view_system._edge_point(c, u)
			var n := u.orthogonal() * MapRule.LANE_W
			session.draw_colored_polygon(PackedVector2Array([c + u * 60.0 + n, e + n, e - n, c + u * 60.0 - n]), Color(BinduSession.MAP_AFF_COLOR, 0.05))
			session.draw_line(c + u * 60.0 + n, e + n, Color(BinduSession.MAP_AFF_COLOR, 0.18), 1.0)
			session.draw_line(c + u * 60.0 - n, e - n, Color(BinduSession.MAP_AFF_COLOR, 0.18), 1.0)
	var w := MapRule.wind_dir(session.lanes)
	if w != Vector2.ZERO:
		# 바람 줄기: 화면을 가로질러 흐르는 짧은 선 (웨이브 중에는 옅게)
		var vr := session.viewport_system.arena()
		var al := 0.16 if session.phase != BinduSession.Phase.WAVE else 0.07
		for i in 24:
			var h := Vector2(fmod(i * 0.6180339, 1.0), fmod(i * 0.4142135 + 0.13, 1.0))
			var p := vr.position + Vector2(h.x * vr.size.x, h.y * vr.size.y)
			var off := fmod(now * 90.0 + i * 37.0, 260.0)
			p += w * off
			p = Vector2(vr.position.x + fposmod(p.x - vr.position.x, vr.size.x), vr.position.y + fposmod(p.y - vr.position.y, vr.size.y))
			session.draw_line(p, p + w * 34.0, Color(1, 1, 1, al * (1.0 - off / 260.0)), 2.0)
		# 화살표: 중앙 위
		var at := c + Vector2(0, -150.0)
		var col := Color(1, 1, 1, 0.55 if session.phase != BinduSession.Phase.WAVE else 0.25)
		session.draw_line(at - w * 40.0, at + w * 30.0, col, 4.0)
		session.draw_colored_polygon(PackedVector2Array([at + w * 46.0, at + w * 22.0 + w.orthogonal() * 12.0, at + w * 22.0 - w.orthogonal() * 12.0]), col)


## 시작 화면 맵 줄: 맵 규칙·친화 카드 (시험)
func _refresh_menu() -> void:
	var session: BinduSession = self.session
	var m: Dictionary = Meta.MAPS[Meta.map_id]
	var best := Meta.best_of(Meta.run_key())
	# 폰: 맵 설명 줄은 뺀다 (도움말·도감에 있고, 줄이 많으면 시작 화면 전체가 줄어 버튼이 작아진다)
	# 맵 카드 아래: 고른 맵 이름·규칙, 작은 설명에 맵 설명·친화 카드·최고 기록 (폰은 맵 설명 줄만 뺌)
	var mr := MapRule.rule_text() + " (시험)" if MapRule.on() else ""
	_prep_set(map_label, session.ui_layout_system._kh("%s%s" % [Meta.map_name(), "" if session.touch_ui else "  (←/→)"]), "%s%s최고 기록%s · 웨이브 %d · 점수 %s" % ["" if session.viewport_system._phone() else m["desc"].replace("\n", " ") + "\n", "%s\n친화 카드 (자주 나옴·피해 +%d%%): %s\n" % [mr, roundi(Rules.t("map_aff_dmg") * 100), MapRule.aff_text()] if MapRule.on() else "", " (쉽게 모드)" if Modes.easy() else "", best[0], session.num(best[1])])
	for mc in map_cards:
		mc.queue_redraw()
	session.flip_label.get_meta("row").visible = Meta.map_id == "line"
	_prep_set(session.flip_label, session.ui_layout_system._kh("%s  (F)" % ("왼쪽 → 문은 오른쪽 끝" if Meta.line_flip else "오른쪽 → 문은 왼쪽 끝")), "")
	var ra := [Rules.NAMES[Meta.rules], " (시험)" if Meta.rules in Rules.TRIAL_IDS else "", "(눌러서 바꾸기)" if session.touch_ui else "(↑/↓)", session.onboarding_system._wrap_parts(Patch.text("rules_desc", str(Meta.rules), Rules.DESCS[Meta.rules]), " · ", 550.0, 18)]
	# 폰: 규칙 설명 줄도 뺀다 (이름만, 자세한 건 도움말·모드 창)
	_prep_set(rules_label, session.ui_layout_system._kh("%s%s  %s" % ra.slice(0, 3)), "" if session.viewport_system._phone() else ra[3].replace("\n", " · "))
	rules_label.get_meta("row").visible = Meta.games > 0  # 규칙 버전 고르기는 첫 판을 끝낸 뒤에 (그 전엔 버전 1)
	session.modes_btn.visible = Meta.games > 0  # 모드도
	var sk := Skill.set_ids(Meta.skill_set)
	_prep_set(skill_label, Skill.combo_name(Meta.skill_set) + ("  (눌러서 바꾸기)" if session.touch_ui else ""),
		"" if session.viewport_system._phone() else "웨이브 중 %s · %s" % ["%s: %s" % [Skill.NAMES[sk[0]], Skill.desc(sk[0])], "%s: %s" % [Skill.NAMES[sk[1]], Skill.desc(sk[1])]])
	skill_label.get_meta("row").visible = Rules.t("skill_on") > 0.0
	_prep_set(modes_label, "없음" if Modes.on.is_empty() else Modes.names(), "판을 어렵게·쉽게 바꾸는 규칙 · 점수 배율이 붙어요" if Modes.on.is_empty() else "점수 x%.2f" % Modes.mul())
	if session.modes_panel.visible:
		_refresh_modes()
	var ts: Dictionary = Meta.TOWER_SKINS[Meta.tower_skin]
	skin_label.text = "오브젝트 모양: " + ts["name"]
	var cs: Dictionary = Meta.CORE_SKINS[Meta.core_skin]
	core_label.text = "중앙 모양: " + cs["name"]
	session.best_wave = best[0]
	session.best_score = best[1]
	normal_info.text = "맵·규칙·모드를 골라 한 판\n%s · %s\n최고 웨이브 %d" % [Meta.map_name(), Rules.NAMES[Meta.rules], best[0]]


## 회랑 맵: 구체가 오는 쪽(좌우)을 바꾼다. 기록은 나누지 않는다 (좌우만 바뀐 같은 판).
func _toggle_flip() -> void:
	var session: BinduSession = self.session
	if Meta.map_id != "line":
		return
	Meta.line_flip = not Meta.line_flip
	session.sfx.play("place")
	_refresh_menu()
	session.progression_system._save_best()
	session.queue_redraw()


func _cycle_map(d: int) -> void:
	var session: BinduSession = self.session
	var i := Meta.MAP_IDS.find(Meta.map_id)
	Meta.map_id = Meta.MAP_IDS[(i + d + Meta.MAP_IDS.size()) % Meta.MAP_IDS.size()]
	session.sfx.play("place")
	_refresh_menu()
	session.progression_system._save_best()
	session.queue_redraw()


## 오른쪽 설명: 상한은 규칙 버전에 따라 다르다.
var legend_heads := PackedStringArray()
func _draw_legend_icons() -> void:
	var session: BinduSession = self.session
	var lh := session.legend.get_line_height() + session.legend.get_theme_constant("line_spacing")
	var fs := session.legend.get_theme_font_size("font_size")
	var w := session.legend.size.x - 32.0 - 8.0
	var row := 0
	for i in mini(BinduSession.LEGEND_ICONS.size(), legend_heads.size()):
		var c := Vector2(16.0, 8.0 + lh * row + session.legend.get_line_height() / 2.0)
		row += session.onboarding_system._wrap_words(session.patchlog_system._kr_keep(legend_heads[i]), w, fs).count("\n") + 1
		var id: String = BinduSession.LEGEND_ICONS[i]
		if id == "tower":
			Glyph.ui(session.legend, id, c, 6.5, Color(1, 1, 1, 0.7))
		else:
			Glyph.kind(session.legend, id, c, 7.0, Color(0.95, 0.85, 0.6))


func _refresh_legend() -> void:
	var session: BinduSession = self.session
	# 줄 앞 그림(카드 종류)은 legend.draw에서 (LEGEND_ICONS 순서). 그림이 있어 머리 글·긴 설명을 뺐다
	var cap_e := "%d종까지" % Rules.max_elems if Rules.max_elems < Rules.NO_CAP else "종류마다 공속 -%d%%" % roundi(Rules.tax_step * 100)
	var cap_m := "종류별 %d · 합 %d" % [Rules.max_mod, Rules.mod_total] if Rules.max_mod < Rules.NO_CAP else "쌓을수록 절반"
	legend_heads = PackedStringArray([
		"공격방식 · 직선탄에 1번, 같은 것 Lv↑",
		"속성 · 추가 효과, " + cap_e,
		"강화 · 공격 변형, " + cap_m,
		"연계 · 주변 오브젝트와 함께",
		"발동 · 조건이 맞으면 추가 공격",
		"새 오브젝트 = 직선탄 + 속성 1",
		"조합 · 두 속성이 만나면 (%d/%d)" % [Meta.codex.size(), Elem.REACTIONS.size()],
	])
	var lines := legend_heads.duplicate()
	# 반응이 91개라 만들어 본 반응만 한 줄에 세 개씩 (나머지는 개수만, 도감과 같은 기록).
	# 줄 수는 legend_rx_rows까지: 많이 찾으면 설명이 화면 아래 설정 버튼까지 덮던 것 (_process에서 맞춤)
	var rs: Array = Elem.REACTIONS.filter(func(r): return Meta.codex.has(r["id"]))
	var shown := 0
	session.legend_rows = 0
	for i in range(0, rs.size(), 3):
		if session.legend_rows >= session.legend_rx_rows:
			break
		var row := PackedStringArray()
		for r in rs.slice(i, i + 3):
			row.append("%s+%s %s" % [Elem.NAMES[r["a"]], Elem.NAMES[r["b"]], r["name"]])
		lines.append("   ".join(row))
		shown += row.size()
		session.legend_rows += 1
	var k := "" if session.touch_ui else " K"
	if shown < rs.size():
		var left := Elem.REACTIONS.size() - rs.size()
		lines.append("외 %d개%s (모두 도감%s)" % [rs.size() - shown, " · 못 만난 조합 %d개" % left if left > 0 else "", k])
	elif rs.size() < Elem.REACTIONS.size():
		lines.append("못 만난 조합 %d개 (도감%s)" % [Elem.REACTIONS.size() - rs.size(), k])
	session.legend.text = session.patchlog_system._kr_keep("\n".join(lines))
	session.legend.size.y = 380.0  # Label은 글이 줄어도 저절로 작아지지 않는다 (글이 길면 다시 늘어남)


## 규칙 버전 바꾸기: 기록은 버전마다 따로.
func _cycle_skill(d: int) -> void:
	var session: BinduSession = self.session
	Meta.skill_set = posmod(Meta.skill_set + d, Skill.SETS.size())
	session.sfx.play("place")
	_refresh_menu()
	session.progression_system._save_best()


func _cycle_rules(d: int) -> void:
	var session: BinduSession = self.session
	var i := Rules.IDS.find(Meta.rules)
	Meta.rules = Rules.IDS[(i + d + Rules.IDS.size()) % Rules.IDS.size()]
	session.run_flow_system._apply_rules()
	session.sfx.play("place")
	_refresh_menu()
	session.progression_system._save_best()
	session.hud_system._update_hud(true)


## 잠긴 스킨은 건너뛰고, 잠긴 것이 있으면 해금 조건을 알려 준다.
func _cycle_skin(kind: String, d: int) -> void:
	var session: BinduSession = self.session
	var ids: Array = Meta.TOWER_SKIN_IDS if kind == "tower" else Meta.CORE_SKIN_IDS
	var defs: Dictionary = Meta.TOWER_SKINS if kind == "tower" else Meta.CORE_SKINS
	var cur: String = Meta.tower_skin if kind == "tower" else Meta.core_skin
	var i := ids.find(cur)
	var locked := PackedStringArray()
	for k in ids.size():
		i = (i + d + ids.size()) % ids.size()
		var need: String = defs[ids[i]]["need"]
		if Meta.unlocked(need):
			break
		locked.append("%s: %s" % [defs[ids[i]]["name"], Meta.ACHIEVEMENTS[need]["name"]])
	if kind == "tower":
		Meta.tower_skin = ids[i]
	else:
		Meta.core_skin = ids[i]
	if not locked.is_empty():
		session.hud_system._show_toast("잠김 - " + ", ".join(locked) + " 업적으로 해금")
	session.sfx.play("place")
	_refresh_menu()
	session.progression_system._save_best()
	for t in session.towers.get_children():
		t.queue_redraw()


func _toggle_codex() -> void:
	var session: BinduSession = self.session
	if not session.codex_panel.visible:
		session.settings_panel.visible = false
		session.records_panel.visible = false
		session.help_label.visible = false
		session.notes_panel.visible = false
		session.modes_panel.visible = false
	if session.vote_panel.visible:
		session.vote_panel.hide_panel()
	session.codex_panel.fit(session.ui_root.size, session.viewport_system._phone())
	session.codex_panel.toggle()
	if session.codex_panel.visible:
		session.net.ach_rates()


## 다음 패치 투표 창. 판 끝난 화면에서 열면 이번 판에 고른 카드·특성이 맨 앞 탭.
func _toggle_vote(from_run := false) -> void:
	var session: BinduSession = self.session
	if not session.vote_panel.visible:
		session.settings_panel.visible = false
		session.records_panel.visible = false
		session.help_label.visible = false
		session.notes_panel.visible = false
		session.modes_panel.visible = false
		session.codex_panel.visible = false
	session.vote_panel.toggle(_vote_run_keys() if from_run else [])


## 이번 판에 고른 것 (통계 키, 고른 차례대로, 겹치지 않게).
func _vote_run_keys() -> Array:
	var session: BinduSession = self.session
	var out := []
	for e in session.run_log:
		var p := str(e.get("p", ""))
		if p != "" and not out.has(p):
			out.append(p)
	return out


func _toggle_records() -> void:
	var session: BinduSession = self.session
	session.records_panel.visible = not session.records_panel.visible
	session.board_box.visible = false
	session.board_ugc_panel.visible = false
	if not session.records_panel.visible:
		return
	session.leaderboard_system._records_fit()
	var lines := PackedStringArray(["[맵별 최고 기록 · %s]   (아무 곳이나 %s)" % [Rules.NAMES[Meta.rules], "누르면 닫기" if session.touch_ui else "클릭: 닫기"]])
	for id in Meta.MAP_IDS:
		var b := Meta.best_of(Meta.key(id))
		var e := Meta.best_of(Meta.key(id) + Meta.EASY_TAG)  # 쉽게 모드를 쓴 판은 따로
		lines.append("  %s: 웨이브 %d · 점수 %s%s" % [Meta.map_name(id), b[0], session.num(b[1]), "   (쉽게 모드: 웨이브 %d · 점수 %s)" % [e[0], session.num(e[1])] if e[0] > 0 else ""])
	# 규칙 버전끼리 비교하기 쉽게: 지금 맵의 버전별 최고 웨이브
	var vers := PackedStringArray()
	for r in Rules.IDS:
		vers.append("%s: %d" % [Rules.NAMES[r], Meta.best_of(Meta.key(Meta.map_id, r))[0]])
	lines.append("  %s 규칙별 최고 웨이브  %s" % [Meta.map_name(Meta.map_id), " · ".join(vers)])
	# 2026-10-30 이전 규칙(버전 1~5)의 기록은 따로 보관해 보여 준다
	var olds := PackedStringArray()
	for r in Rules.OLD_IDS:
		var w: int = Meta.best_of(Meta.key(Meta.map_id, r, true))[0]
		if w > 0:
			olds.append("버전 %d: %d" % [r, w])
	if not olds.is_empty():
		lines.append("  이전 규칙 최고 웨이브  %s" % " · ".join(olds))
	lines.append("  총 처치 %s · 플레이 %d판" % [session.num(Meta.total_kills), Meta.games])
	lines.append("")
	# 업적은 도감 업적 탭에 진행 막대와 함께 (55개라 여기에 다 쓰면 창이 넘친다). 등급마다 수만
	var tiers := PackedStringArray()
	for tid in Ach.TIER_IDS:
		var of_t := Ach.LIST.filter(func(a): return a["tier"] == tid)
		tiers.append("%s %d/%d" % [Ach.TIERS[tid]["name"], of_t.filter(func(a): return Meta.achieved.has(a["id"])).size(), of_t.size()])
	lines.append("[업적] %d / %d   %s   (도감%s 업적 탭)" % [Meta.achieved.size(), Ach.LIST.size(), " · ".join(tiers), "" if session.touch_ui else "(K)"])
	if Meta.title != "":
		lines.append("  칭호: " + Meta.ACHIEVEMENTS[Meta.title]["name"])
	lines.append("")
	lines.append("[조합 도감] %d / %d   (모든 조합은 도감%s 조합 탭)" % [Meta.codex.size(), Elem.REACTIONS.size(), "" if session.touch_ui else "(K)"])
	# 찾은 반응만 이어 쓴다. 모르는 칸마다 ???를 쓰면 반응이 91개라 창이 화면 높이만큼 길어져 글자가 읽을 수 없게 작아졌다
	var found := PackedStringArray()
	for r in Elem.REACTIONS:
		if Meta.codex.has(r["id"]):
			found.append("%s(%s+%s)" % [r["name"], Elem.NAMES[r["a"]], Elem.NAMES[r["b"]]])
	if not found.is_empty():
		# 많이 찾아도 4줄까지 (다 찾으면 16줄이 넘어 창 전체가 읽을 수 없게 작아졌다). 나머지는 도감에서
		var k := found.size()
		var wl := session.onboarding_system._wrap_words(", ".join(found), 600.0, 15).split("\n")
		while wl.size() > 4 and k > 1:
			k -= 1
			wl = session.onboarding_system._wrap_words(", ".join(found.slice(0, k)) + " 외 %d개" % (found.size() - k), 600.0, 15).split("\n")
		for l in wl:
			lines.append("  " + l)
	session.records_panel.text = session.patchlog_system._kr_keep("\n".join(lines))


# ---------- 온라인 ----------

## 서버 응답(켤 때, 시작 화면으로 돌아올 때): 시작 화면이면 받은 패치를 바로 적용하고, 새 버전·공지를 띄운다.
func _toggle_settings() -> void:
	var session: BinduSession = self.session
	session.settings_panel.visible = not session.settings_panel.visible
	if account_label:
		account_label.text = Account.label()


# ---------- 모드 ----------

## 모드 창: 어렵게·쉽게 두 묶음. 누르면 켜고 끄며, 반대 모드는 저절로 꺼진다. 효과는 버튼에 바로 적는다 (터치는 마우스 올리기가 없음).
func _build_modes(root: Control, sb: StyleBox) -> void:
	var session: BinduSession = self.session
	session.modes_panel = PanelContainer.new()
	session.modes_panel.set_anchors_preset(Control.PRESET_CENTER)
	session.modes_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	session.modes_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	session.modes_panel.add_theme_stylebox_override("panel", sb.duplicate())
	session.modes_panel.visible = false
	root.add_child(session.modes_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	session.modes_panel.add_child(v)
	var t := Label.new()
	t.text = "모드 (시험)   (Esc: 닫기)"
	t.add_to_group("key_hint")
	t.add_theme_font_size_override("font_size", Meta.fs(22))
	v.add_child(t)
	modes_head = Label.new()
	modes_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modes_head.custom_minimum_size = Vector2(620, 0)
	modes_head.add_theme_font_size_override("font_size", Meta.fs(16))
	v.add_child(modes_head)
	_build_easy_notice(v)
	for hard in [true, false]:
		var l := Label.new()
		l.text = "어렵게 (점수 올라감)" if hard else "쉽게 (점수 내려감 · 쉽게 모드 리더보드 · 최고 기록 따로)"
		l.add_theme_font_size_override("font_size", Meta.fs(17))
		l.add_theme_color_override("font_color", Color(1, 0.65, 0.5) if hard else Color(0.6, 0.85, 1.0))
		v.add_child(l)
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 6)
		v.add_child(g)
		for id in Modes.ORDER:
			if Modes.LIST[id]["hard"] != hard:
				continue
			var b := Button.new()
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(306, 54)
			if session.viewport_system._phone():
				# 폰: 커진 글자로 설명 줄이 길어져 창이 화면 밖으로 나가던 것 → 칸 폭에서 접는다
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.custom_minimum_size.x = clampf((session.viewport_system._phone_ui_w() - 60.0) / 2.0, 306.0, 470.0)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", Meta.fs(15))
			b.add_theme_color_override("font_pressed_color", Color(1, 0.88, 0.45))
			b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.88, 0.45))
			b.pressed.connect(func(): _toggle_mode(id))
			g.add_child(b)
			modes_btns[id] = b
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for spec in [["모두 끄기", _modes_off], ["닫기", _toggle_modes]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(spec[1])
		row.add_child(b)
	session.hud_system._phone_scroll(session.modes_panel)


func _toggle_modes() -> void:
	var session: BinduSession = self.session
	session.modes_panel.visible = not session.modes_panel.visible
	if session.modes_panel.visible:
		_refresh_modes()


func _modes_off() -> void:
	Modes.on.clear()
	_modes_changed()


func _toggle_mode(id: String) -> void:
	var was_easy := Modes.easy()
	Modes.toggle(id)
	_modes_changed()
	if Modes.easy() and not was_easy and not _easy_notice_off():
		easy_notice_skip.button_pressed = false
		easy_notice.visible = true


func _build_easy_notice(v: VBoxContainer) -> void:
	var session: BinduSession = self.session
	easy_notice = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.16, 0.26, 0.97)
	sb.border_color = Color(0.6, 0.85, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	easy_notice.add_theme_stylebox_override("panel", sb)
	easy_notice.visible = false
	v.add_child(easy_notice)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	easy_notice.add_child(box)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	l.add_theme_font_size_override("font_size", Meta.fs(17))
	l.text = session.patchlog_system._kr_keep("쉽게 모드를 켰어요\n쉽게 모드를 하나라도 켠 판은 일반 리더보드에 오르지 않고 \"쉽게 모드\" 리더보드에만 올라가요. 어렵게 모드와 함께 켜도 같아요. 최고 기록도 따로 세요.")
	box.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	easy_notice_skip = CheckBox.new()
	easy_notice_skip.text = "다시 보지 않기"
	easy_notice_skip.add_theme_font_size_override("font_size", Meta.fs(16))
	easy_notice_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(easy_notice_skip)
	var ok_btn := Button.new()
	ok_btn.text = "확인"
	ok_btn.custom_minimum_size = Vector2(120, 44)
	ok_btn.pressed.connect(_close_easy_notice)
	row.add_child(ok_btn)


func _close_easy_notice() -> void:
	if easy_notice_skip.button_pressed:
		var cfg := ConfigFile.new()
		cfg.load(Tutorial.PATH)
		cfg.set_value("notice", BinduSession.EASY_NOTICE_KEY, true)
		cfg.save(Tutorial.PATH)
	easy_notice.visible = false


func _easy_notice_off() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(Tutorial.PATH) == OK and cfg.get_value("notice", BinduSession.EASY_NOTICE_KEY, false) == true


## 고른 모드를 저장하고 규칙·기록 표시를 다시 맞춘다 (시작 화면에서만 바뀐다).
func _modes_changed() -> void:
	var session: BinduSession = self.session
	Meta.modes = Array(Modes.on)
	if not Modes.easy():
		easy_notice.visible = false
	session.run_flow_system._apply_rules()
	session.sfx.play("place")
	_refresh_menu()
	session.progression_system._save_best()
	_refresh_modes()


func _refresh_modes() -> void:
	var session: BinduSession = self.session
	for id in modes_btns:
		var b: Button = modes_btns[id]
		var d: Dictionary = Modes.LIST[id]
		b.set_pressed_no_signal(Modes.has(id))
		b.text = "%s %s  %s\n   %s" % ["●" if Modes.has(id) else "○", d["name"], Modes.pct(Modes.score_of(id)), d["desc"]]
	var head := "점수 x%.2f (%s)" % [Modes.mul(), Modes.pct(Modes.mul())] if not Modes.on.is_empty() else "고른 모드 없음"
	if Modes.easy():
		head += " · 쉽게 모드: 쉽게 모드 리더보드, 최고 기록 따로"
	else:
		head += " · 여러 개를 고르면 배율을 곱해요 (x%.1f~x%.1f)" % [Modes.MUL_MIN, Modes.MUL_MAX]
	modes_head.text = session.patchlog_system._kr_keep(head)


func _toggle_fullscreen() -> void:
	if OS.has_feature("mobile"):
		return
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## 음량 한 줄: 이름 + 퍼센트 + 슬라이더 (0~100%, 5% 단위). 같은 이름 줄은 설정 창·소리 창 어디서 바꿔도 서로 맞춤
func _volume_row(parent: Container, title: String, getter: Callable, setter: Callable, label_w := 150.0, slider_w := 240.0) -> HSlider:
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.text = "%s %d%%" % [title, roundi(getter.call() * 100.0)]
	lab.custom_minimum_size = Vector2(label_w, 0)
	row.add_child(lab)
	var slider := HSlider.new()
	slider.name = "Vol_" + title
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = getter.call()
	slider.custom_minimum_size = Vector2(slider_w, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v):
		setter.call(v)
		_apply_volume()
		_sync_volume_ui()
		session.progression_system._save_best())
	row.add_child(slider)
	parent.add_child(row)
	if not volume_sliders.has(title):
		volume_sliders[title] = slider
	volume_rows.append([title, slider, lab, getter])
	return slider


## 모든 음량 줄의 슬라이더·글과 소리 창 켜기 버튼을 지금 값에 맞춤
func _sync_volume_ui() -> void:
	for r in volume_rows:
		var v: float = r[3].call()
		r[1].set_value_no_signal(v)
		r[2].text = "%s %d%%" % [r[0], roundi(v * 100.0)]
	if sound_toggle:
		sound_toggle.set_pressed_no_signal(not session.sfx.muted)
		sound_toggle.text = "소리 켜짐" if not session.sfx.muted else "소리 꺼짐"


## 소리 버튼 작은 창: 소리 켜기·끄기 + 전체·배경음·효과음. 바깥을 누르거나 Esc·버튼을 다시 누르면 닫힘
func _build_sound_pop(root: Control) -> void:
	sound_pop = Control.new()
	sound_pop.set_anchors_preset(Control.PRESET_FULL_RECT)
	sound_pop.z_index = 24  # 일시정지 어둠(20)·창(22)·안내(23) 위
	sound_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	sound_pop.visible = false
	sound_pop.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_close_sound_pop())
	root.add_child(sound_pop)
	sound_panel = PanelContainer.new()
	var sb: StyleBox = session.settings_panel.get_theme_stylebox("panel").duplicate()
	sound_panel.add_theme_stylebox_override("panel", sb)
	sound_pop.add_child(sound_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	sound_panel.add_child(v)
	sound_toggle = CheckButton.new()
	sound_toggle.focus_mode = Control.FOCUS_NONE
	sound_toggle.tooltip_text = "소리 켜기·끄기 (M)"
	sound_toggle.toggled.connect(func(on):
		if on == session.sfx.muted:
			session.cards_system._toggle_mute())
	v.add_child(sound_toggle)
	_volume_row(v, "전체 음량", func(): return Meta.volume, func(x): Meta.volume = x, 160.0, 180.0)
	_volume_row(v, "배경음", func(): return Meta.music_volume, func(x): Meta.music_volume = x, 160.0, 180.0)
	_volume_row(v, "효과음", func(): return Meta.sfx_volume, func(x): Meta.sfx_volume = x, 160.0, 180.0)
	_sync_volume_ui()


func _toggle_sound_pop() -> void:
	if sound_pop.visible:
		_close_sound_pop()
		return
	_sync_volume_ui()
	sound_pop.visible = true
	sound_panel.reset_size()
	# 소리 버튼 바로 위, 오른쪽 끝을 버튼에 맞춤 (화면 밖으로 나가지 않게)
	var ui: Control = session.ui_root
	var k: float = ui.scale.x
	var br: Rect2 = session.mute_btn.get_global_rect()
	var b_pos: Vector2 = (br.position - ui.global_position) / k
	var b_end: Vector2 = (br.end - ui.global_position) / k
	var sz: Vector2 = sound_panel.get_combined_minimum_size()
	var x := clampf(b_end.x - sz.x, 8.0, ui.size.x - sz.x - 8.0)
	var y := clampf(b_pos.y - sz.y - 6.0, 8.0, ui.size.y - sz.y - 8.0)
	sound_panel.position = Vector2(x, y)


func _close_sound_pop() -> void:
	if sound_pop:
		sound_pop.visible = false


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Meta.volume, 0.001)))
	if session.sfx:
		session.sfx.set_levels(Meta.music_volume, Meta.sfx_volume)
