class_name PancakeScorer
extends RefCounted


static func evaluate_sauce(model: PancakeModel) -> Dictionary:
	return evaluate_sauce_type(model, &"sweet_flour")


static func evaluate_sauce_type(model: PancakeModel, sauce_type: StringName) -> Dictionary:
	var covered_cells := 0
	var missing_cells := 0
	var excessive_cells := 0
	var sauce_total := 0.0
	var squared_error_total := 0.0
	var target := model.parameters.sauce_target_concentration
	var sauce_field := model.chili_sauce_concentration if sauce_type == &"red_chili" else model.sauce_concentration
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		covered_cells += 1
		var concentration := sauce_field[index]
		sauce_total += concentration
		var error := concentration - target
		squared_error_total += error * error
		if concentration < model.parameters.sauce_missing_threshold:
			missing_cells += 1
		if concentration > model.parameters.sauce_excess_threshold:
			excessive_cells += 1
	var divisor := maxf(float(covered_cells), 1.0)
	var coverage_ratio := 1.0 - float(missing_cells) / divisor
	var excessive_ratio := float(excessive_cells) / divisor
	var mean_concentration := sauce_total / divisor
	var root_mean_square_error := sqrt(squared_error_total / divisor)
	var uniformity := 1.0 - clampf(root_mean_square_error / maxf(target, 0.001), 0.0, 1.0)
	var raw_score := 100.0 * clampf(coverage_ratio * 0.55 + uniformity * 0.35 + (1.0 - excessive_ratio) * 0.10, 0.0, 1.0)
	var score := raw_score
	var tags := PackedStringArray()
	if covered_cells <= 0:
		tags.append("暂无面饼")
	elif coverage_ratio >= 0.90 and uniformity >= 0.78 and excessive_ratio <= 0.04:
		tags.append("酱料均匀")
	if coverage_ratio < 0.75:
		tags.append("局部缺酱")
	if excessive_ratio > 0.08:
		tags.append("酱料过量")
	if coverage_ratio >= 0.45 and uniformity < 0.45:
		tags.append("刷痕断续")
	return {
		"score": score,
		"raw_score": raw_score,
		"coverage_ratio": coverage_ratio,
		"excessive_ratio": excessive_ratio,
		"mean_concentration": mean_concentration,
		"uniformity": uniformity,
		"tags": tags,
	}


