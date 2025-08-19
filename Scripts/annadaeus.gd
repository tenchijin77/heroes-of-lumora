# annadaeus.gd - AI for Annadaeus's logic
extends CharacterBody2D

# --- Annadaeus's Abilities ---
@export var max_speed: float = 125.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var base_damage: int = 10 # Base damage for projectiles
@export var song_of_courage_rate: float = 15.0 # Cooldown for buffing
@export var song_of_renewal_rate: float = 10.0 # Cooldown for healing
@export var symphony_of_fate_rate: float = 2.0 # Cooldown for AoE
@export var finale_rate: float = 45.0 # Cooldown for ultimate
@export var illusory_double_rate: float = 25.0 # Cooldown for escape double
@export var illusory_double_hp_threshold: float = 0.3 # HP to trigger escape
@export var support_range: float = 300.0 # Range for targeting
@export var finale_range: float = 250.0 # Range for Finale AoE
@export var current_health: int = 75
@export var max_health: int = 75

# --- Node References ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var health_bar: ProgressBar = $health_bar
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var avoidance_ray: RayCast2D = $avoidance_ray
@onready var casting_label: Label = $casting_label
@onready var casting_timer: Timer = $casting_timer
@onready var renewal_aura: Area2D = $renewal_aura
@onready var courage_aura: Area2D = $courage_aura
@onready var renewal_aura_timer: Timer = $renewal_aura_timer
@onready var courage_aura_timer: Timer = $courage_aura_timer
@onready var finale_particles: GPUParticles2D = $finale_particles
@onready var finale_sound: AudioStreamPlayer2D = $finale_sound

var current_target: CharacterBody2D = null
var current_friendly_target: CharacterBody2D = null
var current_state: String = "FOLLOWING_PLAYER"
var last_ability_time: float = 0.0
var damage_modifier: float = 1.0 # Multiplier for damage buffs
var is_decoy: bool = false # Flag to identify decoys
var ability_cooldowns: Dictionary = {
	"courage": 0.0,
	"renewal": 0.0,
	"symphony": 0.0,
	"double": 0.0,
	"finale": 0.0
}
var casting_lines: Dictionary = {}
var target_update_timer: float = 0.0
var target_update_interval: float = 0.25 # Update more frequently

func _ready() -> void:
	# Initialize Annadaeus in the scene
	add_to_group("friendly")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	casting_timer.timeout.connect(func(): _show_casting_text(""))
	velocity = Vector2.ZERO
	_load_casting_lines()
	_configure_auras()

func _update_cooldowns(delta: float) -> void:
	# Decrease ability cooldowns over time
	for key in ability_cooldowns:
		if ability_cooldowns[key] > 0:
			ability_cooldowns[key] -= delta

func _process(delta: float) -> void:
	# Update Annadaeus's logic each frame, skip for decoys
	if is_decoy:
		return
	target_update_timer += delta
	if target_update_timer >= target_update_interval:
		_update_targets()
		target_update_timer = 0.0
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
		"ESCAPING":
			_escaping_state(delta)
			_move_wobble()
	if current_target:
		_update_avoidance_ray(current_target, support_range)
	_update_flip_h()

func _physics_process(delta: float) -> void:
	# Handle physics-based movement, skip for decoys
	if is_decoy:
		return
	move_and_slide()

