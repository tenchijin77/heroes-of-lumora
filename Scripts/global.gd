#global.gd - manages global game state, including high scores
extends Node

var high_scores : Array[Dictionary] = []
var current_score : int = 0

func _ready():
	DirAccess.make_dir_absolute("user://saves/")
	load_high_scores()

# Load high scores from user://saves/high_scores.json
func load_high_scores():
	var file = FileAccess.open("user://saves/high_scores.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			if json.data is Array:
				high_scores = []
				for item in json.data:
					if item is Dictionary and "score" in item and "initials" in item:
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
func save_high_scores():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
		print("Global: Created saves directory")
	var file = FileAccess.open("user://saves/high_scores.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(high_scores, "\t"))
		file.close()
	else:
		push_error("Global: Failed to save high_scores.json")

# Add a new score with initials, keeping top 10
func add_high_score(score: int, initials: String):
	if initials.length() > 3:
		initials = initials.substr(0, 3)
	if initials.length() == 0:
		initials = "AAA"
	var entry = {"score": score, "initials": initials.to_upper()}
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

# Reset game state on restart
func reset():
	current_score = 0
