class_name MultiGriddleStation
extends Control

signal status_message(message: String)
signal transient_warning_requested(message: String)
signal held_tool_changed(tool_id: StringName)
signal fold_feedback_requested(unit_index: int, feedback_kind: StringName)
signal ingredient_feedback_requested(success: bool)
signal ready_product_clicked(source_ref: Dictionary)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_SCORER := preload("res://scripts/gameplay/pancake_scorer.gd")
const UNIT_SCRIPT := preload("res://scripts/gameplay/compact_griddle_unit.gd")
const PANCAKE_YOUTIAO_PRODUCT_IDS: Array[StringName] = [&"product.youtiao.plain"]
const EGG_STOCK_ID := &"stock.pancake.egg"
const ONE_CLICK_EGG_GROWTH_ID := &"growth.automation.pancake.one_click_egg"
const NON_BURNING_GRIDDLE_GROWTH_ID := &"growth.automation.pancake.non_burning_griddle"
const FAST_COOK_GRIDDLE_GROWTH_ID := &"growth.automation.pancake.fast_cook_griddle"
## Small toppings have no placement precision requirement, so clicking their
## worktop source always places a portion at the authored centre position.
const CLICK_INGREDIENT_STOCK_IDS: Array[StringName] = [
	&"stock.pancake.baocui",
	&"stock.pancake.scallion",
	&"stock.pancake.ham_sausage",
	&"stock.pancake.coriander",
	&"stock.pancake.meat_floss",
]

@onready var units: Array[Node] = [%Griddle01]

var _session: Node
var _active_count := 1
var _active_index := 0
var _product_sequence := 0
var _save_elapsed := 0.0
var _last_tree_paused := false
var _last_synced_snapshot: Dictionary = {}
var _selected_tool: StringName = &""
var _reserved_ingredient_drag_stock_id: StringName = &""
var _ingredient_feedback_tween: Tween
var _target_preview_visible := false
## The cartoon workstation uses one baked-in contextual tool hotspot. After a
## successful held pour it can hand the player the spreader immediately,
## without interrupting the pour while the pointer is still down.
var auto_select_spreader_after_pour := false


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
		unit.transient_warning_requested.connect(transient_warning_requested.emit)
		unit.fold_feedback_requested.connect(fold_feedback_requested.emit)
		unit.packaging_finished.connect(_on_unit_packaging_finished)
		unit.ready_product_clicked.connect(ready_product_clicked.emit)
	_apply_count_layout()


func bind_session(session: Node) -> void:
	_session = session
	_last_synced_snapshot.clear()
	if is_node_ready() and _session != null and _session.has_method("five_area_pancake_griddles_snapshot"):
		var result := load_snapshot(Dictionary(_session.call("five_area_pancake_griddles_snapshot")))
		if bool(result.get("success", false)):
			# The session already owns this state. Seed the comparison cache so the
			# one-second safety sync cannot immediately rewrite an unchanged save.
			_last_synced_snapshot = snapshot().duplicate(true)
	_sync_growth_effects()


func _process(delta: float) -> void:
	var tree_paused := get_tree().paused
	if tree_paused != _last_tree_paused:
		_last_tree_paused = tree_paused
		if tree_paused:
			clear_held_tool()
		_sync_snapshot_to_session()
	_save_elapsed += maxf(delta, 0.0)
	if _save_elapsed >= 1.0:
		_sync_growth_effects()
		# A cooking snapshot contains the complete simulation fields and is written
		# as JSON. Defer this safety save while a native preview is following the
		# pointer, then flush it immediately after the drag ends.
		var viewport := get_viewport()
		if viewport != null and viewport.gui_is_dragging():
			return
		_save_elapsed = 0.0
		_sync_snapshot_to_session()


func _sync_growth_effects() -> void:
	if _session == null or not _session.has_method("progression_service"):
		return
	var progression: RefCounted = _session.call("progression_service")
	var non_burning_enabled := progression != null and bool(progression.call("owns_growth", NON_BURNING_GRIDDLE_GROWTH_ID))
	# The catalog requires the non-burning griddle first. Keep that safety
	# invariant at runtime too, including for malformed or hand-edited saves.
	var fast_cook_enabled := non_burning_enabled and progression != null and bool(progression.call("owns_growth", FAST_COOK_GRIDDLE_GROWTH_ID))
	for unit in units:
		if unit != null and unit.has_method("set_non_burning_upgrade_enabled"):
			unit.call("set_non_burning_upgrade_enabled", non_burning_enabled)
		if unit != null and unit.has_method("set_fast_cook_upgrade_enabled"):
			unit.call("set_fast_cook_upgrade_enabled", fast_cook_enabled)


