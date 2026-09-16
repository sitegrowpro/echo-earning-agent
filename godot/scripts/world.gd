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
	"garage": ["hall", "garage"],
}

var doors := {}
var door_seep := {} # id -> {"mat": StandardMaterial3D, "rooms": Array}
var _seep_sig := ""
var shade_mats := {}
var fan_hubs: Array[Node3D] = []
var art_props := {}
var clock_sec: Node3D
var clock_sec_a := 0.0
var glimpse: MeshInstance3D
var room_lights := {}
var power := true
var porch_on := true
var porch_light: OmniLight3D
var window_glows: Array = []
var window_slabs: Array = []
var _slabs_out := true
var tv_on := false
var tv_screen_mat: StandardMaterial3D
var tv_glow: OmniLight3D
var micro_light: OmniLight3D
var alert_light: OmniLight3D
var _alert_on := false
var cams: Array = []
var cam_labels: Array = []
var cam_vp: SubViewport
var cam_idx := 0
var street_spot: SpotLight3D
var _shadow_orig := {}
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
		var wgm := glow_mat(Color(1.0, 0.8, 0.55), 1.4)
		window_slabs.append(box(w - 0.25, h - 0.25, 0.02, wgm, Vector3(cx, cy, cz)))
		window_glows.append(wgm)
		box(0.05, h - 0.1, 0.05, fm, Vector3(cx, cy, cz))
		box(w + 0.1, 0.07, 0.3, mat(Color(0.42, 0.36, 0.27), 0.8), Vector3(cx, cy - h * 0.5, cz))
	else:
		box(0.03, h - 0.1, w - 0.1, g, Vector3(cx, cy, cz))
		box(0.05, 0.05, w - 0.1, fm, Vector3(cx, cy, cz))
		var wgm := glow_mat(Color(1.0, 0.8, 0.55), 1.4)
		window_slabs.append(box(0.02, h - 0.25, w - 0.25, wgm, Vector3(cx, cy, cz)))
		window_glows.append(wgm)
		box(0.05, h - 0.1, 0.05, fm, Vector3(cx, cy, cz))
		box(0.3, 0.07, w + 0.1, mat(Color(0.42, 0.36, 0.27), 0.8), Vector3(cx, cy - h * 0.5, cz))


func set_slabs_outside(out: bool) -> void:
	if out == _slabs_out:
		return
	_slabs_out = out
	for s in window_slabs:
		(s as Node3D).visible = out


func add_door(id: String, x: float, z: float, w: float, swing: float, opts: Dictionary) -> void:
	var d = Door.new()
	d.position = Vector3(x, 0, z)
	add_child(d)
	d.setup(id, w, swing, opts.get("open", false), opts.get("locked", false), opts.get("label", id), opts.get("color", Color(0.36, 0.27, 0.19)))
	d.set("base_ry", float(opts.get("ry", 0.0)))
	d.rotation.y = float(opts.get("ry", 0.0))
	doors[id] = d
	_add_seep(id, x, z, w, float(opts.get("ry", 0.0)))


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
	for gm in window_glows:
		(gm as StandardMaterial3D).emission_energy_multiplier = 1.4 if power else 0.0


# ---------- door light-seep (F2F hallway slivers) ----------
func _add_seep(id: String, x: float, z: float, w: float, ry := 0.0) -> void:
	if not DOOR_ROOMS.has(id):
		return
	var smat := glow_mat(Color(1.0, 0.8, 0.55), 0.0)
	# Thin emissive threshold strip; added to the WORLD (not the door: the door rotates).
	if absf(ry) > 0.01: # R5: seep runs along Z for X-wall doors (garage)
		box(0.1, 0.03, w - 0.06, smat, Vector3(x, 0.015, z - w * 0.5))
	else:
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
	if _alert_on and alert_light != null:
		alert_light.light_energy = 2.2 + 1.6 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012))
	if tv_on and tv_glow != null and tv_glow.visible:
		var ms := float(Time.get_ticks_msec())
		var n := sin(ms * 0.02) * 0.5 + sin(ms * 0.043 + 1.7) * 0.3 + sin(ms * 0.11 + 0.4) * 0.2
		tv_glow.light_energy = 1.2 + n * 0.55
		tv_screen_mat.emission_energy_multiplier = 1.6 + n * 0.6
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


func set_quality(high: bool) -> void:
	if env != null:
		env.glow_enabled = high
		(env as Environment).ssao_enabled = high
	if moon != null:
		if not _shadow_orig.has(moon):
			_shadow_orig[moon] = moon.shadow_enabled
		moon.shadow_enabled = high and bool(_shadow_orig[moon])
	if porch_light != null:
		if not _shadow_orig.has(porch_light):
			_shadow_orig[porch_light] = porch_light.shadow_enabled
		porch_light.shadow_enabled = high and bool(_shadow_orig[porch_light])
	if street_spot != null:
		if not _shadow_orig.has(street_spot):
			_shadow_orig[street_spot] = street_spot.shadow_enabled
		street_spot.shadow_enabled = high and bool(_shadow_orig[street_spot])
	for room in room_lights.keys():
		for l in ((room_lights[room] as Dictionary)["lights"] as Array):
			var lo := l as OmniLight3D
			if not _shadow_orig.has(lo):
				_shadow_orig[lo] = lo.shadow_enabled
			lo.shadow_enabled = high and bool(_shadow_orig[lo])


func set_alert(on: bool) -> void:
	if on == _alert_on:
		return
	_alert_on = on
	if alert_light != null:
		alert_light.visible = on


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
		env.ambient_light_energy = 0.4
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
	t.tween_property(moon, "light_energy", 0.5, 0.6)
	t.parallel().tween_property(env, "ambient_light_energy", 0.4, 0.6)
	t.tween_callback(func(): moon.light_color = Color(0.56, 0.66, 1.0))


func build() -> void:
	_build_env()
	var wall_in := TEX.mat_for("drywall", Color(0.72, 0.67, 0.56), 0.9)
	var wall_out := TEX.mat_for("stucco", Color(0.45, 0.43, 0.38), 0.95)
	var wood := TEX.mat_for("planks", Color(0.48, 0.36, 0.24), 0.7)
	var tile := TEX.mat_for("tile", Color(0.6, 0.63, 0.64), 0.4)
	var bathtile := TEX.mat_for("bathtile", Color(0.62, 0.68, 0.72), 0.35)
	var carpet := TEX.mat_for("carpet", Color(0.3, 0.27, 0.35), 1.0)
	var conc := TEX.mat_for("concrete", Color(0.36, 0.36, 0.38), 0.95)
	_floor(X0, 0.5, 0.0, ZS, wood)
	_floor(0.0, 0.5, X1, ZS, tile)
	_floor(X0, -1.5, X1, 0.5, wood)
	_floor(X0, ZN, -2.0, -1.5, carpet)
	_floor(-2.0, ZN, 4.0, -1.5, carpet)
	_floor(4.0, ZN, 6.5, -1.5, bathtile) # R5: the bath gets its own glaze
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
	run_v(X1, ZN, ZS, [{"at": 5.0, "w": 1.0, "kind": "door"}, {"at": 8.5, "w": 1.4, "y0": 0.95, "y1": 2.25, "kind": "window"}], wall_out) # R5: hall-east door into the new garage
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
	run_v(0.0, 0.5, 3.6, [{"at": 2.05, "w": 2.1, "y0": 0.0, "y1": 2.3, "kind": "arch"}], wall_in)
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
	add_door("garage", 8.0, 0.0, 0.94, -1.92, {"label": "Garage door", "ry": PI * 0.5}) # R5: pivot at the hole edge, swings into the garage
	_furnish()
	_fixtures()
	_window_dressing()
	_dressing()
	_dressing2()
	_furnish2()
	_baseboards()
	_liners()
	_garage()
	_backyard()
	_woods()
	_build_clock()
	_light_rig()
	_outside()
	_build_cams()


func _ground_collision() -> void:
	# One slab under the whole playable map (house, yard, street, neighbor).
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = Vector3(0, -0.25, -7.0) # R6: slab now spans z -39..25 (woods)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(64, 0.5, 64) # R6: stretched further north — the woods need ground too
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)


