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
const TEX := preload("res://scripts/tex.gd")
const H := 2.8
const T := 0.2
const X0 := -8.0
const X1 := 8.0
const ZN := -5.5
const ZS := 5.5
# Wall clock: living-room south wall, between the window and the front door.
const CLOCK_POS := Vector3(-1.5, 2.0, 5.36)
# Light-seep: rooms on each side of every door (front opens to the porch).
const DOOR_ROOMS := {
	"front": ["living", "porch"], "guest": ["hall", "guest"],
	"master": ["hall", "master"], "bath": ["hall", "bath"],
	"laundry": ["hall", "laundry"],
}

var doors := {}
var door_seep := {} # id -> {"mat": StandardMaterial3D, "rooms": Array}
var _seep_sig := ""
var shade_mats := {}
var fan_hubs: Array[Node3D] = []
var clock_sec: Node3D
var clock_sec_a := 0.0
var glimpse: MeshInstance3D
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
var env: Environment
var moon: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
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
	_add_seep(id, x, z, w)


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


# ---------- door light-seep (F2F hallway slivers) ----------
func _add_seep(id: String, x: float, z: float, w: float) -> void:
	if not DOOR_ROOMS.has(id):
		return
	var smat := glow_mat(Color(1.0, 0.8, 0.55), 0.0)
	# Thin emissive threshold strip; added to the WORLD (not the door: the door rotates).
	box(w - 0.06, 0.03, 0.1, smat, Vector3(x + w * 0.5, 0.015, z))
	door_seep[id] = {"mat": smat, "rooms": DOOR_ROOMS[id]}


func _room_glow(room: String) -> bool:
	if room == "porch":
		return porch_light != null and porch_light.visible
	if not room_lights.has(room):
		return false
	for l in ((room_lights[room] as Dictionary)["lights"] as Array):
		if (l as OmniLight3D).visible:
			return true
	return false


func _process(dt: float) -> void:
	if power:
		for f in fan_hubs:
			f.rotate_y(dt * 2.8)
	if door_seep.is_empty():
		return
	# Signature-gated: recompute strip energies only when light/door state changes.
	# Reads live light.visible, so power cuts, switches AND flicker events all show.
	var states := {}
	var sig := ""
	for id in door_seep.keys():
		var e: Dictionary = door_seep[id]
		var pair: Array = e["rooms"]
		var lit := _room_glow(String(pair[0])) or _room_glow(String(pair[1]))
		var shut := not bool((doors[id] as AnimatableBody3D).get("is_open"))
		states[id] = lit and shut
		sig += "%s%d" % [id, 1 if states[id] else 0]
	for room in shade_mats.keys():
		sig += "%s%d" % [room, 1 if _room_glow(room) else 0]
	if sig == _seep_sig:
		return
	_seep_sig = sig
	for id in states.keys():
		((door_seep[id] as Dictionary)["mat"] as StandardMaterial3D).emission_energy_multiplier = 2.4 if bool(states[id]) else 0.0
	for room in shade_mats.keys():
		var glow := _room_glow(room)
		for s in (shade_mats[room] as Array):
			(s["mat"] as StandardMaterial3D).emission_energy_multiplier = float(s["base"]) if glow else 0.0


func set_tv(on: bool) -> void:
	tv_on = on
	if tv_screen_mat:
		tv_screen_mat.emission_energy_multiplier = 1.6 if on else 0.02
	if tv_glow:
		tv_glow.visible = on and power


func set_market_mood(inside: bool) -> void:
	# FreshMart is aggressively, fluorescently bright. The house is not.
	if env == null:
		return
	if inside:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.85, 0.88, 0.9)
		env.ambient_light_energy = 1.15
		env.fog_enabled = false
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.35
		env.fog_enabled = true


func flash_lightning() -> void:
	# Double-strike: sky flashes, then thunder arrives late (story plays it).
	if env == null or moon == null:
		return
	moon.light_energy = 3.2
	moon.light_color = Color(0.8, 0.86, 1.0)
	env.ambient_light_energy = 1.8
	var t := create_tween()
	t.tween_interval(0.12)
	t.tween_callback(func(): moon.light_energy = 0.4)
	t.tween_interval(0.09)
	t.tween_callback(func(): moon.light_energy = 2.2)
	t.tween_interval(0.25)
	t.tween_property(moon, "light_energy", 0.25, 0.6)
	t.parallel().tween_property(env, "ambient_light_energy", 0.35, 0.6)
	t.tween_callback(func(): moon.light_color = Color(0.56, 0.66, 1.0))


