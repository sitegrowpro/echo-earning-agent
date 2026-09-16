extends Node3D
## MAIN — game manager: states, menus, saves, input, per-frame glue.

const Story := preload("res://scripts/story.gd")
const Phone := preload("res://scripts/phone.gd")
const Interact := preload("res://scripts/interact.gd")
const Save := preload("res://scripts/save.gd")
const Mic := preload("res://scripts/mic.gd")
const Market := preload("res://scripts/market.gd")
const Cat := preload("res://scripts/cat.gd")

@onready var world = $World
@onready var player = $Player
@onready var enemy = $Enemy
@onready var audio = $Audio
@onready var ui = $UI
@onready var camera = $Player/Camera3D
@onready var flash = $Player/Camera3D/Flashlight
@onready var ray = $Player/Camera3D/InteractRay

var story
var phone
var interact
var mic
var market
var cat
var settings := {}
var state := "menu"
var last_room := ""
var last_ending := ""
var shake_t := 0.0
var intro_t := 0.0
var intro_on := false
var menu_t := 0.0

# R4: remappable keyboard controls (gamepad layout is fixed, see _pad_defaults).
const DEFAULT_KEYS := {
	"interact": [69], "flashlight": [70], "phone": [4194306],
	"crouch": [67, 4194326], "sprint": [4194325], "mute_mic": [77], "throw_item": [71],
}
const REBINDABLE := ["interact", "flashlight", "phone", "crouch", "sprint", "mute_mic", "throw_item"]
const REBIND_LABELS := {"interact": "Interact", "flashlight": "Flashlight", "phone": "Phone", "crouch": "Crouch", "sprint": "Sprint", "mute_mic": "Mute mic", "throw_item": "Throw distraction"}


func _ready() -> void:
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input()
	settings = Save.get_settings()
	market = Market.new()
	market.name = "Market"
	add_child(market)
	cat = Cat.new()
	cat.name = "Cat"
	add_child(cat)
	mic = Mic.new()
	mic.setup(get_tree())
	player.audio = audio
	player.world = world
	enemy.audio = audio
	story = Story.new()
	phone = Phone.new()
	story.setup({"audio": audio, "world": world, "enemy": enemy, "player": player, "root": self, "tree": get_tree(), "ui": ui, "phone": phone, "market": market, "cat": cat, "mic": mic})
	phone.audio = audio
	phone.ui = ui
	phone.story = story
	phone.tree = get_tree()
	cat.setup({"audio": audio, "player": player, "enemy": enemy, "story": story, "ui": ui})
	interact = Interact.new()
	interact.parent = world
	interact.ray = ray
	interact.ctx = {"story": story, "audio": audio, "player": player, "world": world, "enemy": enemy, "ui": ui, "ui_blocked": Callable(self, "is_ui_blocked")}
	story.register(interact)
	story.I = interact
	ui.setup(self, story, phone)
	audio.caption_cb = Callable(ui, "caption")
	audio.listener = player
	audio.occlude_excludes = [player.get_rid(), enemy.get_rid()]
	_apply_keys()
	apply_settings()
	ui.refresh_endings_list()
	ui.refresh_continue()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ensure_input() -> void:
	var defs := {
		"move_forward": [87, 4194320], "move_back": [83, 4194322],
		"move_left": [65, 4194319], "move_right": [68, 4194321],
		"sprint": [4194325], "crouch": [67, 4194326],
		"interact": [69], "flashlight": [70], "phone": [4194306],
		"phone_next": [81], "reply_1": [49], "reply_2": [50], "reply_3": [51],
		"pause_game": [4194305], "mute_mic": [77],
		"getup": [32], "throw_item": [71],
		"cam_prev": [65], "cam_next": [68], "cam_night": [78],
	}
	for a in defs.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		if InputMap.action_get_events(a).is_empty():
			for code in (defs[a] as Array):
				var ev := InputEventKey.new()
				ev.device = -1
				ev.physical_keycode = code
				InputMap.action_add_event(a, ev)
	if not InputMap.has_action("focus"):
		InputMap.add_action("focus")
	if InputMap.action_get_events("focus").is_empty():
		var mev := InputEventMouseButton.new()
		mev.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("focus", mev)
	_pad_defaults()


