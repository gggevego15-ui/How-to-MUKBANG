extends Node
## Lightweight procedural restaurant ambience. All sounds are generated locally for Android.

const SAMPLE_RATE := 22050
const LOOP_SECONDS := 4.0

var _players: Array[AudioStreamPlayer3D] = []
var _rng := RandomNumberGenerator.new()
var _master_enabled := true

func _ready() -> void:
	_rng.randomize()
	# Positions match the mall's coordinate system: counters are along the north side.
	_add_loop("VisitorsMurmur", "visitors", -24.0, Vector3(0.0, 1.8, -2.0), 42.0)
	_add_loop("KitchenSizzle", "kitchen", -23.0, Vector3(-38.0, 1.8, -38.0), 32.0)
	_add_loop("DishesAndCutlery", "dishes", -26.0, Vector3(-5.0, 1.5, -34.0), 27.0)
	_add_loop("CashRegister", "register", -28.0, Vector3(39.0, 1.5, -36.0), 24.0)

func _add_loop(label: String, kind: String, volume: float, source_position: Vector3, audible_range: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = label
	player.stream = _make_loop(kind)
	player.volume_db = volume
	player.bus = "Master"
	player.position = source_position
	player.max_distance = audible_range
	player.unit_size = 8.0
	player.panning_strength = 1.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.max_db = 3.0
	add_child(player)
	_players.append(player)
	player.play()

func set_ambience_enabled(enabled: bool) -> void:
	_master_enabled = enabled
	for player in _players:
		player.stream_paused = not enabled

func set_ambience_volume(volume_db: float) -> void:
	for player in _players:
		player.volume_db = volume_db

func set_layer_volume(layer_name: String, volume_db: float) -> void:
	for player in _players:
		if player.name == layer_name:
			player.volume_db = volume_db
			return

func _make_loop(kind: String) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * LOOP_SECONDS)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var phase := _rng.randf_range(0.0, TAU)
	var phase2 := _rng.randf_range(0.0, TAU)
	var pulses: Array[float] = []
	for i in range(12):
		pulses.append(_rng.randf_range(0.15, LOOP_SECONDS - 0.25))
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var noise := _rng.randf_range(-1.0, 1.0)
		var value := 0.0
		match kind:
			"visitors":
				# Distant, nonverbal crowd murmur; no intelligible speech.
				var swell := 0.58 + 0.24 * sin(TAU * 0.31 * t + phase) + 0.12 * sin(TAU * 0.17 * t + phase2)
				var voices := sin(TAU * 178.0 * t + phase) * 0.20 + sin(TAU * 231.0 * t + phase2) * 0.13
				value = (noise * 0.26 + voices) * swell
			"kitchen":
				# Soft continuous sizzling with slow intensity movement.
				var swell := 0.55 + 0.35 * sin(TAU * 0.42 * t + phase)
				value = noise * 0.48 * swell + sin(TAU * 93.0 * t + phase2) * 0.07
			"dishes":
				# Small glass/ceramic clinks spaced irregularly across the loop.
				for pulse in pulses:
					var age := t - pulse
					if age >= 0.0 and age < 0.22:
						value += sin(TAU * (1150.0 + 240.0 * sin(age * 32.0)) * age) * exp(-age * 21.0) * 0.38
				value += noise * 0.018
			"register":
				# Two short checkout beeps, repeated every four-second ambience loop.
				var local := fposmod(t + 0.3, LOOP_SECONDS)
				var beep_a := local >= 1.10 and local < 1.22
				var beep_b := local >= 1.28 and local < 1.42
				if beep_a:
					value = sin(TAU * 1046.5 * t) * 0.36 * minf((local - 1.10) / 0.012, 1.0) * minf((1.22 - local) / 0.018, 1.0)
				elif beep_b:
					value = sin(TAU * 1318.5 * t) * 0.32 * minf((local - 1.28) / 0.012, 1.0) * minf((1.42 - local) / 0.02, 1.0)
		value = clampf(value, -0.8, 0.8)
		pcm.encode_s16(i * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
