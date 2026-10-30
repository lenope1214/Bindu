extends SceneTree
## 게임 안 업데이트 점검: 서버 서명(release_payload)을 게임이 확인하는지, zip 해시·exe 꺼내기가 되는지.
## godot --headless --path . -s tools/update_check.gd -- <공개키 pem 파일> <서명> <zip 파일> <sha256> <크기>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pem := FileAccess.get_file_as_string(a[0])
	var url := "https://github.com/lenope1214/Bindu/releases/download/v9.9.9/Bindu-windows.zip"
	var p := Updater.payload("windows", "9.9.9", url, a[3], int(a[4]))
	var ok := true
	ok = _check("서명 맞음", Patch.verify(p, a[1], pem)) and ok
	ok = _check("고친 서명 거부", not Patch.verify(p.replace("9.9.9", "9.9.8"), a[1], pem)) and ok
	ok = _check("zip 해시", FileAccess.get_sha256(a[2]) == a[3]) and ok
	var zr := ZIPReader.new()
	ok = _check("zip 열기", zr.open(a[2]) == OK) and ok
	var exe := ""
	for f in zr.get_files():
		if f.get_extension().to_lower() == "exe":
			exe = f
	ok = _check("exe 꺼내기 (%s)" % exe, exe != "" and zr.read_file(exe).size() > 0) and ok
	print("모두 통과" if ok else "실패 있음")
	quit(0 if ok else 1)


func _check(what: String, v: bool) -> bool:
	print(("  ok  " if v else "  FAIL ") + what)
	return v