func _pad_defaults() -> void:
	# R4: fixed gamepad layout. Left stick moves (motion events on move_*),
	# right stick looks (player.gd polls it), Start pauses, D-pad + A drive
	# focused menu/dialog buttons through the default ui_* actions.
	var pads := {
		"interact": [JOY_BUTTON_A], "flashlight": [JOY_BUTTON_X], "phone": [JOY_BUTTON_Y],
		"sprint": [JOY_BUTTON_LEFT_STICK], "crouch": [JOY_BUTTON_RIGHT_STICK],
		"pause_game": [JOY_BUTTON_START], "mute_mic": [JOY_BUTTON_BACK],
		"throw_item": [JOY_BUTTON_RIGHT_SHOULDER], "getup": [JOY_BUTTON_B],
	}
	for a in pads.keys():
		if not InputMap.has_action(a):
			continue
		var has_pad := false
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				has_pad = true
		if has_pad:
			continue
		for b in (pads[a] as Array):
			var ev: InputEventJoypadButton = InputEventJoypadButton.new()
			ev.button_index = b
			InputMap.action_add_event(a, ev)
	var sticks := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for a in sticks.keys():
		var has_motion := false
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadMotion:
				has_motion = true
		if has_motion:
			continue
		var mv: InputEventJoypadMotion = InputEventJoypadMotion.new()
		mv.axis = (sticks[a] as Array)[0]
		mv.axis_value = (sticks[a] as Array)[1]
		InputMap.action_add_event(a, mv)


func _apply_keys() -> void:
	# Rebuild key events for remappable actions: saved key if any, else default.
	var saved: Dictionary = settings.get("keys", {})
	for a in REBINDABLE:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				InputMap.action_erase_event(a, e)
		var codes: Array = [int(saved[a])] if saved.has(a) else (DEFAULT_KEYS[a] as Array).duplicate()
		for code in codes:
			var ev := InputEventKey.new()
			ev.device = -1
			ev.physical_keycode = code
			InputMap.action_add_event(a, ev)


func rebind(action: String, code: int) -> void:
	if not (action in REBINDABLE) or code == KEY_ESCAPE or code <= 0:
		return
	var keys: Dictionary = (settings.get("keys", {}) as Dictionary).duplicate()
	for a in keys.keys(): # one key, one action: whoever had it falls back to default
		if String(a) != action and int(keys[a]) == code:
			keys.erase(a)
	keys[action] = code
	settings["keys"] = keys
	Save.save_settings(settings)
	_apply_keys()
	ui.refresh_rebinds()


func reset_keys() -> void:
	settings["keys"] = {}
	Save.save_settings(settings)
	_apply_keys()
	ui.refresh_rebinds()


func is_ui_blocked() -> bool:
	return story.ui_busy() or state != "playing"


func update_mouse() -> void:
	if state == "playing" and not story.ui_busy() and not phone.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _is_echo(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).echo


