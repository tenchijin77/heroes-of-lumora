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
var godmode: bool = false
var killer_name: String = ""
var killer_weapon: String = ""
var guard_spawn_index: int = 0
var magi_spawn_index: int = 0

# Shop / scene-transition state preservation
var shop_purchase_counts: Dictionary = {"health": 0, "damage": 0, "speed": 0, "guard": 0, "magi": 0}

func _ready() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(1152, 648)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
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
						"lost_villagers": int(round(item.get("lost_villagers", 0.0))),
						"epitaph": item.get("epitaph", "")
					}
					high_scores.append(entry)
		file.close()
	else:
		# File doesn't exist yet - create default empty scores (first run)
		high_scores = []
		save_high_scores()  # Create the file with empty array

func save_high_scores() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var file: FileAccess = FileAccess.open("user://saves/high_scores.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(high_scores, "\t"))
		file.close()
	else:
		push_error("Global: Failed to save high_scores.json")

func add_high_score(score: int, initials: String, wave: int, coins: int, time_survived: float, saved_villagers: int, lost_villagers: int, epitaph: String = "") -> void:
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
		"lost_villagers": lost_villagers,
		"epitaph": epitaph
	}
	high_scores.append(entry)
	high_scores.sort_custom(func(a, b): return a.score > b.score)
	if high_scores.size() > 10:
		high_scores.resize(10)
	save_high_scores()

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
	godmode = false
	killer_name = ""
	killer_weapon = ""
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
	# Boss spawning itself is handled by final_boss_spawner.gd, which listens
	# for this same signal — keep this a single source of truth.

func increment_lost_villagers() -> void:
	lost_villagers += 1
	emit_signal("villagers_updated", saved_villagers, lost_villagers, total_villagers)

## Sayings for each monster, split into "melee" (no weapon known — plain
## contact damage) and "ranged" (the specific projectile that landed the
## killing blow, filled in via a single %s, e.g. "wizard" + "fireball").
static func generate_epitaph(killer: String, weapon: String = "") -> String:
	var templates: Dictionary = {
		"goblin": {
			"melee": [
				"cut down by a goblin — a most ignoble end",
				"bested by a creature half their size",
			],
			"ranged": [
				"felled by a goblin's grubby %s",
				"caught off guard by a hurled %s",
			],
		},
		"skeleton": {
			"melee": [
				"slain before their time by a skeleton",
				"rattled to death by an animated corpse",
				"reduced to bones by an agent of bones",
			],
			"ranged": [
				"perforated by a skeleton's thrown %s",
				"struck down by a rattling %s",
			],
		},
		"wizard": {
			"melee": [
				"outdueled by a wizard's arcane will",
				"overwhelmed by raw arcane power",
			],
			"ranged": [
				"incinerated by a wizard's %s",
				"reduced to ash by a wizard's %s",
				"consumed in a wizard's %s",
			],
		},
		"troll": {
			"melee": [
				"crushed underfoot by a troll's terrible bulk",
				"met the wrong end of a troll's club",
				"smashed flat — a troll's idea of a greeting",
			],
			"ranged": [
				"poisoned by a troll's %s",
				"brought low by a troll's noxious %s",
			],
		},
		"wraith": {
			"melee": [
				"their life force drained by a wraith",
				"frozen in their final step by a wraith's cold touch",
				"the wraith kept what little warmth remained",
			],
			"ranged": [
				"their essence siphoned by a wraith's %s",
				"drained hollow by a %s",
			],
		},
		"beholder": {
			"melee": [
				"gazed upon by something that gazed back",
				"the last thing they saw was an eye",
				"unmade by a beholder's many terrible eyes",
			],
			"ranged": [
				"unmade by a beholder's %s",
				"reduced to nothing by a %s",
			],
		},
		"lich": {
			"melee": [
				"outmatched in arcane matters by a lich",
				"turned to dust by forces they didn't understand",
			],
			"ranged": [
				"a lich's %s found its mark",
				"struck down by a lich's %s",
			],
		},
		"hezrou": {
			"melee": [
				"torn apart by a hezrou's claws",
				"a demon's prey — nothing more",
				"overwhelmed by demonic fury",
			],
			"ranged": [
				"dissolved by a hezrou's %s",
				"caught in a wave of %s",
			],
		},
		"ogre": {
			"melee": [
				"flattened by an ogre's unfortunate enthusiasm",
				"clubbed into the afterlife",
				"the ogre barely noticed",
			],
			"ranged": [
				"crushed by an ogre's hurled %s",
				"flattened by a thrown %s",
			],
		},
		"ghost": {
			"melee": [
				"frightened to death — technically",
				"haunted into the hereafter",
				"phased out of existence by a ghost",
			],
			"ranged": [
				"consumed by %s",
				"engulfed in a ghost's %s",
			],
		},
		"balrog": {
			"melee": [
				"they shall not pass — and didn't",
				"the balrog's flames left nothing behind",
			],
			"ranged": [
				"consumed in the balrog's %s",
				"engulfed by a wave of %s",
			],
		},
		"mh_orzath": {
			"melee": [
				"annihilated by Mh'Orzath, The Eternal Dark",
				"claimed by the darkness they came to oppose",
				"the old ones claimed another",
			],
			"ranged": [
				"torn apart by Mh'Orzath's %s",
				"unmade by the Eclipsed One's %s",
			],
		},
		"victory": {
			"melee": [
				"defeated Mh'Orzath and saved all of Lumora",
				"stood victorious where others fell",
				"the last light of Lumora, unextinguished",
				"defeated Mh'Orzath to become a hero of Lumora",
				"banished the Eclipsed One and brought dawn to Lumora",
			],
			"ranged": [],
		},
	}
	var pretty_weapon: String = weapon.replace("_", " ")
	if templates.has(killer):
		var bucket: Dictionary = templates[killer]
		var ranged_opts: Array = bucket["ranged"]
		if weapon != "" and not ranged_opts.is_empty():
			return ranged_opts[randi() % ranged_opts.size()] % pretty_weapon
		var melee_opts: Array = bucket["melee"]
		return melee_opts[randi() % melee_opts.size()]
	elif killer != "" and weapon != "":
		return "felled by a %s's %s" % [killer.replace("_", " "), pretty_weapon]
	elif killer != "":
		return "slain by a " + killer.replace("_", " ")
	else:
		return "their fate lost to the darkness"
