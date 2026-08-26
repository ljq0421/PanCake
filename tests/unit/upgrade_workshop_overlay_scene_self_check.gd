extends SceneTree

const OVERLAY_SCENE := preload("res://scenes/ui/upgrade_workshop_overlay.tscn")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

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
	var editor_preview := overlay.get_node_or_null("EditorPreview") as Control
	_check(editor_preview != null, "workshop scene keeps an editor-preview host")
	_check(editor_preview != null and editor_preview.get_child_count() == 0, "runtime workshop does not instantiate a duplicate workstation")
	var overlay_scene_source := FileAccess.get_file_as_string("res://scenes/ui/upgrade_workshop_overlay.tscn")
	var overlay_script_source := FileAccess.get_file_as_string("res://scripts/ui/upgrade_workshop_overlay.gd")
	_check(overlay_scene_source.contains("path=\"res://scenes/gameplay/five_area_workstation.tscn\""), "editor preview reads from the formal workstation scene")
	_check(overlay_scene_source.contains("name=\"SyncedWorkstationPreview\" parent=\"EditorPreview\" instance="), "workshop scene authors one synchronized external workstation instance")
	_check(overlay_script_source.contains("func _enter_tree()"), "runtime removes the editor-only workstation before child callbacks run")
	var props := overlay.get_node_or_null("UpgradeProps") as Control
	var scene_growth_ids := {}
	if props != null:
		for prop in props.get_children():
			if prop.name.begins_with("WorkshopProp_"):
				var growth_id := StringName(prop.get_meta("growth_id", &""))
				_check(not growth_id.is_empty(), "%s identifies its catalog growth" % prop.name)
				_check(not scene_growth_ids.has(growth_id), "%s has exactly one workshop hotspot" % growth_id)
				scene_growth_ids[growth_id] = true
	for growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		_check(scene_growth_ids.has(growth_id), "%s has an authored workshop hotspot" % growth_id)
	_check(scene_growth_ids.size() == CATALOG.GROWTH_DISPLAY_ORDER.size(), "workshop hotspots exactly match the active growth catalog")
	_check(props != null and props.get_node_or_null("WorkshopProp_growth_add_on_pancake_sweet_flour") == null, "baseline secret sauce is not presented as a purchasable upgrade")
	_check(props != null and props.get_node_or_null("PressSpreaderPreview") is TextureRect, "press preview is an authored workshop-scene node")
	if session != null and props != null:
		var progression: RefCounted = session.call("progression_service")
		var press_prop := props.get_node_or_null("WorkshopProp_growth_automation_pancake_press_once") as Button
		var initial_soy_prop := props.get_node_or_null("WorkshopProp_growth_area_fresh_soy_milk") as Button
		var intermediate_soy_prop := props.get_node_or_null("WorkshopProp_growth_automation_fresh_soy_milk_auto_fill") as Button
		var advanced_soy_prop := props.get_node_or_null("WorkshopProp_growth_automation_fresh_soy_milk_advanced") as Button
		var finished_tray_prop := props.get_node_or_null("WorkshopProp_growth_capacity_youtiao_finished_tray") as Button
		var sesame_prop := props.get_node_or_null("WorkshopProp_growth_flavor_youtiao_sesame") as Button
		var baocui_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_baocui") as Button
		var scallion_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_scallion") as Button
		var one_click_egg_prop := props.get_node_or_null("WorkshopProp_growth_automation_pancake_one_click_egg") as Button
		_check(press_prop != null and press_prop.visible, "press is the direct upgrade from the base spreader")
		_check(initial_soy_prop != null and initial_soy_prop.visible, "initial soy machine is the only soy machine label before the soy area is unlocked")
		_check(intermediate_soy_prop != null and not intermediate_soy_prop.visible, "intermediate soy machine is hidden until the initial machine is installed")
		_check(advanced_soy_prop != null and not advanced_soy_prop.visible, "advanced soy machine is hidden until the intermediate machine is installed")
		var finished_tray_tag := finished_tray_prop.get_node_or_null("ConditionTag") as Label if finished_tray_prop != null else null
		_check(finished_tray_prop != null and finished_tray_prop.visible, "finished-youtiao tray remains labelled before the fryer is installed")
		_check(finished_tray_tag != null and finished_tray_tag.text.contains("解锁条件：解锁油条区、拥有油条炸锅"), "workshop tags retain every unlock condition")
		_check(finished_tray_tag != null and finished_tray_tag.text.contains("价格：12 金币"), "workshop tags show the coin price")
		_check(finished_tray_prop != null and finished_tray_prop.tooltip_text.contains("先解锁油条区域"), "finished-youtiao tray hover explains its reservation prerequisite")
		_check(baocui_prop != null and baocui_prop.visible and baocui_prop.tooltip_text.contains("煎饼合格 4 次"), "baocui tag remains visible and explains its qualification requirement")
		_check(scallion_prop != null and scallion_prop.visible and scallion_prop.tooltip_text.contains("煎饼合格 6 次"), "scallion tag remains visible and explains its qualification requirement")
		_check(one_click_egg_prop != null and one_click_egg_prop.visible and one_click_egg_prop.tooltip_text.contains("拥有鸡蛋"), "one-click egg remains visible and explains that eggs must be unlocked first")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
		progression.set("owned_growth_ids", {&"growth.area.youtiao": true})
		overlay.refresh()
		var sesame_tag := sesame_prop.get_node_or_null("ConditionTag") as Label if sesame_prop != null else null
		_check(sesame_prop != null and sesame_prop.visible, "sesame-youtiao tray remains labelled before its prerequisite is installed")
		_check(sesame_tag != null and sesame_tag.text.contains("解锁条件：解锁油条区、拥有油条成品盘、油条合格2次"), "sesame-youtiao tray label states every reservation prerequisite")
		_check(sesame_prop != null and sesame_prop.tooltip_text.contains("先预订油条成品盘"), "sesame-youtiao tray hover explains its reservation prerequisite")
		progression.set("owned_growth_ids", {&"growth.area.youtiao": true, &"growth.area.fresh_soy_milk": true})
		overlay.refresh()
		_check(initial_soy_prop != null and not initial_soy_prop.visible, "initial soy machine label is replaced after it is installed")
		_check(intermediate_soy_prop != null and intermediate_soy_prop.visible, "intermediate soy machine label appears after the initial machine is installed")
		progression.set("owned_growth_ids", {
			&"growth.automation.pancake.press_once": true,
			&"growth.area.fresh_soy_milk": true,
			&"growth.automation.fresh_soy_milk.auto_fill": true,
		})
		overlay.refresh()
		_check(press_prop != null and press_prop.visible, "owned press remains visible in the workshop")
		_check(advanced_soy_prop != null and advanced_soy_prop.visible, "advanced soy machine appears after the intermediate machine is installed")
		var press_tag := press_prop.get_node_or_null("ConditionTag") as Label if press_prop != null else null
		_check(press_tag != null and press_tag.text.contains("已解锁"), "owned press uses the unlocked workshop label")
		_check(press_tag != null and press_tag.text.contains("价格：36 金币"), "press workshop label retains its coin price")
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
