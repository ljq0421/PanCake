extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")
const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")
const HOTSPOTS_SCRIPT := preload("res://scripts/ui/pancake_worktop_hotspots.gd")
const DRAG_SOURCE_SCRIPT := preload("res://scripts/ui/product_drag_source.gd")


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
		"stock.pancake.sauce.sweet_flour": 2,
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
	_test_egg_on_both_sides(station, unit, session)
	_test_sauce_selection_and_first_stroke(station, unit, session)
	_test_automatic_sauce_brush(station, unit, session)
	_test_tomato_sauce_selection(station, unit, session)
	_test_sauce_guards_second_side_and_restore(station, unit, session)
	_test_worktop_hotspot_mapping(station, unit, session)
	station.queue_free()
	session.queue_free()
	_finish()


func _test_egg_on_both_sides(station: Node, unit: Node, session: FakeSession) -> void:
	var source := {"source_kind": &"pancake_shared_ingredient", "stock_id": &"stock.pancake.egg"}
	var center: Vector2 = unit.pancake_surface.size * 0.5
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	var first_validation := Dictionary(unit.validate_ingredient_drop(source, center))
	_check(bool(first_validation.get("success", false)), "egg can be dropped on the first side")
	unit.reset_unit()
	unit.begin_order({})
	unit.pancake_model.flip(true)
	unit.state = CompactGriddleUnit.State.SECOND_SIDE
	var second_validation := Dictionary(unit.validate_ingredient_drop(source, center))
	_check(bool(second_validation.get("success", false)), "egg can be dropped on the second side")
	var placed := Dictionary(station.drop_on_unit(0, source, center))
	_check(bool(placed.get("success", false)) and unit.pancake_model.has_egg(), "second-side egg placement records the egg")
	_check(int(session.inventory["stock.pancake.egg"]) == 1, "egg placement consumes exactly one inventory unit")
	_check(not bool(unit.validate_ingredient_drop(source, center).get("success", false)), "a second egg is rejected as a duplicate")


func _test_sauce_selection_and_first_stroke(station: Node, unit: Node, session: FakeSession) -> void:
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	var center: Vector2 = unit.pancake_surface.size * 0.5
	var before := int(session.inventory["stock.pancake.sauce.sweet_flour"])
	var selected := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	var primed_total := float(unit.pancake_model.total_sauce())
	_check(bool(selected.get("success", false)), "sweet sauce jar primes the direct-brush tool")
	_check(int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before - 1, "sauce jar click consumes exactly one inventory unit")
	_check(primed_total > 0.0 and unit.applied_sauce_ids.has("stock.pancake.sauce.sweet_flour"), "sauce jar click places a central dollop and records its recipe identifier")
	_check(unit.pancake_surface.cursor_is_sauce_brush and unit.state == CompactGriddleUnit.State.GARNISH, "sauce jar click enters garnish flow and automatically arms the brush")
	unit._on_surface_pointer_started(center)
	unit._on_surface_pointer_ended(center)
	_check(int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before - 1, "drag brushing does not consume a second inventory unit")
	_check(float(unit.pancake_model.total_sauce()) >= primed_total, "drag brushing preserves and spreads the primed sauce")
	var before_duplicate := int(session.inventory["stock.pancake.sauce.sweet_flour"])
	var duplicate := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	_check(not bool(duplicate.get("success", false)) and int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before_duplicate, "duplicate sauce jar click is rejected without consuming inventory")


func _test_automatic_sauce_brush(station: Node, unit: Node, session: FakeSession) -> void:
	station.clear_held_tool()
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	session.progression.owned_growth[&"growth.automation.pancake.auto_sauce_brush"] = true
	var before := int(session.inventory["stock.pancake.sauce.sweet_flour"])
	var selected := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.sweet_flour"))
	var sauce_quality := PancakeScorer.evaluate_sauce(unit.pancake_model)
	_check(bool(selected.get("success", false)) and bool(selected.get("automated", false)), "automatic sauce brush applies sauce from a jar click")
	_check(int(session.inventory["stock.pancake.sauce.sweet_flour"]) == before - 1, "automatic sauce brush consumes exactly one sauce unit")
	_check(unit.applied_sauce_ids.has("stock.pancake.sauce.sweet_flour") and unit.state == CompactGriddleUnit.State.GARNISH, "automatic sauce brush records the sauce and advances to garnish")
	_check(not unit.pancake_surface.cursor_is_sauce_brush and float(sauce_quality.get("coverage_ratio", 0.0)) >= 0.99 and float(sauce_quality.get("uniformity", 0.0)) >= 0.99, "automatic sauce brush completes a uniform layer without arming manual brushing")
	session.progression.owned_growth.erase(&"growth.automation.pancake.auto_sauce_brush")


