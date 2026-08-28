extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")
const WORKTOP_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")
const HOTSPOTS_SCRIPT := preload("res://scripts/ui/pancake_worktop_hotspots.gd")


class FakeProgression:
	extends RefCounted

	var locked := {}
	var owned_growth := {}
	var stock_capacity := 6

	func owns_stock(stock_id: StringName) -> bool:
		return not locked.has(stock_id)

	func owns_growth(growth_id: StringName) -> bool:
		return owned_growth.has(growth_id)

class FakeSession:
	extends Node

	var progression := FakeProgression.new()
	var restock_hold_seconds := {}
	var inventory := {
		"stock.pancake.batter": 2,
		"stock.pancake.egg": 2,
		"stock.pancake.baocui": 2,
		"stock.pancake.meat_floss": 2,
		"stock.pancake.scallion": 2,
		"stock.pancake.coriander": 2,
		"stock.pancake.sauce.sweet_flour": 4,
		"stock.pancake.sauce.red_chili": 2,
		"stock.pancake.sauce.tomato": 2,
	}

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array) -> Dictionary:
		for stock_id in stock_ids:
			if int(inventory.get(str(stock_id), 0)) <= 0:
				return {"success": false, "reason": &"insufficient_stock"}
		for stock_id in stock_ids:
			var key := str(stock_id)
			inventory[key] = int(inventory.get(key, 0)) - 1
		return {"success": true}

	func five_area_restock_status(stock_id: StringName) -> Dictionary:
		return {
			"success": true,
			"stock_id": stock_id,
			"current_stock": int(inventory.get(str(stock_id), 0)),
			"capacity": 6,
			"unit_cost": 1,
		}

	func advance_five_area_restock_hold(stock_id: StringName, delta: float) -> Dictionary:
		restock_hold_seconds[stock_id] = float(restock_hold_seconds.get(stock_id, 0.0)) + delta
		return {"success": true, "completed_units": 0, "auto_stopped": false}


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
	var unit: Node = station.units[0]
	_test_egg_on_first_side(station, unit, session)
	_test_default_automatic_sauce_after_flip(station, unit, session)
	_test_sauce_guards_second_side_and_restore(station, unit, session)
	_test_one_click_ingredient_upgrades(station, unit, session)
	await _test_worktop_hotspot_mapping(session)
	station.queue_free()
	session.queue_free()
	_finish()


