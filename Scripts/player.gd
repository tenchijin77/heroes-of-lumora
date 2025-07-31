# player.gd - main character script

extends CharacterBody2D

@export var player_damage: int = 4
@export var max_speed: float = 100.0
@export var acceleration: float = .2
@export var braking: float = .15
@export var firing_speed: float = .2
@export var current_health: int = 100
@export var max_health: int = 100
@export var regeneration_per_second: float = 1.0  # Health regenerated per second

var last_shoot_time: float
var survival_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle = $muzzle
@onready var arrow_pool = $player_bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var regeneration_timer: Timer = $regeneration_timer
@onready var score_label: Label = get_node("/root/main/CanvasLayer/VBoxContainer/score")
@onready var uptime_label: Label = get_node("/root/main/CanvasLayer/VBoxContainer/uptime")
@onready var wave_label: Label = get_node("/root/main/CanvasLayer/VBoxContainer/wave")
@onready var coin_label: Label = get_node("/root/main/CanvasLayer/VBoxContainer/coins")
@onready var player_damage_sound: AudioStreamPlayer2D = $player_damage_sound
@onready var pickup_area: Area2D = $pickup_area  # New reference to pickup area

var move_input: Vector2
var coin_count: int = 0

func _ready() -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	regeneration_timer.wait_time = 1.0
	regeneration_timer.autostart = true
	health_bar.max_value = max_health
	health_bar.value = current_health
	update_score_label()
	update_time_label()
	Global.current_score = 0
	pickup_area.area_entered.connect(_on_pickup_area_entered)

func _physics_process(_delta) -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	move_and_slide()

func _process(delta: float) -> void:
	sprite.flip_h = get_global_mouse_position().x > global_position.x
	if Input.is_action_pressed("shoot"):
		if Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
			open_fire()
	_move_wobble()
	survival_time += delta
	update_time_label()

func open_fire() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	var arrow = arrow_pool.spawn()
	arrow.global_position = muzzle.global_position
	var mouse_position = get_global_mouse_position()
	var mouse_direction = muzzle.global_position.direction_to(mouse_position)
	arrow.move_direction = mouse_direction
	print("Player: Spawned arrow %s, move_direction=%s, position=%s" % [arrow.name, arrow.move_direction, arrow.global_position])  # Debug

func take_damage(damage: int) -> void:
	current_health -= damage
	if current_health <= 0:
		print("Game Over! LOADING, PLEASE WAIT......................")
		Global.current_score = Global.current_score
		call_deferred("_handle_game_over")  # defer to avoid acting in invalid state
	else:
		_damage_flash()
		health_bar.value = current_health
		if player_damage_sound:
			player_damage_sound.play()

func _damage_flash() -> void:
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color.WHITE

func _move_wobble() -> void:
	if move_input.length() == 0:
		sprite.rotation_degrees = 0
		return
	var t = Time.get_unix_time_from_system()
	var rot = sin(t * 20) * 2
	sprite.rotation_degrees = rot

func _on_regeneration_timer_timeout() -> void:
	if is_queued_for_deletion():
		return
	var health_to_add: int = int(regeneration_per_second)
	current_health += health_to_add
	current_health = min(current_health, max_health)
	health_bar.value = current_health

func increment_score() -> void:
	Global.current_score += 1
	update_score_label()

func update_score_label() -> void:
	if score_label:
		score_label.text = "Score: %d" % Global.current_score
	else:
		push_error("Score label not found at /root/main/CanvasLayer/score")

func update_time_label() -> void:
	if uptime_label:
		var minutes = int(survival_time / 60)
		var seconds = int(survival_time) % 60
		uptime_label.text = "Time: %02d:%02d" % [minutes, seconds]
	else:
		push_error("Uptime label not found at /root/main/CanvasLayer/uptime")

func _handle_game_over() -> void:
	var tree = get_tree()
	if not tree:
		push_error("SceneTree is null in _handle_game_over()")
		return
	if Global.is_high_score(Global.current_score):
		tree.change_scene_to_file("res://Scenes/game_over.tscn")
	else:
		tree.change_scene_to_file("res://Scenes/game_over2.tscn")

# Handle loot pickup when entering pickup area
func _on_pickup_area_entered(area: Area2D) -> void:
	if area.is_in_group("loot"):
		coin_count += 1
		if coin_label:
			coin_label.text = "Coin: %d" % coin_count
		print("Picked up coin! Coins: %d" % coin_count)
		area.collect()  # Let coin handle sound and cleanup

# Apply potion effect to player
func apply_potion_effect(effect_type: String, effect_value: float, effect_duration: float) -> void:
	match effect_type:
		"heal":
			current_health = min(current_health + int(effect_value), max_health)
			health_bar.value = current_health  # Update UI for heal effect
		"speed_boost":
			max_speed *= effect_value
			_start_effect_timer(effect_duration, "max_speed", 1.0 / effect_value)
		"damage_boost":
			player_damage *= effect_value
			_start_effect_timer(effect_duration, "player_damage", 1.0 / effect_value)

# Helper to revert temporary effects
func _start_effect_timer(duration: float, property: String, revert_multiplier: float) -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func():
		set(property, get(property) * revert_multiplier)
		timer.queue_free()
	)
	add_child(timer)
	timer.start()
