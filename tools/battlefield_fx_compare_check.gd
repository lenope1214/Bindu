extends "res://tools/battlefield_feedback_check.gd"
## 같은 정지 장면의 native FX 명령과 후속 RNG를 비교한다.
var trace_mode := true

func qcheck(value: bool,label: String) -> void:
	checks+=1
	ok("UI-51",value,label)

func _after_dense_snapshot() -> void:
	trace_mode=OS.get_cmdline_user_args()[4]=="contract"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var mode: int = main.process_mode
	main.process_mode=Node.PROCESS_MODE_DISABLED
	main.sfx.muted=true
	Meta.fx_dps=0
	for tower in main.towers.get_children():tower.fx_a=1.0
	var viewport: RID = main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var snapshot := combat_state()
	var camera: Transform2D = main.get_canvas_transform()
	var results := []
	for reduced in [false,true]:
		Meta.fx_low=reduced
		var pair := []
		for before in [true,false]:
			main.field_view_system.set("qa_before",before)
			main.field_view_system._soften_fx()
			for warm in (2 if trace_mode else 12):await draw_scene()
			var data: Dictionary = await draw_scene()
			pair.append(data)
			main.get_viewport().get_texture().get_image().save_png(output.path_join(("reduced"if reduced else"full")+("-before.png"if before else"-after.png")))
			qcheck(snapshot==combat_state(),"draw mode preserves combat snapshot")
			qcheck(camera==main.get_canvas_transform(),"draw mode preserves camera")
		qcheck(pair[0].next_rng==pair[1].next_rng,"paired full scene draw preserves next RNG")
		if trace_mode:
			if not reduced:qcheck(pair[0].commands==pair[1].commands,"default FX command arguments/order identical")
			else:
				qcheck(pair[1].commands.size()<pair[0].commands.size(),"reduced mode emits fewer native FX commands")
				var decorative: Array = main.field_view_system.get("qa_decorative_keys")
				var protected_before: Array = pair[0].commands.filter(func(row):return not row[0] in decorative)
				var protected_after: Array = pair[1].commands.filter(func(row):return not row[0] in decorative)
				qcheck(protected_before==protected_after,"all other FX native command arguments/order preserved")
			results.append({"reduced":reduced,"before_commands":pair[0].commands.size(),"after_commands":pair[1].commands.size(),"next_rng_equal":pair[0].next_rng==pair[1].next_rng})
		else:
			var values := [[],[]]
			var render_cpu := [[],[]]
			var draw_return := [[],[]]
			for batch in 7:
				var rng := [[],[]]
				for which in ([0,1]if batch%2==0 else[1,0]):
					main.field_view_system.set("qa_before",which==0)
					# viewport CPU 질의의 이전 draw 결과가 섞이지 않게 전환 후 준비한다.
					for settle in 6:await draw_scene()
					var elapsed := 0.0
					var cpu := 0.0
					var returned := 0.0
					for repeat in 5:
						var draw: Dictionary = await draw_scene()
						rng[which].append(draw.next_rng)
						elapsed+=draw.fx_us/1000.0
						returned+=draw.queue_to_return_ms
						cpu+=RenderingServer.viewport_get_measured_render_time_cpu(viewport)
					values[which].append(elapsed/5.0)
					render_cpu[which].append(cpu/5.0)
					draw_return[which].append(returned/5.0)
				qcheck(rng[0]==rng[1],"alternating draws retain RNG sequence")
			results.append({"reduced":reduced,"fx_cpu_ms":values,"viewport_cpu_query_ms":render_cpu,"queue_to_force_draw_return_ms":draw_return})
	var record := {"mode":"contract"if trace_mode else"benchmark","checks":checks,"failures":fails,"ui_errors":ui_errors,"results":results,"effect_counts":{"arcs":main.arcs.size(),"pulses":main.pulses.size(),"beams":main.beams.size(),"bolts":main.bolts.size(),"particles":main.particles.size()},"source_field_sha256":FileAccess.get_sha256("res://scripts/features/field_view.gd")}
	record.tool_sha256=FileAccess.get_sha256("res://tools/battlefield_fx_compare_check.gd")
	record.settling_draws_per_benchmark_switch=6
	FileAccess.open(output.path_join("fx-compare.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	Meta.fx_low=false
	main.process_mode=mode

func draw_scene() -> Dictionary:
	var started := Time.get_ticks_usec()
	main.field_view_system.set("qa_fx_commands",[])
	var count: int = main.field_view_system.get("qa_fx_count")
	seed(9222)
	main.queue_redraw()
	for layer in [main.towers,main.orbs,main.projectiles,main.zones]:
		for node in layer.get_children():node.queue_redraw()
	main.fx_layer.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var queue_to_return_ms := (Time.get_ticks_usec()-started)/1000.0
	qcheck(main.field_view_system.get("qa_fx_count")==count+1,"one actual FX callback")
	return {"next_rng":randi(),"fx_us":main.field_view_system.get("qa_fx_us"),"queue_to_return_ms":queue_to_return_ms,"commands":main.field_view_system.get("qa_fx_commands").duplicate(true)}

func combat_state() -> Array:
	var data := [main.sim_id,main.core_hp,main.score,main.run_game,main.wave_time,main.popups.duplicate(true),main.particles.duplicate(true),main.beams.duplicate(true),main.bolts.duplicate(true),main.pulses.duplicate(true)]
	for layer in [main.towers,main.orbs,main.projectiles,main.zones]:
		var rows := []
		for node in layer.get_children():
			var row := [node.position]
			var keys: Array = ["elements","eff","dealt","src","cd","_shots_n"]if node is Tower else["hp","burn_t","poison_t","root_timer","echo_t","vine","chill"]if node is Orb else["pts","pk","life","t","radius"]if node is Zone else["vel","travel","dmg","t"]
			for key in keys:row.append(node.get(key))
			rows.append(row.duplicate(true))
		data.append(rows)
	return data
