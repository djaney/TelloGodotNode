@tool
extends EditorPlugin

const node_name := "Tello"

func _enter_tree():
	add_custom_type(
		node_name,
		"Node",
		preload("res://addons/tello_node/TelloNode.gd"),
		preload("res://addons/tello_node/drone_icon.png")
	)


func _exit_tree():
	remove_custom_type(node_name)