func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	# Dusk sky: deep blue zenith bleeding to a dying orange horizon.
	# This is what windows and the open door frame (the F2F look).
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.025, 0.085)
	sky_mat.sky_horizon_color = Color(0.05, 0.08, 0.15)
	sky_mat.ground_bottom_color = Color(0.004, 0.004, 0.01)
	sky_mat.ground_horizon_color = Color(0.02, 0.03, 0.06)
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	# Filmic + bloom: lamps, TV and windows bleed like a camcorder at night.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.1
	env.glow_bloom = 0.15
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.012
	env.fog_light_color = Color(0.09, 0.12, 0.20)
	env.fog_sky_affect = 0.35
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.56, 0.66, 1.0)
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-50, -30, 0)
	add_child(moon)
	_ground_collision()


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
	_poster(Vector3(-3.5, 1.7, -5.38), Color(0.14, 0.25, 0.42))
	_poster(Vector3(-2.9, 1.7, -5.38), Color(0.42, 0.14, 0.14))
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
	# R5: living-room rug + the framed family photo (the note finally has a face).
	_fabric_plane(Vector3(-4.0, 0.02, 3.0), "rug", 2.6, 3.4)
	_frame_x(Vector3(-7.88, 1.5, 0.95), "family", 0.5, 0.4)
	# GUEST — a faded tour poster somebody loved very much. (R5: real art,
	# correctly sized — the old 2.4 m text banner ran into the side wall.)
	_poster_art(Vector3(-6.85, 1.62, -5.375), "poster", 0.85, 1.1)
	var tour_cap: Label3D = Label3D.new()
	tour_cap.text = "WORLD TOUR '88"
	tour_cap.font_size = 48
	tour_cap.modulate = Color(0.95, 0.75, 0.3)
	tour_cap.position = Vector3(-6.85, 0.98, -5.375)
	tour_cap.pixel_size = 0.0025
	add_child(tour_cap)


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


func _liners() -> void:
	# R5: wallpaper + tile accent walls. Every liner sits 1 mm proud of its
	# face: readable as a surface, never coplanar, never z-fighting.
	var wp := TEX.mat_for("wallpaper", Color(0.82, 0.78, 0.68), 0.9)
	var bt := TEX.mat_for("bathtile", Color(0.7, 0.76, 0.8), 0.35)
	box(0.04, H, 3.7, wp, Vector3(-7.879, H * 0.5, -3.55)) # guest west wall (no holes here)
	box(0.04, H, 3.7, wp, Vector3(3.879, H * 0.5, -3.55)) # master east wall (no holes here)
	box(0.8, H, 0.04, bt, Vector3(4.4, H * 0.5, -5.379)) # bath north wall, left of window
	box(0.9, H, 0.04, bt, Vector3(6.05, H * 0.5, -5.379)) # bath north wall, right of window
	# Brick foundation skirt: hides the wall/ground seam on all four sides.
	var br := TEX.mat_for("brick", Color(0.5, 0.42, 0.36), 0.95)
	box(16.5, 0.55, 0.1, br, Vector3(0, 0.27, -5.56))
	box(16.5, 0.55, 0.1, br, Vector3(0, 0.27, 5.56))
	box(0.1, 0.55, 11.2, br, Vector3(-8.06, 0.27, 0))
	box(0.1, 0.55, 11.2, br, Vector3(8.06, 0.27, 0))
	# Furnace flue through the roof (the house HAS a furnace — see the thermostat chore).
	box(0.7, 2.2, 0.7, br, Vector3(5.5, 3.4, -3.0))
	box(0.9, 0.12, 0.9, mat(Color(0.15, 0.15, 0.16), 0.9), Vector3(5.5, 4.55, -3.0))


func _garage() -> void:
	# R5: attached garage, x 8..13, z -3.5..3.5. One real door (hall side),
	# one sectional door (dressed wall, never interactive), one window.
	var go := TEX.mat_for("stucco", Color(0.45, 0.43, 0.38), 0.95)
	var gf := TEX.mat_for("concrete", Color(0.4, 0.4, 0.42), 0.95)
	_floor(8.0, -3.5, 13.0, 3.5, gf)
	run_h(-3.5, 8.0, 13.0, [], go)
	run_h(3.5, 8.0, 13.0, [], go)
	run_v(13.0, -3.5, 3.5, [{"at": 3.5, "w": 1.2, "y0": 1.2, "y1": 2.2, "kind": "window"}], go)
	box(5.4, 0.15, 7.4, TEX.mat_for("ceiling", Color(0.55, 0.55, 0.53), 0.95), Vector3(10.5, H + 0.07, 0))
	box(5.6, 0.12, 7.6, mat(Color(0.07, 0.07, 0.08), 1.0), Vector3(10.5, H + 0.2, 0))
	box(3.0, 0.04, 10.0, gf, Vector3(10.5, 0.0, 8.5)) # driveway to the street
	# The Millers' sedan (decor car: parked, cold, never driven).
	var car := mat(Color(0.16, 0.2, 0.28), 0.35, 0.4)
	var glass := mat(Color(0.05, 0.07, 0.1), 0.08, 0.9)
	box(1.8, 0.55, 4.2, car, Vector3(10.5, 0.55, 0.2), 0.0, true)
	box(1.6, 0.5, 2.1, glass, Vector3(10.5, 1.05, -0.1))
	box(1.82, 0.18, 0.3, mat(Color(0.5, 0.5, 0.52), 0.5, 0.6), Vector3(10.5, 0.42, 2.35))
	box(1.82, 0.18, 0.3, mat(Color(0.5, 0.5, 0.52), 0.5, 0.6), Vector3(10.5, 0.42, -1.95))
	for wx in [9.75, 11.25]:
		for wz in [-1.2, 1.6]:
			var wh := _cyl(0.32, 0.32, 0.22, mat(Color(0.05, 0.05, 0.06), 0.9), Vector3(wx, 0.32, wz))
			wh.rotation.z = PI * 0.5
	# Workbench + clutter along the north wall.
	var wb := mat(Color(0.35, 0.26, 0.16), 0.8)
	box(2.4, 0.08, 0.7, wb, Vector3(9.6, 0.9, -3.05), 0.0, true)
	box(0.08, 0.9, 0.7, wb, Vector3(8.5, 0.45, -3.05), 0.0, true)
	box(0.08, 0.9, 0.7, wb, Vector3(10.7, 0.45, -3.05), 0.0, true)
	box(1.2, 0.9, 0.06, mat(Color(0.4, 0.3, 0.18), 0.9), Vector3(9.6, 1.7, -3.38))
	box(0.4, 0.3, 0.3, mat(Color(0.5, 0.32, 0.12), 0.8), Vector3(9.0, 1.09, -3.05))
	box(0.3, 0.22, 0.25, mat(Color(0.3, 0.35, 0.4), 0.8), Vector3(9.7, 1.05, -3.1))
	box(0.5, 0.5, 0.5, mat(Color(0.45, 0.36, 0.22), 0.9), Vector3(12.4, 0.25, -2.8), 0.0, true)
	box(0.45, 0.45, 0.45, mat(Color(0.42, 0.33, 0.2), 0.9), Vector3(12.35, 0.72, -2.75))
	box(0.6, 0.4, 0.4, mat(Color(0.2, 0.22, 0.25), 0.7), Vector3(12.4, 0.2, 2.9), 0.0, true)
	box(1.0, 0.012, 0.7, mat(Color(0.03, 0.03, 0.04), 0.3), Vector3(10.5, 0.012, 1.4)) # oil stain
	for i in 4: # sectional door dressing, both faces (never interactive)
		var sy := 0.5 + float(i) * 0.5
		box(3.2, 0.42, 0.06, mat(Color(0.55, 0.53, 0.48), 0.6), Vector3(10.5, sy, 3.38))
		box(3.2, 0.42, 0.06, mat(Color(0.5, 0.48, 0.44), 0.65), Vector3(10.5, sy, 3.62))
	box(0.3, 0.06, 0.08, mat(Color(0.2, 0.2, 0.2), 0.5, 0.5), Vector3(10.5, 1.0, 3.34))
	_pullchain(Vector3(10.5, 0, 0), "garage", Color(1.0, 0.93, 0.75))