func _test_egg_on_first_side(station: Node, unit: Node, session: FakeSession) -> void:
	var source := {"source_kind": &"pancake_shared_ingredient", "stock_id": &"stock.pancake.egg"}
	var center: Vector2 = unit.pancake_surface.size * 0.5
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	var first_validation := Dictionary(unit.validate_ingredient_drop(source, center))
	_check(bool(first_validation.get("success", false)), "egg can be dropped on the first side")
	var placed := Dictionary(station.drop_on_unit(0, source, center))
	_check(bool(placed.get("success", false)) and unit.pancake_model.has_egg(), "first-side egg placement records the egg")
	_check(unit.egg_shell_visual.visible and unit.egg_shell_visual.position.is_equal_approx(center + Vector2(0.0, -88.8)), "egg shell bottom stays 60px above the pancake while liquid falls")
	_check(unit.egg_intact_visual.visible and unit.egg_intact_visual.position.is_equal_approx(center + Vector2(0.0, -88.8)), "egg liquid begins at the opened shell position")
	_check(int(session.inventory["stock.pancake.egg"]) == 1, "egg placement consumes exactly one inventory unit")
	unit.call("_complete_egg_liquid_fall")
	var second_egg_position := center + Vector2(20.0, 0.0)
	var second_placed := Dictionary(station.drop_on_unit(0, source, second_egg_position))
	_check(bool(second_placed.get("success", false)) and unit.ingredient_model.count_type(IngredientModel.EGG) == 2 and int(session.inventory["stock.pancake.egg"]) == 0, "a second egg is accepted and consumes a second inventory unit")
	unit.call("_complete_egg_liquid_fall")
	_check(
		unit.egg_intact_visual.visible
		and unit.egg_intact_visual.position.is_equal_approx(second_egg_position)
		and unit.egg_intact_visual_second.visible
		and unit.egg_intact_visual_second.position.is_equal_approx(center)
		and unit.egg_intact_visual.scale.is_equal_approx(CompactGriddleUnit.EGG_INTACT_VISUAL_SCALE),
		"two consecutively cracked eggs remain complete and visible before one shared spread action",
	)
	var staged_double_egg_snapshot: Dictionary = Dictionary(unit.snapshot())
	var restored_double_egg := Dictionary(unit.load_snapshot(staged_double_egg_snapshot))
	_check(
		bool(restored_double_egg.get("success", false))
		and unit.egg_intact_visual.visible
		and unit.egg_intact_visual_second.visible
		and not unit.egg_intact_visual.position.is_equal_approx(unit.egg_intact_visual_second.position),
		"two intact eggs remain visible after restoring an in-progress pancake",
	)
	var first_egg_grid_position := Vector2(unit.ingredient_model.placements.front().position)
	var double_egg_spread := Dictionary(unit.pancake_model.apply_egg_spreader_sample(first_egg_grid_position, Vector2.RIGHT, 70.0))
	unit.call("_finish_egg_spread_visuals")
	_check(
		float(double_egg_spread.get("moved_mass", 0.0)) > 0.0
		and unit.pancake_model.yolk_broken,
		"one spread action starts the shared double-egg spreading layer",
	)
	_check(
		not unit.egg_intact_visual.visible and not unit.egg_intact_visual_second.visible,
		"spreading clears both complete-egg sprites together",
	)
	var third_validation := Dictionary(unit.validate_ingredient_drop(source, center + Vector2(-20.0, 0.0)))
	_check(not bool(third_validation.get("success", false)) and StringName(third_validation.get("reason", &"")) == &"portion_limit", "a third egg is rejected at the two-portion limit")
	unit.reset_unit()
	unit.begin_order({})
	unit.pancake_model.flip(true)
	unit.state = CompactGriddleUnit.State.SECOND_SIDE
	unit.p1_session.phase = P1Session.Phase.SECOND_SIDE
	var post_flip_validation := Dictionary(unit.validate_ingredient_drop(source, center))
	_check(not bool(post_flip_validation.get("success", false)) and StringName(post_flip_validation.get("reason", &"")) == &"wrong_stage", "egg cannot be added after flipping")


func _test_default_automatic_sauce_after_flip(station: Node, unit: Node, session: FakeSession) -> void:
	station.clear_held_tool()
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	var before := int(session.inventory["stock.pancake.sauce.sweet_flour"])
	var rejected := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	_check(not bool(rejected.get("success", false)) and StringName(rejected.get("reason", &"")) == &"wrong_stage", "sauce is rejected before the pancake is flipped")
	unit.pancake_model.flip(true)
	unit.state = CompactGriddleUnit.State.SECOND_SIDE
	unit.p1_session.phase = P1Session.Phase.SECOND_SIDE
	var selected := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	var sauce_quality := PancakeScorer.evaluate_sauce(unit.pancake_model)
	_check(bool(selected.get("success", false)) and bool(selected.get("automated", false)), "a post-flip sauce click applies sauce automatically")
	_check(int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before, "automatic unlimited sauce does not consume inventory")
	_check(unit.applied_sauce_ids.has("stock.pancake.sauce.sweet_flour") and unit.state == CompactGriddleUnit.State.SECOND_SIDE, "automatic sauce records its recipe identifier without ending second-side cooking")
	_check(not unit.pancake_surface.cursor_is_sauce_brush and float(sauce_quality.get("coverage_ratio", 0.0)) >= 0.99 and float(sauce_quality.get("uniformity", 0.0)) >= 0.99, "default sauce completes a uniform layer without arming a manual brush")
	var second_portion := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	var sauce_center := Vector2i(unit.pancake_model.grid_size / 2, unit.pancake_model.grid_size / 2)
	_check(
		bool(second_portion.get("success", false))
		and unit.applied_sauce_ids.count("stock.pancake.sauce.sweet_flour") == 2
		and is_equal_approx(
			unit.pancake_model.get_field_value(PancakeModel.FIELD_SAUCE_CONCENTRATION, sauce_center),
			unit.pancake_model.parameters.sauce_target_concentration * 2.0
		)
		and int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before,
		"a second unlimited sauce portion doubles the visible sauce concentration"
	)
	var before_limit := int(session.inventory["stock.pancake.sauce.sweet_flour"])
	var over_limit := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	_check(not bool(over_limit.get("success", false)) and StringName(over_limit.get("reason", &"")) == &"portion_limit" and int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before_limit, "a third sauce portion is rejected without consuming inventory")


