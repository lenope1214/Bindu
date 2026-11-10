class_name Oath
## 보스 서약 (시험, test/boss-oath): 10웨이브마다 보스를 잡은 뒤 '이득과 제약이 함께 붙은' 서약 3장 중 1장을 고르거나 건너뛴다.
## 고른 서약은 판 끝까지, 한 판에 최대 MAX개. 제약은 수치 너프가 아니라 카드 풀을 줄이는 쪽.
## 지금 빌드에서 뜻이 있는 서약만 나오고(등장 조건), 조건 맞는 서약이 2개 미만이면 화면을 띄우지 않는다.
## 기획: 2026-11-05 보스 서약 기획안의 추천 1차 6개(한길·굳은 형태·맨손·깊이·상성·질주).

const EVERY := 10  # 이 웨이브마다
const MAX := 3
const DEFS := {
	"one_path": {"name": "한길", "gain": "가장 많이 가진 속성 하나의 특징 세기 x1.5", "cost": "그 속성과 상성이 약한 속성 카드가 더 안 나와요"},
	"rigid": {"name": "굳은 형태", "gain": "모든 오브젝트 공격방식 레벨 +1", "cost": "공격방식 카드가 더 안 나와요"},
	"bare": {"name": "맨손", "gain": "곁공격 간격 -30%, 큰 곁공격이 5번째마다", "cost": "강화 카드가 더 안 나와요"},
	"depth": {"name": "깊이", "gain": "속성 카드가 한 단계 높게 나와요 (레벨 상한 안)", "cost": "새 속성 종류 카드가 더 안 나와요"},
	"affinity": {"name": "상성", "gain": "강한 상성 특징 x1.5 → x2.0", "cost": "약한 상성 짝을 만든 오브젝트는 공격 속도 -20%"},
	"sprint": {"name": "질주", "gain": "점수 x1.2, 쉬는 시간마다 새로고침 +1", "cost": "카드 선택지 3장 → 2장"},
}

static var taken: Array = []  # 고른 서약 id (고른 순서)
static var path_e := -1  # 한길: 고른 때 가장 많이 가진 속성
static var offered_w := -1  # 마지막으로 서약 화면을 띄운 웨이브 (이어하기·특성 뒤 다시 안 띄우게)


static func new_run() -> void:
	taken = []
	path_e = -1
	offered_w = -1


static func has(id: String) -> bool:
	return taken.has(id)


static func save() -> Dictionary:
	return {"taken": taken.duplicate(), "path_e": path_e, "offered_w": offered_w}


static func load_from(d: Variant) -> void:
	new_run()
	if not d is Dictionary:
		return
	var tk: Variant = d.get("taken", [])
	if tk is Array:
		for id in tk:
			if id is String and DEFS.has(id) and not taken.has(id) and taken.size() < MAX:
				taken.append(id)
	var pe: Variant = d.get("path_e", -1)
	path_e = int(pe) if (pe is int or pe is float) and int(pe) in Elem.ALL else -1
	var ow: Variant = d.get("offered_w", -1)
	offered_w = int(ow) if ow is int or ow is float else -1


# ---------- 빌드 읽기 ----------

## 내 오브젝트들이 가진 속성 -> 레벨 합.
static func owned(towers: Array) -> Dictionary:
	var out := {}
	for t in towers:
		for e in t.elements:
			out[e] = out.get(e, 0) + t.elements[e]
	return out


static func top_elem(towers: Array) -> int:
	var o := owned(towers)
	var best := -1
	for e in o:
		if best < 0 or o[e] > o[best]:
			best = e
	return best


## e와 상성이 약한 속성들.
static func weak_of(e: int) -> Array:
	return Elem.ALL.filter(func(x): return x != e and Elem.aff_of(e, x)["weak"] and not Elem.aff_of(e, x)["strong"])


static func strong_pairs(towers: Array) -> int:
	var n := 0
	for t in towers:
		for p in Share.aff(t)["pairs"]:
			if p[2]["strong"]:
				n += 1
	return n


## 지금 빌드에서 이 서약이 뜻이 있는지 (기획안 '나오는 때').
static func available(id: String, towers: Array) -> bool:
	if has(id):
		return false
	match id:
		"one_path":
			var e := top_elem(towers)
			if e < 0:
				return false
			var o := owned(towers)
			return weak_of(e).filter(func(x): return not o.has(x)).size() >= 2
		"rigid":
			if towers.size() < 4:
				return false
			var changed := towers.filter(func(t): return t.pattern != Pat.DEFAULT).size()
			return changed * 2 >= towers.size() and changed < towers.size()
		"bare":
			if towers.is_empty():
				return false
			var used := 0
			for t in towers:
				used += t.mod_count()
			return float(used) / towers.size() < Rules.mod_total * 0.5
		"depth":
			var k := owned(towers).size()
			return k >= 4 and k <= 7
		"affinity":
			return strong_pairs(towers) >= 2
		"sprint":
			return true
	return false


