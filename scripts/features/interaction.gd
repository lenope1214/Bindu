class_name BinduInteraction
extends BinduFeature
## 입력·선택·이동·방향 편집과 제스처 상태. 예약 콜백은 main의 순서를 따른다.

var moving: Tower = null  # 위치를 옮기는 중인 오브젝트
# 오브젝트를 꾹 누르거나 끌면 바로 옮긴다(카드를 고른 뒤에도). 선택된 오브젝트를 끌면 함께 움직인다.
var press_t: Tower = null
var press_pos := Vector2.ZERO
var press_ms := 0
var dragging := false
var drag_group: Array = []  # 함께 끄는 오브젝트들
var drag_origs: Array = []  # 끌기 전 위치
var selected: Array = []  # 여러 개 선택 (빈 곳을 끌어 상자로, Shift/Ctrl+클릭으로 더하고 빼기)
var boxing := false  # 선택 상자를 끄는 중
var wheel_acc := 0.0  # 오브젝트 휠 돌리기: 트랙패드의 잘게 오는 휠을 한 칸이 될 때까지 모은다
var aim_right := false  # 오브젝트를 우클릭한 채 끌어 방향을 정하는 중 (떼면 확정)
var box_start := Vector2.ZERO
var move_orig_pos := Vector2.ZERO
var move_orig_dir := Vector2.RIGHT
var move_cards_hidden := false
var move_return := BinduSession.Phase.CHOOSE  # 옮기기를 끝내면 돌아갈 단계
var touches := {}  # 터치 번호 → 화면 자리 (두 손가락 확대·이동)
var pinch_d := 0.0  # 두 손가락 사이 거리 (확대 시작할 때)
var pinch_z := 1.0
var pinch_lock := false  # 두 손가락을 댄 뒤 모든 손가락을 뗄 때까지 누르기·끌기를 막는다 (확대하다 설치되지 않게)
var mid_drag := false  # PC: 휠 누른 채 끌어 화면 이동
var info_mouse_capture := false
var info_touch_capture := -1
var aim_start_ms := 0
var aim_hold := false  # 손가락을 대고 있는 중 (터치)
var additive_selection := false  # 화면 선택 모드: 터치로 선택에 더하고 뺀다.
var drag_refusal := ""
var drag_invalid: Array = []
var keyboard_active := false
var _direction_group: Array = []
var _direction_origins: Array = []
var _move_selection: Array = []


func _reading_modal_open() -> bool:
	return session.settings_panel.visible or session.notes_panel.visible or session.codex_panel.visible or session.vote_panel.visible or session.records_panel.visible or session.help_label.visible or session.modes_panel.visible or session.menu_system.sound_pop.visible or (session.tut != null and session.tut.visible)


func _history_begin(label: String) -> void:
	if session.cards_system.has_method("begin_edit"):
		session.cards_system.call("begin_edit", label)


func _history_finish() -> void:
	if session.cards_system.has_method("finish_edit"):
		session.cards_system.call("finish_edit")


func _gift_blocked() -> bool:
	if session.mp_mode != "coop" or not session.multiplayer_system.gifts().blocks_local_choice(): return false
	session.hud_system._show_toast(session.multiplayer_system.gifts().pending_notice())
	return true


func _can_edit_selection() -> bool:
	return not _gift_blocked() and not session.get_tree().paused and not _reading_modal_open() and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] and not session.perk_mode


func set_additive_selection(on: bool) -> void:
	additive_selection = on and _can_edit_selection()
	_restore_hint()


func toggle_additive_selection() -> void:
	set_additive_selection(not additive_selection)


func clear_selection() -> void:
	selected.clear()
	session.card_dock.close_inspector()
	_restore_hint()


func select_all() -> void:
	if not _can_edit_selection():
		return
	selected = session.multiplayer_system._my_towers()
	if not selected.is_empty():
		session.card_dock.inspector_dismissed = false
		session.card_dock.inspected_tower = selected[0]
	_restore_hint()


func cycle_selection(backward := false) -> void:
	if session.get_tree().paused or _reading_modal_open() or session.perk_mode or not session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY, BinduSession.Phase.WAVE, BinduSession.Phase.PLACE]:
		return
	var candidates: Array = session.towers.get_children().filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
	candidates.sort_custom(func(a, b): return a.position.x < b.position.x if not is_equal_approx(a.position.x, b.position.x) else a.position.y < b.position.y)
	if candidates.is_empty():
		return
	var current: Tower = selected[0] if not selected.is_empty() else session.card_dock.inspected_tower
	var at := candidates.find(current)
	if at < 0 and backward:
		at = 0
	var t: Tower = candidates[posmod(at + (-1 if backward else 1), candidates.size())]
	_select_tower(t)
	pointer_position = session.get_canvas_transform() * t.position
	keyboard_active = true


func move_selected(delta: Vector2) -> bool:
	if not _can_edit_selection():
		return false
	var group: Array = selected.filter(func(t): return is_instance_valid(t) and session.multiplayer_system._mine(t))
	if group.is_empty():
		return false
	var origins: Array[Vector2] = []
	for t in group:
		origins.append(t.position)
	delta = BinduPlacementPolicy.clamp_group_delta(origins, delta, session.combat_system.field_rect())
	for t in group:
		var occupied: Array[Vector2] = []
		for other in session.towers.get_children():
			if not other in group:
				occupied.append(other.position)
		var refusal := BinduPlacementPolicy.refusal(t.position + delta, session.viewport_system.core(), occupied, BinduSession.MERGE_DIST)
		if refusal != "":
			session.hud_system._show_toast(refusal)
			return false
	_history_begin("오브젝트 이동")
	for t in group:
		t.position += delta
		t.queue_redraw()
	session.persistence_system._save_run()
	_history_finish()
	return true


func rotate_selected(radians: float) -> void:
	if not _can_edit_selection():
		return
	var group: Array = selected.filter(func(t): return is_instance_valid(t) and session.multiplayer_system._mine(t))
	if group.is_empty():
		return
	_history_begin("방향 회전")
	for t in group:
		t.set_attack_direction(t.dir.rotated(radians))
		t.queue_redraw()
	if session.tplay != null:
		session.tplay.flags["aimed"] = true
	session.persistence_system._save_run()
	_history_finish()


func drag_preview() -> Dictionary:
	return {"active":dragging, "valid":drag_refusal == "", "reason":drag_refusal, "invalid":drag_invalid.duplicate(), "targets":drag_group.duplicate()}


