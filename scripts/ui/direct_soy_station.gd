class_name DirectSoyStation
extends Control

signal status_message(message: String)
signal audio_cue_requested(cue: StringName)

const CUP_STACK_CAPACITY := 8
const REPRESENTATIVE_CUP_STACK_COUNT := 4
const INVENTORY_COUNT_BADGE := preload("res://scripts/ui/inventory_count_badge.gd")
const CUP_STACK_TEXTURE_PATHS := [
	"res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_1_v3_bold_cartoon_transparent.png",
	"res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_2_v3_bold_cartoon_transparent.png",
	"res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_3_v3_bold_cartoon_transparent.png",
	"res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_4_v3_bold_cartoon_transparent.png",
	"res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_5_v3_bold_cartoon_transparent.png",
	"res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_6_v3_bold_cartoon_transparent.png",
	"res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_7_v3_bold_cartoon_transparent.png",
	"res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_8_v3_bold_cartoon_transparent.png",
]
const FILLED_CUP_TEXTURE_PATH := "res://resources/art/products/soy_milk/yellow_soy_milk_cup_filled_v1.png"
const SUGAR_JAR_TEXTURE_PATH := "res://resources/art/workstation/containers/p1/container-s-sugar-p1-v2-transparent.png"
const MACHINE_TIER_LAYOUTS: Array[Dictionary] = [
	{
		"texture_path": "res://resources/art/workstation/machines/soy_milk/soy-milk-dispenser-p1-v2-transparent.png",
	},
	{
		"texture_path": "res://resources/art/workstation/machines/soy_milk/automatic-soy-milk-dispenser-p1-v2-transparent.png",
	},
	{
		"texture_path": "res://resources/art/workstation/machines/soy_milk/automatic-soy-milk-dispenser-two-outlets-p1-v2-transparent.png",
	},
]
const OUTLET_CUP_REGION := Rect2(261.0, 1125.0, 430.0, 488.0)
const FILLED_CUP_REGION := Rect2(256.0, 1079.0, 435.0, 498.0)
const FULL_CUP_SECONDS := 0.8
const WORKSHOP_LOCKED_AREA_MODULATE := Color(1.0, 1.0, 1.0, 0.42)

@export_group("Editor preview")
@export_enum("Basic", "Intermediate", "Advanced") var editor_preview_tier := 0

@export_group("Machine geometry")
@export_subgroup("Basic")
@export var basic_machine_rect := Rect2(57.0, 42.0, 315.0, 300.0)
@export var basic_left_nozzle_texture_position := Vector2(575.0, 1000.0)
@export var basic_left_cup_offset := Vector2(0.0, 8.0)
@export_subgroup("Intermediate")
@export var intermediate_machine_rect := Rect2(57.0, 42.0, 315.0, 300.0)
@export var intermediate_left_nozzle_texture_position := Vector2(573.0, 1040.0)
@export var intermediate_left_cup_offset := Vector2(0.0, 8.0)
@export_subgroup("Advanced")
@export var advanced_machine_rect := Rect2(57.0, 42.0, 315.0, 300.0)
@export var advanced_left_nozzle_texture_position := Vector2(452.0, 980.0)
@export var advanced_right_nozzle_texture_position := Vector2(689.0, 980.0)
@export var advanced_left_cup_offset := Vector2(0.0, 8.0)
@export var advanced_right_cup_offset := Vector2(0.0, 8.0)

@onready var machine_assembly: Control = %MachineAssembly
@onready var left_cup_slot: Control = %LeftCupSlot
@onready var right_cup_slot: Control = %RightCupSlot
@onready var machine_output: ProductDragSource = %MachineOutput
@onready var queued_cup_output: ProductDragSource = %QueuedCupOutput
@onready var cup_stack: ProductDragSource = %CupStack
@onready var left_selection_frame: Panel = %LeftSelectionFrame
@onready var right_selection_frame: Panel = %RightSelectionFrame
@onready var nozzle_button: Button = %NozzleButton
@onready var second_nozzle_button: Button = %SecondNozzleButton
@onready var dual_nozzle_button: Button = %DualNozzleButton
@onready var sugar_jar: TextureButton = %SugarJar
@onready var sugar_animation_origin: Control = $SugarJar/AnimationOrigin
@onready var soy_milk_dispenser: TextureRect = %SoyMilkDispenser
@onready var dispense_effect: SoyDispenseEffect = %DispenseEffect
@onready var queued_cup_effect: SoyDispenseEffect = %QueuedCupEffect