func build() -> void:
	_build_env()
	var wall_in := TEX.mat_for("drywall", Color(0.72, 0.67, 0.56), 0.9)
	var wall_out := TEX.mat_for("concrete", Color(0.43, 0.42, 0.39), 0.95)
	var wood := TEX.mat_for("planks", Color(0.48, 0.36, 0.24), 0.7)
	var tile := TEX.mat_for("tile", Color(0.6, 0.63, 0.64), 0.4)
	var carpet := TEX.mat_for("carpet", Color(0.3, 0.27, 0.35), 1.0)
	var conc := TEX.mat_for("concrete", Color(0.36, 0.36, 0.38), 0.95)
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
	ceil_mi.material_override = TEX.mat_for("ceiling", Color(0.85, 0.82, 0.76), 0.95)
	# PlaneMesh faces +Y; flip it so the ceiling is visible from inside the rooms.
	ceil_mi.rotation.x = PI
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
	_fixtures()
	_window_dressing()
	_dressing()
	_baseboards()
	_build_clock()
	_light_rig()
	_outside()


func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	# Dusk sky: deep blue zenith bleeding to a dying orange horizon.
	# This is what windows and the open door frame (the F2F look).
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.025, 0.085)
	sky_mat.sky_horizon_color = Color(0.30, 0.13, 0.09)
	sky_mat.ground_bottom_color = Color(0.004, 0.004, 0.01)
	sky_mat.ground_horizon_color = Color(0.09, 0.06, 0.07)
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	# Filmic + bloom: lamps, TV and windows bleed like a camcorder at night.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.1
	env.glow_bloom = 0.15
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.028
	env.fog_light_color = Color(0.05, 0.07, 0.12)
	env.fog_sky_affect = 0.35
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
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
	_cyl(0.18, 0.3, 0.42, mat(Color(0.87, 0.82, 0.7), 0.9), Vector3(-7.3, 1.76, 4.9))
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
	box(0.12, 0.6, 0.45, mat(Color(0.23, 0.25, 0.27), 0.5, 0.4), Vector3(7.9, 1.55, -2.6))
	box(0.04, 0.4, 0.3, mat(Color(0.76, 0.07, 0.12), 0.5), Vector3(7.83, 1.55, -2.6))
	# LIVING — Martin's record shelf + turntable (he has TASTE).
	box(0.35, 0.06, 1.4, wood_d, Vector3(-7.7, 1.05, 2.5), 0.0, true)
	box(0.32, 0.1, 0.4, mat(Color(0.16, 0.15, 0.14), 0.5), Vector3(-7.7, 1.13, 2.15))
	var rec := MeshInstance3D.new()
	var recm := CylinderMesh.new()
	recm.top_radius = 0.15
	recm.bottom_radius = 0.15
	recm.height = 0.02
	rec.mesh = recm
	rec.material_override = mat(Color(0.05, 0.05, 0.06), 0.3)
	rec.position = Vector3(-7.7, 1.19, 2.15)
	add_child(rec)
	box(0.02, 0.32, 0.32, mat(Color(0.75, 0.6, 0.2), 0.6), Vector3(-7.82, 1.24, 2.75))
	box(0.02, 0.32, 0.32, mat(Color(0.2, 0.3, 0.55), 0.6), Vector3(-7.82, 1.24, 2.42))
	# GUEST — a faded tour poster somebody loved very much.
	var tour := Label3D.new()
	tour.text = "★ KING OF POP ★\nWORLD TOUR '88"
	tour.font_size = 72
	tour.modulate = Color(0.95, 0.75, 0.3)
	tour.position = Vector3(-6.1, 1.75, -5.36)
	tour.pixel_size = 0.004
	add_child(tour)


