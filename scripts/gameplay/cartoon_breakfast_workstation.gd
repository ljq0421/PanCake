class_name CartoonBreakfastWorkstation
extends FiveAreaWorkstation

const GRIDDLE_UNIT := preload("res://scripts/gameplay/compact_griddle_unit.gd")
const PROCESS_OVERLAY := preload("res://scripts/ui/cartoon_breakfast_process_overlay.gd")
const ART_PANCAKE := preload("res://resources/art/cartoon/xiaoliao-1.png")
const ART_YOUTIAO := preload("res://resources/art/cartoon/zhaguo-1.png")
const ART_DRINKS := preload("res://resources/art/cartoon/doujiang-2.png")
const ART_ALL_EQUIPMENT := preload("res://resources/art/cartoon/shebei-2.png")
const ART_RAW_YOUTIAO := preload("res://resources/art/cartoon/mianpi-1.png")
const ART_READY_YOUTIAO := preload("res://resources/art/cartoon/youtiao-1.png")
const ART_PANCAKE_RAW := preload("res://resources/art/cartoon/process/pancake_raw_cartoon_v1.png")
const ART_PANCAKE_COOKED := preload("res://resources/art/cartoon/process/pancake_cooked_cartoon_v1.png")
const ART_PANCAKE_CHARRED := preload("res://resources/art/cartoon/process/pancake_charred_cartoon_v1.png")
const ART_EGG_SPREAD := preload("res://resources/art/cartoon/process/egg_spread_cartoon_v1.png")
const ART_SWEET_SAUCE := preload("res://resources/art/cartoon/process/sweet_flour_sauce_cartoon_v1.png")
const ART_CHILI_SAUCE := preload("res://resources/art/cartoon/process/chili_sauce_cartoon_v1.png")
const ART_BATTER_SPREADER := preload("res://resources/art/cartoon/process/batter_spreader_cartoon_v1.png")

const ART_SOURCE_SIZE := Vector2(1672.0, 941.0)
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const ART_SCALE := DESIGN_SIZE.x / ART_SOURCE_SIZE.x
const ART_TOP := (DESIGN_SIZE.y - ART_SOURCE_SIZE.y * ART_SCALE) * 0.5
const CUSTOMER_COUNTER_EDGE_Y := 468.0
const CUSTOMER_HORIZONTAL_LIMITS := Vector2(210.0, 1648.0)
const CUSTOMER_PORTRAIT_SIZE := Vector2(260.0, 200.0)
const LEFT_ART_REGION := Rect2(0.0, 430.0, 455.0, 511.0)
const INGREDIENT_ART_REGION := Rect2(810.0, 487.0, 410.0, 190.0)
const CONTEXT_TOOL_RECT := Rect2(842.0, 680.0, 150.0, 130.0)
## Calibrated against the authored dark cooking surface in xiaoliao-1.png.
## The cartoon griddle is more foreshortened than the retired griddle artwork,
## so both its field rectangle and simulation ellipse ratio are overridden.
const CARTOON_PANCAKE_SURFACE_RECT := Rect2(27.0, -124.0, 398.0, 398.0)
const CARTOON_PAN_HEIGHT_RATIO := 0.64
const FRYER_INPUT_RECT := Rect2(42.0, 500.0, 410.0, 330.0)
const SOY_INPUT_RECT := Rect2(1200.0, 470.0, 360.0, 350.0)
const DRINK_INPUT_RECT := Rect2(1270.0, 680.0, 345.0, 210.0)
const INGREDIENT_RECTS := {
	"EggCarton": Rect2(825.0, 500.0, 135.0, 84.0),
	"BaocuiBasket": Rect2(945.0, 500.0, 135.0, 84.0),
	"PorkFlossSource": Rect2(1065.0, 500.0, 135.0, 84.0),
	"SecretSauceSource": Rect2(825.0, 580.0, 135.0, 84.0),
	"ScallionTray": Rect2(945.0, 580.0, 135.0, 84.0),
	"HamSource": Rect2(1065.0, 580.0, 135.0, 84.0),
}

