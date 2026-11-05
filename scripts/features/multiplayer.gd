class_name BinduMultiplayer
extends BinduFeature
## 패킷·스냅샷과 멀티 진행. 예약 콜백은 main의 순서를 따른다.

var mp_pending := 0  # 대결: 웨이브 중에 받은 것 (다음 쉬는 시간에 예고에 더함)
var mp_st_sig := ""
var mp_tick_t := 0.0
var mp_next := {}  # 협동 참가자: 호스트가 정한 다음 웨이브 {w, lanes, res, boss}
var mp_ghosts := {}  # 협동 참가자: net_id -> Orb
var mp_orb_n := 0
var mp_tw_sig := ""
var mp_snap_t := 0.0
var mp_start := {}  # 판을 시작한 "start" 메시지 (협동 호스트가 다시 들어온 사람에게 다시 보냄)
var mp_code_last := ""  # 이번 판 방 코드 (끊기면 Mp가 code를 비우므로 따로)
var mp_won := false
var mp_win_counted := false
var mp_was_last := false  # 대결: 한때 웨이브 꼴찌
var mp_cur_layer: Node2D
var mp_cur_t := 0.0
var mp_cur_last := Vector2.INF
func wf() -> float:
	var session: BinduSession = self.session
	return session.wrng.randf() if session.mp_seed != 0 and not session.w_off else randf()


func wi() -> int:
	var session: BinduSession = self.session
	return session.wrng.randi() if session.mp_seed != 0 and not session.w_off else randi()


func wrange(a: float, b: float) -> float:
	var session: BinduSession = self.session
	return session.wrng.randf_range(a, b) if session.mp_seed != 0 and not session.w_off else randf_range(a, b)


func _wpick(arr: Array) -> Variant:
	var session: BinduSession = self.session
	return arr[wi() % arr.size()] if session.mp_seed != 0 and not session.w_off else arr.pick_random()


