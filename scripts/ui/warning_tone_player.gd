class_name WarningTonePlayer
extends AudioStreamPlayer

const MIX_RATE := 22050

var _normal_tone: AudioStreamWAV
var _severe_tone: AudioStreamWAV
var _last_trigger_msec := -10000


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_normal_tone = _build_tone(720.0, 0.07, 0.075)
	_severe_tone = _build_tone(940.0, 0.12, 0.12)


func trigger(severe: bool = false) -> void:
	if _normal_tone == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_trigger_msec < 180:
		return
	_last_trigger_msec = now
	stream = _severe_tone if severe else _normal_tone
	play()


func _build_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var frame_count := roundi(float(MIX_RATE) * duration)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	for frame in frame_count:
		var progress := float(frame) / maxf(float(frame_count - 1), 1.0)
		var envelope := sin(PI * progress)
		var sample := roundi(sin(TAU * frequency * float(frame) / float(MIX_RATE)) * amplitude * envelope * 32767.0)
		pcm.encode_s16(frame * 2, clampi(sample, -32768, 32767))
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = MIX_RATE
	tone.stereo = false
	tone.loop_mode = AudioStreamWAV.LOOP_DISABLED
	tone.data = pcm
	return tone


func _exit_tree() -> void:
	stop()
	stream = null
	_normal_tone = null
	_severe_tone = null
