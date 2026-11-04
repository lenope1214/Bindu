extends "res://tools/spec_check.gd"
## 격리 사본에서 카드 들기·취소·소비·이어하기와 튜토리얼만 독립 검증한다.
## 전체 spec의 결과를 대신하지 않는다.
func _initialize() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("BinduTools") or OnlineConfig.SERVER_URL != "" or OnlineConfig.MP_URL != "":
		push_error("BinduTools 사본과 비어 있는 온라인 주소가 필요합니다")
		quit(1)
		return
	seed(1)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._hide_title()
	_carry_cards()
	_tutorial()
	print("CARRY SPEC failures=%d features=%d" % [fails, seen.size()])
	quit(1 if fails > 0 else 0)
