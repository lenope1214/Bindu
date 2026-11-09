extends "res://tools/battlefield_feedback_check.gd"
## run_profile.py 사본 전용. 실제 primitive와 callback을 세어 같은 전장을 비교한다.
func _after_dense_snapshot() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var mode: int = main.process_mode
	main.process_mode=Node.PROCESS_MODE_DISABLED
	main.sfx.muted=true
	Meta.fx_dps=0
	for tower in main.towers.get_children():tower.fx_a=1.0
	var viewport: RID = main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var state := combat_state()
	var camera: Transform2D = main.get_canvas_transform()
	var results := []
	var sequences := [[],[]]
	for reduced in [false,true]:
		Meta.fx_low=reduced
		main.field_view_system._soften_fx()
		for warm in 3:await draw_scene()
		var draws: Dictionary
		var primitives: Dictionary
		var render_cpu := []
		for repeat in 5:
			Zone.qa_primitives.clear()
			Zone.qa_draws.clear()
			seed(9222)
			await draw_scene()
			sequences[1 if reduced else 0].append(randi())
			draws=Zone.qa_draws.duplicate(true)
			primitives=Zone.qa_primitives.duplicate(true)
			render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			verify(draws.get("field_view/_draw_fx",{}).get("calls")==1,"one actual FX draw callback")
			verify(draws.get("orb/_draw",{}).get("calls")==main.orbs.get_child_count(),"all orb draw callbacks executed")
		main.get_viewport().get_texture().get_image().save_png(output.path_join("reduced.png"if reduced else"full.png"))
		verify(state==combat_state(),"quality toggle/redraw preserves combat snapshot")
		verify(camera==main.get_canvas_transform(),"quality toggle preserves camera")
		results.append({"reduced":reduced,"primitives":primitives,"inclusive_draw_us":draws,"render_cpu_ms":render_cpu})
	verify(sequences[0]==sequences[1],"quality toggle keeps subsequent global RNG sequence")
	print("FX PROFILE RESULTS ",JSON.stringify(results))
	FileAccess.open(output.path_join("fx-profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"results":results,"next_rng":sequences},"\t"))
	Meta.fx_low=false
	main.process_mode=mode

func draw_scene() -> void:
	main.queue_redraw()
	for layer in [main.towers,main.orbs,main.projectiles,main.zones]:
		for node in layer.get_children():node.queue_redraw()
	main.fx_layer.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()

func combat_state() -> Array:
	var data := [main.sim_id,main.core_hp,main.score,main.run_game,main.wave_time,main.popups.duplicate(true)]
	for layer in [main.towers,main.orbs,main.projectiles,main.zones]:
		var rows := []
		for node in layer.get_children():
			var row := [node.position]
			var keys: Array = ["elements","eff","dealt","src","cd","_shots_n"]if node is Tower else["hp","burn_t","poison_t","root_timer","echo_t","vine","chill"]if node is Orb else["pts","pk","life","t","radius"]if node is Zone else["vel","travel","dmg","t"]
			for key in keys:row.append(node.get(key))
			rows.append(row.duplicate(true))
		data.append(rows)
	return data
