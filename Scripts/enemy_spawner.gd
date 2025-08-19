# enemy_spawner.gd - Scalable enemy spawner with weighted random and edge spawns, including dynamic boss integration
extends Node

signal wave_updated(wave: int)

# -- Existing @exports --
@export var min_spawn_time: float = 3.0
@export var max_spawn_time: float = 5.0
@export var spawn_radius: float = 200.0 # Increased to reduce clustering
@export var monster_configs: Array[Dictionary] = [
	{"scene": preload("res://Scenes/skeleton.tscn"), "weight": 0.7},
	{"scene": preload("res://Scenes/wizard.tscn"), "weight": 0.3},
	{"scene": preload("res://Scenes/goblin.tscn"), "weight": 0.3},
	{"scene": preload("res://Scenes/beholder.tscn"), "weight": 0.1},
	{"scene": preload("res://Scenes/lich.tscn"), "weight": 0.1},
	{"scene": preload("res://Scenes/ogre.tscn"), "weight": 0.2},
	{"scene": preload("res://Scenes/ghost.tscn"), "weight": 0.3}
]
@export var boss_configs: Array[Dictionary] = [
	{"scene": preload("res://Scenes/balrog.tscn"), "weight": 0.1},
	{"scene": preload("res://Scenes/hezrou.tscn"), "weight": 0.1},
	{"scene": preload("res://Scenes/wraith.tscn"), "weight": 0.1},
	{"scene": preload("res://Scenes/troll.tscn"), "weight": 0.1}
]
@export var use_fixed_points: bool = false
@export var fixed_points_paths: Array[NodePath] = []
@export var initial_spawn_multiplier: float = 1.0
@export var wave_duration_minutes: float = 2.0
@export var spawn_rate_increase_per_wave: float = 0.1
@export var min_multiplier_limit: float = 0.1
@export var obstacle_collision_mask: int = 16 # Layer 5
@export var forbidden_zone_mask: int = 128 # Layer 8
@export var initial_mobs_per_spawn: int = 1
@export var mobs_increase_per_wave: int = 1
@export var coin_drop_chance: float = 0.3
@export var coin_drop_amount_range: Vector2 = Vector2(1, 4)
@export var coin_scene: PackedScene = preload("res://Scenes/coin.tscn")

# -- References --
@onready var spawn_timer: Timer = $spawn_timer
@onready var wave_timer: Timer = $wave_timer
@onready var player = get_tree().get_first_node_in_group("player")

var mob_pools: Dictionary = {}
var fixed_points_nodes: Array[Node2D] = []
var total_weight: float = 0.0
var current_spawn_multiplier: float = 1.0
var current_wave: int = 1
var current_mobs_per_spawn: int = 1
var effective_monster_configs: Array[Dictionary] = [] # Dynamic list including bosses

func _ready() -> void:
	# Initialize with regular monster configs
	effective_monster_configs = monster_configs.duplicate(true)
	_calculate_total_weight()
	
	# Initialize node pools for regular monsters and bosses
	for config in monster_configs + boss_configs:
		var pool = NodePool.new()
		add_child(pool)
		pool.node_scene = config.scene
		mob_pools[config.scene.resource_path] = pool
	
	# Set up fixed spawn points if enabled
	if use_fixed_points:
		for path in fixed_points_paths:
			var node = get_node(path)
			if node:
				fixed_points_nodes.append(node as Node2D)
			else:
				push_error("Fixed point node not found at path: %s" % path)
	
	# Validate player reference
	if not player:
		push_error("Spawner: Player reference is null! Make sure player is in 'player' group.")
		set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	# Initialize spawn parameters
	current_spawn_multiplier = initial_spawn_multiplier
	current_mobs_per_spawn = initial_mobs_per_spawn
	_update_spawn_timer_interval()
	print("Initial spawn interval: %.2f seconds." % spawn_timer.wait_time)
	
	# Connect timers
	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if not wave_timer.timeout.is_connected(_on_wave_timer_timeout):
		wave_timer.timeout.connect(_on_wave_timer_timeout)
	
	# Set initial wave
	Global.current_wave = current_wave
	Global.emit_signal("wave_updated", current_wave)
	print("Wave timer set for %.1f minutes." % (wave_timer.wait_time / 60.0))

