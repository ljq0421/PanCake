class_name KitchenAudioPlayer
extends AudioStreamPlayer

const MIX_RATE := 22050
const CUES := {
	&"pour": [180.0, 0.12, 0.08],
	&"scrape": [330.0, 0.06, 0.04],
	&"sizzle": [520.0, 0.08, 0.035],
	&"flip": [240.0, 0.16, 0.09],
	&"sauce": [410.0, 0.07, 0.04],
	&"fold": [290.0, 0.10, 0.06],
	&"serve": [760.0, 0.20, 0.08],
}

var _streams := {}
var _last_cue_msec := -10000


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for cue in CUES:
		var spec: Array = CUES[cue]
		_streams[cue] = _build_tone(float(spec[0]), float(spec[1]), float(spec[2]))


func play_cue(cue: StringName) -> void:
	if not _streams.has(cue):
		return
	var now := Time.get_ticks_msec()
	if now - _last_cue_msec < 45:
		return
	_last_cue_msec = now
	stream = _streams[cue]
	play()


func _build_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var frame_count := roundi(float(MIX_RATE) * duration)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	for frame in frame_count:
		var progress := float(frame) / maxf(float(frame_count - 1), 1.0)
		var envelope := sin(PI * progress)
		var wobble := 1.0 + 0.06 * sin(progress * TAU * 3.0)
		var sample := roundi(sin(TAU * frequency * wobble * float(frame) / float(MIX_RATE)) * amplitude * envelope * 32767.0)
		pcm.encode_s16(frame * 2, clampi(sample, -32768, 32767))
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = MIX_RATE
	tone.stereo = false
	tone.data = pcm
	return tone
