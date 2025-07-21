#wizard.gd - wizard monster sheet

extends CharacterBody2D

@export var max_speed : float = 25
@export var acceleration : float = 10
@export var drag : float = .9
@export var stop_range : float = 25
@export var shoot_rate : float = .8
@export var shoot_range : float = 150
@export var current_health : int = 25
@export var max_health : int = 25
@export var collision_damage : int = 3



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
			
	_move_wobble()

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

	# --- NEW: Check for collisions with the player after movement ---
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		# Ensure the collided body exists and is the player
		if body and body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(collision_damage)
				print(name, " collided with player and dealt ", collision_damage, " damage!")
				# Optional: You might want to add a small delay or cooldown here
				# to prevent the monster from instantly spamming damage if it stays
				# on top of the player. For now, it will damage every physics frame.
	
func _move_wobble ():
	if velocity.length() == 0:
		sprite.rotation_degrees = 0
		return
		
	var t = Time.get_unix_time_from_system()
	var rot = sin(t * 20) * 2
	
	sprite.rotation_degrees = rot
	
		

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


func take_damage (damage : int):
	current_health -= damage
	
	if current_health <= 0:
		visible = false
	else:
		_damage_flash()
		
func _damage_flash ():
	sprite.modulate = Color.BLACK
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE
	
		


func _on_visibility_changed() -> void:

	if visible:
		set_process(false)
		set_physics_process(false)
		current_health = max_health
	else:
		set_process(false)
		set_physics_process(false)
		
		global_position = Vector2(0 ,999999)
