class_name FiveAreaProductionService
extends RefCounted

signal machine_changed(device_id: StringName, snapshot: Dictionary)
signal product_created(product: Dictionary)
signal waste_recorded(entry: Dictionary)
signal stock_changed(stock_id: StringName, current: int)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const YOUTIAO_MODEL := preload("res://scripts/gameplay/youtiao_fryer_model.gd")
const SOY_MODEL := preload("res://scripts/gameplay/fresh_soy_milk_machine_model.gd")
const YOUTIAO_DEVICE := &"device.youtiao_fryer"
const SOY_DEVICE := &"device.fresh_soy_milk_machine"
const YOUTIAO_AUTO_LIFT := &"automation.youtiao.auto_lift"
const TIME_DRIVEN_YOUTIAO_STATES := [
	&"frying",
	&"ready_safe",
	&"overcooking",
	&"draining",
]

var _session: Node
var _progression: RefCounted
var _youtiao: RefCounted = YOUTIAO_MODEL.new()
var _soy: RefCounted = SOY_MODEL.new()
var _product_sequence := 0
var _waste_events: Array[Dictionary] = []
var _pancake_griddles: Dictionary = {"version": 1, "griddle_count": 1, "active_index": 0, "product_sequence": 0, "slots": []}
var _youtiao_auto_lift_enabled := true


func _init(session: Node = null, initial_snapshot: Dictionary = {}) -> void:
	if session != null:
		configure(session.call("progression_service") if session.has_method("progression_service") else null, session)
	if not initial_snapshot.is_empty():
		load_snapshot(initial_snapshot)


func configure(progression: RefCounted, session: Node) -> void:
	_progression = progression
	_session = session
	_sync_ownership()


func advance_time(delta: float) -> bool:
	var step := maxf(delta, 0.0)
	if step <= 0.0:
		return false
	_sync_ownership()
	# Soy serving is entirely player-driven, and several fryer states are also
	# stable until the next player action.  Reporting a change for those states
	# made GameSession clone and broadcast the complete production snapshot every
	# frame, even while a finished stick was following the pointer.
	if StringName(_youtiao.get("state")) not in TIME_DRIVEN_YOUTIAO_STATES:
		return false
	_youtiao.call("advance_time", step, youtiao_auto_lift_enabled())
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return true


func machine_snapshot(device_id: StringName) -> Dictionary:
	_sync_ownership()
	if device_id == YOUTIAO_DEVICE:
		var youtiao_snapshot := Dictionary(_youtiao.call("snapshot")).duplicate(true)
		youtiao_snapshot["auto_lift_enabled"] = youtiao_auto_lift_enabled()
		return youtiao_snapshot
	if device_id == SOY_DEVICE:
		return Dictionary(_soy.call("snapshot")).duplicate(true)
	return {"device_id": device_id, "owned": false, "state": &"unsupported"}


func take_soy_empty_cup() -> Dictionary:
	_sync_ownership()
	var result: Dictionary = _soy.call("take_empty_cup")
	if bool(result.get("success", false)):
		machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return result


func select_soy_recipe(recipe_id: StringName) -> Dictionary:
	_sync_ownership()
	var result: Dictionary = _soy.call("select_recipe", recipe_id)
	if bool(result.get("success", false)):
		machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return result


func fill_soy_empty_cup(held_seconds: float, outlet_index: int = 0) -> Dictionary:
	_sync_ownership()
	var result: Dictionary = _soy.call("fill_held_cup", held_seconds, outlet_index)
	if bool(result.get("success", false)):
		machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return result


func add_soy_sugar(cup_index: int = 0) -> Dictionary:
	var result: Dictionary = _soy.call("add_sugar", cup_index)
	if bool(result.get("success", false)):
		machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return result


func add_soy_ice(cup_index: int = 0) -> Dictionary:
	var result: Dictionary = _soy.call("add_ice", cup_index)
	if bool(result.get("success", false)):
		machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return result


func preview_soy_cup(cup_index: int = 0) -> Dictionary:
	var result: Dictionary = _soy.call("preview_cup", cup_index)
	if not bool(result.get("success", false)):
		return result
	var source_product := Dictionary(result.get("product", {}))
	var product := _new_product(
		StringName(source_product.get("product_id", &"")),
		&"area.fresh_soy_milk",
		StringName(source_product.get("temperature_mode", &"room_temperature")),
		float(source_product.get("quality", 0.0)),
		StringName(source_product.get("grade", &"waste")),
		false,
	)
	_copy_soy_product_fields(product, source_product)
	product["fill_ratio"] = float(source_product.get("fill_ratio", 1.0))
	product["sugar_servings"] = int(source_product.get("sugar_servings", 0))
	return _success({"product": product})