func _test_sauce_guards_second_side_and_restore(station: Node, unit: Node, session: FakeSession) -> void:
	station.clear_held_tool()
	unit.reset_unit()
	unit.begin_order({})
	unit.pancake_model.flip(true)
	unit.state = CompactGriddleUnit.State.SECOND_SIDE
	unit.p1_session.phase = P1Session.Phase.SECOND_SIDE
	var sauce_id := &"stock.pancake.sauce.sweet_flour"
	var initial_sauce := int(session.inventory[str(sauce_id)])
	session.progression.locked[sauce_id] = true
	var locked := Dictionary(station.select_worktop_tool(sauce_id))
	_check(not bool(locked.get("success", false)) and int(session.inventory[str(sauce_id)]) == initial_sauce, "locked secret sauce cannot prime or consume inventory")
	session.progression.locked.erase(sauce_id)
	session.inventory[str(sauce_id)] = 0
	var primed := Dictionary(station.select_worktop_tool(sauce_id))
	_check(bool(primed.get("success", false)) and unit.state == CompactGriddleUnit.State.SECOND_SIDE, "unlimited secret sauce can prime without ending second-side cooking")
	_check(int(session.inventory[str(sauce_id)]) == 0 and unit.applied_sauce_ids.has(str(sauce_id)), "empty unlimited sauce inventory still primes without consumption")
	var saved := Dictionary(unit.snapshot())
	var saved_sauce_total := float(unit.pancake_model.total_sauce())
	unit.reset_unit()
	var restored := Dictionary(unit.load_snapshot(saved))
	_check(bool(restored.get("success", false)) and unit.applied_sauce_ids.has(str(sauce_id)) and is_equal_approx(float(unit.pancake_model.total_sauce()), saved_sauce_total), "primed sauce and recipe identifier survive snapshot restore")
	_check(not unit.pancake_surface.cursor_is_sauce_brush, "snapshot restore does not restore the temporary held brush")
	station.clear_held_tool()
	unit.reset_unit()
	var before_wrong_stage := int(session.inventory[str(sauce_id)])
	var wrong_stage := Dictionary(station.select_worktop_tool(sauce_id))
	_check(not bool(wrong_stage.get("success", false)) and int(session.inventory[str(sauce_id)]) == before_wrong_stage, "wrong-stage sauce click does not consume inventory")


