class_name BinduOnline
extends BinduFeature
## 온라인 부팅·업데이트와 원격 판 연결. 예약 콜백은 main의 순서를 따른다.

var remote_run := ""  # remote_btn이 가져올 판
var updater: Updater  # Windows·macOS 게임 안 업데이트
var update_release := {}  # 실패 후에도 같은 릴리스를 다시 시도한다.
func _on_booted(info: Dictionary) -> void:
	var session: BinduSession = self.session
	if info.is_empty() or session.update_btn == null:
		return
	if session.title_label.visible:
		session.run_flow_system._apply_rules()
		session.menu_system._refresh_menu()
	var latest: Variant = info.get("latest")
	# 모바일은 해당 플랫폼의 스토어·TestFlight 주소만 연다.
	if latest is Dictionary and not update_url_allowed(str(latest.get("url", "")), Net.platform()):
		latest = null
	if latest is Dictionary and str(latest.get("url", "")) != "" and not updater.busy:
		_show_update(latest, Updater.available(latest))
	elif not updater.busy:
		update_release = {}
		session.update_btn.visible = false  # 다시 물어보니 새 버전이 없음 (서버에서 내림)
	var msg := Patch.text("", "message", "")
	session.notice_label.text = session.patchlog_system._kr_keep(msg)
	session.notice_label.visible = msg != ""
	if Net.acct_ok():
		session.net.sync()  # 진행을 계정 것과 합친다 (다른 기기에서 한 것)
		if session.title_label.visible:
			session.net.list_runs()


static func update_url_allowed(url: String, platform: String) -> bool:
	match platform:
		"ios":
			return url.begins_with("https://apps.apple.com/") or url.begins_with("https://testflight.apple.com/join/")
		"android":
			return url.begins_with("https://play.google.com/store/apps/")
	return url.begins_with("https://")


func _show_update(latest: Dictionary, auto: bool) -> void:
	update_release = latest.duplicate(true)
	var release := update_release
	var notes := str(release.get("notes", ""))
	session.update_btn.text = "업데이트"
	session.update_btn.tooltip_text = "새 버전 v%s%s\n%s" % [release.get("version", "?"), "\n" + notes if notes != "" else "", "다운로드 후 자동으로 다시 시작해요" if auto else "배포 페이지에서 업데이트해요"]
	session.update_btn.disabled = false
	session.update_btn.visible = true
	_set_update_action(func(): _start_update(release) if auto else _open_update_url(str(release["url"])))


func _open_update_url(url: String) -> void:
	if OS.shell_open(url) != OK:
		session.hud_system._show_toast("업데이트 페이지를 열지 못했어요. 다시 시도해 주세요")


## 다른 기기 진행과 합쳐졌다: 저장하고 시작 화면 글(최고 기록·해금)을 다시 쓴다.
func _on_progress_synced() -> void:
	var session: BinduSession = self.session
	var b := Meta.best_of(Meta.run_key())
	session.best_wave = maxi(session.best_wave, b[0])
	session.best_score = maxi(session.best_score, b[1])
	session.progression_system._ach_catch_up()
	session.progression_system._save_best()
	if session.title_label.visible:
		Modes.set_on(Meta.modes if Meta.games > 0 else [])
		session.run_flow_system._apply_rules()
		session.menu_system._refresh_menu()


## 계정의 진행 중 판 목록: 이 기기 판을 다른 기기가 가져갔으면 지우고, 이 기기에 판이 없으면 다른 기기 판을 이어 하게.
func _on_runs_listed(list: Array) -> void:
	var session: BinduSession = self.session
	var local := _local_run_key()
	remote_run = ""
	for e in list:
		if not e is Dictionary:
			continue
		if str(e.get("run", "")) == local and local != "" and not e.get("mine", true):
			_on_run_moved(local)
			local = ""
	if local == "" and not FileAccess.file_exists(BinduSession.RUN_PATH):
		for e in list:
			if e is Dictionary and not e.get("mine", true) and Net.same_minor(str(e.get("game", "")), Net.game_version()) and str(e.get("map", "")) in Meta.MAP_IDS:
				remote_run = str(e["run"])
				session.remote_btn.text = "다른 기기에서 하던 판 이어하기   웨이브 %d부터 · %s" % [int(e.get("wave", 0)) + 1, Meta.MAPS[str(e["map"])]["name"]]
				break
	session.remote_btn.visible = remote_run != "" and session.title_label.visible
	session.remote_btn.disabled = false


func _claim_remote_run() -> void:
	var session: BinduSession = self.session
	if remote_run == "":
		return
	session.remote_btn.disabled = true
	session.remote_btn.text = "가져오는 중..."
	session.net.claim_run(remote_run)


func _on_run_claimed(d: Dictionary) -> void:
	var session: BinduSession = self.session
	session.remote_btn.visible = false
	var cfg := ConfigFile.new()
	if d.is_empty() or cfg.parse(str(d.get("data", ""))) != OK or Meta.val(cfg, "run", "format", 0) != BinduSession.RUN_FORMAT:
		session.hud_system._show_toast("다른 기기의 판을 가져오지 못했어요")
		return
	cfg.save(BinduSession.RUN_PATH)
	session.moved_run = ""
	session.persistence_system._refresh_continue()
	if session.title_label.visible and session.continue_btn.visible:
		session.persistence_system._continue_run()


