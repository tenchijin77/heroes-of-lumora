# splash_screen.gd - Kuro Neko Sama Games studio splash before main menu
extends Control

const STUDIO_LOGO: Texture2D = preload("res://Assets/KNSG.png")

func _ready() -> void:
	_build_ui()
	_run_sequence()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var logo := TextureRect.new()
	logo.texture = STUDIO_LOGO
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(logo)

	modulate = Color(1.0, 1.0, 1.0, 0.0)

func _run_sequence() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(2.5)
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_go_to_menu)

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