var cartoon_artwork: TextureRect
var ingredient_artwork: TextureRect
var fryer_state_artwork: TextureRect
var process_overlay: Control
var contextual_tool_button: Button
var fryer_hotspot_button: Button
var _cartoon_refresh_elapsed := 0.0
var _last_macro_signature := ""
var _last_fryer_signature := ""


func _ready() -> void:
	_install_cartoon_artwork()
	_hide_retired_workbench_artwork()
	_configure_cartoon_customer_layout()
	super._ready()
	_configure_cartoon_layout()
	_enforce_cartoon_only_visuals()
	_refresh_cartoon_presentation(true)


func _refresh_customer_service_slots(orders: Array) -> void:
	super._refresh_customer_service_slots(orders)
	var order_by_id := {}
	for order_value in orders:
		var order := Dictionary(order_value)
		order_by_id[StringName(order.get("order_id", &""))] = order
	for slot_value in customer_service_slots:
		var slot := slot_value as CustomerServiceSlot
		if slot == null:
			continue
		var order := Dictionary(order_by_id.get(slot.bound_order_id(), {}))
		var items := Array(order.get("items", []))
		for item_index in slot.item_buttons.size():
			var button := slot.item_buttons[item_index]
			button.text = _cartoon_item_text(Dictionary(items[item_index])) if item_index < items.size() else ""
			button.add_theme_font_size_override(&"font_size", 14)
			button.add_theme_color_override(&"font_color", Color("6b3218"))
			button.add_theme_color_override(&"font_hover_color", Color("8b431f"))
			button.add_theme_color_override(&"font_pressed_color", Color("3f1c0e"))


func _cartoon_item_text(item: Dictionary) -> String:
	match StringName(item.get("product_id", &"")):
		&"product.youtiao.plain":
			return "油条"
		&"product.fresh_soy_milk.yellow_bean":
			return "黄豆浆"
		&"product.packaged_drink.juice":
			return "盒装果汁"
		&"product.pancake.custom":
			var marks: Array[String] = []
			var names := {
				"stock.pancake.egg": "蛋", "stock.pancake.baocui": "脆",
				"stock.pancake.scallion": "葱", "stock.pancake.ham_sausage": "肠",
				"stock.pancake.meat_floss": "松", "stock.pancake.sauce.sweet_flour": "酱",
			}
			for ingredient_id in Array(item.get("ingredient_ids", [])) + Array(item.get("sauce_ids", [])):
				var mark := str(names.get(str(ingredient_id), ""))
				if not mark.is_empty():
					marks.append(mark)
			return "煎饼\n%s" % ("原味" if marks.is_empty() else "·".join(marks))
		_:
			return "单品"


func _process(delta: float) -> void:
	super._process(delta)
	_cartoon_refresh_elapsed += maxf(delta, 0.0)
	if _cartoon_refresh_elapsed < 0.08:
		return
	_cartoon_refresh_elapsed = 0.0
	_refresh_cartoon_presentation()
	_enforce_cartoon_only_visuals()


func _install_cartoon_artwork() -> void:
	var safe_area := get_node("SafeArea") as Control
	cartoon_artwork = TextureRect.new()
	cartoon_artwork.name = "CartoonArtPlate"
	cartoon_artwork.z_index = -160
	cartoon_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartoon_artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cartoon_artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cartoon_artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	safe_area.add_child(cartoon_artwork)
	safe_area.move_child(cartoon_artwork, 0)

	ingredient_artwork = _new_art_region("IngredientArtPlate", ART_PANCAKE, INGREDIENT_ART_REGION, -159)
	safe_area.add_child(ingredient_artwork)
	safe_area.move_child(ingredient_artwork, 1)
	fryer_state_artwork = _new_art_region("FryerStatePlate", null, LEFT_ART_REGION, -158)
	safe_area.add_child(fryer_state_artwork)
	safe_area.move_child(fryer_state_artwork, 2)

	process_overlay = PROCESS_OVERLAY.new() as Control
	process_overlay.name = "CartoonProcessOverlay"
	process_overlay.z_index = 80
	process_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_child(process_overlay)

	contextual_tool_button = _new_hotspot_button("ContextualPancakeTool", _design_rect(CONTEXT_TOOL_RECT), 210)
	contextual_tool_button.tooltip_text = "煎饼工具"
	contextual_tool_button.pressed.connect(_on_contextual_tool_pressed)
	safe_area.add_child(contextual_tool_button)

	fryer_hotspot_button = _new_hotspot_button("FryerHotspot", _design_rect(FRYER_INPUT_RECT), 205)
	fryer_hotspot_button.tooltip_text = "油条炸锅"
	fryer_hotspot_button.button_down.connect(_on_fryer_hotspot_down)
	fryer_hotspot_button.button_up.connect(_on_fryer_hotspot_up)
	safe_area.add_child(fryer_hotspot_button)