func _wshuffle(arr: Array) -> void:
	var session: BinduSession = self.session
	if session.mp_seed == 0:
		arr.shuffle()
		return
	for i in range(arr.size() - 1, 0, -1):
		var j := wi() % (i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## 이 기기 사람이 바꿀 수 있는 오브젝트인지 (협동에서 친구 것은 아님).
func _mine(t: Tower) -> bool:
	var session: BinduSession = self.session
	return t == null or session.mp_mode != "coop" or t.owner_id == session.mp.my_id


func _my_towers() -> Array:
	var session: BinduSession = self.session
	if session.mp_mode != "coop":
		return session.towers.get_children()
	return session.towers.get_children().filter(func(t): return t.owner_id == session.mp.my_id)


func _mp_name(id: int) -> String:
	var session: BinduSession = self.session
	if id == session.mp.my_id:
		return "나"
	if Meta.blocked.has(session.mp.pids.get(id, "")):
		return "차단한 플레이어"
	var n: String = session.mp_others.get(id, {}).get("name", "")
	if n == "":
		n = session.mp.peers.get(id, {}).get("name", "")
	return n if n != "" else "플레이어 %d" % id


## 멀티플레이에서 남에게 보이는 이름 = 설정의 닉네임 (비우면 상대 화면엔 "플레이어 N"). 플랫폼은 그림으로 따로.
func _mp_begin(msg: Dictionary) -> void:
	var session: BinduSession = self.session
	session.mp.started = true
	session.mp.in_game.clear()
	for id in msg.get("ids", []):
		session.mp.in_game[int(id)] = true
	mp_start = msg.duplicate(true)
	session.mp_cursors.clear()
	mp_code_last = session.mp.code
	session.mp_mode = str(msg.get("mode", "vs"))
	session.mp.save_rejoin(session.mp_mode == "coop" and not session.mp.is_host())  # 협동 참가자만 다시 들어올 수 있다
	var m := str(msg.get("map", "plain"))
	Meta.map_id = m if m in Meta.MAP_IDS else "plain"
	Meta.line_flip = msg.get("flip", false) == true
	var r := int(msg.get("rules", 1))
	Meta.rules = r if r in Rules.IDS else 1
	Modes.set_on([])
	session.run_flow_system._apply_rules()
	session.mp_others.clear()
	var names: Dictionary = msg.get("names", {})
	for id in msg.get("ids", []):
		if int(id) != session.mp.my_id:
			var c0 := roundi(BinduSession.CORE_MAX_HP * float(Rules.tune["mp_core"]))
			session.mp_others[int(id)] = {"name": str(names.get(id, "")), "w": 0, "hp": c0, "mx": c0, "sc": 0, "alive": true, "gone": false}
	session.mp_seed = int(msg.get("seed", 1)) if session.mp_mode == "vs" else 0
	Ach.mp = session.mp_mode
	for id in session.mp_others:
		var nk: String = str(Mp.split_name(str(session.mp_others[id]["name"]))[0]).strip_edges()
		if nk != "":
			Ach.raise("mpn:" + nk.left(16), 1)
	session.mp_ghost = session.mp_mode == "coop" and not session.mp.is_host()
	BinduSession.vs_on = session.mp_mode == "vs"
	if session.mp_mode == "coop":
		BinduSession.coop_n = 1 + session.mp_others.size()
		BinduSession.coop_orbs = 1.0 + float(Rules.tune["coop_orb_per"]) * (BinduSession.coop_n - 1)
		session.auto_start = false
		session.cards_system._update_auto_btn()
	session.mp_panel.visible = false
	var tn := Meta.tutor_next
	Meta.tutor_next = false  # 멀티플레이는 첫 판 안내(카드 종류를 하나씩 엶) 없이
	session.progression_system._hide_title()
	session.lanes.clear()
	session.run_flow_system._start_choose()
	Meta.tutor_next = tn
	session.hud_system.big_banner("%s 시작! %d명" % ["대결" if session.mp_mode == "vs" else "협동", session.mp_others.size() + 1], Color(0.6, 0.9, 1.0))


func _mp_packet(from: int, msg: Dictionary) -> void:
	var session: BinduSession = self.session
	var t := str(msg.get("t", ""))
	if t == "start":
		if from == 1 and session.mp_mode == "" and session.mp.active():
			_mp_begin(msg)
		return
	if t == "re":
		if from == 1 and not session.mp.is_host() and session.mp.active():
			_mp_resync(msg)
		return
	if t == "kick" and from == 1 and session.mp_mode == "":
		# 내보내진 뒤 같은 코드로 다시 들어오려 함
		session.mp.save_rejoin(false)
		session.mp.leave()
		if session.mp_status:
			session.mp_status.text = "호스트가 판에서 내보냈어요"
		session.lobby_system._mp_refresh_lobby()
		return
	if session.mp_mode == "":
		return
	match t:
		"gone":
			session.mp_cursors.erase(from)
			if session.mp_others.has(from):
				session.mp_others[from]["gone"] = true
				if session.mp_mode == "vs" and session.mp_others[from]["alive"]:
					session.mp_others[from]["alive"] = false  # 대결은 끊기면 패배 (다시 못 들어옴)
					session.hud_system._show_toast("%s 연결이 끊겨 탈락했어요" % _mp_name(from))
				else:
					session.hud_system._show_toast("%s 연결이 끊겼어요%s" % [_mp_name(from), " (같은 방 코드로 다시 들어올 수 있어요)" if session.mp_mode == "coop" else ""])
			session.mp_ready.erase(from)
			if session.mp_mode == "coop" and session.mp.is_host():
				_mp_try_go()
			elif session.mp_mode == "vs":
				_mp_check_win()
		"st":
			if session.mp_others.has(from):
				var o: Dictionary = session.mp_others[from]
				o["w"] = int(msg.get("w", 0))
				o["hp"] = int(msg.get("hp", 0))
				o["mx"] = int(msg.get("mx", BinduSession.CORE_MAX_HP))
				o["sc"] = int(msg.get("sc", 0))
		"dead":
			if session.mp_others.has(from):
				session.mp_others[from]["alive"] = false
				session.mp_others[from]["w"] = int(msg.get("w", 0))
				session.mp_others[from]["sc"] = int(msg.get("sc", 0))
				session.hud_system._show_toast("%s 탈락 (웨이브 %d)" % [_mp_name(from), session.mp_others[from]["w"]])
				_mp_check_win()
		"atk":
			var n := int(msg.get("n", 0))
			if n <= 0 or session.phase == BinduSession.Phase.GAMEOVER:
				return
			# 한 웨이브에 받는 상한: 넘치는 만큼은 (보낸 사람 말고) 점수가 가장 높은 다른 사람에게 넘긴다 (한 번만)
			var cap := ceili((1 + (session.wave + 1) / 4) * float(Rules.tune["vs_recv_cap"]))
			var over := maxi(0, session.mp_recv_n + n - cap)
			if over > 0:
				n -= over
				if not msg.get("fw", false):
					var nxt := _mp_vs_target([from])
					if nxt > 0:
						session.mp.send({"t": "atk", "n": over, "fw": true}, nxt)
				if n <= 0:
					return
			session.mp_recv_n += n
			if session.phase == BinduSession.Phase.WAVE:
				mp_pending += n
			else:
				session.mp_next_extra += n
				session.waves_system._update_preview()
			session.hud_system._show_toast("%s가 구체 %d개를 보냈어요 (다음 웨이브에 더 옴)" % [_mp_name(from), n])
			session.sfx.play("danger", 0.0)
		"tw":
			_mp_recv_towers(from, msg.get("list", []))
		"cur":
			if session.mp_mode == "coop" and from != session.mp.my_id:
				var to := Vector2(float(msg.get("x", 0)), float(msg.get("y", 0)))
				var c: Dictionary = session.mp_cursors.get(from, {"p": to})
				c["to"] = to
				c["t"] = Time.get_ticks_msec()
				session.mp_cursors[from] = c
		"perk":
			var id := str(msg.get("id", ""))
			if BinduSession.PERKS.any(func(pk): return pk["id"] == id):
				session.perks[id] = session.perks.get(id, 0) + 1
				session.perks_system._apply_perk(id)
				session.hud_system._show_toast("%s 특성: %s (팀 전체)" % [_mp_name(from), _perk_name(id)])
		"ready":
			if session.mp.is_host():
				session.mp_ready[from] = true
				_mp_try_go()
		"wait":
			# 협동: 누군가 웨이브 시작을 눌렀다. 아직 고르는 사람은 정해진 시간 안에 고르고, 지나면 대신 고른다
			session.mp_wait_ids = (msg.get("ids", []) as Array).map(func(x): return int(x))
			session.mp_wait_show = float(msg.get("s", 0))
			if session.mp.my_id in session.mp_wait_ids and not session.mp_i_ready and session.mp_wait_left < 0.0:
				session.mp_wait_left = 2.0 if session.mp_afk else float(msg.get("s", Rules.tune["mp_wait"]))
		"afk":
			if session.mp_others.has(from):
				session.mp_others[from]["afk"] = msg.get("on", false) == true
		"kick":
			if from == 1 and session.mp_mode == "coop" and session.phase != BinduSession.Phase.GAMEOVER:
				session.mp.save_rejoin(false)
				session.mp_rank = "호스트가 판에서 내보냈어요"
				session.mp_fail_msg = session.mp_rank
				session.core_hp = 0
				session.run_flow_system._game_over()
		"gift":
			session.lobby_system._mp_recv_gift(from, msg)
		"wave":
			if session.mp_ghost and from == 1:
				session.lobby_system._mp_wait_end()
				session.wave = int(msg.get("w", session.wave + 1)) - 1
				session.mp_wave_go = true
				_end_ghost_rest()
				session.run_flow_system._start_wave()
				session.mp_wave_go = false
				session.mp_i_ready = false
		"next":
			if session.mp_ghost and from == 1:
				mp_next = msg
				if int(msg.get("w", -1)) == session.wave:
					_mp_ghost_rest()
					session.waves_system._update_preview()
		"snap":
			if session.mp_ghost and from == 1:
				_mp_apply_snap(msg)
		"clear":
			if session.mp_ghost and from == 1 and session.phase == BinduSession.Phase.WAVE:
				_mp_ghost_clear(msg)
		"over":
			if session.mp_ghost and from == 1 and session.phase != BinduSession.Phase.GAMEOVER:
				session.score = int(msg.get("sc", session.score))
				session.kills = int(msg.get("k", session.kills))
				session.wave = int(msg.get("w", session.wave))
				session.core_hp = 0
				session.run_flow_system._game_over()


## 협동 호스트: 끊겼던 참가자가 같은 자리로 다시 이어짐 → 지금 판 상태를 통째로 보낸다.
func _mp_peer_up(id: int) -> void:
	var session: BinduSession = self.session
	if session.mp_mode != "coop" or not session.mp.is_host() or not session.mp_others.has(id) or session.phase == BinduSession.Phase.GAMEOVER:
		return
	if session.mp_kicked.has(id):
		session.mp.send({"t": "kick"}, id)  # 내보낸 사람은 다시 들어올 수 없다
		return
	session.mp_others[id]["gone"] = false
	var st := mp_start.duplicate(true)
	st["t"] = "re"
	var ids: Array = [1] + session.mp_others.keys()
	var names := {1: session.mp.my_name}
	for k in session.mp_others:
		names[k] = session.mp_others[k]["name"]
	st["ids"] = ids
	st["names"] = names
	var tw := {}
	for t in session.towers.get_children():
		if t.is_queued_for_deletion():
			continue
		if not tw.has(t.owner_id):
			tw[t.owner_id] = []
		tw[t.owner_id].append(t.mp_state())
	st.merge({"w": session.wave, "ph": "wave" if session.phase == BinduSession.Phase.WAVE else "rest", "sc": session.score, "k": session.kills, "hp": session.core_hp, "mx": session.core_max,
		"perks": session.perks.duplicate(), "tw": tw, "next": {"t": "next", "w": session.wave, "lanes": Array(session.lanes), "res": session.wave_resist, "boss": session.boss_plan}}, true)
	session.mp.send(st, id)
	session.hud_system._show_toast("%s 다시 들어왔어요" % _mp_name(id))


## 협동 참가자: 호스트가 보낸 판 상태로 맞춘다 (끊겼다 다시 붙음, 또는 게임을 껐다 켜고 같은 코드로 들어옴).
## 쉬는 시간이면 카드 고르기 없이 웨이브 기다림으로 (다시 들어와 카드를 더 받지 않게).
func _mp_resync(msg: Dictionary) -> void:
	var session: BinduSession = self.session
	var fresh := session.mp_mode == ""
	session.mp_rejoin_until = 0
	session.mp_rejoin_wait = 0.0
	for t in session.towers.get_children():
		session.towers.remove_child(t)
		t.queue_free()
	session.interaction_system.selected.clear()
	for o in session.orbs.get_children():
		o.queue_free()
	mp_ghosts.clear()
	if fresh:
		_mp_begin(msg)
		for id in msg.get("perks", {}):
			for i in int(msg["perks"][id]):
				if BinduSession.PERKS.any(func(pk): return pk["id"] == id):
					session.perks[id] = session.perks.get(id, 0) + 1
					session.perks_system._apply_perk(id)
	else:
		session.mp.started = true
		mp_code_last = session.mp.code
		session.mp.save_rejoin(true)
		for id in session.mp_others:
			session.mp_others[id]["gone"] = false
	session.score = int(msg.get("sc", 0))
	session.kills = int(msg.get("k", 0))
	session.core_max = int(msg.get("mx", session.core_max))
	session.core_hp = int(msg.get("hp", session.core_hp))
	var tw: Dictionary = msg.get("tw", {})
	session.mp_tw_n = 0
	for owner in tw:
		for d in tw[owner]:
			if not d is Dictionary:
				continue
			var t := Tower.new()
			t.main = session
			t.owner_id = int(owner)
			t.net_id = int(d.get("nid", 0))
			t.mp_apply(d)
			if t.order.is_empty():
				t.free()
				continue
			session.towers.add_child(t)
			if t.owner_id == session.mp.my_id:
				session.mp_tw_n = maxi(session.mp_tw_n, t.net_id % 100000)
	mp_tw_sig = ""
	_end_ghost_rest()
	mp_next = msg.get("next", {})
	if str(msg.get("ph", "rest")) == "wave":
		session.wave = int(msg.get("w", 1)) - 1
		mp_next["w"] = session.wave  # 호스트가 지금 웨이브 진입 방향을 보냈다 (평소 next는 쉬는 시간에 지난 웨이브 번호로)
		_mp_ghost_rest()
		session.mp_wave_go = true
		session.run_flow_system._start_wave()
		session.mp_wave_go = false
	else:
		session.wave = int(msg.get("w", 0))
		_mp_ghost_rest()
		session.cards_system._enter_ready()
		session.waves_system._update_preview()
	session.mp_i_ready = false
	session.hud_system._refresh_dps()
	session.hud_system._show_toast("다시 들어왔어요 (웨이브 %d)" % maxi(session.wave, 1))


func _perk_name(id: String) -> String:
	for pk in BinduSession.PERKS:
		if pk["id"] == id:
			return pk["name"]
	return id


func _mp_send_perk(id: String) -> void:
	var session: BinduSession = self.session
	if session.mp_mode == "coop":
		session.mp.send({"t": "perk", "id": id})


## 매 프레임: 상태·오브젝트·전장 보내기, 위쪽 상태 줄.
func _mp_tick(delta: float) -> void:
	var session: BinduSession = self.session
	if session.mp_mode == "":
		return
	if session.mp_mode == "coop":
		_mp_cursor_tick(delta)
	if session.mp_rejoin_wait > 0.0:
		session.mp_rejoin_wait -= delta
		if session.mp_rejoin_wait <= 0.0:
			session.mp.join(mp_code_last, session._mp_my_name())
	session.lobby_system._mp_afk_tick(delta)
	mp_tick_t += delta
	mp_snap_t += delta
	if session.mp_mode == "vs" and mp_tick_t >= 0.5:
		mp_tick_t = 0.0
		var ws: Array = session.mp_others.values().filter(func(o): return o["alive"] and not o["gone"]).map(func(o): return int(o["w"]))
		if not ws.is_empty() and session.wave < ws.min() and session.phase != BinduSession.Phase.GAMEOVER:
			mp_was_last = true  # 역전 업적: 한때 웨이브 꼴찌
		var sig := "%d/%d/%d/%d" % [session.wave, session.core_hp, session.core_max, session.score]
		if sig != mp_st_sig and session.phase != BinduSession.Phase.GAMEOVER:
			mp_st_sig = sig
			session.mp.send({"t": "st", "w": session.wave, "hp": session.core_hp, "mx": session.core_max, "sc": session.score})
	if session.mp_mode == "coop":
		if mp_tick_t >= 0.25 and session.phase != BinduSession.Phase.GAMEOVER:
			mp_tick_t = 0.0
			_mp_send_towers()
		if session.mp.is_host() and session.phase == BinduSession.Phase.WAVE and mp_snap_t >= 1.0 / 12.0:
			mp_snap_t = 0.0
			_mp_send_snap()
	session.mp_bar.visible = not session.title_label.visible
	session.mp_bar.position = Vector2(session.hud.position.x + 2.0, session.hud.position.y + session.hud.size.y + 4.0)
	var mine_n := _my_towers().size() if session.mp_mode == "coop" else 0
	session.mp_req_btn.visible = session.mp_mode == "coop" and session.phase in [BinduSession.Phase.CHOOSE, BinduSession.Phase.READY] and not session.perk_mode and mine_n > 0
	session.mp_kick_btn.visible = session.mp_mode == "coop" and session.mp.is_host() and session.phase != BinduSession.Phase.GAMEOVER \
		and session.mp_others.keys().any(func(id): return not session.mp_kicked.has(id))
	session.mp_view_btn.visible = session.mp_mode == "coop" and session.phase != BinduSession.Phase.GAMEOVER
	if session.phase == BinduSession.Phase.GAMEOVER:
		session.mp_view = 0  # 끝 화면에선 모두 보이게
	if session.mp_view > 0 and session.mp_view != session.mp.my_id and (not session.mp_others.has(session.mp_view) or session.mp_others[session.mp_view].get("gone", false)):
		session.mp_view = 0  # 고른 사람이 나감
	session.mp_view_btn.text = "보기: " + ("모두" if session.mp_view == 0 else _mp_name(session.mp_view))
	if session.mp_view > 0:
		session.mp_view_btn.add_theme_color_override("font_color", Mp.owner_color(session.mp_view))
	else:
		session.mp_view_btn.remove_theme_color_override("font_color")
	if session.mp_mode == "coop":
		session.lobby_system._mp_view_fade(delta)
	session.mp_act.visible = session.mp_bar.visible and (session.mp_req_btn.visible or session.mp_kick_btn.visible or session.mp_view_btn.visible)
	session.mp_act.position = session.mp_bar.position + Vector2(0, session.mp_bar.size.y + 2.0)
	if not session.mp_req_btn.visible and session.mp_req_mode:
		session.mp_req_mode = false
		session.mp_req_btn.text = "속성 요청"
	if session.mp_bar.visible:
		var parts := PackedStringArray()
		if session.mp_mode == "vs":
			for id in session.mp_others:
				var o: Dictionary = session.mp_others[id]
				var nm := _mp_name(id)
				if o["gone"] and o["alive"]:
					parts.append("%s 연결 끊김" % nm)
				elif not o["alive"]:
					parts.append("%s 탈락 W%d" % [nm, o["w"]])
				else:
					parts.append("%s W%d ♥%d/%d %s점%s" % [nm, o["w"], o["hp"], o["mx"], session.num(o["sc"]), _mp_bar_ping(id)])
			session.mp_bar.text = "대결 · " + "   |   ".join(parts)
		else:
			for id in session.mp_others:
				var tag := " (끊김)" if session.mp_others[id]["gone"] else _mp_bar_ping(id)
				if session.mp_others[id].get("afk", false) and not session.mp_others[id]["gone"]:
					tag = " (자리 비움)"
				elif id in session.mp_wait_ids and session.mp_wait_show > 0.0 and not session.mp_others[id]["gone"]:
					tag = " (고르는 중 %d초)" % ceili(session.mp_wait_show)
				parts.append("%s%s" % [_mp_name(id), tag])
			var me := "호스트" if session.mp.is_host() else "참가"
			if session.mp_afk:
				me += ", 자리 비움"
			elif session.mp_wait_left > 0.0:
				me += ", %d초 뒤 대신 고름" % ceili(session.mp_wait_left)
			session.mp_bar.text = "협동 · 나(%s) + %s" % [me, ", ".join(parts)]
			if session.mp_rejoin_until > 0:
				session.mp_bar.text = "협동 · 다시 접속하는 중… %d초" % maxi(0, (session.mp_rejoin_until - Time.get_ticks_msec()) / 1000)
			session.mp_bar.add_theme_color_override("font_color", Mp.owner_color(session.mp.my_id))


## 협동: 내 마우스 위치를 보내고(움직였을 때만, 초당 MP_CUR_HZ번) 받은 위치를 따라간다.
func _mp_cursor_tick(delta: float) -> void:
	var session: BinduSession = self.session
	mp_cur_t += delta
	if mp_cur_t >= 1.0 / BinduSession.MP_CUR_HZ:
		mp_cur_t = 0.0
		var m := session.interaction_system._pointer_world()
		if m.distance_to(mp_cur_last) > 1.0 and not session.title_label.visible:
			mp_cur_last = m
			session.mp.send({"t": "cur", "x": roundf(m.x), "y": roundf(m.y)}, 0, false)
	var k := 1.0 - exp(-14.0 * delta)
	for id in session.mp_cursors:
		var c: Dictionary = session.mp_cursors[id]
		c["p"] = (c["p"] as Vector2).lerp(c["to"], k)
	if not session.mp_cursors.is_empty():
		mp_cur_layer.queue_redraw()


## 다른 사람 커서: 주인 색 화살표 + 닉네임. 화면 확대와 상관없이 같은 크기.
func _draw_mp_cursors() -> void:
	var session: BinduSession = self.session
	if session.mp_mode != "coop":
		return
	var now := Time.get_ticks_msec()
	var z := 1.0 / maxf(0.01, session.camera.zoom.x) if session.camera else 1.0
	for id in session.mp_cursors:
		var c: Dictionary = session.mp_cursors[id]
		var age: int = now - int(c["t"])
		if age > BinduSession.MP_CUR_HIDE_MS:
			continue
		var a := clampf((BinduSession.MP_CUR_HIDE_MS - age) / 1000.0, 0.0, 1.0)
		var col := Color(Mp.owner_color(id), a)
		var p: Vector2 = c["p"]
		var tri := PackedVector2Array([p, p + Vector2(0, 22) * z, p + Vector2(6, 17) * z, p + Vector2(14, 16) * z])
		mp_cur_layer.draw_colored_polygon(tri, col)
		tri.append(p)
		mp_cur_layer.draw_polyline(tri, Color(0, 0, 0, 0.7 * a), 1.5 * z, true)
		var nm := _mp_name(id)
		var fs := 13
		mp_cur_layer.draw_set_transform(p + Vector2(16, 28) * z, 0.0, Vector2(z, z))
		mp_cur_layer.draw_string_outline(session.ui_font, Vector2.ZERO, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75 * a))
		mp_cur_layer.draw_string(session.ui_font, Vector2.ZERO, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		mp_cur_layer.draw_set_transform(Vector2.ZERO)


func _mp_bar_ping(id: int) -> String:
	var session: BinduSession = self.session
	return " · %dms" % session.mp.ping[id] if session.mp.ping.has(id) else ""


## 쉬는 시간 시작 (_new_rest 안): 대결은 받아 둔 구체를 예고에, 협동 호스트는 다음 웨이브를 참가자에게.
func _mp_rest_begin() -> void:
	var session: BinduSession = self.session
	if session.mp_mode == "vs":
		session.mp_next_extra += mp_pending
		mp_pending = 0
	elif session.mp_mode == "coop" and session.mp.is_host():
		session.mp.send({"t": "next", "w": session.wave, "lanes": Array(session.lanes), "res": session.wave_resist, "boss": session.boss_plan})


## 대결: 상대가 보낸 구체를 웨이브 동안 섞어 내보낸다 (같은 웨이브 순서를 흐트리지 않게 씨앗 밖에서 뽑음).
func _mp_spawn_extra(delta: float) -> void:
	var session: BinduSession = self.session
	if randf() > delta * 1.2:
		return
	session.mp_extra_left -= 1
	session.w_off = true
	session.spawning_system._spawn_orb()
	session.w_off = false


## 대결: 웨이브를 막았을 때. 중앙이 한 번도 안 맞았으면 상대에게 구체를 보낸다.
## 협동 호스트: 참가자에게 웨이브 끝을 알린다.
func _mp_wave_cleared() -> void:
	var session: BinduSession = self.session
	if session.mp_mode == "coop" and session.mp.is_host():
		var sh := _mp_shares()
		session.mp.send({"t": "clear", "w": session.wave, "perk": session.wave % 5 == 0, "sc": session.score, "hp": session.core_hp, "mx": session.core_max, "k": session.kills, "sh": sh})
		_mp_ach_coop(session.wave, sh)
		return
	if session.mp_mode != "vs":
		return
	if session.wave_dmg == 0 and session.mp_wave_extra > 0:
		Ach.raise("max:mp_counter", 1)
	_mp_ach_win()
	if session.wave_dmg > 0:
		session.progression_system._ach_check()
		return
	var to := _mp_vs_target([])
	if to <= 0:
		session.progression_system._ach_check()
		return
	var n := maxi(1, roundi((1 + session.wave / 4) * _mp_send_k()))
	session.mp.send({"t": "atk", "n": n}, to)
	Ach.add("mp_sent", n)
	session.progression_system._ach_check()
	session.hud_system._show_toast("완벽 방어! %s에게 구체 %d개를 보냈어요" % [_mp_name(to), n])


## 대결: 보내는 구체 배율. 살아 있는 사람이 많을수록 줄인다 (1위가 여럿에게 한꺼번에 받지 않게).
func _mp_send_k() -> float:
	var session: BinduSession = self.session
	var n := 1 + session.mp_others.values().filter(func(o): return o["alive"] and not o["gone"]).size()
	if n <= 2:
		return 1.0
	return float(Rules.tune["vs_send3"]) if n == 3 else float(Rules.tune["vs_send4"])


## 대결: 구체를 받을 사람 = 살아 있는 상대 중 점수가 가장 높은 사람 (skip은 빼고). 없으면 0.
func _mp_vs_target(skip: Array) -> int:
	var session: BinduSession = self.session
	var alive: Array = session.mp_others.keys().filter(func(id): return session.mp_others[id]["alive"] and not session.mp_others[id]["gone"] and not id in skip)
	if alive.is_empty():
		return 0
	alive.sort_custom(func(a, b): return session.mp_others[a]["sc"] > session.mp_others[b]["sc"])
	return alive[0]


## 협동 호스트: 사람마다 판 전체 피해 비중 {id: 0~1}.
func _mp_shares() -> Dictionary:
	var session: BinduSession = self.session
	var by := {}
	var total := 0.0
	for t in session.towers.get_children():
		var d: float = t.run_dealt + t.dealt
		by[t.owner_id] = by.get(t.owner_id, 0.0) + d
		total += d
	var out := {}
	for id in [1] + session.mp_others.keys():
		out[id] = snappedf(by.get(id, 0.0) / total, 0.001) if total > 0.0 else 0.0
	return out


## 협동 업적: 웨이브 w를 막음 (sh: 사람마다 피해 비중).
func _mp_ach_coop(w: int, sh: Dictionary) -> void:
	var session: BinduSession = self.session
	Ach.raise("max:mp_coop", w)
	if BinduSession.coop_n >= 4:
		Ach.raise("max:mp_coop4", w)
	if w >= 12 and sh.size() >= 2:
		if sh.values().all(func(v): return float(v) >= 0.2):
			Ach.raise("max:mp_even", 1)
		var mine := 0.0
		for k in sh:
			if int(k) == session.mp.my_id:
				mine = float(sh[k])
		if mine >= 0.6:
			Ach.raise("max:mp_carry", 1)
	session.progression_system._ach_check()


## 대결 승리 업적: 상대가 모두 빠졌고 내 웨이브가 5 이상일 때 한 번.
func _mp_ach_win() -> void:
	var session: BinduSession = self.session
	if not mp_won or mp_win_counted or session.wave < 5 or session.mp_mode != "vs":
		return
	mp_win_counted = true
	Ach.add("mp_wins")
	if session.mp_others.size() + 1 >= 4:
		Ach.add("mp_wins4")
	if mp_was_last:
		Ach.raise("max:mp_comeback", 1)
	session.progression_system._ach_check()


## 대결·협동: 이 기기가 끝났을 때.
func _mp_over() -> void:
	var session: BinduSession = self.session
	if session.mp_mode == "vs":
		session.mp.send({"t": "dead", "w": session.wave, "sc": session.score})
		var rows: Array = [[session.mp.my_id, session.wave, session.score]]
		for id in session.mp_others:
			var o: Dictionary = session.mp_others[id]
			rows.append([id, o["w"], o["sc"], o["alive"] and not o["gone"]])
		rows.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[2] > b[2]))
		var place := 1 + session.mp_others.values().filter(func(o): return o["alive"] and not o["gone"]).size()
		var ls := PackedStringArray()
		for r in rows:
			ls.append("%s W%d%s" % [_mp_name(r[0]), r[1], " (진행 중)" if r.size() > 3 and r[3] else ""])
		session.mp_rank = "대결 %d위 / %d명 · %s" % [place, session.mp_others.size() + 1, " · ".join(ls)]
	elif session.mp_mode == "coop":
		session.mp.save_rejoin(false)
		if session.mp.is_host():
			session.mp.send({"t": "over", "w": session.wave, "sc": session.score, "k": session.kills})
		if session.mp_rank == "":
			session.mp_rank = "협동 %d명 · 함께 웨이브 %d까지" % [session.mp_others.size() + 1, session.wave]


