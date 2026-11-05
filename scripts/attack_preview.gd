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

func configure(tower: Tower) -> void:
	source = tower
	world.ui_font = tower.main.ui_font if tower.main != null else ThemeDB.fallback_font
	caption.add_theme_font_override("font", world.ui_font)
	if tower.main != null:
		world.perks = tower.main.perks.duplicate(true)
		world.wave = tower.main.wave
	var values := {}
	for key in ["elements", "order", "pattern", "plv", "mods", "trigs", "pincer", "reso", "wind_buff"]:
		values[key] = tower.get(key)
	var next := str(values)
	if next == signature: return
	signature = next
	_reset(values)

func _reset(values: Dictionary) -> void:
	for layer in [world.towers, world.orbs, world.projectiles, world.zones]:
		for child in layer.get_children(): child.free()
	for key in ["arcs", "bolts", "beams", "pulses", "particles", "popups"]: world.set(key, [])
	clone = Tower.new()
	clone.main = world
	for key in values:
		var value = values[key]
		clone.set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	clone.position = Vector2(180, 360)
	clone.dir = Vector2.RIGHT
	world.towers.add_child(clone)
	var damage: Dictionary = clone.hit_calc()
	var hp := maxf(3.0, (damage.one + damage.metal) * 2.5)
	for i in 5:
		var orb := Orb.new()
		orb.main = world
		orb.setup(Orb.Kind.NORMAL, hp * (1.0 if i == 0 else 3.0), 8.0)
		orb.position = Vector2(380 + i * 48, 360 + (0 if i < 3 else (i * 2 - 7) * 50))
		orb.target = Vector2(120, 360)
		world.orbs.add_child(orb)
	elapsed = 0.0

func advance(delta: float) -> void:
	if clone == null: return
	elapsed += delta
	world.run_game += delta
	world.sim_id += 1
	for layer in [world.orbs, world.projectiles, world.zones]:
		for child in layer.get_children():
			if not child.is_queued_for_deletion(): child.step(delta)
	world.combat_system._resolve(delta, true)
	for q in world.arcs: q[2] -= delta
	world.arcs = world.arcs.filter(func(q): return q[2] > 0)
	for key in ["bolts", "pulses", "beams", "particles", "popups"]:
		var items: Array = world.get(key)
		for q in items:
			if key == "particles": q[0] += q[1] * delta
			if key == "popups": q[0] += Vector2(0, -40) * delta
			var index := 1 if key == "bolts" else (3 if key == "beams" else 2)
			q[index] -= delta
		world.set(key, items.filter(func(q): return q[1 if key == "bolts" else (3 if key == "beams" else 2)] > 0))
	world.fx_layer.queue_redraw()
	if elapsed >= 8.0 and is_instance_valid(source):
		signature = ""
		configure(source)

func _process(delta: float) -> void:
	var on := is_visible_in_tree()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on: return
	caption.text = ("NEW · " if is_instance_valid(source) and not source.new_reactions.is_empty() else "") + "최종 공격 · 조건에 따라 발동"
	accumulator += minf(delta, 0.1)
	while accumulator >= 1.0 / 30.0:
		advance(1.0 / 30.0)
		accumulator -= 1.0 / 30.0
