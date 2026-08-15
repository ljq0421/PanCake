extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")
const COMPACT_GRIDDLE_SCENE := preload("res://scenes/gameplay/compact_griddle_unit.tscn")

class FakeProgression:
	extends RefCounted
	var stock_capacity := 6
	var wide_spreader := false

	func owns_stock(_stock_id: StringName) -> bool:
		return true

	func owns_growth(growth_id: StringName) -> bool:
		return growth_id == &"growth.tool.pancake.wide_spreader" and wide_spreader


class FakeSession:
	extends Node
	var progression := FakeProgression.new()
	var youtiao_count := 1
	var inventory := {
		"stock.pancake.batter": 3,
		"stock.pancake.egg": 3,
		"stock.pancake.baocui": 3,
		"stock.pancake.scallion": 3,
		"stock.pancake.sauce.sweet_flour": 3,
		"stock.pancake.sauce.red_chili": 3,
	}

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array) -> Dictionary:
		for value in stock_ids:
			var key := str(value)
			if int(inventory.get(key, 0)) <= 0:
				return {"success": false, "reason": &"insufficient_stock", "stock_id": StringName(value)}
		for value in stock_ids:
			var key := str(value)
			inventory[key] = int(inventory.get(key, 0)) - 1
		return {"success": true}

	func preview_take_prepared_product(_slot_id: StringName) -> Dictionary:
		return {"success": youtiao_count > 0, "reason": &"" if youtiao_count > 0 else &"empty"}

	func take_prepared_product(_slot_id: StringName) -> Dictionary:
		if youtiao_count <= 0:
			return {"success": false, "reason": &"empty"}
		youtiao_count -= 1
		return {"success": true}