var lock_cover: Control = null
var _filling := false
var _held_seconds := 0.0
var _auto_fill_enabled := false
var _double_fill_enabled := false
var _workshop_preview := false
var _selected_cup_index := 0
var _displayed_machine_tier := 0
var _cup_stack_count := CUP_STACK_CAPACITY
var _outlet_cup_texture: Texture2D
var _filled_cup_texture: Texture2D
var _texture_cache: Dictionary = {}
var _cup_stack_count_badge


func _ready() -> void:
	_ensure_cup_stack_count_badge()
	machine_output.short_clicked.connect(_on_cup_short_clicked)
	queued_cup_output.short_clicked.connect(_on_queued_cup_short_clicked)
	cup_stack.short_clicked.connect(_on_cup_stack_short_clicked)
	cup_stack.hold_requested.connect(_on_cup_stack_hold_requested)
	nozzle_button.button_down.connect(_on_nozzle_down)
	nozzle_button.button_up.connect(_on_nozzle_up)
	nozzle_button.pressed.connect(_on_nozzle_pressed)
	second_nozzle_button.pressed.connect(_on_second_nozzle_pressed)
	dual_nozzle_button.pressed.connect(_on_dual_nozzle_pressed)
	sugar_jar.pressed.connect(_on_sugar_jar_pressed)
	refresh_from_session()


