# troubadour.gd - Troubadour endless-mode character script (playable Annadaeus)
# Movement/input/pickup/death follow the woodstalker.gd player template; the
# actual abilities (auras, Finale, Illusory Double) are Anna's own code from
# annadaeus.gd, just triggered by unlock+cooldown instead of her old AI.
extends CharacterBody2D

signal damage_updated(damage: float)
signal speed_updated(speed: float)
signal health_updated(current: int, max: int)

@export var base_damage: int = 6 # Base damage for Symphony of Fate bolts
@export var max_speed: float = 110.0
@export var max_speed_cap: float = 220.0
@export var acceleration: float = 0.2
@export var braking: float = 0.15
@export var firing_speed: float = 0.5 # Symphony of Fate basic-attack rate
@export var current_health: int = 120
@export var max_health: int = 120
@export var regeneration_per_second: float = 2.0
@export var flip_sprite: bool = false

@export var song_of_courage_rate: float = 15.0
@export var song_of_renewal_rate: float = 10.0
@export var finale_rate: float = 45.0
@export var illusory_double_rate: float = 25.0
@export var illusory_double_hp_threshold: float = 0.3
@export var finale_range: float = 250.0
@export var finale_damage: int = 25

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var pickup_area: Area2D = $pickup_area
@onready var player_damage_sound: AudioStreamPlayer2D = $player_damage_sound
@onready var casting_label: Label = $casting_label
@onready var casting_timer: Timer = $casting_timer
@onready var renewal_aura: Area2D = $renewal_aura
@onready var courage_aura: Area2D = $courage_aura
@onready var renewal_aura_timer: Timer = $renewal_aura_timer
@onready var courage_aura_timer: Timer = $courage_aura_timer
@onready var finale_particles: GPUParticles2D = $finale_particles
@onready var finale_sound: AudioStreamPlayer2D = $finale_sound
@onready var renewal_sparkle: CPUParticles2D = $renewal_aura/sparkle_particles
@onready var courage_sparkle: CPUParticles2D = $courage_aura/sparkle_particles

const _AURA_PULSE_SPEED: float = 4.5
const _AURA_TICK_INTERVAL: float = 2.0

var move_input: Vector2
var damage_modifier: float = 1.0
var last_shoot_time: float
var speed_buff_active: bool = false
var base_max_speed: float = 110.0
var active_effect_timers: Dictionary = {}
var cached_aim_vector: Vector2 = Vector2.ZERO
var is_decoy: bool = false

var casting_lines: Dictionary = {}
var last_shout_time: float = 0.0
var shout_cooldown: float = 30.0

var _aura_sparkle_phase: float = 0.0
var _aura_prev_pulse: float = 0.0
var _aura_tick_timer: float = 0.0

# Endless mode: all locked at start, unlocked in SPELL_PROGRESSION order via ability_chest drops.
var spells_unlocked: Dictionary = {
	"song_of_renewal": false,
	"song_of_courage": false,
	"finale": false,
	"illusory_double": false,
}
var ability_cooldowns: Dictionary = {
	"renewal": 0.0,
	"courage": 0.0,
	"finale": 0.0,
	"double": 0.0,
}
const SPELL_PROGRESSION: Array = [
	"song_of_renewal", "song_of_courage", "finale", "illusory_double",
]

func _ready() -> void:
	collision_mask = 16 + 2048 # Environment (buildings) + Walls
	add_to_group("player")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	if casting_timer:
		casting_timer.wait_time = 2.0
		casting_timer.one_shot = true
		casting_timer.timeout.connect(func(): casting_label.text = "")
	_load_casting_lines()
	_configure_auras()
	var regen_timer := Timer.new()
	regen_timer.wait_time = 1.0
	regen_timer.autostart = true
	regen_timer.timeout.connect(_on_regen_tick)
	add_child(regen_timer)
	emit_signal("damage_updated", base_damage * damage_modifier)
	emit_signal("speed_updated", max_speed)
	emit_signal("health_updated", current_health, max_health)

