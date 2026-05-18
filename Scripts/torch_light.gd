extends PointLight2D

@export var base_energy: float = 1.2
@export var flicker_range: float = 0.4
@export var flicker_speed: float = 0.12
@export var color_dim: Color = Color(1.0, 0.42, 0.0)    # deep orange at low energy
@export var color_bright: Color = Color(1.0, 0.78, 0.25) # warm yellow at peak

var _target_energy: float
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_target_energy = base_energy
	energy = base_energy
	var timer := Timer.new()
	timer.name = "flicker_timer"
	timer.one_shot = false
	timer.wait_time = flicker_speed
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_pick_new_target)

func _process(delta: float) -> void:
	energy = lerp(energy, _target_energy, delta * 10.0)
	# Color breathes with energy: deeper orange when dim, warm yellow at peak
	var t: float = clamp((energy - (base_energy - flicker_range)) / (flicker_range * 2.0), 0.0, 1.0)
	color = color_dim.lerp(color_bright, t)

func _pick_new_target() -> void:
	_target_energy = base_energy + rng.randf_range(-flicker_range, flicker_range)
	$flicker_timer.wait_time = flicker_speed + rng.randf_range(-flicker_speed * 0.4, flicker_speed * 0.4)