func _cyl(rt: float, rb: float, h: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _ball(r: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _shade(room: String, m: StandardMaterial3D, base: float) -> void:
	# Register an emissive fixture shade so _process can sync it with the
	# room's real lights (power cuts, switches AND flicker all show).
	if not shade_mats.has(room):
		shade_mats[room] = []
	(shade_mats[room] as Array).append({"mat": m, "base": base})


func _fan(c: Vector3, room: String, bulb_c: Color) -> void:
	var dark := mat(Color(0.16, 0.14, 0.12), 0.6)
	var blade := mat(Color(0.35, 0.26, 0.17), 0.7)
	_cyl(0.025, 0.025, 0.35, dark, Vector3(c.x, 2.62, c.z))
	_cyl(0.11, 0.11, 0.13, dark, Vector3(c.x, 2.42, c.z))
	var hub := Node3D.new()
	hub.position = Vector3(c.x, 2.34, c.z)
	add_child(hub)
	for i in 4:
		var a := float(i) * PI * 0.5
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.02, 0.13)
		mi.mesh = bm
		mi.material_override = blade
		mi.position = Vector3(cos(a) * 0.4, 0.0, sin(a) * 0.4)
		mi.rotation.y = -a
		hub.add_child(mi)
	fan_hubs.append(hub)
	_cyl(0.09, 0.05, 0.08, dark, Vector3(c.x, 2.3, c.z))
	var b := glow_mat(bulb_c, 2.0)
	_ball(0.05, b, Vector3(c.x, 2.24, c.z))
	_shade(room, b, 2.0)


func _pendant(c: Vector3, room: String, bulb_c: Color, trim: Material, drop: float) -> void:
	_cyl(0.06, 0.06, 0.05, trim, Vector3(c.x, 2.77, c.z))
	var y := 2.2 - drop
	var stem_h := 2.745 - (y + 0.09) + 0.05
	_cyl(0.015, 0.015, stem_h, trim, Vector3(c.x, (2.745 + y + 0.09) * 0.5, c.z))
	_cyl(0.06, 0.22, 0.18, trim, Vector3(c.x, y, c.z))
	var b := glow_mat(bulb_c, 2.2)
	_ball(0.06, b, Vector3(c.x, y - 0.08, c.z))
	_shade(room, b, 2.2)


func _flush(c: Vector3, room: String, bulb_c: Color, frost: Material) -> void:
	_cyl(0.17, 0.17, 0.03, frost, Vector3(c.x, 2.77, c.z))
	var d := glow_mat(bulb_c, 1.8)
	var dome := _ball(0.14, d, Vector3(c.x, 2.68, c.z))
	dome.scale.y = 0.7
	_shade(room, d, 1.8)


func _pullchain(c: Vector3, room: String, bulb_c: Color) -> void:
	var dark := mat(Color(0.12, 0.12, 0.14), 0.6)
	_cyl(0.008, 0.008, 0.45, dark, Vector3(c.x, 2.57, c.z))
	_cyl(0.025, 0.025, 0.07, dark, Vector3(c.x, 2.32, c.z))
	var b := glow_mat(bulb_c, 2.0)
	_ball(0.055, b, Vector3(c.x, 2.24, c.z))
	_shade(room, b, 2.0)
	_cyl(0.004, 0.004, 0.3, dark, Vector3(c.x + 0.06, 2.15, c.z))
	_ball(0.015, dark, Vector3(c.x + 0.06, 1.99, c.z))


func _fixtures() -> void:
	var mount := mat(Color(0.16, 0.14, 0.12), 0.6)
	var brass := mat(Color(0.55, 0.42, 0.2), 0.4, 0.6)
	var frost := mat(Color(0.88, 0.86, 0.78), 0.5)
	_fan(Vector3(-4, 0, 3), "living", Color(1.0, 0.85, 0.63))
	_fan(Vector3(1, 0, -3.5), "master", Color(1.0, 0.91, 0.77))
	_pendant(Vector3(4, 0, 3), "kitchen", Color(1.0, 0.95, 0.85), brass, 0.0)
	_pendant(Vector3(-4.5, 0, -3.5), "guest", Color(1.0, 0.85, 0.63), mount, 0.25)
	_flush(Vector3(0, 0, -0.5), "hall", Color(1.0, 0.91, 0.77), frost)
	_flush(Vector3(5.2, 0, -3.5), "bath", Color(0.84, 0.93, 1.0), frost)
	_pullchain(Vector3(7.2, 0, -3.5), "laundry", Color(1.0, 0.97, 0.85))
	# guest desk lamp (the accent light lives at its head)
	_cyl(0.08, 0.1, 0.04, mount, Vector3(-3.58, 0.77, -5.08))
	var arm := _cyl(0.015, 0.015, 0.55, mount, Vector3(-3.58, 1.0, -5.03))
	arm.rotation.x = 0.35
	_cyl(0.05, 0.12, 0.14, mount, Vector3(-3.58, 1.24, -4.93))
	var dl := glow_mat(Color(1.0, 0.9, 0.7), 1.6)
	_ball(0.045, dl, Vector3(-3.58, 1.2, -4.93))
	_shade("guest", dl, 1.6)
	# living floor-lamp bulb under the existing shade
	var fl := glow_mat(Color(1.0, 0.9, 0.64), 1.6)
	_ball(0.06, fl, Vector3(-7.3, 1.5, 4.9))
	_shade("living", fl, 1.6)


func _curtain(cx: float, z: float, rod_y: float, w: float, panels: Array, short: bool, c: Color) -> void:
	var rod_m := mat(Color(0.25, 0.18, 0.1), 0.5, 0.3)
	box(w + 0.9, 0.04, 0.04, rod_m, Vector3(cx, rod_y, z))
	_ball(0.035, rod_m, Vector3(cx - (w + 0.9) * 0.5, rod_y, z))
	_ball(0.035, rod_m, Vector3(cx + (w + 0.9) * 0.5, rod_y, z))
	var h := 1.2 if short else 1.7
	var y := 1.7 if short else 1.45
	var fm := mat(c, 1.0)
	for px in panels:
		box(0.42, h, 0.09, fm, Vector3(px, y, z))


func _blind_h(cx: float, z: float, w: float) -> void:
	var slat := mat(Color(0.78, 0.77, 0.72), 0.6)
	box(w, 0.7, 0.03, slat, Vector3(cx, 1.87, z))
	box(w + 0.02, 0.05, 0.05, slat, Vector3(cx, 1.5, z + 0.01))
	box(w + 0.15, 0.16, 0.1, mat(Color(0.6, 0.58, 0.52), 0.7), Vector3(cx, 2.3, z + 0.02))


func _blind_v(x: float, cz: float, w: float, s: float) -> void:
	var slat := mat(Color(0.78, 0.77, 0.72), 0.6)
	box(0.03, 1.2, w, slat, Vector3(x, 1.6, cz))
	box(0.05, 0.05, w + 0.02, slat, Vector3(x + s * 0.01, 0.98, cz))
	box(0.1, 0.16, w + 0.25, mat(Color(0.6, 0.58, 0.52), 0.7), Vector3(x + s * 0.04, 2.3, cz))


func _window_dressing() -> void:
	_curtain(-4.5, 5.32, 2.42, 1.9, [-5.7, -3.3], false, Color(0.45, 0.16, 0.14))
	_curtain(4.5, 5.32, 2.42, 1.9, [3.3, 5.7], false, Color(0.5, 0.44, 0.3))
	_curtain(-5.5, -5.32, 2.37, 1.5, [-6.5, -4.5], true, Color(0.2, 0.26, 0.4))
	_curtain(1.5, -5.32, 2.42, 1.5, [0.5, 2.5], true, Color(0.4, 0.3, 0.42))
	_blind_h(5.2, -5.37, 0.8)
	_blind_v(-7.97, 3.0, 1.6, 1.0)
	_blind_v(7.97, 3.0, 1.4, -1.0)


func _dressing() -> void:
	var white := mat(Color(0.85, 0.85, 0.85), 0.6)
	var steel := mat(Color(0.54, 0.56, 0.58), 0.35, 0.5)
	var cab := mat(Color(0.78, 0.74, 0.66), 0.6)
	var dark := mat(Color(0.16, 0.14, 0.12), 0.6)
	# kitchen uppers + kettle + paper towels
	box(0.35, 0.8, 1.2, cab, Vector3(7.72, 1.9, 2.6), 0.0, true)
	box(0.35, 0.8, 1.2, cab, Vector3(7.72, 1.9, 4.0), 0.0, true)
	_cyl(0.09, 0.11, 0.22, steel, Vector3(7.55, 1.09, 5.0))
	_cyl(0.06, 0.06, 0.28, white, Vector3(4.9, 1.1, 3.1))
	# bath: towel bar + towel, mat, shower rod + half-drawn curtain
	box(0.04, 0.04, 0.7, steel, Vector3(4.12, 1.3, -3.0))
	box(0.08, 0.55, 0.45, mat(Color(0.7, 0.4, 0.35), 1.0), Vector3(4.15, 1.0, -3.0))
	box(0.7, 0.02, 0.5, mat(Color(0.35, 0.45, 0.5), 1.0), Vector3(4.6, 0.02, -3.3))
	box(0.05, 0.05, 1.7, steel, Vector3(4.95, 2.0, -4.5))
	box(0.04, 1.5, 0.9, mat(Color(0.75, 0.73, 0.65), 0.9), Vector3(4.95, 1.2, -4.85))
	# laundry: basket, detergent, wall cabinet
	box(0.5, 0.4, 0.4, mat(Color(0.6, 0.5, 0.35), 0.9), Vector3(7.55, 0.2, -2.2), 0.0, true)
	box(0.12, 0.25, 0.12, mat(Color(0.85, 0.4, 0.15), 0.6), Vector3(6.85, 1.07, -5.1))
	box(0.12, 0.25, 0.12, mat(Color(0.2, 0.4, 0.8), 0.6), Vector3(7.6, 1.07, -4.9))
	box(0.9, 0.6, 0.35, cab, Vector3(7.2, 2.0, -5.2), 0.0, true)
	# hall: thermostat + family photos
	box(0.15, 0.2, 0.05, white, Vector3(-1.0, 1.5, 0.37))
	var photos := [Color(0.3, 0.4, 0.35), Color(0.4, 0.35, 0.3), Color(0.35, 0.3, 0.4)]
	for i in 3:
		var fx := 1.2 + float(i) * 0.5
		box(0.3, 0.4, 0.03, dark, Vector3(fx, 1.7, 0.385))
		box(0.24, 0.34, 0.035, mat(photos[i], 0.9), Vector3(fx, 1.7, 0.382))
	# living throw pillows
	box(0.35, 0.35, 0.15, mat(Color(0.6, 0.5, 0.3), 1.0), Vector3(-2.6, 0.75, 3.5), 0.3)
	box(0.35, 0.35, 0.15, mat(Color(0.3, 0.45, 0.4), 1.0), Vector3(-1.4, 0.75, 3.5), -0.2)
	# guest rug + master pillows + rug
	box(1.6, 0.02, 2.2, mat(Color(0.4, 0.3, 0.25), 1.0), Vector3(-5.0, 0.02, -3.0))
	box(0.7, 0.15, 0.45, white, Vector3(0.25, 0.78, -4.9))
	box(0.7, 0.15, 0.45, white, Vector3(0.95, 0.78, -4.9))
	box(2.0, 0.02, 1.4, mat(Color(0.35, 0.3, 0.4), 1.0), Vector3(0.6, 0.02, -2.6))


func _bb_h(z: float, x1: float, x2: float, gaps: Array) -> void:
	var m := mat(Color(0.8, 0.77, 0.7), 0.7)
	var edges := [x1]
	for g in gaps:
		edges.append(g[0])
		edges.append(g[1])
	edges.append(x2)
	for i in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i + 1]
		if b - a < 0.05:
			continue
		box(b - a, 0.12, 0.03, m, Vector3((a + b) * 0.5, 0.06, z))