## 대결: 다른 사람이 모두 탈락하면 승리 (판은 계속할 수 있다).
func _mp_check_win() -> void:
	var session: BinduSession = self.session
	if session.phase == BinduSession.Phase.GAMEOVER or session.mp_others.is_empty():
		return
	if session.mp_others.values().all(func(o): return not o["alive"] or o["gone"]):
		if mp_won:
			return
		mp_won = true
		session.hud_system.big_banner("승리! 끝까지 버텨 기록을 늘려 보세요", Color(1, 0.85, 0.3))
		session.sfx.play("clear", 0.0)
		_mp_ach_win()


# --- 협동 ---

## 웨이브 시작을 누름: 모두 누르면 호스트가 시작한다.
func _mp_coop_ready() -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.READY:
		return
	session.mp_wait_left = -1.0
	if not session.mp_auto_now:
		session.mp_afk_n = 0  # 스스로 눌렀다
	if session.mp.is_host():
		session.mp_ready[1] = true
		_mp_try_go()
	elif not session.mp_i_ready:
		session.mp_i_ready = true
		session.mp.send({"t": "ready"}, 1)
		session.start_btn.text = "친구를 기다리는 중…"


## force: 기다림이 다 지나 안 누른 사람(응답 없는 기기)을 두고 시작.
func _mp_try_go(force := false) -> void:
	var session: BinduSession = self.session
	var need: Array = session.mp.connected_ids()
	var have := need.filter(func(id): return session.mp_ready.get(id, false)).size()
	var host_ok: bool = session.mp_ready.get(1, false) and session.phase == BinduSession.Phase.READY
	if force and not host_ok and session.phase != BinduSession.Phase.GAMEOVER and session.phase != BinduSession.Phase.WAVE:
		session.mp_host_wait = 999.0  # 대신 고르는 동안 기다림 알림을 다시 보내지 않게
		session.lobby_system._mp_auto_rest()  # 호스트 자신이 잠수: 대신 고르고 준비
		session.mp_host_wait = -1.0
		if session.phase == BinduSession.Phase.READY:
			session.mp_ready[1] = true
			_mp_try_go(true)
		return
	if not force and (not host_ok or have < need.size()):
		if (host_ok or have > 0) and session.mp_host_wait < 0.0:
			# 누군가 눌렀다: 남은 사람에게 기다림 시간을 알린다
			var w: float = Rules.tune["mp_wait"]
			session.mp_host_wait = w + float(Rules.tune["mp_wait_force"])
			var left: Array = ([] if host_ok else [1]) + need.filter(func(id): return not session.mp_ready.get(id, false))
			session.mp.send({"t": "wait", "s": w, "ids": left})
			_mp_packet(1, {"t": "wait", "s": w, "ids": left})  # 호스트 자신에게도
		if host_ok:
			session.start_btn.text = "친구를 기다리는 중 (%d/%d)" % [have + 1, need.size() + 1]
		return
	if session.phase != BinduSession.Phase.READY:
		return
	session.mp_ready.clear()
	session.lobby_system._mp_wait_end()
	session.mp.send({"t": "wave", "w": session.wave + 1})
	session.mp_wave_go = true
	session.run_flow_system._start_wave()
	session.mp_wave_go = false


