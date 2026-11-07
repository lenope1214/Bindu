class_name BinduLobby
extends BinduFeature
## 대기방·접속·요청과 자리 비움. 예약 콜백은 main의 순서를 따른다.

var mp_code_edit: LineEdit
var mp_start_btn: Button
var mp_host_box: HBoxContainer
var mp_join_box: HBoxContainer
var mp_room_box: VBoxContainer  # 방 코드·복사 + 사람 줄(플랫폼 그림·닉네임·핑)
var mp_desc: Label  # 모드 설명 (방에 들어가면 숨김)
var mp_load_view: Control  # 방 만들기·들어가기·호스트와 연결 중 화면 (그림·단계·남은 시간, _mp_draw_load)
var mp_load_msg := ""
var mp_load_host := false  # 방을 만드는 중 (단계가 둘)
var mp_close_btn: Button
var mp_ping_labels := {}  # id -> 사람 줄 끝 핑 Label (핑이 바뀌면 줄을 다시 안 만들고 글만)
var mp_pop: PanelContainer  # 속성 고르기·내보낼 사람 고르기 작은 창
var mp_req_got_w := -1  # 이 웨이브 쉬는 시간에 요청한 속성을 이미 받음
# 대결 보낸 구체·멀티 업적
func _build_mp_lobby(root: Control) -> void:
	var session: BinduSession = self.session
	session.mp_panel = PanelContainer.new()
	session.mp_panel.z_index = 22
	session.mp_panel.set_anchors_preset(Control.PRESET_CENTER)
	session.mp_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	session.mp_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	session.mp_panel.offset_left = -330.0
	session.mp_panel.offset_right = 330.0
	session.mp_panel.offset_top = -160.0  # 내용만큼 위아래로 자란다
	session.mp_panel.offset_bottom = 160.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_content_margin_all(18)
	session.mp_panel.add_theme_stylebox_override("panel", sb)
	session.mp_panel.visible = false
	root.add_child(session.mp_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	session.mp_panel.add_child(box)
	var head := Label.new()
	head.text = "멀티플레이"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", Meta.fs(28))
	box.add_child(head)
	var desc := Label.new()
	mp_desc = desc
	desc.text = "대결: 같은 웨이브를 각자 막고, 실수 없이 막으면 상대에게 구체를 보냄\n협동: 한 전장을 함께 막음 (호스트 기기가 계산, 인원만큼 구체가 많아짐)\n맵·규칙은 호스트가 시작 화면에서 고른 것으로, 모드는 끈 채로 합니다"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", Meta.fs(15))
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	box.add_child(desc)
	mp_host_box = HBoxContainer.new()
	mp_host_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mp_host_box.add_theme_constant_override("separation", 10)
	box.add_child(mp_host_box)
	for spec in [["대결 방 만들기", "vs"], ["협동 방 만들기", "coop"]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(250, 46)
		b.focus_mode = Control.FOCUS_NONE
		var m: String = spec[1]
		b.pressed.connect(func(): _mp_host(m))
		mp_host_box.add_child(b)
	mp_join_box = HBoxContainer.new()
	mp_join_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mp_join_box.add_theme_constant_override("separation", 10)
	box.add_child(mp_join_box)
	mp_code_edit = LineEdit.new()
	mp_code_edit.placeholder_text = "방 코드 6자리"
	mp_code_edit.custom_minimum_size = Vector2(220, 46)
	mp_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_code_edit.add_theme_font_size_override("font_size", Meta.fs(22))
	# 글자 수 제한(max_length) 대신 넣을 때마다 코드 글자만 남긴다: "방 코드 3EL3MP" 같은 글을 붙여 넣어도 코드만
	mp_code_edit.text_changed.connect(func(t):
		var c := Mp.clean_code(t)
		if c != t:
			mp_code_edit.text = c
			mp_code_edit.caret_column = c.length())
	mp_code_edit.text_submitted.connect(func(_t): _mp_join())
	mp_join_box.add_child(mp_code_edit)
	var pb := Button.new()
	pb.text = "붙여넣기"
	pb.custom_minimum_size = Vector2(130, 46)
	pb.focus_mode = Control.FOCUS_NONE
	pb.pressed.connect(func():
		mp_code_edit.text = Mp.clean_code(DisplayServer.clipboard_get())
		mp_code_edit.caret_column = mp_code_edit.text.length()
		if mp_code_edit.text.length() != 6:
			session.mp_status.text = "복사한 글에 방 코드 6자리가 없어요")
	mp_join_box.add_child(pb)
	var jb := Button.new()
	jb.text = "참가"
	jb.custom_minimum_size = Vector2(200, 46)
	jb.focus_mode = Control.FOCUS_NONE
	jb.pressed.connect(_mp_join)
	mp_join_box.add_child(jb)
	mp_room_box = VBoxContainer.new()
	mp_room_box.add_theme_constant_override("separation", 6)
	mp_room_box.visible = false
	box.add_child(mp_room_box)
	mp_load_view = Control.new()
	mp_load_view.custom_minimum_size = Vector2(560, 200)
	mp_load_view.visible = false
	mp_load_view.add_to_group("mp_spin")  # 매 프레임 다시 그림
	mp_load_view.draw.connect(_mp_draw_load)
	box.add_child(mp_load_view)
	session.mp_status = Label.new()
	session.mp_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	session.mp_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session.mp_status.custom_minimum_size = Vector2(600, 30)
	session.mp_status.add_theme_font_size_override("font_size", Meta.fs(18))
	box.add_child(session.mp_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	mp_start_btn = Button.new()
	mp_start_btn.text = "시작"
	mp_start_btn.custom_minimum_size = Vector2(220, 46)
	mp_start_btn.focus_mode = Control.FOCUS_NONE
	mp_start_btn.pressed.connect(_mp_start)
	row.add_child(mp_start_btn)
	mp_close_btn = Button.new()
	mp_close_btn.text = "닫기"
	mp_close_btn.custom_minimum_size = Vector2(200, 46)
	mp_close_btn.focus_mode = Control.FOCUS_NONE
	mp_close_btn.pressed.connect(_toggle_mp_lobby)
	row.add_child(mp_close_btn)
	session.mp_bar = Label.new()  # 점수 줄 바로 아래 (_mp_tick이 자리를 맞춘다)
	session.mp_bar.add_theme_font_size_override("font_size", Meta.fs(15))
	session.mp_bar.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	session.mp_bar.add_theme_constant_override("outline_size", 4)
	session.mp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.mp_bar.visible = false
	root.add_child(session.mp_bar)
	# 협동 버튼 줄 (상태 줄 아래): [속성 요청] 모두, [내보내기] 호스트만
	session.mp_act = HBoxContainer.new()
	session.mp_act.add_theme_constant_override("separation", 8)
	session.mp_act.visible = false
	root.add_child(session.mp_act)
	session.mp_view_btn = Button.new()
	session.mp_view_btn.text = "보기: 모두"
	session.mp_view_btn.tooltip_text = "누구 오브젝트인지 골라 보기: 모두 → 나 → 친구마다 (고른 사람 것만 진하게, 나머지는 흐리게)"
	session.mp_view_btn.focus_mode = Control.FOCUS_NONE
	session.mp_view_btn.add_theme_font_size_override("font_size", Meta.fs(14))
	session.mp_view_btn.pressed.connect(_mp_view_next)
	session.mp_act.add_child(session.mp_view_btn)
	session.mp_req_btn = Button.new()
	session.mp_req_btn.text = "속성 요청"
	session.mp_req_btn.tooltip_text = "내 오브젝트 하나에 원하는 속성을 요청해요. 친구가 그 속성 카드를 고르면 넣어 줄 수 있어요 (쉬는 시간마다 1장)"
	session.mp_req_btn.focus_mode = Control.FOCUS_NONE
	session.mp_req_btn.add_theme_font_size_override("font_size", Meta.fs(14))
	session.mp_req_btn.pressed.connect(_mp_req_toggle)
	session.mp_act.add_child(session.mp_req_btn)
	session.mp_kick_btn = Button.new()
	session.mp_kick_btn.text = "내보내기"
	session.mp_kick_btn.tooltip_text = "호스트: 판에서 사람을 내보내요 (그 사람 오브젝트는 남고, 다시 들어올 수 없어요)"
	session.mp_kick_btn.focus_mode = Control.FOCUS_NONE
	session.mp_kick_btn.add_theme_font_size_override("font_size", Meta.fs(14))
	session.mp_kick_btn.pressed.connect(_mp_kick_open)
	session.mp_act.add_child(session.mp_kick_btn)
	mp_pop = PanelContainer.new()
	mp_pop.z_index = 23
	mp_pop.set_anchors_preset(Control.PRESET_CENTER)
	mp_pop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mp_pop.grow_vertical = Control.GROW_DIRECTION_BOTH
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	psb.set_border_width_all(1)
	psb.border_color = Color(1, 1, 1, 0.25)
	psb.set_content_margin_all(16)
	mp_pop.add_theme_stylebox_override("panel", psb)
	mp_pop.visible = false
	root.add_child(mp_pop)
	_mp_refresh_lobby()


## 협동 작은 창: 제목 + 버튼들 ([글, 색, 누르면 할 일]) + [닫기].
func _mp_pop_show(title: String, items: Array) -> void:
	for ch in mp_pop.get_children():
		mp_pop.remove_child(ch)
		ch.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	mp_pop.add_child(box)
	var head := Label.new()
	head.text = title
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(420, 0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", Meta.fs(17))
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 4 if items.size() > 4 else maxi(1, items.size())
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.custom_minimum_size = Vector2(100, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", it[1])
		var f: Callable = it[2]
		b.pressed.connect(func():
			mp_pop.visible = false
			f.call())
		grid.add_child(b)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(120, 38)
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): mp_pop.visible = false)
	box.add_child(close)
	mp_pop.visible = true
	_mp_pop_center.call_deferred()


func _mp_pop_center() -> void:
	var sz := mp_pop.get_combined_minimum_size()
	mp_pop.offset_left = -floorf(sz.x / 2.0)
	mp_pop.offset_right = ceilf(sz.x / 2.0)
	mp_pop.offset_top = -floorf(sz.y / 2.0)
	mp_pop.offset_bottom = ceilf(sz.y / 2.0)


## [속성 요청]: 다음에 누른 내 오브젝트에 요청할 속성을 고른다.
func _mp_req_toggle() -> void:
	var session: BinduSession = self.session
	if session.mp_mode != "coop":
		return
	if mp_req_got_w == session.wave:
		session.hud_system._show_toast("이번 쉬는 시간에는 이미 요청한 속성을 받았어요")
		return
	session.mp_req_mode = not session.mp_req_mode
	session.mp_req_btn.text = "요청 취소" if session.mp_req_mode else "속성 요청"
	session.hint.text = "속성을 요청할 내 오브젝트를 누르세요" if session.mp_req_mode else session.ui_layout_system._th(session.cards_system._choose_hint() if session.phase == BinduSession.Phase.CHOOSE else "")


func _mp_req_open(t: Tower) -> void:
	var session: BinduSession = self.session
	session.mp_req_mode = false
	session.mp_req_btn.text = "속성 요청"
	session.interaction_system._restore_hint()
	var items: Array = []
	for e in Elem.ALL:
		if t.can_take({"type": "elem", "e": e, "lv": 1}):
			var ee: int = e
			items.append([Elem.NAMES[e], Elem.COLORS[e], func(): _mp_req_set(t, ee)])
	if t.req_e >= 0:
		items.append(["요청 지우기", Color(0.75, 0.75, 0.75), func(): _mp_req_set(t, -1)])
	if items.is_empty():
		session.hud_system._show_toast("이 오브젝트에는 더 넣을 수 있는 속성이 없어요")
		return
	_mp_pop_show("%s에 받고 싶은 속성 (친구가 그 속성 카드를 고르면 넣어 줄 수 있어요. 한 번에 하나)" % t.title(), items)


## 요청은 사람마다 하나: 다른 내 오브젝트의 요청은 지운다. 상태는 오브젝트 상태(tw)로 친구에게 간다.
func _mp_req_set(t: Tower, e: int) -> void:
	var session: BinduSession = self.session
	if not is_instance_valid(t):
		return
	for x in session.multiplayer_system._my_towers():
		if x != t and x.req_e >= 0:
			x.req_e = -1
			x.queue_redraw()
	t.req_e = e
	t.queue_redraw()
	if e >= 0:
		session.hud_system._show_toast("요청: %s 속성 (친구 화면에 표시돼요)" % Elem.NAMES[e])


## 친구 오브젝트가 지금 든 속성 카드를 요청했나.
func _req_ok(t: Tower) -> bool:
	var session: BinduSession = self.session
	return session.mp_mode == "coop" and is_instance_valid(t) and t.owner_id != session.mp.my_id and t.req_e >= 0 \
		and str(session.picked.get("type", "")) == "elem" and int(session.picked.get("e", -1)) == t.req_e


## 요청한 속성을 친구 오브젝트에 넣어 준다: 주인 기기가 넣고 상태를 다시 보낸다.
func _mp_give(t: Tower) -> void:
	var session: BinduSession = self.session
	session.mp.send({"t": "gift", "nid": t.net_id, "e": session.picked["e"], "lv": session.picked["lv"]}, t.owner_id)
	session.hud_system._show_toast("%s에게 %s 속성을 넣어 줬어요" % [session.multiplayer_system._mp_name(t.owner_id), Elem.NAMES[session.picked["e"]]])
	session.sfx.play("place")
	session.spawning_system.burst(t.position, session.cards_system._card_color(session.picked), 16, 160.0)
	t.req_e = -1
	t.queue_redraw()
	session.cards_system._after_place()


func _mp_recv_gift(from: int, msg: Dictionary) -> void:
	var session: BinduSession = self.session
	if session.mp_mode != "coop":
		return
	var nid := int(msg.get("nid", 0))
	var e := int(msg.get("e", -1))
	var lv := maxi(1, int(msg.get("lv", 1)))
	for t in session.multiplayer_system._my_towers():
		if t.net_id != nid:
			continue
		if t.req_e != e or not t.can_take({"type": "elem", "e": e, "lv": lv}):
			session.hud_system._show_toast("%s가 보낸 %s 속성은 요청이 이미 채워져 들어가지 않았어요" % [session.multiplayer_system._mp_name(from), Elem.NAMES.get(e, "?")])
			return
		var m: String = t.add(e, lv)
		t.req_e = -1
		mp_req_got_w = session.wave
		t.place_pop = 1.0
		t.queue_redraw()
		session.hud_system._show_toast("%s가 %s 속성을 넣어 줬어요 · %s" % [session.multiplayer_system._mp_name(from), Elem.NAMES[e], m])
		session.sfx.play("place")
		if m.begins_with("조합"):
			session.sfx.play("reaction", 0.0)
		session.spawning_system.burst(t.position, Elem.COLORS[e], 20, 200.0)
		session.progression_system._check_progress()
		return


## 호스트 [내보내기]: 내보낼 사람 고르기 (두 번 눌러야).
func _mp_kick_open() -> void:
	var session: BinduSession = self.session
	if session.mp_mode != "coop" or not session.mp.is_host():
		return
	var items: Array = []
	for id in session.mp_others:
		if session.mp_kicked.has(id):
			continue
		var kid: int = id
		items.append([session.multiplayer_system._mp_name(id), Mp.owner_color(id), func(): _mp_kick_confirm(kid)])
	if items.is_empty():
		return
	_mp_pop_show("내보낼 사람 (그 사람 오브젝트는 남고 다시 들어올 수 없어요)", items)


func _mp_kick_confirm(id: int) -> void:
	var session: BinduSession = self.session
	_mp_pop_show("%s을(를) 정말 내보낼까요?" % session.multiplayer_system._mp_name(id), [["내보내기", Color(1, 0.5, 0.5), func(): _mp_kick(id)]])


func _mp_kick(id: int) -> void:
	var session: BinduSession = self.session
	if not session.mp.is_host() or not session.mp_others.has(id):
		return
	session.mp_kicked[id] = true
	session.mp.send({"t": "kick"}, id)
	session.mp_others[id]["gone"] = true
	session.mp_ready.erase(id)
	session.mp_cursors.erase(id)
	session.hud_system._show_toast("%s을(를) 내보냈어요" % session.multiplayer_system._mp_name(id))
	session.get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(session) and is_instance_valid(session.mp):
			session.mp._drop(id))  # 메시지가 간 뒤에 끊는다
	session.multiplayer_system._mp_try_go()


## 협동 [보기]: 모두 → 나 → 친구마다 차례로.
func _mp_view_next() -> void:
	var session: BinduSession = self.session
	var ids: Array = [0, session.mp.my_id]
	for id in session.mp_others:
		if not session.mp_others[id].get("gone", false):
			ids.append(id)
	session.mp_view = ids[(ids.find(session.mp_view) + 1) % ids.size()]
	for t in session.towers.get_children():
		t.queue_redraw()


## 고른 사람 것이 아닌 오브젝트·그 탄·장판을 흐리게 (부드럽게 바뀜).
func _mp_view_fade(delta: float) -> void:
	var session: BinduSession = self.session
	var k := minf(1.0, delta * 10.0)
	for t in session.towers.get_children():
		var a := 1.0 if session.mp_view == 0 or t.owner_id == session.mp_view else 0.25
		t.self_modulate.a = lerpf(t.self_modulate.a, a, k)  # modulate는 카드 놓기 흐림(_update_place_dim)이 쓴다
	for layer in [session.projectiles, session.zones]:
		for n in layer.get_children():
			var ot = n.get("owner_tower")
			var a := 1.0 if session.mp_view == 0 or not is_instance_valid(ot) or ot.owner_id == session.mp_view else 0.25
			n.modulate.a = lerpf(n.modulate.a, a, k)


func _mp_wait_end() -> void:
	var session: BinduSession = self.session
	session.mp_wait_left = -1.0
	session.mp_wait_ids.clear()
	session.mp_wait_show = -1.0
	session.mp_host_wait = -1.0


## 매 프레임 (멀티 판): 잠수 처리 시간 재기.
func _mp_afk_tick(delta: float) -> void:
	var session: BinduSession = self.session
	if session.phase == BinduSession.Phase.GAMEOVER or session.title_label.visible:
		return
	if session.mp_wait_show > 0.0:
		session.mp_wait_show -= delta
	var rest := session.phase != BinduSession.Phase.WAVE
	if session.mp_mode == "coop":
		if session.mp.is_host() and session.mp_host_wait > 0.0:
			session.mp_host_wait -= delta
			if session.mp_host_wait <= 0.0:
				session.mp_host_wait = -1.0
				session.multiplayer_system._mp_try_go(true)
		var done: bool = session.mp_ready.get(session.mp.my_id, false) if session.mp.is_host() else session.mp_i_ready
		if session.mp_afk and rest and not done and session.mp_wait_left < 0.0:
			session.mp_wait_left = 2.0  # 자리 비움: 곧바로 대신 고른다
		if session.mp_wait_left > 0.0:
			session.mp_wait_left -= delta
			if session.mp_wait_left <= 0.0:
				session.mp_wait_left = -1.0
				if rest and not done:
					_mp_auto_rest()
	elif session.mp_mode == "vs" and rest:
		session.mp_idle_t += delta
		if session.mp_idle_t >= float(Rules.tune["vs_idle"]):
			session.mp_idle_t = 0.0
			_mp_auto_rest()


## 사람이 화면을 누르거나 키를 누름: 잠수 아님.
func _mp_presence() -> void:
	var session: BinduSession = self.session
	session.mp_idle_t = 0.0
	session.mp_afk_n = 0
	if session.mp_afk:
		session.mp_afk = false
		session.mp_wait_left = -1.0
		if session.mp_mode == "coop":
			session.mp.send({"t": "afk", "on": false})
		session.hud_system._show_toast("돌아왔어요: 다시 직접 골라요")


## 잠수: 남은 고르기를 대신하고 준비한다 (속성은 반응이 생기는 내 오브젝트에, 없으면 오브젝트가 적은 진입 방향에 새로,
## 다른 카드는 넣을 수 있는 내 오브젝트에, 특성은 동전 말고 첫 번째).
func _mp_auto_rest() -> void:
	var session: BinduSession = self.session
	if session.phase == BinduSession.Phase.GAMEOVER or session.phase == BinduSession.Phase.WAVE or session.mp_mode == "":
		return
	session.mp_auto_now = true
	session.mp_req_mode = false
	mp_pop.visible = false
	for i in 40:
		if session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.AIM, BinduSession.Phase.MOVE] or session.interaction_system.press_t or session.interaction_system.moving:
			session.interaction_system._cancel_step()
			continue
		if session.perk_mode:
			if session.coin_stage > 0:
				break
			var opts: Array = session.perk_offer.filter(func(pk): return pk["id"] != "coin")
			session.perks_system._on_perk(opts[0] if not opts.is_empty() else session.perk_offer[0])
			continue
		if session.phase != BinduSession.Phase.CHOOSE or session.picks_left <= 0 or session.offer.is_empty():
			break
		if not _mp_auto_pick():
			break
	if session.phase == BinduSession.Phase.CHOOSE and not session.perk_mode:
		session.picks_left = 0
		session.cards_system._enter_ready()
	session.mp_afk_n += 1
	if session.mp_mode == "coop":
		if session.mp_afk_n >= int(Rules.tune["mp_afk_after"]) and not session.mp_afk:
			session.mp_afk = true
			session.mp.send({"t": "afk", "on": true})
			session.hud_system._show_toast("자리 비움: 다음부터 카드를 대신 골라요 (화면을 누르면 돌아와요)")
		else:
			session.hud_system._show_toast("시간이 지나 카드를 대신 골랐어요")
		if session.phase == BinduSession.Phase.READY:
			session.multiplayer_system._mp_coop_ready()
	elif session.mp_mode == "vs":
		if session.mp_afk_n >= int(Rules.tune["vs_idle_out"]):
			session.mp_auto_now = false
			session.mp_rank = "%d번 연속 움직임이 없어 탈락했어요" % session.mp_afk_n
			session.core_hp = 0
			session.run_flow_system._game_over()
			return
		session.hud_system._show_toast("오래 움직임이 없어 웨이브를 시작했어요 (%d번 연속이면 탈락)" % int(Rules.tune["vs_idle_out"]))
		if session.phase == BinduSession.Phase.READY:
			session.run_flow_system._start_wave()
	session.mp_auto_now = false


## 카드 하나를 대신 고른다. 고를 게 없으면 false.
func _mp_auto_pick() -> bool:
	var session: BinduSession = self.session
	var mine: Array = session.multiplayer_system._my_towers()
	for o in session.offer:
		if o["type"] == "elem":
			for t in mine:
				if t.can_take(o) and not Elem.new_reactions(t.eff_now(), o["e"]).is_empty():
					session.cards_system._on_pick(o)
					session.interaction_system._place_on(t)
					return true
		else:
			for t in mine:
				if t.can_take(o):
					session.cards_system._on_pick(o)
					session.cards_system._apply_card(t)
					return true
	for o in session.offer:
		if o["type"] == "elem" and not (o["e"] == Elem.STAR and session.cards_system.star_full()):
			var spot := _mp_auto_spot()
			if spot.is_empty():
				return false
			session.cards_system._on_pick(o)
			session.interaction_system._place_tower(spot[0], spot[1])
			session.cards_system._after_place()
			return true
	return false


## 대신 놓을 자리: 오브젝트가 가장 적은 진입 방향, 중앙 가까이 비어 있는 곳 [자리, 방향].
func _mp_auto_spot() -> Array:
	var session: BinduSession = self.session
	var ls: Array = Array(session.lanes) if not session.lanes.is_empty() else [0.0]
	var c := session.viewport_system.core()
	var best_a: float = ls[0]
	var fewest := 999
	for a in ls:
		var d := Vector2.from_angle(a)
		var cnt := session.towers.get_children().filter(func(t): return (t.position - c).normalized().dot(d) > 0.9).size()
		if cnt < fewest:
			fewest = cnt
			best_a = a
	var dir := Vector2.from_angle(best_a)
	var f := session.combat_system.field_rect()
	for k in 16:
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := c + dir * (90.0 + 28.0 * (k / 2)) + dir.orthogonal() * 24.0 * side
		if f.has_point(p) and session.towers.get_children().all(func(t): return t.position.distance_to(p) >= BinduSession.MERGE_DIST + 4.0):
			return [p, dir]
	return []


## 시작 화면 [멀티플레이]: 창을 열고 닫는다. 닫으면 만든 방·들어간 방에서 나온다.
func _toggle_mp_lobby() -> void:
	var session: BinduSession = self.session
	session.mp_panel.visible = not session.mp_panel.visible
	if session.mp_panel.visible:
		session.mp.check_status()
		var rj := Mp.saved_rejoin()
		if not rj.is_empty() and not session.mp.active() and session.mp_mode == "":
			# 껐다 켠 협동 참가자: 코드를 채워 두고 [참가]로 원래 자리에
			mp_code_edit.text = str(rj.get("code", ""))
			session.mp_status.text = "하던 협동 판이 있어요. [참가]를 누르면 다시 들어가요"
	if session.mp_panel.visible and Meta.guide_on and not Tutorial.seen.has("mp") and DisplayServer.get_name() != "headless":
		session.onboarding_system._open_tut(["mp"])  # 멀티 창 위에 바로
	if not session.mp_panel.visible and session.mp_mode == "":
		session.mp.leave()
	_mp_refresh_lobby()


func _mp_btn_shown() -> bool:
	if Mp.sw_hide:
		return false
	return Mp.available() or (Mp.url() != "" and OS.has_feature("windows"))


## 서버 스위치가 바뀜: 숨김이면 버튼·창을 닫고, 막힘이면 창의 안내를 바꾼다 (이미 시작한 판은 그대로).
func _mp_apply_switch() -> void:
	var session: BinduSession = self.session
	if session.mp_btn:
		session.mp_btn.visible = _mp_btn_shown()
	if session.mp_panel and session.mp_panel.visible and not Mp.sw_on and session.mp_mode == "":
		if not session.mp.active():
			if Mp.sw_hide:
				_toggle_mp_lobby()
			else:
				session.mp_status.text = _mp_off_text()


func _mp_off_text() -> String:
	return "멀티플레이를 잠시 쉬고 있어요" + (": " + Mp.sw_msg if Mp.sw_msg != "" else "")


## 서버 스위치가 꺼졌거나 연결 부품(WebRTC 확장)을 못 읽은 기기: 방을 열어도 안 되니 미리 막는다.
func _mp_blocked() -> bool:
	var session: BinduSession = self.session
	if not Mp.sw_on:
		session.mp_status.text = _mp_off_text()
		return true
	if Mp.loaded():
		return false
	session.mp_status.text = "이 기기에서 멀티플레이 연결 부품을 읽지 못했어요. 게임을 완전히 껐다 켜 보세요 (계속되면 오류가 자동으로 보고됩니다)"
	return true


func _mp_host(m: String) -> void:
	var session: BinduSession = self.session
	if _mp_blocked():
		return
	session.mp_status.text = ""
	mp_load_msg = "방을 만드는 중"
	mp_load_host = true
	session.mp.host(m, session._mp_my_name())
	_mp_refresh_lobby()


func _mp_join() -> void:
	var session: BinduSession = self.session
	var c := Mp.clean_code(mp_code_edit.text)
	if c.length() != 6:
		session.mp_status.text = "방 코드 6자리를 넣으세요"
		return
	if _mp_blocked():
		return
	session.mp_status.text = ""
	mp_load_msg = "방에 들어가는 중"
	mp_load_host = false
	session.mp.join(c, session._mp_my_name())
	_mp_refresh_lobby()


func _mp_failed(reason: String) -> void:
	var session: BinduSession = self.session
	if session.mp_mode != "":
		session.mp_fail_msg = reason
	if session.mp_mode == "":
		session.mp_status.text = reason
		_mp_refresh_lobby(false)
		return
	# 판 중에 끊김
	if session.mp_mode == "coop" and session.mp_ghost and session.phase != BinduSession.Phase.GAMEOVER:
		# 협동 참가자: 같은 방에 다시 붙어 본다. 방이 없어졌으면(호스트가 나감) 바로 끝
		var room_gone: bool = session.mp.last_err in ["nocode", "started"]
		if session.mp_rejoin_until == 0 and not room_gone:
			session.mp_rejoin_until = Time.get_ticks_msec() + BinduSession.MP_REJOIN_S * 1000
			session.hud_system._show_toast("연결이 끊겼어요. 다시 접속하는 중…")
		if not room_gone and Time.get_ticks_msec() < session.mp_rejoin_until:
			session.mp_rejoin_wait = 2.0
			return
		session.mp_rejoin_until = 0
		session.mp_rank = "호스트가 나가 판이 끝났어요" if room_gone else reason
		session.core_hp = 0
		session.run_flow_system._game_over()
	elif session.mp_mode == "vs" and not session.mp.is_host() and session.phase != BinduSession.Phase.GAMEOVER:
		# 대결 참가자: 호스트와 끊기면 이 판은 끝 (끊긴 사람은 패배)
		session.mp_rank = "연결이 끊겨 판이 끝났어요 (끊기면 패배)"
		session.core_hp = 0
		session.run_flow_system._game_over()
	else:
		session.hud_system._show_toast(reason)
		for id in session.mp_others:
			session.mp_others[id]["gone"] = true


func _mp_refresh_lobby(keep_status := true) -> void:
	var session: BinduSession = self.session
	if session.mp_panel == null or session.mp == null:
		return
	var in_room := session.mp.active()
	var busy := session.mp.busy()
	var wait_host := session.mp.waiting_host()
	mp_host_box.visible = not in_room and not busy
	mp_join_box.visible = not in_room and not busy
	mp_room_box.visible = in_room
	mp_load_view.visible = busy or wait_host
	mp_close_btn.text = "나가기" if in_room or busy else "닫기"
	mp_desc.visible = not in_room and not busy
	_mp_lobby_tick()
	for ch in mp_room_box.get_children():
		mp_room_box.remove_child(ch)
		ch.queue_free()
	mp_ping_labels.clear()
	mp_start_btn.visible = in_room and session.mp.is_host()
	var ready := session.mp.connected_ids().size()
	var playing := session.mp.playing_ids().size() if in_room else 0  # 지난 판이 아직 안 끝난 사람
	mp_start_btn.disabled = ready < 1 or playing > 0
	mp_start_btn.text = "시작 (%d/%d명)" % [ready + 1, Mp.MAX_PLAYERS] if in_room else "시작"
	if not in_room:
		if busy:
			session.mp_status.text = ""
		elif not keep_status and session.mp_status.text == "":
			session.mp_status.text = "방을 만들거나 친구에게 받은 방 코드로 들어가세요"
		return
	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", 12)
	mp_room_box.add_child(code_row)
	var cl := Label.new()
	cl.text = "%s 방 코드  %s" % ["대결" if session.mp.mode == "vs" else "협동", session.mp.code]
	cl.add_theme_font_size_override("font_size", Meta.fs(22))
	code_row.add_child(cl)
	var cb := Button.new()
	cb.text = "복사"
	cb.custom_minimum_size = Vector2(90, 38)
	cb.focus_mode = Control.FOCUS_NONE
	cb.pressed.connect(func():
		DisplayServer.clipboard_set(session.mp.code)
		cb.text = "복사됨")
	code_row.add_child(cb)
	var cnt := Label.new()
	cnt.text = "%d/%d명" % [session.mp.names().size(), Mp.MAX_PLAYERS]
	cnt.add_theme_font_size_override("font_size", Meta.fs(16))
	cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	code_row.add_child(cnt)
	if wait_host:
		# 참가자: 호스트와 이어지기 전엔 사람 줄 대신 도는 고리만 (이어지면 peers_changed로 다시 그림)
		session.mp_status.text = ""
		return
	# 사람 줄은 왼쪽 정렬 (그림·★·이름이 세로로 맞게), 목록 덩어리는 창 가운데
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.custom_minimum_size = Vector2(380, 0)
	list.add_theme_constant_override("separation", 6)
	mp_room_box.add_child(list)
	for n in session.mp.names():
		var id: int = n[0]
		var me := id == session.mp.my_id
		# 호스트: 내가 차단한 사람은 시작 전에 방에서 내보낸다
		if session.mp.is_host() and not me and not session.mp.started and Meta.blocked.has(session.mp.pids.get(id, "")):
			var did := id
			session.hud_system._show_toast("차단한 플레이어가 들어와서 내보냈어요")
			session.mp.call_deferred("_drop", did)
			continue
		var nm: String = session.multiplayer_system._mp_name(id) if not me else (n[1] if n[1] != "" else "닉네임 없음")
		var st := "" if me or n[2] else ("연결 안 됨" if n[4] else "연결 중")
		if st == "" and not me and session.mp.in_game.has(id):
			st = "판 진행 중"
		var row := _mp_member_row(id, n[3], id == 1, nm + (" (나)" if me else ""), st)
		if not me:
			row.add_child(session.leaderboard_system._ugc_buttons(session.mp.pids.get(id, ""), str(n[1]), "mp", func(): _mp_refresh_lobby()))
		list.add_child(row)
	for i in Mp.MAX_PLAYERS - session.mp.names().size():
		var empty := _mp_member_row(0, "", false, "빈 자리", "")
		empty.modulate = Color(1, 1, 1, 0.3)
		list.add_child(empty)
	_mp_refresh_pings()
	if session.mp.relay_lost and session.mp.is_host():
		session.mp_status.text = "중개 서버 연결이 끊겨 새로 들어올 수는 없어요. 지금 있는 사람끼리는 계속할 수 있어요" if playing == 0 else "지난 판이 아직 끝나지 않은 사람이 있어요 (중개 서버 연결이 끊겨 새로 들어올 수는 없어요)"
	elif playing > 0:
		session.mp_status.text = "지난 판이 아직 끝나지 않은 사람이 있어요. 모두 돌아오면 %s" % ("[시작]" if session.mp.is_host() else "호스트가 시작해요")
	elif session.mp.is_host():
		session.mp_status.text = "친구에게 방 코드를 알려 주세요. 연결되면 [시작]" if ready < 1 else "모두 연결되면 [시작]"
	else:
		session.mp_status.text = "호스트가 시작하기를 기다리는 중"


## 로비 사람 한 줄: [플랫폼 그림] ★(호스트) 닉네임 [연결 중 고리·상태 | 핑]
func _mp_member_row(id: int, pf: String, host: bool, text: String, state: String) -> HBoxContainer:
	var session: BinduSession = self.session
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(26, 26)
	ic.tooltip_text = {"windows": "Windows", "mac": "Mac", "ios": "iPhone·iPad", "android": "Android", "linux": "Linux"}.get(pf, "")
	if id > 0:  # 빈 자리는 그림 없이
		ic.draw.connect(func(): Glyph.ui(ic, "pf_" + (pf if pf != "" else "unknown"), ic.size * 0.5, 10.0, Color(1, 1, 1, 0.85)))
	row.add_child(ic)
	var l := Label.new()
	l.text = ("★ " if host else "    ") + text  # ★ 자리를 비워 이름 시작을 맞춤
	l.add_theme_font_size_override("font_size", Meta.fs(20))
	row.add_child(l)
	if state == "연결 중":
		row.add_child(_mp_spinner(8.0))
	if state != "":
		var sl := Label.new()
		sl.text = state
		sl.add_theme_font_size_override("font_size", Meta.fs(16))
		sl.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if state == "연결 안 됨" else Color(1, 1, 1, 0.55))
		row.add_child(sl)
	elif id != session.mp.my_id and id > 0:
		var pl := Label.new()
		pl.add_theme_font_size_override("font_size", Meta.fs(16))
		pl.tooltip_text = "왕복 지연 (호스트와의 연결 기준)"
		row.add_child(pl)
		mp_ping_labels[id] = pl
	return row