func take_soy_cup(cup_index: int = 0) -> Dictionary:
	var preview := preview_soy_cup(cup_index)
	if not bool(preview.get("success", false)):
		return preview
	var taken: Dictionary = _soy.call("take_filled_cup", cup_index)
	if not bool(taken.get("success", false)):
		return taken
	var product := Dictionary(preview.get("product", {})).duplicate(true)
	product["product_instance_id"] = _new_product(
		StringName(product.get("product_id", &"")),
		&"area.fresh_soy_milk",
		StringName(product.get("temperature_mode", &"room_temperature")),
		float(product.get("quality", 0.0)),
		StringName(product.get("grade", &"waste")),
	).get("product_instance_id", &"")
	product_created.emit(product.duplicate(true))
	machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return _success({"product": product})


func youtiao_auto_lift_enabled() -> bool:
	return _youtiao_auto_lift_enabled and _owns_automation(YOUTIAO_AUTO_LIFT)


func set_youtiao_auto_lift_enabled(enabled: bool) -> Dictionary:
	if not _owns_automation(YOUTIAO_AUTO_LIFT):
		return _failure(&"automation_unowned")
	_youtiao_auto_lift_enabled = enabled
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return _success({"enabled": _youtiao_auto_lift_enabled})


func all_machine_snapshots() -> Dictionary:
	return {
		YOUTIAO_DEVICE: machine_snapshot(YOUTIAO_DEVICE),
		SOY_DEVICE: machine_snapshot(SOY_DEVICE),
	}


func pancake_griddles_snapshot() -> Dictionary:
	return _pancake_griddles.duplicate(true)


func set_pancake_griddles_snapshot(value: Dictionary) -> Dictionary:
	var slots := Array(value.get("slots", []))
	if slots.size() > 3:
		return _failure(&"invalid_griddle_slot_count")
	# Legacy snapshots may retain three slots. The single-stall migration keeps
	# the primary slot and drops secondary work-in-progress safely.
	if slots.size() > 1:
		slots = [slots[0]]
	_pancake_griddles = {
		"version": 2,
		"griddle_count": 1,
		"active_index": 0,
		"product_sequence": maxi(int(value.get("product_sequence", 0)), 0),
		"slots": slots.duplicate(true),
	}
	return _success({"snapshot": pancake_griddles_snapshot()})


func preview_pancake_griddle_ready(source_index: int) -> Dictionary:
	var slots := Array(_pancake_griddles.get("slots", []))
	if source_index < 0 or source_index >= slots.size():
		return _failure(&"invalid_griddle_index", {"source_index": source_index})
	var slot := Dictionary(slots[source_index])
	var product := Dictionary(slot.get("ready_product", {})).duplicate(true)
	if int(slot.get("state", 0)) != 6 or product.is_empty():
		return _failure(&"pancake_not_ready", {"source_index": source_index})
	return _success({"source_index": source_index, "product": product})


func take_pancake_griddle_ready(source_index: int) -> Dictionary:
	var preview := preview_pancake_griddle_ready(source_index)
	if not bool(preview.get("success", false)):
		return preview
	var slots := Array(_pancake_griddles.get("slots", [])).duplicate(true)
	var slot := Dictionary(slots[source_index]).duplicate(true)
	slot["state"] = 0
	slot["order"] = {}
	slot["ready_product"] = {}
	slots[source_index] = slot
	_pancake_griddles["slots"] = slots
	return _success({"source_index": source_index, "product": Dictionary(preview.get("product", {})).duplicate(true)})


func load_batch(device_id: StringName, recipe_id: StringName, quantity: int) -> Dictionary:
	if device_id == SOY_DEVICE:
		return load_soy_batch(recipe_id, quantity)
	if device_id != YOUTIAO_DEVICE:
		return _failure(&"unsupported_device", {"device_id": device_id})
	_sync_ownership()
	if not _owns_recipe(recipe_id):
		return _failure(&"recipe_locked", {"recipe_id": recipe_id})
	var recipe := CATALOG.recipe_definition(recipe_id)
	if recipe.get("area_id", &"") != &"area.youtiao":
		return _failure(&"invalid_recipe", {"recipe_id": recipe_id})
	var stock_ids: Array[StringName] = []
	var source_stock_ids: Array = Array(recipe.get("stock_ids", []))
	if source_stock_ids.size() != 1:
		return _failure(&"invalid_recipe_stock", {"recipe_id": recipe_id})
	for _unit in range(quantity):
		stock_ids.append(StringName(source_stock_ids[0]))
	var rollback := Dictionary(_youtiao.call("snapshot")).duplicate(true)
	var loaded: Dictionary = _youtiao.call("load_recipe", recipe_id, quantity)
	if not bool(loaded.get("success", false)):
		return loaded
	var consumed := _consume(stock_ids)
	if not bool(consumed.get("success", false)):
		_youtiao.call("load_snapshot", rollback)
		return consumed
	loaded["consumed_stock_ids"] = PackedStringArray(stock_ids.map(func(value): return str(value)))
	_emit_stock(stock_ids[0])
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return loaded


