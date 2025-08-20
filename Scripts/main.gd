# main.gd

extends Node2D

# Global light node for dynamic day-night veil
@onready var global_light: DirectionalLight2D = $DirectionalLight2D  # Assuming named DirectionalLight2D in main.tscn

# Process: Update world light based on TimeManager's chronomancy
func _process(delta: float) -> void:
	var time_str: String = TimeManager.get_time_string()  # Fetch "HH:MM" from global.gd
	var parts: Array = time_str.split(":")
	if parts.size() != 2:
		return  # Safeguard against malformed time
	
	var hour: String = parts[0].pad_zeros(2)  # Ensure "06" not "6"
	var minute: String = parts[1].pad_zeros(2)  # Ensure "00" format
	var full_time: String = hour + ":" + minute  # "HH:MM" for debug
	
	var target_energy: float = _calculate_light_energy(full_time)
	
	# Gradual transition: lerp current to target (0.01 for slow veil descent, tweak for pace)
	global_light.energy = lerp(global_light.energy, target_energy, 0.01)

# Calculate target energy based on time slots (reduction % to energy: 1.0 full light)
func _calculate_light_energy(time: String) -> float:
	if time >= "06:00" and time < "18:00":
		return 0.85  # Day: 15% reduction
	elif time >= "18:00" and time < "20:00":
		return 0.55  # Dusk: 45% reduction
	else:  # 20:00-06:00 Night, wrapping cycle
		return 0.3   # 70% reduction
