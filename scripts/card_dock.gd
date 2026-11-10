class_name CardDock
extends RefCounted
## 카드 팔레트와 전장 카메라는 독립적이다. 카드를 들면 팔레트만 접는다.
## 폰은 글자를 키워(Meta.fs) 버튼·카드도 K배 크게 쓴다 (fit_phone)
static var K := 1.0
static var CONTROL_HEIGHT := 36.0
static var HEADER_HEIGHT := CONTROL_HEIGHT + 16.0
static var FOOTER_HEIGHT := CONTROL_HEIGHT + 24.0
static var CARD_HEIGHT := 112.0
static var HEIGHT := HEADER_HEIGHT + CARD_HEIGHT + 8.0 + FOOTER_HEIGHT
static var SKIP_WIDTH := 224.0


## 폰이면 카드 줄·버튼을 키운다 (글 두 줄·아래 줄이 커진 글자에 맞게)
static func fit_phone() -> void:
	K = 1.22 if Meta.phone() else 1.0
	CONTROL_HEIGHT = roundf(36.0 * K)
	HEADER_HEIGHT = CONTROL_HEIGHT + 16.0
	FOOTER_HEIGHT = CONTROL_HEIGHT + 24.0
	CARD_HEIGHT = 144.0 if K > 1.0 else 112.0
	HEIGHT = HEADER_HEIGHT + CARD_HEIGHT + 8.0 + FOOTER_HEIGHT
	SKIP_WIDTH = roundf(224.0 * K)
var game
var panel: Panel
var footer: Panel
var skip_group: Panel
var controls_theme := make_controls_theme()
var side: FloatPanel  # 오브젝트·카드 정보창 (공용 떠 있는 창 틀: 옮기기·압정·접기·닫기)
var inspector_header: HBoxContainer  # 머리 줄의 창별 버튼 칸 (방향 변경·터치 자세히)
var direction_btn: Button
var close_btn: Button
var inspector_dismissed := false  # X로 닫으면 명시적으로 자세히를 다시 켤 때까지 유지
var dismissed_tower: Tower
var heading: Label
var detail: RichTextLabel
var scroll: ScrollContainer  # 설명창 안이 화면보다 길면 통째로 스크롤 (폰 자세히 등)
var pic: InfoPanel  # 설명창 그림 부분 (오브젝트 정보·카드 미리보기)
var state: Label
var focus_btn: Button
var hovered: Button
var inspected_tower: Tower
var shown_tower: Tower  # 설명창이 지금 보여 주는 오브젝트 (이 오브젝트는 절대 가리지 않는다)
var side_left := false  # 설명창이 왼쪽 위에 떠 있는지 (오브젝트를 덜 가리는 쪽)
var side_signature := ""
var board := Rect2()
var fit := 1.0
var pointer := Vector2.ZERO
var pending_card := {}
var press_origin := Vector2.ZERO
var pointer_id := -2  # -2: 없음, -1: 마우스, 0 이상: 터치
var card_dragging := false
var suppress_tap := false
var touch_capture := false
var touch_position := Vector2.ZERO
var read_pointer := -1
var reading_card: Dictionary = {}
var reading_review := false
var reading_return_cards := false
var inspect_return_cards := false
var brief: Label
var read_actions: HBoxContainer
var preview_actions: HBoxContainer
var preview_btn: Button
var preview_reveal_generation := 0
var expand_btn: Button
var use_btn: Button
var read_prev: Button
var read_next: Button
var edit_tools: HBoxContainer
var undo_btn: Button
var select_btn: Button
var select_all_btn: Button
var group_direction_btn: Button
var prio_btn: Button  # 표적 우선순위 (시험): 선택한 오브젝트들을 다음 우선순위로
var save_btn: Button
var review_btn: Button

static func surface() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("151e2c")
	box.border_color = Color("344358")
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(8)
	return box

static func make_controls_theme() -> Theme:
	var theme := Theme.new()
	theme.set_type_variation("ShortcutButton", "Button")
	for type in ["Button", "OptionButton"]:
		for state_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var box := surface()
			if state_name == "focus":
				box.bg_color = Color.TRANSPARENT
				box.border_color = Color("7798be")
			elif state_name == "hover":
				box.bg_color = Color("223149")
				box.border_color = Color("7798be")
			elif state_name in ["pressed", "hover_pressed"]:
				box.bg_color = Color("2a3945")
				box.border_color = Color("e6c476")
			elif state_name == "disabled":
				box.bg_color = Color("101722")
			theme.set_stylebox(state_name, type, box)
			if type == "Button":
				var shortcut := box.duplicate()
				shortcut.content_margin_right = 24
				theme.set_stylebox(state_name, "ShortcutButton", shortcut)
		for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			theme.set_color(color_name, type, Color("e1e9f4"))
		theme.set_color("font_disabled_color", type, Color("78889d"))
		theme.set_font_size("font_size", type, Meta.fs(15))
	theme.set_stylebox("panel", "PopupMenu", surface())
	var hover := surface()
	hover.bg_color = Color("223149")
	theme.set_stylebox("hover", "PopupMenu", hover)
	return theme

