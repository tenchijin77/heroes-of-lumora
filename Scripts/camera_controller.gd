extends Camera2D

@onready var target = $"../player"
@export var follow_rate : float = 2.0

func _process (delta):
	global_position = global_position.lerp(target.global_position, follow_rate * delta)
