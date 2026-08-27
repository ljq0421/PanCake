extends SceneTree

const FRYER_VIEW := preload("res://scripts/ui/cartoon_youtiao_fryer_toggle.gd")


func _initialize() -> void:
	var fryer_view := FRYER_VIEW.new()
	fryer_view.set("_machine", {
		"state": &"idle",
		"lanes": {
			&"left": {"state": &"idle"},
			&"right": {"state": &"frying"},
		},
	})
	var refreshes_chicken_progress := bool(fryer_view.call("_requires_timed_session_refresh"))
	fryer_view.free()
	if refreshes_chicken_progress:
		print("CHICKEN_FRYER_PROGRESS_REFRESH_SELF_CHECK_PASS")
		quit(0)
	else:
		print("CHICKEN_FRYER_PROGRESS_REFRESH_SELF_CHECK_FAIL")
		quit(1)
