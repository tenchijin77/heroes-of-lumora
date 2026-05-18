# main.gd

extends Node2D

# Global light node for dynamic day-night veil
@onready var global_light: DirectionalLight2D = $global_light  

# Process: Update world light based on TimeManager's chronomancy
func _process(delta: float) -> void:
	var hour: float = TimeManager.current_time / 60.0
	# Sin curve peaks at noon (factor=1.0, full brightness) and troughs at midnight (factor=0.0, darkest)
	var sun_factor: float = (sin((hour - 6.0) / 24.0 * TAU) + 1.0) / 2.0
	# Subtract mode: 0.0 = no subtraction (full bright), 0.55 = moonlit night
	var target_subtract: float = lerp(0.55, 0.0, sun_factor)
	global_light.energy = lerp(global_light.energy, target_subtract, 0.05 * delta)
