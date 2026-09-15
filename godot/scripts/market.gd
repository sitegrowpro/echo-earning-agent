extends Node3D
## FRESHMART — the supermarket errand (Chapter 1). A bright, humming, safe-
## feeling box... that still manages to be creepy. Six groceries, one chatty
## cashier, and two men by the dairy case who are definitely just normal guys.
## Built far from the house (x ~ 120) so both maps coexist in one scene.

const MX := 120.0
const BOUNDS_MIN := Vector2(106.7, -10.3)
const BOUNDS_MAX := Vector2(133.3, 10.3)
const SPAWN := Vector3(120.0, 0.0, 8.6)
const TEX := preload("res://scripts/tex.gd")

const ITEMS := {
	"milk": {"name": "Milk (2% — Dana specified. Twice.)", "pos": Vector3(118.5, 1.2, -8.7), "prop": Vector3(118.5, 1.05, -8.9), "size": Vector3(0.28, 0.38, 0.28), "color": Color(0.92, 0.94, 0.96)},
	"eggs": {"name": "Eggs (a dozen, hopefully un-cracked)", "pos": Vector3(121.0, 1.2, -8.7), "prop": Vector3(121.0, 1.0, -8.9), "size": Vector3(0.4, 0.18, 0.3), "color": Color(0.87, 0.78, 0.6)},
	"icecream": {"name": "Ice cream (mint chip. For Jamie. Obviously.)", "pos": Vector3(114.5, 1.2, -8.7), "prop": Vector3(114.5, 1.05, -8.9), "size": Vector3(0.35, 0.3, 0.3), "color": Color(0.55, 0.85, 0.75)},
	"bread": {"name": "Bread (the soft kind that dents)", "pos": Vector3(111.75, 1.35, 0.5), "prop": Vector3(111.0, 1.95, 0.5), "size": Vector3(0.5, 0.22, 0.32), "color": Color(0.85, 0.66, 0.4)},
	"catfood": {"name": "Cat food (Biscuit's brand. The expensive one.)", "pos": Vector3(114.25, 1.35, -2.0), "prop": Vector3(115.0, 1.95, -2.0), "size": Vector3(0.35, 0.45, 0.25), "color": Color(0.75, 0.35, 0.15)},
	"batteries": {"name": "Batteries (AA. Storm's coming. Smart.)", "pos": Vector3(123.5, 1.3, 6.5), "prop": Vector3(123.5, 1.15, 6.5), "size": Vector3(0.3, 0.25, 0.2), "color": Color(0.15, 0.35, 0.55)},
}

var item_props := {}
var john: Node3D
var charlie: Node3D
var cashier: Node3D
var john_home := Vector3(122.5, 0, -7.2)
var charlie_home := Vector3(121.2, 0, -6.9)
var flick_mat: StandardMaterial3D
var flick_t := 0.0
var _mats := {}


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
	mi.position = pos
	add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(w, h, d)
		cs.shape = bs
		sb.position = pos
		sb.add_child(cs)
		add_child(sb)
	return mi


