# villager.gd
# This script defines the behavior for a non-combatant villager NPC.
# The villager navigates to an extraction point, cowering/fleeing from monsters.

class_name Villager
extends CharacterBody2D

signal villager_extracted
signal villager_died

## Villager Type - Determines stats and appearance from GameData.
@export var villager_type: String = "villager_commoner_male"

# Villager stats loaded from GameData
var move_speed: float = 75.0
var max_health: float = 25.0
var popup_message: String = "Help me!"

# Internal variables
var current_health: float
var _extraction_point: Node2D
var can_trigger_popup: bool = true
var is_fearing: bool = false
var fear_direction: Vector2
var fear_timer: Timer

# Packed scene for the popup label
var popup_scene: PackedScene = preload("res://Assets/UI/villager_popup.tscn")

# Node references
@onready var sprite: Sprite2D = $sprite_2d
@onready var navigation_agent: NavigationAgent2D = $navigation_agent_2d
@onready var interaction_area: Area2D = $interaction_area
@onready var fear_area: Area2D = $fear_area

# Initialize the villager on ready
func _ready() -> void:
	if not sprite:
		print_debug("ERROR: sprite_2d node not found in villager.tscn")
		queue_free()
		return
	if not fear_area:
		print_debug("ERROR: fear_area node not found in villager.tscn")
		queue_free()
		return
	initialize_villager()
	add_to_group("friendly")

	fear_timer = Timer.new()
	fear_timer.one_shot = true
	fear_timer.timeout.connect(_on_fear_timer_timeout)
	add_child(fear_timer)

	var all_extraction_points: Array = get_tree().get_nodes_in_group("extraction_points")
	if not all_extraction_points.is_empty():
		_extraction_point = all_extraction_points.pick_random()
		print_debug("Selected extraction point: ", _extraction_point.global_position)
	else:
		print_debug("ERROR: No nodes found in the 'extraction_points' group.")
		set_physics_process(false)
		return

	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.area_entered.connect(_on_area_entered)
	fear_area.body_entered.connect(_on_fear_area_body_entered)
	update_navigation_target()

# Apply stats and sprite settings from GameData based on villager_type
func initialize_villager() -> void:
	if not GameData.villager_data.has(villager_type):
		print_debug("ERROR: Villager type '%s' not found in villagers.json" % villager_type)
		return

	var data: Dictionary = GameData.villager_data[villager_type]
	max_health = data.get("max_health", max_health)
	move_speed = data.get("move_speed", move_speed)
	popup_message = data.get("popup_message", popup_message)
	current_health = max_health

	var region_array: Array = data.get("sprite_region", [])
	if sprite and region_array.size() == 4 and region_array.all(func(x): return x is float or x is int):
		sprite.region_enabled = true
		sprite.region_rect = Rect2(region_array[0], region_array[1], region_array[2], region_array[3])
	else:
		print_debug("ERROR: Invalid 'sprite_region' for villager type '%s'" % villager_type)
		if sprite:
			sprite.region_enabled = false

# Called every physics frame for movement logic.
func _physics_process(delta: float) -> void:
	if not is_instance_valid(_extraction_point):
		set_physics_process(false)
		print_debug("ERROR: Extraction point is invalid")
		return

	if is_fearing:
		velocity = fear_direction * move_speed * 1.5  # Faster flee
		move_and_slide()
		return

	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		print_debug("Navigation finished for villager at: ", global_position)
		move_and_slide()
		return

	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_path_position)
	velocity = direction * move_speed
	move_and_slide()
	print_debug("Villager moving to: ", next_path_position, " with velocity: ", velocity)

# Called every frame for visual updates.
func _process(delta: float) -> void:
	_move_wobble()

# Applies a wobble rotation to the sprite when moving.
func _move_wobble() -> void:
	if not sprite or velocity.length() == 0:
		sprite.rotation_degrees = 0
		return
	var t = Time.get_unix_time_from_system()
	var rot = sin(t * 20) * 2
	sprite.rotation_degrees = rot

# Sets the target for the NavigationAgent2D.
func update_navigation_target() -> void:
	if is_instance_valid(_extraction_point):
		navigation_agent.target_position = _extraction_point.global_position
		print_debug("Navigation target set to: ", _extraction_point.global_position)
	else:
		print_debug("ERROR: Invalid extraction point in update_navigation_target")

# Function called by projectiles or attacks to inflict damage.
func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0 and not is_queued_for_deletion():
		die()

# Function called by healing projectiles to restore health.
func receive_heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)

# Handles the villager's death.
func die() -> void:
	set_process(false)
	set_physics_process(false)
	$collision_shape_2d.set_deferred("disabled", true)
	emit_signal("villager_died")
	Global.increment_lost_villagers()  # Update Global counter
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		await tween.finished
	queue_free()

# Called when the villager successfully reaches the extraction point.
func _on_navigation_finished() -> void:
	emit_signal("villager_extracted")
	Global.increment_saved_villagers()  # Update Global counter
	queue_free()

# Called when a body enters the interaction area.
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and can_trigger_popup:
		can_trigger_popup = false
		var popup: CanvasLayer = popup_scene.instantiate()
		var label: Label = popup.get_node("label")
		if not label:
			print_debug("ERROR: label node not found in villager_popup.tscn")
			popup.queue_free()
			await get_tree().create_timer(5.0).timeout
			can_trigger_popup = true
			return

		label.text = popup_message
		# Convert villager's world position to screen coordinates
		var camera: Camera2D = get_viewport().get_camera_2d()
		var screen_pos: Vector2 = global_position + Vector2(0, -30)
		if camera:
			screen_pos = camera.get_screen_center_position() - (camera.get_viewport_rect().size / 2) + global_position - camera.global_position
		label.global_position = screen_pos
		get_tree().current_scene.add_child(popup)
		
		# Fade in the label
		label.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.5)
		
		# Wait and fade out
		await get_tree().create_timer(2.0).timeout
		tween = create_tween()
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		await tween.finished
		popup.queue_free()
		
		# Allow retrigger after cooldown
		await get_tree().create_timer(5.0).timeout
		can_trigger_popup = true

# Called when an area (e.g., projectile) enters the interaction area.
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster_projectiles"):
		take_damage(area.damage if "damage" in area else 10.0)
	elif area.is_in_group("healing_projectiles"):
		receive_heal(area.heal_amount if "heal_amount" in area else 20.0)

# Called when a monster enters the fear area
func _on_fear_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("monster") and not is_fearing:
		is_fearing = true
		fear_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		fear_timer.start(3.0)  # Flee for 3 seconds
		sprite.modulate = Color(1, 0.5, 0.5)  # Cower effect (reddish tint)

# End fear state
func _on_fear_timer_timeout() -> void:
	is_fearing = false
	sprite.modulate = Color.WHITE  # Reset tint
	update_navigation_target()
