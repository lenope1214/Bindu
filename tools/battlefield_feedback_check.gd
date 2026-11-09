extends "res://tools/battlefield_load_check.gd"
## Native read-only popup selection, renderer captures and pointer routing.
var checks := 0
var before_variant := false

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name() == "headless" or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	create_timer(240).timeout.connect(func():quit(2))
	var args := OS.get_cmdline_user_args()
	output = args[0]
	phone = args.size()>2 and args[2]=="phone"
	touch_profile = phone
	before_variant = args.size()>3 and args[3]=="before"
	DirAccess.make_dir_recursive_absolute(output)
	Tutorial.loaded = true
	Tutorial.done = true
	Tutorial.play_done = true
	Meta.games = 10
	Meta.guide_on = false
	Meta.sim_phone = phone
	Meta.sim_safe = Rect2(86,0,86,38) if phone else Rect2()
	Meta.skill_auto = false
	Meta.skill_aim_slow = false
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main,root)
	await process_frame
	main.progression_system._hide_title()
	main.set_process(false)
	main.auto_start = false
	Meta.ui_scale = float(args[1])
	main.touch_ui = phone
	main.hud_system._apply_ui_scale()
	orb_goal = 400
	await load_fixture()
	if not before_variant:
		geometry_cases()
	await load_fixture()
	main.game_speed = 8.0
	Meta.fx_low = false
	var target_counts: Array = []
	for i in 60:
		await process_frame
		main.frame_system._process(1.0/60.0)
		fill_orbs()
		target_counts.append(main.combat_system.targets.size())
		RenderingServer.force_draw()
	await snap("dense")
	await _after_dense_snapshot()
	var original: Array = main.popups.duplicate(true)
	var selected := display_rows()
	verify(original==main.popups,"dense input popup values preserved")
	var overlap_before := overlap_pairs(main.popups)
	var overlap_after := overlap_pairs(selected)
	if not before_variant:
		verify(overlap_after==0,"dense equal-style status labels do not overlap")
		verify(selected.size()<main.popups.size(),"dense repeated status count reduced")
	var record := {"before_variant":before_variant,"phone":phone,"ui_scale":Meta.ui_scale,"checks":checks,"failures":fails,"ui_errors":ui_errors,"tower_count":main.towers.get_child_count(),"orb_goal":orb_goal,"live_orbs":main.live_orbs.size(),"mean_target_orbs":mean(target_counts),"raw_popup_count":main.popups.size(),"draw_popup_count":selected.size(),"same_status_overlap_pairs_before":overlap_before,"same_status_overlap_pairs_after":overlap_after,"field_view_sha256":FileAccess.get_sha256("res://scripts/features/field_view.gd"),"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"camera":str(main.get_canvas_transform()),"raw_popups":main.popups,"draw_popups":selected}
	await pointer_probe()
	record.checks = checks
	record.failures = fails
	record.ui_errors = ui_errors
	record.tool_sha256 = FileAccess.get_sha256("res://tools/battlefield_feedback_check.gd")
	record.runtime_features = {"template":OS.has_feature("template"),"debug_build":OS.is_debug_build(),"editor":OS.has_feature("editor")}
	FileAccess.open(output.path_join("feedback.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	print("FEEDBACK checks=%d failures=%d ui=%d" % [checks,fails,ui_errors])
	quit(1 if fails+ui_errors>0 else 0)

func _after_dense_snapshot() -> void:
	pass

func fill_orbs() -> void:
	var alive: int = main.orbs.get_children().filter(func(o):return is_instance_valid(o) and not o.is_queued_for_deletion() and o.hp>0.0).size()
	var bounds: Rect2 = main.viewport_system.arena().grow(-60.0)
	var center: Vector2 = main.viewport_system.core()
	for i in maxi(0,orb_goal-alive):
		var index := orb_serial % orb_goal
		orb_serial += 1
		var at := bounds.position+Vector2(bounds.size.x*(index%25)/24.0,bounds.size.y*floori(index/25.0)/15.0)
		if at.distance_to(center)<180.0:
			var away := (at-center).normalized()
			if away==Vector2.ZERO:away=Vector2.UP
			at=(center+away*180.0).clamp(bounds.position,bounds.end)
		_orb(at,10000000.0,Orb.Kind.FAST if index%5==0 else Orb.Kind.NORMAL,8.0)

func verify(value: bool,message: String) -> void:
	checks += 1
	ok("UI-50",value,message)

func display_rows() -> Array:
	return main.popups if before_variant else main.field_view_system.call("_popup_draw_rows")

func popup(at: Vector2,text: String,big := true,color := Color.GOLD) -> Array:
	return [at,text,0.7,color,big]

func geometry_cases() -> void:
	var first := Vector2(400,300)
	var last := Vector2(401,301)
	var examples := [
		["empty",[],0],
		["single",[popup(first,"되풀이")],1],
		["latest",[popup(first,"되풀이"),popup(last,"되풀이")],1],
		["separate",[popup(first,"되풀이"),popup(Vector2(800,300),"되풀이")],2],
		["different-message",[popup(first,"되풀이"),popup(first,"최다 피해 25%")],2],
		["different-color",[popup(first,"되풀이"),popup(first,"되풀이",true,Color.RED)],2],
		["different-size",[popup(first,"되풀이"),popup(first,"되풀이",false)],2],
		["numbers",[popup(first,"123"),popup(first,"123")],2],
		["negative-numbers",[popup(first,"-9"),popup(first,"-9")],2],
		["mixed",[popup(first,"되풀이"),popup(first,"123"),popup(last,"되풀이"),popup(first,"99")],3],
	]
	var original: Array = main.popups
	var fx_transform: Transform2D = main.fx_layer.transform
	var camera: Transform2D = main.get_canvas_transform()
	var state := [main.core_hp,main.score,main.run_game,main.wave_time,main.towers.get_child_count(),main.orbs.get_child_count()]
	for zoom in [0.65,1.0,1.6]:
		var transform := Transform2D.IDENTITY.scaled(Vector2(zoom,zoom))
		transform.origin = Vector2(23,-17)
		main.fx_layer.transform = transform
		for example in examples:
			main.popups = example[1].duplicate(true)
			var copied: Array = main.popups.duplicate(true)
			seed(4404)
			var expected_rng := randi()
			seed(4404)
			var selected := display_rows()
			var next_rng := randi()
			verify(selected.size()==example[2],"%s zoom%s count" % [example[0],zoom])
			verify(main.popups==copied and next_rng==expected_rng,"%s data/RNG read-only" % example[0])
			if example[0]=="latest":verify(selected[0][0]==last,"newest overlapping status retained")
			if example[0] in ["latest","separate"]:verify(overlap_pairs(selected)==0,"selected status rectangles separated")
		var random := RandomNumberGenerator.new()
		random.seed = 8833
		for sample in 24:
			var rows := []
			for i in 36:
				var text: String = ["되풀이","최다 피해 25%","긴 상태 문구의 화면 칸 경계 검사","123","-9"][random.randi_range(0,4)]
				var at := Vector2(random.randf_range(-800,1600),random.randf_range(-300,900))
				rows.append(popup(at,text,random.randi_range(0,1)==1,Color.GOLD if i%3 else Color.RED))
			main.popups = rows
			var expected := []
			for i in range(rows.size()-1,-1,-1):
				var overlaps := false
				for prior in expected:
					if overlap_pairs([rows[i],prior])>0:
						overlaps = true
						break
				if not overlaps:expected.append(rows[i])
			expected.reverse()
			var copied: Array = rows.duplicate(true)
			seed(4404)
			var expected_rng := randi()
			seed(4404)
			var selected := display_rows()
			verify(selected==expected,"grid selection matches full scan %s/%s" % [zoom,sample])
			verify(main.popups==copied and randi()==expected_rng,"grid selection preserves data/RNG")
	main.fx_layer.transform = fx_transform
	main.popups = original
	verify(main.get_canvas_transform()==camera,"camera unchanged by status selection")
	verify(state==[main.core_hp,main.score,main.run_game,main.wave_time,main.towers.get_child_count(),main.orbs.get_child_count()],"combat state unchanged by status selection")

func overlap_pairs(rows: Array) -> int:
	var pairs := 0
	var canvas: Transform2D = main.fx_layer.get_global_transform_with_canvas()
	for i in rows.size():
		var a: Array = rows[i]
		if a[1].is_valid_int():continue
		var size := 22 if a[4] else 14
		var span: Vector2 = main.ui_font.get_string_size(a[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size)
		var rect: Rect2 = (canvas * Rect2(a[0]-Vector2(0,main.ui_font.get_ascent(size)),Vector2(span.x,main.ui_font.get_height(size)))).grow(2.0)
		for j in range(i+1,rows.size()):
			var b: Array = rows[j]
			if b[1]!=a[1] or b[3]!=a[3] or b[4]!=a[4]:continue
			var other: Rect2 = (canvas * Rect2(b[0]-Vector2(0,main.ui_font.get_ascent(size)),Vector2(span.x,main.ui_font.get_height(size)))).grow(2.0)
			if rect.intersects(other):pairs += 1
	return pairs

func pointer_probe() -> void:
	_fresh(39)
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.countdown = -1.0
	main.to_spawn = 1
	main.spawn_timer = INF
	var orb := _orb(main.viewport_system.center()+Vector2(-180,0),100.0)
	main.popups = [popup(orb.position+Vector2(-10,10),"되풀이"),popup(orb.position+Vector2(-9,11),"되풀이")]
	await mouse_click(world(orb.position))
	verify(main.field_view_system.pinned_orb()==orb,"pointer passes through status text to same orb")
	await key(KEY_P)
	verify(paused and main.pause_box.is_visible_in_tree(),"pause input remains available")
	await key(KEY_P)
	verify(not paused,"resume remains available")
