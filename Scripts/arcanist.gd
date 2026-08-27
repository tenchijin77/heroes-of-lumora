# arcanist.gd - Arcanist endless-mode character script (playable Tenchijin)
# Movement/input/pickup/death follow the woodstalker.gd player template; the
# actual spells (Frost Nova, Meteor, Disintegrate, Time Warp) are Tenchijin's
# own code from tenchijin.gd, just triggered by unlock+cooldown instead of
# his old AI positioning/targeting state machine.
extends CharacterBody2D

signal damage_updated(damage: float)
signal speed_updated(speed: float)
signal health_updated(current: int, max: int)

@export var base_damage: int = 8 # unused directly — Frost Bolt uses frost_bolt_damage
@export var max_speed: float = 95.0
@export var max_speed_cap: float = 190.0
@export var acceleration: float = 0.2
@export var braking: float = 0.15
@export var firing_speed: float = 0.8 # Frost Bolt basic-attack rate
@export var current_health: int = 100
@export var max_health: int = 100
@export var regeneration_per_second: float = 2.0
@export var flip_sprite: bool = false

@export var frost_bolt_damage: int = 60
@export var frost_bolt_slow: float = 0.15
@export var frost_bolt_slow_duration: float = 6.0
@export var frost_nova_rate: float = 20.0
@export var frost_nova_range: float = 333.0
@export var frost_nova_root_duration: float = 4.0
@export var meteor_rate: float = 60.0
@export var meteor_damage: int = 200
@export var meteor_dot_per_sec: int = 15
@export var meteor_dot_ticks: int = 6
@export var meteor_range: float = 333.0
@export var disintegrate_rate: float = 20.0
@export var disintegrate_damage: int = 200
@export var time_warp_rate: float = 45.0
@export var time_warp_speed_bonus: float = 0.1
@export var time_warp_duration: float = 8.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var pickup_area: Area2D = $pickup_area
@onready var player_damage_sound: AudioStreamPlayer2D = $player_damage_sound
@onready var casting_label: Label = $casting_label
@onready var casting_timer: Timer = $casting_timer

const CASTING_LINES: Dictionary = {
	"frost_nova": [
		"Freeze in place—Frost Nova!",
		"The cold claims all who stand before me!",
		"Be bound by ice!",
		"Glacial chains hold fast!",
	],
	"meteor": [
		"Behold the fury of the heavens!",
		"I call down the stars themselves—Meteor!",
		"The cosmos answers my call!",
	],
	"disintegrate": [
		"Your very essence unravels!",
		"Dissolution is your fate—Disintegrate!",
		"I unmake you!",
	],
	"time_warp": [
		"The weave of time bends to my will!",
		"Haste—Time Warp!",
		"I bend the flow of time itself!",
	],
}

var move_input: Vector2
var damage_modifier: float = 1.0
var last_shoot_time: float
var speed_buff_active: bool = false
var base_max_speed: float = 95.0
var active_effect_timers: Dictionary = {}
var cached_aim_vector: Vector2 = Vector2.ZERO
var is_decoy: bool = false # kept for parity with other classes; Arcanist has no decoy ability

var ability_cooldowns: Dictionary = {
	"frost_nova": 0.0,
	"meteor": 0.0,
	"disintegrate": 0.0,
	"time_warp": 0.0,
}

# Endless mode: all locked at start, unlocked in SPELL_PROGRESSION order via ability_chest drops.
var spells_unlocked: Dictionary = {
	"frost_nova": false,
	"time_warp": false,
	"disintegrate": false,
	"meteor": false,
}
const SPELL_PROGRESSION: Array = [
	"frost_nova", "time_warp", "disintegrate", "meteor",
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
	var regen_timer := Timer.new()
	regen_timer.wait_time = 1.0
	regen_timer.autostart = true
	regen_timer.timeout.connect(_on_regen_tick)
	add_child(regen_timer)
	emit_signal("damage_updated", frost_bolt_damage)
	emit_signal("speed_updated", max_speed)
	emit_signal("health_updated", current_health, max_health)

func _physics_process(_delta: float) -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0:
		velocity = velocity.lerp(move_input * max_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, braking)
	move_and_slide()

func _process(delta: float) -> void:
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

	for key in ability_cooldowns:
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] -= delta
	_perform_auto_spells()

func open_fire() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle:
		return
	var projectile = bullet_pool.spawn()
	if not projectile:
		return
	projectile.owner_group = "player"
	projectile.damage = int(frost_bolt_damage * damage_modifier)
	projectile.slow_percent = frost_bolt_slow
	projectile.slow_duration = frost_bolt_slow_duration
	projectile.modulate = Color(0.5, 0.85, 1.0, 1.0)
	var aim_vector: Vector2 = cached_aim_vector
	if aim_vector.is_zero_approx():
		aim_vector = muzzle.global_position.direction_to(get_global_mouse_position())
	if projectile.has_method("launch"):
		projectile.launch(muzzle.global_position, aim_vector)
	else:
		projectile.global_position = muzzle.global_position
		projectile.move_direction = aim_vector

