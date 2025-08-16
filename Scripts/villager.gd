# villager.gd - Controls villager behavior, navigation, and health
extends CharacterBody2D
class_name Villager

signal villager_died(villager: Node2D)
signal villager_extracted(villager: Node2D)

@export var speed: float = 100.0
@export var villager_type: String = "villager_commoner_male"
@export var avoidance_strength: float = 100.0 # Strength of avoidance steering
@export var ray_length: float = 100.0 # Length of avoidance ray
@export var max_health: int = 100
@export var current_health: int = 100

@onready var navigation_agent: NavigationAgent2D = $navigation_agent_2d
@onready var sprite: Sprite2D = $sprite_2d
@onready var popup_timer: Timer = $popup_timer
@onready var avoidance_ray: RayCast2D = $avoidance_ray
@onready var health_bar: ProgressBar = $health_bar

var popup_message: String = "Help me!"
var popup_node: CanvasLayer
var popup_label: Label
var target_position: Vector2

func _ready() -> void:
	# Initialize villager in scene tree
	if is_inside_tree():
		add_to_group("villagers")
		if health_bar:
			health_bar.max_value = max_health
			health_bar.value = current_health
		if navigation_agent:
			navigation_agent.path_desired_distance = 50.0
			navigation_agent.target_desired_distance = 50.0
			navigation_agent.navigation_finished.connect(_on_navigation_finished)
			update_navigation_target()
		else:
			push_error("Villager %s: navigation_agent_2d not found!" % name)
		if popup_timer:
			popup_timer.wait_time = 3.0
			popup_timer.one_shot = true
			popup_timer.timeout.connect(_on_popup_timer_timeout)
		else:
			push_error("Villager %s: popup_timer not found!" % name)
		if avoidance_ray:
			avoidance_ray.enabled = true
			avoidance_ray.collision_mask = 1 << 4 # Layer 5 (environment)
		else:
			push_error("Villager %s: avoidance_ray not found!" % name)
		var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
		if file:
			var json_data = JSON.parse_string(file.get_as_text())
			if json_data and json_data.has(villager_type):
				var data: Dictionary = json_data[villager_type]
				max_health = data.get("max_health", 100)
				current_health = max_health
				if health_bar:
					health_bar.max_value = max_health
					health_bar.value = current_health
				popup_message = data.get("popup_message", "Help me!")
			else:
				push_error("Villager: Failed to load data for type %s from villagers.json!" % villager_type)
			file.close()
		else:
			push_error("Villager: Failed to open villagers.json!")
		_setup_popup()

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
	# Handle villager movement and navigation
	if navigation_agent.is_navigation_finished():
		_on_navigation_finished()
		return
	var next_position: Vector2 = navigation_agent.get_next_path_position()
	if next_position == Vector2.ZERO:
		update_navigation_target()
		return
	var direction: Vector2 = (next_position - global_position).normalized()
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

func _on_navigation_finished() -> void:
	# Handle villager extraction
	if Global.has_method("increment_saved_villagers"):
		Global.increment_saved_villagers()
	villager_extracted.emit(self)
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

func take_damage(damage: int, _projectile_instance) -> void:
	# Apply damage and handle death
	current_health -= damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	if current_health <= 0:
		if Global.has_method("increment_lost_villagers"):
			Global.increment_lost_villagers()
		if popup_node:
			popup_node.queue_free()
			popup_node = null
			popup_label = null
		villager_died.emit(self)
		queue_free()

func reset(type: String = villager_type) -> void:
	# Reset villager for reuse
	villager_type = type
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	visible = true
	set_physics_process(true)
	var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data and json_data.has(villager_type):
			var data: Dictionary = json_data[villager_type]
			max_health = data.get("max_health", 100)
			current_health = max_health
			if health_bar:
				health_bar.max_value = max_health
				health_bar.value = current_health
			popup_message = data.get("popup_message", "Help me!")
		file.close()
	_setup_popup()
	update_navigation_target()

func get_health() -> int:
	# Return current health
	return current_health

func get_max_health() -> int:
	# Return maximum health
	return max_health

func heal(amount: int) -> void:
	# Heal Villager and update health bar
	current_health = clamp(current_health + amount, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	print("Villager %s healed for %d → current_health = %d" % [name, amount, current_health])
