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

@onready var navigation_agent: NavigationAgent2D = $navigation_agent_2d
@onready var sprite: Sprite2D = $sprite_2d
@onready var popup_timer: Timer = $popup_timer
@onready var avoidance_ray: RayCast2D = $avoidance_ray

var target_extraction_point: Node2D
var is_extracted: bool = false
var health: int = 100
var popup_message: String = "Help me!"
var popup_node: CanvasLayer
var popup_label: Label

func _ready() -> void:
	# Initialize villager in scene tree
	if is_inside_tree():
		if OS.has_feature("editor"):
			print("Villager: Scene tree valid in _ready, node: %s" % name)
	else:
		if OS.has_feature("editor"):
			push_error("Villager: Not in scene tree in _ready!")
	
	# Setup navigation
	if navigation_agent:
		navigation_agent.path_desired_distance = 50.0
		navigation_agent.target_desired_distance = 50.0
		navigation_agent.navigation_finished.connect(_on_navigation_finished)
		update_navigation_target()
		if OS.has_feature("editor"):
			print("Villager %s: navigation_agent_2d initialized" % name)
	else:
		if OS.has_feature("editor"):
			push_error("Villager %s: navigation_agent_2d not found!" % name)
	
	# Setup popup timer
	if popup_timer:
		popup_timer.wait_time = 3.0
		popup_timer.one_shot = true
		popup_timer.timeout.connect(_on_popup_timer_timeout)
		if OS.has_feature("editor"):
			print("Villager %s: popup_timer initialized with wait_time %s" % [name, popup_timer.wait_time])
	else:
		if OS.has_feature("editor"):
			push_error("Villager %s: popup_timer not found!" % name)
	
	# Setup avoidance ray
	if avoidance_ray:
		avoidance_ray.enabled = true
		avoidance_ray.collision_mask = 1 << 4  # Layer 5 (environment, mask is 1 << (layer - 1))
		if OS.has_feature("editor"):
			print("Villager %s: avoidance_ray initialized" % name)
	else:
		if OS.has_feature("editor"):
			push_error("Villager %s: avoidance_ray not found!" % name)
	
	# Load villager data
	var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data and json_data.has(villager_type):
			var data: Dictionary = json_data[villager_type]
			health = data.get("health", 100)
			popup_message = data.get("popup_message", "Help me!")
			if OS.has_feature("editor"):
				print("Villager %s: Initialized with type %s, popup_message=%s" % [name, villager_type, popup_message])
		else:
			if OS.has_feature("editor"):
				push_error("Villager: Failed to load data for type %s from villagers.json!" % villager_type)
		file.close()
	else:
		if OS.has_feature("editor"):
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
					if OS.has_feature("editor"):
						push_warning("Villager %s: sprite_2d is null, using fallback offset for popup!" % name)
				popup_label.global_position = global_position + Vector2(-popup_label.size.x / 2, offset_y)
				if popup_timer:
					popup_timer.start()
				if OS.has_feature("editor"):
					print("Villager %s: Popup initialized with message '%s' at position %s" % [name, popup_message, popup_label.global_position])
			else:
				if OS.has_feature("editor"):
					push_error("Villager %s: label not found in villager_popup.tscn!" % name)
		else:
			if OS.has_feature("editor"):
				push_error("Villager %s: Failed to instantiate villager_popup.tscn!" % name)
	else:
		if OS.has_feature("editor"):
			push_error("Villager %s: villager_popup.tscn not found!" % name)

func _physics_process(delta: float) -> void:
	# Move towards extraction point if not extracted
	if is_extracted or not navigation_agent:
		if OS.has_feature("editor"):
			print("Villager %s: Skipping _physics_process: is_extracted=%s, navigation_agent=%s" % [name, is_extracted, navigation_agent])
		return
	
	if navigation_agent.is_navigation_finished():
		if OS.has_feature("editor"):
			print("Villager %s: Navigation finished, checking for new target" % name)
		update_navigation_target()
		return
	
	var next_position: Vector2 = navigation_agent.get_next_path_position()
	if next_position == Vector2.ZERO:
		if OS.has_feature("editor"):
			print("Villager %s: No valid path, updating navigation target" % name)
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
			if OS.has_feature("editor"):
				print("Villager %s: Avoiding obstacle at %s, adjusted direction %s" % [name, collision_point, direction])
	
	velocity = direction * speed
	move_and_slide()
	if OS.has_feature("editor"):
		print("Villager %s: Moving to %s with velocity %s" % [name, next_position, velocity])
	
	# Update popup position to follow villager
	if popup_label:
		var offset_y: float = -20.0
		if sprite:
			offset_y = -sprite.get_rect().size.y / 2 - 20
		else:
			if OS.has_feature("editor"):
				push_warning("Villager %s: sprite_2d is null, using fallback offset for popup!" % name)
		popup_label.global_position = global_position + Vector2(-popup_label.size.x / 2, offset_y)

