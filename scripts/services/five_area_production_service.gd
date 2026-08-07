class_name FiveAreaProductionService
extends RefCounted

signal machine_changed(device_id: StringName, snapshot: Dictionary)
signal product_created(product: Dictionary)
signal waste_recorded(entry: Dictionary)
signal stock_changed(stock_id: StringName, current: int)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const DRINK_MODEL := preload("res://scripts/gameplay/packaged_drink_heater_model.gd")
const YOUTIAO_MODEL := preload("res://scripts/gameplay/youtiao_fryer_model.gd")
const DRINK_DEVICE := &"device.packaged_drink_heater"
const YOUTIAO_DEVICE := &"device.youtiao_fryer"

var _session: Node
var _progression: RefCounted
var _drink: RefCounted = DRINK_MODEL.new()
var _youtiao: RefCounted = YOUTIAO_MODEL.new()
var _product_sequence := 0
var _waste_events: Array[Dictionary] = []
var _youtiao_job_profile: Dictionary = {}


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
	_drink.call("advance_time", step)
	_youtiao.call("advance_time", step, _owns_automation(&"automation.youtiao.auto_lift"))
	machine_changed.emit(DRINK_DEVICE, machine_snapshot(DRINK_DEVICE))
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))


func machine_snapshot(device_id: StringName) -> Dictionary:
	_sync_ownership()
	if device_id == DRINK_DEVICE:
		return Dictionary(_drink.call("snapshot")).duplicate(true)
	if device_id == YOUTIAO_DEVICE:
		return Dictionary(_youtiao.call("snapshot")).duplicate(true)
	return {"device_id": device_id, "owned": false, "state": &"unsupported"}


func all_machine_snapshots() -> Dictionary:
	return {
		DRINK_DEVICE: machine_snapshot(DRINK_DEVICE),
		YOUTIAO_DEVICE: machine_snapshot(YOUTIAO_DEVICE),
	}


func load_drink(slot_index: int, product_id: StringName) -> Dictionary:
	_sync_ownership()
	if not _owns_product(product_id):
		return _failure(&"product_locked", {"product_id": product_id})
	var product_definition := CATALOG.product_definition(product_id)
	var stock_id: StringName = product_definition.get("stock_id", &"")
	if stock_id.is_empty():
		return _failure(&"product_stock_missing", {"product_id": product_id})
	var rollback := Dictionary(_drink.call("snapshot")).duplicate(true)
	var loaded: Dictionary = _drink.call("load_product", slot_index, product_id)
	if not bool(loaded.get("success", false)):
		return loaded
	var consumed := _consume([stock_id])
	if not bool(consumed.get("success", false)):
		_drink.call("load_snapshot", rollback)
		return consumed
	loaded["consumed_stock_ids"] = PackedStringArray([str(stock_id)])
	_emit_stock(stock_id)
	machine_changed.emit(DRINK_DEVICE, machine_snapshot(DRINK_DEVICE))
	return loaded


func create_room_temperature_drink(product_id: StringName) -> Dictionary:
	if not _owns_product(product_id):
		return _failure(&"product_locked", {"product_id": product_id})
	var definition := CATALOG.product_definition(product_id)
	if definition.get("area_id", &"") != &"area.packaged_drink":
		return _failure(&"invalid_drink_product", {"product_id": product_id})
	var stock_id: StringName = definition.get("stock_id", &"")
	var consumed := _consume([stock_id])
	if not bool(consumed.get("success", false)):
		return consumed
	var product := _new_product(product_id, &"area.packaged_drink", &"room_temperature", 100.0, &"A")
	_emit_stock(stock_id)
	product_created.emit(product.duplicate(true))
	return _success({"product": product, "consumed_stock_ids": PackedStringArray([str(stock_id)])})


func preview_collect_drink(slot_index: int) -> Dictionary:
	var preview: Dictionary = _drink.call("preview_collect", slot_index)
	if not bool(preview.get("success", false)):
		return preview
	var product := _new_product(StringName(preview.get("product_id", &"")), &"area.packaged_drink", &"heated", 100.0, &"A", false)
	return _success({"slot_index": slot_index, "product": product})


func collect_drink(slot_index: int) -> Dictionary:
	var result: Dictionary = _drink.call("collect", slot_index)
	if not bool(result.get("success", false)):
		return result
	var product := _new_product(StringName(result.get("product_id", &"")), &"area.packaged_drink", &"heated", 100.0, &"A")
	product_created.emit(product.duplicate(true))
	machine_changed.emit(DRINK_DEVICE, machine_snapshot(DRINK_DEVICE))
	return _success({"slot_index": slot_index, "product": product})


