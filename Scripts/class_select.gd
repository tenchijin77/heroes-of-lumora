# class_select.gd - lets the player pick which class to play in endless mode
extends Control

@onready var woodstalker_button: Button = $menu_container/woodstalker_button
@onready var troubadour_button: Button = $menu_container/troubadour_button
@onready var arcanist_button: Button = $menu_container/arcanist_button
@onready var voidknight_button: Button = $menu_container/voidknight_button
@onready var gravecaller_button: Button = $menu_container/gravecaller_button
@onready var back_button: Button = $menu_container/back_button

func _ready() -> void:
	Global.play_menu_music()
	woodstalker_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var focused_control = get_viewport().gui_get_focus_owner()
		if focused_control == woodstalker_button:
			_on_woodstalker_button_pressed()
		elif focused_control == troubadour_button:
			_on_troubadour_button_pressed()
		elif focused_control == arcanist_button:
			_on_arcanist_button_pressed()
		elif focused_control == voidknight_button:
			_on_voidknight_button_pressed()
		elif focused_control == gravecaller_button:
			_on_gravecaller_button_pressed()
		elif focused_control == back_button:
			_on_back_button_pressed()

func _on_woodstalker_button_pressed() -> void:
	Global.selected_class_scene = "res://Scenes/woodstalker.tscn"
	Global.stop_menu_music()
	get_tree().change_scene_to_file(Global.selected_endless_level)

func _on_troubadour_button_pressed() -> void:
	Global.selected_class_scene = "res://Scenes/troubadour.tscn"
	Global.stop_menu_music()
	get_tree().change_scene_to_file(Global.selected_endless_level)

func _on_arcanist_button_pressed() -> void:
	Global.selected_class_scene = "res://Scenes/arcanist.tscn"
	Global.stop_menu_music()
	get_tree().change_scene_to_file(Global.selected_endless_level)

func _on_voidknight_button_pressed() -> void:
	Global.selected_class_scene = "res://Scenes/voidknight_class.tscn"
	Global.stop_menu_music()
	get_tree().change_scene_to_file(Global.selected_endless_level)

func _on_gravecaller_button_pressed() -> void:
	Global.selected_class_scene = "res://Scenes/gravecaller_class.tscn"
	Global.stop_menu_music()
	get_tree().change_scene_to_file(Global.selected_endless_level)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/endless_level_select.tscn")
