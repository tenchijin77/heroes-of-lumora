# healer.gd - Priestess AI healer logic
extends "res://Scripts/npc.gd"

@export var max_speed: float = 40.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var attack_rate: float = 1.0
@export var attack_range: float = 200.0
@export var heal_rate: float = 2.0
@export var heal_range: float = 250.0
@export var base_damage: int = 5
@export var current_health: int = 75
@export var max_health: int = 75
@export var patrol_radius: float = 300.0
@export var projectile_scene: PackedScene

# FIXED: New export for heal priority threshold
@export var critical_health_threshold: float = 0.3  # Heal if unit is below 30% HP

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var patrol_timer: Timer = $patrol_timer
@onready var avoidance_ray: RayCast2D = $avoidance_ray

var current_target: CharacterBody2D = null
var current_friendly_target: CharacterBody2D = null
var current_state: String = "PATROL"
var last_action_time: float = 0.0
var damage_modifier: float = 1.0
var patrol_center: Vector2
var patrol_target: Vector2

func _ready() -> void:
	add_to_group("healing_npcs")
	velocity = Vector2.ZERO

	if projectile_scene and bullet_pool:
		bullet_pool.node_scene = projectile_scene

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	patrol_center = global_position
	_update_patrol_target()
	patrol_timer.timeout.connect(_update_patrol_target)

func _process(delta: float) -> void:
	_update_targets()

	if current_state == "ATTACKING" and current_target:
		_update_avoidance_ray(current_target, attack_range)
	if current_state == "HEALING" and current_friendly_target:
		_update_avoidance_ray(current_friendly_target, heal_range)

	match current_state:
		"PATROL":
			_patrol_state(delta)
		"HEALING":
			_healing_state(delta)
		"ATTACKING":
			_attacking_state(delta)

	_update_flip_h()

func _physics_process(delta: float) -> void:
	move_and_slide()

func _update_avoidance_ray(target: Node2D, range: float) -> void:
	if avoidance_ray and target and is_instance_valid(target):
		avoidance_ray.target_position = (target.global_position - global_position).normalized() * range
		avoidance_ray.force_raycast_update()

func _has_clear_line_to_target(target: Node2D) -> bool:
	if not avoidance_ray or not target or not is_instance_valid(target):
		return false
	return not avoidance_ray.is_colliding() or avoidance_ray.get_collider() == target

# FIXED: Completely rewritten priority logic
func _update_targets() -> void:
	var heal_target = _find_low_health_friendly()
	var enemy_target = _find_closest_mob()

	# FIXED: Prioritize healing critical targets first
	if heal_target and heal_target.has_method("get_health") and heal_target.has_method("get_max_health"):
		var health_percent = float(heal_target.get_health()) / float(heal_target.get_max_health())
		
		# If someone is critically wounded, ALWAYS heal them first
		if health_percent < critical_health_threshold:
			current_friendly_target = heal_target
			current_state = "HEALING"
			current_target = null
			return
		
		# Otherwise, heal if they're closer than enemies OR there are no enemies
		if enemy_target:
			var heal_dist = global_position.distance_to(heal_target.global_position)
			var enemy_dist = global_position.distance_to(enemy_target.global_position)
			
			# Heal if friendly is closer OR if friendly is moderately hurt (< 70% HP)
			if heal_dist < enemy_dist or health_percent < 0.7:
				current_friendly_target = heal_target
				current_state = "HEALING"
				current_target = null
			else:
				current_target = enemy_target
				current_state = "ATTACKING"
				current_friendly_target = null
		else:
			# No enemies, just heal
			current_friendly_target = heal_target
			current_state = "HEALING"
			current_target = null
	elif enemy_target:
		# No one needs healing, attack
		current_target = enemy_target
		current_state = "ATTACKING"
		current_friendly_target = null
	else:
		# Nothing to do, patrol
		current_state = "PATROL"

