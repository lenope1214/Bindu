extends "res://tools/battlefield_input_check.gd"
## Real GUI key dispatch only: never grab_focus or emit button signals from this test.
var focus_trace := []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name()=="headless" or OnlineConfig.SERVER_URL!="" or OnlineConfig.MP_URL!="":
		quit(2);return
	create_timer(120).timeout.connect(func():quit(2))
	var args:=OS.get_cmdline_user_args()
	output=args[0];phone=args[2]=="phone"
	Tutorial.loaded=true;Tutorial.done=true;Tutorial.play_done=true
	Meta.games=5;Meta.guide_on=false;Meta.sim_phone=phone
	Meta.sim_safe=Rect2(86,0,86,38) if phone else Rect2()
	main=load("res://main.tscn").instantiate()
	VirtualInput.mount(main,root)
	await process_frame
	main.progression_system._hide_title();main.set_process(false);main.auto_start=false
	Meta.ui_scale=float(args[1]);main.hud_system._apply_ui_scale()
	await read_cards()
	await read_object()
	await reading_guards()
	FileAccess.open(output.path_join("focus-trace.json"),FileAccess.WRITE).store_string(JSON.stringify(focus_trace,"\t"))
	main.queue_free()
	for i in 4:await process_frame
	print("BATTLEFIELD KEYBOARD failures=%d ui=%d"%[fails,ui_errors])
	quit(1 if fails else 0)

func owner() -> Control:
	return main.get_viewport().gui_get_focus_owner()

func input_key(code:int,ctrl:=false,shift:=false) -> void:
	await super.input_key(code,ctrl,shift)
	remember("key:%s ctrl:%s shift:%s"%[OS.get_keycode_string(code),ctrl,shift])

func remember(label:String) -> void:
	var focused:=owner()
	focus_trace.append({"step":label,"focus":str(focused.get_path()) if focused else "","text":str(focused.get("text")) if focused and "text" in focused else "","scroll":main.card_dock.scroll.scroll_vertical,"selection":main.interaction_system.selected.map(func(t):return str(t.position)),"paused":paused,"phase":main.phase,"picks":main.picks_left,"preview":main.card_dock.pic.preview_visible,"reading_card":main.card_dock.reading_card})

func focus_by_tab(control:Control,backward:=false) -> bool:
	for i in 16:
		remember("tab-backward" if backward else "tab-forward")
		if owner()==control:return true
		await input_key(KEY_TAB,false,backward)
	return false

func read_cards() -> void:
	await reset_input_case()
	main.card_dock.close_inspector(true)
	await settle()
	var dock:CardDock=main.card_dock
	var offer:Array=main.offer.duplicate(true)
	var initial_picks:int=main.picks_left
	await input_key(KEY_F6)
	ok("KEY-2",owner()!=null and dock.side.is_ancestor_of(owner()) and not dock.reading_card.is_empty(),"F6 enters card reading without pointer input")
	if owner()==null:return
	var original:Dictionary=dock.reading_card.duplicate(true)
	ok("KEY-2",await focus_by_tab(dock.read_next),"next-card button reachable by Tab")
	await input_key(KEY_ENTER)
	ok("KEY-2",dock.reading_card!=original and main.offer==offer and main.picks_left==initial_picks,"Enter reads next card without consuming a choice")
	ok("KEY-2",await focus_by_tab(dock.read_prev,true),"previous-card button reachable by Shift+Tab")
	await input_key(KEY_SPACE)
	ok("KEY-2",dock.reading_card==original and main.picks_left==initial_picks,"Space reads previous card without playing it")
	ok("KEY-2",await focus_by_tab(dock.use_btn),"use-card action reachable by Tab")
	await input_key(KEY_ENTER)
	ok("KEY-2",main.phase==main.Phase.PLACE and owner()==null and main.picks_left==initial_picks,"use card hands Enter back to field without consuming early")
	await input_key(KEY_ESCAPE)
	ok("KEY-2",main.phase==main.Phase.CHOOSE and main.offer==offer and main.picks_left==initial_picks,"Esc returns unchanged offers")
	await input_key(KEY_F6)
	ok("KEY-2",await focus_by_tab(dock.close_btn),"card inspector close button reachable")
	await input_key(KEY_ENTER)
	ok("KEY-2",not dock.side.visible and owner()==null and main.picks_left==initial_picks,"keyboard close releases hidden focus")