func _new_art_region(node_name: String, texture: Texture2D, source_region: Rect2, z: int) -> TextureRect:
	var result := TextureRect.new()
	result.name = node_name
	result.z_index = z
	var mapped := _design_rect(source_region)
	result.position = mapped.position
	result.size = mapped.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_SCALE
	result.texture = _atlas_region(texture, source_region) if texture != null else null
	return result


func _new_hotspot_button(node_name: String, rect: Rect2, z: int) -> Button:
	var result := Button.new()
	result.name = node_name
	result.z_index = z
	result.position = rect.position
	result.size = rect.size
	result.flat = true
	result.focus_mode = Control.FOCUS_NONE
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return result


func _hide_retired_workbench_artwork() -> void:
	for path in [
		"Backdrop",
		"SafeArea/BackgroundArtwork",
		"SafeArea/FormalWorkbenchPolish",
		"SafeArea/WorkstationZoneBackdrop",
		"SafeArea/CustomerStrip",
		"SafeArea/BottomStrip",
		"SafeArea/LockedIngredientInteractions",
		"SafeArea/YoutiaoDoughPlain",
		"FiveAreaInfrastructure/Stations/PancakeHoldingTray",
	]:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = false
	var waste_basket := get_node_or_null("FiveAreaInfrastructure/Stations/WasteBasket") as Control
	if waste_basket != null:
		for child in waste_basket.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
	var fifth_customer := get_node_or_null("SafeArea/ServiceCustomer5") as Control
	if fifth_customer != null:
		fifth_customer.visible = false
		fifth_customer.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED


func _configure_cartoon_layout() -> void:
	# Keep the proven production controls, but make every inherited visual fully
	# transparent. The authored cartoon plate is the only bitmap presentation.
	pancake_station_view.position = Vector2(-91.0, -26.0)
	var unit := multi_griddle_station.get_node_or_null("Griddle01") as CompactGriddleUnit
	if unit != null:
		multi_griddle_station.set("auto_select_spreader_after_pour", true)
		unit.pancake_surface.scale = Vector2.ONE
		unit.pancake_surface.position = CARTOON_PANCAKE_SURFACE_RECT.position
		unit.pancake_surface.size = CARTOON_PANCAKE_SURFACE_RECT.size
		unit.pancake_surface.pivot_offset = CARTOON_PANCAKE_SURFACE_RECT.size * 0.5
		unit.pancake_model.parameters.pan_height_ratio = CARTOON_PAN_HEIGHT_RATIO
		unit.set_spreader_cursor_textures(ART_BATTER_SPREADER)
		unit.set_spreader_visual_enabled(true)
		unit.self_modulate.a = 0.0
		_apply_cartoon_pancake_material(unit)
	var main_action := pancake_station_view.get_node_or_null("MultiGriddleStation/Griddle01/MainAction") as Control
	if main_action != null:
		main_action.visible = false
		main_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node_name in INGREDIENT_RECTS:
		var source := pancake_worktop_hotspots.get_node_or_null(NodePath(str(node_name))) as Control
		if source == null:
			continue
		var desired := _design_rect(Rect2(INGREDIENT_RECTS[node_name]))
		source.position = desired.position - pancake_station_view.position
		source.size = desired.size
		var visual := source.get_node_or_null("Visual") as CanvasItem
		if visual != null:
			visual.visible = false
	for hidden_source_name in ["CorianderTray", "BatterLadleSource", "SpreaderSource"]:
		var source := pancake_worktop_hotspots.get_node_or_null(hidden_source_name) as Control
		if source != null:
			source.visible = false
			source.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED

	cartoon_youtiao_fryer.position = Vector2(22.0, 492.0)
	cartoon_youtiao_fryer.baked_into_workbench_artwork = true
	cartoon_youtiao_fryer.direct_single_delivery_only = true
	cartoon_youtiao_fryer.fryer_visual.self_modulate.a = 0.0
	var chicken_basket := cartoon_youtiao_fryer.get_node_or_null("FryerAssembly/RightBasket") as Control
	if chicken_basket != null:
		chicken_basket.visible = false
	fresh_soy_station.position = _design_rect(SOY_INPUT_RECT).position
	fresh_soy_station.size = _design_rect(SOY_INPUT_RECT).size
	fresh_soy_station.soy_milk_dispenser.visible = false
	fresh_soy_station.sugar_jar.visible = false
	fresh_soy_station.sugar_jar.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	var drink_rect := _design_rect(DRINK_INPUT_RECT)
	packaged_drink_station.position = drink_rect.position
	packaged_drink_station.custom_minimum_size = Vector2.ZERO
	packaged_drink_station.size = drink_rect.size
	packaged_drink_station.baked_into_workbench_artwork = true
	packaged_drink_station.refresh_from_session()


