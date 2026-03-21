# monsters.gd - Controls monster movement towards extraction points and attacks nearby enemies
extends CharacterBody2D
signal mob_died

@export var max_speed: float = 35.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var collision_damage: int = 3
@export var shoot_rate: float = 1.5
@export var shoot_range: float = 250.0
@export var current_health: int = 15
@export var max_health: int = 15
@export var bullet_scene: PackedScene
@export var score_value: int = 10
@export var debug_enabled: bool = false  # NEW: Toggle debug printing
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var potion_pool: NodePool = $potion_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var avoidance_ray: RayCast2D = $avoidance_ray

var potions_data: Dictionary = {}
var target: Node2D # Attack target (for shooting/facing)
var target_distance: float
var target_direction: Vector2
var last_shoot_time: float = 0.0
var last_damage_source: Node = null
var last_damage_times: Dictionary = {}
var monster_size: String = "medium"

# Waypoint system for sequential pathfinding
var current_waypoint: Node2D = null
var waypoint_stage: int = 0  # 0 = move to town center, 1 = move to extraction

# Debug tracking
var debug_frame_counter: int = 0

# NEW: Target finding optimization
var target_update_timer: float = 0.0
const TARGET_UPDATE_INTERVAL: float = 0.5  # Update target twice per second

func _ready() -> void:
	# Initialize monster properties and navigation
	add_to_group("monsters")
	collision_mask = 1 + 4 + 16 + 32 + 64 + 512
	
	# Navigation settings will be auto-tuned by _auto_tune_from_collision()
	navigation_agent.path_desired_distance = 15.0
	# Target desired distance will be set in _auto_tune_from_collision()
	navigation_agent.avoidance_enabled = true
	navigation_agent.avoidance_layers = 1 << 4
	navigation_agent.max_neighbors = 5
	navigation_agent.neighbor_distance = 50.0
	
	navigation_agent.velocity_computed.connect(_on_navigation_agent_velocity_computed)
	
	# Setup avoidance_ray for line-of-sight checks
	if avoidance_ray:
		avoidance_ray.collision_mask = 1 
		avoidance_ray.enabled = true
	
	# Load potions data
	var file: FileAccess = FileAccess.open("res://Data/potions.json", FileAccess.READ)
	if file:
		potions_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		push_warning("Monster %s: Failed to open potions.json!" % name)
	
	# Setup bullet pool
	if bullet_scene:
		bullet_pool.node_scene = bullet_scene
	else:
		push_warning("Monster %s: bullet_scene not set!" % name)
	
	# Validate required nodes
	if not health_bar:
		push_error("Monster %s: health_bar is null!" % name)
	if not collision_shape:
		push_error("Monster %s: collision_shape is null!" % name)
	
	# Initial setup - defer until scene tree is fully ready
	_find_nearest_attack_target()
	reset()
	
	# Defer waypoint initialization to next frame when scene tree is ready
	call_deferred("_initialize_waypoint")
	_auto_tune_from_collision()

func _auto_tune_from_collision() -> void:
	if not collision_shape or not collision_shape.shape or not navigation_agent:
		return

	var max_dim: float = 0.0

	# Determine footprint from collision shape
	if collision_shape.shape is RectangleShape2D:
		var size: Vector2 = collision_shape.shape.size
		max_dim = max(size.x, size.y)
	elif collision_shape.shape is CircleShape2D:
		max_dim = collision_shape.shape.radius * 2.0
	else:
		return

	# Classify monster size based on footprint
	if max_dim < 48.0:
		monster_size = "small"
	elif max_dim < 96.0:
		monster_size = "medium"
	else:
		monster_size = "large"

	# Tune navigation radius from footprint
	navigation_agent.radius = max_dim * 0.6
	
	# FIXED: Set target_desired_distance based on monster size
	# Small monsters can get closer, large monsters need more space
	navigation_agent.target_desired_distance = max(10.0, max_dim * 0.3)
	
	if debug_enabled:
		print("Monster %s: Auto-tuned - size=%s, max_dim=%.1f, radius=%.1f, target_desired=%.1f" % [
			name, monster_size, max_dim, navigation_agent.radius, navigation_agent.target_desired_distance
		])

