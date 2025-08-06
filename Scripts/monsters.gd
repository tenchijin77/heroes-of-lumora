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

@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var avoidance_ray: RayCast2D = $avoidance_ray
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var potion_pool: NodePool = $potion_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var potions_data: Dictionary = {}
var player_distance: float
var player_direction: Vector2
var last_shoot_time: float = 0.0

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
	if not player:
		push_error("Monster %s: Player reference is null!" % name)

	reset()

func reset() -> void:
	visible = true
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	velocity = Vector2.ZERO
	last_shoot_time = 0.0
	set_process(true)
	set_physics_process(true)
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	global_position = Vector2.ZERO

func _process(_delta: float) -> void:
	if not player:
		return

	player_distance = global_position.distance_to(player.global_position)
	player_direction = global_position.direction_to(player.global_position)
	sprite.flip_h = player_direction.x > 0

	_update_avoidance_ray(player, shoot_range)

	if player_distance < shoot_range and _has_clear_line_to_target(player):
		if Time.get_unix_time_from_system() - last_shoot_time > shoot_rate:
			_cast()

	_move_wobble()

func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not player:
		push_warning("Monster %s: Cannot cast!" % name)
		return

	var projectile = bullet_pool.spawn()
	if projectile:
		projectile.global_position = muzzle.global_position
		projectile.move_direction = muzzle.global_position.direction_to(player.global_position)
		print("Monster %s: Cast projectile %s" % [name, projectile.name])
	else:
		push_warning("Monster %s: Failed to spawn projectile!" % name)

func _physics_process(_delta: float) -> void:
	if not player:
		return

	var move_direction = player_direction
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
		if body and body.is_in_group("player"):
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
	avoidance_ray.target_position = to_local(player.global_position).normalized() * 80
	if not avoidance_ray.is_colliding():
		return Vector2.ZERO
	var obstacle = avoidance_ray.get_collider()
	if obstacle == player:
		return Vector2.ZERO
	var obstacle_point = avoidance_ray.get_collision_point()
	var obstacle_direction = global_position.direction_to(obstacle_point)
	return Vector2(-obstacle_direction.y, obstacle_direction.x)

func _update_avoidance_ray(target: Node2D, range: float):
	if avoidance_ray and target:
		avoidance_ray.target_position = (target.global_position - global_position).normalized() * range
		avoidance_ray.force_raycast_update()

func _has_clear_line_to_target(target: Node2D) -> bool:
	if not avoidance_ray or not target:
		return false
	return not avoidance_ray.is_colliding() or avoidance_ray.get_collider() == target

func take_damage(damage: int) -> void:
	current_health -= damage
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		mob_died.emit()
		if player:
			player.increment_score()

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