func _unhandled_input(event: InputEvent) -> void:
	if ui.warn_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause_game"):
			warn_click()
			return
	if state == "intro":
		if event.is_action_pressed("interact") or event.is_action_pressed("pause_game") or event.is_action_pressed("getup"):
			finish_intro()
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			finish_intro()
			return
	if state == "paused":
		if event.is_action_pressed("pause_game") and not _is_echo(event):
			resume_game()
			return
	if state != "playing":
		return
	if _is_echo(event):
		return
	if event.is_action_pressed("mute_mic"):
		var m: bool = mic.toggle_mute()
		audio.ui_click()
		ui.toast("🎙 Mic MUTED — hiding uses movement noise only." if m else "🎙 Mic LIVE — stay quiet when hiding.")
		return
	if event.is_action_pressed("phone") and not story.ui_busy():
		audio.ui_click()
		phone.toggle()
		return
	if phone.visible:
		if event.is_action_pressed("reply_1"):
			ui.press_reply(0)
			return
		if event.is_action_pressed("reply_2"):
			ui.press_reply(1)
			return
		if event.is_action_pressed("reply_3"):
			ui.press_reply(2)
			return
		if event.is_action_pressed("phone_next"):
			var order := ["millers", "priya", "unknown"]
			phone.show(order[(order.find(phone.active) + 1) % order.size()])
			return
	if story.note_open and (event.is_action_pressed("interact") or event.is_action_pressed("pause_game")):
		story.close_note()
		return
	if story.peep_open and (event.is_action_pressed("interact") or event.is_action_pressed("pause_game")):
		story.close_peep()
		return
	if story.story_open and (event.is_action_pressed("interact") or event.is_action_pressed("pause_game")):
		story.close_story()
		return
	if ui.dialog_panel.visible:
		if event.is_action_pressed("reply_1"):
			ui.press_dialog(0)
			return
		if event.is_action_pressed("reply_2"):
			ui.press_dialog(1)
			return
		if event.is_action_pressed("reply_3"):
			ui.press_dialog(2)
			return
	if story.cam_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("phone"):
			story.cam_close()
			return
		if event.is_action_pressed("cam_prev"):
			ui.cam_cycle(-1)
			return
		if event.is_action_pressed("cam_next"):
			ui.cam_cycle(1)
			return
		if event.is_action_pressed("cam_night"):
			ui.cam_night_toggle()
			return
		return
	if story.ui_busy():
		return
	if event.is_action_pressed("getup"):
		_getup()
		return
	if event.is_action_pressed("throw_item"):
		story.throw_distraction()
		return
	if event.is_action_pressed("interact"):
		interact.press()
	if event.is_action_released("interact"):
		interact.release()
	if event.is_action_pressed("flashlight"):
		story.toggle_flash()
	if event.is_action_pressed("pause_game"):
		pause_game()
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			update_mouse()


func _getup() -> void:
	var h := String(player.get("hidden"))
	if h != "":
		story.hide(h)
	elif bool(player.get("sitting")):
		story.sit_toggle()
	elif bool(player.get("crouch")):
		player.call("stand_up")


func _physics_process(dt: float) -> void:
	if state == "menu":
		menu_t += dt
		_menu_drift()
		return
	if state == "intro":
		_intro_tick(dt)
		return
	if state != "playing":
		return
	mic.poll(dt, true)
	cat.update(dt)
	var pp: Vector3 = player.global_position
	var room := room_of(pp)
	if room != last_room:
		last_room = room
		if not story.finished:
			story.on_room(room)
	player.indoor = room != "porch" and room != "yard" and room != "street"
	world.set_slabs_outside(not player.indoor)
	# R4: rain follows shelter — full storm outside, muffled patter inside.
	if bool(story.flags.get("in_market", false)):
		audio.set_rain_level(0.12, true)
	else:
		audio.set_rain_level(0.35 if player.indoor else 1.0, player.indoor)
	story.update(dt)
	# R4: Daniel freezes while MODAL ui holds the player — being caught
	# mid-dialogue was unfair and fired story callbacks after death.
	# The phone is NOT modal: texting while he hunts stays dangerous.
	var modal: bool = story.dialog_open or story.note_open or story.peep_open or story.call_open or story.story_open or story.cam_open
	var res := ""
	if not modal and not story.finished:
		res = enemy.update_enemy(dt, player, story)
	if res == "caught" and not story.finished:
		ui.jumpscare(Callable(story, "finish").bind("D", "He was faster. He is always faster."))
	var target_e := 8.0 if story.flash_is_on else 0.0
	if story.flash_is_on and float(story.items.get("battery", 100.0)) < 20.0 and randf() < 0.08:
		target_e = 1.0
	flash.light_energy += (target_e - flash.light_energy) * minf(1.0, dt * 10.0)
	if story.chapter == 6 and not story.finished and room == "street":
		story.finish("B")
	ui.set_meters(player.stamina, player.noise, float(story.items.get("battery", 100.0)), bool(story.items.get("flash", false)))
	var est2: String = String(enemy.get("state"))
	var dread := 0.3
	if est2 == "chase":
		dread = 1.0
	elif est2 == "investigate":
		dread = 0.7
	elif String(player.get("hidden")) != "" and story.chapter >= 5:
		dread = 0.8
	elif story.chapter >= 5:
		dread = 0.55
	elif bool(story.flags.get("in_market", false)):
		dread = 0.15
	ui.set_dread(dread)
	audio.set_dread_mix(dread)
	world.set_alert(est2 == "chase" and not story.finished)
	ui.set_mic(mic.enabled and mic.available and not story.finished, mic.level, mic.loud, String(player.get("hidden")) != "")
	var cur: Dictionary = interact.update(dt)
	if not cur.is_empty():
		ui.set_prompt(String(cur["text"]), float(cur["hold"]) > 0.0)
		if interact.holding and interact.hold_need > 0.0:
			ui.set_hold(interact.hold_t / interact.hold_need)
		else:
			ui.set_hold(-1.0)
	else:
		ui.set_prompt("", false)
		ui.set_hold(-1.0)
	if shake_t > 0.0:
		shake_t -= dt
		camera.h_offset = randf_range(-0.06, 0.06)
		camera.v_offset = randf_range(-0.06, 0.06)
	elif String(enemy.get("state")) == "chase" and not story.finished:
		camera.h_offset = randf_range(-0.012, 0.012)
		camera.v_offset = randf_range(-0.012, 0.012)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func room_of(p: Vector3) -> String:
	if p.x > 60.0:
		return "market"
	if p.z >= 5.5:
		if absf(p.x) < 3.4 and p.z < 8.4:
			return "porch"
		return "street" if p.z >= 13.4 else "yard"
	return world.room_at(p.x, p.z)


