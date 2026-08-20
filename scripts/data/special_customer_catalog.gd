class_name SpecialCustomerCatalog
extends RefCounted

## Central, data-only contract for special storefront customers.  These IDs are
## deliberately separate from the ordinary customer_01..customer_20 rotation.
const GLUTTON := &"special.glutton"
const STUDENT := &"special.student"
const SPICY_FAN := &"special.spicy_fan"
const BLOGGER := &"special.blogger"

const SPECIAL_CUSTOMER_IDS: Array[StringName] = [GLUTTON, STUDENT, SPICY_FAN, BLOGGER]
const SPECIAL_ROLE_IDS: Array[StringName] = [
	&"customer_special_glutton",
	&"customer_special_student",
	&"customer_special_spicy_fan",
	&"customer_special_blogger",
]

const DEFINITIONS := {
	GLUTTON: {
		"customer_id": &"customer_special_glutton",
		"title": "超能吃大胃王",
		"customer_line": "今天特别饿，给我来三份，至少要两种不一样的！",
		"rule_text": "至少两类餐品 · 共3份 · 完成金币+20%",
		"patience_seconds": 150.0,
		"unlock_completed_area_ids": [&"area.youtiao"],
	},
	STUDENT: {
		"customer_id": &"customer_special_student",
		"title": "手头拮据的学生",
		"customer_line": "预算有点紧，麻烦给我最实惠的经典简餐，谢谢。",
		"rule_text": "最低价经典简餐 · 成功额外口碑+2",
		"patience_seconds": 90.0,
		"unlock_completed_area_ids": [&"area.pancake"],
	},
	SPICY_FAN: {
		"customer_id": &"customer_special_spicy_fan",
		"title": "爆辣爱好者",
		"customer_line": "只刷辣酱，辣度再往上提一档，还要刷得均匀！",
		"rule_text": "只用辣酱 · 目标辣度×1.35 · 达标金币+35%",
		"patience_seconds": 80.0,
		"unlock_stock_ids": [&"stock.pancake.sauce.red_chili"],
	},
	BLOGGER: {
		"customer_id": &"customer_special_blogger",
		"title": "探店博主",
		"customer_line": "今天做一期早餐摊探店，拿出你们最稳的水准吧。",
		"rule_text": "全A金币+50%且总口碑+8 · 含C或失败口碑-4",
		"unlock_completed_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"],
	},
}


static func definition(special_id: StringName) -> Dictionary:
	return Dictionary(DEFINITIONS.get(special_id, {})).duplicate(true)


static func is_special_id(special_id: StringName) -> bool:
	return SPECIAL_CUSTOMER_IDS.has(special_id)


static func is_special_role_id(customer_id: StringName) -> bool:
	return SPECIAL_ROLE_IDS.has(customer_id)


static func eligible_ids(progression: Dictionary) -> Array[StringName]:
	var completed := _id_set(Dictionary(progression.get("tutorial", {})).get("completed_area_ids", []))
	var unlocked_stocks := _id_set(progression.get("unlocked_stock_ids", []))
	var result: Array[StringName] = []
	for special_id in SPECIAL_CUSTOMER_IDS:
		var entry := definition(special_id)
		var eligible := true
		for area_id_variant in Array(entry.get("unlock_completed_area_ids", [])):
			if not completed.has(StringName(area_id_variant)):
				eligible = false
				break
		if not eligible:
			continue
		for stock_id_variant in Array(entry.get("unlock_stock_ids", [])):
			if not unlocked_stocks.has(StringName(stock_id_variant)):
				eligible = false
				break
		if eligible:
			result.append(special_id)
	return result


static func default_state(current_day: int = 1) -> Dictionary:
	return {
		"day": maxi(current_day, 1),
		"generated_today": 0,
		"last_generated_sequence": -1000,
		"last_special_id": &"",
	}


static func normalize_state(source: Dictionary, current_day: int) -> Dictionary:
	var state := default_state(current_day)
	state["last_generated_sequence"] = int(source.get("last_generated_sequence", -1000))
	var last_special_id := StringName(source.get("last_special_id", &""))
	state["last_special_id"] = last_special_id if is_special_id(last_special_id) else &""
	if int(source.get("day", current_day)) == current_day:
		state["generated_today"] = clampi(int(source.get("generated_today", 0)), 0, 3)
	return state


static func _id_set(values: Variant) -> Dictionary:
	var result := {}
	for value in Array(values):
		result[StringName(value)] = true
	return result
