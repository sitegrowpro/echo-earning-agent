extends Node
## Procedural audio: every sound is synthesized at boot into AudioStreamWAV.
## Zero audio files. 2D pool for UI/feet/phone, 3D pool for world sounds.

var rate := 22050
var bank := {}
var pool2d: Array[AudioStreamPlayer] = []
var pool3d: Array[AudioStreamPlayer3D] = []
var i2d := 0
var i3d := 0
var room_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var tv_player: AudioStreamPlayer3D # R4: the TV is a room, not a soundtrack — positional now
var heart_player: AudioStreamPlayer
var hum_player: AudioStreamPlayer
var whisper_player: AudioStreamPlayer
var mj_player: AudioStreamPlayer
var drone_player: AudioStreamPlayer
var shower_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var vox := {}
var heart_on := false
var heart_fast := false
var heart_t := 0.0
var vol := 0.8
var pool3d_muf: Array[AudioStreamPlayer3D] = [] # R4: occluded (through-wall) voices
var voice_player: AudioStreamPlayer
var stalk_player: AudioStreamPlayer
var sub_player: AudioStreamPlayer
var glass_player: AudioStreamPlayer
var night_player: AudioStreamPlayer
var fridge_player: AudioStreamPlayer3D
var rain_on := false
var duck_t := 0.0
var caption_cb := Callable() # R4: closed captions, wired by main
var listener: Node3D
var occlude_excludes: Array = []
var music_db := 0.0
var sfx_db := 0.0
var voice_db := 0.0


func _ensure_bus(n: String) -> void:
	if AudioServer.get_bus_index(n) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, n)


func _loop_player(bus: String) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new()
	pl.bus = bus
	add_child(pl)
	return pl


func _ready() -> void:
	randomize()
	# R4: Music / SFX / Voice buses (separate sliders = the accessibility
	# standard) + a lowpassed Muffled bus for through-wall sound.
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Voice")
	_ensure_bus("Muffled")
	var lp: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 550.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Muffled"), lp)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool2d.append(p)
		var q := AudioStreamPlayer3D.new()
		q.max_distance = 60.0
		q.bus = "SFX"
		add_child(q)
		pool3d.append(q)
		var qm: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		qm.max_distance = 60.0
		qm.bus = "Muffled"
		add_child(qm)
		pool3d_muf.append(qm)
	room_player = _loop_player("SFX")
	rain_player = _loop_player("SFX")
	tv_player = AudioStreamPlayer3D.new()
	tv_player.bus = "SFX"
	tv_player.position = Vector3(-2.0, 1.2, 0.6)
	tv_player.unit_size = 6.0
	tv_player.max_distance = 24.0
	add_child(tv_player)
	heart_player = _loop_player("SFX")
	hum_player = _loop_player("SFX")
	whisper_player = _loop_player("SFX")
	mj_player = _loop_player("SFX")
	drone_player = _loop_player("SFX")
	shower_player = _loop_player("SFX")
	music_player = _loop_player("Music")
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)
	stalk_player = _loop_player("SFX")
	sub_player = _loop_player("SFX")
	glass_player = _loop_player("SFX")
	night_player = _loop_player("SFX")
	fridge_player = AudioStreamPlayer3D.new()
	fridge_player.bus = "SFX"
	fridge_player.position = Vector3(7.0, 1.2, 1.0)
	fridge_player.unit_size = 5.0
	fridge_player.max_distance = 12.0
	add_child(fridge_player)
	_build_bank()
	set_vol(vol)
	set_mix(1.0, 1.0, 1.0)


func set_vol(v: float) -> void:
	vol = v
	var db := -60.0 if v <= 0.01 else linear_to_db(v)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)


func _slider_db(v: float) -> float:
	return -60.0 if v <= 0.01 else linear_to_db(v)


func set_mix(m: float, s: float, v: float) -> void:
	music_db = _slider_db(m)
	sfx_db = _slider_db(s)
	voice_db = _slider_db(v)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), voice_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Muffled"), sfx_db - 4.0)


func set_dread_mix(d: float) -> void:
	# R5: score stays minimal while safe (spec: silence-first), leans in on dread.
	if music_player and music_player.playing:
		music_player.volume_db = clampf(music_db + lerpf(-26.0, -10.0, clampf(d, 0.0, 1.0)), -48.0, 3.0)
		music_player.pitch_scale = 0.96 + 0.08 * clampf(d, 0.0, 1.0)


