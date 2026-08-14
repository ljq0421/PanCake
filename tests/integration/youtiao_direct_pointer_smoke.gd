extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const RECIPE := &"recipe.youtiao.plain"
const AUTO_LIFT := &"automation.youtiao.auto_lift"
const SCREENSHOT_1920 := "res://tmp/validation/youtiao_station_formal_1920x1080.png"
const SCREENSHOT_1280 := "res://tmp/validation/youtiao_station_formal_1280x720.png"
const TWO_UNIT_SCREENSHOT_1920 := "res://tmp/validation/youtiao_two_units_gpu_1920x1080.png"
const SOY_SCREENSHOT_1366 := "res://tmp/validation/direct_soy_station_gpu_1366x768.png"
const SOY_SPOILED_SCREENSHOT_1920 := "res://tmp/validation/direct_soy_spoiled_gpu_1920x1080.png"
const SOY_AUTO_CUP_SCREENSHOT_1920 := "res://tmp/validation/direct_soy_auto_cup_gpu_1920x1080.png"

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
	progression.set("unlocked_recipe_ids", {RECIPE: true, &"recipe.fresh_soy_milk.yellow_bean": true, &"recipe.fresh_soy_milk.black_bean": true, &"recipe.fresh_soy_milk.red_bean": true, &"recipe.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_product_ids", {&"product.youtiao.plain": true, &"product.fresh_soy_milk.yellow_bean": true, &"product.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true, &"stock.fresh_soy_milk.yellow_bean": true, &"stock.fresh_soy_milk.black_bean": true, &"stock.fresh_soy_milk.red_bean": true})
	progression.set("unlocked_automation_ids", {})
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.youtiao.plain_dough"] = 7
	inventory["stock.fresh_soy_milk.yellow_bean"] = 2
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
	var soy_top := workstation.soy_full_slots[0] as Control
	var soy_bottom := workstation.soy_full_slots[2] as Control
	_check(soy_top.visible and soy_bottom.visible and soy_top.size.y == 89.0 and soy_bottom.size.y == 89.0, "multigrain unlock keeps three full-size bean targets")
	await _hover_control(soy_top)
	_check(root.gui_get_hovered_control() == soy_top, "1920x1080 pointer resolves the yellow-bean slot")
	await _hover_control(soy_bottom)
	if root.gui_get_hovered_control() != soy_bottom:
		for _frame in 2:
			await process_frame
		await _hover_control(soy_bottom)
	_check(root.gui_get_hovered_control() == soy_bottom, "1920x1080 pointer resolves the red-bean slot")
	workstation.tutorial_guide_overlay.call("show_guide", soy_top, "把黄豆拖入豆浆机")
	await process_frame
	var guide_highlight_1920 := workstation.tutorial_guide_overlay.get_node("TargetHighlight") as Control
	_check(guide_highlight_1920.get_global_rect().has_point(soy_top.get_global_rect().get_center()), "1920x1080 guide arrow layer aligns to the bean slot")
	workstation.tutorial_guide_overlay.call("hide_guide")
	workstation.set_process(false)
	_clear_formal_orders(session)
	var opened: Dictionary = session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 3, "temperature_mode": &"room_temperature"}])
	_check(bool(opened.get("success", false)), "a formal youtiao order opens")
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	session.call("begin_formal_order_serving", order_id)
	var focused_order := Dictionary(session.call("formal_order", order_id))
	_check(StringName(focused_order.get("state", &"")) in [&"active", &"serving"], "the pointer test focuses a currently active formal order")
	workstation.call("_focus_formal_order", focused_order, false)
	await process_frame
	_check(station.get_node_or_null("AutoLoadPanel") == null and station.get_node_or_null("MachineStage/ArtRoot/AutoLoadFeederVisual") == null, "retired auto-load controls and hardware are physically absent")
	var plain_dough_source := workstation.youtiao_dough_slots[0] as Control
	await _hover_control(plain_dough_source)
	var dough_hovered := root.gui_get_hovered_control()
	_check(dough_hovered == plain_dough_source, "the GPU pointer resolves the bottom-dock dough source; hovered=%s visible=%s disabled=%s" % [str(dough_hovered.get_path() if dough_hovered != null else "none"), plain_dough_source.is_visible_in_tree(), plain_dough_source.disabled])
	session.call("credit_coins", 2)
	await _hold_control(plain_dough_source, 0.55)
	var inventory_after_hold := Dictionary(session.call("inventory_snapshot"))
	_check(int(inventory_after_hold.get("stock.youtiao.plain_dough", 0)) == 8 and int(session.call("five_area_progression_snapshot").get("coins", -1)) == 0, "real stationary pointer hold completes one 0.25-second youtiao restock unit after the shared hold threshold")

	await _drag_control(plain_dough_source, station.machine_stage)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"loaded", "real pointer drag moves one dough portion into the physical basket")
	await _click_control(station.start_button)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"frying", "real start-button click begins the unchanged frying model")
	session.call("advance_f3_production", 10.05)
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
	await _drag_control(station.output_source, workstation.waste_area)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"idle", "dragging fryer output to waste discards the whole ready batch")
	await _produce_ready_quantity(session, station, plain_dough_source, 2)
	var prepared_plain := station.prepared_slots[0] as PreparedProductSlot
	var two_unit_snapshot := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(
		StringName(two_unit_snapshot.get("state", &"")) == &"ready_to_collect"
		and int(two_unit_snapshot.get("quantity", 0)) == 2
		and Array(two_unit_snapshot.get("occupied_slot_indices", [])).hash() == [0, 1].hash()
		and station.food_slots.filter(func(slot: Control): return slot.visible).size() == 2,
		"two real dough drags render exactly two ready single-unit sprites"
	)
	await _save_viewport(TWO_UNIT_SCREENSHOT_1920, Vector2i(1920, 1080))
	await _drag_control(station.output_source, prepared_plain)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"idle" and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", 0)) == 2, "one real output drag stores exactly the two visible products")
	session.call("clear_prepared_product_slots")
	station.refresh_from_session()
	await process_frame

	await _produce_ready_quantity(session, station, plain_dough_source, 4)
	await _hover_control(prepared_plain)
	_check(root.gui_get_hovered_control() == prepared_plain, "the GPU pointer resolves the oil-strip prepared compartment")
	await _drag_control(station.output_source, prepared_plain)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"idle" and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", 0)) == 4, "one real output drag transfers the whole four-strip batch into the matching compartment")
	await _drag_control(prepared_plain, workstation.waste_area)
	await process_frame
	_check(int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 3, "dragging the prepared compartment to waste discards one portion without touching the other three")
	var order_target := workstation.get_node("SafeArea/ServiceCustomer1/OrderPanel/ItemButton1") as Button
	var delivery_guide := Dictionary(workstation.call("_tutorial_guide_for_area", session, &"area.youtiao"))
	_check(delivery_guide.get("target") == order_target, "the stored-youtiao guide resolves the real customer-card target without a legacy OrderCard array")
	_check(not order_target.disabled and order_target.mouse_filter == Control.MOUSE_FILTER_STOP, "the youtiao order product is an enabled pointer delivery target")
	await _hover_control(order_target)
	_check(root.gui_get_hovered_control() == order_target, "the GPU pointer resolves the order product target")
	for _unit in 3:
		await _drag_control(prepared_plain, order_target)
		await process_frame
	_check(int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 0, "three real drags stage the oldest matching oil strips from the prepared compartment one at a time")
	var order := Dictionary(session.call("formal_order", order_id))
	var item := Dictionary(Array(order.get("items", []))[0]) if not Array(order.get("items", [])).is_empty() else {}
	_check(Array(item.get("prepared_product_instance_ids", [])).size() == 3 and StringName(order.get("state", &"")) == &"settled", "the order progress reaches 3/3 and settles")
	_check(StringName(workstation.get("_formal_order_id")) != order_id, "the next customer is routed before youtiao payment collection")

	var soy_station := workstation.fresh_soy_station as DirectSoyStation
	await _drag_control(soy_top, soy_station)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"loaded", "real pointer drag drops one bean portion into the direct soy machine")
	await _click_control(soy_station.water_button)
	session.call("advance_f3_production", 1.0)
	await _click_control(soy_station.water_button)
	await _click_control(soy_station.start_button)
	session.call("advance_f3_production", 5.0)
	soy_station.refresh_from_session()
	await process_frame
	var soy_waiting_for_cup := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(StringName(soy_waiting_for_cup.get("state", &"")) == &"ready_safe" and soy_station.machine_output.visible and not soy_station.machine_output.disabled, "finished soy batch automatically exposes a deliverable cup")
	await _save_viewport(SOY_AUTO_CUP_SCREENSHOT_1920, Vector2i(1920, 1080))
	var production_service: RefCounted = session.get("_production_service")
	_check(bool(Dictionary(production_service.call("collect_soy", 1)).get("success", false)), "GPU cup fixture consumes the prepared cup before starting its independent spoil case")
	soy_station.refresh_from_session()
	await _drag_control(soy_top, soy_station)
	await _click_control(soy_station.water_button)
	session.call("advance_f3_production", 1.0)
	await _click_control(soy_station.water_button)
	await _click_control(soy_station.start_button)
	session.call("advance_f3_production", 5.0)
	session.call("advance_f3_production", 16.0)
	soy_station.refresh_from_session()
	await process_frame
	var spoiled_source := Dictionary(soy_station.machine_output.source_ref())
	_check(bool(spoiled_source.get("discardable", false)) and soy_station.state_label.text == "豆浆已变质，请拖到废弃区", "spoiled soy batch exposes the current drag-to-waste prompt")
	await _save_viewport(SOY_SPOILED_SCREENSHOT_1920, Vector2i(1920, 1080))
	await _drag_control(soy_station.machine_output, workstation.waste_area)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"idle", "real pointer drag discards the whole spoiled machine batch through the unified waste target")

	progression.set("unlocked_automation_ids", {AUTO_LIFT: true})
	station.refresh_from_session()
	await process_frame
	_check(station.auto_lift_toggle.visible and station.auto_lift_toggle.button_pressed, "the purchased auto-lift exposes an enabled real-pointer toggle")
	await _click_control(station.auto_lift_toggle)
	await process_frame
	_check(not bool(session.call("youtiao_auto_lift_enabled")), "a real toggle click disables auto-lift")
	await _drag_control(plain_dough_source, station.machine_stage)
	await _click_control(station.start_button)
	session.call("advance_f3_production", 10.05)
	station.refresh_from_session()
	for _frame in 3:
		await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"ready_safe", "disabled auto-lift preserves the manual lift window")
	await _click_control(station.auto_lift_toggle)
	session.call("advance_f3_production", 0.01)
	station.refresh_from_session()
	for _frame in 3:
		await process_frame
	_check(bool(session.call("youtiao_auto_lift_enabled")) and StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"draining", "re-enabled auto-lift reaches draining without a manual lift click")
	_check(station.auto_lift_visual.visible and station.raised_basket_visual.visible and station.oil_drips_visual.visible, "the auto-lift attachment, high basket, and drips agree with the business state")
	await _save_viewport(SCREENSHOT_1920, Vector2i(1920, 1080))
	DisplayServer.window_set_size(Vector2i(1366, 768))
	for _frame in 4:
		await process_frame
	await _hover_control(soy_top)
	_check(root.gui_get_hovered_control() == soy_top, "1366x768 pointer resolves the yellow-bean slot")
	await _hover_control(soy_bottom)
	_check(root.gui_get_hovered_control() == soy_bottom, "1366x768 pointer resolves the red-bean slot")
	await _save_viewport(SOY_SCREENSHOT_1366, Vector2i(1366, 768))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 4:
		await process_frame
	await _hover_control(soy_top)
	_check(root.gui_get_hovered_control() == soy_top, "1280x720 pointer resolves the yellow-bean slot")
	await _hover_control(soy_bottom)
	_check(root.gui_get_hovered_control() == soy_bottom, "1280x720 pointer resolves the red-bean slot")
	workstation.tutorial_guide_overlay.call("show_guide", soy_bottom, "把红豆拖入豆浆机")
	await process_frame
	var guide_highlight := workstation.tutorial_guide_overlay.get_node("TargetHighlight") as Control
	_check(workstation.tutorial_guide_overlay.visible and guide_highlight.get_global_rect().has_point(soy_bottom.get_global_rect().get_center()), "1280x720 guide arrow layer remains aligned to the red-bean slot")
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


func _produce_ready_quantity(session: Node, station: DirectYoutiaoStation, dough_source: Control, quantity: int) -> void:
	for _unit in quantity:
		await _drag_control(dough_source, station.machine_stage)
	await process_frame
	await _click_control(station.start_button)
	session.call("advance_f3_production", 10.05)
	station.refresh_from_session()
	await process_frame
	await _click_control(station.lift_button)
	session.call("advance_f3_production", 2.05)
	station.refresh_from_session()
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
		print("YOUTIAO_TWO_UNIT_SCREENSHOT_1920=%s" % ProjectSettings.globalize_path(TWO_UNIT_SCREENSHOT_1920))
		print("DIRECT_SOY_SCREENSHOT_1366=%s" % ProjectSettings.globalize_path(SOY_SCREENSHOT_1366))
		print("DIRECT_SOY_SPOILED_SCREENSHOT_1920=%s" % ProjectSettings.globalize_path(SOY_SPOILED_SCREENSHOT_1920))
		print("DIRECT_SOY_AUTO_CUP_SCREENSHOT_1920=%s" % ProjectSettings.globalize_path(SOY_AUTO_CUP_SCREENSHOT_1920))
		quit(0)
		return
	printerr("YOUTIAO_DIRECT_POINTER_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
