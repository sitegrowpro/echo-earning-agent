extends RefCounted
## Interact registry: invisible Area3D halos raycast from screen center.
## Supports instant + hold-to-complete. Prompt/on_use/hold are Callables(ctx).

var items: Array = []
var current := {}
var holding := false
var hold_t := 0.0
var hold_need := 0.0
var ctx := {}
var parent: Node3D
var ray: RayCast3D


func halo(pos: Vector3, r := 0.55) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 4
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = true
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = r
	cs.shape = sp
	a.add_child(cs)
	a.position = pos
	parent.add_child(a)
	return a


func add(def: Dictionary) -> void:
	items.append(def)
	(def["area"] as Area3D).set_meta("idef", def)


func update(dt: float) -> Dictionary:
	current = {}
	if ctx.is_empty() or bool(ctx["ui_blocked"].call()):
		holding = false
		hold_t = 0.0
		return current
	if ray == null or not ray.enabled:
		return current
	var col := ray.get_collider()
	if col is Area3D and (col as Area3D).has_meta("idef"):
		var def: Dictionary = (col as Area3D).get_meta("idef")
		var text: String = def["prompt"].call(ctx)
		if text != "":
			var h := 0.0
			if def.has("hold"):
				h = float(def["hold"].call(ctx))
			current = {"def": def, "text": text, "hold": h}
	if holding and not current.is_empty() and float(current["hold"]) > 0.0:
		hold_t += dt
		if hold_t >= float(current["hold"]):
			var c := current
			holding = false
			hold_t = 0.0
			(c["def"] as Dictionary)["on_use"].call(ctx)
	elif not holding:
		hold_t = 0.0
	return current


func press() -> void:
	if current.is_empty() or ctx.is_empty():
		return
	if bool(ctx["ui_blocked"].call()):
		return
	if float(current["hold"]) > 0.0:
		holding = true
		hold_t = 0.0
		hold_need = float(current["hold"])
	else:
		(current["def"] as Dictionary)["on_use"].call(ctx)


func release() -> void:
	holding = false
	hold_t = 0.0
	hold_need = 0.0
