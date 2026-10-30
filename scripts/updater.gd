class_name Updater
extends Node
## Windows 게임 안 업데이트: 서버가 알려 준 zip을 받아 서명된 해시와 맞는지 보고, 안의 exe로 바꿔 끼운 뒤 다시 켠다.
## 실행 중인 exe는 덮어쓸 수 없지만 이름은 바꿀 수 있어서: 지금 exe → .old, 새 exe → 원래 이름, 새로 켜고 끈다.
## 중간에 실패하면 원래 exe를 되돌리고 zip 주소를 브라우저로 연다(main.gd). .old는 새 버전이 켜질 때 지운다.

signal progress(ratio: float)  # 0~1, 크기를 모르면 -1
signal failed(reason: String)

const OLD_SUFFIX := ".old"
const NEW_SUFFIX := ".new"
const ZIP_NAME := "Bindu.update.zip"

var http: HTTPRequest
var busy := false


## 서버 응답의 latest로 게임 안 업데이트를 할 수 있는지 (아니면 지금처럼 브라우저로 받기).
static func available(latest: Dictionary) -> bool:
	if not OS.has_feature("windows") or not OS.has_feature("template"):
		return false  # 에디터·소스 실행·다른 플랫폼
	var exe := OS.get_executable_path()
	if FileAccess.file_exists(exe.get_basename() + ".pck"):
		return false  # pck가 따로 있는 빌드는 exe만 바꾸면 안 맞는다
	var url := str(latest.get("url", ""))
	var sha := str(latest.get("sha256", ""))
	if url == "" or sha.length() != 64:
		return false
	return Patch.verify(payload(Net.platform(), str(latest.get("version", "")), url, sha, int(latest.get("size", 0))), str(latest.get("sig", "")))


## server/app/main.py release_payload와 같아야 한다.
static func payload(platform: String, version: String, url: String, sha: String, size: int) -> String:
	return "bindu-release|%s|%s|%s|%s|%d" % [platform, version, url, sha, size]


## 켤 때: 지난 업데이트가 남긴 파일 지우기. 옛 exe는 막 끝나는 중이라 잠겨 있을 수 있어 몇 번 다시 시도.
func cleanup() -> void:
	if not OS.has_feature("windows") or not OS.has_feature("template"):
		return
	var exe := OS.get_executable_path()
	for i in 5:
		var left := false
		for p in [exe + OLD_SUFFIX, exe + NEW_SUFFIX, exe.get_base_dir().path_join(ZIP_NAME)]:
			if FileAccess.file_exists(p) and DirAccess.remove_absolute(p) != OK:
				left = true
		if not left:
			return
		if not is_inside_tree():
			return  # 장면을 다시 읽어 트리에서 빠진 뒤 (get_tree() null 오류)
		await get_tree().create_timer(2.0).timeout


func start(latest: Dictionary) -> void:
	if busy:
		return
	busy = true
	var exe := OS.get_executable_path()
	var dir := exe.get_base_dir()
	var zip_path := dir.path_join(ZIP_NAME)
	# 쓸 수 없는 폴더(Program Files 등)면 받기 전에 알린다
	var probe := FileAccess.open(zip_path, FileAccess.WRITE)
	if probe == null:
		_fail("게임 폴더에 쓸 수 없어요")
		return
	probe.close()
	http = HTTPRequest.new()
	http.download_file = zip_path
	http.use_threads = true
	http.timeout = 600.0
	add_child(http)
	if http.request(str(latest["url"])) != OK:
		http.queue_free()
		_fail("받기를 시작하지 못했어요")
		return
	var size := int(latest.get("size", 0))
	var res: Array = [-1, 0]  # 람다가 바깥 변수를 바꿀 수 없어 배열 안을 바꾼다
	http.request_completed.connect(func(r, code, _h, _b): res[1] = code; res[0] = r, CONNECT_ONE_SHOT)
	while res[0] == -1:
		var total := size if size > 0 else http.get_body_size()
		progress.emit(float(http.get_downloaded_bytes()) / total if total > 0 else -1.0)
		if not is_inside_tree():
			return  # 장면을 다시 읽어 트리에서 빠진 뒤 (get_tree() null 오류)
		await get_tree().create_timer(0.2).timeout
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		_fail("받기 실패 (%s)" % (str(res[1]) if res[0] == HTTPRequest.RESULT_SUCCESS else "연결"))
		return
	if FileAccess.get_sha256(zip_path) != str(latest["sha256"]).to_lower():
		_fail("받은 파일이 맞지 않아요")
		return
	# zip 안의 exe 꺼내기 (zip에는 Bindu.exe 하나)
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		_fail("zip을 열지 못했어요")
		return
	var inner := ""
	for f in zr.get_files():
		if f.get_extension().to_lower() == "exe":
			inner = f
			break
	var data := zr.read_file(inner) if inner != "" else PackedByteArray()
	zr.close()
	DirAccess.remove_absolute(zip_path)
	if data.is_empty():
		_fail("zip 안에 exe가 없어요")
		return
	var new_path := exe + NEW_SUFFIX
	var nf := FileAccess.open(new_path, FileAccess.WRITE)
	if nf == null:
		_fail("새 파일을 쓰지 못했어요")
		return
	nf.store_buffer(data)
	nf.close()
	data = PackedByteArray()
	# 바꿔 끼우기: 지금 exe → .old, 새 exe → 원래 이름. 어느 단계든 실패하면 되돌린다.
	var old_path := exe + OLD_SUFFIX
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(old_path)
	if DirAccess.rename_absolute(exe, old_path) != OK:
		DirAccess.remove_absolute(new_path)
		_fail("실행 파일을 바꾸지 못했어요")
		return
	if DirAccess.rename_absolute(new_path, exe) != OK:
		DirAccess.rename_absolute(old_path, exe)
		DirAccess.remove_absolute(new_path)
		_fail("실행 파일을 바꾸지 못했어요")
		return
	if OS.create_process(exe, []) == -1:
		DirAccess.remove_absolute(exe)
		DirAccess.rename_absolute(old_path, exe)
		_fail("새 버전을 켜지 못했어요")
		return
	get_tree().quit()


func _fail(reason: String) -> void:
	busy = false
	var zip_path := OS.get_executable_path().get_base_dir().path_join(ZIP_NAME)
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(zip_path)
	failed.emit(reason)
