extends SceneTree
## tools/run.sh ui update_flow_check.gd /tmp/bindu-update-ui
## 저장·네트워크가 분리된 실제 홈화면에서 버튼·재시도·스토어 이동을 점검한다.

class FakeUpdater extends Updater:
	var requests: Array[Dictionary] = []
	func start(latest: Dictionary) -> void:
		busy = true
		requests.append(latest.duplicate(true))

class TestOnline extends BinduOnline:
	var opened := ""
	func _open_update_url(url: String) -> void:
		opened = url

var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		push_error("tools/run.sh ui의 저장·네트워크 분리 사본에서 실행하세요")
		quit(1)
		return
	Tutorial.load_file()
	Tutorial.done = true
	Tutorial.play_done = true
	Tutorial.save_file()
	var main: BinduSession = load("res://main.tscn").instantiate()
	VirtualInput.mount(main, root)
	await process_frame
	main.tut.close()
	var online := TestOnline.new(main)
	var updater := FakeUpdater.new()
	root.add_child(updater)
	online.updater = updater
	var latest := {"version": "9.9.9", "url": "https://example.com/Bindu.zip", "notes": "새 버전 안내"}
	# 기존 코드에서도 실행되는 회귀 검사: 외부 배포 페이지여도 이름은 [업데이트].
	online._on_booted({"latest": latest})
	check(main.update_btn.visible and main.update_btn.text == "업데이트", "홈 버튼 이름은 업데이트")
	await snap(main, "update-home")
	await click(main.update_btn)
	check(online.opened == latest.url, "외부 업데이트는 배포 페이지로 이동")
	if not online.has_method("_show_update"):
		print("UPDATE FLOW failures=", fails)
		main.free()
		updater.free()
		quit(1)
		return
	# Windows 자동 업데이트 경로. OS 실행·파일 교체 대신 요청만 기록한다.
	online._show_update(latest, true)
	online._show_update(latest, true)
	check(main.update_btn.pressed.get_connections().size() == 1, "새 응답에도 클릭 처리 중복 없음")
	await click(main.update_btn)
	check(updater.requests.size() == 1 and main.update_btn.disabled, "한 클릭으로 앱 안 다운로드 시작·중복 클릭 차단")
	online._on_update_progress(0.45)
	check(main.update_btn.text.contains("45%"), "다운로드 진행률")
	online._on_booted({"latest": null})
	check(main.update_btn.visible and main.update_btn.disabled, "진행 중 새 응답이 버튼을 숨기거나 재활성화하지 않음")
	updater.busy = false
	online._on_update_failed("연결")
	check(main.update_btn.text == "업데이트" and not main.update_btn.disabled, "실패 후 업데이트 버튼 복구")
	check(main.update_btn.tooltip_text.contains("연결"), "실패 이유 안내")
	latest.url = "https://example.com/changed.zip"
	await click(main.update_btn)
	check(updater.requests.size() == 2 and updater.requests[1].url == "https://example.com/Bindu.zip", "재시도는 원래 릴리스로 앱 안에서 실행")
	updater.busy = false
	online._on_update_failed("연결")
	for p in ["ios", "android"]:
		check(not BinduOnline.update_url_allowed("https://example.com/Bindu.zip", p), p + " 외부 빌드 차단")
	check(BinduOnline.update_url_allowed("https://apps.apple.com/kr/app/id123", "ios"), "iOS App Store 허용")
	check(not BinduOnline.update_url_allowed("https://testflight.apple.com/join/abcd", "ios"), "iOS TestFlight 차단 (App Store 빌드)")
	check(not BinduOnline.update_url_allowed("https://play.google.com/store/apps/details?id=x", "ios"), "iOS에서 Android 스토어 차단")
	check(BinduOnline.update_url_allowed("https://play.google.com/store/apps/details?id=x", "android"), "Android Google Play 허용")
	check(not BinduOnline.update_url_allowed("https://apps.apple.com/kr/app/id123", "android"), "Android에서 iOS 스토어 차단")
	check(not BinduOnline.update_url_allowed("https://apps.apple.com.evil.example/id123", "ios"), "스토어 유사 도메인 차단")
	await snap(main, "update-retry")
	online._on_booted({"latest": null})
	check(not main.update_btn.visible and online.update_release.is_empty(), "최신 버전이면 버튼 숨김·릴리스 초기화")
	main.free()
	updater.free()
	print("UPDATE FLOW failures=", fails)
	quit(1 if fails else 0)

func check(value: bool, message: String) -> void:
	print("ok " if value else "FAIL ", message)
	if not value:
		fails += 1

func click(button: Button) -> void:
	for i in 3:
		await process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(VirtualInput.viewport.size))
	check(button.is_visible_in_tree() and screen.encloses(button.get_global_rect()), "클릭할 업데이트 버튼이 화면에 보임")
	var pos := button.get_global_rect().get_center()
	VirtualInput.move(pos)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		VirtualInput.send(event)
		await process_frame

func snap(main: BinduSession, tag: String) -> void:
	for i in 6:
		await process_frame
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless" and not args.is_empty():
		RenderingServer.force_draw()
		main.get_viewport().get_texture().get_image().save_png(args[0].path_join(tag + ".png"))
