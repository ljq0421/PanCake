extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")
const PRODUCTION_SERVICE := preload("res://scripts/services/five_area_production_service.gd")

class FakeProgression:
	extends RefCounted
	var stock_capacity := 6
	var owned_growth_ids := PackedStringArray()

	func owns_stock(_stock_id: StringName) -> bool:
		return true

	func owns_growth(growth_id: StringName) -> bool:
		return owned_growth_ids.has(str(growth_id))


class FakeSession:
	extends Node
	var progression := FakeProgression.new()
	var inventory := {"stock.pancake.batter": 0}
	var saved_griddles: Dictionary = {}
	var griddle_save_calls := 0
	var fryer_slot_available := true

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array) -> Dictionary:
		for stock_id in stock_ids:
			var key := str(stock_id)
			if int(inventory.get(key, 0)) <= 0:
				return {"success": false, "reason": &"insufficient_stock"}
		for stock_id in stock_ids:
			var key := str(stock_id)
			inventory[key] = int(inventory.get(key, 0)) - 1
		return {"success": true}

	func five_area_pancake_griddles_snapshot() -> Dictionary:
		return saved_griddles.duplicate(true)

	func save_five_area_pancake_griddles(value: Dictionary) -> Dictionary:
		griddle_save_calls += 1
		saved_griddles = value.duplicate(true)
		return {"success": true}

	func preview_take_youtiao_fryer_slot(slot_index: int) -> Dictionary:
		return {"success": fryer_slot_available and slot_index == 0}

	func take_youtiao_fryer_slot(slot_index: int) -> Dictionary:
		var preview := preview_take_youtiao_fryer_slot(slot_index)
		if bool(preview.get("success", false)):
			fryer_slot_available = false
		return preview

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := FakeSession.new()
	root.add_child(session)
	var station := STATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	station.bind_session(session)
	_check(station.units.size() == 1, "single-stall scene authors exactly one griddle unit")
	_check(station.get_node_or_null("SharedToolTray") == null, "the retired hidden shared tool tray is absent")
	_check(station.get_node_or_null("Griddle01") != null and station.get_node_or_null("Griddle02") == null and station.get_node_or_null("Griddle03") == null, "secondary griddle nodes are absent")
	for _refresh in 20:
		station.set_griddle_count(3)
	station.call("_process", 1.01)
	_check(station.griddle_count() == 1, "legacy count requests cannot expand the single stall")
	_check(session.griddle_save_calls == 0, "reapplying the single-griddle layout and its safety tick do not rewrite an unchanged save")
	var unit := station.units[0] as CompactGriddleUnit
	_check(unit.position.is_equal_approx(Vector2(380.0, 105.0)), "the sole griddle retains the scene-authored single-stall position")
	for coverage_index in unit.pancake_model.coverage.size():
		unit.pancake_model.coverage[coverage_index] = 1.0
	unit.state = CompactGriddleUnit.State.GARNISH
	var fryer_youtiao_source := {"source_kind": &"youtiao_fryer_slot", "source_index": 0, "product_id": &"product.youtiao.plain"}
	var pancake_center := unit.pancake_surface.size * 0.5
	var fryer_youtiao_preview: bool = station.can_preview_drop_on_unit(0, fryer_youtiao_source, pancake_center)
	var direct_youtiao_drop := Dictionary(station.drop_on_unit(0, fryer_youtiao_source, pancake_center))
	var retired_sesame_source := {"source_kind": &"prepared_product_slot", "source_slot_id": &"slot.04", "source_index": 1, "product_id": &"product.youtiao.sesame"}
	var retired_sesame_preview: bool = station.can_preview_drop_on_unit(0, retired_sesame_source, pancake_center)
	_check(
		fryer_youtiao_preview
		and bool(direct_youtiao_drop.get("success", false))
		and not session.fryer_slot_available
		and not retired_sesame_preview
		and unit.ingredient_model.count_type(IngredientModel.YOUTIAO) == 1,
		"only a plain ready fryer youtiao can be dragged onto the pancake"
	)
	unit.reset_unit()
	_check(
		unit.package_visual.scale.is_equal_approx(Vector2(2.0, 2.0))
		and unit.package_visual.pivot_offset.is_equal_approx(unit.package_visual.size * 0.5)
		and unit.package_visual.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the ready-product artwork keeps its authored scale around its original center without taking pointer input",
	)
	var save_calls_before_main_action := session.griddle_save_calls
	station.call("_on_main_action", 0)
	_check(session.griddle_save_calls == save_calls_before_main_action + 1, "a real griddle state change still persists exactly once")
	_check(int(session.inventory["stock.pancake.batter"]) == 0 and unit.state == CompactGriddleUnit.State.BATTER, "the visible griddle starts with unlimited batter and does not consume inventory")
	_check(unit.pancake_surface.visible and unit.pancake_surface._has_point(unit.pancake_surface.size * 0.5), "the single griddle keeps its elliptical interactive pancake surface")
	var locked_press := Dictionary(station.select_worktop_tool(&"tool.pancake.press_once"))
	_check(not bool(locked_press.get("success", false)) and StringName(locked_press.get("reason", &"")) == &"tool_locked", "the press tool stays unavailable before its growth unlock")
	session.progression.owned_growth_ids.append("growth.automation.pancake.press_once")
	var press_result := Dictionary(station.select_worktop_tool(&"tool.pancake.press_once"))
	_check(bool(press_result.get("success", false)) and unit.state == CompactGriddleUnit.State.FIRST_SIDE, "the unlocked press tool converts batter into a ready first-side pancake")
	_check(unit.state_label.text.contains("折叠") and unit.state_label.text.contains("-12"), "the first-side hint exposes direct folding and its score cost")
	var unflipped_fold := Dictionary(station.begin_surface_action(0, unit.pancake_surface.size * Vector2(0.12, 0.5)))
	var unflipped_product: Dictionary = station.call("_build_product", unit)
	var unflipped_production := Dictionary(Dictionary(unflipped_product.get("serving_score_basis", {})).get("production", {}))
	_check(
		bool(unflipped_fold.get("success", false))
		and StringName(unflipped_fold.get("action", &"")) == CompactGriddleUnit.SURFACE_ACTION_FOLD
		and unit.state == CompactGriddleUnit.State.FOLDING
		and unit.p1_session.phase == P1Session.Phase.FOLD
		and not unit.pancake_model.is_flipped,
		"grabbing the first-side edge starts folding without forcing a flip",
	)
	_check(
		is_equal_approx(float(unflipped_production.get("unflipped_delivery_penalty", 0.0)), 12.0),
		"an unflipped direct-fold product preserves the 12-point delivery penalty",
	)
	unit.reset_unit()
	station.call("_on_main_action", 0)
	var legacy_slot := Dictionary(unit.snapshot())
	var legacy_snapshot := {"version": 1, "griddle_count": 3, "active_index": 2, "product_sequence": 7, "slots": [legacy_slot, {}, {}]}
	unit.reset_unit()
	var migration := Dictionary(station.load_snapshot(legacy_snapshot))
	_check(bool(migration.get("success", false)) and station.griddle_count() == 1 and station.units[0].state == CompactGriddleUnit.State.BATTER, "legacy multi-griddle snapshot restores only its primary slot")
	var production: RefCounted = PRODUCTION_SERVICE.new()
	var saved := Dictionary(production.call("set_pancake_griddles_snapshot", legacy_snapshot))
	var normalized := Dictionary(production.call("pancake_griddles_snapshot"))
	_check(bool(saved.get("success", false)) and int(normalized.get("griddle_count", 0)) == 1 and Array(normalized.get("slots", [])).size() == 1 and int(normalized.get("active_index", -1)) == 0, "production persistence normalizes old multi-griddle snapshots")

	unit.begin_order({"time_limit": 72.0})
	unit.pancake_model.coverage.fill(1.0)
	unit.pancake_model.thickness.fill(0.55)
	unit.pancake_model.doneness.fill(0.62)
	unit.state = CompactGriddleUnit.State.GARNISH
	unit.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	unit.call("_refresh_ui")
	unit.call("_on_surface_pointer_started", unit.pancake_surface.size * Vector2(0.12, 0.50))
	unit.call("_on_surface_pointer_ended", unit.pancake_surface.size * Vector2(0.54, 0.50))
	await create_timer(0.70).timeout
	unit.call("_on_surface_pointer_started", unit.pancake_surface.size * Vector2(0.88, 0.50))
	unit.call("_on_surface_pointer_ended", unit.pancake_surface.size * Vector2(0.46, 0.50))
	var pending_snapshot := Dictionary(unit.snapshot())
	_check(
		unit.state == CompactGriddleUnit.State.FOLDING
		and bool(pending_snapshot.get("packaging_pending", false))
		and unit.fold_model.package_result == PancakeFoldModel.PACKAGE_NONE,
		"the final fold remains visible while its landing animation finishes",
	)
	await create_timer(0.70).timeout
	var packaging_material := unit.pancake_visual.material as ShaderMaterial
	_check(
		unit.fold_model.package_result == PancakeFoldModel.PACKAGE_BAG
		and is_equal_approx(float(packaging_material.get_shader_parameter(&"package_hidden")), 1.0),
		"the entering paper bag fully replaces the folded-pancake artwork instead of layering over it",
	)
	await create_timer(0.45).timeout
	_check(
		unit.state == CompactGriddleUnit.State.READY
		and unit.fold_model.package_result == PancakeFoldModel.PACKAGE_BAG
		and not unit.ready_product.is_empty(),
		"the settled fold automatically completes the single paper-bag transition before delivery unlocks",
	)
	station.queue_free()
	session.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SINGLE_GRIDDLE_STATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("SINGLE_GRIDDLE_STATION_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
