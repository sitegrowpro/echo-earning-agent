extends Node3D
## THE CELLAR — under the house in fiction, far away in fact (x ~ -120, the
## same offset-zone trick as FreshMart). Cinderblock walls, a 1974 furnace that
## never quite goes out, crates, a workbench with spare AAs. The hanging bulb
## registers into the world's room-light table, so the ch4 blackout and the
## pull switch behave exactly like every other room. No new systems.

const CX := -120.0
const BOUNDS_MIN := Vector2(CX - 13.3, -10.3)
const BOUNDS_MAX := Vector2(CX + 13.3, 10.3)
const SPAWN := Vector3(CX, 0.0, 8.6)
const TEX := preload("res://scripts/tex.gd")

const FURNACE_POS := Vector3(CX + 9.0, 1.0, -6.0)
const BENCH_POS := Vector3(CX - 8.0, 0.95, -7.5)
const PACK_POS := Vector3(CX - 8.0, 1.0, -7.5)
const NOTE_POS := Vector3(CX - 10.5, 1.15, -8.5)
const SWITCH_POS := Vector3(CX + 1.0, 1.35, 10.7)
const EXIT_POS := Vector3(CX, 1.2, 9.8)

var _mats := {}
var bulb: OmniLight3D
var furnace_glow: OmniLight3D
var pulse_t := 0.0


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


