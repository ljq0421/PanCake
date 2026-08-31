extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const PANCAKE_ITEM := {
	"area_id": &"area.pancake",
	"product_id": &"product.pancake.custom",
	"quantity": 1,
	"ingredient_ids": [
		&"stock.pancake.egg",
		&"stock.pancake.baocui",
		&"stock.pancake.scallion",
	],
}
const SINGLE_SAUCE_PANCAKE_ITEM := {
	"area_id": &"area.pancake",
	"product_id": &"product.pancake.custom",
	"quantity": 1,
	"ingredient_ids": [&"stock.pancake.egg"],
	"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
}
const DOUBLE_SAUCE_PANCAKE_ITEM := {
	"area_id": &"area.pancake",
	"product_id": &"product.pancake.custom",
	"quantity": 1,
	"ingredient_ids": [&"stock.pancake.egg"],
	"sauce_ids": [
		&"stock.pancake.sauce.sweet_flour",
		&"stock.pancake.sauce.red_chili",
	],
}
const DOUBLE_PORTION_PANCAKE_ITEM := {
	"area_id": &"area.pancake",
	"product_id": &"product.pancake.custom",
	"quantity": 1,
	"ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.egg", &"stock.pancake.meat_floss", &"stock.pancake.meat_floss"],
	"sauce_ids": [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.sweet_flour"],
}
const HEATED_SOY_ITEM := {
	"area_id": &"area.packaged_drink",
	"product_id": &"product.packaged_drink.soy_milk",
	"quantity": 1,
	"temperature_mode": &"heated",
	"ingredient_ids": [],
}
const ROOM_TEMPERATURE_SOY_ITEM := {
	"area_id": &"area.packaged_drink",
	"product_id": &"product.packaged_drink.soy_milk",
	"quantity": 1,
	"temperature_mode": &"room_temperature",
	"ingredient_ids": [],
}
const MULTI_SUGAR_SOY_ITEM := {
	"area_id": &"area.fresh_soy_milk",
	"product_id": &"product.fresh_soy_milk.yellow_bean",
	"quantity": 1,
	"temperature_mode": &"room_temperature",
	"sugar_servings": 2,
}
const NORMAL_SUGAR_SOY_ITEM := {
	"area_id": &"area.fresh_soy_milk",
	"product_id": &"product.fresh_soy_milk.yellow_bean",
	"quantity": 1,
	"temperature_mode": &"room_temperature",
	"sugar_servings": 1,
}
const NO_SUGAR_SOY_ITEM := {
	"area_id": &"area.fresh_soy_milk",
	"product_id": &"product.fresh_soy_milk.yellow_bean",
	"quantity": 1,
	"temperature_mode": &"room_temperature",
	"sugar_servings": 0,
}
const EXPECTED_INGREDIENT_TEXTURE_SUFFIXES := [
	"egg_whole_v1.png",
	"baocui_broken_v1.png",
	"scallion_scattered_v1.png",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for order-card requirement rendering")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame

	workstation.call("_refresh_order_card_ui", {"items": [PANCAKE_ITEM]}, 1.0)
	_assert_pancake_prefix(workstation)
	for slot_index in range(3, 8):
		_assert_empty_slot(workstation, slot_index, "classic pancake leaves later requirement slots empty")

	workstation.call("_refresh_order_card_ui", {"items": [SINGLE_SAUCE_PANCAKE_ITEM]}, 1.0)
	_assert_texture(workstation, 0, "egg_whole_v1.png", "single-sauce order keeps topping first")
	_assert_texture(workstation, 1, "sweet-bean-sauce-jar-no-brush.png", "single-sauce order shows the sweet-bean sauce jar")
	_check(_icon(workstation, 1).tooltip_text == "甜面酱", "sweet flour sauce requirement has a distinct name")

	workstation.call("_refresh_order_card_ui", {"items": [DOUBLE_PORTION_PANCAKE_ITEM]}, 1.0)
	_assert_texture(workstation, 0, "egg_whole_v1.png", "double-portion order shows the first egg")
	_assert_texture(workstation, 1, "egg_whole_v1.png", "double-portion order visibly repeats the egg")
	_check(_icon(workstation, 0).tooltip_text == "鸡蛋×2" and _icon(workstation, 1).tooltip_text == "鸡蛋×2", "double ingredient tooltip states the required quantity")
	_assert_texture(workstation, 4, "sweet-bean-sauce-jar-no-brush.png", "double-portion order shows the first sweet-bean sauce jar")
	_assert_texture(workstation, 5, "sweet-bean-sauce-jar-no-brush.png", "double-portion order visibly repeats the sweet-bean sauce jar")
	_check(_icon(workstation, 4).tooltip_text == "甜面酱×2" and _icon(workstation, 5).tooltip_text == "甜面酱×2", "double sauce tooltip states the required quantity")

	workstation.call("_refresh_order_card_ui", {"items": [HEATED_SOY_ITEM, DOUBLE_SAUCE_PANCAKE_ITEM]}, 1.0)
	_assert_texture(workstation, 0, "egg_whole_v1.png", "double-sauce order keeps topping first")
	_assert_texture(workstation, 1, "sweet-bean-sauce-jar-no-brush.png", "double-sauce order shows the sweet-bean sauce jar")
	_assert_texture(workstation, 2, "chili-sauce-jar-no-brush.png", "double-sauce order shows the chili sauce jar")
	_check(_icon(workstation, 2).tooltip_text == "辣椒酱", "chili sauce requirement has a distinct name")
	_assert_texture(workstation, 3, "quality_heat_requirement_v2_chinese_ui.png", "heating marker follows toppings and sauces")

	# Reverse item order on purpose: pancake ingredients must still render first.
	workstation.call("_refresh_order_card_ui", {"items": [HEATED_SOY_ITEM, PANCAKE_ITEM]}, 1.0)
	_assert_pancake_prefix(workstation)
	var heat_icon := _icon(workstation, 3)
	var heat_background := _heat_background(workstation, 3)
	var ingredient_background := _ingredient_background(workstation, 3)
	_check(
		heat_icon.visible
		and heat_icon.texture != null
		and heat_icon.texture.resource_path.ends_with("quality_heat_requirement_v2_chinese_ui.png"),
		"heated packaged drink appends the generic heat marker in row-major slot 4",
	)
	_check(heat_background.visible and not ingredient_background.visible, "heated requirement owns the distinct warm background in slot 4")
	for slot_index in range(4, 8):
		_assert_empty_slot(workstation, slot_index, "heated two-item order leaves unused requirement slots empty")

	workstation.call("_refresh_order_card_ui", {"items": [PANCAKE_ITEM, ROOM_TEMPERATURE_SOY_ITEM]}, 1.0)
	_assert_pancake_prefix(workstation)
	_assert_empty_slot(workstation, 3, "room-temperature packaged drink omits the heat marker and clears stale styling")
	for slot_index in range(4, 8):
		_assert_empty_slot(workstation, slot_index, "room-temperature two-item order leaves later requirement slots empty")

	var soy_requirements_by_item := Array(workstation.call("_order_requirements_by_item_for_customer_card", {"items": [MULTI_SUGAR_SOY_ITEM]}))
	var soy_requirements := Array(soy_requirements_by_item.front()) if not soy_requirements_by_item.is_empty() else []
	_check(
		soy_requirements.size() == 2
		and StringName(Dictionary(soy_requirements[0]).get("kind", &"")) == &"sugar"
		and StringName(Dictionary(soy_requirements[1]).get("kind", &"")) == &"sugar",
		"fresh soy order exposes one sugar-jar icon for each requested sugar serving",
	)
	var normal_sugar_requirements_by_item := Array(workstation.call("_order_requirements_by_item_for_customer_card", {"items": [NORMAL_SUGAR_SOY_ITEM]}))
	var normal_sugar_requirements := Array(normal_sugar_requirements_by_item.front()) if not normal_sugar_requirements_by_item.is_empty() else []
	var no_sugar_requirements_by_item := Array(workstation.call("_order_requirements_by_item_for_customer_card", {"items": [NO_SUGAR_SOY_ITEM]}))
	var no_sugar_requirements := Array(no_sugar_requirements_by_item.front()) if not no_sugar_requirements_by_item.is_empty() else []
	_check(
		normal_sugar_requirements.size() == 1
		and StringName(Dictionary(normal_sugar_requirements[0]).get("kind", &"")) == &"sugar"
		and no_sugar_requirements.is_empty(),
		"fresh soy card uses zero, one, or two sugar-jar icons to represent the requested sugar servings",
	)

	workstation.queue_free()
	_finish()


func _assert_pancake_prefix(workstation: Node) -> void:
	for slot_index in EXPECTED_INGREDIENT_TEXTURE_SUFFIXES.size():
		var icon := _icon(workstation, slot_index)
		_check(
			icon.visible
			and icon.texture != null
			and icon.texture.resource_path.ends_with(EXPECTED_INGREDIENT_TEXTURE_SUFFIXES[slot_index]),
			"pancake ingredient %d keeps catalog order in row-major slot %d" % [slot_index + 1, slot_index + 1],
		)
		_check(
			not _ingredient_background(workstation, slot_index).visible
			and not _heat_background(workstation, slot_index).visible,
			"pancake ingredient slot %d uses only the authored order-card cell without a second background" % (slot_index + 1),
		)


func _assert_texture(workstation: Node, slot_index: int, suffix: String, message: String) -> void:
	var icon := _icon(workstation, slot_index)
	_check(icon.visible and icon.texture != null and icon.texture.resource_path.ends_with(suffix), message)


func _assert_empty_slot(workstation: Node, slot_index: int, message: String) -> void:
	var icon := _icon(workstation, slot_index)
	_check(
		not icon.visible
		and icon.texture == null
		and not _ingredient_background(workstation, slot_index).visible
		and not _heat_background(workstation, slot_index).visible,
		message + " (%d)" % (slot_index + 1),
	)


func _icon(workstation: Node, slot_index: int) -> TextureRect:
	return workstation.get_node("SafeArea/OrderCard/OrderIngredient%02d" % (slot_index + 1)) as TextureRect


func _ingredient_background(workstation: Node, slot_index: int) -> Panel:
	return workstation.get_node("SafeArea/OrderCard/OrderIngredientBackground%02d" % (slot_index + 1)) as Panel


func _heat_background(workstation: Node, slot_index: int) -> Panel:
	return workstation.get_node("SafeArea/OrderCard/OrderHeatBackground%02d" % (slot_index + 1)) as Panel


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ORDER_CARD_REQUIREMENTS_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("ORDER_CARD_REQUIREMENTS_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
