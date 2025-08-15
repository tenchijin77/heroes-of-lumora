# global.gd - manages global game state and emits signals for UI updates
extends Node

# Signals
signal villagers_updated(saved: int, lost: int, total: int)  # Modified to include total
signal score_updated(score: int)
signal coins_updated(coins: int)
signal wave_updated(wave: int)
signal time_updated(time: String)

var high_scores: Array[Dictionary] = []
var current_score: int = 0
var current_wave: int = 1
var coins_collected: int = 0
var current_time_survived: float = 0.0
var saved_villagers: int = 0
var lost_villagers: int = 0
var total_villagers: int = 100  # Added for total villager count
var game_active: bool = true

func _ready() -> void:
	DirAccess.make_dir_absolute("user://saves/")
	load_high_scores()

func _process(delta: float) -> void:
	if game_active:
		current_time_survived += delta
		emit_signal("time_updated", format_time(current_time_survived))

func load_high_scores() -> void:
	var file: FileAccess = FileAccess.open("user://saves/high_scores.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data is Array:
			high_scores = []
			for item in json_data:
				if item is Dictionary:
					var entry: Dictionary = {
						"score": int(round(item.get("score", 0.0))),
						"initials": item.get("initials", "AAA").to_upper(),
						"wave": int(round(item.get("wave", 0.0))),
						"coins": int(round(item.get("coins", 0.0))),
						"time_survived": float(item.get("time_survived", 0.0)),
						"saved_villagers": int(round(item.get("saved_villagers", 0.0))),
						"lost_villagers": int(round(item.get("lost_villagers", 0.0)))
					}
					high_scores.append(entry)
		if OS.has_feature("editor"):
			print("Global: Loaded high scores: %s" % JSON.stringify(high_scores))
	else:
		high_scores = []
		if OS.has_feature("editor"):
			print("Global: No valid high scores data, initialized empty array")
	file.close()

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

func add_high_score(score: int, initials: String, wave: int, coins: int, time_survived: float, saved_villagers: int, lost_villagers: int) -> void:
	if initials.length() > 3:
		initials = initials.substr(0, 3)
	if initials.length() == 0:
		initials = "AAA"
	var entry: Dictionary = {
		"score": score,
		"initials": initials.to_upper(),
		"wave": wave,
		"coins": coins,
		"time_survived": time_survived,
		"saved_villagers": saved_villagers,
		"lost_villagers": lost_villagers
	}
	high_scores.append(entry)
	high_scores.sort_custom(func(a, b): return a.score > b.score)
	if high_scores.size() > 10:
		high_scores.resize(10)
	save_high_scores()
	if OS.has_feature("editor"):
		print("Global: Added high score entry: %s" % entry)

func is_high_score(score: int) -> bool:
	if high_scores.size() < 10:
		return true
	return score > high_scores[-1].score

func format_time(seconds: float) -> String:
	var minutes: int = int(seconds / 60)
	var secs: int = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func reset() -> void:
	current_score = 0
	current_wave = 1
	coins_collected = 0
	current_time_survived = 0.0
	saved_villagers = 0
	lost_villagers = 0
	total_villagers = 100  # Reset total villagers
	game_active = true
	emit_signal("score_updated", current_score)
	emit_signal("coins_updated", coins_collected)
	emit_signal("wave_updated", current_wave)
	emit_signal("time_updated", format_time(current_time_survived))
	emit_signal("villagers_updated", saved_villagers, lost_villagers, total_villagers)

# Public functions for other scripts to use
func increment_wave() -> void:
	current_wave += 1
	emit_signal("wave_updated", current_wave)

func increment_saved_villagers() -> void:
	saved_villagers += 1
	emit_signal("villagers_updated", saved_villagers, lost_villagers, total_villagers)

func increment_lost_villagers() -> void:
	lost_villagers += 1
	emit_signal("villagers_updated", saved_villagers, lost_villagers, total_villagers)
