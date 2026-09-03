class_name CartoonBreakfastProcessOverlay
extends Control

var pancake_mode: StringName = &"idle"
var pancake_ingredients: PackedStringArray = PackedStringArray()
var fryer_state: StringName = &"idle"
var fryer_quantity := 0
var drinks_unlocked := false
var payment_coin_centers := PackedVector2Array()


func update_presentation(pancake: Dictionary, fryer: Dictionary, show_drinks: bool, coin_centers: PackedVector2Array = PackedVector2Array()) -> void:
	pancake_mode = StringName(pancake.get("mode", &"idle"))
	pancake_ingredients = PackedStringArray(pancake.get("ingredient_ids", PackedStringArray()))
	fryer_state = StringName(fryer.get("state", &"idle"))
	fryer_quantity = maxi(int(fryer.get("quantity", 0)), 0)
	drinks_unlocked = show_drinks
	payment_coin_centers = coin_centers
	queue_redraw()


func _draw() -> void:
	_draw_pancake_overlays()
	_draw_partial_youtiao()
	_draw_boxed_juice()
	_draw_payment_coins()


func _draw_pancake_overlays() -> void:
	# The live pancake body comes from PancakeHeatmap/PancakeModel. Keep only
	# lightweight garnish and packaging fallbacks that do not replace its shape.
	if pancake_mode in [&"garnish", &"folding"]:
		var center := Vector2(720.0, 740.0)
		var colors := [Color("f6edd1"), Color("d89a37"), Color("73a64b"), Color("d97155"), Color("a86f43")]
		for index in pancake_ingredients.size():
			var angle := float(index) * 1.71 - 1.1
			var position := center + Vector2(cos(angle) * (48.0 + 13.0 * (index % 3)), sin(angle) * 36.0)
			draw_circle(position, 12.0, colors[index % colors.size()])
	if pancake_mode == &"ready":
		var parcel := Rect2(Vector2(1164.0, 820.0), Vector2(150.0, 72.0))
		draw_rect(parcel.grow(5.0), Color(0.24, 0.10, 0.025, 0.75), true)
		draw_rect(parcel, Color("e8c27d"), true)
		draw_line(parcel.position + Vector2(parcel.size.x * 0.5, 0.0), parcel.position + Vector2(parcel.size.x * 0.5, parcel.size.y), Color("a46b35"), 3.0)


func _draw_partial_youtiao() -> void:
	if fryer_quantity <= 0 or fryer_quantity >= 4:
		return
	if fryer_state not in [&"loaded", &"frying", &"ready_safe", &"overcooking", &"draining", &"ready_to_collect", &"burnt"]:
		return
	var cooked := fryer_state in [&"ready_safe", &"overcooking", &"draining", &"ready_to_collect"]
	var fill := Color("4c2d22") if fryer_state == &"burnt" else Color("cf7a27") if cooked else Color("e8c98e")
	for index in fryer_quantity:
		var start := Vector2(122.0 + index * 72.0, 704.0 + (index % 2) * 12.0)
		var finish := start + Vector2(54.0, -14.0)
		draw_line(start, finish, Color(0.20, 0.08, 0.025, 0.86), 26.0, true)
		draw_line(start, finish, fill, 18.0, true)


func _draw_boxed_juice() -> void:
	if not drinks_unlocked:
		return
	for index in 4:
		var rect := Rect2(Vector2(1515.0 + index * 62.0, 840.0 - (index % 2) * 7.0), Vector2(44.0, 82.0))
		draw_rect(rect.grow(3.0), Color(0.25, 0.10, 0.025, 0.78), true)
		draw_rect(rect, Color("f08a2d"), true)
		draw_rect(Rect2(rect.position + Vector2(0.0, 8.0), Vector2(rect.size.x, 17.0)), Color("fff0bd"), true)
		draw_line(rect.position + Vector2(31.0, 4.0), rect.position + Vector2(38.0, -10.0), Color("f7e0a6"), 4.0, true)


func _draw_payment_coins() -> void:
	for center in payment_coin_centers:
		draw_circle(center, 27.0, Color(0.24, 0.10, 0.025, 0.84))
		draw_circle(center, 22.0, Color("f4b83d"))
		draw_arc(center, 16.0, 0.0, TAU, 24, Color("ffe49a"), 3.0, true)
