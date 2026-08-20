class_name PancakeScorer
extends RefCounted

const UNFLIPPED_DELIVERY_PENALTY := 12.0
const MAX_PORTIONS_PER_REQUIREMENT := 2

static func evaluate_sauce(model: PancakeModel) -> Dictionary:
	return evaluate_sauce_type(model, &"sweet_flour")


static func evaluate_sauce_type(model: PancakeModel, sauce_type: StringName, intensity_multiplier: float = 1.0) -> Dictionary:
	var covered_cells := 0
	var missing_cells := 0
	var excessive_cells := 0
	var sauce_total := 0.0
	var squared_error_total := 0.0
	var normalized_multiplier := maxf(intensity_multiplier, 0.01)
	var target := model.parameters.sauce_target_concentration * normalized_multiplier
	var missing_threshold := model.parameters.sauce_missing_threshold * normalized_multiplier
	var excess_threshold := model.parameters.sauce_excess_threshold * normalized_multiplier
	var sauce_field := model.chili_sauce_concentration if sauce_type == &"red_chili" else model.sauce_concentration
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		covered_cells += 1
		var concentration := sauce_field[index]
		sauce_total += concentration
		var error := concentration - target
		squared_error_total += error * error
		if concentration < missing_threshold:
			missing_cells += 1
		if concentration > excess_threshold:
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
		"target_concentration": target,
		"intensity_multiplier": normalized_multiplier,
		"tags": tags,
	}


static func _portion_counts(values: Array) -> Dictionary:
	var counts := {}
	for value in values:
		var id := StringName(value)
		if id.is_empty():
			continue
		counts[id] = mini(int(counts.get(id, 0)) + 1, MAX_PORTIONS_PER_REQUIREMENT)
	return counts


static func _sauce_portion_count(sauce_result: Dictionary, base_target: float) -> int:
	if float(sauce_result.get("coverage_ratio", 0.0)) <= 0.08:
		return 0
	return clampi(roundi(float(sauce_result.get("mean_concentration", 0.0)) / maxf(base_target, 0.001)), 1, MAX_PORTIONS_PER_REQUIREMENT)


