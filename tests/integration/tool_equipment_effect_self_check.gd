extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const PANCAKE_MODEL := preload("res://scripts/simulation/pancake_model.gd")
const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const PROGRESSION_SERVICE := preload("res://scripts/services/workstation_progression_service.gd")
const PRODUCTION_SERVICE := preload("res://scripts/services/expansion_production_service.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var basic_model := PANCAKE_MODEL.new(128)
	var wide_model := PANCAKE_MODEL.new(128)
	var center := Vector2(63.5, 63.5)
	basic_model.call("add_batter", center, 6.0, 55.0)
	wide_model.call("add_batter", center, 6.0, 55.0)
	var basic_result: Dictionary = basic_model.call("apply_scraper_sample", center, Vector2.RIGHT, 72.0, 1.0)
	var wide_result: Dictionary = wide_model.call("apply_scraper_sample", center, Vector2.RIGHT, 72.0, 1.35)
	_check(int(wide_result.get("changed_cells", 0)) > int(basic_result.get("changed_cells", 0)), "wide spreader changes a physically wider model footprint")

	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	session.begin_new_game()
	var progression: RefCounted = session.progression_service()
	progression.get("owned_items")[CATALOG.TOOL_SPREADER_WIDE] = true
	progression.get("owned_items")[CATALOG.TOOL_PRESS] = true
	progression.get("owned_items")[CATALOG.TOOL_SAUCE_BRUSH_AUTO] = true
	progression.get("equipment_levels")[CATALOG.DEVICE_SOY_MILK] = CATALOG.TIER_INTERMEDIATE
	progression.set("coins", 10)
	session.save_workstation_progression(progression.call("snapshot"))

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	var pancake_model: RefCounted = workstation.get("pancake_model")
	var model_center := Vector2(63.5, 63.5)
	pancake_model.call("add_batter", model_center, 8.0, 22.0)
	workstation.set("pour_used", true)
	(workstation.get("p1_session") as RefCounted).set("phase", 0)
	var press_result: Dictionary = workstation.call("use_press_spreader")
	var second_press: Dictionary = workstation.call("use_press_spreader")
	_check(bool(press_result.get("success", false)) and float(press_result.get("moved_mass", 0.0)) > 0.0, "press spreader performs a real standard spread on batter")
	_check(not bool(second_press.get("success", false)) and second_press.get("reason", &"") == &"already_used", "press spreader is limited to one use per pancake")

	pancake_model.call("reset")
	pancake_model.call("add_batter", model_center, 8.0, 45.0)
	var p1_session: RefCounted = workstation.get("p1_session")
	p1_session.set("phase", 3)
	var sweet_state: RefCounted = workstation.get("sauce_tool_states")[&"sweet_flour"]
	sweet_state.call("add", sweet_state.get("capacity"))
	var load_before := float(sweet_state.get("load"))
	var time_before := float(p1_session.get("elapsed_seconds"))
	var brush_result: Dictionary = workstation.call("use_automatic_sauce_brush")
	_check(bool(brush_result.get("success", false)) and float(pancake_model.call("total_sauce", &"sweet_flour")) > 0.0, "automatic brush paints the live pancake field")
	_check(float(sweet_state.get("load")) < load_before, "automatic brush consumes real brush load")
	_check(float(p1_session.get("elapsed_seconds")) > time_before, "automatic brush consumes customer time")

	var wide_hook := workstation.get_node("SafeArea/ExpansionLayout/LeftZone/UpgradeToolHooks/WideSpreaderHook") as Button
	var press_hook := workstation.get_node("SafeArea/ExpansionLayout/LeftZone/UpgradeToolHooks/PressSpreaderHook") as Button
	_check(wide_hook.visible and press_hook.visible, "owned tools appear on their fixed scene-backed hooks")
	var soy_art := workstation.get_node("SafeArea/ExpansionLayout/DeviceSlots/SoyMilkMachineSlot/EquipmentArt") as TextureRect
	var soy_hit := workstation.get_node("SafeArea/ExpansionLayout/DeviceSlots/SoyMilkMachineSlot/InteractionArea") as Button
	_check(soy_art.visible and "tier_2" in soy_art.texture.resource_path, "equipment tier swaps to its matching machine artwork")
	_check("单批2份" in soy_hit.tooltip_text and "12秒" in soy_hit.tooltip_text, "equipment UI exposes the tier's actual capacity and duration")
	var adapter := workstation.get_node("SafeArea/InitialUnlockAdapter")
	var production: RefCounted = adapter.call("production_service")
	var machine_snapshot: Dictionary = production.call("machine_snapshot", CATALOG.DEVICE_SOY_MILK)
	_check(int(machine_snapshot.get("capacity", 0)) == 2 and is_equal_approx(float(machine_snapshot.get("duration_seconds", 0.0)), 12.0), "visual equipment tier and production service share the same real effect data")

	adapter.call("_on_device_button_down", CATALOG.DEVICE_SOY_MILK)
	adapter.call("_advance_device_refill_hold", 1.7)
	adapter.call("_on_device_button_up", CATALOG.DEVICE_SOY_MILK)
	_check(int(progression.get("inventory").call("current", CATALOG.STOCK_SOY_YELLOW)) == 1 and int(progression.get("coins")) == 9, "holding a machine refills one default raw input and charges its real unit cost")
	adapter.call("_on_device_button_down", CATALOG.DEVICE_SOY_MILK)
	adapter.call("_on_device_button_up", CATALOG.DEVICE_SOY_MILK)
	adapter.call("_on_device_button_down", CATALOG.DEVICE_SOY_MILK)
	adapter.call("_on_device_button_up", CATALOG.DEVICE_SOY_MILK)
	machine_snapshot = production.call("machine_snapshot", CATALOG.DEVICE_SOY_MILK)
	_check(machine_snapshot.get("state", &"") == &"processing" and int(machine_snapshot.get("loaded_quantity", 0)) == 1, "two explicit machine clicks load, perform required actions, and start production")
	var persisted_snapshot: Dictionary = session.workstation_progression_snapshot()
	_check(Dictionary(persisted_snapshot.get("equipment_batches", {})).has("soy_milk_machine"), "an in-progress equipment batch is included in complete progress saves")
	var restored_progression: RefCounted = PROGRESSION_SERVICE.new(persisted_snapshot)
	var restored_production: RefCounted = PRODUCTION_SERVICE.new(restored_progression)
	_check(restored_production.call("machine_snapshot", CATALOG.DEVICE_SOY_MILK).get("state", &"") == &"processing", "a new production service restores the saved in-progress batch")
	production.call("advance_time", 12.0)
	adapter.call("_persist_progression")
	adapter.call("_on_device_button_down", CATALOG.DEVICE_SOY_MILK)
	adapter.call("_on_device_button_up", CATALOG.DEVICE_SOY_MILK)
	_check(int(progression.call("metric", &"soy_good")) == 1, "collecting a qualified product updates the permanent equipment gate metric")
	_check(production.call("machine_snapshot", CATALOG.DEVICE_SOY_MILK).get("state", &"") == &"idle", "collecting frees the real machine capacity")

	workstation.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("TOOL_EQUIPMENT_EFFECT_SELF_CHECK_PASS")
		quit(0)
		return
	print("TOOL_EQUIPMENT_EFFECT_SELF_CHECK_FAIL: %s" % ", ".join(_failures))
	quit(1)
