extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame

	workstation.call("_show_formal_payment_coins", 22)
	var coins := _valid_payment_coins(workstation)
	_check(coins.size() == 2, "22 coins uses the two authored denomination sprites")
	if coins.size() == 2:
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