func _keyboard_input(event: InputEventKey) -> bool:
	if session.title_label.visible or session.get_tree().paused or _reading_modal_open() or session.perk_mode:
		return false
	if event.keycode == KEY_TAB:
		cycle_selection(event.shift_pressed)
		return true
	if event.keycode == KEY_E and _can_edit_selection() and not selected.is_empty():
		_edit_selected_direction()
		return true
	if event.keycode in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT] and _can_edit_selection():
		rotate_selected(deg_to_rad((-1.0 if event.keycode == KEY_BRACKETLEFT else 1.0) * (5.0 if event.shift_pressed else 15.0)))
		return true
	if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var step := Vector2(-1 if event.keycode == KEY_LEFT else (1 if event.keycode == KEY_RIGHT else 0), -1 if event.keycode == KEY_UP else (1 if event.keycode == KEY_DOWN else 0)) * (2.0 if event.shift_pressed else 12.0)
		if session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.AIM, BinduSession.Phase.MOVE]:
			if not keyboard_active:
				pointer_position = session.get_canvas_transform() * (session.place_pos if session.phase == BinduSession.Phase.AIM else session.viewport_system.center())
			keyboard_active = true
			pointer_position = (pointer_position + step).clamp(Vector2(1, 1), session.get_viewport_rect().size - Vector2(1, 1))
			if session.phase == BinduSession.Phase.AIM:
				var d := _pointer_world() - session.place_pos
				if d.length() > 0.1:
					session.aim_d = d.normalized()
					session.aim_wait = true
			return true
		if _can_edit_selection() and not selected.is_empty():
			move_selected(session.get_canvas_transform().basis_xform_inv(step))
			return true
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if session.phase == BinduSession.Phase.PLACE:
			if not keyboard_active:
				pointer_position = session.get_canvas_transform() * (session.viewport_system.core() + Vector2(140, 0))
			keyboard_active = true
			_place_card_at(_pointer_world(), true)
			return true
		if session.phase == BinduSession.Phase.AIM:
			_confirm_aim()
			return true
	return false

func _zoom_input(event: InputEvent) -> bool:
	var session: BinduSession = self.session
	if _reading_modal_open():
		return false
	if session.card_dock != null and session.card_dock.active():
		if event is InputEventMouseButton and session.card_dock.over_ui(event.position):
			if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
				mid_drag = false
			return false
		if event is InputEventScreenTouch and event.pressed and session.card_dock.over_ui(event.position):
			return false
	if session.title_label == null or session.title_label.visible or session.phase == BinduSession.Phase.GAMEOVER:
		touches.clear()
		pinch_lock = false
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		if touches.size() >= 2:
			if not pinch_lock:
				pinch_lock = true
				_abort_touch_action()  # 첫 손가락이 시작한 놓기·끌기·그리기를 거둔다
			var ps: Array = touches.values()
			pinch_d = maxf((ps[0] as Vector2).distance_to(ps[1]), 1.0)
			pinch_z = session.view_zoom
		elif touches.is_empty():
			var was := pinch_lock
			pinch_lock = false
			return was  # 마지막 손가락을 뗀 것도 누르기로 치지 않는다
		return pinch_lock
	if event is InputEventScreenDrag:
		if not touches.has(event.index):
			return pinch_lock
		var prev: Vector2 = touches[event.index]
		touches[event.index] = event.position
		if touches.size() >= 2 and pinch_lock:
			var ps: Array = touches.values()
			var d := maxf((ps[0] as Vector2).distance_to(ps[1]), 1.0)
			var mid: Vector2 = ((ps[0] as Vector2) + (ps[1] as Vector2)) / 2.0
			session.viewport_system._zoom_to(pinch_z * d / pinch_d, mid)
			session.viewport_system._pan_by((event.position - prev) / 2.0)  # 두 손가락의 가운데가 움직인 만큼
			return true
		return pinch_lock
	if pinch_lock and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return true  # 손가락에서 흉내 낸 마우스
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			mid_drag = event.pressed and session.view_zoom > 1.0
			return mid_drag or not event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not _over_scroll_ui(event.position):
			if _wheel_turn(event):
				return true
			session.viewport_system._zoom_to(session.view_zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), event.position)
			return true
	if event is InputEventMouseMotion and mid_drag:
		session.viewport_system._pan_by(event.relative)
		return true
	return false


## Alt+휠만 선택 방향 회전. 일반 휠은 선택 여부와 관계없이 확대다.
func _wheel_turn(event: InputEventMouseButton) -> bool:
	var session: BinduSession = self.session
	if not event.alt_pressed or session.touch_ui or session.perk_mode or session.get_tree().paused or not session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] or press_t or boxing:
		return false
	if session.settings_panel.visible or session.notes_panel.visible or session.codex_panel.visible or session.vote_panel.visible or session.records_panel.visible or session.help_label.visible:
		return false
	var t := _tower_at(session.get_canvas_transform().affine_inverse() * event.position)
	if t == null or not session.multiplayer_system._mine(t) or not t in selected:
		return false
	wheel_acc += event.factor if event.factor > 0.0 else 1.0
	if wheel_acc < 1.0:
		return true
	wheel_acc = 0.0
	var step := deg_to_rad(5.0 if Input.is_key_pressed(KEY_SHIFT) else 15.0)
	rotate_selected(-step if event.button_index == MOUSE_BUTTON_WHEEL_UP else step)
	session.sfx.play("place")
	return true


## 휠을 굴릴 창(도감·패치노트·도움말·DPS 표 등)이 마우스 아래 있으면 확대하지 않는다.
func _over_scroll_ui(p: Vector2) -> bool:
	var session: BinduSession = self.session
	var h := session.get_viewport().gui_get_hovered_control() if session.get_viewport().has_method("gui_get_hovered_control") else null
	if h != null and h != session.ui_root and h != session.info:
		return true
	return session.settings_panel.visible or session.notes_panel.visible or session.help_label.visible or session.records_panel.visible or session.codex_panel.visible or session.vote_panel.visible or session.get_tree().paused


## 두 번째 손가락이 닿으면: 첫 손가락으로 시작한 누르기·끌기·그리기·상자 선택을 없던 일로.
func _abort_touch_action() -> void:
	if press_t:
		_drop_press()
		_restore_hint()
	boxing = false
	aim_hold = false
	if dragging and moving:
		_cancel_step()


## OS 포인터를 조회하지 않고 입력 이벤트의 화면 좌표를 현재 카메라로 변환한다.
var pointer_position := Vector2.ZERO


func _pointer_screen() -> Vector2:
	return pointer_position


func _pointer_world() -> Vector2:
	var session: BinduSession = self.session
	return session.get_canvas_transform().affine_inverse() * pointer_position


