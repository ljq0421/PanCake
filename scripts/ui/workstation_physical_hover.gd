class_name WorkstationPhysicalHover
extends Node

## Applies the shared, instantaneous physical-object hover treatment to the
## workbench only. ProductDragSource already brightens its own texture; when a
## source is an invisible hit layer, this helper instead brightens its artwork.

const HOVER_MODULATE := Color(1.18, 1.13, 0.96, 1.0)

var _watched: Dictionary = {}
var _rest_modulates: Dictionary = {}


func watch_tree(root: Node) -> void:
	if root == null:
		return
	if root is BaseButton:
		_watch_button(root as BaseButton)
	for node in root.find_children("*", "BaseButton", true, false):
		_watch_button(node as BaseButton)


func watch_control(control: Control, visual: CanvasItem = null) -> void:
	if control == null:
		return
	var target := visual if visual != null else control
	_watch(control, target)


func _watch_button(button: BaseButton) -> void:
	if button == null:
		return
	# ProductDragSource owns durable hover state itself. It has to reapply that
	# state after its frequent inventory refreshes, which this passive helper
	# deliberately does not observe.
	if button is ProductDragSource:
		return
	var visual := _visual_for_button(button)
	_watch(button, visual)


func _watch(control: Control, visual: CanvasItem) -> void:
	if visual == null:
		return
	var key := control.get_instance_id()
	if _watched.has(key):
		return
	_watched[key] = visual
	control.mouse_entered.connect(_on_mouse_entered.bind(control, visual))
	control.mouse_exited.connect(_on_mouse_exited.bind(control, visual))


func _visual_for_button(button: BaseButton) -> CanvasItem:
	var locked_art_path: NodePath = button.get_meta(&"locked_art_path", NodePath())
	if not locked_art_path.is_empty():
		var locked_art := button.get_node_or_null(locked_art_path) as CanvasItem
		if locked_art != null:
			return locked_art
	var parent := button.get_parent()
	if parent != null:
		var visual := parent.get_node_or_null("Visual") as CanvasItem
		if visual != null:
			# Modulate the physical prop root rather than one visual layer. Some
			# tools swap their artwork at runtime (for example the basic spreader
			# and its upgraded press), and the hover must follow that swap.
			return parent as CanvasItem
		var press_visual := parent.get_node_or_null("PressVisual") as CanvasItem
		if press_visual != null:
			return parent as CanvasItem
	return button


func _on_mouse_entered(control: Control, visual: CanvasItem) -> void:
	if control is BaseButton and (control as BaseButton).disabled:
		return
	var key := control.get_instance_id()
	# `self_modulate` intentionally stops at this node. Most countertop props
	# have a transparent Button/Control as the hit layer and their real artwork
	# below it, so use the inherited modulation channel to brighten that artwork.
	_rest_modulates[key] = visual.modulate
	visual.modulate = visual.modulate * HOVER_MODULATE
	control.set_meta(&"workbench_visual_state", &"hover")


func _on_mouse_exited(control: Control, visual: CanvasItem) -> void:
	var key := control.get_instance_id()
	if not _rest_modulates.has(key):
		return
	visual.modulate = _rest_modulates[key] as Color
	_rest_modulates.erase(key)
	control.set_meta(&"workbench_visual_state", &"default")
