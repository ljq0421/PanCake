extends SceneTree

const SESSION_SCRIPT := preload("res://scripts/services/game_session_store.gd")
const SOURCE_SCRIPT := preload("res://scripts/ui/product_drag_source.gd")
const UI_SCALE_APPLIER := preload("res://scripts/ui/ui_scale_applier.gd")
const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const SETTINGS_PANEL_SCRIPT := preload("res://scripts/ui/game_settings_panel.gd")

const TOOL_KEYS := {
	&"tool_ladle": KEY_1,
	&"tool_spreader": KEY_2,
	&"tool_sauce_brush": KEY_3,
	&"tool_fold_package": KEY_4,
}

var failures := PackedStringArray()
var hold_release_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload exists")
	if session == null:
		_finish()
		return
	_test_opening_restock_tasks(session)
	_test_tutorial_retry_and_skip(session)
	await _test_tool_shortcuts(session)
	await _test_settings_contract(session)
	await _test_feedback_controls()
	_finish()


func _test_opening_restock_tasks(session: Node) -> void:
	session.call("begin_new_game")
	var initial := Array(session.call("opening_restock_tasks"))
	_check(initial.size() == 2, "opening checklist only exposes the two unlocked starter stocks")
	_check(
		initial.all(func(value: Variant) -> bool: return bool(Dictionary(value).get("is_unlimited", false)) and bool(Dictionary(value).get("completed", false)) and int(Dictionary(value).get("target", -1)) == 0),
		"unlimited starter stocks are shown as complete rather than hard-coded quantities"
	)
	var progression: RefCounted = session.call("progression_service")
	var unlocked := Dictionary(progression.get("unlocked_stock_ids")).duplicate(true)
	unlocked[&"stock.pancake.egg"] = true
	unlocked[&"stock.pancake.baocui"] = true
	progression.set("unlocked_stock_ids", unlocked)
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.pancake.egg"] = 0
	inventory["stock.pancake.baocui"] = 0
	session.call("save_inventory", inventory)
	var tasks := Array(session.call("opening_restock_tasks"))
	_check(_task_index(tasks, &"stock.youtiao.plain_dough") < 0, "locked stock never appears in the opening checklist")
	_check(_next_task_id(tasks) == &"stock.pancake.egg" and _next_task_count(tasks) == 1, "the first incomplete catalog item is the unique highlighted next step")
	var egg := Dictionary(tasks[_task_index(tasks, &"stock.pancake.egg")])
	_check(int(egg.get("current", -1)) == 0 and int(egg.get("target", -1)) == 3, "finite stock reports current and suggested target")
	inventory["stock.pancake.egg"] = 3
	session.call("save_inventory", inventory)
	tasks = Array(session.call("opening_restock_tasks"))
	_check(_next_task_id(tasks) == &"stock.pancake.baocui", "live quantity changes advance the checklist in catalog order")
	inventory["stock.pancake.baocui"] = 3
	session.call("save_inventory", inventory)
	tasks = Array(session.call("opening_restock_tasks"))
	_check(_next_task_count(tasks) == 0 and tasks.all(func(value: Variant) -> bool: return bool(Dictionary(value).get("completed", false))), "a fully stocked snapshot has no highlighted next step")


