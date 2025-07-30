#main_menu.gd - handles main menu interactions
extends Control

@onready var menu_container : VBoxContainer = $menu_container
@onready var start_button : Button = $menu_container/start_button
@onready var quit_button : Button = $menu_container/quit_button
@onready var background_music : AudioStreamPlayer = $background_music

func _ready():
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

func _on_start_button_pressed():
	#get_tree().change_scene_to_file("res://Scenes/main.tscn")
	get_tree().change_scene_to_file("res://Scenes/intro_scene.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