# --- Setup Logic ---
func _load_casting_lines() -> void:
	# Load ability casting lines from JSON
	var file = FileAccess.open("res://Data/annadaeus_casting_lines.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			casting_lines = json.get_data()
		else:
			print("JSON Parse Error: ", json.get_error_message())
		file.close()

func _configure_auras() -> void:
	# Configure aura collision masks and timers
	renewal_aura.collision_mask = 1057 # Player (1), friendly (6), healer (10)
	courage_aura.collision_mask = 1057
	renewal_aura.visible = false
	courage_aura.visible = false
	renewal_aura_timer.timeout.connect(func(): renewal_aura.visible = false)
	courage_aura_timer.timeout.connect(func(): courage_aura.visible = false)

# --- State & Target Logic ---
func _update_targets() -> void:
	# Determine current target and state
	if current_state == "CASTING":
		return
	current_target = null
	current_friendly_target = null
	if current_health <= max_health * illusory_double_hp_threshold and ability_cooldowns["double"] <= 0:
		print("Annadaeus: Health=%d, Double CD=%.2f, triggering Illusory Double" % [current_health, ability_cooldowns["double"]])
		_perform_illusory_double()
		return
	var enemy_target = _find_closest_mob()
	if enemy_target and _has_clear_line_to_target(enemy_target) and ability_cooldowns["symphony"] <= 0:
		current_target = enemy_target
		_perform_symphony_of_fate(enemy_target)
		return
	var damaged_friendlies = _find_damaged_friendlies_in_range()
	if damaged_friendlies.size() > 0 and ability_cooldowns["renewal"] <= 0:
		_perform_song_of_renewal()
		return
	var friendlies = _find_friendlies_in_range()
	if friendlies.size() > 0 and ability_cooldowns["courage"] <= 0:
		_perform_song_of_courage()
		return
	if _is_critical_situation() and ability_cooldowns["finale"] <= 0:
		_perform_finale()
		return
	current_state = "FOLLOWING_PLAYER"

# --- States ---
func _idle_state(delta: float) -> void:
	# Slow down to a stop
	velocity = velocity.lerp(Vector2.ZERO, drag)

func _following_player_state(delta: float) -> void:
	# Move toward player, stopping at 75-pixel distance
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance > 75.0:
			var direction = global_position.direction_to(player.global_position)
			velocity = velocity.lerp(direction * max_speed, acceleration * delta)
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

func _casting_state(delta: float) -> void:
	# Stop movement during casting
	velocity = Vector2.ZERO

func _escaping_state(delta: float) -> void:
	# Move away from closest enemy
	var closest_enemy = _find_closest_mob()
	if closest_enemy and is_instance_valid(closest_enemy):
		var direction = global_position.direction_to(closest_enemy.global_position).normalized()
		velocity = velocity.lerp(-direction * max_speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, drag)

# --- Abilities ---
func _perform_song_of_courage() -> void:
	# Activate courage aura to buff allies
	_show_casting_text("Song of Courage")
	current_state = "CASTING"
	await get_tree().create_timer(1.0).timeout
	ability_cooldowns["courage"] = song_of_courage_rate
	_activate_courage_aura()
	current_state = "FOLLOWING_PLAYER"

func _perform_song_of_renewal() -> void:
	# Activate renewal aura to heal allies, including self
	_show_casting_text("Song of Renewal")
	current_state = "CASTING"
	await get_tree().create_timer(1.0).timeout
	ability_cooldowns["renewal"] = song_of_renewal_rate
	_activate_renewal_aura()
	if current_health < max_health:
		heal(4) # Match renewal_aura.gd's heal_amount
	current_state = "FOLLOWING_PLAYER"

func _perform_symphony_of_fate(target: CharacterBody2D) -> void:
	# Fire sonic projectile at the closest enemy
	_show_casting_text("Symphony of Fate")
	current_state = "CASTING"
	if target and is_instance_valid(target):
		current_target = target
		print("Annadaeus: Targeting enemy %s at position %s for Symphony of Fate" % [target.name, target.global_position])
		_spawn_ability_projectile(target)
	else:
		var new_target = _find_closest_mob()
		if new_target and is_instance_valid(new_target) and _has_clear_line_to_target(new_target):
			current_target = new_target
			print("Annadaeus: Retargeted enemy %s at position %s for Symphony of Fate" % [new_target.name, new_target.global_position])
			_spawn_ability_projectile(new_target)
		else:
			print("Annadaeus: No valid enemy target for Symphony of Fate, firing randomly")
			_spawn_ability_projectile_random()
	ability_cooldowns["symphony"] = symphony_of_fate_rate
	current_state = "FOLLOWING_PLAYER"

func _perform_finale() -> void:
	# Deal instant damage to all enemies within finale_range, boosted by auras
	_show_casting_text("Finale")
	current_state = "CASTING"
	if finale_particles and is_instance_valid(finale_particles):
		finale_particles.emitting = true
	if finale_sound and is_instance_valid(finale_sound):
		finale_sound.play()
		print("Annadaeus: Playing Finale sound")
	var base_finale_damage: int = 25
	var damage_boost: float = 1.0 + 0.5 * (int(courage_aura.visible) + int(renewal_aura.visible))
	var final_damage: int = int(base_finale_damage * damage_boost)
	var hit_count: int = 0
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.has_method("take_damage"):
			var distance = global_position.distance_to(mob.global_position)
			if distance <= finale_range:
				mob.take_damage(final_damage, null)
				hit_count += 1
	print("Annadaeus: Finale hit %d enemies within %.2f pixels for %d damage (boost=%.2f)" % [hit_count, finale_range, final_damage, damage_boost])
	ability_cooldowns["finale"] = finale_rate
	current_state = "FOLLOWING_PLAYER"

func _perform_illusory_double() -> void:
	# Spawn static decoy and enter escaping state, return to following after 5s
	_show_casting_text("Illusory Double")
	current_state = "CASTING"
	await get_tree().create_timer(1.0).timeout
	ability_cooldowns["double"] = illusory_double_rate
	_spawn_decoy()
	current_state = "ESCAPING"
	await get_tree().create_timer(5.0).timeout
	current_state = "FOLLOWING_PLAYER"

func _activate_courage_aura() -> void:
	# Show courage aura (effects in aura script)
	courage_aura.visible = true
	courage_aura_timer.start()

func _activate_renewal_aura() -> void:
	# Show renewal aura (effects in aura script)
	renewal_aura.visible = true
	renewal_aura_timer.start()

func _spawn_ability_projectile(target: CharacterBody2D) -> void:
	# Spawn sonic projectile from bullet pool targeting enemy
	if bullet_pool and muzzle and target and is_instance_valid(target):
		var projectile = bullet_pool.spawn()
		if projectile:
			projectile.global_position = muzzle.global_position
			projectile.move_direction = muzzle.global_position.direction_to(target.global_position)
			if projectile.has_method("set_damage"):
				projectile.set_damage(base_damage * damage_modifier)
			print("Annadaeus: Fired Symphony of Fate projectile at %s, direction=%s" % [target.name, projectile.move_direction])
	else:
		print("Annadaeus: Failed to spawn Symphony of Fate projectile, target=%s, bullet_pool=%s, muzzle=%s" % [target.name if target else "null", bullet_pool, muzzle])

func _spawn_ability_projectile_random() -> void:
	# Fallback to random direction if no target
	if bullet_pool and muzzle:
		var projectile = bullet_pool.spawn()
		if projectile:
			projectile.global_position = muzzle.global_position
			var random_angle = randf_range(0, 2 * PI)
			projectile.move_direction = Vector2(cos(random_angle), sin(random_angle))
			if projectile.has_method("set_damage"):
				projectile.set_damage(base_damage * damage_modifier)
			print("Annadaeus: Fired Symphony of Fate projectile in random direction=%s" % projectile.move_direction)

func _spawn_finale_projectile(target: CharacterBody2D) -> void:
	# Spawn enhanced projectile, boosted by active auras
	if bullet_pool and muzzle and target and is_instance_valid(target):
		var projectile = bullet_pool.spawn()
		if projectile:
			projectile.global_position = muzzle.global_position
			projectile.move_direction = muzzle.global_position.direction_to(target.global_position)
			var damage_boost = 1.0
			if courage_aura.visible:
				damage_boost += 0.5
			if renewal_aura.visible:
				damage_boost += 0.5
			if projectile.has_method("set_damage"):
				projectile.set_damage(base_damage * damage_modifier * damage_boost)
			print("Annadaeus: Fired Finale projectile at %s, direction=%s, damage_boost=%.2f" % [target.name, projectile.move_direction, damage_boost])
	else:
		print("Annadaeus: Failed to spawn Finale projectile, target=%s, bullet_pool=%s, muzzle=%s" % [target.name if target else "null", bullet_pool, muzzle])

func _spawn_decoy() -> void:
	# Spawn static duplicate of Annadaeus with 40 health
	var decoy = duplicate()
	decoy.is_decoy = true # Mark as decoy
	decoy.global_position = global_position
	decoy.current_health = 40
	decoy.max_health = 40
	if decoy.get_node_or_null("health_bar"):
		var decoy_health_bar = decoy.get_node("health_bar")
		decoy_health_bar.max_value = 40
		decoy_health_bar.value = 40
	decoy.set_process(false) # Disable AI logic
	decoy.set_physics_process(false) # Disable movement
	if decoy.get_node_or_null("CollisionShape2D"):
		decoy.get_node("CollisionShape2D").set_deferred("disabled", false) # Keep collision for damage
	get_tree().current_scene.add_child(decoy)
	# Add timer to despawn after 5 seconds
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
	print("Annadaeus: Spawned decoy at %s with 40 HP" % decoy.global_position)

# --- Utility ---
func _update_avoidance_ray(target: Node2D, range: float) -> void:
	# Update raycast for line-of-sight
	if avoidance_ray and target and is_instance_valid(target):
		avoidance_ray.target_position = (target.global_position - global_position).normalized() * range
		avoidance_ray.force_raycast_update()
	else:
		print("Annadaeus: Invalid avoidance ray or target for %s" % (target.name if target else "null"))

func _has_clear_line_to_target(target: Node2D) -> bool:
	# Check if there's a clear line to target
	if not avoidance_ray or not target or not is_instance_valid(target):
		print("Annadaeus: No clear line to target %s, invalid ray or target" % (target.name if target else "null"))
		return false
	if avoidance_ray.is_colliding() and avoidance_ray.get_collider() != target:
		print("Annadaeus: No clear line to target %s, blocked by %s" % [target.name, avoidance_ray.get_collider().name])
		return false
	return true

func _show_casting_text(ability_name: String) -> void:
	# Display ability casting text
	if casting_label and casting_timer:
		if casting_lines.has(ability_name):
			var lines = casting_lines[ability_name]
			var random_line = lines[randi() % lines.size()]
			casting_label.text = random_line
		else:
			casting_label.text = ability_name
		casting_timer.start()

func take_damage(damage: int, _projectile_instance) -> void:
	# Apply damage and update health
	current_health -= damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	if current_health <= 0:
		_die()
	else:
		_damage_flash()

func _damage_flash() -> void:
	# Flash sprite red on hit
	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.05).timeout
		sprite.modulate = Color.WHITE

