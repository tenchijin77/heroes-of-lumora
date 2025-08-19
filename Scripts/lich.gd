# lich.gd Lich mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

# Initialize lich-specific properties
func _ready() -> void:
	super._ready()
	max_speed = 25.0  # Slower, as lich is a powerful caster
	acceleration = 0.1
	drag = 0.1
	shoot_rate = 3.0 # Slow, Powerful attacks
	shoot_range = 250.0  # Longer range
	max_health = 45  # Tankier
	collision_damage = 5  # Stronger melee
	current_health = max_health
	score_value = 65  # Sets monster's score value to 65
	# bullet_scene already set in tscn to death_bolt.tscn

# Cast death_bolt projectile at target
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Lich %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	var death_bolt: Area2D = bullet_pool.spawn()

	if death_bolt:
		death_bolt.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		death_bolt.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		death_bolt.owner_group = "monsters"
		death_bolt.launch(muzzle.global_position, death_bolt.move_direction)  # Call launch to play sound and activate
		print("Lich %s: Cast death_bolt %s at %s, move_direction=%s, position=%s" % [name, death_bolt.name, target.name, death_bolt.move_direction, death_bolt.global_position])
	else:
		push_warning("Lich %s: Failed to spawn death_bolt!" % name)
