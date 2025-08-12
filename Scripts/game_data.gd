# game_data.gd
# Singleton to manage game data, including villager stats from villagers.json.

extends Node

var villager_data: Dictionary = {}

func _ready() -> void:
	_load_villager_data()

# Load villager data from villagers.json
func _load_villager_data() -> void:
	var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if file:
		var json_result = JSON.parse_string(file.get_as_text())
		if json_result is Dictionary:
			villager_data = json_result
		else:
			print_debug("ERROR: Invalid JSON format in villagers.json")
		file.close()
	else:
		print_debug("ERROR: Failed to open villagers.json")