## 참가자: 호스트가 웨이브를 시작했는데 아직 고르는 중이면 그대로 닫는다.
func _end_ghost_rest() -> void:
	var session: BinduSession = self.session
	if session.phase in [BinduSession.Phase.PLACE, BinduSession.Phase.AIM, BinduSession.Phase.MOVE]:
		session.interaction_system._cancel_step()
	session.perk_mode = false
	session.choice_box.visible = false


## 참가자의 쉬는 시간: 다음 웨이브는 호스트가 보낸 것으로.
func _mp_ghost_rest() -> void:
	var session: BinduSession = self.session
	if int(mp_next.get("w", -1)) != session.wave:
		return
	session.lanes.assign((mp_next.get("lanes", []) as Array).filter(func(a): return a is float))
	session.wave_resist = int(mp_next.get("res", -1))
	var bp: Variant = mp_next.get("boss", {})
	session.boss_plan = bp if bp is Dictionary else {}


## 참가자: 호스트 웨이브가 끝남 → 이 기기도 쉬는 시간.
func _mp_ghost_clear(msg: Dictionary) -> void:
	var session: BinduSession = self.session
	session.wave = int(msg.get("w", session.wave))
	session.score = int(msg.get("sc", session.score))
	session.kills = int(msg.get("k", session.kills))
	session.core_max = int(msg.get("mx", session.core_max))
	session.core_hp = int(msg.get("hp", session.core_hp))
	for o in session.orbs.get_children():
		o.queue_free()
	mp_ghosts.clear()
	session.combo_hold = true
	session.hud_system._show_toast("웨이브 %d 클리어!" % session.wave)
	session.sfx.play("clear", 0.0)
	session.spawning_system._show_mvp()
	var sh: Variant = msg.get("sh", {})
	_mp_ach_coop(session.wave, sh if sh is Dictionary else {})
	if bool(msg.get("perk", false)):
		session.perks_system._start_perk()
	else:
		session.run_flow_system._start_choose()


