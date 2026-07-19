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
@export var flip_sprite: bool = false  # Invert all flip logic if sprite faces left by default

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

# Woodstalker spell system
# Story campaign: all pre-unlocked. Endless mode: use ability_chest drops to unlock in order.
var spells_unlocked: Dictionary = {
	"hunters_mark": true,
	"call_pet": true,
	"ensnaring_trap": true,
	"barrage": true,
	"poisoned_shot": true,
	"improved_barrage": true,
}
var spell_cooldowns: Dictionary = {
	"hunters_mark": 4.0,
	"ensnaring_trap": 5.0,
	"barrage": 6.0,
}
var pet_stage: int = 0
var pet_node: Node = null
var crit_chance: float = 0.0

const SPELL_PROGRESSION: Array = [
	"hunters_mark", "call_pet", "ensnaring_trap", "barrage",
	"upgrade_to_bear", "poisoned_shot", "upgrade_to_panther", "improved_barrage",
]

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
	# Spawn Wolf companion (story mode: always present from the start)
	call_deferred("_spawn_pet", 1)

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
	# Woodstalker auto-cast spells
	for key in spell_cooldowns:
		if spell_cooldowns[key] > 0.0:
			spell_cooldowns[key] -= delta
	_perform_auto_spells()

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
		var killer_info := _identify_killer(source)
		Global.killer_name = killer_info["monster"]
		Global.killer_weapon = killer_info["weapon"]
		_handle_game_over()
	else:
		if player_damage_sound:
			player_damage_sound.play()

func _identify_killer(source: Node) -> Dictionary:
	var result := {"monster": "", "weapon": ""}
	if not is_instance_valid(source):
		return result
	var attacker: Node = source
	var maybe_shooter = source.get("shooter")
	if maybe_shooter != null and is_instance_valid(maybe_shooter):
		# Killed by a projectile — attribute to the monster that fired it,
		# and name the projectile itself as the weapon (e.g. "fireball").
		attacker = maybe_shooter
		if source.scene_file_path != "":
			result["weapon"] = source.scene_file_path.get_file().get_basename()
	var script = attacker.get_script()
	if script:
		result["monster"] = script.resource_path.get_file().get_basename()
	return result

func open_fire() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	var arrow = arrow_pool.spawn()
	arrow.global_position = muzzle.global_position
	arrow.owner_group = "player"

	var aim_vector: Vector2 = cached_aim_vector
	if aim_vector.is_zero_approx():
		aim_vector = muzzle.global_position.direction_to(get_global_mouse_position())
	arrow.move_direction = aim_vector

	var dmg := int(base_damage * damage_modifier)
	if crit_chance > 0.0 and randf() < crit_chance:
		dmg = int(dmg * 2.0)
	if arrow.has_method("set_damage"):
		arrow.set_damage(dmg)

	# Poisoned Shot passive — each arrow applies 3 DPS for 5s
	if spells_unlocked.get("poisoned_shot", false):
		arrow.apply_dot_on_hit = true
		arrow.dot_damage_per_tick = 3
		arrow.dot_ticks = 5

func _move_wobble() -> void:
	if velocity.length_squared() < 25.0:
		sprite.rotation_degrees = 0
		return
	sprite.rotation_degrees = sin(Time.get_ticks_msec() / 100.0) * 2

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
	# Ability chest (endless mode): unlock next Woodstalker spell
	if area.is_in_group("ability_chest"):
		_unlock_next_spell()
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

# --- Woodstalker Spells ---

func _perform_auto_spells() -> void:
	if spells_unlocked.get("hunters_mark", false) and spell_cooldowns["hunters_mark"] <= 0.0:
		_cast_hunters_mark()
	if spells_unlocked.get("ensnaring_trap", false) and spell_cooldowns["ensnaring_trap"] <= 0.0:
		_cast_ensnaring_trap()
	if spells_unlocked.get("barrage", false) and spell_cooldowns["barrage"] <= 0.0:
		_cast_barrage()

func _cast_hunters_mark() -> void:
	var target := _find_nearest_enemy()
	if not target:
		return
	spell_cooldowns["hunters_mark"] = 4.0
	if target.has_method("apply_mark"):
		target.apply_mark(8.0)
	_spawn_mark_vfx(target.global_position)

func _cast_ensnaring_trap() -> void:
	var target := _find_nearest_enemy()
	if not target:
		return
	spell_cooldowns["ensnaring_trap"] = 5.0
	if target.has_method("apply_root"):
		target.apply_root(2.0)
	_spawn_trap_vfx(target.global_position)

func _cast_barrage() -> void:
	var target := _find_nearest_enemy()
	if not target:
		return
	if global_position.distance_to(target.global_position) > 350.0:
		return
	spell_cooldowns["barrage"] = 6.0
	var arrow_count := 5 if spells_unlocked.get("improved_barrage", false) else 3
	var aim := cached_aim_vector
	if aim.is_zero_approx():
		aim = muzzle.global_position.direction_to(get_global_mouse_position())
	var arrow_spacing := deg_to_rad(5.0)  # angle between adjacent arrows
	for i in arrow_count:
		var offset_index := float(i) - float(arrow_count - 1) / 2.0
		var dir := aim.rotated(offset_index * arrow_spacing).normalized()
		var arrow = arrow_pool.spawn()
		if not arrow:
			continue
		arrow.global_position = muzzle.global_position
		arrow.owner_group = "player"
		arrow.move_direction = dir
		if arrow.has_method("set_damage"):
			arrow.set_damage(int(base_damage * damage_modifier))
		if spells_unlocked.get("poisoned_shot", false):
			arrow.apply_dot_on_hit = true
			arrow.dot_damage_per_tick = 3
			arrow.dot_ticks = 5

func _find_nearest_enemy() -> Node:
	var nearest: Node = null
	var min_dist: float = INF
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible:
			var d := global_position.distance_to(mob.global_position)
			if d < min_dist:
				min_dist = d
				nearest = mob
	return nearest

func _spawn_pet(stage: int) -> void:
	if pet_node and is_instance_valid(pet_node):
		pet_node.queue_free()
	var pet := CharacterBody2D.new()
	pet.set_script(load("res://Scripts/pet.gd"))
	pet.global_position = global_position + Vector2(40, 0)
	get_tree().current_scene.add_child(pet)
	pet.init(self, stage, max_health)
	pet_node = pet
	pet_stage = stage

func _upgrade_pet(new_stage: int) -> void:
	if pet_node and is_instance_valid(pet_node):
		pet_node.upgrade(new_stage, max_health)
		pet_stage = new_stage
	else:
		_spawn_pet(new_stage)
	if new_stage == 3:
		crit_chance = 0.1  # Panther: +10% crit chance

func _unlock_next_spell() -> void:
	for spell in SPELL_PROGRESSION:
		if spell in spells_unlocked:
			if not spells_unlocked[spell]:
				_unlock_spell(spell)
				return
		else:
			_unlock_spell(spell)
			return

func _unlock_spell(spell: String) -> void:
	match spell:
		"call_pet":
			spells_unlocked["call_pet"] = true
			_spawn_pet(1)
		"upgrade_to_bear":
			_upgrade_pet(2)
		"upgrade_to_panther":
			_upgrade_pet(3)
		_:
			spells_unlocked[spell] = true

func _spawn_mark_vfx(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 20
	p.lifetime = 0.8
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1.0, 0.65, 0.0, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_trap_vfx(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.2, 0.85, 0.3, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)