func set_griddle_count(_value: int) -> void:
	# Keep the public setter for existing callers, but the redesigned stall has
	# exactly one physical cooking surface regardless of legacy device tiers.
	# FiveAreaWorkstation reapplies this invariant every 100 ms. Treating the
	# already-normalized value as a mutation used to relayout the station and
	# synchronously rewrite the complete save ten times per second.
	if _active_count == 1 and _active_index == 0:
		return
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


func set_ready_product_selected(source_ref: Dictionary) -> void:
	for unit in units:
		var unit_source := Dictionary(unit.source_ref())
		var selected := (
			not source_ref.is_empty()
			and StringName(unit_source.get("source_kind", &"")) == StringName(source_ref.get("source_kind", &""))
			and int(unit_source.get("source_index", -1)) == int(source_ref.get("source_index", -2))
		)
		unit.set_ready_product_selected(selected)


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
		status_message.emit("鏊子%d开始制作：摊饼器已自动拿起，绕鏊面转一圈即可" % (unit_index + 1))
		return
	var result: Dictionary = Dictionary(unit.advance_main())
	_sync_snapshot_to_session()
	status_message.emit(str(result.get("message", "继续操作鏊子")))


func trigger_fold_package() -> Dictionary:
	var unit := _unit(_active_index)
	if unit == null:
		var unavailable := _tool_interaction_result(false, &"griddle_locked", "当前没有可用的煎饼鏊子", &"tool.pancake.fold_package")
		status_message.emit(str(unavailable.message))
		return unavailable
	if unit.state not in [UNIT_SCRIPT.State.SECOND_SIDE, UNIT_SCRIPT.State.GARNISH]:
		var wrong_stage := _tool_interaction_result(false, &"wrong_stage", "翻面并完成加料后才能折叠包装", &"tool.pancake.fold_package")
		status_message.emit(str(wrong_stage.message))
		return wrong_stage
	var advanced := Dictionary(unit.advance_main())
	_sync_snapshot_to_session()
	var result := _tool_interaction_result(
		bool(advanced.get("success", false)),
		StringName(advanced.get("reason", &"" if bool(advanced.get("success", false)) else &"action_failed")),
		str(advanced.get("message", "正在折叠并包装")),
		&"tool.pancake.fold_package",
	).merged(advanced, true)
	status_message.emit(str(result.message))
	return result


func can_take_batter_from_ladle() -> bool:
	if units.is_empty():
		return false
	var unit := _unit(_active_index)
	return unit != null and unit.state == UNIT_SCRIPT.State.IDLE


func take_batter_from_ladle(batter_amount: float = UNIT_SCRIPT.STANDARD_BATTER_AMOUNT, used_automatic_batter_ladle: bool = false) -> Dictionary:
	if not can_take_batter_from_ladle():
		status_message.emit("鏊面制作中，暂时不能再加面糊")
		return {"success": false, "reason": &"griddle_busy"}
	var unit := _unit(_active_index)
	if unit == null:
		return {"success": false, "reason": &"griddle_locked"}
	var actual_amount := clampf(batter_amount, UNIT_SCRIPT.MIN_BATTER_AMOUNT, UNIT_SCRIPT.MAX_BATTER_AMOUNT)
	unit.begin_order(_unbound_production_context(), actual_amount, used_automatic_batter_ladle)
	_set_selected_tool(&"tool.pancake.spreader")
	_sync_snapshot_to_session()
	status_message.emit("面糊已倒入：摊饼器已自动拿起，绕鏊面转一圈即可")
	return {"success": true, "unit_index": _active_index, "batter_amount": actual_amount}