## 호스트: 전장 구체 상태를 보낸다 [번호, x, y, 체력, 최대, 종류, 보호막, 저항+1, 굳셈 + 2x(후반 구체 번호+1)].
func _mp_send_snap() -> void:
	var session: BinduSession = self.session
	var o_list := PackedFloat32Array()
	for o in session.orbs.get_children():
		if o.is_queued_for_deletion():
			continue
		if o.net_id == 0:
			mp_orb_n += 1
			o.net_id = mp_orb_n
		o_list.append_array([o.net_id, o.position.x, o.position.y, o.hp, o.max_hp, o.kind, o.shield, o.resist_e + 1, (1.0 if o.sturdy else 0.0) + 2.0 * (BinduSession.LATE_IDS.find(o.late) + 1)])
	session.mp.send({"t": "snap", "w": session.wave, "hp": session.core_hp, "mx": session.core_max, "sc": session.score, "k": session.kills, "cb": session.combo, "o": o_list}, 0, false)


func _mp_apply_snap(msg: Dictionary) -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.WAVE or int(msg.get("w", -1)) != session.wave:
		return
	var hp := int(msg.get("hp", session.core_hp))
	if hp < session.core_hp:
		session.sfx.play("core", 0.0)
		session.shake = 0.25
		session.core_flash = 0.4
		session.hud_system._show_toast("중앙 피격! %d/%d" % [maxi(hp, 0), session.core_max])
	session.core_hp = hp
	session.core_max = int(msg.get("mx", session.core_max))
	session.score = int(msg.get("sc", session.score))
	session.kills = int(msg.get("k", session.kills))
	session.combo = int(msg.get("cb", session.combo))
	session.best_combo = maxi(session.best_combo, session.combo)
	session.combat_system._check_danger()
	var arr: PackedFloat32Array = msg.get("o", PackedFloat32Array())
	var seen := {}
	var i := 0
	while i + 8 < arr.size():
		var id := int(arr[i])
		seen[id] = true
		var o: Orb = mp_ghosts.get(id)
		var pos := Vector2(arr[i + 1], arr[i + 2])
		if o == null or not is_instance_valid(o):
			o = Orb.new()
			o.main = session
			o.ghost = true
			o.net_id = id
			o.setup(int(arr[i + 5]), arr[i + 4], 30.0)
			o.position = pos
			o.target = session.viewport_system.center()
			o.from_a = (pos - session.viewport_system.center()).angle()
			session.orbs.add_child(o)
			mp_ghosts[id] = o
		o.net_pos = pos
		o.hp = arr[i + 3]
		o.max_hp = arr[i + 4]
		o.shield = arr[i + 6]
		o.resist_e = int(arr[i + 7]) - 1
		var sl := roundi(arr[i + 8])
		o.sturdy = sl % 2 == 1
		o.late = BinduSession.LATE_IDS[sl / 2 - 1] if sl >= 2 and sl / 2 - 1 < BinduSession.LATE_IDS.size() else ""
		i += 9
	for id in mp_ghosts.keys():
		if not seen.has(id):
			var o: Orb = mp_ghosts[id]
			if is_instance_valid(o):
				if o.position.distance_to(session.viewport_system.center()) > 40.0:
					session.spawning_system.burst(o.position, o.death_color(), 10 if o.kind != Orb.Kind.BOSS else 40, 180.0)
					session.sfx.play("kill", 0.15)
				o.queue_free()
			mp_ghosts.erase(id)


