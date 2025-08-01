# arrow.gd - player's ranged attack

extends Area2D

# Projectile speed
var speed: float = 800.0
# Direction vector
var direction: Vector2 = Vector2.RIGHT
# Damage amount
var damage: int = 10
# Trail length limit
var trail_length: int = 20

@onready var trail: Line2D = $Trail
@onready var particles: GPUParticles2D = $Particles
@onready var launch_sound: AudioStreamPlayer2D = $LaunchSound

# Set up effects on ready
func _ready() -> void:
	launch_sound.play()
	particles.emitting = true  # Simple spark trail for arrow

# Move projectile and update trail
func _process(delta: float) -> void:
	position += direction * speed * delta
	update_trail()

# Update trail points
func update_trail() -> void:
	trail.add_point(position)
	if trail.points.size() > trail_length:
		trail.remove_point(0)

# Handle collision with mobs
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("monsters"):
		body.take_damage(damage)  # Assuming mobs have take_damage func
		spawn_blood_splatter()
	queue_free()

# Spawn blood particle effect on hit
func spawn_blood_splatter() -> void:
	var effect: Node2D = preload("res://Scenes/blood_splatter.tscn").instantiate()
	effect.position = position
	get_parent().add_child(effect)
