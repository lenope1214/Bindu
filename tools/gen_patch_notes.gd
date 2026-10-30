extends SceneTree
## CHANGELOG.md → scripts/patch_notes_data.gd (게임 안 패치노트의 내장 본).
## 빌드에는 .md가 들어가지 않으므로 빌드 스크립트가 내보내기 전에 돌린다. CHANGELOG를 고친 뒤 직접 돌려도 된다.
## 사용: godot --headless --path . --script tools/gen_patch_notes.gd


func _init() -> void:
	var f := FileAccess.open("res://CHANGELOG.md", FileAccess.READ)
	if f == null:
		push_error("CHANGELOG.md를 열지 못했어요")
		quit(1)
		return
	var notes := PatchNotes.parse(f.get_as_text())
	var body := "class_name PatchNotesData\n## tools/gen_patch_notes.gd가 CHANGELOG.md에서 만든 파일. 직접 고치지 마세요.\n\nconst NOTES := %s\n" % var_to_str(notes)
	var old := FileAccess.get_file_as_string("res://scripts/patch_notes_data.gd")
	if old != body:
		var w := FileAccess.open("res://scripts/patch_notes_data.gd", FileAccess.WRITE)
		w.store_string(body)
	print("패치노트 %d개 (최신 v%s)" % [notes.size(), notes[-1]["v"] if not notes.is_empty() else "-"])
	quit()