func perform_action(device_id: StringName, action_id: StringName) -> Dictionary:
	if device_id == SOY_DEVICE:
		return perform_soy_action(action_id)
	if device_id != YOUTIAO_DEVICE:
		return _failure(&"unsupported_device", {"device_id": device_id})
	var result: Dictionary
	match action_id:
		&"start":
			result = _youtiao.call("start")
		&"lift":
			result = _youtiao.call("lift")
		_:
			return _failure(&"unsupported_action", {"action_id": action_id})
	if bool(result.get("success", false)):
		machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return result


func preview_collect_batch(device_id: StringName, quantity: int = 1, source_index: int = -1) -> Dictionary:
	if device_id == SOY_DEVICE:
		return preview_collect_soy(quantity)
	if device_id != YOUTIAO_DEVICE:
		return _failure(&"unsupported_device", {"device_id": device_id})
	var preview: Dictionary = _youtiao.call("preview_collect_slot", source_index) if source_index >= 0 else _youtiao.call("preview_collect", quantity)
	if not bool(preview.get("success", false)):
		return preview
	var product := _new_product(StringName(preview.get("product_id", &"")), &"area.youtiao", &"room_temperature", float(preview.get("quality", 0.0)), StringName(preview.get("grade", &"waste")), false)
	product["material_cost"] = _youtiao_material_cost(StringName(product.get("product_id", &"")))
	return _success({"product": product, "quantity": quantity, "source_index": source_index})


func collect_batch(device_id: StringName, quantity: int = 1, source_index: int = -1) -> Dictionary:
	if device_id == SOY_DEVICE:
		return collect_soy(quantity)
	if device_id != YOUTIAO_DEVICE:
		return _failure(&"unsupported_device", {"device_id": device_id})
	var result: Dictionary = _youtiao.call("collect_slot", source_index) if source_index >= 0 else _youtiao.call("collect", quantity)
	if not bool(result.get("success", false)):
		return result
	var products: Array[Dictionary] = []
	for _unit in range(quantity):
		var product := _new_product(StringName(result.get("product_id", &"")), &"area.youtiao", &"room_temperature", float(result.get("quality", 0.0)), StringName(result.get("grade", &"waste")))
		product["material_cost"] = _youtiao_material_cost(StringName(product.get("product_id", &"")))
		products.append(product)
		product_created.emit(product.duplicate(true))
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return _success({"products": products, "product": products[0] if not products.is_empty() else {}, "remaining_quantity": result.get("remaining_quantity", 0), "source_index": source_index, "occupied_slot_indices": result.get("occupied_slot_indices", [])})


func discard_batch(device_id: StringName) -> Dictionary:
	if device_id == SOY_DEVICE:
		return discard_soy()
	if device_id != YOUTIAO_DEVICE:
		return _failure(&"unsupported_device", {"device_id": device_id})
	var before := machine_snapshot(YOUTIAO_DEVICE)
	var result: Dictionary = _youtiao.call("discard")
	if not bool(result.get("success", false)):
		return result
	var recipe_id := StringName(result.get("recipe_id", &""))
	var recipe := CATALOG.recipe_definition(recipe_id)
	var product_id := StringName(recipe.get("product_id", &""))
	var quantity := int(result.get("quantity", 0))
	var unit_cost := 0
	for stock_id_variant in Array(recipe.get("stock_ids", [])):
		unit_cost += _stock_cost(StringName(stock_id_variant))
	var entry := _record_waste(&"area.youtiao", YOUTIAO_DEVICE, product_id, StringName(result.get("waste_reason", &"youtiao_batch_discarded")), quantity, unit_cost * quantity)
	entry["quality_before_discard"] = float(before.get("quality", 0.0))
	entry["machine_state_before_discard"] = StringName(before.get("state", &""))
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return _success({"waste": entry})