func label3d(text: String, pos: Vector3, size := 64, color := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.modulate = color
	l.pixel_size = 0.004
	l.position = pos
	add_child(l)


func _ready() -> void:
	build()


## Main calls this after add_child: the bulb joins the house power grid.
func setup(w: Node3D) -> void:
	w.room_light("cellar", bulb)


func build() -> void:
	var X0 := CX - 14.0
	var X1 := CX + 14.0
	var Z0 := -11.0
	var Z1 := 11.0
	var fl := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(X1 - X0, Z1 - Z0)
	fl.mesh = fm
	fl.material_override = TEX.mat_for("cellar", Color(0.55, 0.55, 0.57), 0.95)
	fl.position = Vector3(CX, 0.01, 0)
	add_child(fl)
	var slab := StaticBody3D.new()
	slab.collision_layer = 1
	slab.collision_mask = 0
	slab.position = Vector3(CX, -0.25, 0)
	var scs := CollisionShape3D.new()
	var sbs := BoxShape3D.new()
	sbs.size = Vector3(30, 0.5, 24)
	scs.shape = sbs
	slab.add_child(scs)
	add_child(slab)
	var ce := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(X1 - X0, Z1 - Z0)
	ce.mesh = cm
	ce.material_override = mat(Color(0.09, 0.09, 0.1), 1.0)
	ce.rotation.x = PI
	ce.position = Vector3(CX, 2.6, 0)
	add_child(ce)
	# Perimeter: painted block, full height, no holes (travel is via story).
	var wall_m := TEX.mat_for("block", Color(0.6, 0.6, 0.62), 0.95)
	box(X1 - X0, 2.6, 0.3, wall_m, Vector3(CX, 1.3, Z0 - 0.15), true)
	box(X1 - X0, 2.6, 0.3, wall_m, Vector3(CX, 1.3, Z1 + 0.15), true)
	box(0.3, 2.6, Z1 - Z0, wall_m, Vector3(X0 - 0.15, 1.3, 0), true)
	box(0.3, 2.6, Z1 - Z0, wall_m, Vector3(X1 + 0.15, 1.3, 0), true)
	# Partition with a doorway: furnace nook on the east side.
	box(0.25, 2.6, 9.0, wall_m, Vector3(CX + 2.0, 1.3, -6.5), true)
	box(0.25, 2.6, 9.0, wall_m, Vector3(CX + 2.0, 1.3, 6.5), true)
	box(0.25, 0.6, 2.0, wall_m, Vector3(CX + 2.0, 2.3, 0), true)
	# Stairs up (visual) + the way back.
	for i in 5:
		box(1.6, 0.18, 0.5, mat(Color(0.3, 0.24, 0.16), 0.9), Vector3(CX, 0.2 + float(i) * 0.36, 9.6 - float(i) * 0.42), true)
	box(1.8, 2.2, 0.15, TEX.mat_for("wooddoor", Color(0.5, 0.42, 0.3), 0.8), Vector3(CX, 1.6, 7.6))
	label3d("UPSTAIRS", Vector3(CX, 2.1, 9.9), 72, Color(0.9, 0.85, 0.7))
	# The furnace: riveted body, inspection window, stack pipes.
	var iron := mat(Color(0.12, 0.11, 0.12), 0.6)
	box(1.7, 1.8, 1.2, iron, FURNACE_POS + Vector3(0, -0.1, 0), true)
	box(0.5, 0.35, 0.06, glow(Color(1.0, 0.45, 0.1), 2.5), FURNACE_POS + Vector3(0, -0.1, 0.62))
	for px in [-0.4, 0.4]:
		var pipe := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.12
		pm.bottom_radius = 0.12
		pm.height = 1.6
		pipe.mesh = pm
		pipe.material_override = iron
		pipe.position = FURNACE_POS + Vector3(px, 1.6, -0.2)
		add_child(pipe)
	furnace_glow = OmniLight3D.new()
	furnace_glow.light_color = Color(1.0, 0.5, 0.15)
	furnace_glow.light_energy = 0.55
	furnace_glow.omni_range = 5.0
	furnace_glow.position = FURNACE_POS + Vector3(0, -0.2, 1.0)
	add_child(furnace_glow)
	label3d("FURNACE — DO NOT TOUCH -M", FURNACE_POS + Vector3(0, 1.25, 0.3), 48, Color(0.8, 0.7, 0.6))
	# Crates (MILLER 1974) + shelves with paint cans.
	var crate_m := TEX.mat_for("planks", Color(0.5, 0.4, 0.26), 0.9)
	box(1.1, 1.1, 1.1, crate_m, Vector3(CX - 11.0, 0.55, -8.5), true)
	box(0.9, 0.9, 0.9, crate_m, Vector3(CX - 9.9, 0.45, -8.6), true)
	box(0.9, 0.9, 0.9, crate_m, Vector3(CX - 10.6, 1.55, -8.5))
	label3d("MILLER 1974", Vector3(CX - 10.5, 1.0, -7.9), 48, Color(0.75, 0.7, 0.6))
	for sx in [CX - 11.5, CX - 11.5]:
		for sy in [0.5, 1.1, 1.7]:
			box(0.4, 0.06, 2.4, crate_m, Vector3(sx, sy, 2.0), true)
	var can_cols := [Color(0.7, 0.2, 0.15), Color(0.2, 0.4, 0.7), Color(0.75, 0.7, 0.6), Color(0.2, 0.55, 0.25)]
	for i in 4:
		var can := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.09
		cm2.bottom_radius = 0.09
		cm2.height = 0.24
		can.mesh = cm2
		can.material_override = mat(can_cols[i], 0.5)
		can.position = Vector3(CX - 11.5, 0.65 + float(i % 2) * 0.6, 1.2 + float(i / 2) * 1.4)
		add_child(can)
	# Workbench + the spare AA pack + vise.
	var bench_m := TEX.mat_for("planks", Color(0.42, 0.32, 0.2), 0.85)
	box(2.2, 0.12, 0.9, bench_m, BENCH_POS + Vector3(0, 0.05, 0), true)
	for lx in [-0.9, 0.9]:
		box(0.1, 0.9, 0.1, bench_m, BENCH_POS + Vector3(lx, -0.4, 0))
	box(0.22, 0.1, 0.15, mat(Color(0.15, 0.35, 0.55), 0.5), PACK_POS)
	box(0.25, 0.2, 0.2, iron, BENCH_POS + Vector3(0.8, 0.2, 0))
	# Water heater + slop sink along the north wall.
	var heater := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.45
	hm.bottom_radius = 0.45
	hm.height = 1.9
	heater.mesh = hm
	heater.material_override = mat(Color(0.6, 0.62, 0.6), 0.6)
	heater.position = Vector3(CX - 4.0, 0.95, -10.0)
	add_child(heater)
	box(1.1, 1.9, 1.1, mat(Color(0.6, 0.62, 0.6), 0.6), Vector3(CX - 4.0, 0.95, -10.0), true)
	box(0.9, 0.5, 0.6, mat(Color(0.7, 0.7, 0.68), 0.4), Vector3(CX - 1.5, 0.65, -10.2), true)
	# Hanging bulb on the house grid (dies with the ch4 blackout, like home).
	var cord := MeshInstance3D.new()
	var ccm := CylinderMesh.new()
	ccm.top_radius = 0.015
	ccm.bottom_radius = 0.015
	ccm.height = 0.7
	cord.mesh = ccm
	cord.material_override = mat(Color(0.05, 0.05, 0.05), 1.0)
	cord.position = Vector3(CX - 2.0, 2.25, 2.0)
	add_child(cord)
	var bulb_mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	bulb_mi.mesh = sm
	bulb_mi.material_override = glow(Color(1.0, 0.9, 0.7), 2.0)
	bulb_mi.position = Vector3(CX - 2.0, 1.85, 2.0)
	add_child(bulb_mi)
	bulb = OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.9, 0.7)
	bulb.light_energy = 1.6
	bulb.omni_range = 14.0
	bulb.position = Vector3(CX - 2.0, 1.8, 2.0)
	add_child(bulb)


func _process(dt: float) -> void:
	# The furnace never quite sits still.
	pulse_t += dt
	if furnace_glow != null:
		furnace_glow.light_energy = 0.55 + sin(pulse_t * 2.3) * 0.08
