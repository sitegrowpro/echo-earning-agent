extends Node3D
## WORLD — floorplan-first construction (same guarantee as Episode 1: the plan IS
## the single source of truth; colliders derive from wall data; every door named).
##
## PLAN (meters, X east / Z south, walls 0.2 thick, 2.8 high) — the MILLERS' house:
##   Z -5.5: GUEST ROOM (you) | MASTER BEDROOM (locked) | BATH | LAUNDRY (breaker)
##   Z -1.5: doors D_GUEST D_MASTER D_BATH D_LAUNDRY
##   middle: HALLWAY (thermostat, photos)
##   Z  0.5: two arches into LIVING (TV) + KITCHEN (food, drawer)
##   Z  5.5: FRONT DOOR + 2 windows -> PORCH -> yard -> street -> neighbor

const Door := preload("res://scripts/door.gd")
const H := 2.8
const T := 0.2
const X0 := -8.0
const X1 := 8.0
const ZN := -5.5
const ZS := 5.5

var doors := {}
var room_lights := {}
var power := true
var porch_on := true
var porch_light: OmniLight3D
var tv_on := false
var tv_screen_mat: StandardMaterial3D
var tv_glow: OmniLight3D
var micro_light: OmniLight3D
var escape_win_body: StaticBody3D
var rain_nodes: Array[CPUParticles3D] = []
var _mat_cache := {}

const PERCHES := {
	"porch": {"x": 0.0, "z": 7.2, "face": PI},
	"living_win": {"x": -4.5, "z": 6.4, "face": PI},
	"kitchen_win": {"x": 4.5, "z": 6.4, "face": PI},
	"master_win": {"x": 1.5, "z": -6.4, "face": 0.0},
	"lamp": {"x": 7.2, "z": 11.8, "face": PI * 0.75},
}
const HIDE := {
	"bed": {"pos": Vector3(-6.4, 0.42, -3.6), "look": Vector3(-5.5, 1.0, -1.4)},
	"closet": {"pos": Vector3(-2.7, 1.45, -2.0), "look": Vector3(-6.0, 1.1, -2.2)},
	"pcloset": {"pos": Vector3(3.2, 1.45, -2.0), "look": Vector3(0.5, 1.1, -2.4)},
	"couch": {"pos": Vector3(-2.0, 1.18, 3.35), "look": Vector3(-2.0, 0.95, 0.7)},
}


func _ready() -> void:
	build()


func mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "%s_%f_%f" % [c.to_html(), rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mat_cache[key] = m
	return m


func glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.06)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func box(w: float, h: float, d: float, m: Material, pos: Vector3, ry := 0.0, collide := false, layer := 1) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = m
	if not collide:
		mi.position = pos
		mi.rotation.y = ry
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = ry
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h, d)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	return body


func blocker(x0: float, z0: float, x1: float, z1: float, is_escape := false) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 32
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(absf(x1 - x0), H, absf(z1 - z0))
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3((x0 + x1) * 0.5, H * 0.5, (z0 + z1) * 0.5)
	add_child(body)
	if is_escape:
		escape_win_body = body


# ---------- wall runs with intentional holes ----------
func run_h(z: float, x1: float, x2: float, holes: Array, material: Material) -> void:
	var hs := holes.duplicate()
	hs.sort_custom(func(a, b): return a["at"] < b["at"])
	var cx := x1
	var segs: Array = []
	for h in hs:
		var hx0: float = x1 + h["at"] - h["w"] * 0.5
		var hx1: float = x1 + h["at"] + h["w"] * 0.5
		segs.append([cx, hx0])
		_finish_hole_h(z, hx0, hx1, h, material)
		cx = hx1
	segs.append([cx, x2])
	for s in segs:
		if s[1] - s[0] < 0.01:
			continue
		box(s[1] - s[0], H, T, material, Vector3((s[0] + s[1]) * 0.5, H * 0.5, z), 0.0, true)


func _finish_hole_h(z: float, hx0: float, hx1: float, h: Dictionary, material: Material) -> void:
	var y0: float = h.get("y0", 0.0)
	var y1: float = h.get("y1", 2.15)
	var w := hx1 - hx0
	var cx := (hx0 + hx1) * 0.5
	if y1 < H - 0.01:
		box(w, H - y1, T, material, Vector3(cx, (H + y1) * 0.5, z)) # lintel (overhead, no collide)
	if y0 > 0.01:
		box(w, y0, T, material, Vector3(cx, y0 * 0.5, z), 0.0, true) # sill wall
	_trim_h(z, hx0, hx1, y0, y1)
	if h.get("kind", "") == "window" or h.get("kind", "") == "escape-window":
		window_glass(cx, (y0 + y1) * 0.5, z, w, y1 - y0, true)


