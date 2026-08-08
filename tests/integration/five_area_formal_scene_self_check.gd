extends SceneTree

const SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	_check(workstation is Workstation, "formal five-area scene preserves the playable pancake controller contract")
	var material_dock := workstation.get_node_or_null("SafeArea/MaterialDock")
	_check(material_dock != null and material_dock.get_child_count() == 18, "formal five-area scene keeps eighteen fixed material slots")
	var infrastructure := workstation.get_node_or_null("FiveAreaInfrastructure")
	_check(infrastructure != null and infrastructure.mouse_filter == Control.MOUSE_FILTER_IGNORE, "formal infrastructure cannot steal pointer input while hidden")
	var stations := workstation.get_node_or_null("FiveAreaInfrastructure/Stations")
	_check(stations != null and stations.get_child_count() == 5 and stations.mouse_filter == Control.MOUSE_FILTER_IGNORE, "formal scene owns five stable station roots without covering the pancake controls")
	var queue := workstation.get_node_or_null("FiveAreaInfrastructure/OrderQueue")
	_check(queue != null and queue.get_child_count() == 4, "formal scene owns four stable order cards")
	var queue_copy_is_player_facing := true
	for card in queue.get_children():
		var summary := card.get_node("Summary") as Label
		queue_copy_is_player_facing = queue_copy_is_player_facing and not "订单位" in summary.text and not "single" in summary.text and not "double" in summary.text and not "triple" in summary.text
	_check(queue_copy_is_player_facing, "formal order cards contain no internal complexity or empty-slot placeholder copy")
	_check(workstation.get_node_or_null("SafeArea/PatienceTextLabel") != null, "formal workstation owns a stable numeric patience label")
	var attention := workstation.get_node_or_null("FiveAreaInfrastructure/AttentionRail")
	_check(attention != null and attention.get_child_count() == 3, "formal scene owns three stable attention rows")
	var recommendations := workstation.get_node_or_null("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets")
	_check(recommendations != null and recommendations.get_child_count() == 6, "formal daily bill owns three install and three content recommendations")
	var soy := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation")
	var steamer := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/SteamerStation")
	_check(soy != null and soy.has_signal("intent_requested") and soy.has_method("apply_snapshot") and soy.has_method("set_locked") and soy.has_method("set_interaction_enabled"), "soy station exposes the standard intent and snapshot contract")
	_check(steamer != null and steamer.has_signal("intent_requested") and steamer.has_method("apply_snapshot") and steamer.has_method("set_locked") and steamer.has_method("set_interaction_enabled"), "steamer station exposes the standard intent and snapshot contract")
	_check(soy.get_node("Layout/OutputRack").get_child_count() == 4, "soy station prebuilds the maximum four output slots")
	_check(steamer.get_node("Layout/Layers").get_child_count() == 4, "steamer station prebuilds the maximum four independent layers")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FIVE_AREA_FORMAL_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_FORMAL_SCENE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