func discard_drink(slot_index: int) -> Dictionary:
	var result: Dictionary = _drink.call("discard", slot_index)
	if not bool(result.get("success", false)):
		return result
	var product_id := StringName(result.get("product_id", &""))
	var product := CATALOG.product_definition(product_id)
	var stock_id := StringName(product.get("stock_id", &""))
	var entry := _record_waste(&"area.packaged_drink", DRINK_DEVICE, product_id, &"cooled_drink", 1, _stock_cost(stock_id))
	machine_changed.emit(DRINK_DEVICE, machine_snapshot(DRINK_DEVICE))
	return _success({"waste": entry})


func load_batch(device_id: StringName, recipe_id: StringName, quantity: int) -> Dictionary:
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


func preview_collect_batch(device_id: StringName, quantity: int = 1) -> Dictionary:
	if device_id != YOUTIAO_DEVICE:
		return _failure(&"unsupported_device", {"device_id": device_id})
	var preview: Dictionary = _youtiao.call("preview_collect", quantity)
	if not bool(preview.get("success", false)):
		return preview
	var product := _new_product(StringName(preview.get("product_id", &"")), &"area.youtiao", &"room_temperature", float(preview.get("quality", 0.0)), StringName(preview.get("grade", &"waste")), false)
	return _success({"product": product, "quantity": quantity})


func collect_batch(device_id: StringName, quantity: int = 1) -> Dictionary:
	if device_id != YOUTIAO_DEVICE:
		return _failure(&"unsupported_device", {"device_id": device_id})
	var result: Dictionary = _youtiao.call("collect", quantity)
	if not bool(result.get("success", false)):
		return result
	var products: Array[Dictionary] = []
	for _unit in range(quantity):
		var product := _new_product(StringName(result.get("product_id", &"")), &"area.youtiao", &"room_temperature", float(result.get("quality", 0.0)), StringName(result.get("grade", &"waste")))
		products.append(product)
		product_created.emit(product.duplicate(true))
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return _success({"products": products, "product": products[0] if not products.is_empty() else {}, "remaining_quantity": result.get("remaining_quantity", 0)})


func discard_batch(device_id: StringName) -> Dictionary:
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
	var entry := _record_waste(&"area.youtiao", YOUTIAO_DEVICE, product_id, &"burnt_batch", quantity, unit_cost * quantity)
	entry["quality_before_discard"] = float(before.get("quality", 0.0))
	machine_changed.emit(YOUTIAO_DEVICE, machine_snapshot(YOUTIAO_DEVICE))
	return _success({"waste": entry})


func confirm_youtiao_job_profile(recipe_id: StringName, quantity: int) -> Dictionary:
	if not _owns_automation(&"automation.youtiao.auto_load"):
		return _failure(&"automation_not_owned")
	if not _owns_recipe(recipe_id) or quantity <= 0:
		return _failure(&"invalid_job_profile")
	_youtiao_job_profile = {"recipe_id": recipe_id, "quantity": quantity, "confirmed": true}
	return _success({"job_profile": _youtiao_job_profile.duplicate(true)})


func run_confirmed_youtiao_auto_load() -> Dictionary:
	if not bool(_youtiao_job_profile.get("confirmed", false)):
		return _failure(&"job_profile_not_confirmed")
	return load_batch(YOUTIAO_DEVICE, StringName(_youtiao_job_profile.get("recipe_id", &"")), int(_youtiao_job_profile.get("quantity", 0)))


func waste_events() -> Array[Dictionary]:
	return _waste_events.duplicate(true)


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"product_sequence": _product_sequence,
		"packaged_drink_heater": _drink.call("snapshot"),
		"youtiao_fryer": _youtiao.call("snapshot"),
		"waste_events": _waste_events.duplicate(true),
		"youtiao_job_profile": _youtiao_job_profile.duplicate(true),
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	_product_sequence = maxi(int(value.get("product_sequence", 0)), 0)
	_waste_events = []
	for entry_value in Array(value.get("waste_events", [])):
		_waste_events.append(Dictionary(entry_value).duplicate(true))
	_youtiao_job_profile = Dictionary(value.get("youtiao_job_profile", {})).duplicate(true)
	_sync_ownership()
	var drink_result: Dictionary = _drink.call("load_snapshot", Dictionary(value.get("packaged_drink_heater", {})))
	var youtiao_result: Dictionary = _youtiao.call("load_snapshot", Dictionary(value.get("youtiao_fryer", {})))
	if not bool(drink_result.get("success", false)):
		return drink_result
	return youtiao_result


func _sync_ownership() -> void:
	if _progression == null:
		return
	if bool(_progression.call("owns_area", &"area.packaged_drink")):
		_drink.call("configure_owned", int(_progression.call("device_tier", DRINK_DEVICE)))
	if bool(_progression.call("owns_area", &"area.youtiao")):
		_youtiao.call("configure_owned", int(_progression.call("device_tier", YOUTIAO_DEVICE)))


func _owns_product(product_id: StringName) -> bool:
	return _progression != null and _progression.has_method("owns_product") and bool(_progression.call("owns_product", product_id))


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


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


static func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
