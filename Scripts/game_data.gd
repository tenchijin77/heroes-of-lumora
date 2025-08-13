# game_data.gd - handles information related to the villagers

extends Node

var villagers_data: Dictionary = {}

func _ready() -> void:
	_load_villagers_data()

# Load villagers.json
func _load_villagers_data() -> void:
	var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if file:
		var json_text: String = file.get_as_text()
		file.close()
		var json: JSON = JSON.new()
		var error: Error = json.parse(json_text)
		if error == OK:
			villagers_data = json.data
			if villagers_data.has("_comment"):
				villagers_data.erase("_comment")
			print("GameData: Loaded villagers.json successfully")
		else:
			push_error("GameData: Failed to parse villagers.json: %s" % json.get_error_message())
	else:
		push_error("GameData: Failed to open villagers.json")

# Get villager stats by type
func get_villager_stats(villager_type: String) -> Dictionary:
	if villagers_data.has(villager_type):
		return villagers_data[villager_type]
	push_warning("GameData: Villager type %s not found, using default stats" % villager_type)
	return {
		"max_health": 25.0,
		"move_speed": 40.0,
		"popup_message": "Help me!",
		"sprite_region": [135, 68, 20, 28]
	}
