#wizard.gd - wizard monster sheet

extends CharacterBody2D

@export var max_speed : float = 25
@export var acceleration : float = 10
@export var drag : float = .9
@export var stop_range : float = 25
@export var shoot_rate : float = .8
@export var shoot_range : float = 150
var last_shoot_time : float

@onready var player = get_tree().get_first_node_in_group("player")
@onready var avoidance_ray : RayCast2D = $avoidance_ray
@onready var sprite : Sprite2D = $Sprite2D
@onready var fireball_pool = $wizard_bullet_pool
@onready var muzzle = $muzzle


var player_distance : float
var player_direction : Vector2

func _process (delta):
	player_distance = global_position.distance_to(player.global_position)
	player_direction =  global_position.direction_to(player.global_position)

	sprite.flip_h = player_direction.x > 0
	
	if player_distance < shoot_range:
		if Time.get_unix_time_from_system() - last_shoot_time > shoot_rate:
			_cast()

func _physics_process(delta: float) -> void:
	var move_direction = player_direction
	var local_avoidance = _local_avoidance()
	
	if local_avoidance.length() > 0:
		move_direction = local_avoidance
		
	if velocity.length() < max_speed and player_distance > stop_range:
		velocity += move_direction * acceleration
	else:
		velocity *= drag
		
	move_and_slide()
	
func _local_avoidance () -> Vector2:
	avoidance_ray.target_position = to_local(player.global_position).normalized()
	avoidance_ray.target_position *= 80
	
	if not avoidance_ray.is_colliding():
		return Vector2.ZERO
			
	var obstacle = avoidance_ray.get_collider()
	
	if obstacle == player:
		return Vector2.ZERO
		
	var obstacle_point = avoidance_ray.get_collision_point()
	var obstacle_direction = global_position.direction_to(obstacle_point)
	
	return Vector2(-obstacle_direction.y, obstacle_direction.x)
	
	
func _cast ():
	last_shoot_time =Time.get_unix_time_from_system()
		
	var fireball = fireball_pool.spawn()
	fireball.global_position = muzzle.global_position
	fireball.move_direction = muzzle.global_position.direction_to(player.global_position)
