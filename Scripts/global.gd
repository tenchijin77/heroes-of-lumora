#global.gd - manages global game state, including high scores
extends Node

var high_scores : Array[Dictionary] = []

func _ready():
	load_high_scores()

# Load high scores from user://saves/high_scores.json
func load_high_scores():
	var file = FileAccess.open("user://saves/high_scores.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK and json.data is Array:
			high_scores = json.data
		else:
			print("Global: Failed to parse high_scores.json, initializing empty list")
			high_scores = []
		file.close()
	else:
		print("Global: No high_scores.json found, initializing empty list")
		high_scores = []

# Save high scores to user://saves/high_scores.json
func save_high_scores():
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
	print("Global: Added high score - %s: %d" % [initials, score])

# Check if score qualifies for top 10
func is_high_score(score: int) -> bool:
	if high_scores.size() < 10:
		return true
	return score > high_scores[-1].score
