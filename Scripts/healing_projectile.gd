# healer_projectile.gd
extends "res://Scripts/projectile.gd"

@export var heal_amount: int = 4 # Adjust this value as needed

func _on_body_entered(body: Node) -> void:
	# We will bypass the `if body.is_in_group(owner_group)` check here
	# and instead check the group of the body it has collided with.
	
	if body.is_in_group("player") or body.is_in_group("friendly"):
		# The projectile has hit a friendly target.
		# Check if the body has a `heal` function before trying to call it.
		if body.has_method("heal"):
			body.heal(heal_amount)
			print("Healing projectile healed %s for %d" % [body.name, heal_amount])
			# Despawn the projectile after a successful heal.
			despawn()
	elif body.is_in_group("monsters"):
		# The projectile has hit an enemy target.
		# Check if the body has a `take_damage` function before trying to call it.
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Healing projectile dealt %d damage to %s" % [damage, body.name])
			# Despawn the projectile after a successful attack.
			despawn()
	else:
		# If it hits anything else (like the environment), it will despawn.
		# This prevents it from endlessly traveling.
		despawn()
