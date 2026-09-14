extends CharacterBody3D
## First-person controller: mouse look, WASD, sprint/stamina, crouch,
## head-bob, noise emission. Feet-origin body; camera rides at eye height.

const CFG := preload("res://scripts/config.gd")

var audio
var world
var sens := 1.0
var headbob := true
var yaw := 0.0
var pitch := 0.0
var stamina := 100.0
var crouch := false
var is_sprinting := false
var moving := false
var frozen := true
var hidden := ""
var sitting := false
var noise := 0.0
var eye_cur := 1.62
var bob_t := 0.0
var step_t := 0.0
var indoor := true
var bounds_min := Vector2(-26.0, -7.6)
var bounds_max := Vector2(26.0, 16.4)
var fov_kick := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var body: CollisionShape3D = $Body


func _ready() -> void:
	stamina = CFG.STAM_MAX
	eye_cur = CFG.EYE
	_apply_look()


func set_look(p_yaw: float, p_pitch: float) -> void:
	yaw = p_yaw
	pitch = p_pitch
	_apply_look()


func _apply_look() -> void:
	rotation.y = yaw
	camera.rotation.x = pitch


func look_at_spot(from_pos: Vector3, to_pos: Vector3) -> void:
	# from_pos is an EYE position (web-style coords); feet stay on the floor.
	global_position = Vector3(from_pos.x, 0.0, from_pos.z)
	camera.position = Vector3(0, from_pos.y, 0)
	velocity = Vector3.ZERO
	var d := to_pos - from_pos
	yaw = atan2(-d.x, -d.z)
	pitch = atan2(d.y, maxf(0.001, Vector2(d.x, d.z).length()))
	_apply_look()


func _unhandled_input(event: InputEvent) -> void:
	if frozen or hidden != "" or sitting:
		pass
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if frozen:
		return
	if event is InputEventMouseMotion:
		var s := 0.0023 * sens
		yaw -= event.relative.x * s
		pitch = clampf(pitch - event.relative.y * s, -1.45, 1.45)
		_apply_look()


func surface_at() -> String:
	var p := global_position
	if p.x > 60.0:
		return "conc"
	if p.z >= 5.5:
		if absf(p.x) < 3.4 and p.z < 8.4:
			return "wood"
		return "grass" if p.z < 13.4 else "conc"
	if world == null:
		return "wood"
	match world.room_at(p.x, p.z):
		"kitchen", "bath":
			return "tile"
		"guest", "master":
			return "carpet"
		"laundry":
			return "conc"
	return "wood"


func _physics_process(dt: float) -> void:
	if frozen or hidden != "" or sitting:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= CFG.GRAVITY * dt
		else:
			velocity.y = -0.5
		move_and_slide()
		noise = maxf(0.0, noise - CFG.NOISE_DECAY * dt)
		fov_kick = lerpf(fov_kick, 0.0, minf(1.0, dt * 6.0))
		camera.fov = 72.0 + fov_kick
		return
	if Input.is_action_just_pressed("crouch"):
		crouch = not crouch
		_apply_crouch_shape()
	var ix := Input.get_axis("move_left", "move_right")
	var iz := Input.get_axis("move_forward", "move_back")
	moving = ix != 0.0 or iz != 0.0
	var want_sprint: bool = Input.is_action_pressed("sprint") and moving and iz < 0.0 and not crouch and stamina > CFG.STAM_MIN
	if want_sprint:
		stamina = maxf(0.0, stamina - CFG.STAM_DRAIN * dt)
	else:
		stamina = minf(CFG.STAM_MAX, stamina + CFG.STAM_REGEN * dt)
	var speed: float = CFG.CROUCH if crouch else (CFG.SPRINT if want_sprint else CFG.WALK)
	is_sprinting = want_sprint
	var dir := (transform.basis * Vector3(ix, 0.0, iz))
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= CFG.GRAVITY * dt
	else:
		velocity.y = -0.5
	move_and_slide()
	global_position.x = clampf(global_position.x, bounds_min.x, bounds_max.x)
	global_position.z = clampf(global_position.z, bounds_min.y, bounds_max.y)
	# eye height + head bob
	var target_eye: float = CFG.EYE_CROUCH if crouch else CFG.EYE
	eye_cur += (target_eye - eye_cur) * minf(1.0, dt * 8.0)
	var bob_y := 0.0
	if moving:
		bob_t += dt * (11.0 if want_sprint else 7.5)
		var amp := 0.0
		if headbob:
			amp = 0.055 if want_sprint else 0.032
		bob_y = absf(sin(bob_t)) * amp
		step_t -= dt
		if step_t <= 0.0:
			step_t = 0.32 if want_sprint else (0.62 if crouch else 0.46)
			if audio:
				audio.footstep_surf(want_sprint, crouch, surface_at())
			var n := 34.0 if want_sprint else (2.0 if crouch else 9.0)
			noise = minf(100.0, noise + n)
	camera.position = Vector3(0, eye_cur + bob_y, 0)
	fov_kick = lerpf(fov_kick, 6.0 if want_sprint else 0.0, minf(1.0, dt * 5.0))
	camera.fov = 72.0 + fov_kick
	noise = maxf(0.0, noise - CFG.NOISE_DECAY * dt * (0.4 if moving else 1.0))


func _apply_crouch_shape() -> void:
	var sh := body.shape as CapsuleShape3D
	if sh == null:
		return
	if crouch:
		sh.height = 1.1
		body.position.y = 0.55
	else:
		sh.height = 1.7
		body.position.y = 0.85


func stand_up() -> void:
	crouch = false
	_apply_crouch_shape()
