extends PointLight2D

@export var base_energy: float = 1.5
@export var flicker_range: float = 0.5
@export var flicker_speed: float = 0.1 # This will be the new Timer's wait_time

var rng = RandomNumberGenerator.new()

func _ready():
	# Make sure we have a Timer node to work with
	if has_node("flicker_timer"):
		$flicker_timer.wait_time = flicker_speed
		$flicker_timer.start()
	else:
		# If there is no Timer node, add it and connect the signal
		var timer = Timer.new()
		timer.name = "flicker_timer"
		timer.one_shot = false
		timer.wait_time = flicker_speed
		timer.autostart = true
		add_child(timer)
		timer.timeout.connect(on_flicker_timer_timeout)
		
	rng.randomize()

func on_flicker_timer_timeout():
	# Change the light's energy by a random amount
	energy = base_energy + rng.randf_range(-flicker_range, flicker_range)
	# Give the timer a new random wait time for more natural flickering
	$flicker_timer.wait_time = flicker_speed + rng.randf_range(-flicker_speed * 0.5, flicker_speed * 0.5)