var failures := PackedStringArray()
var target_order := {
	"product_id": &"product.pancake.custom",
	"heat_preference": &"golden",
	"ingredient_ids": PackedStringArray(["stock.pancake.egg", "stock.pancake.baocui"]),
	"sauce_ids": PackedStringArray(["stock.pancake.sauce.sweet_flour"]),
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := FakeSession.new()
	root.add_child(session)
	var station := STATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	_check(station.get_node_or_null("Background") == null, "multi-griddle station has no redundant outer background frame")
	station.bind_session(session)
	station.set_griddle_count(1)
	_check(is_equal_approx(station.units[0].position.x, 405.0), "logical slot 0 is displayed as the center main griddle")
	_check(is_equal_approx(station.units[1].position.x, 96.0), "logical slot 1 is displayed as the left griddle")
	_check(is_equal_approx(station.units[2].position.x, 714.0), "logical slot 2 is displayed as the right griddle")
	var locked_batter_before := int(session.inventory["stock.pancake.batter"])
	station.call("_on_main_action", 1)
	_check(int(session.inventory["stock.pancake.batter"]) == locked_batter_before, "clicking a locked griddle does not consume batter")
	station.set_griddle_count(3)
	_check(station.griddle_count() == 3, "advanced station exposes three griddles")
	var visual_unit: Node = station.units[0]
	var visual_surface: Control = visual_unit.pancake_surface
	var visual_material := visual_unit.pancake_visual.material as ShaderMaterial
	_check(visual_unit.get_node_or_null("Frame") == null, "compact griddle renders without a rectangular panel frame")
	_check(visual_unit.griddle_art.position.is_equal_approx(Vector2(-22.8, 11.4)) and visual_unit.griddle_art.size.is_equal_approx(Vector2(405.6, 213.2)), "griddle artwork is exactly 1.3x the former 312x164 display while preserving its center")
	_check(visual_surface.position.is_equal_approx(Vector2(40.9, -24.1)) and visual_surface.size.is_equal_approx(Vector2(278.2, 278.2)), "compact pancake surface is exactly 1.3x the former 214x214 coordinate space while preserving its center")
	_check(not visual_surface.draw_pointer_trace and not visual_surface.draw_pan_outline and visual_surface.elliptical_hit_test and not visual_surface.draw_spreader_fallback and not visual_surface.draw_sauce_brush_fallback, "compact surface hides the white pointer trace, disables legacy drawn tools, and uses elliptical hit testing without the brown outline")
	_check(visual_material != null and visual_material.shader.resource_path == "res://resources/shaders/pancake_surface.gdshader", "compact pancake visual uses the production material shader")
	_check(visual_unit.get_node_or_null("SauceAction") == null and visual_unit.get_node_or_null("IngredientAction") == null and visual_unit.get_node_or_null("FoldAction") == null and visual_unit.get_node_or_null("DiscardAction") == null, "compact griddles physically retain only the batter/flip action button")
	_check(visual_unit.get_node_or_null("PancakeSurface/PancakeFoldOverlay") != null, "compact griddles author the manual fold preview in the scene")
	_check(not visual_surface._has_point(Vector2.ZERO) and visual_surface._has_point(visual_surface.size * 0.5), "compact surface rejects rectangular corner input while accepting the real pan center")
	_check(visual_unit.spreader_artwork.get_index() > visual_unit.ingredient_layer.get_index() and visual_unit.sauce_brush_artwork.get_index() > visual_unit.ingredient_layer.get_index(), "real compact tools render above batter and ingredients")
	_check(visual_unit.get_node_or_null("PancakeSurface/EggCrackArtwork") == null, "compact griddles do not retain a static eggshell after the crack feedback")
	_check(visual_unit.egg_intact_visual != null and visual_unit.egg_intact_visual.texture.resource_path == "res://resources/art/ingredients/egg/egg_intact_raw_v1_five_area_v2.png", "compact griddles author the shell-free intact egg visual in the scene")
	_check(is_equal_approx(float(visual_unit.ingredient_layer.scallion_scale), 0.18), "compact griddles use the scene-local enlarged scallion scale")
	var worktop: Control = station.shared_tool_tray
	_check(worktop.get_node_or_null("Background") == null and worktop.get_node_or_null("PhysicalToolRow") == null, "pancake materials use transparent authored worktop slots without a second tray row")
	var expected_stock_ids := PackedStringArray([
		"stock.pancake.batter", "", "stock.pancake.egg", "stock.pancake.baocui",
		"stock.pancake.scallion", "stock.pancake.ham_sausage", "stock.pancake.meat_floss", "stock.pancake.coriander",
		"stock.pancake.preserved_mustard", "stock.pancake.pork_tenderloin", "stock.pancake.sauce.sweet_flour", "stock.pancake.sauce.red_chili",
	])
	for slot_offset in 12:
		var slot_name := "WorktopSlot%02d" % (slot_offset + 4)
		var host := worktop.get_node(slot_name) as Control
		_check(host.size == Vector2(89.0, 89.0) and host.get_child_count() == 1, "%s is one exact physical 89x89 worktop slot" % slot_name)
		if slot_offset == 1:
			_check(host.get_child(0).name == "SpreaderButton", "worktop slot 05 owns the spreader")
		else:
			_check(str((host.get_child(0) as FiveAreaMaterialSlot).stock_id) == expected_stock_ids[slot_offset], "%s owns the intended pancake stock" % slot_name)
	var baocui_slot := worktop.get_node("WorktopSlot07/BaocuiSlot") as FiveAreaMaterialSlot
	_check(baocui_slot.material_texture.resource_path == "res://resources/art/ingredients/baocui/baocui_intact_v1.png", "the worktop baocui slot uses the real crispy-cracker artwork instead of the bun image")
	_check(visual_unit.ingredient_layer.baocui_texture.resource_path == "res://resources/art/ingredients/baocui/baocui_broken_v1.png", "the pancake topping layer uses the real broken baocui artwork")
	for unit_index in 3:
		station.call("_on_main_action", unit_index)
	_check(int(session.inventory["stock.pancake.batter"]) == 0, "starting three griddles immediately consumes three portions of batter")
	_check(Array(station.units[0].order.get("ingredient_ids", [])).is_empty() and Array(station.units[0].order.get("sauce_ids", [])).is_empty(), "starting a griddle without customers uses an order-independent production context")
	var spreader_button := station.shared_tool_tray.get_node("WorktopSlot05/SpreaderButton") as TextureButton
	_check(StringName(station.get("_selected_tool")) == &"tool.pancake.spreader" and spreader_button.button_pressed, "adding batter automatically holds and highlights the shared spreader")
	for unit_index in 3:
		var started_unit: Node = station.units[unit_index]
		started_unit.pancake_surface.force_texture_upload()
		var renderer_diagnostics := Dictionary(started_unit.pancake_surface.get_renderer_diagnostics())
		_check(started_unit.pancake_model.covered_cell_count() > 0, "griddle %d receives a centered batter deposit immediately after stock is consumed" % (unit_index + 1))
		_check(started_unit.pancake_surface.visible and int(renderer_diagnostics.get("upload_count", 0)) > 0, "griddle %d uploads the initial batter texture in the first visible frame" % (unit_index + 1))
		_check(_visible_coverage_pixels(renderer_diagnostics.get("field_image")) > 0, "griddle %d initial batter field contains visible coverage pixels" % (unit_index + 1))
		_check(is_equal_approx(float(renderer_diagnostics.get("update_hz", 0.0)), 30.0), "griddle %d refreshes dirty batter fields at 30 Hz" % (unit_index + 1))
	var left_unit: Control = station.units[1]
	var center_unit: Control = station.units[0]
	var right_unit: Control = station.units[2]
	var left_art_rect := Rect2(left_unit.position + left_unit.griddle_art.position, left_unit.griddle_art.size)
	var center_art_rect := Rect2(center_unit.position + center_unit.griddle_art.position, center_unit.griddle_art.size)
	var right_art_rect := Rect2(right_unit.position + right_unit.griddle_art.position, right_unit.griddle_art.size)
	_check(left_art_rect.intersects(center_art_rect) and center_art_rect.intersects(right_art_rect), "left-center-right griddle artwork visually closes the gaps")
	_check(not left_unit.pancake_surface.get_global_rect().intersects(center_unit.pancake_surface.get_global_rect()) and not center_unit.pancake_surface.get_global_rect().intersects(right_unit.pancake_surface.get_global_rect()), "three pancake surfaces keep independent non-overlapping pointer regions")
	var zero_coverage_snapshot: Dictionary = visual_unit.snapshot()
	var zero_model := Dictionary(zero_coverage_snapshot.get("pancake_model", {}))
	for field_name in ["coverage", "thickness", "wetness", "doneness", "back_doneness", "damage", "scrape_stress", "sauce_concentration", "chili_sauce_concentration", "egg_white", "egg_yolk", "egg_doneness"]:
		var empty_field := PackedFloat32Array()
		empty_field.resize(64 * 64)
		zero_model[field_name] = empty_field
	zero_coverage_snapshot["pancake_model"] = zero_model
	var migrated_unit := COMPACT_GRIDDLE_SCENE.instantiate()
	root.add_child(migrated_unit)
	await process_frame
	_check(bool(Dictionary(migrated_unit.load_snapshot(zero_coverage_snapshot)).get("success", false)), "legacy BATTER snapshot with zero coverage still loads")
	_check(migrated_unit.pancake_model.covered_cell_count() > 0, "legacy BATTER snapshot with zero coverage rebuilds the centered batter deposit")
	migrated_unit.pancake_surface.force_texture_upload()
	_check(_visible_coverage_pixels(Dictionary(migrated_unit.pancake_surface.get_renderer_diagnostics()).get("field_image")) > 0, "migrated zero-coverage snapshot uploads visible batter pixels")
	migrated_unit.queue_free()
	var bounded_sweep_unit := COMPACT_GRIDDLE_SCENE.instantiate()
	root.add_child(bounded_sweep_unit)
	await process_frame
	bounded_sweep_unit.begin_order(_order())
	var bounded_center := Vector2.ONE * (float(bounded_sweep_unit.pancake_model.grid_size) - 1.0) * 0.5
	var bounded_mass_before: float = bounded_sweep_unit.pancake_model.total_thickness()
	bounded_sweep_unit.call("_apply_radial_batter_sweep", bounded_center + Vector2(8.0, 0.0), Vector2.RIGHT, 70.0)
	var bounded_mass_after: float = bounded_sweep_unit.pancake_model.total_thickness()
	_check(absf(bounded_mass_after - bounded_mass_before) / maxf(bounded_mass_before, 0.001) < 0.001, "a compact radial sweep conserves batter mass while its push fan remains inside the pan")
	bounded_sweep_unit.queue_free()
	var spread_before: int = visual_unit.pancake_model.covered_cell_count()
	var straight_core_before := _mean_thickness_in_radius(visual_unit.pancake_model, 6.0)
	station.call("clear_held_tool")
	visual_unit.call("_on_surface_pointer_started", visual_surface.size * 0.5)
	_check(visual_unit.pancake_model.covered_cell_count() == spread_before, "the first spreader press does not add a duplicate batter portion")
	_check(StringName(station.get("_selected_tool")) == &"tool.pancake.spreader" and spreader_button.button_pressed and StringName(visual_unit.get("_surface_action")) == CompactGriddleUnit.SURFACE_ACTION_SPREAD_BATTER, "pressing a batter-stage griddle contextually equips and highlights the shared spreader")
	_check(visual_unit.spreader_artwork.visible and visual_unit.spreader_artwork.texture.resource_path == "res://resources/art/workstation/tools/batter_spreader_v1_five_area_v2.png", "contextually equipped basic spreader artwork appears at the compact pan contact point")
	var spread_target := visual_surface.size * 0.5 + Vector2(86.0, 0.0)
	visual_surface.pointer_local_position = spread_target
	visual_unit.call("_update_surface_tool_artwork", spread_target, 0.05)
	visual_unit.call("_process_manual_spread", 0.05)
	_check(visual_unit.pancake_model.covered_cell_count() == spread_before and is_equal_approx(_mean_thickness_in_radius(visual_unit.pancake_model, 6.0), straight_core_before) and not visual_surface.spreader_motion_valid, "a straight outward drag changes neither coverage nor center thickness")
	visual_unit.call("_on_surface_pointer_ended", spread_target)
	_check(visual_unit.state == CompactGriddleUnit.State.FIRST_SIDE and not visual_unit.spreader_artwork.visible and StringName(station.get("_selected_tool")).is_empty(), "releasing the first stroke fixes the pancake shape, hides the tool, and clears the shared selection")
	visual_unit.call("_on_surface_pointer_started", visual_surface.size * 0.5)
	_check(StringName(station.get("_selected_tool")).is_empty() and StringName(visual_unit.get("_surface_action")).is_empty() and not visual_unit.spreader_artwork.visible, "a first-side pancake without egg does not contextually equip the spreader")
	station.call("clear_held_tool")

	var circular_unit: Node = station.units[2]
	var circular_surface: Control = circular_unit.pancake_surface
	var circular_before: int = circular_unit.pancake_model.covered_cell_count()
	var circular_center := circular_surface.size * 0.5
	var circular_start := circular_center + Vector2(20.0, 0.0)
	var core_thickness_by_turn := PackedFloat32Array([_mean_thickness_in_radius(circular_unit.pancake_model, 6.0)])
	circular_unit.call("_on_surface_pointer_started", circular_start)
	_check(StringName(station.get("_selected_tool")) == &"tool.pancake.spreader" and StringName(circular_unit.get("_surface_action")) == CompactGriddleUnit.SURFACE_ACTION_SPREAD_BATTER, "switching to another batter-stage griddle equips the spreader again without a tray click")
	var circular_point := circular_start
	for spread_step in 60:
		var progress := float(spread_step + 1) / 60.0
		var angle := progress * TAU * 3.2
		var radius := lerpf(20.0, 108.0, progress)
		circular_point = circular_center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.70)
		circular_surface.pointer_local_position = circular_point
		circular_unit.call("_update_surface_tool_artwork", circular_point, 1.0 / 30.0)
		circular_unit.call("_process_manual_spread", 1.0 / 30.0)
		if spread_step in [18, 37, 56]:
			core_thickness_by_turn.append(_mean_thickness_in_radius(circular_unit.pancake_model, 6.0))
	_check(circular_unit.pancake_model.covered_cell_count() > circular_before and circular_surface.spreader_motion_valid, "one continuous outward circle expands the centered batter")
	_check(_strictly_decreasing(core_thickness_by_turn), "each completed outward circle progressively thins the center batter core")
	var final_core_thickness := _mean_thickness_in_radius(circular_unit.pancake_model, 6.0)
	var final_covered_thickness := _mean_covered_thickness(circular_unit.pancake_model)
	_check(final_core_thickness >= final_covered_thickness * 0.75 and final_core_thickness <= final_covered_thickness * 1.10, "the formed pancake center stays within 0.75x to 1.10x of the mean covered thickness")
	_check(_coverage_ratio_in_radius(circular_unit.pancake_model, 6.0) >= 0.95, "stronger center redistribution does not tear or uncover the pancake core")
	_check(absf(_mean_wetness_in_radius(circular_unit.pancake_model, 14.0) - _mean_covered_wetness(circular_unit.pancake_model)) <= 0.10, "the original batter deposit no longer remains as a visibly wetter center disc")
	for _settle_step in 12:
		circular_unit.call("_update_surface_tool_artwork", circular_point, 1.0 / 30.0)
	var final_radial := circular_point - circular_center
	var expected_rotation := Vector2(final_radial.x, final_radial.y / circular_unit.pancake_model.parameters.pan_height_ratio).angle() + CompactGriddleUnit.SPREADER_ART_ROTATION_OFFSET
	_check(absf(wrapf(circular_unit.spreader_artwork.rotation - expected_rotation, -PI, PI)) < 0.45, "the authored spreader rotates smoothly toward the pan radial instead of following straight-line motion")
	circular_unit.call("_on_surface_pointer_ended", circular_point)
	_check(circular_unit.state == CompactGriddleUnit.State.FIRST_SIDE, "the accepted circular stroke enters first-side cooking on release")

	session.progression.wide_spreader = true
	var wide_unit: Node = station.units[1]
	var wide_surface: Control = wide_unit.pancake_surface
	wide_unit.call("_on_surface_pointer_started", wide_surface.size * 0.5 + Vector2(20.0, 0.0))
	_check(StringName(station.get("_selected_tool")) == &"tool.pancake.spreader" and wide_unit.spreader_artwork.texture.resource_path == "res://resources/art/workstation/tools/batter_spreader_upgrade_v1_five_area_v2.png", "contextual equip preserves the wide-spreader upgrade artwork on another griddle")
	wide_unit.call("_on_surface_pointer_ended", wide_surface.size * 0.5 + Vector2(20.0, 0.0))
	session.progression.wide_spreader = false
	for unit_index in 3:
		var unit: Node = station.units[unit_index]
		unit.pancake_model.add_batter(Vector2(31.5, 31.5), 1.2, 27.0)
		unit.p1_session.confirm_spread(unit.pancake_model)
		unit.state = 2
		unit.first_side_seconds = 2.5
		unit.pancake_model.advance_cooking(2.5, unit.p1_session.heat_level)
	var unit_one: Node = station.units[1]
	var egg_source := {"source_kind": &"pancake_shared_ingredient", "stock_id": &"stock.pancake.egg"}
	var baocui_source := {"source_kind": &"pancake_shared_ingredient", "stock_id": &"stock.pancake.baocui"}
	var center_local: Vector2 = unit_one.pancake_surface.size * 0.5
	var baocui_before_invalid := int(session.inventory["stock.pancake.baocui"])
	_check(station.can_drop_on_unit(1, baocui_source, center_local), "garnish can be dropped during the first-side stage without forcing a flip")
	_check(int(session.inventory["stock.pancake.baocui"]) == baocui_before_invalid, "first-side drop validation does not consume stock before placement")
	var egg_drop := Dictionary(station.drop_on_unit(1, egg_source, center_local))
	_check(bool(egg_drop.get("success", false)) and unit_one.ingredient_model.has_type(IngredientModel.EGG), "egg drop changes only the actual target griddle")
	_check(unit_one.egg_crack_effect.visible, "a successful egg drop immediately starts the authored two-frame crack effect on its target griddle")
	_check(is_equal_approx(unit_one.egg_crack_effect.position.x, center_local.x) and unit_one.egg_crack_effect.position.y < center_local.y and not unit_one.egg_intact_visual.visible, "the crack feedback begins directly above the player's real drop point before revealing the intact egg")
	_check(StringName(station.get("_selected_tool")) == &"tool.pancake.spreader" and spreader_button.button_pressed, "placing an egg automatically restores and highlights the shared spreader")
	_check(not station.units[0].egg_crack_effect.visible and not station.units[2].egg_crack_effect.visible, "the egg effect remains isolated to the actual target griddle")
	var egg_after_first_drop := int(session.inventory["stock.pancake.egg"])
	_check(not bool(Dictionary(station.drop_on_unit(1, egg_source, center_local)).get("success", false)), "duplicate ingredient drop is rejected")
	_check(int(session.inventory["stock.pancake.egg"]) == egg_after_first_drop, "duplicate ingredient rejection does not consume stock")
	var unit_zero: Node = station.units[0]
	var unit_zero_center: Vector2 = unit_zero.pancake_surface.size * 0.5
	_check(bool(Dictionary(station.drop_on_unit(0, egg_source, unit_zero_center)).get("success", false)), "a second griddle receives its own ordered egg before flipping")
	await create_timer(0.40).timeout
	unit_one.pancake_surface.force_texture_upload()
	_check(not unit_one.egg_crack_effect.visible and unit_one.egg_intact_visual.visible and unit_one.pancake_model.has_egg() and _visible_egg_pixels(Dictionary(unit_one.pancake_surface.get_renderer_diagnostics()).get("egg_image")) == 0, "the crack animation ends on the shell-free intact egg instead of the spread heatmap")
	_check(unit_one.egg_intact_visual.position.distance_to(center_local) <= 3.0, "the stable intact egg remains at the player's real drop point")
	var restored_egg_unit := COMPACT_GRIDDLE_SCENE.instantiate()
	root.add_child(restored_egg_unit)
	await process_frame
	_check(bool(Dictionary(restored_egg_unit.load_snapshot(unit_one.snapshot())).get("success", false)), "a compact griddle snapshot with an unspread egg restores")
	restored_egg_unit.pancake_surface.force_texture_upload()
	_check(restored_egg_unit.get_node_or_null("PancakeSurface/EggCrackArtwork") == null and not restored_egg_unit.egg_crack_effect.visible and restored_egg_unit.egg_intact_visual.visible and restored_egg_unit.pancake_model.has_egg() and _visible_egg_pixels(Dictionary(restored_egg_unit.pancake_surface.get_renderer_diagnostics()).get("egg_image")) == 0, "snapshot restore reconstructs the intact egg from model state without restoring an eggshell")
	var restored_model_egg_center: Vector2 = restored_egg_unit.pancake_model.egg_visual_center()
	var restored_expected_local: Vector2 = (restored_model_egg_center + Vector2(0.5, 0.5)) / float(restored_egg_unit.pancake_model.grid_size) * restored_egg_unit.pancake_surface.size
	_check(restored_egg_unit.egg_intact_visual.position.distance_to(restored_expected_local) <= 0.01, "snapshot restore derives the intact egg position from the saved model's egg center")
	restored_egg_unit.queue_free()
	station.call("clear_held_tool")
	unit_one.call("_on_surface_pointer_started", center_local)
	_check(StringName(station.get("_selected_tool")) == &"tool.pancake.spreader" and spreader_button.button_pressed and StringName(unit_one.get("_surface_action")) == CompactGriddleUnit.SURFACE_ACTION_SPREAD_EGG, "pressing a first-side griddle with egg contextually equips the spreader without a tray click")
	unit_one.pancake_surface.pointer_local_position = center_local + Vector2(22.0, 0.0)
	unit_one.call("_update_surface_tool_artwork", center_local + Vector2(22.0, 0.0), 0.1)
	unit_one.call("_process_egg_spread", 0.1)
	unit_one.call("_on_surface_pointer_ended", center_local + Vector2(22.0, 0.0))
	unit_one.pancake_surface.force_texture_upload()
	_check(unit_one.pancake_model.calculate_egg_spread_summary().get("coverage_ratio", 0.0) > 0.0, "shared spreader routes egg spreading to the selected griddle")
	_check(not unit_one.egg_crack_effect.visible and not unit_one.egg_intact_visual.visible and _visible_egg_pixels(Dictionary(unit_one.pancake_surface.get_renderer_diagnostics()).get("egg_image")) > 0, "the first effective spread replaces the intact egg with model-driven egg liquid")
	unit_zero.call("_on_surface_pointer_started", unit_zero_center)
	_check(StringName(station.get("_selected_tool")) == &"tool.pancake.spreader" and StringName(unit_zero.get("_surface_action")) == CompactGriddleUnit.SURFACE_ACTION_SPREAD_EGG, "switching to another egg-stage griddle contextually equips the spreader again")
	unit_zero.call("_on_surface_pointer_ended", unit_zero_center)
	var unit_two: Node = station.units[2]
	_check(not unit_two.pancake_model.has_egg(), "the third griddle intentionally has no egg before the free flip check")
	for unit_index in 3:
		var unit: Node = station.units[unit_index]
		station.call("_on_main_action", unit_index)
		unit.second_side_seconds = 2.6
		unit.pancake_model.advance_cooking(2.6, unit.p1_session.heat_level)
		unit.call("_refresh_ui")
		_check(unit.state == CompactGriddleUnit.State.SECOND_SIDE and not unit.main_action.visible, "after flipping, griddle %d keeps cooking without a confirm-heat button" % (unit_index + 1))
	_check(unit_two.state == CompactGriddleUnit.State.SECOND_SIDE, "a pancake without egg can still flip through the real three-griddle action path")
	station.call("_on_shared_tool_selected", &"tool.pancake.spreader")
	var unit_one_left_edge := Vector2(24.0, center_local.y)
	unit_one.call("_on_surface_pointer_started", unit_one_left_edge)
	unit_one.pancake_surface.pointer_local_position = Vector2(224.0, center_local.y)
	unit_one.call("_process", 0.016)
	unit_one.call("_on_surface_pointer_ended", Vector2(224.0, center_local.y))
	_check(unit_one.state == CompactGriddleUnit.State.FOLDING and StringName(station.get("_selected_tool")).is_empty(), "edge input overrides a residual spreader selection and starts folding without sauce or small toppings")
	var unit_one_right_edge := Vector2(unit_one.pancake_surface.size.x - 24.0, center_local.y)
	unit_one.call("_on_surface_pointer_started", unit_one_right_edge)
	unit_one.pancake_surface.pointer_local_position = Vector2(54.0, center_local.y)
	unit_one.call("_process", 0.016)
	unit_one.call("_on_surface_pointer_ended", Vector2(54.0, center_local.y))
	_check(unit_one.state == CompactGriddleUnit.State.READY and unit_one.applied_sauce_ids.is_empty() and not unit_one.applied_ingredient_ids.has("stock.pancake.baocui") and not unit_one.applied_ingredient_ids.has("stock.pancake.scallion"), "zero-sauce and zero-small-topping pancake can fold and bag directly")
	_check(station.consume_ready(1), "the optional-content fold fixture can be consumed without affecting the scored target pancake")
	var youtiao_source := {"source_kind": &"prepared_product_slot", "source_slot_id": &"slot.04", "product_id": &"product.youtiao.plain"}
	var scallion_source := {"source_kind": &"pancake_shared_ingredient", "stock_id": &"stock.pancake.scallion"}
	_check(bool(Dictionary(station.drop_on_unit(2, baocui_source, unit_two.pancake_surface.size * 0.5)).get("success", false)), "shared garnish tray routes a topping to its actual drop target")
	_check(unit_two.state == CompactGriddleUnit.State.GARNISH and is_equal_approx(unit_two.second_side_seconds, 2.6), "the first post-flip topping confirms second-side heat exactly once")
	_check(bool(Dictionary(station.drop_on_unit(2, scallion_source, unit_two.pancake_surface.size * 0.5 + Vector2(-18.0, 0.0))).get("success", false)), "shared garnish tray places scallion on the selected griddle")
	var scallion_sprite: Sprite2D
	for child in unit_two.ingredient_layer.get_children():
		var sprite := child as Sprite2D
		if sprite != null and StringName(sprite.get_meta(&"ingredient_type", &"")) == IngredientModel.SCALLION:
			scallion_sprite = sprite
			break
	_check(scallion_sprite != null and scallion_sprite.scale.is_equal_approx(Vector2(0.18, 0.18)) and scallion_sprite.texture.get_size().x * scallion_sprite.scale.x > 46.0, "compact scallion renders at the scene-local 0.18 scale without changing other topping scales")
	_check(bool(Dictionary(station.drop_on_unit(2, youtiao_source, unit_two.pancake_surface.size * 0.5 + Vector2(8.0, 0.0))).get("success", false)) and session.youtiao_count == 0, "stored youtiao is consumed one at a time only after a valid target drop")
	station.call("_on_shared_tool_selected", &"stock.pancake.sauce.red_chili")
	unit_two.call("_on_surface_pointer_started", unit_two.pancake_surface.size * 0.5)
	_check(unit_two.sauce_brush_artwork.visible and unit_two.sauce_brush_artwork.texture.resource_path == "res://resources/art/workstation/tools/sauce_brush_v1_five_area_v2.png", "real sauce-brush artwork appears for compact pan brushing")
	unit_two.call("_on_surface_pointer_ended", unit_two.pancake_surface.size * 0.5)
	_check(not unit_two.sauce_brush_artwork.visible, "sauce-brush artwork hides when brushing ends")
	_check(unit_two.applied_sauce_ids.has("stock.pancake.sauce.red_chili"), "selected chili brush paints the chosen griddle instead of auto-filling the order")
	_check(bool(Dictionary(station.drop_on_unit(0, baocui_source, unit_zero_center + Vector2(8.0, 0.0))).get("success", false)), "the ordered topping manually enters the target griddle and confirms its second side")
	station.call("_on_shared_tool_selected", &"stock.pancake.sauce.sweet_flour")
	unit_zero.call("_on_surface_pointer_started", unit_zero_center)
	unit_zero.call("_on_surface_pointer_ended", unit_zero_center + Vector2(16.0, 0.0))
	_check(unit_zero.applied_sauce_ids.has("stock.pancake.sauce.sweet_flour"), "the ordered sauce is brushed manually before folding")
	var left_edge := Vector2(24.0, unit_zero_center.y)
	var short_left_release := Vector2(58.0, unit_zero_center.y)
	unit_zero.call("_on_surface_pointer_started", left_edge)
	unit_zero.call("_on_surface_pointer_ended", short_left_release)
	_check(unit_zero.fold_model.completed_fold_count() == 0 and unit_zero.state == CompactGriddleUnit.State.FOLDING, "releasing before the fold line keeps both sides unfolded")
	unit_zero.call("_on_surface_pointer_started", left_edge)
	unit_zero.pancake_surface.pointer_local_position = Vector2(224.0, unit_zero_center.y)
	unit_zero.call("_process", 0.016)
	unit_zero.call("_on_surface_pointer_ended", Vector2(224.0, unit_zero_center.y))
	_check(unit_zero.fold_model.is_region_folded(PancakeFoldModel.REGION_LEFT) and unit_zero.state == CompactGriddleUnit.State.FOLDING, "dragging the left edge past its fold line commits only the left side")
	var right_edge := Vector2(unit_zero.pancake_surface.size.x - 24.0, unit_zero_center.y)
	unit_zero.call("_on_surface_pointer_started", right_edge)
	unit_zero.pancake_surface.pointer_local_position = Vector2(54.0, unit_zero_center.y)
	unit_zero.call("_process", 0.016)
	unit_zero.call("_on_surface_pointer_ended", Vector2(54.0, unit_zero_center.y))
	_check(unit_zero.fold_model.is_region_folded(PancakeFoldModel.REGION_RIGHT) and unit_zero.state == CompactGriddleUnit.State.READY, "dragging the other side completes two-sided folding and automatically bags the pancake")
	var ready_refs: Array = station.ready_source_refs()
	_check(ready_refs.size() == 1, "one independently completed griddle exposes one delivery source")
	var product := Dictionary(Dictionary(ready_refs[0]).get("product", {})) if not ready_refs.is_empty() else {}
	var wrong_product := Dictionary(station.call("_build_product", unit_two))
	var completed_summary: Dictionary = station.units[0].pancake_model.calculate_summary()
	var completed_heat := (float(completed_summary.get("mean_doneness", 0.0)) + float(completed_summary.get("mean_back_doneness", 0.0))) * 0.5
	var expected_heat: StringName = &"light" if completed_heat < 0.34 else (&"golden" if completed_heat < 0.62 else &"well_done")
	_check(StringName(product.get("heat_preference", &"")) == expected_heat, "ready product preserves the heat calculated from both cooked surfaces")
	_check(PackedStringArray(product.get("ingredient_ids", [])) == target_order.ingredient_ids, "product carries exactly the manually added ingredients")
	_check(PackedStringArray(product.get("sauce_ids", [])) == target_order.sauce_ids, "product carries exactly the manually added sauce")
	_check(not Dictionary(product.get("serving_score_basis", {})).is_empty() and Dictionary(product.get("dimension_scores", {})).size() == 4, "ready product stores intrinsic craft dimensions and defers order scoring until delivery")
	_check(not Dictionary(wrong_product.get("serving_score_basis", {})).is_empty(), "every independently produced pancake retains delivery scoring evidence")
	_check(int(session.inventory["stock.pancake.egg"]) == 1 and int(session.inventory["stock.pancake.baocui"]) == 1, "valid physical and shortcut placements each consume stock exactly once")
	var persisted: Dictionary = station.snapshot()
	_check(int(persisted.get("product_sequence", 0)) == 3 and Array(persisted.get("slots", [])).size() == 3, "three-griddle snapshot preserves the product sequence and all independent surfaces")
	var restored := STATION_SCENE.instantiate()
	root.add_child(restored)
	await process_frame
	restored.bind_session(session)
	_check(bool(Dictionary(restored.load_snapshot(persisted)).get("success", false)), "v1 three-slot snapshot restores without migration")
	_check(restored.units[0].unit_index == 0 and restored.units[0].position.x == 405.0 and restored.units[1].unit_index == 1 and restored.units[1].position.x == 96.0, "restored v1 slots keep source indices while using center-left-right display mapping")
	var restored_unit_zero_state: int = restored.units[0].state
	var restored_unit_two_state: int = restored.units[2].state
	restored.set("_active_index", 2)
	var reset_result := Dictionary(restored.reset_active())
	_check(bool(reset_result.get("success", false)) and restored.units[2].state == CompactGriddleUnit.State.IDLE, "R-target reset clears the most recently operated griddle")
	_check(restored.units[0].state == restored_unit_zero_state and restored.units[1].state == CompactGriddleUnit.State.IDLE, "active-griddle reset leaves both other griddles untouched")
	restored.queue_free()
	var no_flip_session := FakeSession.new()
	root.add_child(no_flip_session)
	var no_flip_station := STATION_SCENE.instantiate()
	root.add_child(no_flip_station)
	await process_frame
	no_flip_station.bind_session(no_flip_session)
	no_flip_station.call("_on_main_action", 0)
	var no_flip_unit: Node = no_flip_station.units[0]
	no_flip_unit.pancake_model.add_batter(Vector2(31.5, 31.5), 1.2, 27.0)
	no_flip_unit.p1_session.confirm_spread(no_flip_unit.pancake_model)
	no_flip_unit.state = CompactGriddleUnit.State.FIRST_SIDE
	var no_flip_center: Vector2 = no_flip_unit.pancake_surface.size * 0.5
	var no_flip_topping := Dictionary(no_flip_station.drop_on_unit(0, baocui_source, no_flip_center))
	_check(
		bool(no_flip_topping.get("success", false))
		and no_flip_unit.state == CompactGriddleUnit.State.GARNISH
		and no_flip_unit.p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS
		and not no_flip_unit.pancake_model.is_flipped,
		"a first-side topping enters the real no-flip garnish route without turning the pancake"
	)
	_check(
		not bool(Dictionary(no_flip_station.drop_on_unit(0, egg_source, no_flip_center)).get("success", false))
		and not no_flip_unit.ingredient_model.has_type(IngredientModel.EGG),
		"egg placement remains restricted to the first-side egg stage after no-flip garnish begins"
	)
	no_flip_station.call("_on_shared_tool_selected", &"stock.pancake.sauce.sweet_flour")
	var no_flip_sauce := Dictionary(no_flip_station.begin_surface_action(0, no_flip_center))
	_check(
		bool(no_flip_sauce.get("success", false))
		and StringName(no_flip_sauce.get("action", &"")) == CompactGriddleUnit.SURFACE_ACTION_BRUSH_SAUCE
		and not no_flip_unit.pancake_model.is_flipped,
		"the no-flip route also permits sauce brushing before folding"
	)
	no_flip_station.clear_held_tool()
	var no_flip_fold: Dictionary = no_flip_unit.begin_manual_fold(Vector2(24.0, no_flip_center.y))
	_check(
		bool(no_flip_fold.get("success", false)) and no_flip_unit.state == CompactGriddleUnit.State.FOLDING,
		"the no-flip route proceeds from garnish to the normal manual-fold flow (%s)" % str(no_flip_fold.get("reason", ""))
	)
	no_flip_station.queue_free()
	no_flip_session.queue_free()
	_check(station.consume_ready(0), "delivered griddle can be consumed by source index")
	_check(station.ready_source_refs().is_empty(), "consumed griddle returns to an empty work surface")
	station.queue_free()
	session.queue_free()
	_finish()