func reset() -> void:
	# Reset monster state for reuse
	visible = true
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	velocity = Vector2.ZERO
	last_shoot_time = 0.0
	last_damage_source = null
	last_damage_times = {}
	debug_frame_counter = 0
	waypoint_stage = 0  # Reset to stage 0 (village center)
	target_update_timer = 0.0  # Reset target timer
	set_process(true)
	set_physics_process(true)
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if get_parent() is NodePool and global_position == Vector2.ZERO:
		global_position = Vector2.ZERO
	
	# Always defer to be safe
	call_deferred("_update_waypoint")

func _process(delta: float) -> void:
	# NEW: Update target less frequently for performance
	target_update_timer += delta
	if target_update_timer >= TARGET_UPDATE_INTERVAL:
		target_update_timer = 0.0
		_find_nearest_attack_target()
	
	# If we have a target, calculate distance/direction, face it, and shoot
	var has_valid_target: bool = is_instance_valid(target)
	if has_valid_target:
		target_distance = global_position.distance_to(target.global_position)
		target_direction = global_position.direction_to(target.global_position)
		sprite.flip_h = target_direction.x > 0
		
		# Shooting logic
		if target_distance < shoot_range:
			# Only shoot if we have a clear line of sight
			if _has_line_of_sight():
				if Time.get_unix_time_from_system() - last_shoot_time > shoot_rate:
					_cast()
	
	_move_wobble()
	
	# Check if we've reached current waypoint
	_check_waypoint_reached()

# Checks for obstacles between the monster and its target
func _has_line_of_sight() -> bool:
	if not avoidance_ray or not target:
		return false
	
	# Set the ray's end point to the target's position (in local space)
	var target_local_pos = to_local(target.global_position)
	avoidance_ray.target_position = target_local_pos
	
	# Force the raycast to update its collision detection immediately
	avoidance_ray.force_raycast_update()
	
	# Check if the ray collided with anything
	if avoidance_ray.is_colliding():
		var collider = avoidance_ray.get_collider()
		# If the collider is NOT the target, shot is blocked
		if collider != target:
			return false
	
	return true

# Initialize waypoint - start with village center, then extraction point
func _initialize_waypoint() -> void:
	waypoint_stage = 0
	_update_waypoint()

func _update_waypoint() -> void:
	# Safety check: Make sure scene tree is available
	if not is_inside_tree():
		push_warning("Monster %s: Not in scene tree yet, deferring waypoint update" % name)
		call_deferred("_update_waypoint")
		return
	
	match waypoint_stage:
		0:
			# Stage 0: Move to village center first
			var village_centers = get_tree().get_nodes_in_group("village_center")
			if not village_centers.is_empty():
				current_waypoint = village_centers[0]
				navigation_agent.target_position = current_waypoint.global_position
				if debug_enabled:
					print("Monster %s: Waypoint set to village_center at (%.1f, %.1f)" % [name, current_waypoint.global_position.x, current_waypoint.global_position.y])
			else:
				push_warning("Monster %s: No village_center found! Skipping to extraction." % name)
				waypoint_stage = 1
				call_deferred("_update_waypoint")
		1:
			# Stage 1: Move to nearest extraction point
			current_waypoint = _find_nearest_extraction_point()
			if current_waypoint:
				navigation_agent.target_position = current_waypoint.global_position
				if debug_enabled:
					print("Monster %s: Waypoint set to extraction_point at (%.1f, %.1f)" % [name, current_waypoint.global_position.x, current_waypoint.global_position.y])
			else:
				push_error("Monster %s: No extraction points found!" % name)

# Finds the closest extraction point (Movement Target)
func _find_nearest_extraction_point() -> Node2D:
	# Safety check: Make sure scene tree is available
	if not is_inside_tree():
		return null
	
	var extraction_points: Array = get_tree().get_nodes_in_group("extraction_points")
	
	if extraction_points.is_empty():
		push_warning("Monster %s: No extraction points found! Movement stalled." % name)
		return null

	# Sort and return the closest point
	extraction_points.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	return extraction_points[0]