static func evaluate_order(
	model: PancakeModel,
	ingredients: IngredientModel,
	fold_model: PancakeFoldModel,
	order: Dictionary,
	elapsed_seconds: float,
	patience_ratio: float
) -> Dictionary:
	var covered_indices := PackedInt32Array()
	var damaged := 0
	var thickness_total := 0.0
	var thickness_squared_total := 0.0
	var front_total := 0.0
	var back_total := 0.0
	var heat_squared_error := 0.0
	var heat_target := _heat_target(order.get("heat_preference", &"golden"))
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		covered_indices.append(index)
		var thickness := model.thickness[index]
		thickness_total += thickness
		thickness_squared_total += thickness * thickness
		front_total += model.doneness[index]
		back_total += model.back_doneness[index]
		var front_error := model.doneness[index] - heat_target
		var back_error := model.back_doneness[index] - heat_target
		heat_squared_error += (front_error * front_error + back_error * back_error) * 0.5
		if model.damage[index] > 0.15:
			damaged += 1
	var divisor := maxf(float(covered_indices.size()), 1.0)
	var pan_summary := model.calculate_summary()
	var coverage_ratio := float(pan_summary.coverage_ratio)
	var damage_ratio := float(damaged) / divisor
	var integrity_score := 100.0 * clampf(minf(coverage_ratio / 0.78, 1.0) * 0.72 + (1.0 - damage_ratio) * 0.28, 0.0, 1.0)
	var mean_thickness := thickness_total / divisor
	var thickness_variance := maxf(thickness_squared_total / divisor - mean_thickness * mean_thickness, 0.0)
	var thickness_score := 100.0 * clampf(1.0 - sqrt(thickness_variance) / 0.42 - absf(mean_thickness - 0.42) / 1.2, 0.0, 1.0)
	var mean_front := front_total / divisor
	var mean_back := back_total / divisor
	var heat_rmse := sqrt(heat_squared_error / divisor)
	var heat_score := 100.0 * clampf(1.0 - heat_rmse / 0.62, 0.0, 1.0)
	var egg_result := model.calculate_egg_spread_summary()
	var egg_score := float(egg_result.score)

	var required_sauces: Array = order.get("sauces", [])
	var sauce_scores := PackedFloat32Array()
	var missing_sauces := PackedStringArray()
	for sauce_type in required_sauces:
		var sauce_result := evaluate_sauce_type(model, sauce_type)
		sauce_scores.append(float(sauce_result.score))
		if float(sauce_result.coverage_ratio) < 0.35:
			missing_sauces.append(OrderService.sauce_display_name(sauce_type))
	var sauce_score := 0.0
	for value in sauce_scores:
		sauce_score += value
	sauce_score /= maxf(float(sauce_scores.size()), 1.0)
	for sauce_type in [OrderService.SAUCE_SWEET, OrderService.SAUCE_CHILI]:
		if required_sauces.has(sauce_type):
			continue
		var unexpected := evaluate_sauce_type(model, sauce_type)
		if float(unexpected.coverage_ratio) > 0.08:
			sauce_score = maxf(sauce_score - 24.0, 0.0)

	var required_ingredients: Array = order.get("ingredients", [])
	var missing_ingredients := PackedStringArray()
	var unexpected_ingredients := PackedStringArray()
	for ingredient_type in required_ingredients:
		if not ingredients.has_type(ingredient_type):
			missing_ingredients.append(IngredientModel.display_name(ingredient_type))
	for ingredient_type in IngredientModel.TYPES:
		if ingredients.has_type(ingredient_type) and not required_ingredients.has(ingredient_type):
			unexpected_ingredients.append(IngredientModel.display_name(ingredient_type))
	var ingredient_distribution := ingredients.evaluate_distribution(model.grid_size)
	var ingredient_match := 1.0 - float(missing_ingredients.size() + unexpected_ingredients.size()) / maxf(float(required_ingredients.size() + 1), 1.0)
	var ingredient_score := clampf(float(ingredient_distribution.score) * 0.45 + 100.0 * ingredient_match * 0.55, 0.0, 100.0)

	var fold_score := 100.0 - float(fold_model.maximum_severity()) * 28.0
	var repair_tags := PackedStringArray()
	var score_caps := {"fold": 100.0}
	if fold_model.package_result == PancakeFoldModel.PACKAGE_SLEEVE:
		fold_score -= 18.0
		score_caps.fold = 90.0
		fold_score = minf(fold_score, float(score_caps.fold))
		repair_tags.append("纸套加固")
	elif fold_model.package_result == PancakeFoldModel.PACKAGE_TRAY:
		fold_score -= 42.0
		score_caps.fold = 55.0
		fold_score = minf(fold_score, float(score_caps.fold))
		repair_tags.append("托盘挽救")
	fold_score = clampf(fold_score, 0.0, 100.0)
	var order_score := 100.0
	order_score -= float(missing_ingredients.size()) * 22.0
	order_score -= float(unexpected_ingredients.size()) * 14.0
	order_score -= float(missing_sauces.size()) * 24.0
	order_score = clampf(order_score, 0.0, 100.0)
	var time_limit := maxf(float(order.get("time_limit", 72.0)), 1.0)
	var time_score := 100.0 * clampf(1.0 - maxf(elapsed_seconds - time_limit * 0.55, 0.0) / (time_limit * 0.75), 0.0, 1.0)
	var overall := (
		integrity_score * 0.13
		+ thickness_score * 0.12
		+ heat_score * 0.15
		+ egg_score * 0.08
		+ sauce_score * 0.13
		+ ingredient_score * 0.12
		+ fold_score * 0.12
		+ order_score * 0.11
		+ time_score * 0.04
	)
	var tags := PackedStringArray()
	if integrity_score >= 85.0:
		tags.append("饼皮完整")
	if thickness_score < 58.0:
		tags.append("厚薄不均")
	if heat_score < 58.0:
		tags.append("两面火候有偏差")
	if sauce_score >= 82.0:
		tags.append("酱料均匀")
	for egg_tag in egg_result.tags:
		if not tags.has(egg_tag):
			tags.append(egg_tag)
	if not missing_ingredients.is_empty():
		tags.append("缺少%s" % "、".join(missing_ingredients))
	if not unexpected_ingredients.is_empty():
		tags.append("多放%s" % "、".join(unexpected_ingredients))
	for tag in ingredient_distribution.tags:
		if not tags.has(tag):
			tags.append(tag)
	for tag in repair_tags:
		tags.append(tag)
	var feedback := _feedback_for(overall, tags, patience_ratio)
	return {
		"score": overall,
		"dimensions": {
			"integrity": integrity_score,
			"thickness": thickness_score,
			"heat": heat_score,
			"egg": egg_score,
			"sauce": sauce_score,
			"ingredients": ingredient_score,
			"fold": fold_score,
			"order": order_score,
			"time": time_score,
		},
		"metrics": {
			"coverage_ratio": coverage_ratio,
			"damage_ratio": damage_ratio,
			"mean_thickness": mean_thickness,
			"mean_front_doneness": mean_front,
			"mean_back_doneness": mean_back,
			"heat_target": heat_target,
			"egg_coverage_ratio": float(egg_result.coverage_ratio),
			"egg_uniformity": float(egg_result.uniformity),
			"mean_egg_doneness": float(egg_result.mean_doneness),
		},
		"tags": tags,
		"feedback": feedback,
		"missing_ingredients": missing_ingredients,
		"missing_sauces": missing_sauces,
		"score_caps": score_caps,
	}


static func _heat_target(preference: StringName) -> float:
	match preference:
		&"light":
			return 0.48
		&"well_done":
			return 0.76
	return 0.64


static func _feedback_for(score: float, tags: PackedStringArray, patience_ratio: float) -> String:
	if tags.has("蛋黄没有摊开") or tags.has("鸡蛋覆盖不足"):
		return "鸡蛋还没摊开，翻面前要让蛋黄和蛋白铺到更大的饼面。"
	if tags.has("鸡蛋厚薄不均") or tags.has("鸡蛋局部堆积"):
		return "鸡蛋有些地方堆得太厚，画圈时再连续、均匀一些。"
	if tags.has("两面火候有偏差"):
		return "两面的火候差得有点多，下次翻面后再稳一会儿。"
	if tags.has("厚薄不均"):
		return "有些地方偏厚，不过整体还能吃得挺香。"
	for tag in tags:
		if tag.begins_with("缺少") or tag.begins_with("多放"):
			return "%s，订单还是要看清楚。" % tag
	if patience_ratio <= 0.12:
		return "味道不错，就是等得有点久。"
	if score >= 86.0:
		return "边缘脆、酱也匀，这张做得很稳。"
	if score >= 70.0:
		return "整体不错，再把细节收一收就更好了。"
	return "能吃，但面饼、酱料和折叠都还有提升空间。"
