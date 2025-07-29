# ghost.gd - ghost mob specific script (extends monsters.gd)

extends "res://Scripts/monsters.gd"

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
	

func _process(delta: float) -> void:
	super._process(delta)

	#if sprite:
	#	sprite.flip_h = player_direction.x < 0  # Inverted logic for right-facing sprite

func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not player:
		push_warning("Ghost %s: Cannot cast—missing bullet_pool, muzzle, or player!" % name)
		return
	var ghost_fire: Area2D = bullet_pool.spawn()
	
	if ghost_fire:
		ghost_fire.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(player.global_position)
		ghost_fire.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		ghost_fire.owner_group = "monsters"
		ghost_fire.launch(muzzle.global_position, ghost_fire.move_direction)  # Call launch to play sound and activate
		print("Ghost %s: Cast ghost_fire %s, move_direction=%s, position=%s" % [name, ghost_fire.name, ghost_fire.move_direction, ghost_fire.global_position])
	else:
		push_warning("Ghost %s: Failed to spawn ghost_fire!" % name)
