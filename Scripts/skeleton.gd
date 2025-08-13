# skeleton.gd
# Skeleton mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

# Initialize skeleton-specific properties
func _ready() -> void:
	super._ready()
	max_speed = 35.0
	acceleration = 10.0
	drag = 0.9
	shoot_rate = 1.5
	shoot_range = 150.0
	max_health = 15
	collision_damage = 3
	current_health = max_health
	score_value = 15  # Sets monster's score value to 15
	# Override sprite region if not in tscn: sprite.region_rect = Rect2(710, 262, 20, 26)
	# bullet_scene already set in tscn to bone.tscn

# Cast bone projectile at target
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Skeleton %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	var bone = bullet_pool.spawn()

	if bone:
		bone.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		bone.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		bone.owner_group = "monsters"
		bone.launch(muzzle.global_position, bone.move_direction)  # Call launch to play sound and activate
		print("Skeleton %s: Cast bone %s at %s, move_direction=%s, position=%s" % [name, bone.name, target.name, bone.move_direction, bone.global_position])
	else:
		push_warning("Skeleton %s: Failed to spawn bone!" % name)
