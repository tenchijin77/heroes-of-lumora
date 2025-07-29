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


func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not player:
		push_warning("Goblin %s: Cannot cast—missing bullet_pool, muzzle, or player!" % name)
		return
	var dagger: Area2D = bullet_pool.spawn()
	
	if dagger:
		dagger.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(player.global_position)
		dagger.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		dagger.owner_group = "monsters"
		dagger.launch(muzzle.global_position, dagger.move_direction)  # Call launch to play sound and activate
		print("Goblin %s: Cast dagger %s, move_direction=%s, position=%s" % [name, dagger.name, dagger.move_direction, dagger.global_position])
	else:
		push_warning("Goblin %s: Failed to spawn dagger!" % name)