func _configure_cartoon_customer_layout() -> void:
	for slot_index in customer_service_slots.size():
		var slot_value := customer_service_slots[slot_index]
		var slot := slot_value as CustomerServiceSlot
		if slot == null or is_zero_approx(slot.scale.x) or is_zero_approx(slot.scale.y):
			continue
		# Clip the whole service slot at the rear counter edge. During entrance and
		# exit motion customers can move down behind the counter, but can never be
		# painted over the interactive worktop.
		var local_counter_edge := (CUSTOMER_COUNTER_EDGE_Y - slot.position.y) / slot.scale.y
		slot.size.y = local_counter_edge
		slot.clip_contents = true
		var portrait_position := Vector2(
			(slot.card_width - CUSTOMER_PORTRAIT_SIZE.x) * 0.5,
			local_counter_edge - CUSTOMER_PORTRAIT_SIZE.y,
		)
		# Distribute the complete visual frames between the two vertical blockers,
		# not merely their pivot points, so wide poses also stay inside the opening.
		var visual_width := CUSTOMER_PORTRAIT_SIZE.x * slot.portrait.scale.x * slot.scale.x
		var center_left := CUSTOMER_HORIZONTAL_LIMITS.x + visual_width * 0.5
		var center_right := CUSTOMER_HORIZONTAL_LIMITS.y - visual_width * 0.5
		var distribution := float(slot_index) / float(maxi(customer_service_slots.size() - 1, 1))
		var desired_center_x := lerpf(center_left, center_right, distribution)
		slot.position.x = desired_center_x - (portrait_position.x + CUSTOMER_PORTRAIT_SIZE.x * 0.5) * slot.scale.x
		slot.portrait.position = portrait_position
		slot.portrait.size = CUSTOMER_PORTRAIT_SIZE
		slot.portrait.pivot_offset = Vector2(CUSTOMER_PORTRAIT_SIZE.x * 0.5, CUSTOMER_PORTRAIT_SIZE.y)
		slot.set("_portrait_rest_position", portrait_position)


func _apply_cartoon_pancake_material(unit: CompactGriddleUnit) -> void:
	var material := unit.pancake_visual.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(&"raw_texture", ART_PANCAKE_RAW)
	material.set_shader_parameter(&"cooked_texture", ART_PANCAKE_COOKED)
	material.set_shader_parameter(&"charred_texture", ART_PANCAKE_CHARRED)
	material.set_shader_parameter(&"edge_texture", ART_PANCAKE_RAW)
	material.set_shader_parameter(&"egg_surface_texture", ART_EGG_SPREAD)
	material.set_shader_parameter(&"sweet_sauce_texture", ART_SWEET_SAUCE)
	material.set_shader_parameter(&"chili_sauce_texture", ART_CHILI_SAUCE)
	unit.pancake_surface.refresh_material_textures()


