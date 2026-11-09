extends SceneTree
## Differential source/alias contract and alternating function CPU measurements.
class OtherTower extends RefCounted:
	var eff := {}
	var elements := {}

var service=load("res://scripts/share.gd")
var checks:=0
var failures:=0
var rows:=[]
const METHODS:=["_els","qa_local_els","qa_typed_els"]

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name()!="headless" or OnlineConfig.SERVER_URL!="" or OnlineConfig.MP_URL!="":
		quit(2);return
	call_deferred("run")

func verify(condition:bool,label:String) -> void:
	checks+=1
	if not condition:failures+=1;print("FAIL ",label)

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var tower:=Tower.new()
	var other:=OtherTower.new()
	for owner in [tower,other]:
		for effective in [{},{Elem.FIRE:3},{Elem.METAL:0,Elem.EARTH:2}]:
			owner.elements={Elem.WOOD:2,Elem.BLOOD:1}
			owner.eff=effective.duplicate()
			for method in METHODS:
				var selected:Dictionary=service.call(method,owner)
				var expected:Dictionary=owner.elements if owner.eff.is_empty() else owner.eff
				verify(selected==expected,"effective priority / fallback values")
				selected[-100]=71
				verify(expected.get(-100)==71,"returned dictionary retains source alias")
				selected.erase(-100)
			owner.eff.clear()
			for method in METHODS:verify(service.call(method,owner)==owner.elements,"in-place clear selects fallback")
		owner.elements.clear()
		for method in METHODS:verify(service.call(method,owner).is_empty(),"empty fallback")
		owner.elements={Elem.TIME:1}
		owner.eff=owner.elements
		for method in METHODS:
			var selected:Dictionary=service.call(method,owner)
			selected[Elem.ICE]=3
			verify(owner.eff.get(Elem.ICE)==3 and owner.elements.get(Elem.ICE)==3,"effective/base shared alias retained")
			selected.erase(Elem.ICE)
	for entry in [["tower-effective",tower,{Elem.FIRE:3,Elem.ICE:2,Elem.METAL:1}],["tower-fallback",tower,{}],["tower-single",tower,{Elem.WIND:1}],["tower-empty",tower,{}],["other-effective",other,{Elem.FIRE:3,Elem.ICE:2,Elem.METAL:1}],["other-fallback",other,{}]]:
		var owner:Object=entry[1]
		owner.elements={} if entry[0]=="tower-empty" else {Elem.WOOD:2,Elem.BLOOD:1}
		owner.eff=entry[2]
		var times:={}
		for method in METHODS:
			times[method]=[]
			for i in 1000:service.call(method,owner)
		for batch in 9:
			var order:Array=METHODS.duplicate()
			# Rotate the start; reverse alternate batches to balance adjacency/order.
			for i in batch%3:order.push_back(order.pop_front())
			if batch%2==1:order.reverse()
			for method in order:
				var started:=Time.get_ticks_usec()
				for i in 100000:service.call(method,owner)
				times[method].append(float(Time.get_ticks_usec()-started)/100000.0)
		var medians:={}
		for method in METHODS:
			var sorted:Array=times[method].duplicate();sorted.sort();medians[method]=sorted[4]
		rows.append({"case":entry[0],"us_per_call":times,"median_us":medians})
		print("EFFECT READ ",JSON.stringify(rows[-1]))
	tower.free()
	FileAccess.open(args[0].path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":rows},"\t"))
	print("EFFECT READ checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
