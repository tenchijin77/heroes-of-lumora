# hezrou.gd - hezrou mob specific script (extends monsters.gd)
extends "res://Scripts/monsters.gd"

# hezrou mob specific script (extends monsters.gd)
## This script defines the hezrou enemy type, which is a powerful monster with a medium-speed, long-range attack and high health.

# --- Initialize hezrou-specific properties ---
func _ready() -> void:
	super._ready()
	max_speed = 55.0  # Average speed
	acceleration = 0.1
	drag = 0.1
	shoot_rate = 1.0  # Medium speed, powerful attacks
	shoot_range = 350.0  # Longer range
	max_health = 350  # Powerful
	collision_damage = 5  # Stronger melee
	current_health = max_health
	score_value = 300  # Sets monster's score value to 300
	# bullet_scene is already set in tscn to bile_spew.tscn

# --- Cast bile_spew projectile at target ---
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	
	if not bullet_pool or not muzzle or not target:
		push_warning("hezrou %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	
	var bile_spew: Area2D = bullet_pool.spawn()
	
	if bile_spew:
		bile_spew.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		bile_spew.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		bile_spew.owner_group = "monsters"
		bile_spew.launch(muzzle.global_position, bile_spew.move_direction)  # Call launch to play sound and activate
		print("hezrou %s: Cast bile_spew %s at %s, move_direction=%s, position=%s" % [name, bile_spew.name, target.name, bile_spew.move_direction, bile_spew.global_position])
	else:
		push_warning("hezrou %s: Failed to spawn bile_spew!" % name)

# --- Override process to fix sprite flip for hezrou's right-facing default sprite ---
func _process(delta: float) -> void:
	super._process(delta)
	
	if target:
		var local_target_direction: Vector2 = global_position.direction_to(target.global_position)
		sprite.flip_h = local_target_direction.x < 0  # Flip if target is left (face left), no flip if right (face right)
