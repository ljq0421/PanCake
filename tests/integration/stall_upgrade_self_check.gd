extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	session.begin_new_game()
	var mobile := WORKSTATION_SCENE.instantiate()
	root.add_child(mobile)
	await process_frame
	await process_frame
	var mobile_positions := _workstation_rects(mobile)
	var mobile_background := mobile.get_node("SafeArea/BackgroundArtwork") as TextureRect
	_check("morning_mobile_cart" in mobile_background.texture.resource_path, "level-zero store uses the mobile-cart backplate")
	mobile.queue_free()
	await process_frame

	var progression: RefCounted = session.progression_service()
	progression.set("coins", 120)
	progression.set("reputation", 220)
	progression.set("current_day", 14)
	progression.call("set_metric", &"all_equipment_good", 3)
	var purchase: Dictionary = progression.call("purchase", CATALOG.STALL_FIXED)
	_check(bool(purchase.get("success", false)), "fixed store can be purchased at its documented gate")
	_check(int(progression.get("stall_tier")) == 0, "store appearance does not change before the next business day")
	progression.call("begin_next_business_day")
	session.save_workstation_progression(progression.call("snapshot"))
	_check(int(session.workstation_progression_snapshot().get("stall_tier", 0)) == 1, "store level is part of the complete persisted progression")

	var fixed := WORKSTATION_SCENE.instantiate()
	root.add_child(fixed)
	await process_frame
	await process_frame
	var fixed_background := fixed.get_node("SafeArea/BackgroundArtwork") as TextureRect
	_check(fixed_background.texture.resource_path == "res://resources/art/workstation/background/workstation_backplate_upgrade_v1.png", "fixed-store level swaps to the approved upgrade artwork")
	_check(_workstation_rects(fixed) == mobile_positions, "store artwork swap preserves every established workstation rectangle")
	var status: Dictionary = session.growth_purchase_status(CATALOG.STALL_FIXED)
	_check(bool(status.get("already_owned", false)), "growth service recognizes the fixed store as permanently owned")
	fixed.queue_free()
	await process_frame
	_finish()


func _workstation_rects(workstation: Control) -> Dictionary:
	var result := {}
	for path in ["SafeArea/PanBase", "SafeArea/IngredientRack", "SafeArea/LeftRack", "SafeArea/BottomStrip"]:
		var control := workstation.get_node(path) as Control
		result[path] = {"position": control.position, "size": control.size}
	return result


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("STALL_UPGRADE_SELF_CHECK_PASS")
		quit(0)
		return
	print("STALL_UPGRADE_SELF_CHECK_FAIL: %s" % ", ".join(_failures))
	quit(1)
