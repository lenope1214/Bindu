class_name BinduEditHistory
extends RefCounted
## 쉬는 시간 편집의 메모리 이력. 디스크 복원과 분리해 기존 Node·Callable을 보존한다.
const LIMIT := 20
const REST := [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY]
const STATE_FIELDS := ["phase", "wave_active", "picks_left", "offer", "perk_offer", "perk_mode",
	"bank_picks", "bank_rerolls", "bank_perks", "rerolls_left", "bonus_rerolls", "perk_rerolls",
	"countdown", "run_log", "new_achievements", "tutor_given", "rest_ready", "picked", "place_pos", "aim_d", "aim_wait"]
const SIGNATURE_FIELDS := ["phase", "picks_left", "offer", "perk_offer", "perk_mode", "bank_picks",
	"bank_rerolls", "bank_perks", "rerolls_left", "bonus_rerolls", "perk_rerolls", "run_log"]
const DOCK_FIELDS := ["inspector_dismissed", "dismissed_tower", "inspected_tower", "reading_card", "reading_return_cards", "reading_review", "inspect_return_cards"]
const UI_FIELDS := ["cards_hidden", "tap_sel", "hover_elem", "tip_tower", "tip_detail", "tip_frame"]

var _session_ref: WeakRef
var session: BinduSession:
	get: return _session_ref.get_ref() as BinduSession
var edit_history: Array[Dictionary] = []
var pending_edit: Dictionary = {}
var last_reason := "아직 되돌릴 변경이 없어요"
var _empty_reason := "아직 되돌릴 변경이 없어요"

func _init(owner_session: BinduSession) -> void:
	_session_ref = weakref(owner_session)
	_observe_sync()

func _observe_sync() -> void:
	# 다른 기기 진행이 합쳐진 뒤 로컬 snapshot으로 그 진행을 덮어쓰지 않는다.
	if session != null and session.net != null and not session.net.progress_synced.is_connected(_on_progress_synced):
		session.net.progress_synced.connect(_on_progress_synced)

func _on_progress_synced() -> void:
	clear_edit_history("진행 동기화 뒤에는 이전 편집을 되돌릴 수 없어요")

func clear_edit_history(reason := "새 선택지나 웨이브가 시작되어 이전 편집은 되돌릴 수 없어요") -> void:
	edit_history.clear()
	pending_edit.clear()
	last_reason = reason
	_empty_reason = reason

func begin_edit(label := "배치") -> void:
	var game := session
	if game == null or game.mp_mode != "" or TutPlay.on or not game.phase in REST or game.perk_mode or game.coin_stage > 0 or game.title_label.visible:
		return
	_observe_sync()
	if game.net != null and game.net.syncing:
		clear_edit_history("진행 동기화 중에는 편집을 되돌릴 수 없어요")
		return
	# 카드 취소는 소비하지 않는다. 다음 편집은 취소 전의 오래된 snapshot을 이어 쓰지 않는다.
	pending_edit = _capture(label)

func finish_edit() -> void:
	if pending_edit.is_empty():
		return
	var game := session
	if game == null or pending_edit.context != _context():
		clear_edit_history()
		return
	if not game.phase in REST:
		# 카드를 든 채 옮기기·새 설치 AIM은 아직 같은 편집 안에 있다.
		if game.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.AIM]:
			return
		clear_edit_history()
		return
	# 남은 고르기가 있으면 _after_place가 새 draft를 공개한다. 같은 값이 뽑혀도 경계다.
	if game.phase == BinduSession.Phase.CHOOSE and game.picks_left < int(pending_edit.state.picks_left):
		clear_edit_history("새 카드가 공개되어 이전 카드 적용은 되돌릴 수 없어요")
		return
	var after := _semantic()
	if after == pending_edit.before:
		pending_edit = {}
		return
	if not _original_nodes_valid(pending_edit):
		clear_edit_history("오브젝트 구성이 바뀌어 이전 편집을 되돌릴 수 없어요")
		return
	pending_edit["after"] = after
	pending_edit["transform_only"] = _without_transform(after) == _without_transform(pending_edit.before)
	pending_edit["profile_after"] = _profile()
	edit_history.append(pending_edit)
	if edit_history.size() > LIMIT:
		edit_history.pop_front()
	pending_edit = {}
	last_reason = ""
	_empty_reason = "아직 되돌릴 변경이 없어요"