func _backyard() -> void:
	# R5: fenced backyard, z -14..-5.5. Shed (his nest), dead tree, patio +
	# grill, string lights on the porch circuit. The EAST side stays open:
	# escape B runs around the garage, and no fence exists for the AI to hug.
	var fm := mat(Color(0.3, 0.24, 0.16), 0.9)
	for px in [-11.0, -8.5, -6.0, -3.5, -1.0, 1.5, 4.0, 6.5, 9.0, 11.5]:
		if px == 1.5: # R6: the broken gate — the woods are through here
			continue
		box(2.4, 1.8, 0.08, fm, Vector3(px, 0.9, -14.0), 0.0, true)
	box(0.14, 2.0, 0.14, fm, Vector3(0.3, 1.0, -14.0), 0.0, true)
	box(0.14, 2.0, 0.14, fm, Vector3(2.7, 1.0, -14.0), 0.0, true)
	var gate := box(2.2, 1.6, 0.06, fm, Vector3(1.5, 0.75, -14.35))
	gate.rotation.y = 0.5 # hanging open, dragging in the dirt
	for pz in [-13.0, -10.5, -8.0, -5.5, -3.0, -0.5, 2.0, 4.5]:
		box(0.08, 1.8, 2.4, fm, Vector3(-12.0, 0.9, pz), 0.0, true)
	for pz in [-13.0, -10.5, -8.0, -5.5]:
		box(0.08, 1.8, 2.4, fm, Vector3(13.0, 0.9, pz), 0.0, true)
	for px in [-12.0, -9.6, -7.2, -4.8, -2.4, 0.0, 2.4, 4.8, 7.2, 9.6, 12.0]:
		box(0.14, 2.0, 0.14, fm, Vector3(px, 1.0, -14.0))
	# Shed 2x2 in the NW corner, door facing south (z-constant wall, no ry needed).
	var sm := TEX.mat_for("planks", Color(0.32, 0.24, 0.15), 0.9)
	_floor(-10.0, -12.0, -8.0, -10.0, TEX.mat_for("concrete", Color(0.4, 0.4, 0.42), 0.95))
	box(2.0, 2.3, 0.12, sm, Vector3(-9.0, 1.15, -12.0), 0.0, true)
	box(0.12, 2.3, 2.0, sm, Vector3(-10.0, 1.15, -11.0), 0.0, true)
	box(0.12, 2.3, 2.0, sm, Vector3(-8.0, 1.15, -11.0), 0.0, true)
	box(0.5, 2.3, 0.12, sm, Vector3(-9.75, 1.15, -10.0), 0.0, true)
	box(0.5, 2.3, 0.12, sm, Vector3(-8.25, 1.15, -10.0), 0.0, true)
	box(1.1, 0.24, 0.12, sm, Vector3(-9.0, 2.18, -10.0))
	box(0.08, 2.1, 0.16, sm, Vector3(-9.54, 1.05, -10.0))
	box(0.08, 2.1, 0.16, sm, Vector3(-8.46, 1.05, -10.0))
	box(2.3, 0.1, 2.3, mat(Color(0.08, 0.08, 0.09), 1.0), Vector3(-9.0, 2.33, -11.0))
	add_door("shed", -9.5, -10.0, 0.9, 1.92, {"label": "Shed door"})
	var cm2 := mat(Color(0.42, 0.33, 0.2), 0.9)
	box(0.6, 0.6, 0.6, cm2, Vector3(-9.4, 0.3, -11.4), 0.0, true)
	box(0.16, 0.02, 0.22, mat(Color(0.82, 0.8, 0.72), 0.9), Vector3(-9.4, 0.62, -11.4))
	for cx in [-9.4, -9.0, -8.6]:
		box(0.3, 0.4, 0.015, mat(Color(0.75, 0.73, 0.65), 0.95), Vector3(cx, 1.5, -11.92))
	var lan: OmniLight3D = OmniLight3D.new()
	lan.light_color = Color(1.0, 0.75, 0.45)
	lan.light_energy = 0.7
	lan.omni_range = 4.0
	lan.position = Vector3(-9.0, 1.3, -11.0)
	add_child(lan)
	_ball(0.05, glow_mat(Color(1.0, 0.75, 0.45), 1.2), Vector3(-9.0, 1.3, -11.0))
	# Patio + grill + dead tree + bushes.
	box(4.0, 0.08, 3.0, TEX.mat_for("concrete", Color(0.45, 0.44, 0.4), 0.95), Vector3(1.5, 0.0, -7.5))
	_cyl(0.28, 0.24, 0.5, mat(Color(0.1, 0.1, 0.1), 0.6), Vector3(2.6, 0.55, -7.2))
	_cyl(0.3, 0.3, 0.12, mat(Color(0.08, 0.08, 0.08), 0.6), Vector3(2.6, 0.85, -7.2))
	for lx in [2.35, 2.85]:
		box(0.04, 0.5, 0.04, mat(Color(0.15, 0.15, 0.15), 0.7), Vector3(lx, 0.25, -7.2))
	box(0.04, 0.5, 0.04, mat(Color(0.15, 0.15, 0.15), 0.7), Vector3(2.6, 0.25, -7.45))
	_cyl(0.16, 0.22, 3.2, mat(Color(0.2, 0.15, 0.1), 0.95), Vector3(-5.5, 1.6, -11.0))
	for ba in [0.6, 2.2, 4.0]:
		var br := _cyl(0.05, 0.08, 1.6, mat(Color(0.2, 0.15, 0.1), 0.95), Vector3(-5.5, 2.9, -11.0))
		br.rotation.z = 0.7
		br.rotation.y = ba
	var shrub_m := TEX.mat_for("shrub", Color(0.55, 0.62, 0.55), 1.0) # R5b: real hedge
	_ball(0.7, shrub_m, Vector3(-2.5, 0.5, -12.5))
	_ball(0.55, shrub_m, Vector3(5.5, 0.4, -12.0))
	_ball(0.6, shrub_m, Vector3(-11.0, 0.45, -8.0))
	# R5b: the old family plot along the north fence — four leaning stones.
	var grave_m := TEX.mat_for("grave", Color(0.72, 0.72, 0.74), 0.95)
	var dirt_m := TEX.mat_for("gravedirt", Color(0.62, 0.57, 0.52), 1.0)
	box(1.6, 0.06, 1.0, dirt_m, Vector3(-4.5, 0.03, -13.0))
	for i in 4:
		var st := box(0.5, 0.9, 0.12, grave_m, Vector3(-7.6 + float(i) * 0.9, 0.42, -13.4), 0.0, true)
		st.rotation.z = 0.06 * float((i % 2) * 2 - 1)
		st.rotation.x = -0.05
	# String lights over the patio, wired to the porch switch.
	box(0.06, 2.6, 0.06, fm, Vector3(-0.3, 1.3, -7.5), 0.0, true)
	box(0.06, 2.6, 0.06, fm, Vector3(3.3, 1.3, -7.5), 0.0, true)
	box(3.6, 0.02, 0.02, mat(Color(0.05, 0.05, 0.05), 0.9), Vector3(1.5, 2.5, -7.5))
	for bx in [-0.1, 0.5, 1.1, 1.7, 2.3, 2.9]:
		_ball(0.035, glow_mat(Color(1.0, 0.8, 0.5), 1.4), Vector3(bx, 2.46, -7.5))
	var sl: OmniLight3D = OmniLight3D.new()
	sl.light_color = Color(1.0, 0.8, 0.55)
	sl.light_energy = 1.2
	sl.omni_range = 7.0
	sl.position = Vector3(1.5, 2.3, -7.5)
	add_child(sl)
	room_light("porch", sl)
	# Cool moonlight wash so the yard never goes pitch-void.
	var ml: OmniLight3D = OmniLight3D.new()
	ml.light_color = Color(0.35, 0.45, 0.7)
	ml.light_energy = 0.5
	ml.omni_range = 20.0
	ml.position = Vector3(0, 4.0, -10.0)
	add_child(ml)


func _pine(pos: Vector3, s: float, bark_m: Material, pine_m: Material) -> void:
	_cyl(0.14 * s, 0.2 * s, 3.2 * s, bark_m, pos + Vector3(0, 1.6 * s, 0))
	box(0.4 * s, 3.4 * s, 0.4 * s, bark_m, pos + Vector3(0, 1.7 * s, 0), 0.0, true)
	_cone(0.08 * s, 1.5 * s, 2.6 * s, Color(0.05, 0.10, 0.07), pos + Vector3(0, 3.6 * s, 0))
	_cone(0.06 * s, 1.1 * s, 2.0 * s, Color(0.04, 0.09, 0.06), pos + Vector3(0, 5.0 * s, 0))