func discard_youtiao_slot(slot_index: int) -> Dictionary:
	if slot_index < 0:
		return _failure(&"invalid_source_index")
	var before := machine_snapshot(YOUTIAO_DEVICE)
	var result: Dictionary = _youtiao.call("discard_slot", slot_index)
	if not bool(result.get("success", false)):
		return result
	var recipe := CATALOG.recipe_definition(StringName(result.get("recipe_id", &"")))
	var unit_cost := 0
	for stock_id_variant in Array(recipe.get("stock_ids", [])):
		unit_cost += _stock_cost(StringName(stock_id_variant))
	var entry := _record_waste(&"area.youtiao", YOUTIAO_DEVICE, StringName(recipe.get("product_id", &"")), StringName(result.get("waste_reason", &"youtiao_slot_discarded")), 1, unit_cost)
	entry["quality_before_discard"] = float(before.get("quality", 0.0))
	entry["machine_state_before_discard"] = StringName(before.get("state", &""))
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return _success({"waste": entry})


func load_soy_batch(recipe_id: StringName, quantity: int) -> Dictionary:
	_sync_ownership()
	if not _owns_recipe(recipe_id):
		return _failure(&"recipe_locked", {"recipe_id": recipe_id})
	var recipe := CATALOG.recipe_definition(recipe_id)
	if StringName(recipe.get("area_id", &"")) != &"area.fresh_soy_milk":
		return _failure(&"invalid_recipe", {"recipe_id": recipe_id})
	var source_stock_ids := Array(recipe.get("stock_ids", []))
	if source_stock_ids.size() != 1:
		return _failure(&"invalid_recipe_stock", {"recipe_id": recipe_id})
	var stock_id := StringName(source_stock_ids[0])
	var stock_ids: Array[StringName] = []
	for _unit in range(quantity):
		stock_ids.append(stock_id)
	var rollback := Dictionary(_soy.call("snapshot")).duplicate(true)
	var loaded: Dictionary = _soy.call("load_recipe", recipe_id, quantity)
	if not bool(loaded.get("success", false)):
		return loaded
	var consumed := _consume(stock_ids)
	if not bool(consumed.get("success", false)):
		_soy.call("load_snapshot", rollback)
		return consumed
	_emit_stock(stock_id)
	loaded["consumed_stock_ids"] = PackedStringArray(stock_ids.map(func(value): return str(value)))
	machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return loaded


func add_soy_ingredient(stock_id: StringName) -> Dictionary:
	_sync_ownership()
	var recipe_id := _soy_recipe_for_stock(stock_id)
	if recipe_id.is_empty() or not _owns_recipe(recipe_id):
		return _failure(&"recipe_locked", {"stock_id": stock_id, "recipe_id": recipe_id})
	var before := machine_snapshot(SOY_DEVICE)
	var before_counts := Dictionary(before.get("ingredient_counts", {}))
	if not before_counts.is_empty() and not before_counts.has(stock_id) and not _owns_recipe(&"recipe.fresh_soy_milk.multigrain"):
		return _failure(&"multigrain_recipe_locked")
	var rollback := Dictionary(_soy.call("snapshot")).duplicate(true)
	var added: Dictionary = _soy.call("add_ingredient", stock_id)
	if not bool(added.get("success", false)):
		return added
	var consumed := _consume([stock_id])
	if not bool(consumed.get("success", false)):
		_soy.call("load_snapshot", rollback)
		return consumed
	_emit_stock(stock_id)
	added["consumed_stock_ids"] = PackedStringArray([str(stock_id)])
	machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return added


func perform_soy_action(action_id: StringName) -> Dictionary:
	var result: Dictionary
	match action_id:
		&"add_water":
			result = _soy.call("add_water")
		&"start_water":
			result = _soy.call("start_water")
		&"stop_water":
			result = _soy.call("stop_water")
		&"start":
			result = _soy.call("start")
		&"clear_hopper":
			return clear_soy_hopper()
		_:
			return _failure(&"unsupported_action", {"action_id": action_id})
	if bool(result.get("success", false)):
		machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return result


func preview_collect_soy(quantity: int = 1) -> Dictionary:
	var preview: Dictionary = _soy.call("preview_collect", quantity)
	if not bool(preview.get("success", false)):
		return preview
	var product := _new_product(StringName(preview.get("product_id", &"")), &"area.fresh_soy_milk", &"room_temperature", float(preview.get("quality", 0.0)), StringName(preview.get("grade", &"waste")), false)
	_copy_soy_product_fields(product, preview)
	return _success({"product": product, "quantity": quantity})


func collect_soy(quantity: int = 1) -> Dictionary:
	var result: Dictionary = _soy.call("collect", quantity)
	if not bool(result.get("success", false)):
		return result
	return _commit_products_from_result(result, &"area.fresh_soy_milk", quantity, SOY_DEVICE)


func collect_soy_output(slot_index: int) -> Dictionary:
	var result: Dictionary = _soy.call("collect_output", slot_index)
	if not bool(result.get("success", false)):
		return result
	var committed := _commit_products_from_result(result, &"area.fresh_soy_milk", 1, SOY_DEVICE)
	committed["slot_index"] = slot_index
	return committed