func _process(delta: float) -> void:
	if not _filling:
		return
	_held_seconds += maxf(delta, 0.0)
	var fill_ratio := clampf(_held_seconds / FULL_CUP_SECONDS, 0.0, 1.0)
	dispense_effect.set_dispense_state(true, fill_ratio, _liquid_color_for_recipe(_selected_recipe_id()))


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var area_unlocked := Array(progression.get("unlocked_area_ids", [])).has("area.fresh_soy_milk")
	visible = _workshop_preview or area_unlocked
	modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not area_unlocked else Color.WHITE
	if not visible:
		return
	if not _ensure_visual_resources():
		return
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	# Keep ownership separate from the workshop's ghost prop.  The workshop
	# always previews the next purchasable machine instead of skipping straight
	# to the final dual-outlet model.
	var double_fill_owned := bool(machine.get("double_fill_enabled", false))
	var auto_fill_owned := bool(machine.get("auto_fill_enabled", false))
	_displayed_machine_tier = _workshop_preview_tier(area_unlocked, auto_fill_owned, double_fill_owned) if _workshop_preview else _owned_machine_tier(auto_fill_owned, double_fill_owned)
	if _workshop_preview:
		machine["sugar_enabled"] = true
		machine["auto_fill_enabled"] = true
		machine["double_fill_enabled"] = true
	var cup_state := StringName(machine.get("cup_state", &"ready"))
	var cup := Dictionary(machine.get("cup", {}))
	var queued_cups := Array(machine.get("queued_cups", []))
	var held_empty_cup_count := int(machine.get("held_empty_cup_count", 0))
	var primary_empty_cup_placed := bool(machine.get("primary_empty_cup_placed", false))
	var secondary_empty_cup_placed := bool(machine.get("secondary_empty_cup_placed", false))
	var queued_cup := _cup_at_index(cup, queued_cups, 1)
	var has_left_cup := not cup.is_empty()
	var has_right_cup := not queued_cup.is_empty()
	if cup_state != &"filled" or _cup_at_index(cup, queued_cups, _selected_cup_index).is_empty():
		_selected_cup_index = 0 if has_left_cup else 1 if has_right_cup else 0
	var selected_cup := _cup_at_index(cup, queued_cups, _selected_cup_index)
	var fill_ratio := float(cup.get("fill_ratio", 0.0))
	var sugar_servings := int(selected_cup.get("sugar_servings", 0))
	var sugar_enabled := bool(machine.get("sugar_enabled", false))
	_auto_fill_enabled = bool(machine.get("auto_fill_enabled", false))
	_double_fill_enabled = bool(machine.get("double_fill_enabled", false))
	soy_milk_dispenser.texture = _texture_for_machine_tier(_displayed_machine_tier)
	var machine_rect := _machine_rect_for_tier(_displayed_machine_tier)
	soy_milk_dispenser.position = machine_rect.position
	soy_milk_dispenser.size = machine_rect.size
	# A locked area is faded by the station itself. Once the basic machine is
	# installed, fade only the next machine tier being previewed.
	soy_milk_dispenser.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and area_unlocked and not double_fill_owned else Color.WHITE
	_refresh_machine_geometry()
	var selected_recipe_id := StringName(machine.get("recipe_id", &"recipe.fresh_soy_milk.yellow_bean"))
	_filling = _filling and cup_state == &"held_empty"
	if not _filling:
		if cup_state == &"filled":
			# A completed full cup owns its authored liquid artwork. Keep the
			# procedural layer only for an underfilled cup so the two visuals never
			# overlap or produce a broken seam at the rim.
			dispense_effect.set_filled_cup(0.0 if _is_full_cup(cup) else fill_ratio, _liquid_color_for_recipe(StringName(cup.get("recipe_id", selected_recipe_id))))
		else:
			dispense_effect.set_filled_cup(0.0, _liquid_color_for_recipe(selected_recipe_id))
	var queued_fill_ratio := float(queued_cup.get("fill_ratio", 0.0)) if cup_state == &"filled" and has_right_cup else 0.0
	queued_cup_effect.set_filled_cup(0.0 if _is_full_cup(queued_cup) else queued_fill_ratio, _liquid_color_for_recipe(StringName(queued_cup.get("recipe_id", selected_recipe_id))))
	_refresh_cup_stack()
	var left_empty_visible := false
	var right_empty_visible := false
	if cup_state == &"held_empty":
		var right_empty_cup_only := _double_fill_enabled and secondary_empty_cup_placed and held_empty_cup_count == 1
		left_empty_visible = not right_empty_cup_only
		right_empty_visible = right_empty_cup_only or (_double_fill_enabled and held_empty_cup_count >= 2)
	elif cup_state == &"filled":
		left_empty_visible = primary_empty_cup_placed
		right_empty_visible = secondary_empty_cup_placed
	_configure_cup_source(machine_output, 0, cup, left_empty_visible, has_left_cup)
	_configure_cup_source(queued_cup_output, 1, queued_cup, right_empty_visible, has_right_cup)
	_update_cup_selection_frames(cup_state == &"filled")
	sugar_jar.visible = sugar_enabled
	sugar_jar.disabled = not sugar_enabled or cup_state != &"filled" or sugar_servings >= 2
	sugar_jar.tooltip_text = "给第%d杯加糖（最多两份）" % (_selected_cup_index + 1) if not sugar_jar.disabled else "请先接好豆浆" if cup_state != &"filled" else "第%d杯已是多糖" % (_selected_cup_index + 1)
	var left_outlet_ready := (cup_state == &"held_empty" and not secondary_empty_cup_placed) or primary_empty_cup_placed
	var right_outlet_ready := _double_fill_enabled and ((cup_state == &"held_empty" and (held_empty_cup_count >= 2 or secondary_empty_cup_placed)) or (cup_state == &"filled" and secondary_empty_cup_placed))
	var dual_outlets_ready := _double_fill_enabled and cup_state == &"held_empty" and held_empty_cup_count >= 2
	nozzle_button.disabled = not left_outlet_ready
	nozzle_button.tooltip_text = "点击左侧出浆口，接满左杯豆浆" if _double_fill_enabled else "点击自动接满一杯豆浆" if _auto_fill_enabled else "按住出浆口接浆"
	second_nozzle_button.visible = _double_fill_enabled
	second_nozzle_button.disabled = not right_outlet_ready
	second_nozzle_button.tooltip_text = "点击右侧出浆口，接满右杯豆浆"
	dual_nozzle_button.visible = _double_fill_enabled
	dual_nozzle_button.disabled = not dual_outlets_ready
	dual_nozzle_button.tooltip_text = "同时接满左右两杯豆浆"
	if _workshop_preview:
		# The workshop previews the compact station without exposing live controls.
		nozzle_button.disabled = true
		second_nozzle_button.visible = false
		dual_nozzle_button.visible = false
		machine_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
		queued_cup_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sugar_jar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		machine_output.mouse_filter = Control.MOUSE_FILTER_STOP if machine_output.visible else Control.MOUSE_FILTER_IGNORE
		queued_cup_output.mouse_filter = Control.MOUSE_FILTER_STOP if queued_cup_output.visible else Control.MOUSE_FILTER_IGNORE
		sugar_jar.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_nozzle_affordances()