## 터치에서 흉내 낸 마우스는 장치 번호 EMULATION으로 구분한다.
func _input(event: InputEvent) -> void:
	var session: BinduSession = self.session
	var was_touch := session.touch_ui
	if event is InputEventMouse:
		pointer_position = event.position
		keyboard_active = false
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer_position = event.position
		keyboard_active = false
		session.touch_ui = true
		session.touch_tip_t = BinduSession.TOUCH_TIP_SEC
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		session.touch_ui = false
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		session.onboarding_system.suppress_guide_for_object(event.position)
	if session.touch_ui != was_touch:
		session.get_tree().call_group("keycap", "queue_redraw")
		if session.legend:
			session.menu_system._refresh_legend()
	if session.dps_panel != null and ((event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed):
		session.dps_panel.press_check(event.position)
		if session.card_dock != null:
			session.card_dock.side.press_check(event.position)
	if session.mp_mode != "" and ((event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.pressed):
		session.lobby_system._mp_presence()
	if _info_input(event) or (session.card_dock != null and session.card_dock.handle_input(event)) or _zoom_input(event):
		session.get_viewport().set_input_as_handled()


func _info_tip_at(screen: Vector2) -> int:
	var session: BinduSession = self.session
	if session.hud.is_visible_in_tree() and session.hud.get_global_rect().has_point(screen) and session.card_dock._tower_under(screen):
		return -1
	var at := session.ui_root.get_global_transform().affine_inverse() * screen
	for i in range(session.tip_rects.size() - 1, -1, -1):
		if session.tip_rects[i][0].has_point(at):
			return i
	return -1


## 원래 터치와 흉내 낸 마우스의 누름/뗌을 각각 소비해 뒤 전장으로 넘기지 않는다.
func _info_input(event: InputEvent) -> bool:
	var session: BinduSession = self.session
	if session.card_dock == null or session.card_dock.input_blocked():
		info_mouse_capture = false
		info_touch_capture = -1
		return false
	if event is InputEventMouseMotion and info_mouse_capture:
		return true
	if event is InputEventScreenDrag and event.index == info_touch_capture:
		return true
	var mouse: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch
	if mouse and not event.pressed and info_mouse_capture:
		info_mouse_capture = false
		return true
	if touch and not event.pressed and event.index == info_touch_capture:
		info_touch_capture = -1
		return true
	if not (mouse or touch) or not event.pressed:
		return false
	var at: Vector2 = (event as InputEventScreenTouch).position if touch else (event as InputEventMouseButton).position
	var was := session.tip_pin
	if touch:
		session.tip_pin = -1
	if session.card_dock.over_ui(at, false):
		return false
	var hit := _info_tip_at(at)
	if hit < 0:
		return false
	_abort_touch_action()
	if touch:
		info_touch_capture = event.index
		session.tip_pin = -1 if was == hit else hit
	else:
		info_mouse_capture = true
	return true


func _unhandled_input(event: InputEvent) -> void:
	var session: BinduSession = self.session
	# 터치의 carried-card drop은 원래 ScreenTouch 경로 하나가 처리한다.
	# 일부 플랫폼의 emulated MousePress가 먼저 와도 같은 손가락으로 Tower 이동까지 시작하지 않는다.
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION and session.phase == BinduSession.Phase.PLACE and session.card_dock.carrying():
		return
	# 글 입력 칸(닉네임)에 쓰는 중엔 단축키를 막는다. 한글 조합 중 키는 입력 칸이 받지 않고 넘겨서
	# ㅐ(O)·ㅔ(P)·ㅡ(M) 같은 글자가 설정 닫기·일시정지·소리 끄기로 먹혔다. Esc는 그대로 창을 닫는다.
	if event is InputEventKey and session.get_viewport().gui_get_focus_owner() is LineEdit and event.keycode != KEY_ESCAPE:
		return
	if event is InputEventKey and event.pressed and event.echo:
		if not event.ctrl_pressed and not event.meta_pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			_keyboard_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# 수정키 조합은 plain 게임 단축키로 해석하지 않는다.
		if event.ctrl_pressed or event.meta_pressed:
			if not _reading_modal_open() and not session.get_tree().paused:
				if event.keycode == KEY_Z and session.cards_system.has_method("undo_edit"):
					session.cards_system.call("undo_edit")
				elif event.keycode == KEY_A:
					select_all()
			return
		# 읽기 창이 입력을 소유한다. 시뮬레이션 정지와 게임 명령 차단은 별개다.
		if _reading_modal_open():
			if event.keycode == KEY_ESCAPE:
				if session.menu_system.sound_pop.visible:
					session.menu_system._close_sound_pop()
				elif session.notes_panel.visible:
					session.patchlog_system._close_notes()
				elif session.tut != null and session.tut.visible:
					session.tut.close()
				else:
					session.settings_panel.hide()
					session.help_label.hide()
					session.records_panel.hide()
					session.modes_panel.hide()
					session.codex_panel.hide()
					if session.vote_panel.visible:
						session.vote_panel.hide_panel()
			elif event.keycode == KEY_O and session.settings_panel.visible:
				session.menu_system._toggle_settings()
			elif event.keycode == KEY_H and session.help_label.visible:
				session.help_label.hide()
			elif event.keycode == KEY_N and session.notes_panel.visible:
				session.patchlog_system._close_notes()
			elif event.keycode == KEY_M:
				session.cards_system._toggle_mute()
			elif event.keycode == KEY_F11:
				session.menu_system._toggle_fullscreen()
			return
		if _keyboard_input(event):
			return
		if session.coin_stage > 0 and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3]:
			session.perks_system._coin_tap()
			return
		if event.keycode == KEY_O:
			session.menu_system._toggle_settings()
			return
		if event.keycode == KEY_N and (session.title_label.visible or session.settings_panel.visible or session.notes_panel.visible):
			session.patchlog_system._toggle_notes()
			return
		if event.keycode == KEY_ESCAPE and session.menu_system.sound_pop.visible:
			session.menu_system._close_sound_pop()
			return
		if event.keycode == KEY_ESCAPE and session.notes_panel.visible:
			session.patchlog_system._close_notes()
			return
		if event.keycode == KEY_ESCAPE and (session.settings_panel.visible or session.records_panel.visible or session.help_label.visible or session.modes_panel.visible or session.codex_panel.visible or session.vote_panel.visible):
			session.settings_panel.visible = false
			session.codex_panel.visible = false
			if session.vote_panel.visible:
				session.vote_panel.hide_panel()
			session.modes_panel.visible = false
			session.records_panel.visible = false
			session.help_label.visible = false
			return
		if session.title_label.visible:
			match event.keycode:
				KEY_H:
					if session.help_label.visible:
						session.help_label.visible = false
					else:
						session.onboarding_system._open_tut_list()
				KEY_K:
					session.menu_system._toggle_codex()
				KEY_V:
					if session.vote_btn and session.vote_btn.visible:
						session.menu_system._toggle_vote()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					if session.prep:
						session.progression_system._close_title()
					elif session.continue_btn.visible:
						session.persistence_system._continue_run()
					else:
						session.menu_system._set_prep(true)
				KEY_ESCAPE:
					if session.prep:
						session.menu_system._set_prep(false)
				KEY_LEFT:
					if session.prep:
						session.menu_system._cycle_map(-1)
				KEY_RIGHT:
					if session.prep:
						session.menu_system._cycle_map(1)
				KEY_F:
					if session.prep:
						session.menu_system._toggle_flip()
				KEY_UP:
					if session.prep and Meta.games > 0:
						session.menu_system._cycle_rules(-1)
				KEY_DOWN:
					if session.prep and Meta.games > 0:
						session.menu_system._cycle_rules(1)
				KEY_F11:
					session.menu_system._toggle_fullscreen()
				KEY_M:
					session.cards_system._toggle_mute()  # 시작 화면에도 소리 버튼이 보인다
			return
		if session.get_tree().paused and event.keycode not in [KEY_ESCAPE, KEY_P, KEY_R, KEY_E, KEY_T, KEY_X, KEY_H, KEY_M, KEY_D, KEY_F11]:
			return
		if session.run_detail.visible and event.keycode in [KEY_ESCAPE, KEY_R]:
			session.run_detail.close()  # 결과 상세 먼저 닫고, 한 번 더 누르면 시작 화면
			return
		if event.keycode == KEY_ESCAPE and session.phase == BinduSession.Phase.GAMEOVER:
			if Time.get_ticks_msec() - session.over_ms > 800:
				BinduSession.title_seen = false
				session.run_flow_system._reload()
			return
		if event.keycode == KEY_F11:
			session.menu_system._toggle_fullscreen()
		elif event.keycode == KEY_F:
			session.cards_system._toggle_focus_view()
		elif event.keycode == KEY_R and session.get_tree().paused:
			session.run_flow_system._pause_restart()
		elif event.keycode == KEY_E and session.get_tree().paused:
			session.run_flow_system._end_run()
		elif event.keycode == KEY_T and session.get_tree().paused:
			session.run_flow_system._leave(false)
		elif event.keycode == KEY_X and session.get_tree().paused and OS.has_feature("pc"):
			session.run_flow_system._leave(true)
		elif event.keycode in [KEY_1, KEY_2, KEY_KP_1, KEY_KP_2] and session.phase == BinduSession.Phase.WAVE and not session.skill_ids.is_empty():
			session.abilities_system._arm_skill(event.keycode - (KEY_KP_1 if event.keycode >= KEY_KP_1 else KEY_1))
		elif event.keycode == KEY_ESCAPE and session.phase == BinduSession.Phase.WAVE:
			session.run_flow_system._toggle_pause()
		elif event.keycode == KEY_ESCAPE and session.skill_arm != "":
			session.skill_arm = ""
		elif event.keycode == KEY_H:
			session.help_label.visible = not session.help_label.visible
		elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4] and session.phase == BinduSession.Phase.CHOOSE and session.help_label.visible == false and not session.get_tree().paused:
			var i: int = event.keycode - (KEY_KP_1 if event.keycode >= KEY_KP_1 else KEY_1)
			if session.perk_mode:
				if i < session.perk_offer.size():
					session.perks_system._on_perk(session.perk_offer[i])
			elif i < session.offer.size():
				keyboard_active = false
				session.cards_system._on_pick(session.offer[i])
		elif event.keycode == KEY_Q and session.phase == BinduSession.Phase.CHOOSE:
			session.cards_system._on_reroll()
		elif event.keycode == KEY_S and not event.ctrl_pressed and not event.meta_pressed and not session.title_label.visible:
			if session.skip_left > 0:
				session.run_flow_system._toggle_skip_stop()
			elif session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY]:
				session.run_flow_system._on_skip()
		elif event.keycode == KEY_V and session.phase == BinduSession.Phase.CHOOSE:
			session.cards_system._toggle_cards_hidden()
		elif event.keycode == KEY_Z and not session.perk_mode:
			if session.phase == BinduSession.Phase.CHOOSE:
				session.cards_system._set_card_detail(not Meta.card_detail)
			elif session.phase in [BinduSession.Phase.READY, BinduSession.Phase.WAVE]:
				session.card_dock.inspector_dismissed = false
				if not selected.is_empty():
					_select_tower(selected[0])
		elif event.keycode == KEY_D and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY, BinduSession.Phase.WAVE]:
			session.hud_system._toggle_dps()
		elif event.keycode == KEY_A and (event.ctrl_pressed or event.meta_pressed) and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] and not session.perk_mode:
			# 모두 선택: 한꺼번에 옮길 때
			selected = session.multiplayer_system._my_towers()
			_restore_hint()
		elif event.keycode == KEY_R and session.phase == BinduSession.Phase.GAMEOVER:
			if Time.get_ticks_msec() - session.over_ms > 800:
				BinduSession.title_seen = false
				session.run_flow_system._reload()
		elif event.keycode == KEY_M:
			session.cards_system._toggle_mute()
		elif event.keycode == KEY_SPACE and session.phase == BinduSession.Phase.READY:
			session.run_flow_system._start_wave()
		elif event.keycode == KEY_SPACE and session.phase == BinduSession.Phase.WAVE:
			session.run_flow_system._toggle_speed(true)
		elif event.keycode == KEY_SPACE and session.phase == BinduSession.Phase.CHOOSE:
			session.hud_system._show_toast(("특성을" if session.perk_mode else "선택지를") + " 먼저 고르세요 (1·2·3 또는 클릭)")
		elif event.keycode == KEY_ESCAPE and not session.get_tree().paused and (session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.AIM, BinduSession.Phase.MOVE] or press_t or boxing or (not selected.is_empty() and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY])):
			_cancel_step()
		elif event.keycode == KEY_ESCAPE and not session.get_tree().paused and session.card_dock.side.visible:
			session.card_dock.close_inspector()
			_restore_hint()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			session.run_flow_system._toggle_pause()
	if session.get_tree().paused:
		return
	if event is InputEventMouseButton and not session.card_dock.input_blocked() and session.card_dock.over_ui(event.position):
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drop_press()
			boxing = false
			aim_hold = false
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and aim_right:
		aim_right = false
		if session.phase == BinduSession.Phase.AIM:
			if _pointer_world().distance_to(session.place_pos) > 30.0:
				_confirm_aim()
			else:
				_cancel_step()  # 거의 안 끌고 뗀 우클릭: 그대로 둔다
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if press_t:
			_release_press()
			return
		if boxing:
			_finish_box()
			return
		if session.phase == BinduSession.Phase.AIM and session.touch_ui and aim_hold:
			_aim_release()
			return
		# 누른 채 끌어서 놓으면 그 방향으로 바로 확정
		if session.phase == BinduSession.Phase.AIM and _pointer_world().distance_to(session.place_pos) > 40.0 and Time.get_ticks_msec() - aim_start_ms > 150:
			_confirm_aim()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	# 휠은 클릭이 아니다: 도감·패치노트는 끝까지 굴린 뒤의 휠이 여기로 넘어와 창이 닫혔다
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and (press_t or boxing):
		_cancel_step()
		return
	# 오브젝트를 우클릭한 채 끌기: 그 자리에서 방향만 바꾸고, 떼면 확정
	if event.button_index == MOUSE_BUTTON_RIGHT and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] and not session.perk_mode and not session.title_label.visible \
			and not (session.settings_panel.visible or session.notes_panel.visible or session.codex_panel.visible or session.vote_panel.visible or session.records_panel.visible or session.help_label.visible):
		var rt := _tower_at(_pointer_world())
		if rt and session.multiplayer_system._mine(rt):
			_start_move(rt)
			aim_right = session.phase == BinduSession.Phase.AIM
			return
	# 선택 해제보다 오브젝트 우클릭 조준을 먼저 처리한다. 빈 곳 우클릭은 선택 해제.
	if event.button_index == MOUSE_BUTTON_RIGHT and not selected.is_empty() and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY]:
		_cancel_step()
		return
	if session.notes_panel.visible:
		session.patchlog_system._close_notes()
		return
	if session.codex_panel.visible:
		session.codex_panel.visible = false
		return
	if session.vote_panel.visible:
		session.vote_panel.hide_panel()
		return
	if session.records_panel.visible:
		session.records_panel.visible = false
		return
	if session.help_label.visible:
		session.help_label.visible = false
		return
	if session.title_label.visible or session.settings_panel.visible:
		return
	if session.phase == BinduSession.Phase.GAMEOVER and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() - session.over_ms > 800:
			BinduSession.title_seen = false
			session.run_flow_system._reload()
		return
	if session.card_dock != null and session.card_dock.over_ui(event.position):
		return
	var mpos := _pointer_world()
	if event.button_index == MOUSE_BUTTON_LEFT and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY, BinduSession.Phase.WAVE] and _tower_at(mpos) == null:
		session.card_dock.inspected_tower = null
		session.tip_tower = null
		if not (additive_selection or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)):
			selected.clear()
	if session.perk_mode:
		return
	if session.phase == BinduSession.Phase.WAVE and session.skill_arm != "":
		if event.button_index == MOUSE_BUTTON_LEFT:
			session.abilities_system._use_skill(session.skill_arm, mpos)
		else:
			session.skill_arm = ""
		return
	if session.phase == BinduSession.Phase.WAVE and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tower_at(mpos)
		if t:
			_select_tower(t)
		elif session.field_view_system.has_method("pin_orb_at"):
			if session.field_view_system.call("pin_orb_at", mpos):
				session.card_dock.close_inspector()
			elif session.field_view_system.has_method("clear_orb_pin"):
				session.field_view_system.call("clear_orb_pin")
		return
	if session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tower_at(mpos)
		if t:
			# 짧게 클릭: 선택, Shift/Ctrl+클릭: 선택에 더하기·빼기, 끌기: 바로 이동
			_begin_press(t, mpos)
		else:
			# 빈 곳을 끌면 선택 상자
			boxing = true
			box_start = mpos
		return
	if session.phase == BinduSession.Phase.MOVE:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mpos = mpos.clamp(session.combat_system.field_rect().position, session.combat_system.field_rect().end)
			if mpos.distance_to(session.viewport_system.core()) < 50.0:
				session.hud_system._show_toast("중앙 점에 너무 가까워요")
				return
			var other := _tower_at(mpos, moving)
			if other:
				session.hud_system._show_toast("다른 오브젝트와 겹칠 수 없어요")
				return
			session.place_pos = mpos
			moving.position = mpos
			session.phase = BinduSession.Phase.AIM
			aim_start_ms = Time.get_ticks_msec()
			_aim_begin()
			session.hint.text = session.ui_layout_system._th("클릭 또는 끌어서 놓기: 방향 확정 (Shift: 15도 단위) (색칠된 곳이 공격 범위)\n우클릭/Esc: 옮기기 취소")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_step()
		return
	if session.phase == BinduSession.Phase.PLACE and event.button_index == MOUSE_BUTTON_LEFT:
		_place_card_at(mpos)
	elif session.phase == BinduSession.Phase.AIM:
		if event.button_index == MOUSE_BUTTON_LEFT and session.touch_ui:
			aim_hold = true  # 터치: 누르는 동안 손가락을 따라 범위를 보여 주고, 떼면 [확정]을 기다린다
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# 오브젝트 바로 위를 누르면 손을 뗄 때 정한다 (그 자리에서 바깥으로 끌어 조준)
			if mpos.distance_to(session.place_pos) >= BinduSession.MERGE_DIST:
				_confirm_aim()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not aim_right:
			_cancel_step()
	elif session.phase == BinduSession.Phase.PLACE and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_step()


