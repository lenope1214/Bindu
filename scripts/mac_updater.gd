class_name MacUpdater
extends RefCounted
## 직접 배포 .app 전용. 서명된 보조 프로그램은 앱 밖 임시 폴더에서 실행한다.

const HELPER := "Contents/Helpers/BinduUpdater"
const RECEIPT := "user://macos-update-result.json"
const PREFIX := ".bindu-update-"

static func app_path(executable := OS.get_executable_path()) -> String:
	var app := executable.get_base_dir().get_base_dir().get_base_dir()
	if not app.ends_with(".app") or not executable.begins_with(app.path_join("Contents/MacOS/")):
		return ""
	if not FileAccess.file_exists(app.path_join("Contents/Info.plist")) or "/AppTranslocation/" in app:
		return ""
	return app

static func supported() -> bool:
	var app := app_path()
	return OS.has_feature("macos") and OS.has_feature("template") and app != "" and FileAccess.file_exists(app.path_join(HELPER))

static func new_stage() -> String:
	var app := app_path()
	if app == "":
		return ""
	var stage := app.get_base_dir().path_join(PREFIX + Crypto.new().generate_random_bytes(16).hex_encode())
	return stage if DirAccess.make_dir_absolute(stage) == OK else ""

static func read_status(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func discard(stage: String) -> void:
	# rm removes symlinks themselves. Never recurse through a framework symlink using DirAccess.
	var app := app_path()
	if app != "" and stage.get_base_dir() == app.get_base_dir() and stage.get_file().begins_with(PREFIX):
		OS.execute("/bin/rm", PackedStringArray(["-rf", "--", stage]))

static func acknowledge() -> void:
	var args := OS.get_cmdline_user_args()
	var state_index := args.find("--bindu-update-state")
	var token_index := args.find("--bindu-update-token")
	if state_index < 0 or token_index < 0 or state_index + 1 >= args.size() or token_index + 1 >= args.size():
		return
	var stage := args[state_index + 1]
	var app := app_path()
	if app == "" or stage.get_base_dir() != app.get_base_dir() or not stage.get_file().begins_with(PREFIX):
		return
	var manifest := read_status(stage.path_join("manifest.json"))
	if manifest.get("app", "") != app or manifest.get("version", "") != Net.game_version() or manifest.get("token", "") != args[token_index + 1]:
		return
	var file := FileAccess.open(stage.path_join("ready"), FileAccess.WRITE)
	if file:
		file.store_string(args[token_index + 1])
