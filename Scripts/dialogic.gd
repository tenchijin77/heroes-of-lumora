# dialogic.gd - your autoload wrapper
extends Node

signal timeline_ended # ✅ define this at the top

var dialogic_node: CanvasLayer = null # <--- CHANGE THIS LINE!

func start_timeline(timeline_path: String):
	if dialogic_node:
		dialogic_node.queue_free()

	dialogic_node = Dialogic.start(timeline_path) # This now returns a CanvasLayer

	# Set the process_mode on the CanvasLayer returned by Dialogic.start()
	# Using Node.PROCESS_MODE_ALWAYS for consistency and clarity (value is 2)
	dialogic_node.process_mode = Node.PROCESS_MODE_ALWAYS # <--- Use the correct enum access

	dialogic_node.connect("timeline_ended", Callable(self, "_on_timeline_ended"))

	get_tree().get_root().add_child(dialogic_node) # ✅ show it in the scene

func _on_timeline_ended():
	if dialogic_node:
		dialogic_node.queue_free()
		dialogic_node = null
	emit_signal("timeline_ended")
