extends SceneTree
## Read-time alias/fallback contract plus a symmetric local function benchmark.
var cases := 0
var failures: Array = []
var benchmark: Array = []

func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		quit(2)
		return
	var output := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var tower := Tower.new()
	for count in [0, 1, 3, 17]:
		tower.elements.clear()
		for i in count:
			tower.elements[Elem.ALL[i]] = 1 + i % 3
		tower.eff.clear()
		probe(tower, tower.elements, "fallback-%s" % count)
		tower.eff = tower.elements.duplicate()
		probe(tower, tower.eff if count > 0 else tower.elements, "effective-%s" % count)
		tower.eff = {Elem.FIRE:9}
		probe(tower, tower.eff, "replaced-effective-%s" % count)
		tower.eff[Elem.WATER] = 4
		probe(tower, tower.eff, "mutated-effective-%s" % count)
		tower.eff.clear()
		tower.elements[Elem.TIME] = 7
		probe(tower, tower.elements, "cleared-effective-mutated-fallback-%s" % count)
	for count in [0, 1, 3, 17]:
		for effective in [false, true]:
			tower.elements.clear()
			for i in count: tower.elements[Elem.ALL[i]] = 1 + i % 3
			tower.eff = tower.elements.duplicate() if effective else {}
			measure(tower, "%s/%s" % [count, effective])
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases":cases,"failures":failures,"benchmark":benchmark,"share_sha256":FileAccess.get_sha256("res://scripts/share.gd"),"tool_sha256":FileAccess.get_sha256("res://tools/battlefield_share_els_check.gd"),"engine":Engine.get_version_info()}, "\t"))
	file.close()
	tower.free()
	print("SHARE ELS cases=%s failures=%s" % [cases, failures.size()])
	quit(0 if failures.is_empty() else 1)

func reference(tower: Object) -> Dictionary:
	return tower.eff if not tower.eff.is_empty() else tower.elements

func candidate(tower: Object) -> Dictionary:
	var current: Dictionary = tower.eff
	return current if not current.is_empty() else tower.elements

func probe(tower: Tower, expected: Dictionary, label: String) -> void:
	cases += 1
	seed(991)
	var next := randi()
	seed(991)
	var actual := candidate(tower)
	if actual != expected or actual != reference(tower) or actual != Share._els(tower) or randi() != next:
		failures.append(label + ": value/RNG")
	# A duplicate dictionary could compare equal but would break callers' mutations.
	actual[-900] = cases
	if expected.get(-900) != cases: failures.append(label + ": alias")
	expected.erase(-900)
	if actual.has(-900): failures.append(label + ": reverse-alias")

func measure(tower: Tower, label: String) -> void:
	for i in 5000:
		reference(tower)
		candidate(tower)
	var before := []
	var after := []
	var checksums := [0, 0]
	for batch in 9:
		for which in ([0, 1] if batch % 2 == 0 else [1, 0]):
			var checksum := 0
			var start := Time.get_ticks_usec()
			for i in 20000:
				checksum += (reference(tower) if which == 0 else candidate(tower)).size()
			var elapsed := float(Time.get_ticks_usec() - start) / 20000.0
			(before if which == 0 else after).append(elapsed)
			checksums[which] += checksum
	if checksums[0] != checksums[1]: failures.append(label + ": checksum")
	var a := before.duplicate()
	var b := after.duplicate()
	a.sort()
	b.sort()
	benchmark.append({"condition":label,"reference_us_per_call":before,"candidate_us_per_call":after,"reference_median_us":a[4],"candidate_median_us":b[4],"scope":"symmetric local helper calls; not native frame/FPS"})