# ---------- market travel ----------
func enter_market(instant := false) -> void:
	if instant:
		_enter_market_now()
	else:
		ui.fade_swap(_enter_market_now)


func _enter_market_now() -> void:
	story.flags["in_market"] = true
	world.set_market_mood(true)
	audio.set_rain_level(0.12)
	audio.set_hum(true)
	player.bounds_min = Market.BOUNDS_MIN
	player.bounds_max = Market.BOUNDS_MAX
	player.global_position = Market.SPAWN
	player.call("set_look", 0.0, 0.0)
	story.market_enter()
	update_mouse()


func exit_market() -> void:
	ui.fade_swap(_exit_market_now)


func _exit_market_now() -> void:
	story.flags["in_market"] = false
	story.market_exit()
	world.set_market_mood(false)
	audio.set_rain_level(1.0)
	player.bounds_min = Vector2(-26.0, -7.6)
	player.bounds_max = Vector2(26.0, 16.4)
	player.global_position = Vector3(0, 0, 7.4)
	player.call("set_look", 0.0, 0.0)
	story.clock_min += 25.0
	story.done("market")


func flash_lightning() -> void:
	if bool(settings.get("photosafe", false)):
		audio.thunder() # R4: photosafe users get the cue without the strobe
		return
	world.flash_lightning()
	await get_tree().create_timer(randf_range(0.6, 2.2), false).timeout
	if state == "playing":
		audio.thunder()


# ---------- state flow ----------
func _reset_run() -> void:
	world.set_power(true)
	world.set_rain(true)
	world.set_tv(false)
	world.set_market_mood(false)
	audio.set_tv(false)
	audio.set_heart(false)
	audio.set_hum(false)
	audio.set_whisper(false)
	audio.set_drone(false)
	audio.set_stalk(false)
	world.reset_dread_props()
	audio.mj_stop()
	mic.reset_run()
	market.reset_run()
	cat.reset_run()
	player.bounds_min = Vector2(-26.0, -7.6)
	player.bounds_max = Vector2(26.0, 16.4)
	world.escape_win_body.get_child(0).set_deferred("disabled", false)
	for id in world.doors.keys():
		var d = world.doors[id]
		var open: bool = id == "guest" or id == "bath"
		d.set("is_open", open)
		d.set("target", float(d.get("swing")) if open else 0.0)
		d.set("angle", float(d.get("swing")) if open else 0.0)
		d.rotation.y = float(d.get("angle"))
		d.set("locked", id == "master")
		(d.get("shape") as CollisionShape3D).set_deferred("disabled", open)
	enemy.set("state", "dormant")
	enemy.set("aggression", 0)
	enemy.set("speed_mul", 1.0)
	enemy.set("wp", 0)
	enemy.visible = false
	player.set("frozen", false)
	player.set("hidden", "")
	player.set("sitting", false)
	player.set("noise", 0.0)
	player.set("stamina", 100.0)
	player.call("stand_up")
	phone.threads = {"millers": [], "priya": [], "unknown": []}
	phone.unread = {"millers": 0, "priya": 0, "unknown": 0}
	phone.active = "millers"
	phone.visible = false
	ui.set_replies([])
	ui.set_phone_visible(false)
	ui.unknown_btn.visible = false


