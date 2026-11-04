extends SceneTree
## 반응 카드 앞면·상세·후방 자동 조준의 실제 렌더링. 임시 사본(BinduTools*)에서만 실행.
## godot --path <사본> -s tools/reflex_shot.gd -- <출력 폴더> [글자 크기=1.3] [touch] [맵=plain]
var main
var out := "/tmp/bindu-reflex-shots"
var zoom := 1.3
var touch := false
var map_id := "plain"
var bad := 0


func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools"):
		push_error("실제 게임 저장 공간에서는 실행할 수 없습니다. 임시 사본에서 실행하세요.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	if args.size() > 1: zoom = float(args[1])
	touch = args.size() > 2 and args[2] == "touch"
	if args.size() > 3: map_id = args[3]
	DirAccess.make_dir_recursive_absolute(out)
	seed(1)
	main = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	Meta.guide_on = false
	Meta.ui_scale = zoom
	Meta.rules = 1
	Meta.map_id = map_id
	Modes.set_on([])
	main._apply_rules()
	main._hide_title()
	main.guide_label.hide()
	main._apply_ui_scale()
	main.touch_ui = touch
	main.wave = 12
	main.picks_left = 1
	main.picked = {"type": "elem", "e": Elem.WATER, "lv": 1}
	main._place_tower(main.center() + Vector2(-180, 0), Vector2.RIGHT)
	var t: Tower = main.towers.get_child(main.towers.get_child_count() - 1)
	main.offer = [{"type": "mod", "id": "reflex"}, {"type": "mod", "id": "homing"}, {"type": "elem", "e": Elem.WOOD, "lv": 1}]
	main._show_offer()
	main._open_choose()
	await _snap("reflex_card")
	main._on_card_tap(main.offer[0], 0)
	main._set_card_detail(true)
	await _snap("reflex_detail")
	main._on_pick(main.offer[0])
	main._apply_card(t)
	main._enter_ready()
	t.set_pattern("spray")
	var o := Orb.new()
	o.main = main
	o.position = t.position + Vector2.LEFT * 130.0
	o.target = main.center()
	o.setup(Orb.Kind.NORMAL, 1000.0, 0.0)
	main.orbs.add_child(o)
	main.phase = main.Phase.WAVE
	main.wave_active = true
	main.start_btn.hide()
	main.range_all = map_id == "storm"
	main.tap_sel = -1
	main.to_spawn = 0
	main._resolve(0.1)
	if t.dir != Vector2.RIGHT or t.aim.x > -0.99 or o.hp >= 1000.0:
		push_error("후방 자동 조준·명중 검증 실패")
		bad += 1
	main.queue_redraw()
	await _snap("reflex_rear_attack")
	print("REFLEXSHOT fails=%d" % bad)
	quit(1 if bad > 0 else 0)


func _snap(tag: String) -> void:
	for i in 15:
		await process_frame
	var suffix := "_%s%s.png" % [zoom, "_touch" if touch else ""]
	RenderingServer.force_draw()
	var result: int = main.get_viewport().get_texture().get_image().save_png(out.path_join(tag + suffix))
	if result != OK: bad += 1
	bad += preload("res://tools/ui_check.gd").check(main, tag)


func _process(_delta: float) -> bool:
	if is_instance_valid(main) and is_instance_valid(main.tut) and main.tut.visible:
		main.tut.close()
	return false
