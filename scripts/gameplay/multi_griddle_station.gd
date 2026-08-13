class_name MultiGriddleStation
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_SCORER := preload("res://scripts/gameplay/pancake_scorer.gd")
const UNIT_SCRIPT := preload("res://scripts/gameplay/compact_griddle_unit.gd")

@onready var count_label: Label = %CountLabel
@onready var units: Array[Node] = [%Griddle01, %Griddle02, %Griddle03]

var _session: Node
var _order_provider := Callable()
var _active_count := 1
var _active_index := 0
var _product_sequence := 0
var _save_elapsed := 0.0
var _last_tree_paused := false


func _ready() -> void:
	# Persist pause transitions while each individual griddle remains pausable.
	# This records the exact slots without advancing heat behind the pause UI.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_tree_paused = get_tree().paused
	for index in units.size():
		var unit: Node = units[index]
		unit.configure(index)
		unit.main_action_requested.connect(_on_main_action)
		unit.sauce_action_requested.connect(_on_sauce_action)
		unit.ingredient_action_requested.connect(_on_ingredient_action)
		unit.fold_action_requested.connect(_on_fold_action)
		unit.discard_requested.connect(_on_discard)
	_apply_count_layout()


func bind_session(session: Node, order_provider: Callable) -> void:
	_session = session
	_order_provider = order_provider
	if is_node_ready() and _session != null and _session.has_method("five_area_pancake_griddles_snapshot"):
		load_snapshot(Dictionary(_session.call("five_area_pancake_griddles_snapshot")))


func _process(delta: float) -> void:
	var tree_paused := get_tree().paused
	if tree_paused != _last_tree_paused:
		_last_tree_paused = tree_paused
		_sync_snapshot_to_session()
	_save_elapsed += maxf(delta, 0.0)
	if _save_elapsed >= 1.0:
		_save_elapsed = 0.0
		_sync_snapshot_to_session()


func set_griddle_count(value: int) -> void:
	var next_count := clampi(value, 1, 3)
	if next_count == _active_count:
		return
	_active_count = next_count
	_active_index = mini(_active_index, _active_count - 1)
	if is_node_ready():
		_apply_count_layout()
		_sync_snapshot_to_session()


func griddle_count() -> int:
	return _active_count


func ready_source_refs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in _active_count:
		var source: Dictionary = Dictionary(units[index].source_ref())
		if not source.is_empty():
			result.append(source)
	return result


func consume_ready(unit_index: int) -> bool:
	if unit_index < 0 or unit_index >= _active_count:
		return false
	if units[unit_index].state != UNIT_SCRIPT.State.READY:
		return false
	units[unit_index].reset_unit()
	_active_index = unit_index
	_sync_snapshot_to_session()
	status_message.emit("鏊子%d已腾空，可以继续接单" % (unit_index + 1))
	return true


func reset_all() -> void:
	for unit in units:
		unit.reset_unit()
	_active_index = 0
	_sync_snapshot_to_session()


