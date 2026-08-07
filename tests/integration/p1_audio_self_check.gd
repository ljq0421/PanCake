extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")

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
	await process_frame
	await process_frame
	workstation.set_process(false)
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

	workstation._auto_pour_center()
	var diagnostics: Dictionary = audio.call("get_diagnostics")
	_check(int(diagnostics.cue_counts.get(&"pour", 0)) == 1, "automatic measured pour triggers batter-drop audio once")
	workstation._update_cooking_audio(0.13)
	diagnostics = audio.call("get_diagnostics")
	_check(bool(diagnostics.sizzle_requested) and float(diagnostics.sizzle_intensity) > 0.0, "poured batter on active heat requests the continuous cooking sizzle")

	_fill_product_base(workstation.pancake_model)
	_check(bool(workstation.p1_session.confirm_spread(workstation.pancake_model).success), "audio path fixture reaches first-side cooking")
	var center := Vector2(workstation.pancake_model.grid_size - 1, workstation.pancake_model.grid_size - 1) * 0.5
	workstation.ingredient_model.place(IngredientModel.EGG, center, 0.0, workstation.pancake_model)
	workstation.pancake_model.crack_egg(center)
	workstation.tool_controller.select_tool(ToolController.Tool.SCRAPER)
	_spread_egg(workstation)
	diagnostics = audio.call("get_diagnostics")
	_check(int(diagnostics.cue_counts.get(&"scrape", 0)) > 0, "accepted distance-sampled spreading triggers scraper audio")

	workstation.pancake_model.doneness.fill(0.62)
	workstation._advance_p1_step()
	diagnostics = audio.call("get_diagnostics")
	_check(int(diagnostics.cue_counts.get(&"flip", 0)) == 1, "successful guarded flip triggers flip audio once")
	_check(workstation.p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS, "successful flip immediately reaches sauce phase")

	workstation.sauce_tool_state.add(workstation.parameters.sauce_brush_capacity)
	workstation._sauce_stroke_id = workstation.pancake_model.begin_sauce_stroke()
	workstation._apply_sauce_brush_sample(center)
	diagnostics = audio.call("get_diagnostics")
	_check(int(diagnostics.cue_counts.get(&"sauce", 0)) > 0, "a sauce sample that changes cells triggers brush audio")

	workstation.ingredient_model.place(IngredientModel.BAOCUI, Vector2(62, 56), 0.0, workstation.pancake_model)
	workstation.ingredient_model.place(IngredientModel.SCALLION, Vector2(68, 70), 0.0, workstation.pancake_model)
	workstation._advance_p1_step()
	_commit_fold(workstation, Vector2(110, 300), Vector2(300, 300), Vector2(70, 64))
	diagnostics = audio.call("get_diagnostics")
	_check(int(diagnostics.cue_counts.get(&"fold", 0)) > 0, "a committed continuous fold triggers fold audio")

	_commit_fold(workstation, Vector2(490, 300), Vector2(300, 300), Vector2(58, 64))
	workstation._use_bag()
	workstation._serve_order()
	diagnostics = audio.call("get_diagnostics")
	_check(int(diagnostics.cue_counts.get(&"serve", 0)) == 1, "valid order handoff triggers serve audio once")
	_check(not bool(diagnostics.sizzle_requested), "cooking sizzle is stopped outside the cooking phases")

	workstation.queue_free()
	await process_frame
	await process_frame
	_finish()


func _fill_product_base(model: PancakeModel) -> void:
	for y in model.grid_size:
		for x in model.grid_size:
			if not model.is_inside_pan(Vector2(x, y), 0.84):
				continue
			var index := y * model.grid_size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.42
			model.wetness[index] = 0.20
	model.revision += 1
	model.changed.emit()


func _spread_egg(workstation: Workstation) -> void:
	var center := Vector2(workstation.pancake_model.grid_size - 1, workstation.pancake_model.grid_size - 1) * 0.5
	workstation._on_pointer_started(Vector2(300, 300))
	for ring in 10:
		var radius := 6.0 + float(ring) * 4.2
		for step in 56:
			var angle := TAU * float(step) / 56.0
			var radial := Vector2(cos(angle), sin(angle) * workstation.parameters.pan_height_ratio)
			workstation._process_scraper(center + radial * radius, 1.0 / 60.0)
	workstation._on_pointer_ended(Vector2(300, 300))


func _commit_fold(workstation: Workstation, start_local: Vector2, end_local: Vector2, drag_grid: Vector2) -> void:
	workstation._on_pointer_started(start_local)
	workstation.fold_model.update_drag(drag_grid)
	workstation._on_pointer_ended(end_local)


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
