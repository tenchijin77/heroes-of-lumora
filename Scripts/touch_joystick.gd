# touch_joystick.gd - Virtual joystick for touch controls
extends Control

@export var action_name: String = "move"
@export var radius: float = 100.0

var _touch_index: int = -1
var _knob: Node2D = null

func _ready() -> void:
	_knob = get_node_or_null("Sprite2D")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			if global_position.distance_to(event.position) <= radius:
				_touch_index = event.index
				_process_touch(event.position)
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_process_touch(event.position)
		get_viewport().set_input_as_handled()

func _process_touch(touch_pos: Vector2) -> void:
	var delta := (touch_pos - global_position).limit_length(radius)
	var norm := delta / radius
	if _knob:
		_knob.position = delta
	if action_name == "move":
		Input.action_press("move_left",  maxf(0.0, -norm.x))
		Input.action_press("move_right", maxf(0.0,  norm.x))
		Input.action_press("move_up",    maxf(0.0, -norm.y))
		Input.action_press("move_down",  maxf(0.0,  norm.y))
	elif action_name == "aim":
		Input.action_press("aim_left",  maxf(0.0, -norm.x))
		Input.action_press("aim_right", maxf(0.0,  norm.x))
		Input.action_press("aim_up",    maxf(0.0, -norm.y))
		Input.action_press("aim_down",  maxf(0.0,  norm.y))
		if norm.length() > 0.2:
			Input.action_press("shoot", 1.0)
		else:
			Input.action_release("shoot")

func _reset() -> void:
	if _knob:
		_knob.position = Vector2.ZERO
	if action_name == "move":
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
	elif action_name == "aim":
		Input.action_release("aim_left")
		Input.action_release("aim_right")
		Input.action_release("aim_up")
		Input.action_release("aim_down")
		Input.action_release("shoot")