func begin_surface_action(unit_index: int, local_position: Vector2) -> Dictionary:
	var unit := _unit(unit_index)
	if unit == null:
		return {"success": false, "reason": &"griddle_locked"}
	_active_index = unit_index
	if _selected_tool == &"tool.pancake.ladle":
		if unit.state != UNIT_SCRIPT.State.IDLE:
			status_message.emit("空鏊子上才能倒入面糊")
			return {"success": false, "reason": &"griddle_busy"}
		var pour_result := Dictionary(unit.call("begin_batter_pour", _unbound_production_context()))
		if not bool(pour_result.get("success", false)):
			return pour_result
		return {"success": true, "action": UNIT_SCRIPT.SURFACE_ACTION_POUR_BATTER}
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
	if _selected_tool == &"stock.pancake.sauce.sweet_flour":
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
	if action == UNIT_SCRIPT.SURFACE_ACTION_POUR_BATTER:
		var pour_unit := _unit(unit_index)
		if changed:
			clear_held_tool()
			if auto_select_spreader_after_pour:
				_set_selected_tool(&"tool.pancake.spreader")
				status_message.emit("面糊已倒入；摊饼器已自动拿起，绕鏊面转一圈即可")
			else:
				status_message.emit("面糊已倒入；面糊勺已放回筒中")
		else:
			if pour_unit != null:
				pour_unit.reset_unit()
			status_message.emit("面糊不足；请在鏊子上方多按住一会儿")
			clear_held_tool()
		_sync_snapshot_to_session()
		return
	clear_held_tool()
	_sync_snapshot_to_session()


func _on_unit_packaging_finished(unit_index: int) -> void:
	var unit := _unit(unit_index)
	if unit == null or unit.state != UNIT_SCRIPT.State.FOLDING or unit.fold_model.package_result != &"paper_bag":
		return
	unit.mark_ready(_build_product(unit))
	status_message.emit("鏊子%d纸袋包装完成，可拖到匹配订单" % (unit_index + 1))
	_sync_snapshot_to_session()


func can_drop_on_unit(unit_index: int, source_ref: Dictionary, local_position: Vector2) -> bool:
	var unit := _unit(unit_index)
	if unit == null:
		return false
	var validation := Dictionary(unit.validate_ingredient_drop(source_ref, local_position))
	return bool(validation.get("success", false)) and _source_is_available_for_drop(source_ref, validation)


func can_preview_drop_on_unit(unit_index: int, source_ref: Dictionary, local_position: Vector2) -> bool:
	var unit := _unit(unit_index)
	if unit == null:
		return false
	# Native drag hover is called for every pointer update. Keep it local to the
	# griddle model, then repeat the session-backed stock check once on release.
	if not bool(Dictionary(unit.validate_ingredient_drop(source_ref, local_position)).get("success", false)):
		return false
	var source_kind := StringName(source_ref.get("source_kind", &""))
	return source_kind == &"pancake_shared_ingredient" or (
		PANCAKE_YOUTIAO_PRODUCT_IDS.has(StringName(source_ref.get("product_id", &"")))
		and source_kind in [&"prepared_product_slot", &"youtiao_fryer_slot"]
	)


func reserve_ingredient_drag(source_ref: Dictionary) -> Dictionary:
	if StringName(source_ref.get("source_kind", &"")) != &"pancake_shared_ingredient":
		return {"success": false, "reason": &"unsupported_source"}
	var stock_id := StringName(source_ref.get("stock_id", &""))
	if stock_id.is_empty():
		return {"success": false, "reason": &"stock_id_missing"}
	# Native GUI dragging is single-pointer. Restore any abandoned reservation
	# defensively before beginning another one so inventory cannot leak if a drag
	# source disappears without receiving NOTIFICATION_DRAG_END.
	if not _reserved_ingredient_drag_stock_id.is_empty():
		_restore_reserved_ingredient_drag()
	var consumed := _consume_inventory_stock(stock_id)
	if not bool(consumed.get("success", false)):
		return consumed
	_reserved_ingredient_drag_stock_id = stock_id
	return {"success": true, "stock_id": stock_id}


func finish_ingredient_drag(source_ref: Dictionary, successful: bool) -> Dictionary:
	if not _source_matches_reserved_ingredient_drag(source_ref):
		return {"success": true, "already_finished": true}
	if successful:
		_reserved_ingredient_drag_stock_id = &""
		return {"success": true}
	return _restore_reserved_ingredient_drag()


