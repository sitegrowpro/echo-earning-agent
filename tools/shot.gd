extends SceneTree
## CI screenshot driver. Run from the Godot project as:
##   godot --path godot -s "$PWD/tools/shot.gd"
## Captures menu, spawn view, and post-walk view; prints player position to
## prove movement. Dev tooling only: the game zip builds from godot/, so this
## file never ships.

var main: Node
var frames := 0
var stage := 0


func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	main = ps.instantiate()
	root.add_child(main)
	print("[SHOT] main instanced")


func _process(_delta: float) -> bool:
	frames += 1
	if stage == 0 and frames >= 60:
		stage = 1
		_shot("/tmp/shot_menu.png")
		print("[SHOT] menu captured; starting new game")
		main.call("start_new")
	elif stage == 1 and frames >= 140:
		stage = 2
		print("[SHOT] dismissing story card")
		main.call("story_click")
	elif stage == 2 and frames >= 220:
		stage = 3
		_shot("/tmp/shot_spawn.png")
		print("[SHOT] spawn captured at pos=", (main.get("player") as Node3D).global_position, "; walking forward")
		Input.action_press("move_forward")
	elif stage == 3 and frames >= 360:
		stage = 4
		Input.action_release("move_forward")
		_shot("/tmp/shot_walked.png")
		print("[SHOT] walked-final pos=", (main.get("player") as Node3D).global_position)
		print("[SHOT] DONE")
		return true
	return false


func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	var err := img.save_png(path)
	print("[SHOT] saved ", path, " err=", err)
