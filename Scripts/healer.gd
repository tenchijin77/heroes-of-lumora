# healer.gd
extends CharacterBody2D

# Expose properties in the editor for tuning
@export var max_speed: float = 40.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var attack_rate: float = 1.0 # How often to shoot a projectile
@export var attack_range: float = 150.0 # How close monster needs to be to attack
@export var heal_rate: float = 2.0 # How often to cast a heal
@export var heal_range: float = 200.0 # How close friendly unit needs to be to heal
@export var current_health: int = 25
@export var max_health: int = 25
@export var patrol_radius: float = 300.0 # How far healer can roam
@export var projectile_scene: PackedScene # For the healing/attacking projectile

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool # For projectiles
@onready var health_bar: ProgressBar = $health_bar
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var patrol_timer: Timer = $patrol_timer

# Declare state machine variables
var current_target: CharacterBody2D = null
var current_friendly_target: CharacterBody2D = null
var current_state: String = "PATROL" # States: "PATROL", "HEALING", "ATTACKING"

var last_action_time: float = 0.0
var patrol_center: Vector2 # The world position where this healer considers 'home'
var patrol_target: Vector2 # The random point the healer is moving towards

func _ready() -> void:
	# Set up NodePool and HealthBar similar to how it's done in monsters.gd 
	if projectile_scene:
		bullet_pool.node_scene = projectile_scene
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	patrol_center = global_position
	_update_patrol_target()
	
	# Add to friendly group and set collision layers/masks
	add_to_group("friendly")
	# Collision layers and masks will be set in the scene file, but we can double-check here.
	set_collision_layer_value(6, true)
	set_collision_mask_value(2, true)  # Collide with monsters
	set_collision_mask_value(4, true)  # Collide with enemy projectiles
	
	# Connect signals
	patrol_timer.timeout.connect(_update_patrol_target)

func _process(delta: float) -> void:
	# Always check for potential targets
	_update_targets()
	
	match current_state:
		"PATROL":
			_patrol_state(delta)
		"HEALING":
			_healing_state(delta)
		"ATTACKING":
			_attacking_state(delta)
	
	_update_flip_h()

func _physics_process(delta: float) -> void:
	# Reusing the movement logic from guard.gd [cite: 12]
	move_and_slide()

# --- Core Logic Functions ---

func _update_targets():
	current_friendly_target = _find_low_health_friendly()
	
	if current_friendly_target:
		current_state = "HEALING"
		current_target = null # Clear enemy target
	else:
		current_target = _find_closest_mob()
		if current_target:
			current_state = "ATTACKING"
		else:
			current_state = "PATROL"

func _find_low_health_friendly() -> CharacterBody2D:
	var closest_unit: CharacterBody2D = null
	var min_distance: float = heal_range
	
	# Check friendly NPCs
	for unit in get_tree().get_nodes_in_group("friendly"):
		# Make sure we don't heal ourselves.
		if unit != self and is_instance_valid(unit) and unit.has_method("get_health") and unit.get_health() < unit.get_max_health():
			var distance = global_position.distance_to(unit.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_unit = unit
	
	# Check the player
	if is_instance_valid(player) and player.has_method("get_health") and player.get_health() < player.get_max_health():
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_unit = player
			
	return closest_unit

func _find_closest_mob() -> CharacterBody2D:
	# This logic is similar to what's in your guard.gd's _update_target()
	var closest_mob: CharacterBody2D = null
	var min_distance = attack_range # Only target mobs in range
	
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob):
			var distance = global_position.distance_to(mob.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_mob = mob
				
	return closest_mob

# --- State Machine Functions ---

func _patrol_state(delta: float):
	# Move towards the random patrol target
	var direction = global_position.direction_to(patrol_target)
	velocity = velocity.lerp(direction * max_speed, acceleration * delta)
	
	# Check if we've arrived at the patrol point
	if global_position.distance_to(patrol_target) < 10.0:
		_update_patrol_target()

func _healing_state(delta: float):
	if current_friendly_target and is_instance_valid(current_friendly_target):
		var distance_to_target = global_position.distance_to(current_friendly_target.global_position)
		
		# Stop and heal if in range, otherwise move closer
		if distance_to_target <= heal_range:
			velocity = Vector2.ZERO
			_perform_heal()
		else:
			var direction = global_position.direction_to(current_friendly_target.global_position)
			velocity = velocity.lerp(direction * max_speed, acceleration * delta)
	else:
		current_state = "PATROL" # Target disappeared or was fully healed

func _attacking_state(delta: float):
	if current_target and is_instance_valid(current_target):
		var distance_to_target = global_position.distance_to(current_target.global_position)
		
		# Stop and attack if in range, otherwise move closer
		if distance_to_target <= attack_range:
			velocity = Vector2.ZERO
			_perform_attack()
		else:
			var direction = global_position.direction_to(current_target.global_position)
			velocity = velocity.lerp(direction * max_speed, acceleration * delta)
	else:
		current_state = "PATROL" # Target disappeared

# --- Action Functions ---

func _perform_heal():
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_action_time > heal_rate:
		last_action_time = current_time
		_cast_projectile(current_friendly_target, "friendly")

func _perform_attack():
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_action_time > attack_rate:
		last_action_time = current_time
		_cast_projectile(current_target, "monsters")

func _cast_projectile(target: CharacterBody2D, target_group: String):
	# This is a generic function to cast either a heal or damage projectile
	if bullet_pool and muzzle and target and is_instance_valid(target):
		var projectile = bullet_pool.spawn()
		if projectile:
			projectile.global_position = muzzle.global_position
			projectile.move_direction = muzzle.global_position.direction_to(target.global_position)
			projectile.owner_group = target_group # This is key for the projectile's logic
			print("Healer: Fired projectile at %s" % target.name)
		else:
			push_warning("Healer: Failed to spawn projectile!")
	else:
		push_warning("Healer: Cannot fire—missing bullet_pool, muzzle, or invalid target!")

func _update_patrol_target():
	patrol_target = patrol_center + Vector2(randf_range(-patrol_radius, patrol_radius), randf_range(-patrol_radius, patrol_radius))
	patrol_timer.start(randf_range(3.0, 7.0)) # Patrol for 3-7 seconds before picking a new point

# --- Health and Utility Functions ---

func _update_flip_h():
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false

func take_damage(damage: int):
	current_health -= damage
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		_die()
	else:
		_damage_flash()

func _damage_flash():
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE

func _die():
	print("Healer died!")
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		visible = false
		set_process(false)
		set_physics_process(false)
		if $CollisionShape2D:
			$CollisionShape2D.set_deferred("disabled", true)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health
