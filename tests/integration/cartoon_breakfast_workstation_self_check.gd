extends SceneTree

const SCENE := preload("res://scenes/gameplay/cartoon_breakfast_workstation.tscn")
const PORTRAITS := preload("res://scripts/ui/customer_portrait_catalog.gd")
const SAVE_PATH := "user://cartoon_breakfast_workstation_self_check.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.set("_active_save_path", SAVE_PATH)
		session.call("begin_new_game")
	var workstation := SCENE.instantiate() as CartoonBreakfastWorkstation
	root.add_child(workstation)
	await process_frame
	_check(workstation != null and workstation.has_signal("daily_bill_closed"), "new scene preserves the daily-bill interface")
	_check(workstation.has_method("end_business_day_early") and workstation.has_method("is_blocking_modal_open"), "new scene preserves the main-scene methods")
	_check(workstation.cartoon_artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE and workstation.fryer_state_artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE, "cartoon decoration never intercepts input")
	_check(workstation.cartoon_artwork.texture.resource_path.ends_with("xiaoliao-1.png"), "day-one art uses xiaoliao-1")
	workstation.call("_apply_fryer_art_state", &"loaded", 4)
	_check(workstation.fryer_state_artwork.texture != null and workstation.fryer_state_artwork.texture.atlas.resource_path.ends_with("mianpi-1.png"), "four raw dough blanks use mianpi-1")
	workstation.call("_apply_fryer_art_state", &"ready_to_collect", 4)
	_check(workstation.fryer_state_artwork.texture != null and workstation.fryer_state_artwork.texture.atlas.resource_path.ends_with("youtiao-1.png"), "four cooked sticks use restored youtiao-1")
	workstation.call("_apply_fryer_art_state", &"ready_to_collect", 3)
	_check(workstation.fryer_state_artwork.texture == null, "after one stick leaves, the procedural overlay shows the remaining batch")
	workstation.cartoon_youtiao_fryer.call("refresh_from_session")
	_check(is_zero_approx(workstation.cartoon_youtiao_fryer.fryer_visual.self_modulate.a), "refreshing the fryer suppresses the retired machine artwork in the same call")
	for source in workstation.cartoon_youtiao_fryer.fryer_slot_sources:
		_check(is_zero_approx(source.self_modulate.a), "refreshing the fryer suppresses every retired youtiao sprite in the same call")
	_check(workstation.contextual_tool_button != null and workstation.contextual_tool_button.size.x >= 56.0, "the baked-in pancake tool has a transparent interactive hotspot")
	_check(workstation.process_overlay != null and workstation.process_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "procedural process feedback never intercepts input")
	var pancake_unit := workstation.multi_griddle_station.get_node("Griddle01") as CompactGriddleUnit
	_check(workstation.cartoon_egg_crack_effect != null and workstation.cartoon_egg_crack_effect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "cartoon egg feedback is installed without blocking griddle input")
	var pancake_material := pancake_unit.pancake_visual.material as ShaderMaterial
	_check(
		pancake_unit.pancake_surface.position.is_equal_approx(Vector2(27.0, -124.0))
		and pancake_unit.pancake_surface.size.is_equal_approx(Vector2(398.0, 398.0))
		and pancake_unit.pancake_surface.scale.is_equal_approx(Vector2.ONE),
		"cartoon pancake surface is calibrated to the full authored griddle interior",
	)
	_check(is_equal_approx(pancake_unit.pancake_model.parameters.pan_height_ratio, 0.64), "cartoon pancake ellipse matches the authored griddle foreshortening")
	_check(bool(workstation.multi_griddle_station.get("auto_select_spreader_after_pour")), "cartoon held pour hands off to the spreader only after release")
	_check(
		pancake_material != null
		and (pancake_material.get_shader_parameter(&"raw_texture") as Texture2D).resource_path.begins_with("res://resources/art/cartoon/process/")
		and (pancake_material.get_shader_parameter(&"cooked_texture") as Texture2D).resource_path.begins_with("res://resources/art/cartoon/process/"),
		"live pancake shader uses the cartoon process materials",
	)
	workstation.call("_on_contextual_tool_pressed")
	_check(
		pancake_unit.state == CompactGriddleUnit.State.IDLE
		and pancake_unit.pancake_model.covered_cell_count() == 0
		and StringName(workstation.multi_griddle_station.get("_selected_tool")) == &"tool.pancake.ladle",
		"one contextual click prepares the ladle for a player-controlled held pour",
	)
	pancake_unit.begin_order({})
	_check(bool(pancake_unit.use_press_spreader().get("success", false)), "self-check can advance a seeded pancake into first-side cooking")
	workstation.call("_enforce_cartoon_only_visuals")
	_check(
		pancake_unit.main_action.visible
		and pancake_unit.main_action.is_visible_in_tree()
		and not pancake_unit.main_action.disabled
		and pancake_unit.main_action.mouse_filter == Control.MOUSE_FILTER_STOP
		and pancake_unit.main_action.text == "翻面",
		"cartoon-only enforcement keeps the flip/package action visible and interactive",
	)
	_check(pancake_unit.pancake_visual.texture is ImageTexture, "cartoon-only enforcement preserves the model-generated field texture")
	_check(_visible_textures_are_cartoon_only(workstation), "all visible workstation textures come from resources/art/cartoon")
	_check(not workstation.get_node("SafeArea/ServiceCustomer5").visible, "fifth customer slot is disabled")
	_check(workstation.customer_service_slots.size() == 4, "exactly four customer service slots are resolved")
	_check(not workstation.customer_service_slots.has(workstation.get_node("SafeArea/ServiceCustomer5")), "customer allocation cannot resolve a fifth slot")
	for slot_index in workstation.customer_service_slots.size():
		var slot := workstation.customer_service_slots[slot_index] as CustomerServiceSlot
		var portrait_bottom := slot.position.y + slot.scale.y * (slot.portrait.position.y + slot.portrait.size.y)
		var slot_clip_bottom := slot.position.y + slot.scale.y * slot.size.y
		var portrait_visual_width := slot.portrait.size.x * slot.portrait.scale.x * slot.scale.x
		var portrait_center_x := slot.position.x + slot.scale.x * (slot.portrait.position.x + slot.portrait.size.x * 0.5)
		var portrait_left := portrait_center_x - portrait_visual_width * 0.5
		var portrait_right := portrait_center_x + portrait_visual_width * 0.5
		_check(slot.clip_contents and is_equal_approx(slot_clip_bottom, 468.0), "customer slot %d clips at the marked counter edge" % (slot_index + 1))
		_check(is_equal_approx(portrait_bottom, 468.0) and slot.portrait.size == Vector2(260.0, 200.0), "customer slot %d uses the shared visible-height frame and marked baseline" % (slot_index + 1))
		_check(portrait_left >= 210.0 - 0.01 and portrait_right <= 1648.0 + 0.01, "customer slot %d stays between the vertical blockers" % (slot_index + 1))
	workstation.call("_open_upgrade_workshop")
	await process_frame
	var workshop := workstation.get("_upgrade_workshop") as UpgradeWorkshopOverlay
	var visible_growth_props: Array[String] = []
	if workshop != null:
		for child in workshop.get_node("UpgradeProps").get_children():
			if child is Button and child.visible:
				visible_growth_props.append(child.name)
	_check(visible_growth_props.size() == 2 and visible_growth_props.has("WorkshopProp_growth_area_youtiao") and visible_growth_props.has("WorkshopProp_growth_area_fresh_soy_milk"), "growth workshop shows only youtiao and drinks")
	workstation.call("_close_upgrade_workshop")

	var progression: RefCounted = session.call("progression_service") as RefCounted if session != null else null
	if progression != null:
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
		workstation.call("_refresh_cartoon_presentation", true)
		_check(workstation.cartoon_artwork.texture.resource_path.ends_with("zhaguo-1.png"), "youtiao-only expansion uses zhaguo-1")
		_check(workstation.ingredient_artwork.visible, "expanded layouts retain the filled pancake ingredient region from xiaoliao-1")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true, &"area.packaged_drink": true})
		workstation.call("_refresh_cartoon_presentation", true)
		_check(workstation.cartoon_artwork.texture.resource_path.ends_with("doujiang-2.png"), "drink-only expansion uses doujiang-2 with its finished-drink plate")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true, &"area.packaged_drink": true})
		workstation.call("_refresh_cartoon_presentation", true)
		_check(workstation.cartoon_artwork.texture.resource_path.ends_with("shebei-2.png"), "fully unlocked counter uses shebei-2")

	var portraits := PORTRAITS.new()
	var portrait_pool: Array[StringName] = PORTRAITS.CUSTOMER_IDS
	_check(portrait_pool.size() == 6, "six cartoon customers form the rotation pool")
	for customer_id in portrait_pool:
		for state in [&"neutral", &"impatient", &"satisfied", &"angry"]:
			var texture := portraits.texture_for(customer_id, state) as AtlasTexture
			_check(texture != null and texture.region.size.x > 0.0 and texture.region.size.y > 0.0, "%s exposes %s atlas state" % [customer_id, state])
			_check(texture != null and texture.region.size != Vector2(texture.atlas.get_width() / 2.0, texture.atlas.get_height() / 2.0), "%s %s is cropped to its visible figure" % [customer_id, state])

	workstation.queue_free()
	await process_frame
	_remove_test_files()
	_finish()


func _visible_textures_are_cartoon_only(workstation: CartoonBreakfastWorkstation) -> bool:
	for node in workstation.find_children("*", "", true, false):
		if not (node is CanvasItem) or not (node as CanvasItem).is_visible_in_tree():
			continue
		var textures: Array[Texture2D] = []
		if node is TextureRect:
			textures.append((node as TextureRect).texture)
		elif node is TextureButton:
			textures.append_array([(node as TextureButton).texture_normal, (node as TextureButton).texture_pressed, (node as TextureButton).texture_hover, (node as TextureButton).texture_disabled, (node as TextureButton).texture_focused])
		elif node is Sprite2D:
			textures.append((node as Sprite2D).texture)
		elif node is NinePatchRect:
			textures.append((node as NinePatchRect).texture)
		for texture in textures:
			if not workstation.call("_is_cartoon_texture", texture):
				return false
	return true


func _remove_test_files() -> void:
	var absolute := ProjectSettings.globalize_path(SAVE_PATH)
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = absolute + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARTOON_BREAKFAST_WORKSTATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CARTOON_BREAKFAST_WORKSTATION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