func snapshot() -> Dictionary:
	var slots: Array[Dictionary] = []
	for unit in units:
		slots.append(Dictionary(unit.snapshot()))
	return {
		"version": 1,
		"griddle_count": _active_count,
		"active_index": _active_index,
		"product_sequence": _product_sequence,
		"slots": slots,
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	_active_count = clampi(int(value.get("griddle_count", _active_count)), 1, 3)
	_active_index = clampi(int(value.get("active_index", 0)), 0, _active_count - 1)
	_product_sequence = maxi(int(value.get("product_sequence", 0)), 0)
	var slots := Array(value.get("slots", []))
	for index in mini(slots.size(), units.size()):
		var result := Dictionary(units[index].load_snapshot(Dictionary(slots[index])))
		if not bool(result.get("success", false)):
			return result
	_apply_count_layout()
	return {"success": true}


func _on_main_action(unit_index: int) -> void:
	var unit: Node = _unit(unit_index)
	if unit == null:
		return
	_active_index = unit_index
	if unit.state == UNIT_SCRIPT.State.IDLE:
		var order: Dictionary = Dictionary(_order_provider.call()) if _order_provider.is_valid() else {}
		if order.is_empty():
			status_message.emit("先选择一位含煎饼商品的顾客，再给空鏊子添面")
			return
		var consumed := _consume_inventory_stock(&"stock.pancake.batter")
		if not bool(consumed.get("success", false)):
			status_message.emit("面糊不足：先补货再给空鏊子添面")
			return
		order.erase("formal_order_id")
		unit.begin_order(order)
		_sync_snapshot_to_session()
		status_message.emit("鏊子%d开始制作：按住鏊面画圈摊开" % (unit_index + 1))
		return
	var result: Dictionary = Dictionary(unit.advance_main())
	_sync_snapshot_to_session()
	status_message.emit(str(result.get("message", "继续操作鏊子")))


func _on_sauce_action(unit_index: int) -> void:
	var unit: Node = _unit(unit_index)
	if unit == null or unit.state != UNIT_SCRIPT.State.GARNISH:
		return
	_active_index = unit_index
	var stock_id: StringName = unit.next_sauce_id()
	if stock_id.is_empty():
		status_message.emit("鏊子%d的酱料已按订单配齐" % (unit_index + 1))
		return
	var consumed := _consume_inventory_stock(stock_id)
	if not bool(consumed.get("success", false)):
		status_message.emit("%s不足，先补货再挤酱" % _stock_label(stock_id))
		return
	unit.apply_sauce(stock_id)
	_sync_snapshot_to_session()
	status_message.emit("鏊子%d加入%s" % [unit_index + 1, _stock_label(stock_id)])


func _on_ingredient_action(unit_index: int) -> void:
	var unit: Node = _unit(unit_index)
	if unit == null or unit.state != UNIT_SCRIPT.State.GARNISH:
		return
	_active_index = unit_index
	var stock_id: StringName = unit.next_ingredient_id()
	if stock_id.is_empty():
		status_message.emit("鏊子%d的小料已按订单配齐" % (unit_index + 1))
		return
	var consumed: Dictionary = _consume_ingredient(stock_id)
	if not bool(consumed.get("success", false)):
		status_message.emit("%s不足，先补货或制作油条" % _stock_label(stock_id))
		return
	unit.apply_ingredient(stock_id)
	_sync_snapshot_to_session()
	status_message.emit("鏊子%d放入%s" % [unit_index + 1, _stock_label(stock_id)])


func _on_fold_action(unit_index: int) -> void:
	var unit: Node = _unit(unit_index)
	if unit == null:
		return
	_active_index = unit_index
	var result: Dictionary = Dictionary(unit.advance_fold())
	if bool(result.get("ready", false)):
		unit.mark_ready(_build_product(unit))
	_sync_snapshot_to_session()
	status_message.emit(str(result.get("message", "继续完成折叠")))


func _on_discard(unit_index: int) -> void:
	var unit: Node = _unit(unit_index)
	if unit == null or unit.state == UNIT_SCRIPT.State.IDLE:
		return
	_active_index = unit_index
	unit.reset_unit()
	_sync_snapshot_to_session()
	status_message.emit("鏊子%d上的半成品已丢弃；已放入的小料不返还" % (unit_index + 1))


func _consume_ingredient(stock_id: StringName) -> Dictionary:
	if _session == null:
		return {"success": false, "reason": &"no_session"}
	if stock_id == &"stock.pancake.youtiao":
		if not _session.has_method("take_prepared_product"):
			return {"success": false, "reason": &"no_youtiao_source"}
		return Dictionary(_session.call("take_prepared_product", &"slot.04"))
	if not _session.has_method("consume_inventory_stock_ids"):
		return {"success": false, "reason": &"no_inventory"}
	return Dictionary(_session.call("consume_inventory_stock_ids", [stock_id]))


func _consume_inventory_stock(stock_id: StringName) -> Dictionary:
	if _session == null or not _session.has_method("consume_inventory_stock_ids"):
		return {"success": false, "reason": &"no_inventory"}
	return Dictionary(_session.call("consume_inventory_stock_ids", [stock_id]))


func _build_product(unit: Node) -> Dictionary:
	_product_sequence += 1
	var scoring_order := Dictionary(unit.order).duplicate(true)
	var scoring_ingredients := PackedStringArray()
	for stock_value in Array(unit.order.get("ingredient_ids", [])):
		var ingredient_type := _ingredient_type_for_stock(StringName(stock_value))
		if not ingredient_type.is_empty():
			scoring_ingredients.append(ingredient_type)
	var scoring_sauces := PackedStringArray()
	for stock_value in Array(unit.order.get("sauce_ids", [])):
		scoring_sauces.append(&"red_chili" if StringName(stock_value) == &"stock.pancake.sauce.red_chili" else &"sweet_flour")
	scoring_order["ingredients"] = scoring_ingredients
	scoring_order["sauces"] = scoring_sauces
	var score_result := PANCAKE_SCORER.evaluate_order(
		unit.pancake_model,
		unit.ingredient_model,
		unit.fold_model,
		scoring_order,
		float(unit.p1_session.elapsed_seconds),
		float(unit.p1_session.patience_ratio()),
	)
	var summary := Dictionary(unit.pancake_model.calculate_summary())
	var mean_heat := (float(summary.get("mean_doneness", 0.0)) + float(summary.get("mean_back_doneness", 0.0))) * 0.5
	var actual_heat: StringName = &"light" if mean_heat < 0.34 else (&"golden" if mean_heat < 0.62 else &"well_done")
	var cost_stock_ids := PackedStringArray(["stock.pancake.batter"])
	cost_stock_ids.append_array(unit.applied_ingredient_ids)
	cost_stock_ids.append_array(unit.applied_sauce_ids)
	var material_cost := 0
	for stock_value in cost_stock_ids:
		material_cost += maxi(int(CATALOG.stock_definition(StringName(stock_value)).get("restock_unit_cost", 0)), 0)
	return {
		"product_instance_id": StringName("product_instance.pancake_griddle.%d.%d" % [unit.unit_index + 1, _product_sequence]),
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"source_index": int(unit.unit_index),
		"heat_preference": actual_heat,
		"ingredient_ids": unit.applied_ingredient_ids.duplicate(),
		"sauce_ids": unit.applied_sauce_ids.duplicate(),
		"cost_stock_ids": cost_stock_ids,
		"material_cost": material_cost,
		"fold_snapshot": Dictionary(unit.fold_model.snapshot()).duplicate(true),
		"dimension_scores": Dictionary(score_result.get("dimensions", {})).duplicate(true),
		"score": float(score_result.get("score", 0.0)),
		"feedback": str(score_result.get("feedback", "")),
		"tags": Array(score_result.get("tags", [])).duplicate(),
		"serving_score_basis": Dictionary(score_result.get("serving_score_basis", {})).duplicate(true),
		"status": &"available",
	}


func _sync_snapshot_to_session() -> void:
	if _session != null and _session.has_method("save_five_area_pancake_griddles"):
		_session.call("save_five_area_pancake_griddles", snapshot())


func _unit(index: int) -> Node:
	if index < 0 or index >= _active_count:
		return null
	return units[index]


func _stock_label(stock_id: StringName) -> String:
	var label := str(CATALOG.stock_definition(stock_id).get("label", ""))
	return label if not label.is_empty() else str(stock_id).get_slice(".", str(stock_id).count("."))


static func _ingredient_type_for_stock(stock_id: StringName) -> StringName:
	return {
		&"stock.pancake.egg": &"egg",
		&"stock.pancake.baocui": &"baocui",
		&"stock.pancake.ham_sausage": &"ham_sausage",
		&"stock.pancake.scallion": &"scallion",
		&"stock.pancake.meat_floss": &"meat_floss",
		&"stock.pancake.pork_tenderloin": &"pork_tenderloin",
		&"stock.pancake.coriander": &"coriander",
		&"stock.pancake.preserved_mustard": &"preserved_mustard",
		&"stock.pancake.youtiao": &"youtiao",
	}.get(stock_id, &"")


func _apply_count_layout() -> void:
	count_label.text = "%d/3张鏊子运行 · 每张独立火候、配料与出餐" % _active_count
	var positions: Array[float] = [0.0, 390.0, 780.0]
	for index in units.size():
		units[index].visible = true
		units[index].position = Vector2(positions[index], 36.0)
		units[index].call("set_upgrade_locked", index >= _active_count)
