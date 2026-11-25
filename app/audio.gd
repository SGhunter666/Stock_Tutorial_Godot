## Procedural audio service. Synthesizes both calm modern ambient pads and
## authentic 16-bit PC-98 FM / pulse / triangle chiptune BGM loops + arcade SFX
## at runtime without external binary audio assets.
extends Node

const SAMPLE_RATE := 22050
const SFX_VOICES := 8

var _streams: Dictionary = {}
var _bgm_cache: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_index := 0
var _music: AudioStreamPlayer = null
var _current_mood := ""
var _built := false
var _master := 0.8
var _music_volume := 0.22
var _sfx_volume := 0.75
var _muted := false


static func resolve_mood(is_pixel: bool, started: bool, paused: bool,
		crisis: bool, screen: String) -> String:
	if not is_pixel:
		return "ambient"
	if crisis:
		return "pixel_crisis"
	if not started or paused or screen in ["academy", "story", "glossary", "settings", "replay"]:
		return "pixel_calm"
	return "pixel_session"


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
	_bgm_cache.clear()
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
	_streams["pixel_click"] = _chip_sequence([
		{"freq": 1046.50, "start": 0.0, "duration": 0.018, "volume": 0.11, "wave": "pulse"},
		{"freq": 659.25, "start": 0.016, "duration": 0.024, "volume": 0.09, "wave": "pulse"},
	])
	_streams["pixel_coin"] = _chip_sequence([
		{"freq": 987.77, "start": 0.0, "duration": 0.055, "volume": 0.15, "wave": "pulse"},
		{"freq": 1318.51, "start": 0.05, "duration": 0.16, "volume": 0.16, "wave": "pulse"},
	])
	_streams["pixel_coffee"] = _chip_sequence([
		{"freq": 523.25, "start": 0.0, "duration": 0.05, "volume": 0.11, "wave": "tri"},
		{"freq": 659.25, "start": 0.045, "duration": 0.05, "volume": 0.11, "wave": "tri"},
		{"freq": 783.99, "start": 0.09, "duration": 0.09, "volume": 0.12, "wave": "fm"},
	])
	_streams["fill"] = _sequence([
		{"freq": 620.0, "start": 0.0, "duration": 0.07, "volume": 0.16},
		{"freq": 880.0, "start": 0.06, "duration": 0.11, "volume": 0.16},
	])
	_streams["reject"] = _tone(150.0, 0.20, 0.16, 0.005, 0.18)
	_streams["day_close"] = _chip_sequence([
		{"freq": 523.25, "start": 0.0, "duration": 0.14, "volume": 0.13, "wave": "fm"},
		{"freq": 659.25, "start": 0.12, "duration": 0.14, "volume": 0.13, "wave": "fm"},
		{"freq": 783.99, "start": 0.24, "duration": 0.24, "volume": 0.14, "wave": "fm"},
	])
	_streams["achievement"] = _chip_sequence([
		{"freq": 523.25, "start": 0.0, "duration": 0.10, "volume": 0.14, "wave": "pulse"},
		{"freq": 659.25, "start": 0.09, "duration": 0.10, "volume": 0.14, "wave": "pulse"},
		{"freq": 783.99, "start": 0.18, "duration": 0.10, "volume": 0.14, "wave": "pulse"},
		{"freq": 1046.50, "start": 0.27, "duration": 0.28, "volume": 0.15, "wave": "fm"},
	])
	_streams["promotion"] = _chip_sequence([
		{"freq": 392.00, "start": 0.0, "duration": 0.14, "volume": 0.14, "wave": "pulse"},
		{"freq": 523.25, "start": 0.13, "duration": 0.14, "volume": 0.14, "wave": "pulse"},
		{"freq": 659.25, "start": 0.26, "duration": 0.14, "volume": 0.14, "wave": "pulse"},
		{"freq": 783.99, "start": 0.39, "duration": 0.32, "volume": 0.16, "wave": "fm"},
	])
	_streams["margin_call"] = _sequence([
		{"freq": 220.0, "start": 0.0, "duration": 0.22, "volume": 0.17},
		{"freq": 174.61, "start": 0.24, "duration": 0.22, "volume": 0.17},
		{"freq": 220.0, "start": 0.48, "duration": 0.28, "volume": 0.17},
	])
	_streams["story"] = _chip_sequence([
		{"freq": 440.0, "start": 0.0, "duration": 0.10, "volume": 0.10, "wave": "fm"},
		{"freq": 554.37, "start": 0.09, "duration": 0.16, "volume": 0.10, "wave": "fm"},
	])
	_streams["alert"] = _chip_sequence([
		{"freq": 880.0, "start": 0.0, "duration": 0.08, "volume": 0.14, "wave": "pulse"},
		{"freq": 1174.66, "start": 0.09, "duration": 0.15, "volume": 0.14, "wave": "pulse"},
	])
	_streams["quiz_pass"] = _chip_sequence([
		{"freq": 587.33, "start": 0.0, "duration": 0.10, "volume": 0.13, "wave": "pulse"},
		{"freq": 739.99, "start": 0.09, "duration": 0.10, "volume": 0.13, "wave": "pulse"},
		{"freq": 880.00, "start": 0.18, "duration": 0.22, "volume": 0.14, "wave": "fm"},
	])
	_streams["quiz_fail"] = _sequence([
		{"freq": 329.63, "start": 0.0, "duration": 0.14, "volume": 0.13},
		{"freq": 261.63, "start": 0.13, "duration": 0.22, "volume": 0.13},
	])
	_streams["crisis_alarm"] = _sequence([
		{"freq": 196.00, "start": 0.0, "duration": 0.24, "volume": 0.16},
		{"freq": 185.00, "start": 0.26, "duration": 0.28, "volume": 0.16},
	])
	for index in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_voices.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_built = true
	set_music_mood("pixel_calm" if SmaUiTheme.is_pixel() else "ambient")


