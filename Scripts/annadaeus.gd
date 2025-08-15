#annadaeus.gd - AI for Annadaeus's logic
extends CharacterBody2D

# --- Annadaeus's Abilities ---
@export var max_speed: float = 40.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9

@export var song_of_courage_rate: float = 15.0 # Cooldown for buffing
@export var song_of_renewal_rate: float = 10.0 # Cooldown for healing
@export var symphony_of_fate_rate: float = 20.0 # Cooldown for AoE
@export var finale_rate: float = 45.0 # Cooldown for ultimate
@export var illusory_double_hp_threshold: float = 0.3 # HP to trigger escape
@export var support_range: float = 300.0

@export var current_health: int = 75
@export var max_health: int = 75

@export var buffing_aura_scene: PackedScene # New variable for the buffing aura scene
@export var ability_projectile_scene: PackedScene # The projectile Annadaeus uses (troubadour_bolt)

# --- Node References (from healer.gd) ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var avoidance_ray: RayCast2D = $avoidance_ray
@onready var casting_label: Label = $casting_label
@onready var casting_timer: Timer = $casting_timer

var current_target: CharacterBody2D = null
var current_friendly_target: CharacterBody2D = null
var current_state: String = "IDLE"
var last_ability_time: float = 0.0
var ability_cooldowns: Dictionary = {
	"courage": 0.0,
	"renewal": 0.0,
	"symphony": 0.0,
	"finale": 0.0
}

func _ready():
	add_to_group("friendly")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	casting_timer.timeout.connect(func(): _show_casting_text(""))

func _process(delta: float):
	_update_targets()
	_update_cooldowns(delta)
	
	match current_state:
		"IDLE":
			_idle_state(delta)
			_move_wobble()
		"FOLLOWING_PLAYER":
			_following_player_state(delta)
			_move_wobble()
		"CASTING":
			_casting_state(delta)
			sprite.rotation_degrees = 0
		"DEFENDING_PLAYER":
			_defending_player_state(delta)
			_move_wobble()

	if current_target:
		_update_avoidance_ray(current_target, support_range)

	_update_flip_h()

func _physics_process(delta: float):
	move_and_slide()

# --- State & Target Logic ---
func _update_targets():
	if current_state != "CASTING":
		var heal_target = _find_low_health_friendly()
		var enemy_target = _find_closest_mob()
		var player_distance = global_position.distance_to(player.global_position) if player else INF

		if current_health <= max_health * illusory_double_hp_threshold:
			current_state = "ESCAPING"
		elif heal_target and ability_cooldowns["renewal"] <= 0:
			current_friendly_target = heal_target
			_perform_song_of_renewal(heal_target)
		elif enemy_target and ability_cooldowns["symphony"] <= 0:
			current_target = enemy_target
			_perform_symphony_of_fate(enemy_target)
		elif player_distance > support_range - 50:
			current_state = "FOLLOWING_PLAYER"
		elif player and ability_cooldowns["courage"] <= 0:
			_perform_song_of_courage()
		else:
			current_state = "IDLE"

func _update_cooldowns(delta: float):
	for key in ability_cooldowns:
		if ability_cooldowns[key] > 0:
			ability_cooldowns[key] -= delta

# --- States ---
func _idle_state(delta: float):
	velocity = velocity.lerp(Vector2.ZERO, drag)

func _following_player_state(delta: float):
	if player and is_instance_valid(player):
		var direction = global_position.direction_to(player.global_position)
		velocity = velocity.lerp(direction * max_speed, acceleration * delta)

func _casting_state(delta: float):
	velocity = Vector2.ZERO
	# The function that put it in this state is responsible for getting it out

func _defending_player_state(delta: float):
	if current_target and is_instance_valid(current_target):
		var direction = global_position.direction_to(current_target.global_position)
		velocity = velocity.lerp(direction * max_speed, acceleration * delta)

# --- Abilities ---
func _perform_song_of_courage():
	_show_casting_text("Courage!")
	current_state = "CASTING"
	await get_tree().create_timer(1.0).timeout
	ability_cooldowns["courage"] = song_of_courage_rate
	_spawn_buffing_aura()
	current_state = "IDLE"