func _source_is_available_for_drop(source_ref: Dictionary, validation: Dictionary) -> bool:
	var source_kind := StringName(source_ref.get("source_kind", &""))
	if source_kind == &"pancake_shared_ingredient":
		if _source_matches_reserved_ingredient_drag(source_ref):
			return true
		var stock_id := StringName(validation.get("stock_id", &""))
		if _session == null or not _session.has_method("inventory_snapshot"):
			return false
		var progression: RefCounted = _session.call("progression_service") if _session.has_method("progression_service") else null
		if progression == null or not bool(progression.call("owns_stock", stock_id)):
			return false
		# Unlimited garnishes intentionally keep a zero inventory count. Their
		# unlock state is the complete availability contract, just as it is in
		# _consume_inventory_stock below.
		if _stock_is_unlimited(stock_id):
			return true
		return int(Dictionary(_session.call("inventory_snapshot")).get(str(stock_id), 0)) > 0
	if not PANCAKE_YOUTIAO_PRODUCT_IDS.has(StringName(source_ref.get("product_id", &""))):
		return false
	if source_kind == &"prepared_product_slot":
		return _session != null and _session.has_method("preview_take_prepared_product") and bool(Dictionary(_session.call("preview_take_prepared_product", StringName(source_ref.get("source_slot_id", &"")), int(source_ref.get("source_index", 0)))).get("success", false))
	if source_kind == &"youtiao_fryer_slot":
		return _session != null and _session.has_method("preview_take_youtiao_fryer_slot") and bool(Dictionary(_session.call("preview_take_youtiao_fryer_slot", int(source_ref.get("source_index", -1)))).get("success", false))
	return false


func drop_on_unit(unit_index: int, source_ref: Dictionary, local_position: Vector2) -> Dictionary:
	var unit := _unit(unit_index)
	if unit == null:
		return {"success": false, "reason": &"griddle_locked"}
	var validation := Dictionary(unit.validate_ingredient_drop(source_ref, local_position))
	if not bool(validation.get("success", false)) or not _source_is_available_for_drop(source_ref, validation):
		return validation if not bool(validation.get("success", false)) else {"success": false, "reason": &"source_unavailable"}
	var consumed: Dictionary
	var source_kind := StringName(source_ref.get("source_kind", &""))
	var used_reservation := _source_matches_reserved_ingredient_drag(source_ref)
	if source_kind == &"prepared_product_slot":
		consumed = Dictionary(_session.call("take_prepared_product", StringName(source_ref.get("source_slot_id", &"")), int(source_ref.get("source_index", 0))))
	elif source_kind == &"youtiao_fryer_slot":
		consumed = Dictionary(_session.call("take_youtiao_fryer_slot", int(source_ref.get("source_index", -1))))
	elif used_reservation:
		consumed = {"success": true, "stock_id": _reserved_ingredient_drag_stock_id}
	else:
		consumed = _consume_inventory_stock(StringName(validation.get("stock_id", &"")))
	if not bool(consumed.get("success", false)):
		return consumed
	var placed := Dictionary(unit.place_validated_ingredient(validation))
	if not bool(placed.get("success", false)):
		if used_reservation:
			_restore_reserved_ingredient_drag()
		return placed
	if used_reservation:
		_reserved_ingredient_drag_stock_id = &""
	_active_index = unit_index
	if StringName(validation.get("ingredient_type", &"")) == IngredientModel.EGG:
		_set_selected_tool(&"tool.pancake.spreader")
	_sync_snapshot_to_session()
	var placed_label := _stock_label(StringName(validation.get("stock_id", &"")))
	status_message.emit(
		"%s已放到%s；摊饼器已自动拿起" % [placed_label, unit.display_name()]
		if StringName(validation.get("ingredient_type", &"")) == IngredientModel.EGG
		else "%s已放到%s" % [placed_label, unit.display_name()]
	)
	return placed


func one_click_ingredient_enabled(stock_id: StringName) -> bool:
	return not _ingredient_type_for_stock(stock_id).is_empty()


func ingredient_drag_enabled(stock_id: StringName) -> bool:
	return false


func auto_spread_egg_enabled() -> bool:
	if _session == null or not _session.has_method("progression_service"):
		return false
	var progression: RefCounted = _session.call("progression_service")
	return progression != null and bool(progression.call("owns_growth", ONE_CLICK_EGG_GROWTH_ID))