func run_v(x: float, z1: float, z2: float, holes: Array, material: Material) -> void:
	var hs := holes.duplicate()
	hs.sort_custom(func(a, b): return a["at"] < b["at"])
	var cz := z1
	var segs: Array = []
	for h in hs:
		var hz0: float = z1 + h["at"] - h["w"] * 0.5
		var hz1: float = z1 + h["at"] + h["w"] * 0.5
		segs.append([cz, hz0])
		var y0: float = h.get("y0", 0.0)
		var y1: float = h.get("y1", 2.15)
		var w := hz1 - hz0
		var cc := (hz0 + hz1) * 0.5
		if y1 < H - 0.01:
			box(T, H - y1, w, material, Vector3(x, (H + y1) * 0.5, cc))
		if y0 > 0.01:
			box(T, y0, w, material, Vector3(x, y0 * 0.5, cc), 0.0, true)
		_trim_v(x, hz0, hz1, y0, y1)
		if h.get("kind", "") == "window":
			window_glass(x, (y0 + y1) * 0.5, cc, w, y1 - y0, false)
		cz = hz1
	segs.append([cz, z2])
	for s in segs:
		if s[1] - s[0] < 0.01:
			continue
		box(T, H, s[1] - s[0], material, Vector3(x, H * 0.5, (s[0] + s[1]) * 0.5), 0.0, true)


func _trim_h(z: float, hx0: float, hx1: float, y0: float, y1: float) -> void:
	var tm := mat(Color(0.29, 0.21, 0.14), 0.7)
	var w := 0.09
	box(w, y1 - y0, T + 0.06, tm, Vector3(hx0 + w * 0.5, (y0 + y1) * 0.5, z))
	box(w, y1 - y0, T + 0.06, tm, Vector3(hx1 - w * 0.5, (y0 + y1) * 0.5, z))
	box(hx1 - hx0 + w, w, T + 0.06, tm, Vector3((hx0 + hx1) * 0.5, y1 - w * 0.5, z))


func _trim_v(x: float, hz0: float, hz1: float, y0: float, y1: float) -> void:
	var tm := mat(Color(0.29, 0.21, 0.14), 0.7)
	var w := 0.09
	box(T + 0.06, y1 - y0, w, tm, Vector3(x, (y0 + y1) * 0.5, hz0 + w * 0.5))
	box(T + 0.06, y1 - y0, w, tm, Vector3(x, (y0 + y1) * 0.5, hz1 - w * 0.5))
	box(T + 0.06, w, hz1 - hz0 + w, tm, Vector3(x, y1 - w * 0.5, (hz0 + hz1) * 0.5))


func window_glass(cx: float, cy: float, cz: float, w: float, h: float, horiz: bool) -> void:
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.56, 0.66, 0.78, 0.16)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.roughness = 0.1
	g.metallic = 0.4
	g.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fm := mat(Color(0.17, 0.17, 0.2), 0.6)
	if horiz:
		box(w - 0.1, h - 0.1, 0.03, g, Vector3(cx, cy, cz))
		box(w - 0.1, 0.05, 0.05, fm, Vector3(cx, cy, cz))
		box(0.05, h - 0.1, 0.05, fm, Vector3(cx, cy, cz))
		box(w + 0.1, 0.07, 0.3, mat(Color(0.42, 0.36, 0.27), 0.8), Vector3(cx, cy - h * 0.5, cz))
	else:
		box(0.03, h - 0.1, w - 0.1, g, Vector3(cx, cy, cz))
		box(0.05, 0.05, w - 0.1, fm, Vector3(cx, cy, cz))
		box(0.05, h - 0.1, 0.05, fm, Vector3(cx, cy, cz))
		box(0.3, 0.07, w + 0.1, mat(Color(0.42, 0.36, 0.27), 0.8), Vector3(cx, cy - h * 0.5, cz))


func add_door(id: String, x: float, z: float, w: float, swing: float, opts: Dictionary) -> void:
	var d = Door.new()
	d.position = Vector3(x, 0, z)
	add_child(d)
	d.setup(id, w, swing, opts.get("open", false), opts.get("locked", false), opts.get("label", id), opts.get("color", Color(0.36, 0.27, 0.19)))
	doors[id] = d