## 드롭은 손을 뗀 화면 좌표로 판정한다. 패널·창 밖·무효 대상에서는 카드를 소비하지 않는다.
func _drop_carried_card(screen: Vector2) -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.PLACE or session.picked.is_empty() or not session.get_viewport_rect().has_point(screen) or session.card_dock.input_blocked() or session.card_dock.over_ui(screen):
		return
	var world := session.get_canvas_transform().affine_inverse() * screen
	_place_card_at(world, true)


func _place_card_at(mpos: Vector2, direct := false) -> void:
	var session: BinduSession = self.session
	if _gift_blocked(): return
	var target := _tower_at(mpos)
	if TutPlay.on and session.tplay != null and not session.tplay.allow_place(target):
		return
	if target and not _place_ok(target):
		# 넣을 수 없는 오브젝트는 흐리게 그리고 누르거나 끌 수 없다 (이유만 알림)
		session.hud_system._show_toast(_place_refuse(target))
		return
	if target:
		# 클릭은 손을 뗄 때 처리한다. 꾹 누르거나 끌면 카드를 유지한 채 옮긴다.
		if direct:
			_place_on(target)
		else:
			_begin_press(target, mpos)
		return
	if not session.combat_system.field_rect().has_point(mpos):
		session.hud_system._show_toast("전장 안에 놓으세요")
		return
	if mpos.distance_to(session.viewport_system.core()) < 50.0:
		session.hud_system._show_toast("중앙 점에 너무 가까워요")
		return
	if session.picked["type"] != "elem":
		session.cards_system._apply_card(target)
		return
	elif session.picked["e"] == Elem.STAR and session.cards_system.star_full():
		session.hud_system._show_toast(Tower.star_full_text())
		return
	else:
		session.place_pos = mpos
		# 일반 판 기본 자동 조준은 기본 방향으로 설치한다. 방향 학습 연습 판은 유지한다.
		if Rules.t("auto_aim") > 0.0 and not TutPlay.on:
			_history_begin("새 오브젝트 설치")
			var d := (mpos - session.viewport_system.core()).normalized()
			_place_tower(mpos, d if d != Vector2.ZERO else Vector2.RIGHT)
			session.sfx.play("place")
			session.cards_system._after_place()
			_history_finish()
			return
		session.phase = BinduSession.Phase.AIM
		aim_start_ms = Time.get_ticks_msec()
		_aim_begin()
		aim_hold = session.touch_ui and not direct  # 놓은 손가락 그대로 끌어 방향을 볼 수 있다
		if session.touch_ui:
			session.hint.text = session.ui_layout_system._th(BinduSession.AIM_TOUCH_HINT + "   취소: 위치 다시 정하기")
		else:
			session.hint.text = session.ui_layout_system._th("클릭 또는 끌어서 놓기: 발사 방향 확정 (Shift: 15도 단위) (색칠된 곳이 공격 범위)\n우클릭/Esc: 위치 다시 정하기")