func _die() -> void:
	# Handle death, queue_free for decoys
	if is_decoy:
		print("Annadaeus decoy died at %s!" % global_position)
		queue_free()
		return
	print("Annadaeus died!")
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		visible = false
		set_process(false)
		set_physics_process(false)
		if $CollisionShape2D and is_instance_valid($CollisionShape2D):
			$CollisionShape2D.set_deferred("disabled", true)

func _find_damaged_friendlies_in_range() -> Array[CharacterBody2D]:
	# Find friendlies in range with less than max health, including self
	var friendlies: Array[CharacterBody2D] = []
	for unit in get_tree().get_nodes_in_group("friendly") + get_tree().get_nodes_in_group("player"):
		if is_instance_valid(unit) and unit.has_method("get_health") and unit.has_method("get_max_health"):
			if unit.get_health() < unit.get_max_health():
				var distance = global_position.distance_to(unit.global_position)
				if distance < support_range or unit == self:
					friendlies.append(unit)
	return friendlies

func _find_friendlies_in_range() -> Array[CharacterBody2D]:
	# Find friendlies in range
	var friendlies: Array[CharacterBody2D] = []
	for unit in get_tree().get_nodes_in_group("friendly") + get_tree().get_nodes_in_group("player"):
		if unit != self and is_instance_valid(unit):
			var distance = global_position.distance_to(unit.global_position)
			if distance < support_range:
				friendlies.append(unit)
	return friendlies

