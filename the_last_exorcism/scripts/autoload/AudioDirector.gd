extends Node
## AudioDirector autoload - procedurally generates all prototype audio (no external
## files needed) and manages ambient dread, whispers, stingers and footstep clicks.
## Every sound is routed through the SFX/Music buses so GameSettings volumes apply.

var _env := AudioEnvironment.new()


class AudioEnvironment extends RefCounted:
	var players: Array[AudioStreamPlayer] = []
	var pool_size := 6


func _ready() -> void:
	# Build bus layout expected by GameSettings if missing (editor runs included).
	if AudioServer.get_bus_index("SFX") < 0:
		_add_bus("SFX")
	if AudioServer.get_bus_index("Music") < 0:
		_add_bus("Music")
	# Pre-create a small player pool for one-shots.
	for i in AudioEnvironment.pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_env.players.append(p)


func _add_bus(name: String) -> void:
	AudioServer.add_bus(AudioServer.bus_count)
	AudioServer.set_bus_name(AudioServer.bus_count - 1, name)


## Generate a mono WAV byte array from samples at 44.1kHz. Pure GDScript, no assets.
static func make_wav(samples: PackedFloat32Array, rate := 44100) -> PackedByteArray:
	var n := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(44 + n * 2)
	# "RIFF"
	bytes[0] = 82; bytes[1] = 73; bytes[2] = 68; bytes[3] = 70
	var data_size: int = n * 2
	var file_size: int = 36 + data_size
	_wu32(bytes, 4, file_size)
	# "WAVE"
	bytes[8] = 87; bytes[9] = 65; bytes[10] = 86; bytes[11] = 69
	# "fmt "
	bytes[12] = 102; bytes[13] = 109; bytes[14] = 116; bytes[15] = 32
	_wu32(bytes, 16, 16)                 # fmt chunk size
	_wu16(bytes, 20, 1)                  # PCM
	_wu16(bytes, 22, 1)                  # mono
	_wu32(bytes, 24, rate)
	_wu32(bytes, 28, rate * 2)           # byte rate
	_wu16(bytes, 32, 2)                  # block align
	_wu16(bytes, 34, 16)                 # bits
	# "data"
	bytes[36] = 100; bytes[37] = 97; bytes[38] = 116; bytes[39] = 97
	_wu32(bytes, 40, data_size)
	for i in n:
		var s := clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(44 + i * 2, s)
	return bytes


static func _wu32(b: PackedByteArray, off: int, v: int) -> void:
	b[off] = v & 0xFF; b[off+1] = (v >> 8) & 0xFF; b[off+2] = (v >> 16) & 0xFF; b[off+3] = (v >> 24) & 0xFF


static func _wu16(b: PackedByteArray, off: int, v: int) -> void:
	b[off] = v & 0xFF; b[off+1] = (v >> 8) & 0xFF


static func tone_stream(freq: float, dur: float, vol := 0.3, decay := 2.0) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		var env := exp(-decay * t)
		s[i] = sin(TAU * freq * t) * vol * env
	var wav := make_wav(s, rate)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = wav
	return stream


static func noise_burst(dur: float, lowpass_hz: float, vol := 0.4) -> AudioStreamWAV:
	# Simple filtered noise - used for footsteps / door thuds / static.
	var rate := 44100
	var n := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := clampf(lowpass_hz / rate * 10.0, 0.01, 1.0)
	var last := 0.0
	for i in n:
		var white := randf_range(-1.0, 1.0)
		last += lp * (white - last)
		var t := float(i) / rate
		s[i] = last * vol * exp(-6.0 * t / dur)
	var wav := make_wav(s, rate)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = wav
	return stream


func play(stream: AudioStream, volume_db := 0.0) -> void:
	for p in _env.players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return


func footstep(running := false) -> void:
	play(noise_burst(0.06, 900.0 if running else 500.0, 0.25), -8.0)


func interact_ok() -> void:
	play(tone_stream(660.0, 0.12, 0.2, 12.0))


func interact_fail() -> void:
	play(tone_stream(180.0, 0.2, 0.25, 8.0))


func pickup() -> void:
	play(tone_stream(880.0, 0.1, 0.2, 14.0))
	play(tone_stream(1320.0, 0.15, 0.15, 10.0))


func whisper() -> void:
	play(noise_burst(0.8, 2400.0, 0.12), -6.0)


func scare_stinger() -> void:
	play(noise_burst(0.5, 6000.0, 0.7))
	play(tone_stream(55.0, 0.9, 0.5, 2.0))


func heartbeat() -> void:
	play(tone_stream(50.0, 0.12, 0.35, 20.0))


func door_open() -> void:
	play(noise_burst(0.35, 350.0, 0.35))


func exorcism_chime() -> void:
	play(tone_stream(523.25, 1.2, 0.25, 1.5))
	play(tone_stream(659.25, 1.4, 0.2, 1.2))
