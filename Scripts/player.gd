# player.gd - main character script
extends CharacterBody2D

@export var base_damage: int = 4 # Base damage for projectiles
@export var max_speed: float = 100.0
@export var acceleration: float = 0.2
@export var braking: float = 0.15
@export var firing_speed: float = 0.2
@export var current_health: int = 100
@export var max_health: int = 100
@export var regeneration_per_second: float = 1.0 # Health regenerated per second

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle = $muzzle
@onready var arrow_pool = $player_bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var regeneration_timer: Timer = $regeneration_timer
@onready var player_damage_sound: AudioStreamPlayer2D = $player_damage_sound
@onready var pickup_area: Area2D = $pickup_area

var move_input: Vector2
var damage_modifier: float = 1.0 # Multiplier for damage buffs
var last_shoot_time: float

func _ready() -> void:
	# Initialize player properties and connections
	add_to_group("player")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	regeneration_timer.wait_time = 1.0
	regeneration_timer.autostart = true
	pickup_area.area_entered.connect(_on_pickup_area_entered)

func _physics_process(_delta: float) -> void:
	# Handle player movement
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	move_and_slide()

func _process(delta: float) -> void:
	# Handle shooting and sprite orientation
	sprite.flip_h = get_global_mouse_position().x > global_position.x
	if Input.is_action_pressed("shoot"):
		if Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
			open_fire()
	_move_wobble()

func _handle_game_over() -> void:
	# Handle game over logic when player's health hits zero
	Global.game_active = false
	print("Game Over! Final Score: %d | Wave: %d | Coins: %d | Time: %s | Saved: %d | Lost: %d" % [
		Global.current_score, Global.current_wave, Global.coins_collected, Global.format_time(Global.current_time_survived),
		Global.saved_villagers, Global.lost_villagers])
	if get_tree():
		if Global.is_high_score(Global.current_score):
			get_tree().change_scene_to_file("res://Scenes/game_over.tscn")
		else:
			get_tree().change_scene_to_file("res://Scenes/game_over2.tscn")
	else:
		push_error("SceneTree is null—cannot change to game over scene!")

func take_damage(damage: int, _projectile_instance) -> void:
	# Apply damage to player
	current_health -= damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	if current_health <= 0:
		_handle_game_over()
	else:
		if player_damage_sound:
			player_damage_sound.play()

func open_fire() -> void:
	# Fire an arrow projectile
	last_shoot_time = Time.get_unix_time_from_system()
	var arrow = arrow_pool.spawn()
	arrow.global_position = muzzle.global_position
	arrow.owner_group = "player"
	var mouse_position = get_global_mouse_position()
	var mouse_direction = muzzle.global_position.direction_to(mouse_position)
	arrow.move_direction = mouse_direction
	if arrow.has_method("set_damage"):
		arrow.set_damage(base_damage * damage_modifier)
	print("Player: Spawned arrow %s, move_direction=%s, position=%s" % [arrow.name, arrow.move_direction, arrow.global_position])

func _move_wobble() -> void:
	# Handle sprite wobble animation
	var rot: float = sin(Time.get_ticks_msec() / 100.0) * 2
	sprite.rotation_degrees = rot

func _on_regeneration_timer_timeout() -> void:
	# Regenerate health periodically
	if is_queued_for_deletion():
		return
	var health_to_add: int = int(regeneration_per_second)
	current_health += health_to_add
	current_health = clamp(current_health, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health

func _on_pickup_area_entered(area: Area2D) -> void:
	# Handle loot pickup when entering pickup area
	if area.is_in_group("loot"):
		Global.coins_collected += 1
		Global.emit_signal("coins_updated", Global.coins_collected)
		print("Picked up coin! Coins: %d" % Global.coins_collected)
		area.collect()

func apply_potion_effect(effect_type: String, effect_value: float, effect_duration: float) -> void:
	# Apply potion effect to player
	match effect_type:
		"heal":
			heal(int(effect_value))
		"speed_boost":
			max_speed *= effect_value
			_start_effect_timer(effect_duration, "max_speed", 1.0 / effect_value)
		"damage_boost":
			damage_modifier *= effect_value
			_start_effect_timer(effect_duration, "damage_modifier", 1.0 / effect_value)

func _start_effect_timer(duration: float, property: String, revert_multiplier: float) -> void:
	# Helper to revert temporary effects
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func():
		set(property, get(property) * revert_multiplier)
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

func get_health() -> int:
	# Return current health
	return current_health

func get_max_health() -> int:
	# Return maximum health
	return max_health

func heal(amount: int) -> void:
	# Heal player and update health bar
	current_health = clamp(current_health + amount, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	print("Player %s healed for %d → current_health = %d" % [name, amount, current_health])

func set_damage_modifier(modifier: float) -> void:
	# Set damage multiplier for courage aura
	damage_modifier = modifier
