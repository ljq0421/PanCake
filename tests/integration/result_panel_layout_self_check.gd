extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/result_panel_layout_1920x1080.png"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1920, 1080)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1210, 582))
	await process_frame
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 6:
		await process_frame
	var workstation := game.get_node("Workstation")
	workstation._populate_result({
		"score": 51.0,
		"feedback": "鸡蛋有些地方堆得太厚，画圈时再连续、均匀一些。",
		"dimensions": {
			"thickness": 0.0,
			"heat": 55.0,
			"egg": 54.0,
			"sauce": 10.0,
			"ingredients": 95.0,
			"order": 76.0,
			"time": 100.0,
		},
		"tags": ["鸡蛋偏厚", "摊制不均"],
	})
	_check(_metric_is_visible(workstation, "EggMetric"), "pancake result without order context retains egg metric")
	_check(_metric_is_visible(workstation, "IngredientMetric"), "pancake result without order context retains ingredient metric")
	_check(not _metric_is_visible(workstation, "IntegrityMetric"), "pancake result hides automatic integrity metric")
	_check(not _metric_is_visible(workstation, "FoldMetric"), "pancake result hides automatic fold metric")
	_check(workstation.order_score_label.text == "符合度  76", "pancake result names order-content scoring as compliance")

	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray()))
	_check(not _metric_is_visible(workstation, "EggMetric"), "eggless pancake hides egg metric")
	_check(not _metric_is_visible(workstation, "IngredientMetric"), "plain pancake hides ingredient metric")

	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray(["stock.pancake.egg"])))
	_check(_metric_is_visible(workstation, "EggMetric"), "egg-only pancake shows egg metric")
	_check(not _metric_is_visible(workstation, "IngredientMetric"), "egg-only pancake hides ingredient metric")

	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray(["stock.pancake.baocui"])))
	_check(not _metric_is_visible(workstation, "EggMetric"), "topping-only pancake hides egg metric")
	_check(_metric_is_visible(workstation, "IngredientMetric"), "topping-only pancake shows ingredient metric")

	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray(["stock.pancake.egg", "stock.pancake.baocui"])))
	_check(_metric_is_visible(workstation, "EggMetric"), "pancake with egg and toppings shows egg metric")
	_check(_metric_is_visible(workstation, "IngredientMetric"), "pancake with egg and toppings shows ingredient metric")

	workstation._order_summary_visible = true
	workstation._result_detail_open = false
	workstation._refresh_p1_ui()
	await process_frame
	_click(workstation.summary_view_button)
	for _frame in 4:
		await process_frame

	var panel: Control = workstation.result_panel
	var panel_rect := panel.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check(panel.is_visible_in_tree(), "view-order action opens the result panel")
	_check(viewport_rect.encloses(panel_rect), "the complete result panel remains inside the virtual viewport")
	for metric_name in ["IntegrityMetric", "ThicknessMetric", "HeatMetric", "EggMetric", "SauceMetric", "IngredientMetric", "FoldMetric", "OrderMetric", "TimeMetric"]:
		var icon := workstation.get_node("SafeArea/ResultPanel/Margin/VBox/DimensionGrid/%s/Icon" % metric_name) as TextureRect
		_check(icon != null and icon.texture != null, "%s loads its quality icon when the result panel opens" % metric_name)
	for node_name in ["ResultTitleLabel", "ResultDetailLabel", "DimensionGrid", "ResultTagsLabel", "PaymentDisplay", "NextOrderButton"]:
		var control := workstation.get_node("%" + node_name) as Control
		_check(control.is_visible_in_tree(), "%s remains visible" % node_name)
		_check(panel_rect.encloses(control.get_global_rect()), "%s remains inside the result panel" % node_name)

	var five_area_infrastructure := workstation.get_node_or_null("FiveAreaInfrastructure") as Control
	_check(five_area_infrastructure != null, "formal five-area workstation content is present")
	if five_area_infrastructure != null:
		_check(
			panel.z_index > _maximum_effective_z_index(five_area_infrastructure),
			"result panel renders above every five-area foreground and hotspot layer"
		)
		_check(
			five_area_infrastructure.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED,
			"opening result detail disables underlying workstation hotspots"
		)
	var input_shield := workstation.get_node_or_null("SafeArea/ResultDetailInputShield") as Control
	_check(input_shield != null and input_shield.is_visible_in_tree(), "result detail shows an outside-input shield")
	await _capture_result_detail()

	workstation._populate_result({
		"product_id": &"product.youtiao.plain",
		"score": 83.0,
		"feedback": "油条已送达",
		"display_product": {"quality": 83.0},
		"display_item": {"mismatch_reasons": PackedStringArray()},
	})
	_check(workstation.integrity_score_label.text == "火候  83", "youtiao result shows its cooking score")
	_check(workstation.thickness_score_label.text == "沥油  100", "youtiao result shows its draining score")
	_check(workstation.order_score_label.text == "订单  100", "youtiao result shows its order score")
	for metric_name in ["EggMetric", "SauceMetric", "IngredientMetric", "FoldMetric", "TimeMetric"]:
		var metric := workstation.get_node("SafeArea/ResultPanel/Margin/VBox/DimensionGrid/%s" % metric_name) as Control
		_check(not metric.visible, "youtiao result hides pancake-only %s" % metric_name)

	workstation._populate_result({
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"score": 90.0,
		"feedback": "豆浆已送达",
		"display_product": {"fill_ratio": 0.9, "sugar_servings": 1, "temperature_mode": &"room_temperature"},
		"display_item": {"mismatch_reasons": PackedStringArray(), "requested_sugar_servings": 1, "requested_temperature_mode": &"room_temperature"},
	})
	_check(workstation.integrity_score_label.text == "满杯度  90", "soy result shows its fill score")
	_check(workstation.thickness_score_label.text == "糖度  100", "soy result shows its sugar score")
	_check(workstation.heat_score_label.text == "温度  100", "soy result shows its temperature score")
	_check(workstation.order_score_label.text == "订单  100", "soy result shows its order score")

	_click(workstation.next_order_button)
	await process_frame
	_check(not panel.is_visible_in_tree(), "close action hides the result panel")
	_check(workstation.order_summary_card.is_visible_in_tree(), "close action returns to the clickable order summary")
	_check(input_shield != null and not input_shield.is_visible_in_tree(), "closing detail removes its outside-input shield")
	_check(
		five_area_infrastructure.mouse_behavior_recursive != Control.MOUSE_BEHAVIOR_DISABLED,
		"closing detail restores workbench input even while the order summary remains visible"
	)

	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RESULT_PANEL_LAYOUT_SELF_CHECK PASS")
		quit()
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _maximum_effective_z_index(item: CanvasItem, parent_z := 0) -> int:
	var effective_z := item.z_index + parent_z if item.z_as_relative else item.z_index
	var maximum := effective_z
	for child in item.get_children():
		if child is CanvasItem:
			maximum = maxi(maximum, _maximum_effective_z_index(child as CanvasItem, effective_z))
	return maximum


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _pancake_result_with_ingredients(ingredient_ids: PackedStringArray) -> Dictionary:
	return {
		"product_id": &"product.pancake.custom",
		"score": 100.0,
		"dimensions": {
			"thickness": 100.0,
			"heat": 100.0,
			"egg": 100.0,
			"sauce": 100.0,
			"ingredients": 100.0,
			"order": 100.0,
			"time": 100.0,
		},
		"display_item": {"ingredient_ids": ingredient_ids},
	}


func _metric_is_visible(workstation: Node, metric_name: String) -> bool:
	var metric := workstation.get_node("SafeArea/ResultPanel/Margin/VBox/DimensionGrid/%s" % metric_name) as Control
	return metric != null and metric.visible


func _capture_result_detail() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var save_error := root.get_texture().get_image().save_png(output_absolute)
	_check(save_error == OK, "GPU result-detail screenshot was saved")


func _click(control: Control) -> void:
	var position := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	var hovered := root.gui_get_hovered_control()
	_check(hovered == control, "%s receives pointer input at its visual center" % control.name)
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.position = position
	release.global_position = position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release, true)