## 핑 글과 색: 80ms 아래 초록, 150ms 아래 노랑, 그 위 빨강. 아직 못 쟀으면 "…ms".
func _mp_ping_text(id: int) -> Array:
	var session: BinduSession = self.session
	if not session.mp.ping.has(id):
		return ["…ms", Color(1, 1, 1, 0.4)]
	var ms: int = session.mp.ping[id]
	return ["%dms" % ms, Color(0.5, 1, 0.55) if ms < 80 else (Color(1, 0.85, 0.35) if ms < 150 else Color(1, 0.45, 0.4))]


func _mp_refresh_pings() -> void:
	for id in mp_ping_labels:
		var l: Label = mp_ping_labels[id]
		if is_instance_valid(l):
			var t := _mp_ping_text(id)
			l.text = t[0]
			l.add_theme_color_override("font_color", t[1])


## 도는 고리 (기다리는 동안). 다시 그리기는 _mp_lobby_tick이 group "mp_spin"으로.
func _mp_spinner(r: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(r * 2.0 + 6.0, r * 2.0 + 6.0)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add_to_group("mp_spin")
	c.draw.connect(func():
		var a := Time.get_ticks_msec() * 0.006
		var w := maxf(2.0, r * 0.22)
		c.draw_arc(c.size * 0.5, r, 0.0, TAU, 32, Color(1, 1, 1, 0.12), w, true)
		c.draw_arc(c.size * 0.5, r, a, a + PI * 1.3, 24, Color(0.6, 0.9, 1.0), w, true))
	return c


## 매 프레임 (창이 열려 있을 때): 고리·접속 화면을 다시 그린다.
func _mp_lobby_tick() -> void:
	var session: BinduSession = self.session
	if session.mp_panel == null or not session.mp_panel.visible:
		return
	session.get_tree().call_group("mp_spin", "queue_redraw")


## 접속 화면: 내 기기 ─ 오가는 점 ─ 상대(중개 서버·호스트), 지금 하는 일, 단계, (호스트 기다림) 남은 시간 막대.
## 단계: 방 만들기 = 중개 서버 → 방 만들기, 참가 = 중개 서버 → 방 찾기 → 호스트와 직접 연결.
func _mp_draw_load() -> void:
	var session: BinduSession = self.session
	var c := mp_load_view
	var w := c.size.x
	var font := c.get_theme_default_font()
	var now := Time.get_ticks_msec() / 1000.0
	var wait_host := session.mp.waiting_host()
	var ws_open := session.mp.ws.get_ready_state() == WebSocketPeer.STATE_OPEN
	var steps: Array = ["중개 서버", "방 만들기"] if mp_load_host else ["중개 서버", "방 찾기", "호스트와 직접 연결"]
	var cur := 2 if wait_host else (1 if ws_open else 0)
	var accent := Color(0.6, 0.9, 1.0)
	# 그림: 두 기기와 그 사이를 오가는 점
	var y := 44.0
	var a := Vector2(w * 0.24, y)
	var b := Vector2(w * 0.76, y)
	for p in [a, b]:
		c.draw_circle(p, 30.0, Color(1, 1, 1, 0.06))
		c.draw_arc(p, 30.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 1.5, true)
	Glyph.ui(c, "pf_" + str(Mp.PF[Mp.pf_code()]), a, 13.0, Color(1, 1, 1, 0.9))
	if wait_host:
		var hp: String = session.mp.peers.get(1, {}).get("pf", "")
		Glyph.ui(c, "pf_" + (hp if hp != "" else "unknown"), b, 13.0, Color(1, 1, 1, 0.9))
		Icons.draw(c, "score", b + Vector2(22, -22), 7.0, Color(1, 0.85, 0.4))
	else:
		# 중개 서버: 서버 칸 셋 (불빛은 차례로 깜빡)
		for i in 3:
			var r := Rect2(b + Vector2(-13, -13 + i * 9), Vector2(26, 7))
			c.draw_rect(r, Color(1, 1, 1, 0.85), false, 1.5)
			var on := int(now * 4.0) % 3 == i
			c.draw_circle(r.position + Vector2(20, 3.5), 1.6, accent if on else Color(1, 1, 1, 0.5))
	c.draw_arc(b, 36.0, now * 3.0, now * 3.0 + PI * 1.2, 24, accent, 3.0, true)  # 기다리는 쪽에 도는 고리
	var x0 := a.x + 40.0
	var x1 := b.x - 40.0
	for i in 9:
		c.draw_circle(Vector2(lerpf(x0, x1, i / 8.0), y), 1.5, Color(1, 1, 1, 0.18))
	for i in 3:
		var t := fposmod(now * 0.6 + i / 3.0, 1.0)
		var back := i == 1  # 하나는 되돌아오는 답
		var px := lerpf(x0, x1, 1.0 - t if back else t)
		c.draw_circle(Vector2(px, y), 4.0, Color(accent, sin(t * PI)))
	c.draw_string(font, Vector2(0, y + 52), "나", HORIZONTAL_ALIGNMENT_CENTER, w * 0.48, 14, Color(1, 1, 1, 0.55))
	var right := ("호스트 " + session.multiplayer_system._mp_name(1)) if wait_host else "중개 서버"
	c.draw_string(font, Vector2(w * 0.52, y + 52), right, HORIZONTAL_ALIGNMENT_CENTER, w * 0.48, 14, Color(1, 1, 1, 0.55))
	# 지금 하는 일
	var dots := ".".repeat(1 + int(now * 2.5) % 3)
	var title: String = ["중개 서버에 접속하는 중", mp_load_msg if not ws_open or mp_load_host else "방을 찾는 중", "호스트와 직접 연결하는 중"][cur]
	if cur == 1 and mp_load_host:
		title = "방을 만드는 중"
	c.draw_string(font, Vector2(0, 132), title + dots, HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color.WHITE)
	# 단계: 끝난 것 초록 ✓, 지금 것 파랑, 남은 것 흐리게
	var fs := 15
	var parts: Array = []
	var total := 0.0
	for i in steps.size():
		var tx: String = ("✓ " if i < cur else "%d " % (i + 1)) + steps[i]
		var tw := font.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		parts.append([tx, tw, Color(0.5, 1, 0.55) if i < cur else (accent if i == cur else Color(1, 1, 1, 0.35))])
		total += tw + (34.0 if i < steps.size() - 1 else 0.0)
	var sx := (w - total) * 0.5
	for i in parts.size():
		c.draw_string(font, Vector2(sx, 162), parts[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, parts[i][2])
		sx += parts[i][1]
		if i < parts.size() - 1:
			c.draw_line(Vector2(sx + 9, 157), Vector2(sx + 25, 157), Color(1, 1, 1, 0.25), 1.5)
			sx += 34.0
	# 호스트 기다림: 남은 시간 막대 (Mp.WAIT_JOIN초가 지나면 실패로 돌아감)
	if wait_host:
		var el := clampf((Time.get_ticks_msec() - session.mp.joined_ms) / 1000.0, 0.0, Mp.WAIT_JOIN)
		var bar := Rect2(w * 0.2, 180, w * 0.6, 5)
		c.draw_rect(bar, Color(1, 1, 1, 0.1))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * el / Mp.WAIT_JOIN, bar.size.y)), accent if el < 10.0 else Color(1, 0.75, 0.35))
		c.draw_string(font, Vector2(bar.end.x + 10, 187), "%d / %d초" % [int(el), int(Mp.WAIT_JOIN)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
		if el >= 8.0:
			c.draw_string(font, Vector2(0, 210), "오래 걸리면 두 기기의 인터넷·방화벽을 확인해 보세요", HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(1, 1, 1, 0.5))


## 호스트 [시작]: 씨앗·맵·규칙을 정해 모두에게 보내고 함께 시작한다.
func _mp_start() -> void:
	var session: BinduSession = self.session
	if not session.mp.is_host() or session.mp.connected_ids().is_empty() or not session.mp.playing_ids().is_empty():
		return
	var ids: Array = [1] + session.mp.connected_ids()
	var names := {}
	for id in ids:
		names[id] = session.mp.peers.get(id, {}).get("name", "")
	var msg := {"t": "start", "seed": randi() % 2000000000 + 1, "map": Meta.map_id, "flip": Meta.line_flip, "rules": Meta.rules,
		"mode": session.mp.mode, "ids": ids, "names": names}
	session.mp.lock()
	session.mp.send(msg)
	session.multiplayer_system._mp_begin(msg)


## 멀티 판이 끝나고 돌아옴: 시작 화면 위에 대기방(멀티플레이 창)을 연다. 방이 남아 있으면 다시 들어올 수 있게 풀고 알린다.
func _mp_back_lobby() -> void:
	var session: BinduSession = self.session
	BinduSession.mp_back = false
	session.title_label.visible = true
	session.persistence_system._refresh_continue()
	session.hint.text = ""
	session.mp_panel.visible = true
	if session.mp.active():
		session.mp.back_to_lobby()
		session.mp_status.text = ""
		_mp_refresh_lobby()
	else:
		_mp_refresh_lobby()
		session.mp_status.text = BinduSession.mp_back_msg
	BinduSession.mp_back_msg = ""
