class_name BaocuiBasketSource
extends ProductDragSource

## Physical thin-crisp basket on the main worktop.  It is both the visual
## inventory indicator and the shared-ingredient source used by the griddle.

const STOCK_ID := &"stock.pancake.baocui"

@export var stock_textures: Array[Texture2D] = []
@export var contents_visual_path: NodePath

var _session: Node
var _basket_texture: Texture2D
var _stock_count := 0
var _stock_capacity := 6


func _ready() -> void:
	_basket_texture = texture_normal
	hold_enabled = true
	hold_threshold_seconds = 0.2
	cancel_pending_on_mouse_exit = false
	super._ready()
	hold_requested.connect(_on_hold_requested)
	hold_advanced.connect(_on_hold_advanced)
	hold_released.connect(_on_hold_released)
	call_deferred("_bind_session")


func _bind_session() -> void:
	_session = get_node_or_null("/root/GameSession")
	if _session == null:
		return
	var inventory_signal := Signal(_session, &"inventory_changed")
	if not inventory_signal.is_connected(_on_inventory_changed):
		inventory_signal.connect(_on_inventory_changed)
	var progression_signal := Signal(_session, &"progression_changed")
	if not progression_signal.is_connected(_on_progression_changed):
		progression_signal.connect(_on_progression_changed)
	_refresh_from_session()


func _on_inventory_changed(_inventory: Dictionary) -> void:
	_refresh_from_session()


func _on_progression_changed(_progression: Dictionary) -> void:
	_refresh_from_session()


func _refresh_from_session() -> void:
	if _session == null or not _session.has_method("five_area_restock_status"):
		return
	var status := Dictionary(_session.call("five_area_restock_status", STOCK_ID))
	var unlocked := bool(status.get("success", false))
	_stock_count = maxi(int(status.get("current_stock", 0)), 0)
	_stock_capacity = maxi(int(status.get("capacity", 6)), 1)
	configure(_build_source_ref(), _basket_texture, unlocked, _hint_text(status, unlocked))
	set_drag_available(unlocked and _stock_count > 0)
	_update_contents_visual()


func _build_source_ref() -> Dictionary:
	return {
		"source_kind": &"pancake_shared_ingredient",
		"source_index": -1,
		"stock_id": STOCK_ID,
	}


func _update_contents_visual() -> void:
	var contents := get_node_or_null(contents_visual_path) as TextureRect
	if contents == null:
		return
	var texture_index := clampi(_stock_count, 0, stock_textures.size()) - 1
	contents.texture = stock_textures[texture_index] if texture_index >= 0 else null
	contents.visible = texture_index >= 0


func _hint_text(status: Dictionary, unlocked: bool) -> String:
	if not unlocked:
		return "薄脆尚未解锁"
	if _stock_count <= 0:
		return "薄脆缺货：长按补货"
	if _stock_count >= _stock_capacity:
		return "薄脆 %d/%d：拖到鏊面" % [_stock_count, _stock_capacity]
	return "薄脆 %d/%d：拖到鏊面；长按补货（每片 %d 金币）" % [
		_stock_count,
		_stock_capacity,
		int(status.get("unit_cost", 0)),
	]


func _on_hold_requested(_source_ref: Dictionary) -> void:
	if _session == null:
		reject_hold()
		_show_feedback("薄脆补货暂不可用")
		return
	var status := Dictionary(_session.call("five_area_restock_status", STOCK_ID))
	if not bool(status.get("success", false)):
		reject_hold()
		_show_feedback("薄脆尚未解锁")
		return
	if int(status.get("current_stock", 0)) >= int(status.get("capacity", 0)):
		reject_hold()
		_show_feedback("薄脆篮已满")
		return
	if int(status.get("coins", 0)) < int(status.get("unit_cost", 0)):
		reject_hold()
		_show_feedback("金币不足，无法补薄脆")
		return
	accept_hold()
	self_modulate = Color(1.12, 1.04, 0.82, 1.0)
	_show_feedback("正在补薄脆…")


func _on_hold_advanced(_source_ref: Dictionary, delta: float) -> void:
	if _session == null or not _session.has_method("advance_five_area_restock_hold"):
		reject_hold()
		return
	var result := Dictionary(_session.call("advance_five_area_restock_hold", STOCK_ID, maxf(delta, 0.0)))
	_refresh_from_session()
	if int(result.get("completed_units", 0)) > 0:
		_show_feedback("薄脆补货 +%d" % int(result.get("completed_units", 0)))
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		reject_hold()
		self_modulate = Color.WHITE
		match StringName(result.get("reason", &"")):
			&"capacity_reached": _show_feedback("薄脆篮已满")
			&"insufficient_coins": _show_feedback("金币不足，无法继续补薄脆")


func _on_hold_released(_source_ref: Dictionary) -> void:
	self_modulate = Color.WHITE
	_refresh_from_session()


func _show_feedback(message: String) -> void:
	var status_label := get_node_or_null("../../BottomStrip/ToolStatusLabel") as Label
	if status_label != null:
		status_label.text = message
