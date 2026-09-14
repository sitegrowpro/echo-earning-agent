extends CharacterBody3D
## "Daniel" — the stranger. Scripted perches early, then a real hunter:
## patrol -> investigate noise -> chase on sight -> search -> lose.

const CFG := preload("res://scripts/config.gd")

var audio
var state := "dormant" # dormant|perch|patrol|investigate|chase|search|gone
var aggression := 0
var face := PI
var target := Vector3.ZERO
var lose_t := 0.0
var search_t := 0.0
var speed_mul := 1.0
var wp := 0
var mesh_root: Node3D
var waypoints := [
	Vector3(1.8, 0, -0.5),
	Vector3(0, 0, -0.5),
	Vector3(-4.5, 0, -0.5), Vector3(-4.5, 0, 2.6), Vector3(-4.5, 0, -0.5),
	Vector3(-5.5, 0, -0.5), Vector3(-5.0, 0, -2.8), Vector3(-5.5, 0, -0.5),
	Vector3(0, 0, -0.5),
	Vector3(4.5, 0, -0.5), Vector3(4.5, 0, 1.5), Vector3(2.9, 0, 1.5),
	Vector3(2.9, 0, 4.0), Vector3(2.9, 0, 1.5), Vector3(4.5, 0, 1.5), Vector3(4.5, 0, -0.5),
	Vector3(6.0, 0, -0.5), Vector3(5.2, 0, -0.5), Vector3(5.2, 0, -2.6), Vector3(5.2, 0, -0.5),
	Vector3(1.8, 0, -0.5), Vector3(2.3, 0, -3.0), Vector3(1.8, 0, -0.5),
]


func _ready() -> void:
	_build_mesh()
	visible = false


func _part(w: float, h: float, d: float, m: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mesh_root.add_child(mi)


func _build_mesh() -> void:
	mesh_root = Node3D.new()
	add_child(mesh_root)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.05, 0.05, 0.06)
	cloth.roughness = 1.0
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.73, 0.66, 0.56)
	skin.roughness = 0.9
	_part(0.5, 0.9, 0.3, cloth, Vector3(0, 1.15, 0))
	_part(0.42, 0.75, 0.26, cloth, Vector3(0, 0.38, 0))
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.32
	head.mesh = hm
	head.material_override = skin
	head.position = Vector3(0, 1.78, 0)
	mesh_root.add_child(head)
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = Color.BLACK
	eye_m.emission_enabled = true
	eye_m.emission = Color.WHITE
	eye_m.emission_energy_multiplier = 0.7
	for sx in [-0.06, 0.06]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.022
		em.height = 0.044
		e.mesh = em
		e.material_override = eye_m
		e.position = Vector3(sx, 1.8, 0.14)
		mesh_root.add_child(e)
	for sx in [-0.32, 0.32]:
		_part(0.11, 0.85, 0.11, cloth, Vector3(sx, 1.05, 0))


func place(x: float, z: float, p_face: float) -> void:
	global_position = Vector3(x, 0, z)
	face = p_face
	rotation.y = face
	velocity = Vector3.ZERO


func perch(p: Dictionary) -> void:
	place(float(p["x"]), float(p["z"]), float(p["face"]))
	state = "perch"
	visible = true


func vanish() -> void:
	state = "gone"
	visible = false


func hear_at(pos: Vector3) -> void:
	# A loud noise (mic, crash) — come take a look. Never interrupts a chase.
	if state == "dormant" or state == "gone" or state == "perch" or state == "chase":
		return
	state = "investigate"
	target = pos


func yank_to_hiding(player: CharacterBody3D) -> void:
	# He HEARD you in the hiding spot. No more games.
	target = player.global_position
	state = "chase"
	lose_t = 0.0


func can_see(player: CharacterBody3D) -> bool:
	var pp: Vector3 = player.global_position
	var dx := pp.x - global_position.x
	var dz := pp.z - global_position.z
	var dist := Vector2(dx, dz).length()
	var e: Dictionary = CFG.ENEMY
	var sight_range := float(e["sight_range"]) + aggression * 1.5
	if dist > sight_range:
		return false
	var fx := sin(face)
	var fz := cos(face)
	var dot := (dx * fx + dz * fz) / maxf(dist, 0.001)
	if dist > 2.2 and dot < float(e["sight_fov"]):
		return false
	var from := global_position + Vector3(0, 1.6, 0)
	var to := pp + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 3, [self])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return false
	if bool(player.get("crouch")) and not bool(player.get("moving")) and dist > 3.5:
		return false
	return true


func move_toward(tx: float, tz: float, speed: float, dt: float) -> bool:
	var dx := tx - global_position.x
	var dz := tz - global_position.z
	var d := Vector2(dx, dz).length()
	if d < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	velocity.x = dx / d * speed
	velocity.z = dz / d * speed
	if not is_on_floor():
		velocity.y -= 20.0 * dt
	else:
		velocity.y = -0.5
	move_and_slide()
	face = atan2(dx, dz)
	rotation.y = face
	return d < 0.4


func update_enemy(dt: float, player: CharacterBody3D, story: RefCounted) -> String:
	if state == "dormant" or state == "gone" or state == "perch":
		return state
	var e: Dictionary = CFG.ENEMY
	var pp: Vector3 = player.global_position
	var seen := can_see(player)
	var pnoise := float(player.get("noise"))
	var dist := Vector2(pp.x - global_position.x, pp.z - global_position.z).length()
	var heard: bool = pnoise > 45.0 and dist < float(e["hear_radius"]) + pnoise * 0.05
	var hidden_safe: bool = String(player.get("hidden")) != "" and pnoise < 30.0 and not bool(story.get("flash_is_on"))
	if (seen and not hidden_safe) or (String(player.get("hidden")) != "" and pnoise > 55.0):
		if state != "chase":
			story.call("on_spotted")
		state = "chase"
		lose_t = 0.0
		target = pp
	elif state == "chase":
		lose_t += dt
		target = pp
		if lose_t > float(e["lose_time"]):
			state = "search"
			search_t = 0.0
	elif heard and state != "investigate":
		state = "investigate"
		target = pp
	var sp := speed_mul
	if state == "chase":
		move_toward(target.x, target.z, float(e["chase"]) * sp, dt)
		var d := Vector2(pp.x - global_position.x, pp.z - global_position.z).length()
		if d < float(e["catch_dist"]) and not hidden_safe:
			return "caught"
	elif state == "investigate":
		if move_toward(target.x, target.z, float(e["investigate"]) * sp, dt):
			state = "search"
			search_t = 0.0
	elif state == "search":
		search_t += dt
		face += dt * 1.4
		rotation.y = face
		velocity.x = 0.0
		velocity.z = 0.0
		if search_t > 6.0:
			state = "patrol"
	elif state == "patrol":
		var w: Vector3 = waypoints[wp]
		if move_toward(w.x, w.z, float(e["patrol"]) * sp, dt):
			wp = (wp + 1) % waypoints.size()
	if mesh_root:
		mesh_root.position.y = absf(sin(Time.get_ticks_msec() * 0.004)) * 0.03
	return state