func set_workshop_preview(enabled: bool) -> void:
	_workshop_preview = enabled
	refresh_from_session()


func _on_cup_short_clicked(_source_ref: Dictionary) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
		if StringName(machine.get("cup_state", &"ready")) == &"filled":
			_select_cup(0)


func _on_queued_cup_short_clicked(_source_ref: Dictionary) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
		if StringName(machine.get("cup_state", &"ready")) == &"filled":
			_select_cup(1)


func _on_cup_stack_short_clicked(_source_ref: Dictionary) -> void:
	if _workshop_preview:
		return
	if _cup_stack_count <= 0:
		status_message.emit("空杯已用完，请长按杯堆位置补货")
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	var cup_state := StringName(machine.get("cup_state", &"ready"))
	var held_empty_cup_count := int(machine.get("held_empty_cup_count", 0))
	var can_place_first_cup := cup_state == &"ready"
	var can_place_second_cup := cup_state == &"held_empty" and _double_fill_enabled and held_empty_cup_count < 2
	var can_refill_second_outlet := cup_state == &"filled" and _double_fill_enabled and not bool(machine.get("secondary_empty_cup_placed", false)) and int(machine.get("ready_cup_count", 0)) == 1
	if not can_place_first_cup and not can_place_second_cup and not can_refill_second_outlet:
		status_message.emit("请先完成当前这杯豆浆")
		return
	var result: Dictionary = session.call("take_f4_soy_empty_cup")
	if not bool(result.get("success", false)):
		status_message.emit("无法取杯：%s" % str(result.get("reason", &"unknown")))
		return
	_cup_stack_count -= 1
	audio_cue_requested.emit(&"soy_cup_place")
	var success_message := "第2个空杯已放到右出浆口，请单独点击右侧出浆口接浆" if bool(result.get("secondary_empty_cup_placed", false)) else "第一个空杯已放置，再点击杯堆放置第二个" if _double_fill_enabled and int(result.get("held_empty_cup_count", 0)) == 1 else "双杯已就位，点击双出浆口同时接满" if _double_fill_enabled else "空杯已拿起，点击自动豆浆机出浆口接浆" if _auto_fill_enabled else "空杯已拿起，按住豆浆机出浆口接浆"
	status_message.emit("%s（杯堆剩余 %d 个）" % [success_message, _cup_stack_count])
	refresh_from_session()


func _on_cup_stack_hold_requested(_source_ref: Dictionary) -> void:
	# A completed hold intentionally adds exactly one cup.  Rejecting the
	# gesture prevents the release from also being interpreted as a take-cup tap.
	cup_stack.reject_hold()
	if _workshop_preview:
		return
	if _cup_stack_count >= CUP_STACK_CAPACITY:
		status_message.emit("杯堆已经补满")
		return
	_cup_stack_count += 1
	status_message.emit("补货完成：杯堆现有 %d 个" % _cup_stack_count)
	refresh_from_session()


func _refresh_cup_stack() -> void:
	# The workshop is a visual catalogue, so it always shows a full, transparent
	# stack of cups.  The preview remains non-interactive and does not consume
	# the live station's cup inventory.
	var preview_stack_count := CUP_STACK_CAPACITY if _workshop_preview else _cup_stack_count
	var stack_texture := _cup_stack_texture(REPRESENTATIVE_CUP_STACK_COUNT)
	var has_stock := preview_stack_count > 0
	_ensure_cup_stack_count_badge()
	_cup_stack_count_badge.set_stock(preview_stack_count, CUP_STACK_CAPACITY, _workshop_preview)
	cup_stack.visible = true
	cup_stack.configure(
		{"source_kind": &"soy_cup_stack", "cup_count": preview_stack_count},
		stack_texture,
		not _workshop_preview,
		"工坊预览：一摞空杯" if _workshop_preview else "点击取空杯（剩余 %d 个）" % _cup_stack_count if has_stock else "空杯已用完，长按此处补货"
	)
	cup_stack.native_drag_enabled = not _workshop_preview
	cup_stack.set_drag_available(false)
	cup_stack.self_modulate = Color.WHITE if has_stock else Color(1.0, 1.0, 1.0, 0.0)
	if has_stock:
		cup_stack.set_alpha_hit_regions([{"texture": stack_texture, "rect": Rect2(Vector2.ZERO, cup_stack.size)}])
	else:
		# The empty location stays fully transparent, but its entire slot remains
		# interactive so players can long-press it to restore one cup.
		cup_stack.set_alpha_hit_regions([])