func _bb_v(x: float, z1: float, z2: float, gaps: Array) -> void:
	var m := mat(Color(0.8, 0.77, 0.7), 0.7)
	var edges := [z1]
	for g in gaps:
		edges.append(g[0])
		edges.append(g[1])
	edges.append(z2)
	for i in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i + 1]
		if b - a < 0.05:
			continue
		box(0.03, 0.12, b - a, m, Vector3(x, 0.06, (a + b) * 0.5))


func _baseboards() -> void:
	_bb_h(5.385, X0, X1, [[-0.6, 0.6]])
	_bb_h(-5.385, X0, X1, [])
	_bb_v(-7.885, ZN, ZS, [])
	_bb_v(7.885, ZN, ZS, [])
	_bb_h(0.385, X0, X1, [[-5.35, -3.65], [3.65, 5.35]])
	_bb_h(0.615, X0, X1, [[-5.35, -3.65], [3.65, 5.35]])
	var backdoors := [[-6.0, -5.0], [1.0, 2.0], [4.75, 5.65], [6.825, 7.675]]
	_bb_h(-1.385, X0, X1, backdoors)
	_bb_h(-1.615, X0, X1, backdoors)
	_bb_v(-0.115, 0.5, ZS, [[1.95, 4.05]])
	_bb_v(0.115, 0.5, ZS, [[1.95, 4.05]])
	_bb_v(-2.115, ZN, -1.5, [])
	_bb_v(-1.885, ZN, -1.5, [])
	_bb_v(3.885, ZN, -1.5, [])
	_bb_v(4.115, ZN, -1.5, [])
	_bb_v(6.385, ZN, -1.5, [])
	_bb_v(6.615, ZN, -1.5, [])


