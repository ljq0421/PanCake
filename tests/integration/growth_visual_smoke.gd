extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session == null:
		push_error("GameSession autoload is unavailable")
		quit(1)
		return
	var output_directory := ProjectSettings.globalize_path("res://tmp/validation")
	DirAccess.make_dir_recursive_absolute(output_directory)

	session.begin_new_game()
	var progression: RefCounted = session.progression_service()
	progression.set("coins", 50)
	progression.set("reputation", 10)
	progression.set("current_day", 2)
	progression.call("set_metric", &"lifetime_orders", 4)
	session.save_workstation_progression(progression.call("snapshot"))
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var workstation := main.get_node("Workstation") as Workstation
	workstation.call("end_business_day")
	await process_frame
	await process_frame
	var daily_path := output_directory.path_join("daily_growth_visual_latest.png")
	if root.get_texture().get_image().save_png(daily_path) != OK:
		push_error("Failed to save daily growth capture")
		quit(1)
		return
	main.queue_free()
	await process_frame
	await process_frame

	progression = session.progression_service()
	progression.set("stall_tier", 1)
	progression.get("owned_items")[CATALOG.STALL_FIXED] = true
	progression.get("owned_items")[CATALOG.TOOL_SPREADER_WIDE] = true
	progression.get("owned_items")[CATALOG.TOOL_PRESS] = true
	progression.get("owned_items")[CATALOG.TOOL_SAUCE_BRUSH_AUTO] = true
	progression.get("equipment_levels")[CATALOG.DEVICE_SOY_MILK] = CATALOG.TIER_INTERMEDIATE
	progression.get("equipment_levels")[CATALOG.DEVICE_YOUTIAO] = CATALOG.TIER_BASIC
	session.save_workstation_progression(progression.call("snapshot"))
	main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var store_path := output_directory.path_join("fixed_store_growth_visual_latest.png")
	if root.get_texture().get_image().save_png(store_path) != OK:
		push_error("Failed to save fixed store capture")
		quit(1)
		return
	print("GROWTH_VISUAL_SMOKE_PASS: %s | %s" % [daily_path, store_path])
	quit(0)
