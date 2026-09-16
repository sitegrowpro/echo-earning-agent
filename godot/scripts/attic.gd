extends Node3D
## THE ATTIC — above the house in fiction, far north in fact (z ~ -129, the
## same offset-zone trick as the cellar). Sloped roof, a crib, a nursery box
## that raises the worst question in the game. The bulb joins the house power
## grid like the cellar's. No new textures: planks + wood + glow only.

const AX := 0.0
const AZ := -129.0
const BOUNDS_MIN := Vector2(AX - 13.3, AZ - 10.3)
const BOUNDS_MAX := Vector2(AX + 13.3, AZ + 10.3)
const SPAWN := Vector3(AX, 0.0, AZ + 8.6)
const TEX := preload("res://scripts/tex.gd")

const EXIT_POS := Vector3(AX, 1.2, AZ + 9.8)
const SWITCH_POS := Vector3(AX, 1.4, AZ + 5.4)
const NOTE_POS := Vector3(AX - 8.0, 1.0, AZ - 4.0)
const MUSIC_POS := Vector3(AX + 7.5, 1.0, AZ - 2.0)

var _mats := {}
var bulb: OmniLight3D


func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var k := str(c.to_html(), rough)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[k] = m
	return _mats[k]


func glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func box(w: float, h: float, d: float, m: Material, pos: Vector3, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = m
	if not collide:
		mi.position = pos
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.add_child(mi)
	add_child(body)
	return mi


func _orb(r: float, m: Material, pos: Vector3, h := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = 2.0 * r if h <= 0.0 else h
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func label3d(text: String, pos: Vector3, size := 64, color := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.modulate = color
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)


func _ready() -> void:
	build()


## Main calls this after add_child: the bulb joins the house power grid.
func setup(w: Node3D) -> void:
	w.room_light("attic", bulb)


func build() -> void:
	var X0 := AX - 14.0
	var X1 := AX + 14.0
	var Z0 := AZ - 11.0
	var Z1 := AZ + 11.0
	var fl := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(X1 - X0, Z1 - Z0)
	fl.mesh = fm
	fl.material_override = TEX.mat_for("planks", Color(0.35, 0.27, 0.17), 0.9)
	fl.position = Vector3(AX, 0.01, AZ)
	add_child(fl)
	var slab := StaticBody3D.new()
	slab.collision_layer = 1
	slab.collision_mask = 0
	slab.position = Vector3(AX, -0.25, AZ)
	var scs := CollisionShape3D.new()
	var sbs := BoxShape3D.new()
	sbs.size = Vector3(30, 0.5, 24)
	scs.shape = sbs
	slab.add_child(scs)
	add_child(slab)
	# Knee walls + gable stacks + sloped roof (ridge along Z at y 4.4).
	var wall_m := TEX.mat_for("planks", Color(0.4, 0.31, 0.2), 0.9)
	box(X1 - X0, 2.6, 0.3, wall_m, Vector3(AX, 1.3, Z0 - 0.15), true)
	box(X1 - X0, 2.6, 0.3, wall_m, Vector3(AX, 1.3, Z1 + 0.15), true)
	box(0.3, 2.6, Z1 - Z0, wall_m, Vector3(X0 - 0.15, 1.3, AZ), true)
	box(0.3, 2.6, Z1 - Z0, wall_m, Vector3(X1 + 0.15, 1.3, AZ), true)
	for zi in [Z0 - 0.15, Z1 + 0.15]:
		var w := 24.0
		var y := 2.8
		for i in 4:
			box(w, 0.45, 0.3, wall_m, Vector3(AX, y, zi))
			w -= 6.0
			y += 0.45
	var roof_m := TEX.mat_for("planks", Color(0.3, 0.23, 0.15), 0.95)
	var rl := box(14.3, 0.25, 22.6, roof_m, Vector3(AX - 7.0, 3.5, AZ))
	rl.rotation.z = 0.1279
	var rr := box(14.3, 0.25, 22.6, roof_m, Vector3(AX + 7.0, 3.5, AZ))
	rr.rotation.z = -0.1279
	var beam_m := mat(Color(0.25, 0.18, 0.11), 0.9)
	box(0.3, 0.3, 22.0, beam_m, Vector3(AX, 4.3, AZ))
	box(0.25, 4.3, 0.25, beam_m, Vector3(AX, 2.15, AZ - 5.0), true)
	box(0.25, 4.3, 0.25, beam_m, Vector3(AX, 2.15, AZ + 5.0), true)
	# Round window on the south gable + cold moonlight.
	_orb(0.45, glow(Color(0.6, 0.72, 0.9), 1.6), Vector3(AX, 3.4, AZ + 10.96), 0.12)
	box(1.1, 0.08, 0.25, beam_m, Vector3(AX, 2.9, AZ + 10.95))
	var moon := OmniLight3D.new()
	moon.light_color = Color(0.5, 0.62, 0.85)
	moon.light_energy = 0.7
	moon.omni_range = 9.0
	moon.position = Vector3(AX, 3.0, AZ + 9.5)
	add_child(moon)
	# Floor hatch + ladder back down (visuals; travel runs through the story).
	box(1.1, 0.06, 1.1, beam_m, Vector3(AX, 0.04, AZ + 9.0))
	box(0.85, 0.07, 0.85, mat(Color(0.02, 0.02, 0.03), 1.0), Vector3(AX, 0.045, AZ + 9.0))
	for sx in [-0.3, 0.3]:
		var rail := box(0.07, 2.4, 0.07, beam_m, Vector3(AX + 1.5 + sx, 1.1, AZ + 10.2))
		rail.rotation.x = 0.22
	for i in 4:
		box(0.6, 0.06, 0.06, beam_m, Vector3(AX + 1.5, 0.5 + float(i) * 0.5, AZ + 10.32 - float(i) * 0.11))
	label3d("DOWNSTAIRS", Vector3(AX, 1.9, AZ + 9.9), 72, Color(0.9, 0.85, 0.7))
	# The crib.
	var crib := Vector3(AX - 6.0, 0, AZ - 3.0)
	var crib_m := mat(Color(0.55, 0.52, 0.45), 0.8)
	for px in [-0.65, 0.65]:
		for pz in [-0.4, 0.4]:
			box(0.08, 1.0, 0.08, crib_m, crib + Vector3(px, 0.5, pz), true)
	for pz in [-0.4, 0.4]:
		box(1.38, 0.08, 0.06, crib_m, crib + Vector3(0, 0.95, pz))
		box(1.38, 0.08, 0.06, crib_m, crib + Vector3(0, 0.35, pz))
		for sx in [-0.45, -0.15, 0.15, 0.45]:
			box(0.05, 0.55, 0.05, crib_m, crib + Vector3(sx, 0.65, pz))
	box(1.25, 0.15, 0.72, mat(Color(0.7, 0.68, 0.6), 0.9), crib + Vector3(0, 0.32, 0))
	box(0.5, 0.07, 0.5, mat(Color(0.45, 0.55, 0.7), 0.9), crib + Vector3(-0.3, 0.43, 0))
	# Dress form, boxes, trunk with the music box.
	box(0.5, 0.08, 0.5, beam_m, Vector3(AX + 5.0, 0.04, AZ + 2.0))
	box(0.08, 1.5, 0.08, beam_m, Vector3(AX + 5.0, 0.8, AZ + 2.0))
	var torso := _orb(0.3, mat(Color(0.5, 0.42, 0.3), 0.9), Vector3(AX + 5.0, 1.35, AZ + 2.0))
	torso.scale = Vector3(1.0, 1.6, 0.7)
	box(1.0, 1.0, 1.0, wall_m, Vector3(AX - 11.0, 0.5, AZ + 7.5), true)
	box(0.8, 0.8, 0.8, wall_m, Vector3(AX - 10.0, 0.4, AZ + 7.6), true)
	box(0.8, 0.8, 0.8, wall_m, Vector3(AX - 10.6, 1.4, AZ + 7.5))
	var trunk := Vector3(AX + 7.5, 0, AZ - 2.0)
	box(1.4, 0.6, 0.7, TEX.mat_for("wooddoor", Color(0.45, 0.36, 0.24), 0.85), trunk + Vector3(0, 0.3, 0), true)
	box(1.4, 0.15, 0.7, beam_m, trunk + Vector3(0, 0.67, 0))
	box(0.25, 0.15, 0.2, mat(Color(0.72, 0.55, 0.2), 0.4), trunk + Vector3(-0.3, 0.82, 0))
	box(0.27, 0.03, 0.22, beam_m, trunk + Vector3(-0.3, 0.91, 0))
	# The nursery crate.
	box(0.9, 0.9, 0.9, wall_m, Vector3(AX - 8.0, 0.45, AZ - 4.0), true)
	label3d("NURSERY", Vector3(AX - 8.0, 1.15, AZ - 3.4), 48, Color(0.8, 0.72, 0.6))
	# Hanging bulb on the house grid.
	var cord := MeshInstance3D.new()
	var ccm := CylinderMesh.new()
	ccm.top_radius = 0.015
	ccm.bottom_radius = 0.015
	ccm.height = 1.2
	cord.mesh = ccm
	cord.material_override = mat(Color(0.05, 0.05, 0.05), 1.0)
	cord.position = Vector3(AX + 2.5, 3.7, AZ)
	add_child(cord)
	_orb(0.06, glow(Color(1.0, 0.9, 0.7), 2.0), Vector3(AX + 2.5, 3.05, AZ))
	bulb = OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.9, 0.7)
	bulb.light_energy = 1.2
	bulb.omni_range = 12.0
	bulb.position = Vector3(AX + 2.5, 3.0, AZ)
	add_child(bulb)
