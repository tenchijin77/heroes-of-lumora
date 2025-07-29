# enemy_spawner.gd - scalable enemy spawner with weighted random and edge spawns

extends Node

# -- Existing @exports --
@export var min_spawn_time : float = 2.0 # Base minimum spawn time
@export var max_spawn_time : float = 5.0 # Base maximum spawn time
@export var spawn_radius : float = 100.0 # Jitter for edge spawns
@export var monster_configs : Array[Dictionary] = [
	{"scene": preload("res://Scenes/skeleton.tscn"), "weight": 0.7},
	{"scene": preload("res://Scenes/wizard.tscn"), "weight": 0.3},
	{"scene": preload("res://Scenes/goblin.tscn"), "weight": 0.3},
	{"scene": preload("res://Scenes/ghost.tscn"), "weight": 0.3}
]
# Add new mobs here: {"scene": preload("new_mob.tscn"), "weight": 0.2}

@export var use_fixed_points : bool = false # Toggle for portals/fixed spawns
@export var fixed_points_paths : Array[NodePath] = [] # For fixed points if true

# -- NEW: Spawning Multiplier and Wave Logic --
@export var initial_spawn_multiplier: float = 1.0 # Overall multiplier for spawn speed. 0.5 makes it twice as fast.
@export var wave_duration_minutes: float = 2.0 # How long each wave lasts
@export var spawn_rate_increase_per_wave: float = 0.1 # How much the spawn rate speeds up each wave (e.g., 0.1 means 10% faster)
@export var min_multiplier_limit: float = 0.05 # Don't let the multiplier go below this to avoid insane spawn rates
@export var obstacle_collision_mask: int = 1 # Set this in Inspector to match your environment/wall layer(s)

# -- References --
@onready var spawn_timer : Timer = $spawn_timer
@onready var player = get_tree().get_first_node_in_group("player")
# CORRECTED PATH to match player.gd's label path
@onready var current_wave_label: Label = get_node("/root/main/CanvasLayer/VBoxContainer/wave") 

var mob_pools : Dictionary = {} # Dynamic pools: scene_path -> NodePool
var fixed_points_nodes : Array[Node2D] = []
var total_weight : float = 0.0

var current_spawn_multiplier: float = 1.0 # Actual multiplier applied
var current_wave: int = 1
var wave_timer: Timer # Dedicated timer for wave updates

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

	# Check player reference
	if not player:
		push_error("Spawner: Player reference is null! Make sure player is in 'player' group.")
		set_process_mode(Node.PROCESS_MODE_DISABLED) # Stop processing if no player

	# --- NEW: Initialize Wave and Spawn Logic ---
	current_spawn_multiplier = initial_spawn_multiplier # Set initial multiplier

	# Setup Wave Timer
	wave_timer = Timer.new()
	add_child(wave_timer)
	wave_timer.wait_time = wave_duration_minutes * 60.0
	wave_timer.one_shot = false # It repeats
	wave_timer.autostart = true # Starts automatically
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	print("Wave timer initialized for {} minutes.".format([wave_duration_minutes])) # Corrected format

	# Connect existing spawn_timer
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_update_spawn_timer_interval() # Set initial interval
	print("Initial spawn interval: {:.2f} seconds.".format([spawn_timer.wait_time])) # Corrected format

	# Initial label update
	_update_wave_label()

# --- NEW: Wave and Spawn Rate Management Functions ---

func _update_spawn_timer_interval():
	# Calculate effective min and max spawn times based on the current multiplier
	var effective_min = min_spawn_time * current_spawn_multiplier
	var effective_max = max_spawn_time * current_spawn_multiplier

	# Ensure minimum interval is not too low (e.g., if multiplier goes to 0)
	effective_min = max(0.1, effective_min) # Prevents division by zero or negative times
	effective_max = max(effective_min + 0.1, effective_max) # Ensure max is always greater than min

	spawn_timer.wait_time = randf_range(effective_min, effective_max)
	spawn_timer.start() # Restart the timer with the new interval
	print("Spawn interval updated to {:.2f} (Effective Range: {:.2f}-{:.2f}, Multiplier: {:.2f}).".format(
		[spawn_timer.wait_time, effective_min, effective_max, current_spawn_multiplier])) # Corrected format


func _on_wave_timer_timeout():
	current_wave += 1
	print("--- Wave {} Started! ---".format([current_wave])) # Corrected format
	_update_wave_label()
	_increase_spawn_rate()
	# The wave_timer is set to one_shot=false, so it automatically restarts.

func _update_wave_label():
	if current_wave_label:
		current_wave_label.text = "Current Wave: " + str(current_wave)
	else:
		push_warning("Spawner: 'current_wave_label' is not set or found. Check node path/name.")

func _increase_spawn_rate():
	# Decrease the multiplier to make spawns faster
	# Example: 1.0 * (1 - 0.1) = 0.9 (10% faster)
	#          0.9 * (1 - 0.1) = 0.81 (another 10% faster relative to previous)
	current_spawn_multiplier *= (1.0 - spawn_rate_increase_per_wave)
	current_spawn_multiplier = max(min_multiplier_limit, current_spawn_multiplier) # Prevent it from becoming too fast
	_update_spawn_timer_interval() # Apply the new multiplier to the spawn timer

