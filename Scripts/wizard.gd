# wizard.gd - wizard mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

func _ready():
	super._ready()
	max_speed = 30.0
	acceleration = .2
	drag = 0.15
	shoot_rate = 0.4
	shoot_range = 200.0
	max_health = 25
	collision_damage = 3
	current_health = max_health
	# Override sprite region if not in tscn: sprite.region_rect = Rect2(640, 64, 32, 33)
	# bullet_scene already set in tscn to fireball.tscn

func _cast():
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not player:
		push_warning("Wizard %s: Cannot cast—missing bullet_pool, muzzle, or player!" % name)
		return
	var fireball = bullet_pool.spawn()
	if fireball:
		fireball.global_position = muzzle.global_position
		fireball.move_direction = muzzle.global_position.direction_to(player.global_position)
		fireball.owner_group = "monsters"  # Ensure owner_group for enemy
		print("Wizard %s: Cast fireball %s, move_direction=%s, position=%s" % [name, fireball.name, fireball.move_direction, fireball.global_position])
	else:
		push_warning("Wizard %s: Failed to spawn fireball!" % name)