func _physics_process(_delta: float) -> void:
	if is_decoy:
		return
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	move_and_slide()

func _process(delta: float) -> void:
	if is_decoy:
		return

	var use_touch: bool = OS.has_feature("touchscreen")
	var joystick_connected: bool = Input.get_joy_name(0) != ""
	var aim_active: bool = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down").length() > 0.2
	var shoot_active: bool
	if use_touch and not joystick_connected:
		shoot_active = aim_active
	else:
		shoot_active = (joystick_connected and aim_active) or Input.is_action_pressed("shoot") or Input.get_action_strength("shoot") > 0.1

	if joystick_connected and aim_active:
		cached_aim_vector = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down").normalized()
		sprite.flip_h = (cached_aim_vector.x < 0) != flip_sprite
	elif not use_touch:
		var mouse_position = get_global_mouse_position()
		cached_aim_vector = muzzle.global_position.direction_to(mouse_position)
		sprite.flip_h = (mouse_position.x < global_position.x) != flip_sprite
	else:
		var touch_aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if touch_aim.length() > 0.2:
			cached_aim_vector = touch_aim.normalized()
			sprite.flip_h = (cached_aim_vector.x < 0) != flip_sprite

	if shoot_active and Time.get_unix_time_from_system() - last_shoot_time > firing_speed:
		open_fire()

	_move_wobble()
	_update_aura_sparkles(delta)
	_update_aura_ticks(delta)

	for key in ability_cooldowns:
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] -= delta
	_perform_auto_spells()
	_check_illusory_double()

func _perform_auto_spells() -> void:
	if spells_unlocked.get("song_of_renewal", false) and ability_cooldowns["renewal"] <= 0.0:
		_perform_song_of_renewal()
	if spells_unlocked.get("song_of_courage", false) and ability_cooldowns["courage"] <= 0.0:
		_perform_song_of_courage()
	if spells_unlocked.get("finale", false) and ability_cooldowns["finale"] <= 0.0:
		_perform_finale()

func _check_illusory_double() -> void:
	if not spells_unlocked.get("illusory_double", false):
		return
	if ability_cooldowns["double"] > 0.0:
		return
	if current_health <= max_health * illusory_double_hp_threshold:
		_perform_illusory_double()

func open_fire() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle:
		return
	var projectile = bullet_pool.spawn()
	if not projectile:
		return
	projectile.owner_group = "player"
	var aim_vector: Vector2 = cached_aim_vector
	if aim_vector.is_zero_approx():
		aim_vector = muzzle.global_position.direction_to(get_global_mouse_position())
	var dmg := int(base_damage * damage_modifier)
	if projectile.has_method("set_damage"):
		projectile.set_damage(dmg)
	if projectile.has_method("launch"):
		projectile.launch(muzzle.global_position, aim_vector)
	else:
		projectile.global_position = muzzle.global_position
		projectile.move_direction = aim_vector