func set_stalk(on: bool, level := 0.0) -> void:
	if on and bank.has("stalk_loop"):
		if not stalk_player.playing:
			stalk_player.stream = bank["stalk_loop"]
			stalk_player.play()
		stalk_player.volume_db = lerpf(-38.0, -14.0, clampf(level, 0.0, 1.0))
	elif stalk_player:
		stalk_player.stop()


func cue(t: String) -> void:
	if caption_cb.is_valid():
		caption_cb.call(t)


func set_subbass(on: bool) -> void:
	# R5: 30-60 Hz threat weight — felt on headphones/subs, per spec.
	if on and bank.has("subbass_loop"):
		if not sub_player.playing:
			sub_player.stream = bank["subbass_loop"]
			sub_player.volume_db = -12.0
			sub_player.play()
	elif sub_player:
		sub_player.stop()


func set_glass_rain(indoor: bool) -> void:
	var want: bool = indoor and rain_on and rain_player.playing
	if want and bank.has("glassrain_loop"):
		if not glass_player.playing:
			glass_player.stream = bank["glassrain_loop"]
			glass_player.volume_db = -24.0
			glass_player.play()
	elif glass_player:
		glass_player.stop()


func set_wind(outdoor: bool) -> void:
	if outdoor and bank.has("night_loop"):
		if not night_player.playing:
			night_player.stream = bank["night_loop"]
			night_player.volume_db = -26.0
			night_player.play()
	elif night_player:
		night_player.stop()


func scare_duck() -> void:
	# R5: the spec's "wrong silence" — everything drops out half a beat
	# before the scare lands. Restored automatically in _process.
	if duck_t > 0.0:
		return
	duck_t = 0.55
	_apply_duck(-28.0)


func _apply_duck(db: float) -> void:
	for b in ["Music", "SFX", "Voice", "Muffled"]:
		var bn: String = b
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bn), db)


func _restore_mix() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), voice_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Muffled"), sfx_db - 4.0)


# ---------- synthesis helpers ----------
func _empty(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(1, int(dur * rate)))
	return b


func _put_tone(b: PackedFloat32Array, freq: float, volu: float, wave: String, start: float, dur: float, slide_to := 0.0, decay := 3.0) -> void:
	var s0 := int(start * rate)
	var n := int(dur * rate)
	if n <= 0:
		return
	var phase := 0.0
	for i in n:
		var f := freq
		if slide_to > 0.0:
			f = lerpf(freq, slide_to, float(i) / float(n - 1))
		phase += TAU * f / rate
		var s := 0.0
		match wave:
			"sine":
				s = sin(phase)
			"square":
				s = 1.0 if sin(phase) > 0.0 else -1.0
			"tri":
				s = asin(clampf(sin(phase), -1.0, 1.0)) * 0.6366
			"saw":
				s = fmod(phase, TAU) / PI - 1.0
		var env := 1.0
		if decay > 0.0:
			env = exp(-decay * float(i) / float(n - 1))
		var idx := s0 + i
		if idx >= 0 and idx < b.size():
			b[idx] += s * volu * env


func _put_noise(b: PackedFloat32Array, volu: float, start: float, dur: float, cutoff := 0.0, highpass := false, decay := 3.0) -> void:
	var s0 := int(start * rate)
	var n := int(dur * rate)
	if n <= 0:
		return
	var alpha := 0.0
	if cutoff > 0.0:
		alpha = 1.0 - exp(-TAU * cutoff / rate)
	var y := 0.0
	for i in n:
		var x := randf() * 2.0 - 1.0
		var out := x
		if cutoff > 0.0:
			y += alpha * (x - y)
			out = (x - y) if highpass else y
		var env := 1.0
		if decay > 0.0:
			env = exp(-decay * float(i) / float(n - 1))
		var idx := s0 + i
		if idx >= 0 and idx < b.size():
			b[idx] += out * volu * env


func _fade(b: PackedFloat32Array, fade_in: float, fade_out: float) -> void:
	var ni := int(fade_in * rate)
	var no := int(fade_out * rate)
	for i in mini(ni, b.size()):
		b[i] *= float(i) / float(maxi(1, ni))
	for i in mini(no, b.size()):
		b[b.size() - 1 - i] *= float(i) / float(maxi(1, no))


func _loopify(b: PackedFloat32Array, fade_ms := 60.0) -> void:
	var n := mini(int(fade_ms / 1000.0 * rate), int(b.size() / 2.0))
	for i in n:
		var t := float(i) / float(maxi(1, n))
		var idx := b.size() - n + i
		b[idx] = b[idx] * (1.0 - t) + b[i] * t


