## Autosave: one JSON file in user://. Written through a temp file and a rename so a save cut off
## mid-write (app killed, battery dead) never leaves a broken file behind.
## Backups: each time a game starts, the save it found is copied aside (PREV), and once a day a second
## copy (DAY). If the save can't be read, the game comes back from the newest backup that can.
## A ranch can also leave the phone as a "ranch code": the save packed into one line of text the
## player copies somewhere safe and pastes back later, on this phone or a new one.
## Off in desktop test runs (they would load each other's state) unless `-- --save=1` is passed.
class_name SaveGame

const PATH := "user://ranch_save.json"
const PREV := "user://ranch_save.prev.json"  # the save as this session found it
const DAY := "user://ranch_save.day.json"    # refreshed at most once a day
const VERSION := 1
const CODE_HEAD := "RANCH1:"

static var hold := false      # an imported ranch is replacing this one: no autosave over it
static var recovered := false # this session came back from a backup


static func enabled() -> bool:
	return OS.has_feature("template") or OS.get_cmdline_user_args().has("--save=1")


static func _parse(text: String) -> Dictionary:
	var d = JSON.parse_string(text)
	if d is not Dictionary or d.get("v", 0) != VERSION or not d.has("money") or not d.has("buildings"):
		return {}
	return d


static func read() -> Dictionary:
	recovered = false  # read again after a reload (a new look): only this read counts
	if not enabled():
		return {}
	for p in [PATH, PREV, DAY]:
		if not FileAccess.file_exists(p):
			continue
		var d := _parse(FileAccess.get_file_as_string(p))
		if d.is_empty():
			push_warning("save file %s unreadable or from another version" % p)
			continue
		if p == PATH:
			_backup()
		else:
			recovered = true
		return d
	return {}


## Copies the good save aside: always to PREV, and to DAY when that copy is a day old.
static func _backup() -> void:
	DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PREV))
	var day_old := not FileAccess.file_exists(DAY) or Time.get_unix_time_from_system() - FileAccess.get_modified_time(DAY) > 20 * 3600
	if day_old:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(DAY))


static func write(d: Dictionary) -> void:
	if not enabled() or hold:
		return
	_write(d)


static func _write(d: Dictionary) -> void:
	d.v = VERSION
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("can't write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(d))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


## The ranch as one line of text: gzip'd JSON in base64, behind a short header.
static func to_code(d: Dictionary) -> String:
	d.v = VERSION
	var raw := JSON.stringify(d).to_utf8_buffer()
	return CODE_HEAD + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## The ranch inside a code, or {} if it isn't a whole, readable ranch code.
static func from_code(code: String) -> Dictionary:
	var s := code.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
	var at := s.find(CODE_HEAD)
	if at < 0:
		return {}
	var packed := Marshalls.base64_to_raw(s.substr(at + CODE_HEAD.length()))
	if packed.is_empty():
		return {}
	var raw := packed.decompress_dynamic(32 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return {}
	return _parse(raw.get_string_from_utf8())


## Puts an imported ranch in place of this one; the caller reloads the scene right after.
static func replace_with(d: Dictionary) -> void:
	hold = true  # the ranch being left must not autosave over the new one on its way out
	if enabled():
		_write(d)