# Check if we've arrived at the current waypoint
func _check_waypoint_reached() -> void:
	if not current_waypoint or not is_instance_valid(current_waypoint):
		return
	
	var distance_to_waypoint = global_position.distance_to(current_waypoint.global_position)
	
	match waypoint_stage:
		0:
			# Reached village center - advance to next stage
			if distance_to_waypoint < 100.0:
				if debug_enabled:
					print("Monster %s: Reached village center - moving to extraction!" % name)
				waypoint_stage = 1
				_update_waypoint()
		1:
			# Reached extraction point - STAY HERE and hunt villagers
			if distance_to_waypoint < 50.0:
				if debug_enabled:
					print("Monster %s: Reached extraction point - hunting villagers!" % name)
				waypoint_stage = 2  # Mark as "arrived at hunting grounds"
				velocity = Vector2.ZERO  # Stop moving

# Finds the closest enemy (Attack Target)
func _find_nearest_attack_target() -> void:
	# Safety check: Make sure scene tree is available
	if not is_inside_tree():
		target = null
		return
	
	var attack_targets: Array = []
	
	# Target groups for Attack: player, friendly, healer, villagers (in order of proximity)
	var priority_groups = ["player", "friendly", "healer", "villagers"]

	for group_name in priority_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				attack_targets.append(node)

	# Set 'target' to the closest enemy for shooting/facing
	if not attack_targets.is_empty():
		attack_targets.sort_custom(func(a, b):
			return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
		)
		target = attack_targets[0]
	else:
		target = null

func _physics_process(_delta: float) -> void:
	var desired_velocity: Vector2 = Vector2.ZERO
	
	# Stage 2 (hunting grounds) - monsters have reached extraction point, now just hunt
	if waypoint_stage == 2:
		# No pathfinding needed - just attack nearby targets
		# Target finding happens in _process(), shooting happens automatically
		velocity = Vector2.ZERO
		move_and_slide()
		_process_collisions()
		return
	
	# Ensure we have a valid waypoint for stages 0 and 1
	if not is_instance_valid(current_waypoint):
		_update_waypoint()
		return
	
	# FIXED: Simplified navigation logic without await
	# Debug printing (only if enabled)
	if debug_enabled:
		debug_frame_counter += 1
		if debug_frame_counter >= 60:
			debug_frame_counter = 0
			var distance_to_waypoint = global_position.distance_to(current_waypoint.global_position)
			var nav_finished = navigation_agent.is_navigation_finished()
			var stage_name = "village_center" if waypoint_stage == 0 else "extraction_point"
			print("Monster %s: Stage=%s | Distance=%.1f | NavFinished=%s | Pos=(%.1f,%.1f)" % [
				name, 
				stage_name,
				distance_to_waypoint, 
				nav_finished,
				global_position.x,
				global_position.y
			])
	
	# FIXED: New simplified navigation logic
	if navigation_agent.is_navigation_finished():
		# Check if we're actually close to the waypoint
		var distance_to_waypoint = global_position.distance_to(current_waypoint.global_position)
		var arrival_threshold = 100.0 if waypoint_stage == 0 else 50.0
		
		if distance_to_waypoint > arrival_threshold:
			# Not actually there - force path recalculation (NO AWAIT!)
			navigation_agent.target_position = current_waypoint.global_position
		else:
			# Actually arrived
			desired_velocity = Vector2.ZERO

	# If navigation isn't finished, follow the path normally
	if not navigation_agent.is_navigation_finished():
		var next_path_position: Vector2 = navigation_agent.get_next_path_position()
		var move_direction: Vector2 = global_position.direction_to(next_path_position).normalized()
		desired_velocity = move_direction * max_speed
	
	# If no movement is desired, apply drag to stop
	if desired_velocity.is_zero_approx():
		velocity = velocity.lerp(Vector2.ZERO, drag)
		move_and_slide()
		_process_collisions()
		return
	
	# Submit velocity to NavigationAgent for avoidance calculation
	navigation_agent.set_velocity(desired_velocity)

	# Process collisions
	_process_collisions()

# Receives safe velocity from NavigationAgent2D and applies movement
func _on_navigation_agent_velocity_computed(safe_velocity: Vector2) -> void:
	# Use the safe velocity for movement
	velocity = safe_velocity
	
	# Apply acceleration and clamping for smooth movement
	var new_velocity = velocity.lerp(safe_velocity, acceleration * get_physics_process_delta_time())
	velocity = new_velocity.limit_length(max_speed)
	
	# Move using the safe velocity
	move_and_slide()

