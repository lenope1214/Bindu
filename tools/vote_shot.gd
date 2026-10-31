extends SceneTree
## 다음 패치 투표 화면 스크린샷: 시작 화면 [투표] 버튼, 투표 창(표 넣음·개선 의견·표 다 씀·지난 회차 결과), 판 끝난 화면 버튼·이번 판 탭.
## 서버 없이 Net.info.vote와 응답을 채워 그린다. 실제 서버로 보내지 않게 SERVER_URL을 바꾼 사본에서 돌린다.
## 인자: 저장 폴더 [글자 크기] [touch] [phone]. 예) xvfb-run godot --path <사본> -s tools/vote_shot.gd -- /tmp/shots 1.3 touch phone
var main
var f := 0
var out := "/tmp"
var z := 1.0
var touch := false
var steps: Array = []
const FAKE := {"round": {"id": 2, "name": "0.6.0 다음"}, "max": 5, "min_wave": 5, "eligible": true, "reason": "",
	"mine": [{"key": "elem:fire", "dir": "up", "note": ""}, {"key": "pat:spray", "dir": "down", "note": ""},
		{"key": "mod:homing", "dir": "fix", "note": "유도탄이 화면 밖까지 쫓아가요"}],
	"last": {"id": 1, "name": "1회차", "voters": 37, "up": [{"key": "elem:wind", "n": 12}, {"key": "pat:laser", "n": 9}, {"key": "perk:regen", "n": 6}],
		"down": [{"key": "pat:vortex", "n": 15}, {"key": "elem:poison", "n": 7}], "fix": [{"key": "mod:dice", "n": 5}]}}


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: z = float(a[1])
	touch = a.size() > 2 and a[2] == "touch"
	Meta.sim_phone = a.size() > 3 and a[3] == "phone"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func():
			Meta.ui_scale = z
			main.touch_ui = touch
			main._apply_ui_scale()
			Net.info["vote"] = true
			main.tut_first = false
			if main.tut.visible:
				main.tut.close(),
		func(): _snap("vote_title"); main.vote_panel.net = null; main._toggle_vote(),
		func(): main.vote_panel.take(FAKE); main.vote_panel._draw_list(),
		func(): _snap("vote_panel"); main.vote_panel.tabs[3].pressed.emit(),
		func(): _snap("vote_mod"); main.vote_panel.choose("trig:echo", "up"); main.vote_panel.choose("perk:power", "fix"); main.vote_panel.choose("elem:ice", "up"); main.vote_panel._say("표 5장을 다 썼어요. 다른 표를 취소하고 넣어 주세요"); main.vote_panel.tabs[6].pressed.emit(),
		func(): _snap("vote_full_rx"); main.vote_panel.hide_panel(); main.continue_btn.visible = false; main._close_title(),
		func():
			main.run_log = [{"w": 0, "k": "card", "p": "elem:fire"}, {"w": 2, "k": "card", "p": "pat:spray"}, {"w": 4, "k": "card", "p": "mod:rapid"}, {"w": 5, "k": "perk", "p": "perk:power"}]
			main.wave = 12
			main.score = 34567
			main._game_over(),
		func(): main.over_label.text = "피해 출처: 불 42%, 분사 30%, 속사 12%\n온라인 순위: 시즌 1 12위 (최고 점수 34,567)",
		func(): _snap("vote_over"); main._toggle_vote(true),
		func(): main.vote_panel.take(FAKE); main.vote_panel._draw_list(),
		func(): _snap("vote_over_run"),
	]


func _snap(n: String):
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s%s.png" % [n, z, "_touch" if touch else "", "_phone" if Meta.sim_phone else ""]))
	print("SHOT ", n)
	preload("res://tools/ui_check.gd").check(main, n)  # 겹침·화면 밖 (UI OVERLAP 줄)


func _process(_d) -> bool:
	f += 1
	if f % 15 == 5:
		var i := f / 15
		if i < steps.size():
			steps[i].call()
		else:
			quit()
	return false
