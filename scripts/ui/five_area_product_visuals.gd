class_name FiveAreaProductVisuals
extends RefCounted

const PRODUCT_TEXTURES := {
	&"product.pancake.custom": preload("res://resources/art/workstation/packaging/serving_tray_package_v1_five_area_v2.png"),
	&"product.packaged_drink.milk": preload("res://resources/art/products/packaged_drink/milk_package_five_area_v2.png"),
	&"product.packaged_drink.soy_milk": preload("res://resources/art/products/packaged_drink/soy_milk_package_five_area_v2.png"),
	&"product.packaged_drink.walnut": preload("res://resources/art/products/packaged_drink/walnut_package_five_area_v2.png"),
	&"product.packaged_drink.black_sesame": preload("res://resources/art/products/packaged_drink/black_sesame_package_five_area_v2.png"),
	&"product.youtiao.plain": preload("res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v2.png"),
	&"product.youtiao.oil_cake": preload("res://resources/art/products/youtiao/oil_cake_five_area_v2.png"),
	&"product.youtiao.sugar_oil_cake": preload("res://resources/art/products/youtiao/sugar_oil_cake_five_area_v2.png"),
	&"product.fresh_soy_milk.yellow_bean": preload("res://resources/art/products/soy_milk/soy_milk_cup_yellow_bean_v3.png"),
	&"product.fresh_soy_milk.black_bean": preload("res://resources/art/products/soy_milk/soy_milk_cup_black_bean_v3.png"),
	&"product.fresh_soy_milk.red_bean": preload("res://resources/art/products/soy_milk/soy_milk_cup_red_bean_v3.png"),
	&"product.fresh_soy_milk.multigrain": preload("res://resources/art/products/soy_milk/soy_milk_cup_multigrain_v3.png"),
	&"product.steamer.mantou": preload("res://resources/art/products/steamer/mantou_cooked_five_area_v2.png"),
	&"product.steamer.vegetable_bun": preload("res://resources/art/products/steamer/vegetable_bun_cooked_five_area_v2.png"),
	&"product.steamer.meat_bun": preload("res://resources/art/products/steamer/meat_bun_cooked_five_area_v2.png"),
}

const HEATED_DRINK_TEXTURES := {
	&"product.packaged_drink.milk": preload("res://resources/art/products/packaged_drink/milk_heated_five_area_v2.png"),
	&"product.packaged_drink.soy_milk": preload("res://resources/art/products/packaged_drink/soy_milk_heated_five_area_v2.png"),
	&"product.packaged_drink.walnut": preload("res://resources/art/products/packaged_drink/walnut_heated_five_area_v2.png"),
	&"product.packaged_drink.black_sesame": preload("res://resources/art/products/packaged_drink/black_sesame_heated_five_area_v2.png"),
}


static func texture_for(product_id: StringName, temperature_mode: StringName = &"room_temperature") -> Texture2D:
	if temperature_mode == &"heated" and HEATED_DRINK_TEXTURES.has(product_id):
		return HEATED_DRINK_TEXTURES[product_id]
	return PRODUCT_TEXTURES.get(product_id) as Texture2D

