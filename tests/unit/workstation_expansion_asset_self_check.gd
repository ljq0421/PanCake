extends SceneTree

const EXPECTED := {
	"res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_v1.png": Vector2i(1024, 512),
	"res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_v1.png": Vector2i(1024, 512),
	"res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_3_v1.png": Vector2i(1024, 512),
	"res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_v1.png": Vector2i(1024, 384),
	"res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_v1.png": Vector2i(1024, 384),
	"res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_3_v1.png": Vector2i(1024, 384),
	"res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_1_v1.png": Vector2i(1024, 512),
	"res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_2_v1.png": Vector2i(1024, 512),
	"res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_3_v1.png": Vector2i(1024, 512),
	"res://resources/art/workstation/expansion/tools/single_press_spreader_v1.png": Vector2i(1024, 1024),
	"res://resources/art/workstation/expansion/tools/automatic_sauce_brush_v1.png": Vector2i(1024, 1024),
	"res://resources/art/workstation/expansion/trays/ingredient_tray_4x3_v1.png": Vector2i(512, 240),
	"res://resources/art/workstation/expansion/trays/ingredient_slot_locked_cover_v1.png": Vector2i(512, 512),
	"res://resources/art/workstation/expansion/bins/small_ingredient_box_tier_1_v1.png": Vector2i(512, 512),
	"res://resources/art/workstation/expansion/bins/small_ingredient_box_tier_2_v1.png": Vector2i(512, 512),
	"res://resources/art/workstation/expansion/bins/small_ingredient_box_tier_3_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/soybean/yellow_soybean_portion_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/beans/red_bean_portion_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/beans/black_bean_portion_v1.png": Vector2i(512, 512),
	"res://resources/art/products/soy_milk/plain_soy_milk_cup_v1.png": Vector2i(512, 512),
	"res://resources/art/products/soy_milk/red_bean_soy_milk_cup_v1.png": Vector2i(512, 512),
	"res://resources/art/products/soy_milk/black_bean_soy_milk_cup_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/youtiao/plain_youtiao_dough_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/youtiao/sesame_youtiao_dough_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/youtiao/scallion_youtiao_dough_v1.png": Vector2i(512, 512),
	"res://resources/art/products/youtiao/plain_youtiao_v1.png": Vector2i(512, 512),
	"res://resources/art/products/youtiao/sesame_youtiao_v1.png": Vector2i(512, 512),
	"res://resources/art/products/youtiao/scallion_youtiao_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/egg_waffle/plain_egg_waffle_batter_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/sauces/strawberry_sauce_bottle_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/sauces/chocolate_sauce_bottle_v1.png": Vector2i(512, 512),
	"res://resources/art/products/egg_waffle/plain_egg_waffle_v1.png": Vector2i(512, 512),
	"res://resources/art/products/egg_waffle/strawberry_egg_waffle_v1.png": Vector2i(512, 512),
	"res://resources/art/products/egg_waffle/chocolate_egg_waffle_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/nuts/peanut_portion_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/beans/mung_bean_portion_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/grains/five_grain_mix_portion_v1.png": Vector2i(512, 512),
	"res://resources/art/products/soy_milk/peanut_soy_milk_cup_v1.png": Vector2i(512, 512),
	"res://resources/art/products/soy_milk/mung_bean_soy_milk_cup_v1.png": Vector2i(512, 512),
	"res://resources/art/products/soy_milk/five_grain_soy_milk_cup_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/youtiao/glutinous_rice_youtiao_dough_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/youtiao/multigrain_youtiao_dough_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/youtiao/filled_youtiao_dough_v1.png": Vector2i(512, 512),
	"res://resources/art/products/youtiao/glutinous_rice_youtiao_v1.png": Vector2i(512, 512),
	"res://resources/art/products/youtiao/multigrain_youtiao_v1.png": Vector2i(512, 512),
	"res://resources/art/products/youtiao/filled_youtiao_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/egg_waffle/matcha_egg_waffle_batter_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/egg_waffle/sesame_topping_portion_v1.png": Vector2i(512, 512),
	"res://resources/art/ingredients/egg_waffle/dried_fruit_topping_portion_v1.png": Vector2i(512, 512),
	"res://resources/art/products/egg_waffle/matcha_egg_waffle_v1.png": Vector2i(512, 512),
	"res://resources/art/products/egg_waffle/sesame_egg_waffle_v1.png": Vector2i(512, 512),
	"res://resources/art/products/egg_waffle/dried_fruit_egg_waffle_v1.png": Vector2i(512, 512),
}


func _initialize() -> void:
	for path: String in EXPECTED:
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("WORKSTATION EXPANSION ASSET SELF-CHECK FAIL: cannot load %s" % path)
			quit(1)
			return
		if texture.get_size() != Vector2(EXPECTED[path]):
			push_error("WORKSTATION EXPANSION ASSET SELF-CHECK FAIL: %s size %s expected %s" % [path, texture.get_size(), EXPECTED[path]])
			quit(1)
			return
	print("WORKSTATION EXPANSION ASSET SELF-CHECK PASS: %d textures" % EXPECTED.size())
	quit(0)
