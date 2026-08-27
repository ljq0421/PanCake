extends SceneTree

const GAME_SCENE := preload("res://scenes/main/main.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null and game_session.has_method("begin_new_game"):
		game_session.call("begin_new_game")
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var workstation := game.get_node("Workstation")
	var daily_bill := workstation.get_node("SafeArea/DailyBillPanel") as Control
	var pause_dim := game.get_node("PauseDim") as ColorRect
	var pause_panel := game.get_node("PausePanel") as PanelContainer

	workstation.call("end_business_day", {"reason": &"test_early_end"})
	await process_frame
	game.call("_set_paused", true)
	_check(not paused and not pause_dim.visible and not pause_panel.visible, "结算弹层打开时不会再叠加暂停弹层")

	daily_bill.visible = false
	game.call("_set_paused", true)
	_check(paused and pause_dim.visible and pause_panel.visible, "无阻塞弹层时暂停遮罩与暂停面板同步出现")
	game.call("_set_paused", false)
	_check(not paused and not pause_dim.visible and not pause_panel.visible, "继续游戏会同步关闭暂停遮罩与暂停面板")

	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PAUSE_MODAL_EXCLUSION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PAUSE_MODAL_EXCLUSION_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
