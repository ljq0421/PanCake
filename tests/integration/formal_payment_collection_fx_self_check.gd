extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	var artwork := workstation.get_node_or_null("SafeArea/JianbingStallArtwork") as Control
	var worktop := artwork.get_node_or_null("PancakeWorktopHotspots") as Control if artwork != null else null
	var sauce_source := worktop.get_node_or_null("SecretSauceSource") as Control if worktop != null else null
	var sauce_visual := worktop.get_node_or_null("SecretSauceSource/Visual") as TextureRect if worktop != null else null
	var payment_tray := artwork.get_node_or_null("PaymentTray") as TextureRect if artwork != null else null
	_check(payment_tray != null and payment_tray.texture != null and payment_tray.texture.resource_path.ends_with("yinpin-v1.png"), "the workbench uses yinpin-v1 as its payment tray")
	_check(sauce_source != null and payment_tray != null and payment_tray.get_global_rect().position.x < sauce_source.get_global_rect().position.x, "the payment tray is positioned to the left of the sauce source")
	_check(sauce_visual != null and payment_tray != null and payment_tray.z_index == worktop.z_index + sauce_visual.z_index, "the payment tray shares the sauce tray's visual layer")
	if payment_tray != null:
		var coin_center: Vector2 = workstation.call("_formal_payment_coin_target", 0) + Vector2(22.0, 22.0)
		var coin_global_position: Vector2 = workstation.payment_coin_layer.get_global_transform() * coin_center
		_check(payment_tray.get_global_rect().grow(-40.0).has_point(coin_global_position), "new customer-payment coins are placed inside the payment tray")

	workstation.call("_show_formal_payment_coins", 22)
	var coins := _valid_payment_coins(workstation)
	_check(coins.size() == 2, "22 coins uses the two authored denomination sprites")
	var one_coin_size: Vector2 = workstation.call("_formal_payment_coin_size", 1)
	var two_coin_size: Vector2 = workstation.call("_formal_payment_coin_size", 2)
	var five_coin_size: Vector2 = workstation.call("_formal_payment_coin_size", 5)
	var ten_coin_size: Vector2 = workstation.call("_formal_payment_coin_size", 10)
	var twenty_coin_size: Vector2 = workstation.call("_formal_payment_coin_size", 20)
	_check(
		one_coin_size.x < two_coin_size.x
		and two_coin_size.x < five_coin_size.x
		and five_coin_size.x < ten_coin_size.x
		and ten_coin_size.x < twenty_coin_size.x,
		"payment coin sizes increase strictly with denomination"
	)
	if coins.size() == 2:
		_check(coins[0].size.x > coins[1].size.x, "the 20-value coin renders larger than the 2-value coin")
		_check(
			absf(coins[0].position.y - coins[1].position.y) > 1.0
			and not is_equal_approx(coins[0].rotation, coins[1].rotation),
			"payment coins use a scattered, individually tilted presentation instead of a rigid row"
		)
		_detach_live_payment_coins(workstation)
		var first_start := coins[0].global_position
		var second_start := coins[1].global_position
		workstation.call("_play_formal_payment_collection_feedback", 22, coins, false)
		await create_timer(0.075).timeout
		await process_frame
		_check(bool(workstation.get("_formal_payment_collection_active")), "collection remains active while coins are in flight")
		_check(_has_fx_kind(workstation.payment_coin_layer, &"origin_ring"), "collection starts with a visible origin burst ring")
		_check(_has_fx_kind(workstation.payment_coin_layer, &"origin_spark"), "full motion adds a radial gold spark burst")
		_check(_has_fx_kind(workstation.payment_coin_layer, &"reward_badge"), "collection displays a high-contrast reward badge")
		_check(coins[0].global_position.distance_to(first_start) > 0.5 or coins[0].scale.x > 1.0, "the first coin has a strong launch anticipation")
		_check(
			is_equal_approx(float(coins[0].get_meta(&"formal_payment_stagger_delay", -1.0)), 0.0)
			and is_equal_approx(float(coins[1].get_meta(&"formal_payment_stagger_delay", -1.0)), 0.05),
			"the two coins receive distinct real 50ms launch delays"
		)
		await create_timer(0.06).timeout
		_check(coins[1].global_position.distance_to(second_start) > 0.5, "the staggered second coin launches after the first")
		await create_timer(0.36).timeout
		_check(bool(workstation.get("_formal_payment_collection_active")), "collection stays locked through the final counter impact")
		_check(_has_fx_kind(workstation.payment_coin_layer, &"target_ring"), "coin arrival creates a visible counter impact")
		_check(not is_instance_valid(coins[0]) and not is_instance_valid(coins[1]), "all collected coin sprites are released after the final impact")
		await create_timer(0.28).timeout
		_check(not bool(workstation.get("_formal_payment_collection_active")), "collection unlocks after the complete impact tail")

	await create_timer(0.30).timeout
	workstation.call("_show_formal_payment_coins", 5)
	var reduced_coins := _valid_payment_coins(workstation)
	_check(reduced_coins.size() == 1, "reduced-motion fixture creates one authored coin")
	if reduced_coins.size() == 1:
		_detach_live_payment_coins(workstation)
		var reduced_coin := reduced_coins[0]
		var reduced_start := reduced_coin.global_position
		workstation.call("_play_formal_payment_collection_feedback", 5, reduced_coins, true)
		await create_timer(0.05).timeout
		_check(reduced_coin.global_position.distance_to(reduced_start) < 0.1, "reduced motion fades the coin in place without travel")
		_check(reduced_coin.scale.is_equal_approx(Vector2.ONE), "reduced motion does not scale the coin")
		_check(not _has_fx_kind(workstation.payment_coin_layer, &"origin_spark"), "reduced motion omits travelling burst sparks")
		var reduced_ring := _first_fx_kind(workstation.payment_coin_layer, &"origin_ring") as Control
		_check(reduced_ring != null and reduced_ring.scale.is_equal_approx(Vector2.ONE), "reduced motion keeps its confirmation ring stationary")
		await create_timer(0.38).timeout
		_check(not bool(workstation.get("_formal_payment_collection_active")) and not is_instance_valid(reduced_coin), "reduced-motion feedback still completes and cleans up")

	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for the day-end collection flow")
	if session != null:
		session.call("begin_new_game")
		var coins_before_day_end := int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0))
		var save_data := Dictionary(session.get("_save_data")).duplicate(true)
		save_data["pending_tray_payments"] = {
			"day.end.pending.payment": {
				"settlement_id": &"day.end.pending.payment",
				"order_id": &"day.end.order",
				"amount": 22,
				"collected": false,
				"created_at_unix": 1,
			},
		}
		session.set("_save_data", save_data)
		_check(Array(session.call("pending_order_payments")).size() == 1, "fixture creates a pending payment for day-end collection")
		workstation.call("_show_formal_payment_coins", 22)
		workstation.call("end_business_day_early_for_testing")
		await process_frame
		_check(
			bool(workstation.get("_formal_payment_collection_active"))
			and not workstation.daily_bill_panel.visible
			and Array(session.call("pending_order_payments")).is_empty(),
			"day end clears pending coins and starts their collection animation before the daily bill",
		)
		_check(
			int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) == coins_before_day_end + 22,
			"day-end collection credits the pending payment exactly once",
		)
		await create_timer(0.85).timeout
		_check(
			not bool(workstation.get("_formal_payment_collection_active")) and workstation.daily_bill_panel.visible,
			"daily bill opens only after the unified collection animation completes",
		)

	workstation.queue_free()
	await process_frame
	_finish()


func _valid_payment_coins(workstation: Node) -> Array[TextureRect]:
	var result: Array[TextureRect] = []
	for value in Array(workstation.get("_formal_payment_coin_sprites")):
		var coin := value as TextureRect
		if is_instance_valid(coin):
			result.append(coin)
	return result


func _detach_live_payment_coins(workstation: Node) -> void:
	var live_coins: Array = workstation.get("_formal_payment_coin_sprites")
	live_coins.clear()


func _has_fx_kind(layer: Control, kind: StringName) -> bool:
	return _first_fx_kind(layer, kind) != null


func _first_fx_kind(layer: Control, kind: StringName) -> Node:
	for child in layer.get_children():
		if child.has_meta(&"formal_payment_fx_kind") \
			and StringName(child.get_meta(&"formal_payment_fx_kind")) == kind:
			return child
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FORMAL_PAYMENT_COLLECTION_FX_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FORMAL_PAYMENT_COLLECTION_FX_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
