# monsters.gd - Controls monster movement towards extraction points and attacks nearby enemies
extends CharacterBody2D
signal mob_died

@export var max_speed: float = 35.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var collision_damage: int = 3
@export var shoot_rate: float = 1.5
@export var shoot_range: float = 250.0 # Adjust this value if still too far
@export var current_health: int = 15
@export var max_health: int = 15
@export var bullet_scene: PackedScene
@export var score_value: int = 10
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var potion_pool: NodePool = $potion_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var avoidance_ray: RayCast2D = $avoidance_ray # Using existing RayCast2D

var potions_data: Dictionary = {}
var target: Node2D # <<< This is now ONLY the attack target (for shooting/facing)
var target_distance: float
var target_direction: Vector2
var last_shoot_time: float = 0.0
var last_damage_source: Node = null
var last_damage_times: Dictionary = {}

func _ready() -> void:
	# Initialize monster properties and navigation
	add_to_group("monsters")
	collision_mask = 1 + 4 + 16 + 32 + 64 + 512
	navigation_agent.path_desired_distance = 15.0
	navigation_agent.target_desired_distance = 32.0
	navigation_agent.radius = 12.0
	navigation_agent.avoidance_enabled = true
	navigation_agent.avoidance_layers = 1 << 4
	
	navigation_agent.velocity_computed.connect(_on_navigation_agent_velocity_computed)
	
	# 🛑 CRITICAL FIX: Setup avoidance_ray for line-of-sight checks
	if avoidance_ray:
		# Setting collision mask to 1 assumes walls/buildings are on Layer 1 (Static Environment)
		avoidance_ray.collision_mask = 1 
		avoidance_ray.enabled = true
	
	var file: FileAccess = FileAccess.open("res://Data/potions.json", FileAccess.READ)
	if file:
		potions_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		push_warning("Monster %s: Failed to open potions.json!" % name)
	if bullet_scene:
		bullet_pool.node_scene = bullet_scene
	else:
		push_warning("Monster %s: bullet_scene not set!" % name)
	if not health_bar:
		push_error("Monster %s: health_bar is null!" % name)
	if not collision_shape:
		push_error("Monster %s: collision_shape is null!" % name)
		
	# Initial path setting
	_find_nearest_attack_target()
	_update_path()
	reset()

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
	set_process(true)
	set_physics_process(true)
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if get_parent() is NodePool and global_position == Vector2.ZERO:
		global_position = Vector2.ZERO

func _process(_delta: float) -> void:
	# 1. Find Attack Target (who to shoot at and face)
	_find_nearest_attack_target()
	
	# 2. If we have a target, calculate distance/direction, face it, and shoot.
	if is_instance_valid(target):
		target_distance = global_position.distance_to(target.global_position)
		target_direction = global_position.direction_to(target.global_position)
		sprite.flip_h = target_direction.x > 0
		
		# Shooting logic
		if target_distance < shoot_range:
			# 🛑 CRITICAL FIX: Only shoot if we have a clear line of sight
			if _has_line_of_sight():
				if Time.get_unix_time_from_system() - last_shoot_time > shoot_rate:
					_cast()
			
	_move_wobble()
	
	# 3. Always update the path to the Extraction Point (Movement Target)
	_update_path()

# 🛑 CRITICAL NEW FUNCTION: Checks for obstacles between the monster and its target
func _has_line_of_sight() -> bool:
	if not avoidance_ray or not target:
		return false
	
	# 1. Set the ray's end point to the target's position (in local space)
	var target_local_pos = to_local(target.global_position)
	avoidance_ray.target_position = target_local_pos
	
	# 2. Force the raycast to update its collision detection immediately
	avoidance_ray.force_raycast_update()
	
	# 3. Check if the ray collided with anything
	if avoidance_ray.is_colliding():
		# It hit something, check if the collision was *not* the target itself
		var collider = avoidance_ray.get_collider()
		
		# If the collider is NOT the target, it means the shot is blocked by a wall/building.
		if collider != target:
			return false
	
	return true # Either no collision, or the collision was the target itself