## 카드 선택 막을 깔지: 선택지 카드가 펼쳐져 있을 때만 (일시정지 어둠이 있으면 그것만).
func _card_dim_on() -> bool:
	var session: BinduSession = self.session
	if session.card_dock != null and session.card_dock.active():
		return false
	return session.phase == BinduSession.Phase.CHOOSE and session.choice_box.visible and not session.cards_hidden and session.choice_box.get_child_count() > 0 \
		and not session.title_label.visible and not session.get_tree().paused


## 지금 고른 카드를 이 오브젝트에 넣을 수 있는지 (속성 종류·강화 종류별 상한·Pat.NO_MOD·별 상한·친구 오브젝트).
func _place_ok(t: Tower) -> bool:
	var session: BinduSession = self.session
	if session.picked.is_empty() or not is_instance_valid(t):
		return false
	return (session.multiplayer_system._mine(t) or session.lobby_system._req_ok(t)) and t.can_take(session.picked)


## 넣을 수 없는 이유 (_place_ok가 false일 때).
func _place_refuse(t: Tower) -> String:
	var session: BinduSession = self.session
	if not session.multiplayer_system._mine(t) and not session.lobby_system._req_ok(t):
		return str(session.multiplayer_system.gifts().offer_status(t, session.picked).reason)
	return t.refuse_text(session.picked)


