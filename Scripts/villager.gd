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

func _ready() -> void:
	# FIXED: Reparent to main scene if we're not already a child of main
	# This prevents projectiles from moving with their firing entity
	call_deferred("_reparent_to_main")
	
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

	print("Projectile %s: _ready, move_direction=%s, position=%s, owner_group=%s" %
		[name, move_direction, global_position, owner_group])

func _reparent_to_main() -> void:
	"""Reparent projectile to main scene so it doesn't move with firing entity"""
	if not is_inside_tree():
		return
	
	var current_parent = get_parent()
	if not current_parent:
		return
	
	# Check if we're already a child of main
	if current_parent.name == "main":
		return
	
	# Find main scene
	var main_scene = get_tree().root.get_node_or_null("main")
	if not main_scene:
		push_warning("Projectile %s: Could not find 'main' scene for reparenting" % name)
		return
	
	# Store position before reparenting
	var old_global_pos = global_position
	
	# Reparent
	current_parent.remove_child(self)
	main_scene.add_child(self)
	
	# Restore position
	global_position = old_global_pos

func reset() -> void:
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if destroy_timer:
		destroy_timer.start()
	if projectile_sound:
		# Stop any playing audio first
		if projectile_sound.playing:
			projectile_sound.stop()
		if sound_stream:
			projectile_sound.stream = sound_stream
		if not projectile_sound.playing:
			projectile_sound.play()
	move_direction = Vector2.ZERO
	rotation = 0.0
	position = Vector2.ZERO
	print("Projectile %s: Reset, move_direction=%s, position=%s, owner_group=%s" % [name, move_direction, global_position, owner_group])

func _process(delta: float) -> void:
	if move_direction != Vector2.ZERO:
		translate(move_direction * speed * delta)
		rotation = move_direction.angle()

func _on_destroy_timer_timeout() -> void:
	despawn()

func _on_visibility_changed() -> void:
	if visible and destroy_timer:
		destroy_timer.start()
	elif not visible and projectile_sound and projectile_sound.playing:
		# Stop audio when becoming invisible
		projectile_sound.stop()

func _on_body_entered(body: Node) -> void:
	print("🟠 projectile.gd _on_body_entered called: hit %s from group %s" % [body.name, owner_group])

	if body.is_in_group(owner_group):
		return

	if owner_group == "friendly":
		if body.has_method("heal") and (body.is_in_group("player") or body.is_in_group("friendly")):
			push_warning("Friendly projectile tried to heal in projectile.gd; should be in healing_projectile.gd")
			despawn()
			return

	if body.has_method("take_damage") and body.is_in_group("monsters"):
		body.take_damage(damage, self)
		print("Projectile from '%s' damaged monster %s for %d" % [owner_group, body.name, damage])
		despawn()
		return

	if owner_group == "monsters":
		if body.has_method("take_damage") and (body.is_in_group("player") or body.is_in_group("friendly") or body.is_in_group("healer")):
			body.take_damage(damage, self)
			print("Monster projectile hit %s for %d" % [body.name, damage])
			despawn()
			return

	if owner_group == "player" and body.has_method("take_damage") and body.is_in_group("monsters"):
		body.take_damage(damage, self)
		print("Player projectile hit monster %s for %d" % [body.name, damage])
		despawn()
		return

	print("Projectile from '%s' hit %s — no effect, despawning" % [owner_group, body.name])
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
		print("Projectile %s: Despawn fallback (no NodePool parent)—test mode OK" % name)
	print("Projectile %s: Despawned, move_direction=%s, position=%s" % [name, move_direction, global_position])

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
	else:
		print("⚠️ projectile_sound is null!")

	if destroy_timer:
		destroy_timer.start()
