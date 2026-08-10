extends SceneTree

const MATERIAL_SLOT := preload("res://scripts/ui/five_area_material_slot.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var slot := MATERIAL_SLOT.new()
	slot.size = Vector2(89.0, 89.0)
	slot.stock_id = &"stock.youtiao.plain_dough"
	slot.recipe_id = &"recipe.youtiao.plain"
	slot.product_id = &"product.youtiao.plain"
	slot.source_kind = &"youtiao_dough"
	root.add_child(slot)
	await process_frame
	slot.apply_state(2, true, 6)
	var counts := {"drag": 0, "hold_request": 0, "hold_tick": 0, "short": 0}
	slot.drag_started.connect(func(_ref: Dictionary): counts["drag"] += 1)
	slot.hold_requested.connect(func(_ref: Dictionary): counts["hold_request"] += 1; slot.accept_hold())
	slot.hold_advanced.connect(func(_ref: Dictionary, _delta: float): counts["hold_tick"] += 1)
	slot.short_clicked.connect(func(_ref: Dictionary): counts["short"] += 1)

	slot.begin_gesture(Vector2.ZERO)
	slot.update_gesture(Vector2(10.1, 0.0), false)
	slot.advance_gesture(0.3)
	_check(int(counts["drag"]) == 1 and int(counts["hold_request"]) == 0 and int(counts["hold_tick"]) == 0, "movement beyond 10px starts drag and never enters paid hold")

	slot.begin_gesture(Vector2.ZERO)
	slot.advance_gesture(0.19)
	_check(int(counts["hold_request"]) == 0, "hold does not start before 0.2 seconds")
	slot.advance_gesture(0.01)
	slot.advance_gesture(0.05)
	_check(int(counts["hold_request"]) == 1 and int(counts["hold_tick"]) == 1, "stationary 0.2-second hold advances restocking")
	slot.end_gesture()

	slot.begin_gesture(Vector2.ZERO)
	slot.end_gesture()
	_check(int(counts["short"]) == 1, "a hold-capable dough slot still emits short click for auto-loader recipe selection")
	slot.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FIVE_AREA_MATERIAL_SLOT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_MATERIAL_SLOT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
