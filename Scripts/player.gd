# player.gd - main character script
extends CharacterBody2D

@export var player_damage: int = 4
@export var max_speed: float = 100.0
@export var acceleration: float = 0.2
@export var braking: float = 0.15
@export var firing_speed: float = 0.2
@export var current_health: int = 100
@export var max_health: int = 100
@export var regeneration_per_second: float = 1.0  # Health regenerated per second
var last_shoot_time: float

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle = $muzzle
@onready var arrow_pool = $player_bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var regeneration_timer: Timer = $regeneration_timer
@onready var player_damage_sound: AudioStreamPlayer2D = $player_damage_sound
@onready var pickup_area: Area2D = $pickup_area  # New reference to pickup area

var move_input: Vector2

# Initialize player properties and connections
func _ready() -> void:
	add_to_group("player")
	health_bar.max_value = max_health
	health_bar.value = current_health
	regeneration_timer.wait_time = 1.0
	regeneration_timer.autostart = true
	pickup_area.area_entered.connect(_on_pickup_area_entered)

# Handle player movement
func _physics_process(_delta: float) -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	move_and_slide()

# Handle shooting and sprite orientation
func _process(delta: float) -> void:
	sprite.flip_h = get_global_mouse_position().x > global_position.x
	if Input.is_action_pressed("shoot"):
		if Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
			open_fire()
	_move_wobble()

# Fire an arrow projectile
func open_fire() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	var arrow = arrow_pool.spawn()
	arrow.global_position = muzzle.global_position
	arrow.owner_group = "player"  # Set owner_group on the projectile
	var mouse_position = get_global_mouse_position()
	var mouse_direction = muzzle.global_position.direction_to(mouse_position)
	arrow.move_direction = mouse_direction
	print("Player: Spawned arrow %s, move_direction=%s, position=%s" % [arrow.name, arrow.move_direction, arrow.global_position])  # Debug log

# Apply damage to player
func take_damage(damage: int) -> void:
	current_health -= damage
	if current_health <= 0:
		_handle_game_over()
	else:
		if player_damage_sound:
			player_damage_sound.play()
	health_bar.value = current_health

# Handle sprite wobble animation
func _move_wobble() -> void:
	var rot: float = sin(Time.get_ticks_msec() / 100.0) * 2
	sprite.rotation_degrees = rot

# Regenerate health periodically
func _on_regeneration_timer_timeout() -> void:
	if is_queued_for_deletion():
		return
	var health_to_add: int = int(regeneration_per_second)
	current_health += health_to_add
	current_health = min(current_health, max_health)
	health_bar.value = current_health

# Increment score via global
func increment_score() -> void:
	Global.increment_score()  # Call Global to handle increment and signal

# Handle loot pickup when entering pickup area
func _on_pickup_area_entered(area: Area2D) -> void:
	if area.is_in_group("loot"):
		Global.increment_coins()  # Call Global to handle increment and signal
		print("Picked up coin! Coins: %d" % Global.coins_collected)  # Debug log
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

# Get current health
func get_health() -> int:
	return current_health

# Get max health
func get_max_health() -> int:
	return max_health

# Heal player
func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	health_bar.value = current_health
	print("Player healed for %d. Current health: %d" % [amount, current_health])

# Handle game over logic when player's health hits zero
func _handle_game_over() -> void:
	Global.game_active = false  # Halt time updates
	print("Game Over! Final Score: %d | Wave: %d | Coins: %d | Time: %s | Saved: %d | Lost: %d" % [
		Global.current_score, Global.current_wave, Global.coins_collected, Global.format_time(Global.current_time_survived),
		Global.saved_villagers, Global.lost_villagers])  # Debug final state
	if get_tree():
		if Global.is_high_score(Global.current_score):
			get_tree().change_scene_to_file("res://Scenes/game_over.tscn")
		else:
			get_tree().change_scene_to_file("res://Scenes/game_over2.tscn")
	else:
		push_error("SceneTree is null—cannot change to game over scene!")
