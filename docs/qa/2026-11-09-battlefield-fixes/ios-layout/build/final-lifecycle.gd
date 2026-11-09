extends Node
## 격리 iOS QA 앱의 제어·관찰. 플랫폼 알림은 주입하지 않고 UIKit→Godot 경로를 관찰한다.
class NativeLog:
	extends Logger
	var rows := []
	var lock := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		lock.lock()
		rows.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale,"type":error_type})
		lock.unlock()
	func snapshot() -> Array:
		lock.lock()
		var copy := rows.duplicate(true)
		lock.unlock()
		return copy

var native_log := NativeLog.new()
var main
var notifications := []
var input_events := []
var restoration_events := []
var last_command := ""
var stage := "startup"
var heartbeat := 0.0
var preparing := false
var target
const COMMAND := "user://ios-qa-command.json"
const STATUS := "user://ios-qa-status.json"

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	OS.add_logger(native_log)
	push_warning("BinduIOSQA logger probe")
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL!="" or OnlineConfig.MP_URL!="":
		get_tree().quit(2)
		return
	call_deferred("attach")

func attach() -> void:
	main=get_tree().current_scene
	if main==null:
		await get_tree().process_frame
		main=get_tree().current_scene
	main.sfx.muted=true
	# 제품의 이어하기 callback 다음에 관찰한다. 연속 진행의 1초 READY를 놓치지 않는다.
	main.continue_btn.pressed.connect(func():
		restoration_events.append({"at_ms":Time.get_ticks_msec(),"phase_name":main.Phase.keys()[main.phase],"wave":main.wave,"picks":main.picks_left,"tower_count":main.towers.get_child_count(),"offer":main.offer.duplicate(true),"bank_picks":main.bank_picks.duplicate(),"skip_left":main.skip_left})
		write_status())
	write_status()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_RESUMED]:
		notifications.append({"what":what,"at_ms":Time.get_ticks_msec()})
		if is_instance_valid(main):write_status()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		input_events.append({"at_ms":Time.get_ticks_msec(),"pressed":event.pressed,"index":event.index,"position":[event.position.x,event.position.y],"qa_fixture":event.device==777})

func _process(delta: float) -> void:
	if not is_instance_valid(main) or preparing:return
	if FileAccess.file_exists(COMMAND):
		var command: Variant=JSON.parse_string(FileAccess.get_file_as_string(COMMAND))
		if command is Dictionary and str(command.get("id",""))!="" and str(command.id)!=last_command:
			last_command=str(command.id)
			DirAccess.remove_absolute(COMMAND)
			match str(command.get("op","")):
				"prepare":
					preparing=true
					await prepare_case(str(command.stage))
					preparing=false
				"snapshot":pass
			write_status()
	heartbeat+=delta
	if heartbeat>0.25:
		heartbeat=0.0
		write_status()

