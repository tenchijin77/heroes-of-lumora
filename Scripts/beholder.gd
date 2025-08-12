# beholder.gd
# Beholder mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

# Initialize beholder-specific properties
func _ready() -> void:
	super._ready()
	max_speed = 20.0  # Very slow, floating
	acceleration = 0.05
	drag = 0.05
	shoot_rate = 4.0  # Slow attack speed
	shoot_range = 300.0  # Long range for ray
	max_health = 50  # Very tanky
	collision_damage = 4
	current_health = max_health
	# bullet_scene already set in tscn to disintegration_ray.tscn

# Cast disintegration_ray projectile at target
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Beholder %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	var disintegration_ray: Area2D = bullet_pool.spawn()
	
	if disintegration_ray:
		disintegration_ray.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		disintegration_ray.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		disintegration_ray.owner_group = "monsters"
		disintegration_ray.launch(muzzle.global_position, disintegration_ray.move_direction)  # Call launch to play sound and activate
		print("Beholder %s: Cast disintegration_ray %s at %s, move_direction=%s, position=%s" % [name, disintegration_ray.name, target.name, disintegration_ray.move_direction, disintegration_ray.global_position])
	else:
		push_warning("Beholder %s: Failed to spawn disintegration_ray!" % name)