## 카드를 놓는 중(PLACE): 넣을 수 없는 오브젝트는 흐리게. 다른 단계에서는 원래대로.
func _update_place_dim() -> void:
	var session: BinduSession = self.session
	var on := session.phase == BinduSession.Phase.PLACE and not session.picked.is_empty()
	for t in session.towers.get_children():
		var c := Color.WHITE
		if on and not _place_ok(t):
			c = BinduSession.PLACE_OFF
		if t.modulate != c:
			t.modulate = c


## 고른 카드를 오브젝트에 넣는다 (PLACE에서 오브젝트를 짧게 클릭).
func _place_on(target: Tower) -> void:
	var session: BinduSession = self.session
	if _gift_blocked(): return
	if not session.multiplayer_system._mine(target):
		if session.lobby_system._req_ok(target) and target.can_take(session.picked):
			session.lobby_system._mp_give(target)  # 협동: 친구가 요청한 속성
		else:
			session.hud_system._show_toast(_place_refuse(target))
		return
	if session.picked["type"] != "elem":
		session.cards_system._apply_card(target)
		return
	if not target.can_take(session.picked):
		session.hud_system._show_toast(target.refuse_text(session.picked))
		return
	_history_begin("속성 카드 적용")
	var msg: String = target.add(session.picked["e"], session.picked["lv"])
	if target.hero and Hero.gain(target, "card", Hero.XP_CARD) > 0:
		session.hud_system._show_toast("영웅 Lv%d!" % target.hero_lv)
	session.sfx.play("place")
	if msg.begins_with("조합"):
		session.sfx.play("reaction", 0.0)
		session.spawning_system.burst(target.position, Color(1, 0.85, 0.4), 30, 260.0)
	else:
		session.hud_system._show_toast(msg)
	session.cards_system._after_place()
	_history_finish()


func _begin_press(t: Tower, mpos: Vector2) -> void:
	var session: BinduSession = self.session
	if session.multiplayer_system.gifts().blocks_local_choice():
		_select_tower(t)
		return
	if session.mp_req_mode and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY]:
		if session.multiplayer_system._mine(t):
			session.lobby_system._mp_req_open(t)
		else:
			session.hud_system._show_toast("내 오브젝트를 누르세요")
		return
	if not session.multiplayer_system._mine(t):
		if session.phase == BinduSession.Phase.PLACE and session.lobby_system._req_ok(t):
			_place_on(t)  # 요청한 속성을 넣어 주기 (옮기지는 못함)
			return
		if session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY]:
			if additive_selection:
				session.hud_system._show_toast("여러 개 선택에는 내 오브젝트만 더할 수 있어요")
			else:
				_select_tower(t)
		else:
			session.hud_system._show_toast("친구가 놓은 오브젝트는 바꿀 수 없어요")
		return
	press_t = t
	press_pos = mpos
	press_ms = Time.get_ticks_msec()
	dragging = false


## 이동은 화면상 충분히 움직였을 때만 시작한다. 정지한 길게 누르기는 정보 읽기다.
func _update_press() -> void:
	var session: BinduSession = self.session
	if not press_t:
		return
	if session.card_dock.input_blocked() or not session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] or not is_instance_valid(press_t) or not session.multiplayer_system._mine(press_t):
		_drop_press()
		return
	var mpos := _pointer_world()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_press()
		return
	var screen_delta := session.get_canvas_transform().basis_xform(mpos - press_pos)
	if not dragging and screen_delta.length() > (16.0 if session.touch_ui else 12.0):
		_history_begin("오브젝트 이동")
		dragging = true
		drag_group = selected.filter(func(t): return is_instance_valid(t) and session.multiplayer_system._mine(t)) if press_t in selected else [press_t]
		drag_origs = drag_group.map(func(t): return t.position)
		for t in drag_group:
			t.place_pop = 1.0
		session.hint.text = session.ui_layout_system._th("끌어서 옮기는 중%s: 놓으면 그 자리에 둠 (방향은 그대로)\n우클릭/Esc: 취소" % (" (%d개)" % drag_group.size() if drag_group.size() > 1 else ""))
	if dragging:
		# 창 밖으로 끌어도 무리 전체가 화면 안에 남도록 이동량을 자른다
		var delta := mpos - press_pos
		var f := session.combat_system.field_rect()
		var origins: Array[Vector2] = []
		for i in drag_group.size():
			if is_instance_valid(drag_group[i]):
				origins.append(drag_origs[i])
		delta = BinduPlacementPolicy.clamp_group_delta(origins, delta, f)
		for i in drag_group.size():
			if is_instance_valid(drag_group[i]):
				drag_group[i].position = drag_origs[i] + delta
				drag_group[i].queue_redraw()
		drag_refusal = ""
		drag_invalid.clear()
		for t in drag_group:
			if is_instance_valid(t):
				var refusal := _bad_spot(t, drag_group)
				if refusal != "":
					drag_invalid.append(t)
					if drag_refusal == "":
						drag_refusal = refusal