func _test_tomato_sauce_selection(station: Node, unit: Node, session: FakeSession) -> void:
	station.clear_held_tool()
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	var before := int(session.inventory["stock.pancake.sauce.tomato"])
	var selected := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.tomato"))
	_check(bool(selected.get("success", false)), "tomato sauce jar primes the direct-brush tool")
	_check(int(session.inventory["stock.pancake.sauce.tomato"]) == before - 1, "tomato sauce jar click consumes exactly one inventory unit")
	_check(unit.applied_sauce_ids.has("stock.pancake.sauce.tomato"), "tomato sauce jar click records its recipe identifier")


func _test_sauce_guards_second_side_and_restore(station: Node, unit: Node, session: FakeSession) -> void:
	station.clear_held_tool()
	unit.reset_unit()
	unit.begin_order({})
	unit.pancake_model.flip(true)
	unit.state = CompactGriddleUnit.State.SECOND_SIDE
	unit.p1_session.phase = P1Session.Phase.SECOND_SIDE
	var initial_chili := int(session.inventory["stock.pancake.sauce.red_chili"])
	session.progression.locked[&"stock.pancake.sauce.red_chili"] = true
	var locked := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.red_chili"))
	_check(not bool(locked.get("success", false)) and int(session.inventory["stock.pancake.sauce.red_chili"]) == initial_chili, "locked chili sauce cannot prime or consume inventory")
	session.progression.locked.erase(&"stock.pancake.sauce.red_chili")
	session.inventory["stock.pancake.sauce.red_chili"] = 0
	var depleted := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.red_chili"))
	_check(not bool(depleted.get("success", false)) and is_zero_approx(float(unit.pancake_model.total_sauce())), "depleted chili sauce cannot create a dollop")
	session.inventory["stock.pancake.sauce.red_chili"] = initial_chili
	var primed := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.red_chili"))
	_check(bool(primed.get("success", false)) and unit.state == CompactGriddleUnit.State.GARNISH, "chili sauce can prime on the second side")
	_check(int(session.inventory["stock.pancake.sauce.red_chili"]) == initial_chili - 1 and unit.applied_sauce_ids.has("stock.pancake.sauce.red_chili"), "second-side chili prime consumes and records exactly once")
	var saved := Dictionary(unit.snapshot())
	var saved_sauce_total := float(unit.pancake_model.total_sauce())
	unit.reset_unit()
	var restored := Dictionary(unit.load_snapshot(saved))
	_check(bool(restored.get("success", false)) and unit.applied_sauce_ids.has("stock.pancake.sauce.red_chili") and is_equal_approx(float(unit.pancake_model.total_sauce()), saved_sauce_total), "primed sauce and recipe identifier survive snapshot restore")
	_check(not unit.pancake_surface.cursor_is_sauce_brush, "snapshot restore does not restore the temporary held brush")
	station.clear_held_tool()
	unit.reset_unit()
	var before_wrong_stage := int(session.inventory["stock.pancake.sauce.red_chili"])
	var wrong_stage := Dictionary(station.select_worktop_tool(&"stock.pancake.sauce.red_chili"))
	_check(not bool(wrong_stage.get("success", false)) and int(session.inventory["stock.pancake.sauce.red_chili"]) == before_wrong_stage, "wrong-stage sauce click does not consume inventory")


