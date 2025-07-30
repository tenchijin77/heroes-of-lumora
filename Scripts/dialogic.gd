# dialogic.gd - your autoload wrapper (named DialogicManager in your project settings)
extends Node

signal timeline_ended # ✅ define this at the top

# We'll use this to hold a reference to the active Dialogic CanvasLayer
# if we successfully find it.
var _current_dialog_canvas_layer: CanvasLayer = null

func _ready():
	# Connect to the primary Dialogic signals that *are* consistently available.
	# timeline_ended is definitely there.
	# This connects your wrapper's _on_official_timeline_ended to Dialogic's own timeline_ended signal.
	Dialogic.timeline_ended.connect(Callable(self, "_on_official_timeline_ended"))

	# We cannot directly connect to 'dialog_started' on 'Dialogic' in Alpha 16 as confirmed by errors.
	# We will find the node after starting the timeline instead.

func start_timeline(timeline_path: String):
	# Clean up any previous reference to ensure we don't have stale data
	if _current_dialog_canvas_layer and is_instance_valid(_current_dialog_canvas_layer):
		# It's usually best to let Dialogic manage its own node's lifecycle.
		# However, if you're manually trying to force cleanup, you could uncomment this.
		# Be cautious, as it might interfere with Dialogic's internal state.
		#_current_dialog_canvas_layer.queue_free()
		_current_dialog_canvas_layer = null # Clear the reference to any old dialog

	# Start the Dialogic timeline. Dialogic handles creating and adding its scene to the tree.
	Dialogic.start(timeline_path)

	# Because Dialogic adds its scene to the tree, it might not be
	# immediately available on the same frame.
	# We yield for a single frame to ensure the node has been processed and added.
	await get_tree().process_frame

	# Now, try to find the actual Dialogic CanvasLayer node in the scene tree.
	# This is a workaround due to the lack of direct API access in your alpha version.
	_current_dialog_canvas_layer = find_dialogic_canvas_layer() # This is likely Line 41.

	if _current_dialog_canvas_layer:
		print("Found Dialogic CanvasLayer after start! Setting process_mode.")
		# Set the process_mode on the main CanvasLayer of the dialog.
		_current_dialog_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS

		# Get the actual DialogNode child from the CanvasLayer.
		# "DialogNode" is the default name, but it could vary in alpha versions.
		var actual_dialog_node = _current_dialog_canvas_layer.get_node_or_null("DialogNode")

		if actual_dialog_node:
			print("Found DialogNode child.")
			# Example: Connecting to a 'text_finished' signal if it exists on DialogNode.
			# Signals like text_finished are emitted by the DialogNode itself.
			if actual_dialog_node.has_signal("text_finished"):
				actual_dialog_node.text_finished.connect(Callable(self, "_on_dialog_node_text_finished"))
				print("Connected to text_finished on DialogNode.")
			else:
				print("DialogNode does not have 'text_finished' signal (or name changed in this alpha).")

			# Add other connections here for specific DialogNode signals if needed:
			# if actual_dialog_node.has_signal("character_spoken"):
			#    actual_dialog_node.character_spoken.connect(Callable(self, "_on_dialog_node_character_spoken"))
			# if actual_dialog_node.has_signal("choice_made"):
			#    actual_dialog_node.choice_made.connect(Callable(self, "_on_dialog_node_choice_made"))
		else:
			printerr("ERROR: Could not find 'DialogNode' child within the Dialogic CanvasLayer. This might mean the node name is different or its internal structure changed in your alpha version.")
	else:
		printerr("ERROR: Could not find Dialogic CanvasLayer after starting timeline! Dialogic might not have added its scene yet or its structure is unexpected in your alpha version.")


func _on_official_timeline_ended():
	# This function is called when the *official* Dialogic timeline_ended signal fires.
	print("Official Dialogic timeline ended. Emitting wrapper's signal.")
	# Clear the reference to the old dialog node once it's ended.
	if _current_dialog_canvas_layer and is_instance_valid(_current_dialog_canvas_layer):
		# The Dialogic plugin should handle freeing its own nodes upon timeline end.
		_current_dialog_canvas_layer = null # Clear the local reference.
	emit_signal("timeline_ended") # Re-emit your custom signal from the wrapper.

# New signal handler for text_finished on the actual DialogNode (if connected)
func _on_dialog_node_text_finished():
	print("Text display on DialogNode has finished!")
	# Add any specific game logic here that should happen when a block of text is displayed.

# Helper function to find the Dialogic CanvasLayer in the scene tree.
# This function MUST be defined within the 'extends Node' scope of this script.
func find_dialogic_canvas_layer() -> CanvasLayer:
	var root = get_tree().get_root()
	# Iterate through the children of the root viewport.
	for child in root.get_children():
		# Dialogic's main dialog scene is typically a CanvasLayer.
		if child is CanvasLayer:
			# Check if this CanvasLayer contains a node of class "DialogNode".
			# We use get_node_or_null and get_class() for robustness across alpha versions.
			var dialog_node_child = child.get_node_or_null("DialogNode") # Assuming default name
			if dialog_node_child and dialog_node_child.get_class() == "DialogNode":
				return child # Return the CanvasLayer that holds the DialogNode.
	return null # Return null if no such CanvasLayer is found.

# Expose a method for other scripts to get the current dialog node (the CanvasLayer).
func get_dialog_node() -> CanvasLayer:
	# Return the stored reference if it's valid.
	if _current_dialog_canvas_layer and is_instance_valid(_current_dialog_canvas_layer):
		return _current_dialog_canvas_layer
	# If the stored reference is null or invalid, try to find it again (e.g., if called later).
	return find_dialogic_canvas_layer()
