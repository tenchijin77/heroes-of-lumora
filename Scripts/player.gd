#player.gd - main character script
extends CharacterBody2D

@export var max_speed : float = 100.0
@export var acceleration : float = 0.2
@export var braking : float = 0.15
@export var firing_speed : float = 0.4
@export var current_health : int = 100
@export var max_health : int = 100
var last_shoot_time : float = -1.0
var score : int = 0
var survival_time : float = 0.0

@onready var sprite : Sprite2D = $Sprite2D
@onready var muzzle = $muzzle
@onready var arrow_pool = $player_bullet_pool
@onready var health_bar : ProgressBar = $health_bar
@onready var score_label : Label = get_node("/root/main/CanvasLayer/score")
@onready var uptime_label : Label = get_node("/root/main/CanvasLayer/uptime")
@onready var hit_sound : AudioStreamPlayer2D = $hit_sound

var move_input : Vector2

func _ready():
	if not is_inside_tree():
		await tree_entered
	health_bar.max_value = max_health
	health_bar.value = current_health
	update_score_label()
	update_time_label()
	if not arrow_pool:
		push_error("Player: arrow_pool is null!")
	else:
		for node in arrow_pool.cached_nodes:
			if node and node.has_method("reset"):
				node.call_deferred("reset")
	if not hit_sound:
		push_error("Player: hit_sound is null!")

func _physics_process(delta):
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	
	move_and_slide()

func _process(delta):
	sprite.flip_h = get_global_mouse_position().x > global_position.x
	
	if Input.is_action_pressed("shoot"):
		if last_shoot_time < 0 or Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
			open_fire()
	
	_move_wobble()
	
	survival_time += delta
	update_time_label()

func open_fire():
	last_shoot_time = Time.get_unix_time_from_system()
	var available_nodes = arrow_pool.cached_nodes.filter(func(n): return n and n.visible == false)
	var arrow = arrow_pool.spawn()
	if not arrow:
		push_error("Player: Failed to spawn arrow from pool!")
		return
	arrow.global_position = muzzle.global_position
	var mouse_position = get_global_mouse_position()
	var mouse_direction = muzzle.global_position.direction_to(mouse_position)
	if mouse_direction.length() > 0:
		arrow.move_dir = mouse_direction
		arrow.visible = true
	else:
		arrow.despawn()

func take_damage(damage : int):
	current_health -= damage
	if hit_sound and not hit_sound.playing:
		hit_sound.play()
		print("Player: Hit sound played, damage: %d" % damage)
	if current_health <= 0:
		if Global.is_high_score(score):
			get_tree().change_scene_to_file("res://Scenes/game_over.tscn")
		else:
			get_tree().change_scene_to_file("res://Scenes/main.tscn")
	else:
		_damage_flash()
		health_bar.value = current_health

func _damage_flash():
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE

func _move_wobble():
	if move_input.length() == 0:
		sprite.rotation_degrees = 0
		return
	var t = Time.get_unix_time_from_system()
	var rot = sin(t * 20) * 2
	sprite.rotation_degrees = rot

func increment_score():
	score += 1
	update_score_label()

func update_score_label():
	if score_label:
		score_label.text = "Score: %d" % score
	else:
		push_error("Score label not found at /root/main/CanvasLayer/score")

func update_time_label():
	if uptime_label:
		var minutes = int(survival_time / 60)
		var seconds = int(survival_time) % 60
		uptime_label.text = "Time: %02d:%02d" % [minutes, seconds]
	else:
		push_error("Uptime label not found at /root/main/CanvasLayer/uptime")
