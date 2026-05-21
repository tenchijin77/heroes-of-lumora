# global.gd - manages global game state and emits signals for UI updates
extends Node

# Signals
signal villagers_updated(saved: int, lost: int, total: int)
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
var total_villagers: int = 50
var game_active: bool = true
var boss_fight_active: bool = false
var _boss_triggered: bool = false
var guard_spawn_index: int = 0
var magi_spawn_index: int = 0

# Shop / scene-transition state preservation
var shop_purchase_counts: Dictionary = {"health": 0, "damage": 0, "speed": 0, "guard": 0, "magi": 0}

func _ready() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.content_scale_size = Vector2i(1152, 648)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	print("Global: window size=%s scale_mode=%d scale_size=%s" % [window.size, window.content_scale_mode, window.content_scale_size])
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
		file.close()
	else:
		# File doesn't exist yet - create default empty scores (first run)
		high_scores = []
		print("Global: high_scores.json not found (first run), creating default file")
		save_high_scores()  # Create the file with empty array

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
	total_villagers = 50
	game_active = true
	boss_fight_active = false
	_boss_triggered = false
	guard_spawn_index = 0
	magi_spawn_index = 0
	shop_purchase_counts = {"health": 0, "damage": 0, "speed": 0, "guard": 0, "magi": 0}
	emit_signal("score_updated", current_score)
	emit_signal("coins_updated", coins_collected)
	emit_signal("wave_updated", current_wave)
	emit_signal("time_updated", format_time(current_time_survived))
	emit_signal("villagers_updated", saved_villagers, lost_villagers, total_villagers)

func increment_wave() -> void:
	current_wave += 1
	emit_signal("wave_updated", current_wave)

func increment_saved_villagers() -> void:
	saved_villagers += 1
	emit_signal("villagers_updated", saved_villagers, lost_villagers, total_villagers)
	if saved_villagers >= total_villagers and not _boss_triggered and not boss_fight_active:
		_boss_triggered = true
		_start_boss_sequence()

func increment_lost_villagers() -> void:
	lost_villagers += 1
	emit_signal("villagers_updated", saved_villagers, lost_villagers, total_villagers)

func _start_boss_sequence() -> void:
	boss_fight_active = true
	for spawner in get_tree().get_nodes_in_group("villager_spawner"):
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob):
			mob.queue_free()
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("show_announcement"):
		ui.show_announcement("50 Villagers Saved!\nMh'orzath awakens...", 4.0)
	if ui and ui.has_method("chat_add"):
		ui.chat_add("The darkness recoils... something far worse stirs.", "System")
	print("Global: Win condition met — boss sequence begins")
	await get_tree().create_timer(3.5).timeout
	if not game_active:
		return
	_spawn_boss()

func _spawn_boss() -> void:
	var boss_scene: PackedScene = load("res://Scenes/mh_orzath.tscn")
	if not boss_scene:
		push_error("Global: Could not load mh_orzath.tscn!")
		return
	var boss: Node2D = boss_scene.instantiate() as Node2D
	boss.global_position = _get_boss_spawn_position()
	get_tree().current_scene.add_child(boss)
	if boss.has_signal("mob_died"):
		boss.mob_died.connect(_on_boss_died)
	print("Global: Mh'orzath has entered the world at %s!" % boss.global_position)

func _get_boss_spawn_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	var base: Vector2 = player.global_position if player and is_instance_valid(player) else Vector2(600.0, 400.0)
	var viewport_rect := get_viewport().get_visible_rect()
	return base + Vector2(0.0, -(viewport_rect.size.y * 0.5 + 200.0))

func _on_boss_died() -> void:
	game_active = false
	var ui := get_node_or_null("/root/UI")
	if ui:
		ui.visible = false
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/victory_scene.tscn")
