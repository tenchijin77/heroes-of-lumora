# ogre.gd
# Ogre mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

# Initialize ogre-specific properties
func _ready() -> void:
	super._ready()
	max_speed = 24.0  # Slow, heavy
	acceleration = 0.3
	drag = 0.2
	shoot_rate = 1.5  # Slower attacks
	shoot_range = 250.0  # Short range for heavy projectile
	max_health = 50  # Very tanky
	collision_damage = 6  # Strong melee
	current_health = max_health
	score_value = 35  # Sets monster's score value to 35
	# bullet_scene already set in tscn to ogre.tscn

# Cast ogre projectile at target
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Ogre %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	var boulder: Area2D = bullet_pool.spawn()

	if boulder:
		boulder.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		boulder.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		boulder.owner_group = "monsters"
		boulder.launch(muzzle.global_position, boulder.move_direction)  # Call launch to play sound and activate
		print("Ogre %s: Cast boulder %s at %s, move_direction=%s, position=%s" % [name, boulder.name, target.name, boulder.move_direction, boulder.global_position])
	else:
		push_warning("Ogre %s: Failed to spawn boulder!" % name)