static func _portion_label(display_name: String, portions: int) -> String:
	return display_name if portions <= 1 else "%s×%d" % [display_name, portions]


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
	var front_squared_total := 0.0
	var back_squared_total := 0.0
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
		front_squared_total += model.doneness[index] * model.doneness[index]
		back_squared_total += model.back_doneness[index] * model.back_doneness[index]
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

	var sauce_intensity_multiplier := maxf(float(order.get("sauce_intensity_multiplier", 1.0)), 0.01)
	var required_sauces: Array = order.get("sauces", [])
	var required_sauce_quantities := _portion_counts(required_sauces)
	var sauce_results := {}
	for sauce_type in [OrderService.SAUCE_SWEET, OrderService.SAUCE_CHILI]:
		var portions := int(required_sauce_quantities.get(sauce_type, 1))
		var multiplier := float(portions) * (sauce_intensity_multiplier if sauce_type == OrderService.SAUCE_CHILI else 1.0)
		sauce_results[sauce_type] = evaluate_sauce_type(model, sauce_type, multiplier)
	var applied_sauce_quantities := {}
	for sauce_type in [OrderService.SAUCE_SWEET, OrderService.SAUCE_CHILI]:
		var measured := evaluate_sauce_type(model, sauce_type)
		applied_sauce_quantities[sauce_type] = _sauce_portion_count(measured, model.parameters.sauce_target_concentration)
	var sauce_scores := PackedFloat32Array()
	var missing_sauces := PackedStringArray()
	for sauce_type in required_sauce_quantities:
		var sauce_result: Dictionary = Dictionary(sauce_results.get(StringName(sauce_type), {}))
		sauce_scores.append(float(sauce_result.score))
		var required_portions := int(required_sauce_quantities[sauce_type])
		var applied_portions := int(applied_sauce_quantities.get(sauce_type, 0))
		if applied_portions < required_portions:
			missing_sauces.append(_portion_label(OrderService.sauce_display_name(sauce_type), required_portions - applied_portions))
	var sauce_score := 0.0
	for value in sauce_scores:
		sauce_score += value
	sauce_score /= maxf(float(sauce_scores.size()), 1.0)
	for sauce_type in [OrderService.SAUCE_SWEET, OrderService.SAUCE_CHILI]:
		if required_sauce_quantities.has(sauce_type):
			continue
		var unexpected: Dictionary = Dictionary(sauce_results.get(sauce_type, {}))
		if float(unexpected.coverage_ratio) > 0.08:
			sauce_score = maxf(sauce_score - 24.0, 0.0)

	var required_ingredients: Array = order.get("ingredients", [])
	var required_ingredient_quantities := _portion_counts(required_ingredients)
	var applied_ingredient_quantities := ingredients.quantities()
	var missing_ingredients := PackedStringArray()
	var unexpected_ingredients := PackedStringArray()
	for ingredient_type in required_ingredient_quantities:
		var required_portions := int(required_ingredient_quantities[ingredient_type])
		var applied_portions := int(applied_ingredient_quantities.get(ingredient_type, 0))
		if applied_portions < required_portions:
			missing_ingredients.append(_portion_label(IngredientModel.display_name(ingredient_type), required_portions - applied_portions))
	for ingredient_type in IngredientModel.ALL_TYPES:
		var applied_portions := int(applied_ingredient_quantities.get(ingredient_type, 0))
		var required_portions := int(required_ingredient_quantities.get(ingredient_type, 0))
		if applied_portions > required_portions:
			unexpected_ingredients.append(_portion_label(IngredientModel.display_name(ingredient_type), applied_portions - required_portions))
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
	var unflipped_delivery_penalty := UNFLIPPED_DELIVERY_PENALTY if not model.is_flipped else 0.0
	overall = maxf(overall - unflipped_delivery_penalty, 0.0)
	var score_adjustments := {
		"unflipped_delivery_penalty": unflipped_delivery_penalty,
		"total": -unflipped_delivery_penalty,
	}
	var tags := PackedStringArray()
	if integrity_score >= 85.0:
		tags.append("饼皮完整")
	if thickness_score < 58.0:
		tags.append("厚薄不均")
	if heat_score < 58.0:
		tags.append("两面火候有偏差")
	if sauce_score >= 82.0:
		tags.append("酱料均匀")
	if unflipped_delivery_penalty > 0.0:
		tags.append("未翻面交付（-%d分）" % roundi(unflipped_delivery_penalty))
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
	var applied_ingredient_ids: Array[StringName] = []
	for ingredient_type in IngredientModel.ALL_TYPES:
		if ingredients.has_type(ingredient_type):
			applied_ingredient_ids.append(ingredient_type)
	var applied_sauce_ids: Array[StringName] = []
	for sauce_type in [OrderService.SAUCE_SWEET, OrderService.SAUCE_CHILI]:
		var sauce_portions := int(applied_sauce_quantities.get(sauce_type, 0))
		if sauce_portions > 0:
			applied_sauce_ids.append(sauce_type)
	var serving_sauce_results := {}
	for sauce_type in sauce_results:
		var sauce_result: Dictionary = Dictionary(sauce_results[sauce_type])
		serving_sauce_results[str(sauce_type)] = {
			"score": float(sauce_result.get("score", 0.0)),
			"coverage_ratio": float(sauce_result.get("coverage_ratio", 0.0)),
			"excessive_ratio": float(sauce_result.get("excessive_ratio", 0.0)),
			"mean_concentration": float(sauce_result.get("mean_concentration", 0.0)),
			"uniformity": float(sauce_result.get("uniformity", 0.0)),
			"target_concentration": float(sauce_result.get("target_concentration", 0.0)),
			"intensity_multiplier": float(sauce_result.get("intensity_multiplier", 1.0)),
		}
	var chili_standard := evaluate_sauce_type(model, OrderService.SAUCE_CHILI, 1.0)
	var chili_special := evaluate_sauce_type(model, OrderService.SAUCE_CHILI, 1.35)
	var sauce_profiles := {
		str(OrderService.SAUCE_CHILI): {
			"1.00": _serving_sauce_profile(chili_standard),
			"1.35": _serving_sauce_profile(chili_special),
		},
	}
	var selected_chili := chili_special if is_equal_approx(sauce_intensity_multiplier, 1.35) else Dictionary(sauce_results.get(OrderService.SAUCE_CHILI, {}))
	var spice_target_met := _spice_profile_meets_target(selected_chili)
	var serving_score_basis := {
		"version": 3,
		"production": {
			"was_flipped": model.is_flipped,
			"unflipped_delivery_penalty": unflipped_delivery_penalty,
		},
		"intrinsic_dimensions": {
			"integrity": integrity_score,
			"thickness": thickness_score,
			"egg": egg_score,
			"fold": fold_score,
		},
		"heat_moments": {
			"mean_front": mean_front,
			"mean_back": mean_back,
			"mean_front_squared": front_squared_total / divisor,
			"mean_back_squared": back_squared_total / divisor,
		},
		"sauce_results": serving_sauce_results,
		"sauce_profiles": sauce_profiles,
		"ingredient_distribution_score": float(ingredient_distribution.score),
		"ingredient_distribution_tags": Array(ingredient_distribution.tags).duplicate(),
		"applied_ingredient_ids": applied_ingredient_ids.duplicate(),
		"applied_ingredient_quantities": applied_ingredient_quantities.duplicate(true),
		"applied_sauce_ids": applied_sauce_ids.duplicate(),
		"applied_sauce_quantities": applied_sauce_quantities.duplicate(true),
		"repair_tags": Array(repair_tags).duplicate(),
		"score_caps": score_caps.duplicate(true),
	}
	return {
		"score": overall,
		"score_adjustments": score_adjustments,
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
		"applied_ingredient_ids": applied_ingredient_ids,
		"applied_ingredient_quantities": applied_ingredient_quantities,
		"applied_sauce_ids": applied_sauce_ids,
		"applied_sauce_quantities": applied_sauce_quantities,
		"score_caps": score_caps,
		"serving_score_basis": serving_score_basis,
		"special_evaluation": {
			"sauce_intensity_multiplier": sauce_intensity_multiplier,
			"spice_target_met": spice_target_met,
			"chili_score": float(selected_chili.get("score", 0.0)),
			"chili_coverage_ratio": float(selected_chili.get("coverage_ratio", 0.0)),
			"chili_uniformity": float(selected_chili.get("uniformity", 0.0)),
		},
	}