func can_undo() -> bool:
	var game := session
	if game == null:
		return false
	_observe_sync()
	if game.mp_mode != "" or TutPlay.on or game.perk_mode or game.coin_stage > 0 or not game.phase in REST:
		last_reason = "들고 있는 카드나 방향 편집을 먼저 마쳐 주세요"
		return false
	if game.card_dock.input_blocked() or game.interaction_system._reading_modal_open():
		last_reason = "열린 창을 닫고 되돌려 주세요"
		return false
	var input := game.interaction_system
	if input.dragging or is_instance_valid(input.press_t) or is_instance_valid(input.moving) or input.boxing or not game.card_dock.pending_card.is_empty():
		last_reason = "진행 중인 입력을 먼저 마쳐 주세요"
		return false
	if not pending_edit.is_empty():
		# 취소 후 CHOOSE에서 pending만 남은 경우. 실제 변경이 있으면 불완전 편집이다.
		if pending_edit.context != _context() or _semantic() != pending_edit.before:
			clear_edit_history("완료되지 않은 편집이 있어 이전 상태를 복원하지 않았어요")
			return false
		pending_edit = {}
	if edit_history.is_empty():
		last_reason = _empty_reason
		return false
	var entry: Dictionary = edit_history.back()
	if entry.context != _context() or not _original_nodes_valid(entry) or _semantic() != entry.after:
		clear_edit_history("판이나 오브젝트 상태가 바뀌어 이전 편집은 되돌릴 수 없어요")
		return false
	if not entry.transform_only and ((game.net != null and game.net.syncing) or _profile() != entry.profile_after):
		clear_edit_history("진행 기록이 바뀌어 카드 적용을 되돌릴 수 없어요")
		return false
	last_reason = ""
	return true

func undo_edit() -> bool:
	if not can_undo():
		if session != null:
			session.hud_system._show_toast(last_reason)
		return false
	var entry: Dictionary = edit_history.pop_back()
	var game := session
	if entry.transform_only:
		# 위치·방향만 복원한다. 쉬는 동안 지난 타이머나 실행 대기 효과까지 되감지 않는다.
		for record in entry.towers:
			var tower: Tower = record.node
			var after := _tower_from(entry.after.towers, tower.get_instance_id())
			if record.save.pos != after.pos:
				tower.position = record.save.pos
			if record.save.dir != after.dir:
				tower.dir = record.vars.dir
				tower.aim = record.vars.aim
			# 취소·실패한 이동의 시각 효과는 이력에 포함하지 않는다.
			tower.queue_redraw()
	else:
		var originals: Array = entry.towers.map(func(record): return record.node)
		for tower in game.towers.get_children():
			if not tower in originals:
				game.towers.remove_child(tower)
				tower.queue_free()
		for record in entry.towers:
			var tower: Tower = record.node
			for key in record.vars:
				var value: Variant = record.vars[key]
				if value is Object and not is_instance_valid(value):
					value = null
				if tower.get(key) != value:
					tower.set(key, _copy(value))
			tower.transform = record.transform
			tower.queue_redraw()
		_restore_fields(game, entry.state)
		Meta.tally = _copy(entry.profile.tally)
		Meta.achieved = _copy(entry.profile.achieved)
		Meta.codex = _copy(entry.profile.codex)
		Ach.run = _copy(entry.profile.ach_run)
		game.banner_queue = _copy(entry.banner_queue)
		game.banner_t = entry.banner_t
		game.banner.text = entry.banner_text
	_restore_ui(entry)
	game.hud_system._show_toast(str(entry.label) + " 되돌림")
	if not entry.transform_only:
		game.progression_system._save_best()
	game.persistence_system._save_run()
	return true