func label3d(text: String, pos: Vector3, size := 64, color := Color.WHITE, px := 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.position = pos
	add_child(l)
	return l


func _ready() -> void:
	build()


func build() -> void:
	var X0 := MX - 14.0
	var X1 := MX + 14.0
	var Z0 := -11.0
	var Z1 := 11.0
	# Floor + ceiling.
	var fl := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(X1 - X0, Z1 - Z0)
	fl.mesh = fm
	fl.material_override = TEX.mat_for("tile", Color(0.82, 0.83, 0.82), 0.35)
	fl.position = Vector3(MX, 0.01, 0)
	add_child(fl)
	# (Grout lines now live in the floor texture; the old geometry strips are gone.)
	var ce := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(X1 - X0, Z1 - Z0)
	ce.mesh = cm
	ce.material_override = TEX.mat_for("ceiling", Color(0.58, 0.59, 0.58), 0.9)
	ce.rotation.x = PI
	ce.position = Vector3(MX, 3.4, 0)
	add_child(ce)
	# Walls (front has a door hole x 118..122).
	var wall_m := TEX.mat_for("drywall", Color(0.75, 0.81, 0.75), 0.9)
	box(X1 - X0, 3.4, 0.3, wall_m, Vector3(MX, 1.7, Z0 - 0.15), true)
	box(0.3, 3.4, Z1 - Z0, wall_m, Vector3(X0 - 0.15, 1.7, 0), true)
	box(0.3, 3.4, Z1 - Z0, wall_m, Vector3(X1 + 0.15, 1.7, 0), true)
	box(118.0 - X0, 3.4, 0.3, wall_m, Vector3((X0 + 118.0) * 0.5, 1.7, Z1 + 0.15), true)
	box(X1 - 122.0, 3.4, 0.3, wall_m, Vector3((122.0 + X1) * 0.5, 1.7, Z1 + 0.15), true)
	box(4.0, 0.9, 0.3, wall_m, Vector3(MX, 2.95, Z1 + 0.15), true)
	# Glass entrance doors (shut — you leave through the story, not the mesh).
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 0.55, 0.65, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box(3.8, 2.4, 0.08, glass, Vector3(MX, 1.2, Z1 + 0.1), true)
	label3d("EXIT", Vector3(MX, 2.7, 10.6), 96, Color(1, 0.2, 0.2), 0.003)
	label3d("FRESHMART · OPEN 24 HRS", Vector3(MX, 2.9, 8.0), 72, Color(0.4, 0.9, 0.5))
	box(3.6, 0.03, 1.2, mat(Color(0.2, 0.22, 0.25), 1.0), Vector3(MX, 0.03, 9.8))
	# Front windows glowing against the storm.
	var win_m := glow(Color(0.25, 0.35, 0.55), 0.4)
	for wx in [110.0, 113.0, 127.0, 130.0]:
		var wp := MeshInstance3D.new()
		var wm := PlaneMesh.new()
		wm.size = Vector2(2.2, 1.6)
		wp.mesh = wm
		wp.material_override = win_m
		wp.position = Vector3(wx, 1.8, Z1 - 0.02)
		wp.rotation.y = PI
		add_child(wp)
	# Aisles.
	_shelf(111.0, "AISLE 1 · BREAD")
	_shelf(115.0, "AISLE 2 · PANTRY")
	_shelf(125.0, "AISLE 3 · SNACKS")
	_shelf(129.0, "AISLE 4 · PET & HOME")
	# Dairy case along the back.
	box(11.0, 2.0, 1.2, mat(Color(0.88, 0.9, 0.92), 0.4), Vector3(MX, 1.0, -9.6), true)
	var dairy_glass := MeshInstance3D.new()
	var dg := PlaneMesh.new()
	dg.size = Vector2(10.6, 1.3)
	dairy_glass.mesh = dg
	dairy_glass.material_override = glow(Color(0.75, 0.88, 1.0), 0.5)
	dairy_glass.position = Vector3(MX, 1.25, -8.98)
	add_child(dairy_glass)
	label3d("🥛 DAIRY", Vector3(MX, 2.5, -8.9), 72, Color(0.75, 0.9, 1.0))
	# Freezer end-cap (ice cream lives here).
	box(2.2, 1.6, 1.0, mat(Color(0.6, 0.75, 0.9), 0.4), Vector3(114.5, 0.8, -8.9), true)
	# Checkout counter + cashier.
	box(4.5, 1.0, 1.2, mat(Color(0.55, 0.4, 0.3), 0.7), Vector3(127.5, 0.5, 7.5), true)
	box(4.5, 0.08, 1.3, mat(Color(0.2, 0.2, 0.22), 0.5), Vector3(127.5, 1.04, 7.5))
	label3d("CHECKOUT", Vector3(127.5, 2.6, 7.5), 72, Color(1.0, 0.9, 0.5))
	# Battery display rack.
	box(1.0, 1.0, 0.8, mat(Color(0.3, 0.3, 0.35), 0.8), Vector3(123.5, 0.5, 6.5), true)
	# Carts + baskets by the door.
	for cx in [117.0, 117.9]:
		box(0.7, 0.8, 1.1, mat(Color(0.5, 0.55, 0.6), 0.4, ), Vector3(cx, 0.5, 9.9), true)
	# Lights: bright fluorescents + one tired flickering panel.
	for lp in [Vector3(112, 3.1, -4), Vector3(112, 3.1, 4), Vector3(128, 3.1, -4), Vector3(128, 3.1, 4)]:
		var o := OmniLight3D.new()
		o.light_color = Color(0.95, 0.97, 1.0)
		o.light_energy = 2.6
		o.omni_range = 17.0
		o.position = lp
		add_child(o)
	var panel_m := glow(Color(0.95, 0.97, 1.0), 1.6)
	flick_mat = glow(Color(0.95, 0.97, 1.0), 1.6)
	var pi := 0
	for px in [110.0, 114.0, 118.0, 122.0, 126.0, 130.0]:
		for pz in [-5.0, 1.0, 7.0]:
			var pn := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(2.6, 1.1)
			pn.mesh = pm
			pn.material_override = flick_mat if pi == 7 else panel_m
			pn.rotation.x = PI * 0.5
			pn.rotation.y = PI * 0.5
			pn.position = Vector3(px, 3.35, pz)
			add_child(pn)
			pi += 1
	# Grocery props.
	for id in ITEMS.keys():
		var d: Dictionary = ITEMS[id]
		item_props[id] = box((d["size"] as Vector3).x, (d["size"] as Vector3).y, (d["size"] as Vector3).z, mat(d["color"], 0.6), d["prop"])
	# People.
	cashier = _person("DOT · CASHIER", Color(0.75, 0.15, 0.15), Color(0.72, 0.65, 0.55), Vector3(127.5, 0, 8.7), PI)
	john = _person("JOHN", Color(0.05, 0.05, 0.06), Color(0.8, 0.72, 0.6), john_home, 0.0)
	charlie = _person("CHARLIE", Color(0.15, 0.4, 0.2), Color(0.65, 0.55, 0.45), charlie_home, 0.0)
	# John's white shirt + tie (children of John, so they leave with him).
	for sd in [[0.2, 0.5, 0.05, Color(0.92, 0.92, 0.92), 1.05], [0.08, 0.4, 0.06, Color(0.5, 0.05, 0.05), 1.0]]:
		var smi := MeshInstance3D.new()
		var sbm := BoxMesh.new()
		sbm.size = Vector3(sd[0], sd[1], sd[2])
		smi.mesh = sbm
		smi.material_override = mat(sd[3], 0.7)
		smi.position = Vector3(0, sd[4], 0.24)
		john.add_child(smi)


func _shelf(x: float, sign_text: String) -> void:
	var shelf_m := mat(Color(0.45, 0.47, 0.5), 0.5)
	box(1.2, 1.8, 11.0, shelf_m, Vector3(x, 0.9, -1.0), true)
	box(1.3, 0.08, 11.1, mat(Color(0.6, 0.62, 0.64), 0.5), Vector3(x, 1.84, -1.0))
	# Product boxes: deterministic rainbow of pantry goods.
	var cols := [Color(0.8, 0.2, 0.2), Color(0.2, 0.4, 0.8), Color(0.9, 0.7, 0.2), Color(0.2, 0.6, 0.3), Color(0.7, 0.3, 0.7), Color(0.9, 0.5, 0.15)]
	var ci := 0
	for lvl in [0.55, 1.05, 1.5]:
		for zi in range(9):
			var z := -5.4 + zi * 1.1
			for side in [-0.62, 0.62]:
				var w := 0.35 + float((ci * 7) % 3) * 0.1
				box(w, 0.32, 0.7, mat(cols[ci % cols.size()], 0.7), Vector3(x + side * 0.62, lvl, z))
				ci += 1
	label3d(sign_text, Vector3(x, 2.6, -1.0), 56, Color(1.0, 0.85, 0.4))


func _person(tag: String, clothes: Color, skin: Color, pos: Vector3, face: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = face
	add_child(n)
	var b := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.26
	cm.height = 1.5
	b.mesh = cm
	b.material_override = mat(clothes, 0.9)
	b.position = Vector3(0, 0.85, 0)
	n.add_child(b)
	var h := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	h.mesh = sm
	h.material_override = mat(skin, 0.9)
	h.position = Vector3(0, 1.72, 0)
	n.add_child(h)
	var l := Label3D.new()
	l.text = tag
	l.font_size = 48
	l.pixel_size = 0.003
	l.modulate = Color(1, 1, 1, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 2.1, 0)
	n.add_child(l)
	return n


func _process(dt: float) -> void:
	# One tired fluorescent panel buzzes and drops out.
	if flick_mat == null:
		return
	flick_t -= dt
	if flick_t <= 0.0:
		flick_t = randf_range(0.08, 2.4) if randf() < 0.25 else randf_range(2.0, 7.0)
		flick_mat.emission_energy_multiplier = randf_range(0.15, 0.6) if flick_t < 0.5 else 1.6


func take_item(id: String) -> void:
	if item_props.has(id):
		(item_props[id] as Node3D).visible = false


func reset_run() -> void:
	for id in item_props.keys():
		(item_props[id] as Node3D).visible = true
	if john:
		john.visible = true
		john.position = john_home
	if charlie:
		charlie.visible = true
		charlie.position = charlie_home


func set_folks_home(hidden_folks: bool) -> void:
	if john:
		john.visible = not hidden_folks
	if charlie:
		charlie.visible = not hidden_folks


func folks_leave() -> void:
	if john == null or charlie == null:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(john, "position", Vector3(119.2, 0, 9.9), 4.0)
	t.tween_property(charlie, "position", Vector3(120.8, 0, 9.9), 4.0)
	t.chain().tween_callback(func(): john.visible = false)
	t.tween_callback(func(): charlie.visible = false)