func _init(main) -> void:
	game = main
	fit_phone()
	panel = Panel.new()
	panel.name = "CardDock"
	panel.set_meta("layout_background", true)
	panel.z_index = 1
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0b101a")
	bg.border_color = Color("303c50")
	bg.border_width_top = 1
	panel.add_theme_stylebox_override("panel", bg)
	game.ui_root.add_child(panel)
	footer = Panel.new()
	footer.name = "ControlBarSurface"
	footer.set_meta("layout_background", true)
	footer.z_index = 1
	footer.add_theme_stylebox_override("panel", bg)
	game.ui_root.add_child(footer)
	skip_group = Panel.new()
	skip_group.name = "SkipControls"
	skip_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_group.set_meta("layout_background", true)
	skip_group.z_index = 2
	skip_group.add_theme_stylebox_override("panel", surface())
	skip_group.hide()
	game.ui_root.add_child(skip_group)
	state = Label.new()
	state.add_theme_font_size_override("font_size", Meta.fs(16))
	state.add_theme_color_override("font_color", Color("d9e5f5"))
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(state)
	side = FloatPanel.new("info", game, true)
	side.name = "CardInspector"
	side.z_index = 1
	side.style.set_content_margin_all(10)
	side.style.bg_color = Color("0b101a")  # 읽는 창은 뒤 전장이 비치지 않게 (DPS 표는 옅게 비침)
	side.fold_pressed.connect(func():
		Meta.panel_fold["info"] = not side.folded
		side.set_folded(not side.folded)
		game.progression_system._save_best())
	side.set_folded(Meta.panel_fold.get("info", false))
	game.ui_root.add_child(side)
	var content := side.body
	content.add_theme_constant_override("separation", 8)
	brief = Label.new()
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.add_theme_font_size_override("font_size", Meta.fs(14))
	brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(brief)
	read_actions = HBoxContainer.new()
	read_actions.add_theme_constant_override("separation", 6)
	content.add_child(read_actions)
	expand_btn = _action_button("전체 정보", read_actions, func():
		game.cards_system._set_cards_hidden(not game.cards_hidden))
	preview_btn = _action_button("공격 예시", read_actions, _toggle_attack_preview)
	preview_btn.tooltip_text = "F6: 정보창/전장 전환 · Tab: 버튼 이동 · Enter/Space: 실행"
	read_prev = _action_button("이전", read_actions, func(): cycle_read(-1))
	read_next = _action_button("다음", read_actions, func(): cycle_read(1))
	use_btn = _action_button("이 카드 들기", read_actions, func():
		if not reading_card.is_empty(): game.cards_system._on_pick(reading_card))
	inspector_header = side.tools
	expand_btn.reparent(inspector_header)
	heading = side.title
	heading.add_theme_font_size_override("font_size", Meta.fs(15))
	direction_btn = Button.new()
	direction_btn.text = "방향 변경"
	direction_btn.theme = controls_theme
	direction_btn.focus_mode = Control.FOCUS_NONE
	direction_btn.custom_minimum_size = Vector2(88, 36)
	direction_btn.pressed.connect(game.interaction_system._edit_selected_direction)
	inspector_header.add_child(direction_btn)
	close_btn = side.close_btn
	for button: Button in [side.pin_btn, side.fold_btn, close_btn]:
		button.focus_mode = Control.FOCUS_ALL
	close_btn.tooltip_text = "상세 닫기 (Esc)"
	side.close_pressed.connect(func(): close_inspector(true))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.draw_focus_border = true
	var scroll_focus := surface()
	scroll_focus.bg_color = Color.TRANSPARENT
	scroll_focus.border_color = Color("7798be")
	scroll_focus.set_border_width_all(2)
	scroll_focus.set_content_margin_all(0)
	scroll.add_theme_stylebox_override("focus", scroll_focus)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP  # 읽는 창의 스크롤은 뒤 전장으로 넘기지 않는다
	content.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	brief.reparent(column)
	read_actions.reparent(column)
	pic = InfoPanel.new(game)
	pic.hide()
	column.add_child(pic)
	preview_actions = HBoxContainer.new()
	content.add_child(preview_actions)
	preview_btn.reparent(preview_actions)
	detail = RichTextLabel.new()
	detail.add_theme_font_size_override("normal_font_size", Meta.fs(14))
	detail.add_theme_color_override("default_color", Color("c5cfdc"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.scroll_active = false
	detail.fit_content = true
	detail.mouse_filter = Control.MOUSE_FILTER_PASS
	detail.bbcode_enabled = false
	column.add_child(detail)
	panel.visible = false
	side.visible = false
	focus_btn = Button.new()
	focus_btn.theme = controls_theme
	focus_btn.focus_mode = Control.FOCUS_NONE
	focus_btn.add_theme_font_size_override("font_size", Meta.fs(14))
	focus_btn.pressed.connect(game.cards_system._toggle_focus_view)
	focus_btn.z_index = 10
	game.ui_root.add_child(focus_btn)
	edit_tools = HBoxContainer.new()
	edit_tools.name = "BattlefieldEditControls"
	edit_tools.add_theme_constant_override("separation", 6)
	edit_tools.z_index = 10
	game.ui_root.add_child(edit_tools)
	undo_btn = _action_button("되돌리기", edit_tools, func(): game.cards_system.undo_edit())
	undo_btn.tooltip_text = "최근 배치 되돌리기 (Ctrl/Cmd+Z) · 새 선택지 공개 뒤에는 제한"
	select_btn = _action_button("여러 개 선택", edit_tools, func(): game.interaction_system.toggle_additive_selection())
	select_all_btn = _action_button("전체 선택", edit_tools, func(): game.interaction_system.select_all())
	direction_btn.reparent(edit_tools)
	direction_btn.focus_mode = Control.FOCUS_ALL
	group_direction_btn = direction_btn
	prio_btn = _action_button("표적: 앞선", edit_tools, func(): cycle_selected_prio(1))
	prio_btn.tooltip_text = "표적 우선순위: 앞선·가까운·먼·강한·약한·무리 (G, Shift+G 거꾸로)"
	# 편집 버튼의 실행 뒤에는 방향키·Enter를 전장 편집으로 돌려준다.
	# 정보 읽기 버튼은 키보드로 연속 탐색할 수 있게 포커스를 유지한다.
	for field_action: Button in [undo_btn, select_btn, select_all_btn, group_direction_btn, prio_btn]:
		field_action.pressed.connect(field_action.release_focus)
	review_btn = _action_button("지난 웨이브", edit_tools, read_wave_review)
	save_btn = _action_button("저장 상태", game.ui_root, func():
		game.hud_system._show_toast(game.persistence_system.save_status_text() + " · " + ("멀티 판은 이어하기가 없어요" if game.mp_mode != "" else "전투 중 나가면 앞 쉬는 시간부터 이어집니다")))
	save_btn.z_index = 10

## 표적 우선순위 (시험): 선택한 내 오브젝트를 첫 오브젝트 기준 다음 우선순위로 모두 맞춘다.
func cycle_selected_prio(step := 1) -> void:
	var sel: Array = game.interaction_system.selected.filter(func(t): return is_instance_valid(t) and game.multiplayer_system._mine(t))
	if sel.is_empty():
		return
	var first: Tower = sel[0]
	first.cycle_prio(step)
	for t: Tower in sel:
		t.prio = first.prio
		t.prio_cd = 0.0
		t.queue_redraw()
	game.hud_system._show_toast("표적 우선순위: " + Tower.PRIO_NAME[first.prio])


func _action_button(label: String, parent: Node, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.theme = controls_theme
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, CONTROL_HEIGHT)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

## 전장 Tab 순환과 정보 읽기 포커스를 F6으로 분리한다. 읽는 동안 대상은 바뀌지 않는다.
func _keyboard_read_input(event: InputEventKey) -> bool:
	if not event.pressed or event.ctrl_pressed or event.meta_pressed or event.alt_pressed or game.perk_mode or game.interaction_system._reading_modal_open() or not game.phase in [game.Phase.CHOOSE, game.Phase.READY, game.Phase.WAVE]:
		return false
	var owner := game.get_viewport().gui_get_focus_owner() as Control
	var in_side := owner != null and side.is_ancestor_of(owner)
	if event.keycode == KEY_F6 and not event.echo:
		if in_side:
			owner.release_focus()
		else:
			if not side.is_visible_in_tree() and game.phase == game.Phase.CHOOSE and not game.offer.is_empty():
				read_card(game.offer[clampi(game.tap_sel, 0, game.offer.size() - 1)])
			if not side.is_visible_in_tree(): return false
			var controls := _reading_focus_order()
			if not controls.is_empty(): controls[0].grab_focus()
		return true
	if not in_side:
		return false
	if event.keycode == KEY_TAB or (owner != scroll and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]):
		if not event.echo:
			var controls := _reading_focus_order()
			if not controls.is_empty():
				var backward := event.shift_pressed if event.keycode == KEY_TAB else event.keycode in [KEY_LEFT, KEY_UP]
				var index := controls.find(owner)
				if index < 0 and backward: index = 0
				controls[posmod(index + (-1 if backward else 1), controls.size())].grab_focus()
		return true
	if owner == scroll:
		match event.keycode:
			KEY_UP: scroll.scroll_vertical -= 32
			KEY_DOWN: scroll.scroll_vertical += 32
			KEY_PAGEUP: scroll.scroll_vertical -= maxi(1, floori(scroll.size.y * 0.8))
			KEY_PAGEDOWN: scroll.scroll_vertical += maxi(1, floori(scroll.size.y * 0.8))
			KEY_HOME: scroll.scroll_vertical = 0
			KEY_END: scroll.scroll_vertical = ceili(scroll.get_v_scroll_bar().max_value)
			_: return false
		return true
	return false

func _reading_focus_order() -> Array[Control]:
	var result: Array[Control] = []
	for control: Control in [expand_btn, side.pin_btn, side.fold_btn, side.close_btn, scroll, read_prev, read_next, use_btn, preview_btn]:
		if control != null and control.is_visible_in_tree() and (not control is BaseButton or not control.disabled):
			result.append(control)
	return result

func read_card(card: Dictionary) -> void:
	if input_blocked() or game.phase != game.Phase.CHOOSE or not card in game.offer:
		return
	reading_review = false
	if reading_card.is_empty():
		reading_return_cards = not game.cards_hidden
	reading_card = card.duplicate(true)
	inspector_dismissed = false
	Meta.card_detail = true
	game.card_detail_btn.set_pressed_no_signal(true)
	game.tap_sel = game.offer.find(card)
	game.cards_system._set_cards_hidden(true)
	_update_side()

func read_wave_review() -> void:
	if input_blocked() or game.phase not in [game.Phase.CHOOSE, game.Phase.READY] or game.leak_log.is_empty():
		return
	if not game.cards_hidden:
		inspect_return_cards = true
	reading_card = {}
	reading_review = true
	inspector_dismissed = false
	side.set_folded(false)
	game.cards_system._set_cards_hidden(true)
	_update_side()

func cycle_read(step: int) -> void:
	if game.offer.is_empty(): return
	var index: int = game.offer.find(reading_card)
	read_card(game.offer[posmod(index + step, game.offer.size())])

func inspect_object(tower: Tower) -> void:
	preview_reveal_generation += 1
	reading_review = false
	inspect_return_cards = inspect_return_cards or reading_return_cards
	reading_card = {}
	reading_return_cards = false
	if game.touch_ui and Meta.phone() and game.phase == game.Phase.CHOOSE and not game.cards_hidden:
		inspect_return_cards = true
		game.cards_system._set_cards_hidden(true)

func active() -> bool:
	return available()

func available() -> bool:
	return game.title_label != null and not game.title_label.visible and game.phase != game.Phase.GAMEOVER

func bounds() -> Rect2:
	return game.ui_root.get_global_transform().affine_inverse() * screen_board()

func screen_board() -> Rect2:
	# UI 글자 배율·안전 영역·패널 노출과 무관한 실제 화면 기준.
	return game.get_viewport_rect()

func camera_fit() -> void:
	board = screen_board()
	fit = minf(board.size.x / Meta.FIELD.x, board.size.y / Meta.FIELD.y)
	var half: Vector2 = board.size / (fit * game.view_zoom) / 2.0
	var limits: Vector2 = (half - Meta.FIELD / 2.0).max(Vector2.ZERO)
	var p: Vector2 = game.viewport_system.center() + game.view_pan
	p = p.clamp(-limits + half, Meta.FIELD + limits - half)
	game.view_pan = p - game.viewport_system.center()
	game.camera.zoom = Vector2.ONE * fit * game.view_zoom
	game.camera.position = p - (board.get_center() - game.get_viewport_rect().size / 2.0) / (fit * game.view_zoom)
	game.camera.force_update_scroll()

func world_view() -> Rect2:
	var size: Vector2 = screen_board().size / maxf(0.01, fit * game.view_zoom)
	return Rect2(game.viewport_system.center() + game.view_pan - size / 2.0, size)

func over_ui(p: Vector2, include_info := true) -> bool:
	if not active():
		return false
	var under := _tower_under(p)
	for c: Control in [panel, footer, edit_tools, save_btn, game.pause_btn, side if not (under and side.drag == 0) else null, focus_btn, game.cancel_btn, game.start_btn, game.aim_ok_btn,
			game.dps_panel if not (under and game.dps_panel.drag == 0) else null, game.range_btn, game.zoom_btn,
			game.guide_more, game.skip_btn, game.skip_n_btn, game.pause_box, game.paused_label, game.mp_bar, game.coin_fx]:
		if c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	var hovered_control: Control = game.get_viewport().gui_get_hovered_control()
	while hovered_control != null and hovered_control != game.ui_root:
		if hovered_control is BaseButton and hovered_control.mouse_filter != Control.MOUSE_FILTER_IGNORE and hovered_control.is_visible_in_tree() and hovered_control.get_global_rect().has_point(p):
			return true
		hovered_control = hovered_control.get_parent() as Control
	if include_info and ((game.hud.is_visible_in_tree() and game.hud.get_global_rect().has_point(p) and not _tower_under(p)) or game.interaction_system._info_tip_at(p) >= 0):
		return true
	var bar_rect := Rect2()
	for c: Control in game.bar_box.get_children():
		if c.is_visible_in_tree():
			bar_rect = bar_rect.merge(c.get_global_rect()) if bar_rect.has_area() else c.get_global_rect()
	if bar_rect.has_area() and bar_rect.has_point(p):
		return true
	for c: Control in game.skill_btns:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false

## 점수 줄 칩·떠 있는 창(DPS 표·정보창) 밑에 오브젝트가 있으면 오브젝트가 먼저 (누르기·옮기기·방향 바꾸기). 창은 FloatPanel.cover가 마우스도 통과시킨다
func _tower_under(p: Vector2) -> bool:
	return game.interaction_system._tower_at(game.get_canvas_transform().affine_inverse() * p) != null

func carrying() -> bool:
	return active() and not game.picked.is_empty() and game.interaction_system.moving == null \
		and game.phase in [game.Phase.PLACE, game.Phase.AIM]

func input_blocked(include_pause := true) -> bool:
	return not active() or (include_pause and game.get_tree().paused) or game.tut.visible or game.settings_panel.visible \
		or game.help_label.visible or game.notes_panel.visible or game.codex_panel.visible \
		or game.vote_panel.visible or game.records_panel.visible

func clear_gesture() -> void:
	pending_card = {}
	pointer_id = -2
	card_dragging = false

func _card_gui_input(event: InputEvent, b: Button, card: Dictionary) -> void:
	if b.disabled or input_blocked() or game.phase != game.Phase.CHOOSE or game.perk_mode or card["type"] == "cata":
		return
	if event is InputEventScreenTouch and event.pressed:
		suppress_tap = false
		pending_card = card
		pointer_id = event.index
		press_origin = b.get_global_transform() * event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and pointer_id < 0:
		suppress_tap = false
		pending_card = card
		pointer_id = -1
		press_origin = b.get_global_transform() * event.position

## GUI가 시작한 카드 제스처만 받는다. 일반 전장 클릭·드래그·확대는 기존 입력으로 넘긴다.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION and touch_capture:
			return true
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			touch_capture = false
		pointer = event.position
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer = event.position
	if input_blocked():
		clear_gesture()
		touch_capture = false
		return false
	if event is InputEventKey and _keyboard_read_input(event):
		return true
	if event is InputEventScreenTouch:
		if event.index == read_pointer:
			if not event.pressed: read_pointer = -1
			return false
		if event.pressed:
			for button: Control in game.choice_box.get_children():
				var read_button := button.get_node_or_null("ReadCard") as Button
				if read_button != null and read_button.is_visible_in_tree() and read_button.get_global_rect().has_point(event.position):
					clear_gesture()
					touch_capture = false
					read_pointer = event.index
					return false
	if event is InputEventScreenDrag and event.index == pointer_id:
		touch_position = pointer
	if event is InputEventScreenTouch and event.pressed:
		# 일부 플랫폼은 같은 손가락의 흉내 낸 마우스 press를 먼저 보낸다.
		if pointer_id == -1 and not pending_card.is_empty() and not card_dragging:
			pointer_id = event.index
			press_origin = pointer
			touch_position = pointer
			touch_capture = true
			game.touch_ui = true
			return true
		if pointer_id >= 0 and event.index != pointer_id:
			game.interaction_system.touches[pointer_id] = touch_position
			clear_gesture()
			touch_capture = false
			return false
		if pending_card.is_empty():
			touch_capture = false
			if game.phase == game.Phase.CHOOSE and not game.perk_mode and game.choice_box.is_visible_in_tree():
				for button: Button in game.choice_box.get_children():
					if button.disabled:
						continue
					var card: Dictionary = button.get_meta("offer_card", {})
					if button.get_global_rect().has_point(pointer) and not card.is_empty() and card["type"] != "cata":
						pending_card = card
						break
			elif carrying() and game.phase == game.Phase.PLACE and not over_ui(pointer):
				pending_card = game.picked
				card_dragging = true
			if not pending_card.is_empty():
				suppress_tap = false
				pointer_id = event.index
				press_origin = pointer
				touch_position = pointer
				touch_capture = true
				game.touch_ui = true
				return true
	if pending_card.is_empty():
		if suppress_tap and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			game.cards_system.call_deferred("_release_card_tap_guard")
			return true
		return false
	var motion: bool = (event is InputEventMouseMotion and pointer_id == -1) \
		or (event is InputEventScreenDrag and event.index == pointer_id)
	var released: bool = (event is InputEventMouseButton and pointer_id == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and event.index == pointer_id and not event.pressed)
	if motion and not card_dragging and pointer.distance_to(press_origin) >= 12.0:
		card_dragging = true
		suppress_tap = true
		game.cards_system._on_pick(pending_card)
		tick()
	if released:
		var dropped := card_dragging
		var tapped := pending_card
		var was_touch := pointer_id >= 0
		clear_gesture()
		if dropped:
			game.interaction_system._drop_carried_card(pointer)
		elif was_touch:
			game.cards_system._on_card_tap(tapped, game.offer.find(tapped))
		if dropped or was_touch:
			game.cards_system.call_deferred("_release_card_tap_guard")
		return dropped or was_touch
	return motion and card_dragging

func preview_card() -> Dictionary:
	if reading_review or not active() or game.phase != game.Phase.CHOOSE or game.perk_mode:
		return {}
	if not reading_card.is_empty() and reading_card in game.offer:
		return reading_card
	if game.cards_hidden:
		return {}
	if game.touch_ui and game.tap_sel >= 0 and game.tap_sel < game.offer.size():
		return game.offer[game.tap_sel]
	if is_instance_valid(hovered) and hovered.get_parent() == game.choice_box and hovered.has_meta("offer_card") \
			and (game.interaction_system.selected.is_empty() or hovered.get_global_rect().has_point(pointer) or (side.visible and side.get_global_rect().has_point(pointer))):
		return hovered.get_meta("offer_card")
	return {}

func target_ok(t: Tower, card: Dictionary) -> bool:
	if game.mp_mode == "coop":
		return bool(game.multiplayer_system.gifts().offer_status(t, card).get("ok", false))
	return (game.multiplayer_system._mine(t) or (game.mp_mode == "coop" and card.get("type") == "elem" and t.req_e >= 0 and t.req_e == card.get("e", -1))) and t.can_take(card)

func watch(b: Button, card: Dictionary) -> void:
	b.set_meta("offer_card", card)
	b.mouse_entered.connect(func():
		if not game.touch_ui:
			if game.interaction_system.selected.is_empty():
				inspected_tower = null
			hovered = b)
	b.gui_input.connect(_card_gui_input.bind(b, card))
	var info_button := _action_button("정보", b, read_card.bind(card))
	info_button.name = "ReadCard"
	info_button.tooltip_text = "카드를 쓰지 않고 효과·조건·대상 비교 읽기"
	info_button.custom_minimum_size = Vector2(52, 28)
	info_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# 상세 영역으로 마우스를 옮겨도 읽던 카드와 강조를 유지한다. 다른 카드는 진입 시 교체한다.

func card_size() -> Vector2:
	var count := maxi(game.offer.size(), 3)
	return Vector2(maxf(120, (game.ui_root.size.x - 24 - (count - 1) * 12) / count), CARD_HEIGHT)

func tick() -> void:
	if not available():
		clear_gesture()
		inspected_tower = null
		hovered = null
		panel.hide()
		footer.hide()
		skip_group.hide()
		side.hide()
		focus_btn.hide()
		edit_tools.hide()
		game.ver_label.show()
		return
	camera_fit()
	var size: Vector2 = game.ui_root.size
	var footer_y := size.y - CONTROL_HEIGHT - 12.0
	var blocked := input_blocked()
	var gift_waiting: bool = game.mp_mode == "coop" and game.multiplayer_system.gifts().blocks_local_choice()
	if not is_equal_approx(game.bar_box.custom_minimum_size.y, CONTROL_HEIGHT):
		game.bar_box.custom_minimum_size.y = CONTROL_HEIGHT
	if not is_equal_approx(game.bar_box.offset_top, -CONTROL_HEIGHT - 12.0):
		game.bar_box.offset_top = -CONTROL_HEIGHT - 12.0
	if not is_equal_approx(game.bar_box.offset_bottom, -12.0):
		game.bar_box.offset_bottom = -12.0
	var choosing: bool = game.phase == game.Phase.CHOOSE and game.coin_stage == 0
	var cards: bool = choosing and not game.cards_hidden and not blocked
	footer.visible = cards
	footer.position = Vector2(0, size.y - FOOTER_HEIGHT)
	footer.size = Vector2(size.x, FOOTER_HEIGHT)
	panel.visible = cards
	game.choice_box.visible = cards
	game.apply_btn.hide()  # 일반 판은 한 번 눌러 들고, 전장의 대상으로 확정한다.
	game.legend.hide()
	game.card_dim.hide()
	game.hint.hide()
	for c: Control in [game.bar_box, game.ver_label, game.start_btn, game.cancel_btn, game.aim_ok_btn, game.skip_badge]:
		c.z_index = 2
	panel.position = Vector2(0, size.y - HEIGHT)
	panel.size = Vector2(size.x, HEIGHT - FOOTER_HEIGHT)
	_top_left(game.choice_box)
	game.choice_box.position = Vector2(12, panel.position.y + HEADER_HEIGHT)
	game.choice_box.pivot_offset = Vector2.ZERO
	game.choice_box.scale = Vector2.ONE
	game.choice_box.size = Vector2(size.x - 24, CARD_HEIGHT)
	if game.choice_box.get_theme_constant("separation") != 12:
		game.choice_box.add_theme_constant_override("separation", 12)
	var cs: Array = game.choice_box.get_children()
	for button: Control in cs:
		if button.is_queued_for_deletion():
			continue
		button.disabled = gift_waiting
		button.custom_minimum_size = Vector2((size.x - 24 - maxf(0, cs.size() - 1) * 12) / maxi(1, cs.size()), CARD_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var info_button := button.get_node_or_null("ReadCard") as Button
		if info_button != null:
			info_button.position = Vector2(button.size.x - 62 * K, 5)
			info_button.size = Vector2(56 * K, 30 * K)
	if choosing and not game.perk_mode:
		game.cards_system._update_reroll_btn()
	if gift_waiting:
		game.reroll_btn.disabled = true
	var x := size.x - 12.0
	var skip_visible: bool = game.skip_btn.visible and not blocked and (cards or game.phase == game.Phase.READY)
	game.skip_btn.visible = skip_visible
	game.skip_n_btn.visible = skip_visible
	skip_group.visible = skip_visible
	if cards and skip_visible:
		x -= SKIP_WIDTH
		layout_skip(Vector2(x, panel.position.y + 8), CONTROL_HEIGHT)
		x -= 8
	for button: Button in [game.card_detail_btn, game.reroll_btn]:
		button.visible = button.visible and cards
		if not button.visible:
			continue
		var w := (96.0 if button == game.card_detail_btn else 160.0) * K
		x -= w
		_top_left(button)
		button.position = Vector2(x, panel.position.y + 8)
		button.size = Vector2(w, CONTROL_HEIGHT)
		x -= 8
	game.field_overlay_system._update_choice_header()
	game.choice_header.visible = game.choice_header.visible and cards
	state.visible = cards and not game.choice_header.visible
	state.text = "특성 선택 · 하나 선택"
	state.position = Vector2(12, 9)
	if game.choice_header.visible:
		_top_left(game.choice_header)
		game.choice_header.position = Vector2(12, panel.position.y + 8)
		game.choice_header.size = Vector2(maxf(240 * K, minf(340 * K, x - 24)), CONTROL_HEIGHT)
	_update_side()
	# 상세는 필요할 때 떠 있는 패널로 읽는다. 표시 여부는 전장 크기에 영향을 주지 않는다.
	side.visible = side.visible and not carrying() and not input_blocked(false)
	side.z_index = 21 if game.get_tree().paused else 1
	if side.visible and game.get_tree().paused:
		game.ui_root.move_child(side, game.ui_root.get_child_count() - 1)  # GUI 입력 순서도 일시정지 막 위로 올린다.
	game.detail_btn.visible = side.visible and shown_tower != null and game.touch_ui
	game.start_btn.visible = game.phase == game.Phase.READY and not blocked
	game.start_btn.disabled = gift_waiting
	game.cancel_btn.disabled = gift_waiting
	game.skip_btn.disabled = gift_waiting
	if gift_waiting:
		game.start_btn.text = "진행 확인 중"
	game.cancel_btn.visible = game.phase in [game.Phase.PLACE, game.Phase.AIM, game.Phase.MOVE] and not blocked
	game.aim_ok_btn.visible = game.interaction_system._ok_btn_on() and not blocked
	var actions: Array = [game.start_btn, game.cancel_btn, game.aim_ok_btn].filter(func(button): return button.visible)
	var width := (240.0 if game.start_btn.visible else 144.0) * K
	var action_y := size.y - (112.0 if game.bar_open else 52.0) * K
	var ready_skip: bool = game.phase == game.Phase.READY and skip_visible
	var left := (size.x - 240 * K - 8 - SKIP_WIDTH) / 2
	for i in actions.size():
		var button: Button = actions[i]
		_top_left(button)
		var bx: float = left if ready_skip and button == game.start_btn else (size.x - actions.size() * (width + 8)) / 2 + i * (width + 8)
		button.position = Vector2(bx, action_y)  # 자리를 한 번에 (두 번 나눠 정하면 매 프레임 움직인 것으로 쳐 다시 그렸다)
		button.size = Vector2(width, 44 * K)
	if ready_skip:
		layout_skip(Vector2(left + 240 * K + 8, action_y), 44 * K)
	if not blocked and not game.guide_label.visible:
		var status := operation_text()
		if status != "":
			game.hint.text = game.patchlog_system._kr_keep(status)
			_top_left(game.hint)
			game.hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			game.hud_system._font_size(game.hint, 14)
			if not game.hint.has_theme_stylebox_override("normal"):
				var box := surface()
				box.content_margin_top = 6
				box.content_margin_bottom = 6
				game.hint.add_theme_stylebox_override("normal", box)
			var status_width: float = minf(size.x - 24, game.ui_font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, Meta.fs(14)).x + 24)
			# 글자 확대·줄바꿈으로 늘어난 실제 높이만큼 위로 올려 버튼과 8px 띄운다.
			game.hint.size = Vector2(status_width, 0)
			var status_height: float = maxf(34, game.hint.get_combined_minimum_size().y)
			game.hint.size.y = status_height
			game.hint.position = Vector2((size.x - status_width) / 2, (panel.position.y if cards else action_y) - status_height - 8)
			game.hint.z_index = 2
			game.hint.show()
	game.cancel_btn.text = game.ui_layout_system._kh("카드 돌려놓기 (Esc)") if carrying() and game.phase == game.Phase.PLACE else game.ui_layout_system._kh("위치 다시 정하기 (Esc)" if carrying() else "편집 취소 (Esc)")
	if gift_waiting:
		game.cancel_btn.text = "전달 확인 중"
	var skill_widths: Array[float] = []
	var skills_width := 0.0
	for button: Button in game.skill_btns:
		var skill_width: float = maxf(186.0, button.get_combined_minimum_size().x)
		skill_widths.append(skill_width)
		skills_width += skill_width + 10
	var skill_x: float = size.x - 12 - skills_width + 10
	for i in game.skill_btns.size():
		var button: Button = game.skill_btns[i]
		button.z_index = 2
		_top_left(button)
		button.position = Vector2(skill_x, size.y - 134)
		button.size = Vector2(skill_widths[i], maxf(62, button.get_combined_minimum_size().y))
		skill_x += skill_widths[i] + 10
	if game.abilities_system.skill_auto_btn != null:
		var auto: Button = game.abilities_system.skill_auto_btn
		auto.position = Vector2(size.x - 12 - skills_width + 10, size.y - 178)
		auto.size = Vector2(186, 36)
		auto.z_index = 2
	_avoid_skill_hint()
	# 같은 프레임에 배치한 기술·모드 버튼 위로 정보창이 내려오지 않게 한다.
	_place_side(size, cards)
	if game.zoom_btn.visible:
		_top_left(game.zoom_btn)
		# 점수 줄 첫 줄(웨이브·점수·중앙 체력) 오른쪽 빈자리: 예전 (12, 64)는 둘째 줄 칩(모드·맵 규칙)을 덮었다
		var row1 := 0.0
		for ch in game.hud_chips:
			if (ch[0] as Rect2).position.y < 1.0:
				row1 = maxf(row1, (ch[0] as Rect2).end.x)
		game.zoom_btn.position = Vector2(game.hud.position.x + row1 + 10.0, maxf(game.hud.position.y - 2.0, 4.0)) if game.hud.visible else Vector2(12, 8)
		game.zoom_btn.size = Vector2(132, 34)
	focus_btn.visible = not blocked and choosing
	focus_btn.text = "카드 보기" if game.cards_hidden else "카드 접기"
	focus_btn.tooltip_text = "카드 패널 보기/접기 (F / V)"
	_top_left(focus_btn)
	focus_btn.position = Vector2(12, footer_y)
	focus_btn.size = Vector2(110 * K, CONTROL_HEIGHT)
	game.ver_label.visible = not focus_btn.visible and game.phase == game.Phase.WAVE
	edit_tools.visible = not blocked and game.phase in [game.Phase.CHOOSE, game.Phase.READY]
	edit_tools.position = Vector2(focus_btn.get_rect().end.x + 12 if focus_btn.visible else 12, footer_y)
	if game.phase == game.Phase.READY:
		edit_tools.position.y = action_y - CONTROL_HEIGHT - 12
	undo_btn.disabled = not game.cards_system.can_undo()
	undo_btn.tooltip_text = game.cards_system._history_service().last_reason if undo_btn.disabled else "최근 변경 되돌리기 (Ctrl/Cmd+Z)"
	select_btn.text = "선택 추가: 켬" if game.interaction_system.additive_selection else "여러 개 선택"
	select_btn.disabled = gift_waiting
	select_all_btn.disabled = gift_waiting
	group_direction_btn.disabled = gift_waiting or not game.interaction_system.selected.any(func(t): return game.multiplayer_system._mine(t))
	select_all_btn.visible = game.towers.get_child_count() > 1
	group_direction_btn.visible = edit_tools.visible and not game.interaction_system.selected.is_empty()
	prio_btn.visible = edit_tools.visible and not game.interaction_system.selected.is_empty()
	prio_btn.disabled = group_direction_btn.disabled
	if prio_btn.visible:
		var first: Tower = game.interaction_system.selected[0] if is_instance_valid(game.interaction_system.selected[0]) else null
		prio_btn.text = "표적: " + (Tower.PRIO_NAME.get(first.prio, "앞선") if first else "앞선")
	review_btn.visible = not game.leak_log.is_empty()
	if edit_tools.visible and game.hint.visible and edit_tools.get_rect().intersects(game.hint.get_rect()):
		game.hint.position.y = edit_tools.position.y - game.hint.size.y - 8
	save_btn.visible = not blocked and game.phase == game.Phase.WAVE
	save_btn.position = Vector2(12, footer_y)
	save_btn.size = Vector2(120 * K, CONTROL_HEIGHT)
	if save_btn.visible:
		_top_left(game.ver_label)
		game.ver_label.position = Vector2(save_btn.get_rect().end.x + 12, size.y - 28)
	if game.pause_btn.get_parent() != game.ui_root:
		game.pause_btn.reparent(game.ui_root)
	game.pause_btn.visible = not blocked or game.get_tree().paused
	_top_left(game.pause_btn)
	game.pause_btn.position = Vector2(size.x - 12 - 120 * K, 8)
	game.pause_btn.size = Vector2(120 * K, CONTROL_HEIGHT)
	game.pause_btn.z_index = 25
	game.pause_btn.text = "계속" if game.get_tree().paused else "일시정지"
	var badge_pos := Vector2((size.x - game.skip_badge.size.x) / 2.0, size.y - HEIGHT - 40 if cards else size.y - 100)
	if game.skip_badge.visible:
		# 아래 조작 안내(hint)와 겹치면 그 위로, 오른쪽 기술 버튼과 겹치면 왼쪽으로 비킨다.
		var badge := Rect2(badge_pos, game.skip_badge.size)
		if game.hint.visible and badge.intersects(Rect2(game.hint.position, game.hint.size)):
			badge_pos.y = game.hint.position.y - game.skip_badge.size.y - 6
		var avoid: Array[Control] = []
		avoid.append_array(game.abilities_system.skill_controls())
		avoid.append(side)
		for c: Control in avoid:
			if c.visible and Rect2(badge_pos, game.skip_badge.size).intersects(c.get_rect()):
				badge_pos.x = maxf(12.0, minf(badge_pos.x, c.position.x - game.skip_badge.size.x - 8))
	game.skip_badge.position = badge_pos
	if game.skip_badge.visible and side.visible and game.skip_badge.get_rect().intersects(side.get_rect()):
		game.skip_badge.position.y = minf(size.y - 60 - game.skip_badge.size.y, maxf(side.get_rect().end.y + 8, game.skip_badge.position.y))
	if game.skip_badge.visible:
		for c: Control in [game.start_btn, game.hint]:
			if c.visible and game.skip_badge.get_rect().intersects(c.get_rect()):
				game.skip_badge.position.y = c.position.y - game.skip_badge.size.y - 8

## 왼쪽 위 기준으로 바꾸기: 이미 그렇다면 건드리지 않는다 (set_anchors_preset은 같은 값이어도 다시 그리기를 부른다:
## 매 프레임 부르면 카드 줄·버튼이 매 프레임 다시 그려졌다).
static func _top_left(c: Control) -> void:
	if c.anchor_left != 0.0 or c.anchor_top != 0.0 or c.anchor_right != 0.0 or c.anchor_bottom != 0.0:
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)


