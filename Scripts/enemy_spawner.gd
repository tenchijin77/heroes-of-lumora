#enemy_spawner.gd - spanwns enemies randomly
extends Node

# @export variables
@export var min_spawn_time : float = 2.0 # Corresponds to a maximum spawn rate
@export var max_spawn_time : float = 5.0 # Corresponds to a minimum spawn rate
@export var spawn_radius : float = 100.0
@export var wizard_spawn_chance : float = 0.3 # Default 30% chance for wizard, should be 0.0-1.0


# NodePath exports for Inspector assignment
# THESE MUST MATCH THE NODE_PATHS IN YOUR .TSCN FILE
@export var skeleton_pool_path: NodePath
@export var wizard_pool_path: NodePath
@export var spawn_points_paths: Array[NodePath]


# @onready variables - these get the actual nodes from the NodePaths
@onready var skeleton_pool = get_node(skeleton_pool_path) as NodePool
@onready var wizard_pool = get_node(wizard_pool_path) as NodePool
@onready var spawn_points_nodes: Array[Node2D] = [] # This array will hold the actual Node2D references


func _ready():
	# Populate spawn_points_nodes array from NodePaths
	for path in spawn_points_paths:
		var node = get_node(path)
		if node:
			spawn_points_nodes.append(node as Node2D)
		else:
			push_error("Spawn point node not found at path: ", path)
	
	_set_random_spawn_time()
	
	# Basic checks to ensure pools are assigned and working
	if not skeleton_pool:
		push_error("ERROR: Skeleton (skeleton_pool) NodePool not assigned or found!")
	if not wizard_pool:
		push_error("ERROR: Wizard (wizard_pool) NodePool not assigned or found!")
		
	# Initialize random number generator if not done globally (e.g., in Project Settings or a main script)
	# randomize() # Only call once at game start, not per spawner instance


func _spawn_specific_monster(monster_pool: NodePool, spawn_point_node: Node2D):
	if not monster_pool:
		push_error("Attempted to spawn from a null monster_pool!")
		return
	if not spawn_point_node:
		push_error("Attempted to spawn at a null spawn_point_node!")
		return

	var monster = monster_pool.spawn()
	var random_offset = Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))
	monster.global_position = spawn_point_node.global_position + random_offset


func _spawn_monster():
	if spawn_points_nodes.is_empty():
		push_warning("No valid spawn points configured for enemy_spawner! Cannot spawn.")
		return

	var chosen_spawn_point_node = spawn_points_nodes[randi() % spawn_points_nodes.size()]

	# Convert wizard_spawn_chance from percentage (0-100) to float (0.0-1.0) if it's set as 30.0 in editor
	var actual_wizard_chance = wizard_spawn_chance
	if actual_wizard_chance > 1.0: # Assumes if it's > 1.0, it's a percentage (e.g., 30 for 30%)
		actual_wizard_chance /= 100.0
		
	if randf() < actual_wizard_chance: # Roll the dice for a wizard
		_spawn_specific_monster(wizard_pool, chosen_spawn_point_node)
	else: # Otherwise, spawn a skeleton
		_spawn_specific_monster(skeleton_pool, chosen_spawn_point_node)


func _set_random_spawn_time():
	$spawn_timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	$spawn_timer.start()


func _on_spawn_timer_timeout():
	_spawn_monster()
	_set_random_spawn_time()