## 누른 오브젝트에서 손을 뗐을 때: 끌었으면 그 자리에 두고, 짧은 클릭이면 원래 클릭 동작.
func _release_press() -> void:
	var session: BinduSession = self.session
	if session.card_dock.input_blocked() or session.card_dock.over_ui(_pointer_screen()):
		_drop_press()
		_restore_hint()
		return
	var t := press_t
	press_t = null
	if not is_instance_valid(t) or not session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.CHOOSE, BinduSession.Phase.READY]:
		_drop_press()
		return
	if not dragging:
		if session.phase == BinduSession.Phase.PLACE:
			_place_on(t)
		elif additive_selection or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
			if t in selected:
				selected.erase(t)
			else:
				selected.append(t)
			session.card_dock.inspector_dismissed = false
			session.card_dock.inspected_tower = selected[0] if not selected.is_empty() else null
			_restore_hint()
		else:
			_select_tower(t)
		return
	dragging = false
	# 놓을 수 없는 자리가 하나라도 있으면 모두 원래 자리로
	var bad := ""
	for o in drag_group:
		if is_instance_valid(o) and bad == "":
			bad = _bad_spot(o, drag_group)
	if bad != "":
		session.hud_system._show_toast(bad)
		_revert_drag()
	elif drag_group[0].position.distance_to(drag_origs[0]) > 4.0:
		session.sfx.play("place")
	for o in drag_group:
		if is_instance_valid(o):
			o.place_pop = 1.0
			o.queue_redraw()
	if bad == "" and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY]:
		if drag_group.size() == 1:
			_select_tower(t)
		else:
			selected = drag_group.duplicate()
	drag_group.clear()
	drag_refusal = ""
	drag_invalid.clear()
	_restore_hint()
	session.persistence_system._save_run()
	_history_finish()


## 옮기는 자리에 놓을 수 없으면 그 이유 (movers: 함께 움직이는 것들끼리는 겹쳐도 됨).
func _bad_spot(o: Tower, movers: Array) -> String:
	var session: BinduSession = self.session
	var occupied: Array[Vector2] = []
	for other in session.towers.get_children():
		if not other in movers:
			occupied.append(other.position)
	return BinduPlacementPolicy.refusal(o.position, session.viewport_system.core(), occupied, BinduSession.MERGE_DIST)


func _revert_drag() -> void:
	for i in drag_group.size():
		if is_instance_valid(drag_group[i]):
			drag_group[i].position = drag_origs[i]
			drag_group[i].queue_redraw()


func _drop_press() -> void:
	var was_dragging := dragging
	if dragging:
		_revert_drag()
	press_t = null
	dragging = false
	drag_group.clear()
	drag_refusal = ""
	drag_invalid.clear()
	if was_dragging:
		_history_finish()


## 선택 상자를 놓았을 때: 상자 안 오브젝트 선택 (Shift/Ctrl: 기존 선택에 더함). 짧은 클릭이면 선택 해제.
func _finish_box() -> void:
	var session: BinduSession = self.session
	boxing = false
	if session.card_dock.input_blocked() or session.card_dock.over_ui(_pointer_screen()):
		_restore_hint()
		return
	var r := Rect2(box_start, _pointer_world() - box_start).abs()
	var add := additive_selection or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if not add:
		selected.clear()
	if r.size.length() > 8.0:
		for t in session.towers.get_children():
			if r.grow(Tower.RADIUS * 0.5).has_point(t.position) and not t in selected and session.multiplayer_system._mine(t):
				selected.append(t)
	_restore_hint()


func _select_tower(t: Tower) -> void:
	var session: BinduSession = self.session
	if session.field_view_system.has_method("clear_orb_pin"):
		session.field_view_system.call("clear_orb_pin")
	selected = [t] if session.multiplayer_system._mine(t) else []
	session.card_dock.inspector_dismissed = false
	session.card_dock.dismissed_tower = null
	session.card_dock.hovered = null
	session.card_dock.inspected_tower = t
	session.tip_tower = t
	session.card_dock.inspect_object(t)
	_restore_hint()


func _edit_selected_direction() -> void:
	var session: BinduSession = self.session
	var own: Array = selected.filter(func(t): return is_instance_valid(t) and session.multiplayer_system._mine(t))
	if _can_edit_selection() and not session.card_dock.input_blocked() and not own.is_empty():
		_start_move(own[0], own)


## 단계에 맞는 안내 문구로 되돌린다 (선택 중이면 선택 안내).
func _restore_hint() -> void:
	var session: BinduSession = self.session
	selected = selected.filter(func(t): return is_instance_valid(t))
	match session.phase:
		BinduSession.Phase.PLACE:
			session.hint.text = session.ui_layout_system._th(session.cards_system._place_hint())
		BinduSession.Phase.CHOOSE:
			session.hint.text = session.ui_layout_system._th(session.cards_system._choose_hint())
		BinduSession.Phase.READY:
			session.hint.text = session.ui_layout_system._th(BinduSession.READY_HINT if Meta.games < 3 else "")
	if not selected.is_empty() and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY, BinduSession.Phase.PLACE]:
		session.hint.text = ("선택 %d개: 선택한 오브젝트 하나를 끌면 함께 이동\n빈 곳 누르기: 선택 해제" if session.touch_ui else "선택 %d개: 선택한 오브젝트 하나를 끌면 함께 이동\nShift/Ctrl+클릭: 더하기·빼기   Ctrl+A: 모두   Esc/우클릭: 선택 해제") % selected.size()


## 조준 단계에 들어갈 때: 터치는 지금 방향(옮기는 오브젝트)을 붙잡아 두고 시작한다.
func _aim_begin() -> void:
	var session: BinduSession = self.session
	aim_hold = false
	session.aim_d = moving.dir.normalized() if moving else Vector2.ZERO
	session.aim_wait = session.aim_d != Vector2.ZERO


## 아래 [확정] 버튼: 터치 조준에서 방향을 붙잡아 뒀을 때.
func _ok_btn_on() -> bool:
	var session: BinduSession = self.session
	return session.phase == BinduSession.Phase.AIM and session.touch_ui and session.aim_wait


## 터치 조준에서 손가락을 뗄 때: 끌었던 방향을 붙잡아 두고 [확정]을 기다린다.
## 오브젝트를 짧게 다시 누르면(끌지 않고 떼면) 붙잡아 둔 방향으로 확정.
func _aim_release() -> void:
	var session: BinduSession = self.session
	aim_hold = false
	var d := _pointer_world() - session.place_pos
	if d.length() >= BinduSession.AIM_TOUCH_MIN:
		session.aim_d = d.normalized()
		session.aim_wait = true
	elif session.aim_wait and d.length() < BinduSession.MERGE_DIST:
		_confirm_aim()