# OPTIMIZED: Separated collision logic with early exit
func _process_collisions():
	var collision_count = get_slide_collision_count()
	if collision_count == 0:
		return  # Early exit - most common case
	
	var current_time: float = Time.get_unix_time_from_system()
	
	for i in collision_count:
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		# Quick group check first (faster than has_method)
		if not (body.is_in_group("player") or body.is_in_group("friendly") or body.is_in_group("healer")):
			continue
		
		# Check cooldown before expensive method check
		var last_time: float = last_damage_times.get(body, 0.0)
		if current_time - last_time < 2.0:
			continue
		
		if body.has_method("take_damage"):
			last_damage_times[body] = current_time
			body.call_deferred("take_damage", collision_damage, null)

func _move_wobble() -> void:
	# Apply sprite wobble animation
	if velocity.length() == 0:
		sprite.rotation_degrees = 0
		return
	var t = Time.get_unix_time_from_system()
	var rot = sin(t * 20) * 2
	sprite.rotation_degrees = rot

func _cast() -> void:
	# Fire projectile at the current attack target
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Monster %s: Cannot cast!" % name)
		return
	
	if not is_instance_valid(target):
		target = null
		push_warning("Monster %s: Target instance invalid during cast!" % name)
		return
		
	var projectile = bullet_pool.spawn()
	if projectile:
		projectile.global_position = muzzle.global_position
		
		var direction_vector = muzzle.global_position.direction_to(target.global_position)
		
		if direction_vector.is_zero_approx():
			direction_vector = Vector2.DOWN
		
		projectile.move_direction = direction_vector
	else:
		push_warning("Monster %s: Failed to spawn projectile!" % name)

func take_damage(damage: int, projectile_instance: Node):
	# Apply damage and handle death
	current_health -= damage
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		mob_died.emit()
		if is_instance_valid(projectile_instance) and projectile_instance.owner_group == "player":
			Global.current_score += score_value
			Global.emit_signal("score_updated", Global.current_score)
		if not potions_data.get("potions", []).is_empty():
			var drop_chance: float = randf()
			var cumulative_chance: float = 0.0
			for potion in potions_data["potions"]:
				cumulative_chance += potion["drop_rate"]
				if drop_chance <= cumulative_chance:
					_spawn_potion(potion)
					break
		
		# FIXED: Just hide and disable, DON'T call reset yet!
		visible = false
		set_process(false)
		set_physics_process(false)
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		# Reset will be called when monster is re-spawned from pool
	else:
		_damage_flash()

func _spawn_potion(potion_data: Dictionary) -> void:
	if potion_pool:
		var potion: Area2D = potion_pool.spawn() as Area2D
		if potion:
			# Store the death position BEFORE any operations
			var death_position = global_position
			
			# FIXED: Don't set position here - will be set in deferred helper
			# ALL scene tree modifications must be deferred during physics callbacks
			
			# Reparent potion to main scene so it doesn't disappear with monster
			if potion.get_parent():
				var old_parent = potion.get_parent()
				# Use call_deferred to avoid physics state error
				call_deferred("_reparent_potion", potion, old_parent, death_position, potion_data)
			else:
				# No parent yet, just add to main
				call_deferred("_add_potion_to_main", potion, death_position, potion_data)

func _reparent_potion(potion: Area2D, old_parent: Node, death_position: Vector2, potion_data: Dictionary) -> void:
	"""Helper function to reparent potion outside of physics callback"""
	if is_instance_valid(old_parent) and is_instance_valid(potion):
		old_parent.remove_child(potion)
	_add_potion_to_main(potion, death_position, potion_data)

func _add_potion_to_main(potion: Area2D, death_position: Vector2, potion_data: Dictionary) -> void:
	"""Helper function to add potion to main scene"""
	if not is_instance_valid(potion):
		return
		
	# Add to main scene
	var main_scene = get_tree().root.get_node_or_null("main")
	if main_scene:
		main_scene.add_child(potion)
		# Restore position after reparenting
		potion.global_position = death_position
		# Setup the potion
		potion.setup(potion_data)
		
		if debug_enabled:
			print("Monster %s: Spawned potion at %s" % [name, death_position])

func _damage_flash() -> void:
	# Flash sprite on damage
	sprite.modulate = Color.BLACK
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE

func _on_visibility_changed() -> void:
	# Handle visibility changes for pooling
	if visible:
		set_process(true)
		set_physics_process(true)
		current_health = max_health
		if health_bar:
			health_bar.value = current_health
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
	else:
		set_process(false)
		set_physics_process(false)
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
