class_name MultiGriddleStation
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_SCORER := preload("res://scripts/gameplay/pancake_scorer.gd")
const UNIT_SCRIPT := preload("res://scripts/gameplay/compact_griddle_unit.gd")

@onready var count_label: Label = %CountLabel
@onready var units: Array[Node] = [%Griddle01]
@onready var shared_tool_tray: Control = %SharedToolTray

var _session: Node
var _active_count := 1
var _active_index := 0
var _product_sequence := 0
var _save_elapsed := 0.0
var _last_tree_paused := false
var _selected_tool: StringName = &""
var _primed_sauce_stock_id: StringName = &""
var _primed_sauce_unit_index := -1


func _ready() -> void:
	# Persist pause transitions while each individual griddle remains pausable.
	# This records the exact slots without advancing heat behind the pause UI.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_tree_paused = get_tree().paused
	var display_names := ["主鏊"]
	for index in units.size():
		var unit: Node = units[index]
		unit.configure(index, display_names[index])
		unit.main_action_requested.connect(_on_main_action)
		unit.status_message_requested.connect(status_message.emit)
	shared_tool_tray.tool_selected.connect(_on_shared_tool_selected)
	shared_tool_tray.status_message.connect(status_message.emit)
	_apply_count_layout()


func bind_session(session: Node) -> void:
	_session = session
	shared_tool_tray.bind_session(session)
	if is_node_ready() and _session != null and _session.has_method("five_area_pancake_griddles_snapshot"):
		load_snapshot(Dictionary(_session.call("five_area_pancake_griddles_snapshot")))


func _process(delta: float) -> void:
	var tree_paused := get_tree().paused
	if tree_paused != _last_tree_paused:
		_last_tree_paused = tree_paused
		if tree_paused:
			clear_held_tool()
		_sync_snapshot_to_session()
	_save_elapsed += maxf(delta, 0.0)
	if _save_elapsed >= 1.0:
		_save_elapsed = 0.0
		_sync_snapshot_to_session()


func set_griddle_count(_value: int) -> void:
	# Keep the public setter for existing callers, but the redesigned stall has
	# exactly one physical cooking surface regardless of legacy device tiers.
	_active_count = 1
	_active_index = 0
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
	clear_held_tool()
	for unit in units:
		unit.reset_unit()
	_active_index = 0
	_sync_snapshot_to_session()


func reset_active() -> Dictionary:
	var unit := _unit(_active_index)
	if unit == null or unit.state == UNIT_SCRIPT.State.IDLE:
		status_message.emit("最近操作的鏊子是空的，无需重做")
		return {"success": false, "reason": &"active_griddle_empty", "source_index": _active_index}
	clear_held_tool()
	unit.reset_unit()
	_sync_snapshot_to_session()
	status_message.emit("鏊子%d已清空；原料不返还，请重新添面糊" % (_active_index + 1))
	return {"success": true, "source_index": _active_index}


