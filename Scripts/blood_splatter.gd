# blood_splatter.gd

extends Node2D

# Particle lifetime in seconds
var lifetime: float = 1.0

# Initialize and start emitting particles on ready
func _ready() -> void:
	$particles.emitting = true
	var timer: Timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