func _house(pos: Vector3, size: Vector3, wins: Array) -> void:
	box(size.x, size.y, size.z, mat(Color(0.1, 0.1, 0.12), 1.0), Vector3(pos.x, size.y * 0.5, pos.z), 0.0, true)
	box(size.x + 0.6, 0.4, size.z + 0.6, mat(Color(0.05, 0.05, 0.07), 1.0), Vector3(pos.x, size.y + 0.2, pos.z))
	for w in wins:
		var p := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.3, 0.95)
		p.mesh = pm
		if bool(w["lit"]):
			p.material_override = glow_mat(w["tint"], 1.6)
		else:
			p.material_override = mat(Color(0.05, 0.07, 0.1), 0.2)
		p.position = w["pos"]
		p.rotation.y = float(w["ry"])
		add_child(p)


func _distant() -> void:
	var warm := Color(1.0, 0.83, 0.54)
	var cool := Color(0.56, 0.71, 1.0)
	_house(Vector3(-9, 0, 24), Vector3(6, 3.4, 5), [
		{"pos": Vector3(-10.2, 1.7, 21.49), "ry": PI, "lit": true, "tint": warm},
		{"pos": Vector3(-7.8, 1.7, 21.49), "ry": PI, "lit": true, "tint": cool},
	])
	_house(Vector3(3, 0, 25.5), Vector3(7, 3.4, 5.5), [
		{"pos": Vector3(1.5, 1.7, 22.74), "ry": PI, "lit": true, "tint": warm},
		{"pos": Vector3(4.5, 1.7, 22.74), "ry": PI, "lit": false, "tint": warm},
	])
	_house(Vector3(14, 0, 24), Vector3(6, 3.2, 5), [
		{"pos": Vector3(12.8, 1.7, 21.49), "ry": PI, "lit": false, "tint": warm},
		{"pos": Vector3(15.2, 1.7, 21.49), "ry": PI, "lit": false, "tint": warm},
	])
	_house(Vector3(24, 0, 6), Vector3(5, 3.2, 6), [
		{"pos": Vector3(21.49, 1.7, 6), "ry": -PI * 0.5, "lit": true, "tint": warm},
	])


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


