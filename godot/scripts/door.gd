extends AnimatableBody3D
## A named door: hinge pivot, animated panel, dynamic collision.
## Collision lives on physics layer 2 (Doors): the player collides, the enemy
## ignores it (his mask excludes layer 2) — doors never stop him.

const TEX := preload("res://scripts/tex.gd")

var door_id := ""
var swing := 1.92
var base_ry := 0.0 # R5: doors on X-constant walls (garage) rest rotated
var angle := 0.0
var target := 0.0
var is_open := false
var locked := false
var label := ""
var shape: CollisionShape3D


func setup(p_id: String, w: float, p_swing: float, p_open: bool, p_locked: bool, p_label: String, color: Color) -> void:
	door_id = p_id
	swing = p_swing
	is_open = p_open
	locked = p_locked
	label = p_label
	collision_layer = 2
	collision_mask = 0
	var panel_mat := TEX.mat_for("wooddoor", color.lightened(0.12), 0.65) # R5b: real door veneer
	var inset_mat := StandardMaterial3D.new()
	inset_mat.albedo_color = color.darkened(0.25)
	inset_mat.roughness = 0.7
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 2.06, 0.07)
	panel.mesh = bm
	panel.material_override = panel_mat
	panel.position = Vector3(w * 0.5, 1.05, 0)
	add_child(panel)
	for iy in [1.45, 0.55]:
		for side in [0.045, -0.045]:
			var inset := MeshInstance3D.new()
			var im := BoxMesh.new()
			im.size = Vector3(w - 0.3, 0.7, 0.02)
			inset.mesh = im
			inset.material_override = inset_mat
			inset.position = Vector3(w * 0.5, iy, side)
			add_child(inset)
	var knob_mat := StandardMaterial3D.new()
	knob_mat.albedo_color = Color(0.79, 0.64, 0.15)
	knob_mat.metallic = 0.7
	knob_mat.roughness = 0.35
	for side in [0.08, -0.08]:
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		knob.mesh = sm
		knob.material_override = knob_mat
		knob.position = Vector3(w - 0.16, 1.02, side)
		add_child(knob)
	shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w + 0.1, 2.1, 0.3)
	shape.shape = bs
	shape.position = Vector3(w * 0.5, 1.05, 0)
	add_child(shape)
	if is_open:
		angle = swing
		target = swing
		rotation.y = base_ry + swing
		shape.set_deferred("disabled", true)


func _process(dt: float) -> void:
	if absf(target - angle) < 0.002:
		if angle != target:
			angle = target
			rotation.y = base_ry + angle
			shape.set_deferred("disabled", absf(angle) > 0.25)
		return
	# Exponential ease-out: the panel swings fast, then settles softly.
	angle = lerpf(angle, target, minf(1.0, dt * 4.2))
	rotation.y = base_ry + angle
	shape.set_deferred("disabled", absf(angle) > 0.25)


func toggle() -> void:
	is_open = not is_open
	target = swing if is_open else 0.0


func jiggle() -> void:
	# Locked rattle: the knob turns, the panel shudders, nothing gives.
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", base_ry + 0.07, 0.06)
	tw.tween_property(self, "rotation:y", base_ry - 0.05, 0.08)
	tw.tween_property(self, "rotation:y", base_ry + angle, 0.09)
