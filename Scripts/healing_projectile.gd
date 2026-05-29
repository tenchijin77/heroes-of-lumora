# healing_projectile.gd - used by priestess to heal or hurt
extends "res://Scripts/projectile.gd"

@export var heal_amount: int = 8

func _ready() -> void:
	# `is_connected` and `connect` is now more robust.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.is_in_group("friendly"):
		if body.has_method("heal"):
			body.heal(heal_amount)
		despawn()
	elif body.is_in_group("monsters"):
		if body.has_method("take_damage"):
			body.take_damage(damage, self)
		despawn()
	else:
		despawn()
