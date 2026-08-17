extends SceneTree

## Prepares an isolated, starter-level soy-milk save for manual acceptance.
## The launcher sets a separate APPDATA/LOCALAPPDATA before running this file,
## so it never reads or overwrites the player's normal user:// save.


func _initialize() -> void:
	_prepare.call_deferred()


func _prepare() -> void:
	var session := root.get_node_or_null("GameSession")
	if session == null:
		printerr("SOY_TEST_SAVE_FAIL: GameSession autoload is unavailable")
		quit(1)
		return
	var result := Dictionary(session.call("open_soy_test_profile"))
	if not bool(result.get("success", false)):
		printerr("SOY_TEST_SAVE_FAIL: could not create the soy test profile")
		quit(1)
		return
	print("SOY_TEST_SAVE_READY")
	quit(0)
