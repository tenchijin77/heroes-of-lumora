# guard.gd - AI for Guard's logic
extends CharacterBody2D

@export var max_speed: float = 30.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var shoot_rate: float = 1.0
@export var shoot_range: float = 250.0
@export var base_damage: int = 12 # Base damage for projectiles
@export var current_health: int = 200
@export var max_health: int = 200
@export var guard_center_offset: Vector2 = Vector2.ZERO
@export var guard_area_radius: float = 200.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var detection_area: Area2D = $Area2D
@onready var health_bar: ProgressBar = $health_bar
@onready var avoidance_ray: RayCast2D = $avoidance_ray

var current_target: CharacterBody2D = null
var detected_monsters: Array[CharacterBody2D] = []
var current_state: String = "IDLE"
var last_shoot_time: float = 0.0
var damage_modifier: float = 1.0 # Multiplier for damage buffs
var guard_home_position: Vector2

func _ready() -> void:
	# Initialize Guard in the scene
	add_to_group("friendly")
	guard_home_position = global_position + guard_center_offset
	velocity = Vector2.ZERO
	if bullet_pool and bullet_pool.node_scene == null:
		push_warning("Guard %s: bullet_pool node_scene not set in editor!" % name)
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_error("Guard %s: DetectionArea node not found!" % name)

func _process(delta: float) -> void:
	# Update Guard's logic each frame
	_update_target()
	_update_avoidance_ray(current_target, shoot_range)
	match current_state:
		"IDLE":
			_idle_state(delta)
		"CHASING":
			_chasing_state(delta)
		"ATTACKING":
			_attacking_state(delta)
		"RETURNING":
			_returning_state(delta)
	_update_flip_h()

func _physics_process(delta: float) -> void:
	# Handle physics-based movement
	move_and_slide()

func _update_flip_h() -> void:
	# Flip sprite based on movement or target
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false
	elif current_target:
		sprite.flip_h = global_position.direction_to(current_target.global_position).x > 0

func _update_target() -> void:
	# Update current target based on detected monsters
	detected_monsters = detected_monsters.filter(
		func(m): return is_instance_valid(m) and m.is_in_group("monsters")
	)
	detected_monsters.sort_custom(
		func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	if not detected_monsters.is_empty():
		current_target = detected_monsters[0]
		if current_state == "IDLE" or current_state == "RETURNING":
			current_state = "CHASING"
	else:
		current_target = null
		if current_state in ["CHASING", "ATTACKING"]:
			current_state = "RETURNING"

func _idle_state(delta: float) -> void:
	# Stop movement in idle state
	velocity = Vector2.ZERO

func _chasing_state(delta: float) -> void:
	# Chase target or return if out of range
	if current_target and is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= shoot_range:
			current_state = "ATTACKING"
		elif global_position.distance_to(guard_home_position) > guard_area_radius:
			current_state = "RETURNING"
		else:
			var dir = global_position.direction_to(current_target.global_position)
			velocity = velocity.lerp(dir * max_speed, acceleration * delta)
	else:
		current_state = "RETURNING"

func _attacking_state(delta: float) -> void:
	# Attack target if in range
	velocity = Vector2.ZERO
	if current_target and is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= shoot_range and _has_clear_line_to_target(current_target):
			_perform_attack()
		else:
			current_state = "CHASING"
	else:
		current_state = "RETURNING"

func _returning_state(delta: float) -> void:
	# Return to home position
	var dist = global_position.distance_to(guard_home_position)
	if dist < 5.0:
		velocity = Vector2.ZERO
		current_state = "IDLE"
	else:
		var dir = global_position.direction_to(guard_home_position)
		velocity = velocity.lerp(dir * max_speed, acceleration * delta)

func _perform_attack() -> void:
	# Fire projectile at target
	var time = Time.get_unix_time_from_system()
	if time - last_shoot_time > shoot_rate:
		last_shoot_time = time
		var projectile = bullet_pool.spawn()
		if projectile:
			projectile.global_position = muzzle.global_position
			projectile.move_direction = muzzle.global_position.direction_to(current_target.global_position)
			projectile.owner_group = "friendly"
			if projectile.has_method("set_damage"):
				projectile.set_damage(base_damage * damage_modifier)
			print("Guard %s: Fired arrow at %s" % [name, current_target.name])
		else:
			push_warning("Guard %s: Failed to spawn projectile!" % name)

func _update_avoidance_ray(target: Node2D, range: float) -> void:
	# Update raycast for line-of-sight
	if avoidance_ray and target:
		avoidance_ray.target_position = (target.global_position - global_position).normalized() * range
		avoidance_ray.force_raycast_update()

func _has_clear_line_to_target(target: Node2D) -> bool:
	# Check if there's a clear line to target
	return not avoidance_ray.is_colliding() or avoidance_ray.get_collider() == target

func take_damage(damage: int, _projectile_instance) -> void:
	# Apply damage and update health
	current_health -= damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	if current_health <= 0:
		_die()
	else:
		_damage_flash()

func _damage_flash() -> void:
	# Flash sprite red on hit
	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.05).timeout
		sprite.modulate = Color.WHITE

func _die() -> void:
	# Handle death
	print("Guard %s died!" % name)
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		visible = false
		set_process(false)
		set_physics_process(false)
		if $CollisionShape2D:
			$CollisionShape2D.set_deferred("disabled", true)

func _on_detection_area_body_entered(body: Node2D) -> void:
	# Add monster to detected list
	if body.is_in_group("monsters") and body is CharacterBody2D and not detected_monsters.has(body):
		detected_monsters.append(body)

func _on_detection_area_body_exited(body: Node2D) -> void:
	# Remove monster from detected list
	if detected_monsters.has(body):
		detected_monsters.erase(body)

func get_health() -> int:
	# Return current health
	return current_health

func get_max_health() -> int:
	# Return maximum health
	return max_health

func heal(amount: int) -> void:
	# Heal Guard and update health bar
	current_health = clamp(current_health + amount, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	print("Guard %s healed for %d → current_health = %d" % [name, amount, current_health])

func set_damage_modifier(modifier: float) -> void:
	# Set damage multiplier for courage aura
	damage_modifier = modifier
