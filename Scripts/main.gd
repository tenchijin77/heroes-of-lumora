# main.gd

extends Node2D

# Global light node for dynamic day-night veil
@onready var global_light: DirectionalLight2D = $global_light  

# Process: Update world light based on TimeManager's chronomancy
func _process(delta: float) -> void:
	var time_str: String = TimeManager.get_time_string()  # Fetch "In-Game Time: HH:MM"
	var clean_time: String = time_str.trim_prefix("In-Game Time: ")  # Extract "HH:MM"
	var parts: PackedStringArray = clean_time.split(":")
	if parts.size() != 2:
		push_warning("main.gd: Invalid time format: " + time_str)
		return
	
	var hour: int = int(parts[0])
	var minute: int = int(parts[1])
	var time_of_day: String = "%02d:%02d" % [hour, minute]
	
	var target_energy: float = _calculate_light_energy(time_of_day)
	# Adjust for subtract mode: 0.0 is full light, higher values darken
	var subtract_energy: float = 1.0 - target_energy  # Invert to match subtract
	global_light.energy = lerp(global_light.energy, subtract_energy, 0.03 * delta)  # Faster transition

# Calculate target energy based on time slots (higher energy for darker subtract mode)
func _calculate_light_energy(time: String) -> float:
	if time >= "06:00" and time < "14:00":
		return 0.85  # Brightest: 06:00-14:00, light reduction (subtract = 0.85)
	elif time >= "14:01" and time < "17:00":
		return 0.5   # Dimmer: 14:01-17:00 (subtract = 0.5)
	elif time >= "17:01" and time < "20:00":
		return 0.3   # Darker: 17:01-20:00 (subtract = 0.3)
	else:  # 20:01-05:59 Night, wrapping cycle
		return 0.2   # Darkest: 20:01-05:59 (subtract = 0.1)
