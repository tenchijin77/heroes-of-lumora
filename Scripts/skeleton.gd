#skeleton.gd - skeleton monster sheet

extends CharacterBody2D

@export var max_speed : float
@export var acceleration : float
@export var drag : float
@export var health : int = 15



@onready var player = get_tree().get_first_node_in_group("player")
@onready var avoidance_ray : RayCast2D = $avoidance_ray
@onready var sprite : Sprite2D = $Sprite2D




var player_distance : float
var player_direction : Vector2


func _process (delta):
	player_distance = global_position.distance_to(player.global_position)
	player_direction =  global_position.direction_to(player.global_position)

	sprite.flip_h = player_direction.x > 0

func _physics_process(delta: float) -> void:
	var move_direction = player_direction
	var local_avoidance = _local_avoidance()
	
	if local_avoidance.length() > 0:
		move_direction = local_avoidance
		
	if velocity.length() < max_speed:
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
	
	
		