func _woods() -> void:
	# R6: pine woods, x -13..14, z -14..-38. Same plane as the yard: the
	# enemy hunts here unmodified (raycast sight blocked by trunks, movement
	# slides around them). Player containment: trunk walls + hard blockers.
	var gnd := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(28, 25)
	gnd.mesh = gm
	gnd.material_override = TEX.mat_for("pinefloor", Color(0.5, 0.52, 0.45), 1.0)
	gnd.position = Vector3(0.5, -0.01, -26.0)
	add_child(gnd)
	# Trampled trail: gate (1.5,-14) winding to the clearing (-2,-30).
	var trail_m := TEX.mat_for("gravedirt", Color(0.55, 0.52, 0.47), 1.0)
	for t in [Vector3(1.2, 0.005, -16.5), Vector3(0.4, 0.005, -19.5), Vector3(-0.6, 0.005, -22.5), Vector3(-1.4, 0.005, -25.5), Vector3(-2.0, 0.005, -28.5)]:
		box(1.7, 0.03, 3.4, trail_m, t)
	var bark_m := TEX.mat_for("bark", Color(0.6, 0.58, 0.55), 1.0)
	var pine_m := mat(Color(0.05, 0.10, 0.07), 1.0)
	for tp in [[-6.0, -17.0], [5.0, -16.0], [-10.0, -19.0], [9.0, -20.0], [-3.0, -18.5], [2.4, -20.0], [-8.0, -24.0], [7.0, -25.0], [-5.5, -27.5], [4.5, -29.0], [-9.5, -31.0], [6.0, -32.5], [-1.0, -33.5], [-11.0, -27.0], [10.5, -28.0], [-7.5, -21.5], [3.5, -22.0]]:
		_pine(Vector3(tp[0], 0, tp[1]), 1.0, bark_m, pine_m)
	# Perimeter: a trunk wall the player cannot pass.
	for wx in range(-14, 16, 2):
		_pine(Vector3(float(wx), 0, -38.0), 1.2, bark_m, pine_m)
	for wz in range(-38, -13, 2):
		_pine(Vector3(-13.5, 0, float(wz)), 1.2, bark_m, pine_m)
	for wz2 in range(-38, -13, 2):
		_pine(Vector3(14.0, 0, float(wz2)), 1.2, bark_m, pine_m)
	blocker(-15.0, -40.0, 15.0, -38.5) # hard north stop behind the trunks
	blocker(-15.5, -40.0, -14.0, -13.0) # hard west stop
	blocker(14.5, -40.0, 16.0, -13.0) # hard east stop
	# The clearing: a stump, a shrine cross, and burnt-out candles.
	_cyl(0.32, 0.38, 0.5, bark_m, Vector3(-2.0, 0.25, -30.5))
	box(0.12, 1.1, 0.12, bark_m, Vector3(-3.2, 0.55, -31.5), 0.0, true)
	box(0.7, 0.12, 0.12, bark_m, Vector3(-3.2, 0.85, -31.5))
	for i in 3:
		var cx := -2.7 + float(i) * 0.22
		_cyl(0.03, 0.03, 0.12, mat(Color(0.75, 0.7, 0.6), 0.7), Vector3(cx, 0.06, -31.1))
		_ball(0.025, glow_mat(Color(1.0, 0.6, 0.25), 1.5), Vector3(cx, 0.15, -31.1))
	var ml2: OmniLight3D = OmniLight3D.new()
	ml2.light_color = Color(0.35, 0.45, 0.7)
	ml2.light_energy = 0.5
	ml2.omni_range = 18.0
	ml2.position = Vector3(0, 4.0, -28.0)
	add_child(ml2)


func _curtain(cx: float, z: float, rod_y: float, w: float, panels: Array, short: bool, c: Color) -> void:
	var rod_m := mat(Color(0.25, 0.18, 0.1), 0.5, 0.3)
	box(w + 0.9, 0.04, 0.04, rod_m, Vector3(cx, rod_y, z))
	_ball(0.035, rod_m, Vector3(cx - (w + 0.9) * 0.5, rod_y, z))
	_ball(0.035, rod_m, Vector3(cx + (w + 0.9) * 0.5, rod_y, z))
	var h := 1.2 if short else 1.7
	var y := 1.7 if short else 1.45
	var fm := TEX.mat_for("lace", c.lightened(0.55), 1.0) # R5: curtains get real lace
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


func _sheer(cx: float, z: float, w: float) -> void:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.88, 0.86, 0.8, 0.28)
	m.albedo_texture = TEX.art("curtainlace") # R5b: sheers get real lace (null-safe)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	box(w * 0.46, 1.35, 0.02, m, Vector3(cx - w * 0.26, 1.6, z))
	box(w * 0.46, 1.35, 0.02, m, Vector3(cx + w * 0.26, 1.6, z))


func _window_dressing() -> void:
	_sheer(-4.5, 5.38, 1.9)
	_sheer(4.5, 5.38, 1.9)
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


func _dressing2() -> void:
	# Second clutter pass: small lived-in props. All visual (no collide), tucked
	# against walls and on furniture, clear of door swings and walk lines.
	var white := mat(Color(0.85, 0.85, 0.85), 0.6)
	var dark := mat(Color(0.16, 0.14, 0.12), 0.6)
	var wood := mat(Color(0.31, 0.23, 0.15), 0.7)
	var steel := mat(Color(0.54, 0.56, 0.58), 0.35, 0.5)
	# ENTRY: shoes, umbrella stand, coat rail on the partition.
	box(0.13, 0.1, 0.3, dark, Vector3(0.85, 0.05, 5.05))
	box(0.13, 0.1, 0.3, dark, Vector3(1.02, 0.05, 5.12), 0.2)
	_cyl(0.11, 0.09, 0.45, mat(Color(0.2, 0.25, 0.35), 0.8), Vector3(1.35, 0.22, 5.1))
	_cyl(0.015, 0.015, 0.8, dark, Vector3(1.35, 0.6, 5.1))
	box(0.06, 0.08, 1.2, wood, Vector3(-0.14, 1.62, 2.4))
	box(0.14, 0.7, 0.32, mat(Color(0.25, 0.2, 0.28), 1.0), Vector3(-0.2, 1.2, 2.15))
	box(0.14, 0.6, 0.3, mat(Color(0.2, 0.3, 0.25), 1.0), Vector3(-0.2, 1.25, 2.7))
	# LIVING: book spines, throw blanket, side table + mug, floor cushion.
	var spines := [Color(0.55, 0.2, 0.2), Color(0.2, 0.35, 0.55), Color(0.55, 0.5, 0.2),
		Color(0.25, 0.5, 0.25), Color(0.5, 0.25, 0.5), Color(0.6, 0.4, 0.25)]
	for i in 6:
		var bh := 0.32 + float(i % 3) * 0.04
		box(0.06, bh, 0.16, mat(spines[i], 0.9), Vector3(-7.48, 1.35 + bh * 0.5, 1.85 + float(i) * 0.19))
	box(0.5, 0.06, 0.7, mat(Color(0.55, 0.35, 0.2), 1.0), Vector3(-1.0, 0.86, 3.3))
	box(0.5, 0.4, 0.06, mat(Color(0.55, 0.35, 0.2), 1.0), Vector3(-1.0, 0.65, 3.62))
	box(0.4, 0.45, 0.4, wood, Vector3(-0.5, 0.22, 3.75), 0.0, true)
	_cyl(0.045, 0.04, 0.11, mat(Color(0.2, 0.35, 0.5), 0.7), Vector3(-0.5, 0.5, 3.75))
	_cyl(0.22, 0.24, 0.12, mat(Color(0.4, 0.25, 0.2), 1.0), Vector3(-3.3, 0.06, 2.3))
	# Answering machine on the TV console (chapter 1 flavor + dread).
	box(0.22, 0.09, 0.16, mat(Color(0.12, 0.12, 0.14), 0.6), Vector3(-2.55, 0.46, 0.85))
	_ball(0.015, glow_mat(Color(1.0, 0.1, 0.1), 1.5), Vector3(-2.55, 0.51, 0.8))
	# KITCHEN: cereal, dish rack + plates, soap, towel, trash can, calendar.
	box(0.18, 0.28, 0.08, mat(Color(0.75, 0.5, 0.15), 0.8), Vector3(4.75, 1.1, 3.55))
	box(0.18, 0.26, 0.08, mat(Color(0.3, 0.5, 0.7), 0.8), Vector3(4.75, 1.09, 3.4), 0.15)
	box(0.4, 0.08, 0.3, mat(Color(0.7, 0.7, 0.7), 0.7), Vector3(7.5, 1.0, 3.9))
	for i in 3:
		box(0.03, 0.24, 0.24, white, Vector3(7.42 + float(i) * 0.08, 1.15, 3.9))
	_cyl(0.04, 0.045, 0.16, mat(Color(0.3, 0.6, 0.3), 0.6), Vector3(7.62, 1.04, 4.45))
	box(0.06, 0.04, 0.12, mat(Color(0.8, 0.7, 0.2), 0.8), Vector3(7.45, 0.98, 4.45))
	box(0.02, 0.35, 0.25, mat(Color(0.75, 0.3, 0.25), 1.0), Vector3(7.18, 0.55, 2.6))
	_cyl(0.16, 0.13, 0.42, steel, Vector3(7.5, 0.21, 5.15))
	box(0.015, 0.3, 0.24, white, Vector3(6.94, 1.25, 1.35))
	box(0.016, 0.06, 0.24, mat(Color(0.7, 0.15, 0.15), 0.7), Vector3(6.94, 1.37, 1.35))
	# HALL: north-wall frames, corner plant.
	box(0.4, 0.5, 0.03, dark, Vector3(-2.0, 1.7, -1.37))
	box(0.32, 0.42, 0.035, mat(Color(0.3, 0.35, 0.45), 0.9), Vector3(-2.0, 1.7, -1.368))
	box(0.4, 0.5, 0.03, dark, Vector3(3.4, 1.7, -1.37))
	box(0.32, 0.42, 0.035, mat(Color(0.45, 0.4, 0.3), 0.9), Vector3(3.4, 1.7, -1.368))
	_cyl(0.14, 0.11, 0.28, mat(Color(0.5, 0.28, 0.16), 0.8), Vector3(7.6, 0.14, -0.5))
	_ball(0.26, mat(Color(0.12, 0.25, 0.12), 1.0), Vector3(7.6, 0.5, -0.5))
	# GUEST: bedside books + clock + glass, laundry pile, backpack.
	box(0.3, 0.05, 0.22, mat(Color(0.25, 0.35, 0.5), 0.8), Vector3(-7.5, 0.58, -4.88))
	box(0.26, 0.04, 0.2, mat(Color(0.6, 0.3, 0.2), 0.8), Vector3(-7.5, 0.62, -4.88), 0.2)
	box(0.16, 0.08, 0.06, dark, Vector3(-7.32, 0.6, -5.22))
	_cyl(0.035, 0.03, 0.09, mat(Color(0.7, 0.75, 0.8, 0.5), 0.2), Vector3(-7.62, 0.6, -5.2))
	_ball(0.22, mat(Color(0.4, 0.45, 0.55), 1.0), Vector3(-7.5, 0.15, -2.0))
	_ball(0.18, mat(Color(0.55, 0.4, 0.35), 1.0), Vector3(-7.35, 0.32, -2.1))
	box(0.35, 0.45, 0.25, mat(Color(0.45, 0.15, 0.15), 0.9), Vector3(-3.7, 0.22, -4.5))
	# BATH: toothbrush cup + brushes, soap, hamper.
	_cyl(0.05, 0.04, 0.1, mat(Color(0.3, 0.5, 0.6), 0.6), Vector3(5.05, 0.86, -2.0))
	_cyl(0.008, 0.008, 0.16, white, Vector3(5.03, 0.96, -2.0))
	_cyl(0.008, 0.008, 0.16, mat(Color(0.3, 0.5, 0.8), 0.6), Vector3(5.07, 0.96, -2.0))
	box(0.1, 0.03, 0.07, mat(Color(0.85, 0.8, 0.7), 0.6), Vector3(5.35, 0.82, -2.0))
	_cyl(0.2, 0.17, 0.55, mat(Color(0.6, 0.55, 0.45), 0.9), Vector3(6.1, 0.27, -2.2))
	# LAUNDRY: folded towels on the washer.
	box(0.4, 0.08, 0.35, white, Vector3(6.95, 0.99, -5.0))
	box(0.36, 0.07, 0.32, mat(Color(0.4, 0.55, 0.7), 1.0), Vector3(6.95, 1.06, -5.0))
	# PORCH: boots by the door, hanging plant.
	box(0.14, 0.22, 0.3, mat(Color(0.2, 0.15, 0.1), 0.9), Vector3(-0.95, 0.29, 5.95))
	box(0.14, 0.22, 0.3, mat(Color(0.2, 0.15, 0.1), 0.9), Vector3(-0.78, 0.29, 6.0), -0.15)
	_cyl(0.12, 0.09, 0.18, mat(Color(0.5, 0.28, 0.16), 0.8), Vector3(2.3, 2.55, 7.9))
	_ball(0.2, mat(Color(0.12, 0.25, 0.12), 1.0), Vector3(2.3, 2.35, 7.9))
	# STREET: trash bags by the curb, manhole.
	_ball(0.3, mat(Color(0.08, 0.1, 0.08), 0.9), Vector3(-8.5, 0.25, 12.3))
	_ball(0.26, mat(Color(0.08, 0.1, 0.08), 0.9), Vector3(-8.0, 0.22, 12.5))
	_cyl(0.35, 0.35, 0.012, mat(Color(0.08, 0.08, 0.1), 0.6), Vector3(2.0, 0.045, 15.5))


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


