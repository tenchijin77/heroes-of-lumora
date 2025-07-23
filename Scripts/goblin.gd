# Goblin.gd - Goblin mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

func _ready():
	super._ready()
	max_speed = 42.0
	acceleration = 10.0
	drag = 0.9
	shoot_rate = 1.5
	shoot_range = 220.0
	max_health = 20
	collision_damage = 3
	current_health = max_health
	# Override sprite region if not in tscn: sprite.region_rect = Rect2(710, 262, 20, 26)
	# bullet_scene already set in tscn to axe.tscn

func _cast():
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not player:
		push_warning("Goblin %s: Cannot cast—missing bullet_pool, muzzle, or player!" % name)
		return
	var axe = bullet_pool.spawn()
	if axe:
		axe.global_position = muzzle.global_position
		axe.move_direction = muzzle.global_position.direction_to(player.global_position)
		axe.owner_group = "monsters"  # Ensure owner_group for enemy
		print("Goblin %s: Cast axe %s, move_direction=%s, position=%s" % [name, axe.name, axe.move_direction, axe.global_position])
	else:
		push_warning("Goblin %s: Failed to spawn axe!" % name)
