extends SceneTree

const OVERLAY_SCENE := preload("res://scenes/ui/upgrade_workshop_overlay.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for fast-griddle workshop checks")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var overlay := OVERLAY_SCENE.instantiate() as UpgradeWorkshopOverlay
	root.add_child(overlay)
	await process_frame
	var non_burning := overlay.get_node_or_null("UpgradeProps/WorkshopProp_growth_automation_pancake_non_burning_griddle") as Button
	var fast_cook := overlay.get_node_or_null("UpgradeProps/WorkshopProp_growth_automation_pancake_fast_cook_griddle") as Button
	_check(non_burning != null and fast_cook != null, "both griddle upgrades have authored workshop tags")
	_check(non_burning != null and non_burning.visible and fast_cook != null and not fast_cook.visible, "fast-cook griddle remains hidden until the non-burning griddle is owned")

	var progression: RefCounted = session.call("progression_service")
	progression.set("owned_growth_ids", {
		&"growth.automation.pancake.auto_batter_ladle": true,
		&"growth.automation.pancake.press_once": true,
		&"growth.automation.pancake.non_burning_griddle": true,
	})
	progression.set("coins", 240)
	progression.set("day_open", false)
	overlay.refresh()
	var fast_tag := fast_cook.get_node_or_null("ConditionTag") as Label if fast_cook != null else null
	_check(non_burning != null and not non_burning.visible and fast_cook != null and fast_cook.visible, "fast-cook griddle replaces the completed non-burning griddle tag")
	_check(
		fast_tag != null
		and fast_tag.text == "240 金币"
		and is_equal_approx(fast_cook.modulate.a, 1.0)
		and fast_cook.tooltip_text.contains("快熟煎饼鏊子")
		and fast_cook.tooltip_text.contains("240 金币"),
		"available fast-cook reservation shows a solid price-only tag while hover help carries its details",
	)
	progression.set("coins", 0)
	overlay.refresh()
	_check(
		fast_tag != null
		and fast_tag.text == "240 金币"
		and is_equal_approx(fast_cook.modulate.a, 0.42),
		"unaffordable reservations keep their price but use a translucent tag",
	)
	progression.set("coins", 240)
	overlay.refresh()
	var purchase_status := Dictionary(session.call("growth_purchase_status", &"growth.automation.pancake.fast_cook_griddle"))
	_check(bool(purchase_status.get("can_purchase", false)), "fast-cook griddle is purchasable after the non-burning griddle")
	var purchase := Dictionary(session.call("purchase_growth", &"growth.automation.pancake.fast_cook_griddle"))
	_check(bool(purchase.get("success", false)) and int(purchase.get("charged_coins", 0)) == 240, "fast-cook griddle reservation charges 240 coins")

	overlay.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("UPGRADE_WORKSHOP_FAST_GRIDDLE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("UPGRADE_WORKSHOP_FAST_GRIDDLE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
