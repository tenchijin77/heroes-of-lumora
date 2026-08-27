# endless_level_select.gd - lets the player pick which endless-mode level to play
extends Control

@onready var lumora_button: Button = $menu_container/lumora_button
@onready var back_button: Button = $menu_container/back_button

func _ready() -> void:
	Global.play_menu_music()
	lumora_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var focused_control = get_viewport().gui_get_focus_owner()
		if focused_control == lumora_button:
			_on_lumora_button_pressed()
		elif focused_control == back_button:
			_on_back_button_pressed()

func _on_lumora_button_pressed() -> void:
	Global.selected_endless_level = "res://Scenes/lumora_outskirts.tscn"
	get_tree().change_scene_to_file("res://Scenes/class_select.tscn")

func _on_back_button_pressed() -> void:
	Global.is_endless_mode = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
