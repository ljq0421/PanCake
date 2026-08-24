extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/direct_soy_station.tscn")
const MANUAL_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/soy-milk-dispenser.png"
const AUTO_FILL_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/automatic-soy-milk-dispenser-transparent.png"
const DUAL_OUTLET_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/automatic-soy-milk-dispenser-two-outlets-transparent.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available for the soy station")
	if session != null:
		session.call("begin_new_game")
		var progression: RefCounted = session.call("progression_service")
		var production: RefCounted = session.call("production_service")
		var locked_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(locked_station)
		await process_frame
		locked_station.set_workshop_preview(true)
		await process_frame
		var locked_dispenser := locked_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(locked_dispenser != null, "direct soy station includes the dispenser visual")
		_check(locked_dispenser != null and locked_dispenser.texture != null and locked_dispenser.texture.resource_path == MANUAL_TEXTURE_PATH, "locked soy area previews the basic soy machine")
		_check(locked_station.visible and is_equal_approx(locked_station.modulate.a, 0.42), "locked basic soy machine is translucent in the workshop")
		locked_station.queue_free()
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
		production.call("_sync_ownership")
		var workshop_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(workshop_station)
		await process_frame
		workshop_station.set_workshop_preview(true)
		await process_frame
		var workshop_dispenser := workshop_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(workshop_dispenser != null and workshop_dispenser.texture != null and workshop_dispenser.texture.resource_path == AUTO_FILL_TEXTURE_PATH, "after the basic machine unlocks, the workshop previews the intermediate machine")
		_check(workshop_dispenser != null and is_equal_approx(workshop_dispenser.self_modulate.a, 0.42), "unowned intermediate soy machine is translucent in the workshop")
		workshop_station.queue_free()
		progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_fill": true})
		production.call("_sync_ownership")
		var intermediate_workshop_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(intermediate_workshop_station)
		await process_frame
		intermediate_workshop_station.set_workshop_preview(true)
		await process_frame
		var intermediate_workshop_dispenser := intermediate_workshop_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(intermediate_workshop_dispenser != null and intermediate_workshop_dispenser.texture != null and intermediate_workshop_dispenser.texture.resource_path == DUAL_OUTLET_TEXTURE_PATH, "after the intermediate machine unlocks, the workshop previews the advanced machine")
		_check(intermediate_workshop_dispenser != null and is_equal_approx(intermediate_workshop_dispenser.self_modulate.a, 0.42), "unowned advanced soy machine is translucent in the workshop")
		intermediate_workshop_station.queue_free()
		var live_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(live_station)
		await process_frame
		var live_dispenser := live_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(live_station.visible, "unlocked soy machine appears on the main workstation")
		_check(live_dispenser != null and live_dispenser.texture != null and live_dispenser.texture.resource_path == AUTO_FILL_TEXTURE_PATH, "automatic full-cup upgrade uses the single-outlet asset on the main workstation")
		_check(int(live_station.get("_cup_stack_count")) == 8, "the live soy station starts with an eight-cup stack")
		live_station._on_cup_stack_short_clicked({})
		_check(int(live_station.get("_cup_stack_count")) == 7, "taking an empty cup switches the stack to the next lower count")
		live_station.set("_cup_stack_count", 0)
		live_station.refresh_from_session()
		_check(is_zero_approx(live_station.cup_stack.self_modulate.a), "the final cup leaves a transparent stack location")
		live_station._on_cup_stack_hold_requested({})
		_check(int(live_station.get("_cup_stack_count")) == 1, "a restock hold adds exactly one cup")
		live_station.queue_free()
		progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_fill": true, &"automation.fresh_soy_milk.double_fill": true})
		production.call("_sync_ownership")
		var advanced_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(advanced_station)
		await process_frame
		var advanced_dispenser := advanced_station.get_node_or_null("SoyMilkDispenser") as TextureRect
		_check(advanced_dispenser != null and advanced_dispenser.texture != null and advanced_dispenser.texture.resource_path == DUAL_OUTLET_TEXTURE_PATH, "advanced soy machine uses the dual-outlet asset on the main workstation")
		var outlet_texture := advanced_station.get("_outlet_cup_texture") as Texture2D
		var stack_texture := advanced_station.cup_stack.texture_normal
		var stack_scale := minf(advanced_station.cup_stack.size.x / stack_texture.get_size().x, advanced_station.cup_stack.size.y / stack_texture.get_size().y)
		var expected_outlet_size := outlet_texture.get_size() * stack_scale
		_check(advanced_station.machine_output.size.is_equal_approx(expected_outlet_size) and advanced_station.queued_cup_preview.size.is_equal_approx(expected_outlet_size), "both outlet cups use the exact single-cup size shown in the cup stack")
		var left_outlet := advanced_station._nozzle_outlet_position()
		_check(advanced_station.machine_output.position.y >= left_outlet.y + 8.0, "the cup rim keeps a visible gap below the dispensing outlet")
		_check(is_equal_approx(float(advanced_station.dispense_effect.get("_cup_top_half_width")), advanced_station.machine_output.size.x * 0.39) and is_equal_approx(float(advanced_station.dispense_effect.get("_cup_bottom_half_width")), advanced_station.machine_output.size.x * 0.27), "the soy fill follows the measured tapered inner walls of the cup")
		advanced_station.queue_free()
		session.call("begin_new_game")
		var interaction_progression: RefCounted = session.call("progression_service")
		interaction_progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
		interaction_progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_fill": true})
		session.call("_sync_progression_to_save")
		session.set("_production_service", null)
		session.call("_ensure_production_service")
		var refill_station := STATION_SCENE.instantiate() as DirectSoyStation
		root.add_child(refill_station)
		await process_frame
		refill_station._on_cup_stack_short_clicked({})
		refill_station._on_nozzle_pressed()
		_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("cup_state", &"")) == &"filled", "the first outlet can remain filled before adding a second cup")
		interaction_progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_fill": true, &"automation.fresh_soy_milk.double_fill": true})
		refill_station.refresh_from_session()
		refill_station._on_cup_stack_short_clicked({})
		var right_cup_pending := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
		_check(bool(right_cup_pending.get("secondary_empty_cup_placed", false)) and refill_station.queued_cup_preview.visible and refill_station.second_nozzle_button.visible, "clicking the cup stack puts a new empty cup at the right outlet beside the filled left cup")
		refill_station._on_second_nozzle_pressed()
		var right_cup_filled := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
		_check(int(right_cup_filled.get("ready_cup_count", 0)) == 2 and not refill_station.second_nozzle_button.visible, "clicking the right outlet fills only its added cup")
		refill_station.queue_free()
	if failures.is_empty():
		print("DIRECT_SOY_STATION_DUAL_OUTLET_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DIRECT_SOY_STATION_DUAL_OUTLET_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
