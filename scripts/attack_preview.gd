class_name AttackPreview
extends TextureRect
## 실제 Tower·Projectile·Orb·Share를 사용하는 독립 전장. boot/입력/온라인/저장은 실행하지 않는다.
const HEIGHT := 140.0
var caption: Label
var world: BinduSession
var viewport: SubViewport
var clone: Tower
var signature := ""
var elapsed := 0.0
var source: Tower
var accumulator := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	viewport = SubViewport.new()
	viewport.size = Vector2i(400, 200)
	viewport.world_2d = World2D.new()
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	texture = viewport.get_texture()
	caption = Label.new()
	caption.position = Vector2(6, 4)
	caption.add_theme_font_size_override("font_size", 11)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	world = BinduSession.new()
	world.phase = BinduSession.Phase.WAVE
	world.wave_active = true
	world.ui_font = ThemeDB.fallback_font
	world.sfx = Sfx.new()
	# 음원 합성·음악 초기화 없이 무음 서비스만 소유한다.
	world.sfx.muted = true
	viewport.add_child(world)
	for key in ["zones", "towers", "orbs", "projectiles", "fx_layer"]:
		var layer := Node2D.new()
		world.set(key, layer)
		world.add_child(layer)
	world.fx_layer.draw.connect(func(): world.field_view_system._draw_fx(true))

func _ready() -> void:
	viewport.canvas_transform = Transform2D(0.0, Vector2(0.75, 0.75), 0.0, Vector2(-100, -170))

func _exit_tree() -> void:
	# tree 밖에서 소유한 무음 서비스는 직접 정리한다.
	if is_instance_valid(world.sfx): world.sfx.free()

## 배치·레벨·강화·주변 오브젝트가 바뀔 때만 다시 만든다. 진행 중 카운터는 초기 스냅샷에만 복사한다.
const BUILD_KEYS := ["elements", "order", "pattern", "plv", "mods", "trigs", "pincer", "reso", "position", "dir"]
const STATE_KEYS := ["charge", "third_n", "star_sum", "star_e", "focus_t", "leech_n", "leech_t"]
var copies := {}  # 실제 instance id -> 격리된 사본
var auto_refill := true
var refill_left := 0.0
var cycle := 0

func configure(tower: Tower) -> void:
	source = tower
	var original: BinduSession = tower.main
	world.ui_font = original.ui_font if original != null else ThemeDB.fallback_font
	caption.add_theme_font_override("font", world.ui_font)
	var peers: Array = original.towers.get_children() if original != null else [tower]
	var builds := []
	for peer: Tower in peers:
		var data := {"id": peer.get_instance_id()}
		for key in BUILD_KEYS: data[key] = peer.get(key)
		builds.append(data)
	var context := {"focus": tower.get_instance_id(), "builds": builds,
		"perks": original.perks if original != null else {}, "ley": original.ley if original != null else [],
		"lanes": original.lanes if original != null else [], "wave": original.wave if original != null else 1}
	var next := str(context)
	if next == signature: return
	signature = next
	_reset(peers, context)

func _reset(peers: Array, context: Dictionary) -> void:
	for layer in [world.towers, world.orbs, world.projectiles, world.zones]:
		for child in layer.get_children(): child.free()
	for key in ["arcs", "bolts", "beams", "pulses", "particles", "popups", "wells"]: world.set(key, [])
	world.combat_system.grid.clear()
	world.combat_system.targets.clear()
	world.combat_system.star_towers.clear()
	world.live_orbs.clear()
	world.perks = context.perks.duplicate(true)
	world.ley.assign(context.ley)
	world.lanes.assign(context.lanes)
	world.wave = context.wave
	world.run_game = 0.0
	world.wave_time = 0.0
	world.sim_id = 0
	world.eclipse_cd = 0.0
	world.eclipse_flash = 0.0
	world.side_big_t = 0.0
	world.field_view_system.fx_k = 0.5 if Meta.fx_low else 1.0
	copies.clear()
	for peer: Tower in peers:
		var copy := Tower.new()
		copy.main = world
		for key in BUILD_KEYS + STATE_KEYS:
			var value = peer.get(key)
			copy.set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
		copy.aim = copy.dir
		copy.eff = copy.eff_now()
		world.towers.add_child(copy)
		copies[peer.get_instance_id()] = copy
	clone = copies[source.get_instance_id()]
	for copy: Tower in world.towers.get_children():
		copy.self_modulate.a = 1.0 if copy == clone else 0.3
	# 오브젝트의 실제 월드 위치·방향은 유지하고 카메라만 돌린다. 맵·기맥·공명 판정도 그대로다.
	var xf := Transform2D(-clone.dir.angle(), Vector2(0.75, 0.75), 0.0, Vector2.ZERO)
	xf.origin = Vector2(65, 100) - xf * clone.position
	viewport.canvas_transform = xf
	elapsed = 0.0
	accumulator = 0.0
	refill_left = 0.0
	cycle = 0
	_spawn_targets()

func _spawn_targets() -> void:
	var damage: Dictionary = clone.hit_calc()
	var hp := maxf(3.0, (damage.one + damage.metal) * 2.5)
	var arena := world.viewport_system.arena().grow(-24.0)
	for i in 5:
		var orb := Orb.new()
		orb.main = world
		orb.setup(Orb.Kind.NORMAL, hp * (1.0 if i == 0 else 3.0), 16.0)
		var offset := clone.dir * (100.0 + i * 42.0) + clone.dir.orthogonal() * (0 if i < 3 else (i * 2 - 7) * 40)
		orb.position = (clone.position + offset).clamp(arena.position, arena.end)
		orb.target = clone.position - clone.dir * 80.0
		world.orbs.add_child(orb)
	cycle += 1

func advance(delta: float) -> void:
	if clone == null: return
	elapsed += delta
	# 프레임 효과 -> 이동 -> 게임 시간 -> 공격/명중 순서가 실제 프레임 처리와 같다.
	world.combat_system.tick_effects(delta)
	world.combat_system.step_entities(delta)
	world.run_game += delta
	world.wave_time += delta
	world.combat_system._resolve(delta, true)
	world.fx_layer.queue_redraw()
	# 고정 8초 초기화는 긴 발동·초신성·누적 강화를 잘랐다. 전투 상태를 유지하며 표적만 보충한다.
	if auto_refill and world.orbs.get_children().all(func(o): return o.is_queued_for_deletion()):
		refill_left += delta
		if refill_left >= 0.5:
			_spawn_targets()
			refill_left = 0.0

func _process(delta: float) -> void:
	var on := is_visible_in_tree() and is_instance_valid(source)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on: return
	caption.text = ("NEW · " if not source.new_reactions.is_empty() else "") + "예시 표적 · 발동 조건 적용"
	accumulator += minf(delta, 0.1)
	while accumulator >= 1.0 / 60.0:
		advance(1.0 / 60.0)
		accumulator -= 1.0 / 60.0