func _test_worktop_hotspot_mapping(station: Node, unit: Node, session: FakeSession) -> void:
	_check(HOTSPOTS_SCRIPT.SAUCE_HOTSPOT_IDS.size() == 3, "all three sauce jars have worktop hotspot mappings")
	_check(HOTSPOTS_SCRIPT.SAUCE_HOTSPOT_IDS.get(&"TomatoSauceHotspot", &"") == &"stock.pancake.sauce.tomato", "tomato sauce mapping targets the tomato stock")
	var artwork := ARTWORK_SCENE.instantiate()
	root.add_child(artwork)
	await process_frame
	var artwork_hotspots := artwork.get_node("PancakeWorktopHotspots")
	var sweet_hit := artwork_hotspots.get_node("SweetSauceHotspotHitButton") as Button
	var chili_hit := artwork_hotspots.get_node("ChiliSauceHotspotHitButton") as Button
	var tomato_hit := artwork_hotspots.get_node("TomatoSauceHotspotHitButton") as Button
	_check(sweet_hit != null and chili_hit != null and tomato_hit != null, "every visible sauce jar has a native button hit target")
	if sweet_hit != null and chili_hit != null and tomato_hit != null:
		_check(is_equal_approx(sweet_hit.size.x, 123.0) and is_equal_approx(chili_hit.size.x, 117.0) and is_equal_approx(tomato_hit.size.x, 117.0), "sauce hit controls retain their matching artwork bounds")
		_check(sweet_hit.has_point(Vector2(1.0, sweet_hit.size.y * 0.5)) and sweet_hit.has_point(sweet_hit.size * 0.5) and sweet_hit.has_point(Vector2(sweet_hit.size.x * 0.5, sweet_hit.size.y - 1.0)), "sweet-sauce hit target covers the entire visible dish and jar area")
		_check(not chili_hit.has_point(Vector2(0.0, chili_hit.size.y * 0.5)) and chili_hit.has_point(chili_hit.size * 0.5), "chili-sauce hit test excludes transparent margins but accepts visible artwork")
		_check(not tomato_hit.has_point(Vector2(0.0, tomato_hit.size.y * 0.5)) and tomato_hit.has_point(tomato_hit.size * 0.5), "tomato-sauce hit test excludes transparent margins but accepts visible artwork")
	artwork.queue_free()
	var hotspots := HOTSPOTS_SCRIPT.new()
	hotspots.griddle_station_path = NodePath("../MultiGriddleStation")
	hotspots.size = Vector2(320.0, 240.0)
	for component_name in [&"ScallionTray", &"CorianderTray", &"BaocuiBasket", &"EggCarton"]:
		var component := Control.new()
		component.name = component_name
		hotspots.add_child(component)
		var source := DRAG_SOURCE_SCRIPT.new()
		source.name = &"Hotspot"
		component.add_child(source)
	for hotspot_name in [&"SweetSauceHotspot", &"ChiliSauceHotspot", &"TomatoSauceHotspot"]:
		var sauce_source := DRAG_SOURCE_SCRIPT.new()
		sauce_source.name = hotspot_name
		hotspots.add_child(sauce_source)
		var sauce_hit_button := Button.new()
		sauce_hit_button.name = &"%sHitButton" % hotspot_name
		hotspots.add_child(sauce_hit_button)
	var pork_floss := DRAG_SOURCE_SCRIPT.new()
	pork_floss.name = &"PorkFlossHotspot"
	hotspots.add_child(pork_floss)
	var spreader := TextureButton.new()
	spreader.name = &"SpreaderHotspot"
	spreader.position = Vector2(40.0, 40.0)
	spreader.size = Vector2(160.0, 160.0)
	hotspots.add_child(spreader)
	var batter_ladle := TextureButton.new()
	batter_ladle.name = &"BatterLadleHolderHotspot"
	batter_ladle.position = Vector2(200.0, 40.0)
	batter_ladle.size = Vector2(80.0, 160.0)
	hotspots.add_child(batter_ladle)
	var spreader_holder_empty := TextureRect.new()
	spreader_holder_empty.name = &"SpreaderHolderEmptyVisual"
	hotspots.add_child(spreader_holder_empty)
	var spreader_holder_filled := TextureRect.new()
	spreader_holder_filled.name = &"SpreaderHolderFilledVisual"
	hotspots.add_child(spreader_holder_filled)
	root.add_child(hotspots)
	await process_frame
	_check(spreader.texture_normal != null, "spreader position has a texture-backed hit surface")
	var spreader_hit_button := hotspots.get_node_or_null("SpreaderHotspotHitButton") as Button
	_check(spreader_hit_button != null, "spreader position has a native button hit target")
	session.progression.locked[&"stock.pancake.sauce.red_chili"] = true
	hotspots.bind_session(session)
	_check(StringName(hotspots.get_node("ScallionTray/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.scallion", "left worktop bowl maps to scallion stock")
	_check(StringName(hotspots.get_node("CorianderTray/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.coriander", "coriander tray maps to coriander stock")
	_check(StringName(hotspots.get_node("BaocuiBasket/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.baocui", "middle worktop basket maps to baocui stock")
	_check(StringName(hotspots.get_node("EggCarton/Hotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.egg", "right worktop basket maps to egg stock")
	_check(StringName(hotspots.get_node("PorkFlossHotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.meat_floss", "pork-floss tray maps to meat-floss stock")
	_check(not bool(hotspots.get_node("ScallionTray/Hotspot").disabled), "owned scallion stock is enabled for drag and hold input")
	_check(not bool(hotspots.get_node("CorianderTray/Hotspot").disabled), "owned coriander stock is enabled for drag and hold input")
	_check(not bool(hotspots.get_node("PorkFlossHotspot").disabled), "owned pork-floss tray is enabled for drag and hold input")
	_check(bool(hotspots.get_node("ScallionTray/Hotspot").native_drag_enabled), "ingredient bowls use drag placement")
	_check(bool(hotspots.get_node("CorianderTray/Hotspot").native_drag_enabled), "coriander tray uses drag placement")
	_check(not bool(hotspots.get_node("SweetSauceHotspot").native_drag_enabled), "sauce jars select direct brushing instead of drag placement")
	_check(StringName(hotspots.get_node("TomatoSauceHotspot").source_ref().get("stock_id", &"")) == &"stock.pancake.sauce.tomato", "tomato sauce jar maps to tomato sauce stock")
	_check(not bool(hotspots.get_node("TomatoSauceHotspot").disabled), "owned tomato sauce hotspot is enabled for direct brushing")
	_check(not bool(hotspots.get_node("TomatoSauceHotspotHitButton").disabled), "owned tomato sauce button is enabled for pointer input")
	_check(bool(hotspots.get_node("ChiliSauceHotspot").disabled), "locked chili sauce hotspot cannot be used")
	_check(batter_ladle.tooltip_text == "按住面糊勺拖到空鏊子倒入", "basic batter ladle explains the hold-and-drag interaction")
	hotspots.call("_on_batter_ladle_button_down")
	_check(bool(station.call("is_batter_ladle_selected")) and unit.state == CompactGriddleUnit.State.IDLE, "basic batter ladle click picks up the tool without immediately pouring")
	_check(unit.pancake_surface.batter_pour_guide_visible and unit.pancake_surface.batter_pour_guide_outer_radius_pixels > unit.pancake_surface.batter_pour_guide_inner_radius_pixels, "basic batter ladle shows two rings for the recommended batter area")
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
	_check(batter_ladle.texture_normal == HOTSPOTS_SCRIPT.BATTER_LADLE_HOLDER_FILLED, "released ladle restores the filled holder artwork")
	unit.reset_unit()
	session.progression.owned_growth[&"growth.automation.pancake.auto_batter_ladle"] = true
	hotspots.refresh_from_session()
	_check(batter_ladle.tooltip_text == "点击加标准分量面糊", "upgraded batter ladle explains one-click standard filling")
	hotspots.call("_on_batter_ladle_pressed")
	var automatic_batter_thickness := float(unit.pancake_model.calculate_summary().get("mean_thickness", 0.0))
	_check(unit.state == CompactGriddleUnit.State.BATTER and automatic_batter_thickness > held_batter_thickness, "upgraded batter ladle immediately adds the standard amount")
	unit.reset_unit()
	var scallion := hotspots.get_node("ScallionTray/Hotspot") as ProductDragSource
	scallion.begin_gesture(Vector2.ZERO)
	scallion.advance_gesture(0.20)
	_check(scallion.is_hold_active(), "holding owned scallion stock enters the restock gesture")
	scallion.advance_gesture(0.20)
	_check(float(session.restock_hold_seconds.get(&"stock.pancake.scallion", 0.0)) > 0.0, "holding scallion stock advances the restock service")
	scallion.end_gesture()
	var pork_floss_source := hotspots.get_node("PorkFlossHotspot") as ProductDragSource
	pork_floss_source.begin_gesture(Vector2.ZERO)
	pork_floss_source.advance_gesture(0.20)
	_check(pork_floss_source.is_hold_active(), "holding pork-floss tray enters the restock gesture")
	pork_floss_source.advance_gesture(0.20)
	_check(float(session.restock_hold_seconds.get(&"stock.pancake.meat_floss", 0.0)) > 0.0, "holding pork-floss tray advances the restock service")
	pork_floss_source.end_gesture()
	session.progression.locked.erase(&"stock.pancake.sauce.red_chili")
	hotspots.refresh_from_session()
	_check(not bool(hotspots.get_node("ChiliSauceHotspot").disabled), "unlocked chili sauce hotspot becomes usable")
	hotspots.set_workshop_preview(true)
	_check(hotspots.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "workshop preview disables all worktop interaction")
	_check(bool(hotspots.get_node("ScallionTray/Hotspot").disabled), "workshop preview disables unlocked ingredient interaction")
	_check(bool(hotspots.get_node("ChiliSauceHotspot").disabled), "workshop preview disables unlocked sauce interaction")
	_check(spreader_holder_filled.texture.resource_path.ends_with("batter_spreader_holder_wide_filled_v1.png"), "workshop preview shows the wide spreader upgrade target")
	_check(is_equal_approx(spreader_holder_filled.modulate.a, 0.42), "locked wide spreader target is translucent in workshop preview")
	session.progression.owned_growth[&"growth.tool.pancake.wide_spreader"] = true
	hotspots.refresh_from_session()
	_check(not spreader_holder_filled.visible, "owned wide spreader is hidden in workshop so the press preview can replace it")
	hotspots.set_workshop_preview(false)
	_check(hotspots.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED, "closing workshop preview restores worktop input behavior")
	_check(not bool(hotspots.get_node("ScallionTray/Hotspot").disabled), "closing workshop preview restores owned ingredient interaction")
	_check(not bool(hotspots.get_node("ChiliSauceHotspot").disabled), "closing workshop preview restores owned sauce interaction")
	_check(spreader_holder_filled.visible, "closing workshop preview restores the runtime spreader holder")
	_check(spreader_holder_filled.texture.resource_path.ends_with("batter_spreader_holder_wide_filled_v1.png"), "closing workshop preview restores the owned wide spreader artwork")
	session.progression.owned_growth[&"growth.automation.pancake.press_once"] = true
	hotspots.refresh_from_session()
	_check(spreader_holder_filled.visible, "owned press replaces the wide spreader in the normal worktop")
	_check(spreader_holder_filled.texture.resource_path.ends_with("pancake-press-wide-upgrade-v1.png"), "owned press uses the wide spreader holder position")
	station.select_worktop_tool(&"tool.pancake.spreader")
	hotspots.refresh_from_session()
	_check(spreader_holder_filled.visible, "held spreader state does not hide the installed press")
	unit.reset_unit()
	var batter_started := Dictionary(station.take_batter_from_ladle())
	var press_position := spreader_hit_button.get_global_rect().get_center()
	var press_down := InputEventMouseButton.new()
	press_down.button_index = MOUSE_BUTTON_LEFT
	press_down.pressed = true
	press_down.position = press_position
	press_down.global_position = press_position
	Input.parse_input_event(press_down)
	await process_frame
	var press_up := InputEventMouseButton.new()
	press_up.button_index = MOUSE_BUTTON_LEFT
	press_up.pressed = false
	press_up.position = press_position
	press_up.global_position = press_position
	Input.parse_input_event(press_up)
	await process_frame
	_check(bool(batter_started.get("success", false)) and unit.state == CompactGriddleUnit.State.FIRST_SIDE, "press position activates the one-click press after batter is added")
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	var tomato_hit_button := hotspots.get_node("TomatoSauceHotspotHitButton") as Button
	tomato_hit_button.emit_signal(&"button_down")
	tomato_hit_button.emit_signal(&"button_up")
	_check(unit.applied_sauce_ids.has("stock.pancake.sauce.tomato"), "tomato sauce button pointer signals route to direct brushing")
	station.clear_held_tool()
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	var sweet := hotspots.get_node("SweetSauceHotspot") as ProductDragSource
	sweet.begin_gesture(Vector2.ZERO)
	sweet.end_gesture()
	var brush_start := Dictionary(station.begin_surface_action(0, unit.pancake_surface.size * 0.5))
	_check(bool(brush_start.get("success", false)) and StringName(brush_start.get("action", &"")) == CompactGriddleUnit.SURFACE_ACTION_BRUSH_SAUCE, "sweet sauce hotspot short click routes to direct brushing")
	hotspots.queue_free()


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
