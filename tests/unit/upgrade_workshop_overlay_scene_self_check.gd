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
	_check(upgrade_prop_count == 21, "all active upgrade hotspots are authored in the workshop scene")
	_check(props.get_node_or_null("PressSpreaderPreview") is TextureRect, "press preview is an authored workshop-scene node")
	if session != null and props != null:
		var progression: RefCounted = session.call("progression_service")
		var wide_spreader_prop := props.get_node_or_null("WorkshopProp_growth_tool_pancake_wide_spreader") as Button
		var press_prop := props.get_node_or_null("WorkshopProp_growth_automation_pancake_press_once") as Button
		var advanced_soy_prop := props.get_node_or_null("WorkshopProp_growth_automation_fresh_soy_milk_advanced") as Button
		var finished_tray_prop := props.get_node_or_null("WorkshopProp_growth_capacity_youtiao_finished_tray") as Button
		var sesame_prop := props.get_node_or_null("WorkshopProp_growth_flavor_youtiao_sesame") as Button
		var sweet_flour_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_sweet_flour") as Button
		var baocui_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_baocui") as Button
		var scallion_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_scallion") as Button
		_check(press_prop != null and not press_prop.visible, "press is hidden until the wide spreader is installed")
		_check(advanced_soy_prop != null and not advanced_soy_prop.visible, "advanced soy machine is hidden until the intermediate machine is installed")
		var finished_tray_tag := finished_tray_prop.get_node_or_null("ConditionTag") as Label if finished_tray_prop != null else null
		_check(finished_tray_prop != null and finished_tray_prop.visible, "finished-youtiao tray remains labelled before the fryer is installed")
		_check(finished_tray_tag != null and finished_tray_tag.text.contains("先解锁油条区域"), "finished-youtiao tray label states its reservation prerequisite")
		_check(finished_tray_prop != null and finished_tray_prop.tooltip_text.contains("先解锁油条区域"), "finished-youtiao tray hover explains its reservation prerequisite")
		_check(sweet_flour_prop != null and sweet_flour_prop.visible, "sweet-flour sauce remains labelled before its qualification requirement is met")
		_check(baocui_prop != null and baocui_prop.visible and baocui_prop.tooltip_text.contains("煎饼合格 4 次"), "baocui tag remains visible and explains its qualification requirement")
		_check(scallion_prop != null and scallion_prop.visible and scallion_prop.tooltip_text.contains("煎饼合格 6 次"), "scallion tag remains visible and explains its qualification requirement")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
		progression.set("owned_growth_ids", {&"growth.area.youtiao": true})
		overlay.refresh()
		var sesame_tag := sesame_prop.get_node_or_null("ConditionTag") as Label if sesame_prop != null else null
		_check(sesame_prop != null and sesame_prop.visible, "sesame-youtiao tray remains labelled before its prerequisite is installed")
		_check(sesame_tag != null and sesame_tag.text.contains("先预订油条成品盘"), "sesame-youtiao tray label states its reservation prerequisite")
		_check(sesame_prop != null and sesame_prop.tooltip_text.contains("先预订油条成品盘"), "sesame-youtiao tray hover explains its reservation prerequisite")
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
		_check((wide_spreader_prop.get_node_or_null("ConditionTag") as Label).text.contains("已解锁"), "owned workshop upgrades use the unlocked label")
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
