# global.gd - manages global game state, including high scores
extends Node

var high_scores: Array[Dictionary] = []
var current_score: int = 0
var current_wave: int = 1
var coins_collected: int = 0
var current_time_survived: float = 0.0

func _ready():
	DirAccess.make_dir_absolute("user://saves/")
	load_high_scores()

# Load high scores from user://saves/high_scores.json
func load_high_scores() -> void:
	var file: FileAccess = FileAccess.open("user://saves/high_scores.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		var error: int = json.parse(file.get_as_text())
		if error == OK:
			if json.data is Array:
				high_scores = []
				for item in json.data:
					if item is Dictionary and "score" in item and "initials" in item:
						item["wave"] = item.get("wave", 0)
						item["coins"] = item.get("coins", 0)
						item["time_survived"] = item.get("time_survived", 0.0)
						high_scores.append(item)
			else:
				print("Global: high_scores.json is not an array, initializing empty list")
				high_scores = []
		else:
			print("Global: Failed to parse high_scores.json, error code: " + str(error))
			high_scores = []
		file.close()
	else:
		print("Global: No high_scores.json found, initializing empty list")
		high_scores = []

# Save high scores to user://saves/high_scores.json
func save_high_scores() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
		print("Global: Created saves directory")
	var file: FileAccess = FileAccess.open("user://saves/high_scores.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(high_scores, "\t"))
		file.close()
	else:
		push_error("Global: Failed to save high_scores.json")

# Add a new score with initials, wave, coins, and time survived, keeping top 10
func add_high_score(score: int, initials: String, wave: int, coins: int, time_survived: float) -> void:
	if initials.length() > 3:
		initials = initials.substr(0, 3)
	if initials.length() == 0:
		initials = "AAA"
	var entry: Dictionary = {
		"score": score,
		"initials": initials.to_upper(),
		"wave": wave,
		"coins": coins,
		"time_survived": time_survived
	}
	high_scores.append(entry)
	high_scores.sort_custom(func(a, b): return a.score > b.score)
	if high_scores.size() > 10:
		high_scores.resize(10)
	save_high_scores()

# Check if score qualifies for top 10
func is_high_score(score: int) -> bool:
	if high_scores.size() < 10:
		return true
	return score > high_scores[-1].score

# Format time in seconds to MM:SS for display
func format_time(seconds: float) -> String:
	var minutes: int = int(seconds / 60)
	var secs: int = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

# Reset game state on restart
func reset() -> void:
	current_score = 0
	current_wave = 1
	coins_collected = 0
	current_time_survived = 0.0
