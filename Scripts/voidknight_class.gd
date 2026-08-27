# voidknight_class.gd - Voidknight endless-mode character script (playable)
# Movement/input/pickup/death follow the woodstalker.gd player template. The
# actual abilities (Life Siphon, Necrotic Grasp, Shadow Ward, Void Slash, and
# the permanent Skeleton minion) are ported from voidknight.gd (the elite
# enemy version, which stays untouched for the monster roster) — group
# targets are flipped from "attack the player's side" to "attack monsters"
# since he's now on the player's side instead of the enemy's.
extends CharacterBody2D

signal damage_updated(damage: float)
signal speed_updated(speed: float)
signal health_updated(current: int, max: int)

@export var base_damage: int = 4 # Life Siphon bolt damage — matches arrow baseline
@export var max_speed: float = 75.0
@export var max_speed_cap: float = 150.0
@export var acceleration: float = 0.2
@export var braking: float = 0.15
@export var firing_speed: float = 1.0 # Life Siphon basic-attack rate
@export var current_health: int = 150
@export var max_health: int = 150
@export var regeneration_per_second: float = 2.0
@export var flip_sprite: bool = false

@export var life_siphon_ratio: float = 0.5 # lifesteal fraction of damage dealt
@export var necrotic_grasp_rate: float = 3.0
@export var necrotic_grasp_range: float = 120.0
@export var shadow_ward_rate: float = 8.0
@export var shadow_ward_amount: float = 50.0
@export var void_slash_rate: float = 6.0
@export var void_slash_range: float = 100.0
@export var void_slash_damage: int = 25

const _MINION_TEXTURE_PATH: String = "res://Assets/New Sprites/NPC Sprites 2.png"
const _MINION_REGION: Rect2 = Rect2(464, 89, 169, 268)

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var pickup_area: Area2D = $pickup_area
@onready var player_damage_sound: AudioStreamPlayer2D = $player_damage_sound

var move_input: Vector2
var damage_modifier: float = 1.0
var last_shoot_time: float
var speed_buff_active: bool = false
var base_max_speed: float = 75.0
var active_effect_timers: Dictionary = {}
var cached_aim_vector: Vector2 = Vector2.ZERO

var _shield_hp: float = 0.0
var _minion: Node = null

var ability_cooldowns: Dictionary = {
	"necrotic_grasp": 0.0,
	"shadow_ward": 0.0,
	"void_slash": 0.0,
}

# Endless mode: all locked at start, unlocked in SPELL_PROGRESSION order via ability_chest drops.
var spells_unlocked: Dictionary = {
	"shadow_ward": false,
	"necrotic_grasp": false,
	"void_slash": false,
	"summon_skeleton": false,
}
const SPELL_PROGRESSION: Array = [
	"shadow_ward", "necrotic_grasp", "void_slash", "summon_skeleton",
]

func _ready() -> void:
	collision_mask = 16 + 2048 # Environment (buildings) + Walls
	add_to_group("player")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	var regen_timer := Timer.new()
	regen_timer.wait_time = 1.0
	regen_timer.autostart = true
	regen_timer.timeout.connect(_on_regen_tick)
	add_child(regen_timer)
	emit_signal("damage_updated", base_damage * damage_modifier)
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

# Life Siphon — basic attack, player-aimed. Heals for half the damage dealt
# via projectile.gd's generic lifesteal_percent hook.
func open_fire() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle:
		return
	var bolt = bullet_pool.spawn()
	if not bolt:
		return
	bolt.shooter = self
	bolt.owner_group = "player"
	bolt.damage = int(base_damage * damage_modifier)
	bolt.lifesteal_percent = life_siphon_ratio
	var aim_vector: Vector2 = cached_aim_vector
	if aim_vector.is_zero_approx():
		aim_vector = muzzle.global_position.direction_to(get_global_mouse_position())
	bolt.global_position = muzzle.global_position
	bolt.move_direction = aim_vector
	bolt.launch(muzzle.global_position, aim_vector)

func _perform_auto_spells() -> void:
	if spells_unlocked.get("shadow_ward", false) and ability_cooldowns["shadow_ward"] <= 0.0 and _shield_hp <= 0.0:
		_cast_shadow_ward()
	if spells_unlocked.get("void_slash", false) and ability_cooldowns["void_slash"] <= 0.0:
		_cast_void_slash()
	if spells_unlocked.get("necrotic_grasp", false) and ability_cooldowns["necrotic_grasp"] <= 0.0:
		_cast_necrotic_grasp()

func _cast_necrotic_grasp() -> void:
	var target := _find_closest_mob_in_range(necrotic_grasp_range)
	if not target:
		return
	ability_cooldowns["necrotic_grasp"] = necrotic_grasp_rate
	if target.has_method("apply_slow"):
		target.apply_slow(0.10, 4.0)

func _cast_shadow_ward() -> void:
	ability_cooldowns["shadow_ward"] = shadow_ward_rate
	_shield_hp = shadow_ward_amount
	_spawn_ward_vfx()

func _cast_void_slash() -> void:
	ability_cooldowns["void_slash"] = void_slash_rate
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible and global_position.distance_to(mob.global_position) <= void_slash_range:
			if mob.has_method("take_damage"):
				mob.take_damage(void_slash_damage, self)
	_spawn_slash_vfx()

func _find_closest_mob_in_range(range_dist: float) -> Node:
	var closest: Node = null
	var min_dist := INF
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible:
			var d := global_position.distance_to(mob.global_position)
			if d <= range_dist and d < min_dist:
				min_dist = d
				closest = mob
	return closest

# --- Unlocks (ability chest, endless mode) ---
func _unlock_next_spell() -> void:
	for spell in SPELL_PROGRESSION:
		if not spells_unlocked.get(spell, true):
			_unlock_spell(spell)
			return

func _unlock_spell(spell: String) -> void:
	match spell:
		"summon_skeleton":
			spells_unlocked["summon_skeleton"] = true
			_spawn_minion()
		_:
			spells_unlocked[spell] = true

func _spawn_minion() -> void:
	if _minion and is_instance_valid(_minion):
		return
	var minion := CharacterBody2D.new()
	minion.set_script(load("res://Scripts/ally_minion.gd"))
	minion.global_position = global_position + Vector2(-40, 0)
	var main := get_tree().root.get_node_or_null("main")
	var parent: Node = main if main else get_tree().current_scene
	if not parent:
		return
	parent.add_child(minion)
	var tex := load(_MINION_TEXTURE_PATH) as Texture2D
	minion.init(self, tex, _MINION_REGION, "a Skeleton minion", int(max_health * 0.45), 8)
	_minion = minion

func _spawn_ward_vfx() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 30
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.45, 0.2, 0.7, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_slash_vfx() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 50
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.55, 0.1, 0.85, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

# --- Health / death / pickup (player template) ---
func take_damage(damage: int, source: Node) -> void:
	if Global.godmode:
		return
	var remaining := damage
	if _shield_hp > 0.0:
		var absorbed: float = min(_shield_hp, float(remaining))
		_shield_hp -= absorbed
		remaining -= int(absorbed)
	if remaining <= 0:
		return
	current_health -= remaining
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	emit_signal("health_updated", current_health, max_health)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(5.0, 0.2)
	if current_health <= 0:
		if _minion and is_instance_valid(_minion) and _minion.has_method("notify_owner_died"):
			_minion.notify_owner_died()
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
	emit_signal("damage_updated", base_damage * damage_modifier)