func _test_settings_contract(session: Node) -> void:
	var defaults := Dictionary(session.call("default_key_bindings"))
	for action_id in TOOL_KEYS:
		_check(int(defaults.get(str(action_id), 0)) == int(TOOL_KEYS[action_id]), "%s has the documented default key" % action_id)
		_check(InputMap.has_action(action_id), "%s exists in InputMap" % action_id)
		var events := InputMap.action_get_events(action_id)
		_check(not events.is_empty() and events[0] is InputEventKey and int((events[0] as InputEventKey).physical_keycode) == int(TOOL_KEYS[action_id]), "%s InputMap action uses its documented number key" % action_id)
	var conflicting := defaults.duplicate(true)
	conflicting["tool_spreader"] = conflicting["tool_ladle"]
	var conflict := Dictionary(session.call("save_settings", 80.0, 85.0, false, 125.0, 100.0, conflicting))
	_check(
		not bool(conflict.get("success", false))
		and StringName(conflict.get("reason", &"")) == &"key_binding_conflict"
		and Array(conflict.get("actions", [])).size() == 2,
		"duplicate keyboard bindings are rejected with both conflicting actions"
	)
	_check(
		is_equal_approx(float(SESSION_SCRIPT._normalized_ui_scale(111.0)), 100.0)
		and is_equal_approx(float(SESSION_SCRIPT._normalized_ui_scale(139.0)), 150.0),
		"UI scale normalizes to the three supported presets"
	)
	var settings_path := "res://tmp/validation/p1_settings_persistence.cfg"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings_path).get_base_dir())
	session.set("_active_settings_path", settings_path)
	var remapped := defaults.duplicate(true)
	remapped["tool_ladle"] = KEY_Q
	var saved := Dictionary(session.call("save_settings", 71.0, 63.0, false, 125.0, 150.0, remapped))
	_check(bool(saved.get("success", false)), "valid keyboard remapping and accessibility settings save successfully")
	var restored := SESSION_SCRIPT.new()
	restored.name = "RestoredP1SettingsSession"
	restored.set("_active_settings_path", settings_path)
	root.add_child(restored)
	await process_frame
	var loaded := Dictionary(restored.call("get_settings"))
	_check(
		is_equal_approx(float(loaded.get("ui_scale", 0.0)), 125.0)
		and is_equal_approx(float(loaded.get("drag_sensitivity", 0.0)), 150.0)
		and int(Dictionary(loaded.get("key_bindings", {})).get("tool_ladle", 0)) == KEY_Q,
		"UI scale, drag sensitivity, and remapped keyboard bindings survive reload"
	)
	var panel := SETTINGS_PANEL_SCRIPT.new() as GameSettingsPanel
	root.add_child(panel)
	await process_frame
	panel.open_with_session(restored)
	panel.call("_begin_key_capture", &"tool_spreader")
	var duplicate_key := InputEventKey.new()
	duplicate_key.pressed = true
	duplicate_key.physical_keycode = KEY_Q
	panel.call("_input", duplicate_key)
	_check(StringName(panel.get("_capture_action")) == &"tool_spreader" and "已被" in str((panel.get("_message") as Label).text), "settings panel identifies the conflicting action without saving the duplicate key")
	var cancel_key := InputEventKey.new()
	cancel_key.pressed = true
	cancel_key.physical_keycode = KEY_ESCAPE
	panel.call("_input", cancel_key)
	_check(StringName(panel.get("_capture_action")).is_empty(), "Esc cancels keyboard remapping capture")
	panel.call("_reset_key_bindings")
	_check(Dictionary(panel.get("_pending_bindings")) == defaults, "restore-default resets all four tool bindings before save")
	panel.queue_free()
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _test_tutorial_retry_and_skip(session: Node) -> void:
	session.call("begin_new_game")
	session.call("advance_customer_arrivals", 5.0)
	var order := Dictionary(session.call("active_formal_order"))
	var order_id := StringName(order.get("order_id", &""))
	for attempt in 3:
		var mismatch := Dictionary(session.call("attach_formal_order_product", order_id, 0, {
			"product_instance_id": StringName("test.retry.%d" % attempt),
			"product_id": &"product.pancake.custom",
			"area_id": &"area.pancake",
			"heat_preference": &"charred",
			"ingredient_ids": [],
			"sauce_ids": [],
		}))
		_check(StringName(mismatch.get("reason", &"")) == &"tutorial_order_mismatch", "tutorial mismatch attempt %d stays safely retryable" % (attempt + 1))
	var before_skip_orders := int(Dictionary(session.get("_save_data")).get("orders_completed", -1))
	var pending := Dictionary(Dictionary(session.call("five_area_progression_snapshot")).get("tutorial", {}))
	_check(StringName(pending.get("active_id", &"")) == &"area.pancake" and int(Dictionary(pending.get("failure_count_by_id", {})).get("area.pancake", 0)) == 3, "repeated tutorial mistakes never auto-end the lesson")
	var skipped := Dictionary(session.call("skip_active_area_tutorial"))
	var tutorial := Dictionary(Dictionary(session.call("five_area_progression_snapshot")).get("tutorial", {}))
	var active_orders := Array(session.call("active_formal_orders"))
	_check(
		bool(skipped.get("success", false))
		and StringName(Dictionary(tutorial.get("final_outcome_by_id", {})).get("area.pancake", &"")) == &"skipped"
		and int(Dictionary(session.get("_save_data")).get("orders_completed", -1)) == before_skip_orders,
		"explicit skip releases the progression gate without recording a successful order"
	)
	_check(active_orders.is_empty() or not bool(Dictionary(active_orders.front()).get("tutorial_no_countdown", false)), "skipping cannot leave a replacement tutorial order in the live queue")


