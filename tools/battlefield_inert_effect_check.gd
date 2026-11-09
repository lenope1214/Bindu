extends "res://tools/spec_check.gd"
## Direct frozen-function differential for eff fallback, extra elements and zero levels.
var output:=""
var rows:=[]
var share_service=load("res://scripts/share.gd")

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name()!="headless" or OnlineConfig.SERVER_URL!="" or OnlineConfig.MP_URL!="":
		quit(2);return
	output=OS.get_cmdline_user_args()[0]
	Tutorial.loaded=true;Tutorial.done=true;Tutorial.play_done=true
	Meta.games=5;Meta.guide_on=false
	main=load("res://main.tscn").instantiate();root.add_child(main)
	await process_frame
	main.progression_system._hide_title();main.set_process(false);main.sfx.muted=true
	var cases:=[
		["fallback",{Elem.FIRE:2},{},{}],
		["effective-hides-base",{Elem.WOOD:3,Elem.ICE:3},{Elem.FIRE:2},{}],
		["effective-modifiers",{Elem.FIRE:2},{Elem.WOOD:3,Elem.ICE:2},{}],
		["extra-modifiers",{Elem.FIRE:2},{Elem.FIRE:2},{Elem.WOOD:3,Elem.ICE:3}],
		["extra-wood",{Elem.ICE:2},{Elem.ICE:2},{Elem.WOOD:3}],
		["zero-level-keys",{Elem.FIRE:2},{Elem.ICE:0,Elem.WOOD:0},{}],
		["above-strength-cap",{Elem.FIRE:2},{Elem.ICE:8,Elem.WOOD:7,Elem.FIRE:3},{}],
		["lower-extra-level",{Elem.ICE:3,Elem.WOOD:2},{},{Elem.ICE:1,Elem.WOOD:1}],
	]
	for entry in cases:
		for strength in [0.0,0.2,1.2]:
			for kind in ["hit","apply"]:
				var before:=observe(entry,strength,kind,true)
				var after:=observe(entry,strength,kind,false)
				ok("BF-49",before==after,"direct %s %s k=%s state/source/nextRNG equality"%[entry[0],kind,strength])
				rows.append({"case":entry[0],"kind":kind,"strength":strength,"reference":before,"candidate":after,"equal":before==after})
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":rows.size(),"failures":fails,"rows":rows},"\t"))
	main.queue_free()
	for i in 4:await process_frame
	print("INERT DIRECT cases=%d failures=%d"%[rows.size(),fails]);quit(1 if fails else 0)

func observe(entry:Array,strength:float,kind:String,reference:bool) -> Array:
	_fresh(12)
	var tower:Tower=load("res://tools/qa_reference_tower.gd").new() if reference else Tower.new()
	tower.main=main;tower.position=Vector2(180,360)
	tower.elements=entry[1].duplicate(true);tower.order.assign(entry[1].keys());tower.eff=entry[2].duplicate(true)
	tower.trigs={"vanguard":1,"finish":2};tower.fire_boost=2.0;tower.fire_key="trig:third"
	main.towers.add_child(tower)
	var orb:=_orb(Vector2(410,360),1000.0)
	orb.shield=40.0;orb.vine=0.2;orb.chill=0.5
	seed(916)
	if kind=="hit":tower.hit(orb,3.5,strength,entry[3],false,false)
	elif reference:share_service.call("qa_reference_apply",tower,orb,strength,"share:test")
	else:Share.apply(tower,orb,strength,"share:test")
	var fields:={}
	for key in ["position","hp","shield","burn_t","burn_dps","poison_t","slow_timer","slow_factor","root_timer","frozen_t","vuln_t","vine","chill","echo_t","echo_amt","bleed_t","confuse_t"]:fields[key]=orb.get(key)
	return [fields,tower.dealt,tower.rx_dealt,tower.src.duplicate(true),randi()]