func _sync_outlet_cup_size_to_stack() -> void:
	# The stack textures share one canvas. Scale the cropped single-cup art by
	# that canvas's on-screen scale so an outlet cup is pixel-for-pixel the same
	# size as the cup visible in the stack, with no independently stretched width.
	var stack_texture_size := _cup_stack_texture(1).get_size()
	var outlet_texture_size := _outlet_cup_texture.get_size()
	if stack_texture_size.x <= 0.0 or stack_texture_size.y <= 0.0 or outlet_texture_size.x <= 0.0 or outlet_texture_size.y <= 0.0:
		return
	var stack_scale := minf(cup_stack.size.x / stack_texture_size.x, cup_stack.size.y / stack_texture_size.y)
	var outlet_display_size := outlet_texture_size * stack_scale
	left_cup_slot.size = outlet_display_size
	right_cup_slot.size = outlet_display_size
	left_selection_frame.position = Vector2(-4.0, -4.0)
	left_selection_frame.size = outlet_display_size + Vector2(8.0, 8.0)
	right_selection_frame.position = Vector2(-4.0, -4.0)
	right_selection_frame.size = outlet_display_size + Vector2(8.0, 8.0)


func _ensure_cup_stack_count_badge() -> void:
	if _cup_stack_count_badge != null:
		return
	_cup_stack_count_badge = INVENTORY_COUNT_BADGE.new()
	_cup_stack_count_badge.name = "InventoryCountBadge"
	_cup_stack_count_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_cup_stack_count_badge.position = Vector2(-60.0, -32.0)
	_cup_stack_count_badge.size = Vector2(54.0, 28.0)
	cup_stack.add_child(_cup_stack_count_badge)


func _ensure_visual_resources() -> bool:
	var source_texture := _cup_stack_texture(1)
	if source_texture == null:
		return false
	if _outlet_cup_texture == null:
		_outlet_cup_texture = _create_outlet_cup_texture(source_texture)
		_sync_outlet_cup_size_to_stack()
	if _filled_cup_texture == null:
		var filled_source_texture := _load_texture(FILLED_CUP_TEXTURE_PATH)
		if filled_source_texture == null:
			return false
		_filled_cup_texture = _create_filled_cup_texture(filled_source_texture)
	var sugar_texture := _load_texture(SUGAR_JAR_TEXTURE_PATH)
	if sugar_texture != null:
		sugar_jar.call("configure_texture", sugar_texture)
	return true


func _cup_stack_texture(cup_count: int) -> Texture2D:
	return _load_texture(CUP_STACK_TEXTURE_PATHS[clampi(cup_count, 1, CUP_STACK_CAPACITY) - 1])


func _load_texture(path: String) -> Texture2D:
	var cached := _texture_cache.get(path) as Texture2D
	if cached != null:
		return cached
	var texture := load(path) as Texture2D
	if texture != null:
		_texture_cache[path] = texture
	return texture


static func _create_outlet_cup_texture(source_texture: Texture2D) -> Texture2D:
	if source_texture == null:
		return null
	# The source artwork has a stable shared canvas. Its opaque cup bounds are
	# authored data, so an AtlasTexture preserves the exact crop without scanning
	# 1.57 million pixels and allocating a duplicate ImageTexture at startup.
	var outlet_texture := AtlasTexture.new()
	outlet_texture.atlas = source_texture
	outlet_texture.region = OUTLET_CUP_REGION
	return outlet_texture


static func _create_filled_cup_texture(source_texture: Texture2D) -> Texture2D:
	if source_texture == null:
		return null
	var filled_texture := AtlasTexture.new()
	filled_texture.atlas = source_texture
	filled_texture.region = FILLED_CUP_REGION
	filled_texture.filter_clip = true
	return filled_texture


