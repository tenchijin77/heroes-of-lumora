# monsters.gd
# Base script for monster behavior, targeting nearest friendly or player.
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
@onready var avoidance_ray: RayCast2D = $avoidance_ray
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var potion_pool: NodePool = $potion_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var potions_data: Dictionary = {}
var target: Node2D
var target_distance: float
var target_direction: Vector2
var last_shoot_time: float = 0.0
var last_damage_source: Node = null # Track the last entity to damage this monster

func _ready() -> void:
	add_to_group("monsters")
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

func reset() -> void:
	visible = true
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	velocity = Vector2.ZERO
	last_shoot_time = 0.0
	last_damage_source = null
	set_process(true)
	set_physics_process(true)
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	# Conditionally reset position only if reused node is at origin (pool-specific)
	if get_parent() is NodePool and global_position == Vector2.ZERO:
		global_position = Vector2.ZERO  # This only for reused nodes at origin

func _process(_delta: float) -> void:
	_find_nearest_target()
	if not target:
		return
	target_distance = global_position.distance_to(target.global_position)
	target_direction = global_position.direction_to(target.global_position)
	sprite.flip_h = target_direction.x > 0
	_update_avoidance_ray(target, shoot_range)
	if target_distance < shoot_range and _has_clear_line_to_target(target):
		if Time.get_unix_time_from_system() - last_shoot_time > shoot_rate:
			_cast()
	_move_wobble()

func _cast() -> void:
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

func _physics_process(_delta: float) -> void:
	if not target:
		return
	var move_direction = target_direction
	var local_avoidance = _local_avoidance()
	if local_avoidance.length() > 0:
		move_direction = local_avoidance
	if velocity.length() < max_speed:
		velocity += move_direction * acceleration
	else:
		velocity *= drag
	move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		if body and (body.is_in_group("player") or body.is_in_group("friendly")):
			if body.has_method("take_damage"):
				body.call_deferred("take_damage", collision_damage)

func _move_wobble() -> void:
	if velocity.length() == 0:
		sprite.rotation_degrees = 0
		return
	var t = Time.get_unix_time_from_system()
	var rot = sin(t * 20) * 2
	sprite.rotation_degrees = rot

func _local_avoidance() -> Vector2:
	avoidance_ray.target_position = to_local(target.global_position).normalized() * 80
	if not avoidance_ray.is_colliding():
		return Vector2.ZERO
	var obstacle = avoidance_ray.get_collider()
	if obstacle == target:
		return Vector2.ZERO
	var obstacle_point = avoidance_ray.get_collision_point()
	var obstacle_direction = global_position.direction_to(obstacle_point)
	return Vector2(-obstacle_direction.y, obstacle_direction.x)

func _update_avoidance_ray(target_node: Node2D, range: float) -> void:
	if avoidance_ray and target_node:
		avoidance_ray.target_position = (target_node.global_position - global_position).normalized() * range
		avoidance_ray.force_raycast_update()

func _has_clear_line_to_target(target_node: Node2D) -> bool:
	if not avoidance_ray or not target_node:
		return false
	return not avoidance_ray.is_colliding() or avoidance_ray.get_collider() == target_node

func _find_nearest_target() -> void:
	var friendlies: Array = get_tree().get_nodes_in_group("friendly")
	var players: Array = get_tree().get_nodes_in_group("player")
	var all_targets: Array = friendlies + players
	if all_targets.is_empty():
		target = null
		return
	all_targets.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	target = all_targets[0]

func take_damage(damage: int, projectile_instance: Node):
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
	if potion_pool:
		var potion: Area2D = potion_pool.spawn() as Area2D
		if potion:
			potion.global_position = global_position
			potion.setup(potion_data)

func _damage_flash() -> void:
	sprite.modulate = Color.BLACK
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE

func _on_visibility_changed() -> void:
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
