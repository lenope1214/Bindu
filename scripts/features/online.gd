class_name BinduOnline
extends BinduFeature

var remote_run := ""  # remote_btn이 가져올 판
var updater: Updater  # Windows 게임 안 업데이트
func _on_booted(info: Dictionary) -> void:
	if info.is_empty() or session.update_btn == null:
		return
	if session.title_label.visible:
		session._apply_rules()
		session.menu_system._refresh_menu()
	var latest: Variant = info.get("latest")
	# 폰·태블릿은 스토어 주소만 연다 (App Store 2.5.2·3.1: 앱 밖에서 빌드를 받게 하지 않음)
	if latest is Dictionary and OS.has_feature("mobile") and not (str(latest.get("url", "")).begins_with("https://apps.apple.com/") or str(latest.get("url", "")).begins_with("https://play.google.com/")):
		latest = null
	if latest is Dictionary and str(latest.get("url", "")) != "" and not updater.busy:
		var notes := str(latest.get("notes", ""))
		var url := str(latest["url"])
		var auto := Updater.available(latest)
		session.update_btn.text = "새 버전 v%s %s%s" % [latest.get("version", "?"), "업데이트" if auto else "받기", " · " + notes if notes != "" else ""]
		session.update_btn.disabled = false
		_set_update_action(func(): _start_update(latest) if auto else OS.shell_open(url))
		session.update_btn.visible = true
	elif not updater.busy:
		session.update_btn.visible = false  # 다시 물어보니 새 버전이 없음 (서버에서 내림)
	var msg := Patch.text("", "message", "")
	session.notice_label.text = session.patchlog_system._kr_keep(msg)
	session.notice_label.visible = msg != ""
	if Net.acct_ok():
		session.net.sync()  # 진행을 계정 것과 합친다 (다른 기기에서 한 것)
		if session.title_label.visible:
			session.net.list_runs()


## 다른 기기 진행과 합쳐졌다: 저장하고 시작 화면 글(최고 기록·해금)을 다시 쓴다.
func _on_progress_synced() -> void:
	var b := Meta.best_of(Meta.run_key())
	session.best_wave = maxi(session.best_wave, b[0])
	session.best_score = maxi(session.best_score, b[1])
	session.progression_system._ach_catch_up()
	session.progression_system._save_best()
	if session.title_label.visible:
		Modes.set_on(Meta.modes if Meta.games > 0 else [])
		session._apply_rules()
		session.menu_system._refresh_menu()


## 계정의 진행 중 판 목록: 이 기기 판을 다른 기기가 가져갔으면 지우고, 이 기기에 판이 없으면 다른 기기 판을 이어 하게.
func _on_runs_listed(list: Array) -> void:
	var local := _local_run_key()
	remote_run = ""
	for e in list:
		if not e is Dictionary:
			continue
		if str(e.get("run", "")) == local and local != "" and not e.get("mine", true):
			_on_run_moved(local)
			local = ""
	if local == "" and not FileAccess.file_exists(session.RUN_PATH):
		for e in list:
			if e is Dictionary and not e.get("mine", true) and Net.same_minor(str(e.get("game", "")), Net.game_version()) and str(e.get("map", "")) in Meta.MAP_IDS:
				remote_run = str(e["run"])
				session.remote_btn.text = "다른 기기에서 하던 판 이어하기   웨이브 %d부터 · %s" % [int(e.get("wave", 0)) + 1, Meta.MAPS[str(e["map"])]["name"]]
				break
	session.remote_btn.visible = remote_run != "" and session.title_label.visible
	session.remote_btn.disabled = false


func _claim_remote_run() -> void:
	if remote_run == "":
		return
	session.remote_btn.disabled = true
	session.remote_btn.text = "가져오는 중..."
	session.net.claim_run(remote_run)


func _on_run_claimed(d: Dictionary) -> void:
	session.remote_btn.visible = false
	var cfg := ConfigFile.new()
	if d.is_empty() or cfg.parse(str(d.get("data", ""))) != OK or Meta.val(cfg, "run", "format", 0) != session.RUN_FORMAT:
		session.hud_system._show_toast("다른 기기의 판을 가져오지 못했어요")
		return
	cfg.save(session.RUN_PATH)
	session.moved_run = ""
	session._refresh_continue()
	if session.title_label.visible and session.continue_btn.visible:
		session._continue_run()


## 다른 기기가 이 판을 가져갔다: 시작 화면이면 이어하기를 지우고, 하는 중이면 계속 하되 서버에는 더 올리지 않는다.
func _on_run_moved(key: String) -> void:
	if session.title_label.visible and _local_run_key() == key:
		session._clear_run(false)
		session._refresh_continue()
		session.hud_system._show_toast("하던 판은 다른 기기에서 이어 하고 있어요")
	elif session.run_id == key and session.moved_run != key:
		session.moved_run = key
		session.hud_system._show_toast("이 판을 다른 기기에서 이어 하고 있어요. 여기서 계속 해도 다른 기기로는 넘어가지 않아요")


func _local_run_key() -> String:
	var cfg := ConfigFile.new()
	return str(Meta.val(cfg, "run", "run_id", "")) if cfg.load(session.RUN_PATH) == OK else ""


func _set_update_action(f: Callable) -> void:
	for c in session.update_btn.pressed.get_connections():
		session.update_btn.pressed.disconnect(c["callable"])
	session.update_btn.pressed.connect(f)


## [업데이트]: 받는 동안 버튼이 진행률을 보여 주고, 다 되면 새 버전으로 다시 켜진다.
func _start_update(latest: Dictionary) -> void:
	session.update_btn.disabled = true
	session.update_btn.text = "업데이트 받는 중..."
	updater.start(latest)


func _on_update_progress(ratio: float) -> void:
	session.update_btn.text = "업데이트 받는 중 %d%%" % int(ratio * 100) if ratio >= 0.0 else "업데이트 받는 중..."


## 실패하면 원래 버전 그대로: 버튼을 눌러 지금처럼 zip을 직접 받는다.
func _on_update_failed(reason: String) -> void:
	var latest: Variant = Net.info.get("latest")
	var url := str(latest.get("url", "")) if latest is Dictionary else ""
	session.update_btn.disabled = false
	session.update_btn.text = "업데이트 실패: %s · 눌러서 직접 받기" % reason
	_set_update_action(func(): OS.shell_open(url))


func _submit_run(done := true) -> void:
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
		"towers": list, "src": src, "log": session.run_log, "leaks": session._leak_records(), "vary": Vary.record(), "run": session.run_id, "ended": done,
	})


## 서버가 기록을 받으면 게임 오버 글 아래에 온라인 순위.
func _on_run_sent(res: Dictionary) -> void:
	if session.phase != session.Phase.GAMEOVER or not res.get("accepted", false):
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


## 시작 화면 리더보드 (2026-11-01 개편): 왼쪽 필터(맵·규칙·기록·시즌 칩을 모두 펼쳐 한 번에 고름), 오른쪽 순위 표(전체/이번 주 탭).
## 처음엔 지금 고른 맵·규칙·기록 종류의 이번 시즌 전체. 지난 시즌은 전체만.
