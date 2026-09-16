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
var walk_t := 0.0
var door_wait := 0.0
var estep_t := 0.0
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
	# R6: garage leg — every segment crosses the x=8 wall inside the door hole.
	Vector3(7.4, 0, -0.5), Vector3(8.6, 0, -0.5), Vector3(9.0, 0, 2.8),
	Vector3(8.6, 0, -0.5), Vector3(7.4, 0, -0.5),
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
	cloth.albedo_color = Color(0.09, 0.09, 0.1)
	cloth.roughness = 1.0
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.47, 0.44, 0.4)
	skin.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.03)
	dark.roughness = 1.0
	# Long coat, flared at the hem; shoulders; collar.
	var coat := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.19
	cm.bottom_radius = 0.27
	cm.height = 1.1
	coat.mesh = cm
	coat.material_override = cloth
	coat.position = Vector3(0, 0.75, 0)
	mesh_root.add_child(coat)
	_part(0.46, 0.35, 0.28, cloth, Vector3(0, 1.42, 0))
	_part(0.3, 0.18, 0.26, cloth, Vector3(0, 1.62, 0))
	# Head + face: brow shadow, socketed glowing eyes, nose, grim mouth.
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.3
	head.mesh = hm
	head.material_override = skin
	head.position = Vector3(0, 1.84, 0)
	mesh_root.add_child(head)
	_part(0.22, 0.04, 0.05, dark, Vector3(0, 1.895, 0.105))
	var sock_m := StandardMaterial3D.new()
	sock_m.albedo_color = Color(0.01, 0.01, 0.015)
	sock_m.roughness = 1.0
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = Color.BLACK
	eye_m.emission_enabled = true
	eye_m.emission = Color.WHITE
	eye_m.emission_energy_multiplier = 2.0
	for sx in [-0.06, 0.06]:
		var so := MeshInstance3D.new()
		var som := SphereMesh.new()
		som.radius = 0.04
		som.height = 0.08
		so.mesh = som
		so.material_override = sock_m
		so.position = Vector3(sx, 1.83, 0.11)
		mesh_root.add_child(so)
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.026
		em.height = 0.052
		e.mesh = em
		e.material_override = eye_m
		e.position = Vector3(sx, 1.83, 0.132)
		mesh_root.add_child(e)
	_part(0.03, 0.06, 0.04, skin, Vector3(0, 1.775, 0.128))
	_part(0.07, 0.01, 0.02, dark, Vector3(0, 1.722, 0.121))
	var hat := MeshInstance3D.new()
	var ham := CylinderMesh.new()
	ham.top_radius = 0.2
	ham.bottom_radius = 0.2
	ham.height = 0.03
	hat.mesh = ham
	hat.material_override = cloth
	hat.position = Vector3(0, 1.97, 0)
	mesh_root.add_child(hat)
	var dome := MeshInstance3D.new()
	var dom := CylinderMesh.new()
	dom.top_radius = 0.11
	dom.bottom_radius = 0.12
	dom.height = 0.12
	dome.mesh = dom
	dome.material_override = cloth
	dome.position = Vector3(0, 2.03, 0)
	mesh_root.add_child(dome)
	# Thinner arms with pale hands; legs + shoes under the hem.
	for sx in [-0.31, 0.31]:
		_part(0.09, 0.8, 0.09, cloth, Vector3(sx, 1.05, 0))
		_part(0.09, 0.12, 0.09, skin, Vector3(sx, 0.6, 0))
	for sx in [-0.11, 0.11]:
		_part(0.13, 0.2, 0.13, cloth, Vector3(sx, 0.1, 0))
		_part(0.14, 0.08, 0.24, dark, Vector3(sx, 0.04, 0.04))


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


func step_toward(tx: float, tz: float, speed: float, dt: float) -> bool:
	var dx := tx - global_position.x
	var dz := tz - global_position.z
	var d := Vector2(dx, dz).length()
	if d < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	var want_x := dx / d * speed
	var want_z := dz / d * speed
	var k := minf(1.0, dt * 7.0)
	velocity.x = lerpf(velocity.x, want_x, k)
	velocity.z = lerpf(velocity.z, want_z, k)
	if not is_on_floor():
		velocity.y -= 20.0 * dt
	else:
		velocity.y = -0.5
	move_and_slide()
	# He turns his whole body toward his path — never snaps.
	face = lerp_angle(face, atan2(dx, dz), minf(1.0, dt * 5.0))
	rotation.y = face
	# Heavy gait: bob + weight sway, scaled by pace.
	walk_t += dt * (2.2 + speed * 0.9)
	mesh_root.rotation.z = sin(walk_t) * 0.02
	# Heavy footfalls you can track through the walls.
	estep_t -= dt
	if estep_t <= 0.0:
		var run := speed > 2.6
		estep_t = 0.3 if run else 0.5
		audio.step_at(global_position, run)
	# R6: hard map containment — he can never leave the playable rect
	# (void-falls used to soft-lock the hunt with no recovery).
	global_position.x = clampf(global_position.x, -30.0, 30.0)
	global_position.z = clampf(global_position.z, -38.0, 20.0)
	return d < 0.4


func _door_factor(dt: float, story: RefCounted) -> float:
	door_wait = maxf(0.0, door_wait - dt)
	if door_wait > 0.0:
		return 0.12
	var ahead := global_position + Vector3(sin(face), 0, cos(face)) * 1.1
	var world = story.get("world")
	if world == null:
		return 1.0
	var doors: Dictionary = (world as Object).get("doors")
	for id in doors.keys():
		var d: Object = doors[id]
		if bool(d.get("is_open")):
			continue
		var dp: Vector3 = (d as Node3D).global_position
		if Vector2(dp.x - ahead.x, dp.z - ahead.z).length() < 1.5:
			d.set("is_open", true)
			d.set("target", float(d.get("swing")))
			audio.door_creak(true)
			door_wait = 0.9
			return 0.12
	return 1.0


func update_enemy(dt: float, player: CharacterBody3D, story: RefCounted) -> String:
	if state == "dormant" or state == "gone" or state == "perch":
		if state == "perch" and mesh_root != null:
			var pt := float(Time.get_ticks_msec()) * 0.001
			mesh_root.rotation.z = sin(pt * 0.9) * 0.015
			mesh_root.position.y = sin(pt * 1.3) * 0.012
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
		step_toward(target.x, target.z, float(e["chase"]) * sp * _door_factor(dt, story), dt)
		var d := Vector2(pp.x - global_position.x, pp.z - global_position.z).length()
		if d < float(e["catch_dist"]) and not hidden_safe:
			return "caught"
	elif state == "investigate":
		if step_toward(target.x, target.z, float(e["investigate"]) * sp * _door_factor(dt, story), dt):
			state = "search"
			search_t = 0.0
	elif state == "search":
		search_t += dt
		var h := String(player.get("hidden"))
		if (h == "closet" or h == "pcloset") and dist < 7.0:
			story.call("closet_found")
		face += dt * 1.4
		rotation.y = face
		velocity.x = 0.0
		velocity.z = 0.0
		if search_t > 6.0:
			state = "patrol"
	elif state == "patrol":
		var w: Vector3 = waypoints[wp]
		if step_toward(w.x, w.z, float(e["patrol"]) * sp * _door_factor(dt, story), dt):
			wp = (wp + 1) % waypoints.size()
	if mesh_root:
		var bamp := 0.05 if state == "chase" else 0.03
		var bfr := 0.006 if state == "chase" else 0.004
		mesh_root.position.y = absf(sin(Time.get_ticks_msec() * bfr)) * bamp
	return state
