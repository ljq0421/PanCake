extends RefCounted

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const EQUIPMENT_BATCH_MODEL := preload("res://scripts/gameplay/equipment_batch_model.gd")

var progression: RefCounted
var _machines := {}
var _collected_products: Array[Dictionary] = []


func _init(next_progression: RefCounted) -> void:
	progression = next_progression
	for device_id in CATALOG.DEVICE_DEFINITIONS:
		_machines[device_id] = EQUIPMENT_BATCH_MODEL.new(device_id)
	_sync_machine_ownership()


func load_input(device_id: StringName, recipe_id: StringName, quantity: int = 1) -> Dictionary:
	return _load_consuming_stock(device_id, recipe_id, quantity)


func automated_load(device_id: StringName, recipe_id: StringName, quantity: int = 1) -> Dictionary:
	var module_id := CATALOG.automation_for(device_id, &"auto_load")
	if module_id.is_empty() or not bool(progression.call("owns", module_id)):
		return _failure(&"automation_not_owned", {"required_module": module_id})
	return _load_consuming_stock(device_id, recipe_id, quantity)


func perform_action(device_id: StringName, action: StringName) -> Dictionary:
	var machine := _machine(device_id)
	if machine == null:
		return _failure(&"unknown_equipment")
	return machine.call("perform_action", action)


func start(device_id: StringName) -> Dictionary:
	var machine := _machine(device_id)
	if machine == null:
		return _failure(&"unknown_equipment")
	return machine.call("start")


func advance_time(delta: float) -> void:
	_sync_machine_ownership()
	for machine in _machines.values():
		machine.call("advance_time", delta)
	_run_completion_automation()


func collect(device_id: StringName, quantity: int = 1) -> Dictionary:
	var machine := _machine(device_id)
	if machine == null:
		return _failure(&"unknown_equipment")
	return machine.call("collect", quantity)


func add_topping(product: Dictionary, add_on_id: StringName) -> Dictionary:
	if not bool(progression.call("is_recipe_unlocked", add_on_id)):
		return _failure(&"recipe_not_unlocked")
	var definition := CATALOG.recipe_definition(add_on_id)
	if definition.get("kind", &"") != &"add_on":
		return _failure(&"invalid_add_on")
	var stock_id: StringName = definition.get("stock_id", &"")
	var inventory: RefCounted = progression.get("inventory")
	if int(inventory.call("current", stock_id)) < 1:
		return _failure(&"insufficient_input_stock", {"stock_id": stock_id})
	var decorated: Dictionary = EQUIPMENT_BATCH_MODEL.decorate_product(product, add_on_id)
	if not bool(decorated.get("success", false)):
		return decorated
	inventory.call("consume", stock_id)
	decorated["consumed_stock_id"] = stock_id
	return decorated


func machine_snapshot(device_id: StringName) -> Dictionary:
	var machine := _machine(device_id)
	if machine == null:
		return {"owned": false, "has_output": false, "state": &"unknown"}
	return machine.call("snapshot")


func take_automated_products() -> Array[Dictionary]:
	var result := _collected_products.duplicate(true)
	_collected_products.clear()
	return result


func _load_consuming_stock(device_id: StringName, recipe_id: StringName, quantity: int) -> Dictionary:
	_sync_machine_ownership()
	var machine := _machine(device_id)
	if machine == null:
		return _failure(&"unknown_equipment")
	if not bool(progression.call("owns_equipment", device_id)):
		return _failure(&"equipment_not_owned")
	if not bool(progression.call("is_recipe_unlocked", recipe_id)):
		return _failure(&"recipe_not_unlocked")
	var definition := CATALOG.recipe_definition(recipe_id)
	if definition.get("kind", &"") != &"main" or definition.get("device_id", &"") != device_id:
		return _failure(&"invalid_main_recipe")
	var stock_id: StringName = definition.get("stock_id", &"")
	var inventory: RefCounted = progression.get("inventory")
	if quantity <= 0:
		return _failure(&"invalid_quantity")
	if int(inventory.call("current", stock_id)) < quantity:
		return _failure(&"insufficient_input_stock", {"stock_id": stock_id, "required_quantity": quantity})
	var loaded: Dictionary = machine.call("load_input", recipe_id, quantity)
	if not bool(loaded.get("success", false)):
		return loaded
	if not bool(inventory.call("consume_many", stock_id, quantity)):
		return _failure(&"inventory_transaction_failed")
	loaded["consumed_stock_id"] = stock_id
	loaded["consumed_quantity"] = quantity
	return loaded


func _sync_machine_ownership() -> void:
	for device_id in _machines:
		var tier := int(progression.call("equipment_tier", device_id))
		if tier >= CATALOG.TIER_BASIC:
			(_machines[device_id] as RefCounted).call("configure_owned", tier)


func _run_completion_automation() -> void:
	for device_id in _machines:
		var machine: RefCounted = _machines[device_id]
		if not bool(machine.call("has_output")):
			continue
		if device_id == CATALOG.DEVICE_EGG_WAFFLE and progression.call("owns", CATALOG.AUTO_EGG_WAFFLE_OPEN):
			machine.call("perform_action", CATALOG.ACTION_OPEN_LID)
		var extract_module := CATALOG.automation_for(device_id, &"auto_extract")
		if extract_module.is_empty() or not bool(progression.call("owns", extract_module)):
			continue
		if device_id == CATALOG.DEVICE_YOUTIAO:
			machine.call("perform_action", CATALOG.ACTION_DRAIN_OIL)
		var result: Dictionary = machine.call("collect", int(machine.get("loaded_quantity")))
		if bool(result.get("success", false)):
			_collected_products.append(result.product)


func _machine(device_id: StringName) -> RefCounted:
	return _machines.get(device_id) as RefCounted


func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
