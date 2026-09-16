extends RefCounted
## DISTURB — the house breathes when you look away. Organic micro-events:
## doors found cracked, dead lights, a porch bulb with a mind of its own.
## Fires only at the player's back (camera dot-product), chapters 2+,
## never during a chase, never twice in a minute.

var world: Node = null
var enemy: Node = null
var next_in := 95.0
var restore: Array = [] # [{room, in, was}]

const DOORS := ["guest", "bath", "laundry", "garage"]
const ROOMS := ["living", "kitchen", "hall", "guest"]


func setup(w: Node, e: Node) -> void:
	world = w
	enemy = e
	reset_run()


func reset_run() -> void:
	next_in = randf_range(80.0, 130.0)
	restore.clear()


func _behind(cam: Camera3D, pos: Vector3) -> bool:
	var to: Vector3 = pos - cam.global_position
	if to.length() < 2.5:
		return false # too close: the player would see fair play, not dread
	return cam.global_transform.basis.z.dot(to.normalized()) > 0.35


func update(dt: float, player: Node3D, story: Node) -> void:
	_tick_restores(dt)
	if int(story.get("chapter")) < 2 or bool(story.get("finished")):
		return
	if enemy != null and String(enemy.get("state")) == "chase":
		return
	var room: String = world.call("room_at", player.global_position.x, player.global_position.z)
	if room in ["porch", "yard", "street", "market", "backyard", "woods", "cellar", "attic", "garage"]:
		next_in = 20.0
		return
	next_in -= dt
	if next_in > 0.0:
		return
	next_in = randf_range(90.0, 150.0)
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var roll := randf()
	if roll < 0.45:
		_crack(cam)
	elif roll < 0.75:
		_kill_light()
	else:
		_porch_flick()


func _tick_restores(dt: float) -> void:
	for i in range(restore.size() - 1, -1, -1):
		var r: Dictionary = restore[i]
		r["in"] = float(r["in"]) - dt
		if float(r["in"]) <= 0.0:
			world.call("set_room_light", String(r["room"]), bool(r["was"]))
			restore.remove_at(i)


func _crack(cam: Camera3D) -> void:
	var shut: Array = []
	var doors: Dictionary = world.get("doors")
	for id in DOORS:
		if not doors.has(id):
			continue
		var d: Node = doors[id]
		if bool(d.get("is_open")):
			continue
		if _behind(cam, (d as Node3D).global_position):
			shut.append(d)
	if shut.is_empty():
		return
	var pick: Node = shut[randi() % shut.size()]
	pick.set("target", 0.32)
	pick.set("is_open", true)


func _kill_light() -> void:
	var room: String = ROOMS[randi() % ROOMS.size()]
	var was := true
	var rl: Dictionary = world.get("room_lights")
	if rl.has(room):
		was = bool((rl[room] as Dictionary)["on"])
	world.call("set_room_light", room, false)
	restore.append({"room": room, "in": randf_range(18.0, 40.0), "was": was})


func _porch_flick() -> void:
	world.set("porch_on", not bool(world.get("porch_on")))
	world.call("apply_lights")
