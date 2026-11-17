## Autosave: one JSON file in user://. Written through a temp file and a rename so a save cut off
## mid-write (app killed, battery dead) never leaves a broken file behind.
## Off in desktop test runs (they would load each other's state) unless `-- --save=1` is passed.
class_name SaveGame

const PATH := "user://ranch_save.json"
const VERSION := 1


static func enabled() -> bool:
	return OS.has_feature("template") or OS.get_cmdline_user_args().has("--save=1")


static func read() -> Dictionary:
	if not enabled() or not FileAccess.file_exists(PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is not Dictionary or d.get("v", 0) != VERSION:
		push_warning("save file unreadable or from another version, starting fresh")
		return {}
	return d


static func write(d: Dictionary) -> void:
	if not enabled():
		return
	d.v = VERSION
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("can't write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(d))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


static func erase() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