func preview_collect_soy_output(slot_index: int) -> Dictionary:
	var snapshot := machine_snapshot(SOY_DEVICE)
	var rack := Array(snapshot.get("output_rack", []))
	if slot_index < 0 or slot_index >= rack.size() or Dictionary(rack[slot_index]).is_empty():
		return _failure(&"output_slot_empty", {"slot_index": slot_index})
	var cup := Dictionary(rack[slot_index])
	var recipe := CATALOG.recipe_definition(StringName(cup.get("recipe_id", &"")))
	var product_id := StringName(recipe.get("product_id", &""))
	if product_id.is_empty():
		return _failure(&"invalid_output_product", {"slot_index": slot_index})
	var product := _new_product(
		product_id,
		&"area.fresh_soy_milk",
		&"room_temperature",
		float(cup.get("quality", 0.0)),
		StringName(cup.get("grade", &"waste")),
		false,
	)
	_copy_soy_product_fields(product, cup)
	return _success({"product": product, "slot_index": slot_index})


func clear_soy_hopper() -> Dictionary:
	var result: Dictionary = _soy.call("clear_hopper")
	if not bool(result.get("success", false)):
		return result
	var counts := Dictionary(result.get("ingredient_counts", {}))
	var attributed_cost := 0
	for raw_stock_id in counts:
		attributed_cost += _stock_cost(StringName(raw_stock_id)) * int(counts[raw_stock_id])
	var entry := _record_waste(&"area.fresh_soy_milk", SOY_DEVICE, &"", &"soy_hopper_cleared", int(result.get("quantity", 0)), attributed_cost)
	entry["ingredient_counts"] = counts.duplicate(true)
	machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return _success({"waste": entry, "ingredient_counts": counts})


func discard_soy(cup_index: int = 0) -> Dictionary:
	var before := machine_snapshot(SOY_DEVICE)
	var result: Dictionary = _soy.call("discard", cup_index)
	if not bool(result.get("success", false)):
		return result
	var product := Dictionary(result.get("product", {}))
	var recipe := CATALOG.recipe_definition(StringName(product.get("recipe_id", result.get("recipe_id", &""))))
	var stock_ids := Array(recipe.get("stock_ids", []))
	var attributed_cost := 0
	var ingredient_counts := Dictionary(result.get("ingredient_counts", {}))
	if ingredient_counts.is_empty():
		attributed_cost = (_stock_cost(StringName(stock_ids[0])) if not stock_ids.is_empty() else 0) * int(result.get("quantity", 0))
	else:
		for raw_stock_id in ingredient_counts:
			attributed_cost += _stock_cost(StringName(raw_stock_id)) * int(ingredient_counts[raw_stock_id])
	var entry := _record_waste(&"area.fresh_soy_milk", SOY_DEVICE, StringName(product.get("product_id", recipe.get("product_id", &""))), StringName(result.get("waste_reason", &"soy_cup_discarded")), maxi(int(result.get("quantity", 1)), 1), attributed_cost)
	entry["quality_before_discard"] = float(before.get("quality", 0.0))
	machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return _success({"waste": entry})


func discard_soy_output(slot_index: int) -> Dictionary:
	var result: Dictionary = _soy.call("discard_output", slot_index)
	if not bool(result.get("success", false)):
		return result
	var recipe := CATALOG.recipe_definition(StringName(result.get("recipe_id", &"")))
	var stock_ids := Array(recipe.get("stock_ids", []))
	var unit_cost := _stock_cost(StringName(stock_ids[0])) if not stock_ids.is_empty() else 0
	if stock_ids.is_empty():
		for raw_stock_id in PackedStringArray(result.get("ingredient_ids", PackedStringArray())):
			unit_cost += _stock_cost(StringName(raw_stock_id))
	var entry := _record_waste(&"area.fresh_soy_milk", &"output.fresh_soy_milk", StringName(recipe.get("product_id", &"")), &"soy_output_discarded", 1, unit_cost)
	machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return _success({"waste": entry})


func waste_events() -> Array[Dictionary]:
	return _waste_events.duplicate(true)


func record_staged_waste(product: Dictionary, reason: StringName = &"staged_product_discarded") -> Dictionary:
	var product_id := StringName(product.get("product_id", &""))
	if product_id.is_empty():
		return _failure(&"invalid_product")
	var definition := CATALOG.product_definition(product_id)
	var stock_id := StringName(definition.get("stock_id", &""))
	var attributed_cost := maxi(int(product.get("material_cost", _stock_cost(stock_id))), 0)
	var entry := _record_waste(
		StringName(product.get("area_id", definition.get("area_id", &""))),
		&"customer_handoff_tray",
		product_id,
		reason,
		1,
		attributed_cost,
	)
	return _success({"waste": entry})


