## Historical manual-fold component fixture. The current baseline uses one-click automatic packing.
extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/automatic_pack_pointer_gpu.png"


class FakeProgression:
	extends RefCounted
	var owned_growth_ids := PackedStringArray()

	func owns_stock(_stock_id: StringName) -> bool:
		return true

	func owns_growth(growth_id: StringName) -> bool:
		return owned_growth_ids.has(str(growth_id))


class FakeSession:
	extends Node
	var progression := FakeProgression.new()
	var inventory := {"stock.pancake.batter": 99}
	var saved_griddles: Dictionary = {}

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(_stock_ids: Array) -> Dictionary:
		return {"success": true}

	func five_area_pancake_griddles_snapshot() -> Dictionary:
		return saved_griddles.duplicate(true)

	func save_five_area_pancake_griddles(value: Dictionary) -> Dictionary:
		saved_griddles = value.duplicate(true)
		return {"success": true}


var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("SINGLE_GESTURE_FOLD_GPU_SMOKE_FAIL\nGPU mode required")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var backdrop := ColorRect.new()
	backdrop.color = Color("#213034")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var session := FakeSession.new()
	root.add_child(session)
	var station := STATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	# The formal workstation enables the component's recursive GUI branch after
	# instancing it; reproduce that production binding in this isolated fixture.
	station.mouse_filter = Control.MOUSE_FILTER_STOP
	station.bind_session(session)
	var unit := station.units[0] as CompactGriddleUnit
	unit.position = Vector2(400.0, 150.0)
	_prepare_fold_surface(unit)
	var feedbacks := PackedStringArray()
	unit.fold_feedback_requested.connect(func(_unit_index: int, feedback_kind: StringName) -> void: feedbacks.append(str(feedback_kind)))

	_check(unit.main_action.visible and not unit.main_action.disabled, "the current baseline exposes one explicit package action")
	await _click_control(unit.main_action)
	_check(
		unit.fold_model.is_region_folded(PancakeFoldModel.REGION_LEFT)
		and unit.fold_steps == 1
		and StringName(unit.get("_automatic_fold_pending_region")) == PancakeFoldModel.REGION_RIGHT,
		"one pointer click commits the first automatic fold and arms the opposite side",
	)
	await create_timer(1.20).timeout
	_check(
		unit.fold_model.completed_fold_count() == 2
		and unit.fold_model.package_result == PancakeFoldModel.PACKAGE_BAG
		and unit.state == CompactGriddleUnit.State.READY,
		"the opposite side folds automatically and reaches the packaged ready state",
	)
	_check(feedbacks.count("automatic_fold") >= 2, "both automatic folds emit non-color feedback cues")

	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var screenshot := root.get_texture().get_image()
	_check(screenshot.save_png(output_absolute) == OK, "the final single-gesture frame is captured")
	station.queue_free()
	session.queue_free()
	backdrop.queue_free()
	await process_frame
	_finish(output_absolute)


func _prepare_fold_surface(unit: CompactGriddleUnit) -> void:
	unit.begin_order({"time_limit": 72.0})
	unit.pancake_model.coverage.fill(1.0)
	unit.pancake_model.thickness.fill(0.55)
	unit.pancake_model.wetness.fill(0.18)
	unit.pancake_model.doneness.fill(0.62)
	unit.pancake_model.flip(false)
	unit.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	unit.state = CompactGriddleUnit.State.GARNISH
	unit.pancake_model.changed.emit()
	unit.call("_refresh_ui")


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	_check(
		hovered == control,
		"the visible package button owns its pointer hit area (hovered=%s, rect=%s)" % [hovered.get_path() if hovered != null else "none", control.get_global_rect()],
	)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventMouseButton
	released.pressed = false
	root.push_input(released)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(output_absolute: String) -> void:
	if failures.is_empty():
		print("SINGLE_GESTURE_FOLD_GPU_SMOKE_PASS")
		print("SINGLE_GESTURE_FOLD_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("SINGLE_GESTURE_FOLD_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