func preview_one_click_ingredient(stock_id: StringName) -> Dictionary:
	var unit := _unit(_active_index)
	if unit == null:
		return _ingredient_result(false, &"griddle_locked", stock_id, "当前没有可用的煎饼鏊子")
	var source_ref := {"source_kind": &"pancake_shared_ingredient", "stock_id": stock_id}
	var local_position: Vector2 = unit.pancake_surface.size * 0.5
	var validation := Dictionary(unit.validate_ingredient_drop(source_ref, local_position))
	if not bool(validation.get("success", false)):
		return _ingredient_result(false, StringName(validation.get("reason", &"invalid_target")), stock_id, _ingredient_failure_message(stock_id, validation))
	if not _source_is_available_for_drop(source_ref, validation):
		return _ingredient_result(false, &"source_unavailable", stock_id, "%s库存不足；请长按补货" % _stock_label(stock_id))
	return _ingredient_result(true, &"", stock_id, "%s将加入%s" % [_stock_label(stock_id), unit.display_name()])


func apply_one_click_ingredient(stock_id: StringName) -> Dictionary:
	if not one_click_ingredient_enabled(stock_id):
		return _ingredient_result(false, &"not_pancake_ingredient", stock_id, "该物品不能直接加入煎饼")
	var unit := _unit(_active_index)
	if unit == null:
		return _ingredient_result(false, &"griddle_locked", stock_id, "当前没有可用的煎饼鏊子")
	var source_ref := {"source_kind": &"pancake_shared_ingredient", "stock_id": stock_id}
	var result := Dictionary(drop_on_unit(_active_index, source_ref, unit.pancake_surface.size * 0.5))
	if bool(result.get("success", false)):
		var automated_spread := {}
		if stock_id == EGG_STOCK_ID and auto_spread_egg_enabled() and unit.has_method("auto_spread_egg"):
			automated_spread = Dictionary(unit.call("auto_spread_egg"))
			clear_held_tool()
			_sync_snapshot_to_session()
			status_message.emit("鸡蛋已自动摊匀")
		var auto_spread_succeeded := bool(automated_spread.get("success", false))
		var message := "鸡蛋已自动打入并摊匀" if auto_spread_succeeded else "%s已加入%s" % [_stock_label(stock_id), unit.display_name()]
		return result.merged(_ingredient_result(true, &"", stock_id, message), true).merged({"one_click": true, "auto_spread": automated_spread}, true)
	var message := _ingredient_failure_message(stock_id, result)
	status_message.emit(message)
	return result.merged({"success": false, "message": message, "target": _active_index}, true)


func set_ingredient_target_preview(result: Dictionary, visible: bool) -> void:
	var unit := _unit(_active_index)
	if unit == null or unit.pancake_surface == null:
		return
	_target_preview_visible = visible
	if not visible:
		unit.pancake_surface.self_modulate = Color.WHITE
		unit.pancake_surface.tooltip_text = ""
		return
	var valid := bool(result.get("success", false))
	unit.pancake_surface.self_modulate = Color(0.82, 1.0, 0.82, 1.0) if valid else Color(1.0, 0.72, 0.68, 1.0)
	unit.pancake_surface.tooltip_text = str(result.get("message", ""))


func play_ingredient_feedback(success: bool) -> void:
	var unit := _unit(_active_index)
	if unit == null or unit.pancake_surface == null:
		return
	ingredient_feedback_requested.emit(success)
	if _ingredient_feedback_tween != null and _ingredient_feedback_tween.is_valid():
		_ingredient_feedback_tween.kill()
	var surface: Control = unit.pancake_surface
	surface.pivot_offset = surface.size * 0.5
	surface.scale = Vector2.ONE
	var reduce_motion := DisplayServer.has_method(&"accessibility_should_reduce_motion") and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))
	var feedback_color := Color(0.72, 1.0, 0.72, 1.0) if success else Color(1.0, 0.58, 0.54, 1.0)
	_ingredient_feedback_tween = create_tween()
	_ingredient_feedback_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_ingredient_feedback_tween.tween_property(surface, "self_modulate", feedback_color, 0.06)
	if not reduce_motion:
		_ingredient_feedback_tween.parallel().tween_property(surface, "scale", Vector2.ONE * (1.015 if success else 0.985), 0.06)
	_ingredient_feedback_tween.tween_property(surface, "self_modulate", Color.WHITE, 0.08)
	if not reduce_motion:
		_ingredient_feedback_tween.parallel().tween_property(surface, "scale", Vector2.ONE, 0.08)


