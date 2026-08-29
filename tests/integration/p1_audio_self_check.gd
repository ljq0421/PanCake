extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

const EXPECTED_STREAMS := {
	&"pour": "res://resources/audio/sfx/batter_drop.wav",
	&"scrape": "res://resources/audio/sfx/spreader_scrape.wav",
	&"sizzle": "res://resources/audio/sfx/cooking_sizzle.wav",
	&"flip": "res://resources/audio/sfx/pancake_flip.wav",
	&"sauce": "res://resources/audio/sfx/sauce_brush.wav",
	&"fold": "res://resources/audio/sfx/pancake_fold.wav",
	&"serve": "res://resources/audio/sfx/order_serve.wav",
	&"ambience": "res://resources/audio/sfx/morning_ambience.wav",
	&"customer_arrive": "res://resources/audio/sfx/customer_arrive.wav",
	&"patience_warning": "res://resources/audio/sfx/patience_warning.wav",
	&"payment_collect": "res://resources/audio/sfx/payment_collect.wav",
	&"youtiao_load": "res://resources/audio/sfx/youtiao_load.wav",
	&"fryer_start": "res://resources/audio/sfx/fryer_start.wav",
	&"fryer_ready": "res://resources/audio/sfx/fryer_ready.wav",
	&"soy_cup_place": "res://resources/audio/sfx/soy_cup_place.wav",
	&"soy_dispense": "res://resources/audio/sfx/soy_dispense.wav",
	&"soy_ready": "res://resources/audio/sfx/soy_ready.wav",
	&"drink_restock": "res://resources/audio/sfx/drink_restock.wav",
	&"drink_pickup": "res://resources/audio/sfx/drink_pickup.wav",
}

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate() as Workstation
	root.add_child(workstation)
	# This check drives every production phase directly. Disable the live order
	# clock immediately after _ready(), before yielding a frame, so a restored
	# near-expiry order cannot reset the fixture.
	workstation.set_process(false)
	await process_frame
	await process_frame
	var audio: AudioStreamPlayer = workstation.kitchen_audio
	_check(audio.bus == &"SFX", "kitchen cues use the settings-controlled SFX bus")
	_check((audio.get_node("CookingSizzle") as AudioStreamPlayer).bus == &"SFX", "continuous sizzle uses the settings-controlled SFX bus")
	_check((audio.get_node("MorningAmbience") as AudioStreamPlayer).bus == &"SFX", "morning ambience uses the settings-controlled SFX bus")
	for voice_index in 5:
		_check((audio.get_node("OneShotVoice%02d" % (voice_index + 1)) as AudioStreamPlayer).bus == &"SFX", "one-shot voice %d uses the SFX bus" % (voice_index + 1))

	_check(bool(audio.call("has_all_cues")), "all 19 breakfast-shop cues are bound in the stable workstation scene")
	for cue in EXPECTED_STREAMS:
		var cue_stream := audio.call("get_cue_stream", cue) as AudioStream
		_check(cue_stream != null, "%s cue loads as an AudioStream" % cue)
		if cue_stream != null:
			_check(cue_stream.resource_path == EXPECTED_STREAMS[cue], "%s cue uses its dedicated source asset" % cue)
			_check(cue_stream.get_length() >= 0.30, "%s cue is a non-placeholder kitchen recording length" % cue)

	var ambience := audio.get_node("MorningAmbience") as AudioStreamPlayer
	_check(ambience.stream is AudioStreamWAV and (ambience.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "morning ambience is configured as a seamless loop")
	var diagnostics := Dictionary(audio.call("get_diagnostics"))
	_check(bool(diagnostics.get("ambience_requested", false)), "morning ambience starts with gameplay")
	_check(int(diagnostics.get("one_shot_voice_count", 0)) == 5, "one-shot cues have five playback voices and do not cut each other off")
	workstation.cartoon_youtiao_fryer.audio_cue_requested.emit(&"youtiao_load")
	workstation.fresh_soy_station.audio_cue_requested.emit(&"soy_cup_place")
	workstation.packaged_drink_station.emit_signal("audio_cue_requested", &"drink_restock")
	diagnostics = Dictionary(audio.call("get_diagnostics"))
	var counts := Dictionary(diagnostics.get("cue_counts", {}))
	_check(int(counts.get(&"youtiao_load", 0)) == 1, "youtiao station routes semantic audio through the shared player")
	_check(int(counts.get(&"soy_cup_place", 0)) == 1, "soy station routes semantic audio through the shared player")
	_check(int(counts.get(&"drink_restock", 0)) == 1, "packaged-drink station routes semantic audio through the shared player")

	workstation.set("_audio_orders_seeded", false)
	workstation.set("_known_audio_order_ids", {})
	workstation.set("_warned_audio_order_ids", {})
	var first_order := {"order_id": &"audio.order.1", "patience_seconds": 100.0, "remaining_patience_seconds": 100.0}
	var second_order := {"order_id": &"audio.order.2", "patience_seconds": 100.0, "remaining_patience_seconds": 100.0}
	workstation.call("_update_order_audio_feedback", [first_order])
	workstation.call("_update_order_audio_feedback", [first_order, second_order])
	workstation.call("_update_order_audio_feedback", [first_order, second_order])
	second_order["remaining_patience_seconds"] = 29.0
	workstation.call("_update_order_audio_feedback", [first_order, second_order])
	workstation.call("_update_order_audio_feedback", [first_order, second_order])
	diagnostics = Dictionary(audio.call("get_diagnostics"))
	counts = Dictionary(diagnostics.get("cue_counts", {}))
	_check(int(counts.get(&"customer_arrive", 0)) == 1, "new customer arrival plays once instead of on every refresh")
	_check(int(counts.get(&"patience_warning", 0)) == 1, "critical patience crossing plays once per order")

	for cue in [&"fryer_start", &"soy_ready", &"drink_pickup", &"payment_collect"]:
		audio.call("play_cue", cue)
	diagnostics = Dictionary(audio.call("get_diagnostics"))
	counts = Dictionary(diagnostics.get("cue_counts", {}))
	for cue in [&"fryer_start", &"soy_ready", &"drink_pickup", &"payment_collect"]:
		_check(int(counts.get(cue, 0)) == 1, "%s semantic event reaches the shared audio player" % cue)

	workstation.queue_free()
	await process_frame
	await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("P1 AUDIO SELF-CHECK PASS")
		quit(0)
	else:
		print("P1 AUDIO SELF-CHECK FAIL (%d)" % _failures.size())
		quit(1)