# ---------- lights / power ----------
func room_light(room: String, l: OmniLight3D) -> void:
	if not room_lights.has(room):
		room_lights[room] = {"lights": [], "on": true}
	(room_lights[room]["lights"] as Array).append(l)


func set_room_light(room: String, on: bool) -> void:
	if room_lights.has(room):
		room_lights[room]["on"] = on
		apply_lights()


func set_power(on: bool) -> void:
	power = on
	apply_lights()
	if not on:
		set_tv(false)


func apply_lights() -> void:
	for room in room_lights.keys():
		var r: Dictionary = room_lights[room]
		for l in (r["lights"] as Array):
			(l as OmniLight3D).visible = power and bool(r["on"])
	if porch_light:
		porch_light.visible = power and porch_on
	_apply_flicker_end()


func _apply_flicker_end() -> void:
	pass


func set_tv(on: bool) -> void:
	tv_on = on
	if tv_screen_mat:
		tv_screen_mat.emission_energy_multiplier = 1.6 if on else 0.02
	if tv_glow:
		tv_glow.visible = on and power


func build() -> void:
	_build_env()
	var wall_in := mat(Color(0.72, 0.67, 0.56), 0.9)
	var wall_out := mat(Color(0.43, 0.42, 0.39), 0.95)
	var wood := mat(Color(0.48, 0.36, 0.24), 0.7)
	var tile := mat(Color(0.6, 0.63, 0.64), 0.4)
	var carpet := mat(Color(0.3, 0.27, 0.35), 1.0)
	var conc := mat(Color(0.36, 0.36, 0.38), 0.95)
	_floor(X0, 0.5, 0.0, ZS, wood)
	_floor(0.0, 0.5, X1, ZS, tile)
	_floor(X0, -1.5, X1, 0.5, wood)
	_floor(X0, ZN, -2.0, -1.5, carpet)
	_floor(-2.0, ZN, 4.0, -1.5, carpet)
	_floor(4.0, ZN, 6.5, -1.5, tile)
	_floor(6.5, ZN, X1, -1.5, conc)
	var ceil_mi := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(X1 - X0 + 1.0, ZS - ZN + 1.0)
	ceil_mi.mesh = cm
	ceil_mi.material_override = mat(Color(0.85, 0.82, 0.76), 0.95)
	ceil_mi.position = Vector3(0, H, 0)
	add_child(ceil_mi)
	box(X1 - X0 + 1.6, 0.25, ZS - ZN + 1.6, mat(Color(0.1, 0.1, 0.13), 1.0), Vector3(0, H + 0.2, 0))
	# exterior walls
	run_h(ZS, X0, X1, [
		{"at": 3.5, "w": 1.9, "y0": 0.95, "y1": 2.25, "kind": "window"},
		{"at": 8.0, "w": 1.15, "y0": 0.0, "y1": 2.15, "kind": "door"},
		{"at": 12.5, "w": 1.9, "y0": 0.95, "y1": 2.25, "kind": "window"},
	], wall_out)
	run_h(ZN, X0, X1, [
		{"at": 2.5, "w": 1.5, "y0": 0.9, "y1": 2.2, "kind": "escape-window"},
		{"at": 9.5, "w": 1.5, "y0": 0.95, "y1": 2.25, "kind": "window"},
		{"at": 13.2, "w": 0.8, "y0": 1.5, "y1": 2.25, "kind": "window"},
	], wall_out)
	run_v(X0, ZN, ZS, [{"at": 8.5, "w": 1.6, "y0": 0.95, "y1": 2.25, "kind": "window"}], wall_out)
	run_v(X1, ZN, ZS, [{"at": 8.5, "w": 1.4, "y0": 0.95, "y1": 2.25, "kind": "window"}], wall_out)
	# interior walls
	run_h(0.5, X0, X1, [
		{"at": 3.5, "w": 1.7, "y0": 0.0, "y1": 2.3, "kind": "arch"},
		{"at": 12.5, "w": 1.7, "y0": 0.0, "y1": 2.3, "kind": "arch"},
	], wall_in)
	run_h(-1.5, X0, X1, [
		{"at": 2.5, "w": 1.0, "kind": "door"},
		{"at": 9.5, "w": 1.0, "kind": "door"},
		{"at": 13.2, "w": 0.9, "kind": "door"},
		{"at": 15.25, "w": 0.85, "kind": "door"},
	], wall_in)
	run_v(0.0, 0.5, ZS, [{"at": 2.5, "w": 2.1, "y0": 0.0, "y1": 2.3, "kind": "arch"}], wall_in)
	run_v(-2.0, ZN, -1.5, [], wall_in)
	run_v(4.0, ZN, -1.5, [], wall_in)
	run_v(6.5, ZN, -1.5, [], wall_in)
	# window passage blockers (solid, but on layer 32: sight passes through)
	blocker(-5.45, ZS - 0.15, -3.55, ZS + 0.15)
	blocker(3.55, ZS - 0.15, 5.45, ZS + 0.15)
	blocker(-6.25, ZN - 0.15, -4.75, ZN + 0.15, true)
	blocker(0.75, ZN - 0.15, 2.25, ZN + 0.15)
	blocker(4.8, ZN - 0.15, 5.6, ZN + 0.15)
	blocker(X0 - 0.15, 2.2, X0 + 0.15, 3.8)
	blocker(X1 - 0.15, 2.3, X1 + 0.15, 3.7)
	# doors (named, purposeful)
	add_door("front", -0.575, ZS, 1.09, 1.92, {"label": "Front door", "color": Color(0.43, 0.18, 0.15)})
	add_door("guest", -6.0, -1.5, 0.94, 1.92, {"label": "Guest room door", "open": true})
	add_door("master", 1.0, -1.5, 0.94, 1.92, {"label": "Master bedroom door", "locked": true})
	add_door("bath", 4.75, -1.5, 0.84, 1.92, {"label": "Bathroom door", "open": true})
	add_door("laundry", 6.825, -1.5, 0.79, 1.92, {"label": "Laundry door"})
	_furnish()
	_light_rig()
	_outside()


