class_name KitchenAudioPlayer
extends AudioStreamPlayer

const ONE_SHOT_VOICE_COUNT := 5
const REQUIRED_CUES: Array[StringName] = [
	&"pour", &"scrape", &"sizzle", &"flip", &"sauce", &"fold", &"serve",
	&"ambience", &"customer_arrive", &"patience_warning", &"payment_collect",
	&"youtiao_load", &"fryer_start", &"fryer_ready",
	&"soy_cup_place", &"soy_dispense", &"soy_ready",
	&"drink_restock", &"drink_pickup",
]
const CUE_COOLDOWNS_MSEC := {
	&"pour": 120,
	&"scrape": 150,
	&"flip": 120,
	&"sauce": 110,
	&"fold": 120,
	&"serve": 180,
	&"customer_arrive": 350,
	&"patience_warning": 1400,
	&"payment_collect": 250,
	&"youtiao_load": 100,
	&"fryer_start": 220,
	&"fryer_ready": 220,
	&"soy_cup_place": 100,
	&"soy_dispense": 300,
	&"soy_ready": 180,
	&"drink_restock": 120,
	&"drink_pickup": 120,
}

@export var pour_stream: AudioStream
@export var scrape_stream: AudioStream
@export var flip_stream: AudioStream
@export var sauce_stream: AudioStream
@export var fold_stream: AudioStream
@export var serve_stream: AudioStream
@export var ambience_stream: AudioStream
@export var customer_arrive_stream: AudioStream
@export var patience_warning_stream: AudioStream
@export var payment_collect_stream: AudioStream
@export var youtiao_load_stream: AudioStream
@export var fryer_start_stream: AudioStream
@export var fryer_ready_stream: AudioStream
@export var soy_cup_place_stream: AudioStream
@export var soy_dispense_stream: AudioStream
@export var soy_ready_stream: AudioStream
@export var drink_restock_stream: AudioStream
@export var drink_pickup_stream: AudioStream

@onready var cooking_sizzle: AudioStreamPlayer = $CookingSizzle

var _streams: Dictionary = {}
var _one_shot_voices: Array[AudioStreamPlayer] = []
var _ambience_player: AudioStreamPlayer
var _voice_cursor := 0
var _last_cue_msec: Dictionary = {}
var _cue_counts: Dictionary = {}
var _last_cue: StringName = &""
var _sizzle_requested := false
var _sizzle_intensity := 0.0
var _ambience_requested := false


func _ready() -> void:
	_streams = {
		&"pour": pour_stream,
		&"scrape": scrape_stream,
		&"sizzle": cooking_sizzle.stream,
		&"flip": flip_stream,
		&"sauce": sauce_stream,
		&"fold": fold_stream,
		&"serve": serve_stream,
		&"ambience": ambience_stream,
		&"customer_arrive": customer_arrive_stream,
		&"patience_warning": patience_warning_stream,
		&"payment_collect": payment_collect_stream,
		&"youtiao_load": youtiao_load_stream,
		&"fryer_start": fryer_start_stream,
		&"fryer_ready": fryer_ready_stream,
		&"soy_cup_place": soy_cup_place_stream,
		&"soy_dispense": soy_dispense_stream,
		&"soy_ready": soy_ready_stream,
		&"drink_restock": drink_restock_stream,
		&"drink_pickup": drink_pickup_stream,
	}
	for cue in _streams:
		_cue_counts[cue] = 0
	_build_playback_children()
	_prepare_sizzle_loop()
	_prepare_ambience_loop()
	set_ambience(true)


func play_cue(cue: StringName) -> void:
	if cue == &"sizzle":
		set_sizzle(true, 0.65)
		return
	if cue == &"ambience":
		set_ambience(true)
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
	var voice := _next_one_shot_voice()
	voice.stream = cue_stream
	voice.play()


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


func set_ambience(active: bool) -> void:
	_ambience_requested = active and _ambience_player != null and _ambience_player.stream != null
	if DisplayServer.get_name() == "headless":
		return
	if not _ambience_requested:
		if _ambience_player != null and _ambience_player.playing:
			_ambience_player.stream_paused = true
		return
	_ambience_player.stream_paused = false
	if not _ambience_player.playing:
		_ambience_player.play()


func has_all_cues() -> bool:
	if _streams.size() != REQUIRED_CUES.size():
		return false
	for cue in REQUIRED_CUES:
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
		"ambience_requested": _ambience_requested,
		"one_shot_voice_count": _one_shot_voices.size(),
	}


func _build_playback_children() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "MorningAmbience"
	_ambience_player.bus = bus
	_ambience_player.volume_db = -18.0
	_ambience_player.stream = ambience_stream
	add_child(_ambience_player)
	for index in ONE_SHOT_VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "OneShotVoice%02d" % (index + 1)
		voice.bus = bus
		add_child(voice)
		_one_shot_voices.append(voice)


func _next_one_shot_voice() -> AudioStreamPlayer:
	for offset in _one_shot_voices.size():
		var index := (_voice_cursor + offset) % _one_shot_voices.size()
		if not _one_shot_voices[index].playing:
			_voice_cursor = (index + 1) % _one_shot_voices.size()
			return _one_shot_voices[index]
	var voice := _one_shot_voices[_voice_cursor]
	voice.stop()
	_voice_cursor = (_voice_cursor + 1) % _one_shot_voices.size()
	return voice


func _prepare_sizzle_loop() -> void:
	_prepare_loop_player(cooking_sizzle)
	_streams[&"sizzle"] = cooking_sizzle.stream


func _prepare_ambience_loop() -> void:
	_prepare_loop_player(_ambience_player)
	_streams[&"ambience"] = _ambience_player.stream


func _prepare_loop_player(player: AudioStreamPlayer) -> void:
	if player == null or not (player.stream is AudioStreamWAV):
		return
	var loop_stream := player.stream as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = roundi(loop_stream.get_length() * float(loop_stream.mix_rate))
	player.stream = loop_stream
