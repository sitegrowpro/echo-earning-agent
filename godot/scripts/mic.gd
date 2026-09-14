extends RefCounted
## MIC — real-microphone stealth. While hiding (or creeping), the game listens
## to your actual microphone: cough, talk, or laugh and HE hears you.
## Uses AudioStreamMicrophone + AudioEffectCapture on a silent bus (-80 dB),
## so the chain runs but you never hear yourself. Degrades gracefully to
## movement-noise-only when no mic is present.

var tree: SceneTree
var bus := -1
var effect: AudioEffectCapture
var mic_player: AudioStreamPlayer
var available := false
var enabled := true
var muted := false
var sensitivity := 0.6
var level := 0.0
var loud := false
var heard := false
var streak := 0.0
var warmup := 0.0
var announced := false


func threshold() -> float:
	return lerpf(0.30, 0.04, clampf(sensitivity, 0.0, 1.0))


func setup(p_tree: SceneTree) -> void:
	tree = p_tree
	bus = AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "MicCapture")
	effect = AudioEffectCapture.new()
	effect.buffer_length = 0.5
	AudioServer.add_bus_effect(bus, effect)
	# Silent bus: capture effect still receives audio, but nothing is audible.
	AudioServer.set_bus_volume_db(bus, -80.0)
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "MicCapture"
	tree.root.add_child.call_deferred(mic_player)
	(func(): if is_instance_valid(mic_player) and not mic_player.playing: mic_player.play()).call_deferred()


func poll(dt: float, active: bool) -> void:
	if effect == null:
		return
	if not active or not enabled or muted:
		level = lerpf(level, 0.0, minf(1.0, dt * 6.0))
		loud = false
		streak = 0.0
		return
	var n := effect.get_frames_available()
	if n > 0:
		var buf := effect.get_buffer(n)
		var peak := 0.0
		for v in buf:
			peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
		if not available:
			available = true
		level = lerpf(level, clampf(peak * 1.6, 0.0, 1.0), minf(1.0, dt * 10.0))
	else:
		warmup += dt
		if warmup > 4.0 and not available and not announced:
			announced = true
		level = lerpf(level, 0.0, minf(1.0, dt * 4.0))
	loud = available and level > threshold()
	if loud:
		streak += dt
	else:
		streak = maxf(0.0, streak - dt * 2.0)
	if streak > 0.45:
		heard = true
		streak = 0.0


func consume_heard() -> bool:
	if heard:
		heard = false
		return true
	return false


func toggle_mute() -> bool:
	muted = not muted
	streak = 0.0
	heard = false
	return muted


func reset_run() -> void:
	level = 0.0
	loud = false
	heard = false
	streak = 0.0
	muted = false
	announced = false


func status_text() -> String:
	if not enabled:
		return "Microphone stealth: OFF (movement noise only)"
	if muted:
		return "Microphone: MUTED (M to unmute)"
	if not available:
		return "Microphone: listening for a device..."
	return "Microphone: LIVE — stay quiet when hiding"