func _osc(phase: float, wave: String) -> float:
	var p := fposmod(phase, 1.0)
	match wave:
		"pulse":
			return 0.72 if p < 0.25 else -0.28
		"tri":
			return 4.0 * absf(p - 0.5) - 1.0
		"fm":
			return sin(TAU * p + 1.15 * sin(TAU * 2.0 * p))
		_:
			return sin(TAU * p) * 0.78 + sin(TAU * 2.0 * p) * 0.22


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
		var sample := sin(TAU * freq * time) * 0.78 + sin(TAU * freq * 2.0 * time) * 0.22
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data[index * 2] = value & 0xFF
		data[index * 2 + 1] = (value >> 8) & 0xFF
	return _wav(data, count, false)


func _sequence(notes: Array) -> AudioStreamWAV:
	return _chip_sequence(notes)


func _chip_sequence(notes: Array) -> AudioStreamWAV:
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
		var wave := String(note.get("wave", "sine"))
		var first := int(SAMPLE_RATE * start)
		var note_count := int(SAMPLE_RATE * duration)
		for offset in note_count:
			var index := first + offset
			if index < 0 or index >= count:
				continue
			var time := float(offset) / float(SAMPLE_RATE)
			var envelope := clampf(time / 0.003, 0.0, 1.0) \
				* clampf((duration - time) / 0.035, 0.0, 1.0)
			buffer[index] += _osc(freq * time, wave) * envelope * volume
	return _pack_buffer(buffer, true if false else false)