func set_prop_visible(id: String, on: bool) -> void:
	if art_props.has(id):
		(art_props[id] as Node3D).visible = on


func _switchplate(pos: Vector3, nz: float) -> void:
	box(0.09, 0.14, 0.025, mat(Color(0.85, 0.83, 0.76), 0.6), pos)
	box(0.03, 0.05, 0.03, mat(Color(0.72, 0.7, 0.64), 0.6), pos + Vector3(0, 0, nz * 0.022))


func _furnish2() -> void:
	var wood := mat(Color(0.31, 0.23, 0.15), 0.7)
	var wood_l := mat(Color(0.45, 0.34, 0.22), 0.7)
	var dark := mat(Color(0.16, 0.14, 0.12), 0.6)
	var steel := mat(Color(0.54, 0.56, 0.58), 0.35, 0.5)
	var white := mat(Color(0.85, 0.85, 0.85), 0.6)
	var cream := mat(Color(0.87, 0.82, 0.7), 0.9)
	var brass := mat(Color(0.55, 0.42, 0.2), 0.4, 0.6)
	# ---- light switch plates (triple gang by the front door + one per room) ----
	_switchplate(Vector3(0.65, 1.35, 5.37), -1.0)
	_switchplate(Vector3(0.78, 1.35, 5.37), -1.0)
	_switchplate(Vector3(0.91, 1.35, 5.37), -1.0)
	_switchplate(Vector3(-4.9, 1.35, 0.37), -1.0)
	_switchplate(Vector3(-4.85, 1.35, -1.37), 1.0)
	_switchplate(Vector3(2.1, 1.35, -1.37), 1.0)
	_switchplate(Vector3(4.6, 1.35, -1.37), 1.0)
	_switchplate(Vector3(6.67, 1.35, -1.37), 1.0)
	# ---- porch: mat + key, chair, table, dead plant ----
	box(1.1, 0.04, 0.65, mat(Color(0.4, 0.2, 0.16), 1.0), Vector3(0, 0.2, 6.15))
	box(0.14, 0.02, 0.05, brass, Vector3(0.35, 0.21, 6.32))
	box(0.55, 0.07, 0.5, wood, Vector3(-2.4, 0.45, 7.2), 0.0, true)
	box(0.55, 0.65, 0.07, wood, Vector3(-2.4, 0.8, 7.42))
	for lx in [-0.22, 0.22]:
		for lz in [-0.19, 0.19]:
			box(0.06, 0.45, 0.06, wood, Vector3(-2.4 + lx, 0.22, 7.2 + lz))
	box(0.42, 0.42, 0.42, wood, Vector3(-1.55, 0.21, 7.35), 0.0, true)
	_cyl(0.045, 0.04, 0.11, mat(Color(0.5, 0.2, 0.15), 0.7), Vector3(-1.55, 0.47, 7.35))
	_cyl(0.14, 0.11, 0.26, mat(Color(0.5, 0.28, 0.16), 0.8), Vector3(-2.9, 0.31, 5.9))
	_ball(0.2, mat(Color(0.35, 0.28, 0.12), 1.0), Vector3(-2.9, 0.6, 5.9))
	# ---- mailbox + mail prop, trash bin ----
	box(0.12, 1.05, 0.12, wood, Vector3(2.2, 0.52, 9.0), 0.0, true)
	box(0.28, 0.22, 0.55, mat(Color(0.16, 0.25, 0.18), 0.6), Vector3(2.2, 1.15, 9.0))
	box(0.03, 0.25, 0.05, mat(Color(0.7, 0.12, 0.12), 0.6), Vector3(2.36, 1.3, 8.85))
	art_props["mailpapers"] = box(0.2, 0.06, 0.3, white, Vector3(2.2, 1.29, 9.0))
	box(0.6, 0.9, 0.6, mat(Color(0.13, 0.22, 0.14), 0.7), Vector3(-2.6, 0.45, 6.3), 0.0, true)
	box(0.66, 0.08, 0.66, dark, Vector3(-2.6, 0.94, 6.3))
	# ---- fences, path, road, sidewalk ----
	var fence_m := mat(Color(0.26, 0.2, 0.14), 0.85)
	for sx in [-9.0, 9.0]:
		box(0.08, 0.1, 18.0, fence_m, Vector3(sx, 0.55, 7.0), 0.0, true)
		box(0.08, 0.1, 18.0, fence_m, Vector3(sx, 0.95, 7.0))
		var fz := -2.0
		while fz <= 16.0:
			box(0.12, 1.1, 0.12, fence_m, Vector3(sx, 0.55, fz))
			fz += 2.5
	for fx in [-5.1, 5.1]:
		box(7.8, 0.1, 0.08, fence_m, Vector3(fx, 0.55, 11.0), 0.0, true)
		box(7.8, 0.1, 0.08, fence_m, Vector3(fx, 0.95, 11.0))
	var conc := TEX.mat_for("concrete", Color(0.5, 0.5, 0.5), 0.95)
	for i in 3:
		box(1.3, 0.07, 0.9, conc, Vector3(0, 0.035, 9.2 + float(i) * 0.8))
	box(60.0, 0.04, 7.0, TEX.mat_for("asphalt", Color(0.35, 0.35, 0.38), 0.95), Vector3(0, 0.02, 16.5))
	box(60.0, 0.12, 0.25, conc, Vector3(0, 0.06, 12.9))
	box(60.0, 0.12, 0.25, conc, Vector3(0, 0.06, 20.1))
	box(60.0, 0.06, 1.6, TEX.mat_for("concrete", Color(0.55, 0.55, 0.55), 0.95), Vector3(0, 0.03, 11.9))
	# ---- the Millers' sedan ----
	var car_m := mat(Color(0.12, 0.18, 0.35), 0.4, 0.4)
	box(4.3, 0.62, 1.85, car_m, Vector3(-5.5, 0.62, 15.8), 0.0, true)
	box(2.3, 0.55, 1.65, mat(Color(0.05, 0.07, 0.1), 0.2), Vector3(-5.8, 1.2, 15.8))
	var tire := mat(Color(0.05, 0.05, 0.06), 0.9)
	for wx in [-6.9, -4.1]:
		for wz in [14.95, 16.65]:
			var wh := _cyl(0.33, 0.33, 0.25, tire, Vector3(wx, 0.33, wz))
			wh.rotation.x = PI * 0.5
	box(0.06, 0.18, 0.35, mat(Color(0.75, 0.78, 0.7), 0.3), Vector3(-3.34, 0.65, 15.25))
	box(0.06, 0.18, 0.35, mat(Color(0.75, 0.78, 0.7), 0.3), Vector3(-3.34, 0.65, 16.35))
	box(0.06, 0.15, 0.3, mat(Color(0.4, 0.08, 0.08), 0.4), Vector3(-7.66, 0.65, 15.25))
	box(0.06, 0.15, 0.3, mat(Color(0.4, 0.08, 0.08), 0.4), Vector3(-7.66, 0.65, 16.35))
	# ---- trees, bushes, hydrant, second lamp, moon, stars ----
	var bark := mat(Color(0.2, 0.15, 0.1), 0.9)
	var leaf := mat(Color(0.08, 0.14, 0.08), 1.0)
	for tp in [Vector3(-12, 0, 4), Vector3(11, 0, -3), Vector3(-10, 0, 15)]:
		_cyl(0.16, 0.24, 2.6, bark, tp + Vector3(0, 1.3, 0))
		_ball(1.3, leaf, tp + Vector3(0, 3.0, 0))
		_ball(1.1, leaf, tp + Vector3(0.6, 3.7, 0.3))
		_ball(0.9, leaf, tp + Vector3(-0.5, 4.3, -0.2))
	for bp in [Vector3(-6.5, 0.4, 6.0), Vector3(-5.5, 0.4, 6.0), Vector3(5.5, 0.4, 6.0), Vector3(6.5, 0.4, 6.0), Vector3(-3.6, 0.4, 7.0), Vector3(3.6, 0.4, 7.0)]:
		_ball(0.5, leaf, bp)
	_cyl(0.12, 0.14, 0.5, mat(Color(0.7, 0.6, 0.1), 0.6), Vector3(8.5, 0.3, 13.5))
	_ball(0.12, mat(Color(0.7, 0.6, 0.1), 0.6), Vector3(8.5, 0.6, 13.5))
	_cyl(0.07, 0.09, 5.2, dark, Vector3(-14, 2.6, 14))
	_ball(0.14, glow_mat(Color(1.0, 0.91, 0.64), 2.0), Vector3(-14, 5.2, 14))
	_ball(1.8, glow_mat(Color(0.9, 0.93, 1.0), 1.2), Vector3(28, 32, -25))
	var starm := glow_mat(Color(0.8, 0.85, 1.0), 1.0)
	for i in 26:
		var sa := float(i) * 2.4
		var sr := 30.0 + float(i % 5) * 4.0
		_ball(0.12, starm, Vector3(cos(sa) * sr, 24.0 + float(i % 7), sin(sa) * sr - 5.0))
	# ---- neighbor: somebody might be home ----
	_ball(0.08, glow_mat(Color(1.0, 0.83, 0.54), 2.0), Vector3(-13.4, 2.4, 10.0))
	var np := MeshInstance3D.new()
	var npm := PlaneMesh.new()
	npm.size = Vector2(1.3, 0.95)
	np.mesh = npm
	np.material_override = glow_mat(Color(1.0, 0.83, 0.54), 1.6)
	np.position = Vector3(-13.44, 1.7, 10.0)
	np.rotation.y = PI * 0.5
	add_child(np)
	# ---- living: coffee-table life, books, plant, frames ----
	_cyl(0.045, 0.04, 0.11, mat(Color(0.5, 0.2, 0.15), 0.7), Vector3(-2.35, 0.46, 2.0))
	box(0.07, 0.03, 0.2, dark, Vector3(-1.8, 0.42, 2.25), 0.4)
	box(0.32, 0.07, 0.42, cream, Vector3(-2.1, 0.44, 1.9), -0.15)
	box(0.3, 0.1, 0.24, mat(Color(0.6, 0.15, 0.12), 0.8), Vector3(-1.0, 0.89, 3.55))
	box(0.26, 0.08, 0.2, mat(Color(0.15, 0.25, 0.5), 0.8), Vector3(-1.0, 0.98, 3.55), 0.3)
	_cyl(0.16, 0.12, 0.32, mat(Color(0.5, 0.28, 0.16), 0.8), Vector3(-7.5, 0.16, 0.9))
	_ball(0.28, mat(Color(0.12, 0.25, 0.12), 1.0), Vector3(-7.5, 0.6, 0.9))
	_ball(0.24, mat(Color(0.12, 0.25, 0.12), 1.0), Vector3(-7.4, 0.85, 0.8))
	_ball(0.2, mat(Color(0.12, 0.25, 0.12), 1.0), Vector3(-7.55, 1.05, 0.95))
	box(0.04, 0.55, 0.45, dark, Vector3(-7.86, 1.7, 1.0))
	box(0.045, 0.45, 0.35, mat(Color(0.3, 0.4, 0.35), 0.9), Vector3(-7.86, 1.7, 1.0))
	box(0.04, 0.55, 0.45, dark, Vector3(-7.86, 1.7, 4.3))
	box(0.045, 0.45, 0.35, mat(Color(0.4, 0.35, 0.3), 0.9), Vector3(-7.86, 1.7, 4.3))
	# ---- kitchen: sink, stove, magnets, fruit, trash prop ----
	box(0.5, 0.1, 0.65, steel, Vector3(7.5, 0.97, 4.2))
	_cyl(0.025, 0.025, 0.28, steel, Vector3(7.68, 1.1, 4.2))
	box(0.22, 0.04, 0.05, steel, Vector3(7.58, 1.23, 4.2))
	box(0.55, 0.03, 0.7, dark, Vector3(7.55, 0.98, 2.6))
	for bx in [7.45, 7.65]:
		for bz in [2.42, 2.78]:
			_cyl(0.09, 0.09, 0.02, mat(Color(0.05, 0.05, 0.06), 0.6), Vector3(bx, 1.0, bz))
	for kz in [2.4, 2.6, 2.8]:
		box(0.03, 0.05, 0.05, white, Vector3(7.19, 0.75, kz))
	box(0.02, 0.07, 0.06, mat(Color(0.7, 0.1, 0.1), 0.6), Vector3(6.94, 1.25, 0.85))
	box(0.02, 0.07, 0.06, mat(Color(0.1, 0.3, 0.7), 0.6), Vector3(6.94, 1.4, 1.0))
	box(0.02, 0.07, 0.06, mat(Color(0.1, 0.6, 0.2), 0.6), Vector3(6.94, 1.5, 1.15))
	box(0.015, 0.28, 0.22, white, Vector3(6.94, 1.6, 1.0))
	_cyl(0.17, 0.1, 0.09, wood, Vector3(4.2, 1.0, 3.0))
	_ball(0.06, mat(Color(0.85, 0.45, 0.1), 0.7), Vector3(4.13, 1.08, 2.97))
	_ball(0.06, mat(Color(0.7, 0.1, 0.1), 0.7), Vector3(4.27, 1.08, 3.03))
	_ball(0.06, mat(Color(0.4, 0.65, 0.15), 0.7), Vector3(4.2, 1.08, 2.93))
	art_props["trashbag"] = box(0.45, 0.55, 0.45, mat(Color(0.08, 0.1, 0.08), 0.9), Vector3(4.9, 0.28, 2.6), 0.0, true)
	# ---- hall: vase on the console ----
	_cyl(0.07, 0.1, 0.28, mat(Color(0.2, 0.4, 0.4), 0.6), Vector3(-3.8, 0.94, -1.25))
	_ball(0.07, mat(Color(0.15, 0.35, 0.15), 1.0), Vector3(-3.8, 1.15, -1.25))
	# ---- guest: bedside lamp, closet doors ----
	_cyl(0.09, 0.11, 0.05, dark, Vector3(-7.5, 0.58, -5.1))
	_cyl(0.02, 0.02, 0.3, dark, Vector3(-7.5, 0.75, -5.1))
	_cyl(0.14, 0.17, 0.2, cream, Vector3(-7.5, 0.95, -5.1))
	var gl := glow_mat(Color(1.0, 0.9, 0.7), 1.6)
	_ball(0.05, gl, Vector3(-7.5, 0.93, -5.1))
	_shade("guest", gl, 1.6)
	box(0.62, 1.86, 0.04, wood_l, Vector3(-3.02, 0.98, -1.68))
	box(0.62, 1.86, 0.04, wood_l, Vector3(-2.38, 0.98, -1.68))
	_ball(0.03, brass, Vector3(-2.78, 1.0, -1.64))
	_ball(0.03, brass, Vector3(-2.62, 1.0, -1.64))
	# ---- master: closet doors, mirror, car-key prop ----
	box(0.62, 1.86, 0.04, wood_l, Vector3(2.88, 0.98, -1.68))
	box(0.62, 1.86, 0.04, wood_l, Vector3(3.52, 0.98, -1.68))
	_ball(0.03, brass, Vector3(3.12, 1.0, -1.64))
	_ball(0.03, brass, Vector3(3.28, 1.0, -1.64))
	box(0.04, 1.1, 0.7, mat(Color(0.1, 0.13, 0.16), 0.05, 0.9), Vector3(-1.86, 1.6, -3.5))
	art_props["carkeys"] = box(0.13, 0.02, 0.06, brass, Vector3(3.3, 0.86, -5.1)) # R5: seated on the dresser
	# ---- bath: vanity bar, shelf + bottles, TP ----
	var vb := glow_mat(Color(0.9, 0.95, 1.0), 1.4)
	box(0.5, 0.08, 0.1, vb, Vector3(5.2, 2.15, -1.62))
	_shade("bath", vb, 1.4)
	box(0.25, 0.04, 0.7, white, Vector3(6.28, 1.5, -3.0))
	_cyl(0.035, 0.035, 0.14, mat(Color(0.2, 0.5, 0.7), 0.6), Vector3(6.28, 1.59, -3.2))
	_cyl(0.035, 0.035, 0.14, mat(Color(0.7, 0.4, 0.2), 0.6), Vector3(6.28, 1.59, -3.0))
	_cyl(0.035, 0.035, 0.14, mat(Color(0.5, 0.2, 0.5), 0.6), Vector3(6.28, 1.59, -2.8))
	_cyl(0.06, 0.06, 0.11, white, Vector3(5.5, 0.51, -4.9))
	# ---- laundry: flashlight shelf + prop, shelf, detergent ----
	box(0.4, 0.05, 0.5, wood, Vector3(6.8, 1.2, -3.6))
	box(0.05, 0.05, 0.2, dark, Vector3(6.8, 1.26, -3.62))
	art_props["flashprop"] = box(0.07, 0.07, 0.08, steel, Vector3(6.8, 1.26, -3.48))
	box(1.4, 0.05, 0.35, wood, Vector3(7.27, 1.55, -5.25))
	box(0.22, 0.3, 0.16, mat(Color(0.85, 0.4, 0.15), 0.6), Vector3(7.85, 1.72, -5.25))


