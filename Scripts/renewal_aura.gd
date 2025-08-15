# renewal_aura.gd - A temporary aura for Annadaeus's Song of Renewal
extends Area2D

@export var heal_amount: int = 4
@export var heal_interval: float = 3.0
@export var buff_strength: float = 1.2 # 20% damage increase
@export var buff_duration: float = 10.0
@export var aura_duration: float = 8.0 # How long the aura exists
@export var target_groups: Array[String] = ["friendly", "player", "healer"]

@onready var despawn_timer: Timer = $despawn_timer

func _ready():
	# Timer to remove the aura after its total duration
	if despawn_timer:
		despawn_timer.wait_time = aura_duration
		despawn_timer.one_shot = true
		despawn_timer.timeout.connect(despawn)
		despawn_timer.start()

func _on_body_entered(body: Node) -> void:
	_apply_effect_to_body(body)

func _on_body_exited(body: Node) -> void:
	# Optional: logic to remove buff when body exits the area
	pass

func _apply_effect_to_body(body: Node):
	for group in target_groups:
		if body.is_in_group(group):
			# Apply healing effect
			if body.has_method("heal"):
				body.heal(heal_amount)
				
			# Apply buff effect (requires `apply_buff` method on target)
			if body.has_method("apply_buff"):
				body.apply_buff(buff_strength, buff_duration)
			break

func despawn():
	# Safely remove the aura from the scene
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		queue_free()
