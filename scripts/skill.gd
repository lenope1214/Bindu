class_name Skill
## 중앙 기술 (2026-10-31 사용자 "디펜스 한계 개선 A"): 웨이브 중에 쓰는 기술 2칸.
## 일반 판 준비 화면에서 세 가지 중 두 개 묶음을 고른다(Meta.skill_set). 쿨다운은 게임 시간이고 웨이브를 시작하면 모두 다시 찬다.
## 효과·수치는 Rules skill_* (온라인 패치로 조정). 멀티플레이·정원엔 없음.

const IDS := ["focus", "hold", "brand"]
const SETS := [["focus", "hold"], ["focus", "brand"], ["hold", "brand"]]
const NAMES := {"focus": "집중", "hold": "붙잡기", "brand": "낙인"}
const COLORS := {"focus": Color(1.0, 0.8, 0.35), "hold": Color(0.55, 0.85, 1.0), "brand": Color(1.0, 0.45, 0.55)}
const PICK_R := 70.0  # 집중: 누른 곳에서 이 거리 안 가장 가까운 오브젝트


## 묶음 번호 → 기술 두 개 (모르는 번호는 0번).
static func set_ids(i: int) -> Array:
	return SETS[i] if i >= 0 and i < SETS.size() else SETS[0]


static func combo_name(i: int) -> String:
	var ids := set_ids(i)
	return "%s + %s" % [NAMES[ids[0]], NAMES[ids[1]]]


static func desc(id: String) -> String:
	match id:
		"focus":
			return Rules.fmt("오브젝트 하나를 눌러 {skill_focus_t}초 동안 공격 속도 x{skill_focus_spd}")
		"hold":
			return Rules.fmt("누른 곳 둘레 구체를 {skill_hold_t}초 멈춤 (기절 한계·보스 절반)")
		"brand":
			return Rules.fmt("누른 곳 둘레 구체가 {skill_brand_t}초 동안 받는 피해 +{skill_brand_amp%}%")
	return ""


## 다시 쓰기까지 (특성 '빠른 손' n번이면 x(1-skill_cool_perk)^n).
static func cd_full(id: String, cool_n := 0) -> float:
	return Rules.t("skill_%s_cd" % id) * pow(1.0 - Rules.t("skill_cool_perk"), cool_n)


## 누른 자리에서 닿는 거리 (그릴 때·자동 사용).
static func radius(id: String) -> float:
	match id:
		"hold":
			return Rules.t("skill_hold_r")
		"brand":
			return Rules.t("skill_brand_r")
	return PICK_R


## 집중을 받을 오브젝트: p에서 PICK_R 안 가장 가까운 내 오브젝트.
static func focus_tower(main, p: Vector2) -> Tower:
	var best: Tower = null
	var bd := PICK_R
	for t in main.towers.get_children():
		if t.is_queued_for_deletion():
			continue
		var d: float = t.position.distance_to(p)
		if d < bd:
			bd = d
			best = t
	return best


## p에 쓴다. 닿은 것이 없으면 false (쿨다운을 쓰지 않는다).
static func use(main, id: String, p: Vector2) -> bool:
	var col: Color = COLORS[id]
	match id:
		"focus":
			var t := focus_tower(main, p)
			if t == null:
				return false
			t.focus_t = Rules.t("skill_focus_t")
			p = t.position
		"hold":
			var any := false
			var r := Rules.t("skill_hold_r")
			for o in main.near(p, r):
				if o.hp > 0.0 and o.position.distance_to(p) < r + o.radius():
					o.root(Rules.t("skill_hold_t"))
					any = true
			if not any:
				return false
		"brand":
			var any := false
			var r := Rules.t("skill_brand_r")
			for o in main.near(p, r):
				if o.hp > 0.0 and o.position.distance_to(p) < r + o.radius():
					o.amp["brand"] = [Rules.t("skill_brand_amp"), Rules.t("skill_brand_t")]
					any = true
			if not any:
				return false
	main.skill_fx.append([p, radius(id), 0.5, col])
	main.burst(p, col, 14, 180.0)
	return true


## 자동 사용(설정·봇): 쓸 만한 자리. 없으면 null.
## 집중: 둘레(사거리쯤) 구체가 가장 많은 오브젝트(3개 이상). 붙잡기: 중앙 가까이(260) 몰린 곳(3개 이상, 보스면 하나도).
## 낙인: 전장에서 가장 몰린 곳(4개 이상, 보스면 하나도).
static func auto_target(main, id: String) -> Variant:
	if id == "focus":
		var best: Tower = null
		var bn := 2
		for t in main.towers.get_children():
			var n: int = main.near(t.position, 300.0).size()
			if n > bn:
				bn = n
				best = t
		return best.position if best else null
	var r := radius(id)
	var need := 3 if id == "hold" else 4
	var best_p: Variant = null
	var best_n := need - 1
	for o in main.targets:
		if not is_instance_valid(o) or o.hp <= 0.0:
			continue
		if id == "hold" and not main._near_core(o, 260.0):
			continue
		var n: int = main.near(o.position, r).size()
		if o.kind == Orb.Kind.BOSS:
			n += need
		if n > best_n:
			best_n = n
			best_p = o.position
	return best_p
