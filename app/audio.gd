## Procedural audio service. All tones are synthesized at runtime, so the
## project ships without binary sound assets. Three buses keep master, music
## and interface volumes independent.
extends Node

const SAMPLE_RATE := 22050
const SFX_VOICES := 8

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_index := 0
var _music: AudioStreamPlayer = null
var _built := false
var _master := 0.8
var _music_volume := 0.22
var _sfx_volume := 0.75
var _muted := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_ensure_buses()
	_build()
	_apply_volumes()


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.stream = null
	for player in _voices:
		player.stop()
		player.stream = null
	_streams.clear()
	_voices.clear()


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func _build() -> void:
	_streams["click"] = _tone(760.0, 0.045, 0.10, 0.002, 0.035)
	_streams["fill"] = _sequence([
		{"freq": 620.0, "start": 0.0, "duration": 0.07, "volume": 0.16},
		{"freq": 880.0, "start": 0.06, "duration": 0.11, "volume": 0.16},
	])
	_streams["reject"] = _tone(150.0, 0.20, 0.16, 0.005, 0.18)
	_streams["day_close"] = _sequence([
		{"freq": 523.25, "start": 0.0, "duration": 0.16, "volume": 0.12},
		{"freq": 659.25, "start": 0.13, "duration": 0.16, "volume": 0.12},
		{"freq": 783.99, "start": 0.26, "duration": 0.24, "volume": 0.12},
	])
	_streams["achievement"] = _sequence([
		{"freq": 523.25, "start": 0.0, "duration": 0.12, "volume": 0.14},
		{"freq": 659.25, "start": 0.10, "duration": 0.12, "volume": 0.14},
		{"freq": 783.99, "start": 0.20, "duration": 0.12, "volume": 0.14},
		{"freq": 1046.50, "start": 0.30, "duration": 0.28, "volume": 0.14},
	])
	_streams["promotion"] = _sequence([
		{"freq": 392.00, "start": 0.0, "duration": 0.18, "volume": 0.14},
		{"freq": 523.25, "start": 0.15, "duration": 0.18, "volume": 0.14},
		{"freq": 659.25, "start": 0.30, "duration": 0.18, "volume": 0.14},
		{"freq": 783.99, "start": 0.45, "duration": 0.34, "volume": 0.14},
	])
	_streams["margin_call"] = _sequence([
		{"freq": 220.0, "start": 0.0, "duration": 0.22, "volume": 0.17},
		{"freq": 174.61, "start": 0.24, "duration": 0.22, "volume": 0.17},
		{"freq": 220.0, "start": 0.48, "duration": 0.28, "volume": 0.17},
	])
	_streams["story"] = _sequence([
		{"freq": 440.0, "start": 0.0, "duration": 0.12, "volume": 0.09},
		{"freq": 554.37, "start": 0.10, "duration": 0.18, "volume": 0.09},
	])
	for index in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_voices.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = _build_ambient_loop()
	add_child(_music)
	_built = true


## One note with a short attack and a smooth release. The second harmonic keeps
## the synthesized clicks from sounding like pure test tones.
func _tone(freq: float, duration: float, volume: float,
		attack: float = 0.004, release: float = 0.05) -> AudioStreamWAV:
	var count := maxi(1, int(SAMPLE_RATE * duration))
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in count:
		var time := float(index) / float(SAMPLE_RATE)
		var attack_gain := clampf(time / maxf(0.0001, attack), 0.0, 1.0)
		var release_gain := clampf((duration - time) / maxf(0.0001, release), 0.0, 1.0)
		var envelope := attack_gain * release_gain
		var sample := sin(TAU * freq * time) * 0.78
		sample += sin(TAU * freq * 2.0 * time) * 0.22
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data[index * 2] = value & 0xFF
		data[index * 2 + 1] = (value >> 8) & 0xFF
	return _wav(data, count, false)


