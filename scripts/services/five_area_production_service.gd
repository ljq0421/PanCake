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

var _session: Node
var _progression: RefCounted
var _youtiao: RefCounted = YOUTIAO_MODEL.new()
var _soy: RefCounted = SOY_MODEL.new()
var _product_sequence := 0
var _waste_events: Array[Dictionary] = []
var _pancake_griddles: Dictionary = {"version": 1, "griddle_count": 1, "active_index": 0, "product_sequence": 0, "slots": []}


func _init(session: Node = null, initial_snapshot: Dictionary = {}) -> void:
	if session != null:
		configure(session.call("progression_service") if session.has_method("progression_service") else null, session)
	if not initial_snapshot.is_empty():
		load_snapshot(initial_snapshot)


func configure(progression: RefCounted, session: Node) -> void:
	_progression = progression
	_session = session
	_sync_ownership()


func advance_time(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if step <= 0.0:
		return
	_sync_ownership()
	_youtiao.call("advance_time", step, _owns_automation(&"automation.youtiao.auto_lift"))
	_soy.call("advance_time", step, _owns_automation(&"automation.fresh_soy_milk.auto_cup_rack"))
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	machine_changed.emit(SOY_DEVICE, machine_snapshot(SOY_DEVICE))


func machine_snapshot(device_id: StringName) -> Dictionary:
	_sync_ownership()
	if device_id == YOUTIAO_DEVICE:
		return Dictionary(_youtiao.call("snapshot")).duplicate(true)
	if device_id == SOY_DEVICE:
		return Dictionary(_soy.call("snapshot")).duplicate(true)
	return {"device_id": device_id, "owned": false, "state": &"unsupported"}


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
	var griddle_count := clampi(int(value.get("griddle_count", 1)), 1, 3)
	_pancake_griddles = {
		"version": 1,
		"griddle_count": griddle_count,
		"active_index": clampi(int(value.get("active_index", 0)), 0, griddle_count - 1),
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


func discard_ready_youtiao(source_index: int = -1) -> Dictionary:
	var before := machine_snapshot(YOUTIAO_DEVICE)
	var result: Dictionary = _youtiao.call("discard_slot", source_index) if source_index >= 0 else _youtiao.call("collect", 1)
	if not bool(result.get("success", false)):
		return result
	var recipe_id := StringName(result.get("recipe_id", before.get("recipe_id", &"")))
	var product_id := StringName(result.get("product_id", CATALOG.recipe_definition(recipe_id).get("product_id", &"")))
	var reason := StringName(result.get("waste_reason", &"youtiao_output_discarded"))
	var entry := _record_waste(&"area.youtiao", StringName("output.youtiao.slot.%d" % source_index) if source_index >= 0 else &"output.youtiao", product_id, reason, 1, _youtiao_material_cost(product_id))
	entry["quality_before_discard"] = float(before.get("quality", 0.0))
	entry["machine_state_before_discard"] = StringName(before.get("state", &""))
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return _success({"waste": entry, "remaining_quantity": int(result.get("remaining_quantity", 0)), "source_index": source_index, "occupied_slot_indices": result.get("occupied_slot_indices", [])})


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


func perform_soy_action(action_id: StringName) -> Dictionary:
	var result: Dictionary
	match action_id:
		&"add_water":
			result = _soy.call("add_water")
		&"start":
			result = _soy.call("start")
		&"fill_cup":
			result = _soy.call("fill_manual_cup")
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
	return _success({"product": product, "slot_index": slot_index})


func discard_soy() -> Dictionary:
	var before := machine_snapshot(SOY_DEVICE)
	var result: Dictionary = _soy.call("discard")
	if not bool(result.get("success", false)):
		return result
	var recipe := CATALOG.recipe_definition(StringName(result.get("recipe_id", &"")))
	var stock_ids := Array(recipe.get("stock_ids", []))
	var unit_cost := _stock_cost(StringName(stock_ids[0])) if not stock_ids.is_empty() else 0
	var entry := _record_waste(&"area.fresh_soy_milk", SOY_DEVICE, StringName(recipe.get("product_id", &"")), &"soy_spoiled", int(result.get("quantity", 0)), unit_cost * int(result.get("quantity", 0)))
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


func snapshot() -> Dictionary:
	return {
		"version": 4,
		"product_sequence": _product_sequence,
		"pancake_griddles": pancake_griddles_snapshot(),
		"youtiao_fryer": _youtiao.call("snapshot"),
		"fresh_soy_milk_machine": _soy.call("snapshot"),
		"waste_events": _waste_events.duplicate(true),
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	_product_sequence = maxi(int(value.get("product_sequence", 0)), 0)
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


func _owns_recipe(recipe_id: StringName) -> bool:
	return _progression != null and bool(_progression.call("owns_recipe", recipe_id))


func _owns_automation(automation_id: StringName) -> bool:
	return _progression != null and bool(_progression.call("owns_automation", automation_id))


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


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


static func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