func _test_one_click_ingredient_upgrades(station: Node, unit: Node, session: FakeSession) -> void:
	var default_click_stock_ids: Array[StringName] = [
		&"stock.pancake.baocui",
		&"stock.pancake.scallion",
		&"stock.pancake.ham_sausage",
		&"stock.pancake.coriander",
		&"stock.pancake.meat_floss",
	]
	for stock_id in default_click_stock_ids:
		session.inventory[str(stock_id)] = 2
		unit.begin_order({})
		var pressed := Dictionary(unit.use_press_spreader())
		_check(bool(pressed.get("success", false)), "%s test pancake reaches the first cooking side" % stock_id)
		var preflip_rejected := Dictionary(station.apply_one_click_ingredient(stock_id))
		_check(not bool(preflip_rejected.get("success", false)) and StringName(preflip_rejected.get("reason", &"")) == &"wrong_stage", "%s is rejected before flipping" % stock_id)
		unit.advance_main()
		var before := int(session.inventory[str(stock_id)])
		var added := Dictionary(station.apply_one_click_ingredient(stock_id))
		_check(
			bool(added.get("success", false)) and bool(added.get("one_click", false)) and int(session.inventory[str(stock_id)]) == before - 1,
			"%s click adds exactly one inventory-backed portion without an upgrade" % stock_id
		)
		var ingredient_type := StringName(added.get("ingredient_type", &""))
		_check(unit.ingredient_model.count_type(ingredient_type) == 1, "%s click creates one pancake placement" % stock_id)
		var first_position := Vector2(unit.ingredient_model.placements.back().get("position", Vector2.ZERO))
		var added_second_portion := Dictionary(station.apply_one_click_ingredient(stock_id))
		var second_position := Vector2(unit.ingredient_model.placements.back().get("position", Vector2.ZERO))
		var second_visual := unit.ingredient_layer.get_children().back() as Sprite2D
		_check(
			bool(added_second_portion.get("success", false))
			and unit.ingredient_model.count_type(ingredient_type) == 2
			and first_position.distance_to(second_position) > 1.0,
			"%s second click creates a separately visible second portion" % stock_id
		)
		_check(
			_sprite_corners_stay_on_pancake(unit, second_visual),
			"%s repeat portion and its full artwork remain inside the pancake" % stock_id
		)
		# Keep the later physical-hotspot test's original one-portion stock setup.
		session.inventory[str(stock_id)] = 1
		unit.reset_unit()
	var egg_stock_id := &"stock.pancake.egg"
	session.inventory[str(egg_stock_id)] = 2
	_check(station.one_click_ingredient_enabled(egg_stock_id) and not station.ingredient_drag_enabled(egg_stock_id), "basic egg uses the same click-to-place grammar as every raw pancake ingredient")
	unit.begin_order({})
	var basic_egg_pressed := Dictionary(unit.use_press_spreader())
	_check(bool(basic_egg_pressed.get("success", false)), "basic click egg test pancake reaches the first cooking side")
	var basic_egg_before := int(session.inventory[str(egg_stock_id)])
	var basic_egg_added := Dictionary(station.apply_one_click_ingredient(egg_stock_id))
	_check(
		bool(basic_egg_added.get("success", false))
		and unit.pancake_model.has_egg()
		and not unit.pancake_model.yolk_broken
		and int(session.inventory[str(egg_stock_id)]) == basic_egg_before - 1,
		"base egg click cracks one egg but leaves spreading as the next tool action"
	)
	var first_egg_position := Vector2(unit.ingredient_model.placements.back().get("position", Vector2.ZERO))
	var basic_second_egg_added := Dictionary(station.apply_one_click_ingredient(egg_stock_id))
	var second_egg_position := Vector2(unit.ingredient_model.placements.back().get("position", Vector2.ZERO))
	_check(
		bool(basic_second_egg_added.get("success", false))
		and unit.ingredient_model.count_type(IngredientModel.EGG) == 2
		and first_egg_position.distance_to(second_egg_position) > 1.0
		and first_egg_position.distance_to(second_egg_position) >= 17.0
		and unit.pancake_model.egg_portion_count == 2,
		"a second click egg keeps both eggs visibly separated before spreading"
	)
	unit.reset_unit()
	session.inventory[str(egg_stock_id)] = 2
	session.progression.owned_growth[&"growth.automation.pancake.one_click_egg"] = true
	unit.begin_order({})
	var egg_pressed := Dictionary(unit.use_press_spreader())
	_check(bool(egg_pressed.get("success", false)), "one-click egg test pancake reaches the first cooking side")
	var egg_before := int(session.inventory[str(egg_stock_id)])
	var egg_added := Dictionary(station.apply_one_click_ingredient(egg_stock_id))
	_check(
		bool(egg_added.get("success", false))
		and bool(egg_added.get("one_click", false))
		and bool(Dictionary(egg_added.get("auto_spread", {})).get("success", false))
		and bool(unit.get("egg_automation_applied"))
		and bool(Dictionary(unit.snapshot()).get("egg_automation_applied", false))
		and int(session.inventory[str(egg_stock_id)]) == egg_before - 1,
		"egg automation upgrade keeps the click gesture, spreads the egg, and persists its scoring guarantee"
	)
	_check(unit.pancake_model.has_egg() and unit.pancake_model.yolk_broken and not station.ingredient_drag_enabled(egg_stock_id), "egg automation changes the result, not the input gesture")
	session.progression.owned_growth.erase(&"growth.automation.pancake.one_click_egg")
	unit.reset_unit()


