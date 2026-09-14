extends RefCounted
## JSON saves in user:// (works on every platform, no permissions needed).

const SAVE_PATH := "user://housesit_save.json"
const END_PATH := "user://housesit_endings.json"
const SET_PATH := "user://housesit_settings.json"


static func save_game(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	data["ts"] = Time.get_unix_time_from_system()
	f.store_string(JSON.stringify(data))
	f.close()
	return true


static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var d := DirAccess.open("user://")
		if d != null:
			d.remove("housesit_save.json")


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func get_endings() -> Dictionary:
	if not FileAccess.file_exists(END_PATH):
		return {}
	var f := FileAccess.open(END_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


static func unlock_ending(id: String) -> Dictionary:
	var e := get_endings()
	e[id] = float(e.get(id, 0)) + 1.0
	var f := FileAccess.open(END_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(e))
		f.close()
	return e


static func get_settings() -> Dictionary:
	var d := {"sens": 1.0, "vol": 0.8, "subs": true, "grain": true, "headbob": true, "mic": true, "micsens": 0.6}
	if not FileAccess.file_exists(SET_PATH):
		return d
	var f := FileAccess.open(SET_PATH, FileAccess.READ)
	if f == null:
		return d
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for k in parsed.keys():
			d[k] = parsed[k]
	return d


static func save_settings(s: Dictionary) -> void:
	var f := FileAccess.open(SET_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(s))
		f.close()
