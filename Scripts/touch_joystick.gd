# touch_joystick.gd - handles virtual joystick input for touch controls
extends TouchScreenButton

@export var joystick_size: Vector2 = Vector2(200, 200)  # Allow size configuration in Inspector
@export var action_name: String
var base_position: Vector2
var radius: float = 100.0
var action_prefix: String

func _ready() -> void:
	await get_tree().process_frame  # Ensure node is fully initialized
	base_position = position + joystick_size / 2
	print("Base position: ", base_position, " Size: ", joystick_size, " Node: ", name)  # Enhanced debug
	action_prefix = action_name

# Remove the _input() function entirely, as TouchScreenButton handles its own input.

func set_action_strength(touch_pos: Vector2) -> void:
	var delta = (touch_pos - base_position).limit_length(radius)
	var strength = delta.length() / radius
	var direction = delta.normalized()
	if action_prefix == "move":
		Input.action_press("move_left", -direction.x if direction.x < 0 else 0.0)
		Input.action_press("move_right", direction.x if direction.x > 0 else 0.0)
		Input.action_press("move_up", -direction.y if direction.y < 0 else 0.0)
		Input.action_press("move_down", direction.y if direction.y > 0 else 0.0)
	elif action_prefix == "aim":
		Input.action_press("aim_left", -direction.x if direction.x < 0 else 0.0)
		Input.action_press("aim_right", direction.x if direction.x > 0 else 0.0)
		Input.action_press("aim_up", -direction.y if direction.y < 0 else 0.0)
		Input.action_press("aim_down", direction.y if direction.y > 0 else 0.0)
		if strength > 0.2:  # Deadzone for shooting
			Input.action_press("shoot", 1.0)
		else:
			Input.action_release("shoot")
