# ui_manager.gd
# Manages UI updates for labels in main.tscn.

extends CanvasLayer

@onready var score_label: Label = $VBoxContainer/score
@onready var uptime_label: Label = $VBoxContainer/uptime
@onready var wave_label: Label = $VBoxContainer/wave
@onready var coin_label: Label = $VBoxContainer/coins
@onready var saved_label: Label = $VBoxContainer/saved_villagers
@onready var lost_label: Label = $VBoxContainer/lost_villagers

func _ready() -> void:
	if not score_label or not uptime_label or not wave_label or not coin_label or not saved_label or not lost_label:
		push_error("UIManager: One or more labels not found")
		return
	Global.score_updated.connect(_on_score_updated)
	Global.coins_updated.connect(_on_coins_updated)
	Global.wave_updated.connect(_on_wave_updated)
	Global.time_updated.connect(_on_time_updated)
	Global.villagers_updated.connect(_on_villagers_updated)
	_on_score_updated(Global.current_score)
	_on_coins_updated(Global.coins_collected)
	_on_wave_updated(Global.current_wave)
	_on_time_updated(Global.format_time(Global.current_time_survived))
	_on_villagers_updated(Global.saved_villagers, Global.lost_villagers)

func _on_score_updated(score: int) -> void:
	score_label.text = "Score: %d" % score

func _on_coins_updated(coins: int) -> void:
	coin_label.text = "Coin: %d" % coins

func _on_wave_updated(wave: int) -> void:
	wave_label.text = "Wave: %d" % wave

func _on_time_updated(time: String) -> void:
	uptime_label.text = "Time: %s" % time

func _on_villagers_updated(saved: int, lost: int) -> void:
	saved_label.text = "Saved Villagers: %d" % saved
	lost_label.text = "Lost Villagers: %d" % lost