func clear_for_day_end() -> Dictionary:
	var cleared_waste: Array[Dictionary] = []
	var griddle_slots := Array(_pancake_griddles.get("slots", []))
	for slot_index in range(griddle_slots.size()):
		var slot := Dictionary(griddle_slots[slot_index])
		if int(slot.get("state", 0)) <= 0:
			continue
		var ready_product := Dictionary(slot.get("ready_product", {}))
		var attributed_cost := maxi(int(ready_product.get("material_cost", 0)), 0)
		if ready_product.is_empty():
			attributed_cost = _stock_cost(&"stock.pancake.batter")
			for stock_value in PackedStringArray(slot.get("applied_ingredient_ids", PackedStringArray())):
				attributed_cost += _stock_cost(StringName(stock_value))
			for stock_value in PackedStringArray(slot.get("applied_sauce_ids", PackedStringArray())):
				attributed_cost += _stock_cost(StringName(stock_value))
		cleared_waste.append(_record_waste(
			&"area.pancake",
			StringName("pancake_griddle.%d" % (slot_index + 1)),
			StringName(ready_product.get("product_id", &"product.pancake.custom")),
			&"day_end_unsold_product" if not ready_product.is_empty() else &"day_end_work_in_progress",
			1,
			attributed_cost,
		))
	_pancake_griddles = {
		"version": 2,
		"griddle_count": 1,
		"active_index": 0,
		"product_sequence": maxi(int(_pancake_griddles.get("product_sequence", 0)), 0),
		"slots": [],
	}

	var youtiao_snapshot := machine_snapshot(YOUTIAO_DEVICE)
	var youtiao_quantity := maxi(int(youtiao_snapshot.get("quantity", 0)), 0)
	if youtiao_quantity > 0:
		var youtiao_recipe := CATALOG.recipe_definition(StringName(youtiao_snapshot.get("recipe_id", &"")))
		var youtiao_unit_cost := 0
		for stock_value in Array(youtiao_recipe.get("stock_ids", [])):
			youtiao_unit_cost += _stock_cost(StringName(stock_value))
		cleared_waste.append(_record_waste(
			&"area.youtiao",
			YOUTIAO_DEVICE,
			StringName(youtiao_recipe.get("product_id", &"")),
			&"day_end_unsold_product" if StringName(youtiao_snapshot.get("state", &"")) in [&"ready_safe", &"draining", &"ready_to_collect"] else &"day_end_work_in_progress",
			youtiao_quantity,
			youtiao_unit_cost * youtiao_quantity,
		))
	_youtiao.call("load_snapshot", {
		"owned": bool(youtiao_snapshot.get("owned", false)),
		"tier": int(youtiao_snapshot.get("tier", 0)),
		"state": &"idle",
	})

	var soy_snapshot := machine_snapshot(SOY_DEVICE)
	var soy_cup_clear := Dictionary(_soy.call("clear_for_day_end"))
	var soy_cup_products: Array = Array(soy_cup_clear.get("discarded_products", []))
	if soy_cup_products.is_empty():
		var legacy_soy_cup_product := Dictionary(soy_cup_clear.get("discarded_product", {}))
		if not legacy_soy_cup_product.is_empty():
			soy_cup_products.append(legacy_soy_cup_product)
	for raw_soy_cup_product in soy_cup_products:
		var soy_cup_product := Dictionary(raw_soy_cup_product)
		if soy_cup_product.is_empty():
			continue
		var soy_cup_product_id := StringName(soy_cup_product.get("product_id", &""))
		var soy_cup_cost := maxi(int(soy_cup_product.get("material_cost", CATALOG.product_definition(soy_cup_product_id).get("material_cost", 0))), 0)
		cleared_waste.append(_record_waste(
			&"area.fresh_soy_milk",
			&"fresh_soy_cup",
			soy_cup_product_id,
			&"day_end_unsold_product",
			1,
			soy_cup_cost,
		))
	var soy_counts := Dictionary(soy_snapshot.get("ingredient_counts", {}))
	var soy_quantity := maxi(int(soy_snapshot.get("quantity", 0)), 0)
	if soy_quantity > 0 or not soy_counts.is_empty():
		var soy_cost := 0
		for stock_value in soy_counts:
			soy_cost += _stock_cost(StringName(stock_value)) * maxi(int(soy_counts[stock_value]), 0)
		cleared_waste.append(_record_waste(
			&"area.fresh_soy_milk",
			SOY_DEVICE,
			StringName(CATALOG.recipe_definition(StringName(soy_snapshot.get("recipe_id", &""))).get("product_id", &"")),
			&"day_end_unsold_product" if StringName(soy_snapshot.get("state", &"")) in [&"ready_safe", &"overcooking", &"blocked", &"spoiled"] else &"day_end_work_in_progress",
			maxi(soy_quantity, 1),
			soy_cost,
		))
	for rack_index in range(Array(soy_snapshot.get("output_rack", [])).size()):
		var cup := Dictionary(Array(soy_snapshot.get("output_rack", []))[rack_index])
		if cup.is_empty():
			continue
		var cup_cost := 0
		var cup_ingredient_ids := PackedStringArray(cup.get("ingredient_ids", PackedStringArray()))
		if cup_ingredient_ids.is_empty():
			for stock_value in Array(CATALOG.recipe_definition(StringName(cup.get("recipe_id", &""))).get("stock_ids", [])):
				cup_cost += _stock_cost(StringName(stock_value))
		else:
			for stock_value in cup_ingredient_ids:
				cup_cost += _stock_cost(StringName(stock_value))
		cleared_waste.append(_record_waste(
			&"area.fresh_soy_milk",
			StringName("fresh_soy_output.%d" % rack_index),
			StringName(CATALOG.recipe_definition(StringName(cup.get("recipe_id", &""))).get("product_id", &"")),
			&"day_end_unsold_product",
			1,
			cup_cost,
		))
	_soy.call("load_snapshot", {
		"owned": bool(soy_snapshot.get("owned", false)),
		"tier": int(soy_snapshot.get("tier", 0)),
		"state": &"idle",
		"output_rack": [{}, {}, {}, {}],
	})
	_sync_ownership()
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))
	return _success({"waste": cleared_waste})


