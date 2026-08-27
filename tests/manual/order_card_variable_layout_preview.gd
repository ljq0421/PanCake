extends SceneTree

const SLOT_SCENE := preload("res://scenes/gameplay/customer_service_slot.tscn")
const MILK_TEXTURE := preload("res://resources/art/products/milk/boxed_milk_v2.png")
const YOUTIAO_TEXTURE := preload("res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v3.png")
const SOY_TEXTURE := preload("res://resources/art/products/soy_milk/yellow_soy_milk_cup_filled_v1.png")
const EGG_TEXTURE := preload("res://resources/art/ingredients/egg/egg_whole_v1.png")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(800, 600))
	var backdrop := ColorRect.new()
	backdrop.color = Color("f7f1e6")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var slot := SLOT_SCENE.instantiate() as CustomerServiceSlot
	slot.position = Vector2(90.0, 70.0)
	root.add_child(slot)
	await process_frame
	var pancake_requirements: Array = []
	for _index in 9:
		pancake_requirements.append({"texture": EGG_TEXTURE, "display_name": "鸡蛋"})
	slot.bind_order({
		"order_id": &"preview.order.0261",
		"patience_seconds": 60.0,
		"remaining_patience_seconds": 39.0,
		"items": [
			{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 1, "prepared_product_instance_ids": []},
			{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "prepared_product_instance_ids": []},
			{"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "prepared_product_instance_ids": []},
			{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "prepared_product_instance_ids": []},
	],
	}, null, [MILK_TEXTURE, YOUTIAO_TEXTURE, SOY_TEXTURE, YOUTIAO_TEXTURE], [[], [], [], pancake_requirements], 17)
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tmp/validation/order_card_variable_layout_preview.png"))
	quit(0)
