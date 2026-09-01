extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const GRIDDLE_SCENE := preload("res://scenes/gameplay/compact_griddle_unit.tscn")
const SOY_SCENE := preload("res://scenes/gameplay/direct_soy_station.tscn")
const FRYER_SCENE := preload("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	_check(WorkbenchArtSpec.CONTAINER_S == Vector2(96, 76), "S containers use the 96x76 art contract")
	_check(WorkbenchArtSpec.CONTAINER_M == Vector2(176, 96), "M containers use the 176x96 art contract")
	_check(WorkbenchArtSpec.CONTAINER_L == Vector2(288, 120), "L containers use the 288x120 art contract")
	_check(is_equal_approx(WorkbenchArtSpec.ROUND_TOP_ASPECT, 0.36), "round horizontal tops share the 0.36 perspective ratio")

	var griddle := GRIDDLE_SCENE.instantiate()
	var griddle_art := griddle.get_node("GriddleArt") as TextureRect
	_check(griddle_art.size == Vector2(455, 302), "griddle shell is reduced by nine percent without shrinking its interaction surface")
	_check(_material_path(griddle_art).ends_with("workbench_griddle_treatment.tres"), "griddle uses the warm-charcoal treatment")
	var surface := griddle.get_node("PancakeSurface") as Control
	_check(surface.size == Vector2(314, 314), "griddle interaction surface keeps its established effective size")

	var soy := SOY_SCENE.instantiate()
	var soy_art := soy.get_node("MachineAssembly/SoyMilkDispenser") as TextureRect
	_check(soy_art.size == Vector2(315, 300), "soy machine is eight percent narrower and sixteen percent shorter")
	_check(_material_path(soy_art).ends_with("workbench_soy_machine_treatment.tres"), "soy machine uses the low-saturation bean-green treatment")
	var sugar := soy.get_node("SugarJar") as TextureButton
	_check(sugar.size.is_equal_approx(WorkbenchArtSpec.CONTAINER_S) and str(sugar.get_meta(&"workbench_container_size_class", "")) == "S", "soy sugar jar applies the S container component (actual size=%s class=%s)" % [sugar.size, sugar.get_meta(&"workbench_container_size_class", "")])

	var fryer := FRYER_SCENE.instantiate()
	var fryer_art := fryer.get_node("FryerAssembly/FryerVisual") as TextureRect
	var fryer_material := fryer_art.material as ShaderMaterial
	_check(_material_path(fryer_art).ends_with("workbench_fryer_treatment.tres"), "fryer uses the shared machine treatment")
	_check(
		fryer_material != null
		and is_equal_approx(float(fryer_material.get_shader_parameter("panel_source_split")), 0.72)
		and is_equal_approx(float(fryer_material.get_shader_parameter("panel_target_split")), 0.755),
		"fryer treatment lowers the front-panel height by twelve and a half percent",
	)
	var tray_art := fryer.get_node("SharedTray/Artwork") as TextureRect
	_check(tray_art.size.is_equal_approx(WorkbenchArtSpec.CONTAINER_L) and str(tray_art.get_meta(&"workbench_container_size_class", "")) == "L", "fryer output uses the L container component")

	var workstation := WORKSTATION_SCENE.instantiate()
	var background := workstation.get_node("SafeArea/BackgroundArtwork") as TextureRect
	var background_material := background.material as ShaderMaterial
	_check(
		background_material != null and is_equal_approx(float(background_material.get_shader_parameter("wood_contrast")), 0.8),
		"worktop texture contrast is reduced by twenty percent",
	)
	var toppings := workstation.get_node("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots")
	for visual_path in ["SecretSauceSource/Visual", "ScallionTray/Visual", "CorianderTray/Visual"]:
		var visual := toppings.get_node(visual_path) as TextureRect
		_check(visual.size.is_equal_approx(WorkbenchArtSpec.CONTAINER_S) and str(visual.get_meta(&"workbench_container_size_class", "")) == "S", "%s applies the S component (actual size=%s class=%s)" % [visual_path, visual.size, visual.get_meta(&"workbench_container_size_class", "")])
	for visual_path in ["EggCarton/Visual", "BaocuiBasket/Visual", "PorkFlossSource/Visual", "HamSource/Visual"]:
		var visual := toppings.get_node(visual_path) as TextureRect
		_check(visual.size.is_equal_approx(WorkbenchArtSpec.CONTAINER_M) and str(visual.get_meta(&"workbench_container_size_class", "")) == "M", "%s applies the M component" % visual_path)
	var dough := workstation.get_node("SafeArea/YoutiaoDoughPlain") as TextureButton
	var holding := workstation.get_node("FiveAreaInfrastructure/Stations/PancakeHoldingTray") as TextureButton
	_check(str(dough.get_meta(&"workbench_container_size_class", "")) == "L" and str(holding.get_meta(&"workbench_container_size_class", "")) == "L", "large stock and holding trays apply the L component")

	griddle.free()
	soy.free()
	fryer.free()
	workstation.free()
	_finish()


func _material_path(item: CanvasItem) -> String:
	return item.material.resource_path if item != null and item.material != null else ""


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("WORKBENCH_P1_ART_SPEC_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("WORKBENCH_P1_ART_SPEC_SELF_CHECK_FAIL\n%s" % "\n".join(failures))
	quit(1)
