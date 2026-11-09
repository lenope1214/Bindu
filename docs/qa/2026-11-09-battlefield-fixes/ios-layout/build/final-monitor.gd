extends "res://qa_ios/lifecycle.gd"
## 실제 iOS 글꼴·안전 영역의 기술 조작부 관찰. 게임 알림·터치를 합성하지 않는다.
var layout_settled := false
var control_actions := []

func attach() -> void:
	await super.attach()
	var controls: Array=main.skill_btns.duplicate()
	controls.append(main.abilities_system.skill_auto_btn)
	for index in controls.size():
		connect_action(controls[index],index)

func connect_action(button: Button,index: int) -> void:
	button.pressed.connect(func():
		control_actions.append({"index":index,"skill_arm":main.skill_arm,"skill_auto":Meta.skill_auto,"skill_used":main.skill_used,"at_ms":Time.get_ticks_msec()})
		write_status())

func prepare_case(next_stage: String) -> void:
	layout_settled=false
	await super.prepare_case("wave")
	var parts := next_stage.split("|")
	assert(parts.size()==4)
	stage=next_stage
	if parts[0]!="native":
		Meta.ui_scale=float(parts[0])
		main.hud_system._apply_ui_scale()
	main.abilities_system._skills_new_run(int(parts[1]))
	Meta.skill_auto=false
	main.bar_open=parts[3]=="open"
	if parts[2]=="cooldown":
		for id in main.skill_ids:main.skill_cd[id]=Skill.cd_full(id,0)
	elif parts[2].begins_with("armed"):main.abilities_system._arm_skill(int(parts[2].trim_prefix("armed")))
	elif parts[2]=="inspected":main.interaction_system._select_tower(target)
	for i in 8:await get_tree().process_frame
	layout_settled=true
	write_status()

func rect_data(r: Rect2) -> Array:
	return [r.position.x,r.position.y,r.size.x,r.size.y]

func button_data(button: Button) -> Dictionary:
	var font := button.get_theme_font("font")
	var fs := button.get_theme_font_size("font_size")
	var style := button.get_theme_stylebox("normal")
	var border := []
	if style is StyleBoxFlat:
		border=[style.border_width_left,style.border_width_top,style.border_width_right,style.border_width_bottom]
	var paragraph := TextParagraph.new()
	paragraph.break_flags=TextServer.BREAK_MANDATORY|button.autowrap_trim_flags
	paragraph.line_spacing=button.get_theme_constant("line_spacing")
	paragraph.direction=TextServer.DIRECTION_RTL if button.is_layout_rtl() else TextServer.DIRECTION_LTR
	paragraph.add_string(button.text,font,fs,TranslationServer.get_locale())
	return {"name":button.name,"text":button.text,"visible":button.is_visible_in_tree(),"rect":rect_data(button.get_global_rect()),"local_rect":rect_data(button.get_rect()),"minimum":[button.get_combined_minimum_size().x,button.get_combined_minimum_size().y],"font_size":fs,"font_names":font.get_font_names(),"normal_border":border,"text_size":str(paragraph.get_size()),"untrimmed_text_size":str(font.get_multiline_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs)),"style_minimum":str(style.get_minimum_size()),"center":[button.get_global_rect().get_center().x/main.get_viewport_rect().size.x,button.get_global_rect().get_center().y/main.get_viewport_rect().size.y]}

func write_status() -> void:
	super.write_status()
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(STATUS))
	var buttons := []
	for button: Button in main.skill_btns:buttons.append(button_data(button))
	buttons.append(button_data(main.abilities_system.skill_auto_btn))
	record["layout"]={"settled":layout_settled,"safe_ui_rect":rect_data(main.ui_root.get_global_rect()),"safe_pad":rect_data(main.hud_system._safe_pad()),"display_safe_rect":rect_data(Rect2(DisplayServer.get_display_safe_area())),"window_size":str(DisplayServer.window_get_size()),"ui_scale":Meta.ui_scale,"buttons":buttons,"bar_rect":rect_data(main.bar_box.get_global_rect()),"bar_visible":main.bar_open,"hint_rect":rect_data(main.hint.get_global_rect()),"hint_visible":main.hint.visible,"camera":str(main.get_canvas_transform()),"field":str(Meta.FIELD)}
	record["layout"]["control_actions"]=control_actions
	record["layout"]["inspector"]={"visible":main.card_dock.side.is_visible_in_tree(),"rect":rect_data(main.card_dock.side.get_global_rect())}
	record["layout"]["screen_scale"]=DisplayServer.screen_get_scale()
	var file := FileAccess.open(STATUS+".tmp",FileAccess.WRITE)
	file.store_string(JSON.stringify(record));file.close()
	DirAccess.rename_absolute(STATUS+".tmp",STATUS)
