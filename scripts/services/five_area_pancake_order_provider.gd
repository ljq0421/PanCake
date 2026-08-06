class_name FiveAreaPancakeOrderProvider
extends RefCounted

var _game_session: Node


func _init(game_session: Node) -> void:
	_game_session = game_session


func next_order() -> Dictionary:
	if _game_session == null or not _game_session.has_method("next_filtered_pancake_order"):
		return {}
	return Dictionary(_game_session.call("next_filtered_pancake_order")).duplicate(true)
