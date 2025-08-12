# wizard.gd
# Wizard mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

# Initialize wizard-specific properties
func _ready() -> void:
	super._ready()
	max_speed = 30.0
	acceleration = 0.2
	drag = 0.15
	shoot_rate = 0.4
	shoot_range = 200.0
	max_health = 25
	collision_damage = 3
	current_health = max_health
	# Override sprite region if not in tscn: sprite.region_rect = Rect2(640, 64, 32, 33)
	# bullet_scene already set in tscn to fireball.tscn

# Cast fireball projectile at target
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		push_warning("Wizard %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	var fireball: Area2D = bullet_pool.spawn()
	
	if fireball:
		fireball.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		fireball.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		fireball.owner_group = "monsters"
		fireball.launch(muzzle.global_position, fireball.move_direction)  # Call launch to play sound and activate
		print("Wizard %s: Cast fireball %s at %s, move_direction=%s, position=%s" % [name, fireball.name, target.name, fireball.move_direction, fireball.global_position])
	else:
		push_warning("Wizard %s: Failed to spawn fireball!" % name)
