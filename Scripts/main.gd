# main.gd
# Root script for main.tscn, initializes global UI after scene load.

extends Node2D

# Initialize UI labels in global after scene is ready
func _ready() -> void:
	#Global.init_ui_labels()
	add_child(load("res://Scenes/ui.tscn").instantiate())