func _perform_auto_spells() -> void:
	if spells_unlocked.get("time_warp", false) and ability_cooldowns["time_warp"] <= 0.0:
		_cast_time_warp()
	if spells_unlocked.get("meteor", false) and ability_cooldowns["meteor"] <= 0.0:
		_cast_meteor()
	if spells_unlocked.get("frost_nova", false) and ability_cooldowns["frost_nova"] <= 0.0:
		_cast_frost_nova()
	if spells_unlocked.get("disintegrate", false) and ability_cooldowns["disintegrate"] <= 0.0:
		_cast_disintegrate()

# --- Spells (ported from tenchijin.gd, target = nearest visible monster where needed) ---
func _cast_frost_nova() -> void:
	ability_cooldowns["frost_nova"] = frost_nova_rate
	_show_casting_text("frost_nova")
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible and global_position.distance_to(mob.global_position) <= frost_nova_range:
			if mob.has_method("apply_root"):
				mob.apply_root(frost_nova_root_duration)
	_spawn_nova_vfx()

func _cast_meteor() -> void:
	var target := _find_closest_mob_globally()
	if not target:
		return
	ability_cooldowns["meteor"] = meteor_rate
	_show_casting_text("meteor")
	var target_pos := target.global_position
	_spawn_meteor_windup_vfx(target_pos)
	get_tree().create_timer(0.8).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_meteor_impact(target_pos)
	)

func _meteor_impact(impact_pos: Vector2) -> void:
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible and impact_pos.distance_to(mob.global_position) <= meteor_range:
			if mob.has_method("take_damage"):
				mob.take_damage(meteor_damage, null)
			if mob.has_method("apply_dot"):
				mob.apply_dot(meteor_dot_per_sec, meteor_dot_ticks)
	_spawn_meteor_impact_vfx(impact_pos)

func _cast_disintegrate() -> void:
	var target := _find_closest_mob_globally()
	if not bullet_pool or not muzzle or not target:
		return
	ability_cooldowns["disintegrate"] = disintegrate_rate
	_show_casting_text("disintegrate")
	var projectile = bullet_pool.spawn()
	if not projectile:
		return
	projectile.owner_group = "player"
	projectile.damage = disintegrate_damage
	projectile.modulate = Color(0.9, 0.5, 1.0, 1.0)
	var direction := muzzle.global_position.direction_to(target.global_position)
	if projectile.has_method("launch"):
		projectile.launch(muzzle.global_position, direction)

func _cast_time_warp() -> void:
	ability_cooldowns["time_warp"] = time_warp_rate
	_show_casting_text("time_warp")
	var targets: Array = []
	targets.append_array(get_tree().get_nodes_in_group("friendly"))
	targets.append_array(get_tree().get_nodes_in_group("player"))
	for unit in targets:
		if is_instance_valid(unit) and unit.has_method("apply_speed_buff"):
			unit.apply_speed_buff(time_warp_speed_bonus, time_warp_duration)
	_spawn_time_warp_vfx()

func _find_closest_mob_globally() -> CharacterBody2D:
	var closest: CharacterBody2D = null
	var min_dist := INF
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible:
			var d := global_position.distance_to(mob.global_position)
			if d < min_dist:
				min_dist = d
				closest = mob as CharacterBody2D
	return closest

# --- VFX (unchanged from tenchijin.gd) ---
func _spawn_nova_vfx() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 100
	p.lifetime = 1.2
	p.spread = 180.0
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 250.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(0.4, 0.85, 1.0, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_meteor_windup_vfx(target_pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = target_pos + Vector2(0.0, -250.0)
	p.one_shot = true
	p.explosiveness = 0.4
	p.amount = 40
	p.lifetime = 0.7
	p.spread = 20.0
	p.direction = Vector2(0.0, 1.0)
	p.initial_velocity_min = 200.0
	p.initial_velocity_max = 350.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = Color(1.0, 0.5, 0.1, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_meteor_impact_vfx(impact_pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = impact_pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 140
	p.lifetime = 1.8
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 280.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	p.color = Color(1.0, 0.35, 0.05, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_time_warp_vfx() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 70
	p.lifetime = 2.0
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.75, 0.4, 1.0, 0.9)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _show_casting_text(key: String) -> void:
	if not casting_label or not casting_timer:
		return
	if CASTING_LINES.has(key):
		var lines: Array = CASTING_LINES[key]
		casting_label.text = lines[randi() % lines.size()]
	else:
		casting_label.text = key
	casting_timer.start()
	var ui = get_node_or_null("/root/UI")
	if ui and ui.has_method("chat_add"):
		ui.chat_add(casting_label.text, "Tenchijin")

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
	var actual_damage := int(damage * 0.5) # 50% damage reduction — archmage passive
	current_health -= actual_damage
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
		sprite.modulate = Color.CYAN
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
			emit_signal("damage_updated", frost_bolt_damage * damage_modifier)

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
			emit_signal("damage_updated", frost_bolt_damage * damage_modifier)
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
	if current_health <= 0 or current_health >= max_health:
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
	emit_signal("damage_updated", frost_bolt_damage * damage_modifier)
