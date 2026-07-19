# projectile.gd - base projectile template script
extends Area2D


@export var speed : float = 200.0
@export var owner_group: String
@export var damage : int = 4
@export var sound_stream : AudioStream
@onready var destroy_timer : Timer = $destroy_timer
@onready var projectile_sound : AudioStreamPlayer2D = $projectile_sound
@onready var collision_shape : CollisionShape2D = $CollisionShape2D

var move_direction : Vector2 = Vector2.ZERO
var home_target: Node = null
@export var home_strength: float = 0.0  # turn rate radians/sec; 0 = straight flight
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var shooter: Node = null
var apply_dot_on_hit: bool = false
var dot_damage_per_tick: int = 0
var dot_ticks: int = 0

func _ready() -> void:
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

	visible = true
	if collision_shape:
		collision_shape.disabled = false
	if projectile_sound:
		if sound_stream:
			projectile_sound.stream = sound_stream
		if not projectile_sound.playing:
			projectile_sound.play()
	else:
		push_warning("Projectile %s: projectile_sound or sound_stream is null in _ready—check scene node!" % name)



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
	home_target = null
	move_direction = Vector2.ZERO
	rotation = 0.0
	position = Vector2.ZERO
	slow_percent = 0.0
	slow_duration = 0.0
	modulate = Color.WHITE
	apply_dot_on_hit = false
	dot_damage_per_tick = 0
	dot_ticks = 0


func _process(delta: float) -> void:
	if home_target != null and is_instance_valid(home_target) and home_strength > 0.0:
		var to_target: Vector2 = global_position.direction_to(home_target.global_position)
		var turn: float = clamp(move_direction.angle_to(to_target), -home_strength * delta, home_strength * delta)
		move_direction = move_direction.rotated(turn).normalized()
	if move_direction != Vector2.ZERO:
		translate(move_direction * speed * delta)
		rotation = move_direction.angle()


func _on_destroy_timer_timeout() -> void:
	despawn()


func _on_visibility_changed() -> void:
	if visible and destroy_timer:
		destroy_timer.start()


func _on_body_entered(body: Node) -> void:

	if body.is_in_group(owner_group):
		return

	if owner_group == "friendly":
		if body.has_method("heal") and (body.is_in_group("player") or body.is_in_group("friendly")):
			push_warning("Friendly projectile tried to heal in projectile.gd; should be in healing_projectile.gd")
			despawn()
			return

	if body.has_method("take_damage") and body.is_in_group("monsters"):
		body.take_damage(damage, self)
		if slow_percent > 0.0 and body.has_method("apply_slow"):
			body.apply_slow(slow_percent, slow_duration)
		if apply_dot_on_hit and dot_ticks > 0 and body.has_method("apply_dot"):
			body.apply_dot(dot_damage_per_tick, dot_ticks)
		despawn()
		return

	if owner_group == "monsters":
		if body.has_method("take_damage") and (body.is_in_group("player") or body.is_in_group("friendly") or body.is_in_group("healer")):
			body.take_damage(damage, self)
			despawn()
			return

	if owner_group == "player" and body.has_method("take_damage") and body.is_in_group("monsters"):
		body.take_damage(damage, self)
		despawn()
		return

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


func set_damage(new_damage: int) -> void:
	damage = new_damage


func launch(start_pos: Vector2, direction: Vector2) -> void:
	global_position = start_pos
	move_direction = direction.normalized()
	rotation = move_direction.angle()

	visible = true
	if $CollisionShape2D:
		$CollisionShape2D.disabled = false

	if projectile_sound and projectile_sound.stream == null:
		projectile_sound.stream = load("res://Assets/sounds/bone_whistle.ogg")
	if projectile_sound:
		projectile_sound.play()

	if destroy_timer:
		destroy_timer.start()
