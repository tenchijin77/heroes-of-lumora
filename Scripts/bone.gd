# bone.gd - controls the bone projectile
extends Area2D

@export var speed: float = 200.0
@export var owner_group: String = "monsters"
@export var damage: int = 5

@onready var destroy_timer: Timer = $destroy_timer
@onready var projectile_sound: AudioStreamPlayer2D = $projectile_sound

var move_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Optional: Set default stream if not overridden in .tscn (safeguard)
	if projectile_sound.stream == null:
		projectile_sound.stream = load("res://Assets/sounds/bone_whistle.ogg")  # Your unique path

func launch(start_pos: Vector2, direction: Vector2) -> void:
	global_position = start_pos
	move_direction = direction.normalized()
	rotation = move_direction.angle()
	
	visible = true
	if $CollisionShape2D:
		$CollisionShape2D.disabled = false
	
	# Ensure unique sound plays on each launch, overriding any default
	if projectile_sound and projectile_sound.stream == null:
		projectile_sound.stream = load("res://Assets/sounds/bone_whistle.ogg")  # Reapply on reuse
	if projectile_sound:
		projectile_sound.play()
	else:
		print("⚠️ projectile_sound is null!")
	
	if destroy_timer:
		destroy_timer.start()

# ... (keep _process, _on_destroy_timer_timeout, _on_body_entered, reset as is)