# Finds the closest available node in the "extraction_points" group (Movement Target)
func _find_nearest_extraction_point() -> Node2D:
	var extraction_points: Array = get_tree().get_nodes_in_group("extraction_points")
	
	if extraction_points.is_empty():
		push_warning("Monster %s: No extraction points found! Movement stalled." % name)
		return null

	# Sort and return the closest point
	extraction_points.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	return extraction_points[0]

func _update_path() -> void:
	# CRITICAL: Movement target is always the nearest Extraction Point
	var movement_target = _find_nearest_extraction_point()
	if movement_target:
		navigation_agent.target_position = movement_target.global_position

# Finds the closest enemy (Attack Target)
func _find_nearest_attack_target() -> void:
	var attack_targets: Array = []
	
	# Target groups for Attack: player, friendly, healer, villagers (in order of proximity)
	var priority_groups = ["player", "friendly", "healer", "villagers"]

	for group_name in priority_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				attack_targets.append(node)

	# Set 'target' to the closest enemy for shooting/facing.
	if not attack_targets.is_empty():
		# Sort all potential attack targets by distance to find the absolute nearest
		attack_targets.sort_custom(func(a, b):
			return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
		)
		target = attack_targets[0]
	else:
		target = null

func _physics_process(_delta: float) -> void:
	var desired_velocity: Vector2 = Vector2.ZERO
	var movement_target = _find_nearest_extraction_point()

	if movement_target:
		# 1. Try to move using the Navigation Agent (safe pathfinding)
		if not navigation_agent.is_navigation_finished():
			var next_path_position: Vector2 = navigation_agent.get_next_path_position()
			var move_direction: Vector2 = global_position.direction_to(next_path_position).normalized()
			desired_velocity = move_direction * max_speed
		else:
			# 2. AGGRESSIVE OVERRIDE: If NavAgent is "finished" (i.e., blocked by wall/boundary),
			# force direct, non-navigated movement towards the extraction point.
			var move_direction: Vector2 = global_position.direction_to(movement_target.global_position).normalized()
			desired_velocity = move_direction * max_speed
	
	# If no movement is desired (no extraction point), apply drag to stop.
	if desired_velocity.is_zero_approx():
		velocity = velocity.lerp(Vector2.ZERO, drag)
		move_and_slide()
		_process_collisions()
		return
	
	# 3. Submit the calculated velocity to the NavigationAgent for RVO/avoidance calculation
	navigation_agent.set_velocity(desired_velocity)

	# 4. Process collisions
	_process_collisions()
	
# Receives safe velocity from NavigationAgent2D and applies movement
func _on_navigation_agent_velocity_computed(safe_velocity: Vector2) -> void:
	# Use the safe velocity for movement
	velocity = safe_velocity
	
	# Apply acceleration and clamping for smooth movement
	var new_velocity = velocity.lerp(safe_velocity, acceleration * get_physics_process_delta_time())
	velocity = new_velocity.limit_length(max_speed)
	
	# Move is performed here using the safe velocity
	move_and_slide()

# Separated collision logic
func _process_collisions():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		# Only collide damage the player/friendly groups
		if body and (body.is_in_group("player") or body.is_in_group("friendly") or body.is_in_group("healer")):
			if body.has_method("take_damage"):
				var current_time: float = Time.get_unix_time_from_system()
				var last_time: float = last_damage_times.get(body, 0.0)
				if current_time - last_time >= 2.0:
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
		if get_parent() is NodePool:
			get_parent().despawn(self)
		else:
			visible = false
			set_process(false)
			set_physics_process(false)
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
	else:
		_damage_flash()

func _spawn_potion(potion_data: Dictionary) -> void:
	# Spawn potion on death
	if potion_pool:
		var potion: Area2D = potion_pool.spawn() as Area2D
		if potion:
			potion.global_position = global_position
			potion.setup(potion_data)

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