func _pack_buffer(buffer: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var count := buffer.size()
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in count:
		var value := int(clampf(buffer[index], -1.0, 1.0) * 32767.0)
		data[index * 2] = value & 0xFF
		data[index * 2 + 1] = (value >> 8) & 0xFF
	return _wav(data, count, looped)


func _get_bgm_stream(mood: String) -> AudioStreamWAV:
	if _bgm_cache.has(mood):
		return _bgm_cache[mood]
	var stream: AudioStreamWAV
	match mood:
		"pixel_session":
			stream = _build_pixel_session_loop()
		"pixel_calm":
			stream = _build_pixel_calm_loop()
		"pixel_crisis":
			stream = _build_pixel_crisis_loop()
		_:
			stream = _build_ambient_loop()
	_bgm_cache[mood] = stream
	return stream


func _mix_note(buffer: PackedFloat32Array, freq: float, start: float, duration: float,
		vol: float, wave: String, attack: float = 0.008, release: float = 0.08) -> void:
	if freq <= 0.0:
		return
	var total := buffer.size()
	var first := int(SAMPLE_RATE * start)
	var n := int(SAMPLE_RATE * duration)
	for i in n:
		var idx := first + i
		if idx < 0 or idx >= total:
			continue
		var t := float(i) / float(SAMPLE_RATE)
		var env := clampf(t / maxf(0.001, attack), 0.0, 1.0) \
			* clampf((duration - t) / maxf(0.001, release), 0.0, 1.0)
		buffer[idx] += _osc(freq * t, wave) * env * vol


## Upbeat 9.6s PC-98 / Kairosoft trading-floor FM + walking-bass loop (4 bars @ 100 BPM).
func _build_pixel_session_loop() -> AudioStreamWAV:
	var step := 0.15 # 16th-note swing grid, 64 steps = 9.6s
	var duration := step * 64.0
	var buffer := PackedFloat32Array()
	buffer.resize(int(SAMPLE_RATE * duration))
	# Progression: Fmaj7 -> Em7 -> Dm7 -> G7 / Cmaj7
	var chords := [
		[174.61, 220.00, 261.63, 329.63],
		[164.81, 196.00, 246.94, 293.66],
		[146.83, 174.61, 220.00, 261.63],
		[196.00, 246.94, 293.66, 392.00],
	]
	var bass_steps := [
		87.31, 0.0, 110.00, 130.81, 87.31, 0.0, 130.81, 110.00,
		82.41, 0.0, 98.00, 123.47, 82.41, 0.0, 123.47, 98.00,
		73.42, 0.0, 87.31, 110.00, 73.42, 0.0, 110.00, 130.81,
		98.00, 0.0, 123.47, 146.83, 130.81, 0.0, 98.00, 110.00,
	]
	var lead_melody := [
		523.25, 0.0, 659.25, 587.33, 523.25, 0.0, 440.00, 523.25,
		493.88, 0.0, 587.33, 523.25, 493.88, 392.00, 440.00, 0.0,
		440.00, 523.25, 587.33, 0.0, 659.25, 587.33, 523.25, 440.00,
		392.00, 493.88, 587.33, 659.25, 523.25, 0.0, 392.00, 0.0,
	]
	for bar in 4:
		var chord: Array = chords[bar]
		for hit in [0, 6, 10]:
			var st := float(bar * 16 + hit) * step
			for f in chord:
				_mix_note(buffer, float(f), st, step * 3.6, 0.022, "fm", 0.01, 0.18)
	for i in 32:
		var st := float(i * 2) * step
		_mix_note(buffer, float(bass_steps[i]), st, step * 1.7, 0.055, "tri", 0.005, 0.06)
		_mix_note(buffer, float(lead_melody[i]), st, step * 1.5, 0.028, "pulse", 0.004, 0.05)
	return _pack_buffer(buffer, true)


## Calm 12.8s PC-98 night observatory FM Rhodes lounge loop for Start / Academy / Story.
func _build_pixel_calm_loop() -> AudioStreamWAV:
	var duration := 12.8
	var buffer := PackedFloat32Array()
	buffer.resize(int(SAMPLE_RATE * duration))
	var chords := [
		[220.00, 261.63, 329.63, 392.00],
		[174.61, 220.00, 261.63, 329.63],
		[196.00, 246.94, 293.66, 392.00],
		[164.81, 220.00, 246.94, 329.63],
	]
	var bells := [659.25, 587.33, 523.25, 783.99, 659.25, 523.25, 587.33, 493.88]
	for bi in 4:
		var b_start := float(bi) * 3.2
		var c: Array = chords[bi]
		_mix_note(buffer, float(c[0]) * 0.5, b_start, 3.0, 0.042, "tri", 0.04, 0.5)
		for f in c:
			_mix_note(buffer, float(f), b_start, 3.05, 0.020, "fm", 0.12, 0.7)
		_mix_note(buffer, float(bells[bi * 2]), b_start + 0.4, 1.1, 0.022, "pulse", 0.01, 0.35)
		_mix_note(buffer, float(bells[bi * 2 + 1]), b_start + 1.8, 1.1, 0.020, "fm", 0.01, 0.35)
	return _pack_buffer(buffer, true)


## Urgent 6.4s low-pulse crisis loop for Black Friday / Margin Call.
func _build_pixel_crisis_loop() -> AudioStreamWAV:
	var step := 0.20
	var duration := step * 32.0
	var buffer := PackedFloat32Array()
	buffer.resize(int(SAMPLE_RATE * duration))
	var ostinato := [110.0, 110.0, 130.81, 110.0, 116.54, 110.0, 98.0, 110.0]
	for i in 32:
		var f := float(ostinato[i % ostinato.size()])
		_mix_note(buffer, f, float(i) * step, step * 0.85, 0.055, "pulse", 0.004, 0.04)
		if i % 8 == 0:
			_mix_note(buffer, f * 2.0, float(i) * step, step * 3.2, 0.028, "fm", 0.02, 0.25)
	return _pack_buffer(buffer, true)


func _build_ambient_loop() -> AudioStreamWAV:
	var duration := 16.0
	var count := int(SAMPLE_RATE * duration)
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	var chords := [
		[220.00, 261.63, 329.63, 493.88],
		[174.61, 220.00, 261.63, 329.63],
		[261.63, 329.63, 392.00, 493.88],
		[196.00, 246.94, 293.66, 329.63],
	]
	for chord_index in chords.size():
		var chord: Array = chords[chord_index]
		var start := float(chord_index) * 4.0
		for f in chord:
			_mix_note(buffer, float(f), start, 3.9, 0.016, "sine", 0.6, 0.8)
	return _pack_buffer(buffer, true)


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


func set_music_mood(mood: String) -> void:
	if not _built or _music == null:
		_current_mood = mood
		return
	var target := mood if mood != "" else "ambient"
	if _current_mood != target or _music.stream == null:
		_current_mood = target
		var was_playing := _music.playing
		_music.stop()
		_music.stream = _get_bgm_stream(target)
		if was_playing and not _muted and _music_volume > 0.0:
			_music.play()
	elif not _muted and _music_volume > 0.0 and not _music.playing:
		_music.play()


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
	if _music.stream == null:
		_music.stream = _get_bgm_stream(_current_mood if _current_mood != "" else (
			"pixel_calm" if SmaUiTheme.is_pixel() else "ambient"))
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
	var resolved := sound
	if SmaUiTheme.is_pixel() and sound == "fill":
		resolved = "pixel_coin"
	var stream: Variant = _streams.get(resolved, _streams.get(sound, null))
	if stream == null:
		return
	var player := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	player.stream = stream
	player.play()


func play_click() -> void:
	play("pixel_click" if SmaUiTheme.is_pixel() else "click")
