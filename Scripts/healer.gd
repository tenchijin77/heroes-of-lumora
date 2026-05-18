# healer.gd - Stationary priestess: heals friendlies and attacks monsters in range
extends "res://Scripts/npc.gd"

@export var attack_rate: float = 1.0
@export var attack_range: float = 200.0
@export var heal_rate: float = 2.0
@export var heal_range: float = 250.0
@export var base_damage: int = 5
@export var critical_health_threshold: float = 0.3
@export var projectile_scene: PackedScene

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool

var current_target: CharacterBody2D = null
var current_friendly_target: CharacterBody2D = null
var current_state: String = "IDLE"
var last_action_time: float = 0.0
var damage_modifier: float = 1.0

func _ready() -> void:
	add_to_group("healing_npcs")
	collision_mask = 0  # Stationary, no physical collision needed
	velocity = Vector2.ZERO
	if projectile_scene and bullet_pool:
		bullet_pool.node_scene = projectile_scene
	var health_bar_node = get_node_or_null("health_bar")
	if health_bar_node:
		health_bar_node.visible = false

func _process(_delta: float) -> void:
	_update_targets()
	match current_state:
		"HEALING":
			_healing_state()
		"ATTACKING":
			_attacking_state()
	_update_flip_h()

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

func _update_targets() -> void:
	var heal_target := _find_low_health_friendly()
	var enemy_target := _find_closest_mob()

	if heal_target and heal_target.has_method("get_health") and heal_target.has_method("get_max_health"):
		var health_percent := float(heal_target.get_health()) / float(heal_target.get_max_health())
		if health_percent < critical_health_threshold:
			current_friendly_target = heal_target
			current_state = "HEALING"
			current_target = null
			return
		if enemy_target:
			var heal_dist := global_position.distance_to(heal_target.global_position)
			var enemy_dist := global_position.distance_to(enemy_target.global_position)
			if heal_dist < enemy_dist or health_percent < 0.7:
				current_friendly_target = heal_target
				current_state = "HEALING"
				current_target = null
			else:
				current_target = enemy_target
				current_state = "ATTACKING"
				current_friendly_target = null
		else:
			current_friendly_target = heal_target
			current_state = "HEALING"
			current_target = null
	elif enemy_target:
		current_target = enemy_target
		current_state = "ATTACKING"
		current_friendly_target = null
	else:
		current_state = "IDLE"

func _find_low_health_friendly() -> CharacterBody2D:
	var most_wounded: CharacterBody2D = null
	var lowest_health_percent: float = 1.0
	var player_node = get_tree().get_first_node_in_group("player")
	var friendlies: Array = get_tree().get_nodes_in_group("friendly")
	if player_node and is_instance_valid(player_node):
		friendlies.append(player_node)
	for unit in friendlies:
		if unit == self or not is_instance_valid(unit):
			continue
		if not unit.has_method("get_health") or not unit.has_method("get_max_health"):
			continue
		var current_hp: int = unit.get_health()
		var max_hp: int = unit.get_max_health()
		if current_hp >= max_hp:
			continue
		if global_position.distance_to(unit.global_position) > heal_range:
			continue
		var health_percent := float(current_hp) / float(max_hp)
		if health_percent < lowest_health_percent:
			lowest_health_percent = health_percent
			most_wounded = unit
	return most_wounded

func _find_closest_mob() -> CharacterBody2D:
	var closest_mob: CharacterBody2D = null
	var min_distance := attack_range
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible:
			var distance := global_position.distance_to(mob.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_mob = mob
	return closest_mob

func _healing_state() -> void:
	if current_friendly_target and is_instance_valid(current_friendly_target):
		_perform_heal()
	else:
		current_state = "IDLE"

func _attacking_state() -> void:
	if current_target and is_instance_valid(current_target):
		_perform_attack()
	else:
		current_state = "IDLE"

func _perform_heal() -> void:
	var current_time := Time.get_unix_time_from_system()
	if current_time - last_action_time > heal_rate and current_friendly_target and is_instance_valid(current_friendly_target):
		last_action_time = current_time
		_cast_projectile(current_friendly_target)

func _perform_attack() -> void:
	var current_time := Time.get_unix_time_from_system()
	if current_time - last_action_time > attack_rate and current_target and is_instance_valid(current_target):
		last_action_time = current_time
		_cast_projectile(current_target)

func _cast_projectile(target: CharacterBody2D) -> void:
	if not bullet_pool or not muzzle or not target or not is_instance_valid(target):
		push_warning("Healer: Cannot fire—missing bullet_pool, muzzle, or invalid target!")
		return
	var projectile = bullet_pool.spawn()
	if not projectile:
		push_warning("Healer: Failed to spawn projectile!")
		return
	var direction := muzzle.global_position.direction_to(target.global_position)
	projectile.owner_group = "healer"
	if projectile.has_method("set_damage"):
		projectile.set_damage(base_damage * damage_modifier)
	if projectile.has_method("launch"):
		projectile.launch(muzzle.global_position, direction)
	else:
		projectile.global_position = muzzle.global_position
		projectile.move_direction = direction

func _update_flip_h() -> void:
	var face_target: Node2D = current_friendly_target if current_state == "HEALING" else current_target
	if face_target and is_instance_valid(face_target):
		sprite.flip_h = face_target.global_position.x > global_position.x

func get_health() -> int:
	return 100

func get_max_health() -> int:
	return 100

func heal(_amount: int) -> void:
	pass  # Priestess is immortal