func _ingredient_result(success: bool, reason: StringName, stock_id: StringName, message: String) -> Dictionary:
	return {"success": success, "reason": reason, "stock_id": stock_id, "message": message, "target": _active_index}


func _ingredient_failure_message(stock_id: StringName, result: Dictionary) -> String:
	match StringName(result.get("reason", &"")):
		&"insufficient_stock", &"source_unavailable": return "%s库存不足；请长按补货" % _stock_label(stock_id)
		&"portion_limit": return "同一种小料最多加2份"
		&"outside_pancake": return "当前饼面没有可添加%s的位置" % _stock_label(stock_id)
		&"wrong_stage": return "鸡蛋需在第一面加入；其他小料需翻面后加入"
		&"griddle_locked": return "当前没有可用的煎饼鏊子"
		_: return "当前不能添加%s：%s" % [_stock_label(stock_id), str(result.get("reason", &"unknown"))]


func apply_clicked_youtiao(source_ref: Dictionary) -> Dictionary:
	var source_kind := StringName(source_ref.get("source_kind", &""))
	if (
		StringName(source_ref.get("product_id", &"")) not in PANCAKE_YOUTIAO_PRODUCT_IDS
		or source_kind not in [&"prepared_product_slot", &"youtiao_fryer_slot"]
	):
		return {"success": false, "reason": &"unsupported_source", "message": "只有炸制完成的油条才能加入煎饼"}
	var unit := _unit(_active_index)
	if unit == null:
		return {"success": false, "reason": &"griddle_locked", "message": "当前没有可用的煎饼鏊子"}
	var result := Dictionary(drop_on_unit(_active_index, source_ref, unit.pancake_surface.size * 0.5))
	if bool(result.get("success", false)):
		return result.merged({"one_click": true}, true)
	var message := "当前不能把油条加到煎饼上"
	match StringName(result.get("reason", &"")):
		&"wrong_stage": message = "面饼翻面后才能点击加入油条"
		&"portion_limit": message = "同一种小料最多加2份"
		&"outside_pancake": message = "当前饼面没有可添加油条的位置"
		&"source_unavailable": message = "这根油条已被取走"
		&"griddle_locked": message = "当前没有可用的煎饼鏊子"
	status_message.emit(message)
	return result.merged({"message": message}, true)


func _source_matches_reserved_ingredient_drag(source_ref: Dictionary) -> bool:
	return (
		not _reserved_ingredient_drag_stock_id.is_empty()
		and StringName(source_ref.get("source_kind", &"")) == &"pancake_shared_ingredient"
		and StringName(source_ref.get("stock_id", &"")) == _reserved_ingredient_drag_stock_id
	)


func _restore_reserved_ingredient_drag() -> Dictionary:
	if _reserved_ingredient_drag_stock_id.is_empty():
		return {"success": true, "already_finished": true}
	var stock_id := _reserved_ingredient_drag_stock_id
	_reserved_ingredient_drag_stock_id = &""
	if _session == null or not _session.has_method("restore_inventory_stock_ids"):
		return {"success": false, "reason": &"restore_unavailable", "stock_id": stock_id}
	var stock_ids: Array[StringName] = [stock_id]
	var restored := Dictionary(_session.call("restore_inventory_stock_ids", stock_ids))
	return restored


func clear_held_tool() -> void:
	_selected_tool = &""
	for unit in units:
		unit.cancel_held_tool()
	held_tool_changed.emit(&"")


func is_spreader_selected() -> bool:
	return _selected_tool == &"tool.pancake.spreader"


func is_batter_ladle_selected() -> bool:
	return _selected_tool == &"tool.pancake.ladle"


func select_worktop_tool(tool_id: StringName) -> Dictionary:
	var result := _select_worktop_tool_impl(tool_id)
	var success := bool(result.get("success", false))
	result["success"] = success
	result["reason"] = &"" if success else StringName(result.get("reason", &"action_failed"))
	result["message"] = str(result.get("message", _tool_result_message(tool_id, result)))
	result["target"] = tool_id
	return result


