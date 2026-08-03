class_name KitchenAudioPlayer
extends AudioStreamPlayer

const CUE_COOLDOWNS_MSEC := {
	&"pour": 120,
	&"scrape": 150,
	&"flip": 120,
	&"sauce": 110,
	&"fold": 120,
	&"serve": 180,
}

@export var pour_stream: AudioStream
@export var scrape_stream: AudioStream
@export var flip_stream: AudioStream
@export var sauce_stream: AudioStream
@export var fold_stream: AudioStream
@export var serve_stream: AudioStream

@onready var cooking_sizzle: AudioStreamPlayer = $CookingSizzle

var _streams: Dictionary = {}
var _last_cue_msec: Dictionary = {}
var _cue_counts: Dictionary = {}
var _last_cue: StringName = &""
var _sizzle_requested := false
var _sizzle_intensity := 0.0


func _ready() -> void:
	_streams = {
		&"pour": pour_stream,
		&"scrape": scrape_stream,
		&"sizzle": cooking_sizzle.stream,
		&"flip": flip_stream,
		&"sauce": sauce_stream,
		&"fold": fold_stream,
		&"serve": serve_stream,
	}
	for cue in _streams:
		_cue_counts[cue] = 0
	_prepare_sizzle_loop()


func play_cue(cue: StringName) -> void:
	if cue == &"sizzle":
		set_sizzle(true, 0.65)
		return
	var cue_stream: AudioStream = _streams.get(cue)
	if cue_stream == null:
		return
	var now := Time.get_ticks_msec()
	var cooldown := int(CUE_COOLDOWNS_MSEC.get(cue, 80))
	if now - int(_last_cue_msec.get(cue, -10000)) < cooldown:
		return
	_last_cue_msec[cue] = now
	_last_cue = cue
	_cue_counts[cue] = int(_cue_counts.get(cue, 0)) + 1
	if DisplayServer.get_name() == "headless":
		return
	stream = cue_stream
	play()


func set_sizzle(active: bool, intensity: float = 0.65) -> void:
	_sizzle_requested = active and cooking_sizzle.stream != null
	_sizzle_intensity = clampf(intensity, 0.0, 1.0) if _sizzle_requested else 0.0
	if not _sizzle_requested:
		cooking_sizzle.stop()
		return
	if DisplayServer.get_name() == "headless":
		return
	cooking_sizzle.volume_db = lerpf(-25.0, -8.0, _sizzle_intensity)
	cooking_sizzle.pitch_scale = lerpf(0.84, 1.16, _sizzle_intensity)
	if not cooking_sizzle.playing:
		cooking_sizzle.play()


func has_all_cues() -> bool:
	if _streams.size() != 7:
		return false
	for cue in [&"pour", &"scrape", &"sizzle", &"flip", &"sauce", &"fold", &"serve"]:
		if not _streams.has(cue) or _streams[cue] == null:
			return false
	return true


func get_cue_stream(cue: StringName) -> AudioStream:
	return _streams.get(cue)


func get_diagnostics() -> Dictionary:
	return {
		"all_cues_loaded": has_all_cues(),
		"cue_counts": _cue_counts.duplicate(true),
		"last_cue": _last_cue,
		"sizzle_requested": _sizzle_requested,
		"sizzle_intensity": _sizzle_intensity,
	}


func _prepare_sizzle_loop() -> void:
	if not (cooking_sizzle.stream is AudioStreamWAV):
		return
	var loop_stream := cooking_sizzle.stream as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = roundi(loop_stream.get_length() * float(loop_stream.mix_rate))
	cooking_sizzle.stream = loop_stream
	_streams[&"sizzle"] = loop_stream
