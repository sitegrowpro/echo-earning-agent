extends RefCounted
## JSON saves in user:// (works on every platform, no permissions needed).

const SAVE_PATH := "user://housesit_save.json"
const END_PATH := "user://housesit_endings.json"
const SET_PATH := "user://housesit_settings.json"
const SAVE_VER := 1


# R4: crash-proof writes — the full file lands in tmp first, then the old
# file is swapped out, so a crash mid-save can never leave half a JSON file.
static func _atomic_write(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	var d := DirAccess.open("user://")
	if d == null:
		return false
	var base := path.get_file()
	if d.file_exists(base + ".tmp"):
		d.remove(base) # rename() won't overwrite on every platform
		return d.rename(base + ".tmp", base) == OK
	return false


static func save_game(data: Dictionary) -> bool:
	data["ts"] = Time.get_unix_time_from_system()
	data["v"] = SAVE_VER
	return _atomic_write(SAVE_PATH, JSON.stringify(data))


static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var partial := SAVE_PATH + ".tmp"
	if FileAccess.file_exists(partial) and FileAccess.get_modified_time(partial) > FileAccess.get_modified_time(SAVE_PATH):
		pass # a newer tmp means the last write crashed; the old save below is still intact
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return {}
	if int((parsed as Dictionary).get("v", 1)) != SAVE_VER:
		return {} # future format: refuse loudly (fresh run) instead of crashing
	return parsed


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
	_atomic_write(END_PATH, JSON.stringify(e))
	return e


static func get_settings() -> Dictionary:
	var d := {"sens": 1.0, "vol": 0.8, "subs": true, "grain": true, "headbob": true, "mic": true, "micsens": 0.6, "highq": true,
		"vol_music": 1.0, "vol_sfx": 1.0, "vol_voice": 1.0, "fov": 72.0, "photosafe": false, "cc": false, "subsize": 16.0, "keys": {}}
	if not FileAccess.file_exists(SET_PATH):
		return d
	var f := FileAccess.open(SET_PATH, FileAccess.READ)
	if f == null:
		return d
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		# R4: only accept known keys with the RIGHT TYPE — one hand-edited
		# "sens": "abc" used to break mouse look; now it falls back safely.
		for k in d.keys():
			if (parsed as Dictionary).has(k) and typeof((parsed as Dictionary)[k]) == typeof(d[k]):
				if k == "keys":
					var clean := {}
					for a in (((parsed as Dictionary)[k]) as Dictionary).keys():
						var code: Variant = (((parsed as Dictionary)[k]) as Dictionary)[a]
						if code is int and int(code) > 0:
							clean[String(a)] = int(code)
					d[k] = clean
				else:
					d[k] = (parsed as Dictionary)[k]
	return d


static func save_settings(s: Dictionary) -> void:
	_atomic_write(SET_PATH, JSON.stringify(s))