func _poster(pos: Vector3, c: Color) -> void:
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.7, 0.95)
	p.mesh = pm
	p.material_override = mat(c, 0.9)
	p.position = pos
	add_child(p)


func _poster_art(pos: Vector3, art: String, w: float, h: float) -> void:
	# R5: real poster art with a frame (falls back to a flat poster if missing).
	var img := TEX.art(art)
	if img == null:
		_poster(pos, Color(0.2, 0.2, 0.25))
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = img
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.roughness = 0.85
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, h)
	p.mesh = pm
	p.material_override = m
	p.position = pos
	add_child(p)
	var fm := mat(Color(0.1, 0.08, 0.06), 0.6)
	box(w + 0.06, 0.04, 0.03, fm, pos + Vector3(0, h * 0.5 + 0.02, -0.005))
	box(w + 0.06, 0.04, 0.03, fm, pos + Vector3(0, -h * 0.5 - 0.02, -0.005))
	box(0.04, h + 0.06, 0.03, fm, pos + Vector3(w * 0.5 + 0.02, 0, -0.005))
	box(0.04, h + 0.06, 0.03, fm, pos + Vector3(-w * 0.5 - 0.02, 0, -0.005))


func _fabric_plane(pos: Vector3, art: String, w: float, d: float) -> void:
	# R5: horizontal art plane (rugs). PlaneMesh faces +Y: zero extra work.
	var img := TEX.art(art)
	if img == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = img
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.roughness = 0.95
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	p.mesh = pm
	p.material_override = m
	p.position = pos
	add_child(p)


