extends "res://tools/battlefield_feedback_check.gd"
## Temporary QA FieldView adds only a passthrough flag; never used in product.
func _after_dense_snapshot() -> void:
	var raw: Array = main.popups
	var copied: Array = raw.duplicate(true)
	var state := [main.core_hp,main.score,main.run_game,main.wave_time,main.towers.get_child_count(),main.orbs.get_child_count()]
	var camera: Transform2D = main.get_canvas_transform()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var viewport: RID = main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var old_process: int = main.process_mode
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var rng := []
	var captures := []
	for before in [true,false]:
		var draw: Dictionary = await draw_one(before)
		rng.append(draw.next_rng)
		var path := output.path_join("matched-before.png" if before else "matched-after.png")
		main.get_viewport().get_texture().get_image().save_png(path)
		captures.append(FileAccess.get_sha256(path))
	verify(captures[0]!=captures[1],"actual redraw changes matched capture")
	verify(rng[0]==rng[1],"matched full FX draw preserves next RNG")
	verify(main.popups==copied,"matched capture preserves exact popup store")
	var bounds: Rect2 = main.viewport_system.arena().grow(-60.0)
	var scattered := []
	var unique := []
	var numbers := []
	for i in 121:
		var at := bounds.position+Vector2(bounds.size.x*(i%11)/10.0,bounds.size.y*floori(i/11.0)/10.0)
		scattered.append(popup(at,"되풀이"))
		unique.append(popup(at,"안내 "+str(i)))
		numbers.append(popup(at,str(i+1)))
	var results := []
	for dataset in [["live",raw],["scattered",scattered],["unique",unique],["numbers",numbers]]:
		main.popups = dataset[1]
		for i in 10:
			for before in [true,false]:await draw_one(before)
		var timing := [[],[]]
		var render_cpu := [[],[]]
		var rng_ok := true
		for batch in 7:
			var sequences := [[],[]]
			for which in ([0,1] if batch%2==0 else [1,0]):
				var elapsed := 0.0
				var cpu := 0.0
				for repeat in 10:
					var draw: Dictionary = await draw_one(which==0)
					sequences[which].append(draw.next_rng)
					elapsed += draw.popup_us/1000.0
					cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
				timing[which].append(elapsed/10.0)
				render_cpu[which].append(cpu/10.0)
			rng_ok = rng_ok and sequences[0]==sequences[1]
		verify(rng_ok,str(dataset[0])+": repeated full FX draws keep RNG sequence")
		var original: Array = timing[0].duplicate()
		var selected: Array = timing[1].duplicate()
		original.sort()
		selected.sort()
		results.append({"dataset":dataset[0],"raw_count":main.popups.size(),"selected_count":display_rows().size(),"raw_popup_cpu_ms":timing[0],"selected_popup_cpu_ms":timing[1],"raw_median_ms":original[3],"selected_median_ms":selected[3],"raw_render_cpu_ms":render_cpu[0],"selected_render_cpu_ms":render_cpu[1],"rng_equal":rng_ok})
		print("DRAW CASE ",JSON.stringify(results[-1]))
	main.process_mode = old_process
	main.popups = raw
	main.field_view_system.set("qa_popup_passthrough",false)
	verify(main.popups==copied and main.get_canvas_transform()==camera,"draw-only benchmark preserves data/camera")
	verify(state==[main.core_hp,main.score,main.run_game,main.wave_time,main.towers.get_child_count(),main.orbs.get_child_count()],"draw-only benchmark does not advance combat")
	FileAccess.open(output.path_join("draw-benchmark.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"Frozen400-orb scene; awaited FX redraws, alternate7batches10draws; seed9222 before each draw; popup selection+draw-string enqueue CPU from temporary instrumentation. Not whole-frame FPS or physical display latency.","results":results},"\t"))

func draw_one(before: bool) -> Dictionary:
	main.field_view_system.set("qa_popup_passthrough",before)
	var count: int = main.field_view_system.get("qa_draw_count")
	seed(9222)
	main.fx_layer.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	verify(main.field_view_system.get("qa_draw_count")==count+1,"one actual popup draw callback")
	return {"popup_us":main.field_view_system.get("qa_popup_us"),"next_rng":main.field_view_system.get("qa_next_rng")}
