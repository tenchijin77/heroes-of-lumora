# main.gd
# Root script for main.tscn, initializes global UI and manages lighting.

extends Node2D

@onready var global_light : DirectionalLight2D = $global_light

func _ready() -> void:
	add_child(load("res://Scenes/ui.tscn").instantiate())
	TimeManager.connect("time_updated", _on_time_updated)

func _on_time_updated(current_time: float) -> void:
	var hour: int = TimeManager.get_hour()

	# Adjust subtractive lighting based on time
	if hour >= 6 and hour <= 18:
		# Daytime: reduce subtractive darkness
		global_light.energy = lerp(0.8, 0.2, float(hour - 6) / 12.0)
	else:
		# Nighttime: increase subtractive darkness
		global_light.energy = 0.8
