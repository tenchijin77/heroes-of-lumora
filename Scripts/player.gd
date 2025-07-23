#player.gd - main character script
extends CharacterBody2D

@export var max_speed : float = 100.0
@export var acceleration : float = 0.2
@export var braking : float = 0.15
@export var firing_speed : float = 0.4
@export var current_health : int = 100
@export var max_health : int = 100
@export var regeneration_per_second : float = 1.0  # Health regenerated per second

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
@onready var regeneration_timer : Timer = $regeneration_timer

var move_input : Vector2

func _ready():
	if not is_inside_tree():
		await tree_entered
	if not health_bar:
		push_error("Player: health_bar is null!")
	if not arrow_pool:
		push_error("Player: arrow_pool is null!")
	if not hit_sound:
		push_error("Player: hit_sound is null!")
	if not regeneration_timer:
		push_error("Player: regeneration_timer is null!")
	else:
		regeneration_timer.wait_time = 1.0
		regeneration_timer.autostart = true
	health_bar.max_value = max_health
	health_bar.value = current_health
	update_score_label()
	update_time_label()
	for node in arrow_pool.cached_nodes:
		if node and node.has_method("reset"):
			node.call_deferred("reset")
	Global.current_score = 0

func _physics_process(_delta):
	if is_queued_for_deletion():
		return
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
		# velocity *= delta  # Make frame-rate independent # added to address delta not used error msg

	move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		if body and body.is_in_group("environment"):
			velocity = velocity.slide(collision.get_normal())

func _process(delta):
	if is_queued_for_deletion():
		return
	sprite.flip_h = get_global_mouse_position().x > global_position.x
	
	if Input.is_action_pressed("shoot"):
		if last_shoot_time < 0 or Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
			open_fire()
	
	_move_wobble()
	
	survival_time += delta
	update_time_label()

func open_fire():
	if is_queued_for_deletion() or not arrow_pool or not muzzle:
		push_error("Player: arrow_pool or muzzle is null!")
		return
	last_shoot_time = Time.get_unix_time_from_system()
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
	if is_queued_for_deletion():
		return
	current_health -= damage
	if hit_sound and not hit_sound.playing:
		hit_sound.play()
	if current_health <= 0:
		set_process(false)
		set_physics_process(false)
		for mob in get_tree().get_nodes_in_group("monsters"):
			if mob.has_method("set_process"):
				mob.set_process(false)
				mob.set_physics_process(false)
		get_tree().call_group("monsters", "queue_free")
		Global.current_score = score
		if Global.is_high_score(score):
			get_tree().change_scene_to_file("res://Scenes/game_over.tscn")
		else:
			get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	else:
		_damage_flash()
		health_bar.value = current_health

func _on_regeneration_timer_timeout():
	if is_queued_for_deletion():
		return
	var health_to_add : int = int(regeneration_per_second)
	current_health += health_to_add
	current_health = min(current_health, max_health)
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
