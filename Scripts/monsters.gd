# monsters.gd - base monster template script

extends CharacterBody2D

signal mob_died  # Emitted when the monster dies

@export var max_speed : float = 35.0
@export var acceleration : float = 10.0
@export var drag : float = 0.9
@export var collision_damage : int = 3
@export var shoot_rate : float = 1.5
@export var shoot_range : float = 150.0 
@export var current_health : int = 15
@export var max_health : int = 15
@export var bullet_scene : PackedScene  # Override in child for specific projectile

@onready var player : CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var avoidance_ray : RayCast2D = $avoidance_ray
@onready var sprite : Sprite2D = $Sprite2D
@onready var muzzle : Node2D = $muzzle 
@onready var bullet_pool : NodePool = $bullet_pool 
@onready var health_bar : ProgressBar = $health_bar
@onready var collision_shape : CollisionShape2D = $CollisionShape2D

var player_distance : float
var player_direction : Vector2
var last_shoot_time : float = 0.0 

func _ready():
	if bullet_scene:
		bullet_pool.node_scene = bullet_scene
	else:
		push_warning("Monster %s: bullet_scene not set; no shooting possible!" % name)
	if not health_bar:
		push_error("Monster %s: health_bar is null!" % name)
	if not collision_shape:
		push_error("Monster %s: collision_shape is null!" % name)
	if not player:
		push_error("Monster %s: Player reference is null!" % name)
	else:
		print("Monster %s initialized, player ref: %s" % [name, player])
	reset()  # Initialize state on first creation


func reset():
	visible = true
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	else:
		push_warning("Monster %s: health_bar is null in reset—check scene node!" % name)
	velocity = Vector2.ZERO
	last_shoot_time = 0.0
	set_process(true)
	set_physics_process(true)
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	global_position = Vector2.ZERO  # Will be set by spawner
	print("Monster %s reset, position: %s, velocity: %s, health: %s / %s" % [name, global_position, velocity, current_health, max_health])

func _process(_delta: float) -> void:
	if not player:
		return
	player_distance = global_position.distance_to(player.global_position)
	player_direction = global_position.direction_to(player.global_position)
	sprite.flip_h = player_direction.x > 0
	if player_distance < shoot_range:
		if Time.get_unix_time_from_system() - last_shoot_time > shoot_rate:
			_cast()
	_move_wobble()

func _cast():
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not player:
		push_warning("Monster %s: Cannot cast—missing bullet_pool, muzzle, or player!" % name)
		return
	var projectile = bullet_pool.spawn()
	if projectile:
		projectile.global_position = muzzle.global_position
		projectile.move_direction = muzzle.global_position.direction_to(player.global_position)
		print("Monster %s: Cast default projectile %s, move_direction=%s, position=%s" % [name, projectile.name, projectile.move_direction, projectile.global_position])
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
				body.take_damage(collision_damage)
				print("%s collided with player and dealt %s damage!" % [name, collision_damage])

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
	else:
		push_error("Monster %s: health_bar is null in take_damage!" % name)
	if current_health <= 0:
		mob_died.emit()
		if get_parent() is NodePool:
			get_parent().despawn(self)
		else:
			visible = false
			set_process(false)
			set_physics_process(false)
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
			print("Monster %s: Despawn fallback at zero health" % name)
	else:
		_damage_flash()

func _damage_flash():
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