## 서약 화면을 띄울지: 혼자 하는 판, EVERY웨이브마다 (그 웨이브에 한 번), MAX개 미만, 조건 맞는 서약 2개 이상.
static func should_offer(session) -> bool:
	if session.mp_mode != "" or TutPlay.on or session.wave <= 0 or session.wave % EVERY != 0 or offered_w == session.wave or taken.size() >= MAX:
		return false
	return choices(session.multiplayer_system._my_towers()).size() >= 2


## 이번에 보일 서약 (최대 3장, 무작위).
static func choices(towers: Array) -> Array:
	var ids: Array = DEFS.keys().filter(func(id): return available(id, towers))
	ids.shuffle()
	return ids.slice(0, 3)


## 서약을 고른다 (한 번 효과는 여기서).
static func take(session, id: String) -> void:
	if has(id) or taken.size() >= MAX or not DEFS.has(id):
		return
	taken.append(id)
	var towers: Array = session.multiplayer_system._my_towers()
	match id:
		"one_path":
			path_e = top_elem(towers)
		"rigid":
			for t in towers:
				t.plv += 1
				t.queue_redraw()
	session.hud_system._show_toast("서약: %s" % DEFS[id]["name"])


# ---------- 효과 (다른 코드에서 부름) ----------

## 카드 풀 제약: 이 카드를 낼 수 있는지.
static func card_ok(session, card: Dictionary) -> bool:
	if taken.is_empty():
		return true
	match str(card.get("type", "")):
		"pat":
			return not has("rigid")
		"mod":
			return not has("bare")
		"elem":
			var e := int(card.get("e", -1))
			if has("one_path") and path_e >= 0 and weak_of(path_e).has(e):
				return false
			if has("depth") and session != null and not owned(session.multiplayer_system._my_towers()).has(e):
				return false
	return true


## 깊이: 속성 카드 레벨 +1 (레벨 상한 안).
static func elem_lv(lv: int) -> int:
	return mini(lv + 1, Tower.elem_cap()) if has("depth") else lv


## 특징 세기 배율 (Share.k).
static func share_k(e: int) -> float:
	return 1.5 if has("one_path") and e == path_e else 1.0


static func aff_carry() -> float:
	return 2.0 if has("affinity") else Share.AFF_CARRY


## 상성 서약: 약한 상성 짝을 가진 오브젝트 공격 속도 -20%.
static func spd_k(tw: Object) -> float:
	if not has("affinity"):
		return 1.0
	for p in Share.aff(tw)["pairs"]:
		if p[2]["weak"] and not p[2]["strong"]:
			return 0.8
	return 1.0


static func side_iv_k() -> float:
	return 0.7 if has("bare") else 1.0


static func side_big_n(n: int) -> int:
	return 5 if has("bare") and n > 0 else n


static func offer_n() -> int:
	return 2 if has("sprint") else 3


static func score_k() -> float:
	return 1.2 if has("sprint") else 1.0


static func rerolls() -> int:
	return 1 if has("sprint") else 0


# ---------- 화면 ----------

static func is_open(session) -> bool:
	return session.ui_root.has_node("OathPick")


static func close(session) -> void:
	var n: Node = session.ui_root.get_node_or_null("OathPick")
	if n:
		session.ui_root.remove_child(n)
		n.queue_free()


static func open(session) -> void:
	if is_open(session):
		return
	offered_w = session.wave
	var ids := choices(session.multiplayer_system._my_towers())
	var root := PanelContainer.new()
	root.name = "OathPick"
	root.z_index = 60
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.1, 0.97)
	sb.border_color = Color(0.85, 0.55, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	root.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	var head := Label.new()
	head.text = "보스 서약 (%d/%d) · 판 끝까지 가요" % [taken.size() + 1, MAX]
	head.add_theme_font_size_override("font_size", Meta.fs(20))
	head.add_theme_color_override("font_color", Color("e0b3ff"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for id in ids:
		var d: Dictionary = DEFS[id]
		var b := Button.new()
		var extra := ""
		if id == "one_path":
			var e := top_elem(session.multiplayer_system._my_towers())
			extra = " (%s)" % Elem.NAMES.get(e, "")
		b.text = "%s%s\n\n+ %s\n- %s" % [d["name"], extra, d["gain"], d["cost"]]
		b.custom_minimum_size = Vector2(230, 150)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", Meta.fs(14))
		b.pressed.connect(func():
			take(session, id)
			close(session)
			session.cards_system._make_choices()  # 제약이 바로 카드 줄에 맞게
			session.persistence_system._save_run())
		row.add_child(b)
	var skip := Button.new()
	skip.text = "서약 안 함"
	skip.pressed.connect(func():
		close(session)
		session.persistence_system._save_run())
	box.add_child(skip)
	session.ui_root.add_child(root)
	var center := func(): root.position = ((session.ui_root.size - root.size) * 0.5).max(Vector2.ZERO)
	root.resized.connect(center)
	center.call_deferred()
