extends SceneTree

const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const CUSTOMER_SERVICE_SLOT_SCENE := preload("res://scenes/gameplay/customer_service_slot.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var soy_texture := PRODUCT_VISUALS.texture_for(&"product.fresh_soy_milk.yellow_bean")
	if soy_texture == null:
		_fail("yellow-soy milk owns a customer-order product texture")
		return
	if not soy_texture is AtlasTexture:
		_fail("yellow-soy milk order texture uses a tightly cropped atlas")
		return
	var atlas_texture := soy_texture as AtlasTexture
	if atlas_texture.atlas == null or not atlas_texture.atlas.resource_path.ends_with("yellow_soy_milk_cup_filled_v1.png"):
		_fail("yellow-soy milk atlas points to the filled-cup artwork")
		return
	if atlas_texture.region != Rect2(256.0, 1079.0, 435.0, 498.0):
		_fail("yellow-soy milk atlas keeps the verified opaque bounds")
		return
	var slot := CUSTOMER_SERVICE_SLOT_SCENE.instantiate()
	root.add_child(slot)
	await process_frame
	slot.call(
		"bind_order",
		{
			"order_id": &"yellow-soy-order",
			"items": [{"product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1}],
			"patience_seconds": 30.0,
			"remaining_patience_seconds": 30.0,
		},
		null,
		[soy_texture],
		[[]],
		7,
	)
	var item_icon := slot.get_node("%ItemIcon1") as TextureRect
	if item_icon == null or not item_icon.visible or item_icon.texture != soy_texture:
		_fail("the live customer order card renders the filled yellow-soy cup")
		return
	if item_icon.scale != Vector2(0.72, 0.72) or item_icon.pivot_offset != item_icon.size * 0.5:
		_fail("the live customer order card renders the yellow-soy cup at the reduced centered scale")
		return
	var ordinary_order := {
		"order_id": &"ordinary-order",
		"items": [{"product_id": &"product.youtiao.plain", "quantity": 1}],
		"patience_seconds": 30.0,
		"remaining_patience_seconds": 30.0,
	}
	slot.call("bind_order", ordinary_order, null, [soy_texture], [[]], 7)
	if item_icon.scale != Vector2.ONE:
		_fail("rebinding an ordinary product restores the customer-order icon scale")
		return
	slot.queue_free()
	print("FIVE_AREA_PRODUCT_VISUALS_SELF_CHECK_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL: %s" % message)
	quit(1)
