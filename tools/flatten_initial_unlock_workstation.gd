extends SceneTree

const SOURCE_SCENE := "res://scenes/gameplay/initial_unlock_workstation.tscn"
const OUTPUT_SCENE := "res://tmp/initial_unlock_workstation_flattened.tscn"


func _initialize() -> void:
	var source := load(SOURCE_SCENE) as PackedScene
	if source == null:
		printerr("FLATTEN_FAILED: source scene could not load")
		quit(1)
		return
	var source_root := source.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	# Do not retain the inherited PackedScene link. The standalone replacement
	# must own every node before being packed, otherwise Godot writes the base
	# workstation scene back as an instance reference.
	var root := source_root.duplicate(
		Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
	)
	_make_subtree_owned_by(root, root)
	source_root.queue_free()
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		printerr("FLATTEN_FAILED: pack error %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_SCENE)
	root.queue_free()
	if save_error != OK:
		printerr("FLATTEN_FAILED: save error %s" % error_string(save_error))
		quit(1)
		return
	print("FLATTEN_INITIAL_UNLOCK_WORKSTATION_PASS")
	quit(0)


func _make_subtree_owned_by(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_make_subtree_owned_by(child, root)
