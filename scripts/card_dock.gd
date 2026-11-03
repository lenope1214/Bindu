class_name CardDock
extends RefCounted
## 일반 판의 고정 하단 도크. 전장 규칙은 그대로 두고 표시 영역과 입력만 분리한다.
const HEIGHT := 188.0
const CARD_HEIGHT := 94.0
var game
var panel: Panel
var side: PanelContainer
var heading: Label
var detail: RichTextLabel
var state: Label
var hovered: Button
var side_signature := ""
var board := Rect2()
var fit := 1.0

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
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	side.add_child(column)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 19)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	detail = RichTextLabel.new()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("normal_font_size", 14)
	detail.add_theme_color_override("default_color", Color("c5cfdc"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.scroll_active = true
	detail.bbcode_enabled = false
	column.add_child(detail)
	panel.visible = false
	side.visible = false

func active() -> bool:
	return not Garden.on and game.title_label != null and not game.title_label.visible and game.phase != game.Phase.GAMEOVER

func bounds() -> Rect2:
	var size: Vector2 = game.ui_root.size
	var right := clampf(size.x * 0.25, 220.0, 290.0)
	return Rect2(8, 48, size.x - right - 24, maxf(80, size.y - HEIGHT - 60))

func screen_board() -> Rect2:
	return game.ui_root.get_global_transform() * bounds()

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
	return active() and not screen_board().has_point(p)

func preview_card() -> Dictionary:
	if not active() or game.phase != game.Phase.CHOOSE or game.perk_mode or game.cards_hidden:
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
			hovered = b)
	# 상세 영역으로 마우스를 옮겨도 읽던 카드와 강조를 유지한다. 다른 카드는 진입 시 교체한다.

func card_size() -> Vector2:
	var count := maxi(game.offer.size(), 3)
	return Vector2(maxf(120, (game.ui_root.size.x - 24 - (count - 1) * 12) / count), CARD_HEIGHT)

func tick() -> void:
	var on := active()
	var was := panel.visible
	panel.visible = on
	side.visible = on
	if not on:
		if was:
			game._clamp_pan()
		return
	var size: Vector2 = game.ui_root.size
	var field := bounds()
	panel.position = Vector2(0, size.y - HEIGHT)
	panel.size = Vector2(size.x, HEIGHT)
	side.position = Vector2(field.end.x + 8, 48)
	side.size = Vector2(size.x - side.position.x - 8, size.y - HEIGHT - 60)
	game.legend.visible = false
	game.card_dim.visible = false
	for c: Control in [game.bar_box, game.hint, game.ver_label, game.start_btn, game.cancel_btn, game.draw_ok_btn, game.skip_badge]:
		c.z_index = 2
	camera_fit()
	var choosing: bool = game.phase == game.Phase.CHOOSE and game.coin_stage == 0
	var cards: bool = choosing and not game.cards_hidden and game.choice_box.visible
	var title := "특성 선택" if game.perk_mode else "카드 선택"
	state.text = ("특성 선택  ·  하나 선택" if game.perk_mode else "%s  ·  %d장 남음" % [title, game.picks_left]) if choosing else "전투 중" if game.phase == game.Phase.WAVE else "배치 준비"
	state.position = Vector2(12, 9)
	state.size = Vector2(200, 28)
	game.choice_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.choice_box.position = Vector2(12, panel.position.y + 42)
	game.choice_box.scale = Vector2.ONE
	game.choice_box.size = Vector2(size.x - 24, CARD_HEIGHT)
	game.choice_box.add_theme_constant_override("separation", 12)
	var cs: Array = game.choice_box.get_children()
	for b: Control in cs:
		if b.is_queued_for_deletion():
			continue
		b.custom_minimum_size = Vector2((size.x - 24 - maxf(0, cs.size() - 1) * 12) / maxi(1, cs.size()), CARD_HEIGHT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	game.hide_btn.text = "보기" if game.cards_hidden else ""
	var x := size.x - 12.0
	var buttons: Array = [game.skip_n_btn, game.skip_btn, game.hide_btn, game.card_detail_btn, game.reroll_btn]
	if game.touch_ui and game.tap_sel >= 0 and not game.perk_mode and cards:
		buttons.push_front(game.apply_btn)
	for b: Button in buttons:
		if not b.visible and b != game.apply_btn:
			continue
		if b == game.apply_btn:
			b.visible = cards and game.tap_sel >= 0
		var w := maxf(132.0, b.get_combined_minimum_size().x) if b == game.apply_btn else 78.0 if b == game.card_detail_btn else 64.0
		x -= w
		b.set_anchors_preset(Control.PRESET_TOP_LEFT)
		b.position = Vector2(x, panel.position.y + 4)
		b.size = Vector2(w, 34)
		x -= 8
	if game.cards_hidden:
		game.hide_btn.tooltip_text = "카드 다시 보기 (V)"
	if game.zoom_btn.visible:
		game.zoom_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		game.zoom_btn.position = Vector2(150, size.y - 48)
		game.zoom_btn.size = Vector2(132, 34)
		game.zoom_btn.z_index = 2
	for i in game.skill_btns.size():
		var b: Button = game.skill_btns[i]
		b.z_index = 2
		b.set_anchors_preset(Control.PRESET_TOP_LEFT)
		b.position = Vector2(size.x - 12 - game.skill_btns.size() * 176 + i * 176, panel.position.y + 66)
		b.size = Vector2(166, 50)
	game.hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.hint.position = Vector2(16, panel.position.y + 46)
	game.hint.size = Vector2(maxf(200, size.x - 360), 76)
	game.hint.visible = not cards and not game.title_label.visible
	if game.phase == game.Phase.WAVE:
		game.hint.text = "기술을 사용하거나 전장의 구체·오브젝트를 확인하세요."
		game.hint.size.x = maxf(150, size.x - 410)
	var actions: Array = [game.start_btn, game.cancel_btn, game.draw_ok_btn].filter(func(b): return b.visible)
	var action_width := (280.0 - maxf(0, actions.size() - 1) * 8) / maxi(1, actions.size())
	for i in actions.size():
		var b: Button = actions[i]
		b.set_anchors_preset(Control.PRESET_TOP_LEFT)
		b.position = Vector2(size.x - 300 + i * (action_width + 8), panel.position.y + 62)
		b.size = Vector2(action_width, 44)
	game.ver_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.ver_label.position = Vector2(12, size.y - 22)
	game.skip_badge.position.y = -HEIGHT - 40
	game._update_choice_header()
	state.visible = not game.choice_header.visible
	if game.choice_header.visible:
		game.choice_header.set_anchors_preset(Control.PRESET_TOP_LEFT)
		game.choice_header.position = Vector2(12, panel.position.y + 4)
		game.choice_header.size = Vector2(maxf(240, minf(340, x - 24)), 34)
	_update_side()

func _update_side() -> void:
	var card := preview_card()
	var title := "전장 안내"
	var text: String = game.legend.text if not game.legend_hidden else "카드에 마우스를 올리면 적용 대상과 반응을 확인합니다.\n\n카드와 전장은 항상 함께 보입니다."
	if not card.is_empty():
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
		text = "적용 가능 %d곳 · 새 반응 %d곳\n얇은 고리: 적용 · 빛나는 고리: 새 반응\n\n" % [take, reaction]
		var full: Array = game._card_full(card)
		var fit_name: String = game.core_fit(card)
		if fit_name != "":
			full.append(["주력 %s 강화" % fit_name, Color.WHITE])
		if MapRule.card_aff(card):
			var bonus := " · 피해 +%d%%" % roundi(Rules.t("map_aff_dmg") * 100) if card["type"] in ["elem", "pat"] else ""
			full.append([str(Meta.MAPS[Meta.map_id]["name"]) + " 친화" + bonus, Color.WHITE])
		for row in (full if Meta.card_detail else full.slice(0, 2)):
			text += str(row[0]) + "\n\n"
		if not Meta.card_detail:
			text += "자세히를 켜면 반응·적용 조건을 모두 볼 수 있어요." if game.touch_ui else "자세히(Z)를 켜면 반응·적용 조건을 모두 볼 수 있어요."
	elif game.perk_mode and is_instance_valid(hovered) and hovered.get_parent() == game.choice_box and hovered.has_meta("perk_desc"):
		title = hovered.get_meta("card")[0]["name"]
		text = hovered.get_meta("perk_desc")
	var sig: String = title + "|" + text
	if sig != side_signature:
		heading.text = title
		detail.text = game._kr_keep(text)
		detail.scroll_to_line(0)
		side_signature = sig

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