func _build_clock() -> void:
	# Round wall clock; the second hand steps once per audible tick (story calls
	# clock_tick in sync with the sound) and freezes forever when the clock dies.
	var rim_mat := mat(Color(0.12, 0.1, 0.09), 0.6)
	var face_mat := mat(Color(0.82, 0.8, 0.72), 0.5)
	var hand_mat := mat(Color(0.08, 0.08, 0.08), 0.5)
	var rim := MeshInstance3D.new()
	var rcm := CylinderMesh.new()
	rcm.top_radius = 0.24
	rcm.bottom_radius = 0.24
	rcm.height = 0.06
	rim.mesh = rcm
	rim.material_override = rim_mat
	rim.rotation.x = PI * 0.5
	rim.position = CLOCK_POS
	add_child(rim)
	var face := MeshInstance3D.new()
	var fcm := CylinderMesh.new()
	fcm.top_radius = 0.2
	fcm.bottom_radius = 0.2
	fcm.height = 0.02
	face.mesh = fcm
	face.material_override = face_mat
	face.rotation.x = PI * 0.5
	face.position = CLOCK_POS + Vector3(0, 0, -0.025)
	add_child(face)
	for h in [{"len": 0.09, "wid": 0.03, "ang": 2.25}, {"len": 0.15, "wid": 0.02, "ang": -0.85}]:
		var hm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(float(h["wid"]), float(h["len"]), 0.008)
		hm.mesh = bm
		hm.material_override = hand_mat
		hm.position = CLOCK_POS + Vector3(0, 0, -0.04)
		hm.rotation.z = float(h["ang"])
		add_child(hm)
	clock_sec = Node3D.new()
	clock_sec.position = CLOCK_POS + Vector3(0, 0, -0.045)
	add_child(clock_sec)
	var sh := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(0.012, 0.17, 0.006)
	sh.mesh = sbm
	sh.material_override = mat(Color(0.6, 0.12, 0.1), 0.5)
	sh.position = Vector3(0, 0.06, 0)
	clock_sec.add_child(sh)


