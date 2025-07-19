#node_pool.gd
extends Node

@export var node_scene : PackedScene
var cached_nodes : Array[Node2D]

func _create_new () -> Node2D:
	var node = node_scene.instantiate()
	cached_nodes.append(node)
	get_tree().get_root().add_child(node)
	#added to troubleshoot invisible fireballs
	node.visible = true
	return node
	
func spawn () -> Node2D:
	for node in cached_nodes:
		if node.visible == false:
			node.visible = true
			return node
			
	return _create_new()
	
