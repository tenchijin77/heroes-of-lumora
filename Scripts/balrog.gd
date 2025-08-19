# balrog.gd - Balrog mob specific script (extends monsters.gd)
extends "res://Scripts/monsters.gd"

# Balrog mob specific script (extends monsters.gd)
## This script defines the Balrog enemy type, which is a powerful monster with a medium-speed, long-range attack and high health.

# --- Initialize Balrog-specific properties ---
func _ready() -> void:
	super._ready()
	max_speed = 35.0  # Average speed
	acceleration = 0.1
	drag = 0.1
	shoot_rate = 1.0  # Medium speed, powerful attacks
	shoot_range = 350.0  # Longer range
	max_health = 300  # Powerful
	collision_damage = 5  # Stronger melee
	current_health = max_health
	score_value = 250  # Sets monster's score value to 250
	# bullet_scene is already set in tscn to malfire.tscn

# --- Cast malfire projectile at target ---
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	
	if not bullet_pool or not muzzle or not target:
		push_warning("Balrog %s: Cannot cast—missing bullet_pool, muzzle, or target!" % name)
		return
	
	var malfire: Area2D = bullet_pool.spawn()
	
	if malfire:
		malfire.global_position = muzzle.global_position
		var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
		malfire.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT  # Fallback to avoid zero vector
		malfire.owner_group = "monsters"
		malfire.launch(muzzle.global_position, malfire.move_direction)  # Call launch to play sound and activate
		print("Balrog %s: Cast malfire %s at %s, move_direction=%s, position=%s" % [name, malfire.name, target.name, malfire.move_direction, malfire.global_position])
	else:
		push_warning("Balrog %s: Failed to spawn malfire!" % name)

# --- Override process to fix sprite flip for Balrog's right-facing default sprite ---
func _process(delta: float) -> void:
	super._process(delta)
	
	if target:
		var local_target_direction: Vector2 = global_position.direction_to(target.global_position)
		sprite.flip_h = local_target_direction.x < 0  # Flip if target is left (face left), no flip if right (face right)