func _refresh_cartoon_presentation(force: bool = false) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("five_area_progression_snapshot"):
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked := Array(progression.get("unlocked_area_ids", []))
	var youtiao_unlocked := unlocked.has(&"area.youtiao") or unlocked.has("area.youtiao")
	var drinks_unlocked := unlocked.has(&"area.fresh_soy_milk") or unlocked.has("area.fresh_soy_milk")
	var macro_signature := "%s:%s" % [youtiao_unlocked, drinks_unlocked]
	if force or macro_signature != _last_macro_signature:
		_last_macro_signature = macro_signature
		cartoon_artwork.texture = ART_ALL_EQUIPMENT if youtiao_unlocked and drinks_unlocked else ART_YOUTIAO if youtiao_unlocked else ART_DRINKS if drinks_unlocked else ART_PANCAKE
		ingredient_artwork.visible = youtiao_unlocked or drinks_unlocked
	var fryer := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")) if youtiao_unlocked else {}
	var state := StringName(fryer.get("state", &"unowned"))
	var quantity := maxi(int(fryer.get("quantity", 0)), 0)
	var fryer_signature := "%s:%d" % [state, quantity]
	if force or fryer_signature != _last_fryer_signature:
		_last_fryer_signature = fryer_signature
		_apply_fryer_art_state(state, quantity)
	fryer_hotspot_button.visible = youtiao_unlocked
	fryer_hotspot_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if state in [&"ready_to_collect", &"burnt"] else Control.MOUSE_FILTER_STOP
	_update_process_overlay(fryer, drinks_unlocked)
	_update_contextual_tool_hint()


func _update_process_overlay(fryer: Dictionary, drinks_unlocked: bool) -> void:
	var pancake := {"mode": &"idle", "ingredient_ids": PackedStringArray()}
	var unit := multi_griddle_station.get_node_or_null("Griddle01") as CompactGriddleUnit
	if unit != null:
		var modes: Array[StringName] = [&"idle", &"batter", &"first_side", &"second_side", &"garnish", &"folding", &"ready"]
		var unit_state := clampi(int(unit.state), 0, modes.size() - 1)
		pancake = {"mode": modes[unit_state], "ingredient_ids": unit.applied_ingredient_ids.duplicate()}
	var coin_centers := PackedVector2Array()
	var safe_area := get_node("SafeArea") as Control
	var inverse := safe_area.get_global_transform().affine_inverse()
	for coin in _formal_payment_coin_sprites:
		if is_instance_valid(coin) and coin.visible:
			coin_centers.append(inverse * coin.get_global_rect().get_center())
	process_overlay.update_presentation(pancake, fryer, drinks_unlocked, coin_centers)


func _apply_fryer_art_state(state: StringName, quantity: int) -> void:
	var source_texture: Texture2D
	if quantity == 4 and state in [&"loaded", &"frying"]:
		source_texture = ART_RAW_YOUTIAO
	elif quantity == 4 and state in [&"ready_safe", &"overcooking", &"draining", &"ready_to_collect", &"ready"]:
		source_texture = ART_READY_YOUTIAO
	fryer_state_artwork.texture = _atlas_region(source_texture, LEFT_ART_REGION) if source_texture != null else null
	for source in cartoon_youtiao_fryer.fryer_slot_sources:
		source.self_modulate.a = 0.0
	cartoon_youtiao_fryer.fryer_visual.self_modulate.a = 0.0


