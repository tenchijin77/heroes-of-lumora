# main_menu.gd - handles main menu interactions
extends Control

@onready var menu_container: VBoxContainer = $menu_container
@onready var start_button: Button = $menu_container/start_button
@onready var skip_button: Button = $menu_container/skip_button
@onready var scores_button: Button = $menu_container/scores_button
@onready var quit_button: Button = $menu_container/quit_button
@onready var background_music: AudioStreamPlayer = $background_music

func _ready() -> void:
	if not menu_container:
		push_error("MainMenu: menu_container is null!")
	if not start_button:
		push_error("MainMenu: start_button is null!")
	if not quit_button:
		push_error("MainMenu: quit_button is null!")
	if not background_music:
		push_error("MainMenu: background_music is null!")
	else:
		background_music.play()
		print("MainMenu: Playing background music")
	if start_button:
		start_button.grab_focus()
	# Hide UI on main menu
	if Global and Global.has_node("UI"):
		Global.ui.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var focused_control = get_viewport().gui_get_focus_owner()
		if focused_control:
			if focused_control == start_button:
				_on_start_button_pressed()
			elif focused_control == skip_button:
				_on_skip_button_pressed()
			elif focused_control == scores_button:
				_on_scores_button_pressed()
			elif focused_control == quit_button:
				_on_quit_button_pressed()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/intro_scene.tscn")

func _on_skip_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_scores_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_over2.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