func _frame_x(pos: Vector3, art: String, w: float, h: float) -> void:
	# R5: framed art facing +X (west-wall frames). Width runs along Z.
	var img := TEX.art(art)
	if img == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = img
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.roughness = 0.7
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, h)
	p.mesh = pm
	p.material_override = m
	p.position = pos
	p.rotation.y = PI * 0.5
	add_child(p)
	var fm := mat(Color(0.12, 0.09, 0.06), 0.6)
	box(0.03, h + 0.06, 0.04, fm, pos + Vector3(-0.005, 0, w * 0.5 + 0.02))
	box(0.03, h + 0.06, 0.04, fm, pos + Vector3(-0.005, 0, -w * 0.5 - 0.02))


func _omni(room: String, color: Color, energy: float, dist: float, pos: Vector3, shadow := false) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = dist
	l.shadow_enabled = shadow
	l.position = pos
	add_child(l)
	room_light(room, l)


func _cone(top_r: float, bot_r: float, h: float, c: Color, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	add_child(mi)


func _shaft(w: float, y: float, z: float, tilt: float, cx: float) -> void:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.56, 0.66, 1.0, 0.10)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sh := box(w, 0.05, 2.6, m, Vector3(cx, y, z))
	sh.rotation.x = tilt
	var pm := StandardMaterial3D.new()
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = Color(0.5, 0.62, 1.0, 0.14)
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(w * 0.85, 0.012, 1.5, pm, Vector3(cx, 0.025, z - 1.05))


func _dust(center: Vector3, extents: Vector3, n: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0, -1, 0)
	p.spread = 20.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.08
	p.gravity = Vector3.ZERO
	var dot := SphereMesh.new()
	dot.radius = 0.008
	dot.height = 0.016
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1.0, 0.95, 0.85, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dot.material = dm
	p.mesh = dot
	p.position = center
	add_child(p)


