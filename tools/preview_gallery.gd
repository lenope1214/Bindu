extends "res://tools/carry_check.gd"
## 실제 인스펙터의 SubViewport 렌더링을 공격방식별로 캡처한다.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	output = args[0]
	Tutorial.loaded = true
	Tutorial.done = true
	Meta.guide_on = false
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main.progression_system._hide_title()
	main.set_process(false)
	await fixture()
	main.interaction_system._select_tower(target)
	await settle()
	var preview: AttackPreview = main.card_dock.pic.attack_preview
	preview.set_process(false)
	preview.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 12)
	var captured := 0
	for pat in Pat.ALL_IDS:
		target.pattern = pat
		target.elements = {Elem.METAL: 2, Elem.WATER: 1}
		target.order.assign([Elem.METAL, Elem.WATER])
		preview.configure(target)
		for frame in 9: preview.advance(1.0 / 60.0)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var first := preview.viewport.get_texture().get_image()
		first.save_png(output.path_join(pat + "-early.png"))
		if pat in ["spray", "stream", "laser", "sonic", "clock"]:
			preview.world.wave_active = false
			preview.clone.queue_redraw()
			await process_frame
			RenderingServer.force_draw()
			var idle := preview.viewport.get_texture().get_image()
			var region := Rect2i(90, 50, 40, 100)
			ok("UI-37", first.get_region(region).get_data() != idle.get_region(region).get_data(), "본체 앞 공격 그림이 전투 상태에서 출력: " + pat)
			preview.world.wave_active = true
			preview.clone.queue_redraw()
		ok("UI-37", first.get_used_rect().has_area(), "공격방식 렌더링: " + pat)
		for frame in 45: preview.advance(1.0 / 60.0)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var later := preview.viewport.get_texture().get_image()
		later.save_png(output.path_join(pat + "-later.png"))
		var cell := VBoxContainer.new()
		var label := Label.new()
		label.text = Pat.pname(pat)
		label.add_theme_font_override("font", main.ui_font)
		cell.add_child(label)
		var picture := TextureRect.new()
		picture.texture = ImageTexture.create_from_image(first)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.custom_minimum_size = Vector2(240, 140)
		cell.add_child(picture)
		grid.add_child(cell)
		captured += 1
	preview.world.eclipse_flash = 0.4
	preview.world.fx_layer.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	var eclipse := preview.viewport.get_texture().get_image()
	ok("UI-37", eclipse.get_pixel(0, 0).a > 0.05, "일식 화면 효과도 미리보기 영역 안에 출력")
	preview.world.eclipse_flash = 0.0
	var back := ColorRect.new()
	back.color = Color("10131c")
	back.size = Vector2(1280, 720)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	VirtualInput.viewport.add_child(overlay)
	overlay.add_child(back)
	overlay.add_child(grid)
	await process_frame
	RenderingServer.force_draw()
	VirtualInput.viewport.get_texture().get_image().save_png(output.path_join("gallery.png"))
	ok("UI-37", captured == Pat.ALL_IDS.size(), "모든 공격방식 초기·명중 이후 캡처 완료")
	print("PREVIEW GALLERY cases=%d failures=%d" % [captured, fails])
	quit(1 if fails else 0)
