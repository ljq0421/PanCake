class_name FiveAreaWorkstation
extends "res://scripts/gameplay/workstation.gd"

@onready var five_area_infrastructure: Control = $FiveAreaInfrastructure
@onready var fresh_soy_station: Control = $FiveAreaInfrastructure/Stations/FreshSoyMilkStation
@onready var steamer_station: Control = $FiveAreaInfrastructure/Stations/SteamerStation
@onready var five_area_close_button: Button = $FiveAreaInfrastructure/CloseButton

var _open_f4_area_id: StringName = &""


func _ready() -> void:
	super._ready()
	fresh_soy_station.intent_requested.connect(_on_f4_intent.bind(&"area.fresh_soy_milk"))
	steamer_station.intent_requested.connect(_on_f4_intent.bind(&"area.steamer"))
	five_area_close_button.pressed.connect(_close_f4_station)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		var order_signal := Signal(session, &"order_changed")
		if not order_signal.is_connected(_on_formal_shell_changed):
			order_signal.connect(_on_formal_shell_changed)
		var production_signal := Signal(session, &"production_changed")
		if not production_signal.is_connected(_on_formal_shell_changed):
			production_signal.connect(_on_formal_shell_changed)
	_refresh_f4_stations()
	_refresh_formal_shell()


func _process(delta: float) -> void:
	super._process(delta)
	_refresh_formal_shell()


func _open_f3_station(area_id: StringName) -> void:
	if area_id not in [&"area.fresh_soy_milk", &"area.steamer"]:
		super._open_f3_station(area_id)
		return
	_close_f3_station()
	_open_f4_area_id = area_id
	fresh_soy_station.visible = area_id == &"area.fresh_soy_milk"
	steamer_station.visible = area_id == &"area.steamer"
	five_area_close_button.visible = true
	_refresh_f4_stations()
	five_area_close_button.grab_focus()


func _close_f4_station() -> void:
	fresh_soy_station.visible = false
	steamer_station.visible = false
	five_area_close_button.visible = false
	_open_f4_area_id = &""
	_refresh_global_status()


func _on_f4_intent(intent: Dictionary, area_id: StringName) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var action_id := StringName(intent.get("action_id", &""))
	var result: Dictionary
	if area_id == &"area.fresh_soy_milk":
		match action_id:
			&"load": result = session.call("load_f4_soy", StringName(intent.get("recipe_id", &"")), int(intent.get("quantity", 1)))
			&"add_water", &"start": result = session.call("perform_f4_soy_action", action_id)
			&"collect": result = session.call("deliver_f4_soy", _formal_order_id, _active_item_index(area_id), int(intent.get("quantity", 1)), false, -1)
			&"collect_output": result = session.call("deliver_f4_soy", _formal_order_id, _active_item_index(area_id), 1, true, int(intent.get("slot_index", -1)))
			&"discard": result = session.call("discard_f4_soy", int(intent.get("slot_index", -1)))
			_: result = {"success": false, "reason": &"unsupported_action"}
	else:
		var layer_index := int(intent.get("layer_index", 0))
		match action_id:
			&"load": result = session.call("load_f4_steamer", layer_index, StringName(intent.get("recipe_id", &"")), int(intent.get("quantity", 1)))
			&"start": result = session.call("perform_f4_steamer_action", layer_index, &"start")
			&"collect": result = session.call("deliver_f4_steamer", _formal_order_id, _active_item_index(area_id), layer_index)
			&"discard": result = session.call("discard_f4_steamer", layer_index)
			_: result = {"success": false, "reason": &"unsupported_action"}
	if bool(result.get("success", false)):
		_try_settle_f4_order()
	else:
		tool_status_label.text = "操作未完成：%s" % str(result.get("reason", &"unknown"))
	_refresh_f4_stations()


func _active_item_index(area_id: StringName) -> int:
	var session := get_node_or_null("/root/GameSession")
	var active: Dictionary = session.call("active_formal_order") if session != null else {}
	var items := Array(active.get("items", []))
	for index in range(items.size()):
		var item := Dictionary(items[index])
		if StringName(item.get("area_id", &"")) == area_id and int(item.get("attached_quantity", 0)) < int(item.get("quantity", 1)):
			return index
	return -1


func _try_settle_f4_order() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or _formal_order_id.is_empty():
		return
	var active: Dictionary = session.call("active_formal_order")
	for raw_item in Array(active.get("items", [])):
		var item := Dictionary(raw_item)
		if int(item.get("attached_quantity", 0)) < int(item.get("quantity", 1)):
			return
	var settlement: Dictionary = session.call("settle_f3_order", _formal_order_id, false)
	if bool(settlement.get("success", false)):
		_close_f4_station()
		_on_playable_order_finished(settlement)


