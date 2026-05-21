#intro_scene.gd - controls the main dialog
extends Node

func _ready():
	await get_tree().process_frame
	DialogicManager.connect("timeline_ended", Callable(self, "_on_dialogue_finished"))
	DialogicManager.start_timeline("res://Dialogic/Timot-Intro.dtl")
	var dialog_node = DialogicManager.get_dialog_node()


func _on_dialogue_finished():
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
