extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const RECIPE := &"recipe.steamer.mantou"
const STOCK := &"stock.steamer.mantou"
const PRODUCT := &"product.steamer.mantou"
const DEVICE := &"device.steamer"
const OUTPUT_DIR := "res://tmp/validation/direct_steamer_v6"

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("DIRECT_STEAMER_STATION_POINTER_GPU_SMOKE_FAIL\nGPU pointer smoke must run without --headless")
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
	_setup_session(session)
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in range(8):
		await process_frame
	workstation.set_process(false)
	var station := workstation.get_node("FiveAreaInfrastructure/Stations/SteamerStation") as DirectSteamerStation
	_check(station != null, "formal five-area workstation exposes direct_steamer_station")
	if station == null:
		workstation.queue_free()
		await process_frame
		_finish()
		return

	var input := station.input_sources[0] as ProductDragSource
	var layer := station.layer_targets[0] as SteamerLayerDropTarget
	await _hover_control(input)
	_check(root.gui_get_hovered_control() == input, "real pointer reaches the steamer ingredient source through the machine art")
	var load_target := await _begin_drag(input, layer)
	await create_timer(0.25).timeout
	_check(station.is_lid_open() and station.open_machine_visual.visible and station.open_machine_visual.modulate.a > 0.99, "ingredient drag opens the lid for the full native drag session")
	await _save_viewport(OUTPUT_DIR + "/tier_2_input_drag_open_1920x1080.png", Vector2i(1920, 1080))
	await _end_drag(load_target)
	await create_timer(0.25).timeout
	var loaded := Dictionary(session.call("f3_machine_snapshot", DEVICE))
	_check(StringName(Dictionary(Array(loaded.get("layers", []))[0]).get("state", &"")) == &"loaded", "real pointer drop loads layer 1")
	_check(not station.is_lid_open() and not station.open_machine_visual.visible, "successful ingredient drop closes the lid")

	await _click_control(station.layer_starts[0])
	await process_frame
	var steaming := Dictionary(session.call("f3_machine_snapshot", DEVICE))
	_check(StringName(Dictionary(Array(steaming.get("layers", []))[0]).get("state", &"")) == &"steaming", "start button begins the unchanged steamer model")
	_check(not station.is_lid_open(), "start button does not open the lid")
	session.call("advance_f3_production", 8.0)
	station.refresh_from_session()
	await process_frame
	_check(station.layer_outputs[0].visible and not station.layer_outputs[0].disabled, "mature product exposes a real output drag source")
	var mature_target := await _begin_drag(station.layer_outputs[0], workstation.waste_area)
	await create_timer(0.25).timeout
	_check(station.is_lid_open(), "dragging a mature product opens the lid")
	await _end_drag(mature_target)
	await create_timer(0.25).timeout
	_check(_layer_state(session, 0) == &"empty" and not station.is_lid_open(), "mature product can be dragged to waste and the lid closes")

	await _drag_control(input, layer)
	await create_timer(0.25).timeout
	await _click_control(station.layer_starts[0])
	session.call("advance_f3_production", 25.0)
	station.refresh_from_session()
	await process_frame
	_check(_layer_state(session, 0) == &"spoiled" and station.layer_outputs[0].visible, "spoiled product remains an enabled output source")
	var spoiled_target := await _begin_drag(station.layer_outputs[0], workstation.waste_area)
	await create_timer(0.25).timeout
	_check(station.is_lid_open(), "dragging spoiled product opens the lid")
	await _end_drag(spoiled_target)
	await create_timer(0.25).timeout
	_check(_layer_state(session, 0) == &"empty" and not station.is_lid_open(), "spoiled product reaches waste and the lid closes")

	station.set_process(false)
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(size)
		for _frame in range(4):
			await process_frame
		for tier in range(3):
			var capacity: int = [1, 2, 4][tier]
			station.apply_visual_snapshot(_visual_snapshot(tier, capacity), true, PackedStringArray([str(RECIPE)]), {str(STOCK): 3})
			await process_frame
			await _save_viewport(OUTPUT_DIR + "/tier_%d_closed_%dx%d.png" % [tier + 1, size.x, size.y], size)
			station.call("_on_steamer_drag_started", {"source_kind": &"steamer_input"})
			await create_timer(0.25).timeout
			await _save_viewport(OUTPUT_DIR + "/tier_%d_open_%dx%d.png" % [tier + 1, size.x, size.y], size)
			station.call("_on_steamer_drag_ended", {"source_kind": &"steamer_input"}, false)
			await create_timer(0.25).timeout

	workstation.queue_free()
	await process_frame
	_finish()


func _setup_session(session: Node) -> void:
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.steamer": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, DEVICE: 1})
	progression.set("unlocked_recipe_ids", {RECIPE: true})
	progression.set("unlocked_product_ids", {PRODUCT: true})
	progression.set("unlocked_stock_ids", {STOCK: true})
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory[str(STOCK)] = 4
	session.call("save_inventory", inventory)


func _layer_state(session: Node, layer_index: int) -> StringName:
	var machine := Dictionary(session.call("f3_machine_snapshot", DEVICE))
	var layers := Array(machine.get("layers", []))
	return StringName(Dictionary(layers[layer_index]).get("state", &"")) if layer_index < layers.size() else &"missing"


static func _visual_snapshot(tier: int, capacity: int) -> Dictionary:
	var layers: Array[Dictionary] = []
	for index in range(4):
		layers.append({"state": &"empty", "recipe_id": &"", "quantity": 0} if index < capacity else {"state": &"locked", "recipe_id": &"", "quantity": 0})
	return {"owned": true, "tier": tier, "layer_capacity": capacity, "layers": layers}


func _click_control(control: Control) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var hover := InputEventMouseMotion.new()
	hover.position = position
	hover.global_position = position
	Input.parse_input_event(hover)
	await process_frame
	for pressed_value in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed_value
		event.position = position
		event.global_position = position
		root.push_input(event)
		await process_frame


func _hover_control(control: Control) -> void:
	var position := _pointer_position(control)
	Input.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame


func _begin_drag(source: Control, target: Control) -> Vector2:
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
	return to


func _end_drag(position: Vector2) -> void:
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)
	await process_frame


func _drag_control(source: Control, target: Control) -> void:
	var target_position := await _begin_drag(source, target)
	await _end_drag(target_position)


func _pointer_position(control: Control) -> Vector2:
	return root.get_final_transform() * control.get_global_rect().get_center()


func _save_viewport(path: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var saved := image.save_png(absolute)
	_check(saved == OK and image.get_size() == expected_size, "%s is captured from the real GPU viewport" % path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DIRECT_STEAMER_STATION_POINTER_GPU_SMOKE_PASS")
		print("DIRECT_STEAMER_V6_SCREENSHOTS=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	printerr("DIRECT_STEAMER_STATION_POINTER_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
