extends SceneTree
# 온라인 패치 rules 키(Rules.TUNE·STAT·dmg_/spd_/range_<공격방식>·rxd_<반응>)가 실제로 먹는지 점검.
# 사용: godot --headless --path . -s tools/patch_keys_check.gd   (마지막 줄 PATCHCHECK ok/FAIL)
var main
var fails := 0


func _ok(name: String, cond: bool) -> void:
	print("%s %s" % ["ok  " if cond else "FAIL", name])
	if not cond:
		fails += 1


func _tower(p: String, els: Dictionary, ms: Dictionary) -> Tower:
	var t: Tower = Tower.new()
	t.main = main
	main.towers.add_child(t)
	for e in els:
		t.elements[e] = els[e]
		t.order.append(e)
	t.pattern = p
	t.mods = ms.duplicate()
	return t


func _snap() -> Dictionary:
	var t := _tower("shot", {Elem.FIRE: 2}, {"rapid": 2, "split": 2})
	var g := _tower("gust", {Elem.FIRE: 1}, {})
	var out := {"iv": t.attack_iv(), "range": Tower.shot_range(2, 0.0), "f": t.dmg_factor(false), "gust_iv": g.attack_iv(),
		"split": t.split_ch(), "pw": Tower.pw(3), "desc": Pat.mdesc("rapid"), "rider": Elem.rider(Elem.LIGHT)}
	t.free()
	g.free()
	return out


func _initialize():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	Meta.rules = 1
	Patch.data = {}
	Rules.apply(1)
	var a := _snap()
	Patch.data = {"rules": {"all": {"spd_shot": 2.0, "range_shot": 1.5, "dmg_shot": 3.0, "rapid_k": 0.5, "split_ch": 0.2, "lv_dmg": 1.0, "light_ch": 0.2}, "3": {"spd_shot": 9.0}}}
	Rules.apply(1)
	var b := _snap()
	_ok("spd_shot 2 → 간격 (속사 1.2/2.0 포함)", is_equal_approx(a["iv"] / b["iv"], 2.0 * 2.0 / 1.2))
	_ok("spd_shot은 다른 공격방식에 안 먹음", is_equal_approx(a["gust_iv"], b["gust_iv"]))
	_ok("range_shot 1.5", is_equal_approx(b["range"], a["range"] * 1.5))
	_ok("dmg_shot 3", is_equal_approx(b["f"], a["f"] * 3.0))
	_ok("split_ch 0.2", is_equal_approx(b["split"], 0.4))
	_ok("lv_dmg 1.0", is_equal_approx(b["pw"], 3.0))
	_ok("설명 글: 속사 +50%", "+50%" in b["desc"])
	_ok("설명 글: 치명타 +20%", "+20%" in b["rider"])
	Rules.apply(3)
	_ok("규칙별 덮어쓰기 rules.3", is_equal_approx(Rules.t("spd_shot"), 9.0))
	for k in Rules.DEFAULTS:
		if Rules.DEFAULTS[k] is float or Rules.DEFAULTS[k] is int:
			continue
		_ok("기본값 숫자 " + k, false)
	Patch.data = {}
	Rules.apply(1)
	_ok("패치 없으면 원래대로", is_equal_approx(Rules.t("spd_shot"), 1.0) and is_equal_approx(Tower.pw(3), 2.0))
	print("PATCHCHECK %s keys=%d" % ["ok" if fails == 0 else "FAIL", Rules.DEFAULTS.size()])
	quit()
