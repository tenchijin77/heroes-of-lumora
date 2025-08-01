# fireball.gd - wizard fireball projectile

extends Area2D

# Projectile speed
var speed: float = 500.0
# Direction vector
var direction: Vector2 = Vector2.RIGHT
# Damage amount
var damage: int = 20
# Trail length limit
var trail_length: int = 30
# Scale pulse for flaming effect
var scale_pulse_speed: float = 5.0
# Light pulse speed
var pulse_speed: float = 4.0

@onready var trail: Line2D = $Trail
@onready var particles: GPUParticles2D = $particles
@onready var launch_sound: AudioStreamPlayer2D = $LaunchSound
@onready var glow_light: Light2D = $glow_light


# Set up effects on ready
func _ready() -> void:
	launch_sound.play()
	particles.emitting = true  # Fire embers for trail

# Move projectile, update trail, pulse scale and light for glam
func _process(delta: float) -> void:
	position += direction * speed * delta
	scale = Vector2(1 + 0.1 * sin(Time.get_ticks_msec() * 0.001 * scale_pulse_speed), 1 + 0.1 * sin(Time.get_ticks_msec() * 0.001 * scale_pulse_speed))
	glow_light.energy = 1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed)
	update_trail()

# Update trail points
func update_trail() -> void:
	trail.add_point(position)
	if trail.points.size() > trail_length:
		trail.remove_point(0)

# Handle collision with player
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
		spawn_fire_explosion()
	queue_free()

# Spawn fire particle explosion on hit
func spawn_fire_explosion() -> void:
	var effect: Node2D = preload("res://Scenes/fire_explosion.tscn").instantiate()
	effect.position = position
	get_parent().add_child(effect)
