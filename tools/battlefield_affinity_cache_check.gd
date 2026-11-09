extends SceneTree
## run_cache.py의 격리 사본 전용: 동결 원본과 캐시 후보의 mutation 경계 비교.
class OtherTower extends RefCounted:
	var elements := {}
	var eff := {}

var service = load("res://scripts/share.gd")
var checks := 0
var failures := 0
var mutant := false
var mutant_detections := 0
var timings := []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or DisplayServer.get_name()!="headless" or OnlineConfig.SERVER_URL!="" or OnlineConfig.MP_URL!="":
		quit(2)
		return
	call_deferred("run")

func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ",label)

func compare(tower: Object, label: String) -> void:
	var before: Array = [tower.eff.duplicate(true),tower.elements.duplicate(true)]
	seed(9118)
	var rng := randi()
	seed(9118)
	var actual: Dictionary = service.aff(tower)
	var after_rng := randi()
	var expected: Dictionary = service.qa_reference_aff(tower)
	if mutant and actual!=expected:
		mutant_detections += 1
	else:
		verify(actual==expected,label+": exact affinity")
	verify(before==[tower.eff,tower.elements] and after_rng==rng,label+": input/RNG preserved")
	actual["qa_alias"] = 554
	if not (mutant and actual!=expected):
		verify(service.qa_reference_aff(tower).get("qa_alias")==554,label+": original shared result alias")
	actual.erase("qa_alias")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	mutant = args.size()>1 and args[1]=="mutant"
	var tower := Tower.new()
	var other := OtherTower.new()
	compare(tower,"empty first lookup")
	for owner in [tower,other]:
		owner.elements={Elem.FIRE:1,Elem.WATER:3}
		owner.eff={}
		compare(owner,"fallback elements")
		owner.elements[Elem.ICE]=2
		compare(owner,"fallback in-place add")
		owner.elements.erase(Elem.FIRE)
		compare(owner,"fallback in-place remove")
		owner.eff={Elem.WOOD:1,Elem.POISON:3}
		compare(owner,"effective replacement")
		owner.eff[Elem.TIME]=1
		compare(owner,"effective in-place add")
		owner.eff.erase(Elem.WOOD)
		compare(owner,"effective in-place remove")
		owner.eff[Elem.TIME]=3
		compare(owner,"same keys level change")
		owner.elements[Elem.BLOOD]=3
		compare(owner,"hidden base mutation")
		owner.eff=owner.elements
		compare(owner,"effective aliases base")
		owner.elements.clear()
		compare(owner,"aliased in-place clear")
		owner.eff={Elem.METAL:0,Elem.EARTH:3}
		compare(owner,"zero level remains a key")
		owner.eff={Elem.EARTH:3,Elem.METAL:0}
		compare(owner,"insertion order reversed")
	service._aff.clear()
	compare(other,"global result cache cleared with same input")
	tower.eff=other.eff.duplicate()
	compare(tower,"same values on another object")
	for a in Elem.ALL:
		for b in Elem.ALL:
			if b<a:continue
			for c in Elem.ALL:
				if c<b:continue
				tower.eff={a:1,b:2,c:3}
				compare(tower,"all up-to-three-element multisets")
	if mutant:
		verify(mutant_detections>0,"snapshot-alias mutant detected")
	else:
		benchmark(tower,other)
	tower.free()
	FileAccess.open(args[0].path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"mutant_detections":mutant_detections,"timings":timings},"\t"))
	print("AFFINITY CACHE checks=%d failures=%d mutants=%d" % [checks,failures,mutant_detections])
	quit(1 if failures else 0)

func benchmark(tower: Tower, other: OtherTower) -> void:
	for entry in [["tower-effective",tower,{Elem.FIRE:3,Elem.ICE:2,Elem.METAL:1}],["tower-fallback",tower,{}],["tower-single",tower,{Elem.WIND:1}],["tower-empty",tower,{}],["other-effective",other,{Elem.FIRE:3,Elem.ICE:2,Elem.METAL:1}],["other-fallback",other,{}],["churn-keys",tower,{Elem.FIRE:3,Elem.ICE:2,Elem.METAL:1}]]:
		var owner: Object = entry[1]
		owner.elements={}if entry[0]=="tower-empty"else{Elem.WOOD:2,Elem.BLOOD:1}
		owner.eff=entry[2]
		for i in 100:
			service.aff(owner)
			service.qa_reference_aff(owner)
		var values := [[],[]]
		var changing := [{Elem.FIRE:3,Elem.ICE:2,Elem.METAL:1},{Elem.WATER:3,Elem.BLOOD:2,Elem.WOOD:1}]
		for batch in 7:
			for which in ([0,1]if batch%2==0 else[1,0]):
				var start := Time.get_ticks_usec()
				for repeat in 20000:
					if entry[0]=="churn-keys":owner.eff=changing[repeat%2]
					if which==0:service.qa_reference_aff(owner)
					else:service.aff(owner)
				values[which].append(float(Time.get_ticks_usec()-start)/20000.0)
		var before: Array = values[0].duplicate()
		var after: Array = values[1].duplicate()
		before.sort()
		after.sort()
		timings.append({"case":entry[0],"reference_us":values[0],"candidate_us":values[1],"reference_median_us":before[3],"candidate_median_us":after[3]})
