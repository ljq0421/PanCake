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
	_check(workstation.result_review_scroll.visible and workstation.result_review_cards.get_child_count() == 1, "single-product result uses one review card")
	_check(workstation.result_title_label.text == "顾客评价 · 1项" and not workstation.result_dimension_grid.visible, "single-product result uses the shared card format")
	var pancake_card := _only_review_card(workstation)
	_check(_review_metric_label(pancake_card, "egg") == "摊蛋 54", "pancake card retains egg scoring when no order context is available")
	_check(_review_metric_label(pancake_card, "ingredients") == "配料 95", "pancake card retains ingredient scoring when no order context is available")
	_check(_review_metric_has_icon(pancake_card, "thickness"), "pancake card places a quality icon before its metric label")

	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray()))
	pancake_card = _only_review_card(workstation)
	_check(_review_metric_label(pancake_card, "egg").is_empty(), "eggless pancake hides egg metric")
	_check(_review_metric_label(pancake_card, "ingredients").is_empty(), "plain pancake hides ingredient metric")

	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray(["stock.pancake.egg"])))
	pancake_card = _only_review_card(workstation)
	_check(not _review_metric_label(pancake_card, "egg").is_empty(), "egg-only pancake shows egg metric")
	_check(_review_metric_label(pancake_card, "ingredients").is_empty(), "egg-only pancake hides ingredient metric")

	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray(["stock.pancake.baocui"])))
	pancake_card = _only_review_card(workstation)
	_check(_review_metric_label(pancake_card, "egg").is_empty(), "topping-only pancake hides egg metric")
	_check(not _review_metric_label(pancake_card, "ingredients").is_empty(), "topping-only pancake shows ingredient metric")

	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray(["stock.pancake.egg", "stock.pancake.baocui"])))
	pancake_card = _only_review_card(workstation)
	_check(not _review_metric_label(pancake_card, "egg").is_empty(), "pancake with egg and toppings shows egg metric")
	_check(not _review_metric_label(pancake_card, "ingredients").is_empty(), "pancake with egg and toppings shows ingredient metric")
	workstation._populate_result({
		"review_items": [
			{"expected_product_id": &"product.pancake.custom", "actual_product_id": &"product.pancake.custom", "product": {"product_id": &"product.pancake.custom", "dimension_scores": {"thickness": 58.0, "heat": 72.0, "order": 100.0}}, "order_item": {"ingredient_ids": []}, "score": 58.0, "qualified": false, "feedback": "煎饼评分未达60分，本份不付款"},
			{"expected_product_id": &"product.youtiao.plain", "actual_product_id": &"product.youtiao.plain", "product": {"product_id": &"product.youtiao.plain", "quality": 92.0}, "order_item": {"mismatch_reasons": PackedStringArray()}, "score": 92.0, "qualified": true, "feedback": "油条符合订单要求"},
			{"expected_product_id": &"product.fresh_soy_milk.yellow_bean", "actual_product_id": &"product.fresh_soy_milk.yellow_bean", "product": {"product_id": &"product.fresh_soy_milk.yellow_bean", "fill_ratio": 0.96, "sugar_servings": 0, "temperature_mode": &"room_temperature"}, "order_item": {"requested_sugar_servings": 0, "requested_temperature_mode": &"room_temperature", "mismatch_reasons": PackedStringArray()}, "score": 96.0, "qualified": true, "feedback": "黄豆豆浆符合订单要求"},
		],
	})
	_check(workstation.result_review_scroll.visible and workstation.result_review_cards.get_child_count() == 3, "multi-item result renders one scrollable review card per ordered product")
	_check(workstation.result_title_label.text == "顾客评价 · 3项" and not workstation.result_dimension_grid.visible, "multi-item result uses the shared card format")
	var multi_soy_card := workstation.result_review_cards.get_child(2) as Control
	_check(_review_metric_has_icon(multi_soy_card, "IntegrityMetric"), "multi-product soy metric places an icon before its label")
	workstation._populate_result(_pancake_result_with_ingredients(PackedStringArray(["stock.pancake.egg", "stock.pancake.baocui"])))

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
	pancake_card = _only_review_card(workstation)
	for metric_name in ["thickness", "heat", "egg", "sauce", "ingredients", "order", "time"]:
		_check(_review_metric_has_icon(pancake_card, metric_name), "%s loads a quality icon in the shared review card" % metric_name)
	for node_name in ["ResultTitleLabel", "ResultDetailLabel", "ResultReviewScroll", "PaymentDisplay", "NextOrderButton"]:
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
	var youtiao_card := _only_review_card(workstation)
	_check(_review_metric_label(youtiao_card, "IntegrityMetric") == "火候 83", "youtiao card shows its cooking score")
	_check(_review_metric_label(youtiao_card, "ThicknessMetric") == "沥油 100", "youtiao card shows its draining score")
	_check(_review_metric_label(youtiao_card, "OrderMetric") == "订单 100", "youtiao card shows its order score")
	_check(_review_metric_has_icon(youtiao_card, "IntegrityMetric") and _review_metric_has_icon(youtiao_card, "ThicknessMetric"), "youtiao card uses its dedicated quality icons")

	workstation._populate_result({
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"score": 90.0,
		"feedback": "豆浆已送达",
		"display_product": {"fill_ratio": 0.9, "sugar_servings": 1, "temperature_mode": &"room_temperature"},
		"display_item": {"mismatch_reasons": PackedStringArray(), "requested_sugar_servings": 1, "requested_temperature_mode": &"room_temperature"},
	})
	var soy_card := _only_review_card(workstation)
	_check(_review_metric_label(soy_card, "IntegrityMetric") == "满杯度 90", "soy card shows its fill score")
	_check(_review_metric_label(soy_card, "ThicknessMetric") == "糖度 100", "soy card shows its sugar score")
	_check(_review_metric_label(soy_card, "HeatMetric") == "温度 100", "soy card shows its temperature score")
	_check(_review_metric_label(soy_card, "OrderMetric") == "订单 100", "soy card shows its order score")
	_check(_review_metric_has_icon(soy_card, "IntegrityMetric") and _review_metric_has_icon(soy_card, "ThicknessMetric") and _review_metric_has_icon(soy_card, "HeatMetric"), "soy card uses its dedicated quality icons")

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


func _only_review_card(workstation: Node) -> Control:
	var cards := workstation.get_node("SafeArea/ResultPanel/Margin/VBox/ResultReviewScroll/ResultReviewCards") as VBoxContainer
	if cards == null:
		return null
	if cards.get_child_count() != 1:
		return null
	return cards.get_child(0) as Control


func _review_metric_label(card: Control, metric_name: String) -> String:
	if card == null:
		return ""
	var label := card.get_node_or_null("Content/Metrics/%sMetric/Label" % metric_name) as Label
	return label.text if label != null else ""


func _review_metric_icon(card: Control, metric_name: String) -> TextureRect:
	if card == null:
		return null
	return card.get_node_or_null("Content/Metrics/%sMetric/Icon" % metric_name) as TextureRect


func _review_metric_has_icon(card: Control, metric_name: String) -> bool:
	var icon := _review_metric_icon(card, metric_name)
	return icon != null and icon.texture != null


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