func _on_popup_timer_timeout() -> void:
	# Hides popup after 3 seconds
	if popup_node:
		popup_node.queue_free()
		popup_node = null
		popup_label = null
		if OS.has_feature("editor"):
			print("Villager %s: Popup freed after timer timeout" % name)

func update_navigation_target() -> void:
	# Sets a random extraction point as navigation target
	if is_extracted or not navigation_agent:
		if OS.has_feature("editor"):
			print("Villager %s: Skipping update_navigation_target: is_extracted=%s, navigation_agent=%s" % [name, is_extracted, navigation_agent])
		return
	
	var extraction_points: Array = get_tree().get_nodes_in_group("extraction_points")
	if OS.has_feature("editor"):
		print("Villager %s: Found %d extraction points" % [name, extraction_points.size()])
	if not extraction_points.is_empty():
		target_extraction_point = extraction_points[randi() % extraction_points.size()] as Node2D
		if target_extraction_point:
			navigation_agent.set_target_position(target_extraction_point.global_position)
			if OS.has_feature("editor"):
				print("Villager %s: Navigation target set to %s at %s" % [name, target_extraction_point.name, target_extraction_point.global_position])
		else:
			if OS.has_feature("editor"):
				push_error("Villager %s: Invalid extraction point!" % name)
	else:
		if OS.has_feature("editor"):
			push_error("Villager %s: No extraction points found!" % name)

func _on_navigation_finished() -> void:
	# Handles villager reaching extraction point
	if is_extracted:
		if OS.has_feature("editor"):
			print("Villager %s: Already extracted, skipping _on_navigation_finished" % name)
		return
	
	if target_extraction_point and global_position.distance_to(target_extraction_point.global_position) <= 50.0:
		is_extracted = true
		visible = false
		set_physics_process(false)
		Global.saved_villagers += 1
		emit_signal("villagers_updated", Global.saved_villagers, Global.lost_villagers)
		if popup_node:
			popup_node.queue_free()
			popup_node = null
			popup_label = null
			if OS.has_feature("editor"):
				print("Villager %s: Popup freed on extraction" % name)
		if OS.has_feature("editor"):
			print("Villager %s: Reached extraction point %s at %s" % [name, target_extraction_point.name, target_extraction_point.global_position])
			print("Villager %s: Global.saved_villagers incremented to %d" % [name, Global.saved_villagers])
		villager_extracted.emit(self)
	else:
		update_navigation_target()
		if OS.has_feature("editor"):
			print("Villager %s: Navigation finished but not close enough to %s, updating target" % [name, target_extraction_point.name if target_extraction_point else "null"])

func take_damage(damage: int, _projectile_instance):
	# Applies damage and handles death
	health -= damage
	if OS.has_feature("editor"):
		print("Villager %s: Took %d damage, health now %d" % [name, damage, health])
	if health <= 0:
		Global.lost_villagers += 1
		emit_signal("villagers_updated", Global.saved_villagers, Global.lost_villagers)
		if popup_node:
			popup_node.queue_free()
			popup_node = null
			popup_label = null
			if OS.has_feature("editor"):
				print("Villager %s: Popup freed on death" % name)
		if OS.has_feature("editor"):
			print("Villager %s: Died, Global.lost_villagers incremented to %d" % [name, Global.lost_villagers])
		villager_died.emit(self)

func reset(type: String = villager_type) -> void:
	# Resets villager for reuse
	villager_type = type
	health = 100
	is_extracted = false
	visible = true
	set_physics_process(true)
	
	# Reload villager data to update popup_message
	var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data and json_data.has(villager_type):
			var data: Dictionary = json_data[villager_type]
			health = data.get("health", 100)
			popup_message = data.get("popup_message", "Help me!")
		file.close()
	
	# Reset popup
	_setup_popup()
	
	if OS.has_feature("editor"):
		print("Villager %s: Reset with type %s" % [name, villager_type])
	update_navigation_target()