## 방향 확정 (클릭, 또는 끌었다 놓기, 터치 [확정]).
func _confirm_aim() -> void:
	var session: BinduSession = self.session
	if _gift_blocked(): return
	var d := session.field_view_system._aim_dir(session.place_pos)
	if d == Vector2.ZERO:
		return
	if moving:
		if session.tplay != null:
			session.tplay.flags["aimed"] = true  # 튜토리얼 '보스 길 쪽으로 돌리기': 이미 그쪽이라 거의 안 돌아도 한 번 정하면 된다
		moving.position = session.place_pos
		if _direction_group.size() > 1:
			for t in _direction_group:
				if is_instance_valid(t) and session.multiplayer_system._mine(t):
					t.set_attack_direction(d)
					t.queue_redraw()
		else:
			moving.set_attack_direction(d)
		moving.place_pop = 1.0
		session.sfx.play("place")
		moving.queue_redraw()
		moving = null
		_end_move()
		return
	_place_tower(session.place_pos, d)

	session.sfx.play("place")
	session.cards_system._after_place()
	_history_finish()


## 메인 메뉴: 맵·스킨 선택, 시작, 기록·업적, 설정, 도움말.
func _cancel_step() -> void:
	var session: BinduSession = self.session
	if _gift_blocked(): return
	if press_t:
		_drop_press()
		_restore_hint()
		return
	if boxing:
		boxing = false
		return
	if not selected.is_empty() and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY]:
		session.card_dock.close_inspector()
		_restore_hint()
		return
	if moving:
		var t := moving
		var restore_selection := _move_selection.duplicate()
		moving.position = move_orig_pos
		moving.set_attack_direction(move_orig_dir)
		for i in _direction_group.size():
			if is_instance_valid(_direction_group[i]):
				_direction_group[i].set_attack_direction(_direction_origins[i])
				_direction_group[i].queue_redraw()
		moving.queue_redraw()
		moving = null
		_end_move()
		_select_tower(t)
		selected = restore_selection.filter(func(o): return is_instance_valid(o))
		_restore_hint()
		return
	if session.phase == BinduSession.Phase.AIM:
		session.phase = BinduSession.Phase.PLACE
		session.hint.text = session.ui_layout_system._th(BinduSession.PLACE_HINT)
	elif session.phase == BinduSession.Phase.PLACE:
		_back_to_choose()


## 선택지를 그대로 둔 채 오브젝트 고르기로 돌아간다.
func _back_to_choose() -> void:
	var session: BinduSession = self.session
	if _gift_blocked(): return
	session.card_dock.clear_gesture()
	session.cards_hidden = false
	session.tap_sel = session.offer.find(session.picked)
	for button: Button in session.choice_box.get_children():
		if button.get_meta("offer_card", {}) == session.picked:
			session.card_dock.hovered = button
	session.phase = BinduSession.Phase.CHOOSE
	session.cards_system._tap_hover()
	session.choice_box.visible = not session.cards_hidden
	session.cards_system._update_reroll_btn()
	session.hint.text = session.ui_layout_system._th(session.cards_system._choose_hint())
	session.persistence_system._save_run()
	_history_finish()


## 방향 바꾸기를 끝내고 원래 단계로.
func _end_move() -> void:
	var session: BinduSession = self.session
	session.card_dock.clear_gesture()
	session.card_dock.close_inspector()
	aim_right = false
	if move_return == BinduSession.Phase.READY:
		session.cards_system._enter_ready()
	else:
		session.phase = BinduSession.Phase.CHOOSE
		session.cards_system._set_cards_hidden(move_cards_hidden)
		_restore_hint()
		session.persistence_system._save_run()
	_direction_group.clear()
	_direction_origins.clear()
	_move_selection.clear()
	_history_finish()


## 선택한 오브젝트의 [방향 변경] 또는 우클릭 끌기로 제자리 방향을 편집한다.
func _start_move(t: Tower, group: Array = []) -> void:
	var session: BinduSession = self.session
	if _gift_blocked(): return
	_history_begin("방향 편집")
	_move_selection = selected.duplicate()
	_direction_group = group.duplicate() if not group.is_empty() else [t]
	_direction_origins = _direction_group.map(func(o): return o.dir)
	move_cards_hidden = session.cards_hidden
	move_return = session.phase
	session.start_btn.visible = false
	moving = t
	move_orig_pos = t.position
	move_orig_dir = t.dir
	session.place_pos = t.position
	session.phase = BinduSession.Phase.AIM
	keyboard_active = false  # 첫 방향키는 이전 선택·이동 포인터 대신 이 오브젝트 자리에서 시작한다.
	aim_start_ms = Time.get_ticks_msec()
	_aim_begin()
	session.choice_box.visible = false
	session.reroll_btn.visible = false
	if session.touch_ui:
		session.hint.text = session.ui_layout_system._th(BinduSession.AIM_TOUCH_HINT + "   취소: 그대로 두기")
	else:
		session.hint.text = session.ui_layout_system._th("클릭 또는 끌어서 놓기: 방향 확정 (Shift: 15도 단위)   오브젝트 우클릭한 채 끌기로도 바로 됨\n우클릭/Esc: 그대로 두기")


func _tower_at(p: Vector2, except: Tower = null) -> Tower:
	var session: BinduSession = self.session
	var canvas := session.get_canvas_transform()
	var at := canvas * p
	var radius := maxf(30.0 if session.touch_ui else 22.0, Tower.RADIUS * canvas.get_scale().length() / sqrt(2.0) + 8.0)
	var nearest: Tower = null
	var distance := INF
	for t in session.towers.get_children():
		if t == except or t.is_queued_for_deletion():
			continue
		var d: float = (canvas * t.position).distance_to(at)
		if d > radius:
			continue
		var tie_preferred: bool = nearest == null or t.position.x < nearest.position.x or (is_equal_approx(t.position.x, nearest.position.x) and t.position.y < nearest.position.y)
		if d < distance - 0.01 or (absf(d - distance) <= 0.01 and tie_preferred):
			nearest = t
			distance = d
	return nearest


func _place_tower(p: Vector2, d: Vector2) -> void:
	var session: BinduSession = self.session
	if _gift_blocked(): return
	var t := Tower.new()
	t.add(session.picked["e"], session.picked["lv"])
	t.dir = d
	t.position = p
	t.main = session
	if session.mp_mode == "coop":
		session.mp_tw_n += 1
		t.owner_id = session.mp.my_id
		t.net_id = session.mp.my_id * 100000 + session.mp_tw_n
	session.towers.add_child(t)
