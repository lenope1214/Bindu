class_name Hero
## 영웅 속성 (시험, test/hero): 판 시작 때 17속성 중 하나를 골라 영웅 오브젝트 하나를 받고, 그 하나만 레벨을 올려 능력을 고른다.
## 상태는 영웅 오브젝트(Tower.hero*)에 있어 이어하기·협동 동기화는 오브젝트 저장을 따른다.
## 기획: 2026-11-07 영웅 속성 기획안 v4 (루트 선택 없음, 모든 판이 영웅 고르기로 시작).

const XP_CARD := 10.0  # 영웅에 카드 1장
const XP_WAVE := 4.0  # 웨이브 하나 넘길 때마다 (줄지 않음)
const XP_DMG := 20.0  # 웨이브 피해 몫 x 이 값, 웨이브당 XP_DMG_CAP까지
const XP_DMG_CAP := 6.0
const FADE := 8.0  # 같은 길은 받은 횟수 n만큼 기본값 / (1 + n/FADE)
const LV_K := 0.08  # 레벨마다 영웅 피해 +8%
const CARD_K := 1.5  # 영웅 속성 카드 등장 배율
const AB_LV := [3, 6, 10]  # 능력을 고르는 레벨 (1차: 공통 3·6, Lv10은 공통 2개로 시험)
const ABIL := {
	3: [["far", "먼 눈", "크기 강화 1개를 공짜로: 범위·사거리가 넓어져요"], ["twin", "두 갈래", "다중 발사 1개를 공짜로: 공격이 하나 더 나가요"]],
	6: [["teach", "영웅의 가르침", "영웅 속성이 든 다른 오브젝트 피해 +영웅 레벨x3%"], ["hone", "단련", "영웅 피해 x1.3"]],
	10: [["overload", "과부하", "영웅 공격 속도 x1.5"], ["smite", "강타", "영웅 피해 x1.5"]],
}


## Lv에서 다음 레벨까지 필요한 경험치: Lv10까지 10, 그 뒤 1.3배씩.
static func need(lv: int) -> float:
	return 10.0 if lv < 10 else 10.0 * pow(1.3, lv - 9)


## 이 판의 영웅 오브젝트 (없으면 null).
static func tower_of(session) -> Tower:
	if session == null:
		return null
	for t in session.towers.get_children():
		if t is Tower and t.hero and not t.is_queued_for_deletion():
			return t
	return null


## 경험치를 준다. path: card·wave·dmg. wave 말고는 같은 길로 받을수록 줄어든다. 오른 레벨 수를 돌려준다.
static func gain(t: Tower, path: String, base: float) -> int:
	if t == null or not t.hero or base <= 0.0:
		return 0
	var n: int = t.hero_n.get(path, 0)
	var amt := base if path == "wave" else base / (1.0 + n / FADE)
	t.hero_n[path] = n + 1
	t.hero_xp += amt
	var ups := 0
	while t.hero_xp >= need(t.hero_lv):
		t.hero_xp -= need(t.hero_lv)
		t.hero_lv += 1
		ups += 1
		if t.hero_lv in AB_LV and not t.hero_ab.has(str(t.hero_lv)) and not t.hero_pend.has(t.hero_lv):
			t.hero_pend.append(t.hero_lv)
	if ups > 0:
		t.place_pop = 1.0
		t.queue_redraw()
	return ups


## 웨이브 끝: 생존 4 + 피해 몫 (웨이브당 최대 6).
static func wave_done(session) -> void:
	var h := tower_of(session)
	if h == null:
		return
	var total := 0.0
	for t in session.towers.get_children():
		total += t.dealt
	var lv0 := h.hero_lv
	gain(h, "wave", XP_WAVE)
	if total > 0.0:
		gain(h, "dmg", minf(XP_DMG * h.dealt / total, XP_DMG_CAP))
	if h.hero_lv > lv0:
		session.hud_system._show_toast("영웅 Lv%d!" % h.hero_lv)


## 영웅 오브젝트가 이 능력을 골랐는지.
static func has_ab(t: Tower, id: String) -> bool:
	return t != null and t.hero and t.hero_ab.values().has(id)


## 영웅 피해 배율 (레벨 + 능력).
static func dmg_k(t: Tower) -> float:
	var k := 1.0 + LV_K * (t.hero_lv - 1)
	if has_ab(t, "hone"):
		k *= 1.3
	if has_ab(t, "smite"):
		k *= 1.5
	return k


## 영웅이 아닌 오브젝트: 영웅의 가르침이면 영웅 속성이 든 오브젝트 피해 +.
static func teach_k(t: Tower) -> float:
	if t.main == null or t.hero:
		return 1.0
	var h := tower_of(t.main)
	if h == null or not has_ab(h, "teach") or not t.elements.has(h.hero_e):
		return 1.0
	return 1.0 + 0.03 * h.hero_lv