func snapshot() -> Dictionary:
	return {
		"version": 6,
		"product_sequence": _product_sequence,
		"pancake_griddles": pancake_griddles_snapshot(),
		"youtiao_fryer": _youtiao.call("snapshot"),
		"youtiao_auto_lift_enabled": _youtiao_auto_lift_enabled,
		"fresh_soy_milk_machine": _soy.call("snapshot"),
		"waste_events": _waste_events.duplicate(true),
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	_product_sequence = maxi(int(value.get("product_sequence", 0)), 0)
	_youtiao_auto_lift_enabled = bool(value.get("youtiao_auto_lift_enabled", true))
	set_pancake_griddles_snapshot(Dictionary(value.get("pancake_griddles", {"version": 1, "griddle_count": 1, "active_index": 0, "product_sequence": 0, "slots": []})))
	_waste_events = []
	for entry_value in Array(value.get("waste_events", [])):
		_waste_events.append(Dictionary(entry_value).duplicate(true))
	_sync_ownership()
	var youtiao_result: Dictionary = _youtiao.call("load_snapshot", Dictionary(value.get("youtiao_fryer", {})))
	var soy_result: Dictionary = _soy.call("load_snapshot", Dictionary(value.get("fresh_soy_milk_machine", {})))
	if not bool(youtiao_result.get("success", false)):
		return youtiao_result
	if not bool(soy_result.get("success", false)):
		return soy_result
	# Progression ownership is authoritative even when an older production
	# snapshot still says that a split-out device was installed.
	_sync_ownership()
	return {"success": true}


func _sync_ownership() -> void:
	if _progression == null:
		return
	if bool(_progression.call("owns_area", &"area.youtiao")):
		_youtiao.call("configure_owned", int(_progression.call("device_tier", YOUTIAO_DEVICE)))
	if bool(_progression.call("owns_area", &"area.fresh_soy_milk")):
		_soy.call("configure_owned", int(_progression.call("device_tier", SOY_DEVICE)))
		_configure_soy_serving_upgrades()


func _configure_soy_serving_upgrades() -> void:
	if _progression == null:
		return
	var recipes: Array[StringName] = []
	for recipe_id in SOY_MODEL.SOY_RECIPE_IDS:
		if _owns_recipe(recipe_id):
			recipes.append(recipe_id)
	_soy.call("configure_available_recipes", recipes)
	_soy.call(
		"configure_upgrades",
		false,
		_owns_automation(&"automation.fresh_soy_milk.auto_fill"),
		_owns_assist(&"assist.fresh_soy_milk.sugar"),
		_owns_assist(&"assist.fresh_soy_milk.ice"),
		_owns_automation(&"automation.fresh_soy_milk.double_fill")
	)


func _owns_recipe(recipe_id: StringName) -> bool:
	return _progression != null and bool(_progression.call("owns_recipe", recipe_id))


func _owns_automation(automation_id: StringName) -> bool:
	return _progression != null and bool(_progression.call("owns_automation", automation_id))


func _owns_assist(assist_id: StringName) -> bool:
	return _progression != null and bool(_progression.call("owns_assist", assist_id))


func _owns_growth(growth_id: StringName) -> bool:
	return _progression != null and bool(_progression.call("owns_growth", growth_id))


func _consume(stock_ids: Array[StringName]) -> Dictionary:
	if _session == null or not _session.has_method("consume_inventory_stock_ids"):
		return _failure(&"inventory_unavailable")
	return Dictionary(_session.call("consume_inventory_stock_ids", stock_ids))


func _emit_stock(stock_id: StringName) -> void:
	if _session == null or not _session.has_method("inventory_snapshot"):
		return
	var inventory: Dictionary = _session.call("inventory_snapshot")
	stock_changed.emit(stock_id, int(inventory.get(str(stock_id), 0)))


func _new_product(product_id: StringName, area_id: StringName, temperature_mode: StringName, quality: float, grade: StringName, commit_sequence: bool = true) -> Dictionary:
	var next_sequence := _product_sequence + 1
	if commit_sequence:
		_product_sequence = next_sequence
	return {
		"product_instance_id": StringName("runtime.product.%06d" % next_sequence),
		"area_id": area_id,
		"product_id": product_id,
		"quantity": 1,
		"quality": quality,
		"grade": grade,
		"temperature_mode": temperature_mode,
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"status": &"available",
		"owner_order_id": &"",
	}


func _commit_products_from_result(result: Dictionary, area_id: StringName, quantity: int, source_device_id: StringName) -> Dictionary:
	var products: Array[Dictionary] = []
	for _unit in range(maxi(quantity, 0)):
		var product := _new_product(StringName(result.get("product_id", &"")), area_id, &"room_temperature", float(result.get("quality", 0.0)), StringName(result.get("grade", &"waste")))
		if area_id == &"area.fresh_soy_milk":
			_copy_soy_product_fields(product, result)
		products.append(product)
		product_created.emit(product.duplicate(true))
	machine_changed.emit(source_device_id, machine_snapshot(source_device_id))
	return _success({"products": products, "product": products[0] if not products.is_empty() else {}, "remaining_quantity": result.get("remaining_quantity", 0)})


func _record_waste(area_id: StringName, source_id: StringName, product_id: StringName, reason: StringName, quantity: int, attributed_cost: int) -> Dictionary:
	var entry := {
		"event_id": StringName("waste.%06d" % (_waste_events.size() + 1)),
		"area_id": area_id,
		"source_id": source_id,
		"product_id": product_id,
		"reason": reason,
		"quantity": quantity,
		"attributed_cost": attributed_cost,
	}
	_waste_events.append(entry)
	waste_recorded.emit(entry.duplicate(true))
	return entry


static func _stock_cost(stock_id: StringName) -> int:
	return maxi(int(CATALOG.stock_definition(stock_id).get("restock_unit_cost", 0)), 0)


static func _youtiao_material_cost(product_id: StringName) -> int:
	var product_definition := CATALOG.product_definition(product_id)
	var recipe_definition := CATALOG.recipe_definition(StringName(product_definition.get("recipe_id", &"")))
	var stock_ids: Array = Array(recipe_definition.get("stock_ids", []))
	return _stock_cost(StringName(stock_ids[0])) if not stock_ids.is_empty() else 0


func _copy_soy_product_fields(product: Dictionary, source: Dictionary) -> void:
	product["ingredient_ids"] = PackedStringArray(source.get("ingredient_ids", PackedStringArray()))
	product["quality_multiplier"] = float(source.get("quality_multiplier", 1.0))
	product["fill_ratio"] = float(source.get("fill_ratio", 1.0))
	product["sugar_servings"] = int(source.get("sugar_servings", 0))
	var material_cost := 0
	if product["ingredient_ids"].is_empty():
		var recipe := CATALOG.recipe_definition(StringName(CATALOG.product_definition(StringName(product.get("product_id", &""))).get("recipe_id", &"")))
		var stocks := Array(recipe.get("stock_ids", []))
		if not stocks.is_empty():
			material_cost = _stock_cost(StringName(stocks[0]))
	else:
		for raw_stock_id in product["ingredient_ids"]:
			material_cost += _stock_cost(StringName(raw_stock_id))
	product["material_cost"] = material_cost


static func _soy_recipe_for_stock(stock_id: StringName) -> StringName:
	match stock_id:
		&"stock.fresh_soy_milk.yellow_bean": return &"recipe.fresh_soy_milk.yellow_bean"
	return &""


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


static func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
