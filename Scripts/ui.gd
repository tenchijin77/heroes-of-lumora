# ui.gd - manages persistent UI elements across all scenes
extends CanvasLayer

@onready var wave_label: Label = $VBoxContainer/wave
@onready var uptime_label: Label = $VBoxContainer/uptime
@onready var score_label: Label = $VBoxContainer/score
@onready var coin_label: Label = $VBoxContainer/coins
@onready var saved_villagers_label: Label = $VBoxContainer/saved_villagers
@onready var lost_villagers_label: Label = $VBoxContainer/lost_villagers

func _ready() -> void:
	# Hide UI by default, show only for main scene
	visible = false
	# Update with initial values
	_update_all()
	Global.wave_updated.connect(_update_wave)
	Global.time_updated.connect(_update_time)
	Global.score_updated.connect(_update_score)
	Global.coins_updated.connect(_update_coins)
	Global.villagers_updated.connect(_update_villagers)
	_check_scene()

func _check_scene() -> void:
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "main":
		visible = true
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node.name == "main":
		visible = true
	elif node.name in ["main_menu", "intro_scene", "game_over2"]:
		visible = false

func _update_all() -> void:
	_update_wave(Global.current_wave)
	_update_time(Global.format_time(Global.current_time_survived))
	_update_score(Global.current_score)
	_update_coins(Global.coins_collected)
	_update_villagers(Global.saved_villagers, Global.lost_villagers)

func _update_wave(wave: int) -> void:
	wave_label.text = "Wave: %d" % wave

func _update_time(time: String) -> void:
	uptime_label.text = "Time: %s" % time

func _update_score(score: int) -> void:
	score_label.text = "Score: %d" % score

func _update_coins(coins: int) -> void:
	coin_label.text = "Coins: %d" % coins

func _update_villagers(saved: int, lost: int) -> void:
	saved_villagers_label.text = "Villagers Saved: %d" % saved
	lost_villagers_label.text = "Villagers Lost: %d" % lost
