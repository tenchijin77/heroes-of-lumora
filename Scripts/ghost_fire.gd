# ghost_fire.gd - controls the ghost fire projectile
extends Area2D

@export var speed: float = 180.0  # Ethereal drift speed
@export var owner_group: String = "monsters"
@export var damage: int = 16  # Spectral burn damage

@onready var destroy_timer: Timer = $destroy_timer
@onready var projectile_sound: AudioStreamPlayer2D = $projectile_sound

var move_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Set unique stream if not overridden in .tscn
	if projectile_sound.stream == null:
		projectile_sound.stream = load("res://Assets/sounds/ghost_wail.ogg")  # Your unique path

func launch(start_pos: Vector2, direction: Vector2) -> void:
	global_position = start_pos
	move_direction = direction.normalized()
	rotation = move_direction.angle()
	
	visible = true
	if $CollisionShape2D:
		$CollisionShape2D.disabled = false
	
	# Always ensure unique sound, overriding any default
	if projectile_sound.stream == null:
		projectile_sound.stream = load("res://Assets/sounds/ghost_wail.ogg")
	if projectile_sound:
		projectile_sound.play()
	else:
		print("⚠️ projectile_sound is null!")
	
	if destroy_timer:
		destroy_timer.start()

func _process(delta: float) -> void:
	if visible:
		translate(move_direction * speed * delta)

func _on_destroy_timer_timeout() -> void:
	reset()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(owner_group):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	reset()

func reset() -> void:
	visible = false
	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", true)
	if destroy_timer:
		destroy_timer.stop()
	if projectile_sound and projectile_sound.playing:
		projectile_sound.stop()
	move_direction = Vector2.ZERO