func _find_closest_mob() -> CharacterBody2D:
	# Find closest enemy in range
	var closest_mob: CharacterBody2D = null
	var min_distance: float = support_range
	var enemy_count: int = 0
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob):
			enemy_count += 1
			var distance = global_position.distance_to(mob.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_mob = mob
	if closest_mob:
		print("Annadaeus: Found closest enemy %s at position %s, distance=%.2f" % [closest_mob.name, closest_mob.global_position, min_distance])
	else:
		print("Annadaeus: No enemies found within range %.2f, total enemies=%d" % [support_range, enemy_count])
	return closest_mob

func _is_critical_situation() -> bool:
	# Check for critical situation (more than 5 enemies or low player/Annadaeus HP)
	var enemy_count = 0
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and global_position.distance_to(mob.global_position) < support_range:
			enemy_count += 1
	var player_low_hp = player and is_instance_valid(player) and player.has_method("get_health") and player.get_health() < player.get_max_health() * 0.5
	var annadaeus_low_hp = current_health < max_health * 0.5
	print("Annadaeus: Checking critical situation: enemies=%d, player_hp=%s, annadaeus_hp=%d, is_critical=%s" % [
		enemy_count,
		player.get_health() if player and player.has_method("get_health") else "N/A",
		current_health,
		enemy_count > 5 or player_low_hp or annadaeus_low_hp
	])
	return enemy_count > 5 or player_low_hp or annadaeus_low_hp

func _move_wobble() -> void:
	# Apply wobble animation to sprite
	var rot: float = sin(Time.get_ticks_msec() / 100.0) * 2
	sprite.rotation_degrees = rot

func _update_flip_h() -> void:
	# Flip sprite based on movement or target
	var active_target = _get_active_target()
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false
	elif active_target:
		sprite.flip_h = global_position.direction_to(active_target.global_position).x > 0

func _get_active_target() -> CharacterBody2D:
	# Get current target (enemy or friendly)
	if current_target and is_instance_valid(current_target):
		return current_target
	if current_friendly_target and is_instance_valid(current_friendly_target):
		return current_friendly_target
	return null

func get_health() -> int:
	# Return current health
	return current_health

func get_max_health() -> int:
	# Return maximum health
	return max_health

func heal(amount: int) -> void:
	# Heal Annadaeus and update health bar
	current_health = clamp(current_health + amount, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	print("Annadaeus %s healed for %d - current_health = %d" % [name, amount, current_health])

func set_damage_modifier(modifier: float) -> void:
	# Set damage multiplier for courage aura
	damage_modifier = modifier