func product_sources() -> Array[ProductDragSource]:
	return [machine_output, queued_cup_output]


func _configure_cup_source(source: ProductDragSource, cup_index: int, cup_payload: Dictionary, empty_visible: bool, filled_visible: bool) -> void:
	var source_visible := empty_visible or filled_visible
	var cup_slot := source.get_parent() as Control
	if cup_slot != null:
		cup_slot.visible = source_visible
	source.visible = source_visible
	if not source_visible:
		source.configure({"source_kind": &"soy_empty_cup"}, _outlet_cup_texture, false, "")
		source.set_drag_available(false)
		return
	var displayed_cup_texture := _filled_cup_texture if filled_visible and _is_full_cup(cup_payload) else _outlet_cup_texture
	if filled_visible:
		var product_id := StringName(cup_payload.get("product_id", &"product.fresh_soy_milk.yellow_bean"))
		source.configure(
			{"source_kind": &"soy_cup", "source_index": cup_index, "product_id": product_id, "discardable": true},
			displayed_cup_texture,
			not _workshop_preview,
			"点击选择第%d杯；拖动可交付或报废" % (cup_index + 1),
		)
		source.set_drag_available(not _workshop_preview)
	else:
		source.configure({"source_kind": &"soy_empty_cup", "source_index": cup_index}, _outlet_cup_texture, false, "空杯已在第%d个出浆口就位" % (cup_index + 1))
		source.set_drag_available(false)
	source.set_drag_preview_size(source.size)
	source.set_alpha_hit_regions([{"texture": displayed_cup_texture, "rect": Rect2(Vector2.ZERO, source.size)}])


func _select_cup(cup_index: int) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	var ready_cup_count := int(machine.get("ready_cup_count", 0))
	if StringName(machine.get("cup_state", &"ready")) != &"filled" or cup_index < 0 or cup_index >= ready_cup_count:
		return
	_selected_cup_index = cup_index
	status_message.emit("已选第%d杯豆浆" % (_selected_cup_index + 1))
	refresh_from_session()


func _on_nozzle_down() -> void:
	if nozzle_button.disabled:
		return
	if _auto_fill_enabled:
		return
	_filling = true
	_held_seconds = 0.0
	audio_cue_requested.emit(&"soy_dispense")
	dispense_effect.set_dispense_state(true, 0.0, _liquid_color_for_recipe(_selected_recipe_id()))


func _on_nozzle_pressed() -> void:
	if not nozzle_button.disabled and _auto_fill_enabled:
		_fill_cup_automatically()


func _on_second_nozzle_pressed() -> void:
	if not second_nozzle_button.disabled:
		_fill_cup_automatically(1)


func _on_dual_nozzle_pressed() -> void:
	if not dual_nozzle_button.disabled:
		_fill_cup_automatically(2)