func _select_worktop_tool_impl(tool_id: StringName) -> Dictionary:
	if tool_id == &"tool.pancake.ladle":
		if not can_take_batter_from_ladle():
			status_message.emit("鏊面制作中，暂时不能添加面糊")
			return {"success": false, "reason": &"griddle_busy"}
		clear_held_tool()
		_set_selected_tool(tool_id)
		var ladle_unit := _unit(_active_index)
		if ladle_unit != null:
			ladle_unit.call("set_batter_ladle_armed", true)
		status_message.emit("已拿起面糊勺；按住空鏊子并拖动可调整落点，松开即放回")
		return {"success": true, "tool_id": tool_id}
	if tool_id == &"tool.pancake.press_once":
		if _session == null or not _session.has_method("progression_service"):
			return {"success": false, "reason": &"no_session"}
		var progression: RefCounted = _session.call("progression_service")
		if progression == null or not bool(progression.call("owns_growth", &"growth.automation.pancake.press_once")):
			status_message.emit("压饼器尚未解锁")
			return {"success": false, "reason": &"tool_locked"}
		var press_unit := _unit(_active_index)
		if press_unit == null:
			return {"success": false, "reason": &"griddle_locked"}
		var press_result := Dictionary(press_unit.call("use_press_spreader"))
		clear_held_tool()
		_sync_snapshot_to_session()
		if bool(press_result.get("success", false)):
			status_message.emit("压饼器已压平饼皮，进入第一面煎制")
		else:
			status_message.emit(str(press_result.get("message", "倒入面糊后、进入煎制前才能使用压饼器")))
		return press_result
	if tool_id == &"tool.pancake.spreader":
		clear_held_tool()
		_set_selected_tool(tool_id)
		status_message.emit("已拿起摊饼器；摊面糊时绕鏊面转一圈即可，也可用来摊蛋")
		return {"success": true, "tool_id": tool_id}
	if tool_id != &"stock.pancake.sauce.sweet_flour":
		return {"success": false, "reason": &"unknown_tool"}
	if _session == null or not _session.has_method("inventory_snapshot"):
		return {"success": false, "reason": &"no_session"}
	var progression: RefCounted = _session.call("progression_service") if _session.has_method("progression_service") else null
	if progression == null or not bool(progression.call("owns_stock", tool_id)):
		status_message.emit("%s尚未解锁" % _stock_label(tool_id))
		return {"success": false, "reason": &"stock_locked"}
	if not _stock_is_unlimited(tool_id) and int(Dictionary(_session.call("inventory_snapshot")).get(str(tool_id), 0)) <= 0:
		status_message.emit("%s库存不足；请长按酱罐补货" % _stock_label(tool_id))
		return {"success": false, "reason": &"insufficient_stock"}
	var unit := _unit(_active_index)
	if unit == null or not unit.has_method("validate_sauce_prime"):
		return {"success": false, "reason": &"griddle_locked"}
	var validation := Dictionary(unit.call("validate_sauce_prime", tool_id))
	if not bool(validation.get("success", false)):
		var reason := StringName(validation.get("reason", &""))
		match reason:
			&"portion_limit": status_message.emit("同一种小料最多加2份")
			&"outside_pancake": status_message.emit("当前饼面没有可落酱的位置")
			_: status_message.emit("面饼翻面后才能点击酱料")
		return validation
	var consumed := _consume_inventory_stock(tool_id)
	if not bool(consumed.get("success", false)):
		status_message.emit("%s库存不足" % _stock_label(tool_id))
		return consumed
	var automated := Dictionary(unit.call("apply_sauce_automatically", tool_id, validation))
	if not bool(automated.get("success", false)):
		return automated
	clear_held_tool()
	_sync_snapshot_to_session()
	status_message.emit("%s已自动刷好" % _stock_label(tool_id))
	return automated.merged({"tool_id": tool_id, "unit_index": _active_index}, true)


