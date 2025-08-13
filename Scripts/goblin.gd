# goblin.gd
# Goblin mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

# Initialize goblin-specific properties
func _ready() -> void:
	super._ready()
	max_speed = 42.0
	acceleration = 10.0
	drag = 0.9
	shoot_rate = 1.5
	shoot_range = 220.0
	max_health = 20
	collision_damage = 3
	current_health = max_health
	score_value = 20  # Sets monster's score value to 20
	# bullet_scene already set in tscn to dagger.tscn

# Cast dagger projectile at target
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Goblin %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	var dagger: Area2D = bullet_pool.spawn()

	if dagger:
		dagger.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		dagger.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		dagger.owner_group = "monsters"
		dagger.launch(muzzle.global_position, dagger.move_direction)  # Call launch to play sound and activate
		print("Goblin %s: Cast dagger %s at %s, move_direction=%s, position=%s" % [name, dagger.name, target.name, dagger.move_direction, dagger.global_position])
	else:
		push_warning("Goblin %s: Failed to spawn dagger!" % name)
