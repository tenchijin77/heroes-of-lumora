#intro_scene.gd - controls the main dialog
extends Node

func _ready():
	DialogicManager.connect("timeline_ended", Callable(self, "_on_dialogue_finished"))
	DialogicManager.start_timeline("res://Dialogic/Timot-Intro.dtl")

func _on_dialogue_finished():
	print("Timeline ended!")
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
