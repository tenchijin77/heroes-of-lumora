# enemy_spawner.gd - scalable enemy spawner with weighted random and edge spawns

extends Node

@export var min_spawn_time : float = 2.0
@export var max_spawn_time : float = 5.0
@export var spawn_radius : float = 100.0  # Jitter for edge spawns
@export var monster_configs : Array[Dictionary] = [
	{"scene": preload("res://Scenes/skeleton.tscn"), "weight": 0.7},
	{"scene": preload("res://Scenes/wizard.tscn"), "weight": 0.3},
	{"scene": preload("res://Scenes/goblin.tscn"), "weight": 0.3}
]
# Add new mobs here: {"scene": preload("new_mob.tscn"), "weight": 0.2}

@export var use_fixed_points : bool = false  # Toggle for portals/fixed spawns
@export var fixed_points_paths : Array[NodePath] = []  # For fixed points if true

@onready var spawn_timer : Timer = $spawn_timer
@onready var player = get_tree().get_first_node_in_group("player")
var mob_pools : Dictionary = {}  # Dynamic pools: scene_path -> NodePool
var fixed_points_nodes : Array[Node2D] = []
var total_weight : float = 0.0

func _ready():
	for config in monster_configs:
		total_weight += config.weight
		var pool = NodePool.new()
		add_child(pool)
		pool.node_scene = config.scene
		mob_pools[config.scene.resource_path] = pool
	if use_fixed_points:
		for path in fixed_points_paths:
			var node = get_node(path)
			if node:
				fixed_points_nodes.append(node as Node2D)
			else:
				push_error("Fixed point node not found at path: %s" % path)
	if not player:
		push_error("Spawner: Player reference is null!")
	_set_random_spawn_time()

func _spawn_monster():
	var selected_scene = _select_weighted_scene()
	if not selected_scene:
		push_warning("Spawner: No monster scene selected!")
		return
	var pool = mob_pools[selected_scene.resource_path]
	var monster = pool.spawn()
	var spawn_pos = _get_spawn_position()
	monster.global_position = spawn_pos
	monster.player_direction = spawn_pos.direction_to(player.global_position)  # Initial direction toward player
	if monster.has_signal("mob_died") and player and player.has_method("increment_score"):
		if not monster.is_connected("mob_died", player.increment_score):
			monster.mob_died.connect(player.increment_score)
	print("Spawner: Spawned %s at %s" % [monster.name, spawn_pos])

func _select_weighted_scene() -> PackedScene:
	var rand = randf() * total_weight
	var cumulative : float = 0.0
	for config in monster_configs:
		cumulative += config.weight
		if rand < cumulative:
			return config.scene
	return null

func _get_spawn_position() -> Vector2:
	if use_fixed_points and not fixed_points_nodes.is_empty():
		var point = fixed_points_nodes[randi() % fixed_points_nodes.size()]
		var offset = Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))
		return point.global_position + offset
	else:
		# Random edge spawn: Off-screen borders
		var viewport_rect = get_viewport().get_visible_rect()
		var camera = get_viewport().get_camera_2d()
		var center = camera.get_screen_center_position() if camera else Vector2.ZERO
		var margin = 50.0  # Off-screen distance
		var side = randi() % 4  # 0 left, 1 right, 2 top, 3 bottom
		var pos = Vector2.ZERO
		match side:
			0: pos = Vector2(center.x - viewport_rect.size.x / 2 - margin, center.y + randf_range(-viewport_rect.size.y / 2, viewport_rect.size.y / 2))
			1: pos = Vector2(center.x + viewport_rect.size.x / 2 + margin, center.y + randf_range(-viewport_rect.size.y / 2, viewport_rect.size.y / 2))
			2: pos = Vector2(center.x + randf_range(-viewport_rect.size.x / 2, viewport_rect.size.x / 2), center.y - viewport_rect.size.y / 2 - margin)
			3: pos = Vector2(center.x + randf_range(-viewport_rect.size.x / 2, viewport_rect.size.x / 2), center.y - viewport_rect.size.y / 2 - margin)
		return pos + Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))

func _set_random_spawn_time():
	spawn_timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	spawn_timer.start()

func _on_spawn_timer_timeout():
	_spawn_monster()
	_set_random_spawn_time()
