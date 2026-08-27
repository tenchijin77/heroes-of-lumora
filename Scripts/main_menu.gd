# main_menu.gd - handles main menu interactions
extends Control

@onready var menu_container: VBoxContainer = $menu_container
@onready var start_button: Button = $menu_container/start_button
@onready var skip_button: Button = $menu_container/skip_button
@onready var scores_button: Button = $menu_container/scores_button
@onready var quit_button: Button = $menu_container/quit_button
@onready var endless_button: Button = $menu_container/endless_button
@onready var credits_button: Button = $menu_container/credits_button
@onready var store_button: Button = $menu_container/store_button

func _ready() -> void:
	if not menu_container:
		push_error("MainMenu: menu_container is null!")
	if not start_button:
		push_error("MainMenu: start_button is null!")
	if not quit_button:
		push_error("MainMenu: quit_button is null!")
	Global.play_menu_music()
	if start_button:
		start_button.grab_focus()
	# Hide UI on main menu
	if Global and Global.has_node("UI"):
		Global.ui.visible = false

	# Endless mode + credits only unlock after the story campaign is beaten
	var unlocked: bool = Global.campaign_complete
	endless_button.disabled = not unlocked
	endless_button.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	credits_button.disabled = not unlocked
	credits_button.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	store_button.disabled = not unlocked
	store_button.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	endless_button.pressed.connect(_on_endless_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	store_button.pressed.connect(_on_store_button_pressed)

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
			elif focused_control == endless_button and not endless_button.disabled:
				_on_endless_button_pressed()
			elif focused_control == credits_button and not credits_button.disabled:
				_on_credits_button_pressed()
			elif focused_control == store_button and not store_button.disabled:
				_on_store_button_pressed()

func _on_start_button_pressed() -> void:
	Global.is_endless_mode = false
	Global.stop_menu_music()
	get_tree().change_scene_to_file("res://Scenes/intro_scene.tscn")

func _on_skip_button_pressed() -> void:
	Global.is_endless_mode = false
	Global.stop_menu_music()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_scores_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_over2.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_endless_button_pressed() -> void:
	Global.is_endless_mode = true
	get_tree().change_scene_to_file("res://Scenes/endless_level_select.tscn")

func _on_credits_button_pressed() -> void:
	Global.viewing_credits = true
	Global.stop_menu_music()
	get_tree().change_scene_to_file("res://Scenes/victory_scene.tscn")

func _on_store_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/upgrade_store.tscn")
