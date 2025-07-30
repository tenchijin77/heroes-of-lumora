# player.gd - main character script
extends CharacterBody2D

@export var max_speed : float = 100.0
@export var acceleration : float = .2
@export var braking : float = .15
@export var firing_speed : float = .2
@export var current_health : int = 100
@export var max_health: int = 100
@export var regeneration_per_second : float = 1.0  # Health regenerated per second

var last_shoot_time : float
var survival_time : float = 0.0

@onready var sprite : Sprite2D = $Sprite2D
@onready var muzzle = $muzzle
@onready var arrow_pool = $player_bullet_pool
@onready var health_bar : ProgressBar = $health_bar
@onready var regeneration_timer : Timer = $regeneration_timer
@onready var score_label : Label = get_node("/root/main/CanvasLayer/VBoxContainer/score")
@onready var uptime_label : Label = get_node("/root/main/CanvasLayer/VBoxContainer/uptime")
@onready var wave_label : Label = get_node("/root/main/CanvasLayer/VBoxContainer/wave")
@onready var coin_label : Label = get_node("/root/main/CanvasLayer/VBoxContainer/coins")
@onready var player_damage_sound : AudioStreamPlayer2D = $player_damage_sound
@onready var pickup_area: Area2D = $pickup_area  # New reference to pickup area


var move_input : Vector2
# New variable for coins
var coin_count: int = 0

func _ready ():
	health_bar.max_value = max_health
	health_bar.value = current_health
	regeneration_timer.wait_time = 1.0
	regeneration_timer.autostart = true
	health_bar.max_value = max_health
	health_bar.value = current_health
	update_score_label()
	update_time_label()
	Global.current_score = 0

func _physics_process(_delta):
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	move_and_slide()

func _process (delta):
	sprite.flip_h = get_global_mouse_position().x > global_position.x
	if  Input.is_action_pressed("shoot"):
		if Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
			open_fire()
	_move_wobble()
	survival_time += delta
	update_time_label()
	

func open_fire():
	last_shoot_time = Time.get_unix_time_from_system()
	var arrow = arrow_pool.spawn()
	arrow.global_position = muzzle.global_position
	var mouse_position = get_global_mouse_position()
	var mouse_direction = muzzle.global_position.direction_to(mouse_position)
	arrow.move_direction = mouse_direction
	print("Player: Spawned arrow %s, move_direction=%s, position=%s" % [arrow.name, arrow.move_direction, arrow.global_position])  # Debug

func take_damage(damage: int):
	current_health -= damage
	if current_health <= 0:
		print("Game Over! LOADING, PLEASE WAIT......................")
		Global.current_score = Global.current_score
		call_deferred("_handle_game_over")  # defer to avoid acting in invalid state
	else:
		_damage_flash()
		health_bar.value = current_health
	
		if player_damage_sound: # Check if the sound node exists
			player_damage_sound.play()
		
	
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
	
func _on_regeneration_timer_timeout():
	if is_queued_for_deletion():
		return
	var health_to_add : int = int(regeneration_per_second)
	current_health += health_to_add
	current_health = min(current_health, max_health)
	health_bar.value = current_health
	
func increment_score():
	Global.current_score += 1
	update_score_label()

func update_score_label():
	if score_label:
		score_label.text = "Score: %d" % Global.current_score
	else:
		push_error("Score label not found at /root/main/CanvasLayer/score")

func update_time_label():
	if uptime_label:
		var minutes = int(survival_time / 60)
		var seconds = int(survival_time) % 60
		uptime_label.text = "Time: %02d:%02d" % [minutes, seconds]
	else:
		push_error("Uptime label not found at /root/main/CanvasLayer/uptime")
		
func _handle_game_over():
	var tree = get_tree()
	if not tree:
		push_error("SceneTree is null in _handle_game_over()")
		return
	
	if Global.is_high_score(Global.current_score):
		tree.change_scene_to_file("res://Scenes/game_over.tscn")
	else:
		tree.change_scene_to_file("res://Scenes/game_over2.tscn")
		
# Handle loot pickup when entering pickup area
# Handle loot pickup when entering pickup area
func _on_pickup_area_entered(area: Area2D) -> void:
	if area.is_in_group("loot") and area.name == "coin":
		coin_count += 1
		if coin_label:
			coin_label.text = "Coin: %d" % coin_count
		print("Picked up coin! Coins: %d" % coin_count)
		area.play_pickup_sound()  # Trigger sound from coin
		area.queue_free()
