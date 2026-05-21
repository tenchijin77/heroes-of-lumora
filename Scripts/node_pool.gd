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

	var target_parent = _find_main_scene()
	if target_parent:
		target_parent.call_deferred("add_child", node)
	else:
		if get_parent():
			get_parent().add_child(node)

	node.visible = true
	return node

func _find_main_scene() -> Node:
	"""Find the main scene node in the tree"""
	if not is_inside_tree():
		return null
	
	# Try to find 'main' node
	var root = get_tree().root
	if root:
		var main = root.get_node_or_null("main")
		if main:
			return main
	
	# Fallback: traverse up to find a node named 'main'
	var current = get_parent()
	while current:
		if current.name == "main":
			return current
		current = current.get_parent()
	
	return null

func spawn() -> Node2D:
	for node in cached_nodes:
		if is_instance_valid(node) and node.visible == false:
			node.visible = true
			if node.has_method("reset"):
				node.reset()
			return node
	return _create_new()

func despawn(node: Node2D) -> void:
	"""Hide and reset a node, returning it to the pool"""
	if node in cached_nodes:
		node.visible = false
		if node.has_method("reset"):
			node.reset()
	else:
		push_warning("NodePool: Tried to despawn node %s not in pool" % node.name)