func _perform_song_of_renewal(target: CharacterBody2D):
	_show_casting_text("Renewal!")
	current_state = "CASTING"
	await get_tree().create_timer(1.0).timeout
	ability_cooldowns["renewal"] = song_of_renewal_rate
	_spawn_healing_projectile(target)
	current_state = "IDLE"

func _perform_symphony_of_fate(target: CharacterBody2D):
	_show_casting_text("Symphony!")
	current_state = "CASTING"
	await get_tree().create_timer(1.0).timeout
	ability_cooldowns["symphony"] = symphony_of_fate_rate
	_spawn_ability_projectile(target)
	current_state = "IDLE"

func _spawn_buffing_aura():
	if buffing_aura_scene:
		var aura = buffing_aura_scene.instantiate()
		aura.global_position = global_position
		get_parent().add_child(aura)

func _spawn_healing_projectile(target: CharacterBody2D):
	if bullet_pool and muzzle and target and is_instance_valid(target):
		var projectile = bullet_pool.spawn()
		if projectile:
			projectile.global_position = muzzle.global_position
			projectile.move_direction = muzzle.global_position.direction_to(target.global_position)

func _spawn_ability_projectile(target: CharacterBody2D):
	if bullet_pool and muzzle and target and is_instance_valid(target):
		var projectile = bullet_pool.spawn()
		if projectile:
			projectile.global_position = muzzle.global_position
			projectile.move_direction = muzzle.global_position.direction_to(target.global_position)

# --- Utility ---
func _update_avoidance_ray(target: Node2D, range: float):
	if avoidance_ray and target and is_instance_valid(target):
		avoidance_ray.target_position = (target.global_position - global_position).normalized() * range
		avoidance_ray.force_raycast_update()

func _has_clear_line_to_target(target: Node2D) -> bool:
	if not avoidance_ray or not target or not is_instance_valid(target):
		return false
	return not avoidance_ray.is_colliding() or avoidance_ray.get_collider() == target

func _is_player_buffed():
	# Placeholder for checking if player has active buffs
	return true
	
func _show_casting_text(text: String):
	if casting_label and casting_timer:
		casting_label.text = text
		casting_timer.start()

func take_damage(damage: int, _projectile_instance):
	current_health -= damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	if current_health <= 0:
		_die()
	else:
		_damage_flash()

func _damage_flash():
	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.05).timeout
		sprite.modulate = Color.WHITE

func _die():
	print("Annadaeus died!")
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		visible = false
		set_process(false)
		set_physics_process(false)
		if $CollisionShape2D and is_instance_valid($CollisionShape2D):
			$CollisionShape2D.set_deferred("disabled", true)

func _find_low_health_friendly() -> CharacterBody2D:
	var closest_unit: CharacterBody2D = null
	var min_distance: float = support_range
	var friendlies = get_tree().get_nodes_in_group("friendly") + get_tree().get_nodes_in_group("player")
	for unit in friendlies:
		if unit != self and is_instance_valid(unit) and unit.has_method("get_health") and unit.has_method("get_max_health"):
			if unit.get_health() < unit.get_max_health():
				var distance = global_position.distance_to(unit.global_position)
				if distance < min_distance:
					min_distance = distance
					closest_unit = unit
	return closest_unit

func _find_closest_mob() -> CharacterBody2D:
	var closest_mob: CharacterBody2D = null
	var min_distance = support_range
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob):
			var distance = global_position.distance_to(mob.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_mob = mob
	return closest_mob

# Handle sprite wobble animation
func _move_wobble() -> void:
	var rot: float = sin(Time.get_ticks_msec() / 100.0) * 2
	sprite.rotation_degrees = rot

func _update_flip_h():
	var active_target = _get_active_target()
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false
	elif active_target:
		sprite.flip_h = global_position.direction_to(active_target.global_position).x > 0

func _get_active_target() -> CharacterBody2D:
	if current_target and is_instance_valid(current_target):
		return current_target
	if current_friendly_target and is_instance_valid(current_friendly_target):
		return current_friendly_target
	return null
