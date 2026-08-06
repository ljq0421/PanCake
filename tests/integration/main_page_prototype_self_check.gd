extends SceneTree

const PAGE_SCENE := preload("res://scenes/main/main_page_prototype.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var page := PAGE_SCENE.instantiate()
	root.add_child(page)
	await process_frame
	await process_frame

	var station_names := [
		"SoyMilkStation",
		"YoutiaoStation",
		"PancakeStation",
		"FinishedDrinkStation",
		"DimSumStation",
	]
	var previous_center_x := -INF
	for station_name in station_names:
		var station := page.get_node("Worktop/%s" % station_name) as Button
		_check(station != null, "%s exists as a clickable station" % station_name)
		if station != null:
			var center_x := station.get_global_rect().get_center().x
			_check(center_x > previous_center_x, "%s follows the requested left-to-right workstation order" % station_name)
			previous_center_x = center_x

	var pancake := page.get_node("Worktop/PancakeStation") as Button
	_check(is_equal_approx(pancake.get_global_rect().get_center().x, 960.0), "pancake operation is centered at X=960 in the 1920 reference layout")
	_check(StringName(page.get("selected_station_id")) == &"pancake" and pancake.button_pressed, "pancake is the default selected station")
	var customer_field := page.get_node("CustomerField") as Control
	var worktop := page.get_node("Worktop") as Control
	var material_dock := page.get_node("MaterialDock") as Control
	var lower_region_height := material_dock.get_global_rect().end.y - worktop.get_global_rect().position.y
	var customer_share := customer_field.size.y / (customer_field.size.y + lower_region_height)
	_check(customer_share >= 0.38 and customer_share <= 0.42, "customer queue and lower workstation occupy an approximately 4:6 vertical ratio")
	_check(not worktop.has_node("StationOrder"), "workstation-order caption is removed")
	_check(not material_dock.has_node("Title") and not material_dock.has_node("GroupSoy") and not material_dock.has_node("GroupYoutiao") and not material_dock.has_node("GroupPancake") and not material_dock.has_node("GroupFinishedDrink") and not material_dock.has_node("GroupSteam"), "both material-dock caption rows are removed")
	_check("下方 3 格原料位" in (page.get_node("Worktop/SoyMilkStation") as Button).text and not "2 列 × 2 行材料" in (page.get_node("Worktop/SoyMilkStation") as Button).text, "soy-milk station copy matches the single-row material allocation")

	var slots := page.get_node("MaterialDock/Slots") as GridContainer
	_check(slots.columns == 18 and slots.get_child_count() == 18, "material dock reserves exactly 1 row by 18 columns")
	var expected_groups := [&"soy_milk", &"soy_milk", &"soy_milk", &"youtiao", &"pancake", &"pancake", &"pancake", &"pancake", &"pancake", &"pancake", &"pancake", &"pancake", &"pancake", &"pancake", &"finished_drinks", &"dim_sum", &"dim_sum", &"dim_sum"]
	var station_slot_counts := {}
	for slot in slots.get_children():
		var row := int(slot.get_meta(&"grid_row", 0))
		var column := int(slot.get_meta(&"grid_column", 0))
		var station_id := StringName(str(slot.get_meta(&"station_id", "")))
		station_slot_counts[station_id] = int(station_slot_counts.get(station_id, 0)) + 1
		_check(row == 1 and column >= 1 and column <= 18, "%s has valid 18x1 coordinates" % slot.name)
		if row == 1 and column >= 1 and column <= 18:
			_check(station_id == expected_groups[column - 1], "%s follows the requested workstation grouping" % slot.name)
	_check(int(station_slot_counts.get(&"finished_drinks", 0)) == 1, "finished drinks use exactly one 1x1 stock slot")
	_check(int(station_slot_counts.get(&"pancake", 0)) == 10, "pancake materials occupy ten consecutive single-row slots")
	_check(not slots.has_node("SweetSauce") and not slots.has_node("Water"), "sweet sauce and machine water no longer consume material slots")

	var dim_sum := page.get_node("Worktop/DimSumStation") as Button
	dim_sum.emit_signal("pressed")
	await process_frame
	_check(StringName(page.get("selected_station_id")) == &"dim_sum" and dim_sum.button_pressed, "dim-sum station activation updates the selected page state")
	_check("馒头" in dim_sum.text and "菜包" in dim_sum.text and "肉包" in dim_sum.text and not "花卷" in dim_sum.text, "steam station matches the current first-release product scope")

	var finished_drinks := page.get_node("Worktop/FinishedDrinkStation") as Button
	finished_drinks.emit_signal("pressed")
	await process_frame
	_check(StringName(page.get("selected_station_id")) == &"finished_drinks" and "自动摆放" in finished_drinks.text and "1×1" in finished_drinks.text, "finished-drink cabinet advertises automatic display and its single stock slot")
	var drink_slot := page.get_node("MaterialDock/Slots/DrinkStockCrate") as Button
	_check(StringName(str(drink_slot.get_meta(&"station_id"))) == &"finished_drinks" and "自动摆放" in drink_slot.text, "the only finished-drink slot is the automatic stock crate")

	var pancake_tools := {
		"BatterSourceButton": &"batter_ladle",
		"SpreaderToolButton": &"spreader",
		"SauceBrushToolButton": &"sweet_sauce_brush",
		"FoldSpatulaToolButton": &"fold_spatula",
	}
	for tool_name in pancake_tools:
		var tool := page.get_node("Worktop/%s" % tool_name) as Button
		_check(tool != null, "%s is a visible pancake input" % tool_name)
		tool.emit_signal("pressed")
		await process_frame
		_check(StringName(page.get("last_clicked_tool")) == pancake_tools[tool_name], "%s is bound to click feedback" % tool_name)
	_check("面糊" in (page.get_node("Worktop/BatterSourceButton") as Button).text, "pancake batter has an explicit visible source")
	_check("甜面酱刷" in (page.get_node("Worktop/SauceBrushToolButton") as Button).text, "sweet sauce is represented by its countertop brush tool")
	_check("流程尚未接入" in (page.get_node("Header/PrototypeTag") as Label).text, "page clearly identifies itself as a click prototype rather than a completed flow")

	var red_bean := page.get_node("MaterialDock/Slots/RedBean") as Button
	red_bean.emit_signal("pressed")
	await process_frame
	_check(StringName(page.get("last_clicked_slot")) == &"red_bean", "material-slot activation reaches the page binding")
	_check("后续升级解锁" in (page.get_node("Worktop/FeedbackLabel") as Label).text, "locked material click returns explicit upgrade feedback")

	var order := page.get_node("CustomerField/Order2") as Button
	order.emit_signal("pressed")
	await process_frame
	_check("加热成品豆奶" in (page.get_node("Worktop/FeedbackLabel") as Label).text, "order cards use the latest finished-drink terminology")

	var pause_button := page.get_node("Header/PauseButton") as Button
	pause_button.emit_signal("pressed")
	await process_frame
	_check(paused and (page.get_node("PauseOverlay") as Control).visible, "pause control opens a real modal and pauses the tree")
	var resume_button := page.get_node("PauseOverlay/Dialog/Rows/ResumeButton") as Button
	resume_button.emit_signal("pressed")
	await process_frame
	_check(not paused and not (page.get_node("PauseOverlay") as Control).visible, "resume control closes the pause modal")

	var settings_button := page.get_node("Header/SettingsButton") as Button
	settings_button.emit_signal("pressed")
	await process_frame
	_check((page.get_node("SettingsOverlay") as Control).visible, "settings control opens its page-level placeholder modal")
	page.call("_close_settings")
	await process_frame

	page.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("MAIN_PAGE_PROTOTYPE_SELF_CHECK_PASS")
		quit(0)
	else:
		print("MAIN_PAGE_PROTOTYPE_SELF_CHECK_FAIL (%d)" % _failures.size())
		quit(1)
