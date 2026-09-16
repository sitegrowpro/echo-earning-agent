extends Node3D
## BISCUIT — the Millers' orange tabby. Wanders the house, meows, accepts
## tribute in the form of chin scratches (restores your nerve), and — most
## importantly — HISSES when the stranger is close. Trust the cat.

var audio
var player: CharacterBody3D
var enemy: CharacterBody3D
var story: RefCounted
var ui

var home := Vector3(5.6, 0, 4.4)
var dest := Vector3.ZERO
var wait_t := 0.0
var meow_t := 14.0
var hiss_cool := 0.0
var pet_cool := 0.0
var mesh_root: Node3D
var tail: MeshInstance3D
var head_mi: MeshInstance3D
var legs: Array[Node3D] = []
var walk_ph := 0.0
var spots := [
	Vector3(5.6, 0, 4.4), Vector3(3.0, 0, 2.2), Vector3(-1.5, 0, 3.2),
	Vector3(-4.5, 0, 1.8), Vector3(-0.5, 0, -0.5), Vector3(4.6, 0, -0.5),
	Vector3(6.8, 0, 2.8), Vector3(-3.0, 0, 4.6),
]
var couch_hide := Vector3(-2.0, 0, 3.9)


func setup(deps: Dictionary) -> void:
	audio = deps["audio"]
	player = deps["player"]
	enemy = deps["enemy"]
	story = deps["story"]
	ui = deps["ui"]
	_build_mesh()
	global_position = home
	dest = home


func _build_mesh() -> void:
	mesh_root = Node3D.new()
	add_child(mesh_root)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.85, 0.52, 0.2)
	fur.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.55, 0.32, 0.12)
	dark.roughness = 1.0
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.2, 0.42)
	body.mesh = bm
	body.material_override = fur
	body.position = Vector3(0, 0.2, 0)
	mesh_root.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.11
	hm.height = 0.22
	head.mesh = hm
	head.material_override = fur
	head.position = Vector3(0, 0.34, 0.26)
	head_mi = head
	mesh_root.add_child(head)
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = Color.BLACK
	eye_m.emission_enabled = true
	eye_m.emission = Color(0.4, 1.0, 0.3)
	eye_m.emission_energy_multiplier = 0.8
	for sx in [-0.045, 0.045]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.02
		em.height = 0.04
		e.mesh = em
		e.material_override = eye_m
		e.position = Vector3(sx, 0.37, 0.35)
		mesh_root.add_child(e)
	for sx in [-0.07, 0.07]:
		var ear := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.06, 0.08, 0.03)
		ear.mesh = pm
		ear.material_override = dark
		ear.position = Vector3(sx, 0.48, 0.24)
		mesh_root.add_child(ear)
	tail = MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.025
	tm.bottom_radius = 0.025
	tm.height = 0.4
	tail.mesh = tm
	tail.material_override = dark
	tail.position = Vector3(0, 0.36, -0.24)
	tail.rotation_degrees = Vector3(-24, 0, 0)
	mesh_root.add_child(tail)
	for lx in [-0.07, 0.07]:
		for lz in [-0.14, 0.14]:
			var hip := Node3D.new()
			hip.position = Vector3(lx, 0.12, lz)
			mesh_root.add_child(hip)
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.028
			lm.bottom_radius = 0.032
			lm.height = 0.13
			leg.mesh = lm
			leg.material_override = dark
			leg.position = Vector3(0, -0.06, 0)
			hip.add_child(leg)
			legs.append(hip)


func reset_run() -> void:
	global_position = home
	dest = home
	wait_t = 0.0
	meow_t = 14.0
	hiss_cool = 0.0
	pet_cool = 0.0
	visible = true


func update(dt: float) -> void:
	if story.get("finished"):
		return
	if bool((story.get("flags") as Dictionary).get("in_market", false)):
		return
	hiss_cool = maxf(0.0, hiss_cool - dt)
	pet_cool = maxf(0.0, pet_cool - dt)
	var danger := int(story.get("chapter")) >= 5
	var pp: Vector3 = player.global_position
	# Hiss early-warning when the hunter is near and active.
	var est := String(enemy.get("state"))
	if (est == "chase" or est == "investigate") and hiss_cool <= 0.0:
		var ed: Vector3 = enemy.global_position
		if Vector2(ed.x - pp.x, ed.z - pp.z).length() < 14.0:
			hiss_cool = 25.0
			audio.hiss()
			ui.toast("🐈 Biscuit's fur stands straight up. Something is CLOSE.")
	# Movement: wander, or cower under the couch once he's inside.
	var goal := dest
	if danger:
		goal = couch_hide
	elif wait_t > 0.0:
		wait_t -= dt
	else:
		var d := Vector2(dest.x - global_position.x, dest.z - global_position.z)
		if d.length() < 0.3:
			dest = spots[randi() % spots.size()]
			wait_t = randf_range(3.0, 9.0)
		else:
			var step: Vector2 = d.normalized() * minf(d.length(), 0.85 * dt)
			global_position.x += step.x
			global_position.z += step.y
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.y), minf(1.0, dt * 6.0))
	if danger and Vector2(goal.x - global_position.x, goal.z - global_position.z).length() > 0.2:
		var dd := Vector2(goal.x - global_position.x, goal.z - global_position.z)
		var st: Vector2 = dd.normalized() * minf(dd.length(), 1.6 * dt)
		global_position.x += st.x
		global_position.z += st.y
		rotation.y = lerp_angle(rotation.y, atan2(dd.x, dd.y), minf(1.0, dt * 6.0))
	# Idle tail sway + occasional meow.
	if tail:
		tail.rotation.z = sin(Time.get_ticks_msec() * 0.003) * 0.25
	# R7d: diagonal-gait walk cycle — hips swing, the body rides along.
	var moving := Vector2(goal.x - global_position.x, goal.z - global_position.z).length() > 0.3
	walk_ph += dt * (9.0 if moving else 2.0)
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(walk_ph + float(i) * PI * 0.5) * (0.5 if moving else 0.03)
	mesh_root.position.y = absf(sin(walk_ph)) * (0.02 if moving else 0.004)
	meow_t -= dt
	if meow_t <= 0.0:
		meow_t = randf_range(22.0, 45.0)
		if Vector2(pp.x - global_position.x, pp.z - global_position.z).length() < 12.0:
			audio.meow_at(global_position)


func pet() -> void:
	if pet_cool > 0.0:
		return
	pet_cool = 6.0
	audio.purr()
	if head_mi and is_instance_valid(head_mi):
		var tw := create_tween()
		tw.tween_property(head_mi, "position:y", 0.26, 0.18)
		tw.tween_property(head_mi, "position:y", 0.34, 0.25)
	ui.toast("🐈 Biscuit purrs like a motorboat. Your hands stop shaking.")


func head_pos() -> Vector3:
	return global_position + Vector3(0, 0.45, 0)
