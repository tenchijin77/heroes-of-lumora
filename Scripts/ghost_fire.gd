# ghost_fire.gd - ghost projectile script

extends Area2D

# Projectile speed
var speed: float = 550.0  # Slightly different for variety
# Direction vector
var direction: Vector2 = Vector2.RIGHT
# Damage amount
var damage: int = 18  # Adjust as needed
# Trail length limit
var trail_length: int = 25
# Scale pulse for ethereal effect
var scale_pulse_speed: float = 4.0
# Light pulse speed
var pulse_speed: float = 3.5

@onready var trail: Line2D = $Trail
@onready var particles: GPUParticles2D = $Particles
@onready var launch_sound: AudioStreamPlayer2D = $LaunchSound
@onready var glow_light: Light2D = $GlowLight

# Set up effects on ready
func _ready() -> void:
	launch_sound.play()
	particles.emitting = true  # Ethereal wisps for trail

# Move projectile, update trail, pulse scale and light for glam
func _process(delta: float) -> void:
	position += direction * speed * delta
	scale = Vector2(1 + 0.15 * sin(Time.get_ticks_msec() * 0.001 * scale_pulse_speed), 1 + 0.15 * sin(Time.get_ticks_msec() * 0.001 * scale_pulse_speed))
	glow_light.energy = 1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed)
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
		spawn_ghost_explosion()
	queue_free()

# Spawn ghost particle explosion on hit
func spawn_ghost_explosion() -> void:
	var effect: Node2D = preload("res://Scenes/ghost_explosion.tscn").instantiate()
	effect.position = position
	get_parent().add_child(effect)