## 선택 안내는 기술 왼쪽에 둔다. 폭이 부족하면 원문을 접고 기존 아래쪽 간격을 지킨다.
func _avoid_skill_hint() -> void:
	if not game.hint.is_visible_in_tree():
		return
	var original: Rect2 = game.hint.get_rect()
	var right: float = game.ui_root.size.x - 12.0
	for control: Control in game.abilities_system.skill_controls():
		if control.is_visible_in_tree() and original.intersects(control.get_rect()):
			right = minf(right, control.position.x - 8.0)
	if right >= game.ui_root.size.x - 12.0:
		return
	game.hint.size = Vector2(minf(original.size.x, maxf(1.0, right - 12.0)), 0.0)
	var height: float = maxf(34.0, game.hint.get_combined_minimum_size().y)
	game.hint.size.y = height
	game.hint.position = Vector2(clampf(original.position.x, 12.0, maxf(12.0, right - game.hint.size.x)), original.end.y - height)


func operation_text() -> String:
	if game.mp_mode == "coop":
		var notice: String = game.multiplayer_system.gifts().pending_notice()
		if notice != "":
			return notice
	game.interaction_system.selected = game.interaction_system.selected.filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
	var cancel := "아래 버튼으로 취소" if game.touch_ui else "Esc 취소"
	if game.interaction_system.dragging:
		var invalid: String = str(game.interaction_system.drag_preview().get("reason", ""))
		return "%d개 이동 중 · %s" % [game.interaction_system.drag_group.size(), invalid if invalid != "" else ("손을 떼어 배치" if game.touch_ui else cancel)]
	if game.interaction_system.boxing:
		return "영역 선택 중 · %s" % ("손을 떼어 선택" if game.touch_ui else cancel)
	match game.phase:
		game.Phase.PLACE:
			var content: Dictionary = game.cards_system._card_content(game.picked, 0)
			return "%s 놓는 중 · %s" % [str(content.get("head", {}).get("name", "카드")), cancel]
		game.Phase.AIM:
			return ("방향 편집 중" if game.interaction_system.moving else "설치 방향 정하는 중") + " · " + cancel
		game.Phase.MOVE:
			return "위치 편집 중 · %s" % cancel
		game.Phase.CHOOSE, game.Phase.READY, game.Phase.WAVE:
			if not game.interaction_system.selected.is_empty():
				var again := ""
				if game.phase != game.Phase.WAVE:
					again = "방향 변경 버튼 · " if game.touch_ui else "E: 방향 · Alt+휠: 회전 · "
				return "오브젝트 %d개 선택 · %s%s" % [game.interaction_system.selected.size(), again, "빈 곳을 눌러 해제" if game.touch_ui else "Esc 해제"]
	return ""