# FIXED: Find the MOST wounded friendly, not just closest
func _find_low_health_friendly() -> CharacterBody2D:
	var most_wounded: CharacterBody2D = null
	var lowest_health_percent: float = 1.0  # 100%

	var friendlies = get_tree().get_nodes_in_group("friendly")
	if player and is_instance_valid(player):
		friendlies.append(player)

	for unit in friendlies:
		if unit == self:
			continue
			
		if not is_instance_valid(unit):
			continue
			
		if not unit.has_method("get_health") or not unit.has_method("get_max_health"):
			continue
		
		var current_hp = unit.get_health()
		var max_hp = unit.get_max_health()
		
		# Only consider units that are wounded and in range
		if current_hp >= max_hp:
			continue
		
		var distance = global_position.distance_to(unit.global_position)
		if distance > heal_range:
			continue
		
		# Calculate health percentage
		var health_percent = float(current_hp) / float(max_hp)
		
		# FIXED: Prioritize by health percentage, not distance
		# If tied on health, prefer closer target
		if health_percent < lowest_health_percent:
			lowest_health_percent = health_percent
			most_wounded = unit
		elif health_percent == lowest_health_percent and most_wounded:
			# Tiebreaker: prefer closer
			var dist_to_current = global_position.distance_to(unit.global_position)
			var dist_to_best = global_position.distance_to(most_wounded.global_position)
			if dist_to_current < dist_to_best:
				most_wounded = unit

	return most_wounded

func _find_closest_mob() -> CharacterBody2D:
	var closest_mob: CharacterBody2D = null
	var min_distance = attack_range

	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob):
			var distance = global_position.distance_to(mob.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_mob = mob

	return closest_mob

func _patrol_state(delta: float) -> void:
	var direction = global_position.direction_to(patrol_target)
	velocity = velocity.lerp(direction * max_speed, acceleration * delta)

	if global_position.distance_to(patrol_target) < 10.0:
		_update_patrol_target()

func _healing_state(delta: float) -> void:
	if current_friendly_target and is_instance_valid(current_friendly_target):
		var distance = global_position.distance_to(current_friendly_target.global_position)
		if distance <= heal_range and _has_clear_line_to_target(current_friendly_target):
			velocity = Vector2.ZERO
			_perform_heal()
		else:
			var direction = global_position.direction_to(current_friendly_target.global_position)
			velocity = velocity.lerp(direction * max_speed, acceleration * delta)
	else:
		current_state = "PATROL"

func _attacking_state(delta: float) -> void:
	if current_target and is_instance_valid(current_target):
		var distance = global_position.distance_to(current_target.global_position)
		if distance <= attack_range and _has_clear_line_to_target(current_target):
			velocity = Vector2.ZERO
			_perform_attack()
		else:
			var direction = global_position.direction_to(current_target.global_position)
			velocity = velocity.lerp(direction * max_speed, acceleration * delta)
	else:
		current_state = "PATROL"

func _perform_heal() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_action_time > heal_rate and current_friendly_target and is_instance_valid(current_friendly_target):
		last_action_time = current_time
		_cast_projectile(current_friendly_target, "friendly")

func _perform_attack() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_action_time > attack_rate and current_target and is_instance_valid(current_target):
		last_action_time = current_time
		_cast_projectile(current_target, "monsters")

func _cast_projectile(target: CharacterBody2D, target_group: String) -> void:
	if bullet_pool and muzzle and target and is_instance_valid(target):
		var projectile = bullet_pool.spawn()
		if projectile:
			projectile.global_position = muzzle.global_position
			projectile.move_direction = muzzle.global_position.direction_to(target.global_position)
			projectile.owner_group = "healer"
			if projectile.has_method("set_damage"):
				projectile.set_damage(base_damage * damage_modifier)
		else:
			push_warning("Healer: Failed to spawn projectile!")
	else:
		push_warning("Healer: Cannot fire—missing bullet_pool, muzzle, or invalid target!")

func _update_patrol_target() -> void:
	patrol_target = patrol_center + Vector2(randf_range(-patrol_radius, patrol_radius), randf_range(-patrol_radius, patrol_radius))
	patrol_timer.start(randf_range(3.0, 7.0))

func _update_flip_h() -> void:
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false

func take_damage(damage: int, _projectile_instance) -> void:
	current_health -= damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health

	if current_health <= 0:
		_die()
	else:
		_damage_flash()

func _damage_flash() -> void:
	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.05).timeout
		sprite.modulate = Color.WHITE

func _die() -> void:
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		visible = false
		set_process(false)
		set_physics_process(false)
		if $CollisionShape2D and is_instance_valid($CollisionShape2D):
			$CollisionShape2D.set_deferred("disabled", true)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func heal(amount: int) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