func _capture(label: String) -> Dictionary:
	var game := session
	var towers: Array = []
	for tower: Tower in game.towers.get_children():
		var properties := {}
		for property in tower.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				properties[property.name] = _copy(tower.get(property.name))
		towers.append({"node":tower, "vars":properties, "transform":tower.transform, "save":_copy(tower.to_save())})
	var hovered := {}
	if is_instance_valid(game.card_dock.hovered):
		hovered = _copy(game.card_dock.hovered.get_meta("offer_card", {}))
	return {"label":label, "context":_context(), "before":_semantic(), "state":_fields(game, STATE_FIELDS), "towers":towers,
		"profile":_profile(), "ui":_fields(game, UI_FIELDS), "dock":_fields(game.card_dock, DOCK_FIELDS), "hovered":hovered,
		"selected":game.interaction_system.selected.duplicate(), "additive":game.interaction_system.additive_selection,
		"banner_queue":_copy(game.banner_queue), "banner_t":game.banner_t, "banner_text":game.banner.text}

func _context() -> Dictionary:
	var game := session
	return {"run":game.run_id, "wave":game.wave, "map":Meta.map_id, "rules":Meta.rules, "modes":Array(Modes.on), "container":game.towers.get_instance_id()}

func _semantic() -> Dictionary:
	var towers: Array = []
	for tower: Tower in session.towers.get_children():
		towers.append({"id":tower.get_instance_id(), "save":_copy(tower.to_save())})
	return {"state":_fields(session, SIGNATURE_FIELDS), "towers":towers}

func _without_transform(state: Dictionary) -> Dictionary:
	var copy := state.duplicate(true)
	for record in copy.towers:
		record.save.erase("pos")
		record.save.erase("dir")
	return copy

func _tower_from(towers: Array, id: int) -> Dictionary:
	for record in towers:
		if record.id == id:
			return record.save
	return {}

func _original_nodes_valid(entry: Dictionary) -> bool:
	for record in entry.towers:
		if not is_instance_valid(record.node) or record.node.is_queued_for_deletion() or record.node.get_parent() != session.towers:
			return false
	return true

func _profile() -> Dictionary:
	return {"tally":Meta.tally.duplicate(true), "achieved":Meta.achieved.duplicate(true), "codex":Meta.codex.duplicate(true), "ach_run":Ach.run.duplicate(true)}

func _fields(object: Object, names: Array) -> Dictionary:
	var result := {}
	for key in names:
		result[key] = _copy(object.get(key))
	return result

func _restore_fields(object: Object, state: Dictionary) -> void:
	for key in state:
		object.set(key, _copy(state[key]))

func _copy(value: Variant) -> Variant:
	# Array/Dictionary만 깊이 복사한다. Node·Resource·Callable identity는 그대로 둔다.
	return value.duplicate(true) if value is Array or value is Dictionary else value

func _restore_ui(entry: Dictionary) -> void:
	var game := session
	var input := game.interaction_system
	game.card_dock.clear_gesture()
	game.card_dock.close_inspector()
	_restore_fields(game, entry.ui)
	_restore_fields(game.card_dock, entry.dock)
	if game.phase == BinduSession.Phase.CHOOSE:
		# 저장된 같은 선택지만 다시 그린다. _make_choices/_start_choose는 호출하지 않는다.
		game.cards_system._show_offer()
		game.cards_system._update_reroll_btn()
	else:
		game.reroll_btn.visible = false
	game.choice_box.visible = game.phase == BinduSession.Phase.CHOOSE and not game.cards_hidden
	game.start_btn.visible = game.phase == BinduSession.Phase.READY
	game.cancel_btn.hide()
	game.aim_ok_btn.hide()
	game.card_dock.hovered = null
	for button: Button in game.choice_box.get_children():
		if not button.is_queued_for_deletion() and button.get_meta("offer_card", {}) == entry.hovered:
			game.card_dock.hovered = button
	game.tap_sel = entry.ui.tap_sel
	input.selected = entry.selected.filter(func(tower): return is_instance_valid(tower) and tower.get_parent() == game.towers)
	input.additive_selection = entry.additive
	input._update_place_dim()
	input._restore_hint()
	game.cards_system._tap_hover()
	game.card_dock.side_signature = ""
	game.card_dock.tick()
	game.menu_system._refresh_legend()
	game.info.queue_redraw()
	game.queue_redraw()