func _start(fresh: bool) -> void:
	intro_on = false # R4.1: _start is terminal — the intro can never survive it
	intro_t = 0.0
	ui.show_intro(false)
	audio.ui_click()
	audio.start_ambience()
	audio.start_rain()
	audio.start_music()
	_reset_run()
	get_tree().paused = false
	state = "playing"
	ui.show_hud()
	last_room = ""
	if fresh:
		Save.clear_save()
		story.new_game()
		# "Based on a true story" framing card, F2F-style: shown once per run.
		story.story_open = true
		ui.true_story_card()
	else:
		var s := Save.load_game()
		if s.is_empty():
			story.new_game()
		else:
			story.load_data(s)
			if bool(story.flags.get("master_open", false)):
				(world.doors["master"]).set("locked", false)
			if story.chapter == 4 and not story.is_done("fuse"):
				world.set_power(false)
			if story.chapter >= 5 and not bool(story.flags.get("in_market", false)):
				enemy.visible = true
				enemy.call("place", 0.0, -0.5, 0.0)
				enemy.set("state", "patrol")
			if bool(story.flags.get("in_market", false)):
				market.set_folks_home(bool(story.flags.get("keanu_done", false)))
				for gid in (story.flags.get("groceries", []) as Array):
					market.take_item(gid)
				enter_market(true)
	audio.set_hum(world.power or bool(story.flags.get("in_market", false)))
	ui.refresh_continue()
	update_mouse()


func start_new(skip_intro := false) -> void:
	if skip_intro:
		_start(true)
	else:
		_start_intro()


func warn_click() -> void:
	audio.ui_click()
	ui.warn_close()


func _start_intro() -> void:
	audio.ui_click()
	audio.start_ambience()
	audio.start_rain()
	audio.start_music()
	_reset_run()
	get_tree().paused = false
	state = "intro"
	intro_t = 0.0
	intro_on = true
	player.set("frozen", true)
	ui.show_intro(true)
	last_room = ""
	update_mouse()


func finish_intro() -> void:
	if state != "intro":
		return
	intro_on = false
	ui.show_intro(false)
	state = "playing"
	ui.show_hud()
	last_room = ""
	Save.clear_save()
	story.new_game()
	story.story_open = true
	ui.true_story_card()
	audio.set_hum(world.power or bool(story.flags.get("in_market", false)))
	ui.refresh_continue()
	update_mouse()


func _menu_drift() -> void:
	var k := 0.5 + 0.5 * sin(menu_t * TAU / 26.0)
	var eye := Vector3(lerpf(-7.0, 7.0, k), 2.4, 13.8)
	player.call("look_at_spot", eye, Vector3(0, 1.6, 5.5))


