extends SceneTree
func _initialize() -> void:
	assert(str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"))
	assert(OnlineConfig.SERVER_URL=="" and OnlineConfig.MP_URL=="")
	assert(not OS.has_feature("mobile"))
	var rows := [{"case":"initial","value":Meta.ui_scale}]
	assert(Meta.ui_scale==1.0)
	Meta.load_into(ConfigFile.new())
	rows.append({"case":"missing","value":Meta.ui_scale});assert(Meta.ui_scale==1.0)
	for scale in Meta.UI_SCALES:
		var cfg := ConfigFile.new();cfg.set_value("settings","ui_scale",scale)
		Meta.load_into(cfg);rows.append({"case":"saved","value":Meta.ui_scale,"expected":scale});assert(Meta.ui_scale==scale)
	var invalid := ConfigFile.new();invalid.set_value("settings","ui_scale",.93)
	Meta.load_into(invalid);rows.append({"case":"invalid","value":Meta.ui_scale});assert(Meta.ui_scale==1.0)
	var file := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	file.store_string(JSON.stringify({"os":OS.get_name(),"mobile":OS.has_feature("mobile"),"rows":rows}));file.close()
	print("DESKTOP DEFAULT assertions=8 failures=0")
	quit(0)
