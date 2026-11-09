extends "res://tools/carry_check.gd"
## Observe key dispatch and GUI focus without assigning focus in the fixture.
var trace := []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name()=="headless" or OnlineConfig.SERVER_URL!="" or OnlineConfig.MP_URL!="":
		quit(2);return
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
	await fixture()
	target.position=Vector2(280,300);refused.position=Vector2(950,300)
	main.cards_system._set_cards_hidden(true)
	await settle()
	record("choose-start")
	for i in 16:
		await tap_key(KEY_TAB)
		record("choose-tab-%d"%i)
	await tap_key(KEY_ESCAPE)
	record("choose-escape")
	paused=false
	main.interaction_system.clear_selection()
	main.phase=main.Phase.WAVE;main.wave_active=true
	main.to_spawn=1;main.spawn_timer=1000.0
	await settle()
	record("wave-start")
	for i in 12:
		await tap_key(KEY_TAB)
		record("wave-tab-%d"%i)
	await tap_key(KEY_ESCAPE)
	record("wave-escape")
	FileAccess.open(output.path_join("trace.json"),FileAccess.WRITE).store_string(JSON.stringify(trace,"\t"))
	print("KEYBOARD OBSERVATION rows=%d"%trace.size())
	main.queue_free()
	for i in 4:await process_frame
	quit(0)

func tap_key(code:int,shift:=false,ctrl:=false) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.pressed=true;event.shift_pressed=shift;event.ctrl_pressed=ctrl
	VirtualInput.send(event);await settle()
	event.pressed=false;VirtualInput.send(event);await settle()

func record(label:String) -> void:
	var owner:Control=main.get_viewport().gui_get_focus_owner()
	var row:={"label":label,"focus":str(owner.get_path()) if owner else "","text":str(owner.get("text")) if owner and "text" in owner else "","selection":main.interaction_system.selected.map(func(t):return str(t.position)),"inspector":main.card_dock.side.visible,"preview":main.card_dock.pic.preview_visible,"paused":paused,"phase":main.phase}
	trace.append(row)
	print("KEYBOARD ",JSON.stringify(row))