func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.01, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.12, 0.15, 0.22)
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_density = 0.022
	e.fog_light_color = Color(0.03, 0.04, 0.07)
	we.environment = e
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.56, 0.66, 1.0)
	moon.light_energy = 0.25
	moon.shadow_enabled = false
	moon.rotation_degrees = Vector3(-50, -30, 0)
	add_child(moon)


func _floor(x0: float, z0: float, x1: float, z1: float, m: Material) -> void:
	var f := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z1 - z0)
	f.mesh = pm
	f.material_override = m
	f.position = Vector3((x0 + x1) * 0.5, 0.01, (z0 + z1) * 0.5)
	add_child(f)


func _furnish() -> void:
	var wood_d := mat(Color(0.31, 0.23, 0.15), 0.7)
	var fabric := mat(Color(0.22, 0.27, 0.36), 1.0)
	var fabric2 := mat(Color(0.36, 0.22, 0.22), 1.0)
	var white := mat(Color(0.85, 0.85, 0.85), 0.6)
	var steel := mat(Color(0.54, 0.56, 0.58), 0.35, 0.5)
	# LIVING
	box(1.5, 0.45, 0.45, wood_d, Vector3(-2, 0.22, 0.85), 0.0, true)
	box(1.35, 0.78, 0.08, mat(Color(0.04, 0.04, 0.05), 0.4), Vector3(-2, 0.9, 0.78))
	tv_screen_mat = StandardMaterial3D.new()
	tv_screen_mat.albedo_color = Color(0.02, 0.02, 0.03)
	tv_screen_mat.emission_enabled = true
	tv_screen_mat.emission = Color(0.56, 0.71, 1.0)
	tv_screen_mat.emission_energy_multiplier = 0.02
	var scr := MeshInstance3D.new()
	var spm := PlaneMesh.new()
	spm.size = Vector2(1.24, 0.68)
	scr.mesh = spm
	scr.material_override = tv_screen_mat
	scr.position = Vector3(-2, 0.9, 0.83)
	add_child(scr)
	tv_glow = OmniLight3D.new()
	tv_glow.light_color = Color(0.56, 0.71, 1.0)
	tv_glow.light_energy = 1.2
	tv_glow.omni_range = 7.0
	tv_glow.position = Vector3(-2, 1.1, 1.6)
	tv_glow.visible = false
	add_child(tv_glow)
	box(2.2, 0.5, 0.95, fabric, Vector3(-2, 0.35, 3.3), 0.0, true)
	box(2.2, 0.65, 0.28, fabric, Vector3(-2, 0.75, 3.75), 0.0, true)
	box(0.28, 0.65, 0.95, fabric, Vector3(-3.0, 0.5, 3.3))
	box(0.28, 0.65, 0.95, fabric, Vector3(-1.0, 0.5, 3.3))
	box(1.2, 0.4, 0.6, wood_d, Vector3(-2, 0.2, 2.1), 0.0, true)
	box(3.0, 0.03, 2.2, mat(Color(0.43, 0.23, 0.23), 1.0), Vector3(-2, 0.03, 2.9))
	box(0.4, 1.9, 2.4, wood_d, Vector3(-7.7, 0.95, 2.6), 0.0, true)
	var book_cols := [Color(0.48, 0.18, 0.18), Color(0.18, 0.29, 0.48), Color(0.25, 0.48, 0.18)]
	for i in 3:
		box(0.34, 0.28, 2.1, mat(book_cols[i], 1.0), Vector3(-7.7, 0.6 + i * 0.5, 2.6))
	box(0.35, 1.6, 0.35, mat(Color(0.13, 0.13, 0.15), 0.6), Vector3(-7.3, 0.8, 4.9), 0.0, true)
	box(0.55, 0.4, 0.55, glow_mat(Color(1.0, 0.9, 0.64), 0.4), Vector3(-7.3, 1.75, 4.9))
	box(0.9, 0.75, 0.45, wood_d, Vector3(-7.6, 0.37, 0.95), 0.0, true)
	# KITCHEN
	box(0.7, 0.9, 3.4, mat(Color(0.81, 0.78, 0.72), 0.6), Vector3(7.55, 0.45, 3.3), 0.0, true)
	box(0.75, 0.06, 3.5, mat(Color(0.24, 0.24, 0.27), 0.4), Vector3(7.55, 0.93, 3.3))
	box(0.6, 0.5, 0.9, mat(Color(0.13, 0.13, 0.15), 0.5), Vector3(7.5, 1.2, 1.9))
	box(0.05, 0.36, 0.7, mat(Color(0.07, 0.07, 0.08), 0.2), Vector3(7.18, 1.2, 1.9))
	micro_light = OmniLight3D.new()
	micro_light.light_color = Color(1.0, 0.83, 0.54)
	micro_light.light_energy = 1.5
	micro_light.omni_range = 3.0
	micro_light.position = Vector3(7.2, 1.3, 1.9)
	micro_light.visible = false
	add_child(micro_light)
	box(0.7, 0.9, 0.8, white, Vector3(7.55, 0.45, 5.0), 0.0, true)
	box(0.5, 0.1, 0.6, mat(Color(0.11, 0.11, 0.13), 0.5), Vector3(7.55, 0.93, 5.0))
	box(0.9, 1.9, 0.9, steel, Vector3(7.4, 0.95, 1.0), 0.0, true)
	box(1.8, 0.9, 0.9, mat(Color(0.54, 0.48, 0.37), 0.7), Vector3(4.2, 0.45, 3.3), 0.0, true)
	box(1.9, 0.06, 1.0, mat(Color(0.24, 0.24, 0.27), 0.4), Vector3(4.2, 0.93, 3.3))
	box(0.5, 0.35, 0.4, mat(Color(0.69, 0.54, 0.27), 0.9), Vector3(3.7, 1.13, 3.2))
	box(0.4, 0.3, 0.35, mat(Color(0.62, 0.72, 0.5), 0.9), Vector3(4.6, 1.1, 3.45))
	# cat bowls (Biscuit's dinner — chapter 1)
	box(0.28, 0.1, 0.28, mat(Color(0.75, 0.3, 0.3), 0.6), Vector3(6.6, 0.05, 4.9))
	box(0.28, 0.1, 0.28, mat(Color(0.3, 0.5, 0.75), 0.6), Vector3(6.2, 0.05, 4.9))
	box(1.1, 0.75, 1.1, wood_d, Vector3(1.8, 0.37, 4.6), 0.0, true)
	box(0.45, 0.8, 0.45, wood_d, Vector3(1.8, 0.4, 3.8), 0.0, true)
	box(0.45, 0.8, 0.45, wood_d, Vector3(2.6, 0.4, 4.6), 0.0, true)
	# HALL
	box(1.4, 0.8, 0.35, wood_d, Vector3(-3.5, 0.4, -1.25), 0.0, true)
	box(3.5, 0.03, 0.9, mat(Color(0.33, 0.26, 0.18), 1.0), Vector3(-1, 0.03, -0.5))
	# GUEST ROOM (yours for the night)
	box(1.7, 0.55, 2.2, mat(Color(0.18, 0.23, 0.36), 1.0), Vector3(-6.4, 0.32, -4.2), 0.0, true)
	box(1.7, 0.18, 2.2, mat(Color(0.48, 0.55, 0.69), 1.0), Vector3(-6.4, 0.65, -4.2))
	box(1.7, 0.9, 0.15, wood_d, Vector3(-6.4, 0.6, -5.35), 0.0, true)
	box(0.7, 0.15, 0.45, white, Vector3(-6.7, 0.78, -4.9))
	box(0.7, 0.15, 0.45, white, Vector3(-6.1, 0.78, -4.9))
	box(0.5, 0.55, 0.5, wood_d, Vector3(-7.5, 0.27, -5.1), 0.0, true)
	box(1.4, 0.75, 0.6, wood_d, Vector3(-3.0, 0.37, -5.05), 0.0, true)
	box(0.5, 0.5, 0.5, fabric2, Vector3(-3.0, 0.25, -4.3), 0.0, true)
	box(0.5, 0.06, 0.35, mat(Color(0.23, 0.25, 0.29), 0.5), Vector3(-3.2, 0.78, -5.05))
	box(0.35, 0.12, 0.28, mat(Color(0.64, 0.24, 0.24), 0.8), Vector3(-2.7, 0.8, -5.1))
	box(1.3, 2.0, 0.6, wood_d, Vector3(-2.7, 1.0, -2.0), 0.0, true)
	box(0.04, 1.7, 0.5, mat(Color(0.2, 0.15, 0.1), 0.7), Vector3(-3.36, 1.0, -2.0))
	_poster(Vector3(-5.2, 1.7, -5.38), Color(0.14, 0.25, 0.42))
	_poster(Vector3(-4.3, 1.7, -5.38), Color(0.42, 0.14, 0.14))
	# MASTER BEDROOM (locked)
	box(1.9, 0.55, 2.2, mat(Color(0.36, 0.29, 0.43), 1.0), Vector3(0.6, 0.32, -4.2), 0.0, true)
	box(1.9, 0.18, 2.2, mat(Color(0.6, 0.55, 0.69), 1.0), Vector3(0.6, 0.65, -4.2))
	box(1.9, 0.9, 0.15, wood_d, Vector3(0.6, 0.6, -5.35), 0.0, true)
	box(1.5, 0.85, 0.5, wood_d, Vector3(3.3, 0.42, -5.1), 0.0, true)
	box(1.3, 2.0, 0.6, wood_d, Vector3(3.2, 1.0, -2.0), 0.0, true)
	box(0.5, 0.55, 0.5, wood_d, Vector3(-0.7, 0.27, -5.1), 0.0, true)
	# BATH
	box(0.85, 0.6, 1.7, white, Vector3(4.6, 0.3, -4.5), 0.0, true)
	box(0.5, 0.45, 0.6, white, Vector3(5.9, 0.22, -4.9), 0.0, true)
	box(0.6, 0.8, 0.5, white, Vector3(5.2, 0.4, -2.0), 0.0, true)
	var mir := MeshInstance3D.new()
	var mm := PlaneMesh.new()
	mm.size = Vector2(0.55, 0.75)
	mir.mesh = mm
	var mirm := StandardMaterial3D.new()
	mirm.albedo_color = Color(0.1, 0.13, 0.16)
	mirm.roughness = 0.05
	mirm.metallic = 0.9
	mir.material_override = mirm
	mir.position = Vector3(5.2, 1.65, -1.62)
	mir.rotation.y = PI
	add_child(mir)
	# LAUNDRY
	box(0.65, 0.95, 0.65, white, Vector3(6.95, 0.47, -5.0), 0.0, true)
	box(0.65, 0.95, 0.65, white, Vector3(7.6, 0.47, -5.0), 0.0, true)
	box(0.35, 1.8, 1.4, mat(Color(0.33, 0.33, 0.38), 0.8), Vector3(7.8, 0.9, -3.4), 0.0, true)
	box(0.3, 0.25, 0.4, mat(Color(0.85, 0.73, 0.24), 0.6), Vector3(7.8, 1.25, -3.6))
	box(0.12, 0.6, 0.45, mat(Color(0.23, 0.25, 0.27), 0.5, 0.4), Vector3(7.9, 1.55, -2.6))
	box(0.04, 0.4, 0.3, mat(Color(0.76, 0.07, 0.12), 0.5), Vector3(7.83, 1.55, -2.6))