func _wav(b: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		var v := int(clampf(b[i], -1.0, 1.0) * 32767.0)
		if v < 0:
			v += 65536
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w


func _loop_wav(b: PackedFloat32Array) -> AudioStreamWAV:
	_loopify(b)
	var w := _wav(b)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = b.size()
	return w


func _build_bank() -> void:
	var b: PackedFloat32Array
	# footsteps — wood (base)
	b = _empty(0.14)
	_put_tone(b, 90.0, 0.5, "sine", 0.0, 0.1, 60.0, 6.0)
	_put_noise(b, 0.12, 0.0, 0.08, 600.0, false, 6.0)
	bank["step_walk"] = _wav(b)
	b = _empty(0.14)
	_put_tone(b, 100.0, 0.85, "sine", 0.0, 0.11, 55.0, 5.0)
	_put_noise(b, 0.25, 0.0, 0.1, 800.0, false, 5.0)
	bank["step_run"] = _wav(b)
	b = _empty(0.16)
	_put_tone(b, 80.0, 0.22, "sine", 0.0, 0.12, 55.0, 5.0)
	bank["step_crouch"] = _wav(b)
	# footsteps — tile (bright click + slap)
	b = _empty(0.12)
	_put_tone(b, 190.0, 0.4, "tri", 0.0, 0.08, 120.0, 7.0)
	_put_noise(b, 0.2, 0.0, 0.06, 2400.0, true, 7.0)
	bank["step_tile"] = _wav(b)
	# footsteps — carpet (soft thud)
	b = _empty(0.16)
	_put_tone(b, 70.0, 0.35, "sine", 0.0, 0.13, 45.0, 5.0)
	_put_noise(b, 0.05, 0.0, 0.1, 400.0, false, 5.0)
	bank["step_carpet"] = _wav(b)
	# footsteps — concrete (flat knock)
	b = _empty(0.13)
	_put_tone(b, 120.0, 0.5, "tri", 0.0, 0.1, 70.0, 6.0)
	_put_noise(b, 0.14, 0.0, 0.08, 1000.0, false, 6.0)
	bank["step_conc"] = _wav(b)
	# footsteps — grass (soft shuffle)
	b = _empty(0.15)
	_put_noise(b, 0.22, 0.0, 0.13, 1500.0, false, 4.0)
	_put_tone(b, 75.0, 0.25, "sine", 0.0, 0.1, 55.0, 5.0)
	bank["step_grass"] = _wav(b)
	# doors
	b = _empty(0.65)
	_put_tone(b, 180.0, 0.3, "saw", 0.05, 0.5, 340.0, 1.5)
	_put_noise(b, 0.05, 0.05, 0.5, 900.0, false, 1.5)
	bank["creak_open"] = _wav(b)
	b = _empty(0.65)
	_put_tone(b, 320.0, 0.3, "saw", 0.05, 0.5, 140.0, 1.5)
	_put_noise(b, 0.05, 0.05, 0.5, 900.0, false, 1.5)
	bank["creak_close"] = _wav(b)
	b = _empty(0.28)
	_put_tone(b, 65.0, 0.9, "sine", 0.0, 0.24, 40.0, 5.0)
	_put_noise(b, 0.2, 0.0, 0.1, 500.0, false, 6.0)
	bank["shut"] = _wav(b)
	b = _empty(0.3)
	_put_tone(b, 140.0, 0.5, "square", 0.0, 0.07, 0.0, 8.0)
	_put_tone(b, 110.0, 0.5, "square", 0.11, 0.09, 0.0, 8.0)
	bank["locked"] = _wav(b)
	# knocks (baked sequences)
	b = _empty(1.1)
	for k in 3:
		_put_tone(b, 85.0, 0.9, "sine", 0.05 + k * 0.3, 0.16, 55.0, 6.0)
	bank["knock_soft"] = _wav(b)
	b = _empty(1.5)
	for k in 3:
		_put_tone(b, 55.0, 1.0, "sine", 0.05 + k * 0.42, 0.2, 35.0, 5.0)
	bank["knock_heavy"] = _wav(b)
	b = _empty(1.0)
	for k in 2:
		_put_tone(b, 55.0, 1.0, "sine", 0.05 + k * 0.42, 0.2, 35.0, 5.0)
	bank["knock2"] = _wav(b)
	b = _empty(0.35)
	_put_tone(b, 70.0, 0.9, "sine", 0.02, 0.2, 45.0, 5.0)
	bank["knock1"] = _wav(b)
	# glass
	b = _empty(0.55)
	_put_noise(b, 0.8, 0.0, 0.5, 3800.0, true, 5.0)
	_put_tone(b, 1200.0, 0.3, "tri", 0.0, 0.2, 400.0, 5.0)
	bank["glass"] = _wav(b)
	# thunder: crack + long rolling rumble
	b = _empty(3.6)
	_put_noise(b, 0.7, 0.0, 0.25, 3000.0, true, 7.0)
	_put_tone(b, 48.0, 1.0, "sine", 0.05, 3.2, 26.0, 1.2)
	_put_noise(b, 0.5, 0.1, 3.2, 320.0, false, 1.1)
	bank["thunder"] = _wav(b)
	# phone / ui
	b = _empty(0.5)
	_put_tone(b, 880.0, 0.5, "sine", 0.0, 0.12, 0.0, 4.0)
	_put_tone(b, 1174.0, 0.5, "sine", 0.13, 0.2, 0.0, 4.0)
	bank["ding"] = _wav(b)
	b = _empty(0.95)
	_put_tone(b, 160.0, 0.6, "saw", 0.0, 0.35, 0.0, 0.5)
	_put_tone(b, 160.0, 0.6, "saw", 0.45, 0.35, 0.0, 0.5)
	bank["buzz"] = _wav(b)
	b = _empty(0.2)
	_put_tone(b, 1046.0, 0.6, "square", 0.0, 0.15, 0.0, 2.0)
	bank["beep1"] = _wav(b)
	b = _empty(1.1)
	_put_tone(b, 1046.0, 0.6, "square", 0.0, 0.15, 0.0, 2.0)
	_put_tone(b, 1046.0, 0.6, "square", 0.25, 0.15, 0.0, 2.0)
	_put_tone(b, 1046.0, 0.6, "square", 0.5, 0.35, 0.0, 2.0)
	bank["beep3"] = _wav(b)
	b = _empty(0.08)
	_put_tone(b, 520.0, 0.35, "square", 0.0, 0.05, 0.0, 8.0)
	bank["click"] = _wav(b)
	b = _empty(0.25)
	_put_tone(b, 660.0, 0.5, "tri", 0.0, 0.2, 880.0, 2.0)
	bank["pickup"] = _wav(b)
	b = _empty(0.4)
	_put_noise(b, 0.6, 0.0, 0.4, 0.0, false, 4.0)
	bank["static"] = _wav(b)
	# supermarket: PA chime, scanner, cash drawer
	b = _empty(0.8)
	_put_tone(b, 659.0, 0.5, "sine", 0.0, 0.3, 0.0, 2.0)
	_put_tone(b, 880.0, 0.5, "sine", 0.32, 0.4, 0.0, 2.0)
	_put_tone(b, 880.0, 0.15, "sine", 0.5, 0.3, 0.0, 2.0)
	bank["pa"] = _wav(b)
	b = _empty(0.16)
	_put_tone(b, 1568.0, 0.5, "square", 0.0, 0.1, 0.0, 6.0)
	_put_tone(b, 3136.0, 0.15, "sine", 0.0, 0.1, 0.0, 6.0)
	bank["scan"] = _wav(b)
	b = _empty(0.7)
	_put_tone(b, 659.0, 0.5, "square", 0.0, 0.12, 0.0, 4.0)
	_put_tone(b, 988.0, 0.5, "square", 0.13, 0.3, 0.0, 3.0)
	_put_noise(b, 0.25, 0.3, 0.3, 900.0, false, 3.0)
	bank["cash"] = _wav(b)
	# cat: meow, hiss, purr
	b = _empty(0.6)
	_put_tone(b, 550.0, 0.55, "saw", 0.0, 0.28, 950.0, 1.2)
	_put_tone(b, 950.0, 0.45, "saw", 0.28, 0.25, 420.0, 2.5)
	bank["meow"] = _wav(b)
	b = _empty(0.7)
	_put_noise(b, 0.7, 0.0, 0.6, 4500.0, true, 2.0)
	bank["hiss"] = _wav(b)
	b = _empty(1.6)
	for i in b.size():
		var t := float(i) / rate
		b[i] += sin(TAU * 92.0 * t) * 0.32 * (0.45 + 0.55 * absf(sin(TAU * 11.5 * t)))
	bank["purr"] = _wav(b)
	# sting
	b = _empty(1.2)
	for f in [110.0, 116.0, 233.0, 466.0, 932.0]:
		_put_tone(b, f, 0.28, "saw", 0.0, 1.1, 0.0, 3.0)
	_put_tone(b, 45.0, 0.9, "sine", 0.0, 0.8, 30.0, 3.0)
	bank["sting"] = _wav(b)
	# siren
	b = _empty(6.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / rate
		var f := 770.0 + 110.0 * sin(TAU * t / 1.8)
		phase += TAU * f / rate
		b[i] += asin(clampf(sin(phase), -1.0, 1.0)) * 0.6366 * 0.4
	_fade(b, 2.0, 0.5)
	bank["siren"] = _wav(b)
	# power
	b = _empty(0.7)
	_put_tone(b, 300.0, 0.4, "saw", 0.0, 0.65, 40.0, 0.8)
	bank["power_down"] = _wav(b)
	b = _empty(0.5)
	_put_tone(b, 80.0, 0.35, "saw", 0.0, 0.45, 320.0, 0.8)
	bank["power_up"] = _wav(b)
	# heartbeat (single double-thump, scheduled in _process)
	b = _empty(0.8)
	_put_tone(b, 55.0, 0.9, "sine", 0.0, 0.28, 35.0, 5.0)
	_put_tone(b, 52.0, 0.7, "sine", 0.42, 0.28, 35.0, 5.0)
	bank["heart"] = _wav(b)
	# wall clock (single ticks, scheduled in story.update like the heartbeat)
	b = _empty(0.09)
	_put_tone(b, 2100.0, 0.32, "square", 0.0, 0.025, 0.0, 9.0)
	_put_noise(b, 0.08, 0.0, 0.02, 4000.0, true, 9.0)
	bank["tick"] = _wav(b)
	b = _empty(0.09)
	_put_tone(b, 1700.0, 0.32, "square", 0.0, 0.025, 0.0, 9.0)
	_put_noise(b, 0.08, 0.0, 0.02, 4000.0, true, 9.0)
	bank["tock"] = _wav(b)
	# MJ easter egg: an ORIGINAL 8-second funk groove (E minor pocket).
	b = _mj_groove()
	_fade(b, 0.1, 0.6)
	bank["mj"] = _wav(b)
	# loops
	b = _empty(2.0)
	_put_noise(b, 0.5, 0.0, 2.0, 220.0, false, 0.0)
	_put_tone(b, 59.0, 0.06, "sine", 0.0, 2.0, 0.0, 0.0)
	bank["room_loop"] = _loop_wav(b)
	b = _empty(6.0) # R6: rain is low rumble + slow swell now, not white hiss
	_put_noise(b, 0.10, 0.0, 6.0, 480.0, false, 0.0)
	_put_noise(b, 0.07, 0.0, 6.0, 220.0, false, 0.0)
	for i in b.size():
		var t := float(i) / rate
		b[i] *= 0.7 + 0.3 * sin(TAU * t / 3.1 + 0.4) * sin(TAU * t / 5.3)
	bank["rain_loop"] = _loop_wav(b)
	b = _empty(16.0)
	var prog := [
		[110.0, 130.81, 164.81, 220.0], [87.31, 110.0, 130.81, 174.61],
		[98.0, 130.81, 164.81, 196.0], [98.0, 123.47, 146.83, 196.0],
	]
	for ci in 4:
		for f in (prog[ci] as Array):
			_put_tone(b, float(f), 0.05, "sine", float(ci) * 4.0, 4.0, 0.0, 0.0)
			_put_tone(b, float(f) * 1.003, 0.03, "sine", float(ci) * 4.0, 4.0, 0.0, 0.0)
		_put_tone(b, float((prog[ci] as Array)[0]) * 0.5, 0.07, "sine", float(ci) * 4.0, 4.0, 0.0, 0.0)
	for i in b.size():
		var t := float(i) / rate
		var pc := fmod(t, 4.0) / 4.0
		b[i] *= sin(PI * pc) * (0.9 + 0.1 * sin(TAU * t / 16.0))
	bank["music_loop"] = _loop_wav(b)
	b = _empty(1.0)
	_put_noise(b, 0.3, 0.0, 1.0, 400.0, true, 0.0)
	bank["tv_loop"] = _loop_wav(b)
	b = _empty(1.0)
	_put_tone(b, 120.0, 0.16, "sine", 0.0, 1.0, 0.0, 0.0)
	_put_tone(b, 240.0, 0.06, "sine", 0.0, 1.0, 0.0, 0.0)
	_put_tone(b, 360.0, 0.03, "sine", 0.0, 1.0, 0.0, 0.0)
	bank["hum_loop"] = _loop_wav(b)
	b = _empty(3.0)
	_put_noise(b, 0.28, 0.0, 3.0, 900.0, false, 0.0)
	_put_noise(b, 0.12, 0.0, 3.0, 2400.0, true, 0.0)
	for i in b.size():
		var t := float(i) / rate
		b[i] *= 0.45 + 0.55 * (0.5 + 0.5 * sin(TAU * t / 1.7)) * (0.5 + 0.5 * sin(TAU * t / 0.9 + 1.3))
	bank["whisper_loop"] = _loop_wav(b)
	b = _empty(6.0)
	_put_tone(b, 41.2, 0.5, "sine", 0.0, 6.0, 0.0, 0.0)
	_put_tone(b, 43.7, 0.4, "sine", 0.0, 6.0, 0.0, 0.0)
	_put_tone(b, 110.0, 0.12, "saw", 0.0, 6.0, 0.0, 0.0)
	_put_noise(b, 0.1, 0.0, 6.0, 240.0, false, 0.0)
	for i in b.size():
		var t := float(i) / rate
		b[i] *= 0.6 + 0.4 * (0.5 + 0.5 * sin(TAU * t / 5.3)) * (0.5 + 0.5 * sin(TAU * t / 7.7 + 2.0))
	bank["drone_loop"] = _loop_wav(b)
	b = _empty(3.0)
	_put_noise(b, 0.32, 0.0, 3.0, 3400.0, true, 0.0)
	_put_noise(b, 0.2, 0.0, 3.0, 900.0, false, 0.0)
	for i in b.size():
		var t := float(i) / rate
		b[i] *= 0.8 + 0.2 * sin(TAU * t / 0.7 + 1.1) * sin(TAU * t / 2.3)
	bank["shower_loop"] = _loop_wav(b)
	# R4: stalk loop — a low breathing rumble, 2 breath cycles per 8 s loop.
	b = _empty(8.0)
	_put_noise(b, 0.5, 0.0, 8.0, 90.0, false, 0.0)
	_put_tone(b, 55.0, 0.3, "sine", 0.0, 8.0, 0.0, 0.0)
	_put_tone(b, 110.0, 0.08, "sine", 0.0, 8.0, 0.0, 0.0)
	for i in b.size():
		var t := float(i) / rate
		var br := 0.5 + 0.5 * sin(TAU * t / 4.0)
		b[i] *= 0.3 + 0.7 * br * br
	bank["stalk_loop"] = _loop_wav(b)
	# R5: sub-bass threat weight (spec §3: 30-60 Hz, threat-only).
	b = _empty(8.0)
	_put_tone(b, 41.0, 0.5, "sine", 0.0, 8.0, 0.0, 0.0)
	_put_tone(b, 47.0, 0.4, "sine", 0.0, 8.0, 0.0, 0.0)
	_put_tone(b, 55.0, 0.25, "sine", 0.0, 8.0, 0.0, 0.0)
	for i in b.size():
		var t := float(i) / rate
		b[i] *= 0.5 + 0.5 * (0.5 + 0.5 * sin(TAU * t / 8.0))
	bank["subbass_loop"] = _loop_wav(b)
	# R5: rain-on-glass patter (near-window indoor layer) + night wind bed.
	b = _empty(6.0)
	_put_noise(b, 0.13, 0.0, 6.0, 1700.0, true, 0.0)
	_put_noise(b, 0.07, 0.0, 6.0, 600.0, false, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for d in 16:
		var at := rng.randf() * 6.0
		_put_tone(b, rng.randf_range(1200.0, 2400.0), 0.035, "sine", at, 0.06, 0.0, 30.0)
	bank["glassrain_loop"] = _loop_wav(b)
	b = _empty(12.0)
	_put_noise(b, 0.14, 0.0, 12.0, 300.0, false, 0.0)
	for i in b.size():
		var t := float(i) / rate
		b[i] *= 0.6 + 0.4 * sin(TAU * t / 12.0 + 1.0) * sin(TAU * t / 5.0)
	bank["night_loop"] = _loop_wav(b)


func _mj_groove() -> PackedFloat32Array:
	# Original funk pocket: E minor, 112 BPM, kick/snare/hats + busy bass + stabs.
	var b := _empty(8.0)
	var step := 60.0 / 112.0 / 4.0
	var e2 := 82.41
	var bass_pat := [0, -1, 0, 0, 3, -1, 0, -1, 5, -1, 3, 0, 2, -1, 1, 2]
	var n_steps := int(8.0 / step)
	for s in n_steps:
		var t := s * step
		var st := s % 16
		if st == 0 or st == 7 or st == 8 or st == 10:
			_put_tone(b, 120.0, 0.85, "sine", t, 0.12, 45.0, 8.0)
		if st == 4 or st == 12:
			_put_noise(b, 0.4, t, 0.09, 1800.0, true, 9.0)
			_put_tone(b, 190.0, 0.4, "tri", t, 0.08, 140.0, 9.0)
		if st % 2 == 0:
			_put_noise(b, 0.12 if st % 4 == 2 else 0.2, t, 0.04, 6000.0, true, 12.0)
		var bn: int = bass_pat[st]
		if bn >= 0:
			var bf: float = e2 * pow(2.0, bn / 12.0)
			_put_tone(b, bf, 0.5, "square", t, step * 0.9, 0.0, 4.0)
			_put_tone(b, bf * 0.5, 0.35, "sine", t, step * 0.9, 0.0, 4.0)
		if st == 2 or st == 11:
			for cf in [164.81, 196.0, 246.94, 293.66]:
				_put_tone(b, cf, 0.1, "square", t, 0.09, 0.0, 10.0)
		if s % 32 == 30:
			_put_tone(b, 1318.0, 0.12, "sine", t, 0.12, 1760.0, 6.0)
	return b


# ---------- playback ----------
func _free2d() -> AudioStreamPlayer:
	# R4: never cut a playing voice while an idle one exists (kills the pops).
	for p in pool2d:
		if not p.playing:
			return p
	var p := pool2d[i2d]
	i2d = (i2d + 1) % pool2d.size()
	return p


func _free3d(pool: Array[AudioStreamPlayer3D]) -> AudioStreamPlayer3D:
	for p in pool:
		if not p.playing:
			return p
	var p := pool[i3d % pool.size()]
	i3d = (i3d + 1) % pool.size()
	return p


func _play2d(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not bank.has(sound):
		return
	var p := _free2d()
	p.stream = bank[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func _play3d(sound: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	if not bank.has(sound):
		return
	# R4: walls muffle — occluded sounds route to the lowpassed pool.
	var p := _free3d(pool3d_muf if _occluded(pos) else pool3d)
	p.global_position = pos
	p.stream = bank[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func _occluded(pos: Vector3) -> bool:
	if listener == null:
		return false
	var from: Vector3 = listener.global_position + Vector3(0, 1.6, 0)
	var to := Vector3(pos.x, 1.2 if pos.y < 0.5 else pos.y, pos.z)
	var q := PhysicsRayQueryParameters3D.create(from, to, 3, occlude_excludes)
	return not get_tree().root.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _process(delta: float) -> void:
	if duck_t > 0.0:
		duck_t -= delta
		if duck_t <= 0.0:
			_restore_mix()
	if fridge_player.playing:
		fridge_player.bus = "Muffled" if _occluded(fridge_player.global_position) else "SFX"
	if tv_player.playing: # R5: the TV muffles through walls, live
		tv_player.bus = "Muffled" if _occluded(tv_player.global_position) else "SFX"
	if heart_on:
		heart_t -= delta
		if heart_t <= 0.0:
			heart_t = 0.62 if heart_fast else 0.95
			heart_player.stream = bank["heart"]
			heart_player.play()


# ---------- public API ----------
func start_ambience() -> void:
	if not room_player.playing:
		room_player.stream = bank["room_loop"]
		room_player.volume_db = -14.0
		room_player.play()


func start_rain() -> void:
	rain_on = true
	if not rain_player.playing:
		rain_player.stream = bank["rain_loop"]
		rain_player.volume_db = -19.0
		rain_player.play()
	else:
		set_rain_level(1.0)


func start_music() -> void:
	if not music_player.playing:
		music_player.stream = bank["music_loop"]
		music_player.volume_db = -17.0
		music_player.play()


func stop_rain() -> void:
	rain_on = false
	rain_player.stop()


func set_rain_level(x: float, muffle := false) -> void:
	if rain_player.playing:
		rain_player.volume_db = lerpf(-44.0, -24.0, clampf(x, 0.0, 1.0)) # R6: storms breathe, they don't scream
		rain_player.bus = "Muffled" if muffle else "SFX"


func set_shower(on: bool) -> void:
	if on and not shower_player.playing:
		shower_player.stream = bank["shower_loop"]
		shower_player.volume_db = -13.0
		shower_player.play()
	elif not on:
		shower_player.stop()


func thunder() -> void:
	_play2d("thunder", randf_range(-4.0, 1.0), randf_range(0.9, 1.1))
	cue("[thunder rumbles]")


func set_tv(on: bool) -> void:
	if on and not tv_player.playing:
		tv_player.stream = bank["tv_loop"]
		tv_player.volume_db = -8.0
		tv_player.play()
	elif not on:
		tv_player.stop()


func set_hum(on: bool) -> void:
	if on and not hum_player.playing:
		hum_player.stream = bank["hum_loop"]
		hum_player.volume_db = -22.0
		hum_player.play()
	elif not on:
		hum_player.stop()
	# R5: the fridge is a PLACE now — hum swells as you near the kitchen.
	if on and not fridge_player.playing:
		fridge_player.stream = bank["hum_loop"]
		fridge_player.volume_db = -10.0
		fridge_player.play()
	elif not on:
		fridge_player.stop()


func set_whisper(on: bool) -> void:
	if on and not whisper_player.playing:
		whisper_player.stream = bank["whisper_loop"]
		whisper_player.volume_db = -20.0
		whisper_player.play()
	elif not on:
		whisper_player.stop()


func set_heart(on: bool, fast := false) -> void:
	heart_on = on
	heart_fast = fast


func tick_at(pos: Vector3, alt: bool) -> void:
	_play3d("tock" if alt else "tick", pos, -6.0, 1.0)


func step_at(pos: Vector3, run: bool) -> void:
	_play3d("step_run" if run else "step_walk", pos, -1.0 if run else -6.0, randf_range(0.9, 1.1))


func clatter(pos: Vector3) -> void:
	_play3d("shut", pos, -4.0, 0.7)


func footstep_surf(run: bool, crouch: bool, surf: String) -> void:
	var s := "step_walk"
	var db := 0.0
	if run:
		s = "step_run"
	elif crouch:
		s = "step_crouch"
		db = -4.0
	elif surf != "wood":
		s = "step_" + surf if bank.has("step_" + surf) else "step_walk"
		if surf == "carpet":
			db = -5.0
		elif surf == "grass":
			db = -3.0
	_play2d(s, db, randf_range(0.92, 1.08))


func door_creak(open: bool) -> void:
	_play2d("creak_open" if open else "creak_close", -4.0, randf_range(0.95, 1.05))


func door_shut_at(pos: Vector3) -> void:
	_play3d("shut", pos, 0.0)


func locked() -> void:
	_play2d("locked", 0.0)


func knock_at(pos: Vector3, kind := "soft3") -> void:
	_play3d("knock_soft" if kind == "soft3" else ("knock_heavy" if kind == "heavy3" else ("knock2" if kind == "heavy2" else "knock1")), pos, 2.0)
	cue("[knocking]")


func glass_at(pos: Vector3) -> void:
	_play3d("glass", pos, 2.0)
	cue("[glass shatters]")


func text_ding() -> void:
	_play2d("ding", 0.0)


func phone_buzz() -> void:
	_play2d("buzz", 0.0)
	cue("[phone buzzing]")


func microwave_beep(final := false) -> void:
	_play2d("beep3" if final else "beep1", 0.0)
	if final:
		cue("[microwave beeps]")


func sting() -> void:
	_play2d("sting", 0.0)


func siren() -> void:
	_play2d("siren", 2.0)
	cue("[sirens wail outside]")


func power_down() -> void:
	_play2d("power_down", 0.0)
	cue("[the power dies]")


func power_up() -> void:
	_play2d("power_up", 0.0)
	cue("[the power hums back]")


func ui_click() -> void:
	_play2d("click", 0.0)


func pickup() -> void:
	_play2d("pickup", 0.0)


func static_burst() -> void:
	_play2d("static", -2.0)


func pa() -> void:
	_play2d("pa", -2.0)


func scan() -> void:
	_play2d("scan", 0.0, randf_range(0.97, 1.03))


func cash() -> void:
	_play2d("cash", 0.0)


func meow_at(pos: Vector3) -> void:
	_play3d("meow", pos, -2.0, randf_range(0.9, 1.15))


func hiss() -> void:
	_play2d("hiss", 2.0)


func purr() -> void:
	_play2d("purr", 0.0)


func mj_groove() -> void:
	mj_player.stream = bank["mj"]
	mj_player.volume_db = -2.0
	mj_player.play()


func mj_stop() -> void:
	mj_player.stop()


func set_drone(on: bool) -> void:
	if on and not drone_player.playing:
		drone_player.stream = bank["drone_loop"]
		drone_player.volume_db = -16.0
		drone_player.play()
	elif not on:
		drone_player.stop()


func voice(id: String, db := 0.0) -> void:
	if not vox.has(id):
		var p := "res://assets/vox/%s.mp3" % id
		if not ResourceLoader.exists(p):
			return
		vox[id] = ResourceLoader.load(p)
	voice_player.stream = vox[id] # R4: dedicated Voice-bus player — one voice at a time
	voice_player.volume_db = db
	voice_player.pitch_scale = 1.0
	voice_player.play()
