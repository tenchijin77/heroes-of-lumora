# healing_aura.gd - healer's aura logic
extends Area2D

@export var heal_amount: int = 4
@export var heal_interval: float = 3.0
@export var target_groups: Array[String] = ["healer", "friendly", "player"]
@onready var heal_aura_timer: Timer = $heal_aura_timer
@onready var aura_particles: Node2D = $aura_particles

func _ready():
	heal_aura_timer.wait_time = heal_interval
	heal_aura_timer.timeout.connect(_on_heal_tick)
	heal_aura_timer.start()

func _on_heal_tick():
	var bodies = get_overlapping_bodies()
	for body in bodies:
		for group in target_groups:
			if body.is_in_group(group) and body.has_method("heal"):
				body.heal(heal_amount)
				print("HealingAura: Healed %s for %d" % [body.name, heal_amount])
				break
	if aura_particles and aura_particles.has_method("restart"):
		aura_particles.restart()