func layout_skip(at: Vector2, height: float) -> void:
	skip_group.position = at
	skip_group.size = Vector2(SKIP_WIDTH, height)
	for i in 2:
		var button: Button = [game.skip_btn, game.skip_n_btn][i]
		_top_left(button)
		button.position = at + Vector2(124 * K if i == 1 else 0.0, 0)
		button.size = Vector2((100 if i == 1 else 124) * K, height)


func close_inspector(explicit := false) -> void:
	preview_reveal_generation += 1
	var restore_cards: bool = (not reading_card.is_empty() and reading_return_cards) or inspect_return_cards
	reading_card = {}
	reading_review = false
	reading_return_cards = false
	inspect_return_cards = false
	if explicit:
		inspector_dismissed = true
	dismissed_tower = game.interaction_system._tower_at(game.interaction_system._pointer_world())
	game.interaction_system.selected.clear()
	game.tap_sel = -1
	game.hover_elem = -1
	game.cards_system._tap_hover()
	game.tip_tower = null
	inspected_tower = null
	shown_tower = null
	hovered = null
	pic.clear()
	side.hide()
	side_signature = ""
	if restore_cards:
		game.cards_system._set_cards_hidden(false)


func _update_side() -> void:
	if not reading_card.is_empty() and (game.phase != game.Phase.CHOOSE or not reading_card in game.offer):
		reading_card = {}
		reading_return_cards = false
	direction_btn.visible = not game.get_tree().paused and game.phase in [game.Phase.CHOOSE, game.Phase.READY] and not game.interaction_system.selected.is_empty()
	if inspector_dismissed:
		side.hide()
		return
	var mouse: Vector2 = game.interaction_system._pointer_screen()
	var tower: Tower = game.interaction_system._tower_at(game.interaction_system._pointer_world()) if not over_ui(mouse) else null
	if tower == dismissed_tower:
		tower = null
	else:
		dismissed_tower = null
	# 선택은 고정 대상, 전장 호버는 이번 프레임의 임시 대상이다.
	var selected_tower: Tower = null
	for candidate in game.interaction_system.selected:
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion() and candidate.get_parent() == game.towers:
			if selected_tower == null or candidate == inspected_tower:
				selected_tower = candidate
			if candidate == inspected_tower:
				break
	if selected_tower != null:
		inspected_tower = selected_tower
	if tower != null:
		hovered = null
		if selected_tower == null:
			inspected_tower = tower
	var card := preview_card()
	var title := "전장 안내"
	var text := ""
	var has_content := false
	shown_tower = null
	if reading_review and game.phase in [game.Phase.CHOOSE, game.Phase.READY]:
		has_content = true
		title = "지난 웨이브"
		text = game.hud_system.leak_review_text()
		pic.clear()
	elif not card.is_empty():
		inspected_tower = null
		has_content = true
		var cc: Dictionary = game.cards_system._card_content(card, 0)
		title = cc["head"]["name"]
		var take := 0
		var reaction := 0
		for t: Tower in game.towers.get_children():
			if not target_ok(t, card):
				continue
			take += 1
			if card["type"] == "elem" and not Elem.new_reactions(t.eff_now(), card["e"]).is_empty():
				reaction += 1
		pic.show_card(card, cc["head"], take, reaction, game.waves_system._combo_parts(card["e"])["els"] if card["type"] == "elem" else [], _pic_w())
		var full: Array = game.cards_system._card_full(card)
		if game.hud_system.has_method("card_comparison_text"):
			full.append([game.hud_system.card_comparison_text(card), Color.WHITE])
		var fit_name: String = game.hud_system.core_fit(card)
		if fit_name != "":
			full.append(["주력 %s 강화" % fit_name, Color.WHITE])
		if MapRule.card_aff(card):
			var bonus := " · 피해 +%d%%" % roundi(Rules.t("map_aff_dmg") * 100) if card["type"] in ["elem", "pat"] else ""
			full.append([str(Meta.MAPS[Meta.map_id]["name"]) + " 친화" + bonus, Color.WHITE])
		for row in (full if Meta.card_detail else full.slice(0, 2)):
			text += str(row[0]) + "\n\n"
		text = text.strip_edges()
		if not Meta.card_detail:
			text += "\n\n"
			text += "자세히를 켜면 반응·적용 조건을 모두 볼 수 있어요." if game.touch_ui else "자세히(Z)를 켜면 반응·적용 조건을 모두 볼 수 있어요."
	elif selected_tower == null and game.perk_mode and is_instance_valid(hovered) and hovered.get_parent() == game.choice_box and hovered.has_meta("perk_desc"):
		inspected_tower = null
		has_content = true
		title = hovered.get_meta("card")[0]["name"]
		text = hovered.get_meta("perk_desc")
	else:
		if is_instance_valid(inspected_tower) and not inspected_tower.is_queued_for_deletion() and inspected_tower.get_parent() == game.towers:
			if tower == null:
				tower = inspected_tower
		else:
			inspected_tower = null
		if tower == null and game.touch_ui and is_instance_valid(game.tip_tower) \
				and Engine.get_process_frames() - game.tip_frame <= 180:
			tower = game.tip_tower
		shown_tower = tower
		if tower != null:
			has_content = true
			title = tower.title()
			var total := 0.0
			for o: Tower in game.towers.get_children():
				total += o.dealt
			var part: float = tower.dealt / total if total > 0.0 and game.towers.get_child_count() > 1 else -1.0
			var more: bool = game.field_view_system._tip_detail_on()
			pic.show_tower(tower, more, part, "이번 웨이브 몫" if game.phase == game.Phase.WAVE else "지난 웨이브 몫", _pic_w(), scroll.size.y)
			# 조합의 발동 조건은 기본 정보에도 표시한다. 공격 모습은 위의 공용 미리보기에서 보여 준다.
			for rx in tower.reactions():
				text += ("\n\n" if text != "" else "") + ("NEW · " if tower.new_reactions.has(rx["id"]) else "") + str(rx["name"]) + ": " + str(rx["desc"])
			if game.mp_mode == "coop":
				var ownership: String = game.multiplayer_system._mp_name(tower.owner_id) + "의 오브젝트"
				ownership += " · 직접 편집 가능" if game.multiplayer_system._mine(tower) else " · 위치·방향은 소유자만 편집"
				if tower.req_e >= 0:
					ownership += " · 요청: " + Elem.NAMES[tower.req_e]
				text = ownership + "\n\n" + text
	if pic.mode != "" and ((pic.mode == "tower" and shown_tower == null) or (pic.mode == "card" and card.is_empty())):
		pic.clear()
	var compact: bool = shown_tower != null and not game.cards_hidden and game.phase == game.Phase.CHOOSE
	brief.visible = compact
	scroll.visible = true
	if compact:
		var elems: Array[String] = []
		for e in shown_tower.order:
			elems.append("%s %d" % [Elem.NAMES[e], shown_tower.lv(e)])
		brief.text = shown_tower.title() + "\n" + " · ".join(elems) + "\n" + pic.summary_lines(shown_tower)[0]
		if game.mp_mode == "coop":
			brief.text += "\n" + game.multiplayer_system._mp_name(shown_tower.owner_id) + (" · 편집 가능" if game.multiplayer_system._mine(shown_tower) else " · 소유자만 이동·방향 편집")
		pic.hide()
		detail.hide()
	expand_btn.visible = shown_tower != null and game.phase == game.Phase.CHOOSE
	expand_btn.text = "카드 보기" if game.cards_hidden else "전체 정보"
	preview_btn.visible = shown_tower != null and not compact
	preview_btn.text = "예시 접기" if pic.preview_visible else "공격 예시"
	read_prev.visible = not reading_card.is_empty()
	read_next.visible = not reading_card.is_empty()
	use_btn.visible = not reading_card.is_empty() and game.phase == game.Phase.CHOOSE and game.picks_left > 0
	use_btn.disabled = input_blocked() or (game.mp_mode == "coop" and game.multiplayer_system.gifts().blocks_local_choice())
	read_actions.visible = read_prev.visible or read_next.visible or use_btn.visible
	preview_actions.visible = preview_btn.visible
	heading.visible = not ((game.touch_ui or Meta.phone()) and pic.mode == "tower")
	detail.visible = text != "" and not compact
	var sig: String = title + "|" + text + ("|" + str(tower.get_instance_id()) if is_instance_valid(tower) and card.is_empty() else "")
	side.visible = active() and has_content and (card.is_empty() or Meta.card_detail)
	if sig != side_signature:
		heading.text = "정보" if pic.mode == "tower" else ("카드 정보" if pic.mode == "card" else title)
		detail.text = game.patchlog_system._kr_keep(text)
		scroll.scroll_vertical = 0
		side_signature = sig

