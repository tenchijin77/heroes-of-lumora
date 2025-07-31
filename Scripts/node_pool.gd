# node_pool.gd

class_name NodePool
extends Node

@export var node_scene: PackedScene
var cached_nodes: Array[Node2D]

func _create_new() -> Node2D:
	if not node_scene:
		push_error("NodePool: node_scene is not set!")
		return null
	var node = node_scene.instantiate()
	if not node:
		push_error("NodePool: Failed to instantiate node_scene!")
		return null
	cached_nodes.append(node)
	get_tree().get_root().add_child.call_deferred(node)
	node.visible = true
	if node.has_method("reset"):
		node.reset()
	else:
		push_warning("NodePool: Spawned node %s has no reset method!" % node.name)
	print("NodePool: Created new node %s" % node.name)
	return node

func spawn() -> Node2D:
	for node in cached_nodes:
		if node and node.visible == false:
			node.visible = true
			if node.has_method("reset"):
				node.reset()
			else:
				push_warning("NodePool: Reused node %s has no reset method!" % node.name)
			print("NodePool: Reused node %s" % node.name)
			return node
	return _create_new()