func clock_tick() -> void:
	if clock_sec == null:
		return
	clock_sec_a -= TAU / 60.0
	clock_sec.rotation.z = clock_sec_a


func spawn_glimpse(pos: Vector3, dur := 0.3) -> void:
	if glimpse != null and is_instance_valid(glimpse):
		glimpse.queue_free()
		glimpse = null
	var g := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 1.9, 0.32)
	g.mesh = bm
	g.material_override = mat(Color(0.0, 0.0, 0.0), 1.0)
	g.position = pos + Vector3(0, 0.95, 0)
	add_child(g)
	glimpse = g
	await get_tree().create_timer(dur, false).timeout
	if glimpse != null and is_instance_valid(glimpse):
		glimpse.queue_free()
		glimpse = null


func reset_dread_props() -> void:
	if not porch_on:
		porch_on = true
		apply_lights()
	clock_sec_a = 0.0
	if clock_sec != null:
		clock_sec.rotation.z = 0.0
	if glimpse != null and is_instance_valid(glimpse):
		glimpse.queue_free()
		glimpse = null


func _light_rig() -> void:
	_omni("living", Color(1.0, 0.85, 0.63), 2.2, 11.0, Vector3(-4, 2.3, 3))
	_omni("living", Color(1.0, 0.9, 0.64), 1.2, 6.0, Vector3(-7.3, 1.9, 4.9))
	_omni("kitchen", Color(1.0, 0.95, 0.85), 2.2, 11.0, Vector3(4, 2.4, 3))
	_omni("hall", Color(1.0, 0.91, 0.77), 1.8, 9.0, Vector3(0, 2.4, -0.5))
	_omni("guest", Color(1.0, 0.85, 0.63), 1.6, 7.0, Vector3(-4.5, 2.0, -3.5))
	_omni("guest", Color(0.81, 0.88, 1.0), 0.9, 4.0, Vector3(-3.58, 1.3, -4.93))
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
	gnd.material_override = TEX.mat_for("grass", Color(0.09, 0.11, 0.1), 1.0)
	gnd.position = Vector3(0, -0.02, 4)
	add_child(gnd)
	var path := MeshInstance3D.new()
	var phm := PlaneMesh.new()
	phm.size = Vector2(1.6, 8.5)
	path.mesh = phm
	path.material_override = TEX.mat_for("concrete", Color(0.27, 0.25, 0.22), 1.0)
	path.position = Vector3(0, 0.0, 9.5)
	add_child(path)
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(90, 3.4)
	road.mesh = rm
	road.material_override = TEX.mat_for("asphalt", Color(0.06, 0.06, 0.07), 1.0)
	road.position = Vector3(0, 0.0, 15)
	add_child(road)
	var deck := TEX.mat_for("deck", Color(0.38, 0.29, 0.22), 0.9)
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
	_distant()


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
	p.mesh = drop
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
		"market": "FRESHMART",
	}
	return names.get(r, r.to_upper())
