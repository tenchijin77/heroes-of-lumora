# villager.gd
# Controls villager behavior, navigation to extraction points, and popup message display.
extends CharacterBody2D
class_name Villager
signal villager_died(villager: Node2D)
signal villager_extracted(villager: Node2D)
@export var speed: float = 100.0
@export var villager_type: String = "villager_commoner_male"
@export var avoidance_strength: float = 100.0 # Strength of avoidance steering
@export var ray_length: float = 100.0 # Length of avoidance ray
@export var max_health: int = 100 # Added for healer compatibility
@onready var navigation_agent: NavigationAgent2D = $navigation_agent_2d
@onready var sprite: Sprite2D = $sprite_2d
@onready var popup_timer: Timer = $popup_timer
@onready var avoidance_ray: RayCast2D = $avoidance_ray
var health: int = 100
var popup_message: String = "Help me!"
var popup_node: CanvasLayer
var popup_label: Label
var target_position: Vector2
func _ready() -> void:
	# Initialize villager in scene tree
	if is_inside_tree():
		# Setup navigation
		if navigation_agent:
			navigation_agent.path_desired_distance = 50.0
			navigation_agent.target_desired_distance = 50.0
			navigation_agent.navigation_finished.connect(_on_navigation_finished)
			update_navigation_target()
		else:
			push_error("Villager %s: navigation_agent_2d not found!" % name)
		# Setup popup timer
		if popup_timer:
			popup_timer.wait_time = 3.0
			popup_timer.one_shot = true
			popup_timer.timeout.connect(_on_popup_timer_timeout)
		else:
			push_error("Villager %s: popup_timer not found!" % name)
		# Setup avoidance ray
		if avoidance_ray:
			avoidance_ray.enabled = true
			avoidance_ray.collision_mask = 1 << 4 # Layer 5 (environment, mask is 1 << (layer - 1))
		else:
			push_error("Villager %s: avoidance_ray not found!" % name)
		# Load villager data
		var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
		if file:
			var json_data = JSON.parse_string(file.get_as_text())
			if json_data and json_data.has(villager_type):
				var data: Dictionary = json_data[villager_type]
				max_health = data.get("max_health", 100) # Added max_health from data if available
				health = max_health # Reset to max
				popup_message = data.get("popup_message", "Help me!")
			else:
				push_error("Villager: Failed to load data for type %s from villagers.json!" % villager_type)
			file.close()
		else:
			push_error("Villager: Failed to open villagers.json!")
		# Setup popup
		_setup_popup()
		add_to_group("villagers")

func _setup_popup() -> void:
	# Sets up the popup message
	var popup_scene: PackedScene = preload("res://Assets/UI/villager_popup.tscn")
	if popup_scene:
		if popup_node:
			popup_node.queue_free()
			popup_node = null
			popup_label = null
		popup_node = popup_scene.instantiate() as CanvasLayer
		if popup_node:
			add_child(popup_node)
			popup_label = popup_node.get_node_or_null("label")
			if popup_label:
				popup_label.text = popup_message
				popup_label.visible = true
				# Position label above villager, centered horizontally
				var offset_y: float = -20.0
				if sprite:
					offset_y = -sprite.get_rect().size.y / 2 - 20
				else:
					push_warning("Villager %s: sprite_2d is null, using fallback offset for popup!" % name)
				popup_label.global_position = global_position + Vector2(-popup_label.size.x / 2, offset_y)
				if popup_timer:
					popup_timer.start()
			else:
				push_error("Villager %s: label not found in villager_popup.tscn!" % name)
		else:
			push_error("Villager %s: Failed to instantiate villager_popup.tscn!" % name)
	else:
		push_error("Villager %s: villager_popup.tscn not found!" % name)

func _physics_process(delta: float) -> void:
	# Check if the villager has reached the final destination and is ready to be extracted
	if navigation_agent.is_navigation_finished():
		_on_navigation_finished()
		return
	# If the villager is on a path, get the next point and move
	var next_position: Vector2 = navigation_agent.get_next_path_position()
	# Add a check to update target if the path becomes invalid or is zero
	if next_position == Vector2.ZERO:
		update_navigation_target()
		return
	var direction: Vector2 = (next_position - global_position).normalized()
	# Update avoidance ray in direction of movement
	if avoidance_ray:
		avoidance_ray.target_position = direction * ray_length
		avoidance_ray.force_raycast_update()
		if avoidance_ray.is_colliding():
			var collision_point = avoidance_ray.get_collision_point()
			var avoidance_vector = (global_position - collision_point).normalized().orthogonal() * avoidance_strength * delta
			direction += avoidance_vector
	direction = direction.normalized().clamp(Vector2(-1, -1), Vector2(1, 1))
	velocity = direction * speed
	move_and_slide()
	# Update popup position to follow villager
	if popup_label:
		var offset_y: float = -20.0
		if sprite:
			offset_y = -sprite.get_rect().size.y / 2 - 20
		else:
			push_warning("Villager %s: sprite_2d is null, using fallback offset for popup!" % name)
		popup_label.global_position = global_position + Vector2(-popup_label.size.x / 2, offset_y)

func _on_popup_timer_timeout() -> void:
	# Hides popup after 3 seconds
	if popup_node:
		popup_node.queue_free()
		popup_node = null
		popup_label = null

# This function is now responsible for handling extraction
func _on_navigation_finished() -> void:
	# New: Increment saved villagers
	if Global.has_method("increment_saved_villagers"):
		Global.increment_saved_villagers()
	# Emit the signal before freeing the node
	villager_extracted.emit(self)
	# Use queue_free() to properly remove the node from the scene
	queue_free()

func update_navigation_target() -> void:
	# Sets a random extraction point as navigation target
	if not navigation_agent:
		return
	var extraction_points: Array = get_tree().get_nodes_in_group("extraction_points")
	if not extraction_points.is_empty():
		var random_target = extraction_points[randi() % extraction_points.size()] as Node2D
		if random_target:
			target_position = random_target.global_position
			navigation_agent.set_target_position(target_position)
		else:
			push_error("Villager %s: Invalid extraction point!" % name)
	else:
		push_error("Villager %s: No extraction points found!" % name)

func take_damage(damage: int, _projectile_instance):
	# Applies damage and handles death
	health -= damage
	if health <= 0:
		# New: Increment lost villagers
		if Global.has_method("increment_lost_villagers"):
			Global.increment_lost_villagers()
		# A villager death has occurred, now emit the signal so other nodes can react.
		if popup_node:
			popup_node.queue_free()
			popup_node = null
			popup_label = null
		villager_died.emit(self)
		queue_free()

func reset(type: String = villager_type) -> void:
	# Resets villager for reuse
	villager_type = type
	health = max_health # Reset to max_health
	visible = true
	set_physics_process(true)
	# Reload villager data to update popup_message
	var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data and json_data.has(villager_type):
			var data: Dictionary = json_data[villager_type]
			max_health = data.get("max_health", 100) # Update max_health
			health = max_health
			popup_message = data.get("popup_message", "Help me!")
		file.close()
	# Reset popup
	_setup_popup()
	update_navigation_target()

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

func heal(amount: int) -> void:
	health = clamp(health + amount, 0, max_health)
	print("Villager %s healed for %d → current_health = %d" % [name, amount, health])
