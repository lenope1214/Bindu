extends "res://qa_ios/lifecycle.gd"
## 격리 iOS 앱: 실제 InfoPanel._tile 호출과 스크롤 clip을 관찰한다.
class ReadingPanel:
	extends "res://scripts/info_panel.gd"
	var tile_rows: Array[Dictionary] = []
	var active_tile := -1
	func _init(owner_main) -> void:
		super(owner_main)
	func _draw() -> void:
		tile_rows.clear()
		super._draw()
	func _tile(r: Rect2, icon: String, color: Color, big: String, small: String) -> void:
		tile_rows.append({"rect":r,"big":big,"small":small,"texts":[]})
		active_tile=tile_rows.size()-1
		super._tile(r,icon,color,big,small)
		active_tile=-1
	func _txt(p: Vector2, s: String, fs: float, color := Color("d9e5f5"), width := -1.0) -> void:
		if active_tile>=0:
			var actual_fs: int=int(maxf(fs,13.0) if Meta.phone() else fs)
			var required: float=font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,actual_fs).x
			var available: float=tile_rows[active_tile].rect.end.x-p.x
			if width>=0:available=minf(available,width)
			tile_rows[active_tile].texts.append({"text":s,"required":required,"available":available,"font_size":actual_fs})
		super._txt(p,s,fs,color,width)

var reading_panel: ReadingPanel
var reading_settled := false

func attach() -> void:
	await super.attach()
	var previous: Control = main.card_dock.pic
	var parent: Node = previous.get_parent()
	var index: int = previous.get_index()
	reading_panel=ReadingPanel.new(main)
	parent.remove_child(previous)
	previous.free()
	parent.add_child(reading_panel)
	parent.move_child(reading_panel,index)
	main.card_dock.pic=reading_panel

func prepare_case(next_stage: String) -> void:
	reading_settled=false
	await super.prepare_case("wave")
	var parts := next_stage.split("|")
	assert(parts.size()==5)
	stage=next_stage
	Meta.ui_scale=float(parts[0])
	main.hud_system._apply_ui_scale()
	main.abilities_system._skills_new_run(0)
	main.tip_detail=parts[4]=="detail"
	main.card_dock.pic.set_preview_visible(parts[4]=="preview")
	if parts[1]=="dense":
		target.elements.clear()
		target.order.clear()
		for element in Elem.ALL:
			target.elements[element]=3
			target.order.append(element)
		target.eff=target.eff_now()
	if parts[2]=="ready":
		main.wave_active=false
		main.cards_system._enter_ready()
	elif parts[2]=="choose":
		main.wave_active=false
		main.picks_left=2
		main.phase=main.Phase.CHOOSE
		main.cards_system._show_offer()
		main.cards_system._open_choose()
		main.cards_system._set_cards_hidden(true)
	if parts[3]=="right":
		target.position=Vector2(950,320)
		main.towers.get_child(1).position=Vector2(300,320)
	main.card_dock.inspector_dismissed=false
	main.interaction_system._select_tower(target)
	main.bar_open=false
	main.banner_t=2.3  # 실제 웨이브 진입 배너와 동시에 읽는 상태도 유지한다.
	for i in 12:await get_tree().process_frame
	reading_settled=true
	write_status()

func rect_data(r: Rect2) -> Array:
	return [r.position.x,r.position.y,r.size.x,r.size.y]

func write_status() -> void:
	super.write_status()
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(STATUS))
	var rows := []
	if is_instance_valid(reading_panel):
		for row in reading_panel.tile_rows:
			rows.append({"rect":rect_data(reading_panel.get_global_transform()*row.rect),"big":row.big,"small":row.small,"texts":row.texts})
	var controls := []
	for control: Control in main.abilities_system.skill_controls():
		if control.is_visible_in_tree():controls.append(rect_data(control.get_global_rect()))
	report["reading"]={"settled":reading_settled,"tiles":rows,"scroll":rect_data(main.card_dock.scroll.get_global_rect()),"scroll_value":main.card_dock.scroll.scroll_vertical,"inspector":rect_data(main.card_dock.side.get_global_rect()),"inspector_visible":main.card_dock.side.is_visible_in_tree(),"safe_ui":rect_data(main.ui_root.get_global_rect()),"preview_button":rect_data(main.card_dock.preview_btn.get_global_rect()),"preview_visible":main.card_dock.pic.preview_visible,"preview_button_visible":main.card_dock.preview_btn.is_visible_in_tree(),"preview_rect":rect_data(main.card_dock.pic.attack_preview.get_global_rect()),"preview_caption":rect_data(main.card_dock.pic.attack_preview.caption.get_global_rect()),"preview_texture_size":str(main.card_dock.pic.attack_preview.viewport.size),"camera":str(main.get_canvas_transform()),"field":str(Meta.FIELD),"skill_controls":controls,"banner":rect_data(main.banner.get_global_rect()),"banner_visible":main.banner.visible}
	var file := FileAccess.open(STATUS+".tmp",FileAccess.WRITE)
	file.store_string(JSON.stringify(report));file.close()
	DirAccess.rename_absolute(STATUS+".tmp",STATUS)
