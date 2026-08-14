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

	_check(bool(audio.call("has_all_cues")), "all seven P1 kitchen cues are bound in the stable workstation scene")
	for cue in EXPECTED_STREAMS:
		var cue_stream := audio.call("get_cue_stream", cue) as AudioStream
		_check(cue_stream != null, "%s cue loads as an AudioStream" % cue)
		if cue_stream != null:
			_check(cue_stream.resource_path == EXPECTED_STREAMS[cue], "%s cue uses its dedicated source asset" % cue)
			_check(cue_stream.get_length() >= 0.30, "%s cue is a non-placeholder kitchen recording length" % cue)

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