## Mixes several notes into one SFX stream so a player only needs one voice.
func _sequence(notes: Array) -> AudioStreamWAV:
	var total := 0.01
	for note in notes:
		total = maxf(total, float(note["start"]) + float(note["duration"]))
	var count := maxi(1, int(SAMPLE_RATE * total))
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	for note in notes:
		var freq := float(note["freq"])
		var start := float(note["start"])
		var duration := float(note["duration"])
		var volume := float(note["volume"])
		var first := int(SAMPLE_RATE * start)
		var note_count := int(SAMPLE_RATE * duration)
		for offset in note_count:
			var index := first + offset
			if index < 0 or index >= count:
				continue
			var time := float(offset) / float(SAMPLE_RATE)
			var envelope := clampf(time / 0.004, 0.0, 1.0) \
				* clampf((duration - time) / 0.04, 0.0, 1.0)
			var sample := sin(TAU * freq * time) * 0.78
			sample += sin(TAU * freq * 2.0 * time) * 0.22
			buffer[index] += sample * envelope * volume
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in count:
		var value := int(clampf(buffer[index], -1.0, 1.0) * 32767.0)
		data[index * 2] = value & 0xFF
		data[index * 2 + 1] = (value >> 8) & 0xFF
	return _wav(data, count, false)


## Eight-second ambient loop: four soft chords with gaps, low enough to sit
## under the interface without competing with it.
func _build_ambient_loop() -> AudioStreamWAV:
	var duration := 8.0
	var count := int(SAMPLE_RATE * duration)
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	var chords := [
		[220.00, 261.63, 329.63],
		[174.61, 220.00, 261.63],
		[261.63, 329.63, 392.00],
		[196.00, 246.94, 293.66],
	]
	for chord_index in chords.size():
		var chord: Array = chords[chord_index]
		var start := float(chord_index) * 2.0
		var note_duration := 1.75
		var first := int(SAMPLE_RATE * start)
		var note_count := int(SAMPLE_RATE * note_duration)
		for offset in note_count:
			var index := first + offset
			if index < 0 or index >= count:
				continue
			var time := float(offset) / float(SAMPLE_RATE)
			var envelope := clampf(time / 0.35, 0.0, 1.0) \
				* clampf((note_duration - time) / 0.45, 0.0, 1.0)
			var sample := 0.0
			for freq in chord:
				sample += sin(TAU * float(freq) * time)
				sample += sin(TAU * float(freq) * 2.0 * time) * 0.12
			buffer[index] += sample * envelope * 0.018
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in count:
		var value := int(clampf(buffer[index], -1.0, 1.0) * 32767.0)
		data[index * 2] = value & 0xFF
		data[index * 2 + 1] = (value >> 8) & 0xFF
	return _wav(data, count, true)


func _wav(data: PackedByteArray, sample_count: int, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream


func apply_settings(settings: Dictionary) -> void:
	_master = clampf(float(settings.get("masterVolume", 0.8)), 0.0, 1.0)
	_music_volume = clampf(float(settings.get("musicVolume", 0.22)), 0.0, 1.0)
	_sfx_volume = clampf(float(settings.get("sfxVolume", 0.75)), 0.0, 1.0)
	_muted = bool(settings.get("muted", false))
	if not _built:
		return
	_apply_volumes()
	if _music == null:
		return
	if _muted or _music_volume <= 0.0:
		_music.stop()
	elif not _music.playing:
		_music.play()


func _apply_volumes() -> void:
	var master_db := linear_to_db(maxf(0.0001, _master)) if not _muted else -80.0
	AudioServer.set_bus_volume_db(0, master_db)
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(0.0001, _music_volume)))
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(0.0001, _sfx_volume)))


func play(sound: String) -> void:
	if not _built or _voices.is_empty():
		return
	var stream: Variant = _streams.get(sound, null)
	if stream == null:
		return
	var player := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	player.stream = stream
	player.play()


func play_click() -> void:
	play("click")
