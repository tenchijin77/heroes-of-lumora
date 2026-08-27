# upgrade_store.gd - main-menu entry point: pick which class's permanent
# endless-mode upgrades to view/purchase (see class_upgrade.gd for the
# actual purchase page).
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
			_go_to_class("res://Scenes/woodstalker.tscn")
		elif focused_control == troubadour_button:
			_go_to_class("res://Scenes/troubadour.tscn")
		elif focused_control == arcanist_button:
			_go_to_class("res://Scenes/arcanist.tscn")
		elif focused_control == voidknight_button:
			_go_to_class("res://Scenes/voidknight_class.tscn")
		elif focused_control == gravecaller_button:
			_go_to_class("res://Scenes/gravecaller_class.tscn")
		elif focused_control == back_button:
			_on_back_button_pressed()

func _go_to_class(class_path: String) -> void:
	Global.viewing_upgrade_class = class_path
	get_tree().change_scene_to_file("res://Scenes/class_upgrade.tscn")

func _on_woodstalker_button_pressed() -> void:
	_go_to_class("res://Scenes/woodstalker.tscn")

func _on_troubadour_button_pressed() -> void:
	_go_to_class("res://Scenes/troubadour.tscn")

func _on_arcanist_button_pressed() -> void:
	_go_to_class("res://Scenes/arcanist.tscn")

func _on_voidknight_button_pressed() -> void:
	_go_to_class("res://Scenes/voidknight_class.tscn")

func _on_gravecaller_button_pressed() -> void:
	_go_to_class("res://Scenes/gravecaller_class.tscn")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
