extends SceneTree

const WORKSTATION := preload("res://scripts/gameplay/five_area_workstation.gd")
const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const WORKSHOP_SCENE := preload("res://scenes/ui/upgrade_workshop_overlay.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tray := WORKSTATION_SCENE.instantiate()
	_check(tray.get_node_or_null("FiveAreaInfrastructure/PancakeHoldingTray") is TextureButton, "formal workstation authors a clickable pancake holding tray")
	_check(tray.get_node_or_null("FiveAreaInfrastructure/PancakeHoldingTray/SlotFrame01") is TextureRect and tray.get_node_or_null("FiveAreaInfrastructure/PancakeHoldingTray/SlotFrame02") is TextureRect, "holding tray authors two visible slots")
	var first_source := tray.get_node_or_null("FiveAreaInfrastructure/PancakeHoldingTray/PancakeHoldingSource01") as ProductDragSource
	var second_source := tray.get_node_or_null("FiveAreaInfrastructure/PancakeHoldingTray/PancakeHoldingSource02") as ProductDragSource
	_check(first_source != null and second_source != null and first_source.size == Vector2(114.0, 114.0) and second_source.size == Vector2(114.0, 114.0), "packaged pancakes fill each finished-tray slot at a readable size")
	_check(WORKSTATION.PANCAKE_HOLDING_PACKAGE_TEXTURE.resource_path.ends_with("paper_bag_package_v1.png"), "finished-tray slots keep the packaged pancake artwork separate from order cards")
	var egg_baocui := {
		"ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.baocui"],
		"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
	}
	var herb_pancake := {
		"ingredient_ids": [&"stock.pancake.scallion", &"stock.pancake.coriander"],
		"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
	}
	var egg_markers: Array = WORKSTATION._pancake_recipe_marker_entries(egg_baocui)
	var herb_markers: Array = WORKSTATION._pancake_recipe_marker_entries(herb_pancake)
	_check(egg_markers.size() == 3 and herb_markers.size() == 3 and egg_markers != herb_markers, "different pancake recipes produce different holding-tray icon sequences")
	tray.call("_refresh_pancake_recipe_markers", first_source, egg_baocui)
	var package_markers: Array[Node] = first_source.get_children().filter(func(child): return child.has_meta("pancake_recipe_marker"))
	_check(package_markers.size() == 3 and package_markers.all(func(marker): return marker.position.y >= 57.0 and marker.position.y < 80.0), "recipe icons are arranged across the paper bag front")
	_check(WORKSTATION._pancake_holding_tooltip(egg_baocui).contains("鸡蛋") and WORKSTATION._pancake_holding_tooltip(herb_pancake).contains("香菜"), "holding-tray tooltip names the complete stored recipe")
	tray.free()
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("begin_new_game")
		var progression: RefCounted = session.call("progression_service")
		progression.set("owned_growth_ids", {&"growth.capacity.pancake_holding_tray.first_slot": true})
		var formal_workstation := WORKSTATION_SCENE.instantiate()
		root.add_child(formal_workstation)
		await process_frame
		var first_slot_frame := formal_workstation.get_node_or_null("FiveAreaInfrastructure/PancakeHoldingTray/SlotFrame01") as TextureRect
		var second_slot_frame := formal_workstation.get_node_or_null("FiveAreaInfrastructure/PancakeHoldingTray/SlotFrame02") as TextureRect
		_check(first_slot_frame != null and first_slot_frame.visible and second_slot_frame != null and not second_slot_frame.visible, "formal workstation shows only the first holding tray slot until the second slot is unlocked")
		formal_workstation.queue_free()
		await process_frame
	var workshop := WORKSHOP_SCENE.instantiate()
	root.add_child(workshop)
	await process_frame
	_check(workshop.get_node_or_null("UpgradeProps/WorkshopProp_growth_capacity_pancake_holding_tray_first_slot") is Button and workshop.get_node_or_null("UpgradeProps/WorkshopProp_growth_capacity_pancake_holding_tray_second_slot") is Button, "workshop authors separate pancake holding-tray upgrade hotspots")
	var second_slot_tag := workshop.get_node_or_null("UpgradeProps/WorkshopProp_growth_capacity_pancake_holding_tray_second_slot") as Button
	_check(second_slot_tag != null and second_slot_tag.visible, "second holding-tray reservation tag remains visible with its prerequisite unmet")
	var preview_slot := workshop.get_node_or_null("UpgradeProps/PancakeHoldingTrayPreview/Slot01") as TextureRect
	_check(preview_slot != null and preview_slot.texture != null and preview_slot.texture.resource_path.ends_with("empty-square-ingredient-tray.png"), "workshop preview uses the confirmed empty-square tray asset")
	workshop.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PANCAKE_HOLDING_TRAY_DISPLAY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_HOLDING_TRAY_DISPLAY_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
