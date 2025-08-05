# healing_projectile.gd - used by priestess to heal or hurt
extends "res://Scripts/projectile.gd"

@export var heal_amount: int = 4

func _ready() -> void:
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	print("🟢 healing_projectile.gd _on_body_entered called: hit %s from group %s" % [body.name, owner_group])

	if body.is_in_group("player") or body.is_in_group("friendly"):
		if body.has_method("heal"):
			body.heal(heal_amount)
			print("Healing projectile healed %s for %d" % [body.name, heal_amount])
			despawn()
	elif body.is_in_group("monsters"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Healing projectile dealt %d damage to %s" % [damage, body.name])
			despawn()
	else:
		despawn()