func prepare_case(next_stage: String) -> void:
	stage=next_stage
	get_tree().paused=false
	main.set_process(false)
	main.tut.hide()
	Tutorial.loaded=true;Tutorial.done=true;Tutorial.play_done=true
	Tutorial.save_file()
	Meta.games=5;Meta.guide_on=false
	Meta.skill_auto=false
	main.progression_system._save_best()
	main.progression_system._hide_title()
	main.auto_start=false
	main.interaction_system._drop_press()
	main.interaction_system.moving=null
	main.interaction_system.selected.clear()
	main.card_dock.clear_gesture()
	main.card_dock.close_inspector()
	main.cards_system.clear_edit_history()
	for layer in [main.towers,main.orbs,main.projectiles,main.zones]:
		for node in layer.get_children():node.free()
	main.live_orbs=[]
	main.popups=[];main.particles=[];main.beams=[];main.bolts=[];main.pulses=[];main.arcs=[]
	main.ley=[]
	Modes.set_on([]);Meta.rules=1;Meta.map_id="plain"
	main.run_flow_system._apply_rules()
	Rules.tune["map_on"]=0.0
	Rules.tune["auto_aim"]=1.0
	Tower.dmg_mul=1.0;Tower.spd_mul=1.0;Tower.reach_mul=1.0;Tower.tax_step=Rules.tax_step
	main.perks={};main.perk_mode=false;main.coin_stage=0;main.coin_next=""
	main.regen_acc=0.0;main.shield=0;main.shield_keep=0;main.rampart_left=0;main.riposte_cd=0.0
	main.orb_speed_mul=1.0;main.tutor=false;main.wave=4;main.score=0;main.combo=0;main.combo_t=0.0
	main.core_max=main.CORE_MAX_HP;main.core_hp=main.CORE_MAX_HP
	main.bank_picks=[];main.bank_perks=0;main.bank_rerolls=0;main.skip_left=0;main.skip_total=0;main.skip_stop=false
	main.wave_active=false;main.to_spawn=0;main.skill_arm="";main.countdown=-1.0
	main.lanes.clear();main.waves_system._roll_lanes()
	main.run_id="ios-lifecycle-"+stage
	main.picks_left=4
	main.phase=main.Phase.CHOOSE
	main.picked={"type":"elem","e":Elem.WATER,"lv":1}
	main.interaction_system._place_tower(Vector2(300,320),Vector2.RIGHT)
	main.picked={"type":"elem","e":Elem.WATER,"lv":1}
	main.interaction_system._place_tower(Vector2(950,320),Vector2.LEFT)
	target=main.towers.get_child(0)
	main.picks_left=2;main.rerolls_left=1
	main.offer=[{"type":"mod","id":"pierce"},{"type":"elem","e":Elem.FIRE,"lv":1},{"type":"elem","e":Elem.WOOD,"lv":1}]
	main.cards_system._show_offer();main.cards_system._open_choose()
	main.viewport_system._reset_zoom()
	main.banner_t=0.0;main.banner_queue.clear();main.toast_timer=0.0
	main.persistence_system._save_run()
	match stage:
		"place":main.cards_system._on_pick(main.offer[0])
		"aim":
			main.cards_system._on_pick(main.offer[1]);Rules.tune["auto_aim"]=0.0
			main.interaction_system._place_card_at(Vector2(600,400))
		"ready","wave","skill":
			main.picks_left=0
			main.cards_system._enter_ready()
			if stage in ["wave","skill"]:
				main.lanes.clear();main.run_flow_system._start_wave();main.to_spawn=1;main.spawn_timer=1000.0
				if stage=="skill":main.skill_arm="hold"
		"continuous":
			main.run_flow_system._on_skip()
			# 넘기기는 READY→1초 대기를 만든다. 실제 시작 경로 뒤 전투 상태를 고정한다.
			main.cards_system._start_wave_from_ready()
			main.to_spawn=1;main.spawn_timer=1000.0
	main.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	write_status()

func saved_state() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(main.RUN_PATH)!=OK:return {}
	var result := {}
	for field in ["state","wave","picks_left","offer","towers","run_id","skip_left","bank_picks","bank_rerolls","bank_perks"]:
		result[field]=cfg.get_value("run",field,null)
	result["sha256"]=FileAccess.get_sha256(main.RUN_PATH)
	return result

func button_center(button: Control) -> Array:
	var at: Vector2=button.get_global_rect().get_center()/main.get_viewport_rect().size
	return [at.x,at.y]

func write_status() -> void:
	var towers := []
	for node in main.towers.get_children():towers.append({"pos":[node.position.x,node.position.y],"elements":node.elements,"mods":node.mods})
	var report := {"os":OS.get_name(),"mobile":OS.has_feature("mobile"),"ios":OS.has_feature("ios"),"template":OS.has_feature("template"),"debug_build":OS.has_feature("debug"),"editor":Engine.is_editor_hint(),"pid":OS.get_process_id(),"user_dir":OS.get_user_data_dir(),"viewport":str(main.get_viewport_rect()),"stage":stage,"command":last_command,"phase":main.phase,"wave":main.wave,"paused":get_tree().paused,"pause_setting":Meta.pause_on_focus_loss,"title_visible":main.title_label.visible,"pause_ui_visible":main.pause_box.visible,"continue_visible":main.continue_btn.visible,"touches_empty":main.interaction_system.touches.is_empty(),"pinch_lock":main.interaction_system.pinch_lock,"press_empty":main.interaction_system.press_t==null,"pending_card_empty":main.card_dock.pending_card.is_empty(),"picks":main.picks_left,"towers":towers,"skill_arm":main.skill_arm,"save_text":main.persistence_system.save_status_text(),"saved":saved_state(),"notifications":notifications,"input_events":input_events,"mouse_buttons":Input.get_mouse_button_mask(),"mouse_emulation":Input.emulate_mouse_from_touch,"resume_can_process":main.pause_box.get_child(0).can_process(),"resume_at":button_center(main.pause_box.get_child(0)),"continue_at":button_center(main.continue_btn)}
	report["runtime_log"]=native_log.snapshot()
	report["restoration_events"]=restoration_events
	report["skill_cd"]=main.skill_cd
	report["skill_used"]=main.skill_used
	report["offer"]=main.offer
	report["bank_picks"]=main.bank_picks
	report["skip_left"]=main.skip_left
	report["phase_name"]=main.Phase.keys()[main.phase]
	var file := FileAccess.open(STATUS+".tmp",FileAccess.WRITE)
	file.store_string(JSON.stringify(report));file.close()
	DirAccess.rename_absolute(STATUS+".tmp",STATUS)
