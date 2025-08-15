# courage_aura.gd
extends Area2D

@export var buff_amount: float = 1.5 # 50% damage boost
@export var buff_duration: float = 8.0 # Match despawn_timer
@onready var despawn_timer: Timer = $despawn_timer

var buffed_bodies: Dictionary = {}

func _ready():
	despawn_timer.wait_time = buff_duration
	despawn_timer.timeout.connect(_on_despawn_timer_timeout)
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node):
	if body.is_in_group("friendly") or body.is_in_group("player") or body.is_in_group("healer"):
		# We assume the body has a `base_damage` and a `damage_modifier` variable
		if body.has_method("get_base_damage") and body.has_method("set_damage_modifier"):
			# Apply the buff and store the body in our dictionary
			body.set_damage_modifier(buff_amount)
			buffed_bodies[body] = true

func _on_body_exited(body: Node):
	if buffed_bodies.has(body):
		# Remove the buff and remove the body from our dictionary
		body.set_damage_modifier(1.0) # Reset to default
		buffed_bodies.erase(body)

func _on_despawn_timer_timeout():
	# Remove buff from all remaining bodies and queue for deletion
	for body in buffed_bodies:
		if is_instance_valid(body):
			body.set_damage_modifier(1.0) # Reset to default
	queue_free() # Despawn the aura scene
