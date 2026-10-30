class_name PatchNotes
extends Node
## 버전별 패치노트. CHANGELOG.md의 "## 제목 (vX.Y.Z)" 절이 한 버전.
## 빌드에는 CHANGELOG.md가 들어가지 않아(내보내기에서 *.md 제외) tools/gen_patch_notes.gd가 만든
## PatchNotesData.NOTES를 쓰고, 인터넷이 되면 GitHub의 최신 CHANGELOG.md를 받아 새 버전 노트도 보여 준다.
## 받은 글은 user://에 두었다가 오프라인일 때 쓴다.

signal loaded  # notes()가 바뀜 (인터넷에서 받음)

const URL := "https://raw.githubusercontent.com/lenope1214/Bindu/main/CHANGELOG.md"
const CACHE_PATH := "user://patchnotes.md"
const TIMEOUT := 8.0

static var remote: Array = []  # 받은(또는 받아 둔) 노트. 비면 내장 노트
static var source := "builtin"  # builtin | cache | online
static var fetching := false
static var fetched := false  # 다시 시작해도 한 번만


## CHANGELOG 글 → [{v: "0.4.39", title, lines: [..]}] (파일 순서 그대로, 옛것이 먼저).
## 버전이 없는 절(초기 기록)은 v가 빈 글자.
## "다음 버전 (미배포)" 절은 배포 전 작업 기록이라 플레이어에게 보이지 않게 뺀다 (내장본·온라인본 모두).
static func parse(text: String) -> Array:
	var out: Array = []
	var ver_re := RegEx.create_from_string("\\(v(\\d+\\.\\d+\\.\\d+)[^)]*\\)")
	var cur: Dictionary = {}
	for raw in text.split("\n"):
		var line := raw.rstrip(" \r")
		if line.begins_with("## "):
			var head := line.substr(3).strip_edges()
			var m := ver_re.search(head)
			var title := head
			if m:
				title = (head.substr(0, m.get_start()) + head.substr(m.get_end())).strip_edges()
			cur = {"v": m.get_string(1) if m else "", "title": title, "lines": []}
			if m == null and title.contains("미배포"):
				continue  # cur는 out에 넣지 않아 아래 줄들도 버려진다
			out.append(cur)
		elif not cur.is_empty() and line.strip_edges() != "" and not line.begins_with("#"):
			cur["lines"].append(line.replace("`", "").replace("**", ""))
	return out


static func vtuple(v: String) -> Array:
	var t: Array = []
	for p in v.split("."):
		t.append(int(p))
	return t


## 보여 줄 노트: 받은 것에 빌드에만 있는 버전(아직 올리기 전인 빌드)을 더한 것. 받은 것이 없으면 빌드에 든 것.
static func notes() -> Array:
	if remote.is_empty():
		_load_cache()
	if remote.is_empty():
		return PatchNotesData.NOTES
	var have := {}
	for n in remote:
		have[n["v"]] = true
	var out := remote.duplicate()
	for n in PatchNotesData.NOTES:
		if n["v"] != "" and not have.has(n["v"]):
			out.append(n)
	return out


static func has_version(v: String) -> bool:
	for n in notes():
		if n["v"] == v:
			return true
	return false


static func _load_cache() -> void:
	if source != "builtin":
		return
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if f == null:
		return
	var n := parse(f.get_as_text())
	if not n.is_empty():
		remote = n
		source = "cache"


## 인터넷에서 최신 CHANGELOG.md를 받는다 (켜고 처음 볼 때 한 번). 헤드리스 점검에서는 받지 않는다.
func fetch() -> void:
	if fetched or fetching or DisplayServer.get_name() == "headless":
		return
	fetching = true
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	if http.request(URL) != OK:
		http.queue_free()
		fetching = false
		return
	var res: Array = await http.request_completed
	http.queue_free()
	fetching = false
	fetched = true
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var n := parse(text)
	if n.is_empty():
		return
	remote = n
	source = "online"
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
	loaded.emit()
