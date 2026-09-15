extends SceneTree
## CI screenshot tour driver. Run from the Godot project as:
##   godot --path godot -s "$PWD/tools/shot.gd"
## Walks a 9-stop camera tour (menu, spawn, 5 rooms, phone, street) to prove
## graphics + mechanics. Dev tooling only: the game zip builds from godot/,
## so this file never ships.

var main: Node
var frames := 0
var stage := 0
var stop_i := -1

var stops := [
	{"eye": Vector3(0, 1.62, 7.4), "look": Vector3(0, 1.4, 5.5), "file": "shot_02_spawn.png"},
	{"eye": Vector3(-0.5, 1.62, 4.4), "look": Vector3(-3.2, 1.0, 0.8), "file": "shot_03_living.png"},
	{"eye": Vector3(1.6, 1.62, 4.6), "look": Vector3(7.4, 1.0, 2.6), "file": "shot_04_kitchen.png"},
	{"eye": Vector3(-4.3, 1.62, -2.4), "look": Vector3(-6.7, 0.8, -4.5), "file": "shot_05_guest.png"},
	{"eye": Vector3(5.6, 1.62, -2.3), "look": Vector3(4.4, 1.0, -4.7), "file": "shot_06_bath.png"},
	{"eye": Vector3(2.5, 1.62, -0.5), "look": Vector3(-4.9, 1.3, -1.4), "file": "shot_07_hall.png"},
	{"eye": Vector3(1.6, 1.62, 4.6), "look": Vector3(7.4, 1.0, 2.6), "file": "shot_08_phone.png"},
	{"eye": Vector3(0, 1.62, 12.4), "look": Vector3(0, 1.8, 5.5), "file": "shot_09_street.png"},
]


func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	main = ps.instantiate()
	root.add_child(main)
	print("[SHOT] main instanced")


func _process(_delta: float) -> bool:
	frames += 1
	if stage == 0 and frames >= 60:
		stage = 1
		_shot("/tmp/shot_01_menu.png")
		print("[SHOT] menu captured; starting new game")
		main.call("start_new")
	elif stage == 1 and frames >= 140:
		stage = 2
		stop_i = -1
		main.call("story_click")
		main.get("story").call("toggle_door", "laundry")
		main.get("story").call("_tv_use")
		main.get("player").set("frozen", true)
		print("[SHOT] card dismissed; laundry open; TV on; touring")
	elif stage == 2 and frames >= 220 + (stop_i + 1) * 35:
		stop_i += 1
		if stop_i >= stops.size():
			print("[SHOT] DONE")
			return true
		if stop_i == 6:
			main.get("phone").call("toggle")
			print("[SHOT] phone opened")
		if stop_i == 7:
			main.get("phone").call("toggle")
			print("[SHOT] phone closed")
		var s: Dictionary = stops[stop_i]
		main.get("player").call("look_at_spot", s["eye"], s["look"])
		_shot("/tmp/" + String(s["file"]))
		print("[SHOT] stop ", stop_i + 2, " saved")
		if stop_i >= stops.size() - 1:
			print("[SHOT] DONE")
			return true
	return false


func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	var err := img.save_png(path)
	print("[SHOT] saved ", path, " err=", err)
