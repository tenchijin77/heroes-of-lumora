#player.gd - main character script
extends CharacterBody2D

@export var max_speed : float = 100.0
@export var acceleration : float = .2
@export var braking : float = .15

@onready var sprite : Sprite2D = $Sprite2D

var move_input : Vector2


func _physics_process(delta):
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	
	#make the player accelerate to speed, and slow down when the movement key is released
	
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
		
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	
	move_and_slide()
	
# this function will flip the sprite of the player horizontally based on the mouse position 	
func _process (delta):
	sprite.flip_h = get_global_mouse_position().x > global_position.x
	
