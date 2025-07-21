#enemy_spawner.gd - spawns enemies randomly
extends Node

@export var min_spawn_time : float = 0.5
@export var max_spawn_time : float = 2.0
@export var spawn_radius : float = 100.0
@export var wizard_spawn_chance : float = 0.3
@export var enemies_per_spawn : int = 3

@export var skeleton_pool_path: NodePath
@export var wizard_pool_path: NodePath
@export var spawn_points_paths: Array[NodePath]

@onready var skeleton_pool = get_node(skeleton_pool_path) as NodePool
@onready var wizard_pool = get_node(wizard_pool_path) as NodePool
@onready var spawn_points_nodes: Array[Node2D] = []
@onready var player = get_node("/root/main/player")

func _ready():
	for path in spawn_points_paths:
		var node = get_node(path)
		if node:
			spawn_points_nodes.append(node as Node2D)
		else:
			push_error("Spawn point node not found at path: %s" % path)
	
	_set_random_spawn_time()
	
	if not skeleton_pool:
		push_error("ERROR: Skeleton (skeleton_pool) NodePool not assigned or found!")
	if not wizard_pool:
		push_error("ERROR: Wizard (wizard_pool) NodePool not assigned or found!")
	if not player:
		push_error("ERROR: Player node not found!")

func _spawn_specific_monster(monster_pool: NodePool, spawn_point_node: Node2D):
	if not monster_pool or not spawn_point_node or get_tree().paused:
		return
	var monster = monster_pool.spawn()
	if not monster:
		return
	var random_offset = Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))
	monster.global_position = spawn_point_node.global_position + random_offset
	monster.visible = true
	if monster.has_signal("mob_died"):
		monster.mob_died.connect(player.increment_score.bind())
	else:
		push_error("Monster %s does not have mob_died signal!" % monster.name)

func _spawn_monster():
	if get_tree().paused:
		return
	if spawn_points_nodes.is_empty():
		return
	for i in range(enemies_per_spawn):
		var chosen_spawn_point_node = spawn_points_nodes[randi() % spawn_points_nodes.size()]
		var actual_wizard_chance = wizard_spawn_chance
		if actual_wizard_chance > 1.0:
			actual_wizard_chance /= 100.0
		
		if randf() < actual_wizard_chance:
			_spawn_specific_monster(wizard_pool, chosen_spawn_point_node)
		else:
			_spawn_specific_monster(skeleton_pool, chosen_spawn_point_node)

func _set_random_spawn_time():
	$spawn_timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	$spawn_timer.start()

func _on_spawn_timer_timeout():
	_spawn_monster()
	_set_random_spawn_time()
