class_name NightMarketAudioPlayer
extends Node

const ONE_SHOT_VOICE_COUNT := 4

@export var grill_place_stream: AudioStream
@export var grill_sizzle_stream: AudioStream
@export var grill_flip_stream: AudioStream
@export var grill_lift_stream: AudioStream
@export var fryer_lower_stream: AudioStream
@export var fryer_bubbles_stream: AudioStream
@export var fryer_lift_stream: AudioStream
@export var season_stream: AudioStream
@export var ready_cue_stream: AudioStream
@export var overcook_warning_stream: AudioStream
@export var serve_stream: AudioStream
@export var payment_stream: AudioStream

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_cursor := 0
var _cue_counts: Dictionary = {}
var _danger_active := false
var _grill_sizzle: AudioStreamPlayer
var _fryer_bubbles: AudioStreamPlayer


func _ready() -> void:
	_streams = {
		&"grill_place": grill_place_stream,
		&"grill_flip": grill_flip_stream,
		&"grill_lift": grill_lift_stream,
		&"fryer_lower": fryer_lower_stream,
		&"fryer_lift": fryer_lift_stream,
		&"season": season_stream,
		&"ready_cue": ready_cue_stream,
		&"overcook_warning": overcook_warning_stream,
		&"serve": serve_stream,
		&"payment": payment_stream,
	}
	_grill_sizzle = _loop_player(&"GrillSizzle", grill_sizzle_stream, -13.0)
	_fryer_bubbles = _loop_player(&"FryerBubbles", fryer_bubbles_stream, -11.0)
	for index in ONE_SHOT_VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "OneShotVoice%02d" % (index + 1)
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)


func play_cue(cue: StringName) -> void:
	var stream := _streams.get(cue) as AudioStream
	if stream == null or _voices.is_empty():
		return
	var voice := _next_voice()
	voice.stream = stream
	voice.pitch_scale = 1.0
	voice.volume_db = -5.0 if cue in [&"serve", &"payment"] else -7.0
	voice.play()
	_cue_counts[cue] = int(_cue_counts.get(cue, 0)) + 1


func set_cooking_activity(grill_active: bool, fryer_active: bool, danger_active: bool) -> void:
	_set_loop_active(_grill_sizzle, grill_active)
	_set_loop_active(_fryer_bubbles, fryer_active)
	if danger_active and not _danger_active:
		play_cue(&"overcook_warning")
	_danger_active = danger_active


func has_all_cues() -> bool:
	if grill_sizzle_stream == null or fryer_bubbles_stream == null:
		return false
	for stream in _streams.values():
		if stream == null:
			return false
	return true


func get_cue_stream(cue: StringName) -> AudioStream:
	if cue == &"grill_sizzle":
		return grill_sizzle_stream
	if cue == &"fryer_bubbles":
		return fryer_bubbles_stream
	return _streams.get(cue) as AudioStream


func get_diagnostics() -> Dictionary:
	return {
		"cue_counts": _cue_counts.duplicate(true),
		"grill_sizzle_playing": _grill_sizzle != null and _grill_sizzle.playing,
		"fryer_bubbles_playing": _fryer_bubbles != null and _fryer_bubbles.playing,
		"danger_active": _danger_active,
		"one_shot_voice_count": _voices.size(),
	}


func _loop_player(node_name: StringName, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = &"SFX"
	player.stream = stream
	player.volume_db = volume_db
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(player)
	return player


func _set_loop_active(player: AudioStreamPlayer, active: bool) -> void:
	if player == null or player.stream == null:
		return
	if active and not player.playing:
		player.play()
	elif not active and player.playing:
		player.stop()


func _next_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	var voice := _voices[_voice_cursor]
	_voice_cursor = (_voice_cursor + 1) % _voices.size()
	return voice