func _calculate_total_weight() -> void:
	# Sum weights for current effective monster configs
	total_weight = 0.0
	for config in effective_monster_configs:
		total_weight += config.weight

func _update_effective_configs() -> void:
	# Dynamically add bosses to effective configs based on wave
	effective_monster_configs = monster_configs.duplicate(true)
	var num_bosses_to_add: int = 0
	if current_wave >= 10:
		num_bosses_to_add = 4
	elif current_wave >= 8:
		num_bosses_to_add = 3
	elif current_wave >= 6:
		num_bosses_to_add = 2
	elif current_wave >= 4:
		num_bosses_to_add = 1
	
	if num_bosses_to_add > 0:
		# Shuffle bosses and add the first num_bosses_to_add
		var shuffled_bosses = boss_configs.duplicate(true)
		shuffled_bosses.shuffle()
		for i in range(num_bosses_to_add):
			effective_monster_configs.append(shuffled_bosses[i])
		print("Wave %d: Added %d boss types to spawn pool" % [current_wave, num_bosses_to_add])
	_calculate_total_weight()

func _increase_spawn_rate() -> void:
	# Adjust spawn rate and mobs per spawn
	current_spawn_multiplier *= (1.0 - spawn_rate_increase_per_wave)
	current_spawn_multiplier = max(min_multiplier_limit, current_spawn_multiplier)
	current_mobs_per_spawn += mobs_increase_per_wave
	_update_spawn_timer_interval()
	print("Wave %d: Spawn multiplier=%.2f, Mobs per spawn=%d" % [current_wave, current_spawn_multiplier, current_mobs_per_spawn])

func _update_spawn_timer_interval() -> void:
	# Update spawn timer with scaled interval
	var effective_min: float = max(0.1, min_spawn_time * current_spawn_multiplier)
	var effective_max: float = max(effective_min + 0.1, max_spawn_time * current_spawn_multiplier)
	spawn_timer.wait_time = randf_range(effective_min, effective_max)
	spawn_timer.start()
	print("Spawn interval updated to %.2f (Range: %.2f-%.2f, Multiplier: %.2f)." % [
		spawn_timer.wait_time, effective_min, effective_max, current_spawn_multiplier])

func _on_wave_timer_timeout() -> void:
	# Increment wave and update effective configs with bosses
	Global.increment_wave()
	current_wave = Global.current_wave
	print("--- Wave %d Started! ---" % current_wave)
	_update_effective_configs()
	_increase_spawn_rate()

func _on_spawn_timer_timeout() -> void:
	# Spawn monsters
	for i: int in range(current_mobs_per_spawn):
		_spawn_monster()
	_update_spawn_timer_interval()

func _spawn_monster() -> void:
	# Spawn a regular or boss monster
	var monster_scene: PackedScene = _select_weighted_scene()
	if not monster_scene:
		push_error("Spawner: No monster scene selected!")
		return
	if not player:
		push_error("Spawner: Player reference is null!")
		return
	var monster: CharacterBody2D = mob_pools[monster_scene.resource_path].spawn() as CharacterBody2D
	if monster:
		var spawn_pos: Vector2 = _get_spawn_position()
		var shape: Shape2D = monster.get_node("CollisionShape2D").shape if monster.get_node_or_null("CollisionShape2D") else null
		if shape:
			var attempts: int = 0
			var max_attempts: int = 10
			while attempts < max_attempts and not (_is_obstacle_free(spawn_pos, shape) and _is_forbidden_free(spawn_pos, shape)):
				spawn_pos = _get_spawn_position()
				attempts += 1
			if attempts >= max_attempts:
				print("Spawner: Failed to find valid spawn position for %s after %d attempts!" % [monster.name, max_attempts])
				monster.queue_free()
				return
		monster.global_position = spawn_pos
		get_parent().add_child(monster)
		monster.visible = true
		if monster.has_method("reset"):
			monster.reset()
		if monster.has_signal("mob_died") and player.has_method("increment_score") and not monster.is_connected("mob_died", Callable(player, "increment_score")):
			monster.mob_died.connect(Callable(player, "increment_score"))
		if monster.has_signal("mob_died") and not monster.is_connected("mob_died", _on_mob_died):
			var connection_result = monster.mob_died.connect(_on_mob_died.bind(monster))
			if connection_result != OK:
				print("Failed to connect mob_died for %s, error: %s" % [monster.name, connection_result])
			else:
				print("Connected mob_died for %s" % monster.name)
		print("Spawner: Spawned %s at %s" % [monster.name, spawn_pos])
	else:
		print("Spawner: Failed to spawn %s!" % monster_scene.resource_path)