## 다른 기기가 이 판을 가져갔다: 시작 화면이면 이어하기를 지우고, 하는 중이면 계속 하되 서버에는 더 올리지 않는다.
func _on_run_moved(key: String) -> void:
	var session: BinduSession = self.session
	if session.title_label.visible and _local_run_key() == key:
		session.persistence_system._clear_run(false)
		session.persistence_system._refresh_continue()
		session.hud_system._show_toast("하던 판은 다른 기기에서 이어 하고 있어요")
	elif session.run_id == key and session.moved_run != key:
		session.moved_run = key
		session.hud_system._show_toast("이 판을 다른 기기에서 이어 하고 있어요. 여기서 계속 해도 다른 기기로는 넘어가지 않아요")


func _local_run_key() -> String:
	var cfg := ConfigFile.new()
	return str(Meta.val(cfg, "run", "run_id", "")) if cfg.load(BinduSession.RUN_PATH) == OK else ""


func _set_update_action(f: Callable) -> void:
	var session: BinduSession = self.session
	for c in session.update_btn.pressed.get_connections():
		session.update_btn.pressed.disconnect(c["callable"])
	session.update_btn.pressed.connect(f)


## [업데이트]: 받는 동안 버튼이 진행률을 보여 주고, 다 되면 새 버전으로 다시 켜진다.
func _start_update(latest: Dictionary) -> void:
	var session: BinduSession = self.session
	session.update_btn.disabled = true
	session.update_btn.text = "업데이트 받는 중..."
	updater.start(latest)


func _on_update_progress(ratio: float) -> void:
	var session: BinduSession = self.session
	session.update_btn.text = "업데이트 받는 중 %d%%" % int(ratio * 100) if ratio >= 0.0 else "업데이트 받는 중..."


## 실패하면 원래 버전 그대로: [업데이트]로 앱 안에서 다시 시도한다.
func _on_update_failed(reason: String) -> void:
	var session: BinduSession = self.session
	if not update_release.is_empty():
		_show_update(update_release, true)
		session.update_btn.tooltip_text = "업데이트 실패: %s\n다시 눌러 시도해 주세요" % reason
	session.hud_system._show_toast("업데이트 실패: %s. 다시 시도해 주세요" % reason)


func _submit_run(done := true) -> void:
	var session: BinduSession = self.session
	if not Net.enabled() or session.mp_mode != "" or TutPlay.on:
		return
	var ts := session.towers.get_children()
	var total := 0.0
	for t in ts:
		total += t.run_dealt + t.dealt
	var list: Array = []
	for t in ts:
		var els := {}
		for e in t.elements:
			els[Patch.ELEM_KEYS[Elem.ALL.find(e)]] = t.elements[e]
		list.append({"els": els, "pat": t.pattern, "plv": t.plv, "mods": t.mods, "reso": t.reso,
			"pincer": t.pincer, "trigs": t.trigs, "share": (t.run_dealt + t.dealt) / total if total > 0.0 else 0.0})
	# 피해 출처 몫 (속성·공격방식·강화·반응·연계별, 오브젝트를 합쳐서). 직접 타격 안의 배율 몫은 추정
	var src := {}
	var rs := session.hud_system._run_src()
	for key in rs:
		if total > 0.0 and rs[key] / total >= 0.0005:
			src[key] = snappedf(rs[key] / total, 0.0001)
	session.net.submit({
		"device": Meta.device_id, "nick": Meta.nickname, "title": Meta.title, "platform": Net.platform(), "game": session.old_run_ver if session.old_run_ver != "" else Net.game_version(),
		"patch": Patch.id, "map": Meta.map_id, "rules": Meta.rules, "modes": Array(Modes.on) + (["grow"] if session.legacy_grow else []), "wave": session.wave, "score": session.score, "kills": session.kills,
		"best_combo": session.best_combo, "game_secs": session.run_game, "real_secs": session.run_real, "perks": session.perks.duplicate(),
		"towers": list, "src": src, "log": session.run_log, "leaks": session.combat_system._leak_records(), "vary": Vary.record(), "run": session.run_id, "ended": done,
	})


## 서버가 기록을 받으면 게임 오버 글 아래에 온라인 순위.
func _on_run_sent(res: Dictionary) -> void:
	var session: BinduSession = self.session
	if session.phase != BinduSession.Phase.GAMEOVER or not res.get("accepted", false):
		return
	var rk: Variant = res.get("rank")
	if int(res.get("season", 0)) == 0:
		session.over_label.text += session.patchlog_system._kr_keep("\n(지난 버전으로 한 판이라 이번 시즌 리더보드에는 들어가지 않아요)")
		session.over_card.queue_redraw()
	elif rk is Dictionary:
		var season: Variant = Net.info.get("season")
		var sname := str(season.get("name", "")) if season is Dictionary else ""
		session.over_label.text += "\n온라인 순위%s: %s%d위 (최고 점수 %s)" % [" (쉽게 모드)" if Modes.easy() else "", sname + " " if sname != "" else "", int(rk["rank"]), session.num(int(rk["score"]))]
		session.over_card.queue_redraw()
