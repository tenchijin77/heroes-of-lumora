# monsters.gd - Base script for monster behavior, targeting nearest friendly or player
extends CharacterBody2D
signal mob_died

@export var max_speed: float = 35.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var collision_damage: int = 3
@export var shoot_rate: float = 1.5
@export var shoot_range: float = 150.0
@export var current_health: int = 15
@export var max_health: int = 15
@export var bullet_scene: PackedScene
@export var score_value: int = 10 # Points awarded when killed by player
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var potion_pool: NodePool = $potion_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
var potions_data: Dictionary = {}
var target: Node2D
var target_distance: float
var target_direction: Vector2
var last_shoot_time: float = 0.0
var last_damage_source: Node = null # Track the last entity to damage this monster
var last_damage_times: Dictionary = {} # Tracks last collision damage time per target

func _ready() -> void:
	# Initialize monster properties and navigation
	add_to_group("monsters")
	# Set collision mask to exclude monsters (layer 2), include player (1), player projectiles (3), environment (5), friendly (6), friendly projectiles (7), healing (10)
	collision_mask = 1 + 4 + 16 + 32 + 64 + 512 # Layers 1, 3, 5, 6, 7, 10
	# Configure navigation agent
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	navigation_agent.radius = 10.0 # Adjust to monster size
	navigation_agent.avoidance_enabled = true
	navigation_agent.avoidance_layers = 1 << 4
	var file: FileAccess = FileAccess.open("res://Data/potions.json", FileAccess.READ)
	if file:
		potions_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		print("Monster %s: Failed to open potions.json!" % name)
	if bullet_scene:
		bullet_pool.node_scene = bullet_scene
	else:
		push_warning("Monster %s: bullet_scene not set!" % name)
	if not health_bar:
		push_error("Monster %s: health_bar is null!" % name)
	if not collision_shape:
		push_error("Monster %s: collision_shape is null!" % name)
	_find_nearest_target()
	reset()
	_update_path()

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
	last_damage_times = {} # Reset collision damage tracker
	set_process(true)
	set_physics_process(true)
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	# Conditionally reset position only if reused node is at origin (pool-specific)
	if get_parent() is NodePool and global_position == Vector2.ZERO:
		global_position = Vector2.ZERO # For reused nodes at origin

func _process(_delta: float) -> void:
	# Update target and shooting logic
	_find_nearest_target()
	if not target:
		return
	target_distance = global_position.distance_to(target.global_position)
	target_direction = global_position.direction_to(target.global_position)
	sprite.flip_h = target_direction.x > 0
	if target_distance < shoot_range:
		if Time.get_unix_time_from_system() - last_shoot_time > shoot_rate:
			_cast()
	_move_wobble()
	_update_path() # Update path every frame for dynamic targets

func _update_path() -> void:
	# Update navigation path to target
	if target:
		navigation_agent.target_position = target.global_position

func _physics_process(_delta: float) -> void:
	# Move using navigation path
	if not target or navigation_agent.is_navigation_finished():
		velocity = velocity.lerp(Vector2.ZERO, drag)
		return
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var move_direction: Vector2 = global_position.direction_to(next_path_position).normalized()
	if velocity.length() < max_speed:
		velocity += move_direction * acceleration
	else:
		velocity *= drag
	move_and_slide()
	if not navigation_agent.is_navigation_finished():
		print("Monster %s: Moving to path point %s, Distance=%.2f, Velocity=%s" % [name, next_path_position, target_distance, velocity])
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		if body and (body.is_in_group("player") or body.is_in_group("friendly") or body.is_in_group("healer")):
			if body.has_method("take_damage"):
				var current_time: float = Time.get_unix_time_from_system()
				var last_time: float = last_damage_times.get(body, 0.0)
				if current_time - last_time >= 2.0:
					last_damage_times[body] = current_time
					body.call_deferred("take_damage", collision_damage, null)
					print("Monster %s dealt %d collision damage to %s" % [name, collision_damage, body.name])

func _move_wobble() -> void:
	# Apply sprite wobble animation
	if velocity.length() == 0:
		sprite.rotation_degrees = 0
		return
	var t = Time.get_unix_time_from_system()
	var rot = sin(t * 20) * 2
	sprite.rotation_degrees = rot

func _cast() -> void:
	# Fire projectile at target
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Monster %s: Cannot cast!" % name)
		return
	var projectile = bullet_pool.spawn()
	if projectile:
		projectile.global_position = muzzle.global_position
		projectile.move_direction = muzzle.global_position.direction_to(target.global_position)
		print("Monster %s: Cast projectile %s at %s" % [name, projectile.name, target.name])
	else:
		push_warning("Monster %s: Failed to spawn projectile!" % name)

func _find_nearest_target() -> void:
	# Find closest player or friendly target
	var friendlies: Array = get_tree().get_nodes_in_group("friendly")
	var players: Array = get_tree().get_nodes_in_group("player")
	var all_targets: Array = friendlies + players
	if all_targets.is_empty():
		target = null
		return
	all_targets.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	target = all_targets[0]

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
