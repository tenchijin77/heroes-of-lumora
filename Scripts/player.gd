#player.gd - main character script
extends CharacterBody2D

@export var max_speed : float = 100.0
@export var acceleration : float = .2
@export var braking : float = .15
@export var firing_speed : float = .4
@export var current_health : int = 100
@export var max_health: int = 100
var last_shoot_time : float
var score : int = 0  # Tracks number of monsters killed
var survival_time : float = 0.0  # Tracks survival time in seconds

@onready var sprite : Sprite2D = $Sprite2D
@onready var muzzle = $muzzle
@onready var arrow_pool = $player_bullet_pool
@onready var health_bar : ProgressBar = $health_bar
@onready var score_label : Label = get_node("/root/main/CanvasLayer/score")  # Reference to score label
@onready var uptime_label : Label = get_node("/root/main/CanvasLayer/uptime")  # Reference to uptime label

var move_input : Vector2

# Removed to use the player_bullet_pool node pool instead.
#var arrow_scene : PackedScene = preload("res://Scenes/arrow.tscn")

func _ready ():
	health_bar.max_value = max_health
	health_bar.value = current_health

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
	
	if  Input.is_action_pressed("shoot"):
		if Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
			open_fire()
		
	_move_wobble()
	
	# Update survival time
	survival_time += delta
	update_time_label()

func open_fire():
	last_shoot_time = Time.get_unix_time_from_system()
	
	
	#removed in exchange for the bullet pool
	#var arrow = arrow_scene.instantiate()

	var arrow = arrow_pool.spawn()
	
	#no longer used; replaced by node pool functionality
	#get_tree().root.add_child(arrow)
	
	arrow.global_position = muzzle.global_position
	
	var mouse_position = get_global_mouse_position()
	var mouse_direction = muzzle.global_position.direction_to(mouse_position)
	
	arrow.move_dir = mouse_direction
	
func take_damage (damage : int):
	current_health -= damage
	
	if current_health <= 0:
		print("Game Over! LOADING, PLEASE WAIT......................")
	else:
		_damage_flash()
		health_bar.value = current_health
		
func _damage_flash ():
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE
	
	
func _move_wobble ():
	if move_input.length() == 0:
		sprite.rotation_degrees = 0
		return
		
	var t = Time.get_unix_time_from_system()
	var rot = sin(t * 20) * 2
	
	sprite.rotation_degrees = rot
	
# Increment score and update label
func increment_score():
	score += 1
	update_score_label()

# Update score label text
func update_score_label():
	if score_label:
		score_label.text = "Score: %d" % score
	else:
		push_error("Score label not found at ../CanvasLayer/score")

# Update uptime label text
func update_time_label():
	if uptime_label:
		var minutes = int(survival_time / 60)
		var seconds = int(survival_time) % 60
		uptime_label.text = "Time: %02d:%02d" % [minutes, seconds]
	else:
		push_error("Uptime label not found at ../CanvasLayer/uptime")
	
	
	