func _tool_result_message(tool_id: StringName, result: Dictionary) -> String:
	if bool(result.get("success", false)):
		return {
			&"tool.pancake.ladle": "已拿起面糊勺",
			&"tool.pancake.spreader": "已拿起摊饼器",
			&"tool.pancake.press_once": "压饼器操作完成",
			&"stock.pancake.sauce.sweet_flour": "秘制酱料已刷好",
		}.get(tool_id, "工具已就绪")
	return {
		&"griddle_busy": "当前鏊面制作中，不能使用面糊勺",
		&"griddle_locked": "当前没有可用的煎饼鏊子",
		&"tool_locked": "该工具尚未解锁",
		&"stock_locked": "秘制酱料尚未解锁",
		&"insufficient_stock": "秘制酱料库存不足",
		&"portion_limit": "同一种酱料最多加2份",
		&"outside_pancake": "当前饼面没有可落酱的位置",
		&"wrong_stage": "当前制作阶段不能使用该工具",
		&"no_session": "当前游戏会话不可用",
		&"unknown_tool": "未知工具",
	}.get(StringName(result.get("reason", &"action_failed")), "当前无法使用该工具")


static func _tool_interaction_result(success: bool, reason: StringName, message: String, target: StringName) -> Dictionary:
	return {
		"success": success,
		"reason": reason,
		"message": message,
		"target": target,
	}


func _set_selected_tool(tool_id: StringName) -> void:
	_selected_tool = tool_id
	held_tool_changed.emit(tool_id)


func _spreader_width_multiplier() -> float:
	return 1.0


func _consume_ingredient(stock_id: StringName) -> Dictionary:
	if _session == null:
		return {"success": false, "reason": &"no_session"}
	if stock_id == &"stock.pancake.youtiao":
		if not _session.has_method("take_prepared_product"):
			return {"success": false, "reason": &"no_youtiao_source"}
		return Dictionary(_session.call("take_ready_youtiao_for_pancake"))
	if not _session.has_method("consume_inventory_stock_ids"):
		return {"success": false, "reason": &"no_inventory"}
	var stock_ids: Array[StringName] = [stock_id]
	return Dictionary(_session.call("consume_inventory_stock_ids", stock_ids))


func _consume_inventory_stock(stock_id: StringName) -> Dictionary:
	if _stock_is_unlimited(stock_id):
		return {"success": true, "consumed_stock_ids": []}
	if _session == null or not _session.has_method("consume_inventory_stock_ids"):
		return {"success": false, "reason": &"no_inventory"}
	var stock_ids: Array[StringName] = [stock_id]
	return Dictionary(_session.call("consume_inventory_stock_ids", stock_ids))


func _stock_is_unlimited(stock_id: StringName) -> bool:
	return bool(CATALOG.stock_definition(stock_id).get("unlimited", false))


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
		scoring_sauces.append(&"sweet_flour")
	scoring_order["ingredients"] = scoring_ingredients
	scoring_order["sauces"] = scoring_sauces
	var score_result := PANCAKE_SCORER.evaluate_order(
		unit.pancake_model,
		unit.ingredient_model,
		unit.fold_model,
		scoring_order,
		float(unit.p1_session.elapsed_seconds),
		float(unit.p1_session.patience_ratio()),
		bool(unit.get("egg_automation_applied")),
		bool(unit.get("sauce_automation_applied")),
		bool(unit.get("automatic_batter_ladle_applied")) and bool(unit.get("press_spreader_applied")),
		bool(unit.call("non_burning_upgrade_enabled")),
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
	var heat_metrics := Dictionary(score_result.get("metrics", {}))
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
		"heat_is_suitable": PANCAKE_SCORER.heat_is_suitable_metrics(heat_metrics),
		"heat_feedback": PANCAKE_SCORER.heat_feedback_for_metrics(heat_metrics),
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
		"ingredients": PackedStringArray(),
		"sauces": PackedStringArray(),
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"time_limit": 72.0,
		"tutorial_no_countdown": true,
	}


func _sync_snapshot_to_session() -> void:
	if _session == null or not _session.has_method("save_five_area_pancake_griddles"):
		return
	var next_snapshot := snapshot()
	if next_snapshot == _last_synced_snapshot:
		return
	var result: Variant = _session.call("save_five_area_pancake_griddles", next_snapshot)
	if result is Dictionary and not bool(Dictionary(result).get("success", false)):
		return
	_last_synced_snapshot = next_snapshot.duplicate(true)


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
	if units.is_empty():
		return
	units[0].visible = true
	units[0].position = Vector2(380.0, 105.0)
	units[0].call("set_upgrade_locked", false)
