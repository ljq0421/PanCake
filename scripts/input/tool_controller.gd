class_name ToolController
extends Node

signal tool_changed(tool: Tool)

enum Tool {
	NONE,
	LADLE,
	SCRAPER,
	SAUCE_BRUSH,
	FOLD,
}

var current_tool: Tool = Tool.NONE


func select_tool(tool: Tool) -> void:
	if current_tool == tool:
		tool_changed.emit(current_tool)
		return
	current_tool = tool
	tool_changed.emit(current_tool)


func clear_tool() -> void:
	select_tool(Tool.NONE)


func display_name() -> String:
	match current_tool:
		Tool.LADLE:
			return "面糊勺"
		Tool.SCRAPER:
			return "T形摊饼器"
		Tool.SAUCE_BRUSH:
			return "酱刷"
		Tool.FOLD:
			return "折叠手"
		_:
			return "未拿工具"
