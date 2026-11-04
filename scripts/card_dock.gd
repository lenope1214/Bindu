class_name CardDock
extends RefCounted
## 카드 팔레트와 전장 카메라는 독립적이다. 카드를 들면 팔레트만 접는다.
const CARD_HEIGHT := 94.0
const CONTROL_HEIGHT := 36.0
const HEADER_HEIGHT := CONTROL_HEIGHT + 16.0
const FOOTER_HEIGHT := CONTROL_HEIGHT + 24.0
const HEIGHT := HEADER_HEIGHT + CARD_HEIGHT + 8.0 + FOOTER_HEIGHT
const SKIP_WIDTH := 204.0
var game
var panel: Panel
var footer: Panel
var skip_group: Panel
var controls_theme := make_controls_theme()
var side: PanelContainer
var inspector_header: HBoxContainer
var direction_btn: Button
var close_btn: Button
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
		theme.set_font_size("font_size", type, 15)
	theme.set_stylebox("panel", "PopupMenu", surface())
	var hover := surface()
	hover.bg_color = Color("223149")
	theme.set_stylebox("hover", "PopupMenu", hover)
	return theme

func _init(main) -> void:
	game = main
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
	state.add_theme_font_size_override("font_size", 16)
	state.add_theme_color_override("font_color", Color("d9e5f5"))
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(state)
	side = PanelContainer.new()
	side.name = "CardInspector"
	side.z_index = 1
	var sb := bg.duplicate()
	sb.border_width_top = 0
	sb.border_width_left = 1
	sb.set_content_margin_all(14)
	side.add_theme_stylebox_override("panel", sb)
	game.ui_root.add_child(side)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	side.add_child(content)
	inspector_header = HBoxContainer.new()
	content.add_child(inspector_header)
	heading = Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_theme_font_size_override("font_size", 16)
	inspector_header.add_child(heading)
	direction_btn = Button.new()
	direction_btn.text = "방향 변경"
	direction_btn.theme = controls_theme
	direction_btn.focus_mode = Control.FOCUS_NONE
	direction_btn.custom_minimum_size = Vector2(88, 36)
	direction_btn.pressed.connect(game._edit_selected_direction)
	inspector_header.add_child(direction_btn)
	close_btn = Button.new()
	close_btn.text = "×"
	close_btn.theme = controls_theme
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.tooltip_text = "상세 닫기 (Esc)"
	close_btn.pressed.connect(close_inspector)
	inspector_header.add_child(close_btn)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	pic = InfoPanel.new(game)
	pic.hide()
	column.add_child(pic)
	detail = RichTextLabel.new()
	detail.add_theme_font_size_override("normal_font_size", 14)
	detail.add_theme_color_override("default_color", Color("c5cfdc"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.scroll_active = false
	detail.fit_content = true
	detail.bbcode_enabled = false
	column.add_child(detail)
	panel.visible = false
	side.visible = false
	focus_btn = Button.new()
	focus_btn.theme = controls_theme
	focus_btn.focus_mode = Control.FOCUS_NONE
	focus_btn.add_theme_font_size_override("font_size", 14)
	focus_btn.pressed.connect(game._toggle_focus_view)
	focus_btn.z_index = 10
	game.ui_root.add_child(focus_btn)

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
	var p: Vector2 = game.center() + game.view_pan
	p = p.clamp(-limits + half, Meta.FIELD + limits - half)
	game.view_pan = p - game.center()
	game.camera.zoom = Vector2.ONE * fit * game.view_zoom
	game.camera.position = p - (board.get_center() - game.get_viewport_rect().size / 2.0) / (fit * game.view_zoom)
	game.camera.force_update_scroll()

func world_view() -> Rect2:
	var size: Vector2 = screen_board().size / maxf(0.01, fit * game.view_zoom)
	return Rect2(game.center() + game.view_pan - size / 2.0, size)

func over_ui(p: Vector2) -> bool:
	if not active():
		return false
	for c: Control in [panel, footer, side, focus_btn, game.cancel_btn, game.start_btn, game.aim_ok_btn,
			game.hud, game.dps_panel, game.range_btn, game.zoom_btn,
			game.guide_more, game.skip_btn, game.skip_n_btn]:
		if c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(p):
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

func carrying() -> bool:
	return active() and not game.picked.is_empty() and game.moving == null \
		and game.phase in [game.Phase.PLACE, game.Phase.AIM]

func input_blocked() -> bool:
	return not active() or game.get_tree().paused or game.tut.visible or game.settings_panel.visible \
		or game.help_label.visible or game.notes_panel.visible or game.codex_panel.visible \
		or game.vote_panel.visible or game.records_panel.visible

func clear_gesture() -> void:
	pending_card = {}
	pointer_id = -2
	card_dragging = false

func _card_gui_input(event: InputEvent, b: Button, card: Dictionary) -> void:
	if input_blocked() or game.phase != game.Phase.CHOOSE or game.perk_mode or card["type"] == "cata":
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
			game.touches[pointer_id] = touch_position
			clear_gesture()
			touch_capture = false
			return false
		if pending_card.is_empty():
			touch_capture = false
			if game.phase == game.Phase.CHOOSE and not game.perk_mode and game.choice_box.is_visible_in_tree():
				for button: Button in game.choice_box.get_children():
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
			game.call_deferred("_release_card_tap_guard")
			return true
		return false
	var motion: bool = (event is InputEventMouseMotion and pointer_id == -1) \
		or (event is InputEventScreenDrag and event.index == pointer_id)
	var released: bool = (event is InputEventMouseButton and pointer_id == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and event.index == pointer_id and not event.pressed)
	if motion and not card_dragging and pointer.distance_to(press_origin) >= 12.0:
		card_dragging = true
		suppress_tap = true
		game._on_pick(pending_card)
		tick()
	if released:
		var dropped := card_dragging
		var tapped := pending_card
		var was_touch := pointer_id >= 0
		clear_gesture()
		if dropped:
			game._drop_carried_card(pointer)
		elif was_touch:
			game._on_card_tap(tapped, game.offer.find(tapped))
		if dropped or was_touch:
			game.call_deferred("_release_card_tap_guard")
		return dropped or was_touch
	return motion and card_dragging

func preview_card() -> Dictionary:
	if not active() or game.phase != game.Phase.CHOOSE or game.perk_mode or game.cards_hidden or is_instance_valid(inspected_tower):
		return {}
	if game.touch_ui and game.tap_sel >= 0 and game.tap_sel < game.offer.size():
		return game.offer[game.tap_sel]
	if is_instance_valid(hovered) and hovered.get_parent() == game.choice_box and hovered.has_meta("offer_card"):
		return hovered.get_meta("offer_card")
	return {}

func target_ok(t: Tower, card: Dictionary) -> bool:
	return (game._mine(t) or (game.mp_mode == "coop" and card.get("type") == "elem" and t.req_e >= 0 and t.req_e == card.get("e", -1))) and t.can_take(card)

func watch(b: Button, card: Dictionary) -> void:
	b.set_meta("offer_card", card)
	b.mouse_entered.connect(func():
		if not game.touch_ui:
			inspected_tower = null
			hovered = b)
	b.gui_input.connect(_card_gui_input.bind(b, card))
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
		game.ver_label.show()
		return
	camera_fit()
	var size: Vector2 = game.ui_root.size
	var blocked := input_blocked()
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
	game.choice_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.choice_box.position = Vector2(12, panel.position.y + HEADER_HEIGHT)
	game.choice_box.pivot_offset = Vector2.ZERO
	game.choice_box.scale = Vector2.ONE
	game.choice_box.size = Vector2(size.x - 24, CARD_HEIGHT)
	game.choice_box.add_theme_constant_override("separation", 12)
	var cs: Array = game.choice_box.get_children()
	for button: Control in cs:
		if button.is_queued_for_deletion():
			continue
		button.custom_minimum_size = Vector2((size.x - 24 - maxf(0, cs.size() - 1) * 12) / maxi(1, cs.size()), CARD_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if choosing and not game.perk_mode:
		game._update_reroll_btn()
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
		var w := 96.0 if button == game.card_detail_btn else 80.0
		x -= w
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.position = Vector2(x, panel.position.y + 8)
		button.size = Vector2(w, CONTROL_HEIGHT)
		x -= 8
	game._update_choice_header()
	game.choice_header.visible = game.choice_header.visible and cards
	state.visible = cards and not game.choice_header.visible
	state.text = "특성 선택 · 하나 선택"
	state.position = Vector2(12, 9)
	if game.choice_header.visible:
		game.choice_header.set_anchors_preset(Control.PRESET_TOP_LEFT)
		game.choice_header.position = Vector2(12, panel.position.y + 8)
		game.choice_header.size = Vector2(maxf(240, minf(340, x - 24)), CONTROL_HEIGHT)
	_update_side()
	# 상세는 필요할 때 떠 있는 패널로 읽는다. 표시 여부는 전장 크기에 영향을 주지 않는다.
	side.visible = side.visible and not carrying() and not blocked
	_place_side(size, cards)
	game.start_btn.visible = game.phase == game.Phase.READY and not blocked
	game.cancel_btn.visible = game.phase in [game.Phase.PLACE, game.Phase.AIM, game.Phase.MOVE] and not blocked
	game.aim_ok_btn.visible = game._ok_btn_on() and not blocked
	var actions: Array = [game.start_btn, game.cancel_btn, game.aim_ok_btn].filter(func(button): return button.visible)
	var width := 240.0 if game.start_btn.visible else 144.0
	var action_y := size.y - (112.0 if game.bar_open else 52.0)
	for i in actions.size():
		var button: Button = actions[i]
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.position = Vector2((size.x - actions.size() * (width + 8)) / 2 + i * (width + 8), action_y)
		button.size = Vector2(width, 44)
	if game.phase == game.Phase.READY and skip_visible:
		var left := (size.x - 240 - 8 - SKIP_WIDTH) / 2
		game.start_btn.position.x = left
		layout_skip(Vector2(left + 248, action_y), 44)
	if not blocked and not game.guide_label.visible:
		var instruction := ""
		match game.phase:
			game.Phase.PLACE:
				instruction = "빈 곳이나 오브젝트에 놓으세요." if game.picked.get("type", "") == "elem" else "넣을 오브젝트를 고르세요."
			game.Phase.AIM: instruction = "쏠 쪽으로 끌어 보고 확정하세요." if game.touch_ui else "발사 방향을 정하세요."
			game.Phase.MOVE: instruction = "옮길 곳을 고르세요."
		# 대상 위에서는 적용 미리보기가 안내를 대신한다. 긴 효과 글과 하단 안내가 겹치지 않게 한다.
		var target_preview: bool = game.phase == game.Phase.PLACE and game._tower_at(game._pointer_world()) != null
		if instruction != "" and not target_preview:
			game.hint.text = game._kr_keep(instruction)
			game.hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
			game.hint.position = Vector2((size.x - 260) / 2, action_y - 30)
			game.hint.size = Vector2(260, 24)
			game.hint.show()
	game.cancel_btn.text = game._kh("카드 돌려놓기 (Esc)") if carrying() and game.phase == game.Phase.PLACE else game._kh("취소 (Esc)")
	for i in game.skill_btns.size():
		var button: Button = game.skill_btns[i]
		button.z_index = 2
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.position = Vector2(size.x - 12 - game.skill_btns.size() * 150 + i * 150, size.y - 110)
		button.size = Vector2(140, 44)
	if game.zoom_btn.visible:
		game.zoom_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		game.zoom_btn.position = Vector2(12, maxf(64, game.hud.get_rect().end.y + 8))
		game.zoom_btn.size = Vector2(132, 34)
	focus_btn.visible = not blocked and choosing
	focus_btn.text = "카드 보기" if game.cards_hidden else "카드 접기"
	focus_btn.tooltip_text = "카드 패널 보기/접기 (F / V)"
	focus_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	focus_btn.position = Vector2(12, size.y - 48)
	focus_btn.size = Vector2(110, CONTROL_HEIGHT)
	game.ver_label.visible = not focus_btn.visible
	game.skip_badge.position.y = -HEIGHT - 40 if cards else -100

func layout_skip(at: Vector2, height: float) -> void:
	skip_group.position = at
	skip_group.size = Vector2(SKIP_WIDTH, height)
	for i in 2:
		var button: Button = [game.skip_btn, game.skip_n_btn][i]
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.position = at + Vector2(108 if i == 1 else 0, 0)
		button.size = Vector2(96 if i == 1 else 108, height)


func close_inspector() -> void:
	dismissed_tower = game._tower_at(game._pointer_world())
	game.selected.clear()
	game.tip_tower = null
	inspected_tower = null
	shown_tower = null
	hovered = null
	pic.clear()
	side.hide()
	side_signature = ""


func _update_side() -> void:
	var mouse: Vector2 = game._pointer_screen()
	var tower: Tower = game._tower_at(game._pointer_world()) if not over_ui(mouse) else null
	if tower == dismissed_tower:
		tower = null
	else:
		dismissed_tower = null
	if tower != null:
		hovered = null
		inspected_tower = tower
	var card := preview_card()
	var title := "전장 안내"
	var text := ""
	var has_content := false
	shown_tower = null
	if not card.is_empty():
		inspected_tower = null
		has_content = true
		var cc: Dictionary = game._card_content(card, 0)
		title = cc["head"]["name"]
		var take := 0
		var reaction := 0
		for t: Tower in game.towers.get_children():
			if not target_ok(t, card):
				continue
			take += 1
			if card["type"] == "elem" and not Elem.new_reactions(t.eff_now(), card["e"]).is_empty():
				reaction += 1
		pic.show_card(card, cc["head"], take, reaction, game._combo_parts(card["e"])["els"] if card["type"] == "elem" else [], _pic_w())
		var full: Array = game._card_full(card)
		var fit_name: String = game.core_fit(card)
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
	elif game.perk_mode and is_instance_valid(hovered) and hovered.get_parent() == game.choice_box and hovered.has_meta("perk_desc"):
		inspected_tower = null
		has_content = true
		title = hovered.get_meta("card")[0]["name"]
		text = hovered.get_meta("perk_desc")
	else:
		if is_instance_valid(inspected_tower) and not inspected_tower.is_queued_for_deletion() and inspected_tower.get_parent() == game.towers:
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
			var more: bool = game._tip_detail_on()
			pic.show_tower(tower, more, part, "이번 웨이브 몫" if game.phase == game.Phase.WAVE else "지난 웨이브 몫", _pic_w())
			# 그림으로 못 보이는 것만 글로: 자세히일 때 반응 설명 (공격 모양은 미리보기가 보여 준다)
			if more:
				for rx in tower.reactions():
					text += ("\n\n" if text != "" else "") + str(rx["name"]) + ": " + str(rx["desc"])
	if pic.mode != "" and ((pic.mode == "tower" and shown_tower == null) or (pic.mode == "card" and card.is_empty())):
		pic.clear()
	direction_btn.visible = shown_tower != null and game.selected.size() == 1 and shown_tower == game.selected[0] and game._mine(shown_tower) and game.phase in [game.Phase.CHOOSE, game.Phase.READY]
	heading.visible = true
	detail.visible = text != ""
	var sig: String = title + "|" + text + ("|" + str(tower.get_instance_id()) if is_instance_valid(tower) and card.is_empty() else "")
	side.visible = active() and has_content and (card.is_empty() or Meta.card_detail)
	if sig != side_signature:
		heading.text = "오브젝트 정보" if pic.mode == "tower" else ("카드 정보" if pic.mode == "card" else title)
		detail.text = game._kr_keep(text)
		scroll.scroll_vertical = 0
		side_signature = sig

## 설명창 자리: 오른쪽 기둥 대신 내용 높이만큼만, 오른쪽 위·왼쪽 위 중 오브젝트를 덜 가리는 쪽에 뜬다.
## 보고 있는 오브젝트(shown_tower)는 가리지 않는다. 비슷하면 지금 쪽에 머문다(왔다 갔다 하지 않게).
func _place_side(size: Vector2, cards: bool) -> void:
	var w := clampf(size.x * 0.28, 240.0, 330.0)
	side.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var top := maxf(60.0, game.hud.get_rect().end.y + 8.0)
	var bottom: float = panel.position.y - 12.0 if cards else size.y - 64.0
	var ltop := top
	for c: Control in [game.dps_panel, game.zoom_btn]:
		if c.is_visible_in_tree():
			ltop = maxf(ltop, c.get_rect().end.y + 8.0)
	var sb: StyleBox = side.get_theme_stylebox("panel")
	var parts := []
	parts.append(inspector_header.get_combined_minimum_size().y)
	if pic.visible:
		parts.append(pic.custom_minimum_size.y)
	if detail.visible:
		parts.append(detail.get_content_height())
	var want: float = sb.get_minimum_size().y + 4.0 + 12.0 * maxf(0, parts.size() - 1)
	for v in parts:
		want += v
	var cands := [Rect2(size.x - w - 12.0, top, w, 0.0), Rect2(12.0, ltop, w, 0.0)]
	for control: Control in [game.toast, game.banner]:
		if not control.is_visible_in_tree():
			continue
		var overlay := control.get_rect()
		for i in cands.size():
			var candidate: Rect2 = cands[i]
			if overlay.position.x < candidate.end.x and overlay.end.x > candidate.position.x:
				candidate.position.y = maxf(candidate.position.y, overlay.end.y + 8)
				cands[i] = candidate
	var scores := []
	var inv: Transform2D = game.ui_root.get_global_transform().affine_inverse()
	var canvas: Transform2D = game.get_viewport().get_canvas_transform()
	var pad: float = 26.0 * fit * game.view_zoom
	for i in cands.size():
		var r: Rect2 = cands[i]
		r.size.y = clampf(want, 100.0, maxf(100.0, bottom - r.position.y))
		cands[i] = r
		var sc := 0.0
		for t: Tower in game.towers.get_children():
			var at: Vector2 = inv * (canvas * t.global_position)
			if r.grow(pad).has_point(at):
				sc += 100.0 if t == shown_tower else 1.0
		if r.size.y < want - 1.0:
			sc += 0.5  # 다 안 들어가 스크롤해야 하는 쪽은 조금 덜 고른다
		scores.append(sc)
	var cur := 1 if side_left else 0
	if scores[1 - cur] < scores[cur]:
		cur = 1 - cur
	side_left = cur == 1
	var pick: Rect2 = cands[cur]
	side.position = pick.position
	side.size = pick.size
	# 읽는 패널의 클릭·스크롤은 뒤 전장으로 넘기지 않는다.
	side.mouse_filter = Control.MOUSE_FILTER_STOP
	detail.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP


## 설명창 그림 폭: 설명창 폭에서 안쪽 여백을 뺀 값.
func _pic_w() -> float:
	return side.size.x - 28.0


func summary_text(b: Button) -> String:
	var summary := ""
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
	b.draw_string(font, Vector2(36, 28), name, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 64, 18, col.lightened(0.2))
	if not game.touch_ui:
		Glyph.keycap(b, font, Vector2(b.size.x - 8, 8), str(h["idx"]))
	var summary := summary_text(b)
	var lines: PackedStringArray = game._wrap_words(game._kr_keep(summary), b.size.x - 28, 14).split("\n")
	var visible_lines := mini(2, lines.size())
	for i in visible_lines:
		var line := lines[i]
		if i == visible_lines - 1 and lines.size() > visible_lines:
			while line.length() > 0 and font.get_string_size(line + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > b.size.x - 28:
				line = line.left(-1)
			line += "…"
		b.draw_string(font, Vector2(14, 51 + 18 * i), line, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 28, 14, Color("d2dae6"))
	var foot := "특성 · 상세는 오른쪽에서 확인"
	var destinations: Array = b.get_meta("card_foot", [])
	if not destinations.is_empty():
		foot = " · ".join(destinations.map(func(it): return it[1]))
	b.draw_string(font, Vector2(14, 86), foot, HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 28, 11, Color("8294aa"))