func read_object() -> void:
	await reset_input_case()
	main.cards_system._set_cards_hidden(true)
	for element in Elem.ALL:
		target.elements[element]=3
		if not element in target.order:target.order.append(element)
	target.eff=target.eff_now()
	main.phase=main.Phase.WAVE;main.wave_active=true;main.to_spawn=1;main.spawn_timer=1000.0
	main.tip_detail=true
	await settle()
	await input_key(KEY_TAB)
	var dock:CardDock=main.card_dock
	var camera:Transform2D=main.get_canvas_transform()
	var positions:=[target.position,refused.position]
	var picks:int=main.picks_left
	ok("KEY-2",main.interaction_system.selected==[target],"field Tab still selects a tower")
	await input_key(KEY_F6)
	ok("KEY-2",owner()!=null and dock.side.is_ancestor_of(owner()),"F6 enters selected-object inspector")
	if owner()==null:return
	var reached:Array=[]
	for i in 16:
		if owner()!=null and not owner() in reached:reached.append(owner())
		await input_key(KEY_TAB)
		remember("object-tab")
	ok("KEY-2",dock.preview_btn in reached and dock.scroll in reached and dock.side.pin_btn in reached and dock.side.fold_btn in reached and dock.close_btn in reached,"Tab reaches preview, reading area, pin, fold and close")
	ok("KEY-2",main.interaction_system.selected==[target] and positions==[target.position,refused.position],"reading navigation never cycles or moves field targets")
	ok("KEY-2",await focus_by_tab(dock.scroll),"reading area reached")
	await input_key(KEY_END)
	var bottom:int=dock.scroll.scroll_vertical
	ok("KEY-2",bottom>0,"End scrolls actual overflowing content")
	await input_key(KEY_HOME)
	ok("KEY-2",dock.scroll.scroll_vertical==0,"Home returns to primary metrics")
	await input_key(KEY_DOWN)
	ok("KEY-2",dock.scroll.scroll_vertical>0,"Down scrolls rather than moving the selected tower")
	await input_key(KEY_PAGEDOWN)
	await input_key(KEY_PAGEUP)
	await input_key(KEY_HOME)
	await snap("reading-focus")
	ok("KEY-2",await focus_by_tab(dock.preview_btn),"preview action reached")
	await input_key(KEY_ENTER)
	ok("KEY-2",dock.pic.preview_visible and dock.scroll.get_global_rect().grow(.1).encloses(dock.pic.attack_preview.get_global_rect()),"Enter reveals entire attack example")
	await snap("preview-focus")
	await input_key(KEY_SPACE)
	ok("KEY-2",not dock.pic.preview_visible and dock.scroll.scroll_vertical==0,"Space collapses example and returns to metrics")
	ok("KEY-2",await focus_by_tab(dock.side.fold_btn),"fold action reached")
	await input_key(KEY_ENTER)
	ok("KEY-2",dock.side.folded and owner()==dock.side.fold_btn,"fold keeps visible header focus")
	var hidden_reached:=false
	for i in 8:
		await input_key(KEY_TAB)
		hidden_reached=hidden_reached or owner()==dock.scroll or owner()==dock.preview_btn
	ok("KEY-2",not hidden_reached,"folded content is excluded from focus traversal")
	await focus_by_tab(dock.side.fold_btn)
	await input_key(KEY_ENTER)
	ok("KEY-2",not dock.side.folded,"keyboard unfolds inspector")
	await focus_by_tab(dock.preview_btn)
	await input_key(KEY_ESCAPE)
	ok("KEY-2",paused,"wave Esc immediately pauses while inspector button focused")
	await input_key(KEY_P)
	ok("KEY-2",not paused,"P resumes after reading pause")
	if owner()==null:await input_key(KEY_F6)
	await input_key(KEY_F6)
	ok("KEY-2",owner()==null,"F6 returns focus to field")
	await input_key(KEY_TAB)
	ok("KEY-2",main.interaction_system.selected==[refused],"field Tab resumes target cycling after leaving inspector")
	ok("KEY-2",positions==[target.position,refused.position] and main.picks_left==picks and main.get_canvas_transform().is_equal_approx(camera),"reading preserves positions, cards and camera")
	# Native GUI action dispatch after this path still works for explicit movement/editing.
	main.phase=main.Phase.READY;main.wave_active=false;main.countdown=-1.0
	await settle()
	var before:Vector2=refused.position
	await input_key(KEY_LEFT)
	ok("KEY-2",refused.position.x<before.x,"field arrows work after inspector focus exits")
	await input_key(KEY_E)
	await input_key(KEY_UP)
	await input_key(KEY_ENTER)
	print("KEYBOARD FINAL EDIT phase=",main.phase," direction=",refused.dir," pointer=",main.interaction_system.pointer_position," target=",refused.position)
	ok("KEY-2",main.phase==main.Phase.READY and refused.dir.dot(Vector2.UP)>.99,"field direction editing still completes by keyboard")

func reading_guards() -> void:
	await reset_input_case()
	main.card_dock.close_inspector(true)
	var original:Array=main.offer.duplicate(true)
	for modal:Control in [main.settings_panel,main.help_label,main.notes_panel,main.codex_panel,main.vote_panel,main.records_panel,main.modes_panel,main.menu_system.sound_pop]:
		modal.show()
		await input_key(KEY_F6)
		ok("KEY-2",not main.card_dock.side.visible and main.offer==original and main.picks_left==2,"reading modal retains input ownership: "+str(modal.name))
		modal.hide()
	main.perk_mode=true
	await input_key(KEY_F6)
	ok("KEY-2",not main.card_dock.side.visible and main.card_dock.reading_card.is_empty(),"perk selection does not expose a stale normal offer")
	main.perk_mode=false
	paused=true
	await input_key(KEY_F6)
	ok("KEY-2",not main.card_dock.side.visible and main.picks_left==2,"pause blocks entering hidden card reading")
	paused=false