func _refresh_f4_stations() -> void:
	if not is_node_ready():
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked := Array(progression.get("unlocked_area_ids", []))
	var production := Dictionary(session.call("five_area_production_snapshot"))
	var unlocked_recipes: Variant = progression.get("unlocked_recipe_ids", PackedStringArray())
	var soy_snapshot := Dictionary(production.get("fresh_soy_milk_machine", {})).duplicate(true)
	var steamer_snapshot := Dictionary(production.get("steamer", {})).duplicate(true)
	soy_snapshot["unlocked_recipe_ids"] = unlocked_recipes
	steamer_snapshot["unlocked_recipe_ids"] = unlocked_recipes
	fresh_soy_station.set_locked(not unlocked.has("area.fresh_soy_milk"))
	steamer_station.set_locked(not unlocked.has("area.steamer"))
	fresh_soy_station.set_interaction_enabled(not _formal_order_time_paused())
	steamer_station.set_interaction_enabled(not _formal_order_time_paused())
	fresh_soy_station.apply_snapshot(soy_snapshot)
	steamer_station.apply_snapshot(steamer_snapshot)


func _on_formal_shell_changed(_snapshot: Dictionary = {}) -> void:
	_refresh_f4_stations()
	_refresh_formal_shell()


func _refresh_formal_shell() -> void:
	if not is_node_ready():
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var orders: Array[Dictionary] = []
	var active := Dictionary(session.call("active_formal_order"))
	if not active.is_empty():
		orders.append(active)
	for waiting in Array(session.call("waiting_formal_orders")):
		orders.append(Dictionary(waiting))
	var order_queue := $FiveAreaInfrastructure/OrderQueue
	for index in range(order_queue.get_child_count()):
		var card := order_queue.get_child(index) as PanelContainer
		var label := card.get_node("Summary") as Label
		card.visible = index < orders.size()
		if not card.visible:
			label.text = ""
			continue
		var order := orders[index]
		var position_text := "当前订单" if index == 0 else "候单%d" % index
		var patience_text := "教学单·不限时" if _order_has_no_countdown(order) else (
			"耐心 %d秒" % ceili(float(order.get("remaining_patience_seconds", 0.0)))
			if index == 0
			else "接单后开始计时"
		)
		label.text = "%s｜%s\n%s" % [position_text, _order_product_summary(order), patience_text]
	var entries: Array = Array(session.call("five_area_attention"))
	var rail := $FiveAreaInfrastructure/AttentionRail
	for index in range(rail.get_child_count()):
		var label := rail.get_child(index) as Label
		if index < entries.size():
			var entry := Dictionary(entries[index])
			var severity := StringName(entry.get("severity", &"yellow"))
			label.text = "%s · %.1f秒" % [_attention_label(StringName(entry.get("status_key", &"attention"))), float(entry.get("seconds_to_irreversible_loss", 0.0))]
			label.add_theme_color_override("font_color", Color("ff6b5f") if severity == &"red" else Color("f4c95d"))
			label.visible = true
		else:
			label.visible = false


func _attention_label(status_key: StringName) -> String:
	return {
		&"packaged_drink_ready": "热饮可取",
		&"packaged_drink_overcooking": "热饮即将过热",
		&"youtiao_ready": "油条可起锅",
		&"youtiao_overcooking": "油条即将过火",
		&"fresh_soy_milk_ready": "豆浆可接杯",
		&"fresh_soy_milk_overcooking": "豆浆即将变质",
		&"fresh_soy_milk_blocked": "豆浆输出架已满",
		&"steamer_ready": "蒸品已熟",
		&"steamer_overcooking": "蒸品即将过熟",
		&"soy_output_spoil": "豆浆杯即将变质",
		&"tray_stale": "煎饼暂存即将陈旧",
	}.get(status_key, str(status_key))


func _order_has_no_countdown(order: Dictionary) -> bool:
	if bool(order.get("tutorial_no_countdown", false)) or not StringName(order.get("teaching_area_id", &"")).is_empty():
		return true
	var metadata := Dictionary(order.get("metadata", {}))
	return bool(metadata.get("tutorial_no_countdown", false)) or bool(Dictionary(metadata.get("legacy_order", {})).get("tutorial_no_countdown", false))


func _order_product_summary(order: Dictionary) -> String:
	var labels := PackedStringArray()
	var metadata := Dictionary(order.get("metadata", {}))
	var legacy := Dictionary(metadata.get("legacy_order", {}))
	for raw_item in Array(order.get("items", [])):
		var item := Dictionary(raw_item)
		var product_id := StringName(item.get("product_id", &""))
		var label := ""
		if product_id == &"product.pancake.custom":
			label = str(legacy.get("title", "煎饼"))
		else:
			var product := FIVE_AREA_CATALOG.product_definition(product_id)
			label = str(product.get("label", ""))
			if label.is_empty():
				label = str(FIVE_AREA_CATALOG.recipe_definition(StringName(product.get("recipe_id", &""))).get("label", ""))
		if label.is_empty():
			label = "餐品"
		var quantity := maxi(int(item.get("quantity", 1)), 1)
		labels.append("%s×%d" % [label, quantity] if quantity > 1 else label)
	return "＋".join(labels) if not labels.is_empty() else "待确认餐品"