# --- Setup ---
func _load_casting_lines() -> void:
	var file = FileAccess.open("res://Data/annadaeus_casting_lines.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			casting_lines = json.get_data()
		file.close()

func _configure_auras() -> void:
	renewal_aura.collision_mask = 1057
	courage_aura.collision_mask = 1057
	renewal_aura.visible = false
	courage_aura.visible = false
	renewal_aura_timer.timeout.connect(func(): renewal_aura.visible = false)
	courage_aura_timer.timeout.connect(func():
		_clear_courage_buffs()
		courage_aura.visible = false
	)
	_setup_aura_sparkles()

func _setup_aura_sparkles() -> void:
	_configure_sparkle(renewal_sparkle, Color(0.3, 0.9, 1.0, 0.9), Color(0.3, 0.9, 1.0, 0.0))
	_configure_sparkle(courage_sparkle, Color(1.0, 0.85, 0.2, 0.9), Color(1.0, 0.85, 0.2, 0.0))

func _configure_sparkle(p: CPUParticles2D, col_start: Color, col_end: Color) -> void:
	p.amount = 10
	p.lifetime = 0.55
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 90.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 6.0
	var grad := Gradient.new()
	grad.set_color(0, col_start)
	grad.set_color(1, col_end)
	p.color_ramp = grad

func _update_aura_ticks(delta: float) -> void:
	if not (renewal_aura.visible or courage_aura.visible):
		return
	_aura_tick_timer += delta
	if _aura_tick_timer >= _AURA_TICK_INTERVAL:
		_aura_tick_timer = 0.0
		if renewal_aura.visible:
			_renewal_heal_tick()
		if courage_aura.visible:
			_courage_buff_tick()

func _renewal_heal_tick() -> void:
	for body in renewal_aura.get_overlapping_bodies():
		if (body.is_in_group("friendly") or body.is_in_group("player") or body.is_in_group("healer")) and body.has_method("heal"):
			body.heal(4)

func _courage_buff_tick() -> void:
	for body in courage_aura.get_overlapping_bodies():
		if (body.is_in_group("friendly") or body.is_in_group("player") or body.is_in_group("healer")) and body.has_method("set_damage_modifier"):
			body.set_damage_modifier(1.5)

func _clear_courage_buffs() -> void:
	for body in courage_aura.get_overlapping_bodies():
		if body.has_method("set_damage_modifier"):
			body.set_damage_modifier(1.0)

func _update_aura_sparkles(delta: float) -> void:
	if not (renewal_aura.visible or courage_aura.visible):
		return
	_aura_sparkle_phase += delta * _AURA_PULSE_SPEED
	var pulse := sin(_aura_sparkle_phase)
	if pulse >= 0.9 and _aura_prev_pulse < 0.9:
		if renewal_aura.visible:
			renewal_sparkle.restart()
		if courage_aura.visible:
			courage_sparkle.restart()
	_aura_prev_pulse = pulse

# --- Abilities ---
func _perform_song_of_courage() -> void:
	_show_casting_text("Song of Courage")
	ability_cooldowns["courage"] = song_of_courage_rate
	_activate_courage_aura()

func _perform_song_of_renewal() -> void:
	_show_casting_text("Song of Renewal")
	ability_cooldowns["renewal"] = song_of_renewal_rate
	_activate_renewal_aura()

func _perform_finale() -> void:
	_show_casting_text("Finale")
	if finale_particles and is_instance_valid(finale_particles):
		finale_particles.emitting = true
	if finale_sound and is_instance_valid(finale_sound):
		finale_sound.play()
	var damage_boost: float = 1.0 + 0.5 * (int(courage_aura.visible) + int(renewal_aura.visible))
	var final_damage: int = int(finale_damage * damage_boost)
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible and mob.has_method("take_damage"):
			if global_position.distance_to(mob.global_position) <= finale_range:
				mob.take_damage(final_damage, null)
	ability_cooldowns["finale"] = finale_rate

func _perform_illusory_double() -> void:
	_show_casting_text("Illusory Double")
	ability_cooldowns["double"] = illusory_double_rate
	_spawn_decoy()
	apply_speed_buff(0.5, 2.0)

func _activate_courage_aura() -> void:
	courage_aura.visible = true
	courage_aura_timer.start()
	_courage_buff_tick()

func _activate_renewal_aura() -> void:
	renewal_aura.visible = true
	renewal_aura_timer.start()
	_renewal_heal_tick()

func _spawn_decoy() -> void:
	var decoy = duplicate()
	decoy.is_decoy = true
	decoy.global_position = global_position
	decoy.current_health = 40
	decoy.max_health = 40
	if decoy.get_node_or_null("health_bar"):
		var decoy_health_bar = decoy.get_node("health_bar")
		decoy_health_bar.max_value = 40
		decoy_health_bar.value = 40
	decoy.set_process(false)
	decoy.set_physics_process(false)
	if decoy.get_node_or_null("CollisionShape2D"):
		decoy.get_node("CollisionShape2D").set_deferred("disabled", false)
	get_tree().current_scene.add_child(decoy)
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(decoy):
			decoy.queue_free()
		timer.queue_free()
	)
	decoy.add_child(timer)
	timer.start()

