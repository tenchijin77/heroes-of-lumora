# global.gd
# Manages global game state (scores, coins, waves, time, villagers) and in-game UI updates for labels in main.tscn.

extends Node

signal villagers_updated(saved: int, lost: int)  # Signal for villager UI updates
signal score_updated(score: int)  # Signal for score UI updates
signal coins_updated(coins: int)  # Signal for coin UI updates
signal wave_updated(wave: int)  # Signal for wave UI updates
signal time_updated(time: String)  # Signal for time survived UI updates

var high_scores: Array[Dictionary] = []
var current_score: int = 0
var current_wave: int = 1
var coins_collected: int = 0
var current_time_survived: float = 0.0
var saved_villagers: int = 0 # Track villagers that reached extraction points
var lost_villagers: int = 0 # Track villagers killed by monsters
var game_active: bool = true # Flag to control time updates (stop on game over)

# UI References (set in init_ui_labels after scene load)
var score_label: Label
var uptime_label: Label
var wave_label: Label
var coin_label: Label
var saved_label: Label
var lost_label: Label

# Initialize game state and load high scores
func _ready() -> void:
	DirAccess.make_dir_absolute("user://saves/")
	load_high_scores()
	# Connect signals to UI update functions
	score_updated.connect(_on_score_updated)
	coins_updated.connect(_on_coins_updated)
	wave_updated.connect(_on_wave_updated)
	time_updated.connect(_on_time_updated)
	villagers_updated.connect(_on_villagers_updated)

# Bind UI labels and initialize values (called from main.gd _ready)
func init_ui_labels() -> void:
	score_label = get_node("/root/main/CanvasLayer/VBoxContainer/score")
	uptime_label = get_node("/root/main/CanvasLayer/VBoxContainer/uptime")
	wave_label = get_node("/root/main/CanvasLayer/VBoxContainer/wave")
	coin_label = get_node("/root/main/CanvasLayer/VBoxContainer/coins")
	saved_label = get_node("/root/main/CanvasLayer/VBoxContainer/saved_villagers")
	lost_label = get_node("/root/main/CanvasLayer/VBoxContainer/lost_villagers")
	if not score_label or not uptime_label or not wave_label or not coin_label or not saved_label or not lost_label:
		push_error("Global: One or more UI labels not found—check paths in main.tscn")
		return
	# Initialize UI with current values
	_on_score_updated(current_score)
	_on_coins_updated(coins_collected)
	_on_wave_updated(current_wave)
	_on_time_updated(format_time(current_time_survived))
	_on_villagers_updated(saved_villagers, lost_villagers)

# Update time only if game is active
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
	else:
		high_scores = []
		if OS.has_feature("editor"):
			print("Global: No high_scores.json found, initialized empty array")

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

# Add a new score with initials, wave, coins, villagers, and time survived, keeping top 10
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
	saved_villagers = 0
	lost_villagers = 0
	game_active = true # Reset flag for new game
	emit_signal("score_updated", current_score)
	emit_signal("coins_updated", coins_collected)
	emit_signal("wave_updated", current_wave)
	emit_signal("time_updated", format_time(current_time_survived))
	emit_signal("villagers_updated", saved_villagers, lost_villagers)

# UI Update Functions
func _on_score_updated(score: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % score

func _on_coins_updated(coins: int) -> void:
	if coin_label:
		coin_label.text = "Coin: %d" % coins

func _on_wave_updated(wave: int) -> void:
	if wave_label:
		wave_label.text = "Wave: %d" % wave

func _on_time_updated(time: String) -> void:
	if uptime_label:
		uptime_label.text = "Time: %s" % time

func _on_villagers_updated(saved: int, lost: int) -> void:
	if saved_label:
		saved_label.text = "Saved Villagers: %d" % saved
	if lost_label:
		lost_label.text = "Lost Villagers: %d" % lost