func _order() -> Dictionary:
	return target_order.duplicate(true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _visible_coverage_pixels(value: Variant) -> int:
	var image := value as Image
	if image == null:
		return 0
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).r > 0.01:
				count += 1
	return count


func _visible_egg_pixels(value: Variant) -> int:
	var image := value as Image
	if image == null:
		return 0
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.r + pixel.g > 0.001:
				count += 1
	return count


func _mean_thickness_in_radius(model: PancakeModel, radius: float) -> float:
	var center := Vector2.ONE * (float(model.grid_size) - 1.0) * 0.5
	var total := 0.0
	var cell_count := 0
	for y in model.grid_size:
		for x in model.grid_size:
			if Vector2(x, y).distance_to(center) > radius:
				continue
			total += model.thickness[y * model.grid_size + x]
			cell_count += 1
	return total / maxf(float(cell_count), 1.0)


func _mean_covered_thickness(model: PancakeModel) -> float:
	var total := 0.0
	var covered_count := 0
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		total += model.thickness[index]
		covered_count += 1
	return total / maxf(float(covered_count), 1.0)


func _mean_wetness_in_radius(model: PancakeModel, radius: float) -> float:
	var center := Vector2.ONE * (float(model.grid_size) - 1.0) * 0.5
	var total := 0.0
	var covered_count := 0
	for y in model.grid_size:
		for x in model.grid_size:
			if Vector2(x, y).distance_to(center) > radius:
				continue
			var index := y * model.grid_size + x
			if model.coverage[index] <= 0.0:
				continue
			total += model.wetness[index]
			covered_count += 1
	return total / maxf(float(covered_count), 1.0)


