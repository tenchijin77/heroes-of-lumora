# guard.gd - Guard NPC specific script (extends CharacterBody2D)
extends CharacterBody2D

@export var max_speed : float = 30.0
@export var acceleration : float = 10.0
@export var drag : float = 0.9
@export var shoot_rate : float = 1.0 # Arrows per second
@export var shoot_range : float = 150.0 # How close monster needs to be to shoot
@export var current_health : int = 20
@export var max_health : int = 20
@export var collision_damage : int = 3 # Damage if guard bumps into something (optional)
@export var guard_center_offset: Vector2 = Vector2.ZERO # Local offset from Guard's initial spawn point
@export var guard_area_radius: float = 200.0 # How far guard can roam from their home spot

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool # Ensure NodePool is set up in .tscn
@onready var detection_area: Area2D = $Area2D # This is your 'defense_zone' Area2D's parent
@onready var health_bar: ProgressBar = $health_bar # Ensure health_bar is set up

var current_target: CharacterBody2D = null
var detected_monsters: Array[CharacterBody2D] = []
var current_state: String = "IDLE" # States: IDLE, CHASING, ATTACKING, RETURNING

var last_shoot_time: float = 0.0
var guard_home_position: Vector2 # The world position where this guard considers 'home'

func _ready():
	# Store the initial global position as their "home" point
	guard_home_position = global_position + guard_center_offset

	# Set up bullet pool from the editor's bullet_scene export
	# Ensure bullet_scene is set in the editor for guard.tscn's script.
	if bullet_pool and bullet_pool.node_scene == null: # Only set if not already set by editor export
		# Assuming you have set guard.tscn's bullet_pool.node_scene to guard_arrow.tscn via editor
		# If you rely on script, you'd export PackedScene bullet_scene and assign it here:
		# bullet_pool.node_scene = bullet_scene
		push_warning("Guard %s: bullet_pool node_scene not set in editor!" % name)
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	# Connect signals from the detection Area2D
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_error("Guard %s: DetectionArea node not found!" % name)

func _process(delta: float) -> void:
	_update_target() # Always try to find the best target

	match current_state:
		"IDLE":
			_idle_state(delta)
		"CHASING":
			_chasing_state(delta)
		"ATTACKING":
			_attacking_state(delta)
		"RETURNING":
			_returning_state(delta)
	
	_update_flip_h() # Make sure the guard faces the correct direction

func _physics_process(delta: float) -> void:
	move_and_slide() # Handles CharacterBody2D physics movement

func _update_flip_h():
	# Default facing: Assumed to be facing LEFT in the sprite sheet
	# If the guard's sprite is facing LEFT by default (like your skeleton/wizard)
	# then flip_h = true will make it face RIGHT.
	
	if velocity.x > 0: # Moving right
		sprite.flip_h = true
	elif velocity.x < 0: # Moving left
		sprite.flip_h = false
	elif current_target: # If not moving, face the target if there is one
		# This assumes sprite.flip_h = true means facing right
		sprite.flip_h = global_position.direction_to(current_target.global_position).x > 0
	# else if no target and not moving, maintain last orientation or default to false

func _update_target():
	# 1. Clean up detected_monsters (remove nulls or invalid instances)
	detected_monsters = detected_monsters.filter(func(m):
		return is_instance_valid(m) and m.is_in_group("monsters")
	)

	# 2. Sort by distance (closest first)
	detected_monsters.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	# 3. Assign current_target
	if not detected_monsters.is_empty():
		current_target = detected_monsters[0] # Target the closest monster
		# Transition to chasing if we weren't already engaged
		if current_state == "IDLE" or current_state == "RETURNING":
			current_state = "CHASING"
	else:
		current_target = null
		# If we lost target and were chasing/attacking, go home
		if current_state == "CHASING" or current_state == "ATTACKING":
			current_state = "RETURNING"

# --- State Machine Functions ---

func _idle_state(delta: float):
	velocity = Vector2.ZERO # Stand still
	# Can add subtle animation or slight wander if desired

func _chasing_state(delta: float):
	if current_target and is_instance_valid(current_target):
		var distance_to_target = global_position.distance_to(current_target.global_position)
		
		# If within shooting range, switch to attacking
		if distance_to_target <= shoot_range:
			current_state = "ATTACKING"
		# If target is too far from home, return
		elif global_position.distance_to(guard_home_position) > guard_area_radius:
			current_state = "RETURNING"
		else:
			# Move towards the target
			var direction = global_position.direction_to(current_target.global_position)
			velocity = velocity.lerp(direction * max_speed, acceleration * delta)
	else: # Lost target while chasing
		current_state = "RETURNING"

func _attacking_state(delta: float):
	velocity = Vector2.ZERO # Stop movement while attacking
	
	if current_target and is_instance_valid(current_target):
		var distance_to_target = global_position.distance_to(current_target.global_position)
		if distance_to_target <= shoot_range:
			_perform_attack() # Try to shoot
		else:
			current_state = "CHASING" # Target moved out of range, re-engage
	else: # Target died or became invalid
		current_state = "RETURNING" # Go home

func _returning_state(delta: float):
	var distance_to_home = global_position.distance_to(guard_home_position)
	
	if distance_to_home < 5.0: # Arbitrary small distance to consider "home"
		velocity = Vector2.ZERO
		current_state = "IDLE"
	else:
		# Move towards home position
		var direction = global_position.direction_to(guard_home_position)
		velocity = velocity.lerp(direction * max_speed, acceleration * delta)

# --- Attack Logic ---

func _perform_attack():
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_shoot_time > shoot_rate:
		last_shoot_time = current_time
		if bullet_pool and muzzle and current_target and is_instance_valid(current_target):
			var projectile = bullet_pool.spawn()
			if projectile:
				projectile.global_position = muzzle.global_position
				# Set projectile direction towards the target
				projectile.move_direction = muzzle.global_position.direction_to(current_target.global_position)
				projectile.owner_group = "friendly" # IMPORTANT: Set this to friendly group
				print("Guard %s: Fired arrow at %s" % [name, current_target.name])
			else:
				push_warning("Guard %s: Failed to spawn projectile!" % name)
		else:
			push_warning("Guard %s: Cannot fire—missing bullet_pool, muzzle, or invalid target!" % name)

# --- Health / Damage Logic (similar to monsters) ---

func take_damage(damage : int):
	current_health -= damage
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		_die()
	else:
		_damage_flash()

func _damage_flash():
	sprite.modulate = Color.RED # Flash red on hit
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE

func _die():
	print("Guard %s died!" % name)
	# Despawn if part of a NodePool, otherwise hide/disable
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		visible = false
		set_process(false)
		set_physics_process(false)
		# Disable collision shape if not despawning
		if $CollisionShape2D: # Assuming CollisionShape2D exists
			$CollisionShape2D.set_deferred("disabled", true)

# --- Signal Connections ---

func _on_detection_area_body_entered(body: Node2D):
	# Make sure it's a monster and not already in our list
	if body.is_in_group("monsters") and body is CharacterBody2D and not detected_monsters.has(body):
		detected_monsters.append(body)
		print("Guard detected monster: ", body.name)

func _on_detection_area_body_exited(body: Node2D):
	if detected_monsters.has(body):
		detected_monsters.erase(body)
		print("Guard lost monster: ", body.name)
		
func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health
