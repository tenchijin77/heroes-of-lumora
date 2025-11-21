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
@onready var avoidance_ray: RayCast2D = $avoidance_ray
@onready var health_bar: ProgressBar = $health_bar

var popup_message: String = "Help me!"
var shout_label: Label # The new internal label for shouts
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

		if avoidance_ray:
			avoidance_ray.enabled = true
			# Assuming Layer 5 (1 << 4) is the collision layer for monsters or obstacles to avoid
			avoidance_ray.collision_mask = 1 << 4 
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
			
		_setup_shout_label()
		# Initial shout using the message loaded from JSON
		shout(popup_message)

# --- NEW FUNCTION: Sets up the internal Label node ---
func _setup_shout_label() -> void:
	# 1. Create or fetch the internal label node (matching messenger.gd logic)
	if not has_node("shout_label"):
		shout_label = Label.new()
		shout_label.name = "shout_label"
		shout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Using theme overrides similar to Messenger
		shout_label.add_theme_font_size_override("font_size", 24)
		shout_label.add_theme_color_override("font_color", Color(1, 1, 0.2))
		shout_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		shout_label.add_theme_constant_override("outline_size", 8)
		add_child(shout_label)
	else:
		shout_label = $shout_label
	
	shout_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	shout_label.clip_text = true
	
	# Position relative to the Villager (centered)
	shout_label.position = Vector2(-200, -100) # Assuming width is 400, center at 0
	shout_label.size = Vector2(400, 80)
	shout_label.pivot_offset = shout_label.size / 2 # Pivot at the center of the label
	shout_label.modulate.a = 0.0
	shout_label.text = "" # Ensure it starts blank

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
			# Calculate avoidance vector perpendicular to the ray
			var avoidance_vector = (global_position - collision_point).normalized().orthogonal() * avoidance_strength * delta
			direction += avoidance_vector
	direction = direction.normalized().clamp(Vector2(-1, -1), Vector2(1, 1))
	velocity = direction * speed
	move_and_slide()

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

# --- NEW FUNCTION: Implements the animated shout ---
func shout(text: String) -> void:
	if not shout_label or shout_label.text != "": # Don't interrupt a shout
		return
	
	# 🛑 CRITICAL CHANGE: Apply the prefix here
	text = "A villager shouts: " + text
	
	# 1. Update text and calculate height (using Messenger's logic)
	shout_label.size.x = 400.0
	shout_label.set_deferred("text", text)
	
	if not get_tree(): return # Pre-await safety check
	await get_tree().process_frame
	
	# 🛑 CRITICAL FIX: Check if the instance is still valid after the await resumes.
	if not is_instance_valid(self):
		return # Prevents crash if the villager was killed/extracted during the frame wait.
	
	var font_height = shout_label.get_theme_font_size("font_size") * 1.7
	var line_count = shout_label.get_line_count()
	
	shout_label.size.y = float(line_count) * font_height
	shout_label.pivot_offset = shout_label.size / 2
	
	# 2. Reset visual state
	shout_label.scale = Vector2(0.2, 0.2)
	shout_label.modulate.a = 0.0
	
	# 3. Animate
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(shout_label, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(shout_label, "modulate:a", 1.0, 0.25)
	
	# Calculate final Y position relative to the Villager's body (where the label sits)
	var final_y_pos: float = -140.0 - (shout_label.size.y / 2.0)
	
	tween.tween_property(shout_label, "position:y", final_y_pos, 0.5)
	
	# 4. Fade out and clear text
	tween.chain().tween_property(shout_label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(func(): shout_label.text = "")

func take_damage(damage: int, _projectile_instance) -> void:
	# Apply damage and handle death
	current_health -= damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	if current_health <= 0:
		if Global.has_method("increment_lost_villagers"):
			Global.increment_lost_villagers()
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
	_setup_shout_label()
	shout(popup_message) # Initial shout on reset
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
