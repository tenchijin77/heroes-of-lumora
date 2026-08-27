# gravecaller_class.gd - Gravecaller endless-mode character script (playable)
# Movement/input/pickup/death follow the woodstalker.gd player template. The
# actual abilities (Death Bolt, Curse of Withering, Plague Cloud, and the
# permanent Wraith minion) are ported from gravecaller.gd (the elite enemy
# version, which stays untouched for the monster roster) — group targets are
# flipped from "attack the player's side" to "attack monsters" since he's now
# on the player's side instead of the enemy's.
extends CharacterBody2D

signal damage_updated(damage: float)
signal speed_updated(speed: float)
signal health_updated(current: int, max: int)

@export var base_damage: int = 4 # Death Bolt damage — matches arrow baseline
@export var max_speed: float = 85.0
@export var max_speed_cap: float = 170.0
@export var acceleration: float = 0.2
@export var braking: float = 0.15
@export var firing_speed: float = 0.9 # Death Bolt basic-attack rate
@export var current_health: int = 90
@export var max_health: int = 90
@export var regeneration_per_second: float = 2.0
@export var flip_sprite: bool = false

@export var curse_rate: float = 5.0
@export var curse_damage_per_tick: int = 4
@export var curse_ticks: int = 6
@export var curse_range: float = 250.0
@export var plague_rate: float = 8.0
@export var plague_radius: float = 60.0
@export var plague_tick_damage: int = 5
@export var plague_duration: float = 4.0
@export var plague_range: float = 250.0

const _MINION_TEXTURE_PATH: String = "res://Assets/New Sprites/NPC Sprites 2.png"
const _MINION_REGION: Rect2 = Rect2(1090, 68, 244, 289)

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
var base_max_speed: float = 85.0
var active_effect_timers: Dictionary = {}
var cached_aim_vector: Vector2 = Vector2.ZERO

var _minion: Node = null

var ability_cooldowns: Dictionary = {
	"curse_of_withering": 0.0,
	"plague_cloud": 0.0,
}

# Endless mode: all locked at start, unlocked in SPELL_PROGRESSION order via ability_chest drops.
var spells_unlocked: Dictionary = {
	"curse_of_withering": false,
	"plague_cloud": false,
	"summon_wraith": false,
}
const SPELL_PROGRESSION: Array = [
	"curse_of_withering", "plague_cloud", "summon_wraith",
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
	var aim_vector: Vector2 = cached_aim_vector
	if aim_vector.is_zero_approx():
		aim_vector = muzzle.global_position.direction_to(get_global_mouse_position())
	bolt.global_position = muzzle.global_position
	bolt.move_direction = aim_vector
	bolt.launch(muzzle.global_position, aim_vector)

func _perform_auto_spells() -> void:
	if spells_unlocked.get("plague_cloud", false) and ability_cooldowns["plague_cloud"] <= 0.0:
		_cast_plague_cloud()
	if spells_unlocked.get("curse_of_withering", false) and ability_cooldowns["curse_of_withering"] <= 0.0:
		_cast_curse_of_withering()

func _cast_curse_of_withering() -> void:
	var target := _find_closest_mob_in_range(curse_range)
	if not target:
		return
	ability_cooldowns["curse_of_withering"] = curse_rate
	if target.has_method("apply_dot"):
		target.apply_dot(curse_damage_per_tick, curse_ticks)
	_spawn_curse_vfx(target.global_position)

func _cast_plague_cloud() -> void:
	var target := _find_closest_mob_in_range(plague_range)
	var pos: Vector2 = target.global_position if target else global_position
	ability_cooldowns["plague_cloud"] = plague_rate
	call_deferred("_spawn_plague_cloud", pos)

func _spawn_plague_cloud(pos: Vector2) -> void:
	var cloud := Area2D.new()
	cloud.collision_layer = 0
	cloud.collision_mask = 2 # Monsters
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = plague_radius
	shape.shape = circle
	cloud.add_child(shape)

	var visual := CPUParticles2D.new()
	visual.amount = 24
	visual.lifetime = plague_duration
	visual.local_coords = false
	visual.spread = 180.0
	visual.initial_velocity_min = 5.0
	visual.initial_velocity_max = 20.0
	visual.scale_amount_min = 3.0
	visual.scale_amount_max = 6.0
	visual.color = Color(0.35, 0.7, 0.2, 0.7)
	cloud.add_child(visual)

	var main := get_tree().root.get_node_or_null("main")
	var parent: Node = main if main else get_tree().current_scene
	parent.add_child(cloud)
	cloud.global_position = pos
	visual.emitting = true

	var tick_timer := Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	cloud.add_child(tick_timer)
	tick_timer.timeout.connect(func():
		if not is_instance_valid(cloud):
			return
		for body in cloud.get_overlapping_bodies():
			if is_instance_valid(body) and body.is_in_group("monsters") and body.has_method("take_damage"):
				body.take_damage(plague_tick_damage, null)
	)
	get_tree().create_timer(plague_duration).timeout.connect(func():
		if is_instance_valid(cloud): cloud.queue_free()
	)

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
		"summon_wraith":
			spells_unlocked["summon_wraith"] = true
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
	minion.init(self, tex, _MINION_REGION, "a Wraith minion", int(max_health * 0.5), 10)
	_minion = minion

func _spawn_curse_vfx(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.7
	p.spread = 180.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 50.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.3, 0.55, 0.15, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

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
