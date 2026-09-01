class_name WorkbenchArtSpec
extends RefCounted

## Shared P1 art contract for workstation props.  Controls may keep a larger
## transparent hit target; these values describe the visible container shell.
const CONTAINER_S := Vector2(96.0, 76.0)
const CONTAINER_M := Vector2(176.0, 96.0)
const CONTAINER_L := Vector2(288.0, 120.0)
const ROUND_TOP_ASPECT := 0.36
const ROUND_TOP_ASPECT_TOLERANCE := 0.02
const SMALL_OUTLINE_PIXELS := Vector2(3.0, 4.0)
const MACHINE_OUTLINE_PIXELS := Vector2(4.0, 6.0)
const LIGHT_DIRECTION := Vector2(-0.70710678, -0.70710678)
const SHADOW_DIRECTION := Vector2(0.70710678, 0.70710678)
const SHADOW_COLOR := Color(0.24, 0.15, 0.10, 0.30)

## Confirmed P1 perspective masters.  New workstation art is derived from one
## of these four sources instead of copying the independent angles of legacy
## props.  The active griddle surface remains a documented runtime exception:
## its simulation and pointer mapping use 0.75, which takes precedence over the
## general 0.36 prop-top target in the visual specification.
const PERSPECTIVE_MASTER_PATHS := {
	&"round_top": "res://resources/art/workstation/perspective_masters/p1/round-griddle-master-p1-v3-transparent.png",
	&"rectangular_tray": "res://resources/art/workstation/containers/p1/container-l-empty-p1-v2-transparent.png",
	&"machine": "res://resources/art/workstation/perspective_masters/p1/soy-machine-master-p1-v3-transparent.png",
	&"cylinder": "res://resources/art/products/soy_milk/yellow_soy_milk_cup_filled_v1.png",
}
const GRIDDLE_RUNTIME_SURFACE_ASPECT := 0.75

enum ContainerSizeClass { S, M, L }


static func container_size(size_class: ContainerSizeClass) -> Vector2:
	match size_class:
		ContainerSizeClass.S:
			return CONTAINER_S
		ContainerSizeClass.M:
			return CONTAINER_M
		ContainerSizeClass.L:
			return CONTAINER_L
	return Vector2.ZERO


static func center_visual(control: Control, size_class: ContainerSizeClass) -> void:
	if control == null:
		return
	var target_size := container_size(size_class)
	control.set_anchors_preset(Control.PRESET_CENTER)
	control.position = -target_size * 0.5
	control.size = target_size
	control.set_meta(&"workbench_container_size_class", ContainerSizeClass.keys()[size_class])
