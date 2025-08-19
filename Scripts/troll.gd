# troll.gd troll mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

# Initialize troll-specific properties
func _ready() -> void:
	super._ready()
	max_speed = 75.0  
	acceleration = 0.1
	drag = 0.1
	shoot_rate = 1.0 # Medium Speed, Powerful attacks
	shoot_range = 350.0  # Longer range
	max_health = 200  # Powerful
	collision_damage = 5  # Stronger melee
	current_health = max_health
	score_value = 250  # Sets monster's score value to 65
	# bullet_scene already set in tscn to poison_bolt.tscn

# Cast poison_bolt projectile at target
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Troll %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	var poison_bolt: Area2D = bullet_pool.spawn()

	if poison_bolt:
		poison_bolt.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		poison_bolt.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		poison_bolt.owner_group = "monsters"
		poison_bolt.launch(muzzle.global_position, poison_bolt.move_direction)  # Call launch to play sound and activate
		print("Troll %s: Cast poison_bolt %s at %s, move_direction=%s, position=%s" % [name, poison_bolt.name, target.name, poison_bolt.move_direction, poison_bolt.global_position])
	else:
		push_warning("Troll %s: Failed to spawn poison_bolt!" % name)
