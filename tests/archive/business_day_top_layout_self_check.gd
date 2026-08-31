extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame

	var safe_area := workstation.get_node("SafeArea") as Control
	var status_background := safe_area.get_node("GlobalStatusBackground") as Control
	var timer_background := safe_area.get_node("BusinessDayTimerBackground") as Control
	var summary_card := safe_area.get_node("OrderSummaryCard") as Control
	var compact_status := safe_area.get_node("BottomStrip") as Control
	var top_warning := safe_area.get_node("TopWarningLabel") as Control
	var attention_rail := workstation.get_node("FiveAreaInfrastructure/AttentionRail") as Control
	var attention_label := attention_rail.get_node("Attention01") as Label
	var first_order_panel := safe_area.get_node("ServiceCustomer1/OrderPanel") as Control
	var instructions := compact_status.get_node("Instructions") as Label

	_check(not _rects_overlap(status_background.get_global_rect(), timer_background.get_global_rect()), "经营数据与倒计时使用独立区域")
	_check(not _rects_overlap(timer_background.get_global_rect(), summary_card.get_global_rect()), "倒计时与本单结算使用独立区域")
	_check(not _rects_overlap(compact_status.get_global_rect(), top_warning.get_global_rect()), "操作状态与瞬时警告使用独立区域")
	_check(not _rects_overlap(top_warning.get_global_rect(), attention_rail.get_global_rect()), "瞬时警告与设备告警使用独立区域")
	_check(compact_status.get_global_rect().end.y < first_order_panel.get_global_rect().position.y, "顶部状态栏不会压住顾客订单卡")
	_check(top_warning.get_global_rect().end.y < first_order_panel.get_global_rect().position.y, "顶部警告不会压住顾客订单卡")
	_check(attention_rail.get_global_rect().end.y < first_order_panel.get_global_rect().position.y, "设备告警不会压住顾客订单卡")
	_check(attention_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "设备告警提示条不拦截右上角结算按钮的输入")
	_check(not instructions.visible, "重复的常驻操作说明默认隐藏")
	_check(not workstation.global_status_label.text.contains("熟练度"), "实时经营状态不再重复展示熟练度")
	workstation.call("_set_upgrade_workshop_preview", true)
	_check(not status_background.visible and not timer_background.visible and not compact_status.visible, "工坊预览会隐藏营业日顶部 HUD")
	workstation.call("_set_upgrade_workshop_preview", false)
	_check(status_background.visible and timer_background.visible and compact_status.visible, "退出工坊预览后恢复营业日顶部 HUD")

	workstation.queue_free()
	_finish()


static func _rects_overlap(left: Rect2, right: Rect2) -> bool:
	return left.intersects(right)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("BUSINESS_DAY_TOP_LAYOUT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("BUSINESS_DAY_TOP_LAYOUT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
