#intro_scene.gd - controls the main dialog
extends Node

func _ready():
	DialogicManager.connect("timeline_ended", Callable(self, "_on_dialogue_finished"))
	DialogicManager.start_timeline("res://Dialogic/Timot-Intro.dtl")
	var dialog_node = DialogicManager.get_dialog_node()
	if dialog_node:
		for s in dialog_node.get_signal_list():
			print("Signal:", s.name)


func _on_dialogue_finished():
	print("Timeline ended!")
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
