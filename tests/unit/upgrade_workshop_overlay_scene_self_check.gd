extends SceneTree

const OVERLAY_SCENE := preload("res://scenes/ui/upgrade_workshop_overlay.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for workshop visibility checks")
	if session != null:
		session.call("begin_new_game")
	var overlay := OVERLAY_SCENE.instantiate() as UpgradeWorkshopOverlay
	root.add_child(overlay)
	await process_frame
	_check(overlay.get_node_or_null("DetailPanel") is Panel, "detail panel is authored in the workshop scene")
	_check(overlay.get_node_or_null("DetailPanel/DetailText") is RichTextLabel, "detail content is authored in the workshop scene")
	_check(overlay.get_node_or_null("DetailPanel/BuyButton") is Button, "reservation button is authored in the workshop scene")
	_check(overlay.get_node_or_null("HoverHint/HintLabel") is Label, "hover hint is authored in the workshop scene")
	var props := overlay.get_node_or_null("UpgradeProps") as Control
	var upgrade_prop_count := 0
	if props != null:
		for prop in props.get_children():
			if prop.name.begins_with("WorkshopProp_"):
				upgrade_prop_count += 1
	_check(upgrade_prop_count == 18, "all remaining active upgrade hotspots are authored in the workshop scene")
	_check(props.get_node_or_null("PressSpreaderPreview") is TextureRect, "press preview is an authored workshop-scene node")
	if session != null and props != null:
		var progression: RefCounted = session.call("progression_service")
		var press_prop := props.get_node_or_null("WorkshopProp_growth_automation_pancake_press_once") as Button
		var advanced_soy_prop := props.get_node_or_null("WorkshopProp_growth_automation_fresh_soy_milk_advanced") as Button
		_check(press_prop != null and not press_prop.visible, "press is hidden until the wide spreader is installed")
		_check(advanced_soy_prop != null and not advanced_soy_prop.visible, "advanced soy machine is hidden until the intermediate machine is installed")
		progression.set("pending_growth_ids", [&"growth.tool.pancake.wide_spreader"])
		overlay.refresh()
		_check(press_prop != null and not press_prop.visible, "press remains hidden while the wide spreader is only reserved")
		progression.set("pending_growth_ids", [])
		progression.set("owned_growth_ids", {
			&"growth.tool.pancake.wide_spreader": true,
			&"growth.automation.fresh_soy_milk.auto_fill": true,
		})
		overlay.refresh()
		_check(press_prop != null and press_prop.visible, "press appears after the wide spreader is installed")
		_check(advanced_soy_prop != null and advanced_soy_prop.visible, "advanced soy machine appears after the intermediate machine is installed")
	overlay.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("UPGRADE_WORKSHOP_OVERLAY_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("UPGRADE_WORKSHOP_OVERLAY_SCENE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