func _sprite_corners_stay_on_pancake(unit: Node, sprite: Sprite2D) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	var half_size := Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.scale.abs() * 0.5
	for corner in [
		sprite.position + Vector2(-half_size.x, -half_size.y),
		sprite.position + Vector2(half_size.x, -half_size.y),
		sprite.position + Vector2(-half_size.x, half_size.y),
		sprite.position + Vector2(half_size.x, half_size.y),
	]:
		if not PancakeSpace.is_inside_pan(corner, unit.pancake_surface.size, unit.pancake_model.parameters.pan_height_ratio):
			return false
	return true


func _test_worktop_hotspot_mapping(session: FakeSession) -> void:
	_check(HOTSPOTS_SCRIPT.SAUCE_HOTSPOT_IDS.size() == 1, "the physical worktop exposes exactly one secret-sauce source")
	_check(HOTSPOTS_SCRIPT.SAUCE_HOTSPOT_IDS.get(&"SecretSauceSource/Hotspot", &"") == &"stock.pancake.sauce.sweet_flour", "the secret-sauce component maps to sweet-flour sauce stock")
	session.inventory["stock.pancake.sauce.sweet_flour"] = 4
	var artwork := WORKTOP_SCENE.instantiate()
	root.add_child(artwork)
	await process_frame
	var station := artwork.get_node("MultiGriddleStation") as MultiGriddleStation
	var hotspots := artwork.get_node("PancakeWorktopHotspots") as PancakeWorktopHotspots
	station.bind_session(session)
	hotspots.bind_session(session)
	await process_frame
	var unit := station.units[0] as CompactGriddleUnit
	var spreader_hit_button := hotspots.get_node("SpreaderSource/HitButton") as AlphaTextureHitButton
	var spreader_visual := hotspots.get_node("SpreaderSource/Visual") as TextureRect
	var press_visual := hotspots.get_node("SpreaderSource/PressVisual") as TextureRect
	var batter_ladle := hotspots.get_node("BatterLadleSource/HitButton") as AlphaTextureHitButton
	var batter_ladle_visual := hotspots.get_node("BatterLadleSource/Visual") as TextureRect
	_check(spreader_hit_button != null, "spreader uses its component-local alpha hit target")
	var expected_component_rects := {
		&"PorkFlossSource": Rect2(1137.0, 578.0, 214.0, 180.0),
		&"HamSource": Rect2(1319.0, 578.0, 214.0, 180.0),
		&"EggCarton": Rect2(1269.0, 795.0, 216.0, 234.0),
		&"ScallionTray": Rect2(1128.0, 709.0, 146.0, 147.0),
		&"CorianderTray": Rect2(1233.0, 709.0, 149.0, 149.0),
		&"BaocuiBasket": Rect2(954.0, 578.0, 214.0, 180.0),
		&"SecretSauceSource": Rect2(1034.0, 717.0, 123.0, 134.4),
	}
	for component_path in expected_component_rects:
		var component := hotspots.get_node(NodePath(str(component_path))) as Control
		var visual := component.get_node("Visual") as TextureRect
		var source := component.get_node("Hotspot") as ProductDragSource
		_check(Rect2(component.position, component.size).is_equal_approx(expected_component_rects[component_path]), "%s preserves the approved 1920x1080 worktop geometry" % component_path)
		_check(visual.get_global_rect().is_equal_approx(component.get_global_rect()), "%s visual follows its single component rectangle" % component_path)
		_check(source.get_global_rect().is_equal_approx(component.get_global_rect()), "%s hotspot follows its single component rectangle" % component_path)
		_check(not source._alpha_hit_regions.is_empty(), "%s derives its clickable silhouette from its visible artwork" % component_path)
	_check(Rect2(station.position, station.size).is_equal_approx(Rect2(220.0, 566.0, 1170.0, 444.0)), "the unified pancake station preserves the authored griddle-station rectangle")
	var surface_design_rect := Rect2(station.position + unit.position + unit.pancake_surface.position, unit.pancake_surface.size)
	_check(surface_design_rect.is_equal_approx(Rect2(610.0, 622.0, 400.0, 400.0)), "the interactive griddle surface preserves its authored 1920x1080 design rectangle")
	_check(StringName(hotspots.get_node("ScallionTray/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.scallion", "left worktop bowl maps to scallion stock")
	_check(StringName(hotspots.get_node("CorianderTray/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.coriander", "coriander tray maps to coriander stock")
	_check(StringName(hotspots.get_node("BaocuiBasket/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.baocui", "middle worktop basket maps to baocui stock")
	_check(StringName(hotspots.get_node("EggCarton/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.egg", "right worktop basket maps to egg stock")
	_check(StringName(hotspots.get_node("PorkFlossSource/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.meat_floss", "pork-floss tray maps to meat-floss stock")
	_check(not bool(hotspots.get_node("ScallionTray/Hotspot").disabled), "owned scallion stock is enabled for click and hold input")
	_check(not bool(hotspots.get_node("CorianderTray/Hotspot").disabled), "owned coriander stock is enabled for click and hold input")
	_check(not bool(hotspots.get_node("PorkFlossSource/Hotspot").disabled), "owned pork-floss tray is enabled for click and hold input")
	_check(not bool(hotspots.get_node("ScallionTray/Hotspot").native_drag_enabled), "ingredient bowls use click placement")
	_check(not bool(hotspots.get_node("CorianderTray/Hotspot").native_drag_enabled), "coriander tray uses click placement")
	_check(not bool(hotspots.get_node("PorkFlossSource/Hotspot").native_drag_enabled), "pork-floss tray uses click placement")
	var egg_source := hotspots.get_node("EggCarton/Hotspot") as ProductDragSource
	_check(not egg_source.native_drag_enabled and egg_source.drag_preview_texture == null, "egg source is click-only and does not create a native drag preview")
	var scallion_click_source := hotspots.get_node("ScallionTray/Hotspot") as ProductDragSource
	unit.begin_order({})
	var click_pancake_pressed := Dictionary(unit.use_press_spreader())
	_check(bool(click_pancake_pressed.get("success", false)), "click hotspot test pancake reaches the first cooking side")
	unit.advance_main()
	var scallion_before_click := int(session.inventory["stock.pancake.scallion"])
	hotspots.call("_on_material_short_clicked", scallion_click_source.source_ref(), scallion_click_source)
	_check(
		unit.ingredient_model.count_type(IngredientModel.SCALLION) == 1 and int(session.inventory["stock.pancake.scallion"]) == scallion_before_click - 1,
		"a scallion hotspot click adds one portion without starting a drag"
	)
	unit.reset_unit()
	session.progression.owned_growth[&"growth.automation.pancake.one_click_egg"] = true
	hotspots.refresh_from_session()
	_check(not egg_source.native_drag_enabled, "egg automation upgrade preserves the click-only input gesture")
	unit.begin_order({})
	var egg_click_pancake_pressed := Dictionary(unit.use_press_spreader())
	_check(bool(egg_click_pancake_pressed.get("success", false)), "upgraded egg hotspot test pancake reaches the first cooking side")
	var egg_before_click := int(session.inventory["stock.pancake.egg"])
	hotspots.call("_on_material_short_clicked", egg_source.source_ref(), egg_source)
	_check(
		unit.pancake_model.has_egg() and int(session.inventory["stock.pancake.egg"]) == egg_before_click - 1,
		"an upgraded egg hotspot click cracks one egg at the standard position"
	)
	session.progression.owned_growth.erase(&"growth.automation.pancake.one_click_egg")
	unit.reset_unit()
	hotspots.refresh_from_session()
	_check(not egg_source.native_drag_enabled, "without the upgrade, egg remains click-to-crack")
	var secret_sauce := hotspots.get_node("SecretSauceSource/Hotspot") as ProductDragSource
	_check(not secret_sauce.native_drag_enabled and not secret_sauce.disabled, "secret sauce selects direct brushing on its own component-local input surface")
	_check(batter_ladle.tooltip_text == "点击拿起面糊勺，在空鏊子上按住并拖动调整落点", "basic batter ladle explains the movable pour interaction")
	hotspots.call("_on_batter_ladle_button_down")
	_check(bool(station.call("is_batter_ladle_selected")) and unit.state == CompactGriddleUnit.State.IDLE, "basic batter ladle click picks up the tool without immediately pouring")
	_check(unit.pancake_surface.batter_pour_guide_visible and unit.pancake_surface.batter_pour_guide_outer_radius_pixels > unit.pancake_surface.batter_pour_guide_inner_radius_pixels, "basic batter ladle shows two rings for the recommended batter area")
	unit.call("_process_batter_ladle_drag", 0.0)
	_check(bool(station.call("is_batter_ladle_selected")) and unit.state == CompactGriddleUnit.State.IDLE, "releasing the holder click keeps the basic ladle in hand until an empty griddle is pressed")
	var pour_center: Vector2 = unit.pancake_surface.size * 0.5
	unit.call("_on_surface_pointer_started", pour_center)
	unit.call("_process_batter_pour", 0.20)
	var early_pour_coverage := float(unit.pancake_model.calculate_summary().get("coverage_ratio", 0.0))
	unit.call("_process_batter_pour", 0.20)
	var later_pour_coverage := float(unit.pancake_model.calculate_summary().get("coverage_ratio", 0.0))
	_check(later_pour_coverage > early_pour_coverage, "holding the basic ladle expands the visible batter range as well as deepening it")
	unit.call("_on_surface_pointer_ended", pour_center)
	_check(not unit.pancake_surface.batter_pour_guide_visible, "releasing the basic batter ladle freezes the batter range and hides its guide rings")
	var held_batter_thickness := float(unit.pancake_model.calculate_summary().get("mean_thickness", 0.0))
	_check(unit.state == CompactGriddleUnit.State.BATTER and held_batter_thickness > 0.0 and not bool(station.call("is_batter_ladle_selected")) and not bool(station.call("is_spreader_selected")), "releasing after pouring returns the ladle to its holder")
	hotspots.refresh_from_session()
	_check(
		batter_ladle_visual.texture.resource_path.ends_with("batter_ladle_holder_occupied_v1.png")
		and batter_ladle.disabled,
		"released ladle returns visibly to its disabled holder while the griddle is busy",
	)
	unit.reset_unit()
	session.progression.owned_growth[&"growth.automation.pancake.auto_batter_ladle"] = true
	hotspots.refresh_from_session()
	_check(batter_ladle.tooltip_text == "点击加标准分量面糊", "upgraded batter ladle explains one-click standard filling")
	hotspots.call("_on_batter_ladle_pressed")
	var automatic_batter_thickness := float(unit.pancake_model.calculate_summary().get("mean_thickness", 0.0))
	_check(unit.state == CompactGriddleUnit.State.BATTER and automatic_batter_thickness > held_batter_thickness, "upgraded batter ladle immediately adds the standard amount")
	hotspots.refresh_from_session()
	_check(
		batter_ladle_visual.texture.resource_path.ends_with("batter_ladle_holder_occupied_v1.png")
		and batter_ladle.disabled,
		"automatic filling also leaves the ladle visibly returned to its holder",
	)
	unit.reset_unit()
	var scallion := hotspots.get_node("ScallionTray/Hotspot") as ProductDragSource
	scallion.begin_gesture(Vector2.ZERO)
	scallion.advance_gesture(0.20)
	_check(scallion.is_hold_active(), "holding owned scallion stock enters the restock gesture")
	scallion.advance_gesture(0.20)
	_check(float(session.restock_hold_seconds.get(&"stock.pancake.scallion", 0.0)) > 0.0, "holding scallion stock advances the restock service")
	scallion.end_gesture()
	var pork_floss_source := hotspots.get_node("PorkFlossSource/Hotspot") as ProductDragSource
	pork_floss_source.begin_gesture(Vector2.ZERO)
	pork_floss_source.advance_gesture(0.20)
	_check(pork_floss_source.is_hold_active(), "holding pork-floss tray enters the restock gesture")
	pork_floss_source.advance_gesture(0.20)
	_check(float(session.restock_hold_seconds.get(&"stock.pancake.meat_floss", 0.0)) > 0.0, "holding pork-floss tray advances the restock service")
	pork_floss_source.end_gesture()
	station.clear_held_tool()
	hotspots.set_workshop_preview(true)
	_check(hotspots.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "workshop preview disables all worktop interaction")
	_check(bool(hotspots.get_node("ScallionTray/Hotspot").disabled), "workshop preview disables unlocked ingredient interaction")
	_check(bool(secret_sauce.disabled), "workshop preview disables unlocked sauce interaction")
	_check(not spreader_visual.visible, "workshop preview reserves the holder position for the press upgrade")
	hotspots.set_workshop_preview(false)
	_check(hotspots.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED, "closing workshop preview restores worktop input behavior")
	_check(not bool(hotspots.get_node("ScallionTray/Hotspot").disabled), "closing workshop preview restores owned ingredient interaction")
	_check(not secret_sauce.disabled, "closing workshop preview restores owned sauce interaction")
	_check(spreader_visual.visible, "closing workshop preview restores the runtime spreader holder")
	_check(spreader_visual.texture.resource_path.ends_with("batter_spreader_holder_wide_filled_v2.png"), "closing workshop preview restores the base spreader artwork")
	session.progression.owned_growth[&"growth.automation.pancake.press_once"] = true
	hotspots.refresh_from_session()
	_check(not spreader_visual.visible and press_visual.visible, "owned press replaces the base holder in the normal worktop")
	_check(press_visual.texture.resource_path.ends_with("pancake-press-wide-upgrade-v2-base.png"), "owned press uses its scene-authored visual")
	station.select_worktop_tool(&"tool.pancake.spreader")
	hotspots.refresh_from_session()
	_check(press_visual.visible, "held spreader state does not hide the installed press")
	unit.reset_unit()
	var batter_started := Dictionary(station.take_batter_from_ladle())
	spreader_hit_button.pressed.emit()
	await process_frame
	_check(bool(batter_started.get("success", false)) and unit.state == CompactGriddleUnit.State.FIRST_SIDE, "press position activates the one-click press after batter is added")
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	unit.pancake_model.coverage.fill(1.0)
	unit.advance_main()
	secret_sauce.begin_gesture(Vector2.ZERO)
	secret_sauce.end_gesture()
	_check(unit.pancake_model.total_sauce() > 0.0 and not unit.pancake_surface.cursor_is_sauce_brush, "post-flip secret-sauce click applies sauce automatically without a manual brush")
	artwork.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PANCAKE_WORKTOP_HOTSPOTS_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_WORKTOP_HOTSPOTS_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