func _intro_tick(dt: float) -> void:
	intro_t += dt
	var keys := [
		{"t": 0.0, "eye": Vector3(0, 3.4, 17.5), "look": Vector3(0, 1.6, 5.5)},
		{"t": 8.0, "eye": Vector3(-3.5, 2.0, 12.5), "look": Vector3(0, 1.4, 5.5)},
		{"t": 16.0, "eye": Vector3(0, 1.62, 8.8), "look": Vector3(0, 1.4, 5.5)},
		{"t": 24.0, "eye": Vector3(0, 1.6, 6.9), "look": Vector3(0, 1.5, 5.5)},
	]
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[keys.size() - 1]
	for i in keys.size() - 1:
		if intro_t >= float(keys[i]["t"]) and intro_t <= float(keys[i + 1]["t"]):
			a = keys[i]
			b = keys[i + 1]
	var span: float = maxf(0.01, float(b["t"]) - float(a["t"]))
	var f: float = clampf((intro_t - float(a["t"])) / span, 0.0, 1.0)
	var eye: Vector3 = (a["eye"] as Vector3).lerp(b["eye"], f)
	var look: Vector3 = (a["look"] as Vector3).lerp(b["look"], f)
	player.call("look_at_spot", eye, look)
	ui.intro_tick(intro_t)
	if intro_t >= 25.0:
		finish_intro()


func start_continue() -> void:
	_start(false)


func pause_game() -> void:
	if state != "playing" or story.ui_busy():
		return
	state = "paused"
	ui.show_pause(true)
	get_tree().paused = true
	update_mouse()


func resume_game() -> void:
	if state != "paused":
		return
	state = "playing"
	ui.show_pause(false)
	get_tree().paused = false
	update_mouse()


func autosave() -> void:
	if state == "playing" and story.chapter >= 0:
		Save.save_game(story.serialize())


func quit_to_menu() -> void:
	if (state == "playing" or state == "paused") and not story.finished:
		Save.save_game(story.serialize())
	story.script_token += 1 # R4: kill pending timers/coroutines — nothing may fire on the menu
	state = "menu"
	audio.set_hum(false)
	audio.set_heart(false) # R4: loops driven by update() must die here — update() stops on menu
	audio.set_drone(false)
	audio.set_stalk(false)
	audio.set_whisper(false)
	get_tree().paused = false
	phone.toggle(0)
	ui.show_menu()
	update_mouse()


func on_ending(id: String) -> void:
	last_ending = id
	state = "ending"
	Save.unlock_ending(id)
	if id != "D":
		Save.clear_save()
	phone.toggle(0)
	ui.hud.visible = false
	audio.set_heart(false)
	audio.set_whisper(false)
	audio.mj_stop()
	audio.set_hum(false)
	audio.set_stalk(false)
	ui.refresh_endings_list()
	ui.refresh_continue()


func again_pressed() -> void:
	audio.ui_click()
	if last_ending == "D":
		_retry_checkpoint()
	else:
		_start(true)


func _retry_checkpoint() -> void:
	# F2F rules: death returns you to the chapter-entry checkpoint — the real
	# saved state, not a fabricated one. The slot always holds it: every
	# chapter entry autosaves, and deaths never overwrite or clear it.
	ui.hide_ending()
	_start(false)


func note_click() -> void:
	if story.note_open:
		story.close_note()


func story_click() -> void:
	if story.story_open:
		story.close_story()


func peep_click() -> void:
	if story.peep_open:
		story.close_peep()


func setting_changed(key: String, v: Variant) -> void:
	settings[key] = v
	Save.save_settings(settings)
	apply_settings()


func apply_settings() -> void:
	audio.set_vol(float(settings.get("vol", 0.8)))
	audio.set_mix(float(settings.get("vol_music", 1.0)), float(settings.get("vol_sfx", 1.0)), float(settings.get("vol_voice", 1.0)))
	player.sens = float(settings.get("sens", 1.0))
	player.headbob = bool(settings.get("headbob", true))
	player.fov_base = clampf(float(settings.get("fov", 72.0)), 60.0, 90.0)
	if not story.dialog_open and not story.note_open:
		player.fov_target = player.fov_base
	story.photosafe = bool(settings.get("photosafe", false))
	mic.enabled = bool(settings.get("mic", true))
	mic.sensitivity = float(settings.get("micsens", 0.6))
	ui.apply_settings_vis()
	world.set_quality(bool(settings.get("highq", true)))


func get_endings() -> Dictionary:
	return Save.get_endings()


func has_save() -> bool:
	return Save.has_save()


func shake(t: float) -> void:
	shake_t = t