## 설명창 자리: 오른쪽 기둥 대신 내용 높이만큼만, 오른쪽 위·왼쪽 위 중 오브젝트를 덜 가리는 쪽에 뜬다.
## 보고 있는 오브젝트(shown_tower)는 가리지 않는다. 비슷하면 지금 쪽에 머문다(왔다 갔다 하지 않게).
func _place_side(size: Vector2, cards: bool) -> void:
	var w := clampf(size.x * 0.28, 240.0, 330.0)
	# 머리 줄 버튼(방향 변경·자세히·압정·접기·닫기)이 다 들어가게: 터치는 짧은 이름, 그래도 모자라면 창을 넓힌다
	direction_btn.text = "방향" if game.touch_ui else "방향 변경"
	side.set_touch(game.touch_ui)
	w = maxf(w, side.get_combined_minimum_size().x)
	_top_left(side)
	var top := maxf(60.0, game.hud.get_rect().end.y + 8.0)
	var bottom: float = panel.position.y - 12.0 if cards else size.y - 64.0
	if game.hint.visible:
		bottom = minf(bottom, game.hint.position.y - 8)
	for b: Control in game.abilities_system.skill_controls():
		if b.is_visible_in_tree():
			bottom = minf(bottom, b.position.y - 8)  # 웨이브 중 오른쪽 아래 기술 버튼을 덮지 않게
	var ltop := top
	var rtop := top
	if game.zoom_btn.is_visible_in_tree():
		ltop = maxf(ltop, game.zoom_btn.get_rect().end.y + 8.0)
	# DPS 표(옮길 수 있음)가 위쪽 구석 기둥에 있으면 그 아래부터, 다른 곳에 있으면 겹치는 쪽을 덜 고른다
	var dr := Rect2()
	if game.dps_panel.is_visible_in_tree():
		dr = game.dps_panel.get_rect()
		if dr.position.y < top + 60.0:
			if dr.position.x < 12.0 + w:
				ltop = maxf(ltop, dr.end.y + 8.0)
			if dr.end.x > size.x - w - 12.0:
				rtop = maxf(rtop, dr.end.y + 8.0)
	var sb: StyleBox = side.get_theme_stylebox("panel")
	var parts := []
	parts.append(side.head.get_combined_minimum_size().y)
	for control: Control in side.body.get_children():
		if control != scroll and control.visible:
			parts.append(control.get_combined_minimum_size().y)
	if not side.folded:
		parts.append((scroll.get_child(0) as Control).get_combined_minimum_size().y)
	var want: float = sb.get_minimum_size().y + 4.0 + side.body.get_theme_constant("separation") * maxf(0, parts.size() - 2)
	for v in parts:
		want += v
	var minimum_height: float = maxf(64.0, side.get_combined_minimum_size().y)
	# 잠깐 뜨는 배너를 피하더라도 제목과 핵심 수치 네 개는 첫 화면에 남긴다.
	var reading_height := minimum_height
	if not side.folded and pic.visible and pic.mode == "tower":
		reading_height = maxf(reading_height, sb.get_minimum_size().y + side.head.get_combined_minimum_size().y + 4.0 + pic.primary_metrics_rect().end.y)
		if preview_actions.visible:
			reading_height += preview_actions.get_combined_minimum_size().y + side.body.get_theme_constant("separation")
	want = maxf(want, minimum_height)
	var cands := [Rect2(size.x - w - 12.0, rtop, w, 0.0), Rect2(12.0, ltop, w, 0.0)]
	for control: Control in [game.toast, game.banner, game.paused_label, game.pause_box, game.skip_badge]:
		if not control.is_visible_in_tree():
			continue
		var overlay := control.get_rect()
		for i in cands.size():
			var candidate: Rect2 = cands[i]
			# 잠깐 뜨는 글(알림·배너) 아래로 내리면 창이 카드 줄 머리 버튼(새로고침·넘기기)을 덮을 만큼 좁아지면 그대로 둔다.
			if overlay.position.x < candidate.end.x and overlay.end.x > candidate.position.x and overlay.end.y + 8 <= bottom - reading_height:
				candidate.position.y = maxf(candidate.position.y, overlay.end.y + 8)
				cands[i] = candidate
	var scores := []
	var inv: Transform2D = game.ui_root.get_global_transform().affine_inverse()
	var canvas: Transform2D = game.get_viewport().get_canvas_transform()
	var pad: float = 26.0 * fit * game.view_zoom
	for i in cands.size():
		var r: Rect2 = cands[i]
		# 긴 DPS 표 아래에 자리가 없으면 읽기 창을 화면 밖으로 밀지 않는다.
		r.position.y = minf(r.position.y, maxf(top, bottom - minimum_height))
		r.size.y = clampf(want, minimum_height, maxf(minimum_height, bottom - r.position.y))
		cands[i] = r
		var sc := 0.0
		for t: Tower in game.towers.get_children():
			var at: Vector2 = inv * (canvas * t.global_position)
			if r.grow(pad).has_point(at):
				sc += 100.0 if t == shown_tower else 1.0
		if r.size.y < want - 1.0:
			sc += 0.5  # 다 안 들어가 스크롤해야 하는 쪽은 조금 덜 고른다
		if dr.has_area() and r.intersects(dr):
			sc += 50.0  # 옮겨 둔 DPS 표를 덮는 쪽
		scores.append(sc)
	var cur := 1 if side_left else 0
	if scores[1 - cur] < scores[cur]:
		cur = 1 - cur
	side_left = cur == 1
	var pick: Rect2 = cands[cur]
	if side.pinned() or side.drag == 2:
		# 사용자가 옮겨 둔 자리: 폭은 같고, 높이는 그 자리에서 아래 끝까지 들어가는 만큼 (모자라면 위로 올린다)
		var at: Vector2 = side.saved_pos() if side.drag != 2 else side.drag_pos()
		var h := clampf(want, minimum_height, maxf(minimum_height, bottom - top))
		pick = Rect2(Vector2(at.x, clampf(at.y, top, maxf(top, bottom - h))), Vector2(w, h))
	side.size = pick.size
	side.follow(pick.position, game.get_process_delta_time())
	if side.drag != 2:
		side.position.y = clampf(side.position.y, top, maxf(top, bottom - side.size.y))
	side.set_touch(game.touch_ui)
	# 밑에 깔린 오브젝트는 먼저 누르게 통과, 옮겨 둔 창은 밑에 오브젝트가 있으면 옅게 (자동 자리는 보는 오브젝트를 피해 뜬다)
	side.cover(side.pinned())


