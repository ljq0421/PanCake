class_name FiveAreaProductVisuals
extends RefCounted

const PRODUCT_TEXTURES := {
	&"product.pancake.custom": preload("res://resources/art/workstation/packaging/serving_tray_package_v1_five_area_v2.png"),
	&"product.youtiao.plain": preload("res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v3.png"),
	&"product.fresh_soy_milk.yellow_bean": preload("res://resources/art/products/soy_milk/soy_milk_cup_yellow_bean_v3.png"),
	&"product.fresh_soy_milk.black_bean": preload("res://resources/art/products/soy_milk/soy_milk_cup_black_bean_v3.png"),
	&"product.fresh_soy_milk.red_bean": preload("res://resources/art/products/soy_milk/soy_milk_cup_red_bean_v3.png"),
	&"product.fresh_soy_milk.multigrain": preload("res://resources/art/products/soy_milk/soy_milk_cup_multigrain_v3.png"),
}

static func texture_for(product_id: StringName, temperature_mode: StringName = &"room_temperature") -> Texture2D:
	return PRODUCT_TEXTURES.get(product_id) as Texture2D
