# ability_chest.gd - Enemy drop that unlocks the next Woodstalker spell.
# Used in endless mode (set ability_chest_drop_chance > 0 on monsters).
# In story campaign (main.tscn) spells are pre-unlocked; chests are unused.
extends Area2D

func _ready() -> void:
	add_to_group("ability_chest")
	collision_layer = 256  # Layer 9 — matches player pickup_area mask
	collision_mask = 0

	# Chest body
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-9, -5), Vector2(9, -5),
		Vector2(9, 6),   Vector2(-9, 6),
	])
	body.color = Color(0.75, 0.5, 0.15, 1.0)
	add_child(body)

	# Chest lid (slightly lighter)
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([
		Vector2(-9, -10), Vector2(9, -10),
		Vector2(9, -5),   Vector2(-9, -5),
	])
	lid.color = Color(0.95, 0.7, 0.25, 1.0)
	add_child(lid)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 16)
	col.shape = shape
	col.position = Vector2(0, -2)
	add_child(col)

	# Auto-despawn after 30 seconds
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func collect() -> void:
	queue_free()
