# enemy_spawner.gd - scalable enemy spawner with weighted random and edge spawns

extends Node

# -- Existing @exports --
@export var min_spawn_time: float = 1.0 # Reduced for more frequent spawns
@export var max_spawn_time: float = 3.0 # Reduced for more frequent spawns
@export var spawn_radius: float = 100.0 # Jitter for edge spawns
@export var monster_configs: Array[Dictionary] = [
	{"scene": preload("res://Scenes/skeleton.tscn"), "weight": 0.7},
	{"scene": preload("res://Scenes/wizard.tscn"), "weight": 0.3},
	{"scene": preload("res://Scenes/goblin.tscn"), "weight": 0.3},
# Add new mobs here: {"scene": preload("new_mob.tscn"), "weight": 0.2}
	{"scene": preload("res://Scenes/ghost.tscn"), "weight": 0.3}
]


@export var use_fixed_points: bool = false # Toggle for portals/fixed spawns
@export var fixed_points_paths: Array[NodePath] = [] # For fixed points if true

# -- NEW: Spawning Multiplier and Wave Logic --
@export var initial_spawn_multiplier: float = 1.0 # Overall multiplier for spawn speed
@export var wave_duration_minutes: float = 2.0 # How long each wave lasts
@export var spawn_rate_increase_per_wave: float = 0.15 # Increased for faster progression
@export var min_multiplier_limit: float = 0.05 # Prevent insane spawn rates
@export var obstacle_collision_mask: int = 1 # Match environment layer

# -- References --
@onready var spawn_timer: Timer = $spawn_timer
@onready var wave_timer: Timer = $wave_timer # New Timer node
@onready var player = get_tree().get_first_node_in_group("player")
@onready var current_wave_label: Label = get_node("/root/main/CanvasLayer/VBoxContainer/wave")

var mob_pools: Dictionary = {} # Dynamic pools: scene_path -> NodePool
var fixed_points_nodes: Array[Node2D] = []
var total_weight: float = 0.0

var current_spawn_multiplier: float = 1.0
var current_wave: int = 1

func _ready():
	# Initial setup for monster pools
	for config in monster_configs:
		total_weight += config.weight
		var pool = NodePool.new()
		add_child(pool)
		pool.node_scene = config.scene
		mob_pools[config.scene.resource_path] = pool

	# Setup fixed spawn points
	if use_fixed_points:
		for path in fixed_points_paths:
			var node = get_node(path)
			if node:
				fixed_points_nodes.append(node as Node2D)
			else:
				push_error("Fixed point node not found at path: %s" % path)

	# Check player and label references
	if not player:
		push_error("Spawner: Player reference is null! Make sure player is in 'player' group.")
		set_process_mode(Node.PROCESS_MODE_DISABLED)
	if not current_wave_label:
		push_warning("Spawner: 'current_wave_label' is null! Check path /root/main/CanvasLayer/VBoxContainer/wave")

	# Initialize wave and spawn logic
	current_spawn_multiplier = initial_spawn_multiplier
	_update_spawn_timer_interval()
	print("Initial spawn interval: %.2f seconds." % spawn_timer.wait_time)

	# Connect timers
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	print("Wave timer set for %.1f minutes." % (wave_timer.wait_time / 60.0))

	# Initial label update
	_update_wave_label()

# --- Wave and Spawn Rate Management Functions ---

func _update_spawn_timer_interval():
	var effective_min = max(0.1, min_spawn_time * current_spawn_multiplier)
	var effective_max = max(effective_min + 0.1, max_spawn_time * current_spawn_multiplier)
	spawn_timer.wait_time = randf_range(effective_min, effective_max)
	spawn_timer.start()
	print("Spawn interval updated to %.2f (Range: %.2f-%.2f, Multiplier: %.2f)." % [
		spawn_timer.wait_time, effective_min, effective_max, current_spawn_multiplier])

func _on_wave_timer_timeout():
	current_wave += 1
	print("--- Wave %d Started! ---" % current_wave)
	_update_wave_label()
	_increase_spawn_rate()

func _update_wave_label():
	if current_wave_label:
		current_wave_label.text = "Wave: %d" % current_wave
	else:
		push_warning("Spawner: 'current_wave_label' is not set or found.")

func _increase_spawn_rate():
	current_spawn_multiplier *= (1.0 - spawn_rate_increase_per_wave)
	current_spawn_multiplier = max(min_multiplier_limit, current_spawn_multiplier)
	_update_spawn_timer_interval()

# --- Spawning Logic ---

func _spawn_monster():
	var selected_scene = _select_weighted_scene()
	if not selected_scene:
		push_warning("Spawner: No monster scene selected!")
		return

	var pool = mob_pools[selected_scene.resource_path]
	var monster = pool.spawn()

	var spawn_pos: Vector2
	var max_attempts = 10
	var attempts = 0
	var found_clear_spot = false

	var monster_collision_shape: CollisionShape2D = monster.find_child("CollisionShape2D", true, false)
	if not monster_collision_shape or not monster_collision_shape.shape:
		push_error("Monster %s: Missing CollisionShape2D or shape." % monster.name)
		pool.despawn(monster)
		return

	while attempts < max_attempts and not found_clear_spot:
		spawn_pos = _get_spawn_position()
		if _is_position_clear(spawn_pos, monster_collision_shape.shape):
			found_clear_spot = true
		attempts += 1

	if not found_clear_spot:
		push_warning("Spawner: No clear spawn position after %d attempts for %s." % [max_attempts, monster.name])
		pool.despawn(monster)
		return

	monster.global_position = spawn_pos
	monster.player_direction = spawn_pos.direction_to(player.global_position)

	if monster.has_signal("mob_died") and player and player.has_method("increment_score"):
		if not monster.is_connected("mob_died", Callable(player, "increment_score")):
			monster.mob_died.connect(Callable(player, "increment_score"))
	else:
		push_warning("Monster %s or player: Missing 'mob_died' signal or 'increment_score' method." % monster.name)

	print("Spawner: Spawned %s at %s" % [monster.name, spawn_pos])

func _is_position_clear(position: Vector2, shape: Shape2D) -> bool:
	var space = get_viewport().get_world_2d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters2D.new()
	shape_query.shape = shape
	shape_query.transform = Transform2D(0, position)
	shape_query.collision_mask = obstacle_collision_mask
	return space.intersect_shape(shape_query).is_empty()

func _select_weighted_scene() -> PackedScene:
	var rand = randf() * total_weight
	var cumulative: float = 0.0
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
		var viewport_rect = get_viewport().get_visible_rect()
		var camera = get_viewport().get_camera_2d()
		var center = camera.get_screen_center_position() if camera else Vector2.ZERO
		var margin = 50.0
		var side = randi() % 4
		var pos = Vector2.ZERO
		match side:
			0: pos = Vector2(center.x - viewport_rect.size.x / 2 - margin, center.y + randf_range(-viewport_rect.size.y / 2, viewport_rect.size.y / 2))
			1: pos = Vector2(center.x + viewport_rect.size.x / 2 + margin, center.y + randf_range(-viewport_rect.size.y / 2, viewport_rect.size.y / 2))
			2: pos = Vector2(center.x + randf_range(-viewport_rect.size.x / 2, viewport_rect.size.x / 2), center.y - viewport_rect.size.y / 2 - margin)
			3: pos = Vector2(center.x + randf_range(-viewport_rect.size.x / 2, viewport_rect.size.x / 2), center.y + viewport_rect.size.y / 2 + margin)
		return pos + Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))

func _on_spawn_timer_timeout():
	_spawn_monster()
	_update_spawn_timer_interval()
