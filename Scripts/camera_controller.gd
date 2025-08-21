extends Camera2D

# --- Existing Camera Follow Properties ---
@onready var target = $"../player"
@export var follow_rate: float = 2.0

# --- Zoom Properties ---
@export var zoom_speed: float = 0.01
var touch_positions: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_zoom: Vector2 = Vector2.ONE

func _process(delta: float) -> void:
	# This line keeps the camera following the player smoothly
	global_position = global_position.lerp(target.global_position, follow_rate * delta)

func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse wheel scrolling for zooming
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom *= 1.1  # Zoom in
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom /= 1.1  # Zoom out
				
	# Handle touch events for pinch-to-zoom
	if event is InputEventScreenTouch:
		var touch_index = event.index
		if event.pressed:
			touch_positions[touch_index] = event.position
		else:
			if touch_positions.has(touch_index):
				touch_positions.erase(touch_index)
			if touch_positions.size() < 2:
				initial_pinch_distance = 0.0
				initial_zoom = zoom

	# Check for pinch gesture
	if touch_positions.size() == 2:
		var touches = touch_positions.values()
		var touch1_pos = touches[0]
		var touch2_pos = touches[1]
		
		var current_pinch_distance = touch1_pos.distance_to(touch2_pos)
		
		if initial_pinch_distance == 0.0:
			initial_pinch_distance = current_pinch_distance
			initial_zoom = zoom
			return
		
		var zoom_factor = current_pinch_distance / initial_pinch_distance
		zoom = initial_zoom * zoom_factor
