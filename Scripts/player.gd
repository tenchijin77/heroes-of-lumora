# player.gd - main character script
extends CharacterBody2D

# Signals for UI updates
signal damage_updated(damage: float)
signal speed_updated(speed: float)
signal health_updated(current: int, max: int)

@export var base_damage: int = 4 # Base damage for projectiles
@export var max_speed: float = 100.0
@export var max_speed_cap: float = 200.0 # Cap at 2x base speed
@export var acceleration: float = 0.2
@export var braking: float = 0.15
@export var firing_speed: float = 0.2
@export var current_health: int = 100
@export var max_health: int = 100
@export var regeneration_per_second: float = 2.0 # Health regenerated per second
@export var debug_enabled: bool = false  # NEW: Toggle debug printing

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
var speed_buff_active: bool = false # Prevent stacking speed buffs
var base_max_speed: float = 100.0 # Base speed to avoid floating-point drift
var active_effect_timers: Dictionary = {}  # NEW: Track active effect timers to prevent leaks
var cached_aim_vector: Vector2 = Vector2.ZERO  # NEW: Cache aim vector to avoid recalculation

func _ready() -> void:
	collision_mask = 16 + 2048  # Environment (buildings) + Walls
	# Initialize player properties and connections
	add_to_group("player")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	regeneration_timer.wait_time = 1.0
	regeneration_timer.autostart = true
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	# Emit initial stat values
	emit_signal("damage_updated", base_damage * damage_modifier)
	emit_signal("speed_updated", max_speed)
	emit_signal("health_updated", current_health, max_health)

func _physics_process(_delta: float) -> void:
	# Handle player movement with priority
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	move_and_slide()

func _process(delta: float) -> void:
	# Handle shooting and sprite orientation
	var use_touch: bool = OS.has_feature("touchscreen")
	var joystick_connected: bool = Input.get_joy_name(0) != ""
	var aim_active: bool = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down").length() > 0.2
	var shoot_active: bool
	if use_touch and not joystick_connected:
		shoot_active = aim_active  # on touch, only shoot when the right joystick is pushed
	else:
		shoot_active = (joystick_connected and aim_active) or Input.is_action_pressed("shoot") or Input.get_action_strength("shoot") > 0.1

	if joystick_connected and aim_active:
		# Joystick active for aiming
		cached_aim_vector = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down").normalized()
		sprite.flip_h = cached_aim_vector.x > 0
	elif not use_touch:
		# Keyboard/Mouse fallback
		var mouse_position = get_global_mouse_position()
		cached_aim_vector = muzzle.global_position.direction_to(mouse_position)
		sprite.flip_h = mouse_position.x > global_position.x
	else:
		var touch_aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if touch_aim.length() > 0.2:
			cached_aim_vector = touch_aim.normalized()
			sprite.flip_h = cached_aim_vector.x > 0

	if shoot_active and Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
		open_fire()
	_move_wobble()

func _handle_game_over() -> void:
	if not Global.game_active:
		return  # Victory already claimed this frame (boss died simultaneously)
	Global.game_active = false
	# Explicitly hide UI
	var ui = get_node_or_null("/root/UI")
	if ui:
		ui.visible = false
	else:
		push_error("Player: UI node not found at /root/UI!")
	if get_tree():
		if Global.is_high_score(Global.current_score):
			get_tree().call_deferred("change_scene_to_file", "res://Scenes/game_over.tscn")
		else:
			get_tree().call_deferred("change_scene_to_file", "res://Scenes/game_over2.tscn")
	else:
		push_error("SceneTree is null—cannot change to game over scene!")

func take_damage(damage: int, source: Node) -> void:
	if Global.godmode:
		return
	current_health -= damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	emit_signal("health_updated", current_health, max_health)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(5.0, 0.2)
	if current_health <= 0:
		Global.killer_name = _identify_killer(source)
		_handle_game_over()
	else:
		if player_damage_sound:
			player_damage_sound.play()

func _identify_killer(source: Node) -> String:
	if not is_instance_valid(source):
		return ""
	var attacker: Node = source
	var maybe_shooter = source.get("shooter")
	if maybe_shooter != null and is_instance_valid(maybe_shooter):
		attacker = maybe_shooter
	var script = attacker.get_script()
	if script:
		return script.resource_path.get_file().get_basename()
	return ""

func open_fire() -> void:
	# Fire an arrow projectile
	last_shoot_time = Time.get_unix_time_from_system()
	var arrow = arrow_pool.spawn()
	arrow.global_position = muzzle.global_position
	arrow.owner_group = "player"
	
	# FIXED: Use cached aim_vector instead of recalculating
	var aim_vector: Vector2 = cached_aim_vector
	if aim_vector.is_zero_approx():
		# Fallback if no aim input
		aim_vector = muzzle.global_position.direction_to(get_global_mouse_position())
	
	arrow.move_direction = aim_vector
	if arrow.has_method("set_damage"):
		arrow.set_damage(base_damage * damage_modifier)
	

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
	emit_signal("health_updated", current_health, max_health)

func _on_pickup_area_entered(area: Area2D) -> void:
	# Handle loot pickup when entering pickup area
	if area.is_in_group("loot"):
		Global.coins_collected += 1
		Global.emit_signal("coins_updated", Global.coins_collected)
		area.collect()
	# Handle potion pickup
	if area.is_in_group("potion"):
		var potion_data = area.get_potion_data() # Assume potion.gd has this
		if potion_data:
			apply_potion_effect(potion_data.effect_type, potion_data.effect_value, potion_data.effect_duration)
		area.collect()

func apply_potion_effect(effect_type: String, effect_value: float, effect_duration: float) -> void:
	# Apply potion effect to player
	match effect_type:
		"heal":
			heal(int(effect_value))
		"speed_boost":
			if not speed_buff_active:
				speed_buff_active = true
				max_speed = min(max_speed * effect_value, max_speed_cap)
				_start_effect_timer(effect_duration, "max_speed", base_max_speed)
				emit_signal("speed_updated", max_speed)
		"damage_boost":
			damage_modifier = effect_value
			_start_effect_timer(effect_duration, "damage_modifier", 1.0)
			emit_signal("damage_updated", base_damage * damage_modifier)

func _start_effect_timer(duration: float, property: String, revert_value: float) -> void:
	# FIXED: Helper to revert temporary effects - now prevents timer leaks
	
	# Cancel existing timer for this property to prevent stacking/leaks
	if property in active_effect_timers:
		var old_timer = active_effect_timers[property]
		if is_instance_valid(old_timer):
			old_timer.stop()
			old_timer.queue_free()
		active_effect_timers.erase(property)
	
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func():
		var new_value: float = revert_value
		set(property, new_value)
		if property == "max_speed":
			speed_buff_active = false
			emit_signal("speed_updated", max_speed)
		else:
			emit_signal("damage_updated", base_damage * damage_modifier)
		
		# Clean up timer reference
		active_effect_timers.erase(property)
		timer.queue_free()
	)
	add_child(timer)
	active_effect_timers[property] = timer
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
	emit_signal("health_updated", current_health, max_health)

func set_damage_modifier(modifier: float) -> void:
	# Set damage modifier for courage aura
	damage_modifier = modifier
	emit_signal("damage_updated", base_damage * damage_modifier)

func apply_speed_buff(bonus_percent: float, duration: float) -> void:
	apply_potion_effect("speed_boost", 1.0 + bonus_percent, duration)