func _on_nozzle_up() -> void:
	if not _filling:
		return
	_filling = false
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("fill_f4_soy_empty_cup", _held_seconds) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		var ratio := float(result.get("fill_ratio", 0.0))
		audio_cue_requested.emit(&"soy_ready")
		status_message.emit("满杯黄豆豆浆" if ratio >= 0.999 else "未接满（%d%%），收益和口碑将降低" % roundi(ratio * 100.0))
	else:
		status_message.emit("接浆失败：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _fill_cup_automatically(outlet_index: int = 0) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("fill_f4_soy_empty_cup", FULL_CUP_SECONDS, outlet_index) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		audio_cue_requested.emit(&"soy_dispense")
		audio_cue_requested.emit(&"soy_ready")
		status_message.emit("双口豆浆已同时接满" if outlet_index == 2 else "右杯豆浆已接满" if outlet_index == 1 else "左杯豆浆已接满" if _double_fill_enabled else "自动豆浆机已接满一杯")
	else:
		status_message.emit("自动接浆失败：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_sugar_jar_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("add_f4_soy_sugar", _selected_cup_index) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		var servings := int(result.get("sugar_servings", 0))
		_selected_cup_effect().play_sugar_add(_animation_origin_in_effect(sugar_animation_origin, _selected_cup_effect()))
		status_message.emit("第%d杯已加正常糖" % (_selected_cup_index + 1) if servings == 1 else "第%d杯已加多糖" % (_selected_cup_index + 1))
	else:
		status_message.emit("无法加糖：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _selected_recipe_id() -> StringName:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return &"recipe.fresh_soy_milk.yellow_bean"
	return StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("recipe_id", &"recipe.fresh_soy_milk.yellow_bean"))


static func _liquid_color_for_recipe(recipe_id: StringName) -> Color:
	return {
		&"recipe.fresh_soy_milk.yellow_bean": Color("f4d99c"),
	}.get(recipe_id, Color("f4d99c"))


func _machine_tier_layout() -> Dictionary:
	var tier := clampi(_displayed_machine_tier, 0, MACHINE_TIER_LAYOUTS.size() - 1)
	var layout := MACHINE_TIER_LAYOUTS[tier].duplicate()
	match tier:
		0:
			layout["left_nozzle_texture_position"] = basic_left_nozzle_texture_position
			layout["right_nozzle_texture_position"] = Vector2.ZERO
		1:
			layout["left_nozzle_texture_position"] = intermediate_left_nozzle_texture_position
			layout["right_nozzle_texture_position"] = Vector2.ZERO
		2:
			layout["left_nozzle_texture_position"] = advanced_left_nozzle_texture_position
			layout["right_nozzle_texture_position"] = advanced_right_nozzle_texture_position
	return layout


func _machine_rect_for_tier(tier: int) -> Rect2:
	match clampi(tier, 0, MACHINE_TIER_LAYOUTS.size() - 1):
		0: return basic_machine_rect
		1: return intermediate_machine_rect
		2: return advanced_machine_rect
	return basic_machine_rect


func _left_cup_offset_for_tier(tier: int) -> Vector2:
	match clampi(tier, 0, MACHINE_TIER_LAYOUTS.size() - 1):
		0: return basic_left_cup_offset
		1: return intermediate_left_cup_offset
		2: return advanced_left_cup_offset
	return basic_left_cup_offset


func _right_cup_offset_for_tier(tier: int) -> Vector2:
	return advanced_right_cup_offset if clampi(tier, 0, MACHINE_TIER_LAYOUTS.size() - 1) >= 2 else _left_cup_offset_for_tier(tier)


func _nozzle_outlet_position() -> Vector2:
	# The dispenser uses KEEP_ASPECT_COVERED. Resolve any source-image crop
	# before converting its verified source-pixel outlet into assembly coordinates.
	return _texture_position_to_machine(Vector2(_machine_tier_layout()["left_nozzle_texture_position"]))


func _texture_position_to_machine(texture_position: Vector2) -> Vector2:
	var texture_size := soy_milk_dispenser.texture.get_size()
	var display_size := soy_milk_dispenser.size
	var scale := maxf(display_size.x / texture_size.x, display_size.y / texture_size.y)
	var drawn_size := texture_size * scale
	var crop_offset := (display_size - drawn_size) * 0.5
	return soy_milk_dispenser.position + crop_offset + texture_position * scale


func _active_cup_position() -> Vector2:
	var outlet := _nozzle_outlet_position()
	return Vector2(outlet.x - left_cup_slot.size.x * 0.5, outlet.y) + _left_cup_offset_for_tier(_displayed_machine_tier)


func _secondary_cup_position() -> Vector2:
	var outlet := _second_nozzle_outlet_position()
	return Vector2(outlet.x - right_cup_slot.size.x * 0.5, outlet.y) + _right_cup_offset_for_tier(_displayed_machine_tier)


func _second_nozzle_outlet_position() -> Vector2:
	if _displayed_machine_tier < 2:
		return _nozzle_outlet_position()
	return _texture_position_to_machine(Vector2(_machine_tier_layout()["right_nozzle_texture_position"]))


func _refresh_machine_geometry() -> void:
	var outlet := _nozzle_outlet_position()
	var second_outlet := _second_nozzle_outlet_position()
	left_cup_slot.position = _active_cup_position()
	right_cup_slot.position = _secondary_cup_position()
	var nozzle_size := Vector2(88.0, 92.0) if _displayed_machine_tier >= 2 else Vector2(112.0, 100.0)
	nozzle_button.size = nozzle_size
	second_nozzle_button.size = nozzle_size
	nozzle_button.position = Vector2(
		clampf(outlet.x - nozzle_button.size.x * 0.5, 0.0, machine_assembly.size.x - nozzle_button.size.x),
		clampf(outlet.y - nozzle_button.size.y, 0.0, machine_assembly.size.y - nozzle_button.size.y)
	)
	second_nozzle_button.position = Vector2(
		clampf(second_outlet.x - second_nozzle_button.size.x * 0.5, 0.0, machine_assembly.size.x - second_nozzle_button.size.x),
		clampf(second_outlet.y - second_nozzle_button.size.y, 0.0, machine_assembly.size.y - second_nozzle_button.size.y)
	)
	dual_nozzle_button.position = Vector2(
		clampf((outlet.x + second_outlet.x) * 0.5 - dual_nozzle_button.size.x * 0.5, 0.0, machine_assembly.size.x - dual_nozzle_button.size.x),
		clampf(minf(outlet.y, second_outlet.y) - nozzle_size.y - dual_nozzle_button.size.y - 8.0, 0.0, machine_assembly.size.y - dual_nozzle_button.size.y)
	)
	dispense_effect.configure_geometry(Rect2(Vector2.ZERO, left_cup_slot.size), outlet - left_cup_slot.position)
	queued_cup_effect.configure_geometry(Rect2(Vector2.ZERO, right_cup_slot.size), second_outlet - right_cup_slot.position)


func _refresh_nozzle_affordances() -> void:
	# The former transparent hit zones made the actual operating point invisible.
	# Keep the highlight exactly aligned with each real button, and show it only
	# when that outlet can accept the next action.
	_configure_nozzle_affordance(
		nozzle_button,
		"左口出浆" if _double_fill_enabled else "点击出浆" if _auto_fill_enabled else "按住出浆",
	)
	_configure_nozzle_affordance(second_nozzle_button, "右口出浆")
	_configure_nozzle_affordance(dual_nozzle_button, "双口出浆")


func _configure_nozzle_affordance(button: Button, action_label: String) -> void:
	var actionable := not _workshop_preview and button.visible and not button.disabled
	button.text = action_label if actionable else ""
	button.modulate = Color.WHITE if actionable else Color(1.0, 1.0, 1.0, 0.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actionable else Control.CURSOR_ARROW


func _update_cup_selection_frames(has_filled_cup: bool) -> void:
	left_selection_frame.visible = has_filled_cup and _selected_cup_index == 0 and machine_output.visible and not machine_output.disabled
	right_selection_frame.visible = has_filled_cup and _selected_cup_index == 1 and queued_cup_output.visible and not queued_cup_output.disabled


func _selected_cup_effect() -> SoyDispenseEffect:
	return queued_cup_effect if _selected_cup_index == 1 else dispense_effect


func _animation_origin_in_effect(origin: Control, effect: SoyDispenseEffect) -> Vector2:
	var canvas_position := origin.get_global_transform_with_canvas().origin
	return effect.get_global_transform_with_canvas().affine_inverse() * canvas_position


static func _cup_at_index(active_cup: Dictionary, queued_cups: Array, cup_index: int) -> Dictionary:
	if cup_index == 0:
		return active_cup
	var queued_index := cup_index - 1
	if queued_index < 0 or queued_index >= queued_cups.size():
		return {}
	return Dictionary(queued_cups[queued_index])


static func _is_full_cup(cup: Dictionary) -> bool:
	return not cup.is_empty() and float(cup.get("fill_ratio", 0.0)) >= 0.999


static func _owned_machine_tier(auto_fill_owned: bool, double_fill_owned: bool) -> int:
	if double_fill_owned:
		return 2
	if auto_fill_owned:
		return 1
	return 0


static func _workshop_preview_tier(area_unlocked: bool, auto_fill_owned: bool, double_fill_owned: bool) -> int:
	if not area_unlocked:
		return 0
	if not auto_fill_owned:
		return 1
	if not double_fill_owned:
		return 2
	return 2


func _texture_for_machine_tier(tier: int) -> Texture2D:
	var layout := MACHINE_TIER_LAYOUTS[clampi(tier, 0, MACHINE_TIER_LAYOUTS.size() - 1)]
	return _load_texture(String(layout["texture_path"]))
