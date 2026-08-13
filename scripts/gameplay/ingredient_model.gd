class_name IngredientModel
extends RefCounted

signal changed

const EGG: StringName = &"egg"
const BAOCUI: StringName = &"baocui"
const HAM_SAUSAGE: StringName = &"ham_sausage"
const SCALLION: StringName = &"scallion"
const MEAT_FLOSS: StringName = &"meat_floss"
const PORK_TENDERLOIN: StringName = &"pork_tenderloin"
const CORIANDER: StringName = &"coriander"
const PRESERVED_MUSTARD: StringName = &"preserved_mustard"
const YOUTIAO: StringName = &"youtiao"
const TYPES: Array[StringName] = [EGG, BAOCUI, HAM_SAUSAGE, SCALLION, MEAT_FLOSS, PORK_TENDERLOIN, CORIANDER, PRESERVED_MUSTARD]
const ALL_TYPES: Array[StringName] = [EGG, BAOCUI, HAM_SAUSAGE, SCALLION, MEAT_FLOSS, PORK_TENDERLOIN, CORIANDER, PRESERVED_MUSTARD, YOUTIAO]

const DEFINITIONS := {
	EGG: {"label": "鸡蛋", "structural_load": 0.16, "wetness": 0.30},
	BAOCUI: {"label": "薄脆", "structural_load": 0.42, "wetness": 0.0},
	HAM_SAUSAGE: {"label": "火腿肠", "structural_load": 0.34, "wetness": 0.05},
	SCALLION: {"label": "葱花", "structural_load": 0.06, "wetness": 0.04},
	MEAT_FLOSS: {"label": "肉松", "structural_load": 0.20, "wetness": 0.02},
	PORK_TENDERLOIN: {"label": "里脊肉", "structural_load": 0.55, "wetness": 0.08},
	CORIANDER: {"label": "香菜", "structural_load": 0.03, "wetness": 0.02},
	PRESERVED_MUSTARD: {"label": "榨菜", "structural_load": 0.10, "wetness": 0.03},
	YOUTIAO: {"label": "原味油条", "structural_load": 0.55, "wetness": 0.02},
}

var placements: Array[Dictionary] = []
var revision := 0


func reset() -> void:
	placements.clear()
	revision += 1
	changed.emit()


func snapshot() -> Dictionary:
	var serialized: Array[Dictionary] = []
	for placement in placements:
		var position := Vector2(placement.get("position", Vector2.ZERO))
		serialized.append({
			"type": StringName(placement.get("type", &"")),
			"position": [position.x, position.y],
			"rotation": float(placement.get("rotation", 0.0)),
			"structural_load": float(placement.get("structural_load", 0.0)),
			"wetness": float(placement.get("wetness", 0.0)),
			"damaged": bool(placement.get("damaged", false)),
		})
	return {"version": 1, "revision": revision, "placements": serialized}


func load_snapshot(value: Dictionary) -> Dictionary:
	placements.clear()
	for placement_value in Array(value.get("placements", [])):
		var source := Dictionary(placement_value)
		var ingredient_type := StringName(source.get("type", &""))
		var position_values := Array(source.get("position", []))
		if not ALL_TYPES.has(ingredient_type) or position_values.size() != 2:
			return {"success": false, "reason": &"invalid_ingredient_snapshot"}
		placements.append({
			"type": ingredient_type,
			"position": Vector2(float(position_values[0]), float(position_values[1])),
			"rotation": float(source.get("rotation", 0.0)),
			"structural_load": float(source.get("structural_load", DEFINITIONS[ingredient_type].get("structural_load", 0.0))),
			"wetness": float(source.get("wetness", DEFINITIONS[ingredient_type].get("wetness", 0.0))),
			"damaged": bool(source.get("damaged", false)),
		})
	revision = maxi(int(value.get("revision", placements.size())), 0)
	changed.emit()
	return {"success": true}


func place(ingredient_type: StringName, grid_position: Vector2, rotation: float, pancake_model: PancakeModel) -> Dictionary:
	if not ALL_TYPES.has(ingredient_type):
		return {"success": false, "reason": "未知配料"}
	if pancake_model == null:
		return {"success": false, "reason": "面饼数据尚未准备"}
	var cell := Vector2i(roundi(grid_position.x), roundi(grid_position.y))
	var index := pancake_model.index_of(cell)
	if index < 0 or not pancake_model.is_inside_pan(grid_position):
		return {"success": false, "reason": "请把配料放在鏊面内"}
	if pancake_model.coverage[index] <= 0.0 or pancake_model.damage[index] >= pancake_model.parameters.hole_damage_threshold:
		return {"success": false, "reason": "配料必须落在完整饼皮上"}
	var definition: Dictionary = DEFINITIONS[ingredient_type]
	var placement := {
		"type": ingredient_type,
		"position": grid_position,
		"rotation": rotation,
		"structural_load": float(definition.structural_load),
		"wetness": float(definition.wetness),
		"damaged": false,
	}
	placements.append(placement)
	revision += 1
	changed.emit()
	return {"success": true, "placement": placement.duplicate(true)}


func count_type(ingredient_type: StringName) -> int:
	var count := 0
	for placement in placements:
		if placement.get("type", &"") as StringName == ingredient_type:
			count += 1
	return count


func has_type(ingredient_type: StringName) -> bool:
	return count_type(ingredient_type) > 0


func has_toppings() -> bool:
	for placement in placements:
		if StringName(placement.get("type", &"")) != EGG:
			return true
	return false


func quantities() -> Dictionary:
	var result := {}
	for ingredient_type in ALL_TYPES:
		result[ingredient_type] = count_type(ingredient_type)
	return result


func placement_metrics_for_region(region: StringName, line_x: float) -> Dictionary:
	var count := 0
	var structural_load := 0.0
	var wetness := 0.0
	for placement in placements:
		var position: Vector2 = placement.position
		if region == &"left" and position.x > line_x:
			continue
		if region == &"right" and position.x < line_x:
			continue
		count += 1
		structural_load += float(placement.structural_load)
		wetness += float(placement.wetness)
	return {"count": count, "structural_load": structural_load, "wetness": wetness}


func evaluate_distribution(grid_size: int) -> Dictionary:
	if placements.is_empty():
		return {"score": 0.0, "center_distance": 1.0, "edge_ratio": 1.0, "tags": PackedStringArray(["没有配料"])}
	var center := Vector2(grid_size - 1, grid_size - 1) * 0.5
	var maximum_radius := maxf(float(grid_size) * 0.5, 1.0)
	var center_distance_total := 0.0
	var edge_count := 0
	for placement in placements:
		var normalized_distance := (placement.position as Vector2).distance_to(center) / maximum_radius
		center_distance_total += normalized_distance
		if normalized_distance > 0.72:
			edge_count += 1
	var mean_distance := center_distance_total / float(placements.size())
	var edge_ratio := float(edge_count) / float(placements.size())
	var score := 100.0 * clampf(1.0 - absf(mean_distance - 0.34) * 1.35 - edge_ratio * 0.55, 0.0, 1.0)
	var tags := PackedStringArray()
	if score >= 82.0:
		tags.append("配料分布稳妥")
	if edge_ratio > 0.24:
		tags.append("配料靠边易漏")
	if mean_distance < 0.14:
		tags.append("配料堆在中央")
	return {"score": score, "center_distance": mean_distance, "edge_ratio": edge_ratio, "tags": tags}


static func display_name(ingredient_type: StringName) -> String:
	return str((DEFINITIONS.get(ingredient_type, {"label": "未知配料"}) as Dictionary).label)
