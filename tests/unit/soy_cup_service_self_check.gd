extends SceneTree

const MODEL := preload("res://scripts/gameplay/fresh_soy_milk_machine_model.gd")
const ORDERS := preload("res://scripts/services/five_area_order_service.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	var machine: RefCounted = MODEL.new(0, true)
	machine.call("configure_upgrades", false, false, true)
	_check(bool(machine.call("take_empty_cup").get("success", false)), "player can take an empty soy cup")
	var partial := Dictionary(machine.call("fill_held_cup", 0.2))
	var partial_cup := Dictionary(partial.get("cup", {}))
	_check(float(partial.get("fill_ratio", 1.0)) < 1.0 and float(partial_cup.get("quality_multiplier", 1.0)) < 1.0, "early release creates a partial cup with reduced payout")
	_check(bool(machine.call("add_sugar").get("success", false)) and bool(machine.call("add_sugar").get("success", false)), "filled cup accepts one or two sugar servings")
	_check(StringName(machine.call("add_sugar").get("reason", &"")) == &"sugar_limit_reached", "a cup cannot exceed two sugar servings")
	var two_sugar := Dictionary(machine.call("preview_cup").get("product", {}))
	_check(int(two_sugar.get("sugar_servings", 0)) == 2, "cup preserves the multi-sugar selection")
	_check(bool(machine.call("take_filled_cup").get("success", false)) and StringName(machine.call("snapshot").get("cup_state", &"")) == &"ready", "delivery collection clears the serving position")

	var full_machine: RefCounted = MODEL.new(0, true)
	full_machine.call("take_empty_cup")
	var full := Dictionary(full_machine.call("fill_held_cup", 0.8))
	_check(bool(full.get("is_full", false)) and is_equal_approx(float(full.get("fill_ratio", 0.0)), 1.0), "holding the spout for 0.8 seconds fills the cup")
	full_machine.call("configure_upgrades", false, false, false, true)
	_check(bool(full_machine.call("add_ice").get("success", false)), "filled soy cup can be iced after the ice-box upgrade")
	_check(StringName(Dictionary(full_machine.call("preview_cup").get("product", {})).get("temperature_mode", &"")) == &"iced", "iced soy cup preserves its temperature for delivery")
	_check(StringName(full_machine.call("add_ice").get("reason", &"")) == &"ice_already_added", "a soy cup cannot receive ice twice")

	var assisted_machine: RefCounted = MODEL.new(0, true)
	assisted_machine.call("configure_upgrades", true, false, true)
	assisted_machine.call("take_empty_cup")
	var assisted_cup := Dictionary(assisted_machine.call("fill_held_cup", 0.1).get("cup", {}))
	_check(is_equal_approx(float(assisted_cup.get("fill_ratio", 0.0)), 0.125) and float(assisted_cup.get("quality", 0.0)) < 100.0, "fill guide keeps a manual release at its exact pour level")

	var advanced_machine: RefCounted = MODEL.new(0, true)
	advanced_machine.call("configure_upgrades", false, true, false, false, true)
	var first_advanced_cup := Dictionary(advanced_machine.call("take_empty_cup"))
	var second_advanced_cup := Dictionary(advanced_machine.call("take_empty_cup"))
	_check(int(first_advanced_cup.get("held_empty_cup_count", 0)) == 1 and int(second_advanced_cup.get("held_empty_cup_count", 0)) == 2, "advanced soy machine places one empty cup per take action")
	var double_fill := Dictionary(advanced_machine.call("fill_held_cup", 0.1, 2))
	_check(int(double_fill.get("quantity", 0)) == 2 and int(Dictionary(advanced_machine.call("snapshot")).get("ready_cup_count", 0)) == 2, "advanced soy machine fills the two placed cups from one automatic press")
	advanced_machine.call("take_filled_cup")
	var after_left_delivery := Dictionary(advanced_machine.call("snapshot"))
	_check(StringName(after_left_delivery.get("cup_state", &"")) == &"filled" and int(after_left_delivery.get("ready_cup_count", 0)) == 1 and Dictionary(after_left_delivery.get("cup", {})).is_empty() and not Array(after_left_delivery.get("queued_cups", [])).is_empty(), "delivering the left cup keeps the right cup in its own outlet")
	var restored_right_cup_machine: RefCounted = MODEL.new()
	restored_right_cup_machine.call("load_snapshot", after_left_delivery)
	_check(bool(restored_right_cup_machine.call("preview_cup", 1).get("success", false)), "a saved right-side cup restores in the right outlet")
	_check(bool(advanced_machine.call("preview_cup", 1).get("success", false)) and bool(advanced_machine.call("take_filled_cup", 1).get("success", false)) and StringName(Dictionary(advanced_machine.call("snapshot")).get("cup_state", &"")) == &"ready", "the right cup remains deliverable from the right outlet")

	var selectable_machine: RefCounted = MODEL.new(0, true)
	selectable_machine.call("configure_upgrades", false, true, true, true, true)
	selectable_machine.call("take_empty_cup")
	selectable_machine.call("take_empty_cup")
	selectable_machine.call("fill_held_cup", 0.1, 2)
	_check(bool(selectable_machine.call("add_sugar", 1).get("success", false)) and bool(selectable_machine.call("add_ice", 1).get("success", false)), "selected queued cup accepts sugar and ice")
	var selectable_snapshot := Dictionary(selectable_machine.call("snapshot"))
	var active_cup := Dictionary(selectable_snapshot.get("cup", {}))
	var queued_cup := Dictionary(Array(selectable_snapshot.get("queued_cups", [])).front())
	_check(int(active_cup.get("sugar_servings", 0)) == 0 and StringName(active_cup.get("temperature_mode", &"")) == &"room_temperature", "adding to the queued cup leaves the active cup unchanged")
	_check(int(queued_cup.get("sugar_servings", 0)) == 1 and StringName(queued_cup.get("temperature_mode", &"")) == &"iced", "selected queued cup retains its own sugar and ice state")
	var queued_preview := Dictionary(selectable_machine.call("preview_cup", 1).get("product", {}))
	_check(int(queued_preview.get("sugar_servings", 0)) == 1 and StringName(queued_preview.get("temperature_mode", &"")) == &"iced", "previewing the selected queued cup keeps its sugar and ice requirements")
	var queued_taken := Dictionary(selectable_machine.call("take_filled_cup", 1))
	var after_queued_take := Dictionary(selectable_machine.call("snapshot"))
	_check(bool(queued_taken.get("success", false)) and int(Dictionary(queued_taken.get("product", {})).get("sugar_servings", 0)) == 1 and int(after_queued_take.get("ready_cup_count", 0)) == 1 and int(Dictionary(after_queued_take.get("cup", {})).get("sugar_servings", 0)) == 0, "collecting the selected queued cup preserves the unselected active cup")

	var orders: RefCounted = ORDERS.new()
	var opened := Dictionary(orders.call("open_order", [{
		"area_id": &"area.fresh_soy_milk",
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"sugar_servings": 1,
	}]))
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	var wrong_sweetness := {"product_instance_id": &"soy.wrong", "product_id": &"product.fresh_soy_milk.yellow_bean", "sugar_servings": 0}
	var normal_sugar := {"product_instance_id": &"soy.right", "product_id": &"product.fresh_soy_milk.yellow_bean", "sugar_servings": 1}
	_check(PackedStringArray(orders.call("preview_attach_product", order_id, 0, wrong_sweetness).get("mismatch_reasons", [])).has("sugar_servings"), "wrong sweetness is an order mismatch")
	_check(bool(orders.call("preview_attach_product", order_id, 0, normal_sugar).get("will_match", false)), "matching sweetness is accepted")
	var iced_opened := Dictionary(orders.call("open_order", [{
		"area_id": &"area.fresh_soy_milk",
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"temperature_mode": &"iced",
	}]))
	var iced_order_id := StringName(Dictionary(iced_opened.get("order", {})).get("order_id", &""))
	var room_temperature_cup := {"product_instance_id": &"soy.room", "product_id": &"product.fresh_soy_milk.yellow_bean", "temperature_mode": &"room_temperature"}
	var iced_cup := {"product_instance_id": &"soy.iced", "product_id": &"product.fresh_soy_milk.yellow_bean", "temperature_mode": &"iced"}
	_check(PackedStringArray(orders.call("preview_attach_product", iced_order_id, 0, room_temperature_cup).get("mismatch_reasons", [])).has("temperature_mode"), "room-temperature soy milk does not satisfy an iced order")
	_check(bool(orders.call("preview_attach_product", iced_order_id, 0, iced_cup).get("will_match", false)), "iced soy milk satisfies an iced order")

	if failures.is_empty():
		print("SOY_CUP_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