func _atlas_region(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = region
	result.filter_clip = true
	return result


func _design_rect(source_rect: Rect2) -> Rect2:
	return Rect2(source_rect.position * ART_SCALE + Vector2(0.0, ART_TOP), source_rect.size * ART_SCALE)


func _on_contextual_tool_pressed() -> void:
	var unit := multi_griddle_station.get_node_or_null("Griddle01")
	if unit == null:
		return
	var state := int(unit.get("state"))
	if state == GRIDDLE_UNIT.State.IDLE:
		multi_griddle_station.call("select_worktop_tool", &"tool.pancake.ladle")
	elif state == GRIDDLE_UNIT.State.BATTER:
		multi_griddle_station.call("select_worktop_tool", &"tool.pancake.spreader")
	elif state in [GRIDDLE_UNIT.State.FIRST_SIDE, GRIDDLE_UNIT.State.SECOND_SIDE, GRIDDLE_UNIT.State.GARNISH]:
		multi_griddle_station.call("_on_main_action", 0)
	_update_contextual_tool_hint()


func _on_fryer_hotspot_down() -> void:
	cartoon_youtiao_fryer.set("_machine_lane", &"left")
	cartoon_youtiao_fryer.call("_begin_machine_gesture")


func _on_fryer_hotspot_up() -> void:
	if bool(cartoon_youtiao_fryer.get("_machine_press_active")):
		cartoon_youtiao_fryer.call("_finish_drag_or_click", Vector2.ZERO)


func _update_contextual_tool_hint() -> void:
	if contextual_tool_button == null:
		return
	var unit := multi_griddle_station.get_node_or_null("Griddle01")
	if unit == null:
		return
	match int(unit.get("state")):
		GRIDDLE_UNIT.State.IDLE:
			contextual_tool_button.tooltip_text = "点击拿起面糊勺，再在鏊面长按控制倒浆"
		GRIDDLE_UNIT.State.BATTER:
			contextual_tool_button.tooltip_text = "摊饼器已就绪，绕鏊面转满一圈"
		GRIDDLE_UNIT.State.FIRST_SIDE:
			contextual_tool_button.tooltip_text = "火候合适后点击翻面"
		GRIDDLE_UNIT.State.SECOND_SIDE, GRIDDLE_UNIT.State.GARNISH:
			contextual_tool_button.tooltip_text = "加好小料后点击折叠装袋"
		_:
			contextual_tool_button.tooltip_text = "当前煎饼正在处理"


func _enforce_cartoon_only_visuals() -> void:
	# The inherited scene supplies behavior only. Any texture that did not come
	# from the new cartoon directory is cleared even when a parent later refreshes it.
	for node in find_children("*", "", true, false):
		if node is TextureRect:
			var rect := node as TextureRect
			if not _is_cartoon_texture(rect.texture):
				rect.texture = null
		elif node is TextureButton:
			var button := node as TextureButton
			if not _is_cartoon_texture(button.texture_normal): button.texture_normal = null
			if not _is_cartoon_texture(button.texture_pressed): button.texture_pressed = null
			if not _is_cartoon_texture(button.texture_hover): button.texture_hover = null
			if not _is_cartoon_texture(button.texture_disabled): button.texture_disabled = null
			if not _is_cartoon_texture(button.texture_focused): button.texture_focused = null
		elif node is Sprite2D:
			var sprite := node as Sprite2D
			if not _is_cartoon_texture(sprite.texture): sprite.texture = null
		elif node is NinePatchRect:
			var patch := node as NinePatchRect
			if not _is_cartoon_texture(patch.texture): patch.texture = null
		elif node is Polygon2D:
			var polygon := node as Polygon2D
			if not _is_cartoon_texture(polygon.texture): polygon.texture = null
		elif node is Button:
			var plain_button := node as Button
			if not _is_cartoon_texture(plain_button.icon): plain_button.icon = null
	for badge in _station_state_badges.values():
		if badge is CanvasItem:
			(badge as CanvasItem).visible = false
	var inherited_main_action := pancake_station_view.get_node_or_null("MultiGriddleStation/Griddle01/MainAction") as Control
	if inherited_main_action != null:
		inherited_main_action.visible = false
		inherited_main_action.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _is_cartoon_texture(texture: Texture2D) -> bool:
	if texture == null:
		return true
	# PancakeHeatmap produces model-backed field textures at runtime. They have
	# no resource_path, but are gameplay output rather than retired disk art.
	if texture is ImageTexture:
		return true
	if texture is AtlasTexture:
		return _is_cartoon_texture((texture as AtlasTexture).atlas)
	return texture.resource_path.begins_with("res://resources/art/cartoon/")
