#monsters.gd - base script for monster behavior
extends CharacterBody2D

signal mob_died  # Emitted when the monster dies

@export var max_speed : float = 50.0
@export var acceleration : float = 10.0
@export var drag : float = 0.9
@export var current_health : int = 15
@export var max_health : int = 15
@export var collision_damage : int = 3
@export var shoot_rate : float = 1.5
@export var shoot_range : float = 150.0
@export var collision_cooldown : float = 1.0

@onready var player = get_tree().get_first_node_in_group("player")
@onready var avoidance_ray : RayCast2D = $avoidance_ray
@onready var sprite : Sprite2D = $Sprite2D
@onready var muzzle : Node2D = $muzzle
@onready var projectile_pool = $projectile_pool
@onready var health_bar : ProgressBar = $health_bar

var player_distance : float
var player_direction : Vector2
var last_shoot_time : float = -1.0
var last_collision_time : float = 0.0

func _ready():
	if not is_inside_tree():
		await tree_entered
	if not health_bar:
		push_error("%s: health_bar is null!" % name)
	if not sprite:
		push_error("%s: sprite is null!" % name)
	if not projectile_pool:
		push_error("%s: projectile_pool is null!" % name)
	else:
		if projectile_pool.cached_nodes.size() == 0:
			push_warning("%s: projectile_pool has no preloaded nodes!" % name)
	if not avoidance_ray:
		push_error("%s: avoidance_ray is null!" % name)
	if not muzzle:
		push_error("%s: muzzle is null!" % name)
	if not player:
		push_error("%s: Player reference is null!" % name)
	else:
		sprite.visible = true
		print("%s initialized, player ref: %s, health_bar: %s, health: %d, bar_max: %s, bar_value: %s, visible: %s" % [name, player, health_bar, current_health, str(health_bar.max_value) if health_bar else "null", str(health_bar.value) if health_bar else "null", visible])
	reset()

func reset():
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true
		health_bar.queue_redraw()
	velocity = Vector2.ZERO
	last_shoot_time = -1.0
	last_collision_time = 0.0
	set_process(true)
	set_physics_process(true)
	if sprite:
		sprite.visible = true
	print("%s reset, health: %d, velocity: %s, bar_max: %s, bar_value: %s, visible: %s" % [name, current_health, velocity, str(health_bar.max_value) if health_bar else "null", str(health_bar.value) if health_bar else "null", visible])

func get_current_health() -> int:
	return current_health

func _process(delta):
	if not player or is_queued_for_deletion():
		return
	player_distance = global_position.distance_to(player.global_position)
	player_direction = global_position.direction_to(player.global_position)
	sprite.flip_h = player_direction.x > 0
	
	if player_distance < shoot_range:
		if last_shoot_time < 0 or Time.get_unix_time_from_system() - last_shoot_time > shoot_rate:
			_cast_projectile()
	
	_move_wobble()

func _physics_process(delta: float) -> void:
	if not player or is_queued_for_deletion():
		return
	
	var move_direction = player_direction
	var local_avoidance = _local_avoidance()
	
	if local_avoidance.length() > 0:
		move_direction = local_avoidance
	
	if velocity.length() < max_speed:
		velocity += move_direction * acceleration * delta
	else:
		velocity *= drag
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		if body and body.is_in_group("player"):
			if Time.get_unix_time_from_system() - last_collision_time > collision_cooldown:
				if body.has_method("take_damage"):
					body.take_damage(collision_damage)
					last_collision_time = Time.get_unix_time_from_system()
					print("%s collided with player, dealt %d damage" % [name, collision_damage])
		elif body and body.is_in_group("environment"):
			velocity = velocity.slide(collision.get_normal())
			print("%s slid along environment wall" % name)

func _cast_projectile():
	# To be overridden by child classes
	pass

func _move_wobble():
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

func take_damage(damage : int):
	current_health -= damage
	if health_bar:
		health_bar.value = current_health
		health_bar.queue_redraw()
	else:
		push_error("%s: health_bar is null in take_damage!" % name)
	if current_health <= 0:
		mob_died.emit()
		visible = false
		if sprite:
			sprite.visible = false
		set_process(false)
		set_physics_process(false)
	else:
		_damage_flash()

func _damage_flash():
	if sprite:
		sprite.modulate = Color.BLACK
		await get_tree().create_timer(0.05).timeout
		sprite.modulate = Color.WHITE

func _on_visibility_changed():
	if visible:
		if sprite:
			sprite.visible = true
		if health_bar:
			health_bar.visible = true
		print("%s made visible, sprite: %s, health_bar: %s" % [name, sprite.visible if sprite else "null", health_bar.visible if health_bar else "null"])
	else:
		set_process(false)
		set_physics_process(false)
		if sprite:
			sprite.visible = false
		if health_bar:
			health_bar.visible = false
		print("%s hidden, velocity: %s" % [name, velocity])