## 설명창 그림 폭: 설명창 폭에서 안쪽 여백을 뺀 값.
func _pic_w() -> float:
	var column: Control = scroll.get_child(0)
	return maxf(1.0, column.size.x if column.size.x > 0.0 else side.size.x - 28.0)


func _toggle_attack_preview() -> void:
	preview_reveal_generation += 1
	var generation := preview_reveal_generation
	var target: Tower = pic.tower
	pic.set_preview_visible(not pic.preview_visible)
	if not pic.preview_visible:
		scroll.scroll_vertical = 0
		return
	# 크기 변경과 스크롤 범위가 반영된 뒤 요청한 예시를 보여 준다.
	var tree: SceneTree = game.get_tree()
	for i in 2:
		await tree.process_frame
	if generation == preview_reveal_generation and is_instance_valid(pic) and is_instance_valid(scroll) and pic.is_visible_in_tree() and pic.mode == "tower" and pic.preview_visible and is_instance_valid(target) and pic.tower == target:
		var relative: Vector2 = scroll.get_global_transform().affine_inverse() * pic.attack_preview.global_position
		scroll.scroll_vertical = maxi(0, floori(relative.y + scroll.scroll_vertical))


func summary_text(b: Button) -> String:
	var summary := ""
	if b.has_meta("perk_summary"):
		return str(b.get_meta("perk_summary"))
	if b.has_meta("perk_desc"):
		return b.get_meta("perk_desc")
	if b.has_meta("summary"):
		for row: Dictionary in b.get_meta("summary"):
			if row.has("t"):
				summary += ("\n" if summary != "" else "") + str(row["t"])
		return summary
	if b.has_meta("full"):
		var full: Array = b.get_meta("full")
		for i in mini(2, full.size()):
			summary += ("\n" if i else "") + str(full[i][0])
	return summary