func _is_obstacle_free(position: Vector2, shape: Shape2D) -> bool:
	var space: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
	var shape_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	shape_query.shape = shape
	shape_query.transform = Transform2D(0, position)
	shape_query.collision_mask = obstacle_collision_mask # Layer 5
	var intersects: Array = space.intersect_shape(shape_query)
	if not intersects.is_empty():
		print("Position %s blocked by obstacle: %s" % [position, intersects])
		return false
	return true

func _is_forbidden_free(position: Vector2, shape: Shape2D) -> bool:
	var space: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
	var shape_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	shape_query.shape = shape
	shape_query.transform = Transform2D(0, position)
	shape_query.collision_mask = forbidden_zone_mask # Layer 8
	var intersects: Array = space.intersect_shape(shape_query)
	if not intersects.is_empty():
		print("Position %s in forbidden zone: %s" % [position, intersects])
		return false
	return true

func _select_weighted_scene() -> PackedScene:
	var rand: float = randf() * total_weight
	var cumulative: float = 0.0
	for config: Dictionary in effective_monster_configs:
		cumulative += config.weight
		if rand < cumulative:
			return config.scene
	return null

func _get_spawn_position() -> Vector2:
	if use_fixed_points and not fixed_points_nodes.is_empty():
		var point: Node2D = fixed_points_nodes[randi() % fixed_points_nodes.size()]
		var offset: Vector2 = Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))
		return point.global_position + offset
	else:
		var viewport_rect: Rect2 = get_viewport().get_visible_rect()
		var camera: Camera2D = get_viewport().get_camera_2d()
		var center: Vector2 = camera.get_screen_center_position() if camera else Vector2.ZERO
		var margin: float = 200.0
		var side: int = randi() % 4
		var pos: Vector2 = Vector2.ZERO
		match side:
			0: pos = Vector2(center.x - viewport_rect.size.x / 2 - margin, center.y + randf_range(-viewport_rect.size.y / 2, viewport_rect.size.y / 2))
			1: pos = Vector2(center.x + viewport_rect.size.x / 2 + margin, center.y + randf_range(-viewport_rect.size.y / 2, viewport_rect.size.y / 2))
			2: pos = Vector2(center.x + randf_range(-viewport_rect.size.x / 2, viewport_rect.size.x / 2), center.y - viewport_rect.size.y / 2 - margin)
			3: pos = Vector2(center.x + randf_range(-viewport_rect.size.x / 2, viewport_rect.size.x / 2), center.y + viewport_rect.size.y / 2 + margin)
		return pos + Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))

func _on_mob_died(mob: Node2D) -> void:
	if randf() < coin_drop_chance:
		var drop_position: Vector2 = mob.global_position
		var coin_count: int = randi_range(coin_drop_amount_range.x, coin_drop_amount_range.y)
		for i in range(coin_count):
			var coin: Area2D = coin_scene.instantiate() as Area2D
			if coin:
				coin.collision_layer = 256 # Layer 9 (loot)
				coin.collision_mask = 1 # Layer 1 (player)
				coin.global_position = drop_position + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
				get_parent().add_child(coin)
				print("Dropped %d coins at %s (total %d)" % [coin_count, coin.global_position, i + 1])
			else:
				print("Failed to instantiate coin at %s" % drop_position)