# --- Existing Spawning Logic (modified for collision avoidance) ---

func _spawn_monster():
	var selected_scene = _select_weighted_scene()
	if not selected_scene:
		push_warning("Spawner: No monster scene selected!")
		return

	var pool = mob_pools[selected_scene.resource_path]
	var monster = pool.spawn()

	# --- NEW: Collision Avoidance Logic ---
	var spawn_pos: Vector2
	var max_attempts = 10 # Try a few times to find a clear spot
	var attempts = 0
	var found_clear_spot = false

	# Ensure the monster instance has a CollisionShape2D named "CollisionShape2D"
	# and retrieve its shape.
	var monster_collision_shape: CollisionShape2D = monster.find_child("CollisionShape2D", true, false)
	if not monster_collision_shape:
		push_error("Spawned monster '%s' does not have a CollisionShape2D child named 'CollisionShape2D'. Cannot perform spawn collision check." % monster.name)
		pool.despawn(monster)
		return
	if not monster_collision_shape.shape:
		push_error("CollisionShape2D on monster '%s' does not have a shape assigned." % monster.name)
		pool.despawn(monster)
		return


	while attempts < max_attempts and not found_clear_spot:
		spawn_pos = _get_spawn_position()
		# Check if the proposed spawn_pos is clear
		if _is_position_clear(spawn_pos, monster_collision_shape.shape):
			found_clear_spot = true
		else:
			# print("Attempt {}: Spawn point {} blocked, trying another.".format([attempts+1, spawn_pos])) # Uncomment for detailed debug
			pass
		attempts += 1

	if not found_clear_spot:
		push_warning("Spawner: Could not find a clear spawn position after %d attempts for %s. Despawning." % [max_attempts, monster.name])
		pool.despawn(monster) # Return the monster to the pool
		return
	# --- END NEW Collision Avoidance Logic ---

	monster.global_position = spawn_pos
	monster.player_direction = spawn_pos.direction_to(player.global_position) # Initial direction toward player

	# Connect signals for score increment
	if monster.has_signal("mob_died") and player and player.has_method("increment_score"):
		# Ensure signal is connected only once if not already
		# Using Callable() for robustness as per Godot 4 best practices
		if not monster.is_connected("mob_died", Callable(player, "increment_score")):
			monster.mob_died.connect(Callable(player, "increment_score"))
	else:
		if not monster.has_signal("mob_died"):
			push_warning("Monster %s: does not have 'mob_died' signal." % monster.name)
		if not player:
			push_warning("Player is null when connecting score increment.")
		elif player and not player.has_method("increment_score"):
			push_warning("Player does not have 'increment_score' method.")

	print("Spawner: Spawned %s at %s" % [monster.name, spawn_pos])


# --- NEW: Helper for Collision Avoidance ---
# This function checks if a given position is clear of obstacles for a given shape.
func _is_position_clear(position: Vector2, shape: Shape2D) -> bool:
	# Corrected: Access world_2d through the Viewport
	var space = get_viewport().get_world_2d().direct_space_state

	var shape_query = PhysicsShapeQueryParameters2D.new()
	shape_query.shape = shape
	shape_query.transform = Transform2D(0, position) # Position the shape at the test point
	shape_query.collision_mask = obstacle_collision_mask # Use the exported collision mask for obstacles

	var result = space.intersect_shape(shape_query)
	return result.is_empty() # If result is empty, no collisions found at that point

# --- Existing Helper Functions ---

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
		var margin = 50.0 # Off-screen distance
		var side = randi() % 4 # 0 left, 1 right, 2 top, 3 bottom
		var pos = Vector2.ZERO
		match side:
			0: pos = Vector2(center.x - viewport_rect.size.x / 2 - margin, center.y + randf_range(-viewport_rect.size.y / 2, viewport_rect.size.y / 2))
			1: pos = Vector2(center.x + viewport_rect.size.x / 2 + margin, center.y + randf_range(-viewport_rect.size.y / 2, viewport_rect.size.y / 2))
			2: pos = Vector2(center.x + randf_range(-viewport_rect.size.x / 2, viewport_rect.size.x / 2), center.y - viewport_rect.size.y / 2 - margin)
			3: pos = Vector2(center.x + randf_range(-viewport_rect.size.x / 2, viewport_rect.size.x / 2), center.y + viewport_rect.size.y / 2 + margin) # Corrected logic for bottom edge
		return pos + Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))

# The _set_random_spawn_time function is now replaced by _update_spawn_timer_interval
# which is called when the multiplier changes or for initial setup.
# The _on_spawn_timer_timeout is now simpler:
func _on_spawn_timer_timeout():
	_spawn_monster()
	_update_spawn_timer_interval() # Get a new random time for the *next* spawn within the current multiplier range
