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
	var editor_material_previews := overlay.get_node_or_null("EditorMaterialPreviews") as Control
	_check(editor_material_previews != null and not editor_material_previews.visible, "runtime hides the scene-authored editor material guides")
	var overlay_scene_source := FileAccess.get_file_as_string("res://scenes/ui/upgrade_workshop_overlay.tscn")
	var overlay_script_source := FileAccess.get_file_as_string("res://scripts/ui/upgrade_workshop_overlay.gd")
	_check(overlay_scene_source.contains("path=\"res://scenes/gameplay/four_area_workstation.tscn\""), "editor preview reads from the formal workstation scene")
	_check(overlay_scene_source.contains("name=\"SyncedWorkstationPreview\" parent=\"EditorPreview\"") and overlay_scene_source.contains("instance=ExtResource(\"3_workstation_preview\")"), "workshop scene authors one synchronized external workstation instance")
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
	_check(props != null and props.get_node_or_null("WorkshopProp_growth_automation_pancake_auto_sauce_brush") == null, "baseline automatic sauce is removed from the workshop")
	_check(props != null and props.get_node_or_null("PressSpreaderPreview") is TextureRect, "press preview is an authored workshop-scene node")
	var juice_tray_preview := props.get_node_or_null("FilledOrangeJuiceTrayPreview") as TextureRect if props != null else null
	_check(juice_tray_preview != null and juice_tray_preview.texture != null and juice_tray_preview.texture.resource_path.ends_with("yinpin-v1-10.png"), "workshop shows the authored full ten-box orange-juice tray preview")
	var juice_unlock_tag := props.get_node_or_null("WorkshopProp_growth_area_packaged_drink") as Button if props != null else null
	_check(juice_unlock_tag != null and juice_unlock_tag.visible and (juice_unlock_tag.get_node_or_null("ConditionTag") as Label).text == "200 金币" and is_equal_approx(juice_unlock_tag.modulate.a, 0.42), "locked juice-tray preview shows a translucent price-only reservation tag")
	_check(juice_unlock_tag != null and juice_unlock_tag.tooltip_text.contains("先解锁豆浆区域"), "locked juice-tray hover explains why it cannot be reserved")
	_check(juice_unlock_tag != null and juice_tray_preview != null and not juice_unlock_tag.get_global_rect().intersects(juice_tray_preview.get_global_rect()), "juice reservation tag is separate from the drink-tray artwork")
	_check(juice_tray_preview != null and is_equal_approx(juice_tray_preview.self_modulate.a, 0.42), "locked juice-tray preview is translucent")
	if session != null and props != null:
		var progression: RefCounted = session.call("progression_service")
		var press_prop := props.get_node_or_null("WorkshopProp_growth_automation_pancake_press_once") as Button
		var initial_youtiao_prop := props.get_node_or_null("WorkshopProp_growth_area_youtiao") as Button
		var initial_soy_prop := props.get_node_or_null("WorkshopProp_growth_area_fresh_soy_milk") as Button
		var intermediate_soy_prop := props.get_node_or_null("WorkshopProp_growth_automation_fresh_soy_milk_auto_fill") as Button
		var advanced_soy_prop := props.get_node_or_null("WorkshopProp_growth_automation_fresh_soy_milk_advanced") as Button
		var finished_tray_prop := props.get_node_or_null("WorkshopProp_growth_capacity_youtiao_finished_tray") as Button
		var chicken_tray_prop := props.get_node_or_null("WorkshopProp_growth_capacity_chicken_finished_tray") as Button
		var baocui_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_baocui") as Button
		var scallion_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_scallion") as Button
		var meat_floss_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_meat_floss") as Button
		var ham_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_ham_sausage") as Button
		var coriander_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_coriander") as Button
		var egg_prop := props.get_node_or_null("WorkshopProp_growth_add_on_pancake_egg") as Button
		var one_click_egg_prop := props.get_node_or_null("WorkshopProp_growth_automation_pancake_one_click_egg") as Button
		var non_burning_griddle_prop := props.get_node_or_null("WorkshopProp_growth_automation_pancake_non_burning_griddle") as Button
		_check(press_prop != null and press_prop.visible, "press is the direct upgrade from the base spreader")
		_check(initial_youtiao_prop != null and initial_youtiao_prop.visible, "initial youtiao fryer tag remains visible before its pancake prerequisites are installed")
		_check(initial_youtiao_prop != null and not initial_youtiao_prop.tooltip_text.is_empty(), "locked youtiao fryer tag explains its reservation prerequisites")
		_check(initial_soy_prop != null and initial_soy_prop.visible, "initial soy machine is the only soy machine label before the soy area is unlocked")
		_check(intermediate_soy_prop != null and not intermediate_soy_prop.visible, "intermediate soy machine is hidden until the initial machine is installed")
		_check(advanced_soy_prop != null and not advanced_soy_prop.visible, "advanced soy machine is hidden until the intermediate machine is installed")
		var finished_tray_tag := finished_tray_prop.get_node_or_null("ConditionTag") as Label if finished_tray_prop != null else null
		_check(finished_tray_prop != null and finished_tray_prop.visible, "finished-youtiao tray remains labelled before the fryer is installed")
		_check(finished_tray_tag != null and finished_tray_tag.text == "50 金币" and is_equal_approx(finished_tray_prop.modulate.a, 0.42), "unavailable workshop tags show a translucent price-only cost")
		_check(finished_tray_prop != null and finished_tray_prop.tooltip_text.contains("先解锁油条区域"), "finished-youtiao tray hover explains its reservation prerequisite")
		_check(chicken_tray_prop != null and chicken_tray_prop.visible and chicken_tray_prop.tooltip_text.contains("先预订双篮炸锅"), "chicken tray is visible in the workshop and explains its dual-fryer prerequisite")
		_check(baocui_prop != null and baocui_prop.visible and baocui_prop.tooltip_text.contains("金币"), "baocui tag remains visible and explains its current availability")
		_check(scallion_prop != null and scallion_prop.visible and scallion_prop.tooltip_text.contains("金币"), "scallion tag remains visible and explains its current availability")
		_check(meat_floss_prop != null and meat_floss_prop.visible and meat_floss_prop.tooltip_text.contains("先预订薄脆"), "meat-floss tag remains visible before its prerequisite is installed")
		_check(ham_prop != null and ham_prop.visible and ham_prop.tooltip_text.contains("先预订肉松"), "ham tag remains visible before its prerequisite is installed")
		_check(coriander_prop != null and coriander_prop.visible and coriander_prop.tooltip_text.contains("先预订香葱罐"), "coriander tag remains visible before its prerequisite is installed")
		_check(egg_prop != null and egg_prop.visible, "egg reservation is visible before the egg add-on is installed")
		_check(one_click_egg_prop != null and not one_click_egg_prop.visible, "one-click egg stays hidden before the egg add-on is installed")
		_check(non_burning_griddle_prop != null and non_burning_griddle_prop.visible and non_burning_griddle_prop.tooltip_text.contains("先预订定量面糊勺"), "non-burning griddle remains discoverable and explains its first missing prerequisite")
		_check(egg_prop != null and one_click_egg_prop != null and egg_prop.z_index > one_click_egg_prop.z_index, "egg reservation tag is drawn above the later one-click-egg upgrade at their shared anchor")
		if egg_prop != null:
			egg_prop.emit_signal("pressed")
			await process_frame
			var detail_text := overlay.get_node_or_null("DetailPanel/DetailText") as RichTextLabel
			_check(detail_text != null and detail_text.text.begins_with("[b]鸡蛋[/b]"), "pressing the egg tag opens egg details instead of one-click-egg details")
		progression.set("owned_growth_ids", {&"growth.add_on.pancake.egg": true})
		overlay.refresh()
		_check(egg_prop != null and not egg_prop.visible, "installed egg add-on hides its reservation tag")
		_check(one_click_egg_prop != null and one_click_egg_prop.visible, "one-click egg replaces the egg reservation after the egg add-on is installed")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
		progression.set("owned_growth_ids", {&"growth.area.youtiao": true})
		overlay.refresh()
		_check(props.get_node_or_null("WorkshopProp_growth_flavor_youtiao_sesame") == null, "retired sesame-youtiao upgrade is absent from the workshop")
		progression.set("owned_growth_ids", {&"growth.area.youtiao": true, &"growth.area.fresh_soy_milk": true})
		overlay.refresh()
		_check(initial_soy_prop != null and not initial_soy_prop.visible, "initial soy machine label is replaced after it is installed")
		_check(intermediate_soy_prop != null and intermediate_soy_prop.visible, "intermediate soy machine label appears after the initial machine is installed")
		progression.set("owned_growth_ids", {
			&"growth.automation.pancake.auto_batter_ladle": true,
			&"growth.automation.pancake.press_once": true,
			&"growth.area.fresh_soy_milk": true,
			&"growth.automation.fresh_soy_milk.auto_fill": true,
		})
		overlay.refresh()
		_check(press_prop != null and not press_prop.visible, "owned press hides its workshop tag")
		_check(non_burning_griddle_prop != null and non_burning_griddle_prop.visible and (non_burning_griddle_prop.get_node_or_null("ConditionTag") as Label).text == "180 金币", "non-burning griddle appears after its two prerequisite tools with its cost")
		_check(advanced_soy_prop != null and advanced_soy_prop.visible, "advanced soy machine appears after the intermediate machine is installed")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
		progression.set("coins", 200)
		overlay.refresh()
		_check(juice_unlock_tag != null and (juice_unlock_tag.get_node_or_null("ConditionTag") as Label).text == "200 金币" and is_equal_approx(juice_unlock_tag.modulate.a, 1.0), "available reservations show a solid price-only tag")
		if juice_unlock_tag != null:
			juice_unlock_tag.emit_signal("pressed")
		await process_frame
		_check(bool(Dictionary(session.call("growth_purchase_status", &"growth.area.packaged_drink")).get("pending_activation", false)), "pressing the reservation tag books the drink rack directly")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true})
		overlay.refresh()
		_check(juice_tray_preview != null and is_equal_approx(juice_tray_preview.self_modulate.a, 1.0) and juice_unlock_tag != null and not juice_unlock_tag.visible, "unlocked juice-tray preview becomes fully opaque and hides its condition tag")
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
