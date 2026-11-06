extends SceneTree
## 게임 안 업데이트 점검: 서버 서명(release_payload)을 게임이 확인하는지, zip 해시·exe 꺼내기가 되는지.
## godot --headless --path . -s tools/update_check.gd -- <공개키 pem 파일> <서명> <zip 파일> <sha256> <크기>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() == 3 and a[0] == "--release":
		_check_release(a[1], a[2])
		return
	if a.size() != 5:
		printerr("사용: --release boot.json Bindu-windows.zip 또는 공개키.pem 서명 zip 해시 크기")
		quit(1)
		return
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


## 실제 /v1/boot 응답을 내장 공개키로 검증한다. 파일 교체·실행·저장은 하지 않는다.
func _check_release(boot_path: String, zip_path: String) -> void:
	var boot: Variant = JSON.parse_string(FileAccess.get_file_as_string(boot_path))
	if not boot is Dictionary or not boot.get("latest") is Dictionary:
		printerr("boot.json에 latest가 없음")
		quit(1)
		return
	var r: Dictionary = boot["latest"]
	var payload := Updater.payload("windows", str(r.get("version", "")), str(r.get("url", "")), str(r.get("sha256", "")), int(r.get("size", 0)))
	var ok := _check("실제 릴리스 서명", Patch.verify(payload, str(r.get("sig", ""))))
	ok = _check("변조한 릴리스 거부", not Patch.verify(payload + "!", str(r.get("sig", "")))) and ok
	ok = _check("실제 zip 해시", FileAccess.get_sha256(zip_path) == str(r.get("sha256", ""))) and ok
	var file := FileAccess.open(zip_path, FileAccess.READ)
	ok = _check("실제 zip 크기", file != null and file.get_length() == int(r.get("size", 0))) and ok
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		_check("실제 zip 열기", false)
		quit(1)
		return
	var files := zr.get_files()
	ok = _check("단일 Bindu.exe 배포", files.size() == 1 and files[0] == "Bindu.exe") and ok
	var exe := zr.read_file("Bindu.exe")
	ok = _check("Windows 실행 파일", exe.size() > 12 and exe.slice(0, 2).get_string_from_ascii() == "MZ") and ok
	ok = _check("PCK 내장 실행 파일", exe.size() > 12 and exe.slice(exe.size() - 4).get_string_from_ascii() == "GDPC") and ok
	zr.close()
	print("UPDATE RELEASE ", "ok" if ok else "FAIL")
	quit(0 if ok else 1)


func _check(what: String, v: bool) -> bool:
	print(("  ok  " if v else "  FAIL ") + what)
	return v
