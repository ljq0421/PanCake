extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const RECIPE := &"recipe.youtiao.plain"
const AUTO_LIFT := &"automation.youtiao.auto_lift"
const AUTO_LOAD := &"automation.youtiao.auto_load"
const SCREENSHOT_1920 := "res://tmp/validation/youtiao_station_formal_1920x1080.png"
const SCREENSHOT_1280 := "res://tmp/validation/youtiao_station_formal_1280x720.png"

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("YOUTIAO_DIRECT_POINTER_SMOKE_FAIL\nGPU pointer smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {RECIPE: true, &"recipe.fresh_soy_milk.yellow_bean": true, &"recipe.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_product_ids", {&"product.youtiao.plain": true, &"product.fresh_soy_milk.yellow_bean": true, &"product.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true, &"stock.fresh_soy_milk.yellow_bean": true, &"stock.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_automation_ids", {AUTO_LOAD: true})
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.youtiao.plain_dough"] = 5
	inventory["stock.fresh_soy_milk.yellow_bean"] = 2
	inventory["stock.fresh_soy_milk.multigrain"] = 2
	session.call("save_inventory", inventory)
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	var station := workstation.get_node("FiveAreaInfrastructure/Stations/YoutiaoStation") as DirectYoutiaoStation
	_check(station != null and workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray") == null, "the formal same-screen scene exposes the direct fryer without a customer handoff tray")
	if station == null:
		workstation.queue_free()
		await process_frame
		_finish()
		return
	var soy_top := workstation.soy_split_slots[0] as Control
	var soy_bottom := workstation.soy_split_slots[3] as Control
	_check(soy_top.visible and soy_bottom.visible and soy_top.size.y < 50.0 and soy_bottom.size.y < 50.0, "multigrain unlock switches to six preauthored half-slot targets")
	await _hover_control(soy_top)
	_check(root.gui_get_hovered_control() == soy_top, "1920x1080 pointer resolves the upper soy half-slot")
	await _hover_control(soy_bottom)
	_check(root.gui_get_hovered_control() == soy_bottom, "1920x1080 pointer resolves the lower soy half-slot")
	workstation.tutorial_guide_overlay.call("show_guide", soy_top, "把黄豆拖入豆浆机")
	await process_frame
	var guide_highlight_1920 := workstation.tutorial_guide_overlay.get_node("TargetHighlight") as Control
	_check(guide_highlight_1920.get_global_rect().has_point(soy_top.get_global_rect().get_center()), "1920x1080 guide arrow layer aligns to the upper half-slot")
	workstation.tutorial_guide_overlay.call("hide_guide")
	workstation.set_process(false)
	_clear_formal_orders(session)
	var opened: Dictionary = session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "temperature_mode": &"room_temperature"}])
	_check(bool(opened.get("success", false)), "a formal youtiao order opens")
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	session.call("begin_formal_order_serving", order_id)
	var focused_order := Dictionary(session.call("formal_order", order_id))
	_check(StringName(focused_order.get("state", &"")) in [&"active", &"serving"], "the pointer test focuses a currently active formal order")
	workstation.call("_focus_formal_order", focused_order, false)
	await process_frame
	_check(station.auto_load_panel.visible and station.auto_load_visual.visible, "owned auto-load hardware is visible in the formal station")
	var plain_dough_source := workstation.youtiao_dough_slots[0] as Control
	await _hover_control(plain_dough_source)
	var dough_hovered := root.gui_get_hovered_control()
	_check(dough_hovered == plain_dough_source, "the GPU pointer resolves the bottom-dock dough source; hovered=%s visible=%s disabled=%s" % [str(dough_hovered.get_path() if dough_hovered != null else "none"), plain_dough_source.is_visible_in_tree(), plain_dough_source.disabled])
	session.call("credit_coins", 2)
	await _hold_control(plain_dough_source, 0.55)
	var inventory_after_hold := Dictionary(session.call("inventory_snapshot"))
	_check(int(inventory_after_hold.get("stock.youtiao.plain_dough", 0)) == 6 and int(session.call("five_area_progression_snapshot").get("coins", -1)) == 0, "real stationary pointer hold completes one 0.25-second youtiao restock unit after the shared hold threshold")

	await _drag_control(plain_dough_source, station.machine_stage)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"loaded", "real pointer drag moves one dough portion into the physical basket")
	await _click_control(station.start_button)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"frying", "real start-button click begins the unchanged frying model")
	session.call("advance_f3_production", 12.05)
	station.refresh_from_session()
	await process_frame
	await _click_control(station.lift_button)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"draining", "real lift-button click enters draining")
	session.call("advance_f3_production", 2.05)
	station.refresh_from_session()
	await process_frame
	var collectible := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(StringName(collectible.get("state", &"")) == &"ready_to_collect" and station.output_source.visible and not station.output_source.disabled, "the drained output exposes an enabled physical drag source")
	await _hover_control(station.output_source)
	_check(root.gui_get_hovered_control() == station.output_source, "the GPU pointer resolves the modular output hit area above the basket art")
	_check(StringName(station.output_source.source_ref().get("product_id", &"")) == &"product.youtiao.plain", "the physical output source carries the current product identity")
	var order_target := workstation.get_node("SafeArea/OrderCard/OrderDishTarget1") as Button
	_check(not order_target.disabled and order_target.mouse_filter == Control.MOUSE_FILTER_STOP, "the youtiao order product is an enabled pointer delivery target")
	await _hover_control(order_target)
	_check(root.gui_get_hovered_control() == order_target, "the GPU pointer resolves the order product target")
	await _click_control(order_target)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"idle", "real order-card click takes the drained youtiao directly from the fryer")
	var order := Dictionary(session.call("formal_order", order_id))
	var item := Dictionary(Array(order.get("items", []))[0]) if not Array(order.get("items", [])).is_empty() else {}
	_check(Array(item.get("prepared_product_instance_ids", [])).size() == 1 and StringName(order.get("state", &"")) == &"settled", "the order product click delivers and settles the fryer-held youtiao")
	_check(StringName(workstation.get("_formal_order_id")) != order_id, "the next customer is routed before youtiao payment collection")

	await _click_control(plain_dough_source)
	await _click_control(station.auto_plus_button)
	await _click_control(station.auto_confirm_button)
	await process_frame
	var auto_loaded := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(StringName(auto_loaded.get("state", &"")) == &"loaded" and int(auto_loaded.get("quantity", 0)) == 2, "real recipe, plus, and confirm clicks run one two-serving automatic load")
	progression.set("unlocked_automation_ids", {AUTO_LOAD: true, AUTO_LIFT: true})
	station.refresh_from_session()
	await _click_control(station.start_button)
	session.call("advance_f3_production", 12.05)
	station.refresh_from_session()
	for _frame in 3:
		await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"draining", "the purchased auto-lift reaches the same draining state without a manual click")
	_check(station.auto_lift_visual.visible and station.raised_basket_visual.visible and station.oil_drips_visual.visible, "the auto-lift attachment, high basket, and drips agree with the business state")
	await _save_viewport(SCREENSHOT_1920, Vector2i(1920, 1080))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 4:
		await process_frame
	await _hover_control(soy_top)
	_check(root.gui_get_hovered_control() == soy_top, "1280x720 pointer resolves the upper soy half-slot")
	await _hover_control(soy_bottom)
	_check(root.gui_get_hovered_control() == soy_bottom, "1280x720 pointer resolves the lower soy half-slot")
	workstation.tutorial_guide_overlay.call("show_guide", soy_bottom, "把五谷豆料拖入豆浆机")
	await process_frame
	var guide_highlight := workstation.tutorial_guide_overlay.get_node("TargetHighlight") as Control
	_check(workstation.tutorial_guide_overlay.visible and guide_highlight.get_global_rect().has_point(soy_bottom.get_global_rect().get_center()), "1280x720 guide arrow layer remains aligned to the lower half-slot")
	await _save_viewport(SCREENSHOT_1280, Vector2i(1280, 720))
	var stage_rect_before_tiers := station.machine_stage.get_global_rect()
	var start_rect_before_tiers := station.start_button.get_global_rect()
	var lift_rect_before_tiers := station.lift_button.get_global_rect()
	for tier in range(3):
		var tiers := Dictionary(progression.get("device_tiers")).duplicate(true)
		tiers[&"device.youtiao_fryer"] = tier
		progression.set("device_tiers", tiers)
		station.refresh_from_session()
		for _frame in 2:
			await process_frame
		var tier_snapshot := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
		_check(
			int(tier_snapshot.get("tier", -1)) == tier
			and station.body_visual.texture == station.body_textures[tier]
			and station.raised_basket_visual.texture == station.raised_basket_textures[tier],
			"fryer tier %d renders its matching enlarged body and raised-basket artwork" % tier
		)
		_check(
			station.machine_stage.get_global_rect().is_equal_approx(stage_rect_before_tiers)
			and station.start_button.get_global_rect().is_equal_approx(start_rect_before_tiers)
			and station.lift_button.get_global_rect().is_equal_approx(lift_rect_before_tiers),
			"fryer tier %d keeps the authored machine and action hit regions unchanged" % tier
		)
	workstation.queue_free()
	await process_frame
	_finish()