func draw_card(b: Button, col: Color) -> void:
	var m: Array = b.get_meta("card")
	var h: Dictionary = m[0]
	var font: Font = game.ui_font
	if h.has("e"):
		Glyph.elem(b, h["e"], Vector2(18, 22), 8, col)
	elif h.has("pat"):
		Glyph.pat(b, h["pat"], Vector2(18, 22), 8, col)
	else:
		Glyph.kind(b, h["kind"], Vector2(18, 22), 8, col)
	var name: String = h["name"] + (" " + h["lv"] if h.has("lv") else "")
	var fs_name := Meta.fs(18)
	var fs_body := Meta.fs(14)
	var fs_foot := Meta.fs(11)
	var lh := fs_body + 4.0
	var body_y := 51.0 + (fs_name - 18)
	b.draw_string(font, Vector2(36, 28 + (fs_name - 18) * 0.5), name, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 126 * K, fs_name, col.lightened(0.2))
	if not game.touch_ui:
		Glyph.keycap(b, font, Vector2(b.size.x - 72 * K, 8), str(h["idx"]))
	var summary := summary_text(b)
	var lines: PackedStringArray = game.onboarding_system._wrap_words(game.patchlog_system._kr_keep(summary), b.size.x - 28, fs_body).split("\n")
	var visible_lines := mini(3, lines.size())
	for i in visible_lines:
		var line := lines[i]
		if i == visible_lines - 1 and lines.size() > visible_lines:
			while line.length() > 0 and font.get_string_size(line + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_body).x > b.size.x - 28:
				line = line.left(-1)
			line += "…"
		b.draw_string(font, Vector2(14, body_y + lh * i), line, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 28, fs_body, Color("d2dae6"))
	var foot := "특성 · 길게 누르면 자세히" if game.touch_ui else "특성 · 올리면 오른쪽에 자세히"
	var destinations: Array = b.get_meta("card_foot", [])
	if not destinations.is_empty():
		foot = " · ".join(destinations.map(func(it): return it[1]))
	b.draw_string(font, Vector2(14, b.size.y - 8.0), foot, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 28, fs_foot, Color("8294aa"))