static func evaluate_stored_product(
	product: Dictionary,
	order: Dictionary,
	elapsed_seconds: float,
	patience_ratio: float
) -> Dictionary:
	var basis: Dictionary = Dictionary(product.get("serving_score_basis", {}))
	if basis.is_empty():
		return {}
	var intrinsic: Dictionary = Dictionary(basis.get("intrinsic_dimensions", {}))
	var integrity_score := float(intrinsic.get("integrity", 0.0))
	var thickness_score := float(intrinsic.get("thickness", 0.0))
	var egg_score := float(intrinsic.get("egg", 0.0))
	var fold_score := float(intrinsic.get("fold", 0.0))

	var heat_target := _heat_target(StringName(order.get("heat_preference", &"golden")))
	var heat_moments: Dictionary = Dictionary(basis.get("heat_moments", {}))
	var mean_front := float(heat_moments.get("mean_front", heat_target))
	var mean_back := float(heat_moments.get("mean_back", heat_target))
	var mean_front_squared := float(heat_moments.get("mean_front_squared", mean_front * mean_front))
	var mean_back_squared := float(heat_moments.get("mean_back_squared", mean_back * mean_back))
	var heat_mse := maxf((
		mean_front_squared - 2.0 * heat_target * mean_front + heat_target * heat_target
		+ mean_back_squared - 2.0 * heat_target * mean_back + heat_target * heat_target
	) * 0.5, 0.0)
	var heat_score := 100.0 * clampf(1.0 - sqrt(heat_mse) / 0.62, 0.0, 1.0)

	var sauce_results: Dictionary = Dictionary(basis.get("sauce_results", {}))
	var sauce_profiles: Dictionary = Dictionary(basis.get("sauce_profiles", {}))
	var sauce_intensity_multiplier := maxf(float(order.get("sauce_intensity_multiplier", 1.0)), 0.01)
	var required_sauces: Array = Array(order.get("sauces", []))
	var required_sauce_quantities := _portion_counts(required_sauces)
	var applied_sauce_quantities: Dictionary = Dictionary(basis.get("applied_sauce_quantities", {}))
	if applied_sauce_quantities.is_empty():
		applied_sauce_quantities = _portion_counts(Array(basis.get("applied_sauce_ids", [])))
	var sauce_score := 0.0
	var sauce_score_count := 0
	var missing_sauces := PackedStringArray()
	for sauce_type_variant in required_sauce_quantities:
		var sauce_type := StringName(sauce_type_variant)
		var sauce_result: Dictionary = Dictionary(sauce_results.get(str(sauce_type), {}))
		if sauce_type == OrderService.SAUCE_CHILI:
			var chili_profiles := Dictionary(sauce_profiles.get(str(OrderService.SAUCE_CHILI), {}))
			var profile_key := "1.35" if is_equal_approx(sauce_intensity_multiplier, 1.35) else "1.00"
			var target_profile := Dictionary(chili_profiles.get(profile_key, {}))
			if not target_profile.is_empty():
				sauce_result = target_profile
		sauce_score += float(sauce_result.get("score", 0.0))
		sauce_score_count += 1
		var required_portions := int(required_sauce_quantities[sauce_type])
		var applied_portions := int(applied_sauce_quantities.get(sauce_type, applied_sauce_quantities.get(str(sauce_type), 0)))
		if applied_portions < required_portions:
			missing_sauces.append(_portion_label(OrderService.sauce_display_name(sauce_type), required_portions - applied_portions))
	if sauce_score_count > 0:
		sauce_score /= float(sauce_score_count)
	for sauce_type in [OrderService.SAUCE_SWEET, OrderService.SAUCE_CHILI]:
		if required_sauce_quantities.has(sauce_type):
			continue
		var unexpected: Dictionary = Dictionary(sauce_results.get(str(sauce_type), {}))
		if float(unexpected.get("coverage_ratio", 0.0)) > 0.08:
			sauce_score = maxf(sauce_score - 24.0, 0.0)

	var required_ingredients: Array = Array(order.get("ingredients", []))
	var required_ingredient_quantities := _portion_counts(required_ingredients)
	var applied_ingredient_quantities: Dictionary = Dictionary(basis.get("applied_ingredient_quantities", {}))
	if applied_ingredient_quantities.is_empty():
		applied_ingredient_quantities = _portion_counts(Array(basis.get("applied_ingredient_ids", [])))
	var missing_ingredients := PackedStringArray()
	var unexpected_ingredients := PackedStringArray()
	for ingredient_type_variant in required_ingredient_quantities:
		var ingredient_type := StringName(ingredient_type_variant)
		var required_portions := int(required_ingredient_quantities[ingredient_type])
		var applied_portions := int(applied_ingredient_quantities.get(ingredient_type, applied_ingredient_quantities.get(str(ingredient_type), 0)))
		if applied_portions < required_portions:
			missing_ingredients.append(_portion_label(IngredientModel.display_name(ingredient_type), required_portions - applied_portions))
	for ingredient_type in IngredientModel.ALL_TYPES:
		var applied_portions := int(applied_ingredient_quantities.get(ingredient_type, applied_ingredient_quantities.get(str(ingredient_type), 0)))
		var required_portions := int(required_ingredient_quantities.get(ingredient_type, 0))
		if applied_portions > required_portions:
			unexpected_ingredients.append(_portion_label(IngredientModel.display_name(ingredient_type), applied_portions - required_portions))
	var applied_ingredients: Array[StringName] = []
	for ingredient_type in IngredientModel.ALL_TYPES:
		if int(applied_ingredient_quantities.get(ingredient_type, applied_ingredient_quantities.get(str(ingredient_type), 0))) > 0:
			applied_ingredients.append(ingredient_type)
	var ingredient_match := 1.0 - float(missing_ingredients.size() + unexpected_ingredients.size()) / maxf(float(required_ingredients.size() + 1), 1.0)
	var ingredient_score := clampf(float(basis.get("ingredient_distribution_score", 0.0)) * 0.45 + 100.0 * ingredient_match * 0.55, 0.0, 100.0)
	var order_score := clampf(
		100.0
		- float(missing_ingredients.size()) * 22.0
		- float(unexpected_ingredients.size()) * 14.0
		- float(missing_sauces.size()) * 24.0,
		0.0,
		100.0
	)
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
	# Older stored products do not contain production metadata, so their original
	# score remains unchanged rather than retroactively receiving this penalty.
	var production: Dictionary = Dictionary(basis.get("production", {}))
	var unflipped_delivery_penalty := maxf(float(production.get("unflipped_delivery_penalty", 0.0)), 0.0)
	overall = maxf(overall - unflipped_delivery_penalty, 0.0)
	var score_adjustments := {
		"unflipped_delivery_penalty": unflipped_delivery_penalty,
		"total": -unflipped_delivery_penalty,
	}
	var tags := PackedStringArray()
	if integrity_score >= 85.0:
		tags.append("饼皮完整")
	if thickness_score < 58.0:
		tags.append("厚薄不均")
	if heat_score < 58.0:
		tags.append("两面火候有偏差")
	if sauce_score >= 82.0:
		tags.append("酱料均匀")
	if unflipped_delivery_penalty > 0.0:
		tags.append("未翻面交付（-%d分）" % roundi(unflipped_delivery_penalty))
	if not missing_ingredients.is_empty():
		tags.append("缺少%s" % "、".join(missing_ingredients))
	if not unexpected_ingredients.is_empty():
		tags.append("多放%s" % "、".join(unexpected_ingredients))
	for tag_variant in Array(basis.get("ingredient_distribution_tags", [])):
		var tag := str(tag_variant)
		if not tags.has(tag):
			tags.append(tag)
	for tag_variant in Array(basis.get("repair_tags", [])):
		tags.append(str(tag_variant))
	var selected_chili_profile := Dictionary(sauce_results.get(str(OrderService.SAUCE_CHILI), {}))
	var stored_chili_profiles := Dictionary(sauce_profiles.get(str(OrderService.SAUCE_CHILI), {}))
	var stored_profile_key := "1.35" if is_equal_approx(sauce_intensity_multiplier, 1.35) else "1.00"
	if stored_chili_profiles.has(stored_profile_key):
		selected_chili_profile = Dictionary(stored_chili_profiles.get(stored_profile_key, {}))
	return {
		"score": overall,
		"score_adjustments": score_adjustments,
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
			"mean_front_doneness": mean_front,
			"mean_back_doneness": mean_back,
			"heat_target": heat_target,
		},
		"tags": tags,
		"feedback": _feedback_for(overall, tags, patience_ratio),
		"missing_ingredients": missing_ingredients,
		"missing_sauces": missing_sauces,
		"applied_ingredient_ids": applied_ingredients.duplicate(),
		"applied_ingredient_quantities": Dictionary(basis.get("applied_ingredient_quantities", {})).duplicate(true),
		"applied_sauce_ids": Array(basis.get("applied_sauce_ids", [])).duplicate(),
		"score_caps": Dictionary(basis.get("score_caps", {})).duplicate(true),
		"special_evaluation": {
			"sauce_intensity_multiplier": sauce_intensity_multiplier,
			"spice_target_met": _spice_profile_meets_target(selected_chili_profile),
			"chili_score": float(selected_chili_profile.get("score", 0.0)),
			"chili_coverage_ratio": float(selected_chili_profile.get("coverage_ratio", 0.0)),
			"chili_uniformity": float(selected_chili_profile.get("uniformity", 0.0)),
		},
	}


static func _serving_sauce_profile(source: Dictionary) -> Dictionary:
	return {
		"score": float(source.get("score", 0.0)),
		"coverage_ratio": float(source.get("coverage_ratio", 0.0)),
		"excessive_ratio": float(source.get("excessive_ratio", 0.0)),
		"mean_concentration": float(source.get("mean_concentration", 0.0)),
		"uniformity": float(source.get("uniformity", 0.0)),
		"target_concentration": float(source.get("target_concentration", 0.0)),
		"intensity_multiplier": float(source.get("intensity_multiplier", 1.0)),
	}


static func _spice_profile_meets_target(profile: Dictionary) -> bool:
	return (
		float(profile.get("score", 0.0)) >= 82.0
		and float(profile.get("coverage_ratio", 0.0)) >= 0.75
		and float(profile.get("uniformity", 0.0)) >= 0.65
	)


static func _heat_target(preference: StringName) -> float:
	match preference:
		&"light":
			return 0.48
		&"well_done":
			return 0.76
	return 0.64


static func heat_target_for(preference: StringName) -> float:
	return _heat_target(preference)


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