func _click_control(control: Control) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)
	await process_frame


func _hover_control(control: Control) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame


func _hold_control(control: Control, seconds: float) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var hover := InputEventMouseMotion.new()
	hover.position = position
	hover.global_position = position
	Input.parse_input_event(hover)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await create_timer(seconds).timeout
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)
	await process_frame


func _drag_control(source: Control, target: Control) -> void:
	var from := _pointer_position(source)
	var to := _pointer_position(target)
	Input.warp_mouse(from)
	var hover := InputEventMouseMotion.new()
	hover.position = from
	hover.global_position = from
	Input.parse_input_event(hover)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = from
	pressed.global_position = from
	root.push_input(pressed)
	await process_frame
	for ratio in [0.18, 0.42, 0.72, 1.0]:
		var position := from.lerp(to, ratio)
		Input.warp_mouse(position)
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		motion.relative = (to - from) * 0.24
		Input.parse_input_event(motion)
		await process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = to
	released.global_position = to
	root.push_input(released)
	await process_frame


func _pointer_position(control: Control) -> Vector2:
	# Control rectangles live in the authored 1920x1080 canvas. Pointer events
	# use physical window coordinates after canvas_items stretch is applied.
	return root.get_final_transform() * control.get_global_rect().get_center()


func _save_viewport(path: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var saved := image.save_png(absolute)
	_check(saved == OK and image.get_size() == expected_size, "%s is captured from the real GPU viewport" % path)


func _clear_formal_orders(session: Node) -> void:
	for _round in range(8):
		var queued: Array = Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders"))
		if queued.is_empty():
			return
		for order_value in queued:
			var order_id := StringName(Dictionary(order_value).get("order_id", &""))
			if not order_id.is_empty():
				session.call("abandon_formal_order", order_id, &"pointer_test_setup")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("YOUTIAO_DIRECT_POINTER_SMOKE_PASS")
		print("YOUTIAO_FORMAL_SCREENSHOT_1920=%s" % ProjectSettings.globalize_path(SCREENSHOT_1920))
		print("YOUTIAO_FORMAL_SCREENSHOT_1280=%s" % ProjectSettings.globalize_path(SCREENSHOT_1280))
		quit(0)
		return
	printerr("YOUTIAO_DIRECT_POINTER_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