func _test_tool_shortcuts(session: Node) -> void:
	session.call("begin_new_game")
	var workstation := WORKSTATION_SCENE.instantiate() as FiveAreaWorkstation
	root.add_child(workstation)
	for _frame in 3:
		await process_frame
	var griddle := workstation.multi_griddle_station as MultiGriddleStation
	var click_result := Dictionary(griddle.call("select_worktop_tool", &"tool.pancake.ladle"))
	griddle.call("clear_held_tool")
	var shortcut_result := Dictionary(workstation.call("_activate_tool_shortcut", &"tool_ladle"))
	_check(bool(click_result.get("success", false)) == bool(shortcut_result.get("success", false)) and shortcut_result.has_all(["reason", "message", "target"]) and StringName(griddle.get("_selected_tool")) == &"tool.pancake.ladle", "number-key ladle uses the same unified station validation path as clicking the tool")
	var selected_before := StringName(griddle.get("_selected_tool"))
	var direct_sauce := Dictionary(griddle.call("select_worktop_tool", &"stock.pancake.sauce.sweet_flour"))
	var shortcut_sauce := Dictionary(workstation.call("_activate_tool_shortcut", &"tool_sauce_brush"))
	_check(not bool(direct_sauce.get("success", false)) and StringName(shortcut_sauce.get("reason", &"")) == StringName(direct_sauce.get("reason", &"")) and StringName(griddle.get("_selected_tool")) == selected_before, "unavailable shortcut reports the click-path reason without changing the selected tool")
	var state_before := int(griddle.units[0].state)
	var fold_result := Dictionary(workstation.call("_activate_tool_shortcut", &"tool_fold_package"))
	_check(not bool(fold_result.get("success", false)) and int(griddle.units[0].state) == state_before, "fold shortcut leaves production unchanged when the stage is invalid")
	workstation.queue_free()
	await process_frame


func _test_feedback_controls() -> void:
	var holder := Control.new()
	root.add_child(holder)
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", 12)
	holder.add_child(label)
	var fixed_button := Button.new()
	fixed_button.custom_minimum_size = Vector2(120.0, 30.0)
	holder.add_child(fixed_button)
	UI_SCALE_APPLIER.apply_to(holder, 150.0, 24, false)
	_check(label.get_theme_font_size(&"font_size") == 36, "150% UI scale preserves the 24 px design minimum before scaling")
	_check(fixed_button.custom_minimum_size.is_equal_approx(Vector2(120.0, 30.0)), "gameplay UI scaling does not alter authored hit geometry")

	var source := SOURCE_SCRIPT.new() as ProductDragSource
	source.size = Vector2(120.0, 120.0)
	source.hold_enabled = true
	source.hold_threshold_seconds = 0.20
	holder.add_child(source)
	await process_frame
	source.configure({"source_kind": &"test", "stock_id": &"stock.test"}, null, true, "test")
	source.call("_apply_interaction_settings", {"drag_sensitivity": 50.0})
	_check(is_equal_approx(source.drag_threshold_pixels, 6.0) and is_equal_approx(float(source.get("_effective_cancel_tolerance_pixels")), 4.0), "50% drag sensitivity raises the start threshold and narrows cancel tolerance")
	source.call("_apply_interaction_settings", {"drag_sensitivity": 150.0})
	_check(is_equal_approx(source.drag_threshold_pixels, 2.0) and is_equal_approx(float(source.get("_effective_cancel_tolerance_pixels")), 12.0), "150% drag sensitivity lowers the start threshold and widens cancel tolerance")
	hold_release_count = 0
	source.hold_requested.connect(func(_source_ref: Dictionary) -> void: source.accept_hold())
	source.hold_released.connect(func(_source_ref: Dictionary) -> void: hold_release_count += 1)
	source.begin_gesture(Vector2.ZERO)
	source.advance_gesture(0.10)
	var ring := source.get_node("HoldProgress") as HoldProgressRing
	_check(ring.visible and is_equal_approx(ring.progress_ratio, 0.5), "long press exposes a circular percentage indicator before activation")
	source.advance_gesture(0.10)
	_check(source.is_hold_active(), "long press activates only after its visible progress reaches the threshold")
	source.call("_cancel_gesture_from_exit")
	_check(not source.is_hold_active() and not ring.visible and hold_release_count == 1, "moving away cancels an active hold and hides its unfinished progress")
	holder.queue_free()
	await process_frame


static func _task_index(tasks: Array, stock_id: StringName) -> int:
	for index in range(tasks.size()):
		if StringName(Dictionary(tasks[index]).get("id", &"")) == stock_id:
			return index
	return -1


static func _next_task_id(tasks: Array) -> StringName:
	for value in tasks:
		var task := Dictionary(value)
		if bool(task.get("is_next", false)):
			return StringName(task.get("id", &""))
	return &""


static func _next_task_count(tasks: Array) -> int:
	var result := 0
	for value in tasks:
		if bool(Dictionary(value).get("is_next", false)):
			result += 1
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("P1_PLAYER_FEEL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("P1_PLAYER_FEEL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
