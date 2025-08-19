# wraith.gd Wraith mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

# Initialize wraith-specific properties
func _ready() -> void:
	super._ready()
	max_speed = 55.0  
	acceleration = 0.1
	drag = 0.1
	shoot_rate = 1.0 # Medium Speed, Powerful attacks
	shoot_range = 350.0  # Longer range
	max_health = 350  # Powerful
	collision_damage = 5  # Stronger melee
	current_health = max_health
	score_value = 300  # Sets monster's score value to 65
	# bullet_scene already set in tscn to lifedrain.tscn

# Cast lifedrain projectile at target
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Wraith %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	var lifedrain: Area2D = bullet_pool.spawn()

	if lifedrain:
		lifedrain.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		lifedrain.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		lifedrain.owner_group = "monsters"
		lifedrain.launch(muzzle.global_position, lifedrain.move_direction)  # Call launch to play sound and activate
		print("Wraith %s: Cast lifedrain %s at %s, move_direction=%s, position=%s" % [name, lifedrain.name, target.name, lifedrain.move_direction, lifedrain.global_position])
	else:
		push_warning("Wraith %s: Failed to spawn lifedrain!" % name)
