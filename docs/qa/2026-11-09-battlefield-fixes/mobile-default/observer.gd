extends "res://qa_ios/lifecycle.gd"
## 격리 앱에서 main의 실제 최초 _load_best 이전/이후를 관찰한다.
var scenario := ""
var initial_scale: float
var initial_save_exists := false
var startup_settled := false

func _ready() -> void:
	assert(str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"))
	assert(OnlineConfig.SERVER_URL=="" and OnlineConfig.MP_URL=="")
	AudioServer.set_bus_mute(0,true)
	initial_scale=Meta.ui_scale
	scenario=OS.get_environment("BINDU_QA_SCALE_CASE")
	assert(scenario=="fresh" or scenario=="missing" or scenario.begins_with("saved:"))
	if FileAccess.file_exists(Meta.SAVE_PATH):DirAccess.remove_absolute(Meta.SAVE_PATH)
	if scenario!="fresh":
		var cfg := ConfigFile.new()
		cfg.set_value("meta","games",7)
		cfg.set_value("settings","volume",0.37)
		if scenario.begins_with("saved:"):cfg.set_value("settings","ui_scale",float(scenario.trim_prefix("saved:")))
		assert(cfg.save(Meta.SAVE_PATH)==OK)
	initial_save_exists=FileAccess.file_exists(Meta.SAVE_PATH)
	super._ready()

func attach() -> void:
	await super.attach()
	for i in 8:await get_tree().process_frame
	startup_settled=true
	write_status()

func write_status() -> void:
	super.write_status()
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(STATUS))
	report["startup"]={"settled":startup_settled,"scenario":scenario,"initial_scale":initial_scale,"initial_save_exists":initial_save_exists,"loaded_scale":Meta.ui_scale,"ui_root_scale":[main.ui_root.scale.x,main.ui_root.scale.y],"games":Meta.games,"volume":Meta.volume,"camera":str(main.get_canvas_transform()),"field":str(Meta.FIELD)}
	var file := FileAccess.open(STATUS+".tmp",FileAccess.WRITE)
	file.store_string(JSON.stringify(report));file.close()
	DirAccess.rename_absolute(STATUS+".tmp",STATUS)