static func spd_k(t: Tower) -> float:
	return 1.5 if has_ab(t, "overload") else 1.0


## 능력이 주는 공짜 강화 (영웅 강화 합계·상한에 세지 않음).
static func free_mod(t: Tower, id: String) -> int:
	if id == "size" and has_ab(t, "far"):
		return 1
	if id == "multi" and has_ab(t, "twin"):
		return 1
	return 0


## 영웅 고르기를 띄울지: 새 판(웨이브 0)이고 혼자 하는 판, 튜토리얼·멀티 아님, 영웅이 아직 없음.
static func should_pick(session) -> bool:
	return session.wave == 0 and session.mp_mode == "" and not TutPlay.on and not session.tutor and tower_of(session) == null \
		and (DisplayServer.get_name() != "headless" or OS.get_environment("HERO") != "")


## 영웅 오브젝트를 놓는다 (지키는 곳 왼쪽 위). 직선탄 + 영웅 속성 Lv1.
static func spawn(session, e: int) -> Tower:
	if tower_of(session) != null or not e in Elem.ALL:
		return null
	var core: Vector2 = session.viewport_system.core()
	var p := core + Vector2(-130, -70)
	var fr: Rect2 = session.combat_system.field_rect().grow(-40)
	p = p.clamp(fr.position, fr.end)
	var keep: Dictionary = session.picked
	session.picked = {"type": "elem", "e": e, "lv": 1}
	session.interaction_system._place_tower(p, (p - core).normalized())
	session.picked = keep
	var t: Tower = session.towers.get_child(session.towers.get_child_count() - 1)
	t.hero = true
	t.hero_e = e
	t.queue_redraw()
	session.hud_system._show_toast("영웅: %s. 영웅에 카드를 넣고 웨이브를 넘기면 레벨이 올라요" % Elem.NAMES[e])
	return t


## 능력 하나를 고른다.
static func choose(t: Tower, lv: int, id: String) -> void:
	t.hero_ab[str(lv)] = id
	t.hero_pend.erase(lv)
	t.queue_redraw()


# ---------- 고르기 창 ----------

static func _panel(session, title: String) -> VBoxContainer:
	var root := PanelContainer.new()
	root.name = "HeroPick"
	root.z_index = 60
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.97)
	sb.border_color = Color(1, 0.82, 0.4, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	root.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", Meta.fs(20))
	head.add_theme_color_override("font_color", Color("ffd479"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	session.ui_root.add_child(root)
	var center := func(): root.position = ((session.ui_root.size - root.size) * 0.5).max(Vector2.ZERO)
	root.resized.connect(center)
	center.call_deferred()
	return box


static func is_open(session) -> bool:
	return session.ui_root.has_node("HeroPick")


static func close(session) -> void:
	var n: Node = session.ui_root.get_node_or_null("HeroPick")
	if n:
		session.ui_root.remove_child(n)
		n.queue_free()


## 17속성 중 영웅 속성 고르기 창.
static func open_pick(session) -> void:
	if is_open(session):
		return
	var box := _panel(session, "영웅 속성을 고르세요")
	var sub := Label.new()
	sub.text = "고른 속성의 영웅 오브젝트를 하나 받아요. 영웅 속성은 종류·레벨 상한이 없고, 레벨이 오르면 능력을 골라요."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(560, 0)
	sub.add_theme_font_size_override("font_size", Meta.fs(13))
	box.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for e in Elem.ALL:
		var b := Button.new()
		b.text = Elem.NAMES[e]
		b.custom_minimum_size = Vector2(88, 40)
		b.add_theme_font_size_override("font_size", Meta.fs(15))
		b.add_theme_color_override("font_color", (Elem.COLORS[e] as Color).lightened(0.25))
		b.pressed.connect(func():
			close(session)
			spawn(session, e)
			session.persistence_system._save_run())
		grid.add_child(b)
	var skip := Button.new()
	skip.text = "영웅 없이 시작"
	skip.pressed.connect(func(): close(session))
	box.add_child(skip)


## 쉬는 시간: 고를 능력이 남았으면 두 개 중 하나 고르기 창.
static func open_ability(session) -> void:
	var h := tower_of(session)
	if h == null or h.hero_pend.is_empty() or is_open(session):
		return
	var lv: int = h.hero_pend[0]
	var box := _panel(session, "영웅 Lv%d 능력 고르기 · 고르지 않은 쪽은 이 판에서 사라져요" % lv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for opt in ABIL[lv]:
		var b := Button.new()
		b.text = "%s\n%s" % [opt[1], opt[2]]
		b.custom_minimum_size = Vector2(260, 84)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", Meta.fs(14))
		var id: String = opt[0]
		b.pressed.connect(func():
			choose(h, lv, id)
			close(session)
			session.hud_system._show_toast("영웅 능력: " + opt[1])
			if not h.hero_pend.is_empty():
				open_ability(session))
		row.add_child(b)