func _mean_covered_wetness(model: PancakeModel) -> float:
	var total := 0.0
	var covered_count := 0
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		total += model.wetness[index]
		covered_count += 1
	return total / maxf(float(covered_count), 1.0)


func _coverage_ratio_in_radius(model: PancakeModel, radius: float) -> float:
	var center := Vector2.ONE * (float(model.grid_size) - 1.0) * 0.5
	var covered_count := 0
	var cell_count := 0
	for y in model.grid_size:
		for x in model.grid_size:
			if Vector2(x, y).distance_to(center) > radius:
				continue
			var index := y * model.grid_size + x
			covered_count += 1 if model.coverage[index] > 0.0 else 0
			cell_count += 1
	return float(covered_count) / maxf(float(cell_count), 1.0)


func _strictly_decreasing(values: PackedFloat32Array) -> bool:
	for index in range(1, values.size()):
		if values[index] >= values[index - 1] - 0.0001:
			return false
	return values.size() > 1


func _path_has_coverage(model: PancakeModel, from_grid: Vector2, to_grid: Vector2) -> bool:
	var distance := from_grid.distance_to(to_grid)
	var sample_count := maxi(1, ceili(distance))
	for sample_index in range(sample_count + 1):
		var sample := from_grid.lerp(to_grid, float(sample_index) / float(sample_count))
		var found := false
		for y_offset in range(-2, 3):
			for x_offset in range(-2, 3):
				var index := model.index_of(Vector2i(roundi(sample.x) + x_offset, roundi(sample.y) + y_offset))
				if index >= 0 and model.coverage[index] > 0.0:
					found = true
					break
			if found:
				break
		if not found:
			return false
	return true


func _finish() -> void:
	if failures.is_empty():
		print("MULTI_GRIDDLE_STATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("MULTI_GRIDDLE_STATION_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
