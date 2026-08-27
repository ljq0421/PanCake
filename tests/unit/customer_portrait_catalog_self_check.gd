extends SceneTree

const CATALOG_SCRIPT := preload("res://scripts/ui/customer_portrait_catalog.gd")
const WORKSTATION_SCRIPT_PATH := "res://scripts/gameplay/workstation.gd"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: RefCounted = CATALOG_SCRIPT.new()
	for customer_id in CATALOG_SCRIPT.CUSTOMER_IDS:
		for state in CATALOG_SCRIPT.STATES:
			var path := str(catalog.call("resource_path_for", customer_id, state))
			_check(ResourceLoader.exists(path, "Texture2D"), "%s %s portrait path exists" % [customer_id, state])

	var workstation_file := FileAccess.open(WORKSTATION_SCRIPT_PATH, FileAccess.READ)
	_check(workstation_file != null, "workstation source is readable for preload contract")
	if workstation_file != null:
		var workstation_source := workstation_file.get_as_text()
		workstation_file.close()
		_check(
			'preload("res://resources/art/customers/' not in workstation_source,
			"gameplay startup does not eagerly preload customer portraits"
		)

	var visible_ids: Array[StringName] = [&"customer_01", &"customer_20"]
	catalog.call("set_visible_customers", visible_ids)
	var first_neutral := catalog.call("texture_for", &"customer_01", &"neutral") as Texture2D
	var last_neutral := catalog.call("texture_for", &"customer_20", &"neutral") as Texture2D
	var fallback := catalog.call("texture_for", &"customer_unknown", &"unknown_state") as Texture2D
	_check(first_neutral != null and last_neutral != null, "visible neutral portraits load synchronously")
	_check(fallback == first_neutral, "unknown customer and state fall back to customer_01 neutral")
	_check(int(catalog.call("cached_resource_count")) == 2, "entry cache contains only requested visible neutral portraits")

	catalog.call("enable_reaction_prewarm")
	for _frame in 600:
		catalog.call("poll")
		if bool(catalog.call("has_cached", &"customer_20", &"paying_coins")):
			break
		await process_frame
	_check(bool(catalog.call("has_cached", &"customer_20", &"paying_coins")), "visible reaction portraits finish threaded prewarming")

	catalog.call("set_visible_customers", [&"customer_01"] as Array[StringName])
	_check(not bool(catalog.call("has_cached", &"customer_20", &"neutral")), "customer cache releases portraits that leave the visible queue")
	catalog.call("set_visible_customers", [] as Array[StringName])
	catalog.call("finish_pending")
	catalog = null
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CUSTOMER_PORTRAIT_CATALOG_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_PORTRAIT_CATALOG_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