func snapshot() -> Dictionary:
	var slots: Array[Dictionary] = []
	if not units.is_empty():
		slots.append(Dictionary(units[0].snapshot()))
	return {
		"version": 2,
		"griddle_count": 1,
		"active_index": 0,
		"product_sequence": _product_sequence,
		"slots": slots,
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	clear_held_tool()
	# Version 1 snapshots may contain up to three griddles. Preserve only the
	# primary slot; secondary in-progress pancakes intentionally do not migrate.
	_active_count = 1
	_active_index = 0
	_product_sequence = maxi(int(value.get("product_sequence", 0)), 0)
	var slots := Array(value.get("slots", []))
	if not slots.is_empty() and not units.is_empty():
		var result := Dictionary(units[0].load_snapshot(Dictionary(slots[0])))
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
		unit.begin_order(_unbound_production_context())
		_set_selected_tool(&"tool.pancake.spreader")
		_sync_snapshot_to_session()
		status_message.emit("鏊子%d开始制作：摊饼器已自动拿起，按住鏊面画圈摊开" % (unit_index + 1))
		return
	var result: Dictionary = Dictionary(unit.advance_main())
	_sync_snapshot_to_session()
	status_message.emit(str(result.get("message", "继续操作鏊子")))


func begin_surface_action(unit_index: int, local_position: Vector2) -> Dictionary:
	var unit := _unit(unit_index)
	if unit == null:
		return {"success": false, "reason": &"griddle_locked"}
	_active_index = unit_index
	if (
		unit_index == _primed_sauce_unit_index
		and _selected_tool == _primed_sauce_stock_id
		and not _primed_sauce_stock_id.is_empty()
	):
		if not unit.can_apply_sauce_at(local_position):
			status_message.emit("酱刷必须先接触有效饼面")
			return {"success": false, "reason": &"outside_pancake"}
		return {"success": true, "action": UNIT_SCRIPT.SURFACE_ACTION_BRUSH_SAUCE, "stock_id": _primed_sauce_stock_id}
	if unit.state in [UNIT_SCRIPT.State.SECOND_SIDE, UNIT_SCRIPT.State.GARNISH, UNIT_SCRIPT.State.FOLDING]:
		var fold_result := Dictionary(unit.begin_manual_fold(local_position))
		if bool(fold_result.get("success", false)):
			_selected_tool = &""
			shared_tool_tray.set_selected_tool(&"")
			for other_unit in units:
				if other_unit != unit:
					other_unit.cancel_held_tool()
			return fold_result
	var contextual_spreader_action := _contextual_spreader_action(unit)
	if not contextual_spreader_action.is_empty():
		_set_selected_tool(&"tool.pancake.spreader")
		return {
			"success": true,
			"action": contextual_spreader_action,
			"width_multiplier": _spreader_width_multiplier(),
		}
	if _selected_tool == &"tool.pancake.spreader":
		status_message.emit("摊饼器当前只能摊面糊，或在第一面摊开已放入的鸡蛋")
		return {"success": false, "reason": &"wrong_stage"}
	if _selected_tool in [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili"]:
		status_message.emit("请重新点击酱罐落酱后再刷")
		return {"success": false, "reason": &"sauce_not_primed"}
	status_message.emit("先从共享料台拿起摊饼器或酱刷")
	return {"success": false, "reason": &"tool_not_selected"}


func _contextual_spreader_action(unit: Node) -> StringName:
	if unit.state == UNIT_SCRIPT.State.BATTER:
		return UNIT_SCRIPT.SURFACE_ACTION_SPREAD_BATTER
	if unit.state in [UNIT_SCRIPT.State.FIRST_SIDE, UNIT_SCRIPT.State.SECOND_SIDE] and unit.pancake_model.has_egg():
		return UNIT_SCRIPT.SURFACE_ACTION_SPREAD_EGG
	return &""


func complete_surface_action(unit_index: int, action: StringName, changed: bool) -> void:
	if action.is_empty():
		return
	if action == UNIT_SCRIPT.SURFACE_ACTION_BRUSH_SAUCE:
		status_message.emit("酱料已完成一次连续刷涂" if changed else "酱刷没有接触到有效饼面")
	elif action == UNIT_SCRIPT.SURFACE_ACTION_FOLD:
		var unit := _unit(unit_index)
		if changed and unit != null and unit.fold_model.completed_fold_count() >= 2 and unit.state == UNIT_SCRIPT.State.FOLDING:
			unit.mark_ready(_build_product(unit))
	clear_held_tool()
	_sync_snapshot_to_session()


func can_drop_on_unit(unit_index: int, source_ref: Dictionary, local_position: Vector2) -> bool:
	var unit := _unit(unit_index)
	if unit == null:
		return false
	var validation := Dictionary(unit.validate_ingredient_drop(source_ref, local_position))
	if not bool(validation.get("success", false)):
		return false
	var source_kind := StringName(source_ref.get("source_kind", &""))
	if source_kind == &"pancake_shared_ingredient":
		var stock_id := StringName(validation.get("stock_id", &""))
		if _session == null or not _session.has_method("inventory_snapshot"):
			return false
		var progression: RefCounted = _session.call("progression_service") if _session.has_method("progression_service") else null
		if progression == null or not bool(progression.call("owns_stock", stock_id)):
			return false
		return int(Dictionary(_session.call("inventory_snapshot")).get(str(stock_id), 0)) > 0
	if StringName(source_ref.get("product_id", &"")) != &"product.youtiao.plain":
		return false
	if source_kind == &"prepared_product_slot":
		return _session != null and _session.has_method("preview_take_prepared_product") and bool(Dictionary(_session.call("preview_take_prepared_product", StringName(source_ref.get("source_slot_id", &"")))).get("success", false))
	return false


func drop_on_unit(unit_index: int, source_ref: Dictionary, local_position: Vector2) -> Dictionary:
	var unit := _unit(unit_index)
	if unit == null:
		return {"success": false, "reason": &"griddle_locked"}
	var validation := Dictionary(unit.validate_ingredient_drop(source_ref, local_position))
	if not bool(validation.get("success", false)) or not can_drop_on_unit(unit_index, source_ref, local_position):
		return validation if not bool(validation.get("success", false)) else {"success": false, "reason": &"source_unavailable"}
	var consumed: Dictionary
	var source_kind := StringName(source_ref.get("source_kind", &""))
	if source_kind == &"prepared_product_slot":
		consumed = Dictionary(_session.call("take_prepared_product", StringName(source_ref.get("source_slot_id", &""))))
	else:
		consumed = _consume_inventory_stock(StringName(validation.get("stock_id", &"")))
	if not bool(consumed.get("success", false)):
		return consumed
	if StringName(validation.get("ingredient_type", &"")) != IngredientModel.EGG:
		var preparation: Dictionary = unit.begin_garnish_without_flip() if unit.state == UNIT_SCRIPT.State.FIRST_SIDE else unit.confirm_second_side_for_followup()
		if not bool(preparation.get("success", false)):
			return preparation
	var placed := Dictionary(unit.place_validated_ingredient(validation))
	if not bool(placed.get("success", false)):
		return placed
	_active_index = unit_index
	shared_tool_tray.refresh_from_session()
	if StringName(validation.get("ingredient_type", &"")) == IngredientModel.EGG:
		_set_selected_tool(&"tool.pancake.spreader")
	_sync_snapshot_to_session()
	var placed_label := _stock_label(StringName(validation.get("stock_id", &"")))
	status_message.emit(
		"%s已放到%s；摊饼器已自动拿起" % [placed_label, unit.title_label.text]
		if StringName(validation.get("ingredient_type", &"")) == IngredientModel.EGG
		else "%s已放到%s%s" % [placed_label, unit.title_label.text, "；未翻面交付会额外扣12分" if not unit.pancake_model.is_flipped else ""]
	)
	return placed


func clear_held_tool() -> void:
	_selected_tool = &""
	_primed_sauce_stock_id = &""
	_primed_sauce_unit_index = -1
	if is_instance_valid(shared_tool_tray):
		shared_tool_tray.set_selected_tool(&"")
	for unit in units:
		unit.cancel_held_tool()


func is_spreader_selected() -> bool:
	return _selected_tool == &"tool.pancake.spreader"


func _on_shared_tool_selected(tool_id: StringName) -> void:
	select_worktop_tool(tool_id)


func select_worktop_tool(tool_id: StringName) -> Dictionary:
	if tool_id == &"tool.pancake.spreader":
		clear_held_tool()
		_set_selected_tool(tool_id)
		status_message.emit("已拿起摊饼器；在鏊面按住画圈摊面或摊蛋")
		return {"success": true, "tool_id": tool_id}
	if tool_id not in [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili"]:
		return {"success": false, "reason": &"unknown_tool"}
	if _session == null or not _session.has_method("inventory_snapshot"):
		return {"success": false, "reason": &"no_session"}
	var progression: RefCounted = _session.call("progression_service") if _session.has_method("progression_service") else null
	if progression == null or not bool(progression.call("owns_stock", tool_id)):
		status_message.emit("%s尚未解锁" % _stock_label(tool_id))
		return {"success": false, "reason": &"stock_locked"}
	if int(Dictionary(_session.call("inventory_snapshot")).get(str(tool_id), 0)) <= 0:
		status_message.emit("%s库存不足；请长按酱罐补货" % _stock_label(tool_id))
		return {"success": false, "reason": &"insufficient_stock"}
	var unit := _unit(_active_index)
	if unit == null or not unit.has_method("validate_sauce_prime"):
		return {"success": false, "reason": &"griddle_locked"}
	var validation := Dictionary(unit.call("validate_sauce_prime", tool_id))
	if not bool(validation.get("success", false)):
		var reason := StringName(validation.get("reason", &""))
		match reason:
			&"duplicate_sauce": status_message.emit("这张饼已经加过同一种酱")
			&"outside_pancake": status_message.emit("当前饼面没有可落酱的位置")
			_: status_message.emit("摊开面饼后才能点击酱罐落酱")
		return validation
	var consumed := _consume_inventory_stock(tool_id)
	if not bool(consumed.get("success", false)):
		status_message.emit("%s库存不足" % _stock_label(tool_id))
		return consumed
	var primed := Dictionary(unit.call("prime_sauce", tool_id, validation))
	if not bool(primed.get("success", false)):
		return primed
	_set_selected_tool(tool_id)
	_primed_sauce_stock_id = tool_id
	_primed_sauce_unit_index = _active_index
	shared_tool_tray.refresh_from_session()
	_sync_snapshot_to_session()
	status_message.emit("%s已落到饼面；酱刷已拿起，按住鏊面拖动刷开" % _stock_label(tool_id))
	return primed.merged({"tool_id": tool_id, "unit_index": _active_index}, true)


func _set_selected_tool(tool_id: StringName) -> void:
	_selected_tool = tool_id
	shared_tool_tray.set_selected_tool(tool_id)


func _spreader_width_multiplier() -> float:
	if _session == null or not _session.has_method("progression_service"):
		return 1.0
	var progression: RefCounted = _session.call("progression_service")
	return 1.65 if bool(progression.call("owns_growth", &"growth.tool.pancake.wide_spreader")) else 1.0


func _consume_ingredient(stock_id: StringName) -> Dictionary:
	if _session == null:
		return {"success": false, "reason": &"no_session"}
	if stock_id == &"stock.pancake.youtiao":
		if not _session.has_method("take_prepared_product"):
			return {"success": false, "reason": &"no_youtiao_source"}
		return Dictionary(_session.call("take_prepared_product", &"slot.04"))
	if not _session.has_method("consume_inventory_stock_ids"):
		return {"success": false, "reason": &"no_inventory"}
	var stock_ids: Array[StringName] = [stock_id]
	return Dictionary(_session.call("consume_inventory_stock_ids", stock_ids))


func _consume_inventory_stock(stock_id: StringName) -> Dictionary:
	if _session == null or not _session.has_method("consume_inventory_stock_ids"):
		return {"success": false, "reason": &"no_inventory"}
	var stock_ids: Array[StringName] = [stock_id]
	return Dictionary(_session.call("consume_inventory_stock_ids", stock_ids))


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
	var serving_score_basis := Dictionary(score_result.get("serving_score_basis", {})).duplicate(true)
	var intrinsic_dimensions := Dictionary(serving_score_basis.get("intrinsic_dimensions", {})).duplicate(true)
	if intrinsic_dimensions.is_empty():
		intrinsic_dimensions = Dictionary(score_result.get("dimensions", {})).duplicate(true)
	var intrinsic_score := 0.0
	for value in intrinsic_dimensions.values():
		intrinsic_score += float(value)
	if not intrinsic_dimensions.is_empty():
		intrinsic_score /= float(intrinsic_dimensions.size())
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
		"dimension_scores": intrinsic_dimensions,
		"score": intrinsic_score,
		"feedback": "成品将在交付时按顾客订单评价",
		"tags": Array(serving_score_basis.get("repair_tags", [])).duplicate(),
		"serving_score_basis": serving_score_basis,
		"special_evaluation": Dictionary(score_result.get("special_evaluation", {})).duplicate(true),
		"status": &"available",
	}


static func _unbound_production_context() -> Dictionary:
	return {
		"id": &"production.pancake.unbound",
		"product_id": &"product.pancake.custom",
		"heat_preference": &"golden",
		"ingredients": PackedStringArray(),
		"sauces": PackedStringArray(),
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"time_limit": 72.0,
		"tutorial_no_countdown": true,
	}


func _sync_snapshot_to_session() -> void:
	if _session != null and _session.has_method("save_five_area_pancake_griddles"):
		_session.call("save_five_area_pancake_griddles", snapshot())


func _unit(index: int) -> Node:
	if index < 0 or index >= _active_count:
		return null
	return units[index]


func _stock_label(stock_id: StringName) -> String:
	var pancake_labels := {
		&"stock.pancake.egg": "鸡蛋",
		&"stock.pancake.baocui": "薄脆",
		&"stock.pancake.scallion": "葱花",
		&"stock.pancake.ham_sausage": "火腿",
		&"stock.pancake.meat_floss": "肉松",
		&"stock.pancake.coriander": "香菜",
		&"stock.pancake.preserved_mustard": "榨菜",
		&"stock.pancake.pork_tenderloin": "里脊",
	}
	if pancake_labels.has(stock_id):
		return str(pancake_labels[stock_id])
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
	count_label.text = "单张鏊子 · 现做现出"
	if units.is_empty():
		return
	units[0].visible = true
	units[0].position = Vector2(380.0, 105.0)
	units[0].call("set_upgrade_locked", false)
