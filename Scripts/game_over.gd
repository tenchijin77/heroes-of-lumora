#game_over.gd - handles game over screen and high score input
extends Control

@onready var leader_board : VBoxContainer = $leader_board
@onready var restart_button : Button = $restart_button

var current_score : int

func _ready():
	get_tree().paused = false  # Ensure unpaused


func _on_restart_button_pressed():
	Global.reset()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
