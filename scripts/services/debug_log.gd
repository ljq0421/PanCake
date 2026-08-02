extends Node

signal message_emitted(category: StringName, message: String)

const PREFIX := "[ProjectCake]"


func info(category: StringName, message: String) -> void:
	var line := "%s[%s] %s" % [PREFIX, category, message]
	print(line)
	message_emitted.emit(category, message)


func warning(category: StringName, message: String) -> void:
	var line := "%s[%s] %s" % [PREFIX, category, message]
	push_warning(line)
	message_emitted.emit(category, message)
