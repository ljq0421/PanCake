class_name IngredientTrayVisual
extends TextureRect

## Keeps a physical countertop tray in sync with an inventory stock. Input is
## intentionally handled by the matching PancakeWorktopHotspots drag source.

@export var stock_id: StringName
@export var stock_textures: Array[Texture2D] = []
## Optional runtime empty state. This lets the authored scene use a full
## container texture for editor layout while service gameplay still starts
## from the correct empty artwork before inventory is applied.
@export var empty_texture: Texture2D
## Optional complete-container states ordered as empty, partial, and full.
## When these are supplied, this node itself swaps texture rather than using a
## separate contents layer inside a fixed tray.
@export var state_textures: Array[Texture2D] = []
@export_range(1, 99, 1) var full_quantity := 6
@export var contents_visual_path: NodePath

var _session: Node
var _base_texture: Texture2D
var _workshop_preview := false


func _ready() -> void:
	_base_texture = empty_texture if empty_texture != null else texture
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


## The upgrade workshop is an equipment catalogue, not an inventory readout.
## Keep its countertop examples full even when the live service inventory is
## currently depleted. Leaving the preview restores the live stock state.
func set_workshop_preview(enabled: bool) -> void:
	_workshop_preview = enabled
	_refresh_from_session()


func _refresh_from_session() -> void:
	if _session == null or stock_id.is_empty() or not _session.has_method("inventory_snapshot"):
		return
	var inventory := Dictionary(_session.call("inventory_snapshot"))
	var quantity := full_quantity if _workshop_preview else maxi(int(inventory.get(str(stock_id), 0)), 0)
	var contents := get_node_or_null(contents_visual_path) as TextureRect
	if not state_textures.is_empty():
		texture = _state_texture_for_quantity(quantity)
		if contents != null:
			contents.texture = null
			contents.visible = false
		return
	if contents == null:
		return
	var texture_index := clampi(quantity, 0, stock_textures.size()) - 1
	contents.texture = stock_textures[texture_index] if texture_index >= 0 else null
	contents.visible = texture_index >= 0


func _state_texture_for_quantity(quantity: int) -> Texture2D:
	if state_textures.is_empty():
		return null
	# A full quantity-indexed container set has one texture for each stocked
	# amount (1..full_quantity), while the scene's original texture is kept for
	# the empty state.
	if state_textures.size() == full_quantity:
		if quantity <= 0:
			return _base_texture
		return state_textures[clampi(quantity, 1, state_textures.size()) - 1]
	if quantity <= 0:
		return state_textures[0]
	var full_index := state_textures.size() - 1
	if quantity >= full_quantity:
		return state_textures[full_index]
	return state_textures[mini(1, full_index)]
