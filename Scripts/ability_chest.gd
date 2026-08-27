# ability_chest.gd - Enemy drop that unlocks the next Woodstalker spell.
# Used in endless mode (set ability_chest_drop_chance > 0 on monsters).
# In story campaign (main.tscn) spells are pre-unlocked; chests are unused.
extends Area2D

func _ready() -> void:
	add_to_group("ability_chest")
	collision_layer = 256  # Layer 9 — matches player pickup_area mask
	collision_mask = 0

	# Auto-despawn after 30 seconds
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func collect() -> void:
	queue_free()