func _show_casting_text(ability_name: String) -> void:
	if not casting_label or not casting_timer:
		return
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_shout_time < shout_cooldown:
		return
	last_shout_time = current_time
	if casting_lines.has(ability_name):
		var lines = casting_lines[ability_name]
		casting_label.text = lines[randi() % lines.size()]
	else:
		casting_label.text = ability_name
	casting_timer.start()
	var ui = get_node_or_null("/root/UI")
	if ui and ui.has_method("chat_add"):
		ui.chat_add(casting_label.text, "Annadaeus")

# --- Unlocks (ability chest, endless mode) ---
func _unlock_next_spell() -> void:
	for spell in SPELL_PROGRESSION:
		if not spells_unlocked.get(spell, true):
			spells_unlocked[spell] = true
			return

# --- Health / death / pickup (player template) ---
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
		var killer_info := _identify_killer(source)
		Global.killer_name = killer_info["monster"]
		Global.killer_weapon = killer_info["weapon"]
		_handle_game_over()
	else:
		_damage_flash()
		if player_damage_sound:
			player_damage_sound.play()

func _damage_flash() -> void:
	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.05).timeout
		sprite.modulate = Color.WHITE

func _identify_killer(source: Node) -> Dictionary:
	var result := {"monster": "", "weapon": ""}
	if not is_instance_valid(source):
		return result
	var attacker: Node = source
	var maybe_shooter = source.get("shooter")
	if maybe_shooter != null and is_instance_valid(maybe_shooter):
		attacker = maybe_shooter
		if source.scene_file_path != "":
			result["weapon"] = source.scene_file_path.get_file().get_basename()
	var script = attacker.get_script()
	if script:
		result["monster"] = script.resource_path.get_file().get_basename()
	return result

func _handle_game_over() -> void:
	if not Global.game_active:
		return
	Global.game_active = false
	var ui = get_node_or_null("/root/UI")
	if ui:
		ui.visible = false
	if get_tree():
		if Global.is_high_score(Global.current_score):
			get_tree().call_deferred("change_scene_to_file", "res://Scenes/game_over.tscn")
		else:
			get_tree().call_deferred("change_scene_to_file", "res://Scenes/game_over2.tscn")

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.is_in_group("loot"):
		Global.coins_collected += 1
		Global.emit_signal("coins_updated", Global.coins_collected)
		if Global.is_endless_mode:
			Global.add_endless_coins(1)
		area.collect()
	if area.is_in_group("potion"):
		var potion_data = area.get_potion_data()
		if potion_data:
			apply_potion_effect(potion_data.effect_type, potion_data.effect_value, potion_data.effect_duration)
		area.collect()
	if area.is_in_group("ability_chest"):
		_unlock_next_spell()
		area.collect()

func apply_potion_effect(effect_type: String, effect_value: float, effect_duration: float) -> void:
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
		set(property, revert_value)
		if property == "max_speed":
			speed_buff_active = false
			emit_signal("speed_updated", max_speed)
		else:
			emit_signal("damage_updated", base_damage * damage_modifier)
		active_effect_timers.erase(property)
		timer.queue_free()
	)
	add_child(timer)
	active_effect_timers[property] = timer

func apply_speed_buff(bonus_percent: float, duration: float) -> void:
	apply_potion_effect("speed_boost", 1.0 + bonus_percent, duration)

func _move_wobble() -> void:
	if velocity.length_squared() < 25.0:
		sprite.rotation_degrees = 0
		return
	sprite.rotation_degrees = sin(Time.get_ticks_msec() / 100.0) * 2

func _on_regen_tick() -> void:
	if is_decoy or current_health <= 0 or current_health >= max_health:
		return
	heal(int(regeneration_per_second))

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func heal(amount: int) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	emit_signal("health_updated", current_health, max_health)

func set_damage_modifier(modifier: float) -> void:
	damage_modifier = modifier
	emit_signal("damage_updated", base_damage * damage_modifier)