func _poster(pos: Vector3, c: Color) -> void:
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.7, 0.95)
	p.mesh = pm
	p.material_override = mat(c, 0.9)
	p.position = pos
	add_child(p)


func _omni(room: String, color: Color, energy: float, dist: float, pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = dist
	l.position = pos
	add_child(l)
	room_light(room, l)


func _light_rig() -> void:
	_omni("living", Color(1.0, 0.85, 0.63), 2.2, 11.0, Vector3(-4, 2.3, 3))
	_omni("living", Color(1.0, 0.9, 0.64), 1.2, 6.0, Vector3(-7.3, 1.9, 4.9))
	_omni("kitchen", Color(1.0, 0.95, 0.85), 2.2, 11.0, Vector3(4, 2.4, 3))
	_omni("hall", Color(1.0, 0.91, 0.77), 1.8, 9.0, Vector3(0, 2.4, -0.5))
	_omni("guest", Color(1.0, 0.85, 0.63), 1.6, 7.0, Vector3(-4.5, 2.0, -3.5))
	_omni("guest", Color(0.81, 0.88, 1.0), 0.9, 4.0, Vector3(-3.0, 1.3, -5.0))
	_omni("master", Color(1.0, 0.91, 0.77), 1.8, 9.0, Vector3(1, 2.4, -3.5))
	_omni("bath", Color(0.84, 0.93, 1.0), 1.6, 6.0, Vector3(5.2, 2.3, -3.5))
	_omni("laundry", Color(1.0, 0.97, 0.85), 1.8, 7.0, Vector3(7.2, 2.3, -3.5))
	porch_light = OmniLight3D.new()
	porch_light.light_color = Color(1.0, 0.85, 0.63)
	porch_light.light_energy = 3.0
	porch_light.omni_range = 14.0
	porch_light.shadow_enabled = true
	porch_light.position = Vector3(0, 2.9, 6.8)
	add_child(porch_light)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	bulb.mesh = sm
	bulb.material_override = glow_mat(Color(1.0, 0.83, 0.54), 2.0)
	bulb.position = Vector3(0, 2.9, 6.7)
	add_child(bulb)


func _outside() -> void:
	var gnd := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(90, 60)
	gnd.mesh = gm
	gnd.material_override = mat(Color(0.08, 0.1, 0.09), 1.0)
	gnd.position = Vector3(0, -0.02, 4)
	add_child(gnd)
	var path := MeshInstance3D.new()
	var phm := PlaneMesh.new()
	phm.size = Vector2(1.6, 8.5)
	path.mesh = phm
	path.material_override = mat(Color(0.25, 0.23, 0.2), 1.0)
	path.position = Vector3(0, 0.0, 9.5)
	add_child(path)
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(90, 3.4)
	road.mesh = rm
	road.material_override = mat(Color(0.05, 0.05, 0.06), 1.0)
	road.position = Vector3(0, 0.0, 15)
	add_child(road)
	var deck := mat(Color(0.35, 0.27, 0.2), 0.9)
	box(6.4, 0.18, 2.6, deck, Vector3(0, 0.09, 6.8))
	box(0.18, 3.0, 0.18, mat(Color(0.23, 0.18, 0.12), 0.9), Vector3(-2.9, 1.5, 7.9), 0.0, true)
	box(0.18, 3.0, 0.18, mat(Color(0.23, 0.18, 0.12), 0.9), Vector3(2.9, 1.5, 7.9), 0.0, true)
	box(6.8, 0.15, 3.0, mat(Color(0.08, 0.08, 0.09), 1.0), Vector3(0, 3.05, 6.8))
	box(2.0, 0.12, 0.6, deck, Vector3(0, 0.06, 8.35))
	box(1.6, 0.03, 1.0, mat(Color(0.43, 0.23, 0.23), 1.0), Vector3(0, 0.2, 6.1))
	box(0.12, 1.1, 0.12, mat(Color(0.23, 0.18, 0.12), 0.9), Vector3(2.2, 0.55, 9.0), 0.0, true)
	box(0.55, 0.3, 0.35, mat(Color(0.18, 0.29, 0.48), 0.6), Vector3(2.2, 1.2, 9.0))
	box(0.6, 0.95, 0.6, mat(Color(0.17, 0.18, 0.21), 0.8), Vector3(-2.6, 0.47, 6.3), 0.0, true)
	box(0.66, 0.1, 0.66, mat(Color(0.11, 0.13, 0.15), 0.8), Vector3(-2.6, 0.98, 6.3))
	box(0.16, 5.2, 0.16, mat(Color(0.13, 0.13, 0.16), 0.6, 0.5), Vector3(8, 2.6, 12.5), 0.0, true)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.32
	head.mesh = hm
	head.material_override = glow_mat(Color(1.0, 0.91, 0.64), 3.0)
	head.position = Vector3(8, 5.2, 12.5)
	add_child(head)
	var sl := OmniLight3D.new()
	sl.light_color = Color(1.0, 0.91, 0.64)
	sl.light_energy = 4.0
	sl.omni_range = 20.0
	sl.position = Vector3(8, 5.0, 12.5)
	add_child(sl)
	# neighbor house (escape A)
	box(7, 3.6, 5.5, mat(Color(0.14, 0.13, 0.16), 1.0), Vector3(-17, 1.8, 10), 0.0, true)
	box(7.6, 0.4, 6.1, mat(Color(0.06, 0.06, 0.08), 1.0), Vector3(-17, 3.8, 10))
	var nwin := MeshInstance3D.new()
	var nw := PlaneMesh.new()
	nw.size = Vector2(1.4, 1.0)
	nwin.mesh = nw
	nwin.material_override = glow_mat(Color(1.0, 0.83, 0.54), 1.8)
	nwin.position = Vector3(-15.5, 1.7, 7.24)
	nwin.rotation.y = PI
	add_child(nwin)
	box(1.1, 2.1, 0.1, mat(Color(0.43, 0.18, 0.15), 0.7), Vector3(-18.2, 1.05, 7.25))
	var nl := OmniLight3D.new()
	nl.light_color = Color(1.0, 0.85, 0.63)
	nl.light_energy = 3.5
	nl.omni_range = 16.0
	nl.position = Vector3(-17, 3.0, 7.0)
	add_child(nl)
	_tree(Vector3(-11, 0, 2), 1.0)
	_tree(Vector3(11.5, 0, 1), 1.2)
	_tree(Vector3(-12, 0, -7), 1.3)
	_tree(Vector3(12, 0, -7), 1.0)
	_tree(Vector3(5, 0, -9), 1.1)
	_tree(Vector3(-5, 0, -9), 1.0)
	_tree(Vector3(14, 0, 9), 1.2)
	_tree(Vector3(-10, 0, 13), 1.0)
	var fence_m := mat(Color(0.18, 0.15, 0.13), 1.0)
	box(0.15, 1.1, 22.0, fence_m, Vector3(-11, 0.55, 2), 0.0, true)
	box(0.15, 1.1, 22.0, fence_m, Vector3(11, 0.55, 2), 0.0, true)
	box(22.0, 1.1, 0.15, fence_m, Vector3(0, 0.55, -8), 0.0, true)
	_make_rain(Vector3(0, 9, 11), Vector3(32, 1, 5.5))    # front yard
	_make_rain(Vector3(0, 9, -8), Vector3(32, 1, 2.0))    # back yard strip
	_make_rain(Vector3(-20, 9, 0), Vector3(12, 1, 8))     # west side
	_make_rain(Vector3(20, 9, 0), Vector3(12, 1, 8))      # east side


func _tree(pos: Vector3, s: float) -> void:
	box(0.3 * s, 1.6 * s, 0.3 * s, mat(Color(0.18, 0.13, 0.09), 1.0), Vector3(pos.x, 0.8 * s, pos.z), 0.0, true)
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 1.3 * s
	cm.height = 3.2 * s
	c.mesh = cm
	c.material_override = mat(Color(0.06, 0.1, 0.07), 1.0)
	c.position = Vector3(pos.x, 2.8 * s, pos.z)
	add_child(c)


func _make_rain(center: Vector3, extents: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 320
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0, -1, 0)
	p.spread = 3.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3(0, -2, 0)
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.22, 0.015)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.56, 0.66, 0.78, 0.55)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	p.draw_pass_1 = drop
	p.position = center
	add_child(p)
	rain_nodes.append(p)


func set_rain(on: bool) -> void:
	for r in rain_nodes:
		r.emitting = on


func room_at(x: float, z: float) -> String:
	if z >= 5.5:
		return "porch"
	if z >= 0.5:
		return "living" if x < 0.0 else "kitchen"
	if z >= -1.5:
		return "hall"
	if x < -2.0:
		return "guest"
	if x < 4.0:
		return "master"
	if x < 6.5:
		return "bath"
	return "laundry"


func room_name(r: String) -> String:
	var names := {
		"living": "LIVING ROOM", "kitchen": "KITCHEN", "hall": "HALLWAY",
		"guest": "GUEST ROOM", "master": "MASTER BEDROOM", "bath": "BATHROOM",
		"laundry": "LAUNDRY", "porch": "FRONT PORCH", "yard": "YARD", "street": "STREET",
	}
	return names.get(r, r.to_upper())
