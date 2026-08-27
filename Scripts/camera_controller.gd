extends Camera2D

@onready var target: Node2D = get_node_or_null("../player")
@export var follow_rate: float = 2.0

# The vertical world-units the game was designed to show at 1x zoom.
# Matches the Godot 4 default viewport height so existing scenes look unchanged.
@export var base_height: float = 648.0

# Screen shake
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0

# Zoom — user_zoom is applied on top of the auto-fit base zoom
const MIN_USER_ZOOM: float = 0.65
const MAX_USER_ZOOM: float = 3.0
var _base_zoom: float = 1.0
var _user_zoom: float = 1.0
var _pinch_start_user_zoom: float = 1.0
var _pinch_start_distance: float = 0.0
var _touch_positions: Dictionary = {}

func _ready() -> void:
	get_viewport().size_changed.connect(_recalc_zoom)
	_recalc_zoom()

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

func _process(delta: float) -> void:
	if not target:
		return
	global_position = global_position.lerp(target.global_position, follow_rate * delta)
	if _shake_timer > 0.0:
		_shake_timer -= delta
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		offset = Vector2.ZERO

func _recalc_zoom() -> void:
	# Scale so base_height world-units always fill the viewport vertically.
	var vp_h := get_viewport().get_visible_rect().size.y
	if vp_h > 0.0:
		_base_zoom = vp_h / base_height
	zoom = Vector2.ONE * (_base_zoom * _user_zoom)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse-wheel zoom
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_user_zoom = minf(_user_zoom * 1.1, MAX_USER_ZOOM)
			_recalc_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_user_zoom = maxf(_user_zoom / 1.1, MIN_USER_ZOOM)
			_recalc_zoom()

	# Touch: track finger positions
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_positions[event.index] = event.position
		else:
			_touch_positions.erase(event.index)
			if _touch_positions.size() < 2:
				_pinch_start_distance = 0.0

	# Pinch-to-zoom
	if _touch_positions.size() == 2:
		var pts := _touch_positions.values()
		var dist: float = pts[0].distance_to(pts[1])
		if _pinch_start_distance == 0.0:
			_pinch_start_distance = dist
			_pinch_start_user_zoom = _user_zoom
			return
		_user_zoom = clamp(_pinch_start_user_zoom * (dist / _pinch_start_distance), MIN_USER_ZOOM, MAX_USER_ZOOM)
		_recalc_zoom()