## 내 오브젝트가 바뀌었으면 다른 기기로 보낸다.
func _mp_send_towers() -> void:
	var session: BinduSession = self.session
	var list: Array = []
	for t in _my_towers():
		list.append(t.mp_state())
	var sig := var_to_str(list)
	if sig == mp_tw_sig:
		return
	mp_tw_sig = sig
	session.mp.send({"t": "tw", "list": list})


func _mp_recv_towers(owner: int, list: Variant) -> void:
	var session: BinduSession = self.session
	if not list is Array or owner == session.mp.my_id:
		return
	var keep := {}
	for d in list:
		if not d is Dictionary:
			continue
		var nid := int(d.get("nid", 0))
		if nid / 100000 != owner:
			continue  # 남의 번호로 보낸 것
		keep[nid] = true
		var t: Tower = null
		for x in session.towers.get_children():
			if x.net_id == nid:
				t = x
				break
		if t == null:
			t = Tower.new()
			t.main = session
			t.owner_id = owner
			t.net_id = nid
			t.mp_apply(d)
			if t.order.is_empty():
				t.free()
				continue
			session.towers.add_child(t)
			t.place_pop = 1.0
		else:
			t.mp_apply(d)
	for x in session.towers.get_children():
		if x.owner_id == owner and not keep.has(x.net_id):
			if x in session.interaction_system.selected:
				session.interaction_system.selected.erase(x)
			x.queue_free()