func _puddle(x: float, z: float, w: float, d: float) -> void:
	var f := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	f.mesh = pm
	f.material_override = mat(Color(0.04, 0.06, 0.11), 0.05, 0.7)
	f.position = Vector3(x, 0.012, z)
	add_child(f)


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
	set_alert(false)
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
	_omni("living", Color(1.0, 0.85, 0.63), 2.2, 11.0, Vector3(-4, 2.1, 3))
	_omni("living", Color(1.0, 0.9, 0.64), 1.0, 6.0, Vector3(-7.3, 1.9, 4.9))
	_omni("kitchen", Color(1.0, 0.95, 0.85), 1.8, 11.0, Vector3(4, 2.4, 3), true)
	_omni("hall", Color(1.0, 0.91, 0.77), 1.5, 9.0, Vector3(0, 2.4, -0.5), true)
	_omni("guest", Color(1.0, 0.85, 0.63), 1.35, 7.0, Vector3(-4.5, 2.0, -3.5))
	_omni("guest", Color(0.81, 0.88, 1.0), 0.9, 4.0, Vector3(-3.58, 1.3, -4.93))
	_omni("master", Color(1.0, 0.91, 0.77), 1.5, 9.0, Vector3(1, 2.4, -3.5))
	_omni("bath", Color(0.84, 0.93, 1.0), 1.1, 6.0, Vector3(5.2, 2.3, -3.5))
	_omni("laundry", Color(1.0, 0.97, 0.85), 1.5, 7.0, Vector3(7.2, 2.3, -3.5))
	porch_light = OmniLight3D.new()
	porch_light.light_color = Color(1.0, 0.85, 0.63)
	porch_light.light_energy = 2.5
	porch_light.omni_range = 10.0
	porch_light.shadow_enabled = true
	porch_light.position = Vector3(1.3, 2.75, 6.5)
	add_child(porch_light)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	bulb.mesh = sm
	bulb.material_override = glow_mat(Color(1.0, 0.83, 0.54), 2.0)
	bulb.position = Vector3(1.3, 2.75, 6.5)
	add_child(bulb)
	box(0.07, 0.07, 1.2, mat(Color(0.16, 0.14, 0.12), 0.6), Vector3(1.3, 2.95, 5.95))
	box(0.06, 0.28, 0.06, mat(Color(0.16, 0.14, 0.12), 0.6), Vector3(1.3, 2.82, 6.5))
	_cone(0.15, 1.1, 1.6, Color(1.0, 0.95, 0.85, 0.07), Vector3(4, 1.5, 3))
	_cone(0.12, 1.3, 2.4, Color(1.0, 0.85, 0.63, 0.08), Vector3(1.3, 1.6, 6.5))
	_cone(0.12, 0.9, 1.4, Color(1.0, 0.85, 0.63, 0.07), Vector3(-4.5, 1.5, -3.5))
	_cone(0.1, 1.0, 1.6, Color(1.0, 0.85, 0.63, 0.06), Vector3(-4, 1.6, 3))
	_shaft(1.7, 0.9, 4.2, -0.45, -4.5)
	_shaft(1.7, 1.0, 4.5, -0.5, 4.5)
	_dust(Vector3(-4.5, 1.2, 4.0), Vector3(0.9, 0.8, 1.2), 30)
	_dust(Vector3(4, 1.5, 3), Vector3(1.0, 0.7, 1.0), 24)
	_dust(Vector3(0, 1.4, -0.5), Vector3(2.0, 0.8, 0.5), 20)
	_dust(Vector3(1.3, 1.5, 6.5), Vector3(0.8, 0.8, 0.8), 20)
	var moonspot := SpotLight3D.new()
	moonspot.light_color = Color(0.56, 0.66, 1.0)
	moonspot.light_energy = 1.2
	moonspot.spot_range = 8.0
	moonspot.spot_angle = 30.0
	moonspot.position = Vector3(-4.5, 2.2, 5.8)
	moonspot.rotation.x = -0.67
	add_child(moonspot)
	alert_light = OmniLight3D.new()
	alert_light.light_color = Color(1.0, 0.08, 0.1)
	alert_light.light_energy = 3.0
	alert_light.omni_range = 12.0
	alert_light.position = Vector3(0, 2.4, -0.5)
	alert_light.visible = false
	add_child(alert_light)


func _outside() -> void:
	var gnd := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(90, 60)
	gnd.mesh = gm
	gnd.material_override = TEX.mat_for("grass", Color(0.17, 0.20, 0.18), 1.0)
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
	road.material_override = TEX.mat_for("asphalt", Color(0.13, 0.13, 0.15), 1.0)
	road.position = Vector3(0, 0.0, 15)
	add_child(road)
	_puddle(0, 10.5, 1.4, 2.2)
	_puddle(-3.5, 13.5, 2.2, 1.4)
	_puddle(4.5, 14.5, 2.6, 1.6)
	_puddle(-6, 9.0, 1.8, 1.2)
	var deck := TEX.mat_for("deck", Color(0.38, 0.29, 0.22), 0.9)
	box(6.4, 0.18, 2.6, deck, Vector3(0, 0.09, 6.8), 0.0, true)
	box(0.18, 3.0, 0.18, mat(Color(0.23, 0.18, 0.12), 0.9), Vector3(-2.9, 1.5, 7.9), 0.0, true)
	box(0.18, 3.0, 0.18, mat(Color(0.23, 0.18, 0.12), 0.9), Vector3(2.9, 1.5, 7.9), 0.0, true)
	box(6.8, 0.15, 3.0, mat(Color(0.08, 0.08, 0.09), 1.0), Vector3(0, 3.05, 6.8))
	var step_ramp := box(6.4, 0.06, 0.75, deck, Vector3(0, 0.09, 8.42), 0.0, true)
	step_ramp.rotation.x = 0.27
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
	sl.light_energy = 8.0
	sl.omni_range = 26.0
	sl.position = Vector3(8, 5.0, 12.5)
	add_child(sl)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.9, 0.7)
	spot.light_energy = 6.0
	spot.spot_range = 13.0
	spot.spot_angle = 38.0
	spot.shadow_enabled = true
	street_spot = spot
	spot.position = Vector3(8, 5.1, 12.5)
	spot.rotation.x = -PI / 2.0
	add_child(spot)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 2.4
	cm.height = 4.6
	cone.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.albedo_color = Color(1.0, 0.9, 0.7, 0.10)
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material_override = cmat
	cone.position = Vector3(8, 2.7, 12.5)
	add_child(cone)
	# neighbor house (escape A)
	box(7, 3.6, 5.5, TEX.mat_for("brick", Color(0.38, 0.24, 0.22), 1.0), Vector3(-17, 1.8, 10), 0.0, true)
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


func _build_cams() -> void:
	cam_vp = SubViewport.new()
	cam_vp.name = "CamVP"
	cam_vp.size = Vector2i(960, 540)
	cam_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	cam_vp.handle_input_locally = false
	add_child(cam_vp)
	var cenv := Environment.new()
	cenv.background_mode = Environment.BG_COLOR
	cenv.background_color = Color(0.008, 0.01, 0.025)
	cenv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	cenv.ambient_light_color = Color(0.09, 0.11, 0.17)
	cenv.ambient_light_energy = 0.45
	cenv.tonemap_mode = Environment.TONE_MAPPER_ACES
	cenv.tonemap_exposure = 1.15
	cenv.fog_enabled = true
	cenv.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	cenv.fog_density = 0.012
	cenv.fog_light_color = Color(0.09, 0.12, 0.2)
	var cwe := WorldEnvironment.new()
	cwe.environment = cenv
	cam_vp.add_child(cwe)
	var defs := [
		{"pos": Vector3(-2.6, 2.7, 7.7), "look": Vector3(0.3, 1.0, 6.2), "label": "CAM 01 · PORCH"},
		{"pos": Vector3(-7.5, 2.5, 0.9), "look": Vector3(-2, 0.8, 3.3), "label": "CAM 02 · LIVING"},
		{"pos": Vector3(-6.5, 3.2, 12.5), "look": Vector3(1.5, 1.0, 6.5), "label": "CAM 03 · STREET"},
		{"pos": Vector3(2.5, 3.0, -26.0), "look": Vector3(-3.0, 0.8, -31.5), "label": "CAM 04 · WOODS"},
	]
	for d in defs:
		var c := Camera3D.new()
		c.fov = 70.0
		c.position = d["pos"]
		cam_vp.add_child(c)
		c.look_at(d["look"], Vector3.UP)
		c.current = false
		cams.append(c)
		cam_labels.append(String(d["label"]))
	cams[0].current = true
	# Security monitor on the hall console (E to watch).
	box(0.5, 0.32, 0.04, mat(Color(0.05, 0.05, 0.06), 0.4), Vector3(-3.5, 1.12, -1.28))
	box(0.44, 0.26, 0.045, glow_mat(Color(0.2, 0.5, 0.3), 0.5), Vector3(-3.5, 1.12, -1.28))
	_cyl(0.03, 0.05, 0.14, mat(Color(0.1, 0.1, 0.1), 0.6), Vector3(-3.5, 0.9, -1.28))


func cam_cycle(dir: int) -> String:
	if cams.is_empty():
		return ""
	cams[cam_idx].current = false
	cam_idx = (cam_idx + dir + cams.size()) % cams.size()
	cams[cam_idx].current = true
	return String(cam_labels[cam_idx])


func room_at(x: float, z: float) -> String:
	if z < -14.0:
		return "woods" # R6: the pine woods behind the fence
	if z < -5.5:
		return "backyard"
	if x > 8.0 and z >= -3.5:
		return "garage"
	if x > 8.0:
		return "backyard" # east strip behind the garage: outdoors
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
		"market": "FRESHMART", "garage": "GARAGE", "backyard": "BACKYARD", "woods": "THE WOODS",
	}
	return names.get(r, r.to_upper())
