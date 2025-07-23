# projectile.gd - base projectile template script
extends Area2D

@export var speed : float = 200.0
@export var owner_group : String = "monsters"  # Default for enemy projectiles; override for "player"
@export var damage : int = 4
@export var sound_stream : AudioStream  # Override in child for specific sound

@onready var destroy_timer : Timer = $destroy_timer
@onready var projectile_sound : AudioStreamPlayer2D = $projectile_sound
@onready var collision_shape : CollisionShape2D = $CollisionShape2D

var move_direction : Vector2 = Vector2.ZERO

func reset() -> void:
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if destroy_timer:
		destroy_timer.start()
	if projectile_sound:
		if sound_stream:
			projectile_sound.stream = sound_stream
		if not projectile_sound.playing:
			projectile_sound.play()
	else:
		push_warning("Projectile %s: projectile_sound is null!" % name)
	move_direction = Vector2.ZERO
	rotation = 0.0
	position = Vector2.ZERO
	print("Projectile %s: Reset, move_direction=%s, position=%s, owner_group=%s" % [name, move_direction, global_position, owner_group])

func _ready() -> void:
	visible = true
	if collision_shape:
		collision_shape.disabled = false
	if projectile_sound:
		if sound_stream:
			projectile_sound.stream = sound_stream
		if not projectile_sound.playing:
			projectile_sound.play()
	else:
		push_warning("Projectile %s: projectile_sound or sound_stream is null in _ready!" % name)
	print("Projectile %s: _ready, move_direction=%s, position=%s, owner_group=%s" % [name, move_direction, global_position, owner_group])

func _process(delta: float) -> void:
	if move_direction != Vector2.ZERO:
		translate(move_direction * speed * delta)
		rotation = move_direction.angle()
	else:
		print("Projectile %s: not moving, move_direction=%s, position=%s" % [name, move_direction, global_position])

func _on_destroy_timer_timeout() -> void:
	despawn()

func _on_visibility_changed() -> void:
	if visible and destroy_timer:
		destroy_timer.start()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(owner_group):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	despawn()

func despawn() -> void:
	visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if destroy_timer:
		destroy_timer.stop()
	if projectile_sound and projectile_sound.playing:
		projectile_sound.stop()
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		push_warning("Projectile %s: Parent is not a NodePool, cannot despawn properly!" % name)
	print("Projectile %s: Despawned, move_direction=%s, position=%s" % [name, move_direction, global_position])
